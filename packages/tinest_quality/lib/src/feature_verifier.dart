import 'dart:io';

import 'package:path/path.dart' as p;

/// Verification layers supported by the feature traceability gate.
enum FeatureVerificationLayer {
  /// Pure domain and state-transition tests.
  unit,

  /// Typed protocol and client codec tests.
  contract,

  /// Production service adapters exercised without Flutter UI.
  verticalSlice,

  /// Flutter interaction tests with deterministic ports.
  widget,

  /// Real Flutter runner tests against a real daemon.
  e2e,

  /// Platform bootstrap or compilation smoke tests.
  platformSmoke,
}

/// Application surfaces on which an E2E scenario must remain executable.
enum FeatureSurface {
  /// Linux, macOS, and Windows desktop runners.
  desktop,

  /// Android and iOS remote-only runners.
  mobile,

  /// The browser build, which is remote-only for the same reason as mobile.
  web,
}

/// Scheduling tier for UI evidence.
enum UiEvidenceTier {
  /// Blocks pull requests and merge-queue changes.
  prRequired,

  /// Runs in the expanded scheduled matrix.
  nightlyExtended,
}

/// One user-observable state of a UI entry point.
final class UiStateContract {
  /// Creates an immutable UI state contract.
  const new({required this.id, required this.description});

  /// Stable snake-case identifier used by evidence tags.
  final String id;

  /// Observable condition that proves the state.
  final String description;
}

/// One user action and its allowed observable outcomes.
final class UiTransitionContract {
  /// Creates an immutable UI transition contract.
  const new({
    required this.id,
    required this.description,
    required this.fromState,
    required this.outcomes,
  });

  /// Stable snake-case identifier used by evidence tags.
  final String id;

  /// User action protected by the transition.
  final String description;

  /// State in which the action is reachable.
  final String fromState;

  /// States in which the action may observably finish.
  final Set<String> outcomes;
}

/// One pairwise environment case required for a UI entry point.
final class UiVariantContract {
  /// Creates an immutable UI variant contract.
  const new({required this.id, required this.description});

  /// Stable snake-case case identifier.
  final String id;

  /// Viewport, locale, theme, input, and connection dimensions in this case.
  final String description;
}

/// Complete atomic reachability contract for one route or transient surface.
final class UiReachabilityContract {
  /// Creates an immutable UI reachability contract.
  const new({
    required this.id,
    required this.featureId,
    required this.description,
    required this.states,
    required this.transitions,
    required this.variants,
    this.tier = UiEvidenceTier.prRequired,
  });

  /// Stable snake-case route, dialog, sheet, menu, overlay, or pane ID.
  final String id;

  /// Feature that owns this user-facing surface.
  final String featureId;

  /// Entry point and supported user outcome.
  final String description;

  /// Every user-observable state supported by the entry point.
  final List<UiStateContract> states;

  /// Every meaningful user action reachable from the entry point.
  final List<UiTransitionContract> transitions;

  /// Pairwise environment cases required for the entry point.
  final List<UiVariantContract> variants;

  /// CI scheduling tier for this contract.
  final UiEvidenceTier tier;
}

/// A deliberately composite real-runner journey that cannot replace atomics.
final class UiJourneyContract {
  /// Creates an immutable composite journey contract.
  const new({
    required this.id,
    required this.description,
    required this.tier,
    required this.surfaces,
    required this.transitionIds,
  });

  /// Stable snake-case journey ID.
  final String id;

  /// User-observable purpose of the journey.
  final String description;

  /// CI scheduling tier for this journey.
  final UiEvidenceTier tier;

  /// Runtime surfaces on which this journey executes.
  final Set<FeatureSurface> surfaces;

  /// Ordered `surface/transition` IDs composed by the journey.
  final List<String> transitionIds;
}

/// One stable, user-observable E2E behavior owned by a feature.
final class FeatureScenario {
  /// Creates an immutable E2E scenario contract.
  const new({
    required this.id,
    required this.description,
    required this.surfaces,
  });

  /// Stable snake-case identifier used in executable test tags.
  final String id;

  /// User-observable outcome and boundary protected by the scenario.
  final String description;

  /// Product surfaces on which this behavior is supported.
  final Set<FeatureSurface> surfaces;
}

/// Declares one user-visible capability and its mandatory evidence.
final class FeatureContract {
  /// Creates an immutable feature contract.
  const new({
    required this.id,
    required this.description,
    required this.requiredLayers,
    this.apiMethods = const <String>[],
    this.routes = const <String>[],
    this.e2eScenarios = const <FeatureScenario>[],
  });

  /// Stable dotted identifier used by test tags and reports.
  final String id;

  /// User outcome protected by this contract.
  final String description;

  /// Public client methods owned by the feature.
  final List<String> apiMethods;

  /// Typed Flutter routes owned by the feature.
  final List<String> routes;

  /// Test layers that must contain tagged evidence.
  final Set<FeatureVerificationLayer> requiredLayers;

  /// Executable real-runner behaviors required for this feature.
  final List<FeatureScenario> e2eScenarios;
}

/// One actionable feature verification failure.
final class FeatureViolation {
  /// Creates a violation.
  const new(this.message);

  /// Human-readable failure detail.
  final String message;

  @override
  String toString() => message;
}

/// Checks public surfaces and tagged tests against typed feature contracts.
final class FeatureVerifier {
  /// Creates a verifier rooted at [workspaceRoot].
  const new(
    this.workspaceRoot, {
    required this.contracts,
    this.uiContracts = const <UiReachabilityContract>[],
    this.uiJourneys = const <UiJourneyContract>[],
    this.apiPath = 'packages/client/lib/src/api.dart',
    this.routePath = 'packages/app/lib/src/app/router/app_router.dart',
    this.forbiddenProductionTerms = const <String>[],
  });

  /// Pub workspace root.
  final String workspaceRoot;

  /// Complete declared feature catalog.
  final List<FeatureContract> contracts;

  /// Complete catalog of UI entry points, states, actions, and variants.
  final List<UiReachabilityContract> uiContracts;

  /// Composite real-runner journeys that supplement atomic evidence.
  final List<UiJourneyContract> uiJourneys;

  /// Source containing the `TinestApi` interface.
  final String apiPath;

  /// Source containing typed route annotations.
  final String routePath;

  /// Retired security concepts that must not return to production or docs.
  final List<String> forbiddenProductionTerms;

  /// Returns every manifest, public-surface, and test-evidence violation.
  List<FeatureViolation> verify() {
    final violations = <FeatureViolation>[];
    final contractsById = <String, FeatureContract>{};
    final scenariosByFeature = <String, Map<String, FeatureScenario>>{};
    final methodOwners = <String, String>{};
    final routeOwners = <String, String>{};
    for (final contract in contracts) {
      if (contractsById.containsKey(contract.id)) {
        violations.add(
          FeatureViolation('Duplicate feature ID: ${contract.id}'),
        );
      }
      contractsById[contract.id] = contract;
      if (contract.description.trim().isEmpty) {
        violations.add(
          FeatureViolation('Feature ${contract.id} has no description.'),
        );
      }
      if (contract.requiredLayers.isEmpty) {
        violations.add(
          FeatureViolation('Feature ${contract.id} has no required layers.'),
        );
      }
      if (contract.requiredLayers.contains(FeatureVerificationLayer.e2e) &&
          contract.e2eScenarios.isEmpty) {
        violations.add(
          FeatureViolation('Feature ${contract.id} has no E2E scenarios.'),
        );
      }
      final scenariosById = <String, FeatureScenario>{};
      scenariosByFeature[contract.id] = scenariosById;
      for (final scenario in contract.e2eScenarios) {
        if (scenariosById.containsKey(scenario.id)) {
          violations.add(
            FeatureViolation(
              'Duplicate E2E scenario ${scenario.id} for ${contract.id}.',
            ),
          );
        }
        scenariosById[scenario.id] = scenario;
        if (!RegExp(r'^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$').hasMatch(scenario.id)) {
          violations.add(
            FeatureViolation(
              'E2E scenario ${contract.id}/${scenario.id} must use a stable '
              'snake-case ID.',
            ),
          );
        }
        if (scenario.description.trim().isEmpty) {
          violations.add(
            FeatureViolation(
              'E2E scenario ${contract.id}/${scenario.id} has no description.',
            ),
          );
        }
        if (scenario.surfaces.isEmpty) {
          violations.add(
            FeatureViolation(
              'E2E scenario ${contract.id}/${scenario.id} has no supported '
              'surface.',
            ),
          );
        }
      }
      for (final method in contract.apiMethods) {
        final previous = methodOwners[method];
        if (previous != null) {
          violations.add(
            FeatureViolation(
              'TinestApi method $method belongs to both $previous and '
              '${contract.id}.',
            ),
          );
        }
        methodOwners[method] = contract.id;
      }
      for (final route in contract.routes) {
        final previous = routeOwners[route];
        if (previous != null) {
          violations.add(
            FeatureViolation(
              'Route $route belongs to both $previous and ${contract.id}.',
            ),
          );
        }
        routeOwners[route] = contract.id;
      }
    }

    final uiById = <String, UiReachabilityContract>{};
    final uiStateKeys = <String>{};
    final uiTransitionKeys = <String>{};
    final uiVariantKeys = <String>{};
    for (final contract in uiContracts) {
      if (uiById.containsKey(contract.id)) {
        violations.add(
          FeatureViolation('Duplicate UI reachability ID: ${contract.id}'),
        );
      }
      uiById[contract.id] = contract;
      _validateStableId(
        contract.id,
        label: 'UI reachability ID',
        violations: violations,
      );
      if (contract.description.trim().isEmpty) {
        violations.add(
          FeatureViolation(
            'UI reachability ${contract.id} has no description.',
          ),
        );
      }
      if (contract.states.isEmpty) {
        violations.add(
          FeatureViolation('UI reachability ${contract.id} has no states.'),
        );
      }
      if (contract.variants.isEmpty) {
        violations.add(
          FeatureViolation('UI reachability ${contract.id} has no variants.'),
        );
      }
      final stateIds = <String>{};
      for (final state in contract.states) {
        final key = '${contract.id}/${state.id}';
        if (!stateIds.add(state.id)) {
          violations.add(FeatureViolation('Duplicate UI state $key.'));
        }
        uiStateKeys.add(key);
        _validateStableId(
          state.id,
          label: 'UI state ID $key',
          violations: violations,
        );
        if (state.description.trim().isEmpty) {
          violations.add(FeatureViolation('UI state $key has no description.'));
        }
      }
      final transitionIds = <String>{};
      for (final transition in contract.transitions) {
        final key = '${contract.id}/${transition.id}';
        if (!transitionIds.add(transition.id)) {
          violations.add(FeatureViolation('Duplicate UI transition $key.'));
        }
        uiTransitionKeys.add(key);
        _validateStableId(
          transition.id,
          label: 'UI transition ID $key',
          violations: violations,
        );
        if (!stateIds.contains(transition.fromState)) {
          violations.add(
            FeatureViolation(
              'UI transition $key starts from unknown state '
              '${transition.fromState}.',
            ),
          );
        }
        if (transition.outcomes.isEmpty) {
          violations.add(
            FeatureViolation('UI transition $key has no outcomes.'),
          );
        }
        for (final outcome in transition.outcomes) {
          if (!stateIds.contains(outcome)) {
            violations.add(
              FeatureViolation(
                'UI transition $key has unknown outcome $outcome.',
              ),
            );
          }
        }
      }
      final variantIds = <String>{};
      for (final variant in contract.variants) {
        final key = '${contract.id}/${variant.id}';
        if (!variantIds.add(variant.id)) {
          violations.add(FeatureViolation('Duplicate UI variant $key.'));
        }
        uiVariantKeys.add(key);
        _validateStableId(
          variant.id,
          label: 'UI variant ID $key',
          violations: violations,
        );
        if (variant.description.trim().isEmpty) {
          violations.add(
            FeatureViolation('UI variant $key has no description.'),
          );
        }
      }
    }
    final journeysById = <String, UiJourneyContract>{};
    for (final journey in uiJourneys) {
      if (journeysById.containsKey(journey.id)) {
        violations.add(FeatureViolation('Duplicate UI journey: ${journey.id}'));
      }
      journeysById[journey.id] = journey;
      _validateStableId(
        journey.id,
        label: 'UI journey ID',
        violations: violations,
      );
      if (journey.description.trim().isEmpty) {
        violations.add(
          FeatureViolation('UI journey ${journey.id} has no description.'),
        );
      }
      if (journey.surfaces.isEmpty) {
        violations.add(
          FeatureViolation('UI journey ${journey.id} has no surfaces.'),
        );
      }
      if (journey.transitionIds.isEmpty) {
        violations.add(
          FeatureViolation('UI journey ${journey.id} has no transitions.'),
        );
      }
      for (final transitionId in journey.transitionIds) {
        if (!uiTransitionKeys.contains(transitionId)) {
          violations.add(
            FeatureViolation(
              'UI journey ${journey.id} references unknown transition '
              '$transitionId.',
            ),
          );
        }
      }
    }

    final apiMethods = _apiMethods(
      File(p.join(workspaceRoot, apiPath)).readAsStringSync(),
    );
    for (final method in apiMethods.difference(methodOwners.keys.toSet())) {
      violations.add(
        FeatureViolation('Unregistered TinestApi method: $method'),
      );
    }
    for (final method in methodOwners.keys.toSet().difference(apiMethods)) {
      violations.add(FeatureViolation('Missing TinestApi method: $method'));
    }

    final routes = _routes(
      File(p.join(workspaceRoot, routePath)).readAsStringSync(),
    );
    for (final route in routes.difference(routeOwners.keys.toSet())) {
      violations.add(FeatureViolation('Unregistered typed route: $route'));
    }
    for (final route in routeOwners.keys.toSet().difference(routes)) {
      violations.add(FeatureViolation('Missing typed route: $route'));
    }

    final evidence = <String, Set<FeatureVerificationLayer>>{};
    final scenarioEvidence = <String>{};
    final routeEvidence = <String>{};
    final uiStateEvidence = <String>{};
    final uiTransitionEvidence = <String>{};
    final uiVariantEvidence = <String>{};
    final uiJourneyEvidence = <String>{};
    final marker = RegExp(
      'feature_test__([a-z0-9_]+)__'
      '(unit|contract|verticalSlice|widget|e2e|platformSmoke)',
    );
    final routeMarker = RegExp('route_test__([a-z0-9_]+)__widget');
    final scenarioMarker = RegExp(
      'feature_scenario__([a-z0-9_]+)__([a-z0-9_]+)__e2e',
    );
    final uiStateMarker = RegExp(
      'ui_state__([a-z0-9_]+)__([a-z0-9_]+)__widget',
    );
    final uiTransitionMarker = RegExp(
      'ui_transition__([a-z0-9_]+)__([a-z0-9_]+)__widget',
    );
    final uiVariantMarker = RegExp(
      'ui_variant__([a-z0-9_]+)__([a-z0-9_]+)__widget',
    );
    final uiJourneyMarker = RegExp('ui_journey__([a-z0-9_]+)__e2e');
    final routesByTag = <String, String>{
      for (final route in routes) _snakeCase(route): route,
    };
    for (final file in _testSources()) {
      final source = file.readAsStringSync();
      final hasSkip = RegExp(r'''\bskip\s*:\s*(true|["'])''').hasMatch(source);
      for (final match in marker.allMatches(source)) {
        final id = match.group(1)!.replaceAll('_', '.');
        final layerName = match.group(2)!;
        final contract = contractsById[id];
        if (contract == null) {
          violations.add(FeatureViolation('Unknown feature test tag: $id'));
          continue;
        }
        final layer = FeatureVerificationLayer.values
            .where((candidate) => candidate.name == layerName)
            .firstOrNull;
        if (layer == null) {
          violations.add(
            FeatureViolation('Unknown verification layer $layerName for $id.'),
          );
          continue;
        }
        if (hasSkip) {
          violations.add(
            FeatureViolation(
              'Feature evidence for $id cannot use skip in '
              '${p.relative(file.path, from: workspaceRoot)}.',
            ),
          );
        }
        evidence.putIfAbsent(id, () => <FeatureVerificationLayer>{}).add(layer);
      }
      for (final match in scenarioMarker.allMatches(source)) {
        final featureId = match.group(1)!.replaceAll('_', '.');
        final scenarioId = match.group(2)!;
        final scenario = scenariosByFeature[featureId]?[scenarioId];
        if (scenario == null) {
          violations.add(
            FeatureViolation(
              'Unknown E2E scenario tag: $featureId/$scenarioId.',
            ),
          );
          continue;
        }
        if (hasSkip) {
          violations.add(
            FeatureViolation(
              'E2E scenario $featureId/$scenarioId cannot use skip in '
              '${p.relative(file.path, from: workspaceRoot)}.',
            ),
          );
        }
        if (!_hasExecutableUiEvidence(source, match.start)) {
          violations.add(
            FeatureViolation(
              'E2E scenario $featureId/$scenarioId has no executable '
              'testWidgets behavior in '
              '${p.relative(file.path, from: workspaceRoot)}.',
            ),
          );
          continue;
        }
        scenarioEvidence.add('$featureId/$scenarioId');
        evidence
            .putIfAbsent(featureId, () => <FeatureVerificationLayer>{})
            .add(FeatureVerificationLayer.e2e);
      }
      for (final match in routeMarker.allMatches(source)) {
        final tagId = match.group(1)!;
        final route = routesByTag[tagId];
        if (route == null) {
          violations.add(
            FeatureViolation(
              'Unknown route test tag: ${_upperCamelCase(tagId)}',
            ),
          );
          continue;
        }
        if (hasSkip) {
          violations.add(
            FeatureViolation(
              'Route evidence for $route cannot use skip in '
              '${p.relative(file.path, from: workspaceRoot)}.',
            ),
          );
        }
        routeEvidence.add(route);
      }
      for (final match in uiStateMarker.allMatches(source)) {
        final key = '${match.group(1)!}/${match.group(2)!}';
        if (!uiStateKeys.contains(key)) {
          violations.add(FeatureViolation('Unknown UI state tag: $key'));
          continue;
        }
        _recordAtomicUiEvidence(
          source: source,
          markerOffset: match.start,
          key: key,
          hasSkip: hasSkip,
          relativePath: p.relative(file.path, from: workspaceRoot),
          evidence: uiStateEvidence,
          violations: violations,
        );
      }
      for (final match in uiTransitionMarker.allMatches(source)) {
        final key = '${match.group(1)!}/${match.group(2)!}';
        if (!uiTransitionKeys.contains(key)) {
          violations.add(FeatureViolation('Unknown UI transition tag: $key'));
          continue;
        }
        _recordAtomicUiEvidence(
          source: source,
          markerOffset: match.start,
          key: key,
          hasSkip: hasSkip,
          relativePath: p.relative(file.path, from: workspaceRoot),
          evidence: uiTransitionEvidence,
          violations: violations,
        );
      }
      for (final match in uiVariantMarker.allMatches(source)) {
        final key = '${match.group(1)!}/${match.group(2)!}';
        if (!uiVariantKeys.contains(key)) {
          violations.add(FeatureViolation('Unknown UI variant tag: $key'));
          continue;
        }
        if (hasSkip) {
          violations.add(FeatureViolation('UI variant $key cannot use skip.'));
        }
        if (!_hasExecutableUiEvidence(source, match.start)) {
          violations.add(
            FeatureViolation('UI variant $key has no executable testWidgets.'),
          );
          continue;
        }
        uiVariantEvidence.add(key);
      }
      for (final match in uiJourneyMarker.allMatches(source)) {
        final id = match.group(1)!;
        if (!journeysById.containsKey(id)) {
          violations.add(FeatureViolation('Unknown UI journey tag: $id'));
          continue;
        }
        if (hasSkip) {
          violations.add(FeatureViolation('UI journey $id cannot use skip.'));
        }
        if (!_hasExecutableScenario(source, match.start)) {
          violations.add(
            FeatureViolation('UI journey $id has no executable testWidgets.'),
          );
          continue;
        }
        uiJourneyEvidence.add(id);
      }
    }
    for (final contract in contracts) {
      final observed = evidence[contract.id] ?? <FeatureVerificationLayer>{};
      for (final layer in contract.requiredLayers.difference(observed)) {
        violations.add(
          FeatureViolation(
            'Feature ${contract.id} is missing ${layer.name} evidence.',
          ),
        );
      }
      for (final scenario in contract.e2eScenarios) {
        final key = '${contract.id}/${scenario.id}';
        if (!scenarioEvidence.contains(key)) {
          violations.add(
            FeatureViolation('E2E scenario $key is missing E2E evidence.'),
          );
        }
      }
    }
    for (final route in routes.difference(routeEvidence)) {
      violations.add(
        FeatureViolation('Route $route is missing widget evidence.'),
      );
    }
    for (final key in uiStateKeys.difference(uiStateEvidence)) {
      violations.add(
        FeatureViolation('UI state $key is missing widget evidence.'),
      );
    }
    for (final key in uiTransitionKeys.difference(uiTransitionEvidence)) {
      violations.add(
        FeatureViolation('UI transition $key is missing widget evidence.'),
      );
    }
    for (final key in uiVariantKeys.difference(uiVariantEvidence)) {
      violations.add(
        FeatureViolation('UI variant $key is missing widget evidence.'),
      );
    }
    for (final id in journeysById.keys.toSet().difference(uiJourneyEvidence)) {
      violations.add(
        FeatureViolation('UI journey $id is missing E2E evidence.'),
      );
    }
    for (final file in _productionSources()) {
      final source = file.readAsStringSync();
      for (final term in _effectiveForbiddenProductionTerms) {
        if (source.contains(term)) {
          violations.add(
            FeatureViolation(
              'Forbidden production term $term in '
              '${p.relative(file.path, from: workspaceRoot)}.',
            ),
          );
        }
      }
    }
    return violations;
  }

  void _validateStableId(
    String id, {
    required String label,
    required List<FeatureViolation> violations,
  }) {
    if (!RegExp(r'^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$').hasMatch(id)) {
      violations.add(
        FeatureViolation('$label $id must use a stable snake-case ID.'),
      );
    }
  }

  void _recordAtomicUiEvidence({
    required String source,
    required int markerOffset,
    required String key,
    required bool hasSkip,
    required String relativePath,
    required Set<String> evidence,
    required List<FeatureViolation> violations,
  }) {
    if (hasSkip) {
      violations.add(FeatureViolation('UI evidence for $key cannot use skip.'));
    }
    if (!_hasExecutableUiEvidence(source, markerOffset)) {
      violations.add(
        FeatureViolation(
          'UI evidence for $key has no executable testWidgets in '
          '$relativePath.',
        ),
      );
      return;
    }
    if (_atomicUiMarkersInTest(source, markerOffset) != 1) {
      violations.add(
        FeatureViolation(
          'Each testWidgets must prove exactly one atomic UI contract; '
          '$key shares a test in $relativePath.',
        ),
      );
      return;
    }
    evidence.add(key);
  }

  int _atomicUiMarkersInTest(String source, int markerOffset) {
    final testSource = _testWidgetsSource(source, markerOffset);
    if (testSource == null) return 0;
    return RegExp('ui_(?:state|transition)__[a-z0-9_]+__[a-z0-9_]+__widget')
        .allMatches(testSource)
        .length;
  }

  bool _hasExecutableUiEvidence(String source, int markerOffset) {
    final testSource = _testWidgetsSource(source, markerOffset);
    if (testSource == null) return false;
    final inlineBehavior =
        testSource.contains('await ') && testSource.contains('expect(');
    final assertingRouteHelper = testSource.contains('=> _verifyRoute(');
    return inlineBehavior || assertingRouteHelper;
  }

  String? _testWidgetsSource(String source, int markerOffset) {
    final testStart = source.lastIndexOf('testWidgets(', markerOffset);
    if (testStart < 0) return null;
    final nextTest = source.indexOf('testWidgets(', markerOffset + 1);
    final end = nextTest < 0 ? source.length : nextTest;
    return source.substring(testStart, end);
  }

  List<String> get _effectiveForbiddenProductionTerms =>
      forbiddenProductionTerms.isEmpty
      ? <String>[
          <String>['admin', 'Token'].join(),
          <String>['X-Tinyrack-Tinest-', 'Admin'].join(),
          <String>['TINYRACK_TINEST_', 'ADMIN_TOKEN'].join(),
          <String>['local_admin_', 'required'].join(),
        ]
      : forbiddenProductionTerms;

  Iterable<File> _productionSources() sync* {
    for (final relativeRoot in <String>['apps', 'packages', 'lib', 'docs']) {
      final directory = Directory(p.join(workspaceRoot, relativeRoot));
      if (!directory.existsSync()) continue;
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File) continue;
        final normalized = p.normalize(entity.path);
        if (normalized.contains('${p.separator}test${p.separator}') ||
            normalized.contains(
              '${p.separator}integration_test${p.separator}',
            ) ||
            normalized.endsWith('.g.dart') ||
            normalized.endsWith('.freezed.dart')) {
          continue;
        }
        if (normalized.endsWith('.dart') || normalized.endsWith('.md')) {
          yield entity;
        }
      }
    }
  }

  String _snakeCase(String value) => value
      .replaceAllMapped(RegExp('(?<=[a-z0-9])(?=[A-Z])'), (_) => '_')
      .toLowerCase();

  String _upperCamelCase(String value) => value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join();

  bool _hasExecutableScenario(String source, int markerOffset) {
    final testStart = source.lastIndexOf('testWidgets(', markerOffset);
    if (testStart < 0) return false;
    final body = source.substring(testStart, markerOffset);
    return body.contains('await ') && body.contains('expect(');
  }

  Set<String> _apiMethods(String source) {
    final methods = _interfaceMethods(source, 'TinestApi');
    const features = <String, String>{
      'WorkspacesApi': 'workspaces',
      'SessionsApi': 'sessions',
      'AgentsApi': 'agents',
      'PluginsApi': 'plugins',
      'PromptsApi': 'prompts',
      'ModelsApi': 'models',
      'ProvidersApi': 'providers',
      'McpApi': 'mcp',
      'TerminalsApi': 'terminals',
      'AttachmentsApi': 'attachments',
      'RelayApi': 'relay',
    };
    for (final MapEntry(key: interfaceName, value: owner) in features.entries) {
      methods.addAll(
        _interfaceMethods(
          source,
          interfaceName,
        ).map((method) => '$owner.$method'),
      );
    }
    return methods;
  }

  Set<String> _interfaceMethods(String source, String interfaceName) {
    final declaration = RegExp('abstract interface class $interfaceName\\s*\\{')
        .firstMatch(source);
    if (declaration == null) return <String>{};
    var depth = 1;
    var cursor = declaration.end;
    while (cursor < source.length && depth > 0) {
      final character = source[cursor];
      if (character == '{') depth += 1;
      if (character == '}') depth -= 1;
      cursor += 1;
    }
    if (depth != 0) return <String>{};
    final interfaceBody = source.substring(declaration.end, cursor - 1);
    return RegExp(r'\bFuture(?:<[^;]+>)?\s+(\w+)\s*\(')
        .allMatches(interfaceBody)
        .map((match) => match.group(1)!)
        .toSet();
  }

  Set<String> _routes(String source) =>
      RegExp(r'@?TypedGoRoute<(\w+)>')
          .allMatches(source)
          .map((match) => match.group(1)!)
          .toSet();

  List<File> _testSources() {
    final files = <File>[];
    for (final root in <Directory>[
      Directory(p.join(workspaceRoot, 'test')),
      Directory(p.join(workspaceRoot, 'packages')),
      Directory(p.join(workspaceRoot, 'apps')),
    ]) {
      if (!root.existsSync()) continue;
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final normalized = p.normalize(entity.path);
        if (p
            .split(normalized)
            .any(
              (segment) => segment == 'test' || segment == 'integration_test',
            )) {
          files.add(entity);
        }
      }
    }
    return files;
  }
}
