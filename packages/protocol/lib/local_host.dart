import 'package:path/path.dart' as p;

/// Environment values needed to resolve a local daemon deployment.
abstract interface class LocalDaemonEnvironment {
  /// Process environment variables.
  Map<String, String> get values;

  /// Whether the host is Linux.
  bool get isLinux;

  /// Whether the host is macOS.
  bool get isMacOS;

  /// Whether the host is Windows.
  bool get isWindows;
}

/// Platform-specific locations used by a local daemon.
final class LocalDaemonDirectories {
  /// Creates a resolved directory set.
  const new({
    required this.configDirectory,
    required this.stateDirectory,
    required this.userHomeDirectory,
    required this.osHomeDirectory,
  });

  /// Base directory whose v5 child holds daemon configuration.
  final String configDirectory;

  /// Base directory whose v5 child holds daemon state.
  final String stateDirectory;

  /// Home used for the shared `~/.agents` tree.
  final String userHomeDirectory;

  /// Home reported by the operating system before overrides.
  final String osHomeDirectory;
}

/// Default local listen address.
const String defaultLocalDaemonListen = '127.0.0.1:7337';

/// Resolves local daemon directories without importing `dart:io`.
LocalDaemonDirectories resolveLocalDaemonDirectories({
  required LocalDaemonEnvironment environment,
}) {
  final values = environment.values;
  final defaults = _defaultDirectories(values, environment);
  final override = values['TINYRACK_TINEST_HOME'];
  return LocalDaemonDirectories(
    configDirectory: override ?? defaults.configDirectory,
    stateDirectory: override ?? defaults.stateDirectory,
    userHomeDirectory:
        values['TINYRACK_TINEST_AGENTS_HOME'] ?? defaults.userHomeDirectory,
    osHomeDirectory: defaults.osHomeDirectory,
  );
}

/// Parses a required `host:port` listen address.
(String, int) parseLocalDaemonListen(String listen) {
  final separator = listen.lastIndexOf(':');
  if (separator < 1) {
    throw FormatException('A listen address must be host:port, got "$listen".');
  }
  final port = int.tryParse(listen.substring(separator + 1));
  if (port == null) {
    throw FormatException('A listen address must be host:port, got "$listen".');
  }
  return (listen.substring(0, separator), port);
}

LocalDaemonDirectories _defaultDirectories(
  Map<String, String> environment,
  LocalDaemonEnvironment platform,
) {
  final userHome =
      environment[platform.isWindows ? 'USERPROFILE' : 'HOME'] ?? '.';
  if (platform.isLinux) {
    final config =
        environment['XDG_CONFIG_HOME'] ?? p.posix.join(userHome, '.config');
    final state =
        environment['XDG_STATE_HOME'] ??
        p.posix.join(userHome, '.local', 'state');
    return LocalDaemonDirectories(
      configDirectory: p.posix.join(config, 'tinyrack-tinest'),
      stateDirectory: p.posix.join(state, 'tinyrack-tinest'),
      userHomeDirectory: userHome,
      osHomeDirectory: userHome,
    );
  }
  if (platform.isMacOS) {
    final support = p.posix.join(
      userHome,
      'Library',
      'Application Support',
      'Tinest',
    );
    return LocalDaemonDirectories(
      configDirectory: support,
      stateDirectory: support,
      userHomeDirectory: userHome,
      osHomeDirectory: userHome,
    );
  }
  if (platform.isWindows) {
    final config = environment['APPDATA'] ?? userHome;
    final state = environment['LOCALAPPDATA'] ?? config;
    return LocalDaemonDirectories(
      configDirectory: p.windows.join(config, 'Tinest'),
      stateDirectory: p.windows.join(state, 'Tinest'),
      userHomeDirectory: userHome,
      osHomeDirectory: userHome,
    );
  }
  return LocalDaemonDirectories(
    configDirectory: p.posix.join(userHome, '.config', 'tinyrack-tinest'),
    stateDirectory: p.posix.join(
      userHome,
      '.local',
      'state',
      'tinyrack-tinest',
    ),
    userHomeDirectory: userHome,
    osHomeDirectory: userHome,
  );
}
