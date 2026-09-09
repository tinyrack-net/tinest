import 'dart:async';

import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/features/workspace/presentation/pages/project_settings_page.dart';
import 'package:app/src/features/workspace/presentation/widgets/worktree_hook_report.dart';
import 'package:app/src/shared/presentation/settings_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/fake_tinest_api.dart';
import '../../support/localization.dart';

void main() {
  final now = DateTime.utc(2026, 8, 3);
  WorkspaceDto workspace(String id, String name) => WorkspaceDto(
    id: id,
    name: name,
    rootPath: '/repos/$name',
    kind: WorkspaceKind.git,
    createdAt: now,
  );

  test('hook commands round-trip one command per non-blank line', () {
    expect(parseHookCommands(' npm ci \n\n  \nnpm run build\n'), <String>[
      'npm ci',
      'npm run build',
    ]);
    expect(parseHookCommands('   '), isEmpty);
    expect(
      formatHookCommands(const <String>['npm ci', 'npm run build']),
      'npm ci\nnpm run build',
    );
  });

  test('only a non-zero exit code is reported as a hook failure', () {
    expect(failedWorktreeHook(const <WorktreeHookRunDto>[]), isNull);
    expect(
      failedWorktreeHook(const <WorktreeHookRunDto>[
        WorktreeHookRunDto(
          phase: WorktreeHookPhase.setup,
          command: 'npm ci',
          exitCode: 0,
          stdout: '',
          stderr: '',
        ),
      ]),
      isNull,
    );
    expect(
      failedWorktreeHook(const <WorktreeHookRunDto>[
        WorktreeHookRunDto(
          phase: WorktreeHookPhase.setup,
          command: 'npm ci',
          exitCode: 0,
          stdout: '',
          stderr: '',
        ),
        WorktreeHookRunDto(
          phase: WorktreeHookPhase.setup,
          command: 'npm run build',
          exitCode: 2,
          stdout: '',
          stderr: 'boom',
        ),
      ])?.command,
      'npm run build',
    );
  });

  testWidgets(
    'project settings leaves the editor usable while host shell loads',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gate = Completer<void>();
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace('workspace', 'tinest')],
        terminalShellGate: gate.future,
      )..projectSettings['workspace'] = const ProjectSettingsDto();
      final router = await _pumpRoute(
        tester,
        api,
        const ProjectSettingsRoute(hostId: 'server').location,
        settle: false,
      );
      addTearDown(router.dispose);
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump();
      }

      expect(_textInput('Setup (worktree 생성 후)'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('settings-skeleton-overlay')),
        findsOneWidget,
      );
      expect(
        tester.widget<TRButton>(find.widgetWithText(TRButton, '저장')).onPressed,
        isNull,
      );

      gate.complete();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('host-shell-executable')),
        findsOneWidget,
      );
      expect(
        tester.widget<TRButton>(find.widgetWithText(TRButton, '저장')).onPressed,
        isNotNull,
      );
    },
    tags: const <String>[
      'feature_test__settings_async_loading__widget',
      'feature_test__terminal_settings__widget',
    ],
  );

  testWidgets(
    'project settings lists projects and saves worktree lifecycle hooks',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[
          workspace('design', 'design'),
          workspace('workspace', 'tinest'),
        ],
      )..projectSettings['tinest'] = const ProjectSettingsDto();
      final router = await _pumpRoute(
        tester,
        api,
        const ProjectSettingsRoute(hostId: 'server').location,
      );
      addTearDown(router.dispose);

      expect(find.byType(TRTreeNav<String>), findsOneWidget);

      // Select the product workspace explicitly: the new brand sorts after
      // `design`, unlike the previous product name.
      await tester.tap(find.text('tinest'));
      await tester.pumpAndSettle();

      expect(find.text('프로젝트'), findsWidgets);
      expect(find.text('design'), findsOneWidget);
      expect(_projectEditor, findsOneWidget);

      await tester.enterText(
        _textInput('Setup (worktree 생성 후)'),
        'npm ci\n\nnpm run build',
      );
      await tester.enterText(
        _textInput('Teardown (worktree 제거 전)'),
        'docker compose down',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('project-shell-executable')),
      );
      await tester.enterText(
        _keyedTextInput('project-shell-executable'),
        '/bin/zsh',
      );
      await tester.enterText(
        _keyedTextInput('project-shell-arguments'),
        '-l\n--no-rcs',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('host-shell-executable')),
      );
      await tester.enterText(
        _keyedTextInput('host-shell-executable'),
        '/bin/bash',
      );
      await tester.enterText(_keyedTextInput('host-shell-arguments'), '-l');
      await tester.ensureVisible(find.widgetWithText(TRButton, '저장'));
      await tester.tap(find.widgetWithText(TRButton, '저장'));
      await tester.pumpAndSettle();

      expect(
        api.projectSettings['workspace'],
        const ProjectSettingsDto(
          setup: <String>['npm ci', 'npm run build'],
          teardown: <String>['docker compose down'],
          shell: ShellSpecDto(
            executable: '/bin/zsh',
            arguments: <String>['-l', '--no-rcs'],
          ),
        ),
      );
      expect(
        api.terminalShell,
        const ShellSpecDto(executable: '/bin/bash', arguments: <String>['-l']),
      );

      await tester.enterText(_keyedTextInput('project-shell-executable'), '');
      await tester.enterText(_keyedTextInput('host-shell-executable'), '');
      await tester.ensureVisible(find.widgetWithText(TRButton, '저장'));
      await tester.tap(find.widgetWithText(TRButton, '저장'));
      await tester.pumpAndSettle();
      expect(api.projectSettings['workspace']?.shell, isNull);
      expect(api.terminalShell, isNull);
    },
    tags: const <String>[
      'feature_test__project_settings__widget',
      'feature_test__terminal_settings__widget',
    ],
  );

  testWidgets('project settings switches between projects', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api =
        FakeTinestApi(
            workspaces: <WorkspaceDto>[
              workspace('design', 'design'),
              workspace('workspace', 'tinest'),
            ],
          )
          ..projectSettings['design'] = const ProjectSettingsDto(
            setup: <String>['bundle install'],
          );
    final router = await _pumpRoute(
      tester,
      api,
      const ProjectSettingsRoute(hostId: 'server').location,
    );
    addTearDown(router.dispose);

    await tester.tap(find.text('tinest'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('design'));
    await tester.pumpAndSettle();

    expect(_projectEditor, findsOneWidget);
    expect(find.text('bundle install'), findsOneWidget);
  });

  testWidgets('project settings reports an empty catalog', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = await _pumpRoute(
      tester,
      FakeTinestApi(),
      const ProjectSettingsRoute(hostId: 'server').location,
    );
    addTearDown(router.dispose);

    expect(find.text('등록된 project가 없습니다.'), findsOneWidget);
    expect(find.byType(TRPaneHeader), findsOneWidget);
    expect(find.byType(SettingsEmptyState), findsWidgets);
  });

  testWidgets(
    'project settings exposes load errors until an explicit retry',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace('workspace', 'tinest')],
        projectSettingsError: Exception('invalid_project_settings'),
      );
      final router = await _pumpRoute(
        tester,
        api,
        const ProjectSettingsRoute(hostId: 'server').location,
      );
      addTearDown(router.dispose);

      expect(find.textContaining('invalid_project_settings'), findsOneWidget);
      expect(api.projectSettingsLoadCount, 1);

      api.projectSettingsError = null;
      await tester.tap(find.widgetWithText(TRButton, '다시 시도'));
      await tester.pumpAndSettle();

      expect(_textInput('Setup (worktree 생성 후)'), findsOneWidget);
      expect(api.projectSettingsLoadCount, 2);
    },
    tags: const <String>[
      'feature_test__project_settings__widget',
      'feature_test__settings_async_loading__widget',
    ],
  );

  testWidgets('mobile project settings navigates from list to editor', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = FakeTinestApi(
      workspaces: <WorkspaceDto>[workspace('workspace', 'tinest')],
    );
    final router = await _pumpRoute(
      tester,
      api,
      const ProjectSettingsRoute(hostId: 'server').location,
    );
    addTearDown(router.dispose);

    expect(_projectEditor, findsNothing);
    await tester.tap(find.text('tinest'));
    await tester.pumpAndSettle();
    expect(_projectEditor, findsOneWidget);

    expect(findAccessibleAction('Project 목록'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey<String>('settings-back-button')),
    );
    await tester.pumpAndSettle();
    expect(_projectEditor, findsNothing);
  });
}

/// Marks the project editor: the source path that used to stand for it moved
/// out of the pane header when destination headers dropped their second line.
final Finder _projectEditor = find.byKey(
  const ValueKey<String>('project-shell-executable'),
);

Finder _textInput(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is TRTextField && widget.label == label,
  ),
  matching: find.byType(EditableText),
);

Finder _keyedTextInput(String key) => find.descendant(
  of: find.byKey(ValueKey<String>(key)),
  matching: find.byType(EditableText),
);

Future<GoRouter> _pumpRoute(
  WidgetTester tester,
  FakeTinestApi api,
  String location, {
  bool settle = true,
}) async {
  final router = GoRouter(initialLocation: location, routes: $appRoutes);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appServicesProvider.overrideWithValue(fakeAppServices(api))],
      child: MaterialApp.router(
        theme: testLightTheme,
        darkTheme: testDarkTheme,
        locale: testLocale,
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        routerConfig: router,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return router;
}
