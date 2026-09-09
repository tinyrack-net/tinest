import 'package:test/test.dart';
import 'package:tinest_quality/src/generated_sources.dart';

void main() {
  test('stale built-in Lua plugin assets fail the generated-source check', () {
    const path =
        'packages/daemon/lib/src/features/plugins/infrastructure/'
        'builtin_plugin_assets.g.dart';
    expect(GeneratedSources.includesPath(path), isTrue);

    final check = GeneratedSources.compare(
      before: const <String, String>{path: 'old bundle'},
      after: const <String, String>{path: 'new bundle'},
    );

    expect(check.succeeded, isFalse);
    expect(check.changedPaths, const <String>[path]);
  });

  test(
    'Flutter localization outputs are generated at package-relative paths',
    () {
      expect(
        GeneratedSources.includesPath(
          r'lib\l10n\gen\app_localizations_ko.dart',
        ),
        isTrue,
      );
    },
  );

  test('desktop app version synchronization is a generated source', () {
    expect(
      GeneratedSources.includesPath('packages/desktop_app/pubspec.yaml'),
      isTrue,
    );
  });

  test('Freezed outputs remove only trailing horizontal whitespace', () {
    const source = 'alpha  \r\nbeta\t\n  inner gap  \r\nomega\t';

    expect(
      GeneratedSources.normalizeWhitespace(
        path: r'packages\protocol\lib\src\models.freezed.dart',
        source: source,
      ),
      'alpha\r\nbeta\n  inner gap\r\nomega',
    );
    expect(
      GeneratedSources.normalizeWhitespace(
        path: r'packages\protocol\lib\src\models.g.dart',
        source: source,
      ),
      source,
    );
  });

  test('every generated Dart family is sent through the formatter', () {
    expect(
      GeneratedSources.dartFormatPaths(const <String>[
        r'packages\daemon\lib\src\database.g.dart',
        'packages/protocol/lib/src/models.freezed.dart',
        'packages/app/lib/l10n/gen/app_localizations_en.dart',
        'packages/desktop_app/pubspec.yaml',
        'packages/daemon/lib/src/database.dart',
      ]),
      const <String>[
        'packages/app/lib/l10n/gen/app_localizations_en.dart',
        r'packages\daemon\lib\src\database.g.dart',
        'packages/protocol/lib/src/models.freezed.dart',
      ],
    );
  });

  test('generated source records are removed from LCOV input', () {
    const coverage = r'''
SF:C:\workspace\packages\daemon\lib\src\database.g.dart
DA:1,1
LF:1
LH:1
end_of_record
SF:C:\workspace\packages\daemon\lib\src\plugin_service.dart
DA:1,1
LF:1
LH:1
end_of_record
''';

    final filtered = GeneratedSources.excludeFromLcov(coverage);

    expect(filtered, isNot(contains('database.g.dart')));
    expect(filtered, contains('plugin_service.dart'));
    expect(filtered, contains('DA:1,1'));
    expect('end_of_record'.allMatches(filtered), hasLength(1));
  });
}
