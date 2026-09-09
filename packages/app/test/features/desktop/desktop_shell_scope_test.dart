import 'dart:async';

import 'package:app/src/app/composition/app_services.dart';
import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/app/tinest_app.dart';
import 'package:app/src/features/desktop/domain/tray_menu_model.dart';
import 'package:app/src/features/desktop/infrastructure/desktop_shell.dart';
import 'package:app/src/features/desktop/presentation/desktop_shell_scope.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/hosts/domain/host_ports.dart';
import 'package:client/client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_desktop_ports.dart';
import '../../support/localization.dart';

void main() {
  ({
    Widget app,
    FakeDesktopWindow window,
    FakeTrayIcon tray,
    FakeAppTerminator terminator,
    MemoryAppStore store,
  })
  build({
    String? localeTag,
    bool startHidden = false,
    bool customTitleBar = false,
    Completer<void>? installGate,
    EmbeddedDaemonLauncher? embeddedLauncher,
  }) {
    final store = MemoryAppStore(
      settings: AppSettings(
        embeddedDaemonEnabled: embeddedLauncher != null,
        localeTag: localeTag,
      ),
    );
    final window = FakeDesktopWindow(
      visible: !startHidden,
      chrome: customTitleBar
          ? DesktopWindowChrome.custom
          : DesktopWindowChrome.native,
    );
    final tray = FakeTrayIcon(installGate: installGate)..calls = window.calls;
    final terminator = FakeAppTerminator(calls: window.calls);
    return (
      app: TinestApp(
        services: AppServices(
          settings: store,
          profiles: store,
          credentials: store,
          clients: const _OfflineClients(),
          clientKind: 'test',
          embeddedLauncher: embeddedLauncher,
        ),
        desktopWindow: window,
        trayIcon: tray,
        terminator: terminator,
        autostart: FakeAutostartRegistration(),
      ),
      window: window,
      tray: tray,
      terminator: terminator,
      store: store,
    );
  }

  testWidgets('closing the window hides it and leaves the process running', (
    tester,
  ) async {
    final harness = build();
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    expect(harness.window.preventingClose, isTrue);
    expect(harness.tray.installs, 1);
    expect(
      harness.tray.menu.entries
          .firstWhere((entry) => entry.key == trayItemToggleWindow)
          .label,
      testL10n.trayHideWindow,
    );

    harness.window.requestClose();
    await tester.pumpAndSettle();

    expect(harness.window.hides, 1);
    expect(harness.terminator.terminations, 0);
    expect(harness.window.visible.value, isFalse);
    // The tray now offers to bring the window back.
    expect(
      harness.tray.menu.entries
          .firstWhere((entry) => entry.key == trayItemToggleWindow)
          .label,
      testL10n.trayShowWindow,
    );
  }, tags: const <String>['feature_test__desktop_residency__widget']);

  testWidgets('the tray label flips even though a hidden window stops frames', (
    tester,
  ) async {
    final harness = build();
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();
    final settled = harness.tray.menus.length;

    // Hiding the window makes the Linux and Windows embedders report
    // AppLifecycleState.hidden, and `scheduleFrame` is a no-op while frames
    // are disabled. Anything that waits for a build or a post-frame callback
    // to reach the tray is therefore never going to run again.
    addTearDown(tester.binding.resetInternalState);
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.lifecycle.name,
      const StringCodec().encodeMessage('AppLifecycleState.hidden'),
      (_) {},
    );
    expect(tester.binding.framesEnabled, isFalse);

    harness.window.requestClose();
    // Deliberately not a pump: the production embedder would not give one.
    await tester.idle();

    expect(harness.tray.menus.length, greaterThan(settled));
    expect(
      harness.tray.menu.entries
          .firstWhere((entry) => entry.key == trayItemToggleWindow)
          .label,
      testL10n.trayShowWindow,
    );
  }, tags: const <String>['feature_test__desktop_residency__widget']);

  testWidgets('a hide the app did not ask for still flips the tray label', (
    tester,
  ) async {
    final harness = build();
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    // The window can leave the screen without the app calling hide, and the
    // native show and hide events are the only report of it.
    harness.window.emitNativeVisibility(visible: false);
    await tester.idle();

    expect(harness.window.hides, 0);
    expect(
      harness.tray.menu.entries
          .firstWhere((entry) => entry.key == trayItemToggleWindow)
          .label,
      testL10n.trayShowWindow,
    );
  }, tags: const <String>['feature_test__desktop_residency__widget']);

  testWidgets('the tray toggles the window and never quits by accident', (
    tester,
  ) async {
    final harness = build();
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    harness.tray.select(trayItemToggleWindow);
    await tester.pumpAndSettle();
    expect(harness.window.visible.value, isFalse);
    expect(harness.window.hides, 1);

    harness.tray.select(trayItemToggleWindow);
    await tester.pumpAndSettle();
    expect(harness.window.visible.value, isTrue);
    expect(harness.window.shows, 1);

    // Selecting the informational daemon row must do nothing at all.
    harness.tray.select(trayItemDaemonStatus);
    await tester.pumpAndSettle();
    expect(harness.window.hides, 1);
    expect(harness.window.shows, 1);
    expect(harness.terminator.terminations, 0);
  }, tags: const <String>['feature_test__desktop_residency__widget']);

  testWidgets(
    'clicking the tray icon reveals the window and repeating it keeps it up',
    (tester) async {
      final harness = build();
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      harness.window.requestClose();
      await tester.pumpAndSettle();
      expect(harness.window.visible.value, isFalse);

      harness.tray.activate();
      await tester.pumpAndSettle();
      expect(harness.window.visible.value, isTrue);
      expect(harness.window.shows, 1);
      expect(
        harness.tray.menu.entries
            .firstWhere((entry) => entry.key == trayItemToggleWindow)
            .label,
        testL10n.trayHideWindow,
      );

      // Windows reports a double click as two icon clicks. Showing has to be
      // idempotent, or the second click would hide what the first revealed.
      harness.tray.activate();
      await tester.pumpAndSettle();
      expect(harness.window.visible.value, isTrue);
      expect(harness.window.hides, 1);
    },
    tags: const <String>['feature_test__desktop_residency__widget'],
  );

  testWidgets(
    'the tray settings row reveals the window on the general settings page',
    (tester) async {
      final harness = build();
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      harness.window.requestClose();
      await tester.pumpAndSettle();
      expect(harness.window.visible.value, isFalse);

      harness.tray.select(trayItemOpenSettings);
      await tester.pumpAndSettle();

      expect(harness.window.visible.value, isTrue);
      expect(find.text(testL10n.generalLanguageLabel), findsOneWidget);
      expect(find.text(testL10n.generalStartupAtBootLabel), findsOneWidget);
    },
    tags: const <String>['feature_test__desktop_residency__widget'],
  );

  testWidgets(
    'custom desktop frame keeps stable root and settings navigators',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final harness = build(localeTag: 'ko', customTitleBar: true);
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-settings-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('settings-back-button')),
        findsOneWidget,
      );
      final rootNavigator = Navigator.of(
        tester.element(
          find.byKey(const ValueKey<String>('settings-back-button')),
        ),
        rootNavigator: true,
      );
      final settingsNavigator = SettingsShellRoute.$navigatorKey.currentState;
      expect(settingsNavigator, isNotNull);
      expect(find.byType(Navigator), findsNWidgets(2));

      await tester.tap(find.text(testL10n.settingsCategoryGeneral));
      await tester.pumpAndSettle();
      expect(find.text(testL10n.generalLanguageLabel), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey<String>('general-settings-theme-mode')),
          matching: find.byType(TextButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(testL10n.generalAppearanceDark).last);
      await tester.pumpAndSettle();

      await tester.tap(find.text(testL10n.settingsCategoryAdvanced));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('advanced-settings-reset-button')),
        findsOneWidget,
      );
      expect(
        Navigator.of(
          tester.element(
            find.byKey(const ValueKey<String>('settings-back-button')),
          ),
          rootNavigator: true,
        ),
        same(rootNavigator),
      );
      expect(
        SettingsShellRoute.$navigatorKey.currentState,
        same(settingsNavigator),
      );
      expect(find.byType(Navigator), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      // Every category was reached laterally, so leaving costs one press
      // whichever one is open.
      await tester.tap(
        find.byKey(const ValueKey<String>('settings-back-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('workspace-settings-button')),
        findsOneWidget,
      );
      debugDefaultTargetPlatformOverride = null;
    },
    tags: const <String>[
      'feature_test__app_navigation__widget',
      'feature_test__desktop_residency__widget',
    ],
  );

  testWidgets(
    'quitting hides the window, stops the daemon, and ends the process',
    (tester) async {
      final harness = build();
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      harness.tray.select(trayItemQuit);
      await tester.pumpAndSettle();

      expect(harness.tray.destroys, 1);
      expect(harness.terminator.terminations, 1);
      expect(harness.window.visible.value, isFalse);
      expect(harness.window.preventingClose, isFalse);
      // The window leaves the screen first so quit feels immediate, and the
      // process only ends once the teardown that needs it has run.
      expect(
        harness.window.calls,
        containsAllInOrder(<String>[
          'hide',
          'destroyTray',
          'releaseClose',
          'terminate',
        ]),
      );

      // A second selection must not tear anything down twice.
      harness.tray.select(trayItemQuit);
      await tester.pumpAndSettle();
      expect(harness.terminator.terminations, 1);
    },
    tags: const <String>['feature_test__desktop_residency__widget'],
  );

  testWidgets('quitting ends the process even when stopping the daemon fails', (
    tester,
  ) async {
    final harness = build(
      embeddedLauncher: const _StubLauncher(_StubSession.failing()),
    );
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    harness.tray.select(trayItemQuit);
    await tester.pumpAndSettle();

    expect(harness.terminator.terminations, 1);
  }, tags: const <String>['feature_test__desktop_residency__widget']);

  testWidgets('quitting ends the process when the daemon never stops', (
    tester,
  ) async {
    final harness = build(
      embeddedLauncher: const _StubLauncher(_StubSession.hanging()),
    );
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    harness.tray.select(trayItemQuit);
    await tester.pump();
    // A daemon that will not stop must not hold the app on screen forever.
    expect(harness.terminator.terminations, 0);

    await tester.pump(quitBudget);
    expect(harness.terminator.terminations, 1);
  }, tags: const <String>['feature_test__desktop_residency__widget']);

  testWidgets('the tray menu follows the language and ignores idle rebuilds', (
    tester,
  ) async {
    final english = build(localeTag: 'en');
    await tester.pumpWidget(english.app);
    await tester.pumpAndSettle();

    String quitLabel(FakeTrayIcon tray) => tray.menu.entries
        .firstWhere((entry) => entry.key == trayItemQuit)
        .label;

    // The stored language wins over the platform locale the harness pins.
    expect(quitLabel(english.tray), 'Quit');

    // A rebuild that changes nothing visible must not churn the native menu.
    final settled = english.tray.menus.length;
    await tester.pump();
    await tester.pumpAndSettle();
    expect(english.tray.menus, hasLength(settled));

    // A fresh tree, so the second app installs its own tray rather than
    // reusing the element the first one already attached to.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    final korean = build(localeTag: 'ko');
    await tester.pumpWidget(korean.app);
    await tester.pumpAndSettle();
    expect(quitLabel(korean.tray), '종료');
  }, tags: const <String>['feature_test__desktop_residency__widget']);

  testWidgets('a menu change during installation waits for the icon to exist', (
    tester,
  ) async {
    // The native tray rejects a menu before its icon exists, so a second
    // frame must not overtake an install that is still running.
    final gate = Completer<void>();
    final harness = build(localeTag: 'en', installGate: gate);
    await tester.pumpWidget(harness.app);
    await tester.pump();
    await tester.pump();

    expect(harness.tray.operations, <String>['install']);

    gate.complete();
    await tester.pumpAndSettle();

    expect(harness.tray.operations.first, 'install');
    expect(harness.tray.operations.sublist(1), everyElement('update'));
  }, tags: const <String>['feature_test__desktop_residency__widget']);

  testWidgets('a login launch starts hidden and offers to show the window', (
    tester,
  ) async {
    final harness = build(startHidden: true);
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    expect(
      harness.tray.menu.entries
          .firstWhere((entry) => entry.key == trayItemToggleWindow)
          .label,
      testL10n.trayShowWindow,
    );
    expect(harness.window.shows, 0);
  }, tags: const <String>['feature_test__desktop_residency__widget']);
}

final class _OfflineClients implements HostClientFactory {
  const new();

  @override
  Future<TinestApi> connect({
    required HostConnection connection,
    required HostConnectionCredential credential,
    required String clientId,
    required String clientKind,
  }) => Future<TinestApi>.error(const HostConnectionFailure.network('offline'));
}

final class _StubLauncher implements EmbeddedDaemonLauncher {
  const new(this.session);

  final EmbeddedDaemonSession session;

  @override
  Future<EmbeddedDaemonSession> start({
    required EmbeddedDaemonExposure exposure,
    required int port,
  }) async => session;
}

/// An embedded session whose stop misbehaves the way a wedged daemon does.
final class _StubSession implements EmbeddedDaemonSession {
  const new failing() : _hangs = false;

  const new hanging() : _hangs = true;

  final bool _hangs;

  @override
  HostEndpoint get endpoint => HostEndpoint.parse('ws://embedded.test/ws');

  @override
  DaemonCredentials get credentials =>
      const DaemonCredentials(bearerToken: 'embedded-bearer');

  @override
  String get serverId => 'embedded-server';

  @override
  Future<void> stop() => _hangs
      ? Completer<void>().future
      : Future<void>.error(StateError('The daemon refused to stop.'));
}
