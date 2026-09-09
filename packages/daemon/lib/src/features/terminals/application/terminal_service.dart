import 'dart:async';
import 'dart:convert';

import 'package:daemon/src/features/terminals/application/terminal_screen.dart';
import 'package:daemon/src/features/terminals/domain/terminal.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';

/// Running pseudo-terminal process boundary.
abstract interface class TerminalProcess implements ExecProcess {
  /// Changes the PTY character-cell dimensions.
  Future<void> resize(int columns, int rows);
}

/// Starts interactive terminal processes.
abstract interface class TerminalGateway {
  /// Starts a shell in a working directory.
  Future<TerminalProcess> start({
    required TerminalShell shell,
    required String workingDirectory,
    required int columns,
    required int rows,
  });
}

/// Resolves an active worktree to its checkout path.
typedef WorktreePathResolver = Future<String> Function(String worktreeId);

/// Resolves the effective project, host, or OS shell.
typedef ShellResolver = Future<TerminalShell> Function(String worktreeId);

/// Expected reason a terminal could not be created.
enum TerminalCreationFailureReason {
  /// The selected worktree no longer resolves to a live directory.
  worktreeUnavailable,

  /// The resolved shell could not be started by the platform PTY.
  startFailed,
}

/// Sanitized application failure raised before a terminal becomes live.
final class TerminalCreationException implements Exception {
  /// Creates a typed terminal creation failure.
  const new(this.reason, this.message);

  /// Stable reason translated by the transport boundary.
  final TerminalCreationFailureReason reason;

  /// User-safe diagnostic supplied to the client.
  final String message;

  @override
  String toString() => 'TerminalCreationException(${reason.name}): $message';
}

/// Owns live terminals, their screens, and a short output tail.
final class TerminalService {
  /// Creates a terminal service around injected host boundaries.
  new({
    required this.gateway,
    required this.screens,
    required this.worktreePath,
    required this.shellFor,
    this.maxDeltaBytes = 256 * 1024,
    this.scrollbackLines = 200,
  });

  /// Host PTY boundary.
  final TerminalGateway gateway;

  /// Screen models mirroring each PTY.
  final TerminalScreenFactory screens;

  /// Active worktree path resolver.
  final WorktreePathResolver worktreePath;

  /// Effective shell resolver.
  final ShellResolver shellFor;

  /// UTF-8 bytes of recent output retained per terminal.
  ///
  /// This covers a short gap, not a session: a client that reconnects seconds
  /// later should resume the byte stream rather than repaint. Anything larger
  /// is faster to serve as a screen than to replay, and the screen is the only
  /// answer that is correct once the tail has been trimmed at all.
  final int maxDeltaBytes;

  /// Retained rows a rebuilt screen can carry.
  ///
  /// This is the cold-restore floor, not what a user sees: a live emulator
  /// keeps everything it received. Each retained row is a list of per-cell
  /// objects, so this is also the dominant term in a terminal's memory.
  final int scrollbackLines;
  final Map<String, _LiveTerminal> _terminals = <String, _LiveTerminal>{};
  final StreamController<Object> _events = StreamController<Object>.broadcast(
    sync: true,
  );

  /// Emits [Terminal] and [TerminalOutput] changes.
  Stream<Object> get events => _events.stream;

  /// Lists live and exited terminals for one worktree.
  List<Terminal> list(String worktreeId) => _terminals.values
      .where((item) => item.dto.worktreeId == worktreeId)
      .map((item) => item.dto)
      .toList(growable: false);

  /// Starts a new interactive terminal.
  Future<Terminal> create({
    required String id,
    required String worktreeId,
    required String title,
    required int columns,
    required int rows,
  }) async {
    if (_terminals.containsKey(id)) {
      throw const FormatException('Terminal ID already exists.');
    }
    if (columns <= 0 || rows <= 0) {
      throw const FormatException('Terminal dimensions must be positive.');
    }
    final shell = await shellFor(worktreeId);
    if (shell.executable.trim().isEmpty) {
      throw const FormatException('Shell executable must not be empty.');
    }
    final String workingDirectory;
    try {
      workingDirectory = await worktreePath(worktreeId);
    } on FormatException {
      throw const TerminalCreationException(
        TerminalCreationFailureReason.worktreeUnavailable,
        'The worktree directory is no longer available.',
      );
    }
    final process = await gateway.start(
      shell: shell,
      workingDirectory: workingDirectory,
      columns: columns,
      rows: rows,
    );
    final terminal = _LiveTerminal(
      process: process,
      screen: screens.create(
        columns: columns,
        rows: rows,
        scrollbackLines: scrollbackLines,
      ),
      dto: Terminal(
        id: id,
        worktreeId: worktreeId,
        title: title,
        shell: shell,
        status: TerminalLifecycle.running,
        columns: columns,
        rows: rows,
        lastSequence: 0,
      ),
    );
    _terminals[id] = terminal;
    process.outputs.listen(
      (data) => _record(terminal, data),
      onError: (Object error, StackTrace _) => _fail(terminal, error),
    );
    unawaited(
      process.exitCode.then((code) {
        terminal.dto = terminal.dto.copyWith(
          status: TerminalLifecycle.exited,
          exitCode: code,
        );
        _events.add(terminal.dto);
      }),
    );
    _events.add(terminal.dto);
    return terminal.dto;
  }

  /// Brings an attaching client up to date.
  ///
  /// A viewport claim is applied before anything is read, so whatever the
  /// restore describes is already at the geometry the caller asked for.
  Future<TerminalRestore> attach(
    String id,
    TerminalRestoreRequest request,
  ) async {
    final terminal = _require(id);
    if (request.viewport case final size?
        when size.columns != terminal.dto.columns ||
            size.rows != terminal.dto.rows) {
      await resize(id, columns: size.columns, rows: size.rows);
    }
    final resumable =
        request.strategy == TerminalRestoreStrategy.resume &&
        request.afterSequence >= terminal.deltaFloor &&
        request.afterSequence <= terminal.dto.lastSequence;
    if (resumable) {
      return TerminalDeltaRestore(
        terminal: terminal.dto,
        afterSequence: request.afterSequence,
        chunks: terminal.delta
            .where((item) => item.sequence > request.afterSequence)
            .toList(growable: false),
      );
    }
    // Let the queued chunks finish parsing, then read the grid and its
    // watermark together. Nothing can land between the two: serializing is
    // synchronous, so no feed continuation runs in the gap.
    await terminal.screenTail;
    final throughSequence = terminal.screenSequence;
    return TerminalSnapshotRestore(
      terminal: terminal.dto,
      throughSequence: throughSequence,
      ansi: terminal.screen.snapshot(
        scrollbackLines: request.scrollbackLines.clamp(0, scrollbackLines),
      ),
    );
  }

  /// Writes input to one terminal.
  Future<void> write(String id, String data) =>
      _require(id).process.write(data);

  /// Resizes one terminal.
  Future<Terminal> resize(
    String id, {
    required int columns,
    required int rows,
  }) async {
    if (columns <= 0 || rows <= 0) {
      throw const FormatException('Terminal dimensions must be positive.');
    }
    final terminal = _require(id);
    await terminal.process.resize(columns, rows);
    terminal.screen.resize(columns, rows);
    terminal.dto = terminal.dto.copyWith(columns: columns, rows: rows);
    _events.add(terminal.dto);
    return terminal.dto;
  }

  /// Terminates one terminal.
  Future<void> terminate(String id) => _require(id).process.terminate();

  /// Terminates every owned PTY and closes the event stream.
  Future<void> close() async {
    await Future.wait(
      _terminals.values.map((terminal) => terminal.process.terminate()),
    );
    for (final terminal in _terminals.values) {
      terminal.screen.dispose();
    }
    await _events.close();
  }

  void _record(_LiveTerminal terminal, String data) {
    final sequence = terminal.dto.lastSequence + 1;
    // Parsing is asynchronous — a custom sequence handler may be — so the
    // screen trails the counter. Chaining keeps chunks in order and records
    // how far the grid has actually got, which is the watermark a snapshot is
    // labelled with.
    terminal
      ..dto = terminal.dto.copyWith(lastSequence: sequence)
      ..screenTail = terminal.screenTail.then((_) async {
        await terminal.screen.feed(data);
        terminal.screenSequence = sequence;
      })
      ..delta.add(
        TerminalOutput(
          terminalId: terminal.dto.id,
          sequence: sequence,
          data: data,
        ),
      )
      ..deltaBytes += utf8.encode(data).length;
    // `deltaBytes` is carried across chunks rather than recomputed above:
    // re-measuring the whole buffer per chunk once the budget is reached
    // blocks this isolate on a single burst of PTY reads and stalls every
    // other request with it.
    //
    // Whole chunks only. Slicing one to make the budget exact used to matter
    // when this buffer was how a screen got rebuilt; now that a screen model
    // does that, a partial chunk would just be a stream starting mid-escape.
    while (terminal.deltaBytes > maxDeltaBytes && terminal.delta.length > 1) {
      final dropped = terminal.delta.removeAt(0);
      terminal
        ..deltaBytes -= utf8.encode(dropped.data).length
        ..deltaFloor = dropped.sequence;
    }
    _events.add(terminal.delta.last);
  }

  void _fail(_LiveTerminal terminal, Object error) {
    terminal.dto = terminal.dto.copyWith(
      status: TerminalLifecycle.failed,
      error: error.toString(),
    );
    _events.add(terminal.dto);
  }

  _LiveTerminal _require(String id) {
    final terminal = _terminals[id];
    if (terminal == null) throw const FormatException('Terminal not found.');
    return terminal;
  }
}

final class _LiveTerminal {
  new({required this.process, required this.screen, required this.dto});
  final TerminalProcess process;

  /// Parsed mirror of everything this terminal has emitted.
  final TerminalScreen screen;
  Terminal dto;

  /// Recent output, newest last, bounded by [TerminalService.maxDeltaBytes].
  final List<TerminalOutput> delta = <TerminalOutput>[];

  /// UTF-8 bytes currently held in [delta].
  int deltaBytes = 0;

  /// Highest sequence whose bytes have been dropped from [delta].
  ///
  /// A client whose cursor is at or below this cannot be served a resume; the
  /// bytes it is missing are gone, and handing it the remainder would replay a
  /// stream that starts mid-escape.
  int deltaFloor = 0;

  /// Highest sequence the screen has finished parsing.
  int screenSequence = 0;

  /// Completes when every chunk fed so far has been parsed.
  Future<void> screenTail = Future<void>.value();
}
