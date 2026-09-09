import 'dart:io';

import 'package:app/desktop.dart';
import 'package:daemon/daemon.dart';
import 'package:desktop_app/main.dart' as desktop_entry;
import 'package:desktop_app/src/embedded_daemon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const config = DaemonConfig(
    homeDirectory: '/test-home',
    port: 0,
    bearerToken: 'launcher-token-0123456789abcdef012345',
    useEnvironmentCredentials: false,
  );

  test('launcher maps config and exposes the daemon session', () async {
    final handle = _DaemonHandle();
    DaemonConfig? startedConfig;
    final launcher = IsolateEmbeddedDaemonLauncher(
      resolveConfig: () => config,
      startDaemon: (value) async {
        startedConfig = value;
        return handle;
      },
    );

    final session = await launcher.start(
      exposure: EmbeddedDaemonExposure.allInterfaces,
      port: 8123,
    );

    expect(startedConfig?.host, '0.0.0.0');
    expect(startedConfig?.port, 8123);
    expect(session.endpoint.websocketUri, handle.boundEndpoint);
    expect(session.serverId, handle.serverId);
    expect(session.credentials.bearerToken, handle.bearerToken);
    await session.stop();
    expect(handle.stops, 1);
  });

  for (final failure
      in <(EmbeddedDaemonStartupFailureReason, HostFailureReason?)>[
        (
          EmbeddedDaemonStartupFailureReason.portInUse,
          HostFailureReason.embeddedPortInUse,
        ),
        (
          EmbeddedDaemonStartupFailureReason.alreadyRunning,
          HostFailureReason.embeddedAlreadyRunning,
        ),
        (EmbeddedDaemonStartupFailureReason.unknown, null),
      ]) {
    test('launcher maps ${failure.$1.name}', () async {
      final launcher = IsolateEmbeddedDaemonLauncher(
        resolveConfig: () => config,
        startDaemon: (_) => Future<DaemonHandle>.error(
          EmbeddedDaemonStartupException(
            'startup ${failure.$1.name}',
            reason: failure.$1,
          ),
        ),
      );

      await expectLater(
        launcher.start(exposure: EmbeddedDaemonExposure.loopback, port: 7337),
        throwsA(
          isA<HostConnectionFailure>()
              .having((error) => error.reason, 'reason', failure.$2)
              .having((error) => error.message, 'message', contains('startup')),
        ),
      );
    });
  }

  test('launcher converts unexpected exceptions to network failures', () async {
    final launcher = IsolateEmbeddedDaemonLauncher(
      resolveConfig: () => throw Exception('bad environment'),
    );

    await expectLater(
      launcher.start(exposure: EmbeddedDaemonExposure.loopback, port: 7337),
      throwsA(
        isA<HostConnectionFailure>().having(
          (error) => error.message,
          'message',
          contains('bad environment'),
        ),
      ),
    );
  });

  test('data eraser passes the resolved config to the resetter', () async {
    DaemonConfig? erasedConfig;
    final eraser = IsolateEmbeddedDaemonDataEraser(
      resolveConfig: () => config,
      eraseData: (value) async => erasedConfig = value,
    );

    await eraser.eraseAll();

    expect(erasedConfig, same(config));
  });

  for (final failure
      in <(DaemonDataResetFailureReason, FactoryResetFailureReason)>[
        (
          DaemonDataResetFailureReason.daemonRunning,
          FactoryResetFailureReason.daemonStillRunning,
        ),
        (
          DaemonDataResetFailureReason.filesystem,
          FactoryResetFailureReason.filesystem,
        ),
      ]) {
    test('data eraser maps ${failure.$1.name}', () async {
      final eraser = IsolateEmbeddedDaemonDataEraser(
        resolveConfig: () => config,
        eraseData: (_) => Future<void>.error(
          DaemonDataResetException(
            'reset ${failure.$1.name}',
            reason: failure.$1,
          ),
        ),
      );

      await expectLater(
        eraser.eraseAll(),
        throwsA(
          isA<FactoryResetFailure>()
              .having((error) => error.reason, 'reason', failure.$2)
              .having((error) => error.message, 'message', contains('reset')),
        ),
      );
    });
  }

  test('adapter pair resolves its config once', () async {
    var resolutions = 0;
    final adapters = EmbeddedDaemonAdapters(
      resolveConfig: () {
        resolutions += 1;
        return config;
      },
    );

    expect(adapters.launcher, isA<IsolateEmbeddedDaemonLauncher>());
    expect(adapters.dataEraser, isA<IsolateEmbeddedDaemonDataEraser>());
    final launcher = adapters.launcher as IsolateEmbeddedDaemonLauncher;
    final eraser = adapters.dataEraser as IsolateEmbeddedDaemonDataEraser;
    launcher.resolveConfig();
    eraser.resolveConfig();
    expect(resolutions, 1);
  });

  test('production services expose the embedded daemon capability', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final services = await desktop_entry.createProductionDesktopServices();

    expect(services.supportsEmbeddedDaemon, isTrue);
    expect(services.erasesEmbeddedDaemonData, isTrue);
    expect(services.clientKind, 'desktop');
  });

  test('production entrypoint forwards arguments and its bootstrap', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    List<String>? forwarded;
    Future<AppServices> Function()? bootstrap;

    await desktop_entry.runProductionDesktopApp(
      arguments: const <String>['--started-at-login'],
      runner: ({required arguments, required bootstrapServices}) async {
        forwarded = arguments;
        bootstrap = bootstrapServices;
      },
    );

    expect(forwarded, const <String>['--started-at-login']);
    expect((await bootstrap!()).supportsEmbeddedDaemon, isTrue);
  });

  test(
    'default launcher starts and stops a real embedded daemon',
    () async {
      final home = await Directory.systemTemp.createTemp(
        'desktop-daemon-test-',
      );
      addTearDown(() => home.delete(recursive: true));
      final launcher = IsolateEmbeddedDaemonLauncher(
        resolveConfig: () => DaemonConfig(
          homeDirectory: home.path,
          port: 0,
          bearerToken: 'real-launcher-token-0123456789abcdef',
          useEnvironmentCredentials: false,
        ),
      );

      final session = await launcher.start(
        exposure: EmbeddedDaemonExposure.loopback,
        port: 0,
      );
      expect(session.serverId, isNotEmpty);
      await session.stop();
    },
    tags: const <String>[
      'feature_test__daemon_exposure__verticalSlice',
      'feature_test__daemon_exposure__platformSmoke',
    ],
  );

  test('default data resetter erases daemon state', () async {
    final home = await Directory.systemTemp.createTemp('desktop-reset-test-');
    addTearDown(() {
      if (home.existsSync()) home.deleteSync(recursive: true);
    });
    final eraser = IsolateEmbeddedDaemonDataEraser(
      resolveConfig: () => DaemonConfig(homeDirectory: home.path),
    );

    await eraser.eraseAll();
  });
}

final class _DaemonHandle implements DaemonHandle {
  int stops = 0;

  @override
  String get bearerToken => 'launcher-token-0123456789abcdef012345';

  @override
  Uri get boundEndpoint => Uri.parse('ws://127.0.0.1:4321/ws');

  @override
  Future<void> get ready async {}

  @override
  String get serverId => 'launcher-server';

  @override
  Future<void> stop() async => stops += 1;
}
