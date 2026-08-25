part of '../../app/app_flows_test.dart';

void _registerWorkspaceAppFlows() {
  final now = DateTime.utc(2026, 8, 3);
  final workspace = WorkspaceDto(
    id: 'workspace',
    name: 'Tinest',
    rootPath: '/repos/tinest',
    kind: WorkspaceKind.git,
    createdAt: now,
  );
  final checkout = WorktreeDto(
    id: 'checkout',
    workspaceId: workspace.id,
    name: 'main',
    path: workspace.rootPath,
    branch: 'main',
    head: 'abc',
    kind: WorktreeKind.checkout,
    isTinestOwned: false,
    createdAt: now,
  );
  SessionDto session(String id) => SessionDto(
    id: id,
    worktreeId: checkout.id,
    title: 'Session $id',
    agentDefinitionId: 'tinest',
    origin: SessionOrigin.manual,
    status: SessionStatus.idle,
    model: const ModelSelectionDto(modelId: 'openai/gpt-5.6-sol'),
    createdAt: now,
    updatedAt: now,
  );
  for (final testCase in <({String name, Size size})>[
    (name: 'desktop', size: const Size(1400, 760)),
    (name: 'mobile', size: const Size(390, 780)),
  ]) {
    testWidgets(
      '${testCase.name} replaces a route whose worktree left the catalog',
      (tester) async {
        await _setTestViewport(tester, testCase.size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final api = FakeTinestApi(
          workspaces: <WorkspaceDto>[workspace],
          worktrees: const <WorktreeDto>[],
        );
        final router = await _pumpRoute(
          tester,
          api,
          WorktreeRoute(
            hostId: 'server',
            workspaceId: workspace.id,
            worktreeId: checkout.id,
          ).location,
        );
        addTearDown(router.dispose);

        await tester.pumpAndSettle();

        expect(router.routeInformationProvider.value.uri.path, '/');
        expect(tester.takeException(), isNull);
      },
      tags: const <String>['feature_test__workspace_catalog__widget'],
    );
  }
  testWidgets(
    'a transient stale catalog does not eject a newly created worktree route',
    (tester) async {
      await _setTestViewport(tester, const Size(1400, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        workspaceCatalogResponses: <WorkspaceCatalogDto>[
          WorkspaceCatalogDto(
            workspaces: <WorkspaceDto>[workspace],
            worktrees: const <WorktreeDto>[],
          ),
          WorkspaceCatalogDto(
            workspaces: <WorkspaceDto>[workspace],
            worktrees: <WorktreeDto>[checkout],
          ),
        ],
      );
      final route = WorktreeRoute(
        hostId: 'server',
        workspaceId: workspace.id,
        worktreeId: checkout.id,
      );
      final router = await _pumpRoute(tester, api, route.location);
      addTearDown(router.dispose);

      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, route.location);
      expect(find.text('main'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    tags: const <String>['feature_test__workspace_catalog__widget'],
  );
  testWidgets(
    'desktop workspace uses a flat workspace tree and session tabs',
    (tester) async {
      await _setTestViewport(tester, const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final first = session('one');
      final second = session('two');
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        agents: <SessionDto>[first, second],
      );
      final router = await _pumpRoute(
        tester,
        api,
        SessionRoute(
          hostId: 'server',
          workspaceId: workspace.id,
          worktreeId: checkout.id,
          sessionId: first.id,
        ).location,
      );
      addTearDown(router.dispose);

      expect(find.text('Workspaces'), findsOneWidget);
      expect(find.byKey(const ValueKey('workspace-new-button')), findsOne);
      expect(
        find.byKey(const ValueKey<String>('workspace-sidebar-surface')),
        findsOneWidget,
      );
      // The daemon has no tree level of its own; it names the workspace row.
      expect(
        find.text('Test daemon · ${workspace.rootPath}'),
        findsOneWidget,
      );
      expect(find.text('main'), findsOneWidget);
      expect(find.text('Agents'), findsNothing);
      expect(find.text('Session one'), findsWidgets);

      await tester.tap(
        find.byKey(const ValueKey('workspace-all-sessions-menu')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Session two'), findsOneWidget);
      await tester.tap(find.text('Session two'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, contains('two'));
    },
    tags: const <String>['feature_test__workspace_catalog__widget'],
  );

  testWidgets(
    'archives a managed worktree from the sidebar',
    (
      tester,
    ) async {
      await _setTestViewport(tester, const Size(1400, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final managed = WorktreeDto(
        id: 'external',
        workspaceId: workspace.id,
        name: 'feature/settings',
        path: '/worktrees/feature-settings',
        branch: 'feature/settings',
        kind: WorktreeKind.linked,
        isTinestOwned: false,
        createdAt: now,
      );
      final api =
          FakeTinestApi(
              workspaces: <WorkspaceDto>[workspace],
              worktrees: <WorktreeDto>[checkout, managed],
            )
            ..archiveWorktreeHookRuns = const <WorktreeHookRunDto>[
              WorktreeHookRunDto(
                phase: WorktreeHookPhase.teardown,
                command: 'docker compose down',
                exitCode: 1,
                stdout: '',
                stderr: 'no such service',
              ),
            ];
      final router = await _pumpRoute(
        tester,
        api,
        WorktreeRoute(
          hostId: 'server',
          workspaceId: workspace.id,
          worktreeId: managed.id,
        ).location,
      );
      addTearDown(router.dispose);
      await tester.pumpAndSettle();

      expect(findAccessibleAction('새 worktree'), findsNothing);
      expect(find.text('feature/settings'), findsWidgets);

      final menus = findAccessibleAction('Worktree 메뉴');
      await tester.tap(menus.last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Archive할까요?'), findsOneWidget);
      expect(
        find.text('checkout 디렉터리가 제거됩니다.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TRButton, 'Archive'));
      await tester.pumpAndSettle();
      expect(find.text('feature/settings'), findsNothing);
      expect(router.routeInformationProvider.value.uri.path, '/');
      // Teardown never blocks the archive, so the failure is only reported.
      expect(
        find.text('Teardown 실패 (exit 1): docker compose down'),
        findsOneWidget,
      );
      expect(find.textContaining('no such service'), findsOneWidget);
    },
    tags: const <String>['feature_test__worktree_lifecycle__widget'],
  );

  testWidgets(
    'an archive that outlives its sidebar finishes without throwing',
    (tester) async {
      await _setTestViewport(tester, const Size(1400, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final managed = WorktreeDto(
        id: 'managed',
        workspaceId: workspace.id,
        name: 'feature/settings',
        path: '/worktrees/feature-settings',
        branch: 'feature/settings',
        kind: WorktreeKind.linked,
        isTinestOwned: true,
        createdAt: now,
      );
      final gate = Completer<void>();
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout, managed],
      )..archiveWorktreeGate = gate;
      final router = await _pumpRoute(
        tester,
        api,
        WorktreeRoute(
          hostId: 'server',
          workspaceId: workspace.id,
          worktreeId: managed.id,
        ).location,
      );
      addTearDown(router.dispose);
      await tester.pumpAndSettle();

      await tester.tap(findAccessibleAction('Worktree 메뉴').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TRButton, 'Archive'));
      await tester.pump();

      final confirm = find.byKey(
        const ValueKey<String>('worktree-archive-confirm'),
      );
      expect(tester.widget<TRButton>(confirm).loading, isTrue);
      expect(
        find.descendant(of: confirm, matching: find.byType(TRSpinner)),
        findsOneWidget,
      );

      // A route change removes the sidebar while the daemon operation is still
      // running, but the keep-alive catalog controller must finish its refresh.
      router.go(const SettingsHomeRoute().location);
      await tester.pumpAndSettle();
      gate.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      router.go(const WorkspaceHomeRoute().location);
      await tester.pumpAndSettle();
      expect(find.text('feature/settings'), findsNothing);
    },
    tags: const <String>['feature_test__worktree_lifecycle__widget'],
  );

  testWidgets(
    'the project select registers a project through the daemon browser',
    (tester) async {
      await _setTestViewport(tester, const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi(
        directories: const <String, List<String>>{
          '/': <String>['/srv'],
          '/srv': <String>['/srv/repositories'],
          '/srv/repositories': <String>['/srv/repositories/project'],
        },
      );
      final router = await _pumpRoute(
        tester,
        api,
        const WorkspaceHomeRoute().location,
      );
      addTearDown(router.dispose);
      await tester.pumpAndSettle();

      expect(find.text('폴더 추가'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('new-workspace-project')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('new-workspace-project-add')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Daemon의 폴더 선택'), findsOneWidget);
      await tester.tap(find.text('srv'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('repositories'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('project'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TRButton, '이 폴더 선택'));
      await tester.pumpAndSettle();

      expect(api.registeredPaths, <String>['/srv/repositories/project']);
      expect(find.text('project'), findsWidgets);
    },
    tags: const <String>['feature_test__workspace_registration__widget'],
  );

  testWidgets(
    'the sidebar collapses and restores from persisted settings',
    (tester) async {
      await _setTestViewport(tester, const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
      );
      final store = MemoryAppStore();
      final router = await _pumpRoute(
        tester,
        api,
        const WorkspaceHomeRoute().location,
        store: store,
      );
      addTearDown(router.dispose);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('workspace-new-button')), findsOne);
      await tester.tap(find.byKey(const ValueKey('workspace-sidebar-toggle')));
      // Toggling refreshes the host registry; the composer must keep its
      // loaded state instead of flashing an empty-state error.
      await tester.pump();
      expect(find.text('먼저 프로젝트를 추가하세요.'), findsNothing);
      expect(
        find.byKey(const ValueKey('session-composer-settings')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('session-composer-agent')), findsOne);
      expect(find.text('사용 가능한 primary Agent가 없습니다.'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('workspace-new-button')), findsNothing);
      expect(store.settings.sidebarCollapsed, isTrue);

      await tester.tap(find.byKey(const ValueKey('workspace-sidebar-toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('workspace-new-button')), findsOne);
      expect(store.settings.sidebarCollapsed, isFalse);
    },
    tags: const <String>['feature_test__workspace_catalog__widget'],
  );

  testWidgets(
    'the desktop sidebar collapses and restores without reserving a pane',
    (tester) async {
      await _setTestViewport(tester, const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
      );
      final router = await _pumpRoute(
        tester,
        api,
        const WorkspaceHomeRoute().location,
        store: MemoryAppStore(),
      );
      addTearDown(router.dispose);
      await tester.pumpAndSettle();

      final surface = find.byKey(const ValueKey('workspace-sidebar-surface'));
      expect(tester.getSize(surface).width, greaterThan(0));

      await tester.tap(find.byKey(const ValueKey('workspace-sidebar-toggle')));
      await tester.pumpAndSettle();
      expect(surface, findsNothing);

      await tester.tap(find.byKey(const ValueKey('workspace-sidebar-toggle')));
      await tester.pumpAndSettle();
      expect(tester.getSize(surface).width, greaterThan(0));
    },
    tags: const <String>['feature_test__workspace_catalog__widget'],
  );

  testWidgets(
    'reduced motion collapses the sidebar without animating',
    (tester) async {
      await _setTestViewport(tester, const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
      );
      final router = await _pumpRoute(
        tester,
        api,
        const WorkspaceHomeRoute().location,
        store: MemoryAppStore(),
        disableAnimations: true,
      );
      addTearDown(router.dispose);
      await tester.pumpAndSettle();

      final surface = find.byKey(const ValueKey('workspace-sidebar-surface'));
      expect(tester.getSize(surface).width, greaterThan(0));

      await tester.tap(find.byKey(const ValueKey('workspace-sidebar-toggle')));
      // One frame settles the persisted flag and the collapse together.
      await tester.pump();
      expect(surface, findsNothing);
    },
    tags: const <String>['feature_test__workspace_catalog__widget'],
  );

  testWidgets(
    'a collapsed sidebar is unreachable by pointer, semantics, and keyboard',
    (tester) async {
      await _setTestViewport(tester, const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final semantics = tester.ensureSemantics();
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
      );
      final router = await _pumpRoute(
        tester,
        api,
        const WorkspaceHomeRoute().location,
        store: MemoryAppStore(),
      );
      addTearDown(router.dispose);
      await tester.pumpAndSettle();

      final newWorkspace = find.byKey(const ValueKey('workspace-new-button'));
      expect(newWorkspace.hitTestable(), findsOne);

      await tester.tap(find.byKey(const ValueKey('workspace-sidebar-toggle')));
      await tester.pump();
      expect(newWorkspace.hitTestable(), findsNothing);

      await tester.pumpAndSettle();
      expect(newWorkspace, findsNothing);
      final surface = find.byKey(const ValueKey('workspace-sidebar-surface'));
      // The detail pane keeps its own "New workspace" heading, so scope the
      // semantics check to the sidebar the toggle collapsed.
      expect(
        find.descendant(
          of: surface,
          matching: find.bySemanticsLabel('New workspace'),
        ),
        findsNothing,
      );
      for (var press = 0; press < 6; press++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focused = FocusManager.instance.primaryFocus?.context;
        if (focused == null) continue;
        expect(
          find
              .ancestor(of: find.byWidget(focused.widget), matching: surface)
              .evaluate(),
          isEmpty,
        );
      }
      semantics.dispose();
    },
    tags: const <String>['feature_test__workspace_catalog__widget'],
  );

  testWidgets('mobile opens selected worktree as a session-only detail', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = FakeTinestApi(
      workspaces: <WorkspaceDto>[workspace],
      worktrees: <WorktreeDto>[checkout],
    );
    final router = await _pumpRoute(
      tester,
      api,
      WorktreeRoute(
        hostId: 'server',
        workspaceId: workspace.id,
        worktreeId: checkout.id,
      ).location,
    );
    addTearDown(router.dispose);

    expect(find.byKey(const ValueKey('workspace-new-button')), findsNothing);
    expect(find.text('코딩 요청으로 새 session을 시작하세요.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('session-tab-strip')),
        matching: find.byIcon(TinestIcons.back),
      ),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('workspace-back-button')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('workspace-new-button')), findsOne);
  });

  testWidgets('mobile new-workspace composer backs from the page header', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = await _pumpRoute(
      tester,
      FakeTinestApi(),
      const WorkspaceHomeRoute(compose: true).location,
    );
    addTearDown(router.dispose);

    expect(find.text('New workspace'), findsOneWidget);
    final back = find.byKey(
      const ValueKey<String>('workspace-back-button'),
    );
    expect(back, findsOneWidget);
    await tester.tap(back);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('workspace-new-button')), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/');
  });

  testWidgets('workspace shell is visible before any daemon exists', (
    tester,
  ) async {
    final api = FakeTinestApi();
    final router = GoRouter(
      initialLocation: const WorkspaceHomeRoute().location,
      routes: $appRoutes,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appServicesProvider.overrideWithValue(
            fakeAppServices(api, connected: false),
          ),
        ],
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
    await tester.pump();
    expect(find.text('Workspaces'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workspace-settings-button')),
      findsOneWidget,
    );
  });
}
