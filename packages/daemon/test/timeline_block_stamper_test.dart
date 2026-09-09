import 'package:daemon/src/features/sessions/infrastructure/timeline_blocks.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:test/test.dart';

void main() {
  late TimelineBlockStamper stamper;

  setUp(() => stamper = TimelineBlockStamper(ids: _SequentialIds()));

  Map<String, dynamic> stamp(String type, {String turnId = 'turn-1'}) =>
      stamper.stamp(
        turnId: turnId,
        type: type,
        data: <String, dynamic>{'text': 'chunk'},
      );

  String? blockOf(Map<String, dynamic> data) => data['blockId'] as String?;

  test(
    'every delta of one uninterrupted block carries the same identity',
    () {
      final first = stamp('assistant.delta');
      final second = stamp('assistant.delta');
      final third = stamp('assistant.delta');

      expect(blockOf(first), 'block-1');
      expect(
        <String?>[blockOf(second), blockOf(third)],
        everyElement(blockOf(first)),
        reason: 'a reader that loads any one delta can name the whole block',
      );
      expect(
        first['text'],
        'chunk',
        reason: 'stamping carries the payload it was given',
      );
    },
    tags: const <String>['feature_test__conversation_history_pagination__unit'],
  );

  test(
    'an interruption starts the next block rather than extending this one',
    () {
      final before = stamp('assistant.delta');
      stamp('tool.requested');
      final after = stamp('assistant.delta');

      expect(blockOf(after), isNot(blockOf(before)));
      expect(
        blockOf(stamp('assistant.delta')),
        blockOf(after),
        reason: 'the block reopened by the interruption keeps going',
      );
    },
    tags: const <String>['feature_test__conversation_history_pagination__unit'],
  );

  test(
    'prose and reasoning are separate blocks that interrupt each other',
    () {
      final prose = stamp('assistant.delta');
      final reasoning = stamp('assistant.reasoning.delta');
      final resumed = stamp('assistant.delta');

      expect(blockOf(reasoning), isNot(blockOf(prose)));
      expect(blockOf(resumed), isNot(blockOf(prose)));
      expect(blockOf(resumed), isNot(blockOf(reasoning)));
      expect(
        blockOf(stamp('assistant.reasoning.delta')),
        isNot(blockOf(reasoning)),
        reason: 'prose closed the reasoning block it interrupted',
      );
    },
    tags: const <String>['feature_test__conversation_history_pagination__unit'],
  );

  test(
    'a declared reasoning phase owns the deltas that follow it',
    () {
      final started = stamp('assistant.reasoning.started');
      final delta = stamp('assistant.reasoning.delta');

      expect(blockOf(delta), blockOf(started));
    },
    tags: const <String>['feature_test__conversation_history_pagination__unit'],
  );

  test(
    'concurrent turns never share a block, and a finished turn is released',
    () {
      final left = stamp('assistant.delta', turnId: 'turn-a');
      final right = stamp('assistant.delta', turnId: 'turn-b');
      expect(blockOf(right), isNot(blockOf(left)));
      expect(
        blockOf(stamp('assistant.delta', turnId: 'turn-a')),
        blockOf(left),
        reason: 'the other turn did not disturb this one',
      );

      // Every turn ends on an event that is not a delta, so the close rule is
      // also what stops a long-lived daemon accumulating turns.
      stamp('turn.completed', turnId: 'turn-a');
      expect(stamper.openBlockCount, 1);
      stamp('turn.completed', turnId: 'turn-b');
      expect(stamper.openBlockCount, 0);
    },
    tags: const <String>['feature_test__conversation_history_pagination__unit'],
  );

  test(
    'an event that is not part of a block is stamped with nothing',
    () {
      expect(blockOf(stamp('user.message')), isNull);
      expect(blockOf(stamp('tool.completed')), isNull);
      expect(
        stamper.stamp(
          turnId: null,
          type: 'assistant.delta',
          data: <String, dynamic>{'text': 'chunk'},
        )['blockId'],
        isNull,
        reason: 'a block belongs to a turn, so an event without one has none',
      );
    },
    tags: const <String>['feature_test__conversation_history_pagination__unit'],
  );
}

final class _SequentialIds implements IdGenerator {
  var _next = 0;

  @override
  String generate() => 'block-${_next += 1}';
}
