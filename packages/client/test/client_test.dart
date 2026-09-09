import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:client/client.dart';
import 'package:json_rpc_2/json_rpc_2.dart' as json_rpc;
import 'package:protocol/protocol.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  test('an internal daemon failure prints what the daemon told us', () {
    // The daemon deliberately withholds the message and stack, which carry
    // paths, tokens, and prompt text, and sends the exception type and a trace
    // id instead. Both arrived in `details` and neither reached `toString`, so
    // a CI failure read only "Internal daemon error." -- true, and useless.
    // The trace id is what matches the run against the daemon's diagnostics
    // record holding the stack.
    const failure = TinestClientException(
      'Internal daemon error.',
      code: 'internal_error',
      details: <String, dynamic>{
        'method': 'sessions.startTurn',
        'errorType': 'StateError',
        'traceId': 'trace-7',
      },
    );

    expect(failure.toString(), contains('internal_error'));
    expect(failure.toString(), contains('sessions.startTurn'));
    expect(failure.toString(), contains('StateError'));
    expect(failure.toString(), contains('trace-7'));
  });

  test('an exception with no daemon context still reads cleanly', () {
    const failure = TinestClientException('rejected upload', code: 'nope');

    expect(failure.toString(), 'TinestClientException(nope): rejected upload');
  });

  final now = DateTime.utc(2026, 8, 2);
  const selectedModel = ModelSelectionDto(modelId: 'openai/gpt-5.6-sol');
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
    createdAt: now,
    updatedAt: now,
    model: selectedModel,
  );
  const skill = SkillSummaryDto(
    id: 'commit',
    name: 'commit',
    description: 'Writes atomic commits.',
    isImplicit: false,
  );
  const agentDefinition = AgentDefinitionDto(
    version: 5,
    id: 'tinest',
    name: 'Tinest',
    description: 'Coding agent',
    mode: AgentMode.primary,
    model: AgentModelSelectionDto(source: AgentModelSource.session),
    driverId: 'tinest.standard/driver',
    extensionIds: <String>[],
    toolIds: <String>['tinest.files/read_file'],
    pluginSettings: <String, Map<String, dynamic>>{},
    callableAgentIds: <String>[],
    prompt: 'Code carefully.',
    contentHash: 'hash',
    sourcePath: '/config/v5/agents/tinest.md',
    isBuiltIn: true,
  );
  const agentTool = AgentToolDefinitionDto(
    id: 'tinest.files/read_file',
    originPluginId: 'tinest.files',
    contributionId: 'read_file',
    name: 'read_file',
    description: 'Read a file.',
    risk: ToolRisk.read,
    group: 'filesystem',
    kind: AgentToolKind.function,
    inputSchema: <String, dynamic>{'type': 'object'},
    effects: <String>['filesystem.read'],
    presentation: <String, dynamic>{'group': 'filesystem'},
  );
  const plugin = PluginDescriptorDto(
    apiMajor: 5,
    id: 'acme.reader',
    version: '1.0.0',
    name: 'Reader',
    entrypoint: 'main.lua',
    source: PluginSource.user,
    sourcePath: '/config/v5/plugins/acme.reader',
    requestedCapabilities: <String>['workspace.read'],
  );
  const pluginGrant = AgentPluginGrantDto(
    agentId: 'tinest',
    pluginId: 'acme.reader',
    capability: 'workspace.read',
  );
  const pluginAuthoring = PluginAuthoringEnvironmentDto(
    pluginId: 'acme.reader',
    apiMajor: 5,
    sdkAbiHash: 'sdk-abi-hash',
    luaRuntimeVersion: '5.5.1',
    luaLanguageServerVersion: '3.18.2',
    pluginPath: '/config/v5/plugins/acme.reader',
    sdkLibraryPath: '/config/v5/plugin-sdk/api-5/sdk-abi-hash/library',
    configurationPath: '/config/v5/plugins/acme.reader/.luarc.json',
    synchronized: true,
  );
  const pluginSessionControl = PluginSessionControlValueDto(
    sessionId: 'agent',
    agentId: 'tinest',
    pluginId: 'acme.reader',
    contributionId: 'acme.reader/mode',
    revisionHash: 'revision',
    schema: <String, dynamic>{'type': 'boolean'},
    defaultValue: false,
    value: true,
  );
  const pluginDocument = PluginUiDocumentDto(
    id: 'reader-settings',
    pluginId: 'acme.reader',
    revisionHash: 'revision',
    slot: PluginUiSlot.agentSettings,
    root: <String, dynamic>{'type': 'section'},
  );
  const mcpServer = McpServerStateDto(
    config: McpServerConfigDto(
      id: 'github',
      transport: McpTransportKind.stdio,
      command: 'npx',
      args: <String>['-y', 'server-github'],
    ),
    status: McpServerStatus.ready,
    scope: McpConfigScope.user,
    sourcePath: '/config/mcp.json',
    serverName: 'github',
    protocolVersion: '2025-06-18',
    tools: <McpToolSummaryDto>[
      McpToolSummaryDto(
        toolId: 'mcp__github__create_issue',
        name: 'create_issue',
        description: 'Opens an issue.',
      ),
    ],
  );
  const definition = ProviderDefinitionDto(
    id: 'provider',
    name: 'Provider',
    description: 'Hosted provider',
    authMethods: <ProviderAuthMethodDto>[
      ProviderAuthMethodDto(
        id: 'api-key',
        label: 'API key',
        kind: ProviderAuthKind.apiKey,
        flow: ProviderAuthFlow.apiKey,
      ),
    ],
  );
  final connection = ProviderConnectionDto(
    id: 'provider',
    definitionId: 'provider',
    displayName: 'Provider',
    status: ProviderConnectionStatus.connected,
    authKind: ProviderAuthKind.apiKey,
    credentialOrigin: ProviderCredentialOrigin.stored,
    createdAt: now,
    updatedAt: now,
  );
  const model = ProviderModelDto(
    connectionId: 'provider',
    id: 'vendor/model-with-an-extremely-long-identifier',
    label: 'Model with an extremely long display label',
    source: ProviderModelSource.manual,
    capabilities: ModelCapabilitiesDto(
      streaming: CapabilitySupport.supported,
      toolCalling: CapabilitySupport.supported,
    ),
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
  );
  final userQuestion = UserQuestionRequestDto(
    id: 'question',
    sessionId: agent.id,
    turnId: 'turn',
    toolCallId: 'ask-call',
    questions: const <UserQuestionItemDto>[
      UserQuestionItemDto(
        id: 'q1',
        header: 'Storage',
        question: 'Which store should the cache use?',
        options: <UserQuestionOptionDto>[
          UserQuestionOptionDto(label: 'SQLite', description: 'Durable.'),
          UserQuestionOptionDto(label: 'In memory', description: 'Fast.'),
        ],
      ),
    ],
    status: UserQuestionStatus.pending,
    createdAt: now,
  );
  final timeline = TimelineEventDto(
    sessionId: agent.id,
    sequence: 2,
    turnId: 'turn',
    type: 'assistant.reasoning.delta',
    data: const <String, dynamic>{'text': 'Plan the response.'},
    createdAt: now,
  );
  test(
    'attachments use authenticated streaming HTTP with typed failures',
    tags: const <String>['feature_test__conversation_attachments__contract'],
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final requests =
          <({String method, String path, String? authorization})>[];
      final bodies = <List<int>>[];
      server.listen((request) async {
        requests.add((
          method: request.method,
          path: request.uri.path,
          authorization: request.headers.value(HttpHeaders.authorizationHeader),
        ));
        if (request.method == 'POST') {
          bodies.add(await request.expand((chunk) => chunk).toList());
          if (request.headers.value('x-file-name') == 'reject.txt') {
            request.response
              ..statusCode = HttpStatus.unprocessableEntity
              ..write('rejected upload');
          } else {
            request.response
              ..headers.contentType = ContentType.json
              ..write(
                jsonEncode(
                  AttachmentDto(
                    id: 'attachment-1',
                    fileName: 'report.txt',
                    mimeType: 'text/plain',
                    byteSize: 3,
                    kind: AttachmentKind.file,
                    sha256: 'digest',
                    createdAt: now,
                  ).toJson(),
                ),
              );
          }
          await request.response.close();
          return;
        }
        if (request.uri.path.endsWith('/missing')) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }
        request.response
          ..headers.contentType = ContentType.text
          ..headers.set(
            'content-disposition',
            "attachment; filename*=UTF-8''report%20copy.txt",
          )
          ..contentLength = 3
          ..add(<int>[4, 5, 6]);
        await request.response.close();
      });

      final connector = _TestConnector(onConfigure: _registerHello);
      final client = await TinestClient.connect(
        endpoint: HostEndpoint.parse('ws://127.0.0.1:${server.port}/ws'),
        credentials: const DaemonCredentials(bearerToken: 'attachment-token'),
        clientId: 'attachment-client',
        clientKind: 'test',
        connector: connector,
      );
      addTearDown(client.close);

      expect(client.workspaces, same(client));
      expect(client.sessions, same(client));
      expect(client.agents, same(client));
      expect(client.prompts, same(client));
      expect(client.providers, same(client));
      expect(client.mcp, same(client));
      expect(client.terminals, same(client));
      expect(client.attachments, same(client));
      expect(client.sessions.sessionUpdates, isA<Stream<SessionDto>>());
      expect(client.sessions.timelineEvents, isA<Stream<TimelineEventDto>>());
      expect(
        client.sessions.approvalRequests,
        isA<Stream<ApprovalRequestDto>>(),
      );
      expect(
        client.sessions.questionRequests,
        isA<Stream<UserQuestionRequestDto>>(),
      );
      expect(client.agents.definitionChanges, isA<Stream<void>>());
      expect(client.plugins.pluginChanges, isA<Stream<void>>());
      expect(client.prompts.skillChanges, isA<Stream<void>>());
      expect(client.prompts.commandChanges, isA<Stream<void>>());
      expect(
        client.providers.authUpdates,
        isA<Stream<ProviderAuthAttemptDto>>(),
      );
      expect(client.mcp.serverChanges, isA<Stream<void>>());
      expect(client.terminals.output, isA<Stream<TerminalOutputDto>>());
      expect(client.terminals.terminalUpdates, isA<Stream<TerminalDto>>());

      final uploaded = await client.uploadAttachment(
        fileName: 'report.txt',
        mimeType: 'text/plain',
        byteSize: 3,
        bytes: Stream<List<int>>.value(<int>[1, 2, 3]),
      );
      expect(uploaded.id, 'attachment-1');
      expect(bodies.single, <int>[1, 2, 3]);

      final download = await client.downloadAttachment(uploaded.id);
      expect(download.fileName, 'report copy.txt');
      expect(download.mimeType, 'text/plain');
      expect(download.byteSize, 3);
      expect(await download.bytes.expand((chunk) => chunk).toList(), <int>[
        4,
        5,
        6,
      ]);
      expect(
        requests.every(
          (request) => request.authorization == 'Bearer attachment-token',
        ),
        isTrue,
      );

      expect(
        client.uploadAttachment(
          fileName: 'reject.txt',
          mimeType: 'text/plain',
          byteSize: 1,
          bytes: Stream<List<int>>.value(<int>[9]),
        ),
        throwsA(
          isA<TinestClientException>()
              .having((error) => error.code, 'code', 'attachment_upload_failed')
              .having((error) => error.message, 'message', 'rejected upload'),
        ),
      );
      expect(
        client.downloadAttachment('missing'),
        throwsA(
          isA<TinestClientException>()
              .having(
                (error) => error.code,
                'code',
                'attachment_download_failed',
              )
              .having(
                (error) => error.message,
                'message',
                'Attachment download failed.',
              ),
        ),
      );
    },
  );

  test(
    'typed client covers the complete RPC surface and notifications',
    () async {
      final connector = _TestConnector(
        onConfigure: (peer, requests) {
          _registerFixtureMethods(
            peer,
            requests,
            workspace: workspace,
            worktree: worktree,
            agent: agent,
            agentDefinition: agentDefinition,
            agentTool: agentTool,
            plugin: plugin,
            pluginAuthoring: pluginAuthoring,
            pluginGrant: pluginGrant,
            pluginSessionControl: pluginSessionControl,
            pluginDocument: pluginDocument,
            mcpServer: mcpServer,
            skill: skill,
            definition: definition,
            connection: connection,
            model: model,
            approval: approval,
            userQuestion: userQuestion,
            timeline: timeline,
          );
        },
      );
      final states = <ClientConnectionState>[];
      final clientFuture = TinestClient.connect(
        endpoint: HostEndpoint.parse('127.0.0.1:7337'),
        credentials: const DaemonCredentials(bearerToken: 'secret-token'),
        clientId: 'client',
        clientKind: 'test',
        connector: connector,
      );
      await Future<void>.delayed(Duration.zero);
      final client = await clientFuture;
      final subscription = client.states.listen(states.add);
      addTearDown(subscription.cancel);
      addTearDown(client.close);

      expect(client.serverInfo.protocolVersion, tinestProtocolMajor);
      expect(connector.lastUri, Uri.parse('ws://127.0.0.1:7337/v5/ws'));
      expect(connector.lastHeaders, const <String, String>{
        'Authorization': 'Bearer secret-token',
      });
      expect(
        await client.getWorkspaceCatalog(),
        WorkspaceCatalogDto(
          workspaces: <WorkspaceDto>[workspace],
          worktrees: <WorktreeDto>[worktree],
        ),
      );
      expect(
        await client.registerWorkspace(
          workspaceId: workspace.id,
          checkoutId: worktree.id,
          rootPath: workspace.rootPath,
          name: workspace.name,
        ),
        WorkspaceRegisterResultDto(
          workspace: workspace,
          worktrees: <WorktreeDto>[worktree],
        ),
      );
      expect(
        await client.refreshWorkspace(workspace.id),
        isA<WorkspaceCatalogDto>(),
      );
      await client.unregisterWorkspace(workspace.id);
      expect(await client.suggestDirectories('work'), isNotEmpty);
      final search = await client.searchFiles(
        worktreeId: 'worktree-1',
        query: 'app',
      );
      expect(search.matches.single.relativePath, 'lib/app.dart');
      expect(search.truncated, isTrue);
      expect(
        connector.requests
            .lastWhere(
              (request) =>
                  request.method == workspacesSearchFilesProcedure.name,
            )
            .payload,
        const FileSearchParamsDto(
          worktreeId: 'worktree-1',
          query: 'app',
        ).toJson(),
      );
      expect(await client.listGitBranches(workspace.id), isNotEmpty);
      expect(
        await client.createWorktree(
          id: worktree.id,
          workspaceId: workspace.id,
          mode: WorktreeCreateMode.newBranch,
          branchName: 'topic',
        ),
        WorktreeResultDto(worktree: worktree),
      );
      expect(
        await client.previewWorktreeArchive(worktree.id),
        isA<WorktreeArchivePreviewDto>(),
      );
      expect(
        await client.archiveWorktree(worktree.id),
        WorktreeResultDto(
          worktree: worktree,
          hookRuns: const <WorktreeHookRunDto>[
            WorktreeHookRunDto(
              phase: WorktreeHookPhase.teardown,
              command: 'docker compose down',
              exitCode: 0,
              stdout: '',
              stderr: '',
            ),
          ],
        ),
      );
      expect(
        await client.getProjectSettings(workspace.id),
        const ProjectSettingsResultDto(
          settings: ProjectSettingsDto(setup: <String>['npm ci']),
          sourcePath: '/workspace/.tinest/config.json',
        ),
      );
      expect(
        await client.saveProjectSettings(
          workspace.id,
          const ProjectSettingsDto(setup: <String>['npm ci']),
        ),
        isA<ProjectSettingsResultDto>(),
      );
      expect(await client.listSessions(worktreeId: worktree.id), <SessionDto>[
        agent,
      ]);
      expect(await client.listSubagents(agent.id), <SessionDto>[agent]);
      expect(
        connector.requests
            .lastWhere(
              (request) =>
                  request.method == sessionsListSubagentsProcedure.name,
            )
            .payload,
        SessionSubagentListParamsDto(sessionId: agent.id).toJson(),
      );
      expect(
        await client.createSession(
          id: agent.id,
          worktreeId: worktree.id,
          title: agent.title,
          agentDefinitionId: agent.agentDefinitionId,
          model: const ModelSelectionDto(modelId: 'provider/model'),
        ),
        agent,
      );
      expect(
        await client.updateSettings(
          agent.id,
          const SessionSettingsPatchDto(
            hasModel: true,
            model: ModelSelectionDto(modelId: 'provider/model'),
          ),
        ),
        agent,
      );
      expect(
        await client.updateSettings(
          agent.id,
          const SessionSettingsPatchDto(hasModel: true),
        ),
        agent,
      );
      expect(
        await client.updateSettings(
          agent.id,
          const SessionSettingsPatchDto(
            hasModelControls: true,
            modelControls: <String, ModelControlValueDto>{
              'reasoning_effort': ModelControlValueDto.stringValue(
                value: 'high',
              ),
            },
          ),
        ),
        agent,
      );
      expect(
        await client.updateSettings(
          agent.id,
          const SessionSettingsPatchDto(hasModelControls: true),
        ),
        agent,
      );
      expect(
        await client.updateSettings(
          agent.id,
          const SessionSettingsPatchDto(
            permissionMode: PermissionMode.workspaceWrite,
          ),
        ),
        agent,
      );
      expect(
        await client.updateSettings(
          agent.id,
          const SessionSettingsPatchDto(
            hasModelControls: true,
            modelControls: <String, ModelControlValueDto>{
              'fast_mode': ModelControlValueDto.boolValue(value: true),
            },
          ),
        ),
        agent,
      );
      expect(
        await client.updateSettings(
          agent.id,
          const SessionSettingsPatchDto(hasModelControls: true),
        ),
        agent,
      );

      expect(await client.listTerminals(worktree.id), hasLength(1));
      final terminal = await client.createTerminal(
        id: 'terminal',
        worktreeId: worktree.id,
        title: 'Terminal',
        columns: 80,
        rows: 24,
      );
      expect(
        (await client.attachTerminal(
          terminal.id,
          mode: TerminalRestoreMode.snapshot,
        )).terminal,
        terminal,
      );
      await client.writeTerminal(terminal.id, 'echo ready\r');
      expect(
        await client.resizeTerminal(terminal.id, columns: 100, rows: 30),
        terminal,
      );
      expect(
        await client.getTerminalShell(),
        const ShellSpecDto(executable: '/bin/sh'),
      );
      await client.setTerminalShell(const ShellSpecDto(executable: '/bin/zsh'));
      await client.setTerminalShell(null);
      expect(await client.listAgentDefinitions(), <AgentDefinitionDto>[
        agentDefinition,
      ]);
      expect(await client.getAgentDefinition('tinest'), agentDefinition);
      expect(
        await client.createAgentDefinition('tinest', agentDefinition),
        agentDefinition,
      );
      expect(
        await client.updateAgentDefinition(
          agentDefinition,
          expectedContentHash: agentDefinition.contentHash,
        ),
        agentDefinition,
      );
      await client.archiveAgentDefinition('custom');
      expect(await client.resetAgentDefinition('tinest'), agentDefinition);
      expect(
        await client.validateAgentDefinition('tinest', 'markdown'),
        agentDefinition,
      );
      expect(await client.listAgentTools(), <AgentToolDefinitionDto>[
        agentTool,
      ]);
      expect(
        await client.listAgentTools(worktreeId: 'worktree-1'),
        <AgentToolDefinitionDto>[agentTool],
      );
      expect(client.plugins, same(client));
      expect(await client.listPlugins(), <PluginDescriptorDto>[plugin]);
      expect(await client.getPlugin(plugin.id), plugin);
      expect(await client.validatePlugin(plugin.id), plugin);
      expect(await client.reloadPlugin(plugin.id, 'tinest'), plugin);
      expect(await client.scaffoldPlugin(plugin.id, plugin.name), plugin);
      expect(
        await client.forkPlugin(
          sourceId: 'tinest.files',
          id: plugin.id,
          name: plugin.name,
        ),
        plugin,
      );
      expect(
        await client.getPluginAuthoringEnvironment(plugin.id),
        pluginAuthoring,
      );
      expect(
        await client.syncPluginAuthoringEnvironment(plugin.id),
        pluginAuthoring,
      );
      expect(await client.listPluginGrants('tinest'), <AgentPluginGrantDto>[
        pluginGrant,
      ]);
      expect(
        await client.grantPluginCapability(pluginGrant),
        <AgentPluginGrantDto>[pluginGrant],
      );
      expect(
        await client.revokePluginCapability(pluginGrant),
        <AgentPluginGrantDto>[pluginGrant],
      );
      await client.setPluginSecret(
        agentId: 'tinest',
        pluginId: plugin.id,
        name: 'API_TOKEN',
        value: 'wire-only-secret',
      );
      await client.removePluginSecret(
        agentId: 'tinest',
        pluginId: plugin.id,
        name: 'API_TOKEN',
      );
      expect(
        connector.requests
            .lastWhere(
              (request) => request.method == pluginsSetSecretProcedure.name,
            )
            .payload,
        const PluginSecretSetParamsDto(
          agentId: 'tinest',
          pluginId: 'acme.reader',
          name: 'API_TOKEN',
          value: 'wire-only-secret',
        ).toJson(),
      );
      expect(
        await client.getPluginSessionControl(
          sessionId: agent.id,
          pluginId: plugin.id,
          contributionId: 'acme.reader/mode',
        ),
        pluginSessionControl,
      );
      expect(
        await client.setPluginSessionControl(
          sessionId: agent.id,
          pluginId: plugin.id,
          contributionId: 'acme.reader/mode',
          value: true,
        ),
        pluginSessionControl,
      );
      expect(
        await client.renderPluginUi(
          agentId: 'tinest',
          pluginId: plugin.id,
          contributionId: 'settings',
          slot: PluginUiSlot.agentSettings,
        ),
        pluginDocument,
      );
      expect(
        await client.dispatchPluginUiAction(
          agentId: 'tinest',
          pluginId: plugin.id,
          action: const PluginUiActionDto(
            documentId: 'reader-settings',
            actionId: 'save',
          ),
        ),
        pluginDocument,
      );
      expect(await client.listMcpServers(), <McpServerStateDto>[mcpServer]);
      expect(
        await client.listMcpServers(worktreeId: 'worktree-1'),
        <McpServerStateDto>[mcpServer],
      );
      expect(await client.addMcpServer(mcpServer.config), mcpServer);
      expect(await client.updateMcpServer(mcpServer.config), mcpServer);
      await client.removeMcpServer('github');
      expect(await client.testMcpServer(mcpServer.config), mcpServer);
      await client.setMcpSecret('github.token', 'secret');
      expect((await client.listCommands()).single.name, 'review');
      expect(
        (await client.listCommands(workspaceId: 'workspace')).single.source,
        AgentCommandSource.project,
      );
      expect(
        connector.requests
            .lastWhere(
              (request) => request.method == promptsListCommandsProcedure.name,
            )
            .payload,
        const CommandListParamsDto(workspaceId: 'workspace').toJson(),
      );
      expect(
        await client.listSkills(view: SkillListView.global),
        <SkillSummaryDto>[skill],
      );
      expect(
        connector.requests
            .lastWhere(
              (request) => request.method == promptsListSkillsProcedure.name,
            )
            .payload,
        const SkillListParamsDto(view: SkillListView.global).toJson(),
      );
      expect(
        await client.listSkills(
          view: SkillListView.project,
          workspaceId: 'workspace',
        ),
        <SkillSummaryDto>[skill],
      );
      expect(
        connector.requests
            .lastWhere(
              (request) => request.method == promptsListSkillsProcedure.name,
            )
            .payload,
        const SkillListParamsDto(
          view: SkillListView.project,
          workspaceId: 'workspace',
        ).toJson(),
      );
      expect(
        await client.listSkills(
          view: SkillListView.effective,
          workspaceId: 'workspace',
        ),
        <SkillSummaryDto>[skill],
      );
      expect(
        connector.requests
            .lastWhere(
              (request) => request.method == promptsListSkillsProcedure.name,
            )
            .payload,
        const SkillListParamsDto(
          view: SkillListView.effective,
          workspaceId: 'workspace',
        ).toJson(),
      );
      final catalog = await client.listProviderCatalog();
      expect(catalog.definitions, <ProviderDefinitionDto>[definition]);
      expect(await client.listProviderConnections(), <ProviderConnectionDto>[
        connection,
      ]);
      expect(
        await client.listProviderUsage(),
        isA<List<ProviderUsageDto>>().having(
          (usage) => usage.single.connectionId,
          'connection id',
          connection.id,
        ),
      );
      expect(
        await client.connectProviderApiKey(definition.id, 'api-key'),
        connection,
      );
      expect(await client.connectProviderNone('ollama'), connection);
      final attempt = await client.startProviderAuth(
        definition.id,
        'chatgpt-device',
      );
      expect(await client.providerAuthStatus(attempt.id), attempt);
      await client.cancelProviderAuth(attempt.id);
      await client.disconnectProvider(connection.id);
      expect(
        await client.updateProviderModelPrefix(connection.id, 'work'),
        connection,
      );
      expect(
        (await client.refreshProviderCatalog()).definitions,
        <ProviderDefinitionDto>[definition],
      );
      expect(await client.listProviderModels(connection.id), <ProviderModelDto>[
        model,
      ]);
      expect(
        await client.models.getSettings(),
        const DaemonModelSettingsDto(
          defaultModel: ModelSelectionDto(modelId: 'openai/gpt-5.6-sol'),
        ),
      );
      const defaultModel = ModelSelectionDto(modelId: 'openai/gpt-5.6-sol');
      expect(
        await client.models.setDefaultModel(defaultModel),
        const DaemonModelSettingsDto(defaultModel: defaultModel),
      );
      expect(
        connector.requests
            .lastWhere(
              (request) =>
                  request.method == modelsSetDefaultModelProcedure.name,
            )
            .payload,
        const <String, dynamic>{
          'model': <String, dynamic>{'modelId': 'openai/gpt-5.6-sol'},
        },
      );
      const customConfig = CustomProviderConfigDto(
        name: 'Custom',
        baseUrl: 'http://localhost/v1',
        wireFormatId: 'openai-chat-completions',
        authenticationRequired: false,
      );
      expect(
        await client.createCustomProvider('custom', customConfig),
        connection,
      );
      expect(
        await client.updateCustomProvider('custom', customConfig),
        connection,
      );
      await client.deleteCustomProvider('custom');
      await client.startTurn(
        sessionId: agent.id,
        turnId: 'turn',
        prompt: 'hello',
      );
      await client.cancelTurn(agent.id);
      await client.resolveApproval(approvalId: approval.id, approved: true);
      await client.notePendingInput(agent.id);
      expect(
        await client.answerUserQuestion(
          requestId: userQuestion.id,
          answers: const <UserQuestionAnswerDto>[
            UserQuestionAnswerDto(
              questionId: 'q1',
              answer: 'SQLite',
              isFreeForm: false,
            ),
          ],
        ),
        userQuestion,
      );
      expect(await client.subscribeTimeline(agent.id), <TimelineEventDto>[
        timeline,
      ]);

      final timelines = <TimelineEventDto>[];
      final sessions = <SessionDto>[];
      final approvals = <ApprovalRequestDto>[];
      final questions = <UserQuestionRequestDto>[];
      final authUpdates = <ProviderAuthAttemptDto>[];
      final terminalOutput = <TerminalOutputDto>[];
      final terminalUpdates = <TerminalDto>[];
      var agentChanges = 0;
      var pluginChanges = 0;
      var skillChanges = 0;
      var commandChanges = 0;
      final eventSubscriptions = <StreamSubscription<Object?>>[
        client.sessions.timelineEvents.listen(timelines.add),
        client.sessions.sessionUpdates.listen(sessions.add),
        client.sessions.approvalRequests.listen(approvals.add),
        client.sessions.questionRequests.listen(questions.add),
        client.agents.definitionChanges.listen((_) => agentChanges += 1),
        client.plugins.pluginChanges.listen((_) => pluginChanges += 1),
        client.prompts.skillChanges.listen((_) => skillChanges += 1),
        client.prompts.commandChanges.listen((_) => commandChanges += 1),
        client.providers.authUpdates.listen(authUpdates.add),
        client.terminals.output.listen(terminalOutput.add),
        client.terminals.terminalUpdates.listen(terminalUpdates.add),
      ];
      addTearDown(() async {
        for (final subscription in eventSubscriptions) {
          await subscription.cancel();
        }
      });
      connector.connections.single.peer
        ..sendNotification(
          sessionsTimelineEventNotification.name,
          timeline.toJson(),
        )
        ..sendNotification(
          sessionsTimelineEventNotification.name,
          timeline.copyWith(sequence: 3).toJson(),
        )
        ..sendNotification(sessionsUpdatedNotification.name, agent.toJson())
        ..sendNotification(
          agentsChangedNotification.name,
          const <String, dynamic>{},
        )
        ..sendNotification(
          pluginsChangedNotification.name,
          const <String, dynamic>{},
        )
        ..sendNotification(
          promptsSkillsChangedNotification.name,
          const <String, dynamic>{},
        )
        ..sendNotification(
          promptsCommandsChangedNotification.name,
          const <String, dynamic>{},
        )
        ..sendNotification(
          sessionsApprovalRequestedNotification.name,
          approval.toJson(),
        )
        ..sendNotification(
          sessionsQuestionRequestedNotification.name,
          userQuestion.toJson(),
        )
        ..sendNotification(
          providersAuthUpdatedNotification.name,
          attempt.toJson(),
        )
        ..sendNotification(
          terminalsOutputNotification.name,
          const TerminalOutputDto(
            terminalId: 'terminal',
            sequence: 1,
            data: 'ready',
          ).toJson(),
        )
        ..sendNotification(
          terminalsUpdatedNotification.name,
          terminal.toJson(),
        );
      await Future<void>.delayed(Duration.zero);

      expect(timelines, <TimelineEventDto>[timeline.copyWith(sequence: 3)]);
      expect(sessions, <SessionDto>[agent]);
      expect(agentChanges, 1);
      expect(pluginChanges, 1);
      expect(skillChanges, 1);
      expect(commandChanges, 1);
      expect(approvals, <ApprovalRequestDto>[approval]);
      expect(questions, <UserQuestionRequestDto>[userQuestion]);
      expect(authUpdates, <ProviderAuthAttemptDto>[attempt]);
      expect(terminalOutput, hasLength(1));
      expect(terminalUpdates, <TerminalDto>[terminal]);
      await client.terminateTerminal(terminal.id);
      expect(
        connector.requests.map((request) => request.method),
        containsAll(<String>[
          workspacesCatalogProcedure.name,
          workspacesRegisterProcedure.name,
          workspacesRefreshProcedure.name,
          workspacesUnregisterProcedure.name,
          workspacesSuggestDirectoriesProcedure.name,
          workspacesSearchFilesProcedure.name,
          workspacesListBranchesProcedure.name,
          workspacesCreateWorktreeProcedure.name,
          workspacesPreviewArchiveProcedure.name,
          workspacesArchiveWorktreeProcedure.name,
          workspacesGetProjectSettingsProcedure.name,
          workspacesSaveProjectSettingsProcedure.name,
          sessionsListProcedure.name,
          sessionsListSubagentsProcedure.name,
          sessionsCreateProcedure.name,
          sessionsUpdateSettingsProcedure.name,
          agentsListProcedure.name,
          agentsGetProcedure.name,
          agentsCreateProcedure.name,
          agentsUpdateProcedure.name,
          agentsArchiveProcedure.name,
          agentsResetProcedure.name,
          agentsValidateProcedure.name,
          agentsListToolsProcedure.name,
          mcpListServersProcedure.name,
          mcpAddServerProcedure.name,
          mcpUpdateServerProcedure.name,
          mcpRemoveServerProcedure.name,
          mcpTestServerProcedure.name,
          mcpSetSecretProcedure.name,
          promptsListCommandsProcedure.name,
          promptsListSkillsProcedure.name,
          providersCatalogProcedure.name,
          providersListConnectionsProcedure.name,
          providersListUsageProcedure.name,
          providersConnectApiKeyProcedure.name,
          providersConnectNoneProcedure.name,
          providersStartAuthProcedure.name,
          providersGetAuthProcedure.name,
          providersCancelAuthProcedure.name,
          providersDisconnectProcedure.name,
          providersRefreshCatalogProcedure.name,
          providersListModelsProcedure.name,
          providersCreateCustomProcedure.name,
          providersUpdateCustomProcedure.name,
          providersDeleteCustomProcedure.name,
          sessionsStartTurnProcedure.name,
          sessionsCancelTurnProcedure.name,
          sessionsResolveApprovalProcedure.name,
          sessionsAnswerQuestionProcedure.name,
          sessionsNotePendingInputProcedure.name,
          sessionsSubscribeTimelineProcedure.name,
        ]),
      );
      expect(states, isNot(contains(ClientConnectionState.disconnected)));
    },
    tags: const <String>[
      'feature_test__daemon_management__contract',
      'feature_test__daemon_authentication__contract',
      'feature_test__workspace_catalog__contract',
      'feature_test__workspace_registration__contract',
      'feature_test__worktree_lifecycle__contract',
      'feature_test__project_settings__contract',
      'feature_test__session_lifecycle__contract',
      'feature_test__turn_execution__contract',
      'feature_test__turn_question__contract',
      'feature_test__conversation_turn_queue__contract',
      'feature_test__agent_definition_management__contract',
      'feature_test__mcp_server_management__contract',
      'feature_test__skill_catalog__contract',
      'feature_test__composer_file_mention__contract',
      'feature_test__composer_slash_command__contract',
      'feature_test__provider_catalog__contract',
      'feature_test__provider_usage__contract',
      'feature_test__provider_connection_management__contract',
      'feature_test__provider_oauth__contract',
      'feature_test__provider_custom__contract',
    ],
  );

  test('requests in flight when the peer closes fail as retryable', () async {
    final connector = _TestConnector(onConfigure: _registerHello);
    final clientFuture = TinestClient.connect(
      endpoint: HostEndpoint.parse('127.0.0.1:7337'),
      credentials: const DaemonCredentials(bearerToken: 'secret-token'),
      clientId: 'client',
      clientKind: 'test',
      connector: connector,
    );
    await Future<void>.delayed(Duration.zero);
    final client = await clientFuture;
    await client.close();

    await expectLater(
      client.getWorkspaceCatalog(),
      throwsA(
        isA<TinestClientException>().having(
          (error) => error.retryable,
          'retryable',
          isTrue,
        ),
      ),
    );
  });

  test('RPC errors preserve daemon code and retryability', () async {
    final connector = _TestConnector(
      onConfigure: (peer, requests) {
        _registerHello(peer, requests);
        peer.registerMethod(workspacesCatalogProcedure.name, (_) {
          throw json_rpc.RpcException(
            -32000,
            'Workspace unavailable',
            data: const <String, dynamic>{
              'code': 'workspace_unavailable',
              'retryable': true,
              'details': <String, dynamic>{},
            },
          );
        });
      },
    );
    final client = await TinestClient.connect(
      endpoint: HostEndpoint.parse('ws://localhost/ws'),
      credentials: const DaemonCredentials(bearerToken: 'token'),
      clientId: 'client',
      clientKind: 'test',
      connector: connector,
    );
    addTearDown(client.close);

    await expectLater(
      client.getWorkspaceCatalog(),
      throwsA(
        isA<TinestClientException>()
            .having((error) => error.code, 'code', 'workspace_unavailable')
            .having((error) => error.retryable, 'retryable', isTrue)
            .having(
              (error) => error.toString(),
              'toString',
              contains('Workspace unavailable'),
            ),
      ),
    );
  });

  test('request timeout and idempotent close clean up resources', () async {
    final connector = _TestConnector(
      onConfigure: (peer, requests) {
        _registerHello(peer, requests);
        peer.registerMethod(
          workspacesCatalogProcedure.name,
          (_) => Completer<Map<String, dynamic>>().future,
        );
      },
    );
    final client = await TinestClient.connect(
      endpoint: HostEndpoint.parse('ws://localhost/ws'),
      credentials: const DaemonCredentials(bearerToken: 'token'),
      clientId: 'client',
      clientKind: 'test',
      connector: connector,
      requestTimeout: const Duration(milliseconds: 10),
    );
    // A raw TimeoutException escapes every `on TinestClientException` handler
    // in the app, which leaves the submitting UI stuck mid-flight; the
    // deadline has to arrive as an ordinary retryable client failure.
    await expectLater(
      client.getWorkspaceCatalog(),
      throwsA(
        isA<TinestClientException>()
            .having((error) => error.code, 'code', RpcErrorCodes.requestTimeout)
            .having((error) => error.retryable, 'retryable', isTrue),
      ),
    );
    await client.close();
    await client.close();
  });

  test(
    'socket close reconnects and catches up from the last sequence',
    () async {
      final connector = _TestConnector(
        onConfigure: (peer, requests) {
          _registerHello(peer, requests);
          peer.registerMethod(sessionsSubscribeTimelineProcedure.name, (
            json_rpc.Parameters parameters,
          ) {
            final request = TimelineSubscribeParamsDto.fromJson(
              Map<String, dynamic>.from(parameters.asMap),
            );
            requests.add((
              method: sessionsSubscribeTimelineProcedure.name,
              payload: request.toJson(),
            ));
            return const TimelineResultDto(events: <TimelineEventDto>[])
                .toJson();
          });
        },
      );
      final client = await TinestClient.connect(
        endpoint: HostEndpoint.parse('ws://localhost/ws'),
        credentials: const DaemonCredentials(bearerToken: 'token'),
        clientId: 'client',
        clientKind: 'test',
        connector: connector,
        reconnectDelay: (_) => Duration.zero,
      );
      addTearDown(client.close);
      await client.subscribeTimeline('agent', afterSequence: 7);
      final connectedAgain = client.states.firstWhere(
        (state) =>
            state == ClientConnectionState.connected &&
            connector.connections.length == 2,
      );
      await connector.connections.first.peer.close();
      await connectedAgain.timeout(const Duration(seconds: 2));

      expect(connector.connections, hasLength(2));
      final subscriptions = connector.requests
          .where(
            (request) =>
                request.method == sessionsSubscribeTimelineProcedure.name,
          )
          .toList(growable: false);
      expect(subscriptions, hasLength(2));
      expect(subscriptions.last.payload['afterSequence'], 7);
      expect(
        subscriptions.last.payload['tailLimit'],
        timelineHistoryPageSize,
        reason:
            'a long disconnect must not be caught up in one unbounded frame',
      );
    },
  );

  test(
    'reading history never rewinds the live delivery cursor',
    tags: const <String>[
      'feature_test__conversation_history_pagination__contract',
    ],
    () async {
      final older = <TimelineEventDto>[
        TimelineEventDto(
          sessionId: 'agent',
          sequence: 3,
          type: 'assistant.delta',
          data: const <String, dynamic>{'text': 'older'},
          createdAt: DateTime.utc(2026, 8, 15),
        ),
      ];
      final live = TimelineEventDto(
        sessionId: 'agent',
        sequence: 12,
        type: 'assistant.delta',
        data: const <String, dynamic>{'text': 'live'},
        createdAt: DateTime.utc(2026, 8, 15, 1),
      );
      final connector = _TestConnector(
        onConfigure: (peer, requests) {
          _registerHello(peer, requests);
          peer
            ..registerMethod(sessionsSubscribeTimelineProcedure.name, (
              json_rpc.Parameters parameters,
            ) {
              final request = TimelineSubscribeParamsDto.fromJson(
                Map<String, dynamic>.from(parameters.asMap),
              );
              requests.add((
                method: sessionsSubscribeTimelineProcedure.name,
                payload: request.toJson(),
              ));
              return const TimelineResultDto(events: <TimelineEventDto>[])
                  .toJson();
            })
            ..registerMethod(sessionsTimelineHistoryProcedure.name, (
              json_rpc.Parameters parameters,
            ) {
              final request = TimelineHistoryParamsDto.fromJson(
                Map<String, dynamic>.from(parameters.asMap),
              );
              requests.add((
                method: sessionsTimelineHistoryProcedure.name,
                payload: request.toJson(),
              ));
              return TimelineResultDto(events: older).toJson();
            });
        },
      );
      final client = await TinestClient.connect(
        endpoint: HostEndpoint.parse('ws://localhost/ws'),
        credentials: const DaemonCredentials(bearerToken: 'token'),
        clientId: 'client',
        clientKind: 'test',
        connector: connector,
        reconnectDelay: (_) => Duration.zero,
      );
      addTearDown(client.close);
      await client.subscribeTimeline('agent', afterSequence: 11);

      final delivered = client.timelineEvents.first;
      final page = await client.readTimelineHistory(
        'agent',
        beforeSequence: 4,
        limit: 30,
      );
      expect(page.single.sequence, 3);
      final history = connector.requests.singleWhere(
        (request) => request.method == sessionsTimelineHistoryProcedure.name,
      );
      expect(history.payload['beforeSequence'], 4);
      expect(history.payload['limit'], 30);

      // The cursor still accepts 12: a backwards read must be invisible to
      // live delivery, which a rewound subscribe cursor would not be.
      connector.connections.single.peer.sendNotification(
        sessionsTimelineEventNotification.name,
        sessionsTimelineEventNotification.encode(live),
      );
      expect(
        (await delivered.timeout(const Duration(seconds: 2))).sequence,
        12,
      );
    },
  );

  test('re-attaching a terminal never re-delivers consumed output', () async {
    const terminal = TerminalDto(
      id: 'terminal',
      worktreeId: 'checkout',
      title: 'Terminal',
      shell: ShellSpecDto(executable: '/bin/sh'),
      status: TerminalStatus.running,
      columns: 80,
      rows: 24,
      lastSequence: 0,
    );
    final connector = _TestConnector(
      onConfigure: (peer, requests) {
        _registerHello(peer, requests);
        peer.registerMethod(
          terminalsAttachProcedure.name,
          (json_rpc.Parameters parameters) => const TerminalAttachResultDto(
            terminal: terminal,
            restore: TerminalRestoreDto.delta(
              afterSequence: 0,
              chunks: <TerminalOutputDto>[],
            ),
          ).toJson(),
        );
      },
    );
    final client = await TinestClient.connect(
      endpoint: HostEndpoint.parse('ws://localhost/ws'),
      credentials: const DaemonCredentials(bearerToken: 'token'),
      clientId: 'client',
      clientKind: 'test',
      connector: connector,
    );
    addTearDown(client.close);
    final received = <TerminalOutputDto>[];
    final subscription = client.terminals.output.listen(received.add);
    addTearDown(subscription.cancel);

    await client.attachTerminal(
      terminal.id,
      mode: TerminalRestoreMode.snapshot,
    );
    connector.connections.single.peer.sendNotification(
      terminalsOutputNotification.name,
      const TerminalOutputDto(
        terminalId: 'terminal',
        sequence: 4,
        data: 'consumed',
      ).toJson(),
    );
    await Future<void>.delayed(Duration.zero);

    // A second attach from zero must not rewind the notification gate: the
    // daemon decides what to replay, and everything already consumed would
    // otherwise be delivered a second time.
    await client.attachTerminal(
      terminal.id,
      mode: TerminalRestoreMode.snapshot,
    );
    connector.connections.single.peer.sendNotification(
      terminalsOutputNotification.name,
      const TerminalOutputDto(
        terminalId: 'terminal',
        sequence: 4,
        data: 'consumed',
      ).toJson(),
    );
    await Future<void>.delayed(Duration.zero);

    expect(received.map((output) => output.sequence), <int>[4]);
  }, tags: const <String>['feature_test__terminal_lifecycle__contract']);

  test(
    'a snapshot restore advances the gate to the sequence it already carries',
    () async {
      const terminal = TerminalDto(
        id: 'terminal',
        worktreeId: 'checkout',
        title: 'Terminal',
        shell: ShellSpecDto(executable: '/bin/sh'),
        status: TerminalStatus.running,
        columns: 80,
        rows: 24,
        lastSequence: 9,
      );
      final connector = _TestConnector(
        onConfigure: (peer, requests) {
          _registerHello(peer, requests);
          peer.registerMethod(
            terminalsAttachProcedure.name,
            (json_rpc.Parameters parameters) => const TerminalAttachResultDto(
              terminal: terminal,
              restore: TerminalRestoreDto.snapshot(
                throughSequence: 9,
                ansi: 'restored',
              ),
            ).toJson(),
          );
        },
      );
      final client = await TinestClient.connect(
        endpoint: HostEndpoint.parse('ws://localhost/ws'),
        credentials: const DaemonCredentials(bearerToken: 'token'),
        clientId: 'client',
        clientKind: 'test',
        connector: connector,
      );
      addTearDown(client.close);
      final received = <TerminalOutputDto>[];
      final subscription = client.terminals.output.listen(received.add);
      addTearDown(subscription.cancel);

      await client.attachTerminal(
        terminal.id,
        mode: TerminalRestoreMode.snapshot,
      );
      // A snapshot is not output, so it never reaches the stream; but it does
      // account for everything up to its watermark, and re-delivering that as
      // a notification would paint it twice on top of the restored screen.
      for (final sequence in <int>[9, 10]) {
        connector.connections.single.peer.sendNotification(
          terminalsOutputNotification.name,
          TerminalOutputDto(
            terminalId: 'terminal',
            sequence: sequence,
            data: 'chunk-$sequence',
          ).toJson(),
        );
      }
      await Future<void>.delayed(Duration.zero);

      expect(received.map((output) => output.sequence), <int>[10]);
    },
    tags: const <String>['feature_test__terminal_lifecycle__contract'],
  );

  test(
    'a reconnect leaves restoring a terminal to the layer that owns one',
    () async {
      final connector = _TestConnector(
        onConfigure: (peer, requests) {
          _registerHello(peer, requests);
          peer.registerMethod(terminalsAttachProcedure.name, (
            json_rpc.Parameters parameters,
          ) {
            requests.add((
              method: terminalsAttachProcedure.name,
              payload: Map<String, dynamic>.from(parameters.asMap),
            ));
            return const TerminalAttachResultDto(
              terminal: TerminalDto(
                id: 'terminal',
                worktreeId: 'checkout',
                title: 'Terminal',
                shell: ShellSpecDto(executable: '/bin/sh'),
                status: TerminalStatus.running,
                columns: 80,
                rows: 24,
                lastSequence: 0,
              ),
              restore: TerminalRestoreDto.delta(
                afterSequence: 0,
                chunks: <TerminalOutputDto>[],
              ),
            ).toJson();
          });
        },
      );
      final client = await TinestClient.connect(
        endpoint: HostEndpoint.parse('ws://localhost/ws'),
        credentials: const DaemonCredentials(bearerToken: 'token'),
        clientId: 'client',
        clientKind: 'test',
        connector: connector,
        reconnectDelay: (_) => Duration.zero,
      );
      addTearDown(client.close);
      final received = <TerminalOutputDto>[];
      final subscription = client.terminals.output.listen(received.add);
      addTearDown(subscription.cancel);
      await client.attachTerminal(
        'terminal',
        mode: TerminalRestoreMode.snapshot,
      );

      final connectedAgain = client.states.firstWhere(
        (state) =>
            state == ClientConnectionState.connected &&
            connector.connections.length == 2,
      );
      await connector.connections.first.peer.close();
      await connectedAgain.timeout(const Duration(seconds: 2));
      await Future<void>.delayed(Duration.zero);

      // A restore can be a rebuilt screen rather than output, and applying one
      // means resetting an emulator first. A transport has no emulator, so it
      // must not re-attach on its own and synthesise output from the answer.
      expect(received, isEmpty);
      expect(
        connector.requests
            .where((request) => request.method == terminalsAttachProcedure.name)
            .length,
        1,
      );
    },
    tags: const <String>['feature_test__terminal_lifecycle__contract'],
  );
}

typedef _Request = ({String method, Map<String, dynamic> payload});

final class _TestConnector implements WebSocketConnector {
  new({required this.onConfigure});

  final void Function(json_rpc.Peer peer, List<_Request> requests) onConfigure;
  final List<_TestConnection> connections = <_TestConnection>[];
  final List<_Request> requests = <_Request>[];
  Uri? lastUri;
  Map<String, String>? lastHeaders;

  @override
  Future<WebSocketChannel> connect(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    lastUri = uri;
    lastHeaders = headers;
    final controller = StreamChannelController<Object?>(sync: true);
    final peer = json_rpc.Peer(controller.local.cast<String>());
    onConfigure(peer, requests);
    unawaited(peer.listen());
    connections.add(_TestConnection(peer));
    return _TestWebSocketChannel(controller.foreign);
  }
}

final class _TestConnection {
  const new(this.peer);

  final json_rpc.Peer peer;
}

final class _TestWebSocketChannel extends StreamChannelMixin<Object?>
    implements WebSocketChannel {
  new(this._channel);

  final StreamChannel<Object?> _channel;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => Future<void>.value();

  @override
  Stream<Object?> get stream => _channel.stream;

  @override
  late final WebSocketSink sink = _TestWebSocketSink(_channel.sink);
}

final class _TestWebSocketSink extends DelegatingStreamSink<Object?>
    implements WebSocketSink {
  new(super.sink);

  @override
  Future<void> close([int? closeCode, String? closeReason]) => super.close();
}

void _registerHello(json_rpc.Peer peer, List<_Request> requests) {
  peer.registerMethod(systemHelloProcedure.name, (
    json_rpc.Parameters parameters,
  ) {
    requests.add((
      method: systemHelloProcedure.name,
      payload: Map<String, dynamic>.from(parameters.asMap),
    ));
    return const ServerInfoDto(
      serverId: 'server',
      version: 'test',
      protocolVersion: tinestProtocolMajor,
      features: <String, bool>{},
    ).toJson();
  });
}

void _registerFixtureMethods(
  json_rpc.Peer peer,
  List<_Request> requests, {
  required WorkspaceDto workspace,
  required WorktreeDto worktree,
  required SessionDto agent,
  required AgentDefinitionDto agentDefinition,
  required AgentToolDefinitionDto agentTool,
  required PluginDescriptorDto plugin,
  required PluginAuthoringEnvironmentDto pluginAuthoring,
  required AgentPluginGrantDto pluginGrant,
  required PluginSessionControlValueDto pluginSessionControl,
  required PluginUiDocumentDto pluginDocument,
  required McpServerStateDto mcpServer,
  required SkillSummaryDto skill,
  required ProviderDefinitionDto definition,
  required ProviderConnectionDto connection,
  required ProviderModelDto model,
  required ApprovalRequestDto approval,
  required UserQuestionRequestDto userQuestion,
  required TimelineEventDto timeline,
}) {
  _registerHello(peer, requests);
  final attempt = ProviderAuthAttemptDto(
    id: 'attempt',
    definitionId: definition.id,
    methodId: 'chatgpt-device',
    status: ProviderAuthAttemptStatus.awaitingUser,
    userCode: 'CODE-1234',
  );
  final workspaceCatalog = WorkspaceCatalogDto(
    workspaces: <WorkspaceDto>[workspace],
    worktrees: <WorktreeDto>[worktree],
  );
  const archivePreview = WorktreeArchivePreviewDto(
    worktreeId: 'worktree',
    dirty: false,
    unpushedCommitCount: 0,
    runningSessionCount: 0,
    removesDirectory: false,
  );
  const terminal = TerminalDto(
    id: 'terminal',
    worktreeId: 'worktree',
    title: 'Terminal',
    shell: ShellSpecDto(executable: '/bin/sh'),
    status: TerminalStatus.running,
    columns: 80,
    rows: 24,
    lastSequence: 0,
  );
  final responses = <String, Map<String, dynamic>>{
    workspacesCatalogProcedure.name: WorkspaceCatalogResultDto(
      catalog: workspaceCatalog,
    ).toJson(),
    workspacesRegisterProcedure.name: WorkspaceRegisterResultDto(
      workspace: workspace,
      worktrees: <WorktreeDto>[worktree],
    ).toJson(),
    workspacesRefreshProcedure.name: WorkspaceCatalogResultDto(
      catalog: workspaceCatalog,
    ).toJson(),
    workspacesUnregisterProcedure.name: const WorkspaceUnregisterResultDto(
      unregistered: true,
    ).toJson(),
    workspacesSuggestDirectoriesProcedure.name: const DirectorySuggestResultDto(
      suggestions: <DirectorySuggestionDto>[
        DirectorySuggestionDto(path: '/workspace', name: 'Workspace'),
      ],
    ).toJson(),
    workspacesSearchFilesProcedure.name: const FileSearchResultDto(
      matches: <FileMatchDto>[
        FileMatchDto(
          relativePath: 'lib/app.dart',
          absolutePath: '/workspace/lib/app.dart',
          name: 'app.dart',
          isDirectory: false,
          score: 620,
        ),
      ],
      truncated: true,
    ).toJson(),
    promptsListCommandsProcedure.name: const CommandListResultDto(
      commands: <AgentCommandDto>[
        AgentCommandDto(
          id: 'review',
          name: 'review',
          description: 'Reviews the working diff.',
          source: AgentCommandSource.project,
          sourcePath: '/workspace/.agents/commands/review.md',
          body: 'Review the diff.',
          argumentHint: '<path>',
        ),
      ],
    ).toJson(),
    workspacesListBranchesProcedure.name: const GitBranchesListResultDto(
      branches: <GitBranchDto>[
        GitBranchDto(name: 'main', current: true, checkedOut: true),
      ],
    ).toJson(),
    workspacesCreateWorktreeProcedure.name: WorktreeResultDto(
      worktree: worktree,
    ).toJson(),
    workspacesPreviewArchiveProcedure.name:
        const WorktreeArchivePreviewResultDto(preview: archivePreview).toJson(),
    workspacesArchiveWorktreeProcedure.name: WorktreeResultDto(
      worktree: worktree,
      hookRuns: const <WorktreeHookRunDto>[
        WorktreeHookRunDto(
          phase: WorktreeHookPhase.teardown,
          command: 'docker compose down',
          exitCode: 0,
          stdout: '',
          stderr: '',
        ),
      ],
    ).toJson(),
    workspacesGetProjectSettingsProcedure.name: const ProjectSettingsResultDto(
      settings: ProjectSettingsDto(setup: <String>['npm ci']),
      sourcePath: '/workspace/.tinest/config.json',
    ).toJson(),
    workspacesSaveProjectSettingsProcedure.name: const ProjectSettingsResultDto(
      settings: ProjectSettingsDto(setup: <String>['npm ci']),
      sourcePath: '/workspace/.tinest/config.json',
    ).toJson(),
    sessionsListProcedure.name: SessionListResultDto(
      sessions: <SessionDto>[agent],
    ).toJson(),
    sessionsListSubagentsProcedure.name: SessionListResultDto(
      sessions: <SessionDto>[agent],
    ).toJson(),
    sessionsCreateProcedure.name: SessionResultDto(session: agent).toJson(),
    sessionsUpdateSettingsProcedure.name: SessionResultDto(session: agent)
        .toJson(),
    terminalsListProcedure.name: const TerminalListResultDto(
      terminals: <TerminalDto>[terminal],
    ).toJson(),
    terminalsCreateProcedure.name: const TerminalResultDto(terminal: terminal)
        .toJson(),
    terminalsAttachProcedure.name: const TerminalAttachResultDto(
      terminal: terminal,
      restore: TerminalRestoreDto.delta(
        afterSequence: 0,
        chunks: <TerminalOutputDto>[],
      ),
    ).toJson(),
    terminalsWriteProcedure.name: const <String, dynamic>{},
    terminalsResizeProcedure.name: const TerminalResultDto(terminal: terminal)
        .toJson(),
    terminalsTerminateProcedure.name: const <String, dynamic>{},
    terminalsGetDefaultShellProcedure.name: const TerminalShellDto(
      shell: ShellSpecDto(executable: '/bin/sh'),
    ).toJson(),
    terminalsSetDefaultShellProcedure.name: const <String, dynamic>{},
    agentsListProcedure.name: AgentDefinitionListResultDto(
      definitions: <AgentDefinitionDto>[agentDefinition],
    ).toJson(),
    agentsGetProcedure.name: AgentDefinitionResultDto(
      definition: agentDefinition,
    ).toJson(),
    agentsCreateProcedure.name: AgentDefinitionResultDto(
      definition: agentDefinition,
    ).toJson(),
    agentsUpdateProcedure.name: AgentDefinitionResultDto(
      definition: agentDefinition,
    ).toJson(),
    agentsArchiveProcedure.name: const <String, dynamic>{},
    agentsResetProcedure.name: AgentDefinitionResultDto(
      definition: agentDefinition,
    ).toJson(),
    agentsValidateProcedure.name: AgentDefinitionResultDto(
      definition: agentDefinition,
    ).toJson(),
    agentsListToolsProcedure.name: AgentToolCatalogResultDto(
      tools: <AgentToolDefinitionDto>[agentTool],
    ).toJson(),
    pluginsListProcedure.name: PluginListResultDto(
      plugins: <PluginDescriptorDto>[plugin],
    ).toJson(),
    pluginsGetProcedure.name: PluginResultDto(plugin: plugin).toJson(),
    pluginsValidateProcedure.name: PluginResultDto(plugin: plugin).toJson(),
    pluginsReloadProcedure.name: PluginResultDto(plugin: plugin).toJson(),
    pluginsScaffoldProcedure.name: PluginResultDto(plugin: plugin).toJson(),
    pluginsForkProcedure.name: PluginResultDto(plugin: plugin).toJson(),
    pluginsGetPluginAuthoringEnvironmentProcedure.name:
        PluginAuthoringEnvironmentResultDto(environment: pluginAuthoring)
            .toJson(),
    pluginsSyncPluginAuthoringEnvironmentProcedure.name:
        PluginAuthoringEnvironmentResultDto(environment: pluginAuthoring)
            .toJson(),
    pluginsListGrantsProcedure.name: PluginGrantListResultDto(
      grants: <AgentPluginGrantDto>[pluginGrant],
    ).toJson(),
    pluginsGrantProcedure.name: PluginGrantListResultDto(
      grants: <AgentPluginGrantDto>[pluginGrant],
    ).toJson(),
    pluginsRevokeProcedure.name: PluginGrantListResultDto(
      grants: <AgentPluginGrantDto>[pluginGrant],
    ).toJson(),
    pluginsSetSecretProcedure.name: const <String, dynamic>{},
    pluginsRemoveSecretProcedure.name: const <String, dynamic>{},
    pluginsGetSessionControlProcedure.name: PluginSessionControlResultDto(
      control: pluginSessionControl,
    ).toJson(),
    pluginsSetSessionControlProcedure.name: PluginSessionControlResultDto(
      control: pluginSessionControl,
    ).toJson(),
    pluginsRenderUiProcedure.name: PluginUiDocumentResultDto(
      document: pluginDocument,
    ).toJson(),
    pluginsDispatchUiActionProcedure.name: PluginUiDocumentResultDto(
      document: pluginDocument,
    ).toJson(),
    mcpListServersProcedure.name: McpServersResultDto(
      servers: <McpServerStateDto>[mcpServer],
    ).toJson(),
    mcpAddServerProcedure.name: McpServerStateResultDto(state: mcpServer)
        .toJson(),
    mcpUpdateServerProcedure.name: McpServerStateResultDto(state: mcpServer)
        .toJson(),
    mcpRemoveServerProcedure.name: const <String, dynamic>{},
    mcpTestServerProcedure.name: McpServerStateResultDto(state: mcpServer)
        .toJson(),
    mcpSetSecretProcedure.name: const <String, dynamic>{},
    promptsListSkillsProcedure.name: SkillListResultDto(
      skills: <SkillSummaryDto>[skill],
    ).toJson(),
    providersCatalogProcedure.name: ProviderCatalogResultDto(
      catalog: ProviderCatalogDto(
        definitions: <ProviderDefinitionDto>[definition],
        source: ProviderCatalogSource.bundled,
        updatedAt: workspace.createdAt,
      ),
    ).toJson(),
    providersListConnectionsProcedure.name: ProviderConnectionsResultDto(
      connections: <ProviderConnectionDto>[connection],
    ).toJson(),
    providersListUsageProcedure.name: ProviderUsageResultDto(
      usage: <ProviderUsageDto>[
        ProviderUsageDto(
          connectionId: connection.id,
          status: ProviderUsageStatus.unsupported,
          fetchedAt: workspace.createdAt,
        ),
      ],
    ).toJson(),
    providersConnectApiKeyProcedure.name: ProviderConnectionResultDto(
      connection: connection,
    ).toJson(),
    providersConnectNoneProcedure.name: ProviderConnectionResultDto(
      connection: connection,
    ).toJson(),
    providersStartAuthProcedure.name: ProviderAuthAttemptResultDto(
      attempt: attempt,
    ).toJson(),
    providersGetAuthProcedure.name: ProviderAuthAttemptResultDto(
      attempt: attempt,
    ).toJson(),
    providersCancelAuthProcedure.name: const <String, dynamic>{},
    providersDisconnectProcedure.name: const <String, dynamic>{},
    providersUpdateModelPrefixProcedure.name: ProviderConnectionResultDto(
      connection: connection,
    ).toJson(),
    providersRefreshCatalogProcedure.name: ProviderCatalogResultDto(
      catalog: ProviderCatalogDto(
        definitions: <ProviderDefinitionDto>[definition],
        source: ProviderCatalogSource.refreshed,
        updatedAt: workspace.createdAt,
      ),
    ).toJson(),
    providersListModelsProcedure.name: ProviderModelsResultDto(
      models: <ProviderModelDto>[model],
    ).toJson(),
    modelsGetSettingsProcedure.name: const DaemonModelSettingsDto(
      defaultModel: ModelSelectionDto(modelId: 'openai/gpt-5.6-sol'),
    ).toJson(),
    modelsSetDefaultModelProcedure.name: const DaemonModelSettingsDto(
      defaultModel: ModelSelectionDto(modelId: 'openai/gpt-5.6-sol'),
    ).toJson(),
    providersCreateCustomProcedure.name: ProviderConnectionResultDto(
      connection: connection,
    ).toJson(),
    providersUpdateCustomProcedure.name: ProviderConnectionResultDto(
      connection: connection,
    ).toJson(),
    providersDeleteCustomProcedure.name: const <String, dynamic>{},
    sessionsStartTurnProcedure.name: const TurnStartResultDto(created: true)
        .toJson(),
    sessionsCancelTurnProcedure.name: const <String, dynamic>{},
    sessionsResolveApprovalProcedure.name: ApprovalResultDto(approval: approval)
        .toJson(),
    sessionsNotePendingInputProcedure.name: const <String, dynamic>{},
    sessionsAnswerQuestionProcedure.name: UserQuestionResultDto(
      request: userQuestion,
    ).toJson(),
    sessionsSubscribeTimelineProcedure.name: TimelineResultDto(
      events: <TimelineEventDto>[timeline],
    ).toJson(),
  };
  for (final entry in responses.entries) {
    peer.registerMethod(entry.key, (json_rpc.Parameters parameters) {
      requests.add((
        method: entry.key,
        payload: Map<String, dynamic>.from(parameters.asMap),
      ));
      return entry.value;
    });
  }
}
