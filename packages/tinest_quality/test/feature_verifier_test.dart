import 'dart:io';

import 'package:test/test.dart';
import 'package:tinest_quality/src/feature_manifest.dart';
import 'package:tinest_quality/src/feature_verifier.dart';

import 'support/repo_root.dart';

void main() {
  useRepositoryRoot();

  test('the checked-in workspace satisfies every feature contract', () {
    final violations = FeatureVerifier(
      '.',
      contracts: tinestFeatureManifest,
      uiContracts: tinestUiReachabilityManifest,
      uiJourneys: tinestUiJourneyManifest,
    ).verify();
    expect(violations, isEmpty);
  });

  test('duplicate and incomplete feature declarations are actionable', () {
    final fixture = _fixture(
      api: 'abstract interface class TinestApi {}',
      routes: '',
      tests: '',
    );
    addTearDown(() => fixture.delete(recursive: true));
    const incomplete = FeatureContract(
      id: 'duplicate.feature',
      description: '',
      requiredLayers: <FeatureVerificationLayer>{},
    );

    final violations = FeatureVerifier(
      fixture.path,
      contracts: const <FeatureContract>[incomplete, incomplete],
      apiPath: 'lib/api.dart',
      routePath: 'lib/app.dart',
    ).verify();
    final messages = violations.map((violation) => violation.toString());

    expect(messages, contains(contains('Duplicate feature ID')));
    expect(messages, contains(contains('has no description')));
    expect(messages, contains(contains('has no required layers')));
  });
  test('feature verifier accepts complete API, route, and layer evidence', () {
    const markerPrefix =
        'feature_'
        'test__';
    const routeMarkerPrefix =
        'route_'
        'test__';
    const scenarioMarkerPrefix =
        'feature_'
        'scenario__';
    final fixture = _fixture(
      api:
          'abstract interface class TinestApi {'
          ' Future<void> createThing(); }',
      routes: '@TypedGoRoute<HomeRoute>(path: "/")',
      tests: <String>[
        "testWidgets('works', (tester) async {",
        'await tester.pump();',
        'expect(true, isTrue);',
        '}, tags: <String>[',
        "'${markerPrefix}thing_create__contract', ",
        "'${markerPrefix}thing_create__e2e', ",
        "'${scenarioMarkerPrefix}thing_create__success__e2e', ",
        "'${routeMarkerPrefix}home_route__widget']);",
      ].join(),
    );
    addTearDown(() => fixture.delete(recursive: true));

    final violations = FeatureVerifier(
      fixture.path,
      contracts: const <FeatureContract>[
        FeatureContract(
          id: 'thing.create',
          description: 'Creates a thing.',
          apiMethods: <String>['createThing'],
          routes: <String>['HomeRoute'],
          requiredLayers: <FeatureVerificationLayer>{
            FeatureVerificationLayer.contract,
            FeatureVerificationLayer.e2e,
          },
          e2eScenarios: <FeatureScenario>[
            FeatureScenario(
              id: 'success',
              description: 'Creates a thing.',
              surfaces: <FeatureSurface>{FeatureSurface.desktop},
            ),
          ],
        ),
      ],
      apiPath: 'lib/api.dart',
      routePath: 'lib/app.dart',
    ).verify();

    expect(violations, isEmpty);
  });

  test('feature verifier discovers typed routes nested in a shell', () {
    const markerPrefix =
        'feature_'
        'test__';
    const routeMarkerPrefix =
        'route_'
        'test__';
    final fixture = _fixture(
      api: 'abstract interface class TinestApi {}',
      routes: '''
@TypedShellRoute<AppShellRoute>(
  routes: <TypedRoute<RouteData>>[
    TypedGoRoute<HomeRoute>(path: '/'),
    TypedGoRoute<SettingsRoute>(path: '/settings'),
  ],
)
''',
      tests: <String>[
        "testWidgets('navigates', (tester) async {",
        'await tester.pump();',
        'expect(true, isTrue);',
        '}, tags: <String>[',
        "'${markerPrefix}app_navigation__widget', ",
        "'${routeMarkerPrefix}home_route__widget', ",
        "'${routeMarkerPrefix}settings_route__widget']);",
      ].join(),
    );
    addTearDown(() => fixture.delete(recursive: true));

    final violations = FeatureVerifier(
      fixture.path,
      contracts: const <FeatureContract>[
        FeatureContract(
          id: 'app.navigation',
          description: 'Navigates through a typed shell.',
          routes: <String>['HomeRoute', 'SettingsRoute'],
          requiredLayers: <FeatureVerificationLayer>{
            FeatureVerificationLayer.widget,
          },
        ),
      ],
      apiPath: 'lib/api.dart',
      routePath: 'lib/app.dart',
    ).verify();

    expect(violations, isEmpty);
  });

  test('feature verifier discovers methods on the v5 plugin API', () {
    const markerPrefix =
        'feature_'
        'test__';
    final fixture = _fixture(
      api: '''
abstract interface class PluginsApi {
  Future<void> reloadPlugin();
}
abstract interface class TinestApi {
  PluginsApi get plugins;
}
''',
      routes: '',
      tests:
          "test('reloads', () {}, tags: <String>[ "
          "'${markerPrefix}plugin_management__contract']);",
    );
    addTearDown(() => fixture.delete(recursive: true));

    final violations = FeatureVerifier(
      fixture.path,
      contracts: const <FeatureContract>[
        FeatureContract(
          id: 'plugin.management',
          description: 'Reloads a plugin.',
          apiMethods: <String>['plugins.reloadPlugin'],
          requiredLayers: <FeatureVerificationLayer>{
            FeatureVerificationLayer.contract,
          },
        ),
      ],
      apiPath: 'lib/api.dart',
      routePath: 'lib/app.dart',
    ).verify();

    expect(violations, isEmpty);
  });

  test('feature verifier accepts executable typed E2E scenarios', () {
    const markerPrefix =
        'feature_'
        'scenario__';
    final fixture = _fixture(
      api: 'abstract interface class TinestApi {}',
      routes: '',
      tests: <String>[
        "testWidgets('creates a thing', (tester) async {",
        'await tester.pump();',
        "expect(find.text('created'), findsOneWidget);",
        "}, tags: <String>['${markerPrefix}thing_create__success__e2e']);",
      ].join(),
    );
    addTearDown(() => fixture.delete(recursive: true));

    final violations = FeatureVerifier(
      fixture.path,
      contracts: const <FeatureContract>[
        FeatureContract(
          id: 'thing.create',
          description: 'Creates a thing.',
          requiredLayers: <FeatureVerificationLayer>{
            FeatureVerificationLayer.e2e,
          },
          e2eScenarios: <FeatureScenario>[
            FeatureScenario(
              id: 'success',
              description: 'Creates and persists a valid thing.',
              surfaces: <FeatureSurface>{
                FeatureSurface.desktop,
                FeatureSurface.mobile,
              },
            ),
          ],
        ),
      ],
      apiPath: 'lib/api.dart',
      routePath: 'lib/app.dart',
    ).verify();

    expect(violations, isEmpty);
  });

  test('feature verifier rejects incomplete E2E scenario contracts', () {
    const markerPrefix =
        'feature_'
        'scenario__';
    final fixture = _fixture(
      api: 'abstract interface class TinestApi {}',
      routes: '',
      tests: <String>[
        "test('marker only', () {}, tags: <String>[",
        "'${markerPrefix}thing_create__marker_only__e2e',",
        "'${markerPrefix}thing_create__unknown__e2e']);",
      ].join(),
    );
    addTearDown(() => fixture.delete(recursive: true));

    final violations = FeatureVerifier(
      fixture.path,
      contracts: const <FeatureContract>[
        FeatureContract(
          id: 'thing.create',
          description: 'Creates a thing.',
          requiredLayers: <FeatureVerificationLayer>{
            FeatureVerificationLayer.e2e,
          },
          e2eScenarios: <FeatureScenario>[
            FeatureScenario(
              id: 'marker_only',
              description: 'Exercises a real runner.',
              surfaces: <FeatureSurface>{FeatureSurface.desktop},
            ),
            FeatureScenario(
              id: 'marker_only',
              description: 'Duplicate scenario.',
              surfaces: <FeatureSurface>{FeatureSurface.desktop},
            ),
            FeatureScenario(
              id: 'no_surface',
              description: 'Has no supported surface.',
              surfaces: <FeatureSurface>{},
            ),
            FeatureScenario(
              id: 'missing',
              description: 'Has no executable evidence.',
              surfaces: <FeatureSurface>{FeatureSurface.mobile},
            ),
          ],
        ),
      ],
      apiPath: 'lib/api.dart',
      routePath: 'lib/app.dart',
    ).verify();
    final messages = violations.map((item) => item.message).join('\n');

    expect(messages, contains('Duplicate E2E scenario marker_only'));
    expect(messages, contains('no_surface has no supported surface'));
    expect(
      messages,
      contains('Unknown E2E scenario tag: thing.create/unknown'),
    );
    expect(messages, contains('marker_only has no executable testWidgets'));
    expect(messages, contains('missing is missing E2E evidence'));
  });

  test('feature verifier requires scenarios for every E2E feature', () {
    const markerPrefix =
        'feature_'
        'test__';
    final fixture = _fixture(
      api: 'abstract interface class TinestApi {}',
      routes: '',
      tests:
          "test('layer', () {}, "
          "tags: <String>['${markerPrefix}thing_create__e2e']);",
    );
    addTearDown(() => fixture.delete(recursive: true));

    final violations = FeatureVerifier(
      fixture.path,
      contracts: const <FeatureContract>[
        FeatureContract(
          id: 'thing.create',
          description: 'Creates a thing.',
          requiredLayers: <FeatureVerificationLayer>{
            FeatureVerificationLayer.e2e,
          },
        ),
      ],
      apiPath: 'lib/api.dart',
      routePath: 'lib/app.dart',
    ).verify();

    expect(
      violations.map((item) => item.message),
      contains(contains('Feature thing.create has no E2E scenarios')),
    );
  });

  test('feature verifier accepts complete UI reachability evidence', () {
    const statePrefix = 'ui_state__';
    const transitionPrefix = 'ui_transition__';
    const variantPrefix = 'ui_variant__';
    const journeyPrefix = 'ui_journey__';
    final fixture = _fixture(
      api: 'abstract interface class TinestApi {}',
      routes: '',
      tests: <String>[
        "testWidgets('loaded', (tester) async { await tester.pump(); ",
        "expect(true, isTrue); }, tags: <String>['",
        '${statePrefix}conversation__loaded__widget',
        "']);",
        "testWidgets('error', (tester) async { await tester.pump(); ",
        "expect(true, isTrue); }, tags: <String>['",
        '${statePrefix}conversation__error__widget',
        "']);",
        "testWidgets('retry', (tester) async { ",
        "await tester.tap(find.text('Retry')); ",
        "expect(true, isTrue); }, tags: <String>['",
        '${transitionPrefix}conversation__retry__widget',
        "']);",
        "testWidgets('desktop Korean', (tester) async { await tester.pump(); ",
        "expect(true, isTrue); }, tags: <String>['",
        '${variantPrefix}conversation__desktop_korean__widget',
        "']);",
        "testWidgets('reconnect journey', (tester) async { ",
        'await tester.pump(); ',
        "expect(true, isTrue); }, tags: <String>['",
        '${journeyPrefix}conversation_reconnect__e2e',
        "']);",
      ].join(),
    );
    addTearDown(() => fixture.delete(recursive: true));

    final violations = FeatureVerifier(
      fixture.path,
      contracts: const <FeatureContract>[],
      uiContracts: const <UiReachabilityContract>[
        UiReachabilityContract(
          id: 'conversation',
          featureId: 'turn.execution',
          description: 'Conversation route and overlays.',
          states: <UiStateContract>[
            UiStateContract(id: 'loaded', description: 'Timeline is loaded.'),
            UiStateContract(id: 'error', description: 'Timeline failed.'),
          ],
          transitions: <UiTransitionContract>[
            UiTransitionContract(
              id: 'retry',
              description: 'Retries a failed turn.',
              fromState: 'error',
              outcomes: <String>{'loaded', 'error'},
            ),
          ],
          variants: <UiVariantContract>[
            UiVariantContract(
              id: 'desktop_korean',
              description: 'Desktop Korean keyboard path.',
            ),
          ],
        ),
      ],
      uiJourneys: const <UiJourneyContract>[
        UiJourneyContract(
          id: 'conversation_reconnect',
          description: 'Restores an interrupted conversation.',
          tier: UiEvidenceTier.nightlyExtended,
          surfaces: <FeatureSurface>{FeatureSurface.desktop},
          transitionIds: <String>['conversation/retry'],
        ),
      ],
      apiPath: 'lib/api.dart',
      routePath: 'lib/app.dart',
    ).verify();

    expect(violations, isEmpty);
  });

  test('feature verifier rejects incomplete or laundered UI evidence', () {
    const statePrefix = 'ui_state__';
    const transitionPrefix = 'ui_transition__';
    const variantPrefix = 'ui_variant__';
    const journeyPrefix = 'ui_journey__';
    final fixture = _fixture(
      api: 'abstract interface class TinestApi {}',
      routes: '',
      tests: <String>[
        "testWidgets('laundered', (tester) async { await tester.pump(); ",
        "expect(true, isTrue); }, tags: <String>['",
        '${statePrefix}conversation__loaded__widget',
        "', '",
        '${transitionPrefix}conversation__retry__widget',
        "']);",
        "testWidgets('unknown', (tester) async { await tester.pump(); ",
        "expect(true, isTrue); }, tags: <String>['",
        '${variantPrefix}conversation__unknown__widget',
        "', '",
        '${journeyPrefix}unknown__e2e',
        "']);",
      ].join(),
    );
    addTearDown(() => fixture.delete(recursive: true));

    final violations = FeatureVerifier(
      fixture.path,
      contracts: const <FeatureContract>[],
      uiContracts: const <UiReachabilityContract>[
        UiReachabilityContract(
          id: 'conversation',
          featureId: 'turn.execution',
          description: 'Conversation route and overlays.',
          states: <UiStateContract>[
            UiStateContract(id: 'loaded', description: 'Timeline is loaded.'),
            UiStateContract(id: 'error', description: 'Timeline failed.'),
          ],
          transitions: <UiTransitionContract>[
            UiTransitionContract(
              id: 'retry',
              description: 'Retries a failed turn.',
              fromState: 'error',
              outcomes: <String>{'loaded'},
            ),
          ],
          variants: <UiVariantContract>[
            UiVariantContract(
              id: 'desktop_korean',
              description: 'Desktop Korean keyboard path.',
            ),
          ],
        ),
      ],
      uiJourneys: const <UiJourneyContract>[
        UiJourneyContract(
          id: 'conversation_reconnect',
          description: 'Restores an interrupted conversation.',
          tier: UiEvidenceTier.prRequired,
          surfaces: <FeatureSurface>{FeatureSurface.desktop},
          transitionIds: <String>['conversation/retry'],
        ),
      ],
      apiPath: 'lib/api.dart',
      routePath: 'lib/app.dart',
    ).verify();
    final messages = violations.map((item) => item.message).join('\n');

    expect(messages, contains('must prove exactly one atomic UI contract'));
    expect(messages, contains('conversation/error is missing widget evidence'));
    expect(
      messages,
      contains('conversation/desktop_korean is missing widget evidence'),
    );
    expect(messages, contains('Unknown UI variant tag: conversation/unknown'));
    expect(messages, contains('Unknown UI journey tag: unknown'));
    expect(
      messages,
      contains('conversation_reconnect is missing E2E evidence'),
    );
  });

  test('UI evidence can precede its callback or use an asserting helper', () {
    const statePrefix = 'ui_state__';
    const variantPrefix = 'ui_variant__';
    final fixture = _fixture(
      api: 'abstract interface class TinestApi {}',
      routes: '',
      tests: <String>[
        "testWidgets('route', tags: <String>['",
        '${statePrefix}home__rendered__widget',
        "', '",
        '${variantPrefix}home__desktop__widget',
        "'], (tester) => _verifyRoute(tester));",
        'Future<void> _verifyRoute(WidgetTester tester) async {',
        'await tester.pump(); expect(true, isTrue); }',
      ].join(),
    );
    addTearDown(() => fixture.delete(recursive: true));

    final violations = FeatureVerifier(
      fixture.path,
      contracts: const <FeatureContract>[],
      uiContracts: const <UiReachabilityContract>[
        UiReachabilityContract(
          id: 'home',
          featureId: 'app.navigation',
          description: 'Home route.',
          states: <UiStateContract>[
            UiStateContract(id: 'rendered', description: 'Home is visible.'),
          ],
          transitions: <UiTransitionContract>[],
          variants: <UiVariantContract>[
            UiVariantContract(id: 'desktop', description: 'Desktop case.'),
          ],
        ),
      ],
      apiPath: 'lib/api.dart',
      routePath: 'lib/app.dart',
    ).verify();

    expect(violations, isEmpty);
  });

  test('feature verifier reports every missing or unsafe registration', () {
    const markerPrefix =
        'feature_'
        'test__';
    const routeMarkerPrefix =
        'route_'
        'test__';
    final fixture = _fixture(
      api:
          'abstract interface class TinestApi {'
          ' Future<void> createThing(); Future<void> deleteThing(); }',
      routes:
          '@TypedGoRoute<HomeRoute>(path: "/") '
          '@TypedGoRoute<SettingsRoute>(path: "/settings")',
      tests: <String>[
        "test('skipped', () {}, skip: true, tags: <String>[",
        "'${markerPrefix}thing_create__contract', ",
        "'${markerPrefix}unknown_feature__widget', ",
        "'${routeMarkerPrefix}home_route__widget', ",
        "'${routeMarkerPrefix}ghost_route__widget']);",
      ].join(),
    );
    addTearDown(() => fixture.delete(recursive: true));

    final violations = FeatureVerifier(
      fixture.path,
      contracts: const <FeatureContract>[
        FeatureContract(
          id: 'thing.create',
          description: 'Creates a thing.',
          apiMethods: <String>['createThing'],
          routes: <String>['HomeRoute'],
          requiredLayers: <FeatureVerificationLayer>{
            FeatureVerificationLayer.contract,
            FeatureVerificationLayer.verticalSlice,
          },
        ),
      ],
      apiPath: 'lib/api.dart',
      routePath: 'lib/app.dart',
    ).verify();
    final messages = violations.map((item) => item.message).join('\n');

    expect(messages, contains('deleteThing'));
    expect(messages, contains('SettingsRoute'));
    expect(messages, contains('verticalSlice'));
    expect(messages, contains('unknown.feature'));
    expect(messages, contains('SettingsRoute'));
    expect(messages, contains('GhostRoute'));
    expect(messages, contains('skip'));
  });

  test('feature verifier rejects retired security terms in production', () {
    final fixture = _fixture(
      api: 'abstract interface class TinestApi {}',
      routes: '',
      tests: '',
    );
    addTearDown(() => fixture.delete(recursive: true));
    File('${fixture.path}/lib/security.dart')
        .writeAsStringSync("const retired = 'adminToken';");

    final violations = FeatureVerifier(
      fixture.path,
      contracts: const <FeatureContract>[],
      apiPath: 'lib/api.dart',
      routePath: 'lib/app.dart',
    ).verify();

    expect(
      violations.map((item) => item.message),
      contains(contains('Forbidden production term adminToken')),
    );
  });
}

Directory _fixture({
  required String api,
  required String routes,
  required String tests,
}) {
  final root = Directory.systemTemp.createTempSync('feature-verifier-');
  Directory('${root.path}/lib').createSync();
  Directory('${root.path}/test').createSync();
  File('${root.path}/lib/api.dart').writeAsStringSync(api);
  File('${root.path}/lib/app.dart').writeAsStringSync(routes);
  File('${root.path}/test/features_test.dart').writeAsStringSync(tests);
  return root;
}
