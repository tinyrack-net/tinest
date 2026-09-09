import 'package:app/src/shared/presentation/tinest_list_row.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// A viewport narrow enough that a settings value cannot sit beside its title
/// at its natural width.
const double _narrowWidth = TRMeasurements.measureLg + TRMeasurements.measureXs;

void main() {
  testWidgets('a wide inline trailing shrinks instead of overflowing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        width: _narrowWidth,
        title: '시스템 트레이에서 계속 실행하기',
        // Wider on its own than the row it has to fit inside.
        trailing: _valueTrailing('시스템 테마를 그대로 따르고 다시 시작해도 유지합니다'),
      ),
    );

    expect(tester.takeException(), isNull);

    final content = _contentRect(tester);
    final trailing = tester.getRect(find.byKey(const ValueKey('row-trailing')));
    expect(trailing.right, lessThanOrEqualTo(content.right));
    // A value long enough to swallow the row still leaves the title a rail to
    // read on, rather than collapsing it to nothing.
    expect(
      tester.getRect(find.byKey(const ValueKey('row-title'))).width,
      greaterThanOrEqualTo(TRMeasurements.measureXs),
    );
  });

  testWidgets('a trailing that fits still sits against the content edge', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(width: _narrowWidth, title: '테마', trailing: _valueTrailing('다크')),
    );

    final content = _contentRect(tester);
    final trailing = tester.getRect(find.byKey(const ValueKey('row-trailing')));
    // Capping the trailing must not turn the row into an even split: a short
    // value keeps hugging the edge the way every settings row reads.
    expect(trailing.right, moreOrLessEquals(content.right, epsilon: 0.01));
  });
}

/// Mirrors the shape of a shrink-wrapped [TRSelect] trigger: a self-sizing row
/// whose label may ellipsize once something bounds it.
Widget _valueTrailing(String value) => Row(
  key: const ValueKey<String>('row-trailing'),
  mainAxisSize: MainAxisSize.min,
  children: <Widget>[
    Flexible(
      child: Text(value, overflow: TextOverflow.ellipsis, softWrap: false),
    ),
    const SizedBox(width: TRSpacing.small),
    const SizedBox.square(dimension: TRSpacing.large),
  ],
);

/// The box a row draws its content in, inside its own inline padding.
Rect _contentRect(WidgetTester tester) {
  final row = tester.getRect(find.byType(TinestListRow));
  final padding =
      tester
              .widget<AnimatedContainer>(
                find.descendant(
                  of: find.byType(TinestListRow),
                  matching: find.byWidgetPredicate(
                    (widget) =>
                        widget is AnimatedContainer && widget.padding != null,
                  ),
                ),
              )
              .padding!
          as EdgeInsets;
  return Rect.fromLTRB(
    row.left + padding.left,
    row.top,
    row.right - padding.right,
    row.bottom,
  );
}

Widget _host({
  required double width,
  required String title,
  required Widget trailing,
}) => MaterialApp(
  theme: TinyrackTheme.light(),
  home: Scaffold(
    body: TRUiDensityScope(
      density: TRUiDensity.standard,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: width,
          child: TinestListRow(
            title: Text(title, key: const ValueKey<String>('row-title')),
            trailing: trailing,
          ),
        ),
      ),
    ),
  ),
);
