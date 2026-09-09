import 'dart:async';

import 'package:agent/agent.dart';
import 'package:daemon/src/shared/infrastructure/persistence/repositories.dart';
import 'package:daemon/src/shared/ports/agent_protocol_mapping.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:daemon/src/transport/rpc/binding.dart';
import 'package:protocol/protocol.dart';

/// Client-mediated interactions that can suspend a running session turn.
abstract interface class SessionInteractionPort {
  /// Resolves a pending tool approval.
  Future<ApprovalRequestDto> resolveApproval(
    String approvalId, {
    required bool approved,
  });

  /// Answers a pending structured user question.
  Future<UserQuestionRequestDto> answerUserQuestion(
    String requestId,
    List<UserQuestionAnswerDto> answers,
  );

  /// Reports queued client input so a waiting agent can resume early.
  void notePendingInput(String sessionId);
}

/// Owns pending approvals, questions, and input notifications.
final class SessionInteractionCoordinator implements SessionInteractionPort {
  /// Creates a coordinator backed by the durable timeline.
  new({
    required TimelineRepository timeline,
    required void Function(OutboundNotification event) events,
    required IdGenerator ids,
    required Clock clock,
  }) : this._(timeline, events, ids, clock);

  new _(this._timeline, this._events, this._ids, this._clock);

  final TimelineRepository _timeline;
  final void Function(OutboundNotification event) _events;
  final IdGenerator _ids;
  final Clock _clock;
  final Map<String, Completer<ApprovalDecision>> _pendingApprovals =
      <String, Completer<ApprovalDecision>>{};
  final Map<String, Completer<List<UserAnswer>>> _pendingQuestions =
      <String, Completer<List<UserAnswer>>>{};
  final Map<String, Completer<void>> _pendingInput =
      <String, Completer<void>>{};
  final Set<String> _notedInput = <String>{};

  /// Consumes a queued-input notification or waits for the next one.
  Future<void> pendingInput(String sessionId) {
    if (_notedInput.remove(sessionId)) return Future<void>.value();
    return _pendingInput.putIfAbsent(sessionId, Completer<void>.new).future;
  }

  /// Clears a stale input notice when a new turn starts.
  void beginTurn(String sessionId) => _notedInput.remove(sessionId);

  /// Whether user input is queued and should win over an internal turn.
  bool hasPendingInput(String sessionId) => _notedInput.contains(sessionId);

  @override
  void notePendingInput(String sessionId) {
    _notedInput.add(sessionId);
    final waiting = _pendingInput.remove(sessionId);
    if (waiting != null && !waiting.isCompleted) waiting.complete();
  }

  @override
  Future<ApprovalRequestDto> resolveApproval(
    String approvalId, {
    required bool approved,
  }) async {
    final status = approved ? ApprovalStatus.approved : ApprovalStatus.denied;
    final approval = await _timeline.resolveApproval(approvalId, status);
    if (approval == null) {
      throw StateError('Approval is not pending: $approvalId');
    }
    _pendingApprovals
        .remove(approvalId)
        ?.complete(
          approved ? ApprovalDecision.approved : ApprovalDecision.denied,
        );
    await _appendEvent(
      sessionId: approval.sessionId,
      turnId: approval.turnId,
      type: 'approval.resolved',
      data: <String, dynamic>{'approvalId': approval.id, 'status': status.name},
    );
    return approval;
  }

  @override
  Future<UserQuestionRequestDto> answerUserQuestion(
    String requestId,
    List<UserQuestionAnswerDto> answers,
  ) async {
    final pending = await _timeline.getUserQuestion(requestId);
    if (pending == null || pending.status != UserQuestionStatus.pending) {
      throw StateError('Question is not pending: $requestId');
    }
    final missing = pending.questions
        .map((question) => question.id)
        .toSet()
        .difference(answers.map((answer) => answer.questionId).toSet());
    if (missing.isNotEmpty) {
      throw StateError('Unanswered questions: ${missing.join(', ')}');
    }
    final request = await _timeline.answerUserQuestion(
      requestId,
      UserQuestionStatus.answered,
      answers,
    );
    if (request == null) {
      throw StateError('Question is not pending: $requestId');
    }
    _pendingQuestions.remove(requestId)?.complete(<UserAnswer>[
      for (final answer in answers)
        UserAnswer(
          questionId: answer.questionId,
          answer: answer.answer,
          isFreeForm: answer.isFreeForm,
        ),
    ]);
    await _appendEvent(
      sessionId: request.sessionId,
      turnId: request.turnId,
      type: 'userQuestion.answered',
      data: <String, dynamic>{
        'requestId': request.id,
        'answers': answers.map((answer) => answer.toJson()).toList(),
      },
    );
    return request;
  }

  /// Builds the approval port for one running turn.
  ApprovalCoordinator approvalsFor({
    required String sessionId,
    required String turnId,
  }) => _TimelineApprovalCoordinator(
    owner: this,
    sessionId: sessionId,
    turnId: turnId,
  );

  /// Builds the question port for one running turn.
  UserQuestionCoordinator questionsFor({
    required String sessionId,
    required String turnId,
    required Future<void> Function(SessionStatus status) reportStatus,
  }) => _TimelineUserQuestionCoordinator(
    owner: this,
    sessionId: sessionId,
    turnId: turnId,
    reportStatus: reportStatus,
  );

  Future<void> _appendEvent({
    required String sessionId,
    required String? turnId,
    required String type,
    required Map<String, dynamic> data,
  }) async {
    final event = await _timeline.append(
      sessionId: sessionId,
      turnId: turnId,
      type: type,
      data: data,
    );
    _events(OutboundNotification(sessionsTimelineEventNotification, event));
  }
}

final class _TimelineUserQuestionCoordinator
    implements UserQuestionCoordinator {
  const new({
    required this.owner,
    required this.sessionId,
    required this.turnId,
    required this.reportStatus,
  });

  final SessionInteractionCoordinator owner;
  final String sessionId;
  final String turnId;
  final Future<void> Function(SessionStatus status) reportStatus;

  @override
  Future<List<UserAnswer>> ask(
    String callId,
    List<UserQuestion> questions,
    CancellationToken cancellation,
  ) async {
    final request = UserQuestionRequestDto(
      id: owner._ids.generate(),
      sessionId: sessionId,
      turnId: turnId,
      toolCallId: callId,
      questions: <UserQuestionItemDto>[
        for (final question in questions)
          UserQuestionItemDto(
            id: question.id,
            header: question.header,
            question: question.question,
            options: <UserQuestionOptionDto>[
              for (final option in question.options)
                UserQuestionOptionDto(
                  label: option.label,
                  description: option.description,
                ),
            ],
          ),
      ],
      status: UserQuestionStatus.pending,
      createdAt: owner._clock.nowUtc(),
    );
    final completer = Completer<List<UserAnswer>>();
    owner._pendingQuestions[request.id] = completer;
    await owner._timeline.createUserQuestion(request);
    await owner._appendEvent(
      sessionId: sessionId,
      turnId: turnId,
      type: 'userQuestion.requested',
      data: <String, dynamic>{'request': request.toJson()},
    );
    owner._events(
      OutboundNotification(sessionsQuestionRequestedNotification, request),
    );
    await reportStatus(SessionStatus.waitingForInput);
    cancellation.onCancel(() {
      final active = owner._pendingQuestions.remove(request.id);
      if (active != null && !active.isCompleted) {
        active.completeError(const AgentCancelledException());
      }
      unawaited(
        owner._timeline.answerUserQuestion(
          request.id,
          UserQuestionStatus.cancelled,
          const <UserQuestionAnswerDto>[],
        ),
      );
    });
    try {
      return await completer.future;
    } finally {
      if (!cancellation.isCancelled) {
        await reportStatus(SessionStatus.running);
      }
    }
  }
}

final class _TimelineApprovalCoordinator implements ApprovalCoordinator {
  const new({
    required this.owner,
    required this.sessionId,
    required this.turnId,
  });

  final SessionInteractionCoordinator owner;
  final String sessionId;
  final String turnId;

  @override
  Future<ApprovalDecision> request(
    ToolInvocation invocation,
    CancellationToken cancellation,
  ) async {
    final approval = ApprovalRequestDto(
      id: owner._ids.generate(),
      sessionId: sessionId,
      turnId: turnId,
      toolCallId: invocation.callId,
      toolName: invocation.name,
      risk: protocolRisk(invocation.risk),
      arguments: invocation.arguments,
      status: ApprovalStatus.pending,
      createdAt: owner._clock.nowUtc(),
      preview: invocation.preview,
    );
    final completer = Completer<ApprovalDecision>();
    owner._pendingApprovals[approval.id] = completer;
    await owner._timeline.createApproval(approval);
    await owner._appendEvent(
      sessionId: sessionId,
      turnId: turnId,
      type: 'approval.requested',
      data: <String, dynamic>{'approval': approval.toJson()},
    );
    owner._events(
      OutboundNotification(sessionsApprovalRequestedNotification, approval),
    );
    cancellation.onCancel(() {
      final active = owner._pendingApprovals.remove(approval.id);
      if (active != null && !active.isCompleted) {
        active.complete(ApprovalDecision.denied);
      }
      unawaited(
        owner._timeline.resolveApproval(approval.id, ApprovalStatus.cancelled),
      );
    });
    return await completer.future;
  }
}
