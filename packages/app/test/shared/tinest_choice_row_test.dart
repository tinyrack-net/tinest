import 'package:app/src/shared/presentation/settings_layout.dart';
import 'package:app/src/shared/presentation/tinest_list_row.dart';
import 'package:app/src/shared/presentation/tinest_selection_row.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// A phone narrow enough that a long value cannot show in full beside a label.
const Size _narrowPhone = Size(320, 640);

const String _longValue = 'システムのテーマにそのまま合わせる';

void main() {
  testWidgets('shows its value beside the label rather than under it', (
    tester,
  ) async {
    _useViewport(tester, _narrowPhone);
    await tester.pumpWidget(_host());

    final row = tester.widget<TinestListRow>(find.byType(TinestListRow));
    expect(row.trailingLayout, TinestListRowTrailingLayout.inline);
    expect(find.text('다크'), findsOneWidget);

    final title = tester.getRect(find.text('테마'));
    final value = tester.getRect(find.text('다크'));
    expect(value.left, greaterThan(title.right));
  });

  testWidgets('draws the value without a field frame', (tester) async {
    _useViewport(tester, _narrowPhone);
    await tester.pumpWidget(_host());

    // Ghost: the value reads as the row's own trailing copy. A solid field
    // parked in a list row is the shape this replaces.
    expect(
      tester
          .widget<TRSelect<String>>(
            find.byType(TRSelect<String>),
          )
          .appearance,
      TRFieldAppearance.ghost,
    );
  });

  testWidgets('keeps the token inline inset on both sides while open', (
    tester,
  ) async {
    _useViewport(tester, _narrowPhone);
    await tester.pumpWidget(_host());

    final select = find.byType(TRSelect<String>);
    await tester.tap(select);
    await tester.pumpAndSettle();

    final trigger = tester.getRect(
      find.descendant(of: select, matching: find.byType(TextButton)),
    );
    final label = tester.getRect(
      find.descendant(of: select, matching: find.text('다크')),
    );
    final chevron = find
        .descendant(
          of: select,
          matching: find.byType(CustomPaint),
        )
        .evaluate()
        .map(
          (element) => tester.getRect(
            find.byElementPredicate(
              (candidate) => identical(candidate, element),
            ),
          ),
        )
        // The chevron is the one square the size scale draws it at.
        .where((rect) => rect.width == TRSpacing.large)
        .single;
    final expectedInset =
        TRControlMetrics.inlinePaddingOf(TRUiSize.md) +
        TRControlMetrics.borderWidth;
    expect(
      label.left - trigger.left,
      moreOrLessEquals(expectedInset, epsilon: 0.5),
    );
    expect(
      trigger.right - chevron.right,
      moreOrLessEquals(expectedInset, epsilon: 0.5),
    );
  });

  testWidgets('keeps a value too long for the line inside the row', (
    tester,
  ) async {
    _useViewport(tester, _narrowPhone);
    await tester.pumpWidget(_host(value: _longValue));

    expect(tester.takeException(), isNull);
    final row = tester.getRect(find.byType(TinestListRow));
    final padding = SettingsRow.resolvedPadding(
      tester.element(find.byType(TinestListRow)),
    ).resolve(TextDirection.ltr);
    expect(
      tester.getRect(find.text(_longValue)).right,
      lessThanOrEqualTo(row.right - padding.right + 0.01),
    );
    // The label keeps its rail rather than being squeezed out by the value.
    expect(tester.getRect(find.text('테마')).width, greaterThan(0));
  });

  testWidgets('costs one tab stop, not two', (tester) async {
    _useViewport(tester, _narrowPhone);
    await tester.pumpWidget(_host());

    // The row's tap is the select's tap, so a reader tabbing through settings
    // reaches one stop per setting and hears the setting named once.
    final row = tester.widget<TinestListRow>(find.byType(TinestListRow));
    expect(row.controlOwnsFocus, isTrue);
    expect(row.onTap, isNull);
  });

  testWidgets('reads as disabled with no handler', (tester) async {
    _useViewport(tester, _narrowPhone);
    await tester.pumpWidget(_host(onChanged: null));

    expect(
      tester.widget<TinestListRow>(find.byType(TinestListRow)).enabled,
      isFalse,
    );
    expect(
      tester.widget<TRSelect<String>>(find.byType(TRSelect<String>)).enabled,
      isFalse,
    );
  });
}

void _useViewport(WidgetTester tester, Size size) {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
}

Widget _host({
  String value = '다크',
  ValueChanged<String?>? onChanged = _ignore,
}) {
  final choice = TinestChoiceRow<String>(
    title: const TRText.inherit('테마'),
    semanticLabel: '테마',
    searchPlaceholder: '검색',
    noResultsText: '결과 없음',
    value: value,
    onChanged: onChanged,
    items: <TRSelectItem<String>>[
      TRSelectItem<String>(value: value, label: value),
      const TRSelectItem<String>(value: '라이트', label: '라이트'),
    ],
  );
  return MaterialApp(
    theme: TinyrackTheme.light(),
    home: Scaffold(
      body: choice,
    ),
  );
}

void _ignore(String? value) {}
