import 'package:app/src/features/conversation/presentation/composer_trigger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Builds a value whose caret sits where `|` appears in [text].
  TextEditingValue at(String text, {TextRange? composing}) {
    final caret = text.indexOf('|');
    expect(caret, isNonNegative, reason: 'mark the caret with |');
    return TextEditingValue(
      text: text.replaceFirst('|', ''),
      selection: TextSelection.collapsed(offset: caret),
      composing: composing ?? TextRange.empty,
    );
  }

  group('parseComposerTrigger file mentions', () {
    test('fires on a bare @ at the start of the message', () {
      final trigger = parseComposerTrigger(at('@|'))!;

      expect(trigger.kind, ComposerTriggerKind.file);
      expect(trigger.start, 0);
      expect(trigger.end, 1);
      expect(trigger.query, isEmpty);
    }, tags: const <String>['feature_test__composer_file_mention__unit']);

    test('captures the path typed after the sigil', () {
      final trigger = parseComposerTrigger(at('look at @lib/src|'))!;

      expect(trigger.kind, ComposerTriggerKind.file);
      expect(trigger.start, 8);
      expect(trigger.end, 16);
      expect(trigger.query, 'lib/src');
    }, tags: const <String>['feature_test__composer_file_mention__unit']);

    test('fires after a newline', () {
      final trigger = parseComposerTrigger(at('first line\n@app|'))!;

      expect(trigger.kind, ComposerTriggerKind.file);
      expect(trigger.query, 'app');
    }, tags: const <String>['feature_test__composer_file_mention__unit']);

    test('does not fire inside an email address', () {
      expect(parseComposerTrigger(at('mail user@example|')), isNull);
    }, tags: const <String>['feature_test__composer_file_mention__unit']);

    test('does not fire when the sigil follows a word character', () {
      expect(parseComposerTrigger(at('a@b|')), isNull);
    }, tags: const <String>['feature_test__composer_file_mention__unit']);

    test('completes only the prefix left of a mid-token caret', () {
      final trigger = parseComposerTrigger(at('@lib/|src/app.dart'))!;

      expect(trigger.start, 0);
      expect(trigger.end, 5);
      expect(trigger.query, 'lib/');
    }, tags: const <String>['feature_test__composer_file_mention__unit']);
  });

  group('parseComposerTrigger slash commands', () {
    test('fires on a bare slash in an empty message', () {
      final trigger = parseComposerTrigger(at('/|'))!;

      expect(trigger.kind, ComposerTriggerKind.command);
      expect(trigger.start, 0);
      expect(trigger.query, isEmpty);
    }, tags: const <String>['feature_test__composer_slash_command__unit']);

    test('captures the command name', () {
      final trigger = parseComposerTrigger(at('/clear|'))!;

      expect(trigger.kind, ComposerTriggerKind.command);
      expect(trigger.start, 0);
      expect(trigger.end, 6);
      expect(trigger.query, 'clear');
    }, tags: const <String>['feature_test__composer_slash_command__unit']);

    test('tolerates leading whitespace before the sigil', () {
      final trigger = parseComposerTrigger(at('   /clear|'))!;

      expect(trigger.kind, ComposerTriggerKind.command);
      expect(trigger.start, 3);
      expect(trigger.query, 'clear');
    }, tags: const <String>['feature_test__composer_slash_command__unit']);

    test('does not fire on a path segment', () {
      expect(parseComposerTrigger(at('src/foo|')), isNull);
    }, tags: const <String>['feature_test__composer_slash_command__unit']);

    test('does not fire mid-sentence', () {
      expect(parseComposerTrigger(at('please run /clear|')), isNull);
    }, tags: const <String>['feature_test__composer_slash_command__unit']);

    test('does not fire on a later line', () {
      expect(parseComposerTrigger(at('context\n/clear|')), isNull);
    }, tags: const <String>['feature_test__composer_slash_command__unit']);

    test('stops once the command name is followed by arguments', () {
      expect(parseComposerTrigger(at('/review lib/app.dart|')), isNull);
    }, tags: const <String>['feature_test__composer_slash_command__unit']);
  });

  group('parseComposerTrigger guards', () {
    test('ignores a ranged selection', () {
      const value = TextEditingValue(
        text: '@app',
        selection: TextSelection(baseOffset: 1, extentOffset: 4),
      );

      expect(parseComposerTrigger(value), isNull);
    }, tags: const <String>['feature_test__composer_file_mention__unit']);

    test('ignores an invalid selection', () {
      const value = TextEditingValue(text: '@app');

      expect(parseComposerTrigger(value), isNull);
    }, tags: const <String>['feature_test__composer_file_mention__unit']);

    test('keeps a composition that began inside the token', () {
      final trigger = parseComposerTrigger(
        at('@한|', composing: const TextRange(start: 1, end: 2)),
      );

      expect(trigger, isNotNull);
      expect(trigger!.query, '한');
    }, tags: const <String>['feature_test__composer_file_mention__unit']);

    test('drops a composition that spans the sigil', () {
      expect(
        parseComposerTrigger(
          at('@app|', composing: const TextRange(start: 0, end: 4)),
        ),
        isNull,
      );
    }, tags: const <String>['feature_test__composer_file_mention__unit']);

    test('ignores a query longer than the guard allows', () {
      final long = 'x' * (composerTriggerMaxQuery + 1);

      expect(parseComposerTrigger(at('@$long|')), isNull);
    }, tags: const <String>['feature_test__composer_file_mention__unit']);

    test('accepts a query exactly at the guard length', () {
      final exact = 'x' * composerTriggerMaxQuery;

      expect(parseComposerTrigger(at('@$exact|'))!.query, exact);
    }, tags: const <String>['feature_test__composer_file_mention__unit']);

    test('returns null for text with no sigil', () {
      expect(parseComposerTrigger(at('plain prompt|')), isNull);
    }, tags: const <String>['feature_test__composer_file_mention__unit']);
  });

  group('applyComposerCompletion', () {
    TextEditingValue complete(
      String text,
      String replacement, {
      bool appendSpace = true,
    }) {
      final value = at(text);
      return applyComposerCompletion(
        value: value,
        trigger: parseComposerTrigger(value)!,
        replacement: replacement,
        appendSpace: appendSpace,
      );
    }

    test('splices the replacement over the trigger range', () {
      final result = complete('look at @lib|', '@lib/src/app.dart');

      expect(result.text, 'look at @lib/src/app.dart ');
      expect(result.selection.baseOffset, result.text.length);
      expect(result.selection.isCollapsed, isTrue);
    }, tags: const <String>['feature_test__composer_file_mention__unit']);

    test('preserves the text to the right of the caret', () {
      final result = complete('@lib| and more', '@lib/app.dart');

      expect(result.text, '@lib/app.dart and more');
      expect(result.selection.baseOffset, '@lib/app.dart'.length);
    }, tags: const <String>['feature_test__composer_file_mention__unit']);

    test('does not double a space that already follows', () {
      final result = complete('@lib| rest', '@lib/app.dart');

      expect(result.text, '@lib/app.dart rest');
    }, tags: const <String>['feature_test__composer_file_mention__unit']);

    test('omits the trailing space when the caller declines it', () {
      final result = complete('@lib|', '@lib/app.dart', appendSpace: false);

      expect(result.text, '@lib/app.dart');
    }, tags: const <String>['feature_test__composer_file_mention__unit']);

    test('clears a stale composing range', () {
      final value = at('@app|', composing: const TextRange(start: 1, end: 4));
      final result = applyComposerCompletion(
        value: value,
        trigger: parseComposerTrigger(value)!,
        replacement: '@app.dart',
      );

      expect(result.composing, TextRange.empty);
    }, tags: const <String>['feature_test__composer_file_mention__unit']);

    test('completes a command without disturbing later lines', () {
      final result = complete('/cle|\nsecond line', '/clear');

      // The newline already separates the command, so no space is inserted.
      expect(result.text, '/clear\nsecond line');
      expect(result.selection.baseOffset, '/clear'.length);
    }, tags: const <String>['feature_test__composer_file_mention__unit']);
  });

  group('renderFileMention', () {
    test('leaves an ordinary path unquoted', () {
      expect(renderFileMention('lib/src/app.dart'), '@lib/src/app.dart');
    }, tags: const <String>['feature_test__composer_file_mention__unit']);

    test('quotes a path containing whitespace', () {
      expect(renderFileMention('lib/my file.dart'), '@"lib/my file.dart"');
    }, tags: const <String>['feature_test__composer_file_mention__unit']);

    test('escapes and quotes a path containing a double quote', () {
      expect(renderFileMention('lib/a"b.dart'), r'@"lib/a\"b.dart"');
    }, tags: const <String>['feature_test__composer_file_mention__unit']);
  });
}
