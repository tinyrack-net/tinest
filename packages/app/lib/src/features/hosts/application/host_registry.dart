import 'dart:async';

import 'package:app/src/features/hosts/application/host_path_policy.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/hosts/domain/host_ports.dart';
import 'package:client/client.dart';

final class _RuntimeResource {
  new({required this.generation});

  int generation;
  int retryAttempt = 0;
  TinestApi? api;
  HostConnection? activeConnection;
  HostPathPolicy? pathPolicy;
  HostPathProbeTask? probeTask;
  int probeTick = 0;
  bool probing = false;
  // The owning HostRegistry cancels this subscription in _stopRuntime and
  // close.
  // ignore: cancel_subscriptions
  StreamSubscription<ClientConnectionState>? states;
}

final class _CleanupFailures {
  Object? _firstError;
  late StackTrace _firstStackTrace;

  Future<void> attempt(FutureOr<void> Function() operation) async {
    try {
      await operation();
    } on Object catch (error, stackTrace) {
      if (_firstError != null) return;
      _firstError = error;
      _firstStackTrace = stackTrace;
    }
  }

  void throwFirst() {
    final error = _firstError;
    if (error == null) return;
    Error.throwWithStackTrace(error, _firstStackTrace);
  }
}

/// Owns every daemon runtime while keeping connection failures independent.
final class HostRegistry {
  /// Creates a host registry from typed persistence and transport ports.
  factory({
    required AppSettingsRepository store,
    required HostClientFactory clientFactory,
    required AppIdGenerator ids,
    required AppClock clock,
    required AppDelay delay,
    required String clientKind,
    RemoteHostRepository? profiles,
    RemoteHostCredentialStore? credentials,
    EmbeddedDaemonLauncher? embeddedLauncher,
    EmbeddedDaemonDataEraser? embeddedDataEraser,
    RetryDelayPolicy retryPolicy = const ExponentialRetryDelayPolicy(),
    HostPathProbeScheduler? pathProbeScheduler,
    HostRelayPairer? relayPairer,
  }) => HostRegistry._(
    settings: store,
    profiles: profiles ?? _requireProfiles(store),
    credentials: credentials ?? _requireCredentials(store),
    clientFactory: clientFactory,
    embeddedLauncher: embeddedLauncher,
    embeddedDataEraser: embeddedDataEraser,
    ids: ids,
    clock: clock,
    delay: delay,
    clientKind: clientKind,
    retryPolicy: retryPolicy,
    pathProbeScheduler: pathProbeScheduler,
    relayPairer: relayPairer,
  );

  new _({
    required this._settings,
    required this._profiles,
    required this._credentials,
    required this._clientFactory,
    required this._embeddedLauncher,
    required this._embeddedDataEraser,
    required this._ids,
    required this._clock,
    required this._delay,
    required this._clientKind,
    required this._retryPolicy,
    required this._pathProbeScheduler,
    required this._relayPairer,
  });

  final AppSettingsRepository _settings;
  final RemoteHostRepository _profiles;
  final RemoteHostCredentialStore _credentials;
  final HostClientFactory _clientFactory;
  final EmbeddedDaemonLauncher? _embeddedLauncher;
  final EmbeddedDaemonDataEraser? _embeddedDataEraser;
  final AppIdGenerator _ids;
  final AppClock _clock;
  final AppDelay _delay;
  final String _clientKind;
  final RetryDelayPolicy _retryPolicy;
  final HostPathProbeScheduler? _pathProbeScheduler;
  final HostRelayPairer? _relayPairer;
  final Map<String, _RuntimeResource> _resources = <String, _RuntimeResource>{};
  final Map<String, String> _serverOwners = <String, String>{};
  final StreamController<HostRegistryState> _changes =
      StreamController<HostRegistryState>.broadcast(sync: true);
  EmbeddedDaemonSession? _embeddedSession;
  Future<void> _embeddedLifecycle = Future<void>.value();
  Future<void>? _closeFuture;
  HostRegistryState? _state;
  bool _closed = false;
  bool _resetting = false;

  /// Latest loaded registry state.
  HostRegistryState get value =>
      _state ?? (throw StateError('HostRegistry.load must complete first.'));

  /// State changes after the initial [load].
  Stream<HostRegistryState> get changes => _changes.stream;

  /// Hydrates local settings without awaiting daemon startup or connections.
  Future<HostRegistryState> load() async {
    if (_state != null) return value;
    final settings = await _settings.loadSettings();
    final profiles = await _profiles.listProfiles();
    final runtimes = <String, HostRuntimeSnapshot>{
      if (settings.embeddedDaemonEnabled && _embeddedLauncher != null)
        embeddedHostId: const HostRuntimeSnapshot(
          id: embeddedHostId,
          label: embeddedDaemonFallbackLabel,
          kind: HostKind.embedded,
          status: HostRuntimeStatus.connecting,
        ),
      for (final profile in profiles)
        profile.id: HostRuntimeSnapshot(
          id: profile.id,
          label: profile.label,
          kind: HostKind.remote,
          status: profile.autoConnect
              ? HostRuntimeStatus.connecting
              : HostRuntimeStatus.idle,
          endpoint: _directConnection(profile)?.endpoint,
        ),
    };
    _state = HostRegistryState(
      settings: settings,
      profiles: List<RemoteDaemonProfile>.unmodifiable(profiles),
      runtimes: Map<String, HostRuntimeSnapshot>.unmodifiable(runtimes),
    );
    scheduleMicrotask(() {
      if (_closed) return;
      if (settings.embeddedDaemonEnabled && _embeddedLauncher != null) {
        unawaited(
          _serializeEmbedded(
            () => _startEmbedded(
              settings.embeddedDaemonExposure,
              settings.embeddedDaemonPort,
            ),
          ),
        );
      }
      for (final profile in profiles.where((profile) => profile.autoConnect)) {
        unawaited(_connectRemote(profile.id));
      }
    });
    return value;
  }

  /// Saves an offline-capable remote profile and optionally starts connecting.
  Future<RemoteDaemonProfile> addRemote({
    required String label,
    required String address,
    required String bearerToken,
    required bool autoConnect,
  }) async {
    _ensureLoaded();
    final endpoint = _parseEndpoint(address);
    final token = bearerToken.trim();
    if (token.isEmpty) {
      throw const HostConnectionFailure.authentication(
        'A bearer token is required.',
        reason: HostFailureReason.missingBearerToken,
      );
    }
    final now = _clock.nowUtc();
    final profileId = _ids.generate();
    final connection = DirectHostConnection(
      id: _ids.generate(),
      credentialKey: 'host:$profileId:direct',
      endpoint: endpoint,
    );
    final profile = RemoteDaemonProfile(
      id: profileId,
      label: label.trim().isEmpty
          ? endpoint.websocketUri.authority
          : label.trim(),
      connections: <HostConnection>[connection],
      autoConnect: autoConnect,
      createdAt: now,
      updatedAt: now,
    );
    await _credentials.writeBearerToken(connection.credentialKey, token);
    try {
      await _profiles.upsertProfile(profile);
    } on Exception {
      await _credentials.deleteBearerToken(connection.credentialKey);
      rethrow;
    }
    final nextProfiles = <RemoteDaemonProfile>[...value.profiles, profile];
    final nextRuntimes = Map<String, HostRuntimeSnapshot>.of(value.runtimes)
      ..[profile.id] = HostRuntimeSnapshot(
        id: profile.id,
        label: profile.label,
        kind: HostKind.remote,
        status: autoConnect
            ? HostRuntimeStatus.connecting
            : HostRuntimeStatus.idle,
        endpoint: endpoint,
      );
    _emit(
      value.copyWith(
        profiles: List<RemoteDaemonProfile>.unmodifiable(nextProfiles),
        runtimes: Map<String, HostRuntimeSnapshot>.unmodifiable(nextRuntimes),
      ),
    );
    if (autoConnect) unawaited(_connectRemote(profile.id));
    return profile;
  }

  /// Consumes a one-time link and persists a relay-only daemon profile.
  Future<RemoteDaemonProfile> pairRemote({
    required Uri pairingUrl,
    required String deviceName,
    String? label,
    bool autoConnect = true,
  }) async {
    _ensureLoaded();
    final pairer = _relayPairer;
    final relayCredentials = _relayCredentials;
    if (pairer == null || relayCredentials == null) {
      throw const HostConnectionFailure.network(
        'Relay pairing is unavailable on this platform.',
        reason: HostFailureReason.relayPairingUnavailable,
      );
    }
    final proposedProfileId = _ids.generate();
    final connectionId = _ids.generate();
    final proposedCredentialKey = 'host:$proposedProfileId:relay';
    final result = await pairer.pair(
      pairingUrl: pairingUrl,
      deviceId: _ids.generate(),
      deviceName: deviceName,
      connectionId: connectionId,
      credentialKey: proposedCredentialKey,
    );
    final existing = value.profiles
        .where((profile) => profile.serverId == result.connection.serverId)
        .firstOrNull;
    final profileId = existing?.id ?? proposedProfileId;
    final credentialKey = 'host:$profileId:relay';
    final relayConnection = RelayHostConnection(
      id: result.connection.id,
      credentialKey: credentialKey,
      serverId: result.connection.serverId,
      relayUri: result.connection.relayUri,
      daemonIdentityPublicKey: result.connection.daemonIdentityPublicKey,
    );
    final now = _clock.nowUtc();
    final previousRelay = existing?.relayConnections.firstOrNull;
    final profile = existing == null
        ? RemoteDaemonProfile(
            id: profileId,
            label: label?.trim().isNotEmpty == true
                ? label!.trim()
                : _defaultRelayLabel(result.connection.serverId),
            connections: <HostConnection>[relayConnection],
            autoConnect: autoConnect,
            serverId: relayConnection.serverId,
            createdAt: now,
            updatedAt: now,
          )
        : existing.copyWith(
            connections: <HostConnection>[
              ...existing.connections.where(
                (connection) => connection is! RelayHostConnection,
              ),
              relayConnection,
            ],
            autoConnect: autoConnect,
            serverId: relayConnection.serverId,
            updatedAt: now,
          );
    await relayCredentials.writeRelayCredential(
      credentialKey,
      result.credential,
    );
    try {
      await _profiles.upsertProfile(profile);
    } on Exception {
      await relayCredentials.deleteRelayCredential(credentialKey);
      rethrow;
    }
    if (previousRelay != null && previousRelay.credentialKey != credentialKey) {
      await relayCredentials.deleteRelayCredential(previousRelay.credentialKey);
    }
    if (existing != null) await _stopRuntime(profile.id);
    final profiles = existing == null
        ? <RemoteDaemonProfile>[...value.profiles, profile]
        : <RemoteDaemonProfile>[
            for (final item in value.profiles)
              if (item.id == profile.id) profile else item,
          ];
    _emit(
      value.copyWith(
        profiles: List<RemoteDaemonProfile>.unmodifiable(profiles),
        runtimes: Map<String, HostRuntimeSnapshot>.unmodifiable(
          Map<String, HostRuntimeSnapshot>.of(value.runtimes)
            ..[profile.id] = HostRuntimeSnapshot(
              id: profile.id,
              label: profile.label,
              kind: HostKind.remote,
              status: autoConnect
                  ? HostRuntimeStatus.connecting
                  : HostRuntimeStatus.idle,
              endpoint: _directConnection(profile)?.endpoint,
            ),
        ),
      ),
    );
    if (autoConnect) unawaited(_connectRemote(profile.id));
    return profile;
  }

  /// Updates one remote profile and restarts only its runtime.
  Future<void> updateRemote({
    required String profileId,
    required String label,
    required String address,
    required bool autoConnect,
    String? replacementBearerToken,
  }) async {
    final previous = _profile(profileId);
    final endpoint = _parseEndpoint(address);
    if (replacementBearerToken case final token? when token.trim().isNotEmpty) {
      await _credentials.writeBearerToken(
        previous.directConnections.firstOrNull?.credentialKey ??
            'host:$profileId:direct',
        token.trim(),
      );
    }
    final updated = previous.copyWith(
      label: label.trim().isEmpty
          ? endpoint.websocketUri.authority
          : label.trim(),
      connections: <HostConnection>[
        DirectHostConnection(
          id: previous.directConnections.firstOrNull?.id ?? _ids.generate(),
          credentialKey:
              previous.directConnections.firstOrNull?.credentialKey ??
              'host:$profileId:direct',
          endpoint: endpoint,
        ),
        ...previous.relayConnections,
      ],
      autoConnect: autoConnect,
      updatedAt: _clock.nowUtc(),
    );
    await _profiles.upsertProfile(updated);
    await _stopRuntime(profileId);
    _replaceProfile(updated);
    _replaceRuntime(
      HostRuntimeSnapshot(
        id: profileId,
        label: updated.label,
        kind: HostKind.remote,
        status: autoConnect
            ? HostRuntimeStatus.connecting
            : HostRuntimeStatus.idle,
        endpoint: endpoint,
      ),
    );
    if (autoConnect) unawaited(_connectRemote(profileId));
  }

  /// Enables or disables startup connection for one remote profile.
  Future<void> setAutoConnect(String profileId, {required bool enabled}) async {
    final profile = _profile(profileId);
    final updated = profile.copyWith(
      autoConnect: enabled,
      updatedAt: _clock.nowUtc(),
    );
    await _profiles.upsertProfile(updated);
    await _stopRuntime(profileId);
    _replaceProfile(updated);
    _replaceRuntime(
      HostRuntimeSnapshot(
        id: profileId,
        label: updated.label,
        kind: HostKind.remote,
        status: enabled ? HostRuntimeStatus.connecting : HostRuntimeStatus.idle,
        endpoint: _directConnection(updated)?.endpoint,
      ),
    );
    if (enabled) unawaited(_connectRemote(profileId));
  }

  /// Retries one host immediately and resets its backoff.
  Future<void> reconnect(String hostId) async {
    if (hostId == embeddedHostId) {
      await _serializeEmbedded(() async {
        await _stopEmbedded();
        _replaceRuntime(
          const HostRuntimeSnapshot(
            id: embeddedHostId,
            label: embeddedDaemonFallbackLabel,
            kind: HostKind.embedded,
            status: HostRuntimeStatus.connecting,
          ),
        );
        await _startEmbedded(
          value.settings.embeddedDaemonExposure,
          value.settings.embeddedDaemonPort,
        );
      });
      return;
    }
    await _stopRuntime(hostId);
    final profile = _profile(hostId);
    _replaceRuntime(
      HostRuntimeSnapshot(
        id: hostId,
        label: profile.label,
        kind: HostKind.remote,
        status: HostRuntimeStatus.connecting,
        endpoint: _directConnection(profile)?.endpoint,
      ),
    );
    await _connectRemote(hostId, manual: true);
  }

  /// Deletes one remote profile, runtime, and secret credential.
  Future<void> removeRemote(String profileId) async {
    await _stopRuntime(profileId);
    await _profiles.deleteProfile(profileId);
    for (final connection in _profile(profileId).connections) {
      switch (connection) {
        case DirectHostConnection():
          await _credentials.deleteBearerToken(connection.credentialKey);
        case RelayHostConnection():
          await _relayCredentials?.deleteRelayCredential(
            connection.credentialKey,
          );
      }
    }
    var settings = value.settings;
    if (settings.lastActiveHostId == profileId) {
      settings = settings.copyWith(clearLastActiveHost: true);
      await _settings.saveSettings(settings);
    }
    if (settings.lastWorktree?.hostId == profileId ||
        settings.sessionTabs.keys.any(
          (key) => key.startsWith('$profileId\u0000'),
        )) {
      settings = settings.copyWith(
        clearLastWorktree: settings.lastWorktree?.hostId == profileId,
        sessionTabs: Map<String, SessionTabPreference>.unmodifiable(
          Map<String, SessionTabPreference>.of(settings.sessionTabs)
            ..removeWhere((key, value) => key.startsWith('$profileId\u0000')),
        ),
      );
      await _settings.saveSettings(settings);
    }
    _emit(
      value.copyWith(
        settings: settings,
        profiles: List<RemoteDaemonProfile>.unmodifiable(
          value.profiles.where((profile) => profile.id != profileId),
        ),
        runtimes: Map<String, HostRuntimeSnapshot>.unmodifiable(
          Map<String, HostRuntimeSnapshot>.of(value.runtimes)
            ..remove(profileId),
        ),
      ),
    );
  }

  /// Persists a host selection without requiring it to be online.
  Future<void> selectHost(String hostId) async {
    final settings = value.settings.copyWith(lastActiveHostId: hostId);
    await _settings.saveSettings(settings);
    _emit(value.copyWith(settings: settings));
  }

  /// Persists the app UI language, where null follows the system locale.
  Future<void> setLocaleTag(String? tag) async {
    final settings = value.settings.copyWith(
      localeTag: tag,
      clearLocaleTag: tag == null,
    );
    await _settings.saveSettings(settings);
    _emit(value.copyWith(settings: settings));
  }

  /// Persists the theme the app paints itself with.
  Future<void> setThemeMode(AppThemeMode mode) async {
    final settings = value.settings.copyWith(themeMode: mode);
    await _settings.saveSettings(settings);
    _emit(value.copyWith(settings: settings));
  }

  /// Persists whether the operating system launches the app at login.
  Future<void> setStartAtBoot({required bool enabled}) async {
    final settings = value.settings.copyWith(startAtBoot: enabled);
    await _settings.saveSettings(settings);
    _emit(value.copyWith(settings: settings));
  }

  /// Persists whether a login-time launch starts hidden in the tray.
  Future<void> setStartMinimizedAtBoot({required bool enabled}) async {
    final settings = value.settings.copyWith(startMinimizedAtBoot: enabled);
    await _settings.saveSettings(settings);
    _emit(value.copyWith(settings: settings));
  }

  /// Persists whether the workspace sidebar is hidden on wide layouts.
  Future<void> setSidebarCollapsed({required bool collapsed}) async {
    final settings = value.settings.copyWith(sidebarCollapsed: collapsed);
    await _settings.saveSettings(settings);
    _emit(value.copyWith(settings: settings));
  }

  /// Persists the selected checkout and its locally-visible session tabs.
  Future<void> saveWorkspaceUi({
    required WorkspaceSelection selection,
    required SessionTabPreference tabs,
  }) async {
    final settings = value.settings.copyWith(
      lastActiveHostId: selection.hostId,
      lastWorktree: selection,
      sessionTabs: Map<String, SessionTabPreference>.unmodifiable(
        <String, SessionTabPreference>{
          ...value.settings.sessionTabs,
          selection.storageKey: tabs,
        },
      ),
    );
    await _settings.saveSettings(settings);
    _emit(value.copyWith(settings: settings));
  }

  /// Starts or stops only the app-owned desktop daemon.
  Future<void> setEmbeddedDaemonEnabled({required bool enabled}) async {
    if (_embeddedLauncher == null) return;
    await _serializeEmbedded(() async {
      final settings = value.settings.copyWith(
        embeddedDaemonEnabled: enabled,
        clearLastActiveHost:
            !enabled && value.settings.lastActiveHostId == embeddedHostId,
      );
      await _settings.saveSettings(settings);
      if (!enabled) {
        await _stopEmbedded();
        final runtimes = Map<String, HostRuntimeSnapshot>.of(value.runtimes)
          ..remove(embeddedHostId);
        _emit(
          value.copyWith(
            settings: settings,
            runtimes: Map<String, HostRuntimeSnapshot>.unmodifiable(runtimes),
          ),
        );
        return;
      }
      _emit(
        value.copyWith(
          settings: settings,
          runtimes: Map<String, HostRuntimeSnapshot>.unmodifiable(
            <String, HostRuntimeSnapshot>{
              ...value.runtimes,
              embeddedHostId: const HostRuntimeSnapshot(
                id: embeddedHostId,
                label: embeddedDaemonFallbackLabel,
                kind: HostKind.embedded,
                status: HostRuntimeStatus.connecting,
              ),
            },
          ),
        ),
      );
      await _startEmbedded(
        settings.embeddedDaemonExposure,
        settings.embeddedDaemonPort,
      );
    });
  }

  /// Persists and applies a listener exposure to the app-owned daemon.
  Future<void> setEmbeddedDaemonExposure(
    EmbeddedDaemonExposure exposure,
  ) async {
    if (_embeddedLauncher == null) return;
    await _serializeEmbedded(() async {
      final settings = value.settings.copyWith(
        embeddedDaemonExposure: exposure,
      );
      await _settings.saveSettings(settings);
      if (!settings.embeddedDaemonEnabled) {
        _emit(value.copyWith(settings: settings));
        return;
      }
      await _stopEmbedded();
      _emit(
        value.copyWith(
          settings: settings,
          runtimes: Map<String, HostRuntimeSnapshot>.unmodifiable(
            <String, HostRuntimeSnapshot>{
              ...value.runtimes,
              embeddedHostId: const HostRuntimeSnapshot(
                id: embeddedHostId,
                label: embeddedDaemonFallbackLabel,
                kind: HostKind.embedded,
                status: HostRuntimeStatus.connecting,
              ),
            },
          ),
        ),
      );
      await _startEmbedded(exposure, settings.embeddedDaemonPort);
    });
  }

  /// Persists and applies the app-owned daemon listener port.
  Future<void> setEmbeddedDaemonPort(int port) async {
    if (port < 1 || port > 65535) {
      throw RangeError.range(port, 1, 65535, 'port');
    }
    if (_embeddedLauncher == null) return;
    if (value.settings.embeddedDaemonPort == port) return;
    await _serializeEmbedded(() async {
      final settings = value.settings.copyWith(embeddedDaemonPort: port);
      await _settings.saveSettings(settings);
      if (!settings.embeddedDaemonEnabled) {
        _emit(value.copyWith(settings: settings));
        return;
      }
      await _stopEmbedded();
      _emit(
        value.copyWith(
          settings: settings,
          runtimes: Map<String, HostRuntimeSnapshot>.unmodifiable(
            <String, HostRuntimeSnapshot>{
              ...value.runtimes,
              embeddedHostId: const HostRuntimeSnapshot(
                id: embeddedHostId,
                label: embeddedDaemonFallbackLabel,
                kind: HostKind.embedded,
                status: HostRuntimeStatus.connecting,
              ),
            },
          ),
        ),
      );
      await _startEmbedded(settings.embeddedDaemonExposure, port);
    });
  }

  /// Erases stored daemon data and every device-local app setting.
  ///
  /// Managed Git checkouts stay on disk and remote daemons keep running; only
  /// their profiles and bearer tokens are dropped. The app-owned daemon
  /// restarts with a new server identity and a new bearer token.
  ///
  /// Throws [FactoryResetFailure] with
  /// [FactoryResetFailureReason.daemonStillRunning] or
  /// [FactoryResetFailureReason.filesystem] when stored daemon data could not
  /// be erased, in which case nothing was deleted and the daemon is restarted.
  Future<void> resetToFactoryDefaults() async {
    _ensureLoaded();
    if (_resetting) {
      throw const FactoryResetFailure(
        'A reset is already running.',
        reason: FactoryResetFailureReason.incomplete,
      );
    }
    _resetting = true;
    try {
      await _serializeEmbedded(_eraseEverything);
    } finally {
      _resetting = false;
    }
  }

  Future<void> _eraseEverything() async {
    // Releasing the daemon lock and the database handle has to happen before
    // any deletion, and every remote client before its token disappears.
    await _stopEmbedded();
    for (final hostId in List<String>.of(_resources.keys)) {
      await _stopRuntime(hostId);
    }
    _emit(value.copyWith(runtimes: const <String, HostRuntimeSnapshot>{}));

    final previous = value.settings;
    try {
      await _embeddedDataEraser?.eraseAll();
    } on FactoryResetFailure {
      // Nothing was deleted, so put the user back online before reporting.
      await _restoreAfterFailedErase(previous);
      rethrow;
    }

    try {
      await _credentials.deleteAllBearerTokens();
      await _relayCredentials?.deleteAllRelayCredentials();
      await _settings.clear();
    } on Exception catch (error) {
      throw FactoryResetFailure(
        '$error',
        reason: FactoryResetFailureReason.incomplete,
      );
    }

    final settings = await _settings.loadSettings();
    _emit(
      HostRegistryState(
        settings: settings,
        profiles: const <RemoteDaemonProfile>[],
        runtimes: Map<String, HostRuntimeSnapshot>.unmodifiable(
          <String, HostRuntimeSnapshot>{
            if (settings.embeddedDaemonEnabled && _embeddedLauncher != null)
              embeddedHostId: const HostRuntimeSnapshot(
                id: embeddedHostId,
                label: embeddedDaemonFallbackLabel,
                kind: HostKind.embedded,
                status: HostRuntimeStatus.connecting,
              ),
          },
        ),
      ),
    );
    if (settings.embeddedDaemonEnabled) {
      await _startEmbedded(
        settings.embeddedDaemonExposure,
        settings.embeddedDaemonPort,
      );
    }
  }

  Future<void> _restoreAfterFailedErase(AppSettings settings) async {
    if (!settings.embeddedDaemonEnabled || _embeddedLauncher == null) return;
    _replaceRuntime(
      const HostRuntimeSnapshot(
        id: embeddedHostId,
        label: embeddedDaemonFallbackLabel,
        kind: HostKind.embedded,
        status: HostRuntimeStatus.connecting,
      ),
    );
    await _startEmbedded(
      settings.embeddedDaemonExposure,
      settings.embeddedDaemonPort,
    );
  }

  Future<void> _startEmbedded(EmbeddedDaemonExposure exposure, int port) async {
    final launcher = _embeddedLauncher;
    if (launcher == null || _closed) return;
    try {
      final session = await launcher.start(exposure: exposure, port: port);
      if (_closed || !value.settings.embeddedDaemonEnabled) {
        await session.stop();
        return;
      }
      _embeddedSession = session;
      await _connect(
        hostId: embeddedHostId,
        connection: DirectHostConnection(
          id: embeddedHostId,
          credentialKey: embeddedHostId,
          endpoint: session.endpoint,
        ),
        credential: DirectHostCredential(session.credentials),
        retry: false,
      );
    } on Exception catch (error) {
      if (_closed) return;
      _setFailure(embeddedHostId, _failureFrom(error), retry: false);
    }
  }

  Future<void> _connectRemote(String profileId, {bool manual = false}) async {
    if (_closed) return;
    final profile = _profileOrNull(profileId);
    if (profile == null || (!manual && !profile.autoConnect)) return;
    final candidates = <(HostConnection, HostConnectionCredential)>[];
    for (final connection in profile.connections) {
      final credential = await _credentialFor(connection);
      if (credential != null) {
        candidates.add((connection, credential));
      }
    }
    if (candidates.isEmpty) {
      _setFailure(
        profileId,
        const HostConnectionFailure.authentication(
          'No bearer token is stored.',
          reason: HostFailureReason.noStoredBearerToken,
        ),
        retry: false,
      );
      return;
    }
    if (candidates.length > 1) {
      try {
        final winner = await _raceConnections(profile, candidates);
        await _connect(
          hostId: profileId,
          connection: winner.connection,
          credential: winner.credential,
          connectedApi: winner.api,
          retry: profile.autoConnect,
        );
      } on Exception catch (error) {
        final failure = _failureFrom(error);
        _setFailure(
          profileId,
          failure,
          retry: profile.autoConnect && failure.retryable,
        );
      }
      return;
    }
    final (connection, credential) = candidates.single;
    await _connect(
      hostId: profileId,
      connection: connection,
      credential: credential,
      retry: profile.autoConnect,
    );
  }

  Future<void> _connect({
    required String hostId,
    required HostConnection connection,
    required HostConnectionCredential credential,
    required bool retry,
    TinestApi? connectedApi,
  }) async {
    final resource = _resources.putIfAbsent(
      hostId,
      () => _RuntimeResource(generation: 0),
    );
    final generation = resource.generation;
    final fallbackApi = resource.api;
    final fallbackConnection = resource.activeConnection;
    _updateRuntime(
      hostId,
      (runtime) => runtime.copyWith(
        status: HostRuntimeStatus.connecting,
        endpoint: switch (connection) {
          DirectHostConnection(:final endpoint) => endpoint,
          RelayHostConnection() => null,
        },
        clearError: true,
        clearConflict: true,
      ),
    );
    try {
      final api =
          connectedApi ??
          await _clientFactory.connect(
            connection: connection,
            credential: credential,
            clientId: _ids.generate(),
            clientKind: _clientKind,
          );
      if (_closed || resource.generation != generation) {
        await api.close();
        return;
      }
      final expectedServerId = _profileOrNull(hostId)?.serverId;
      if (expectedServerId != null &&
          api.serverInfo.serverId != expectedServerId) {
        await api.close();
        throw const HostConnectionFailure.authentication(
          'Connection path resolved to a different daemon.',
          reason: HostFailureReason.serverIdentityMismatch,
        );
      }
      final conflictingHostId = _serverOwners[api.serverInfo.serverId];
      if (conflictingHostId != null && conflictingHostId != hostId) {
        await api.close();
        _updateRuntime(
          hostId,
          (runtime) => runtime.copyWith(
            status: HostRuntimeStatus.conflict,
            conflictingHostId: conflictingHostId,
            error: 'That daemon is already registered.',
            errorReason: HostFailureReason.duplicateDaemon,
            clearApi: true,
          ),
        );
        return;
      }
      _serverOwners[api.serverInfo.serverId] = hostId;
      final previousApi = resource.api;
      resource
        ..api = api
        ..activeConnection = connection
        ..retryAttempt = 0;
      await resource.states?.cancel();
      resource.states = api.states.listen(
        (state) => _handleClientState(hostId, api, state),
      );
      _updateRuntime(
        hostId,
        (runtime) => runtime.copyWith(
          status: HostRuntimeStatus.online,
          api: api,
          serverInfo: api.serverInfo,
          activeConnectionId: connection.id,
          clearError: true,
        ),
      );
      if (previousApi != null && previousApi != api) {
        await previousApi.close();
      }
      if (hostId != embeddedHostId) {
        final profile = _profile(hostId).copyWith(
          serverId: api.serverInfo.serverId,
          lastConnectedAt: _clock.nowUtc(),
          updatedAt: _clock.nowUtc(),
        );
        await _profiles.upsertProfile(profile);
        _replaceProfile(profile);
        resource.pathPolicy ??= HostPathPolicy(
          authoritativeServerId: api.serverInfo.serverId,
        );
        resource.pathPolicy!.selectInitial(connection);
        _startPathMonitoring(hostId, resource);
      }
    } on Exception catch (error) {
      if (_closed || resource.generation != generation) return;
      if (fallbackApi != null &&
          fallbackConnection != null &&
          identical(resource.api, fallbackApi)) {
        resource.pathPolicy?.selectInitial(fallbackConnection);
        _updateRuntime(
          hostId,
          (runtime) => runtime.copyWith(
            status: HostRuntimeStatus.online,
            api: fallbackApi,
            serverInfo: fallbackApi.serverInfo,
            activeConnectionId: fallbackConnection.id,
            clearError: true,
          ),
        );
        return;
      }
      final failure = _failureFrom(error);
      _setFailure(hostId, failure, retry: retry && failure.retryable);
      if (retry && failure.retryable) {
        resource.retryAttempt += 1;
        await _delay.wait(_retryPolicy.delayFor(resource.retryAttempt));
        if (_closed || resource.generation != generation) return;
        await _connectRemote(hostId);
      }
    }
  }

  void _startPathMonitoring(String hostId, _RuntimeResource resource) {
    final scheduler = _pathProbeScheduler;
    final profile = _profileOrNull(hostId);
    if (scheduler == null ||
        profile == null ||
        profile.connections.length < 2 ||
        resource.probeTask != null) {
      return;
    }
    resource.probeTask = scheduler.periodic(
      activeHostPathProbeInterval,
      () async {
        resource.probeTick += 1;
        await _probePaths(
          hostId,
          includeInactive: resource.probeTick % 12 == 0,
        );
      },
    );
  }

  Future<void> _probePaths(
    String hostId, {
    required bool includeInactive,
  }) async {
    final resource = _resources[hostId];
    final profile = _profileOrNull(hostId);
    final active = resource?.activeConnection;
    if (resource == null ||
        profile == null ||
        active == null ||
        resource.probing ||
        _closed) {
      return;
    }
    resource.probing = true;
    try {
      var probingInactive = includeInactive;
      var targets = probingInactive
          ? profile.connections
          : profile.connections
                .where((connection) => connection.id == active.id)
                .toList(growable: false);
      var observations = await Future.wait(targets.map(_probeConnection));
      final activeObservation = observations.firstOrNull;
      if (!probingInactive && activeObservation?.available != true) {
        targets = profile.connections;
        observations = await Future.wait(targets.map(_probeConnection));
        probingInactive = true;
      }
      if (!probingInactive) return;
      final selected = resource.pathPolicy?.evaluate(observations);
      if (selected == null || selected.id == active.id) return;
      final credential = await _credentialFor(selected);
      if (credential == null) return;
      await _connect(
        hostId: hostId,
        connection: selected,
        credential: credential,
        retry: profile.autoConnect,
      );
    } finally {
      resource.probing = false;
    }
  }

  Future<HostPathObservation> _probeConnection(
    HostConnection connection,
  ) async {
    final credential = await _credentialFor(connection);
    if (credential == null) return HostPathObservation.failure(connection);
    final started = _clock.nowUtc();
    try {
      final api = await _clientFactory.connect(
        connection: connection,
        credential: credential,
        clientId: _ids.generate(),
        clientKind: _clientKind,
      );
      final latency = _clock.nowUtc().difference(started);
      final serverId = api.serverInfo.serverId;
      await api.close();
      return HostPathObservation.success(
        connection,
        latency: latency,
        serverId: serverId,
      );
    } on Exception {
      return HostPathObservation.failure(connection);
    }
  }

  Future<HostConnectionCredential?> _credentialFor(
    HostConnection connection,
  ) async => switch (connection) {
    DirectHostConnection() => switch (await _credentials.readBearerToken(
      connection.credentialKey,
    )) {
      final String token when token.isNotEmpty => DirectHostCredential(
        DaemonCredentials(bearerToken: token),
      ),
      _ => null,
    },
    RelayHostConnection() => await _relayCredentials?.readRelayCredential(
      connection.credentialKey,
    ),
  };

  Future<_ConnectedPath> _raceConnections(
    RemoteDaemonProfile profile,
    List<(HostConnection, HostConnectionCredential)> candidates,
  ) {
    final completer = Completer<_ConnectedPath>();
    var remaining = candidates.length;
    Object? lastError;
    for (final (connection, credential) in candidates) {
      unawaited(
        _clientFactory
            .connect(
              connection: connection,
              credential: credential,
              clientId: _ids.generate(),
              clientKind: _clientKind,
            )
            .then((api) async {
              final expected = profile.serverId;
              if (expected != null && api.serverInfo.serverId != expected) {
                await api.close();
                throw const HostConnectionFailure.authentication(
                  'Connection path resolved to a different daemon.',
                  reason: HostFailureReason.serverIdentityMismatch,
                );
              }
              if (completer.isCompleted) {
                await api.close();
              } else {
                completer.complete(_ConnectedPath(connection, credential, api));
              }
            })
            .catchError((Object error) {
              lastError = error;
              remaining -= 1;
              if (remaining == 0 && !completer.isCompleted) {
                completer.completeError(lastError!);
              }
            }),
      );
    }
    return completer.future;
  }

  void _handleClientState(
    String hostId,
    TinestApi api,
    ClientConnectionState state,
  ) {
    if (_closed || value.runtimes[hostId]?.api != api) return;
    final status = switch (state) {
      ClientConnectionState.connected => HostRuntimeStatus.online,
      ClientConnectionState.connecting ||
      ClientConnectionState.reconnecting => HostRuntimeStatus.reconnecting,
      ClientConnectionState.disconnected => HostRuntimeStatus.offline,
    };
    _updateRuntime(hostId, (runtime) => runtime.copyWith(status: status));
    final hasFailoverPath =
        (_profileOrNull(hostId)?.connections.length ?? 0) > 1;
    if (hasFailoverPath &&
        (state == ClientConnectionState.reconnecting ||
            state == ClientConnectionState.disconnected)) {
      unawaited(_probePaths(hostId, includeInactive: true));
    }
  }

  void _setFailure(
    String hostId,
    HostConnectionFailure failure, {
    required bool retry,
  }) {
    _updateRuntime(
      hostId,
      (runtime) => runtime.copyWith(
        status: retry ? HostRuntimeStatus.offline : HostRuntimeStatus.error,
        error: failure.message,
        errorReason: failure.reason,
        clearApi: true,
      ),
    );
  }

  HostConnectionFailure _failureFrom(Object error) {
    if (error is HostConnectionFailure) return error;
    if (error is TinestClientException && error.code == 'protocol_mismatch') {
      return HostConnectionFailure.protocolMismatch(error.message);
    }
    if (error is TinestClientException &&
        error.code == localNetworkUnreachableCode) {
      return HostConnectionFailure.network(
        error.message,
        reason: HostFailureReason.localNetworkUnreachable,
      );
    }
    return HostConnectionFailure.network('$error');
  }

  HostEndpoint _parseEndpoint(String address) {
    try {
      return HostEndpoint.parse(address);
    } on FormatException catch (error) {
      throw HostConnectionFailure.invalidEndpoint(error.message);
    }
  }

  Future<void> _stopEmbedded() async {
    await _stopRuntime(embeddedHostId);
    final session = _embeddedSession;
    _embeddedSession = null;
    await session?.stop();
  }

  Future<void> _stopRuntime(String hostId) async {
    final resource = _resources.remove(hostId);
    if (resource == null) return;
    resource.generation += 1;
    final failures = _CleanupFailures();
    await failures.attempt(() => resource.probeTask?.cancel());
    await failures.attempt(() => resource.states?.cancel());
    await failures.attempt(() => resource.api?.close());
    _serverOwners.removeWhere((serverId, owner) => owner == hostId);
    failures.throwFirst();
  }

  Future<void> _serializeEmbedded(Future<void> Function() operation) {
    final result = _embeddedLifecycle.then<void>((_) => operation());
    _embeddedLifecycle = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {
        // The caller observes the failure through result; recovering this tail
        // allows later lifecycle operations to continue safely.
      },
    );
    return result;
  }

  void _replaceProfile(RemoteDaemonProfile profile) {
    _emit(
      value.copyWith(
        profiles: List<RemoteDaemonProfile>.unmodifiable(<RemoteDaemonProfile>[
          for (final item in value.profiles)
            if (item.id == profile.id) profile else item,
        ]),
      ),
    );
  }

  void _replaceRuntime(HostRuntimeSnapshot runtime) {
    final runtimes = Map<String, HostRuntimeSnapshot>.of(value.runtimes)
      ..[runtime.id] = runtime;
    _emit(
      value.copyWith(
        runtimes: Map<String, HostRuntimeSnapshot>.unmodifiable(runtimes),
      ),
    );
  }

  void _updateRuntime(
    String hostId,
    HostRuntimeSnapshot Function(HostRuntimeSnapshot current) update,
  ) {
    final current = value.runtimes[hostId];
    if (current == null) return;
    _replaceRuntime(update(current));
  }

  void _emit(HostRegistryState next) {
    if (_closed) return;
    _state = next;
    _changes.add(next);
  }

  RemoteDaemonProfile _profile(String id) =>
      _profileOrNull(id) ?? (throw StateError('Unknown remote host: $id'));

  RemoteDaemonProfile? _profileOrNull(String id) {
    for (final profile in value.profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  void _ensureLoaded() {
    if (_state == null) {
      throw StateError('HostRegistry.load must complete first.');
    }
  }

  /// Stops every client and the app-owned daemon before the process exits.
  ///
  /// The tray quit path runs before the provider scope is disposed, so this
  /// is the same idempotent teardown [close] performs, named for its caller.
  Future<void> shutdown() => close();

  /// Closes every client and the app-owned daemon.
  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    _closed = true;
    final failures = _CleanupFailures();
    await failures.attempt(() => _embeddedLifecycle);
    for (final hostId in List<String>.of(_resources.keys)) {
      await failures.attempt(() => _stopRuntime(hostId));
    }
    final session = _embeddedSession;
    _embeddedSession = null;
    if (session != null) await failures.attempt(session.stop);
    await failures.attempt(_changes.close);
    failures.throwFirst();
  }

  static RemoteHostRepository _requireProfiles(AppSettingsRepository store) {
    if (store case final RemoteHostRepository profiles) return profiles;
    throw ArgumentError('A RemoteHostRepository must be provided.');
  }

  static RemoteHostCredentialStore _requireCredentials(
    AppSettingsRepository store,
  ) {
    if (store case final RemoteHostCredentialStore credentials) {
      return credentials;
    }
    throw ArgumentError('A RemoteHostCredentialStore must be provided.');
  }

  RelayHostCredentialStore? get _relayCredentials =>
      _credentials is RelayHostCredentialStore
      ? _credentials as RelayHostCredentialStore
      : null;
}

DirectHostConnection? _directConnection(RemoteDaemonProfile profile) =>
    profile.directConnections.firstOrNull;

String _defaultRelayLabel(String serverId) =>
    serverId.length <= 12 ? serverId : serverId.substring(0, 12);

final class _ConnectedPath {
  const new(this.connection, this.credential, this.api);

  final HostConnection connection;
  final HostConnectionCredential credential;
  final TinestApi api;
}
