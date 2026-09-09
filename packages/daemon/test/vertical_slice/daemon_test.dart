@Timeout(Duration(minutes: 2))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agent/agent.dart';
import 'package:client/client.dart';
import 'package:daemon/daemon.dart';
import 'package:daemon/src/features/providers/infrastructure/openai/openai.dart';
import 'package:daemon/src/shared/infrastructure/persistence/database.dart';
import 'package:json_rpc_2/json_rpc_2.dart' as json_rpc;
import 'package:path/path.dart' as p;
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

/// Budget for one broadcast event to arrive.
///
/// These drive a real daemon over a real WebSocket with SQLite behind an
/// isolate, and a cold Windows runner is comfortably slower than the five
/// seconds this used to allow. A generous budget costs wall-clock only when
/// something is genuinely broken.
const Duration _eventTimeout = Duration(minutes: 1);

/// Bundled deterministic model whose declared surface supports every default
/// v5 Agent contribution, including deferred tools.
const String _testModelId = 'openai/gpt-5.6-sol';

void main() {
  test(
    'daemon stop cancels and drains an active turn before closing storage',
    () async {
      final home = await Directory.systemTemp.createTemp(
        'tinest-turn-shutdown-home-',
      );
      final workspace = await Directory.systemTemp.createTemp(
        'tinest-turn-shutdown-workspace-',
      );
      final provider = _ShutdownProvider();
      final handle = await DaemonApplication.start(
        DaemonConfig(
          homeDirectory: home.path,
          port: 0,
          bearerToken: 'shutdown-token-0123456789abcdef012345',
          useEnvironmentCredentials: false,
        ),
        provider: provider,
      );
      final client = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
        credentials: const DaemonCredentials(
          bearerToken: 'shutdown-token-0123456789abcdef012345',
        ),
        clientId: 'turn-shutdown-test',
        clientKind: 'test',
      );
      addTearDown(() async {
        await client.close();
        await handle.stop();
        await home.delete(recursive: true);
        await workspace.delete(recursive: true);
      });

      final catalog = await client.registerWorkspace(
        workspaceId: 'shutdown-workspace',
        checkoutId: 'shutdown-checkout',
        rootPath: workspace.path,
        name: 'Shutdown',
      );
      final session = await client.createSession(
        id: 'shutdown-session',
        worktreeId: catalog.worktrees.single.id,
        title: 'Shutdown session',
        agentDefinitionId: 'tinest',
        model: const ModelSelectionDto(modelId: _testModelId),
      );
      await client.startTurn(
        sessionId: session.id,
        turnId: 'shutdown-turn',
        prompt: 'Wait until shutdown.',
      );
      await _waitForProviderStartOrTurnFailure(
        client: client,
        worktreeId: session.worktreeId,
        sessionId: session.id,
        started: provider.started,
      );

      await handle.stop().timeout(_eventTimeout);

      await provider.cancelled.future.timeout(_eventTimeout);
    },
  );

  test('daemon permission default survives a restart', () async {
    final home = await Directory.systemTemp.createTemp(
      'tinest-permission-home-',
    );
    const token = 'permission-token-0123456789abcdef012345';
    final config = DaemonConfig(
      homeDirectory: home.path,
      port: 0,
      bearerToken: token,
      useEnvironmentCredentials: false,
    );
    try {
      final firstHandle = await DaemonApplication.start(config);
      final firstClient = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: firstHandle.boundEndpoint),
        credentials: const DaemonCredentials(bearerToken: token),
        clientId: 'permission-first',
        clientKind: 'test',
      );
      expect(
        (await firstClient.getDefaultPermissionMode()).defaultMode,
        PermissionMode.ask,
      );
      await firstClient.setDefaultPermissionMode(PermissionMode.fullAccess);
      await firstClient.close();
      await firstHandle.stop();

      final secondHandle = await DaemonApplication.start(config);
      final secondClient = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: secondHandle.boundEndpoint),
        credentials: const DaemonCredentials(bearerToken: token),
        clientId: 'permission-second',
        clientKind: 'test',
      );
      expect(
        (await secondClient.getDefaultPermissionMode()).defaultMode,
        PermissionMode.fullAccess,
      );
      await secondClient.close();
      await secondHandle.stop();
    } finally {
      await home.delete(recursive: true);
    }
  }, tags: const <String>['feature_test__permission_settings__verticalSlice']);

  test(
    'standalone application serves authenticated workspace and agent RPCs',
    () async {
      final home = await Directory.systemTemp.createTemp('tinest-daemon-home-');
      final workspace = await Directory.systemTemp.createTemp(
        'tinest-workspace-',
      );
      final modelServer = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      modelServer.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, dynamic>{
            'object': 'list',
            'data': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'test-model', 'owned_by': 'test'},
              <String, dynamic>{'id': 'discovered-model', 'owned_by': 'test'},
            ],
          }),
        );
        await request.response.close();
      });
      final handle = await DaemonApplication.start(
        DaemonConfig(
          homeDirectory: home.path,
          // A temporary directory stands in for the machine home so the test
          // never depends on the home of whoever runs it.
          osHomeDirectory: workspace.path,
          port: 0,
          bearerToken: 'test-token-0123456789abcdef0123456789',
          useEnvironmentCredentials: false,
        ),
        provider: _PatchProvider(),
      );
      addTearDown(() async {
        await handle.stop();
        await home.delete(recursive: true);
        await workspace.delete(recursive: true);
        await modelServer.close(force: true);
      });

      final client = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
        credentials: const DaemonCredentials(
          bearerToken: 'test-token-0123456789abcdef0123456789',
        ),
        clientId: 'integration-test',
        clientKind: 'test',
      );
      addTearDown(client.close);

      expect(client.serverInfo.serverId, handle.serverId);
      expect(client.serverInfo.features, isNot(contains('providerAdmin')));
      expect(client.serverInfo.features['jsonRpc2'], isTrue);
      // The handshake carries the browsing home so the app can open a picker
      // there instead of at the drive root.
      expect(client.serverInfo.homeDirectory, workspace.path);
      expect(
        (await client.getDefaultPermissionMode()).defaultMode,
        PermissionMode.ask,
      );
      await client.setDefaultPermissionMode(PermissionMode.fullAccess);
      expect(
        (await client.getDefaultPermissionMode()).defaultMode,
        PermissionMode.fullAccess,
      );
      await client.setDefaultPermissionMode(PermissionMode.ask);
      final initialCatalog = await client.listProviderCatalog();
      expect(
        initialCatalog.definitions.map((item) => item.id),
        containsAll(<String>['openai', 'deepseek', 'ollama']),
      );
      expect(
        initialCatalog.toJson().toString(),
        isNot(anyOf(contains('baseUrl'), contains('transport'))),
      );
      final custom = await client.createCustomProvider(
        'local-test',
        CustomProviderConfigDto(
          name: 'Local test',
          baseUrl: 'http://127.0.0.1:${modelServer.port}/v1',
          wireFormatId: openAIChatCompletionsWireId,
          authenticationRequired: false,
          models: const <ManualProviderModelDto>[
            ManualProviderModelDto(id: 'test-model', label: 'test-model'),
          ],
        ),
      );
      expect(custom.status, ProviderConnectionStatus.connected);
      expect(custom.authKind, ProviderAuthKind.none);
      expect(
        (await client.listProviderConnections())
            .singleWhere((connection) => connection.id == custom.id)
            .id,
        custom.id,
      );
      expect(
        (await client.listProviderUsage())
            .singleWhere((usage) => usage.connectionId == custom.id)
            .status,
        ProviderUsageStatus.unsupported,
      );
      expect(
        (await client.listProviderModels(custom.id)).map((item) => item.id),
        containsAll(<String>[
          'local-test/test-model',
          'local-test/discovered-model',
        ]),
      );
      final updatedCustom = await client.updateCustomProvider(
        custom.id,
        CustomProviderConfigDto(
          name: 'Updated local test',
          baseUrl: 'http://127.0.0.1:${modelServer.port}/v1',
          wireFormatId: openAIChatCompletionsWireId,
          authenticationRequired: false,
          models: const <ManualProviderModelDto>[
            ManualProviderModelDto(id: 'test-model', label: 'test-model'),
          ],
        ),
      );
      expect(updatedCustom.displayName, 'Updated local test');
      final temporary = await client.createCustomProvider(
        'temporary',
        CustomProviderConfigDto(
          name: 'Temporary',
          baseUrl: 'http://127.0.0.1:${modelServer.port}/v1',
          wireFormatId: openAIResponsesWireId,
          authenticationRequired: false,
          models: const <ManualProviderModelDto>[
            ManualProviderModelDto(id: 'test-model', label: 'test-model'),
          ],
        ),
      );
      expect(temporary.id, isNot('temporary'));
      await client.deleteCustomProvider(temporary.id);
      expect(
        (await client.listProviderConnections()).map((item) => item.id),
        isNot(contains('temporary')),
      );
      final registered = await client.registerWorkspace(
        workspaceId: 'workspace-1',
        checkoutId: 'checkout-1',
        rootPath: workspace.path,
        name: 'Workspace',
      );
      expect(
        registered.workspace.rootPath,
        workspace.resolveSymbolicLinksSync(),
      );
      expect((await client.getWorkspaceCatalog()).workspaces, hasLength(1));
      final checkout = registered.worktrees.single;

      final projectShell = ShellSpecDto(
        executable: Platform.isWindows ? 'cmd.exe' : '/bin/sh',
      );
      await client.setTerminalShell(
        const ShellSpecDto(executable: '/definitely/missing-shell'),
      );
      expect(
        await client.getTerminalShell(),
        const ShellSpecDto(executable: '/definitely/missing-shell'),
      );
      await client.saveProjectSettings(
        registered.workspace.id,
        ProjectSettingsDto(shell: projectShell),
      );
      final terminal = await client.createTerminal(
        id: 'terminal-1',
        worktreeId: checkout.id,
        title: 'Terminal 1',
        columns: 80,
        rows: 24,
      );
      expect(terminal.shell, projectShell);
      expect(
        (await client.listTerminals(checkout.id)).map((item) => item.id),
        contains(terminal.id),
      );
      final attached = await client.attachTerminal(
        terminal.id,
        mode: TerminalRestoreMode.snapshot,
      );
      expect(attached.terminal.id, terminal.id);
      const marker = 'tinest-terminal-ready';
      final output = client.terminals.output
          .where((output) => output.terminalId == terminal.id)
          .map((output) => output.data)
          .firstWhere((data) => data.contains(marker))
          .timeout(_eventTimeout);
      await client.resizeTerminal(terminal.id, columns: 100, rows: 30);
      await client.writeTerminal(
        terminal.id,
        Platform.isWindows ? 'echo $marker\r' : "printf '$marker\\n'\r",
      );
      expect(await output, contains(marker));

      // What a full-screen program does, driven by printf so the assertion
      // does not depend on which editor a CI image ships. The screen the
      // daemon hands back has to carry the alternate buffer, or reattaching
      // to a running editor comes back to the shell behind it.
      if (!Platform.isWindows) {
        const altMarker = 'tinest-alt-screen';
        // Waiting for the marker alone matches the shell echoing the command
        // back, which happens before printf runs. The alternate-screen entry
        // appears as a real escape byte only in the program's own output; the
        // echo shows it as the literal text that was typed.
        const altScreenEntry = '\u001b[?1049h';
        final painted = Completer<void>();
        final seen = StringBuffer();
        final painting = client.terminals.output
            .where((output) => output.terminalId == terminal.id)
            .listen((output) {
              seen.write(output.data);
              final sofar = seen.toString();
              if (!painted.isCompleted &&
                  sofar.contains(altScreenEntry) &&
                  sofar.contains(altMarker)) {
                painted.complete();
              }
            });
        // Backslash escapes here are for printf, not for Dart: the shell
        // is what turns them into control bytes, the way a real program
        // entering its alternate screen would.
        const enterAltScreen = r'\033[?1049h\033[H\033[2J';
        await client.writeTerminal(
          terminal.id,
          "printf '$enterAltScreen$altMarker'\r",
        );
        await painted.future.timeout(_eventTimeout);
        await painting.cancel();

        final restored = await client.attachTerminal(
          terminal.id,
          mode: TerminalRestoreMode.snapshot,
        );
        final restore = restored.restore;
        expect(restore, isA<TerminalSnapshotRestoreDto>());
        restore as TerminalSnapshotRestoreDto;
        expect(restore.ansi, contains('\u001b[?1049h'));
        expect(restore.ansi, contains(altMarker));
        expect(restore.throughSequence, greaterThan(0));
      }

      await client.terminateTerminal(terminal.id);

      const wireDefault = ModelSelectionDto(modelId: 'local-test/test-model');
      expect(
        (await client.models.getSettings()).defaultModel,
        const ModelSelectionDto(modelId: 'openai/gpt-4'),
      );
      expect(
        (await client.models.setDefaultModel(wireDefault)).defaultModel,
        wireDefault,
      );
      final inherited = await client.createSession(
        id: 'model-inherited',
        worktreeId: checkout.id,
        title: 'Model inherited',
        agentDefinitionId: 'tinest',
      );
      expect(inherited.model, isNull);
      await expectLater(
        client.models.setDefaultModel(
          const ModelSelectionDto(modelId: 'local-test/missing-model'),
        ),
        throwsA(
          isA<TinestClientException>().having(
            (error) => error.code,
            'code',
            'model_unavailable',
          ),
        ),
      );
      await expectLater(
        client.createSession(
          id: 'agent-rejected',
          worktreeId: checkout.id,
          title: 'Rejected',
          agentDefinitionId: 'tinest',
          model: const ModelSelectionDto(
            modelId: 'missing-connection/test-model',
          ),
        ),
        throwsA(
          isA<TinestClientException>().having(
            (error) => error.code,
            'code',
            'provider_not_connected',
          ),
        ),
      );
      final agent = await client.createSession(
        id: 'agent-1',
        worktreeId: checkout.id,
        title: 'Session',
        agentDefinitionId: 'tinest',
        model: const ModelSelectionDto(modelId: 'local-test/test-model'),
      );
      expect(agent.status, SessionStatus.idle);
      expect(
        agent.model,
        const ModelSelectionDto(modelId: 'local-test/test-model'),
      );
      expect(
        (await client.sessions.listSessions(worktreeId: checkout.id))
            .singleWhere((session) => session.id == agent.id)
            .model,
        agent.model,
      );
      final tinest = (await client.listAgentDefinitions()).single;
      final configuredDefinition = await client.updateAgentDefinition(
        tinest.copyWith(
          model: const AgentModelSelectionDto(
            source: AgentModelSource.fixed,
            modelId: 'local-test/test-model',
          ),
        ),
        expectedContentHash: tinest.contentHash,
      );
      expect(configuredDefinition.model.source, AgentModelSource.fixed);
      expect(configuredDefinition.model.modelId, 'local-test/test-model');
      expect(
        await client.sessions.listSessions(worktreeId: checkout.id),
        hasLength(2),
      );
      await client.models.setDefaultModel(
        const ModelSelectionDto(modelId: 'openai/gpt-4'),
      );
      final agentPriority = await client.createSession(
        id: 'agent-priority',
        worktreeId: checkout.id,
        title: 'Agent priority',
        agentDefinitionId: 'tinest',
      );
      expect(agentPriority.model, isNull);
      final chatPriority = await client.createSession(
        id: 'chat-priority',
        worktreeId: checkout.id,
        title: 'Chat priority',
        agentDefinitionId: 'tinest',
        model: const ModelSelectionDto(modelId: 'openai/gpt-4'),
      );
      expect(
        chatPriority.model,
        const ModelSelectionDto(modelId: 'openai/gpt-4'),
      );
      await client.models.setDefaultModel(wireDefault);
      expect(await client.subscribeTimeline(agent.id), isEmpty);

      final approvalFuture = client.sessions.approvalRequests.first.timeout(
        _eventTimeout,
      );
      final completedFuture = client.sessions.timelineEvents
          .firstWhere(
            (event) =>
                event.type == 'turn.completed' || event.type == 'turn.failed',
          )
          .timeout(_eventTimeout);
      await client.startTurn(
        sessionId: agent.id,
        turnId: 'turn-1',
        prompt: 'Create result.txt',
      );
      final approval = await approvalFuture;
      expect(approval.toolName, 'apply_patch');
      expect(approval.preview, contains('result.txt'));
      await client.resolveApproval(approvalId: approval.id, approved: true);
      final outcome = await completedFuture;
      expect(
        outcome.type,
        'turn.completed',
        reason: 'Turn failed: ${outcome.data}',
      );
      await _waitForIdleSession(client, checkout.id, agent.id);

      expect(
        (await client.sessions.updateSettings(
          agent.id,
          const SessionSettingsPatchDto(
            hasModel: true,
            model: ModelSelectionDto(modelId: 'local-test/test-model'),
          ),
        )).model,
        const ModelSelectionDto(modelId: 'local-test/test-model'),
      );
      expect(
        (await client.sessions.updateSettings(
          agent.id,
          const SessionSettingsPatchDto(hasModel: true),
        )).model,
        isNull,
      );
      expect(
        (await client.sessions.updateSettings(
          agent.id,
          SessionSettingsPatchDto(hasModel: true, model: agent.model),
        )).model,
        agent.model,
      );
      expect(
        (await client.sessions.listSessions(worktreeId: checkout.id))
            .singleWhere((session) => session.id == agent.id)
            .model,
        agent.model,
      );
      await expectLater(
        client.sessions.updateSettings(
          agent.id,
          const SessionSettingsPatchDto(
            hasModel: true,
            model: ModelSelectionDto(modelId: 'local-test/missing-model'),
          ),
        ),
        throwsA(
          isA<TinestClientException>().having(
            (error) => error.code,
            'code',
            'model_unavailable',
          ),
        ),
      );

      // A session created without a choice is pinned to the configured
      // default rather than left to resolve it later.
      expect(agent.permissionMode, PermissionMode.ask);

      // Model controls are persisted atomically with other session settings.
      expect(
        (await client.sessions.updateSettings(
          agent.id,
          const SessionSettingsPatchDto(
            permissionMode: PermissionMode.workspaceWrite,
          ),
        )).permissionMode,
        PermissionMode.workspaceWrite,
      );
      final withControls = await client.sessions.updateSettings(
        agent.id,
        const SessionSettingsPatchDto(hasModelControls: true),
      );
      expect(withControls.modelControls, isEmpty);
      final overridden = (await client.sessions.listSessions(
        worktreeId: checkout.id,
      )).singleWhere((session) => session.id == agent.id);
      expect(overridden.modelControls, isEmpty);
      expect(overridden.permissionMode, PermissionMode.workspaceWrite);
      // A patch that carries no mode changes the rest and leaves the session
      // running under the mode it already had.
      expect(
        (await client.sessions.updateSettings(
          agent.id,
          const SessionSettingsPatchDto(hasModelControls: true),
        )).permissionMode,
        PermissionMode.workspaceWrite,
      );

      expect(
        await File('${workspace.path}/result.txt').readAsString(),
        'done\n',
      );
      final timeline = await client.subscribeTimeline(agent.id);
      expect(
        timeline.map((event) => event.sequence),
        orderedEquals(
          List<int>.generate(timeline.length, (index) => index + 1),
        ),
      );
      expect(timeline.map((event) => event.type), contains('tool.completed'));
      expect(timeline.map((event) => event.type), contains('turn.completed'));
      expect(
        timeline
            .where((event) => event.type == 'assistant.reasoning.delta')
            .map((event) => event.data['text']),
        orderedEquals(<String>[
          'Planning the patch.',
          'Checking the patch result.',
        ]),
      );
      final invalidAgentDefinition = await client.updateAgentDefinition(
        configuredDefinition.copyWith(
          model: const AgentModelSelectionDto(
            source: AgentModelSource.fixed,
            modelId: 'local-test/missing-model',
          ),
        ),
        expectedContentHash: configuredDefinition.contentHash,
      );
      await expectLater(
        client.createSession(
          id: 'invalid-agent-model',
          worktreeId: checkout.id,
          title: 'Invalid agent model',
          agentDefinitionId: 'tinest',
        ),
        throwsA(
          isA<TinestClientException>().having(
            (error) => error.code,
            'code',
            'model_unavailable',
          ),
        ),
      );
      final restoredAgentDefinition = await client.updateAgentDefinition(
        invalidAgentDefinition.copyWith(
          model: const AgentModelSelectionDto(
            source: AgentModelSource.fixed,
            modelId: 'local-test/test-model',
          ),
        ),
        expectedContentHash: invalidAgentDefinition.contentHash,
      );
      await client.disconnectProvider(custom.id);
      expect((await client.models.getSettings()).defaultModel, wireDefault);
      await expectLater(
        client.startTurn(
          sessionId: agent.id,
          turnId: 'turn-stale-provider',
          prompt: 'This must not run.',
        ),
        throwsA(
          isA<TinestClientException>().having(
            (error) => error.code,
            'code',
            'provider_not_connected',
          ),
        ),
      );
      expect(
        (await client.sessions.listSessions(worktreeId: checkout.id))
            .singleWhere((session) => session.id == agent.id)
            .status,
        SessionStatus.idle,
      );
      final withoutAgentModel = await client.updateAgentDefinition(
        restoredAgentDefinition.copyWith(
          model: const AgentModelSelectionDto(source: AgentModelSource.session),
        ),
        expectedContentHash: restoredAgentDefinition.contentHash,
      );
      await expectLater(
        client.createSession(
          id: 'invalid-daemon-default',
          worktreeId: checkout.id,
          title: 'Invalid daemon default',
          agentDefinitionId: 'tinest',
        ),
        throwsA(
          isA<TinestClientException>().having(
            (error) => error.code,
            'code',
            'model_unavailable',
          ),
        ),
      );
      await client.updateAgentDefinition(
        withoutAgentModel.copyWith(
          model: const AgentModelSelectionDto(
            source: AgentModelSource.fixed,
            modelId: 'local-test/test-model',
          ),
        ),
        expectedContentHash: withoutAgentModel.contentHash,
      );
      final renamed = await client.updateProviderModelPrefix(
        custom.id,
        'local-renamed',
      );
      expect(renamed.modelPrefix, 'local-renamed');
      expect(
        (await client.models.getSettings()).defaultModel,
        const ModelSelectionDto(modelId: 'local-renamed/test-model'),
      );
      expect(
        (await client.listAgentDefinitions()).single.model,
        const AgentModelSelectionDto(
          source: AgentModelSource.fixed,
          modelId: 'local-renamed/test-model',
        ),
      );
      final renamedSessions = <String, String?>{
        for (final session in await client.sessions.listSessions(
          worktreeId: checkout.id,
        ))
          session.id: session.model?.modelId,
      };
      expect(renamedSessions['model-inherited'], isNull);
      expect(renamedSessions['agent-1'], 'local-renamed/test-model');
      expect(renamedSessions['agent-priority'], isNull);
      expect(renamedSessions['chat-priority'], 'openai/gpt-4');
    },
    tags: const <String>[
      'feature_test__workspace_catalog__verticalSlice',
      'feature_test__workspace_registration__verticalSlice',
      'feature_test__session_lifecycle__verticalSlice',
      'feature_test__terminal_lifecycle__verticalSlice',
      'feature_test__terminal_settings__verticalSlice',
      'feature_test__turn_execution__verticalSlice',
      'feature_test__provider_catalog__verticalSlice',
      'feature_test__provider_usage__verticalSlice',
      'feature_test__provider_connection_management__verticalSlice',
      'feature_test__provider_custom__verticalSlice',
      'feature_test__model_settings__verticalSlice',
      'feature_test__permission_settings__verticalSlice',
    ],
  );

  test(
    'spawn_agent runs a subagent asynchronously and mails back a final answer',
    () async {
      final home = await Directory.systemTemp.createTemp('tinest-spawn-home-');
      final workspace = await Directory.systemTemp.createTemp(
        'tinest-spawn-workspace-',
      );
      final provider = _CollaboratingProvider();
      final handle = await DaemonApplication.start(
        DaemonConfig(
          homeDirectory: home.path,
          port: 0,
          bearerToken: 'spawn-token-0123456789abcdef01234567',
          useEnvironmentCredentials: false,
        ),
        provider: provider,
      );
      addTearDown(() async {
        await handle.stop();
        await home.delete(recursive: true);
        await workspace.delete(recursive: true);
      });
      final client = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
        credentials: const DaemonCredentials(
          bearerToken: 'spawn-token-0123456789abcdef01234567',
        ),
        clientId: 'spawn-test',
        clientKind: 'test',
      );
      addTearDown(client.close);
      final tinest = (await client.listAgentDefinitions()).single;
      final reviewer = await client.createAgentDefinition(
        'reviewer',
        tinest.copyWith(
          id: 'reviewer',
          name: 'Reviewer',
          mode: AgentMode.subagent,
          toolIds: const <String>['tinest.edit/apply_patch'],
          callableAgentIds: const <String>[],
          contentHash: '',
          sourcePath: '',
          isBuiltIn: false,
        ),
      );
      await client.updateAgentDefinition(
        tinest.copyWith(callableAgentIds: <String>[reviewer.id]),
        expectedContentHash: tinest.contentHash,
      );
      final registered = await client.registerWorkspace(
        workspaceId: 'workspace',
        checkoutId: 'checkout',
        rootPath: workspace.path,
        name: 'Workspace',
      );
      final parent = await client.createSession(
        id: 'parent',
        worktreeId: registered.worktrees.single.id,
        title: 'Parent',
        agentDefinitionId: 'tinest',
        model: const ModelSelectionDto(
          // Collaboration is the subject of this slice. Lua orchestration has
          // its own vertical slice and must not add a native cold start here.
          modelId: _testModelId,
        ),
      );
      await client.sessions.updateSettings(
        parent.id,
        const SessionSettingsPatchDto(permissionMode: PermissionMode.readOnly),
      );
      final timelineEvents = client.sessions.timelineEvents;
      final parentTurns = timelineEvents.where(
        (event) =>
            event.sessionId == parent.id && event.type == 'turn.completed',
      );
      final parentCompleted = parentTurns.first.timeout(_eventTimeout);
      // The parent's own turn, then the one the finishing child wakes.
      final parentWokenAgain = parentTurns
          .take(2)
          .toList()
          .timeout(_eventTimeout);
      // The child session ID is unknown before the spawn, so completion is
      // detected through the parent's FINAL_ANSWER mail event.
      final finalAnswerMailed = timelineEvents
          .firstWhere(
            (event) =>
                event.sessionId == parent.id &&
                event.type == 'agent.mail' &&
                ((event.data['mail'] as Map<String, dynamic>?)?['type']
                        as String?) ==
                    'finalAnswer',
          )
          .timeout(_eventTimeout);
      await client.subscribeTimeline(parent.id);
      await client.startTurn(
        sessionId: parent.id,
        turnId: 'parent-turn',
        prompt: 'Review this workspace.',
      );
      // The parent turn completes without blocking on the child.
      await parentCompleted;
      await finalAnswerMailed;

      final tree = await client.listSubagents(parent.id);
      expect(tree.first.id, parent.id);
      final child = tree.singleWhere(
        (session) => session.origin == SessionOrigin.delegated,
      );
      expect(child.parentSessionId, parent.id);
      expect(child.rootSessionId, parent.id);
      // A spawned agent is pinned to the mode its caller runs under, so the
      // row itself carries the parent's narrower choice rather than the
      // daemon default the effective mode would have had to narrow back down.
      expect(child.permissionMode, PermissionMode.readOnly);
      expect(child.taskName, 'review_task');
      expect(child.agentPath, '/root/review_task');
      expect(child.lifecycle, AgentLifecycle.completed);
      expect(child.agentDefinitionId, reviewer.id);
      // A source=session child inherits the caller's effective session model;
      // selecting another Agent changes its harness, not its model policy.
      expect(child.model, parent.model);

      // The read-only clamp still denies the child's write attempt.
      final childTimeline = await client.subscribeTimeline(child.id);
      expect(childTimeline.map((event) => event.type), contains('agent.mail'));
      expect(childTimeline.map((event) => event.type), contains('tool.denied'));
      expect(
        childTimeline
            .where((event) => event.type == 'tool.requested')
            .single
            .data['name'],
        'apply_patch',
      );
      final parentTimeline = await client.subscribeTimeline(parent.id);
      expect(
        parentTimeline
            .where((event) => event.type == 'agent.spawned')
            .single
            .data['agentPath'],
        '/root/review_task',
      );

      // The last child to finish wakes the idle parent by itself, and that
      // turn folds the FINAL_ANSWER envelope into the model request at its
      // first message boundary. Without the wake the mail would sit
      // undelivered until the user typed again.
      expect(await parentWokenAgain, hasLength(2));
      expect(
        provider.requests.any(
          (request) => request.history.whereType<UserConversationItem>().any(
            (item) =>
                item.text.startsWith('Message Type: FINAL_ANSWER') &&
                item.text.contains('Review completed.'),
          ),
        ),
        isTrue,
      );

      // `turn.completed` is emitted before the runner reports the idle
      // status, so the tree has to be observed at rest before teardown
      // closes the database under a turn that is still writing.
      final worktreeId = registered.worktrees.single.id;
      await _waitForIdleSession(client, worktreeId, parent.id);
      await _waitForIdleSession(client, worktreeId, child.id);
    },
    tags: const <String>['feature_test__agent_collaboration__verticalSlice'],
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'a parent waiting inside its turn reads the answer it waited for',
    () async {
      final home = await Directory.systemTemp.createTemp('tinest-wait-home-');
      final workspace = await Directory.systemTemp.createTemp(
        'tinest-wait-workspace-',
      );
      final provider = _WaitingCollaboratingProvider();
      final handle = await DaemonApplication.start(
        DaemonConfig(
          homeDirectory: home.path,
          port: 0,
          bearerToken: 'waitcol-token-0123456789abcdef01234',
          useEnvironmentCredentials: false,
        ),
        provider: provider,
      );
      addTearDown(() async {
        await handle.stop();
        await home.delete(recursive: true);
        await workspace.delete(recursive: true);
      });
      final client = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
        credentials: const DaemonCredentials(
          bearerToken: 'waitcol-token-0123456789abcdef01234',
        ),
        clientId: 'wait-collab-test',
        clientKind: 'test',
      );
      addTearDown(client.close);
      final tinest = (await client.listAgentDefinitions()).single;
      final reviewer = await client.createAgentDefinition(
        'reviewer',
        tinest.copyWith(
          id: 'reviewer',
          name: 'Reviewer',
          mode: AgentMode.subagent,
          toolIds: const <String>[],
          callableAgentIds: const <String>[],
          contentHash: '',
          sourcePath: '',
          isBuiltIn: false,
        ),
      );
      await client.updateAgentDefinition(
        tinest.copyWith(callableAgentIds: <String>[reviewer.id]),
        expectedContentHash: tinest.contentHash,
      );
      final registered = await client.registerWorkspace(
        workspaceId: 'workspace',
        checkoutId: 'checkout',
        rootPath: workspace.path,
        name: 'Workspace',
      );
      final parent = await client.createSession(
        id: 'parent',
        worktreeId: registered.worktrees.single.id,
        title: 'Parent',
        agentDefinitionId: 'tinest',
        model: const ModelSelectionDto(modelId: _testModelId),
      );
      final parentCompleted = client.sessions.timelineEvents
          .firstWhere(
            (event) =>
                event.sessionId == parent.id && event.type == 'turn.completed',
          )
          .timeout(_eventTimeout);
      await client.subscribeTimeline(parent.id);
      await client.startTurn(
        sessionId: parent.id,
        turnId: 'parent-turn',
        prompt: 'Review this workspace.',
      );
      await parentCompleted;

      // The parent spawned and then blocked in `wait_agent`, so the child
      // answered while the parent was still inside this one turn. The wait is
      // the only reader the parent has left: the mailbox was already drained
      // when the turn started. Reporting that mail merely exists would leave
      // the parent holding a notification it cannot open.
      expect(provider.waitOutputs, hasLength(1));
      expect(provider.waitOutputs.single, contains('final_answer'));
      expect(provider.waitOutputs.single, contains('/root/review_task'));
      expect(provider.waitOutputs.single, contains('Review completed.'));

      final child = (await client.listSubagents(parent.id))
          .singleWhere((session) => session.origin == SessionOrigin.delegated);
      expect(child.lifecycle, AgentLifecycle.completed);

      final worktreeId = registered.worktrees.single.id;
      await _waitForIdleSession(client, worktreeId, parent.id);
      await _waitForIdleSession(client, worktreeId, child.id);
    },
    tags: const <String>['feature_test__agent_collaboration__verticalSlice'],
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'a subagent blocked on an approval finishes once the user answers',
    () async {
      final home = await Directory.systemTemp.createTemp(
        'tinest-child-approval-home-',
      );
      final workspace = await Directory.systemTemp.createTemp(
        'tinest-child-approval-workspace-',
      );
      final handle = await DaemonApplication.start(
        DaemonConfig(
          homeDirectory: home.path,
          port: 0,
          bearerToken: 'childapv-token-0123456789abcdef012345',
          useEnvironmentCredentials: false,
        ),
        provider: _CollaboratingProvider(),
      );
      addTearDown(() async {
        await handle.stop();
        await home.delete(recursive: true);
        await workspace.delete(recursive: true);
      });
      final client = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
        credentials: const DaemonCredentials(
          bearerToken: 'childapv-token-0123456789abcdef012345',
        ),
        clientId: 'child-approval-test',
        clientKind: 'test',
      );
      addTearDown(client.close);
      final tinest = (await client.listAgentDefinitions()).single;
      // The parent is left on the daemon default, `ask`. The child inherits
      // that mode from it, and `ask` is what parks the child's turn on an
      // approval only a human can answer.
      final reviewer = await client.createAgentDefinition(
        'reviewer',
        tinest.copyWith(
          id: 'reviewer',
          name: 'Reviewer',
          mode: AgentMode.subagent,
          toolIds: const <String>['tinest.edit/apply_patch'],
          callableAgentIds: const <String>[],
          contentHash: '',
          sourcePath: '',
          isBuiltIn: false,
        ),
      );
      await client.updateAgentDefinition(
        tinest.copyWith(callableAgentIds: <String>[reviewer.id]),
        expectedContentHash: tinest.contentHash,
      );
      final registered = await client.registerWorkspace(
        workspaceId: 'workspace',
        checkoutId: 'checkout',
        rootPath: workspace.path,
        name: 'Workspace',
      );
      final parent = await client.createSession(
        id: 'parent',
        worktreeId: registered.worktrees.single.id,
        title: 'Parent',
        agentDefinitionId: 'tinest',
        model: const ModelSelectionDto(modelId: _testModelId),
      );
      final finalAnswerMailed = client.sessions.timelineEvents
          .firstWhere(
            (event) =>
                event.sessionId == parent.id &&
                event.type == 'agent.mail' &&
                ((event.data['mail'] as Map<String, dynamic>?)?['type']
                        as String?) ==
                    'finalAnswer',
          )
          .timeout(_eventTimeout);
      await client.subscribeTimeline(parent.id);
      await client.startTurn(
        sessionId: parent.id,
        turnId: 'parent-turn',
        prompt: 'Review this workspace.',
      );

      // The parent's own turn ends immediately; the child then parks on an
      // approval that only a human can answer.
      final blocked = await _waitForSubagentStatus(
        client,
        parent.id,
        SessionStatus.waitingForApproval,
      );
      expect(blocked.lifecycle, AgentLifecycle.running);

      // Opening the subagent's tab replays its timeline, which is where the
      // pending approval surfaces. Approvals only reach clients subscribed to
      // that session, so this subscribe is what the tab does on open. The
      // request is written to the child's timeline independently of the status
      // the parent reports, so a tab that opens the moment the parent blocks
      // can replay a timeline that does not carry it yet.
      final requested = await _waitForTimelineEvent(
        client,
        blocked.id,
        'approval.requested',
      );
      final approval = ApprovalRequestDto.fromJson(
        Map<String, dynamic>.from(
          requested.data['approval'] as Map<dynamic, dynamic>,
        ),
      );
      expect(approval.toolName, 'apply_patch');
      expect(approval.sessionId, blocked.id);
      expect(approval.status, ApprovalStatus.pending);

      // Answering it is the only thing that can end the child's turn: the
      // daemon waits on an unbounded completer until someone does.
      await client.resolveApproval(approvalId: approval.id, approved: true);
      await finalAnswerMailed;
      final child = (await client.listSubagents(parent.id))
          .singleWhere((session) => session.origin == SessionOrigin.delegated);
      expect(child.lifecycle, AgentLifecycle.completed);
      expect(
        File(p.join(workspace.path, 'forbidden.txt')).existsSync(),
        isTrue,
      );

      final worktreeId = registered.worktrees.single.id;
      await _waitForIdleSession(client, worktreeId, parent.id);
      await _waitForIdleSession(client, worktreeId, child.id);
    },
    tags: const <String>['feature_test__agent_collaboration__verticalSlice'],
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'a subagent inherits the permission mode granted to its parent',
    () async {
      final home = await Directory.systemTemp.createTemp(
        'tinest-child-inherit-home-',
      );
      final workspace = await Directory.systemTemp.createTemp(
        'tinest-child-inherit-workspace-',
      );
      final handle = await DaemonApplication.start(
        DaemonConfig(
          homeDirectory: home.path,
          port: 0,
          bearerToken: 'childinh-token-0123456789abcdef012345',
          useEnvironmentCredentials: false,
        ),
        provider: _CollaboratingProvider(),
      );
      addTearDown(() async {
        await handle.stop();
        await home.delete(recursive: true);
        await workspace.delete(recursive: true);
      });
      final client = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
        credentials: const DaemonCredentials(
          bearerToken: 'childinh-token-0123456789abcdef012345',
        ),
        clientId: 'child-inherit-test',
        clientKind: 'test',
      );
      addTearDown(client.close);
      final tinest = (await client.listAgentDefinitions()).single;
      final reviewer = await client.createAgentDefinition(
        'reviewer',
        tinest.copyWith(
          id: 'reviewer',
          name: 'Reviewer',
          mode: AgentMode.subagent,
          toolIds: const <String>['tinest.edit/apply_patch'],
          callableAgentIds: const <String>[],
          contentHash: '',
          sourcePath: '',
          isBuiltIn: false,
        ),
      );
      await client.updateAgentDefinition(
        tinest.copyWith(callableAgentIds: <String>[reviewer.id]),
        expectedContentHash: tinest.contentHash,
      );
      final registered = await client.registerWorkspace(
        workspaceId: 'workspace',
        checkoutId: 'checkout',
        rootPath: workspace.path,
        name: 'Workspace',
      );
      final parent = await client.createSession(
        id: 'parent',
        worktreeId: registered.worktrees.single.id,
        title: 'Parent',
        agentDefinitionId: 'tinest',
        model: const ModelSelectionDto(modelId: _testModelId),
      );
      // A subagent pane carries no permission control, so the mode granted
      // here is the only permission decision the user makes for the whole tree.
      await client.sessions.updateSettings(
        parent.id,
        const SessionSettingsPatchDto(
          permissionMode: PermissionMode.fullAccess,
        ),
      );
      final finalAnswerMailed = client.sessions.timelineEvents
          .firstWhere(
            (event) =>
                event.sessionId == parent.id &&
                event.type == 'agent.mail' &&
                ((event.data['mail'] as Map<String, dynamic>?)?['type']
                        as String?) ==
                    'finalAnswer',
          )
          .timeout(_eventTimeout);
      await client.subscribeTimeline(parent.id);
      await client.startTurn(
        sessionId: parent.id,
        turnId: 'parent-turn',
        prompt: 'Review this workspace.',
      );

      // Nobody answers an approval here: the child writes under the parent's
      // full access and reports back on its own.
      await finalAnswerMailed;
      final child = (await client.listSubagents(parent.id))
          .singleWhere((session) => session.origin == SessionOrigin.delegated);
      expect(child.permissionMode, PermissionMode.fullAccess);
      expect(child.lifecycle, AgentLifecycle.completed);
      expect(
        File(p.join(workspace.path, 'forbidden.txt')).existsSync(),
        isTrue,
      );
      final childTimeline = await client.subscribeTimeline(child.id);
      expect(
        childTimeline.map((event) => event.type),
        isNot(contains('approval.requested')),
      );

      final worktreeId = registered.worktrees.single.id;
      await _waitForIdleSession(client, worktreeId, parent.id);
      await _waitForIdleSession(client, worktreeId, child.id);
    },
    tags: const <String>[
      'feature_test__agent_collaboration__verticalSlice',
      'feature_test__permission_settings__verticalSlice',
    ],
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'spawn_agent rejects an agent_type outside the caller allowlist',
    () async {
      final home = await Directory.systemTemp.createTemp('tinest-reject-home-');
      final workspace = await Directory.systemTemp.createTemp(
        'tinest-reject-workspace-',
      );
      final handle = await DaemonApplication.start(
        DaemonConfig(
          homeDirectory: home.path,
          port: 0,
          bearerToken: 'reject-token-0123456789abcdef0123456',
          useEnvironmentCredentials: false,
        ),
        provider: _CollaboratingProvider(agentType: 'stranger'),
      );
      addTearDown(() async {
        await handle.stop();
        await home.delete(recursive: true);
        await workspace.delete(recursive: true);
      });
      final client = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
        credentials: const DaemonCredentials(
          bearerToken: 'reject-token-0123456789abcdef0123456',
        ),
        clientId: 'reject-test',
        clientKind: 'test',
      );
      addTearDown(client.close);
      final tinest = (await client.listAgentDefinitions()).single;
      await client.updateAgentDefinition(
        tinest,
        expectedContentHash: tinest.contentHash,
      );
      final registered = await client.registerWorkspace(
        workspaceId: 'workspace',
        checkoutId: 'checkout',
        rootPath: workspace.path,
        name: 'Workspace',
      );
      final parent = await client.createSession(
        id: 'parent',
        worktreeId: registered.worktrees.single.id,
        title: 'Parent',
        agentDefinitionId: 'tinest',
        model: const ModelSelectionDto(modelId: _testModelId),
      );
      final completed = client.sessions.timelineEvents
          .firstWhere(
            (event) =>
                event.sessionId == parent.id &&
                (event.type == 'turn.completed' || event.type == 'turn.failed'),
          )
          .timeout(_eventTimeout);
      await client.subscribeTimeline(parent.id);
      await client.startTurn(
        sessionId: parent.id,
        turnId: 'parent-turn',
        prompt: 'Review this workspace.',
      );
      final outcome = await completed;
      expect(
        outcome.type,
        'turn.completed',
        reason: 'Parent turn failed: ${outcome.data}',
      );

      expect(await client.listSubagents(parent.id), hasLength(1));
      final timeline = await client.subscribeTimeline(parent.id);
      final spawnResult = timeline
          .where((event) => event.type == 'tool.completed')
          .single;
      expect(spawnResult.data['isError'], isTrue);
      expect(spawnResult.data['output'], contains('not allowed'));

      await _waitForIdleSession(
        client,
        registered.worktrees.single.id,
        parent.id,
      );
    },
    tags: const <String>['feature_test__agent_collaboration__verticalSlice'],
  );

  test(
    'MCP servers publish tools a real turn can call',
    () async {
      final home = await Directory.systemTemp.createTemp('tinest-mcp-home-');
      final workspace = await Directory.systemTemp.createTemp(
        'tinest-mcp-workspace-',
      );
      const bearerToken = 'mcp-token-0123456789abcdef0123456789';
      final handle = await DaemonApplication.start(
        DaemonConfig(
          homeDirectory: home.path,
          port: 0,
          bearerToken: bearerToken,
          useEnvironmentCredentials: false,
        ),
        provider: _EchoingMcpProvider(),
      );
      addTearDown(() async {
        await handle.stop();
        await home.delete(recursive: true);
        await workspace.delete(recursive: true);
      });
      final client = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
        credentials: const DaemonCredentials(bearerToken: bearerToken),
        clientId: 'mcp-test',
        clientKind: 'test',
      );
      addTearDown(client.close);

      expect(client.serverInfo.features['mcp'], isTrue);
      expect(await client.mcp.listMcpServers(), isEmpty);

      final changed = client.mcp.serverChanges.first.timeout(_eventTimeout);
      await client.setMcpSecret('fake.prefix', 'secret-');
      final added = await client.addMcpServer(
        McpServerConfigDto(
          id: 'fake',
          transport: McpTransportKind.stdio,
          command: Platform.resolvedExecutable,
          // Run the script directly rather than through `dart run`: it
          // imports nothing but dart:*, and the pub layer would otherwise
          // contend with the suite for this package's .dart_tool.
          args: <String>[_fakeMcpServerPath()],
          env: const <String, String>{
            'MCP_ECHO_PREFIX': r'${secret:fake.prefix}',
          },
        ),
      );
      await changed;
      expect(added.config.id, 'fake');

      // The server connects in the background, so wait for it to come up.
      final ready = await _awaitReadyMcpServer(client, 'fake');
      expect(ready.serverName, 'fake');
      expect(ready.protocolVersion, '2025-06-18');
      expect(ready.tools.single.toolId, 'mcp__fake__echo');

      final catalog = await client.listAgentTools();
      expect(
        catalog.map((tool) => tool.id),
        allOf(
          contains('tinest.mcp/tool_search'),
          isNot(contains('tinest.mcp/tool_bridge')),
          isNot(contains('tinest.mcp/mcp__fake__echo')),
        ),
      );
      final forked = await client.forkPlugin(
        sourceId: 'tinest.mcp',
        id: 'acme.mcp',
        name: 'Acme MCP',
      );
      expect(forked.id, 'acme.mcp');
      for (final capability in const <String>[
        'mcp.read',
        'mcp.invoke',
        'tools.list',
      ]) {
        await client.grantPluginCapability(
          AgentPluginGrantDto(
            agentId: 'tinest',
            pluginId: 'acme.mcp',
            capability: capability,
          ),
        );
      }
      await client.reloadPlugin('acme.mcp', 'tinest');
      final catalogAfterFork = await client.listAgentTools();
      expect(
        catalogAfterFork.map((tool) => tool.id),
        allOf(
          contains('acme.mcp/tool_search'),
          isNot(contains('acme.mcp/tool_bridge')),
        ),
      );
      // File tools remain independent catalog contributions. The Agent must
      // select each one explicitly; no model-visible tool is implicitly on.
      expect(
        catalog.map((tool) => tool.id),
        containsAll(<String>[
          'tinest.files/list_directory',
          'tinest.files/read_file',
          'tinest.files/search_text',
        ]),
      );

      final tinest = (await client.listAgentDefinitions()).single;
      await client.updateAgentDefinition(
        tinest.copyWith(
          toolIds: <String>[
            ...tinest.toolIds.where(
              (toolId) => toolId != 'tinest.mcp/tool_search',
            ),
            'tinest.files/list_directory',
            'tinest.files/read_file',
            'tinest.files/search_text',
            'acme.mcp/tool_search',
          ],
        ),
        expectedContentHash: tinest.contentHash,
      );

      final registered = await client.registerWorkspace(
        workspaceId: 'workspace',
        checkoutId: 'checkout',
        rootPath: workspace.path,
        name: 'Workspace',
      );
      final session = await client.createSession(
        id: 'mcp-session',
        worktreeId: registered.worktrees.single.id,
        title: 'MCP',
        agentDefinitionId: 'tinest',
        model: const ModelSelectionDto(modelId: _testModelId),
      );
      await client.sessions.updateSettings(
        session.id,
        const SessionSettingsPatchDto(
          permissionMode: PermissionMode.workspaceWrite,
        ),
      );
      // A dangerous tool always asks, even under workspaceWrite.
      final approvalFuture = client.sessions.approvalRequests.first.timeout(
        _eventTimeout,
      );
      final terminal = client.sessions.timelineEvents
          .firstWhere(
            (event) =>
                event.sessionId == session.id &&
                (event.type == 'turn.completed' || event.type == 'turn.failed'),
          )
          .timeout(_eventTimeout);
      await client.subscribeTimeline(session.id);
      await client.startTurn(
        sessionId: session.id,
        turnId: 'mcp-turn',
        prompt: 'Echo something through MCP.',
      );
      late ApprovalRequestDto approval;
      try {
        approval = await approvalFuture;
      } on TimeoutException catch (error) {
        final diagnosticTimeline = await client.subscribeTimeline(session.id);
        final diagnostics = diagnosticTimeline
            .map((event) => '${event.type}: ${event.data}')
            .join('\n');
        throw TestFailure(
          '$error while waiting for dynamic MCP approval.\n$diagnostics',
        );
      }
      expect(approval.toolName, 'mcp__fake__echo');
      expect(approval.risk, ToolRisk.dangerous);
      expect(approval.preview, 'fake.echo');
      await client.resolveApproval(approvalId: approval.id, approved: true);
      final terminalEvent = await terminal;
      expect(
        terminalEvent.type,
        'turn.completed',
        reason: '${terminalEvent.data}',
      );
      // turn.completed precedes the daemon's own final writes, so let the
      // session settle before the teardown closes its database.
      await _waitForIdleSession(
        client,
        registered.worktrees.single.id,
        session.id,
      );

      final timeline = await client.subscribeTimeline(session.id);
      final requestedNames = timeline
          .where((event) => event.type == 'tool.requested')
          .map((event) => event.data['name'])
          .toList(growable: false);
      expect(
        requestedNames,
        containsAll(<String>['tool_search_mcp', 'mcp__fake__echo']),
      );
      // Dangerous tools need approval, and workspaceWrite does not grant it.
      expect(
        timeline.map((event) => event.type),
        contains('approval.resolved'),
      );
      final completedTools = timeline
          .where((event) => event.type == 'tool.completed')
          .toList();
      expect(
        completedTools,
        hasLength(2),
        reason: timeline
            .map((event) => '${event.type}: ${event.data}')
            .join('\n'),
      );
      final searchTool = completedTools.singleWhere(
        (event) => event.data['name'] == 'tool_search_mcp',
      );
      expect(searchTool.data['output'], contains('mcp__fake__echo'));
      final completedTool = completedTools.singleWhere(
        (event) => event.data['name'] == 'mcp__fake__echo',
      );
      // The configured secret reached the child process.
      expect(completedTool.data['output'], contains('secret-through MCP'));

      await client.removeMcpServer('fake');
      expect(
        (await client.listAgentTools()).map((tool) => tool.id),
        allOf(
          contains('acme.mcp/tool_search'),
          isNot(contains('acme.mcp/tool_bridge')),
          isNot(contains('acme.mcp/mcp__fake__echo')),
        ),
      );
      expect(await client.mcp.listMcpServers(), isEmpty);
    },
    tags: const <String>[
      'feature_test__mcp_server_management__verticalSlice',
      'feature_test__mcp_tool_execution__verticalSlice',
    ],
  );

  test(
    'a project .tinest/config.json publishes tools only in its worktree',
    () async {
      final home = await Directory.systemTemp.createTemp(
        'tinest-mcp-project-home-',
      );
      final workspace = await Directory.systemTemp.createTemp(
        'tinest-mcp-project-',
      );
      const bearerToken = 'mcp-project-token-0123456789abcdef0123';
      final projectConfig = File(
        p.join(workspace.path, '.tinest', 'config.json'),
      );
      await projectConfig.parent.create(recursive: true);
      await projectConfig.writeAsString(
        jsonEncode(<String, dynamic>{
          'schemaVersion': 5,
          'mcp': <String, dynamic>{
            'servers': <String, dynamic>{
              'repo': <String, dynamic>{
                'transport': 'stdio',
                'command': Platform.resolvedExecutable,
                'args': <String>[_fakeMcpServerPath()],
              },
            },
          },
        }),
      );
      final handle = await DaemonApplication.start(
        DaemonConfig(
          homeDirectory: home.path,
          port: 0,
          bearerToken: bearerToken,
          useEnvironmentCredentials: false,
        ),
      );
      addTearDown(() async {
        await handle.stop();
        await home.delete(recursive: true);
        await workspace.delete(recursive: true);
      });
      final client = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
        credentials: const DaemonCredentials(bearerToken: bearerToken),
        clientId: 'mcp-project-test',
        clientKind: 'test',
      );
      addTearDown(client.close);

      final registered = await client.registerWorkspace(
        workspaceId: 'workspace',
        checkoutId: 'checkout',
        rootPath: workspace.path,
        name: 'Workspace',
      );
      final worktreeId = registered.worktrees.single.id;

      // Listing with the worktree in hand is what puts it into use.
      await client.mcp.listMcpServers(worktreeId: worktreeId);
      final ready = await _awaitReadyMcpServer(
        client,
        'repo',
        worktreeId: worktreeId,
      );
      expect(ready.scope, McpConfigScope.project);
      // The daemon canonicalizes checkout paths, and macOS resolves the
      // temporary directory through /private, so compare against what the
      // registration actually recorded.
      expect(
        ready.sourcePath,
        p.join(registered.worktrees.single.path, '.tinest', 'config.json'),
      );
      expect(ready.shadowed, isFalse);

      final worktreeCatalog = await client.listAgentTools(
        worktreeId: worktreeId,
      );
      final daemonCatalog = await client.listAgentTools();
      // Agent catalogs expose the selectable Lua search contribution, never
      // one Dart-synthesized contribution per remote MCP tool. Project scope
      // remains enforced by the raw catalog primitive used during that turn.
      for (final catalog in <List<AgentToolDefinitionDto>>[
        worktreeCatalog,
        daemonCatalog,
      ]) {
        expect(
          catalog.map((tool) => tool.id),
          allOf(
            contains('tinest.mcp/tool_search'),
            isNot(contains('tinest.mcp/tool_bridge')),
            isNot(contains('tinest.mcp/mcp__repo__echo')),
          ),
        );
      }
      expect(await client.mcp.listMcpServers(), isEmpty);
    },
    tags: const <String>[
      'feature_test__mcp_server_management__verticalSlice',
      'feature_test__mcp_tool_execution__verticalSlice',
    ],
  );

  // Both transports are production paths — pipes for ordinary commands, a
  // pseudo-terminal for the interactive ones — so both are proved against a
  // real daemon and a real process rather than only the default.
  for (final tty in <bool>[false, true]) {
    final transport = tty ? 'pseudo-terminal' : 'pipes';
    test(
      'exec_command drives a real $transport across two tool calls',
      () async {
        final home = await Directory.systemTemp.createTemp('tinest-exec-home-');
        final workspace = await Directory.systemTemp.createTemp(
          'tinest-exec-workspace-',
        );
        const bearerToken = 'exec-command-token-0123456789abcdef012';
        final provider = _ExecProvider(tty: tty);
        final handle = await DaemonApplication.start(
          DaemonConfig(
            homeDirectory: home.path,
            port: 0,
            bearerToken: bearerToken,
            useEnvironmentCredentials: false,
          ),
          provider: provider,
        );
        addTearDown(() async {
          await handle.stop();
          await home.delete(recursive: true);
          await workspace.delete(recursive: true);
        });
        final client = await TinestClient.connect(
          endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
          credentials: const DaemonCredentials(bearerToken: bearerToken),
          clientId: 'exec-command-test',
          clientKind: 'test',
        );
        addTearDown(client.close);

        final registered = await client.registerWorkspace(
          workspaceId: 'workspace',
          checkoutId: 'checkout',
          rootPath: workspace.path,
          name: 'Workspace',
        );
        final session = await client.createSession(
          id: 'exec-session',
          worktreeId: registered.worktrees.single.id,
          title: 'Exec',
          agentDefinitionId: 'tinest',
          model: const ModelSelectionDto(modelId: _testModelId),
        );
        await client.sessions.updateSettings(
          session.id,
          const SessionSettingsPatchDto(
            permissionMode: PermissionMode.workspaceWrite,
          ),
        );
        await client.subscribeTimeline(session.id);
        // Each model tool call asks once at its effective primitive risk. A
        // tool may compose start/read or write/read primitives internally,
        // but those implementation details must not duplicate the dialog.
        final approvals = <String>[];
        final approvalFailure = Completer<Never>();
        // startTurn can deliver and resolve an approval before the provider
        // wait below attaches its fail-fast listener.
        approvalFailure.future.ignore();
        final approvalSubscription = client.sessions.approvalRequests.listen((
          approval,
        ) {
          approvals.add(approval.toolName);
          unawaited(
            client
                .resolveApproval(approvalId: approval.id, approved: true)
                .onError((error, stackTrace) {
                  if (!approvalFailure.isCompleted) {
                    approvalFailure.completeError(
                      error ?? StateError('Approval resolution failed.'),
                      stackTrace,
                    );
                  }
                }),
          );
        });
        addTearDown(approvalSubscription.cancel);
        await client.startTurn(
          sessionId: session.id,
          turnId: 'exec-turn',
          prompt: 'Run the shell',
        );

        // A command that outlives the first call hands back an id the second
        // call writes into, and the echoed text proves the same process
        // answered.
        final seen = await _waitForProviderResultOrTurnFailure(
          client: client,
          worktreeId: registered.worktrees.single.id,
          sessionId: session.id,
          result: provider.echoed.future,
          externalFailure: approvalFailure.future,
          progress: () =>
              'providerRound=${provider.round}, approvals=$approvals',
        );
        expect(seen, contains('tinyrack-exec-probe'));
        expect(approvals, <String>['exec_command', 'write_stdin']);
        await _waitForIdleSession(
          client,
          registered.worktrees.single.id,
          session.id,
        );
      },
      tags: const <String>['feature_test__tool_exec_session__verticalSlice'],
      // Both transports run a POSIX shell; Windows uses PowerShell instead.
      testOn: '!windows',
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }

  test(
    'view_image puts a hydrated workspace image into the model context',
    () async {
      final home = await Directory.systemTemp.createTemp('tinest-image-home-');
      final workspace = await Directory.systemTemp.createTemp(
        'tinest-image-workspace-',
      );
      // A one-pixel PNG, valid down to its magic bytes.
      await File(p.join(workspace.path, 'shot.png')).writeAsBytes(<int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      ]);
      const bearerToken = 'view-image-token-0123456789abcdef01234';
      final provider = _ViewImageProvider();
      final handle = await DaemonApplication.start(
        DaemonConfig(
          homeDirectory: home.path,
          port: 0,
          bearerToken: bearerToken,
          useEnvironmentCredentials: false,
        ),
        provider: provider,
      );
      addTearDown(() async {
        await handle.stop();
        await home.delete(recursive: true);
        await workspace.delete(recursive: true);
      });
      final client = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
        credentials: const DaemonCredentials(bearerToken: bearerToken),
        clientId: 'view-image-test',
        clientKind: 'test',
      );
      addTearDown(client.close);
      await _selectTinestTools(client, const <String>[
        'tinest.files/view_image',
      ]);

      final registered = await client.registerWorkspace(
        workspaceId: 'workspace',
        checkoutId: 'checkout',
        rootPath: workspace.path,
        name: 'Workspace',
      );
      final session = await client.createSession(
        id: 'image-session',
        worktreeId: registered.worktrees.single.id,
        title: 'Image',
        agentDefinitionId: 'tinest',
        model: const ModelSelectionDto(modelId: _testModelId),
      );
      await client.subscribeTimeline(session.id);
      await client.startTurn(
        sessionId: session.id,
        turnId: 'image-turn',
        prompt: 'Look at the screenshot',
      );

      final request = await provider.secondRequest.future.timeout(
        _eventTimeout,
      );
      final imageContext = request.history
          .whereType<UserConversationItem>()
          .last
          .attachments;
      expect(
        imageContext,
        hasLength(1),
        reason:
            'Second model history: '
            '${request.history.map((item) => item.toJson()).toList()}',
      );
      final injected = imageContext.single;
      expect(injected.mimeType, 'image/png');
      expect(injected.imageDetail, 'high');
      // The bytes are hydrated, so the provider can actually encode the image.
      expect(injected.bytes, isNotNull);
      await _waitForIdleSession(
        client,
        registered.worktrees.single.id,
        session.id,
      );
    },
    tags: const <String>['feature_test__tool_image_context__verticalSlice'],
  );

  test('a sleeping agent wakes early when the client queues input', () async {
    final home = await Directory.systemTemp.createTemp('tinest-sleep-home-');
    final workspace = await Directory.systemTemp.createTemp(
      'tinest-sleep-workspace-',
    );
    const bearerToken = 'sleep-tool-token-0123456789abcdef01234';
    final provider = _SleepProvider();
    final handle = await DaemonApplication.start(
      DaemonConfig(
        homeDirectory: home.path,
        port: 0,
        bearerToken: bearerToken,
        useEnvironmentCredentials: false,
      ),
      provider: provider,
    );
    addTearDown(() async {
      await handle.stop();
      await home.delete(recursive: true);
      await workspace.delete(recursive: true);
    });
    final client = await TinestClient.connect(
      endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
      credentials: const DaemonCredentials(bearerToken: bearerToken),
      clientId: 'sleep-tool-test',
      clientKind: 'test',
    );
    addTearDown(client.close);
    await _selectTinestTools(client, const <String>['tinest.time/sleep']);

    final registered = await client.registerWorkspace(
      workspaceId: 'workspace',
      checkoutId: 'checkout',
      rootPath: workspace.path,
      name: 'Workspace',
    );
    final session = await client.createSession(
      id: 'sleep-session',
      worktreeId: registered.worktrees.single.id,
      title: 'Sleep',
      agentDefinitionId: 'tinest',
      model: const ModelSelectionDto(modelId: _testModelId),
    );
    await client.subscribeTimeline(session.id);
    await client.startTurn(
      sessionId: session.id,
      turnId: 'sleep-turn',
      prompt: 'Wait for the build',
    );

    // The agent asked to wait five minutes; the queued prompt must cut it
    // short, so the turn finishing at all proves the signal arrived.
    await provider.sleeping.future.timeout(_eventTimeout);
    await client.notePendingInput(session.id);

    final outcome = await provider.outcome.future.timeout(_eventTimeout);
    expect(outcome, 'interrupted');
    await _waitForIdleSession(
      client,
      registered.worktrees.single.id,
      session.id,
    );
  }, tags: const <String>['feature_test__tool_clock__verticalSlice']);

  test(
    'settings refused during a turn report a code the client can translate',
    () async {
      // The mode and the model are read when a turn starts, so the daemon
      // refuses to move them underneath a running one. That refusal is the
      // intended behavior, not a defect, and it used to escape as a bare
      // StateError: the transport turned it into `internal_error`, which the
      // protocol reserves for defects and the app shows as an unexplained
      // daemon failure with a trace id.
      final home = await Directory.systemTemp.createTemp('tinest-busy-home-');
      final workspace = await Directory.systemTemp.createTemp(
        'tinest-busy-workspace-',
      );
      const bearerToken = 'busy-settings-token-0123456789abcdef012';
      final provider = _SleepProvider();
      final handle = await DaemonApplication.start(
        DaemonConfig(
          homeDirectory: home.path,
          port: 0,
          bearerToken: bearerToken,
          useEnvironmentCredentials: false,
        ),
        provider: provider,
      );
      addTearDown(() async {
        await handle.stop();
        await home.delete(recursive: true);
        await workspace.delete(recursive: true);
      });
      final client = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
        credentials: const DaemonCredentials(bearerToken: bearerToken),
        clientId: 'busy-settings-test',
        clientKind: 'test',
      );
      addTearDown(client.close);
      await _selectTinestTools(client, const <String>['tinest.time/sleep']);

      final registered = await client.registerWorkspace(
        workspaceId: 'workspace',
        checkoutId: 'checkout',
        rootPath: workspace.path,
        name: 'Workspace',
      );
      final session = await client.createSession(
        id: 'busy-session',
        worktreeId: registered.worktrees.single.id,
        title: 'Busy',
        agentDefinitionId: 'tinest',
        model: const ModelSelectionDto(modelId: _testModelId),
      );
      await client.subscribeTimeline(session.id);
      await client.startTurn(
        sessionId: session.id,
        turnId: 'busy-turn',
        prompt: 'Wait for the build',
      );
      await provider.sleeping.future.timeout(_eventTimeout);

      await expectLater(
        client.sessions.updateSettings(
          session.id,
          const SessionSettingsPatchDto(hasModelControls: true),
        ),
        throwsA(
          isA<TinestClientException>()
              .having(
                (error) => error.code,
                'code',
                RpcErrorCodes.sessionTurnActive,
              )
              .having(
                (error) => error.details['sessionId'],
                'sessionId',
                session.id,
              ),
        ),
      );

      // The refusal is transient: the same change lands once the turn ends.
      await client.notePendingInput(session.id);
      await provider.outcome.future.timeout(_eventTimeout);
      await _waitForIdleSession(
        client,
        registered.worktrees.single.id,
        session.id,
      );
      expect(
        (await client.sessions.updateSettings(
          session.id,
          const SessionSettingsPatchDto(hasModelControls: true),
        )).modelControls,
        isEmpty,
      );
    },
    tags: const <String>['feature_test__session_lifecycle__verticalSlice'],
  );

  test(
    'search_text and glob honour a real .gitignore in a real workspace',
    () async {
      final home = await Directory.systemTemp.createTemp('tinest-search-home-');
      final workspace = await Directory.systemTemp.createTemp(
        'tinest-search-workspace-',
      );
      for (final directory in <String>[
        'blocked',
        'classes',
        'deep/x/y',
        'generated',
        'nested',
      ]) {
        await Directory(
          p.joinAll(<String>[workspace.path, ...directory.split('/')]),
        ).create(recursive: true);
      }
      await File(p.join(workspace.path, '.gitignore')).writeAsString(r'''
generated/
*.log
!keep.log
/root-only.dart
deep/**/secret?.dart
classes/[a-c].tmp
escaped\[.txt
*.cache
blocked/
''');
      await File(p.join(workspace.path, 'nested', '.gitignore'))
          .writeAsString('!keep.cache\n');
      await File(p.join(workspace.path, 'blocked', '.gitignore'))
          .writeAsString('!resurrect.dart\n');
      final files = <String, String>{
        'main.dart': 'const marker = 1;\n',
        'keep.log': 'marker\n',
        'notes.log': 'marker\n',
        'root-only.dart': 'const marker = 2;\n',
        'nested/root-only.dart': 'const marker = 3;\n',
        'nested/keep.cache': 'marker\n',
        'nested/drop.cache': 'marker\n',
        'generated/out.dart': 'const marker = 4;\n',
        'deep/secret1.dart': 'const marker = 5;\n',
        'deep/x/y/secret2.dart': 'const marker = 6;\n',
        'classes/b.tmp': 'marker\n',
        'escaped[.txt': 'marker\n',
        'blocked/resurrect.dart': 'const marker = 7;\n',
      };
      for (final entry in files.entries) {
        await File(p.joinAll(<String>[workspace.path, ...entry.key.split('/')]))
            .writeAsString(entry.value);
      }
      const bearerToken = 'search-tool-token-0123456789abcdef0123';
      final provider = _SearchProvider();
      final handle = await DaemonApplication.start(
        DaemonConfig(
          homeDirectory: home.path,
          port: 0,
          bearerToken: bearerToken,
          useEnvironmentCredentials: false,
        ),
        provider: provider,
      );
      addTearDown(() async {
        await handle.stop();
        await home.delete(recursive: true);
        await workspace.delete(recursive: true);
      });
      final client = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
        credentials: const DaemonCredentials(bearerToken: bearerToken),
        clientId: 'search-tool-test',
        clientKind: 'test',
      );
      addTearDown(client.close);
      await _selectTinestTools(client, const <String>[
        'tinest.files/search_text',
        'tinest.files/glob',
      ]);

      final registered = await client.registerWorkspace(
        workspaceId: 'workspace',
        checkoutId: 'checkout',
        rootPath: workspace.path,
        name: 'Workspace',
      );
      final session = await client.createSession(
        id: 'search-session',
        worktreeId: registered.worktrees.single.id,
        title: 'Search',
        agentDefinitionId: 'tinest',
        model: const ModelSelectionDto(modelId: _testModelId),
      );
      await client.subscribeTimeline(session.id);
      final failed = client.sessions.timelineEvents.firstWhere(
        (event) => event.sessionId == session.id && event.type == 'turn.failed',
      );
      await client.startTurn(
        sessionId: session.id,
        turnId: 'search-turn',
        prompt: 'Find the marker',
      );

      final results = await Future.any(<Future<_SearchResults>>[
        provider.results.future,
        failed.then<_SearchResults>(
          (event) => throw TestFailure('Search turn failed: ${event.data}'),
        ),
      ]).timeout(_eventTimeout);
      final matches = results.search['matches']! as List;
      // The ignored copies of the marker are not reachable, so the model sees
      // exactly the file a developer would expect.
      expect(
        matches.map((match) => (match! as Map<String, dynamic>)['path']),
        <String>[
          'keep.log',
          'main.dart',
          'nested/keep.cache',
          'nested/root-only.dart',
        ],
      );
      expect(results.search['truncated'], isFalse);
      expect(results.glob['paths'], <String>[
        'main.dart',
        'nested/root-only.dart',
      ]);
      expect(
        (results.searchIgnored['matches']! as List).map(
          (match) => (match! as Map<String, dynamic>)['path'],
        ),
        containsAll(<String>[
          'blocked/resurrect.dart',
          'generated/out.dart',
          'notes.log',
          'root-only.dart',
        ]),
      );
      expect(
        results.globIgnored['paths'],
        containsAll(<String>[
          'blocked/resurrect.dart',
          'generated/out.dart',
          'root-only.dart',
        ]),
      );
      await _waitForIdleSession(
        client,
        registered.worktrees.single.id,
        session.id,
      );
    },
    tags: const <String>['feature_test__tool_search__verticalSlice'],
  );

  test(
    'an agent question blocks the turn until the user answers it',
    () async {
      final home = await Directory.systemTemp.createTemp('tinest-ask-home-');
      final workspace = await Directory.systemTemp.createTemp(
        'tinest-ask-workspace-',
      );
      const bearerToken = 'ask-user-token-0123456789abcdef0123456';
      final handle = await DaemonApplication.start(
        DaemonConfig(
          homeDirectory: home.path,
          port: 0,
          bearerToken: bearerToken,
          useEnvironmentCredentials: false,
        ),
        provider: _AskingProvider(),
      );
      addTearDown(() async {
        await handle.stop();
        await home.delete(recursive: true);
        await workspace.delete(recursive: true);
      });
      final client = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
        credentials: const DaemonCredentials(bearerToken: bearerToken),
        clientId: 'ask-user-test',
        clientKind: 'test',
      );
      addTearDown(client.close);
      await _selectTinestTools(client, const <String>[
        'tinest.interaction/request_user_input',
      ]);

      final registered = await client.registerWorkspace(
        workspaceId: 'workspace',
        checkoutId: 'checkout',
        rootPath: workspace.path,
        name: 'Workspace',
      );
      final session = await client.createSession(
        id: 'ask-session',
        worktreeId: registered.worktrees.single.id,
        title: 'Ask',
        agentDefinitionId: 'tinest',
        model: const ModelSelectionDto(modelId: _testModelId),
      );
      await client.subscribeTimeline(session.id);

      final questionFuture = client.sessions.questionRequests.first.timeout(
        _eventTimeout,
      );
      final waitingFuture = client.sessions.sessionUpdates
          .firstWhere(
            (updated) =>
                updated.id == session.id &&
                updated.status == SessionStatus.waitingForInput,
          )
          .timeout(_eventTimeout);
      final completedFuture = client.sessions.timelineEvents
          .firstWhere(
            (event) =>
                event.sessionId == session.id &&
                (event.type == 'turn.completed' || event.type == 'turn.failed'),
          )
          .timeout(_eventTimeout);

      await client.startTurn(
        sessionId: session.id,
        turnId: 'ask-turn',
        prompt: 'Decide the store',
      );

      final question = await questionFuture;
      expect(question.toolCallId, 'ask-call');
      expect(question.status, UserQuestionStatus.pending);
      expect(question.questions.single.header, 'Storage');
      expect(question.questions.single.options, hasLength(2));
      await waitingFuture;

      // Every question must be answered before the turn may continue.
      await expectLater(
        client.answerUserQuestion(
          requestId: question.id,
          answers: const <UserQuestionAnswerDto>[],
        ),
        throwsA(isA<TinestClientException>()),
      );

      const answers = <UserQuestionAnswerDto>[
        UserQuestionAnswerDto(
          questionId: 'store',
          answer: 'Postgres',
          isFreeForm: true,
        ),
      ];
      final answered = await client.answerUserQuestion(
        requestId: question.id,
        answers: answers,
      );
      expect(answered.status, UserQuestionStatus.answered);
      expect(answered.answers, answers);

      // The same question cannot be answered twice.
      await expectLater(
        client.answerUserQuestion(requestId: question.id, answers: answers),
        throwsA(isA<TinestClientException>()),
      );

      final askOutcome = await completedFuture;
      expect(
        askOutcome.type,
        'turn.completed',
        reason: 'Ask turn failed: ${askOutcome.data}',
      );
      await _waitForIdleSession(
        client,
        registered.worktrees.single.id,
        session.id,
      );

      final events = await client.subscribeTimeline(session.id);
      expect(
        events.map((event) => event.type),
        containsAll(<String>[
          'userQuestion.requested',
          'userQuestion.answered',
        ]),
      );
      final result = events.firstWhere(
        (event) =>
            event.type == 'tool.completed' &&
            event.data['name'] == 'request_user_input',
      );
      // The chosen answer reaches the model as the tool's output.
      expect(result.data['output'], contains('Postgres'));
    },
    tags: const <String>['feature_test__turn_question__verticalSlice'],
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test(
    'a server that cannot start leaves the daemon and its turns working',
    () async {
      final home = await Directory.systemTemp.createTemp(
        'tinest-mcp-broken-home-',
      );
      final workspace = await Directory.systemTemp.createTemp(
        'tinest-mcp-broken-workspace-',
      );
      const bearerToken = 'mcp-broken-token-0123456789abcdef01234';
      await Directory(p.join(home.path, 'v5')).create();
      await File(p.join(home.path, 'v5', 'config.json')).writeAsString(
        jsonEncode(<String, dynamic>{
          'schemaVersion': 5,
          'mcp': <String, dynamic>{
            'servers': <String, dynamic>{
              'broken': <String, dynamic>{
                'transport': 'stdio',
                'command': '/nonexistent/mcp-server',
              },
            },
          },
        }),
      );
      final handle = await DaemonApplication.start(
        DaemonConfig(
          homeDirectory: home.path,
          port: 0,
          bearerToken: bearerToken,
          useEnvironmentCredentials: false,
        ),
        provider: _PatchProvider(),
      );
      addTearDown(() async {
        await handle.stop();
        await home.delete(recursive: true);
        await workspace.delete(recursive: true);
      });
      final client = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
        credentials: const DaemonCredentials(bearerToken: bearerToken),
        clientId: 'mcp-broken-test',
        clientKind: 'test',
      );
      addTearDown(client.close);

      final registered = await client.registerWorkspace(
        workspaceId: 'workspace',
        checkoutId: 'checkout',
        rootPath: workspace.path,
        name: 'Workspace',
      );
      final session = await client.createSession(
        id: 'broken-session',
        worktreeId: registered.worktrees.single.id,
        title: 'Broken',
        agentDefinitionId: 'tinest',
        model: const ModelSelectionDto(modelId: _testModelId),
      );
      await client.sessions.updateSettings(
        session.id,
        const SessionSettingsPatchDto(
          permissionMode: PermissionMode.workspaceWrite,
        ),
      );
      final completed = client.sessions.timelineEvents
          .firstWhere(
            (event) =>
                event.sessionId == session.id &&
                (event.type == 'turn.completed' || event.type == 'turn.failed'),
          )
          .timeout(_eventTimeout);
      await client.subscribeTimeline(session.id);
      await client.startTurn(
        sessionId: session.id,
        turnId: 'broken-turn',
        prompt: 'Write a file.',
      );
      final brokenOutcome = await completed;
      expect(
        brokenOutcome.type,
        'turn.completed',
        reason: 'Broken-server turn failed: ${brokenOutcome.data}',
      );
      await _waitForIdleSession(
        client,
        registered.worktrees.single.id,
        session.id,
      );

      // The turn succeeded on built-in tools alone.
      expect(File(p.join(workspace.path, 'result.txt')).existsSync(), isTrue);
      final broken = (await client.mcp.listMcpServers()).single;
      expect(broken.status, McpServerStatus.failed);
      expect(broken.error, isNotNull);
      expect(broken.tools, isEmpty);
    },
    tags: const <String>[
      'feature_test__mcp_server_management__verticalSlice',
      'feature_test__mcp_tool_execution__verticalSlice',
    ],
  );

  test(
    'skill catalog partitions scopes, refreshes, and drives a turn',
    () async {
      final home = await Directory.systemTemp.createTemp('tinest-skill-home-');
      final agentsHome = await Directory.systemTemp.createTemp(
        'tinest-skill-agents-home-',
      );
      final workspace = await Directory.systemTemp.createTemp(
        'tinest-skill-workspace-',
      );
      const bearerToken = 'skill-token-0123456789abcdef0123456789';
      addTearDown(() async {
        await home.delete(recursive: true);
        await agentsHome.delete(recursive: true);
        await workspace.delete(recursive: true);
      });

      // A global skill in the shared `~/.agents` tree, shadowed by a project
      // skill with the same ID.
      await _writeSkill(
        p.join(agentsHome.path, '.agents', 'skills', 'shared'),
        description: 'From the user home.',
        body: 'Global instructions.',
      );
      await _writeSkill(
        p.join(workspace.path, '.agents', 'skills', 'shared'),
        description: 'From the project.',
        body: 'Project instructions.',
      );

      // Development databases may still contain values written by the
      // removed enablement API. The read-only catalog never consults them.
      final state = Directory(p.join(home.path, 'v5'))..createSync();
      final legacyDatabase = TinestDatabase(
        p.join(state.path, 'tinest.sqlite'),
      );
      await legacyDatabase.settingsDao.setValue(
        'skills.enablement',
        jsonEncode(<String, bool>{'commit': false, 'shared': false}),
      );
      await legacyDatabase.close();

      final handle = await DaemonApplication.start(
        DaemonConfig(
          homeDirectory: home.path,
          userHomeDirectory: agentsHome.path,
          port: 0,
          bearerToken: bearerToken,
          useEnvironmentCredentials: false,
        ),
        provider: _SkillProvider(),
      );
      addTearDown(handle.stop);
      final client = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
        credentials: const DaemonCredentials(bearerToken: bearerToken),
        clientId: 'skill-test',
        clientKind: 'test',
      );
      addTearDown(client.close);
      await _selectTinestTools(client, const <String>[
        'tinest.skills/list_skills',
        'tinest.skills/skill',
      ]);

      expect(client.serverInfo.features['skills'], isTrue);

      final global = await client.listSkills(view: SkillListView.global);
      expect(
        global.map((skill) => skill.id),
        containsAll(<String>['coding-conventions', 'commit', 'shared']),
      );
      expect(
        global.singleWhere((skill) => skill.id == 'shared').description,
        'From the user home.',
      );

      final registered = await client.registerWorkspace(
        workspaceId: 'workspace',
        checkoutId: 'checkout',
        rootPath: workspace.path,
        name: 'Workspace',
      );
      await expectLater(
        client.listSkills(view: SkillListView.global, workspaceId: 'workspace'),
        throwsA(
          isA<TinestClientException>().having(
            (error) => error.code,
            'code',
            RpcErrorCodes.invalidParams,
          ),
        ),
      );
      await expectLater(
        client.listSkills(view: SkillListView.project),
        throwsA(
          isA<TinestClientException>().having(
            (error) => error.code,
            'code',
            RpcErrorCodes.invalidParams,
          ),
        ),
      );
      final projectSkills = await client.listSkills(
        view: SkillListView.project,
        workspaceId: 'workspace',
      );
      final projectSkill = projectSkills.singleWhere(
        (skill) => skill.id == 'shared',
      );
      expect(projectSkill.description, 'From the project.');
      expect(projectSkills.map((skill) => skill.id), isNot(contains('commit')));

      final effective = await client.listSkills(
        view: SkillListView.effective,
        workspaceId: 'workspace',
      );
      expect(effective.map((skill) => skill.id), contains('commit'));
      expect(
        effective.singleWhere((skill) => skill.id == 'shared').description,
        'From the project.',
      );

      // External files are now the only management boundary. A file created
      // after daemon startup must refresh the RPC catalog through its watcher.
      final changed = client.skillChanges.first;
      await _writeSkill(
        p.join(home.path, 'v5', 'skills', 'release'),
        description: 'Ships a release.',
        body: 'Tag, build, publish.',
      );
      await changed.timeout(_eventTimeout);
      expect(
        (await client.listSkills(view: SkillListView.global))
            .map((skill) => skill.id),
        contains('release'),
      );

      final session = await client.createSession(
        id: 'skill-session',
        worktreeId: registered.worktrees.single.id,
        title: 'Skills',
        agentDefinitionId: 'tinest',
        model: const ModelSelectionDto(modelId: _testModelId),
      );
      final terminal = client.sessions.timelineEvents
          .firstWhere(
            (event) =>
                event.sessionId == session.id &&
                (event.type == 'turn.completed' || event.type == 'turn.failed'),
          )
          .timeout(_eventTimeout);
      await client.subscribeTimeline(session.id);
      await client.startTurn(
        sessionId: session.id,
        turnId: 'skill-turn',
        prompt: 'Use the shared skill.',
      );
      final outcome = await terminal;
      expect(
        outcome.type,
        'turn.completed',
        reason: 'Skill turn failed: ${outcome.data}',
      );

      final timeline = await client.subscribeTimeline(session.id);
      final loaded = timeline
          .where((event) => event.type == 'tool.completed')
          .firstWhere((event) => event.data['name'] == 'skill');
      expect(loaded.data['isError'], isFalse);
      // The worktree is the checkout itself, so the project skill wins.
      final output = loaded.data['output']! as String;
      expect(output, contains('Project instructions.'));
      expect(output, isNot(contains('Global instructions.')));
    },
    tags: const <String>[
      'feature_test__skill_catalog__verticalSlice',
      'feature_test__skill_invocation__verticalSlice',
    ],
  );

  test(
    'agent create survives watcher reload and daemon restart',
    () async {
      final home = await Directory.systemTemp.createTemp(
        'tinest-agent-create-home-',
      );
      const bearerToken = 'agent-create-token-0123456789abcdef012345';
      final config = DaemonConfig(
        homeDirectory: home.path,
        port: 0,
        bearerToken: bearerToken,
        useEnvironmentCredentials: false,
      );
      addTearDown(() async {
        if (home.existsSync()) await home.delete(recursive: true);
      });

      final firstHandle = await DaemonApplication.start(config);
      final firstClient = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: firstHandle.boundEndpoint),
        credentials: const DaemonCredentials(bearerToken: bearerToken),
        clientId: 'agent-create-first',
        clientKind: 'test',
      );
      final tinest = (await firstClient.listAgentDefinitions()).single;
      expect(tinest.toolIds, <String>[
        'tinest.edit/apply_patch',
        'tinest.mcp/list_resources',
        'tinest.mcp/list_resource_templates',
        'tinest.mcp/read_resource',
        'tinest.terminal/exec_command',
        'tinest.terminal/write_stdin',
        'tinest.collaboration/spawn_agent',
        'tinest.collaboration/send_message',
        'tinest.collaboration/followup_task',
        'tinest.collaboration/wait_agent',
        'tinest.collaboration/interrupt_agent',
        'tinest.collaboration/list_agents',
      ]);
      // What the user reads in the agent editor: a freshly seeded Tinest is
      // clean, with no unavailable_tool warning against the real catalog.
      expect(tinest.diagnostics, isEmpty);
      await firstClient.createAgentDefinition(
        'reviewer',
        tinest.copyWith(
          id: 'reviewer',
          name: 'Reviewer',
          description: '',
          mode: AgentMode.subagent,
          callableAgentIds: const <String>[],
          contentHash: '',
          sourcePath: '',
          isBuiltIn: false,
        ),
      );
      expect(
        (await firstClient.listAgentDefinitions()).map((item) => item.id),
        contains('reviewer'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(
        (await firstClient.listAgentDefinitions()).map((item) => item.id),
        contains('reviewer'),
      );
      expect(File('${home.path}/v5/agents/reviewer.md').existsSync(), isTrue);
      await firstClient.close();
      await firstHandle.stop();

      final secondHandle = await DaemonApplication.start(config);
      final secondClient = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: secondHandle.boundEndpoint),
        credentials: const DaemonCredentials(bearerToken: bearerToken),
        clientId: 'agent-create-second',
        clientKind: 'test',
      );
      expect(
        (await secondClient.listAgentDefinitions())
            .singleWhere((item) => item.id == 'tinest')
            .toolIds,
        tinest.toolIds,
      );
      expect(
        (await secondClient.listAgentDefinitions()).map((item) => item.id),
        contains('reviewer'),
      );
      await secondClient.close();
      await secondHandle.stop();
    },
    tags: const <String>[
      'feature_test__agent_definition_management__verticalSlice',
    ],
  );

  test(
    'bearer-only clients can mutate provider and Agent settings',
    () async {
      final home = await Directory.systemTemp.createTemp('tinest-remote-home-');
      final handle = await DaemonApplication.start(
        DaemonConfig(
          homeDirectory: home.path,
          port: 0,
          bearerToken: 'remote-token-0123456789abcdef0123456789',
          useEnvironmentCredentials: false,
        ),
        provider: _PatchProvider(),
      );
      addTearDown(() async {
        await handle.stop();
        await home.delete(recursive: true);
      });
      for (final headers in <Map<String, dynamic>>[
        const <String, dynamic>{},
        const <String, dynamic>{'Authorization': 'Bearer incorrect'},
      ]) {
        await expectLater(
          WebSocket.connect(handle.boundEndpoint.toString(), headers: headers),
          throwsA(isA<WebSocketException>()),
        );
      }
      final obsoleteChannel = IOWebSocketChannel.connect(
        handle.boundEndpoint,
        headers: const <String, dynamic>{
          'Authorization': 'Bearer remote-token-0123456789abcdef0123456789',
        },
      );
      await obsoleteChannel.ready;
      final obsoletePeer = json_rpc.Peer(obsoleteChannel.cast<String>());
      unawaited(obsoletePeer.listen());
      await expectLater(
        obsoletePeer.sendRequest(
          systemHelloProcedure.name,
          const HelloParamsDto(
            clientId: 'obsolete-client',
            clientKind: 'test',
            protocolMajor: 2,
            capabilities: <String, bool>{},
          ).toJson(),
        ),
        throwsA(
          isA<json_rpc.RpcException>().having(
            (error) => error.code,
            'code',
            1001,
          ),
        ),
      );
      await obsoletePeer.close();
      final rawChannel = IOWebSocketChannel.connect(
        handle.boundEndpoint,
        headers: const <String, dynamic>{
          'Authorization': 'Bearer remote-token-0123456789abcdef0123456789',
        },
      );
      await rawChannel.ready;
      final rawPeer = json_rpc.Peer(rawChannel.cast<String>());
      unawaited(rawPeer.listen());
      await rawPeer.sendRequest(
        systemHelloProcedure.name,
        const HelloParamsDto(
          clientId: 'raw-client',
          clientKind: 'test',
          protocolMajor: tinestProtocolMajor,
          capabilities: <String, bool>{},
        ).toJson(),
      );
      await expectLater(
        rawPeer.sendRequest('sessions.unknown', const <String, dynamic>{}),
        throwsA(
          isA<json_rpc.RpcException>().having(
            (error) => (error.data! as Map<String, dynamic>)['code'],
            'typed code',
            'unknown_method',
          ),
        ),
      );
      await rawPeer.close();
      final client = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
        credentials: const DaemonCredentials(
          bearerToken: 'remote-token-0123456789abcdef0123456789',
        ),
        clientId: 'remote-test',
        clientKind: 'mobile',
      );
      addTearDown(client.close);
      expect(client.serverInfo.features, isNot(contains('providerAdmin')));
      final connection = await client.createCustomProvider(
        'denied',
        const CustomProviderConfigDto(
          name: 'Bearer managed',
          baseUrl: 'http://127.0.0.1:9999/v1',
          wireFormatId: openAIChatCompletionsWireId,
          authenticationRequired: false,
        ),
      );
      expect(connection.id, isNot('denied'));
      final tinest = (await client.listAgentDefinitions()).single;
      final updated = await client.updateAgentDefinition(
        tinest.copyWith(name: 'Bearer managed Tinest'),
        expectedContentHash: tinest.contentHash,
      );
      expect(updated.name, 'Bearer managed Tinest');
    },
    tags: const <String>['feature_test__daemon_authentication__verticalSlice'],
  );

  test(
    'real daemon runs a session that belongs to no project in the user home',
    () async {
      final home = await Directory.systemTemp.createTemp('tinest-home-state-');
      // The daemon canonicalizes every workspace path, and macOS reaches its
      // temporary directory through a /var symlink, so the fixture starts from
      // the resolved path the daemon will report back.
      final userHome = Directory(
        await (await Directory.systemTemp.createTemp('tinest-user-home-'))
            .resolveSymbolicLinks(),
      );
      final modelServer = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      modelServer.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, dynamic>{
            'object': 'list',
            'data': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'test-model', 'owned_by': 'test'},
            ],
          }),
        );
        await request.response.close();
      });
      DaemonConfig config() => DaemonConfig(
        homeDirectory: home.path,
        userHomeDirectory: userHome.path,
        port: 0,
        bearerToken: 'home-token-0123456789abcdef0123456789',
        useEnvironmentCredentials: false,
      );
      var handle = await DaemonApplication.start(
        config(),
        provider: _PatchProvider(),
      );
      addTearDown(() async {
        await handle.stop();
        await home.delete(recursive: true);
        await userHome.delete(recursive: true);
        await modelServer.close(force: true);
      });
      Future<TinestClient> connect() async {
        final client = await TinestClient.connect(
          endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
          credentials: DaemonCredentials(bearerToken: handle.bearerToken),
          clientId: 'home-vertical-slice',
          clientKind: 'test',
        );
        addTearDown(client.close);
        return client;
      }

      var client = await connect();
      final catalog = await client.getWorkspaceCatalog();
      final homeWorkspace = catalog.workspaces.singleWhere(
        (item) => item.kind == WorkspaceKind.home,
      );
      expect(homeWorkspace.rootPath, userHome.path);
      final homeCheckout = catalog.worktrees.singleWhere(
        (item) => item.workspaceId == homeWorkspace.id,
      );
      expect(homeCheckout.kind, WorktreeKind.directory);
      expect(homeCheckout.path, userHome.path);
      expect(homeCheckout.isTinestOwned, isFalse);

      // The daemon owns this workspace, so clients must not be able to drop it
      // and orphan every session that belongs to no project.
      await expectLater(
        client.unregisterWorkspace(homeWorkspace.id),
        throwsA(isA<TinestClientException>()),
      );
      await expectLater(
        client.archiveWorktree(homeCheckout.id, force: true),
        throwsA(isA<TinestClientException>()),
      );
      await expectLater(
        client.registerWorkspace(
          workspaceId: 'shadow-home',
          checkoutId: 'shadow-home-checkout',
          rootPath: userHome.path,
          name: 'Home again',
        ),
        throwsA(isA<TinestClientException>()),
      );

      await client.createCustomProvider(
        'local-test',
        CustomProviderConfigDto(
          name: 'Local test',
          baseUrl: 'http://127.0.0.1:${modelServer.port}/v1',
          wireFormatId: openAIChatCompletionsWireId,
          authenticationRequired: false,
          models: const <ManualProviderModelDto>[
            ManualProviderModelDto(id: 'test-model', label: 'test-model'),
          ],
        ),
      );
      final session = await client.createSession(
        id: 'home-session',
        worktreeId: homeCheckout.id,
        title: 'No project',
        agentDefinitionId: 'tinest',
        model: const ModelSelectionDto(modelId: 'local-test/test-model'),
      );
      expect(session.worktreeId, homeCheckout.id);
      expect(
        (await client.sessions.listSessions(worktreeId: homeCheckout.id))
            .single
            .id,
        'home-session',
      );

      // Re-provisioning happens on every boot, so a restart must reuse the same
      // workspace and checkout rather than forking a second home.
      await handle.stop();
      handle = await DaemonApplication.start(
        config(),
        provider: _PatchProvider(),
      );
      client = await connect();
      final restarted = await client.getWorkspaceCatalog();
      expect(
        restarted.workspaces.where((item) => item.kind == WorkspaceKind.home),
        hasLength(1),
      );
      expect(restarted.workspaces.single.id, homeWorkspace.id);
      expect(restarted.worktrees.single.id, homeCheckout.id);
      expect(
        (await client.sessions.listSessions(worktreeId: homeCheckout.id))
            .single
            .id,
        'home-session',
      );
    },
    tags: const <String>['feature_test__session_home__verticalSlice'],
  );

  test(
    'real daemon creates and archives a Git worktree over WebSocket',
    () async {
      final home = await Directory.systemTemp.createTemp('tinest-git-home-');
      // The daemon canonicalizes every workspace path, and macOS reaches its
      // temporary directory through a /var symlink to /private/var, so the
      // fixture starts from the resolved path the daemon will report back.
      final repository = Directory(
        await (await Directory.systemTemp.createTemp('tinest-git-repository-'))
            .resolveSymbolicLinks(),
      );
      await _runGit(repository.path, <String>['init', '-b', 'main']);
      await File('${repository.path}/README.md').writeAsString('# fixture\n');
      await _runGit(repository.path, <String>['add', 'README.md']);
      await _runGit(repository.path, <String>[
        '-c',
        'user.name=Tinest Test',
        '-c',
        'user.email=tinest@example.invalid',
        'commit',
        '-m',
        'Initial fixture',
      ]);
      final handle = await DaemonApplication.start(
        DaemonConfig(
          homeDirectory: home.path,
          port: 0,
          bearerToken: 'git-token-0123456789abcdef0123456789',
          useEnvironmentCredentials: false,
        ),
      );
      addTearDown(() async {
        await handle.stop();
        await home.delete(recursive: true);
        await repository.delete(recursive: true);
      });
      final client = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
        credentials: DaemonCredentials(bearerToken: handle.bearerToken),
        clientId: 'git-vertical-slice',
        clientKind: 'test',
      );
      addTearDown(client.close);

      final registered = await client.registerWorkspace(
        workspaceId: 'git-workspace',
        checkoutId: 'main-checkout',
        rootPath: repository.path,
        name: 'Git fixture',
      );
      expect(registered.workspace.kind, WorkspaceKind.git);
      expect(await client.listGitBranches('git-workspace'), hasLength(1));

      // The repository checkout stays on disk either way, so archiving it would
      // only hide the project from the catalog.
      await expectLater(
        client.archiveWorktree('main-checkout', force: true),
        throwsA(isA<TinestClientException>()),
      );
      expect(
        (await client.getWorkspaceCatalog()).worktrees.single.id,
        'main-checkout',
      );

      expect(
        (await client.getProjectSettings('git-workspace')).settings,
        const ProjectSettingsDto(),
      );
      final teardownMarker = p.join(repository.path, 'teardown-ran');
      // Hooks run in the platform shell, so the fixture has to speak the one
      // it will actually get.
      final saved = await client.saveProjectSettings(
        'git-workspace',
        ProjectSettingsDto(
          setup: <String>[
            if (Platform.isWindows)
              'echo %CODER_BRANCH% > setup-ran'
            else
              r'printf "%s" "$CODER_BRANCH" > setup-ran',
          ],
          teardown: <String>[
            if (Platform.isWindows)
              'echo ran > $teardownMarker'
            else
              'printf ran > $teardownMarker',
          ],
        ),
      );
      expect(
        saved.sourcePath,
        p.join(repository.path, '.tinest', 'config.json'),
      );
      expect(File(saved.sourcePath).existsSync(), isTrue);

      final externalPath = p.join(home.path, 'external-worktree');
      await _runGit(repository.path, <String>[
        'worktree',
        'add',
        '-b',
        'external-race',
        externalPath,
      ]);
      final canonicalExternalPath = await Directory(externalPath)
          .resolveSymbolicLinks();
      final refreshed = await client.refreshWorkspace('git-workspace');
      expect(
        refreshed.worktrees.map((worktree) => worktree.path),
        contains(
          predicate<String>((item) => p.equals(item, canonicalExternalPath)),
        ),
      );
      final external = refreshed.worktrees.singleWhere(
        (worktree) => p.equals(worktree.path, canonicalExternalPath),
      );
      await _runGit(repository.path, <String>[
        'worktree',
        'remove',
        '--force',
        externalPath,
      ]);
      await expectLater(
        client.createTerminal(
          id: 'missing-worktree-terminal',
          worktreeId: external.id,
          title: 'Missing worktree',
          columns: 80,
          rows: 24,
        ),
        throwsA(
          isA<TinestClientException>().having(
            (error) => error.code,
            'code',
            RpcErrorCodes.worktreeUnavailable,
          ),
        ),
      );
      expect(
        (await client.getWorkspaceCatalog()).worktrees,
        isNot(
          contains(predicate<WorktreeDto>((item) => item.id == external.id)),
        ),
      );

      final archivedExternalPath = p.join(home.path, 'external-archive');
      await _runGit(repository.path, <String>[
        'worktree',
        'add',
        '-b',
        'external-archive',
        archivedExternalPath,
      ]);
      final canonicalArchivedExternalPath = await Directory(
        archivedExternalPath,
      ).resolveSymbolicLinks();
      final archiveCatalog = await client.refreshWorkspace('git-workspace');
      final archivedExternal = archiveCatalog.worktrees.singleWhere(
        (worktree) => p.equals(worktree.path, canonicalArchivedExternalPath),
      );
      expect(archivedExternal.kind, WorktreeKind.linked);
      expect(
        (await client.previewWorktreeArchive(archivedExternal.id))
            .removesDirectory,
        isTrue,
      );
      await client.archiveWorktree(archivedExternal.id);
      expect(Directory(archivedExternalPath).existsSync(), isFalse);
      expect(
        (await client.listGitBranches('git-workspace'))
            .map((branch) => branch.name),
        contains('external-archive'),
      );
      expect(
        (await client.getWorkspaceCatalog()).worktrees.map(
          (worktree) => worktree.id,
        ),
        isNot(contains(archivedExternal.id)),
      );

      final managed = await client.createWorktree(
        id: 'managed-worktree',
        workspaceId: 'git-workspace',
        mode: WorktreeCreateMode.newBranch,
        branchName: 'feature/vertical-slice',
        baseBranch: 'main',
      );
      expect(Directory(managed.worktree.path).existsSync(), isTrue);
      expect(managed.hookRuns.single.exitCode, 0);
      expect(managed.hookRuns.single.phase, WorktreeHookPhase.setup);
      expect(
        // cmd's echo appends a line break, so compare the written value.
        (await File(
          p.join(managed.worktree.path, 'setup-ran'),
        ).readAsString()).trim(),
        'feature-vertical-slice',
      );
      expect(
        (await client.refreshWorkspace('git-workspace')).worktrees,
        isNotEmpty,
      );
      final preview = await client.previewWorktreeArchive(managed.worktree.id);
      expect(preview.removesDirectory, isTrue);
      final archived = await client.archiveWorktree(
        managed.worktree.id,
        force: true,
      );
      expect(archived.hookRuns.single.phase, WorktreeHookPhase.teardown);
      expect(archived.hookRuns.single.exitCode, 0);
      expect(File(teardownMarker).existsSync(), isTrue);
      expect(Directory(managed.worktree.path).existsSync(), isFalse);

      // Archiving removed the checkout but left the local branch, so asking
      // again with the same derived name used to fail as an unexplained
      // internal error. Requesting derived naming keeps the session possible.
      await expectLater(
        client.createWorktree(
          id: 'managed-worktree-exact',
          workspaceId: 'git-workspace',
          mode: WorktreeCreateMode.newBranch,
          branchName: 'feature/vertical-slice',
          baseBranch: 'main',
        ),
        throwsA(
          isA<TinestClientException>().having(
            (error) => error.code,
            'code',
            RpcErrorCodes.branchAlreadyExists,
          ),
        ),
      );
      final derived = await client.createWorktree(
        id: 'managed-worktree-derived',
        workspaceId: 'git-workspace',
        mode: WorktreeCreateMode.newBranch,
        branchName: 'feature/vertical-slice',
        baseBranch: 'main',
        branchNaming: WorktreeBranchNaming.derive,
      );
      expect(derived.worktree.branch, 'feature-vertical-slice-2');
      expect(Directory(derived.worktree.path).existsSync(), isTrue);
      await client.archiveWorktree(derived.worktree.id, force: true);

      // A base ref Git cannot resolve reports the command and its own stderr
      // rather than collapsing into a generic internal failure.
      await expectLater(
        client.createWorktree(
          id: 'managed-worktree-bad-base',
          workspaceId: 'git-workspace',
          mode: WorktreeCreateMode.newBranch,
          branchName: 'no-such-base',
          baseBranch: 'refs/heads/definitely-missing',
        ),
        throwsA(
          isA<TinestClientException>()
              .having(
                (error) => error.code,
                'code',
                RpcErrorCodes.gitCommandFailed,
              )
              .having((error) => error.details['stderr'], 'stderr', isNotEmpty),
        ),
      );
      await client.unregisterWorkspace('git-workspace');
      expect((await client.getWorkspaceCatalog()).workspaces, isEmpty);
    },
    tags: const <String>[
      'feature_test__workspace_catalog__verticalSlice',
      'feature_test__worktree_lifecycle__verticalSlice',
      'feature_test__terminal_lifecycle__verticalSlice',
      'feature_test__project_settings__verticalSlice',
    ],
  );

  test(
    'real daemon completes and cancels OAuth attempts over WebSocket',
    () async {
      final home = await Directory.systemTemp.createTemp('tinest-oauth-home-');
      final gateway = _IntegrationOAuthGateway();
      final handle = await DaemonApplication.start(
        DaemonConfig(
          homeDirectory: home.path,
          port: 0,
          bearerToken: 'oauth-token-0123456789abcdef01234567',
          useEnvironmentCredentials: false,
        ),
        oauthGateway: gateway,
        modelDiscovery: const _CredentialAwareDiscovery(),
      );
      addTearDown(() async {
        await handle.stop();
        await home.delete(recursive: true);
      });
      final client = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
        credentials: DaemonCredentials(bearerToken: handle.bearerToken),
        clientId: 'oauth-vertical-slice',
        clientKind: 'test',
      );
      addTearDown(client.close);

      final rejected = await client.connectProviderApiKey(
        'deepseek',
        'invalid-key',
      );
      expect(rejected.status, ProviderConnectionStatus.error);
      final corrected = await client.connectProviderApiKey(
        'deepseek',
        'valid-key',
        connectionId: rejected.id,
      );
      expect(corrected.id, rejected.id);
      expect(corrected.status, ProviderConnectionStatus.connected);
      await client.disconnectProvider(corrected.id);

      final completed = await client.startProviderAuth(
        'openai',
        'chatgpt-device',
      );
      gateway.sessions.single.completer.complete(
        OAuthCredential(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        ),
      );
      await _waitForAuthStatus(
        client,
        completed.id,
        ProviderAuthAttemptStatus.succeeded,
      );
      final connected = (await client.listProviderConnections()).singleWhere(
        (connection) => connection.definitionId == 'openai',
      );
      expect(connected.credentialOrigin, ProviderCredentialOrigin.oauth);
      // The Codex endpoint has no `/models` listing, so the connection must
      // settle on the bundled catalog instead of degrading on a discovery 400.
      expect(connected.status, ProviderConnectionStatus.connected);
      expect(connected.error, isNull);
      final oauthModels = (await client.listProviderModels(connected.id))
          .map((model) => model.id);
      expect(oauthModels, contains('openai/gpt-5.6-sol'));
      expect(oauthModels, isNot(contains('gpt-test')));

      final createdAt = connected.createdAt;
      final reauth = await client.startProviderAuth(
        'openai',
        'chatgpt-device',
        connectionId: connected.id,
      );
      gateway.sessions.last.completer.complete(
        OAuthCredential(
          accessToken: 'replacement-access-token',
          refreshToken: 'replacement-refresh-token',
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 2)),
        ),
      );
      await _waitForAuthStatus(
        client,
        reauth.id,
        ProviderAuthAttemptStatus.succeeded,
      );
      final reauthenticated = await client.listProviderConnections();
      final reauthenticatedOpenAI = reauthenticated.singleWhere(
        (connection) => connection.definitionId == 'openai',
      );
      expect(reauthenticatedOpenAI.id, connected.id);
      expect(reauthenticatedOpenAI.createdAt, createdAt);

      final cancelled = await client.startProviderAuth(
        'openai',
        'chatgpt-browser',
      );
      await client.cancelProviderAuth(cancelled.id);
      expect(
        (await client.providers.providerAuthStatus(cancelled.id)).status,
        ProviderAuthAttemptStatus.cancelled,
      );
      expect(gateway.sessions.last.cancelled, isTrue);
    },
    tags: const <String>['feature_test__provider_oauth__verticalSlice'],
  );

  test(
    'attachments stream through a remote client and survive daemon restart',
    tags: const <String>[
      'feature_test__conversation_attachments__verticalSlice',
    ],
    () async {
      final home = await Directory.systemTemp.createTemp(
        'tinest-attachment-home-',
      );
      final workspace = await Directory.systemTemp.createTemp(
        'tinest-attachment-workspace-',
      );
      await File(p.join(workspace.path, 'agent-result.txt'))
          .writeAsString('agent bytes');
      const token = 'attachment-token-0123456789abcdef0123456789';
      final provider = _AttachmentProvider();
      final config = DaemonConfig(
        homeDirectory: home.path,
        port: 0,
        bearerToken: token,
        useEnvironmentCredentials: false,
      );
      var handle = await DaemonApplication.start(config, provider: provider);
      var client = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
        credentials: const DaemonCredentials(bearerToken: token),
        clientId: 'attachment-integration',
        clientKind: 'test',
      );
      addTearDown(() async {
        await client.close();
        await handle.stop();
        await home.delete(recursive: true);
        await workspace.delete(recursive: true);
      });
      await _selectTinestTools(client, const <String>[
        'tinest.attachments/attach_file',
      ]);

      final unauthorizedClient = HttpClient();
      final unauthorized = await unauthorizedClient.getUrl(
        handle.boundEndpoint.replace(
          scheme: 'http',
          path: '/v5/attachments/missing',
        ),
      );
      expect((await unauthorized.close()).statusCode, HttpStatus.unauthorized);
      unauthorizedClient.close(force: true);

      final imageBytes = <int>[
        0x89,
        0x50,
        0x4e,
        0x47,
        0x0d,
        0x0a,
        0x1a,
        0x0a,
        1,
        2,
        3,
      ];
      final uploaded = await client.uploadAttachment(
        fileName: 'fixture.png',
        mimeType: 'image/png',
        byteSize: imageBytes.length,
        bytes: Stream<List<int>>.value(imageBytes),
      );
      expect(uploaded.kind, AttachmentKind.image);

      final catalog = await client.registerWorkspace(
        workspaceId: 'attachment-workspace',
        checkoutId: 'attachment-checkout',
        rootPath: workspace.path,
        name: 'Attachments',
      );
      final session = await client.createSession(
        id: 'attachment-session',
        worktreeId: catalog.worktrees.single.id,
        title: 'Attachment session',
        agentDefinitionId: 'tinest',
        // The default v5 Agent exposes function and deferred tools; its queue
        // fixture must select a model supporting the whole surface.
        model: const ModelSelectionDto(modelId: _testModelId),
      );
      await client.subscribeTimeline(session.id);
      final terminal = client.sessions.timelineEvents
          .firstWhere(
            (event) =>
                event.sessionId == session.id &&
                (event.type == 'turn.completed' || event.type == 'turn.failed'),
          )
          .timeout(_eventTimeout);
      await client.startTurn(
        sessionId: session.id,
        turnId: 'attachment-turn',
        prompt: '',
        attachmentIds: <String>[uploaded.id],
      );
      final outcome = await terminal;
      expect(
        outcome.type,
        'turn.completed',
        reason: 'Attachment turn failed: ${outcome.data}',
      );

      final request = await provider.firstRequest.future;
      final input = request.history.whereType<UserConversationItem>().last;
      expect(input.text, isEmpty);
      expect(input.attachments.single.bytes, imageBytes);
      final timeline = await client.subscribeTimeline(session.id);
      final userMessage = timeline.singleWhere(
        (event) => event.type == 'user.message',
      );
      expect(userMessage.data['attachments'], hasLength(1));
      final userAttachment =
          (userMessage.data['attachments']! as List<Object?>).single!
              as Map<String, dynamic>;
      expect(userAttachment, isNot(contains('path')));
      expect(userAttachment, isNot(contains('bytes')));
      final outbound = timeline.singleWhere(
        (event) => event.type == 'assistant.attachment',
      );
      expect(outbound.data, isNot(contains('path')));
      expect(outbound.data, isNot(contains('bytes')));
      final outboundId = outbound.data['id']! as String;

      final imageDownload = await client.downloadAttachment(uploaded.id);
      expect(
        await imageDownload.bytes.expand((chunk) => chunk).toList(),
        imageBytes,
      );
      final outboundDownload = await client.downloadAttachment(outboundId);
      expect(
        utf8.decode(
          await outboundDownload.bytes.expand((chunk) => chunk).toList(),
        ),
        'agent bytes',
      );

      await client.close();
      await handle.stop();
      handle = await DaemonApplication.start(
        config,
        provider: _AttachmentProvider(),
      );
      client = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
        credentials: const DaemonCredentials(bearerToken: token),
        clientId: 'attachment-reconnect',
        clientKind: 'test',
      );
      final restored = await client.downloadAttachment(uploaded.id);
      expect(
        await restored.bytes.expand((chunk) => chunk).toList(),
        imageBytes,
      );
      expect(
        await client.subscribeTimeline(session.id),
        contains(
          predicate<TimelineEventDto>(
            (event) =>
                event.type == 'assistant.attachment' &&
                event.data['id'] == outboundId,
          ),
        ),
      );
    },
  );

  test(
    'a pre-launch attachment failure clears the session for retry',
    tags: const <String>[
      'feature_test__conversation_attachments__verticalSlice',
      'feature_test__turn_execution__verticalSlice',
    ],
    () async {
      final home = await Directory.systemTemp.createTemp(
        'tinest-prelaunch-failure-home-',
      );
      final workspace = await Directory.systemTemp.createTemp(
        'tinest-prelaunch-failure-workspace-',
      );
      const token = 'prelaunch-failure-token-0123456789abcdef012345';
      final provider = _AttachmentProvider();
      final handle = await DaemonApplication.start(
        DaemonConfig(
          homeDirectory: home.path,
          port: 0,
          bearerToken: token,
          useEnvironmentCredentials: false,
        ),
        provider: provider,
      );
      final client = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
        credentials: const DaemonCredentials(bearerToken: token),
        clientId: 'prelaunch-failure-test',
        clientKind: 'test',
      );
      addTearDown(() async {
        await client.close();
        await handle.stop();
        await home.delete(recursive: true);
        await workspace.delete(recursive: true);
      });
      await _selectTinestTools(client, const <String>[
        'tinest.attachments/attach_file',
      ]);

      final imageBytes = <int>[
        0x89,
        0x50,
        0x4e,
        0x47,
        0x0d,
        0x0a,
        0x1a,
        0x0a,
        1,
        2,
        3,
      ];
      final uploaded = await client.uploadAttachment(
        fileName: 'missing.png',
        mimeType: 'image/png',
        byteSize: imageBytes.length,
        bytes: Stream<List<int>>.value(imageBytes),
      );
      final blobFiles = Directory(home.path)
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => p.extension(file.path) == '.blob')
          .toList(growable: false);
      expect(blobFiles, hasLength(1));
      final blobPath = blobFiles.single.path;
      await blobFiles.single.delete();

      final catalog = await client.registerWorkspace(
        workspaceId: 'prelaunch-failure-workspace',
        checkoutId: 'prelaunch-failure-checkout',
        rootPath: workspace.path,
        name: 'Pre-launch failure',
      );
      final session = await client.createSession(
        id: 'prelaunch-failure-session',
        worktreeId: catalog.worktrees.single.id,
        title: 'Pre-launch failure',
        agentDefinitionId: 'tinest',
        // The default v5 Agent exposes function and deferred tools; picking
        // the first streaming model from the catalog chose a
        // surface-incomplete model whenever the catalog ordered one first.
        model: const ModelSelectionDto(modelId: _testModelId),
      );

      await expectLater(
        client.startTurn(
          sessionId: session.id,
          turnId: 'broken-turn',
          prompt: 'This attachment cannot be opened.',
          attachmentIds: <String>[uploaded.id],
        ),
        throwsA(isA<Exception>()),
      );
      final stuck = (await client.listSessions()).singleWhere(
        (item) => item.id == session.id,
      );
      expect(stuck.status, SessionStatus.failed);
      expect(stuck.activeTurnId, isNull);
      expect(
        await client.subscribeTimeline(session.id),
        contains(
          predicate<TimelineEventDto>(
            (event) =>
                event.type == 'turn.failed' && event.turnId == 'broken-turn',
          ),
        ),
      );

      await File(blobPath).writeAsBytes(imageBytes);
      // The retry turn runs detached, so wait on its own terminal timeline
      // event rather than on the provider call: a failure before the model
      // opens would otherwise leave nothing to wait for and only the wall
      // clock would fire, without the failure payload.
      final retryTerminal = client.sessions.timelineEvents
          .firstWhere(
            (event) =>
                event.sessionId == session.id &&
                event.turnId == 'retry-turn' &&
                (event.type == 'turn.completed' || event.type == 'turn.failed'),
          )
          .timeout(_eventTimeout);
      await client.startTurn(
        sessionId: session.id,
        turnId: 'retry-turn',
        prompt: 'Retry after the failure.',
      );
      final retryOutcome = await retryTerminal;
      expect(
        retryOutcome.type,
        'turn.completed',
        reason: 'Retry turn failed: ${retryOutcome.data}',
      );
      await provider.firstRequest.future.timeout(_eventTimeout);
      await _waitForIdleSession(
        client,
        catalog.worktrees.single.id,
        session.id,
      );
    },
  );

  test('secrets are not persisted in daemon files', () async {
    final home = await Directory.systemTemp.createTemp('tinest-secret-home-');
    final config = await Directory.systemTemp.createTemp(
      'tinest-secret-config-',
    );
    const token = 'plaintext-token-that-must-not-be-stored';
    final handle = await DaemonApplication.start(
      DaemonConfig(
        homeDirectory: home.path,
        configDirectory: config.path,
        port: 0,
        bearerToken: token,
        useEnvironmentCredentials: false,
      ),
      modelDiscovery: const _StaticDiscovery(<String>['gpt-5.6-sol']),
    );
    await handle.stop();
    final persisted = StringBuffer();
    await for (final entity in home.list(recursive: true)) {
      if (entity is File) {
        persisted.write(String.fromCharCodes(await entity.readAsBytes()));
      }
    }
    expect(persisted.toString(), isNot(contains(token)));
    final credentials = await File('${config.path}/v5/secrets.json')
        .readAsString();
    expect(credentials, contains(token));
    expect(File('${config.path}/auth.json').existsSync(), isFalse);
    if (!Platform.isWindows) {
      expect(
        File('${config.path}/v5/secrets.json').statSync().mode & 0x1ff,
        0x180,
      );
    }
    await home.delete(recursive: true);
    await config.delete(recursive: true);
  });

  test('embedded daemon starts in an isolate and shuts down cleanly', () async {
    final home = await Directory.systemTemp.createTemp('tinest-embedded-home-');
    final handle = await EmbeddedDaemonHandle.start(
      DaemonConfig(
        homeDirectory: home.path,
        port: 0,
        bearerToken: 'embedded-token-0123456789abcdef012345',
        useEnvironmentCredentials: false,
      ),
    );
    expect(handle.boundEndpoint.port, greaterThan(0));
    await handle.stop();
    await home.delete(recursive: true);
  });

  test(
    'concurrent embedded daemon stops join the same completed shutdown',
    () async {
      final home = await Directory.systemTemp.createTemp(
        'tinest-embedded-concurrent-stop-',
      );
      final handle = await EmbeddedDaemonHandle.start(
        DaemonConfig(
          homeDirectory: home.path,
          port: 0,
          bearerToken: 'embedded-token-0123456789abcdef012345',
          useEnvironmentCredentials: false,
        ),
      );
      var firstStopCompleted = false;
      final firstStop = handle.stop().whenComplete(() {
        firstStopCompleted = true;
      });
      addTearDown(() async {
        await firstStop;
        if (home.existsSync()) {
          await home.delete(recursive: true);
        }
      });

      await handle.stop();

      expect(firstStopCompleted, isTrue);
      await firstStop;
      await home.delete(recursive: true);
    },
    tags: const <String>['feature_test__daemon_management__contract'],
  );

  test('embedded daemon reports a typed port conflict', () async {
    // The socket stays bound for as long as the port number is used, because
    // the test only owns that number while it holds it. Releasing it and
    // expecting to bind it again races every other server on the host: the OS
    // hands ephemeral ports out of one pool, and this suite alone starts many
    // daemons at once, so the number can be gone before it is reused.
    final occupied = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(occupied.close);
    final home = await Directory.systemTemp.createTemp(
      'tinest-embedded-conflict-',
    );
    addTearDown(() => home.delete(recursive: true));

    const token = 'embedded-token-0123456789abcdef012345';
    await expectLater(
      EmbeddedDaemonHandle.start(
        DaemonConfig(
          homeDirectory: home.path,
          port: occupied.port,
          bearerToken: token,
          useEnvironmentCredentials: false,
        ),
      ),
      throwsA(
        isA<EmbeddedDaemonStartupException>().having(
          (error) => error.reason,
          'reason',
          EmbeddedDaemonStartupFailureReason.portInUse,
        ),
      ),
    );

    // What the refusal must not do is poison the home directory it already
    // opened, so the same home starts cleanly afterwards. Which port the
    // second start lands on is the operating system's business, not the
    // daemon's.
    final recovered = await EmbeddedDaemonHandle.start(
      DaemonConfig(
        homeDirectory: home.path,
        port: 0,
        bearerToken: token,
        useEnvironmentCredentials: false,
      ),
    );
    expect(recovered.boundEndpoint.port, greaterThan(0));
    await recovered.stop();
  });

  test(
    'a queued turn started on the idle session event is accepted',
    tags: const <String>[
      'feature_test__conversation_turn_queue__verticalSlice',
    ],
    () async {
      final home = await Directory.systemTemp.createTemp('tinest-queue-home-');
      final workspace = await Directory.systemTemp.createTemp(
        'tinest-queue-workspace-',
      );
      const token = 'queue-token-0123456789abcdef0123456789';
      final handle = await DaemonApplication.start(
        DaemonConfig(
          homeDirectory: home.path,
          port: 0,
          bearerToken: token,
          useEnvironmentCredentials: false,
        ),
        provider: _TextProvider(),
      );
      final client = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
        credentials: const DaemonCredentials(bearerToken: token),
        clientId: 'queue-integration',
        clientKind: 'test',
      );
      addTearDown(() async {
        await client.close();
        await handle.stop();
        await home.delete(recursive: true);
        await workspace.delete(recursive: true);
      });

      final catalog = await client.registerWorkspace(
        workspaceId: 'queue-workspace',
        checkoutId: 'queue-checkout',
        rootPath: workspace.path,
        name: 'Queue',
      );
      final session = await client.createSession(
        id: 'queue-session',
        worktreeId: catalog.worktrees.single.id,
        title: 'Queue session',
        agentDefinitionId: 'tinest',
        model: const ModelSelectionDto(modelId: _testModelId),
      );
      await client.subscribeTimeline(session.id);

      // The drain a queueing client performs: start the follow-up turn from the
      // idle session event itself, without waiting a further round trip. The
      // daemon must have released the session slot before broadcasting it.
      final drained = Completer<void>();
      final subscription = client.sessions.sessionUpdates.listen((updated) {
        if (updated.id != session.id) return;
        if (updated.status != SessionStatus.idle) return;
        if (drained.isCompleted) return;
        drained.complete(
          client.startTurn(
            sessionId: session.id,
            turnId: 'queued-turn',
            prompt: 'The queued follow-up.',
          ),
        );
      });
      addTearDown(subscription.cancel);

      await client.startTurn(
        sessionId: session.id,
        turnId: 'first-turn',
        prompt: 'The first prompt.',
      );
      try {
        await drained.future.timeout(_eventTimeout);
      } on TimeoutException catch (error) {
        final current = (await client.sessions.listSessions(
          worktreeId: catalog.worktrees.single.id,
        )).singleWhere((item) => item.id == session.id);
        final timeline = await client.subscribeTimeline(session.id);
        final timelineDescription = timeline
            .map((event) => '${event.type}: ${event.data}')
            .join('\n');
        throw TestFailure(
          '$error while waiting for the idle queue drain; '
          'status=${current.status}, error=${current.lastError}\n'
          '$timelineDescription',
        );
      }

      await _waitForIdleSession(
        client,
        catalog.worktrees.single.id,
        session.id,
      );
      final timeline = await client.subscribeTimeline(session.id);
      expect(
        timeline
            .where((event) => event.type == 'user.message')
            .map((event) => event.data['text']),
        <String>['The first prompt.', 'The queued follow-up.'],
      );
    },
  );

  test(
    'composer file search honours gitignore over a real daemon',
    () async {
      final home = await Directory.systemTemp.createTemp(
        'tinest-mention-home-',
      );
      final repository = Directory(
        await (await Directory.systemTemp.createTemp(
          'tinest-mention-repository-',
        )).resolveSymbolicLinks(),
      );
      await _runGit(repository.path, <String>['init', '-b', 'main']);
      await File(p.join(repository.path, '.gitignore'))
          .writeAsString('secrets.env\n');
      await Directory(p.join(repository.path, 'lib')).create(recursive: true);
      await File(p.join(repository.path, 'lib', 'composer.dart'))
          .writeAsString('// composer\n');
      await File(p.join(repository.path, 'secrets.env'))
          .writeAsString('TOKEN=nope\n');

      final handle = await DaemonApplication.start(
        DaemonConfig(
          homeDirectory: home.path,
          port: 0,
          bearerToken: 'mention-token-0123456789abcdef0123456789',
          useEnvironmentCredentials: false,
        ),
      );
      addTearDown(() async {
        await handle.stop();
        await home.delete(recursive: true);
        await repository.delete(recursive: true);
      });
      final client = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
        credentials: DaemonCredentials(bearerToken: handle.bearerToken),
        clientId: 'mention-vertical-slice',
        clientKind: 'test',
      );
      addTearDown(client.close);

      final registered = await client.registerWorkspace(
        workspaceId: 'mention-workspace',
        checkoutId: 'mention-checkout',
        rootPath: repository.path,
        name: 'Mention fixture',
      );
      final worktreeId = registered.worktrees.single.id;

      final matched = await client.searchFiles(
        worktreeId: worktreeId,
        query: 'composer',
      );
      expect(
        matched.matches.map((match) => match.relativePath),
        contains('lib/composer.dart'),
      );
      expect(matched.matches.single.absolutePath, startsWith(repository.path));

      final everything = await client.searchFiles(
        worktreeId: worktreeId,
        query: '',
      );
      expect(
        everything.matches.map((match) => match.relativePath),
        isNot(contains('secrets.env')),
      );
      expect(
        everything.matches.map((match) => match.relativePath),
        contains('.gitignore'),
      );

      await expectLater(
        client.searchFiles(worktreeId: 'missing', query: 'composer'),
        throwsA(isA<Exception>()),
      );
    },
    tags: const <String>['feature_test__composer_file_mention__verticalSlice'],
  );

  test(
    'agent commands merge across sources and follow disk changes',
    () async {
      final home = await Directory.systemTemp.createTemp(
        'tinest-command-home-',
      );
      final agentsHome = await Directory.systemTemp.createTemp(
        'tinest-command-agents-home-',
      );
      final workspace = await Directory.systemTemp.createTemp(
        'tinest-command-workspace-',
      );
      const bearerToken = 'command-token-0123456789abcdef0123456789';
      addTearDown(() async {
        await home.delete(recursive: true);
        await agentsHome.delete(recursive: true);
        await workspace.delete(recursive: true);
      });

      await _writeCommand(
        p.join(agentsHome.path, '.agents', 'commands'),
        name: 'review',
        description: 'From the user home.',
        body: 'Global review.',
      );
      await _writeCommand(
        p.join(workspace.path, '.agents', 'commands'),
        name: 'review',
        description: 'From the project.',
        body: r'Review $ARGUMENTS.',
        argumentHint: '<path>',
      );

      final handle = await DaemonApplication.start(
        DaemonConfig(
          homeDirectory: home.path,
          userHomeDirectory: agentsHome.path,
          port: 0,
          bearerToken: bearerToken,
          useEnvironmentCredentials: false,
        ),
      );
      addTearDown(handle.stop);
      final client = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
        credentials: const DaemonCredentials(bearerToken: bearerToken),
        clientId: 'command-vertical-slice',
        clientKind: 'test',
      );
      addTearDown(client.close);

      final global = await client.listCommands();
      expect(global.single.name, 'review');
      expect(global.single.description, 'From the user home.');
      expect(global.single.source, AgentCommandSource.userHome);

      await client.registerWorkspace(
        workspaceId: 'command-workspace',
        checkoutId: 'command-checkout',
        rootPath: workspace.path,
        name: 'Workspace',
      );
      final scoped = await client.listCommands(
        workspaceId: 'command-workspace',
      );
      expect(scoped.single.source, AgentCommandSource.project);
      expect(scoped.single.description, 'From the project.');
      expect(scoped.single.argumentHint, '<path>');
      expect(scoped.single.body, r'Review $ARGUMENTS.');

      final changed = client.prompts.commandChanges.first;
      await _writeCommand(
        p.join(agentsHome.path, '.agents', 'commands'),
        name: 'ship',
        description: 'Ships the branch.',
        body: 'Ship it.',
      );
      await changed.timeout(const Duration(seconds: 10));

      expect(
        (await client.listCommands()).map((command) => command.name),
        containsAll(<String>['review', 'ship']),
      );
    },
    tags: const <String>['feature_test__composer_slash_command__verticalSlice'],
  );
}

Future<void> _waitForProviderStartOrTurnFailure({
  required TinestApi client,
  required String worktreeId,
  required String sessionId,
  required Completer<void> started,
}) async {
  for (var attempt = 0; attempt < 600; attempt += 1) {
    if (started.isCompleted) return;
    final current = (await client.sessions.listSessions(worktreeId: worktreeId))
        .singleWhere((item) => item.id == sessionId);
    if (current.status == SessionStatus.failed) {
      throw StateError(
        'Turn failed before the provider started: '
        '${current.lastError ?? 'unknown error'}',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  await started.future.timeout(_eventTimeout);
}

Future<T> _waitForProviderResultOrTurnFailure<T>({
  required TinestApi client,
  required String worktreeId,
  required String sessionId,
  required Future<T> result,
  Future<Never>? externalFailure,
  String Function()? progress,
}) async {
  final completed =
      Completer<({Object? value, Object? error, StackTrace? stack})>();
  unawaited(
    result.then<void>(
      (value) {
        if (!completed.isCompleted) {
          completed.complete((value: value, error: null, stack: null));
        }
      },
      onError: (Object error, StackTrace stack) {
        if (!completed.isCompleted) {
          completed.complete((value: null, error: error, stack: stack));
        }
      },
    ),
  );
  final failure = externalFailure;
  if (failure != null) {
    unawaited(
      failure.then<void>(
        (_) {},
        onError: (Object error, StackTrace stack) {
          if (!completed.isCompleted) {
            completed.complete((value: null, error: error, stack: stack));
          }
        },
      ),
    );
  }
  for (
    var attempt = 0;
    attempt < 1200 && !completed.isCompleted;
    attempt += 1
  ) {
    final current = (await client.sessions.listSessions(worktreeId: worktreeId))
        .singleWhere((item) => item.id == sessionId);
    if (current.status == SessionStatus.failed) {
      throw StateError(
        'Turn failed before the provider result: '
        '${current.lastError ?? 'unknown error'} '
        '(${progress?.call() ?? 'no progress'})',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  if (!completed.isCompleted) {
    final current = (await client.sessions.listSessions(worktreeId: worktreeId))
        .singleWhere((item) => item.id == sessionId);
    throw StateError(
      'Timed out waiting for provider result: status=${current.status}, '
      'error=${current.lastError}, ${progress?.call() ?? 'no progress'}',
    );
  }
  final outcome = await completed.future;
  final error = outcome.error;
  if (error != null) {
    Error.throwWithStackTrace(error, outcome.stack ?? StackTrace.current);
  }
  return outcome.value as T;
}

Future<void> _writeCommand(
  String directory, {
  required String name,
  required String description,
  required String body,
  String? argumentHint,
}) async {
  await Directory(directory).create(recursive: true);
  await File(p.join(directory, '$name.md')).writeAsString(
    '---\n'
    'description: $description\n'
    '${argumentHint == null ? '' : 'argument-hint: $argumentHint\n'}'
    '---\n\n'
    '$body\n',
  );
}

/// Provider that answers every turn with one assistant message.
final class _TextProvider implements ModelGateway {
  @override
  String get id => 'text-fake';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    yield const ModelTextDelta('Done.');
    yield const ModelResponseCompleted(
      assistant: AssistantConversationItem(text: 'Done.'),
    );
  }
}

/// Holds a provider request open until daemon shutdown cancels its turn.
final class _ShutdownProvider implements ModelGateway {
  final Completer<void> started = Completer<void>();
  final Completer<void> cancelled = Completer<void>();

  @override
  String get id => 'shutdown-fake';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    if (!started.isCompleted) started.complete();
    cancellation.onCancel(() {
      if (!cancelled.isCompleted) cancelled.complete();
    });
    await cancelled.future;
    cancellation.throwIfCancelled();
  }
}

/// Waits until a session reports idle.
///
/// The `turn.completed` timeline event is broadcast before the session row
/// leaves the running state, so a mutation issued immediately after it can
/// still be rejected.
Future<SessionDto> _waitForSubagentStatus(
  TinestApi client,
  String parentId,
  SessionStatus status, {
  int attempts = 100,
}) async {
  for (var attempt = 0; attempt < attempts; attempt += 1) {
    final delegated = (await client.sessions.listSubagents(parentId))
        .where((session) => session.origin == SessionOrigin.delegated);
    for (final session in delegated) {
      if (session.status == status) return session;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('Timed out waiting for a subagent of $parentId at $status.');
}

/// Replays [sessionId]'s timeline until [type] appears on it.
///
/// A session's status and its timeline are written separately, so a status that
/// implies an event has happened does not prove the event is readable yet.
Future<TimelineEventDto> _waitForTimelineEvent(
  TinestApi client,
  String sessionId,
  String type, {
  int attempts = 100,
}) async {
  for (var attempt = 0; attempt < attempts; attempt += 1) {
    final events = await client.sessions.subscribeTimeline(sessionId);
    for (final event in events) {
      if (event.type == type) return event;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('Timed out waiting for "$type" on session $sessionId.');
}

Future<void> _selectTinestTools(
  TinestClient client,
  List<String> contributionIds,
) async {
  final definition = (await client.listAgentDefinitions()).singleWhere(
    (item) => item.id == 'tinest',
  );
  await client.updateAgentDefinition(
    definition.copyWith(
      toolIds: <String>{
        ...definition.toolIds,
        ...contributionIds,
      }.toList(growable: false),
    ),
    expectedContentHash: definition.contentHash,
  );
}

Future<void> _waitForIdleSession(
  TinestApi client,
  String worktreeId,
  String sessionId, {
  int attempts = 50,
}) async {
  for (var attempt = 0; attempt < attempts; attempt += 1) {
    final session = (await client.sessions.listSessions(worktreeId: worktreeId))
        .singleWhere((item) => item.id == sessionId);
    if (session.status != SessionStatus.running) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('Timed out waiting for $sessionId to leave running.');
}

Future<void> _runGit(String workingDirectory, List<String> arguments) async {
  final result = await Process.run(
    'git',
    arguments,
    workingDirectory: workingDirectory,
  );
  if (result.exitCode != 0) {
    throw TestFailure('git ${arguments.join(' ')} failed: ${result.stderr}');
  }
}

Future<void> _waitForAuthStatus(
  TinestApi client,
  String attemptId,
  ProviderAuthAttemptStatus status,
) async {
  // 50 attempts at 10ms allowed half a second for an entire OAuth round trip.
  for (var attempt = 0; attempt < 100; attempt += 1) {
    final current = await client.providers.providerAuthStatus(attemptId);
    if (current.status == status) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw TestFailure('Timed out waiting for OAuth status ${status.name}.');
}

final class _IntegrationOAuthGateway implements ProviderOAuthGateway {
  final List<_IntegrationOAuthSession> sessions = <_IntegrationOAuthSession>[];

  @override
  Future<OAuthCredential> refresh(OAuthCredential credential) async =>
      credential;

  @override
  Future<ProviderOAuthSession> start(AgentProviderAuthFlow flow) async {
    final session = _IntegrationOAuthSession(flow);
    sessions.add(session);
    return session;
  }
}

final class _IntegrationOAuthSession implements ProviderOAuthSession {
  new(this.flow);

  final AgentProviderAuthFlow flow;
  final Completer<OAuthCredential> completer = Completer<OAuthCredential>();
  bool cancelled = false;

  @override
  String get authorizationUrl => 'https://auth.example/${flow.name}';

  @override
  Future<OAuthCredential> get completion => completer.future;

  @override
  DateTime get expiresAt =>
      DateTime.now().toUtc().add(const Duration(minutes: 15));

  @override
  String? get instructions => 'Complete the test authorization.';

  @override
  String? get userCode =>
      flow == AgentProviderAuthFlow.oauthDevice ? 'TEST-CODE' : null;

  @override
  Future<void> cancel() async {
    cancelled = true;
  }
}

final class _StaticDiscovery implements ProviderModelDiscovery {
  const new(this.modelIds);

  final List<String> modelIds;

  @override
  Future<List<String>> fetchModelIds(
    ProviderEndpoint endpoint,
    ProviderCredential? credential,
  ) async => modelIds;
}

final class _CredentialAwareDiscovery implements ProviderModelDiscovery {
  const new();

  @override
  Future<List<String>> fetchModelIds(
    ProviderEndpoint endpoint,
    ProviderCredential? credential,
  ) async {
    if (credential case ApiKeyCredential(:final key) when key != 'valid-key') {
      throw const ProviderDiscoveryFailure(
        ProviderDiscoveryFailureKind.invalidCredential,
        'credential rejected by deterministic provider',
      );
    }
    return const <String>['gpt-test'];
  }
}

/// Locates the fake stdio MCP server, whichever directory the suite runs from.
///
/// melos runs the vertical slice from the workspace root while a package-level
/// `dart test` runs from the package, so neither path can be assumed.
String _fakeMcpServerPath() {
  const relative = <String>['test', 'support', 'fake_mcp_server_main.dart'];
  for (final root in <String>[
    Directory.current.path,
    p.join(Directory.current.path, 'packages', 'daemon'),
  ]) {
    final candidate = p.join(root, p.joinAll(relative));
    if (File(candidate).existsSync()) return candidate;
  }
  fail('Could not locate fake_mcp_server_main.dart from ${Directory.current}.');
}

/// Polls until [serverId] reports itself ready, or the event budget expires.
Future<McpServerStateDto> _awaitReadyMcpServer(
  TinestApi client,
  String serverId, {
  String? worktreeId,
}) async {
  final deadline = DateTime.now().add(_eventTimeout);
  while (DateTime.now().isBefore(deadline)) {
    final servers = await client.mcp.listMcpServers(worktreeId: worktreeId);
    for (final server in servers) {
      if (server.config.id != serverId) continue;
      if (server.status == McpServerStatus.ready) return server;
      if (server.status == McpServerStatus.failed) {
        // The server's own output is what explains a platform-specific
        // launch failure, so report it rather than just the summary.
        fail(
          'MCP server "$serverId" failed: ${server.error}\n'
          'diagnostics: ${server.diagnostics.join('\n')}',
        );
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  fail('MCP server "$serverId" never became ready.');
}

class _EchoingMcpProvider implements ModelGateway {
  @override
  String get id => 'fake';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    final searchResult = request.history
        .whereType<ToolResultConversationItem>()
        .where((item) => item.callId == 'mcp-search-call')
        .map((item) => item.output)
        .firstOrNull;
    final hasEchoResult = request.history
        .whereType<ToolResultConversationItem>()
        .any((item) => item.callId == 'echo-call');
    if (searchResult == null) {
      expect(
        request.tools.map((tool) => tool.name),
        allOf(contains('tool_search_mcp'), isNot(contains('mcp__fake__echo'))),
      );
      const arguments = <String, dynamic>{'query': 'echo', 'limit': 8};
      yield const ModelDeferredSearchCall(
        callId: 'mcp-search-call',
        name: 'tool_search_mcp',
        arguments: arguments,
      );
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.deferredSearch(
              callId: 'mcp-search-call',
              name: 'tool_search_mcp',
              arguments: arguments,
            ),
          ],
        ),
      );
      return;
    }
    if (!hasEchoResult) {
      expect(searchResult, contains('mcp__fake__echo'));
      expect(
        request.tools.map((tool) => tool.name),
        contains('mcp__fake__echo'),
      );
      const arguments = <String, dynamic>{'value': 'through MCP'};
      yield const ModelFunctionCall(
        callId: 'echo-call',
        name: 'mcp__fake__echo',
        arguments: arguments,
      );
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.function(
              callId: 'echo-call',
              name: 'mcp__fake__echo',
              arguments: arguments,
            ),
          ],
        ),
      );
      return;
    }
    yield const ModelTextDelta('Echoed.');
    yield const ModelResponseCompleted(
      assistant: AssistantConversationItem(text: 'Echoed.'),
    );
  }
}

class _PatchProvider implements ModelGateway {
  var _round = 0;

  @override
  String get id => 'fake';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    if (_round++ == 0) {
      const patch =
          '*** Begin Patch\n'
          '*** Add File: result.txt\n'
          '+done\n'
          '*** End Patch';
      yield const ModelReasoningDelta('Planning the patch.');
      yield const ModelFunctionCall(
        callId: 'patch-call',
        name: 'apply_patch',
        arguments: <String, dynamic>{'patch': patch},
      );
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.function(
              callId: 'patch-call',
              name: 'apply_patch',
              arguments: <String, dynamic>{'patch': patch},
            ),
          ],
        ),
      );
      return;
    }
    yield const ModelReasoningDelta('Checking the patch result.');
    yield const ModelTextDelta('Created result.txt');
    yield const ModelResponseCompleted(
      assistant: AssistantConversationItem(text: 'Created result.txt'),
    );
  }
}

class _SleepProvider implements ModelGateway {
  /// Completes once the sleep call has been issued.
  final Completer<void> sleeping = Completer<void>();

  /// Completes with the outcome the sleep tool reported.
  final Completer<String> outcome = Completer<String>();

  var _round = 0;

  @override
  String get id => 'sleep-fake';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    if (_round++ == 0) {
      const arguments = <String, dynamic>{'duration_ms': 300000};
      yield const ModelFunctionCall(
        callId: 'sleep-call',
        name: 'clock__sleep',
        arguments: arguments,
      );
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.function(
              callId: 'sleep-call',
              name: 'clock__sleep',
              arguments: arguments,
            ),
          ],
        ),
      );
      if (!sleeping.isCompleted) sleeping.complete();
      return;
    }
    if (!outcome.isCompleted) {
      final result = request.history
          .whereType<ToolResultConversationItem>()
          .firstWhere((item) => item.callId == 'sleep-call')
          .output;
      outcome.complete(
        result.contains('interrupted') ? 'interrupted' : 'completed',
      );
    }
    yield const ModelTextDelta('Done.');
    yield const ModelResponseCompleted(
      assistant: AssistantConversationItem(text: 'Done.'),
    );
  }
}

class _AskingProvider implements ModelGateway {
  var _round = 0;

  @override
  String get id => 'fake';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    if (_round++ == 0) {
      const arguments = <String, dynamic>{
        'questions': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'store',
            'header': 'Storage',
            'question': 'Which store should the cache use?',
            'options': <Map<String, dynamic>>[
              <String, dynamic>{
                'label': 'SQLite',
                'description': 'Durable and already a dependency.',
              },
              <String, dynamic>{
                'label': 'In memory',
                'description': 'Fastest, lost on restart.',
              },
            ],
          },
        ],
      };
      yield const ModelFunctionCall(
        callId: 'ask-call',
        name: 'request_user_input',
        arguments: arguments,
      );
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.function(
              callId: 'ask-call',
              name: 'request_user_input',
              arguments: arguments,
            ),
          ],
        ),
      );
      return;
    }
    final answer = request.history
        .whereType<ToolResultConversationItem>()
        .firstWhere((item) => item.callId == 'ask-call')
        .output;
    yield ModelTextDelta('Using $answer');
    yield ModelResponseCompleted(
      assistant: AssistantConversationItem(text: 'Using $answer'),
    );
  }
}

final class _AttachmentProvider implements ModelGateway {
  final Completer<ModelRequest> firstRequest = Completer<ModelRequest>();

  @override
  String get id => 'attachment-fake';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    if (!firstRequest.isCompleted) firstRequest.complete(request);
    final hasToolResult = request.history.any(
      (item) => item is ToolResultConversationItem,
    );
    if (!hasToolResult) {
      const arguments = <String, dynamic>{'path': 'agent-result.txt'};
      yield const ModelFunctionCall(
        callId: 'attach-call',
        name: 'attach_file',
        arguments: arguments,
      );
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.function(
              callId: 'attach-call',
              name: 'attach_file',
              arguments: arguments,
            ),
          ],
        ),
      );
      return;
    }
    yield const ModelResponseCompleted(
      assistant: AssistantConversationItem(text: 'Attached.'),
    );
  }
}

class _ExecProvider implements ModelGateway {
  new({required this.tty});

  /// Whether the command is asked for a pseudo-terminal or plain pipes.
  final bool tty;

  /// Completes with the shell's output once stdin has been echoed back.
  final Completer<String> echoed = Completer<String>();

  var _round = 0;
  int? _sessionId;

  int get round => _round;

  @override
  String get id => 'exec-fake';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    Map<String, dynamic> resultFor(String callId) => Map<String, dynamic>.from(
      jsonDecode(
        request.history
            .whereType<ToolResultConversationItem>()
            .firstWhere((item) => item.callId == callId)
            .output,
      ) as Map,
    );

    if (_round++ == 0) {
      // `cat` keeps running with no arguments, so the session survives the
      // call and the next one can write into it.
      final arguments = <String, dynamic>{
        'cmd': 'cat',
        'workdir': null,
        'tty': tty,
        'yield_time_ms': 300,
        'max_output_tokens': null,
      };
      yield ModelFunctionCall(
        callId: 'exec-call',
        name: 'exec_command',
        arguments: arguments,
      );
      yield ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.function(
              callId: 'exec-call',
              name: 'exec_command',
              arguments: arguments,
            ),
          ],
        ),
      );
      return;
    }
    if (_round == 2) {
      _sessionId = resultFor('exec-call')['session_id'] as int?;
      final arguments = <String, dynamic>{
        'session_id': _sessionId,
        'chars': 'tinyrack-exec-probe\n',
        'yield_time_ms': 1000,
        'max_output_tokens': null,
      };
      yield ModelFunctionCall(
        callId: 'stdin-call',
        name: 'write_stdin',
        arguments: arguments,
      );
      yield ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.function(
              callId: 'stdin-call',
              name: 'write_stdin',
              arguments: arguments,
            ),
          ],
        ),
      );
      return;
    }
    if (!echoed.isCompleted) {
      echoed.complete(resultFor('stdin-call')['output'] as String);
    }
    yield const ModelTextDelta('Done.');
    yield const ModelResponseCompleted(
      assistant: AssistantConversationItem(text: 'Done.'),
    );
  }
}

final class _ViewImageProvider implements ModelGateway {
  /// The request that carried the image back into the model's context.
  final Completer<ModelRequest> secondRequest = Completer<ModelRequest>();

  @override
  String get id => 'view-image-fake';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    final viewed = request.history.whereType<ToolResultConversationItem>().any(
      (item) => item.callId == 'view-call',
    );
    if (!viewed) {
      const arguments = <String, dynamic>{'path': 'shot.png', 'detail': 'high'};
      yield const ModelFunctionCall(
        callId: 'view-call',
        name: 'view_image',
        arguments: arguments,
      );
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.function(
              callId: 'view-call',
              name: 'view_image',
              arguments: arguments,
            ),
          ],
        ),
      );
      return;
    }
    if (!secondRequest.isCompleted) secondRequest.complete(request);
    yield const ModelTextDelta('I can see it.');
    yield const ModelResponseCompleted(
      assistant: AssistantConversationItem(text: 'I can see it.'),
    );
  }
}

/// The two tool results the search vertical slice inspects.
final class _SearchResults {
  const new({
    required this.search,
    required this.glob,
    required this.searchIgnored,
    required this.globIgnored,
  });

  final Map<String, dynamic> search;
  final Map<String, dynamic> glob;
  final Map<String, dynamic> searchIgnored;
  final Map<String, dynamic> globIgnored;
}

final class _SearchProvider implements ModelGateway {
  /// Completes once both tools have answered.
  final Completer<_SearchResults> results = Completer<_SearchResults>();

  @override
  String get id => 'search-fake';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    Map<String, dynamic>? resultFor(String callId) {
      for (final item
          in request.history.whereType<ToolResultConversationItem>()) {
        if (item.callId == callId) {
          final structured = item.structuredContent;
          if (structured is! Map) {
            throw StateError(
              'Tool $callId returned no structured content: '
              'output=${item.output}, error=${item.isError}',
            );
          }
          return Map<String, dynamic>.from(structured);
        }
      }
      return null;
    }

    final search = resultFor('search-call');
    if (search == null) {
      const arguments = <String, dynamic>{'query': 'marker'};
      yield const ModelFunctionCall(
        callId: 'search-call',
        name: 'search_text',
        arguments: arguments,
      );
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.function(
              callId: 'search-call',
              name: 'search_text',
              arguments: arguments,
            ),
          ],
        ),
      );
      return;
    }
    final glob = resultFor('glob-call');
    if (glob == null) {
      const arguments = <String, dynamic>{'pattern': '**/*.dart'};
      yield const ModelFunctionCall(
        callId: 'glob-call',
        name: 'glob',
        arguments: arguments,
      );
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.function(
              callId: 'glob-call',
              name: 'glob',
              arguments: arguments,
            ),
          ],
        ),
      );
      return;
    }
    final searchIgnored = resultFor('search-ignored-call');
    if (searchIgnored == null) {
      const arguments = <String, dynamic>{
        'query': 'marker',
        'include_ignored': true,
      };
      yield const ModelFunctionCall(
        callId: 'search-ignored-call',
        name: 'search_text',
        arguments: arguments,
      );
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.function(
              callId: 'search-ignored-call',
              name: 'search_text',
              arguments: arguments,
            ),
          ],
        ),
      );
      return;
    }
    final globIgnored = resultFor('glob-ignored-call');
    if (globIgnored == null) {
      const arguments = <String, dynamic>{
        'pattern': '**/*.dart',
        'include_ignored': true,
      };
      yield const ModelFunctionCall(
        callId: 'glob-ignored-call',
        name: 'glob',
        arguments: arguments,
      );
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.function(
              callId: 'glob-ignored-call',
              name: 'glob',
              arguments: arguments,
            ),
          ],
        ),
      );
      return;
    }
    if (!results.isCompleted) {
      results.complete(
        _SearchResults(
          search: search,
          glob: glob,
          searchIgnored: searchIgnored,
          globIgnored: globIgnored,
        ),
      );
    }
    yield const ModelTextDelta('Found it.');
    yield const ModelResponseCompleted(
      assistant: AssistantConversationItem(text: 'Found it.'),
    );
  }
}

final class _CollaboratingProvider implements ModelGateway {
  new({this.agentType = 'reviewer'});

  /// The `agent_type` the scripted root passes to `spawn_agent`.
  final String agentType;

  /// Every request the daemon sent, for envelope assertions.
  final List<ModelRequest> requests = <ModelRequest>[];

  static List<ModelEvent> _toolCall(
    String callId,
    String name,
    Map<String, dynamic> arguments,
  ) => <ModelEvent>[
    ModelFunctionCall(callId: callId, name: name, arguments: arguments),
    ModelResponseCompleted(
      assistant: AssistantConversationItem(
        text: '',
        toolCalls: <ConversationToolCall>[
          ConversationToolCall.function(
            callId: callId,
            name: name,
            arguments: arguments,
          ),
        ],
      ),
    ),
  ];

  @override
  String get id => 'collab-fake';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    cancellation.throwIfCancelled();
    requests.add(request);
    final userTexts = request.history
        .whereType<UserConversationItem>()
        .map((item) => item.text)
        .toList(growable: false);
    final isSubagent = userTexts.any(
      (text) => text.startsWith('Message Type: NEW_TASK'),
    );
    final hasToolResult = request.history.any(
      (item) => item is ToolResultConversationItem,
    );
    if (isSubagent) {
      if (!hasToolResult) {
        const patch =
            '*** Begin Patch\n'
            '*** Add File: forbidden.txt\n'
            '+forbidden\n'
            '*** End Patch';
        yield const ModelFunctionCall(
          callId: 'write-call',
          name: 'apply_patch',
          arguments: <String, dynamic>{'patch': patch},
        );
        yield const ModelResponseCompleted(
          assistant: AssistantConversationItem(
            text: '',
            toolCalls: <ConversationToolCall>[
              ConversationToolCall.function(
                callId: 'write-call',
                name: 'apply_patch',
                arguments: <String, dynamic>{'patch': patch},
              ),
            ],
          ),
        );
        return;
      }
      yield const ModelTextDelta('Review completed.');
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(text: 'Review completed.'),
      );
      return;
    }
    if (!hasToolResult &&
        request.tools.any((tool) => tool.name == 'spawn_agent')) {
      yield* Stream<ModelEvent>.fromIterable(
        _toolCall('spawn-call', 'spawn_agent', <String, dynamic>{
          'task_name': 'review_task',
          'message': 'Review without changing files.',
          'agent_type': agentType,
          'fork_turns': 'none',
        }),
      );
      return;
    }
    yield const ModelTextDelta('Parent completed.');
    yield const ModelResponseCompleted(
      assistant: AssistantConversationItem(text: 'Parent completed.'),
    );
  }
}

/// Scripts a parent that spawns a subagent and then blocks in `wait_agent`.
///
/// The child answers while the parent is still inside its own turn, which is
/// where a wait that reports nothing but an outcome leaves the parent unable
/// to read what it waited for.
final class _WaitingCollaboratingProvider implements ModelGateway {
  /// Every `wait_agent` tool result the parent was handed back.
  final List<String> waitOutputs = <String>[];

  @override
  String get id => 'collab-wait-fake';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    cancellation.throwIfCancelled();
    final isSubagent = request.history.whereType<UserConversationItem>().any(
      (item) => item.text.startsWith('Message Type: NEW_TASK'),
    );
    if (isSubagent) {
      yield const ModelTextDelta('Review completed.');
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(text: 'Review completed.'),
      );
      return;
    }
    final results = request.history
        .whereType<ToolResultConversationItem>()
        .toList(growable: false);
    if (results.isEmpty) {
      yield* Stream<ModelEvent>.fromIterable(
        _CollaboratingProvider._toolCall(
          'spawn-call',
          'spawn_agent',
          <String, dynamic>{
            'task_name': 'review_task',
            'message': 'Review this workspace.',
            'agent_type': 'reviewer',
            'fork_turns': 'none',
          },
        ),
      );
      return;
    }
    final waited = results
        .where((item) => item.callId == 'wait-call')
        .toList(growable: false);
    if (waited.isEmpty) {
      yield* Stream<ModelEvent>.fromIterable(
        _CollaboratingProvider._toolCall(
          'wait-call',
          'wait_agent',
          <String, dynamic>{
            // Only a backstop: the child's answer is what ends this wait. A
            // deadline short enough to expire first would make the assertion
            // depend on how fast the host is.
            'timeout_ms': 60000,
          },
        ),
      );
      return;
    }
    waitOutputs.addAll(waited.map((item) => item.output));
    yield const ModelTextDelta('Parent completed.');
    yield const ModelResponseCompleted(
      assistant: AssistantConversationItem(text: 'Parent completed.'),
    );
  }
}

Future<void> _writeSkill(
  String directory, {
  required String description,
  required String body,
}) async {
  await Directory(directory).create(recursive: true);
  await File(p.join(directory, 'SKILL.md')).writeAsString(
    '---\n'
    'name: ${p.basename(directory)}\n'
    'description: $description\n'
    '---\n\n'
    '$body\n',
  );
}

/// Loads one skill through the `skill` tool, then finishes the turn.
final class _SkillProvider implements ModelGateway {
  @override
  String get id => 'skill-fake';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    cancellation.throwIfCancelled();
    final instructions = request.blocks
        .map((block) => block.content)
        .join('\n\n');
    expect(instructions, contains('## Implicit skills'));
    expect(instructions, contains('Before writing code'));
    expect(instructions, isNot(contains('Project instructions.')));
    String? outputFor(String callId) {
      for (final item
          in request.history.whereType<ToolResultConversationItem>()) {
        if (item.callId == callId) return item.output;
      }
      return null;
    }

    Stream<ModelEvent> call(
      String callId,
      String name,
      Map<String, dynamic> arguments,
    ) async* {
      yield ModelFunctionCall(callId: callId, name: name, arguments: arguments);
      yield ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.function(
              callId: callId,
              name: name,
              arguments: arguments,
            ),
          ],
        ),
      );
    }

    final listed = outputFor('list-call');
    if (listed == null) {
      // The prompt no longer names the skills, only how many there are and
      // which tool finds them.
      yield* call('list-call', 'list_skills', const <String, dynamic>{});
      return;
    }
    if (outputFor('skill-call') == null) {
      // The turn catalog is the same effective projection as the RPC catalog;
      // read its typed Lua tool result rather than parsing display text.
      final page =
          request.history
                  .whereType<ToolResultConversationItem>()
                  .firstWhere((item) => item.callId == 'list-call')
                  .structuredContent!
              as Map<String, dynamic>;
      final names = (page['skills']! as List)
          .map((skill) => (skill! as Map<String, dynamic>)['name'])
          .toList();
      expect(names, contains('shared'));
      expect(names, contains('commit'));
      expect(page['total'], names.length);
      yield* call('skill-call', 'skill', <String, dynamic>{'name': 'shared'});
      return;
    }
    yield const ModelTextDelta('Loaded the skill.');
    yield const ModelResponseCompleted(
      assistant: AssistantConversationItem(text: 'Loaded the skill.'),
    );
  }
}
