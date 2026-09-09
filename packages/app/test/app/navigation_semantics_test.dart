import 'dart:async';

import 'package:app/src/app/presentation/settings_page.dart';
import 'package:app/src/app/presentation/workspace_page.dart';
import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/hosts/domain/host_ports.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';

import '../support/fake_tinest_api.dart';
import '../support/router_harness.dart';

Future<void> _sendBackGesture(WidgetTester tester, MethodCall call) async {
  final message = const StandardMethodCodec().encodeMethodCall(call);
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    message,
    (_) {},
  );
}

/// Navigation-verb behaviour: pushed tasks pop back, lateral moves do not
/// change the stack, and deep links still close to a sensible destination.
void main() {
  final now = DateTime.utc(2026, 8, 5);
  final workspace = WorkspaceDto(
    id: 'workspace',
    name: 'Tinest',
    rootPath: '/repos/tinest',
    kind: WorkspaceKind.git,
    createdAt: now,
  );
  final worktree = WorktreeDto(
    id: 'checkout',
    workspaceId: workspace.id,
    name: 'main',
    path: workspace.rootPath,
    branch: 'main',
    kind: WorktreeKind.checkout,
    isTinestOwned: false,
    createdAt: now,
  );
  SessionDto session(String id, String title) => SessionDto(
    id: id,
    worktreeId: worktree.id,
    title: title,
    agentDefinitionId: 'tinest',
    origin: SessionOrigin.manual,
    status: SessionStatus.idle,
    model: const ModelSelectionDto(modelId: 'openai/gpt-5.6-sol'),
    createdAt: now,
    updatedAt: now,
  );
  final worktreeLocation = WorktreeRoute(
    hostId: 'server',
    workspaceId: workspace.id,
    worktreeId: worktree.id,
  ).location;

  FakeTinestApi apiWith(List<SessionDto> sessions) => FakeTinestApi(
    workspaces: <WorkspaceDto>[workspace],
    worktrees: <WorktreeDto>[worktree],
    agents: sessions,
  );

  /// Two connections, so a chosen detail is distinguishable from the one the
  /// wide layout selects on entry.
  FakeTinestApi apiWithProviders() => FakeTinestApi(
    workspaces: <WorkspaceDto>[workspace],
    worktrees: <WorktreeDto>[worktree],
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
  );

  Future<void> useWidth(WidgetTester tester, double width) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = Size(width, 900);
    addTearDown(tester.view.reset);
  }

  Future<void> useDesktop(WidgetTester tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
  }

  Future<void> useMobile(WidgetTester tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 780);
    addTearDown(tester.view.reset);
  }

  Future<void> useTwoPane(WidgetTester tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(800, 900);
    addTearDown(tester.view.reset);
  }

  testWidgets(
    'system Back closes the new-workspace composer to the workspace list',
    (tester) async {
      await useMobile(tester);
      final router = await pumpRoutedApp(
        tester,
        apiWith(<SessionDto>[]),
        initialLocation: const WorkspaceHomeRoute().location,
      );
      addTearDown(router.dispose);

      await tester.tap(find.byKey(const ValueKey('workspace-new-button')));
      await tester.pumpAndSettle();
      expect(
        currentLocation(router),
        const WorkspaceHomeRoute(compose: true).location,
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(currentLocation(router), const WorkspaceHomeRoute().location);
      expect(
        find.byKey(const ValueKey('workspace-new-button')),
        findsOneWidget,
      );
    },
    tags: const <String>['feature_test__app_navigation__widget'],
  );

  testWidgets(
    'system Back closes a directly opened mobile session to the workspace list',
    (tester) async {
      await useMobile(tester);
      final router = await pumpRoutedApp(
        tester,
        apiWith(<SessionDto>[session('session', 'Route session')]),
        initialLocation: SessionRoute(
          hostId: 'server',
          workspaceId: workspace.id,
          worktreeId: worktree.id,
          sessionId: 'session',
        ).location,
      );
      addTearDown(router.dispose);

      expect(find.text('Route session'), findsWidgets);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(currentLocation(router), const WorkspaceHomeRoute().location);
      expect(
        find.byKey(const ValueKey('workspace-new-button')),
        findsOneWidget,
      );
    },
    tags: const <String>['feature_test__app_navigation__widget'],
  );

  testWidgets(
    'Android predictive Back cancel preserves the session and commit returns '
    'home',
    (tester) async {
      await useMobile(tester);
      final sessionLocation = SessionRoute(
        hostId: 'server',
        workspaceId: workspace.id,
        worktreeId: worktree.id,
        sessionId: 'session',
      ).location;
      final router = await pumpRoutedApp(
        tester,
        apiWith(<SessionDto>[session('session', 'Route session')]),
        initialLocation: sessionLocation,
        platform: TargetPlatform.android,
      );
      addTearDown(router.dispose);

      Future<void> startAndUpdate() async {
        await _sendBackGesture(
          tester,
          const MethodCall('startBackGesture', <String, Object>{
            'touchOffset': <double>[5, 300],
            'progress': 0.0,
            'swipeEdge': 0,
          }),
        );
        await _sendBackGesture(
          tester,
          const MethodCall('updateBackGestureProgress', <String, Object>{
            'touchOffset': <double>[160, 300],
            'progress': 0.5,
            'swipeEdge': 0,
          }),
        );
        await tester.pump();
      }

      await startAndUpdate();
      expect(currentLocation(router), sessionLocation);
      expect(
        find.byKey(const ValueKey('workspace-new-button')),
        findsOneWidget,
      );

      await _sendBackGesture(tester, const MethodCall('cancelBackGesture'));
      await tester.pumpAndSettle();
      expect(currentLocation(router), sessionLocation);
      expect(find.text('Route session'), findsWidgets);
      expect(find.byKey(const ValueKey('workspace-new-button')), findsNothing);

      await startAndUpdate();
      await _sendBackGesture(tester, const MethodCall('commitBackGesture'));
      await tester.pumpAndSettle();
      expect(currentLocation(router), const WorkspaceHomeRoute().location);
      expect(
        find.byKey(const ValueKey('workspace-new-button')),
        findsOneWidget,
      );
    },
    tags: const <String>['feature_test__app_navigation__widget'],
  );

  testWidgets(
    'reduced motion exposes a pushed settings page on the first frame',
    (tester) async {
      await useMobile(tester);
      final router = await pumpRoutedApp(
        tester,
        apiWith(<SessionDto>[]),
        initialLocation: const SettingsHomeRoute().location,
        disableAnimations: true,
      );
      addTearDown(router.dispose);

      unawaited(router.push<void>(const GeneralSettingsRoute().location));
      // One frame applies GoRouter's new configuration; the next paints the
      // Material route at its reduced-motion destination.
      await tester.pump();
      await tester.pump();

      expect(currentLocation(router), const GeneralSettingsRoute().location);
      expect(
        find.byKey(const ValueKey<String>('settings-category-pane-general')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('settings-home-pane')).hitTestable(),
        findsNothing,
      );
    },
    tags: const <String>['feature_test__app_navigation__widget'],
  );

  testWidgets(
    'system Back closes a session selected from the mobile workspace list',
    (tester) async {
      await useMobile(tester);
      final homeWorkspace = workspace.copyWith(
        id: 'home',
        name: 'Home',
        rootPath: '/home/user',
        kind: WorkspaceKind.home,
      );
      final homeWorktree = worktree.copyWith(
        id: 'home-checkout',
        workspaceId: homeWorkspace.id,
        name: 'Home',
        path: homeWorkspace.rootPath,
        branch: null,
        kind: WorktreeKind.directory,
      );
      final homeSession = session(
        'home-session',
        'Home session',
      ).copyWith(worktreeId: homeWorktree.id);
      final router = await pumpRoutedApp(
        tester,
        FakeTinestApi(
          workspaces: <WorkspaceDto>[homeWorkspace],
          worktrees: <WorktreeDto>[homeWorktree],
          agents: <SessionDto>[homeSession],
        ),
        initialLocation: const WorkspaceHomeRoute().location,
      );
      addTearDown(router.dispose);

      await tester.tap(find.text('Home session'));
      await tester.pumpAndSettle();
      expect(currentLocation(router), contains('/sessions/home-session'));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(currentLocation(router), const WorkspaceHomeRoute().location);
      expect(
        find.byKey(const ValueKey('workspace-new-button')),
        findsOneWidget,
      );
    },
    tags: const <String>['feature_test__app_navigation__widget'],
  );

  testWidgets(
    'system Back closes a restored mobile worktree to the workspace list',
    (tester) async {
      await useMobile(tester);
      final router = await pumpRoutedApp(
        tester,
        apiWith(<SessionDto>[]),
        initialLocation: const WorkspaceHomeRoute().location,
        store: MemoryAppStore(
          settings: AppSettings(
            embeddedDaemonEnabled: false,
            lastWorktree: WorkspaceSelection(
              hostId: 'server',
              workspaceId: workspace.id,
              worktreeId: worktree.id,
            ),
          ),
        ),
      );
      addTearDown(router.dispose);

      expect(currentLocation(router), worktreeLocation);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(currentLocation(router), const WorkspaceHomeRoute().location);
      expect(
        find.byKey(const ValueKey('workspace-new-button')),
        findsOneWidget,
      );
    },
    tags: const <String>['feature_test__app_navigation__widget'],
  );

  testWidgets(
    'wide settings Back and Up both return to the worktree in one press',
    (tester) async {
      await useDesktop(tester);
      final router = await pumpRoutedApp(
        tester,
        apiWith(<SessionDto>[session('session', 'Route session')]),
        initialLocation: worktreeLocation,
      );
      addTearDown(router.dispose);

      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-settings-button')),
      );
      await tester.pumpAndSettle();
      expect(
        currentLocation(router),
        const ProviderSettingsRoute(hostId: 'server').location,
      );
      expect(router.canPop(), isTrue);

      // The split detail sits beside its collection, so neither verb spends a
      // press closing it.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(currentLocation(router), worktreeLocation);

      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-settings-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('settings-back-button')),
      );
      await tester.pumpAndSettle();
      expect(currentLocation(router), worktreeLocation);
    },
    tags: const <String>['feature_test__app_navigation__widget'],
  );

  testWidgets(
    'system Back on a settings deep link does not synthesize Up history',
    (tester) async {
      await useDesktop(tester);
      final router = await pumpRoutedApp(
        tester,
        apiWith(<SessionDto>[]),
        initialLocation: const GeneralSettingsRoute().location,
      );
      addTearDown(router.dispose);

      expect(router.canPop(), isFalse);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(currentLocation(router), const GeneralSettingsRoute().location);
    },
    tags: const <String>['feature_test__app_navigation__widget'],
  );

  testWidgets('settings Up on a wide deep link closes to the workspace home', (
    tester,
  ) async {
    await useDesktop(tester);
    final router = await pumpRoutedApp(
      tester,
      apiWith(<SessionDto>[]),
      initialLocation: const GeneralSettingsRoute().location,
    );
    addTearDown(router.dispose);

    await tester.tap(
      find.byKey(const ValueKey<String>('settings-back-button')),
    );
    await tester.pumpAndSettle();
    expect(currentLocation(router), const WorkspaceHomeRoute().location);
  }, tags: const <String>['feature_test__app_navigation__widget']);

  testWidgets(
    'wide daemon categories Up leaves without stepping through its detail',
    (tester) async {
      await useDesktop(tester);
      const route = DaemonCategoriesRoute(hostId: 'server');
      final router = await pumpRoutedApp(
        tester,
        apiWith(<SessionDto>[]),
        initialLocation: route.location,
      );
      addTearDown(router.dispose);

      // Wide daemon categories render the Provider category, which selects its
      // first connection on entry.
      expect(
        find.byKey(const ValueKey<String>('provider-detail-openai')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('settings-back-button')),
      );
      await tester.pumpAndSettle();
      expect(currentLocation(router), const WorkspaceHomeRoute().location);
    },
    tags: const <String>['feature_test__app_navigation__widget'],
  );

  testWidgets(
    'switching settings categories keeps the entry screen on the stack',
    (tester) async {
      await useDesktop(tester);
      final router = await pumpRoutedApp(
        tester,
        apiWith(<SessionDto>[session('session', 'Route session')]),
        initialLocation: worktreeLocation,
      );
      addTearDown(router.dispose);

      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-settings-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('일반'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('프로젝트'));
      await tester.pumpAndSettle();
      expect(currentLocation(router), const ProjectSettingsRoute().location);
      expect(router.canPop(), isTrue);

      // Lateral moves replaced the settings page rather than stacking, so the
      // worktree is still directly beneath however many categories were open.
      await tester.tap(
        find.byKey(const ValueKey<String>('settings-back-button')),
      );
      await tester.pumpAndSettle();
      expect(currentLocation(router), worktreeLocation);
    },
    tags: const <String>['feature_test__app_navigation__widget'],
  );

  testWidgets('desktop settings Up closes the task in one press', (
    tester,
  ) async {
    await useDesktop(tester);
    final router = await pumpRoutedApp(
      tester,
      apiWith(<SessionDto>[session('session', 'Route session')]),
      initialLocation: worktreeLocation,
    );
    addTearDown(router.dispose);

    await tester.tap(
      find.byKey(const ValueKey<String>('workspace-settings-button')),
    );
    await tester.pumpAndSettle();
    expect(
      currentLocation(router),
      const ProviderSettingsRoute(hostId: 'server').location,
    );
    expect(
      find.byKey(const ValueKey<String>('provider-detail-openai')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('settings-back-button')),
    );
    await tester.pumpAndSettle();
    expect(currentLocation(router), worktreeLocation);
  }, tags: const <String>['feature_test__app_navigation__widget']);

  testWidgets(
    'settings Up below the split width closes the detail before the task',
    (tester) async {
      // One pixel below the large break, so this also pins the shell and the
      // list-detail host to the same split predicate.
      await useWidth(tester, 1199);
      final router = await pumpRoutedApp(
        tester,
        apiWith(<SessionDto>[session('session', 'Route session')]),
        initialLocation: worktreeLocation,
      );
      addTearDown(router.dispose);

      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-settings-button')),
      );
      await tester.pumpAndSettle();
      final settingsLocation = const ProviderSettingsRoute(hostId: 'server')
          .location;
      expect(currentLocation(router), settingsLocation);
      expect(
        find.byKey(const ValueKey<String>('provider-detail-openai')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('provider-connection-openai')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('provider-detail-openai')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('settings-back-button')),
      );
      await tester.pumpAndSettle();
      expect(currentLocation(router), settingsLocation);
      expect(
        find.byKey(const ValueKey<String>('provider-detail-openai')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('provider-connection-openai')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('settings-back-button')),
      );
      await tester.pumpAndSettle();
      expect(currentLocation(router), worktreeLocation);
    },
    tags: const <String>['feature_test__app_navigation__widget'],
  );

  testWidgets(
    'reaching the same wide category by another route keeps the selection',
    (tester) async {
      await useDesktop(tester);
      final router = await pumpRoutedApp(
        tester,
        apiWithProviders(),
        initialLocation: const DaemonCategoriesRoute(hostId: 'server').location,
      );
      addTearDown(router.dispose);

      // Wide daemon categories render the Provider category, which selects its
      // first connection once.
      expect(
        find.byKey(const ValueKey<String>('provider-detail-openai')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('provider-connection-deepseek')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('provider-detail-deepseek')),
        findsOneWidget,
      );

      // The sidebar navigates without `host-id`, leaning on the persisted
      // daemon, so the URL changes while the rendered category does not.
      await tester.tap(
        find.byKey(const ValueKey<String>('settings-category-row-provider')),
      );
      await tester.pumpAndSettle();

      expect(currentLocation(router), const ProviderSettingsRoute().location);
      expect(
        find.byKey(const ValueKey<String>('provider-detail-deepseek')),
        findsOneWidget,
      );
    },
    tags: const <String>['feature_test__app_navigation__widget'],
  );

  testWidgets(
    'a settings stack pushed while compact survives the window widening',
    (tester) async {
      await useMobile(tester);
      final router = await pumpRoutedApp(
        tester,
        apiWith(<SessionDto>[session('session', 'Route session')]),
        initialLocation: worktreeLocation,
      );
      addTearDown(router.dispose);

      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-settings-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('settings-category-row-general')),
      );
      await tester.pumpAndSettle();
      expect(currentLocation(router), const GeneralSettingsRoute().location);

      await useDesktop(tester);
      await tester.pumpAndSettle();

      // Widening does not discard what compact pushed, so the page it was
      // pushed from is still a destination and costs its own press.
      await tester.tap(
        find.byKey(const ValueKey<String>('settings-back-button')),
      );
      await tester.pumpAndSettle();
      expect(currentLocation(router), const SettingsHomeRoute().location);

      await tester.tap(
        find.byKey(const ValueKey<String>('settings-back-button')),
      );
      await tester.pumpAndSettle();
      expect(currentLocation(router), worktreeLocation);
    },
    tags: const <String>['feature_test__app_navigation__widget'],
  );

  testWidgets(
    'rapid lateral settings replacements settle on the final URL and pane',
    (tester) async {
      await useDesktop(tester);
      final router = await pumpRoutedApp(
        tester,
        apiWith(<SessionDto>[]),
        initialLocation: const GeneralSettingsRoute().location,
      );
      addTearDown(router.dispose);

      unawaited(router.replace<void>(const ProjectSettingsRoute().location));
      unawaited(router.replace<void>(const AgentSettingsRoute().location));
      unawaited(router.replace<void>(const AdvancedSettingsRoute().location));
      await tester.pumpAndSettle();

      expect(currentLocation(router), const AdvancedSettingsRoute().location);
      expect(
        find.byKey(const ValueKey<String>('settings-category-pane-advanced')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
    tags: const <String>['feature_test__app_navigation__widget'],
  );

  testWidgets(
    'two-pane category replacement keeps the typed shell and sidebar mounted',
    (tester) async {
      await useTwoPane(tester);
      final router = await pumpRoutedApp(
        tester,
        apiWith(<SessionDto>[]),
        initialLocation: const ModelSettingsRoute().location,
      );
      addTearDown(router.dispose);

      final shell = find.byType(UnifiedSettingsPage);
      final shellState = tester.state<State<UnifiedSettingsPage>>(shell);
      final sidebar = find.byKey(
        const ValueKey<String>('settings-sidebar-surface'),
      );
      final sidebarElement = tester.element(sidebar);
      final sidebarRect = tester.getRect(sidebar);
      final childNavigator = SettingsShellRoute.$navigatorKey.currentState;

      await tester.tap(
        find.byKey(const ValueKey<String>('settings-category-row-permission')),
      );
      await tester.pump();
      await tester.pump();

      expect(currentLocation(router), const PermissionSettingsRoute().location);
      expect(tester.state<State<UnifiedSettingsPage>>(shell), same(shellState));
      expect(
        SettingsShellRoute.$navigatorKey.currentState,
        same(childNavigator),
      );
      expect(tester.element(sidebar), same(sidebarElement));
      expect(tester.getRect(sidebar), sidebarRect);
      final permissionPane = find.byKey(
        const ValueKey<String>('settings-category-pane-permission'),
      );
      expect(permissionPane, findsOneWidget);

      await tester.pumpAndSettle();
      expect(permissionPane, findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('settings-category-pane-model')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
    tags: const <String>['feature_test__app_navigation__widget'],
  );

  testWidgets('selecting a session keeps the workspace page mounted', (
    tester,
  ) async {
    await useDesktop(tester);
    final router = await pumpRoutedApp(
      tester,
      apiWith(<SessionDto>[
        session('one', 'Session one'),
        session('two', 'Session two'),
      ]),
      initialLocation: SessionRoute(
        hostId: 'server',
        workspaceId: workspace.id,
        worktreeId: worktree.id,
        sessionId: 'one',
      ).location,
    );
    addTearDown(router.dispose);

    final before = tester.state<State<WorkspacePage>>(
      find.byType(WorkspacePage),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('workspace-all-sessions-menu')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Session two'));
    await tester.pumpAndSettle();

    expect(currentLocation(router), contains('two'));
    expect(
      tester.state<State<WorkspacePage>>(find.byType(WorkspacePage)),
      same(before),
    );
  }, tags: const <String>['feature_test__app_navigation__widget']);

  testWidgets('a later session location opens that session', (tester) async {
    await useDesktop(tester);
    final router = await pumpRoutedApp(
      tester,
      apiWith(<SessionDto>[
        session('one', 'Session one'),
        session('two', 'Session two'),
      ]),
      initialLocation: SessionRoute(
        hostId: 'server',
        workspaceId: workspace.id,
        worktreeId: worktree.id,
        sessionId: 'one',
      ).location,
    );
    addTearDown(router.dispose);
    expect(find.text('Session two'), findsNothing);

    // Selecting a session replaces the location instead of pushing, so the
    // page survives and has to react to the new session itself.
    unawaited(
      router.replace<void>(
        SessionRoute(
          hostId: 'server',
          workspaceId: workspace.id,
          worktreeId: worktree.id,
          sessionId: 'two',
        ).location,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Session two'), findsWidgets);
  }, tags: const <String>['feature_test__app_navigation__widget']);

  testWidgets('adding a remote daemon closes back to the daemon list', (
    tester,
  ) async {
    await useDesktop(tester);
    final router = await pumpRoutedApp(
      tester,
      apiWith(<SessionDto>[]),
      initialLocation: const DaemonSettingsRoute().location,
    );
    addTearDown(router.dispose);

    await tester.tap(
      find.byKey(const ValueKey<String>('app-settings-add-remote')),
    );
    await tester.pumpAndSettle();
    expect(currentLocation(router), const ConnectDaemonRoute().location);
    expect(router.canPop(), isTrue);

    await tester.tap(
      find.byKey(const ValueKey<String>('remote-host-back-button')),
    );
    await tester.pumpAndSettle();
    expect(currentLocation(router), const DaemonSettingsRoute().location);
  }, tags: const <String>['feature_test__app_navigation__widget']);

  testWidgets('reopening settings from the shell does not stack duplicates', (
    tester,
  ) async {
    await useDesktop(tester);
    final router = await pumpRoutedApp(
      tester,
      apiWith(<SessionDto>[]),
      initialLocation: const WorkspaceHomeRoute().location,
    );
    addTearDown(router.dispose);

    openSettingsTask(router);
    await tester.pumpAndSettle();
    openSettingsTask(router);
    await tester.pumpAndSettle();
    expect(currentLocation(router), const SettingsHomeRoute().location);

    await tester.tap(
      find.byKey(const ValueKey<String>('settings-back-button')),
    );
    await tester.pumpAndSettle();
    expect(currentLocation(router), const WorkspaceHomeRoute().location);
  }, tags: const <String>['feature_test__app_navigation__widget']);

  testWidgets(
    'a delayed workspace restore cannot replace an open settings task',
    (tester) async {
      await useDesktop(tester);
      final catalogGate = Completer<void>();
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[worktree],
        workspaceCatalogGate: catalogGate.future,
      );
      final store = MemoryAppStore(
        settings: AppSettings(
          embeddedDaemonEnabled: false,
          lastWorktree: WorkspaceSelection(
            hostId: 'server',
            workspaceId: workspace.id,
            worktreeId: worktree.id,
          ),
        ),
      );
      final router = await pumpRoutedApp(
        tester,
        api,
        initialLocation: const WorkspaceHomeRoute().location,
        store: store,
        settle: false,
      );
      addTearDown(router.dispose);

      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-settings-button')),
      );
      for (var frame = 0; frame < 4; frame += 1) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(currentLocation(router), const DaemonSettingsRoute().location);

      catalogGate.complete();
      await tester.pumpAndSettle();

      expect(currentLocation(router), const DaemonSettingsRoute().location);
      expect(find.byType(Navigator), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('일반'));
      await tester.pumpAndSettle();
      expect(currentLocation(router), const GeneralSettingsRoute().location);
      expect(find.byType(Navigator), findsNWidgets(2));

      await tester.tap(
        find.byKey(const ValueKey<String>('settings-back-button')),
      );
      await tester.pumpAndSettle();
      expect(currentLocation(router), const WorkspaceHomeRoute().location);
    },
    tags: const <String>['feature_test__app_navigation__widget'],
  );
}
