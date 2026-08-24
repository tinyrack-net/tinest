import 'dart:convert';

import 'package:app/src/features/conversation/application/chat_timeline_model.dart';

/// Decoded shape of `tool.completed.output`, which some tools double-encode.
sealed class ChatToolOutput {
  const ChatToolOutput();
}

/// Output that decoded into a JSON object.
final class ChatToolJsonObject extends ChatToolOutput {
  /// Creates a decoded JSON object output.
  const ChatToolJsonObject(this.value);

  /// The decoded object.
  final Map<String, dynamic> value;
}

/// Output that decoded into a JSON array.
final class ChatToolJsonArray extends ChatToolOutput {
  /// Creates a decoded JSON array output.
  const ChatToolJsonArray(this.value);

  /// The decoded array.
  final List<dynamic> value;
}

/// Output that is plain text, or JSON that failed to decode.
final class ChatToolPlainText extends ChatToolOutput {
  /// Creates a plain-text output.
  const ChatToolPlainText(this.value);

  /// The raw text.
  final String value;
}

/// Decodes tool output without ever throwing.
ChatToolOutput decodeToolOutput(String raw) {
  final trimmed = raw.trim();
  if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
    return ChatToolPlainText(raw);
  }
  try {
    final decoded = json.decode(trimmed);
    if (decoded is Map<String, dynamic>) return ChatToolJsonObject(decoded);
    if (decoded is List<dynamic>) return ChatToolJsonArray(decoded);
    return ChatToolPlainText(raw);
  } on FormatException {
    return ChatToolPlainText(raw);
  }
}

/// Expanded body of one tool activity.
sealed class ChatToolBody {
  const ChatToolBody();
}

/// Nothing to show beyond the summary.
final class ChatToolEmptyBody extends ChatToolBody {
  /// Creates an empty body.
  const ChatToolEmptyBody();
}

/// Monospace text such as command output or a file slice.
final class ChatToolTextBody extends ChatToolBody {
  /// Creates a text body.
  const ChatToolTextBody(this.text);

  /// The text to render.
  final String text;
}

/// Icon family used by the collapsed tool row.
enum ChatToolGlyph {
  /// File reads.
  read,

  /// Directory listings.
  list,

  /// Text searches.
  search,

  /// File edits.
  edit,

  /// Shell commands.
  run,

  /// Subagent delegation.
  delegate,

  /// Questions put to the user.
  ask,

  /// MCP resource discovery and reads.
  resource,

  /// Tool discovery.
  tools,

  /// Time and waiting.
  clock,

  /// The model's own context window.
  context,

  /// Images loaded into the model context.
  image,

  /// Anything this build does not know.
  generic,
}

/// Everything the UI needs to draw one tool activity, from data only.
final class ChatToolPresentation {
  /// Creates a tool presentation.
  const ChatToolPresentation({
    required this.glyph,
    required this.title,
    required this.resultLine,
    required this.body,
    required this.isFailure,
    this.argumentBody = const ChatToolEmptyBody(),
  });

  /// Icon family for the collapsed row.
  final ChatToolGlyph glyph;

  /// CLI-style one-line title such as `Read(lib/main.dart)`.
  final String title;

  /// Short Korean result summary, or null while nothing is known.
  final String? resultLine;

  /// Expanded result content.
  final ChatToolBody body;

  /// Expanded request content, shown above [body].
  final ChatToolBody argumentBody;

  /// Whether the result should be styled as an error.
  final bool isFailure;
}

/// How one tool's activity appears in the timeline.
enum ChatToolTimeline {
  /// A collapsed tool row, like most tools.
  row,

  /// Nothing: the activity already renders as its own item, so a row beside
  /// it would only repeat what the reader can already see.
  suppressed,

  /// A host-owned structured question interaction.
  question,

  /// A host-owned cancellable sleep activity.
  sleep,
}

/// Renders whatever a tool returned, pretty-printing structured output.
ChatToolBody plainToolBody(ChatToolActivity activity, ChatToolOutput output) =>
    switch (output) {
      ChatToolPlainText(:final value) =>
        value.isEmpty ? const ChatToolEmptyBody() : ChatToolTextBody(value),
      ChatToolJsonObject(:final value) => ChatToolTextBody(prettyJson(value)),
      ChatToolJsonArray(:final value) => ChatToolTextBody(prettyJson(value)),
    };

/// Dumps a tool call's arguments, for tools whose title omits them.
ChatToolBody prettyToolArgumentBody(ChatToolActivity activity) =>
    activity.arguments.isEmpty
    ? const ChatToolEmptyBody()
    : ChatToolTextBody(prettyJson(activity.arguments));

/// Indents a decoded JSON value for the expanded view.
String prettyJson(Object value) =>
    const JsonEncoder.withIndent('  ').convert(value);

/// The first line of [text], trimmed.
String firstToolLine(String text) {
  final line = text.split('\n').firstOrNull ?? '';
  return line.trim();
}

/// Shortens [text] to [max] characters with an ellipsis.
String truncateToolText(String text, int max) =>
    text.length <= max ? text : '${text.substring(0, max - 1)}…';
