import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:relay/relay.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

void main() {
  test(
    'health, opaque routing, metrics, and rolling drain work end to end',
    () async {
      final service = RelayService();
      final server = await shelf_io.serve(
        service.call,
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => server.close(force: true));
      final base = Uri.parse('http://127.0.0.1:${server.port}');

      expect(await _get(base.resolve('/health/live')), 'live\n');
      expect(await _get(base.resolve('/health/ready')), 'ready\n');

      final daemon = await WebSocket.connect(
        _webSocketUri(base, role: 'daemon', serverId: 'daemon-1').toString(),
      );
      final client = await WebSocket.connect(
        _webSocketUri(base, role: 'client', serverId: 'daemon-1').toString(),
      );
      final daemonMessages = StreamIterator<dynamic>(daemon);
      final clientMessages = StreamIterator<dynamic>(client);
      client.add(Uint8List.fromList(<int>[7, 8, 9]));
      expect(await daemonMessages.moveNext(), isTrue);
      final envelope = RelayEnvelope.decode(
        Uint8List.fromList(daemonMessages.current as List<int>),
      );
      expect(envelope.payload, <int>[7, 8, 9]);

      daemon.add(
        RelayEnvelope(
          connectionId: envelope.connectionId,
          payload: Uint8List.fromList(<int>[4, 5, 6]),
        ).encode(),
      );
      expect(await clientMessages.moveNext(), isTrue);
      expect(clientMessages.current, <int>[4, 5, 6]);
      expect(await _get(base.resolve('/metrics')), contains('received_bytes'));

      await service.drain();
      expect(await daemonMessages.moveNext(), isFalse);
      expect(await clientMessages.moveNext(), isFalse);
      expect(daemon.closeCode, 4002);
      expect(client.closeCode, 4002);
      expect(await _status(base.resolve('/health/ready')), 503);
    },
  );

  test(
    'connection, route, and source limits reject before admission',
    () async {
      final service = RelayService(maxConnections: 1, maxConnectionsPerIp: 1);
      final server = await shelf_io.serve(
        service.call,
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => server.close(force: true));
      final base = Uri.parse('http://127.0.0.1:${server.port}');
      expect(await _status(base.resolve('/v1/ws')), 400);

      final daemon = await WebSocket.connect(
        _webSocketUri(base, role: 'daemon', serverId: 'daemon-1').toString(),
      );
      addTearDown(daemon.close);
      await expectLater(
        WebSocket.connect(
          _webSocketUri(base, role: 'client', serverId: 'daemon-1').toString(),
        ),
        throwsA(isA<WebSocketException>()),
      );
    },
  );

  test(
    'an idle daemon remains routable beyond the client handshake timeout',
    () async {
      // The budget governs the client socket as well as naming the span this
      // daemon has to outlive, so it cannot be set purely for the daemon's
      // sake. At 20ms a runner busy enough to spend that long between
      // accepting the client's upgrade and reading its first frame closed the
      // client for a handshake timeout this test is not about, and the frame
      // it was waiting on never arrived. A second is still trivial to idle
      // past and is fifty times the margin that failed.
      const handshakeBudget = Duration(seconds: 1);
      final service = RelayService(clientHandshakeTimeout: handshakeBudget);
      final server = await shelf_io.serve(
        service.call,
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => server.close(force: true));
      final base = Uri.parse('http://127.0.0.1:${server.port}');
      final daemon = await WebSocket.connect(
        _webSocketUri(base, role: 'daemon', serverId: 'idle-daemon').toString(),
      );
      addTearDown(daemon.close);

      // The daemon's upgrade and its registry attach are a separate round trip
      // from this connect, so waiting a duration here only works while the
      // host is fast enough: a loaded Windows runner lands the client first,
      // `attachClient` rejects it for having no daemon, and the routed frame
      // never arrives. Await the attach itself instead.
      await _awaitDaemonAttached(service, 'idle-daemon');
      // Then sit idle past the budget, which is what "beyond" means here. The
      // direction is safe: a slower machine only widens the window a
      // regression that closed this socket would have to survive.
      await Future<void>.delayed(handshakeBudget * 1.5);

      final client = await WebSocket.connect(
        _webSocketUri(base, role: 'client', serverId: 'idle-daemon').toString(),
      );
      addTearDown(client.close);
      final daemonMessages = StreamIterator<dynamic>(daemon);
      client.add(Uint8List.fromList(<int>[1, 2, 3]));
      // Awaited, not raced against a stopwatch. The frame crosses a real
      // loopback server, so a second is a bound on how busy the machine is
      // rather than on whether the daemon stayed routable — which is what the
      // test is about. The suite timeout still stops a hang.
      expect(await daemonMessages.moveNext(), isTrue);
    },
  );

  test('a client without a daemon closes with the wire policy code', () async {
    final service = RelayService(
      clientHandshakeTimeout: const Duration(milliseconds: 20),
    );
    final server = await shelf_io.serve(
      service.call,
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(() => server.close(force: true));
    final base = Uri.parse('http://127.0.0.1:${server.port}');
    final client = await WebSocket.connect(
      _webSocketUri(base, role: 'client', serverId: 'missing').toString(),
    );

    await client.drain<void>().timeout(const Duration(seconds: 1));
    expect(client.closeCode, 4008);
  });

  test('an idle client closes with the wire policy code', () async {
    final service = RelayService(
      clientHandshakeTimeout: const Duration(milliseconds: 20),
    );
    final server = await shelf_io.serve(
      service.call,
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(() => server.close(force: true));
    final base = Uri.parse('http://127.0.0.1:${server.port}');
    final daemon = await WebSocket.connect(
      _webSocketUri(base, role: 'daemon', serverId: 'idle-client').toString(),
    );
    addTearDown(daemon.close);
    final client = await WebSocket.connect(
      _webSocketUri(base, role: 'client', serverId: 'idle-client').toString(),
    );

    await client.drain<void>().timeout(const Duration(seconds: 1));
    expect(client.closeCode, 4008);
  });

  test(
    'unknown routes and oversized server identifiers are rejected',
    () async {
      final service = RelayService();
      expect(
        (await service.call(Request('GET', Uri.parse('http://x/nope'))))
            .statusCode,
        404,
      );
      final oversized = 'x' * 129;
      expect(
        (await service.call(
          Request(
            'GET',
            Uri.parse('http://x/v1/ws?role=daemon&serverId=$oversized'),
          ),
        )).statusCode,
        400,
      );
    },
  );
}

/// Waits until [serverId]'s daemon control socket has reached the registry.
///
/// The timeout is a failure deadline rather than a settling delay: it turns a
/// daemon that never attaches into a named failure instead of a hung suite.
Future<void> _awaitDaemonAttached(RelayService service, String serverId) =>
    Future.doWhile(() async {
      if (service.registry.hasDaemon(serverId)) return false;
      await Future<void>.delayed(Duration.zero);
      return true;
    }).timeout(
      const Duration(seconds: 10),
      onTimeout: () => fail('Daemon $serverId never attached to the registry.'),
    );

Uri _webSocketUri(Uri base, {required String role, required String serverId}) =>
    base.replace(
      scheme: 'ws',
      path: '/v1/ws',
      queryParameters: <String, String>{'role': role, 'serverId': serverId},
    );

Future<String> _get(Uri uri) async {
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(uri)).close();
    final body = await response
        .transform(const SystemEncoding().decoder)
        .join();
    return body;
  } finally {
    client.close();
  }
}

Future<int> _status(Uri uri) async {
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(uri)).close();
    final statusCode = response.statusCode;
    await response.drain<void>();
    return statusCode;
  } finally {
    client.close();
  }
}
