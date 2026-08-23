import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/features/conversation/application/chat_timeline_model.dart';
import 'package:app/src/features/conversation/application/chat_tool_presentation.dart';
import 'package:app/src/features/conversation/presentation/chat_code_block.dart';
import 'package:app/src/shared/presentation/tinest_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Maps a tool glyph to its semantic Lucide icon.
IconData chatToolIcon(ChatToolGlyph glyph) => switch (glyph) {
  ChatToolGlyph.read => TinestIcons.document,
  ChatToolGlyph.list => TinestIcons.folderOpen,
  ChatToolGlyph.search => TinestIcons.search,
  ChatToolGlyph.edit => TinestIcons.edit,
  ChatToolGlyph.run => TinestIcons.terminal,
  ChatToolGlyph.delegate => TinestIcons.network,
  ChatToolGlyph.ask => TinestIcons.chat,
  ChatToolGlyph.resource => TinestIcons.extension,
  ChatToolGlyph.tools => TinestIcons.tool,
  ChatToolGlyph.clock => TinestIcons.time,
  ChatToolGlyph.context => TinestIcons.gauge,
  ChatToolGlyph.image => TinestIcons.image,
  ChatToolGlyph.generic => TinestIcons.tool,
};

/// One tool call rendered as a collapsed CLI-style line.
///
/// Tapping the row reveals the full request and result instead of dumping raw
/// JSON into the conversation. Expansion is owned by the enclosing list so it
/// survives scrolling and newly arriving events.
class ChatToolCard extends StatelessWidget {
  /// Creates a tool card.
  const ChatToolCard({
    required this.activity,
    this.expanded = false,
    this.onToggle,
    super.key,
  });

  /// The merged tool call rendered by this card.
  final ChatToolActivity activity;

  /// Whether the request and result are visible.
  final bool expanded;

  /// Called when the row is tapped.
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final activity = this.activity;
    final presentation = describeToolActivity(
      l10n,
      activity,
    );
    final status = switch (activity.status) {
      ChatToolStatus.running => TRChatToolStatus.running,
      ChatToolStatus.succeeded =>
        presentation.isFailure
            ? TRChatToolStatus.failed
            : TRChatToolStatus.succeeded,
      ChatToolStatus.failed => TRChatToolStatus.failed,
      ChatToolStatus.denied => TRChatToolStatus.denied,
    };
    return TRChatToolDisclosure(
      icon: chatToolIcon(presentation.glyph),
      label: _actionLabel(l10n, presentation.glyph),
      secondaryLabel: status == TRChatToolStatus.running
          ? presentation.title
          : null,
      status: status,
      statusLabel: _statusLabel(l10n, status),
      open: expanded,
      onOpenChange: (_) => onToggle?.call(),
      details: _ChatToolDetails(
        activity: activity,
        presentation: presentation,
      ),
    );
  }
}

String _actionLabel(AppLocalizations l10n, ChatToolGlyph glyph) =>
    switch (glyph) {
      ChatToolGlyph.read => l10n.chatToolActionRead,
      ChatToolGlyph.list => l10n.chatToolActionList,
      ChatToolGlyph.search => l10n.chatToolActionSearch,
      ChatToolGlyph.edit => l10n.chatToolActionEdit,
      ChatToolGlyph.run => l10n.chatToolActionRun,
      ChatToolGlyph.delegate => l10n.chatToolActionDelegate,
      ChatToolGlyph.ask => l10n.chatToolActionAsk,
      ChatToolGlyph.resource => l10n.chatToolActionResource,
      ChatToolGlyph.tools => l10n.chatToolActionTools,
      ChatToolGlyph.clock => l10n.chatToolActionClock,
      ChatToolGlyph.context => l10n.chatToolActionContext,
      ChatToolGlyph.image => l10n.chatToolActionImage,
      ChatToolGlyph.generic => l10n.chatToolActionGeneric,
    };

String _statusLabel(AppLocalizations l10n, TRChatToolStatus status) =>
    switch (status) {
      TRChatToolStatus.running => l10n.commonRunning,
      TRChatToolStatus.succeeded => l10n.commonDone,
      TRChatToolStatus.failed => l10n.chatToolStatusFailed,
      TRChatToolStatus.denied => l10n.chatToolStatusDenied,
    };

class _ChatToolDetails extends StatelessWidget {
  const _ChatToolDetails({
    required this.activity,
    required this.presentation,
  });

  final ChatToolActivity activity;
  final ChatToolPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // One host for the whole disclosure, so a drag runs from a label through
    // the payload below it instead of stopping at each block.
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _ChatToolDetailLabel(l10n.chatToolDetailsTool),
          ChatCodeBlock(text: '${activity.toolName}\n${presentation.title}'),
          const SizedBox(height: TRSpacing.small),
          _ChatToolDetailLabel(l10n.chatToolDetailsRequest),
          ChatCodeBlock(text: prettyJson(activity.arguments)),
          if (presentation.argumentBody is! ChatToolEmptyBody) ...<Widget>[
            const SizedBox(height: TRSpacing.extraSmall),
            _ChatToolBodyView(body: presentation.argumentBody),
          ],
          if (presentation.body is! ChatToolEmptyBody ||
              presentation.resultLine != null ||
              activity.error != null) ...<Widget>[
            const SizedBox(height: TRSpacing.small),
            _ChatToolDetailLabel(l10n.chatToolDetailsResult),
            if (presentation.resultLine != null)
              Padding(
                padding: const EdgeInsets.only(bottom: TRSpacing.extraSmall),
                child: TRText(
                  presentation.resultLine!,
                  variant: TRTextVariant.bodySm,
                  color: presentation.isFailure
                      ? TRTextColor.danger
                      : TRTextColor.muted,
                ),
              ),
            _ChatToolBodyView(body: presentation.body),
            if (presentation.body is ChatToolEmptyBody)
              if (activity.error case final String error)
                ChatCodeBlock(text: error),
          ],
        ],
      ),
    );
  }
}

class _ChatToolDetailLabel extends StatelessWidget {
  const _ChatToolDetailLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: TRSpacing.extraSmall),
    child: TRText(
      label,
      variant: TRTextVariant.bodySm,
      color: TRTextColor.muted,
    ),
  );
}

class _ChatToolBodyView extends StatelessWidget {
  const _ChatToolBodyView({required this.body});

  final ChatToolBody body;

  @override
  Widget build(BuildContext context) => switch (body) {
    ChatToolEmptyBody() => const SizedBox.shrink(),
    ChatToolTextBody(:final text) => ChatCodeBlock(text: text),
  };
}
