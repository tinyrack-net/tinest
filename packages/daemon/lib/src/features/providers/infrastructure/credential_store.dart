import 'dart:convert';
import 'dart:io';

import 'package:daemon/src/shared/infrastructure/persistence/repositories.dart';
import 'package:path/path.dart' as p;

/// CredentialStore defines a public contract.
class CredentialStore implements CredentialRepository {
  /// Creates a [CredentialStore].
  new(this.configDirectory);

  /// The configDirectory public API member.
  final String configDirectory;
  final Map<String, ProviderCredential> _providerCredentials =
      <String, ProviderCredential>{};
  final Map<String, String> _mcpSecrets = <String, String>{};
  String? _bearerToken;
  List<int>? _relayIdentityPrivateKey;
  bool _loaded = false;

  File get _credentialsFile => File(p.join(configDirectory, 'secrets.json'));

  @override
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    await _ensureDirectory();
    if (_credentialsFile.existsSync()) {
      final decoded = jsonDecode(await _credentialsFile.readAsString());
      if (decoded is! Map<String, dynamic> || decoded['schemaVersion'] != 2) {
        throw FormatException(
          'incompatible_credentials: explicitly remove '
          '${_credentialsFile.path} to reset development credentials.',
        );
      }
      final credentials = decoded['providerCredentials'];
      if (credentials is Map<String, dynamic>) {
        for (final entry in credentials.entries) {
          if (entry.value case final Map<String, dynamic> value) {
            _providerCredentials[entry.key] = _credentialFromJson(value);
          }
        }
      }
      final secrets = decoded['mcpSecrets'];
      if (secrets != null) {
        if (secrets is! Map<String, dynamic> ||
            secrets.values.any((value) => value is! String)) {
          throw const FormatException('Invalid MCP secret data.');
        }
        _mcpSecrets.addAll(secrets.cast<String, String>());
      }
      final daemon = decoded['daemon'];
      if (daemon != null) {
        if (daemon is! Map<String, dynamic> ||
            (daemon['bearerToken'] != null &&
                daemon['bearerToken'] is! String) ||
            (daemon['relayIdentityPrivateKey'] != null &&
                daemon['relayIdentityPrivateKey'] is! String)) {
          throw const FormatException('Invalid daemon credential data.');
        }
        _bearerToken = daemon['bearerToken'] as String?;
        if (daemon['relayIdentityPrivateKey'] case final String encoded) {
          final key = base64Url.decode(base64Url.normalize(encoded));
          if (key.length != 32) {
            throw const FormatException('Invalid relay identity private key.');
          }
          _relayIdentityPrivateKey = List<int>.unmodifiable(key);
        }
      }
    }
  }

  @override
  String? get bearerToken => _bearerToken;

  /// Raw Ed25519 private key seed for the persistent daemon relay identity.
  List<int>? get relayIdentityPrivateKey => _relayIdentityPrivateKey == null
      ? null
      : List<int>.unmodifiable(_relayIdentityPrivateKey!);

  @override
  ProviderCredential? credential(String connectionId) =>
      _providerCredentials[connectionId];

  @override
  Future<void> setDaemonToken(String bearerToken) async {
    await load();
    _bearerToken = bearerToken;
    await _writeCredentials();
  }

  /// Stores the daemon's 32-byte Ed25519 private key seed.
  Future<void> setRelayIdentityPrivateKey(List<int> privateKey) async {
    if (privateKey.length != 32) {
      throw RangeError.range(privateKey.length, 32, 32, 'privateKey.length');
    }
    await load();
    _relayIdentityPrivateKey = List<int>.unmodifiable(privateKey);
    await _writeCredentials();
  }

  @override
  Future<void> setCredential(
    String connectionId,
    ProviderCredential credential,
  ) async {
    await load();
    _providerCredentials[connectionId] = credential;
    await _writeCredentials();
  }

  @override
  Future<void> removeCredential(String connectionId) async {
    await load();
    _providerCredentials.remove(connectionId);
    await _writeCredentials();
  }

  @override
  Map<String, String> get mcpSecrets =>
      Map<String, String>.unmodifiable(_mcpSecrets);

  @override
  Future<void> setMcpSecret(String key, String value) async {
    await load();
    _mcpSecrets[key] = value;
    await _writeCredentials();
  }

  @override
  Future<void> removeMcpSecret(String key) async {
    await load();
    _mcpSecrets.remove(key);
    await _writeCredentials();
  }

  Future<void> _writeCredentials() =>
      _writeJson(_credentialsFile, <String, dynamic>{
        'schemaVersion': 2,
        if (_bearerToken != null || _relayIdentityPrivateKey != null)
          'daemon': <String, dynamic>{
            'bearerToken': ?_bearerToken,
            if (_relayIdentityPrivateKey case final privateKey?)
              'relayIdentityPrivateKey': base64UrlEncode(privateKey),
          },
        'providerCredentials': <String, dynamic>{
          for (final entry in _providerCredentials.entries)
            entry.key: _credentialToJson(entry.value),
        },
        if (_mcpSecrets.isNotEmpty)
          'mcpSecrets': Map<String, String>.from(_mcpSecrets),
      });

  Future<void> _ensureDirectory() async {
    final directory = Directory(configDirectory);
    await directory.create(recursive: true);
    if (!Platform.isWindows) {
      await Process.run('chmod', <String>['700', directory.path]);
    }
  }

  Future<void> _writeJson(File file, Map<String, dynamic> value) async {
    await _ensureDirectory();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(value), flush: true);
    if (!Platform.isWindows) {
      await Process.run('chmod', <String>['600', temporary.path]);
    }
    // `rename` removes an existing destination itself. Unlinking it first
    // fails while anything else holds the file — on Windows the scanner that
    // reads every newly created file is enough — and leaves the credentials
    // gone rather than replaced if the process stops in between.
    await temporary.rename(file.path);
    if (!Platform.isWindows) {
      await Process.run('chmod', <String>['600', file.path]);
    }
  }

  static ProviderCredential _credentialFromJson(Map<String, dynamic> json) =>
      switch (json['type']) {
        'apiKey' when json['key'] is String => ApiKeyCredential(
          json['key']! as String,
        ),
        'oauth'
            when json['accessToken'] is String &&
                json['refreshToken'] is String &&
                json['expiresAt'] is String =>
          OAuthCredential(
            accessToken: json['accessToken']! as String,
            refreshToken: json['refreshToken']! as String,
            expiresAt: DateTime.parse(json['expiresAt']! as String).toUtc(),
            accountId: json['accountId'] as String?,
          ),
        _ => throw const FormatException('Invalid provider credential data.'),
      };

  static Map<String, dynamic> _credentialToJson(
    ProviderCredential credential,
  ) => switch (credential) {
    ApiKeyCredential(:final key) => <String, dynamic>{
      'type': 'apiKey',
      'key': key,
    },
    OAuthCredential(
      :final accessToken,
      :final refreshToken,
      :final expiresAt,
      :final accountId,
    ) =>
      <String, dynamic>{
        'type': 'oauth',
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt.toUtc().toIso8601String(),
        'accountId': ?accountId,
      },
  };
}
