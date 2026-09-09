import 'package:app/main.dart' as app_entry;
import 'package:app/main_desktop.dart' as desktop_entry;
import 'package:app/main_mobile.dart' as mobile_entry;
import 'package:app/main_web.dart' as web_entry;
import 'package:app/src/app/app_identity.dart';
import 'package:app/src/app/tinest_app.dart';
import 'package:app/src/features/conversation/infrastructure/attachment_export_web.dart';
import 'package:app/src/features/conversation/infrastructure/attachment_web.dart';
import 'package:app/src/features/desktop/application/desktop_startup.dart';
import 'package:app/src/features/desktop/domain/tray_menu_model.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/hosts/domain/host_ports.dart';
import 'package:dropwell/dropwell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';

import '../support/fake_desktop_ports.dart';
import '../support/fake_tinest_api.dart';
import '../support/localization.dart';

void main() {
  testWidgets('the default entrypoint starts the mobile bootstrap', (
    tester,
  ) async {
    await app_entry.main();
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('desktop and mobile runners accept test services', (
    tester,
  ) async {
    final desktopApi = FakeTinestApi(
      workspaces: <WorkspaceDto>[
        WorkspaceDto(
          id: 'workspace',
          name: 'Tinest',
          rootPath: '/repos/tinest',
          kind: WorkspaceKind.git,
          createdAt: DateTime.utc(2026, 8, 3),
        ),
      ],
    );
    final window = FakeDesktopWindow();
    final tray = FakeTrayIcon();
    await desktop_entry.runDesktopApp(
      services: fakeAppServices(desktopApi),
      window: window,
      tray: tray,
      autostart: FakeAutostartRegistration(),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
      AppIdentity.displayName,
    );
    // The injected daemon names the workspace row it serves.
    expect(find.text('Test daemon · /repos/tinest'), findsOneWidget);
    // The desktop runner is resident: it owns a tray and swallows the close.
    expect(window.preparedHidden, isFalse);
    expect(window.preventingClose, isTrue);
    expect(tray.installs, 1);

    final mobileApi = FakeTinestApi();
    await mobile_entry.runMobileApp(services: fakeAppServices(mobileApi));
    // The gate paints its splash first, so the app arrives a frame after the
    // bootstrap future resolves rather than in the first pump.
    await tester.pumpAndSettle();
    expect(find.byType(TinestApp), findsOneWidget);
  });

  testWidgets('the web runner starts remote-only', (tester) async {
    await web_entry.runWebApp(services: fakeAppServices(FakeTinestApi()));
    await tester.pumpAndSettle();

    expect(find.byType(TinestApp), findsOneWidget);
  });

  test('the web attachment adapters replace their native counterparts', () {
    // A browser has no filesystem, so both ports need a web implementation or
    // the composer silently loses file support.
    expect(createAttachmentExport(), isA<WebAttachmentExport>());
    // Drop support is dropwell's answer, not this adapter's: repeating the
    // claim here is how the two would drift apart. What the adapter owes is
    // to report whatever the running platform says.
    expect(
      const WebAttachmentInput().supportsDrop,
      DropwellPlatform.instance.supportsDrop,
    );
  });

  testWidgets('the login-item argument starts the desktop runner hidden', (
    tester,
  ) async {
    final store = MemoryAppStore(
      settings: const AppSettings(embeddedDaemonEnabled: false),
    );
    final window = FakeDesktopWindow();
    final tray = FakeTrayIcon();
    await desktop_entry.runDesktopApp(
      services: fakeAppServices(FakeTinestApi(), store: store),
      arguments: const <String>[startMinimizedFlag],
      window: window,
      tray: tray,
      autostart: FakeAutostartRegistration(),
    );
    await tester.pumpAndSettle();

    expect(window.preparedHidden, isTrue);
    expect(window.visible.value, isFalse);
    expect(window.shows, 0);
    // Preparing the window is what tells the tray which label to start with.
    expect(
      tray.menu.entries
          .firstWhere((entry) => entry.key == trayItemToggleWindow)
          .label,
      testL10n.trayShowWindow,
    );
  }, tags: const <String>['feature_test__settings_startup__widget']);
}
