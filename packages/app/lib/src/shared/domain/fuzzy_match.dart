import 'package:meta/meta.dart';

/// One scored subsequence match, with the characters a UI should highlight.
@immutable
final class FuzzyMatch {
  /// Creates a fuzzy match.
  const new({required this.score, required this.matchedIndices});

  /// Higher is a better match; only comparable within one query.
  final int score;

  /// Ascending indices into the candidate that the query matched.
  final List<int> matchedIndices;

  @override
  bool operator ==(Object other) =>
      other is FuzzyMatch &&
      other.score == score &&
      _sameIndices(other.matchedIndices, matchedIndices);

  @override
  int get hashCode => Object.hash(score, Object.hashAll(matchedIndices));

  static bool _sameIndices(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}

/// Bonus for a query character that also matched the candidate's case.
const int _exactCaseBonus = 8;

/// Bonus for landing on a word boundary rather than inside a word.
const int _boundaryBonus = 60;

/// Bonus for continuing an unbroken run of matched characters.
const int _consecutiveBonus = 40;

/// Bonus when the query is a whole prefix of the candidate.
const int _prefixBonus = 150;

/// Penalty per character skipped before the first match.
const int _leadingGapPenalty = 3;

/// Largest total leading-gap penalty, so a deep match stays rankable.
const int _maxLeadingGapPenalty = 30;

/// Penalty per character skipped between matches.
const int _interiorGapPenalty = 1;

/// Scores [query] against [candidate], or returns null when it cannot match.
///
/// The scan is greedy left to right with a one-step lookahead, so a query
/// character prefers a word boundary over the first position that merely
/// works. An empty query matches everything with no highlights.
FuzzyMatch? fuzzyMatch(String candidate, String query) {
  if (query.isEmpty) {
    return const FuzzyMatch(score: 0, matchedIndices: <int>[]);
  }
  if (candidate.isEmpty || query.length > candidate.length) return null;

  final foldedCandidate = candidate.toLowerCase();
  final foldedQuery = query.toLowerCase();

  final matched = <int>[];
  var score = 0;
  var cursor = 0;
  var previousMatch = -1;

  for (var index = 0; index < foldedQuery.length; index += 1) {
    final found = _findBest(foldedCandidate, foldedQuery, index, cursor);
    if (found < 0) return null;

    final gap = previousMatch < 0 ? found : found - previousMatch - 1;
    if (previousMatch < 0) {
      score -= (gap * _leadingGapPenalty).clamp(0, _maxLeadingGapPenalty);
    } else if (gap == 0) {
      score += _consecutiveBonus;
    } else {
      score -= gap * _interiorGapPenalty;
    }
    if (_isBoundary(candidate, found)) score += _boundaryBonus;
    if (candidate.codeUnitAt(found) == query.codeUnitAt(index)) {
      score += _exactCaseBonus;
    }

    matched.add(found);
    previousMatch = found;
    cursor = found + 1;
  }

  if (foldedCandidate.startsWith(foldedQuery)) score += _prefixBonus;
  return FuzzyMatch(
    score: score,
    matchedIndices: List<int>.unmodifiable(matched),
  );
}

/// Picks where `query[at]` should land in [candidate] at or after [from].
///
/// Preferring a word boundary outright would break a longer unbroken run —
/// `app` in `a/app.dart` must land on the second `a`, not the first — so the
/// run the choice sustains is weighed first, then the boundary, then position.
int _findBest(String candidate, String query, int at, int from) {
  final wanted = query.codeUnitAt(at);
  var best = -1;
  var bestRun = -1;
  var bestBoundary = false;

  for (var index = from; index < candidate.length; index += 1) {
    if (candidate.codeUnitAt(index) != wanted) continue;
    final run = _runLength(candidate, query, at, index);
    final boundary = _isBoundary(candidate, index);
    if (run > bestRun || (run == bestRun && boundary && !bestBoundary)) {
      best = index;
      bestRun = run;
      bestBoundary = boundary;
    }
    // A boundary-anchored full run cannot be beaten by a later position.
    if (bestBoundary && bestRun == query.length - at) break;
  }
  return best;
}

/// How much of `query[at..]` continues unbroken from [start].
int _runLength(String candidate, String query, int at, int start) {
  var length = 0;
  while (at + length < query.length &&
      start + length < candidate.length &&
      candidate.codeUnitAt(start + length) == query.codeUnitAt(at + length)) {
    length += 1;
  }
  return length;
}

const int _upperA = 0x41;
const int _upperZ = 0x5a;
const int _lowerA = 0x61;
const int _lowerZ = 0x7a;
const Set<int> _separators = <int>{
  0x2f, // /
  0x5c, // \
  0x5f, // _
  0x2d, // -
  0x2e, // .
  0x20, // space
};

bool _isBoundary(String candidate, int index) {
  if (index == 0) return true;
  final previous = candidate.codeUnitAt(index - 1);
  if (_separators.contains(previous)) return true;
  final current = candidate.codeUnitAt(index);
  // A camel-case hump starts a word just as much as a separator does.
  return previous >= _lowerA &&
      previous <= _lowerZ &&
      current >= _upperA &&
      current <= _upperZ;
}

/// Orders two scored candidates: best score, then shortest, then alphabetical.
///
/// The final lexicographic step keeps ordering stable so a list does not
/// reshuffle between identical queries.
int compareFuzzyCandidates(
  FuzzyMatch left,
  String leftCandidate,
  FuzzyMatch right,
  String rightCandidate,
) {
  final byScore = right.score.compareTo(left.score);
  if (byScore != 0) return byScore;
  final byLength = leftCandidate.length.compareTo(rightCandidate.length);
  if (byLength != 0) return byLength;
  return leftCandidate.compareTo(rightCandidate);
}
