import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:agent/agent.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

/// OpenAI Codex public OAuth client identifier.
const String openAICodexOAuthClientId = 'app_EMoamEEZ73f0CkXaXp7hrann';

/// Opens the fixed loopback callback used by ChatGPT browser authorization.
abstract interface class OAuthCallbackServerBinder {
  /// Binds and returns a loopback callback server.
  Future<HttpServer> bind();
}

/// Production callback binder on the single registered Codex callback port.
final class LoopbackOAuthCallbackServerBinder
    implements OAuthCallbackServerBinder {
  /// Creates the production callback binder.
  const new({this.port = 1455});

  /// The only loopback port registered for the public Codex OAuth client.
  final int port;

  @override
  Future<HttpServer> bind() async {
    try {
      return await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    } on SocketException {
      // Any other port yields a redirect_uri the public Codex client has not
      // registered, which fails the exchange with an opaque 400. Failing here
      // instead names the actual problem while the user can still act on it.
      throw OAuthAuthorizationFailure(
        'The ChatGPT sign-in callback port $port is already in use. Close the '
        'other Codex or ChatGPT sign-in and try again.',
      );
    }
  }
}

/// Production OpenAI browser and device-code OAuth adapter.
final class OpenAIOAuthGateway implements ProviderOAuthGateway {
  /// Creates an OpenAI OAuth adapter.
  factory({
    required Clock clock,
    Dio? dio,
    String issuer = 'https://auth.openai.com',
    OAuthCallbackServerBinder callbackServerBinder =
        const LoopbackOAuthCallbackServerBinder(),
    Future<void> Function(Duration duration) delay = Future<void>.delayed,
  }) => OpenAIOAuthGateway._(
    clock: clock,
    dio: dio ?? Dio(),
    issuer: issuer.replaceAll(RegExp(r'/+$'), ''),
    callbackServerBinder: callbackServerBinder,
    delay: delay,
  );

  new _({
    required this._clock,
    required this._dio,
    required this._issuer,
    required this._callbackServerBinder,
    required this._delay,
  });

  final Clock _clock;
  final Dio _dio;
  final String _issuer;
  final OAuthCallbackServerBinder _callbackServerBinder;
  final Future<void> Function(Duration duration) _delay;

  @override
  Future<ProviderOAuthSession> start(AgentProviderAuthFlow flow) =>
      switch (flow) {
        AgentProviderAuthFlow.oauthBrowser => _startBrowser(),
        AgentProviderAuthFlow.oauthDevice => _startDevice(),
        AgentProviderAuthFlow.apiKey || AgentProviderAuthFlow.none =>
          throw StateError('The selected method is not an OAuth flow.'),
      };

  @override
  Future<OAuthCredential> refresh(OAuthCredential credential) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_issuer/oauth/token',
        data: <String, String>{
          'client_id': openAICodexOAuthClientId,
          'grant_type': 'refresh_token',
          'refresh_token': credential.refreshToken,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      return _credentialFromTokens(
        response.data ?? const <String, dynamic>{},
        fallbackRefreshToken: credential.refreshToken,
        fallbackAccountId: credential.accountId,
      );
    } on DioException catch (error) {
      final data = error.response?.data;
      final code = data is Map<String, dynamic> ? data['error'] : null;
      throw OAuthRefreshFailure(
        code == 'invalid_grant' ? 'Authorization expired.' : 'Refresh failed.',
        reauthRequired: code == 'invalid_grant',
      );
    }
  }

  Future<ProviderOAuthSession> _startBrowser() async {
    final verifier = _randomToken(64);
    final challenge = base64UrlEncode(
      sha256.convert(utf8.encode(verifier)).bytes,
    ).replaceAll('=', '');
    final state = _randomToken(32);
    final server = await _callbackServerBinder.bind();
    final port = server.port;
    final redirectUri = 'http://localhost:$port/auth/callback';
    final authorizationUrl = Uri.parse('$_issuer/oauth/authorize')
        .replace(
          queryParameters: <String, String>{
            'response_type': 'code',
            'client_id': openAICodexOAuthClientId,
            'redirect_uri': redirectUri,
            'scope':
                'openid profile email offline_access api.connectors.read '
                'api.connectors.invoke',
            'code_challenge': challenge,
            'code_challenge_method': 'S256',
            'id_token_add_organizations': 'true',
            'codex_cli_simplified_flow': 'true',
            'state': state,
            'originator': 'tinyrack_tinest',
          },
        )
        .toString();
    final completion = _completeBrowser(
      server: server,
      expectedState: state,
      verifier: verifier,
      redirectUri: redirectUri,
    );
    return _OpenAIOAuthSession(
      authorizationUrl: authorizationUrl,
      instructions: 'Complete ChatGPT sign in in your browser.',
      expiresAt: _clock.nowUtc().add(const Duration(minutes: 15)),
      completion: completion,
      onCancel: () => server.close(force: true),
    );
  }

  Future<ProviderOAuthSession> _startDevice() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_issuer/api/accounts/deviceauth/usercode',
      data: const <String, String>{'client_id': openAICodexOAuthClientId},
    );
    final data = response.data ?? const <String, dynamic>{};
    final deviceAuthId = data['device_auth_id'];
    final userCode = data['user_code'] ?? data['usercode'];
    final rawInterval = data['interval'];
    if (deviceAuthId is! String || userCode is! String) {
      throw const FormatException('Invalid OpenAI device authorization data.');
    }
    final resolvedInterval = switch (rawInterval) {
      final int value => value,
      final String value => int.tryParse(value) ?? 5,
      _ => 5,
    };
    final cancellation = _CancellationFlag();
    final expiresAt = _clock.nowUtc().add(const Duration(minutes: 15));
    return _OpenAIOAuthSession(
      authorizationUrl: '$_issuer/codex/device',
      userCode: userCode,
      instructions: 'Open the URL and enter the one-time code.',
      expiresAt: expiresAt,
      completion: _pollDevice(
        deviceAuthId: deviceAuthId,
        userCode: userCode,
        interval: Duration(seconds: resolvedInterval.clamp(1, 30)),
        expiresAt: expiresAt,
        cancelled: cancellation,
      ),
      onCancel: () async => cancellation.cancelled = true,
    );
  }

  Future<OAuthCredential> _completeBrowser({
    required HttpServer server,
    required String expectedState,
    required String verifier,
    required String redirectUri,
  }) async {
    try {
      await for (final request in server) {
        if (request.uri.path != '/auth/callback') {
          await _respond(request, HttpStatus.notFound, 'Not found');
          continue;
        }
        if (request.uri.queryParameters['state'] != expectedState) {
          await _respond(request, HttpStatus.badRequest, 'State mismatch');
          continue;
        }
        // A denied or failed authorization redirects back with `error` and no
        // `code`. Fail the attempt instead of waiting for a code that the
        // identity provider will never send.
        final failure = request.uri.queryParameters['error'];
        if (failure != null && failure.isNotEmpty) {
          final description =
              request.uri.queryParameters['error_description'] ?? failure;
          await _respond(request, HttpStatus.badRequest, description);
          throw OAuthAuthorizationFailure(
            'ChatGPT sign in failed: $description',
          );
        }
        final code = request.uri.queryParameters['code'];
        if (code == null || code.isEmpty) {
          await _respond(
            request,
            HttpStatus.badRequest,
            'Authorization code missing',
          );
          continue;
        }
        final OAuthCredential credential;
        try {
          credential = await _exchangeCode(
            code: code,
            verifier: verifier,
            redirectUri: redirectUri,
          );
        } on OAuthAuthorizationFailure catch (failure) {
          // Answer the browser before closing, otherwise the tab shows a
          // connection reset instead of the reason the exchange failed.
          await _respond(request, HttpStatus.badRequest, failure.message);
          rethrow;
        }
        await _respond(request, HttpStatus.ok, 'Sign in complete.');
        return credential;
      }
      throw StateError('OpenAI OAuth callback server closed.');
    } finally {
      await server.close(force: true);
    }
  }

  Future<OAuthCredential> _pollDevice({
    required String deviceAuthId,
    required String userCode,
    required Duration interval,
    required DateTime expiresAt,
    required _CancellationFlag cancelled,
  }) async {
    while (_clock.nowUtc().isBefore(expiresAt)) {
      if (cancelled.cancelled) throw StateError('OAuth was cancelled.');
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          '$_issuer/api/accounts/deviceauth/token',
          data: <String, String>{
            'device_auth_id': deviceAuthId,
            'user_code': userCode,
          },
        );
        final data = response.data ?? const <String, dynamic>{};
        final code = data['authorization_code'];
        final verifier = data['code_verifier'];
        if (code is! String || verifier is! String) {
          throw const FormatException('Invalid OpenAI device token data.');
        }
        return await _exchangeCode(
          code: code,
          verifier: verifier,
          redirectUri: '$_issuer/deviceauth/callback',
        );
      } on DioException catch (error) {
        final status = error.response?.statusCode;
        if (status != HttpStatus.forbidden && status != HttpStatus.notFound) {
          rethrow;
        }
      }
      await _delay(interval);
    }
    throw TimeoutException('OpenAI device authorization expired.');
  }

  Future<OAuthCredential> _exchangeCode({
    required String code,
    required String verifier,
    required String redirectUri,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_issuer/oauth/token',
        data: <String, String>{
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
          'client_id': openAICodexOAuthClientId,
          'code_verifier': verifier,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      return _credentialFromTokens(response.data ?? const <String, dynamic>{});
    } on DioException catch (error) {
      // A raw Dio message names a status code the user cannot act on, so
      // report the OAuth error code the token endpoint actually returned.
      final data = error.response?.data;
      final reason = data is Map<String, dynamic>
          ? data['error_description'] ?? data['error']
          : null;
      throw OAuthAuthorizationFailure(
        'ChatGPT sign in could not be completed: '
        '${reason is String ? reason : 'the token exchange was rejected.'}',
      );
    }
  }

  OAuthCredential _credentialFromTokens(
    Map<String, dynamic> data, {
    String? fallbackRefreshToken,
    String? fallbackAccountId,
  }) {
    final accessToken = data['access_token'];
    final refreshToken = data['refresh_token'] ?? fallbackRefreshToken;
    if (accessToken is! String || refreshToken is! String) {
      throw const FormatException('Invalid OpenAI OAuth token response.');
    }
    final idToken = data['id_token'];
    final claims = _jwtClaims(idToken is String ? idToken : accessToken);
    final expiration = claims['exp'];
    final accountId = claims['chatgpt_account_id'];
    return OAuthCredential(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiration is num
          ? DateTime.fromMillisecondsSinceEpoch(
              expiration.toInt() * 1000,
              isUtc: true,
            )
          : _clock.nowUtc().add(const Duration(hours: 1)),
      accountId: accountId is String ? accountId : fallbackAccountId,
    );
  }

  static Future<void> _respond(
    HttpRequest request,
    int status,
    String message,
  ) async {
    // The identity provider controls `error_description`, so escape it rather
    // than reflect remote text into the local callback page verbatim.
    final body = htmlEscape.convert(message);
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.html
      ..write('<!doctype html><title>Tinest</title><p>$body</p>');
    await request.response.close();
  }

  static Map<String, dynamic> _jwtClaims(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return const <String, dynamic>{};
    try {
      final decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return decoded is Map<String, dynamic>
          ? decoded
          : const <String, dynamic>{};
    } on FormatException {
      return const <String, dynamic>{};
    }
  }

  static String _randomToken(int byteCount) {
    final random = Random.secure();
    final bytes = List<int>.generate(
      byteCount,
      (_) => random.nextInt(256),
      growable: false,
    );
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

final class _OpenAIOAuthSession implements ProviderOAuthSession {
  factory({
    required String authorizationUrl,
    required String? instructions,
    required DateTime expiresAt,
    required Future<OAuthCredential> completion,
    required Future<void> Function() onCancel,
    String? userCode,
  }) => _OpenAIOAuthSession._(
    authorizationUrl: authorizationUrl,
    instructions: instructions,
    expiresAt: expiresAt,
    completion: completion,
    onCancel: onCancel,
    userCode: userCode,
  );

  new _({
    required this.authorizationUrl,
    required this.instructions,
    required this.expiresAt,
    required this._completion,
    required this._onCancel,
    this.userCode,
  });

  @override
  final String authorizationUrl;
  @override
  final String? userCode;
  @override
  final String? instructions;
  @override
  final DateTime expiresAt;
  final Future<OAuthCredential> _completion;
  final Future<void> Function() _onCancel;

  @override
  Future<OAuthCredential> get completion => _completion;

  @override
  Future<void> cancel() => _onCancel();
}

final class _CancellationFlag {
  bool cancelled = false;
}
