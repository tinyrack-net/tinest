import 'package:app/src/shared/presentation/tinest_bottom_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

void main() {
  testWidgets('short content uses its intrinsic height below the cap', (
    tester,
  ) async {
    await _pumpSheet(
      tester,
      content: const SizedBox(height: 80, child: Text('Short content')),
    );

    final drawer = find.byType(TRDrawer);
    expect(tester.getSize(drawer).height, lessThan(800 * 0.7));
    expect(tester.getRect(drawer).bottom, 800);
  });

  testWidgets('long content is capped at 70 percent and remains scrollable', (
    tester,
  ) async {
    await _pumpSheet(
      tester,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var index = 0; index < 40; index += 1)
            SizedBox(height: 40, child: Text('Item $index')),
        ],
      ),
    );

    final drawer = find.byType(TRDrawer);
    expect(tester.getSize(drawer).height, 800 * 0.7);
    expect(tester.getRect(find.text('Item 39')).top, greaterThan(800));

    await tester.ensureVisible(find.text('Item 39'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text('Item 39')).bottom,
      lessThanOrEqualTo(tester.getRect(drawer).bottom),
    );
  });

  testWidgets('safe area and keyboard inset are consumed within the cap', (
    tester,
  ) async {
    await _pumpSheet(
      tester,
      padding: const EdgeInsets.fromLTRB(8, 24, 12, 34),
      viewInsets: const EdgeInsets.only(bottom: 220),
      textScaler: const TextScaler.linear(2),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var index = 0; index < 20; index += 1)
            Text('Accessible item $index'),
        ],
      ),
    );

    final drawer = find.byType(TRDrawer);
    expect(tester.getSize(drawer).height, lessThanOrEqualTo(800 * 0.7));
    expect(tester.getRect(drawer).bottom, 800);
    expect(
      tester.getRect(find.text('Accessible item 0')).bottom,
      lessThanOrEqualTo(800 - 220),
    );
    expect(tester.takeException(), isNull);
  }, tags: const <String>['feature_test__soft_keyboard_visibility__widget']);
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  required Widget content,
  EdgeInsets padding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: TinyrackTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 800),
          padding: padding,
          viewInsets: viewInsets,
          textScaler: textScaler,
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => TRButton(
          onPressed: () => showTinestBottomSheet<void>(
            context: context,
            builder: (_) => TinestBottomSheet(content: content),
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}
