import 'dart:async';

import 'package:agent/agent.dart';
import 'package:daemon/src/features/models/infrastructure/model_settings_service.dart';
import 'package:daemon/src/features/providers/infrastructure/provider_adapters.dart';
import 'package:daemon/src/features/providers/infrastructure/provider_auth.dart';
import 'package:daemon/src/features/providers/infrastructure/provider_catalog.dart';
import 'package:daemon/src/shared/infrastructure/persistence/repositories.dart';
import 'package:daemon/src/shared/ports/agent_protocol_mapping.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:protocol/protocol.dart';

/// Runtime provider selection resolved from one Markdown agent snapshot.
final class ResolvedAgentModel {
  /// Creates a resolved executable provider and model pair.
  const new({
    required this.connectionId,
    required this.modelId,
    required this.provider,
    this.capabilities = const AgentModelCapabilities(),
    this.limits,
    this.pricing,
  });

  /// Selected provider connection.
  final String connectionId;

  /// Selected model identifier.
  final String modelId;

  /// Executable provider adapter.
  final ModelGateway provider;

  /// Provider-neutral features the selected driver may require.
  final AgentModelCapabilities capabilities;

  /// Advertised limits of the model, when the catalog knows them.
  final ModelLimitsDto? limits;

  /// Advertised USD-per-million pricing used for session accounting.
  final ModelPricingDto? pricing;
}

/// Stable provider connection failure translated to a protocol error code.
final class ProviderConnectionFailure implements Exception {
  /// Creates a provider connection failure.
  const new(this.code, this.message);

  /// Stable machine-readable error code.
  final String code;

  /// User-safe failure description.
  final String message;

  @override
  String toString() => 'ProviderConnectionFailure($code): $message';
}

/// Resolves configured model selections into executable provider instances.
final class ProviderModelResolver {
  /// Creates a model resolver over the provider connection registry.
  const new(this._connections, {required this._defaultModel});

  final ProviderConnectionService _connections;
  final Future<ModelSelectionDto> Function() _defaultModel;

  /// Resolves the model policy declared by an Agent definition.
  Future<ResolvedAgentModel> resolveAgentModel(
    AgentModelSelectionDto selection,
  ) async {
    final selected = switch (selection.source) {
      AgentModelSource.fixed => ModelSelectionDto(
        modelId:
            selection.modelId ??
            (throw const FormatException(
              'A fixed Agent model requires a modelId.',
            )),
      ),
      AgentModelSource.session => await _defaultModel(),
    };
    return await resolveSelection(selected);
  }

  /// Resolves one concrete model selection.
  Future<ResolvedAgentModel> resolveSelection(ModelSelectionDto selection) =>
      _connections.resolveQualifiedModel(selection.qualifiedModelId);

  /// Resolves one canonical qualified model identifier.
  Future<ResolvedAgentModel> resolveQualifiedModel(String modelId) =>
      _connections.resolveQualifiedModel(modelId);

  /// Resolves one explicit provider connection and model.
  Future<ResolvedAgentModel> resolveExplicitModel(
    String connectionId,
    String modelId,
  ) => _connections.resolveExplicitModel(connectionId, modelId);

  /// Validates that one model is runnable on its connection.
  Future<ProviderModelDto> validateAgentModel(
    String connectionId,
    String modelId,
  ) => _connections.validateAgentModel(connectionId, modelId);

  /// Validates one qualified model identifier.
  Future<ProviderModelDto> validateQualifiedModel(String modelId) async {
    final resolved = await _connections.resolveQualifiedModel(modelId);
    return await _connections.validateAgentModel(
      resolved.connectionId,
      modelId,
    );
  }

  /// Validates submitted controls against one resolved connection and model.
  Future<void> validateModelControls(
    String connectionId,
    String modelId,
    Map<String, ModelControlValueDto> controls,
  ) => _connections.validateModelControls(connectionId, modelId, controls);

  /// Validates controls for one qualified model identifier.
  Future<void> validateQualifiedModelControls(
    String modelId,
    Map<String, ModelControlValueDto> controls,
  ) async {
    final resolved = await _connections.resolveQualifiedModel(modelId);
    await _connections.validateModelControls(
      resolved.connectionId,
      modelId,
      controls,
    );
  }

  /// Retains only values accepted by one resolved connection and model.
  Future<Map<String, ModelControlValueDto>> retainValidModelControls(
    String connectionId,
    String modelId,
    Map<String, ModelControlValueDto> controls,
  ) => _connections.retainValidModelControls(connectionId, modelId, controls);

  /// Retains controls accepted by one qualified model identifier.
  Future<Map<String, ModelControlValueDto>> retainValidQualifiedModelControls(
    String modelId,
    Map<String, ModelControlValueDto> controls,
  ) async {
    final resolved = await _connections.resolveQualifiedModel(modelId);
    return await _connections.retainValidModelControls(
      resolved.connectionId,
      modelId,
      controls,
    );
  }
}

/// Definition id recorded for connections built from custom configuration.
///
/// Not a vendor: only the presence of [ProviderConnectionDto.customConfig]
/// decides how a connection resolves. This id exists so a custom connection
/// never collides with a registered plugin id.
const String customProviderDefinitionId = 'custom';

/// Rewrites persisted references owned outside provider persistence.
abstract interface class ProviderModelReferenceUpdater {
  /// Replaces the qualified prefix everywhere outside provider storage.
  Future<void> rewrite(String oldPrefix, String newPrefix);
}

/// Owns provider connections while keeping runtime details out of the protocol.
final class ProviderConnectionService
    implements ProviderOAuthConnector, RunnableModelCatalog {
  /// Creates the provider connection service.
  factory({
    required ProviderRepository repository,
    required CredentialRepository credentials,
    required Clock clock,
    required ProviderRegistry registry,
    required BuiltInProviderCatalog catalog,
    IdGenerator ids = const UuidIdGenerator(),
    ProviderModelDiscovery? modelDiscovery,
    ModelGatewayFactory? providerFactory,
    ProviderCredentialRefresher? oauthRefresher,
    ModelGateway? fixedProvider,
    ProviderModelReferenceUpdater? referenceUpdater,
  }) => ProviderConnectionService._(
    referenceUpdater,
    repository: repository,
    credentials: credentials,
    ids: ids,
    clock: clock,
    registry: registry,
    catalog: catalog,
    modelDiscovery: modelDiscovery,
    providerFactory: providerFactory,
    oauthRefresher: oauthRefresher,
    fixedProvider: fixedProvider,
  );

  new _(
    this._referenceUpdater, {
    required this._repository,
    required this._credentials,
    required this._ids,
    required this._clock,
    required this._registry,
    required this._catalog,
    ProviderModelDiscovery? modelDiscovery,
    ModelGatewayFactory? providerFactory,
    this._oauthRefresher,
    this._fixedProvider,
  }) : _discoveryOverride = modelDiscovery,
       _factoryOverride = providerFactory;

  final ProviderRepository _repository;
  final CredentialRepository _credentials;
  final IdGenerator _ids;
  final Clock _clock;
  final ProviderRegistry _registry;
  final BuiltInProviderCatalog _catalog;
  final ProviderModelDiscovery? _discoveryOverride;
  final ModelGatewayFactory? _factoryOverride;
  final ProviderCredentialRefresher? _oauthRefresher;
  final ModelGateway? _fixedProvider;
  ProviderModelReferenceUpdater? _referenceUpdater;
  final StreamController<ProviderCatalogDto> _catalogUpdates =
      StreamController<ProviderCatalogDto>.broadcast(sync: true);
  final StreamController<void> _runnableModelChanges =
      StreamController<void>.broadcast(sync: true);
  Future<void>? _backgroundRefresh;
  final Map<String, String> _oauthPrefixReservations = <String, String>{};

  /// Background catalog refresh results.
  Stream<ProviderCatalogDto> get catalogUpdates => _catalogUpdates.stream;

  @override
  Stream<void> get runnableModelChanges => _runnableModelChanges.stream;

  /// Persistence coordinator currently attached by the composition root.
  ProviderModelReferenceUpdater? get referenceUpdater => _referenceUpdater;

  /// Attaches persistence that is initialized after the provider service.
  set referenceUpdater(ProviderModelReferenceUpdater updater) =>
      _referenceUpdater = updater;

  /// The definition a fixed test provider connects under.
  ///
  /// A fixed provider replaces every transport, so which vendor lends its
  /// bundled models is arbitrary; the first registered one keeps embedded
  /// runs deterministic.
  String get _fixedProviderDefinitionId => _registry.adapters.first.id;

  /// Loads explicitly stored credentials and starts catalog refresh.
  Future<void> initialize() async {
    await _credentials.load();
    if (_fixedProvider != null &&
        await _repository.getConnection(_fixedProviderDefinitionId) == null) {
      await _initializeFixedProvider();
    }
    _backgroundRefresh = _runBackgroundRefresh();
    unawaited(_backgroundRefresh);
  }

  Future<void> _runBackgroundRefresh() async {
    try {
      await refreshCatalog(force: false);
    } on Object {
      // Startup remains usable with the bundled catalog. The explicit refresh
      // path still reports its safe error state to clients.
    }
  }

  /// Waits for owned background work and releases the catalog event stream.
  Future<void> close() async {
    await _catalog.close();
    await _backgroundRefresh;
    await _catalogUpdates.close();
    await _runnableModelChanges.close();
  }

  Future<void> _initializeFixedProvider() async {
    final plugin = _registry.require(_fixedProviderDefinitionId);
    final now = _clock.nowUtc();
    final connection = ProviderConnectionDto(
      id: plugin.id,
      definitionId: plugin.id,
      modelPrefix: plugin.id,
      displayName: plugin.definition.name,
      status: ProviderConnectionStatus.connected,
      authKind: ProviderAuthKind.none,
      credentialOrigin: ProviderCredentialOrigin.none,
      createdAt: now,
      updatedAt: now,
    );
    await _repository.upsertConnection(connection);
    await _repository.replaceModels(
      connection.id,
      _seedModels(connection).values,
    );
  }

  /// Returns the safe public provider catalog.
  Future<ProviderCatalogDto> catalog() async => _catalog.catalog();

  /// Marks an explicit catalog refresh while retaining trusted runtime data.
  Future<ProviderCatalogDto> refreshCatalog({bool force = true}) async {
    if (_fixedProvider == null) {
      for (final connection in await _repository.listConnections()) {
        if (!_canRun(connection.status) ||
            (!force &&
                _clock.nowUtc().difference(connection.updatedAt) <
                    const Duration(minutes: 15))) {
          continue;
        }
        await _discoverAndSave(connection, _credentialFor(connection));
      }
    }
    final refreshed = await _catalog.refresh(force: force);
    for (final connection in await _repository.listConnections()) {
      if (connection.customConfig != null) continue;
      final models = <String, ProviderModelDto>{
        for (final model in await _repository.listModels(connection.id))
          model.id: model,
      };
      for (final metadata in _catalog.modelsFor(connection.definitionId)) {
        final qualifiedId = _qualify(connection.modelPrefix, metadata.id);
        models[qualifiedId] = ProviderModelDto(
          connectionId: connection.id,
          id: qualifiedId,
          providerModelId: metadata.id,
          label: metadata.label,
          source:
              _catalog.isRefreshedModel(connection.definitionId, metadata.id)
              ? ProviderModelSource.refreshed
              : ProviderModelSource.bundled,
          capabilities: metadata.capabilities,
          pricing: metadata.pricing,
          limits: metadata.limits,
        );
      }
      await _repository.replaceModels(connection.id, models.values);
    }
    _catalogUpdates.add(refreshed);
    _runnableModelChanges.add(null);
    return refreshed;
  }

  /// Returns all user-owned connections with deterministic ordering.
  Future<List<ProviderConnectionDto>> connections() async {
    final result = await _repository.listConnections();
    result.sort((left, right) {
      final byName = left.displayName.compareTo(right.displayName);
      if (byName != 0) return byName;
      return left.modelPrefix.compareTo(right.modelPrefix);
    });
    return result;
  }

  @override
  Future<List<ModelSelectionDto>> listRunnableModels() async {
    final selections = <ModelSelectionDto>[];
    for (final connection in await connections()) {
      if (!_canRun(connection.status)) continue;
      final models = await _repository.listModels(connection.id);
      models.sort((left, right) {
        final byLabel = left.label.compareTo(right.label);
        if (byLabel != 0) return byLabel;
        return left.id.compareTo(right.id);
      });
      for (final model in models) {
        if (!_isRunnableModel(model)) continue;
        selections.add(ModelSelectionDto(modelId: model.id));
      }
    }
    return selections;
  }

  /// Resolves one canonical `<prefix>/<provider-model-id>` selection.
  Future<ResolvedAgentModel> resolveQualifiedModel(String modelId) async {
    final connection = await _connectionForQualifiedModel(modelId);
    if (connection == null) {
      throw ProviderConnectionFailure(
        'provider_not_connected',
        'Provider model prefix is not connected: $modelId',
      );
    }
    return await resolveExplicitModel(connection.id, modelId);
  }

  Future<ProviderConnectionDto?> _connectionForQualifiedModel(
    String modelId,
  ) async {
    final separator = modelId.indexOf('/');
    if (separator <= 0 || separator == modelId.length - 1) {
      throw FormatException(
        'Model ID must be qualified as prefix/model: $modelId',
      );
    }
    final prefix = modelId.substring(0, separator).toLowerCase();
    return (await _repository.listConnections())
        .where((connection) => connection.modelPrefix.toLowerCase() == prefix)
        .firstOrNull;
  }

  /// Validates and resolves one explicitly chosen connection and model.
  Future<ResolvedAgentModel> resolveExplicitModel(
    String connectionId,
    String modelId,
  ) async {
    final model = await validateAgentModel(connectionId, modelId);
    return ResolvedAgentModel(
      connectionId: connectionId,
      modelId: model.providerModelId,
      provider: await resolve(connectionId, modelId: modelId),
      capabilities: agentCapabilities(model.capabilities),
      limits: model.limits,
      pricing: model.pricing,
    );
  }

  /// Returns one connection or fails when it does not exist.
  Future<ProviderConnectionDto> get(String id) async {
    final connection = await _repository.getConnection(id);
    if (connection == null) {
      throw ProviderConnectionFailure(
        'provider_not_connected',
        'Provider connection not found: $id',
      );
    }
    return connection;
  }

  /// Connects a hosted built-in provider with one API key.
  Future<ProviderConnectionDto> connectApiKey(
    String definitionId,
    String apiKey, {
    String? connectionId,
    String? modelPrefix,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw const FormatException('API key must not be empty.');
    }
    final plugin = _registry.require(definitionId);
    if (!_supportsFlow(plugin, AgentProviderAuthFlow.apiKey)) {
      throw StateError(
        '$definitionId does not support API key authentication.',
      );
    }
    final credential = ApiKeyCredential(apiKey);
    return await _connectBuiltIn(
      plugin,
      ProviderAuthKind.apiKey,
      ProviderCredentialOrigin.stored,
      credential,
      connectionId: connectionId,
      modelPrefix: modelPrefix,
    );
  }

  /// Connects a local built-in provider without authentication.
  Future<ProviderConnectionDto> connectNone(
    String definitionId, {
    String? connectionId,
    String? modelPrefix,
  }) async {
    final plugin = _registry.require(definitionId);
    if (!_supportsFlow(plugin, AgentProviderAuthFlow.none)) {
      throw StateError('$definitionId requires authentication.');
    }
    return await _connectBuiltIn(
      plugin,
      ProviderAuthKind.none,
      ProviderCredentialOrigin.none,
      null,
      connectionId: connectionId,
      modelPrefix: modelPrefix,
    );
  }

  @override
  Future<void> connectOAuth(
    String definitionId,
    OAuthCredential credential, {
    String? connectionId,
    String? modelPrefix,
  }) async {
    final plugin = _registry.require(definitionId);
    if (!_supportsFlow(plugin, AgentProviderAuthFlow.oauthBrowser) &&
        !_supportsFlow(plugin, AgentProviderAuthFlow.oauthDevice)) {
      throw StateError('$definitionId does not support OAuth.');
    }
    final id = connectionId;
    final reservedPrefix = id == null ? null : _oauthPrefixReservations[id];
    if (id != null &&
        (reservedPrefix == null || reservedPrefix != modelPrefix)) {
      throw const ProviderConnectionFailure(
        'model_prefix_conflict',
        'OAuth provider prefix reservation is no longer valid.',
      );
    }
    try {
      await _connectBuiltIn(
        plugin,
        ProviderAuthKind.oauth,
        ProviderCredentialOrigin.oauth,
        credential,
        connectionId: connectionId,
        modelPrefix: modelPrefix,
        reservedPrefix: reservedPrefix,
      );
    } finally {
      if (id != null) _oauthPrefixReservations.remove(id);
    }
  }

  @override
  Future<ProviderOAuthReservation> reserveOAuthConnection(
    String definitionId, {
    String? connectionId,
    String? modelPrefix,
  }) async {
    _registry.require(definitionId);
    final existing = connectionId == null ? null : await get(connectionId);
    if (existing != null && existing.definitionId != definitionId) {
      throw const ProviderConnectionFailure(
        'provider_definition_mismatch',
        'An existing connection cannot change provider definition.',
      );
    }
    final resolvedId = connectionId ?? _ids.generate();
    final prefix = await _reservePrefixFor(
      resolvedId,
      requested: modelPrefix ?? existing?.modelPrefix,
      fallback: definitionId,
    );
    return (connectionId: resolvedId, modelPrefix: prefix);
  }

  @override
  Future<void> releaseOAuthConnection(String connectionId) async {
    _oauthPrefixReservations.remove(connectionId);
  }

  /// Creates an advanced custom connection speaking a registered wire format.
  Future<ProviderConnectionDto> createCustom(
    String id,
    CustomProviderConfigDto config, {
    String? apiKey,
    String? modelPrefix,
  }) async {
    if (id.trim().isEmpty) {
      throw const FormatException('Custom provider ID must not be empty.');
    }
    final normalized = _validateCustom(config);
    final connectionId = _ids.generate();
    final prefix = await _reservePrefixFor(
      connectionId,
      requested: modelPrefix,
      fallback: normalized.name,
    );
    try {
      final credential = _customCredential(normalized, apiKey);
      if (credential != null) {
        await _credentials.setCredential(connectionId, credential);
      }
      final now = _clock.nowUtc();
      final connection = ProviderConnectionDto(
        id: connectionId,
        definitionId: customProviderDefinitionId,
        modelPrefix: prefix,
        displayName: normalized.name,
        status: ProviderConnectionStatus.connecting,
        authKind: normalized.authenticationRequired
            ? ProviderAuthKind.apiKey
            : ProviderAuthKind.none,
        credentialOrigin: credential == null
            ? ProviderCredentialOrigin.none
            : ProviderCredentialOrigin.stored,
        createdAt: now,
        updatedAt: now,
        customConfig: normalized,
      );
      return await _discoverAndSave(connection, credential);
    } on Object {
      await _credentials.removeCredential(connectionId);
      rethrow;
    } finally {
      _oauthPrefixReservations.remove(connectionId);
    }
  }

  /// Updates advanced settings for an existing custom connection.
  Future<ProviderConnectionDto> updateCustom(
    String id,
    CustomProviderConfigDto config, {
    String? apiKey,
  }) async {
    final current = await get(id);
    if (current.customConfig == null) {
      throw StateError('Built-in provider configuration is immutable.');
    }
    final normalized = _validateCustom(config);
    var credential = _credentials.credential(id);
    if (apiKey != null) {
      credential = _customCredential(normalized, apiKey);
      if (credential == null) {
        await _credentials.removeCredential(id);
      } else {
        await _credentials.setCredential(id, credential);
      }
    }
    final updated = current.copyWith(
      displayName: normalized.name,
      status: ProviderConnectionStatus.connecting,
      authKind: normalized.authenticationRequired
          ? ProviderAuthKind.apiKey
          : ProviderAuthKind.none,
      credentialOrigin: credential == null
          ? ProviderCredentialOrigin.none
          : ProviderCredentialOrigin.stored,
      updatedAt: _clock.nowUtc(),
      customConfig: normalized,
      error: null,
    );
    return await _discoverAndSave(updated, credential);
  }

  /// Disconnects a provider but preserves agents and historical metadata.
  Future<void> disconnect(String id) async {
    final connection = await get(id);
    await _credentials.removeCredential(id);
    await _repository.upsertConnection(
      connection.copyWith(
        status: ProviderConnectionStatus.disconnected,
        credentialOrigin: ProviderCredentialOrigin.none,
        updatedAt: _clock.nowUtc(),
        error: null,
      ),
    );
    _runnableModelChanges.add(null);
  }

  /// Changes one connection prefix and every provider-owned model identifier.
  Future<ProviderConnectionDto> updateModelPrefix(
    String id,
    String modelPrefix,
  ) async {
    final current = await get(id);
    final normalized = _validateRequestedPrefix(modelPrefix);
    if (normalized == current.modelPrefix) return current;
    final conflict = (await _repository.listConnections()).any(
      (connection) =>
          connection.id != id &&
          connection.modelPrefix.toLowerCase() == normalized,
    );
    if (conflict) {
      throw ProviderConnectionFailure(
        'model_prefix_conflict',
        'Model prefix is already in use: $normalized',
      );
    }
    final oldPrefix = current.modelPrefix;
    final models = await _repository.listModels(id);
    final updated = current.copyWith(
      modelPrefix: normalized,
      updatedAt: _clock.nowUtc(),
    );
    final updater = _referenceUpdater;
    var referencesUpdated = false;
    try {
      if (updater != null) {
        await updater.rewrite(oldPrefix, normalized);
        referencesUpdated = true;
      }
      await _repository.upsertConnection(updated);
      await _repository.replaceModels(
        id,
        models.map(
          (model) =>
              model.copyWith(id: _qualify(normalized, model.providerModelId)),
        ),
      );
      _runnableModelChanges.add(null);
      return updated;
    } catch (_) {
      await _repository.upsertConnection(current);
      await _repository.replaceModels(id, models);
      if (referencesUpdated) await updater!.rewrite(normalized, oldPrefix);
      rethrow;
    }
  }

  /// Permanently removes a custom provider connection.
  Future<void> deleteCustom(String id) async {
    final connection = await get(id);
    if (connection.customConfig == null) {
      throw StateError('Built-in provider connections cannot be deleted.');
    }
    await _credentials.removeCredential(id);
    await _repository.deleteConnection(id);
    _runnableModelChanges.add(null);
  }

  /// Returns cached and discovered models for a connection.
  Future<List<ProviderModelDto>> listModels(String connectionId) =>
      get(connectionId)
          .then((connection) => _repository.listModels(connection.id));

  /// Creates an executable provider without exposing secrets or endpoints.
  Future<ModelGateway> resolve(
    String connectionId, {
    required String modelId,
  }) async {
    if (_fixedProvider != null) return _fixedProvider;
    final connection = await get(connectionId);
    if (!_canRun(connection.status)) {
      throw ProviderConnectionFailure(
        'provider_not_connected',
        'Provider is not connected: $connectionId',
      );
    }
    var credential = _credentialFor(connection);
    if (connection.authKind != ProviderAuthKind.none && credential == null) {
      throw ProviderConnectionFailure(
        'provider_not_connected',
        'Provider credential is not configured: $connectionId',
      );
    }
    if (credential case final OAuthCredential oauthCredential
        when !oauthCredential.expiresAt.isAfter(
          _clock.nowUtc().add(const Duration(minutes: 5)),
        )) {
      credential = await _refreshOAuth(connection, oauthCredential);
    }
    final qualifiedModelId = modelId.contains('/')
        ? modelId
        : _qualify(connection.modelPrefix, modelId);
    final model = await _repository.getModel(connection.id, qualifiedModelId);
    final request = ModelGatewayRequest(
      connectionId: connection.id,
      endpoint: _endpointFor(connection),
      credential: credential,
      capabilities: agentCapabilities(
        model?.capabilities ?? const ModelCapabilitiesDto(),
      ),
    );
    final override = _factoryOverride;
    if (override != null) return override.create(request);
    return _adapterSourceFor(connection).createProvider(request);
  }

  Future<OAuthCredential> _refreshOAuth(
    ProviderConnectionDto connection,
    OAuthCredential credential,
  ) async {
    final refresher = _oauthRefresher;
    if (refresher == null) {
      throw StateError('OAuth credential refresh is not configured.');
    }
    try {
      final refreshed = await refresher.refresh(
        connection.id,
        connection.definitionId,
        credential,
      );
      await _credentials.setCredential(connection.id, refreshed);
      return refreshed;
    } on OAuthRefreshFailure catch (failure) {
      if (failure.reauthRequired) {
        await _repository.upsertConnection(
          connection.copyWith(
            status: ProviderConnectionStatus.reauthRequired,
            updatedAt: _clock.nowUtc(),
            error: failure.message,
          ),
        );
      }
      throw ProviderConnectionFailure(
        failure.reauthRequired
            ? 'provider_not_connected'
            : 'provider_unavailable',
        failure.message,
      );
    }
  }

  /// Verifies that a connected model can stream and call coding tools.
  ///
  /// Returns the validated model so a caller that needs its metadata, such as
  /// the context window, does not have to read it a second time.
  Future<ProviderModelDto> validateAgentModel(
    String connectionId,
    String modelId,
  ) async {
    final connection = await get(connectionId);
    if (!_canRun(connection.status)) {
      throw ProviderConnectionFailure(
        'provider_not_connected',
        'Provider is not connected: $connectionId',
      );
    }
    final qualifiedModelId = modelId.contains('/')
        ? modelId
        : _qualify(connection.modelPrefix, modelId);
    final model = await _repository.getModel(connection.id, qualifiedModelId);
    if (model == null) {
      throw ProviderConnectionFailure(
        'model_unavailable',
        'The configured model is unavailable: $qualifiedModelId',
      );
    }
    if (!_isRunnableModel(model)) {
      throw ProviderConnectionFailure(
        'model_unavailable',
        'The configured model cannot stream and call tools: $qualifiedModelId',
      );
    }
    return model;
  }

  /// Rejects unknown IDs, wrong value types, invalid choices and conflicts.
  Future<void> validateModelControls(
    String connectionId,
    String modelId,
    Map<String, ModelControlValueDto> controls,
  ) async {
    final model = await validateAgentModel(connectionId, modelId);
    _validatedControls(model.capabilities.controls, controls, reject: true);
  }

  /// Drops values that are not accepted by the target model.
  Future<Map<String, ModelControlValueDto>> retainValidModelControls(
    String connectionId,
    String modelId,
    Map<String, ModelControlValueDto> controls,
  ) async {
    final model = await validateAgentModel(connectionId, modelId);
    return _validatedControls(model.capabilities.controls, controls);
  }

  Future<ProviderConnectionDto> _connectBuiltIn(
    ProviderAdapter adapter,
    ProviderAuthKind authKind,
    ProviderCredentialOrigin origin,
    ProviderCredential? credential, {
    String? connectionId,
    String? modelPrefix,
    String? reservedPrefix,
  }) async {
    final now = _clock.nowUtc();
    final id = connectionId ?? _ids.generate();
    final existing = connectionId == null
        ? null
        : await _repository.getConnection(id);
    if (connectionId != null && existing == null && reservedPrefix == null) {
      throw ProviderConnectionFailure(
        'provider_not_connected',
        'Provider connection not found: $id',
      );
    }
    if (existing != null && existing.definitionId != adapter.id) {
      throw const ProviderConnectionFailure(
        'provider_definition_mismatch',
        'An existing connection cannot change provider definition.',
      );
    }
    final ownsReservation = reservedPrefix == null;
    final prefix =
        reservedPrefix ??
        await _reservePrefixFor(
          id,
          requested: modelPrefix ?? existing?.modelPrefix,
          fallback: adapter.id,
        );
    final connection = ProviderConnectionDto(
      id: id,
      definitionId: adapter.id,
      modelPrefix: prefix,
      displayName: adapter.definition.name,
      status: ProviderConnectionStatus.connecting,
      authKind: authKind,
      credentialOrigin: origin,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      if (credential != null) await _credentials.setCredential(id, credential);
      return await _discoverAndSave(connection, credential);
    } finally {
      if (ownsReservation) _oauthPrefixReservations.remove(id);
    }
  }

  Future<ProviderConnectionDto> _discoverAndSave(
    ProviderConnectionDto connection,
    ProviderCredential? credential,
  ) async {
    await _repository.upsertConnection(connection);
    final endpoint = _endpointFor(connection);
    final models = <String, ProviderModelDto>{
      for (final model in await _repository.listModels(connection.id))
        model.id: model,
      ..._seedModels(connection),
    };
    ProviderConnectionStatus status;
    String? error;
    if (!endpoint.accepts(ProviderEndpointExtension.modelDiscovery)) {
      // The bundled catalog is already the complete model set for endpoints
      // without a `/models` listing, so a discovery request would only fail.
      status = ProviderConnectionStatus.connected;
    } else {
      try {
        final discovered = await _discoverModels(
          connection,
          endpoint,
          credential,
        );
        for (final providerModelId in discovered) {
          final modelId = _qualify(connection.modelPrefix, providerModelId);
          models.putIfAbsent(
            modelId,
            () => ProviderModelDto(
              connectionId: connection.id,
              id: modelId,
              providerModelId: providerModelId,
              label: providerModelId,
              source: ProviderModelSource.discovered,
              capabilities: _catalogCapabilities(
                connection.definitionId,
                providerModelId,
              ),
            ),
          );
        }
        status = ProviderConnectionStatus.connected;
      } on ProviderDiscoveryFailure catch (failure) {
        error = failure.message;
        status = switch (failure.kind) {
          ProviderDiscoveryFailureKind.invalidCredential =>
            ProviderConnectionStatus.error,
          ProviderDiscoveryFailureKind.unavailable =>
            ProviderConnectionStatus.degraded,
        };
      }
    }
    await _repository.replaceModels(connection.id, models.values);
    final saved = connection.copyWith(
      status: status,
      updatedAt: _clock.nowUtc(),
      error: error,
    );
    await _repository.upsertConnection(saved);
    _runnableModelChanges.add(null);
    return (await _repository.getConnection(saved.id)) ?? saved;
  }

  Map<String, ProviderModelDto> _seedModels(ProviderConnectionDto connection) {
    final result = <String, ProviderModelDto>{};
    for (final model in _catalog.modelsFor(connection.definitionId)) {
      final plugin = _registry.find(connection.definitionId);
      final capabilities = plugin == null
          ? model.capabilities
          : protocolCapabilities(
              plugin.capabilitiesForAuth(
                agentCapabilities(model.capabilities),
                AgentProviderAuthKind.values.byName(connection.authKind.name),
              ),
            );
      final id = _qualify(connection.modelPrefix, model.id);
      result[id] = ProviderModelDto(
        connectionId: connection.id,
        id: id,
        providerModelId: model.id,
        label: model.label,
        source: _catalog.isRefreshedModel(connection.definitionId, model.id)
            ? ProviderModelSource.refreshed
            : ProviderModelSource.bundled,
        capabilities: capabilities,
        pricing: model.pricing,
        limits: model.limits,
      );
    }
    for (final model
        in connection.customConfig?.models ??
            const <ManualProviderModelDto>[]) {
      final id = _qualify(connection.modelPrefix, model.id);
      result[id] = ProviderModelDto(
        connectionId: connection.id,
        id: id,
        providerModelId: model.id,
        label: model.label,
        source: ProviderModelSource.manual,
        capabilities: ModelCapabilitiesDto(
          streaming: CapabilitySupport.supported,
          toolCalling: CapabilitySupport.supported,
          functionTools: CapabilitySupport.supported,
          deferredTools: CapabilitySupport.unsupported,
          controls: model.controls,
          source: CapabilitySource.manual,
        ),
      );
    }
    return result;
  }

  ModelCapabilitiesDto _catalogCapabilities(
    String definitionId,
    String modelId,
  ) =>
      _catalog
          .modelsFor(definitionId)
          .where((model) => model.id == modelId)
          .map((model) => model.capabilities)
          .firstOrNull ??
      const ModelCapabilitiesDto();

  ProviderEndpoint _endpointFor(ProviderConnectionDto connection) {
    final custom = connection.customConfig;
    if (custom != null) {
      // A user-entered base URL may be anything, so it receives the neutral
      // baseline: it cannot be told to accept a field nobody has verified it
      // defines. Model discovery is the one exception, since a connection
      // with no bundled catalog has no other way to name a model.
      return ProviderEndpoint(
        baseUrl: custom.baseUrl,
        extensions: const <ProviderEndpointExtension>{
          ProviderEndpointExtension.modelDiscovery,
        },
      );
    }
    return _registry
        .require(connection.definitionId)
        .endpoint(agentAuthKind(connection.authKind));
  }

  /// The plugin or wire protocol that builds and discovers for [connection].
  ///
  /// A built-in connection asks its vendor; a custom connection asks the wire
  /// protocol its configuration names.
  ({
    ModelGateway Function(ModelGatewayRequest request) createProvider,
    Future<List<String>> Function(
      ProviderEndpoint endpoint,
      ProviderCredential? credential,
    )
    discoverModels,
  })
  _adapterSourceFor(ProviderConnectionDto connection) {
    final custom = connection.customConfig;
    if (custom != null) {
      final wire = _registry.requireWire(custom.wireFormatId);
      return (
        createProvider: wire.createProvider,
        discoverModels: wire.discoverModels,
      );
    }
    final plugin = _registry.require(connection.definitionId);
    return (
      createProvider: plugin.createProvider,
      discoverModels: plugin.discoverModels,
    );
  }

  Future<List<String>> _discoverModels(
    ProviderConnectionDto connection,
    ProviderEndpoint endpoint,
    ProviderCredential? credential,
  ) {
    final override = _discoveryOverride;
    if (override != null) return override.fetchModelIds(endpoint, credential);
    return _adapterSourceFor(connection).discoverModels(endpoint, credential);
  }

  ProviderCredential? _credentialFor(ProviderConnectionDto connection) =>
      switch (connection.credentialOrigin) {
        ProviderCredentialOrigin.stored || ProviderCredentialOrigin.oauth =>
          _credentials.credential(connection.id),
        ProviderCredentialOrigin.none => null,
      };

  Future<String> _availablePrefix(String requested) async {
    final base = _slugPrefix(requested);
    final used = <String>{
      for (final connection in await _repository.listConnections())
        connection.modelPrefix.toLowerCase(),
      ..._oauthPrefixReservations.values.map((prefix) => prefix.toLowerCase()),
    };
    if (!used.contains(base)) return base;
    var suffix = 2;
    while (used.contains('$base-$suffix')) {
      suffix += 1;
    }
    return '$base-$suffix';
  }

  Future<String> _allocatePrefix({
    required String connectionId,
    required String? requested,
    required String fallback,
  }) async {
    if (requested == null) return await _availablePrefix(fallback);
    final normalized = _validateRequestedPrefix(requested);
    final conflict = (await _repository.listConnections()).any(
      (connection) =>
          connection.id != connectionId &&
          connection.modelPrefix.toLowerCase() == normalized.toLowerCase(),
    );
    final reserved = _oauthPrefixReservations.entries.any(
      (entry) =>
          entry.key != connectionId &&
          entry.value.toLowerCase() == normalized.toLowerCase(),
    );
    if (conflict || reserved) {
      throw ProviderConnectionFailure(
        'model_prefix_conflict',
        'Model prefix is already in use: $normalized',
      );
    }
    return normalized;
  }

  Future<String> _reservePrefixFor(
    String connectionId, {
    required String? requested,
    required String fallback,
  }) async {
    final prefix = await _allocatePrefix(
      connectionId: connectionId,
      requested: requested,
      fallback: fallback,
    );
    _oauthPrefixReservations[connectionId] = prefix;
    return prefix;
  }

  static String _slugPrefix(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9_-]+'), '-')
        .replaceAll(RegExp('-+'), '-')
        .replaceAll(RegExp(r'^[-_]+|[-_]+$'), '');
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(normalized)) {
      throw const FormatException(
        'Model prefix must be a 1-64 character lowercase slug.',
      );
    }
    return normalized;
  }

  static String _validateRequestedPrefix(String value) {
    final normalized = value.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(normalized)) {
      throw const FormatException(
        'Model prefix must be a 1-64 character lowercase slug.',
      );
    }
    return normalized;
  }

  static String _qualify(String prefix, String providerModelId) =>
      '$prefix/$providerModelId';

  static bool _supportsFlow(
    ProviderAdapter adapter,
    AgentProviderAuthFlow flow,
  ) => adapter.definition.authMethods.any((method) => method.flow == flow);

  static bool _canRun(ProviderConnectionStatus status) =>
      status == ProviderConnectionStatus.connected ||
      status == ProviderConnectionStatus.degraded;

  /// Whether a model advertises everything a coding turn needs.
  ///
  /// [validateAgentModel] and the fallback chain share this predicate so the
  /// chain never hands back a model the validator would reject.
  static bool _isRunnableModel(ProviderModelDto model) =>
      model.capabilities.streaming == CapabilitySupport.supported &&
      model.capabilities.toolCalling == CapabilitySupport.supported;

  static ApiKeyCredential? _customCredential(
    CustomProviderConfigDto config,
    String? apiKey,
  ) {
    if (!config.authenticationRequired) return null;
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const FormatException('This custom provider requires an API key.');
    }
    return ApiKeyCredential(apiKey);
  }

  CustomProviderConfigDto _validateCustom(CustomProviderConfigDto config) {
    final uri = Uri.tryParse(config.baseUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException(
        'Custom provider base URL must be an absolute HTTP(S) URL.',
      );
    }
    if (_registry.findWire(config.wireFormatId) == null) {
      throw FormatException(
        'Unknown provider wire format: ${config.wireFormatId}',
      );
    }
    final wire = _registry.requireWire(config.wireFormatId);
    final seenModelIds = <String>{};
    final models = <ManualProviderModelDto>[];
    for (final model in config.models) {
      final id = model.id.trim();
      if (id.isEmpty || !seenModelIds.add(id)) continue;
      for (final control in model.controls) {
        final template = wire.controlDescriptors
            .where((candidate) => candidate.id == control.id)
            .firstOrNull;
        if (template == null) {
          throw FormatException(
            'Control ${control.id} is not supported by ${wire.label}.',
          );
        }
        // The wire owns the shape it can encode; the endpoint's owner owns the
        // values, because nobody here knows what an arbitrary base URL takes.
        if (protocolControlDescriptor(template)
                .copyWith(choices: control.choices) !=
            control) {
          throw FormatException(
            'Control ${control.id} does not match the shape ${wire.label} '
            'encodes.',
          );
        }
        if (control.kind == ModelControlKind.choice &&
            control.choices.isEmpty) {
          throw FormatException(
            'Control ${control.id} offers no values to choose from.',
          );
        }
      }
      models.add(
        model.copyWith(
          id: id,
          label: model.label.trim().isEmpty ? id : model.label.trim(),
        ),
      );
    }
    return config.copyWith(
      name: config.name.trim(),
      baseUrl: config.baseUrl.replaceAll(RegExp(r'/+$'), ''),
      models: models,
    );
  }
}

Map<String, ModelControlValueDto> _validatedControls(
  List<ModelControlDescriptorDto> descriptors,
  Map<String, ModelControlValueDto> values, {
  bool reject = false,
}) {
  final byId = <String, ModelControlDescriptorDto>{
    for (final descriptor in descriptors) descriptor.id: descriptor,
  };
  final accepted = <String, ModelControlValueDto>{};
  for (final entry in values.entries) {
    final descriptor = byId[entry.key];
    final valid =
        descriptor != null && _controlValueIsValid(descriptor, entry.value);
    if (!valid) {
      if (reject) {
        throw FormatException('Invalid value for model control ${entry.key}.');
      }
      continue;
    }
    final conflict = accepted.keys.firstWhere(
      (acceptedId) =>
          descriptor.conflictsWith.contains(acceptedId) ||
          byId[acceptedId]!.conflictsWith.contains(entry.key),
      orElse: () => '',
    );
    if (conflict.isNotEmpty) {
      if (reject) {
        throw FormatException(
          'Model controls ${entry.key} and $conflict conflict.',
        );
      }
      continue;
    }
    accepted[entry.key] = entry.value;
  }
  return Map<String, ModelControlValueDto>.unmodifiable(accepted);
}

bool _controlValueIsValid(
  ModelControlDescriptorDto descriptor,
  ModelControlValueDto value,
) => switch ((descriptor.kind, value)) {
  (ModelControlKind.choice, ModelControlStringValueDto(:final value)) =>
    descriptor.choices.any((choice) => choice.id == value),
  (ModelControlKind.toggle, ModelControlBoolValueDto()) => true,
  (ModelControlKind.integer, ModelControlIntValueDto(:final value)) =>
    (descriptor.minimum == null || value >= descriptor.minimum!) &&
        (descriptor.maximum == null || value <= descriptor.maximum!) &&
        (descriptor.step == null ||
            descriptor.minimum == null ||
            (value - descriptor.minimum!) % descriptor.step! == 0),
  _ => false,
};
