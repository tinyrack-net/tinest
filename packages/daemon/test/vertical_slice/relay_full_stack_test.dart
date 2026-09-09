import 'dart:async';
import 'dart:io';

import 'package:client/client.dart';
import 'package:daemon/daemon.dart';
import 'package:relay/relay.dart';
import 'package:relay_protocol/relay_protocol.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

void main() {
  test('pairing and RPC cross a real daemon, relay, and client', () async {
    final stack = await _RelayStack.start('pairing');
    addTearDown(stack.close);

    final paired = await stack.pair(deviceId: 'phone');
    final client = await stack.connectRelay(paired);

    expect(client.serverInfo.serverId, stack.daemon.serverId);
    expect((await client.getRelayStatus()).connected, isTrue);
    expect(
      (await client.listRelayDevices()).map((device) => device.id),
      contains('phone'),
    );
  }, tags: const <String>['feature_test__daemon_relay__verticalSlice']);

  test(
    'revocation terminates the live relay session and rejects its key',
    () async {
      final stack = await _RelayStack.start('revocation');
      addTearDown(stack.close);
      final paired = await stack.pair(deviceId: 'tablet');
      final client = await stack.connectRelay(paired);
      final disconnected = client.states.firstWhere(
        (state) => state == ClientConnectionState.disconnected,
      );

      await stack.admin.revokeRelayDevice('tablet');
      await disconnected.timeout(const Duration(seconds: 5));
      await client.close();

      await expectLater(
        stack.connectRelay(paired).timeout(const Duration(seconds: 5)),
        throwsA(anyOf(isA<RelaySecurityException>(), isA<TimeoutException>())),
      );
    },
  );

  test(
    'attachment content crosses the real relay beyond one credit window',
    () async {
      final stack = await _RelayStack.start('attachment');
      addTearDown(stack.close);
      final paired = await stack.pair(deviceId: 'laptop');
      final client = await stack.connectRelay(paired);
      const size = relayAttachmentCreditWindowBytes + 257;

      final uploaded = await client.uploadAttachment(
        fileName: 'relay-payload.bin',
        mimeType: 'application/octet-stream',
        byteSize: size,
        bytes: _bytes(size, 0x5a),
      );
      final download = await client.downloadAttachment(uploaded.id);
      final received = await download.bytes.expand((chunk) => chunk).toList();

      expect(uploaded.byteSize, size);
      expect(download.fileName, 'relay-payload.bin');
      expect(received, hasLength(size));
      expect(received, everyElement(0x5a));
    },
  );

  test(
    'parallel stacks use independently bound operating-system ports',
    () async {
      final stacks = await Future.wait(<Future<_RelayStack>>[
        _RelayStack.start('isolation-a'),
        _RelayStack.start('isolation-b'),
      ]);
      addTearDown(() async {
        await Future.wait(stacks.map((stack) => stack.close()));
      });

      expect(stacks[0].relayPort, isNot(stacks[1].relayPort));
      expect(stacks[0].daemonPort, isNot(stacks[1].daemonPort));
      final clients = await Future.wait(<Future<TinestClient>>[
        stacks[0].pairAndConnect(deviceId: 'device-a'),
        stacks[1].pairAndConnect(deviceId: 'device-b'),
      ]);
      expect(clients[0].serverInfo.serverId, stacks[0].daemon.serverId);
      expect(clients[1].serverInfo.serverId, stacks[1].daemon.serverId);
    },
    tags: const <String>['feature_test__daemon_relay__verticalSlice'],
  );
}

Stream<List<int>> _bytes(int total, int byte) async* {
  const chunkSize = 128 * 1024;
  for (var sent = 0; sent < total; sent += chunkSize) {
    yield List<int>.filled((total - sent).clamp(0, chunkSize), byte);
  }
}

final class _RelayStack {
  new _({
    required this.home,
    required this.relayService,
    required this.relayServer,
    required this.daemon,
    required this.admin,
  });

  static Future<_RelayStack> start(String id) async {
    final home = await Directory.systemTemp.createTemp('tinest-relay-$id-');
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
      final token = '$id-relay-token-0123456789abcdef0123456789';
      daemon = await DaemonApplication.start(
        DaemonConfig(
          homeDirectory: home.path,
          configDirectory: home.path,
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
        clientKind: 'test',
      );
      return _RelayStack._(
        home: home,
        relayService: relayService,
        relayServer: relayServer,
        daemon: daemon,
        admin: admin,
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
  final List<TinestClient> _relayClients = <TinestClient>[];

  int get relayPort => relayServer.port;
  int get daemonPort => daemon.boundEndpoint.port;

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

  Future<TinestClient> pairAndConnect({required String deviceId}) async =>
      await connectRelay(await pair(deviceId: deviceId));

  Future<TinestClient> connectRelay(RelayPairingResult paired) async {
    final client = await TinestClient.connect(
      endpoint: HostEndpoint(websocketUri: paired.connection.relayUri),
      credentials: const DaemonCredentials(
        bearerToken: 'relay-device-authentication-is-e2e',
      ),
      clientId: '${paired.credential.deviceId}-client',
      clientKind: 'test',
      connector: RelayWebSocketConnector(
        connection: paired.connection,
        credential: paired.credential,
      ),
      reconnectDelay: (_) => Duration.zero,
    );
    _relayClients.add(client);
    return client;
  }

  Future<void> close() async {
    for (final client in _relayClients.reversed) {
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
