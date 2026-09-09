import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:client/src/api.dart';
import 'package:client/src/attachment_transport.dart';
import 'package:client/src/connection.dart';
import 'package:client/src/web_socket_connector.dart';
import 'package:protocol/protocol.dart';
import 'package:relay_protocol/relay_protocol.dart';
import 'package:stream_channel/stream_channel.dart';

/// Opens an end-to-end encrypted JSON-RPC channel through a relay socket.
final class RelayWebSocketConnector
    implements WebSocketConnector, AttachmentTransport {
  /// Creates a connector for one daemon-scoped device identity.
  new({
    required this.connection,
    required this.credential,
    WebSocketConnector? socketConnector,
  }) : socketConnector = socketConnector ?? createWebSocketConnector();

  /// Pinned relay path and daemon identity.
  final RelayHostConnection connection;

  /// Device private identity loaded from secure storage.
  final RelayHostCredential credential;

  /// Platform WebSocket connector used for the outer binary socket.
  final WebSocketConnector socketConnector;
  _RelayClientChannel? _session;

  @override
  Future<StreamChannel<dynamic>> connect(
    Uri _, {
    required Map<String, String> headers,
  }) async {
    final relayUri = connection.relayUri.replace(
      queryParameters: <String, String>{
        ...connection.relayUri.queryParameters,
        'role': 'client',
        'serverId': connection.serverId,
      },
    );
    final raw = await socketConnector.connect(
      relayUri,
      headers: const <String, String>{},
    );
    final iterator = StreamIterator<dynamic>(raw.stream);
    final identity = await RelayIdentity.fromSeed(credential.privateKey);
    final initiator = await RelayHandshakeInitiator.start(
      serverId: connection.serverId,
      sessionId: _randomId(),
      deviceId: credential.deviceId,
      identity: identity,
    );
    raw.sink.add(
      RelayWireFrame(
        type: RelayWireFrameType.clientHello,
        payload: utf8.encode(jsonEncode(initiator.hello.toJson())),
      ).encode(),
    );
    final received = await iterator.moveNext().timeout(
      const Duration(seconds: 10),
    );
    if (!received || iterator.current is! List<int>) {
      await raw.sink.close();
      throw const RelaySecurityException(
        'Relay handshake response is missing.',
      );
    }
    final frame = RelayWireFrame.decode(iterator.current! as List<int>);
    if (frame.type != RelayWireFrameType.daemonHello) {
      await raw.sink.close();
      throw const RelaySecurityException(
        'Relay handshake response is invalid.',
      );
    }
    final decoded = jsonDecode(utf8.decode(frame.payload));
    if (decoded is! Map<String, dynamic>) {
      await raw.sink.close();
      throw const RelaySecurityException('Daemon hello is malformed.');
    }
    final result = await initiator.complete(
      RelayDaemonHello.fromJson(decoded),
      expectedDaemonPublicKey: connection.daemonIdentityPublicKey,
    );
    final session = await _RelayClientChannel.create(
      raw: raw,
      iterator: iterator,
      handshake: result,
    );
    _session = session;
    return session.channel;
  }

  _RelayClientChannel get _activeSession =>
      _session ??
      (throw StateError('The encrypted relay session is not connected.'));

  @override
  Future<AttachmentDto> upload({
    required String fileName,
    required String mimeType,
    required int byteSize,
    required Stream<List<int>> bytes,
  }) => _activeSession.upload(
    fileName: fileName,
    mimeType: mimeType,
    byteSize: byteSize,
    bytes: bytes,
  );

  @override
  Future<AttachmentDownload> download(String id) => _activeSession.download(id);
}

final class _RelayClientChannel {
  new _({
    required this._raw,
    required this._iterator,
    required this._incoming,
    required this._outgoing,
  }) {
    channel = StreamChannel<dynamic>(_incomingMessages.stream, _outbound.sink);
    _outgoingSubscription = _outbound.stream.listen(
      _queueSend,
      onDone: () => unawaited(_close()),
    );
    unawaited(_read());
  }

  static Future<_RelayClientChannel> create({
    required StreamChannel<dynamic> raw,
    required StreamIterator<dynamic> iterator,
    required RelayHandshakeResult handshake,
  }) async {
    final session = _RelayClientChannel._(
      raw: raw,
      iterator: iterator,
      incoming: await RelayCipherState.create(
        sharedSecret: handshake.sharedSecret,
        transcript: handshake.transcript,
        direction: RelayDirection.daemonToClient,
      ),
      outgoing: await RelayCipherState.create(
        sharedSecret: handshake.sharedSecret,
        transcript: handshake.transcript,
        direction: RelayDirection.clientToDaemon,
      ),
    );
    return session;
  }

  final StreamChannel<dynamic> _raw;
  final StreamIterator<dynamic> _iterator;
  final RelayCipherState _incoming;
  final RelayCipherState _outgoing;
  final RelayRpcMessageAssembler _assembler = RelayRpcMessageAssembler();
  final Map<int, StreamController<RelayRecord>> _attachmentStreams =
      <int, StreamController<RelayRecord>>{};
  final StreamController<dynamic> _incomingMessages =
      StreamController<dynamic>();
  final StreamController<dynamic> _outbound = StreamController<dynamic>();
  late final StreamSubscription<dynamic> _outgoingSubscription;
  late final StreamChannel<dynamic> channel;
  Future<void> _sendQueue = Future<void>.value();
  int _nextStreamId = 1;
  bool _closed = false;

  Future<void> _read() async {
    try {
      while (await _iterator.moveNext()) {
        final message = _iterator.current;
        if (message is! List<int>) {
          throw const RelaySecurityException('Relay sent a non-binary frame.');
        }
        final frame = RelayWireFrame.decode(message);
        if (frame.type != RelayWireFrameType.encryptedRecord) {
          throw const RelaySecurityException('Unexpected relay frame type.');
        }
        final plaintext = await _incoming.decrypt(frame.payload);
        final record = RelayRecord.decode(plaintext);
        if (record.type == RelayRecordType.close &&
            record.streamId == 0 &&
            record.payload.isEmpty) {
          return;
        }
        if (record.type == RelayRecordType.rpc) {
          final complete = _assembler.add(record);
          if (complete != null) {
            _incomingMessages.add(complete);
          }
        } else {
          final stream = _attachmentStreams[record.streamId];
          if (stream == null) {
            throw const RelaySecurityException(
              'Received an unknown attachment stream.',
            );
          }
          stream.add(record);
        }
      }
    } on Object catch (error, stackTrace) {
      _incomingMessages.addError(error, stackTrace);
    } finally {
      await _close();
    }
  }

  void _queueSend(dynamic message) {
    if (message is! String) {
      _outbound.addError(
        const RelaySecurityException(
          'JSON-RPC relay messages must be strings.',
        ),
      );
      return;
    }
    _sendQueue = _sendQueue
        .then((_) async {
          for (final record in fragmentRelayRpcMessage(message)) {
            await _sendRecordNow(record);
          }
        })
        .onError((_, _) {
          unawaited(_close());
        });
  }

  Future<void> _sendRecord(RelayRecord record) {
    final completed = Completer<void>();
    _sendQueue = _sendQueue
        .then((_) => _sendRecordNow(record))
        .then(completed.complete)
        .onError((error, stackTrace) {
          completed.completeError(
            error ?? StateError('Relay record send failed.'),
            stackTrace as StackTrace?,
          );
          unawaited(_close());
        });
    return completed.future;
  }

  Future<void> _sendRecordNow(RelayRecord record) async {
    final encrypted = await _outgoing.encrypt(record.encode());
    _raw.sink.add(
      RelayWireFrame(
        type: RelayWireFrameType.encryptedRecord,
        payload: encrypted,
      ).encode(),
    );
  }

  Future<AttachmentDto> upload({
    required String fileName,
    required String mimeType,
    required int byteSize,
    required Stream<List<int>> bytes,
  }) async {
    final streamId = _allocateStream();
    final events = _attachmentStreams[streamId]!;
    final iterator = StreamIterator<RelayRecord>(events.stream);
    try {
      await _sendRecord(
        RelayRecord(
          type: RelayRecordType.attachmentOpen,
          streamId: streamId,
          payload: RelayAttachmentOpen.upload(
            fileName: fileName,
            mimeType: mimeType,
            byteSize: byteSize,
          ).encode(),
        ),
      );
      var credit = 0;
      await for (final sourceChunk in bytes) {
        var offset = 0;
        while (offset < sourceChunk.length) {
          while (credit == 0) {
            final record = await _next(iterator);
            if (record.type != RelayRecordType.attachmentCredit) {
              throw const RelaySecurityException('Upload credit is missing.');
            }
            credit += decodeRelayAttachmentCredit(record.payload);
          }
          final count = <int>[
            sourceChunk.length - offset,
            maxRelayAttachmentChunkBytes,
            credit,
          ].reduce((a, b) => a < b ? a : b);
          await _sendRecord(
            RelayRecord(
              type: RelayRecordType.attachmentData,
              streamId: streamId,
              payload: sourceChunk.sublist(offset, offset + count),
            ),
          );
          offset += count;
          credit -= count;
        }
      }
      await _sendRecord(
        RelayRecord(
          type: RelayRecordType.close,
          streamId: streamId,
          payload: const <int>[],
        ),
      );
      while (true) {
        final record = await _next(iterator);
        if (record.type == RelayRecordType.attachmentCredit) {
          continue;
        }
        if (record.type != RelayRecordType.close) {
          throw const RelaySecurityException('Upload response is invalid.');
        }
        final result = _decodeResult(record.payload);
        return AttachmentDto.fromJson(
          Map<String, dynamic>.from(result['attachment']! as Map),
        );
      }
    } finally {
      await iterator.cancel();
      await _removeStream(streamId);
    }
  }

  Future<AttachmentDownload> download(String id) async {
    final streamId = _allocateStream();
    final events = _attachmentStreams[streamId]!;
    final iterator = StreamIterator<RelayRecord>(events.stream);
    await _sendRecord(
      RelayRecord(
        type: RelayRecordType.attachmentOpen,
        streamId: streamId,
        payload: RelayAttachmentOpen.download(attachmentId: id).encode(),
      ),
    );
    await _sendRecord(
      RelayRecord(
        type: RelayRecordType.attachmentCredit,
        streamId: streamId,
        payload: encodeRelayAttachmentCredit(relayAttachmentCreditWindowBytes),
      ),
    );
    final opened = await _next(iterator);
    if (opened.type != RelayRecordType.attachmentOpen) {
      await iterator.cancel();
      await _removeStream(streamId);
      throw const RelaySecurityException('Download metadata is missing.');
    }
    final metadata = AttachmentDto.fromJson(
      Map<String, dynamic>.from(
        _decodeResult(opened.payload)['attachment']! as Map,
      ),
    );
    return AttachmentDownload(
      fileName: metadata.fileName,
      mimeType: metadata.mimeType,
      byteSize: metadata.byteSize,
      bytes: _downloadBytes(streamId, iterator),
    );
  }

  Stream<List<int>> _downloadBytes(
    int streamId,
    StreamIterator<RelayRecord> iterator,
  ) async* {
    try {
      while (true) {
        final record = await _next(iterator);
        if (record.type == RelayRecordType.close) {
          _decodeResult(record.payload);
          return;
        }
        if (record.type != RelayRecordType.attachmentData) {
          throw const RelaySecurityException('Download record is invalid.');
        }
        yield record.payload;
        await _sendRecord(
          RelayRecord(
            type: RelayRecordType.attachmentCredit,
            streamId: streamId,
            payload: encodeRelayAttachmentCredit(record.payload.length),
          ),
        );
      }
    } finally {
      await iterator.cancel();
      await _removeStream(streamId);
    }
  }

  int _allocateStream() {
    final id = _nextStreamId;
    _nextStreamId += 2;
    _attachmentStreams[id] = StreamController<RelayRecord>();
    return id;
  }

  Future<void> _removeStream(int streamId) async {
    await _attachmentStreams.remove(streamId)?.close();
  }

  Future<RelayRecord> _next(StreamIterator<RelayRecord> iterator) async {
    if (!await iterator.moveNext().timeout(const Duration(seconds: 60))) {
      throw const RelaySecurityException('Attachment stream closed early.');
    }
    return iterator.current;
  }

  Map<String, dynamic> _decodeResult(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const RelaySecurityException('Attachment result is malformed.');
    }
    if (decoded['error'] case final String message) {
      throw RelaySecurityException(message);
    }
    return decoded;
  }

  Future<void> _close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _iterator.cancel();
    await _outgoingSubscription.cancel();
    await _outbound.close();
    await _incomingMessages.close();
    for (final stream in _attachmentStreams.values) {
      await stream.close();
    }
    _attachmentStreams.clear();
    await _raw.sink.close();
  }
}

String _randomId() {
  final random = Random.secure();
  final bytes = List<int>.generate(
    16,
    (_) => random.nextInt(256),
    growable: false,
  );
  return base64UrlEncode(bytes).replaceAll('=', '');
}
