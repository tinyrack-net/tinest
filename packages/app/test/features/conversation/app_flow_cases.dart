part of '../../app/app_flows_test.dart';

/// A definition the catalog only learns about after the session is on screen.
const _lateAgentDefinition = AgentDefinitionDto(
  version: 5,
  id: 'late',
  name: 'Late',
  description: 'Published after its session opened',
  mode: AgentMode.primary,
  model: AgentModelSelectionDto(source: AgentModelSource.session),
  driverId: 'tinest.standard/driver',
  extensionIds: <String>[],
  toolIds: <String>['tinest.files/read_file'],
  pluginSettings: <String, Map<String, dynamic>>{},
  callableAgentIds: <String>[],
  prompt: 'Code carefully.',
  contentHash: 'late-hash',
  sourcePath: '/config/agents/late.md',
);

void _registerConversationAppFlows() {
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
    'conversation scrollbar spans the pane while its content stays capped',
    (tester) async {
      await _setTestViewport(tester, const Size(1500, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final root = session('layout');
      final child = session('layout-child')
          .copyWith(parentSessionId: root.id, taskName: 'Layout child');
      // The subagent list is a plugin drawer now, so the layout contract this
      // case pins — composer-header content is inset by the composer's own
      // padding at every width — needs a drawer contribution to measure.
      const drawerAgent = AgentDefinitionDto(
        version: 5,
        id: 'tinest',
        name: 'Tinest',
        description: 'General-purpose coding agent',
        mode: AgentMode.primary,
        model: AgentModelSelectionDto(source: AgentModelSource.session),
        driverId: 'tinest.standard/driver',
        extensionIds: <String>['example.drawer'],
        toolIds: <String>[],
        pluginSettings: <String, Map<String, dynamic>>{},
        callableAgentIds: <String>[],
        prompt: 'Code carefully.',
        contentHash: 'tinest-hash',
        sourcePath: '/config/agents/tinest.md',
        isBuiltIn: true,
      );
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        agents: <SessionDto>[root, child],
        agentDefinitions: const <AgentDefinitionDto>[drawerAgent],
        plugins: const <PluginDescriptorDto>[
          PluginDescriptorDto(
            apiMajor: 5,
            id: 'example.drawer',
            version: '1.0.0',
            name: 'Drawer',
            entrypoint: 'main.lua',
            source: PluginSource.user,
            sourcePath: '/config/v5/plugins/example.drawer',
            requestedCapabilities: <String>[],
            contributions: <PluginContributionDto>[
              PluginContributionDto(
                pluginId: 'example.drawer',
                id: 'agents',
                kind: PluginContributionKind.ui,
                metadata: <String, dynamic>{
                  'slots': <String>['composerDrawer'],
                },
              ),
            ],
          ),
        ],
        pluginUiDocuments: const <String, PluginUiDocumentDto>{
          'example.drawer/agents/tinest': PluginUiDocumentDto(
            id: 'drawer-document',
            pluginId: 'example.drawer',
            revisionHash: 'revision',
            slot: PluginUiSlot.composerDrawer,
            root: <String, dynamic>{
              'type': 'disclosure',
              'title': '1 subagent',
              'children': <Map<String, dynamic>>[
                <String, dynamic>{
                  'type': 'tree',
                  'children': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'type': 'tree_item',
                      'label': 'Layout child',
                      'status': 'running',
                    },
                  ],
                },
              ],
            },
          ),
        },
        timelines: <String, List<TimelineEventDto>>{
          root.id: <TimelineEventDto>[
            for (var index = 0; index < 24; index += 1)
              TimelineEventDto(
                sessionId: root.id,
                sequence: index + 1,
                turnId: 'layout-turn-$index',
                type: 'user.message',
                data: <String, dynamic>{
                  'text': 'Layout message $index\nline two\nline three',
                },
                createdAt: now.add(Duration(seconds: index)),
              ),
          ],
        },
      );
      final router = await _pumpRoute(
        tester,
        api,
        SessionRoute(
          hostId: 'server',
          workspaceId: workspace.id,
          worktreeId: checkout.id,
          sessionId: root.id,
        ).location,
      );
      addTearDown(router.dispose);
      await tester.pumpAndSettle();

      final pane = find.byKey(
        ValueKey<String>('conversation-pane-session:${root.id}'),
      );
      final timeline = find.byType(ChatTimelineView);
      final scrollbar = find.descendant(
        of: timeline,
        matching: find.byType(Scrollbar),
      );
      final message = find.byType(ChatUserLine).last;
      final composer = find.byType(SessionComposer);
      final subagents = find.byKey(
        const ValueKey<String>('agent-plugin-ui-composerDrawer'),
      );
      // The pane carries no title header: the tab label already names the
      // session, so the timeline starts flush with the top of the pane.
      expect(
        find.descendant(of: pane, matching: find.byType(TinestListRow)),
        findsNothing,
      );

      final paneRect = tester.getRect(pane);
      final timelineRect = tester.getRect(timeline);
      expect(timelineRect.top, closeTo(paneRect.top, 0.5));
      expect(timelineRect.width, paneRect.width);
      expect(timelineRect.center.dx, closeTo(paneRect.center.dx, 0.5));
      final scrollbarRect = tester.getRect(scrollbar);
      expect(scrollbarRect.width, paneRect.width);
      expect(scrollbarRect.right, closeTo(paneRect.right, 0.5));
      final messageRect = tester.getRect(message);
      expect(
        messageRect.width,
        TinestLayoutMetrics.conversationContentMaxWidth -
            TRSpacing.extraLarge * 2,
      );
      expect(messageRect.center.dx, closeTo(paneRect.center.dx, 0.5));
      for (final content in <Finder>[composer]) {
        final rect = tester.getRect(content);
        expect(rect.width, TinestLayoutMetrics.conversationContentMaxWidth);
        expect(rect.center.dx, closeTo(paneRect.center.dx, 0.5));
      }
      final subagentRect = tester.getRect(subagents);
      expect(
        subagentRect.width,
        TinestLayoutMetrics.conversationContentMaxWidth - TRSpacing.medium * 2,
      );
      expect(subagentRect.center.dx, closeTo(paneRect.center.dx, 0.5));
      expect(
        find.byKey(const ValueKey<String>('session-composer-model')),
        findsOneWidget,
      );

      await _setTestViewport(tester, const Size(599, 900));
      await tester.pumpAndSettle();
      final narrowPane = tester.getRect(pane);
      final narrowTimeline = tester.getRect(timeline);
      expect(narrowTimeline.width, narrowPane.width);
      expect(narrowTimeline.center.dx, closeTo(narrowPane.center.dx, 0.5));
      final narrowScrollbar = tester.getRect(scrollbar);
      expect(narrowScrollbar.width, narrowPane.width);
      expect(narrowScrollbar.right, closeTo(narrowPane.right, 0.5));
      final narrowMessage = tester.getRect(message);
      expect(narrowMessage.width, narrowPane.width - TRSpacing.extraLarge * 2);
      expect(narrowMessage.center.dx, closeTo(narrowPane.center.dx, 0.5));
      for (final content in <Finder>[composer]) {
        final rect = tester.getRect(content);
        expect(rect.width, narrowPane.width);
        expect(rect.center.dx, closeTo(narrowPane.center.dx, 0.5));
      }
      final narrowSubagents = tester.getRect(subagents);
      expect(narrowSubagents.width, narrowPane.width - TRSpacing.medium * 2);
      expect(narrowSubagents.center.dx, closeTo(narrowPane.center.dx, 0.5));
      expect(
        find.byKey(const ValueKey<String>('session-composer-settings')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
    tags: const <String>[
      'feature_test__session_lifecycle__widget',
      'feature_test__turn_execution__widget',
    ],
  );

  testWidgets(
    'a running chat restores permission and reports a daemon save failure',
    (tester) async {
      final running = session('running').copyWith(
        status: SessionStatus.running,
        permissionMode: PermissionMode.ask,
      );
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        agents: <SessionDto>[running],
        sessionPermissionSetError: Exception('daemon rejected update'),
      );
      final router = await _pumpRoute(
        tester,
        api,
        SessionRoute(
          hostId: 'server',
          workspaceId: workspace.id,
          worktreeId: checkout.id,
          sessionId: running.id,
        ).location,
        disableAnimations: true,
      );
      addTearDown(router.dispose);
      await tester.pumpAndSettle();

      await _openComposerSetting(tester, 'permission');
      final fullAccess = find.byKey(
        const ValueKey('permission-option-fullAccess'),
      );
      await tester.ensureVisible(fullAccess);
      await tester.tap(fullAccess);
      await tester.pumpAndSettle();

      expect(find.text('변경 전 확인'), findsWidgets);
      expect(
        find.byKey(const ValueKey('session-composer-permission-error')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
    tags: const <String>['feature_test__permission_settings__widget'],
  );

  testWidgets(
    'the standard composer starts a session without a host-owned mode',
    (tester) async {
      await _setTestViewport(tester, const Size(1500, 900));
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
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('session-composer-mode')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('session-composer-model')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('model-option-openai-gpt-5.6-sol')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('session-composer-input')),
        'Migrate the parser',
      );
      await tester.tap(find.byKey(const ValueKey('session-composer-send')));
      await tester.pumpAndSettle();

      final created = api.createdSessions.single;
      expect(created.agentDefinitionId, 'tinest');
    },
    tags: const <String>['feature_test__session_lifecycle__widget'],
  );

  testWidgets('a session exposes no host-owned mode control', (tester) async {
    await _setTestViewport(tester, const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final planning = session('planning');
    final api = FakeTinestApi(
      workspaces: <WorkspaceDto>[workspace],
      worktrees: <WorktreeDto>[checkout],
      agents: <SessionDto>[planning],
    );
    final router = await _pumpRoute(
      tester,
      api,
      SessionRoute(
        hostId: 'server',
        workspaceId: workspace.id,
        worktreeId: checkout.id,
        sessionId: planning.id,
      ).location,
    );
    addTearDown(router.dispose);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey<String>('session-composer-mode')),
      findsNothing,
    );
  }, tags: const <String>['feature_test__session_lifecycle__widget']);

  testWidgets('a historical plan snapshot renders through generic plugin UI', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final planning = session('planning');
    final api = FakeTinestApi(
      workspaces: <WorkspaceDto>[workspace],
      worktrees: <WorktreeDto>[checkout],
      agents: <SessionDto>[planning],
      timelines: <String, List<TimelineEventDto>>{
        planning.id: <TimelineEventDto>[
          TimelineEventDto(
            sessionId: planning.id,
            sequence: 1,
            turnId: 'turn-1',
            type: 'plugin.ui',
            data: const <String, dynamic>{
              'document': <String, dynamic>{
                'id': 'plan-snapshot',
                'pluginId': 'tinest.plan',
                'revisionHash': 'historical-revision',
                'slot': 'timeline',
                'root': <String, dynamic>{
                  'type': 'text',
                  'text': 'Move the parser',
                },
              },
            },
            createdAt: now,
          ),
        ],
      },
    );
    final router = await _pumpRoute(
      tester,
      api,
      SessionRoute(
        hostId: 'server',
        workspaceId: workspace.id,
        worktreeId: checkout.id,
        sessionId: planning.id,
      ).location,
    );
    addTearDown(router.dispose);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('session-composer-input')),
      findsOneWidget,
    );
    expect(find.text('이 계획대로 진행할까요?'), findsNothing);
    expect(find.text('Move the parser'), findsOneWidget);
    expect(api.startedPrompts, isEmpty);
  }, tags: const <String>['feature_test__session_lifecycle__widget']);

  testWidgets(
    'live plugin publications reach status, dialog, and toast host slots',
    (tester) async {
      final agent = session('plugin-ui-slots');
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        agents: <SessionDto>[agent],
      );
      final router = await _pumpRoute(
        tester,
        api,
        SessionRoute(
          hostId: 'server',
          workspaceId: workspace.id,
          worktreeId: checkout.id,
          sessionId: agent.id,
        ).location,
      );
      addTearDown(router.dispose);

      void publish(String id, PluginUiSlot slot, String text) {
        api.emitTimeline(agent.id, 'plugin.ui', <String, dynamic>{
          'document': <String, dynamic>{
            'id': id,
            'pluginId': 'example.notifications',
            'revisionHash': 'revision-1',
            'slot': slot.name,
            'root': <String, dynamic>{'type': 'text', 'text': text},
          },
        });
      }

      publish('status', PluginUiSlot.conversationStatus, 'Live goal status');
      await tester.pumpAndSettle();
      expect(find.text('Live goal status'), findsOneWidget);

      publish('toast', PluginUiSlot.toast, 'Plugin toast body');
      await tester.pumpAndSettle();
      expect(find.text('Plugin toast body'), findsOneWidget);

      publish('dialog', PluginUiSlot.dialog, 'Plugin dialog body');
      await tester.pumpAndSettle();
      expect(find.text('Plugin dialog body'), findsOneWidget);
      await tester.tap(find.widgetWithText(TRButton, '닫기'));
      await tester.pumpAndSettle();
      expect(find.text('Plugin dialog body'), findsNothing);
    },
    tags: const <String>['feature_test__plugin_ui__widget'],
  );

  testWidgets(
    'the conversation status slot re-renders at both turn boundaries',
    (tester) async {
      final agent = session('plugin-ui-status-turn');
      PluginUiDocumentDto reported(String text) => PluginUiDocumentDto(
        id: 'status-$text',
        pluginId: 'tinest.standard',
        revisionHash: 'revision-1',
        slot: PluginUiSlot.conversationStatus,
        root: <String, dynamic>{'type': 'text', 'text': text},
      );
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        agents: <SessionDto>[agent],
        plugins: const <PluginDescriptorDto>[
          PluginDescriptorDto(
            apiMajor: 5,
            id: 'tinest.standard',
            version: '1.0.0',
            name: 'Standard',
            entrypoint: 'main.lua',
            source: PluginSource.builtIn,
            sourcePath: '/built-in/tinest.standard',
            requestedCapabilities: <String>[],
            contributions: <PluginContributionDto>[
              PluginContributionDto(
                pluginId: 'tinest.standard',
                id: 'status',
                kind: PluginContributionKind.ui,
                metadata: <String, dynamic>{
                  'slots': <String>['conversationStatus'],
                },
              ),
            ],
          ),
        ],
        pluginUiDocuments: <String, PluginUiDocumentDto>{
          'tinest.standard/status/tinest': reported('idle'),
        },
      );
      final router = await _pumpRoute(
        tester,
        api,
        SessionRoute(
          hostId: 'server',
          workspaceId: workspace.id,
          worktreeId: checkout.id,
          sessionId: agent.id,
        ).location,
        // A running turn animates its busy indicator forever, and this test
        // has to settle while the turn is in flight.
        disableAnimations: true,
      );
      addTearDown(router.dispose);
      await tester.pumpAndSettle();
      expect(find.text('idle'), findsOneWidget);

      api.pluginUiDocuments['tinest.standard/status/tinest'] = reported(
        'working',
      );
      api.emit(
        SessionUpdatedClientEvent(
          agent.copyWith(status: SessionStatus.running),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('working'), findsOneWidget);

      // The end of the turn is the half that used to be missed: a surface that
      // reloads only when a turn starts keeps reporting the state that turn was
      // in for the rest of the session.
      api.pluginUiDocuments['tinest.standard/status/tinest'] = reported('done');
      api.emit(
        SessionUpdatedClientEvent(agent.copyWith(status: SessionStatus.idle)),
      );
      await tester.pumpAndSettle();
      expect(find.text('done'), findsOneWidget);
      expect(find.text('working'), findsNothing);
      expect(
        api.pluginUiRenders
            .map((render) => render.context['busy'])
            .toList(growable: false),
        <bool>[false, true, false],
      );
    },
    tags: const <String>['feature_test__plugin_ui__widget'],
  );

  testWidgets(
    'a published status document does not outlive the turn that sent it',
    (tester) async {
      final agent = session('plugin-ui-status-live')
          .copyWith(status: SessionStatus.running);
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        agents: <SessionDto>[agent],
      );
      final router = await _pumpRoute(
        tester,
        api,
        SessionRoute(
          hostId: 'server',
          workspaceId: workspace.id,
          worktreeId: checkout.id,
          sessionId: agent.id,
        ).location,
        // The publication under test only happens mid-turn, and a running
        // turn animates its busy indicator for as long as it lasts.
        disableAnimations: true,
      );
      addTearDown(router.dispose);

      api.emitTimeline(agent.id, 'plugin.ui', <String, dynamic>{
        'document': <String, dynamic>{
          'id': 'status',
          'pluginId': 'example.notifications',
          'revisionHash': 'revision-1',
          'slot': PluginUiSlot.conversationStatus.name,
          'root': <String, dynamic>{'type': 'text', 'text': '2 agents running'},
        },
      });
      await tester.pumpAndSettle();
      expect(find.text('2 agents running'), findsOneWidget);

      // The snapshot describes the turn that published it. Holding it after the
      // turn ends freezes that text above the composer for good.
      api.emit(
        SessionUpdatedClientEvent(agent.copyWith(status: SessionStatus.idle)),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 agents running'), findsNothing);
    },
    tags: const <String>['feature_test__plugin_ui__widget'],
  );

  testWidgets(
    'timeline and approval cards render typed event content',
    (tester) async {
      final agent = session('approval');
      final approval = ApprovalRequestDto(
        id: 'approval',
        sessionId: agent.id,
        turnId: 'turn',
        toolCallId: 'call',
        toolName: 'apply_patch',
        risk: ToolRisk.write,
        arguments: const <String, dynamic>{'patch': 'diff'},
        status: ApprovalStatus.pending,
        createdAt: now,
      );
      final event = TimelineEventDto(
        sessionId: agent.id,
        sequence: 1,
        type: 'user.message',
        data: const <String, dynamic>{'text': 'Inspect this'},
        createdAt: now,
      );
      final api = FakeTinestApi(agents: <SessionDto>[agent]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appServicesProvider.overrideWithValue(fakeAppServices(api)),
          ],
          child: MaterialApp(
            theme: testLightTheme,
            darkTheme: testDarkTheme,
            locale: testLocale,
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            home: Scaffold(
              body: ListView(
                children: <Widget>[
                  Consumer(
                    builder: (context, ref, child) => Text(
                      ref
                                  .watch(hostRegistryControllerProvider)
                                  .asData
                                  ?.value
                                  .runtimes['server']
                                  ?.connected ==
                              true
                          ? 'ready'
                          : 'waiting',
                    ),
                  ),
                  ChatItemView(
                    item: projectChatTimeline(<TimelineEventDto>[event]).single,
                  ),
                  ApprovalCard(hostId: 'server', approval: approval),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ready'), findsOneWidget);
      expect(find.byType(TRChatUserBubble), findsOneWidget);
      expect(find.text('Inspect this', findRichText: true), findsOneWidget);
      expect(find.text('승인 필요 · apply_patch'), findsOneWidget);
      await tester.tap(find.widgetWithText(TRButton, '거부'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TRButton, '승인'));
      await tester.pumpAndSettle();
      expect(api.approvalDecisions, <({bool approved, String id})>[
        (id: 'approval', approved: false),
        (id: 'approval', approved: true),
      ]);
    },
    tags: const <String>[
      'feature_test__turn_execution__widget',
      'ui_state__conversation_timeline__approval_pending__widget',
    ],
  );

  testWidgets(
    'a question card answers with an option or with free-form text',
    (tester) async {
      await _setTestViewport(tester, const Size(900, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final agent = session('asking');
      final request = UserQuestionRequestDto(
        id: 'question',
        sessionId: agent.id,
        turnId: 'turn',
        toolCallId: 'ask-call',
        questions: const <UserQuestionItemDto>[
          UserQuestionItemDto(
            id: 'store',
            header: 'Storage',
            question: 'Which store should the cache use?',
            options: <UserQuestionOptionDto>[
              UserQuestionOptionDto(
                label: 'SQLite',
                description: 'Durable and already a dependency.',
              ),
              UserQuestionOptionDto(
                label: 'In memory',
                description: 'Fastest, lost on restart.',
              ),
            ],
          ),
        ],
        status: UserQuestionStatus.pending,
        createdAt: now,
      );
      final api = FakeTinestApi(agents: <SessionDto>[agent]);
      Future<void> pump() => tester.pumpWidget(
        ProviderScope(
          overrides: [
            appServicesProvider.overrideWithValue(fakeAppServices(api)),
          ],
          child: MaterialApp(
            theme: testLightTheme,
            locale: testLocale,
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            home: Scaffold(
              body: ListView(
                children: <Widget>[
                  Consumer(
                    builder: (context, ref, child) => Text(
                      ref
                                  .watch(hostRegistryControllerProvider)
                                  .asData
                                  ?.value
                                  .runtimes['server']
                                  ?.connected ==
                              true
                          ? 'ready'
                          : 'waiting',
                    ),
                  ),
                  ChatQuestionCard(hostId: 'server', request: request),
                ],
              ),
            ),
          ),
        ),
      );

      await pump();
      await tester.pumpAndSettle();
      expect(find.text('ready'), findsOneWidget);
      expect(find.text('Storage'), findsOneWidget);
      expect(find.text('Which store should the cache use?'), findsOneWidget);
      expect(find.text('Durable and already a dependency.'), findsOneWidget);
      // The client offers the free-form choice; the agent never authors it.
      expect(find.text('직접 입력'), findsOneWidget);

      final submit = find.byKey(const ValueKey<String>('chat-question-submit'));
      expect(tester.widget<TRButton>(submit).onPressed, isNull);

      await tester.tap(find.text('SQLite'));
      await tester.pumpAndSettle();
      expect(tester.widget<TRButton>(submit).onPressed, isNotNull);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(api.questionAnswers.single.id, 'question');
      expect(api.questionAnswers.single.answers, <UserQuestionAnswerDto>[
        const UserQuestionAnswerDto(
          questionId: 'store',
          answer: 'SQLite',
          isFreeForm: false,
        ),
      ]);

      await pump();
      await tester.pumpAndSettle();
      await tester.tap(find.text('직접 입력'));
      await tester.pumpAndSettle();
      final field = find.byKey(
        const ValueKey<String>('chat-question-other-store'),
      );
      expect(field, findsOneWidget);
      // Blank free-form text is not an answer.
      expect(tester.widget<TRButton>(submit).onPressed, isNull);
      await tester.enterText(field, '  Postgres  ');
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(api.questionAnswers.last.answers, <UserQuestionAnswerDto>[
        const UserQuestionAnswerDto(
          questionId: 'store',
          answer: 'Postgres',
          isFreeForm: true,
        ),
      ]);
    },
    tags: const <String>[
      'feature_test__turn_question__widget',
      'ui_state__conversation_timeline__question_pending__widget',
    ],
  );

  testWidgets(
    'the composer does not expose the removed host-owned goal command',
    (tester) async {
      await _setTestViewport(tester, const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final agent = session('goal-session');
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        agents: <SessionDto>[agent],
      );
      final router = await _pumpRoute(
        tester,
        api,
        SessionRoute(
          hostId: 'server',
          workspaceId: workspace.id,
          worktreeId: checkout.id,
          sessionId: agent.id,
        ).location,
      );
      addTearDown(router.dispose);
      await tester.pumpAndSettle();

      expect(
        clientComposerCommands.any((command) => command.name == 'goal'),
        isFalse,
      );
    },
    tags: const <String>['feature_test__session_goal__widget'],
  );

  testWidgets(
    'a multi-question card pages through tabs and submits ordered answers',
    (tester) async {
      await _setTestViewport(tester, const Size(900, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final agent = session('asking-many');
      final request = UserQuestionRequestDto(
        id: 'questions',
        sessionId: agent.id,
        turnId: 'turn',
        toolCallId: 'ask-call',
        questions: const <UserQuestionItemDto>[
          UserQuestionItemDto(
            id: 'store',
            header: 'Storage',
            question: 'Which store should the cache use?',
            options: <UserQuestionOptionDto>[
              UserQuestionOptionDto(
                label: 'SQLite',
                description: 'Durable and already a dependency.',
              ),
              UserQuestionOptionDto(
                label: 'In memory',
                description: 'Fastest, lost on restart.',
              ),
            ],
          ),
          UserQuestionItemDto(
            id: 'theme',
            header: 'Theme',
            question: 'Which theme should the editor use?',
            options: <UserQuestionOptionDto>[
              UserQuestionOptionDto(
                label: 'System',
                description: 'Follow the operating system.',
              ),
              UserQuestionOptionDto(
                label: 'Dark',
                description: 'Always use the dark theme.',
              ),
            ],
          ),
          UserQuestionItemDto(
            id: 'review',
            header: 'Review',
            question: 'How should changes be reviewed?',
            options: <UserQuestionOptionDto>[
              UserQuestionOptionDto(
                label: 'Pull request',
                description: 'Require a review before merging.',
              ),
              UserQuestionOptionDto(
                label: 'Direct',
                description: 'Merge directly after checks pass.',
              ),
            ],
          ),
        ],
        status: UserQuestionStatus.pending,
        createdAt: now,
      );
      final api = FakeTinestApi(agents: <SessionDto>[agent]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appServicesProvider.overrideWithValue(fakeAppServices(api)),
          ],
          child: MaterialApp(
            theme: testLightTheme,
            locale: testLocale,
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            home: Scaffold(
              body: ListView(
                children: <Widget>[
                  Consumer(
                    builder: (context, ref, child) => Text(
                      ref
                                  .watch(hostRegistryControllerProvider)
                                  .asData
                                  ?.value
                                  .runtimes['server']
                                  ?.connected ==
                              true
                          ? 'ready'
                          : 'waiting',
                    ),
                  ),
                  ChatQuestionCard(hostId: 'server', request: request),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ready'), findsOneWidget);
      expect(find.byType(TRTabs), findsOneWidget);
      expect(find.text('Which store should the cache use?'), findsOneWidget);
      expect(find.text('Which theme should the editor use?'), findsNothing);
      expect(find.text('How should changes be reviewed?'), findsNothing);
      expect(
        tester
            .widgetList<TRRadio>(find.byType(TRRadio))
            .every(
              (radio) =>
                  radio.labelAlignment == TRRadioLabelAlignment.firstLine,
            ),
        isTrue,
      );

      await tester.tap(find.text('SQLite'));
      await tester.pumpAndSettle();
      expect(find.text('Which store should the cache use?'), findsNothing);
      expect(find.text('Which theme should the editor use?'), findsOneWidget);
      expect(find.byIcon(TinestIcons.check), findsOneWidget);

      await tester.tap(find.text('직접 입력'));
      await tester.pumpAndSettle();
      final other = find.byKey(
        const ValueKey<String>('chat-question-other-theme'),
      );
      expect(other, findsOneWidget);
      final primary = find.byKey(
        const ValueKey<String>('chat-question-submit'),
      );
      expect(find.widgetWithText(TRButton, '다음'), findsOneWidget);
      expect(tester.widget<TRButton>(primary).onPressed, isNull);
      await tester.enterText(other, '  High contrast  ');
      await tester.pumpAndSettle();
      expect(tester.widget<TRButton>(primary).onPressed, isNotNull);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();

      expect(find.text('How should changes be reviewed?'), findsOneWidget);
      expect(find.byIcon(TinestIcons.check), findsNWidgets(2));
      expect(find.widgetWithText(TRButton, '답변'), findsOneWidget);
      expect(tester.widget<TRButton>(primary).onPressed, isNull);

      await tester.tap(find.text('Storage'));
      await tester.pumpAndSettle();
      expect(tester.widget<TRRadioGroup>(find.byType(TRRadioGroup)).value, '0');
      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TRTextField>(
              find.byKey(const ValueKey<String>('chat-question-other-theme')),
            )
            .controller
            ?.text,
        '  High contrast  ',
      );
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pull request'));
      await tester.pumpAndSettle();
      expect(tester.widget<TRButton>(primary).onPressed, isNotNull);

      api.questionAnswerError = Exception('daemon rejected answers');
      await tester.tap(primary);
      await tester.pumpAndSettle();
      expect(find.text('Exception: daemon rejected answers'), findsOneWidget);
      expect(tester.widget<TRButton>(primary).loading, isFalse);
      expect(tester.widget<TRButton>(primary).onPressed, isNotNull);
      expect(
        tester.widget<TRTabs>(find.byType(TRTabs)).tabs,
        everyElement(
          isA<TRTabsTab>().having((tab) => tab.disabled, 'disabled', isFalse),
        ),
      );
      api
        ..questionAnswers.clear()
        ..questionAnswerError = null
        ..questionAnswerGate = Completer<void>();

      await tester.tap(primary);
      await tester.pump();

      expect(tester.widget<TRButton>(primary).loading, isTrue);
      expect(
        tester.widget<TRRadioGroup>(find.byType(TRRadioGroup)).disabled,
        isTrue,
      );
      expect(
        tester.widget<TRTabs>(find.byType(TRTabs)).tabs,
        everyElement(
          isA<TRTabsTab>().having((tab) => tab.disabled, 'disabled', isTrue),
        ),
      );
      api.questionAnswerGate!.complete();
      await tester.pumpAndSettle();

      expect(api.questionAnswers.single.id, 'questions');
      expect(api.questionAnswers.single.answers, const <UserQuestionAnswerDto>[
        UserQuestionAnswerDto(
          questionId: 'store',
          answer: 'SQLite',
          isFreeForm: false,
        ),
        UserQuestionAnswerDto(
          questionId: 'theme',
          answer: 'High contrast',
          isFreeForm: true,
        ),
        UserQuestionAnswerDto(
          questionId: 'review',
          answer: 'Pull request',
          isFreeForm: false,
        ),
      ]);
    },
    tags: const <String>[
      'feature_test__turn_question__widget',
      'ui_transition__conversation_timeline__answer_question__widget',
    ],
  );

  testWidgets(
    'question tabs remain accessible on a narrow large-text surface',
    (tester) async {
      await _setTestViewport(tester, const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final semantics = tester.ensureSemantics();
      final request = UserQuestionRequestDto(
        id: 'compact-questions',
        sessionId: 'compact-session',
        turnId: 'turn',
        toolCallId: 'ask-call',
        questions: const <UserQuestionItemDto>[
          UserQuestionItemDto(
            id: 'store',
            header: 'Storage',
            question: 'Which store should the cache use?',
            options: <UserQuestionOptionDto>[
              UserQuestionOptionDto(label: 'SQLite', description: 'Durable.'),
              UserQuestionOptionDto(label: 'Memory', description: 'Fast.'),
            ],
          ),
          UserQuestionItemDto(
            id: 'theme',
            header: 'Theme',
            question: 'Which theme should the editor use?',
            options: <UserQuestionOptionDto>[
              UserQuestionOptionDto(label: 'System', description: 'Follow it.'),
              UserQuestionOptionDto(label: 'Dark', description: 'Always dark.'),
            ],
          ),
          UserQuestionItemDto(
            id: 'review',
            header: 'Review',
            question: 'How should changes be reviewed?',
            options: <UserQuestionOptionDto>[
              UserQuestionOptionDto(label: 'PR', description: 'Review first.'),
              UserQuestionOptionDto(label: 'Direct', description: 'Merge now.'),
            ],
          ),
        ],
        status: UserQuestionStatus.pending,
        createdAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: testLightTheme,
            locale: testLocale,
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ChatQuestionCard(hostId: 'server', request: request),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('질문'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Which theme should the editor use?'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
    tags: const <String>[
      'feature_test__turn_question__widget',
      // Exact executable tag required by the typed UI manifest.
      // ignore: lines_longer_than_80_chars
      'ui_variant__conversation_timeline__mobile_light_korean_large_text_touch_online__widget',
    ],
  );

  testWidgets(
    'a resolving agent catalog does not take the composer draft with it',
    (tester) async {
      // The pane's slots are same-typed siblings above the composer. The one
      // that appears only once the session's agent definition is in the
      // catalog shifts the unkeyed children below it, and the composer that
      // moves with them is rebuilt from scratch — losing whatever was typed,
      // along with the caret.
      await _setTestViewport(tester, const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final current = session('catalog').copyWith(agentDefinitionId: 'late');
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        agents: <SessionDto>[current],
      );
      final router = await _pumpRoute(
        tester,
        api,
        SessionRoute(
          hostId: 'server',
          workspaceId: workspace.id,
          worktreeId: checkout.id,
          sessionId: current.id,
        ).location,
      );
      addTearDown(router.dispose);

      const input = ValueKey<String>('session-composer-input');
      const prompt = 'Typed before the definition arrived';
      expect(
        find.byType(AgentPluginUiSlot),
        findsNothing,
        reason: 'the session names a definition the catalog does not have yet',
      );
      await tester.enterText(find.byKey(input), prompt);
      await tester.pump();

      // The daemon publishes the missing definition; the catalog reloads and
      // the slot above the composer appears.
      await api.createAgentDefinition('late', _lateAgentDefinition);
      api.emit(const AgentDefinitionsChangedClientEvent());
      await tester.pumpAndSettle();
      // Both of the definition's slots are now built; the status one sits
      // between the timeline and the composer, which is the child that shifts.
      expect(find.byType(AgentPluginUiSlot), findsAtLeastNWidgets(1));

      expect(
        tester.widget<TRTextField>(find.byKey(input)).controller!.text,
        prompt,
        reason: 'the draft survives the agent slot arriving above it',
      );
      final primaryContext = tester.binding.focusManager.primaryFocus?.context;
      expect(
        find.ancestor(
          of: find.byElementPredicate(
            (element) => identical(element, primaryContext),
          ),
          matching: find.byKey(input),
        ),
        findsOneWidget,
        reason: 'and so does the caret',
      );
    },
    tags: const <String>['feature_test__session_lifecycle__widget'],
  );
}
