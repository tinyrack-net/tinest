import 'dart:async';

import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/features/hosts/application/host_registry.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:client/client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderListenableSelect;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'host_controller.g.dart';

/// Resolves a connected host API without subscribing to registry changes.
Future<TinestApi> requireHostApi(Ref ref, String hostId) async {
  final runtime = (await ref.read(hostRegistryControllerProvider.future))
      .runtimes[hostId];
  return connectedHostApi(runtime);
}

/// Watches one host's connected API instead of the whole registry.
///
/// A device-settings write, such as a pane ratio or the sidebar toggle, emits
/// a new registry state without touching any daemon connection. Selecting the
/// API identity keeps those writes from reloading, and re-issuing the RPCs of,
/// every host-scoped provider.
///
/// Its `loaded` field separates "the registry has not finished its first load"
/// from "the registry is loaded and this host is offline", which callers answer
/// differently.
///
/// The result is a record, rather than a class, so
/// [ProviderListenableSelect.select] compares it by value and skips every
/// notification that leaves this host's connection unchanged.
HostApiConnection watchHostConnection(Ref ref, String hostId) => ref.watch(
  hostRegistryControllerProvider.select((value) {
    if (value.hasError) {
      return (
        loaded: false,
        api: null,
        error: value.error,
        stackTrace: value.stackTrace,
      );
    }
    // `value`, not `asData`: a dependency-driven reload keeps the previous
    // registry but reports itself as loading.
    final registry = value.value;
    if (registry == null) {
      return (loaded: false, api: null, error: null, stackTrace: null);
    }
    final runtime = registry.runtimes[hostId];
    return (
      loaded: true,
      api: runtime?.connected == true ? runtime!.api : null,
      error: null,
      stackTrace: null,
    );
  }),
);

/// One host's connection as observed by [watchHostConnection].
typedef HostApiConnection = ({
  bool loaded,
  TinestApi? api,
  Object? error,
  StackTrace? stackTrace,
});

/// Reports one host's connected API to [onChanged] without rebuilding.
///
/// A provider that owns long-lived state cannot `watch` its connection: every
/// rebuild would discard that state. Listening leaves the provider's own build
/// untouched and lets it reconcile a reconnect in place. [onChanged] runs once
/// with the current API, which may be null while the registry is still loading.
void listenHostApi(
  Ref ref,
  String hostId,
  void Function(TinestApi? api) onChanged,
) => ref.listen(
  hostRegistryControllerProvider.select((value) {
    final runtime = value.value?.runtimes[hostId];
    return runtime?.connected == true ? runtime!.api : null;
  }),
  (previous, next) => onChanged(next),
  fireImmediately: true,
);

/// Awaits one host's connected API, or null once the host is known offline.
///
/// Stays loading while the registry has yet to answer and rethrows a registry
/// failure, so a caller only has to decide what an offline host means for it.
Future<TinestApi?> watchConnectedHostApi(Ref ref, String hostId) {
  final connection = watchHostConnection(ref, hostId);
  if (connection.error case final error?) {
    Error.throwWithStackTrace(error, connection.stackTrace ?? StackTrace.empty);
  }
  // The selector re-runs this build as soon as the registry answers.
  if (!connection.loaded) return Completer<TinestApi?>().future;
  return Future<TinestApi?>.value(connection.api);
}

/// Resolves the API inside a build, re-running once the daemon connects.
Future<TinestApi> watchHostApi(Ref ref, String hostId) async {
  final api = await watchConnectedHostApi(ref, hostId);
  // Internal invariant, not user copy: every caller gates on a connected
  // daemon, so this only fires on a bug. Left in English for the report.
  if (api == null) throw StateError('Online daemon connection required.');
  return api;
}

/// Returns the connected API or reports that an online daemon is required.
TinestApi connectedHostApi(HostRuntimeSnapshot? runtime) {
  final api = runtime?.api;
  if (api == null || runtime?.connected != true) {
    throw StateError('Online daemon connection required.');
  }
  return api;
}

/// Disables Riverpod's automatic retry for user-facing settings loads.
Duration? noAutomaticRetry(int retryCount, Object error) => null;

@Riverpod(keepAlive: true)
/// Riverpod bridge exposing the independently testable [HostRegistry].
class HostRegistryController extends _$HostRegistryController {
  StreamSubscription<HostRegistryState>? _changes;
  late HostRegistry _registry;

  @override
  Future<HostRegistryState> build() async {
    final services = ref.watch(appServicesProvider);
    _registry = HostRegistry(
      store: services.settings,
      profiles: services.profiles,
      credentials: services.credentials,
      clientFactory: services.clients,
      embeddedLauncher: services.embeddedLauncher,
      embeddedDataEraser: services.embeddedDataEraser,
      ids: ref.watch(appIdGeneratorProvider),
      clock: ref.watch(appClockProvider),
      delay: services.delay,
      pathProbeScheduler: services.pathProbeScheduler,
      relayPairer: services.relayPairer,
      clientKind: services.clientKind,
    );
    ref.onDispose(() => unawaited(_dispose()));
    final initial = await _registry.load();
    _changes = _registry.changes.listen((next) {
      state = AsyncData<HostRegistryState>(next);
    });
    return initial;
  }

  /// Adds a remote daemon without requiring it to be online.
  Future<RemoteDaemonProfile> addRemote({
    required String label,
    required String address,
    required String bearerToken,
    required bool autoConnect,
  }) => _registry.addRemote(
    label: label,
    address: address,
    bearerToken: bearerToken,
    autoConnect: autoConnect,
  );

  /// Registers a daemon from a one-time pairing link.
  Future<RemoteDaemonProfile> pairRemote({
    required Uri pairingUrl,
    required String deviceName,
    String? label,
    bool autoConnect = true,
  }) => _registry.pairRemote(
    pairingUrl: pairingUrl,
    deviceName: deviceName,
    label: label,
    autoConnect: autoConnect,
  );

  /// Updates one remote profile.
  Future<void> updateRemote({
    required String profileId,
    required String label,
    required String address,
    required bool autoConnect,
    String? replacementBearerToken,
  }) => _registry.updateRemote(
    profileId: profileId,
    label: label,
    address: address,
    autoConnect: autoConnect,
    replacementBearerToken: replacementBearerToken,
  );

  /// Removes one remote host and its secret.
  Future<void> removeRemote(String profileId) =>
      _registry.removeRemote(profileId);

  /// Connects one host immediately.
  Future<void> reconnect(String hostId) => _registry.reconnect(hostId);

  /// Enables or disables startup connection for one remote host.
  Future<void> setRemoteAutoConnect(String hostId, {required bool enabled}) =>
      _registry.setAutoConnect(hostId, enabled: enabled);

  /// Selects one host without requiring an online connection.
  Future<void> selectHost(String hostId) => _registry.selectHost(hostId);

  /// Enables or disables the app-owned desktop daemon.
  Future<void> setEmbeddedDaemonEnabled({required bool enabled}) =>
      _registry.setEmbeddedDaemonEnabled(enabled: enabled);

  /// Changes the app-owned daemon listener and restarts it when active.
  Future<void> setEmbeddedDaemonExposure(EmbeddedDaemonExposure exposure) =>
      _registry.setEmbeddedDaemonExposure(exposure);

  /// Changes the app-owned daemon port and restarts it when active.
  Future<void> setEmbeddedDaemonPort(int port) =>
      _registry.setEmbeddedDaemonPort(port);

  /// Erases stored daemon data and every device-local app setting.
  Future<void> resetToFactoryDefaults() => _registry.resetToFactoryDefaults();

  /// Persists the app UI language, where null follows the system locale.
  Future<void> setLocaleTag(String? tag) => _registry.setLocaleTag(tag);

  /// Persists the theme the app paints itself with.
  Future<void> setThemeMode(AppThemeMode mode) => _registry.setThemeMode(mode);

  /// Persists whether the operating system launches the app at login.
  Future<void> setStartAtBoot({required bool enabled}) =>
      _registry.setStartAtBoot(enabled: enabled);

  /// Persists whether a login-time launch starts hidden in the tray.
  Future<void> setStartMinimizedAtBoot({required bool enabled}) =>
      _registry.setStartMinimizedAtBoot(enabled: enabled);

  /// Stops every client and the app-owned daemon before the process exits.
  Future<void> shutdown() => _registry.shutdown();

  /// Persists whether the workspace sidebar is hidden.
  Future<void> setSidebarCollapsed({required bool collapsed}) =>
      _registry.setSidebarCollapsed(collapsed: collapsed);

  /// Persists a checkout selection and its visible session tabs.
  Future<void> saveWorkspaceUi({
    required WorkspaceSelection selection,
    required SessionTabPreference tabs,
  }) => _registry.saveWorkspaceUi(selection: selection, tabs: tabs);

  Future<void> _dispose() async {
    await _changes?.cancel();
    await _registry.close();
  }
}

@Riverpod(keepAlive: true)
/// The daemon that host-scoped screens read and write.
///
/// The saved [AppSettings.lastActiveHostId] wins so the choice survives a
/// restart and stays in step with the workspace window. It is allowed to name
/// an offline daemon, so the fallbacks only run when it names no daemon at all.
String? activeHostId(Ref ref) {
  final registry = ref.watch(hostRegistryControllerProvider).asData?.value;
  if (registry == null) return null;
  final runtimes = registry.runtimes;
  final saved = registry.settings.lastActiveHostId;
  if (saved != null && runtimes.containsKey(saved)) return saved;
  return runtimes.values.where((item) => item.connected).firstOrNull?.id ??
      runtimes.values.firstOrNull?.id;
}
