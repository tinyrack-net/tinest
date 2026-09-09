@Tags(<String>['feature_test__terminal_lifecycle__unit'])
library;

import 'dart:async';

import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/features/terminals/application/terminal_session_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;
import 'package:termworld/termworld.dart';

import '../../support/fake_tinest_api.dart';

const _terminal = TerminalDto(
  id: 'terminal-1',
  worktreeId: 'checkout',
  title: 'Terminal 1',
  shell: ShellSpecDto(executable: '/bin/sh'),
  status: TerminalStatus.running,
  columns: 80,
  rows: 24,
  lastSequence: 0,
);

/// Everything the emulator holds, scrollback included.
String _screen(Terminal terminal) {
  final buffer = terminal.buffer.active;
  return <String>[
    for (var line = 0; line < buffer.length; line += 1)
      buffer.translateBufferLineToString(line, trimRight: true),
  ].join('\n');
}

/// Lets pending microtasks and the emulator's write buffer drain.
Future<void> _settle() async {
  for (var turn = 0; turn < 4; turn += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

({ProviderContainer container, FakeTinestApi api}) _harness({
  Exception? attachError,
}) {
  final api = FakeTinestApi(
    terminals: const <TerminalDto>[_terminal],
    terminalAttachError: attachError,
  );
  final container = ProviderContainer(
    overrides: <Override>[
      appServicesProvider.overrideWithValue(fakeAppServices(api)),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, api: api);
}

Future<TerminalSessionState> _session(ProviderContainer container) async {
  final provider = terminalSessionControllerProvider('server', _terminal.id);
  container.listen(provider, (_, _) {});
  await _settle();
  return await container.read(provider);
}

void main() {
  test('the emulator identity survives repeated reads', () async {
    final harness = _harness();
    final first = await _session(harness.container);
    final second = harness.container.read(
      terminalSessionControllerProvider('server', _terminal.id),
    );

    expect(identical(first.terminal, second.terminal), isTrue);
    expect(first.status, TerminalSessionStatus.live);
  });

  test('replay and live output merge on one monotonic sequence', () async {
    final harness = _harness();
    harness.api.emitTerminalOutput(_terminal.id, 'replayed');
    final session = await _session(harness.container);
    harness.api.emitTerminalOutput(_terminal.id, 'live');
    await _settle();

    final screen = _screen(session.terminal);
    expect('replayed'.allMatches(screen), hasLength(1));
    expect('live'.allMatches(screen), hasLength(1));
  });

  test(
    'a chunk published during the attach round trip is applied once',
    () async {
      final harness = _harness();
      final gate = Completer<void>();
      harness.api.terminalAttachGate = gate;
      final provider = terminalSessionControllerProvider(
        'server',
        _terminal.id,
      );
      harness.container.listen(provider, (_, _) {});
      await _settle();

      // The daemon has already snapshotted its replay, so this chunk can only
      // reach a subscription that was created before the call went out.
      harness.api.emitTerminalOutput(_terminal.id, 'mid-attach');
      gate.complete();
      await _settle();

      final session = harness.container.read(provider);
      expect('mid-attach'.allMatches(_screen(session.terminal)), hasLength(1));
      expect(session.status, TerminalSessionStatus.live);
    },
  );

  test(
    'the first attach adopts the daemon geometry without echoing it',
    () async {
      final harness = _harness();
      final session = await _session(harness.container);

      expect(session.terminal.cols, _terminal.columns);
      expect(session.terminal.rows, _terminal.rows);
      expect(harness.api.terminalResizes, isEmpty);
    },
  );

  test('a viewport resize is forwarded to the daemon once', () async {
    final harness = _harness();
    final session = await _session(harness.container);
    session.terminal.resize(100, 30);
    await _settle();
    session.terminal.resize(100, 30);
    await _settle();

    expect(
      harness.api.terminalResizes,
      <({String terminalId, int columns, int rows})>[
        (terminalId: _terminal.id, columns: 100, rows: 30),
      ],
    );
  });

  test('input reaches the daemon through the session', () async {
    final harness = _harness();
    final session = await _session(harness.container);
    session.terminal.input('ls');
    await _settle();

    expect(
      harness.api.terminalWrites.map((write) => write.terminalId),
      contains(_terminal.id),
    );
  });

  test('a failed attach reports itself and recovers on retry', () async {
    final harness = _harness(attachError: Exception('host unreachable'));
    final provider = terminalSessionControllerProvider('server', _terminal.id);
    harness.container.listen(provider, (_, _) {});
    await _settle();

    var session = harness.container.read(provider);
    expect(session.status, TerminalSessionStatus.failed);
    expect('${session.error}', contains('host unreachable'));

    harness.api.terminalAttachError = null;
    harness.api.emitTerminalOutput(_terminal.id, 'after-retry');
    harness.container.read(provider.notifier).retry();
    await _settle();

    session = harness.container.read(provider);
    expect(session.status, TerminalSessionStatus.live);
    // The retry keeps the emulator, so the replay lands in the terminal the
    // failed attempt already handed to the pane.
    expect(_screen(session.terminal), contains('after-retry'));
  });

  test('a cold attach asks for a screen and claims no size', () async {
    final harness = _harness();
    await _session(harness.container);

    final request = harness.api.attachedTerminalRequests.single;
    expect(request.mode, TerminalRestoreMode.snapshot);
    expect(request.afterSequence, 0);
    // Nothing about mounting a pane says the user resized anything.
    expect(request.viewport, isNull);
  });

  test('a snapshot restore resets the emulator before painting', () async {
    final harness = _harness()
      ..api.terminalSnapshotAnsi['terminal-1'] =
          '\u001b[?1049h\u001b[Hrestored-alt-screen';
    harness.api.emitTerminalOutput(_terminal.id, 'stale-before-restore');
    final session = await _session(harness.container);

    final screen = _screen(session.terminal);
    expect(screen, contains('restored-alt-screen'));
    // The daemon's screen is the whole truth; anything the emulator held
    // before it would otherwise stack underneath.
    expect(screen, isNot(contains('stale-before-restore')));
  });

  test('a resume the daemon cannot serve falls back to a screen', () async {
    final harness = _harness();
    harness.api
      ..emitTerminalOutput(_terminal.id, 'first')
      ..terminalDeltaFloors[_terminal.id] = 5
      ..terminalSnapshotAnsi[_terminal.id] = 'rebuilt';
    final session = await _session(harness.container);

    // The client asked to resume; the daemon answered with a screen because it
    // no longer retains that far back, and the client has to accept either.
    expect(_screen(session.terminal), contains('rebuilt'));
  });

  test('a restore does not type its own replies into the shell', () async {
    final harness = _harness();
    // Device Attributes: a real snapshot carries whatever the session had on
    // screen, and a program that queried the terminal leaves such a sequence
    // in it. The emulator answers on `onData`, and that answer is not
    // something the user typed.
    harness.api.terminalSnapshotAnsi[_terminal.id] = 'restored\u001b[c';
    harness.api.emitTerminalOutput(_terminal.id, 'seed');
    final session = await _session(harness.container);

    expect(_screen(session.terminal), contains('restored'));
    expect(harness.api.terminalWrites, isEmpty);

    // The barrier lifts once the restore has been parsed, so ordinary typing
    // still reaches the daemon afterwards.
    session.terminal.input('ls');
    await _settle();
    expect(
      harness.api.terminalWrites.map((write) => write.data),
      contains('ls'),
    );
  });

  test('a reconnect carries the size the user last claimed', () async {
    final harness = _harness();
    final session = await _session(harness.container);

    // A genuine viewport change is a claim; adopting the daemon's geometry on
    // attach is not, which is why the first attach sent none.
    session.terminal.resize(100, 30);
    await _settle();
    expect(harness.api.attachedTerminalRequests.single.viewport, isNull);

    harness.container
        .read(
          terminalSessionControllerProvider('server', _terminal.id).notifier,
        )
        .retry();
    await _settle();

    final reattach = harness.api.attachedTerminalRequests.last;
    expect(reattach.viewport?.columns, 100);
    expect(reattach.viewport?.rows, 30);
    // The claim travels with the attach instead of racing it, so the daemon
    // has applied it before it builds anything.
    expect(harness.api.terminalResizes, hasLength(1));
  });

  test('adopting the daemon geometry never claims it back', () async {
    final harness = _harness();
    // The daemon reports a size this session never asked for, the way it would
    // after another client resized the same terminal.
    harness.api.resizeTerminalDirectly(_terminal.id, columns: 132, rows: 43);
    final session = await _session(harness.container);

    expect(session.terminal.cols, 132);
    expect(session.terminal.rows, 43);
    expect(
      harness.api.terminalResizes,
      isEmpty,
      reason: 'adopting a size is not claiming it',
    );
  });

  test('disposing the session stops writing into the emulator', () async {
    final harness = _harness();
    final session = await _session(harness.container);
    harness.container.invalidate(
      terminalSessionControllerProvider('server', _terminal.id),
    );
    await _settle();

    // A disposed emulator throws if anything still writes to it, so a chunk
    // arriving after teardown proves the subscription is gone.
    harness.api.emitTerminalOutput(_terminal.id, 'after-dispose');
    await _settle();
    expect(_screen(session.terminal), isNot(contains('after-dispose')));
  });
}
