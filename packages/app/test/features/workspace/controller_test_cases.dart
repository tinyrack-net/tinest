part of '../../app/application_controllers_test.dart';

void _registerWorkspaceControllerTests() {
  final now = DateTime.utc(2026, 8, 2);
  final workspace = WorkspaceDto(
    id: 'workspace',
    name: 'Workspace',
    rootPath: '/workspace',
    kind: WorkspaceKind.directory,
    createdAt: now,
  );
  final worktree = WorktreeDto(
    id: 'worktree',
    workspaceId: workspace.id,
    name: workspace.name,
    path: workspace.rootPath,
    kind: WorktreeKind.directory,
    isTinestOwned: false,
    createdAt: now,
  );
  final agent = SessionDto(
    id: 'agent',
    worktreeId: worktree.id,
    title: 'Agent',
    agentDefinitionId: 'tinest',
    origin: SessionOrigin.manual,
    status: SessionStatus.idle,
    model: const ModelSelectionDto(modelId: 'openai/gpt-5.6-sol'),
    createdAt: now,
    updatedAt: now,
  );
  test(
    'connection, workspace, and agent notifiers own their feature state',
    () async {
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[worktree],
        agents: <SessionDto>[agent],
      );
      final container = _container(api);
      addTearDown(container.dispose);
      final registrySubscription = container.listen(
        hostRegistryControllerProvider,
        (_, _) {},
      );
      addTearDown(registrySubscription.close);

      await container.read(
        hostRegistryControllerProvider.future,
      );
      await Future<void>.delayed(Duration.zero);
      final runtime = container
          .read(hostRegistryControllerProvider)
          .value!
          .runtimes['server']!;
      expect(runtime.connected, isTrue);
      expect(runtime.serverInfo!.serverId, 'server');
      expect(
        container
            .read(hostRegistryControllerProvider)
            .value!
            .profiles
            .single
            .connections,
        hasLength(1),
      );

      api.emitState(ClientConnectionState.reconnecting);
      await Future<void>.delayed(Duration.zero);
      expect(
        container
            .read(hostRegistryControllerProvider)
            .value!
            .runtimes['server']!
            .status,
        HostRuntimeStatus.reconnecting,
      );
      api.emitState(ClientConnectionState.connected);

      await container.read(workspaceCatalogControllerProvider.future);
      // Host catalogs merge in as each daemon answers.
      await Future<void>.delayed(Duration.zero);
      final catalog = container
          .read(workspaceCatalogControllerProvider)
          .requireValue;
      expect(catalog.catalogs['server']?.workspaces, <WorkspaceDto>[workspace]);
      final registered = await container
          .read(workspaceCatalogControllerProvider.notifier)
          .register('server', '/workspace/new');
      expect(registered.workspace.id, 'generated-id');
      expect(registered.workspace.name, 'new');
      expect(
        container
            .read(workspaceCatalogControllerProvider)
            .value
            ?.catalogs['server']
            ?.workspaces,
        hasLength(2),
      );

      final agentsProvider = sessionsControllerProvider('server', worktree.id);
      expect(await container.read(agentsProvider.future), <SessionDto>[agent]);
      const override = ModelSelectionDto(
        modelId: 'openai/gpt-5.6-sol',
      );
      final created = await container
          .read(agentsProvider.notifier)
          .create(
            title: 'Created',
            agentDefinitionId: 'tinest',
            model: override,
          );
      expect(created.id, 'generated-id');
      expect(created.model, override);
      expect(container.read(agentsProvider).value!.first, created);
      expect(
        (await container
                .read(agentsProvider.notifier)
                .setModel(
                  created.id,
                  const ModelSelectionDto(modelId: 'openai/gpt-5.6-terra'),
                  const <String, ModelControlValueDto>{},
                ))
            .model,
        const ModelSelectionDto(modelId: 'openai/gpt-5.6-terra'),
      );
      expect(api.updatedSessionModels.single.sessionId, created.id);
      expect(
        container
            .read(agentsProvider)
            .value!
            .firstWhere((item) => item.id == created.id)
            .model,
        const ModelSelectionDto(modelId: 'openai/gpt-5.6-terra'),
      );
      api.emit(
        SessionUpdatedClientEvent(
          agent.copyWith(status: SessionStatus.running),
        ),
      );
      expect(
        container.read(agentsProvider).value!.last.status,
        SessionStatus.running,
      );
      final delegated = agent.copyWith(
        id: 'delegated',
        title: 'Reviewer',
        parentSessionId: agent.id,
        origin: SessionOrigin.delegated,
      );
      api.emit(SessionUpdatedClientEvent(delegated));
      expect(
        container.read(agentsProvider).value!.map((item) => item.id),
        contains(delegated.id),
      );

      expect(
        await container.read(sessionsControllerProvider('server', null).future),
        isEmpty,
      );
    },
    tags: const <String>[
      'feature_test__session_lifecycle__unit',
    ],
  );

  test(
    'the home checkout resolves per host and is kept out of projects',
    () {
      final home = WorkspaceDto(
        id: 'home',
        name: 'user',
        rootPath: '/home/user',
        kind: WorkspaceKind.home,
        createdAt: now,
      );
      final homeCheckout = WorktreeDto(
        id: 'home-checkout',
        workspaceId: home.id,
        name: home.name,
        path: home.rootPath,
        kind: WorktreeKind.directory,
        isTinestOwned: false,
        createdAt: now,
      );
      final state = UnifiedWorkspaceCatalogState(
        hosts: const <String, HostRuntimeSnapshot>{},
        catalogs: <String, WorkspaceCatalogDto>{
          'with-home': WorkspaceCatalogDto(
            workspaces: <WorkspaceDto>[workspace, home],
            worktrees: <WorktreeDto>[worktree, homeCheckout],
          ),
          'without-home': WorkspaceCatalogDto(
            workspaces: <WorkspaceDto>[workspace],
            worktrees: <WorktreeDto>[worktree],
          ),
        },
      );

      expect(
        state.homeSelection('with-home'),
        const WorkspaceSelection(
          hostId: 'with-home',
          workspaceId: 'home',
          worktreeId: 'home-checkout',
        ),
      );
      // A daemon configured without a user home offers no project-less start.
      expect(state.homeSelection('without-home'), isNull);
      expect(state.homeSelection('unknown'), isNull);
    },
    tags: const <String>['feature_test__session_home__unit'],
  );

  test('feature families never mix state between connected hosts', () async {
    WorkspaceDto hostWorkspace(String host) => WorkspaceDto(
      id: 'workspace',
      name: '$host workspace',
      rootPath: '/$host',
      kind: WorkspaceKind.directory,
      createdAt: now,
    );
    SessionDto hostAgent(String host) => agent.copyWith(title: '$host agent');
    TimelineEventDto hostEvent(String host) => TimelineEventDto(
      sessionId: agent.id,
      sequence: 1,
      turnId: 'turn',
      type: 'assistant.delta',
      data: <String, dynamic>{'text': host},
      createdAt: now,
    );
    ProviderCatalogDto hostCatalog(String host) => ProviderCatalogDto(
      definitions: <ProviderDefinitionDto>[
        ProviderDefinitionDto(
          id: host,
          name: host,
          description: host,
          authMethods: const <ProviderAuthMethodDto>[],
        ),
      ],
      source: ProviderCatalogSource.bundled,
      updatedAt: now,
    );
    final firstApi = FakeTinestApi(
      serverInfo: _serverInfo('first-server'),
      workspaces: <WorkspaceDto>[hostWorkspace('first')],
      worktrees: <WorktreeDto>[worktree],
      agents: <SessionDto>[hostAgent('first')],
      timelines: <String, List<TimelineEventDto>>{
        agent.id: <TimelineEventDto>[hostEvent('first')],
      },
      catalog: hostCatalog('first'),
    );
    final secondApi = FakeTinestApi(
      serverInfo: _serverInfo('second-server'),
      workspaces: <WorkspaceDto>[hostWorkspace('second')],
      worktrees: <WorktreeDto>[worktree],
      agents: <SessionDto>[hostAgent('second')],
      timelines: <String, List<TimelineEventDto>>{
        agent.id: <TimelineEventDto>[hostEvent('second')],
      },
      catalog: hostCatalog('second'),
    );
    final store = MemoryAppStore(
      settings: const AppSettings(embeddedDaemonEnabled: false),
      profiles: <RemoteDaemonProfile>[
        _profile('first', now),
        _profile('second', now),
      ],
      tokens: const <String, String>{'first': 'one', 'second': 'two'},
    );
    final container = ProviderContainer(
      overrides: [
        appServicesProvider.overrideWithValue(
          AppServices(
            settings: store,
            profiles: store,
            credentials: store,
            clients: _HostClients(<String, TinestApi>{
              'first.test': firstApi,
              'second.test': secondApi,
            }),
            clientKind: 'test',
          ),
        ),
        appIdGeneratorProvider.overrideWithValue(const _FixedIdGenerator()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(hostRegistryControllerProvider.future);
    await Future<void>.delayed(Duration.zero);

    await container.read(workspaceCatalogControllerProvider.future);
    // Host catalogs merge in as each daemon answers.
    await Future<void>.delayed(Duration.zero);
    final catalogs = container
        .read(workspaceCatalogControllerProvider)
        .requireValue;
    expect(
      catalogs.catalogs['first']?.workspaces.single.name,
      'first workspace',
    );
    expect(
      catalogs.catalogs['second']?.workspaces.single.name,
      'second workspace',
    );
    expect(
      (await container.read(
        sessionsControllerProvider('first', 'worktree').future,
      )).single.title,
      'first agent',
    );
    expect(
      (await container.read(
        sessionsControllerProvider('second', 'worktree').future,
      )).single.title,
      'second agent',
    );
    expect(
      (await container.read(
        conversationControllerProvider('first', agent.id).future,
      )).timeline.single.data['text'],
      'first',
    );
    expect(
      (await container.read(
        conversationControllerProvider('second', agent.id).future,
      )).timeline.single.data['text'],
      'second',
    );
    expect(
      (await container.read(
        providerSettingsControllerProvider('first').future,
      ))!.catalog.definitions.single.id,
      'first',
    );
    expect(
      (await container.read(
        providerSettingsControllerProvider('second').future,
      ))!.catalog.definitions.single.id,
      'second',
    );
  });

  test(
    'session tabs close locally and persist independently per worktree',
    () async {
      final second = agent.copyWith(id: 'agent-2', title: 'Second');
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[worktree],
        agents: <SessionDto>[agent, second],
      );
      final store = MemoryAppStore(
        settings: const AppSettings(embeddedDaemonEnabled: false),
        profiles: <RemoteDaemonProfile>[_profile('server', now)],
        tokens: const <String, String>{'server': 'token'},
      );
      final container = ProviderContainer(
        overrides: [
          appServicesProvider.overrideWithValue(
            AppServices(
              settings: store,
              profiles: store,
              credentials: store,
              clients: _HostClients(<String, TinestApi>{
                'server.test': api,
              }),
              clientKind: 'test',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      const selection = WorkspaceSelection(
        hostId: 'server',
        workspaceId: 'workspace',
        worktreeId: 'worktree',
      );
      final provider = sessionTabsControllerProvider(selection);
      final initial = await container.read(provider.future);
      expect(initial.panes.single.tabIds, hasLength(1));
      expect(initial.focusedTab?.target, isA<DraftTabTarget>());

      await container
          .read(provider.notifier)
          .add(agent, draftTabId: initial.focusedTabId);
      await container.read(provider.notifier).open(second.id);
      await container.read(provider.notifier).close(agent.id);

      final afterClose = container.read(provider).requireValue;
      expect(afterClose.panes.single.tabIds, <String>['session:agent-2']);
      expect(
        store.settings.sessionTabs[selection.storageKey]?.focusedPaneId,
        afterClose.focusedPaneId,
      );
      expect(
        await api.sessions.listSessions(worktreeId: worktree.id),
        hasLength(2),
      );
    },
    tags: const <String>['feature_test__session_tabs__unit'],
  );

  test(
    'session catalog updates preserve the ready tab tree without loading',
    () async {
      final createGate = Completer<void>();
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[worktree],
        agents: <SessionDto>[agent],
      )..sessionCreateGate = createGate;
      final container = _container(api);
      addTearDown(container.dispose);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);

      const selection = WorkspaceSelection(
        hostId: 'server',
        workspaceId: 'workspace',
        worktreeId: 'worktree',
      );
      final tabsProvider = sessionTabsControllerProvider(selection);
      final initial = await container.read(tabsProvider.future);
      final transitions = <AsyncValue<SessionTabsState>>[];
      final subscription = container.listen(
        tabsProvider,
        (_, next) => transitions.add(next),
      );
      addTearDown(subscription.close);

      final sessionsProvider = sessionsControllerProvider(
        selection.hostId,
        selection.worktreeId,
      );
      final creating = container
          .read(sessionsProvider.notifier)
          .create(
            title: 'Created',
            agentDefinitionId: 'tinest',
          );
      await Future<void>.delayed(Duration.zero);

      expect(container.read(sessionsProvider).hasValue, isTrue);
      expect(container.read(tabsProvider).hasValue, isTrue);
      expect(
        container.read(tabsProvider).requireValue.root,
        same(initial.root),
      );

      createGate.complete();
      final created = await creating;
      await Future<void>.delayed(Duration.zero);
      expect(transitions.where((value) => value.isLoading), isEmpty);
      expect(
        container.read(tabsProvider).requireValue.root,
        same(initial.root),
      );

      await container
          .read(tabsProvider.notifier)
          .add(created, draftTabId: initial.focusedTabId);
      final promoted = container.read(tabsProvider).requireValue;
      final promotedRoot = promoted.root;
      final promotedTab = promoted.focusedTabId;
      api.emit(
        SessionUpdatedClientEvent(
          created.copyWith(status: SessionStatus.running),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final running = container.read(tabsProvider).requireValue;
      expect(transitions.where((value) => value.isLoading), isEmpty);
      expect(running.root, same(promotedRoot));
      expect(running.focusedTabId, promotedTab);
      expect(
        running.sessions.where((item) => item.id == created.id),
        hasLength(1),
      );
      expect(
        running.sessions.firstWhere((item) => item.id == created.id).status,
        SessionStatus.running,
      );

      api.sessionCreateError = Exception('offline');
      final beforeFailure = container.read(sessionsProvider).requireValue;
      await expectLater(
        container
            .read(sessionsProvider.notifier)
            .create(
              title: 'Failed',
              agentDefinitionId: 'tinest',
            ),
        throwsException,
      );
      expect(
        container.read(sessionsProvider).requireValue,
        same(beforeFailure),
      );
      expect(container.read(tabsProvider).hasValue, isTrue);
      expect(
        container.read(tabsProvider).requireValue.root,
        same(promotedRoot),
      );
    },
    tags: const <String>[
      'feature_test__session_lifecycle__unit',
      'feature_test__session_tabs__unit',
    ],
  );

  test(
    'workspace tabs split, move, collapse empty panes, and persist ratios',
    () async {
      final second = agent.copyWith(id: 'agent-2', title: 'Second');
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[worktree],
        agents: <SessionDto>[agent, second],
      );
      final store = MemoryAppStore(
        settings: const AppSettings(embeddedDaemonEnabled: false),
        profiles: <RemoteDaemonProfile>[_profile('server', now)],
        tokens: const <String, String>{'server': 'token'},
      );
      final ids = _SequentialIdGenerator();
      final container = ProviderContainer(
        overrides: [
          appServicesProvider.overrideWithValue(
            AppServices(
              settings: store,
              profiles: store,
              credentials: store,
              clients: _HostClients(<String, TinestApi>{'server.test': api}),
              clientKind: 'test',
            ),
          ),
          appIdGeneratorProvider.overrideWithValue(ids),
        ],
      );
      addTearDown(container.dispose);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      const selection = WorkspaceSelection(
        hostId: 'server',
        workspaceId: 'workspace',
        worktreeId: 'worktree',
      );
      final provider = sessionTabsControllerProvider(selection);
      final initial = await container.read(provider.future);
      final originalPane = initial.focusedPaneId;
      await container
          .read(provider.notifier)
          .add(agent, draftTabId: initial.focusedTabId);

      await container
          .read(provider.notifier)
          .split(originalPane, WorkspaceSplitAxis.horizontal);
      var current = container.read(provider).requireValue;
      expect(current.panes, hasLength(2));
      expect(current.tabs[current.focusedTabId]?.target, isA<DraftTabTarget>());
      final split = current.root as WorkspaceSplitNode;
      expect(split.ratio, 0.5);

      await container
          .read(provider.notifier)
          .split(current.focusedPaneId, WorkspaceSplitAxis.horizontal);
      current = container.read(provider).requireValue;
      expect(current.panes, hasLength(2));

      await container
          .read(provider.notifier)
          .moveTab(
            tabId: initial.focusedTabId,
            sourcePaneId: originalPane,
            targetPaneId: current.focusedPaneId,
            targetIndex: 0,
          );
      current = container.read(provider).requireValue;
      expect(current.panes, hasLength(1));
      expect(current.panes.single.tabIds.first, initial.focusedTabId);
      expect(
        current.tabs[initial.focusedTabId]?.target,
        const SessionTabTarget('agent'),
      );

      await container
          .read(provider.notifier)
          .split(current.focusedPaneId, WorkspaceSplitAxis.vertical);
      current = container.read(provider).requireValue;
      expect(current.panes, hasLength(1));
      await container
          .read(provider.notifier)
          .split(current.focusedPaneId, WorkspaceSplitAxis.horizontal);
      current = container.read(provider).requireValue;
      final horizontal = current.root as WorkspaceSplitNode;
      expect(horizontal.axis, WorkspaceSplitAxis.horizontal);
      await container.read(provider.notifier).resize(horizontal.id, 0.7);
      await container.read(provider.notifier).commitResize();
      expect(
        store.settings.sessionTabs[selection.storageKey]?.root,
        isA<WorkspaceSplitPreference>(),
      );
      expect(
        (store.settings.sessionTabs[selection.storageKey]!.root
                as WorkspaceSplitPreference)
            .ratio,
        0.7,
      );
    },
    tags: const <String>['feature_test__session_tabs__unit'],
  );

  test(
    'saved workspace layouts normalize to two panes without losing tabs',
    () {
      const first = PaneNode(
        id: 'first',
        tabIds: <String>['a'],
        activeTabId: 'a',
      );
      const middle = PaneNode(
        id: 'middle',
        tabIds: <String>['b', 'c'],
        activeTabId: 'c',
      );
      const focused = PaneNode(
        id: 'focused',
        tabIds: <String>['d', 'e'],
        activeTabId: 'e',
      );
      const root = WorkspaceSplitNode(
        id: 'outer',
        axis: WorkspaceSplitAxis.vertical,
        ratio: 0.4,
        first: first,
        second: WorkspaceSplitNode(
          id: 'inner',
          axis: WorkspaceSplitAxis.horizontal,
          ratio: 0.6,
          first: middle,
          second: focused,
        ),
      );

      final normalized = normalizeWorkspacePaneCount(root, focused.id);
      final split = normalized as WorkspaceSplitNode;
      final firstPane = split.first as PaneNode;
      final secondPane = split.second as PaneNode;

      expect(firstPane.id, first.id);
      expect(secondPane.id, focused.id);
      expect(secondPane.tabIds, <String>['b', 'c', 'd', 'e']);
      expect(secondPane.activeTabId, 'e');
      expect(split.axis, WorkspaceSplitAxis.horizontal);
    },
    tags: const <String>['feature_test__session_tabs__unit'],
  );

  test(
    'catalogs merge per host so one slow daemon cannot block others', //
    () async {
      final gate = Completer<void>();
      final fastApi = FakeTinestApi(
        serverInfo: _serverInfo('first-server'),
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[worktree],
      );
      final slowApi = FakeTinestApi(
        serverInfo: _serverInfo('second-server'),
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[worktree],
        workspaceCatalogGate: gate.future,
      );
      final store = MemoryAppStore(
        settings: const AppSettings(embeddedDaemonEnabled: false),
        profiles: <RemoteDaemonProfile>[
          _profile('first', now),
          _profile('second', now),
        ],
        tokens: const <String, String>{'first': 'one', 'second': 'two'},
      );
      final container = ProviderContainer(
        overrides: [
          appServicesProvider.overrideWithValue(
            AppServices(
              settings: store,
              profiles: store,
              credentials: store,
              clients: _HostClients(<String, TinestApi>{
                'first.test': fastApi,
                'second.test': slowApi,
              }),
              clientKind: 'test',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);

      await container.read(workspaceCatalogControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      final partial = container
          .read(workspaceCatalogControllerProvider)
          .requireValue;
      // The fast daemon's projects are usable while the slow one still loads.
      expect(partial.catalogs.containsKey('first'), isTrue);
      expect(partial.catalogs.containsKey('second'), isFalse);

      gate.complete();
      await Future<void>.delayed(Duration.zero);
      final complete = container
          .read(workspaceCatalogControllerProvider)
          .requireValue;
      expect(complete.catalogs.containsKey('first'), isTrue);
      expect(complete.catalogs.containsKey('second'), isTrue);
    },
    tags: const <String>['feature_test__workspace_catalog__unit'],
  );

  test(
    'a catalog response is ignored after its provider is disposed',
    () async {
      final gate = Completer<void>();
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[worktree],
        workspaceCatalogGate: gate.future,
      );
      final errors = <Object>[];

      await runZonedGuarded(() async {
        final container = _container(api);
        await container.read(hostRegistryControllerProvider.future);
        await Future<void>.delayed(Duration.zero);
        await container.read(workspaceCatalogControllerProvider.future);

        container.dispose();
        gate.complete();
        await Future<void>.delayed(Duration.zero);
      }, (error, _) => errors.add(error));

      expect(errors, isEmpty);
    },
    tags: const <String>['feature_test__workspace_catalog__unit'],
  );

  test(
    'catalog refresh keeps stale data, exposes failure, and retries in place',
    () async {
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[worktree],
      );
      final container = _container(api);
      addTearDown(container.dispose);
      final subscription = container.listen(
        workspaceCatalogControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      await container.read(workspaceCatalogControllerProvider.future);
      await Future<void>.delayed(Duration.zero);

      api.workspaceCatalogError = Exception('git unavailable');
      await container
          .read(workspaceCatalogControllerProvider.notifier)
          .retryHost('server');
      final failed = container
          .read(workspaceCatalogControllerProvider)
          .requireValue;
      expect(failed.catalogs['server']?.worktrees, contains(worktree));
      expect(failed.refreshingHostIds, isNot(contains('server')));
      expect(failed.errors['server'], isA<Exception>());

      api.workspaceCatalogError = null;
      api.workspaceCatalogResponses.add(
        WorkspaceCatalogDto(
          workspaces: <WorkspaceDto>[workspace],
          worktrees: const <WorktreeDto>[],
        ),
      );
      await container
          .read(workspaceCatalogControllerProvider.notifier)
          .retryHost('server');
      final recovered = container
          .read(workspaceCatalogControllerProvider)
          .requireValue;
      expect(recovered.catalogs['server']?.worktrees, isEmpty);
      expect(recovered.errors, isEmpty);
    },
    tags: const <String>['feature_test__workspace_catalog__unit'],
  );

  test(
    'archiving through the catalog controller refreshes the host snapshot',
    () async {
      final external = WorktreeDto(
        id: 'external',
        workspaceId: workspace.id,
        name: 'External',
        path: '/workspace/external',
        branch: 'external',
        kind: WorktreeKind.linked,
        isTinestOwned: false,
        createdAt: now,
      );
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[worktree, external],
      );
      final container = _container(api);
      addTearDown(container.dispose);
      final subscription = container.listen(
        workspaceCatalogControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      await container.read(workspaceCatalogControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(api.workspaceCatalogCount, 1);

      final archived = await container
          .read(workspaceCatalogControllerProvider.notifier)
          .archiveWorktree('server', external.id, force: false);

      expect(archived.worktree.archivedAt, isNotNull);
      expect(api.workspaceCatalogCount, 2);
      expect(
        container
            .read(workspaceCatalogControllerProvider)
            .requireValue
            .catalogs['server']
            ?.worktrees
            .map((item) => item.id),
        isNot(contains(external.id)),
      );
    },
    tags: const <String>[
      'feature_test__worktree_lifecycle__unit',
      'feature_test__workspace_catalog__unit',
    ],
  );

  test(
    'saving the tab layout leaves the sidebar catalog and sessions untouched',
    () async {
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[worktree],
        agents: <SessionDto>[agent],
      );
      final container = _container(api);
      addTearDown(container.dispose);
      final registrySubscription = container.listen(
        hostRegistryControllerProvider,
        (_, _) {},
      );
      addTearDown(registrySubscription.close);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);

      final catalogSubscription = container.listen(
        workspaceCatalogControllerProvider,
        (_, _) {},
      );
      addTearDown(catalogSubscription.close);
      await container.read(workspaceCatalogControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      final sessions = sessionsControllerProvider('server', worktree.id);
      final sessionsSubscription = container.listen(sessions, (_, _) {});
      addTearDown(sessionsSubscription.close);
      await container.read(sessions.future);
      final loaded = container.read(workspaceCatalogControllerProvider);
      expect(api.workspaceCatalogCount, 1);
      expect(api.listSessionsCount, 1);

      // Every tab switch persists the pane tree, which re-emits the whole
      // registry. Nothing that only needs daemon runtimes may notice, or the
      // sidebar refetches its tree on each click.
      await container
          .read(hostRegistryControllerProvider.notifier)
          .saveWorkspaceUi(
            selection: WorkspaceSelection(
              hostId: 'server',
              workspaceId: workspace.id,
              worktreeId: worktree.id,
            ),
            tabs: const SessionTabPreference(
              tabs: <WorkspaceTabPreference>[
                WorkspaceTabPreference(
                  id: 'tab',
                  kind: WorkspaceTabTargetKind.draft,
                ),
              ],
              root: WorkspacePanePreference(
                id: 'pane',
                tabIds: <String>['tab'],
                activeTabId: 'tab',
              ),
              focusedPaneId: 'pane',
            ),
          );
      await Future<void>.delayed(Duration.zero);

      expect(api.workspaceCatalogCount, 1);
      expect(api.listSessionsCount, 1);
      expect(container.read(workspaceCatalogControllerProvider), same(loaded));
    },
    tags: const <String>[
      'feature_test__workspace_catalog__unit',
      'feature_test__session_tabs__unit',
    ],
  );

  test(
    'pending terminal tabs appear instantly, persist nothing, and promote '
    'or roll back',
    () async {
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[worktree],
      );
      final store = MemoryAppStore(
        settings: const AppSettings(embeddedDaemonEnabled: false),
        profiles: <RemoteDaemonProfile>[_profile('server', now)],
        tokens: const <String, String>{'server': 'token'},
      );
      final container = ProviderContainer(
        overrides: [
          appServicesProvider.overrideWithValue(
            AppServices(
              settings: store,
              profiles: store,
              credentials: store,
              clients: _HostClients(<String, TinestApi>{'server.test': api}),
              clientKind: 'test',
            ),
          ),
          appIdGeneratorProvider.overrideWithValue(_SequentialIdGenerator()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      const selection = WorkspaceSelection(
        hostId: 'server',
        workspaceId: 'workspace',
        worktreeId: 'worktree',
      );
      final provider = sessionTabsControllerProvider(selection);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final initial = await container.read(provider.future);
      final notifier = container.read(provider.notifier);

      // The placeholder tab is observable synchronously: creating a terminal
      // must never leave the pane waiting on the daemon for feedback.
      final pendingId = notifier.openPendingTerminal(initial.focusedPaneId);
      final pending = container.read(provider).requireValue;
      expect(pending.focusedTab?.id, pendingId);
      expect(pending.focusedTab?.target, isA<PendingTerminalTabTarget>());

      await Future<void>.delayed(Duration.zero);
      final savedPending = store.settings.sessionTabs[selection.storageKey]!;
      expect(
        savedPending.tabs.map((tab) => tab.id),
        isNot(contains(pendingId)),
      );
      expect(
        (savedPending.root as WorkspacePanePreference).tabIds,
        isNot(contains(pendingId)),
      );

      const terminal = TerminalDto(
        id: 'terminal-1',
        worktreeId: 'worktree',
        title: 'Terminal 1',
        shell: ShellSpecDto(executable: '/bin/sh'),
        status: TerminalStatus.running,
        columns: 80,
        rows: 24,
        lastSequence: 0,
      );
      notifier.promotePendingTerminal(pendingId, terminal);
      final promoted = container.read(provider).requireValue;
      expect(
        (promoted.tabs[pendingId]!.target as TerminalTabTarget).terminalId,
        terminal.id,
      );
      expect(promoted.terminals.map((item) => item.id), contains(terminal.id));
      await Future<void>.delayed(Duration.zero);
      expect(
        store.settings.sessionTabs[selection.storageKey]!.tabs.map(
          (tab) => tab.targetId,
        ),
        contains(terminal.id),
      );

      final second = notifier.openPendingTerminal(promoted.focusedPaneId);
      await notifier.removePendingTerminal(second);
      final rolled = container.read(provider).requireValue;
      expect(rolled.tabs.containsKey(second), isFalse);
      expect(rolled.tabs.containsKey(pendingId), isTrue);
    },
    tags: const <String>['feature_test__session_tabs__unit'],
  );

  test(
    'tab mutations complete without waiting for the settings write',
    () async {
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[worktree],
        agents: <SessionDto>[agent],
      );
      final container = ProviderContainer(
        overrides: [
          appServicesProvider.overrideWithValue(fakeAppServices(api)),
          appIdGeneratorProvider.overrideWithValue(const _FixedIdGenerator()),
          hostRegistryControllerProvider.overrideWith(_StalledSaveRegistry.new),
        ],
      );
      addTearDown(container.dispose);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      const selection = WorkspaceSelection(
        hostId: 'server',
        workspaceId: 'workspace',
        worktreeId: 'worktree',
      );
      final provider = sessionTabsControllerProvider(selection);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final initial = await container.read(provider.future);

      // The settings write never completes, yet the mutation resolves and the
      // state is already updated: navigation is not gated on disk I/O.
      var completed = false;
      unawaited(
        container
            .read(provider.notifier)
            .add(agent, draftTabId: initial.focusedTabId)
            .then((_) => completed = true),
      );
      await Future<void>.delayed(Duration.zero);
      expect(completed, isTrue);
      expect(
        container.read(provider).requireValue.focusedTab?.target,
        const SessionTabTarget('agent'),
      );
    },
    tags: const <String>['feature_test__session_tabs__unit'],
  );
}

final class _StalledSaveRegistry extends HostRegistryController {
  @override
  Future<void> saveWorkspaceUi({
    required WorkspaceSelection selection,
    required SessionTabPreference tabs,
  }) => Completer<void>().future;
}
