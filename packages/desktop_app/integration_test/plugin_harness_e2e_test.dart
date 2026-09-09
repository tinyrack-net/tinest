@Tags(<String>[
  'feature_test__plugin_authoring__verticalSlice',
  'feature_test__plugin_authoring__e2e',
  'feature_test__plugin_authoring__platformSmoke',
])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agent/agent.dart';
import 'package:app/testing/features/plugins/presentation/plugin_ui_document_view.dart';
import 'package:client/client.dart';
import 'package:daemon/daemon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import 'support/pump_until.dart';
import 'support/temporary_directory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'app-data plugin owns a zero-tool harness, state, continuation, UI, LKG, '
    'permissions, and restart recovery',
    (tester) async {
      expect(
        _stringWiringViolations(_harnessSource),
        isEmpty,
        reason: 'The E2E plugin must connect executable behavior by SDK refs.',
      );
      await tester.binding.setSurfaceSize(const Size(1100, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final home = await Directory.systemTemp.createTemp(
        'tinest-plugin-harness-e2e-',
      );
      final workspace = await Directory.systemTemp.createTemp(
        'tinest-plugin-workspace-e2e-',
      );
      const token = 'plugin-e2e-token-0123456789abcdef0123456789';
      final provider = _PluginHarnessProvider();
      final config = DaemonConfig(
        homeDirectory: home.path,
        configDirectory: home.path,
        osHomeDirectory: home.path,
        port: 0,
        bearerToken: token,
        useEnvironmentCredentials: false,
      );
      var handle = await DaemonApplication.start(
        config,
        provider: provider,
        providerCatalogMetadataSource: const _NoNetworkCatalogMetadataSource(),
      );
      var client = await _connect(handle, token);
      var running = true;
      addTearDown(() async {
        await client.close();
        if (running) await handle.stop();
        await deleteTemporaryDirectory(home);
        await deleteTemporaryDirectory(workspace);
      });

      final catalog = await client.workspaces.registerWorkspace(
        workspaceId: 'plugin-workspace',
        checkoutId: 'plugin-checkout',
        rootPath: workspace.path,
        name: 'Plugin workspace',
      );
      final worktreeId = catalog.worktrees
          .singleWhere((item) => item.id == 'plugin-checkout')
          .id;
      final model = (await client.providers.listProviderModels('openai'))
          .firstWhere(
            (item) =>
                item.capabilities.streaming == CapabilitySupport.supported,
          );

      await _awaitPluginChange(
        client,
        'the scaffolded plugin to be reported',
        apply: () =>
            client.plugins.scaffoldPlugin('acme.harness', 'Harness E2E'),
      );
      final authoring = await client.plugins.getPluginAuthoringEnvironment(
        'acme.harness',
      );
      expect(authoring.synchronized, isTrue);
      expect(authoring.sdkAbiHash, isNotEmpty);
      expect(File(authoring.configurationPath).existsSync(), isTrue);
      expect(Directory(authoring.sdkLibraryPath).existsSync(), isTrue);
      final synchronized = await client.plugins.syncPluginAuthoringEnvironment(
        'acme.harness',
      );
      expect(synchronized.synchronized, isTrue);
      expect(synchronized.sdkAbiHash, authoring.sdkAbiHash);
      final pluginDirectory = Directory(
        p.join(home.path, 'v5', 'plugins', 'acme.harness'),
      );
      final mainFile = File(p.join(pluginDirectory.path, 'main.lua'));
      final manifestFile = File(p.join(pluginDirectory.path, 'PLUGIN.md'));
      await _awaitPluginChange(
        client,
        'the harness source edits to be reported',
        apply: () async {
          await manifestFile.writeAsString(_harnessManifest, flush: true);
          await mainFile.writeAsString(_harnessSource, flush: true);
        },
        reapply: true,
      );
      final typedAuthoring = await client.plugins
          .syncPluginAuthoringEnvironment('acme.harness');
      expect(typedAuthoring.synchronized, isTrue);
      final configuration = jsonDecode(
        await File(typedAuthoring.configurationPath).readAsString(),
      ) as Map<String, dynamic>;
      final libraries = (configuration['workspace.library'] as List<dynamic>)
          .cast<String>();
      final typeDefinition = File(p.join(libraries.last, 'types.d.lua'));
      expect(typeDefinition.existsSync(), isTrue);
      expect(
        await typeDefinition.readAsString(),
        allOf(<Matcher>[
          contains('---@class (exact) tinest_plugin_acme_harness.StateValue'),
          contains(
            '---@class (exact) tinest_plugin_acme_harness.RememberInput',
          ),
          contains(
            '---@class (exact) tinest_plugin_acme_harness.ScheduledPayload',
          ),
        ]),
      );

      final validated = await client.plugins.validatePlugin('acme.harness');
      expect(validated.contributions, isNotEmpty);
      const agentId = 'plugin-e2e-agent';
      for (final capability in validated.requestedCapabilities) {
        await client.plugins.grantPluginCapability(
          AgentPluginGrantDto(
            agentId: agentId,
            pluginId: 'acme.harness',
            capability: capability,
          ),
        );
      }
      final active = await client.plugins.reloadPlugin('acme.harness', agentId);
      expect(active.isStale, isFalse);
      final activeContentHash = active.revision!.contentHash;
      final activeExecutionRevisionHash =
          active.revision!.executionRevisionHash;

      var definition = await client.agents.createAgentDefinition(
        agentId,
        const AgentDefinitionDto(
          version: 5,
          id: agentId,
          name: 'Plugin harness E2E',
          description: 'Exercises the public plugin harness.',
          mode: AgentMode.primary,
          model: AgentModelSelectionDto(source: AgentModelSource.session),
          driverId: 'acme.harness/driver',
          extensionIds: <String>['acme.harness'],
          toolIds: <String>[],
          pluginSettings: <String, Map<String, dynamic>>{
            'acme.harness': <String, dynamic>{'label': 'configured'},
          },
          callableAgentIds: <String>[],
          prompt: 'The Agent body is driver-owned prompt data.',
          contentHash: '',
          sourcePath: '',
        ),
      );
      final session = await client.sessions.createSession(
        id: 'plugin-zero-tools',
        worktreeId: worktreeId,
        title: 'Zero tools',
        agentDefinitionId: agentId,
        model: ModelSelectionDto(modelId: model.id),
      );
      await _runTurn(
        client,
        sessionId: session.id,
        turnId: 'zero-tool-turn',
        prompt: 'zero tools',
      );
      expect(provider.requests, hasLength(1));
      expect(provider.requests.single.tools, isEmpty);
      expect(
        provider.requests.single.blocks.map((block) => block.content),
        contains('The Agent body is driver-owned prompt data.'),
      );

      definition = await client.agents.updateAgentDefinition(
        definition.copyWith(toolIds: const <String>['acme.harness/remember']),
        expectedContentHash: definition.contentHash,
      );
      expect(
        (await client.agents.getAgentDefinition(agentId)).toolIds,
        const <String>['acme.harness/remember'],
      );
      final completedTurns = client.sessions.timelineEvents
          .where(
            (event) =>
                event.sessionId == session.id && event.type == 'turn.completed',
          )
          .take(2)
          .toList()
          .timeout(const Duration(seconds: 30));
      await client.sessions.startTurn(
        sessionId: session.id,
        turnId: 'state-turn',
        prompt: 'persist this value',
      );
      expect(await completedTurns, hasLength(2));
      expect(
        provider.requests.last.tools.map((tool) => tool.name),
        contains('remember'),
      );
      await _waitFor(() async {
        final status = await client.plugins.renderPluginUi(
          agentId: agentId,
          pluginId: 'acme.harness',
          contributionId: 'acme.harness/status',
          slot: PluginUiSlot.timeline,
          context: <String, dynamic>{'sessionId': session.id},
        );
        return status.root.toString().contains('continued');
      }, description: 'the serialized continuation after the saved Agent turn');

      definition = await client.agents.updateAgentDefinition(
        definition.copyWith(toolIds: const <String>['acme.harness/wait']),
        expectedContentHash: definition.contentHash,
      );
      final cancelled = client.sessions.timelineEvents
          .firstWhere(
            (event) =>
                event.sessionId == session.id &&
                event.turnId == 'revoke-turn' &&
                event.type == 'turn.cancelled',
          )
          .timeout(const Duration(seconds: 10));
      await client.sessions.startTurn(
        sessionId: session.id,
        turnId: 'revoke-turn',
        prompt: 'wait for revoke',
      );
      await _waitFor(() async {
        final waiting = await client.plugins.renderPluginUi(
          agentId: agentId,
          pluginId: 'acme.harness',
          contributionId: 'acme.harness/status',
          slot: PluginUiSlot.timeline,
          context: <String, dynamic>{'sessionId': session.id},
        );
        return waiting.root.toString().contains('waiting:revoke');
      }, description: 'the brokered sleep primitive to start');
      await client.plugins.revokePluginCapability(
        const AgentPluginGrantDto(
          agentId: agentId,
          pluginId: 'acme.harness',
          capability: 'clock.sleep',
        ),
      );
      await cancelled;

      final document = await client.plugins.renderPluginUi(
        agentId: agentId,
        pluginId: 'acme.harness',
        contributionId: 'acme.harness/status',
        slot: PluginUiSlot.timeline,
        context: <String, dynamic>{
          'sessionId': session.id,
          'workspaceId': 'plugin-workspace',
        },
      );
      expect(document.root.toString(), contains('continued'));
      final actionResult = await client.plugins.dispatchPluginUiAction(
        agentId: agentId,
        pluginId: 'acme.harness',
        action: PluginUiActionDto(
          documentId: document.id,
          actionId: 'acme.harness/refresh',
        ),
      );
      expect(actionResult.revisionHash, activeExecutionRevisionHash);
      expect(actionResult.root.toString(), contains('continued'));

      await expectLater(
        client.plugins.renderPluginUi(
          agentId: agentId,
          pluginId: 'acme.harness',
          contributionId: 'acme.harness/invalid',
          slot: PluginUiSlot.timeline,
          context: <String, dynamic>{'sessionId': session.id},
        ),
        throwsA(
          isA<TinestClientException>()
              .having(
                (error) => error.message,
                'message',
                contains('must return a Tinest UI node'),
              )
              .having(
                (error) => error.code,
                'code',
                RpcErrorCodes.pluginUiRejected,
              ),
        ),
      );

      final invalidDocument = PluginUiDocumentDto(
        id: 'host-owned-invalid-snapshot',
        pluginId: 'acme.harness',
        revisionHash: activeExecutionRevisionHash,
        slot: PluginUiSlot.timeline,
        root: const <String, dynamic>{
          'type': 'remote-widget',
          'source': 'untrusted',
        },
      );
      expect(invalidDocument.root['type'], 'remote-widget');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          theme: TinyrackTheme.light(),
          home: Scaffold(
            body: PluginUiDocumentView(
              document: invalidDocument,
              invalidDocumentLabel: 'Unsupported plugin interface',
              invalidDocumentDescription: 'The host kept the raw document.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TRCollapsible), findsOneWidget);
      expect(find.text('Unsupported plugin interface'), findsOneWidget);

      final historicalTimeline = await client.sessions.subscribeTimeline(
        session.id,
      );
      final historicalDocument = PluginUiDocumentDto.fromJson(
        Map<String, dynamic>.from(
          historicalTimeline
                  .lastWhere((event) => event.type == 'plugin.ui')
                  .data['document']!
              as Map,
        ),
      );
      expect(historicalDocument.revisionHash, activeExecutionRevisionHash);

      await _awaitPluginChange(
        client,
        'the invalid source edit to be reported',
        apply: () =>
            mainFile.writeAsString('this is not valid Lua', flush: true),
        reapply: true,
      );
      final held = await client.plugins.reloadPlugin('acme.harness', agentId);
      expect(held.isStale, isTrue);
      expect(held.revision!.contentHash, activeContentHash);
      expect(
        held.diagnostics.map((item) => item.code),
        contains('invalid_plugin_definition'),
      );
      expect(
        (await client.sessions.subscribeTimeline(session.id))
            .lastWhere((event) => event.type == 'plugin.ui')
            .data['document'],
        historicalDocument.toJson(),
      );

      // The revoke above intentionally removed one manifest capability. A
      // repaired revision cannot become active until the Agent approves that
      // capability again; otherwise the LKG expansion guard must keep it stale.
      await client.plugins.grantPluginCapability(
        const AgentPluginGrantDto(
          agentId: agentId,
          pluginId: 'acme.harness',
          capability: 'clock.sleep',
        ),
      );

      await _awaitPluginChange(
        client,
        'the repaired source edit to be reported',
        apply: () => mainFile.writeAsString(
          '$_harnessSource\n-- repaired revision\n',
          flush: true,
        ),
        reapply: true,
      );
      final repaired = await client.plugins.reloadPlugin(
        'acme.harness',
        agentId,
      );
      expect(repaired.isStale, isFalse);
      expect(repaired.revision!.contentHash, isNot(activeContentHash));

      await _installIncompatiblePlugin(client, home);
      const incompatibleAgentId = 'plugin-incompatible-agent';
      await client.plugins.grantPluginCapability(
        const AgentPluginGrantDto(
          agentId: incompatibleAgentId,
          pluginId: 'acme.incompatible',
          capability: 'model.call',
        ),
      );
      await client.plugins.reloadPlugin(
        'acme.incompatible',
        incompatibleAgentId,
      );
      await client.agents.createAgentDefinition(
        incompatibleAgentId,
        const AgentDefinitionDto(
          version: 5,
          id: incompatibleAgentId,
          name: 'Incompatible driver',
          description: '',
          mode: AgentMode.primary,
          model: AgentModelSelectionDto(source: AgentModelSource.session),
          driverId: 'acme.incompatible/driver',
          extensionIds: <String>[],
          toolIds: <String>[],
          pluginSettings: <String, Map<String, dynamic>>{},
          callableAgentIds: <String>[],
          prompt: '',
          contentHash: '',
          sourcePath: '',
        ),
      );
      final incompatibleSession = await client.sessions.createSession(
        id: 'plugin-incompatible',
        worktreeId: worktreeId,
        title: 'Incompatible driver',
        agentDefinitionId: incompatibleAgentId,
        model: ModelSelectionDto(modelId: model.id),
      );
      final requestsBeforeFailure = provider.requests.length;
      await client.sessions.subscribeTimeline(incompatibleSession.id);
      final incompatibleFailure = client.sessions.timelineEvents
          .firstWhere(
            (event) =>
                event.sessionId == incompatibleSession.id &&
                event.turnId == 'incompatible-turn' &&
                event.type == 'turn.failed',
          )
          .timeout(const Duration(seconds: 10));
      await client.sessions.startTurn(
        sessionId: incompatibleSession.id,
        turnId: 'incompatible-turn',
        prompt: 'must not call model',
      );
      expect(
        (await incompatibleFailure).data.toString(),
        contains('role.tool'),
      );
      expect(provider.requests, hasLength(requestsBeforeFailure));

      definition = await client.agents.updateAgentDefinition(
        definition.copyWith(toolIds: const <String>[]),
        expectedContentHash: definition.contentHash,
      );
      await client.close();
      await handle.stop();
      running = false;
      handle = await DaemonApplication.start(
        config,
        provider: provider,
        providerCatalogMetadataSource: const _NoNetworkCatalogMetadataSource(),
      );
      running = true;
      client = await _connect(handle, token, clientId: 'plugin-e2e-restart');
      final restoredDefinition = await client.agents.getAgentDefinition(
        agentId,
      );
      expect(restoredDefinition.toolIds, isEmpty);
      final restoredUi = await client.plugins.renderPluginUi(
        agentId: agentId,
        pluginId: 'acme.harness',
        contributionId: 'acme.harness/status',
        slot: PluginUiSlot.timeline,
        context: <String, dynamic>{'sessionId': session.id},
      );
      expect(restoredUi.root.toString(), contains('continued'));
      expect(
        (await client.sessions.subscribeTimeline(session.id))
            .where((event) => event.type == 'plugin.ui'),
        isNotEmpty,
      );
      await _runTurn(
        client,
        sessionId: session.id,
        turnId: 'restart-zero-tool-turn',
        prompt: 'restart with zero tools',
      );
      expect(provider.requests.last.tools, isEmpty);

      final grantsBeforeRevoke = await client.plugins.listPluginGrants(agentId);
      expect(
        grantsBeforeRevoke.map((grant) => grant.capability),
        contains('state.read'),
      );
      await client.plugins.revokePluginCapability(
        const AgentPluginGrantDto(
          agentId: agentId,
          pluginId: 'acme.harness',
          capability: 'state.read',
        ),
      );
      await expectLater(
        client.plugins.renderPluginUi(
          agentId: agentId,
          pluginId: 'acme.harness',
          contributionId: 'acme.harness/status',
          slot: PluginUiSlot.timeline,
          context: <String, dynamic>{'sessionId': session.id},
        ),
        throwsA(anything),
      );
    },
    tags: const <String>[
      'feature_test__agent_harness__e2e',
      'feature_test__agent_harness__platformSmoke',
      'feature_scenario__agent_harness__custom_driver_zero_tools_restart__e2e',
      'feature_scenario__agent_harness__incompatible_model_blocked__e2e',
      'feature_test__plugin_management__verticalSlice',
      'feature_test__plugin_management__e2e',
      'feature_test__plugin_management__platformSmoke',
      // ignore: lines_longer_than_80_chars -- Static verifier IDs stay atomic.
      'feature_scenario__plugin_management__scaffold_detect_reload_lkg_restart__e2e',
      // ignore: lines_longer_than_80_chars -- Static verifier IDs stay atomic.
      'feature_scenario__plugin_authoring__scaffold_sdk_sync_reload_restart__e2e',
      'feature_test__plugin_runtime__e2e',
      'feature_test__plugin_runtime__platformSmoke',
      'feature_scenario__plugin_runtime__user_tool_state_and_continuation__e2e',
      'feature_test__plugin_permissions__e2e',
      'feature_test__plugin_permissions__platformSmoke',
      // ignore: lines_longer_than_80_chars -- Static verifier IDs stay atomic.
      'feature_scenario__plugin_permissions__agent_grant_revoke_live_primitive__e2e',
      'feature_test__plugin_ui__verticalSlice',
      'feature_test__plugin_ui__e2e',
      'feature_test__plugin_ui__platformSmoke',
      // ignore: lines_longer_than_80_chars -- Static verifier IDs stay atomic.
      'feature_scenario__plugin_ui__render_action_invalid_fallback_history__e2e',
    ],
  );

  testWidgets(
    'session atomically changes its selected model and provider controls',
    (tester) async {
      final home = await Directory.systemTemp.createTemp(
        'tinest-session-settings-e2e-',
      );
      final workspace = await Directory.systemTemp.createTemp(
        'tinest-session-settings-workspace-',
      );
      const token = 'settings-e2e-token-0123456789abcdef012345678';
      final handle = await DaemonApplication.start(
        DaemonConfig(
          homeDirectory: home.path,
          configDirectory: home.path,
          osHomeDirectory: home.path,
          port: 0,
          bearerToken: token,
          useEnvironmentCredentials: false,
        ),
        provider: _PluginHarnessProvider(),
        providerCatalogMetadataSource: const _NoNetworkCatalogMetadataSource(),
      );
      final client = await _connect(handle, token, clientId: 'settings-e2e');
      addTearDown(() async {
        await client.close();
        await handle.stop();
        await deleteTemporaryDirectory(home);
        await deleteTemporaryDirectory(workspace);
      });
      final catalog = await client.workspaces.registerWorkspace(
        workspaceId: 'settings-workspace',
        checkoutId: 'settings-checkout',
        rootPath: workspace.path,
        name: 'Settings workspace',
      );
      final models = (await client.providers.listProviderModels('openai'))
          .where(
            (model) => model.capabilities.controls.any(
              (control) =>
                  control.id == AgentModelControlIds.reasoningEffort &&
                  control.choices.any((choice) => choice.id == 'high'),
            ),
          )
          .take(2)
          .toList(growable: false);
      expect(models, hasLength(2));
      final session = await client.sessions.createSession(
        id: 'settings-session',
        worktreeId: catalog.worktrees.single.id,
        title: 'Settings lifecycle',
        agentDefinitionId: 'tinest',
        model: ModelSelectionDto(modelId: models.first.id),
      );
      final updateNotification = client.sessions.sessionUpdates
          .firstWhere(
            (candidate) =>
                candidate.id == session.id &&
                candidate.model?.modelId == models.last.id &&
                candidate.modelControls.containsKey(
                  AgentModelControlIds.reasoningEffort,
                ),
          )
          .timeout(const Duration(seconds: 10));
      final updated = await client.sessions.updateSettings(
        session.id,
        SessionSettingsPatchDto(
          hasModel: true,
          model: ModelSelectionDto(modelId: models.last.id),
          hasModelControls: true,
          modelControls: const <String, ModelControlValueDto>{
            AgentModelControlIds.reasoningEffort:
                ModelControlValueDto.stringValue(value: 'high'),
          },
        ),
      );
      expect(await updateNotification, updated);
      expect(updated.model?.modelId, models.last.id);
      expect(
        updated.modelControls[AgentModelControlIds.reasoningEffort],
        const ModelControlValueDto.stringValue(value: 'high'),
      );
      await tester.pumpWidget(MaterialApp(home: Text(updated.model!.modelId)));
      expect(find.text(models.last.id), findsOneWidget);
    },
    tags: const <String>[
      'feature_scenario__session_lifecycle__update_model_and_controls__e2e',
    ],
  );

  testWidgets(
    'goal plugin completes a scheduled turn and restores state after restart',
    (tester) async {
      final home = await Directory.systemTemp.createTemp('tinest-goal-e2e-');
      final workspace = await Directory.systemTemp.createTemp(
        'tinest-goal-workspace-e2e-',
      );
      const token = 'goal-e2e-token-0123456789abcdef012345678901';
      final provider = _GoalE2eProvider();
      final diagnostics = _RecordingRpcDiagnostics();
      final config = DaemonConfig(
        homeDirectory: home.path,
        configDirectory: home.path,
        osHomeDirectory: home.path,
        port: 0,
        bearerToken: token,
        useEnvironmentCredentials: false,
      );
      var handle = await DaemonApplication.start(
        config,
        options: DaemonHostOptions(
          provider: provider,
          providerCatalogMetadataSource:
              const _NoNetworkCatalogMetadataSource(),
          rpcDiagnostics: diagnostics,
        ),
      );
      var client = await _connect(handle, token, clientId: 'goal-e2e');
      var running = true;
      addTearDown(() async {
        await client.close();
        if (running) await handle.stop();
        await deleteTemporaryDirectory(home);
        await deleteTemporaryDirectory(workspace);
      });
      final catalog = await client.workspaces.registerWorkspace(
        workspaceId: 'goal-workspace',
        checkoutId: 'goal-checkout',
        rootPath: workspace.path,
        name: 'Goal workspace',
      );
      final model = (await client.providers.listProviderModels('openai'))
          .firstWhere(
            (item) =>
                item.capabilities.streaming == CapabilitySupport.supported &&
                item.capabilities.toolCalling == CapabilitySupport.supported,
          );
      const goalAgentId = 'goal-e2e-agent';
      await client.agents.createAgentDefinition(
        goalAgentId,
        const AgentDefinitionDto(
          version: 5,
          id: goalAgentId,
          name: 'Goal E2E',
          description: '',
          mode: AgentMode.primary,
          model: AgentModelSelectionDto(source: AgentModelSource.session),
          driverId: 'tinest.standard/driver',
          extensionIds: <String>['tinest.goal'],
          toolIds: <String>[
            'tinest.goal/create_goal',
            'tinest.goal/get_goal',
            'tinest.goal/update_goal',
          ],
          pluginSettings: <String, Map<String, dynamic>>{},
          callableAgentIds: <String>[],
          prompt: 'Complete the goal through the public Lua tools.',
          contentHash: '',
          sourcePath: '',
        ),
      );
      final session = await client.sessions.createSession(
        id: 'goal-e2e-session',
        worktreeId: catalog.worktrees.single.id,
        title: 'Goal E2E',
        agentDefinitionId: goalAgentId,
        model: ModelSelectionDto(modelId: model.id),
      );
      await client.sessions.startTurn(
        sessionId: session.id,
        turnId: 'goal-create-turn',
        prompt: 'Create and finish the migration goal.',
      );
      await _waitFor(() async {
        if (provider.requests.length < 4) return false;
        final document = await client.plugins.renderPluginUi(
          agentId: goalAgentId,
          pluginId: 'tinest.goal',
          contributionId: 'tinest.goal/goal_status',
          slot: PluginUiSlot.conversationStatus,
          context: <String, dynamic>{'sessionId': session.id},
        );
        return document.root['text'] == 'complete';
      }, description: 'scheduled goal continuation to complete');
      // The fourth provider request starts before the continuation's
      // after-turn lifecycle and durable turn update finish. Stopping the
      // daemon on the goal-state edge can therefore cancel that still-active
      // turn, especially on Linux. Wait for both the initiating turn and its
      // scheduled continuation to reach their durable terminal boundary.
      await _waitFor(
        () async =>
            (await client.sessions.subscribeTimeline(session.id))
                .where((event) => event.type == 'turn.completed')
                .length >=
            2,
        description: 'scheduled goal continuation turn to terminate',
      );
      expect(provider.requests, hasLength(4));
      final completedGoal = await client.plugins.renderPluginUi(
        agentId: goalAgentId,
        pluginId: 'tinest.goal',
        contributionId: 'tinest.goal/goal_status',
        slot: PluginUiSlot.conversationStatus,
        context: <String, dynamic>{'sessionId': session.id},
      );
      expect(completedGoal.root, containsPair('text', 'complete'));

      await client.close();
      await handle.stop();
      running = false;
      handle = await DaemonApplication.start(
        config,
        options: DaemonHostOptions(
          provider: provider,
          providerCatalogMetadataSource:
              const _NoNetworkCatalogMetadataSource(),
          rpcDiagnostics: diagnostics,
        ),
      );
      running = true;
      client = await _connect(handle, token, clientId: 'goal-e2e-restart');
      late final PluginUiDocumentDto restoredGoal;
      try {
        restoredGoal = await client.plugins.renderPluginUi(
          agentId: goalAgentId,
          pluginId: 'tinest.goal',
          contributionId: 'tinest.goal/goal_status',
          slot: PluginUiSlot.conversationStatus,
          context: <String, dynamic>{'sessionId': session.id},
        );
      } on TinestClientException catch (error) {
        fail(
          'Goal UI restart failed: ${error.details}; '
          'daemon=${diagnostics.errors.join(' | ')}',
        );
      }
      expect(restoredGoal.root, containsPair('text', 'complete'));
      expect(
        (await client.sessions.subscribeTimeline(session.id))
            .where((event) => event.type == 'tool.completed'),
        hasLength(2),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: TinyrackTheme.light(),
          home: Scaffold(
            body: PluginUiDocumentView(
              document: restoredGoal,
              invalidDocumentLabel: 'Unsupported plugin interface',
              invalidDocumentDescription: 'The host kept the raw document.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('complete'), findsOneWidget);
    },
    tags: const <String>[
      'feature_test__session_goal__e2e',
      'feature_scenario__session_goal__multi_turn_completion_reconnect__e2e',
    ],
  );
}

/// Applies a plugin mutation and waits until the daemon reports a change.
///
/// The subscription starts before [apply] so the change event cannot slip
/// between the mutation and the wait. When [reapply] is set the mutation is
/// repeated while no event arrives: the plugins watcher can gain its OS watch
/// on a freshly scaffolded directory only after the first write already
/// landed, and an idempotent rewrite converts that missed edge back into a
/// level. Reapplied mutations must write identical content.
Future<void> _awaitPluginChange(
  TinestApi client,
  String description, {
  required Future<void> Function() apply,
  bool reapply = false,
}) async {
  var observed = false;
  final subscription = client.plugins.pluginChanges.listen(
    (_) => observed = true,
  );
  try {
    await apply();
    const pollInterval = Duration(milliseconds: 100);
    const reapplyInterval = Duration(seconds: 5);
    var sinceApply = Duration.zero;
    for (
      var waited = Duration.zero;
      waited < e2eWaitBudget;
      waited += pollInterval
    ) {
      if (observed) return;
      if (reapply && sinceApply >= reapplyInterval) {
        await apply();
        sinceApply = Duration.zero;
      }
      await Future<void>.delayed(pollInterval);
      sinceApply += pollInterval;
    }
    throw TestFailure(
      'Timed out after ${e2eWaitBudget.inSeconds}s waiting for $description.',
    );
  } finally {
    await subscription.cancel();
  }
}

Future<TinestApi> _connect(
  DaemonHandle handle,
  String token, {
  String clientId = 'plugin-e2e',
}) => TinestClient.connect(
  endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
  credentials: DaemonCredentials(bearerToken: token),
  clientId: clientId,
  clientKind: 'integration-test',
);

Future<TimelineEventDto> _runTurn(
  TinestApi client, {
  required String sessionId,
  required String turnId,
  required String prompt,
}) async {
  // The daemon intentionally emits timeline notifications only after this
  // client has attached to the session. Attach before starting a potentially
  // synchronous test provider so the first terminal event cannot be missed.
  await client.sessions.subscribeTimeline(sessionId);
  final terminal = client.sessions.timelineEvents
      .firstWhere(
        (event) =>
            event.sessionId == sessionId &&
            event.turnId == turnId &&
            const <String>{
              'turn.completed',
              'turn.failed',
              'turn.cancelled',
            }.contains(event.type),
      )
      .timeout(const Duration(seconds: 30));
  await client.sessions.startTurn(
    sessionId: sessionId,
    turnId: turnId,
    prompt: prompt,
  );
  late final TimelineEventDto result;
  try {
    result = await terminal;
  } on TimeoutException {
    final timeline = await client.sessions.subscribeTimeline(sessionId);
    fail(
      'Turn $turnId did not terminate. Timeline: '
      '${timeline.map((event) => '${event.type}:${event.data}').join(' | ')}',
    );
  }
  if (result.type != 'turn.completed') {
    fail('Turn $turnId ended as ${result.type}: ${result.data}');
  }
  return result;
}

Future<void> _waitFor(
  Future<bool> Function() predicate, {
  required String description,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    if (await predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('Timed out waiting for $description.');
}

Future<void> _installIncompatiblePlugin(
  TinestApi client,
  Directory home,
) async {
  await client.plugins.scaffoldPlugin('acme.incompatible', 'Incompatible');
  final directory = p.join(home.path, 'v5', 'plugins', 'acme.incompatible');
  await File(p.join(directory, 'PLUGIN.md')).writeAsString('''
---
api: 5
id: acme.incompatible
version: 1.0.0
name: Incompatible
entrypoint: main.lua
capabilities:
  - model.call
---

Requires a capability absent from the selected model.
''', flush: true);
  await File(p.join(directory, 'main.lua')).writeAsString('''
local tinest = require("tinest")
local driver = tinest.driver.define({
    id = "driver",
    required_capabilities = {tinest.capability.model.call},
    -- No such model capability exists, so this driver can never run. The
    -- harness must refuse before the model is ever contacted.
    required_model_capabilities = {"role.tool"},
}, function(_arguments) return {tool_rounds = 0} end)
return tinest.plugin.define({driver = driver})
''', flush: true);
  final descriptor = await client.plugins.validatePlugin('acme.incompatible');
  expect(descriptor.contributions, isNotEmpty);
}

const _harnessManifest = '''
---
api: 5
id: acme.harness
version: 1.0.0
name: Harness E2E
entrypoint: main.lua
capabilities:
  - model.call
  - tools.list
  - tools.invoke
  - state.read
  - state.write
  - scheduler.manage
  - ui.publish
  - clock.sleep
---

Exercises the complete public plugin harness.
''';

const _harnessSource = '''
local tinest = require("tinest")
local S = tinest.schema
local T = require("tinest.types")

local state_value = S.object(T.StateValue, {
  status = S.string(),
  value = S.string(),
})
local phase = tinest.state.cell({
  scope = tinest.state.scope.session,
  key = "phase",
}, state_value)
local waiting = tinest.state.cell({
  scope = tinest.state.scope.session,
  key = "waiting",
}, state_value)

local refresh = tinest.ui.action({
  id = "refresh",
  required_capabilities = {tinest.capability.state.read},
}, S.any(), function(_arguments)
  return phase:read()
end)

local status = tinest.ui.contribution({
  id = "status",
  slot = tinest.ui.slot.timeline,
  required_capabilities = {tinest.capability.state.read},
  metadata = {snapshot = true},
}, S.any(), function(_arguments)
  local current = phase:read()
  local text = current.found ~= true and "empty" or
    tostring(current.value.status) .. ":" .. tostring(current.value.value)
  local waiting_value = waiting:read()
  if waiting_value.found == true then
    text = text .. "|" .. tostring(waiting_value.value.status) .. ":" ..
      tostring(waiting_value.value.value)
  end
  return tinest.ui.section({title = "Harness state", children = {
    tinest.ui.text({text = text}),
    tinest.ui.button({label = "Refresh", action = refresh}),
  }})
end)

local invalid = tinest.ui.contribution({
  id = "invalid",
  slot = tinest.ui.slot.timeline,
}, S.any(), function(_arguments)
  return {type = "remote-widget", source = "untrusted"}
end)

local remember_input = S.object(T.RememberInput, {value = S.string()})
local remember = tinest.tool.function_({
    id = "remember",
    name = "remember",
    description = "Persist one value and publish its native UI snapshot.",
    effects = {
      tinest.effect.state.write,
      tinest.effect.ui.timeline,
      tinest.effect.scheduler.enqueue,
    },
    required_capabilities = {
      tinest.capability.state.read,
      tinest.capability.state.write,
      tinest.capability.ui.publish,
    },
    presentation = {ui = status},
}, remember_input, nil, function(arguments)
  local current = phase:read()
  local stored = phase:compare_and_set(
    current.found and current.revision or 0,
    {status = "remembered", value = arguments.value}
  )
  tinest.ui.timeline(status, stored, {snapshot = true})
  return stored
end)

local wait_input = S.object(T.WaitInput, {})
local wait = tinest.tool.function_({
    id = "wait",
    name = "wait",
    description = "Wait in a cancellable host primitive.",
    uses = {tinest.host.clock.sleep},
    effects = {tinest.effect.clock.sleep},
    required_capabilities = {
      tinest.capability.state.read,
      tinest.capability.state.write,
      tinest.capability.clock.sleep,
    },
}, wait_input, nil, function(_arguments)
  local current = waiting:read()
  waiting:compare_and_set(
    current.found and current.revision or 0,
    {status = "waiting", value = "revoke"}
  )
  return tinest.result.unwrap(
    tinest.host.clock.sleep({duration_ms = 30000})
  )
end)

local scheduled_payload = S.object(T.ScheduledPayload, {
  reason = S.string(),
})
local scheduled = tinest.scheduler.handler({
  id = "scheduled",
  required_capabilities = {
    tinest.capability.state.read,
    tinest.capability.state.write,
  },
}, scheduled_payload, function(_arguments)
  local current = phase:read()
  phase:compare_and_set(
    current.revision,
    {status = "continued", value = current.value.value}
  )
  return {continue = true, prompt = "continuation"}
end)

local after_turn = tinest.hook.after_turn({
  id = "after-turn",
  required_capabilities = {
    tinest.capability.state.read,
    tinest.capability.state.write,
    tinest.capability.scheduler.manage,
  },
}, function(_arguments)
  local current = phase:read()
  if current.found ~= true or current.value.status ~= "remembered" then
    return {}
  end
  phase:compare_and_set(
    current.revision,
    {status = "scheduled", value = current.value.value}
  )
  return tinest.scheduler.continue_after_turn(scheduled, {reason = "e2e"})
end)

local function run(arguments)
  local history = arguments.history or {}
  table.insert(history, {type = "user", text = arguments.prompt, attachments = {}})
  local tools = tinest.tools.list()
  local selected = {}
  for _, descriptor in ipairs(tools) do
    selected[descriptor.name] = descriptor.ref
  end
  local rounds = 0
  if arguments.prompt == "wait for revoke" then
    tinest.tools.invoke(selected.wait, {})
    rounds = 1
  elseif arguments.prompt ~= "continuation" and #tools > 0 then
    tinest.tools.invoke(selected.remember, {value = arguments.prompt})
    rounds = 1
  end
  local stream = tinest.model.open({
    blocks = {{
      role = tinest.model.role.system,
      content = arguments.agent_prompt,
    }},
    history = history,
    tools = tools,
  })
  while true do
    local next = tinest.model.next(stream)
    if next.done then break end
  end
  return {tool_rounds = rounds}
end

local driver = tinest.driver.define({
  id = "driver",
  required_capabilities = {
    tinest.capability.model.call,
    tinest.capability.tools.list,
    tinest.capability.tools.invoke,
  },
  required_model_capabilities = {tinest.model.capability.streaming},
}, run)

return tinest.plugin.define({
  driver = driver,
  tools = {remember, wait},
  hooks = {after_turn, scheduled},
  ui = {status, invalid},
  actions = {refresh},
})
''';

List<String> _stringWiringViolations(String source) => <String>[
  if (RegExp(r'\bhandler\s*=').hasMatch(source)) 'handler binding',
  if (RegExp(r'''\.(?:call|open)\s*\(\s*["']''').hasMatch(source))
    'host operation',
  if (RegExp(r'\bactionId\s*=').hasMatch(source)) 'UI action',
  if (RegExp(r'\bcontribution_id\s*=').hasMatch(source)) 'UI contribution',
  if (RegExp(r'''tinest\.scheduler\.[a-z_]+\s*\(\s*["']''').hasMatch(source))
    'scheduled handler',
  if (RegExp(r'''tinest\.tools\.invoke\s*\(\s*["']''').hasMatch(source))
    'tool invocation',
];

final class _PluginHarnessProvider implements ModelGateway {
  final List<ModelRequest> requests = <ModelRequest>[];

  @override
  String get id => 'plugin-harness-e2e';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    cancellation.throwIfCancelled();
    requests.add(request);
    final text = 'plugin response ${requests.length}';
    yield ModelTextDelta(text);
    yield ModelResponseCompleted(
      assistant: AssistantConversationItem(text: text),
      usage: const ModelUsage(inputTokens: 3, outputTokens: 2),
    );
  }
}

final class _GoalE2eProvider implements ModelGateway {
  final List<ModelRequest> requests = <ModelRequest>[];

  @override
  String get id => 'goal-e2e';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    cancellation.throwIfCancelled();
    requests.add(request);
    switch (requests.length) {
      case 1:
        const arguments = <String, dynamic>{
          'objective': 'Finish the Lua plugin migration',
        };
        yield const ModelFunctionCall(
          callId: 'create-goal',
          name: 'create_goal',
          arguments: arguments,
        );
        yield const ModelResponseCompleted(
          assistant: AssistantConversationItem(
            text: '',
            toolCalls: <ConversationToolCall>[
              ConversationToolCall.function(
                callId: 'create-goal',
                name: 'create_goal',
                arguments: arguments,
              ),
            ],
          ),
          usage: ModelUsage(inputTokens: 2, outputTokens: 1),
        );
      case 2:
        yield const ModelTextDelta('Goal created.');
        yield const ModelResponseCompleted(
          assistant: AssistantConversationItem(text: 'Goal created.'),
          usage: ModelUsage(inputTokens: 3, outputTokens: 1),
        );
      case 3:
        const arguments = <String, dynamic>{'status': 'complete'};
        yield const ModelFunctionCall(
          callId: 'complete-goal',
          name: 'update_goal',
          arguments: arguments,
        );
        yield const ModelResponseCompleted(
          assistant: AssistantConversationItem(
            text: '',
            toolCalls: <ConversationToolCall>[
              ConversationToolCall.function(
                callId: 'complete-goal',
                name: 'update_goal',
                arguments: arguments,
              ),
            ],
          ),
          usage: ModelUsage(inputTokens: 2, outputTokens: 1),
        );
      case 4:
        yield const ModelTextDelta('Goal completed.');
        yield const ModelResponseCompleted(
          assistant: AssistantConversationItem(text: 'Goal completed.'),
          usage: ModelUsage(inputTokens: 3, outputTokens: 1),
        );
      default:
        throw StateError('Unexpected goal model request ${requests.length}.');
    }
  }
}

final class _NoNetworkCatalogMetadataSource
    implements ProviderCatalogMetadataSource {
  const new();

  @override
  Future<Map<String, List<ProviderCatalogMetadata>>> fetch(
    Set<String> providerIds,
  ) async => const <String, List<ProviderCatalogMetadata>>{};

  @override
  Future<void> close() async {}
}

final class _RecordingRpcDiagnostics implements RpcDiagnostics {
  final List<String> errors = <String>[];

  @override
  void unhandledError(
    String method,
    Object error,
    StackTrace stackTrace, {
    required String traceId,
  }) {
    errors.add('$method [$traceId]: $error\n$stackTrace');
  }
}
