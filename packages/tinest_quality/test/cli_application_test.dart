import 'package:test/test.dart';

import '../bin/src/application.dart';

void main() {
  test('empty input renders public help and hides internal commands', () async {
    final output = <Object?>[];
    final errors = <Object?>[];

    final code = await runTinestQuality(
      const <String>[],
      out: output.add,
      error: errors.add,
    );

    expect(code, 0);
    expect(output.join(), contains('generate'));
    expect(output.join(), contains('verify'));
    expect(output.join(), isNot(contains('_test-dart')));
    expect(errors, isEmpty);
  });

  test('unknown commands and flags are usage errors', () async {
    final errors = <Object?>[];

    expect(
      await runTinestQuality(const <String>['missing'], error: errors.add),
      64,
    );
    expect(
      await runTinestQuality(const <String>[
        'verify',
        '--unknown',
      ], error: errors.add),
      64,
    );
    expect(
      await runTinestQuality(const <String>[
        'verify',
        '--jobs=0',
      ], error: errors.add),
      64,
    );
    expect(
      await runTinestQuality(const <String>[
        'verify',
        '--report=',
      ], error: errors.add),
      64,
    );
    expect(errors.join(), isNotEmpty);
  });

  test('internal commands remain routable but hidden', () async {
    final output = <Object?>[];

    expect(
      await runTinestQuality(const <String>[
        '_test-dart',
        '--help',
      ], out: output.add),
      0,
    );
    expect(output.join(), contains('--scope'));

    output.clear();
    expect(
      await runTinestQuality(const <String>[
        '_test-flutter',
        '--help',
      ], out: output.add),
      0,
    );
    expect(output.join(), contains('--scope'));
  });
}
