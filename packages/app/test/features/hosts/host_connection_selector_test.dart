import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/app/composition/app_services.dart';
import 'package:app/src/features/hosts/application/host_controller.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/hosts/domain/host_ports.dart';
import 'package:app/src/features/sessions/application/sessions_controller.dart';
import 'package:client/client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';

import '../../support/fake_tinest_api.dart';

void main() {
  final now = DateTime.utc(2026, 8, 10);
  final worktree = WorktreeDto(
    id: 'worktree',
    workspaceId: 'workspace',
    name: 'main',
    path: '/repos/tinest',
    kind: WorktreeKind.checkout,
    isTinestOwned: false,
    createdAt: now,
  );
  final agent = SessionDto(
    id: 'one',
    worktreeId: worktree.id,
    title: 'Session one',
    agentDefinitionId: 'tinest',
    origin: SessionOrigin.manual,
    status: SessionStatus.idle,
    model: const ModelSelectionDto(modelId: 'openai/gpt-5.6-sol'),
    createdAt: now,
    updatedAt: now,
  );

  ({ProviderContainer container, FakeTinestApi api}) connectedHost() {
    final api = FakeTinestApi(
      serverInfo: const ServerInfoDto(
        serverId: 'server',
        version: 'test',
        protocolVersion: tinestProtocolMajor,
        features: <String, bool>{},
      ),
      worktrees: <WorktreeDto>[worktree],
      agents: <SessionDto>[agent],
    );
    final store = MemoryAppStore(
      settings: const AppSettings(embeddedDaemonEnabled: false),
      profiles: <RemoteDaemonProfile>[
        RemoteDaemonProfile(
          id: 'server',
          label: 'server',
          connections: directHostConnections(Uri.parse('ws://server.test/ws')),
          autoConnect: true,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      tokens: const <String, String>{'server': 'token'},
    );
    return (
      container: ProviderContainer(
        overrides: [
          appServicesProvider.overrideWithValue(
            AppServices(
              settings: store,
              profiles: store,
              credentials: store,
              clients: _HostClients(<String, TinestApi>{'server.test': api}),
              clientKind: 'test',
            ),
          ),
        ],
      ),
      api: api,
    );
  }

  test(
    'a device-settings write leaves the watched host connection untouched',
    () async {
      final host = connectedHost();
      addTearDown(host.container.dispose);
      var builds = 0;
      final probe = Provider<TinestApi?>((ref) {
        builds += 1;
        return watchHostConnection(ref, 'server').api;
      });
      host.container.listen(probe, (_, _) {});

      // Before the registry answers, the connection reads as not-yet-loaded so
      // callers can stay loading instead of reporting an offline daemon.
      expect(host.container.read(probe), isNull);
      expect(builds, 1);

      await host.container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(host.container.read(probe), isNotNull);
      final connectedBuilds = builds;

      await host.container
          .read(hostRegistryControllerProvider.notifier)
          .setSidebarCollapsed(collapsed: true);
      await Future<void>.delayed(Duration.zero);

      expect(builds, connectedBuilds);
    },
    tags: const <String>['feature_test__session_tabs__unit'],
  );

  test('a device-settings write never reloads the session catalog', () async {
    final host = connectedHost();
    addTearDown(host.container.dispose);
    await host.container.read(hostRegistryControllerProvider.future);
    await Future<void>.delayed(Duration.zero);
    final sessions = sessionsControllerProvider('server', worktree.id);
    host.container.listen(sessions, (_, _) {});
    await host.container.read(sessions.future);
    final loads = host.api.listSessionsCount;

    await host.container
        .read(hostRegistryControllerProvider.notifier)
        .setSidebarCollapsed(collapsed: true);
    await Future<void>.delayed(Duration.zero);

    expect(host.api.listSessionsCount, loads);
  }, tags: const <String>['feature_test__session_tabs__unit']);

  test('a registry that cannot load surfaces its failure', () async {
    final container = ProviderContainer(
      overrides: [
        appServicesProvider.overrideWithValue(
          const AppServices(
            settings: _FailingStore(),
            profiles: _FailingStore(),
            credentials: _FailingStore(),
            clients: _FailingStore(),
            clientKind: 'test',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(hostRegistryControllerProvider.future),
      throwsA(isA<StateError>()),
    );

    final probe = FutureProvider<TinestApi?>(
      (ref) => watchConnectedHostApi(ref, 'server'),
    );
    container.listen(probe, (_, _) {});
    expect(container.read(probe).error, isA<StateError>());
  }, tags: const <String>['feature_test__session_tabs__unit']);

  test('a disconnected host reports a loaded connection with no API', () async {
    final store = MemoryAppStore(
      settings: const AppSettings(embeddedDaemonEnabled: false),
    );
    final container = ProviderContainer(
      overrides: [
        appServicesProvider.overrideWithValue(
          AppServices(
            settings: store,
            profiles: store,
            credentials: store,
            clients: const _HostClients(<String, TinestApi>{}),
            clientKind: 'test',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(hostRegistryControllerProvider.future);

    final probe = Provider<HostApiConnection>(
      (ref) => watchHostConnection(ref, 'missing'),
    );
    expect(container.read(probe), (
      loaded: true,
      api: null,
      error: null,
      stackTrace: null,
    ));
  }, tags: const <String>['feature_test__session_tabs__unit']);
}

final class _FailingStore
    implements
        AppSettingsRepository,
        RemoteHostRepository,
        RemoteHostCredentialStore,
        HostClientFactory {
  const new();

  @override
  Future<AppSettings> loadSettings() =>
      Future<AppSettings>.error(StateError('connection failed'));

  @override
  Future<List<RemoteDaemonProfile>> listProfiles() async =>
      const <RemoteDaemonProfile>[];

  @override
  Future<void> saveSettings(AppSettings settings) async {}

  @override
  Future<void> upsertProfile(RemoteDaemonProfile profile) async {}

  @override
  Future<void> deleteProfile(String profileId) async {}

  @override
  Future<String?> readBearerToken(String profileId) async => null;

  @override
  Future<void> writeBearerToken(String profileId, String token) async {}

  @override
  Future<void> deleteBearerToken(String profileId) async {}

  @override
  Future<void> deleteAllBearerTokens() async {}

  @override
  Future<void> clear() async {}

  @override
  Future<TinestApi> connect({
    required HostConnection connection,
    required HostConnectionCredential credential,
    required String clientId,
    required String clientKind,
  }) => Future<TinestApi>.error(StateError('connection failed'));
}

final class _HostClients implements HostClientFactory {
  const new(this.apis);

  final Map<String, TinestApi> apis;

  @override
  Future<TinestApi> connect({
    required HostConnection connection,
    required HostConnectionCredential credential,
    required String clientId,
    required String clientKind,
  }) async =>
      apis[(connection as DirectHostConnection).endpoint.websocketUri.host]!;
}
