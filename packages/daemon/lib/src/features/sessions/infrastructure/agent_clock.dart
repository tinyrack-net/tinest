import 'dart:async';

import 'package:agent/agent.dart';

/// Completes once the client queues something for a session.
///
/// The turn queue lives in the client, so the daemon only learns about a
/// waiting prompt when the client says so. A signal that never fires costs
/// nothing: the sleep simply runs its full duration.
typedef PendingInputSignal = Future<void> Function(String sessionId);

/// The host clock the agent's time tools run on.
///
/// A composition-root adapter over the daemon's [Clock] and the pending-input
/// signal, because `agent` cannot depend on `daemon`.
final class SessionAgentClock implements AgentClock {
  /// Creates a [SessionAgentClock] for one session.
  const new({
    required this.clock,
    required this.sessionId,
    required this.pendingInput,
  });

  /// Where the wall time comes from.
  final Clock clock;

  /// Session whose queued input ends a sleep early.
  final String sessionId;

  /// Fires when the client queues something for [sessionId].
  final PendingInputSignal pendingInput;

  @override
  DateTime nowUtc() => clock.nowUtc();

  @override
  Future<SleepOutcome> sleep(
    Duration duration,
    CancellationToken cancellation,
  ) async {
    // A Completer plus a Timer rather than Future.delayed, so the timer is
    // actually cancelled when input or a cancellation wins the race and does
    // not hold the isolate open past the turn.
    final elapsed = Completer<SleepOutcome>();
    final timer = Timer(duration, () {
      if (!elapsed.isCompleted) elapsed.complete(SleepOutcome.elapsed);
    });
    final stopped = Completer<SleepOutcome>();
    cancellation.onCancel(() {
      if (!stopped.isCompleted) stopped.complete(SleepOutcome.elapsed);
    });

    try {
      final outcome = await Future.any(<Future<SleepOutcome>>[
        elapsed.future,
        stopped.future,
        pendingInput(sessionId).then((_) => SleepOutcome.interrupted),
      ]);
      cancellation.throwIfCancelled();
      return outcome;
    } finally {
      timer.cancel();
    }
  }
}
