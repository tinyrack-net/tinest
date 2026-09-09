import 'dart:async';

import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/features/plugins/presentation/agent_plugin_session_controls.dart';
import 'package:app/src/features/plugins/presentation/agent_plugin_ui_slot.dart';
import 'package:app/src/features/plugins/presentation/plugin_ui_document_view.dart';
import 'package:client/client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/fake_tinest_api.dart';
import '../../support/localization.dart';

void main() {
  testWidgets(
    'renders only Agent-referenced contributions for the requested slot',
    (tester) async {
      const contribution = PluginContributionDto(
        pluginId: 'example.controls',
        id: 'composer',
        kind: PluginContributionKind.ui,
        metadata: <String, dynamic>{
          'slots': <String>['composerControl'],
        },
      );
      const document = PluginUiDocumentDto(
        id: 'composer-document',
        pluginId: 'example.controls',
        revisionHash: 'revision',
        slot: PluginUiSlot.composerControl,
        root: <String, dynamic>{
          'type': 'button',
          'label': 'Continue goal',
          'actionId': 'continue',
        },
      );
      const agent = AgentDefinitionDto(
        version: 5,
        id: 'custom-agent',
        name: 'Custom Agent',
        description: 'Plugin controlled',
        mode: AgentMode.primary,
        model: AgentModelSelectionDto(source: AgentModelSource.session),
        driverId: 'tinest.standard/driver',
        extensionIds: <String>['example.controls'],
        toolIds: <String>[],
        pluginSettings: <String, Map<String, dynamic>>{},
        callableAgentIds: <String>[],
        prompt: '',
        contentHash: 'agent-hash',
        sourcePath: '/config/v5/agents/custom-agent.md',
      );
      final api = FakeTinestApi(
        agentDefinitions: const <AgentDefinitionDto>[agent],
        plugins: const <PluginDescriptorDto>[
          PluginDescriptorDto(
            apiMajor: 5,
            id: 'example.controls',
            version: '1.0.0',
            name: 'Controls',
            entrypoint: 'main.lua',
            source: PluginSource.user,
            sourcePath: '/config/v5/plugins/example.controls',
            requestedCapabilities: <String>[],
            contributions: <PluginContributionDto>[contribution],
          ),
          PluginDescriptorDto(
            apiMajor: 5,
            id: 'example.unreferenced',
            version: '1.0.0',
            name: 'Unreferenced',
            entrypoint: 'main.lua',
            source: PluginSource.user,
            sourcePath: '/config/v5/plugins/example.unreferenced',
            requestedCapabilities: <String>[],
            contributions: <PluginContributionDto>[
              PluginContributionDto(
                pluginId: 'example.unreferenced',
                id: 'composer',
                kind: PluginContributionKind.ui,
                metadata: <String, dynamic>{
                  'slots': <String>['composerControl'],
                },
              ),
            ],
          ),
        ],
        pluginUiDocuments: const <String, PluginUiDocumentDto>{
          'example.controls/composer/custom-agent': document,
        },
      );

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
            home: const Scaffold(
              body: AgentPluginUiSlot(
                hostId: 'server',
                agent: agent,
                slot: PluginUiSlot.composerControl,
                context: <String, dynamic>{'sessionId': 'session-1'},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TRButton, 'Continue goal'), findsOneWidget);
      expect(api.pluginUiRenders, hasLength(1));
      expect(api.pluginUiRenders.single.slot, PluginUiSlot.composerControl);
      // The locale is a host fact of the surface, not something every call
      // site has to remember to pass, so the slot supplies it. Without it a
      // plugin has no way to translate the strings it owns.
      expect(api.pluginUiRenders.single.context, <String, dynamic>{
        'sessionId': 'session-1',
        'locale': 'ko',
      });

      await tester.tap(find.widgetWithText(TRButton, 'Continue goal'));
      await tester.pumpAndSettle();
      expect(api.pluginUiActions.single.actionId, 'continue');
    },
    tags: const <String>['feature_test__plugin_ui__widget'],
  );

  testWidgets(
    'a declared session-tree dependency renders again when the tree moves',
    (tester) async {
      // A declarative surface is drawn on demand, so a panel over the session
      // tree goes stale the moment a subagent's lifecycle moves. Declaring the
      // dependency is what lets the host draw it again; a surface that
      // declares nothing must stay put, or every plugin pays for the watch.
      const live = PluginContributionDto(
        pluginId: 'example.live',
        id: 'tree',
        kind: PluginContributionKind.ui,
        metadata: <String, dynamic>{
          'slots': <String>['composerControl'],
          'dependsOn': <String>['session_tree'],
        },
      );
      const still = PluginContributionDto(
        pluginId: 'example.still',
        id: 'plain',
        kind: PluginContributionKind.ui,
        metadata: <String, dynamic>{
          'slots': <String>['composerControl'],
        },
      );
      const document = PluginUiDocumentDto(
        id: 'tree-document',
        pluginId: 'example.live',
        revisionHash: 'revision',
        slot: PluginUiSlot.composerControl,
        root: <String, dynamic>{'type': 'badge', 'text': 'two agents'},
      );
      const agent = AgentDefinitionDto(
        version: 5,
        id: 'custom-agent',
        name: 'Custom Agent',
        description: 'Plugin controlled',
        mode: AgentMode.primary,
        model: AgentModelSelectionDto(source: AgentModelSource.session),
        driverId: 'tinest.standard/driver',
        extensionIds: <String>['example.live', 'example.still'],
        toolIds: <String>[],
        pluginSettings: <String, Map<String, dynamic>>{},
        callableAgentIds: <String>[],
        prompt: '',
        contentHash: 'agent-hash',
        sourcePath: '/config/v5/agents/custom-agent.md',
      );
      final now = DateTime.utc(2026, 8, 20);
      SessionDto child(SessionStatus status) => SessionDto(
        id: 'child-1',
        worktreeId: 'worktree-1',
        title: 'Child',
        agentDefinitionId: 'custom-agent',
        origin: SessionOrigin.delegated,
        status: status,
        parentSessionId: 'session-1',
        rootSessionId: 'session-1',
        taskName: 'reviewer',
        agentPath: '/root/reviewer',
        lifecycle: AgentLifecycle.running,
        createdAt: now,
        updatedAt: now,
      );
      final parent = SessionDto(
        id: 'session-1',
        worktreeId: 'worktree-1',
        title: 'Parent',
        agentDefinitionId: 'custom-agent',
        origin: SessionOrigin.manual,
        status: SessionStatus.running,
        rootSessionId: 'session-1',
        createdAt: now,
        updatedAt: now,
      );
      final api = FakeTinestApi(
        agentDefinitions: const <AgentDefinitionDto>[agent],
        agents: <SessionDto>[parent, child(SessionStatus.running)],
        plugins: const <PluginDescriptorDto>[
          PluginDescriptorDto(
            apiMajor: 5,
            id: 'example.live',
            version: '1.0.0',
            name: 'Live',
            entrypoint: 'main.lua',
            source: PluginSource.user,
            sourcePath: '/config/v5/plugins/example.live',
            requestedCapabilities: <String>[],
            contributions: <PluginContributionDto>[live],
          ),
          PluginDescriptorDto(
            apiMajor: 5,
            id: 'example.still',
            version: '1.0.0',
            name: 'Still',
            entrypoint: 'main.lua',
            source: PluginSource.user,
            sourcePath: '/config/v5/plugins/example.still',
            requestedCapabilities: <String>[],
            contributions: <PluginContributionDto>[still],
          ),
        ],
        pluginUiDocuments: const <String, PluginUiDocumentDto>{
          'example.live/tree/custom-agent': document,
          'example.still/plain/custom-agent': document,
        },
      );

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
            home: const Scaffold(
              body: AgentPluginUiSlot(
                hostId: 'server',
                agent: agent,
                slot: PluginUiSlot.composerControl,
                context: <String, dynamic>{
                  'sessionId': 'session-1',
                  'worktreeId': 'worktree-1',
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final firstRenders = api.pluginUiRenders.length;
      expect(firstRenders, 2);
      final declaredContext = api.pluginUiRenders
          .firstWhere((render) => render.pluginId == 'example.live')
          .context;
      final undeclaredContext = api.pluginUiRenders
          .firstWhere((render) => render.pluginId == 'example.still')
          .context;
      expect(declaredContext, contains('sessionTreeRevision'));
      expect(undeclaredContext, isNot(contains('sessionTreeRevision')));

      api.emit(
        SessionUpdatedClientEvent(child(SessionStatus.waitingForApproval)),
      );
      await tester.pumpAndSettle();

      final live2 = api.pluginUiRenders
          .where((render) => render.pluginId == 'example.live')
          .length;
      final still2 = api.pluginUiRenders
          .where((render) => render.pluginId == 'example.still')
          .length;
      expect(live2, 2, reason: 'the declared surface renders again');
      expect(still2, 1, reason: 'an undeclared surface is left alone');
    },
    tags: const <String>['feature_test__plugin_ui__widget'],
  );

  testWidgets(
    'does not invoke a contribution registered for a different slot',
    (tester) async {
      const agent = AgentDefinitionDto(
        version: 5,
        id: 'custom-agent',
        name: 'Custom Agent',
        description: 'Plugin controlled',
        mode: AgentMode.primary,
        model: AgentModelSelectionDto(source: AgentModelSource.session),
        driverId: 'example.controls/driver',
        extensionIds: <String>[],
        toolIds: <String>[],
        pluginSettings: <String, Map<String, dynamic>>{},
        callableAgentIds: <String>[],
        prompt: '',
        contentHash: 'agent-hash',
        sourcePath: '/config/v5/agents/custom-agent.md',
      );
      final api = FakeTinestApi(
        agentDefinitions: const <AgentDefinitionDto>[agent],
        plugins: const <PluginDescriptorDto>[
          PluginDescriptorDto(
            apiMajor: 5,
            id: 'example.controls',
            version: '1.0.0',
            name: 'Controls',
            entrypoint: 'main.lua',
            source: PluginSource.user,
            sourcePath: '/config/v5/plugins/example.controls',
            requestedCapabilities: <String>[],
            contributions: <PluginContributionDto>[
              PluginContributionDto(
                pluginId: 'example.controls',
                id: 'settings',
                kind: PluginContributionKind.ui,
                metadata: <String, dynamic>{
                  'slots': <String>['agentSettings'],
                },
              ),
            ],
          ),
        ],
      );

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
            home: const Scaffold(
              body: AgentPluginUiSlot(
                hostId: 'server',
                agent: agent,
                slot: PluginUiSlot.conversationStatus,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(api.pluginUiRenders, isEmpty);
      expect(find.byType(PluginUiDocumentView), findsNothing);
    },
    tags: const <String>['feature_test__plugin_ui__widget'],
  );

  testWidgets('a contribution with nothing to report leaves no panel behind', (
    tester,
  ) async {
    const status = PluginContributionDto(
      pluginId: 'example.status',
      id: 'status',
      kind: PluginContributionKind.ui,
      metadata: <String, dynamic>{
        'slots': <String>['conversationStatus'],
      },
    );
    const goal = PluginContributionDto(
      pluginId: 'example.goal',
      id: 'goal',
      kind: PluginContributionKind.ui,
      metadata: <String, dynamic>{
        'slots': <String>['conversationStatus'],
      },
    );
    const agent = AgentDefinitionDto(
      version: 5,
      id: 'custom-agent',
      name: 'Custom Agent',
      description: 'Plugin controlled',
      mode: AgentMode.primary,
      model: AgentModelSelectionDto(source: AgentModelSource.session),
      driverId: 'tinest.standard/driver',
      extensionIds: <String>['example.status', 'example.goal'],
      toolIds: <String>[],
      pluginSettings: <String, Map<String, dynamic>>{},
      callableAgentIds: <String>[],
      prompt: '',
      contentHash: 'agent-hash',
      sourcePath: '/config/v5/agents/custom-agent.md',
    );
    final api = FakeTinestApi(
      agentDefinitions: const <AgentDefinitionDto>[agent],
      plugins: const <PluginDescriptorDto>[
        PluginDescriptorDto(
          apiMajor: 5,
          id: 'example.status',
          version: '1.0.0',
          name: 'Status',
          entrypoint: 'main.lua',
          source: PluginSource.user,
          sourcePath: '/config/v5/plugins/example.status',
          requestedCapabilities: <String>[],
          contributions: <PluginContributionDto>[status],
        ),
        PluginDescriptorDto(
          apiMajor: 5,
          id: 'example.goal',
          version: '1.0.0',
          name: 'Goal',
          entrypoint: 'main.lua',
          source: PluginSource.user,
          sourcePath: '/config/v5/plugins/example.goal',
          requestedCapabilities: <String>[],
          contributions: <PluginContributionDto>[goal],
        ),
      ],
      pluginUiDocuments: const <String, PluginUiDocumentDto>{
        'example.status/status/custom-agent': PluginUiDocumentDto(
          id: 'status-document',
          pluginId: 'example.status',
          revisionHash: 'revision',
          slot: PluginUiSlot.conversationStatus,
          root: <String, dynamic>{'type': 'section', 'children': <Object?>[]},
        ),
        'example.goal/goal/custom-agent': PluginUiDocumentDto(
          id: 'goal-document',
          pluginId: 'example.goal',
          revisionHash: 'revision',
          slot: PluginUiSlot.conversationStatus,
          root: <String, dynamic>{'type': 'badge', 'text': 'active'},
        ),
      },
    );

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
          home: const Scaffold(
            body: AgentPluginUiSlot(
              hostId: 'server',
              agent: agent,
              slot: PluginUiSlot.conversationStatus,
              context: <String, dynamic>{'sessionId': 'session-1'},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // An empty section is how a status contribution says it has nothing to
    // report. Framing it would park a bare card beside the composer of every
    // session, so the surface renders nothing at all — and the separator it
    // would have been given goes with it, leaving the sibling that does draw
    // flush against the top edge.
    expect(find.byType(TRCard), findsNothing);
    expect(find.text('active'), findsOneWidget);
    expect(api.pluginUiRenders, hasLength(2));
    expect(
      tester
          .widgetList<PluginUiContributionSurface>(
            find.byType(PluginUiContributionSurface),
          )
          .map((surface) => surface.leadingSpacing)
          .toList(growable: false),
      <double>[0, 0],
    );
  }, tags: const <String>['feature_test__plugin_ui__widget']);

  testWidgets('a rejected render is translated and keeps its trace id', (
    tester,
  ) async {
    const contribution = PluginContributionDto(
      pluginId: 'example.controls',
      id: 'status',
      kind: PluginContributionKind.ui,
      metadata: <String, dynamic>{
        'slots': <String>['conversationStatus'],
      },
    );
    const agent = AgentDefinitionDto(
      version: 5,
      id: 'custom-agent',
      name: 'Custom Agent',
      description: 'Plugin controlled',
      mode: AgentMode.primary,
      model: AgentModelSelectionDto(source: AgentModelSource.session),
      driverId: 'tinest.standard/driver',
      extensionIds: <String>['example.controls'],
      toolIds: <String>[],
      pluginSettings: <String, Map<String, dynamic>>{},
      callableAgentIds: <String>[],
      prompt: '',
      contentHash: 'agent-hash',
      sourcePath: '/config/v5/agents/custom-agent.md',
    );
    final api =
        FakeTinestApi(
            agentDefinitions: const <AgentDefinitionDto>[agent],
            plugins: const <PluginDescriptorDto>[
              PluginDescriptorDto(
                apiMajor: 5,
                id: 'example.controls',
                version: '1.0.0',
                name: 'Controls',
                entrypoint: 'main.lua',
                source: PluginSource.user,
                sourcePath: '/config/v5/plugins/example.controls',
                requestedCapabilities: <String>[],
                contributions: <PluginContributionDto>[contribution],
              ),
            ],
          )
          ..pluginUiRenderFailure = const TinestClientException(
            'Plugin UI callback failed.',
            code: RpcErrorCodes.pluginUiRejected,
            details: <String, dynamic>{'traceId': 'trace-42'},
          );

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
          home: const Scaffold(
            body: AgentPluginUiSlot(
              hostId: 'server',
              agent: agent,
              slot: PluginUiSlot.conversationStatus,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The user reads the translated reason, never the raw exception; the
    // trace id stays so a bug report still points at the daemon log record.
    expect(find.text(testL10n.pluginUiLoadFailed), findsOneWidget);
    expect(find.text(testL10n.errorPluginUiRejected), findsOneWidget);
    expect(find.textContaining('traceId: trace-42'), findsOneWidget);
    expect(find.textContaining('TinestClientException'), findsNothing);
    expect(find.widgetWithText(TRButton, testL10n.commonRetry), findsOneWidget);
  }, tags: const <String>['feature_test__plugin_ui__widget']);

  testWidgets(
    'a session that has never run shows no slot rather than an error',
    (tester) async {
      const contribution = PluginContributionDto(
        pluginId: 'example.controls',
        id: 'status',
        kind: PluginContributionKind.ui,
        metadata: <String, dynamic>{
          'slots': <String>['conversationStatus'],
        },
      );
      const agent = AgentDefinitionDto(
        version: 5,
        id: 'custom-agent',
        name: 'Custom Agent',
        description: 'Plugin controlled',
        mode: AgentMode.primary,
        model: AgentModelSelectionDto(source: AgentModelSource.session),
        driverId: 'tinest.standard/driver',
        extensionIds: <String>['example.controls'],
        toolIds: <String>[],
        pluginSettings: <String, Map<String, dynamic>>{},
        callableAgentIds: <String>[],
        prompt: '',
        contentHash: 'agent-hash',
        sourcePath: '/config/v5/agents/custom-agent.md',
      );
      final api =
          FakeTinestApi(
              agentDefinitions: const <AgentDefinitionDto>[agent],
              plugins: const <PluginDescriptorDto>[
                PluginDescriptorDto(
                  apiMajor: 5,
                  id: 'example.controls',
                  version: '1.0.0',
                  name: 'Controls',
                  entrypoint: 'main.lua',
                  source: PluginSource.user,
                  sourcePath: '/config/v5/plugins/example.controls',
                  requestedCapabilities: <String>[],
                  contributions: <PluginContributionDto>[contribution],
                ),
              ],
            )
            ..pluginUiRenderFailure = const TinestClientException(
              'Agent custom-agent has no active revision for plugin '
              'example.controls.',
              code: RpcErrorCodes.pluginRevisionUnavailable,
            );

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
            home: const Scaffold(
              body: AgentPluginUiSlot(
                hostId: 'server',
                agent: agent,
                slot: PluginUiSlot.conversationStatus,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // An Agent pins its plugin revisions when a turn starts, so this is the
      // ordinary state of a conversation before its first message. Reporting
      // it would put a red panel beside every new session's composer.
      expect(find.text(testL10n.pluginUiLoadFailed), findsNothing);
      expect(find.byType(TRAlert), findsNothing);
    },
    tags: const <String>['feature_test__plugin_ui__widget'],
  );

  testWidgets(
    'Agent extension session control toggles through the typed plugin RPC',
    (tester) async {
      const agent = AgentDefinitionDto(
        version: 5,
        id: 'plan-agent',
        name: 'Plan Agent',
        description: '',
        mode: AgentMode.primary,
        model: AgentModelSelectionDto(source: AgentModelSource.session),
        driverId: 'tinest.standard/driver',
        extensionIds: <String>['tinest.plan'],
        toolIds: <String>[],
        pluginSettings: <String, Map<String, dynamic>>{},
        callableAgentIds: <String>[],
        prompt: '',
        contentHash: 'agent-hash',
        sourcePath: '/config/v5/agents/plan-agent.md',
      );
      const plugin = PluginDescriptorDto(
        apiMajor: 5,
        id: 'tinest.plan',
        version: '1.0.0',
        name: 'Plan',
        entrypoint: 'main.lua',
        source: PluginSource.builtIn,
        sourcePath: '/built-in/tinest.plan',
        requestedCapabilities: <String>[],
        contributions: <PluginContributionDto>[
          PluginContributionDto(
            pluginId: 'tinest.plan',
            id: 'tinest.plan/mode',
            kind: PluginContributionKind.sessionControl,
            metadata: <String, dynamic>{
              'label': 'Plan',
              'schema': <String, dynamic>{'type': 'boolean'},
            },
          ),
        ],
      );
      const control = PluginSessionControlValueDto(
        sessionId: 'session-1',
        agentId: 'plan-agent',
        pluginId: 'tinest.plan',
        contributionId: 'tinest.plan/mode',
        revisionHash: 'plan-revision',
        schema: <String, dynamic>{'type': 'boolean'},
        defaultValue: false,
        value: false,
        isDefault: true,
        metadata: <String, dynamic>{'label': 'Plan'},
      );
      final api = FakeTinestApi(
        agentDefinitions: const <AgentDefinitionDto>[agent],
        plugins: const <PluginDescriptorDto>[plugin],
        pluginSessionControls: const <String, PluginSessionControlValueDto>{
          'session-1/tinest.plan/tinest.plan/mode': control,
        },
      );

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
            home: const Scaffold(
              body: AgentPluginSessionControls(
                hostId: 'server',
                sessionId: 'session-1',
                agent: agent,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final finder = find.byKey(
        const ValueKey<String>('plugin-session-control-tinest.plan/mode'),
      );
      expect(tester.widget<TRSwitch>(finder).checked, isFalse);
      await tester.tap(finder);
      await tester.pumpAndSettle();

      expect(api.pluginSessionControlSets, hasLength(1));
      expect(api.pluginSessionControlSets.single.value, isTrue);
      expect(tester.widget<TRSwitch>(finder).checked, isTrue);
    },
    tags: const <String>[
      'feature_test__agent_harness__widget',
      'feature_test__plugin_runtime__widget',
      'feature_test__session_plan__widget',
    ],
  );

  testWidgets(
    'session controls render enum choices and explain unsupported schemas',
    (tester) async {
      const agent = AgentDefinitionDto(
        version: 5,
        id: 'controls-agent',
        name: 'Controls Agent',
        description: '',
        mode: AgentMode.primary,
        model: AgentModelSelectionDto(source: AgentModelSource.session),
        driverId: 'tinest.standard/driver',
        extensionIds: <String>['example.controls'],
        toolIds: <String>[],
        pluginSettings: <String, Map<String, dynamic>>{},
        callableAgentIds: <String>[],
        prompt: '',
        contentHash: 'controls-agent-hash',
        sourcePath: '/config/v5/agents/controls-agent.md',
      );
      const plugin = PluginDescriptorDto(
        apiMajor: 5,
        id: 'example.controls',
        version: '1.0.0',
        name: 'Controls',
        entrypoint: 'main.lua',
        source: PluginSource.user,
        sourcePath: '/config/v5/plugins/example.controls',
        requestedCapabilities: <String>[],
        contributions: <PluginContributionDto>[
          PluginContributionDto(
            pluginId: 'example.controls',
            id: 'example.controls/style',
            kind: PluginContributionKind.sessionControl,
            metadata: <String, dynamic>{
              'label': 'Response style',
              'description': 'Choose how detailed responses should be.',
            },
          ),
          PluginContributionDto(
            pluginId: 'example.controls',
            id: 'example.controls/unsupported',
            kind: PluginContributionKind.sessionControl,
          ),
        ],
      );
      const style = PluginSessionControlValueDto(
        sessionId: 'session-1',
        agentId: 'controls-agent',
        pluginId: 'example.controls',
        contributionId: 'example.controls/style',
        revisionHash: 'controls-revision',
        schema: <String, dynamic>{
          'type': 'string',
          'enum': <Object?>['concise', 7, 'detailed'],
        },
        defaultValue: 'concise',
        value: 'concise',
        isDefault: true,
      );
      const unsupported = PluginSessionControlValueDto(
        sessionId: 'session-1',
        agentId: 'controls-agent',
        pluginId: 'example.controls',
        contributionId: 'example.controls/unsupported',
        revisionHash: 'controls-revision',
        schema: <String, dynamic>{'type': 'integer'},
        defaultValue: 1,
        value: 1,
        isDefault: true,
      );
      final api = FakeTinestApi(
        agentDefinitions: const <AgentDefinitionDto>[agent],
        plugins: const <PluginDescriptorDto>[plugin],
        pluginSessionControls: const <String, PluginSessionControlValueDto>{
          'session-1/example.controls/example.controls/style': style,
          'session-1/example.controls/example.controls/unsupported':
              unsupported,
        },
      );

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
            home: const Scaffold(
              body: AgentPluginSessionControls(
                hostId: 'server',
                sessionId: 'session-1',
                agent: agent,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final selectFinder = find.byKey(
        const ValueKey<String>('plugin-session-control-example.controls/style'),
      );
      final select = tester.widget<TRSelect<String>>(selectFinder);
      expect(select.value, 'concise');
      expect(select.presentation, isA<TRSelectLayerPresentation>());
      expect(select.items.map((item) => item.value), <String>[
        'concise',
        'detailed',
      ]);
      final field = tester.widget<TRField>(find.byType(TRField));
      expect(field.label, 'Response style');
      expect(field.description, 'Choose how detailed responses should be.');
      expect(find.text('example.controls/unsupported'), findsOneWidget);

      select.onValueChange?.call(null);
      select.onValueChange?.call('detailed');
      await tester.pumpAndSettle();

      expect(api.pluginSessionControlSets, hasLength(1));
      expect(api.pluginSessionControlSets.single.value, 'detailed');
      expect(tester.widget<TRSelect<String>>(selectFinder).value, 'detailed');
    },
    tags: const <String>[
      'feature_test__agent_harness__widget',
      'feature_test__plugin_runtime__widget',
    ],
  );

  testWidgets(
    'a re-render keeps the rendered document instead of blanking to a spinner',
    (tester) async {
      // The conversation slot sits between the transcript and the composer and
      // takes `busy` in its render context, so it re-renders on every turn
      // boundary. Collapsing to a spinner and back changes the timeline's
      // viewport height twice per send, which the reader sees as the list
      // jumping rather than as this surface reloading.
      const contribution = PluginContributionDto(
        pluginId: 'example.controls',
        id: 'status',
        kind: PluginContributionKind.ui,
        metadata: <String, dynamic>{
          'slots': <String>['conversationStatus'],
        },
      );
      const document = PluginUiDocumentDto(
        id: 'status-document',
        pluginId: 'example.controls',
        revisionHash: 'revision',
        slot: PluginUiSlot.conversationStatus,
        root: <String, dynamic>{'type': 'text', 'text': 'Working on it'},
      );
      const agent = AgentDefinitionDto(
        version: 5,
        id: 'custom-agent',
        name: 'Custom Agent',
        description: 'Plugin controlled',
        mode: AgentMode.primary,
        model: AgentModelSelectionDto(source: AgentModelSource.session),
        driverId: 'tinest.standard/driver',
        extensionIds: <String>['example.controls'],
        toolIds: <String>[],
        pluginSettings: <String, Map<String, dynamic>>{},
        callableAgentIds: <String>[],
        prompt: '',
        contentHash: 'agent-hash',
        sourcePath: '/config/v5/agents/custom-agent.md',
      );
      final api = FakeTinestApi(
        agentDefinitions: const <AgentDefinitionDto>[agent],
        plugins: const <PluginDescriptorDto>[
          PluginDescriptorDto(
            apiMajor: 5,
            id: 'example.controls',
            version: '1.0.0',
            name: 'Controls',
            entrypoint: 'main.lua',
            source: PluginSource.user,
            sourcePath: '/config/v5/plugins/example.controls',
            requestedCapabilities: <String>[],
            contributions: <PluginContributionDto>[contribution],
          ),
        ],
        pluginUiDocuments: const <String, PluginUiDocumentDto>{
          'example.controls/status/custom-agent': document,
        },
      );

      // One scope for the whole test: the slot has to survive the context
      // change, so re-pumping a fresh container would reload it either way and
      // prove nothing.
      final busy = ValueNotifier<bool>(false);
      addTearDown(busy.dispose);
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
              body: ValueListenableBuilder<bool>(
                valueListenable: busy,
                builder: (context, value, _) => AgentPluginUiSlot(
                  hostId: 'server',
                  agent: agent,
                  slot: PluginUiSlot.conversationStatus,
                  context: <String, dynamic>{
                    'sessionId': 'session-1',
                    'busy': value,
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Working on it'), findsOneWidget);
      expect(api.pluginUiRenders, hasLength(1));

      // The turn starts: the context changes and a second render goes out.
      api.pluginUiRenderGate = Completer<void>();
      busy.value = true;
      for (var frame = 0; frame < 3; frame += 1) {
        await tester.pump();
      }
      expect(api.pluginUiRenders, hasLength(2));
      expect(
        find.byType(TRProgress),
        findsNothing,
        reason: 'a refresh is not a first load; there is already a document',
      );
      expect(
        find.text('Working on it'),
        findsOneWidget,
        reason: 'the surface keeps its height while the re-render is in flight',
      );

      api.pluginUiRenderGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Working on it'), findsOneWidget);
    },
    tags: const <String>['feature_test__plugin_ui__widget'],
  );
}
