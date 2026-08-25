import 'dart:async';

import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/workspace/application/workspace_controller.dart';
import 'package:app/src/features/workspace/presentation/widgets/workspace_sidebar.dart';
import 'package:client/client.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    rootPath: '/repos/$id',
    kind: WorkspaceKind.git,
    createdAt: now,
  );

  WorktreeDto worktree(String id, String workspaceId, String branch) =>
      WorktreeDto(
        id: id,
        workspaceId: workspaceId,
        name: branch,
        path: '/repos/$workspaceId',
        branch: branch,
        head: 'abc',
        kind: WorktreeKind.checkout,
        isTinestOwned: false,
        createdAt: now,
      );

  /// A checkout beside the workspace root, which a row menu can archive.
  WorktreeDto linkedWorktree(
    String id,
    String workspaceId,
    String branch, {
    bool isTinestOwned = true,
  }) => WorktreeDto(
    id: id,
    workspaceId: workspaceId,
    name: branch,
    path: '/state/worktrees/$workspaceId/$branch',
    branch: branch,
    head: 'def',
    kind: WorktreeKind.linked,
    isTinestOwned: isTinestOwned,
    createdAt: now,
  );

  HostRuntimeSnapshot host(
    String id,
    String label, {
    HostRuntimeStatus status = HostRuntimeStatus.online,
    TinestApi? api,
  }) => HostRuntimeSnapshot(
    id: id,
    label: label,
    kind: HostKind.remote,
    status: status,
    endpoint: HostEndpoint(
      websocketUri: Uri.parse('ws://127.0.0.1:7337/ws'),
    ),
    // `connected` requires an API, so only online hosts get one.
    api: status == HostRuntimeStatus.online ? api ?? FakeTinestApi() : null,
  );

  Future<void> pump(
    WidgetTester tester, {
    required List<HostRuntimeSnapshot> hosts,
    required Map<String, WorkspaceCatalogDto> catalogs,
    ValueChanged<WorkspaceSelection>? onSelect,
    WorkspaceSelection? selected,
    TRTreeNavController<WorkspaceNavValue>? treeController,
    void Function(WorkspaceSelection selection, String sessionId)?
    onSelectSession,
    List<HomeSessionEntry> homeSessions = const <HomeSessionEntry>[],
    ThemeMode themeMode = ThemeMode.light,
    Set<String> refreshingHostIds = const <String>{},
    Map<String, Object> catalogErrors = const <String, Object>{},
    bool settle = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: testLightTheme,
          darkTheme: testDarkTheme,
          themeMode: themeMode,
          locale: testLocale,
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: Scaffold(
            body: WorkspaceSidebar(
              hosts: <String, HostRuntimeSnapshot>{
                for (final item in hosts) item.id: item,
              },
              catalog: AsyncValue<UnifiedWorkspaceCatalogState>.data(
                UnifiedWorkspaceCatalogState(
                  hosts: <String, HostRuntimeSnapshot>{
                    for (final item in hosts) item.id: item,
                  },
                  catalogs: catalogs,
                  refreshingHostIds: refreshingHostIds,
                  errors: catalogErrors,
                ),
              ),
              homeSessions: AsyncValue<List<HomeSessionEntry>>.data(
                homeSessions,
              ),
              selected: selected,
              treeController:
                  treeController ?? TRTreeNavController<WorkspaceNavValue>(),
              onNewWorkspace: () {},
              onSelect: onSelect ?? (_) {},
              onSelectSession: onSelectSession ?? (_, _) {},
              onOpenDaemonSettings: () {},
              onConnectDaemon: () {},
              onArchivedSelection: () {},
            ),
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('selecting a worktree expands its collapsed workspace', (
    tester,
  ) async {
    final first = workspace('first', 'First');
    final second = workspace('second', 'Second');
    final checkout = worktree('first-main', first.id, 'main');
    final runtime = host('server', 'Server');
    final controller = TRTreeNavController<WorkspaceNavValue>();
    addTearDown(controller.dispose);

    await pump(
      tester,
      hosts: <HostRuntimeSnapshot>[runtime],
      catalogs: <String, WorkspaceCatalogDto>{
        runtime.id: WorkspaceCatalogDto(
          workspaces: <WorkspaceDto>[first, second],
          worktrees: <WorktreeDto>[checkout],
        ),
      },
      treeController: controller,
    );
    expect(find.text('main'), findsNothing);

    await pump(
      tester,
      hosts: <HostRuntimeSnapshot>[runtime],
      catalogs: <String, WorkspaceCatalogDto>{
        runtime.id: WorkspaceCatalogDto(
          workspaces: <WorkspaceDto>[first, second],
          worktrees: <WorktreeDto>[checkout],
        ),
      },
      selected: WorkspaceSelection(
        hostId: runtime.id,
        workspaceId: first.id,
        worktreeId: checkout.id,
      ),
      treeController: controller,
    );

    expect(find.text('main'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('workspace-worktree-first-main')),
      findsOneWidget,
    );
    expect(
      controller.expanded,
      contains((hostId: runtime.id, workspaceId: first.id, worktreeId: null)),
    );
  });

  testWidgets(
    'New Workspace separator matches the title bar border in light and dark '
    'themes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final themeMode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
        await pump(
          tester,
          hosts: const <HostRuntimeSnapshot>[],
          catalogs: const <String, WorkspaceCatalogDto>{},
          themeMode: themeMode,
        );

        final separator = find.byType(TRSeparator);
        expect(separator, findsOneWidget);
        final line = find.descendant(
          of: separator,
          matching: find.byType(ColoredBox),
        );
        expect(line, findsOneWidget);
        expect(
          tester.widget<ColoredBox>(line).color,
          tester.element(separator).tinyrackTheme.border,
          reason: '${themeMode.name} sidebar and title bar borders must match',
        );
      }
    },
  );

  testWidgets(
    'workspaces from every daemon share one flat list sorted by name',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final zed = workspace('zed', 'Zed');
      final alpha = workspace('alpha', 'Alpha');
      await pump(
        tester,
        hosts: <HostRuntimeSnapshot>[
          host('first', 'First daemon'),
          host('second', 'Second daemon'),
        ],
        catalogs: <String, WorkspaceCatalogDto>{
          'first': WorkspaceCatalogDto(
            workspaces: <WorkspaceDto>[zed],
            worktrees: <WorktreeDto>[worktree('zed-main', zed.id, 'main')],
          ),
          'second': WorkspaceCatalogDto(
            workspaces: <WorkspaceDto>[alpha],
            worktrees: <WorktreeDto>[worktree('alpha-main', alpha.id, 'main')],
          ),
        },
      );

      // No daemon tree level: each daemon only names its workspace's subtitle.
      expect(find.text('First daemon'), findsNothing);
      expect(find.text('Second daemon · /repos/alpha'), findsOneWidget);
      expect(find.text('First daemon · /repos/zed'), findsOneWidget);
      final tree = find.byKey(
        const ValueKey<String>('workspace-sidebar-tree'),
      );
      expect(tree, findsOneWidget);
      expect(find.byType(TRCollapsible), findsNothing);
      final names = tester
          .widgetList<Text>(
            find.descendant(of: tree, matching: find.byType(Text)),
          )
          .map((text) => text.data)
          .where((data) => data == 'Alpha' || data == 'Zed')
          .toList(growable: false);
      expect(names, <String>['Alpha', 'Zed']);
      expect(find.text('main'), findsNothing);
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      expect(find.text('main'), findsOneWidget);
    },
    tags: const <String>['feature_test__workspace_catalog__widget'],
  );

  testWidgets(
    'tree navigation expands workspaces and selects typed worktrees',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final project = workspace('project', 'Project');
      WorkspaceSelection? selection;
      await pump(
        tester,
        hosts: <HostRuntimeSnapshot>[host('up', 'Up daemon')],
        catalogs: <String, WorkspaceCatalogDto>{
          'up': WorkspaceCatalogDto(
            workspaces: <WorkspaceDto>[project],
            worktrees: <WorktreeDto>[
              worktree('project-main', project.id, 'main'),
            ],
          ),
        },
        onSelect: (value) => selection = value,
      );

      expect(
        find.byKey(const ValueKey<String>('workspace-sidebar-tree')),
        findsOneWidget,
      );
      await tester.tap(find.text('main'));
      await tester.pumpAndSettle();
      expect(
        selection,
        const WorkspaceSelection(
          hostId: 'up',
          workspaceId: 'project',
          worktreeId: 'project-main',
        ),
      );
    },
    tags: const <String>['feature_test__workspace_catalog__widget'],
  );

  testWidgets(
    'sessions with no project list above the tree and hide the home workspace',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final project = workspace('project', 'Project');
      final home = WorkspaceDto(
        id: 'home',
        name: 'user',
        rootPath: '/home/user',
        kind: WorkspaceKind.home,
        createdAt: now,
      );
      const homeSelection = WorkspaceSelection(
        hostId: 'up',
        workspaceId: 'home',
        worktreeId: 'home-checkout',
      );
      WorkspaceSelection? selectedSelection;
      String? selectedSession;
      await pump(
        tester,
        hosts: <HostRuntimeSnapshot>[host('up', 'Up daemon')],
        catalogs: <String, WorkspaceCatalogDto>{
          'up': WorkspaceCatalogDto(
            workspaces: <WorkspaceDto>[project, home],
            worktrees: <WorktreeDto>[
              worktree('project-main', project.id, 'main'),
              WorktreeDto(
                id: 'home-checkout',
                workspaceId: home.id,
                name: home.name,
                path: home.rootPath,
                kind: WorktreeKind.directory,
                isTinestOwned: false,
                createdAt: now,
              ),
            ],
          ),
        },
        homeSessions: <HomeSessionEntry>[
          (
            selection: homeSelection,
            session: SessionDto(
              id: 'loose-session',
              worktreeId: 'home-checkout',
              title: 'Scratch work',
              agentDefinitionId: 'tinest',
              origin: SessionOrigin.manual,
              status: SessionStatus.idle,
              model: const ModelSelectionDto(
                modelId: 'openai/gpt-5.6-sol',
              ),
              createdAt: now,
              updatedAt: now,
            ),
          ),
        ],
        onSelectSession: (selection, sessionId) {
          selectedSelection = selection;
          selectedSession = sessionId;
        },
      );

      // The home workspace backs these sessions but is not a project, so it
      // must never appear as one.
      expect(find.text('user'), findsNothing);
      expect(find.text('Project'), findsOneWidget);
      expect(find.text('Scratch work'), findsOneWidget);

      await tester.tap(find.text('Scratch work'));
      await tester.pumpAndSettle();
      expect(selectedSelection, homeSelection);
      expect(selectedSession, 'loose-session');
    },
    tags: const <String>['feature_test__session_home__widget'],
  );

  testWidgets(
    'the no-project section is absent when every session has one',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final project = workspace('project', 'Project');
      await pump(
        tester,
        hosts: <HostRuntimeSnapshot>[host('up', 'Up daemon')],
        catalogs: <String, WorkspaceCatalogDto>{
          'up': WorkspaceCatalogDto(
            workspaces: <WorkspaceDto>[project],
            worktrees: <WorktreeDto>[
              worktree('project-main', project.id, 'main'),
            ],
          ),
        },
      );

      expect(
        find.byKey(const ValueKey<String>('workspace-sidebar-home-sessions')),
        findsNothing,
      );
    },
    tags: const <String>['feature_test__session_home__widget'],
  );

  testWidgets(
    'workspace menu confirms and unregisters the repository',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final project = workspace('project', 'Project');
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[project],
        worktrees: <WorktreeDto>[
          worktree('project-main', project.id, 'main'),
        ],
      );
      await pump(
        tester,
        hosts: <HostRuntimeSnapshot>[host('up', 'Up daemon', api: api)],
        catalogs: <String, WorkspaceCatalogDto>{
          'up': WorkspaceCatalogDto(
            workspaces: <WorkspaceDto>[project],
            worktrees: <WorktreeDto>[
              worktree('project-main', project.id, 'main'),
              linkedWorktree('project-topic', project.id, 'topic'),
            ],
          ),
        },
      );

      // Both row menus stand where a TRIconButton would, so a text trigger's
      // inline padding would leave them the one wide control in the sidebar.
      final square = Size.square(TRControlMetrics.heightOf(TRUiSize.md));
      for (final key in const <String>[
        'workspace-menu-project',
        'worktree-menu-project-topic',
      ]) {
        expect(
          tester.getSize(find.byKey(ValueKey<String>(key))),
          square,
          reason: key,
        );
      }

      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-menu-project')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-unregister-project')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-unregister-confirm')),
      );
      await tester.pumpAndSettle();

      expect((await api.workspaces.getWorkspaceCatalog()).workspaces, isEmpty);
    },
    tags: const <String>['feature_test__workspace_registration__widget'],
  );

  testWidgets(
    'the tree lists every worktree and offers archive on the linked ones',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final project = workspace('project', 'Project');
      final worktrees = <WorktreeDto>[
        worktree('project-main', project.id, 'main'),
        linkedWorktree('project-ours', project.id, 'ours'),
        linkedWorktree(
          'project-theirs',
          project.id,
          'theirs',
          isTinestOwned: false,
        ),
      ];
      final controller = TRTreeNavController<WorkspaceNavValue>();
      addTearDown(controller.dispose);

      await pump(
        tester,
        hosts: <HostRuntimeSnapshot>[host('up', 'Up daemon')],
        catalogs: <String, WorkspaceCatalogDto>{
          'up': WorkspaceCatalogDto(
            workspaces: <WorkspaceDto>[project],
            worktrees: worktrees,
          ),
        },
        selected: WorkspaceSelection(
          hostId: 'up',
          workspaceId: project.id,
          worktreeId: 'project-main',
        ),
        treeController: controller,
      );

      // The new-workspace composer offers only Local and New worktree. The
      // tree is where an existing checkout is picked, so it must keep showing
      // every one of them regardless of who created it.
      for (final item in worktrees) {
        expect(
          find.byKey(ValueKey<String>('workspace-worktree-${item.id}')),
          findsOneWidget,
          reason: item.id,
        );
      }
      // Ownership decides whether the directory can be removed, not whether
      // the checkout can be archived, so both linked rows offer the menu.
      for (final id in const <String>['project-ours', 'project-theirs']) {
        expect(
          find.byKey(ValueKey<String>('worktree-menu-$id')),
          findsOneWidget,
          reason: id,
        );
      }
      expect(
        find.byKey(const ValueKey<String>('worktree-menu-project-main')),
        findsNothing,
      );
    },
    tags: const <String>['feature_test__workspace_catalog__widget'],
  );

  // The row paints its own background and focus ring, so both are read off the
  // AnimatedContainer that wraps the row content.
  AnimatedContainer rowSurface(WidgetTester tester, String label) =>
      tester.widget<AnimatedContainer>(
        find
            .ancestor(
              of: find.text(label),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );

  Color? rowBackground(WidgetTester tester, String label) =>
      (rowSurface(tester, label).decoration! as BoxDecoration).color;

  // The ring always sits in the tree so that showing it never restructures the
  // row; an unfocused row draws it transparent.
  Color rowFocusRing(WidgetTester tester, String label) =>
      ((rowSurface(tester, label).foregroundDecoration! as BoxDecoration)
                  .border!
              as Border)
          .top
          .color;

  Future<TestGesture> clickWithMouse(
    WidgetTester tester,
    Finder target, {
    TestGesture? reuse,
  }) async {
    final gesture =
        reuse ?? await tester.createGesture(kind: PointerDeviceKind.mouse);
    if (reuse == null) {
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
    }
    // A real pointer hovers the row before it presses, and frames render while
    // the button is held. That is the state the reported defect appears in.
    await gesture.moveTo(tester.getCenter(target));
    await tester.pumpAndSettle();
    await gesture.down(tester.getCenter(target));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    return gesture;
  }

  Future<void> pumpProject(WidgetTester tester) async {
    final project = workspace('project', 'Project');
    await pump(
      tester,
      hosts: <HostRuntimeSnapshot>[host('up', 'Up daemon')],
      catalogs: <String, WorkspaceCatalogDto>{
        'up': WorkspaceCatalogDto(
          workspaces: <WorkspaceDto>[project],
          worktrees: <WorktreeDto>[
            worktree('project-main', project.id, 'main'),
            linkedWorktree('project-topic', project.id, 'topic'),
          ],
        ),
      },
    );
  }

  testWidgets(
    'only worktrees the daemon can archive carry a row menu',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpProject(tester);

      // Archiving the workspace root would hide the project without removing
      // anything, so that row offers no menu at all.
      expect(
        find.byKey(const ValueKey<String>('worktree-menu-project-main')),
        findsNothing,
      );
      await clickWithMouse(
        tester,
        find.byKey(const ValueKey<String>('worktree-menu-project-topic')),
      );
      expect(find.text(testL10n.workspaceArchive), findsOneWidget);
    },
    tags: const <String>['feature_test__worktree_lifecycle__widget'],
  );

  testWidgets(
    'archive safety inspection opens immediate progress before Git answers',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final project = workspace('project', 'Project');
      final gate = Completer<void>();
      final api = FakeTinestApi(previewArchiveGate: gate);
      await pump(
        tester,
        hosts: <HostRuntimeSnapshot>[host('up', 'Up daemon', api: api)],
        catalogs: <String, WorkspaceCatalogDto>{
          'up': WorkspaceCatalogDto(
            workspaces: <WorkspaceDto>[project],
            worktrees: <WorktreeDto>[
              worktree('project-main', project.id, 'main'),
              linkedWorktree('project-topic', project.id, 'topic'),
            ],
          ),
        },
      );

      await clickWithMouse(
        tester,
        find.byKey(const ValueKey<String>('worktree-menu-project-topic')),
      );
      await tester.tap(find.text(testL10n.workspaceArchive));
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('worktree-archive-checking')),
        findsOneWidget,
      );
      expect(find.byType(TRSpinner), findsOneWidget);
      final progressSemantics = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byKey(
                const ValueKey<String>('worktree-archive-checking'),
              ),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(progressSemantics.properties.label, '워크트리 확인 중…');

      gate.complete();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('worktree-archive-confirm')),
        findsOneWidget,
      );
    },
    tags: const <String>[
      'feature_test__workspace_async_loading__widget',
      'feature_test__worktree_lifecycle__widget',
    ],
  );

  testWidgets(
    'archive inspection failure stays in the dialog and retries',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final project = workspace('project', 'Project');
      final api = FakeTinestApi(
        previewArchiveError: Exception('git status failed'),
      );
      await pump(
        tester,
        hosts: <HostRuntimeSnapshot>[host('up', 'Up daemon', api: api)],
        catalogs: <String, WorkspaceCatalogDto>{
          'up': WorkspaceCatalogDto(
            workspaces: <WorkspaceDto>[project],
            worktrees: <WorktreeDto>[
              worktree('project-main', project.id, 'main'),
              linkedWorktree('project-topic', project.id, 'topic'),
            ],
          ),
        },
      );

      await clickWithMouse(
        tester,
        find.byKey(const ValueKey<String>('worktree-menu-project-topic')),
      );
      await tester.tap(find.text(testL10n.workspaceArchive));
      await tester.pumpAndSettle();
      expect(find.text(testL10n.workspaceArchiveFailed), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('worktree-archive-retry')),
        findsOneWidget,
      );

      api.previewArchiveError = null;
      await tester.tap(
        find.byKey(const ValueKey<String>('worktree-archive-retry')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('worktree-archive-confirm')),
        findsOneWidget,
      );
    },
    tags: const <String>[
      'feature_test__workspace_async_loading__widget',
      'feature_test__worktree_lifecycle__widget',
    ],
  );

  testWidgets(
    'a catalog refresh keeps the loaded tree and shows non-blocking progress',
    (tester) async {
      final project = workspace('project', 'Project');
      await pump(
        tester,
        hosts: <HostRuntimeSnapshot>[host('up', 'Up daemon')],
        catalogs: <String, WorkspaceCatalogDto>{
          'up': WorkspaceCatalogDto(
            workspaces: <WorkspaceDto>[project],
            worktrees: <WorktreeDto>[
              worktree('project-main', project.id, 'main'),
            ],
          ),
        },
        refreshingHostIds: const <String>{'up'},
        settle: false,
      );

      expect(find.text('Project'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('workspace-catalog-refreshing-up'),
        ),
        findsOneWidget,
      );
      expect(find.byType(TRSpinner), findsOneWidget);
      expect(find.bySemanticsLabel('워크스페이스 목록 새로고침 중…'), findsOne);
    },
    tags: const <String>[
      'feature_test__workspace_async_loading__widget',
      'feature_test__workspace_catalog__widget',
    ],
  );

  testWidgets(
    'a catalog failure remains inline with an explicit retry action',
    (tester) async {
      await pump(
        tester,
        hosts: <HostRuntimeSnapshot>[host('up', 'Up daemon')],
        catalogs: const <String, WorkspaceCatalogDto>{},
        catalogErrors: <String, Object>{'up': Exception('git failed')},
      );

      expect(
        find.byKey(const ValueKey<String>('workspace-catalog-error-up')),
        findsOneWidget,
      );
      expect(find.text('워크스페이스 목록을 불러오지 못했습니다'), findsOne);
      expect(find.widgetWithText(TRButton, '다시 시도'), findsOneWidget);
      expect(find.text(testL10n.workspaceNoWorkspaces), findsNothing);
    },
    tags: const <String>[
      'feature_test__workspace_async_loading__widget',
      'feature_test__workspace_catalog__widget',
    ],
  );

  testWidgets(
    'a row menu opens on a single pointer press',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpProject(tester);

      await clickWithMouse(
        tester,
        find.byKey(const ValueKey<String>('workspace-menu-project')),
      );

      expect(find.text(testL10n.workspaceUnregister), findsOneWidget);
    },
    tags: const <String>['feature_test__workspace_registration__widget'],
  );

  testWidgets(
    'a row menu opens on the first press while another row menu is open',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpProject(tester);

      // The checkout menu opens downwards, which leaves the project trigger
      // above it uncovered.
      final mouse = await clickWithMouse(
        tester,
        find.byKey(const ValueKey<String>('worktree-menu-project-topic')),
      );
      expect(find.text(testL10n.workspaceArchive), findsOneWidget);

      // Moving from one row menu to the next is one press: the open menu
      // closes and the pressed one opens.
      await clickWithMouse(
        tester,
        find.byKey(const ValueKey<String>('workspace-menu-project')),
        reuse: mouse,
      );
      expect(find.text(testL10n.workspaceArchive), findsNothing);
      expect(find.text(testL10n.workspaceUnregister), findsOneWidget);
    },
    tags: const <String>['feature_test__workspace_registration__widget'],
  );

  testWidgets(
    'a row menu leaves no focus ring or background on its row',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpProject(tester);

      final idleGroupBackground = rowBackground(tester, 'Project');

      final mouse = await clickWithMouse(
        tester,
        find.byKey(const ValueKey<String>('workspace-menu-project')),
      );

      // The trigger owns the focus ring; the row that hosts it does not.
      expect(rowFocusRing(tester, 'Project'), Colors.transparent);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      // Leaving the row drops the hover surface with nothing else holding it.
      await mouse.moveTo(const Offset(1, 700));
      await tester.pumpAndSettle();

      expect(rowFocusRing(tester, 'Project'), Colors.transparent);
      expect(rowBackground(tester, 'Project'), idleGroupBackground);
    },
    tags: const <String>['feature_test__workspace_registration__widget'],
  );

  testWidgets(
    'an unhovered workspace row keeps a transparent background',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpProject(tester);

      // Only a hovered row, or a selected checkout, is filled. A workspace has
      // no selected state of its own.
      expect(rowBackground(tester, 'Project'), Colors.transparent);

      await clickWithMouse(
        tester,
        find.byKey(const ValueKey<String>('worktree-menu-project-topic')),
      );

      expect(rowBackground(tester, 'Project'), Colors.transparent);
    },
    tags: const <String>['feature_test__workspace_registration__widget'],
  );

  testWidgets(
    'a disconnected daemon drops out of the sidebar entirely',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final online = workspace('online', 'Online repo');
      final stale = workspace('stale', 'Stale repo');
      await pump(
        tester,
        hosts: <HostRuntimeSnapshot>[
          host('up', 'Up daemon'),
          host('down', 'Down daemon', status: HostRuntimeStatus.offline),
        ],
        catalogs: <String, WorkspaceCatalogDto>{
          'up': WorkspaceCatalogDto(
            workspaces: <WorkspaceDto>[online],
            worktrees: <WorktreeDto>[
              worktree('online-main', online.id, 'main'),
            ],
          ),
          // A stale catalog from before the daemon dropped must not leak.
          'down': WorkspaceCatalogDto(
            workspaces: <WorkspaceDto>[stale],
            worktrees: <WorktreeDto>[worktree('stale-main', stale.id, 'main')],
          ),
        },
      );

      expect(find.text('Online repo'), findsOneWidget);
      expect(find.text('Stale repo'), findsNothing);
      expect(find.text('Down daemon'), findsNothing);
      expect(find.text(testL10n.hostStatusOffline), findsNothing);
    },
    tags: const <String>['feature_test__workspace_catalog__widget'],
  );

  testWidgets(
    'the sidebar explains when every configured daemon is offline',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pump(
        tester,
        hosts: <HostRuntimeSnapshot>[
          host('down', 'Down daemon', status: HostRuntimeStatus.offline),
        ],
        catalogs: const <String, WorkspaceCatalogDto>{},
      );

      expect(find.text(testL10n.workspaceNoConnectedDaemons), findsOneWidget);
      expect(find.text(testL10n.workspaceOpenDaemonSettings), findsOneWidget);
    },
    tags: const <String>['feature_test__workspace_catalog__widget'],
  );

  testWidgets(
    'a connected daemon without workspaces shows the empty workspace state',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pump(
        tester,
        hosts: <HostRuntimeSnapshot>[host('up', 'Up daemon')],
        catalogs: const <String, WorkspaceCatalogDto>{
          'up': WorkspaceCatalogDto(
            workspaces: <WorkspaceDto>[],
            worktrees: <WorktreeDto>[],
          ),
        },
      );

      expect(find.text(testL10n.workspaceNoWorkspaces), findsOneWidget);
      // Daemon settings are not what the user needs here.
      expect(find.text(testL10n.workspaceOpenDaemonSettings), findsNothing);
    },
    tags: const <String>['feature_test__workspace_catalog__widget'],
  );
}
