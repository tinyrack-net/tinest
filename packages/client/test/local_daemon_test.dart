import 'dart:convert';
import 'dart:io';

import 'package:client/local_daemon.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('directory resolution', () {
    test('Linux honours the XDG variables', () {
      final directories = resolveLocalDaemonDirectories(
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
        directories.configDirectory,
        p.posix.join('/xdg/config', 'tinyrack-tinest'),
      );
      expect(
        directories.stateDirectory,
        p.posix.join('/xdg/state', 'tinyrack-tinest'),
      );
      expect(directories.userHomeDirectory, '/home/test');
    });

    test('Linux falls back to the conventional paths under HOME', () {
      final directories = resolveLocalDaemonDirectories(
        environment: const _Environment(
          values: <String, String>{'HOME': '/home/test'},
          linux: true,
        ),
      );
      expect(
        directories.configDirectory,
        p.posix.join('/home/test', '.config', 'tinyrack-tinest'),
      );
      expect(
        directories.stateDirectory,
        p.posix.join('/home/test', '.local', 'state', 'tinyrack-tinest'),
      );
    });

    test(
      'macOS collapses configuration and state into Application Support',
      () {
        final directories = resolveLocalDaemonDirectories(
          environment: const _Environment(
            values: <String, String>{'HOME': '/Users/test'},
            macOS: true,
          ),
        );
        expect(
          directories.configDirectory,
          p.posix.join(
            '/Users/test',
            'Library',
            'Application Support',
            'Tinest',
          ),
        );
        expect(directories.stateDirectory, directories.configDirectory);
      },
    );

    test('Windows separates roaming configuration from local state', () {
      final directories = resolveLocalDaemonDirectories(
        environment: const _Environment(
          values: <String, String>{
            'USERPROFILE': r'C:\Users\test',
            'APPDATA': r'C:\Roaming',
            'LOCALAPPDATA': r'C:\Local',
          },
          windows: true,
        ),
      );
      expect(directories.configDirectory, contains('Roaming'));
      expect(directories.stateDirectory, contains('Local'));
      expect(directories.userHomeDirectory, r'C:\Users\test');
    });

    test('Windows falls back to the user profile without APPDATA', () {
      final directories = resolveLocalDaemonDirectories(
        environment: const _Environment(
          values: <String, String>{'USERPROFILE': r'C:\Users\test'},
          windows: true,
        ),
      );
      expect(directories.configDirectory, contains(r'C:\Users\test'));
      expect(directories.stateDirectory, directories.configDirectory);
    });

    test('an unknown platform still resolves under HOME', () {
      final directories = resolveLocalDaemonDirectories(
        environment: const _Environment(
          values: <String, String>{'HOME': '/home/test'},
        ),
      );
      expect(
        directories.configDirectory,
        p.posix.join('/home/test', '.config', 'tinyrack-tinest'),
      );
      expect(
        directories.stateDirectory,
        p.posix.join('/home/test', '.local', 'state', 'tinyrack-tinest'),
      );
    });

    test('a missing home variable degrades to the working directory', () {
      final directories = resolveLocalDaemonDirectories(
        environment: const _Environment(
          values: <String, String>{},
          linux: true,
        ),
      );
      expect(
        directories.configDirectory,
        p.posix.join('.', '.config', 'tinyrack-tinest'),
      );
      expect(directories.userHomeDirectory, '.');
    });

    test('TINYRACK_TINEST_HOME collapses configuration and state', () {
      final directories = resolveLocalDaemonDirectories(
        environment: const _Environment(
          values: <String, String>{
            'TINYRACK_TINEST_HOME': '/override',
            'HOME': '/home/test',
          },
          linux: true,
        ),
      );
      expect(directories.configDirectory, '/override');
      expect(directories.stateDirectory, '/override');
      // The override relocates daemon-owned state only; the shared `~/.agents`
      // tree still belongs to the real user home.
      expect(directories.userHomeDirectory, '/home/test');
    });

    test('TINYRACK_TINEST_AGENTS_HOME wins over the platform user home', () {
      final directories = resolveLocalDaemonDirectories(
        environment: const _Environment(
          values: <String, String>{
            'HOME': '/home/test',
            'TINYRACK_TINEST_AGENTS_HOME': '/tmp/agents-home',
          },
          linux: true,
        ),
      );
      expect(directories.userHomeDirectory, '/tmp/agents-home');
      // The agents override must not move the home a file browser starts in.
      expect(directories.osHomeDirectory, '/home/test');
    });

    test('the operating-system home follows the platform variable', () {
      expect(
        resolveLocalDaemonDirectories(
          environment: const _Environment(
            values: <String, String>{'HOME': '/home/test'},
            linux: true,
          ),
        ).osHomeDirectory,
        '/home/test',
      );
      expect(
        resolveLocalDaemonDirectories(
          environment: const _Environment(
            values: <String, String>{'USERPROFILE': r'C:\Users\test'},
            windows: true,
          ),
        ).osHomeDirectory,
        r'C:\Users\test',
      );
      expect(
        resolveLocalDaemonDirectories(
          environment: const _Environment(
            values: <String, String>{'TINYRACK_TINEST_HOME': '/override'},
            linux: true,
          ),
        ).osHomeDirectory,
        '.',
      );
    });
  });

  group('listen parsing', () {
    test('splits a host and port, including IPv6 hosts', () {
      expect(parseLocalDaemonListen(defaultLocalDaemonListen), (
        '127.0.0.1',
        7337,
      ));
      expect(parseLocalDaemonListen('0.0.0.0:9001'), ('0.0.0.0', 9001));
      expect(parseLocalDaemonListen('[::1]:8080'), ('[::1]', 8080));
    });

    test('rejects an address without a usable port', () {
      // Falling back silently would connect the caller to the wrong daemon.
      expect(
        () => parseLocalDaemonListen('nonsense'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parseLocalDaemonListen('127.0.0.1:'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parseLocalDaemonListen('127.0.0.1:http'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parseLocalDaemonListen(':7337'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('bearer token discovery', () {
    late Directory directory;

    setUp(
      () => directory = Directory.systemTemp.createTempSync('tinest-token'),
    );
    tearDown(() => directory.deleteSync(recursive: true));

    void write(Object? value) {
      final versionDirectory = Directory(p.join(directory.path, 'v5'))
        ..createSync();
      File(
        p.join(versionDirectory.path, 'secrets.json'),
      ).writeAsStringSync(jsonEncode(value));
    }

    test('returns null when no daemon has ever run here', () async {
      expect(await readLocalDaemonBearerToken(directory.path), isNull);
    });

    test('returns null when the file carries no daemon section', () async {
      write(<String, dynamic>{'schemaVersion': 2});
      expect(await readLocalDaemonBearerToken(directory.path), isNull);
    });

    test('reads the token a running daemon provisioned', () async {
      write(<String, dynamic>{
        'schemaVersion': 2,
        'daemon': <String, dynamic>{'bearerToken': 'secret-token'},
        'providerCredentials': <String, dynamic>{},
      });
      expect(await readLocalDaemonBearerToken(directory.path), 'secret-token');
    });

    test('names the file when the secrets schema is incompatible', () async {
      write(<String, dynamic>{'schemaVersion': 0});
      await expectLater(
        readLocalDaemonBearerToken(directory.path),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('incompatible_credentials'),
              contains(directory.path),
            ),
          ),
        ),
      );
    });

    test('rejects a malformed daemon section', () async {
      write(<String, dynamic>{
        'schemaVersion': 2,
        'daemon': 'not-an-object',
      });
      await expectLater(
        readLocalDaemonBearerToken(directory.path),
        throwsA(isA<FormatException>()),
      );
      write(<String, dynamic>{
        'schemaVersion': 2,
        'daemon': <String, dynamic>{'bearerToken': 7},
      });
      await expectLater(
        readLocalDaemonBearerToken(directory.path),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

final class _Environment implements LocalDaemonEnvironment {
  const _Environment({
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
