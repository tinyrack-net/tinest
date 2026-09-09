import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:daemon/src/features/mcp/infrastructure/mcp.dart';
import 'package:test/test.dart';

void main() {
  late _FakeHttpServer server;

  setUp(() async => server = await _FakeHttpServer.bind());
  tearDown(() => server.close());

  HttpMcpTransport transportFor({Map<String, String> headers = const {}}) {
    final transport = HttpMcpTransport(
      McpHttpSpec(url: server.url, headers: headers),
    );
    addTearDown(transport.close);
    return transport;
  }

  test('a JSON response is emitted as one message', () async {
    server.respondJson(<String, dynamic>{
      'jsonrpc': '2.0',
      'id': 1,
      'result': <String, dynamic>{},
    });
    final transport = transportFor();
    final messages = <Map<String, dynamic>>[];
    transport.incoming.listen(messages.add);

    await transport.start();
    await transport.send(<String, dynamic>{'id': 1, 'method': 'ping'});
    await pumpEventQueue();

    expect(messages.single['id'], 1);
    expect(server.requests.single.method, 'POST');
    expect(
      server.requests.single.headers['accept'],
      contains('text/event-stream'),
    );
    expect(server.requests.single.body, contains('"method":"ping"'));
  });

  test('an SSE response is split into separate messages', () async {
    server.respondSse(
      'data: {"id":1,"result":{}}\n'
      '\n'
      ': a comment\n'
      'event: message\n'
      'data: {"id":2,\n'
      'data: "result":{}}\n'
      '\n'
      'data: not json\n'
      '\n'
      'data: [1,2]\n'
      '\n'
      'data: {"id":3,"result":{}}\n',
    );
    final transport = transportFor();
    final messages = <Map<String, dynamic>>[];
    final diagnostics = <String>[];
    transport
      ..incoming.listen(messages.add)
      ..diagnostics.listen(diagnostics.add);

    await transport.start();
    await transport.send(<String, dynamic>{'id': 1});

    expect(messages.map((m) => m['id']), <int>[1, 2, 3]);
    expect(diagnostics, hasLength(2));
    expect(diagnostics.first, contains('non-JSON event'));
    expect(diagnostics.last, contains('non-object event'));
  });

  test('a 202 with no body carries a notification', () async {
    server.respondAccepted();
    final transport = transportFor();
    final messages = <Map<String, dynamic>>[];
    transport.incoming.listen(messages.add);

    await transport.start();
    await transport.send(<String, dynamic>{
      'method': 'notifications/cancelled',
    });
    await pumpEventQueue();

    expect(messages, isEmpty);
    expect(server.requests.single.method, 'POST');
  });

  test('the session id is captured, echoed, and released', () async {
    server
      ..sessionId = 'session-42'
      ..respondJson(<String, dynamic>{'id': 1, 'result': <String, dynamic>{}});
    final transport = transportFor();

    await transport.start();
    await transport.send(<String, dynamic>{'id': 1, 'method': 'initialize'});
    expect(transport.sessionId, 'session-42');

    await transport.send(<String, dynamic>{'id': 2, 'method': 'tools/list'});
    expect(server.requests[1].headers['mcp-session-id'], 'session-42');

    await transport.close();
    expect(server.requests.last.method, 'DELETE');
    expect(server.requests.last.headers['mcp-session-id'], 'session-42');
  });

  test('the protocol version header is omitted until the handshake', () async {
    server.respondJson(<String, dynamic>{
      'id': 1,
      'result': <String, dynamic>{},
    });
    final transport = transportFor(
      headers: const <String, String>{'authorization': 'Bearer token'},
    );

    await transport.start();
    await transport.send(<String, dynamic>{'id': 1, 'method': 'initialize'});
    expect(server.requests.single.headers['mcp-protocol-version'], isNull);
    expect(server.requests.single.headers['authorization'], 'Bearer token');

    await transport.send(<String, dynamic>{'id': 2, 'method': 'tools/list'});
    expect(
      server.requests[1].headers['mcp-protocol-version'],
      preferredMcpProtocolVersion,
    );
  });

  test('a 404 on an established session closes the transport', () async {
    server
      ..sessionId = 'session-1'
      ..respondJson(<String, dynamic>{'id': 1, 'result': <String, dynamic>{}});
    final transport = transportFor();
    final diagnostics = <String>[];
    transport.diagnostics.listen(diagnostics.add);

    await transport.start();
    await transport.send(<String, dynamic>{'id': 1, 'method': 'initialize'});

    server.respondStatus(404, 'gone');
    await transport.send(<String, dynamic>{'id': 2, 'method': 'tools/list'});

    expect(diagnostics, contains('the server expired the session'));
    expect(transport.sessionId, isNull);
    await expectLater(transport.done, completes);
  });

  test('a server error surfaces as an HTTP exception', () async {
    server.respondStatus(500, 'boom');
    final transport = transportFor();
    await transport.start();

    await expectLater(
      transport.send(<String, dynamic>{'id': 1}),
      throwsA(
        isA<McpHttpException>()
            .having((error) => error.statusCode, 'statusCode', 500)
            .having((error) => error.body, 'body', 'boom'),
      ),
    );
  });

  test('a 404 without a session is a plain failure', () async {
    server.respondStatus(404, 'no such endpoint');
    final transport = transportFor();
    await transport.start();

    await expectLater(
      transport.send(<String, dynamic>{'id': 1}),
      throwsA(isA<McpHttpException>()),
    );
  });

  test('a long error body is truncated', () async {
    server.respondStatus(
      500,
      'x' * (HttpMcpTransport.maxRetainedBodyLength * 2),
    );
    final transport = transportFor();
    await transport.start();

    await expectLater(
      transport.send(<String, dynamic>{'id': 1}),
      throwsA(
        isA<McpHttpException>().having(
          (error) => error.body.length,
          'body length',
          HttpMcpTransport.maxRetainedBodyLength + 1,
        ),
      ),
    );
  });

  test('the listening stream opens after initialized', () async {
    server
      ..respondAccepted()
      ..serverStream =
          'data: {"method":"notifications/tools/list_changed"}\n\n';
    final transport = transportFor();
    final messages = <Map<String, dynamic>>[];
    final opened = Completer<Map<String, dynamic>>();
    transport.incoming.listen((message) {
      messages.add(message);
      if (!opened.isCompleted) opened.complete(message);
    });

    await transport.start();
    await transport.send(<String, dynamic>{
      'method': 'notifications/initialized',
    });
    // This notification arrives over the GET that `send` opens, which is a
    // second connection: `send` returning says nothing about whether that
    // stream has produced anything. `pumpEventQueue` drains the event loop a
    // bounded number of times and never waits on a socket read, so a loaded
    // host reached the assertion with nothing received. Await the message.
    final message = await opened.future;

    expect(transport.supportsServerStream, isTrue);
    expect(message['method'], 'notifications/tools/list_changed');
    expect(messages, hasLength(1));
    expect(server.requests.last.method, 'GET');
  });

  test('a server that refuses GET falls back to polling', () async {
    server
      ..respondAccepted()
      ..serverStreamStatus = 405;
    final transport = transportFor();
    final diagnostics = <String>[];
    transport.diagnostics.listen(diagnostics.add);

    await transport.start();
    await transport.send(<String, dynamic>{
      'method': 'notifications/initialized',
    });
    await pumpEventQueue();

    expect(transport.supportsServerStream, isFalse);
    expect(diagnostics.single, contains('HTTP 405'));
  });

  test('sending before start or after close is refused', () async {
    final transport = transportFor();

    await expectLater(
      transport.send(<String, dynamic>{}),
      throwsA(isA<McpTransportClosed>()),
    );

    await transport.start();
    await transport.close();
    await transport.close();
    expect(transport.start(), throwsA(isA<McpTransportClosed>()));
    await expectLater(
      transport.send(<String, dynamic>{}),
      throwsA(isA<McpTransportClosed>()),
    );
  });

  test('an unreachable endpoint fails the send', () async {
    final closedPort = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final url = Uri.parse('http://127.0.0.1:${closedPort.port}/mcp');
    await closedPort.close();

    final transport = HttpMcpTransport(McpHttpSpec(url: url));
    addTearDown(transport.close);
    await transport.start();

    await expectLater(
      transport.send(<String, dynamic>{'id': 1}),
      throwsA(isA<SocketException>()),
    );
  });

  test('a full client session runs over Streamable HTTP', () async {
    server.handler = (request, body) {
      final message = jsonDecode(body) as Map<String, dynamic>;
      final id = message['id'];
      if (id == null) return _Reply.accepted();
      final result = switch (message['method']) {
        'initialize' => <String, dynamic>{
          'protocolVersion': preferredMcpProtocolVersion,
          'serverInfo': <String, dynamic>{'name': 'remote', 'version': '2.0'},
          'capabilities': <String, dynamic>{'tools': <String, dynamic>{}},
        },
        'tools/list' => <String, dynamic>{
          'tools': <dynamic>[
            <String, dynamic>{'name': 'search'},
          ],
        },
        'tools/call' => <String, dynamic>{
          'content': <dynamic>[
            <String, dynamic>{'type': 'text', 'text': 'remote result'},
          ],
        },
        _ => <String, dynamic>{},
      };
      return _Reply.json(<String, dynamic>{
        'jsonrpc': '2.0',
        'id': id,
        'result': result,
      });
    };
    final client = McpClient(transport: transportFor());
    addTearDown(client.close);

    final identity = await client.connect();
    expect(identity.name, 'remote');
    expect(client.tools.single.name, 'search');

    final result = await client.callTool('search', const <String, dynamic>{});
    expect((result.content.single as McpTextContent).text, 'remote result');
  });
}

final class _Reply {
  const new({
    required this.status,
    required this.body,
    required this.contentType,
  });

  factory json(Map<String, dynamic> payload) => _Reply(
    status: 200,
    body: jsonEncode(payload),
    contentType: 'application/json',
  );

  factory sse(String body) =>
      _Reply(status: 200, body: body, contentType: 'text/event-stream');

  factory accepted() =>
      const _Reply(status: 202, body: '', contentType: 'text/plain');

  final int status;
  final String body;
  final String contentType;
}

final class _RecordedRequest {
  const new({required this.method, required this.headers, required this.body});

  final String method;
  final Map<String, String> headers;
  final String body;
}

final class _FakeHttpServer {
  new(this._server) {
    unawaited(_serve());
  }

  static Future<_FakeHttpServer> bind() async =>
      _FakeHttpServer(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _server;
  final List<_RecordedRequest> requests = <_RecordedRequest>[];

  _Reply Function(HttpRequest request, String body)? handler;
  String? sessionId;
  String? serverStream;
  int serverStreamStatus = 200;
  _Reply _reply = _Reply.accepted();

  Uri get url => Uri.parse('http://127.0.0.1:${_server.port}/mcp');

  void respondJson(Map<String, dynamic> payload) =>
      _reply = _Reply.json(payload);

  void respondSse(String body) => _reply = _Reply.sse(body);

  void respondAccepted() => _reply = _Reply.accepted();

  void respondStatus(int status, String body) =>
      _reply = _Reply(status: status, body: body, contentType: 'text/plain');

  Future<void> close() => _server.close(force: true);

  Future<void> _serve() async {
    await for (final request in _server) {
      final body = await utf8.decoder.bind(request).join();
      final headers = <String, String>{};
      request.headers.forEach((name, values) => headers[name] = values.first);
      requests.add(
        _RecordedRequest(method: request.method, headers: headers, body: body),
      );

      if (request.method == 'DELETE') {
        request.response.statusCode = 200;
        await request.response.close();
        continue;
      }
      if (request.method == 'GET') {
        request.response.statusCode = serverStreamStatus;
        if (serverStreamStatus == 200) {
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.write(serverStream ?? '');
        }
        await request.response.close();
        continue;
      }

      final reply = handler?.call(request, body) ?? _reply;
      request.response.statusCode = reply.status;
      if (reply.body.isNotEmpty) {
        final parts = reply.contentType.split('/');
        request.response.headers.contentType = ContentType(
          parts.first,
          parts.last,
        );
      }
      if (sessionId != null) {
        request.response.headers.set('mcp-session-id', sessionId!);
      }
      request.response.write(reply.body);
      await request.response.close();
    }
  }
}
