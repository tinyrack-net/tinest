import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/shared/presentation/blocked_control.dart';
import 'package:app/src/shared/presentation/model_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/fake_tinest_api.dart';
import '../../support/localization.dart';
import '../../support/router_harness.dart';

void main() {
  testWidgets(
    'daemon model settings offers concrete runnable models only',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(1200, 900);
      addTearDown(tester.view.reset);
      final api = FakeTinestApi();
      final router = await pumpRoutedApp(
        tester,
        api,
        initialLocation: const ModelSettingsRoute(hostId: 'server').location,
      );
      addTearDown(router.dispose);

      final select = find.byType(TRSelect<ModelPickerOption>);
      expect(select, findsOneWidget);
      expect(
        tester.widget<TRSelect<ModelPickerOption>>(select).padding,
        TRFieldPadding.standard,
      );
      expect(find.text('자동'), findsNothing);
      expect(find.text('기본 모델 사용'), findsNothing);

      await tester.tap(select);
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey<String>('model-option-openai-gpt-5.6-sol'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('model-option-inherit')),
        findsNothing,
      );
    },
    tags: const <String>['feature_test__model_settings__widget'],
  );

  testWidgets(
    'unavailable saved model remains visible and can be replaced',
    (tester) async {
      final api = FakeTinestApi(
        defaultModel: const ModelSelectionDto(modelId: 'retired/model'),
      );
      final router = await pumpRoutedApp(
        tester,
        api,
        initialLocation: const ModelSettingsRoute(hostId: 'server').location,
      );
      addTearDown(router.dispose);

      expect(
        find.byKey(const ValueKey<String>('model-settings-unavailable')),
        findsOneWidget,
      );
      expect(find.textContaining('retired/model'), findsWidgets);
      await tester.tap(find.byType(TRSelect<ModelPickerOption>));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<String>('model-option-openai-gpt-5.6-sol'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        api.defaultModel,
        const ModelSelectionDto(modelId: 'openai/gpt-5.6-sol'),
      );
    },
    tags: const <String>['feature_test__model_settings__widget'],
  );

  testWidgets(
    'providerless model settings keeps the locked connection guidance',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 760);
      addTearDown(tester.view.reset);
      final router = await pumpRoutedApp(
        tester,
        FakeTinestApi(connections: const <ProviderConnectionDto>[]),
        initialLocation: const ModelSettingsRoute(hostId: 'server').location,
      );
      addTearDown(router.dispose);

      expect(find.byType(BlockedControl), findsOneWidget);
      await tester.tap(find.byType(BlockedControl));
      await tester.pump();
      expect(find.text(testL10n.composerConnectProviderFirst), findsWidgets);
    },
    tags: const <String>['feature_test__model_settings__widget'],
  );
}
