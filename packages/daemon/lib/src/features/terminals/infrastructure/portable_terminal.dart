import 'dart:convert';

import 'package:daemon/src/features/terminals/application/terminal_service.dart';
import 'package:daemon/src/features/terminals/domain/terminal.dart';
import 'package:ptyworld/ptyworld.dart';

/// Production cross-platform PTY adapter.
final class PtyworldTerminalGateway implements TerminalGateway {
  /// Creates the production PTY adapter.
  const new();

  @override
  Future<TerminalProcess> start({
    required TerminalShell shell,
    required String workingDirectory,
    required int columns,
    required int rows,
  }) async {
    try {
      final process = await PtyProcess.start(
        shell.executable,
        arguments: shell.arguments,
        workingDirectory: workingDirectory,
        columns: columns,
        rows: rows,
      );
      return _TinyrackTerminalProcess(process);
    } on PtyException {
      throw const TerminalCreationException(
        TerminalCreationFailureReason.startFailed,
        'The configured terminal shell could not be started.',
      );
    }
  }
}

final class _TinyrackTerminalProcess implements TerminalProcess {
  const new(this._process);

  final PtyProcess _process;

  @override
  Stream<String> get outputs => _process.output.transform(utf8.decoder);

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  Future<void> write(String data) => _process.write(utf8.encode(data));

  @override
  Future<void> interrupt() =>
      // ETX is what Ctrl-C sends; the terminal's line discipline turns it into
      // SIGINT for the foreground command and leaves the shell running.
      _process.write(utf8.encode(String.fromCharCode(0x03)));

  @override
  Future<void> resize(int columns, int rows) async =>
      _process.resize(columns: columns, rows: rows);

  @override
  Future<void> terminate() => _process.terminate();
}
