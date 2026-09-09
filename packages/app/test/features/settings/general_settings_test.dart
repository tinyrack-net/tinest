import 'package:app/src/app/composition/app_services.dart';
import 'package:app/src/app/tinest_app.dart';
import 'package:app/src/features/desktop/infrastructure/desktop_shell.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/hosts/domain/host_ports.dart';
import 'package:app/src/shared/presentation/settings_layout.dart';
import 'package:app/src/shared/presentation/tinest_list_row.dart';
import 'package:app/src/shared/presentation/tinest_selection_row.dart';
import 'package:client/client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/fake_desktop_ports.dart';

void main() {
  testWidgets(
    'general controls stay beside their labels at phone and desktop widths',
    (tester) async {
      // The viewport rather than the surface: `setSurfaceSize` does not move
      // `MediaQuery`, so both passes would quietly run at the same width.
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      for (final size in <Size>[
        // A phone, and the width that used to lay the controls down flat.
        const Size(390, 844),
        const Size(696, 900),
      ]) {
        tester.view.physicalSize = size;
        final store = MemoryAppStore(
          settings: const AppSettings(embeddedDaemonEnabled: false),
        );
        await tester.pumpWidget(_app(store));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey<String>('workspace-settings-button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('일반'));
        await tester.pumpAndSettle();

        for (final key in <String>[
          'general-settings-theme-mode',
          'general-settings-language',
        ]) {
          final reason = '$key at ${size.width}';
          final setting = find.ancestor(
            of: find.byKey(ValueKey<String>(key)),
            matching: find.byType(SettingsRow),
          );
          final rowFinder = find.descendant(
            of: setting,
            matching: find.byType(TinestListRow),
          );
          final row = tester.widget<TinestListRow>(rowFinder);
          expect(
            row.trailingLayout,
            TinestListRowTrailingLayout.inline,
            reason: reason,
          );

          final rowRect = tester.getRect(rowFinder);
          final rowPadding = SettingsRow.resolvedPadding(
            tester.element(rowFinder),
          ).resolve(Directionality.of(tester.element(rowFinder)));
          final control = tester.getRect(find.byKey(ValueKey<String>(key)));
          // The control shows its current value and no more, leaving the rest
          // of the line to the label instead of claiming the whole row.
          expect(
            control.width,
            lessThan(rowRect.width - rowPadding.horizontal),
            reason: reason,
          );
          expect(
            control.right,
            lessThanOrEqualTo(rowRect.right - rowPadding.right + 0.01),
            reason: reason,
          );
          // One setting, one line: the row is as tall as the taller of its
          // label and its control, never the two stacked with a sentence
          // between them.
          expect(
            rowRect.height,
            lessThan(
              tester.getRect(find.text('테마')).height +
                  control.height +
                  rowPadding.vertical,
            ),
            reason: reason,
          );
        }
        expect(tester.takeException(), isNull, reason: 'at ${size.width}');
      }
    },
    tags: const <String>[
      'feature_test__settings_appearance__widget',
      'feature_test__settings_language__widget',
    ],
  );

  testWidgets(
    'the language setting switches the whole app and persists the choice',
    (tester) async {
      final store = MemoryAppStore(
        settings: const AppSettings(embeddedDaemonEnabled: false),
      );
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-settings-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('일반'));
      await tester.pumpAndSettle();

      // Nothing is stored yet, so the app follows the pinned platform locale.
      expect(store.settings.localeTag, isNull);
      expect(find.text('설정'), findsOneWidget);
      expect(find.text('시스템 설정 따름'), findsOneWidget);

      await tester.tap(_selectTrigger('general-settings-language'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();

      expect(store.settings.localeTag, 'en');
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Display language'), findsOneWidget);
      expect(find.text('설정'), findsNothing);

      await tester.tap(_selectTrigger('general-settings-language'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('日本語').last);
      await tester.pumpAndSettle();

      expect(store.settings.localeTag, 'ja');
      expect(find.text('設定'), findsOneWidget);
      expect(find.text('表示言語'), findsOneWidget);
      expect(find.text('Settings'), findsNothing);

      // Returning to the system default clears the stored tag rather than
      // storing the resolved locale, so the app follows the platform again.
      await tester.tap(_selectTrigger('general-settings-language'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('システムに合わせる').last);
      await tester.pumpAndSettle();

      expect(store.settings.localeTag, isNull);
      expect(find.text('설정'), findsOneWidget);
    },
    tags: const <String>['feature_test__settings_language__widget'],
  );

  testWidgets('a stored language is applied on the next start', (tester) async {
    final store = MemoryAppStore(
      settings: const AppSettings(
        embeddedDaemonEnabled: false,
        localeTag: 'en',
      ),
    );
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('workspace-settings-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
  }, tags: const <String>['feature_test__settings_language__widget']);

  testWidgets(
    'the appearance setting repaints the app and persists the choice',
    (tester) async {
      final store = MemoryAppStore(
        settings: const AppSettings(embeddedDaemonEnabled: false),
      );
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-settings-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('일반'));
      await tester.pumpAndSettle();

      // Nothing is stored yet, so the app follows the platform brightness,
      // which the widget test binding reports as light.
      expect(store.settings.themeMode, AppThemeMode.system);
      expect(_appThemeMode(tester), ThemeMode.system);
      expect(_renderedBrightness(tester), Brightness.light);

      await tester.tap(_selectTrigger('general-settings-theme-mode'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다크').last);
      await tester.pumpAndSettle();

      expect(store.settings.themeMode, AppThemeMode.dark);
      expect(_appThemeMode(tester), ThemeMode.dark);
      expect(_renderedBrightness(tester), Brightness.dark);

      await tester.tap(_selectTrigger('general-settings-theme-mode'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('라이트').last);
      await tester.pumpAndSettle();

      expect(store.settings.themeMode, AppThemeMode.light);
      expect(_appThemeMode(tester), ThemeMode.light);
      expect(_renderedBrightness(tester), Brightness.light);

      // Following the system again is a stored choice of its own rather than
      // an absent value, so it has to survive the same round trip.
      await tester.tap(_selectTrigger('general-settings-theme-mode'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('시스템 테마 따름').last);
      await tester.pumpAndSettle();

      expect(store.settings.themeMode, AppThemeMode.system);
      expect(_appThemeMode(tester), ThemeMode.system);
    },
    tags: const <String>['feature_test__settings_appearance__widget'],
  );

  testWidgets('a stored appearance choice is applied on the next start', (
    tester,
  ) async {
    final store = MemoryAppStore(
      settings: const AppSettings(
        embeddedDaemonEnabled: false,
        themeMode: AppThemeMode.dark,
      ),
    );
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(_appThemeMode(tester), ThemeMode.dark);
    expect(_renderedBrightness(tester), Brightness.dark);
  }, tags: const <String>['feature_test__settings_appearance__widget']);

  testWidgets('the startup toggles persist and re-register the login item', (
    tester,
  ) async {
    final store = MemoryAppStore(
      settings: const AppSettings(embeddedDaemonEnabled: false),
    );
    final autostart = FakeAutostartRegistration(enabled: true);
    await tester.pumpWidget(_app(store, autostart: autostart));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('workspace-settings-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('일반'));
    await tester.pumpAndSettle();

    expect(store.settings.startAtBoot, isTrue);
    expect(store.settings.startMinimizedAtBoot, isTrue);

    // Turning off "start minimized" keeps the login item but has to rewrite
    // the arguments it records.
    final startMinimized = find.byKey(
      const ValueKey<String>('general-settings-start-minimized'),
    );
    await tester.ensureVisible(startMinimized);
    await tester.pumpAndSettle();
    await tester.tap(startMinimized);
    await tester.pumpAndSettle();
    expect(store.settings.startMinimizedAtBoot, isFalse);
    expect(autostart.applications.last, (enabled: true, minimized: false));

    final startAtBoot = find.byKey(
      const ValueKey<String>('general-settings-start-at-boot'),
    );
    await tester.ensureVisible(startAtBoot);
    await tester.pumpAndSettle();
    await tester.tap(startAtBoot);
    await tester.pumpAndSettle();
    expect(store.settings.startAtBoot, isFalse);
    expect(autostart.enabled, isFalse);
    expect(autostart.applications.last, (enabled: false, minimized: false));
  }, tags: const <String>['feature_test__settings_startup__widget']);

  testWidgets(
    'start minimized is disabled while the app does not start at login',
    (tester) async {
      final store = MemoryAppStore(
        settings: const AppSettings(
          embeddedDaemonEnabled: false,
          startAtBoot: false,
        ),
      );
      final autostart = FakeAutostartRegistration();
      await tester.pumpWidget(_app(store, autostart: autostart));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-settings-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('일반'));
      await tester.pumpAndSettle();

      // Starting minimized only describes a login launch, so it cannot be
      // chosen while there is no login launch to describe. The stored choice
      // still shows, because the reader is losing access to it, not losing it.
      final startMinimized = find.byKey(
        const ValueKey<String>('general-settings-start-minimized'),
      );
      expect(
        tester.widget<TinestSwitchRow>(startMinimized),
        isA<TinestSwitchRow>()
            .having((row) => row.onChanged, 'onChanged', isNull)
            .having((row) => row.value, 'value', isTrue),
      );
      expect(
        tester.widget<TRSwitch>(
          find.descendant(of: startMinimized, matching: find.byType(TRSwitch)),
        ),
        isA<TRSwitch>()
            .having((control) => control.disabled, 'disabled', isTrue)
            .having((control) => control.checked, 'checked', isTrue),
      );

      // Turning start-at-login back on may not move the switch, because it
      // never claimed the preference had changed.
      expect(store.settings.startMinimizedAtBoot, isTrue);
      final startAtBoot = find.byKey(
        const ValueKey<String>('general-settings-start-at-boot'),
      );
      await tester.ensureVisible(startAtBoot);
      await tester.pumpAndSettle();
      await tester.tap(startAtBoot);
      await tester.pumpAndSettle();
      expect(autostart.applications.single, (enabled: true, minimized: true));
    },
    tags: const <String>['feature_test__settings_startup__widget'],
  );

  testWidgets('a disabled start minimized shows a stored off choice as off', (
    tester,
  ) async {
    final store = MemoryAppStore(
      settings: const AppSettings(
        embeddedDaemonEnabled: false,
        startAtBoot: false,
        startMinimizedAtBoot: false,
      ),
    );
    await tester.pumpWidget(
      _app(store, autostart: FakeAutostartRegistration()),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('workspace-settings-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('일반'));
    await tester.pumpAndSettle();

    // The row reports the stored preference either way, so it must not
    // report a stored off as on any more than it forced a stored on to off.
    expect(
      tester.widget<TinestSwitchRow>(
        find.byKey(const ValueKey<String>('general-settings-start-minimized')),
      ),
      isA<TinestSwitchRow>()
          .having((row) => row.onChanged, 'onChanged', isNull)
          .having((row) => row.value, 'value', isFalse),
    );
  }, tags: const <String>['feature_test__settings_startup__widget']);

  testWidgets('a build without login items hides the startup card entirely', (
    tester,
  ) async {
    final store = MemoryAppStore(
      settings: const AppSettings(embeddedDaemonEnabled: false),
    );
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('workspace-settings-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('일반'));
    await tester.pumpAndSettle();

    expect(find.text('표시 언어'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('general-settings-start-at-boot')),
      findsNothing,
    );
  }, tags: const <String>['feature_test__settings_startup__widget']);
}

Finder _selectTrigger(String key) => find.descendant(
  of: find.byKey(ValueKey<String>(key)),
  matching: find.byType(TextButton),
);

ThemeMode? _appThemeMode(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode;

/// Brightness the running app actually resolved, not the one it was offered.
Brightness _renderedBrightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Navigator).last)).brightness;

Widget _app(MemoryAppStore store, {AutostartRegistration? autostart}) =>
    TinestApp(
      services: AppServices(
        settings: store,
        profiles: store,
        credentials: store,
        clients: const _OfflineClients(),
        clientKind: 'test',
      ),
      autostart: autostart,
    );

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
