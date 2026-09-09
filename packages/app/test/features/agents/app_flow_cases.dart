part of '../../app/app_flows_test.dart';

Future<void> _centerAgentSettingsAction(
  WidgetTester tester,
  Finder action,
) async {
  await tester.scrollUntilVisible(
    action,
    TRSpacing.fourExtraLarge,
    scrollable: find
        .descendant(
          of: find.byType(SettingsScaffold),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await Scrollable.ensureVisible(tester.element(action), alignment: 0.5);
  await tester.pumpAndSettle();
}

void _registerAgentsAppFlows() {
  testWidgets(
    'agent event refresh does not leak a client error after disposal',
    (tester) async {
      await _setTestViewport(tester, const Size(1200, 900));
      final api = FakeTinestApi();
      final router = await _pumpRoute(
        tester,
        api,
        const AgentSettingsRoute(hostId: 'server').location,
      );
      addTearDown(router.dispose);

      final refreshGate = Completer<void>();
      api.agentDefinitionsGate = refreshGate.future;
      final callsBeforeEvent = api.agentDefinitionsListCount;
      api.emit(const McpServersChangedClientEvent());
      await tester.pump();
      expect(api.agentDefinitionsListCount, callsBeforeEvent + 1);

      await tester.pumpWidget(const SizedBox.shrink());
      refreshGate.completeError(
        const TinestClientException(
          'The client closed with a pending request.',
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
    tags: const <String>['feature_test__agent_definition_management__widget'],
  );

  testWidgets('agent collection explains that no definitions are configured', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(1200, 900));
    final api = FakeTinestApi(agentDefinitions: const <AgentDefinitionDto>[]);
    final router = await _pumpRoute(
      tester,
      api,
      const AgentSettingsRoute(hostId: 'server').location,
    );
    addTearDown(router.dispose);

    expect(find.text('설정된 Agent가 없습니다.'), findsOneWidget);
    // The detail destination still explains that it needs a selection; the
    // collection itself owns the distinct no-data copy above.
    expect(find.text('Agent를 선택하세요.'), findsOneWidget);
  }, tags: const <String>['feature_test__agent_definition_management__widget']);

  testWidgets('agent settings edits v5 definitions and creates subagents', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = FakeTinestApi();
    final router = await _pumpRoute(
      tester,
      api,
      const AgentSettingsRoute(hostId: 'server').location,
    );
    addTearDown(router.dispose);

    expect(find.byType(TRTreeNav<String>), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TRPaneHeader),
        matching: find.text(testL10n.agentSettingsHeading),
      ),
      findsOneWidget,
    );
    expect(find.text('Tinest'), findsWidgets);
    final prompt = _textInput('시스템 프롬프트 (Markdown)');
    await tester.enterText(prompt, 'Always run focused tests.');
    await tester.tap(find.widgetWithText(TRButton, '저장'));
    await tester.pumpAndSettle();
    expect(
      (await api.agents.getAgentDefinition('tinest')).prompt,
      'Always run focused tests.',
    );
    expect(find.text('Custom system prompt 사용'), findsNothing);
    final settingsScroll = find
        .descendant(
          of: find.byType(SettingsScaffold),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('agent-tool-group-filesystem')),
      400,
      scrollable: settingsScroll,
    );
    expect(
      find.byKey(const ValueKey<String>('agent-tool-group-filesystem')),
      findsOneWidget,
    );

    // Tools are behind their group, so nothing is listed until one opens.
    expect(
      find.byKey(
        const ValueKey<String>('agent-tool-tile-tinest.files-read_file'),
      ),
      findsNothing,
    );
    // The selected read tool is still independently configurable.
    final filesystemGroup = tester.widget<TinestCheckboxRow>(
      find.byKey(const ValueKey<String>('agent-tool-group-filesystem')),
    );
    expect(filesystemGroup.value, isTrue);
    expect(filesystemGroup.onChanged, isNotNull);

    // scrollUntilVisible stops as soon as the row is built, which leaves it
    // under the pinned save bar. Bring it fully into the viewport before
    // aiming a pointer at it.
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('agent-tool-group-filesystem')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('agent-tool-group-filesystem')),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(
        const ValueKey<String>('agent-tool-tile-tinest.files-read_file'),
      ),
      400,
      scrollable: settingsScroll,
    );
    await tester.ensureVisible(
      find.byKey(
        const ValueKey<String>('agent-tool-tile-tinest.files-read_file'),
      ),
    );
    await tester.pumpAndSettle();
    final readFile = tester.widget<TinestCheckboxRow>(
      find.byKey(
        const ValueKey<String>('agent-tool-tile-tinest.files-read_file'),
      ),
    );
    expect(readFile.value, isTrue);
    expect(readFile.onChanged, isNotNull);
    expect(
      find.byKey(const ValueKey<String>('agent-tool-lock-read_file')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(
        const ValueKey<String>('agent-tool-tile-tinest.files-read_file'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TinestCheckboxRow>(
            find.byKey(
              const ValueKey<String>('agent-tool-tile-tinest.files-read_file'),
            ),
          )
          .value,
      isFalse,
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('agent-tool-group-execution')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('agent-tool-group-execution')),
    );
    await tester.pumpAndSettle();
    final toggleable = tester.widget<TinestCheckboxRow>(
      find.byKey(
        const ValueKey<String>('agent-tool-tile-tinest.terminal-exec_command'),
      ),
    );
    expect(toggleable.onChanged, isNotNull);

    await tester.tap(find.byKey(const ValueKey('agent-add-button')));
    await tester.pumpAndSettle();
    expect(find.byType(TRAlertDialog), findsNothing);
    expect(find.text('Agent 추가'), findsOneWidget);
    await tester.enterText(_textInput('ID (파일명)'), 'reviewer');
    await tester.enterText(_textInput('이름').last, 'Reviewer');
    await tester.tap(find.byType(TRSelectFormField<AgentMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('subagent').last);
    tester.testTextInput.hide();
    final createButton = find.widgetWithText(TRButton, '생성');
    await tester.ensureVisible(createButton);
    await tester.pumpAndSettle();
    await tester.tap(createButton);
    await tester.pumpAndSettle();
    expect(find.text('Reviewer'), findsWidgets);
    final created = await api.agents.getAgentDefinition('reviewer');
    expect(created.version, 5);
    expect(created.mode, AgentMode.subagent);
    expect(created.prompt, isEmpty);
    expect(created.driverId, 'tinest.standard/driver');
    expect(created.extensionIds, isEmpty);
    expect(created.pluginSettings, isEmpty);

    // The adaptive settings navigator can retain more than one lazily built
    // pane while replacing the create destination with the new editor. The
    // new definition must expose its own scroll owner so automation and
    // keyboard reveal target that editor instead of an offstage pane.
    final reviewerEditor = find.byKey(
      const ValueKey<String>('agent-settings-editor-reviewer'),
    );
    expect(reviewerEditor, findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('agent-archive-button')),
      400,
      scrollable: find
          .descendant(of: reviewerEditor, matching: find.byType(Scrollable))
          .first,
    );
    expect(
      find.byKey(const ValueKey<String>('agent-archive-button')),
      findsOneWidget,
    );
  }, tags: const <String>['feature_test__agent_definition_management__widget']);

  testWidgets(
    'agent create validates input and keeps daemon failures in the pane',
    (tester) async {
      await _setTestViewport(tester, const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi(failNextAgentCreate: true);
      final router = await _pumpRoute(
        tester,
        api,
        const AgentSettingsRoute(hostId: 'server').location,
      );
      addTearDown(router.dispose);

      await tester.tap(find.byKey(const ValueKey('agent-add-button')));
      await tester.pumpAndSettle();
      var create = tester.widget<TRButton>(find.widgetWithText(TRButton, '생성'));
      expect(create.onPressed, isNull);

      await tester.enterText(_textInput('ID (파일명)'), 'Invalid ID');
      await tester.enterText(_textInput('이름').last, 'Reviewer');
      await tester.pumpAndSettle();
      expect(find.text('영문 소문자, 숫자, -, _만 사용할 수 있습니다.'), findsOneWidget);

      await tester.enterText(_textInput('ID (파일명)'), 'tinest');
      await tester.pumpAndSettle();
      expect(find.text('이미 존재하는 Agent ID입니다.'), findsOneWidget);

      await tester.enterText(_textInput('ID (파일명)'), 'reviewer');
      await tester.pumpAndSettle();
      create = tester.widget<TRButton>(find.widgetWithText(TRButton, '생성'));
      expect(create.onPressed, isNotNull);
      await tester.tap(find.widgetWithText(TRButton, '생성'));
      await tester.pumpAndSettle();
      final errorAlert = find.ancestor(
        of: find.textContaining('agent_create_failed'),
        matching: find.byType(TRAlert),
      );
      expect(errorAlert, findsOneWidget);
      expect(
        tester.widget<TRAlert>(errorAlert).variant,
        TRStatusVariant.danger,
      );
      expect(find.textContaining('agent_create_failed'), findsOneWidget);
      expect(find.text('Agent 추가'), findsWidgets);

      await tester.tap(find.widgetWithText(TRButton, '생성'));
      await tester.pumpAndSettle();
      expect(find.text('Agent 추가'), findsNothing);
      expect(find.text('Reviewer'), findsWidgets);
    },
  );

  testWidgets(
    'fixed agent model explains the missing provider without opening a picker',
    (tester) async {
      await _setTestViewport(tester, const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const fixedAgent = AgentDefinitionDto(
        version: 5,
        id: 'tinest',
        name: 'Tinest',
        description: 'General coding',
        mode: AgentMode.primary,
        model: AgentModelSelectionDto(
          source: AgentModelSource.fixed,
          modelId: 'openai/gpt-5.6-sol',
        ),
        driverId: 'tinest.standard/driver',
        extensionIds: <String>[],
        toolIds: <String>[],
        pluginSettings: <String, Map<String, dynamic>>{},
        callableAgentIds: <String>[],
        prompt: '',
        contentHash: 'fixed-agent-hash',
        sourcePath: '/config/agents/tinest.md',
        isBuiltIn: true,
      );
      final api = FakeTinestApi(
        agentDefinitions: const <AgentDefinitionDto>[fixedAgent],
        connections: const <ProviderConnectionDto>[],
      );
      final router = await _pumpRoute(
        tester,
        api,
        const AgentSettingsRoute(hostId: 'server').location,
      );
      addTearDown(router.dispose);
      await tester.pumpAndSettle();

      final modelRow = find.byKey(
        const ValueKey<String>('agent-settings-model-selector'),
      );
      await tester.ensureVisible(modelRow);
      final modelSection = find.ancestor(
        of: modelRow,
        matching: find.byType(SettingsSection),
      );
      final modelLabel = find.descendant(
        of: modelRow,
        matching: find.text(testL10n.agentSettingsModelId),
      );
      final modelHeading = find.descendant(
        of: modelSection,
        matching: find.text(testL10n.agentSettingsModelHeading),
      );
      expect(modelLabel, findsOneWidget);
      expect(modelHeading, findsOneWidget);
      expect(
        tester.getRect(modelLabel).left,
        tester.getRect(modelHeading).left,
      );
      expect(
        find.descendant(of: modelRow, matching: find.byIcon(TinestIcons.lock)),
        findsOneWidget,
      );
      expect(
        tester
            .widgetList<TRText>(
              find.descendant(of: modelRow, matching: find.byType(TRText)),
            )
            .first
            .color,
        TRTextColor.muted,
      );
      expect(
        tester.getSemantics(modelRow).hint,
        testL10n.composerConnectProviderFirst,
      );
      final container = ProviderScope.containerOf(tester.element(modelRow));
      final toasts = container.read(appToastControllerProvider);

      final lockIcon = find.descendant(
        of: modelRow,
        matching: find.byIcon(TinestIcons.lock),
      );
      final blockedControl = find.descendant(
        of: modelRow,
        matching: find.byType(BlockedControl),
      );
      await tester.scrollUntilVisible(
        lockIcon,
        TRSpacing.extraLarge,
        scrollable: find
            .ancestor(of: modelRow, matching: find.byType(Scrollable))
            .first,
      );
      await tester.pumpAndSettle();
      tester.widget<BlockedControl>(blockedControl).onTap();
      await tester.pumpAndSettle();

      expect(find.byType(AsyncModelSelect), findsOneWidget);
      expect(toasts.toasts, hasLength(1));
      expect(toasts.toasts.single.variant, TRStatusVariant.info);
      expect(
        (toasts.toasts.single.title as TRText).data,
        testL10n.composerConnectProviderFirst,
      );

      Focus.of(
        tester.element(
          find
              .descendant(of: modelRow, matching: find.byType(MouseRegion))
              .first,
        ),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(toasts.toasts, hasLength(1));
    },
    tags: const <String>[
      'feature_test__agent_definition_management__widget',
      'feature_test__app_toast__widget',
    ],
  );

  testWidgets(
    'agent model switch snapshots a concrete model and clears it when off',
    (tester) async {
      await _setTestViewport(tester, const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi();
      final router = await _pumpRoute(
        tester,
        api,
        const AgentSettingsRoute(hostId: 'server').location,
      );
      addTearDown(router.dispose);
      await tester.pumpAndSettle();

      final fixedModel = find.byKey(
        const ValueKey<String>('agent-settings-model-source-fixed'),
      );
      final sessionModel = find.byKey(
        const ValueKey<String>('agent-settings-model-source-session'),
      );
      expect(
        tester.widget<TRRadioGroup>(find.byType(TRRadioGroup)).value,
        AgentModelSource.session.name,
      );

      await tester.tap(fixedModel);
      await tester.pumpAndSettle();
      expect(find.byType(AsyncModelSelect), findsOneWidget);
      await tester.tap(find.widgetWithText(TRButton, '저장'));
      await tester.pumpAndSettle();
      expect(
        (await api.agents.getAgentDefinition('tinest')).model,
        const AgentModelSelectionDto(
          source: AgentModelSource.fixed,
          modelId: 'openai/gpt-5.6-sol',
        ),
      );

      await tester.tap(sessionModel);
      await tester.pumpAndSettle();
      expect(find.byType(AsyncModelSelect), findsNothing);
      await tester.tap(find.widgetWithText(TRButton, '저장'));
      await tester.pumpAndSettle();
      expect(
        (await api.agents.getAgentDefinition('tinest')).model,
        const AgentModelSelectionDto(source: AgentModelSource.session),
      );
    },
    tags: const <String>[
      'feature_test__agent_definition_management__widget',
      'feature_test__model_settings__widget',
    ],
  );

  testWidgets(
    'agent model switch cannot save without a concrete runnable option',
    (tester) async {
      await _setTestViewport(tester, const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi(connections: const <ProviderConnectionDto>[]);
      final router = await _pumpRoute(
        tester,
        api,
        const AgentSettingsRoute(hostId: 'server').location,
      );
      addTearDown(router.dispose);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('agent-settings-model-source-fixed')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AsyncModelSelect), findsOneWidget);
      expect(find.byType(BlockedControl), findsOneWidget);
      expect(
        tester.widget<TRButton>(find.widgetWithText(TRButton, '저장')).onPressed,
        isNull,
      );
    },
    tags: const <String>[
      'feature_test__agent_definition_management__widget',
      'feature_test__model_settings__widget',
    ],
  );

  testWidgets('mobile agent settings navigates from list to Markdown detail', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = FakeTinestApi();
    final router = await _pumpRoute(
      tester,
      api,
      const AgentSettingsRoute(hostId: 'server').location,
    );
    addTearDown(router.dispose);

    expect(find.text(testL10n.agentSettingsHeading), findsOneWidget);
    expect(_textField('시스템 프롬프트 (Markdown)'), findsNothing);
    await tester.tap(find.text('Tinest').first);
    await tester.pumpAndSettle();
    expect(_textField('시스템 프롬프트 (Markdown)'), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-list-button')), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey<String>('settings-back-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text(testL10n.agentSettingsHeading), findsOneWidget);
  });

  testWidgets(
    'agent editor handles conflicts, policy controls, reset, and archive',
    (tester) async {
      await _setTestViewport(tester, const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const tinest = AgentDefinitionDto(
        version: 5,
        id: 'tinest',
        name: 'Tinest',
        description: 'General coding',
        mode: AgentMode.primary,
        model: AgentModelSelectionDto(source: AgentModelSource.session),
        driverId: 'tinest.standard/driver',
        extensionIds: <String>['tinest.standard'],
        toolIds: <String>['tinest.files/read_file'],
        pluginSettings: <String, Map<String, dynamic>>{
          'tinest.standard': <String, dynamic>{'tone': 'careful'},
        },
        callableAgentIds: <String>[],
        prompt: 'Code carefully.',
        contentHash: 'tinest-hash',
        sourcePath: '/config/agents/tinest.md',
        isBuiltIn: true,
        diagnostics: <AgentDefinitionDiagnosticDto>[
          AgentDefinitionDiagnosticDto(
            code: 'unavailable_tool',
            message: 'A future tool is unavailable.',
          ),
        ],
      );
      const reviewer = AgentDefinitionDto(
        version: 5,
        id: 'reviewer',
        name: 'Reviewer',
        description: 'Reviews changes',
        mode: AgentMode.subagent,
        model: AgentModelSelectionDto(source: AgentModelSource.session),
        driverId: 'tinest.standard/driver',
        extensionIds: <String>[],
        toolIds: <String>['tinest.files/read_file'],
        pluginSettings: <String, Map<String, dynamic>>{},
        callableAgentIds: <String>[],
        prompt: 'Review.',
        contentHash: 'reviewer-hash',
        sourcePath: '/config/agents/reviewer.md',
      );
      final api = FakeTinestApi(
        agentDefinitions: const <AgentDefinitionDto>[tinest, reviewer],
        failNextAgentUpdate: true,
      );
      final router = await _pumpRoute(
        tester,
        api,
        const AgentSettingsRoute(hostId: 'server').location,
      );
      addTearDown(router.dispose);

      expect(find.text('unavailable_tool'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('agent-permission-change')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('agent-copy-path-button')));
      final settingsScroll = find
          .descendant(
            of: find.byType(SettingsScaffold),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('agent-settings-model-source-fixed')),
        300,
        scrollable: settingsScroll,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('agent-settings-model-source-fixed')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TRSelect<ModelPickerOption>).last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('model-option-openai-gpt-5.6-sol')),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('agent-settings-model-selector'),
          ),
          matching: find.text('GPT-5.6 Sol'),
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('agent-callable-reviewer')),
        400,
        scrollable: settingsScroll,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('agent-callable-reviewer')),
      );
      await tester.tap(find.widgetWithText(TRButton, '저장'));
      await tester.pumpAndSettle();
      expect(find.text('Agent 저장 실패'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(TRButton, testL10n.agentSettingsOverwrite),
      );
      await tester.pumpAndSettle();

      final updated = await api.agents.getAgentDefinition('tinest');
      expect(updated.version, 5);
      expect(updated.prompt, 'Code carefully.');
      expect(updated.model.modelId, 'openai/gpt-5.6-sol');
      expect(updated.driverId, 'tinest.standard/driver');
      expect(updated.extensionIds, <String>['tinest.standard']);
      expect(updated.toolIds, <String>['tinest.files/read_file']);
      expect(updated.pluginSettings, <String, Map<String, dynamic>>{
        'tinest.standard': <String, dynamic>{'tone': 'careful'},
      });
      expect(updated.callableAgentIds, <String>['reviewer']);

      final reset = find.byKey(const ValueKey('agent-reset-button'));
      await _centerAgentSettingsAction(tester, reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('agent-reset-confirm')),
      );
      await tester.pumpAndSettle();
      expect(
        (await api.agents.getAgentDefinition('tinest')).prompt,
        'Code carefully.',
      );
      await tester.tap(find.text('Reviewer').first);
      await tester.pumpAndSettle();
      final archive = find.byKey(const ValueKey('agent-archive-button'));
      await _centerAgentSettingsAction(tester, archive);
      await tester.tap(archive);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('agent-archive-confirm')),
      );
      await tester.pumpAndSettle();
      expect(
        (await api.agents.listAgentDefinitions()).map(
          (definition) => definition.id,
        ),
        isNot(contains('reviewer')),
      );
    },
    tags: const <String>['feature_test__agent_collaboration__widget'],
  );

  testWidgets(
    'remote agent settings stays editable and exposes load errors',
    (tester) async {
      await _setTestViewport(tester, const Size(1400, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const remoteInfo = ServerInfoDto(
        serverId: 'server',
        version: 'test',
        protocolVersion: tinestProtocolMajor,
        features: <String, bool>{},
      );
      final remoteRouter = await _pumpRoute(
        tester,
        FakeTinestApi(serverInfo: remoteInfo),
        const AgentSettingsRoute(hostId: 'server').location,
      );
      expect(find.textContaining('읽기만'), findsNothing);
      expect(
        tester
            .widget<TRIconButton>(
              find.widgetWithIcon(TRIconButton, TinestIcons.add),
            )
            .onPressed,
        isNotNull,
      );
      remoteRouter.dispose();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      final errorRouter = await _pumpRoute(
        tester,
        FakeTinestApi(agentListError: Exception('definition load failed')),
        const AgentSettingsRoute(hostId: 'server').location,
        settle: false,
      );
      addTearDown(errorRouter.dispose);
      // Settings owns an explicit Retry action. Riverpod's default backoff
      // would otherwise replace this error with a loading skeleton for tens
      // of seconds.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SettingsSkeletonLayout), findsNothing);
      expect(find.textContaining('definition load failed'), findsOneWidget);
      expect(find.widgetWithText(TRButton, '다시 시도'), findsOneWidget);
      await tester.tap(find.widgetWithText(TRButton, '다시 시도'));
      await tester.pumpAndSettle();
      expect(find.textContaining('definition load failed'), findsOneWidget);
    },
    tags: const <String>[
      'feature_test__agent_definition_management__widget',
      'feature_test__settings_async_loading__widget',
    ],
  );

  testWidgets('agent prompt remains savable while the plugin catalog loads', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(1200, 900));
    final pluginListGate = Completer<void>();
    addTearDown(() {
      if (!pluginListGate.isCompleted) pluginListGate.complete();
    });
    final api = FakeTinestApi(pluginListGate: pluginListGate.future);
    final router = await _pumpRoute(
      tester,
      api,
      const AgentSettingsRoute(hostId: 'server').location,
    );
    addTearDown(router.dispose);

    await tester.enterText(
      _textInput('시스템 프롬프트 (Markdown)'),
      'Save before the catalog resolves.',
    );
    final save = find.widgetWithText(TRButton, '저장');
    expect(tester.widget<TRButton>(save).onPressed, isNotNull);
    await tester.tap(save);
    await tester.pump();
    expect(
      (await api.agents.getAgentDefinition('tinest')).prompt,
      'Save before the catalog resolves.',
    );
  });

  testWidgets('an Agent save may finish after its editor unmounts', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(1200, 900));
    final updateGate = Completer<void>();
    addTearDown(() {
      if (!updateGate.isCompleted) updateGate.complete();
    });
    final api = FakeTinestApi(agentUpdateGate: updateGate.future);
    final router = await _pumpRoute(
      tester,
      api,
      const AgentSettingsRoute(hostId: 'server').location,
    );
    addTearDown(router.dispose);

    await tester.enterText(
      _textInput('시스템 프롬프트 (Markdown)'),
      'Finish safely after navigation.',
    );
    await tester.tap(find.widgetWithText(TRButton, '저장'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    updateGate.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      (await api.agents.getAgentDefinition('tinest')).prompt,
      'Finish safely after navigation.',
    );
  });

  testWidgets(
    'resetting a built-in agent asks first and reports what it did',
    (tester) async {
      await _setTestViewport(tester, const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi();
      final router = await _pumpRoute(
        tester,
        api,
        const AgentSettingsRoute(hostId: 'server').location,
      );
      addTearDown(router.dispose);

      // Edit first, so a reset that runs has something to undo.
      await tester.enterText(
        _textInput('시스템 프롬프트 (Markdown)'),
        'Always run focused tests.',
      );
      await tester.tap(find.widgetWithText(TRButton, '저장'));
      await tester.pumpAndSettle();

      final reset = find.byKey(const ValueKey<String>('agent-reset-button'));
      await _centerAgentSettingsAction(tester, reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TRButton, '취소'));
      await tester.pumpAndSettle();
      expect(
        (await api.agents.getAgentDefinition('tinest')).prompt,
        'Always run focused tests.',
        reason: 'declining the question must not discard the edit',
      );

      await _centerAgentSettingsAction(tester, reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('agent-reset-confirm')),
      );
      await tester.pumpAndSettle();
      expect(find.text('기본 Agent로 되돌렸습니다.'), findsOneWidget);
    },
    tags: const <String>[
      'feature_test__agent_definition_management__widget',
      'feature_test__app_toast__widget',
    ],
  );

  testWidgets('a tool group header turns its whole group on and off at once', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = FakeTinestApi();
    final router = await _pumpRoute(
      tester,
      api,
      const AgentSettingsRoute(hostId: 'server').location,
    );
    addTearDown(router.dispose);

    final scrollable = find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first;
    // scrollUntilVisible stops as soon as the row is built, which a list
    // builds before it is on screen, so the row still has to be brought
    // fully into view before it can be tapped.
    Future<void> reveal(String key) async {
      final finder = find.byKey(ValueKey<String>(key));
      await tester.scrollUntilVisible(finder, 200, scrollable: scrollable);
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
    }

    TinestCheckboxRow rowFor(String key) =>
        tester.widget<TinestCheckboxRow>(find.byKey(ValueKey<String>(key)));

    await reveal('agent-tool-group-mcp');
    final initial = rowFor('agent-tool-group-mcp');
    expect(initial.value, isFalse);
    expect(initial.indeterminate, isFalse);

    // Checking the header takes every tool in the group, not just one.
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey<String>('agent-tool-group-mcp')),
        matching: find.byType(TRCheckbox),
      ),
    );
    await tester.pumpAndSettle();
    expect(rowFor('agent-tool-group-mcp').value, isTrue);

    await tester.tap(find.widgetWithText(TRButton, '저장'));
    await tester.pumpAndSettle();
    expect((await api.agents.getAgentDefinition('tinest')).toolIds, <String>[
      'tinest.files/read_file',
      'tinest.mcp/list_mcp_resource_templates',
      'tinest.mcp/list_mcp_resources',
      'tinest.mcp/read_mcp_resource',
    ], reason: 'a group is stored as the ids it contains, not as itself');

    // Turning one member off leaves the header partially checked.
    await reveal('agent-tool-group-mcp');
    await tester.tap(
      find.byKey(const ValueKey<String>('agent-tool-group-mcp')),
    );
    await tester.pumpAndSettle();
    await reveal('agent-tool-tile-tinest.mcp-read_mcp_resource');
    await tester.tap(
      find.byKey(
        const ValueKey<String>('agent-tool-tile-tinest.mcp-read_mcp_resource'),
      ),
    );
    await tester.pumpAndSettle();
    await reveal('agent-tool-group-mcp');
    final partial = rowFor('agent-tool-group-mcp');
    expect(partial.value, isFalse);
    expect(partial.indeterminate, isTrue);
  }, tags: const <String>['feature_test__agent_definition_management__widget']);

  testWidgets(
    'agent harness edits driver ordered extensions tools settings and grants',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const definition = AgentDefinitionDto(
        version: 5,
        id: 'tinest',
        name: 'Tinest',
        description: 'Plugin harness',
        mode: AgentMode.primary,
        model: AgentModelSelectionDto(source: AgentModelSource.session),
        driverId: 'tinest.standard/driver',
        extensionIds: <String>['tinest.plan'],
        toolIds: <String>['tinest.files/read_file'],
        pluginSettings: <String, Map<String, dynamic>>{
          'tinest.plan': <String, dynamic>{'mode': 'guided'},
        },
        callableAgentIds: <String>[],
        prompt: 'Use the configured harness.',
        contentHash: 'tinest-harness-hash',
        sourcePath: '/config/v5/agents/tinest.md',
        isBuiltIn: true,
      );
      final api = FakeTinestApi(
        agentDefinitions: const <AgentDefinitionDto>[definition],
        plugins: _agentHarnessPlugins,
      );
      final router = await _pumpRoute(
        tester,
        api,
        const AgentSettingsRoute(hostId: 'server').location,
      );
      addTearDown(router.dispose);

      final driverFinder = find.byKey(
        const ValueKey<String>('agent-plugin-driver'),
      );
      expect(driverFinder, findsOneWidget);
      final driver = tester.widget<TRSelect<String>>(driverFinder);
      expect(driver.value, 'tinest.standard/driver');
      expect(driver.presentation, isA<TRSelectLayerPresentation>());
      expect(
        driver.items.map((item) => item.value),
        contains('acme.xml/driver'),
      );
      driver.onValueChange?.call('acme.xml/driver');
      await tester.pumpAndSettle();

      final scrollable = find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first;
      Future<void> reveal(String key) async {
        final finder = find.byKey(ValueKey<String>(key));
        await tester.scrollUntilVisible(finder, 260, scrollable: scrollable);
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
      }

      await reveal('agent-extension-tinest.goal');
      await tester.tap(
        find.byKey(const ValueKey<String>('agent-extension-tinest.goal')),
      );
      await tester.pumpAndSettle();
      await reveal('agent-extension-up-tinest.goal');
      await tester.tap(
        find.byKey(const ValueKey<String>('agent-extension-up-tinest.goal')),
      );
      await tester.pumpAndSettle();

      await reveal('agent-tool-group-editing');
      await tester.tap(
        find.byKey(const ValueKey<String>('agent-tool-group-editing')),
      );
      await tester.pumpAndSettle();
      await reveal('agent-tool-tile-tinest.edit-apply_patch');
      await tester.tap(
        find.byKey(
          const ValueKey<String>('agent-tool-tile-tinest.edit-apply_patch'),
        ),
      );
      await tester.pumpAndSettle();

      await reveal('agent-plugin-settings-tinest.plan');
      await tester.enterText(
        find.byKey(const ValueKey<String>('agent-plugin-settings-tinest.plan')),
        '{"mode":"strict","maxSteps":4}',
      );
      await tester.pumpAndSettle();

      await reveal('agent-plugin-grant-tinest.files-workspace.read');
      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'agent-plugin-grant-tinest.files-workspace.read',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TRSwitch>(
              find.byKey(
                const ValueKey<String>(
                  'agent-plugin-grant-tinest.files-workspace.read',
                ),
              ),
            )
            .checked,
        isTrue,
      );

      await tester.tap(find.widgetWithText(TRButton, '저장'));
      await tester.pumpAndSettle();
      final saved = await api.agents.getAgentDefinition('tinest');
      expect(saved.driverId, 'acme.xml/driver');
      expect(saved.extensionIds, <String>['tinest.goal', 'tinest.plan']);
      expect(
        saved.toolIds,
        containsAll(<String>[
          'tinest.files/read_file',
          'tinest.edit/apply_patch',
        ]),
      );
      expect(saved.pluginSettings['tinest.plan'], <String, dynamic>{
        'mode': 'strict',
        'maxSteps': 4,
      });
      expect(
        await api.plugins.listPluginGrants('tinest'),
        contains(
          const AgentPluginGrantDto(
            agentId: 'tinest',
            pluginId: 'tinest.files',
            capability: 'workspace.read',
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('agent-session-driver-override')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('plugin-global-enable')),
        findsNothing,
      );
    },
    tags: const <String>[
      'feature_test__agent_harness__widget',
      'feature_test__plugin_permissions__widget',
      'route_test__agent_settings_route__widget',
    ],
  );

  testWidgets(
    'mobile agent harness reports missing dependencies and model mismatch',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const definition = AgentDefinitionDto(
        version: 5,
        id: 'broken',
        name: 'Broken harness',
        description: 'Invalid references',
        mode: AgentMode.primary,
        model: AgentModelSelectionDto(
          source: AgentModelSource.fixed,
          modelId: 'openai/gpt-5.6-sol',
        ),
        driverId: 'acme.xml/driver',
        extensionIds: <String>['missing.plugin'],
        toolIds: <String>['missing.plugin/tool'],
        pluginSettings: <String, Map<String, dynamic>>{},
        callableAgentIds: <String>[],
        prompt: 'This should be diagnosed.',
        contentHash: 'broken-hash',
        sourcePath: '/config/v5/agents/broken.md',
      );
      final plugins = _agentHarnessPlugins
          .map(
            (plugin) => plugin.id == 'acme.xml'
                ? plugin.copyWith(
                    contributions: <PluginContributionDto>[
                      plugin.contributions.single.copyWith(
                        metadata: const <String, dynamic>{
                          'name': 'XML driver',
                          'requiredModelCapabilities': <String>[
                            'deferred_tools',
                          ],
                          'dependencies': <String>['tinest.context'],
                        },
                      ),
                    ],
                  )
                : plugin,
          )
          .toList(growable: false);
      final api = FakeTinestApi(
        agentDefinitions: const <AgentDefinitionDto>[definition],
        plugins: plugins,
      );
      final router = await _pumpRoute(
        tester,
        api,
        const AgentSettingsRoute(hostId: 'server').location,
      );
      addTearDown(router.dispose);

      await tester.tap(find.text('Broken harness').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('agent-harness-diagnostics')),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('missing.plugin'), findsWidgets);
      expect(find.textContaining('missing.plugin/tool'), findsWidgets);
      expect(find.textContaining('tinest.context'), findsWidgets);
      expect(find.textContaining('deferred_tools'), findsWidgets);
      expect(
        tester.widget<TRButton>(find.widgetWithText(TRButton, '저장')).onPressed,
        isNull,
      );
    },
    tags: const <String>[
      'feature_test__agent_harness__widget',
      'feature_test__plugin_runtime__widget',
      'route_test__agent_settings_route__widget',
      'ui_state_test__agent_harness_diagnostics__mobile',
    ],
  );

  testWidgets(
    'agent harness diagnoses and blocks an absent driver',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const definition = AgentDefinitionDto(
        version: 5,
        id: 'no-driver',
        name: 'No driver',
        description: 'Incomplete harness',
        mode: AgentMode.primary,
        model: AgentModelSelectionDto(source: AgentModelSource.session),
        driverId: '',
        extensionIds: <String>[],
        toolIds: <String>[],
        pluginSettings: <String, Map<String, dynamic>>{},
        callableAgentIds: <String>[],
        prompt: '',
        contentHash: 'no-driver-hash',
        sourcePath: '/config/v5/agents/no-driver.md',
      );
      final api = FakeTinestApi(
        agentDefinitions: const <AgentDefinitionDto>[definition],
        plugins: _agentHarnessPlugins,
      );
      final router = await _pumpRoute(
        tester,
        api,
        const AgentSettingsRoute(hostId: 'server').location,
      );
      addTearDown(router.dispose);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('agent-harness-diagnostics')),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('driver'), findsWidgets);
      expect(
        tester.widget<TRButton>(find.widgetWithText(TRButton, '저장')).onPressed,
        isNull,
      );
    },
    tags: const <String>[
      'feature_test__agent_harness__widget',
      'route_test__agent_settings_route__widget',
      'ui_state_test__agent_harness_diagnostics__desktop',
    ],
  );
}

const List<PluginDescriptorDto> _agentHarnessPlugins = <PluginDescriptorDto>[
  PluginDescriptorDto(
    apiMajor: 5,
    id: 'tinest.standard',
    version: '1.0.0',
    name: 'Standard',
    entrypoint: 'main.lua',
    source: PluginSource.builtIn,
    sourcePath: '/built-in/tinest.standard',
    requestedCapabilities: <String>['model.call'],
    contributions: <PluginContributionDto>[
      PluginContributionDto(
        pluginId: 'tinest.standard',
        id: 'driver',
        kind: PluginContributionKind.driver,
        metadata: <String, dynamic>{
          'name': 'Standard driver',
          'requiredModelCapabilities': <String>['streaming'],
        },
      ),
    ],
  ),
  PluginDescriptorDto(
    apiMajor: 5,
    id: 'acme.xml',
    version: '1.0.0',
    name: 'XML harness',
    entrypoint: 'main.lua',
    source: PluginSource.user,
    sourcePath: '/config/v5/plugins/acme.xml',
    requestedCapabilities: <String>['model.call'],
    contributions: <PluginContributionDto>[
      PluginContributionDto(
        pluginId: 'acme.xml',
        id: 'driver',
        kind: PluginContributionKind.driver,
        metadata: <String, dynamic>{
          'name': 'XML driver',
          'requiredModelCapabilities': <String>['streaming'],
        },
      ),
    ],
  ),
  PluginDescriptorDto(
    apiMajor: 5,
    id: 'tinest.plan',
    version: '1.0.0',
    name: 'Plan',
    entrypoint: 'main.lua',
    source: PluginSource.builtIn,
    sourcePath: '/built-in/tinest.plan',
    requestedCapabilities: <String>['state.write'],
    contributions: <PluginContributionDto>[
      PluginContributionDto(
        pluginId: 'tinest.plan',
        id: 'before-turn',
        kind: PluginContributionKind.extension,
        metadata: <String, dynamic>{'lifecycle': 'before_turn'},
      ),
    ],
  ),
  PluginDescriptorDto(
    apiMajor: 5,
    id: 'tinest.goal',
    version: '1.0.0',
    name: 'Goal',
    entrypoint: 'main.lua',
    source: PluginSource.builtIn,
    sourcePath: '/built-in/tinest.goal',
    requestedCapabilities: <String>['state.write'],
    contributions: <PluginContributionDto>[
      PluginContributionDto(
        pluginId: 'tinest.goal',
        id: 'after-turn',
        kind: PluginContributionKind.extension,
        metadata: <String, dynamic>{'lifecycle': 'after_turn'},
      ),
    ],
  ),
  PluginDescriptorDto(
    apiMajor: 5,
    id: 'tinest.files',
    version: '1.0.0',
    name: 'Files',
    entrypoint: 'main.lua',
    source: PluginSource.builtIn,
    sourcePath: '/built-in/tinest.files',
    requestedCapabilities: <String>['workspace.read'],
    contributions: <PluginContributionDto>[
      PluginContributionDto(
        pluginId: 'tinest.files',
        id: 'tinest.files/read_file',
        kind: PluginContributionKind.tool,
        requiredCapabilities: <String>['workspace.read'],
        tool: AgentToolDefinitionDto(
          id: 'tinest.files/read_file',
          originPluginId: 'tinest.files',
          contributionId: 'read_file',
          name: 'Read file',
          description: 'Read a workspace file.',
          risk: ToolRisk.read,
          group: 'filesystem',
          kind: AgentToolKind.function,
          inputSchema: <String, dynamic>{'type': 'object'},
          effects: <String>['filesystem.read'],
          presentation: <String, dynamic>{'group': 'filesystem'},
        ),
      ),
    ],
  ),
  PluginDescriptorDto(
    apiMajor: 5,
    id: 'tinest.edit',
    version: '1.0.0',
    name: 'Edit',
    entrypoint: 'main.lua',
    source: PluginSource.builtIn,
    sourcePath: '/built-in/tinest.edit',
    requestedCapabilities: <String>['workspace.patch'],
    contributions: <PluginContributionDto>[
      PluginContributionDto(
        pluginId: 'tinest.edit',
        id: 'tinest.edit/apply_patch',
        kind: PluginContributionKind.tool,
        requiredCapabilities: <String>['workspace.patch'],
        tool: AgentToolDefinitionDto(
          id: 'tinest.edit/apply_patch',
          originPluginId: 'tinest.edit',
          contributionId: 'apply_patch',
          name: 'Apply patch',
          description: 'Apply a patch to the workspace.',
          risk: ToolRisk.write,
          group: 'editing',
          kind: AgentToolKind.function,
          inputSchema: <String, dynamic>{
            'type': 'object',
            'properties': <String, dynamic>{
              'patch': <String, dynamic>{'type': 'string'},
            },
            'required': <String>['patch'],
          },
          effects: <String>['filesystem.write'],
          presentation: <String, dynamic>{'group': 'editing'},
        ),
      ),
    ],
  ),
];
