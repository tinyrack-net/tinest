import 'dart:async';

import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/app/composition/app_services.dart';
import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/hosts/domain/host_ports.dart';
import 'package:app/src/features/workspace/application/directory_picker_port.dart';
import 'package:client/client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/fake_tinest_api.dart';
import '../../support/localization.dart';

void main() {
  const home = '/home/tester';
  const directories = <String, List<String>>{
    '/': <String>['/home'],
    home: <String>['$home/projects'],
    '$home/projects': <String>['$home/projects/tinest'],
  };

  ServerInfoDto info({String? homeDirectory}) => ServerInfoDto(
    serverId: 'server',
    version: 'test',
    protocolVersion: tinestProtocolMajor,
    features: const <String, bool>{},
    homeDirectory: homeDirectory,
  );

  testWidgets(
    'a remote daemon opens the browser at the home it reported',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi(
        serverInfo: info(homeDirectory: home),
        directories: directories,
      );
      final router = await _pump(tester, api);
      addTearDown(router.dispose);

      await _openProjectPicker(tester);

      expect(find.text('Daemon의 폴더 선택'), findsOneWidget);
      expect(api.suggestedQueries.first, home);
      expect(find.text('projects'), findsOneWidget);
    },
    tags: const <String>['feature_test__workspace_registration__widget'],
  );

  testWidgets(
    'a remote daemon without a reported home falls back to the drive root',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi(serverInfo: info(), directories: directories);
      final router = await _pump(tester, api);
      addTearDown(router.dispose);

      await _openProjectPicker(tester);

      expect(api.suggestedQueries.first, '/');
    },
    tags: const <String>['feature_test__workspace_registration__widget'],
  );

  testWidgets(
    'the embedded daemon registers the folder the native chooser returned',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi(
        serverInfo: info(homeDirectory: home),
        directories: directories,
      );
      final picker = _FakeDirectoryPicker(result: '$home/projects/tinest');
      final router = await _pump(tester, api, embedded: true, picker: picker);
      addTearDown(router.dispose);

      await _openProjectPicker(tester);

      // The embedded daemon shares this filesystem, so no RPC browser opens.
      expect(find.text('Daemon의 폴더 선택'), findsNothing);
      expect(api.suggestedQueries, isEmpty);
      expect(picker.initialDirectories, <String?>[home]);
      expect(api.registeredPaths, <String>['$home/projects/tinest']);
    },
    tags: const <String>['feature_test__workspace_registration__widget'],
  );

  testWidgets(
    'cancelling the native chooser registers nothing',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi(
        serverInfo: info(homeDirectory: home),
        directories: directories,
      );
      final picker = _FakeDirectoryPicker();
      final router = await _pump(tester, api, embedded: true, picker: picker);
      addTearDown(router.dispose);

      await _openProjectPicker(tester);

      expect(picker.calls, 1);
      expect(api.registeredPaths, isEmpty);
      expect(find.text('Daemon의 폴더 선택'), findsNothing);
    },
    tags: const <String>['feature_test__workspace_registration__widget'],
  );

  testWidgets(
    'repository registration shows progress while Git discovery is pending',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gate = Completer<void>();
      final api = FakeTinestApi(
        serverInfo: info(homeDirectory: home),
        directories: directories,
        registerWorkspaceGate: gate,
      );
      final picker = _FakeDirectoryPicker(result: '$home/projects/tinest');
      final router = await _pump(tester, api, embedded: true, picker: picker);
      addTearDown(router.dispose);

      await tester.tap(find.byKey(const ValueKey('new-workspace-project')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('new-workspace-project-add')),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(
          const ValueKey<String>('new-workspace-project-registering'),
        ),
        findsOneWidget,
      );
      expect(find.byType(TRSpinner), findsOneWidget);
      expect(find.bySemanticsLabel('Project 추가 중…'), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(api.registeredPaths, <String>['$home/projects/tinest']);
      expect(find.text('tinest'), findsWidgets);
    },
    tags: const <String>[
      'feature_test__workspace_async_loading__widget',
      'feature_test__workspace_registration__widget',
    ],
  );
}

Future<void> _openProjectPicker(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('new-workspace-project')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('new-workspace-project-add')));
  await tester.pumpAndSettle();
}

Future<GoRouter> _pump(
  WidgetTester tester,
  FakeTinestApi api, {
  bool embedded = false,
  DirectoryPickerPort? picker,
}) async {
  final router = GoRouter(
    initialLocation: const WorkspaceHomeRoute(compose: true).location,
    routes: $appRoutes,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appServicesProvider.overrideWithValue(
          embedded ? _embeddedServices(api) : fakeAppServices(api),
        ),
        directoryPickerProvider.overrideWithValue(picker),
      ],
      child: MaterialApp.router(
        theme: testLightTheme,
        darkTheme: testDarkTheme,
        locale: testLocale,
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        routerConfig: router,
        builder: (context, child) => TRTooltipProvider(child: child!),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// Services whose only online host is the app-owned daemon.
///
/// [AppSettings] enables the embedded daemon by default and no remote profile
/// is stored, so the pane finds exactly one host and skips the daemon prompt.
AppServices _embeddedServices(FakeTinestApi api) {
  final store = MemoryAppStore();
  return AppServices(
    settings: store,
    profiles: store,
    credentials: store,
    clients: _FakeClients(api),
    clientKind: 'test',
    embeddedLauncher: const _FakeEmbeddedLauncher(),
  );
}

final class _FakeDirectoryPicker implements DirectoryPickerPort {
  _FakeDirectoryPicker({this.result});

  final String? result;

  /// Initial directories requested by the pane, in call order.
  final List<String?> initialDirectories = <String?>[];
  int calls = 0;

  @override
  Future<String?> pickDirectory({String? initialDirectory}) async {
    calls += 1;
    initialDirectories.add(initialDirectory);
    return result;
  }
}

final class _FakeClients implements HostClientFactory {
  const _FakeClients(this.api);

  final TinestApi api;

  @override
  Future<TinestApi> connect({
    required HostConnection connection,
    required HostConnectionCredential credential,
    required String clientId,
    required String clientKind,
  }) async => api;
}

final class _FakeEmbeddedLauncher implements EmbeddedDaemonLauncher {
  const _FakeEmbeddedLauncher();

  @override
  Future<EmbeddedDaemonSession> start({
    required EmbeddedDaemonExposure exposure,
    required int port,
  }) async => const _FakeEmbeddedSession();
}

final class _FakeEmbeddedSession implements EmbeddedDaemonSession {
  const _FakeEmbeddedSession();

  @override
  HostEndpoint get endpoint => HostEndpoint.parse('ws://embedded.test/ws');

  @override
  DaemonCredentials get credentials => const DaemonCredentials(
    bearerToken: 'embedded-bearer',
  );

  @override
  String get serverId => 'embedded-server';

  @override
  Future<void> stop() async {}
}
