import 'dart:async';

import 'package:app/src/features/conversation/application/attachment_ports.dart';
import 'package:app/src/features/conversation/application/conversation_controller.dart';
import 'package:app/src/features/conversation/application/pending_turns_controller.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/sessions/application/session_tabs_controller.dart';
import 'package:app/src/features/sessions/application/sessions_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';

/// Starts a session without borrowing the lifecycle of the submitting widget.
final sessionStarterProvider = Provider<SessionStarter>(SessionStarter.new);

/// Coordinates session creation, tab promotion, and the first turn.
///
/// The provider is deliberately not auto-disposed: a draft tab is replaced by
/// its session while this operation is running, so the widget that submitted
/// the prompt can unmount before the daemon finishes creating the session.
final class SessionStarter {
  /// Creates a starter owned by the application provider container.
  new(this._ref);

  final Ref _ref;

  /// Creates a session, opens its tab, and starts its first turn.
  Future<SessionDto> start({
    required WorkspaceSelection selection,
    required String agentDefinitionId,
    required String title,
    required String prompt,
    String? draftTabId,
    List<PendingAttachment> attachments = const <PendingAttachment>[],
    ModelSelectionDto? model,
    Map<String, ModelControlValueDto> modelControls =
        const <String, ModelControlValueDto>{},
    PermissionMode? permissionMode,
  }) async {
    final sessions = sessionsControllerProvider(
      selection.hostId,
      selection.worktreeId,
    );
    final tabs = sessionTabsControllerProvider(selection);
    final sessionsHandle = _ref.listen(sessions, (previous, next) {});
    final tabsHandle = _ref.listen(tabs, (previous, next) {});
    try {
      await Future.wait(<Future<Object?>>[
        _ref.read(sessions.future),
        _ref.read(tabs.future),
      ]);
      final session = await _ref
          .read(sessions.notifier)
          .create(
            title: title,
            agentDefinitionId: agentDefinitionId,
            model: model,
            modelControls: modelControls,
            permissionMode: permissionMode,
          );
      // The chat room opens on the single create round trip: the draft is
      // promoted and the caller navigates now, while the timeline
      // subscription, attachment uploads, and the first turn continue in the
      // background. The pending registry renders the prompt as an optimistic
      // user bubble until the daemon echoes it.
      _ref
          .read(pendingFirstTurnsProvider.notifier)
          .put(session.id, prompt, attachments: attachments);
      await _ref.read(tabs.notifier).add(session, draftTabId: draftTabId);
      unawaited(_startFirstTurn(selection, session, prompt, attachments));
      return session;
    } finally {
      tabsHandle.close();
      sessionsHandle.close();
    }
  }

  Future<void> _startFirstTurn(
    WorkspaceSelection selection,
    SessionDto session,
    String prompt,
    List<PendingAttachment> attachments,
  ) async {
    final conversation = conversationControllerProvider(
      selection.hostId,
      session.id,
    );
    final conversationHandle = _ref.listen(conversation, (previous, next) {});
    try {
      // Install the timeline subscription before starting the turn so the
      // opened chat room streams the turn it just kicked off.
      await _ref.read(conversation.future);
      if (!_ref.mounted) return;
      await _ref
          .read(conversation.notifier)
          .startTurn(prompt, attachments: attachments, queueWhenBusy: false);
    } on Exception {
      // The session exists but its first turn did not start. The conversation
      // state auto-disposes with this temporary listener, so the prompt stays
      // in the pending registry until the mounted composer restores it.
      if (_ref.mounted) {
        _ref.read(pendingFirstTurnsProvider.notifier).markFailed(session.id);
      }
    } finally {
      conversationHandle.close();
    }
  }
}
