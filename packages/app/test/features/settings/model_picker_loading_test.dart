import 'dart:async';

import 'package:app/src/shared/presentation/model_picker.dart';
import 'package:app/src/shared/presentation/tinest_bottom_sheet.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/localization.dart';

void main() {
  testWidgets(
    'model Select replaces its skeleton after the typed loader resolves',
    tags: const <String>['feature_test__settings_async_loading__widget'],
    (tester) async {
      final gate = Completer<List<ModelPickerOption>>();
      await tester.pumpWidget(_host(() => gate.future));

      expect(
        find.byKey(const ValueKey<String>('model-select-loading')),
        findsOneWidget,
      );
      expect(find.byType(TRSelect<ModelPickerOption>), findsNothing);

      gate.complete(const <ModelPickerOption>[_option]);
      await tester.pumpAndSettle();

      final select = tester.widget<TRSelect<ModelPickerOption>>(
        find.byType(TRSelect<ModelPickerOption>),
      );
      expect(select.searchable, isTrue);
      expect(select.presentation, isA<TRSelectLayerPresentation>());
    },
  );

  testWidgets(
    'model Select exposes retry after loading fails',
    tags: const <String>['feature_test__settings_async_loading__widget'],
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _host(() async {
          calls += 1;
          if (calls == 1) throw StateError('offline');
          return const <ModelPickerOption>[_option];
        }),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('model-select-retry')),
      );
      await tester.pumpAndSettle();

      expect(calls, 2);
      expect(find.byType(TRSelect<ModelPickerOption>), findsOneWidget);
    },
  );

  testWidgets('model Select inherits the comfortable mobile control size', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 760);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        () async => const <ModelPickerOption>[_option],
        density: TRUiDensity.comfortable,
      ),
    );
    await tester.pumpAndSettle();

    final trigger = find.descendant(
      of: find.byKey(const ValueKey<String>('model-select')),
      matching: find.byType(TextButton),
    );
    expect(trigger, findsOneWidget);
    expect(
      tester.getRect(trigger).height,
      TRControlMetrics.heightOf(TRUiSize.xl),
    );
  });

  for (final (width, expectsSheet) in <(double, bool)>[
    (599, true),
    (600, false),
  ]) {
    testWidgets(
      'model Select uses the adaptive searchable surface at width $width',
      tags: const <String>['feature_test__settings_async_loading__widget'],
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 760);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _host(() async => const <ModelPickerOption>[_option]),
        );
        await tester.pumpAndSettle();

        final select = tester.widget<TRSelect<ModelPickerOption>>(
          find.byType(TRSelect<ModelPickerOption>),
        );
        expect(
          select.presentation,
          expectsSheet
              ? isA<TRSelectSheetPresentation>()
              : isA<TRSelectLayerPresentation>(),
        );
        if (expectsSheet) {
          final sheet = select.presentation as TRSelectSheetPresentation;
          expect(sheet.maxExtent, tinestBottomSheetMaxExtent);
          expect(sheet.snapPoints, isEmpty);
          expect(sheet.showDragHandle, isTrue);
        } else {
          final layer = select.presentation as TRSelectLayerPresentation;
          expect(
            layer.width,
            const TRLayerWidth.fixed(TRMeasurements.overlayWidthSm),
          );
          // The popup width is the policy's, not the trigger's: a narrow and a
          // wide anchor resolve to the same fixed bounds. Height is the design
          // system's, and stating the width must not quietly drop it: without
          // the cap the option list grows to the whole viewport.
          for (final anchor in <double>[64, 512]) {
            final resolved = layer.layerSize.constraintsFor(
              anchorSize: Size(anchor, TRControlMetrics.heightOf(TRUiSize.sm)),
              viewportSize: Size(width, 760),
            );
            expect(resolved.minWidth, TRMeasurements.overlayWidthSm);
            expect(resolved.maxWidth, TRMeasurements.overlayWidthSm);
            expect(resolved.maxHeight, TRMeasurements.measureXl);
          }
          expect(layer.placement, TRLayerPlacement.bottomStart);
          expect(layer.useRootOverlay, isTrue);
        }
        await tester.tap(find.byType(TRSelect<ModelPickerOption>));
        await tester.pumpAndSettle();

        expect(
          find.byType(TRDrawer),
          expectsSheet ? findsOneWidget : findsNothing,
        );
        expect(find.text('Test provider · provider/gpt-test'), findsOneWidget);
        await tester.enterText(find.byType(TRTextField), 'provider/gpt');
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('model-option-provider-gpt-test')),
          findsOneWidget,
        );
      },
    );
  }

  for (final (initialWidth, resizedWidth, expectsSheet)
      in <(double, double, bool)>[(599, 600, true), (600, 599, false)]) {
    testWidgets(
      'model Select keeps its open presentation when resizing from '
      '$initialWidth to $resizedWidth',
      tags: const <String>['feature_test__settings_async_loading__widget'],
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(initialWidth, 760);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _host(() async => const <ModelPickerOption>[_option]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(TRSelect<ModelPickerOption>));
        await tester.pumpAndSettle();
        expect(
          find.byType(TRDrawer),
          expectsSheet ? findsOneWidget : findsNothing,
        );

        tester.view.physicalSize = Size(resizedWidth, 760);
        await tester.pumpAndSettle();

        expect(
          find.byType(TRDrawer),
          expectsSheet ? findsOneWidget : findsNothing,
          reason: 'an open Select snapshots its presentation until close',
        );
        expect(find.text('Test provider · provider/gpt-test'), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(TRDrawer), findsNothing);

        final resizedSelect = tester.widget<TRSelect<ModelPickerOption>>(
          find.byType(TRSelect<ModelPickerOption>),
        );
        expect(
          resizedSelect.presentation,
          expectsSheet
              ? isA<TRSelectLayerPresentation>()
              : isA<TRSelectSheetPresentation>(),
        );
        await tester.tap(find.byType(TRSelect<ModelPickerOption>));
        await tester.pumpAndSettle();
        expect(
          find.byType(TRDrawer),
          expectsSheet ? findsNothing : findsOneWidget,
          reason: 'the next open resolves the resized viewport',
        );
      },
    );
  }
}

const _option = ModelPickerOption(
  providerName: 'Test provider',
  model: ProviderModelDto(
    connectionId: 'provider',
    id: 'provider/gpt-test',
    providerModelId: 'gpt-test',
    label: 'GPT Test',
    source: ProviderModelSource.bundled,
    capabilities: ModelCapabilitiesDto(),
  ),
);

Widget _host(ModelPickerOptionsLoader loader, {TRUiDensity? density}) =>
    MaterialApp(
      locale: testLocale,
      localizationsDelegates: testLocalizationsDelegates,
      supportedLocales: testSupportedLocales,
      theme: testLightTheme,
      builder: (context, child) => density == null
          ? child ?? const SizedBox.shrink()
          : TRUiDensityScope(
              density: density,
              child: child ?? const SizedBox.shrink(),
            ),
      home: Scaffold(
        body: Center(
          child: AsyncModelSelect(
            loadOptions: loader,
            currentSelection: const ModelSelectionDto(
              modelId: 'provider/gpt-test',
            ),
            onValueChange: (_) {},
          ),
        ),
      ),
    );
