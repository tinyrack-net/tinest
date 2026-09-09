import 'dart:async';

import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/features/hosts/application/host_controller.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
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
  final cases =
      <
        ({
          String name,
          String location,
          FakeTinestApi Function(Future<void> gate) api,
        })
      >[
        (
          name: 'project catalog',
          location: const ProjectSettingsRoute(hostId: 'server').location,
          api: (gate) => FakeTinestApi(workspaceCatalogGate: gate),
        ),
        (
          name: 'agent definitions',
          location: const AgentSettingsRoute(hostId: 'server').location,
          api: (gate) => FakeTinestApi(agentDefinitionsGate: gate),
        ),
        (
          name: 'MCP servers',
          location: const McpSettingsRoute(hostId: 'server').location,
          api: (gate) => FakeTinestApi(mcpListGate: gate),
        ),
        (
          name: 'skills',
          location: const SkillSettingsRoute(hostId: 'server').location,
          api: (gate) => FakeTinestApi(skillListGate: gate),
        ),
        (
          name: 'providers',
          location: const ProviderSettingsRoute(hostId: 'server').location,
          api: (gate) => FakeTinestApi(providerConnectionsGate: gate),
        ),
        (
          name: 'models',
          location: const ModelSettingsRoute(hostId: 'server').location,
          api: (gate) => FakeTinestApi(modelSettingsGate: gate),
        ),
        (
          name: 'permissions',
          location: const PermissionSettingsRoute(hostId: 'server').location,
          api: (gate) => FakeTinestApi(permissionSettingsGate: gate),
        ),
      ];

  for (final testCase in cases) {
    testWidgets(
      '${testCase.name} keeps settings chrome available while loading',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1200, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final gate = Completer<void>();
        final router = await _pumpPendingRoute(
          tester,
          testCase.api(gate.future),
          testCase.location,
        );
        addTearDown(router.dispose);

        expect(find.text('설정'), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('settings-sidebar-surface')),
          findsOneWidget,
        );
        expect(find.byType(TRSkeleton), findsWidgets);
        expect(find.bySemanticsLabel('설정 불러오는 중'), findsWidgets);

        gate.complete();
        await tester.pumpAndSettle();
        expect(find.byType(SettingsSkeletonLayout), findsNothing);
      },
      tags: const <String>['feature_test__settings_async_loading__widget'],
    );
  }

  for (final testCase
      in <
        ({
          String name,
          String heading,
          String location,
          FakeTinestApi Function(Future<void> failure) api,
        })
      >[
        (
          name: 'MCP servers',
          heading: testL10n.mcpSettingsHeading,
          location: const McpSettingsRoute(hostId: 'server').location,
          api: (failure) => FakeTinestApi(mcpListGate: failure),
        ),
        (
          name: 'providers',
          heading: testL10n.providerSettingsConnected,
          location: const ProviderSettingsRoute(hostId: 'server').location,
          api: (failure) => FakeTinestApi(providerConnectionsGate: failure),
        ),
      ]) {
    testWidgets(
      '${testCase.name} exposes a load failure until explicit retry',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1200, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final failure = _failedSettingsGate('${testCase.name} unavailable');
        final router = await _pumpPendingRoute(
          tester,
          testCase.api(failure),
          testCase.location,
        );
        addTearDown(router.dispose);

        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(SettingsSkeletonLayout), findsNothing);
        expect(
          find.textContaining('${testCase.name} unavailable'),
          findsOneWidget,
        );
        expect(find.widgetWithText(TRButton, '다시 시도'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(TRPaneHeader),
            matching: find.text(testCase.heading),
          ),
          findsOneWidget,
        );
      },
      tags: const <String>['feature_test__settings_async_loading__widget'],
    );
  }

  testWidgets('approved devices show skeleton rows while the relay answers', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gate = Completer<void>();
    final api = FakeTinestApi(
      relayDevices: <RelayDeviceDto>[
        RelayDeviceDto(
          id: 'phone',
          name: 'My phone',
          registeredAt: DateTime.utc(2026, 8, 2),
          lastConnectedAt: DateTime.utc(2026, 8, 2),
        ),
      ],
    )..listRelayDevicesGate = gate.future;
    final router = await _pumpPendingRoute(
      tester,
      api,
      const DaemonConnectionsRoute(hostId: 'server').location,
    );
    addTearDown(router.dispose);

    expect(
      find.byKey(const ValueKey<String>('list-rows-skeleton')),
      findsOneWidget,
    );
    expect(find.text('My phone'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('list-rows-skeleton')),
      findsNothing,
    );
    expect(find.text('My phone'), findsOneWidget);
  }, tags: const <String>['feature_test__settings_async_loading__widget']);

  for (final testCase in <({String name, String location})>[
    (name: 'general', location: const GeneralSettingsRoute().location),
    (name: 'daemon', location: const DaemonSettingsRoute().location),
    (
      name: 'remote daemon editor',
      location: const EditHostRoute(hostId: 'server').location,
    ),
  ]) {
    testWidgets(
      '${testCase.name} replaces registry loading with settings content',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1200, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final gate = Completer<HostRegistryState>();
        final router = GoRouter(
          initialLocation: testCase.location,
          routes: $appRoutes,
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appServicesProvider.overrideWithValue(
                fakeAppServices(FakeTinestApi()),
              ),
              hostRegistryControllerProvider.overrideWith(
                () => _GateHostRegistryController(gate.future),
              ),
            ],
            child: MaterialApp.router(
              theme: testLightTheme,
              darkTheme: testDarkTheme,
              locale: testLocale,
              localizationsDelegates: testLocalizationsDelegates,
              supportedLocales: testSupportedLocales,
              routerConfig: router,
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(TRSkeleton), findsWidgets);
        expect(find.bySemanticsLabel('설정 불러오는 중'), findsWidgets);

        gate.complete(
          const HostRegistryState(
            settings: AppSettings(embeddedDaemonEnabled: false),
            profiles: <RemoteDaemonProfile>[],
            runtimes: <String, HostRuntimeSnapshot>{},
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SettingsSkeletonLayout), findsNothing);
      },
      tags: const <String>['feature_test__settings_async_loading__widget'],
    );
  }

  for (final testCase in <({String name, String location})>[
    (name: 'general', location: const GeneralSettingsRoute().location),
    (name: 'daemon', location: const DaemonSettingsRoute().location),
    (
      name: 'remote daemon editor',
      location: const EditHostRoute(hostId: 'server').location,
    ),
  ]) {
    testWidgets('${testCase.name} uses the shared settings hierarchy '
        'for a blocking error', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = GoRouter(
        initialLocation: testCase.location,
        routes: $appRoutes,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appServicesProvider.overrideWithValue(
              fakeAppServices(FakeTinestApi()),
            ),
            hostRegistryControllerProvider.overrideWith(
              _ErrorHostRegistryController.new,
            ),
          ],
          child: MaterialApp.router(
            theme: testLightTheme,
            darkTheme: testDarkTheme,
            locale: testLocale,
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final state = find.byType(SettingsEmptyState);
      expect(state, findsOneWidget);
      expect(
        find.descendant(
          of: state,
          matching: find.widgetWithText(TRText, '문제가 발생했습니다.'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('registry unavailable'), findsOneWidget);
      expect(find.widgetWithText(TRButton, '다시 시도'), findsOneWidget);
    }, tags: const <String>['feature_test__settings_async_loading__widget']);
  }
}

Future<void> _failedSettingsGate(String message) {
  final failure = Future<void>.sync(() => throw Exception(message));
  // The provider attaches after the first widget pump; consume the same
  // failure eagerly so the test binding does not report it as unhandled.
  unawaited(failure.then<void>((_) {}, onError: (Object _, StackTrace _) {}));
  return failure;
}

final class _GateHostRegistryController extends HostRegistryController {
  new(this.gate);

  final Future<HostRegistryState> gate;

  @override
  Future<HostRegistryState> build() => gate;
}

final class _ErrorHostRegistryController extends HostRegistryController {
  @override
  Future<HostRegistryState> build() =>
      Future<HostRegistryState>.error(StateError('registry unavailable'));
}

Future<GoRouter> _pumpPendingRoute(
  WidgetTester tester,
  FakeTinestApi api,
  String location,
) async {
  final router = GoRouter(initialLocation: location, routes: $appRoutes);
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
      ),
    ),
  );
  for (var frame = 0; frame < 8; frame++) {
    await tester.pump();
  }
  return router;
}
