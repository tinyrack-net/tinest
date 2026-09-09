import 'package:app/testing/features/conversation/infrastructure/attachment_io.dart';
import 'package:app/testing/features/desktop/domain/tray_menu_model.dart';
import 'package:app/testing/features/desktop/infrastructure/desktop_shell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/pump_until.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the real runner registers a tray icon and hides instead of quitting',
    (tester) async {
      final window = PluginDesktopWindow();
      final tray = PluginTrayIcon();
      addTearDown(tray.destroy);
      addTearDown(window.releaseClose);

      await window.prepare(startHidden: false);
      await window.show();
      await _waitForWindowVisibility(window, visible: true);
      // Windows and Linux own their frame; macOS keeps the native title bar.
      expect(
        window.chrome,
        defaultTargetPlatform == TargetPlatform.macOS
            ? DesktopWindowChrome.native
            : DesktopWindowChrome.custom,
      );
      expect(await window.isVisible(), isTrue);

      var closes = 0;
      await window.interceptClose(() => closes += 1);
      const menu = TrayMenuModel(
        tooltip: 'Tinest',
        entries: <TrayMenuEntry>[
          TrayMenuEntry(
            key: trayItemToggleWindow,
            label: 'Show window',
            action: TrayMenuAction.toggleWindow,
          ),
          TrayMenuEntry.separator(),
          TrayMenuEntry(key: trayItemQuit, label: 'Quit'),
        ],
      );
      await tray.install(menu: menu, onSelected: (_) {}, onActivated: () {});
      await tray.update(menu);
      expect(const NativeAttachmentInput(), isA<AttachmentInputPort>());
      expect(const NativeAttachmentExport(), isA<AttachmentExportPort>());

      await window.hide();
      await _waitForWindowVisibility(window, visible: false);
      await window.show();
      await _waitForWindowVisibility(window, visible: true);
      expect(closes, 0);

      // Exercise maximize transitions after the hide/restore contract. Linux
      // window managers can still be completing an unmaximize animation after
      // the plugin future resolves; issuing hide during that transition makes
      // this independent residency assertion depend on compositor timing.
      await window.toggleMaximized();
      expect(window.maximized.value, isTrue);
      await window.toggleMaximized();
      expect(window.maximized.value, isFalse);
    },
    tags: const <String>[
      'feature_test__desktop_residency__platformSmoke',
      'feature_test__desktop_window_chrome__platformSmoke',
      'feature_test__conversation_attachments__platformSmoke',
      'feature_scenario__desktop_residency__close_hide_restore__e2e',
      'feature_scenario__desktop_window_chrome__native_window_controls__e2e',
    ],
  );
}

Future<void> _waitForWindowVisibility(
  DesktopWindow window, {
  required bool visible,
}) => awaitCondition(() async {
  // Both the native window and the app-level notifier must agree: bare
  // Xvfb runs without a window manager, which can drop a map-state
  // request outright, and a stale native event can flip the notifier
  // after the command settled. Show and hide are idempotent and republish
  // the app-level state, so reissue instead of waiting on a lost edge.
  if (await window.isVisible() == visible && window.visible.value == visible) {
    return true;
  }
  await (visible ? window.show() : window.hide());
  return await window.isVisible() == visible && window.visible.value == visible;
}, 'the window to become ${visible ? 'visible' : 'hidden'}');
