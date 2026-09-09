import 'dart:async';

import 'package:app/src/shared/presentation/settings_layout.dart';
import 'package:app/src/shared/presentation/tinest_icons.dart';
import 'package:app/src/shared/presentation/tinest_layout_metrics.dart';
import 'package:app/src/shared/presentation/tinest_list_row.dart';
import 'package:app/src/shared/presentation/tinest_page_shell.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/localization.dart';

/// Hosts one composite at a fixed width, so a geometry expectation reads the
/// composite rather than whatever the surrounding page happened to impose.
Widget _host(Widget child, {double width = 1200}) => MaterialApp(
  theme: TinyrackTheme.light(),
  home: Scaffold(
    body: SizedBox(width: width, child: child),
  ),
);

Finder _rowSurface(Finder owner, EdgeInsetsGeometry padding) => find.descendant(
  of: owner,
  matching: find.byWidgetPredicate(
    (widget) => widget is AnimatedContainer && widget.padding == padding,
  ),
);

Finder _switchSurface(Finder owner) => find.descendant(
  of: owner,
  matching: find.byWidgetPredicate(
    (widget) => widget is AnimatedContainer && widget.padding != null,
  ),
);

Color _containerColor(WidgetTester tester, Finder finder) {
  final decoration = tester.widget<AnimatedContainer>(finder).decoration;
  return (decoration! as BoxDecoration).color!;
}

/// Sizes the test viewport, which is what the settings kit reads to choose
/// between the phone shape and the wide-window shape.
///
/// `setSurfaceSize` does not move `MediaQuery`, so a test using it would size
/// its box while the width class stayed at the 800-pixel default and quietly
/// checked both shapes at one width.
void _useViewport(WidgetTester tester, Size size) {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
}

const _phone = Size(390, 844);
const _desktop = Size(1400, 900);
const _footerNote = 'Closing the window keeps it running in the tray.';

EdgeInsetsGeometry? _scaffoldPadding(WidgetTester tester) => tester
    .widget<ListView>(
      find.descendant(
        of: find.byType(SettingsScaffold),
        matching: find.byType(ListView),
      ),
    )
    .padding;

/// One titled group of two switch rows, the shape most settings pages take.
Widget _group({String? footer}) => SettingsScaffold(
  children: <Widget>[
    SettingsSection(
      title: 'Startup',
      footer: footer,
      children: <Widget>[
        SettingsRow(
          title: const TRText.inherit('Start at login'),
          control: TRSwitch(checked: true, onCheckedChange: (_) {}),
        ),
        SettingsRow(
          title: const TRText.inherit('Start minimized'),
          control: TRSwitch(checked: true, onCheckedChange: (_) {}),
        ),
      ],
    ),
  ],
);

void main() {
  testWidgets('SettingsAsyncContent preserves stale data across refresh', (
    tester,
  ) async {
    final loads = <Completer<String>>[];
    final provider = FutureProvider<String>((ref) {
      final load = Completer<String>();
      loads.add(load);
      return load.future;
    });
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: testLocale,
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          theme: testLightTheme,
          home: Consumer(
            builder: (context, ref, _) => SettingsAsyncContent<String>(
              state: ref.watch(provider),
              loading: const SettingsSkeletonLayout.form(
                semanticLabel: '설정 불러오는 중',
              ),
              error: (error, _) => TRText.inherit('$error'),
              data: (value) => Center(
                child: TRButton(
                  onPressed: () => ref.invalidate(provider),
                  child: TRText.inherit(value),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(TRSkeleton), findsWidgets);

    loads.single.complete('Ready');
    await tester.pump();
    await tester.pump();
    expect(find.text('Ready'), findsOneWidget);

    await tester.tap(find.text('Ready'));
    await tester.pump();
    expect(find.text('Ready'), findsOneWidget);
    expect(find.byType(SettingsSkeletonLayout), findsNothing);

    loads.last.completeError(Exception('refresh failed'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Ready'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('settings-refresh-error')),
      findsOneWidget,
    );
  }, tags: const <String>['feature_test__settings_async_loading__widget']);

  group('SettingsSkeletonLayout', () {
    testWidgets('renders an inert labelled form skeleton', (tester) async {
      await tester.pumpWidget(
        _host(
          const SettingsSkeletonLayout.form(semanticLabel: 'Loading settings'),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('settings-skeleton-form')),
        findsOneWidget,
      );
      expect(find.byType(TRSkeleton), findsWidgets);
      expect(find.bySemanticsLabel('Loading settings'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SettingsSkeletonLayout),
          matching: find.byType(Focus),
        ),
        findsNothing,
      );
    }, tags: const <String>['feature_test__settings_async_loading__widget']);

    testWidgets('supplies independent collection and detail placeholders', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const Row(
            children: <Widget>[
              SizedBox(
                width: TinestLayoutMetrics.settingsCollectionWidth,
                child: SettingsSkeletonLayout.collection(
                  semanticLabel: 'Loading collection',
                ),
              ),
              Expanded(
                child: SettingsSkeletonLayout.detail(
                  semanticLabel: 'Loading detail',
                ),
              ),
            ],
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('settings-skeleton-list-pane')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('settings-skeleton-detail-pane')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Loading collection'), findsOneWidget);
      expect(find.bySemanticsLabel('Loading detail'), findsOneWidget);
    }, tags: const <String>['feature_test__settings_async_loading__widget']);
  });

  test(
    'SettingsPaneController auto-selects once until its route identity resets',
    () {
      final controller = SettingsPaneController<String>();
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications += 1);

      expect(controller.hasDetail, isFalse);
      expect(controller.selection, isNull);
      expect(controller.detailStack, isEmpty);
      expect(controller.canAutoSelect, isTrue);

      controller.showInitialDetail('github');
      expect(controller.hasDetail, isTrue);
      expect(controller.selection, 'github');
      expect(controller.detailStack, <Object>['github']);
      expect(controller.canAutoSelect, isFalse);
      expect(notifications, 1);

      controller.showCollection();
      expect(controller.hasDetail, isFalse);
      expect(controller.selection, isNull);
      expect(controller.detailStack, isEmpty);
      expect(controller.canAutoSelect, isFalse);
      expect(notifications, 2);

      controller.showInitialDetail('ignored');
      expect(controller.hasDetail, isFalse);
      expect(notifications, 2);

      controller.reset();
      expect(controller.canAutoSelect, isTrue);
      controller.showInitialDetail('gitlab');
      expect(controller.selection, 'gitlab');
      expect(notifications, 3);
    },
  );

  testWidgets(
    'replacing detail A with B does not treat outgoing A as a Back pop',
    (tester) async {
      final controller = SettingsPaneController<String>();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          // Below the split, where the detail covers the collection and Back
          // therefore returns to it.
          TRAdaptiveLayoutScope(
            widthClass: TRAdaptiveWidthClass.expanded,
            child: SettingsListDetailHost(
              coordinator: controller,
              collection: const TRText.inherit('Collection'),
              detail: const TRText.inherit('Detail'),
            ),
          ),
        ),
      );

      controller.showDetail('A');
      await tester.pumpAndSettle();
      controller.showDetail('B');
      await tester.pumpAndSettle();

      expect(controller.selection, 'B');
      expect(find.text('Detail'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(controller.selection, isNull);
      expect(controller.hasDetail, isFalse);
    },
    tags: const <String>['feature_test__app_navigation__widget'],
  );

  testWidgets('a split detail does not consume Back, since it hides nothing', (
    tester,
  ) async {
    final controller = SettingsPaneController<String>();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        TRAdaptiveLayoutScope(
          widthClass: TRAdaptiveWidthClass.large,
          child: SettingsListDetailHost(
            coordinator: controller,
            collection: const TRText.inherit('Collection'),
            detail: const TRText.inherit('Detail'),
          ),
        ),
      ),
    );

    controller.showDetail('A');
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // Back belongs to whatever encloses Settings: the collection is already
    // on screen next to the detail, so there is nothing here to return to.
    expect(controller.selection, 'A');
    expect(controller.hasDetail, isTrue);
  }, tags: const <String>['feature_test__app_navigation__widget']);

  testWidgets('large list-detail uses the dedicated collection width token', (
    tester,
  ) async {
    final controller = SettingsPaneController<String>();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        TRAdaptiveLayoutScope(
          widthClass: TRAdaptiveWidthClass.large,
          child: SettingsListDetailHost(
            coordinator: controller,
            collection: const SizedBox(
              key: ValueKey<String>('collection-pane-content'),
              height: double.infinity,
            ),
            detail: const SizedBox.expand(),
          ),
        ),
      ),
    );

    expect(
      tester
          .getSize(
            find.byKey(const ValueKey<String>('collection-pane-content')),
          )
          .width,
      TinestLayoutMetrics.settingsCollectionWidth,
    );
  }, tags: const <String>['feature_test__app_navigation__widget']);

  testWidgets(
    'large detail replacement keeps collection fixed and outgoing content '
    'inert',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = SettingsPaneController<String>();
      addTearDown(controller.dispose);
      var activations = 0;
      await tester.pumpWidget(
        _host(
          TRAdaptiveLayoutScope(
            widthClass: TRAdaptiveWidthClass.large,
            child: SettingsListDetailHost(
              coordinator: controller,
              collection: const _CollectionIdentityProbe(
                key: ValueKey<String>('fixed-collection'),
              ),
              detail: ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  final selection = controller.selection;
                  return selection == null
                      ? const SizedBox.expand()
                      : Center(
                          child: Semantics(
                            container: true,
                            button: true,
                            label: 'Detail $selection',
                            child: ExcludeSemantics(
                              child: TRButton(
                                key: ValueKey<String>('detail-$selection'),
                                onPressed: () => activations += 1,
                                child: TRText.inherit('Detail $selection'),
                              ),
                            ),
                          ),
                        );
                },
              ),
            ),
          ),
        ),
      );

      controller.showDetail('A');
      await tester.pumpAndSettle();
      final collection = find.byKey(const ValueKey<String>('fixed-collection'));
      final collectionState = tester.state(collection);
      final collectionRect = tester.getRect(collection);

      controller.showDetail('B');
      await tester.pump();

      expect(tester.state(collection), same(collectionState));
      expect(tester.getRect(collection), collectionRect);
      expect(
        find.byKey(const ValueKey<String>('detail-B'), skipOffstage: false),
        findsNWidgets(2),
      );
      final interactiveDetail = find
          .byKey(const ValueKey<String>('detail-B'))
          .hitTestable();
      expect(interactiveDetail, findsOneWidget);
      expect(find.bySemanticsLabel('Detail B'), findsOneWidget);

      await tester.tap(interactiveDetail);
      await tester.pump();
      expect(activations, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focusContext = FocusManager.instance.primaryFocus?.context;
      expect(focusContext, isNotNull);
      expect(
        find.ancestor(
          of: find.byElementPredicate(
            (element) => identical(element, focusContext),
          ),
          matching: interactiveDetail,
        ),
        findsOneWidget,
      );

      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('detail-B'), skipOffstage: false),
        findsOneWidget,
      );
      semantics.dispose();
    },
    tags: const <String>['feature_test__app_navigation__widget'],
  );

  testWidgets(
    'collection rows share the sidebar inset, navigation surface, and rhythm',
    (tester) async {
      await tester.pumpWidget(
        _host(
          const Column(
            children: <Widget>[
              TRPaneHeader(title: TRText.inherit('Projects')),
              Expanded(
                child: SettingsCollectionList(
                  children: <Widget>[
                    SettingsRow.collection(
                      title: TRText.inherit('First'),
                      selected: true,
                    ),
                    SettingsRow.collection(
                      title: TRText.inherit('Second'),
                      selected: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          width: TinestLayoutMetrics.settingsCollectionWidth,
        ),
      );

      final list = tester.widget<ListView>(
        find.descendant(
          of: find.byType(SettingsCollectionList),
          matching: find.byType(ListView),
        ),
      );
      expect(
        list.padding,
        const EdgeInsets.symmetric(
          horizontal: TRSpacing.medium,
          vertical: TRSpacing.medium,
        ),
      );

      final first = tester.getRect(find.widgetWithText(TinestListRow, 'First'));
      final second = tester.getRect(
        find.widgetWithText(TinestListRow, 'Second'),
      );
      expect(first.left, TRSpacing.medium);
      expect(
        first.right,
        TinestLayoutMetrics.settingsCollectionWidth - TRSpacing.medium,
      );
      expect(
        tester
            .widget<TinestListRow>(find.widgetWithText(TinestListRow, 'First'))
            .contentPadding,
        const EdgeInsets.symmetric(
          horizontal: TRSpacing.medium,
          vertical: TRSpacing.medium,
        ),
      );
      expect(second.top - first.bottom, TRSpacing.extraSmall);
      final separator = tester.getRect(find.byType(TRSeparator));
      expect(first.top - separator.bottom, TRSpacing.medium);
      final firstSurface = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.widgetWithText(TinestListRow, 'First'),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(
        (firstSurface.decoration! as BoxDecoration).color,
        tester.element(find.text('First')).tinyrackTheme.surfaceHover,
      );
      expect(
        tester.getRect(find.text('First')).left,
        moreOrLessEquals(
          tester.getRect(find.text('Projects')).left,
          epsilon: 0.5,
        ),
      );
    },
  );

  testWidgets('compact collections keep the same row inset and alignment', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Column(
          children: <Widget>[
            TRPaneHeader(title: TRText.inherit('Projects')),
            Expanded(
              child: SettingsCollectionList(
                children: <Widget>[
                  SettingsRow.collection(
                    title: TRText.inherit('Tinest'),
                    selected: true,
                  ),
                ],
              ),
            ),
          ],
        ),
        width: 390,
      ),
    );

    final row = tester.getRect(find.widgetWithText(TinestListRow, 'Tinest'));
    expect(row.left, TRSpacing.medium);
    expect(row.right, 390 - TRSpacing.medium);
    expect(
      tester.getRect(find.text('Tinest')).left,
      moreOrLessEquals(
        tester.getRect(find.text('Projects')).left,
        epsilon: 0.5,
      ),
    );
    expect(
      tester.widget<TinestListRow>(find.byType(TinestListRow)).contentPadding,
      const EdgeInsets.symmetric(
        horizontal: TRSpacing.medium,
        vertical: TRSpacing.medium,
      ),
    );
  });

  testWidgets('standard rows retain the content selected surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const SettingsRow(title: TRText.inherit('Standard'), selected: true),
      ),
    );

    final surface = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(TinestListRow),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(
      (surface.decoration! as BoxDecoration).color,
      tester.element(find.text('Standard')).tinyrackTheme.surfaceSelected,
    );
  });

  testWidgets('collection header matches the tree navigation leading inset', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Column(
          children: <Widget>[
            TRPaneHeader(title: TRText.inherit('Projects')),
            Expanded(
              child: SettingsCollectionList(
                children: <Widget>[
                  SettingsRow.collection(
                    leading: Icon(Icons.folder),
                    title: TRText.inherit('Tinest'),
                    selected: true,
                  ),
                ],
              ),
            ),
          ],
        ),
        width: TinestLayoutMetrics.settingsCollectionWidth,
      ),
    );

    final header = tester.getRect(find.text('Projects'));
    final row = tester.getRect(find.byType(TinestListRow));
    expect(
      header.left,
      moreOrLessEquals(row.left + TRSpacing.medium, epsilon: 0.5),
    );
  });

  testWidgets('list-detail skeleton uses the collection spacing contract', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const SettingsSkeletonLayout.collection(
          semanticLabel: 'Loading settings',
        ),
      ),
    );

    final list = tester.widget<ListView>(
      find.descendant(
        of: find.byType(SettingsCollectionList),
        matching: find.byType(ListView),
      ),
    );
    expect(
      list.padding,
      const EdgeInsets.symmetric(
        horizontal: TRSpacing.medium,
        vertical: TRSpacing.medium,
      ),
    );
    expect(
      find.descendant(
        of: find.byType(SettingsCollectionList),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Padding &&
              widget.padding == SettingsRow.collectionContentPadding,
        ),
      ),
      findsNWidgets(4),
    );
  });

  group('SettingsScaffold', () {
    testWidgets('reserves tokenized bottom space for final pane actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const SettingsScaffold(
            children: <Widget>[
              SettingsSection(title: 'Danger', children: <Widget>[]),
            ],
          ),
        ),
      );

      expect(
        _scaffoldPadding(tester),
        const EdgeInsets.fromLTRB(
          TRSpacing.extraLarge,
          TRSpacing.extraLarge,
          TRSpacing.extraLarge,
          TRSpacing.fourExtraLarge,
        ),
      );
    });

    testWidgets('runs a group to both edges on a phone and insets it on a '
        'wide window', (tester) async {
      _useViewport(tester, _phone);
      await tester.pumpWidget(_host(_group(), width: _phone.width));
      // A phone has no width to spend on a page margin and a card border: the
      // rows supply the only inline inset, and the heading is what separates
      // one group from the next.
      expect(
        _scaffoldPadding(tester),
        const EdgeInsets.fromLTRB(
          0,
          TRSpacing.small,
          0,
          TRSpacing.fourExtraLarge,
        ),
      );
      expect(find.byType(TRCard), findsNothing);

      tester.view.physicalSize = _desktop;
      await tester.pumpWidget(_host(_group(), width: _desktop.width));
      expect(
        _scaffoldPadding(tester),
        const EdgeInsets.fromLTRB(
          TRSpacing.extraLarge,
          TRSpacing.extraLarge,
          TRSpacing.extraLarge,
          TRSpacing.fourExtraLarge,
        ),
      );
      expect(find.byType(TRCard), findsOneWidget);
    });

    testWidgets('lines a compact heading, row, and divider up on one rail', (
      tester,
    ) async {
      _useViewport(tester, _phone);
      await tester.pumpWidget(_host(_group(), width: _phone.width));

      final heading = tester.getRect(find.text('Startup'));
      final title = tester.getRect(find.text('Start at login'));
      final divider = tester.getRect(find.byType(TRSeparator));
      expect(heading.left, moreOrLessEquals(title.left, epsilon: 0.01));
      expect(divider.left, moreOrLessEquals(title.left, epsilon: 0.01));
      // Indented at its start and running to the far edge is what tells a
      // reader the rows belong to one group without drawing a box around them.
      expect(divider.right, moreOrLessEquals(_phone.width, epsilon: 0.01));
    });

    testWidgets('puts a footer under the group as muted supporting copy', (
      tester,
    ) async {
      _useViewport(tester, _phone);
      await tester.pumpWidget(
        _host(_group(footer: _footerNote), width: _phone.width),
      );

      final lastRow = tester.getRect(find.text('Start minimized'));
      final footer = tester.getRect(find.text(_footerNote));
      expect(footer.top, greaterThan(lastRow.bottom));
      expect(
        footer.left,
        moreOrLessEquals(
          tester.getRect(find.text('Startup')).left,
          epsilon: 0.01,
        ),
      );
      final text = tester.widget<TRText>(
        find.byWidgetPredicate(
          (widget) => widget is TRText && widget.data == _footerNote,
        ),
      );
      expect(text.variant, TRTextVariant.bodySm);
      expect(text.color, TRTextColor.muted);
    });

    testWidgets(
      'scrolls the focused final field above the keyboard and restores',
      (tester) async {
        const viewport = Size(390, 760);
        const keyboardHeight = 300.0;
        const fieldKey = ValueKey<String>('last-settings-input');
        final viewInsets = ValueNotifier<EdgeInsets>(EdgeInsets.zero);
        addTearDown(viewInsets.dispose);
        await tester.binding.setSurfaceSize(viewport);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: TinyrackTheme.light(),
            builder: (context, child) => ValueListenableBuilder<EdgeInsets>(
              valueListenable: viewInsets,
              builder: (context, insets, _) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(size: viewport, viewInsets: insets),
                child: child!,
              ),
            ),
            home: TinestPageShell(
              body: SettingsScaffold(
                children: <Widget>[
                  for (var index = 0; index < 2; index += 1)
                    SettingsSection(
                      title: 'Section $index',
                      children: const <Widget>[SizedBox(height: 120)],
                    ),
                  const SettingsSection.form(
                    title: 'Final section',
                    children: <Widget>[
                      TRTextField(key: fieldKey, label: 'Endpoint'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byKey(fieldKey), findsOneWidget);
        await tester.ensureVisible(find.byKey(fieldKey));
        await tester.showKeyboard(find.byKey(fieldKey));
        viewInsets.value = const EdgeInsets.only(bottom: keyboardHeight);
        await tester.pumpAndSettle();

        final keyboardTop = viewport.height - keyboardHeight;
        expect(
          tester.getRect(find.byKey(fieldKey)).bottom,
          lessThanOrEqualTo(keyboardTop),
        );
        expect(tester.takeException(), isNull);

        viewInsets.value = EdgeInsets.zero;
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byType(TRAppShell)), Offset.zero & viewport);
        expect(tester.takeException(), isNull);
      },
      tags: const <String>['feature_test__soft_keyboard_visibility__widget'],
    );

    testWidgets('caps its content and centres it in a wide pane', (
      tester,
    ) async {
      // A real surface, not just a SizedBox: the default test window is
      // narrower than the cap, so the column would fill it and centring would
      // never be exercised.
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _host(
          SettingsScaffold(
            children: <Widget>[
              SettingsSection(
                title: 'Section',
                children: <Widget>[
                  SettingsRow(
                    title: const TRText.inherit('Row'),
                    control: TRButton(
                      onPressed: () {},
                      child: const TRText.inherit('Do'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          width: 1400,
        ),
      );

      // An unbounded column strands a label and its control at opposite edges
      // of a wide window, which is the defect this cap exists to prevent.
      final card = tester.getRect(find.byType(TRCard));
      expect(
        card.width,
        lessThanOrEqualTo(TinestLayoutMetrics.settingsContentMaxWidth),
      );

      // Centred, so a wide window does not strand the column against one
      // edge with a growing void beside it.
      expect(card.width, TinestLayoutMetrics.settingsContentMaxWidth);
      expect(card.left, moreOrLessEquals(1400 - card.right, epsilon: 0.5));
    });

    testWidgets('fills a pane narrower than the cap', (tester) async {
      await tester.pumpWidget(
        _host(
          const SettingsScaffold(
            children: <Widget>[
              SettingsSection(
                title: 'Section',
                children: <Widget>[SettingsRow(title: TRText.inherit('Row'))],
              ),
            ],
          ),
          // A list-detail detail pane is narrower than the cap, so centring
          // has to leave the column filling it rather than shrinking it.
          width: 600,
        ),
      );

      final card = tester.getRect(find.byType(TRCard));
      expect(card.left, TRSpacing.extraLarge);
      expect(card.width, 600 - 2 * TRSpacing.extraLarge);
    });

    testWidgets('separates its sections by one step', (tester) async {
      await tester.pumpWidget(
        _host(
          const SettingsScaffold(
            children: <Widget>[
              SettingsSection(title: 'First', children: <Widget>[]),
              SettingsSection(title: 'Second', children: <Widget>[]),
            ],
          ),
        ),
      );

      final first = tester.getRect(find.text('First'));
      final second = tester.getRect(find.text('Second'));
      expect(second.top - first.top, greaterThan(TRSpacing.twoExtraLarge));
    });
  });

  group('SettingsSection', () {
    testWidgets('omits a heading when the pane already names the task', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const Column(
            children: <Widget>[
              TRPaneHeader(title: TRText.inherit('Connect')),
              Expanded(
                child: SettingsScaffold(
                  children: <Widget>[
                    SettingsSection.form(
                      children: <Widget>[TRTextField(label: 'Link')],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      expect(find.text('Connect'), findsOneWidget);
      expect(
        tester.widget<TRTextField>(find.byType(TRTextField)).label,
        'Link',
      );
    });

    testWidgets('heads every section at the same scale', (tester) async {
      await tester.pumpWidget(
        _host(
          const SettingsScaffold(
            children: <Widget>[
              SettingsSection(title: 'Boxed', children: <Widget>[]),
              SettingsSection.form(title: 'Form', children: <Widget>[]),
            ],
          ),
        ),
      );

      // Both section shapes carry one heading scale. Two sizes for one level
      // is what split the app-scoped pages from the daemon-scoped ones.
      for (final title in <String>['Boxed', 'Form']) {
        expect(
          tester.widget<TRText>(find.widgetWithText(TRText, title)).variant,
          TRTextVariant.headingSm,
        );
      }
    });

    testWidgets('uses the medium gap between a heading and its description', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const SettingsScaffold(
            children: <Widget>[
              SettingsSection(
                title: 'Section',
                description: 'Description',
                children: <Widget>[],
              ),
            ],
          ),
        ),
      );

      final heading = tester.getRect(find.widgetWithText(TRText, 'Section'));
      final description = tester.getRect(
        find.widgetWithText(TRText, 'Description'),
      );
      expect(
        description.top - heading.bottom,
        moreOrLessEquals(TRSpacing.medium, epsilon: 0.5),
      );
    });

    testWidgets('boxes rows and leaves form controls unboxed', (tester) async {
      await tester.pumpWidget(
        _host(
          const SettingsScaffold(
            children: <Widget>[
              SettingsSection(
                title: 'Boxed',
                children: <Widget>[SettingsRow(title: TRText.inherit('Row'))],
              ),
            ],
          ),
        ),
      );
      expect(find.byType(TRCard), findsOneWidget);

      await tester.pumpWidget(
        _host(
          const SettingsScaffold(
            children: <Widget>[
              SettingsSection.form(
                title: 'Form',
                children: <Widget>[TRTextField(label: 'Prompt')],
              ),
            ],
          ),
        ),
      );
      expect(find.byType(TRCard), findsNothing);
    });

    testWidgets('places a section action opposite its heading', (tester) async {
      await tester.pumpWidget(
        _host(
          SettingsScaffold(
            children: <Widget>[
              SettingsSection(
                title: 'Remotes',
                action: TRButton(
                  onPressed: () {},
                  child: const TRText.inherit('Add'),
                ),
                children: const <Widget>[],
              ),
            ],
          ),
        ),
      );

      // The action belongs on the heading line. Left to a Wrap inside a
      // centring Column it drifted to the middle of the pane instead.
      final heading = tester.getRect(find.text('Remotes'));
      final action = tester.getRect(find.byType(TRButton));
      expect(action.left, greaterThan(heading.right));
      expect(action.center.dy, moreOrLessEquals(heading.center.dy, epsilon: 2));
    });
  });

  group('SettingsSection header', () {
    testWidgets('uses the scale-resilient section heading role', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: TinyrackTheme.light(),
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SizedBox(
                width: 390,
                child: SettingsScaffold(
                  children: <Widget>[
                    SettingsSection(
                      title: 'Default permissions',
                      children: <Widget>[],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        tester
            .widget<TRText>(find.widgetWithText(TRText, 'Default permissions'))
            .variant,
        TRTextVariant.headingSm,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('wraps its action rather than overflowing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: TinyrackTheme.light(),
          home: MediaQuery(
            // A heading and its action do not fit on one line on a narrow
            // window at a large text scale, and a Row cannot give.
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SizedBox(
                width: 390,
                child: SettingsScaffold(
                  children: <Widget>[
                    SettingsSection(
                      title: '원격 daemons',
                      action: TRButton(
                        onPressed: () {},
                        child: const TRText.inherit('원격 daemon 추가'),
                      ),
                      children: const <Widget>[],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('SettingsSection banner', () {
    testWidgets('sits between the heading and the content', (tester) async {
      await tester.pumpWidget(
        _host(
          const SettingsScaffold(
            children: <Widget>[
              SettingsSection(
                title: 'Reset',
                banner: TRAlert(title: TRText.inherit('Failed')),
                children: <Widget>[SettingsRow(title: TRText.inherit('Erase'))],
              ),
            ],
          ),
        ),
      );

      // A save result or a connection failure belongs to its section, so it
      // is placed inside the section rather than stacked above it as another
      // top-level block with a full section gap around it.
      final heading = tester.getRect(find.text('Reset'));
      final banner = tester.getRect(find.text('Failed'));
      final row = tester.getRect(find.text('Erase'));
      expect(banner.top, greaterThan(heading.bottom));
      expect(row.top, greaterThan(banner.bottom));
    });
  });

  group('SettingsRow', () {
    testWidgets('increases row padding with comfortable density', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const TRUiDensityScope(
            density: TRUiDensity.comfortable,
            child: SettingsRow(title: TRText.inherit('Comfortable')),
          ),
          width: 390,
        ),
      );

      expect(
        tester.widget<TinestListRow>(find.byType(TinestListRow)).contentPadding,
        const EdgeInsets.symmetric(
          horizontal: TRSpacing.large,
          vertical: TRSpacing.large,
        ),
      );
    });

    testWidgets('puts the description leading and the control trailing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SettingsScaffold(
            children: <Widget>[
              SettingsSection(
                title: 'Section',
                children: <Widget>[
                  SettingsRow(
                    title: const TRText.inherit('Theme'),
                    description: const TRText.inherit('Applies everywhere'),
                    control: TRButton(
                      onPressed: () {},
                      child: const TRText.inherit('Change'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      final title = tester.getRect(find.text('Theme'));
      final description = tester.getRect(find.text('Applies everywhere'));
      final control = tester.getRect(find.byType(TRButton));
      expect(title.left, description.left);
      expect(control.left, greaterThan(title.right));
    });

    testWidgets('keeps a control trailing on both sides of the width that '
        'used to stack it', (tester) async {
      // A control that moved below its copy under one width gave a single
      // setting two shapes, and the window picked which one a reader saw: the
      // same screen read as a list on a desktop and as a stack of forms on a
      // phone. Only an explicitly stacked control moves now.
      final threshold =
          TRBreakpoints.small + SettingsRow.contentPadding.horizontal;
      for (final width in <double>[threshold - 1, threshold]) {
        await tester.pumpWidget(
          _host(
            SettingsRow(
              title: const TRText.inherit('Theme'),
              description: const TRText.inherit('Applies everywhere'),
              wrapsDescription: true,
              control: TRButton(
                onPressed: () {},
                child: const TRText.inherit('System'),
              ),
            ),
            width: width,
          ),
        );

        final title = tester.getRect(find.text('Theme'));
        final control = tester.getRect(find.byType(TRButton));
        final row = tester.widget<TinestListRow>(find.byType(TinestListRow));
        expect(control.left, greaterThan(title.right), reason: 'at $width');
        expect(
          row.trailingLayout,
          TinestListRowTrailingLayout.inline,
          reason: 'at $width',
        );
        // Copy that may wrap is prose, and prose that stops at two lines stops
        // mid-sentence, so it runs on at every width rather than only narrow.
        expect(row.unboundedSubtitle, isTrue, reason: 'at $width');
        expect(tester.takeException(), isNull, reason: 'at $width');
      }
    });

    testWidgets('places an explicitly stacked control below the copy at any '
        'width', (tester) async {
      await tester.pumpWidget(
        _host(
          SettingsRow(
            title: const TRText.inherit('Port'),
            description: const TRText.inherit('Applies everywhere'),
            wrapsDescription: true,
            controlLayout: SettingsControlLayout.stacked,
            control: TRButton(
              onPressed: () {},
              child: const TRText.inherit('System'),
            ),
          ),
          // Wide enough that the old rule would have kept this inline.
          width: TinestLayoutMetrics.settingsContentMaxWidth,
        ),
      );

      final description = tester.getRect(find.text('Applies everywhere'));
      final control = tester.getRect(find.byType(TRButton));
      final row = tester.widget<TinestListRow>(find.byType(TinestListRow));
      expect(control.top, greaterThan(description.bottom));
      expect(row.trailingLayout, TinestListRowTrailingLayout.below);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps compact switch controls trailing on a narrow row', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SettingsRow(
            title: const TRText.inherit('Enabled'),
            description: const TRText.inherit(
              'This explanatory sentence should remain fully readable.',
            ),
            wrapsDescription: true,
            control: TRSwitch(checked: true, onCheckedChange: (_) {}),
          ),
          width: 390,
        ),
      );

      final title = tester.getRect(find.text('Enabled'));
      final control = tester.getRect(find.byType(TRSwitch));
      final row = tester.widget<TinestListRow>(find.byType(TinestListRow));
      expect(control.left, greaterThan(title.right));
      expect(row.trailingLayout, TinestListRowTrailingLayout.inline);
      expect(row.unboundedSubtitle, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('wraps Japanese copy without overflow at large text scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: TinyrackTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SizedBox(
                width: 390,
                child: SettingsRow(
                  title: const TRText.inherit('表示言語'),
                  description: const TRText.inherit(
                    'アプリ全体に適用され、狭い画面でも省略されずに表示されます。',
                  ),
                  wrapsDescription: true,
                  control: TRButton(
                    onPressed: () {},
                    child: const TRText.inherit('システム'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final description = tester.getRect(
        find.text('アプリ全体に適用され、狭い画面でも省略されずに表示されます。'),
      );
      final control = tester.getRect(find.byType(TRButton));
      final row = tester.widget<TinestListRow>(find.byType(TinestListRow));
      // Doubled text keeps the description on its own lines and the control
      // beside them, without either one leaving the row.
      expect(description.bottom, greaterThan(description.top));
      expect(control.left, greaterThan(description.left));
      expect(row.trailingLayout, TinestListRowTrailingLayout.inline);
      expect(row.unboundedSubtitle, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('insets every row in a card identically', (tester) async {
      await tester.pumpWidget(
        _host(
          SettingsScaffold(
            children: <Widget>[
              SettingsSection(
                title: 'Section',
                children: <Widget>[
                  SettingsRow(
                    leading: const Icon(Icons.circle),
                    title: const TRText.inherit('With leading'),
                    control: TRSwitch(checked: true, onCheckedChange: (_) {}),
                  ),
                  SettingsRow(
                    title: const TRText.inherit('Without leading'),
                    control: TRSwitch(checked: false, onCheckedChange: (_) {}),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      // Two rows in one card drew their content at different insets, so the
      // card had no single alignment line down its leading edge.
      final rows = tester
          .widgetList<TinestListRow>(find.byType(TinestListRow))
          .toList();
      expect(rows, hasLength(2));
      expect(rows.first.contentPadding, rows.last.contentPadding);
      expect(
        rows.first.contentPadding,
        const EdgeInsets.symmetric(
          horizontal: TRSpacing.large,
          vertical: TRSpacing.medium,
        ),
      );

      // The trailing controls line up with each other too.
      final switches = find.byType(TRSwitch);
      expect(
        tester.getRect(switches.first).right,
        moreOrLessEquals(tester.getRect(switches.last).right, epsilon: 0.5),
      );
    });

    testWidgets('activates from the row when it carries a tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          SettingsScaffold(
            children: <Widget>[
              SettingsSection(
                title: 'Section',
                children: <Widget>[
                  SettingsRow(
                    title: const TRText.inherit('Toggle me'),
                    onTap: () => taps++,
                    control: TRSwitch(checked: false, onCheckedChange: (_) {}),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Toggle me'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets(
      'keeps the settings surface stable while the row and switch are hovered',
      (tester) async {
        await tester.pumpWidget(
          _host(
            SettingsRow(
              key: const ValueKey<String>('settings-hover-row'),
              title: const TRText.inherit('Enabled'),
              onTap: () {},
              control: TRSwitch(checked: false, onCheckedChange: (_) {}),
            ),
          ),
        );

        final row = find.byKey(const ValueKey<String>('settings-hover-row'));
        final rowSurface = _rowSurface(row, SettingsRow.contentPadding);
        final switchFinder = find.byType(TRSwitch);
        final theme = tester.element(row).tinyrackTheme;
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        addTearDown(mouse.removePointer);
        await mouse.addPointer(location: Offset.zero);

        await mouse.moveTo(tester.getCenter(find.text('Enabled')));
        await tester.pumpAndSettle();
        expect(_containerColor(tester, rowSurface), theme.surface);
        await mouse.down(tester.getCenter(find.text('Enabled')));
        await tester.pump();
        expect(_containerColor(tester, rowSurface), theme.surface);
        await mouse.cancel();

        await mouse.moveTo(tester.getCenter(switchFinder));
        await tester.pumpAndSettle();
        expect(_containerColor(tester, rowSurface), theme.surface);
        expect(
          _containerColor(tester, _switchSurface(switchFinder)),
          theme.surfaceHover,
        );
      },
    );

    testWidgets('keeps hover for non-settings list rows', (tester) async {
      await tester.pumpWidget(
        _host(
          TinestListRow(
            contentPadding: SettingsRow.contentPadding,
            title: const TRText.inherit('Open'),
            onTap: () {},
          ),
        ),
      );

      final row = find.byType(TinestListRow);
      final theme = tester.element(row).tinyrackTheme;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Open')));
      await tester.pumpAndSettle();

      expect(
        _containerColor(tester, _rowSurface(row, SettingsRow.contentPadding)),
        theme.surfaceHover,
      );
    });
  });

  group('SettingsRow flush', () {
    testWidgets('drops only the inline inset', (tester) async {
      await tester.pumpWidget(
        _host(
          Column(
            children: <Widget>[
              const TRTextField(label: 'Base URL'),
              SettingsRow(
                flush: true,
                title: const TRText.inherit('Requires an API key'),
                control: TRSwitch(checked: true, onCheckedChange: (_) {}),
              ),
            ],
          ),
          width: 400,
        ),
      );

      // A dialog pads its own content, so a row inside one has to line up
      // with the fields above it rather than sitting a step further in.
      expect(
        tester.getRect(find.text('Requires an API key')).left,
        moreOrLessEquals(0, epsilon: 0.5),
      );
      // The vertical rhythm is unchanged, so a flush row is not a third inset.
      expect(
        tester.widget<TinestListRow>(find.byType(TinestListRow)).contentPadding,
        SettingsRow.flushPadding,
      );
    });
  });

  group('TRPaneHeader in Settings', () {
    testWidgets('two side-by-side pane headers share one height and baseline', (
      tester,
    ) async {
      // A list-detail route draws a collection header carrying an icon action
      // beside a detail header carrying none. Sized to their own contents they
      // differ by a control height, and the seam between the panes shows it.
      await tester.pumpWidget(
        _host(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: TRPaneHeader(
                  title: const TRText.inherit('Provider'),
                  actions: <Widget>[
                    TRIconButton(
                      label: 'Add provider',
                      onPressed: () {},
                      icon: const Icon(TinestIcons.add),
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: TRPaneHeader(title: TRText.inherit('OpenAI')),
              ),
            ],
          ),
        ),
      );

      final headers = find.byType(TRPaneHeader);
      expect(headers, findsNWidgets(2));
      expect(
        tester.getSize(headers.at(1)).height,
        tester.getSize(headers.first).height,
      );
      expect(
        tester.getRect(find.text('OpenAI')).center.dy,
        moreOrLessEquals(
          tester.getRect(find.text('Provider')).center.dy,
          epsilon: 0.5,
        ),
      );
    });

    testWidgets('aligns a list header with the rows beneath it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const Column(
            children: <Widget>[
              TRPaneHeader(title: TRText.inherit('Projects')),
              SettingsRow(title: TRText.inherit('Tinest')),
            ],
          ),
          width: TinestLayoutMetrics.settingsCollectionWidth,
        ),
      );

      expect(tester.getRect(find.text('Projects')).left, TRSpacing.extraLarge);
    });

    testWidgets('aligns a detail header with the pane body beneath it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const Column(
            children: <Widget>[
              TRPaneHeader(title: TRText.inherit('Tinest')),
              Expanded(
                child: SettingsScaffold(
                  children: <Widget>[
                    SettingsSection.form(
                      title: 'Hooks',
                      children: <Widget>[TRTextField(label: 'Setup')],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      // A detail header inset less than its own body left the pane with two
      // competing leading edges.
      expect(
        tester.getRect(find.text('Tinest')).left,
        moreOrLessEquals(tester.getRect(find.text('Hooks')).left, epsilon: 0.5),
      );
    });

    testWidgets(
      'aligns a compact detail header with its section leading line',
      (tester) async {
        await tester.pumpWidget(
          _host(
            const TRUiDensityScope(
              density: TRUiDensity.comfortable,
              child: Column(
                children: <Widget>[
                  TRPaneHeader(title: TRText.inherit('Tinest')),
                  Expanded(
                    child: SettingsScaffold(
                      children: <Widget>[
                        SettingsSection.form(
                          title: 'Hooks',
                          children: <Widget>[TRTextField(label: 'Setup')],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            width: 390,
          ),
        );

        expect(
          tester.getRect(find.text('Tinest')).left,
          moreOrLessEquals(
            tester.getRect(find.text('Hooks')).left,
            epsilon: 0.5,
          ),
        );
        expect(tester.getRect(find.text('Tinest')).left, TRSpacing.extraLarge);
      },
    );

    testWidgets('spaces actions and wraps them below long titles', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: TinyrackTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SizedBox(
                width: 390,
                child: TRPaneHeader(
                  title: const TRText.inherit(
                    'A deliberately long settings detail heading',
                  ),
                  description: const TRText.inherit(
                    '/a/long/path/that/must/not/crowd/the/actions',
                  ),
                  actions: <Widget>[
                    TRIconButton(
                      label: 'Copy',
                      onPressed: () {},
                      icon: const Icon(Icons.copy),
                    ),
                    TRButton(
                      key: const ValueKey<String>('save-action'),
                      onPressed: () {},
                      child: const TRText.inherit('Save'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final copy = tester.getRect(find.byType(TRIconButton));
      final save = tester.getRect(
        find.byKey(const ValueKey<String>('save-action')),
      );
      expect(save.left - copy.right, greaterThanOrEqualTo(TRSpacing.small));
    });
  });

  group('SettingsEmptyState', () {
    testWidgets('centres a readable title, description, and action', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SettingsEmptyState(
            title: 'Nothing selected',
            description: 'Choose an item from the list to edit it.',
            icon: const Icon(Icons.tune),
            action: TRButton(
              onPressed: () {},
              child: const TRText.inherit('Create'),
            ),
          ),
          width: 900,
        ),
      );

      final title = tester.getRect(find.text('Nothing selected'));
      final description = tester.getRect(
        find.text('Choose an item from the list to edit it.'),
      );
      final action = tester.getRect(find.byType(TRButton));
      expect(
        title.center.dx,
        moreOrLessEquals(
          tester.getRect(find.byType(Scaffold)).center.dx,
          epsilon: 1,
        ),
      );
      expect(description.top - title.bottom, TRSpacing.extraSmall);
      expect(action.top - description.bottom, TRSpacing.large);
    });
  });

  group('SettingsDialogForm', () {
    testWidgets(
      'keeps the final field and action in the keyboard-visible viewport',
      (tester) async {
        const viewport = Size(390, 760);
        const keyboardHeight = 300.0;
        const fieldKey = ValueKey<String>('dialog-final-input');
        const actionKey = ValueKey<String>('dialog-primary-action');
        await tester.binding.setSurfaceSize(viewport);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: TinyrackTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: viewport,
                viewInsets: const EdgeInsets.only(bottom: keyboardHeight),
              ),
              child: child!,
            ),
            home: Builder(
              builder: (context) => TRButton(
                onPressed: () => showTRAlertDialog<void>(
                  context: context,
                  builder: (context) => TRAlertDialog(
                    title: const TRText.inherit('Edit connection'),
                    content: SettingsDialogForm(
                      children: <Widget>[
                        for (var index = 0; index < 7; index += 1)
                          TRTextField(label: 'Field $index'),
                        const TRTextField(key: fieldKey, label: 'Final field'),
                      ],
                    ),
                    actions: <TRButton>[
                      TRButton(
                        key: actionKey,
                        onPressed: () {},
                        child: const TRText.inherit('Save'),
                      ),
                    ],
                  ),
                ),
                child: const TRText.inherit('Open'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(fieldKey));
        await tester.showKeyboard(find.byKey(fieldKey));
        await tester.pumpAndSettle();

        final keyboardTop = viewport.height - keyboardHeight;
        expect(
          tester.getRect(find.byKey(fieldKey)).bottom,
          lessThanOrEqualTo(keyboardTop),
        );
        expect(
          tester.getRect(find.byKey(actionKey)).bottom,
          lessThanOrEqualTo(keyboardTop),
        );
        expect(tester.takeException(), isNull);
      },
      tags: const <String>['feature_test__soft_keyboard_visibility__widget'],
    );

    testWidgets('uses the overlay token and one gap between fields', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const Center(
            child: SettingsDialogForm(
              children: <Widget>[
                TRTextField(label: 'Name'),
                TRTextField(label: 'Description'),
              ],
            ),
          ),
        ),
      );

      final form = tester.getRect(find.byType(SettingsDialogForm));
      final fields = find.byType(TRTextField);
      expect(form.width, TRMeasurements.overlayWidthMd);
      expect(
        tester.getRect(fields.at(1)).top - tester.getRect(fields.at(0)).bottom,
        TRSpacing.large,
      );
    });
  });

  group('SettingsCompactToolbar', () {
    testWidgets('gives every select the full width', (tester) async {
      await tester.pumpWidget(
        _host(
          SettingsCompactToolbar(
            builder: (width) => <Widget>[
              for (final label in <String>['Category', 'Daemon', 'Project'])
                TRSelect<String>.controlled(
                  value: null,
                  label: label,
                  width: width,
                  items: const <TRSelectItem<String>>[
                    TRSelectItem<String>(value: 'a', label: 'A'),
                  ],
                  onValueChange: (_) {},
                ),
            ],
          ),
          width: 390,
        ),
      );

      // Three stacked selects rendered at three different widths and
      // alignments, because only one of them was told to fill the pane. The
      // trigger has to fill it, not just the field around it: a tap lands on
      // the centre of the control, which otherwise falls in empty space.
      const expected = 390 - 2 * TRSpacing.extraLarge;
      final triggers = find.descendant(
        of: find.byType(SettingsCompactToolbar),
        matching: find.byType(TextButton),
      );
      expect(triggers, findsNWidgets(3));
      for (var index = 0; index < 3; index++) {
        expect(tester.getRect(triggers.at(index)).width, expected);
      }
    });
  });
}

class _CollectionIdentityProbe extends StatefulWidget {
  const new({super.key});

  @override
  State<_CollectionIdentityProbe> createState() =>
      _CollectionIdentityProbeState();
}

class _CollectionIdentityProbeState extends State<_CollectionIdentityProbe> {
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
