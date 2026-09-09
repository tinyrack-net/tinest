import 'dart:io';

import 'package:daemon/src/features/workspaces/infrastructure/file_index.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group(
    'GitAwareFileIndexGateway',
    tags: const <String>['feature_test__composer_file_mention__unit'],
    () {
      late _MutableClock clock;

      setUp(() => clock = _MutableClock());

      FileSearchRequest request(
        String query, {
        String root = '/worktree',
        int limit = 50,
        int maxDepth = 12,
        int maxScannedEntries = 20000,
      }) => FileSearchRequest(
        root: root,
        query: query,
        limit: limit,
        maxDepth: maxDepth,
        maxScannedEntries: maxScannedEntries,
      );

      test(
        'indexes a repository through git and drops ignored files',
        () async {
          final runner = _ScriptedCommandRunner(<String, CommandResult>{
            '/worktree': _gitOutput(<String>[
              'lib/src/app.dart',
              'lib/src/session_composer.dart',
              'README.md',
            ]),
          });
          final gateway = GitAwareFileIndexGateway(runner, clock);

          final result = await gateway.search(request('app'));

          expect(runner.invocations, hasLength(1));
          expect(runner.invocations.single.executable, 'git');
          expect(runner.invocations.single.arguments, <String>[
            'ls-files',
            '--cached',
            '--others',
            '--exclude-standard',
            '--deduplicate',
            '-z',
          ]);
          expect(runner.invocations.single.workingDirectory, '/worktree');
          expect(
            result.matches.map((match) => match.relativePath),
            contains('lib/src/app.dart'),
          );
          expect(result.truncated, isFalse);
        },
      );

      test('reports absolute paths, basenames, and POSIX paths', () async {
        final gateway = GitAwareFileIndexGateway(
          _ScriptedCommandRunner(<String, CommandResult>{
            '/worktree': _gitOutput(<String>['lib/src/app.dart']),
          }),
          clock,
        );

        final match = (await gateway.search(request('app.dart'))).matches.first;

        expect(match.relativePath, 'lib/src/app.dart');
        // Normalized, not merely joined: a root that arrives in another
        // separator must not survive into the result.
        expect(
          match.absolutePath,
          p.normalize(p.join('/worktree', 'lib', 'src', 'app.dart')),
        );
        expect(match.name, 'app.dart');
        expect(match.isDirectory, isFalse);
      });

      test(
        'synthesizes directories from the parent prefixes of files',
        () async {
          final gateway = GitAwareFileIndexGateway(
            _ScriptedCommandRunner(<String, CommandResult>{
              '/worktree': _gitOutput(<String>['lib/src/app.dart']),
            }),
            clock,
          );

          final result = await gateway.search(request('src'));
          final directories = result.matches.where(
            (match) => match.isDirectory,
          );

          expect(
            directories.map((match) => match.relativePath),
            contains('lib/src'),
          );
        },
      );

      test('ranks basename matches above interior path matches', () async {
        final gateway = GitAwareFileIndexGateway(
          _ScriptedCommandRunner(<String, CommandResult>{
            '/worktree': _gitOutput(<String>[
              'composer/notes.md',
              'lib/composer.dart',
            ]),
          }),
          clock,
        );

        final result = await gateway.search(request('composer'));
        final ranked = result.matches
            .map((match) => match.relativePath)
            .toList(growable: false);

        expect(
          ranked.indexOf('lib/composer.dart'),
          lessThan(ranked.indexOf('composer/notes.md')),
        );
      });

      test(
        'returns the shallow head of the index for an empty query',
        () async {
          final gateway = GitAwareFileIndexGateway(
            _ScriptedCommandRunner(<String, CommandResult>{
              '/worktree': _gitOutput(<String>['a/b/c/deep.dart', 'top.dart']),
            }),
            clock,
          );

          final result = await gateway.search(request(''));

          expect(result.matches.first.relativePath, 'top.dart');
        },
      );

      test('drops candidates the query does not match at all', () async {
        final gateway = GitAwareFileIndexGateway(
          _ScriptedCommandRunner(<String, CommandResult>{
            '/worktree': _gitOutput(<String>['lib/app.dart', 'README.md']),
          }),
          clock,
        );

        final result = await gateway.search(request('zzzz'));

        expect(result.matches, isEmpty);
      });

      test('caps the returned matches at the requested limit', () async {
        final gateway = GitAwareFileIndexGateway(
          _ScriptedCommandRunner(<String, CommandResult>{
            '/worktree': _gitOutput(<String>[
              for (var index = 0; index < 30; index += 1) 'lib/file$index.dart',
            ]),
          }),
          clock,
        );

        final result = await gateway.search(request('file', limit: 5));

        expect(result.matches, hasLength(5));
      });

      test('serves a search inside the cache window unchanged', () async {
        final runner = _ScriptedCommandRunner(<String, CommandResult>{
          '/worktree': _gitOutput(<String>['lib/app.dart']),
        });
        final gateway = GitAwareFileIndexGateway(runner, clock);

        await gateway.search(request('app'));
        clock.advance(GitAwareFileIndexGateway.indexTtl - _tick);
        await gateway.search(request('app'));

        expect(runner.invocations, hasLength(1));
      });

      test('serves a stale index and refreshes it in the background', () async {
        final runner = _ScriptedCommandRunner(<String, CommandResult>{
          '/worktree': _gitOutput(<String>['lib/old.dart']),
        });
        final gateway = GitAwareFileIndexGateway(runner, clock);
        await gateway.search(request(''));

        runner.results['/worktree'] = _gitOutput(<String>['lib/new.dart']);
        clock.advance(GitAwareFileIndexGateway.indexTtl + _tick);
        final stale = await gateway.search(request(''));

        expect(
          stale.matches.map((match) => match.relativePath),
          contains('lib/old.dart'),
        );
        expect(runner.invocations, hasLength(2));

        await pumpEventQueue();
        final fresh = await gateway.search(request(''));

        expect(
          fresh.matches.map((match) => match.relativePath),
          contains('lib/new.dart'),
        );
        expect(runner.invocations, hasLength(2));
      });

      test('collapses concurrent cold searches into one index build', () async {
        final runner = _ScriptedCommandRunner(<String, CommandResult>{
          '/worktree': _gitOutput(<String>['lib/app.dart']),
        });
        final gateway = GitAwareFileIndexGateway(runner, clock);

        await Future.wait(<Future<void>>[
          gateway.search(request('app')),
          gateway.search(request('app')),
        ]);

        expect(runner.invocations, hasLength(1));
      });

      test('invalidate forces the next search to rebuild the index', () async {
        final runner = _ScriptedCommandRunner(<String, CommandResult>{
          '/worktree': _gitOutput(<String>['lib/old.dart']),
        });
        final gateway = GitAwareFileIndexGateway(runner, clock);
        await gateway.search(request(''));

        runner.results['/worktree'] = _gitOutput(<String>['lib/new.dart']);
        gateway.invalidate('/worktree');
        final result = await gateway.search(request(''));

        expect(
          result.matches.map((match) => match.relativePath),
          contains('lib/new.dart'),
        );
        expect(runner.invocations, hasLength(2));
      });

      test('evicts the oldest root beyond the cache bound', () async {
        final roots = <String>[
          for (
            var index = 0;
            index <= GitAwareFileIndexGateway.maxCachedRoots;
            index += 1
          )
            '/root$index',
        ];
        final runner = _ScriptedCommandRunner(<String, CommandResult>{
          for (final root in roots) root: _gitOutput(<String>['lib/app.dart']),
        });
        final gateway = GitAwareFileIndexGateway(runner, clock);

        for (final root in roots) {
          await gateway.search(request('app', root: root));
          clock.advance(_tick);
        }
        await gateway.search(request('app', root: roots.first));

        expect(runner.invocations, hasLength(roots.length + 1));
      });
    },
  );

  group('absolutePathFor', () {
    test('keeps a Windows join in one separator', () {
      // Git reports the root with forward slashes even on Windows, which
      // used to leave a path mixing both separators behind.
      expect(
        absolutePathFor(
          'C:/repo',
          'lib/app.dart',
          context: p.Context(style: p.Style.windows),
        ),
        r'C:\repo\lib\app.dart',
      );
    }, tags: const <String>['feature_test__composer_file_mention__unit']);

    test('keeps a POSIX join in one separator', () {
      expect(
        absolutePathFor(
          '/repo',
          'lib/app.dart',
          context: p.Context(style: p.Style.posix),
        ),
        '/repo/lib/app.dart',
      );
    }, tags: const <String>['feature_test__composer_file_mention__unit']);
  });

  group(
    'GitAwareFileIndexGateway outside a repository',
    tags: const <String>['feature_test__composer_file_mention__unit'],
    () {
      late Directory root;
      late _MutableClock clock;
      late GitAwareFileIndexGateway gateway;

      setUp(() async {
        clock = _MutableClock();
        root = await Directory.systemTemp.createTemp('tinest-file-index-');
        gateway = GitAwareFileIndexGateway(_FailingCommandRunner(), clock);
      });

      tearDown(() async => await root.delete(recursive: true));

      Future<void> write(String relativePath) async {
        final file = File(
          p.join(root.path, p.joinAll(relativePath.split('/'))),
        );
        await file.parent.create(recursive: true);
        await file.writeAsString('contents');
      }

      test('walks the directory tree when git reports no repository', () async {
        await write('lib/app.dart');
        await write('README.md');

        final result = await gateway.search(
          FileSearchRequest(root: root.path, query: 'app'),
        );

        expect(
          result.matches.map((match) => match.relativePath),
          contains('lib/app.dart'),
        );
      });

      test('skips build and dependency directories during the walk', () async {
        await write('lib/target.dart');
        await write('node_modules/target.dart');
        await write('.dart_tool/target.dart');
        await write('build/target.dart');

        final result = await gateway.search(
          FileSearchRequest(root: root.path, query: 'target'),
        );

        expect(result.matches.map((match) => match.relativePath), <String>[
          'lib/target.dart',
        ]);
      });

      test('stops at the depth budget without failing the search', () async {
        await write('a/b/c/deep.dart');
        await write('shallow.dart');

        final result = await gateway.search(
          FileSearchRequest(root: root.path, query: '', maxDepth: 1),
        );

        expect(
          result.matches.map((match) => match.relativePath),
          contains('shallow.dart'),
        );
        expect(
          result.matches.map((match) => match.relativePath),
          isNot(contains('a/b/c/deep.dart')),
        );
      });

      test('reports truncation when the entry budget runs out', () async {
        for (var index = 0; index < 12; index += 1) {
          await write('lib/file$index.dart');
        }

        final result = await gateway.search(
          FileSearchRequest(root: root.path, query: '', maxScannedEntries: 4),
        );

        expect(result.truncated, isTrue);
      });

      test('returns an empty result for a root that does not exist', () async {
        final result = await gateway.search(
          FileSearchRequest(root: p.join(root.path, 'missing'), query: 'app'),
        );

        expect(result.matches, isEmpty);
        expect(result.truncated, isFalse);
      });
    },
  );
}

const Duration _tick = Duration(seconds: 1);

CommandResult _gitOutput(List<String> paths) => CommandResult(
  exitCode: 0,
  stdout: paths.map((path) => '$path\u0000').join(),
  stderr: '',
);

final class _MutableClock implements Clock {
  DateTime _now = DateTime.utc(2026, 8, 6);

  void advance(Duration duration) => _now = _now.add(duration);

  @override
  DateTime nowUtc() => _now;
}

final class _CommandInvocation {
  const new({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
  });

  final String executable;
  final List<String> arguments;
  final String workingDirectory;
}

final class _ScriptedCommandRunner implements CommandRunner {
  new(this.results);

  final Map<String, CommandResult> results;
  final List<_CommandInvocation> invocations = <_CommandInvocation>[];

  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
  }) async {
    invocations.add(
      _CommandInvocation(
        executable: executable,
        arguments: List<String>.unmodifiable(arguments),
        workingDirectory: workingDirectory,
      ),
    );
    return results[workingDirectory] ??
        const CommandResult(exitCode: 128, stdout: '', stderr: 'not a repo');
  }
}

final class _FailingCommandRunner implements CommandRunner {
  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
  }) async => const CommandResult(
    exitCode: 128,
    stdout: '',
    stderr: 'fatal: not a git repository',
  );
}
