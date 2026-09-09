@Tags(<String>['feature_test__terminal_lifecycle__widget'])
library;

import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/features/terminals/presentation/tinest_terminal_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';

import '../../support/fake_tinest_api.dart';
import '../../support/localization.dart';

final _now = DateTime.utc(2026, 8, 3);
final _workspace = WorkspaceDto(
  id: 'workspace',
  name: 'Tinest',
  rootPath: '/repos/tinest',
  kind: WorkspaceKind.git,
  createdAt: _now,
);
final _worktree = WorktreeDto(
  id: 'checkout',
  workspaceId: 'workspace',
  name: 'main',
  path: '/repos/tinest',
  branch: 'main',
  head: 'abc',
  kind: WorktreeKind.checkout,
  isTinestOwned: false,
  createdAt: _now,
);
const _terminal = TerminalDto(
  id: 'terminal-shortcuts',
  worktreeId: 'checkout',
  title: 'Remote terminal',
  shell: ShellSpecDto(executable: '/bin/sh'),
  status: TerminalStatus.running,
  columns: 80,
  rows: 24,
  lastSequence: 0,
);

/// Sends one chord to whatever holds focus.
Future<void> _press(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  required bool shift,
}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

void main() {
  testWidgets(
    'a focused terminal keeps control chords and yields the shifted ones',
    (tester) async {
      final fired = <String>[];
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[_workspace],
        worktrees: <WorktreeDto>[_worktree],
        terminals: const <TerminalDto>[_terminal],
        terminalReplay: const <TerminalOutputDto>[
          TerminalOutputDto(
            terminalId: 'terminal-shortcuts',
            sequence: 1,
            data: 'output',
          ),
        ],
      );
      final router = GoRouter(
        initialLocation: TerminalRoute(
          hostId: 'server',
          workspaceId: _workspace.id,
          worktreeId: _worktree.id,
          terminalId: _terminal.id,
        ).location,
        routes: $appRoutes,
      );
      addTearDown(router.dispose);

      // Stands in for the application bindings that DesktopShellScope installs
      // above the router, which is the position that makes them lose to a
      // focused terminal.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appServicesProvider.overrideWithValue(fakeAppServices(api)),
          ],
          child: MaterialApp(
            theme: testLightTheme,
            locale: testLocale,
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            home: CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                const SingleActivator(
                  LogicalKeyboardKey.keyB,
                  control: true,
                  shift: true,
                ): () =>
                    fired.add('toggle-sidebar'),
                const SingleActivator(
                  LogicalKeyboardKey.keyN,
                  control: true,
                  shift: true,
                ): () =>
                    fired.add('new-workspace'),
              },
              child: Router<Object>.withConfig(config: router),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _press(tester, LogicalKeyboardKey.keyB, shift: true);
      await _press(tester, LogicalKeyboardKey.keyN, shift: true);

      expect(fired, <String>['toggle-sidebar', 'new-workspace']);
      expect(
        api.terminalWrites,
        isEmpty,
        reason: 'a reserved application chord must not reach the program',
      );

      await _press(tester, LogicalKeyboardKey.keyB, shift: false);
      await _press(tester, LogicalKeyboardKey.keyN, shift: false);

      // Control with a letter stays with the program: Control+B is the default
      // tmux prefix and Control+Q is flow control, so the shell needs them.
      expect(fired, <String>['toggle-sidebar', 'new-workspace']);
      expect(
        api.terminalWrites.map((write) => write.data).join().codeUnits,
        <int>[0x02, 0x0E],
      );
    },
  );

  testWidgets(
    'Ctrl+Shift+V pastes the clipboard while Ctrl+V stays with the program',
    (tester) async {
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[_workspace],
        worktrees: <WorktreeDto>[_worktree],
        terminals: const <TerminalDto>[_terminal],
      );
      final router = GoRouter(
        initialLocation: TerminalRoute(
          hostId: 'server',
          workspaceId: _workspace.id,
          worktreeId: _worktree.id,
          terminalId: _terminal.id,
        ).location,
        routes: $appRoutes,
      );
      addTearDown(router.dispose);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? <String, Object?>{'text': '붙여넣기'}
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appServicesProvider.overrideWithValue(fakeAppServices(api)),
          ],
          child: MaterialApp.router(
            theme: testLightTheme,
            locale: testLocale,
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('tr-terminal-surface')),
      );
      await tester.pump(kDoubleTapTimeout);

      await _press(tester, LogicalKeyboardKey.keyV, shift: true);
      await tester.pump();
      expect(
        api.terminalWrites.map((write) => write.data).join(),
        '붙여넣기',
        reason: 'the desktop terminal convention pastes on Ctrl+Shift+V',
      );

      await _press(tester, LogicalKeyboardKey.keyV, shift: false);
      await tester.pump();
      expect(
        api.terminalWrites.map((write) => write.data).join().codeUnits.last,
        0x16,
        reason: 'plain Ctrl+V is literal-next and belongs to the program',
      );
    },
  );

  testWidgets('Ctrl+Shift+C copies the selection to the clipboard', (
    tester,
  ) async {
    final api = FakeTinestApi(
      workspaces: <WorkspaceDto>[_workspace],
      worktrees: <WorktreeDto>[_worktree],
      terminals: const <TerminalDto>[_terminal],
      terminalReplay: const <TerminalOutputDto>[
        TerminalOutputDto(
          terminalId: 'terminal-shortcuts',
          sequence: 1,
          data: 'output',
        ),
      ],
    );
    final router = GoRouter(
      initialLocation: TerminalRoute(
        hostId: 'server',
        workspaceId: _workspace.id,
        worktreeId: _worktree.id,
        terminalId: _terminal.id,
      ).location,
      routes: $appRoutes,
    );
    addTearDown(router.dispose);
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add(
            (call.arguments as Map<Object?, Object?>)['text']! as String,
          );
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appServicesProvider.overrideWithValue(fakeAppServices(api)),
        ],
        child: MaterialApp.router(
          theme: testLightTheme,
          locale: testLocale,
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('tr-terminal-surface')));
    await tester.pump(kDoubleTapTimeout);

    // Ctrl+Shift+C with nothing selected copies nothing and sends nothing.
    await _press(tester, LogicalKeyboardKey.keyC, shift: true);
    await tester.pump();
    expect(copied, isEmpty);
    expect(api.terminalWrites, isEmpty);

    final view = tester.widget<TinestTerminalView>(
      find.byType(TinestTerminalView),
    );
    view.controller.selectAll();
    await tester.pump();
    await _press(tester, LogicalKeyboardKey.keyC, shift: true);
    await tester.pump();

    expect(copied.join().trim(), 'output');
    expect(
      api.terminalWrites,
      isEmpty,
      reason: 'the copy chord never reaches the program',
    );
  });

  testWidgets('a Hangul composition followed by Space is written once', (
    tester,
  ) async {
    final api = FakeTinestApi(
      workspaces: <WorkspaceDto>[_workspace],
      worktrees: <WorktreeDto>[_worktree],
      terminals: const <TerminalDto>[_terminal],
    );
    final router = GoRouter(
      initialLocation: TerminalRoute(
        hostId: 'server',
        workspaceId: _workspace.id,
        worktreeId: _worktree.id,
        terminalId: _terminal.id,
      ).location,
      routes: $appRoutes,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appServicesProvider.overrideWithValue(fakeAppServices(api)),
        ],
        child: MaterialApp.router(
          theme: testLightTheme,
          locale: testLocale,
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('tr-terminal-surface')));
    await tester.pump(kDoubleTapTimeout);

    for (final value in <TextEditingValue>[
      const TextEditingValue(
        text: 'ㅎ',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      ),
      const TextEditingValue(
        text: '한',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      ),
      const TextEditingValue(
        text: '한ㄱ',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 1, end: 2),
      ),
      const TextEditingValue(
        text: '한글',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 1, end: 2),
      ),
      const TextEditingValue(
        text: '한글 ',
        selection: TextSelection.collapsed(offset: 3),
      ),
      const TextEditingValue(
        text: '한글 ',
        selection: TextSelection.collapsed(offset: 3),
      ),
    ]) {
      tester.testTextInput.updateEditingValue(value);
      await tester.pump();
    }

    expect(api.terminalWrites.map((write) => write.data).join(), '한글 ');
  });

  testWidgets(
    'Windows Hangul typing commits each syllable once without resets',
    (tester) async {
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[_workspace],
        worktrees: <WorktreeDto>[_worktree],
        terminals: const <TerminalDto>[_terminal],
      );
      final router = GoRouter(
        initialLocation: TerminalRoute(
          hostId: 'server',
          workspaceId: _workspace.id,
          worktreeId: _worktree.id,
          terminalId: _terminal.id,
        ).location,
        routes: $appRoutes,
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appServicesProvider.overrideWithValue(fakeAppServices(api)),
          ],
          child: MaterialApp.router(
            theme: testLightTheme,
            locale: testLocale,
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('tr-terminal-surface')),
      );
      await tester.pump(kDoubleTapTimeout);

      final client = tester.allStates.whereType<DeltaTextInputClient>().single;
      tester.testTextInput.log.clear();

      TextEditingDeltaNonTextUpdate nonText(
        String oldText,
        int selection, {
        TextRange composing = TextRange.empty,
      }) => TextEditingDeltaNonTextUpdate(
        oldText: oldText,
        selection: TextSelection.collapsed(offset: selection),
        composing: composing,
      );
      TextEditingDeltaInsertion insert(
        String oldText,
        String inserted,
        int offset, {
        TextRange composing = TextRange.empty,
      }) => TextEditingDeltaInsertion(
        oldText: oldText,
        textInserted: inserted,
        insertionOffset: offset,
        selection: TextSelection.collapsed(offset: offset + inserted.length),
        composing: composing,
      );
      TextEditingDeltaReplacement replace(
        String oldText,
        TextRange range,
        String replacement, {
        TextRange composing = TextRange.empty,
      }) => TextEditingDeltaReplacement(
        oldText: oldText,
        replacementText: replacement,
        replacedRange: range,
        selection: TextSelection.collapsed(
          offset: range.start + replacement.length,
        ),
        composing: composing,
      );

      // The Win32 embedder's delta stream for typing 안녕하세요. plus a
      // space with Microsoft's Korean IME: every settled syllable commits
      // and closes its composition (WM_IME_ENDCOMPOSITION) and the next
      // jamo opens a fresh one. The engine-side model is never reset, so
      // oldText accumulates across the whole phrase.
      const compose01 = TextRange(start: 0, end: 1);
      const compose12 = TextRange(start: 1, end: 2);
      const compose23 = TextRange(start: 2, end: 3);
      const compose34 = TextRange(start: 3, end: 4);
      const compose45 = TextRange(start: 4, end: 5);
      final deltas = <TextEditingDelta>[
        nonText('', 0, composing: const TextRange.collapsed(0)),
        insert('', 'ㅇ', 0, composing: compose01),
        replace('ㅇ', compose01, '아', composing: compose01),
        replace('아', compose01, '안', composing: compose01),
        replace('안', compose01, '안', composing: compose01),
        nonText('안', 1),
        nonText('안', 1, composing: const TextRange.collapsed(1)),
        insert('안', 'ㄴ', 1, composing: compose12),
        replace('안ㄴ', compose12, '녀', composing: compose12),
        replace('안녀', compose12, '녕', composing: compose12),
        replace('안녕', compose12, '녕', composing: compose12),
        nonText('안녕', 2),
        nonText('안녕', 2, composing: const TextRange.collapsed(2)),
        insert('안녕', 'ㅎ', 2, composing: compose23),
        replace('안녕ㅎ', compose23, '하', composing: compose23),
        replace('안녕하', compose23, '핫', composing: compose23),
        replace('안녕핫', compose23, '하', composing: compose23),
        nonText('안녕하', 3),
        nonText('안녕하', 3, composing: const TextRange.collapsed(3)),
        insert('안녕하', '세', 3, composing: compose34),
        replace('안녕하세', compose34, '셍', composing: compose34),
        replace('안녕하셍', compose34, '세', composing: compose34),
        nonText('안녕하세', 4),
        nonText('안녕하세', 4, composing: const TextRange.collapsed(4)),
        insert('안녕하세', '요', 4, composing: compose45),
        replace('안녕하세요', compose45, '요', composing: compose45),
        nonText('안녕하세요', 5),
        insert('안녕하세요', '.', 5),
        insert('안녕하세요.', ' ', 6),
      ];
      for (final delta in deltas) {
        client.updateEditingValueWithDeltas(<TextEditingDelta>[delta]);
        await tester.pump();
      }

      expect(api.terminalWrites.map((write) => write.data).join(), '안녕하세요. ');
      expect(
        tester.testTextInput.log.where(
          (call) => call.method == 'TextInput.setEditingState',
        ),
        isEmpty,
        reason:
            'the Win32 embedder applies setEditingState destructively to '
            'its engine-side model; a mid-word reset corrupts the next '
            'syllable and duplicates preedit states into the PTY',
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
