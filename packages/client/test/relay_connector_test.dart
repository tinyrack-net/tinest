import 'dart:async';
import 'dart:convert';

import 'package:client/client.dart';
import 'package:protocol/protocol.dart';
import 'package:relay_protocol/relay_protocol.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

void main() {
  test('encrypted relay carries RPC and both attachment directions', () async {
    final device = await RelayIdentity.fromSeed(List<int>.filled(32, 1));
    final daemon = await RelayIdentity.fromSeed(List<int>.filled(32, 2));
    final harness = _RelayDaemonHarness(
      daemonIdentity: daemon,
      devicePublicKey: device.publicKey,
    );
    final connector = RelayWebSocketConnector(
      connection: RelayHostConnection(
        id: 'relay',
        credentialKey: 'relay-key',
        serverId: 'daemon-1',
        relayUri: Uri.parse('wss://relay.example/v1/ws'),
        daemonIdentityPublicKey: daemon.publicKey,
      ),
      credential: RelayHostCredential(
        deviceId: 'phone',
        privateKey: List<int>.filled(32, 1),
      ),
      socketConnector: harness,
    );

    expect(
      () => connector.download('before-connect'),
      throwsA(isA<StateError>()),
    );
    final channel = await connector.connect(
      Uri(),
      headers: const <String, String>{'authorization': 'ignored'},
    );
    expect(harness.connectedUri.queryParameters, <String, String>{
      'role': 'client',
      'serverId': 'daemon-1',
    });

    channel.sink.add('{"jsonrpc":"2.0"}');
    expect(await channel.stream.first, '{"jsonrpc":"2.0"}');

    final uploaded = await connector.upload(
      fileName: 'notes.txt',
      mimeType: 'text/plain',
      byteSize: 5,
      bytes: Stream<List<int>>.fromIterable(const <List<int>>[
        <int>[1, 2],
        <int>[3, 4, 5],
      ]),
    );
    expect(uploaded.id, 'uploaded');
    expect(harness.uploaded, <int>[1, 2, 3, 4, 5]);

    final download = await connector.download('downloaded');
    expect(download.fileName, 'download.bin');
    expect(await download.bytes.expand((chunk) => chunk).toList(), <int>[
      9,
      8,
      7,
    ]);
    await channel.sink.close();
  });

  test('relay handshake rejects missing and wrong response frames', () async {
    final daemon = await RelayIdentity.fromSeed(List<int>.filled(32, 2));
    RelayWebSocketConnector connector(WebSocketConnector socket) =>
        RelayWebSocketConnector(
          connection: RelayHostConnection(
            id: 'relay',
            credentialKey: 'relay-key',
            serverId: 'daemon-1',
            relayUri: Uri.parse('wss://relay.example/v1/ws'),
            daemonIdentityPublicKey: daemon.publicKey,
          ),
          credential: RelayHostCredential(
            deviceId: 'phone',
            privateKey: List<int>.filled(32, 1),
          ),
          socketConnector: socket,
        );

    await expectLater(
      connector(const _HandshakeResponseConnector())
          .connect(Uri(), headers: const <String, String>{}),
      throwsA(isA<RelaySecurityException>()),
    );
    await expectLater(
      connector(
        _HandshakeResponseConnector(
          response: RelayWireFrame(
            type: RelayWireFrameType.pairingAccepted,
            payload: const <int>[],
          ).encode(),
        ),
      ).connect(Uri(), headers: const <String, String>{}),
      throwsA(isA<RelaySecurityException>()),
    );
    await expectLater(
      connector(
        _HandshakeResponseConnector(
          response: RelayWireFrame(
            type: RelayWireFrameType.daemonHello,
            payload: utf8.encode('[]'),
          ).encode(),
        ),
      ).connect(Uri(), headers: const <String, String>{}),
      throwsA(isA<RelaySecurityException>()),
    );
  });

  test('authenticated session close ends the inner RPC channel', () async {
    final device = await RelayIdentity.fromSeed(List<int>.filled(32, 1));
    final daemon = await RelayIdentity.fromSeed(List<int>.filled(32, 2));
    final connector = RelayWebSocketConnector(
      connection: RelayHostConnection(
        id: 'relay',
        credentialKey: 'relay-key',
        serverId: 'daemon-1',
        relayUri: Uri.parse('wss://relay.example/v1/ws'),
        daemonIdentityPublicKey: daemon.publicKey,
      ),
      credential: RelayHostCredential(
        deviceId: 'phone',
        privateKey: List<int>.filled(32, 1),
      ),
      socketConnector: _RelayDaemonHarness(
        daemonIdentity: daemon,
        devicePublicKey: device.publicKey,
        terminateAfterHandshake: true,
      ),
    );

    final channel = await connector.connect(
      Uri(),
      headers: const <String, String>{},
    );

    await expectLater(channel.stream, emitsDone);
  });
}

final class _HandshakeResponseConnector implements WebSocketConnector {
  const new({this.response});

  final List<int>? response;

  @override
  Future<StreamChannel<dynamic>> connect(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    final socket = StreamChannelController<dynamic>(sync: true);
    unawaited(
      socket.foreign.stream.first.then((_) async {
        if (response case final response?) {
          socket.foreign.sink.add(response);
        } else {
          await socket.foreign.sink.close();
        }
      }),
    );
    return socket.local;
  }
}

final class _RelayDaemonHarness implements WebSocketConnector {
  new({
    required this.daemonIdentity,
    required this.devicePublicKey,
    this.terminateAfterHandshake = false,
  });

  final RelayIdentity daemonIdentity;
  final List<int> devicePublicKey;
  final bool terminateAfterHandshake;
  final List<int> uploaded = <int>[];
  late Uri connectedUri;

  @override
  Future<StreamChannel<dynamic>> connect(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    connectedUri = uri;
    final socket = StreamChannelController<dynamic>(sync: true);
    unawaited(_serve(socket.foreign));
    return socket.local;
  }

  Future<void> _serve(StreamChannel<dynamic> socket) async {
    final iterator = StreamIterator<dynamic>(socket.stream);
    await iterator.moveNext();
    final first = RelayWireFrame.decode(iterator.current! as List<int>);
    final hello = RelayClientHello.fromJson(
      jsonDecode(utf8.decode(first.payload))! as Map<String, dynamic>,
    );
    final response = await RelayHandshakeResponder.respond(
      hello: hello,
      expectedServerId: 'daemon-1',
      approvedDevicePublicKey: devicePublicKey,
      identity: daemonIdentity,
      ephemeralSeed: List<int>.filled(32, 3),
    );
    socket.sink.add(
      RelayWireFrame(
        type: RelayWireFrameType.daemonHello,
        payload: utf8.encode(jsonEncode(response.hello.toJson())),
      ).encode(),
    );
    final incoming = await RelayCipherState.create(
      sharedSecret: response.result.sharedSecret,
      transcript: response.result.transcript,
      direction: RelayDirection.clientToDaemon,
    );
    final outgoing = await RelayCipherState.create(
      sharedSecret: response.result.sharedSecret,
      transcript: response.result.transcript,
      direction: RelayDirection.daemonToClient,
    );
    if (terminateAfterHandshake) {
      await _send(
        socket,
        outgoing,
        RelayRecord(
          type: RelayRecordType.close,
          streamId: 0,
          payload: const <int>[],
        ),
      );
      return;
    }
    while (await iterator.moveNext()) {
      final frame = RelayWireFrame.decode(iterator.current! as List<int>);
      final record = RelayRecord.decode(await incoming.decrypt(frame.payload));
      switch (record.type) {
        case RelayRecordType.rpc:
          await _send(socket, outgoing, record);
        case RelayRecordType.attachmentOpen:
          final open = RelayAttachmentOpen.decode(record.payload);
          if (open.operation == RelayAttachmentOperation.upload) {
            await _send(
              socket,
              outgoing,
              RelayRecord(
                type: RelayRecordType.attachmentCredit,
                streamId: record.streamId,
                payload: encodeRelayAttachmentCredit(
                  relayAttachmentCreditWindowBytes,
                ),
              ),
            );
          } else {
            await _send(
              socket,
              outgoing,
              RelayRecord(
                type: RelayRecordType.attachmentOpen,
                streamId: record.streamId,
                payload: utf8.encode(
                  jsonEncode(<String, Object>{
                    'attachment': _metadata(
                      id: open.attachmentId!,
                      fileName: 'download.bin',
                      byteSize: 3,
                    ),
                  }),
                ),
              ),
            );
          }
        case RelayRecordType.attachmentData:
          uploaded.addAll(record.payload);
        case RelayRecordType.attachmentCredit:
          await _send(
            socket,
            outgoing,
            RelayRecord(
              type: RelayRecordType.attachmentData,
              streamId: record.streamId,
              payload: const <int>[9, 8, 7],
            ),
          );
          await _send(
            socket,
            outgoing,
            RelayRecord(
              type: RelayRecordType.close,
              streamId: record.streamId,
              payload: utf8.encode(jsonEncode(<String, bool>{'ok': true})),
            ),
          );
        case RelayRecordType.close:
          await _send(
            socket,
            outgoing,
            RelayRecord(
              type: RelayRecordType.close,
              streamId: record.streamId,
              payload: utf8.encode(
                jsonEncode(<String, Object>{
                  'attachment': _metadata(
                    id: 'uploaded',
                    fileName: 'notes.txt',
                    byteSize: uploaded.length,
                  ),
                }),
              ),
            ),
          );
      }
    }
  }

  Future<void> _send(
    StreamChannel<dynamic> socket,
    RelayCipherState cipher,
    RelayRecord record,
  ) async {
    socket.sink.add(
      RelayWireFrame(
        type: RelayWireFrameType.encryptedRecord,
        payload: await cipher.encrypt(record.encode()),
      ).encode(),
    );
  }

  Map<String, Object> _metadata({
    required String id,
    required String fileName,
    required int byteSize,
  }) => <String, Object>{
    'id': id,
    'fileName': fileName,
    'mimeType': 'application/octet-stream',
    'byteSize': byteSize,
    'kind': AttachmentKind.file.name,
    'sha256': 'sha256',
    'createdAt': DateTime.utc(2026, 8, 8).toIso8601String(),
  };
}
