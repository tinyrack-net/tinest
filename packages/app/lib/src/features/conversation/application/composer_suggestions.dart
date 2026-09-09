import 'package:app/src/features/conversation/domain/composer_commands.dart';
import 'package:app/src/features/conversation/presentation/composer_trigger.dart';
import 'package:app/src/shared/domain/fuzzy_match.dart';
import 'package:meta/meta.dart';
import 'package:protocol/protocol.dart';

/// How many rows the composer offers at once, matching every other popup.
const int composerSuggestionLimit = 8;

/// One row the composer offers for the active trigger.
@immutable
final class ComposerSuggestion {
  /// Creates a suggestion.
  const new({
    required this.id,
    required this.label,
    required this.replacement,
    this.description = '',
    this.hint,
    this.badge,
    this.matchedIndices = const <int>[],
    this.command,
  });

  /// Stable identity within one list.
  final String id;

  /// Primary text; [matchedIndices] indexes into this string.
  final String label;

  /// Text that replaces the trigger token, including its sigil.
  final String replacement;

  /// Secondary line shown beneath the label.
  final String description;

  /// Trailing affordance, such as an argument hint.
  final String? hint;

  /// Short source tag, such as the command kind.
  final String? badge;

  /// Characters of [label] the query matched.
  final List<int> matchedIndices;

  /// Set for a `/` row so a caller can inspect the command it names.
  final ComposerCommand? command;

  @override
  bool operator ==(Object other) =>
      other is ComposerSuggestion &&
      other.id == id &&
      other.label == label &&
      other.replacement == replacement &&
      other.description == description &&
      other.hint == hint &&
      other.badge == badge &&
      other.command == command;

  @override
  int get hashCode =>
      Object.hash(id, label, replacement, description, hint, badge, command);
}

/// Re-ranks daemon matches so highlight spans come from the same scorer the
/// command list uses.
///
/// The daemon ranks coarsely to bound what it sends; the app decides the order
/// the user sees and which characters to emphasise.
List<FileMatchDto> rankFileMatches(List<FileMatchDto> matches, String query) {
  if (query.isEmpty) return List<FileMatchDto>.unmodifiable(matches);

  final scored = <({FileMatchDto match, FuzzyMatch score})>[];
  for (final match in matches) {
    // A mention is typed as a path, so the path is what the query addresses;
    // a basename-only hit still scores through it.
    final score = fuzzyMatch(match.relativePath, query);
    if (score == null) continue;
    scored.add((match: match, score: score));
  }
  scored.sort(
    (left, right) => compareFuzzyCandidates(
      left.score,
      left.match.relativePath,
      right.score,
      right.match.relativePath,
    ),
  );
  return List<FileMatchDto>.unmodifiable(scored.map((entry) => entry.match));
}

/// Builds the rows shown for an `@` trigger.
List<ComposerSuggestion> fileSuggestions(
  List<FileMatchDto> matches,
  String query,
) => List<ComposerSuggestion>.unmodifiable(<ComposerSuggestion>[
  for (final match in matches.take(composerSuggestionLimit))
    ComposerSuggestion(
      id: match.relativePath,
      label: match.relativePath,
      replacement: renderFileMention(match.relativePath),
      description: match.isDirectory ? '' : match.name,
      matchedIndices:
          fuzzyMatch(match.relativePath, query)?.matchedIndices ??
          const <int>[],
    ),
]);

/// Builds the rows shown for a `/` trigger.
List<ComposerSuggestion> commandSuggestions(
  List<ComposerCommand> commands,
  String query, {
  String Function(ComposerCommandKind kind)? badgeOf,
}) => List<ComposerSuggestion>.unmodifiable(<ComposerSuggestion>[
  for (final ranked in rankComposerCommands(
    commands,
    query,
  ).take(composerSuggestionLimit))
    ComposerSuggestion(
      id: ranked.command.id,
      label: ranked.command.name,
      replacement: '/${ranked.command.name}',
      description: ranked.command.description,
      hint: ranked.command.argumentHint,
      badge: badgeOf?.call(ranked.command.kind),
      matchedIndices: ranked.match.matchedIndices,
      command: ranked.command,
    ),
]);
