import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:relay/src/registry.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// HTTP and WebSocket surface of one stateless relay replica.
final class RelayService {
  /// Creates a relay replica with bounded registry resources.
  new({
    RelayRegistry? registry,
    this.maxConnections = 4096,
    this.maxConnectionsPerIp = 64,
    this.clientHandshakeTimeout = const Duration(seconds: 10),
  }) : assert(
         clientHandshakeTimeout > Duration.zero,
         'Client handshake timeout must be positive.',
       ),
       registry = registry ?? RelayRegistry();

  /// In-memory daemon/client registry for this replica.
  final RelayRegistry registry;

  /// Maximum simultaneous WebSocket connections on this replica.
  final int maxConnections;

  /// Maximum simultaneous sockets admitted from one source address.
  final int maxConnectionsPerIp;

  /// Maximum time a client may wait before sending its first relay frame.
  ///
  /// Daemon control sockets are deliberately exempt: they wait for a client
  /// connection before they have an envelope to send.
  final Duration clientHandshakeTimeout;

  final Set<_WebSocketRelayPeer> _peers = <_WebSocketRelayPeer>{};
  final Map<String, int> _connectionsByIp = <String, int>{};
  final Set<String> _seenDaemonIds = <String>{};
  bool _ready = true;
  int _acceptedConnections = 0;
  int _rejectedConnections = 0;
  int _receivedBytes = 0;
  int _sentBytes = 0;
  int _reconnections = 0;

  /// Routes health, metrics, and `/v1/ws` upgrade requests.
  FutureOr<Response> call(Request request) {
    switch (request.url.path) {
      case 'health/live':
        return Response.ok('live\n');
      case 'health/ready':
        return _ready
            ? Response.ok('ready\n')
            : Response(503, body: 'draining\n');
      case 'metrics':
        return Response.ok(
          _metrics(),
          headers: const <String, String>{
            'content-type': 'text/plain; version=0.0.4; charset=utf-8',
          },
        );
      case 'v1/ws':
        if (!_ready) {
          _rejectedConnections += 1;
          return Response(503, body: 'Relay replica is draining.');
        }
        if (_peers.length >= maxConnections) {
          _rejectedConnections += 1;
          return Response(429, body: 'Relay connection limit reached.');
        }
        final route = _RelayRoute.fromRequest(request);
        if (route == null) {
          _rejectedConnections += 1;
          return Response(400, body: 'Invalid relay route.');
        }
        final sourceIp =
            (request.context['shelf.io.connection_info'] as HttpConnectionInfo?)
                ?.remoteAddress
                .address ??
            'unknown';
        if ((_connectionsByIp[sourceIp] ?? 0) >= maxConnectionsPerIp) {
          _rejectedConnections += 1;
          return Response(429, body: 'Relay source connection limit reached.');
        }
        return webSocketHandler(
          (channel, _) => _onConnection(channel, route, sourceIp),
          pingInterval: const Duration(seconds: 10),
        )(request);
      default:
        return Response.notFound('Not found.');
    }
  }

  /// Stops accepting traffic and reconnects all peers through close code 1012.
  Future<void> drain() async {
    _ready = false;
    await Future.wait<void>(<Future<void>>[
      for (final peer in _peers.toList())
        peer.close(1012, 'Relay replica is restarting.'),
    ]);
  }

  void _onConnection(
    WebSocketChannel channel,
    _RelayRoute route,
    String sourceIp,
  ) {
    final peer = _WebSocketRelayPeer(
      channel,
      initialFrameTimeout: route.role == _RelayRole.client
          ? clientHandshakeTimeout
          : null,
      onReceived: (bytes) => _receivedBytes += bytes,
      onSent: (bytes) => _sentBytes += bytes,
    );
    _peers.add(peer);
    _connectionsByIp.update(sourceIp, (count) => count + 1, ifAbsent: () => 1);
    _acceptedConnections += 1;
    unawaited(
      peer.done.whenComplete(() {
        _peers.remove(peer);
        final remaining = (_connectionsByIp[sourceIp] ?? 1) - 1;
        if (remaining == 0) {
          _connectionsByIp.remove(sourceIp);
        } else {
          _connectionsByIp[sourceIp] = remaining;
        }
      }),
    );
    try {
      switch (route.role) {
        case _RelayRole.daemon:
          if (!_seenDaemonIds.add(route.serverId)) _reconnections += 1;
          registry.attachDaemon(serverId: route.serverId, peer: peer);
        case _RelayRole.client:
          registry.attachClient(serverId: route.serverId, peer: peer);
      }
    } on RelayAdmissionException catch (error) {
      _rejectedConnections += 1;
      unawaited(peer.close(relayPolicyViolationCloseCode, error.message));
    }
  }

  String _metrics() =>
      '''
# TYPE tinest_relay_connections gauge
tinest_relay_connections ${_peers.length}
# TYPE tinest_relay_connections_accepted_total counter
tinest_relay_connections_accepted_total $_acceptedConnections
# TYPE tinest_relay_connections_rejected_total counter
tinest_relay_connections_rejected_total $_rejectedConnections
# TYPE tinest_relay_received_bytes_total counter
tinest_relay_received_bytes_total $_receivedBytes
# TYPE tinest_relay_sent_bytes_total counter
tinest_relay_sent_bytes_total $_sentBytes
# TYPE tinest_relay_reconnections_total counter
tinest_relay_reconnections_total $_reconnections
''';
}

enum _RelayRole { daemon, client }

final class _RelayRoute {
  const new(this.role, this.serverId);

  static _RelayRoute? fromRequest(Request request) {
    final role = switch (request.url.queryParameters['role']) {
      'daemon' => _RelayRole.daemon,
      'client' => _RelayRole.client,
      _ => null,
    };
    final serverId = request.url.queryParameters['serverId'];
    if (role == null ||
        serverId == null ||
        serverId.isEmpty ||
        serverId.length > 128) {
      return null;
    }
    return _RelayRoute(role, serverId);
  }

  final _RelayRole role;
  final String serverId;
}

final class _WebSocketRelayPeer implements RelayPeer {
  new(
    this._channel, {
    required Duration? initialFrameTimeout,
    required this.onReceived,
    required this.onSent,
  }) {
    _handshakeTimer = initialFrameTimeout == null
        ? null
        : Timer(initialFrameTimeout, () {
            unawaited(close(1008, 'Relay handshake timed out.'));
          });
    _subscription = _channel.stream.listen(
      (message) {
        if (message is List<int>) {
          _handshakeTimer?.cancel();
          onReceived(message.length);
          _messages.add(Uint8List.fromList(message));
        } else {
          unawaited(
            close(relayPolicyViolationCloseCode, 'Binary frames only.'),
          );
        }
      },
      onError: _messages.addError,
      onDone: _messages.close,
    );
  }

  final WebSocketChannel _channel;
  final void Function(int bytes) onReceived;
  final void Function(int bytes) onSent;
  final StreamController<Uint8List> _messages = StreamController<Uint8List>();
  late final StreamSubscription<dynamic> _subscription;
  late final Timer? _handshakeTimer;

  Future<void> get done => _channel.sink.done;

  @override
  Stream<Uint8List> get messages => _messages.stream;

  @override
  Future<void> close(int code, String reason) async {
    _handshakeTimer?.cancel();
    // package:web_socket currently rejects registered 1xxx codes other than
    // 1000. Keep the standard registry/service protocol intent and map it to
    // private equivalents only at this library boundary.
    final wireCode = switch (code) {
      1008 => 4008,
      1012 => 4002,
      _ => code,
    };
    await _channel.sink
        .close(wireCode, reason)
        .timeout(const Duration(seconds: 1), onTimeout: () {});
    await _subscription.cancel();
  }

  @override
  Future<void> send(Uint8List bytes) async {
    onSent(bytes.length);
    _channel.sink.add(bytes);
  }
}
