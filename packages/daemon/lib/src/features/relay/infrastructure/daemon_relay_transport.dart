import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:daemon/src/bootstrap/config.dart';
import 'package:daemon/src/features/relay/application/relay_control_service.dart';
import 'package:daemon/src/features/relay/application/relay_pairing_service.dart';
import 'package:daemon/src/features/relay/application/relay_ports.dart';
import 'package:daemon/src/transport/rpc/session_host.dart';
import 'package:relay_protocol/relay_protocol.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/io.dart';

/// Opens the daemon's outbound relay control WebSocket.
abstract interface class DaemonRelaySocketConnector {
  /// Connects with bounded handshake time and WebSocket keepalive.
  Future<StreamChannel<dynamic>> connect(Uri uri, RelayTlsPolicy tlsPolicy);
}

/// Native WebSocket connector with an explicit self-hosted TLS override.
final class IoDaemonRelaySocketConnector implements DaemonRelaySocketConnector {
  /// Creates the native connector.
  const new();

  @override
  Future<StreamChannel<dynamic>> connect(
    Uri uri,
    RelayTlsPolicy tlsPolicy,
  ) async {
    HttpClient? client;
    if (tlsPolicy == RelayTlsPolicy.allowInvalidCertificate) {
      client = HttpClient()..badCertificateCallback = (_, _, _) => true;
    }
    final channel = IOWebSocketChannel.connect(
      uri,
      pingInterval: const Duration(seconds: 10),
      connectTimeout: const Duration(seconds: 10),
      customClient: client,
    );
    await channel.ready;
    return channel;
  }
}

/// Bridges encrypted relay envelopes into the daemon's typed RPC session port.
final class DaemonRelayTransport {
  /// Creates an outbound relay adapter.
  new({
    required this.serverId,
    required this.endpoint,
    required this.tlsPolicy,
    required this.identity,
    required this.pairing,
    required this.rpcSessions,
    required this.attachments,
    required this.control,
    this.connector = const IoDaemonRelaySocketConnector(),
  });

  /// Authoritative daemon identity used by relay routing.
  final String serverId;

  /// Relay WebSocket endpoint.
  Uri endpoint;

  /// TLS validation mode.
  final RelayTlsPolicy tlsPolicy;

  /// Persistent daemon Ed25519 identity.
  final RelayIdentity identity;

  /// Approved-device lookup service.
  final RelayPairingService pairing;

  /// Shared daemon JSON-RPC session binding.
  final RpcSessionHost rpcSessions;

  /// Shared attachment application service.
  final RelayAttachmentHost attachments;

  /// Relay status publisher.
  final RelayControlService control;

  /// Outbound WebSocket connector port.
  final DaemonRelaySocketConnector connector;

  final Map<String, _DaemonRelaySession> _sessions =
      <String, _DaemonRelaySession>{};
  StreamChannel<dynamic>? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  bool _enabled = false;
  bool _closed = false;
  int _attempt = 0;

  /// Enables the reconnecting outbound control connection.
  Future<void> start() async {
    if (_closed) {
      throw StateError('Relay transport is closed.');
    }
    _enabled = true;
    unawaited(_connect());
  }

  /// Disables relay operation and closes all encrypted sessions.
  Future<void> stop() async {
    _enabled = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    for (final session in _sessions.values.toList()) {
      await session.close();
    }
    _sessions.clear();
    control.setConnected(connected: false);
  }

  /// Reconnects an enabled transport through [value].
  Future<void> setEndpoint(Uri value) async {
    if (endpoint == value) return;
    final restart = _enabled;
    await stop();
    endpoint = value;
    if (restart) await start();
  }

  /// Terminates encrypted transport state for a revoked device.
  Future<void> terminateDeviceSessions(String deviceId) async {
    final matches = _sessions.entries
        .where((entry) => entry.value.deviceId == deviceId)
        .toList(growable: false);
    for (final entry in matches) {
      _sessions.remove(entry.key);
      await entry.value.terminate();
    }
  }

  /// Permanently closes the transport.
  Future<void> close() async {
    _closed = true;
    await stop();
  }

  Future<void> _connect() async {
    if (!_enabled || _closed || _channel != null) {
      return;
    }
    try {
      final uri = endpoint.replace(
        queryParameters: <String, String>{
          ...endpoint.queryParameters,
          'role': 'daemon',
          'serverId': serverId,
        },
      );
      final channel = await connector.connect(uri, tlsPolicy);
      if (!_enabled || _closed) {
        await channel.sink.close();
        return;
      }
      _channel = channel;
      _attempt = 0;
      control.setConnected(connected: true);
      _subscription = channel.stream.listen(
        _onMessage,
        onError: (_, _) => _disconnected(),
        onDone: _disconnected,
      );
    } on Exception {
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic message) {
    if (message is! List<int>) {
      unawaited(_channel?.sink.close());
      return;
    }
    RelayEnvelope envelope;
    try {
      envelope = RelayEnvelope.decode(message);
    } on FormatException {
      unawaited(_channel?.sink.close());
      return;
    }
    final existing = _sessions[envelope.connectionId];
    if (existing == null) {
      unawaited(_accept(envelope));
    } else {
      unawaited(
        existing.receive(envelope.payload).onError((_, _) async {
          _sessions.remove(envelope.connectionId);
          await existing.close();
        }),
      );
    }
  }

  Future<void> _accept(RelayEnvelope envelope) async {
    try {
      final frame = RelayWireFrame.decode(envelope.payload);
      if (frame.type == RelayWireFrameType.pairingRequest) {
        final request = RelayPairingRegistrationRequest.decode(frame.payload);
        final registration = await pairing.registerEncrypted(request);
        await _send(
          envelope.connectionId,
          RelayWireFrame(
            type: RelayWireFrameType.pairingAccepted,
            payload: await encryptRelayPairingAccepted(
              serverId: serverId,
              offerId: request.offerId,
              offerSecret: registration.offerSecret,
              deviceId: registration.device.id,
            ),
          ).encode(),
        );
        return;
      }
      if (frame.type != RelayWireFrameType.clientHello) {
        throw const RelaySecurityException('Relay handshake is required.');
      }
      final decoded = jsonDecode(utf8.decode(frame.payload));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Client hello must be an object.');
      }
      final hello = RelayClientHello.fromJson(decoded);
      final device = await pairing.findDevice(hello.deviceId);
      if (device == null) {
        throw const RelaySecurityException('Relay device is not approved.');
      }
      final response = await RelayHandshakeResponder.respond(
        hello: hello,
        expectedServerId: serverId,
        approvedDevicePublicKey: device.publicKey,
        identity: identity,
      ).timeout(const Duration(seconds: 10));
      final session = await _DaemonRelaySession.create(
        connectionId: envelope.connectionId,
        deviceId: device.id,
        handshake: response.result,
        send: _send,
        attachments: attachments,
        onClosed: () => _sessions.remove(envelope.connectionId),
      );
      _sessions[envelope.connectionId] = session;
      await pairing.markDeviceConnected(device);
      await _send(
        envelope.connectionId,
        RelayWireFrame(
          type: RelayWireFrameType.daemonHello,
          payload: utf8.encode(jsonEncode(response.hello.toJson())),
        ).encode(),
      );
      rpcSessions.openSessionChannel(session.channel, relayDeviceId: device.id);
    } on Object {
      final session = _sessions.remove(envelope.connectionId);
      await session?.close();
    }
  }

  Future<void> _send(String connectionId, Uint8List payload) async {
    final channel = _channel;
    if (channel == null) {
      throw StateError('Relay control connection is offline.');
    }
    channel.sink.add(
      RelayEnvelope(connectionId: connectionId, payload: payload).encode(),
    );
  }

  void _disconnected() {
    _channel = null;
    _subscription = null;
    control.setConnected(connected: false);
    for (final session in _sessions.values.toList()) {
      unawaited(session.close());
    }
    _sessions.clear();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_enabled || _closed || _reconnectTimer != null) {
      return;
    }
    _attempt += 1;
    final seconds = 1 << (_attempt - 1).clamp(0, 5);
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      _reconnectTimer = null;
      unawaited(_connect());
    });
  }
}

typedef _RelayFrameSender = Future<void> Function(
  String connectionId,
  Uint8List payload,
);

final class _DaemonRelaySession {
  new _({
    required this.connectionId,
    required this.deviceId,
    required this._incoming,
    required this._outgoing,
    required this._send,
    required this._attachments,
    required this.onClosed,
  }) {
    channel = StreamChannel<String>(_messages.stream, _outbound.sink);
    _outboundSubscription = _outbound.stream.listen(
      _queueSend,
      onDone: () => unawaited(close()),
    );
  }

  static Future<_DaemonRelaySession> create({
    required String connectionId,
    required String deviceId,
    required RelayHandshakeResult handshake,
    required _RelayFrameSender send,
    required RelayAttachmentHost attachments,
    required void Function() onClosed,
  }) async => _DaemonRelaySession._(
    connectionId: connectionId,
    deviceId: deviceId,
    incoming: await RelayCipherState.create(
      sharedSecret: handshake.sharedSecret,
      transcript: handshake.transcript,
      direction: RelayDirection.clientToDaemon,
    ),
    outgoing: await RelayCipherState.create(
      sharedSecret: handshake.sharedSecret,
      transcript: handshake.transcript,
      direction: RelayDirection.daemonToClient,
    ),
    send: send,
    attachments: attachments,
    onClosed: onClosed,
  );

  final String connectionId;
  final String deviceId;
  final RelayCipherState _incoming;
  final RelayCipherState _outgoing;
  final _RelayFrameSender _send;
  final RelayAttachmentHost _attachments;
  final void Function() onClosed;
  final RelayRpcMessageAssembler _assembler = RelayRpcMessageAssembler();
  final Map<int, _DaemonUpload> _uploads = <int, _DaemonUpload>{};
  final Map<int, _DaemonDownload> _downloads = <int, _DaemonDownload>{};
  final StreamController<String> _messages = StreamController<String>();
  final StreamController<String> _outbound = StreamController<String>();
  late final StreamSubscription<String> _outboundSubscription;
  late final StreamChannel<String> channel;
  Future<void> _sendQueue = Future<void>.value();
  Future<void> _receiveQueue = Future<void>.value();
  bool _closed = false;

  Future<void> receive(List<int> bytes) {
    return _receiveQueue = _receiveQueue.then((_) => _receive(bytes));
  }

  Future<void> _receive(List<int> bytes) async {
    if (_closed) {
      return;
    }
    final frame = RelayWireFrame.decode(bytes);
    if (frame.type != RelayWireFrameType.encryptedRecord) {
      throw const RelaySecurityException('Unexpected relay frame type.');
    }
    final plaintext = await _incoming.decrypt(frame.payload);
    final record = RelayRecord.decode(plaintext);
    switch (record.type) {
      case RelayRecordType.rpc:
        final message = _assembler.add(record);
        if (message != null) {
          _messages.add(message);
        }
      case RelayRecordType.attachmentOpen:
        await _openAttachment(record);
      case RelayRecordType.attachmentData:
        final upload = _uploads[record.streamId];
        if (upload == null) {
          throw const RelaySecurityException('Unknown relay upload stream.');
        }
        upload.add(record.payload);
      case RelayRecordType.attachmentCredit:
        final download = _downloads[record.streamId];
        if (download == null) {
          throw const RelaySecurityException('Unknown relay download stream.');
        }
        download.addCredit(decodeRelayAttachmentCredit(record.payload));
      case RelayRecordType.close:
        final upload = _uploads.remove(record.streamId);
        if (upload == null || record.payload.isNotEmpty) {
          throw const RelaySecurityException('Unknown relay stream close.');
        }
        await upload.finish();
    }
  }

  Future<void> _openAttachment(RelayRecord record) async {
    if (record.streamId == 0 ||
        _uploads.containsKey(record.streamId) ||
        _downloads.containsKey(record.streamId)) {
      throw const RelaySecurityException('Attachment stream ID is invalid.');
    }
    final open = RelayAttachmentOpen.decode(record.payload);
    switch (open.operation) {
      case RelayAttachmentOperation.upload:
        final upload = _DaemonUpload(
          streamId: record.streamId,
          open: open,
          attachments: _attachments,
          send: _sendRecord,
          onDone: () => _uploads.remove(record.streamId),
        );
        _uploads[record.streamId] = upload;
        await upload.start();
      case RelayAttachmentOperation.download:
        final download = await _DaemonDownload.create(
          streamId: record.streamId,
          attachmentId: open.attachmentId!,
          attachments: _attachments,
          send: _sendRecord,
          onDone: () => _downloads.remove(record.streamId),
        );
        _downloads[record.streamId] = download;
        unawaited(download.start());
    }
  }

  void _queueSend(String message) {
    _sendQueue = _sendQueue
        .then((_) async {
          for (final record in fragmentRelayRpcMessage(message)) {
            await _sendRecordNow(record);
          }
        })
        .onError((_, _) {
          unawaited(close());
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
          unawaited(close());
        });
    return completed.future;
  }

  Future<void> _sendRecordNow(RelayRecord record) async {
    final encrypted = await _outgoing.encrypt(record.encode());
    await _send(
      connectionId,
      RelayWireFrame(
        type: RelayWireFrameType.encryptedRecord,
        payload: encrypted,
      ).encode(),
    );
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    onClosed();
    for (final upload in _uploads.values.toList()) {
      await upload.cancel();
    }
    _uploads.clear();
    for (final download in _downloads.values.toList()) {
      await download.cancel();
    }
    _downloads.clear();
    await _outboundSubscription.cancel();
    await _outbound.close();
    await _messages.close();
  }

  Future<void> terminate() async {
    if (_closed) {
      return;
    }
    try {
      await _sendRecord(
        RelayRecord(
          type: RelayRecordType.close,
          streamId: 0,
          payload: const <int>[],
        ),
      );
    } finally {
      await close();
    }
  }
}

typedef _AttachmentRecordSender = Future<void> Function(RelayRecord record);

final class _DaemonUpload {
  new({
    required this.streamId,
    required this.open,
    required this.attachments,
    required this.send,
    required this.onDone,
  });

  final int streamId;
  final RelayAttachmentOpen open;
  final RelayAttachmentHost attachments;
  final _AttachmentRecordSender send;
  final void Function() onDone;
  final StreamController<List<int>> _bytes = StreamController<List<int>>();
  late final Future<RelayAttachment> _result;
  int _credit = relayAttachmentCreditWindowBytes;
  bool _closed = false;

  Future<void> start() async {
    _result = attachments.upload(
      fileName: open.fileName!,
      mimeType: open.mimeType!,
      declaredByteSize: open.byteSize!,
      bytes: _creditedBytes(),
    );
    await send(
      RelayRecord(
        type: RelayRecordType.attachmentCredit,
        streamId: streamId,
        payload: encodeRelayAttachmentCredit(_credit),
      ),
    );
  }

  void add(List<int> chunk) {
    if (_closed || chunk.isEmpty || chunk.length > _credit) {
      throw const RelaySecurityException('Relay upload exceeded its credit.');
    }
    _credit -= chunk.length;
    _bytes.add(chunk);
  }

  Stream<List<int>> _creditedBytes() async* {
    await for (final chunk in _bytes.stream) {
      yield chunk;
      _credit += chunk.length;
      await send(
        RelayRecord(
          type: RelayRecordType.attachmentCredit,
          streamId: streamId,
          payload: encodeRelayAttachmentCredit(chunk.length),
        ),
      );
    }
  }

  Future<void> finish() async {
    if (_closed) return;
    _closed = true;
    await _bytes.close();
    try {
      final attachment = await _result;
      await _sendResult(<String, Object>{
        'attachment': _attachmentJson(attachment),
      });
    } on Object catch (error) {
      await _sendResult(<String, Object>{'error': '$error'});
    } finally {
      onDone();
    }
  }

  Future<void> _sendResult(Map<String, Object> result) => send(
    RelayRecord(
      type: RelayRecordType.close,
      streamId: streamId,
      payload: utf8.encode(jsonEncode(result)),
    ),
  );

  Future<void> cancel() async {
    if (_closed) return;
    _closed = true;
    await _bytes.close();
  }
}

final class _DaemonDownload {
  new _({
    required this.streamId,
    required this.metadata,
    required this.bytes,
    required this.send,
    required this.onDone,
  });

  static Future<_DaemonDownload> create({
    required int streamId,
    required String attachmentId,
    required RelayAttachmentHost attachments,
    required _AttachmentRecordSender send,
    required void Function() onDone,
  }) async {
    final (metadata, bytes) = await attachments.download(attachmentId);
    return _DaemonDownload._(
      streamId: streamId,
      metadata: metadata,
      bytes: bytes,
      send: send,
      onDone: onDone,
    );
  }

  final int streamId;
  final RelayAttachment metadata;
  final Stream<List<int>> bytes;
  final _AttachmentRecordSender send;
  final void Function() onDone;
  Completer<void>? _creditAvailable;
  var _credit = 0;
  bool _cancelled = false;

  void addCredit(int bytes) {
    if (_cancelled || _credit + bytes > relayAttachmentCreditWindowBytes) {
      throw const RelaySecurityException('Relay download credit is invalid.');
    }
    _credit += bytes;
    _creditAvailable?.complete();
    _creditAvailable = null;
  }

  Future<void> start() async {
    try {
      await send(
        RelayRecord(
          type: RelayRecordType.attachmentOpen,
          streamId: streamId,
          payload: utf8.encode(
            jsonEncode(<String, Object>{
              'attachment': _attachmentJson(metadata),
            }),
          ),
        ),
      );
      await for (final sourceChunk in bytes) {
        var offset = 0;
        while (offset < sourceChunk.length && !_cancelled) {
          while (_credit == 0 && !_cancelled) {
            _creditAvailable = Completer<void>();
            await _creditAvailable!.future;
          }
          if (_cancelled) return;
          final count = <int>[
            sourceChunk.length - offset,
            maxRelayAttachmentChunkBytes,
            _credit,
          ].reduce((a, b) => a < b ? a : b);
          await send(
            RelayRecord(
              type: RelayRecordType.attachmentData,
              streamId: streamId,
              payload: sourceChunk.sublist(offset, offset + count),
            ),
          );
          offset += count;
          _credit -= count;
        }
      }
      if (!_cancelled) {
        await send(
          RelayRecord(
            type: RelayRecordType.close,
            streamId: streamId,
            payload: utf8.encode(jsonEncode(<String, bool>{'ok': true})),
          ),
        );
      }
    } finally {
      onDone();
    }
  }

  Future<void> cancel() async {
    _cancelled = true;
    _creditAvailable?.complete();
    _creditAvailable = null;
  }
}

Map<String, Object> _attachmentJson(RelayAttachment attachment) =>
    <String, Object>{
      'id': attachment.id,
      'fileName': attachment.fileName,
      'mimeType': attachment.mimeType,
      'byteSize': attachment.byteSize,
      'kind': attachment.kind,
      'sha256': attachment.sha256,
      'createdAt': attachment.createdAt.toUtc().toIso8601String(),
    };
