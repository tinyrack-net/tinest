import 'dart:convert';

import 'package:daemon/src/bootstrap/config.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('relay defaults to the official Tinest endpoint', () {
    expect(
      const RelayDaemonConfig().endpoint,
      Uri.parse('wss://relay.tinest.tinyrack.net/v1/ws'),
    );
  });

  test('config isolate serialization and copy preserve explicit values', () {
    final config = DaemonConfig(
      homeDirectory: '/state',
      configDirectory: '/config',
      userHomeDirectory: '/user',
      osHomeDirectory: '/os-home',
      host: '0.0.0.0',
      port: 8123,
      bearerToken: 'token',
      version: '2.0.0',
      useEnvironmentCredentials: false,
      relay: RelayDaemonConfig(
        enabled: true,
        endpoint: Uri.parse('wss://relay.example.test/v1/ws'),
        tlsPolicy: RelayTlsPolicy.allowInvalidCertificate,
      ),
    );
    final decoded = DaemonConfig.fromIsolateMessage(config.toIsolateMessage());
    expect(decoded.homeDirectory, '/state');
    expect(decoded.configDirectory, '/config');
    expect(decoded.userHomeDirectory, '/user');
    expect(decoded.osHomeDirectory, '/os-home');
    expect(decoded.host, '0.0.0.0');
    expect(decoded.port, 8123);
    expect(decoded.bearerToken, 'token');
    expect(decoded.version, '2.0.0');
    expect(decoded.useEnvironmentCredentials, isFalse);
    expect(decoded.relay.enabled, config.relay.enabled);
    expect(decoded.relay.endpoint, config.relay.endpoint);
    expect(decoded.relay.tlsPolicy, config.relay.tlsPolicy);

    final copy = config.copyWith(
      homeDirectory: '/other-state',
      configDirectory: '/other-config',
      userHomeDirectory: '/other-user',
      osHomeDirectory: '/other-os-home',
      host: 'localhost',
      port: 9000,
      bearerToken: 'other-token',
      useEnvironmentCredentials: true,
    );
    expect(copy.homeDirectory, '/other-state');
    expect(copy.configDirectory, '/other-config');
    expect(copy.userHomeDirectory, '/other-user');
    expect(copy.osHomeDirectory, '/other-os-home');
    expect(copy.host, 'localhost');
    expect(copy.port, 9000);
    expect(copy.bearerToken, 'other-token');
    expect(copy.version, config.version);
    expect(copy.useEnvironmentCredentials, isTrue);
    expect(copy.relay.enabled, isTrue);
  });

  test('environment config supports Linux defaults and explicit override', () {
    final defaults = DaemonConfig.fromEnvironment(
      environment: const _Environment(
        values: <String, String>{
          'HOME': '/home/test',
          'XDG_CONFIG_HOME': '/xdg/config',
          'XDG_STATE_HOME': '/xdg/state',
        },
        linux: true,
      ),
    );
    expect(
      defaults.configDirectory,
      p.posix.join('/xdg/config', 'tinyrack-tinest'),
    );
    expect(
      defaults.homeDirectory,
      p.posix.join('/xdg/state', 'tinyrack-tinest'),
    );
    expect(defaults.userHomeDirectory, '/home/test');
    expect(defaults.host, '127.0.0.1');
    expect(defaults.port, 7337);

    final override = DaemonConfig.fromEnvironment(
      environment: const _Environment(
        values: <String, String>{
          'TINYRACK_TINEST_HOME': '/override',
          'TINYRACK_TINEST_LISTEN': '0.0.0.0:9001',
          'TINYRACK_TINEST_TOKEN': 'token',
          'TINYRACK_TINEST_RELAY': 'true',
          'TINYRACK_TINEST_RELAY_ENDPOINT': 'wss://relay.example.test/v1/ws',
          'TINYRACK_TINEST_RELAY_TLS': 'allow-invalid-certificate',
          'HOME': '/unused',
        },
        linux: true,
      ),
    );
    expect(override.homeDirectory, '/override');
    expect(override.configDirectory, '/override');
    // TINYRACK_TINEST_HOME relocates daemon-owned state only. The shared
    // `~/.agents` tree still belongs to the real user home.
    expect(override.userHomeDirectory, '/unused');
    expect(override.host, '0.0.0.0');
    expect(override.port, 9001);
    expect(override.bearerToken, 'token');
    expect(override.relay.enabled, isTrue);
    expect(override.relay.endpoint.host, 'relay.example.test');
    expect(override.relay.tlsPolicy, RelayTlsPolicy.allowInvalidCertificate);
  });

  test('agents home override wins over the platform user home', () {
    final overridden = DaemonConfig.fromEnvironment(
      environment: const _Environment(
        values: <String, String>{
          'HOME': '/home/test',
          'TINYRACK_TINEST_AGENTS_HOME': '/tmp/agents-home',
        },
        linux: true,
      ),
    );
    expect(overridden.userHomeDirectory, '/tmp/agents-home');
    // A relocated agents tree must not move the browsing home the daemon
    // reports at handshake.
    expect(overridden.osHomeDirectory, '/home/test');

    final windows = DaemonConfig.fromEnvironment(
      environment: const _Environment(
        values: <String, String>{
          'USERPROFILE': r'C:\Users\test',
          'APPDATA': r'C:\Roaming',
          'LOCALAPPDATA': r'C:\Local',
        },
        windows: true,
      ),
    );
    expect(windows.userHomeDirectory, r'C:\Users\test');
    expect(windows.osHomeDirectory, r'C:\Users\test');
  });

  test('platform-specific defaults cover macOS, Windows, and fallback', () {
    final macOS = DaemonConfig.fromEnvironment(
      environment: const _Environment(
        values: <String, String>{'HOME': '/Users/test'},
        macOS: true,
      ),
    );
    expect(
      macOS.homeDirectory,
      p.posix.join('/Users/test', 'Library', 'Application Support', 'Tinest'),
    );
    expect(macOS.configDirectory, macOS.homeDirectory);

    final windows = DaemonConfig.fromEnvironment(
      environment: const _Environment(
        values: <String, String>{
          'USERPROFILE': r'C:\Users\test',
          'APPDATA': r'C:\Roaming',
          'LOCALAPPDATA': r'C:\Local',
        },
        windows: true,
      ),
    );
    expect(windows.configDirectory, contains('Roaming'));
    expect(windows.homeDirectory, contains('Local'));

    final fallback = DaemonConfig.fromEnvironment(
      environment: const _Environment(
        values: <String, String>{'HOME': '/home/test'},
      ),
    );
    expect(
      fallback.configDirectory,
      p.posix.join('/home/test', '.config', 'tinyrack-tinest'),
    );
    expect(
      fallback.homeDirectory,
      p.posix.join('/home/test', '.local', 'state', 'tinyrack-tinest'),
    );
  });

  test('invalid listen address is rejected and bearer tokens are 256-bit', () {
    expect(
      () => DaemonConfig.fromEnvironment(
        environment: const _Environment(
          values: <String, String>{'TINYRACK_TINEST_LISTEN': 'invalid'},
          linux: true,
        ),
      ),
      throwsA(isA<FormatException>()),
    );
    final token = generateBearerToken();
    expect(base64Url.decode(base64Url.normalize(token)), hasLength(32));
    expect(token, isNot(contains('=')));
  });

  test('IO environment adapter reflects the running process', () {
    const environment = IoDaemonEnvironment();
    expect(environment.values, isNotNull);
    expect(
      <bool>[
        environment.isLinux,
        environment.isMacOS,
        environment.isWindows,
      ].where((value) => value),
      hasLength(1),
    );
  });
}

final class _Environment implements DaemonEnvironment {
  const new({
    required this.values,
    this.linux = false,
    this.macOS = false,
    this.windows = false,
  });

  @override
  final Map<String, String> values;

  final bool linux;
  final bool macOS;
  final bool windows;

  @override
  bool get isLinux => linux;

  @override
  bool get isMacOS => macOS;

  @override
  bool get isWindows => windows;
}
