import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/features/permissions/application/permission_settings_controller.dart';
import 'package:app/src/shared/presentation/permission_picker.dart';
import 'package:app/src/shared/presentation/settings_layout.dart';
import 'package:app/src/shared/presentation/toast_messenger.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/fake_tinest_api.dart';
import '../../support/localization.dart';

void main() {
  test(
    'every permission mode is offered exactly once, asking first',
    () {
      expect(permissionModeOrder.first, PermissionMode.ask);
      expect(
        permissionModeOrder.toSet(),
        PermissionMode.values.toSet(),
        reason: 'A new mode must be given a place in the offered order.',
      );
      expect(permissionModeOrder, hasLength(PermissionMode.values.length));
    },
    tags: const <String>['feature_test__permission_settings__unit'],
  );

  testWidgets(
    'describes every mode and persists full access without confirmation',
    (tester) async {
      final api = FakeTinestApi();
      final router = GoRouter(
        initialLocation: const PermissionSettingsRoute(
          hostId: 'server',
        ).location,
        routes: $appRoutes,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appServicesProvider.overrideWithValue(fakeAppServices(api)),
          ],
          child: MaterialApp.router(
            theme: testLightTheme,
            darkTheme: testDarkTheme,
            locale: testLocale,
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            routerConfig: router,
            builder: (context, child) =>
                TinestToastScope(child: child ?? const SizedBox.shrink()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TRSelect<PermissionMode>>(
              find.byType(TRSelect<PermissionMode>),
            )
            .padding,
        TRFieldPadding.standard,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('permission-settings-change')),
      );
      await tester.pumpAndSettle();

      expect(find.text('읽기 전용'), findsOneWidget);
      expect(find.text('변경 전 확인'), findsWidgets);
      expect(find.text('작업 공간 접근'), findsOneWidget);
      expect(find.text('전체 접근'), findsWidgets);
      expect(
        find.textContaining('신뢰할 수 있는 작업에서만 사용하세요'),
        findsOneWidget,
      );

      // Nothing defers the decision to the agent, and the mode that asks
      // before every change is the one at the top.
      expect(
        find.byKey(const ValueKey<String>('permission-option-inherit')),
        findsNothing,
      );
      final tops = <PermissionMode, double>{
        for (final mode in permissionModeOrder)
          mode: tester
              .getTopLeft(
                find.byKey(
                  ValueKey<String>('permission-option-${mode.name}'),
                ),
              )
              .dy,
      };
      expect(
        tops.keys.toList(growable: false),
        permissionModeOrder,
      );
      for (var index = 1; index < permissionModeOrder.length; index += 1) {
        expect(
          tops[permissionModeOrder[index]],
          greaterThan(tops[permissionModeOrder[index - 1]]!),
          reason: 'Options render in the order they are offered.',
        );
      }

      final fullAccess = find.byKey(
        const ValueKey<String>('permission-option-fullAccess'),
      );
      await tester.ensureVisible(fullAccess);
      await tester.tap(fullAccess);
      await tester.pumpAndSettle();

      expect(api.defaultPermissionMode, PermissionMode.fullAccess);
      // The closed trigger and the retained overlay route can both contain the
      // selected label during the route's final frame.
      expect(find.text('전체 접근'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
    tags: const <String>['feature_test__permission_settings__widget'],
  );

  testWidgets(
    'restores the prior default and shows an error when persistence fails',
    (tester) async {
      final api = FakeTinestApi(
        defaultPermissionSetError: Exception('daemon rejected update'),
      );
      final router = GoRouter(
        initialLocation: const PermissionSettingsRoute(
          hostId: 'server',
        ).location,
        routes: $appRoutes,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appServicesProvider.overrideWithValue(fakeAppServices(api)),
          ],
          child: MaterialApp.router(
            theme: testLightTheme,
            locale: testLocale,
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            routerConfig: router,
            builder: (context, child) =>
                TinestToastScope(child: child ?? const SizedBox.shrink()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('permission-settings-change')),
      );
      await tester.pumpAndSettle();
      final fullAccess = find.byKey(
        const ValueKey<String>('permission-option-fullAccess'),
      );
      await tester.ensureVisible(fullAccess);
      await tester.tap(fullAccess);
      await tester.pumpAndSettle();

      expect(api.defaultPermissionMode, PermissionMode.ask);
      expect(find.text('변경 전 확인'), findsWidgets);
      expect(find.text('기본 권한을 변경하지 못했습니다'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    tags: const <String>['feature_test__permission_settings__widget'],
  );

  testWidgets(
    'permission Select uses a desktop menu and a mobile sheet',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 800);
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: const PermissionSettingsRoute(
          hostId: 'server',
        ).location,
        routes: $appRoutes,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appServicesProvider.overrideWithValue(
              fakeAppServices(FakeTinestApi()),
            ),
          ],
          child: MaterialApp.router(
            theme: testLightTheme,
            locale: testLocale,
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            routerConfig: router,
            builder: (context, child) =>
                TinestToastScope(child: child ?? const SizedBox.shrink()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('permission-settings-change')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TRDrawer), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(390, 760);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('permission-settings-change')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TRDrawer), findsOneWidget);
      expect(find.byType(TRTextField), findsOneWidget);
      final sheetOptions = find.descendant(
        of: find.byType(TRDrawer),
        matching: find.byType(TextButton),
      );
      expect(sheetOptions, findsWidgets);
      for (final element in sheetOptions.evaluate()) {
        expect(
          tester.getSize(find.byWidget(element.widget)).height,
          greaterThanOrEqualTo(48),
        );
      }
      expect(tester.takeException(), isNull);
    },
    tags: const <String>['feature_test__permission_settings__widget'],
  );

  testWidgets(
    'permission Select inherits the comfortable mobile control size',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 760);
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: const PermissionSettingsRoute(
          hostId: 'server',
        ).location,
        routes: $appRoutes,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appServicesProvider.overrideWithValue(
              fakeAppServices(FakeTinestApi()),
            ),
          ],
          child: TRUiDensityScope(
            density: TRUiDensity.comfortable,
            child: MaterialApp.router(
              theme: testLightTheme,
              locale: testLocale,
              localizationsDelegates: testLocalizationsDelegates,
              supportedLocales: testSupportedLocales,
              routerConfig: router,
              builder: (context, child) =>
                  TinestToastScope(child: child ?? const SizedBox.shrink()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final trigger = find.descendant(
        of: find.byKey(
          const ValueKey<String>('permission-settings-change'),
        ),
        matching: find.byType(TextButton),
      );
      expect(trigger, findsOneWidget);
      expect(
        tester.getRect(trigger).height,
        TRControlMetrics.heightOf(TRUiSize.xl),
      );
    },
    tags: const <String>['feature_test__permission_settings__widget'],
  );

  testWidgets(
    'a blocking permission load error uses the shared settings hierarchy',
    (tester) async {
      final router = GoRouter(
        initialLocation: const PermissionSettingsRoute(
          hostId: 'server',
        ).location,
        routes: $appRoutes,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appServicesProvider.overrideWithValue(
              fakeAppServices(FakeTinestApi()),
            ),
            permissionSettingsControllerProvider('server').overrideWith(
              _ErrorPermissionSettingsController.new,
            ),
          ],
          child: MaterialApp.router(
            theme: testLightTheme,
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
      expect(find.textContaining('permissions unavailable'), findsOneWidget);
      expect(find.widgetWithText(TRButton, '다시 시도'), findsOneWidget);
    },
    tags: const <String>[
      'feature_test__permission_settings__widget',
      'feature_test__settings_async_loading__widget',
    ],
  );
}

final class _ErrorPermissionSettingsController
    extends PermissionSettingsController {
  @override
  Future<PermissionSettingsDto> build(String hostId) =>
      Future<PermissionSettingsDto>.error(
        StateError('permissions unavailable'),
      );
}
