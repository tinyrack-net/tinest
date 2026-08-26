@Tags(<String>['feature_test__agent_collaboration__widget'])
library;

import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/features/conversation/presentation/chat_approval_card.dart';
import 'package:app/src/features/conversation/presentation/chat_timeline_view.dart';
import 'package:app/src/features/conversation/presentation/widgets/session_composer.dart';
import 'package:app/src/shared/presentation/tinest_icons.dart';
import 'package:app/src/shared/presentation/tinest_list_row.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/fake_tinest_api.dart';
import '../../support/router_harness.dart';

void main() {
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

  SessionDto root(String id) => SessionDto(
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

  SessionDto subagent(
    String id, {
    required String parentId,
    required String taskName,
    required String agentPath,
    String rootId = 'main-session',
    AgentLifecycle lifecycle = AgentLifecycle.running,
    DateTime? createdAt,
    SessionStatus status = SessionStatus.running,
  }) => SessionDto(
    id: id,
    worktreeId: checkout.id,
    title: taskName,
    agentDefinitionId: 'tinest',
    origin: SessionOrigin.delegated,
    status: status,
    parentSessionId: parentId,
    taskName: taskName,
    agentPath: agentPath,
    rootSessionId: rootId,
    lifecycle: lifecycle,
    model: const ModelSelectionDto(modelId: 'openai/gpt-5.6-sol'),
    createdAt: createdAt ?? now,
    updatedAt: createdAt ?? now,
  );

  String sessionLocation(String sessionId) => SessionRoute(
    hostId: 'server',
    workspaceId: workspace.id,
    worktreeId: checkout.id,
    sessionId: sessionId,
  ).location;

  // The drawer is drawn by the collaboration plugin now, so this layer stops
  // at the contract between them: given the document the plugin sends, the app
  // frames it on the composer, resolves the status words it states, opens the
  // session an item names, and asks for a new document when the tree moves.
  // Whether the plugin counts the tree correctly is pinned in the daemon.
  const drawerAgent = AgentDefinitionDto(
    version: 5,
    id: 'tinest',
    name: 'Tinest',
    description: 'General-purpose coding agent',
    mode: AgentMode.primary,
    model: AgentModelSelectionDto(source: AgentModelSource.session),
    driverId: 'tinest.standard/driver',
    extensionIds: <String>['tinest.collaboration'],
    toolIds: <String>[],
    pluginSettings: <String, Map<String, dynamic>>{},
    callableAgentIds: <String>[],
    prompt: 'Code carefully.',
    contentHash: 'tinest-hash',
    sourcePath: '/config/agents/tinest.md',
    isBuiltIn: true,
  );
  const drawerPlugin = PluginDescriptorDto(
    apiMajor: 5,
    id: 'tinest.collaboration',
    version: '1.0.0',
    name: 'Tinest Collaboration',
    entrypoint: 'main.lua',
    source: PluginSource.builtIn,
    sourcePath: '/built-in/tinest.collaboration',
    requestedCapabilities: <String>['collaboration.list', 'ui.publish'],
    contributions: <PluginContributionDto>[
      PluginContributionDto(
        pluginId: 'tinest.collaboration',
        id: 'agent_status',
        kind: PluginContributionKind.ui,
        metadata: <String, dynamic>{
          'slots': <String>['composerDrawer'],
          'dependsOn': <String>['session_tree'],
        },
      ),
    ],
  );
  const drawerKey = 'tinest.collaboration/agent_status/tinest';

  /// Builds the document the collaboration plugin sends for one tree.
  PluginUiDocumentDto drawerDocument({
    required String title,
    required List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> summary = const <Map<String, dynamic>>[],
  }) => PluginUiDocumentDto(
    id: 'drawer-$title-${summary.length}-${items.length}',
    pluginId: 'tinest.collaboration',
    revisionHash: 'revision',
    slot: PluginUiSlot.composerDrawer,
    root: <String, dynamic>{
      'type': 'disclosure',
      'title': title,
      'summary': summary,
      'children': <Map<String, dynamic>>[
        <String, dynamic>{'type': 'tree', 'children': items},
      ],
    },
  );

  Map<String, dynamic> drawerItem({
    required String label,
    required String description,
    required String status,
    required String sessionId,
    List<Map<String, dynamic>> children = const <Map<String, dynamic>>[],
  }) => <String, dynamic>{
    'type': 'tree_item',
    'label': label,
    'description': description,
    'status': status,
    'onActivate': <String, dynamic>{
      'type': 'open_session',
      'sessionId': sessionId,
    },
    'children': children,
  };

  Map<String, dynamic> drawerBadge(String text, String variant) =>
      <String, dynamic>{'type': 'badge', 'text': text, 'variant': variant};

  testWidgets(
    'the drawer lists nested subagents and opens a read-only tab',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        agentDefinitions: const <AgentDefinitionDto>[drawerAgent],
        plugins: const <PluginDescriptorDto>[drawerPlugin],
        pluginUiDocuments: <String, PluginUiDocumentDto>{
          drawerKey: drawerDocument(
            title: '서브 에이전트 2개',
            summary: <Map<String, dynamic>>[drawerBadge('1개 실행 중', 'info')],
            items: <Map<String, dynamic>>[
              drawerItem(
                label: 'explore_auth',
                description: '/root/explore_auth',
                status: 'running',
                sessionId: 'child-a',
                children: <Map<String, dynamic>>[
                  drawerItem(
                    label: 'read_docs',
                    description: '/root/explore_auth/read_docs',
                    status: 'done',
                    sessionId: 'grandchild',
                  ),
                ],
              ),
            ],
          ),
        },
        agents: <SessionDto>[
          root('main-session'),
          subagent(
            'child-a',
            parentId: 'main-session',
            taskName: 'explore_auth',
            agentPath: '/root/explore_auth',
          ),
          subagent(
            'grandchild',
            parentId: 'child-a',
            taskName: 'read_docs',
            agentPath: '/root/explore_auth/read_docs',
            lifecycle: AgentLifecycle.completed,
            createdAt: now.add(const Duration(seconds: 1)),
          ),
        ],
      );
      final router = await pumpRoutedApp(
        tester,
        api,
        initialLocation: sessionLocation('main-session'),
        settle: false,
      );
      addTearDown(router.dispose);
      await tester.pump(const Duration(seconds: 1));

      // Collapsed by default: the summary speaks, the rows stay hidden.
      expect(find.text('서브 에이전트 2개'), findsOneWidget);
      expect(find.text('1개 실행 중'), findsOneWidget);
      expect(find.text('/root/explore_auth'), findsNothing);

      // Expanding lists every descendant, nested ones included. A running
      // row keeps a spinner animating, so settle-style pumps would never
      // finish; fixed pumps are used from here on.
      await tester.tap(find.text('서브 에이전트 2개'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('explore_auth'), findsOneWidget);
      expect(find.text('/root/explore_auth/read_docs'), findsOneWidget);

      // Subagents never appear in the all-sessions menu.
      await tester.tap(
        find.byKey(const ValueKey('workspace-all-sessions-menu')),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Session main-session'), findsWidgets);
      // The expanded drawer behind the menu still shows the row text, so the
      // absence check is scoped to menu items.
      expect(
        find.widgetWithText(TRMenuItem, 'read_docs'),
        findsNothing,
      );
      expect(
        find.widgetWithText(TRMenuItem, 'explore_auth'),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('workspace-all-sessions-menu')),
      );
      await tester.pump(const Duration(seconds: 1));

      // Activating a row asks the host to open that session, and the host
      // agrees because it is a descendant of the session the drawer sits on.
      await tester.tap(find.text('explore_auth'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(currentLocation(router), sessionLocation('child-a'));
      expect(
        find.byKey(const ValueKey('tr-tabs-close-child-a')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'an expanded four-agent drawer fits above the composer in a short pane',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1129, 453));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final children = <SessionDto>[
        subagent(
          'child-apps',
          parentId: 'main-session',
          taskName: 'investigate_apps',
          agentPath: '/root/investigate_apps',
        ),
        subagent(
          'child-games',
          parentId: 'main-session',
          taskName: 'investigate_game_packages',
          agentPath: '/root/investigate_game_packages',
        ),
        subagent(
          'child-root',
          parentId: 'main-session',
          taskName: 'investigate_root',
          agentPath: '/root/investigate_root',
        ),
        subagent(
          'child-tests',
          parentId: 'main-session',
          taskName: 'investigate_tests',
          agentPath: '/root/investigate_tests',
        ),
      ];
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        agentDefinitions: const <AgentDefinitionDto>[drawerAgent],
        plugins: const <PluginDescriptorDto>[drawerPlugin],
        pluginUiDocuments: <String, PluginUiDocumentDto>{
          drawerKey: drawerDocument(
            title: '4 subagents',
            summary: <Map<String, dynamic>>[
              drawerBadge('4 running', 'info'),
            ],
            items: <Map<String, dynamic>>[
              for (final child in children)
                drawerItem(
                  label: child.taskName!,
                  description: child.agentPath!,
                  status: 'running',
                  sessionId: child.id,
                ),
            ],
          ),
        },
        agents: <SessionDto>[root('main-session'), ...children],
        timelines: <String, List<TimelineEventDto>>{
          'main-session': <TimelineEventDto>[
            TimelineEventDto(
              sessionId: 'main-session',
              sequence: 1,
              turnId: 'turn-1',
              type: 'user.message',
              data: const <String, dynamic>{
                'text': 'Investigate the workspace in parallel.',
              },
              createdAt: now,
            ),
          ],
        },
      );
      final router = await pumpRoutedApp(
        tester,
        api,
        initialLocation: sessionLocation('main-session'),
        settle: false,
      );
      addTearDown(router.dispose);
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('4 subagents'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final pane = find.byKey(
        const ValueKey<String>('conversation-pane-session:main-session'),
      );
      final timeline = find.byType(ChatTimelineView);
      final composer = find.byType(SessionComposer);
      final drawer = find.byKey(
        const ValueKey<String>('agent-plugin-ui-composerDrawer'),
      );
      final drawerScrollArea = find.descendant(
        of: drawer,
        matching: find.byType(TRScrollArea),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(timeline).height, greaterThan(0));
      final paneRect = tester.getRect(pane);
      final composerRect = tester.getRect(composer);
      expect(composerRect.left, greaterThanOrEqualTo(paneRect.left));
      expect(composerRect.right, lessThanOrEqualTo(paneRect.right));
      expect(composerRect.bottom, lessThanOrEqualTo(paneRect.bottom));
      expect(drawerScrollArea, findsOneWidget);

      final lastPath = find.text('/root/investigate_tests');
      await tester.ensureVisible(lastPath);
      await tester.pump();
      expect(
        tester
            .getRect(drawerScrollArea)
            .contains(tester.getRect(lastPath).center),
        isTrue,
      );
      await tester.tap(find.text('investigate_tests'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(currentLocation(router), sessionLocation('child-tests'));
    },
  );

  testWidgets(
    'a subagent tab is a live read-only transcript without a composer',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final child = subagent(
        'child-a',
        parentId: 'main-session',
        taskName: 'explore_auth',
        agentPath: '/root/explore_auth',
      );
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        agents: <SessionDto>[root('main-session'), child],
      );
      final router = await pumpRoutedApp(
        tester,
        api,
        initialLocation: sessionLocation('child-a'),
        settle: false,
      );
      addTearDown(router.dispose);

      // Read-only chrome: the tab names the task and carries the status icon,
      // and the pane offers no composer and no subagent track.
      expect(find.text('explore_auth'), findsWidgets);
      expect(find.byType(SessionComposer), findsNothing);
      expect(
        find.byKey(const ValueKey('agent-plugin-ui-composerDrawer')),
        findsNothing,
      );
      expect(find.byType(TRSpinner), findsWidgets);

      // Read-only means the user cannot talk to the subagent, not that the
      // subagent is unreachable. Its approvals are the one thing only a human
      // can answer, and hiding them parks the child's turn forever.
      api.emit(
        ApprovalRequestedClientEvent(
          ApprovalRequestDto(
            id: 'approval',
            sessionId: 'child-a',
            turnId: 'turn-1',
            toolCallId: 'call',
            toolName: 'apply_patch',
            risk: ToolRisk.write,
            arguments: const <String, dynamic>{'patch': 'x'},
            status: ApprovalStatus.pending,
            createdAt: now,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ApprovalCard), findsOneWidget);
      expect(find.byType(SessionComposer), findsNothing);
      await tester.tap(find.widgetWithText(TRButton, '승인'));
      await tester.pump(const Duration(seconds: 1));
      expect(
        api.approvalDecisions,
        <({String id, bool approved})>[(id: 'approval', approved: true)],
      );

      // The transcript streams live timeline events.
      api.emitTimeline('child-a', 'assistant.delta', <String, dynamic>{
        'text': 'Reading auth module…',
      });
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Reading auth module…'), findsOneWidget);

      // A lifecycle change flips the tab's spinner into a settled icon.
      api.emit(
        SessionUpdatedClientEvent(
          child.copyWith(
            status: SessionStatus.idle,
            lifecycle: AgentLifecycle.completed,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TRSpinner), findsNothing);
      expect(find.byIcon(TinestIcons.success), findsWidgets);
    },
  );

  testWidgets(
    'a subagent waiting for approval is distinguishable from a working one',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final child = subagent(
        'child-a',
        parentId: 'main-session',
        taskName: 'explore_auth',
        agentPath: '/root/explore_auth',
      );
      final documents = <String, PluginUiDocumentDto>{
        drawerKey: drawerDocument(
          title: '서브 에이전트 1개',
          items: <Map<String, dynamic>>[
            drawerItem(
              label: 'explore_auth',
              description: '/root/explore_auth',
              status: 'running',
              sessionId: 'child-a',
            ),
          ],
        ),
      };
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        agentDefinitions: const <AgentDefinitionDto>[drawerAgent],
        plugins: const <PluginDescriptorDto>[drawerPlugin],
        pluginUiDocuments: documents,
        agents: <SessionDto>[root('main-session'), child],
      );
      final router = await pumpRoutedApp(
        tester,
        api,
        initialLocation: sessionLocation('main-session'),
        settle: false,
      );
      addTearDown(router.dispose);
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('서브 에이전트 1개'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final row = find.ancestor(
        of: find.text('explore_auth'),
        matching: find.byType(TinestListRow),
      );
      expect(
        find.descendant(of: row, matching: find.byType(TRSpinner)),
        findsOneWidget,
      );

      // A child blocked on an approval is not making progress; rendering it
      // as a plain spinner hides the one row the user has to act on. The
      // plugin declared the session tree, so the change alone is what makes
      // the host ask for a new document.
      api.pluginUiDocuments[drawerKey] = drawerDocument(
        title: '서브 에이전트 1개',
        items: <Map<String, dynamic>>[
          drawerItem(
            label: 'explore_auth',
            description: '/root/explore_auth',
            status: 'blocked',
            sessionId: 'child-a',
          ),
        ],
      );
      api.emit(
        SessionUpdatedClientEvent(
          child.copyWith(status: SessionStatus.waitingForApproval),
        ),
      );
      // The drawer answers over the RPC, so the new document lands a frame
      // after the tree moved rather than in the same one.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.descendant(of: row, matching: find.byType(TRSpinner)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: row,
          matching: find.byIcon(TinestIcons.approvalPending),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'the collapsed drawer flags descendants that need the user',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final child = subagent(
        'child-a',
        parentId: 'main-session',
        taskName: 'explore_auth',
        agentPath: '/root/explore_auth',
      );
      final documents = <String, PluginUiDocumentDto>{
        drawerKey: drawerDocument(
          title: '서브 에이전트 1개',
          summary: <Map<String, dynamic>>[drawerBadge('1개 실행 중', 'info')],
          items: <Map<String, dynamic>>[
            drawerItem(
              label: 'explore_auth',
              description: '/root/explore_auth',
              status: 'running',
              sessionId: 'child-a',
            ),
          ],
        ),
      };
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        agentDefinitions: const <AgentDefinitionDto>[drawerAgent],
        plugins: const <PluginDescriptorDto>[drawerPlugin],
        pluginUiDocuments: documents,
        agents: <SessionDto>[root('main-session'), child],
      );
      final router = await pumpRoutedApp(
        tester,
        api,
        initialLocation: sessionLocation('main-session'),
        settle: false,
      );
      addTearDown(router.dispose);
      await tester.pump(const Duration(seconds: 1));

      // A working child is summarized as running and nothing else.
      expect(find.text('1개 실행 중'), findsOneWidget);
      expect(find.text('1개 승인 필요'), findsNothing);

      // Once it parks on an approval the collapsed summary has to say so: the
      // rows are hidden by default, so the badge is the only thing between a
      // stuck tree and a user who never looks. The summary rides in the
      // trigger, which is why a collapsed drawer can still carry it.
      api.pluginUiDocuments[drawerKey] = drawerDocument(
        title: '서브 에이전트 1개',
        summary: <Map<String, dynamic>>[drawerBadge('1개 승인 필요', 'warning')],
        items: <Map<String, dynamic>>[
          drawerItem(
            label: 'explore_auth',
            description: '/root/explore_auth',
            status: 'blocked',
            sessionId: 'child-a',
          ),
        ],
      );
      api.emit(
        SessionUpdatedClientEvent(
          child.copyWith(status: SessionStatus.waitingForApproval),
        ),
      );
      // The drawer answers over the RPC, so the new document lands a frame
      // after the tree moved rather than in the same one.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('1개 승인 필요'), findsOneWidget);
      expect(find.text('1개 실행 중'), findsNothing);
    },
  );

  testWidgets(
    'a blocked subagent approval is answerable from the parent',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final child = subagent(
        'child-a',
        parentId: 'main-session',
        taskName: 'explore_auth',
        agentPath: '/root/explore_auth',
        status: SessionStatus.waitingForApproval,
      );
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        agents: <SessionDto>[root('main-session'), child],
      );
      final router = await pumpRoutedApp(
        tester,
        api,
        initialLocation: sessionLocation('main-session'),
        settle: false,
      );
      addTearDown(router.dispose);

      // The request belongs to the child's session, and only the human can
      // answer it. Surfacing it on the parent is what keeps the tree from
      // parking on a card nobody is looking at.
      api.emit(
        ApprovalRequestedClientEvent(
          ApprovalRequestDto(
            id: 'approval',
            sessionId: 'child-a',
            turnId: 'turn-1',
            toolCallId: 'call',
            toolName: 'apply_patch',
            risk: ToolRisk.write,
            arguments: const <String, dynamic>{'patch': 'x'},
            status: ApprovalStatus.pending,
            createdAt: now,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ApprovalCard), findsOneWidget);
      // Named, because the parent runs its own tools and the user has to know
      // which agent is asking.
      expect(find.text('/root/explore_auth'), findsWidgets);

      // The banner is bounded so it cannot squeeze the composer out, so a
      // long request scrolls; the button still has to be reachable from here.
      final approve = find.widgetWithText(TRButton, '승인');
      await tester.ensureVisible(approve);
      await tester.pump();
      await tester.tap(approve);
      await tester.pump(const Duration(seconds: 1));
      expect(
        api.approvalDecisions,
        <({String id, bool approved})>[(id: 'approval', approved: true)],
      );
      // Answering it never navigated away from the parent.
      expect(currentLocation(router), sessionLocation('main-session'));
    },
    tags: const <String>[
      'ui_state__conversation_timeline__subagent_approval_pending__widget',
    ],
  );

  testWidgets('a session tab flags a descendant waiting on the user', (
    tester,
  ) async {
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    addTearDown(
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
    );
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final child = subagent(
      'child-a',
      parentId: 'main-session',
      taskName: 'explore_auth',
      agentPath: '/root/explore_auth',
    );
    final api = FakeTinestApi(
      workspaces: <WorkspaceDto>[workspace],
      worktrees: <WorktreeDto>[checkout],
      agents: <SessionDto>[root('main-session'), child],
    );
    final router = await pumpRoutedApp(
      tester,
      api,
      initialLocation: sessionLocation('main-session'),
      settle: false,
    );
    addTearDown(router.dispose);

    final tabFlag = find.byKey(
      const ValueKey('session-tab-approval-main-session'),
    );
    expect(tabFlag, findsNothing);

    // The tab is the only part of the parent that stays visible from another
    // session, so a tree blocked behind it has to show there too.
    api.emit(
      SessionUpdatedClientEvent(
        child.copyWith(status: SessionStatus.waitingForApproval),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tabFlag, findsOneWidget);
    final colors = TinyrackTheme.dark().extension<TinyrackThemeData>()!;
    expect(
      tester.widget<Icon>(tabFlag).color,
      colors.warningForeground,
      reason: 'An unfilled tab indicator uses the warning foreground role.',
    );
  });

  testWidgets('a session without subagents shows no track', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = FakeTinestApi(
      workspaces: <WorkspaceDto>[workspace],
      worktrees: <WorktreeDto>[checkout],
      agents: <SessionDto>[root('main-session')],
    );
    final router = await pumpRoutedApp(
      tester,
      api,
      initialLocation: sessionLocation('main-session'),
    );
    addTearDown(router.dispose);
    expect(find.byKey(const ValueKey('subagent-track')), findsNothing);
    expect(find.byType(SessionComposer), findsOneWidget);
  });
}
