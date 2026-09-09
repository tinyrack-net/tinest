import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:daemon/src/features/terminals/application/terminal_screen.dart';
import 'package:daemon/src/features/terminals/application/terminal_service.dart';
import 'package:daemon/src/features/terminals/domain/terminal.dart';
import 'package:test/test.dart';

void main() {
  test(
    'terminal keeps bounded ordered output and survives client detach',
    () async {
      final process = _FakeTerminalProcess();
      final screens = _FakeTerminalScreenFactory();
      final service = TerminalService(
        gateway: _FakeTerminalGateway(process),
        screens: screens,
        worktreePath: (id) async => '/worktrees/$id',
        shellFor: (id) async => const TerminalShell(executable: '/bin/zsh'),
        maxDeltaBytes: 8,
      );

      final created = await service.create(
        id: 'terminal-1',
        worktreeId: 'worktree-1',
        title: 'Terminal 1',
        columns: 80,
        rows: 24,
      );
      expect(created.status, TerminalLifecycle.running);
      expect(process.workingDirectory, '/worktrees/worktree-1');

      process.output.add('12345');
      process.output.add('67890');
      await pumpEventQueue();
      // The tail is over its eight-byte budget, so the first chunk is dropped
      // whole. What is left is a chunk-aligned suffix, never a stream that
      // starts mid-escape.
      final attached = await service.attach(
        'terminal-1',
        const TerminalRestoreRequest(
          strategy: TerminalRestoreStrategy.resume,
          afterSequence: 1,
        ),
      );
      expect(
        (attached as TerminalDeltaRestore).chunks
            .map((item) => item.data)
            .join(),
        '67890',
      );
      expect(attached.terminal.lastSequence, 2);

      // The bytes that cursor is missing are gone, so a resume cannot be
      // honoured and the daemon answers with its screen instead. This is the
      // case that used to hand back a mutilated byte stream.
      final rebuilt = await service.attach(
        'terminal-1',
        const TerminalRestoreRequest(strategy: TerminalRestoreStrategy.resume),
      );
      expect(rebuilt, isA<TerminalSnapshotRestore>());
      expect(
        (rebuilt as TerminalSnapshotRestore).ansi,
        'screen:1234567890',
        reason: 'the screen has parsed every chunk, dropped or not',
      );
      expect(rebuilt.throughSequence, 2);

      process.output.add('가나다');
      await pumpEventQueue();
      final unicodeReplay = await service.attach(
        'terminal-1',
        const TerminalRestoreRequest(
          strategy: TerminalRestoreStrategy.resume,
          afterSequence: 2,
        ),
      );
      expect(
        (unicodeReplay as TerminalDeltaRestore).chunks.single.data,
        '가나다',
        reason: 'a chunk is retained whole or not at all',
      );

      await service.write('terminal-1', 'echo hi\r');
      await service.resize('terminal-1', columns: 120, rows: 40);
      expect(process.input, <String>['echo hi\r']);
      expect(process.sizes, <(int, int)>[(120, 40)]);
      // The screen has to follow the PTY, or the grid it serializes reflows
      // the moment a client adopts the real geometry.
      expect(screens.single.columns, 120);
      expect(screens.single.rows, 40);

      await service.terminate('terminal-1');
      expect(process.terminated, isTrue);
      await service.close();
      expect(screens.single.disposed, isTrue);
    },
    tags: const <String>['feature_test__terminal_lifecycle__unit'],
  );

  test(
    'the retained tail stays a whole-chunk suffix and records its floor',
    () async {
      const maxDeltaBytes = 512;
      final process = _FakeTerminalProcess();
      final screens = _FakeTerminalScreenFactory();
      final service = TerminalService(
        gateway: _FakeTerminalGateway(process),
        screens: screens,
        worktreePath: (id) async => '/worktrees/$id',
        shellFor: (id) async => const TerminalShell(executable: '/bin/zsh'),
        maxDeltaBytes: maxDeltaBytes,
      );
      addTearDown(service.close);
      await service.create(
        id: 'terminal-1',
        worktreeId: 'worktree-1',
        title: 'Terminal 1',
        columns: 80,
        rows: 24,
      );

      // A fixed seed keeps the mix of chunk lengths and of one- and
      // three-byte codepoints reproducible across runs.
      final random = Random(20260806);
      final chunks = <String>[];
      for (var i = 0; i < 400; i++) {
        final chunk = String.fromCharCodes(<int>[
          for (var j = 0; j < 1 + random.nextInt(40); j++) ...<int>[
            if (random.nextBool()) 0x61 + random.nextInt(26) else 0xAC00 + j,
          ],
        ]);
        chunks.add(chunk);
        process.output.add(chunk);
        await pumpEventQueue(times: 1);

        final restore = await service.attach(
          'terminal-1',
          const TerminalRestoreRequest(
            strategy: TerminalRestoreStrategy.resume,
            afterSequence: 1,
          ),
        );
        if (restore is! TerminalDeltaRestore) {
          // Once the floor passes the cursor the only correct answer is the
          // screen, and the screen has everything.
          expect(
            (restore as TerminalSnapshotRestore).ansi,
            'screen:${chunks.join()}',
            reason: 'the screen fell behind the stream after chunk $i',
          );
          continue;
        }
        // Trimming only drops from the front, and only whole chunks, so what
        // is retained is a chunk-aligned suffix of what the program wrote.
        expect(
          restore.chunks.map((chunk) => chunk.data).toList(),
          chunks.sublist(chunks.length - restore.chunks.length),
          reason: 'the tail drifted from the stream after chunk $i',
        );
        expect(
          utf8.encode(restore.chunks.map((chunk) => chunk.data).join()).length,
          lessThanOrEqualTo(maxDeltaBytes + 40 * 3),
          reason: 'the budget stopped bounding the tail after chunk $i',
        );
      }
    },
    tags: const <String>['feature_test__terminal_lifecycle__unit'],
  );

  test(
    'recording output costs the same once the replay budget is full',
    () async {
      final process = _FakeTerminalProcess();
      final screens = _FakeTerminalScreenFactory();
      final service = TerminalService(
        gateway: _FakeTerminalGateway(process),
        screens: screens,
        worktreePath: (id) async => '/worktrees/$id',
        shellFor: (id) async => const TerminalShell(executable: '/bin/zsh'),
      );
      await service.create(
        id: 'terminal-1',
        worktreeId: 'worktree-1',
        title: 'Terminal 1',
        columns: 80,
        rows: 24,
      );

      // A terminal that has produced its megabyte of scrollback must not cost
      // more per chunk than a fresh one. Accounting that rescans the buffer
      // makes this quadratic: it blocks the daemon isolate for hundreds of
      // milliseconds per PTY read burst, which stalls every other request.
      // The bound is deliberately far above the constant-time cost so that a
      // slow machine cannot fail it; only a return to rescanning can.
      // Wide enough that the default megabyte budget fills within the first
      // few thousand chunks, so most of the run measures the steady state.
      final chunk = '${'terminal output line' * 12}\r\n';
      final watch = Stopwatch()..start();
      for (var i = 0; i < 20000; i++) {
        process.output.add(chunk);
        await pumpEventQueue(times: 1);
      }
      watch.stop();

      expect(watch.elapsed, lessThan(const Duration(seconds: 15)));

      await service.terminate('terminal-1');
    },
    timeout: const Timeout(Duration(minutes: 3)),
    tags: const <String>['feature_test__terminal_lifecycle__unit'],
  );

  test('missing worktree paths fail with a typed creation reason', () async {
    final service = TerminalService(
      gateway: _FakeTerminalGateway(_FakeTerminalProcess()),
      screens: _FakeTerminalScreenFactory(),
      worktreePath: (_) async => throw const FormatException('missing'),
      shellFor: (_) async => const TerminalShell(executable: '/bin/sh'),
    );

    await expectLater(
      service.create(
        id: 'terminal-1',
        worktreeId: 'missing',
        title: 'Terminal 1',
        columns: 80,
        rows: 24,
      ),
      throwsA(
        isA<TerminalCreationException>().having(
          (error) => error.reason,
          'reason',
          TerminalCreationFailureReason.worktreeUnavailable,
        ),
      ),
    );
  }, tags: const <String>['feature_test__terminal_lifecycle__unit']);

  test('attaching claims a size only when the client asked it to', () async {
    final process = _FakeTerminalProcess();
    final screens = _FakeTerminalScreenFactory();
    final service = TerminalService(
      gateway: _FakeTerminalGateway(process),
      screens: screens,
      worktreePath: (id) async => '/worktrees/$id',
      shellFor: (id) async => const TerminalShell(executable: '/bin/sh'),
    );
    addTearDown(service.close);
    await service.create(
      id: 'terminal-1',
      worktreeId: 'worktree-1',
      title: 'Terminal',
      columns: 80,
      rows: 24,
    );

    // Attaching, on its own, is passive: a pane that remounted at the same
    // size or a client that reconnected has claimed nothing, and a size it
    // did not ask for would fight every other attached client.
    await service.attach(
      'terminal-1',
      const TerminalRestoreRequest(strategy: TerminalRestoreStrategy.resume),
    );
    expect(process.sizes, isEmpty);

    final resized = await service.attach(
      'terminal-1',
      const TerminalRestoreRequest(
        strategy: TerminalRestoreStrategy.resume,
        viewport: TerminalViewport(columns: 100, rows: 30),
      ),
    );
    // The claim lands before the restore is read, so what the caller gets
    // back already describes the geometry it asked for.
    expect(process.sizes, <(int, int)>[(100, 30)]);
    expect(resized.terminal.columns, 100);
    expect(resized.terminal.rows, 30);

    await service.attach(
      'terminal-1',
      const TerminalRestoreRequest(
        strategy: TerminalRestoreStrategy.resume,
        viewport: TerminalViewport(columns: 100, rows: 30),
      ),
    );
    expect(
      process.sizes,
      hasLength(1),
      reason: 'an unchanged size is not a claim',
    );
  }, tags: const <String>['feature_test__terminal_lifecycle__unit']);
}

final class _FakeTerminalScreenFactory implements TerminalScreenFactory {
  final List<_FakeTerminalScreen> created = <_FakeTerminalScreen>[];

  _FakeTerminalScreen get single => created.single;

  @override
  TerminalScreen create({
    required int columns,
    required int rows,
    required int scrollbackLines,
  }) {
    final screen = _FakeTerminalScreen(
      columns: columns,
      rows: rows,
      scrollbackLines: scrollbackLines,
    );
    created.add(screen);
    return screen;
  }
}

/// Records what the service asks of a screen, in the order it asks.
///
/// The emulator's own behaviour is `vtworld`'s to prove; what matters here is
/// the policy around it — which restore is chosen, and that a size claim lands
/// before anything is serialized.
final class _FakeTerminalScreen implements TerminalScreen {
  new({
    required this.columns,
    required this.rows,
    required this.scrollbackLines,
  });

  int columns;
  int rows;
  final int scrollbackLines;
  final StringBuffer fed = StringBuffer();
  final List<String> calls = <String>[];
  bool disposed = false;

  @override
  Future<void> feed(String data) async {
    calls.add('feed');
    fed.write(data);
  }

  @override
  void resize(int nextColumns, int nextRows) {
    calls.add('resize');
    columns = nextColumns;
    rows = nextRows;
  }

  @override
  String snapshot({required int scrollbackLines}) {
    calls.add('snapshot($scrollbackLines)');
    return 'screen:$fed';
  }

  @override
  void dispose() => disposed = true;
}

final class _FakeTerminalGateway implements TerminalGateway {
  new(this.process);
  final _FakeTerminalProcess process;

  @override
  Future<TerminalProcess> start({
    required TerminalShell shell,
    required String workingDirectory,
    required int columns,
    required int rows,
  }) async {
    process.workingDirectory = workingDirectory;
    return process;
  }
}

final class _FakeTerminalProcess implements TerminalProcess {
  final output = StreamController<String>();
  final input = <String>[];
  final sizes = <(int, int)>[];
  final exit = Completer<int>();
  String? workingDirectory;
  bool terminated = false;

  @override
  Stream<String> get outputs => output.stream;
  @override
  Future<int> get exitCode => exit.future;
  @override
  Future<void> write(String data) async => input.add(data);
  @override
  Future<void> interrupt() async => input.add(String.fromCharCode(0x03));
  @override
  Future<void> resize(int columns, int rows) async =>
      sizes.add((columns, rows));
  @override
  Future<void> terminate() async {
    if (terminated) return;
    terminated = true;
    if (!exit.isCompleted) exit.complete(0);
    await output.close();
  }
}
