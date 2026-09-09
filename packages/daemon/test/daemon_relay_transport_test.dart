import 'dart:async';
import 'dart:convert';

import 'package:client/client.dart';
import 'package:daemon/src/bootstrap/config.dart';
import 'package:daemon/src/features/relay/application/relay_control_service.dart';
import 'package:daemon/src/features/relay/application/relay_pairing_service.dart';
import 'package:daemon/src/features/relay/application/relay_ports.dart';
import 'package:daemon/src/features/relay/infrastructure/daemon_relay_transport.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:daemon/src/transport/rpc/session_host.dart';
import 'package:protocol/protocol.dart';
import 'package:relay_protocol/relay_protocol.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

void main() {
  test(
    'authenticates and hides a JSON-RPC channel inside opaque frames',
    () async {
      final clientIdentity = await RelayIdentity.fromSeed(
        List<int>.filled(32, 1),
      );
      final daemonIdentity = await RelayIdentity.fromSeed(
        List<int>.filled(32, 2),
      );
      final pairing = RelayPairingService(
        serverId: 'daemon-1',
        relayUri: Uri.parse('wss://relay.example/v1/ws'),
        daemonIdentityPublicKey: daemonIdentity.publicKey,
        devices: MemoryRelayDeviceRepository(),
        clock: const _Clock(),
        ids: const _Ids(),
        randomBytes: (length) => List<int>.filled(length, 8),
      );
      final offer = pairing.createOffer();
      await pairing.registerDevice(
        offerId: offer.offerId,
        offerSecret: offer.secret,
        deviceId: 'phone',
        deviceName: 'Phone',
        devicePublicKey: clientIdentity.publicKey,
      );
      final socket = StreamChannelController<dynamic>(sync: true);
      final connector = _Connector(socket.local);
      final rpc = _RpcSessions();
      late final RelayControlService control;
      control = RelayControlService(
        enabled: true,
        endpoint: Uri.parse('wss://relay.example/v1/ws'),
        serverId: 'daemon-1',
        pairing: pairing,
        applyEnabled: ({required enabled}) async {},
      );
      final transport = DaemonRelayTransport(
        serverId: 'daemon-1',
        endpoint: control.endpoint,
        tlsPolicy: RelayTlsPolicy.systemTrust,
        identity: daemonIdentity,
        pairing: pairing,
        rpcSessions: rpc,
        attachments: const _Attachments(),
        control: control,
        connector: connector,
      );
      addTearDown(() async {
        await transport.close();
        await control.close();
        await socket.foreign.sink.close();
      });
      await transport.start();
      await pumpEventQueue();
      expect(control.status.connected, isTrue);
      expect(connector.uri.queryParameters['role'], 'daemon');

      final initiator = await RelayHandshakeInitiator.start(
        serverId: 'daemon-1',
        sessionId: 'session-1',
        deviceId: 'phone',
        identity: clientIdentity,
        ephemeralSeed: List<int>.filled(32, 3),
      );
      socket.foreign.sink.add(
        RelayEnvelope(
          connectionId: 'connection-1',
          payload: RelayWireFrame(
            type: RelayWireFrameType.clientHello,
            payload: utf8.encode(jsonEncode(initiator.hello.toJson())),
          ).encode(),
        ).encode(),
      );
      final iterator = StreamIterator<dynamic>(socket.foreign.stream);
      expect(await iterator.moveNext(), isTrue);
      final responseEnvelope = RelayEnvelope.decode(
        iterator.current! as List<int>,
      );
      final responseFrame = RelayWireFrame.decode(responseEnvelope.payload);
      expect((await pairing.listDevices()).single.lastConnectedAt, isNotNull);
      final responseJson = jsonDecode(utf8.decode(responseFrame.payload));
      final result = await initiator.complete(
        RelayDaemonHello.fromJson(
          Map<String, dynamic>.from(responseJson! as Map),
        ),
        expectedDaemonPublicKey: daemonIdentity.publicKey,
      );
      final outgoing = await RelayCipherState.create(
        sharedSecret: result.sharedSecret,
        transcript: result.transcript,
        direction: RelayDirection.clientToDaemon,
      );
      final incoming = await RelayCipherState.create(
        sharedSecret: result.sharedSecret,
        transcript: result.transcript,
        direction: RelayDirection.daemonToClient,
      );
      const request = '{"jsonrpc":"2.0","id":1,"method":"system.hello"}';
      final encrypted = await outgoing.encrypt(
        fragmentRelayRpcMessage(request).single.encode(),
      );
      socket.foreign.sink.add(
        RelayEnvelope(
          connectionId: 'connection-1',
          payload: RelayWireFrame(
            type: RelayWireFrameType.encryptedRecord,
            payload: encrypted,
          ).encode(),
        ).encode(),
      );
      expect(await rpc.channel!.stream.first, request);

      const response = '{"jsonrpc":"2.0","id":1,"result":{}}';
      rpc.channel!.sink.add(response);
      expect(await iterator.moveNext(), isTrue);
      final encryptedResponse = RelayWireFrame.decode(
        RelayEnvelope.decode(iterator.current! as List<int>).payload,
      );
      final record = RelayRecord.decode(
        await incoming.decrypt(encryptedResponse.payload),
      );
      expect(RelayRpcMessageAssembler().add(record), response);
      await transport.terminateDeviceSessions('phone');
      expect(await iterator.moveNext(), isTrue);
      final terminated = RelayRecord.decode(
        await incoming.decrypt(
          RelayWireFrame.decode(
            RelayEnvelope.decode(iterator.current! as List<int>).payload,
          ).payload,
        ),
      );
      expect(terminated.type, RelayRecordType.close);
      expect(terminated.streamId, 0);
      expect(terminated.payload, isEmpty);
      await iterator.cancel();
      await transport.terminateDeviceSessions('missing-device');
      await transport.close();
      await expectLater(transport.start(), throwsStateError);
    },
  );

  test('streams encrypted relay attachments with bounded credit', () async {
    final clientIdentity = await RelayIdentity.fromSeed(
      List<int>.filled(32, 11),
    );
    final daemonIdentity = await RelayIdentity.fromSeed(
      List<int>.filled(32, 12),
    );
    final pairing = RelayPairingService(
      serverId: 'daemon-attachments',
      relayUri: Uri.parse('wss://relay.example/v1/ws'),
      daemonIdentityPublicKey: daemonIdentity.publicKey,
      devices: MemoryRelayDeviceRepository(),
      clock: const _Clock(),
      ids: const _Ids(),
      randomBytes: (length) => List<int>.filled(length, 13),
    );
    final offer = pairing.createOffer();
    await pairing.registerDevice(
      offerId: offer.offerId,
      offerSecret: offer.secret,
      deviceId: 'tablet',
      deviceName: 'Tablet',
      devicePublicKey: clientIdentity.publicKey,
    );
    final daemonSocket = StreamChannelController<dynamic>(sync: true);
    final clientSocket = StreamChannelController<dynamic>(sync: true);
    final bridge = _RelayBridge(
      daemon: daemonSocket.foreign,
      client: clientSocket.foreign,
    );
    final attachmentHost = _MemoryAttachments();
    final control = RelayControlService(
      enabled: true,
      endpoint: Uri.parse('wss://relay.example/v1/ws'),
      serverId: 'daemon-attachments',
      pairing: pairing,
      applyEnabled: ({required enabled}) async {},
    );
    final transport = DaemonRelayTransport(
      serverId: 'daemon-attachments',
      endpoint: control.endpoint,
      tlsPolicy: RelayTlsPolicy.systemTrust,
      identity: daemonIdentity,
      pairing: pairing,
      rpcSessions: _RpcSessions(expectedDeviceId: 'tablet'),
      attachments: attachmentHost,
      control: control,
      connector: _Connector(daemonSocket.local),
    );
    final relayConnector = RelayWebSocketConnector(
      connection: RelayHostConnection(
        id: 'relay',
        credentialKey: 'relay-key',
        serverId: 'daemon-attachments',
        relayUri: Uri.parse('wss://relay.example/v1/ws'),
        daemonIdentityPublicKey: daemonIdentity.publicKey,
      ),
      credential: RelayHostCredential(
        deviceId: 'tablet',
        privateKey: List<int>.filled(32, 11),
      ),
      socketConnector: _ClientConnector(clientSocket.local),
    );
    addTearDown(() async {
      await transport.close();
      await control.close();
      await bridge.close();
    });
    await transport.start();
    await relayConnector.connect(
      Uri.parse('wss://ignored.example'),
      headers: const <String, String>{},
    );

    const size = 50 * 1024 * 1024;
    final uploaded = await relayConnector
        .upload(
          fileName: 'payload.bin',
          mimeType: 'application/octet-stream',
          byteSize: size,
          bytes: _chunks(size, 0x5a),
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw StateError(
            'upload timed out after ${attachmentHost.uploadedBytes} bytes '
            '(client frames ${bridge.clientFrames}, daemon frames '
            '${bridge.daemonFrames})',
          ),
        );
    expect(uploaded.byteSize, size);
    expect(attachmentHost.uploadedBytes, size);

    final download = await relayConnector
        .download(uploaded.id)
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw StateError('download open timed out'),
        );
    var downloadedBytes = 0;
    await download.bytes
        .forEach((chunk) {
          downloadedBytes += chunk.length;
          expect(chunk, everyElement(0x5a));
        })
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw StateError('download body timed out'),
        );
    expect(downloadedBytes, size);
  });
}

Stream<List<int>> _chunks(int total, int byte) async* {
  const chunkSize = 128 * 1024;
  for (var sent = 0; sent < total; sent += chunkSize) {
    final length = (total - sent).clamp(0, chunkSize);
    yield List<int>.filled(length, byte);
  }
}

final class _RelayBridge {
  new({
    required StreamChannel<dynamic> daemon,
    required StreamChannel<dynamic> client,
  }) : _daemon = daemon,
       _client = client {
    _clientSubscription = client.stream.listen((message) {
      clientFrames += 1;
      daemon.sink.add(
        RelayEnvelope(
          connectionId: 'attachment-connection',
          payload: message! as List<int>,
        ).encode(),
      );
    });
    _daemonSubscription = daemon.stream.listen((message) {
      daemonFrames += 1;
      client.sink.add(RelayEnvelope.decode(message! as List<int>).payload);
    });
  }

  final StreamChannel<dynamic> _daemon;
  final StreamChannel<dynamic> _client;
  late final StreamSubscription<dynamic> _daemonSubscription;
  late final StreamSubscription<dynamic> _clientSubscription;
  int daemonFrames = 0;
  int clientFrames = 0;

  Future<void> close() async {
    await _daemonSubscription.cancel();
    await _clientSubscription.cancel();
    await _daemon.sink.close();
    await _client.sink.close();
  }
}

final class _ClientConnector implements WebSocketConnector {
  const new(this.channel);

  final StreamChannel<dynamic> channel;

  @override
  Future<StreamChannel<dynamic>> connect(
    Uri uri, {
    required Map<String, String> headers,
  }) async => channel;
}

final class _Connector implements DaemonRelaySocketConnector {
  new(this.channel);

  final StreamChannel<dynamic> channel;
  late Uri uri;

  @override
  Future<StreamChannel<dynamic>> connect(
    Uri uri,
    RelayTlsPolicy tlsPolicy,
  ) async {
    this.uri = uri;
    return channel;
  }
}

final class _RpcSessions implements RpcSessionHost {
  new({this.expectedDeviceId = 'phone'});

  final String expectedDeviceId;
  StreamChannel<String>? channel;

  @override
  void openSessionChannel(
    StreamChannel<String> channel, {
    String? relayDeviceId,
  }) {
    expect(relayDeviceId, expectedDeviceId);
    this.channel = channel;
  }

  @override
  Future<void> terminateRelayDeviceSessions(String deviceId) async {}
}

final class _Attachments implements RelayAttachmentHost {
  const new();

  @override
  Future<(RelayAttachment, Stream<List<int>>)> download(String id) =>
      throw UnimplementedError();

  @override
  Future<RelayAttachment> upload({
    required String fileName,
    required String mimeType,
    required int declaredByteSize,
    required Stream<List<int>> bytes,
  }) => throw UnimplementedError();
}

final class _MemoryAttachments implements RelayAttachmentHost {
  int uploadedBytes = 0;

  @override
  Future<(RelayAttachment, Stream<List<int>>)> download(String id) async =>
      (_dto(id, uploadedBytes), _chunks(uploadedBytes, 0x5a));

  @override
  Future<RelayAttachment> upload({
    required String fileName,
    required String mimeType,
    required int declaredByteSize,
    required Stream<List<int>> bytes,
  }) async {
    await for (final chunk in bytes) {
      uploadedBytes += chunk.length;
    }
    if (uploadedBytes != declaredByteSize) {
      throw const FormatException('Upload size mismatch.');
    }
    return _dto('attachment-1', uploadedBytes);
  }

  RelayAttachment _dto(String id, int byteSize) => RelayAttachment(
    id: id,
    fileName: 'payload.bin',
    mimeType: 'application/octet-stream',
    byteSize: byteSize,
    kind: AttachmentKind.file.name,
    sha256: 'test-sha256',
    createdAt: DateTime.utc(2026, 8, 8),
  );
}

final class _Clock implements Clock {
  const new();

  @override
  DateTime nowUtc() => DateTime.utc(2026, 8, 8);
}

final class _Ids implements IdGenerator {
  const new();

  @override
  String generate() => 'offer-1';
}
