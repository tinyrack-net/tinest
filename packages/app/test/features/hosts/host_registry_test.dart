import 'dart:async';

import 'package:app/src/features/hosts/application/host_path_policy.dart';
import 'package:app/src/features/hosts/application/host_registry.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/hosts/domain/host_ports.dart';
import 'package:client/client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';

import '../../support/fake_tinest_api.dart';

void main() {
  final now = DateTime.utc(2026, 8, 3);

  test('loads without awaiting daemon connections and connects hosts '
      'independently', () async {
    final first = RemoteDaemonProfile(
      id: 'first',
      label: 'First',
      connections: directHostConnections(Uri.parse('ws://first.test/ws')),
      autoConnect: true,
      createdAt: now,
      updatedAt: now,
    );
    final second = RemoteDaemonProfile(
      id: 'second',
      label: 'Second',
      connections: directHostConnections(Uri.parse('wss://second.test/ws')),
      autoConnect: true,
      createdAt: now,
      updatedAt: now,
    );
    final store = MemoryAppStore(
      settings: const AppSettings(embeddedDaemonEnabled: false),
      profiles: <RemoteDaemonProfile>[first, second],
      tokens: const <String, String>{'first': 'one', 'second': 'two'},
    );
    final firstConnect = Completer<TinestApi>();
    final secondApi = FakeTinestApi(serverInfo: _serverInfo('server-two'));
    final factory = _ClientFactory(<String, Future<TinestApi>>{
      'first.test': firstConnect.future,
      'second.test': Future<TinestApi>.value(secondApi),
    });
    final registry = HostRegistry(
      store: store,
      clientFactory: factory,
      ids: const _Ids(),
      clock: _Clock(now),
      delay: const _NoDelay(),
      clientKind: 'test',
    );
    addTearDown(registry.close);

    final loaded = await registry.load();
    expect(loaded.runtimes.keys, containsAll(<String>['first', 'second']));
    expect(loaded.runtimes['first']!.status, HostRuntimeStatus.connecting);
    await _flush();
    expect(registry.value.runtimes['second']!.status, HostRuntimeStatus.online);
    expect(
      registry.value.runtimes['first']!.status,
      HostRuntimeStatus.connecting,
    );

    firstConnect.complete(FakeTinestApi(serverInfo: _serverInfo('server-one')));
    await _flush();
    expect(registry.value.runtimes['first']!.status, HostRuntimeStatus.online);
    expect(
      factory.connectedHosts,
      containsAll(<String>['first.test', 'second.test']),
    );
  }, tags: const <String>['feature_test__daemon_management__unit']);

  test(
    'offline profiles save before connection and disabled hosts remain idle',
    () async {
      final store = MemoryAppStore(
        settings: const AppSettings(embeddedDaemonEnabled: false),
      );
      final factory = _ClientFactory(const <String, Future<TinestApi>>{});
      final registry = HostRegistry(
        store: store,
        clientFactory: factory,
        ids: const _Ids(),
        clock: _Clock(now),
        delay: const _NoDelay(),
        clientKind: 'test',
      );
      addTearDown(registry.close);
      await registry.load();

      final profile = await registry.addRemote(
        label: 'Offline',
        address: 'wss://offline.test/ws',
        bearerToken: 'secret',
        autoConnect: false,
      );

      expect(profile.id, 'generated-id');
      expect(store.profiles.single, profile);
      expect(store.tokens[profile.connections.single.credentialKey], 'secret');
      expect(
        registry.value.runtimes[profile.id]!.status,
        HostRuntimeStatus.idle,
      );
      expect(factory.connectedHosts, isEmpty);
    },
  );

  test(
    'embedded daemon is optional and remote selection never stops it',
    () async {
      final store = MemoryAppStore();
      final embeddedApi = FakeTinestApi(
        serverInfo: _serverInfo('embedded-server'),
      );
      final launcher = _EmbeddedLauncher();
      final registry = HostRegistry(
        store: store,
        clientFactory: _ClientFactory(<String, Future<TinestApi>>{
          'embedded.test': Future<TinestApi>.value(embeddedApi),
        }),
        embeddedLauncher: launcher,
        ids: const _Ids(),
        clock: _Clock(now),
        delay: const _NoDelay(),
        clientKind: 'desktop',
      );
      addTearDown(registry.close);

      await registry.load();
      await _flush();
      expect(launcher.starts, 1);
      expect(
        registry.value.runtimes[embeddedHostId]!.status,
        HostRuntimeStatus.online,
      );

      await registry.selectHost('missing-remote');
      expect(launcher.session.stops, 0);
      await registry.setEmbeddedDaemonEnabled(enabled: false);
      expect(launcher.session.stops, 1);
      expect(registry.value.runtimes, isNot(contains(embeddedHostId)));
    },
  );

  test(
    'reset stops every host before erasing and restarts with defaults',
    () async {
      final profile = RemoteDaemonProfile(
        id: 'remote',
        label: 'Remote',
        connections: directHostConnections(Uri.parse('ws://remote.test/ws')),
        autoConnect: true,
        createdAt: now,
        updatedAt: now,
      );
      final store = MemoryAppStore(
        settings: const AppSettings(
          embeddedDaemonPort: 9100,
          lastActiveHostId: 'remote',
          localeTag: 'ko',
          sidebarCollapsed: true,
          themeMode: AppThemeMode.dark,
        ),
        profiles: <RemoteDaemonProfile>[profile],
        tokens: const <String, String>{'remote': 'token'},
      );
      final calls = <String>[];
      final launcher = _EmbeddedLauncher(calls: calls);
      final eraser = _DataEraser(calls: calls);
      final registry = HostRegistry(
        store: store,
        clientFactory: _ClientFactory(<String, Future<TinestApi>>{
          'embedded.test': Future<TinestApi>.value(
            FakeTinestApi(serverInfo: _serverInfo('embedded-server')),
          ),
          'remote.test': Future<TinestApi>.value(
            FakeTinestApi(serverInfo: _serverInfo('remote-server')),
          ),
        }),
        embeddedLauncher: launcher,
        embeddedDataEraser: eraser,
        ids: const _Ids(),
        clock: _Clock(now),
        delay: const _NoDelay(),
        clientKind: 'desktop',
      );
      addTearDown(registry.close);

      await registry.load();
      await _flush();
      expect(launcher.starts, 1);
      calls.clear();

      await registry.resetToFactoryDefaults();
      await _flush();

      expect(calls, <String>['stop', 'erase', 'start']);
      expect(eraser.erases, 1);
      expect(store.tokens, isEmpty);
      expect(store.profiles, isEmpty);
      expect(registry.value.profiles, isEmpty);
      expect(registry.value.settings.localeTag, isNull);
      expect(registry.value.settings.themeMode, AppThemeMode.system);
      expect(registry.value.settings.lastActiveHostId, isNull);
      expect(registry.value.settings.sidebarCollapsed, isFalse);
      expect(registry.value.settings.embeddedDaemonEnabled, isTrue);
      expect(
        registry.value.settings.embeddedDaemonPort,
        defaultEmbeddedDaemonPort,
      );
      expect(registry.value.runtimes.keys, <String>[embeddedHostId]);
      expect(
        registry.value.runtimes[embeddedHostId]!.status,
        HostRuntimeStatus.online,
      );
      expect(launcher.ports.last, defaultEmbeddedDaemonPort);
    },
    tags: const <String>['feature_test__settings_reset__unit'],
  );

  // Characterization of what makes `changes` safe to deliver synchronously.
  //
  // The controller bridging this stream assigns provider state straight from
  // the listener, so an emit that lands on a caller's stack becomes a provider
  // write on that stack. That is only harmless because no mutator emits before
  // its first `await`: every settings mutator persists first, which yields, so
  // the emit can never reach a caller that is mid-build. This pins that
  // invariant — a mutator that starts emitting eagerly fails here rather than
  // in whichever screen happens to call it during a build.
  test('no settings mutator emits before it first yields', () async {
    final store = MemoryAppStore(
      settings: const AppSettings(embeddedDaemonEnabled: false),
    );
    final registry = HostRegistry(
      store: store,
      clientFactory: _ClientFactory(const <String, Future<TinestApi>>{}),
      ids: const _Ids(),
      clock: _Clock(now),
      delay: const _NoDelay(),
      clientKind: 'test',
    );
    addTearDown(registry.close);
    await registry.load();
    await _flush();

    final emitted = <String>[];
    final subscription = registry.changes.listen((_) => emitted.add('emit'));
    addTearDown(subscription.cancel);

    final mutations = <String, Future<void> Function()>{
      'selectHost': () => registry.selectHost('embedded'),
      'setThemeMode': () => registry.setThemeMode(AppThemeMode.dark),
      'setSidebarCollapsed': () =>
          registry.setSidebarCollapsed(collapsed: true),
      'setLocaleTag': () => registry.setLocaleTag('ko'),
      'setStartAtBoot': () => registry.setStartAtBoot(enabled: true),
    };
    for (final entry in mutations.entries) {
      emitted.clear();
      final pending = entry.value();
      expect(emitted, isEmpty, reason: '${entry.key} emitted synchronously');
      await pending;
      await _flush();
    }
  });

  test('reset restarts on the store factory defaults it is given', () async {
    final store = MemoryAppStore(
      settings: const AppSettings(embeddedDaemonPort: 9100),
      factoryDefaults: const AppSettings(embeddedDaemonPort: 9200),
    );
    final calls = <String>[];
    final launcher = _EmbeddedLauncher(calls: calls);
    final registry = HostRegistry(
      store: store,
      clientFactory: _ClientFactory(<String, Future<TinestApi>>{
        'embedded.test': Future<TinestApi>.value(
          FakeTinestApi(serverInfo: _serverInfo('embedded-server')),
        ),
      }),
      embeddedLauncher: launcher,
      embeddedDataEraser: _DataEraser(calls: calls),
      ids: const _Ids(),
      clock: _Clock(now),
      delay: const _NoDelay(),
      clientKind: 'desktop',
    );
    addTearDown(registry.close);

    await registry.load();
    await _flush();
    await registry.resetToFactoryDefaults();
    await _flush();

    expect(store.settings.embeddedDaemonPort, 9200);
    expect(launcher.ports, <int>[9100, 9200]);
  });

  test(
    'a failed erase keeps every stored value and restarts the daemon',
    () async {
      final profile = RemoteDaemonProfile(
        id: 'remote',
        label: 'Remote',
        connections: directHostConnections(Uri.parse('ws://remote.test/ws')),
        autoConnect: false,
        createdAt: now,
        updatedAt: now,
      );
      const settings = AppSettings(embeddedDaemonPort: 9100);
      final store = MemoryAppStore(
        settings: settings,
        profiles: <RemoteDaemonProfile>[profile],
        tokens: const <String, String>{'remote': 'token'},
      );
      final calls = <String>[];
      final launcher = _EmbeddedLauncher(calls: calls);
      final eraser = _DataEraser(
        calls: calls,
        failure: const FactoryResetFailure(
          'locked',
          reason: FactoryResetFailureReason.daemonStillRunning,
        ),
      );
      final registry = HostRegistry(
        store: store,
        clientFactory: _ClientFactory(<String, Future<TinestApi>>{
          'embedded.test': Future<TinestApi>.value(
            FakeTinestApi(serverInfo: _serverInfo('embedded-server')),
          ),
        }),
        embeddedLauncher: launcher,
        embeddedDataEraser: eraser,
        ids: const _Ids(),
        clock: _Clock(now),
        delay: const _NoDelay(),
        clientKind: 'desktop',
      );
      addTearDown(registry.close);

      await registry.load();
      await _flush();
      calls.clear();

      await expectLater(
        registry.resetToFactoryDefaults(),
        throwsA(
          isA<FactoryResetFailure>().having(
            (error) => error.reason,
            'reason',
            FactoryResetFailureReason.daemonStillRunning,
          ),
        ),
      );
      await _flush();

      expect(calls, <String>['stop', 'erase', 'start']);
      expect(store.settings.embeddedDaemonPort, 9100);
      expect(identical(store.settings, settings), isTrue);
      expect(store.profiles, <RemoteDaemonProfile>[profile]);
      expect(store.tokens, const <String, String>{'remote': 'token'});
      expect(registry.value.settings.embeddedDaemonPort, 9100);
      expect(launcher.ports.last, 9100);
      expect(
        registry.value.runtimes[embeddedHostId]!.status,
        HostRuntimeStatus.online,
      );
    },
    tags: const <String>['feature_test__settings_reset__unit'],
  );

  test('a second concurrent reset is rejected without erasing twice', () async {
    final store = MemoryAppStore();
    final calls = <String>[];
    final eraser = _DataEraser(calls: calls);
    final registry = HostRegistry(
      store: store,
      clientFactory: _ClientFactory(const <String, Future<TinestApi>>{}),
      embeddedLauncher: _EmbeddedLauncher(calls: calls),
      embeddedDataEraser: eraser,
      ids: const _Ids(),
      clock: _Clock(now),
      delay: const _NoDelay(),
      clientKind: 'desktop',
    );
    addTearDown(registry.close);

    await registry.load();
    await _flush();

    final first = registry.resetToFactoryDefaults();
    await expectLater(
      registry.resetToFactoryDefaults(),
      throwsA(
        isA<FactoryResetFailure>().having(
          (error) => error.reason,
          'reason',
          FactoryResetFailureReason.incomplete,
        ),
      ),
    );
    await first;

    expect(eraser.erases, 1);
  }, tags: const <String>['feature_test__settings_reset__unit']);

  test(
    'a surface without an embedded daemon still clears device-local data',
    () async {
      final profile = RemoteDaemonProfile(
        id: 'remote',
        label: 'Remote',
        connections: directHostConnections(Uri.parse('ws://remote.test/ws')),
        autoConnect: false,
        createdAt: now,
        updatedAt: now,
      );
      final store = MemoryAppStore(
        settings: const AppSettings(embeddedDaemonEnabled: false),
        profiles: <RemoteDaemonProfile>[profile],
        tokens: const <String, String>{'remote': 'token'},
      );
      final registry = HostRegistry(
        store: store,
        clientFactory: _ClientFactory(const <String, Future<TinestApi>>{}),
        ids: const _Ids(),
        clock: _Clock(now),
        delay: const _NoDelay(),
        clientKind: 'mobile',
      );
      addTearDown(registry.close);

      await registry.load();
      await registry.resetToFactoryDefaults();

      expect(store.profiles, isEmpty);
      expect(store.tokens, isEmpty);
      expect(registry.value.profiles, isEmpty);
      expect(registry.value.runtimes, isEmpty);
      expect(registry.value.settings.embeddedDaemonEnabled, isTrue);
      expect(
        registry.value.settings.embeddedDaemonPort,
        defaultEmbeddedDaemonPort,
      );
    },
    tags: const <String>['feature_test__settings_reset__unit'],
  );

  test('duplicate server identity becomes an explicit conflict', () async {
    final profiles = <RemoteDaemonProfile>[
      for (final id in <String>['first', 'second'])
        RemoteDaemonProfile(
          id: id,
          label: id,
          connections: directHostConnections(Uri.parse('ws://$id.test/ws')),
          autoConnect: true,
          createdAt: now,
          updatedAt: now,
        ),
    ];
    final store = MemoryAppStore(
      settings: const AppSettings(embeddedDaemonEnabled: false),
      profiles: profiles,
      tokens: const <String, String>{'first': 'one', 'second': 'two'},
    );
    final registry = HostRegistry(
      store: store,
      clientFactory: _ClientFactory(<String, Future<TinestApi>>{
        'first.test': Future<TinestApi>.value(
          FakeTinestApi(serverInfo: _serverInfo('same')),
        ),
        'second.test': Future<TinestApi>.value(
          FakeTinestApi(serverInfo: _serverInfo('same')),
        ),
      }),
      ids: const _Ids(),
      clock: _Clock(now),
      delay: const _NoDelay(),
      clientKind: 'test',
    );
    addTearDown(registry.close);

    await registry.load();
    await _flush();
    expect(
      registry.value.runtimes.values.where(
        (runtime) => runtime.status == HostRuntimeStatus.conflict,
      ),
      hasLength(1),
    );
  });

  test(
    'transient failures back off while permanent failures wait for retry',
    () async {
      final profile = RemoteDaemonProfile(
        id: 'remote',
        label: 'Remote',
        connections: directHostConnections(Uri.parse('wss://remote.test/ws')),
        autoConnect: true,
        createdAt: now,
        updatedAt: now,
      );
      final store = MemoryAppStore(
        settings: const AppSettings(embeddedDaemonEnabled: false),
        profiles: <RemoteDaemonProfile>[profile],
        tokens: const <String, String>{'remote': 'token'},
      );
      final api = FakeTinestApi(serverInfo: _serverInfo('remote-server'));
      final delay = _RecordingDelay();
      final factory = _SequenceClientFactory(<Future<TinestApi> Function()>[
        () => Future<TinestApi>.error(
          const HostConnectionFailure.network('temporary outage'),
        ),
        () => Future<TinestApi>.error(
          const HostConnectionFailure.authentication('bad token'),
        ),
        () => Future<TinestApi>.value(api),
      ]);
      final registry = HostRegistry(
        store: store,
        clientFactory: factory,
        ids: const _Ids(),
        clock: _Clock(now),
        delay: delay,
        clientKind: 'test',
      );
      addTearDown(registry.close);

      await registry.load();
      await _flush();
      expect(factory.attempts, 2);
      expect(delay.durations, <Duration>[const Duration(seconds: 1)]);
      expect(
        registry.value.runtimes['remote']!.status,
        HostRuntimeStatus.error,
      );

      await registry.reconnect('remote');
      expect(factory.attempts, 3);
      expect(
        registry.value.runtimes['remote']!.status,
        HostRuntimeStatus.online,
      );
    },
  );

  test(
    'editing and deleting one host cleans only its runtime and secret',
    () async {
      final profile = RemoteDaemonProfile(
        id: 'remote',
        label: 'Before',
        connections: directHostConnections(Uri.parse('wss://before.test/ws')),
        autoConnect: true,
        createdAt: now,
        updatedAt: now,
      );
      final store = MemoryAppStore(
        settings: const AppSettings(
          embeddedDaemonEnabled: false,
          lastActiveHostId: 'remote',
        ),
        profiles: <RemoteDaemonProfile>[profile],
        tokens: const <String, String>{'remote': 'old-token'},
      );
      final beforeApi = FakeTinestApi(serverInfo: _serverInfo('before'));
      final afterApi = FakeTinestApi(serverInfo: _serverInfo('before'));
      final registry = HostRegistry(
        store: store,
        clientFactory: _ClientFactory(<String, Future<TinestApi>>{
          'before.test': Future<TinestApi>.value(beforeApi),
          'after.test': Future<TinestApi>.value(afterApi),
        }),
        ids: const _Ids(),
        clock: _Clock(now),
        delay: const _NoDelay(),
        clientKind: 'test',
      );
      addTearDown(registry.close);
      await registry.load();
      await _flush();

      await registry.updateRemote(
        profileId: 'remote',
        label: 'After',
        address: 'wss://after.test/ws',
        autoConnect: true,
        replacementBearerToken: 'new-token',
      );
      await _flush();
      expect(beforeApi.isClosed, isTrue);
      expect(store.tokens['remote'], 'new-token');
      expect(registry.value.profiles.single.label, 'After');
      expect(registry.value.runtimes['remote']!.api, same(afterApi));

      await registry.removeRemote('remote');
      expect(afterApi.isClosed, isTrue);
      expect(store.profiles, isEmpty);
      expect(store.tokens, isEmpty);
      expect(store.settings.lastActiveHostId, isNull);
      expect(registry.value.runtimes, isNot(contains('remote')));
    },
  );

  test('rejects non-WebSocket endpoints before persisting a profile', () async {
    final store = MemoryAppStore(
      settings: const AppSettings(embeddedDaemonEnabled: false),
    );
    final registry = HostRegistry(
      store: store,
      clientFactory: _ClientFactory(const <String, Future<TinestApi>>{}),
      ids: const _Ids(),
      clock: _Clock(now),
      delay: const _NoDelay(),
      clientKind: 'test',
    );
    addTearDown(registry.close);
    await registry.load();

    expect(
      () => registry.addRemote(
        label: 'Invalid',
        address: 'https://daemon.example/ws',
        bearerToken: 'token',
        autoConnect: false,
      ),
      throwsA(
        isA<HostConnectionFailure>().having(
          (failure) => failure.kind,
          'kind',
          HostConnectionFailureKind.invalidEndpoint,
        ),
      ),
    );
    expect(store.profiles, isEmpty);
  });

  test(
    'validates credentials and rolls secrets back on profile failure',
    () async {
      final store = MemoryAppStore(
        settings: const AppSettings(embeddedDaemonEnabled: false),
      );
      final registry = HostRegistry(
        store: store,
        profiles: const _FailingProfiles(),
        credentials: store,
        clientFactory: _ClientFactory(const <String, Future<TinestApi>>{}),
        ids: const _Ids(),
        clock: _Clock(now),
        delay: const _NoDelay(),
        clientKind: 'test',
      );
      addTearDown(registry.close);
      await registry.load();
      expect(await registry.load(), same(registry.value));

      await expectLater(
        registry.addRemote(
          label: 'Missing token',
          address: 'wss://daemon.test/ws',
          bearerToken: '   ',
          autoConnect: false,
        ),
        throwsA(
          isA<HostConnectionFailure>().having(
            (failure) => failure.kind,
            'kind',
            HostConnectionFailureKind.authentication,
          ),
        ),
      );
      await expectLater(
        registry.addRemote(
          label: 'Failure',
          address: 'wss://daemon.test/ws',
          bearerToken: 'secret',
          autoConnect: false,
        ),
        throwsA(isA<_ProfileWriteFailure>()),
      );
      expect(store.tokens, isEmpty);
    },
  );

  test(
    'auto-connect toggles and missing secrets affect only that host',
    () async {
      final profile = RemoteDaemonProfile(
        id: 'remote',
        label: 'Remote',
        connections: directHostConnections(Uri.parse('wss://remote.test/ws')),
        autoConnect: false,
        createdAt: now,
        updatedAt: now,
      );
      final missing = RemoteDaemonProfile(
        id: 'missing',
        label: 'Missing',
        connections: directHostConnections(Uri.parse('wss://missing.test/ws')),
        autoConnect: true,
        createdAt: now,
        updatedAt: now,
      );
      final api = FakeTinestApi(serverInfo: _serverInfo('remote-server'));
      final store = MemoryAppStore(
        settings: const AppSettings(embeddedDaemonEnabled: false),
        profiles: <RemoteDaemonProfile>[profile, missing],
        tokens: const <String, String>{'remote': 'token'},
      );
      final registry = HostRegistry(
        store: store,
        clientFactory: _ClientFactory(<String, Future<TinestApi>>{
          'remote.test': Future<TinestApi>.value(api),
        }),
        ids: const _Ids(),
        clock: _Clock(now),
        delay: const _NoDelay(),
        clientKind: 'test',
      );
      addTearDown(registry.close);
      await registry.load();
      await _flush();
      expect(
        registry.value.runtimes['missing']!.status,
        HostRuntimeStatus.error,
      );

      await registry.setAutoConnect('remote', enabled: true);
      await _flush();
      expect(registry.value.runtimes['remote']!.connected, isTrue);
      api.emitState(ClientConnectionState.disconnected);
      expect(
        registry.value.runtimes['remote']!.status,
        HostRuntimeStatus.offline,
      );
      api.emitState(ClientConnectionState.connecting);
      expect(
        registry.value.runtimes['remote']!.status,
        HostRuntimeStatus.reconnecting,
      );
      api.emitState(ClientConnectionState.connected);
      expect(
        registry.value.runtimes['remote']!.status,
        HostRuntimeStatus.online,
      );

      await registry.setAutoConnect('remote', enabled: false);
      expect(registry.value.runtimes['remote']!.status, HostRuntimeStatus.idle);
      expect(api.isClosed, isTrue);
    },
  );

  test(
    'embedded reconnect, enable, failure, and unsupported paths are typed',
    () async {
      final store = MemoryAppStore();
      final launcher = _EmbeddedLauncher();
      final registry = HostRegistry(
        store: store,
        clientFactory: _ClientFactory(<String, Future<TinestApi>>{
          'embedded.test': Future<TinestApi>.value(
            FakeTinestApi(serverInfo: _serverInfo('embedded-server')),
          ),
        }),
        embeddedLauncher: launcher,
        ids: const _Ids(),
        clock: _Clock(now),
        delay: const _NoDelay(),
        clientKind: 'test',
      );
      addTearDown(registry.close);
      await registry.load();
      await _flush();

      await registry.reconnect(embeddedHostId);
      expect(launcher.starts, 2);
      await registry.setEmbeddedDaemonEnabled(enabled: false);
      await registry.setEmbeddedDaemonEnabled(enabled: true);
      expect(launcher.starts, 3);

      final remoteOnly = HostRegistry(
        store: MemoryAppStore(
          settings: const AppSettings(embeddedDaemonEnabled: false),
        ),
        clientFactory: _ClientFactory(const <String, Future<TinestApi>>{}),
        ids: const _Ids(),
        clock: _Clock(now),
        delay: const _NoDelay(),
        clientKind: 'test',
      );
      await remoteOnly.load();
      await remoteOnly.setEmbeddedDaemonEnabled(enabled: true);
      expect(remoteOnly.value.runtimes, isEmpty);
      await remoteOnly.close();
      await remoteOnly.close();

      final failingStore = MemoryAppStore();
      final failing = HostRegistry(
        store: failingStore,
        clientFactory: _ClientFactory(const <String, Future<TinestApi>>{}),
        embeddedLauncher: const _FailingEmbeddedLauncher(),
        ids: const _Ids(),
        clock: _Clock(now),
        delay: const _NoDelay(),
        clientKind: 'test',
      );
      addTearDown(failing.close);
      await failing.load();
      await _flush();
      expect(
        failing.value.runtimes[embeddedHostId]!.status,
        HostRuntimeStatus.error,
      );
    },
  );

  test(
    'embedded exposure restarts only the app-owned daemon and persists mode',
    () async {
      final remote = FakeTinestApi(serverInfo: _serverInfo('remote-server'));
      final embedded = FakeTinestApi(
        serverInfo: _serverInfo('embedded-server'),
      );
      final profile = RemoteDaemonProfile(
        id: 'remote',
        label: 'Remote',
        connections: directHostConnections(Uri.parse('wss://remote.test/ws')),
        autoConnect: true,
        createdAt: now,
        updatedAt: now,
      );
      final store = MemoryAppStore(
        profiles: <RemoteDaemonProfile>[profile],
        tokens: const <String, String>{'remote': 'token'},
      );
      final launcher = _EmbeddedLauncher();
      final registry = HostRegistry(
        store: store,
        clientFactory: _ClientFactory(<String, Future<TinestApi>>{
          'embedded.test': Future<TinestApi>.value(embedded),
          'remote.test': Future<TinestApi>.value(remote),
        }),
        embeddedLauncher: launcher,
        ids: const _Ids(),
        clock: _Clock(now),
        delay: const _NoDelay(),
        clientKind: 'test',
      );
      addTearDown(registry.close);

      await registry.load();
      await _flush();
      final firstSession = launcher.session;
      expect(launcher.exposures, <EmbeddedDaemonExposure>[
        EmbeddedDaemonExposure.loopback,
      ]);
      expect(launcher.ports, <int>[7337]);

      await registry.setEmbeddedDaemonExposure(
        EmbeddedDaemonExposure.allInterfaces,
      );

      expect(firstSession.stops, 1);
      expect(launcher.exposures, <EmbeddedDaemonExposure>[
        EmbeddedDaemonExposure.loopback,
        EmbeddedDaemonExposure.allInterfaces,
      ]);
      expect(launcher.ports, <int>[7337, 7337]);
      expect(
        store.settings.embeddedDaemonExposure,
        EmbeddedDaemonExposure.allInterfaces,
      );
      expect(
        registry.value.runtimes[embeddedHostId]?.status,
        HostRuntimeStatus.online,
      );
      expect(
        registry.value.runtimes['remote']?.status,
        HostRuntimeStatus.online,
      );
      expect(remote.isClosed, isFalse);

      await registry.setEmbeddedDaemonEnabled(enabled: false);
      final starts = launcher.starts;
      await registry.setEmbeddedDaemonExposure(EmbeddedDaemonExposure.loopback);
      expect(launcher.starts, starts);
      expect(
        store.settings.embeddedDaemonExposure,
        EmbeddedDaemonExposure.loopback,
      );
    },
    tags: const <String>['feature_test__daemon_exposure__unit'],
  );

  test(
    'embedded port is persisted and restarts only an enabled daemon',
    () async {
      final store = MemoryAppStore();
      final launcher = _EmbeddedLauncher();
      final registry = HostRegistry(
        store: store,
        clientFactory: _SequenceClientFactory(
          List<Future<TinestApi> Function()>.generate(
            2,
            (index) =>
                () async =>
                    FakeTinestApi(serverInfo: _serverInfo('embedded-server')),
          ),
        ),
        embeddedLauncher: launcher,
        ids: const _Ids(),
        clock: _Clock(now),
        delay: const _NoDelay(),
        clientKind: 'test',
      );
      addTearDown(registry.close);
      await registry.load();
      await _flush();

      final firstSession = launcher.session;
      await registry.setEmbeddedDaemonPort(8123);

      expect(firstSession.stops, 1);
      expect(store.settings.embeddedDaemonPort, 8123);
      expect(launcher.ports, <int>[7337, 8123]);
      expect(
        registry.value.runtimes[embeddedHostId]?.status,
        HostRuntimeStatus.online,
      );

      final startsAfterChange = launcher.starts;
      await registry.setEmbeddedDaemonPort(8123);
      expect(launcher.starts, startsAfterChange);
      await expectLater(
        registry.setEmbeddedDaemonPort(65536),
        throwsRangeError,
      );

      await registry.setEmbeddedDaemonEnabled(enabled: false);
      final starts = launcher.starts;
      await registry.setEmbeddedDaemonPort(8124);
      expect(launcher.starts, starts);
      expect(store.settings.embeddedDaemonPort, 8124);
    },
    tags: const <String>['feature_test__daemon_exposure__unit'],
  );

  test(
    'embedded exposure keeps failed mode and serializes rapid restarts',
    () async {
      final stopGate = Completer<void>();
      final launcher = _EmbeddedLauncher(
        firstStopGate: stopGate,
        failingStarts: const <int>{3},
      );
      final registry = HostRegistry(
        store: MemoryAppStore(),
        clientFactory: _SequenceClientFactory(
          List<Future<TinestApi> Function()>.generate(
            3,
            (index) =>
                () async =>
                    FakeTinestApi(serverInfo: _serverInfo('embedded-server')),
          ),
        ),
        embeddedLauncher: launcher,
        ids: const _Ids(),
        clock: _Clock(now),
        delay: const _NoDelay(),
        clientKind: 'test',
      );
      addTearDown(registry.close);
      await registry.load();
      await _flush();

      final toNetwork = registry.setEmbeddedDaemonExposure(
        EmbeddedDaemonExposure.allInterfaces,
      );
      await _flush();
      expect(launcher.session.stops, 1);
      final backToLoopback = registry.setEmbeddedDaemonExposure(
        EmbeddedDaemonExposure.loopback,
      );
      await _flush();
      expect(launcher.exposures, <EmbeddedDaemonExposure>[
        EmbeddedDaemonExposure.loopback,
      ]);

      stopGate.complete();
      await Future.wait(<Future<void>>[toNetwork, backToLoopback]);

      expect(launcher.exposures, <EmbeddedDaemonExposure>[
        EmbeddedDaemonExposure.loopback,
        EmbeddedDaemonExposure.allInterfaces,
        EmbeddedDaemonExposure.loopback,
      ]);
      expect(
        registry.value.settings.embeddedDaemonExposure,
        EmbeddedDaemonExposure.loopback,
      );
      expect(
        registry.value.runtimes[embeddedHostId]?.status,
        HostRuntimeStatus.error,
      );
      expect(
        registry.value.runtimes[embeddedHostId]?.error,
        contains('startup failed'),
      );
    },
    tags: const <String>['feature_test__daemon_exposure__unit'],
  );

  test(
    'protocol mismatch stops retry and closing drops a late connection',
    () async {
      final profile = RemoteDaemonProfile(
        id: 'remote',
        label: 'Remote',
        connections: directHostConnections(Uri.parse('wss://remote.test/ws')),
        autoConnect: true,
        createdAt: now,
        updatedAt: now,
      );
      final store = MemoryAppStore(
        settings: const AppSettings(embeddedDaemonEnabled: false),
        profiles: <RemoteDaemonProfile>[profile],
        tokens: const <String, String>{'remote': 'token'},
      );
      final mismatch = HostRegistry(
        store: store,
        clientFactory: _SequenceClientFactory(<Future<TinestApi> Function()>[
          () => Future<TinestApi>.error(
            const TinestClientException(
              'wrong version',
              code: 'protocol_mismatch',
            ),
          ),
        ]),
        ids: const _Ids(),
        clock: _Clock(now),
        delay: const _NoDelay(),
        clientKind: 'test',
      );
      await mismatch.load();
      await _flush();
      expect(mismatch.value.runtimes['remote']!.error, 'wrong version');
      await mismatch.close();

      final lateApi = FakeTinestApi(serverInfo: _serverInfo('late'));
      final pending = Completer<TinestApi>();
      final late = HostRegistry(
        store: store,
        clientFactory: _ClientFactory(<String, Future<TinestApi>>{
          'remote.test': pending.future,
        }),
        ids: const _Ids(),
        clock: _Clock(now),
        delay: const _NoDelay(),
        clientKind: 'test',
      );
      await late.load();
      await _flush();
      final closing = late.close();
      pending.complete(lateApi);
      await closing;
      await _flush();
      expect(lateApi.isClosed, isTrue);
    },
  );
  test(
    'an unreachable local-network daemon reports its own failure reason',
    () async {
      final profile = RemoteDaemonProfile(
        id: 'remote',
        label: 'Remote',
        connections: directHostConnections(Uri.parse('ws://127.0.0.1:7337/ws')),
        // Auto-connect would retry this retryable failure forever.
        autoConnect: false,
        createdAt: now,
        updatedAt: now,
      );
      final store = MemoryAppStore(
        settings: const AppSettings(embeddedDaemonEnabled: false),
        profiles: <RemoteDaemonProfile>[profile],
        tokens: const <String, String>{'remote': 'token'},
      );
      final registry = HostRegistry(
        store: store,
        clientFactory: _SequenceClientFactory(<Future<TinestApi> Function()>[
          () => Future<TinestApi>.error(
            const TinestClientException(
              'Could not reach a daemon at 127.0.0.1:7337.',
              code: localNetworkUnreachableCode,
              retryable: true,
            ),
          ),
        ]),
        ids: const _Ids(),
        clock: _Clock(now),
        delay: const _NoDelay(),
        clientKind: 'web',
      );
      addTearDown(registry.close);
      await registry.load();
      await registry.reconnect('remote');
      await _flush();

      final runtime = registry.value.runtimes['remote']!;
      expect(runtime.errorReason, HostFailureReason.localNetworkUnreachable);
      // The message is a fallback only; the UI localizes the reason instead.
      expect(runtime.error, 'Could not reach a daemon at 127.0.0.1:7337.');
    },
    tags: const <String>['feature_test__daemon_management__unit'],
  );

  test('sidebar collapse is persisted through the settings store', () async {
    final store = MemoryAppStore(
      settings: const AppSettings(embeddedDaemonEnabled: false),
    );
    final registry = HostRegistry(
      store: store,
      clientFactory: _ClientFactory(const <String, Future<TinestApi>>{}),
      ids: const _Ids(),
      clock: _Clock(now),
      delay: const _NoDelay(),
      clientKind: 'test',
    );
    addTearDown(registry.close);
    await registry.load();

    await registry.setSidebarCollapsed(collapsed: true);
    expect(store.settings.sidebarCollapsed, isTrue);
    expect(registry.value.settings.sidebarCollapsed, isTrue);

    await registry.setSidebarCollapsed(collapsed: false);
    expect(store.settings.sidebarCollapsed, isFalse);
  });

  test(
    'startup preferences are persisted through the settings store',
    () async {
      final store = MemoryAppStore(
        settings: const AppSettings(embeddedDaemonEnabled: false),
      );
      final registry = HostRegistry(
        store: store,
        clientFactory: _ClientFactory(const <String, Future<TinestApi>>{}),
        ids: const _Ids(),
        clock: _Clock(now),
        delay: const _NoDelay(),
        clientKind: 'test',
      );
      addTearDown(registry.close);
      await registry.load();

      // Both default to enabled, so the meaningful transition is turning
      // them off and back on again.
      await registry.setStartAtBoot(enabled: false);
      expect(store.settings.startAtBoot, isFalse);
      expect(registry.value.settings.startAtBoot, isFalse);
      expect(registry.value.settings.startMinimizedAtBoot, isTrue);

      await registry.setStartMinimizedAtBoot(enabled: false);
      expect(store.settings.startMinimizedAtBoot, isFalse);
      expect(registry.value.settings.startMinimizedAtBoot, isFalse);

      await registry.setStartAtBoot(enabled: true);
      expect(store.settings.startAtBoot, isTrue);
      expect(store.settings.startMinimizedAtBoot, isFalse);
    },
    tags: const <String>['feature_test__settings_startup__unit'],
  );

  test(
    'the appearance choice is persisted through the settings store',
    () async {
      final store = MemoryAppStore(
        settings: const AppSettings(embeddedDaemonEnabled: false),
      );
      final registry = HostRegistry(
        store: store,
        clientFactory: _ClientFactory(const <String, Future<TinestApi>>{}),
        ids: const _Ids(),
        clock: _Clock(now),
        delay: const _NoDelay(),
        clientKind: 'test',
      );
      addTearDown(registry.close);
      await registry.load();

      expect(registry.value.settings.themeMode, AppThemeMode.system);

      await registry.setThemeMode(AppThemeMode.dark);
      expect(store.settings.themeMode, AppThemeMode.dark);
      expect(registry.value.settings.themeMode, AppThemeMode.dark);

      await registry.setThemeMode(AppThemeMode.light);
      expect(store.settings.themeMode, AppThemeMode.light);
      expect(registry.value.settings.themeMode, AppThemeMode.light);

      // Returning to the system choice is a real value rather than an absent
      // one, so it has to be written back like any other selection.
      await registry.setThemeMode(AppThemeMode.system);
      expect(store.settings.themeMode, AppThemeMode.system);
      expect(registry.value.settings.themeMode, AppThemeMode.system);
    },
    tags: const <String>['feature_test__settings_appearance__unit'],
  );

  test(
    'shutdown stops every client and the app-owned daemon exactly once',
    () async {
      final store = MemoryAppStore();
      final embeddedApi = FakeTinestApi(
        serverInfo: _serverInfo('embedded-server'),
      );
      final launcher = _EmbeddedLauncher();
      final registry = HostRegistry(
        store: store,
        clientFactory: _ClientFactory(<String, Future<TinestApi>>{
          'embedded.test': Future<TinestApi>.value(embeddedApi),
        }),
        embeddedLauncher: launcher,
        ids: const _Ids(),
        clock: _Clock(now),
        delay: const _NoDelay(),
        clientKind: 'desktop',
      );

      await registry.load();
      await _flush();
      expect(launcher.session.stops, 0);

      await registry.shutdown();
      expect(embeddedApi.isClosed, isTrue);
      expect(launcher.session.stops, 1);

      // The provider scope disposes the registry after the tray quit path
      // already shut it down, so the second call must be inert.
      await registry.shutdown();
      expect(launcher.session.stops, 1);
    },
    tags: const <String>['feature_test__desktop_residency__unit'],
  );

  test(
    'concurrent shutdown and close join the same in-flight teardown',
    () async {
      final stopGate = Completer<void>();
      final launcher = _EmbeddedLauncher(firstStopGate: stopGate);
      final registry = HostRegistry(
        store: MemoryAppStore(),
        clientFactory: _ClientFactory(<String, Future<TinestApi>>{
          'embedded.test': Future<TinestApi>.value(
            FakeTinestApi(serverInfo: _serverInfo('embedded-server')),
          ),
        }),
        embeddedLauncher: launcher,
        ids: const _Ids(),
        clock: _Clock(now),
        delay: const _NoDelay(),
        clientKind: 'desktop',
      );

      await registry.load();
      await _flush();

      final shutdown = registry.shutdown();
      await _flush();
      expect(launcher.session.stops, 1);

      var closeCompleted = false;
      final close = registry.close().then((_) => closeCompleted = true);
      await _flush();
      expect(closeCompleted, isFalse);
      expect(launcher.session.stops, 1);

      stopGate.complete();
      await Future.wait(<Future<void>>[shutdown, close]);
      expect(closeCompleted, isTrue);
      expect(launcher.session.stops, 1);
    },
    tags: const <String>['feature_test__desktop_residency__unit'],
  );

  test(
    'close drains every resource before rethrowing the first failure',
    () async {
      final profiles = <RemoteDaemonProfile>[
        for (final id in <String>['first', 'second'])
          RemoteDaemonProfile(
            id: id,
            label: id,
            connections: directHostConnections(
              Uri.parse('ws://$id.test/ws'),
              credentialKey: id,
            ),
            autoConnect: false,
            createdAt: now,
            updatedAt: now,
          ),
      ];
      final clientFailure = StateError('first client close failed');
      final sessionFailure = StateError('embedded session stop failed');
      final embeddedApi = FakeTinestApi(
        serverInfo: _serverInfo('embedded-server'),
      );
      final firstApi = _ControlledApi(
        FakeTinestApi(serverInfo: _serverInfo('first-server')),
        closeFailure: clientFailure,
      );
      final secondApi = FakeTinestApi(serverInfo: _serverInfo('second-server'));
      final launcher = _EmbeddedLauncher(stopError: sessionFailure);
      final registry = HostRegistry(
        store: MemoryAppStore(
          profiles: profiles,
          tokens: const <String, String>{'first': 'one', 'second': 'two'},
        ),
        clientFactory: _ClientFactory(<String, Future<TinestApi>>{
          'embedded.test': Future<TinestApi>.value(embeddedApi),
          'first.test': Future<TinestApi>.value(firstApi),
          'second.test': Future<TinestApi>.value(secondApi),
        }),
        embeddedLauncher: launcher,
        ids: const _Ids(),
        clock: _Clock(now),
        delay: const _NoDelay(),
        clientKind: 'desktop',
      );

      await registry.load();
      await _flush();
      await registry.reconnect('first');
      await registry.reconnect('second');
      expect(
        registry.value.runtimes['first']!.status,
        HostRuntimeStatus.online,
        reason: registry.value.runtimes['first']!.error,
      );
      expect(registry.value.runtimes['first']!.api, same(firstApi));
      expect(registry.value.runtimes['second']!.api, same(secondApi));
      final changesDone = Completer<void>();
      registry.changes.listen(null, onDone: changesDone.complete);

      final shutdown = registry.shutdown();
      final close = registry.close();
      expect(identical(shutdown, close), isTrue);
      await expectLater(shutdown, throwsA(same(clientFailure)));
      await expectLater(close, throwsA(same(clientFailure)));

      expect(embeddedApi.isClosed, isTrue);
      expect(firstApi.closeCalls, 1);
      expect(firstApi.delegate.isClosed, isTrue);
      expect(secondApi.isClosed, isTrue);
      expect(launcher.session.stops, 1);
      await changesDone.future;

      await expectLater(registry.close(), throwsA(same(clientFailure)));
      expect(firstApi.closeCalls, 1);
      expect(launcher.session.stops, 1);
    },
    tags: const <String>['feature_test__desktop_residency__unit'],
  );

  test(
    'a state subscription cancel failure still closes its runtime client',
    () async {
      final cancelFailure = StateError('state subscription cancel failed');
      final states = StreamController<ClientConnectionState>(
        onCancel: () async => throw cancelFailure,
      );
      final embeddedApi = _ControlledApi(
        FakeTinestApi(serverInfo: _serverInfo('embedded-server')),
        states: states.stream,
        onClose: states.close,
      );
      final remoteApi = FakeTinestApi(serverInfo: _serverInfo('remote-server'));
      final profile = RemoteDaemonProfile(
        id: 'remote',
        label: 'remote',
        connections: directHostConnections(
          Uri.parse('ws://remote.test/ws'),
          credentialKey: 'remote',
        ),
        autoConnect: false,
        createdAt: now,
        updatedAt: now,
      );
      final launcher = _EmbeddedLauncher();
      final registry = HostRegistry(
        store: MemoryAppStore(
          profiles: <RemoteDaemonProfile>[profile],
          tokens: const <String, String>{'remote': 'token'},
        ),
        clientFactory: _ClientFactory(<String, Future<TinestApi>>{
          'embedded.test': Future<TinestApi>.value(embeddedApi),
          'remote.test': Future<TinestApi>.value(remoteApi),
        }),
        embeddedLauncher: launcher,
        ids: const _Ids(),
        clock: _Clock(now),
        delay: const _NoDelay(),
        clientKind: 'desktop',
      );

      await registry.load();
      await _flush();
      await registry.reconnect('remote');
      final changesDone = Completer<void>();
      registry.changes.listen(null, onDone: changesDone.complete);

      await expectLater(registry.shutdown(), throwsA(same(cancelFailure)));

      expect(embeddedApi.closeCalls, 1);
      expect(embeddedApi.delegate.isClosed, isTrue);
      expect(remoteApi.isClosed, isTrue);
      expect(launcher.session.stops, 1);
      await changesDone.future;
    },
    tags: const <String>['feature_test__desktop_residency__unit'],
  );

  test('pairing stores a daemon-scoped relay identity and profile', () async {
    final store = MemoryAppStore(
      settings: const AppSettings(embeddedDaemonEnabled: false),
    );
    final pairer = _Pairer();
    final registry = HostRegistry(
      store: store,
      clientFactory: _ClientFactory(const <String, Future<TinestApi>>{}),
      ids: const _Ids(),
      clock: _Clock(now),
      delay: const _NoDelay(),
      clientKind: 'test',
      relayPairer: pairer,
    );
    addTearDown(registry.close);
    await registry.load();

    final profile = await registry.pairRemote(
      pairingUrl: Uri.parse('https://tinest.tinyrack.net/pair#offer=test'),
      deviceName: 'My phone',
      autoConnect: false,
    );

    expect(profile.serverId, 'relay-daemon');
    expect(profile.relayConnections, hasLength(1));
    expect(store.profiles.single, same(profile));
    expect(store.relayCredentials.values.single.deviceId, 'device-1');
    expect(pairer.deviceName, 'My phone');
    expect(registry.value.runtimes[profile.id]!.status, HostRuntimeStatus.idle);
  });

  test(
    'pairing the same daemon updates its relay path without a duplicate',
    () async {
      final direct = DirectHostConnection(
        id: 'direct',
        credentialKey: 'direct-secret',
        endpoint: HostEndpoint.parse('wss://daemon.example/v5/ws'),
      );
      final existing = RemoteDaemonProfile(
        id: 'existing',
        label: 'Existing daemon',
        serverId: 'relay-daemon',
        connections: <HostConnection>[direct],
        autoConnect: false,
        createdAt: now,
        updatedAt: now,
      );
      final store = MemoryAppStore(
        settings: const AppSettings(embeddedDaemonEnabled: false),
        profiles: <RemoteDaemonProfile>[existing],
        tokens: const <String, String>{'direct-secret': 'token'},
      );
      final registry = HostRegistry(
        store: store,
        clientFactory: _ClientFactory(const <String, Future<TinestApi>>{}),
        ids: const _Ids(),
        clock: _Clock(now.add(const Duration(minutes: 1))),
        delay: const _NoDelay(),
        clientKind: 'test',
        relayPairer: _Pairer(),
      );
      addTearDown(registry.close);
      await registry.load();

      final paired = await registry.pairRemote(
        pairingUrl: Uri.parse('https://tinest.tinyrack.net/pair#offer=test'),
        deviceName: 'My phone',
        autoConnect: false,
      );

      expect(paired.id, existing.id);
      expect(store.profiles, hasLength(1));
      expect(store.profiles.single.label, existing.label);
      expect(store.profiles.single.connections, hasLength(2));
      expect(store.profiles.single.directConnections.single, same(direct));
      expect(store.profiles.single.relayConnections, hasLength(1));
      expect(store.relayCredentials, hasLength(1));
    },
  );

  test(
    'parallel startup selects the first valid path and fails over after loss',
    () async {
      final direct = DirectHostConnection(
        id: 'direct',
        credentialKey: 'direct-secret',
        endpoint: HostEndpoint.parse('ws://private.test/v5/ws'),
      );
      final relay = RelayHostConnection(
        id: 'relay',
        credentialKey: 'relay-secret',
        serverId: 'daemon-1',
        relayUri: Uri.parse('wss://relay.tinest.tinyrack.net/v1/ws'),
        daemonIdentityPublicKey: List<int>.filled(32, 1),
      );
      final profile = RemoteDaemonProfile(
        id: 'remote',
        label: 'Multi-path daemon',
        connections: <HostConnection>[direct, relay],
        autoConnect: true,
        serverId: 'daemon-1',
        createdAt: now,
        updatedAt: now,
      );
      final store = MemoryAppStore(
        settings: const AppSettings(embeddedDaemonEnabled: false),
        profiles: <RemoteDaemonProfile>[profile],
        tokens: const <String, String>{'direct-secret': 'bearer'},
      );
      store.relayCredentials['relay-secret'] = RelayHostCredential(
        deviceId: 'phone',
        privateKey: List<int>.filled(32, 2),
      );
      final directApi = FakeTinestApi(serverInfo: _serverInfo('daemon-1'));
      final lateRelay = Completer<TinestApi>();
      final relayProbe = FakeTinestApi(serverInfo: _serverInfo('daemon-1'));
      final relayApi = FakeTinestApi(serverInfo: _serverInfo('daemon-1'));
      final factory = _PathClientFactory(
        <String, List<Future<TinestApi> Function()>>{
          'direct': <Future<TinestApi> Function()>[
            () => Future<TinestApi>.value(directApi),
            () => Future<TinestApi>.error(
              const HostConnectionFailure.network('direct path lost'),
            ),
          ],
          'relay': <Future<TinestApi> Function()>[
            () => lateRelay.future,
            () => Future<TinestApi>.value(relayProbe),
            () => Future<TinestApi>.value(relayApi),
          ],
        },
      );
      final scheduler = _ManualProbeScheduler();
      final registry = HostRegistry(
        store: store,
        clientFactory: factory,
        ids: const _Ids(),
        clock: _Clock(now),
        delay: const _NoDelay(),
        clientKind: 'test',
        pathProbeScheduler: scheduler,
      );
      addTearDown(registry.close);

      await registry.load();
      await _flush();
      expect(registry.value.runtimes['remote']!.activeConnectionId, 'direct');
      expect(scheduler.interval, activeHostPathProbeInterval);
      lateRelay.complete(FakeTinestApi(serverInfo: _serverInfo('daemon-1')));
      await _flush();

      directApi.emitState(ClientConnectionState.disconnected);
      await _flush();
      expect(registry.value.runtimes['remote']!.activeConnectionId, 'relay');
      expect(registry.value.runtimes['remote']!.api, same(relayApi));
      expect(directApi.isClosed, isTrue);
      expect(relayProbe.isClosed, isTrue);
      expect(factory.connectionIds, <String>[
        'direct',
        'relay',
        'direct',
        'relay',
        'relay',
      ]);

      await registry.close();
      expect(scheduler.task.cancelled, isTrue);
    },
    tags: const <String>['feature_test__daemon_relay__unit'],
  );
}

ServerInfoDto _serverInfo(String id) => ServerInfoDto(
  serverId: id,
  version: 'test',
  protocolVersion: tinestProtocolMajor,
  features: const <String, bool>{},
);

Future<void> _flush() async {
  for (var index = 0; index < 5; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

final class _ClientFactory implements HostClientFactory {
  new(this.clients);

  final Map<String, Future<TinestApi>> clients;
  final List<String> connectedHosts = <String>[];

  @override
  Future<TinestApi> connect({
    required HostConnection connection,
    required HostConnectionCredential credential,
    required String clientId,
    required String clientKind,
  }) {
    connectedHosts.add(
      (connection as DirectHostConnection).endpoint.websocketUri.host,
    );
    return clients[connection.endpoint.websocketUri.host] ??
        Future<TinestApi>.error(const HostConnectionFailure.network('offline'));
  }
}

final class _ControlledApi implements TinestApi {
  new(
    this.delegate, {
    this.closeFailure,
    Stream<ClientConnectionState>? states,
    this.onClose,
  }) : _states = states ?? delegate.states;

  final FakeTinestApi delegate;
  final Error? closeFailure;
  final Stream<ClientConnectionState> _states;
  final Future<void> Function()? onClose;
  int closeCalls = 0;

  @override
  WorkspacesApi get workspaces => delegate.workspaces;

  @override
  SessionsApi get sessions => delegate.sessions;

  @override
  AgentsApi get agents => delegate.agents;

  @override
  PluginsApi get plugins => delegate.plugins;

  @override
  PromptsApi get prompts => delegate.prompts;

  @override
  ModelsApi get models => delegate.models;

  @override
  ProvidersApi get providers => delegate.providers;

  @override
  McpApi get mcp => delegate.mcp;

  @override
  TerminalsApi get terminals => delegate.terminals;

  @override
  AttachmentsApi get attachments => delegate.attachments;

  @override
  RelayApi get relay => delegate.relay;

  @override
  Stream<ClientConnectionState> get states => _states;

  @override
  ServerInfoDto get serverInfo => delegate.serverInfo;

  @override
  Future<void> close() async {
    closeCalls += 1;
    await delegate.close();
    await onClose?.call();
    if (closeFailure case final failure?) throw failure;
  }
}

final class _SequenceClientFactory implements HostClientFactory {
  new(this.results);

  final List<Future<TinestApi> Function()> results;
  int attempts = 0;

  @override
  Future<TinestApi> connect({
    required HostConnection connection,
    required HostConnectionCredential credential,
    required String clientId,
    required String clientKind,
  }) {
    final result = results[attempts]();
    attempts += 1;
    return result;
  }
}

final class _PathClientFactory implements HostClientFactory {
  new(Map<String, List<Future<TinestApi> Function()>> results)
    : _results = results.map(
        (key, value) =>
            MapEntry(key, List<Future<TinestApi> Function()>.of(value)),
      );

  final Map<String, List<Future<TinestApi> Function()>> _results;
  final List<String> connectionIds = <String>[];

  @override
  Future<TinestApi> connect({
    required HostConnection connection,
    required HostConnectionCredential credential,
    required String clientId,
    required String clientKind,
  }) {
    connectionIds.add(connection.id);
    final results = _results[connection.id];
    if (results == null || results.isEmpty) {
      return Future<TinestApi>.error(
        const HostConnectionFailure.network('unexpected connection'),
      );
    }
    return results.removeAt(0)();
  }
}

final class _ManualProbeScheduler implements HostPathProbeScheduler {
  late Duration interval;
  late Future<void> Function() callback;
  final _ManualProbeTask task = _ManualProbeTask();

  @override
  HostPathProbeTask periodic(
    Duration interval,
    Future<void> Function() callback,
  ) {
    this.interval = interval;
    this.callback = callback;
    return task;
  }
}

final class _ManualProbeTask implements HostPathProbeTask {
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;
}

final class _EmbeddedLauncher implements EmbeddedDaemonLauncher {
  new({
    this.firstStopGate,
    this.stopError,
    this.failingStarts = const <int>{},
    this.calls,
  });

  final Completer<void>? firstStopGate;
  final Error? stopError;
  final Set<int> failingStarts;

  /// Shared ordered log used by reset tests.
  final List<String>? calls;
  final List<EmbeddedDaemonExposure> exposures = <EmbeddedDaemonExposure>[];
  final List<int> ports = <int>[];
  final List<_EmbeddedSession> sessions = <_EmbeddedSession>[];
  int starts = 0;

  _EmbeddedSession get session => sessions.last;

  @override
  Future<EmbeddedDaemonSession> start({
    required EmbeddedDaemonExposure exposure,
    required int port,
  }) async {
    starts += 1;
    exposures.add(exposure);
    ports.add(port);
    calls?.add('start');
    if (failingStarts.contains(starts)) {
      throw const HostConnectionFailure.network('startup failed');
    }
    final session = _EmbeddedSession(
      stopGate: sessions.isEmpty ? firstStopGate : null,
      stopError: stopError,
      calls: calls,
    );
    sessions.add(session);
    return session;
  }
}

final class _EmbeddedSession implements EmbeddedDaemonSession {
  new({this.stopGate, this.stopError, this.calls});

  final Completer<void>? stopGate;
  final Error? stopError;
  final List<String>? calls;

  @override
  HostEndpoint get endpoint => HostEndpoint.parse('ws://embedded.test/ws');

  @override
  DaemonCredentials get credentials =>
      const DaemonCredentials(bearerToken: 'embedded-bearer');

  @override
  String get serverId => 'embedded-server';
  int stops = 0;

  @override
  Future<void> stop() async {
    stops += 1;
    calls?.add('stop');
    await stopGate?.future;
    if (stopError case final error?) throw error;
  }
}

final class _DataEraser implements EmbeddedDaemonDataEraser {
  new({required this.calls, this.failure});

  final List<String> calls;
  final FactoryResetFailure? failure;
  int erases = 0;

  @override
  Future<void> eraseAll() async {
    erases += 1;
    calls.add('erase');
    final error = failure;
    if (error != null) throw error;
  }
}

final class _Ids implements AppIdGenerator {
  const new();

  @override
  String generate() => 'generated-id';
}

final class _Clock implements AppClock {
  const new(this.value);

  final DateTime value;

  @override
  DateTime nowUtc() => value;
}

final class _NoDelay implements AppDelay {
  const new();

  @override
  Future<void> wait(Duration duration) async {}
}

final class _Pairer implements HostRelayPairer {
  String? deviceName;

  @override
  Future<RelayPairingResult> pair({
    required Uri pairingUrl,
    required String deviceId,
    required String deviceName,
    required String connectionId,
    required String credentialKey,
  }) async {
    this.deviceName = deviceName;
    return RelayPairingResult(
      connection: RelayHostConnection(
        id: connectionId,
        credentialKey: credentialKey,
        serverId: 'relay-daemon',
        relayUri: Uri.parse('wss://relay.tinest.tinyrack.net/v1/ws'),
        daemonIdentityPublicKey: List<int>.filled(32, 1),
      ),
      credential: RelayHostCredential(
        deviceId: 'device-1',
        privateKey: List<int>.filled(32, 2),
      ),
    );
  }
}

final class _RecordingDelay implements AppDelay {
  final List<Duration> durations = <Duration>[];

  @override
  Future<void> wait(Duration duration) async {
    durations.add(duration);
  }
}

final class _FailingProfiles implements RemoteHostRepository {
  const new();

  @override
  Future<void> deleteProfile(String profileId) async {}

  @override
  Future<List<RemoteDaemonProfile>> listProfiles() async =>
      const <RemoteDaemonProfile>[];

  @override
  Future<void> upsertProfile(RemoteDaemonProfile profile) =>
      Future<void>.error(const _ProfileWriteFailure());
}

final class _ProfileWriteFailure implements Exception {
  const new();
}

final class _FailingEmbeddedLauncher implements EmbeddedDaemonLauncher {
  const new();

  @override
  Future<EmbeddedDaemonSession> start({
    required EmbeddedDaemonExposure exposure,
    required int port,
  }) => Future<EmbeddedDaemonSession>.error(
    const HostConnectionFailure.network('startup failed'),
  );
}
