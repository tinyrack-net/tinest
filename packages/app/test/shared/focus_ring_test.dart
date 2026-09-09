import 'package:app/src/features/conversation/application/chat_timeline_model.dart';
import 'package:app/src/features/conversation/presentation/chat_tool_card.dart';
import 'package:app/src/shared/presentation/settings_layout.dart';
import 'package:app/src/shared/presentation/tinest_list_row.dart';
import 'package:app/src/shared/presentation/tinest_selection_row.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/src/internal/focus_source.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../support/localization.dart';

/// Hosts one composite at a fixed width, so a focus expectation reads the
/// composite rather than whatever the surrounding page happened to impose.
Widget _host(Widget child, {double width = 1200}) => MaterialApp(
  theme: testLightTheme,
  locale: testLocale,
  localizationsDelegates: testLocalizationsDelegates,
  supportedLocales: testSupportedLocales,
  home: Scaffold(
    body: SizedBox(width: width, child: child),
  ),
);

void Function(Canvas) _focusRingPainter(WidgetTester tester, Finder owner) {
  final ring = find
      .descendant(of: owner, matching: find.byType(TRFocusRing))
      .first;
  final render = tester.renderObject<RenderCustomPaint>(
    find.descendant(of: ring, matching: find.byType(CustomPaint)).first,
  );
  return (canvas) => render.foregroundPainter?.paint(canvas, render.size);
}

/// Matches the widget that currently holds the primary focus.
///
/// A control is free to build its focus node behind whatever wrapper it likes,
/// so a traversal expectation asks where the focus landed rather than which
/// widget type carries the node.
Finder get _primaryFocus => find.byElementPredicate(
  (element) => element == FocusManager.instance.primaryFocus?.context,
);

Color _focusColor(WidgetTester tester) =>
    tester.element(find.byType(TinestListRow)).tinyrackTheme.focus;

BorderSide _selectPaintedSide(WidgetTester tester) {
  final button = tester.widget<TextButton>(find.byType(TextButton).first);
  return button.style!.side!.resolve(<WidgetState>{
    if (button.focusNode?.hasFocus ?? false) WidgetState.focused,
  })!;
}

Future<void> _requestFocusFromKeyboard(
  WidgetTester tester,
  Finder owner,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
  TRFocusSource.instance.debugSetKeyboardModality(true);
  Focus.of(
    tester.element(
      find.descendant(of: owner, matching: find.byType(TRFocusRing)).first,
    ),
  ).requestFocus();
  await tester.pumpAndSettle();
  await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
}

void main() {
  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    TRFocusSource.instance.debugReset();
  });
  tearDown(TRFocusSource.instance.debugReset);

  group('TinestListRow focus ring', () {
    testWidgets('leaves the ring to a control that takes the focus', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SettingsRow(
            title: const TRText.inherit('Theme'),
            description: const TRText.inherit('Applies to the whole app.'),
            control: TRSelect<String>.controlled(
              key: const ValueKey<String>('theme-mode'),
              value: 'system',
              items: const <TRSelectItem<String>>[
                TRSelectItem<String>(value: 'system', label: 'Follow system'),
              ],
              onValueChange: (_) {},
            ),
          ),
        ),
      );

      final trigger = find.descendant(
        of: find.byKey(const ValueKey<String>('theme-mode')),
        matching: find.byType(TextButton),
      );
      tester.widget<TextButton>(trigger).focusNode!.requestFocus();
      await tester.pumpAndSettle();

      // The select answers focus itself, so a row that also ringed showed two
      // marks for one control. A row reports focus for its descendants too, so
      // the ring has to follow the primary focus rather than that.
      expect(
        _focusRingPainter(tester, find.byType(TinestListRow)),
        isNot(paints..rrect(color: _focusColor(tester))),
      );
    });

    testWidgets('rings itself for keyboard focus but not pointer focus', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SettingsRow(
            title: const TRText.inherit('Open'),
            onTap: () {},
            control: const Icon(Icons.chevron_right),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        _focusRingPainter(tester, find.byType(TinestListRow)),
        isNot(paints..rrect(color: _focusColor(tester))),
      );

      tester.binding.focusManager.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _requestFocusFromKeyboard(tester, find.byType(TinestListRow));

      expect(
        _focusRingPainter(tester, find.byType(TinestListRow)),
        paints..rrect(color: _focusColor(tester)),
      );
    });

    testWidgets('does not move its content when it takes the focus', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SettingsRow(
            title: const TRText.inherit('Open'),
            onTap: () {},
            control: const Icon(Icons.chevron_right),
          ),
        ),
      );

      final before = tester.getRect(find.byType(Icon));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // A ring added to the layout shrinks the content box and re-lays-out the
      // trailing control, which destroys its focus node mid-traversal.
      expect(tester.getRect(find.byType(Icon)), before);
    });
  });

  group('TRSelect focus policy', () {
    testWidgets('uses a border only for keyboard-originated focus', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const TRSelect<String>(
            defaultValue: 'beta',
            items: <TRSelectItem<String>>[
              TRSelectItem<String>(value: 'stable', label: 'Stable'),
              TRSelectItem<String>(value: 'beta', label: 'Beta'),
            ],
          ),
        ),
      );

      final trigger = find.byType(TextButton).first;
      final focus = tester.element(trigger).tinyrackTheme.focus;

      await tester.tap(trigger, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(_selectPaintedSide(tester).color, isNot(focus));

      await tester.tapAt(
        const Offset(1000, 600),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      tester.binding.focusManager.primaryFocus?.unfocus();
      TRFocusSource.instance.debugSetKeyboardModality(true);
      tester.widget<TextButton>(trigger).focusNode!.requestFocus();
      await tester.pumpAndSettle();

      expect(_selectPaintedSide(tester).color, focus);
    });
  });

  group('SettingsRow traversal', () {
    testWidgets('gives a switch row one tab stop', (tester) async {
      await tester.pumpWidget(
        _host(
          Column(
            children: <Widget>[
              TRButton(onPressed: () {}, child: const TRText.inherit('Before')),
              TinestSwitchRow(
                title: const TRText.inherit('Enabled'),
                value: false,
                onChanged: (_) {},
              ),
              TRButton(onPressed: () {}, child: const TRText.inherit('After')),
            ],
          ),
        ),
      );

      // The row's tap only repeats what the switch already does, so a tab stop
      // on each made one setting cost two presses.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.widgetWithText(TRButton, 'Before'),
          matching: _primaryFocus,
        ),
        findsOneWidget,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(TRSwitch), matching: _primaryFocus),
        findsOneWidget,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.widgetWithText(TRButton, 'After'),
          matching: _primaryFocus,
        ),
        findsOneWidget,
      );
    });

    testWidgets('keeps a separate stop for a distinct trailing action', (
      tester,
    ) async {
      var opened = 0;
      var closed = 0;
      await tester.pumpWidget(
        _host(
          TinestListRow(
            title: const TRText.inherit('Session'),
            onTap: () => opened++,
            trailing: TRIconButton(
              appearance: TRAppearance.ghost,
              label: 'Close',
              onPressed: () => closed++,
              icon: const Icon(Icons.close),
            ),
          ),
        ),
      );

      // Selecting a tab and closing it are two actions, so a row whose trailing
      // control does something else keeps both stops.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        _focusRingPainter(tester, find.byType(TinestListRow)),
        paints..rrect(color: _focusColor(tester)),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        _focusRingPainter(tester, find.byType(TinestListRow)),
        isNot(paints..rrect(color: _focusColor(tester))),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect((opened, closed), (0, 1));
    });

    testWidgets('still toggles a switch row from a pointer tap', (
      tester,
    ) async {
      var value = false;
      await tester.pumpWidget(
        _host(
          TinestSwitchRow(
            title: const TRText.inherit('Enabled'),
            subtitle: const TRText.inherit('Explains the setting.'),
            value: value,
            onChanged: (next) => value = next,
          ),
        ),
      );

      await tester.tap(find.text('Explains the setting.'));
      await tester.pump();
      expect(value, isTrue);
    });
  });

  group('ChatToolCard focus ring', () {
    testWidgets('shows where the keyboard is', (tester) async {
      await tester.pumpWidget(
        _host(
          ChatToolCard(
            activity: ChatToolActivity(
              key: 'tool-call-1',
              turnId: 'turn-1',
              createdAt: DateTime.utc(2026, 8, 3),
              callId: 'call-1',
              toolName: 'read_file',
              arguments: const <String, dynamic>{'path': 'lib/main.dart'},
              status: ChatToolStatus.succeeded,
              output: 'void main() {}',
            ),
            onToggle: () {},
          ),
        ),
      );

      final focus = tester
          .element(find.byType(ChatToolCard))
          .tinyrackTheme
          .focus;

      // The card is a tab stop, so a keyboard user has to be able to see it.
      expect(
        _focusRingPainter(tester, find.byType(ChatToolCard)),
        isNot(paints..rrect(color: focus)),
      );
      await tester.tap(find.byType(ChatToolCard));
      await tester.pumpAndSettle();
      expect(
        _focusRingPainter(tester, find.byType(ChatToolCard)),
        isNot(paints..rrect(color: focus)),
      );
      tester.binding.focusManager.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _requestFocusFromKeyboard(tester, find.byType(ChatToolCard));
      expect(
        _focusRingPainter(tester, find.byType(ChatToolCard)),
        paints..rrect(color: focus),
      );
    });
  });
}
