import 'package:agent/src/contracts.dart';

import 'package:agent/src/model.dart';

/// Secret credential material held only inside the daemon.
///
/// Never serialized to clients: the protocol package carries origins and
/// statuses, never the material itself.
sealed class ProviderCredential {
  const new();
}

/// API key credential material.
final class ApiKeyCredential extends ProviderCredential {
  /// Creates API key credential material.
  const new(this.key);

  /// Secret provider API key.
  final String key;
}

/// OAuth credential material for a subscription-backed provider.
final class OAuthCredential extends ProviderCredential {
  /// Creates OAuth credential material.
  const new({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.accountId,
  });

  /// Short-lived OAuth access token.
  final String accessToken;

  /// Rotating OAuth refresh token.
  final String refreshToken;

  /// UTC expiration instant for [accessToken].
  final DateTime expiresAt;

  /// Vendor account identifier some backends require as a header.
  final String? accountId;
}

/// One optional behaviour an endpoint may accept beyond the neutral baseline.
///
/// Absence is the safe answer: a request carrying none of these is accepted by
/// every transport the runtime speaks. Anything one endpoint accepts and
/// another rejects belongs here rather than in a request field or a default,
/// because one wire implementation serves many endpoints.
enum ProviderEndpointExtension {
  /// Accepts JSON tool schemas marked as strictly validated.
  strictToolSchemas,

  /// Accepts a declared output schema on a function tool.
  toolOutputSchemas,

  /// Accepts an opaque per-installation attribution identifier.
  requestAttribution,

  /// Accepts a request for expedited processing.
  expeditedProcessing,

  /// Returns opaque reasoning continuation data to replay on the next turn.
  reasoningContinuation,

  /// Accepts a request for author-written reasoning summaries.
  reasoningSummaries,

  /// Accepts a declaration that sibling tool calls may run together.
  concurrentToolCalls,

  /// Accepts documents inlined into a request, under the media types and
  /// size ceiling the transport speaking to it documents.
  ///
  /// Without it an attachment is described in text instead, which every
  /// endpoint understands.
  inlineDocuments,

  /// Exposes a model listing.
  ///
  /// Without it the bundled catalog is already the complete model set, so a
  /// discovery request would only fail.
  modelDiscovery,
}

/// One endpoint a transport adapter speaks to, and what it accepts.
final class ProviderEndpoint {
  /// Creates trusted endpoint configuration.
  ///
  /// [extensions] defaults to empty so an endpoint receives an optional field
  /// only once someone has stated that it accepts one.
  const new({
    required this.baseUrl,
    this.extensions = const <ProviderEndpointExtension>{},
  });

  /// Trusted base URL.
  final String baseUrl;

  /// Optional behaviours this endpoint documents.
  final Set<ProviderEndpointExtension> extensions;

  /// Whether this endpoint accepts [extension].
  bool accepts(ProviderEndpointExtension extension) =>
      extensions.contains(extension);
}

/// Everything needed to build one executable adapter.
final class ModelGatewayRequest {
  /// Creates the inputs of one adapter.
  const new({
    required this.connectionId,
    required this.endpoint,
    required this.credential,
    this.capabilities = const AgentModelCapabilities(),
  });

  /// Connection identifier exposed to the agent runtime.
  final String connectionId;

  /// Endpoint the adapter speaks to.
  final ProviderEndpoint endpoint;

  /// Secret material, or null for an unauthenticated endpoint.
  final ProviderCredential? credential;

  /// Advertised capabilities of the resolved model.
  ///
  /// The whole DTO rather than a fixed set of booleans, so a vendor can read
  /// the fields its own API documents without widening a shared signature.
  final AgentModelCapabilities capabilities;
}

/// Classifies model discovery failures without leaking transport exceptions.
enum ProviderDiscoveryFailureKind {
  /// The supplied credential was rejected.
  invalidCredential,

  /// Discovery is temporarily or permanently unavailable.
  unavailable,
}

/// Typed failure returned by provider model discovery.
final class ProviderDiscoveryFailure implements Exception {
  /// Creates a discovery failure.
  const new(this.kind, this.message);

  /// Stable failure classification.
  final ProviderDiscoveryFailureKind kind;

  /// User-safe diagnostic message.
  final String message;

  @override
  String toString() => 'ProviderDiscoveryFailure($kind): $message';
}

/// One wire protocol an adapter package implements.
///
/// A built-in vendor composes one of these with its trusted endpoint, and a
/// custom connection picks one directly in settings, so a new protocol is
/// implemented once and served to both.
abstract interface class ProviderWireProtocol {
  /// Stable identifier stored in custom connection configuration.
  String get id;

  /// Human-readable name shown when choosing a protocol.
  String get label;

  /// Complete control templates custom models may opt into.
  ///
  /// A wire may only list a control it actually encodes: a connection is
  /// offered exactly this set, so anything else is a setting that silently
  /// does nothing.
  List<AgentModelControlDescriptor> get controlDescriptors;

  /// Builds the executable adapter for one resolved model.
  ModelGateway createProvider(ModelGatewayRequest request);

  /// Lists model identifiers from the live endpoint.
  ///
  /// Only called when the endpoint supports discovery. Throws
  /// [ProviderDiscoveryFailure] on a classified failure.
  Future<List<String>> discoverModels(
    ProviderEndpoint endpoint,
    ProviderCredential? credential,
  );
}

/// Immutable metadata for a coding-capable provider model.
final class ProviderCatalogModel {
  /// Creates bundled model metadata.
  const new({
    required this.id,
    required this.label,
    required this.capabilities,
    this.pricing,
    this.limits,
  });

  /// Provider model identifier.
  final String id;

  /// Human-readable model label.
  final String label;

  /// Capabilities sourced from the bundled catalog.
  final AgentModelCapabilities capabilities;

  /// Optional catalog pricing metadata.
  final AgentModelPricing? pricing;

  /// Optional catalog token limits.
  final AgentModelLimits? limits;
}

/// One running OAuth browser or device-code session.
abstract interface class ProviderOAuthSession {
  /// URL the user must open to continue authorization.
  String get authorizationUrl;

  /// Optional code shown for device authorization.
  String? get userCode;

  /// Optional user-facing instructions.
  String? get instructions;

  /// UTC expiration instant for the attempt.
  DateTime get expiresAt;

  /// Completes with tokens after the remote authorization succeeds.
  Future<OAuthCredential> get completion;

  /// Cancels the callback server or device polling loop.
  Future<void> cancel();
}

/// Starts one vendor's OAuth sessions and refreshes rotating tokens.
abstract interface class ProviderOAuthGateway {
  /// Starts one browser or device-code authorization session.
  Future<ProviderOAuthSession> start(AgentProviderAuthFlow flow);

  /// Refreshes one OAuth credential, preserving refresh-token rotation.
  Future<OAuthCredential> refresh(OAuthCredential credential);
}

/// Typed OAuth refresh failure with an explicit reauthentication decision.
final class OAuthRefreshFailure implements Exception {
  /// Creates a refresh failure safe to persist as connection status metadata.
  const new(this.message, {required this.reauthRequired});

  /// Human-readable failure without credential material.
  final String message;

  /// Whether the refresh token is permanently unusable.
  final bool reauthRequired;

  @override
  String toString() => 'OAuthRefreshFailure: $message';
}

/// Typed failure raised while authorizing, before any credential exists.
final class OAuthAuthorizationFailure implements Exception {
  /// Creates an authorization failure safe to show as attempt metadata.
  const new(this.message);

  /// Human-readable failure without credential material.
  final String message;

  /// The coordinator publishes `'$error'` straight to the attempt tile, so the
  /// bare sentence is the user-facing text.
  @override
  String toString() => message;
}

/// One provider transport adapter compiled into the daemon.
///
/// Everything one vendor is — its public metadata, bundled models, trusted
/// endpoint, transport adapter, and optional OAuth — travels together, so
/// adding a vendor is adding a package that exports one of these and
/// registering it in the composition root.
abstract base class ProviderAdapter {
  /// Allows subclasses to be const.
  const new();

  /// Catalog definition identifier.
  String get id;

  /// Public metadata safe to send to clients.
  AgentProviderDefinition get definition;

  /// Bundled, validated coding model metadata.
  List<ProviderCatalogModel> get models => const <ProviderCatalogModel>[];

  /// Trusted endpoint for one connection, given how it authenticated.
  ///
  /// The endpoint may depend on the credential: a subscription OAuth can speak
  /// to a different backend than the platform API key does.
  ProviderEndpoint endpoint(AgentProviderAuthKind authKind);

  /// Builds the executable adapter for one resolved model.
  ModelGateway createProvider(ModelGatewayRequest request);

  /// Lists model identifiers from the live endpoint.
  ///
  /// Only called when [endpoint] supports discovery. Throws
  /// [ProviderDiscoveryFailure] on a classified failure.
  Future<List<String>> discoverModels(
    ProviderEndpoint endpoint,
    ProviderCredential? credential,
  );

  /// OAuth support, or null when this vendor has none.
  ///
  /// Non-null exactly when [definition] lists an OAuth method: the daemon
  /// starts flows only for methods the definition advertises.
  ProviderOAuthGateway? get oauth => null;

  /// Whether a public model catalog reports identifiers this vendor accepts.
  ///
  /// An aggregator may namespace a vendor's models under its own identifiers,
  /// which the vendor's own API rejects; such a vendor serves bundled models
  /// only, because a refreshed entry would name a model no turn can run.
  bool get usesRemoteCatalog => true;

  /// Refines capability metadata fetched from a public model catalog.
  ///
  /// A public catalog reports what it knows about every vendor; the vendor
  /// itself may know more, such as inputs its API accepts for every model.
  AgentModelCapabilities refineRemoteCapabilities(
    AgentModelCapabilities capabilities,
  ) => capabilities;

  /// Narrows model controls for a credential-specific endpoint.
  AgentModelCapabilities capabilitiesForAuth(
    AgentModelCapabilities capabilities,
    AgentProviderAuthKind authKind,
  ) => capabilities;
}

/// The vendors and wire protocols compiled into the daemon.
final class ProviderRegistry {
  /// Creates a registry, rejecting duplicate identifiers.
  factory({
    required List<ProviderAdapter> adapters,
    required List<ProviderWireProtocol> wireProtocols,
  }) {
    final adapterIds = <String>{};
    for (final adapter in adapters) {
      if (!adapterIds.add(adapter.id)) {
        throw StateError('Two provider adapters claim the id ${adapter.id}.');
      }
      if (adapter.definition.id != adapter.id) {
        throw StateError(
          'Adapter ${adapter.id} advertises the id ${adapter.definition.id}.',
        );
      }
    }
    final wireIds = <String>{};
    for (final wire in wireProtocols) {
      if (!wireIds.add(wire.id)) {
        throw StateError('Two wire protocols claim the id ${wire.id}.');
      }
    }
    return ProviderRegistry._(
      List<ProviderAdapter>.unmodifiable(adapters),
      List<ProviderWireProtocol>.unmodifiable(wireProtocols),
    );
  }

  const new _(this.adapters, this.wireProtocols);

  /// Every vendor, in advertised order.
  final List<ProviderAdapter> adapters;

  /// Every wire protocol a custom connection may pick.
  final List<ProviderWireProtocol> wireProtocols;

  /// Returns one vendor, or null for an unknown definition.
  ProviderAdapter? find(String definitionId) =>
      adapters.where((adapter) => adapter.id == definitionId).firstOrNull;

  /// Returns one vendor or fails for an unknown definition.
  ProviderAdapter require(String definitionId) {
    final adapter = find(definitionId);
    if (adapter == null) {
      throw StateError('Unknown provider definition: $definitionId');
    }
    return adapter;
  }

  /// Returns one wire protocol, or null for an unknown identifier.
  ProviderWireProtocol? findWire(String wireId) =>
      wireProtocols.where((wire) => wire.id == wireId).firstOrNull;

  /// Returns one wire protocol or fails for an unknown identifier.
  ProviderWireProtocol requireWire(String wireId) {
    final wire = findWire(wireId);
    if (wire == null) {
      throw StateError('Unknown provider wire protocol: $wireId');
    }
    return wire;
  }
}
