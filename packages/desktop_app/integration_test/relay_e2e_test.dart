import 'dart:async';
import 'dart:io';

import 'package:app/testing/app/composition/app_services.dart';
import 'package:app/testing/features/hosts/application/host_path_policy.dart';
import 'package:client/client.dart';
import 'package:daemon/daemon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:relay/relay.dart';
import 'package:relay_protocol/relay_protocol.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a real relay pairs the app client and carries daemon RPC', (
    tester,
  ) async {
    final stack = await _RelayE2eStack.start('pairing');
    addTearDown(stack.close);

    final paired = await stack.pair(deviceId: 'phone');
    final client = await stack.connect(paired);
    await tester.pump();

    expect(client.serverInfo.serverId, stack.daemon.serverId);
    expect((await client.relay.getRelayStatus()).connected, isTrue);
    final devices = await client.relay.listRelayDevices();
    expect(devices, hasLength(1));
    expect(devices.single.id, 'phone');
  }, tags: const <String>['feature_scenario__daemon_relay__pairing__e2e']);

  testWidgets(
    'a bound failing direct path selects the authenticated real relay',
    (tester) async {
      final stack = await _RelayE2eStack.start('failover');
      addTearDown(stack.close);
      final paired = await stack.pair(deviceId: 'phone');
      final rejectionServer = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => rejectionServer.close(force: true));
      rejectionServer.listen((request) async {
        request.response.statusCode = HttpStatus.serviceUnavailable;
        await request.response.close();
      });
      final direct = DirectHostConnection(
        id: 'direct',
        credentialKey: 'direct-key',
        endpoint: HostEndpoint(
          websocketUri: Uri(
            scheme: 'ws',
            host: InternetAddress.loopbackIPv4.address,
            port: rejectionServer.port,
            path: '/v5/ws',
          ),
        ),
      );
      const factory = WebSocketHostClientFactory();
      final stopwatch = Stopwatch()..start();
      await expectLater(
        factory.connect(
          connection: direct,
          credential: DirectHostCredential(
            DaemonCredentials(bearerToken: stack.token),
          ),
          clientId: 'direct-probe',
          clientKind: 'e2e',
        ),
        throwsA(isA<Exception>()),
      );
      final relayApi = await factory.connect(
        connection: paired.connection,
        credential: paired.credential,
        clientId: 'relay-probe',
        clientKind: 'e2e',
      );
      stack.clients.add(relayApi);
      stopwatch.stop();
      final policy = HostPathPolicy(
        authoritativeServerId: stack.daemon.serverId,
      )..selectInitial(direct);

      final selected = policy.evaluate(<HostPathObservation>[
        HostPathObservation.failure(direct),
        HostPathObservation.success(
          paired.connection,
          latency: stopwatch.elapsed,
          serverId: relayApi.serverInfo.serverId,
        ),
      ]);
      await tester.pump();

      expect(selected, same(paired.connection));
      expect(relayApi.serverInfo.serverId, stack.daemon.serverId);
    },
    tags: const <String>['feature_scenario__daemon_relay__failover__e2e'],
  );

  testWidgets('revoking a device terminates its real encrypted relay session', (
    tester,
  ) async {
    final stack = await _RelayE2eStack.start('revocation');
    addTearDown(stack.close);
    final paired = await stack.pair(deviceId: 'tablet');
    final client = await stack.connect(paired);
    final disconnected = client.states.firstWhere(
      (state) => state == ClientConnectionState.disconnected,
    );

    await stack.admin.revokeRelayDevice('tablet');
    await disconnected.timeout(const Duration(seconds: 5));
    await tester.pump();

    expect(await stack.admin.listRelayDevices(), isEmpty);
  }, tags: const <String>['feature_scenario__daemon_relay__revocation__e2e']);

  testWidgets(
    'a real relay streams an attachment beyond one credit window',
    (tester) async {
      final stack = await _RelayE2eStack.start('attachment');
      addTearDown(stack.close);
      final client = await stack.connect(await stack.pair(deviceId: 'laptop'));
      const size = relayAttachmentCreditWindowBytes + 257;

      final uploaded = await client.attachments.uploadAttachment(
        fileName: 'private-name.bin',
        mimeType: 'application/octet-stream',
        byteSize: size,
        bytes: _bytes(size, 0x5a),
      );
      final download = await client.attachments.downloadAttachment(uploaded.id);
      final received = await download.bytes
          .expand<int>((chunk) => chunk)
          .toList();
      await tester.pump();

      expect(download.fileName, 'private-name.bin');
      expect(received, hasLength(size));
      expect(received, everyElement(0x5a));
    },
    tags: const <String>[
      'feature_test__daemon_relay__e2e',
      'feature_scenario__daemon_relay__relay_attachment__e2e',
    ],
  );
}

Stream<List<int>> _bytes(int total, int byte) async* {
  const chunkSize = 128 * 1024;
  for (var sent = 0; sent < total; sent += chunkSize) {
    yield List<int>.filled((total - sent).clamp(0, chunkSize), byte);
  }
}

final class _RelayE2eStack {
  new _({
    required this.home,
    required this.relayService,
    required this.relayServer,
    required this.daemon,
    required this.admin,
    required this.token,
  });

  static Future<_RelayE2eStack> start(String id) async {
    final home = await Directory.systemTemp.createTemp('tinest-app-relay-$id-');
    final relayService = RelayService();
    final relayServer = await shelf_io.serve(
      relayService.call,
      InternetAddress.loopbackIPv4,
      0,
    );
    final relayEndpoint = Uri(
      scheme: 'ws',
      host: InternetAddress.loopbackIPv4.address,
      port: relayServer.port,
      path: '/v1/ws',
    );
    DaemonHandle? daemon;
    TinestClient? admin;
    try {
      final token = '$id-app-relay-token-0123456789abcdef0123456789';
      daemon = await DaemonApplication.start(
        DaemonConfig(
          homeDirectory: home.path,
          configDirectory: home.path,
          osHomeDirectory: home.path,
          port: 0,
          bearerToken: token,
          useEnvironmentCredentials: false,
          relay: RelayDaemonConfig(enabled: true, endpoint: relayEndpoint),
        ),
        providerCatalogMetadataSource: const _OfflineMetadataSource(),
      );
      admin = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: daemon.boundEndpoint),
        credentials: DaemonCredentials(bearerToken: token),
        clientId: '$id-admin',
        clientKind: 'e2e',
      );
      return _RelayE2eStack._(
        home: home,
        relayService: relayService,
        relayServer: relayServer,
        daemon: daemon,
        admin: admin,
        token: token,
      );
    } catch (_) {
      await admin?.close();
      await daemon?.stop();
      await relayService.drain();
      await relayServer.close(force: true);
      await home.delete(recursive: true);
      rethrow;
    }
  }

  final Directory home;
  final RelayService relayService;
  final HttpServer relayServer;
  final DaemonHandle daemon;
  final TinestClient admin;
  final String token;
  final List<TinestApi> clients = <TinestApi>[];

  Future<RelayPairingResult> pair({required String deviceId}) async {
    final offer = await admin.createRelayPairingOffer();
    return await RelayDevicePairer().pair(
      pairingUrl: Uri.parse(offer.url),
      deviceId: deviceId,
      deviceName: deviceId,
      connectionId: '$deviceId-relay',
      credentialKey: '$deviceId-key',
    );
  }

  Future<TinestApi> connect(RelayPairingResult paired) async {
    final api = await const WebSocketHostClientFactory().connect(
      connection: paired.connection,
      credential: paired.credential,
      clientId: '${paired.credential.deviceId}-client',
      clientKind: 'e2e',
    );
    clients.add(api);
    return api;
  }

  Future<void> close() async {
    for (final client in clients.reversed) {
      await client.close();
    }
    await admin.close();
    await daemon.stop();
    await relayService.drain();
    await relayServer.close(force: true);
    await home.delete(recursive: true);
  }
}

final class _OfflineMetadataSource implements ProviderCatalogMetadataSource {
  const new();

  @override
  Future<void> close() async {}

  @override
  Future<Map<String, List<ProviderCatalogMetadata>>> fetch(
    Set<String> providerIds,
  ) async => <String, List<ProviderCatalogMetadata>>{};
}
