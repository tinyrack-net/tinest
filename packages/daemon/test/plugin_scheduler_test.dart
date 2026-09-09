import 'dart:async';

import 'package:daemon/src/features/plugins/infrastructure/memory_plugin_stores.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_ports.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_scheduler.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:test/test.dart';

void main() {
  test('durable jobs execute in order and wait for an idle session before '
      'continuing', () async {
    final store = MemoryPluginJobStore();
    final clock = _FakeClock(DateTime.utc(2026, 8, 12));
    final handled = <String>[];
    final continuations = <String>[];
    var active = true;
    final scheduler = DurablePluginScheduler(
      store: store,
      clock: clock,
      ids: _SequenceIds(),
      idlePollInterval: const Duration(milliseconds: 1),
      execute: (job, cancellation) async {
        handled.add(job.id);
        return const PluginScheduledHandlerResult(continueTurn: true);
      },
      hasActiveTurn: (_) => active,
      hasPendingInput: (_) => false,
      startContinuation:
          ({required sessionId, required turnId, required prompt}) async {
            continuations.add('$sessionId:$turnId:$prompt');
            return true;
          },
    );
    addTearDown(scheduler.close);

    await scheduler.enqueue(
      PluginJob(
        id: 'job-b',
        pluginId: 'example.goal',
        executionRevisionHash: 'goal-execution-revision',
        bindingId: 'scheduled',
        payload: const <String, dynamic>{},
        dueAt: clock.nowUtc(),
        agentId: 'agent-1',
        sessionId: 'session-1',
      ),
    );
    await scheduler.enqueue(
      PluginJob(
        id: 'job-a',
        pluginId: 'example.goal',
        executionRevisionHash: 'goal-execution-revision',
        bindingId: 'scheduled',
        payload: const <String, dynamic>{},
        dueAt: clock.nowUtc(),
        agentId: 'agent-1',
        sessionId: 'session-1',
      ),
    );

    final draining = scheduler.drainDueJobs();
    await Future<void>.delayed(Duration.zero);
    expect(continuations, isEmpty);
    active = false;
    await draining;

    expect(handled, <String>['job-a', 'job-b']);
    expect(continuations, <String>[
      'session-1:generated-2:',
      'session-1:generated-4:',
    ]);
    expect((await store.get('job-a'))!.status, PluginJobStatus.completed);
    expect((await store.get('job-b'))!.status, PluginJobStatus.completed);
  }, tags: <String>['feature_test__plugin_runtime__unit']);

  test('rejects non-positive scheduler intervals', () {
    for (final durations in <(Duration, Duration, Duration)>[
      (
        Duration.zero,
        const Duration(milliseconds: 1),
        const Duration(seconds: 1),
      ),
      (const Duration(seconds: 1), Duration.zero, const Duration(seconds: 1)),
      (
        const Duration(seconds: 1),
        const Duration(milliseconds: 1),
        Duration.zero,
      ),
    ]) {
      expect(
        () => _scheduler(
          store: MemoryPluginJobStore(),
          pollInterval: durations.$1,
          idlePollInterval: durations.$2,
          leaseDuration: durations.$3,
        ),
        throwsArgumentError,
      );
    }
  });

  test(
    'pending input suppresses continuation without failing the job',
    () async {
      final store = MemoryPluginJobStore();
      var starts = 0;
      final scheduler = _scheduler(
        store: store,
        execute: (_, _) async => const PluginScheduledHandlerResult(
          continueTurn: true,
          prompt: 'resume',
        ),
        hasPendingInput: (_) => true,
        startContinuation:
            ({required sessionId, required turnId, required prompt}) async {
              starts += 1;
              return true;
            },
      );
      addTearDown(scheduler.close);
      await scheduler.enqueue(_job('pending-input'));

      await scheduler.drainDueJobs();

      expect(starts, 0);
      expect(
        (await store.get('pending-input'))!.status,
        PluginJobStatus.completed,
      );
    },
  );

  test('records invalid continuation outcomes as durable failures', () async {
    final cases = <(String, PluginJob, PluginContinuationStarter)>[
      (
        'missing-session',
        _job('missing-session', sessionId: null),
        ({required sessionId, required turnId, required prompt}) async => true,
      ),
      (
        'duplicate-turn',
        _job('duplicate-turn'),
        ({required sessionId, required turnId, required prompt}) async => false,
      ),
    ];
    for (final entry in cases) {
      final store = MemoryPluginJobStore();
      final scheduler = _scheduler(
        store: store,
        execute: (_, _) async =>
            const PluginScheduledHandlerResult(continueTurn: true),
        startContinuation: entry.$3,
      );
      await scheduler.enqueue(entry.$2);
      await scheduler.drainDueJobs();
      expect((await store.get(entry.$1))!.status, PluginJobStatus.failed);
      await scheduler.close();
    }
  });

  test('a handler exception is isolated to its claimed job', () async {
    final store = MemoryPluginJobStore();
    final scheduler = _scheduler(
      store: store,
      execute: (job, _) async {
        if (job.id == 'failed') throw StateError('handler failed');
        return const PluginScheduledHandlerResult();
      },
    );
    addTearDown(scheduler.close);
    await scheduler.enqueue(_job('failed'));
    await scheduler.enqueue(_job('completed'));

    await scheduler.drainDueJobs();

    expect((await store.get('failed'))!.status, PluginJobStatus.failed);
    expect((await store.get('failed'))!.error, contains('handler failed'));
    expect((await store.get('completed'))!.status, PluginJobStatus.completed);
  });

  test(
    'close cancels an active handler, releases its lease, and is idempotent',
    () async {
      final store = MemoryPluginJobStore();
      final started = Completer<void>();
      final stopped = Completer<void>();
      var lateCancellationNotifications = 0;
      final scheduler = _scheduler(
        store: store,
        execute: (_, cancellation) async {
          started.complete();
          cancellation.onCancel(() {
            cancellation.onCancel(() => lateCancellationNotifications += 1);
            stopped.completeError(StateError('cancelled'));
          });
          await stopped.future;
          return const PluginScheduledHandlerResult();
        },
      );
      await scheduler.enqueue(_job('active'));
      final draining = scheduler.drainDueJobs();
      await started.future;

      await scheduler.close();
      await draining;
      await scheduler.close();

      expect(lateCancellationNotifications, 1);
      expect((await store.get('active'))!.status, PluginJobStatus.pending);
      await expectLater(scheduler.enqueue(_job('closed')), throwsStateError);
      expect(scheduler.start, throwsStateError);
      await scheduler.drainDueJobs();
    },
  );

  test(
    'start is idempotent and store operations remain explicitly scoped',
    () async {
      final store = MemoryPluginJobStore();
      final handled = Completer<void>();
      final scheduler = _scheduler(
        store: store,
        pollInterval: const Duration(milliseconds: 5),
        execute: (_, _) async {
          if (!handled.isCompleted) handled.complete();
          return const PluginScheduledHandlerResult();
        },
      );
      addTearDown(scheduler.close);
      await scheduler.enqueue(_job('started'));

      scheduler
        ..start()
        ..start();
      await handled.future.timeout(const Duration(seconds: 1));
      await scheduler.drainDueJobs();
      expect(
        (await scheduler.get('started'))!.status,
        PluginJobStatus.completed,
      );

      await scheduler.enqueue(
        _job('cancelled', dueAt: DateTime.utc(2026, 8, 13)),
      );
      expect(
        await scheduler.cancel(
          'cancelled',
          pluginId: 'example.goal',
          agentId: 'agent-1',
          sessionId: 'session-1',
        ),
        isTrue,
      );
    },
  );
}

DurablePluginScheduler _scheduler({
  required PluginJobStore store,
  PluginScheduledJobExecutor? execute,
  bool Function(String sessionId)? hasActiveTurn,
  bool Function(String sessionId)? hasPendingInput,
  PluginContinuationStarter? startContinuation,
  Duration pollInterval = const Duration(seconds: 1),
  Duration idlePollInterval = const Duration(milliseconds: 1),
  Duration leaseDuration = const Duration(seconds: 1),
}) => DurablePluginScheduler(
  store: store,
  clock: _FakeClock(DateTime.utc(2026, 8, 12)),
  ids: _SequenceIds(),
  execute: execute ?? (_, _) async => const PluginScheduledHandlerResult(),
  hasActiveTurn: hasActiveTurn ?? (_) => false,
  hasPendingInput: hasPendingInput ?? (_) => false,
  startContinuation:
      startContinuation ??
      ({required sessionId, required turnId, required prompt}) async => true,
  pollInterval: pollInterval,
  idlePollInterval: idlePollInterval,
  leaseDuration: leaseDuration,
);

PluginJob _job(String id, {String? sessionId = 'session-1', DateTime? dueAt}) =>
    PluginJob(
      id: id,
      pluginId: 'example.goal',
      executionRevisionHash: 'goal-execution-revision',
      bindingId: 'scheduled',
      payload: const <String, dynamic>{},
      dueAt: dueAt ?? DateTime.utc(2026, 8, 12),
      agentId: 'agent-1',
      sessionId: sessionId,
    );

final class _FakeClock implements Clock {
  new(this.value);

  DateTime value;

  @override
  DateTime nowUtc() => value;
}

final class _SequenceIds implements IdGenerator {
  int _next = 0;

  @override
  String generate() => 'generated-${++_next}';
}
