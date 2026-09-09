import 'dart:async';

import 'package:agent/agent.dart';
import 'package:daemon/src/features/providers/infrastructure/openai/openai_usage_gateway.dart';
import 'package:daemon/src/features/providers/infrastructure/provider_adapters.dart';
import 'package:daemon/src/features/providers/infrastructure/provider_auth.dart';
import 'package:daemon/src/features/providers/infrastructure/provider_usage_service.dart';
import 'package:daemon/src/shared/infrastructure/persistence/repositories.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  test('parses session, weekly, review, reset, plan, and credits', () {
    final usage = parseOpenAIProviderUsage(<String, dynamic>{
      'plan_type': 'plus',
      'rate_limit': <String, dynamic>{
        'primary_window': <String, dynamic>{
          'used_percent': 25,
          'reset_at': 1767225600,
        },
        'secondary_window': <String, dynamic>{'used_percent': 50.5},
      },
      'code_review_rate_limit': <String, dynamic>{
        'primary_window': <String, dynamic>{'used_percent': 75},
      },
      'credits': <String, dynamic>{'balance': '3.5'},
    });

    expect(usage.plan, 'plus');
    expect(usage.creditBalance, 3.5);
    expect(
      usage.windows.map((window) => window.kind),
      ProviderUsageWindowKind.values,
    );
    expect(usage.windows.first.resetsAt, DateTime.utc(2026));
  }, tags: const <String>['feature_test__provider_usage__unit']);

  test(
    'single-flights, refreshes authorization once, and caches for five minutes',
    () async {
      final clock = _Clock(DateTime.utc(2026));
      final credentials = _Credentials(_credential('old'));
      final gateway = _Gateway();
      final refresher = _Refresher(_credential('fresh'));
      final service = ProviderUsageService(
        repository: _Providers(<ProviderConnectionDto>[_connection]),
        credentials: credentials,
        gateway: gateway,
        oauthRefresher: refresher,
        clock: clock,
      );
      gateway.failAuthorizationOnce = true;

      final first = service.listUsage();
      final second = service.listUsage();
      final values = await Future.wait(<Future<List<ProviderUsageDto>>>[
        first,
        second,
      ]);

      expect(values.first.single.status, ProviderUsageStatus.available);
      expect(gateway.calls, 2, reason: 'one rejected call and one retry');
      expect(refresher.calls, 1);
      expect(credentials.current, same(refresher.result));
      await service.listUsage();
      expect(gateway.calls, 2, reason: 'cached within five minutes');
      clock.now = clock.now.add(const Duration(minutes: 5));
      await service.listUsage();
      expect(gateway.calls, 3);
    },
    tags: const <String>['feature_test__provider_usage__unit'],
  );

  test('does not query unsupported API-key connections', () async {
    final gateway = _Gateway();
    final service = ProviderUsageService(
      repository: _Providers(<ProviderConnectionDto>[
        _connection.copyWith(authKind: ProviderAuthKind.apiKey),
      ]),
      credentials: _Credentials(const ApiKeyCredential('secret')),
      gateway: gateway,
      oauthRefresher: _Refresher(_credential('unused')),
      clock: _Clock(DateTime.utc(2026)),
    );

    expect(
      (await service.listUsage()).single.status,
      ProviderUsageStatus.unsupported,
    );
    expect(gateway.calls, 0);
  }, tags: const <String>['feature_test__provider_usage__unit']);

  test(
    'isolates quota transport failures behind a safe provider error',
    () async {
      final gateway = _Gateway()..failUnavailable = true;
      final service = ProviderUsageService(
        repository: _Providers(<ProviderConnectionDto>[_connection]),
        credentials: _Credentials(_credential('access')),
        gateway: gateway,
        oauthRefresher: _Refresher(_credential('unused')),
        clock: _Clock(DateTime.utc(2026)),
      );

      final result = (await service.listUsage()).single;

      expect(result.status, ProviderUsageStatus.error);
      expect(result.errorCode, 'provider_usage_unavailable');
      expect(
        result.detail,
        isNull,
        reason: 'raw transport errors stay private',
      );
    },
    tags: const <String>['feature_test__provider_usage__unit'],
  );
}

final _connection = ProviderConnectionDto(
  id: 'openai',
  definitionId: 'openai',
  displayName: 'OpenAI',
  status: ProviderConnectionStatus.connected,
  authKind: ProviderAuthKind.oauth,
  credentialOrigin: ProviderCredentialOrigin.oauth,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

OAuthCredential _credential(String token) => OAuthCredential(
  accessToken: token,
  refreshToken: 'refresh',
  expiresAt: DateTime.utc(2027),
  accountId: 'account',
);

final class _Clock implements Clock {
  new(this.now);
  DateTime now;

  @override
  DateTime nowUtc() => now;
}

final class _Gateway implements ProviderUsageGateway {
  int calls = 0;
  bool failAuthorizationOnce = false;
  bool failUnavailable = false;

  @override
  Future<ProviderUsagePayload> fetchOpenAIUsage(
    OAuthCredential credential,
  ) async {
    calls += 1;
    if (failUnavailable) throw const ProviderUsageUnavailable();
    if (failAuthorizationOnce) {
      failAuthorizationOnce = false;
      throw const ProviderUsageAuthorizationFailure();
    }
    return const ProviderUsagePayload(
      provider: 'OpenAI',
      plan: 'plus',
      windows: <ProviderUsageWindowDto>[],
    );
  }
}

final class _Refresher implements ProviderCredentialRefresher {
  new(this.result);
  final OAuthCredential result;
  int calls = 0;

  @override
  Future<OAuthCredential> refresh(
    String connectionId,
    String definitionId,
    OAuthCredential credential,
  ) async {
    calls += 1;
    return result;
  }
}

final class _Credentials implements CredentialRepository {
  new(this.current);
  ProviderCredential? current;

  @override
  String? get bearerToken => null;

  @override
  ProviderCredential? credential(String connectionId) => current;

  @override
  Map<String, String> get mcpSecrets => const <String, String>{};

  @override
  Future<void> load() async {}

  @override
  Future<void> removeCredential(String connectionId) async => current = null;

  @override
  Future<void> removeMcpSecret(String key) async {}

  @override
  Future<void> setCredential(
    String connectionId,
    ProviderCredential credential,
  ) async => current = credential;

  @override
  Future<void> setDaemonToken(String bearerToken) async {}

  @override
  Future<void> setMcpSecret(String key, String value) async {}
}

final class _Providers implements ProviderRepository {
  new(this.connections);
  final List<ProviderConnectionDto> connections;

  @override
  Future<void> deleteConnection(String id) async {}

  @override
  Future<void> deleteModel(String connectionId, String modelId) async {}

  @override
  Future<ProviderConnectionDto?> getConnection(String id) async =>
      connections.where((connection) => connection.id == id).firstOrNull;

  @override
  Future<ProviderModelDto?> getModel(
    String connectionId,
    String modelId,
  ) async => null;

  @override
  Future<List<ProviderConnectionDto>> listConnections() async => connections;

  @override
  Future<List<ProviderModelDto>> listModels(String connectionId) async =>
      const <ProviderModelDto>[];

  @override
  Future<void> replaceModels(
    String connectionId,
    Iterable<ProviderModelDto> models,
  ) async {}

  @override
  Future<ProviderConnectionDto> upsertConnection(
    ProviderConnectionDto connection,
  ) async => connection;

  @override
  Future<ProviderModelDto> upsertModel(ProviderModelDto model) async => model;
}
