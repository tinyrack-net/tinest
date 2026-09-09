@Tags(<String>['feature_test__daemon_management__unit'])
library;

import 'dart:async';

import 'package:cli/cli.dart';
import 'package:daemon/daemon.dart';
import 'package:test/test.dart';

void main() {
  const defaults = DaemonConfig(
    homeDirectory: '/state',
    configDirectory: '/config',
  );

  group('resolveDaemonConfig', () {
    test('keeps the defaults when no option is given', () {
      final config = resolveDaemonConfig(defaults: defaults);

      expect(config.homeDirectory, '/state');
      expect(config.configDirectory, '/config');
      expect(config.host, '127.0.0.1');
      expect(config.port, 7337);
      expect(config.bearerToken, isNull);
      expect(config.allowedOrigins, defaultAllowedOrigins);
    });

    test('--home sets both the state and config directories', () {
      final config = resolveDaemonConfig(defaults: defaults, home: '/portable');

      expect(config.homeDirectory, '/portable');
      expect(config.configDirectory, '/portable');
    });

    test('--listen splits into host and port', () {
      final config = resolveDaemonConfig(
        defaults: defaults,
        listen: '0.0.0.0:9000',
      );

      expect(config.host, '0.0.0.0');
      expect(config.port, 9000);
    });

    test('an IPv6 host keeps every colon but the last', () {
      final config = resolveDaemonConfig(
        defaults: defaults,
        listen: '::1:8080',
      );

      expect(config.host, '::1');
      expect(config.port, 8080);
    });

    test('a malformed --listen is a usage error, not a crash', () {
      expect(
        () => resolveDaemonConfig(defaults: defaults, listen: 'nonsense'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => resolveDaemonConfig(defaults: defaults, listen: '127.0.0.1:http'),
        throwsA(isA<FormatException>()),
      );
    });

    test('an empty origin list keeps the shipped allowlist', () {
      final config = resolveDaemonConfig(defaults: defaults);

      expect(config.allowedOrigins, defaultAllowedOrigins);
    });

    test('explicit origins replace the allowlist', () {
      final config = resolveDaemonConfig(
        defaults: defaults,
        allowedOrigins: const <String>[
          'https://tinest.tinyrack.net',
          'http://localhost:8080',
        ],
      );

      expect(config.allowedOrigins, <String>{
        'https://tinest.tinyrack.net',
        'http://localhost:8080',
      });
    });

    test('--token is carried into the config', () {
      final config = resolveDaemonConfig(defaults: defaults, token: 'a' * 32);

      expect(config.bearerToken, 'a' * 32);
    });
  });

  group('runDaemonHost', () {
    test('announces the bound endpoint and stops on shutdown', () async {
      final handle = _FakeHandle();
      final output = StringBuffer();
      final shutdown = Completer<void>();

      final result = runDaemonHost(
        config: defaults,
        output: output,
        shutdown: shutdown.future,
        printToken: false,
        start: (_) async => handle,
      );

      await pumpEventQueue();
      expect(handle.stopped, isFalse);
      shutdown.complete();

      expect(await result, 0);
      expect(handle.stopped, isTrue);
      expect(output.toString(), contains('http://127.0.0.1:7337'));
    });

    test('prints a generated token but never a supplied one', () async {
      final printed = StringBuffer();
      await runDaemonHost(
        config: defaults,
        output: printed,
        shutdown: Future<void>.value(),
        printToken: true,
        start: (_) async => _FakeHandle(),
      );
      expect(printed.toString(), contains('generated-token'));

      final quiet = StringBuffer();
      await runDaemonHost(
        config: defaults,
        output: quiet,
        shutdown: Future<void>.value(),
        printToken: false,
        start: (_) async => _FakeHandle(),
      );
      expect(quiet.toString(), isNot(contains('generated-token')));
    });

    test('stops the daemon even when shutdown fails', () async {
      final handle = _FakeHandle();
      // Completed after the host is listening, so the error never sits on an
      // unobserved future while the daemon is still starting.
      final shutdown = Completer<void>();

      final result = runDaemonHost(
        config: defaults,
        output: StringBuffer(),
        shutdown: shutdown.future,
        printToken: false,
        start: (_) async => handle,
      );
      await pumpEventQueue();
      shutdown.completeError(StateError('interrupted'));

      await expectLater(result, throwsA(isA<StateError>()));
      expect(handle.stopped, isTrue);
    });

    test('the config reaches the starter unchanged', () async {
      DaemonConfig? seen;

      await runDaemonHost(
        config: resolveDaemonConfig(defaults: defaults, listen: '0.0.0.0:9100'),
        output: StringBuffer(),
        shutdown: Future<void>.value(),
        printToken: false,
        start: (config) async {
          seen = config;
          return _FakeHandle();
        },
      );

      expect(seen?.host, '0.0.0.0');
      expect(seen?.port, 9100);
    });
  });
}

final class _FakeHandle implements DaemonHandle {
  bool stopped = false;

  @override
  Uri get boundEndpoint => Uri.parse('http://127.0.0.1:7337');

  @override
  String get serverId => 'server';

  @override
  String get bearerToken => 'generated-token';

  @override
  Future<void> get ready async {}

  @override
  Future<void> stop() async {
    stopped = true;
  }
}
