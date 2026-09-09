import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:daemon/src/bootstrap/version.g.dart';
import 'package:protocol/local_host.dart';

/// Supplies process environment and operating-system information to config.
///
/// Shared with the standalone CLI so both resolve the same directories.
typedef DaemonEnvironment = LocalDaemonEnvironment;

/// Production [DaemonEnvironment] backed by `dart:io`.
final class IoDaemonEnvironment implements DaemonEnvironment {
  /// Creates the production adapter.
  const new();

  @override
  Map<String, String> get values => Platform.environment;
  @override
  bool get isLinux => Platform.isLinux;
  @override
  bool get isMacOS => Platform.isMacOS;
  @override
  bool get isWindows => Platform.isWindows;
}

/// Browser origins allowed to reach the daemon without extra configuration.
///
/// Native clients send no `Origin` and are unaffected. Only a browser is
/// bound by this list, which is what keeps an arbitrary web page from probing
/// a daemon on the visitor's own machine.
const Set<String> defaultAllowedOrigins = <String>{
  'https://tinest.tinyrack.net',
};

/// Certificate validation mode for a daemon's outbound relay connection.
enum RelayTlsPolicy {
  /// Require the platform's public trust chain.
  systemTrust,

  /// Allow an invalid certificate for an explicitly configured relay.
  allowInvalidCertificate,
}

/// Typed relay settings for one daemon process.
final class RelayDaemonConfig {
  /// Creates relay settings, defaulting to the official Tinyrack endpoint.
  const new({
    this.enabled = false,
    Uri? endpoint,
    this.tlsPolicy = RelayTlsPolicy.systemTrust,
  }) : endpointOverride = endpoint;

  /// Whether the daemon opens an outbound relay control connection.
  final bool enabled;

  /// Optional self-hosted endpoint; absent means the official endpoint.
  final Uri? endpointOverride;

  /// Certificate validation policy for [endpoint].
  final RelayTlsPolicy tlsPolicy;

  /// Effective outbound WebSocket URI.
  Uri get endpoint =>
      endpointOverride ?? Uri.parse('wss://relay.tinest.tinyrack.net/v1/ws');
}

/// DaemonConfig defines a public contract.
class DaemonConfig {
  /// Creates a [DaemonConfig].
  const new({
    required this.homeDirectory,
    String? configDirectory,
    this.userHomeDirectory,
    this.osHomeDirectory,
    this.host = '127.0.0.1',
    this.port = 7337,
    this.bearerToken,
    this.version = packageVersion,
    this.useEnvironmentCredentials = true,
    this.allowedOrigins = defaultAllowedOrigins,
    this.relay = const RelayDaemonConfig(),
  }) : configDirectory = configDirectory ?? homeDirectory;

  /// Creates a [DaemonConfig].
  factory fromIsolateMessage(Map<Object?, Object?> value) => DaemonConfig(
    homeDirectory: value['homeDirectory']! as String,
    configDirectory: value['configDirectory'] as String?,
    userHomeDirectory: value['userHomeDirectory'] as String?,
    osHomeDirectory: value['osHomeDirectory'] as String?,
    host: value['host']! as String,
    port: value['port']! as int,
    bearerToken: value['bearerToken'] as String?,
    version: value['version']! as String,
    useEnvironmentCredentials: value['useEnvironmentCredentials']! as bool,
    allowedOrigins: <String>{
      ...(value['allowedOrigins']! as List<Object?>).cast<String>(),
    },
    relay: RelayDaemonConfig(
      enabled: value['relayEnabled']! as bool,
      endpoint: value['relayEndpoint'] == null
          ? null
          : Uri.parse(value['relayEndpoint']! as String),
      tlsPolicy: RelayTlsPolicy.values.byName(
        value['relayTlsPolicy']! as String,
      ),
    ),
  );

  /// Creates a [DaemonConfig].
  factory fromEnvironment({
    DaemonEnvironment environment = const IoDaemonEnvironment(),
  }) {
    final values = environment.values;
    final directories = resolveLocalDaemonDirectories(environment: environment);
    final (host, port) = parseLocalDaemonListen(
      values['TINYRACK_TINEST_LISTEN'] ?? defaultLocalDaemonListen,
    );
    return DaemonConfig(
      homeDirectory: directories.stateDirectory,
      configDirectory: directories.configDirectory,
      userHomeDirectory: directories.userHomeDirectory,
      osHomeDirectory: directories.osHomeDirectory,
      host: host,
      port: port,
      bearerToken: values['TINYRACK_TINEST_TOKEN'],
      allowedOrigins: parseAllowedOrigins(
        values['TINYRACK_TINEST_ALLOWED_ORIGINS'],
      ),
      relay: _relayConfigFromEnvironment(values),
    );
  }

  /// The homeDirectory public API member.
  final String homeDirectory;

  /// The configDirectory public API member.
  final String configDirectory;

  /// Real user home used to locate the shared `~/.agents` tree.
  ///
  /// Null keeps the daemon away from any user home, which is what tests and
  /// CI runs need.
  final String? userHomeDirectory;

  /// Home this machine reports, offered to clients as a browsing start point.
  ///
  /// Null keeps a client from ever assuming a home on a daemon that was
  /// configured without one, which is what tests and CI runs need.
  final String? osHomeDirectory;

  /// The host public API member.
  final String host;

  /// The port public API member.
  final int port;

  /// The bearerToken public API member.
  final String? bearerToken;

  /// The version public API member.
  final String version;

  /// Whether MCP secret substitution may read the daemon environment.
  final bool useEnvironmentCredentials;

  /// Browser origins permitted to call the daemon.
  final Set<String> allowedOrigins;

  /// Outbound relay connection settings.
  final RelayDaemonConfig relay;

  /// The copyWith public API member.
  DaemonConfig copyWith({
    String? homeDirectory,
    String? configDirectory,
    String? userHomeDirectory,
    String? osHomeDirectory,
    String? host,
    int? port,
    String? bearerToken,
    bool? useEnvironmentCredentials,
    Set<String>? allowedOrigins,
    RelayDaemonConfig? relay,
  }) => DaemonConfig(
    homeDirectory: homeDirectory ?? this.homeDirectory,
    configDirectory: configDirectory ?? this.configDirectory,
    userHomeDirectory: userHomeDirectory ?? this.userHomeDirectory,
    osHomeDirectory: osHomeDirectory ?? this.osHomeDirectory,
    host: host ?? this.host,
    port: port ?? this.port,
    bearerToken: bearerToken ?? this.bearerToken,
    version: version,
    useEnvironmentCredentials:
        useEnvironmentCredentials ?? this.useEnvironmentCredentials,
    allowedOrigins: allowedOrigins ?? this.allowedOrigins,
    relay: relay ?? this.relay,
  );

  /// The toIsolateMessage public API member.
  Map<String, Object?> toIsolateMessage() => <String, Object?>{
    'homeDirectory': homeDirectory,
    'configDirectory': configDirectory,
    'userHomeDirectory': userHomeDirectory,
    'osHomeDirectory': osHomeDirectory,
    'host': host,
    'port': port,
    'bearerToken': bearerToken,
    'version': version,
    'useEnvironmentCredentials': useEnvironmentCredentials,
    'allowedOrigins': allowedOrigins.toList(growable: false),
    'relayEnabled': relay.enabled,
    'relayEndpoint': relay.endpointOverride?.toString(),
    'relayTlsPolicy': relay.tlsPolicy.name,
  };
}

RelayDaemonConfig _relayConfigFromEnvironment(Map<String, String> values) {
  final enabledValue = values['TINYRACK_TINEST_RELAY']?.trim().toLowerCase();
  if (enabledValue != null &&
      enabledValue != 'true' &&
      enabledValue != 'false') {
    throw const FormatException('TINYRACK_TINEST_RELAY must be true or false.');
  }
  final endpointValue = values['TINYRACK_TINEST_RELAY_ENDPOINT']?.trim();
  final endpoint = endpointValue == null || endpointValue.isEmpty
      ? null
      : Uri.parse(endpointValue);
  if (endpoint != null && endpoint.scheme != 'wss' && endpoint.scheme != 'ws') {
    throw const FormatException('Relay endpoint must use ws or wss.');
  }
  final tlsValue = values['TINYRACK_TINEST_RELAY_TLS']?.trim();
  final tlsPolicy = switch (tlsValue) {
    null || '' || 'system-trust' => RelayTlsPolicy.systemTrust,
    'allow-invalid-certificate' => RelayTlsPolicy.allowInvalidCertificate,
    _ => throw const FormatException(
      'Invalid TINYRACK_TINEST_RELAY_TLS value.',
    ),
  };
  return RelayDaemonConfig(
    enabled: enabledValue == 'true',
    endpoint: endpoint,
    tlsPolicy: tlsPolicy,
  );
}

/// Parses a comma-separated origin allowlist.
///
/// An empty or absent value keeps [defaultAllowedOrigins]; an explicit `none`
/// turns browser access off entirely, which a headless deployment wants.
Set<String> parseAllowedOrigins(String? value) {
  if (value == null || value.trim().isEmpty) return defaultAllowedOrigins;
  if (value.trim() == 'none') return const <String>{};
  return <String>{
    for (final entry in value.split(','))
      if (entry.trim().isNotEmpty) entry.trim(),
  };
}

/// The generateBearerToken public API member.
String generateBearerToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(
    32,
    (_) => random.nextInt(256),
    growable: false,
  );
  return base64UrlEncode(bytes).replaceAll('=', '');
}
