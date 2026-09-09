import 'dart:async';
import 'dart:collection';

import 'package:daemon/src/features/plugins/infrastructure/plugin_ports.dart';
import 'package:daemon/src/features/plugins/runtime/host_primitives.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_json_schema.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_runtime.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_state_schema.dart';
import 'package:protocol/protocol.dart';

/// Reads one active last-known-good plugin descriptor.
abstract interface class PluginDescriptorReader {
  /// Returns the currently active descriptor for [id].
  Future<PluginDescriptorDto> get(String id);
}

/// Resolves the exact LKG revision selected by one Agent.
abstract interface class AgentPluginDescriptorReader {
  /// Returns the exact revision active for [agentId].
  Future<PluginDescriptorDto> getForAgent(String agentId, String id);
}

/// Resolves the Agent definition that owns a declarative UI transition.
typedef PluginUiAgentDefinitionLookup = Future<AgentDefinitionDto> Function(
  String agentId,
);

/// Executes a UI contribution from one pinned plugin revision.
///
/// The Lua runtime implements this port for executable contributions. The
/// manifest implementation below is also useful for static UI snapshots and
/// exercises the exact same validation and action path.
abstract interface class PluginUiRuntime {
  /// Produces a root UI node for one contribution invocation.
  Future<Map<String, dynamic>> render({
    required PluginDescriptorDto plugin,
    required PluginContributionDto contribution,
    required PluginUiRenderParamsDto request,
  });

  /// Produces the next root UI node after one user action.
  Future<Map<String, dynamic>> dispatch({
    required PluginDescriptorDto plugin,
    required PluginContributionDto contribution,
    required PluginUiRenderParamsDto request,
    required PluginUiDocumentDto document,
    required PluginUiActionDto action,
  });
}

/// Executes static declarative documents embedded in contribution metadata.
///
/// `metadata.document` is the initial root. `metadata.actions[actionId]` is the
/// replacement root returned after that action. Lua-backed contributions use
/// a runtime adapter with the same port instead of a separate RPC path.
final class ManifestPluginUiRuntime implements PluginUiRuntime {
  /// Creates the effect-free manifest runtime.
  const new();

  @override
  Future<Map<String, dynamic>> render({
    required PluginDescriptorDto plugin,
    required PluginContributionDto contribution,
    required PluginUiRenderParamsDto request,
  }) async => _uiMap(
    contribution.metadata['document'],
    'UI contribution ${contribution.id} has no declarative document.',
  );

  @override
  Future<Map<String, dynamic>> dispatch({
    required PluginDescriptorDto plugin,
    required PluginContributionDto contribution,
    required PluginUiRenderParamsDto request,
    required PluginUiDocumentDto document,
    required PluginUiActionDto action,
  }) async {
    final actions = _uiMap(
      contribution.metadata['actions'],
      'UI contribution ${contribution.id} declares no actions.',
    );
    return _uiMap(
      actions[action.actionId],
      'UI action is not registered: ${action.actionId}',
    );
  }
}

/// Executes declarative UI contributions through the public Lua plugin host.
///
/// A runtime session is retained per Agent, session, plugin, contribution, and
/// revision. That session pins the immutable bundle and exact named handler on
/// the first render, so actions from an already-rendered document continue to
/// execute its original Lua revision after reload. Capability grants are
/// checked again for every callback, which makes revocation effective without
/// discarding historical presentation data.
final class LuaPluginUiRuntime<T extends Object> implements PluginUiRuntime {
  /// Creates the Lua-backed native UI adapter.
  new({
    required this.runtime,
    required this.grants,
    required this.state,
    required this.definitions,
    HostPrimitiveRegistry? hostPrimitives,
  }) : hostPrimitives = hostPrimitives ?? HostPrimitiveRegistry.empty();

  /// Shared isolated Lua runtime.
  final PluginRuntime<T> runtime;

  /// Agent-scoped capability grants.
  final AgentPluginGrantStore grants;

  /// Durable scoped JSON state exposed to UI handlers.
  final PluginStateStore state;

  /// Agent-owned extension order and settings for lifecycle dispatch.
  final PluginUiAgentDefinitionLookup definitions;

  /// Explicit typed non-turn primitive surface available to UI handlers.
  ///
  /// The registry owns the same capability, effect floor, cancellation, and
  /// structured result contract used by turn and scheduled invocations.
  final HostPrimitiveRegistry hostPrimitives;

  static const int _sessionLimit = 1024;
  final LinkedHashMap<String, Future<_LuaPluginUiSession<T>>> _sessions =
      LinkedHashMap<String, Future<_LuaPluginUiSession<T>>>();

  @override
  Future<Map<String, dynamic>> render({
    required PluginDescriptorDto plugin,
    required PluginContributionDto contribution,
    required PluginUiRenderParamsDto request,
  }) async {
    final session = await _session(plugin, contribution, request);
    final input = _validatedUiValue(
      session.contribution.inputSchema,
      request.input,
      path: r'$.input',
      label: 'Plugin UI input',
    );
    return await _invoke(
      session,
      plugin: plugin,
      contribution: contribution,
      value: input,
      context: request.context,
    );
  }

  @override
  Future<Map<String, dynamic>> dispatch({
    required PluginDescriptorDto plugin,
    required PluginContributionDto contribution,
    required PluginUiRenderParamsDto request,
    required PluginUiDocumentDto document,
    required PluginUiActionDto action,
  }) async {
    final session = await _session(plugin, contribution, request);
    await _invokeAction(
      session,
      plugin: plugin,
      document: document,
      action: action,
      request: request,
    );
    await _runUiActionHooks(
      request: request,
      document: document,
      action: action,
    );
    return await _invoke(
      session,
      plugin: plugin,
      contribution: contribution,
      value: request.input,
      context: request.context,
    );
  }

  Future<Object?> _invokeAction(
    _LuaPluginUiSession<T> session, {
    required PluginDescriptorDto plugin,
    required PluginUiDocumentDto document,
    required PluginUiActionDto action,
    required PluginUiRenderParamsDto request,
  }) async {
    final registration = session.actions[action.actionId];
    if (registration == null) {
      throw PluginUiException(
        'Plugin UI action is not registered in the snapshot revision: '
        '${action.actionId}',
      );
    }
    final payloadSchema = registration.payloadSchema;
    if (payloadSchema == null) {
      throw PluginUiException(
        'Plugin UI action has no payload schema: ${action.actionId}',
      );
    }
    final actionData = _validatedUiValue(
      payloadSchema,
      action.data,
      path: r'$.action.data',
      label: 'Plugin UI action payload',
    );
    final cancellation = _PluginUiCancellation();
    final revoked = grants.revocations.listen((grant) {
      if (grant.agentId == request.agentId && grant.pluginId == plugin.id) {
        cancellation.cancel();
      }
    });
    try {
      final invocation = await session.runtime.invoke(
        pluginId: plugin.id,
        binding: registration.binding,
        arguments: _directUiCallbackArguments(
          actionData,
          context: request.context,
        ),
        callbackRouter: session.router,
        cancellation: cancellation,
      );
      final completed = await invocation.complete();
      if (completed.error != null) {
        throw PluginUiException(
          'Plugin UI action ${action.actionId} failed: '
          '${completed.error!.message}',
        );
      }
      if (completed.revisionHash != document.revisionHash) {
        throw PluginUiException(
          'Plugin UI action ${action.actionId} executed an unexpected '
          'revision.',
        );
      }
      return completed.result;
    } finally {
      await revoked.cancel();
    }
  }

  Future<List<Object?>> _runUiActionHooks({
    required PluginUiRenderParamsDto request,
    required PluginUiDocumentDto document,
    required PluginUiActionDto action,
  }) async {
    final definition = await definitions(request.agentId);
    final values = <Object?>[];
    for (final extensionId in definition.extensionIds) {
      final pluginId = _pluginId(extensionId);
      final bundle = await runtime.revisions.resolveForAgent(
        request.agentId,
        pluginId,
      );
      final allowed = <String>{
        for (final grant in await grants.list(request.agentId))
          if (grant.pluginId == pluginId) grant.capability,
      };
      final router = _PluginUiCallbackRouter<T>(
        grants: grants,
        state: state,
        hostPrimitives: hostPrimitives,
      );
      final runtimeSession = runtime.openSession(
        agentId: request.agentId,
        sessionId:
            _contextId(request.context, 'sessionId') ??
            'plugin-ui:${request.agentId}',
        workspaceId: _contextId(request.context, 'workspaceId'),
        allowedCapabilitiesByPlugin: <String, Set<String>>{pluginId: allowed},
      );
      try {
        final registration = await runtimeSession.register(
          pluginId: pluginId,
          callbackRouter: router,
        );
        if (registration.revisionHash !=
            bundle.revision.executionRevisionHash) {
          throw PluginUiException(
            'Agent ${request.agentId} changed revision while dispatching '
            '$pluginId.',
          );
        }
        for (final hook in registration.hooks) {
          if (hook.lifecycle != PluginLifecycle.uiAction) continue;
          // Action refs are invoked directly through the exact target
          // document revision. This loop is only for ordered lifecycle hooks.
          if (hook.metadata['uiAction'] == true) continue;
          final payload = <String, Object?>{
            'event': PluginLifecycle.uiAction.wireName,
            'agent_id': request.agentId,
            'session_id': _contextId(request.context, 'sessionId'),
            'workspace_id': _contextId(request.context, 'workspaceId'),
            'context': request.context,
            'document': document.toJson(),
            'action': action.toJson(),
          };
          final cancellation = _PluginUiCancellation();
          final revoked = grants.revocations.listen((grant) {
            if (grant.agentId == request.agentId &&
                grant.pluginId == pluginId) {
              cancellation.cancel();
            }
          });
          try {
            final invocation = await runtimeSession.invoke(
              pluginId: pluginId,
              binding: hook.binding,
              arguments: <String, Object?>{
                ...payload,
                'payload': payload,
                'settings':
                    definition.pluginSettings[pluginId] ??
                    const <String, dynamic>{},
              },
              callbackRouter: router,
              cancellation: cancellation,
            );
            final completed = await invocation.complete();
            if (completed.error != null) {
              throw PluginUiException(
                'Plugin ui_action hook ${hook.id} failed: '
                '${completed.error!.message}',
              );
            }
            values.add(completed.result);
          } finally {
            await revoked.cancel();
          }
        }
      } finally {
        await runtimeSession.close();
      }
    }
    return values;
  }

  Future<Map<String, dynamic>> _invoke(
    _LuaPluginUiSession<T> session, {
    required PluginDescriptorDto plugin,
    required PluginContributionDto contribution,
    required Object? value,
    required Map<String, dynamic> context,
  }) async {
    await _requireCurrentGrants(plugin, contribution, session);
    final normalized = _validatedUiValue(
      session.contribution.inputSchema,
      value,
      path: r'$.input',
      label: 'Plugin UI input',
    );
    final cancellation = _PluginUiCancellation();
    final revoked = grants.revocations.listen((grant) {
      if (grant.agentId == session.runtime.agentId &&
          grant.pluginId == plugin.id) {
        cancellation.cancel();
      }
    });
    try {
      final invocation = await session.runtime.invoke(
        pluginId: plugin.id,
        binding: session.contribution.binding,
        arguments: _directUiCallbackArguments(normalized, context: context),
        callbackRouter: session.router,
        cancellation: cancellation,
      );
      final result = await invocation.complete();
      if (result.error != null) {
        throw PluginUiException(
          'Plugin UI handler ${contribution.id} failed: '
          '${result.error!.message}',
        );
      }
      if (result.revisionHash != plugin.revision?.executionRevisionHash) {
        throw PluginUiException(
          'Plugin UI handler ${contribution.id} executed an unexpected '
          'revision.',
        );
      }
      try {
        return decodePluginUiCallbackDocument(
          result.result,
          pluginId: plugin.id,
          registeredActionIds: session.actions.keys.toSet(),
        ).root;
      } on PluginUiCallbackDocumentException catch (error) {
        throw PluginUiException(error.message);
      }
    } finally {
      await revoked.cancel();
    }
  }

  Future<_LuaPluginUiSession<T>> _session(
    PluginDescriptorDto plugin,
    PluginContributionDto contribution,
    PluginUiRenderParamsDto request,
  ) {
    final revisionHash = plugin.revision?.executionRevisionHash;
    if (revisionHash == null) {
      throw PluginUiException(
        'Plugin ${plugin.id} has no active validated revision.',
      );
    }
    final sessionId =
        _contextId(request.context, 'sessionId') ??
        'plugin-ui:${request.agentId}';
    final workspaceId = _contextId(request.context, 'workspaceId');
    final key = <String?>[
      request.agentId,
      sessionId,
      workspaceId,
      plugin.id,
      contribution.id,
      revisionHash,
    ].join('\u0000');
    final existing = _sessions.remove(key);
    if (existing != null) {
      _sessions[key] = existing;
      return existing;
    }
    final created = _openSession(
      plugin,
      contribution,
      request,
      sessionId: sessionId,
      workspaceId: workspaceId,
    );
    _sessions[key] = created;
    if (_sessions.length > _sessionLimit) {
      final evicted = _sessions.remove(_sessions.keys.first);
      if (evicted != null) {
        unawaited(
          evicted.then((session) => session.runtime.close()).catchError((_) {}),
        );
      }
    }
    return created;
  }

  Future<void> _requireCurrentGrants(
    PluginDescriptorDto plugin,
    PluginContributionDto contribution,
    _LuaPluginUiSession<T> session,
  ) async {
    for (final capability in contribution.requiredCapabilities) {
      final granted = await grants.isGranted(
        AgentPluginGrantDto(
          agentId: session.runtime.agentId,
          pluginId: plugin.id,
          capability: capability,
        ),
      );
      if (!granted) {
        throw PluginUiException(
          'Plugin capability is not granted: $capability',
        );
      }
    }
  }

  Future<_LuaPluginUiSession<T>> _openSession(
    PluginDescriptorDto plugin,
    PluginContributionDto contribution,
    PluginUiRenderParamsDto request, {
    required String sessionId,
    required String? workspaceId,
  }) async {
    final allowed = <String>{
      for (final grant in await grants.list(request.agentId))
        if (grant.pluginId == plugin.id) grant.capability,
    };
    final router = _PluginUiCallbackRouter<T>(
      grants: grants,
      state: state,
      hostPrimitives: hostPrimitives,
    );
    final runtimeSession = runtime.openSession(
      agentId: request.agentId,
      sessionId: sessionId,
      workspaceId: workspaceId,
      allowedCapabilitiesByPlugin: <String, Set<String>>{plugin.id: allowed},
      executionRevisionPinsByPlugin: <String, String>{
        plugin.id: plugin.revision!.executionRevisionHash,
      },
    );
    try {
      final registration = await runtimeSession.register(
        pluginId: plugin.id,
        callbackRouter: router,
      );
      if (registration.revisionHash != plugin.revision?.executionRevisionHash) {
        throw PluginUiException(
          'Agent ${request.agentId} no longer has revision '
          '${plugin.revision?.executionRevisionHash} active for ${plugin.id}.',
        );
      }
      final matches = registration.ui.where(
        (item) => item.id == contribution.id && item.slot == request.slot,
      );
      if (matches.length != 1) {
        throw PluginUiException(
          'Lua UI contribution is not registered: ${contribution.id}',
        );
      }
      return _LuaPluginUiSession<T>(
        runtime: runtimeSession,
        router: router,
        contribution: matches.single,
        actions: <String, PluginHookRegistration>{
          for (final hook in registration.hooks)
            if (hook.lifecycle == PluginLifecycle.uiAction &&
                hook.metadata['uiAction'] == true)
              hook.id: hook,
        },
        sessionId: sessionId,
        workspaceId: workspaceId,
      );
    } on Object {
      await runtimeSession.close();
      rethrow;
    }
  }
}

/// Validates UI contribution ownership, pins snapshots, and serializes actions.
final class PluginUiService {
  /// Creates the native declarative UI host.
  new({required this.descriptors, required this.runtime});

  /// Active plugin descriptor source.
  final PluginDescriptorReader descriptors;

  /// Runtime behind registered UI handlers.
  final PluginUiRuntime runtime;

  static const int _snapshotLimit = 1024;
  final LinkedHashMap<String, _PluginUiSnapshot> _snapshots =
      LinkedHashMap<String, _PluginUiSnapshot>();
  final Map<String, Future<void>> _actionTails = <String, Future<void>>{};
  int _documentGeneration = 0;

  /// Registers a document rendered by the turn-pinned Lua harness.
  ///
  /// Timeline/dialog/toast publications are rendered after their owning Lua
  /// invocation completes, outside this service's ordinary RPC render path.
  /// Remembering the same exact descriptor and context keeps actions on those
  /// documents inside the normal serialized, revision-checked dispatch path.
  void rememberPublished({
    required PluginDescriptorDto plugin,
    required PluginContributionDto contribution,
    required PluginUiRenderParamsDto request,
    required PluginUiDocumentDto document,
  }) {
    if (plugin.id != document.pluginId ||
        plugin.revision?.executionRevisionHash != document.revisionHash ||
        contribution.pluginId != plugin.id ||
        contribution.id != request.contributionId ||
        contribution.kind != PluginContributionKind.ui ||
        request.agentId.isEmpty ||
        request.pluginId != plugin.id ||
        request.slot != document.slot) {
      throw const PluginUiException(
        'Published plugin UI snapshot metadata does not match.',
      );
    }
    final slots = contribution.metadata['slots'];
    if (slots is! List<Object?> ||
        !slots.whereType<String>().contains(document.slot.name)) {
      throw PluginUiException(
        'Plugin UI contribution ${contribution.id} is not registered for '
        '${document.slot.name}.',
      );
    }
    _remember(
      _PluginUiSnapshot(
        plugin: plugin,
        contribution: contribution,
        request: request,
        document: document,
      ),
    );
  }

  /// Renders one registered contribution for one host-owned slot.
  Future<PluginUiDocumentDto> render(PluginUiRenderParamsDto request) async {
    final plugin = descriptors is AgentPluginDescriptorReader
        ? await (descriptors as AgentPluginDescriptorReader).getForAgent(
            request.agentId,
            request.pluginId,
          )
        : await descriptors.get(request.pluginId);
    final revision = plugin.revision;
    if (revision == null) {
      throw PluginUiException(
        'Plugin ${plugin.id} has no active validated revision.',
      );
    }
    final contribution = _findContribution(plugin, request);
    final root = await runtime.render(
      plugin: plugin,
      contribution: contribution,
      request: request,
    );
    _documentGeneration += 1;
    final document = PluginUiDocumentDto(
      id:
          '${plugin.id}/${contribution.id}/${request.agentId}/'
          '${revision.executionRevisionHash}/$_documentGeneration',
      pluginId: plugin.id,
      revisionHash: revision.executionRevisionHash,
      slot: request.slot,
      root: Map<String, dynamic>.unmodifiable(root),
    );
    _remember(
      _PluginUiSnapshot(
        plugin: plugin,
        contribution: contribution,
        request: request,
        document: document,
      ),
    );
    return document;
  }

  /// Dispatches one action against the exact revision snapshot that rendered
  /// it.
  Future<PluginUiDocumentDto> dispatch(PluginUiActionParamsDto request) {
    final previous =
        _actionTails[request.action.documentId] ?? Future<void>.value();
    final completion = Completer<void>();
    _actionTails[request.action.documentId] = completion.future;
    return previous.then((_) async {
      try {
        return await _dispatchNow(request);
      } finally {
        completion.complete();
        if (identical(
          _actionTails[request.action.documentId],
          completion.future,
        )) {
          unawaited(_actionTails.remove(request.action.documentId));
        }
      }
    });
  }

  Future<PluginUiDocumentDto> _dispatchNow(
    PluginUiActionParamsDto request,
  ) async {
    final snapshot = _snapshots[request.action.documentId];
    if (snapshot == null) {
      throw PluginUiException(
        'Plugin UI document is no longer available: '
        '${request.action.documentId}',
      );
    }
    if (snapshot.plugin.id != request.pluginId ||
        snapshot.request.agentId != request.agentId) {
      throw const PluginUiException(
        'Plugin UI action does not belong to this Agent and plugin.',
      );
    }
    if (!_uiActionIds(snapshot.document.root)
        .contains(request.action.actionId)) {
      throw PluginUiException(
        'Plugin UI action is not referenced by this document: '
        '${request.action.actionId}',
      );
    }
    final root = await runtime.dispatch(
      plugin: snapshot.plugin,
      contribution: snapshot.contribution,
      request: snapshot.request,
      document: snapshot.document,
      action: request.action,
    );
    final document = snapshot.document.copyWith(
      root: Map<String, dynamic>.unmodifiable(root),
    );
    _remember(snapshot.copyWith(document: document));
    return document;
  }

  PluginContributionDto _findContribution(
    PluginDescriptorDto plugin,
    PluginUiRenderParamsDto request,
  ) {
    final matches = plugin.contributions.where(
      (candidate) =>
          candidate.pluginId == plugin.id &&
          candidate.kind == PluginContributionKind.ui &&
          candidate.id == request.contributionId,
    );
    if (matches.length != 1) {
      throw PluginUiException(
        'Plugin UI contribution is not registered: '
        '${plugin.id}/${request.contributionId}',
      );
    }
    final contribution = matches.single;
    final rawSlots = contribution.metadata['slots'];
    if (rawSlots is! List<Object?> ||
        !rawSlots.whereType<String>().contains(request.slot.name)) {
      throw PluginUiException(
        'Plugin UI contribution ${contribution.id} is not registered for '
        '${request.slot.name}.',
      );
    }
    return contribution;
  }

  void _remember(_PluginUiSnapshot snapshot) {
    _snapshots
      ..remove(snapshot.document.id)
      ..[snapshot.document.id] = snapshot;
    while (_snapshots.length > _snapshotLimit) {
      _snapshots.remove(_snapshots.keys.first);
    }
  }
}

/// Safe, expected rejection from the declarative UI host.
final class PluginUiException implements Exception {
  /// Creates a plugin UI rejection.
  const new(this.message);

  /// User-safe failure description.
  final String message;

  @override
  String toString() => 'PluginUiException: $message';
}

final class _PluginUiSnapshot {
  const new({
    required this.plugin,
    required this.contribution,
    required this.request,
    required this.document,
  });

  final PluginDescriptorDto plugin;
  final PluginContributionDto contribution;
  final PluginUiRenderParamsDto request;
  final PluginUiDocumentDto document;

  _PluginUiSnapshot copyWith({required PluginUiDocumentDto document}) =>
      _PluginUiSnapshot(
        plugin: plugin,
        contribution: contribution,
        request: request,
        document: document,
      );
}

/// Wraps one callback value, with the host facts of the surface beside it.
///
/// [context] is the render context the host already owns — session, locale,
/// whether the pane accepts input. It is passed as a separate key rather than
/// merged into [value], because [value] is the plugin's own declared input
/// schema and the host has no business writing into it.
Map<String, Object?> _directUiCallbackArguments(
  Object? value, {
  Map<String, dynamic> context = const <String, dynamic>{},
}) => <String, Object?>{
  '__tinest_callback_value': true,
  'value': value,
  'context': context,
};

Object? _validatedUiValue(
  Map<String, Object?> schema,
  Object? value, {
  required String path,
  required String label,
}) {
  final normalized =
      schema['type'] == 'object' && value is List<Object?> && value.isEmpty
      ? <String, Object?>{}
      : value;
  try {
    validatePluginJsonSchema(schema, normalized, path: path);
  } on PluginJsonValidationException catch (error) {
    throw PluginUiException('$label is invalid: ${error.message}');
  }
  return normalized;
}

Map<String, dynamic> _uiMap(Object? value, String error) {
  final normalized = _jsonValue(value, depth: 0);
  if (normalized is Map<String, dynamic>) return normalized;
  throw PluginUiException(error);
}

Object? _jsonValue(Object? value, {required int depth}) {
  if (depth > 32) {
    throw const PluginUiException('Plugin UI document exceeds 32 levels.');
  }
  if (value == null || value is String || value is bool || value is num) {
    return value;
  }
  if (value is List<Object?>) {
    return List<Object?>.unmodifiable(
      value.map((item) => _jsonValue(item, depth: depth + 1)),
    );
  }
  if (value case final Map<Object?, Object?> map) {
    if (!map.keys.every((key) => key is String)) {
      throw const PluginUiException(
        'Plugin UI document object keys must be strings.',
      );
    }
    return Map<String, dynamic>.unmodifiable(<String, dynamic>{
      for (final entry in map.entries)
        entry.key! as String: _jsonValue(entry.value, depth: depth + 1),
    });
  }
  throw const PluginUiException('Plugin UI document must be JSON-compatible.');
}

Set<String> _uiActionIds(Object? value) {
  final result = <String>{};
  void visit(Object? candidate) {
    if (candidate is List<Object?>) {
      candidate.forEach(visit);
      return;
    }
    if (candidate is! Map<String, dynamic>) return;
    for (final entry in candidate.entries) {
      if (entry.key == 'actionId' && entry.value is String) {
        final actionId = entry.value! as String;
        if (actionId.isNotEmpty) result.add(actionId);
      }
      visit(entry.value);
    }
  }

  visit(value);
  return result;
}

String? _contextId(Map<String, dynamic> context, String key) {
  final value = context[key];
  return value is String && value.isNotEmpty ? value : null;
}

String _pluginId(String contributionId) {
  final separator = contributionId.indexOf('/');
  return separator < 0
      ? contributionId
      : contributionId.substring(0, separator);
}

final class _LuaPluginUiSession<T extends Object> {
  const new({
    required this.runtime,
    required this.router,
    required this.contribution,
    required this.actions,
    required this.sessionId,
    required this.workspaceId,
  });

  final PluginRuntimeSession<T> runtime;
  final _PluginUiCallbackRouter<T> router;
  final PluginUiRegistration contribution;
  final Map<String, PluginHookRegistration> actions;
  final String sessionId;
  final String? workspaceId;
}

final class _PluginUiCancellation implements PluginCancellationSignal {
  final List<void Function()> _callbacks = <void Function()>[];
  bool _cancelled = false;

  @override
  void onCancel(void Function() callback) {
    if (_cancelled) {
      callback();
    } else {
      _callbacks.add(callback);
    }
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final callback in _callbacks.toList(growable: false)) {
      callback();
    }
    _callbacks.clear();
  }
}

final class _PluginUiHostCancellation implements HostPrimitiveCancellation {
  const new(this.source);

  final PluginInvocationCancellation source;

  @override
  bool get isCancelled => source.isCancelled;

  @override
  void onCancel(void Function() callback) => source.onCancel(callback);
}

final class _PluginUiCallbackRouter<T extends Object>
    implements PluginCallbackRouter<T> {
  const new({
    required this.grants,
    required this.state,
    required this.hostPrimitives,
  });

  final AgentPluginGrantStore grants;
  final PluginStateStore state;
  final HostPrimitiveRegistry hostPrimitives;

  @override
  Future<PluginCallAuthorization> authorize(
    PluginHostCallContext context,
    String name,
    Map<String, Object?> arguments,
  ) async {
    final builtInCapability = switch (name) {
      'state.read' => 'state.read',
      'state.compare_and_set' ||
      'state.transaction' ||
      'state.remove' => 'state.write',
      _ when name.startsWith('ui.') => 'ui.publish',
      _ => null,
    };
    final capability =
        builtInCapability ?? hostPrimitives.descriptor(name)?.capability;
    if (capability == null) {
      return PluginCallAuthorization.denied(
        'UI handlers cannot call Tinest host operation: $name',
      );
    }
    final granted = await grants.isGranted(
      AgentPluginGrantDto(
        agentId: context.agentId,
        pluginId: context.pluginId,
        capability: capability,
      ),
    );
    if (!granted) {
      return PluginCallAuthorization.denied(
        'Plugin capability is not granted: $capability',
      );
    }
    return PluginCallAuthorization.allowed(
      requiredCapabilities: <String>{capability},
    );
  }

  @override
  Future<PluginCallbackResult<T>> call(
    PluginHostCallContext context,
    String name,
    Map<String, Object?> arguments,
    PluginInvocationCancellation cancellation,
  ) async {
    if (cancellation.isCancelled) {
      return PluginCallbackResult<T>(
        value: 'Plugin UI invocation was cancelled.',
        isError: true,
      );
    }
    final builtIn = _callBuiltIn(context, name, arguments);
    if (builtIn != null) return await builtIn;
    if (hostPrimitives.descriptor(name) != null) {
      return await _invokeHostPrimitive(context, name, arguments, cancellation);
    }
    return PluginCallbackResult<T>(
      value: 'UI host operation is not configured: $name',
      isError: true,
    );
  }

  FutureOr<PluginCallbackResult<T>>? _callBuiltIn(
    PluginHostCallContext context,
    String name,
    Map<String, Object?> arguments,
  ) => switch (name) {
    'state.read' => _read(context, arguments),
    'state.compare_and_set' => _compareAndSet(context, arguments),
    'state.remove' => _remove(context, arguments),
    'state.transaction' => _transaction(context, arguments),
    _ when name.startsWith('ui.') => PluginCallbackResult<T>(
      value: <String, Object?>{
        'plugin_id': context.pluginId,
        'revision_hash': context.revisionHash,
        ...arguments,
      },
    ),
    _ => null,
  };

  Future<PluginCallbackResult<T>> _invokeHostPrimitive(
    PluginHostCallContext context,
    String operation,
    Map<String, Object?> arguments,
    PluginInvocationCancellation cancellation,
  ) async {
    final allowed = Set<String>.of(context.effectiveCapabilities)
      ..retainAll(context.handlerCapabilities);
    final result = await hostPrimitives.invoke(
      operation,
      arguments,
      HostPrimitiveContext(
        pluginId: context.pluginId,
        agentId: context.agentId,
        sessionId: context.sessionId,
        workspaceId: context.workspaceId,
        workspaceRoot: '',
        revisionHash: context.revisionHash,
        allowedCapabilities: allowed,
        cancellation: _PluginUiHostCancellation(cancellation),
      ),
    );
    return PluginCallbackResult<T>(
      value: result.toJson(),
      resources: <PluginOpaqueResource<T>>[
        for (final resource in result.resources)
          if (resource.value is T)
            PluginOpaqueResource<T>(
              value: resource.value as T,
              fileName: resource.fileName,
              mimeType: resource.mimeType,
              byteSize: resource.byteSize,
            ),
      ],
    );
  }

  Future<PluginCallbackResult<T>> _read(
    PluginHostCallContext context,
    Map<String, Object?> arguments,
  ) async {
    final entry = validatePluginStateCellEntry(
      arguments,
      await state.read(
        _scope(context, arguments),
        _requiredString(arguments, 'key'),
      ),
    );
    return PluginCallbackResult<T>(value: pluginStateReadEnvelope(entry));
  }

  Future<PluginCallbackResult<T>> _compareAndSet(
    PluginHostCallContext context,
    Map<String, Object?> arguments,
  ) async {
    final entry = await state.compareAndSet(
      _scope(context, arguments),
      _requiredString(arguments, 'key'),
      expectedRevision: _integer(arguments['expected_revision']) ?? 0,
      value: validatePluginStateCellValue(
        arguments,
        arguments['value'],
        path: r'$.value',
      ),
    );
    return PluginCallbackResult<T>(value: _entry(entry));
  }

  Future<PluginCallbackResult<T>> _remove(
    PluginHostCallContext context,
    Map<String, Object?> arguments,
  ) async {
    final key = _requiredString(arguments, 'key');
    final values = await state.transaction(
      _scope(context, arguments),
      (_) => <PluginStateMutation>[
        PluginStateMutation.remove(
          key: key,
          expectedRevision: _integer(arguments['expected_revision']) ?? 0,
        ),
      ],
    );
    return PluginCallbackResult<T>(value: _entries(values));
  }

  Future<PluginCallbackResult<T>> _transaction(
    PluginHostCallContext context,
    Map<String, Object?> arguments,
  ) async {
    final mutations = <PluginStateMutation>[];
    final rawMutations = arguments['mutations'];
    if (rawMutations is! List<Object?>) {
      return PluginCallbackResult<T>(
        value: 'state.transaction mutations must be an array.',
        isError: true,
      );
    }
    for (final raw in rawMutations) {
      final mutation = _stringMap(raw);
      final key = _requiredString(mutation, 'key');
      final expected = _integer(mutation['expected_revision']) ?? 0;
      mutations.add(
        mutation['remove'] == true
            ? PluginStateMutation.remove(key: key, expectedRevision: expected)
            : PluginStateMutation.put(
                key: key,
                expectedRevision: expected,
                value: validatePluginStateCellValue(
                  arguments,
                  mutation['value'],
                  path: r'$.mutations.value',
                ),
              ),
      );
    }
    final values = await state.transaction(
      _scope(context, arguments),
      (_) => mutations,
    );
    return PluginCallbackResult<T>(value: _entries(values));
  }

  @override
  Stream<PluginCallbackResult<T>> open(
    PluginHostCallContext context,
    String name,
    Map<String, Object?> arguments,
    PluginInvocationCancellation cancellation,
  ) => Stream<PluginCallbackResult<T>>.value(
    PluginCallbackResult<T>(
      value: 'UI handlers cannot open Tinest host streams.',
      isError: true,
    ),
  );
}

PluginStateScope _scope(
  PluginHostCallContext context,
  Map<String, Object?> arguments,
) => switch (arguments['scope']) {
  'plugin' => PluginStateScope.plugin(pluginId: context.pluginId),
  'agent' => PluginStateScope.agent(
    pluginId: context.pluginId,
    agentId: context.agentId,
  ),
  'session' => PluginStateScope.session(
    pluginId: context.pluginId,
    sessionId: context.sessionId,
  ),
  'workspace' when context.workspaceId != null => PluginStateScope.workspace(
    pluginId: context.pluginId,
    workspaceId: context.workspaceId!,
  ),
  'workspace' => throw const PluginUiException(
    'Workspace-scoped UI state requires a workspace context.',
  ),
  _ => throw const PluginUiException('Unsupported plugin UI state scope.'),
};

Map<String, Object?> _entry(PluginStateEntry entry) => <String, Object?>{
  'revision': entry.revision,
  'value': entry.value,
};

Map<String, Object?> _entries(Map<String, PluginStateEntry> values) =>
    <String, Object?>{
      for (final entry in values.entries) entry.key: _entry(entry.value),
    };

String _requiredString(Map<String, Object?> values, String key) {
  final value = values[key];
  if (value is String && value.isNotEmpty) return value;
  throw PluginUiException('Plugin UI callback requires $key.');
}

int? _integer(Object? value) => switch (value) {
  int() => value,
  num() when value.isFinite && value == value.truncate() => value.toInt(),
  _ => null,
};

Map<String, Object?> _stringMap(Object? value) {
  if (value case final Map<Object?, Object?> map) {
    if (map.keys.every((key) => key is String)) {
      return <String, Object?>{
        for (final entry in map.entries) entry.key! as String: entry.value,
      };
    }
  }
  throw const PluginUiException('Plugin UI callback expected an object.');
}
