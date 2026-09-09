import 'dart:async';

import 'package:cli/src/daemon_host.dart';
import 'package:cli/src/plugin_cli.dart';
import 'package:cli/src/progress.dart';
import 'package:client/client.dart';
import 'package:client/local_daemon.dart';
import 'package:cliweave/cliweave.dart';
import 'package:cliweave/terminal.dart';

/// A [StringSink] backed by a cliweave [WriteStream].
///
/// The command bodies write through [StringSink] so a test can pass a plain
/// [StringBuffer]; the router speaks [WriteStream]. This adapts one to the
/// other at the single point where they meet.
final class WriteStreamSink implements StringSink {
  /// Wraps a cliweave write stream as a [StringSink].
  const new(this._stream);

  final WriteStream _stream;

  @override
  void write(Object? object) => _stream.write('$object');

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) =>
      write(objects.join(separator));

  @override
  void writeCharCode(int charCode) => write(String.fromCharCode(charCode));

  @override
  void writeln([Object? object = '']) => write('$object\n');
}

/// Drives a cliweave [Spinner] from the command bodies' narrow progress port.
final class SpinnerCliProgress implements CliProgress {
  /// Reports progress through [_logger].
  new(this._logger);

  final CliLogger _logger;
  Spinner? _spinner;

  @override
  void start(String message) => _spinner = _logger.spinner(message);

  @override
  void succeed(String message) {
    _spinner?.succeed(message);
    _spinner = null;
  }

  @override
  void fail(String message) {
    _spinner?.fail(message);
    _spinner = null;
  }
}

/// How a command reaches a running daemon.
typedef DaemonClientFactory = Future<TinestClient> Function({
  required String host,
  required int port,
  required String bearerToken,
  required String clientId,
});

/// Everything a `tinest-cli` command needs that touches the outside world.
///
/// Every side effect the commands perform — connecting a socket, reading a
/// file, prompting for a secret, reading the environment — arrives through
/// this object, so `bin/tinest_cli.dart` stays the only composition root and a
/// test can substitute each one.
final class TinestCliContext implements CommandContext {
  /// Creates a command context.
  new({
    required this.process,
    required this.logger,
    required this.connectClient,
    required this.readSecret,
    required this.readFile,
    required this.environment,
    required this.directories,
    required this.startDaemon,
    required this.shutdownSignal,
    required this.runPluginProcess,
  });

  @override
  final RunProcess process;

  /// Renders human-facing status, warnings, and errors.
  final CliLogger logger;

  /// Opens a daemon connection.
  final DaemonClientFactory connectClient;

  /// Prompts for a secret without echoing it.
  final Future<String> Function() readSecret;

  /// Reads a UTF-8 text file.
  final Future<String> Function(String path) readFile;

  /// Process environment, consulted for the `TINYRACK_TINEST_*` overrides.
  final Map<String, String> environment;

  /// Resolved platform locations for the local daemon.
  final LocalDaemonDirectories directories;

  /// Starts a daemon in this process.
  final DaemonStarter startDaemon;

  /// Completes when the process is asked to shut down.
  final Future<void> Function() shutdownSignal;

  /// Starts optional local plugin authoring tools such as LuaLS.
  final PluginExternalProcessRunner runPluginProcess;

  /// The running application, needed by the hidden completion command.
  ///
  /// Assigned after the application is built, because the completion command
  /// is one of the routes the application is built from.
  Application<TinestCliContext>? application;

  /// Command output as a [StringSink].
  late final StringSink output = WriteStreamSink(process.stdout);

  /// A spinner-backed progress reporter for long-running steps.
  late final CliProgress progress = SpinnerCliProgress(logger);
}
