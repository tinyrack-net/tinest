import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agent/agent.dart';
import 'package:app/testing/app/composition/app_services.dart';
import 'package:app/testing/app/tinest_app.dart';
import 'package:app/testing/features/conversation/infrastructure/attachment_io.dart';
import 'package:app/testing/features/conversation/presentation/chat_approval_card.dart';
import 'package:app/testing/features/conversation/presentation/chat_reasoning_card.dart';
import 'package:app/testing/features/conversation/presentation/chat_tool_card.dart';
import 'package:app/testing/features/conversation/presentation/widgets/session_composer.dart';
import 'package:app/testing/features/desktop/infrastructure/desktop_shell.dart';
import 'package:app/testing/features/hosts/application/host_controller.dart';
import 'package:app/testing/features/hosts/domain/host_models.dart';
import 'package:app/testing/features/hosts/domain/host_ports.dart';
import 'package:app/testing/features/plugins/presentation/plugin_ui_document_view.dart';
import 'package:app/testing/shared/presentation/settings_layout.dart';
import 'package:app/testing/shared/presentation/tinest_icons.dart';
import 'package:app/testing/shared/presentation/tinest_list_row.dart';
import 'package:app/testing/shared/presentation/tinest_selection_row.dart';
import 'package:client/client.dart';
import 'package:daemon/daemon.dart';
import 'package:dropwell/dropwell.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import 'support/pump_until.dart';
import 'support/tap_visible.dart';
import 'support/temporary_directory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'app switches hosts, streams, approves a patch, and restores timeline',
    (tester) async {
      // GitHub's Linux runner can expose platform accessibility even when
      // testWidgets does not create its own semantics handle. Force it off for
      // this visual interaction test to avoid flutter/flutter#189902.
      tester.platformDispatcher.semanticsEnabledTestValue = false;
      addTearDown(tester.platformDispatcher.clearSemanticsEnabledTestValue);
      expect(tester.binding.semanticsEnabled, isFalse);
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      final home = await Directory.systemTemp.createTemp('tinest-e2e-home-');
      final workspace = await Directory.systemTemp.createTemp(
        'tinest-e2e-workspace-',
      );
      final directoryWorkspace = await Directory.systemTemp.createTemp(
        'tinest-e2e-directory-',
      );
      // Stands in for the machine home the daemon turns into the implicit home
      // workspace, so the run never touches the home of whoever runs it.
      final userHome = Directory(
        await (await Directory.systemTemp.createTemp('tinest-e2e-user-home-'))
            .resolveSymbolicLinks(),
      );
      final remoteHome = await Directory.systemTemp.createTemp(
        'tinest-e2e-remote-home-',
      );
      final remoteWorkspace = await Directory.systemTemp.createTemp(
        'tinest-e2e-remote-workspace-',
      );
      const selectedModelId =
          'vendor/reasoning-model-with-an-extremely-long-identifier';
      await _initializeGitRepository(workspace.path);
      await _writeProjectCommand(workspace.path);
      final globalSkillsRoot = '${home.path}/v5/skills';
      final userSkillsRoot = '${userHome.path}/.agents/skills';
      final projectSkillsRoot = '${workspace.path}/.agents/skills';
      await _writeSkill(
        globalSkillsRoot,
        id: 'global-e2e',
        description: 'Visible only in the global catalog.',
        instructions: 'Use the global E2E instructions.',
      );
      await _writeSkill(
        globalSkillsRoot,
        id: 'invoke-e2e',
        description: 'Loaded during an end-to-end turn.',
        instructions: 'Use the deterministic E2E instructions.',
      );
      await _writeSkill(
        globalSkillsRoot,
        id: 'fallback-e2e',
        description: 'Global fallback remains available.',
        instructions: 'Use the valid global fallback.',
      );
      await _writeSkill(
        userSkillsRoot,
        id: 'legacy-enabled-e2e',
        description: 'Legacy enablement settings cannot hide this skill.',
        instructions: 'Ignore any stored disabled bit.',
      );
      await _writeSkill(
        globalSkillsRoot,
        id: 'shadow-global-e2e',
        name: 'shared-e2e',
        description: 'Shadowed global skill must stay hidden.',
        instructions: 'This global collision must not load.',
      );
      await _writeSkill(
        projectSkillsRoot,
        id: 'project-e2e',
        description: 'Visible only in the project catalog.',
        instructions: 'Use the project E2E instructions.',
      );
      await _writeSkill(
        projectSkillsRoot,
        id: 'shadow-project-e2e',
        name: 'shared-e2e',
        description: 'Winning project skill.',
        instructions: 'Use the project collision winner.',
      );
      await _writeInvalidSkill(projectSkillsRoot, id: 'fallback-e2e');
      await _writeInvalidSkill(projectSkillsRoot, id: 'invalid-e2e');
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
              <String, dynamic>{'id': 'e2e-model', 'owned_by': 'test'},
              <String, dynamic>{'id': selectedModelId, 'owned_by': 'test'},
            ],
          }),
        );
        await request.response.close();
      });
      final attachmentCapture = File(
        '${home.path}/provider-attachment-capture.json',
      );
      final imageBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+'
        'A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );
      final documentBytes = utf8.encode('attachment document\n');
      final agentProvider = _AgentE2eProvider(attachmentCapture.path);
      final handle = await EmbeddedDaemonHandle.start(
        DaemonConfig(
          homeDirectory: home.path,
          userHomeDirectory: userHome.path,
          port: 0,
          bearerToken: 'e2e-token-0123456789abcdef0123456789',
          useEnvironmentCredentials: false,
        ),
        provider: agentProvider,
      );
      final embeddedLauncher = _RestartableLauncher(
        initialHandle: handle,
        homeDirectory: home.path,
        userHomeDirectory: userHome.path,
        bearerToken: 'e2e-token-0123456789abcdef0123456789',
        provider: agentProvider,
      );
      final remoteHandle = await DaemonApplication.start(
        DaemonConfig(
          homeDirectory: remoteHome.path,
          port: 0,
          bearerToken: 'remote-token-0123456789abcdef0123456789',
          useEnvironmentCredentials: false,
        ),
        provider: _PatchProvider(),
        modelDiscovery: const _E2eModelDiscovery(),
      );
      addTearDown(() async {
        await embeddedLauncher.stopCurrent();
        await remoteHandle.stop();
        await Future.wait(<Future<void>>[
          deleteTemporaryDirectory(home),
          deleteTemporaryDirectory(userHome),
          deleteTemporaryDirectory(remoteHome),
          deleteTemporaryDirectory(workspace),
          deleteTemporaryDirectory(directoryWorkspace),
          deleteTemporaryDirectory(remoteWorkspace),
        ]);
        await modelServer.close(force: true);
      });
      final endpoint = HostEndpoint(websocketUri: handle.boundEndpoint);
      var setupClient = await TinestClient.connect(
        endpoint: endpoint,
        credentials: DaemonCredentials(bearerToken: handle.bearerToken),
        clientId: 'e2e-setup',
        clientKind: 'integration-test',
      );
      addTearDown(() => setupClient.close());
      final remoteClient = await TinestClient.connect(
        endpoint: HostEndpoint(websocketUri: remoteHandle.boundEndpoint),
        credentials: const DaemonCredentials(
          bearerToken: 'remote-token-0123456789abcdef0123456789',
        ),
        clientId: 'e2e-remote-setup',
        clientKind: 'integration-test',
      );
      addTearDown(remoteClient.close);
      await setupClient.workspaces.registerWorkspace(
        workspaceId: 'workspace-e2e',
        checkoutId: 'checkout-e2e',
        rootPath: workspace.path,
        name: 'E2E Workspace',
      );
      await setupClient.workspaces.registerWorkspace(
        workspaceId: 'directory-workspace-e2e',
        checkoutId: 'directory-checkout-e2e',
        rootPath: directoryWorkspace.path,
        name: 'E2E Directory',
      );
      final remoteWorkspaceName = remoteWorkspace.path
          .split(Platform.pathSeparator)
          .last;
      await remoteClient.workspaces.registerWorkspace(
        workspaceId: 'remote-workspace-e2e',
        checkoutId: 'remote-checkout-e2e',
        rootPath: remoteWorkspace.path,
        name: remoteWorkspaceName,
      );
      final terminal = await setupClient.terminals.createTerminal(
        id: 'terminal-e2e',
        worktreeId: 'checkout-e2e',
        title: 'E2E Terminal',
        columns: 80,
        rows: 24,
      );
      await setupClient.terminals.attachTerminal(
        terminal.id,
        mode: TerminalRestoreMode.snapshot,
      );
      const terminalMarker = 'terminal-e2e-ready';
      final terminalOutput = setupClient.terminals.output
          .where((output) => output.terminalId == terminal.id)
          .map((output) => output.data)
          .firstWhere((data) => data.contains(terminalMarker))
          .timeout(const Duration(seconds: 30));
      await setupClient.terminals.writeTerminal(
        terminal.id,
        "printf '$terminalMarker\\n'\r",
      );
      expect(await terminalOutput, contains(terminalMarker));
      await setupClient.terminals.terminateTerminal(terminal.id);

      final now = DateTime.utc(2026, 8, 3);
      final appStore = MemoryAppStore(
        settings: AppSettings(embeddedDaemonPort: handle.boundEndpoint.port),
        profiles: <RemoteDaemonProfile>[
          RemoteDaemonProfile(
            id: 'remote',
            label: 'Remote daemon',
            connections: directHostConnections(remoteHandle.boundEndpoint),
            autoConnect: true,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        tokens: const <String, String>{
          'remote': 'remote-token-0123456789abcdef0123456789',
        },
      );
      final desktopWindow = PluginDesktopWindow();
      await desktopWindow.prepare(startHidden: false);
      addTearDown(desktopWindow.releaseClose);

      await tester.pumpWidget(
        TinestApp(
          services: AppServices(
            settings: appStore,
            profiles: appStore,
            credentials: appStore,
            clients: const WebSocketHostClientFactory(),
            clientKind: 'desktop-integration-test',
            embeddedLauncher: embeddedLauncher,
          ),
          desktopWindow: desktopWindow,
          attachmentInput: _E2eAttachmentInput(
            imageBytes: imageBytes,
            documentBytes: documentBytes,
          ),
        ),
      );
      final hostRegistry = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      ).read(hostRegistryControllerProvider.notifier);
      // Await every client and the embedded daemon before unmounting. Riverpod
      // disposal cannot itself be awaited, so capture the controller while its
      // container is live and join that same cached close during tear-down.
      addTearDown(() async {
        try {
          await hostRegistry.shutdown();
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
        }
      });
      // The sidebar has no daemon level; each daemon names the workspace rows
      // it serves, so a subtitle is the evidence that it connected.
      await pumpUntil(tester, find.text('E2E Workspace'));
      await pumpUntil(tester, find.text(remoteWorkspaceName));
      await pumpUntil(tester, find.textContaining('내장 daemon · '));

      // macOS composes native window chrome, which carries no in-window menu
      // row; only the custom-chrome platforms own the Flutter menu bar.
      final chrome = desktopWindow.chrome;
      if (chrome.showsApplicationMenuBar) {
        // The View menu must keep following the persisted sidebar state after
        // each selection, rather than reusing the first title-bar snapshot.
        expect(find.text('보기'), findsOneWidget);
        await tester.tap(find.text('보기'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('사이드바 접기'));
        await tester.pumpAndSettle();
        expect(appStore.settings.sidebarCollapsed, isTrue);

        await tester.tap(find.text('보기'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('사이드바 열기'));
        await tester.pumpAndSettle();
        expect(appStore.settings.sidebarCollapsed, isFalse);

        // The global desktop menu reaches the same typed new-workspace route.
        expect(find.text('파일'), findsOneWidget);
        await tester.tap(find.text('파일'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('New workspace').last);
        await tester.pumpAndSettle();
      } else {
        expect(find.text('보기'), findsNothing);
        // The sidebar action reaches the same typed new-workspace route.
        await tapVisible(
          tester,
          find.byKey(const ValueKey('workspace-new-button')),
          'the new workspace button',
        );
        await tester.pumpAndSettle();
      }
      final projectChip = find.byKey(const ValueKey('new-workspace-project'));
      // The hover-dismiss contract has focused widget coverage. Repeating a
      // Tooltip OverlayPortal lifecycle in this long-lived desktop test also
      // triggers Flutter 3.44's stale semantics-child bug
      // (flutter/flutter#189902) before the required context-meter hover.
      await tester.tap(projectChip);
      await tester.pumpAndSettle();
      final addProject = find.byKey(
        const ValueKey('new-workspace-project-add'),
      );
      expect(addProject, findsOneWidget);
      await tester.tap(projectChip);
      await tester.pumpAndSettle();
      expect(addProject, findsNothing);

      await tapVisible(
        tester,
        find.byKey(const ValueKey<String>('workspace-settings-button')),
        'the workspace settings button',
      );
      await tester.pumpAndSettle();
      await _openSettingsCategory(tester, 'daemon');
      final exposureToggle = find.byKey(
        const ValueKey<String>('embedded-daemon-exposure'),
      );
      await pumpUntil(tester, exposureToggle);
      await tester.tap(exposureToggle);
      await pumpUntilCondition(
        tester,
        () => embeddedLauncher.exposures.length == 2,
        'embedded daemon to restart on all interfaces',
      );
      await pumpUntilCondition(
        tester,
        () => tester.widget<TinestSwitchRow>(exposureToggle).onChanged != null,
        'all-interface daemon to reconnect',
      );
      expect(embeddedLauncher.exposures, <EmbeddedDaemonExposure>[
        EmbeddedDaemonExposure.loopback,
        EmbeddedDaemonExposure.allInterfaces,
      ]);
      await tester.tap(exposureToggle);
      await pumpUntilCondition(
        tester,
        () => embeddedLauncher.exposures.length == 3,
        'embedded daemon to return to loopback',
      );
      await pumpUntilCondition(
        tester,
        () => tester.widget<TinestSwitchRow>(exposureToggle).onChanged != null,
        'loopback daemon to reconnect',
      );
      expect(embeddedLauncher.exposures.last, EmbeddedDaemonExposure.loopback);
      setupClient = await TinestClient.connect(
        endpoint: endpoint,
        credentials: DaemonCredentials(bearerToken: handle.bearerToken),
        clientId: 'e2e-setup-reconnected',
        clientKind: 'integration-test',
      );
      await _openSettingsCategory(tester, 'agent');
      await _selectDaemon(tester, 'Remote daemon');
      final addAgent = find.byKey(const ValueKey('agent-add-button'));
      await pumpUntil(tester, addAgent);
      await tester.tap(addAgent);
      await tester.pumpAndSettle();
      await tester.enterText(_trTextInput('ID (파일명)'), 'remote-agent');
      await tester.enterText(_trTextInput('이름').last, 'Remote Agent');
      FocusManager.instance.primaryFocus?.unfocus();
      final createRemoteAgent = find.widgetWithText(TRButton, '생성');
      await tester.ensureVisible(createRemoteAgent);
      await tester.pumpAndSettle();
      await tester.tap(createRemoteAgent);
      await pumpUntilGone(tester, find.text('Agent 추가'));
      final remoteAgent = await _waitForAgentDefinition(
        remoteClient,
        'remote-agent',
      );
      expect(remoteAgent.sourcePath, startsWith(remoteHome.path));
      await _selectDaemon(tester, '내장 daemon');
      await pumpUntil(tester, addAgent);
      await tester.tap(addAgent);
      await tester.pumpAndSettle();
      await tester.enterText(_trTextInput('ID (파일명)'), 'reviewer');
      await tester.enterText(_trTextInput('이름').last, 'Reviewer');
      await tester.tap(find.widgetWithText(TRSelectFormField<AgentMode>, '유형'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('subagent').last);
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      final createAgent = find.widgetWithText(TRButton, '생성');
      await tester.ensureVisible(createAgent);
      await tester.pumpAndSettle();
      await tester.tap(createAgent);
      await pumpUntilGone(tester, find.text('Agent 추가'));
      final reviewer = await _waitForAgentDefinition(setupClient, 'reviewer');
      final reviewerFile = File(reviewer.sourcePath);
      expect(reviewerFile.existsSync(), isTrue);

      final promptField = _trTextInput('시스템 프롬프트 (Markdown)').hitTestable();
      await tester.enterText(promptField, 'Review the current change.');
      final saveAgent = find.widgetWithText(TRButton, '저장').hitTestable();
      final currentReviewer = await setupClient.agents.getAgentDefinition(
        'reviewer',
      );
      final installedPlugins = await setupClient.plugins.listPlugins();
      final diagnosticCard = find.byKey(
        const ValueKey<String>('agent-harness-diagnostics'),
      );
      final renderedDiagnostics = diagnosticCard.evaluate().isEmpty
          ? const <String>[]
          : tester
                .widgetList<TRText>(
                  find.descendant(
                    of: diagnosticCard,
                    matching: find.byType(TRText),
                  ),
                )
                .map((text) => text.data)
                .toList(growable: false);
      expect(
        tester.widget<TRButton>(saveAgent).onPressed,
        isNotNull,
        reason:
            'A daemon-validated Agent must remain savable. '
            'driver=${currentReviewer.driverId}, '
            'extensions=${currentReviewer.extensionIds}, '
            'tools=${currentReviewer.toolIds}, '
            'plugins=${installedPlugins.map((plugin) => plugin.id).toList()}, '
            'diagnostics=$renderedDiagnostics',
      );
      await tester.tap(saveAgent);
      await tester.pump();
      await _waitForAgentPrompt(
        setupClient,
        'reviewer',
        'Review the current change.',
      );
      await reviewerFile.writeAsString(
        (await reviewerFile.readAsString()).replaceFirst(
          'Review the current change.',
          'Review the current change after external reload.',
        ),
        flush: true,
      );
      await _waitForAgentPrompt(
        setupClient,
        'reviewer',
        'Review the current change after external reload.',
      );
      await _pumpUntilTextFieldValue(
        tester,
        promptField,
        'Review the current change after external reload.',
      );
      final validReviewerSource = await reviewerFile.readAsString();
      await expectLater(
        setupClient.agents.validateAgentDefinition(
          'reviewer',
          'this document has no frontmatter',
        ),
        throwsA(isA<TinestClientException>()),
      );
      expect(await reviewerFile.readAsString(), validReviewerSource);

      await pumpUntil(tester, addAgent);
      await tester.tap(addAgent);
      await tester.pumpAndSettle();
      await tester.enterText(_trTextInput('ID (파일명)'), 'temporary');
      await tester.enterText(_trTextInput('이름').last, 'Temporary');
      FocusManager.instance.primaryFocus?.unfocus();
      final createTemporary = find.widgetWithText(TRButton, '생성');
      await tester.ensureVisible(createTemporary);
      await tester.pumpAndSettle();
      await tester.tap(createTemporary);
      await pumpUntilGone(tester, find.text('Agent 추가'));
      await _waitForAgentDefinition(setupClient, 'temporary');
      final archiveAgent = await _centerSettingsAction(
        tester,
        find.byKey(const ValueKey('agent-archive-button')),
        settingsOwner: find.byKey(
          const ValueKey<String>('agent-settings-editor-temporary'),
        ),
      );
      await tapVisible(tester, archiveAgent, 'the agent archive action');
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('agent-archive-confirm')),
      );
      await tester.pumpAndSettle();
      expect(
        (await setupClient.agents.listAgentDefinitions()).map(
          (item) => item.id,
        ),
        isNot(contains('temporary')),
      );

      await tester.tap(find.text('Tinest').first);
      await tester.pumpAndSettle();
      final resetAgent = await _centerSettingsAction(
        tester,
        find.byKey(const ValueKey('agent-reset-button')),
        settingsOwner: find.byKey(
          const ValueKey<String>('agent-settings-editor-tinest'),
        ),
      );
      await tapVisible(tester, resetAgent, 'the agent reset action');
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('agent-reset-confirm')),
      );
      await tester.pumpAndSettle();
      final tinestEditor = find.byKey(
        const ValueKey<String>('agent-settings-editor-tinest'),
      );
      await pumpUntil(tester, tinestEditor);
      // The group header is the waypoint rather than the tool: a group starts
      // closed, so its tools are not in the tree until someone opens it.
      final collaborationGroup = await _centerSettingsAction(
        tester,
        find.byKey(const ValueKey<String>('agent-tool-group-collaboration')),
        settingsOwner: tinestEditor,
      );
      // Opening it proves the group really does carry the tool the reset
      // default turned on, which the assertion below reads back off disk.
      await tapVisible(tester, collaborationGroup, 'the collaboration group');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TinestCheckboxRow>(
              find.byKey(
                const ValueKey<String>(
                  'agent-tool-tile-tinest.collaboration-spawn_agent',
                ),
              ),
            )
            .value,
        isTrue,
      );

      await _centerSettingsAction(
        tester,
        find.text('호출 가능한 Subagent'),
        settingsOwner: tinestEditor,
      );
      final reviewerSubagent = find.text('Reviewer').last;
      await tester.ensureVisible(reviewerSubagent);
      await tester.pumpAndSettle();
      await tester.tap(reviewerSubagent);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TRButton, '저장').hitTestable());
      await tester.pumpAndSettle();
      final collaboratingTinest = await setupClient.agents.getAgentDefinition(
        'tinest',
      );
      expect(collaboratingTinest.callableAgentIds, <String>['reviewer']);
      expect(
        collaboratingTinest.toolIds,
        contains('tinest.collaboration/spawn_agent'),
      );

      await _openSettingsCategory(tester, 'agent');
      await _openSettingsCategory(tester, 'skill');
      await pumpUntil(
        tester,
        find.byKey(const ValueKey<String>('skill-row-global-e2e')),
      );
      expect(
        find.byKey(const ValueKey<String>('skill-row-project-e2e')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('skill-add-button')),
        findsNothing,
      );

      final globalSkills = await setupClient.prompts.listSkills(
        view: SkillListView.global,
      );
      expect(globalSkills.map((skill) => skill.id), contains('global-e2e'));
      expect(
        globalSkills.map((skill) => skill.id),
        isNot(contains('project-e2e')),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('skill-scope-select')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('E2E Workspace').last);
      await pumpUntil(
        tester,
        find.byKey(const ValueKey<String>('skill-row-project-e2e')),
      );
      expect(
        find.byKey(const ValueKey<String>('skill-row-global-e2e')),
        findsNothing,
      );

      final projectSkills = await setupClient.prompts.listSkills(
        view: SkillListView.project,
        workspaceId: 'workspace-e2e',
      );
      expect(projectSkills.map((skill) => skill.id), contains('project-e2e'));
      expect(
        projectSkills.map((skill) => skill.id),
        isNot(contains('global-e2e')),
      );
      expect(
        projectSkills.map((skill) => skill.id),
        isNot(contains('fallback-e2e')),
      );
      expect(
        projectSkills.map((skill) => skill.id),
        isNot(contains('invalid-e2e')),
      );

      final effectiveSkills = await setupClient.prompts.listSkills(
        view: SkillListView.effective,
        workspaceId: 'workspace-e2e',
      );
      expect(effectiveSkills.map((skill) => skill.id), contains('global-e2e'));
      expect(effectiveSkills.map((skill) => skill.id), contains('project-e2e'));
      expect(
        effectiveSkills.singleWhere((skill) => skill.name == 'shared-e2e').id,
        'shadow-project-e2e',
      );
      expect(
        effectiveSkills
            .singleWhere((skill) => skill.id == 'fallback-e2e')
            .description,
        'Global fallback remains available.',
      );
      expect(
        effectiveSkills.map((skill) => skill.id),
        isNot(contains('invalid-e2e')),
      );

      await _writeSkill(
        projectSkillsRoot,
        id: 'external-e2e',
        description: 'Added outside Tinest.',
        instructions: 'Observe the external skill.',
      );
      await pumpUntil(
        tester,
        find.byKey(const ValueKey<String>('skill-row-external-e2e')),
      );
      await _writeSkill(
        projectSkillsRoot,
        id: 'external-e2e',
        description: 'Updated outside Tinest.',
        instructions: 'Observe the updated external skill.',
      );
      await pumpUntil(tester, find.text('Updated outside Tinest.'));
      await Directory('$projectSkillsRoot/external-e2e')
          .delete(recursive: true);
      await pumpUntilGone(
        tester,
        find.byKey(const ValueKey<String>('skill-row-external-e2e')),
      );

      await _openSettingsCategory(tester, 'agent');
      // The MCP server lifecycle through the UI -- a failing command, its
      // repair, discovery, and removal -- is `conversation-mcp`. It needed a
      // daemon and the settings route and none of the workspace this test
      // builds, and it was long enough to make this the only scenario in the
      // catalog that could not finish inside a lane's share of a shard.
      //
      // What stays here is the server the turn fixtures below invoke, which is
      // installed over the API because this test is not about installing it.
      await _openSettingsCategory(tester, 'mcp');
      await pumpUntil(tester, find.text('MCP 서버'));
      await tester.pumpAndSettle();

      // Install the server the turn fixtures below invoke. Its env resolves a
      // secret, which `conversation-mcp` creates through the UI and this test
      // therefore has to provide itself -- without it the server never reaches
      // ready and the wait below times out.
      await setupClient.mcp.setMcpSecret('e2e.prefix', 'secret-');
      await setupClient.mcp.addMcpServer(
        McpServerConfigDto(
          id: 'e2e',
          transport: McpTransportKind.stdio,
          command: _dartExecutable(),
          args: <String>[_fakeMcpServerPath()],
          env: const <String, String>{
            'MCP_ECHO_PREFIX': r'${secret:e2e.prefix}',
          },
        ),
      );
      await pumpUntilCondition(
        tester,
        () async =>
            (await setupClient.mcp.listMcpServers()).single.status ==
            McpServerStatus.ready,
        'the MCP turn server to reconnect',
      );
      final tinestDefinition = await setupClient.agents.getAgentDefinition(
        'tinest',
      );
      // The remaining turn fixtures invoke individual tools directly. v5 has
      // no hidden or always-on tools, so every static capability the fixture
      // calls is declared on this Agent. MCP tools themselves are materialized
      // only after the selected Lua search contribution discovers them.
      await setupClient.agents.updateAgentDefinition(
        tinestDefinition.copyWith(
          toolIds: <String>[
            ...tinestDefinition.toolIds.where(
              (toolId) => toolId != 'tinest.mcp/tool_search',
            ),
            'tinest.attachments/attach_file',
            'tinest.interaction/request_user_input',
            'tinest.skills/list_skills',
            'tinest.skills/skill',
            'tinest.mcp/tool_search',
          ],
        ),
        expectedContentHash: tinestDefinition.contentHash,
      );

      // Settings has no parent on a desktop window: one press leaves it.
      await tester.tap(
        find.byKey(const ValueKey<String>('settings-back-button')),
      );
      await pumpUntil(tester, find.text('E2E Workspace'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('E2E Workspace').last);
      await tester.pumpAndSettle();
      // Worktrees are created by the new-workspace composer, not the tree.
      expect(find.byTooltip('새 worktree'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('workspace-new-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('new-workspace-project')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('E2E Workspace ·').last);
      await tester.pumpAndSettle();
      await _selectComposerModel(
        tester,
        search: 'gpt-5.2',
        modelId: 'openai-gpt-5.2',
      );
      await tester.enterText(
        find.byKey(const ValueKey('session-composer-input')),
        'Feature e2e',
      );
      const newWorkspaceSend = ValueKey<String>('session-composer-send');
      await _waitForComposerReady(tester, newWorkspaceSend);
      final newWorkspaceSendButton = find.byKey(newWorkspaceSend);
      await tester.ensureVisible(newWorkspaceSendButton);
      await tester.pumpAndSettle();
      await tester.tap(newWorkspaceSendButton);
      await pumpUntilCondition(
        tester,
        () async => (await setupClient.workspaces.getWorkspaceCatalog())
            .worktrees
            .any((worktree) => worktree.branch == 'feature-e2e'),
        'the composer to create a worktree',
      );
      // The session route keeps the sidebar, so the new worktree is listed.
      await pumpUntil(tester, find.text('feature-e2e'));
      await tester.pumpAndSettle();
      final managedWorktree =
          (await setupClient.workspaces.getWorkspaceCatalog()).worktrees
              .singleWhere((worktree) => worktree.branch == 'feature-e2e');
      final managedMenu = find.byKey(
        ValueKey<String>('worktree-menu-${managedWorktree.id}'),
      );
      // Three workspace groups are present, so no group auto-expands while
      // the new-workspace route is still handing off to the session route.
      if (managedMenu.evaluate().isEmpty) {
        await tester.tap(find.text('E2E Workspace').last);
        await tester.pumpAndSettle();
      }
      await pumpUntil(tester, managedMenu);
      await tester.ensureVisible(managedMenu);
      await tester.pumpAndSettle();
      await tester.tap(managedMenu);
      await tester.pumpAndSettle();
      // The catalog is still streaming the new checkout in, so the sidebar can
      // rebuild under the menu and the panel needs another frame to settle.
      await pumpUntil(tester, find.text('Archive'));
      await tester.tap(find.text('Archive'));
      final archiveConfirm = find.byKey(
        const ValueKey<String>('worktree-archive-confirm'),
      );
      await pumpUntil(tester, archiveConfirm);
      await tester.tap(archiveConfirm);
      await pumpUntil(tester, find.text('E2E Workspace'));
      await tester.pumpAndSettle();
      if (find.text('main').evaluate().isEmpty) {
        await tester.tap(find.text('E2E Workspace').last);
        await tester.pumpAndSettle();
      }
      final mainWorktree = find.byKey(
        const ValueKey<String>('workspace-worktree-checkout-e2e'),
      );
      await pumpUntil(tester, mainWorktree);
      await tester.ensureVisible(mainWorktree);
      await tester.pumpAndSettle();
      await tester.tap(mainWorktree);
      const composer = ValueKey<String>('session-composer-input');
      const send = ValueKey<String>('session-composer-send');
      await pumpUntil(tester, find.byKey(composer));
      await tester.pumpAndSettle();
      await _selectComposerModel(
        tester,
        search: 'gpt-5.2',
        modelId: 'openai-gpt-5.2',
      );
      await awaitCondition(
        () async =>
            (await setupClient.workspaces.searchFiles(
              worktreeId: 'checkout-e2e',
              query: 'READ',
            )).matches.any(
              (match) =>
                  match.relativePath == 'README.md' && !match.isDirectory,
            ),
        'README.md to become searchable through the real daemon',
      );

      // An @ token completes into a worktree-relative path rather than
      // sending, and the completed prompt is what reaches the daemon.
      await _typeComposerPrompt(tester, composer, 'read @READ');
      await tester.pumpAndSettle();
      await pumpUntil(tester, find.text('README.md'));
      // Picked with the pointer rather than Enter: the catalog is still
      // streaming here, and a rebuild that takes focus sends the keystroke
      // nowhere. This step is about the daemon's search reaching the composer,
      // and `composer_input_test.dart` owns the keyboard contract.
      // The row names the file and its worktree-relative path, which are the
      // same string at the repository root, so both land in the same row.
      await tester.tap(find.text('README.md').first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TRTextField>(find.byKey(composer)).controller?.text,
        'read @README.md ',
      );

      // A query that matches nothing says so. Dismiss it from the stable tab
      // strip; composer_input_test.dart owns the keyboard dismissal contract.
      await _typeComposerPrompt(tester, composer, 'read @zzzzzz');
      await tester.pumpAndSettle();
      // The E2E app is pinned to Korean, so the empty row reads in Korean.
      await pumpUntil(tester, find.text('파일 없음'));
      await tester.tap(
        find.byKey(const ValueKey<String>('session-tab-strip')).hitTestable(),
      );
      await pumpUntilGone(tester, find.text('파일 없음'));

      await _submitComposerPrompt(tester, composer, send, 'Delegate review');
      // The parent turn completes without waiting for the spawned child.
      await _pumpUntilWithSessionDiagnostics(
        tester,
        find.text('Parent completed.', findRichText: true),
        setupClient,
      );
      final contextMeter = find.byKey(
        const ValueKey<String>('session-composer-context-meter'),
      );
      await pumpUntil(tester, contextMeter);
      final contextMouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await contextMouse.addPointer(location: Offset.zero);
      await contextMouse.moveTo(tester.getCenter(contextMeter));
      await pumpUntil(tester, find.text('컨텍스트 사용량'));
      await contextMouse.moveTo(Offset.zero);
      await pumpUntilGone(tester, find.text('컨텍스트 사용량'));
      // Do not leave a live hover pointer at the origin while this long-lived
      // test replaces routes. A later control can move underneath it and
      // create the second OverlayPortal show/hide cycle that triggers
      // flutter/flutter#189902 on Flutter 3.44.
      await contextMouse.removePointer();
      // The child works asynchronously and parks on an approval only a human
      // can answer; the track has to surface it or the agent never finishes.
      late SessionDto spawnedChild;
      await _pumpUntilConditionWithSessionDiagnostics(
        tester,
        () async {
          final sessions = await setupClient.sessions.listSessions(
            worktreeId: 'checkout-e2e',
          );
          final child = sessions
              .where(
                (session) =>
                    session.origin == SessionOrigin.delegated &&
                    session.status == SessionStatus.waitingForApproval,
              )
              .firstOrNull;
          if (child == null) return false;
          spawnedChild = child;
          return true;
        },
        'the spawned subagent to block on an approval',
        setupClient,
        budget: e2eTurnBudget,
      );
      expect(spawnedChild.taskName, 'review_task');
      expect(spawnedChild.agentPath, '/root/review_task');
      expect(
        (await setupClient.sessions.listSubagents(spawnedChild.id))
            .map((session) => session.id),
        contains(spawnedChild.id),
      );

      // The collaboration plugin draws this drawer, so the whole chain is
      // under test here: the daemon projects the tree, the plugin states a
      // count and a `blocked` status in the reader's language, and the host
      // frames it on the composer and resolves that status to the attention
      // icon rather than an ordinary spinner.
      final drawerSummary = find.text('서브 에이전트 1개');
      await pumpUntil(tester, drawerSummary);
      await tester.tap(drawerSummary);
      final childRow = find.ancestor(
        of: find.text('/root/review_task'),
        matching: find.byType(TinestListRow),
      );
      await pumpUntil(tester, childRow);
      await pumpUntil(
        tester,
        find.descendant(
          of: childRow,
          matching: find.byIcon(TinestIcons.approvalPending),
        ),
      );

      // Opening the row shows a live transcript with no composer, but its
      // approval stays actionable: answering it is what ends the child's turn.
      await tester.tap(childRow);
      await pumpUntil(
        tester,
        find.byKey(
          ValueKey<String>('conversation-pane-session:${spawnedChild.id}'),
        ),
      );
      expect(find.byKey(composer), findsNothing);
      final allowSubagentPatch = find.widgetWithText(TRButton, '승인');
      await pumpUntil(tester, allowSubagentPatch);
      await tester.tap(allowSubagentPatch.last);
      await pumpUntil(
        tester,
        find.text('Review completed.', findRichText: true),
      );
      await pumpUntilCondition(
        tester,
        () async {
          final sessions = await setupClient.sessions.listSessions(
            worktreeId: 'checkout-e2e',
          );
          final child = sessions.singleWhere(
            (session) => session.id == spawnedChild.id,
          );
          return child.lifecycle == AgentLifecycle.completed;
        },
        'the approved subagent to complete',
        budget: e2eTurnBudget,
      );
      expect(find.byKey(composer), findsNothing);
      // Subagents never surface in the all-sessions menu.
      await tapVisible(
        tester,
        find.byKey(const ValueKey<String>('workspace-all-sessions-menu')),
        'the all-sessions menu',
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TRMenuItem, 'review_task'), findsNothing);
      await tester.tap(find.text('Delegate review').last);
      // The composer only exists on a drivable pane, so its return is the
      // evidence that the root session is on screen again, not the child.
      await pumpUntil(tester, find.byKey(composer));

      // An app-owned command runs in the app: the draft clears and no turn
      // starts for it. This needs the live session, which is where the app
      // wires a handler; a draft composer has none and submits the text.
      final composerInput = find.descendant(
        of: find.byKey(composer),
        matching: find.byType(EditableText),
      );
      // Enter is ignored until a model resolves, so typing before that leaves
      // the draft sitting in the field.
      await _waitForComposerReady(tester, send);
      await tester.tap(composerInput);
      await pumpUntilCondition(
        tester,
        () => tester.widget<EditableText>(composerInput).focusNode.hasFocus,
        'the composer to take focus',
      );
      final sessionsBefore = (await setupClient.sessions.listSessions(
        worktreeId: 'checkout-e2e',
      )).length;
      tester.testTextInput.enterText('/clear');
      await pumpUntil(tester, find.text('clear'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TRTextField>(find.byKey(composer)).controller?.text,
        isEmpty,
      );
      expect(
        (await setupClient.sessions.listSessions(worktreeId: 'checkout-e2e'))
            .length,
        sessionsBefore,
      );

      // A project command on disk expands its template into the prompt the
      // daemon records for the turn.
      await _submitComposerPrompt(
        tester,
        composer,
        send,
        '/e2e-review lib/app.dart',
      );
      await pumpUntilCondition(tester, () async {
        for (final session in await setupClient.sessions.listSessions(
          worktreeId: 'checkout-e2e',
        )) {
          final timeline = await setupClient.sessions.subscribeTimeline(
            session.id,
          );
          final expanded = timeline
              .where((event) => event.type == 'user.message')
              .any(
                (event) =>
                    '${event.data['text']}' ==
                    'Review lib/app.dart for the E2E fixture.',
              );
          if (expanded) return true;
        }
        return false;
      }, 'the expanded agent command prompt to reach the daemon');
      await _waitForComposerReady(tester, send);
      // Sending moved focus to the send button; the flow below types straight
      // into the field, so hand it back.
      await tester.tap(composerInput);
      await pumpUntilCondition(
        tester,
        () => tester.widget<EditableText>(composerInput).focusNode.hasFocus,
        'the composer to take focus',
      );

      await tester.enterText(find.byKey(composer), 'Disallowed delegation');
      await tester.pump();
      expect(
        tester.widget<TRTextField>(find.byKey(composer)).controller?.text,
        'Disallowed delegation',
      );
      expect(
        tester.widget<TRIconButton>(find.byKey(send)).onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(send));
      await tester.pump();
      final failedToolSnapshot = find.byWidgetPredicate(
        (widget) =>
            widget is PluginUiDocumentView &&
            widget.document.pluginId == 'tinest.collaboration' &&
            jsonEncode(widget.document.root)
                .contains('Agent type is not allowed: not-allowed'),
      );
      await _pumpUntilWithSessionDiagnostics(
        tester,
        failedToolSnapshot,
        setupClient,
      );
      expect(failedToolSnapshot, findsOneWidget);
      final rootSession = (await setupClient.sessions.listSessions(
        worktreeId: 'checkout-e2e',
      )).singleWhere((session) => session.origin == SessionOrigin.manual);
      final failedToolEvent =
          (await setupClient.sessions.subscribeTimeline(rootSession.id))
              .singleWhere(
                (event) =>
                    event.type == 'tool.completed' &&
                    event.data['callId'] == 'disallowed-delegate-call',
              );
      expect(failedToolEvent.data['isError'], isTrue);
      // Expansion and the structured error body are owned by the focused
      // chat-view widget test. This real-daemon slice pins the failed card and
      // the exact tool event below without depending on virtual-list details.
      await pumpUntilCondition(tester, () {
        final button = find.byKey(send).evaluate().singleOrNull?.widget;
        return button is TRIconButton && button.onPressed != null;
      }, 'the failed delegation turn to release the composer');

      await _submitComposerPrompt(tester, composer, send, 'Create result.txt');
      final patchApproval = _approvalForCall('patch-call');
      await pumpUntil(tester, patchApproval);
      final runningPatch = find.byWidgetPredicate(
        (widget) =>
            widget is ChatToolCard && widget.activity.callId == 'patch-call',
        description: 'running patch tool card',
      );
      await pumpUntil(tester, runningPatch);
      expect(
        find.descendant(of: runningPatch, matching: find.byType(ShaderMask)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: runningPatch, matching: find.byType(TRSpinner)),
        findsNothing,
      );
      expect(
        find.descendant(of: runningPatch, matching: find.text('실행 중')),
        findsNothing,
      );
      await tester.tap(
        find.descendant(
          of: patchApproval,
          matching: find.widgetWithText(TRButton, '승인'),
        ),
      );
      await pumpUntil(
        tester,
        find.text('Created result.txt', findRichText: true),
      );
      // That reply is the scripted provider's catch-all, so an earlier turn
      // already put it in this transcript and the finder above matches on the
      // first poll. Only a settled session proves this turn's tool ran, and
      // the file it wrote is what the next line reads.
      await pumpUntilCondition(
        tester,
        () async =>
            (await setupClient.sessions.listSessions(
                  worktreeId: 'checkout-e2e',
                ))
                .singleWhere(
                  (session) => session.origin == SessionOrigin.manual,
                )
                .status ==
            SessionStatus.idle,
        'the patch turn to finish',
      );
      expect(
        await File('${workspace.path}/result.txt').readAsString(),
        'done\n',
      );
      // Completion is replaced by the plugin-owned immutable presentation
      // snapshot; the running host card above is deliberately no longer kept.
      final patchSnapshot = find.byWidgetPredicate(
        (widget) =>
            widget is PluginUiDocumentView &&
            widget.document.pluginId == 'tinest.edit',
      );
      expect(patchSnapshot, findsOneWidget);
      final patchEvent =
          (await setupClient.sessions.subscribeTimeline(rootSession.id))
              .singleWhere(
                (event) =>
                    event.type == 'tool.completed' &&
                    event.data['callId'] == 'patch-call',
              );
      expect(patchEvent.data['isError'], isFalse);
      expect(tester.takeException(), isNull);
      // Attachments use the authenticated HTTP transport even though the turn
      // and timeline continue to use the WebSocket API.
      await File('${workspace.path}/agent-output.txt')
          .writeAsString('agent attachment\n');
      final attachmentSession = (await setupClient.sessions.listSessions(
        worktreeId: 'checkout-e2e',
      )).singleWhere((session) => session.origin == SessionOrigin.manual);
      final attachButton = find
          .byKey(const ValueKey('session-composer-attach'))
          .hitTestable();
      expect(tester.widget<TRIconButton>(attachButton).onPressed, isNotNull);
      await tester.tap(attachButton);
      await tester.pump();
      expect(find.textContaining('fixture.png'), findsNothing);
      expect(tester.widget<TRIconButton>(attachButton).onPressed, isNotNull);
      await tester.tap(attachButton);
      await pumpUntil(tester, find.textContaining('fixture.png'));
      expect(find.textContaining('fixture.txt'), findsOneWidget);
      await tester.tap(find.byKey(send));
      await pumpUntilCondition(
        tester,
        attachmentCapture.exists,
        'the provider to receive hydrated attachments',
      );
      final providerAttachments = (jsonDecode(
        await attachmentCapture.readAsString(),
      ) as List<dynamic>).cast<Map<String, dynamic>>();
      expect(
        providerAttachments.map((attachment) => attachment['fileName']),
        orderedEquals(<String>['fixture.png', 'fixture.txt']),
      );
      expect(
        base64Decode(providerAttachments[0]['bytes']! as String),
        orderedEquals(imageBytes),
      );
      expect(
        base64Decode(providerAttachments[1]['bytes']! as String),
        orderedEquals(documentBytes),
      );
      final attachmentTimeline = await setupClient.sessions.subscribeTimeline(
        attachmentSession.id,
      );
      final uploadedSnapshots =
          attachmentTimeline
                  .lastWhere(
                    (event) =>
                        event.type == 'user.message' &&
                        (event.data['attachments'] as List? ??
                                const <dynamic>[])
                            .isNotEmpty,
                  )
                  .data['attachments']!
              as List<dynamic>;
      final imageAttachmentId =
          (uploadedSnapshots.first! as Map<String, dynamic>)['id']! as String;
      await pumpUntil(
        tester,
        find.byKey(ValueKey('chat-attachment-$imageAttachmentId')),
      );
      await tester.tap(
        find.byKey(ValueKey('chat-attachment-$imageAttachmentId')),
      );
      await pumpUntil(tester, find.byType(InteractiveViewer));
      expect(find.byType(InteractiveViewer), findsOneWidget);
      Navigator.of(tester.element(find.byType(InteractiveViewer))).pop();
      await pumpUntilGone(tester, find.byType(InteractiveViewer));
      await pumpUntil(
        tester,
        find.text('Attached fixtures.', findRichText: true),
      );

      await _submitComposerPrompt(
        tester,
        composer,
        send,
        'Publish outbound attachment',
      );
      await pumpUntilCondition(
        tester,
        () async =>
            (await setupClient.sessions.subscribeTimeline(attachmentSession.id))
                .any((event) => event.type == 'assistant.attachment'),
        'the agent to publish its outbound attachment',
      );
      await pumpUntil(tester, find.textContaining('agent-output.txt'));
      final outboundTimeline = await setupClient.sessions.subscribeTimeline(
        attachmentSession.id,
      );
      final outboundEvent = outboundTimeline.singleWhere(
        (event) => event.type == 'assistant.attachment',
      );
      final outboundId = outboundEvent.data['id']! as String;
      final outboundDownload = await setupClient.attachments.downloadAttachment(
        outboundId,
      );
      expect(
        await outboundDownload.bytes.expand((chunk) => chunk).toList(),
        utf8.encode('agent attachment\n'),
      );
      await pumpUntil(
        tester,
        find.text('Published outbound attachment.', findRichText: true),
      );

      await _submitComposerPrompt(tester, composer, send, 'Reject result.txt');
      final rejectedPatchApproval = _approvalForCall('reject-patch-call');
      await pumpUntil(tester, rejectedPatchApproval);
      await tester.tap(
        find.descendant(
          of: rejectedPatchApproval,
          matching: find.widgetWithText(TRButton, '거부'),
        ),
      );
      await pumpUntil(tester, find.text('Rejected safely', findRichText: true));
      expect(File('${workspace.path}/rejected.txt').existsSync(), isFalse);

      final liveMcpServer = (await setupClient.mcp.listMcpServers()).single;
      expect(liveMcpServer.status, McpServerStatus.ready);
      expect(
        liveMcpServer.tools.map((tool) => tool.toolId),
        contains('mcp__e2e__echo'),
      );
      expect(
        (await setupClient.agents.listAgentTools()).map((tool) => tool.id),
        allOf(
          contains('tinest.mcp/tool_search'),
          isNot(contains('tinest.mcp/tool_bridge')),
          isNot(contains('tinest.mcp/mcp__e2e__echo')),
        ),
      );
      await _submitComposerPrompt(tester, composer, send, 'MCP echo');
      final mcpApproval = _approvalForCall('mcp-call');
      await _pumpUntilWithSessionDiagnostics(tester, mcpApproval, setupClient);
      await tester.tap(
        find.descendant(
          of: mcpApproval,
          matching: find.widgetWithText(TRButton, '승인'),
        ),
      );
      await pumpUntil(tester, find.text('MCP completed', findRichText: true));

      await _submitComposerPrompt(tester, composer, send, 'Reject MCP');
      final rejectedMcpApproval = _approvalForCall('reject-mcp-call');
      await _pumpUntilWithSessionDiagnostics(
        tester,
        rejectedMcpApproval,
        setupClient,
      );
      await tester.tap(
        find.descendant(
          of: rejectedMcpApproval,
          matching: find.widgetWithText(TRButton, '거부'),
        ),
      );
      await pumpUntil(tester, find.text('MCP rejected', findRichText: true));

      await setupClient.mcp.removeMcpServer('e2e');
      final staticCatalog = await setupClient.agents.listAgentTools();
      expect(
        staticCatalog.map((tool) => tool.id),
        allOf(
          contains('tinest.mcp/tool_search'),
          isNot(contains('tinest.mcp/tool_bridge')),
          isNot(contains('tinest.mcp/mcp__e2e__echo')),
        ),
      );
      await _submitComposerPrompt(tester, composer, send, 'Offline MCP');
      await pumpUntil(
        tester,
        find.text('MCP unavailable safely', findRichText: true),
      );

      await _submitComposerPrompt(tester, composer, send, 'Use E2E skill');
      await pumpUntil(tester, find.text('Skill loaded', findRichText: true));
      await _submitComposerPrompt(
        tester,
        composer,
        send,
        'Check excluded E2E skills',
      );
      await pumpUntil(
        tester,
        find.text('Excluded skills absent', findRichText: true),
      );

      await _submitComposerPrompt(tester, composer, send, 'Cancel streaming');
      await pumpUntil(
        tester,
        find.text('Streaming before cancel', findRichText: true),
      );
      final stop = find.byWidgetPredicate(
        (widget) => widget is TRIconButton && widget.label == '중지',
        description: 'stop active turn button',
      );
      await tester.tap(stop);
      await pumpUntil(tester, find.text('중지됨'));

      await _submitComposerPrompt(tester, composer, send, 'Recover provider');
      await pumpUntil(tester, find.textContaining('planned provider outage'));
      await _submitComposerPrompt(tester, composer, send, 'Recover provider');
      await pumpUntil(
        tester,
        find.text('Provider recovered', findRichText: true),
      );

      final turnBranches = await setupClient.sessions.subscribeTimeline(
        (await setupClient.sessions.listSessions(worktreeId: 'checkout-e2e'))
            .singleWhere((session) => session.origin == SessionOrigin.manual)
            .id,
      );
      expect(
        turnBranches.map((event) => event.type),
        containsAll(<String>[
          'turn.cancelled',
          'turn.failed',
          'approval.resolved',
          'tool.denied',
        ]),
      );
      expect(
        turnBranches
            .where((event) => event.type == 'turn.failed')
            .map((event) => event.data['error']),
        contains(contains('planned provider outage')),
      );
      // A rejected spawn surfaces as an error tool result, not a failed turn.
      expect(
        turnBranches
            .where(
              (event) =>
                  event.type == 'tool.completed' &&
                  event.data['isError'] == true,
            )
            .map((event) => event.data['output']),
        contains(contains('Agent type is not allowed: not-allowed')),
      );
      expect(
        turnBranches
            .where((event) => event.type == 'approval.resolved')
            .map((event) => event.data['status']),
        contains('denied'),
      );
      expect(
        turnBranches
            .where(
              (event) =>
                  event.type == 'tool.completed' &&
                  event.data['name'] == 'mcp__e2e__echo',
            )
            .map((event) => event.data['output']),
        contains(contains('secret-through MCP')),
      );
      expect(
        turnBranches
            .where(
              (event) =>
                  event.type == 'tool.completed' &&
                  event.data['name'] == 'skill',
            )
            .map((event) => event.data['output'])
            .join('\n'),
        contains('Use the deterministic E2E instructions.'),
      );

      // A blocking agent question stops the turn until the user answers it,
      // and the chosen answer reaches the model.
      await _submitComposerPrompt(
        tester,
        composer,
        send,
        'Ask me about storage',
      );
      // The prompt has to leave the composer. Failing here separates "never
      // left the client" from "the daemon never answered", which the 120s
      // wait below cannot tell apart.
      await pumpUntilCondition(
        tester,
        () =>
            find.text('Ask me about storage').evaluate().isNotEmpty ||
            tester
                .widgetList<SessionComposer>(find.byType(SessionComposer))
                .any((item) => item.queued.isNotEmpty),
        'the storage prompt to leave the composer',
      );
      await _pumpUntilWithSessionDiagnostics(
        tester,
        find.text('Storage'),
        setupClient,
      );
      expect(find.text('Which store should the cache use?'), findsOneWidget);
      final questionSubmit = find.byKey(
        const ValueKey<String>('chat-question-submit'),
      );
      // The turn stays blocked: nothing was chosen yet.
      expect(tester.widget<TRButton>(questionSubmit).onPressed, isNull);
      await tester.tap(find.text('SQLite'));
      await pumpUntil(tester, find.text('Which theme should the editor use?'));
      expect(find.text('Which store should the cache use?'), findsNothing);

      await tester.tap(find.text('직접 입력'));
      final themeAnswer = find.byKey(
        const ValueKey<String>('chat-question-other-theme'),
      );
      await pumpUntil(tester, themeAnswer);
      await tester.enterText(themeAnswer, 'High contrast');
      await pumpUntilCondition(
        tester,
        () => tester.widget<TRButton>(questionSubmit).onPressed != null,
        'the next button to accept the typed answer',
      );
      expect(find.widgetWithText(TRButton, '다음'), findsOneWidget);
      await tester.ensureVisible(questionSubmit);
      await tester.pump();
      await tester.tap(questionSubmit);
      await pumpUntil(tester, find.text('How should changes be reviewed?'));

      expect(find.widgetWithText(TRButton, '답변'), findsOneWidget);
      expect(tester.widget<TRButton>(questionSubmit).onPressed, isNull);
      await tester.tap(find.text('Pull request'));
      await pumpUntilCondition(
        tester,
        () => tester.widget<TRButton>(questionSubmit).onPressed != null,
        'the answer button to accept all three answers',
      );
      await tester.ensureVisible(questionSubmit);
      await tester.pump();
      await tester.tap(questionSubmit);
      await pumpUntil(
        tester,
        find.textContaining('Chose SQLite, High contrast, and Pull request'),
      );
      await pumpUntilGone(tester, questionSubmit);

      await _submitComposerPrompt(tester, composer, send, 'Show reasoning');
      await pumpUntil(
        tester,
        find.text('Reasoning shown.', findRichText: true),
      );
      final latestReasoning = find.byWidgetPredicate(
        (widget) =>
            widget is ChatReasoningCard &&
            widget.activity.markdown.contains('복원 가능한 사고 요약'),
        description: 'latest reasoning card',
      );
      await pumpUntil(tester, latestReasoning);
      expect(find.text('생각함', findRichText: true), findsWidgets);
      await tester.tap(latestReasoning);
      await tester.pump();
      expect(find.text('복원 가능한 사고 요약입니다.', findRichText: true), findsOneWidget);

      final reconnected = await TinestClient.connect(
        endpoint: endpoint,
        credentials: DaemonCredentials(bearerToken: handle.bearerToken),
        clientId: 'e2e-reconnect',
        clientKind: 'integration-test',
      );
      final agents = await reconnected.sessions.listSessions(
        worktreeId: 'checkout-e2e',
      );
      expect(agents, hasLength(2));
      final parent = agents.singleWhere(
        (session) => session.origin == SessionOrigin.manual,
      );
      final child = agents.singleWhere(
        (session) => session.origin == SessionOrigin.delegated,
      );
      expect(child.parentSessionId, parent.id);
      final timeline = await reconnected.sessions.subscribeTimeline(parent.id);
      expect(timeline.map((event) => event.type), contains('turn.completed'));
      expect(
        timeline
            .where((event) => event.type == 'assistant.reasoning.delta')
            .map((event) => event.data['text']),
        containsAll(<String>[
          '패치를 적용할 방법을 정리합니다.',
          '적용 결과를 확인합니다.',
          '복원 가능한 사고 요약입니다.',
        ]),
      );
      final restoredAttachmentTimeline = await reconnected.sessions
          .subscribeTimeline(parent.id);
      expect(
        restoredAttachmentTimeline.map((event) => event.type),
        contains('assistant.attachment'),
      );
      final restoredUserAttachment = restoredAttachmentTimeline.singleWhere(
        (event) =>
            event.type == 'user.message' &&
            (event.data['attachments'] as List? ?? const <dynamic>[])
                .isNotEmpty,
      );
      expect(
        (restoredUserAttachment.data['attachments']! as List<dynamic>).map(
          (item) => (item! as Map<String, dynamic>)['fileName'],
        ),
        orderedEquals(<String>['fixture.png', 'fixture.txt']),
      );
      expect(
        timeline.map((event) => event.sequence),
        orderedEquals(
          List<int>.generate(timeline.length, (index) => index + 1),
        ),
      );
      await reconnected.close();

      // Session tabs are device-local: closing one must preserve daemon
      // history, and the all-sessions picker must restore it.
      await tester.tap(
        find.byKey(ValueKey<String>('tr-tabs-close-${parent.id}')),
      );
      await pumpUntilGone(
        tester,
        find.byKey(ValueKey<String>('tr-tabs-close-${parent.id}')),
      );
      expect(
        (await setupClient.sessions.listSessions(worktreeId: 'checkout-e2e'))
            .map((session) => session.id),
        contains(parent.id),
      );
      // Closing the last tab returns to the checkout, and the tab strip shows
      // a spinner in place of its menus until the tab state loads again.
      final allSessionsMenu = find.byKey(
        const ValueKey<String>('workspace-all-sessions-menu'),
      );
      await tapVisible(tester, allSessionsMenu, 'the all-sessions menu');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delegate review').last);
      await pumpUntil(
        tester,
        find.byKey(ValueKey<String>('tr-tabs-close-${parent.id}')),
      );
      final restoredReasoning = find.byWidgetPredicate(
        (widget) =>
            widget is ChatReasoningCard &&
            widget.activity.markdown.contains('복원 가능한 사고 요약'),
        description: 'restored latest reasoning card',
      );
      await pumpUntil(tester, restoredReasoning);
      await tester.ensureVisible(restoredReasoning);
      await tester.pump();
      expect(find.text('생각함', findRichText: true), findsWidgets);
      final restoredReasoningText = find.text(
        '복원 가능한 사고 요약입니다.',
        findRichText: true,
      );
      if (restoredReasoningText.evaluate().isEmpty) {
        await tester.tap(restoredReasoning);
        await tester.pump();
      }
      expect(restoredReasoningText, findsOneWidget);
      // The desktop workspace persists a binary layout, streams divider
      // changes, and collapses a source pane when its last tab moves away.
      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-split-right')),
      );
      await pumpUntil(tester, find.byType(TRSplitView));
      expect(
        find.byKey(const ValueKey<String>('workspace-pane')),
        findsNWidgets(2),
      );
      await tester.drag(
        find.byKey(const ValueKey<String>('tr-split-view-separator')),
        const Offset(TRSpacing.threeExtraLarge, 0),
      );
      await tester.pumpAndSettle();
      final sourceTab = find.byKey(
        ValueKey<String>('tr-tabs-tab-${parent.id}'),
      );
      final targetPane = find
          .byKey(const ValueKey<String>('workspace-pane'))
          .last;
      final targetTab = find.descendant(
        of: targetPane,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'tr-tabs-tab-',
              ),
        ),
      );
      await tester.timedDragFrom(
        tester.getCenter(sourceTab),
        tester.getCenter(targetTab) - tester.getCenter(sourceTab),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      await pumpUntil(
        tester,
        find.descendant(
          of: targetPane,
          matching: find.byKey(ValueKey<String>('tr-tabs-tab-${parent.id}')),
        ),
      );
      for (var moved = 0; moved < 10; moved++) {
        if (find.byType(TRSplitView).evaluate().isEmpty) break;
        final sourceRemainingTab = find.descendant(
          of: find.byKey(const ValueKey<String>('workspace-pane')).first,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  'tr-tabs-tab-',
                ),
          ),
        );
        if (sourceRemainingTab.evaluate().isEmpty) break;
        await tester.timedDragFrom(
          tester.getCenter(sourceRemainingTab.first),
          tester.getCenter(targetTab.last) -
              tester.getCenter(sourceRemainingTab.first),
          const Duration(seconds: 1),
        );
        await tester.pumpAndSettle();
      }
      await pumpUntilGone(tester, find.byType(TRSplitView));
      expect(
        find.byKey(ValueKey<String>('tr-tabs-close-${parent.id}')),
        findsOneWidget,
      );

      await tapVisible(
        tester,
        find.byKey(const ValueKey<String>('workspace-settings-button')),
        'the workspace settings button',
      );
      await pumpUntil(
        tester,
        find.byKey(const ValueKey<String>('provider-add-button')),
      );
      await _selectDaemon(tester, 'Remote daemon');
      await pumpUntil(
        tester,
        find.byKey(const ValueKey<String>('provider-add-button')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('provider-add-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('OpenAI'), findsWidgets);
      expect(find.text('DeepSeek'), findsWidgets);
      final addCustom = find.byKey(const ValueKey('provider-add-custom'));
      await tester.ensureVisible(addCustom);
      await tester.pumpAndSettle();
      await tester.tap(addCustom);
      await tester.pumpAndSettle();
      await tester.enterText(_trTextInput('이름'), '');
      await tester.enterText(_trTextInput('기본 URL'), '');
      await tester.tap(
        find.byKey(const ValueKey<String>('provider-custom-save')),
      );
      await tester.pumpAndSettle();
      expect(find.text('이름과 Base URL을 입력하세요.'), findsOneWidget);
      await tester.enterText(_trTextInput('이름'), 'E2E Provider');
      await tester.enterText(
        _trTextInput('기본 URL'),
        'http://127.0.0.1:${modelServer.port}/unavailable/v1',
      );
      await tester.enterText(_trTextInput('API 키'), 'valid-key');
      await tester.tap(
        find.byKey(const ValueKey<String>('provider-custom-save')),
      );
      ProviderConnectionDto? degradedProvider;
      await pumpUntilCondition(tester, () async {
        final matches = (await remoteClient.providers.listProviderConnections())
            .where(
              (item) =>
                  item.displayName == 'E2E Provider' &&
                  item.status == ProviderConnectionStatus.degraded,
            );
        if (matches.length != 1) return false;
        degradedProvider = matches.single;
        return true;
      }, 'the custom provider to be persisted');
      expect(degradedProvider!.status, ProviderConnectionStatus.degraded);
      final activeProviderDetail = find
          .byKey(ValueKey<String>('provider-detail-${degradedProvider!.id}'))
          .hitTestable();
      await pumpUntil(tester, activeProviderDetail);

      await tester.enterText(
        _trTextInput('이름').hitTestable(),
        'E2E Provider Edited',
      );
      await tester.enterText(
        _trTextInput('기본 URL').hitTestable(),
        'http://127.0.0.1:${modelServer.port}/v1',
      );
      await tester.pump();
      await tester.tap(
        find
            .byKey(const ValueKey<String>('provider-custom-save'))
            .hitTestable(),
      );
      await pumpUntilCondition(
        tester,
        () async => (await remoteClient.providers.listProviderConnections())
            .any((item) => item.displayName == 'E2E Provider Edited'),
        'the custom provider edit to be persisted',
      );
      final providerConnection = await _waitForProviderModels(
        remoteClient,
        'E2E Provider Edited',
      );
      expect(
        (await remoteClient.providers.listProviderModels(providerConnection.id))
            .map((model) => model.id),
        containsAll(<String>[
          '${providerConnection.modelPrefix}/e2e-model',
          '${providerConnection.modelPrefix}/$selectedModelId',
        ]),
      );
      expect(find.text('E2E Provider Edited'), findsWidgets);
      const customDelete = ValueKey<String>('provider-custom-delete');
      await _centerSettingsAction(tester, find.byKey(customDelete));
      await pumpUntilCondition(
        tester,
        () =>
            tester.widget<TRButton>(find.byKey(customDelete)).onPressed != null,
        'the custom provider delete action to become enabled',
      );
      await tapVisible(
        tester,
        find.byKey(customDelete),
        'the custom provider delete action',
      );
      await pumpUntil(tester, find.byType(TRAlertDialog));
      await tester.tap(
        find.descendant(
          of: find.byType(TRAlertDialog),
          matching: find.widgetWithText(TRButton, '취소'),
        ),
      );
      await pumpUntil(tester, find.byKey(customDelete));
      expect(
        (await remoteClient.providers.listProviderConnections()).where(
          (item) => item.id == providerConnection.id,
        ),
        hasLength(1),
      );
      await _centerSettingsAction(tester, find.byKey(customDelete));
      await tapVisible(
        tester,
        find.byKey(customDelete),
        'the custom provider delete action',
      );
      await pumpUntil(tester, find.byType(TRAlertDialog));
      await tester.tap(
        find.descendant(
          of: find.byType(TRAlertDialog),
          matching: find.widgetWithText(TRButton, '삭제'),
        ),
      );
      await pumpUntilCondition(
        tester,
        () async => (await remoteClient.providers.listProviderConnections())
            .every((item) => item.id != providerConnection.id),
        'custom provider to be deleted',
      );
      await pumpUntilGone(
        tester,
        find.byKey(
          ValueKey<String>('provider-detail-${providerConnection.id}'),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('provider-add-button')),
      );
      await tester.pumpAndSettle();
      final addDeepSeek = find.byKey(const ValueKey('provider-add-deepseek'));
      await pumpUntil(tester, addDeepSeek);
      await tester.ensureVisible(addDeepSeek);
      await tester.tap(addDeepSeek);
      await tester.pumpAndSettle();
      await tester.enterText(_trTextInput('API 키'), 'valid-key');
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('provider-connect-submit')),
      );
      ProviderConnectionDto? connectedDeepSeek;
      await pumpUntilCondition(tester, () async {
        final matches = (await remoteClient.providers.listProviderConnections())
            .where(
              (item) =>
                  item.definitionId == 'deepseek' &&
                  item.status == ProviderConnectionStatus.connected,
            )
            .toList();
        if (matches.length != 1) return false;
        connectedDeepSeek = matches.single;
        return true;
      }, 'provider credential to connect');
      await pumpUntil(
        tester,
        find.byKey(
          ValueKey<String>('provider-detail-${connectedDeepSeek!.id}'),
        ),
      );
      await _disconnectProviderConnection(tester, connectedDeepSeek!.id);

      await tester.tap(
        find.byKey(const ValueKey<String>('provider-add-button')),
      );
      await tester.pumpAndSettle();
      final addOllama = find.byKey(const ValueKey('provider-add-ollama'));
      await pumpUntil(tester, addOllama);
      await tester.ensureVisible(addOllama);
      await tester.tap(addOllama);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('provider-connect-submit')),
      );
      ProviderConnectionDto? connectedOllama;
      await pumpUntilCondition(tester, () async {
        final matches = (await remoteClient.providers.listProviderConnections())
            .where(
              (item) =>
                  item.definitionId == 'ollama' &&
                  item.status == ProviderConnectionStatus.connected,
            )
            .toList();
        if (matches.length != 1 ||
            matches.single.credentialOrigin != ProviderCredentialOrigin.none) {
          return false;
        }
        connectedOllama = matches.single;
        return true;
      }, 'no-auth provider to connect');
      await _disconnectProviderConnection(tester, connectedOllama!.id);
      await pumpUntilCondition(
        tester,
        () async => (await remoteClient.providers.listProviderConnections())
            .where(
              (item) =>
                  (item.definitionId == 'deepseek' ||
                      item.definitionId == 'ollama') &&
                  item.status == ProviderConnectionStatus.connected,
            )
            .isEmpty,
        'connected providers to finish disconnecting',
      );
      final remainingConnections = await remoteClient.providers
          .listProviderConnections();
      expect(
        remainingConnections.where(
          (item) =>
              (item.definitionId == 'deepseek' ||
                  item.definitionId == 'ollama') &&
              item.status == ProviderConnectionStatus.connected,
        ),
        isEmpty,
      );
      expect(
        remainingConnections
            .singleWhere((item) => item.definitionId == 'openai')
            .status,
        ProviderConnectionStatus.connected,
      );

      // A plain directory reuses its sole checkout without exposing or
      // validating Git-only worktree and base-branch targets. macOS composes
      // native chrome without the in-window File menu; the sidebar action
      // reaches the same typed new-workspace route.
      if (desktopWindow.chrome.showsApplicationMenuBar) {
        await tester.tap(find.text('파일'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('New workspace').last);
        await tester.pumpAndSettle();
      } else {
        await tapVisible(
          tester,
          find.byKey(const ValueKey('workspace-new-button')),
          'the new workspace button',
        );
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const ValueKey('new-workspace-project')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('E2E Directory ·').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('new-workspace-worktree')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('new-workspace-branch')), findsNothing);
      // The send button is disabled until a model resolves, so tapping before
      // that does nothing and no session is ever created.
      await _waitForComposerReady(
        tester,
        const ValueKey<String>('session-composer-send'),
      );
      await tester.enterText(
        find.byKey(const ValueKey('session-composer-input')),
        'Directory e2e',
      );
      await tester.tap(find.byKey(const ValueKey('session-composer-send')));
      await pumpUntilCondition(
        tester,
        () async => (await setupClient.sessions.listSessions(
          worktreeId: 'directory-checkout-e2e',
        )).any((session) => session.title == 'Directory e2e'),
        'the directory checkout session to start',
      );
      final daemonDefaultModel =
          (await setupClient.models.getSettings()).defaultModel;
      expect(daemonDefaultModel, isNotNull);
      final directorySession = (await setupClient.sessions.listSessions(
        worktreeId: 'directory-checkout-e2e',
      )).singleWhere((session) => session.title == 'Directory e2e');
      // The new-workspace draft intentionally keeps its explicit chat model
      // across sessions, and that override must outrank the daemon default.
      const retainedChatOverride = ModelSelectionDto(modelId: 'openai/gpt-5.2');
      expect(daemonDefaultModel, isNot(retainedChatOverride));
      expect(directorySession.model, retainedChatOverride);
      final directoryWorktrees =
          (await setupClient.workspaces.getWorkspaceCatalog()).worktrees.where(
            (item) => item.workspaceId == 'directory-workspace-e2e',
          );
      expect(directoryWorktrees.single.id, 'directory-checkout-e2e');

      // A session can start without any project: the daemon provisioned the
      // user home as an implicit workspace that no project list offers, and
      // the sidebar lists the session outside every project.
      final homeCatalog = await setupClient.workspaces.getWorkspaceCatalog();
      final homeWorkspace = homeCatalog.workspaces.singleWhere(
        (item) => item.kind == WorkspaceKind.home,
      );
      expect(homeWorkspace.rootPath, userHome.path);
      final homeCheckout = homeCatalog.worktrees.singleWhere(
        (item) => item.workspaceId == homeWorkspace.id,
      );
      final newWorkspaceButton = find
          .byKey(const ValueKey('workspace-new-button'))
          .hitTestable();
      await pumpUntil(tester, newWorkspaceButton);
      await tester.tap(newWorkspaceButton.first);
      await pumpUntil(
        tester,
        find.byKey(const ValueKey('new-workspace-project')),
      );
      await tester.tap(find.byKey(const ValueKey('new-workspace-project')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('new-workspace-project-none')),
      );
      await tester.pumpAndSettle();
      // Without a project there is no branch to pick and no checkout to make.
      expect(
        find.byKey(const ValueKey('new-workspace-worktree')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('new-workspace-branch')), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('session-composer-input')),
        'Home e2e',
      );
      await tester.tap(find.byKey(const ValueKey('session-composer-send')));
      await pumpUntilCondition(
        tester,
        () async => (await setupClient.sessions.listSessions(
          worktreeId: homeCheckout.id,
        )).any((session) => session.title == 'Home e2e'),
        'the project-less session to start in the home folder',
      );
      // The home workspace backs the session but is never shown as a project.
      await tester.tap(find.text('Workspaces').last);
      await pumpUntil(tester, find.text('Home e2e'));
      expect(find.text(homeWorkspace.name), findsNothing);
    },
    // This test validates visible desktop interactions, not accessibility.
    // Flutter 3.44's testWidgets semantics handle exposes the open
    // OverlayPortal corruption tracked by flutter/flutter#189902, making the
    // otherwise successful run fail nondeterministically during a later frame.
    // Focused widget tests retain semantics coverage for these controls.
    semanticsEnabled: false,
    tags: const <String>[
      'ui_journey__conversation_long_running__e2e',
      'feature_test__daemon_management__e2e',
      'feature_test__daemon_exposure__e2e',
      'feature_test__daemon_authentication__e2e',
      'feature_test__workspace_catalog__e2e',
      'feature_test__workspace_registration__e2e',
      'feature_test__worktree_lifecycle__e2e',
      'feature_test__session_lifecycle__e2e',
      'feature_test__session_tabs__e2e',
      'feature_test__terminal_lifecycle__e2e',
      'feature_test__terminal_lifecycle__platformSmoke',
      'feature_scenario__terminal_lifecycle__create_write_terminate__e2e',
      'feature_test__turn_execution__e2e',
      'feature_test__turn_question__e2e',
      'feature_scenario__turn_question__ask_and_answer__e2e',
      'feature_test__agent_definition_management__e2e',
      'feature_test__skill_catalog__e2e',
      'feature_test__agent_collaboration__e2e',
      'feature_test__provider_catalog__e2e',
      'feature_test__provider_usage__e2e',
      'feature_scenario__provider_usage__context_usage_hover__e2e',
      'feature_test__provider_connection_management__e2e',
      'feature_test__provider_custom__e2e',
      'feature_test__desktop_window_chrome__e2e',
      'feature_test__conversation_attachments__e2e',
      'feature_scenario__conversation_attachments__picker_cancel_retry__e2e',
      'feature_scenario__conversation_attachments__upload_preview_restore__e2e',
      'feature_scenario__conversation_attachments__agent_publish_download__e2e',
      'feature_scenario__daemon_authentication__valid_token_reconnect__e2e',
      'feature_scenario__daemon_exposure__loopback_lan_restart__e2e',
      'feature_scenario__workspace_catalog__multi_host_merge_refresh__e2e',
      'feature_scenario__worktree_lifecycle__create_and_archive__e2e',
      'feature_scenario__session_lifecycle__create_with_configuration__e2e',
      'feature_scenario__session_lifecycle__reconnect_persistence__e2e',
      'feature_test__session_home__e2e',
      'feature_scenario__session_home__create_without_project__e2e',
      'feature_scenario__session_tabs__open_switch_close_restore__e2e',
      'feature_scenario__turn_execution__stream_and_restore__e2e',
      'feature_scenario__turn_execution__cancel_stream__e2e',
      'feature_scenario__turn_execution__approve_and_reject__e2e',
      'feature_scenario__turn_execution__provider_failure_recovery__e2e',
      // The verifier requires one literal tag so it can reject stale evidence.
      // ignore: lines_longer_than_80_chars
      'feature_scenario__agent_definition_management__create_validate_edit_reload__e2e',
      // The scenario tag mirrors its typed manifest ID exactly.
      // ignore: lines_longer_than_80_chars
      'feature_scenario__agent_definition_management__invalid_definition_rejected__e2e',
      'feature_scenario__agent_definition_management__archive_and_reset__e2e',
      'feature_scenario__mcp_tool_execution__approve_execute_result__e2e',
      'feature_scenario__mcp_tool_execution__reject_and_offline__e2e',
      'feature_scenario__skill_catalog__global_project_partition__e2e',
      'feature_scenario__skill_catalog__external_file_refresh__e2e',
      'feature_test__composer_file_mention__e2e',
      'feature_test__composer_slash_command__e2e',
      'feature_scenario__composer_file_mention__mention_insert_path__e2e',
      'feature_scenario__composer_file_mention__no_match_dismiss__e2e',
      'feature_scenario__composer_slash_command__client_command_dispatch__e2e',
      'feature_scenario__composer_slash_command__agent_command_prompt__e2e',
      'feature_scenario__skill_invocation__effective_catalog_load__e2e',
      'feature_scenario__skill_invocation__shadowed_invalid_excluded__e2e',
      'feature_scenario__agent_collaboration__spawn_child_final_answer__e2e',
      // The scenario tag mirrors its typed manifest ID exactly.
      // ignore: lines_longer_than_80_chars
      'feature_scenario__agent_collaboration__unauthorized_agent_type_rejected__e2e',
      'feature_scenario__provider_catalog__presets_models_refresh__e2e',
      // The scenario tag mirrors its typed manifest ID exactly.
      // ignore: lines_longer_than_80_chars
      'feature_scenario__provider_connection_management__api_key_none_disconnect__e2e',
      // The second connection scenario has the same typed tag constraint.
      // ignore: lines_longer_than_80_chars
      'feature_scenario__provider_connection_management__invalid_credential_recovery__e2e',
      'feature_scenario__provider_custom__create_edit_delete__e2e',
      'feature_scenario__provider_custom__validation_and_model_failure__e2e',
      'feature_scenario__desktop_window_chrome__localized_menu_navigation__e2e',
    ],
  );
}

final class _E2eAttachmentInput implements AttachmentInputPort {
  new({required this.imageBytes, required this.documentBytes});

  final Uint8List imageBytes;
  final List<int> documentBytes;
  bool _cancelNextPick = true;

  @override
  bool get supportsDrop => false;

  @override
  Future<List<PendingAttachment>> pickFiles() async {
    if (_cancelNextPick) {
      _cancelNextPick = false;
      return const <PendingAttachment>[];
    }
    return <PendingAttachment>[
      PendingAttachment.fromBytes(
        fileName: 'fixture.png',
        mimeType: 'image/png',
        bytes: imageBytes,
      ),
      PendingAttachment.fromBytes(
        fileName: 'fixture.txt',
        mimeType: 'text/plain',
        bytes: Uint8List.fromList(documentBytes),
      ),
    ];
  }

  @override
  Future<List<PendingAttachment>> pasteFiles() async =>
      const <PendingAttachment>[];

  @override
  Future<List<PendingAttachment>> droppedFiles(
    List<DropwellFile> files,
  ) async => const <PendingAttachment>[];
}

Future<ProviderConnectionDto> _waitForProviderModels(
  TinestApi api,
  String displayName,
) => awaitValue(() async {
  final connection = (await api.providers.listProviderConnections())
      .where((item) => item.displayName == displayName)
      .singleOrNull;
  if (connection == null) return null;
  final models = await api.providers.listProviderModels(connection.id);
  return models.isEmpty ? null : connection;
}, '$displayName to discover models');

Future<void> _waitForAgentPrompt(TinestApi api, String id, String prompt) =>
    awaitCondition(
      () async => (await api.agents.getAgentDefinition(id)).prompt == prompt,
      'the external agent file to reload',
    );

Future<AgentDefinitionDto> _waitForAgentDefinition(TinestApi api, String id) =>
    awaitValue(() async {
      try {
        return await api.agents.getAgentDefinition(id);
      } on TinestClientException catch (error) {
        if (error.code != 'request_failed') rethrow;
        return null;
      }
    }, 'Agent definition $id');

Future<void> _selectDaemon(WidgetTester tester, String label) async {
  // The picker now lives in the sidebar, so a settings route still animating
  // out carries its own copy. Settle it away before selecting the incoming
  // route and wait for the host-scoped content to finish replacing afterward.
  await tester.pumpAndSettle();
  final dropdown = find.byKey(const ValueKey<String>('settings-daemon-select'));
  await tester.tap(dropdown.last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _disconnectProviderConnection(
  WidgetTester tester,
  String connectionId,
) async {
  final detail = find.byKey(ValueKey<String>('provider-detail-$connectionId'));
  await pumpUntil(tester, detail.hitTestable());
  final disconnect = find
      .byKey(const ValueKey<String>('provider-connection-disconnect'))
      .hitTestable();
  await _centerSettingsAction(tester, disconnect);
  await tapVisible(tester, disconnect, 'the provider disconnect action');
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(TRAlertDialog),
      matching: find.widgetWithText(TRButton, '연결 해제'),
    ),
  );
  await pumpUntilGone(tester, detail);
}

Future<void> _pumpUntilTextFieldValue(
  WidgetTester tester,
  Finder finder,
  String value,
) => pumpUntilCondition(
  tester,
  () => tester
      .widgetList<EditableText>(finder)
      .any((field) => field.controller.text == value),
  'the text field to hold "$value"',
);

Finder _trTextInput(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is TRTextField && widget.label == label,
    description: 'TRTextField labelled "$label"',
  ),
  matching: find.byType(EditableText),
);

Future<void> _openSettingsCategory(WidgetTester tester, String category) async {
  final row = find.byKey(ValueKey<String>('settings-category-row-$category'));
  await pumpUntil(tester, row.hitTestable());
  await tester.tap(row.hitTestable());
  await tester.pumpAndSettle();
}

Future<Finder> _centerSettingsAction(
  WidgetTester tester,
  Finder action, {
  Finder? settingsOwner,
}) async {
  // A detail replacement deliberately keeps the outgoing route inert during
  // its transition. Both routes listen to the same pane controller, so until
  // that transition settles they can render the new editor identity while
  // retaining independent lazy-list scroll positions. Never choose a scroll
  // owner from that transient pair: it can disappear before the action is
  // built in the incoming route.
  await tester.pumpAndSettle();
  if (settingsOwner != null) {
    expect(
      settingsOwner,
      findsOneWidget,
      reason: 'a settled settings destination has one editor owner',
    );
  }
  // Saving can also briefly replace the editor with its loading state. Wait
  // for the settled settings list to remount before revealing the trailing
  // action. Jump one currently known extent at a time: lazily built sections
  // can extend the list after a jump, and reaching a stable end without the
  // action is a real contract failure.
  final ownedAction = settingsOwner == null
      ? action
      : find.descendant(of: settingsOwner, matching: action);
  var anchoredAtStart = false;
  while (ownedAction.evaluate().isEmpty) {
    final settingsLists = find.descendant(
      of: settingsOwner ?? find.byType(SettingsScaffold),
      matching: find.byType(ListView),
    );
    await pumpUntil(tester, settingsLists);
    final settingsScrollable = find
        .descendant(of: settingsLists.first, matching: find.byType(Scrollable))
        .first;
    await pumpUntil(tester, settingsScrollable);
    final position = tester.state<ScrollableState>(settingsScrollable).position;
    if (!anchoredAtStart) {
      anchoredAtStart = true;
      if (position.pixels > position.minScrollExtent) {
        position.jumpTo(position.minScrollExtent);
        await tester.pumpAndSettle();
        continue;
      }
    }
    final nextExtent = position.maxScrollExtent;
    if (!position.hasContentDimensions || nextExtent <= position.pixels) {
      throw TestFailure('Settings action was not built after scrolling.');
    }
    position.jumpTo(nextExtent);
    await tester.pumpAndSettle();
  }
  await pumpUntil(tester, ownedAction);
  expect(
    ownedAction,
    findsOneWidget,
    reason: 'the exact settings editor owns one actionable control',
  );
  await Scrollable.ensureVisible(tester.element(ownedAction), alignment: 0.5);
  await tester.pumpAndSettle();
  return ownedAction;
}

Finder _approvalForCall(String toolCallId) => find.byWidgetPredicate(
  (widget) =>
      widget is ApprovalCard &&
      (widget.interaction?.approval ?? widget.approval)?.toolCallId ==
          toolCallId,
  description: 'approval card for tool call $toolCallId',
);

Future<void> _initializeGitRepository(String path) async {
  await _runGit(path, <String>['init', '-b', 'main']);
  await File('$path/README.md').writeAsString('# E2E fixture\n');
  await _runGit(path, <String>['add', 'README.md']);
  await _runGit(path, <String>[
    '-c',
    'user.name=Tinest E2E',
    '-c',
    'user.email=tinest-e2e@example.invalid',
    'commit',
    '-m',
    'Initial fixture',
  ]);
}

/// Seeds a project command so the composer has one to expand.
Future<void> _writeProjectCommand(String path) async {
  final directory = Directory('$path/.agents/commands');
  await directory.create(recursive: true);
  await File('${directory.path}/e2e-review.md').writeAsString(
    '---\n'
    'description: Reviews a path in the E2E fixture.\n'
    'argument-hint: <path>\n'
    '---\n\n'
    r'Review $ARGUMENTS for the E2E fixture.'
    '\n',
  );
}

/// Seeds one externally managed skill directory.
Future<void> _writeSkill(
  String root, {
  required String id,
  required String description,
  required String instructions,
  String? name,
}) async {
  final directory = Directory('$root/$id');
  await directory.create(recursive: true);
  await File('${directory.path}/SKILL.md').writeAsString(
    '---\n'
    'name: ${name ?? id}\n'
    'description: $description\n'
    '---\n\n'
    '$instructions\n',
  );
}

/// Seeds malformed project input that must not displace a valid candidate.
Future<void> _writeInvalidSkill(String root, {required String id}) async {
  final directory = Directory('$root/$id');
  await directory.create(recursive: true);
  await File(
    '${directory.path}/SKILL.md',
  ).writeAsString('---\nname: $id\n---\n\nMissing the required description.\n');
}

Future<void> _runGit(String path, List<String> arguments) async {
  final result = await Process.run('git', arguments, workingDirectory: path);
  if (result.exitCode != 0) {
    throw TestFailure('git ${arguments.join(' ')} failed: ${result.stderr}');
  }
}

String _fakeMcpServerPath() {
  final suffix = <String>[
    'packages',
    'daemon',
    'test',
    'support',
    'fake_mcp_server_main.dart',
  ].join(Platform.pathSeparator);
  final candidates = <File>[
    File('${Directory.current.path}${Platform.pathSeparator}$suffix'),
    File(
      '${Directory.current.path}${Platform.pathSeparator}..'
      '${Platform.pathSeparator}..${Platform.pathSeparator}$suffix',
    ),
  ];
  for (final candidate in candidates) {
    if (candidate.existsSync()) return candidate.absolute.path;
  }
  throw TestFailure(
    'Could not locate fake_mcp_server_main.dart from ${Directory.current}.',
  );
}

String _dartExecutable() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null && flutterRoot.isNotEmpty) {
    final executable = File(
      <String>[
        flutterRoot,
        'bin',
        'cache',
        'dart-sdk',
        'bin',
        if (Platform.isWindows) 'dart.exe' else 'dart',
      ].join(Platform.pathSeparator),
    );
    if (executable.existsSync()) return executable.absolute.path;
  }
  final lookup = Process.runSync(
    Platform.isWindows ? 'where' : 'which',
    <String>['dart'],
  );
  if (lookup.exitCode == 0) {
    return (lookup.stdout as String).split(RegExp(r'\r?\n')).first.trim();
  }
  throw TestFailure(
    'Could not locate the Dart executable for the MCP fixture.',
  );
}

/// Waits for the composer to have a model, which is all that gates sending.
///
/// A running turn never disables the button; the prompt queues instead. So
/// this is not a barrier on the previous turn, and a caller that needs one has
/// to wait on daemon state itself.
Future<void> _waitForComposerReady(
  WidgetTester tester,
  ValueKey<String> sendKey,
) => pumpUntilCondition(tester, () {
  final sendButton = find.byKey(sendKey);
  if (sendButton.evaluate().length != 1) return false;
  return tester.widget<TRIconButton>(sendButton).onPressed != null;
}, 'the composer to have a model selected');

Future<void> _selectComposerModel(
  WidgetTester tester, {
  required String search,
  required String modelId,
}) async {
  final direct = find.byKey(const ValueKey<String>('session-composer-model'));
  if (direct.evaluate().isNotEmpty) {
    await tester.ensureVisible(direct);
    await tester.pumpAndSettle();
    await tester.tap(direct);
  } else {
    await tester.tap(
      find.byKey(const ValueKey<String>('session-composer-settings')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('session-composer-settings-model')),
    );
  }
  await tester.pumpAndSettle();
  final searchField = find.byType(TRTextField).last;
  await tester.enterText(searchField, search);
  await tester.pumpAndSettle();
  final option = find.byKey(ValueKey<String>('model-option-$modelId'));
  await tester.tap(option);
  await tester.pumpAndSettle();
  await pumpUntilGone(tester, option);
  if (find
      .byKey(const ValueKey<String>('session-composer-settings-sheet'))
      .evaluate()
      .isNotEmpty) {
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  }
}

/// Types [prompt] into the composer and proves it arrived.
///
/// `tester.enterText` grants focus and pumps once, which is not enough: the
/// text goes to whichever field owns the input connection, so a rebuild racing
/// the keystroke leaves the field empty. An empty field then makes the send a
/// silent no-op, because the composer treats "nothing to send" as nothing to
/// do. Callers that only type, such as the `@` mention steps, use this
/// directly; everything else goes through [_submitComposerPrompt].
Future<void> _typeComposerPrompt(
  WidgetTester tester,
  ValueKey<String> composerKey,
  String prompt,
) async {
  final composer = find.byKey(composerKey);
  final input = find.descendant(
    of: composer,
    matching: find.byType(EditableText),
  );
  await tester.tap(input);
  // Focus is the evidence that the input connection is this composer's.
  await pumpUntilCondition(
    tester,
    () => tester.widget<EditableText>(input).focusNode.hasFocus,
    'the composer to take focus',
  );
  tester.testTextInput.enterText(prompt);
  await tester.pump();
  expect(tester.widget<TRTextField>(composer).controller?.text, prompt);
}

Future<void> _submitComposerPrompt(
  WidgetTester tester,
  ValueKey<String> composerKey,
  ValueKey<String> sendKey,
  String prompt,
) async {
  // Typing first: over a running turn an empty composer offers stop rather
  // than send, so the send button only exists once there is a prompt.
  await _typeComposerPrompt(tester, composerKey, prompt);
  await _waitForComposerReady(tester, sendKey);
  // The send button and the toast stack share the bottom-trailing corner, so a
  // report still on screen from an earlier action takes the tap instead. A
  // reader waits it out or dismisses it; this waits.
  await _waitForToastsToClear(tester);
  await tester.tap(find.byKey(sendKey));
  await tester.pump();
}

/// Waits until nothing is left in the toast stack.
Future<void> _waitForToastsToClear(WidgetTester tester) => pumpUntilGone(
  tester,
  find.descendant(
    of: find.byType(TRToastRegion),
    matching: find.byType(Dismissible),
  ),
);

/// Waits for [finder], reporting both sides when it never comes.
///
/// The daemon dump alone reads as innocent when the prompt never left the
/// client, which is indistinguishable from a model that answered something
/// else. The composer state is what tells those apart.
Future<void> _pumpUntilWithSessionDiagnostics(
  WidgetTester tester,
  Finder finder,
  TinestApi api,
) async {
  try {
    await pumpUntil(tester, finder, budget: e2eTurnBudget);
  } on TestFailure catch (failure) {
    final sessions = await api.sessions.listSessions(
      worktreeId: 'checkout-e2e',
    );
    final diagnostics = <String, Object?>{};
    for (final session in sessions) {
      diagnostics[session.id] = <String, Object?>{
        'status': session.status.name,
        'definition': session.agentDefinitionId,
        'lastError': session.lastError,
        'events': (await api.sessions.subscribeTimeline(session.id))
            .map(
              (event) => <String, Object?>{
                'type': event.type,
                if (event.type.startsWith('tool.') ||
                    event.type.startsWith('plugin.lifecycle.') ||
                    event.type.endsWith('.failed'))
                  'data': event.data,
              },
            )
            .toList(growable: false),
      };
    }
    final composers = tester.widgetList<SessionComposer>(
      find.byType(SessionComposer),
    );
    final client = <String, Object?>{
      'busy': composers.map((item) => item.busy).toList(growable: false),
      'queued': composers
          .map(
            (item) => item.queued
                .map(
                  (turn) =>
                      '${turn.text} '
                      '(attempts ${turn.attempts}, error ${turn.error})',
                )
                .toList(growable: false),
          )
          .toList(growable: false),
      'composerText': tester
          .widgetList<TRTextField>(find.byType(TRTextField))
          .map((field) => field.controller?.text)
          .where((text) => text != null && text.isNotEmpty)
          .toList(growable: false),
    };
    throw TestFailure(
      '${failure.message} Client: $client Sessions: $diagnostics',
    );
  }
}

Future<void> _pumpUntilConditionWithSessionDiagnostics(
  WidgetTester tester,
  FutureOr<bool> Function() condition,
  String description,
  TinestApi api, {
  Duration budget = e2eWaitBudget,
}) async {
  try {
    await pumpUntilCondition(tester, condition, description, budget: budget);
  } on TestFailure catch (failure) {
    final sessions = await api.sessions.listSessions(
      worktreeId: 'checkout-e2e',
    );
    final diagnostics = <String, Object?>{};
    for (final session in sessions) {
      diagnostics[session.id] = <String, Object?>{
        'status': session.status.name,
        'definition': session.agentDefinitionId,
        'origin': session.origin.name,
        'taskName': session.taskName,
        'lastError': session.lastError,
        'events': (await api.sessions.subscribeTimeline(session.id))
            .map(
              (event) => <String, Object?>{
                'type': event.type,
                if (event.type.startsWith('tool.') ||
                    event.type.startsWith('plugin.lifecycle.') ||
                    event.type.endsWith('.failed'))
                  'data': event.data,
              },
            )
            .toList(growable: false),
      };
    }
    throw TestFailure('${failure.message} Sessions: $diagnostics');
  }
}

final class _RestartableLauncher implements EmbeddedDaemonLauncher {
  new({
    required EmbeddedDaemonHandle initialHandle,
    required this.homeDirectory,
    required this.userHomeDirectory,
    required this.bearerToken,
    required this.provider,
  }) : _current = initialHandle;

  final String homeDirectory;

  /// Stands in for the machine home so a restart keeps the home workspace.
  final String userHomeDirectory;
  final String bearerToken;
  final ModelGateway provider;
  final List<EmbeddedDaemonExposure> exposures = <EmbeddedDaemonExposure>[];
  EmbeddedDaemonHandle? _current;
  bool _initial = true;

  @override
  Future<EmbeddedDaemonSession> start({
    required EmbeddedDaemonExposure exposure,
    required int port,
  }) async {
    exposures.add(exposure);
    final handle = _initial
        ? _current!
        : await EmbeddedDaemonHandle.start(
            DaemonConfig(
              homeDirectory: homeDirectory,
              userHomeDirectory: userHomeDirectory,
              host: exposure.bindHost,
              port: port,
              bearerToken: bearerToken,
              useEnvironmentCredentials: false,
            ),
            provider: provider,
          );
    _initial = false;
    _current = handle;
    return _ExistingSession(
      handle,
      onStopped: () {
        if (identical(_current, handle)) _current = null;
      },
    );
  }

  Future<void> stopCurrent() async {
    final handle = _current;
    _current = null;
    await handle?.stop();
  }
}

final class _ExistingSession implements EmbeddedDaemonSession {
  const new(this.handle, {required this.onStopped});

  final EmbeddedDaemonHandle handle;
  final void Function() onStopped;

  @override
  DaemonCredentials get credentials =>
      DaemonCredentials(bearerToken: handle.bearerToken);

  @override
  HostEndpoint get endpoint => HostEndpoint(websocketUri: handle.boundEndpoint);

  @override
  String get serverId => handle.serverId;

  @override
  Future<void> stop() async {
    await handle.stop();
    onStopped();
  }
}

final class _PatchProvider implements ModelGateway {
  int _round = 0;

  @override
  String get id => 'e2e-fake';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    if (_round == 0) {
      _round += 1;
      const patch =
          '*** Begin Patch\n'
          '*** Add File: result.txt\n'
          '+done\n'
          '*** End Patch';
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
    yield const ModelTextDelta('Created result.txt');
    yield const ModelResponseCompleted(
      assistant: AssistantConversationItem(text: 'Created result.txt'),
    );
  }
}

final class _E2eModelDiscovery implements ProviderModelDiscovery {
  const new();

  @override
  Future<List<String>> fetchModelIds(
    ProviderEndpoint endpoint,
    ProviderCredential? credential,
  ) async {
    if (endpoint.baseUrl.contains('/unavailable/')) {
      throw const ProviderDiscoveryFailure(
        ProviderDiscoveryFailureKind.unavailable,
        'planned model discovery outage',
      );
    }
    if (credential case ApiKeyCredential(:final key) when key != 'valid-key') {
      throw const ProviderDiscoveryFailure(
        ProviderDiscoveryFailureKind.invalidCredential,
        'credential rejected by deterministic provider',
      );
    }
    return const <String>[
      'e2e-model',
      'vendor/reasoning-model-with-an-extremely-long-identifier',
    ];
  }
}

final class _AgentE2eProvider implements ModelGateway {
  new(this.attachmentCapturePath);

  final String attachmentCapturePath;
  int _providerFailures = 0;

  @override
  String get id => 'agent-e2e-fake';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    cancellation.throwIfCancelled();
    final latestUser = request.history.whereType<UserConversationItem>().last;
    final latestPrompt = latestUser.text;
    if (latestPrompt == 'Ask me about storage') {
      final answered = request.history
          .whereType<ToolResultConversationItem>()
          .where((item) => item.callId == 'ask-call')
          .firstOrNull;
      if (answered == null) {
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
            <String, dynamic>{
              'id': 'theme',
              'header': 'Theme',
              'question': 'Which theme should the editor use?',
              'options': <Map<String, dynamic>>[
                <String, dynamic>{
                  'label': 'System',
                  'description': 'Follow the operating system.',
                },
                <String, dynamic>{
                  'label': 'Dark',
                  'description': 'Always use the dark theme.',
                },
              ],
            },
            <String, dynamic>{
              'id': 'review',
              'header': 'Review',
              'question': 'How should changes be reviewed?',
              'options': <Map<String, dynamic>>[
                <String, dynamic>{
                  'label': 'Pull request',
                  'description': 'Require a review before merging.',
                },
                <String, dynamic>{
                  'label': 'Direct',
                  'description': 'Merge directly after checks pass.',
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
      final reply =
          answered.output.contains('SQLite') &&
              answered.output.contains('High contrast') &&
              answered.output.contains('Pull request')
          ? 'Chose SQLite, High contrast, and Pull request'
          : 'Chose something else';
      yield ModelTextDelta(reply);
      yield ModelResponseCompleted(
        assistant: AssistantConversationItem(text: reply),
      );
      return;
    }

    // A spawned subagent's turns always carry the NEW_TASK envelope the
    // daemon delivered at its first message boundary.
    final isSubagentTurn = request.history
        .whereType<UserConversationItem>()
        .any((item) => item.text.startsWith('Message Type: NEW_TASK'));
    if (isSubagentTurn) {
      final hasReviewPatchResult = request.history
          .whereType<ToolResultConversationItem>()
          .any((item) => item.callId == 'review-patch-call');
      // The child writes before it answers, which parks its turn on an
      // approval only the user can resolve from the subagent tab.
      if (!hasReviewPatchResult) {
        const patch =
            '*** Begin Patch\n'
            '*** Add File: review.txt\n'
            '+reviewed\n'
            '*** End Patch';
        yield const ModelFunctionCall(
          callId: 'review-patch-call',
          name: 'apply_patch',
          arguments: <String, dynamic>{'patch': patch},
        );
        yield const ModelResponseCompleted(
          assistant: AssistantConversationItem(
            text: '',
            toolCalls: <ConversationToolCall>[
              ConversationToolCall.function(
                callId: 'review-patch-call',
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
    final hasSpawnResult = request.history
        .whereType<ToolResultConversationItem>()
        .any((item) => item.callId == 'spawn-call');
    final hasPatchResult = request.history
        .whereType<ToolResultConversationItem>()
        .any((item) => item.callId == 'patch-call');
    final hasAttachResult = request.history
        .whereType<ToolResultConversationItem>()
        .any((item) => item.callId == 'attach-call');

    if (latestUser.attachments.isNotEmpty) {
      await File(attachmentCapturePath).writeAsString(
        jsonEncode(
          latestUser.attachments
              .map(
                (attachment) => <String, dynamic>{
                  'fileName': attachment.fileName,
                  'bytes': base64Encode(attachment.bytes!),
                },
              )
              .toList(growable: false),
        ),
      );
      yield const ModelTextDelta('Attached fixtures.');
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(text: 'Attached fixtures.'),
      );
      return;
    }

    if (latestPrompt == 'Publish outbound attachment') {
      if (!hasAttachResult) {
        const arguments = <String, dynamic>{'path': 'agent-output.txt'};
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
      yield const ModelTextDelta('Published outbound attachment.');
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: 'Published outbound attachment.',
        ),
      );
      return;
    }

    final hasRejectedPatchResult = request.history
        .whereType<ToolResultConversationItem>()
        .any((item) => item.callId == 'reject-patch-call');
    final hasMcpResult = request.history
        .whereType<ToolResultConversationItem>()
        .any((item) => item.callId == 'mcp-call');
    final hasRejectedMcpResult = request.history
        .whereType<ToolResultConversationItem>()
        .any((item) => item.callId == 'reject-mcp-call');
    final mcpSearchResult = request.history
        .whereType<ToolResultConversationItem>()
        .where((item) => item.callId == 'mcp-search-call')
        .map((item) => item.output)
        .firstOrNull;
    final rejectedMcpSearchResult = request.history
        .whereType<ToolResultConversationItem>()
        .where((item) => item.callId == 'reject-mcp-search-call')
        .map((item) => item.output)
        .firstOrNull;
    final offlineMcpSearchResult = request.history
        .whereType<ToolResultConversationItem>()
        .where((item) => item.callId == 'offline-mcp-search-call')
        .map((item) => item.output)
        .firstOrNull;
    final hasSkillResult = request.history
        .whereType<ToolResultConversationItem>()
        .any((item) => item.callId == 'skill-call');
    final skillListing = request.history
        .whereType<ToolResultConversationItem>()
        .where((item) => item.callId == 'skill-list-call')
        .map((item) => item.output)
        .firstOrNull;
    final excludedSkillListing = request.history
        .whereType<ToolResultConversationItem>()
        .where((item) => item.callId == 'excluded-skill-list-call')
        .map((item) => item.output)
        .firstOrNull;
    final hasDisallowedDelegationResult = request.history
        .whereType<ToolResultConversationItem>()
        .any((item) => item.callId == 'disallowed-delegate-call');

    if (latestPrompt == 'Disallowed delegation' &&
        !hasDisallowedDelegationResult) {
      const arguments = <String, dynamic>{
        'task_name': 'forbidden_task',
        'message': 'This spawn must not start.',
        'agent_type': 'not-allowed',
        'fork_turns': 'none',
        'model': null,
        'reasoning_effort': null,
      };
      yield const ModelFunctionCall(
        callId: 'disallowed-delegate-call',
        name: 'spawn_agent',
        arguments: arguments,
      );
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.function(
              callId: 'disallowed-delegate-call',
              name: 'spawn_agent',
              arguments: arguments,
            ),
          ],
        ),
      );
      return;
    }
    if (latestPrompt == 'Disallowed delegation') {
      yield const ModelTextDelta('Disallowed delegation rejected');
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: 'Disallowed delegation rejected',
        ),
      );
      return;
    }

    if (latestPrompt == 'Use E2E skill' && skillListing == null) {
      // v5 does not inject a host-owned skill catalog into the prompt. The
      // Agent exposes discovery through its selected Lua tool schema instead.
      final prompt = request.blocks.map((block) => block.content).join('\n\n');
      if (!request.tools.any((tool) => tool.name == 'list_skills') ||
          prompt.contains('Loaded during an end-to-end turn.')) {
        throw StateError('the skill tool surface or prompt was incorrect');
      }
      const listArguments = <String, dynamic>{'cursor': null};
      yield const ModelFunctionCall(
        callId: 'skill-list-call',
        name: 'list_skills',
        arguments: listArguments,
      );
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.function(
              callId: 'skill-list-call',
              name: 'list_skills',
              arguments: listArguments,
            ),
          ],
        ),
      );
      return;
    }
    if (latestPrompt == 'Use E2E skill' && !hasSkillResult) {
      // The catalog lives behind the listing tool and every effective skill is
      // available without a separate enablement state.
      if (!skillListing!.contains('invoke-e2e')) {
        throw StateError('effective skill catalog was incorrect');
      }
      const arguments = <String, dynamic>{
        'name': 'invoke-e2e',
        'resource': null,
      };
      yield const ModelFunctionCall(
        callId: 'skill-call',
        name: 'skill',
        arguments: arguments,
      );
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.function(
              callId: 'skill-call',
              name: 'skill',
              arguments: arguments,
            ),
          ],
        ),
      );
      return;
    }
    if (latestPrompt == 'Use E2E skill') {
      yield const ModelTextDelta('Skill loaded');
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(text: 'Skill loaded'),
      );
      return;
    }
    if (latestPrompt == 'Check excluded E2E skills' &&
        excludedSkillListing == null) {
      const listArguments = <String, dynamic>{'cursor': null};
      yield const ModelFunctionCall(
        callId: 'excluded-skill-list-call',
        name: 'list_skills',
        arguments: listArguments,
      );
      // The prompt carries no skill text at all now, so this only guards
      // against a regression that puts the catalog back. That a disabled
      // skill leaves the catalog is pinned by the daemon vertical slice,
      // which asserts on the listing the tool actually returns.
      if (request.blocks.any(
        (block) => block.content.contains('Loaded during an end-to-end turn.'),
      )) {
        throw StateError('disabled skill remained in the turn catalog');
      }
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.function(
              callId: 'excluded-skill-list-call',
              name: 'list_skills',
              arguments: listArguments,
            ),
          ],
        ),
      );
      return;
    }
    if (latestPrompt == 'Check excluded E2E skills') {
      final listing = excludedSkillListing!;
      if (!listing.contains('fallback-e2e') ||
          !listing.contains('Winning project skill.') ||
          listing.contains('invalid-e2e') ||
          listing.contains('Shadowed global skill must stay hidden.')) {
        throw StateError('shadowed or invalid skill catalog was incorrect');
      }
      yield const ModelTextDelta('Excluded skills absent');
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(text: 'Excluded skills absent'),
      );
      return;
    }

    if (latestPrompt == 'Offline MCP' && offlineMcpSearchResult == null) {
      if (!request.tools.any((tool) => tool.name == 'tool_search_mcp')) {
        throw StateError('the selected MCP search tool was not advertised');
      }
      const arguments = <String, dynamic>{'query': 'echo', 'limit': 8};
      yield const ModelDeferredSearchCall(
        callId: 'offline-mcp-search-call',
        name: 'tool_search_mcp',
        arguments: arguments,
      );
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.deferredSearch(
              callId: 'offline-mcp-search-call',
              name: 'tool_search_mcp',
              arguments: arguments,
            ),
          ],
        ),
      );
      return;
    }
    if (latestPrompt == 'Offline MCP') {
      final available = request.tools.any(
        (tool) => tool.name == 'mcp__e2e__echo',
      );
      if (available) throw StateError('offline MCP tool remained available');
      if (offlineMcpSearchResult!.contains('mcp__e2e__echo')) {
        throw StateError('offline MCP tool remained discoverable');
      }
      yield const ModelTextDelta('MCP unavailable safely');
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(text: 'MCP unavailable safely'),
      );
      return;
    }
    if (latestPrompt == 'MCP echo' && mcpSearchResult == null) {
      if (!request.tools.any((tool) => tool.name == 'tool_search_mcp') ||
          request.tools.any((tool) => tool.name == 'mcp__e2e__echo')) {
        throw StateError('MCP search surface was not initially isolated');
      }
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
    if (latestPrompt == 'MCP echo' && !hasMcpResult) {
      if (!mcpSearchResult!.contains('mcp__e2e__echo')) {
        throw StateError('MCP search did not return the echo tool');
      }
      if (!request.tools.any((tool) => tool.name == 'mcp__e2e__echo')) {
        throw StateError('MCP echo tool was not dynamically surfaced');
      }
      const arguments = <String, dynamic>{'value': 'through MCP'};
      yield const ModelFunctionCall(
        callId: 'mcp-call',
        name: 'mcp__e2e__echo',
        arguments: arguments,
      );
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.function(
              callId: 'mcp-call',
              name: 'mcp__e2e__echo',
              arguments: arguments,
            ),
          ],
        ),
      );
      return;
    }
    if (latestPrompt == 'MCP echo') {
      yield const ModelTextDelta('MCP completed');
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(text: 'MCP completed'),
      );
      return;
    }
    if (latestPrompt == 'Reject MCP' && rejectedMcpSearchResult == null) {
      if (!request.tools.any((tool) => tool.name == 'tool_search_mcp')) {
        throw StateError('the selected MCP search tool was not advertised');
      }
      const arguments = <String, dynamic>{'query': 'echo', 'limit': 8};
      yield const ModelDeferredSearchCall(
        callId: 'reject-mcp-search-call',
        name: 'tool_search_mcp',
        arguments: arguments,
      );
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.deferredSearch(
              callId: 'reject-mcp-search-call',
              name: 'tool_search_mcp',
              arguments: arguments,
            ),
          ],
        ),
      );
      return;
    }
    if (latestPrompt == 'Reject MCP' && !hasRejectedMcpResult) {
      if (!rejectedMcpSearchResult!.contains('mcp__e2e__echo') ||
          !request.tools.any((tool) => tool.name == 'mcp__e2e__echo')) {
        throw StateError('rejected MCP tool was not dynamically surfaced');
      }
      const arguments = <String, dynamic>{'value': 'must not run'};
      yield const ModelFunctionCall(
        callId: 'reject-mcp-call',
        name: 'mcp__e2e__echo',
        arguments: arguments,
      );
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.function(
              callId: 'reject-mcp-call',
              name: 'mcp__e2e__echo',
              arguments: arguments,
            ),
          ],
        ),
      );
      return;
    }
    if (latestPrompt == 'Reject MCP') {
      yield const ModelTextDelta('MCP rejected');
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(text: 'MCP rejected'),
      );
      return;
    }

    if (latestPrompt == 'Cancel streaming') {
      yield const ModelTextDelta('Streaming before cancel');
      final cancelled = Completer<void>();
      cancellation.onCancel(cancelled.complete);
      await cancelled.future;
      cancellation.throwIfCancelled();
    }
    if (latestPrompt == 'Recover provider') {
      if (_providerFailures == 0) {
        _providerFailures += 1;
        throw StateError('planned provider outage');
      }
      yield const ModelTextDelta('Provider recovered');
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(text: 'Provider recovered'),
      );
      return;
    }

    if (latestPrompt == 'Delegate review' && !hasSpawnResult) {
      const arguments = <String, dynamic>{
        'task_name': 'review_task',
        'message': 'Review without changing files.',
        'agent_type': 'reviewer',
        'fork_turns': 'none',
        'model': null,
        'reasoning_effort': null,
      };
      yield const ModelFunctionCall(
        callId: 'spawn-call',
        name: 'spawn_agent',
        arguments: arguments,
      );
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.function(
              callId: 'spawn-call',
              name: 'spawn_agent',
              arguments: arguments,
            ),
          ],
        ),
      );
      return;
    }
    if (latestPrompt == 'Delegate review') {
      yield const ModelTextDelta('Parent completed.');
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(text: 'Parent completed.'),
      );
      return;
    }
    if (latestPrompt == 'Create result.txt' && !hasPatchResult) {
      const patch =
          '*** Begin Patch\n'
          '*** Add File: result.txt\n'
          '+done\n'
          '*** End Patch';
      yield const ModelReasoningDelta('패치를 적용할 방법을 정리합니다.');
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
    if (latestPrompt == 'Reject result.txt' && !hasRejectedPatchResult) {
      const patch =
          '*** Begin Patch\n'
          '*** Add File: rejected.txt\n'
          '+nope\n'
          '*** End Patch';
      yield const ModelFunctionCall(
        callId: 'reject-patch-call',
        name: 'apply_patch',
        arguments: <String, dynamic>{'patch': patch},
      );
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.function(
              callId: 'reject-patch-call',
              name: 'apply_patch',
              arguments: <String, dynamic>{'patch': patch},
            ),
          ],
        ),
      );
      return;
    }
    if (latestPrompt == 'Reject result.txt') {
      yield const ModelTextDelta('Rejected safely');
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(text: 'Rejected safely'),
      );
      return;
    }
    if (latestPrompt == 'Show reasoning') {
      yield const ModelReasoningDelta('복원 가능한 사고 요약입니다.');
      yield const ModelTextDelta('Reasoning shown.');
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(text: 'Reasoning shown.'),
      );
      return;
    }
    if (latestPrompt == 'Create result.txt') {
      yield const ModelReasoningDelta('적용 결과를 확인합니다.');
    }
    yield const ModelTextDelta('Created result.txt');
    yield const ModelResponseCompleted(
      assistant: AssistantConversationItem(text: 'Created result.txt'),
    );
  }
}
