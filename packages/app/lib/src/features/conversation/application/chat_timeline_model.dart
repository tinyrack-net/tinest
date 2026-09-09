import 'dart:convert';
import 'dart:typed_data';

import 'package:app/src/features/conversation/application/chat_tool_presentation.dart';
import 'package:app/src/features/plugins/application/plugin_ui_events.dart';
import 'package:protocol/protocol.dart';

/// Loads authenticated attachment bytes for preview.
typedef ChatAttachmentLoader = Future<Uint8List> Function(
  ChatAttachment attachment,
);

/// Exports an authenticated attachment through the platform adapter.
typedef ChatAttachmentExporter = Future<void> Function(
  ChatAttachment attachment,
);

/// One renderable entry of a session conversation.
///
/// The projection collapses many raw [TimelineEventDto]s into a small set of
/// typed items so the UI never has to inspect event names or dump raw data.
sealed class ChatItem {
  /// Creates a chat item.
  const new({required this.key, required this.turnId, required this.createdAt});

  /// Stable identity used as a list key; never changes as events arrive.
  final String key;

  /// Turn that produced this item, when the daemon recorded one.
  final String? turnId;

  /// Instant of the first event backing this item.
  final DateTime createdAt;
}

/// A prompt submitted by the user.
final class ChatUserMessage extends ChatItem {
  /// Creates a user message.
  const new({
    required super.key,
    required super.turnId,
    required super.createdAt,
    required this.text,
    this.attachments = const <ChatAttachment>[],
  });

  /// The prompt text.
  final String text;

  /// Ordered files submitted with the prompt.
  final List<ChatAttachment> attachments;
}

/// Renderable attachment metadata copied into the timeline.
final class ChatAttachment {
  /// Creates attachment presentation metadata.
  const new({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.byteSize,
  });

  /// Stable daemon identifier.
  final String id;

  /// Display filename.
  final String fileName;

  /// Validated media type.
  final String mimeType;

  /// Exact payload length.
  final int byteSize;

  /// Whether the attachment can be previewed as an image.
  bool get isImage => <String>{
    'image/png',
    'image/jpeg',
    'image/webp',
    'image/gif',
  }.contains(mimeType);
}

/// One file explicitly attached by the assistant.
final class ChatAttachmentMessage extends ChatItem {
  /// Creates an assistant attachment row.
  const new({
    required super.key,
    required super.turnId,
    required super.createdAt,
    required this.attachment,
  });

  /// Published attachment.
  final ChatAttachment attachment;
}

/// Assistant prose merged from every delta of one uninterrupted block.
final class ChatAssistantMessage extends ChatItem {
  /// Creates an assistant message.
  const new({
    required super.key,
    required super.turnId,
    required super.createdAt,
    required this.markdown,
    this.isStreaming = false,
  });

  /// Markdown source assembled from the block's deltas.
  final String markdown;

  /// Whether the turn is still producing text.
  final bool isStreaming;
}

/// One provider invocation's display-safe reasoning text.
final class ChatReasoningActivity extends ChatItem {
  /// Creates a reasoning timeline item.
  const new({
    required super.key,
    required super.turnId,
    required super.createdAt,
    required this.markdown,
    required this.isStreaming,
  });

  /// Provider-authored plaintext reasoning or reasoning summary.
  final String markdown;

  /// Whether the provider invocation is still reasoning.
  final bool isStreaming;
}

/// A declarative plugin UI snapshot persisted with the conversation event.
final class ChatPluginUiDocument extends ChatItem {
  /// Creates a historical plugin UI timeline item.
  const new({
    required super.key,
    required super.turnId,
    required super.createdAt,
    required this.document,
  });

  /// Exact revision-pinned document recorded when the event was emitted.
  final PluginUiDocumentDto document;
}

/// Lifecycle shared by actionable conversation rows.
enum ChatInteractionStatus {
  /// The user can still act on the request.
  pending,

  /// The request has been resolved and remains in history.
  resolved,
}

/// One tool approval, retained in the timeline after it is resolved.
final class ChatApprovalInteraction extends ChatItem {
  /// Creates an approval timeline row.
  const new({
    required super.key,
    required super.turnId,
    required super.createdAt,
    required this.approval,
    required this.status,
    this.approved,
  });

  /// The request and preview supplied by the daemon.
  final ApprovalRequestDto approval;

  /// Whether the row is still actionable.
  final ChatInteractionStatus status;

  /// The recorded decision, null while pending.
  final bool? approved;
}

/// One pending question occupying its eventual answer's timeline slot.
final class ChatQuestionInteraction extends ChatItem {
  /// Creates a question timeline row.
  const new({
    required super.key,
    required super.turnId,
    required super.createdAt,
    required this.request,
  });

  /// The questions awaiting answers.
  final UserQuestionRequestDto request;
}

/// Lifecycle of one tool call.
enum ChatToolStatus {
  /// The tool was requested and has not reported a result yet.
  running,

  /// The tool returned a result.
  succeeded,

  /// The tool threw before returning a result.
  failed,

  /// The user rejected the approval request.
  denied,
}

/// One tool call with its request and result merged.
final class ChatToolActivity extends ChatItem {
  /// Creates a tool activity.
  const new({
    required super.key,
    required super.turnId,
    required super.createdAt,
    required this.callId,
    required this.toolName,
    required this.arguments,
    required this.status,
    this.presentation = const <String, dynamic>{},
    this.output,
    this.error,
    this.isError = false,
  });

  /// Provider-assigned identifier shared by the request and its result.
  final String callId;

  /// Tool identifier, for example `exec_command`.
  final String toolName;

  /// Requested arguments; empty when only the result survived in history.
  final Map<String, dynamic> arguments;

  /// Immutable presentation metadata captured from the pinned contribution.
  final Map<String, dynamic> presentation;

  /// Lifecycle state of this call.
  final ChatToolStatus status;

  /// Raw tool output; some tools encode JSON inside this string.
  final String? output;

  /// Failure message when [status] is [ChatToolStatus.failed].
  final String? error;

  /// Whether a returned result reported a tool-level error.
  final bool isError;
}

/// Terminal state of one turn.
enum ChatNoticeKind {
  /// The turn finished normally.
  turnCompleted,

  /// The turn ended with an error.
  turnFailed,

  /// The user cancelled the turn.
  turnCancelled,
}

/// A short status line closing one turn.
final class ChatNotice extends ChatItem {
  /// Creates a turn notice.
  const new({
    required super.key,
    required super.turnId,
    required super.createdAt,
    required this.kind,
    this.message,
    this.toolRounds,
  });

  /// Which terminal state this notice reports.
  final ChatNoticeKind kind;

  /// Failure text for [ChatNoticeKind.turnFailed].
  final String? message;

  /// Tool rounds reported by a completed turn.
  final int? toolRounds;
}

/// One question the agent asked and the answer the user gave.
final class ChatQuestionAnswer {
  /// Creates a question-and-answer pair.
  const new({
    required this.header,
    required this.question,
    required this.answer,
    required this.isFreeForm,
  });

  /// The short label the agent gave the question.
  final String header;

  /// The question as it was put to the user.
  final String question;

  /// What the user chose, or typed when [isFreeForm].
  final String answer;

  /// Whether the user typed the answer instead of taking an option.
  final bool isFreeForm;
}

/// An answered `request_user_input` call, read as conversation rather than
/// tool output.
final class ChatUserAnswer extends ChatItem {
  /// Creates an answered-question item.
  const new({
    required super.key,
    required super.turnId,
    required super.createdAt,
    required this.entries,
  });

  /// Every question of the call, paired with its answer.
  final List<ChatQuestionAnswer> entries;
}

/// One `sleep` call, rendered as a countdown rather than a tool row.
final class ChatSleep extends ChatItem {
  /// Creates a sleep item.
  const new({
    required super.key,
    required super.turnId,
    required super.createdAt,
    required this.duration,
    required this.startedAt,
    required this.isRunning,
    this.reason,
  });

  /// How long the agent asked to wait.
  final Duration duration;

  /// When the request was recorded, so elapsed time is recomputed on replay.
  final DateTime startedAt;

  /// Whether the wait is still in progress.
  final bool isRunning;

  /// What the agent said it was waiting for.
  final String? reason;
}

/// A notice that some tools were withheld from the model's tool list.
final class ChatDeferredTools extends ChatItem {
  /// Creates a deferred-tools notice.
  const new({
    required super.key,
    required super.turnId,
    required super.createdAt,
    required this.count,
  });

  /// How many tools are reachable only through a search.
  final int count;
}

/// Token accounting reported by the provider.
final class ChatUsage extends ChatItem {
  /// Creates a usage item.
  const new({
    required super.key,
    required super.turnId,
    required super.createdAt,
    required this.tokens,
  });

  /// Provider-defined token counters.
  final Map<String, num> tokens;
}

/// An event this build does not know how to render yet.
final class ChatUnknownEvent extends ChatItem {
  /// Creates an unknown-event item.
  const new({
    required super.key,
    required super.turnId,
    required super.createdAt,
    required this.type,
    required this.data,
  });

  /// Raw event type.
  final String type;

  /// Raw event payload, shown only when the user expands the row.
  final Map<String, dynamic> data;
}

/// Projects a persisted timeline into ordered, renderable chat items.
///
/// Assistant deltas of one turn merge across interleaved tool calls, tool
/// requests merge with their results, and live approval or question snapshots
/// merge with persisted events into one stable interaction row.
List<ChatItem> projectChatTimeline(
  List<TimelineEventDto> events, {
  Map<String, ApprovalRequestDto> approvals =
      const <String, ApprovalRequestDto>{},
  Map<String, UserQuestionRequestDto> questions =
      const <String, UserQuestionRequestDto>{},
}) {
  final ordered = List<TimelineEventDto>.of(events)
    ..sort((left, right) => left.sequence.compareTo(right.sequence));
  final builders = <_ChatItemBuilder>[];
  final openAssistant = <String?, _AssistantBuilder>{};
  final openReasoning = <String?, _ReasoningBuilder>{};
  final openTools = <String, _ToolBuilder>{};
  final openSleeps = <String, _SleepBuilder>{};
  final openQuestions = <String, _QuestionBuilder>{};
  final openApprovals = <String, _ApprovalBuilder>{};
  final terminatedTurns = <String?>{};

  void closeAssistant(String? turnId) => openAssistant.remove(turnId);
  void closeReasoning(String? turnId) {
    openReasoning.remove(turnId)?.complete();
  }

  for (final event in ordered) {
    final turnId = event.turnId;
    final pluginDocument = pluginUiDocumentFromJson(
      event.data['uiDocument'] ??
          (event.type == 'plugin.ui' ? event.data['document'] : null),
    );
    if (pluginDocument != null &&
        pluginDocument.slot == PluginUiSlot.timeline) {
      closeAssistant(turnId);
      closeReasoning(turnId);
      final callId = _string(event.data['callId']);
      if (callId != null) {
        final tool = openTools.remove('$turnId/$callId');
        if (tool != null) builders.remove(tool);
      }
      builders.add(
        _StaticBuilder(
          ChatPluginUiDocument(
            key: 'plugin-ui-${pluginDocument.id}-${event.sequence}',
            turnId: turnId,
            createdAt: event.createdAt,
            document: pluginDocument,
          ),
        ),
      );
      continue;
    }
    // Non-timeline plugin publications are consumed by their host-owned slot.
    // They remain durable events for audit/replay, but must not fall through to
    // the generic unknown-event disclosure in the conversation.
    if (event.type == 'plugin.ui' && event.data['document'] != null) continue;
    if (event.type != 'assistant.reasoning.started' &&
        event.type != 'assistant.reasoning.delta') {
      closeReasoning(turnId);
    }
    switch (event.type) {
      case 'user.message':
        closeAssistant(turnId);
        builders.add(
          _StaticBuilder(
            ChatUserMessage(
              key: 'user-${event.sequence}',
              turnId: turnId,
              createdAt: event.createdAt,
              text: _string(event.data['text']) ?? '',
              attachments: _attachments(event.data['attachments']),
            ),
          ),
        );
      case 'assistant.attachment':
        closeAssistant(turnId);
        final attachment = _attachment(event.data);
        if (attachment != null) {
          builders.add(
            _StaticBuilder(
              ChatAttachmentMessage(
                key: 'attachment-${event.sequence}',
                turnId: turnId,
                createdAt: event.createdAt,
                attachment: attachment,
              ),
            ),
          );
        }
      case 'assistant.delta':
        closeReasoning(turnId);
        final text = _string(event.data['text']) ?? '';
        final blockId = _string(event.data['blockId']);
        final open = openAssistant[turnId];
        if (open != null && _continues(open.blockId, blockId)) {
          open.append(text);
        } else {
          final builder = _AssistantBuilder(
            key: 'assistant-${blockId ?? event.sequence}',
            blockId: blockId,
            turnId: turnId,
            createdAt: event.createdAt,
          )..append(text);
          openAssistant[turnId] = builder;
          builders.add(builder);
        }
      case 'assistant.reasoning.started':
        closeAssistant(turnId);
        closeReasoning(turnId);
        final blockId = _string(event.data['blockId']);
        final builder = _ReasoningBuilder(
          key: 'reasoning-${blockId ?? event.sequence}',
          blockId: blockId,
          turnId: turnId,
          createdAt: event.createdAt,
        );
        openReasoning[turnId] = builder;
        builders.add(builder);
      case 'assistant.reasoning.delta':
        closeAssistant(turnId);
        final text = _string(event.data['text']) ?? '';
        final blockId = _string(event.data['blockId']);
        final builder = openReasoning[turnId];
        if (builder != null && _continues(builder.blockId, blockId)) {
          builder.append(text);
        } else {
          final synthesized = _ReasoningBuilder(
            key: 'reasoning-${blockId ?? event.sequence}',
            blockId: blockId,
            turnId: turnId,
            createdAt: event.createdAt,
          )..append(text);
          openReasoning[turnId] = synthesized;
          builders.add(synthesized);
        }
      case 'assistant.reasoning.completed':
        closeAssistant(turnId);
        closeReasoning(turnId);
      case 'tool.requested':
        closeAssistant(turnId);
        // A tool that renders as its own item wants no row beside it, which
        // is a fact each presenter states rather than a set kept here.
        if (_timelineOf(event) == ChatToolTimeline.suppressed) continue;
        final callId = _string(event.data['callId']) ?? '';
        if (_timelineOf(event) == ChatToolTimeline.question &&
            !openQuestions.containsKey('$turnId/$callId')) {
          // A pending question renders from conversation state, so a tool row
          // beside it would only duplicate it; the answer replaces both.
          final builder = _QuestionBuilder(
            key: _questionKey(turnId, callId),
            turnId: turnId,
            createdAt: event.createdAt,
            callId: callId,
            toolName: _string(event.data['name']) ?? '',
            presentation: _map(event.data['presentation']),
            questions: _map(event.data['arguments'])['questions'],
          );
          openQuestions['$turnId/$callId'] = builder;
          builders.add(builder);
          continue;
        }
        if (_timelineOf(event) == ChatToolTimeline.sleep &&
            !openSleeps.containsKey('$turnId/$callId')) {
          final arguments = _map(event.data['arguments']);
          final milliseconds = arguments['duration_ms'];
          if (milliseconds is int && milliseconds > 0) {
            final builder = _SleepBuilder(
              key: 'sleep-$callId-${event.sequence}',
              turnId: turnId,
              createdAt: event.createdAt,
              duration: Duration(milliseconds: milliseconds),
              reason: _string(arguments['reason']),
            );
            openSleeps['$turnId/$callId'] = builder;
            builders.add(builder);
            continue;
          }
        }
        final existing = openTools['$turnId/$callId'];
        if (existing != null && existing.status == ChatToolStatus.running) {
          continue;
        }
        if (existing != null && existing.synthesized) {
          // A truncated history delivered the result first; this request only
          // restores the arguments instead of starting a second activity.
          existing.arguments = _map(event.data['arguments']);
          final presentation = _map(event.data['presentation']);
          if (presentation.isNotEmpty) existing.presentation = presentation;
          continue;
        }
        final builder = _ToolBuilder(
          key: 'tool-$callId-${event.sequence}',
          turnId: turnId,
          createdAt: event.createdAt,
          callId: callId,
          toolName: _string(event.data['name']) ?? '',
          arguments: _map(event.data['arguments']),
          presentation: _map(event.data['presentation']),
        );
        openTools['$turnId/$callId'] = builder;
        builders.add(builder);
      case 'tool.completed':
      case 'tool.failed':
      case 'tool.denied':
        closeAssistant(turnId);
        // A failure still falls through to a plain row so it stays visible.
        if (event.type == 'tool.completed' &&
            _timelineOf(event) == ChatToolTimeline.suppressed &&
            event.data['isError'] != true) {
          continue;
        }
        final callId = _string(event.data['callId']) ?? '';
        final status = switch (event.type) {
          'tool.completed' => ChatToolStatus.succeeded,
          'tool.failed' => ChatToolStatus.failed,
          _ => ChatToolStatus.denied,
        };
        final question = openQuestions['$turnId/$callId'];
        if (question != null) {
          question.finish(
            status: status,
            output: _string(event.data['output']),
            error: _string(event.data['error']),
            isError: event.data['isError'] == true,
          );
          continue;
        }
        final sleep = openSleeps['$turnId/$callId'];
        if (sleep != null) {
          sleep.finish();
          continue;
        }
        final existing = openTools['$turnId/$callId'];
        if (existing != null && existing.status != ChatToolStatus.running) {
          continue;
        }
        final builder =
            existing ??
            (_ToolBuilder(
              key: 'tool-$callId-${event.sequence}',
              turnId: turnId,
              createdAt: event.createdAt,
              callId: callId,
              toolName: _string(event.data['name']) ?? '',
              arguments: const <String, dynamic>{},
              presentation: _map(event.data['presentation']),
              synthesized: true,
            ));
        if (existing == null) {
          openTools['$turnId/$callId'] = builder;
          builders.add(builder);
        }
        builder.finish(
          status: status,
          output: _string(event.data['output']),
          error: _string(event.data['error']),
          isError: event.data['isError'] == true,
          presentation: _map(event.data['presentation']),
        );
      case 'tools.deferred':
        closeAssistant(turnId);
        final count = event.data['count'];
        if (count is int && count > 0) {
          builders.add(
            _StaticBuilder(
              ChatDeferredTools(
                key: 'deferred-${event.sequence}',
                turnId: turnId,
                createdAt: event.createdAt,
                count: count,
              ),
            ),
          );
        }
      case 'model.usage':
        closeAssistant(turnId);
        builders.add(
          _StaticBuilder(
            ChatUsage(
              key: 'usage-${event.sequence}',
              turnId: turnId,
              createdAt: event.createdAt,
              tokens: <String, num>{
                for (final entry in event.data.entries)
                  if (entry.value is num) entry.key: entry.value as num,
              },
            ),
          ),
        );
      case 'turn.completed':
      case 'turn.failed':
      case 'turn.cancelled':
        closeAssistant(turnId);
        terminatedTurns.add(turnId);
        final kind = switch (event.type) {
          'turn.completed' => ChatNoticeKind.turnCompleted,
          'turn.failed' => ChatNoticeKind.turnFailed,
          _ => ChatNoticeKind.turnCancelled,
        };
        final rounds = event.data['toolRounds'];
        builders.add(
          _StaticBuilder(
            ChatNotice(
              key: 'notice-${event.sequence}',
              turnId: turnId,
              createdAt: event.createdAt,
              kind: kind,
              message: _string(event.data['error']),
              toolRounds: rounds is int ? rounds : null,
            ),
          ),
        );
      case 'approval.requested':
        final raw = event.data['approval'];
        if (raw is Map<dynamic, dynamic>) {
          final approval = ApprovalRequestDto.fromJson(
            Map<String, dynamic>.from(raw),
          );
          final builder = _ApprovalBuilder(
            approval: approval,
            turnId: turnId,
            createdAt: event.createdAt,
          );
          openApprovals[approval.id] = builder;
          builders.add(builder);
        }
      case 'approval.resolved':
        final approvalId = _string(event.data['approvalId']);
        final status = _string(event.data['status']);
        if (approvalId != null) {
          openApprovals[approvalId]?.decision = status == 'approved';
        }
      case 'userQuestion.requested':
        final raw = event.data['request'];
        if (raw is Map<dynamic, dynamic>) {
          final request = UserQuestionRequestDto.fromJson(
            Map<String, dynamic>.from(raw),
          );
          openQuestions['${request.turnId}/${request.toolCallId}']?.request =
              request;
        }
      case 'userQuestion.answered':
        continue;
      default:
        closeAssistant(turnId);
        builders.add(
          _StaticBuilder(
            ChatUnknownEvent(
              key: 'event-${event.sequence}',
              turnId: turnId,
              createdAt: event.createdAt,
              type: event.type,
              data: event.data,
            ),
          ),
        );
    }
  }

  // Broadcast notifications can precede their persisted timeline event. Fold
  // those snapshots into the same builders so the later event does not create
  // a second row or a new key.
  for (final approval in approvals.values) {
    final existing = openApprovals[approval.id];
    if (existing != null) continue;
    final builder = _ApprovalBuilder(
      approval: approval,
      turnId: approval.turnId,
      createdAt: approval.createdAt,
    );
    openApprovals[approval.id] = builder;
    builders.add(builder);
  }
  for (final request in questions.values) {
    final existing = openQuestions['${request.turnId}/${request.toolCallId}'];
    if (existing != null) {
      existing.request = request;
      continue;
    }
    builders.add(
      _StaticBuilder(
        ChatQuestionInteraction(
          key: _questionKey(request.turnId, request.toolCallId),
          turnId: request.turnId,
          createdAt: request.createdAt,
          request: request,
        ),
      ),
    );
  }

  // Only the trailing assistant block of an unfinished turn is still growing.
  final lastAssistant = <String?, _AssistantBuilder>{};
  for (final builder in builders) {
    if (builder is _AssistantBuilder) lastAssistant[builder.turnId] = builder;
  }

  final items = <ChatItem>[];
  for (final builder in builders) {
    items.addAll(
      builder.build(
        isStreaming:
            !terminatedTurns.contains(builder.turnId) &&
            identical(lastAssistant[builder.turnId], builder),
      ),
    );
  }
  return List<ChatItem>.unmodifiable(items);
}

String? _string(Object? value) => value is String ? value : null;

/// Whether a delta named [blockId] belongs to the open block [openBlockId].
///
/// The writer names a block once, so a row keeps its identity however much of
/// the block a reader has loaded — which is what lets an older page extend the
/// row the reader is anchored to instead of replacing it, and what tells two
/// answers of one turn apart.
///
/// A delta written before the writer named blocks belongs to whatever is open,
/// which is how it has always been read, and its row is named after the delta
/// that opened it in the window at hand.
bool _continues(String? openBlockId, String? blockId) =>
    blockId == null || openBlockId == blockId;

String _questionKey(String? turnId, String callId) {
  final scope = turnId ?? '';
  return 'question:${scope.length}:$scope:$callId';
}

Map<String, dynamic> _map(Object? value) => value is Map<String, dynamic>
    ? Map<String, dynamic>.unmodifiable(value)
    : const <String, dynamic>{};

List<ChatAttachment> _attachments(Object? value) => value is List
    ? value
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => _attachment(Map<String, dynamic>.from(item)))
          .whereType<ChatAttachment>()
          .toList(growable: false)
    : const <ChatAttachment>[];

ChatAttachment? _attachment(Map<dynamic, dynamic> data) {
  final id = data['id'];
  final fileName = data['fileName'];
  final mimeType = data['mimeType'];
  final byteSize = data['byteSize'];
  if (id is! String ||
      fileName is! String ||
      mimeType is! String ||
      byteSize is! int) {
    return null;
  }
  return ChatAttachment(
    id: id,
    fileName: fileName,
    mimeType: mimeType,
    byteSize: byteSize,
  );
}

sealed class _ChatItemBuilder {
  const new();

  String? get turnId;

  List<ChatItem> build({required bool isStreaming});
}

final class _StaticBuilder extends _ChatItemBuilder {
  const new(this.item);

  final ChatItem item;

  @override
  String? get turnId => item.turnId;

  @override
  List<ChatItem> build({required bool isStreaming}) => <ChatItem>[item];
}

final class _ApprovalBuilder extends _ChatItemBuilder {
  new({required this.approval, required this.turnId, required this.createdAt});

  final ApprovalRequestDto approval;

  @override
  final String? turnId;

  final DateTime createdAt;
  bool? _decision;

  bool? get decision => _decision;

  set decision(bool value) => _decision = value;

  @override
  List<ChatItem> build({required bool isStreaming}) => <ChatItem>[
    ChatApprovalInteraction(
      key: 'approval-${approval.id}',
      turnId: turnId,
      createdAt: createdAt,
      approval: approval,
      status: decision == null
          ? ChatInteractionStatus.pending
          : ChatInteractionStatus.resolved,
      approved: decision,
    ),
  ];
}

final class _AssistantBuilder extends _ChatItemBuilder {
  new({
    required this.key,
    required this.blockId,
    required this.turnId,
    required this.createdAt,
  });

  final String key;

  /// Identity of the streamed block these deltas belong to.
  final String? blockId;

  @override
  final String? turnId;

  final DateTime createdAt;
  final StringBuffer _text = StringBuffer();

  void append(String text) => _text.write(text);

  @override
  List<ChatItem> build({required bool isStreaming}) {
    final markdown = _text.toString();
    return <ChatItem>[
      if (markdown.isNotEmpty)
        ChatAssistantMessage(
          key: key,
          turnId: turnId,
          createdAt: createdAt,
          markdown: markdown,
          isStreaming: isStreaming,
        ),
    ];
  }
}

final class _ReasoningBuilder extends _ChatItemBuilder {
  new({
    required this.key,
    required this.blockId,
    required this.turnId,
    required this.createdAt,
  });

  final String key;

  /// Identity of the streamed block these deltas belong to.
  final String? blockId;

  @override
  final String? turnId;

  final DateTime createdAt;
  final StringBuffer _text = StringBuffer();
  bool _completed = false;

  void append(String text) => _text.write(text);

  void complete() => _completed = true;

  @override
  List<ChatItem> build({required bool isStreaming}) {
    final markdown = _text.toString();
    return <ChatItem>[
      if (markdown.isNotEmpty || !_completed)
        ChatReasoningActivity(
          key: key,
          turnId: turnId,
          createdAt: createdAt,
          markdown: markdown,
          isStreaming: !_completed,
        ),
    ];
  }
}

final class _QuestionBuilder extends _ChatItemBuilder {
  new({
    required this.key,
    required this.turnId,
    required this.createdAt,
    required this.callId,
    required this.toolName,
    required this.presentation,
    required this.questions,
  });

  final String key;

  @override
  final String? turnId;

  final DateTime createdAt;
  final String callId;
  final String toolName;
  final Map<String, dynamic> presentation;
  final Object? questions;
  UserQuestionRequestDto? request;

  ChatToolStatus _status = ChatToolStatus.running;
  String? _output;
  String? _error;
  bool _isError = false;

  void finish({
    required ChatToolStatus status,
    required String? output,
    required String? error,
    required bool isError,
  }) {
    _status = status;
    _output = output;
    _error = error;
    _isError = isError;
  }

  /// Pairs each asked question with the answer that came back.
  List<ChatQuestionAnswer> _entries() {
    final asked = questions;
    final output = _output;
    if (asked is! List || output == null) return const <ChatQuestionAnswer>[];
    final Object? decoded;
    try {
      decoded = jsonDecode(output);
    } on FormatException {
      return const <ChatQuestionAnswer>[];
    }
    if (decoded is! List) return const <ChatQuestionAnswer>[];
    final answers = <String, Map<String, dynamic>>{
      for (final entry in decoded.whereType<Map<dynamic, dynamic>>())
        if (entry['questionId'] case final String id)
          id: Map<String, dynamic>.from(entry),
    };
    return <ChatQuestionAnswer>[
      for (final entry in asked.whereType<Map<dynamic, dynamic>>())
        if (entry['id'] case final String id)
          if (answers[id] case final answer?)
            ChatQuestionAnswer(
              header: _string(entry['header']) ?? '',
              question: _string(entry['question']) ?? '',
              answer: _string(answer['answer']) ?? '',
              isFreeForm: answer['isFreeForm'] == true,
            ),
    ];
  }

  @override
  List<ChatItem> build({required bool isStreaming}) {
    if (_status == ChatToolStatus.running) {
      final pending = request;
      return pending == null
          ? const <ChatItem>[]
          : <ChatItem>[
              ChatQuestionInteraction(
                key: key,
                turnId: turnId,
                createdAt: createdAt,
                request: pending,
              ),
            ];
    }
    final entries = _entries();
    if (_isError || _status != ChatToolStatus.succeeded || entries.isEmpty) {
      // A refused or cancelled question stays a tool row so it is visible.
      return <ChatItem>[
        ChatToolActivity(
          key: key,
          turnId: turnId,
          createdAt: createdAt,
          callId: callId,
          toolName: toolName,
          arguments: const <String, dynamic>{},
          presentation: presentation,
          status: _status,
          output: _output,
          error: _error,
          isError: _isError,
        ),
      ];
    }
    return <ChatItem>[
      ChatUserAnswer(
        key: key,
        turnId: turnId,
        createdAt: createdAt,
        entries: entries,
      ),
    ];
  }
}

final class _SleepBuilder extends _ChatItemBuilder {
  new({
    required this.key,
    required this.turnId,
    required this.createdAt,
    required this.duration,
    required this.reason,
  });

  final String key;

  @override
  final String? turnId;

  final DateTime createdAt;
  final Duration duration;
  final String? reason;
  bool _running = true;

  void finish() => _running = false;

  @override
  List<ChatItem> build({required bool isStreaming}) => <ChatItem>[
    ChatSleep(
      key: key,
      turnId: turnId,
      createdAt: createdAt,
      duration: duration,
      startedAt: createdAt,
      isRunning: _running,
      reason: reason,
    ),
  ];
}

final class _ToolBuilder extends _ChatItemBuilder {
  new({
    required this.key,
    required this.turnId,
    required this.createdAt,
    required this.callId,
    required this.toolName,
    required this.arguments,
    required this.presentation,
    this.synthesized = false,
  });

  final String key;

  @override
  final String? turnId;

  final DateTime createdAt;
  final String callId;
  final String toolName;

  /// Whether this activity was created from a result without a request.
  final bool synthesized;

  /// Requested arguments, restored later when the result arrived first.
  Map<String, dynamic> arguments;
  Map<String, dynamic> presentation;

  ChatToolStatus status = ChatToolStatus.running;

  String? output;
  String? error;
  bool isError = false;

  void finish({
    required ChatToolStatus status,
    required String? output,
    required String? error,
    required bool isError,
    required Map<String, dynamic> presentation,
  }) {
    this.status = status;
    this.output = output;
    this.error = error;
    this.isError = isError;
    if (presentation.isNotEmpty) this.presentation = presentation;
  }

  @override
  List<ChatItem> build({required bool isStreaming}) => <ChatItem>[
    ChatToolActivity(
      key: key,
      turnId: turnId,
      createdAt: createdAt,
      callId: callId,
      toolName: toolName,
      arguments: arguments,
      presentation: Map<String, dynamic>.unmodifiable(presentation),
      status: status,
      output: output,
      error: error,
      isError: isError,
    ),
  ];
}

/// Where the tool behind [event] belongs in the timeline.
///
/// The answer comes from the immutable contribution metadata recorded on the
/// event, never from a Dart table keyed by a tool name.
ChatToolTimeline _timelineOf(TimelineEventDto event) =>
    chatToolTimelineFromPresentation(_map(event.data['presentation']));
