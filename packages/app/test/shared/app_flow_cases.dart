part of '../app/app_flows_test.dart';

void _registerSharedAppFlows() {
  testWidgets('model selection is owned by the design-system Select', (
    tester,
  ) async {
    const hostKey = ValueKey('model-picker-host');
    await tester.pumpWidget(
      MaterialApp(
        locale: testLocale,
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        theme: testLightTheme,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              key: hostKey,
              width: 560,
              height: 600,
              child: AsyncModelSelect(
                loadOptions: () async => const <ModelPickerOption>[],
                currentSelection: const ModelSelectionDto(
                  modelId: 'missing/model',
                ),
                onValueChange: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final select = tester.widget<TRSelect<ModelPickerOption>>(
      find.byType(TRSelect<ModelPickerOption>),
    );
    expect(select.searchable, isTrue);
    expect(select.presentation, isA<TRSelectLayerPresentation>());
    expect(find.byType(TRDialog), findsNothing);
  }, tags: const <String>['feature_test__session_lifecycle__widget']);

  testWidgets('mobile model Select gives touch scrolling only to its options', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(390, 780));
    final options = <ModelPickerOption>[
      for (var index = 0; index < 30; index += 1)
        ModelPickerOption(
          providerName: 'Test provider',
          model: ProviderModelDto(
            connectionId: 'provider',
            id: 'provider/model-$index',
            providerModelId: 'model-$index',
            label: 'Model $index',
            source: ProviderModelSource.bundled,
            capabilities: const ModelCapabilitiesDto(),
          ),
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        locale: testLocale,
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        theme: testLightTheme,
        home: Scaffold(
          body: AsyncModelSelect(
            loadOptions: () async => options,
            currentSelection: null,
            onValueChange: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('model-select')));
    await tester.pumpAndSettle();

    final drawer = find.byType(TRDrawer);
    final search = find.descendant(
      of: drawer,
      matching: find.byType(TRTextField),
    );
    final optionsScroll = find.descendant(
      of: drawer,
      matching: find.byType(SingleChildScrollView),
    );
    expect(optionsScroll, findsOneWidget);
    final position = tester
        .state<ScrollableState>(
          find.descendant(of: optionsScroll, matching: find.byType(Scrollable)),
        )
        .position;
    final drawerRect = tester.getRect(drawer);
    final searchRect = tester.getRect(search);

    final searchDrag = await tester.startGesture(tester.getCenter(search));
    await searchDrag.moveBy(const Offset(0, -100));
    await tester.pump();
    await searchDrag.moveBy(const Offset(0, -100));
    await tester.pump();

    expect(position.pixels, 0);
    expect(tester.getRect(drawer), drawerRect);
    expect(tester.getRect(search), searchRect);
    await searchDrag.up();
    await tester.pumpAndSettle();
    expect(position.pixels, 0);
    expect(tester.getRect(drawer), drawerRect);
    expect(tester.getRect(search), searchRect);

    final optionsDrag = await tester.startGesture(
      tester.getCenter(optionsScroll),
    );
    await optionsDrag.moveBy(const Offset(0, -100));
    await tester.pump();
    await optionsDrag.moveBy(const Offset(0, -100));
    await tester.pump();

    expect(position.pixels, greaterThan(0));
    expect(tester.getRect(drawer), drawerRect);
    expect(tester.getRect(search), searchRect);
    await optionsDrag.up();
    await tester.pumpAndSettle();

    expect(position.pixels, greaterThan(0));
    expect(tester.getRect(drawer), drawerRect);
    expect(tester.getRect(search), searchRect);
  }, tags: const <String>['feature_test__session_lifecycle__widget']);
}
