import 'package:agent/agent.dart';
import 'package:daemon/src/features/providers/infrastructure/provider_adapters.dart';
import 'package:dio/dio.dart';
import 'package:protocol/protocol.dart';

/// Reads the authenticated ChatGPT quota surface used by Codex subscriptions.
final class OpenAIProviderUsageGateway implements ProviderUsageGateway {
  /// Creates the production usage transport.
  const new(this._dio);

  final Dio _dio;

  @override
  Future<ProviderUsagePayload> fetchOpenAIUsage(
    OAuthCredential credential,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://chatgpt.com/backend-api/wham/usage',
        options: Options(
          headers: <String, String>{
            'Authorization': 'Bearer ${credential.accessToken}',
            'Accept': 'application/json',
            'ChatGPT-Account-Id': ?credential.accountId,
          },
        ),
      );
      return parseOpenAIProviderUsage(
        response.data ?? const <String, dynamic>{},
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) {
        throw const ProviderUsageAuthorizationFailure();
      }
      throw const ProviderUsageUnavailable();
    }
  }
}

/// Parses the stable, non-secret subset of ChatGPT's quota response.
ProviderUsagePayload parseOpenAIProviderUsage(Map<String, dynamic> json) {
  final windows = <ProviderUsageWindowDto>[];
  void addWindow(ProviderUsageWindowKind kind, Object? raw) {
    if (raw is! Map) return;
    final value = Map<String, dynamic>.from(raw);
    final used = _number(value['used_percent']);
    if (used == null) return;
    windows.add(
      ProviderUsageWindowDto(
        kind: kind,
        usedPercent: used.clamp(0, 100).toDouble(),
        resetsAt: _reset(value),
      ),
    );
  }

  final rateLimit = json['rate_limit'];
  if (rateLimit is Map) {
    final limits = Map<String, dynamic>.from(rateLimit);
    addWindow(ProviderUsageWindowKind.session, limits['primary_window']);
    addWindow(ProviderUsageWindowKind.weekly, limits['secondary_window']);
  }
  final codeReview = json['code_review_rate_limit'];
  if (codeReview is Map) {
    addWindow(
      ProviderUsageWindowKind.codeReview,
      Map<String, dynamic>.from(codeReview)['primary_window'],
    );
  }
  final credits = json['credits'];
  final creditBalance = credits is Map
      ? _number(Map<String, dynamic>.from(credits)['balance'])
      : null;
  return ProviderUsagePayload(
    provider: 'OpenAI',
    plan: json['plan_type'] as String?,
    windows: windows,
    creditBalance: creditBalance,
  );
}

double? _number(Object? value) => switch (value) {
  num() => value.toDouble(),
  String() => double.tryParse(value),
  _ => null,
};

DateTime? _reset(Map<String, dynamic> value) {
  final seconds = _number(value['reset_at']);
  if (seconds != null) {
    return DateTime.fromMillisecondsSinceEpoch(
      (seconds * 1000).round(),
      isUtc: true,
    );
  }
  return null;
}
