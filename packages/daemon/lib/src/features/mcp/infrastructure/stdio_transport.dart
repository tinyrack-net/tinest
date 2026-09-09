import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:daemon/src/features/mcp/infrastructure/transport.dart';
import 'package:process/process.dart';

/// Speaks newline-delimited JSON-RPC to a child process over its stdio.
final class StdioMcpTransport implements McpTransport {
  /// Creates a transport that will launch [spec].
  new(
    this.spec, {
    this._processManager = const LocalProcessManager(),
    this.terminationGrace = const Duration(seconds: 3),
  });

  final ProcessManager _processManager;

  /// How to launch the server.
  final McpStdioSpec spec;

  /// How long a terminated child has to exit before it is killed outright.
  final Duration terminationGrace;

  /// How many stderr lines are retained for diagnostics.
  static const int maxRetainedDiagnostics = 100;

  /// How many stderr bytes are retained for diagnostics.
  static const int maxRetainedDiagnosticBytes = 64 * 1024;

  final StreamController<Map<String, dynamic>> _incoming =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _diagnostics =
      StreamController<String>.broadcast();
  final Completer<void> _done = Completer<void>();
  final List<String> _retained = <String>[];

  Process? _process;
  StreamSubscription<String>? _stdout;
  StreamSubscription<String>? _stderr;
  bool _closed = false;

  /// The most recent stderr lines, oldest first.
  ///
  /// This is what tells a user why a server will not start, so it survives the
  /// child's death and is bounded rather than unbounded.
  List<String> get retainedDiagnostics => List<String>.unmodifiable(_retained);

  @override
  Stream<Map<String, dynamic>> get incoming => _incoming.stream;

  @override
  Stream<String> get diagnostics => _diagnostics.stream;

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> start() async {
    if (_closed) throw const McpTransportClosed('already closed');
    if (_process != null) return;
    final process = await _processManager.start(
      <String>[spec.command, ...spec.args],
      workingDirectory: spec.workingDirectory,
      environment: spec.env.isEmpty ? null : spec.env,
    );
    _process = process;
    _stdout = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleLine, onDone: _handleStdoutDone);
    _stderr = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_report);
    unawaited(process.exitCode.then(_handleExit));
  }

  @override
  Future<void> send(Map<String, dynamic> message) async {
    final process = _process;
    if (_closed || process == null) {
      throw const McpTransportClosed('the server process is not running');
    }
    process.stdin.write('${jsonEncode(message)}\n');
    await process.stdin.flush();
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final process = _process;
    if (process != null) {
      process.kill();
      // A server that ignores SIGTERM still has to go, so escalate once the
      // grace period passes rather than leaking the child.
      var exited = false;
      await process.exitCode
          .then<void>((_) => exited = true)
          .timeout(terminationGrace, onTimeout: () {});
      if (!exited) process.kill(ProcessSignal.sigkill);
    }
    await _release();
  }

  Future<void> _release() async {
    await _stdout?.cancel();
    await _stderr?.cancel();
    _stdout = null;
    _stderr = null;
    _complete();
    if (!_incoming.isClosed) await _incoming.close();
    if (!_diagnostics.isClosed) await _diagnostics.close();
  }

  void _handleLine(String line) {
    if (line.trim().isEmpty) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      // Servers routinely print banners and warnings to stdout. Dropping the
      // line keeps the session alive while still surfacing it to the user.
      _report('ignored non-JSON stdout: $line');
      return;
    }
    if (decoded is! Map<String, dynamic>) {
      _report('ignored non-object stdout: $line');
      return;
    }
    if (!_incoming.isClosed) _incoming.add(decoded);
  }

  void _handleStdoutDone() {
    if (_closed) return;
    _report('the server closed its stdout');
  }

  void _handleExit(int code) {
    if (_closed) return;
    _report('the server exited with code $code');
    _closed = true;
    unawaited(_release());
  }

  void _report(String note) {
    _retained.add(note);
    var retainedBytes = _retained.fold<int>(
      0,
      (total, entry) => total + entry.length,
    );
    while (_retained.length > maxRetainedDiagnostics ||
        retainedBytes > maxRetainedDiagnosticBytes) {
      retainedBytes -= _retained.removeAt(0).length;
    }
    if (!_diagnostics.isClosed) _diagnostics.add(note);
  }

  void _complete() {
    if (!_done.isCompleted) _done.complete();
  }
}
