import 'dart:io';

import 'package:app/testing/app/composition/app_services.dart';
import 'package:app/testing/features/hosts/domain/host_models.dart';
import 'package:app/testing/features/hosts/domain/host_ports.dart';
import 'package:client/client.dart';
import 'package:daemon/daemon.dart';

import 'temporary_directory.dart';

/// Real local daemon and production WebSocket composition for runner E2E.
final class RealDaemonFixture {
  new _({
    required this.home,
    required this.daemon,
    required this.store,
    required this.token,
    required this.clientKind,
  });

  /// Starts a daemon in an isolated temporary home.
  static Future<RealDaemonFixture> start({
    required String id,
    bool configureRemoteProfile = true,
    AppSettings settings = const AppSettings(embeddedDaemonEnabled: false),
    ModelGateway? provider,
    ProviderModelDiscovery? modelDiscovery,
    ProviderOAuthGateway? oauthGateway,
    ProviderCatalogMetadataSource? providerCatalogMetadataSource,
  }) async {
    final home = await Directory.systemTemp.createTemp('tinest-$id-e2e-');
    final token = '$id-e2e-token-0123456789abcdef0123456789';
    final ids = SequenceE2eIds(id);
    final daemon = await DaemonApplication.start(
      DaemonConfig(
        homeDirectory: home.path,
        // The isolated temporary home stands in for the machine home, so a
        // picker opened in this run never reaches the real user home.
        osHomeDirectory: home.path,
        port: 0,
        bearerToken: token,
        useEnvironmentCredentials: false,
      ),
      clock: const FixedE2eClock(),
      ids: ids,
      provider: provider,
      modelDiscovery: modelDiscovery,
      oauthGateway: oauthGateway,
      providerCatalogMetadataSource: providerCatalogMetadataSource,
    );
    final now = DateTime.utc(2026, 8, 5);
    final store = MemoryAppStore(
      settings: settings,
      profiles: configureRemoteProfile
          ? <RemoteDaemonProfile>[
              RemoteDaemonProfile(
                id: '$id-daemon',
                label: '${_title(id)} daemon',
                connections: directHostConnections(daemon.boundEndpoint),
                autoConnect: true,
                createdAt: now,
                updatedAt: now,
              ),
            ]
          : const <RemoteDaemonProfile>[],
      tokens: configureRemoteProfile
          ? <String, String>{'$id-daemon': token}
          : const <String, String>{},
    );
    return RealDaemonFixture._(
      home: home,
      daemon: daemon,
      store: store,
      token: token,
      clientKind: '$id-e2e',
    );
  }

  final Directory home;
  final DaemonHandle daemon;
  final MemoryAppStore store;
  final String token;
  final String clientKind;

  /// Production app services connected through a real WebSocket.
  AppServices get services => AppServices(
    settings: store,
    profiles: store,
    credentials: store,
    clients: const WebSocketHostClientFactory(),
    clientKind: clientKind,
  );

  /// Opens an assertion client against the same daemon.
  Future<TinestApi> connect({String clientId = 'e2e-assertions'}) =>
      TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: daemon.boundEndpoint),
        credentials: DaemonCredentials(bearerToken: token),
        clientId: clientId,
        clientKind: clientKind,
      );

  Future<void> dispose() async {
    await daemon.stop();
    await deleteTemporaryDirectory(home);
  }
}

/// Stable wall clock shared by real-daemon E2E fixtures.
final class FixedE2eClock implements Clock {
  const new();

  @override
  DateTime nowUtc() => DateTime.utc(2026, 8, 5, 12);
}

/// Deterministic daemon identifier source scoped by fixture ID.
final class SequenceE2eIds implements IdGenerator {
  new(this.prefix);

  final String prefix;
  var _next = 0;

  @override
  String generate() => '$prefix-e2e-${_next++}';
}

String _title(String value) => '${value[0].toUpperCase()}${value.substring(1)}';
