import 'dart:async';

import 'package:daemon/src/features/plugins/infrastructure/plugin_bundles.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_ports.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_service.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_json_schema.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_runtime.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_state_schema.dart';
import 'package:protocol/protocol.dart';

/// Resolves one durable conversation session.
typedef PluginSessionLookup = Future<SessionDto?> Function(String sessionId);

/// Resolves the exact active or archived Agent definition owned by a session.
typedef PluginAgentDefinitionLookup = Future<AgentDefinitionDto> Function(
  String agentId,
);

/// Resolves the checkout owned by a session.
typedef PluginWorktreeLookup = Future<WorktreeDto?> Function(String worktreeId);

/// Reads, normalizes, and persists Agent-active Lua session controls.
final class PluginSessionControlService<T extends Object> {
  /// Creates the service over typed ownership and persistence ports.
  new({
    required this.plugins,
    required this.runtime,
    required this.state,
    required this.sessions,
    required this.definitions,
    required this.worktrees,
  });

  /// Agent-scoped revision and grant service.
  final PluginManagementService plugins;

  /// Isolated Lua host used to register and invoke the selected contribution.
  final PluginRuntime<T> runtime;

  /// Durable JSON store. Control values always use the session scope.
  final PluginStateStore state;

  /// Session ownership lookup.
  final PluginSessionLookup sessions;

  /// Agent definition lookup.
  final PluginAgentDefinitionLookup definitions;

  /// Worktree ownership lookup.
  final PluginWorktreeLookup worktrees;

  final Map<String, Future<void>> _mutationTails = <String, Future<void>>{};

  /// Reads one normalized value, falling back to the validated plugin default.
  Future<PluginSessionControlValueDto> get(
    PluginSessionControlParamsDto request,
  ) async {
    final owner = await _resolveOwner(request.sessionId);
    _validatePluginOwnership(
      owner.definition,
      request.pluginId,
      request.contributionId,
    );
    return await _withPlugin(owner, request.pluginId, (
      registration,
      descriptor,
      session,
      router,
    ) async {
      final control = _control(
        registration,
        request.pluginId,
        request.contributionId,
      );
      return await _readValue(owner, descriptor, control);
    });
  }

  /// Runs the registered Lua normalizer and atomically stores its result.
  Future<PluginSessionControlValueDto> set(
    PluginSessionControlSetParamsDto request,
  ) => _serializeMutation(
    '${request.sessionId}\u0000${request.contributionId}',
    () async {
      final owner = await _resolveOwner(request.sessionId);
      _validatePluginOwnership(
        owner.definition,
        request.pluginId,
        request.contributionId,
      );
      return await _withPlugin(owner, request.pluginId, (
        registration,
        descriptor,
        session,
        router,
      ) async {
        final control = _control(
          registration,
          request.pluginId,
          request.contributionId,
        );
        final input = _normalizeAndValidate(
          control,
          request.value,
          path: r'$.value',
        );
        await _requireCurrentGrants(
          owner.definition.id,
          request.pluginId,
          control.requiredCapabilities,
        );
        final current = await state.read(
          _scope(owner, request.pluginId),
          _stateKey(control),
        );
        final currentValue = current == null
            ? _defaultValue(control)
            : _normalizeAndValidate(
                control,
                current.value,
                path: r'$.currentValue',
              );
        final cancellation = _SessionControlCancellation();
        final revoked = plugins.grants.revocations.listen((grant) {
          if (grant.agentId == owner.definition.id &&
              grant.pluginId == request.pluginId) {
            cancellation.cancel();
          }
        });
        try {
          final invocation = await session.invoke(
            pluginId: request.pluginId,
            binding: control.binding,
            arguments: <String, Object?>{
              'agent_id': owner.definition.id,
              'session_id': owner.session.id,
              'workspace_id': owner.worktree.workspaceId,
              'plugin_id': request.pluginId,
              'contribution_id': control.id,
              'value': input,
              'current_value': currentValue,
              'settings':
                  owner.definition.pluginSettings[request.pluginId] ??
                  const <String, dynamic>{},
            },
            callbackRouter: router,
            cancellation: cancellation,
          );
          final completed = await invocation.complete();
          if (completed.error != null) {
            throw PluginSessionControlException(
              'Session-control handler ${control.id} failed: '
              '${completed.error!.message}',
            );
          }
          if (completed.revisionHash !=
              descriptor.revision!.executionRevisionHash) {
            throw PluginSessionControlException(
              'Session-control handler ${control.id} executed an '
              'unexpected plugin revision.',
            );
          }
          final normalized = _normalizeAndValidate(
            control,
            completed.result,
            path: r'$.result',
          );
          final stored = await state.compareAndSet(
            _scope(owner, request.pluginId),
            _stateKey(control),
            expectedRevision: current?.revision ?? 0,
            value: normalized,
          );
          return _dto(
            owner,
            descriptor,
            control,
            stored.value,
            isDefault: false,
          );
        } finally {
          await revoked.cancel();
        }
      });
    },
  );

  /// Loads every extension control in Agent extension order for one turn.
  Future<Map<String, Object?>> valuesForTurn({
    required SessionDto session,
    required AgentDefinitionDto definition,
    required WorktreeDto worktree,
  }) async {
    if (session.agentDefinitionId != definition.id) {
      throw const PluginSessionControlException(
        'Session and Agent definition ownership do not match.',
      );
    }
    if (session.worktreeId != worktree.id || worktree.archivedAt != null) {
      throw const PluginSessionControlException(
        'Session worktree ownership is invalid.',
      );
    }
    final owner = _SessionControlOwner(
      session: session,
      definition: definition,
      worktree: worktree,
    );
    final values = <String, Object?>{};
    for (final pluginId in definition.extensionIds) {
      await _withPlugin(owner, pluginId, (
        registration,
        descriptor,
        session,
        router,
      ) async {
        for (final control in registration.sessionControls) {
          final value = await _readValue(owner, descriptor, control);
          values[control.id] = value.value;
        }
      }, prepare: false);
    }
    return Map<String, Object?>.unmodifiable(values);
  }

  Future<_SessionControlOwner> _resolveOwner(String sessionId) async {
    final session = await sessions(sessionId);
    if (session == null) {
      throw PluginSessionControlException('Session not found: $sessionId');
    }
    final definition = await definitions(session.agentDefinitionId);
    if (definition.id != session.agentDefinitionId) {
      throw const PluginSessionControlException(
        'Resolved Agent definition does not own the session.',
      );
    }
    final worktree = await worktrees(session.worktreeId);
    if (worktree == null ||
        worktree.id != session.worktreeId ||
        worktree.archivedAt != null) {
      throw PluginSessionControlException(
        'Active session worktree not found: ${session.worktreeId}',
      );
    }
    return _SessionControlOwner(
      session: session,
      definition: definition,
      worktree: worktree,
    );
  }

  void _validatePluginOwnership(
    AgentDefinitionDto definition,
    String pluginId,
    String contributionId,
  ) {
    if (!definition.extensionIds.contains(pluginId)) {
      throw PluginSessionControlException(
        'Plugin is not an active Agent extension: $pluginId',
      );
    }
    if (!contributionId.startsWith('$pluginId/') ||
        contributionId.length == pluginId.length + 1) {
      throw PluginSessionControlException(
        'Session-control contribution is not owned by $pluginId.',
      );
    }
  }

  Future<R> _withPlugin<R>(
    _SessionControlOwner owner,
    String pluginId,
    Future<R> Function(
      PluginRegistration registration,
      PluginDescriptorDto descriptor,
      PluginRuntimeSession<T> session,
      PluginCallbackRouter<T> router,
    )
    operation, {
    bool prepare = true,
  }) async {
    late final PluginDescriptorDto descriptor;
    try {
      descriptor = (await plugins.revisions.resolveForAgent(
        owner.definition.id,
        pluginId,
      )).descriptor;
    } on PluginRevisionUnavailable {
      if (!prepare) rethrow;
      descriptor = await plugins.prepareForAgent(owner.definition.id, pluginId);
    }
    final revision = descriptor.revision;
    if (revision == null) {
      throw PluginSessionControlException(
        'Plugin has no active revision: $pluginId',
      );
    }
    final allowed = <String>{
      for (final grant in await plugins.grants.list(owner.definition.id))
        if (grant.pluginId == pluginId) grant.capability,
    };
    final router = _SessionControlCallbackRouter<T>(
      grants: plugins.grants,
      state: state,
    );
    final session = runtime.openSession(
      agentId: owner.definition.id,
      sessionId: owner.session.id,
      workspaceId: owner.worktree.workspaceId,
      workingDirectory: owner.worktree.path,
      allowedCapabilitiesByPlugin: <String, Set<String>>{pluginId: allowed},
    );
    try {
      final registration = await session.register(
        pluginId: pluginId,
        callbackRouter: router,
      );
      if (registration.revisionHash != revision.executionRevisionHash) {
        throw PluginSessionControlException(
          'Agent ${owner.definition.id} no longer has revision '
          '${revision.executionRevisionHash} active for $pluginId.',
        );
      }
      return await operation(registration, descriptor, session, router);
    } finally {
      await session.close();
    }
  }

  PluginSessionControlRegistration _control(
    PluginRegistration registration,
    String pluginId,
    String contributionId,
  ) {
    final matches = registration.sessionControls.where(
      (control) => control.id == contributionId,
    );
    if (matches.length != 1) {
      throw PluginSessionControlException(
        'Session-control contribution is not registered by $pluginId: '
        '$contributionId',
      );
    }
    return matches.single;
  }

  Future<PluginSessionControlValueDto> _readValue(
    _SessionControlOwner owner,
    PluginDescriptorDto descriptor,
    PluginSessionControlRegistration control,
  ) async {
    final entry = await state.read(
      _scope(owner, descriptor.id),
      _stateKey(control),
    );
    final isDefault = entry == null;
    final value = isDefault
        ? _defaultValue(control)
        : _normalizeAndValidate(control, entry.value, path: r'$.storedValue');
    return _dto(owner, descriptor, control, value, isDefault: isDefault);
  }

  PluginSessionControlValueDto _dto(
    _SessionControlOwner owner,
    PluginDescriptorDto descriptor,
    PluginSessionControlRegistration control,
    Object? value, {
    required bool isDefault,
  }) => PluginSessionControlValueDto(
    sessionId: owner.session.id,
    agentId: owner.definition.id,
    pluginId: descriptor.id,
    contributionId: control.id,
    revisionHash: descriptor.revision!.executionRevisionHash,
    schema: Map<String, dynamic>.from(control.schema),
    defaultValue: _defaultValue(control),
    value: value,
    isDefault: isDefault,
    metadata: Map<String, dynamic>.from(control.metadata),
  );

  Object? _defaultValue(PluginSessionControlRegistration control) =>
      _normalizeAndValidate(
        control,
        control.metadata['default'],
        path: r'$.default',
      );

  Object? _normalizeAndValidate(
    PluginSessionControlRegistration control,
    Object? value, {
    required String path,
  }) {
    try {
      final normalized = normalizePluginJson(value, path: path);
      validatePluginJsonSchema(control.schema, normalized, path: path);
      return normalized;
    } on PluginJsonValidationException catch (error) {
      throw PluginSessionControlException(error.message);
    }
  }

  Future<void> _requireCurrentGrants(
    String agentId,
    String pluginId,
    Set<String> capabilities,
  ) async {
    for (final capability in capabilities) {
      final granted = await plugins.grants.isGranted(
        AgentPluginGrantDto(
          agentId: agentId,
          pluginId: pluginId,
          capability: capability,
        ),
      );
      if (!granted) {
        throw PluginSessionControlException(
          'Plugin capability is not granted: $capability',
        );
      }
    }
  }

  PluginStateScope _scope(_SessionControlOwner owner, String pluginId) =>
      PluginStateScope.session(pluginId: pluginId, sessionId: owner.session.id);

  String _stateKey(PluginSessionControlRegistration control) =>
      '_tinest/session-control/${control.id.split('/').last}';

  Future<R> _serializeMutation<R>(
    String key,
    Future<R> Function() operation,
  ) async {
    final previous = _mutationTails[key] ?? Future<void>.value();
    final released = Completer<void>();
    _mutationTails[key] = released.future;
    await previous;
    try {
      return await operation();
    } finally {
      released.complete();
      if (identical(_mutationTails[key], released.future)) {
        await _mutationTails.remove(key);
      }
    }
  }
}

/// Expected ownership, validation, handler, or persistence failure.
final class PluginSessionControlException implements Exception {
  /// Creates a user-safe failure.
  const new(this.message);

  /// Failure detail suitable for transport mapping.
  final String message;

  @override
  String toString() => 'PluginSessionControlException: $message';
}

final class _SessionControlOwner {
  const new({
    required this.session,
    required this.definition,
    required this.worktree,
  });

  final SessionDto session;
  final AgentDefinitionDto definition;
  final WorktreeDto worktree;
}

final class _SessionControlCancellation implements PluginCancellationSignal {
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

final class _SessionControlCallbackRouter<T extends Object>
    implements PluginCallbackRouter<T> {
  const new({required this.grants, required this.state});

  final AgentPluginGrantStore grants;
  final PluginStateStore state;

  @override
  Future<PluginCallAuthorization> authorize(
    PluginHostCallContext context,
    String name,
    Map<String, Object?> arguments,
  ) async {
    final capability = switch (name) {
      'state.read' => 'state.read',
      'state.compare_and_set' ||
      'state.transaction' ||
      'state.remove' => 'state.write',
      _ => null,
    };
    if (capability == null) {
      return PluginCallAuthorization.denied(
        'Session-control handlers cannot call Tinest host operation: $name',
      );
    }
    final granted = await grants.isGranted(
      AgentPluginGrantDto(
        agentId: context.agentId,
        pluginId: context.pluginId,
        capability: capability,
      ),
    );
    return granted
        ? PluginCallAuthorization.allowed(
            requiredCapabilities: <String>{capability},
          )
        : PluginCallAuthorization.denied(
            'Plugin capability is not granted: $capability',
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
        value: 'Session-control invocation was cancelled.',
        isError: true,
      );
    }
    return await switch (name) {
      'state.read' => _read(context, arguments),
      'state.compare_and_set' => _compareAndSet(context, arguments),
      'state.remove' => _remove(context, arguments),
      'state.transaction' => _transaction(context, arguments),
      _ => PluginCallbackResult<T>(
        value: 'Session-control host operation is not configured: $name',
        isError: true,
      ),
    };
  }

  Future<PluginCallbackResult<T>> _read(
    PluginHostCallContext context,
    Map<String, Object?> arguments,
  ) async {
    final entry = validatePluginStateCellEntry(
      arguments,
      await state.read(
        _callbackScope(context, arguments),
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
      _callbackScope(context, arguments),
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
      _callbackScope(context, arguments),
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
    final rawMutations = arguments['mutations'];
    if (rawMutations is! List<Object?>) {
      return PluginCallbackResult<T>(
        value: 'state.transaction mutations must be an array.',
        isError: true,
      );
    }
    final mutations = <PluginStateMutation>[];
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
      _callbackScope(context, arguments),
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
      value: 'Session-control handlers cannot open Tinest host streams.',
      isError: true,
    ),
  );
}

PluginStateScope _callbackScope(
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
  _ => throw const PluginSessionControlException(
    'Unsupported session-control state scope.',
  ),
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
  throw PluginSessionControlException(
    'Session-control callback requires $key.',
  );
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
  throw const PluginSessionControlException(
    'Session-control callback expected an object.',
  );
}
