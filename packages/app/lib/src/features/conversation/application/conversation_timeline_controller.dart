import 'package:app/src/features/conversation/application/chat_timeline_model.dart';
import 'package:app/src/features/conversation/application/conversation_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderListenableSelect;
import 'package:protocol/protocol.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'conversation_timeline_controller.g.dart';

/// Projects only when timeline interaction data changes.
///
/// Queue edits and other conversation state updates retain the same collection
/// identities, so they do not reparse every Markdown and tool row.
@riverpod
List<ChatItem> conversationTimeline(Ref ref, String hostId, String sessionId) {
  final source = ref.watch(
    conversationControllerProvider(hostId, sessionId).select((value) {
      final state = value.asData?.value;
      return (
        timeline: state?.timeline ?? const <TimelineEventDto>[],
        approvals: state?.approvals ?? const <String, ApprovalRequestDto>{},
        questions: state?.questions ?? const <String, UserQuestionRequestDto>{},
      );
    }),
  );
  return projectChatTimeline(
    source.timeline,
    approvals: source.approvals,
    questions: source.questions,
  );
}
