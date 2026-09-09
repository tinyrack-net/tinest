import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:agent/agent.dart';
import 'package:daemon/src/features/terminals/application/terminal_service.dart';
import 'package:daemon/src/features/terminals/domain/terminal.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:protocol/protocol.dart';

/// How long an untouched pseudo-terminal is kept before it is reclaimed.
const Duration execSessionIdleTimeout = Duration(minutes: 30);

/// How many pseudo-terminals one tinest session may hold at once.
const int maxExecSessionsPerSession = 8;

/// Maximum unread UTF-8 output retained by one process handle.
const int maxExecSessionOutputBytes = 1024 * 1024;

/// Owns every agent-driven pseudo-terminal on this daemon.
///
/// Built on [TerminalGateway] rather than the PTY package directly, so the
/// native terminal stays confined to its one adapter and this service can be
/// tested against the same fake gateway the interactive terminals use.
class ExecSessionService {
  /// Creates an [ExecSessionService].
  new({
    required this._gateway,
    required this._pipes,
    required this._clock,
    bool? isWindows,
  }) : isWindows = isWindows ?? Platform.isWindows;

  final TerminalGateway _gateway;
  final PipeGateway _pipes;
  final Clock _clock;

  /// Whether the host uses PowerShell, injected so tests stay deterministic.
  final bool isWindows;

  final Map<int, _LiveExecSession> _sessions = <int, _LiveExecSession>{};
  final Set<int> _approved = <int>{};
  int _nextSessionId = 0;

  /// Live sessions, newest last, owned by [owner].
  List<_LiveExecSession> _ownedBy(String owner) =>
      _sessions.values.where((session) => session.owner == owner).toList()
        ..sort((left, right) => left.lastUsed.compareTo(right.lastUsed));

  /// Starts [command] for the tinest session [owner].
  ///
  /// [tty] chooses between a pseudo-terminal and plain pipes. Pipes are the
  /// ordinary case; a terminal is what a REPL or a full-screen tool needs.
  Future<ExecSession> start({
    required String owner,
    required String command,
    required String workingDirectory,
    required bool tty,
    String? requestedShell,
    bool login = true,
  }) async {
    sweepIdle();
    final existing = _ownedBy(owner);
    if (existing.length >= maxExecSessionsPerSession) {
      // Reclaim the least recently used rather than refusing: the model has no
      // way to know how many it left behind.
      await _terminate(existing.first);
    }
    final shell = isWindows
        ? ShellSpecDto(
            executable: requestedShell ?? 'powershell.exe',
            arguments: <String>[
              if (!login) '-NoProfile',
              '-NonInteractive',
              '-Command',
              command,
            ],
          )
        : ShellSpecDto(
            executable: requestedShell ?? '/bin/sh',
            arguments: <String>[if (login) '-lc' else '-c', command],
          );
    final process = tty
        ? await _gateway.start(
            shell: TerminalShell(
              executable: shell.executable,
              arguments: shell.arguments,
            ),
            workingDirectory: workingDirectory,
            columns: 120,
            rows: 40,
          )
        : await _pipes.start(shell: shell, workingDirectory: workingDirectory);
    final session = _LiveExecSession(
      id: _nextSessionId += 1,
      owner: owner,
      process: process,
      clock: _clock,
    );
    _sessions[session.id] = session;
    return session;
  }

  /// Returns a live session owned by [owner], or null.
  ExecSession? lookup(String owner, int sessionId) {
    final session = _sessions[sessionId];
    return session != null && session.owner == owner ? session : null;
  }

  /// Whether the user already approved commands for [sessionId].
  bool isApproved(int sessionId) => _approved.contains(sessionId);

  /// Records that the user approved the command that started [sessionId].
  void markApproved(int sessionId) => _approved.add(sessionId);

  /// Terminates one live session only when [owner] owns it.
  Future<bool> terminate(String owner, int sessionId) async {
    final session = _sessions[sessionId];
    if (session == null || session.owner != owner) return false;
    await _terminate(session);
    return true;
  }

  /// Terminates every session untouched for [execSessionIdleTimeout].
  void sweepIdle() {
    final deadline = _clock.nowUtc().subtract(execSessionIdleTimeout);
    for (final session in List<_LiveExecSession>.of(_sessions.values)) {
      if (session.lastUsed.isBefore(deadline)) {
        unawaited(_terminate(session));
      }
    }
  }

  /// Terminates every session owned by one tinest session.
  Future<void> closeOwner(String owner) async {
    await Future.wait(_ownedBy(owner).map(_terminate));
  }

  /// Terminates every session this service owns.
  Future<void> close() async {
    await Future.wait(
      List<_LiveExecSession>.of(_sessions.values).map(_terminate),
    );
  }

  Future<void> _terminate(_LiveExecSession session) async {
    _sessions.remove(session.id);
    _approved.remove(session.id);
    await session.close();
  }
}

/// A tinest-session-scoped view of [ExecSessionService].
///
/// The tools only ever see this, so one tinest session can never reach another
/// session's pseudo-terminals.
class SessionExecHost implements ExecSessionHost {
  /// Creates a [SessionExecHost].
  const new(this._service, this._sessionId);

  final ExecSessionService _service;
  final String _sessionId;

  @override
  Future<ExecSession> start({
    required String command,
    required String workingDirectory,
    required bool tty,
    String? shell,
    bool login = true,
  }) => _service.start(
    owner: _sessionId,
    command: command,
    workingDirectory: workingDirectory,
    tty: tty,
    requestedShell: shell,
    login: login,
  );

  @override
  ExecSession? lookup(int sessionId) => _service.lookup(_sessionId, sessionId);

  @override
  bool isApproved(int sessionId) => _service.isApproved(sessionId);

  @override
  void markApproved(int sessionId) => _service.markApproved(sessionId);

  @override
  Future<bool> terminate(int sessionId) =>
      _service.terminate(_sessionId, sessionId);
}

class _LiveExecSession implements ExecSession {
  new({
    required this.id,
    required this.owner,
    required ExecProcess process,
    required Clock clock,
  }) : _process = process,
       _clock = clock,
       lastUsed = clock.nowUtc() {
    _output = process.outputs.listen(_append);
    unawaited(
      process.exitCode
          .then((code) {
            _exitCode = code;
            _finished.complete(code);
          })
          .catchError((Object _) {
            _exitCode = -1;
            if (!_finished.isCompleted) _finished.complete(-1);
          }),
    );
  }

  @override
  final int id;

  /// Tinest session that owns this pseudo-terminal.
  final String owner;

  final ExecProcess _process;
  final Clock _clock;
  final Completer<int> _finished = Completer<int>();

  /// Output produced since the last read, capped at
  /// [maxExecSessionOutputBytes].
  String _buffer = '';
  late final StreamSubscription<String> _output;
  int? _exitCode;

  /// When this session last produced or received anything.
  DateTime lastUsed;

  @override
  Future<void> write(String chars) async {
    lastUsed = _clock.nowUtc();
    await _process.write(chars);
  }

  @override
  Future<ExecSessionChunk> read(Duration yieldTime) async {
    final startedAt = _clock.nowUtc();
    // Return as soon as the command exits, or when the wait elapses, whichever
    // comes first. Anything the process produced meanwhile is already buffered.
    if (_exitCode == null) {
      await _finished.future
          .timeout(yieldTime)
          .catchError(
            (Object _) => -1,
            test: (error) => error is TimeoutException,
          );
    }
    lastUsed = _clock.nowUtc();
    final output = _buffer;
    _buffer = '';
    return ExecSessionChunk(
      output: output,
      isRunning: _exitCode == null,
      exitCode: _exitCode,
      wallTime: lastUsed.difference(startedAt),
    );
  }

  @override
  Future<void> interrupt() async {
    lastUsed = _clock.nowUtc();
    // The transport decides what stopping means; either way the foreground
    // command stops and the session itself keeps running.
    await _process.interrupt();
  }

  /// Appends PTY output, dropping the oldest bytes once the buffer is full.
  ///
  /// A server left running between reads would otherwise grow this without
  /// bound, and its recent output is the part worth keeping.
  void _append(String data) =>
      _buffer = truncateTailToBytes('$_buffer$data', maxExecSessionOutputBytes);

  /// Stops reading and terminates the pseudo-terminal.
  Future<void> close() async {
    await _output.cancel();
    await _process.terminate();
  }
}

/// Truncates [output] on a UTF-8 boundary so it fits [maxBytes], keeping the
/// tail.
String truncateTailToBytes(String output, int maxBytes) {
  final bytes = utf8.encode(output);
  if (bytes.length <= maxBytes) return output;
  var start = bytes.length - maxBytes;
  while (start < bytes.length && (bytes[start] & 0xC0) == 0x80) {
    start += 1;
  }
  return utf8.decode(bytes.sublist(start));
}
