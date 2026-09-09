import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 2);
  const sessionModel = ModelSelectionDto(modelId: 'provider/model');

  test('protocol v5 exposes plugin-first typed contracts', () {
    expect(tinestProtocolMajor, 5);
    expect(tinestProtocolRevision, 4);
    expect(tinestWebSocketProtocol, 'tinyrack.tinest.v5');
    expect(workspacesCatalogProcedure.name, 'workspaces.catalog');
    expect(workspacesRefreshProcedure.name, 'workspaces.refresh');
    expect(workspacesUnregisterProcedure.name, 'workspaces.unregister');
    expect(
      workspacesSuggestDirectoriesProcedure.name,
      'workspaces.suggestDirectories',
    );
    expect(workspacesListBranchesProcedure.name, 'workspaces.listBranches');
    expect(workspacesCreateWorktreeProcedure.name, 'workspaces.createWorktree');
    expect(workspacesPreviewArchiveProcedure.name, 'workspaces.previewArchive');
    expect(
      workspacesArchiveWorktreeProcedure.name,
      'workspaces.archiveWorktree',
    );
    expect(
      workspacesGetProjectSettingsProcedure.name,
      'workspaces.getProjectSettings',
    );
    expect(
      workspacesSaveProjectSettingsProcedure.name,
      'workspaces.saveProjectSettings',
    );
    expect(
      agentsGetDefaultPermissionModeProcedure.name,
      'agents.getDefaultPermissionMode',
    );
    expect(
      agentsSetDefaultPermissionModeProcedure.name,
      'agents.setDefaultPermissionMode',
    );
    expect(agentsListProcedure.name, 'agents.list');
    expect(agentsUpdateProcedure.name, 'agents.update');
    expect(agentsListToolsProcedure.name, 'agents.listTools');
    expect(promptsListSkillsProcedure.name, 'prompts.listSkills');
    expect(promptsSkillsChangedNotification.name, 'prompts.skillsChanged');
    expect(workspacesSearchFilesProcedure.name, 'workspaces.searchFiles');
    expect(promptsListCommandsProcedure.name, 'prompts.listCommands');
    expect(promptsCommandsChangedNotification.name, 'prompts.commandsChanged');
    expect(sessionsListProcedure.name, 'sessions.list');
    expect(sessionsCreateProcedure.name, 'sessions.create');
    expect(sessionsUpdateSettingsProcedure.name, 'sessions.updateSettings');
  });

  test(
    'relay contracts round-trip status, offers, devices, and parameters',
    () {
      const status = RelayStatusDto(
        enabled: true,
        connected: false,
        endpoint: 'wss://relay.example/v1/ws',
        serverId: 'daemon-1',
      );
      final decodedStatus = RelayStatusDto.fromJson(status.toJson());
      expect(decodedStatus.enabled, isTrue);
      expect(decodedStatus.connected, isFalse);
      expect(decodedStatus.endpoint, status.endpoint);
      expect(decodedStatus.serverId, status.serverId);
      const endpoint = RelaySetEndpointParamsDto(
        endpoint: 'wss://self-hosted.example/v1/ws',
      );
      expect(
        RelaySetEndpointParamsDto.fromJson(endpoint.toJson()).endpoint,
        endpoint.endpoint,
      );

      final offer = RelayPairingOfferDto(
        url: 'https://tinest.example/pair#offer=test',
        expiresAt: now,
      );
      final decodedOffer = RelayPairingOfferDto.fromJson(offer.toJson());
      expect(decodedOffer.url, offer.url);
      expect(decodedOffer.expiresAt, now);

      final device = RelayDeviceDto(
        id: 'device-1',
        name: 'Phone',
        registeredAt: now,
        lastConnectedAt: null,
      );
      final decodedDevice = RelayDeviceDto.fromJson(device.toJson());
      expect(decodedDevice.id, device.id);
      expect(decodedDevice.name, device.name);
      expect(decodedDevice.registeredAt, now);
      expect(decodedDevice.lastConnectedAt, isNull);
      final list = RelayDeviceListDto.fromJson(
        RelayDeviceListDto(devices: <RelayDeviceDto>[device]).toJson(),
      );
      expect(list.devices.single.id, 'device-1');

      expect(
        RelaySetEnabledParamsDto.fromJson(
          const RelaySetEnabledParamsDto(enabled: true).toJson(),
        ).enabled,
        isTrue,
      );
      expect(
        RelayRevokeDeviceParamsDto.fromJson(
          const RelayRevokeDeviceParamsDto(deviceId: 'device-1').toJson(),
        ).deviceId,
        'device-1',
      );
      expect(const RelayEmptyParamsDto().toJson(), isEmpty);
      expect(
        () => RelayEmptyParamsDto.fromJson(const <String, dynamic>{'x': true}),
        throwsFormatException,
      );
    },
    tags: const <String>['feature_test__daemon_relay__contract'],
  );

  test('daemon permission defaults round-trip with full access', () {
    const settings = PermissionSettingsDto(
      defaultMode: PermissionMode.fullAccess,
    );
    expect(PermissionSettingsDto.fromJson(settings.toJson()), settings);
    expect(const PermissionSettingsDto().defaultMode, PermissionMode.ask);
  }, tags: const <String>['feature_test__permission_settings__contract']);

  test('a session always carries one concrete permission mode', () {
    final session = SessionDto(
      id: 'session',
      worktreeId: 'worktree',
      title: 'Run the migration',
      agentDefinitionId: 'tinest',
      origin: SessionOrigin.manual,
      status: SessionStatus.idle,
      createdAt: now,
      updatedAt: now,
      model: sessionModel,
    );

    // No session state means "inherit": a session that was created without an
    // explicit choice still pins the mode that asks before every mutation.
    expect(session.permissionMode, PermissionMode.ask);
    expect(session.toJson()['permissionMode'], 'ask');
    _roundTrip(session, (value) => value.toJson(), SessionDto.fromJson);
    // Creation parameters may still omit the mode, which asks the daemon to
    // resolve its configured default once, while the session is created.
    const params = SessionCreateParamsDto(
      id: 'session',
      worktreeId: 'worktree',
      title: 'Run the migration',
      agentDefinitionId: 'tinest',
    );
    expect(params.permissionMode, isNull);
    _roundTrip(
      params,
      (value) => value.toJson(),
      SessionCreateParamsDto.fromJson,
    );
    expect(
      SessionDto.fromJson(
        json.decode(json.encode(session.toJson())) as Map<String, dynamic>,
      ),
      session,
    );
  });

  test('session model overrides round-trip', () {
    const selection = ModelSelectionDto(modelId: 'provider/model');
    final overridden = SessionDto(
      id: 'session',
      worktreeId: 'worktree',
      title: 'Run the tests',
      agentDefinitionId: 'tinest',
      origin: SessionOrigin.manual,
      status: SessionStatus.idle,
      createdAt: now,
      updatedAt: now,
      model: selection,
    );

    _roundTrip(
      selection,
      (value) => value.toJson(),
      ModelSelectionDto.fromJson,
    );
    _roundTrip(overridden, (value) => value.toJson(), SessionDto.fromJson);
    _roundTrip(
      const SessionCreateParamsDto(
        id: 'session',
        worktreeId: 'worktree',
        title: 'Run the tests',
        agentDefinitionId: 'tinest',
        model: selection,
      ),
      (value) => value.toJson(),
      SessionCreateParamsDto.fromJson,
    );
    _roundTrip(
      const SessionSettingsUpdateParamsDto(
        sessionId: 'session',
        patch: SessionSettingsPatchDto(model: selection),
      ),
      (value) => value.toJson(),
      SessionSettingsUpdateParamsDto.fromJson,
    );
    expect(
      SessionDto.fromJson(
        json.decode(json.encode(overridden.toJson())) as Map<String, dynamic>,
      ).model,
      selection,
    );
    expect(const SessionSettingsPatchDto().model, isNull);
  });

  test('model controls preserve typed values and per-model descriptors', () {
    const controls = <ModelControlDescriptorDto>[
      ModelControlDescriptorDto(
        id: 'reasoning_effort',
        label: 'Reasoning effort',
        kind: ModelControlKind.choice,
        presentation: ModelControlPresentation.menuChip,
        choices: <ModelControlChoiceDto>[
          ModelControlChoiceDto(id: 'low', label: 'Low'),
          ModelControlChoiceDto(id: 'high', label: 'High'),
        ],
        conflictsWith: <String>['thinking_budget'],
      ),
      ModelControlDescriptorDto(
        id: 'fast_mode',
        label: 'Fast mode',
        kind: ModelControlKind.toggle,
        presentation: ModelControlPresentation.selectableChip,
      ),
      ModelControlDescriptorDto(
        id: 'thinking_budget',
        label: 'Thinking budget',
        kind: ModelControlKind.integer,
        presentation: ModelControlPresentation.numberDialog,
        minimum: 1024,
        maximum: 32768,
        step: 1024,
      ),
    ];
    const values = <String, ModelControlValueDto>{
      'reasoning_effort': ModelControlValueDto.stringValue(value: 'high'),
      'fast_mode': ModelControlValueDto.boolValue(value: true),
      'thinking_budget': ModelControlValueDto.intValue(value: 8192),
    };
    const model = ProviderModelDto(
      connectionId: 'provider',
      id: 'model',
      label: 'Model',
      source: ProviderModelSource.bundled,
      capabilities: ModelCapabilitiesDto(controls: controls),
    );
    final session = SessionDto(
      id: 'session',
      worktreeId: 'worktree',
      title: 'Typed controls',
      agentDefinitionId: 'tinest',
      origin: SessionOrigin.manual,
      status: SessionStatus.idle,
      createdAt: now,
      updatedAt: now,
      model: sessionModel,
      modelControls: values,
    );

    _roundTrip(model, (value) => value.toJson(), ProviderModelDto.fromJson);
    _roundTrip(session, (value) => value.toJson(), SessionDto.fromJson);
    _roundTrip(
      const SessionSettingsPatchDto(
        hasModelControls: true,
        modelControls: values,
      ),
      (value) => value.toJson(),
      SessionSettingsPatchDto.fromJson,
    );
  });

  test('multi-agent collaboration contracts round-trip', () {
    expect(sessionsListSubagentsProcedure.name, 'sessions.listSubagents');
    expect(
      SessionStatus.values.map((value) => value.name),
      isNot(contains('waitingForSubagent')),
    );

    final subagent = SessionDto(
      id: 'child',
      worktreeId: 'worktree',
      title: 'explore_auth',
      agentDefinitionId: 'explorer',
      origin: SessionOrigin.delegated,
      status: SessionStatus.running,
      createdAt: now,
      updatedAt: now,
      model: sessionModel,
      parentSessionId: 'root',
      taskName: 'explore_auth',
      agentPath: '/root/explore_auth',
      rootSessionId: 'root',
      lifecycle: AgentLifecycle.running,
    );
    _roundTrip(subagent, (value) => value.toJson(), SessionDto.fromJson);
    final decoded = SessionDto.fromJson(
      json.decode(json.encode(subagent.toJson())) as Map<String, dynamic>,
    );
    expect(decoded.taskName, 'explore_auth');
    expect(decoded.agentPath, '/root/explore_auth');
    expect(decoded.rootSessionId, 'root');
    expect(decoded.lifecycle, AgentLifecycle.running);

    final root = SessionDto(
      id: 'root',
      worktreeId: 'worktree',
      title: 'Root',
      agentDefinitionId: 'tinest',
      origin: SessionOrigin.manual,
      status: SessionStatus.idle,
      createdAt: now,
      updatedAt: now,
      model: sessionModel,
    );
    expect(root.taskName, isNull);
    expect(root.agentPath, isNull);
    expect(root.rootSessionId, isNull);
    expect(root.lifecycle, isNull);

    final mail = AgentMailboxMessageDto(
      id: 'mail-1',
      sessionId: 'root',
      senderPath: '/root/explore_auth',
      recipientPath: '/root',
      type: InterAgentMessageType.finalAnswer,
      payload: 'The auth flow uses JWT.',
      createdAt: now,
      senderSessionId: 'child',
    );
    _roundTrip(
      mail,
      (value) => value.toJson(),
      AgentMailboxMessageDto.fromJson,
    );
    expect(mail.deliveredAt, isNull);
    for (final type in InterAgentMessageType.values) {
      final copy = mail.copyWith(type: type);
      expect(
        AgentMailboxMessageDto.fromJson(
          json.decode(json.encode(copy.toJson())) as Map<String, dynamic>,
        ).type,
        type,
      );
    }
    for (final lifecycle in AgentLifecycle.values) {
      final copy = subagent.copyWith(lifecycle: lifecycle);
      expect(
        SessionDto.fromJson(
          json.decode(json.encode(copy.toJson())) as Map<String, dynamic>,
        ).lifecycle,
        lifecycle,
      );
    }

    _roundTrip(
      const SessionSubagentListParamsDto(sessionId: 'root'),
      (value) => value.toJson(),
      SessionSubagentListParamsDto.fromJson,
    );
    _roundTrip(
      SessionListResultDto(sessions: <SessionDto>[root, subagent]),
      (value) => value.toJson(),
      SessionListResultDto.fromJson,
    );
  }, tags: const <String>['feature_test__agent_collaboration__contract']);

  test('agent definition and session contracts round-trip', () {
    const definition = AgentDefinitionDto(
      version: 5,
      id: 'reviewer',
      name: 'Reviewer',
      description: 'Reviews code without editing it.',
      mode: AgentMode.subagent,
      model: AgentModelSelectionDto(source: AgentModelSource.session),
      driverId: 'tinest.standard/driver',
      extensionIds: <String>[],
      toolIds: <String>['tinest.files/read_file', 'tinest.files/search_text'],
      pluginSettings: <String, Map<String, dynamic>>{},
      callableAgentIds: <String>[],
      prompt: 'Review the requested code.',
      contentHash: 'hash',
      sourcePath: '/config/agents/reviewer.md',
    );
    final session = SessionDto(
      id: 'session',
      worktreeId: 'worktree',
      title: 'Review',
      agentDefinitionId: definition.id,
      origin: SessionOrigin.manual,
      status: SessionStatus.idle,
      createdAt: now,
      updatedAt: now,
      model: sessionModel,
    );

    _roundTrip(
      definition,
      (value) => value.toJson(),
      AgentDefinitionDto.fromJson,
    );
    _roundTrip(session, (value) => value.toJson(), SessionDto.fromJson);
  });

  test('skill catalog contracts round-trip each view and summary', () {
    const skill = SkillSummaryDto(
      id: 'commit',
      name: 'commit',
      description: 'Writes atomic commits.',
      isImplicit: false,
    );

    _roundTrip(skill, (value) => value.toJson(), SkillSummaryDto.fromJson);
    const params = SkillListParamsDto(
      view: SkillListView.project,
      workspaceId: 'workspace',
    );
    expect(params.toJson(), <String, dynamic>{
      'view': 'project',
      'workspaceId': 'workspace',
    });
    _roundTrip(params, (value) => value.toJson(), SkillListParamsDto.fromJson);
    _roundTrip(
      const SkillListResultDto(skills: <SkillSummaryDto>[skill]),
      (value) => value.toJson(),
      SkillListResultDto.fromJson,
    );

    expect(promptsListSkillsProcedure.paramsType, SkillListParamsDto);
    expect(promptsListSkillsProcedure.resultType, SkillListResultDto);
    expect(
      rpcProcedures
          .map((procedure) => procedure.name)
          .where(
            <String>{
              'prompts.getSkill',
              'prompts.createSkill',
              'prompts.updateSkill',
              'prompts.deleteSkill',
              'prompts.setSkillEnabled',
            }.contains,
          ),
      isEmpty,
    );
    expect(SkillListView.values, <SkillListView>[
      SkillListView.global,
      SkillListView.project,
      SkillListView.effective,
    ]);
  }, tags: const <String>['feature_test__skill_catalog__contract']);

  test('workspace and worktree contracts round-trip', () {
    final workspace = WorkspaceDto(
      id: 'workspace',
      name: 'Tinest',
      rootPath: '/workspace',
      kind: WorkspaceKind.git,
      createdAt: now,
    );
    final worktree = WorktreeDto(
      id: 'worktree',
      workspaceId: workspace.id,
      name: 'feature/settings',
      path: '/daemon/worktrees/feature-settings',
      kind: WorktreeKind.linked,
      branch: 'feature/settings',
      head: 'abc123',
      isTinestOwned: true,
      createdAt: now,
    );
    final catalog = WorkspaceCatalogDto(
      workspaces: <WorkspaceDto>[workspace],
      worktrees: <WorktreeDto>[worktree],
    );

    _roundTrip(workspace, (value) => value.toJson(), WorkspaceDto.fromJson);
    _roundTrip(worktree, (value) => value.toJson(), WorktreeDto.fromJson);
    _roundTrip(
      catalog,
      (value) => value.toJson(),
      WorkspaceCatalogDto.fromJson,
    );
    _roundTrip(
      const WorktreeArchivePreviewDto(
        worktreeId: 'worktree',
        dirty: true,
        unpushedCommitCount: 2,
        runningSessionCount: 0,
        removesDirectory: true,
      ),
      (value) => value.toJson(),
      WorktreeArchivePreviewDto.fromJson,
    );
    _roundTrip(
      const DirectorySuggestionDto(path: '/workspace', name: 'workspace'),
      (value) => value.toJson(),
      DirectorySuggestionDto.fromJson,
    );
    _roundTrip(
      const GitBranchDto(name: 'main', current: true, checkedOut: true),
      (value) => value.toJson(),
      GitBranchDto.fromJson,
    );
    _roundTrip(
      const GitBranchDto(
        name: 'origin/main',
        current: false,
        checkedOut: false,
        isRemote: true,
        isDefault: true,
      ),
      (value) => value.toJson(),
      GitBranchDto.fromJson,
    );
    expect(
      const GitBranchDto(
        name: 'main',
        current: true,
        checkedOut: true,
      ).isRemote,
      isFalse,
    );
  });

  test('only non-root worktree kinds are archivable', () {
    expect(isArchivableWorktreeKind(WorktreeKind.linked), isTrue);
    expect(isArchivableWorktreeKind(WorktreeKind.checkout), isFalse);
    expect(isArchivableWorktreeKind(WorktreeKind.directory), isFalse);
  });

  test('a linked worktree carries its ownership as a field, not a kind', () {
    // Who created the checkout is the only thing the retired `managed` and
    // `external` kinds ever disagreed on, and it is already a field. Both
    // still round-trip as one kind and stay archivable.
    for (final owned in <bool>[true, false]) {
      final worktree = WorktreeDto(
        id: 'worktree-$owned',
        workspaceId: 'workspace',
        name: 'feature/settings',
        path: '/daemon/worktrees/feature-settings',
        kind: WorktreeKind.linked,
        isTinestOwned: owned,
        createdAt: DateTime.utc(2026, 8, 20),
      );
      _roundTrip(worktree, (value) => value.toJson(), WorktreeDto.fromJson);
      expect(worktree.toJson()['kind'], 'linked');
      expect(isArchivableWorktreeKind(worktree.kind), isTrue);
    }
  });

  test('the home workspace kind round-trips under a stable JSON name', () {
    final home = WorkspaceDto(
      id: 'home',
      name: 'Home',
      rootPath: '/home/user',
      kind: WorkspaceKind.home,
      createdAt: now,
    );
    expect(home.toJson()['kind'], 'home');
    _roundTrip(home, (value) => value.toJson(), WorkspaceDto.fromJson);
    // The home checkout is an ordinary directory worktree, so nothing
    // downstream of the session needs a second special case.
    final checkout = WorktreeDto(
      id: 'home-checkout',
      workspaceId: home.id,
      name: 'Home',
      path: home.rootPath,
      kind: WorktreeKind.directory,
      isTinestOwned: false,
      createdAt: now,
    );
    _roundTrip(checkout, (value) => value.toJson(), WorktreeDto.fromJson);
  }, tags: const <String>['feature_test__session_home__contract']);

  final workspace = WorkspaceDto(
    id: 'workspace',
    name: 'Tinest',
    rootPath: '/workspace',
    kind: WorkspaceKind.git,
    createdAt: now,
  );
  final worktree = WorktreeDto(
    id: 'worktree',
    workspaceId: workspace.id,
    name: 'main',
    path: workspace.rootPath,
    kind: WorktreeKind.checkout,
    branch: 'main',
    head: 'abc123',
    isTinestOwned: false,
    createdAt: now,
  );
  const capabilities = ModelCapabilitiesDto(
    streaming: CapabilitySupport.supported,
    toolCalling: CapabilitySupport.supported,
    deferredTools: CapabilitySupport.supported,
    controls: <ModelControlDescriptorDto>[
      ModelControlDescriptorDto(
        id: 'reasoning_effort',
        label: 'Reasoning effort',
        kind: ModelControlKind.choice,
        presentation: ModelControlPresentation.menuChip,
        choices: <ModelControlChoiceDto>[
          ModelControlChoiceDto(id: 'low', label: 'Low'),
          ModelControlChoiceDto(id: 'medium', label: 'Medium'),
        ],
      ),
    ],
    source: CapabilitySource.manual,
  );
  const authMethod = ProviderAuthMethodDto(
    id: 'api-key',
    label: 'API key',
    kind: ProviderAuthKind.apiKey,
    flow: ProviderAuthFlow.apiKey,
  );
  const definition = ProviderDefinitionDto(
    id: 'provider',
    name: 'Provider',
    description: 'A hosted provider.',
    authMethods: <ProviderAuthMethodDto>[authMethod],
    recommendedModelIds: <String>['model'],
  );
  const customConfig = CustomProviderConfigDto(
    name: 'Custom',
    baseUrl: 'http://localhost:11434/v1',
    wireFormatId: 'openai-chat-completions',
    authenticationRequired: true,
    models: <ManualProviderModelDto>[
      ManualProviderModelDto(id: 'model', label: 'Model'),
    ],
  );
  final connection = ProviderConnectionDto(
    id: 'provider',
    definitionId: definition.id,
    displayName: definition.name,
    status: ProviderConnectionStatus.connected,
    authKind: ProviderAuthKind.apiKey,
    credentialOrigin: ProviderCredentialOrigin.stored,
    createdAt: now,
    updatedAt: now,
  );
  test('provider connections expose no implicit default state', () {
    expect(connection.toJson(), isNot(contains('isDefault')));
    expect(connection.toJson(), isNot(contains('defaultModelId')));
  });
  final model = ProviderModelDto(
    connectionId: connection.id,
    id: 'model',
    label: 'Model',
    source: ProviderModelSource.manual,
    capabilities: capabilities,
    diagnosticStatus: DiagnosticStatus.verified,
    verifiedAt: now,
    diagnosticError: 'previous error',
    pricing: const ModelPricingDto(
      input: 1.25,
      output: 2.5,
      cacheRead: 0.25,
      cacheWrite: 0.5,
    ),
    limits: const ModelLimitsDto(context: 128000, input: 120000, output: 8000),
  );
  final catalog = ProviderCatalogDto(
    definitions: const <ProviderDefinitionDto>[definition],
    source: ProviderCatalogSource.bundled,
    updatedAt: now,
  );
  final authAttempt = ProviderAuthAttemptDto(
    id: 'attempt',
    definitionId: definition.id,
    methodId: 'chatgpt-device',
    status: ProviderAuthAttemptStatus.awaitingUser,
    authorizationUrl: 'https://auth.openai.com/codex/device',
    userCode: 'ABCD-EFGH',
    instructions: 'Enter the code.',
    expiresAt: now.add(const Duration(minutes: 15)),
  );
  final agent = SessionDto(
    id: 'agent',
    worktreeId: worktree.id,
    title: 'Agent',
    agentDefinitionId: 'tinest',
    origin: SessionOrigin.manual,
    status: SessionStatus.waitingForApproval,
    createdAt: now,
    updatedAt: now,
    model: sessionModel,
    activeTurnId: 'turn',
    lastError: 'none',
  );
  final timeline = TimelineEventDto(
    sessionId: agent.id,
    sequence: 4,
    turnId: 'turn',
    type: 'approval.requested',
    data: const <String, dynamic>{'value': true},
    createdAt: now,
  );
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
    preview: 'diff',
  );
  final diagnostic = ProviderDiagnosticDto(
    connectionId: connection.id,
    model: model.id,
    status: DiagnosticStatus.verified,
    endpointReachable: true,
    streaming: true,
    toolCalling: true,
    checkedAt: now,
    error: 'none',
  );

  test('project settings and worktree hook contracts round-trip', () {
    const settings = ProjectSettingsDto(
      setup: <String>['npm ci', 'npm run build'],
      teardown: <String>['docker compose down'],
    );
    const hookRun = WorktreeHookRunDto(
      phase: WorktreeHookPhase.setup,
      command: 'npm ci',
      exitCode: 1,
      stdout: 'installing',
      stderr: 'boom',
    );

    _roundTrip(
      settings,
      (value) => value.toJson(),
      ProjectSettingsDto.fromJson,
    );
    _roundTrip(hookRun, (value) => value.toJson(), WorktreeHookRunDto.fromJson);
    _roundTrip(
      const ProjectSettingsGetParamsDto(workspaceId: 'workspace'),
      (value) => value.toJson(),
      ProjectSettingsGetParamsDto.fromJson,
    );
    _roundTrip(
      const ProjectSettingsSaveParamsDto(
        workspaceId: 'workspace',
        settings: settings,
      ),
      (value) => value.toJson(),
      ProjectSettingsSaveParamsDto.fromJson,
    );
    _roundTrip(
      const ProjectSettingsResultDto(
        settings: settings,
        sourcePath: '/workspace/.tinest/config.json',
      ),
      (value) => value.toJson(),
      ProjectSettingsResultDto.fromJson,
    );
    expect(
      const ProjectSettingsDto(),
      ProjectSettingsDto.fromJson(<String, dynamic>{}),
    );
    expect(
      WorktreeResultDto.fromJson(<String, dynamic>{
        'worktree': WorktreeDto(
          id: 'worktree',
          workspaceId: 'workspace',
          name: 'main',
          path: '/workspace',
          kind: WorktreeKind.checkout,
          isTinestOwned: false,
          createdAt: now,
        ).toJson(),
      }).hookRuns,
      isEmpty,
    );
  });

  test('protocol version and direct JSON-RPC names are stable', () {
    expect(tinestProtocolMajor, 5);
    expect(workspacesCatalogProcedure.name, 'workspaces.catalog');
    expect(sessionsCreateProcedure.name, 'sessions.create');
    expect(sessionsUpdateSettingsProcedure.name, 'sessions.updateSettings');
    expect(
      agentsGetDefaultPermissionModeProcedure.name,
      'agents.getDefaultPermissionMode',
    );
    expect(
      agentsSetDefaultPermissionModeProcedure.name,
      'agents.setDefaultPermissionMode',
    );
    expect(providersCatalogProcedure.name, 'providers.catalog');
    expect(providersStartAuthProcedure.name, 'providers.startAuth');
    expect(sessionsStartTurnProcedure.name, 'sessions.startTurn');
    expect(sessionsTimelineEventNotification.name, 'sessions.timelineEvent');
  });

  test('MCP contracts round-trip and expose their defaults', () {
    const stdio = McpServerConfigDto(
      id: 'github',
      transport: McpTransportKind.stdio,
      command: 'npx',
      args: <String>['-y', 'server-github'],
      env: <String, String>{'TOKEN': r'${secret:github.token}'},
      cwd: '/repo',
    );
    const remote = McpServerConfigDto(
      id: 'linear',
      transport: McpTransportKind.http,
      enabled: false,
      url: 'https://mcp.linear.test/mcp',
      headers: <String, String>{'authorization': r'${env:LINEAR}'},
    );
    // Everything optional defaults to the empty, enabled, unshadowed case.
    const bare = McpServerConfigDto(
      id: 'bare',
      transport: McpTransportKind.stdio,
    );
    expect(bare.enabled, isTrue);
    expect(bare.args, isEmpty);
    expect(bare.env, isEmpty);
    expect(bare.headers, isEmpty);
    expect(bare.command, isNull);
    expect(bare.url, isNull);
    expect(bare.cwd, isNull);

    const summary = McpToolSummaryDto(
      toolId: 'mcp__github__create_issue',
      name: 'create_issue',
      title: 'Create issue',
      description: 'Opens an issue.',
    );
    final state = McpServerStateDto(
      config: stdio,
      status: McpServerStatus.ready,
      scope: McpConfigScope.user,
      sourcePath: '/config/mcp.json',
      protocolVersion: '2025-06-18',
      serverName: 'github',
      serverVersion: '1.0.0',
      tools: const <McpToolSummaryDto>[summary],
      diagnostics: const <String>['started'],
      lastConnectedAt: now,
    );
    const failed = McpServerStateDto(
      config: remote,
      status: McpServerStatus.failed,
      scope: McpConfigScope.project,
      sourcePath: '/repo/.mcp.json',
      shadowed: true,
      error: 'the server did not answer',
      attempt: 3,
    );
    expect(state.shadowed, isFalse);
    expect(state.attempt, 0);
    expect(failed.tools, isEmpty);
    expect(failed.diagnostics, isEmpty);
    expect(failed.nextRetryAt, isNull);

    for (final config in <McpServerConfigDto>[stdio, remote, bare]) {
      _roundTrip(
        config,
        (value) => value.toJson(),
        McpServerConfigDto.fromJson,
      );
    }
    _roundTrip(summary, (value) => value.toJson(), McpToolSummaryDto.fromJson);
    for (final entry in <McpServerStateDto>[state, failed]) {
      _roundTrip(entry, (value) => value.toJson(), McpServerStateDto.fromJson);
    }

    _roundTrip(
      const McpServersParamsDto(worktreeId: 'worktree'),
      (value) => value.toJson(),
      McpServersParamsDto.fromJson,
    );
    _roundTrip(
      McpServersResultDto(servers: <McpServerStateDto>[state, failed]),
      (value) => value.toJson(),
      McpServersResultDto.fromJson,
    );
    _roundTrip(
      const McpServerParamsDto(server: stdio),
      (value) => value.toJson(),
      McpServerParamsDto.fromJson,
    );
    _roundTrip(
      const McpServerIdParamsDto(id: 'github'),
      (value) => value.toJson(),
      McpServerIdParamsDto.fromJson,
    );
    _roundTrip(
      McpServerStateResultDto(state: state),
      (value) => value.toJson(),
      McpServerStateResultDto.fromJson,
    );
    _roundTrip(
      const McpSecretParamsDto(key: 'github.token', value: 'secret'),
      (value) => value.toJson(),
      McpSecretParamsDto.fromJson,
    );
    _roundTrip(
      const AgentToolCatalogParamsDto(worktreeId: 'worktree'),
      (value) => value.toJson(),
      AgentToolCatalogParamsDto.fromJson,
    );
    expect(const AgentToolCatalogParamsDto().worktreeId, isNull);
    expect(const McpServersParamsDto().worktreeId, isNull);
  });

  test('all domain DTOs round-trip with additive fields', () {
    _roundTrip(workspace, (value) => value.toJson(), WorkspaceDto.fromJson);
    _roundTrip(agent, (value) => value.toJson(), SessionDto.fromJson);
    _roundTrip(
      capabilities,
      (value) => value.toJson(),
      ModelCapabilitiesDto.fromJson,
    );
    _roundTrip(
      model.pricing!,
      (value) => value.toJson(),
      ModelPricingDto.fromJson,
    );
    _roundTrip(
      model.limits!,
      (value) => value.toJson(),
      ModelLimitsDto.fromJson,
    );
    _roundTrip(
      authMethod,
      (value) => value.toJson(),
      ProviderAuthMethodDto.fromJson,
    );
    _roundTrip(
      definition,
      (value) => value.toJson(),
      ProviderDefinitionDto.fromJson,
    );
    _roundTrip(
      connection,
      (value) => value.toJson(),
      ProviderConnectionDto.fromJson,
    );
    _roundTrip(
      customConfig,
      (value) => value.toJson(),
      CustomProviderConfigDto.fromJson,
    );
    _roundTrip(
      authAttempt,
      (value) => value.toJson(),
      ProviderAuthAttemptDto.fromJson,
    );
    _roundTrip(model, (value) => value.toJson(), ProviderModelDto.fromJson);
    _roundTrip(catalog, (value) => value.toJson(), ProviderCatalogDto.fromJson);
    _roundTrip(
      diagnostic,
      (value) => value.toJson(),
      ProviderDiagnosticDto.fromJson,
    );
    _roundTrip(timeline, (value) => value.toJson(), TimelineEventDto.fromJson);
    _roundTrip(
      approval,
      (value) => value.toJson(),
      ApprovalRequestDto.fromJson,
    );
    _roundTrip(
      const ServerInfoDto(
        serverId: 'server',
        version: '1.0.0',
        protocolVersion: tinestProtocolMajor,
        features: <String, bool>{},
        homeDirectory: '/home/test',
      ),
      (value) => value.toJson(),
      ServerInfoDto.fromJson,
    );
    // A daemon configured without a home reports none, and the client has to
    // read that back as null rather than inventing a path.
    _roundTrip(
      const ServerInfoDto(
        serverId: 'server',
        version: '1.0.0',
        protocolVersion: tinestProtocolMajor,
        features: <String, bool>{},
      ),
      (value) => value.toJson(),
      ServerInfoDto.fromJson,
    );
    _roundTrip(
      const RpcErrorDto(
        code: 'invalid',
        message: 'Invalid request',
        retryable: false,
        details: <String, dynamic>{'field': 'model'},
      ),
      (value) => value.toJson(),
      RpcErrorDto.fromJson,
    );
  });

  test('all request DTOs round-trip', () {
    _roundTrip(
      const HelloParamsDto(
        clientId: 'client',
        clientKind: 'desktop',
        protocolMajor: tinestProtocolMajor,
        capabilities: <String, bool>{'timelineCatchup': true},
      ),
      (value) => value.toJson(),
      HelloParamsDto.fromJson,
    );
    _roundTrip(
      const WorkspaceRegisterParamsDto(
        workspaceId: 'workspace',
        checkoutId: 'checkout',
        rootPath: '/workspace',
        name: 'Workspace',
      ),
      (value) => value.toJson(),
      WorkspaceRegisterParamsDto.fromJson,
    );
    _roundTrip(
      const WorkspaceIdParamsDto(workspaceId: 'workspace'),
      (value) => value.toJson(),
      WorkspaceIdParamsDto.fromJson,
    );
    _roundTrip(
      const DirectorySuggestParamsDto(query: '~/Workspaces', limit: 20),
      (value) => value.toJson(),
      DirectorySuggestParamsDto.fromJson,
    );
    _roundTrip(
      const GitBranchesListParamsDto(workspaceId: 'workspace'),
      (value) => value.toJson(),
      GitBranchesListParamsDto.fromJson,
    );
    _roundTrip(
      const WorktreeCreateParamsDto(
        id: 'worktree',
        workspaceId: 'workspace',
        mode: WorktreeCreateMode.newBranch,
        branchName: 'feature/settings',
        baseBranch: 'main',
      ),
      (value) => value.toJson(),
      WorktreeCreateParamsDto.fromJson,
    );
    _roundTrip(
      const WorktreeCreateParamsDto(
        id: 'worktree',
        workspaceId: 'workspace',
        mode: WorktreeCreateMode.newBranch,
        branchName: 'flutter',
        baseBranch: 'origin/main',
        branchNaming: WorktreeBranchNaming.derive,
      ),
      (value) => value.toJson(),
      WorktreeCreateParamsDto.fromJson,
    );
    _roundTrip(
      const WorktreeIdParamsDto(worktreeId: 'worktree'),
      (value) => value.toJson(),
      WorktreeIdParamsDto.fromJson,
    );
    _roundTrip(
      const WorktreeArchiveParamsDto(worktreeId: 'worktree', force: true),
      (value) => value.toJson(),
      WorktreeArchiveParamsDto.fromJson,
    );
    _roundTrip(
      const SessionListParamsDto(worktreeId: 'worktree'),
      (value) => value.toJson(),
      SessionListParamsDto.fromJson,
    );
    _roundTrip(
      const SessionCreateParamsDto(
        id: 'agent',
        worktreeId: 'worktree',
        title: 'Agent',
        agentDefinitionId: 'tinest',
      ),
      (value) => value.toJson(),
      SessionCreateParamsDto.fromJson,
    );
    _roundTrip(
      const AgentDefinitionUpdateParamsDto(
        definition: AgentDefinitionDto(
          version: 5,
          id: 'reviewer',
          name: 'Reviewer',
          description: 'Reviews code.',
          mode: AgentMode.subagent,
          model: AgentModelSelectionDto(source: AgentModelSource.session),
          driverId: 'tinest.standard/driver',
          extensionIds: <String>[],
          toolIds: <String>['tinest.files/read_file'],
          pluginSettings: <String, Map<String, dynamic>>{},
          callableAgentIds: <String>[],
          prompt: 'Review code.',
          contentHash: 'hash',
          sourcePath: '/config/agents/reviewer.md',
        ),
        expectedContentHash: 'hash',
      ),
      (value) => value.toJson(),
      AgentDefinitionUpdateParamsDto.fromJson,
    );
    _roundTrip(
      const ProviderConnectApiKeyParamsDto(
        definitionId: 'provider',
        apiKey: 'secret',
        connectionId: 'existing-provider',
      ),
      (value) => value.toJson(),
      ProviderConnectApiKeyParamsDto.fromJson,
    );
    _roundTrip(
      const ProviderConnectNoneParamsDto(
        definitionId: 'ollama',
        connectionId: 'existing-ollama',
      ),
      (value) => value.toJson(),
      ProviderConnectNoneParamsDto.fromJson,
    );
    _roundTrip(
      const ProviderConnectionIdParamsDto(connectionId: 'provider'),
      (value) => value.toJson(),
      ProviderConnectionIdParamsDto.fromJson,
    );
    _roundTrip(
      const ProviderModelParamsDto(connectionId: 'provider', modelId: 'model'),
      (value) => value.toJson(),
      ProviderModelParamsDto.fromJson,
    );
    _roundTrip(
      const ProviderAuthStartParamsDto(
        definitionId: 'openai',
        methodId: 'chatgpt-device',
        connectionId: 'existing-openai',
      ),
      (value) => value.toJson(),
      ProviderAuthStartParamsDto.fromJson,
    );
    _roundTrip(
      const ProviderAuthAttemptParamsDto(attemptId: 'attempt'),
      (value) => value.toJson(),
      ProviderAuthAttemptParamsDto.fromJson,
    );
    _roundTrip(
      const ProviderCustomCreateParamsDto(
        id: 'custom-id',
        config: customConfig,
        apiKey: 'secret',
      ),
      (value) => value.toJson(),
      ProviderCustomCreateParamsDto.fromJson,
    );
    _roundTrip(
      const ProviderCustomUpdateParamsDto(
        connectionId: 'custom-id',
        config: customConfig,
        apiKey: 'replacement-secret',
      ),
      (value) => value.toJson(),
      ProviderCustomUpdateParamsDto.fromJson,
    );
    _roundTrip(
      const TurnStartParamsDto(
        sessionId: 'agent',
        turnId: 'turn',
        prompt: 'hello',
        attachmentIds: <String>['attachment-1'],
      ),
      (value) => value.toJson(),
      TurnStartParamsDto.fromJson,
    );
    _roundTrip(
      const SessionIdParamsDto(sessionId: 'agent'),
      (value) => value.toJson(),
      SessionIdParamsDto.fromJson,
    );
    _roundTrip(
      const ApprovalResolveParamsDto(approvalId: 'approval', approved: true),
      (value) => value.toJson(),
      ApprovalResolveParamsDto.fromJson,
    );
    _roundTrip(
      const TimelineSubscribeParamsDto(sessionId: 'agent', afterSequence: 12),
      (value) => value.toJson(),
      TimelineSubscribeParamsDto.fromJson,
    );
  });

  test(
    'history pagination contracts round-trip',
    tags: const <String>[
      'feature_test__conversation_history_pagination__contract',
    ],
    () {
      // An unbounded subscribe stays expressible: the daemon's existing
      // full-history callers must keep working untouched.
      _roundTrip(
        const TimelineSubscribeParamsDto(sessionId: 'agent', afterSequence: 0),
        (value) => value.toJson(),
        TimelineSubscribeParamsDto.fromJson,
      );
      _roundTrip(
        const TimelineSubscribeParamsDto(
          sessionId: 'agent',
          afterSequence: 0,
          tailLimit: 200,
        ),
        (value) => value.toJson(),
        TimelineSubscribeParamsDto.fromJson,
      );
      _roundTrip(
        const TimelineHistoryParamsDto(
          sessionId: 'agent',
          beforeSequence: 900,
          limit: 200,
        ),
        (value) => value.toJson(),
        TimelineHistoryParamsDto.fromJson,
      );

      expect(sessionsTimelineHistoryProcedure.name, 'sessions.timelineHistory');
      expect(sessionsProcedures, contains(sessionsTimelineHistoryProcedure));
      expect(
        rpcProcedures.map((procedure) => procedure.name),
        contains('sessions.timelineHistory'),
      );
    },
  );

  test(
    'attachment contracts round-trip',
    tags: const <String>['feature_test__conversation_attachments__contract'],
    () {
      final attachment = AttachmentDto(
        id: 'attachment-1',
        fileName: 'diagram.png',
        mimeType: 'image/png',
        byteSize: 4,
        kind: AttachmentKind.image,
        sha256: 'hash',
        createdAt: now,
      );
      _roundTrip(attachment, (value) => value.toJson(), AttachmentDto.fromJson);
      expect(
        TurnStartParamsDto.fromJson(<String, dynamic>{
          'sessionId': 'agent',
          'turnId': 'turn',
          'prompt': '',
        }).attachmentIds,
        isEmpty,
      );
    },
  );

  test('all result DTOs round-trip', () {
    _roundTrip(
      WorkspaceCatalogResultDto(
        catalog: WorkspaceCatalogDto(
          workspaces: <WorkspaceDto>[workspace],
          worktrees: <WorktreeDto>[worktree],
        ),
      ),
      (value) => value.toJson(),
      WorkspaceCatalogResultDto.fromJson,
    );
    _roundTrip(
      WorkspaceRegisterResultDto(
        workspace: workspace,
        worktrees: <WorktreeDto>[worktree],
      ),
      (value) => value.toJson(),
      WorkspaceRegisterResultDto.fromJson,
    );
    _roundTrip(
      const WorkspaceUnregisterResultDto(unregistered: true),
      (value) => value.toJson(),
      WorkspaceUnregisterResultDto.fromJson,
    );
    _roundTrip(
      const DirectorySuggestResultDto(
        suggestions: <DirectorySuggestionDto>[
          DirectorySuggestionDto(path: '/workspace', name: 'workspace'),
        ],
      ),
      (value) => value.toJson(),
      DirectorySuggestResultDto.fromJson,
    );
    _roundTrip(
      const GitBranchesListResultDto(
        branches: <GitBranchDto>[
          GitBranchDto(name: 'main', current: true, checkedOut: true),
        ],
      ),
      (value) => value.toJson(),
      GitBranchesListResultDto.fromJson,
    );
    _roundTrip(
      WorktreeResultDto(worktree: worktree),
      (value) => value.toJson(),
      WorktreeResultDto.fromJson,
    );
    _roundTrip(
      const WorktreeArchivePreviewResultDto(
        preview: WorktreeArchivePreviewDto(
          worktreeId: 'worktree',
          dirty: false,
          unpushedCommitCount: 0,
          runningSessionCount: 0,
          removesDirectory: true,
        ),
      ),
      (value) => value.toJson(),
      WorktreeArchivePreviewResultDto.fromJson,
    );
    _roundTrip(
      SessionListResultDto(sessions: <SessionDto>[agent]),
      (value) => value.toJson(),
      SessionListResultDto.fromJson,
    );
    _roundTrip(
      SessionResultDto(session: agent),
      (value) => value.toJson(),
      SessionResultDto.fromJson,
    );
    _roundTrip(
      ProviderCatalogResultDto(catalog: catalog),
      (value) => value.toJson(),
      ProviderCatalogResultDto.fromJson,
    );
    _roundTrip(
      ProviderConnectionsResultDto(
        connections: <ProviderConnectionDto>[connection],
      ),
      (value) => value.toJson(),
      ProviderConnectionsResultDto.fromJson,
    );
    _roundTrip(
      ProviderConnectionResultDto(connection: connection),
      (value) => value.toJson(),
      ProviderConnectionResultDto.fromJson,
    );
    _roundTrip(
      ProviderModelsResultDto(models: <ProviderModelDto>[model]),
      (value) => value.toJson(),
      ProviderModelsResultDto.fromJson,
    );
    _roundTrip(
      ProviderAuthAttemptResultDto(attempt: authAttempt),
      (value) => value.toJson(),
      ProviderAuthAttemptResultDto.fromJson,
    );
    _roundTrip(
      ProviderDiagnosticResultDto(diagnostic: diagnostic),
      (value) => value.toJson(),
      ProviderDiagnosticResultDto.fromJson,
    );
    _roundTrip(
      const TurnStartResultDto(created: true),
      (value) => value.toJson(),
      TurnStartResultDto.fromJson,
    );
    _roundTrip(
      ApprovalResultDto(approval: approval),
      (value) => value.toJson(),
      ApprovalResultDto.fromJson,
    );
    _roundTrip(
      TimelineResultDto(events: <TimelineEventDto>[timeline]),
      (value) => value.toJson(),
      TimelineResultDto.fromJson,
    );
  });

  test(
    'user question contracts round-trip and expose a waiting status',
    tags: const <String>['feature_test__turn_question__contract'],
    () {
      final question = UserQuestionRequestDto(
        id: 'question',
        sessionId: agent.id,
        turnId: 'turn',
        toolCallId: 'call',
        questions: const <UserQuestionItemDto>[
          UserQuestionItemDto(
            id: 'q1',
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
      _roundTrip(
        question,
        (value) => value.toJson(),
        UserQuestionRequestDto.fromJson,
      );
      _roundTrip(
        question.copyWith(
          status: UserQuestionStatus.answered,
          answers: const <UserQuestionAnswerDto>[
            UserQuestionAnswerDto(
              questionId: 'q1',
              answer: 'Postgres',
              isFreeForm: true,
            ),
          ],
        ),
        (value) => value.toJson(),
        UserQuestionRequestDto.fromJson,
      );
      _roundTrip(
        const UserQuestionAnswerParamsDto(
          requestId: 'question',
          answers: <UserQuestionAnswerDto>[
            UserQuestionAnswerDto(
              questionId: 'q1',
              answer: 'SQLite',
              isFreeForm: false,
            ),
          ],
        ),
        (value) => value.toJson(),
        UserQuestionAnswerParamsDto.fromJson,
      );
      _roundTrip(
        UserQuestionResultDto(request: question),
        (value) => value.toJson(),
        UserQuestionResultDto.fromJson,
      );

      // A blocked turn is a distinct state from one blocked on an approval.
      expect(
        SessionDto.fromJson(
          _jsonMap(
            agent.copyWith(status: SessionStatus.waitingForInput).toJson(),
          ),
        ).status,
        SessionStatus.waitingForInput,
      );
      expect(TurnStatus.values, contains(TurnStatus.waitingForInput));
      expect(sessionsAnswerQuestionProcedure.name, 'sessions.answerQuestion');
      expect(
        sessionsQuestionRequestedNotification.name,
        'sessions.questionRequested',
      );
    },
  );

  test(
    'the context budget rides the session contract',
    tags: const <String>['feature_test__tool_context_budget__contract'],
    () {
      final session = SessionDto(
        id: 'session',
        worktreeId: 'worktree',
        title: 'Budgeted',
        agentDefinitionId: 'tinest',
        origin: SessionOrigin.manual,
        status: SessionStatus.idle,
        createdAt: now,
        updatedAt: now,
        model: sessionModel,
        contextTokens: 32000,
        contextWindow: 200000,
      );
      _roundTrip(session, (value) => value.toJson(), SessionDto.fromJson);

      // A provider that never advertised a window leaves the meter hidden
      // rather than reporting a made-up denominator.
      final unknown = SessionDto(
        id: 'session',
        worktreeId: 'worktree',
        title: 'Unknown',
        agentDefinitionId: 'tinest',
        origin: SessionOrigin.manual,
        status: SessionStatus.idle,
        createdAt: now,
        updatedAt: now,
        model: sessionModel,
      );
      expect(unknown.contextWindow, isNull);
      expect(unknown.contextTokens, 0);
      expect(
        SessionDto.fromJson(
          json.decode(json.encode(unknown.toJson())) as Map<String, dynamic>,
        ).contextWindow,
        isNull,
      );
    },
  );

  test(
    'MCP resource contracts round-trip and default to empty lists',
    tags: const <String>['feature_test__mcp_resource_access__contract'],
    () {
      _roundTrip(
        const McpResourceSummaryDto(
          uri: 'file:///repo/README.md',
          name: 'README',
          title: 'Project readme',
          description: 'How to build.',
          mimeType: 'text/markdown',
          sizeBytes: 4096,
        ),
        (value) => value.toJson(),
        McpResourceSummaryDto.fromJson,
      );
      _roundTrip(
        const McpResourceSummaryDto(uri: 'db://schema'),
        (value) => value.toJson(),
        McpResourceSummaryDto.fromJson,
      );
      _roundTrip(
        const McpResourceTemplateSummaryDto(
          uriTemplate: 'file:///repo/{path}',
          name: 'Repository file',
        ),
        (value) => value.toJson(),
        McpResourceTemplateSummaryDto.fromJson,
      );

      // A daemon that has not learned about resources yet reports none, so an
      // older stored state decodes without them.
      const bare = McpServerStateDto(
        config: McpServerConfigDto(
          id: 'github',
          transport: McpTransportKind.stdio,
          command: 'npx',
        ),
        status: McpServerStatus.ready,
        scope: McpConfigScope.user,
        sourcePath: '/config/mcp.json',
      );
      expect(bare.resources, isEmpty);
      expect(bare.resourceTemplates, isEmpty);
      _roundTrip(
        bare.copyWith(
          resources: const <McpResourceSummaryDto>[
            McpResourceSummaryDto(uri: 'file:///a.txt'),
          ],
          resourceTemplates: const <McpResourceTemplateSummaryDto>[
            McpResourceTemplateSummaryDto(uriTemplate: 'file:///{p}'),
          ],
        ),
        (value) => value.toJson(),
        McpServerStateDto.fromJson,
      );
    },
  );

  test(
    'provider usage and exact session cost round-trip',
    tags: const <String>['feature_test__provider_usage__contract'],
    () {
      final usage = ProviderUsageDto(
        connectionId: 'openai',
        status: ProviderUsageStatus.available,
        fetchedAt: now,
        provider: 'OpenAI',
        plan: 'plus',
        windows: <ProviderUsageWindowDto>[
          ProviderUsageWindowDto(
            kind: ProviderUsageWindowKind.session,
            usedPercent: 42,
            resetsAt: now.add(const Duration(hours: 1)),
          ),
        ],
        creditBalance: 2.5,
      );
      _roundTrip(usage, (value) => value.toJson(), ProviderUsageDto.fromJson);
      _roundTrip(
        ProviderUsageResultDto(usage: <ProviderUsageDto>[usage]),
        (value) => value.toJson(),
        ProviderUsageResultDto.fromJson,
      );
      expect(providersListUsageProcedure.name, 'providers.listUsage');

      final session = SessionDto(
        id: 'session',
        worktreeId: 'worktree',
        title: 'Priced',
        agentDefinitionId: 'tinest',
        origin: SessionOrigin.manual,
        status: SessionStatus.idle,
        createdAt: now,
        updatedAt: now,
        model: sessionModel,
        totalCostUsd: 1.25,
      );
      expect(
        SessionDto.fromJson(_jsonMap(session.toJson())).totalCostUsd,
        1.25,
      );
    },
  );

  test('malformed required values and typed RPC values are rejected', () {
    expect(
      () => WorkspaceDto.fromJson(const <String, dynamic>{'id': 'missing'}),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => EmptyParamsDto.fromJson(const <String, dynamic>{'extra': true}),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => RpcFailureDto.fromJson(const <String, dynamic>{
        'code': 12,
        'retryable': false,
        'details': <String, dynamic>{},
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('empty RPC values round-trip only canonical empty envelopes', () {
    const params = EmptyParamsDto();
    expect(EmptyParamsDto.fromJson(params.toJson()).toJson(), isEmpty);

    const result = EmptyResultDto();
    expect(EmptyResultDto.fromJson(result.toJson()).toJson(), isEmpty);
    expect(
      () => EmptyResultDto.fromJson(const <String, dynamic>{'extra': true}),
      throwsA(isA<FormatException>()),
    );
  });

  test('protocol exceptions expose a stable diagnostic message', () {
    expect(
      const ProtocolException('bad envelope').toString(),
      'ProtocolException: bad envelope',
    );
  });

  test('typed RPC failure round-trips structured safe details', () {
    const failure = RpcFailureDto(
      code: 'invalid_params',
      details: <String, dynamic>{'field': 'workspaceId'},
    );
    final decoded = RpcFailureDto.fromJson(failure.toJson());
    expect(decoded.code, 'invalid_params');
    expect(decoded.retryable, isFalse);
    expect(decoded.details, <String, dynamic>{'field': 'workspaceId'});
  });

  test('every enum value has a stable JSON name', () {
    final values = <Enum>[
      ...SessionStatus.values,
      ...TurnStatus.values,
      ...PermissionMode.values,
      ...ApprovalStatus.values,
      ...UserQuestionStatus.values,
      ...ToolRisk.values,
      ...McpConfigScope.values,
      ...McpTransportKind.values,
      ...McpServerStatus.values,
      ...SkillListView.values,
      ...AgentCommandSource.values,
      ...WorkspaceKind.values,
      ...WorktreeKind.values,
      ...WorktreeCreateMode.values,
      ...WorktreeHookPhase.values,
      ...ProviderAuthKind.values,
      ...ProviderAuthFlow.values,
      ...ProviderCredentialOrigin.values,
      ...ProviderConnectionStatus.values,
      ...ProviderAuthAttemptStatus.values,
      ...ProviderCatalogSource.values,
      ...ProviderModelSource.values,
      ...CapabilitySupport.values,
      ...CapabilitySource.values,
      ...DiagnosticStatus.values,
    ];
    expect(values.map((value) => value.name).toSet(), isNotEmpty);
  });

  test('tool risk covers the MCP-provided dangerous tier', () {
    expect(ToolRisk.values, contains(ToolRisk.dangerous));
    expect(ToolRisk.dangerous.name, 'dangerous');
  });

  test('agent tool definitions are independently selectable', () {
    const tool = AgentToolDefinitionDto(
      id: 'acme.terminal/run_command',
      originPluginId: 'acme.terminal',
      contributionId: 'run_command',
      name: 'run_command',
      description: 'Starts a child process.',
      risk: ToolRisk.command,
      group: 'execution',
      kind: AgentToolKind.function,
      inputSchema: <String, dynamic>{'type': 'object'},
      effects: <String>['process.execute'],
      presentation: <String, dynamic>{'group': 'execution'},
    );
    expect(tool.id, 'acme.terminal/run_command');
    expect(tool.originPluginId, 'acme.terminal');
    expect(tool.contributionId, 'run_command');
    expect(tool.kind, AgentToolKind.function);
    _roundTrip(
      const AgentToolDefinitionDto(
        id: 'acme.files/read_file',
        originPluginId: 'acme.files',
        contributionId: 'read_file',
        name: 'read_file',
        description: 'Reads a workspace file.',
        risk: ToolRisk.read,
        group: 'filesystem',
        kind: AgentToolKind.function,
        inputSchema: <String, dynamic>{'type': 'object'},
        effects: <String>['filesystem.read'],
        presentation: <String, dynamic>{'group': 'filesystem'},
      ),
      (value) => value.toJson(),
      AgentToolDefinitionDto.fromJson,
    );
    _roundTrip(
      const AgentToolDefinitionDto(
        id: 'tinest.mcp/mcp__github__create_issue',
        originPluginId: 'tinest.mcp',
        contributionId: 'mcp__github__create_issue',
        name: 'mcp__github__create_issue',
        description: 'Creates a GitHub issue.',
        risk: ToolRisk.dangerous,
        group: 'mcp',
        kind: AgentToolKind.deferred,
        inputSchema: <String, dynamic>{'type': 'object'},
        outputSchema: <String, dynamic>{'type': 'object'},
        effects: <String>['mcp.invoke'],
        presentation: <String, dynamic>{'group': 'mcp', 'server': 'github'},
        available: false,
      ),
      (value) => value.toJson(),
      AgentToolDefinitionDto.fromJson,
    );
  });

  test('agent tool definitions carry the group they are toggled in', () {
    const tool = AgentToolDefinitionDto(
      id: 'acme.tools/read_mcp_resource',
      originPluginId: 'acme.tools',
      contributionId: 'read_mcp_resource',
      name: 'read_mcp_resource',
      description: 'Reads one MCP resource.',
      risk: ToolRisk.read,
      group: 'custom.tools',
      kind: AgentToolKind.function,
      inputSchema: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'uri': <String, dynamic>{'type': 'string'},
        },
        'required': <String>['uri'],
      },
      effects: <String>['mcp.read'],
      presentation: <String, dynamic>{'group': 'custom.tools'},
    );
    expect(tool.toJson()['group'], 'custom.tools');
    expect(tool.toJson()['kind'], 'function');
  });

  test(
    'terminal lifecycle payloads preserve shell, size, and replay sequence',
    () {
      const shell = ShellSpecDto(
        executable: '/bin/zsh',
        arguments: <String>['-l'],
      );
      const terminal = TerminalDto(
        id: 'terminal-1',
        worktreeId: 'worktree-1',
        title: 'Terminal 1',
        shell: shell,
        status: TerminalStatus.running,
        columns: 120,
        rows: 40,
        lastSequence: 7,
      );
      _roundTrip(shell, (value) => value.toJson(), ShellSpecDto.fromJson);
      _roundTrip(
        const TerminalOutputDto(
          terminalId: 'terminal-1',
          sequence: 7,
          data: 'ready',
        ),
        (value) => value.toJson(),
        TerminalOutputDto.fromJson,
      );
      _roundTrip(
        const TerminalListParamsDto(worktreeId: 'worktree-1'),
        (value) => value.toJson(),
        TerminalListParamsDto.fromJson,
      );
      _roundTrip(
        const TerminalListResultDto(terminals: <TerminalDto>[terminal]),
        (value) => value.toJson(),
        TerminalListResultDto.fromJson,
      );
      _roundTrip(
        const TerminalCreateParamsDto(
          id: 'terminal-1',
          worktreeId: 'worktree-1',
          title: 'Terminal 1',
          columns: 120,
          rows: 40,
        ),
        (value) => value.toJson(),
        TerminalCreateParamsDto.fromJson,
      );
      _roundTrip(
        const TerminalIdParamsDto(terminalId: 'terminal-1'),
        (value) => value.toJson(),
        TerminalIdParamsDto.fromJson,
      );
      _roundTrip(
        const TerminalAttachParamsDto(
          terminalId: 'terminal-1',
          mode: TerminalRestoreMode.resume,
          afterSequence: 3,
        ),
        (value) => value.toJson(),
        TerminalAttachParamsDto.fromJson,
      );
      // A passive attach leaves the viewport null; an active one claims a size.
      _roundTrip(
        const TerminalAttachParamsDto(
          terminalId: 'terminal-1',
          mode: TerminalRestoreMode.snapshot,
          scrollbackLines: 500,
          viewport: TerminalViewportDto(columns: 100, rows: 30),
        ),
        (value) => value.toJson(),
        TerminalAttachParamsDto.fromJson,
      );
      _roundTrip(
        const TerminalResultDto(terminal: terminal),
        (value) => value.toJson(),
        TerminalResultDto.fromJson,
      );
      _roundTrip(
        const TerminalWriteParamsDto(
          terminalId: 'terminal-1',
          data: 'echo ready\r',
        ),
        (value) => value.toJson(),
        TerminalWriteParamsDto.fromJson,
      );
      _roundTrip(
        const TerminalResizeParamsDto(
          terminalId: 'terminal-1',
          columns: 100,
          rows: 30,
        ),
        (value) => value.toJson(),
        TerminalResizeParamsDto.fromJson,
      );
      _roundTrip(
        const TerminalShellDto(shell: shell),
        (value) => value.toJson(),
        TerminalShellDto.fromJson,
      );
      _roundTrip(
        const TerminalShellDto(),
        (value) => value.toJson(),
        TerminalShellDto.fromJson,
      );
      _roundTrip(terminal, (value) => value.toJson(), TerminalDto.fromJson);
      _roundTrip(
        const TerminalAttachResultDto(
          terminal: terminal,
          restore: TerminalRestoreDto.delta(
            afterSequence: 6,
            chunks: <TerminalOutputDto>[
              TerminalOutputDto(
                terminalId: 'terminal-1',
                sequence: 7,
                data: 'ready',
              ),
            ],
          ),
        ),
        (value) => value.toJson(),
        TerminalAttachResultDto.fromJson,
      );
      // The union discriminator is what stops a client from writing snapshot
      // ANSI without resetting, so it is part of the contract, not an
      // implementation detail of the encoder.
      _roundTrip(
        const TerminalAttachResultDto(
          terminal: terminal,
          restore: TerminalRestoreDto.snapshot(
            throughSequence: 12,
            ansi: '\u001b[?1049h\u001b[Hrestored',
          ),
        ),
        (value) => value.toJson(),
        TerminalAttachResultDto.fromJson,
      );
      expect(
        const TerminalRestoreDto.snapshot(
          throughSequence: 12,
          ansi: 'x',
        ).toJson()['type'],
        'snapshot',
      );
      expect(
        () => TerminalRestoreDto.fromJson(const <String, dynamic>{
          'type': 'unknown',
        }),
        throwsA(isA<CheckedFromJsonException>()),
      );
    },
    tags: const <String>[
      'feature_test__terminal_lifecycle__contract',
      'feature_test__terminal_settings__contract',
    ],
  );

  test(
    'daemon model settings use concrete selections and model-owned RPCs',
    () {
      const selection = ModelSelectionDto(modelId: 'connection-1/model-1');
      _roundTrip(
        const DaemonModelSettingsDto(defaultModel: selection),
        (value) => value.toJson(),
        DaemonModelSettingsDto.fromJson,
      );
      _roundTrip(
        const DaemonModelSettingsDto(),
        (value) => value.toJson(),
        DaemonModelSettingsDto.fromJson,
      );
      _roundTrip(
        const SetDaemonDefaultModelParamsDto(model: selection),
        (value) => value.toJson(),
        SetDaemonDefaultModelParamsDto.fromJson,
      );

      expect(modelsGetSettingsProcedure.name, 'models.getSettings');
      expect(modelsSetDefaultModelProcedure.name, 'models.setDefaultModel');
      expect(
        rpcProcedures.map((procedure) => procedure.name),
        isNot(
          containsAll(<String>[
            'providers.getDefaultModel',
            'providers.setDefaultModel',
          ]),
        ),
      );
    },
    tags: const <String>['feature_test__model_settings__contract'],
  );

  test(
    'composer file mention contracts round-trip and default to a capped search',
    () {
      const match = FileMatchDto(
        relativePath: 'lib/src/app.dart',
        absolutePath: '/worktree/lib/src/app.dart',
        name: 'app.dart',
        isDirectory: false,
        score: 720,
      );

      expect(
        const FileSearchParamsDto(worktreeId: 'w', query: 'app').limit,
        50,
      );
      expect(
        const FileSearchResultDto(matches: <FileMatchDto>[]).truncated,
        isFalse,
      );
      expect(
        const FileMatchDto(
          relativePath: 'lib',
          absolutePath: '/worktree/lib',
          name: 'lib',
          isDirectory: true,
        ).score,
        0,
      );

      _roundTrip(match, (value) => value.toJson(), FileMatchDto.fromJson);
      _roundTrip(
        const FileSearchParamsDto(
          worktreeId: 'worktree',
          query: 'app',
          limit: 20,
        ),
        (value) => value.toJson(),
        FileSearchParamsDto.fromJson,
      );
      _roundTrip(
        const FileSearchResultDto(
          matches: <FileMatchDto>[match],
          truncated: true,
        ),
        (value) => value.toJson(),
        FileSearchResultDto.fromJson,
      );

      expect(
        () => FileSearchParamsDto.fromJson(<String, dynamic>{'query': 'app'}),
        throwsA(isA<TypeError>()),
      );
    },
    tags: const <String>['feature_test__composer_file_mention__contract'],
  );

  test(
    'composer slash command contracts round-trip across every command source',
    () {
      const command = AgentCommandDto(
        id: 'review',
        name: 'review',
        description: 'Reviews the working diff.',
        source: AgentCommandSource.project,
        sourcePath: '/worktree/.agents/commands/review.md',
        body: r'Review $ARGUMENTS and report defects.',
        argumentHint: '<path>',
      );

      expect(command.argumentHint, '<path>');
      expect(const CommandListParamsDto().workspaceId, isNull);
      expect(AgentCommandSource.values, <AgentCommandSource>[
        AgentCommandSource.userHome,
        AgentCommandSource.config,
        AgentCommandSource.project,
      ]);

      for (final source in AgentCommandSource.values) {
        _roundTrip(
          AgentCommandDto(
            id: 'review',
            name: 'review',
            description: 'Reviews the working diff.',
            source: source,
            sourcePath: '/commands/review.md',
            body: 'Review the diff.',
          ),
          (value) => value.toJson(),
          AgentCommandDto.fromJson,
        );
      }

      _roundTrip(
        const CommandListParamsDto(workspaceId: 'workspace'),
        (value) => value.toJson(),
        CommandListParamsDto.fromJson,
      );
      _roundTrip(
        const CommandListResultDto(commands: <AgentCommandDto>[command]),
        (value) => value.toJson(),
        CommandListResultDto.fromJson,
      );

      expect(
        () => AgentCommandDto.fromJson(<String, dynamic>{'id': 'review'}),
        throwsA(isA<TypeError>()),
      );
    },
    tags: const <String>['feature_test__composer_slash_command__contract'],
  );

  test(
    'worktree creation defaults to exact branch naming for older callers',
    () {
      // A client built before derive existed omits the field entirely, and the
      // daemon must keep failing loudly rather than silently renaming a branch
      // that caller believes it controls.
      final decoded = WorktreeCreateParamsDto.fromJson(<String, dynamic>{
        'id': 'worktree',
        'workspaceId': 'workspace',
        'mode': 'newBranch',
        'branchName': 'flutter',
      });
      expect(decoded.branchNaming, WorktreeBranchNaming.exact);
    },
    tags: const <String>['feature_test__worktree_lifecycle__contract'],
  );

  test('failure codes stay unique and self-describing', () {
    // Codes are the translation key every client switches on, so a duplicate
    // or a renamed constant silently drops a localized message.
    const codes = RpcErrorCodes.all;
    expect(codes, contains(RpcErrorCodes.branchAlreadyExists));
    expect(codes, contains(RpcErrorCodes.gitCommandFailed));
    expect(codes, contains(RpcErrorCodes.requestTimeout));
    expect(codes, contains(RpcErrorCodes.internalError));
    expect(
      codes.every((code) => RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(code)),
      isTrue,
    );
  }, tags: const <String>['feature_test__worktree_lifecycle__contract']);
}

void _roundTrip<T>(
  T value,
  Map<String, dynamic> Function(T value) encoder,
  T Function(Map<String, dynamic> json) decoder,
) {
  for (final procedure in rpcProcedures) {
    if (procedure.paramsType == T) {
      expect(procedure.encodeParamsObject(value as Object), encoder(value));
    }
    if (procedure.resultType == T) {
      expect(procedure.encodeResultObject(value as Object), encoder(value));
    }
  }
  for (final notification in rpcNotifications) {
    if (notification.eventType == T) {
      expect(notification.encodeObject(value as Object), encoder(value));
    }
  }
  final encoded = jsonEncode(<String, dynamic>{
    ...encoder(value),
    'futureField': true,
  });
  final json = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
  expect(decoder(json), value);
}

Map<String, dynamic> _jsonMap(Map<String, dynamic> value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
