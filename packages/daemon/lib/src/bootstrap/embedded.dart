import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:agent/agent.dart';
import 'package:daemon/src/bootstrap/application.dart';
import 'package:daemon/src/bootstrap/config.dart';

/// Stable reason an embedded daemon could not finish starting.
enum EmbeddedDaemonStartupFailureReason {
  /// The configured listener port is already owned by another process.
  portInUse,

  /// Another daemon already holds the lock on this daemon home.
  alreadyRunning,

  /// Startup failed for another reason.
  unknown,
}

/// Typed failure reported when an embedded daemon cannot complete startup.
final class EmbeddedDaemonStartupException implements Exception {
  /// Creates an embedded startup failure with a safe diagnostic message.
  const new(
    this.message, {
    this.reason = EmbeddedDaemonStartupFailureReason.unknown,
  });

  /// Startup diagnostic without credential values.
  final String message;

  /// Machine-readable failure category transported across the isolate.
  final EmbeddedDaemonStartupFailureReason reason;

  @override
  String toString() => message;
}

/// EmbeddedDaemonHandle defines a public contract.
class EmbeddedDaemonHandle implements DaemonHandle {
  new _({
    required this.boundEndpoint,
    required this.serverId,
    required this.bearerToken,
    required this._isolate,
    required this._commands,
    required this._exited,
  });

  /// The start public API member.
  static Future<EmbeddedDaemonHandle> start(
    DaemonConfig config, {
    ModelGateway? provider,
  }) async {
    final receive = ReceivePort();
    final exited = Completer<void>();
    late final RawReceivePort exitPort;
    exitPort = RawReceivePort((Object? _) {
      exitPort.close();
      if (!exited.isCompleted) exited.complete();
    });
    late final Isolate isolate;
    try {
      isolate = await Isolate.spawn(
        _embeddedDaemonMain,
        <Object?>[receive.sendPort, config.toIsolateMessage(), provider],
        debugName: 'tinyrack-tinest-daemon',
        onExit: exitPort.sendPort,
      );
    } on Object {
      receive.close();
      exitPort.close();
      rethrow;
    }
    late final Object? message;
    try {
      message = await receive.first.timeout(const Duration(seconds: 30));
    } on Object {
      isolate.kill(priority: Isolate.immediate);
      await exited.future.timeout(const Duration(seconds: 10));
      rethrow;
    } finally {
      receive.close();
    }
    if (message is! Map) {
      isolate.kill(priority: Isolate.immediate);
      await exited.future.timeout(const Duration(seconds: 10));
      throw const EmbeddedDaemonStartupException(
        'Embedded daemon returned an invalid ready message.',
      );
    }
    final values = Map<Object?, Object?>.from(message);
    if (values['error'] case final String error) {
      isolate.kill(priority: Isolate.immediate);
      await exited.future.timeout(const Duration(seconds: 10));
      final reasonName = values['errorReason'];
      final reason = EmbeddedDaemonStartupFailureReason.values
          .where((value) => value.name == reasonName)
          .firstOrNull;
      throw EmbeddedDaemonStartupException(
        error,
        reason: reason ?? EmbeddedDaemonStartupFailureReason.unknown,
      );
    }
    return EmbeddedDaemonHandle._(
      boundEndpoint: Uri.parse(values['endpoint']! as String),
      serverId: values['serverId']! as String,
      bearerToken: values['token']! as String,
      isolate: isolate,
      commands: values['commands']! as SendPort,
      exited: exited.future,
    );
  }

  @override
  final Uri boundEndpoint;
  @override
  final String serverId;
  @override
  final String bearerToken;
  final Isolate _isolate;
  final SendPort _commands;
  final Future<void> _exited;
  Future<void>? _stopFuture;

  @override
  Future<void> get ready => Future<void>.value();

  @override
  Future<void> stop() => _stopFuture ??= _stop();

  Future<void> _stop() async {
    final response = ReceivePort();
    var acknowledged = false;
    try {
      _commands.send(<Object?>['stop', response.sendPort]);
      await response.first.timeout(const Duration(seconds: 10));
      acknowledged = true;
    } finally {
      response.close();
      if (acknowledged) {
        try {
          await _exited.timeout(const Duration(seconds: 10));
        } on TimeoutException {
          _isolate.kill(priority: Isolate.immediate);
          await _exited.timeout(const Duration(seconds: 10));
        }
      } else {
        _isolate.kill(priority: Isolate.immediate);
        await _exited.timeout(const Duration(seconds: 10));
      }
    }
  }
}

Future<void> _embeddedDaemonMain(List<Object?> message) async {
  final ready = message[0]! as SendPort;
  final config = DaemonConfig.fromIsolateMessage(
    Map<Object?, Object?>.from(message[1]! as Map),
  );
  final provider = message[2] as ModelGateway?;
  try {
    final handle = await DaemonApplication.start(
      config,
      options: DaemonHostOptions(provider: provider),
    );
    final commands = ReceivePort();
    ready.send(<Object?, Object?>{
      'endpoint': handle.boundEndpoint.toString(),
      'serverId': handle.serverId,
      'token': handle.bearerToken,
      'commands': commands.sendPort,
    });
    await for (final command in commands) {
      if (command is List && command.firstOrNull == 'stop') {
        await handle.stop();
        if (command.length > 1 && command[1] is SendPort) {
          (command[1] as SendPort).send(true);
        }
        commands.close();
      }
    }
  } on Exception catch (error) {
    _sendStartupError(ready, error);
  }
}

void _sendStartupError(SendPort ready, Object error) {
  ready.send(<Object?, Object?>{
    'error': '$error',
    'errorReason': _startupFailureReason(error).name,
  });
}

EmbeddedDaemonStartupFailureReason _startupFailureReason(Object error) {
  if (error is DaemonAlreadyRunningException) {
    return EmbeddedDaemonStartupFailureReason.alreadyRunning;
  }
  if (error case SocketException(:final osError)) {
    // EADDRINUSE is 48 on Darwin, 98 on Linux, and 10048 on Windows.
    if (const <int>{48, 98, 10048}.contains(osError?.errorCode)) {
      return EmbeddedDaemonStartupFailureReason.portInUse;
    }
    final message = '$error'.toLowerCase();
    if (message.contains('address already in use') ||
        message.contains('shared flag to bind')) {
      return EmbeddedDaemonStartupFailureReason.portInUse;
    }
  }
  return EmbeddedDaemonStartupFailureReason.unknown;
}
