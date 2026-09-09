import 'package:app/src/features/desktop/application/desktop_startup.dart';
import 'package:app/src/features/desktop/domain/tray_menu_model.dart';
import 'package:app/src/features/desktop/infrastructure/desktop_shell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  group('window adapter', () {
    test(
      'Windows and Linux replace native chrome before the window is shown',
      () async {
        Future<(PluginDesktopWindow, List<bool>)> build(
          TargetPlatform platform,
        ) async {
          final hidden = <bool>[];
          final window = PluginDesktopWindow(
            platform: platform,
            initialize: () async {},
            configureCustomTitleBar: ({required enabled}) async {
              hidden.add(enabled);
            },
            readyToShow: (onReady) => onReady(),
            hideWindow: () async {},
            windowIsVisible: () async => false,
          );
          await window.prepare(startHidden: true);
          return (window, hidden);
        }

        final windows = await build(TargetPlatform.windows);
        final linux = await build(TargetPlatform.linux);
        final macos = await build(TargetPlatform.macOS);

        expect(windows.$1.chrome, DesktopWindowChrome.custom);
        expect(linux.$1.chrome, DesktopWindowChrome.custom);
        expect(macos.$1.chrome, DesktopWindowChrome.native);
        expect(windows.$2, <bool>[true]);
        expect(linux.$2, <bool>[true]);
        expect(macos.$2, isEmpty);
      },
      tags: const <String>['feature_test__desktop_window_chrome__unit'],
    );

    test(
      'custom frame commands and native maximize events stay synchronized',
      () async {
        var drags = 0;
        var minimizes = 0;
        var maximizes = 0;
        var unmaximizes = 0;
        final listeners = <WindowListener>[];
        final window = PluginDesktopWindow(
          platform: TargetPlatform.windows,
          startWindowDrag: () async => drags += 1,
          minimizeWindow: () async => minimizes += 1,
          maximizeWindow: () async => maximizes += 1,
          unmaximizeWindow: () async => unmaximizes += 1,
          preventClose: ({required prevent}) async {},
          addWindowListener: listeners.add,
          removeWindowListener: listeners.remove,
        );

        await window.interceptClose(() {});
        await window.startDragging();
        await window.minimize();
        // Native maximize events may arrive after a second caption click.
        await window.toggleMaximized();
        expect(window.maximized.value, isTrue);

        await window.toggleMaximized();
        expect(window.maximized.value, isFalse);
        expect((drags, minimizes, maximizes, unmaximizes), (1, 1, 1, 1));

        listeners.single.onWindowMaximize();
        expect(window.maximized.value, isTrue);
        listeners.single.onWindowUnmaximize();
        expect(window.maximized.value, isFalse);
      },
      tags: const <String>['feature_test__desktop_window_chrome__unit'],
    );

    test(
      'preparing a normal launch shows the window and a hidden one does not',
      () async {
        var initialized = 0;
        var shown = 0;
        var hidden = 0;
        var nativeVisible = false;
        final window = PluginDesktopWindow(
          initialize: () async => initialized += 1,
          readyToShow: (onReady) => onReady(),
          showWindow: () async {
            shown += 1;
            nativeVisible = true;
          },
          hideWindow: () async {
            hidden += 1;
            nativeVisible = false;
          },
          windowIsVisible: () async => nativeVisible,
        );

        await window.prepare(startHidden: false);
        expect(initialized, 1);
        expect(shown, 1);
        expect(window.visible.value, isTrue);

        await window.prepare(startHidden: true);
        expect(initialized, 2);
        expect(shown, 1);
        expect(hidden, 1);
        expect(window.visible.value, isFalse);
      },
      tags: const <String>['feature_test__desktop_residency__unit'],
    );

    test(
      'visibility follows this app and the native show and hide events',
      () async {
        var shown = 0;
        var hidden = 0;
        var nativeVisible = true;
        final listeners = <WindowListener>[];
        final window = PluginDesktopWindow(
          showWindow: () async {
            shown += 1;
            nativeVisible = true;
          },
          hideWindow: () async {
            hidden += 1;
            nativeVisible = false;
          },
          windowIsVisible: () async => nativeVisible,
          preventClose: ({required prevent}) async {},
          addWindowListener: listeners.add,
          removeWindowListener: listeners.remove,
        );

        await window.interceptClose(() {});
        expect(window.visible.value, isTrue);

        await window.hide();
        expect(window.visible.value, isFalse);
        // A repeated call must not report a change that did not happen.
        var changes = 0;
        window.visible.addListener(() => changes += 1);
        await window.hide();
        expect((hidden, changes), (2, 0));

        await window.show();
        expect((shown, window.visible.value, changes), (1, true, 1));

        // The window can also be hidden and shown without the app asking.
        listeners.single.onWindowEvent('hide');
        expect(window.visible.value, isFalse);
        listeners.single.onWindowEvent('show');
        expect(window.visible.value, isTrue);
        // Every other native event leaves visibility alone.
        listeners.single.onWindowEvent('resize');
        expect((window.visible.value, changes), (true, 3));
      },
      tags: const <String>['feature_test__desktop_residency__unit'],
    );

    test(
      'intercepting close routes the native gesture instead of quitting',
      () async {
        final prevented = <bool>[];
        final listeners = <WindowListener>[];
        var closes = 0;
        final window = PluginDesktopWindow(
          preventClose: ({required prevent}) async => prevented.add(prevent),
          addWindowListener: listeners.add,
          removeWindowListener: listeners.remove,
        );

        await window.interceptClose(() => closes += 1);
        expect(prevented, <bool>[true]);
        expect(listeners, hasLength(1));

        // The relay is what turns a native close into an app callback.
        listeners.single.onWindowClose();
        expect(closes, 1);

        // Intercepting twice must not leave a stale listener behind.
        await window.interceptClose(() => closes += 1);
        expect(listeners, hasLength(1));

        await window.releaseClose();
        expect(listeners, isEmpty);
        expect(prevented, <bool>[true, false, true, false]);

        // Releasing again is inert, so the quit path can be defensive.
        await window.releaseClose();
        expect(prevented, hasLength(4));
      },
      tags: const <String>['feature_test__desktop_residency__unit'],
    );

    test('show, hide, and visibility reach the plugin', () async {
      var shown = 0;
      var hidden = 0;
      var nativeVisible = false;
      final window = PluginDesktopWindow(
        showWindow: () async {
          shown += 1;
          nativeVisible = true;
        },
        hideWindow: () async {
          hidden += 1;
          nativeVisible = false;
        },
        windowIsVisible: () async => nativeVisible,
      );

      await window.show();
      expect(await window.isVisible(), isTrue);
      await window.hide();
      expect(await window.isVisible(), isFalse);
      expect(<int>[shown, hidden], <int>[1, 1]);
    }, tags: const <String>['feature_test__desktop_residency__unit']);

    for (final platform in <TargetPlatform>[
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.windows,
    ]) {
      test(
        '$platform hide retries while the native window remains visible',
        () async {
          var hidden = 0;
          var nativeVisible = true;
          final waits = <Duration>[];
          final window = PluginDesktopWindow(
            platform: platform,
            hideWindow: () async {
              hidden += 1;
              if (hidden == 3) nativeVisible = false;
            },
            windowIsVisible: () async => nativeVisible,
            waitForWindowState: (duration) async => waits.add(duration),
          );

          await window.hide();

          expect(hidden, 3);
          expect(waits, hasLength(2));
          expect(window.visible.value, isFalse);
        },
        tags: const <String>['feature_test__desktop_residency__unit'],
      );
    }

    test('a hidden prepare confirms the native window really hid', () async {
      var hidden = 0;
      var nativeVisible = true;
      final window = PluginDesktopWindow(
        platform: TargetPlatform.macOS,
        initialize: () async {},
        readyToShow: (onReady) => onReady(),
        hideWindow: () async {
          hidden += 1;
          if (hidden == 2) nativeVisible = false;
        },
        windowIsVisible: () async => nativeVisible,
        waitForWindowState: (_) async {},
      );

      await window.prepare(startHidden: true);

      expect(hidden, 2);
      expect(window.visible.value, isFalse);
      expect(await window.isVisible(), isFalse);
    }, tags: const <String>['feature_test__desktop_residency__unit']);
  });

  group('process terminator', () {
    test('terminating ends the process successfully', () async {
      final codes = <int>[];
      // The real `exit` never returns, so the seam models that too: reaching
      // the line after `terminate` would mean the app kept running.
      final terminator = ProcessAppTerminator(
        exitProcess: (code) {
          codes.add(code);
          throw const _Exited();
        },
      );

      await expectLater(terminator.terminate(), throwsA(isA<_Exited>()));
      expect(codes, <int>[0]);
    }, tags: const <String>['feature_test__desktop_residency__unit']);
  });

  group('tray adapter', () {
    ({
      PluginTrayIcon tray,
      List<String> icons,
      List<String> tooltips,
      List<Menu> menus,
      List<TrayListener> listeners,
      List<bool> templates,
      List<bool> popUps,
    })
    build({TargetPlatform platform = TargetPlatform.linux}) {
      final icons = <String>[];
      final templates = <bool>[];
      final tooltips = <String>[];
      final menus = <Menu>[];
      final listeners = <TrayListener>[];
      final popUps = <bool>[];
      return (
        tray: PluginTrayIcon(
          platform: platform,
          setIcon: (path, {required isTemplate}) async {
            icons.add(path);
            templates.add(isTemplate);
          },
          setToolTip: (value) async => tooltips.add(value),
          setContextMenu: (value) async => menus.add(value),
          popUpMenu: ({required bringAppToFront}) async =>
              popUps.add(bringAppToFront),
          addTrayListener: listeners.add,
          removeTrayListener: listeners.remove,
          destroyTray: () async {},
        ),
        icons: icons,
        tooltips: tooltips,
        menus: menus,
        listeners: listeners,
        templates: templates,
        popUps: popUps,
      );
    }

    const model = TrayMenuModel(
      tooltip: 'Tinest',
      entries: <TrayMenuEntry>[
        TrayMenuEntry(
          key: trayItemToggleWindow,
          label: 'Show',
          action: TrayMenuAction.toggleWindow,
        ),
        TrayMenuEntry.separator(),
        TrayMenuEntry(key: trayItemDaemonStatus, label: 'Idle', enabled: false),
      ],
    );

    test(
      'installing sets the platform icon and routes clicks by row key',
      () async {
        final harness = build();
        final selected = <String>[];

        await harness.tray.install(
          menu: model,
          onSelected: selected.add,
          onActivated: () {},
        );

        expect(harness.icons, <String>['assets/tray/tray_icon.png']);
        expect(harness.templates, <bool>[false]);
        expect(harness.menus, hasLength(1));
        expect(harness.listeners, hasLength(1));

        harness.listeners.single.onTrayMenuItemClick(
          MenuItem(key: trayItemToggleWindow, label: 'Show'),
        );
        expect(selected, <String>[trayItemToggleWindow]);

        // A native row without a key cannot be mapped to an action.
        harness.listeners.single.onTrayMenuItemClick(
          MenuItem(label: 'Unkeyed'),
        );
        expect(selected, <String>[trayItemToggleWindow]);
      },
      tags: const <String>['feature_test__desktop_residency__unit'],
    );

    test(
      'the tooltip is skipped on Linux, where the plugin has no such call',
      () async {
        final linux = build();
        await linux.tray.update(model);
        expect(linux.tooltips, isEmpty);
        expect(linux.menus, hasLength(1));

        final windows = build(platform: TargetPlatform.windows);
        await windows.tray.update(model);
        expect(windows.tooltips, <String>['Tinest']);

        final macos = build(platform: TargetPlatform.macOS);
        await macos.tray.install(
          menu: model,
          onSelected: (_) {},
          onActivated: () {},
        );
        expect(macos.icons, <String>['assets/tray/tray_icon_template.png']);
        expect(macos.templates, <bool>[true]);
        expect(
          trayIconAssetPath(platform: TargetPlatform.windows),
          'assets/tray/tray_icon.ico',
        );
      },
      tags: const <String>['feature_test__desktop_residency__unit'],
    );

    test(
      'Windows pops the menu on right click and activates on left click',
      () async {
        final harness = build(platform: TargetPlatform.windows);
        var activations = 0;
        await harness.tray.install(
          menu: model,
          onSelected: (_) {},
          onActivated: () => activations += 1,
        );

        // The Windows plugin only reports the click; nothing shows the menu
        // unless the app asks for it.
        harness.listeners.single.onTrayIconRightMouseDown();
        // Foregrounding the window is what lets a click elsewhere dismiss the
        // popup, which `TrackPopupMenu` cannot do on a background window.
        expect(harness.popUps, <bool>[true]);
        expect(activations, 0);

        // Windows reports a double click as two of these, and showing the
        // window is idempotent, so both clicks land on the same result.
        harness.listeners.single.onTrayIconMouseDown();
        harness.listeners.single.onTrayIconMouseDown();
        expect(activations, 2);
        expect(harness.popUps, <bool>[true]);
      },
      tags: const <String>['feature_test__desktop_residency__unit'],
    );

    test(
      'macOS opens the menu from either button, as the menu bar does',
      () async {
        final harness = build(platform: TargetPlatform.macOS);
        var activations = 0;
        await harness.tray.install(
          menu: model,
          onSelected: (_) {},
          onActivated: () => activations += 1,
        );

        harness.listeners.single.onTrayIconMouseDown();
        harness.listeners.single.onTrayIconRightMouseDown();
        expect(harness.popUps, <bool>[false, false]);
        expect(activations, 0);
      },
      tags: const <String>['feature_test__desktop_residency__unit'],
    );

    test(
      'Linux leaves icon clicks to the app indicator, which owns the menu',
      () async {
        final harness = build();
        var activations = 0;
        await harness.tray.install(
          menu: model,
          onSelected: (_) {},
          onActivated: () => activations += 1,
        );

        harness.listeners.single.onTrayIconMouseDown();
        harness.listeners.single.onTrayIconRightMouseDown();
        expect(harness.popUps, isEmpty);
        expect(activations, 0);
      },
      tags: const <String>['feature_test__desktop_residency__unit'],
    );

    test(
      'destroying removes the listener and is inert without an install',
      () async {
        final harness = build();
        await harness.tray.destroy();
        expect(harness.listeners, isEmpty);

        await harness.tray.install(
          menu: model,
          onSelected: (_) {},
          onActivated: () {},
        );
        expect(harness.listeners, hasLength(1));
        await harness.tray.destroy();
        expect(harness.listeners, isEmpty);
      },
      tags: const <String>['feature_test__desktop_residency__unit'],
    );

    test('separators and disabled rows survive the native conversion', () {
      final items = buildNativeTrayMenu(model).items!;
      expect(items, hasLength(3));
      expect(items[0].key, trayItemToggleWindow);
      expect(items[0].disabled, isFalse);
      expect(items[1].type, 'separator');
      expect(items[2].key, trayItemDaemonStatus);
      expect(items[2].disabled, isTrue);
    }, tags: const <String>['feature_test__desktop_residency__unit']);
  });

  group('login item adapter', () {
    test(
      'the minimized flag is recorded as a launch argument, not a toggle',
      () async {
        final recorded = <List<String>>[];
        final paths = <String>[];
        var enables = 0;
        var disables = 0;
        final autostart = LaunchAtStartupRegistration(
          configure: ({required appPath, required args}) {
            paths.add(appPath);
            recorded.add(args);
          },
          enableStartup: () async => enables += 1,
          disableStartup: () async => disables += 1,
          startupIsEnabled: () async => true,
        );

        await autostart.apply(enabled: true, minimized: true);
        expect(recorded.single, <String>[startMinimizedFlag]);
        expect(paths.single, isNotEmpty);
        expect(enables, 1);
        expect(disables, 0);

        // Turning off "start minimized" while still registered must rewrite
        // the arguments, not merely leave the old registration in place.
        await autostart.apply(enabled: true, minimized: false);
        expect(recorded.last, isEmpty);
        expect(enables, 2);

        await autostart.apply(enabled: false, minimized: false);
        expect(disables, 1);
        expect(enables, 2);

        expect(await autostart.isEnabled(), isTrue);
        // A space in the name would corrupt the unquoted Linux Exec= line.
        expect(LaunchAtStartupRegistration.appName, isNot(contains(' ')));
      },
      tags: const <String>['feature_test__settings_startup__unit'],
    );
  });
}

/// Stands in for a process that really did exit.
final class _Exited implements Exception {
  const new();
}
