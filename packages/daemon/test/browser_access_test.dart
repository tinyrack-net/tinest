@Tags(<String>['feature_test__daemon_authentication__verticalSlice'])
library;

import 'dart:async';
import 'dart:io';

import 'package:client/client.dart';
import 'package:daemon/daemon.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

const String _token = 'test-token-0123456789abcdef0123456789';
const String _allowed = 'https://app.example';
const String _blocked = 'https://evil.example';

void main() {
  late DaemonHandle handle;
  late Directory home;

  setUp(() async {
    home = await Directory.systemTemp.createTemp('tinest-browser-');
    handle = await DaemonApplication.start(
      DaemonConfig(
        homeDirectory: home.path,
        port: 0,
        bearerToken: _token,
        useEnvironmentCredentials: false,
        allowedOrigins: const <String>{_allowed},
      ),
    );
  });

  tearDown(() async {
    await handle.stop();
    await home.delete(recursive: true);
  });

  Uri http(String path) =>
      handle.boundEndpoint.replace(scheme: 'http', path: '/$path');

  Future<HttpClientResponse> send(
    String method,
    String path, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, http(path));
      headers.forEach(request.headers.set);
      return await request.close();
    } finally {
      client.close(force: true);
    }
  }

  Future<void> handshake({
    Map<String, String> headers = const <String, String>{},
    List<String> protocols = const <String>[],
  }) async {
    final channel = IOWebSocketChannel.connect(
      handle.boundEndpoint,
      headers: headers,
      protocols: protocols.isEmpty ? null : protocols,
    );
    await channel.ready;
    await channel.sink.close();
  }

  group('WebSocket credentials', () {
    test('a native client authenticates with the bearer header', () async {
      await expectLater(
        handshake(headers: <String, String>{'authorization': 'Bearer $_token'}),
        completes,
      );
    });

    test('a browser authenticates with the token subprotocol', () async {
      // A browser cannot set request headers, so this is the only credential
      // a web client can present.
      await expectLater(
        handshake(
          headers: <String, String>{'origin': _allowed},
          protocols: <String>[
            tinestWebSocketProtocol,
            encodeWebSocketTokenProtocol(_token),
          ],
        ),
        completes,
      );
    });

    test('a wrong token in the subprotocol is rejected', () async {
      await expectLater(
        handshake(
          headers: <String, String>{'origin': _allowed},
          protocols: <String>[
            tinestWebSocketProtocol,
            encodeWebSocketTokenProtocol('not-the-token'),
          ],
        ),
        throwsA(isA<Object>()),
      );
    });

    test('no credential at all is rejected', () async {
      await expectLater(
        handshake(protocols: <String>[tinestWebSocketProtocol]),
        throwsA(isA<Object>()),
      );
    });
  });

  group('origin allowlist', () {
    test('an unlisted origin is refused before authentication', () async {
      final response = await send(
        'GET',
        'v5/health',
        headers: <String, String>{'origin': _blocked},
      );
      expect(response.statusCode, HttpStatus.forbidden);
    });

    test('a request without an origin is unaffected', () async {
      // Every native client and the CLI land here; the allowlist must not
      // change their behaviour.
      final response = await send('GET', 'v5/health');
      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.value('access-control-allow-origin'), isNull);
    });

    test('an allowed origin receives the CORS headers', () async {
      final response = await send(
        'GET',
        'v5/health',
        headers: <String, String>{'origin': _allowed},
      );
      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.value('access-control-allow-origin'), _allowed);
      expect(response.headers.value('vary'), 'Origin');
    });

    test('an unlisted origin cannot reach attachments either', () async {
      final response = await send(
        'GET',
        'v5/attachments/anything',
        headers: <String, String>{
          'origin': _blocked,
          'authorization': 'Bearer $_token',
        },
      );
      expect(response.statusCode, HttpStatus.forbidden);
    });
  });

  group('CORS preflight', () {
    test('an attachment upload preflight is answered', () async {
      // Without this the browser never sends the upload: `x-file-name` makes
      // the request non-simple and therefore preflighted.
      final response = await send(
        'OPTIONS',
        'v5/attachments',
        headers: <String, String>{
          'origin': _allowed,
          'access-control-request-method': 'POST',
          'access-control-request-headers': 'authorization,x-file-name',
        },
      );
      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.value('access-control-allow-origin'), _allowed);
      expect(
        response.headers.value('access-control-allow-headers'),
        allOf(contains('authorization'), contains('x-file-name')),
      );
      expect(
        response.headers.value('access-control-allow-methods'),
        contains('POST'),
      );
      expect(
        response.headers.value('access-control-expose-headers'),
        contains('content-disposition'),
      );
    });

    test('a preflight without an origin is not answered', () async {
      final response = await send('OPTIONS', 'v5/attachments');
      expect(response.statusCode, HttpStatus.notFound);
    });
  });

  group('token subprotocol encoding', () {
    test('round-trips a token that is not subprotocol-safe', () async {
      // Operator-supplied tokens are arbitrary strings, and a raw comma or
      // space would corrupt the Sec-WebSocket-Protocol header.
      const awkward = 'a token, with=punctuation/and+symbols';
      final encoded = encodeWebSocketTokenProtocol(awkward);
      expect(encoded, isNot(contains(' ')));
      expect(encoded, isNot(contains(',')));
      expect(decodeWebSocketTokenProtocol(encoded), awkward);
    });

    test('a protocol that carries no token decodes to null', () async {
      expect(decodeWebSocketTokenProtocol(tinestWebSocketProtocol), isNull);
      expect(decodeWebSocketTokenProtocol(tinestWebSocketTokenPrefix), isNull);
    });
  });
}
