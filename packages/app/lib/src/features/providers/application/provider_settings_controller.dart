import 'dart:async';

import 'package:app/src/features/hosts/application/host_controller.dart';
import 'package:app/src/features/models/application/model_settings_controller.dart';
import 'package:app/src/features/providers/application/session_model_options.dart';
import 'package:client/client.dart';
import 'package:protocol/protocol.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'provider_settings_controller.g.dart';

/// ProviderSettingsState defines a public contract.
final class ProviderSettingsState {
  /// Creates a [ProviderSettingsState].
  const new({
    required this.catalog,
    required this.connections,
    this.models = const <String, List<ProviderModelDto>>{},
    this.authAttempts = const <String, ProviderAuthAttemptDto>{},
  });

  /// The catalog public API member.
  final ProviderCatalogDto catalog;

  /// User-owned provider connections.
  final List<ProviderConnectionDto> connections;

  /// The models public API member.
  final Map<String, List<ProviderModelDto>> models;

  /// Transient interactive authorization attempts.
  final Map<String, ProviderAuthAttemptDto> authAttempts;

  /// The copyWith public API member.
  ProviderSettingsState copyWith({
    ProviderCatalogDto? catalog,
    List<ProviderConnectionDto>? connections,
    Map<String, List<ProviderModelDto>>? models,
    Map<String, ProviderAuthAttemptDto>? authAttempts,
  }) => ProviderSettingsState(
    catalog: catalog ?? this.catalog,
    connections: connections ?? this.connections,
    models: models ?? this.models,
    authAttempts: authAttempts ?? this.authAttempts,
  );
}

@Riverpod(keepAlive: true, retry: noAutomaticRetry)
/// ProviderSettingsController defines a public contract.
class ProviderSettingsController extends _$ProviderSettingsController {
  StreamSubscription<ProviderAuthAttemptDto>? _events;
  StreamSubscription<ProviderCatalogDto>? _catalogEvents;

  @override
  Future<ProviderSettingsState?> build(String hostId) async {
    final api = await watchConnectedHostApi(ref, hostId);
    if (api == null) return null;
    _events = api.providers.authUpdates.listen(_handleEvent);
    _catalogEvents = api.providers.catalogUpdates.listen(_handleCatalogEvent);
    ref.onDispose(() {
      unawaited(_events?.cancel());
      unawaited(_catalogEvents?.cancel());
    });
    final connections = await api.providers.listProviderConnections();
    return ProviderSettingsState(
      catalog: await api.providers.listProviderCatalog(),
      connections: connections,
      models: await _connectedModels(api, connections),
    );
  }

  /// Loads every runnable connection's catalog before exposing the snapshot.
  Future<Map<String, List<ProviderModelDto>>> _connectedModels(
    TinestApi api,
    List<ProviderConnectionDto> connections,
  ) async {
    final usable = usableConnections(connections);
    final loaded = <String, List<ProviderModelDto>>{};
    await Future.wait<void>(
      usable.map((connection) async {
        loaded[connection.id] = await api.providers.listProviderModels(
          connection.id,
        );
      }),
    );
    return loaded;
  }

  /// The loadModels public API member.
  Future<void> loadModels(String connectionId) async {
    final runtime = (await ref.read(hostRegistryControllerProvider.future))
        .runtimes[hostId];
    if (runtime?.connected != true || state.asData?.value == null) return;
    final models = await runtime!.api!.providers.listProviderModels(
      connectionId,
    );
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData<ProviderSettingsState?>(
      current.copyWith(
        models: <String, List<ProviderModelDto>>{
          ...current.models,
          connectionId: models,
        },
      ),
    );
  }

  /// Lazily reads subscription quota when the context preview opens.
  Future<List<ProviderUsageDto>> loadUsage() async {
    final api = await _requireConnection();
    return await api.providers.listProviderUsage();
  }

  /// Connects a hosted built-in provider with an API key.
  Future<ProviderConnectionDto> connectApiKey(
    String definitionId,
    String apiKey, {
    String? connectionId,
    String? modelPrefix,
  }) async {
    final api = await _requireConnection();
    final result = await api.providers.connectProviderApiKey(
      definitionId,
      apiKey,
      connectionId: connectionId,
      modelPrefix: modelPrefix,
    );
    await _reload(api);
    return result;
  }

  /// Connects a local built-in provider without authentication.
  Future<ProviderConnectionDto> connectNone(
    String definitionId, {
    String? connectionId,
    String? modelPrefix,
  }) async {
    final api = await _requireConnection();
    final result = await api.providers.connectProviderNone(
      definitionId,
      connectionId: connectionId,
      modelPrefix: modelPrefix,
    );
    await _reload(api);
    return result;
  }

  /// Starts one provider's browser or device-code authorization.
  Future<ProviderAuthAttemptDto> startAuth(
    String definitionId,
    String methodId, {
    String? connectionId,
    String? modelPrefix,
  }) async {
    final api = await _requireConnection();
    final attempt = await api.providers.startProviderAuth(
      definitionId,
      methodId,
      connectionId: connectionId,
      modelPrefix: modelPrefix,
    );
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData<ProviderSettingsState?>(
        current.copyWith(
          authAttempts: <String, ProviderAuthAttemptDto>{
            ...current.authAttempts,
            attempt.id: attempt,
          },
        ),
      );
    }
    return attempt;
  }

  /// Cancels an interactive authorization attempt.
  Future<void> cancelAuth(String attemptId) async {
    final api = await _requireConnection();
    await api.providers.cancelProviderAuth(attemptId);
  }

  /// Disconnects a provider connection while retaining history.
  Future<void> disconnect(String connectionId) async {
    final api = await _requireConnection();
    await api.providers.disconnectProvider(connectionId);
    await _reload(api);
  }

  /// Changes a provider connection's globally unique model prefix.
  Future<void> updateModelPrefix(
    String connectionId,
    String modelPrefix,
  ) async {
    final api = await _requireConnection();
    await api.providers.updateProviderModelPrefix(connectionId, modelPrefix);
    await _reload(api);
  }

  /// Explicitly refreshes catalog metadata.
  Future<void> refreshCatalog() async {
    final api = await _requireConnection();
    await api.providers.refreshProviderCatalog();
    await _reload(api);
  }

  /// Creates an advanced custom provider speaking a registered wire format.
  Future<ProviderConnectionDto> createCustom(
    String id,
    CustomProviderConfigDto config, {
    String? apiKey,
    String? modelPrefix,
  }) async {
    final api = await _requireConnection();
    final result = await api.providers.createCustomProvider(
      id,
      config,
      apiKey: apiKey,
      modelPrefix: modelPrefix,
    );
    await _reload(api);
    return result;
  }

  /// Updates an advanced custom provider.
  Future<ProviderConnectionDto> updateCustom(
    String connectionId,
    CustomProviderConfigDto config, {
    String? apiKey,
  }) async {
    final api = await _requireConnection();
    final result = await api.providers.updateCustomProvider(
      connectionId,
      config,
      apiKey: apiKey,
    );
    await _reload(api);
    return result;
  }

  /// Deletes an advanced custom connection.
  Future<void> deleteCustom(String connectionId) async {
    final api = await _requireConnection();
    await api.providers.deleteCustomProvider(connectionId);
    await _reload(api);
  }

  Future<TinestApi> _requireConnection() => requireHostApi(ref, hostId);

  Future<void> _reload(TinestApi api) async {
    final current = state.asData?.value;
    final ProviderCatalogDto catalog;
    final List<ProviderConnectionDto> connections;
    final Map<String, List<ProviderModelDto>> connectedModels;
    try {
      catalog = await api.providers.listProviderCatalog();
      connections = await api.providers.listProviderConnections();
      connectedModels = await _connectedModels(api, connections);
    } on TinestClientException catch (error, stackTrace) {
      // A refresh that loses its daemon must not escape as an unhandled error.
      if (ref.mounted) {
        state = AsyncError<ProviderSettingsState?>(error, stackTrace);
      }
      return;
    }
    if (!ref.mounted) return;
    state = AsyncData<ProviderSettingsState?>(
      ProviderSettingsState(
        catalog: catalog,
        connections: connections,
        models: <String, List<ProviderModelDto>>{
          ...?current?.models,
          ...connectedModels,
        },
        authAttempts:
            current?.authAttempts ?? const <String, ProviderAuthAttemptDto>{},
      ),
    );
    ref.invalidate(modelSettingsControllerProvider(hostId));
  }

  void _handleEvent(ProviderAuthAttemptDto attempt) {
    if (!ref.mounted) return;
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData<ProviderSettingsState?>(
      current.copyWith(
        authAttempts: <String, ProviderAuthAttemptDto>{
          ...current.authAttempts,
          attempt.id: attempt,
        },
      ),
    );
    if (attempt.status == ProviderAuthAttemptStatus.succeeded) {
      unawaited(_requireConnection().then(_reload));
    }
  }

  void _handleCatalogEvent(ProviderCatalogDto catalog) {
    if (!ref.mounted) return;
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData<ProviderSettingsState?>(
      current.copyWith(catalog: catalog),
    );
    unawaited(_requireConnection().then(_reload));
  }
}
