import 'package:app/src/app/tinest_app.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/hosts/domain/host_ports.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_tinest_api.dart';

void main() {
  testWidgets(
    'desktop dark English shell remains keyboard reachable while offline',
    (tester) async {
      final store = await _pumpOfflineShell(
        tester,
        size: const Size(1200, 900),
        localeTag: 'en',
        themeMode: AppThemeMode.dark,
      );

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
      expect(app.locale, const Locale('en'));
      expect(store.settings.embeddedDaemonEnabled, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);
    },
    tags: const <String>[
      'ui_state__global_environment__offline_shell__widget',
      // Exact executable tag required by the typed UI manifest.
      // ignore: lines_longer_than_80_chars
      'ui_variant__global_environment__desktop_dark_english_keyboard_offline__widget',
    ],
  );

  testWidgets(
    'mobile light Japanese shell remains touch reachable while offline',
    (tester) async {
      final store = await _pumpOfflineShell(
        tester,
        size: const Size(390, 760),
        localeTag: 'ja',
        themeMode: AppThemeMode.light,
      );

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.light);
      expect(app.locale, const Locale('ja'));
      expect(store.settings.embeddedDaemonEnabled, isFalse);
      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-settings-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('設定'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
    tags: const <String>[
      // Exact executable tag required by the typed UI manifest.
      // ignore: lines_longer_than_80_chars
      'ui_variant__global_environment__mobile_light_japanese_touch_offline__widget',
    ],
  );

  testWidgets(
    'desktop light Korean large-text shell remains pointer reachable offline',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = await _pumpOfflineShell(
        tester,
        size: const Size(1200, 900),
        localeTag: 'ko',
        themeMode: AppThemeMode.light,
      );

      final settings = find.byKey(
        const ValueKey<String>('workspace-settings-button'),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: tester.getCenter(settings));
      await tester.pump();
      expect(store.settings.embeddedDaemonEnabled, isFalse);
      expect(tester.takeException(), isNull);
    },
    tags: const <String>[
      // Exact executable tag required by the typed UI manifest.
      // ignore: lines_longer_than_80_chars
      'ui_variant__global_environment__desktop_light_korean_large_text_pointer_offline__widget',
    ],
  );
}

Future<MemoryAppStore> _pumpOfflineShell(
  WidgetTester tester, {
  required Size size,
  required String localeTag,
  required AppThemeMode themeMode,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  final store = MemoryAppStore(
    settings: AppSettings(
      embeddedDaemonEnabled: false,
      localeTag: localeTag,
      themeMode: themeMode,
    ),
  );
  await tester.pumpWidget(
    TinestApp(services: fakeAppServices(FakeTinestApi(), store: store)),
  );
  await tester.pumpAndSettle();
  return store;
}
