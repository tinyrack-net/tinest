import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/app/app_identity.dart';
import 'package:app/src/app/tinest_app.dart';
import 'package:app/src/app/version.g.dart';
import 'package:app/src/features/desktop/infrastructure/desktop_shell.dart';
import 'package:app/src/features/desktop/presentation/desktop_title_bar.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/hosts/domain/host_ports.dart';
import 'package:app/src/shared/presentation/tinest_icons.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/fake_desktop_ports.dart';
import '../../support/fake_tinest_api.dart';

void main() {
  ({
    Widget app,
    FakeDesktopWindow window,
    FakeTrayIcon tray,
    FakeAppTerminator terminator,
    MemoryAppStore store,
  })
  build({
    FakeTinestApi? api,
    bool connected = false,
    DesktopWindowChrome chrome = DesktopWindowChrome.custom,
  }) {
    final window = FakeDesktopWindow(chrome: chrome);
    final tray = FakeTrayIcon()..calls = window.calls;
    final terminator = FakeAppTerminator(calls: window.calls);
    final store = MemoryAppStore(
      settings: const AppSettings(
        embeddedDaemonEnabled: false,
        localeTag: 'en',
      ),
    );
    return (
      app: TinestApp(
        services: fakeAppServices(
          api ?? FakeTinestApi(),
          connected: connected,
          store: store,
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

  testWidgets(
    'Linux custom title bar drives window controls and close-to-tray',
    (tester) async {
      final linuxChrome = PluginDesktopWindow(platform: TargetPlatform.linux)
          .chrome;
      final harness = build(chrome: linuxChrome);
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      expect(find.byType(DesktopMenuBar), findsOneWidget);
      final borderFinder = find.byKey(
        const ValueKey<String>('desktop-title-bar-border'),
      );
      expect(borderFinder, findsOneWidget);
      final borderBox = tester.widget<DecoratedBox>(borderFinder);
      expect(borderBox.position, DecorationPosition.foreground);
      final borderDecoration = borderBox.decoration as BoxDecoration;
      expect(
        (borderDecoration.border! as Border).bottom.color,
        tester.element(borderFinder).tinyrackTheme.border,
      );
      for (final entry in <String, IconData>{
        'desktop-title-bar-minimize': TinestIcons.minimize,
        'desktop-title-bar-maximize': TinestIcons.maximize,
        'desktop-title-bar-close': TinestIcons.close,
      }.entries) {
        expect(
          tester
              .widget<Icon>(
                find.descendant(
                  of: find.byKey(ValueKey<String>(entry.key)),
                  matching: find.byType(Icon),
                ),
              )
              .icon,
          entry.value,
        );
      }
      await tester.drag(
        find.byKey(const ValueKey<String>('desktop-title-bar-drag-area')),
        const Offset(30, 0),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('desktop-title-bar-minimize')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('desktop-title-bar-maximize')),
      );
      await tester.pump();

      expect(harness.window.drags, 1);
      expect(harness.window.minimizes, 1);
      expect(harness.window.maximizeToggles, 1);
      expect(
        find.byKey(const ValueKey<String>('desktop-title-bar-restore')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Icon>(
              find.descendant(
                of: find.byKey(
                  const ValueKey<String>('desktop-title-bar-restore'),
                ),
                matching: find.byType(Icon),
              ),
            )
            .icon,
        TinestIcons.restoreWindow,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('desktop-title-bar-close')),
      );
      await tester.pumpAndSettle();
      expect(harness.window.hides, 1);
      expect(harness.terminator.terminations, 0);
      expect(harness.window.visible.value, isFalse);
    },
    tags: const <String>['feature_test__desktop_window_chrome__widget'],
  );

  testWidgets(
    'localized menus navigate, toggle the sidebar, show about, and quit',
    (tester) async {
      final harness = build();
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();
      expect(find.text('New workspace'), findsWidgets);
      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Quit'), findsWidgets);

      await tester.tap(
        find.descendant(
          of: find.byType(TRMenuItem),
          matching: find.text('Settings'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Display language'), findsOneWidget);

      await tester.tap(find.text('Help'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('About ${AppIdentity.displayName}'));
      await tester.pumpAndSettle();
      expect(find.text(AppIdentity.displayName), findsWidgets);
      expect(find.text(packageVersion), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      const shortcut = SingleActivator(
        LogicalKeyboardKey.keyB,
        control: true,
        shift: true,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(shortcut.trigger);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(harness.store.settings.sidebarCollapsed, isTrue);

      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quit'));
      await tester.pumpAndSettle();
      for (
        var attempt = 0;
        attempt < 20 && harness.terminator.terminations == 0;
        attempt += 1
      ) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(
        harness.window.calls,
        containsAllInOrder(<String>[
          'hide',
          'destroyTray',
          'releaseClose',
          'terminate',
        ]),
      );
    },
    tags: const <String>['feature_test__desktop_window_chrome__widget'],
  );

  testWidgets('the View menu toggles the sidebar repeatedly', (tester) async {
    final harness = build();
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    Finder viewItem(String label) => find.descendant(
      of: find.byType(TRMenuItem),
      matching: find.text(label),
    );

    Future<void> openViewMenu() async {
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
    }

    await openViewMenu();
    expect(viewItem('Hide sidebar'), findsOneWidget);
    expect(
      tester.widget<TRMenuCheckboxItem>(find.byType(TRMenuCheckboxItem)).value,
      isTrue,
    );

    await tester.tap(viewItem('Hide sidebar'));
    await tester.pumpAndSettle();
    expect(harness.store.settings.sidebarCollapsed, isTrue);
    expect(find.byType(TRMenuCheckboxItem), findsNothing);

    await openViewMenu();
    expect(viewItem('Show sidebar'), findsOneWidget);
    expect(
      tester.widget<TRMenuCheckboxItem>(find.byType(TRMenuCheckboxItem)).value,
      isFalse,
    );

    await tester.tap(viewItem('Show sidebar'));
    await tester.pumpAndSettle();
    expect(harness.store.settings.sidebarCollapsed, isFalse);
    expect(find.byType(TRMenuCheckboxItem), findsNothing);

    await openViewMenu();
    expect(viewItem('Hide sidebar'), findsOneWidget);
    expect(
      tester.widget<TRMenuCheckboxItem>(find.byType(TRMenuCheckboxItem)).value,
      isTrue,
    );
  }, tags: const <String>['feature_test__desktop_window_chrome__widget']);

  testWidgets(
    'the title bar and its controls sit on the compact control size',
    (tester) async {
      final harness = build();
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      // The row is one compact control plus the menubar's own inset, so the
      // menubar fills it exactly instead of being clipped by a taller frame.
      expect(
        desktopMenuBarHeight,
        TRControlMetrics.heightOf(TRUiSize.sm) + TRSpacing.extraSmall * 2,
      );
      expect(
        tester.getSize(find.byType(TRMenubar)).height,
        desktopMenuBarHeight,
      );
      // Close is not tinted apart from its siblings, so the group reads as
      // quiet chrome rather than three competing controls.
      for (final key in <String>[
        'desktop-title-bar-minimize',
        'desktop-title-bar-maximize',
        'desktop-title-bar-close',
      ]) {
        final button = tester.widget<TRIconButton>(
          find.descendant(
            of: find.byKey(ValueKey<String>(key)),
            matching: find.byType(TRIconButton),
          ),
        );
        expect(button.uiSize, TRUiSize.sm);
        expect(button.intent, TRIntent.neutral);
        expect(button.appearance, TRAppearance.ghost);
      }
    },
    tags: const <String>['feature_test__desktop_window_chrome__widget'],
  );

  testWidgets(
    'menubar triggers render at the size the menubar styles its slots with',
    (tester) async {
      final harness = build();
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      // The trigger label is a menubar slot, so it must render at the control
      // size the bar resolves rather than naming a typography role of its own.
      final menubar = tester.widget<TRMenubar>(find.byType(TRMenubar));
      final expected = TRControlMetrics.fontSizeOf(menubar.uiSize!);
      for (final label in <String>['File', 'View', 'Help']) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        expect(
          paragraph.text.style?.fontSize,
          expected,
          reason: '$label must inherit the menubar slot style, not name a role',
        );
      }
    },
    tags: const <String>['feature_test__desktop_window_chrome__widget'],
  );

  testWidgets('an open menu drops below the menubar instead of covering it', (
    tester,
  ) async {
    final harness = build();
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    final menubar = tester.getRect(find.byType(TRMenubar));
    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();

    final panel = tester.getRect(
      find
          .ancestor(
            of: find.widgetWithText(TRMenuItem, 'Quit'),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(panel.top, menubar.bottom);
    expect(tester.getRect(find.text('Help')).overlaps(panel), isFalse);
  }, tags: const <String>['feature_test__desktop_window_chrome__widget']);

  testWidgets(
    'a menu stays open when a keyboard tooltip on the home pane closes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final now = DateTime.utc(2026, 8, 5);
      final workspace = WorkspaceDto(
        id: 'workspace',
        name: 'Tinest',
        rootPath: '/repos/tinest',
        kind: WorkspaceKind.git,
        createdAt: now,
      );
      final harness = build(
        api: FakeTinestApi(
          workspaces: <WorkspaceDto>[workspace],
          worktrees: <WorktreeDto>[
            WorktreeDto(
              id: 'checkout',
              workspaceId: workspace.id,
              name: 'main',
              path: workspace.rootPath,
              branch: 'main',
              kind: WorktreeKind.checkout,
              isTinestOwned: false,
              createdAt: now,
            ),
          ],
        ),
        connected: true,
      );
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      // Traverse with Tab until the project chip's focus tooltip appears, the
      // way a keyboard user reaches it on the home pane.
      final chip = find.byKey(const ValueKey<String>('new-workspace-project'));
      expect(chip, findsOneWidget);
      // This harness pins the app to English, so the tooltip is read from
      // the same locale the widget renders in rather than written out.
      final tooltip = lookupAppLocalizations(const Locale('en'))
          .workspaceProjectChipTooltip;
      var reached = false;
      for (var attempt = 0; attempt < 40 && !reached; attempt += 1) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();
        reached = find.text(tooltip).evaluate().isNotEmpty;
      }
      expect(
        reached,
        isTrue,
        reason: 'Tab traversal never opened the project chip tooltip',
      );

      final quitItem = find.descendant(
        of: find.byType(TRMenuItem),
        matching: find.text('Quit'),
      );
      await tester.tap(find.text('File'));
      await tester.pump();
      expect(quitItem, findsOneWidget);

      // Closing the tooltip must not restore focus to the chip, which would
      // pull focus out of the menu scope and dismiss the menu.
      await tester.pumpAndSettle();
      expect(quitItem, findsOneWidget);
      expect(find.text('프로젝트 선택'), findsNothing);
    },
    tags: const <String>[
      'feature_test__desktop_window_chrome__widget',
      'feature_test__workspace_catalog__widget',
    ],
  );
}
