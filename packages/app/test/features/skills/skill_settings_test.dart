import 'dart:async';
import 'dart:ui' as ui;

import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/app/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/fake_tinest_api.dart';
import '../../support/localization.dart';

void main() {
  final now = DateTime.utc(2026, 8, 4);
  final workspace = WorkspaceDto(
    id: 'workspace',
    name: 'Tinest',
    rootPath: '/repos/tinest',
    kind: WorkspaceKind.git,
    createdAt: now,
  );
  final home = WorkspaceDto(
    id: 'home',
    name: 'Home',
    rootPath: '/home/user',
    kind: WorkspaceKind.home,
    createdAt: now,
  );
  const projectSkill = SkillSummaryDto(
    id: 'migrate',
    name: 'migrate',
    description: 'Runs the migration from the selected project.',
    isImplicit: false,
  );

  testWidgets(
    'global catalog exposes only title and full description in two panes',
    (tester) async {
      await _setViewport(tester, const Size(1200, 900));
      final api = FakeTinestApi(workspaces: <WorkspaceDto>[workspace]);
      final router = await _pumpSkills(tester, api);
      addTearDown(router.dispose);

      expect(find.text('전역 스킬 2개'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('skill-row-coding-conventions')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('skill-row-commit')),
        findsOneWidget,
      );
      final skillRowSemantics = tester.getSemantics(
        find.byKey(const ValueKey<String>('skill-row-commit')),
      );
      expect(skillRowSemantics.flagsCollection.isButton, isFalse);
      expect(skillRowSemantics.flagsCollection.isFocused, ui.Tristate.none);
      final skillRowSemanticsData = skillRowSemantics.getSemanticsData();
      expect(skillRowSemanticsData.hasAction(ui.SemanticsAction.tap), isFalse);
      expect(
        skillRowSemanticsData.hasAction(ui.SemanticsAction.focus),
        isFalse,
      );
      expect(find.text('Match the surrounding code.'), findsOneWidget);
      expect(find.text('Writes atomic commits.'), findsOneWidget);
      expect(find.byType(TRSwitch), findsNothing);
      expect(find.byType(TRTextField), findsNothing);
      expect(find.byType(TRTextarea), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('skill-add-button')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('skill-delete-button')),
        findsNothing,
      );
      expect(find.text('스킬 추가'), findsNothing);
      expect(find.text('스킬 삭제'), findsNothing);

      final layoutScope = tester.widget<TRAdaptiveLayoutScope>(
        find.byType(TRAdaptiveLayoutScope),
      );
      expect(layoutScope.widthClass, TRAdaptiveWidthClass.large);
      expect(
        find.byKey(const ValueKey<String>('settings-sidebar-surface')),
        findsOneWidget,
      );
      expect(api.skillListRequests, hasLength(1));
      expect(api.skillListRequests.single.view, SkillListView.global);
      expect(api.skillListRequests.single.workspaceId, isNull);
    },
    tags: const <String>['feature_test__skill_catalog__widget'],
  );

  testWidgets(
    'project scope shows only project skills and excludes home workspaces',
    (tester) async {
      await _setViewport(tester, const Size(1200, 900));
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[home, workspace],
        projectSkills: const <SkillSummaryDto>[projectSkill],
      );
      final router = await _pumpSkills(tester, api);
      addTearDown(router.dispose);

      await tester.tap(_scopeTrigger);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(MenuItemButton, 'Tinest'), findsOneWidget);
      expect(find.widgetWithText(MenuItemButton, 'Home'), findsNothing);
      expect(find.text('/repos/tinest'), findsOneWidget);
      await tester.tap(find.widgetWithText(MenuItemButton, 'Tinest'));
      await tester.pumpAndSettle();

      expect(find.text('프로젝트 스킬 1개'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('skill-row-migrate')),
        findsOneWidget,
      );
      expect(
        find.text('Runs the migration from the selected project.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('skill-row-commit')),
        findsNothing,
      );
      expect(api.skillListRequests.last.view, SkillListView.project);
      expect(api.skillListRequests.last.workspaceId, workspace.id);
    },
    tags: const <String>['feature_test__skill_catalog__widget'],
  );

  testWidgets('an invalid project route normalizes before listing skills', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1200, 900));
    final api = FakeTinestApi(workspaces: <WorkspaceDto>[workspace]);
    final router = await _pumpSkills(
      tester,
      api,
      workspaceId: 'removed-project',
    );
    addTearDown(router.dispose);

    expect(
      router.routeInformationProvider.value.uri.queryParameters['workspace-id'],
      isNull,
    );
    expect(api.skillListRequests, isNotEmpty);
    expect(
      api.skillListRequests,
      everyElement(
        isA<SkillListParamsDto>()
            .having((request) => request.view, 'view', SkillListView.global)
            .having((request) => request.workspaceId, 'workspaceId', isNull),
      ),
    );
  }, tags: const <String>['feature_test__skill_catalog__widget']);

  testWidgets(
    'initial catalog loading uses the shared form skeleton',
    (tester) async {
      await _setViewport(tester, const Size(1200, 900));
      final gate = Completer<void>();
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        skillListGate: gate.future,
      );
      final router = await _pumpSkills(tester, api, settle: false);
      addTearDown(router.dispose);
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('settings-skeleton-form')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('설정 불러오는 중'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('skill-scope-select')),
        findsNothing,
      );

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('전역 스킬 2개'), findsOneWidget);
    },
    tags: const <String>[
      'feature_test__skill_catalog__widget',
      'feature_test__settings_async_loading__widget',
    ],
  );

  testWidgets('global and project catalogs use distinct empty states', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1200, 900));
    final api = FakeTinestApi(
      workspaces: <WorkspaceDto>[workspace],
      skills: const <SkillSummaryDto>[],
      projectSkills: const <SkillSummaryDto>[],
    );
    final router = await _pumpSkills(tester, api);
    addTearDown(router.dispose);

    expect(find.text('사용 가능한 전역 스킬이 없습니다.'), findsOneWidget);
    await tester.tap(_scopeTrigger);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Tinest'));
    await tester.pumpAndSettle();
    expect(find.text('이 프로젝트에 사용 가능한 스킬이 없습니다.'), findsOneWidget);
  }, tags: const <String>['feature_test__skill_catalog__widget']);

  testWidgets(
    'a failed catalog load keeps the scope and offers retry',
    (tester) async {
      await _setViewport(tester, const Size(1200, 900));
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        skillListError: Exception('daemon offline'),
      );
      final router = await _pumpSkills(tester, api);
      addTearDown(router.dispose);

      expect(find.textContaining('daemon offline'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('skill-scope-select')),
        findsOneWidget,
      );
      api.skillListError = null;
      await tester.tap(find.widgetWithText(TRButton, '다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text('전역 스킬 2개'), findsOneWidget);
    },
    tags: const <String>[
      'feature_test__skill_catalog__widget',
      'feature_test__settings_async_loading__widget',
    ],
  );

  testWidgets(
    'a failed external refresh keeps the catalog and shows an alert',
    (tester) async {
      await _setViewport(tester, const Size(1200, 900));
      final api = FakeTinestApi(workspaces: <WorkspaceDto>[workspace]);
      final router = await _pumpSkills(tester, api);
      addTearDown(router.dispose);

      api
        ..skillListError = Exception('refresh failed')
        ..emit(const SkillsChangedClientEvent());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('skill-row-commit')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('settings-refresh-error')),
        findsOneWidget,
      );
      expect(find.textContaining('refresh failed'), findsOneWidget);
    },
    tags: const <String>[
      'feature_test__skill_catalog__widget',
      'feature_test__settings_async_loading__widget',
    ],
  );

  testWidgets('the controlled scope selector adapts to a mobile sheet', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 760));
    final api = FakeTinestApi(
      workspaces: _manyWorkspaces(now),
      projectSkills: const <SkillSummaryDto>[projectSkill],
    );
    final router = await _pumpSkills(tester, api);
    addTearDown(router.dispose);

    final layoutScope = tester.widget<TRAdaptiveLayoutScope>(
      find.byType(TRAdaptiveLayoutScope),
    );
    expect(layoutScope.widthClass, TRAdaptiveWidthClass.compact);
    expect(
      find.byKey(const ValueKey<String>('settings-sidebar-surface')),
      findsNothing,
    );

    await tester.tap(_scopeTrigger);
    await tester.pumpAndSettle();
    expect(find.byType(TRDrawer), findsOneWidget);
    await tester.enterText(_searchInput('프로젝트 검색'), 'drop');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Dropwell'));
    await tester.pumpAndSettle();

    expect(find.byType(TRDrawer), findsNothing);
    expect(api.skillListRequests.last.view, SkillListView.project);
    expect(api.skillListRequests.last.workspaceId, 'dropwell');
  }, tags: const <String>['feature_test__skill_catalog__widget']);

  testWidgets('English and Japanese catalog copy is available', (tester) async {
    await _setViewport(tester, const Size(1200, 900));
    final api = FakeTinestApi(
      workspaces: <WorkspaceDto>[workspace],
      skills: const <SkillSummaryDto>[],
    );
    var router = await _pumpSkills(tester, api, locale: const Locale('en'));
    expect(find.text('Skill scope'), findsOneWidget);
    expect(find.text('No global skills are available.'), findsOneWidget);
    router.dispose();

    router = await _pumpSkills(tester, api, locale: const Locale('ja'));
    addTearDown(router.dispose);
    expect(find.text('スキルの範囲'), findsOneWidget);
    expect(find.text('利用可能なグローバルスキルはありません。'), findsOneWidget);
  }, tags: const <String>['feature_test__skill_catalog__widget']);
}

Finder get _scopeTrigger => find.descendant(
  of: find.byKey(const ValueKey<String>('skill-scope-select')),
  matching: find.byType(TextButton),
);

Finder _searchInput(String placeholder) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is TRTextField && widget.placeholder == placeholder,
  ),
  matching: find.byType(EditableText),
);

Future<void> _setViewport(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
    tester.view.reset();
  });
}

List<WorkspaceDto> _manyWorkspaces(DateTime now) => <WorkspaceDto>[
  for (final name in const <String>[
    'Tinest',
    'Dropwell',
    'Termworld',
    'Shipworld',
    'Dartage',
  ])
    WorkspaceDto(
      id: name.toLowerCase(),
      name: name,
      rootPath: '/repos/${name.toLowerCase()}',
      kind: WorkspaceKind.git,
      createdAt: now,
    ),
];

Future<GoRouter> _pumpSkills(
  WidgetTester tester,
  FakeTinestApi api, {
  String? workspaceId,
  Locale locale = testLocale,
  bool settle = true,
}) async {
  final router = GoRouter(
    initialLocation: SkillSettingsRoute(
      hostId: 'server',
      workspaceId: workspaceId,
    ).location,
    routes: $appRoutes,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appServicesProvider.overrideWithValue(fakeAppServices(api))],
      child: MaterialApp.router(
        theme: testLightTheme,
        darkTheme: testDarkTheme,
        locale: locale,
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        routerConfig: router,
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return router;
}
