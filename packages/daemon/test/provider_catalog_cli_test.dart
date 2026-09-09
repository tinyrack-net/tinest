import 'package:test/test.dart';

import '../tool/src/provider_catalog_cli.dart';

void main() {
  test('dispatches the typed update flag', () async {
    bool? capturedUpdate;

    expect(
      await runProviderCatalogCli(const <String>[
        '--update',
      ], generate: ({required update}) async => capturedUpdate = update),
      0,
    );
    expect(capturedUpdate, isTrue);
  });

  test('omitting update dispatches a non-refreshing generation', () async {
    bool? capturedUpdate;
    expect(
      await runProviderCatalogCli(
        const <String>[],
        generate: ({required update}) async => capturedUpdate = update,
      ),
      0,
    );
    expect(capturedUpdate, isFalse);
  });

  test('rejects unknown arguments before generating', () async {
    var generations = 0;

    expect(
      await runProviderCatalogCli(const <String>[
        '--unknown',
      ], generate: ({required update}) async => generations += 1),
      64,
    );
    expect(generations, 0);
  });

  test('help exits without generating', () async {
    var generations = 0;
    expect(
      await runProviderCatalogCli(const <String>[
        '--help',
      ], generate: ({required update}) async => generations += 1),
      0,
    );
    expect(generations, 0);
  });
}
