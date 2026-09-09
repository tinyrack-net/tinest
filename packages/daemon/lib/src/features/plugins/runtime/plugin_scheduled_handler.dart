import 'dart:async';

import 'package:agent/agent.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_ports.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_json_schema.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_runtime.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_scheduled_payload.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_scheduler.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_state_schema.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';

/// Host-owned identity and workspace data for one recovered plugin job.
final class PluginScheduledExecutionContext {
  /// Creates a validated scheduled execution context.
  const new({
    required this.agentId,
    required this.sessionId,
    required this.workingDirectory,
    this.workspaceId,
    this.sessionCapabilities,
  });

  /// Agent definition that still references the plugin.
  final String agentId;

  /// Session that owns the durable job.
  final String sessionId;

  /// Registered workspace identity, when present.
  final String? workspaceId;

  /// Host-selected checkout path.
  final String workingDirectory;

  /// Optional live session capability restriction.
  final Set<String>? sessionCapabilities;
}

/// Resolves current daemon entities without trusting persisted job payloads.
typedef PluginScheduledContextResolver =
    Future<PluginScheduledExecutionContext> Function(PluginJob job);

/// Observes declarative UI publications made by a scheduled handler.
typedef PluginScheduledUiEventSink = FutureOr<void> Function(
  PluginJob job,
  PluginHostCallContext context,
  String operation,
  Map<String, Object?> arguments,
);

/// Executes durable named handlers through the same public Lua SDK and broker.
final class LuaPluginScheduledJobExecutor {
  /// Creates the real Lua durable-handler adapter.
  const new({
    required this.runtime,
    required this.state,
    required this.grants,
    required this.jobs,
    required this.clock,
    required this.ids,
    required this.resolveContext,
    this.onUiEvent,
  });

  /// Shared isolated plugin runtime.
  final PluginRuntime<ConversationAttachment> runtime;

  /// Durable scoped JSON state.
  final PluginStateStore state;

  /// Agent-owned capability grants and revocation stream.
  final AgentPluginGrantStore grants;

  /// Active scheduler, resolved lazily to break composition-root cycles.
  final PluginJobStore Function() jobs;

  /// Host clock used for new jobs.
  final Clock clock;

  /// Host ID source used for new jobs.
  final IdGenerator ids;

  /// Validates current Agent/session/workspace ownership.
  final PluginScheduledContextResolver resolveContext;

  /// Optional audit sink for scheduled UI publications.
  final PluginScheduledUiEventSink? onUiEvent;

  /// Invokes one claimed job and maps its return value to scheduler behavior.
  Future<PluginScheduledHandlerResult> execute(
    PluginJob job,
    PluginCancellationSignal schedulerCancellation,
  ) async {
    final context = await resolveContext(job);
    if (job.agentId != context.agentId || job.sessionId != context.sessionId) {
      throw StateError('Scheduled plugin job ownership changed: ${job.id}');
    }
    final allowed = <String>{
      for (final grant in await grants.list(context.agentId))
        if (grant.pluginId == job.pluginId) grant.capability,
    };
    final cancellation = _ScheduledCancellation()..bind(schedulerCancellation);
    final revocations = grants.revocations.listen((grant) {
      if (grant.agentId == context.agentId && grant.pluginId == job.pluginId) {
        cancellation.cancel();
      }
    });
    final runtimeSession = runtime.openSession(
      agentId: context.agentId,
      sessionId: context.sessionId,
      workspaceId: context.workspaceId,
      workingDirectory: context.workingDirectory,
      allowedCapabilitiesByPlugin: <String, Set<String>>{job.pluginId: allowed},
      sessionCapabilities: context.sessionCapabilities,
      executionRevisionPinsByPlugin: <String, String>{
        job.pluginId: job.executionRevisionHash,
      },
    );
    final router = _ScheduledCallbackRouter(
      job: job,
      state: state,
      jobs: jobs,
      clock: clock,
      ids: ids,
      onUiEvent: onUiEvent,
    );
    try {
      final registration = await runtimeSession.register(
        pluginId: job.pluginId,
        callbackRouter: router,
        cancellation: cancellation,
      );
      router.bindRegistration(registration);
      final scheduledHook = resolvePluginScheduledHandler(
        registration: registration,
        pluginId: job.pluginId,
        executionRevisionHash: job.executionRevisionHash,
        bindingId: job.bindingId,
      );
      late final Map<String, dynamic> payload;
      try {
        payload = validatePluginScheduledPayload(
          scheduledHook,
          job.payload,
          path: r'$.job.payload',
        );
      } on PluginJsonValidationException catch (error) {
        throw StateError(
          'Durable job ${job.id} payload violates its exact scheduled '
          'handler schema: ${error.message}',
        );
      }
      final effectiveCapabilities = Set<String>.of(allowed);
      final sessionCapabilities = context.sessionCapabilities;
      if (sessionCapabilities != null) {
        effectiveCapabilities.retainAll(sessionCapabilities);
      }
      final unavailableCapabilities =
          scheduledHook.requiredCapabilities
              .difference(effectiveCapabilities)
              .toList(growable: false)
            ..sort();
      if (unavailableCapabilities.isNotEmpty) {
        throw StateError(
          'Durable job ${job.id} is disabled because required capabilities '
          'are unavailable or revoked: ${unavailableCapabilities.join(', ')}.',
        );
      }
      final invocation = await runtimeSession.invoke(
        pluginId: job.pluginId,
        binding: scheduledHook.binding,
        arguments: payload,
        callbackRouter: router,
        cancellation: cancellation,
      );
      final completed = await invocation.complete();
      if (completed.error != null) {
        throw StateError(
          'Scheduled plugin handler ${job.pluginId}/${job.bindingId} failed: '
          '${completed.error!.message}',
        );
      }
      final result = _object(completed.result);
      return PluginScheduledHandlerResult(
        continueTurn: result['continue'] == true,
        prompt: result['prompt']?.toString() ?? '',
      );
    } finally {
      await revocations.cancel();
      await runtimeSession.close();
    }
  }
}

final class _ScheduledCallbackRouter
    implements PluginCallbackRouter<ConversationAttachment> {
  new({
    required this.job,
    required this.state,
    required this.jobs,
    required this.clock,
    required this.ids,
    required this.onUiEvent,
  });

  final PluginJob job;
  final PluginStateStore state;
  final PluginJobStore Function() jobs;
  final Clock clock;
  final IdGenerator ids;
  final PluginScheduledUiEventSink? onUiEvent;
  PluginRegistration? _registration;

  void bindRegistration(PluginRegistration registration) {
    if (_registration != null) {
      throw StateError('Scheduled callback registration is already pinned.');
    }
    _registration = registration;
  }

  @override
  Future<PluginCallAuthorization> authorize(
    PluginHostCallContext context,
    String name,
    Map<String, Object?> arguments,
  ) async {
    final capability = switch (name) {
      'state.read' => 'state.read',
      _ when name.startsWith('state.') => 'state.write',
      _ when name.startsWith('scheduler.') => 'scheduler.manage',
      _ when name.startsWith('ui.') => 'ui.publish',
      _ => null,
    };
    return capability == null
        ? PluginCallAuthorization.denied(
            'Scheduled handler operation is unavailable: $name',
          )
        : PluginCallAuthorization.allowed(
            requiredCapabilities: <String>{capability},
          );
  }

  @override
  Future<PluginCallbackResult<ConversationAttachment>> call(
    PluginHostCallContext context,
    String name,
    Map<String, Object?> arguments,
    PluginInvocationCancellation cancellation,
  ) async {
    if (cancellation.isCancelled) {
      throw StateError('Scheduled plugin handler was cancelled.');
    }
    switch (name) {
      case 'state.read':
        final entry = validatePluginStateCellEntry(
          arguments,
          await state.read(
            _stateScope(context, arguments),
            _requiredString(arguments, 'key'),
          ),
        );
        return PluginCallbackResult<ConversationAttachment>(
          value: pluginStateReadEnvelope(entry),
        );
      case 'state.compare_and_set':
        final entry = await state.compareAndSet(
          _stateScope(context, arguments),
          _requiredString(arguments, 'key'),
          expectedRevision: _integer(arguments['expected_revision']) ?? 0,
          value: validatePluginStateCellValue(
            arguments,
            arguments['value'],
            path: r'$.value',
          ),
        );
        return PluginCallbackResult<ConversationAttachment>(
          value: _stateEntry(entry),
        );
      case 'state.remove':
        return await _removeState(context, arguments);
      case 'state.transaction':
        return await _transactState(context, arguments);
      case 'scheduler.schedule':
      case 'scheduler.continue_after_turn':
        return await _schedule(context, name, arguments);
      case 'scheduler.cancel':
        final id = _requiredString(arguments, 'id');
        final cancelled = await jobs().cancel(
          id,
          pluginId: context.pluginId,
          agentId: context.agentId,
          sessionId: context.sessionId,
        );
        return PluginCallbackResult<ConversationAttachment>(
          value: <String, Object?>{'id': id, 'cancelled': cancelled},
        );
      default:
        if (name.startsWith('ui.')) {
          await onUiEvent?.call(job, context, name, arguments);
          return PluginCallbackResult<ConversationAttachment>(
            value: <String, Object?>{
              'plugin_id': context.pluginId,
              'revision_hash': context.revisionHash,
              ...arguments,
            },
          );
        }
        return PluginCallbackResult<ConversationAttachment>(
          value: 'Scheduled handler operation is unavailable: $name',
          isError: true,
        );
    }
  }

  Future<PluginCallbackResult<ConversationAttachment>> _removeState(
    PluginHostCallContext context,
    Map<String, Object?> arguments,
  ) async {
    final key = _requiredString(arguments, 'key');
    final values = await state.transaction(
      _stateScope(context, arguments),
      (_) => <PluginStateMutation>[
        PluginStateMutation.remove(
          key: key,
          expectedRevision: _integer(arguments['expected_revision']) ?? 0,
        ),
      ],
    );
    return PluginCallbackResult<ConversationAttachment>(
      value: <String, Object?>{
        for (final entry in values.entries) entry.key: _stateEntry(entry.value),
      },
    );
  }

  Future<PluginCallbackResult<ConversationAttachment>> _transactState(
    PluginHostCallContext context,
    Map<String, Object?> arguments,
  ) async {
    final mutations = <PluginStateMutation>[
      for (final raw in _list(arguments['mutations']))
        if (_object(raw) case final mutation)
          if (mutation['remove'] == true)
            PluginStateMutation.remove(
              key: _requiredString(mutation, 'key'),
              expectedRevision: _integer(mutation['expected_revision']) ?? 0,
            )
          else
            PluginStateMutation.put(
              key: _requiredString(mutation, 'key'),
              expectedRevision: _integer(mutation['expected_revision']) ?? 0,
              value: validatePluginStateCellValue(
                arguments,
                mutation['value'],
                path: r'$.mutations.value',
              ),
            ),
    ];
    final values = await state.transaction(
      _stateScope(context, arguments),
      (_) => mutations,
    );
    return PluginCallbackResult<ConversationAttachment>(
      value: <String, Object?>{
        for (final entry in values.entries) entry.key: _stateEntry(entry.value),
      },
    );
  }

  Future<PluginCallbackResult<ConversationAttachment>> _schedule(
    PluginHostCallContext context,
    String operation,
    Map<String, Object?> arguments,
  ) async {
    final registration = _registration;
    if (registration == null) {
      throw StateError('Scheduled callback registration is not pinned.');
    }
    final bindingId = _requiredString(arguments, 'binding_id');
    final handler = resolvePluginScheduledHandler(
      registration: registration,
      pluginId: context.pluginId,
      executionRevisionHash: context.revisionHash,
      bindingId: bindingId,
    );
    final payload = validatePluginScheduledPayload(
      handler,
      arguments['payload'],
      path: r'$.payload',
    );
    final delay = Duration(
      milliseconds: (_integer(arguments['delay_ms']) ?? 0).clamp(0, 86400000),
    );
    final scheduled = PluginJob(
      id: ids.generate(),
      pluginId: context.pluginId,
      executionRevisionHash: context.revisionHash,
      bindingId: bindingId,
      payload: payload,
      dueAt: clock.nowUtc().add(delay),
      agentId: context.agentId,
      sessionId: context.sessionId,
    );
    await jobs().enqueue(scheduled);
    return PluginCallbackResult<ConversationAttachment>(
      value: <String, Object?>{
        'id': scheduled.id,
        'due_at': scheduled.dueAt.toIso8601String(),
        'continuation': operation == 'scheduler.continue_after_turn',
      },
    );
  }

  @override
  Stream<PluginCallbackResult<ConversationAttachment>> open(
    PluginHostCallContext context,
    String name,
    Map<String, Object?> arguments,
    PluginInvocationCancellation cancellation,
  ) async* {
    yield PluginCallbackResult<ConversationAttachment>(
      value: 'Scheduled handlers cannot open host streams: $name',
      isError: true,
    );
  }
}

final class _ScheduledCancellation implements PluginCancellationSignal {
  final List<void Function()> _listeners = <void Function()>[];
  bool _cancelled = false;

  void bind(PluginCancellationSignal source) => source.onCancel(cancel);

  @override
  void onCancel(void Function() callback) {
    if (_cancelled) {
      callback();
    } else {
      _listeners.add(callback);
    }
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in List<void Function()>.of(_listeners)) {
      listener();
    }
    _listeners.clear();
  }
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
  'workspace' => throw const FormatException(
    'Workspace-scoped state requires a workspace.',
  ),
  _ => throw const FormatException('Unknown plugin state scope.'),
};

Map<String, Object?> _stateEntry(PluginStateEntry entry) => <String, Object?>{
  'revision': entry.revision,
  'value': entry.value,
};

Map<String, Object?> _object(Object? value) => value is Map
    ? <String, Object?>{
        for (final entry in value.entries) entry.key.toString(): entry.value,
      }
    : <String, Object?>{};

List<Object?> _list(Object? value) =>
    value is List ? List<Object?>.from(value) : const <Object?>[];

int? _integer(Object? value) => value is num ? value.toInt() : null;

String _requiredString(Map<String, Object?> value, String key) {
  final result = value[key];
  if (result is! String || result.isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return result;
}
