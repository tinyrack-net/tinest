import 'package:app/src/shared/presentation/tinest_icons.dart';
import 'package:app/src/shared/presentation/tinest_page_shell.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../support/localization.dart';

void main() {
  testWidgets('page surface stays edge to edge while content respects insets', (
    tester,
  ) async {
    const viewport = Size(400, 600);
    const insets = EdgeInsets.fromLTRB(20, 40, 10, 30);
    EdgeInsets? childPadding;

    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _host(
        padding: insets,
        body: Builder(
          builder: (context) {
            childPadding = MediaQuery.paddingOf(context);
            return const SizedBox.expand(key: ValueKey<String>('body'));
          },
        ),
      ),
    );

    final shell = find.byType(TRAppShell);
    final surface = find.descendant(
      of: find.byType(TinestPageShell),
      matching: find.byType(ColoredBox),
    );

    expect(tester.getRect(surface.first), Offset.zero & viewport);
    expect(tester.getRect(shell), const Rect.fromLTRB(20, 40, 390, 570));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('title'))).dy,
      greaterThanOrEqualTo(40),
    );
    expect(childPadding, EdgeInsets.zero);
  });

  testWidgets('zero-inset desktop layout remains full size', (tester) async {
    const viewport = Size(1200, 900);
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _host(padding: EdgeInsets.zero, body: const SizedBox.expand()),
    );

    expect(tester.getRect(find.byType(TRAppShell)), Offset.zero & viewport);
  });

  testWidgets('narrow task header wraps instead of truncating its title', (
    tester,
  ) async {
    const viewport = Size(344, 672);
    const titleKey = ValueKey<String>('long-title');
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _host(
        padding: EdgeInsets.zero,
        textScaler: const TextScaler.linear(2),
        title: const Text('Add a remote daemon connection', key: titleKey),
        actions: <TRIconButton>[
          TRIconButton(
            label: 'Copy path',
            onPressed: () {},
            icon: const Icon(TinestIcons.copy),
          ),
        ],
        body: const SizedBox.expand(),
      ),
    );

    final paragraph = tester.renderObject<RenderParagraph>(
      find.byKey(titleKey),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'header actions share the title line instead of forming their own run',
    (tester) async {
      // A phone-width bar carrying a title long enough to fill it. The actions
      // used to be laid out in a wrap, so they dropped to a second run and the
      // bar grew by a whole control height. They belong beside the title.
      const viewport = Size(344, 672);
      const titleKey = ValueKey<String>('long-title');
      const actionKey = ValueKey<String>('header-action');
      await tester.binding.setSurfaceSize(viewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _host(
          padding: EdgeInsets.zero,
          title: const Text('Custom provider advanced settings', key: titleKey),
          actions: <TRIconButton>[
            TRIconButton(
              key: actionKey,
              label: 'Copy path',
              onPressed: () {},
              icon: const Icon(TinestIcons.copy),
            ),
            TRIconButton(
              label: 'Refresh',
              onPressed: () {},
              icon: const Icon(TinestIcons.refresh),
            ),
          ],
          body: const SizedBox.expand(),
        ),
      );

      final title = tester.getRect(find.byKey(titleKey));
      final action = tester.getRect(find.byKey(actionKey));
      expect(action.top, lessThan(title.bottom));
      expect(action.bottom, greaterThan(title.top));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the bar rests at the shared header height either way', (
    tester,
  ) async {
    const viewport = Size(390, 844);
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Sized by its contents the bar was a line of text tall with no actions
    // and a control tall with them, so a page carrying none drew a visibly
    // shorter bar than the destinations beside it in the same stack.
    await tester.pumpWidget(
      _host(padding: EdgeInsets.zero, body: const SizedBox.expand()),
    );
    expect(
      tester.getSize(find.byType(TRAppShellHeader)).height,
      TRMeasurements.headerHeight + TRControlMetrics.borderWidth,
    );

    await tester.pumpWidget(
      _host(
        padding: EdgeInsets.zero,
        actions: <TRIconButton>[
          TRIconButton(
            label: 'Copy path',
            onPressed: () {},
            icon: const Icon(TinestIcons.copy),
          ),
          TRIconButton(
            label: 'Refresh',
            onPressed: () {},
            icon: const Icon(TinestIcons.refresh),
          ),
        ],
        body: const SizedBox.expand(),
      ),
    );

    expect(
      tester.getSize(find.byType(TRAppShellHeader)).height,
      TRMeasurements.headerHeight + TRControlMetrics.borderWidth,
    );
  });

  testWidgets('a comfortable bar rests a step taller than a standard one', (
    tester,
  ) async {
    const viewport = Size(390, 844);
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // A phone runs comfortable, where a default control is exactly the standard
    // resting height. The bar has to take the same step [TRPaneHeader] does or
    // the control fills it outright.
    await tester.pumpWidget(
      _host(
        padding: EdgeInsets.zero,
        density: TRUiDensity.comfortable,
        body: const SizedBox.expand(),
      ),
    );
    expect(
      tester.getSize(find.byType(TRAppShellHeader)).height,
      TRMeasurements.headerHeight +
          TRSpacing.large +
          TRControlMetrics.borderWidth,
    );

    await tester.pumpWidget(
      _host(
        padding: EdgeInsets.zero,
        density: TRUiDensity.comfortable,
        actions: <TRIconButton>[
          TRIconButton(
            label: 'Copy path',
            onPressed: () {},
            icon: const Icon(TinestIcons.copy),
          ),
        ],
        body: const SizedBox.expand(),
      ),
    );

    expect(
      tester.getSize(find.byType(TRAppShellHeader)).height,
      TRMeasurements.headerHeight +
          TRSpacing.large +
          TRControlMetrics.borderWidth,
    );
  });

  testWidgets('a comfortable header action clears the bar it sits in', (
    tester,
  ) async {
    const viewport = Size(390, 844);
    const actionKey = ValueKey<String>('header-action');
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _host(
        padding: EdgeInsets.zero,
        density: TRUiDensity.comfortable,
        actions: <TRIconButton>[
          TRIconButton(
            key: actionKey,
            label: 'Settings',
            onPressed: () {},
            icon: const Icon(TinestIcons.settings),
          ),
        ],
        body: const SizedBox.expand(),
      ),
    );

    // The reported defect: the gear filled the bar top to bottom, so its tap
    // target met the border and the first control of the page below it.
    final action = tester.getRect(find.byKey(actionKey));
    final bar = tester.getRect(find.byType(TRAppShellHeader));
    expect(action.height, TRControlMetrics.heightOf(TRUiSize.xl));
    expect(action.top - bar.top, greaterThanOrEqualTo(TRSpacing.small));
    expect(
      bar.bottom - TRControlMetrics.borderWidth - action.bottom,
      greaterThanOrEqualTo(TRSpacing.small),
    );
  });

  testWidgets('the header identity keeps its leading rail', (tester) async {
    // The bar used to strut its own height with a zero-width [SizedBox], which
    // also bought a leading [Row] gap on top of the inline padding. The padding
    // carries that inset now, so the identity must not slide toward the edge.
    await tester.pumpWidget(
      _host(padding: EdgeInsets.zero, body: const SizedBox.expand()),
    );

    expect(
      tester.getTopLeft(find.byKey(const ValueKey('title'))).dx,
      TRSpacing.large,
    );
  });

  testWidgets('the page header title is announced as a heading', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _host(padding: EdgeInsets.zero, body: const SizedBox.expand()),
    );

    expect(
      tester.getSemantics(find.byKey(const ValueKey('title'))),
      matchesSemantics(label: 'Title', isHeader: true),
    );
    semantics.dispose();
  });

  testWidgets(
    'mobile input and primary action remain above the software keyboard',
    (tester) async {
      const viewport = Size(390, 760);
      const safeArea = EdgeInsets.only(top: 24, bottom: 16);
      const keyboardHeight = 300.0;
      const fieldKey = ValueKey<String>('focused-input');
      const actionKey = ValueKey<String>('primary-action');

      await tester.binding.setSurfaceSize(viewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _host(
          padding: safeArea,
          viewInsets: const EdgeInsets.only(bottom: keyboardHeight),
          body: Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TRTextField(key: fieldKey),
                TRButton(
                  key: actionKey,
                  onPressed: () {},
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.showKeyboard(find.byKey(fieldKey));
      await tester.pump();

      final keyboardTop = viewport.height - safeArea.bottom - keyboardHeight;
      // The header keeps its content clear of the top inset. Where inside the
      // bar the title lands follows the bar's resting height, so this asserts
      // the safe area rather than a particular inset.
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('title'))).dy,
        greaterThanOrEqualTo(safeArea.top),
      );
      expect(
        tester.getBottomLeft(find.byKey(fieldKey)).dy,
        lessThanOrEqualTo(keyboardTop),
      );
      expect(
        tester.getBottomLeft(find.byKey(actionKey)).dy,
        lessThanOrEqualTo(keyboardTop),
      );
      expect(tester.takeException(), isNull);
    },
    tags: const <String>['feature_test__soft_keyboard_visibility__widget'],
  );
}

Widget _host({
  required EdgeInsets padding,
  required Widget body,
  EdgeInsets viewInsets = EdgeInsets.zero,
  TextScaler textScaler = TextScaler.noScaling,
  Widget title = const Text('Title', key: ValueKey<String>('title')),
  List<TRIconButton> actions = const <TRIconButton>[],
  TRUiDensity density = TRUiDensity.standard,
}) => MaterialApp(
  locale: testLocale,
  localizationsDelegates: testLocalizationsDelegates,
  supportedLocales: testSupportedLocales,
  theme: testLightTheme,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      size: const Size(400, 600),
      padding: padding,
      viewPadding: padding,
      viewInsets: viewInsets,
      textScaler: textScaler,
    ),
    // Stated rather than derived from the width so a height assertion reads
    // one density, not whatever `TinestUiDensity` makes of the viewport.
    child: TRUiDensityScope(density: density, child: child!),
  ),
  home: TinestPageShell(
    appBar: TinestPageHeader(title: title, actions: actions),
    body: body,
  ),
);
