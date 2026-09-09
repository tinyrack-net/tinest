import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/app/tinest_app.dart';
import 'package:app/src/features/hosts/domain/host_ports.dart';
import 'package:app/src/shared/presentation/tinest_ui_density.dart';
import 'package:app/src/shared/presentation/toast_messenger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import 'build_phase_provider_guard.dart';
import 'fake_tinest_api.dart';
import 'localization.dart';

/// Pumps the routed app at [initialLocation] and returns its router.
///
/// Tests that assert navigation behaviour need the router itself, so this
/// builds one explicitly rather than going through [TinestApp].
Future<GoRouter> pumpRoutedApp(
  WidgetTester tester,
  FakeTinestApi api, {
  required String initialLocation,
  MemoryAppStore? store,
  List<Override> overrides = const <Override>[],
  // A screen with a perpetual animation (a running subagent spinner, for
  // instance) never settles; such tests pump fixed frames instead.
  bool settle = true,
  // Makes page transitions render their destination immediately while keeping
  // the real Navigator route lifecycle under test.
  bool disableAnimations = false,
  // Selects a platform transition without mutating the process-wide test
  // platform, so Android predictive Back can be exercised deterministically.
  TargetPlatform? platform,
  // Extra observers a test installs for its own assertions. The build-phase
  // guard below is added on top of these, not instead of them.
  List<ProviderObserver> observers = const <ProviderObserver>[],
  // A non-null value opts this screen out of the build-phase guard, and the
  // string is the reason. There is no bare boolean on purpose: an unexplained
  // exemption is exactly how an enforcement gate rots into decoration.
  String? allowsBuildPhaseMutation,
}) async {
  final guard = allowsBuildPhaseMutation == null
      ? BuildPhaseProviderGuard()
      : null;
  if (guard != null) {
    // Asserted after the test body rather than at the offending call, so a
    // test that drains exceptions cannot swallow the failure.
    addTearDown(() => expect(guard.violations, isEmpty, reason: guard.report));
  }
  final router = GoRouter(initialLocation: initialLocation, routes: $appRoutes);
  await tester.pumpWidget(
    ProviderScope(
      observers: <ProviderObserver>[...observers, ?guard],
      overrides: [
        appServicesProvider.overrideWithValue(
          fakeAppServices(api, store: store),
        ),
        ...overrides,
      ],
      child: MaterialApp.router(
        theme: testLightTheme.copyWith(platform: platform),
        darkTheme: testDarkTheme.copyWith(platform: platform),
        locale: testLocale,
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        routerConfig: router,
        // Mirrors what TinestApp wraps every route in, so a screen under test
        // can report a result the same way it does when the app runs.
        builder: (context, child) {
          final content = TinestUiDensity(
            child: TinestToastScope(child: child ?? const SizedBox.shrink()),
          );
          return disableAnimations
              ? MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: true),
                  child: content,
                )
              : content;
        },
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    for (var frame = 0; frame < 8; frame += 1) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }
  return router;
}

/// Location of the top-most page of [router], including query parameters.
///
/// [GoRouter.routeInformationProvider] reports the base configuration, which
/// does not move when a route is pushed, so it cannot see a pushed task.
String currentLocation(GoRouter router) => router.state.uri.toString();
