import 'dart:convert';
import 'dart:io';

import 'package:app/testing/app/tinest_app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import 'support/pump_until.dart';
import 'support/real_daemon_fixture.dart';
import 'support/tap_visible.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'project hooks save to .tinest/config.json, preserve keys, and reload',
    (tester) async {
      final fixture = await _projectFixture('project-save');
      addTearDown(fixture.$1.dispose);
      final settingsFile = File('${fixture.$2.path}/.tinest/config.json');
      await settingsFile.parent.create();
      await settingsFile.writeAsString(
        '${jsonEncode(<String, Object?>{
          'schemaVersion': 5,
          'other': <String, Object?>{'keep': true},
        })}\n',
      );

      await _pumpProjectSettings(tester, fixture.$1);
      await tester.enterText(
        _textInput('Setup (worktree 생성 후)'),
        'dart pub get\n\ndart test',
      );
      await tester.enterText(
        _textInput('Teardown (worktree 제거 전)'),
        'dart run cleanup',
      );
      await tester.tap(find.widgetWithText(TRButton, '저장'));
      await pumpUntil(tester, find.text('저장했습니다.'));

      final document =
          jsonDecode(await settingsFile.readAsString()) as Map<String, dynamic>;
      expect(document['other'], <String, dynamic>{'keep': true});
      expect(document['worktree'], <String, dynamic>{
        'setup': <dynamic>['dart pub get', 'dart test'],
        'teardown': <dynamic>['dart run cleanup'],
      });

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await _pumpProjectSettings(tester, fixture.$1);
      expect(find.textContaining('dart pub get'), findsOneWidget);
      expect(find.textContaining('dart run cleanup'), findsOneWidget);
    },
    tags: const <String>[
      'feature_scenario__project_settings__load_save_persist_hooks__e2e',
    ],
  );

  testWidgets(
    'invalid project settings report the daemon error and recover on retry',
    (tester) async {
      final fixture = await _projectFixture('project-recovery');
      addTearDown(fixture.$1.dispose);
      final settingsFile = File('${fixture.$2.path}/.tinest/config.json');
      await settingsFile.parent.create();
      await settingsFile.writeAsString('{not json\n');

      await _pumpProjectSettings(tester, fixture.$1, waitForEditor: false);
      await pumpUntil(tester, find.textContaining('invalid_project_settings'));
      expect(find.text('다시 시도'), findsOneWidget);

      await settingsFile.writeAsString(
        '${jsonEncode(<String, Object?>{'schemaVersion': 5})}\n',
        flush: true,
      );
      await tester.tap(find.widgetWithText(TRButton, '다시 시도'));
      await pumpUntil(tester, _textInput('Setup (worktree 생성 후)'));
      expect(find.textContaining('invalid_project_settings'), findsNothing);
    },
    tags: const <String>[
      'feature_scenario__project_settings__hook_failure_feedback__e2e',
    ],
  );

  testWidgets(
    'a failed setup hook removes its real Git checkout',
    (tester) async {
      final fixture = await _gitProjectFixture('worktree-setup-failure');
      addTearDown(fixture.$1.dispose);
      final client = await fixture.$1.connect(clientId: 'setup-failure');
      addTearDown(client.close);
      await client.workspaces.saveProjectSettings(
        fixture.$3,
        ProjectSettingsDto(
          setup: <String>[if (Platform.isWindows) 'exit /b 69' else 'exit 69'],
        ),
      );

      await tester.pumpWidget(TinestApp(services: fixture.$1.services));
      await pumpUntil(tester, find.text('Git Project E2E'));
      final created = await client.workspaces.createWorktree(
        id: 'failed-worktree',
        workspaceId: fixture.$3,
        mode: WorktreeCreateMode.newBranch,
        branchName: 'setup-must-fail',
        baseBranch: 'main',
      );
      await tester.pumpAndSettle();

      expect(created.hookRuns.single.exitCode, 69);
      expect(created.worktree.archivedAt, isNotNull);
      expect(Directory(created.worktree.path).existsSync(), isFalse);
      expect(
        (await client.workspaces.getWorkspaceCatalog()).worktrees.map(
          (item) => item.id,
        ),
        isNot(contains('failed-worktree')),
      );
      expect(find.text('setup-must-fail'), findsNothing);
    },
    tags: const <String>[
      'feature_scenario__worktree_lifecycle__setup_failure_cleanup__e2e',
    ],
  );

  testWidgets(
    'archive preview cancellation preserves the worktree and Git checkout',
    (tester) async {
      final fixture = await _gitProjectFixture('worktree-archive-cancel');
      addTearDown(fixture.$1.dispose);
      final client = await fixture.$1.connect(clientId: 'archive-cancel');
      addTearDown(client.close);
      await client.workspaces.createWorktree(
        id: 'cancelled-archive',
        workspaceId: fixture.$3,
        mode: WorktreeCreateMode.newBranch,
        branchName: 'archive-cancel',
        baseBranch: 'main',
      );
      final activeWorktree = (await client.workspaces.getWorkspaceCatalog())
          .worktrees
          .singleWhere((worktree) => worktree.branch == 'archive-cancel');

      tester.binding.platformDispatcher.localeTestValue = const Locale('ko');
      addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(TinestApp(services: fixture.$1.services));
      await pumpUntil(tester, find.text('archive-cancel'));
      final menu = find.byKey(
        ValueKey<String>('worktree-menu-${activeWorktree.id}'),
      );
      await pumpUntil(tester, menu);
      await tester.ensureVisible(menu);
      await tester.pumpAndSettle();
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await pumpUntil(
        tester,
        find.byKey(const ValueKey<String>('worktree-archive-confirm')),
      );
      await tester.tap(find.widgetWithText(TRButton, '취소'));
      await tester.pumpAndSettle();

      expect(Directory(activeWorktree.path).existsSync(), isTrue);
      expect(
        (await client.workspaces.getWorkspaceCatalog()).worktrees.map(
          (item) => item.id,
        ),
        contains(activeWorktree.id),
      );
      expect(find.text('archive-cancel'), findsWidgets);
    },
    tags: const <String>[
      'feature_scenario__worktree_lifecycle__archive_preview_cancel__e2e',
    ],
  );

  testWidgets(
    'archiving a discovered external worktree removes its checkout',
    (tester) async {
      final fixture = await _gitProjectFixture('worktree-archive-external');
      addTearDown(fixture.$1.dispose);
      final client = await fixture.$1.connect(clientId: 'archive-external');
      addTearDown(client.close);
      final externalPath = Directory(
        '${fixture.$1.home.path}/external-checkout',
      );
      await _runGit(fixture.$2.path, <String>[
        'worktree',
        'add',
        '-b',
        'archive-external',
        externalPath.path,
      ]);
      final catalog = await client.workspaces.refreshWorkspace(fixture.$3);
      final external = catalog.worktrees.singleWhere(
        (worktree) => worktree.branch == 'archive-external',
      );
      expect(external.kind, WorktreeKind.linked);
      // The scenario is about a checkout Tinest did not create, which is the
      // ownership field rather than a kind of its own.
      expect(external.isTinestOwned, isFalse);

      tester.binding.platformDispatcher.localeTestValue = const Locale('ko');
      addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(TinestApp(services: fixture.$1.services));
      await pumpUntil(tester, find.text('archive-external'));
      final menu = find.byKey(ValueKey<String>('worktree-menu-${external.id}'));
      await tester.ensureVisible(menu);
      await tester.pumpAndSettle();
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await pumpUntil(
        tester,
        find.byKey(const ValueKey<String>('worktree-archive-confirm')),
      );
      expect(find.text('checkout 디렉터리가 제거됩니다.'), findsOneWidget);
      await tester.tap(find.widgetWithText(TRButton, 'Archive'));
      await pumpUntilGone(tester, find.text('archive-external'));

      expect(externalPath.existsSync(), isFalse);
      expect(
        (await client.workspaces.listGitBranches(fixture.$3))
            .map((branch) => branch.name),
        contains('archive-external'),
      );
      expect(
        (await client.workspaces.getWorkspaceCatalog()).worktrees.map(
          (worktree) => worktree.id,
        ),
        isNot(contains(external.id)),
      );
    },
    tags: const <String>[
      'feature_scenario__worktree_lifecycle__archive_external__e2e',
    ],
  );
}

Future<(RealDaemonFixture, Directory)> _projectFixture(String id) async {
  final fixture = await RealDaemonFixture.start(id: id);
  final root = Directory('${fixture.home.path}/project')..createSync();
  final client = await fixture.connect(clientId: '$id-setup');
  try {
    await client.workspaces.registerWorkspace(
      workspaceId: id,
      checkoutId: '$id-main',
      rootPath: root.path,
      name: 'Project E2E',
    );
  } finally {
    await client.close();
  }
  return (fixture, root);
}

Future<(RealDaemonFixture, Directory, String)> _gitProjectFixture(
  String id,
) async {
  final fixture = await RealDaemonFixture.start(id: id);
  final root = Directory('${fixture.home.path}/git-project')..createSync();
  await _runGit(root.path, <String>['init', '-b', 'main']);
  await File('${root.path}/README.md').writeAsString('# fixture\n');
  await _runGit(root.path, <String>['add', 'README.md']);
  await _runGit(root.path, <String>[
    '-c',
    'user.name=Tinest E2E',
    '-c',
    'user.email=tinest-e2e@example.invalid',
    'commit',
    '-m',
    'Initial fixture',
  ]);
  final client = await fixture.connect(clientId: '$id-setup');
  try {
    await client.workspaces.registerWorkspace(
      workspaceId: id,
      checkoutId: '$id-main',
      rootPath: root.path,
      name: 'Git Project E2E',
    );
  } finally {
    await client.close();
  }
  return (fixture, root, id);
}

Future<void> _runGit(String path, List<String> arguments) async {
  final result = await Process.run('git', arguments, workingDirectory: path);
  if (result.exitCode != 0) {
    throw TestFailure('git ${arguments.join(' ')} failed: ${result.stderr}');
  }
}

Future<void> _pumpProjectSettings(
  WidgetTester tester,
  RealDaemonFixture fixture, {
  bool waitForEditor = true,
}) async {
  tester.binding.platformDispatcher.localeTestValue = const Locale('ko');
  addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
  await tester.binding.setSurfaceSize(const Size(1200, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(TinestApp(services: fixture.services));
  await tester.pumpAndSettle();
  await pumpUntil(tester, find.text('Project E2E'));
  await tapVisible(
    tester,
    find.byKey(const ValueKey<String>('workspace-settings-button')),
    'the workspace settings button',
  );
  await tester.pumpAndSettle();
  final projectsRow = find.byKey(
    const ValueKey<String>('settings-category-row-project'),
  );
  await pumpUntil(tester, projectsRow);
  await tester.tap(projectsRow);
  await tester.pumpAndSettle();
  if (waitForEditor) {
    await pumpUntil(tester, _textInput('Setup (worktree 생성 후)'));
  }
}

Finder _textInput(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is TRTextField && widget.label == label,
  ),
  matching: find.byType(EditableText),
);
