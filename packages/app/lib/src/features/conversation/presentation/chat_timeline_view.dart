import 'dart:typed_data';

import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/app/app_identity.dart';
import 'package:app/src/features/conversation/application/chat_timeline_model.dart';
import 'package:app/src/features/conversation/presentation/chat_approval_card.dart';
import 'package:app/src/features/conversation/presentation/chat_markdown.dart';
import 'package:app/src/features/conversation/presentation/chat_message_views.dart';
import 'package:app/src/features/conversation/presentation/chat_question_card.dart';
import 'package:app/src/features/conversation/presentation/chat_reasoning_card.dart';
import 'package:app/src/features/conversation/presentation/chat_sleep_card.dart';
import 'package:app/src/features/conversation/presentation/chat_tool_card.dart';
import 'package:app/src/features/plugins/presentation/plugin_ui_document_view.dart';
import 'package:app/src/shared/presentation/tinest_layout_metrics.dart';
import 'package:app/src/shared/presentation/workspace_skeletons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Dispatches an action from a persisted plugin timeline snapshot.
typedef ChatPluginUiActionDispatcher = Future<PluginUiDocumentDto> Function(
  PluginUiDocumentDto document,
  PluginUiActionDto action,
);

/// Scrolling conversation body rendered from projected chat items.
class ChatTimelineView extends StatefulWidget {
  /// Creates a timeline view.
  const ChatTimelineView({
    required this.items,
    required this.busy,
    required this.sessionKey,
    this.loading = false,
    this.readingPosition,
    this.onReadingPositionChanged,
    this.olderPageKey,
    this.loadingOlder = false,
    this.olderFailed = false,
    this.onLoadOlder,
    this.hostId,
    this.onPluginUiAction,
    this.loadAttachment,
    this.exportAttachment,
    super.key,
  });

  /// Items to render, oldest first.
  final List<ChatItem> items;

  /// Whether the session is currently running a turn.
  final bool busy;

  /// Stable identity of the conversation being rendered.
  ///
  /// Per-conversation view state — disclosure expansion, attachment futures,
  /// row identity, the reading position — is scoped to this rather than to the
  /// widget's own lifetime, which does not survive a tab switch.
  final String sessionKey;

  /// Reading position to restore, or null to open at the newest message.
  final TRVirtualListSnapshot<String>? readingPosition;

  /// Reports the position worth restoring after scrolling settles and when a
  /// conversation is being left.
  ///
  /// A null snapshot means the reader was at the newest message and should
  /// arrive there again rather than at whatever row they last stopped on.
  final void Function(
    String sessionKey,
    TRVirtualListSnapshot<String>? position,
  )?
  onReadingPositionChanged;

  /// Identity of the next page of older history, or null when there is none.
  ///
  /// It must change whenever the same page becomes requestable again, because
  /// the list asks for each identity exactly once for its whole lifetime — a
  /// page that failed is otherwise unreachable.
  final Object? olderPageKey;

  /// Whether a page of older history is in flight.
  final bool loadingOlder;

  /// Whether the last page of older history failed to load.
  final bool olderFailed;

  /// Called when the reader approaches the oldest loaded message.
  final VoidCallback? onLoadOlder;

  /// Whether history is still loading and no snapshot has ever arrived.
  ///
  /// A loading timeline renders a conversation-shaped skeleton: showing the
  /// "no messages" empty state would misreport a session that simply has not
  /// received its history yet.
  final bool loading;

  /// Host used to resolve approval and question interactions.
  final String? hostId;

  /// Dispatches actions from revision-pinned plugin timeline snapshots.
  final ChatPluginUiActionDispatcher? onPluginUiAction;

  /// Authenticated attachment byte loader.
  final ChatAttachmentLoader? loadAttachment;

  /// Platform file exporter.
  final ChatAttachmentExporter? exportAttachment;

  @override
  State<ChatTimelineView> createState() => _ChatTimelineViewState();
}

class _ChatTimelineViewState extends State<ChatTimelineView> {
  // Expansion lives here so a card keeps its state when it scrolls out of the
  // cache extent or when new events shift its virtual index.
  final Set<String> _expanded = <String>{};
  final Map<String, Future<Uint8List>> _attachmentCache =
      <String, Future<Uint8List>>{};
  TRVirtualListController<String> _virtualListController =
      TRVirtualListController<String>();
  // The position to hand back when this conversation is left, kept current
  // while the list is laid out because `deactivate` is too late to ask it
  // anything: by then the sliver may already be detached.
  //
  // Null means the reader is at the newest message. Their next entry belongs
  // at the end, not on the row they last stopped on — and a list shorter than
  // its viewport must never be snapshotted at all, because the inset that
  // bottom-aligns it is baked into the anchor offset and cannot be reproduced
  // once the conversation grows past the viewport.
  TRVirtualListSnapshot<String>? _readingPosition;
  // Rows currently handed to the list, which is zero whenever the skeleton or
  // the empty state replaced it and there is therefore nothing to snapshot.
  int _entryCount = 0;

  @override
  void initState() {
    super.initState();
    // A restored snapshot remains the current reading position until a
    // settled scroll proves that the reader reached the trailing edge. The
    // final row can be taller than the viewport, so merely seeing its index
    // does not mean the reader is at its end.
    _readingPosition = widget.readingPosition;
  }

  @override
  void didUpdateWidget(covariant ChatTimelineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionKey == widget.sessionKey) return;
    _reportReadingPosition(oldWidget.sessionKey);
    // The keyed list below remounts so the incoming session can resolve its
    // own initial target. Give it a controller of its own as well: Flutter can
    // mount the replacement before disposing the previous keyed child, and a
    // TRVirtualListController intentionally rejects two simultaneous lists.
    _virtualListController.dispose();
    _virtualListController = TRVirtualListController<String>();
    _readingPosition = widget.readingPosition;
    _expanded.clear();
    _attachmentCache.clear();
  }

  @override
  void deactivate() {
    _reportReadingPosition(widget.sessionKey);
    super.deactivate();
  }

  @override
  void dispose() {
    _virtualListController.dispose();
    super.dispose();
  }

  /// Hands the position of [sessionKey] back to whoever retains it.
  void _reportReadingPosition(String sessionKey) =>
      widget.onReadingPositionChanged?.call(sessionKey, _readingPosition);

  /// Whether no page is in flight and the last one did not fail.
  bool get _olderPageSettled => !widget.loadingOlder && !widget.olderFailed;

  /// The "load earlier messages" edge, or null when there is nothing above.
  ///
  /// Null matters as much as the object: an underfilled list already sits at
  /// its leading edge, so a request that exists is a request that fires
  /// immediately — every short conversation would spend a round trip proving
  /// it has no history.
  ///
  /// It carries no slot. A row occupying the leading edge is content directly
  /// above the reader: the list anchors to it, and once it is the anchor a
  /// page landing underneath leaves the viewport where it is, sending the
  /// reader back to the oldest message instead of holding their place. The
  /// progress it would have shown is overlaid in [build] instead, outside the
  /// scrollable, where appearing and disappearing moves nothing.
  TRVirtualListEdgeRequest? _olderPageRequest() {
    final pageKey = widget.olderPageKey;
    final load = widget.onLoadOlder;
    if (pageKey == null || load == null) return null;
    // A page already in flight cannot be helped by asking for it again, and
    // one that failed is the reader's to retry from the status row below.
    // Neither is an edge the list should be watching.
    if (!_olderPageSettled) return null;
    return TRVirtualListEdgeRequest(
      requestKey: pageKey,
      onRequest: load,
      triggerExtent: const TRVirtualListTriggerExtent.viewports(2),
    );
  }

  /// Progress for an in-flight or failed page of older history.
  Widget? _olderPageStatus(BuildContext context) {
    if (_olderPageSettled) return null;
    final l10n = AppLocalizations.of(context);
    final retry = widget.olderFailed ? widget.onLoadOlder : null;
    // Progress is not something to touch, and it overlays the transcript: only
    // a row the reader can answer takes pointers away from the messages.
    return IgnorePointer(
      ignoring: retry == null,
      child: _ChatTimelineContentColumn(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TRSpacing.extraLarge,
            vertical: TRSpacing.small,
          ),
          child: TRChatStatusRow(
            label: widget.olderFailed
                ? l10n.conversationLoadOlderFailed
                : l10n.conversationLoadingOlder,
            status: widget.olderFailed
                ? TRChatToolStatus.failed
                : TRChatToolStatus.running,
            actionLabel: retry == null ? null : l10n.conversationLoadOlderRetry,
            onAction: retry,
          ),
        ),
      ),
    );
  }

  void _onVisibleRangeChanged(TRVirtualListRange<String> range) {
    final hasUnreadBelow = range.lastIndex < _entryCount - 1;
    // Range changes keep anchors fresh while rows enter and leave the
    // viewport. They must not clear an anchor: a single tall final row has the
    // same range both halfway through and at the trailing edge. Scroll-end
    // metrics below are the only authoritative trailing-edge signal.
    if (hasUnreadBelow) {
      _readingPosition = _virtualListController.takeSnapshot();
    }
  }

  bool _onScrollEnd(ScrollEndNotification notification) {
    if (notification.depth != 0 || _entryCount == 0) return false;
    // A visible range changes only when its first or last row changes. A long
    // Markdown row can therefore move by whole viewports without another
    // range callback, so the settled scroll offset is the authoritative place
    // to refresh the snapshot a tab switch will retain.
    final nextPosition = notification.metrics.extentAfter > 1
        ? _virtualListController.takeSnapshot()
        : null;
    _readingPosition = nextPosition;
    // Checkpoint while the list is still attached. Relying on deactivate as
    // the first report makes a rapid tab switch race the deferred parent-store
    // write against construction of the returning timeline.
    _reportReadingPosition(widget.sessionKey);
    return false;
  }

  /// Folds or unfolds a row while holding it still on screen.
  void _toggle(String key) {
    _virtualListController.holdVisibleAnchorForNextLayout();
    setState(() {
      if (!_expanded.remove(key)) _expanded.add(key);
    });
  }

  Future<Uint8List> _load(ChatAttachment attachment) =>
      _attachmentCache.putIfAbsent(
        attachment.id,
        () => widget.loadAttachment!(attachment),
      );

  double _estimatedItemExtent(_ChatTimelineEntry entry, int _) =>
      switch (entry) {
        _ChatTimelineRunningEntry() => TRMeasurements.measureXs,
        _ChatTimelineItemEntry(:final item) => switch (item) {
          ChatAttachmentMessage() ||
          ChatNotice() ||
          ChatDeferredTools() ||
          ChatUsage() ||
          ChatUnknownEvent() => TRMeasurements.measureXs,
          ChatUserMessage() ||
          ChatAssistantMessage() ||
          ChatReasoningActivity() ||
          ChatPluginUiDocument() ||
          ChatApprovalInteraction() ||
          ChatQuestionInteraction() ||
          ChatToolActivity() ||
          ChatUserAnswer() ||
          ChatSleep() => TRMeasurements.measureSm,
        },
      };

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final busy = widget.busy;
    final reasoningActive =
        items.isNotEmpty &&
        items.last is ChatReasoningActivity &&
        (items.last as ChatReasoningActivity).isStreaming;
    if (widget.loading && items.isEmpty) {
      _entryCount = 0;
      return _ChatTimelineContentColumn(
        child: ChatTimelineSkeleton(
          semanticLabel: AppLocalizations.of(context).conversationLoading,
        ),
      );
    }
    if (items.isEmpty && !busy) {
      _entryCount = 0;
      return const _ChatTimelineContentColumn(child: ChatEmptyState());
    }
    final entries = <_ChatTimelineEntry>[
      for (final item in items) _ChatTimelineItemEntry(item),
      // Present for the whole turn, silent while reasoning owns the indicator.
      if (busy) _ChatTimelineRunningEntry(showsIndicator: !reasoningActive),
    ];
    _entryCount = entries.length;
    final olderStatus = _olderPageStatus(context);
    final virtualList = TRVirtualList<_ChatTimelineEntry, String>(
      // A session owns its initial trailing/snapshot target. Reusing the
      // virtual-list State across a tab switch preserves the previous
      // session's already-resolved target, so a newly supplied snapshot is
      // never applied even though its item keys are present.
      key: ValueKey<String>(widget.sessionKey),
      items: entries,
      itemKey: (entry) => entry.key,
      estimatedItemExtent: _estimatedItemExtent,
      controller: _virtualListController,
      // No `pageStorageId`: the component's own restore outranks
      // `initialPosition`, so a conversation that was ever shorter than its
      // viewport reopens pinned to its oldest message forever. Restoration
      // is owned here instead, and only offered when it is what the reader
      // wants.
      initialPosition: const TRVirtualListInitialPosition<String>.trailing(),
      initialSnapshot: widget.readingPosition,
      // The shared list resolves whether the effective initial target is a
      // restorable item or the trailing fallback. Keeping follow enabled lets
      // an unavailable history anchor fall back to newest and stay there as
      // live messages arrive.
      follow: TRVirtualListFollow.trailing,
      // Two viewports either side is enough to keep a fast scroll ahead of the
      // builder. Every cached row is a full Markdown parse and layout, rebuilt
      // on each streamed delta, so a deeper window buys smoothness the reader
      // never sees at a cost they do.
      scrollCacheExtent: const .viewport(4),
      onVisibleRangeChanged: _onVisibleRangeChanged,
      leadingEdgeRequest: _olderPageRequest(),
      itemBuilder: (context, entry, index) {
        final isFirst = entry == entries.first;
        final isLast = entry == entries.last;
        final content = switch (entry) {
          _ChatTimelineRunningEntry(:final showsIndicator) =>
            showsIndicator
                ? const ChatRunningIndicator()
                : const SizedBox.shrink(),
          _ChatTimelineItemEntry(:final item) => ChatItemView(
            item: item,
            expanded: _expanded.contains(item.key),
            onToggle: () => _toggle(item.key),
            loadAttachment: widget.loadAttachment == null ? null : _load,
            exportAttachment: widget.exportAttachment,
            hostId: widget.hostId,
            onPluginUiAction: widget.onPluginUiAction,
          ),
        };
        return _ChatTimelineContentColumn(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              TRSpacing.extraLarge,
              isFirst ? TRSpacing.large : EdgeInsets.zero.top,
              TRSpacing.extraLarge,
              isLast ? TRSpacing.large : TRSpacing.small,
            ),
            child: KeyedSubtree(
              key: ValueKey<String>(widget.sessionKey),
              child: KeyedSubtree(
                key: ValueKey<String>(entry.key),
                child: content,
              ),
            ),
          ),
        );
      },
    );
    final list = NotificationListener<ScrollEndNotification>(
      onNotification: _onScrollEnd,
      child: virtualList,
    );
    // The stack is unconditional: making it appear only while a page is in
    // flight would re-inflate the list beneath it, and one controller drives
    // exactly one list at a time.
    //
    // The Markdown scope wraps the whole list so every assistant row shares one
    // stylesheet: building it per row means generating a tonal palette per row
    // per streamed delta.
    return ChatMarkdownTheme(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          list,
          if (olderStatus != null)
            Positioned(top: 0, left: 0, right: 0, child: olderStatus),
        ],
      ),
    );
  }
}

/// Keeps timeline visuals readable without narrowing their scroll viewport.
class _ChatTimelineContentColumn extends StatelessWidget {
  const _ChatTimelineContentColumn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: TinestLayoutMetrics.conversationContentMaxWidth,
      ),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

sealed class _ChatTimelineEntry {
  const _ChatTimelineEntry();

  String get key;
}

final class _ChatTimelineItemEntry extends _ChatTimelineEntry {
  const _ChatTimelineItemEntry(this.item);

  final ChatItem item;

  @override
  String get key => item.key;
}

/// The trailing running affordance, present for the whole of a running turn.
///
/// It stays in the list even while [showsIndicator] is false. Reasoning takes
/// the indicator over and hands it back several times within one turn, and
/// inserting and removing a row that often churns the list's keys, drops the
/// neighbouring row's measurement, and flips the trailing padding of whichever
/// row happens to be last — all of which the reader sees as the transcript
/// twitching rather than as an indicator changing.
final class _ChatTimelineRunningEntry extends _ChatTimelineEntry {
  const _ChatTimelineRunningEntry({required this.showsIndicator});

  final bool showsIndicator;

  @override
  String get key => 'chat-running';
}

/// Renders one projected chat item.
class ChatItemView extends StatelessWidget {
  /// Creates a chat item view.
  const ChatItemView({
    required this.item,
    this.expanded = false,
    this.onToggle,
    this.loadAttachment,
    this.exportAttachment,
    this.hostId,
    this.onPluginUiAction,
    super.key,
  });

  /// The item to render.
  final ChatItem item;

  /// Whether an expandable item shows its details.
  final bool expanded;

  /// Called when an expandable item is tapped.
  final VoidCallback? onToggle;

  /// Authenticated attachment byte loader.
  final ChatAttachmentLoader? loadAttachment;

  /// Platform file exporter.
  final ChatAttachmentExporter? exportAttachment;

  /// Host used by actionable interaction rows.
  final String? hostId;

  /// Dispatches actions from a persisted plugin timeline snapshot.
  final ChatPluginUiActionDispatcher? onPluginUiAction;

  @override
  Widget build(BuildContext context) {
    final value = item;
    return switch (value) {
      ChatUserMessage() => ChatUserLine(
        message: value,
        loadAttachment: loadAttachment,
        exportAttachment: exportAttachment,
      ),
      ChatAttachmentMessage() => ChatAttachmentLine(
        message: value,
        loadAttachment: loadAttachment,
        exportAttachment: exportAttachment,
      ),
      ChatAssistantMessage() => ChatAssistantMessageView(message: value),
      ChatReasoningActivity() => ChatReasoningCard(
        activity: value,
        expanded: expanded,
        onToggle: onToggle,
      ),
      ChatPluginUiDocument() => PluginUiDocumentView(
        document: value.document,
        semanticLabel: AppLocalizations.of(
          context,
        ).pluginUiSemanticLabel(value.document.pluginId),
        invalidDocumentLabel: AppLocalizations.of(
          context,
        ).pluginUiInvalidTitle,
        invalidDocumentDescription: AppLocalizations.of(
          context,
        ).pluginUiInvalidDescription(AppIdentity.displayName),
        onAction: onPluginUiAction == null
            ? null
            : (action) => onPluginUiAction!(value.document, action),
      ),
      ChatApprovalInteraction() => ApprovalCard(
        hostId: hostId,
        interaction: value,
      ),
      ChatQuestionInteraction() => ChatQuestionCard(
        key: ValueKey<String>(value.request.id),
        hostId: hostId,
        request: value.request,
      ),
      ChatToolActivity() => ChatToolCard(
        activity: value,
        expanded: expanded,
        onToggle: onToggle,
      ),
      ChatNotice() => ChatNoticeLine(notice: value),
      ChatUserAnswer() => ChatUserAnswerLine(answer: value),
      ChatSleep() => ChatSleepCard(sleep: value),
      ChatDeferredTools() => ChatDeferredToolsLine(notice: value),
      ChatUsage() => ChatUsageLine(usage: value),
      ChatUnknownEvent() => ChatUnknownEventLine(event: value),
    };
  }
}
