part of '../../app/app_flows_test.dart';

void _registerSessionsAppFlows() {
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
  testWidgets(
    'the draft composer stays quiet while agent discovery is still loading',
    (tester) async {
      await _setTestViewport(tester, const Size(1400, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gate = Completer<void>();
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        agentDefinitions: const <AgentDefinitionDto>[],
        agentDefinitionsGate: gate.future,
      );
      final router = await _pumpRoute(
        tester,
        api,
        WorktreeRoute(
          hostId: 'server',
          workspaceId: workspace.id,
          worktreeId: checkout.id,
        ).location,
        settle: false,
      );
      addTearDown(router.dispose);
      await tester.pump();
      await tester.pump();

      expect(find.text('사용 가능한 primary Agent가 없습니다.'), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.text('사용 가능한 primary Agent가 없습니다.'), findsOneWidget);
    },
    tags: const <String>['feature_test__workspace_catalog__widget'],
  );

  testWidgets(
    'the first turn and assistant response preserve the chat surface',
    (tester) async {
      Future<void> verifyAt(Size size) async {
        await _setTestViewport(tester, size);
        final startGate = Completer<void>();
        final api =
            FakeTinestApi(
                workspaces: <WorkspaceDto>[workspace],
                worktrees: <WorktreeDto>[checkout],
              )
              ..startTurnGate = startGate
              ..emitTurnStartEvents = true;
        final router = await _pumpRoute(
          tester,
          api,
          WorktreeRoute(
            hostId: 'server',
            workspaceId: workspace.id,
            worktreeId: checkout.id,
          ).location,
          disableAnimations: true,
        );

        const prompt = 'Keep this request visible';
        await tester.enterText(
          find.byKey(const ValueKey('session-composer-input')),
          prompt,
        );
        await tester.tap(find.byKey(const ValueKey('session-composer-send')));
        for (var frame = 0; frame < 4; frame += 1) {
          await tester.pump();
        }

        // The chat room opens on the create round trip alone: the prompt is
        // already visible as an optimistic bubble while the daemon is still
        // accepting the first turn.
        expect(find.text('코딩 요청으로 새 session을 시작하세요.'), findsNothing);
        final timeline = find.byType(ChatTimelineView).hitTestable();
        expect(timeline, findsOneWidget);
        expect(
          find.descendant(
            of: timeline,
            matching: find.text(prompt, findRichText: true),
          ),
          findsOneWidget,
        );

        startGate.complete();
        for (var frame = 0; frame < 8; frame += 1) {
          await tester.pump();
        }
        // The daemon's echo replaces the optimistic bubble without ever
        // rendering the prompt twice.
        expect(
          find.descendant(
            of: timeline,
            matching: find.text(prompt, findRichText: true),
          ),
          findsOneWidget,
        );
        final timelineState = tester.state<State<StatefulWidget>>(timeline);

        final created = api.createdSessions.single;
        api.emitTimeline(created.id, 'assistant.delta', <String, dynamic>{
          'text': 'First response',
        });
        await tester.pump();

        expect(
          tester.state<State<StatefulWidget>>(timeline),
          same(timelineState),
        );
        expect(
          find.descendant(
            of: timeline,
            matching: find.text(prompt, findRichText: true),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: timeline,
            matching: find.text('First response', findRichText: true),
          ),
          findsOneWidget,
        );
        expect(
          api.createdSessions.where((item) => item.id == created.id),
          hasLength(1),
        );

        router.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      }

      addTearDown(() => tester.binding.setSurfaceSize(null));
      await verifyAt(const Size(1400, 760));
      await verifyAt(const Size(390, 760));
    },
    tags: const <String>[
      'feature_test__session_lifecycle__widget',
      'feature_test__session_tabs__widget',
      'feature_test__turn_execution__widget',
    ],
  );

  testWidgets(
    'session tab strip uses fixed-width tabs and covers the hover seam',
    (tester) async {
      await _setTestViewport(tester, const Size(1400, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final first = session('one');
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        agents: <SessionDto>[first],
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

      // The design system owns the fixed-width strip geometry and selection
      // indicator. Tinest only supplies the selected, closable session tab.
      final strip = find.byKey(const ValueKey('session-tab-strip'));
      expect(strip, findsOneWidget);
      final tabs = tester.widget<TRTabs>(strip);
      expect(tabs.value, first.id);
      expect(tabs.tabWidth, TRTabsWidth.fixed);
      expect(
        find.descendant(
          of: strip,
          matching: find.byKey(const ValueKey<String>('tr-tabs-indicator-one')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: strip,
          matching: find.byKey(const ValueKey<String>('tr-tabs-close-one')),
        ),
        findsOneWidget,
      );

      final tab = find.byKey(const ValueKey<String>('tr-tabs-tab-one'));
      expect(tester.getSize(tab).width, TRMeasurements.measureSm);
      final hoverSurface = find.descendant(
        of: tab,
        matching: find.byWidgetPredicate((widget) {
          if (widget is! AnimatedContainer) return false;
          final decoration = widget.decoration;
          return decoration is BoxDecoration && decoration.border != null;
        }),
      );
      expect(hoverSurface, findsOneWidget);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(tab));
      await tester.pump();
      final colors = tester.element(tab).tinyrackTheme;
      expect(
        tester.widget<AnimatedContainer>(hoverSurface).decoration,
        isA<BoxDecoration>().having(
          (decoration) => decoration.color,
          'color',
          colors.surfaceHover,
        ),
      );
      expect(
        tester.getSize(hoverSurface).height,
        TRControlMetrics.heightOf(TRUiSize.md) + TRControlMetrics.borderWidth,
      );

      // The two menu commands sit beside the square close buttons on each tab,
      // so a wide trigger would read as a stray pill in that row.
      final square = Size.square(TRControlMetrics.heightOf(TRUiSize.md));
      for (final key in const <String>[
        'workspace-new-tab-menu',
        'workspace-all-sessions-menu',
      ]) {
        expect(
          tester.getSize(find.byKey(ValueKey<String>(key))),
          square,
          reason: key,
        );
      }
    },
    tags: const <String>['feature_test__session_tabs__widget'],
  );

  testWidgets(
    'one mouse click switches tabs despite pointer drift and tab padding',
    (tester) async {
      await _setTestViewport(tester, const Size(1400, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final first = session('one');
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        agents: <SessionDto>[first],
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

      final strip = find.byKey(const ValueKey('session-tab-strip'));
      String activeTab() => tester.widget<TRTabs>(strip).value!;
      expect(activeTab(), first.id);

      // A pane strip is always draggable, so the drag recognizer and the tap
      // compete for every click. A mouse rarely holds still between press and
      // release, and the drag used to win a pixel of drift outright.
      final draftTab = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'tr-tabs-tab-draft:',
            ),
      );
      expect(draftTab, findsOneWidget);
      final drifting = await tester.startGesture(
        tester.getCenter(draftTab),
        kind: PointerDeviceKind.mouse,
      );
      await drifting.moveBy(
        const Offset(TRMeasurements.dragStartDistance / 2, 0),
      );
      await drifting.up();
      await tester.pumpAndSettle();

      expect(activeTab(), isNot(first.id));

      // The hover surface covers the whole tab, so every part of it selects.
      final sessionTab = find.byKey(const ValueKey<String>('tr-tabs-tab-one'));
      final bounds = tester.getRect(sessionTab);
      await tester.tapAt(Offset(bounds.left + 1, bounds.center.dy));
      await tester.pumpAndSettle();

      expect(activeTab(), first.id);
    },
    tags: const <String>['feature_test__session_tabs__widget'],
  );

  testWidgets(
    'workspace caps desktop splits and stacks the focused pane when narrow',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(1400, 760);
      addTearDown(tester.view.reset);
      final first = session('one');
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        agents: <SessionDto>[first],
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

      final draftClose = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'tr-tabs-close-draft:',
            ),
      );
      expect(draftClose, findsOneWidget);
      await tester.tap(draftClose);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('workspace-mobile-tab-strip')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('workspace-split-right')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('workspace-split-right')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('workspace-pane')), findsNWidgets(2));
      expect(find.byType(TRSplitView), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey<String>('tr-split-view-separator')),
        const Offset(TRSpacing.threeExtraLarge, 0),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TRSplitView>(find.byType(TRSplitView)).ratio,
        greaterThan(0.5),
      );

      final sourceTab = find.byKey(const ValueKey<String>('tr-tabs-tab-one'));
      final targetStrip = find.byType(TRTabs).last;
      await tester.dragFrom(
        tester.getCenter(sourceTab),
        tester.getCenter(targetStrip) - tester.getCenter(sourceTab),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TRSplitView), findsNothing);

      await tester.tap(find.byKey(const ValueKey('workspace-split-right')));
      await tester.pumpAndSettle();
      expect(find.byType(TRSplitView), findsOneWidget);
      expect(find.byKey(const ValueKey('workspace-pane')), findsNWidgets(2));
      expect(find.byKey(const ValueKey('workspace-split-down')), findsNothing);

      tester.view.physicalSize = const Size(1199, 760);
      await tester.pumpAndSettle();
      expect(find.byType(TRSplitView), findsNothing);
      expect(
        find.byKey(const ValueKey('workspace-mobile-tab-strip')),
        findsOneWidget,
      );

      tester.view.physicalSize = const Size(390, 760);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('workspace-split-right')), findsNothing);
      final mobileStrip = find.byKey(
        const ValueKey('workspace-mobile-tab-strip'),
      );
      expect(mobileStrip, findsOneWidget);
      final tabs = tester.widget<TRTabs>(mobileStrip);
      expect(tabs.tabWidth, TRTabsWidth.fixed);
      expect(tabs.tabs, hasLength(3));
      expect(tabs.tabs.map((tab) => tab.value), contains('one'));
      expect(tabs.tabs.where((tab) => tab.onClose != null), hasLength(3));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('workspace-tab-sheet')), findsNothing);

      final viewport = find.descendant(
        of: mobileStrip,
        matching: find.byType(Scrollable),
      );
      expect(viewport, findsOneWidget);
      expect(
        tester.state<ScrollableState>(viewport).position.maxScrollExtent,
        greaterThan(0),
      );
      final newTabMenu = find.byKey(const ValueKey('workspace-new-tab-menu'));
      expect(newTabMenu, findsOneWidget);
      expect(
        tester.getTopRight(newTabMenu).dx,
        tester.getTopRight(mobileStrip).dx,
      );

      final sessionTab = find.descendant(
        of: mobileStrip,
        matching: find.byKey(const ValueKey('tr-tabs-tab-one')),
      );
      await tester.ensureVisible(sessionTab);
      await tester.tap(sessionTab);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('conversation-pane-session:one')),
        findsOneWidget,
      );

      final closeSession = find.descendant(
        of: mobileStrip,
        matching: find.byKey(const ValueKey('tr-tabs-close-one')),
      );
      await tester.ensureVisible(closeSession);
      await tester.tap(closeSession);
      await tester.pumpAndSettle();
      expect(sessionTab, findsNothing);
      expect(find.byKey(const ValueKey('workspace-tab-sheet')), findsNothing);
    },
    tags: const <String>['feature_test__session_tabs__widget'],
  );

  testWidgets('session tabs close locally and reopen from the picker', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(1400, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final first = session('one');
    final api = FakeTinestApi(
      workspaces: <WorkspaceDto>[workspace],
      worktrees: <WorktreeDto>[checkout],
      agents: <SessionDto>[first],
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

    await tester.tap(find.byKey(const ValueKey('tr-tabs-close-one')));
    await tester.pumpAndSettle();
    expect(find.text('코딩 요청으로 새 session을 시작하세요.'), findsOneWidget);
    expect(
      await api.sessions.listSessions(worktreeId: checkout.id),
      <SessionDto>[first],
    );

    await tester.tap(find.byKey(const ValueKey('workspace-all-sessions-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Session one'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tr-tabs-close-one')), findsOneWidget);
  }, tags: const <String>['feature_test__session_tabs__widget']);

  testWidgets(
    'switching between tab kinds leaves the sidebar exactly as it was',
    (tester) async {
      await _setTestViewport(tester, const Size(1400, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final docs = WorkspaceDto(
        id: 'docs',
        name: 'Docs',
        rootPath: '/repos/docs',
        kind: WorkspaceKind.directory,
        createdAt: now,
      );
      final docsCheckout = WorktreeDto(
        id: 'docs-checkout',
        workspaceId: docs.id,
        name: 'main',
        path: docs.rootPath,
        kind: WorktreeKind.directory,
        isTinestOwned: false,
        createdAt: now,
      );
      final first = session('one');
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace, docs],
        worktrees: <WorktreeDto>[checkout, docsCheckout],
        agents: <SessionDto>[first],
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

      // Expanding the project the user is not in is the state most obviously
      // lost today: only the selected project is re-expanded after a rebuild.
      await tester.tap(find.text(docs.name));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<WorkspaceSidebar>(find.byType(WorkspaceSidebar))
          .treeController;
      expect(
        controller.expanded.map((group) => group.workspaceId),
        containsAll(<String>[workspace.id, docs.id]),
      );
      final page = tester.state(find.byType(WorkspacePage));
      final catalogLoads = api.workspaceCatalogCount;

      // A session tab and a draft tab route through different path patterns,
      // which is the switch that used to rebuild the page under the sidebar.
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'tr-tabs-tab-draft:',
              ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.state(find.byType(WorkspacePage)), same(page));
      expect(
        tester
            .widget<WorkspaceSidebar>(find.byType(WorkspaceSidebar))
            .treeController,
        same(controller),
      );
      expect(
        controller.expanded.map((group) => group.workspaceId),
        containsAll(<String>[workspace.id, docs.id]),
      );
      expect(api.workspaceCatalogCount, catalogLoads);
    },
    tags: const <String>[
      'feature_test__session_tabs__widget',
      'feature_test__workspace_catalog__widget',
    ],
  );

  testWidgets(
    'new-tab popup rows follow the narrow and wide workspace density',
    (tester) async {
      Future<void> verifyAt(Size viewport, TRUiSize expectedRowSize) async {
        await _setTestViewport(tester, viewport);
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

        await tester.tap(find.byKey(const ValueKey('workspace-new-tab-menu')));
        await tester.pumpAndSettle();

        for (final label in const <String>['새 session', '새 터미널']) {
          final row = find.widgetWithText(MenuItemButton, label);
          expect(row, findsOneWidget, reason: '$viewport: $label');
          expect(
            tester.getSize(row).height,
            TRControlMetrics.heightOf(expectedRowSize),
            reason: '$viewport: $label row height',
          );
          expect(
            tester
                .widget<MenuItemButton>(row)
                .style
                ?.textStyle
                ?.resolve({})
                ?.fontSize,
            TRControlMetrics.fontSizeOf(expectedRowSize),
            reason: '$viewport: $label font size',
          );
        }
      }

      await verifyAt(const Size(390, 760), TRUiSize.lg);
      await verifyAt(const Size(1400, 760), TRUiSize.sm);
    },
    tags: const <String>['feature_test__session_tabs__widget'],
  );

  testWidgets(
    'new-tab menu creates a terminal and confirms termination on close',
    (tester) async {
      await _setTestViewport(tester, const Size(1400, 760));
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

      await tester.tap(find.byKey(const ValueKey('workspace-new-tab-menu')));
      await tester.pumpAndSettle();
      expect(find.text('새 session'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('workspace-new-terminal')));
      await tester.pumpAndSettle();

      expect(find.byType(TerminalView), findsOneWidget);
      expect(find.text('터미널 1'), findsOneWidget);
      final terminal = (await api.terminals.listTerminals(checkout.id)).single;
      await tester.tap(
        find.byKey(ValueKey<String>('tr-tabs-close-${terminal.id}')),
      );
      await tester.pumpAndSettle();
      expect(find.text('터미널을 종료할까요?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TRButton, '취소'));
      await tester.pumpAndSettle();
      expect(find.byType(TerminalView), findsOneWidget);
      await tester.tap(
        find.byKey(ValueKey<String>('tr-tabs-close-${terminal.id}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('terminal-close-confirm')));
      await tester.pumpAndSettle();
      expect(
        (await api.terminals.listTerminals(checkout.id)).single.status,
        TerminalStatus.exited,
      );
      expect(find.byType(TerminalView), findsNothing);
    },
    tags: const <String>['feature_test__terminal_lifecycle__widget'],
  );

  testWidgets(
    'new-tab menu reports terminal creation failures without an exception',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _setTestViewport(tester, const Size(1400, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        terminalCreateError: const TinestClientException(
          'The worktree directory is no longer available.',
          code: 'worktree_unavailable',
        ),
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

      await tester.tap(find.byKey(const ValueKey('workspace-new-tab-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('workspace-new-terminal')));
      await tester.pumpAndSettle();

      expect(find.byType(TRAlert), findsOneWidget);
      expect(find.text('터미널을 만들 수 없어요'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(TRAlert)).flagsCollection.isLiveRegion,
        isTrue,
      );
      expect(find.byType(TerminalView), findsNothing);
      expect(await api.terminals.listTerminals(checkout.id), isEmpty);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('workspace-new-tab-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('workspace-new-terminal')));
      await tester.pumpAndSettle();
      expect(find.byType(TRAlert), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
    tags: const <String>['feature_test__terminal_lifecycle__widget'],
  );

  for (final failure in <({String code, String message, String expected})>[
    (
      code: 'terminal_start_failed',
      message: 'The configured terminal shell could not be started.',
      expected: '설정된 터미널 셸을 시작할 수 없습니다. 터미널 설정을 확인하고 다시 시도하세요.',
    ),
    (
      code: 'unexpected_terminal_error',
      message: 'Safe daemon detail.',
      expected: 'Safe daemon detail.',
    ),
  ]) {
    testWidgets('terminal failure ${failure.code} has a safe description', (
      tester,
    ) async {
      await _setTestViewport(tester, const Size(1400, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = await _pumpRoute(
        tester,
        FakeTinestApi(
          workspaces: <WorkspaceDto>[workspace],
          worktrees: <WorktreeDto>[checkout],
          terminalCreateError: TinestClientException(
            failure.message,
            code: failure.code,
          ),
        ),
        WorktreeRoute(
          hostId: 'server',
          workspaceId: workspace.id,
          worktreeId: checkout.id,
        ).location,
      );
      addTearDown(router.dispose);

      await tester.tap(find.byKey(const ValueKey('workspace-new-tab-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('workspace-new-terminal')));
      await tester.pumpAndSettle();

      expect(find.text(failure.expected), findsOneWidget);
      expect(find.byType(TerminalView), findsNothing);
      expect(tester.takeException(), isNull);
    }, tags: const <String>['feature_test__terminal_lifecycle__widget']);
  }

  testWidgets('terminal tab shows attach failures and closes exited shells', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(1400, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const terminal = TerminalDto(
      id: 'terminal-failed-attach',
      worktreeId: 'checkout',
      title: 'Exited terminal',
      shell: ShellSpecDto(executable: '/bin/sh'),
      status: TerminalStatus.exited,
      columns: 80,
      rows: 24,
      lastSequence: 0,
      exitCode: 0,
    );
    final router = await _pumpRoute(
      tester,
      FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        terminals: const <TerminalDto>[terminal],
        terminalAttachError: Exception('host disconnected'),
      ),
      TerminalRoute(
        hostId: 'server',
        workspaceId: workspace.id,
        worktreeId: checkout.id,
        terminalId: terminal.id,
      ).location,
    );
    addTearDown(router.dispose);

    expect(find.text('터미널 연결에 실패했어요'), findsOneWidget);
    expect(find.textContaining('host disconnected'), findsOneWidget);
    await tester.tap(
      find.byKey(ValueKey<String>('tr-tabs-close-${terminal.id}')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('terminal-close-dialog')), findsNothing);
  });

  testWidgets(
    'terminal deep link restores the requested live terminal',
    (tester) async {
      await _setTestViewport(tester, const Size(1400, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const terminal = TerminalDto(
        id: 'terminal-deep-link',
        worktreeId: 'checkout',
        title: 'Remote terminal',
        shell: ShellSpecDto(executable: '/bin/sh'),
        status: TerminalStatus.running,
        columns: 80,
        rows: 24,
        lastSequence: 0,
      );
      final router = await _pumpRoute(
        tester,
        FakeTinestApi(
          workspaces: <WorkspaceDto>[workspace],
          worktrees: <WorktreeDto>[checkout],
          terminals: const <TerminalDto>[terminal],
          terminalReplay: const <TerminalOutputDto>[
            TerminalOutputDto(
              terminalId: 'terminal-deep-link',
              sequence: 1,
              data: 'ready\r\n',
            ),
            TerminalOutputDto(
              terminalId: 'terminal-deep-link',
              sequence: 1,
              data: 'duplicate',
            ),
          ],
        ),
        TerminalRoute(
          hostId: 'server',
          workspaceId: workspace.id,
          worktreeId: checkout.id,
          terminalId: terminal.id,
        ).location,
      );
      addTearDown(router.dispose);

      expect(find.byType(TerminalView), findsOneWidget);
      expect(find.text('Remote terminal'), findsOneWidget);
    },
    tags: const <String>[
      'feature_test__terminal_lifecycle__widget',
      'route_test__terminal_route__widget',
    ],
  );

  testWidgets(
    'terminal sends a Hangul word the input method composes exactly once',
    (tester) async {
      await _setTestViewport(tester, const Size(1400, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        terminals: const <TerminalDto>[liveTerminal],
      );
      final router = await _pumpRoute(
        tester,
        api,
        TerminalRoute(
          hostId: 'server',
          workspaceId: workspace.id,
          worktreeId: checkout.id,
          terminalId: liveTerminal.id,
        ).location,
      );
      addTearDown(router.dispose);

      // A Hangul input method keeps its committed text in the platform editing
      // buffer for the whole composition session instead of letting the
      // terminal reset it between syllables.
      for (final value in const <TextEditingValue>[
        TextEditingValue(
          text: 'ㅂ',
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange(start: 0, end: 1),
        ),
        TextEditingValue(
          text: '반',
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange(start: 0, end: 1),
        ),
        TextEditingValue(
          text: '반',
          selection: TextSelection.collapsed(offset: 1),
        ),
        TextEditingValue(
          text: '반갑',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 1, end: 2),
        ),
        TextEditingValue(
          text: '반갑',
          selection: TextSelection.collapsed(offset: 2),
        ),
        TextEditingValue(
          text: '반갑다',
          selection: TextSelection.collapsed(offset: 3),
          composing: TextRange(start: 2, end: 3),
        ),
        TextEditingValue(
          text: '반갑다',
          selection: TextSelection.collapsed(offset: 3),
        ),
      ]) {
        tester.testTextInput.updateEditingValue(value);
        await tester.pump();
      }

      expect(api.terminalWrites.map((write) => write.data).join(), '반갑다');
      expect(
        api.terminalWrites.map((write) => write.terminalId).toSet(),
        <String>{liveTerminal.id},
      );
    },
    tags: const <String>['feature_test__terminal_lifecycle__widget'],
  );

  testWidgets(
    'terminal ignores the duplicate commit a sticky input method repeats',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await _setTestViewport(tester, const Size(1400, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        terminals: const <TerminalDto>[liveTerminal],
      );
      final router = await _pumpRoute(
        tester,
        api,
        TerminalRoute(
          hostId: 'server',
          workspaceId: workspace.id,
          worktreeId: checkout.id,
          terminalId: liveTerminal.id,
        ).location,
      );
      addTearDown(router.dispose);

      // A sticky input method ends its composition session by reporting the
      // unchanged committed buffer one more time, without a new character.
      final client = tester.allStates.whereType<DeltaTextInputClient>().single;
      for (final delta in <TextEditingDelta>[
        const TextEditingDeltaInsertion(
          oldText: '  ',
          textInserted: '한',
          insertionOffset: 2,
          selection: TextSelection.collapsed(offset: 3),
          composing: TextRange(start: 2, end: 3),
        ),
        const TextEditingDeltaNonTextUpdate(
          oldText: '  한',
          selection: TextSelection.collapsed(offset: 3),
          composing: TextRange.empty,
        ),
        const TextEditingDeltaInsertion(
          oldText: '  한',
          textInserted: '솔',
          insertionOffset: 3,
          selection: TextSelection.collapsed(offset: 4),
          composing: TextRange(start: 3, end: 4),
        ),
        const TextEditingDeltaNonTextUpdate(
          oldText: '  한솔',
          selection: TextSelection.collapsed(offset: 4),
          composing: TextRange.empty,
        ),
        const TextEditingDeltaNonTextUpdate(
          oldText: '  한솔',
          selection: TextSelection.collapsed(offset: 4),
          composing: TextRange.empty,
        ),
      ]) {
        client.updateEditingValueWithDeltas(<TextEditingDelta>[delta]);
        await tester.pump();
      }
      debugDefaultTargetPlatformOverride = null;

      expect(api.terminalWrites.map((write) => write.data).join(), '한솔');
    },
    tags: const <String>['feature_test__terminal_lifecycle__widget'],
  );

  testWidgets(
    'terminal context menu closes on a terminal click and on Escape',
    (tester) async {
      await _setTestViewport(tester, const Size(1400, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        terminals: const <TerminalDto>[liveTerminal],
      );
      final router = await _pumpRoute(
        tester,
        api,
        TerminalRoute(
          hostId: 'server',
          workspaceId: workspace.id,
          worktreeId: checkout.id,
          terminalId: liveTerminal.id,
        ).location,
      );
      addTearDown(router.dispose);

      final copy = find.byKey(const ValueKey<String>('terminal-menu-copy'));
      final surface = find.byKey(const ValueKey<String>('tr-terminal-surface'));

      Future<void> openMenu() async {
        final gesture = await tester.startGesture(
          tester.getTopLeft(surface) + const Offset(24, 24),
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryButton,
        );
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.up();
        await tester.pumpAndSettle();
      }

      await openMenu();
      expect(copy, findsOneWidget);

      // The terminal anchors its own menu, so a click on the terminal is not
      // an outside tap for the menu's tap region and must still close it.
      await tester.tapAt(tester.getBottomRight(surface) - const Offset(48, 48));
      await tester.pumpAndSettle();
      expect(copy, findsNothing);
      // Let the terminal's double-tap recognition window expire.
      await tester.pump(const Duration(milliseconds: 350));

      await openMenu();
      expect(copy, findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(copy, findsNothing);

      // Closing the menu consumed Escape instead of sending it to the shell.
      expect(
        api.terminalWrites.map((write) => write.data).join(),
        isNot(contains('\x1b')),
      );
    },
    tags: const <String>['feature_test__terminal_lifecycle__widget'],
  );

  testWidgets(
    'terminal context menu copies the selection and pastes the clipboard',
    (tester) async {
      await _setTestViewport(tester, const Size(1400, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          switch (call.method) {
            case 'Clipboard.setData':
              final arguments = call.arguments as Map<Object?, Object?>;
              clipboard = arguments['text'] as String?;
              return null;
            case 'Clipboard.getData':
              return <String, Object?>{'text': clipboard};
            default:
              return null;
          }
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        terminals: const <TerminalDto>[liveTerminal],
        terminalReplay: const <TerminalOutputDto>[
          TerminalOutputDto(
            terminalId: 'terminal-deep-link',
            sequence: 1,
            data: 'selectable output',
          ),
        ],
      );
      final router = await _pumpRoute(
        tester,
        api,
        TerminalRoute(
          hostId: 'server',
          workspaceId: workspace.id,
          worktreeId: checkout.id,
          terminalId: liveTerminal.id,
        ).location,
      );
      addTearDown(router.dispose);

      final copy = find.byKey(const ValueKey<String>('terminal-menu-copy'));
      expect(copy, findsNothing);

      Future<void> openMenu() async {
        final surface = find.byKey(
          const ValueKey<String>('tr-terminal-surface'),
        );
        final gesture = await tester.startGesture(
          tester.getTopLeft(surface) + const Offset(24, 24),
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryButton,
        );
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.up();
        await tester.pumpAndSettle();
      }

      await openMenu();
      expect(copy, findsOneWidget);
      expect(find.text('붙여넣기'), findsOneWidget);

      // Copy stays unavailable until something is selected.
      expect(tester.widget<TRMenuItem>(copy).onPressed, isNull);
      await tester.tap(
        find.byKey(const ValueKey<String>('terminal-menu-select-all')),
      );
      await tester.pumpAndSettle();

      await openMenu();
      await tester.tap(copy);
      await tester.pumpAndSettle();
      expect(clipboard, contains('selectable output'));

      await openMenu();
      await tester.tap(
        find.byKey(const ValueKey<String>('terminal-menu-paste')),
      );
      await tester.pumpAndSettle();
      expect(
        api.terminalWrites.map((write) => write.data).join(),
        contains('selectable output'),
      );

      await openMenu();
      await tester.tap(
        find.byKey(const ValueKey<String>('terminal-menu-clear-screen')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TerminalView), findsOneWidget);
    },
    tags: const <String>['feature_test__terminal_lifecycle__widget'],
  );

  testWidgets('creates a session and sends a coding request', (tester) async {
    await _setTestViewport(tester, const Size(1500, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const planner = AgentDefinitionDto(
      version: 5,
      id: 'planner',
      name: 'Planner',
      description: 'Plans changes',
      mode: AgentMode.primary,
      model: AgentModelSelectionDto(source: AgentModelSource.session),
      driverId: 'tinest.standard/driver',
      extensionIds: <String>[],
      toolIds: <String>['tinest.files/read_file'],
      pluginSettings: <String, Map<String, dynamic>>{},
      callableAgentIds: <String>[],
      prompt: 'Plan first.',
      contentHash: 'planner-hash',
      sourcePath: '/config/agents/planner.md',
    );
    final api = FakeTinestApi(
      workspaces: <WorkspaceDto>[workspace],
      worktrees: <WorktreeDto>[checkout],
      agentDefinitions: const <AgentDefinitionDto>[planner],
      connections: <ProviderConnectionDto>[
        ProviderConnectionDto(
          id: 'openai',
          definitionId: 'openai',
          displayName: 'OpenAI',
          status: ProviderConnectionStatus.connected,
          authKind: ProviderAuthKind.apiKey,
          credentialOrigin: ProviderCredentialOrigin.stored,
          createdAt: now,
          updatedAt: now,
        ),
        ProviderConnectionDto(
          id: 'deepseek',
          definitionId: 'deepseek',
          displayName: 'DeepSeek',
          status: ProviderConnectionStatus.connected,
          authKind: ProviderAuthKind.apiKey,
          credentialOrigin: ProviderCredentialOrigin.stored,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      models: const <String, List<ProviderModelDto>>{
        'deepseek': <ProviderModelDto>[
          ProviderModelDto(
            connectionId: 'deepseek',
            id: 'deepseek/gpt-5.6-sol',
            providerModelId: 'gpt-5.6-sol',
            label: 'Shared Model',
            source: ProviderModelSource.bundled,
            capabilities: ModelCapabilitiesDto(
              streaming: CapabilitySupport.supported,
              toolCalling: CapabilitySupport.supported,
            ),
          ),
        ],
      },
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
    expect(find.byKey(const ValueKey('session-composer-agent')), findsOne);
    expect(find.text('Planner'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('session-composer-provider')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('session-composer-model')));
    await tester.pumpAndSettle();
    expect(find.textContaining('openai/gpt-5.6-sol'), findsOneWidget);
    expect(find.textContaining('deepseek/gpt-5.6-sol'), findsOneWidget);
    await tester.enterText(find.byType(TRTextField).last, 'DeepSeek');
    await tester.pumpAndSettle();
    expect(find.textContaining('openai/gpt-5.6-sol'), findsNothing);
    expect(find.text('DeepSeek · deepseek/gpt-5.6-sol'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('model-option-deepseek-gpt-5.6-sol')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('session-composer-input')),
      'Run the tests',
    );
    await tester.tap(find.byKey(const ValueKey('session-composer-send')));
    await tester.pumpAndSettle();

    final created = api.createdSessions.single;
    expect(created.agentDefinitionId, 'planner');
    expect(created.title, 'Run the tests');
    expect(
      created.model,
      const ModelSelectionDto(modelId: 'deepseek/gpt-5.6-sol'),
    );
    expect(api.startedPrompts, <String>['Run the tests']);
  }, tags: const <String>['feature_test__session_lifecycle__widget']);

  testWidgets('composer pins a model at creation and replaces it mid-session', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(1500, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const fast = ProviderModelDto(
      connectionId: 'openai',
      id: 'openai/gpt-5.6-fast',
      providerModelId: 'gpt-5.6-fast',
      label: 'GPT-5.6 Fast',
      source: ProviderModelSource.bundled,
      capabilities: ModelCapabilitiesDto(
        streaming: CapabilitySupport.supported,
        toolCalling: CapabilitySupport.supported,
      ),
    );
    final api = FakeTinestApi(
      workspaces: <WorkspaceDto>[workspace],
      worktrees: <WorktreeDto>[checkout],
      connections: <ProviderConnectionDto>[
        ProviderConnectionDto(
          id: 'openai',
          definitionId: 'openai',
          displayName: 'OpenAI',
          status: ProviderConnectionStatus.connected,
          authKind: ProviderAuthKind.apiKey,
          credentialOrigin: ProviderCredentialOrigin.stored,
          createdAt: now,
          updatedAt: now,
        ),
        ProviderConnectionDto(
          id: 'deepseek',
          definitionId: 'deepseek',
          displayName: 'DeepSeek',
          status: ProviderConnectionStatus.degraded,
          authKind: ProviderAuthKind.apiKey,
          credentialOrigin: ProviderCredentialOrigin.stored,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      agentDefinitions: const <AgentDefinitionDto>[
        AgentDefinitionDto(
          version: 5,
          id: 'tinest',
          name: 'Tinest',
          description: 'Coding agent',
          mode: AgentMode.primary,
          model: AgentModelSelectionDto(
            source: AgentModelSource.fixed,
            modelId: 'openai/gpt-5.6-sol',
          ),
          driverId: 'tinest.standard/driver',
          extensionIds: <String>[],
          toolIds: <String>['tinest.files/read_file'],
          pluginSettings: <String, Map<String, dynamic>>{},
          callableAgentIds: <String>[],
          prompt: 'Code carefully.',
          contentHash: 'tinest-hash',
          sourcePath: '/config/agents/tinest.md',
          isBuiltIn: true,
        ),
      ],
      models: <String, List<ProviderModelDto>>{
        'openai': <ProviderModelDto>[
          const ProviderModelDto(
            connectionId: 'openai',
            id: 'openai/gpt-5.6-sol',
            providerModelId: 'gpt-5.6-sol',
            label: 'GPT-5.6 Sol',
            source: ProviderModelSource.bundled,
            capabilities: ModelCapabilitiesDto(
              streaming: CapabilitySupport.supported,
              toolCalling: CapabilitySupport.supported,
            ),
          ),
          fast,
        ],
        'deepseek': <ProviderModelDto>[
          const ProviderModelDto(
            connectionId: 'deepseek',
            id: 'deepseek/deepseek-v4',
            providerModelId: 'deepseek-v4',
            label: 'DeepSeek V4',
            source: ProviderModelSource.bundled,
            capabilities: ModelCapabilitiesDto(
              streaming: CapabilitySupport.supported,
              toolCalling: CapabilitySupport.supported,
            ),
          ),
        ],
      },
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

    await tester.tap(find.byKey(const ValueKey('session-composer-model')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('model-option-openai-gpt-5.6-fast')),
    );
    await tester.pumpAndSettle();
    expect(find.text('GPT-5.6 Fast'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('session-composer-input')),
      'Speed up the build',
    );
    await tester.tap(find.byKey(const ValueKey('session-composer-send')));
    await tester.pumpAndSettle();
    expect(
      api.createdSessions.single.model,
      const ModelSelectionDto(modelId: 'openai/gpt-5.6-fast'),
    );

    await tester.tap(find.byKey(const ValueKey('session-composer-model')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('model-option-deepseek-deepseek-v4')),
    );
    await tester.pumpAndSettle();
    expect(
      api.updatedSessionModels.single.model,
      const ModelSelectionDto(modelId: 'deepseek/deepseek-v4'),
    );

    await tester.tap(find.byKey(const ValueKey('session-composer-model')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('model-option-inherit')), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(
      api.updatedSessionModels.last.model,
      const ModelSelectionDto(modelId: 'deepseek/deepseek-v4'),
    );
    expect(
      (await api.sessions.listSessions()).single.model,
      const ModelSelectionDto(modelId: 'deepseek/deepseek-v4'),
    );
  }, tags: const <String>['feature_test__session_lifecycle__widget']);

  testWidgets(
    'composer snapshots model controls and resets optional settings',
    (tester) async {
      await _setTestViewport(tester, const Size(1400, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        connections: <ProviderConnectionDto>[
          ProviderConnectionDto(
            id: 'openai',
            definitionId: 'openai',
            displayName: 'OpenAI',
            status: ProviderConnectionStatus.connected,
            authKind: ProviderAuthKind.apiKey,
            credentialOrigin: ProviderCredentialOrigin.stored,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        models: const <String, List<ProviderModelDto>>{
          'openai': <ProviderModelDto>[
            ProviderModelDto(
              connectionId: 'openai',
              id: 'openai/gpt-5.6-sol',
              providerModelId: 'gpt-5.6-sol',
              label: 'GPT-5.6 Sol',
              source: ProviderModelSource.bundled,
              capabilities: ModelCapabilitiesDto(
                streaming: CapabilitySupport.supported,
                toolCalling: CapabilitySupport.supported,
                controls: <ModelControlDescriptorDto>[
                  ModelControlDescriptorDto(
                    id: 'reasoning_effort',
                    label: 'Reasoning effort',
                    kind: ModelControlKind.choice,
                    presentation: ModelControlPresentation.menuChip,
                    choices: <ModelControlChoiceDto>[
                      ModelControlChoiceDto(id: 'low', label: 'Low'),
                      ModelControlChoiceDto(id: 'high', label: 'High'),
                    ],
                  ),
                  ModelControlDescriptorDto(
                    id: 'fast_mode',
                    label: 'Fast',
                    kind: ModelControlKind.toggle,
                    presentation: ModelControlPresentation.selectableChip,
                  ),
                ],
              ),
            ),
            // A model the catalog says cannot honour either setting.
            ProviderModelDto(
              connectionId: 'openai',
              id: 'openai/gpt-5.6-plain',
              providerModelId: 'gpt-5.6-plain',
              label: 'GPT-5.6 Plain',
              source: ProviderModelSource.bundled,
              capabilities: ModelCapabilitiesDto(
                streaming: CapabilitySupport.supported,
                toolCalling: CapabilitySupport.supported,
              ),
            ),
          ],
        },
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

      // Permissions never depend on the model, so the chip is always offered.
      expect(
        find.byKey(const ValueKey('session-composer-permission')),
        findsOne,
      );

      expect(
        find.byKey(const ValueKey('session-composer-control-reasoning_effort')),
        findsOne,
      );
      expect(
        find.byKey(const ValueKey('session-composer-control-fast_mode')),
        findsOne,
      );

      await tester.tap(
        find.byKey(const ValueKey('session-composer-control-reasoning_effort')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey('session-composer-control-reasoning_effort-high'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('High'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('session-composer-permission')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('permission-option-readOnly')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('session-composer-control-fast_mode')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('session-composer-input')),
        'Audit the parser',
      );
      await tester.tap(find.byKey(const ValueKey('session-composer-send')));
      await tester.pumpAndSettle();

      final created = api.createdSessions.single;
      expect(
        created.model,
        const ModelSelectionDto(modelId: 'openai/gpt-5.6-sol'),
      );
      expect(
        created.modelControls['reasoning_effort'],
        const ModelControlValueDto.stringValue(value: 'high'),
      );
      expect(created.permissionMode, PermissionMode.readOnly);
      expect(
        created.modelControls['fast_mode'],
        const ModelControlValueDto.boolValue(value: true),
      );

      // Toggling fast mode off restores the provider default tier.
      await tester.tap(
        find.byKey(const ValueKey('session-composer-control-fast_mode')),
      );
      await tester.pumpAndSettle();
      expect(api.updatedSessionServiceTiers.single.serviceTier, isNull);

      await tester.tap(
        find.byKey(const ValueKey('session-composer-control-reasoning_effort')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey('session-composer-control-reasoning_effort-default'),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.updatedSessionReasoningEfforts.last.reasoningEffort, isNull);

      await tester.tap(
        find.byKey(const ValueKey('session-composer-permission')),
      );
      await tester.pumpAndSettle();
      // There is no option that hands the decision back to something else;
      // every entry pins one concrete mode.
      expect(
        find.byKey(const ValueKey('permission-option-inherit')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('permission-option-workspaceWrite')),
      );
      await tester.pumpAndSettle();
      expect(
        api.updatedSessionPermissionModes.single.permissionMode,
        PermissionMode.workspaceWrite,
      );

      // A model without the capability hides both controls again.
      await tester.tap(find.byKey(const ValueKey('session-composer-model')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('model-option-openai-gpt-5.6-plain')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('session-composer-control-reasoning_effort')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('session-composer-control-fast_mode')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('session-composer-permission')),
        findsOne,
      );
    },
    tags: const <String>['feature_test__session_lifecycle__widget'],
  );

  testWidgets(
    'the draft composer submits a removed host command as prompt text',
    (tester) async {
      await _setTestViewport(tester, const Size(1500, 760));
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

      // The draft pane creates its session from the first prompt, so `/new`
      // has no session to be new relative to.
      await tester.enterText(
        find.byKey(const ValueKey('session-composer-input')),
        '/',
      );
      await tester.pumpAndSettle();
      expect(find.text('mode'), findsNothing);
      expect(find.text('new'), findsNothing);

      expect(find.text('Plan'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('session-composer-input')),
        '/mode',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('session-composer-send')));
      await tester.pumpAndSettle();

      expect(find.text('Plan'), findsNothing);
      expect(api.createdSessions, hasLength(1));
      expect(api.startedPrompts, <String>['/mode']);
    },
    tags: const <String>['feature_test__composer_slash_command__widget'],
  );
}
