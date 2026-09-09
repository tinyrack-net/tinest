@Tags(<String>['feature_test__daemon_management__verticalSlice'])
library;

import 'dart:async';
import 'dart:io';

import 'package:cli/cli.dart';
import 'package:client/local_daemon.dart';
import 'package:daemon/daemon.dart';
import 'package:test/test.dart';

import 'helpers/capture_stream.dart';

/// A token the daemon accepts, which requires at least 32 bytes.
const String _token = 'test-token-0123456789abcdef0123456789';

void main() {
  test(
    'daemon start serves a client that the same binary then drives',
    () async {
      final home = await Directory.systemTemp.createTemp('tinest-cli-daemon-');
      addTearDown(() => home.delete(recursive: true));

      // Port 0 lets the operating system pick a free port, so a parallel test
      // run never collides on a fixed one.
      final config = resolveDaemonConfig(
        defaults: DaemonConfig(
          homeDirectory: home.path,
          osHomeDirectory: home.path,
          useEnvironmentCredentials: false,
        ),
        listen: '127.0.0.1:0',
        token: _token,
      );

      DaemonHandle? started;
      final shutdown = Completer<void>();
      final daemonOutput = StringBuffer();
      final host = runDaemonHost(
        config: config,
        output: daemonOutput,
        shutdown: shutdown.future,
        printToken: false,
        start: (value) async => started = await DaemonApplication.start(value),
      );
      addTearDown(() async {
        if (!shutdown.isCompleted) shutdown.complete();
        await host;
      });

      // Wait for the announcement rather than a fixed delay, so the test is
      // not racing the daemon's bind.
      while (daemonOutput.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(daemonOutput.toString(), contains('listening on'));

      final endpoint = started!.boundEndpoint;
      expect(endpoint.port, isNot(0));

      final out = CaptureStream();
      final err = CaptureStream();
      final code = await runCli(
        <String>[
          'provider',
          'list',
          '--listen',
          '127.0.0.1:${endpoint.port}',
          '--token',
          _token,
        ],
        stdout: out,
        stderr: err,
        environment: const <String, String>{},
        directories: LocalDaemonDirectories(
          configDirectory: home.path,
          stateDirectory: home.path,
          userHomeDirectory: home.path,
          osHomeDirectory: home.path,
        ),
      );

      expect(err.text, isEmpty);
      expect(code, 0);
      expect(out.text, contains('No provider connections.'));

      shutdown.complete();
      expect(await host, 0);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('a client rejects a daemon it cannot authenticate against', () async {
    final home = await Directory.systemTemp.createTemp('tinest-cli-daemon-');
    addTearDown(() => home.delete(recursive: true));

    final handle = await DaemonApplication.start(
      DaemonConfig(
        homeDirectory: home.path,
        osHomeDirectory: home.path,
        port: 0,
        bearerToken: _token,
        useEnvironmentCredentials: false,
      ),
    );
    addTearDown(handle.stop);

    final err = CaptureStream();
    final code = await runCli(
      <String>[
        'provider',
        'list',
        '--listen',
        '127.0.0.1:${handle.boundEndpoint.port}',
        '--token',
        'wrong-token-0123456789abcdef01234567',
      ],
      stdout: CaptureStream(),
      stderr: err,
      environment: const <String, String>{},
      directories: LocalDaemonDirectories(
        configDirectory: home.path,
        stateDirectory: home.path,
        userHomeDirectory: home.path,
        osHomeDirectory: home.path,
      ),
    );

    expect(code, isNot(0));
    expect(err.text, isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
