import 'dart:io';

import 'package:app/testing/app/composition/app_services.dart';
import 'package:app/testing/app/tinest_app.dart';
import 'package:app/testing/features/hosts/domain/host_models.dart';
import 'package:app/testing/features/hosts/domain/host_ports.dart';
import 'package:app/testing/features/workspace/presentation/widgets/directory_browser.dart';
import 'package:app/testing/shared/presentation/tinest_selection_row.dart';
import 'package:client/client.dart';
import 'package:daemon/daemon.dart';
import 'package:desktop_app/src/embedded_daemon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import 'support/ephemeral_port.dart';
import 'support/pump_until.dart';
import 'support/real_daemon_fixture.dart';
import 'support/tap_visible.dart';
import 'support/temporary_directory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'remote daemon rejects a token, recovers, exposes workspaces, and deletes',
    (tester) async {
      tester.binding.platformDispatcher.localeTestValue = const Locale('ko');
      addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
      final fixture = await RealDaemonFixture.start(
        id: 'daemon-workspace',
        configureRemoteProfile: false,
      );
      addTearDown(fixture.dispose);
      final workspace = Directory('${fixture.home.path}/registered-project')
        ..createSync();
      final setup = await fixture.connect(clientId: 'workspace-setup');
      addTearDown(setup.close);

      await tester.pumpWidget(TinestApp(services: fixture.services));
      await tester.pumpAndSettle();
      expect(find.text('설정된 daemon이 없습니다.'), findsOneWidget);

      await tapVisible(
        tester,
        find.byKey(const ValueKey<String>('workspace-settings-button')),
        'the workspace settings button',
      );
      await tester.pumpAndSettle();
      await _openSettingsCategory(tester, 'daemon');
      await tester.tap(find.widgetWithText(TRButton, '기기 연결'));
      await tester.pumpAndSettle();
      final directConnection = find.text('직접 연결');
      await tester.ensureVisible(directConnection);
      await tester.pumpAndSettle();
      await tester.tap(directConnection);
      await tester.pumpAndSettle();
      await tester.enterText(_field('remote-host-label'), 'Recovering daemon');
      await tester.enterText(
        _field('remote-host-address'),
        fixture.daemon.boundEndpoint.toString(),
      );
      await tester.enterText(
        _field('remote-host-token'),
        'incorrect-token-0123456789abcdef0123456789',
      );
      await tester.tap(find.widgetWithText(TRButton, '저장'));
      await tester.pumpAndSettle();
      await _pumpUntil(
        tester,
        find.textContaining('Daemon이 bearer token을 거부했습니다.'),
      );
      expect(find.text('Recovered Workspace'), findsNothing);

      await tester.tap(_action('연결 편집'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('remote-host-label'), 'Recovered daemon');
      await tester.enterText(_field('remote-host-token'), fixture.token);
      await tester.tap(find.widgetWithText(TRButton, '저장'));
      await tester.pumpAndSettle();
      await _pumpUntil(tester, find.textContaining('온라인'));
      expect(fixture.store.profiles.single.label, 'Recovered daemon');
      expect(
        fixture.store.tokens[fixture
            .store
            .profiles
            .single
            .connections
            .single
            .credentialKey],
        fixture.token,
      );

      // Settings has no parent on a desktop window: one press leaves it.
      await tester.tap(
        find.byKey(const ValueKey<String>('settings-back-button')),
      );
      await _pumpUntil(
        tester,
        find.byKey(const ValueKey('workspace-new-button')),
      );
      expect(
        (await setup.workspaces.getWorkspaceCatalog()).workspaces,
        isEmpty,
      );

      await _openProjectDirectoryBrowser(tester);
      // The browser starts at the home the daemon reported, not the root.
      expect(
        tester
            .widget<EditableText>(_field('directory-browser-path'))
            .controller
            .text,
        fixture.home.path,
      );
      final missingPath = '${fixture.home.path}/missing-project';
      await _replaceFieldText(tester, 'directory-browser-path', missingPath);
      await tester.tap(find.widgetWithText(TRButton, '이 폴더 선택'));
      await _pumpUntil(
        tester,
        find.byKey(const ValueKey<String>('new-workspace-error')),
      );
      expect(
        (await setup.workspaces.getWorkspaceCatalog()).workspaces,
        isEmpty,
      );

      await _openProjectDirectoryBrowser(tester);
      await tester.tap(find.widgetWithText(TRButton, '취소'));
      await tester.pumpAndSettle();
      expect(
        (await setup.workspaces.getWorkspaceCatalog()).workspaces,
        isEmpty,
      );

      await _openProjectDirectoryBrowser(tester);
      await _replaceFieldText(tester, 'directory-browser-path', workspace.path);
      await tester.pump(directoryBrowserDebounce);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TRButton, '이 폴더 선택'));
      await _pumpUntil(tester, find.text('registered-project'));
      final catalog = await setup.workspaces.getWorkspaceCatalog();
      expect(
        FileSystemEntity.identicalSync(
          catalog.workspaces.single.rootPath,
          workspace.path,
        ),
        isTrue,
      );
      expect(find.textContaining('Recovered daemon · '), findsOneWidget);

      final workspaceId = catalog.workspaces.single.id;
      final menu = find.byKey(ValueKey<String>('workspace-menu-$workspaceId'));
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey<String>('workspace-unregister-$workspaceId')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TRButton, '취소'));
      await tester.pumpAndSettle();
      expect(
        (await setup.workspaces.getWorkspaceCatalog()).workspaces,
        hasLength(1),
      );

      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey<String>('workspace-unregister-$workspaceId')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-unregister-confirm')),
      );
      await _pumpUntil(tester, find.text('아직 workspace가 없습니다.'));
      expect(
        (await setup.workspaces.getWorkspaceCatalog()).workspaces,
        isEmpty,
      );

      await tapVisible(
        tester,
        find.byKey(const ValueKey<String>('workspace-settings-button')),
        'the workspace settings button',
      );
      await tester.pumpAndSettle();
      await _openSettingsCategory(tester, 'daemon');
      await tester.tap(_action('연결 편집'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TRButton, '삭제').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TRButton, '삭제').last);
      await tester.pumpAndSettle();
      expect(fixture.store.profiles, isEmpty);
      expect(fixture.store.tokens, isEmpty);
      expect(find.text('설정된 daemon이 없습니다.'), findsOneWidget);
    },
    tags: const <String>[
      'feature_scenario__daemon_management__remote_host_lifecycle__e2e',
      'feature_scenario__daemon_management__connection_failure_recovery__e2e',
      'feature_scenario__daemon_authentication__invalid_token_rejected__e2e',
      'feature_scenario__workspace_catalog__empty_offline_recovery__e2e',
      // Long executable tag names are mandated by the feature verifier.
      // ignore: lines_longer_than_80_chars
      'feature_scenario__workspace_registration__browse_register_unregister__e2e',
      'feature_scenario__workspace_registration__invalid_path_cancel__e2e',
    ],
  );

  testWidgets(
    'embedded daemon stops, reports restart failure, and recovers',
    (tester) async {
      tester.binding.platformDispatcher.localeTestValue = const Locale('ko');
      addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
      final home = await Directory.systemTemp.createTemp('embedded-e2e-');
      addTearDown(() => deleteTemporaryDirectory(home));
      const token = 'embedded-e2e-token-0123456789abcdef0123456789';
      final launcher = _ControlledEmbeddedLauncher(
        EphemeralEmbeddedDaemonLauncher(
          IsolateEmbeddedDaemonLauncher(
            resolveConfig: () => DaemonConfig(
              homeDirectory: home.path,
              port: 0,
              bearerToken: token,
              useEnvironmentCredentials: false,
            ),
          ),
        ),
      );
      final store = MemoryAppStore(
        settings: const AppSettings(embeddedDaemonPort: testEmbeddedDaemonPort),
      );
      await tester.pumpWidget(
        TinestApp(
          services: AppServices(
            settings: store,
            profiles: store,
            credentials: store,
            clients: const WebSocketHostClientFactory(),
            clientKind: 'embedded-lifecycle-e2e',
            embeddedLauncher: launcher,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(
        tester,
        find.byKey(const ValueKey<String>('workspace-settings-button')),
        'the workspace settings button',
      );
      await tester.pumpAndSettle();
      await _openSettingsCategory(tester, 'daemon');
      await _pumpUntil(tester, find.textContaining('온라인'));

      const changedPort = testEmbeddedDaemonPort + 1;
      final portField = find.descendant(
        of: find.byKey(const ValueKey<String>('embedded-daemon-port')),
        matching: find.byType(EditableText),
      );
      await tester.enterText(portField, '$changedPort');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('embedded-daemon-port-apply')),
      );
      await pumpUntilCondition(
        tester,
        () => store.settings.embeddedDaemonPort == changedPort,
        'the embedded daemon port to persist',
      );
      expect(store.settings.embeddedDaemonPort, changedPort);
      await pumpUntilCondition(
        tester,
        () => launcher.starts == 2 && launcher.stops == 1,
        'the port-change restart to finish',
      );
      await _pumpUntil(tester, find.textContaining('온라인'));

      final toggle = find.widgetWithText(TinestSwitchRow, '내장 daemon');
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TRButton, '중지'));
      await tester.pumpAndSettle();
      expect(store.settings.embeddedDaemonEnabled, isFalse);
      await pumpUntilCondition(
        tester,
        () => launcher.stops == 2,
        'the disabled embedded daemon to stop',
      );
      expect(launcher.stops, 2);

      launcher.failNext = true;
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await _pumpUntil(tester, find.textContaining('planned restart failure'));
      expect(store.settings.embeddedDaemonEnabled, isTrue);

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TRButton, '중지'));
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await _pumpUntil(tester, find.textContaining('온라인'));
      expect(store.settings.embeddedDaemonEnabled, isTrue);
      expect(launcher.starts, 4);
    },
    tags: const <String>[
      'feature_scenario__daemon_management__embedded_host_lifecycle__e2e',
      'feature_scenario__daemon_exposure__restart_failure_recovery__e2e',
      'feature_scenario__daemon_exposure__port_change_restart__e2e',
    ],
  );
}

Future<void> _openProjectDirectoryBrowser(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('workspace-new-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('new-workspace-project')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('new-workspace-project-add')));
  await _pumpUntil(tester, find.text('Daemon의 폴더 선택'));
}

Finder _field(String key) => find.descendant(
  of: find.byKey(ValueKey<String>(key)),
  matching: find.byType(EditableText),
);

Future<void> _openSettingsCategory(WidgetTester tester, String category) async {
  final row = find.byKey(ValueKey<String>('settings-category-row-$category'));
  await _pumpUntil(tester, row);
  await tester.tap(row);
  await tester.pumpAndSettle();
}

Future<void> _replaceFieldText(
  WidgetTester tester,
  String key,
  String value,
) async {
  final field = tester.widget<TRTextField>(find.byKey(ValueKey<String>(key)));
  field.controller!.text = value;
  field.onChanged!(value);
  await tester.pump();
  expect(field.controller!.text, value);
}

Finder _action(String label) => find.byWidgetPredicate(
  (widget) => widget is TRIconButton && widget.label == label,
  description: 'Tinyrack action labelled "$label"',
);

/// Waits for [finder], naming everything on screen when it never arrives.
Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration budget = e2eWaitBudget,
}) async {
  try {
    await pumpUntil(tester, finder, budget: budget);
  } on TestFailure catch (failure) {
    final visibleText = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .whereType<String>()
        .toList(growable: false);
    throw TestFailure('${failure.message} Text: $visibleText');
  }
}

final class _ControlledEmbeddedLauncher implements EmbeddedDaemonLauncher {
  new(this.delegate);

  final EmbeddedDaemonLauncher delegate;
  bool failNext = false;
  int starts = 0;
  int stops = 0;

  @override
  Future<EmbeddedDaemonSession> start({
    required EmbeddedDaemonExposure exposure,
    required int port,
  }) async {
    starts += 1;
    if (failNext) {
      failNext = false;
      throw const HostConnectionFailure.network('planned restart failure');
    }
    return _CountingSession(
      await delegate.start(exposure: exposure, port: port),
      onStop: () => stops += 1,
    );
  }
}

final class _CountingSession implements EmbeddedDaemonSession {
  const new(this.delegate, {required this.onStop});

  final EmbeddedDaemonSession delegate;
  final void Function() onStop;

  @override
  DaemonCredentials get credentials => delegate.credentials;

  @override
  HostEndpoint get endpoint => delegate.endpoint;

  @override
  String get serverId => delegate.serverId;

  @override
  Future<void> stop() async {
    await delegate.stop();
    onStop();
  }
}
