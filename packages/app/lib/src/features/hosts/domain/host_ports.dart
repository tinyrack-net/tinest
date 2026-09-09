import 'dart:async';

import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:client/client.dart';

export 'package:app/src/app/composition/app_primitives.dart';

/// Stores daemon-independent application settings.
abstract interface class AppSettingsRepository {
  /// Loads settings, returning stable defaults for a fresh install.
  Future<AppSettings> loadSettings();

  /// Persists the complete settings value.
  Future<void> saveSettings(AppSettings settings);

  /// Drops the stored document so the next load returns fresh defaults.
  ///
  /// Settings and remote profiles share one document, so both are cleared.
  Future<void> clear();
}

/// Stores non-secret remote daemon profiles.
abstract interface class RemoteHostRepository {
  /// Lists every configured remote daemon.
  Future<List<RemoteDaemonProfile>> listProfiles();

  /// Creates or replaces one profile by ID.
  Future<void> upsertProfile(RemoteDaemonProfile profile);

  /// Deletes one profile by ID.
  Future<void> deleteProfile(String profileId);
}

/// Stores bearer tokens separately from non-secret profiles.
abstract interface class RemoteHostCredentialStore {
  /// Reads the bearer token for one profile.
  Future<String?> readBearerToken(String profileId);

  /// Writes the bearer token for one profile.
  Future<void> writeBearerToken(String profileId, String token);

  /// Deletes the bearer token for one profile.
  Future<void> deleteBearerToken(String profileId);

  /// Deletes every stored remote bearer token, including orphaned entries.
  Future<void> deleteAllBearerTokens();
}

/// Stores daemon-scoped relay device identities in platform secure storage.
abstract interface class RelayHostCredentialStore {
  /// Reads one relay device credential by its opaque storage key.
  Future<RelayHostCredential?> readRelayCredential(String credentialKey);

  /// Writes one relay device credential by its opaque storage key.
  Future<void> writeRelayCredential(
    String credentialKey,
    RelayHostCredential credential,
  );

  /// Deletes one relay device identity.
  Future<void> deleteRelayCredential(String credentialKey);

  /// Deletes every relay device identity owned by this app.
  Future<void> deleteAllRelayCredentials();
}

/// Opens one typed daemon API without owning profile persistence.
abstract interface class HostClientFactory {
  /// Connects and completes after the daemon handshake succeeds.
  Future<TinestApi> connect({
    required HostConnection connection,
    required HostConnectionCredential credential,
    required String clientId,
    required String clientKind,
  });
}

/// Consumes one fragment-protected relay pairing link.
abstract interface class HostRelayPairer {
  /// Registers a daemon-scoped device identity and returns persisted material.
  Future<RelayPairingResult> pair({
    required Uri pairingUrl,
    required String deviceId,
    required String deviceName,
    required String connectionId,
    required String credentialKey,
  });
}

/// Cancelable periodic path probe owned by one host runtime.
abstract interface class HostPathProbeTask {
  /// Stops future callbacks.
  void cancel();
}

/// Schedules deterministic host-path maintenance outside business logic.
abstract interface class HostPathProbeScheduler {
  /// Invokes [callback] every [interval] until the returned task is canceled.
  HostPathProbeTask periodic(
    Duration interval,
    Future<void> Function() callback,
  );
}

/// Production timer-backed probe scheduler.
final class SystemHostPathProbeScheduler implements HostPathProbeScheduler {
  /// Creates the system scheduler.
  const new();

  @override
  HostPathProbeTask periodic(
    Duration interval,
    Future<void> Function() callback,
  ) => _TimerHostPathProbeTask(interval, callback);
}

final class _TimerHostPathProbeTask implements HostPathProbeTask {
  new(Duration interval, Future<void> Function() callback)
    : _timer = Timer.periodic(interval, (_) => unawaited(callback()));

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

/// Running app-owned daemon information passed to the host registry.
abstract interface class EmbeddedDaemonSession {
  /// Bound local endpoint.
  HostEndpoint get endpoint;

  /// Full-access daemon credential.
  DaemonCredentials get credentials;

  /// Daemon identity known before the client handshake.
  String get serverId;

  /// Stops only this app-owned daemon.
  Future<void> stop();
}

/// Optional desktop port for starting an app-owned daemon.
abstract interface class EmbeddedDaemonLauncher {
  /// Starts one daemon session.
  Future<EmbeddedDaemonSession> start({
    required EmbeddedDaemonExposure exposure,
    required int port,
  });
}

/// Optional port for erasing the app-owned daemon's stored data.
///
/// Absent on surfaces that never own a daemon, where a reset clears only
/// device-local app settings.
abstract interface class EmbeddedDaemonDataEraser {
  /// Erases every daemon-owned file, preserving managed Git checkouts.
  ///
  /// The daemon must already be stopped. Throws [FactoryResetFailure] when
  /// the data directory cannot be erased, in which case nothing was deleted.
  Future<void> eraseAll();
}

/// Injectable asynchronous delay used by reconnect loops.
abstract interface class AppDelay {
  /// Completes after [duration].
  Future<void> wait(Duration duration);
}

/// Production wall-clock delay.
final class SystemAppDelay implements AppDelay {
  /// Creates the system delay adapter.
  const new();

  @override
  Future<void> wait(Duration duration) => Future<void>.delayed(duration);
}

/// Produces a capped retry delay for one-based attempts.
abstract interface class RetryDelayPolicy {
  /// Returns the delay for [attempt].
  Duration delayFor(int attempt);
}

/// Capped exponential retry policy shared by every host runtime.
final class ExponentialRetryDelayPolicy implements RetryDelayPolicy {
  /// Creates the default retry policy.
  const new();

  @override
  Duration delayFor(int attempt) =>
      Duration(seconds: (1 << (attempt - 1).clamp(0, 5)).clamp(1, 30));
}

/// Deterministic in-memory adapter used by unit and widget compositions.
final class MemoryAppStore
    implements
        AppSettingsRepository,
        RemoteHostRepository,
        RemoteHostCredentialStore,
        RelayHostCredentialStore {
  /// Creates an in-memory store.
  new({
    this.settings = const AppSettings(),
    this.factoryDefaults = const AppSettings(),
    List<RemoteDaemonProfile> profiles = const <RemoteDaemonProfile>[],
    Map<String, String> tokens = const <String, String>{},
  }) : profiles = List<RemoteDaemonProfile>.of(profiles),
       tokens = Map<String, String>.of(tokens);

  /// Current settings value.
  AppSettings settings;

  /// Settings [clear] restores.
  ///
  /// Production storage restores the compiled defaults, including the product
  /// daemon port. A test that starts a real daemon has to survive a reset
  /// without binding that machine-global port, so it overrides this instead.
  final AppSettings factoryDefaults;

  /// Current profile values.
  final List<RemoteDaemonProfile> profiles;

  /// Current bearer tokens keyed by profile ID.
  final Map<String, String> tokens;

  /// Relay identities keyed independently from direct bearer tokens.
  final Map<String, RelayHostCredential> relayCredentials =
      <String, RelayHostCredential>{};

  @override
  Future<void> clear() async {
    settings = factoryDefaults;
    profiles.clear();
  }

  @override
  Future<void> deleteAllBearerTokens() async => tokens.clear();

  @override
  Future<void> deleteAllRelayCredentials() async => relayCredentials.clear();

  @override
  Future<void> deleteBearerToken(String profileId) async {
    tokens.remove(profileId);
  }

  @override
  Future<void> deleteRelayCredential(String credentialKey) async {
    relayCredentials.remove(credentialKey);
  }

  @override
  Future<void> deleteProfile(String profileId) async {
    profiles.removeWhere((profile) => profile.id == profileId);
  }

  @override
  Future<List<RemoteDaemonProfile>> listProfiles() async =>
      List<RemoteDaemonProfile>.unmodifiable(profiles);

  @override
  Future<AppSettings> loadSettings() async => settings;

  @override
  Future<String?> readBearerToken(String profileId) async => tokens[profileId];

  @override
  Future<RelayHostCredential?> readRelayCredential(
    String credentialKey,
  ) async => relayCredentials[credentialKey];

  @override
  Future<void> saveSettings(AppSettings settings) async {
    this.settings = settings;
  }

  @override
  Future<void> upsertProfile(RemoteDaemonProfile profile) async {
    final index = profiles.indexWhere((item) => item.id == profile.id);
    if (index < 0) {
      profiles.add(profile);
    } else {
      profiles[index] = profile;
    }
  }

  @override
  Future<void> writeBearerToken(String profileId, String token) async {
    tokens[profileId] = token;
  }

  @override
  Future<void> writeRelayCredential(
    String credentialKey,
    RelayHostCredential credential,
  ) async {
    relayCredentials[credentialKey] = credential;
  }
}
