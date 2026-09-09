import 'dart:async';
import 'dart:math' as math;

import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/features/conversation/application/attachment_ports.dart';
import 'package:app/src/features/conversation/application/composer_controller.dart';
import 'package:app/src/features/conversation/application/pending_turns_controller.dart';
import 'package:app/src/features/hosts/application/host_controller.dart';
import 'package:client/client.dart';
import 'package:protocol/protocol.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'conversation_controller.g.dart';

/// One prompt typed while a turn was still running.
///
/// The daemon runs a single turn per session, so a follow-up waits here until
/// the active turn settles instead of being rejected or silently dropped.
final class QueuedTurn {
  /// Creates a [QueuedTurn].
  const new({
    required this.id,
    required this.text,
    required this.attachments,
    this.attempts = 0,
    this.error,
  });

  /// Identity used to edit or promote one entry.
  final String id;

  /// Trimmed prompt text.
  final String text;

  /// Files that go up with the prompt.
  final List<PendingAttachment> attachments;

  /// Releases already charged against this prompt's retry budget.
  ///
  /// Charged when a retry is armed rather than when a send fails, so every
  /// path that can arm one shares a single budget and none can chain past it.
  final int attempts;

  /// Why the last release failed, once the budget is spent.
  ///
  /// Null while the prompt is merely waiting its turn, which is the state a
  /// reader has to be able to tell apart from one that has stopped trying.
  final String? error;

  /// Returns a copy carrying a new retry budget or failure reason.
  QueuedTurn copyWith({int? attempts, String? error}) => QueuedTurn(
    id: id,
    text: text,
    attachments: attachments,
    attempts: attempts ?? this.attempts,
    error: error ?? this.error,
  );
}

/// One prompt the daemon accepted but has not echoed yet.
///
/// [ConversationController.startTurn] returns as soon as the daemon has created
/// the turn, but the durable `user.message` is only written after plugin
/// lifecycle, skills, and project-doc loading have run — long enough for a sent
/// prompt to look lost. The turn id is the client's own, so the echo is matched
/// exactly rather than by text: two identical prompts must not resolve each
/// other, and cancelling one turn must not erase another turn's prompt.
final class PendingTurn {
  /// Creates a [PendingTurn].
  const new({
    required this.turnId,
    required this.prompt,
    required this.createdAt,
  });

  /// Client-minted identity the daemon stamps on every event of this turn.
  final String turnId;

  /// Trimmed prompt text, rendered as an optimistic user message.
  final String prompt;

  /// When the prompt was submitted, per the app clock.
  final DateTime createdAt;
}

/// ConversationState defines a public contract.
final class ConversationState {
  /// Creates a [ConversationState].
  const new({
    this.timeline = const <TimelineEventDto>[],
    this.approvals = const <String, ApprovalRequestDto>{},
    this.queued = const <QueuedTurn>[],
    this.pending = const <PendingTurn>[],
    this.questions = const <String, UserQuestionRequestDto>{},
    this.hasMoreOlder = false,
    this.loadingOlder = false,
    this.olderFailed = false,
  });

  /// Loaded events, oldest first. A window, not necessarily the whole history.
  final List<TimelineEventDto> timeline;

  /// Whether events exist before [timeline].
  final bool hasMoreOlder;

  /// Whether a page of older events is in flight.
  final bool loadingOlder;

  /// Whether the most recent page attempt failed.
  ///
  /// A failure stops automatic paging until the reader asks again: the page
  /// that failed is the same page, so re-arming the edge on its own would put
  /// the request back on the wire on the next frame, and the frame after that.
  final bool olderFailed;

  /// Sequence of the oldest loaded event, or zero when nothing is loaded.
  int get oldestLoadedSequence =>
      timeline.isEmpty ? 0 : timeline.first.sequence;

  /// The approvals public API member.
  final Map<String, ApprovalRequestDto> approvals;

  /// Prompts waiting for the active turn to finish, oldest first.
  final List<QueuedTurn> queued;

  /// Prompts the daemon accepted whose timeline echo has not arrived, oldest
  /// first. Rendered as optimistic user messages after [timeline].
  final List<PendingTurn> pending;

  /// Questions the agent is blocked on, keyed by request id.
  final Map<String, UserQuestionRequestDto> questions;

  /// The copyWith public API member.
  ConversationState copyWith({
    List<TimelineEventDto>? timeline,
    Map<String, ApprovalRequestDto>? approvals,
    List<QueuedTurn>? queued,
    List<PendingTurn>? pending,
    Map<String, UserQuestionRequestDto>? questions,
    bool? hasMoreOlder,
    bool? loadingOlder,
    bool? olderFailed,
  }) => ConversationState(
    timeline: timeline ?? this.timeline,
    approvals: approvals ?? this.approvals,
    queued: queued ?? this.queued,
    pending: pending ?? this.pending,
    questions: questions ?? this.questions,
    hasMoreOlder: hasMoreOlder ?? this.hasMoreOlder,
    loadingOlder: loadingOlder ?? this.loadingOlder,
    olderFailed: olderFailed ?? this.olderFailed,
  );
}

@riverpod
/// ConversationController defines a public contract.
class ConversationController extends _$ConversationController {
  StreamSubscription<TimelineEventDto>? _timelineEvents;
  StreamSubscription<ApprovalRequestDto>? _approvalEvents;
  StreamSubscription<SessionDto>? _sessionEvents;
  StreamSubscription<UserQuestionRequestDto>? _questionEvents;
  late String? _sessionId;
  // Both the idle session event and an explicit promotion can ask for a drain,
  // so one send is in flight at a time.
  bool _draining = false;
  // A drain asked for while one runs, held rather than dropped: the request
  // refused here is often the only signal that prompt was ever going to get.
  bool _drainAgain = false;
  Timer? _drainRetry;
  // Whether a missing span of history is already being fetched back in.
  bool _filling = false;

  @override
  Future<ConversationState> build(String hostId, String? sessionId) async {
    _sessionId = sessionId;
    final api = await watchConnectedHostApi(ref, hostId);
    if (api == null || sessionId == null) {
      return const ConversationState();
    }
    // Subscribing before the round trip closes the window the daemon cannot
    // cover: it answers with what it held when the call arrived, and a session
    // that is mid-turn keeps writing throughout. These are broadcast streams,
    // so an event delivered while nothing is listening is simply gone — and
    // the events after it are numbered as though it had arrived, which is how
    // one lost delta becomes a hole in the transcript.
    //
    // Nothing can be applied yet: `state` does not exist until this build
    // returns. What arrives first is held here and folded into it below.
    var subscribing = true;
    final heldEvents = <TimelineEventDto>[];
    final heldApprovals = <ApprovalRequestDto>[];
    final heldQuestions = <UserQuestionRequestDto>[];
    _timelineEvents = api.sessions.timelineEvents.listen((event) {
      if (!subscribing) {
        _handleTimeline(event);
      } else if (event.sessionId == sessionId) {
        heldEvents.add(event);
      }
    });
    _approvalEvents = api.sessions.approvalRequests.listen((approval) {
      if (!subscribing) {
        _handleApproval(approval);
      } else if (approval.sessionId == sessionId) {
        heldApprovals.add(approval);
      }
    });
    // Session updates are not held. `_handleSession` only releases a waiting
    // prompt, and a conversation being built has no queue to release.
    _sessionEvents = api.sessions.sessionUpdates.listen(_handleSession);
    _questionEvents = api.sessions.questionRequests.listen((request) {
      if (!subscribing) {
        _handleQuestion(request);
      } else if (request.sessionId == sessionId) {
        heldQuestions.add(request);
      }
    });
    // Registered before the request rather than after it: the subscriptions
    // above already exist, so a snapshot that fails has four of them to cancel.
    ref
      ..onDispose(() => unawaited(_timelineEvents?.cancel()))
      ..onDispose(() => unawaited(_approvalEvents?.cancel()))
      ..onDispose(() => unawaited(_sessionEvents?.cancel()))
      ..onDispose(() => unawaited(_questionEvents?.cancel()))
      ..onDispose(() => _drainRetry?.cancel());
    // Only the newest page: a session stores one row per streamed delta, so
    // the whole history is both a slow first frame and, over a relay, a frame
    // large enough to get the daemon dropped. The daemon aligns the window to
    // a turn boundary, which is also what guarantees the newest `user.message`
    // is present for `_syncPendingFirstTurn` below.
    final window = await api.sessions.subscribeTimeline(
      sessionId,
      tailLimit: timelineHistoryPageSize,
    );
    // Handing over here rather than a frame later is safe: what follows runs
    // to completion without an await, and a socket event cannot be delivered
    // in the middle of a microtask drain.
    subscribing = false;
    final timeline = _continuedBy(window, heldEvents);
    _syncPendingFirstTurn(timeline);
    // Blocking cards belong to the turn that is still running, and the window
    // always contains that turn whole, so folding the window rather than the
    // whole history cannot lose one. A request that was delivered on its own
    // notification need not be in the window at all, so it is applied on top.
    final approvals = _pendingApprovals(timeline);
    for (final approval in heldApprovals) {
      approvals[approval.id] = approval;
    }
    final questions = _pendingQuestions(timeline);
    for (final request in heldQuestions) {
      questions[request.id] = request;
    }
    return ConversationState(
      timeline: timeline,
      approvals: approvals,
      questions: questions,
      hasMoreOlder: timeline.isNotEmpty && timeline.first.sequence > 1,
    );
  }

  /// The subscription [window] continued by what arrived while it was in
  /// flight.
  ///
  /// The snapshot is authoritative through its own last sequence: a held event
  /// at or below it is the same event arriving twice. One below the window
  /// start belongs to a page the reader has not asked for, and prepending it
  /// would move the paging cursor onto a row with a hole behind it.
  static List<TimelineEventDto> _continuedBy(
    List<TimelineEventDto> window,
    List<TimelineEventDto> held,
  ) {
    if (held.isEmpty) return window;
    final floor = window.isEmpty ? 0 : window.last.sequence;
    final seen = <int>{};
    final tail = <TimelineEventDto>[];
    for (final event in held) {
      if (event.sequence <= floor || !seen.add(event.sequence)) continue;
      tail.add(event);
    }
    if (tail.isEmpty) return window;
    tail.sort((left, right) => left.sequence.compareTo(right.sequence));
    return <TimelineEventDto>[...window, ...tail];
  }

  /// Loads the page of history preceding the oldest loaded event.
  ///
  /// A failure leaves the loaded timeline untouched and reports itself, so the
  /// reader can ask for the same page again from the row that announced it.
  Future<void> loadOlderHistory() async {
    final sessionId = _sessionId;
    final current = _currentEventState;
    if (sessionId == null || current == null) return;
    if (current.loadingOlder || !current.hasMoreOlder) return;
    final cursor = current.oldestLoadedSequence;
    if (cursor <= 1) return;
    state = AsyncData<ConversationState>(
      // A retry is in flight, not still failed: the row that announced the
      // failure is the one the reader just used, and it has to say so.
      current.copyWith(loadingOlder: true, olderFailed: false),
    );
    try {
      final api = await requireHostApi(ref, hostId);
      final page = await api.sessions.readTimelineHistory(
        sessionId,
        beforeSequence: cursor,
        limit: timelineHistoryPageSize,
      );
      final live = _currentEventState;
      if (live == null) return;
      // Re-read the cursor: a reconnect may have rewound the window while the
      // page was in flight, and the projector sorts but does not de-duplicate.
      final older = page
          .where((event) => event.sequence < live.oldestLoadedSequence)
          .toList(growable: false);
      final timeline = <TimelineEventDto>[...older, ...live.timeline];
      state = AsyncData<ConversationState>(
        live.copyWith(
          timeline: timeline,
          loadingOlder: false,
          olderFailed: false,
          hasMoreOlder: timeline.isNotEmpty && timeline.first.sequence > 1,
        ),
      );
    } on Object {
      final live = _currentEventState;
      if (live == null) return;
      state = AsyncData<ConversationState>(
        live.copyWith(loadingOlder: false, olderFailed: true),
      );
    }
  }

  /// The startTurn public API member.
  Future<void> startTurn(
    String prompt, {
    List<PendingAttachment> attachments = const <PendingAttachment>[],
    bool queueWhenBusy = true,
  }) async {
    final sessionId = _sessionId;
    if (sessionId == null || (prompt.trim().isEmpty && attachments.isEmpty)) {
      return;
    }
    final turnId = ref.read(appIdGeneratorProvider).generate();
    // Recorded ahead of the upload rather than merely ahead of the RPC: a large
    // attachment holds the send for seconds, and the prompt has to read as sent
    // for all of it.
    _addPending(turnId, prompt.trim());
    final api = await requireHostApi(ref, hostId);
    final uploaded = <AttachmentDto>[];
    for (final attachment in attachments) {
      uploaded.add(
        await api.attachments.uploadAttachment(
          fileName: attachment.fileName,
          mimeType: attachment.mimeType,
          byteSize: attachment.byteSize,
          bytes: attachment.openRead(),
        ),
      );
    }
    try {
      await api.sessions.startTurn(
        sessionId: sessionId,
        turnId: turnId,
        prompt: prompt.trim(),
        attachmentIds: uploaded.map((item) => item.id).toList(growable: false),
      );
    } on Exception {
      // The prompt is no longer in flight whichever way this ends: it either
      // goes back to the composer or becomes a visible queue row, and an
      // optimistic message left behind would be a second copy of it.
      _removePending(turnId);
      // The composer sends or queues from a rendered flag that trails the
      // daemon by one event, so it can send into a turn that is still running.
      // The daemon is the authority: when it says one is, hold the prompt the
      // way the composer would have, rather than handing back an error that
      // reads as "not sent" and drops it.
      if (!queueWhenBusy || !await _hasRunningTurn(api, sessionId)) rethrow;
      enqueueTurn(prompt, attachments: attachments);
    }
  }

  /// Shows [prompt] as sent until the timeline echoes [turnId].
  void _addPending(String turnId, String prompt) {
    final current = _currentEventState;
    // Nothing to render against before the conversation settles, and the first
    // prompt of a new session is already covered by its own pending registry.
    if (current == null || prompt.isEmpty) return;
    state = AsyncData<ConversationState>(
      current.copyWith(
        pending: <PendingTurn>[
          ...current.pending,
          PendingTurn(
            turnId: turnId,
            prompt: prompt,
            createdAt: ref.read(appClockProvider).nowUtc(),
          ),
        ],
      ),
    );
  }

  void _removePending(String turnId) {
    final current = _currentEventState;
    if (current == null) return;
    final pending = _pendingWithout(current.pending, turnId);
    if (identical(pending, current.pending)) return;
    state = AsyncData<ConversationState>(current.copyWith(pending: pending));
  }

  /// Returns [pending] without [turnId], or [pending] itself when absent.
  ///
  /// Identity is the signal a narrowed selector reads, so an event that
  /// resolves nothing must not hand back an equal-but-new list.
  static List<PendingTurn> _pendingWithout(
    List<PendingTurn> pending,
    String? turnId,
  ) {
    if (turnId == null || !pending.any((turn) => turn.turnId == turnId)) {
      return pending;
    }
    return pending
        .where((turn) => turn.turnId != turnId)
        .toList(growable: false);
  }

  Future<bool> _hasRunningTurn(TinestApi api, String sessionId) async {
    try {
      final session = (await api.sessions.listSessions())
          .where((session) => session.id == sessionId)
          .firstOrNull;
      return session != null &&
          session.status != SessionStatus.idle &&
          session.status != SessionStatus.failed;
    } on Exception {
      return false;
    }
  }

  /// The cancelTurn public API member.
  Future<void> cancelTurn() async {
    final sessionId = _sessionId;
    if (sessionId != null) {
      final api = await requireHostApi(ref, hostId);
      await api.sessions.cancelTurn(sessionId);
    }
  }

  /// Holds a prompt until the active turn settles.
  void enqueueTurn(
    String prompt, {
    List<PendingAttachment> attachments = const <PendingAttachment>[],
  }) {
    final text = prompt.trim();
    final current = state.asData?.value;
    if (current == null || (text.isEmpty && attachments.isEmpty)) return;
    state = AsyncData<ConversationState>(
      current.copyWith(
        queued: <QueuedTurn>[
          ...current.queued,
          QueuedTurn(
            id: ref.read(appIdGeneratorProvider).generate(),
            text: text,
            attachments: List<PendingAttachment>.unmodifiable(attachments),
          ),
        ],
      ),
    );
    // Best-effort: it only shortens a sleeping agent's wait, so a failure
    // costs a longer wait and nothing else.
    unawaited(_notePendingInput());
  }

  Future<void> _notePendingInput() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    final TinestApi api;
    try {
      api = await requireHostApi(ref, hostId);
    } on Object {
      // Without a connection there is no queue to release: reconnecting
      // rebuilds this controller from scratch.
      return;
    }
    try {
      await api.sessions.notePendingInput(sessionId);
    } on Object {
      // Not state, so a lost notice is not worth surfacing. The settled check
      // below is liveness rather than a notice, so it still has to run.
    }
    try {
      await _drainIfAlreadySettled(api, sessionId);
    } on Object catch (error) {
      // For a prompt queued after the turn settled this check is the only
      // release it will ever get, so a failed check re-arms rather than
      // stranding the prompt. The reason travels with it: every way of
      // running out of budget has to end somewhere the reader can see.
      _scheduleDrainRetry(error: '$error');
    }
  }

  /// Arms one more release attempt, or stops and records why.
  ///
  /// The only place a retry timer is created. It charges the head's budget
  /// before arming, which is what makes the chain finite by construction.
  void _scheduleDrainRetry({required String error}) {
    if (!ref.mounted) return;
    final current = state.asData?.value;
    final head = current?.queued.firstOrNull;
    if (current == null || head == null) return;
    if (head.attempts >= conversationDrainMaxAttempts) {
      // Out of budget. The prompt stays, but it stops passing for one that is
      // simply waiting its turn, so the reader knows to send or edit it.
      if (head.error == null) {
        state = AsyncData<ConversationState>(
          current.copyWith(
            queued: <QueuedTurn>[
              head.copyWith(error: error),
              ...current.queued.skip(1),
            ],
          ),
        );
      }
      return;
    }
    state = AsyncData<ConversationState>(
      current.copyWith(
        queued: <QueuedTurn>[
          head.copyWith(attempts: head.attempts + 1),
          ...current.queued.skip(1),
        ],
      ),
    );
    _drainRetry?.cancel();
    _drainRetry = Timer(
      conversationDrainRetryDelay,
      () => unawaited(drainQueue()),
    );
  }

  /// Releases the queue when the turn it was waiting on has already finished.
  ///
  /// The composer chooses between sending and queueing from a rendered flag
  /// that trails the daemon by one event, so a prompt can land in the queue
  /// after the session settled. [drainQueue] otherwise runs only from a later
  /// session update, and no such update is coming, which strands the prompt.
  Future<void> _drainIfAlreadySettled(TinestApi api, String sessionId) async {
    if (state.asData?.value.queued.isEmpty ?? true) return;
    final session = (await api.sessions.listSessions())
        .where((session) => session.id == sessionId)
        .firstOrNull;
    if (session == null) return;
    if (session.status == SessionStatus.idle ||
        session.status == SessionStatus.failed) {
      await drainQueue();
    }
  }

  /// Removes one waiting prompt and returns it, so it can be edited again.
  QueuedTurn? takeQueuedTurn(String id) {
    final current = state.asData?.value;
    final item = current?.queued.where((entry) => entry.id == id).firstOrNull;
    if (current == null || item == null) return null;
    state = AsyncData<ConversationState>(
      current.copyWith(
        queued: current.queued
            .where((entry) => entry.id != id)
            .toList(growable: false),
      ),
    );
    return item;
  }

  /// Cancels the active turn and starts one waiting prompt immediately.
  Future<void> sendQueuedTurnNow(String id) async {
    final item = takeQueuedTurn(id);
    if (item == null) return;
    try {
      await cancelTurn();
      await startTurn(item.text, attachments: item.attachments);
    } on Exception {
      _restoreQueuedTurn(item);
      rethrow;
    }
  }

  /// Starts the oldest waiting prompt, if any.
  ///
  /// Exactly one prompt leaves the queue per call: each queued follow-up earns
  /// its own turn, and the next one waits for that turn to settle in turn.
  Future<void> drainQueue() async {
    if (_draining) {
      // Dropping the request drops the prompt when it was the last signal
      // coming, so the running drain picks it up on its way out.
      _drainAgain = true;
      return;
    }
    // Cleared on the way in: a request that arrives from here on is about this
    // run, and a stale flag would cost a pointless extra pass.
    _drainAgain = false;
    final current = state.asData?.value;
    final next = current?.queued.firstOrNull;
    if (current == null || next == null) return;
    _draining = true;
    state = AsyncData<ConversationState>(
      current.copyWith(queued: current.queued.sublist(1)),
    );
    try {
      // Already queued once: re-queueing here would only trade a restore for
      // a loop, so a busy daemon takes the same path as any other failure.
      await startTurn(
        next.text,
        attachments: next.attachments,
        queueWhenBusy: false,
      );
    } on Exception catch (error) {
      // The drain runs from a broadcast event with nobody to await it, so a
      // failed send puts the prompt back rather than disappearing. The event
      // that triggered this drain is often the last one coming, so putting it
      // back is only half the job: it has to be re-armed too.
      _restoreQueuedTurn(next);
      _scheduleDrainRetry(error: '$error');
    } finally {
      _draining = false;
    }
    // drainQueue clears the flag on entry, so this hands over rather than
    // racing: a request arriving during the next run is that run's to keep.
    if (_drainAgain) await drainQueue();
  }

  void _restoreQueuedTurn(QueuedTurn item) {
    if (!ref.mounted) return;
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData<ConversationState>(
      current.copyWith(queued: <QueuedTurn>[item, ...current.queued]),
    );
  }

  /// The resolveApproval public API member.
  Future<void> resolveApproval(
    String approvalId, {
    required bool approved,
  }) async {
    final api = await requireHostApi(ref, hostId);
    await api.sessions.resolveApproval(
      approvalId: approvalId,
      approved: approved,
    );
    if (!ref.mounted) return;
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData<ConversationState>(
      current.copyWith(
        approvals: Map<String, ApprovalRequestDto>.of(current.approvals)
          ..remove(approvalId),
      ),
    );
  }

  /// Answers a pending agent question and lets its turn continue.
  Future<void> answerUserQuestion(
    String requestId,
    List<UserQuestionAnswerDto> answers,
  ) async {
    final api = await requireHostApi(ref, hostId);
    await api.sessions.answerUserQuestion(
      requestId: requestId,
      answers: answers,
    );
    if (!ref.mounted) return;
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData<ConversationState>(
      current.copyWith(
        questions: Map<String, UserQuestionRequestDto>.of(current.questions)
          ..remove(requestId),
      ),
    );
  }

  ConversationState? get _currentEventState {
    if (!ref.mounted) return null;
    return state.asData?.value;
  }

  void _handleTimeline(TimelineEventDto event) {
    if (event.sessionId != _sessionId) return;
    _syncPendingFirstTurn(<TimelineEventDto>[event]);
    final current = _currentEventState;
    if (current == null) return;
    if (current.timeline.any((item) => item.sequence == event.sequence)) {
      return;
    }
    final approvals = Map<String, ApprovalRequestDto>.of(current.approvals);
    final approval = _approvalFromTimeline(event);
    if (approval != null) approvals[approval.id] = approval;
    if (event.type == 'approval.resolved') {
      approvals.remove(event.data['approvalId']);
    }
    // Applied as a delta rather than re-folded from the timeline. A question
    // delivered by its own notification is not in the loaded window, and
    // recomputing would erase it on the very next delta.
    final questions = Map<String, UserQuestionRequestDto>.of(current.questions);
    final request = _questionFromTimeline(event);
    if (request != null && request.status == UserQuestionStatus.pending) {
      questions[request.id] = request;
    }
    if (event.type == 'userQuestion.answered') {
      questions.remove(event.data['requestId']);
    }
    if (event.type == 'turn.completed' ||
        event.type == 'turn.failed' ||
        event.type == 'turn.cancelled') {
      // The daemon cancels a blocked question on restart without writing an
      // answer, so a card whose turn ended can never be resolved.
      questions.removeWhere((_, item) => item.turnId == event.turnId);
    }
    // A bounded reconnect catch-up can resume above the last event seen. The
    // events between are real, and so is everything already loaded: the reader
    // is reading it. The window keeps what it holds and the missing span is
    // fetched back into place, rather than the transcript being replaced by
    // the one event that exposed the hole.
    if (current.timeline.isNotEmpty &&
        event.sequence > current.timeline.last.sequence + 1) {
      unawaited(
        _fillGap(
          from: current.timeline.last.sequence + 1,
          to: event.sequence - 1,
        ),
      );
    }
    final timeline = <TimelineEventDto>[...current.timeline, event];
    // Resolved in the same write that appends the event it echoes. Clearing it
    // separately would take the optimistic message off screen one frame before
    // the durable one arrives, which reads as the list flickering on send.
    final pending = _resolvesPending(event.type)
        ? _pendingWithout(current.pending, event.turnId)
        : current.pending;
    state = AsyncData<ConversationState>(
      current.copyWith(
        timeline: timeline,
        approvals: approvals,
        questions: questions,
        pending: pending,
      ),
    );
  }

  /// Fetches the span [from]..[to], which was written while nothing was
  /// listening or skipped by a bounded catch-up.
  ///
  /// A span wider than one page is filled from its newest end and the rest is
  /// left missing. The alternative is holding a transcript the reader is in
  /// the middle of hostage to an absence long enough to have written a page of
  /// history, and a bounded inaccuracy above them beats losing all of it.
  ///
  /// One at a time: a second hole opening while a fill is in flight is left to
  /// the reader's own paging, which is the path that reports what it is doing.
  ///
  /// The caller only has a hole to report when [to] is at least [from], so an
  /// empty span never reaches here.
  Future<void> _fillGap({required int from, required int to}) async {
    final sessionId = _sessionId;
    if (_filling || sessionId == null) return;
    _filling = true;
    try {
      final api = await requireHostApi(ref, hostId);
      final span = to - from + 1;
      final page = await api.sessions.readTimelineHistory(
        sessionId,
        beforeSequence: to + 1,
        limit: math.min(span, timelineHistoryPageSize),
      );
      final live = _currentEventState;
      if (live == null) return;
      // A history read is aligned to a turn boundary, so it answers with rows
      // either side of the span as well. Only what is inside the hole belongs
      // here: extending the window is the reader's own paging to ask for.
      final loaded = <int>{for (final event in live.timeline) event.sequence};
      final missing = page
          .where(
            (event) =>
                event.sequence >= from &&
                event.sequence <= to &&
                !loaded.contains(event.sequence),
          )
          .toList(growable: false);
      if (missing.isEmpty) return;
      final timeline = <TimelineEventDto>[...live.timeline, ...missing]
        ..sort((left, right) => left.sequence.compareTo(right.sequence));
      state = AsyncData<ConversationState>(live.copyWith(timeline: timeline));
    } on Object {
      // The transcript the reader is holding is unchanged either way. The row
      // that reports a failure belongs to a page they asked for themselves;
      // this repair was never something they set in motion.
    } finally {
      _filling = false;
    }
  }

  /// Whether [type] is durable evidence that an optimistic prompt is settled.
  ///
  /// The echo is the authority for a prompt that landed; a terminal turn event
  /// is the authority for one that never will.
  static bool _resolvesPending(String type) =>
      type == 'user.message' ||
      type == 'turn.completed' ||
      type == 'turn.failed' ||
      type == 'turn.cancelled';

  /// Resolves the optimistic first prompt from durable timeline evidence.
  ///
  /// The start-turn RPC only means that the daemon accepted the request. The
  /// user bubble is authoritative once the timeline echoes `user.message`,
  /// while a terminal turn event is the authoritative pre-echo failure.
  void _syncPendingFirstTurn(Iterable<TimelineEventDto> events) {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    final pending = ref.read(pendingFirstTurnsProvider)[sessionId];
    if (pending == null) return;
    if (events.any((event) => event.type == 'user.message')) {
      ref.read(pendingFirstTurnsProvider.notifier).clear(sessionId);
      return;
    }
    if (events.any(
      (event) => event.type == 'turn.failed' || event.type == 'turn.cancelled',
    )) {
      ref.read(pendingFirstTurnsProvider.notifier).markFailed(sessionId);
    }
  }

  void _handleApproval(ApprovalRequestDto approval) {
    final current = _currentEventState;
    if (current == null || approval.sessionId != _sessionId) return;
    state = AsyncData<ConversationState>(
      current.copyWith(
        approvals: <String, ApprovalRequestDto>{
          ...current.approvals,
          approval.id: approval,
        },
      ),
    );
  }

  void _handleSession(SessionDto session) {
    final current = _currentEventState;
    if (current == null) return;
    if (session.id == _sessionId &&
        current.queued.isNotEmpty &&
        (session.status == SessionStatus.idle ||
            session.status == SessionStatus.failed)) {
      unawaited(drainQueue());
    }
  }

  void _handleQuestion(UserQuestionRequestDto request) {
    final current = _currentEventState;
    if (current == null || request.sessionId != _sessionId) return;
    state = AsyncData<ConversationState>(
      current.copyWith(
        questions: <String, UserQuestionRequestDto>{
          ...current.questions,
          request.id: request,
        },
      ),
    );
  }

  Map<String, ApprovalRequestDto> _pendingApprovals(
    List<TimelineEventDto> timeline,
  ) {
    final approvals = <String, ApprovalRequestDto>{};
    for (final event in timeline) {
      final approval = _approvalFromTimeline(event);
      if (approval != null && approval.status == ApprovalStatus.pending) {
        approvals[approval.id] = approval;
      }
      if (event.type == 'approval.resolved') {
        approvals.remove(event.data['approvalId']);
      }
    }
    return approvals;
  }

  /// Questions still awaiting an answer, derived from the timeline.
  ///
  /// A question whose turn already ended is dropped: the daemon cancels it on
  /// restart without writing an answer event, so leaving it would strand a card
  /// the user can never resolve.
  Map<String, UserQuestionRequestDto> _pendingQuestions(
    List<TimelineEventDto> timeline,
  ) {
    final questions = <String, UserQuestionRequestDto>{};
    final terminated = <String?>{
      for (final event in timeline)
        if (event.type == 'turn.completed' ||
            event.type == 'turn.failed' ||
            event.type == 'turn.cancelled')
          event.turnId,
    };
    for (final event in timeline) {
      final request = _questionFromTimeline(event);
      if (request != null && request.status == UserQuestionStatus.pending) {
        questions[request.id] = request;
      }
      if (event.type == 'userQuestion.answered') {
        questions.remove(event.data['requestId']);
      }
    }
    questions.removeWhere((_, request) => terminated.contains(request.turnId));
    return questions;
  }

  UserQuestionRequestDto? _questionFromTimeline(TimelineEventDto event) {
    if (event.type != 'userQuestion.requested') return null;
    final raw = event.data['request'];
    return raw is Map<dynamic, dynamic>
        ? UserQuestionRequestDto.fromJson(Map<String, dynamic>.from(raw))
        : null;
  }

  ApprovalRequestDto? _approvalFromTimeline(TimelineEventDto event) {
    if (event.type != 'approval.requested') return null;
    final raw = event.data['approval'];
    return raw is Map<dynamic, dynamic>
        ? ApprovalRequestDto.fromJson(Map<String, dynamic>.from(raw))
        : null;
  }
}
