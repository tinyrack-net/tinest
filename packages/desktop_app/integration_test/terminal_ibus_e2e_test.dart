@TestOn('linux')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app/testing/app/composition/app_services.dart';
import 'package:app/testing/app/tinest_app.dart';
import 'package:app/testing/features/hosts/domain/host_models.dart';
import 'package:app/testing/features/hosts/domain/host_ports.dart';
import 'package:app/testing/features/terminals/presentation/tinest_terminal_view.dart';
import 'package:app/testing/features/workspace/application/directory_picker_port.dart';
import 'package:client/client.dart';
import 'package:daemon/daemon.dart';
import 'package:desktop_app/src/embedded_daemon.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:termworld/termworld.dart';

import 'support/ephemeral_port.dart';
import 'support/pump_until.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'real IBus input and X clipboard paste reach the embedded PTY once',
    (tester) async {
      final daemonHome = await Directory.systemTemp.createTemp(
        'tinest-ibus-daemon-',
      );
      final userHome = await Directory.systemTemp.createTemp(
        'tinest-ibus-user-',
      );
      final workspace = await Directory.systemTemp.createTemp(
        'tinest-ibus-workspace-',
      );
      await _initializeGitRepository(workspace.path);
      const port = testEmbeddedDaemonPort;
      const token = 'ibus-e2e-token-0123456789abcdef0123456789';
      final config = DaemonConfig(
        homeDirectory: daemonHome.path,
        userHomeDirectory: userHome.path,
        osHomeDirectory: userHome.path,
        port: port,
        bearerToken: token,
        useEnvironmentCredentials: false,
      );
      final launcher = EphemeralEmbeddedDaemonLauncher(
        IsolateEmbeddedDaemonLauncher(resolveConfig: () => config),
      );
      Process? clipboard;
      addTearDown(() async {
        clipboard?.kill();
        await tester.pumpWidget(const SizedBox.shrink());
        for (final directory in <Directory>[daemonHome, userHome, workspace]) {
          if (directory.existsSync()) directory.deleteSync(recursive: true);
        }
      });

      const typed = '한글 abc 안녕 안녕하세요. ㅁㄴㅇㄻㄴㅇㄹ ';
      const expected =
          '$typed'
          '\u001bz붙여넣기 👩🏽\u200d💻1\u007f\u001b\u007f';
      final expectedBytes = utf8.encode(expected);
      final artifactDirectory =
          Platform.environment['TINYRACK_IBUS_ARTIFACT_DIR'];
      if (artifactDirectory != null) {
        Directory(artifactDirectory).createSync(recursive: true);
      }
      final capture = File(
        artifactDirectory == null
            ? '${workspace.path}/ibus-input.bin'
            : '$artifactDirectory/pty-input.bin',
      );
      final modeProbe = File('${workspace.path}/ibus-mode.bin');
      final modeReady = File('${workspace.path}/ibus-mode-ready');
      final ready = File('${workspace.path}/ibus-ready');
      final store = MemoryAppStore(
        settings: const AppSettings(embeddedDaemonPort: port),
      );
      await tester.pumpWidget(
        TinestApp(
          services: AppServices(
            settings: store,
            profiles: store,
            credentials: store,
            clients: const WebSocketHostClientFactory(),
            clientKind: 'ibus-desktop-integration-test',
            embeddedLauncher: launcher,
          ),
          directoryPicker: _FixedDirectoryPicker(workspace.path),
        ),
      );
      final daemonSession = await launcher.started;
      final setupClient = await _connectToDaemon(
        daemonSession.endpoint.websocketUri.port,
        daemonSession.credentials.bearerToken,
      );
      addTearDown(setupClient.close);
      final projectMenu = find.byKey(
        const ValueKey<String>('new-workspace-project'),
      );
      await pumpUntil(tester, projectMenu);
      await tester.tap(projectMenu);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('new-workspace-project-add')),
      );
      final sidebarCheckout = find.descendant(
        of: find.byKey(const ValueKey<String>('workspace-sidebar-tree')),
        matching: find.text('main'),
      );
      await _pumpUntilFinder(tester, sidebarCheckout, 'the Git checkout');
      await tester.ensureVisible(sidebarCheckout);
      await tester.pumpAndSettle();
      await tester.tap(sidebarCheckout);
      await tester.pumpAndSettle();
      final catalog = await setupClient.workspaces.getWorkspaceCatalog();
      final registered = catalog.workspaces.singleWhere(
        (item) => item.rootPath == workspace.path,
      );
      final checkout = catalog.worktrees.singleWhere(
        (item) => item.workspaceId == registered.id,
      );
      final newTabMenu = find.byKey(
        const ValueKey<String>('workspace-new-tab-menu'),
      );
      await pumpUntil(tester, newTabMenu);
      await tester.tap(newTabMenu);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-new-terminal')),
      );
      await _waitUntil(
        () async =>
            (await setupClient.terminals.listTerminals(checkout.id)).isNotEmpty,
        'Tinest to create the terminal through its real daemon',
      );
      final terminal = (await setupClient.terminals.listTerminals(checkout.id))
          .single;
      final terminalViewFinder = find
          .byKey(ValueKey<String>('terminal-view-${terminal.id}'))
          .hitTestable();
      await pumpUntil(tester, terminalViewFinder);
      final terminalView = tester.widget<TinestTerminalView>(
        terminalViewFinder,
      );
      const wrapReadyMarker = '__CODER_WRAP_PROBE_READY__';
      await setupClient.terminals.writeTerminal(
        terminal.id,
        "stty -echo; printf '\\r\\n$wrapReadyMarker\\r\\n'\r",
      );
      await _waitUntil(
        () =>
            _terminalRows(terminalView)
                .any((line) => line.contains(wrapReadyMarker)),
        'the shell to disable echo before the wrapped-row probe',
      );
      await tester.pumpAndSettle();
      // xterm crosses a soft-wrap boundary on Backspace only when the
      // terminal application enables DEC reverse-wrap mode.
      const reverseWrapPrefix = '\r\n\u001b[2K\u001b[?45h\u001b[999C\u001b[5D';
      const eraseAcrossWrap = 'WRAPQWxy\b \b\b \b\b \b\r\n';
      const wrappedProbe = '$reverseWrapPrefix$eraseAcrossWrap';
      final encodedWrappedProbe = base64Encode(utf8.encode(wrappedProbe));
      await setupClient.terminals.writeTerminal(
        terminal.id,
        r"printf '\033[?2004l'; stty raw -echo; "
        "printf '%s' '$encodedWrappedProbe' | base64 --decode; "
        ": > '${modeProbe.path}'; touch '${modeReady.path}'; "
        "dd bs=1 count=1 of='${modeProbe.path}' status=none; "
        ": > '${capture.path}'; touch '${ready.path}'; "
        "dd bs=1 count=${expectedBytes.length} of='${capture.path}' "
        'status=none; stty sane\r',
      );
      await _waitUntil(
        modeReady.existsSync,
        'the PTY mode probe to enter raw mode',
      );
      // Route replacement briefly leaves both pane surfaces mounted, so scope
      // the finder to the terminal created for this test.
      final terminalSurface = find
          .descendant(
            of: find.byKey(ValueKey<String>('terminal-view-${terminal.id}')),
            matching: find.byKey(const ValueKey<String>('tr-terminal-surface')),
          )
          .last;
      await tester.tap(terminalSurface);
      await tester.pumpAndSettle();
      await _waitForTerminalFocus(tester);

      final windowId = await _findWindow();
      await _run('xdotool', <String>['windowfocus', '--sync', windowId]);
      await _activateHangulEngineForFocusedWindow();
      await tester.pumpAndSettle();
      await _ensureHangulMode(modeProbe);
      await _waitUntil(
        ready.existsSync,
        'the PTY byte recorder to follow the mode probe',
      );
      await _waitForTerminalParsed(terminalView.terminal);
      final wrappedEraseObserved = await _waitForOptional(
        () => _terminalRows(terminalView)
            .any((line) => line.contains('WRAPQ') && !line.contains('WRAPQW')),
        const Duration(seconds: 15),
      );
      final terminalRows = _terminalRows(terminalView);
      expect(
        wrappedEraseObserved,
        isTrue,
        reason:
            'Expected Backspace to erase W across the WRAPQW '
            'soft-wrap boundary; rows=$terminalRows',
      );
      await _keys(<String>['g', 'k']);
      if (artifactDirectory != null) {
        await _run('scrot', <String>[
          '--overwrite',
          '$artifactDirectory/ime-preedit.png',
        ]);
      }
      await _keys(<String>[...'srmf'.split(''), 'space']);
      await _toggleLanguage();
      await _keys(<String>['a', 'b', 'c', 'space']);
      await _toggleLanguage();
      await _keys(<String>[...'dkssud'.split(''), 'space']);
      // ㅅ and ㅇ first land as the final consonant of the syllable in
      // progress and are redistributed into the next one. Each redistribution
      // settles a syllable and reopens the preedit in the same keystroke, so
      // the syllables must still reach the PTY in typed order.
      await _keys(<String>[...'dkssudgktpdy'.split(''), 'period', 'space']);
      // Bare consonants cannot start a syllable, so IBus commits each one as
      // the next arrives while the last stays in preedit until Space — except
      // ㄹ followed by ㅁ, which compose the cluster ㄻ. Every jamo must reach
      // the PTY as it commits — not all at once on the Space — and the Space
      // itself must be written exactly once.
      await _keys(<String>[...'asdfasdf'.split(''), 'space']);
      await _toggleLanguage();

      const pasted = '붙여넣기 👩🏽\u200d💻';
      clipboard = await _setClipboard(pasted);
      await _clickFinder(tester, windowId, terminalSurface, button: 3);
      await _keys(<String>['Escape']);
      await _waitForTerminalFocus(tester);
      await _keys(<String>['z']);
      await _waitUntil(
        () =>
            capture.existsSync() &&
            capture.lengthSync() >= utf8.encode('$typed\u001bz').length,
        'terminal input to resume after native-menu cancellation',
      );
      await _clickFinder(tester, windowId, terminalSurface, button: 3);
      final nativeMenuGesture = await tester.startGesture(
        tester.getTopLeft(terminalSurface) + const Offset(24, 24),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryButton,
      );
      await tester.pump(const Duration(milliseconds: 50));
      await nativeMenuGesture.up();
      await tester.pumpAndSettle();
      if (artifactDirectory != null) {
        final windows = await _run('xwininfo', <String>['-root', '-tree']);
        final pointer = await _run('xdotool', <String>['getmouselocation']);
        await File('$artifactDirectory/menu-window.txt')
            .writeAsString('${pointer.stdout}\n${windows.stdout}');
      }
      // Copy is disabled with no selection, so the first enabled native GTK
      // menu item reached by Down is Paste.
      await _keys(<String>['Down', 'Return']);
      // Activating Paste does not deliver the text. The clipboard owner is
      // another process, so GTK has to ask it for the selection and wait for
      // the answer, while the keystroke below goes straight through. Typing
      // without waiting races the two, and losing that race writes the same
      // bytes in the wrong order, with the digit ahead of the paste.
      await _waitUntil(
        () =>
            capture.existsSync() &&
            capture.lengthSync() >= utf8.encode('$typed\u001bz$pasted').length,
        'the pasted clipboard payload to reach the PTY',
      );
      await _keys(<String>['1', 'BackSpace']);
      await _chord(<String>['Alt_L'], 'BackSpace');

      // Waited for without failing on the wait itself, so a shortfall still
      // reaches the byte comparison below and its diagnostic hex dump.
      await _waitForOptional(
        () =>
            capture.existsSync() &&
            capture.lengthSync() == expectedBytes.length,
        const Duration(seconds: 15),
      );
      final actualBytes = capture.existsSync()
          ? capture.readAsBytesSync()
          : const <int>[];
      expect(
        actualBytes,
        expectedBytes,
        reason:
            'PTY bytes: ${actualBytes.map(_hex).join(' ')} '
            '(${utf8.decode(actualBytes, allowMalformed: true)})',
      );
    },
    tags: const <String>[
      'feature_test__terminal_lifecycle__e2e',
      'feature_test__terminal_lifecycle__platformSmoke',
      'feature_scenario__terminal_lifecycle__keyboard_context_menu_input__e2e',
    ],
  );
}

Future<TinestApi> _connectToDaemon(int port, String token) async {
  Object? lastError;
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    try {
      return await TinestClient.connect(
        endpoint: HostEndpoint.parse('127.0.0.1:$port'),
        credentials: DaemonCredentials(bearerToken: token),
        clientId: 'ibus-e2e-setup',
        clientKind: 'integration-test',
      );
    } on Exception catch (error) {
      lastError = error;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }
  throw TestFailure('Timed out connecting to embedded daemon: $lastError');
}

final class _FixedDirectoryPicker implements DirectoryPickerPort {
  const new(this.path);

  final String path;

  @override
  Future<String?> pickDirectory({String? initialDirectory}) async => path;
}

Future<void> _waitForTerminalFocus(WidgetTester tester) async {
  bool terminalHasFocus() {
    final context = FocusManager.instance.primaryFocus?.context;
    return context != null &&
        context.findAncestorWidgetOfExactType<TerminalView>() != null;
  }

  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!terminalHasFocus() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(terminalHasFocus(), isTrue);
}

Future<void> _pumpUntilFinder(
  WidgetTester tester,
  Finder finder,
  String description,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  final visibleText = tester
      .widgetList<Text>(find.byType(Text))
      .map((item) => item.data);
  expect(
    finder,
    findsWidgets,
    reason:
        'Timed out waiting for $description. Visible text: '
        '$visibleText',
  );
}

Future<String> _findWindow() async {
  final result = await _run('xdotool', <String>[
    'search',
    '--onlyvisible',
    '--class',
    r'^Net\.tinyrack\.tinest$',
  ]);
  final ids = result.stdout.toString().trim().split(RegExp(r'\s+'));
  return ids.single;
}

Future<void> _keys(List<String> keys) async {
  for (final key in keys) {
    await _run('xdotool', <String>[
      'keydown',
      '--clearmodifiers',
      key,
      'sleep',
      '0.04',
      'keyup',
      key,
    ]);
  }
}

Future<void> _toggleLanguage() async {
  await _run('xdotool', <String>[
    'keydown',
    '--clearmodifiers',
    'Shift_L',
    'sleep',
    '0.04',
    'keydown',
    'space',
    'sleep',
    '0.04',
    'keyup',
    'space',
    'keyup',
    'Shift_L',
  ]);
}

Future<void> _chord(List<String> modifiers, String key) async {
  final arguments = <String>['keydown', '--clearmodifiers'];
  for (final modifier in modifiers) {
    arguments.addAll(<String>[modifier, 'sleep', '0.04', 'keydown']);
  }
  arguments
    ..addAll(<String>[key, 'sleep', '0.04', 'keyup', key])
    ..addAll(<String>[
      for (final modifier in modifiers.reversed) ...<String>['keyup', modifier],
    ]);
  await _run('xdotool', arguments);
}

Future<void> _ensureHangulMode(File probe) async {
  await _keys(<String>['g']);
  final latin = await _waitForOptional(
    () => probe.existsSync() && probe.lengthSync() == 1,
    const Duration(seconds: 2),
  );
  if (latin) {
    expect(probe.readAsBytesSync(), utf8.encode('g'));
    // A newly-created GTK input context can start in the engine's Latin mode
    // even though `ibus engine` already reports `hangul`. Use the configured
    // physical switch chord here as well; the synthetic Hangul keysym is not a
    // reliable mode switch on GitHub-hosted X11 sessions.
    await _toggleLanguage();
    return;
  }

  await _keys(<String>['BackSpace']);
  await _toggleLanguage();
  await _keys(<String>['x']);
  await _waitUntil(
    () => probe.existsSync() && probe.lengthSync() == 1,
    'the Latin mode probe byte to reach the PTY',
  );
  expect(probe.readAsBytesSync(), utf8.encode('x'));
  await _toggleLanguage();
}

Future<void> _activateHangulEngineForFocusedWindow() async {
  final engines = await _run('ibus', <String>['list-engine']);
  const latinEngine = 'xkb:us::eng';
  expect(
    engines.stdout.toString(),
    contains(latinEngine),
    reason: 'The deterministic IBus Latin engine is unavailable',
  );
  await _run('ibus', <String>['engine', latinEngine]);

  await _waitUntil(() async {
    final selected = await Process.run('ibus', <String>['engine', 'hangul']);
    final current = await Process.run('ibus', <String>['engine']);
    return selected.exitCode == 0 &&
        current.exitCode == 0 &&
        current.stdout.toString().trim() == 'hangul';
  }, 'the focused GTK input context to activate IBus Hangul');
}

Future<Process> _setClipboard(String text) async {
  final process = await Process.start('xclip', <String>[
    '-selection',
    'clipboard',
    '-silent',
  ]);
  process.stdin.write(text);
  await process.stdin.close();
  await _waitUntil(() async {
    final read = await Process.run('xclip', <String>[
      '-selection',
      'clipboard',
      '-out',
    ]);
    return read.exitCode == 0 && read.stdout == text;
  }, 'the X clipboard owner to publish the paste payload');
  return process;
}

Future<void> _clickFinder(
  WidgetTester tester,
  String windowId,
  Finder finder, {
  int button = 1,
}) async {
  final geometry = await _run('xdotool', <String>[
    'getwindowgeometry',
    '--shell',
    windowId,
  ]);
  final values = <String, int>{};
  for (final line in geometry.stdout.toString().split('\n')) {
    final parts = line.split('=');
    if (parts.length == 2) values[parts.first] = int.tryParse(parts.last) ?? 0;
  }
  final logicalSize = tester.view.physicalSize / tester.view.devicePixelRatio;
  final center = tester.getCenter(finder);
  final x = (center.dx * values['WIDTH']! / logicalSize.width).round();
  final y = (center.dy * values['HEIGHT']! / logicalSize.height).round();
  await _run('xdotool', <String>[
    'windowfocus',
    '--sync',
    windowId,
    'mousemove',
    '--sync',
    '--window',
    windowId,
    x.toString(),
    y.toString(),
    'mousedown',
    button.toString(),
    'sleep',
    '0.10',
    'mouseup',
    button.toString(),
  ]);
  await tester.pumpAndSettle();
}

Future<void> _waitUntil(
  FutureOr<bool> Function() predicate,
  String description,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (!await predicate() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  expect(
    await predicate(),
    isTrue,
    reason: 'Timed out waiting for $description',
  );
}

Future<bool> _waitForOptional(
  bool Function() predicate,
  Duration timeout,
) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return predicate();
}

Future<void> _waitForTerminalParsed(Terminal terminal) async {
  final parsed = Completer<void>();
  // Terminal.write queues parser work. An empty write acts as a FIFO barrier,
  // so the buffer assertions below cannot race the preceding PTY output.
  terminal.write('', onParsed: parsed.complete);
  await parsed.future.timeout(const Duration(seconds: 15));
}

List<String> _terminalRows(TinestTerminalView view) {
  final buffer = view.terminal.buffer.active;
  return <String>[
    for (var index = 0; index < buffer.length; index++)
      buffer.getLine(index)!.translateToString(trimRight: true),
  ];
}

String _hex(int value) => value.toRadixString(16).padLeft(2, '0');

Future<void> _initializeGitRepository(String path) async {
  await _run('git', <String>['-C', path, 'init', '-b', 'main']);
  await File('$path/README.md').writeAsString('# IBus E2E fixture\n');
  await _run('git', <String>['-C', path, 'add', 'README.md']);
  await _run('git', <String>[
    '-C',
    path,
    '-c',
    'user.name=Tinest IBus E2E',
    '-c',
    'user.email=tinest-ibus-e2e@example.invalid',
    'commit',
    '-m',
    'Initial fixture',
  ]);
}

Future<ProcessResult> _run(String executable, List<String> arguments) async {
  final result = await Process.run(executable, arguments);
  if (result.exitCode != 0) {
    throw ProcessException(
      executable,
      arguments,
      '${result.stdout}\n${result.stderr}',
      result.exitCode,
    );
  }
  return result;
}
