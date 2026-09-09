import 'dart:async';

import 'package:daemon/src/features/mcp/infrastructure/transport.dart';

/// An in-memory [McpTransport] wired directly to a handler.
///
/// Every message the client sends is handed to [onMessage], which replies by
/// calling [deliver]. This is the transport used to exercise the client without
/// a process or a socket, and it is also the shape a future in-process server
/// would take.
final class LoopbackMcpTransport implements McpTransport {
  /// Creates a [LoopbackMcpTransport] driven by [onMessage].
  new(this.onMessage);

  /// Receives each message the client sends.
  final void Function(Map<String, dynamic> message) onMessage;

  final StreamController<Map<String, dynamic>> _incoming =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _diagnostics =
      StreamController<String>.broadcast();
  final Completer<void> _done = Completer<void>();
  bool _started = false;
  bool _closed = false;

  /// Messages the client sent, in order.
  final List<Map<String, dynamic>> sent = <Map<String, dynamic>>[];

  @override
  Stream<Map<String, dynamic>> get incoming => _incoming.stream;

  @override
  Stream<String> get diagnostics => _diagnostics.stream;

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> start() async {
    if (_closed) throw const McpTransportClosed('already closed');
    _started = true;
  }

  @override
  Future<void> send(Map<String, dynamic> message) async {
    if (_closed) throw const McpTransportClosed('already closed');
    if (!_started) throw const McpTransportClosed('not started');
    sent.add(message);
    onMessage(message);
  }

  /// Pushes one server-originated message to the client.
  void deliver(Map<String, dynamic> message) {
    if (_closed) return;
    _incoming.add(message);
  }

  /// Reports one non-fatal transport note to the client.
  void reportDiagnostic(String note) {
    if (_closed) return;
    _diagnostics.add(note);
  }

  /// Simulates the peer disappearing without a clean shutdown.
  void dropPeer([String? reason]) {
    if (_closed) return;
    if (reason != null) _diagnostics.add(reason);
    _closed = true;
    if (!_done.isCompleted) _done.complete();
    unawaited(_incoming.close());
    unawaited(_diagnostics.close());
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (!_done.isCompleted) _done.complete();
    await _incoming.close();
    await _diagnostics.close();
  }
}
