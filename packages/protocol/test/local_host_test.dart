import 'package:protocol/local_host.dart';
import 'package:test/test.dart';

void main() {
  test('resolves Linux XDG directories and explicit agent home', () {
    final directories = resolveLocalDaemonDirectories(
      environment: const _Environment(
        values: <String, String>{
          'HOME': '/home/tinest',
          'XDG_CONFIG_HOME': '/config',
          'XDG_STATE_HOME': '/state',
          'TINYRACK_TINEST_AGENTS_HOME': '/agents',
        },
        linux: true,
      ),
    );

    expect(directories.configDirectory, '/config/tinyrack-tinest');
    expect(directories.stateDirectory, '/state/tinyrack-tinest');
    expect(directories.userHomeDirectory, '/agents');
    expect(directories.osHomeDirectory, '/home/tinest');
  });

  test('one Tinest home override owns config and state', () {
    final directories = resolveLocalDaemonDirectories(
      environment: const _Environment(
        values: <String, String>{
          'HOME': '/home/tinest',
          'TINYRACK_TINEST_HOME': '/tinest',
        },
        linux: true,
      ),
    );

    expect(directories.configDirectory, '/tinest');
    expect(directories.stateDirectory, '/tinest');
    expect(directories.userHomeDirectory, '/home/tinest');
  });

  test('resolves macOS, Windows, and fallback conventions', () {
    final macOS = resolveLocalDaemonDirectories(
      environment: const _Environment(
        values: <String, String>{'HOME': '/Users/tinest'},
        macOS: true,
      ),
    );
    expect(
      macOS.configDirectory,
      '/Users/tinest/Library/Application Support/Tinest',
    );
    expect(macOS.stateDirectory, macOS.configDirectory);

    final windows = resolveLocalDaemonDirectories(
      environment: const _Environment(
        values: <String, String>{
          'USERPROFILE': r'C:\Users\tinest',
          'APPDATA': r'C:\Roaming',
          'LOCALAPPDATA': r'C:\Local',
        },
        windows: true,
      ),
    );
    expect(windows.configDirectory, r'C:\Roaming\Tinest');
    expect(windows.stateDirectory, r'C:\Local\Tinest');

    final fallback = resolveLocalDaemonDirectories(
      environment: const _Environment(values: <String, String>{}),
    );
    expect(fallback.configDirectory, './.config/tinyrack-tinest');
    expect(fallback.stateDirectory, './.local/state/tinyrack-tinest');
  });

  test('uses platform fallbacks when optional variables are absent', () {
    final linux = resolveLocalDaemonDirectories(
      environment: const _Environment(
        values: <String, String>{'HOME': '/home/tinest'},
        linux: true,
      ),
    );
    expect(linux.configDirectory, '/home/tinest/.config/tinyrack-tinest');
    expect(linux.stateDirectory, '/home/tinest/.local/state/tinyrack-tinest');

    final windows = resolveLocalDaemonDirectories(
      environment: const _Environment(
        values: <String, String>{'USERPROFILE': r'C:\Users\tinest'},
        windows: true,
      ),
    );
    expect(windows.configDirectory, r'C:\Users\tinest\Tinest');
    expect(windows.stateDirectory, windows.configDirectory);
  });

  test('parses listen addresses and rejects missing or invalid ports', () {
    expect(parseLocalDaemonListen(defaultLocalDaemonListen), (
      '127.0.0.1',
      7337,
    ));
    expect(parseLocalDaemonListen('::1:7444'), ('::1', 7444));
    expect(() => parseLocalDaemonListen('localhost'), throwsFormatException);
    expect(
      () => parseLocalDaemonListen('localhost:http'),
      throwsFormatException,
    );
  });
}

final class _Environment implements LocalDaemonEnvironment {
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
