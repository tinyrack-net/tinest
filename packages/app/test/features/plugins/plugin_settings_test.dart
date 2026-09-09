import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/features/plugins/presentation/plugin_ui_document_view.dart';
import 'package:app/src/shared/presentation/settings_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/fake_tinest_api.dart';
import '../../support/localization.dart';

void main() {
  testWidgets(
    'plugin settings exposes source revision grants references and native UI',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi(
        agentDefinitions: const <AgentDefinitionDto>[_tinestAgent],
        plugins: const <PluginDescriptorDto>[_planPlugin, _userPlugin],
        pluginUiDocuments: const <String, PluginUiDocumentDto>{
          'tinest.plan/settings/tinest': _planUi,
        },
      );
      final router = await _pumpPlugins(tester, api);
      addTearDown(router.dispose);

      expect(find.text('플러그인'), findsWidgets);
      expect(find.text('Plan'), findsWidgets);
      expect(find.text('tinest.plan'), findsWidgets);
      expect(find.text('내장'), findsWidgets);
      expect(find.text('API 5'), findsOneWidget);
      final openPath = tester.widget<TRIconButton>(
        find.byKey(const ValueKey<String>('plugin-open-path-button')),
      );
      expect(openPath.onPressed, isNull);
      expect(
        find.byKey(const ValueKey<String>('plugin-fork-button')),
        findsOneWidget,
      );
      expect(find.text(_planRevisionLabel), findsOneWidget);
      expect(find.text('state.agent'), findsWidgets);
      expect(find.text('Tinest'), findsWidgets);
      expect(find.text('settings'), findsWidgets);
      final reloadAgent = tester.widget<TRSelect<String>>(
        find.byKey(const ValueKey<String>('plugin-reload-agent')),
      );
      expect(reloadAgent.presentation, isA<TRSelectLayerPresentation>());
      await tester.scrollUntilVisible(
        find.text('Plan controls'),
        300,
        scrollable: find.descendant(
          of: find.byType(SettingsScaffold),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Plan controls'), findsOneWidget);
      expect(find.byType(PluginUiDocumentView), findsOneWidget);
      expect(find.byType(TRSwitch), findsNothing);

      // Reload belongs to the source section rather than the page header, so
      // reading the controls below scrolls it away and it has to come back.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('plugin-reload-button')),
        -300,
        scrollable: find.descendant(
          of: find.byType(SettingsScaffold),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('plugin-reload-button')));
      await tester.pumpAndSettle();
      expect(api.reloadedPlugins, <({String agentId, String pluginId})>[
        (agentId: 'tinest', pluginId: 'tinest.plan'),
      ]);

      await tester.tap(find.text('example.tools').first);
      await tester.pumpAndSettle();
      expect(find.text('사용자'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('invalid_manifest'),
        300,
        scrollable: find.descendant(
          of: find.byType(SettingsScaffold),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('invalid_manifest'), findsOneWidget);
      expect(find.text('Manifest is invalid.'), findsOneWidget);
      expect(
        tester
            .widget<TRIconButton>(
              find.byKey(const ValueKey<String>('plugin-open-path-button')),
            )
            .onPressed,
        isNotNull,
      );
    },
    tags: const <String>[
      'feature_test__plugin_management__widget',
      'feature_test__plugin_ui__widget',
      'route_test__plugin_settings_route__widget',
    ],
  );

  testWidgets(
    'forks a validated plugin through a native dialog without enabling it',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi(
        agentDefinitions: const <AgentDefinitionDto>[_tinestAgent],
        plugins: const <PluginDescriptorDto>[_planPlugin],
      );
      final router = await _pumpPlugins(tester, api);
      addTearDown(router.dispose);

      await tester.tap(
        find.byKey(const ValueKey<String>('plugin-fork-button')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TRDialog), findsOneWidget);
      await tester.enterText(_field('플러그인 ID'), 'example.plan');
      await tester.enterText(_field('이름'), 'Plan fork');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TRButton, '복제'));
      await tester.pumpAndSettle();

      expect(api.forkedPlugins, <(String, String, String)>[
        ('tinest.plan', 'example.plan', 'Plan fork'),
      ]);
      expect(find.text('Plan fork'), findsWidgets);
      expect(find.byType(TRSwitch), findsNothing);
    },
    tags: const <String>['feature_test__plugin_management__widget'],
  );

  testWidgets(
    'plugin settings route opens list then detail on a narrow surface',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi(
        agentDefinitions: const <AgentDefinitionDto>[_tinestAgent],
        plugins: const <PluginDescriptorDto>[_planPlugin],
        pluginUiDocuments: const <String, PluginUiDocumentDto>{
          'tinest.plan/settings/tinest': _planUi,
        },
      );
      final router = await _pumpPlugins(tester, api);
      addTearDown(router.dispose);

      expect(find.text(_planRevisionLabel), findsNothing);
      await tester.tap(find.text('Plan').first);
      await tester.pumpAndSettle();
      expect(find.text(_planRevisionLabel), findsOneWidget);

      // The revision keeps its own row: a digest shown whole took the entire
      // line, wrapped the label one character per line, and still overflowed.
      final pane = tester.getRect(find.byType(SettingsScaffold));
      expect(
        tester.getRect(find.text(_planRevisionLabel)).right,
        lessThanOrEqualTo(pane.right),
      );
      expect(
        tester.getRect(find.text('활성 리비전')).width,
        greaterThan(TRMeasurements.measureXs),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('settings-back-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text(_planRevisionLabel), findsNothing);
      expect(find.byKey(const ValueKey('plugin-add-button')), findsOneWidget);
    },
    tags: const <String>[
      'feature_test__plugin_management__widget',
      'route_test__plugin_settings_route__widget',
    ],
  );

  testWidgets('keeps the revision inside its row at a large text scale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = FakeTinestApi(
      agentDefinitions: const <AgentDefinitionDto>[_tinestAgent],
      plugins: const <PluginDescriptorDto>[_planPlugin],
    );
    final router = await _pumpPlugins(
      tester,
      api,
      textScaler: const TextScaler.linear(2),
    );
    addTearDown(router.dispose);
    await tester.tap(find.text('Plan').first);
    await tester.pumpAndSettle();

    // Scaled up, the digest and its label no longer share a line, so the
    // row hands the whole width to each in turn instead of overflowing.
    final label = tester.getRect(find.text('활성 리비전'));
    final revision = tester.getRect(find.text(_planRevisionLabel));
    expect(revision.top, greaterThan(label.bottom));
    expect(revision.right, lessThanOrEqualTo(390));
  }, tags: const <String>['feature_test__plugin_management__widget']);

  testWidgets(
    'creates an app-data plugin starter without a global enable control',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi(
        agentDefinitions: const <AgentDefinitionDto>[_tinestAgent],
        plugins: const <PluginDescriptorDto>[_planPlugin],
        pluginUiDocuments: const <String, PluginUiDocumentDto>{
          'tinest.plan/settings/tinest': _planUi,
        },
      );
      final router = await _pumpPlugins(tester, api);
      addTearDown(router.dispose);

      await tester.tap(find.byKey(const ValueKey('plugin-add-button')));
      await tester.pumpAndSettle();
      await tester.enterText(_field('플러그인 ID'), 'example.review');
      await tester.enterText(_field('이름'), 'Review tools');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TRButton, '생성'));
      await tester.pumpAndSettle();

      expect(
        (await api.plugins.listPlugins()).map((plugin) => plugin.id),
        contains('example.review'),
      );
      expect(find.text('Review tools'), findsWidgets);
      expect(find.byType(TRSwitch), findsNothing);
    },
    tags: const <String>['feature_test__plugin_management__widget'],
  );

  testWidgets(
    'external plugin edits refresh the descriptor and LKG diagnostic',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi(
        agentDefinitions: const <AgentDefinitionDto>[_tinestAgent],
        plugins: const <PluginDescriptorDto>[_planPlugin],
        pluginUiDocuments: const <String, PluginUiDocumentDto>{
          'tinest.plan/settings/tinest': _planUi,
        },
      );
      final router = await _pumpPlugins(tester, api);
      addTearDown(router.dispose);
      expect(find.text(_planRevisionLabel), findsOneWidget);

      api.emitPluginChange(
        _planPlugin.copyWith(
          isStale: true,
          diagnostics: const <PluginDiagnosticDto>[
            PluginDiagnosticDto(
              code: 'invalid_plugin_definition',
              message: 'Lua definition is invalid.',
              severity: PluginDiagnosticSeverity.error,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('invalid_plugin_definition'), findsOneWidget);
      expect(find.text('Lua definition is invalid.'), findsOneWidget);
      expect(find.text(_planRevisionLabel), findsOneWidget);
    },
    tags: const <String>['feature_test__plugin_management__widget'],
  );

  testWidgets(
    'user plugin exposes SDK ABI status and synchronizes LuaLS sidecars',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi(
        agentDefinitions: const <AgentDefinitionDto>[_tinestAgent],
        plugins: const <PluginDescriptorDto>[_userPlugin],
        pluginAuthoringEnvironments:
            const <String, PluginAuthoringEnvironmentDto>{
              'example.tools': _unsynchronizedAuthoring,
            },
      );
      final router = await _pumpPlugins(tester, api);
      addTearDown(router.dispose);
      await tester.tap(find.text('Example tools').first);
      await tester.pumpAndSettle();

      expect(find.text('Lua 개발 환경'), findsOneWidget);
      expect(find.text('동기화 필요'), findsOneWidget);
      expect(find.text('SDK ABI'), findsOneWidget);
      expect(find.text(_sdkAbiLabel), findsOneWidget);
      expect(find.text('luarc_missing'), findsOneWidget);
      expect(
        find.text('The LuaLS workspace configuration is missing.'),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('plugin-sdk-sync-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('plugin-sdk-sync-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('동기화됨'), findsOneWidget);
      expect(find.text('luarc_missing'), findsNothing);
    },
    tags: const <String>[
      'feature_test__plugin_authoring__widget',
      'route_test__plugin_settings_route__widget',
    ],
  );
}

/// A revision digest in the shape the daemon produces: a full sha256 hash.
const _planContentHash =
    'a71d7554b33bc6f9e462e185d0c2f4b8e3a19c6d5f78b0e2a4c6d8f0b2e4a6c8';

/// The leading characters of [_planContentHash] a settings row shows.
const _planRevisionLabel = 'a71d7554b33b';

/// The SDK ABI digest, which the daemon derives the same way.
const _sdkAbiHash =
    'c0ffee1234567890abcdef1234567890abcdef1234567890abcdef1234567890';

/// The leading characters of [_sdkAbiHash] a settings row shows.
const _sdkAbiLabel = 'c0ffee123456';

const _planPlugin = PluginDescriptorDto(
  apiMajor: 5,
  id: 'tinest.plan',
  version: '1.0.0',
  name: 'Plan',
  entrypoint: 'main.lua',
  source: PluginSource.builtIn,
  sourcePath: r'C:\Program Files\Tinest\plugins\tinest.plan',
  requestedCapabilities: <String>['state.agent'],
  revision: PluginRevisionDto(
    pluginId: 'tinest.plan',
    contentHash: _planContentHash,
    manifestHash: 'plan-manifest',
    sdkAbiHash: 'sdk-abi-hash',
    executionRevisionHash: 'plan-execution-revision',
    requestedCapabilities: <String>['state.agent'],
  ),
  contributions: <PluginContributionDto>[
    PluginContributionDto(
      pluginId: 'tinest.plan',
      id: 'settings',
      kind: PluginContributionKind.ui,
      metadata: <String, dynamic>{
        'slots': <String>['agentSettings'],
      },
    ),
    PluginContributionDto(
      pluginId: 'tinest.plan',
      id: 'update_plan',
      kind: PluginContributionKind.tool,
      requiredCapabilities: <String>['state.agent'],
    ),
  ],
);

const _tinestAgent = AgentDefinitionDto(
  version: 5,
  id: 'tinest',
  name: 'Tinest',
  description: 'General-purpose coding agent',
  mode: AgentMode.primary,
  model: AgentModelSelectionDto(source: AgentModelSource.session),
  driverId: 'tinest.standard/driver',
  extensionIds: <String>['tinest.plan'],
  toolIds: <String>['tinest.plan/update_plan'],
  pluginSettings: <String, Map<String, dynamic>>{'tinest.plan': {}},
  callableAgentIds: <String>[],
  prompt: 'Code carefully.',
  contentHash: 'tinest-hash',
  sourcePath: '/config/v5/agents/tinest.md',
  isBuiltIn: true,
);

const _userPlugin = PluginDescriptorDto(
  apiMajor: 5,
  id: 'example.tools',
  version: '0.1.0',
  name: 'Example tools',
  entrypoint: 'main.lua',
  source: PluginSource.user,
  sourcePath: r'C:\config\v5\plugins\example.tools',
  requestedCapabilities: <String>[],
  diagnostics: <PluginDiagnosticDto>[
    PluginDiagnosticDto(
      code: 'invalid_manifest',
      message: 'Manifest is invalid.',
      severity: PluginDiagnosticSeverity.error,
    ),
  ],
);

const _unsynchronizedAuthoring = PluginAuthoringEnvironmentDto(
  pluginId: 'example.tools',
  apiMajor: 5,
  sdkAbiHash: _sdkAbiHash,
  luaRuntimeVersion: '5.5.1',
  luaLanguageServerVersion: '3.18.2',
  pluginPath: r'C:\config\v5\plugins\example.tools',
  sdkLibraryPath: r'C:\config\v5\plugin-sdk\api-5\sdk-abi-hash\library',
  configurationPath: r'C:\config\v5\plugins\example.tools\.luarc.json',
  synchronized: false,
  diagnostics: <PluginDiagnosticDto>[
    PluginDiagnosticDto(
      code: 'luarc_missing',
      message: 'The LuaLS workspace configuration is missing.',
      severity: PluginDiagnosticSeverity.info,
    ),
  ],
);

const _planUi = PluginUiDocumentDto(
  id: 'plan-ui',
  pluginId: 'tinest.plan',
  revisionHash: 'plan-revision',
  slot: PluginUiSlot.agentSettings,
  root: <String, dynamic>{'type': 'text', 'text': 'Plan controls'},
);

Future<GoRouter> _pumpPlugins(
  WidgetTester tester,
  FakeTinestApi api, {
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final router = GoRouter(
    initialLocation: const PluginSettingsRoute(hostId: 'server').location,
    routes: $appRoutes,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appServicesProvider.overrideWithValue(fakeAppServices(api))],
      child: MaterialApp.router(
        theme: testLightTheme,
        darkTheme: testDarkTheme,
        locale: testLocale,
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Finder _field(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is TRTextField && widget.label == label,
  ),
  matching: find.byType(EditableText),
);
