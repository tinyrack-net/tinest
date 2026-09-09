import 'package:flutter/widgets.dart';

/// Which completion source an active composer token asks for.
enum ComposerTriggerKind {
  /// A `/` command typed as the first token of the message.
  command,

  /// An `@` file mention typed anywhere after whitespace.
  file,
}

/// Longest query the composer completes before it stops searching.
///
/// A pasted blob would otherwise spin the file index on every keystroke.
const int composerTriggerMaxQuery = 128;

const String _commandSigil = '/';
const String _fileSigil = '@';

/// One completion token resolved from the caret position.
@immutable
final class ComposerTrigger {
  /// Creates a trigger.
  const new({
    required this.kind,
    required this.start,
    required this.end,
    required this.query,
  });

  /// Which completion list the token asks for.
  final ComposerTriggerKind kind;

  /// Index of the sigil character.
  final int start;

  /// Exclusive end of the token, always the caret offset.
  final int end;

  /// Text typed after the sigil and left of the caret.
  final String query;

  /// Identity of the token, so a UI can reset when the caret moves to a new
  /// one but not when the same token merely gains characters.
  Object get sessionKey => (kind, start);

  @override
  bool operator ==(Object other) =>
      other is ComposerTrigger &&
      other.kind == kind &&
      other.start == start &&
      other.end == end &&
      other.query == query;

  @override
  int get hashCode => Object.hash(kind, start, end, query);
}

/// Resolves the completion token under the caret, or null when there is none.
///
/// The rules differ per sigil on purpose. `@` fires anywhere a word could
/// start, so `user@example.com` stays untouched. `/` fires only as the first
/// token of the message, which removes `src/foo`, `and/or`, and `1/2`, and
/// matches the dispatch model where a command replaces the whole submission.
ComposerTrigger? parseComposerTrigger(TextEditingValue value) {
  final selection = value.selection;
  if (!selection.isValid || !selection.isCollapsed) return null;

  final text = value.text;
  final caret = selection.baseOffset;
  if (caret < 0 || caret > text.length) return null;

  // Scan back to the start of the whitespace-delimited token, never crossing a
  // line break: a mention belongs to the line it was typed on.
  var start = caret;
  while (start > 0 && !_isWhitespace(text.codeUnitAt(start - 1))) {
    start -= 1;
  }
  if (start >= caret) return null;

  final sigil = text[start];
  final kind = switch (sigil) {
    _fileSigil => ComposerTriggerKind.file,
    _commandSigil => ComposerTriggerKind.command,
    _ => null,
  };
  if (kind == null) return null;

  // A composition spanning the sigil is a half-typed word, not a mention; one
  // that began inside the token is ordinary Korean or Japanese input.
  final composing = value.composing;
  if (composing.isValid && composing.start < start + 1) return null;

  if (kind == ComposerTriggerKind.command && !_isMessageStart(text, start)) {
    return null;
  }

  final query = text.substring(start + 1, caret);
  if (query.length > composerTriggerMaxQuery) return null;

  return ComposerTrigger(kind: kind, start: start, end: caret, query: query);
}

/// Whether only whitespace precedes [index] in the whole message.
bool _isMessageStart(String text, int index) {
  for (var cursor = 0; cursor < index; cursor += 1) {
    if (!_isWhitespace(text.codeUnitAt(cursor))) return false;
  }
  return true;
}

bool _isWhitespace(int codeUnit) =>
    codeUnit == 0x20 || // space
    codeUnit == 0x09 || // tab
    codeUnit == 0x0a || // line feed
    codeUnit == 0x0d; // carriage return

/// Replaces [trigger]'s range with [replacement] and collapses the caret after
/// it.
///
/// [replacement] carries its own sigil, so a caller supplies `@lib/app.dart`
/// or `/clear` rather than only the completed remainder.
TextEditingValue applyComposerCompletion({
  required TextEditingValue value,
  required ComposerTrigger trigger,
  required String replacement,
  bool appendSpace = true,
}) {
  final text = value.text;
  final before = text.substring(0, trigger.start);
  final after = text.substring(trigger.end);
  final needsSpace =
      appendSpace && (after.isEmpty || !_isWhitespace(after.codeUnitAt(0)));
  final inserted = needsSpace ? '$replacement ' : replacement;

  // The default empty composing range is what we want: a splice invalidates
  // any range the input method was still tracking.
  return TextEditingValue(
    text: '$before$inserted$after',
    selection: TextSelection.collapsed(offset: before.length + inserted.length),
  );
}

/// Renders one worktree-relative path as the text a mention inserts.
///
/// Quoting keeps a path with spaces readable as a single argument to the
/// agent instead of splitting across the prompt.
String renderFileMention(String relativePath) {
  final needsQuotes =
      relativePath.contains('"') || relativePath.codeUnits.any(_isWhitespace);
  if (!needsQuotes) return '$_fileSigil$relativePath';
  final escaped = relativePath.replaceAll('"', r'\"');
  return '$_fileSigil"$escaped"';
}
