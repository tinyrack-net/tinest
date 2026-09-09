import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/app/platform/external_url_opener.dart';
import 'package:app/src/features/conversation/application/chat_timeline_model.dart';
import 'package:app/src/features/conversation/presentation/chat_markdown.dart';
import 'package:app/src/shared/presentation/tinest_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Expandable provider reasoning shown in the conversation timeline.
class ChatReasoningCard extends ConsumerWidget {
  /// Creates a reasoning disclosure.
  const new({
    required this.activity,
    this.expanded = false,
    this.onToggle,
    super.key,
  });

  /// Reasoning text and lifecycle projected from timeline events.
  final ChatReasoningActivity activity;

  /// Whether the reasoning text is visible.
  final bool expanded;

  /// Called when the disclosure is toggled.
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final running = activity.isStreaming;
    return TRChatToolDisclosure(
      icon: TinestIcons.reasoning,
      label: running ? l10n.chatReasoningThinking : l10n.chatReasoningThought,
      status: running ? TRChatToolStatus.running : TRChatToolStatus.succeeded,
      statusLabel: running ? l10n.commonRunning : l10n.commonDone,
      open: expanded,
      onOpenChange: (_) => onToggle?.call(),
      details: SelectionArea(
        child: activity.markdown.isEmpty
            ? TRText(
                l10n.chatReasoningWaiting,
                variant: TRTextVariant.bodySm,
                color: TRTextColor.muted,
              )
            : ChatMarkdownBody(
                data: activity.markdown,
                onTapLink: (text, href, title) =>
                    openChatLink(ref.read(externalUrlOpenerProvider), href),
              ),
      ),
    );
  }
}
