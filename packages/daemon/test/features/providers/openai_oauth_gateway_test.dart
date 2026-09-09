import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agent/agent.dart';
import 'package:daemon/src/features/providers/infrastructure/openai/openai.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 2);

  test('browser OAuth validates state and exchanges PKCE code', () async {
    final adapter = _OAuthAdapter(now);
    final gateway = OpenAIOAuthGateway(
      clock: _Clock(now),
      dio: Dio()..httpClientAdapter = adapter,
      callbackServerBinder: const _EphemeralBinder(),
    );

    final session = await gateway.start(AgentProviderAuthFlow.oauthBrowser);
    final authorization = Uri.parse(session.authorizationUrl);
    final redirect = Uri.parse(authorization.queryParameters['redirect_uri']!);
    final state = authorization.queryParameters['state']!;
    expect(authorization.queryParameters['code_challenge_method'], 'S256');
    expect(authorization.queryParameters['code_challenge'], isNotEmpty);

    expect(
      await _callback(redirect, state: 'wrong', code: 'ignored'),
      HttpStatus.badRequest,
    );
    expect(
      await _callback(redirect, state: state, code: 'authorization-code'),
      HttpStatus.ok,
    );
    final credential = await session.completion;

    expect(credential.accessToken, adapter.accessToken);
    expect(credential.refreshToken, 'refresh-new');
    expect(credential.accountId, 'account-123');
    expect(adapter.exchangeData['code'], 'authorization-code');
    expect(adapter.exchangeData['code_verifier'], isNotEmpty);
  });

  test('device flow polls, rotates tokens, and can be cancelled', () async {
    final adapter = _OAuthAdapter(now)..pendingDevicePolls = 1;
    var delays = 0;
    final gateway = OpenAIOAuthGateway(
      clock: _Clock(now),
      dio: Dio()..httpClientAdapter = adapter,
      delay: (_) async => delays += 1,
    );

    final session = await gateway.start(AgentProviderAuthFlow.oauthDevice);
    expect(session.authorizationUrl, 'https://auth.openai.com/codex/device');
    expect(session.userCode, 'CODE-1234');
    final credential = await session.completion;

    expect(credential.refreshToken, 'refresh-new');
    expect(delays, 1);

    final pendingAdapter = _OAuthAdapter(now)..pendingDevicePolls = 100;
    final pending = OpenAIOAuthGateway(
      clock: _Clock(now),
      dio: Dio()..httpClientAdapter = pendingAdapter,
      delay: (_) async {},
    );
    final cancelled = await pending.start(AgentProviderAuthFlow.oauthDevice);
    await cancelled.cancel();
    await expectLater(cancelled.completion, throwsA(isA<StateError>()));
  });

  test('refresh preserves rotation and classifies invalid_grant', () async {
    final adapter = _OAuthAdapter(now);
    final gateway = OpenAIOAuthGateway(
      clock: _Clock(now),
      dio: Dio()..httpClientAdapter = adapter,
    );
    final refreshed = await gateway.refresh(
      OAuthCredential(
        accessToken: 'old',
        refreshToken: 'refresh-old',
        expiresAt: now,
        accountId: 'fallback-account',
      ),
    );
    expect(refreshed.refreshToken, 'refresh-new');
    expect(adapter.refreshData['refresh_token'], 'refresh-old');

    adapter.invalidGrant = true;
    await expectLater(
      gateway.refresh(refreshed),
      throwsA(
        isA<OAuthRefreshFailure>().having(
          (error) => error.reauthRequired,
          'reauthRequired',
          isTrue,
        ),
      ),
    );
  });

  test('a denied authorization fails the browser session', () async {
    final gateway = OpenAIOAuthGateway(
      clock: _Clock(now),
      dio: Dio()..httpClientAdapter = _OAuthAdapter(now),
      callbackServerBinder: const _EphemeralBinder(),
    );

    final session = await gateway.start(AgentProviderAuthFlow.oauthBrowser);
    final authorization = Uri.parse(session.authorizationUrl);
    final redirect = Uri.parse(authorization.queryParameters['redirect_uri']!);

    // The gateway fails the session while it is still answering the callback
    // request, so the expectation has to be watching before the round trip
    // starts. Attaching it afterwards leaves the error unhandled for the length
    // of a real socket read, which the test runner reports as a failure.
    final failure = expectLater(
      session.completion,
      throwsA(
        isA<OAuthAuthorizationFailure>().having(
          (error) => error.message,
          'message',
          contains('The user denied the request.'),
        ),
      ),
    );

    expect(
      await _callback(
        redirect,
        state: authorization.queryParameters['state']!,
        error: 'access_denied',
        errorDescription: 'The user denied the request.',
      ),
      HttpStatus.badRequest,
    );

    await failure;
  });

  test('the callback page escapes provider-supplied text', () async {
    final gateway = OpenAIOAuthGateway(
      clock: _Clock(now),
      dio: Dio()..httpClientAdapter = _OAuthAdapter(now),
      callbackServerBinder: const _EphemeralBinder(),
    );

    final session = await gateway.start(AgentProviderAuthFlow.oauthBrowser);
    final authorization = Uri.parse(session.authorizationUrl);
    final failure = expectLater(
      session.completion,
      throwsA(isA<OAuthAuthorizationFailure>()),
    );
    final body = await _callbackBody(
      Uri.parse(authorization.queryParameters['redirect_uri']!),
      state: authorization.queryParameters['state']!,
      error: 'access_denied',
      errorDescription: '<script>alert(1)</script>',
    );

    expect(body, isNot(contains('<script>')));
    expect(body, contains('&lt;script&gt;'));
    await failure;
  });

  test('a rejected token exchange reports the OAuth error, not Dio', () async {
    final adapter = _OAuthAdapter(now)
      ..exchangeError = <String, dynamic>{
        'error': 'invalid_grant',
        'error_description': 'The redirect URI is not registered.',
      };
    final gateway = OpenAIOAuthGateway(
      clock: _Clock(now),
      dio: Dio()..httpClientAdapter = adapter,
      callbackServerBinder: const _EphemeralBinder(),
    );

    final session = await gateway.start(AgentProviderAuthFlow.oauthBrowser);
    final authorization = Uri.parse(session.authorizationUrl);
    final failure = expectLater(
      session.completion,
      throwsA(
        isA<OAuthAuthorizationFailure>().having(
          (error) => error.toString(),
          'toString',
          allOf(
            contains('The redirect URI is not registered.'),
            isNot(contains('status code')),
            isNot(contains('DioException')),
          ),
        ),
      ),
    );

    // The browser must be told why sign in failed, not left on a reset socket.
    expect(
      await _callback(
        Uri.parse(authorization.queryParameters['redirect_uri']!),
        state: authorization.queryParameters['state']!,
        code: 'authorization-code',
      ),
      HttpStatus.badRequest,
    );

    await failure;
  });

  test('a rejected device exchange stops the polling loop', () async {
    final adapter = _OAuthAdapter(now)
      ..exchangeError = <String, dynamic>{'error': 'expired_token'};
    var delays = 0;
    final gateway = OpenAIOAuthGateway(
      clock: _Clock(now),
      dio: Dio()..httpClientAdapter = adapter,
      delay: (_) async => delays += 1,
    );

    final session = await gateway.start(AgentProviderAuthFlow.oauthDevice);

    await expectLater(
      session.completion,
      throwsA(
        isA<OAuthAuthorizationFailure>().having(
          (error) => error.message,
          'message',
          contains('expired_token'),
        ),
      ),
    );
    // A rejected exchange must not be mistaken for `authorization_pending`.
    expect(delays, 0);
  });

  test(
    'loopback callback binder refuses to move off the registered port',
    () async {
      // Port 0 asks the OS for any free port, so the success path never races
      // another process for a specific number.
      final server = await const LoopbackOAuthCallbackServerBinder(port: 0)
          .bind();
      addTearDown(() => server.close(force: true));
      expect(server.port, greaterThan(0));

      // The public Codex client registers exactly one redirect URI, so a busy
      // port must fail loudly instead of silently binding somewhere else.
      await expectLater(
        LoopbackOAuthCallbackServerBinder(port: server.port).bind(),
        throwsA(
          isA<OAuthAuthorizationFailure>().having(
            (error) => error.message,
            'message',
            contains('${server.port}'),
          ),
        ),
      );
    },
  );
}

Future<String> _callbackBody(
  Uri redirect, {
  required String state,
  required String error,
  required String errorDescription,
}) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      redirect.replace(
        queryParameters: <String, String>{
          'state': state,
          'error': error,
          'error_description': errorDescription,
        },
      ),
    );
    final response = await request.close();
    // Read the body before `finally` force-closes the client, otherwise the
    // socket is torn down mid-read when the body spans more than one packet.
    return await response.transform(utf8.decoder).join();
  } finally {
    client.close(force: true);
  }
}

Future<int> _callback(
  Uri redirect, {
  required String state,
  String? code,
  String? error,
  String? errorDescription,
}) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      redirect.replace(
        queryParameters: <String, String>{
          'state': state,
          'code': ?code,
          'error': ?error,
          'error_description': ?errorDescription,
        },
      ),
    );
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  } finally {
    client.close(force: true);
  }
}

final class _Clock implements Clock {
  const new(this.value);

  final DateTime value;

  @override
  DateTime nowUtc() => value;
}

final class _EphemeralBinder implements OAuthCallbackServerBinder {
  const new();

  @override
  Future<HttpServer> bind() => HttpServer.bind(InternetAddress.loopbackIPv4, 0);
}

final class _OAuthAdapter implements HttpClientAdapter {
  new(this.now)
    : accessToken = _jwt(<String, dynamic>{
        'exp': now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
        'chatgpt_account_id': 'account-123',
      });

  final DateTime now;
  final String accessToken;
  int pendingDevicePolls = 0;
  bool invalidGrant = false;
  Map<String, dynamic>? exchangeError;
  Map<String, dynamic> exchangeData = <String, dynamic>{};
  Map<String, dynamic> refreshData = <String, dynamic>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.endsWith('/api/accounts/deviceauth/usercode')) {
      return _json(<String, dynamic>{
        'device_auth_id': 'device-id',
        'user_code': 'CODE-1234',
        'interval': '1',
      });
    }
    if (options.path.endsWith('/api/accounts/deviceauth/token')) {
      if (pendingDevicePolls > 0) {
        pendingDevicePolls -= 1;
        return _json(<String, dynamic>{'error': 'authorization_pending'}, 403);
      }
      return _json(<String, dynamic>{
        'authorization_code': 'device-code',
        'code_verifier': 'device-verifier',
      });
    }
    if (options.path.endsWith('/oauth/token')) {
      final data = Map<String, dynamic>.from(options.data as Map);
      if (data['grant_type'] == 'refresh_token') {
        refreshData = data;
        if (invalidGrant) {
          return _json(<String, dynamic>{'error': 'invalid_grant'}, 400);
        }
      } else {
        exchangeData = data;
        final rejection = exchangeError;
        if (rejection != null) return _json(rejection, 400);
      }
      return _json(<String, dynamic>{
        'access_token': accessToken,
        'refresh_token': 'refresh-new',
      });
    }
    return _json(<String, dynamic>{'error': 'not_found'}, 404);
  }

  static ResponseBody _json(Map<String, dynamic> value, [int status = 200]) =>
      ResponseBody.fromString(
        jsonEncode(value),
        status,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

String _jwt(Map<String, dynamic> claims) =>
    '${base64Url.encode(utf8.encode('{}')).replaceAll('=', '')}.'
    '${base64Url.encode(utf8.encode(jsonEncode(claims))).replaceAll('=', '')}.';
