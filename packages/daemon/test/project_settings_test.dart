import 'dart:convert';
import 'dart:io';

import 'package:daemon/src/features/workspaces/infrastructure/project_settings.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:path/path.dart' as p;
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('tinest-project-settings-');
    await Directory(p.join(root.path, '.tinest')).create();
  });

  tearDown(() => root.delete(recursive: true));

  File settingsFile() => File(p.join(root.path, '.tinest', 'config.json'));

  test('reports the workspace-root settings path', () {
    expect(
      const FileProjectSettingsStore().sourcePath(root.path),
      settingsFile().path,
    );
    expect(projectSettingsFileName, '.tinest/config.json');
  });

  test('treats a missing or blank file as empty settings', () async {
    const store = FileProjectSettingsStore();

    expect(await store.load(root.path), const ProjectSettingsDto());

    await settingsFile().writeAsString('   \n');
    expect(await store.load(root.path), const ProjectSettingsDto());
  });

  test(
    'v5 rejects a preserved v4 project document without importing it',
    () async {
      const store = FileProjectSettingsStore();
      await settingsFile().writeAsString(
        jsonEncode(<String, dynamic>{'schemaVersion': 4}),
      );
      await expectLater(store.load(root.path), throwsA(isA<FormatException>()));

      await settingsFile().writeAsString(
        jsonEncode(<String, dynamic>{'schemaVersion': 5}),
      );
      expect(await store.load(root.path), const ProjectSettingsDto());
    },
  );

  test(
    'reads worktree hooks and typed shell settings',
    () async {
      await settingsFile().writeAsString(
        jsonEncode(<String, dynamic>{
          'schemaVersion': 5,
          'worktree': <String, dynamic>{
            'setup': <String>['npm ci', '  ', ' npm run build '],
            'teardown': <String>['docker compose down'],
            'shell': <String, dynamic>{
              'executable': '/bin/zsh',
              'arguments': <String>['-l'],
            },
          },
        }),
      );

      expect(
        await const FileProjectSettingsStore().load(root.path),
        const ProjectSettingsDto(
          setup: <String>['npm ci', 'npm run build'],
          teardown: <String>['docker compose down'],
          shell: ShellSpecDto(
            executable: '/bin/zsh',
            arguments: <String>['-l'],
          ),
        ),
      );
    },
    tags: const <String>[
      'feature_test__project_settings__unit',
      'feature_test__terminal_settings__unit',
    ],
  );

  test('preserves unknown keys and drops empty hook lists on save', () async {
    await settingsFile().writeAsString(
      jsonEncode(<String, dynamic>{
        'schemaVersion': 5,
        'scripts': <String, dynamic>{
          'typecheck': <String, dynamic>{'command': 'npm run typecheck'},
        },
        'worktree': <String, dynamic>{
          'setup': <String>['npm ci'],
          'teardown': <String>['docker compose down'],
          'futureHook': <String>['echo later'],
        },
      }),
    );
    const store = FileProjectSettingsStore();

    await store.save(
      root.path,
      const ProjectSettingsDto(setup: <String>['pnpm install']),
    );

    final document =
        jsonDecode(await settingsFile().readAsString()) as Map<String, dynamic>;
    expect(document['scripts'], <String, dynamic>{
      'typecheck': <String, dynamic>{'command': 'npm run typecheck'},
    });
    expect(document['worktree'], <String, dynamic>{
      'futureHook': <String>['echo later'],
      'setup': <String>['pnpm install'],
    });
    expect(
      await store.load(root.path),
      const ProjectSettingsDto(setup: <String>['pnpm install']),
    );
  });

  test('creates a formatted file when the project has no settings', () async {
    await const FileProjectSettingsStore().save(
      root.path,
      const ProjectSettingsDto(teardown: <String>['docker compose down']),
    );

    expect(
      await settingsFile().readAsString(),
      '{\n'
      '  "schemaVersion": 5,\n'
      '  "worktree": {\n'
      '    "teardown": [\n'
      '      "docker compose down"\n'
      '    ]\n'
      '  }\n'
      '}\n',
    );
  });

  test('removes the worktree section when every hook is cleared', () async {
    await settingsFile().writeAsString(
      jsonEncode(<String, dynamic>{
        'schemaVersion': 5,
        'worktree': <String, dynamic>{
          'setup': <String>['npm ci'],
        },
      }),
    );

    await const FileProjectSettingsStore().save(
      root.path,
      const ProjectSettingsDto(),
    );

    expect(await settingsFile().readAsString(), '{\n  "schemaVersion": 5\n}\n');
  });

  test('writes nothing when clearing hooks without a file', () async {
    await const FileProjectSettingsStore().save(
      root.path,
      const ProjectSettingsDto(),
    );

    expect(settingsFile().existsSync(), isFalse);
  });

  test('rejects malformed documents without overwriting them', () async {
    const store = FileProjectSettingsStore();

    await settingsFile().writeAsString('{ not json');
    await expectLater(
      store.load(root.path),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('invalid_project_settings'),
        ),
      ),
    );
    expect(await settingsFile().readAsString(), '{ not json');

    await settingsFile().writeAsString(jsonEncode(<String>['array']));
    await expectLater(store.load(root.path), throwsA(isA<FormatException>()));

    await settingsFile().writeAsString(
      jsonEncode(<String, dynamic>{'schemaVersion': 5, 'worktree': 'nope'}),
    );
    await expectLater(store.load(root.path), throwsA(isA<FormatException>()));

    await settingsFile().writeAsString(
      jsonEncode(<String, dynamic>{
        'schemaVersion': 5,
        'worktree': <String, dynamic>{'setup': 'npm ci'},
      }),
    );
    await expectLater(store.load(root.path), throwsA(isA<FormatException>()));

    await settingsFile().writeAsString(
      jsonEncode(<String, dynamic>{
        'schemaVersion': 5,
        'worktree': <String, dynamic>{
          'setup': <Object>[42],
        },
      }),
    );
    await expectLater(store.load(root.path), throwsA(isA<FormatException>()));
  });

  test('legacy schema 3 project settings stay untouched', () async {
    const store = FileProjectSettingsStore();
    final legacy = jsonEncode(<String, dynamic>{
      'schemaVersion': 3,
      'worktree': <String, dynamic>{},
    });
    await settingsFile().writeAsString(legacy);

    await expectLater(store.load(root.path), throwsA(isA<FormatException>()));

    expect(await settingsFile().readAsString(), legacy);
  });

  test('runs hook commands through the platform shell', () async {
    final result = await const ShellWorktreeHookRunner().run(
      r'printf "%s" "$CODER_WORKTREE_PATH" && printf error >&2 && exit 3',
      workingDirectory: root.path,
      environment: <String, String>{'CODER_WORKTREE_PATH': '/checkout'},
    );

    expect(result.exitCode, 3);
    expect(result.stdout, '/checkout');
    expect(result.stderr, 'error');
  }, testOn: '!windows');
}
