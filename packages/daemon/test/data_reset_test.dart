import 'dart:io';

import 'package:daemon/src/bootstrap/data_reset.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/daemon_lock_holder.dart';

/// Records every filesystem interaction so ordering can be asserted.
final class _RecordingDataFiles implements DaemonDataFiles {
  new({
    required Set<String> entries,
    Set<String> directories = const <String>{},
    this.lockFailure,
    String? deleteFailure,
  }) : entries = entries.map(p.canonicalize).toSet(),
       directories = directories.map(p.canonicalize).toSet(),
       deleteFailure = deleteFailure == null
           ? null
           : p.canonicalize(deleteFailure);

  // Canonical, because a real filesystem resolves `/x/y` and `/x//y` to the
  // same entry and the reset joins onto caller-supplied directory strings.
  final Set<String> entries;
  final Set<String> directories;
  final DaemonDataResetException? lockFailure;
  final String? deleteFailure;

  final List<String> calls = <String>[];
  final List<String> deleted = <String>[];

  @override
  Future<void> assertLockAvailable(String lockPath) async {
    calls.add('lock:$lockPath');
    final failure = lockFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<bool> exists(String path) async =>
      entries.contains(p.canonicalize(path));

  @override
  Future<bool> isDirectory(String path) async =>
      directories.contains(p.canonicalize(path));

  @override
  Future<void> deleteFile(String path) async => _delete('file', path);

  @override
  Future<void> deleteDirectory(String path) async => _delete('dir', path);

  void _delete(String kind, String path) {
    calls.add('$kind:$path');
    if (p.canonicalize(path) == deleteFailure) {
      throw FileSystemException('denied', path);
    }
    deleted.add(p.canonicalize(path));
  }
}

void main() {
  // Canonical, matching what _RecordingDataFiles records.
  String home(String entry) =>
      p.canonicalize(p.join('/state/tinyrack-tinest', 'v5', entry));
  String config(String entry) =>
      p.canonicalize(p.join('/config/tinyrack-tinest', 'v5', entry));

  DaemonDataReset reset(
    DaemonDataFiles files, {
    String configDirectory = '/config/tinyrack-tinest',
    String homeDirectory = '/state/tinyrack-tinest',
  }) => DaemonDataReset(
    configDirectory: configDirectory,
    homeDirectory: homeDirectory,
    files: files,
  );

  test('erases every allowlisted entry and keeps managed checkouts', () async {
    final files = _RecordingDataFiles(
      entries: <String>{
        home('tinest.sqlite'),
        home('tinest.sqlite-wal'),
        home('attachments'),
        home('plugin-state.json'),
        home('daemon.lock'),
        home('worktrees'),
        config('secrets.json'),
        config('plugin-secrets.json'),
        config('config.json'),
        config('agents'),
        config('skills'),
      },
      directories: <String>{
        home('attachments'),
        home('worktrees'),
        config('agents'),
        config('skills'),
      },
    );

    await reset(files).eraseAll();

    expect(files.deleted, <String>[
      home('tinest.sqlite'),
      home('tinest.sqlite-wal'),
      home('attachments'),
      home('plugin-state.json'),
      home('daemon.lock'),
      config('secrets.json'),
      config('plugin-secrets.json'),
      config('config.json'),
      config('agents'),
      config('skills'),
    ]);
    expect(files.deleted, isNot(contains(home('worktrees'))));
    expect(
      files.deleted,
      isNot(contains(p.canonicalize('/state/tinyrack-tinest'))),
    );
    expect(
      files.deleted,
      isNot(contains(p.canonicalize('/config/tinyrack-tinest'))),
    );
    expect(DaemonDataReset.preservedHomeEntries, <String>['v5/worktrees']);
  }, tags: const <String>['feature_test__settings_reset__unit']);

  test('tolerates missing entries', () async {
    final files = _RecordingDataFiles(entries: <String>{});

    await reset(files).eraseAll();

    expect(files.deleted, isEmpty);
  }, tags: const <String>['feature_test__settings_reset__unit']);

  test(
    'visits each entry once when config and state collapse into one directory',
    () async {
      final files = _RecordingDataFiles(
        entries: <String>{
          p.join('/shared', 'v5', 'tinest.sqlite'),
          p.join('/shared', 'v5', 'secrets.json'),
        },
      );

      await reset(
        files,
        configDirectory: '/shared/',
        homeDirectory: '/shared',
      ).eraseAll();

      expect(files.deleted, <String>[
        p.canonicalize(p.join('/shared', 'v5', 'tinest.sqlite')),
        p.canonicalize(p.join('/shared', 'v5', 'secrets.json')),
      ]);
      expect(
        files.calls.where((call) => call.startsWith('dir:')).length +
            files.calls.where((call) => call.startsWith('file:')).length,
        2,
      );
    },
    tags: const <String>['feature_test__settings_reset__unit'],
  );

  test(
    'aborts before deleting anything while another daemon holds the lock',
    () async {
      final files = _RecordingDataFiles(
        entries: <String>{home('tinest.sqlite')},
        lockFailure: const DaemonDataResetException(
          'locked',
          reason: DaemonDataResetFailureReason.daemonRunning,
        ),
      );

      await expectLater(
        reset(files).eraseAll(),
        throwsA(
          isA<DaemonDataResetException>().having(
            (error) => error.reason,
            'reason',
            DaemonDataResetFailureReason.daemonRunning,
          ),
        ),
      );
      expect(files.deleted, isEmpty);
      expect(files.calls.single, startsWith('lock:'));
    },
    tags: const <String>['feature_test__settings_reset__unit'],
  );

  test(
    'reports the failing path when the operating system rejects a delete',
    () async {
      final files = _RecordingDataFiles(
        entries: <String>{home('tinest.sqlite')},
        deleteFailure: home('tinest.sqlite'),
      );

      await expectLater(
        reset(files).eraseAll(),
        throwsA(
          isA<DaemonDataResetException>()
              .having(
                (error) => error.reason,
                'reason',
                DaemonDataResetFailureReason.filesystem,
              )
              .having(
                (error) => p.canonicalize(error.path!),
                'path',
                home('tinest.sqlite'),
              ),
        ),
      );
    },
    tags: const <String>['feature_test__settings_reset__unit'],
  );

  test('v5 reset never touches preserved v2, v3, or v4 namespaces', () async {
    final files = _RecordingDataFiles(
      entries: <String>{
        p.join('/state/tinyrack-tinest', 'v2'),
        p.join('/state/tinyrack-tinest', 'v3'),
        p.join('/state/tinyrack-tinest', 'v4'),
        home('tinest.sqlite'),
      },
      directories: <String>{
        p.join('/state/tinyrack-tinest', 'v2'),
        p.join('/state/tinyrack-tinest', 'v3'),
        p.join('/state/tinyrack-tinest', 'v4'),
      },
    );

    await reset(files).eraseAll();

    expect(files.deleted, <String>[home('tinest.sqlite')]);
  }, tags: const <String>['feature_test__settings_reset__unit']);

  test('legacy cleanup requires and removes only explicit versions', () async {
    final files = _RecordingDataFiles(
      entries: <String>{
        p.join('/state/tinyrack-tinest', 'v2'),
        p.join('/config/tinyrack-tinest', 'v2'),
        p.join('/state/tinyrack-tinest', 'v3'),
      },
      directories: <String>{
        p.join('/state/tinyrack-tinest', 'v2'),
        p.join('/config/tinyrack-tinest', 'v2'),
        p.join('/state/tinyrack-tinest', 'v3'),
      },
    );
    final cleanup = DaemonLegacyDataCleanup(
      configDirectory: '/config/tinyrack-tinest',
      homeDirectory: '/state/tinyrack-tinest',
      files: files,
    );

    await cleanup.erase(versions: const <int>{2});

    expect(
      files.deleted,
      containsAll(<String>[
        p.canonicalize(p.join('/state/tinyrack-tinest', 'v2')),
        p.canonicalize(p.join('/config/tinyrack-tinest', 'v2')),
      ]),
    );
    expect(
      files.deleted,
      isNot(contains(p.canonicalize(p.join('/state/tinyrack-tinest', 'v3')))),
    );
    await expectLater(
      cleanup.erase(versions: const <int>{4}),
      throwsArgumentError,
    );
  }, tags: const <String>['feature_test__settings_reset__unit']);

  group('NativeDaemonDataFiles', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('tinest-data-reset-');
    });

    tearDown(() => deleteWithRetry(root));

    test(
      'erases daemon files on disk and keeps the worktrees checkout',
      () async {
        final state = Directory(p.join(root.path, 'state'));
        final configRoot = Directory(p.join(root.path, 'config'));
        final stateV5 = Directory(p.join(state.path, 'v5'));
        final configV5 = Directory(p.join(configRoot.path, 'v5'));
        await stateV5.create(recursive: true);
        await configV5.create(recursive: true);
        await File(p.join(stateV5.path, 'tinest.sqlite')).writeAsString('db');
        await File(p.join(stateV5.path, 'daemon.lock')).writeAsString('');
        await Directory(p.join(stateV5.path, 'attachments')).create();
        await File(p.join(stateV5.path, 'worktrees', 'repo', 'main.dart'))
            .create(recursive: true);
        await File(p.join(configV5.path, 'secrets.json')).writeAsString('{}');
        await File(p.join(configV5.path, 'agents', 'tinest.md'))
            .create(recursive: true);

        await DaemonDataReset(
          configDirectory: configRoot.path,
          homeDirectory: state.path,
        ).eraseAll();

        expect(
          File(p.join(stateV5.path, 'tinest.sqlite')).existsSync(),
          isFalse,
        );
        expect(File(p.join(stateV5.path, 'daemon.lock')).existsSync(), isFalse);
        expect(
          Directory(p.join(stateV5.path, 'attachments')).existsSync(),
          isFalse,
        );
        expect(
          File(p.join(configV5.path, 'secrets.json')).existsSync(),
          isFalse,
        );
        expect(
          Directory(p.join(configV5.path, 'agents')).existsSync(),
          isFalse,
        );
        expect(
          File(p.join(stateV5.path, 'worktrees', 'repo', 'main.dart'))
              .existsSync(),
          isTrue,
        );
        expect(state.existsSync(), isTrue);
        expect(configRoot.existsSync(), isTrue);
      },
      tags: const <String>['feature_test__settings_reset__unit'],
    );

    test(
      'refuses to erase while another process holds the daemon lock',
      () async {
        final state = Directory(p.join(root.path, 'locked'));
        final stateV5 = Directory(p.join(state.path, 'v5'));
        await stateV5.create(recursive: true);
        await File(p.join(stateV5.path, 'tinest.sqlite')).writeAsString('db');
        final holder = await DaemonLockHolder.start(
          root: root,
          lockPath: p.join(stateV5.path, 'daemon.lock'),
        );

        try {
          await expectLater(
            DaemonDataReset(
              configDirectory: state.path,
              homeDirectory: state.path,
            ).eraseAll(),
            throwsA(
              isA<DaemonDataResetException>().having(
                (error) => error.reason,
                'reason',
                DaemonDataResetFailureReason.daemonRunning,
              ),
            ),
          );
          expect(
            File(p.join(stateV5.path, 'tinest.sqlite')).existsSync(),
            isTrue,
          );
        } finally {
          await holder.stop();
        }
      },
      tags: const <String>['feature_test__settings_reset__unit'],
    );
  });
}
