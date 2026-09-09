import 'package:test/test.dart';

import '../tool/src/smoke_relay_cli.dart';

void main() {
  test('parses the base URI and optional ready file', () async {
    Uri? base;
    String? readyFile;

    expect(
      await runRelaySmokeCli(
        const <String>['https://relay.example', 'ready.txt'],
        execute: (value, path) async {
          base = value;
          readyFile = path;
        },
      ),
      0,
    );
    expect(base, Uri.parse('https://relay.example'));
    expect(readyFile, 'ready.txt');
  });

  test(
    'rejects missing, extra, and unknown inputs without side effects',
    () async {
      var executions = 0;
      for (final arguments in <List<String>>[
        <String>[],
        <String>['https://relay.example', 'ready', 'extra'],
        <String>['--unknown'],
      ]) {
        expect(
          await runRelaySmokeCli(
            arguments,
            execute: (_, _) async => executions += 1,
          ),
          64,
        );
      }
      expect(executions, 0);
    },
  );

  test('help exits without running the smoke protocol', () async {
    var executions = 0;
    expect(
      await runRelaySmokeCli(const <String>[
        '--help',
      ], execute: (_, _) async => executions += 1),
      0,
    );
    expect(executions, 0);
  });
}
