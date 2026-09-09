import 'dart:io';

import 'package:app/testing/shared/presentation/settings_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_until.dart';

/// Opens a settings category by its stable row key.
Future<void> openSettingsCategory(WidgetTester tester, String category) async {
  final row = find.byKey(ValueKey<String>('settings-category-row-$category'));
  await pumpUntil(tester, row.hitTestable());
  await tester.tap(row.hitTestable());
  await tester.pumpAndSettle();
}

/// Scrolls [action] into the middle of its settings editor and returns it.
Future<Finder> centerSettingsAction(
  WidgetTester tester,
  Finder action, {
  Finder? settingsOwner,
}) async {
  // A detail replacement deliberately keeps the outgoing route inert during
  // its transition. Both routes listen to the same pane controller, so until
  // that transition settles they can render the new editor identity while
  // retaining independent lazy-list scroll positions. Never choose a scroll
  // owner from that transient pair: it can disappear before the action is
  // built in the incoming route.
  await tester.pumpAndSettle();
  if (settingsOwner != null) {
    expect(
      settingsOwner,
      findsOneWidget,
      reason: 'a settled settings destination has one editor owner',
    );
  }
  // Saving can also briefly replace the editor with its loading state. Wait
  // for the settled settings list to remount before revealing the trailing
  // action. Jump one currently known extent at a time: lazily built sections
  // can extend the list after a jump, and reaching a stable end without the
  // action is a real contract failure.
  final ownedAction = settingsOwner == null
      ? action
      : find.descendant(of: settingsOwner, matching: action);
  var anchoredAtStart = false;
  while (ownedAction.evaluate().isEmpty) {
    final settingsLists = find.descendant(
      of: settingsOwner ?? find.byType(SettingsScaffold),
      matching: find.byType(ListView),
    );
    await pumpUntil(tester, settingsLists);
    final settingsScrollable = find
        .descendant(of: settingsLists.first, matching: find.byType(Scrollable))
        .first;
    await pumpUntil(tester, settingsScrollable);
    final position = tester.state<ScrollableState>(settingsScrollable).position;
    if (!anchoredAtStart) {
      anchoredAtStart = true;
      if (position.pixels > position.minScrollExtent) {
        position.jumpTo(position.minScrollExtent);
        await tester.pumpAndSettle();
        continue;
      }
    }
    final nextExtent = position.maxScrollExtent;
    if (!position.hasContentDimensions || nextExtent <= position.pixels) {
      throw TestFailure('Settings action was not built after scrolling.');
    }
    position.jumpTo(nextExtent);
    await tester.pumpAndSettle();
  }
  await pumpUntil(tester, ownedAction);
  expect(
    ownedAction,
    findsOneWidget,
    reason: 'the exact settings editor owns one actionable control',
  );
  await Scrollable.ensureVisible(tester.element(ownedAction), alignment: 0.5);
  await tester.pumpAndSettle();
  return ownedAction;
}

/// Replaces a text field's contents through the platform text input.
///
/// `enterText` alone leaves the previous value in place for these fields.
Future<void> replaceMcpFieldText(
  WidgetTester tester,
  String key,
  String value,
) async {
  final field = find.byKey(ValueKey<String>(key));
  final input = find.descendant(of: field, matching: find.byType(EditableText));
  await tester.ensureVisible(field);
  await tester.tap(input);
  await tester.pump();
  tester.testTextInput.enterText(value);
  await tester.pump();
}

/// Absolute path of the bundled fake MCP server entry point.
String fakeMcpServerPath() {
  final suffix = <String>[
    'packages',
    'daemon',
    'test',
    'support',
    'fake_mcp_server_main.dart',
  ].join(Platform.pathSeparator);
  final candidates = <File>[
    File('${Directory.current.path}${Platform.pathSeparator}$suffix'),
    File(
      '${Directory.current.path}${Platform.pathSeparator}..'
      '${Platform.pathSeparator}..${Platform.pathSeparator}$suffix',
    ),
  ];
  for (final candidate in candidates) {
    if (candidate.existsSync()) return candidate.absolute.path;
  }
  throw TestFailure(
    'Could not locate fake_mcp_server_main.dart from ${Directory.current}.',
  );
}

/// Absolute path of the Dart executable that can run the fake MCP server.
String dartExecutable() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null && flutterRoot.isNotEmpty) {
    final executable = File(
      <String>[
        flutterRoot,
        'bin',
        'cache',
        'dart-sdk',
        'bin',
        if (Platform.isWindows) 'dart.exe' else 'dart',
      ].join(Platform.pathSeparator),
    );
    if (executable.existsSync()) return executable.absolute.path;
  }
  final lookup = Process.runSync(
    Platform.isWindows ? 'where' : 'which',
    <String>['dart'],
  );
  if (lookup.exitCode == 0) {
    return (lookup.stdout as String).split(RegExp(r'\r?\n')).first.trim();
  }
  throw TestFailure(
    'Could not locate the Dart executable for the MCP fixture.',
  );
}
