import 'dart:async';
import 'dart:io';

import 'package:daemon/src/features/prompts/infrastructure/built_in_skills.dart';
import 'package:daemon/src/features/prompts/infrastructure/skills.dart';
import 'package:path/path.dart' as p;
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late Directory configHome;
  late Directory userHome;
  late Directory project;

  Future<void> writeSkill(
    Directory skillsRoot,
    String id, {
    String? name,
    String description = 'Does something useful.',
    String body = 'Do the thing.',
    String? rawSource,
  }) async {
    final directory = Directory(p.join(skillsRoot.path, id));
    await directory.create(recursive: true);
    await File(p.join(directory.path, 'SKILL.md')).writeAsString(
      rawSource ??
          '---\n'
              'name: ${name ?? id}\n'
              'description: $description\n'
              '---\n\n'
              '$body\n',
    );
  }

  SkillCatalogService buildService({
    List<BuiltInSkill> builtIns = builtInSkills,
    int maxProjectRoots = 8,
  }) => SkillCatalogService(
    store: FileSkillStore(
      roots: <SkillFiles>[
        NativeSkillFiles(
          p.join(userHome.path, '.agents', 'skills'),
          origin: SkillOrigin.userHome,
        ),
        NativeSkillFiles(
          p.join(configHome.path, 'skills'),
          origin: SkillOrigin.config,
          createIfMissing: true,
        ),
      ],
      builtIns: builtIns,
      watchDebounce: const Duration(milliseconds: 20),
      maxProjectRoots: maxProjectRoots,
    ),
  );

  SkillScope projectScope() => SkillScope(projectRoot: project.path);

  Future<List<SkillSummaryDto>> list(
    SkillCatalogService service,
    SkillListView view, {
    SkillScope scope = SkillScope.global,
  }) => service.list(view: view, scope: scope);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('tinest-skills-');
    configHome = Directory(p.join(root.path, 'config'))..createSync();
    userHome = Directory(p.join(root.path, 'home'))..createSync();
    project = Directory(p.join(root.path, 'project'))..createSync();
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  test('global view lists only effective built-in and global skills', () async {
    await writeSkill(
      Directory(p.join(userHome.path, '.agents', 'skills')),
      'shared',
      description: 'From user home.',
    );
    await writeSkill(
      Directory(p.join(configHome.path, 'skills')),
      'shared',
      description: 'From config.',
    );
    final service = buildService();
    addTearDown(service.close);

    final skills = await list(service, SkillListView.global);

    expect(skills.map((skill) => skill.id), contains('coding-conventions'));
    expect(
      skills
          .singleWhere((skill) => skill.id == 'coding-conventions')
          .isImplicit,
      isTrue,
    );
    expect(
      skills.singleWhere((skill) => skill.id == 'shared').description,
      'From config.',
    );
    expect(skills.where((skill) => skill.id == 'shared'), hasLength(1));
  }, tags: const <String>['feature_test__skill_catalog__unit']);

  test('project view contains only effective project-owned winners', () async {
    final globalRoot = Directory(p.join(configHome.path, 'skills'));
    final projectRoot = Directory(p.join(project.path, '.agents', 'skills'));
    await writeSkill(globalRoot, 'global-only');
    await writeSkill(globalRoot, 'shared', description: 'From config.');
    await writeSkill(projectRoot, 'shared', description: 'From project.');
    await writeSkill(projectRoot, 'project-only');
    final service = buildService();
    addTearDown(service.close);

    final projectSkills = await list(
      service,
      SkillListView.project,
      scope: projectScope(),
    );
    final effective = await list(
      service,
      SkillListView.effective,
      scope: projectScope(),
    );

    expect(
      projectSkills.map((skill) => skill.id),
      orderedEquals(<String>['project-only', 'shared']),
    );
    expect(
      projectSkills.singleWhere((skill) => skill.id == 'shared').description,
      'From project.',
    );
    expect(effective.map((skill) => skill.id), contains('global-only'));
    expect(
      effective.singleWhere((skill) => skill.id == 'shared').description,
      'From project.',
    );
  }, tags: const <String>['feature_test__skill_catalog__unit']);

  test('project view requires a project root', () async {
    final service = buildService();
    addTearDown(service.close);

    expect(
      () => list(service, SkillListView.project),
      throwsA(isA<ArgumentError>()),
    );
  }, tags: const <String>['feature_test__skill_catalog__unit']);

  test(
    'protected built-in wins while a normal built-in can be replaced',
    () async {
      final configSkills = Directory(p.join(configHome.path, 'skills'));
      await writeSkill(
        configSkills,
        'protected',
        description: 'External protected replacement.',
      );
      await writeSkill(
        configSkills,
        'replaceable',
        description: 'External replacement.',
      );
      final service = buildService(
        builtIns: const <BuiltInSkill>[
          BuiltInSkill(
            id: 'protected',
            name: 'protected',
            description: 'Protected built-in.',
            body: 'Protected.',
            isImplicit: true,
          ),
          BuiltInSkill(
            id: 'replaceable',
            name: 'replaceable',
            description: 'Normal built-in.',
            body: 'Normal.',
          ),
        ],
      );
      addTearDown(service.close);

      final skills = await list(service, SkillListView.global);

      expect(
        skills.singleWhere((skill) => skill.id == 'protected').description,
        'Protected built-in.',
      );
      expect(
        skills.singleWhere((skill) => skill.id == 'protected').isImplicit,
        isTrue,
      );
      expect(
        skills.singleWhere((skill) => skill.id == 'replaceable').description,
        'External replacement.',
      );
    },
    tags: const <String>['feature_test__skill_catalog__unit'],
  );

  test(
    'malformed higher-precedence candidate falls back to a valid lower one',
    () async {
      await writeSkill(
        Directory(p.join(userHome.path, '.agents', 'skills')),
        'fragile',
        description: 'Valid fallback.',
      );
      await writeSkill(
        Directory(p.join(configHome.path, 'skills')),
        'fragile',
        rawSource: 'no frontmatter here',
      );
      final service = buildService();
      addTearDown(service.close);

      final skills = await list(service, SkillListView.global);

      expect(
        skills.singleWhere((skill) => skill.id == 'fragile').description,
        'Valid fallback.',
      );
    },
    tags: const <String>['feature_test__skill_catalog__unit'],
  );

  test(
    'callable-name collisions use precedence then stable ID order',
    () async {
      final userSkills = Directory(p.join(userHome.path, '.agents', 'skills'));
      final configSkills = Directory(p.join(configHome.path, 'skills'));
      await writeSkill(
        userSkills,
        'user-id',
        name: 'same-command',
        description: 'User home.',
      );
      await writeSkill(
        configSkills,
        'z-config',
        name: 'same-command',
        description: 'Config Z.',
      );
      await writeSkill(
        configSkills,
        'a-config',
        name: 'same-command',
        description: 'Config A.',
      );
      final service = buildService();
      addTearDown(service.close);

      final skills = await list(service, SkillListView.global);

      expect(
        skills.where((skill) => skill.name == 'same-command').single.id,
        'a-config',
      );
    },
    tags: const <String>['feature_test__skill_catalog__unit'],
  );

  test('legacy enablement values do not disable valid skills', () async {
    await writeSkill(
      Directory(p.join(configHome.path, 'skills')),
      'always-available',
    );
    // The store deliberately has no SettingsRepository dependency. A stale
    // database value therefore cannot alter the filesystem catalog.
    final service = buildService();
    addTearDown(service.close);

    expect(
      (await list(service, SkillListView.global)).map((skill) => skill.id),
      contains('always-available'),
    );
  }, tags: const <String>['feature_test__skill_catalog__unit']);

  test(
    'watcher detects a root created after startup plus edits and deletion',
    () async {
      final service = buildService();
      addTearDown(service.close);
      await list(service, SkillListView.global);
      final skillsRoot = Directory(p.join(userHome.path, '.agents', 'skills'));

      var changed = service.changes.first;
      await writeSkill(skillsRoot, 'watched', description: 'Created.');
      await _awaitChange(changed, skillsRoot);
      await _waitForDescription(service, 'watched', 'Created.');

      changed = service.changes.first;
      await writeSkill(skillsRoot, 'watched', description: 'Edited.');
      await _awaitChange(changed, skillsRoot);
      await _waitForDescription(service, 'watched', 'Edited.');

      changed = service.changes.first;
      await Directory(p.join(skillsRoot.path, 'watched'))
          .delete(recursive: true);
      await _awaitChange(changed, skillsRoot);
      await _waitForMissing(service, 'watched');
    },
    tags: const <String>['feature_test__skill_catalog__unit'],
  );

  test('existing root watcher observes nested SKILL.md edits', () async {
    final skillsRoot = Directory(p.join(userHome.path, '.agents', 'skills'));
    await writeSkill(skillsRoot, 'watched', description: 'Created.');
    final service = buildService();
    addTearDown(service.close);
    await list(service, SkillListView.global);

    final changed = service.changes.first;
    await writeSkill(skillsRoot, 'watched', description: 'Edited.');

    await _awaitChange(changed, skillsRoot);
    await _waitForDescription(service, 'watched', 'Edited.');
  }, tags: const <String>['feature_test__skill_catalog__unit']);

  test('watcher observes existing nested resource directories', () async {
    final skillsRoot = Directory(p.join(userHome.path, '.agents', 'skills'));
    await writeSkill(skillsRoot, 'watched');
    final resource = File(
      p.join(skillsRoot.path, 'watched', 'scripts', 'helper.dart'),
    );
    await resource.parent.create(recursive: true);
    await resource.writeAsString('void main() {}');
    final files = NativeSkillFiles(
      skillsRoot.path,
      origin: SkillOrigin.userHome,
    );
    await files.initialize();
    addTearDown(files.close);

    final changed = files.changes.first;
    await resource.writeAsString('void main() => print("updated");');

    await _awaitChange(changed, skillsRoot);
  }, tags: const <String>['feature_test__skill_catalog__unit']);

  test('missing root watcher ignores unrelated sibling changes', () async {
    final skillsRoot = Directory(p.join(project.path, '.agents', 'skills'));
    final files = NativeSkillFiles(
      skillsRoot.path,
      origin: SkillOrigin.project,
    );
    await files.initialize();
    addTearDown(files.close);
    var changes = 0;
    final relevantChange = Completer<void>();
    final subscription = files.changes.listen((_) {
      changes += 1;
      if (!relevantChange.isCompleted) relevantChange.complete();
    });
    addTearDown(subscription.cancel);

    await File(p.join(project.path, 'unrelated.txt')).writeAsString('no-op');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(changes, 0);

    await writeSkill(skillsRoot, 'watched');
    await _awaitChange(relevantChange.future, skillsRoot, files: files);
    expect(changes, greaterThan(0));
  }, tags: const <String>['feature_test__skill_catalog__unit']);

  test(
    'a root created behind an ancestor watch is reported on the next anchor',
    () async {
      final skillsRoot = Directory(p.join(project.path, '.agents', 'skills'));
      final files = NativeSkillFiles(
        skillsRoot.path,
        origin: SkillOrigin.project,
      );
      await files.initialize();
      addTearDown(files.close);

      final changed = files.changes.first;
      await writeSkill(skillsRoot, 'watched');
      // The ancestor watcher can deliver the `.agents` creation while the
      // skills root does not exist yet; the path filter then drops it and
      // native watchers never replay. Do not depend on that event ordering:
      // the next read re-anchors the watch set, and anchoring onto the
      // materialized root must itself report the potentially dropped change.
      expect(
        (await files.read()).map((document) => document.id),
        contains('watched'),
      );
      await _awaitChange(changed, skillsRoot);
    },
    tags: const <String>['feature_test__skill_catalog__unit'],
  );

  test(
    'a root that appears while its ancestor watch arms is still reported',
    () async {
      final agents = Directory(p.join(project.path, '.agents'));
      final skillsRoot = Directory(p.join(agents.path, 'skills'));
      final controllers = <String, StreamController<SkillWatchEvent>>{};
      final files = NativeSkillFiles(
        skillsRoot.path,
        origin: SkillOrigin.project,
        openWatch: (path) {
          // Arming a native watch is not instant, and the level below the one
          // being armed can appear inside that window. On a loaded host that
          // window is wide enough to hit; here it is made exact.
          if (p.equals(path, agents.path) && !skillsRoot.existsSync()) {
            skillsRoot.createSync(recursive: true);
          }
          final controller = StreamController<SkillWatchEvent>.broadcast();
          controllers[p.normalize(p.absolute(path))] = controller;
          return controller.stream;
        },
      );
      await files.initialize();
      addTearDown(() async {
        for (final controller in controllers.values) {
          await controller.close();
        }
      });
      addTearDown(files.close);
      final changed = files.changes.first;

      // The ancestor watch reports `.agents` appearing, and that is the only
      // notification that will ever be delivered: the skills root is created
      // below a watch that is not recursive, so nothing observes it.
      agents.createSync();
      controllers[p.normalize(p.absolute(project.path))]!.add(
        SkillWatchEvent(path: agents.path),
      );

      await _awaitChange(changed, skillsRoot, files: files);
      expect(files.watchedPaths, contains(p.normalize(skillsRoot.path)));
    },
    tags: const <String>['feature_test__skill_catalog__unit'],
  );

  test(
    'watch path filter accepts only related absolute and relative paths',
    () {
      final skillRoot = p.join(root.path, 'tracked', '.agents', 'skills');
      final filter = SkillWatchPathFilter(
        skillRoot: skillRoot,
        watchedRoot: root.path,
      );

      expect(
        filter.accepts('sibling-worktree', skillRootExists: false),
        isFalse,
      );
      expect(filter.accepts('tracked', skillRootExists: false), isFalse);
      expect(
        filter.accepts(p.join('tracked', '.agents'), skillRootExists: false),
        isFalse,
      );
      expect(
        filter.accepts(
          p.relative(skillRoot, from: root.path),
          skillRootExists: false,
        ),
        isTrue,
      );
      expect(filter.accepts('tracked', skillRootExists: true), isTrue);
      expect(
        filter.accepts(
          p.join('tracked', '.agents', 'skills', 'commit', 'SKILL.md'),
          skillRootExists: false,
        ),
        isTrue,
      );
      expect(
        filter.accepts(p.join(root.path, 'other'), skillRootExists: true),
        isFalse,
      );
    },
    tags: const <String>['feature_test__skill_catalog__unit'],
  );

  test(
    'turn catalog uses the same winners and reads bundled files',
    () async {
      final configSkills = Directory(p.join(configHome.path, 'skills'));
      final projectSkills = Directory(
        p.join(project.path, '.agents', 'skills'),
      );
      await writeSkill(
        configSkills,
        'global-id',
        name: 'shared-command',
        description: 'Global.',
        body: 'Global instructions.',
      );
      await writeSkill(
        projectSkills,
        'project-id',
        name: 'shared-command',
        description: 'Project.',
        body: 'Project instructions.',
      );
      await File(p.join(projectSkills.path, 'project-id', 'helper.txt'))
          .writeAsString('helper contents');
      final service = buildService();
      addTearDown(service.close);

      final catalog = await service.viewFor(project.path);

      expect(
        catalog.implicitSkillDocuments().single.instructions,
        contains('Before writing code'),
      );
      expect(
        catalog
            .implicitSkillDocuments()
            .map((document) => document.instructions)
            .join('\n\n'),
        isNot(contains('Project instructions.')),
      );
      expect(
        catalog
            .summaries()
            .singleWhere((summary) => summary.name == 'shared-command')
            .description,
        'Project.',
      );
      final content = await catalog.read('shared-command');
      expect(content.instructions, 'Project instructions.');
      expect(content.directory, p.join(projectSkills.path, 'project-id'));
      expect(
        await catalog.readResource('shared-command', 'helper.txt'),
        'helper contents',
      );
      expect(
        () => catalog.readResource('shared-command', '../secret'),
        throwsA(isA<FileSystemException>()),
      );
    },
    tags: const <String>[
      'feature_test__skill_catalog__unit',
      'feature_test__skill_invocation__unit',
    ],
  );

  test('project root cache evicts the oldest watcher past its limit', () async {
    final service = buildService(maxProjectRoots: 2);
    addTearDown(service.close);

    for (var index = 0; index < 3; index += 1) {
      final directory = Directory(p.join(root.path, 'project-$index'))
        ..createSync();
      await writeSkill(
        Directory(p.join(directory.path, '.agents', 'skills')),
        'local-$index',
      );
      expect(
        (await list(
          service,
          SkillListView.project,
          scope: SkillScope(projectRoot: directory.path),
        )).map((skill) => skill.id),
        contains('local-$index'),
      );
    }

    expect(service.trackedProjectRoots, 2);
  }, tags: const <String>['feature_test__skill_catalog__unit']);

  test('a closed store rejects further work', () async {
    final service = buildService();
    await list(service, SkillListView.global);
    await service.close();
    await service.close();

    expect(
      () => list(service, SkillListView.global),
      throwsA(isA<StateError>()),
    );
  }, tags: const <String>['feature_test__skill_catalog__unit']);
}

/// Awaits a watcher change, reporting what the filesystem looked like when it
/// never came.
///
/// A bare `TimeoutException after 0:00:10` says only that no event arrived,
/// which is true of a dropped native event, a watcher anchored somewhere else,
/// and a write that never landed. Those need different fixes and the message
/// cannot tell them apart. This has failed on a loaded CI host without
/// reproducing anywhere else, so the run that fails has to carry its own
/// evidence.
Future<void> _awaitChange(
  Future<void> changed,
  Directory skillsRoot, {
  NativeSkillFiles? files,
  Duration budget = const Duration(seconds: 10),
}) async {
  try {
    await changed.timeout(budget);
  } on TimeoutException {
    final root = skillsRoot.existsSync()
        ? skillsRoot
              .listSync()
              .map((entity) => p.basename(entity.path))
              .toList(growable: false)
              .toString()
        : 'missing';
    final limits = <String, String>{};
    for (final knob in <String>[
      'max_queued_events',
      'max_user_instances',
      'max_user_watches',
    ]) {
      final file = File('/proc/sys/fs/inotify/$knob');
      if (file.existsSync()) limits[knob] = file.readAsStringSync().trim();
    }
    throw TestFailure(
      'No skill catalog change within ${budget.inSeconds}s. '
      'skillsRoot=${skillsRoot.path} contents=$root'
      '${limits.isEmpty ? '' : ' inotify=$limits'}'
      '${files == null ? '' : ' watching=${files.watchedPaths}'}',
    );
  }
}

Future<void> _waitForDescription(
  SkillCatalogService service,
  String id,
  String description,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    final skills = await service.list(view: SkillListView.global);
    if (skills.any(
      (skill) => skill.id == id && skill.description == description,
    )) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('Timed out waiting for $id to have description $description.');
}

Future<void> _waitForMissing(SkillCatalogService service, String id) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    final skills = await service.list(view: SkillListView.global);
    if (skills.every((skill) => skill.id != id)) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('Timed out waiting for $id to be removed.');
}
