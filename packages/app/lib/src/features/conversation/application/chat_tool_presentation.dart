import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/features/conversation/application/chat_timeline_model.dart';
import 'package:app/src/features/conversation/presentation/tools/presenter.dart';

export 'package:app/src/features/conversation/presentation/tools/presenter.dart';

/// Renders normalized token counters as one muted summary line.
///
/// The counters arrive under the stable names `ModelUsage` writes, so this is a
/// fixed set rather than a walk over whatever keys a provider happened to send.
/// Cached input and hidden reasoning are subsets of their parents, so they read
/// as parenthesised qualifiers. The runner also reports how long the response
/// streamed, which becomes a generation rate rather than a raw duration.
/// Returns null when there is nothing to report.
String? describeTokenUsage(AppLocalizations l10n, Map<String, num> tokens) {
  int count(String key) {
    final value = tokens[key];
    return value is num ? value.round() : 0;
  }

  final input = count('inputTokens');
  final cached = count('cachedInputTokens');
  final output = count('outputTokens');
  final reasoning = count('reasoningTokens');
  final total = count('totalTokens');
  if (input == 0 && output == 0 && total == 0) return null;

  // Absent for a response that streamed no token, and for events recorded
  // before the runner measured the span at all.
  final generationMs = count('generationMs');
  final parts = <String>[
    if (input > 0 && cached > 0) l10n.usageInputCached(input, cached),
    if (input > 0 && cached == 0) l10n.usageInput(input),
    if (output > 0 && reasoning > 0)
      l10n.usageOutputReasoning(output, reasoning),
    if (output > 0 && reasoning == 0) l10n.usageOutput(output),
    if (total > 0) l10n.usageTotal(total),
    if (output > 0 && generationMs > 0)
      // Rounded here because `decimalPattern` only localizes the separators;
      // a raw rate would read as `62.41666666666667 tok/s`.
      l10n.usageThroughput(
        (output * 1000 / generationMs * 10).roundToDouble() / 10,
      ),
  ];
  return parts.join(' · ');
}

/// Describes one tool activity for the chat timeline.
ChatToolPresentation describeToolActivity(
  AppLocalizations l10n,
  ChatToolActivity activity,
) {
  final glyph = chatToolGlyphFromPresentation(activity.presentation);
  final title = _toolTitle(activity);
  final argumentBody = prettyToolArgumentBody(activity);
  switch (activity.status) {
    case ChatToolStatus.running:
      return ChatToolPresentation(
        glyph: glyph,
        title: title,
        resultLine: l10n.commonRunning,
        body: const ChatToolEmptyBody(),
        argumentBody: argumentBody,
        isFailure: false,
      );
    case ChatToolStatus.denied:
      return ChatToolPresentation(
        glyph: glyph,
        title: title,
        resultLine: l10n.toolRejected,
        body: const ChatToolEmptyBody(),
        argumentBody: argumentBody,
        isFailure: false,
      );
    case ChatToolStatus.failed:
      return ChatToolPresentation(
        glyph: glyph,
        title: title,
        resultLine: truncateToolText(
          firstToolLine(activity.error ?? l10n.toolFailed),
          120,
        ),
        body: ChatToolTextBody(activity.error ?? ''),
        argumentBody: argumentBody,
        isFailure: true,
      );
    case ChatToolStatus.succeeded:
      final output = decodeToolOutput(activity.output ?? '');
      return ChatToolPresentation(
        glyph: glyph,
        title: title,
        // Successful plugin tools normally publish an immutable declarative
        // UI snapshot. When that document is absent or invalid, the host's
        // generic disclosure shows the raw result exactly once.
        resultLine: null,
        body: plainToolBody(activity, output),
        argumentBody: argumentBody,
        isFailure: activity.isError,
      );
  }
}

/// Decodes a plugin-owned semantic glyph without trusting arbitrary icon data.
ChatToolGlyph chatToolGlyphFromPresentation(Map<String, dynamic> value) =>
    switch (value['glyph']) {
      'read' => ChatToolGlyph.read,
      'list' => ChatToolGlyph.list,
      'search' => ChatToolGlyph.search,
      'edit' => ChatToolGlyph.edit,
      'run' => ChatToolGlyph.run,
      'delegate' => ChatToolGlyph.delegate,
      'ask' => ChatToolGlyph.ask,
      'resource' => ChatToolGlyph.resource,
      'tools' => ChatToolGlyph.tools,
      'clock' => ChatToolGlyph.clock,
      'context' => ChatToolGlyph.context,
      'image' => ChatToolGlyph.image,
      _ => ChatToolGlyph.generic,
    };

/// Host-safe timeline behavior declared by the pinned tool contribution.
ChatToolTimeline chatToolTimelineFromPresentation(Map<String, dynamic> value) =>
    switch (value['timeline']) {
      'suppressed' => ChatToolTimeline.suppressed,
      'question' => ChatToolTimeline.question,
      'sleep' => ChatToolTimeline.sleep,
      _ => ChatToolTimeline.row,
    };

String _toolTitle(ChatToolActivity activity) {
  final rawLabel = activity.presentation['label'];
  final label = rawLabel is String && rawLabel.trim().isNotEmpty
      ? rawLabel.trim()
      : activity.toolName;
  final summaryKey = activity.presentation['summary_argument'];
  final selected = summaryKey is String
      ? activity.arguments[summaryKey]
      : activity.arguments.values
            .where((value) => value is String || value is num || value is bool)
            .firstOrNull;
  if (selected == null) return '$label()';
  return '$label(${truncateToolText(firstToolLine('$selected'), 40)})';
}
