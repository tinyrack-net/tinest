import 'dart:convert';

import 'package:app/src/app/app_identity.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/hosts/domain/host_ports.dart';
import 'package:client/client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Versioned device-local storage for non-secret app and host settings.
final class SharedPreferencesAppStore
    implements AppSettingsRepository, RemoteHostRepository {
  /// Creates a preferences-backed app store.
  new(this._preferences);

  /// Single versioned document key; legacy singleton keys are not read.
  static const String documentKey =
      '${AppIdentity.storagePrefix}.app_document_v5';

  final SharedPreferences _preferences;
  Future<void> _writes = Future<void>.value();

  @override
  Future<AppSettings> loadSettings() async => (await _read()).settings;

  @override
  Future<List<RemoteDaemonProfile>> listProfiles() async =>
      List<RemoteDaemonProfile>.unmodifiable((await _read()).profiles);

  @override
  Future<void> saveSettings(AppSettings settings) =>
      _enqueue((document) => document.copyWith(settings: settings));

  @override
  Future<void> upsertProfile(RemoteDaemonProfile profile) =>
      _enqueue((document) {
        final profiles = List<RemoteDaemonProfile>.of(document.profiles);
        final index = profiles.indexWhere((item) => item.id == profile.id);
        if (index < 0) {
          profiles.add(profile);
        } else {
          profiles[index] = profile;
        }
        return document.copyWith(profiles: profiles);
      });

  @override
  Future<void> deleteProfile(String profileId) => _enqueue(
    (document) => document.copyWith(
      profiles: document.profiles
          .where((profile) => profile.id != profileId)
          .toList(growable: false),
    ),
  );

  @override
  Future<void> clear() {
    // Joins the write chain so a queued update cannot rewrite the document
    // after it is removed.
    final completer = _writes.then((_) async {
      await _preferences.remove(documentKey);
    });
    _writes = completer;
    return completer;
  }

  Future<void> _enqueue(_AppDocument Function(_AppDocument current) update) {
    final completer = _writes.then((_) async {
      final next = update(await _read());
      await _preferences.setString(documentKey, jsonEncode(next.toJson()));
    });
    _writes = completer;
    return completer;
  }

  Future<_AppDocument> _read() async {
    final source = _preferences.getString(documentKey);
    if (source == null) {
      return const _AppDocument();
    }
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid app settings document.');
    }
    return _AppDocument.fromJson(decoded);
  }
}

/// Secure-storage adapter containing only remote bearer tokens.
final class SecureRemoteHostCredentialStore
    implements RemoteHostCredentialStore, RelayHostCredentialStore {
  /// Creates a secure remote host credential store.
  const new(this._storage);

  static const String _prefix =
      '${AppIdentity.storagePrefix}.v5.remote_host_credential.';
  final FlutterSecureStorage _storage;

  @override
  Future<void> deleteAllBearerTokens() async {
    // Deletes by prefix rather than clearing the whole store, which other
    // plugins share, and also collects tokens orphaned by an earlier crash.
    final stored = await _storage.readAll();
    // Materialized first: deleting while iterating a live keystore view fails.
    final keys = stored.keys
        .where((key) => key.startsWith(_prefix))
        .toList(growable: false);
    for (final key in keys) {
      await _storage.delete(key: key);
    }
  }

  @override
  Future<void> deleteAllRelayCredentials() => deleteAllBearerTokens();

  @override
  Future<void> deleteBearerToken(String profileId) =>
      _storage.delete(key: '$_prefix$profileId');

  @override
  Future<void> deleteRelayCredential(String credentialKey) =>
      _storage.delete(key: '$_prefix$credentialKey');

  @override
  Future<String?> readBearerToken(String profileId) =>
      _storage.read(key: '$_prefix$profileId');

  @override
  Future<void> writeBearerToken(String profileId, String token) =>
      _storage.write(key: '$_prefix$profileId', value: token);

  @override
  Future<RelayHostCredential?> readRelayCredential(String credentialKey) async {
    final encoded = await _storage.read(key: '$_prefix$credentialKey');
    if (encoded == null) {
      return null;
    }
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic> ||
        decoded['type'] != 'relay-device' ||
        decoded['deviceId'] is! String ||
        decoded['privateKey'] is! String) {
      throw const FormatException('Invalid relay device credential.');
    }
    return RelayHostCredential(
      deviceId: decoded['deviceId']! as String,
      privateKey: base64Url.decode(
        base64Url.normalize(decoded['privateKey']! as String),
      ),
    );
  }

  @override
  Future<void> writeRelayCredential(
    String credentialKey,
    RelayHostCredential credential,
  ) => _storage.write(
    key: '$_prefix$credentialKey',
    value: jsonEncode(<String, dynamic>{
      'type': 'relay-device',
      'deviceId': credential.deviceId,
      'privateKey': base64UrlEncode(credential.privateKey),
    }),
  );
}

final class _AppDocument {
  const new({
    this.settings = const AppSettings(),
    this.profiles = const <RemoteDaemonProfile>[],
  });

  factory fromJson(Map<String, dynamic> json) {
    if (json['version'] != 5) {
      throw const FormatException(
        'Incompatible app settings. Remove the app_document_v5 preference '
        'to reset development data.',
      );
    }
    final settingsJson = json['settings'];
    final profilesJson = json['profiles'];
    if (settingsJson is! Map<String, dynamic> || profilesJson is! List) {
      throw const FormatException('Invalid app settings document.');
    }
    return _AppDocument(
      settings: _settingsFromJson(settingsJson),
      profiles: profilesJson
          .map((item) {
            if (item is! Map<String, dynamic>) {
              throw const FormatException('Invalid remote host profile.');
            }
            return _profileFromJson(item);
          })
          .toList(growable: false),
    );
  }

  final AppSettings settings;
  final List<RemoteDaemonProfile> profiles;

  _AppDocument copyWith({
    AppSettings? settings,
    List<RemoteDaemonProfile>? profiles,
  }) => _AppDocument(
    settings: settings ?? this.settings,
    profiles: profiles ?? this.profiles,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': 5,
    'settings': <String, dynamic>{
      'embeddedDaemonEnabled': settings.embeddedDaemonEnabled,
      'embeddedDaemonExposure': settings.embeddedDaemonExposure.name,
      'embeddedDaemonPort': settings.embeddedDaemonPort,
      'lastActiveHostId': settings.lastActiveHostId,
      'lastWorktree': _selectionToJson(settings.lastWorktree),
      'localeTag': settings.localeTag,
      'sessionTabs': settings.sessionTabs.entries
          .map(
            (entry) => <String, dynamic>{
              'key': entry.key,
              'tabs': entry.value.tabs
                  .map(
                    (tab) => <String, dynamic>{
                      'id': tab.id,
                      'kind': tab.kind.name,
                      'targetId': tab.targetId,
                    },
                  )
                  .toList(growable: false),
              'root': _panePreferenceToJson(entry.value.root),
              'focusedPaneId': entry.value.focusedPaneId,
            },
          )
          .toList(growable: false),
      'sidebarCollapsed': settings.sidebarCollapsed,
      'startAtBoot': settings.startAtBoot,
      'startMinimizedAtBoot': settings.startMinimizedAtBoot,
      'themeMode': settings.themeMode.name,
    },
    'profiles': profiles.map(_profileToJson).toList(growable: false),
  };
}

AppSettings _settingsFromJson(Map<String, dynamic> json) {
  final embedded = json['embeddedDaemonEnabled'];
  final exposure = json['embeddedDaemonExposure'];
  final port = json['embeddedDaemonPort'];
  final lastHost = json['lastActiveHostId'];
  final lastWorktree = json['lastWorktree'];
  // Absent in documents written before the language setting existed, which
  // read back as the system default rather than failing the whole document.
  final localeTag = json['localeTag'];
  final tabs = json['sessionTabs'];
  final collapsed = json['sidebarCollapsed'];
  // Absent in documents written before the startup settings existed, which
  // keep the enabled defaults rather than failing the whole document.
  final startAtBoot = json['startAtBoot'];
  final startMinimized = json['startMinimizedAtBoot'];
  // Absent in documents written before the appearance setting existed, which
  // read back as following the system rather than failing the whole document.
  final themeMode = json['themeMode'];
  if (embedded is! bool ||
      collapsed is! bool ||
      (startAtBoot != null && startAtBoot is! bool) ||
      (startMinimized != null && startMinimized is! bool) ||
      (exposure != null && exposure is! String) ||
      (port != null && (port is! int || port < 1 || port > 65535)) ||
      (lastHost != null && lastHost is! String) ||
      (lastWorktree != null && lastWorktree is! Map<String, dynamic>) ||
      (localeTag != null && localeTag is! String) ||
      (themeMode != null && themeMode is! String) ||
      tabs is! List) {
    throw const FormatException('Invalid app settings values.');
  }
  final sessionTabs = <String, SessionTabPreference>{};
  for (final item in tabs) {
    if (item is! Map<String, dynamic>) {
      throw const FormatException('Invalid session tab preference.');
    }
    final key = item['key'];
    final rawTabs = item['tabs'];
    final rawRoot = item['root'];
    final focusedPaneId = item['focusedPaneId'];
    // Flat tab documents were development-only state. Ignore that one
    // workspace entry so the controller can initialize a fresh draft layout.
    if (rawTabs == null && item.containsKey('openAgentIds')) continue;
    if (key is! String ||
        rawTabs is! List ||
        rawRoot is! Map<String, dynamic> ||
        focusedPaneId is! String) {
      throw const FormatException('Invalid session tab preference values.');
    }
    final parsedTabs = <WorkspaceTabPreference>[];
    for (final rawTab in rawTabs) {
      if (rawTab is! Map<String, dynamic>) {
        throw const FormatException('Invalid workspace tab entry.');
      }
      final id = rawTab['id'];
      final kind = rawTab['kind'];
      final targetId = rawTab['targetId'];
      if (id is! String ||
          kind is! String ||
          (targetId != null && targetId is! String)) {
        throw const FormatException('Invalid workspace tab values.');
      }
      parsedTabs.add(
        WorkspaceTabPreference(
          id: id,
          kind: WorkspaceTabTargetKind.values.byName(kind),
          targetId: targetId as String?,
        ),
      );
    }
    sessionTabs[key] = SessionTabPreference(
      tabs: List<WorkspaceTabPreference>.unmodifiable(parsedTabs),
      root: _panePreferenceFromJson(rawRoot),
      focusedPaneId: focusedPaneId,
    );
  }
  return AppSettings(
    embeddedDaemonEnabled: embedded,
    embeddedDaemonExposure: _exposureFromJson(exposure),
    embeddedDaemonPort: port as int? ?? defaultEmbeddedDaemonPort,
    lastActiveHostId: lastHost as String?,
    lastWorktree: lastWorktree == null
        ? null
        : _selectionFromJson(lastWorktree as Map<String, dynamic>),
    localeTag: localeTag as String?,
    sessionTabs: Map<String, SessionTabPreference>.unmodifiable(sessionTabs),
    sidebarCollapsed: collapsed,
    startAtBoot: startAtBoot as bool? ?? true,
    startMinimizedAtBoot: startMinimized as bool? ?? true,
    themeMode: _themeModeFromJson(themeMode),
  );
}

Map<String, dynamic> _panePreferenceToJson(WorkspacePanePreferenceNode node) =>
    switch (node) {
      WorkspacePanePreference() => <String, dynamic>{
        'type': 'pane',
        'id': node.id,
        'tabIds': node.tabIds,
        'activeTabId': node.activeTabId,
      },
      WorkspaceSplitPreference() => <String, dynamic>{
        'type': 'split',
        'id': node.id,
        'axis': node.axis.name,
        'ratio': node.ratio,
        'first': _panePreferenceToJson(node.first),
        'second': _panePreferenceToJson(node.second),
      },
    };

WorkspacePanePreferenceNode _panePreferenceFromJson(Map<String, dynamic> json) {
  final type = json['type'];
  final id = json['id'];
  if (id is! String) throw const FormatException('Invalid pane identity.');
  if (type == 'pane') {
    final tabIds = json['tabIds'];
    final activeTabId = json['activeTabId'];
    if (tabIds is! List ||
        tabIds.any((value) => value is! String) ||
        activeTabId is! String) {
      throw const FormatException('Invalid pane preference.');
    }
    return WorkspacePanePreference(
      id: id,
      tabIds: List<String>.unmodifiable(tabIds.cast<String>()),
      activeTabId: activeTabId,
    );
  }
  if (type == 'split') {
    final axis = json['axis'];
    final ratio = json['ratio'];
    final first = json['first'];
    final second = json['second'];
    if (axis is! String ||
        ratio is! num ||
        ratio < 0 ||
        ratio > 1 ||
        first is! Map<String, dynamic> ||
        second is! Map<String, dynamic>) {
      throw const FormatException('Invalid split preference.');
    }
    return WorkspaceSplitPreference(
      id: id,
      axis: WorkspaceSplitAxis.values.byName(axis),
      ratio: ratio.toDouble(),
      first: _panePreferenceFromJson(first),
      second: _panePreferenceFromJson(second),
    );
  }
  throw const FormatException('Invalid pane preference type.');
}

AppThemeMode _themeModeFromJson(Object? value) => switch (value) {
  null || 'system' => AppThemeMode.system,
  'light' => AppThemeMode.light,
  'dark' => AppThemeMode.dark,
  _ => throw const FormatException('Invalid app theme mode.'),
};

EmbeddedDaemonExposure _exposureFromJson(Object? value) => switch (value) {
  null || 'loopback' => EmbeddedDaemonExposure.loopback,
  'allInterfaces' => EmbeddedDaemonExposure.allInterfaces,
  _ => throw const FormatException('Invalid embedded daemon exposure.'),
};

WorkspaceSelection _selectionFromJson(Map<String, dynamic> json) {
  final hostId = json['hostId'];
  final workspaceId = json['workspaceId'];
  final worktreeId = json['worktreeId'];
  if (hostId is! String || workspaceId is! String || worktreeId is! String) {
    throw const FormatException('Invalid workspace selection.');
  }
  return WorkspaceSelection(
    hostId: hostId,
    workspaceId: workspaceId,
    worktreeId: worktreeId,
  );
}

Map<String, dynamic>? _selectionToJson(WorkspaceSelection? selection) =>
    selection == null
    ? null
    : <String, dynamic>{
        'hostId': selection.hostId,
        'workspaceId': selection.workspaceId,
        'worktreeId': selection.worktreeId,
      };

RemoteDaemonProfile _profileFromJson(Map<String, dynamic> json) {
  final id = json['id'];
  final label = json['label'];
  final connectionsJson = json['connections'];
  final autoConnect = json['autoConnect'];
  final serverId = json['serverId'];
  final createdAt = json['createdAt'];
  final updatedAt = json['updatedAt'];
  final lastConnectedAt = json['lastConnectedAt'];
  if (id is! String ||
      label is! String ||
      connectionsJson is! List ||
      autoConnect is! bool ||
      (serverId != null && serverId is! String) ||
      createdAt is! String ||
      updatedAt is! String ||
      (lastConnectedAt != null && lastConnectedAt is! String)) {
    throw const FormatException('Invalid remote host profile values.');
  }
  return RemoteDaemonProfile(
    id: id,
    label: label,
    connections: connectionsJson
        .map((value) {
          if (value is! Map<String, dynamic>) {
            throw const FormatException('Invalid host connection.');
          }
          return _connectionFromJson(value);
        })
        .toList(growable: false),
    autoConnect: autoConnect,
    serverId: serverId as String?,
    createdAt: DateTime.parse(createdAt).toUtc(),
    updatedAt: DateTime.parse(updatedAt).toUtc(),
    lastConnectedAt: lastConnectedAt == null
        ? null
        : DateTime.parse(lastConnectedAt as String).toUtc(),
  );
}

Map<String, dynamic> _profileToJson(RemoteDaemonProfile profile) =>
    <String, dynamic>{
      'id': profile.id,
      'label': profile.label,
      'connections': profile.connections
          .map(_connectionToJson)
          .toList(growable: false),
      'autoConnect': profile.autoConnect,
      'serverId': profile.serverId,
      'createdAt': profile.createdAt.toIso8601String(),
      'updatedAt': profile.updatedAt.toIso8601String(),
      'lastConnectedAt': profile.lastConnectedAt?.toIso8601String(),
    };

HostConnection _connectionFromJson(Map<String, dynamic> json) {
  final id = json['id'];
  final credentialKey = json['credentialKey'];
  if (id is! String || credentialKey is! String) {
    throw const FormatException('Invalid host connection identity.');
  }
  return switch (json['type']) {
    'direct' when json['websocketUri'] is String => DirectHostConnection(
      id: id,
      credentialKey: credentialKey,
      endpoint: HostEndpoint.parse(json['websocketUri']! as String),
    ),
    'relay'
        when json['serverId'] is String &&
            json['relayUri'] is String &&
            json['daemonIdentityPublicKey'] is String =>
      RelayHostConnection(
        id: id,
        credentialKey: credentialKey,
        serverId: json['serverId']! as String,
        relayUri: Uri.parse(json['relayUri']! as String),
        daemonIdentityPublicKey: base64Url.decode(
          base64Url.normalize(json['daemonIdentityPublicKey']! as String),
        ),
      ),
    _ => throw const FormatException('Invalid host connection type.'),
  };
}

Map<String, dynamic> _connectionToJson(HostConnection connection) =>
    switch (connection) {
      DirectHostConnection(:final id, :final credentialKey, :final endpoint) =>
        <String, dynamic>{
          'type': 'direct',
          'id': id,
          'credentialKey': credentialKey,
          'websocketUri': endpoint.websocketUri.toString(),
        },
      RelayHostConnection(
        :final id,
        :final credentialKey,
        :final serverId,
        :final relayUri,
        :final daemonIdentityPublicKey,
      ) =>
        <String, dynamic>{
          'type': 'relay',
          'id': id,
          'credentialKey': credentialKey,
          'serverId': serverId,
          'relayUri': relayUri.toString(),
          'daemonIdentityPublicKey': base64UrlEncode(daemonIdentityPublicKey),
        },
    };
