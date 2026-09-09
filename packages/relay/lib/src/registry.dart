import 'dart:async';
import 'dart:typed_data';

import 'package:relay_protocol/relay_protocol.dart';

/// WebSocket close code used for relay admission and size violations.
const int relayPolicyViolationCloseCode = 1008;

/// A relay connection rejected before it can enter the registry.
final class RelayAdmissionException implements Exception {
  /// Creates a rejection with a safe [message].
  const new(this.message);

  /// Safe diagnostic for operators and clients.
  final String message;

  @override
  String toString() => 'RelayAdmissionException: $message';
}

/// Binary WebSocket abstraction used by the relay registry.
abstract interface class RelayPeer {
  /// Incoming opaque binary messages.
  Stream<Uint8List> get messages;

  /// Sends one opaque binary message.
  Future<void> send(Uint8List bytes);

  /// Closes this peer with a WebSocket [code] and safe [reason].
  Future<void> close(int code, String reason);
}

/// Deterministic peer for registry unit tests and in-process integration tests.
final class MemoryRelayPeer implements RelayPeer {
  /// Creates a connected in-memory peer.
  new();

  final StreamController<Uint8List> _messages =
      StreamController<Uint8List>.broadcast(sync: true);

  /// Messages sent to this peer, decoded for deterministic assertions.
  final List<RelayEnvelope> sent = <RelayEnvelope>[];

  /// Last close code requested by the registry.
  int? closeCode;

  /// Last close reason requested by the registry.
  String? closeReason;

  @override
  /// Incoming messages injected with [receive].
  Stream<Uint8List> get messages => _messages.stream;

  /// Injects an incoming binary message.
  void receive(Uint8List bytes) => _messages.add(bytes);

  @override
  /// Captures an outgoing message for deterministic assertions.
  Future<void> send(Uint8List bytes) async {
    try {
      sent.add(RelayEnvelope.decode(bytes));
    } on FormatException {
      sent.add(RelayEnvelope(connectionId: 'peer', payload: bytes));
    }
  }

  @override
  /// Captures the requested close status.
  Future<void> close(int code, String reason) async {
    closeCode = code;
    closeReason = reason;
  }

  /// Releases the in-memory message stream.
  Future<void> dispose() => _messages.close();
}

/// Pairs an opaque daemon socket with opaque client sockets for one server ID.
final class RelayRegistry {
  /// Creates an in-memory relay registry with explicit resource limits.
  new({
    this.maxClientsPerDaemon = 32,
    this.maxFrameBytes = 128 * 1024,
    this.maxBufferedBytesPerPeer = 1024 * 1024,
  });

  /// Maximum concurrent device sockets for one daemon.
  final int maxClientsPerDaemon;

  /// Maximum accepted opaque WebSocket frame size.
  final int maxFrameBytes;

  /// Maximum bytes admitted to a peer's outbound buffer.
  final int maxBufferedBytesPerPeer;

  final Map<String, _DaemonEntry> _daemons = <String, _DaemonEntry>{};
  int _nextConnectionId = 0;

  /// Whether a daemon control socket is currently attached for [serverId].
  ///
  /// [attachClient] rejects a client whose daemon has not attached yet, and
  /// the two WebSocket upgrades are independent round trips, so a caller that
  /// opens both has to observe this rather than assume an ordering.
  bool hasDaemon(String serverId) => _daemons.containsKey(serverId);

  /// Registers the sole daemon control socket for [serverId].
  void attachDaemon({required String serverId, required RelayPeer peer}) {
    if (serverId.isEmpty) {
      throw const RelayAdmissionException('Server ID must not be empty.');
    }
    if (_daemons.containsKey(serverId)) {
      throw RelayAdmissionException('Daemon $serverId is already connected.');
    }
    final entry = _DaemonEntry(peer, maxBufferedBytesPerPeer);
    _daemons[serverId] = entry;
    entry.subscription = peer.messages.listen(
      (bytes) => _onDaemonMessage(serverId, entry, bytes),
      onDone: () => _removeDaemon(serverId, entry),
    );
  }

  /// Registers a client and returns its ephemeral routing identifier.
  String attachClient({required String serverId, required RelayPeer peer}) {
    final daemon = _daemons[serverId];
    if (daemon == null) {
      throw RelayAdmissionException('Daemon $serverId is not connected.');
    }
    if (daemon.clients.length >= maxClientsPerDaemon) {
      throw RelayAdmissionException(
        'Daemon $serverId reached its client limit.',
      );
    }
    final connectionId = '${++_nextConnectionId}';
    final client = _ClientEntry(peer, maxBufferedBytesPerPeer);
    daemon.clients[connectionId] = client;
    client.subscription = peer.messages.listen(
      (bytes) => _onClientMessage(daemon, connectionId, client, bytes),
      onDone: () => _removeClient(daemon, connectionId, client),
    );
    return connectionId;
  }

  void _onClientMessage(
    _DaemonEntry daemon,
    String connectionId,
    _ClientEntry client,
    Uint8List bytes,
  ) {
    if (!_acceptFrame(client.peer, bytes.length)) {
      return;
    }
    final envelope = RelayEnvelope(connectionId: connectionId, payload: bytes);
    daemon.sender.enqueue(envelope.encode());
  }

  void _onDaemonMessage(String serverId, _DaemonEntry daemon, Uint8List bytes) {
    if (!_acceptFrame(daemon.peer, bytes.length)) {
      _removeDaemon(serverId, daemon);
      return;
    }
    RelayEnvelope envelope;
    try {
      envelope = RelayEnvelope.decode(bytes);
    } on FormatException {
      unawaited(
        daemon.peer.close(
          relayPolicyViolationCloseCode,
          'Malformed relay envelope.',
        ),
      );
      return;
    }
    final client = daemon.clients[envelope.connectionId];
    if (client != null) {
      client.sender.enqueue(envelope.payload);
    }
  }

  bool _acceptFrame(RelayPeer peer, int length) {
    if (length <= maxFrameBytes) {
      return true;
    }
    unawaited(
      peer.close(
        relayPolicyViolationCloseCode,
        'Relay frame exceeds configured limits.',
      ),
    );
    return false;
  }

  void _removeDaemon(String serverId, _DaemonEntry daemon) {
    if (!identical(_daemons[serverId], daemon)) {
      return;
    }
    _daemons.remove(serverId);
    unawaited(daemon.subscription?.cancel());
    for (final client in daemon.clients.values) {
      unawaited(client.peer.close(1012, 'Daemon disconnected.'));
      unawaited(client.subscription?.cancel());
    }
    daemon.clients.clear();
  }

  void _removeClient(
    _DaemonEntry daemon,
    String connectionId,
    _ClientEntry client,
  ) {
    if (!identical(daemon.clients[connectionId], client)) {
      return;
    }
    daemon.clients.remove(connectionId);
    unawaited(client.subscription?.cancel());
  }
}

final class _DaemonEntry {
  new(this.peer, int maxBufferedBytes)
    : sender = _BufferedRelaySender(peer, maxBufferedBytes);

  final RelayPeer peer;
  final _BufferedRelaySender sender;
  final Map<String, _ClientEntry> clients = <String, _ClientEntry>{};
  // Registry removal paths always cancel this owned subscription.
  // ignore: cancel_subscriptions
  StreamSubscription<Uint8List>? subscription;
}

final class _ClientEntry {
  new(this.peer, int maxBufferedBytes)
    : sender = _BufferedRelaySender(peer, maxBufferedBytes);

  final RelayPeer peer;
  final _BufferedRelaySender sender;
  // Registry removal paths always cancel this owned subscription.
  // ignore: cancel_subscriptions
  StreamSubscription<Uint8List>? subscription;
}

final class _BufferedRelaySender {
  new(this.peer, this.maxBufferedBytes);

  final RelayPeer peer;
  final int maxBufferedBytes;
  Future<void> _tail = Future<void>.value();
  int _pendingBytes = 0;
  bool _overflowed = false;

  bool enqueue(Uint8List bytes) {
    if (_overflowed) return false;
    if (_pendingBytes + bytes.length > maxBufferedBytes) {
      _overflowed = true;
      unawaited(
        peer.close(
          relayPolicyViolationCloseCode,
          'Relay outbound buffer exceeds configured limits.',
        ),
      );
      return false;
    }
    _pendingBytes += bytes.length;
    _tail = _tail
        .then<void>((_) => peer.send(bytes))
        .onError((_, _) {})
        .whenComplete(() => _pendingBytes -= bytes.length);
    return true;
  }
}
