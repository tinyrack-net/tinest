import 'dart:async';

import 'package:agent/agent.dart';
import 'package:daemon/src/features/providers/infrastructure/provider_adapters.dart';
import 'package:daemon/src/features/providers/infrastructure/provider_auth.dart';
import 'package:daemon/src/shared/infrastructure/persistence/repositories.dart';
import 'package:protocol/protocol.dart';

/// Lazily reads provider subscription quota with bounded caching.
final class ProviderUsageService {
  /// Creates a provider usage service over Tinest-owned connections only.
  factory({
    required ProviderRepository repository,
    required CredentialRepository credentials,
    required ProviderUsageGateway gateway,
    required ProviderCredentialRefresher oauthRefresher,
    required Clock clock,
    Duration cacheDuration = const Duration(minutes: 5),
  }) => ProviderUsageService._(
    repository,
    credentials,
    gateway,
    oauthRefresher,
    clock,
    cacheDuration,
  );

  new _(
    this._repository,
    this._credentials,
    this._gateway,
    this._oauthRefresher,
    this._clock,
    this.cacheDuration,
  );

  final ProviderRepository _repository;
  final CredentialRepository _credentials;
  final ProviderUsageGateway _gateway;
  final ProviderCredentialRefresher _oauthRefresher;
  final Clock _clock;

  /// Lifetime of successful and failed snapshots.
  final Duration cacheDuration;

  final Map<String, _CachedUsage> _cache = <String, _CachedUsage>{};
  final Map<String, Future<ProviderUsageDto>> _inFlight =
      <String, Future<ProviderUsageDto>>{};

  /// Lists quota state for configured connections without reading other CLIs.
  Future<List<ProviderUsageDto>> listUsage() async {
    final connections = await _repository.listConnections();
    return await Future.wait(connections.map(_usageFor));
  }

  Future<ProviderUsageDto> _usageFor(ProviderConnectionDto connection) {
    final now = _clock.nowUtc();
    final cached = _cache[connection.id];
    if (cached != null && now.isBefore(cached.expiresAt)) {
      return Future<ProviderUsageDto>.value(cached.value);
    }
    final pending = _inFlight[connection.id];
    if (pending != null) return pending;
    final operation = _load(connection);
    _inFlight[connection.id] = operation;
    unawaited(
      operation.whenComplete(() {
        final _ = _inFlight.remove(connection.id);
      }),
    );
    return operation;
  }

  Future<ProviderUsageDto> _load(ProviderConnectionDto connection) async {
    final now = _clock.nowUtc();
    ProviderUsageDto result;
    final credential = _credentials.credential(connection.id);
    if (connection.definitionId != 'openai' ||
        connection.authKind != ProviderAuthKind.oauth ||
        credential is! OAuthCredential) {
      result = ProviderUsageDto(
        connectionId: connection.id,
        status: ProviderUsageStatus.unsupported,
        fetchedAt: now,
      );
    } else {
      try {
        final payload = await _fetchWithRefresh(connection, credential);
        result = ProviderUsageDto(
          connectionId: connection.id,
          status: ProviderUsageStatus.available,
          fetchedAt: now,
          provider: payload.provider,
          plan: payload.plan,
          windows: payload.windows,
          creditBalance: payload.creditBalance,
          detail: payload.detail,
        );
      } on ProviderUsageUnavailable {
        result = _error(connection.id, now);
      } on ProviderUsageAuthorizationFailure {
        result = _error(connection.id, now);
      } on OAuthRefreshFailure {
        result = _error(connection.id, now);
      }
    }
    _cache[connection.id] = _CachedUsage(result, now.add(cacheDuration));
    return result;
  }

  static ProviderUsageDto _error(String connectionId, DateTime fetchedAt) =>
      ProviderUsageDto(
        connectionId: connectionId,
        status: ProviderUsageStatus.error,
        fetchedAt: fetchedAt,
        provider: 'OpenAI',
        errorCode: 'provider_usage_unavailable',
      );

  Future<ProviderUsagePayload> _fetchWithRefresh(
    ProviderConnectionDto connection,
    OAuthCredential credential,
  ) async {
    try {
      return await _gateway.fetchOpenAIUsage(credential);
    } on ProviderUsageAuthorizationFailure {
      final refreshed = await _oauthRefresher.refresh(
        connection.id,
        connection.definitionId,
        credential,
      );
      await _credentials.setCredential(connection.id, refreshed);
      return await _gateway.fetchOpenAIUsage(refreshed);
    }
  }
}

final class _CachedUsage {
  const new(this.value, this.expiresAt);

  final ProviderUsageDto value;
  final DateTime expiresAt;
}
