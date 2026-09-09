import 'package:daemon/src/features/plugins/infrastructure/plugin_ports.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_runtime.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_state_schema.dart';
import 'package:protocol/protocol.dart';

/// Immutable inputs that identify one Agent/session plugin lifecycle.
final class PluginExecutionLifecycleRequest {
  /// Creates an exact execution lifecycle snapshot.
  const new({
    required this.definition,
    required this.sessionId,
    required this.workingDirectory,
    required this.allowedCapabilitiesByPlugin,
    this.workspaceId,
  });

  /// Agent definition active at the next-turn boundary.
  final AgentDefinitionDto definition;

  /// Product session identity.
  final String sessionId;

  /// Optional workspace isolation identity.
  final String? workspaceId;

  /// Host-owned working directory.
  final String workingDirectory;

  /// Effective grants for the selected revisions.
  final Map<String, Set<String>> allowedCapabilitiesByPlugin;
}

/// Tracks Agent/session lifecycle hooks independently of per-turn Lua VMs.
///
/// Every hook invocation still receives a fresh Lua VM. This registry retains
/// only immutable revision identity and ownership metadata so a session emits
/// attach/open once, switches revisions at the next turn, and closes in reverse
/// lifecycle order when the coordinator shuts down.
final class PluginExecutionLifecycleRegistry<T extends Object> {
  /// Creates the registry over public runtime and scoped-state ports.
  new({required this.runtime, required this.state});

  /// Shared isolated Lua runtime.
  final PluginRuntime<T> runtime;

  /// Scoped JSON state available to lifecycle hooks.
  final PluginStateStore state;

  final Map<String, _AttachedPluginLifecycle<T>> _attached =
      <String, _AttachedPluginLifecycle<T>>{};
  Future<void> _tail = Future<void>.value();
  bool _closed = false;

  /// Attaches the exact Agent/revisions for a turn, switching at this boundary.
  Future<void> enter(PluginExecutionLifecycleRequest request) =>
      _serialize(() async {
        if (_closed) throw StateError('Plugin lifecycle registry is closed.');
        final next = await _snapshot(request);
        final current = _attached[request.sessionId];
        if (current?.fingerprint == next.fingerprint) return;
        if (current != null) {
          _attached.remove(request.sessionId);
          await _closeAttached(current);
        }
        await _openRuntimeSessions(next);
        await _openAttached(next);
        _attached[request.sessionId] = next;
      });

  /// Closes every attached session once, then detaches its Agent in reverse
  /// lifecycle order. Repeated calls are harmless.
  Future<void> close() => _serialize(() async {
    if (_closed) return;
    _closed = true;
    Object? firstError;
    final active = _attached.values.toList(growable: false).reversed;
    _attached.clear();
    for (final attached in active) {
      try {
        await _closeAttached(attached);
      } on Object catch (error) {
        firstError ??= error;
      }
    }
    if (firstError != null) {
      throw StateError('Plugin lifecycle close failed: $firstError');
    }
  });

  Future<_AttachedPluginLifecycle<T>> _snapshot(
    PluginExecutionLifecycleRequest request,
  ) async {
    final pluginIds = request.definition.extensionIds
        .map(_pluginId)
        .toSet()
        .toList(growable: false);
    final referencedPluginIds = <String>{
      _pluginId(request.definition.driverId),
      ...pluginIds,
      ...request.definition.toolIds.map(_pluginId),
    };
    final revisions = <String, String>{};
    for (final pluginId in referencedPluginIds) {
      final bundle = await runtime.revisions.resolveForAgent(
        request.definition.id,
        pluginId,
      );
      revisions[pluginId] = bundle.revision.executionRevisionHash;
    }
    return _AttachedPluginLifecycle(
      request: request,
      pluginIds: pluginIds,
      revisions: revisions,
      sessions: <String, PluginRuntimeSession<T>>{},
    );
  }

  Future<void> _openRuntimeSessions(
    _AttachedPluginLifecycle<T> attached,
  ) async {
    try {
      for (final pluginId in attached.pluginIds) {
        attached.sessions[pluginId] = runtime.openSession(
          agentId: attached.request.definition.id,
          sessionId: attached.request.sessionId,
          workspaceId: attached.request.workspaceId,
          workingDirectory: attached.request.workingDirectory,
          allowedCapabilitiesByPlugin:
              attached.request.allowedCapabilitiesByPlugin,
        );
      }
    } on Object {
      await attached.closeSessions();
      rethrow;
    }
  }

  Future<void> _openAttached(_AttachedPluginLifecycle<T> attached) async {
    final attachedPlugins = <String>[];
    final openedPlugins = <String>[];
    try {
      await _invoke(
        attached,
        PluginLifecycle.agentAttach,
        forward: true,
        progress: attachedPlugins,
      );
      await _invoke(
        attached,
        PluginLifecycle.sessionOpen,
        forward: true,
        progress: openedPlugins,
      );
    } on Object {
      // Best-effort inverse transition prevents a half-open registry entry.
      try {
        if (openedPlugins.isNotEmpty) {
          await _invokeClosing(
            attached,
            PluginLifecycle.sessionClose,
            pluginIds: openedPlugins.reversed,
          );
        }
        if (attachedPlugins.isNotEmpty) {
          await _invokeClosing(
            attached,
            PluginLifecycle.agentDetach,
            pluginIds: attachedPlugins.reversed,
          );
        }
      } on Object {
        // Preserve the transition failure that prevented attachment.
      }
      await attached.closeSessions();
      rethrow;
    }
  }

  Future<void> _closeAttached(_AttachedPluginLifecycle<T> attached) async {
    Object? firstError;
    try {
      await _invokeClosing(
        attached,
        PluginLifecycle.sessionClose,
        pluginIds: attached.pluginIds.reversed,
      );
    } on Object catch (error) {
      firstError = error;
    }
    try {
      await _invokeClosing(
        attached,
        PluginLifecycle.agentDetach,
        pluginIds: attached.pluginIds.reversed,
      );
    } on Object catch (error) {
      firstError ??= error;
    }
    await attached.closeSessions();
    if (firstError != null) {
      throw StateError('Plugin lifecycle transition failed: $firstError');
    }
  }

  Future<void> _invoke(
    _AttachedPluginLifecycle<T> attached,
    PluginLifecycle lifecycle, {
    required bool forward,
    Iterable<String>? pluginIds,
    List<String>? progress,
  }) async {
    final orderedPluginIds =
        pluginIds ??
        (forward ? attached.pluginIds : attached.pluginIds.reversed);
    for (final pluginId in orderedPluginIds) {
      final router = _LifecycleCallbackRouter<T>(state: state);
      final session = attached.sessions[pluginId]!;
      final registration = await session.register(
        pluginId: pluginId,
        callbackRouter: router,
      );
      if (registration.revisionHash != attached.revisions[pluginId]) {
        throw StateError(
          'Plugin lifecycle revision changed before $lifecycle: $pluginId.',
        );
      }
      progress?.add(pluginId);
      for (final hook in registration.hooks) {
        if (hook.lifecycle != lifecycle) continue;
        final payload = <String, Object?>{
          'lifecycle': lifecycle.wireName,
          'agent_id': attached.request.definition.id,
          'session_id': attached.request.sessionId,
          'workspace_id': attached.request.workspaceId,
        };
        final invocation = await session.invoke(
          pluginId: pluginId,
          binding: hook.binding,
          arguments: <String, Object?>{
            ...payload,
            'payload': payload,
            'settings':
                attached.request.definition.pluginSettings[pluginId] ??
                const <String, dynamic>{},
          },
          callbackRouter: router,
        );
        final completed = await invocation.complete();
        if (completed.error != null) {
          throw StateError(
            'Plugin lifecycle hook ${hook.id} failed: '
            '${completed.error!.message}',
          );
        }
      }
    }
  }

  Future<void> _invokeClosing(
    _AttachedPluginLifecycle<T> attached,
    PluginLifecycle lifecycle, {
    required Iterable<String> pluginIds,
  }) async {
    Object? firstError;
    for (final pluginId in pluginIds) {
      try {
        await _invoke(
          attached,
          lifecycle,
          forward: false,
          pluginIds: <String>[pluginId],
        );
      } on Object catch (error) {
        firstError ??= error;
      }
    }
    if (firstError != null) {
      throw StateError('Plugin lifecycle hook failed: $firstError');
    }
  }

  Future<void> _serialize(Future<void> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.catchError((Object _) {});
    return result;
  }
}

final class _AttachedPluginLifecycle<T extends Object> {
  const new({
    required this.request,
    required this.pluginIds,
    required this.revisions,
    required this.sessions,
  });

  final PluginExecutionLifecycleRequest request;
  final List<String> pluginIds;
  final Map<String, String> revisions;
  final Map<String, PluginRuntimeSession<T>> sessions;

  Future<void> closeSessions() async {
    await Future.wait(sessions.values.map((session) => session.close()));
    sessions.clear();
  }

  String get fingerprint => <String>[
    request.definition.id,
    request.definition.contentHash,
    request.workspaceId ?? '',
    request.workingDirectory,
    for (final entry in revisions.entries.toList()..sort(_compareEntries))
      '${entry.key}@${entry.value}',
    for (final entry
        in request.allowedCapabilitiesByPlugin.entries.toList()
          ..sort(_compareEntries))
      '${entry.key}=${(entry.value.toList()..sort()).join(',')}',
  ].join('\u0000');
}

int _compareEntries(
  MapEntry<String, Object?> left,
  MapEntry<String, Object?> right,
) => left.key.compareTo(right.key);

final class _LifecycleCallbackRouter<T extends Object>
    implements PluginCallbackRouter<T> {
  const new({required this.state});

  final PluginStateStore state;

  @override
  Future<PluginCallAuthorization> authorize(
    PluginHostCallContext context,
    String name,
    Map<String, Object?> arguments,
  ) async => switch (name) {
    'state.read' => const PluginCallAuthorization.allowed(
      requiredCapabilities: <String>{'state.read'},
    ),
    'state.compare_and_set' ||
    'state.transaction' ||
    'state.remove' => const PluginCallAuthorization.allowed(
      requiredCapabilities: <String>{'state.write'},
    ),
    _ => PluginCallAuthorization.denied(
      'Execution lifecycle hooks cannot call Tinest host operation: $name',
    ),
  };

  @override
  Future<PluginCallbackResult<T>> call(
    PluginHostCallContext context,
    String name,
    Map<String, Object?> arguments,
    PluginInvocationCancellation cancellation,
  ) async {
    if (cancellation.isCancelled) {
      return PluginCallbackResult<T>(
        value: 'Plugin lifecycle invocation was cancelled.',
        isError: true,
      );
    }
    final scope = _stateScope(context, arguments);
    switch (name) {
      case 'state.read':
        final entry = validatePluginStateCellEntry(
          arguments,
          await state.read(scope, _required(arguments, 'key')),
        );
        return PluginCallbackResult<T>(value: pluginStateReadEnvelope(entry));
      case 'state.compare_and_set':
        final entry = await state.compareAndSet(
          scope,
          _required(arguments, 'key'),
          expectedRevision: _integer(arguments['expected_revision']) ?? 0,
          value: validatePluginStateCellValue(
            arguments,
            arguments['value'],
            path: r'$.value',
          ),
        );
        return PluginCallbackResult<T>(value: _entry(entry));
      case 'state.remove':
        final key = _required(arguments, 'key');
        final values = await state.transaction(
          scope,
          (_) => <PluginStateMutation>[
            PluginStateMutation.remove(
              key: key,
              expectedRevision: _integer(arguments['expected_revision']) ?? 0,
            ),
          ],
        );
        return PluginCallbackResult<T>(value: _entries(values));
      case 'state.transaction':
        final rawMutations = arguments['mutations'];
        if (rawMutations is! List<Object?>) {
          return PluginCallbackResult<T>(
            value: 'state.transaction mutations must be an array.',
            isError: true,
          );
        }
        final mutations = <PluginStateMutation>[];
        for (final raw in rawMutations) {
          final mutation = _object(raw);
          final key = _required(mutation, 'key');
          final expected = _integer(mutation['expected_revision']) ?? 0;
          mutations.add(
            mutation['remove'] == true
                ? PluginStateMutation.remove(
                    key: key,
                    expectedRevision: expected,
                  )
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
        final values = await state.transaction(scope, (_) => mutations);
        return PluginCallbackResult<T>(value: _entries(values));
      default:
        return PluginCallbackResult<T>(
          value: 'Lifecycle host operation is not configured: $name',
          isError: true,
        );
    }
  }

  @override
  Stream<PluginCallbackResult<T>> open(
    PluginHostCallContext context,
    String name,
    Map<String, Object?> arguments,
    PluginInvocationCancellation cancellation,
  ) => Stream<PluginCallbackResult<T>>.value(
    PluginCallbackResult<T>(
      value: 'Execution lifecycle hooks cannot open host streams.',
      isError: true,
    ),
  );
}

PluginStateScope _stateScope(
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
  _ => throw const FormatException('Unsupported lifecycle state scope.'),
};

Map<String, Object?> _entry(PluginStateEntry entry) => <String, Object?>{
  'revision': entry.revision,
  'value': entry.value,
};

Map<String, Object?> _entries(Map<String, PluginStateEntry> entries) =>
    <String, Object?>{
      for (final entry in entries.entries) entry.key: _entry(entry.value),
    };

Map<String, Object?> _object(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map<Object?, Object?>) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw const FormatException(
    'Plugin lifecycle state mutation must be an object.',
  );
}

String _required(Map<String, Object?> arguments, String key) {
  final value = arguments[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Plugin lifecycle callback requires $key.');
}

int? _integer(Object? value) => value is num ? value.toInt() : null;

String _pluginId(String contributionId) {
  final separator = contributionId.indexOf('/');
  return separator < 0
      ? contributionId
      : contributionId.substring(0, separator);
}
