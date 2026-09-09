import 'package:app/src/shared/domain/fuzzy_match.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fuzzyMatch', () {
    test('returns null when the query is not a subsequence', () {
      expect(fuzzyMatch('session_composer.dart', 'zzz'), isNull);
      expect(fuzzyMatch('abc', 'abcd'), isNull);
      expect(fuzzyMatch('', 'a'), isNull);
    }, tags: const <String>['feature_test__composer_file_mention__unit']);

    test('matches an empty query with no highlighted characters', () {
      final match = fuzzyMatch('anything', '');

      expect(match, isNotNull);
      expect(match!.score, 0);
      expect(match.matchedIndices, isEmpty);
    }, tags: const <String>['feature_test__composer_file_mention__unit']);

    test('reports ascending indices that address the candidate', () {
      final match = fuzzyMatch('session_composer.dart', 'scomp')!;

      expect(match.matchedIndices, isNotEmpty);
      expect(
        match.matchedIndices,
        orderedEquals(match.matchedIndices.toList()..sort()),
      );
      expect(
        match.matchedIndices.map((index) => 'session_composer.dart'[index]),
        everyElement(isA<String>()),
      );
      for (final index in match.matchedIndices) {
        expect(index, inInclusiveRange(0, 'session_composer.dart'.length - 1));
      }
    }, tags: const <String>['feature_test__composer_file_mention__unit']);

    test('is case insensitive but rewards an exact-case run', () {
      final exact = fuzzyMatch('Composer', 'Comp')!;
      final folded = fuzzyMatch('Composer', 'comp')!;

      expect(exact.score, greaterThan(folded.score));
    }, tags: const <String>['feature_test__composer_file_mention__unit']);

    test('ranks a whole prefix above an interior match', () {
      final prefix = fuzzyMatch('composer.dart', 'comp')!;
      final interior = fuzzyMatch('the_composer.dart', 'comp')!;

      expect(prefix.score, greaterThan(interior.score));
    }, tags: const <String>['feature_test__composer_file_mention__unit']);

    test('ranks a word-boundary match above a mid-word match', () {
      final boundary = fuzzyMatch('lib/src/app.dart', 'app')!;
      final midWord = fuzzyMatch('lib/wrapper.dart', 'app')!;

      expect(boundary.score, greaterThan(midWord.score));
    }, tags: const <String>['feature_test__composer_file_mention__unit']);

    test('rewards a consecutive run over a scattered subsequence', () {
      final consecutive = fuzzyMatch('xxcomposer', 'comp')!;
      final scattered = fuzzyMatch('xxcxoxmxp', 'comp')!;

      expect(consecutive.score, greaterThan(scattered.score));
    }, tags: const <String>['feature_test__composer_file_mention__unit']);

    test('penalises a long leading gap without rejecting the match', () {
      final near = fuzzyMatch('xapp', 'app')!;
      final far = fuzzyMatch('xxxxxxxxxxxxxxxxxxxxapp', 'app')!;

      expect(far.score, lessThan(near.score));
      expect(far.matchedIndices, hasLength(3));
    }, tags: const <String>['feature_test__composer_file_mention__unit']);

    test('treats a camel-case hump as a word boundary', () {
      final hump = fuzzyMatch('sessionComposer', 'comp')!;
      final midWord = fuzzyMatch('sessioncomposer', 'omp')!;

      expect(hump.score, greaterThan(midWord.score));
    }, tags: const <String>['feature_test__composer_file_mention__unit']);
  });

  group('compareFuzzyCandidates', () {
    test('orders by descending score', () {
      final ordered =
          <({String value, FuzzyMatch match})>[
            (
              value: 'the_composer.dart',
              match: fuzzyMatch('the_composer', 'comp')!,
            ),
            (
              value: 'composer.dart',
              match: fuzzyMatch('composer.dart', 'comp')!,
            ),
          ]..sort(
            (left, right) => compareFuzzyCandidates(
              left.match,
              left.value,
              right.match,
              right.value,
            ),
          );

      expect(ordered.first.value, 'composer.dart');
    }, tags: const <String>['feature_test__composer_file_mention__unit']);

    test('breaks a score tie with the shorter candidate', () {
      const short = 'app.dart';
      const long = 'app.dart.backup';

      expect(
        compareFuzzyCandidates(
          fuzzyMatch(short, 'app')!,
          short,
          fuzzyMatch(long, 'app')!,
          long,
        ),
        lessThan(0),
      );
    }, tags: const <String>['feature_test__composer_file_mention__unit']);

    test('breaks a remaining tie lexicographically for determinism', () {
      const left = 'b/app.dart';
      const right = 'a/app.dart';

      expect(
        compareFuzzyCandidates(
          fuzzyMatch(left, 'app')!,
          left,
          fuzzyMatch(right, 'app')!,
          right,
        ),
        greaterThan(0),
      );
    }, tags: const <String>['feature_test__composer_file_mention__unit']);
  });
}
