@Tags(<String>['feature_test__daemon_authentication__unit'])
library;

import 'dart:async';
import 'dart:io';

import 'package:cli/cli.dart';
import 'package:client/local_daemon.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'helpers/capture_stream.dart';

void main() {
  late CaptureStream out;
  late CaptureStream err;

  setUp(() {
    out = CaptureStream();
    err = CaptureStream();
  });

  const directories = LocalDaemonDirectories(
    configDirectory: '/config',
    stateDirectory: '/state',
    userHomeDirectory: '/home/test',
    osHomeDirectory: '/home/test',
  );

  Future<int> run(
    List<String> inputs, {
    DaemonClientFactory? connectClient,
    Map<String, String> environment = const <String, String>{},
  }) {
    return runCli(
      inputs,
      stdout: out,
      stderr: err,
      environment: environment,
      directories: directories,
      connectClient:
          connectClient ??
          ({
            required host,
            required port,
            required bearerToken,
            required clientId,
          }) async => fail('the CLI must not connect for this input'),
      readSecret: () async => fail('the CLI must not prompt for this input'),
      readFile: (_) async => fail('the CLI must not read files for this input'),
    );
  }

  test('--version prints the package version without connecting', () async {
    expect(await run(<String>['--version']), 0);
    expect(out.text.trim(), packageVersion);
  });

  test('help lists every top-level route and hides the internal one', () async {
    expect(await run(<String>['--help']), 0);

    expect(out.text, contains('daemon'));
    expect(out.text, contains('provider'));
    expect(out.text, contains('agent'));
    expect(out.text, contains('plugin'));
    expect(out.text, contains('completion'));
    expect(out.text, isNot(contains('__complete')));
  });

  test('plugin help lists the authoring lifecycle commands', () async {
    expect(await run(<String>['plugin', '--help']), 0);

    expect(out.text, contains('init'));
    expect(out.text, contains('validate'));
    expect(out.text, contains('reload'));
  });

  test('a route map without a command prints its own commands', () async {
    expect(await run(<String>['provider', '--help']), 0);

    expect(out.text, contains('list'));
    expect(out.text, contains('connect'));
    expect(out.text, contains('disconnect'));
    expect(out.text, contains('catalog-refresh'));
  });

  test('an unknown command is rejected without connecting', () async {
    expect(await run(<String>['provider', 'nope']), isNot(0));
    expect(err.text, isNotEmpty);
  });

  test('a missing token reports the config directory and exits 69', () async {
    expect(await run(<String>['provider', 'list']), 69);

    expect(err.text, contains('/config'));
    expect(err.text, contains('--token'));
  });

  test('--home overrides the directory searched for a token', () async {
    expect(await run(<String>['provider', 'list', '--home', '/elsewhere']), 69);

    expect(err.text, contains('/elsewhere'));
    expect(err.text, isNot(contains('/config')));
  });

  test('a malformed --listen is a usage error', () async {
    expect(
      await run(<String>[
        'provider',
        'list',
        '--listen',
        'nonsense',
        '--token',
        'secret',
      ]),
      64,
    );
    expect(err.text, contains('host:port'));
  });

  test('an unreachable daemon exits 69 rather than crashing', () async {
    final code = await run(
      <String>['provider', 'list', '--token', 'secret'],
      connectClient: ({
        required host,
        required port,
        required bearerToken,
        required clientId,
      }) async => throw const SocketException('connection refused'),
    );

    expect(code, 69);
    expect(err.text, contains('Cannot connect to the daemon'));
  });

  test('a wrapped socket failure is reported the same way', () async {
    final code = await run(
      <String>['agent', 'list', '--token', 'secret'],
      connectClient: ({
        required host,
        required port,
        required bearerToken,
        required clientId,
      }) async => throw WebSocketChannelException('handshake failed'),
    );

    expect(code, 69);
    expect(err.text, contains('Cannot connect to the daemon'));
  });

  test('flags bind after the subcommand and reach the connection', () async {
    var seenHost = '';
    var seenPort = 0;
    var seenToken = '';

    await run(
      <String>[
        'provider',
        'list',
        '--listen',
        'example.test:9001',
        '--token',
        'from-flag',
      ],
      connectClient:
          ({
            required host,
            required port,
            required bearerToken,
            required clientId,
          }) async {
            seenHost = host;
            seenPort = port;
            seenToken = bearerToken;
            throw const SocketException('stop here');
          },
    );

    expect(seenHost, 'example.test');
    expect(seenPort, 9001);
    expect(seenToken, 'from-flag');
  });

  test('the environment supplies the address and token', () async {
    var seenPort = 0;
    var seenToken = '';

    await run(
      <String>['provider', 'list'],
      environment: const <String, String>{
        'TINYRACK_TINEST_LISTEN': '127.0.0.1:9100',
        'TINYRACK_TINEST_TOKEN': 'from-environment',
      },
      connectClient:
          ({
            required host,
            required port,
            required bearerToken,
            required clientId,
          }) async {
            seenPort = port;
            seenToken = bearerToken;
            throw const SocketException('stop here');
          },
    );

    expect(seenPort, 9100);
    expect(seenToken, 'from-environment');
  });

  test('a flag beats the environment', () async {
    var seenToken = '';

    await run(
      <String>['agent', 'list', '--token', 'from-flag'],
      environment: const <String, String>{
        'TINYRACK_TINEST_TOKEN': 'from-environment',
      },
      connectClient:
          ({
            required host,
            required port,
            required bearerToken,
            required clientId,
          }) async {
            seenToken = bearerToken;
            throw const SocketException('stop here');
          },
    );

    expect(seenToken, 'from-flag');
  });

  test('a daemon on every interface is reached over loopback', () async {
    var seenHost = '';

    await run(
      <String>['provider', 'list', '--listen', '0.0.0.0:7337', '--token', 'x'],
      connectClient:
          ({
            required host,
            required port,
            required bearerToken,
            required clientId,
          }) async {
            seenHost = host;
            throw const SocketException('stop here');
          },
    );

    expect(seenHost, '127.0.0.1');
  });

  test('exit codes cover every documented failure kind', () {
    expect(resolveExitCode(const FormatException('bad')), usageExitCode);
    expect(resolveExitCode(const SocketException('down')), unavailableExitCode);
    expect(
      resolveExitCode(WebSocketChannelException('down')),
      unavailableExitCode,
    );
    expect(
      resolveExitCode(const DaemonConnectionException('no token')),
      unavailableExitCode,
    );
    expect(resolveExitCode(StateError('other')), 1);
  });

  test('a connection failure message names the cause', () {
    expect(
      const DaemonConnectionException('missing token').toString(),
      'missing token',
    );
  });
}
