import 'package:app/src/app/composition/app_services.dart';
import 'package:app/src/features/desktop/infrastructure/desktop_bootstrap.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/hosts/domain/host_ports.dart';
import 'package:app/src/features/hosts/infrastructure/remote_bootstrap.dart';
import 'package:client/client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_tinest_api.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test(
    'desktop and mobile service factories expose platform capabilities',
    () async {
      const clients = _UnusedClients();
      const launcher = _UnusedLauncher();
      const dataEraser = _UnusedDataEraser();
      final desktop = await createDesktopServices(
        embeddedLauncher: launcher,
        embeddedDataEraser: dataEraser,
        clients: clients,
      );
      final mobile = await createRemoteServices(clients: clients);

      expect(desktop.supportsEmbeddedDaemon, isTrue);
      expect(desktop.embeddedLauncher, same(launcher));
      expect(desktop.clients, same(clients));
      expect(desktop.clientKind, 'desktop');
      expect(mobile.supportsEmbeddedDaemon, isFalse);
      expect(mobile.embeddedLauncher, isNull);
      expect(mobile.clients, same(clients));
      expect(mobile.clientKind, 'mobile');
    },
  );

  test('WebSocket factory classifies typed connection failures', () async {
    final api = FakeTinestApi();
    final endpoint = HostEndpoint.parse('wss://daemon.example/ws');
    const credentials = DaemonCredentials(bearerToken: 'token');
    final connection = DirectHostConnection(
      id: 'direct',
      credentialKey: 'direct',
      endpoint: endpoint,
    );
    const credential = DirectHostCredential(credentials);
    final success = WebSocketHostClientFactory(
      openClient: ({
        required endpoint,
        required credentials,
        required clientId,
        required clientKind,
      }) async => api,
    );
    expect(
      await success.connect(
        connection: connection,
        credential: credential,
        clientId: 'client',
        clientKind: 'test',
      ),
      same(api),
    );

    Future<TinestApi> connectWith(Object error) =>
        WebSocketHostClientFactory(
          openClient: ({
            required endpoint,
            required credentials,
            required clientId,
            required clientKind,
          }) => Future<TinestApi>.error(error),
        ).connect(
          connection: connection,
          credential: credential,
          clientId: 'client',
          clientKind: 'test',
        );

    await expectLater(
      connectWith(
        const TinestClientException(
          'wrong protocol',
          code: 'protocol_mismatch',
        ),
      ),
      throwsA(
        isA<HostConnectionFailure>().having(
          (failure) => failure.kind,
          'kind',
          HostConnectionFailureKind.protocolMismatch,
        ),
      ),
    );
    await expectLater(
      connectWith(Exception('HTTP 401')),
      throwsA(
        isA<HostConnectionFailure>().having(
          (failure) => failure.kind,
          'kind',
          HostConnectionFailureKind.authentication,
        ),
      ),
    );
    await expectLater(
      connectWith(Exception('offline')),
      throwsA(
        isA<HostConnectionFailure>().having(
          (failure) => failure.kind,
          'kind',
          HostConnectionFailureKind.network,
        ),
      ),
    );
  });
}

final class _UnusedClients implements HostClientFactory {
  const new();

  @override
  Future<TinestApi> connect({
    required HostConnection connection,
    required HostConnectionCredential credential,
    required String clientId,
    required String clientKind,
  }) => throw StateError('No connection is expected in a factory test.');
}

final class _UnusedLauncher implements EmbeddedDaemonLauncher {
  const new();

  @override
  Future<EmbeddedDaemonSession> start({
    required EmbeddedDaemonExposure exposure,
    required int port,
  }) => throw StateError('No daemon is expected in a factory test.');
}

final class _UnusedDataEraser implements EmbeddedDaemonDataEraser {
  const new();

  @override
  Future<void> eraseAll() =>
      throw StateError('No daemon data erase is expected in a factory test.');
}
