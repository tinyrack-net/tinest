import 'dart:async';

import 'package:daemon/src/features/plugins/infrastructure/plugin_ports.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_runtime.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';

/// Outcome returned by one durable Lua handler.
final class PluginScheduledHandlerResult {
  /// Creates a scheduled handler outcome.
  const new({this.continueTurn = false, this.prompt = ''});

  /// Whether the host should start a serialized internal turn.
  final bool continueTurn;

  /// Optional input offered to the Agent driver for that internal turn.
  final String prompt;
}

/// Executes one claimed named handler under a cancellable plugin revision.
typedef PluginScheduledJobExecutor =
    Future<PluginScheduledHandlerResult> Function(
      PluginJob job,
      PluginCancellationSignal cancellation,
    );

/// Starts one daemon-owned continuation after the session becomes idle.
typedef PluginContinuationStarter = Future<bool> Function({
  required String sessionId,
  required String turnId,
  required String prompt,
});

/// Durable, single-worker scheduler for plugin handlers and continuations.
///
/// Enqueueing is persisted before the worker is notified. A clean shutdown
/// releases the active lease, so a new daemon may recover the job immediately.
final class DurablePluginScheduler implements PluginJobStore {
  /// Creates a scheduler over one durable job store.
  factory({
    required PluginJobStore store,
    required Clock clock,
    required IdGenerator ids,
    required PluginScheduledJobExecutor execute,
    required bool Function(String sessionId) hasActiveTurn,
    required bool Function(String sessionId) hasPendingInput,
    required PluginContinuationStarter startContinuation,
    Duration pollInterval = const Duration(seconds: 1),
    Duration idlePollInterval = const Duration(milliseconds: 25),
    Duration leaseDuration = const Duration(minutes: 5),
  }) => DurablePluginScheduler._(
    store,
    clock,
    ids,
    execute,
    hasActiveTurn,
    hasPendingInput,
    startContinuation,
    pollInterval,
    idlePollInterval,
    leaseDuration,
  );

  new _(
    this._store,
    this._clock,
    this._ids,
    this._execute,
    this._hasActiveTurn,
    this._hasPendingInput,
    this._startContinuation,
    this.pollInterval,
    this.idlePollInterval,
    this.leaseDuration,
  ) {
    if (pollInterval <= Duration.zero) {
      throw ArgumentError.value(
        pollInterval,
        'pollInterval',
        'Poll interval must be positive.',
      );
    }
    if (idlePollInterval <= Duration.zero) {
      throw ArgumentError.value(
        idlePollInterval,
        'idlePollInterval',
        'Idle poll interval must be positive.',
      );
    }
    if (leaseDuration <= Duration.zero) {
      throw ArgumentError.value(
        leaseDuration,
        'leaseDuration',
        'Lease duration must be positive.',
      );
    }
  }

  final PluginJobStore _store;
  final Clock _clock;
  final IdGenerator _ids;
  final PluginScheduledJobExecutor _execute;
  final bool Function(String sessionId) _hasActiveTurn;
  final bool Function(String sessionId) _hasPendingInput;
  final PluginContinuationStarter _startContinuation;

  /// Frequency at which future due jobs and expired leases are reconsidered.
  final Duration pollInterval;

  /// Frequency used while a continuation waits for its current turn to end.
  final Duration idlePollInterval;

  /// Maximum ownership interval before another daemon may reclaim a job.
  final Duration leaseDuration;

  Timer? _poller;
  Future<void>? _draining;
  _SchedulerCancellation? _activeCancellation;
  bool _drainRequested = false;
  bool _started = false;
  bool _closed = false;

  /// Starts recovery and polling. Calling this more than once is harmless.
  void start() {
    if (_closed) throw StateError('Plugin scheduler is closed.');
    if (_started) return;
    _started = true;
    _poller = Timer.periodic(pollInterval, (_) => _requestDrain());
    _requestDrain();
  }

  void _requestDrain() {
    unawaited(
      drainDueJobs().catchError((Object _, StackTrace _) {
        // Individual job failures are recorded durably. A store-level failure
        // is retried on the next poll instead of escaping a timer callback.
      }),
    );
  }

  /// Claims and executes every job due at the current host-clock instant.
  Future<void> drainDueJobs() {
    if (_closed) return Future<void>.value();
    _drainRequested = true;
    final active = _draining;
    if (active != null) return active;
    late final Future<void> draining;
    draining = _drainLoop().whenComplete(() {
      if (identical(_draining, draining)) _draining = null;
    });
    _draining = draining;
    return draining;
  }

  Future<void> _drainLoop() async {
    do {
      _drainRequested = false;
      while (!_closed) {
        final leaseId = 'plugin-job-lease:${_ids.generate()}';
        final job = await _store.claimNext(
          now: _clock.nowUtc(),
          leaseId: leaseId,
          leaseDuration: leaseDuration,
        );
        if (job == null) break;
        await _runClaimed(job, leaseId);
      }
    } while (_drainRequested && !_closed);
  }

  Future<void> _runClaimed(PluginJob job, String leaseId) async {
    final cancellation = _SchedulerCancellation();
    _activeCancellation = cancellation;
    try {
      final sessionId = job.sessionId;
      if (sessionId != null) {
        while (_hasActiveTurn(sessionId) && !_closed) {
          await Future<void>.delayed(idlePollInterval);
        }
      }
      if (_closed) {
        await _store.release(job.id, leaseId: leaseId);
        return;
      }
      final result = await _execute(job, cancellation);
      if (result.continueTurn) {
        if (sessionId == null) {
          throw StateError(
            'Scheduled continuation ${job.id} has no session owner.',
          );
        }
        if (!_hasPendingInput(sessionId)) {
          while (_hasActiveTurn(sessionId) && !_closed) {
            await Future<void>.delayed(idlePollInterval);
          }
          if (_closed) {
            await _store.release(job.id, leaseId: leaseId);
            return;
          }
          final started = await _startContinuation(
            sessionId: sessionId,
            turnId: _ids.generate(),
            prompt: result.prompt,
          );
          if (!started) {
            throw StateError(
              'Scheduled continuation could not create a unique turn.',
            );
          }
        }
      }
      await _store.complete(job.id, leaseId: leaseId);
    } on Object catch (error) {
      if (_closed) {
        await _store.release(job.id, leaseId: leaseId);
      } else {
        await _store.fail(job.id, leaseId: leaseId, error: '$error');
      }
    } finally {
      if (identical(_activeCancellation, cancellation)) {
        _activeCancellation = null;
      }
    }
  }

  /// Stops polling, cancels the active Lua handler, and releases its lease.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _poller?.cancel();
    _poller = null;
    _activeCancellation?.cancel();
    await _draining;
  }

  @override
  Future<void> enqueue(PluginJob job) async {
    if (_closed) throw StateError('Plugin scheduler is closed.');
    await _store.enqueue(job);
    if (_started) _requestDrain();
  }

  @override
  Future<PluginJob?> get(String id) => _store.get(id);

  @override
  Future<bool> cancel(
    String id, {
    required String pluginId,
    required String agentId,
    required String sessionId,
  }) => _store.cancel(
    id,
    pluginId: pluginId,
    agentId: agentId,
    sessionId: sessionId,
  );

  @override
  Future<PluginJob?> claimNext({
    required DateTime now,
    required String leaseId,
    Duration leaseDuration = const Duration(minutes: 5),
  }) => _store.claimNext(
    now: now,
    leaseId: leaseId,
    leaseDuration: leaseDuration,
  );

  @override
  Future<void> release(String id, {required String leaseId}) =>
      _store.release(id, leaseId: leaseId);

  @override
  Future<void> complete(String id, {required String leaseId}) =>
      _store.complete(id, leaseId: leaseId);

  @override
  Future<void> fail(
    String id, {
    required String leaseId,
    required String error,
  }) => _store.fail(id, leaseId: leaseId, error: error);
}

final class _SchedulerCancellation implements PluginCancellationSignal {
  final List<void Function()> _listeners = <void Function()>[];
  bool _cancelled = false;

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
