import 'dart:async';

import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/app/platform/external_url_opener.dart';
import 'package:app/src/features/conversation/application/chat_timeline_model.dart';
import 'package:app/src/features/conversation/application/chat_tool_presentation.dart';
import 'package:app/src/features/conversation/presentation/chat_markdown.dart';
import 'package:app/src/shared/presentation/tinest_icons.dart';
import 'package:app/src/shared/presentation/tinest_ui_density.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// A user prompt rendered in a trailing chat bubble.
class ChatUserLine extends StatelessWidget {
  /// Creates a user line.
  const new({
    required this.message,
    this.loadAttachment,
    this.exportAttachment,
    super.key,
  });

  /// The prompt to render.
  final ChatUserMessage message;

  /// Authenticated attachment byte loader.
  final ChatAttachmentLoader? loadAttachment;

  /// Platform file exporter.
  final ChatAttachmentExporter? exportAttachment;

  @override
  Widget build(BuildContext context) => TRChatUserBubble(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (message.text.isNotEmpty) SelectionArea(child: TRText(message.text)),
        if (message.attachments.isNotEmpty) ...<Widget>[
          if (message.text.isNotEmpty) const SizedBox(height: TRSpacing.small),
          Wrap(
            spacing: TRSpacing.extraSmall,
            runSpacing: TRSpacing.extraSmall,
            children: <Widget>[
              for (final attachment in message.attachments)
                ChatAttachmentTile(
                  attachment: attachment,
                  loadAttachment: loadAttachment,
                  exportAttachment: exportAttachment,
                ),
            ],
          ),
        ],
      ],
    ),
  );
}

/// An assistant-published file row.
class ChatAttachmentLine extends StatelessWidget {
  /// Creates an assistant attachment line.
  const new({
    required this.message,
    this.loadAttachment,
    this.exportAttachment,
    super.key,
  });

  /// Attachment timeline item.
  final ChatAttachmentMessage message;

  /// Authenticated attachment byte loader.
  final ChatAttachmentLoader? loadAttachment;

  /// Platform file exporter.
  final ChatAttachmentExporter? exportAttachment;

  @override
  Widget build(BuildContext context) => TRChatMessageRow(
    icon: message.attachment.isImage ? TinestIcons.image : TinestIcons.file,
    alignment: TRChatMessageAlignment.center,
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: ChatAttachmentTile(
        attachment: message.attachment,
        loadAttachment: loadAttachment,
        exportAttachment: exportAttachment,
      ),
    ),
  );
}

/// Thumbnail or file pill shared by inbound and outbound attachments.
class ChatAttachmentTile extends StatefulWidget {
  /// Creates an attachment tile.
  const new({
    required this.attachment,
    this.loadAttachment,
    this.exportAttachment,
    super.key,
  });

  /// Attachment metadata.
  final ChatAttachment attachment;

  /// Authenticated byte loader.
  final ChatAttachmentLoader? loadAttachment;

  /// Platform exporter.
  final ChatAttachmentExporter? exportAttachment;

  @override
  State<ChatAttachmentTile> createState() => _ChatAttachmentTileState();
}

class _ChatAttachmentTileState extends State<ChatAttachmentTile> {
  Uint8List? _bytes;
  bool _failed = false;

  ChatAttachment get attachment => widget.attachment;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPreview());
  }

  @override
  void didUpdateWidget(covariant ChatAttachmentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The preview is keyed by attachment identity: a rebuild with the same
    // attachment must not download the bytes again.
    if (oldWidget.attachment.id != widget.attachment.id ||
        (oldWidget.loadAttachment == null) != (widget.loadAttachment == null)) {
      _bytes = null;
      _failed = false;
      unawaited(_loadPreview());
    }
  }

  Future<void> _loadPreview() async {
    final loader = widget.loadAttachment;
    if (loader == null || !widget.attachment.isImage) return;
    final id = widget.attachment.id;
    try {
      final bytes = await loader(widget.attachment);
      if (!mounted || widget.attachment.id != id) return;
      setState(() => _bytes = bytes);
    } on Exception {
      if (!mounted || widget.attachment.id != id) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loader = widget.loadAttachment;
    final exportAttachment = widget.exportAttachment;
    final preview = attachment.isImage && loader != null
        ? SizedBox.square(
            dimension: TRControlMetrics.heightOf(TRUiSize.lg),
            child: _bytes != null
                ? ClipRRect(
                    borderRadius: const BorderRadius.all(TRRadii.medium),
                    child: Image.memory(
                      _bytes!,
                      width: TRControlMetrics.heightOf(TRUiSize.lg),
                      height: TRControlMetrics.heightOf(TRUiSize.lg),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(TinestIcons.image),
                    ),
                  )
                : _failed
                ? const Icon(TinestIcons.image)
                : const TRSkeleton(shape: TRSkeletonShape.rectangle),
          )
        : Icon(attachment.isImage ? TinestIcons.image : TinestIcons.file);
    final onTap = loader == null
        ? null
        : () => attachment.isImage
              ? _showImage(context, loader)
              : exportAttachment?.call(attachment);
    return Semantics(
      button: true,
      enabled: onTap != null,
      onTap: onTap,
      child: GestureDetector(
        key: ValueKey('chat-attachment-${attachment.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(maxWidth: TRMeasurements.measureSm),
          padding: const EdgeInsets.all(TRSpacing.small),
          decoration: BoxDecoration(
            border: Border.all(color: context.tinyrackTheme.border),
            borderRadius: const BorderRadius.all(TRRadii.large),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              preview,
              const SizedBox(width: TRSpacing.small),
              Flexible(
                child: TRText.inherit(
                  '${attachment.fileName}\n'
                  '${_attachmentSize(attachment.byteSize)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!attachment.isImage) ...<Widget>[
                const SizedBox(width: TRSpacing.small),
                const Icon(TinestIcons.download),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showImage(
    BuildContext context,
    ChatAttachmentLoader loader,
  ) async {
    final bytes = await loader(attachment);
    if (!context.mounted) return;
    await showTRDialog<void>(
      context: context,
      builder: (context) => TRDialog(
        semanticLabel: attachment.fileName,
        content: InteractiveViewer(
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

String _attachmentSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Assistant prose rendered as Markdown on the shared leading rail.
class ChatAssistantMessageView extends ConsumerWidget {
  /// Creates an assistant message view.
  const new({required this.message, super.key});

  /// The assistant block to render.
  final ChatAssistantMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return TRChatMessageRow(
      icon: TinestIcons.status,
      tone: TRChatMessageTone.primary,
      // One selection host for the whole answer. `MarkdownBody.selectable`
      // would give every block its own `SelectableText`, so a drag could never
      // leave the paragraph it started in.
      child: ChatMarkdownSelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ChatMarkdownBody(
              data: message.markdown,
              onTapLink: (text, href, title) =>
                  openChatLink(ref.read(externalUrlOpenerProvider), href),
            ),
            // A growing answer has nothing worth copying yet; a stopped one is
            // no longer streaming, so it keeps the action.
            if (!message.isStreaming)
              TRTooltip(
                message: l10n.chatCopyResponse,
                child: TRIconButton(
                  key: const ValueKey<String>('chat-response-copy'),
                  appearance: TRAppearance.ghost,
                  uiSize: TinestUiDensity.compactControlSize(context),
                  label: l10n.chatCopyResponse,
                  icon: const Icon(TinestIcons.copy),
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: message.markdown)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A short muted line closing one turn.
class ChatNoticeLine extends StatelessWidget {
  /// Creates a notice line.
  const new({required this.notice, super.key});

  /// The notice to render.
  final ChatNotice notice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (String label, TRChatToolStatus status) = switch (notice.kind) {
      ChatNoticeKind.turnCompleted => (
        l10n.commonDone,
        TRChatToolStatus.succeeded,
      ),
      ChatNoticeKind.turnCancelled => (
        l10n.chatNoticeCancelled,
        TRChatToolStatus.denied,
      ),
      ChatNoticeKind.turnFailed => (
        l10n.chatNoticeFailed(notice.message ?? ''),
        TRChatToolStatus.failed,
      ),
    };
    return TRChatStatusRow(label: label, status: status);
  }
}

/// Token accounting rendered as a muted footer.
class ChatUsageLine extends StatelessWidget {
  /// Creates a usage line.
  const new({required this.usage, super.key});

  /// The usage entry to render.
  final ChatUsage usage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final summary = describeTokenUsage(l10n, usage.tokens);
    if (summary == null) return const SizedBox.shrink();
    return KeyedSubtree(
      key: const ValueKey<String>('chat-usage-line'),
      child: TRChatStatusRow(
        label: summary,
        status: TRChatToolStatus.succeeded,
        icon: TinestIcons.gauge,
      ),
    );
  }
}

/// Renders an answered agent question as question-and-answer prose.
///
/// The pending question is a card the user acts on; once answered it belongs
/// in the transcript as conversation, not as a tool row full of JSON.
class ChatUserAnswerLine extends StatelessWidget {
  /// Creates an answered-question line.
  const new({required this.answer, super.key});

  /// The answered questions to render.
  final ChatUserAnswer answer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TRChatUserBubble(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final entry in answer.entries)
            Padding(
              key: ValueKey<String>('chat-answer-${entry.header}'),
              padding: const EdgeInsets.only(bottom: TRSpacing.threeExtraSmall),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TRText(
                    entry.question,
                    variant: TRTextVariant.bodySm,
                    color: TRTextColor.muted,
                  ),
                  TRText(
                    entry.isFreeForm
                        ? l10n.chatAnswerTyped(entry.answer)
                        : entry.answer,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Tells the user that tools exist beyond the ones the model was handed.
class ChatDeferredToolsLine extends StatelessWidget {
  /// Creates a deferred-tools line.
  const new({required this.notice, super.key});

  /// The notice to render.
  final ChatDeferredTools notice;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: const ValueKey<String>('chat-deferred-tools'),
    child: TRChatStatusRow(
      label: AppLocalizations.of(context).chatDeferredTools(notice.count),
      status: TRChatToolStatus.succeeded,
      icon: TinestIcons.tool,
    ),
  );
}

/// An event this build cannot render, shown as a collapsible row.
class ChatUnknownEventLine extends StatelessWidget {
  /// Creates an unknown-event line.
  const new({required this.event, super.key});

  /// The unrecognized event.
  final ChatUnknownEvent event;

  @override
  Widget build(BuildContext context) {
    return TRChatStatusRow(label: event.type, status: TRChatToolStatus.denied);
  }
}

/// Placeholder shown before a session has any timeline events.
class ChatEmptyState extends StatelessWidget {
  /// Creates the empty state.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            TinestIcons.chat,
            size: TRSpacing.twoExtraLarge,
            color: context.tinyrackTheme.textMuted,
          ),
          const SizedBox(height: TRSpacing.medium),
          TRText(AppLocalizations.of(context).chatEmptyTitle),
          const SizedBox(height: TRSpacing.small),
          TRText(
            AppLocalizations.of(context).chatEmptyExample,
            variant: TRTextVariant.bodySm,
            color: TRTextColor.muted,
          ),
        ],
      ),
    );
  }
}

/// Row shown while a turn is still running.
class ChatRunningIndicator extends StatelessWidget {
  /// Creates the running indicator.
  const new({super.key});

  @override
  Widget build(BuildContext context) => TRChatStatusRow(
    label: AppLocalizations.of(context).commonRunning,
    status: TRChatToolStatus.running,
  );
}
