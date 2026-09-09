import 'dart:async';
import 'dart:convert';

import 'package:daemon/src/features/mcp/infrastructure/protocol.dart';
import 'package:daemon/src/features/mcp/infrastructure/transport.dart';
import 'package:http/http.dart' as http;

/// An HTTP status the server returned instead of a JSON-RPC message.
class McpHttpException implements Exception {
  /// Creates a [McpHttpException].
  const new({required this.statusCode, required this.body});

  /// The HTTP status code.
  final int statusCode;

  /// A truncated copy of the response body.
  final String body;

  @override
  String toString() => 'McpHttpException($statusCode): $body';
}

/// Speaks JSON-RPC over the MCP Streamable HTTP transport.
///
/// Every client message is POSTed to a single endpoint. The server answers
/// either with one JSON object or with an SSE stream of them. The deprecated
/// two-endpoint SSE transport is deliberately not implemented.
final class HttpMcpTransport implements McpTransport {
  /// Creates a transport that posts to [spec].
  new(
    this.spec, {
    http.Client? client,
    this.protocolVersion = preferredMcpProtocolVersion,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  /// Where and how to reach the server.
  final McpHttpSpec spec;

  /// The revision advertised on every request after the handshake.
  final String protocolVersion;

  /// How much of an error body is retained for diagnostics.
  static const int maxRetainedBodyLength = 2048;

  final http.Client _client;
  final bool _ownsClient;
  final StreamController<Map<String, dynamic>> _incoming =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _diagnostics =
      StreamController<String>.broadcast();
  final Completer<void> _done = Completer<void>();

  StreamSubscription<Map<String, dynamic>>? _serverStream;
  String? _sessionId;
  bool _started = false;
  bool _closed = false;
  bool _handshakeSent = false;
  bool _supportsServerStream = false;

  /// The session id the server assigned, once it has issued one.
  String? get sessionId => _sessionId;

  /// Whether the server accepted a standing GET for its own messages.
  bool get supportsServerStream => _supportsServerStream;

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
    if (_closed || !_started) {
      throw const McpTransportClosed('the transport is not started');
    }
    final isInitialized = message['method'] == McpMethod.initialized;
    final response = await _post(message);

    if (response.statusCode == 404 && _sessionId != null) {
      // The server forgot our session; the caller reconnects from initialize.
      _sessionId = null;
      _report('the server expired the session');
      await close();
      return;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw McpHttpException(
        statusCode: response.statusCode,
        body: _truncate(await _readBody(response)),
      );
    }

    final assigned = response.headers['mcp-session-id'];
    if (assigned != null && assigned.isNotEmpty) _sessionId = assigned;

    final contentType = response.headers['content-type'] ?? '';
    if (contentType.contains('text/event-stream')) {
      await _decodeEventStream(response.stream).forEach(_emit);
    } else if (contentType.contains('application/json')) {
      final body = await _readBody(response);
      if (body.trim().isNotEmpty) _emitRaw(body);
    }
    // A 202 with no body is the correct answer to a notification.

    if (isInitialized) await _openServerStream();
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _serverStream?.cancel();
    _serverStream = null;
    if (_sessionId != null) await _deleteSession();
    if (_ownsClient) _client.close();
    if (!_done.isCompleted) _done.complete();
    if (!_incoming.isClosed) await _incoming.close();
    if (!_diagnostics.isClosed) await _diagnostics.close();
  }

  Future<http.StreamedResponse> _post(Map<String, dynamic> message) async {
    final request = http.Request('POST', spec.url)
      ..headers.addAll(_headers())
      ..headers['content-type'] = 'application/json'
      ..headers['accept'] = 'application/json, text/event-stream'
      ..body = jsonEncode(message);
    if (message['method'] == McpMethod.initialize) _handshakeSent = true;
    return await _client.send(request);
  }

  Map<String, String> _headers() => <String, String>{
    ...spec.headers,
    // The revision header is only meaningful once the server has told us which
    // revision it speaks, so it is omitted on the opening request.
    if (_handshakeSent) 'mcp-protocol-version': protocolVersion,
    'mcp-session-id': ?_sessionId,
  };

  Future<void> _openServerStream() async {
    if (_closed || _serverStream != null) return;
    final request = http.Request('GET', spec.url)
      ..headers.addAll(_headers())
      ..headers['accept'] = 'text/event-stream';
    final http.StreamedResponse response;
    try {
      response = await _client.send(request);
    } on Object catch (error) {
      _report('the server refused a listening stream: $error');
      return;
    }
    if (response.statusCode != 200) {
      // 405 is the documented answer from a server that never initiates
      // messages; anything else is treated the same way, by polling instead.
      _report('the server does not stream (HTTP ${response.statusCode})');
      unawaited(response.stream.drain<void>());
      return;
    }
    _supportsServerStream = true;
    _serverStream = _decodeEventStream(response.stream).listen(
      _emit,
      onError: (Object error) => _report('the listening stream failed: $error'),
      onDone: () => _serverStream = null,
    );
  }

  Future<void> _deleteSession() async {
    try {
      await _client.delete(spec.url, headers: _headers());
    } on Object catch (error) {
      // The session is being abandoned either way; a failed DELETE only means
      // the server keeps it until its own timeout.
      _report('the session could not be released: $error');
    }
  }

  Stream<Map<String, dynamic>> _decodeEventStream(
    Stream<List<int>> bytes,
  ) async* {
    final data = <String>[];
    await for (final line
        in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.isEmpty) {
        final decoded = _decode(data.join('\n'));
        if (decoded != null) yield decoded;
        data.clear();
        continue;
      }
      if (line.startsWith(':')) continue;
      final separator = line.indexOf(':');
      final field = separator < 0 ? line : line.substring(0, separator);
      if (field != 'data') continue;
      var value = separator < 0 ? '' : line.substring(separator + 1);
      if (value.startsWith(' ')) value = value.substring(1);
      data.add(value);
    }
    final trailing = _decode(data.join('\n'));
    if (trailing != null) yield trailing;
  }

  Map<String, dynamic>? _decode(String payload) {
    if (payload.trim().isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException {
      _report('ignored a non-JSON event: ${_truncate(payload)}');
      return null;
    }
    if (decoded is! Map<String, dynamic>) {
      _report('ignored a non-object event: ${_truncate(payload)}');
      return null;
    }
    return decoded;
  }

  void _emitRaw(String payload) {
    final decoded = _decode(payload);
    if (decoded != null) _emit(decoded);
  }

  void _emit(Map<String, dynamic> message) {
    if (!_incoming.isClosed) _incoming.add(message);
  }

  Future<String> _readBody(http.StreamedResponse response) =>
      response.stream.bytesToString();

  void _report(String note) {
    if (!_diagnostics.isClosed) _diagnostics.add(note);
  }

  static String _truncate(String body) => body.length <= maxRetainedBodyLength
      ? body
      : '${body.substring(0, maxRetainedBodyLength)}…';
}
