import 'dart:async';
import 'dart:io';

import 'package:daemon/src/features/prompts/infrastructure/commands.dart';
import 'package:path/path.dart' as p;
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  late Directory home;
  late Directory config;
  late Directory project;

  setUp(() async {
    home = await Directory.systemTemp.createTemp('tinest-commands-home-');
    config = await Directory.systemTemp.createTemp('tinest-commands-config-');
    project = await Directory.systemTemp.createTemp('tinest-commands-project-');
  });

  tearDown(() async {
    await home.delete(recursive: true);
    await config.delete(recursive: true);
    await project.delete(recursive: true);
  });

  Future<void> write(Directory root, String name, String contents) async {
    final file = File(p.join(root.path, '$name.md'));
    await file.parent.create(recursive: true);
    await file.writeAsString(contents);
  }

  CommandService service() => CommandService(
    globalSources: <CommandFiles>[
      NativeCommandFiles(home.path, source: AgentCommandSource.userHome),
      NativeCommandFiles(config.path, source: AgentCommandSource.config),
    ],
    projectFiles: (root) => NativeCommandFiles(
      p.join(root, '.agents', 'commands'),
      source: AgentCommandSource.project,
    ),
  );

  String projectCommands() => p.join(project.path, '.agents', 'commands');

  group(
    'CommandService parsing',
    tags: const <String>['feature_test__composer_slash_command__unit'],
    () {
      test('reads front matter into a typed command', () async {
        await write(config, 'review', r'''
---
description: Reviews the working diff.
argument-hint: <path>
---

Review $ARGUMENTS and report defects.
''');

        final commands = await service().list();

        expect(commands, hasLength(1));
        final command = commands.single;
        expect(command.id, 'review');
        expect(command.name, 'review');
        expect(command.description, 'Reviews the working diff.');
        expect(command.argumentHint, '<path>');
        expect(command.source, AgentCommandSource.config);
        expect(command.sourcePath, p.join(config.path, 'review.md'));
        expect(command.body, r'Review $ARGUMENTS and report defects.');
      });

      test(
        'prefers an explicit front matter name over the file name',
        () async {
          await write(config, 'review-diff', '''
---
name: review
description: Reviews the working diff.
---

Review the diff.
''');

          final command = (await service().list()).single;

          expect(command.id, 'review-diff');
          expect(command.name, 'review');
        },
      );

      test('treats a document without front matter as a bare prompt', () async {
        await write(config, 'ship', 'Ship the current branch.\n');

        final command = (await service().list()).single;

        expect(command.name, 'ship');
        expect(command.description, isEmpty);
        expect(command.argumentHint, isNull);
        expect(command.body, 'Ship the current branch.');
      });

      test('keeps a command whose front matter omits a description', () async {
        await write(config, 'ship', '''
---
argument-hint: <branch>
---

Ship the branch.
''');

        final command = (await service().list()).single;

        expect(command.description, isEmpty);
        expect(command.argumentHint, '<branch>');
      });

      test('skips a document whose front matter is not valid YAML', () async {
        await write(config, 'broken', '''
---
description: "unterminated
  : :
---

Body.
''');
        await write(config, 'valid', '''
---
description: Works.
---

Body.
''');

        final commands = await service().list();

        expect(commands.map((command) => command.name), <String>['valid']);
      });

      test('ignores files that are not Markdown documents', () async {
        await File(p.join(config.path, 'notes.txt')).writeAsString('ignored');
        await Directory(p.join(config.path, 'nested')).create();
        await write(
          config,
          'valid',
          '---\ndescription: Works.\n---\n\nBody.\n',
        );

        final commands = await service().list();

        expect(commands.map((command) => command.name), <String>['valid']);
      });

      test('returns nothing when no command root exists', () async {
        await config.delete(recursive: true);
        await home.delete(recursive: true);

        expect(await service().list(), isEmpty);

        config = await Directory.systemTemp.createTemp(
          'tinest-commands-config-',
        );
        home = await Directory.systemTemp.createTemp('tinest-commands-home-');
      });
    },
  );

  group(
    'CommandService precedence',
    tags: const <String>['feature_test__composer_slash_command__unit'],
    () {
      test('lets a project command shadow config and home', () async {
        await write(home, 'review', '---\ndescription: Home.\n---\n\nHome.\n');
        await write(config, 'review', '---\ndescription: Config.\n---\n\nC.\n');
        await write(
          Directory(projectCommands()),
          'review',
          '---\ndescription: Project.\n---\n\nProject.\n',
        );

        final commands = await service().list(
          scope: CommandScope(workspaceId: 'w', projectRoot: project.path),
        );

        expect(commands, hasLength(1));
        expect(commands.single.description, 'Project.');
        expect(commands.single.source, AgentCommandSource.project);
      });

      test('lets a config command shadow home', () async {
        await write(home, 'review', '---\ndescription: Home.\n---\n\nHome.\n');
        await write(config, 'review', '---\ndescription: Config.\n---\n\nC.\n');

        final command = (await service().list()).single;

        expect(command.source, AgentCommandSource.config);
      });

      test('dedupes on the resolved name, not the file name', () async {
        await write(home, 'review', '---\ndescription: Home.\n---\n\nHome.\n');
        await write(
          config,
          'review-diff',
          '---\nname: review\ndescription: Config.\n---\n\nC.\n',
        );

        final commands = await service().list();

        expect(commands, hasLength(1));
        expect(commands.single.source, AgentCommandSource.config);
      });

      test('omits project commands when no project root is scoped', () async {
        await write(
          Directory(projectCommands()),
          'review',
          '---\ndescription: Project.\n---\n\nProject.\n',
        );

        expect(await service().list(), isEmpty);
      });

      test('sorts the merged catalog by name', () async {
        await write(config, 'zebra', '---\ndescription: Z.\n---\n\nZ.\n');
        await write(config, 'alpha', '---\ndescription: A.\n---\n\nA.\n');
        await write(home, 'middle', '---\ndescription: M.\n---\n\nM.\n');

        final commands = await service().list();

        expect(commands.map((command) => command.name), <String>[
          'alpha',
          'middle',
          'zebra',
        ]);
      });
    },
  );

  group(
    'CommandService change notifications',
    tags: const <String>['feature_test__composer_slash_command__unit'],
    () {
      test('forwards a change from any global source', () async {
        final userHome = _FakeCommandFiles(AgentCommandSource.userHome);
        final scoped = _FakeCommandFiles(AgentCommandSource.config);
        final commands = CommandService(
          globalSources: <CommandFiles>[userHome, scoped],
        );
        addTearDown(commands.close);

        final seen = <void>[];
        final subscription = commands.changes.listen(seen.add);
        addTearDown(subscription.cancel);

        userHome.emit();
        scoped.emit();
        await pumpEventQueue();

        expect(seen, hasLength(2));
      });

      test('rereads a source after it reports a change', () async {
        final files = _FakeCommandFiles(AgentCommandSource.config)
          ..documents.add(
            const CommandDocument(
              id: 'review',
              sourcePath: '/commands/review.md',
              source: '---\ndescription: First.\n---\n\nFirst.\n',
            ),
          );
        final commands = CommandService(globalSources: <CommandFiles>[files]);
        addTearDown(commands.close);

        expect((await commands.list()).single.description, 'First.');

        files.documents
          ..clear()
          ..add(
            const CommandDocument(
              id: 'review',
              sourcePath: '/commands/review.md',
              source: '---\ndescription: Second.\n---\n\nSecond.\n',
            ),
          );

        expect((await commands.list()).single.description, 'Second.');
      });

      test('closes every source it owns', () async {
        final files = _FakeCommandFiles(AgentCommandSource.config);
        final commands = CommandService(globalSources: <CommandFiles>[files]);

        await commands.close();

        expect(files.closed, isTrue);
      });
    },
  );
}

final class _FakeCommandFiles implements CommandFiles {
  new(this.source);

  @override
  final AgentCommandSource source;

  final List<CommandDocument> documents = <CommandDocument>[];
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );
  bool closed = false;

  void emit() => _changes.add(null);

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<List<CommandDocument>> read() async =>
      List<CommandDocument>.unmodifiable(documents);

  @override
  Future<void> close() async {
    closed = true;
    await _changes.close();
  }
}
