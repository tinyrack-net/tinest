import 'package:agent/agent.dart';
import 'package:protocol/protocol.dart';

// Consumers of the daemon's provider ports need the request and endpoint
// shapes those ports exchange without importing the agent layer directly.
export 'package:agent/agent.dart'
    show
        ModelGatewayRequest,
        ProviderDiscoveryFailure,
        ProviderDiscoveryFailureKind,
        ProviderEndpoint;

/// Overrides every plugin's own model discovery when provided.
///
/// The daemon normally asks the vendor plugin; tests and embedded runs
/// substitute one deterministic listing for all of them through this port.
abstract interface class ProviderModelDiscovery {
  /// Fetches model identifiers for one provider connection.
  Future<List<String>> fetchModelIds(
    ProviderEndpoint endpoint,
    ProviderCredential? credential,
  );
}

/// Overrides every plugin's own adapter construction when provided.
///
/// Same shape as [ProviderAdapter.createProvider]; a test that wants to see
/// exactly what the daemon resolved records the request here instead of
/// standing up a transport.
abstract interface class ModelGatewayFactory {
  /// Creates a provider adapter for one connected provider.
  ModelGateway create(ModelGatewayRequest request);
}

/// Secret-bearing transport used only by the provider usage service.
abstract interface class ProviderUsageGateway {
  /// Reads OpenAI subscription quota using one Tinest-managed OAuth credential.
  Future<ProviderUsagePayload> fetchOpenAIUsage(OAuthCredential credential);
}

/// Provider-neutral quota payload returned by a usage transport.
final class ProviderUsagePayload {
  /// Creates a parsed quota payload.
  const new({
    required this.provider,
    required this.windows,
    this.plan,
    this.creditBalance,
    this.detail,
  });

  /// Provider display label.
  final String provider;

  /// Subscription plan name.
  final String? plan;

  /// Available quota windows.
  final List<ProviderUsageWindowDto> windows;

  /// Remaining prepaid credits, when reported.
  final double? creditBalance;

  /// Non-sensitive provider detail.
  final String? detail;
}

/// Signals that a quota endpoint rejected the current access token.
final class ProviderUsageAuthorizationFailure implements Exception {
  /// Creates an authorization failure.
  const new();
}

/// Safe transport failure with no vendor response body or credentials.
final class ProviderUsageUnavailable implements Exception {
  /// Creates an unavailable failure.
  const new();
}
