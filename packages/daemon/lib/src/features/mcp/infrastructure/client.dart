import 'dart:async';

import 'package:daemon/src/features/mcp/infrastructure/protocol.dart';
import 'package:daemon/src/features/mcp/infrastructure/transport.dart';
import 'package:daemon/src/shared/ports/request_cancellation.dart';

/// Speaks MCP to one server over a [McpTransport].
///
/// The client owns request correlation, protocol negotiation, the tool cache,
/// and liveness. It does not own reconnection: a client whose transport dies is
/// finished, and the caller builds a new one.
final class McpClient {
  /// Creates a client that talks over [transport].
  new({
    required this.transport,
    this.clientVersion = '0.0.0',
    this.requestTimeout = const Duration(seconds: 60),
    this.initializeTimeout = const Duration(seconds: 30),
    this.pingInterval = const Duration(seconds: 30),
  });

  /// The channel to the server.
  final McpTransport transport;

  /// Version reported to the server as `clientInfo.version`.
  final String clientVersion;

  /// How long any request other than `initialize` may take.
  final Duration requestTimeout;

  /// How long the opening handshake may take.
  final Duration initializeTimeout;

  /// How often the client pings an idle connection.
  final Duration pingInterval;

  /// Name reported to the server as `clientInfo.name`.
  static const String clientName = 'tinyrack-tinest';

  /// How many unanswered pings end the connection.
  static const int _maxMissedPings = 2;

  final Map<int, Completer<Map<String, dynamic>>> _pending =
      <int, Completer<Map<String, dynamic>>>{};
  final StreamController<void> _toolsChanged =
      StreamController<void>.broadcast();
  final StreamController<void> _resourcesChanged =
      StreamController<void>.broadcast();
  final StreamController<String> _diagnostics =
      StreamController<String>.broadcast();
  final Completer<void> _closed = Completer<void>();

  StreamSubscription<Map<String, dynamic>>? _incoming;
  StreamSubscription<String>? _transportDiagnostics;
  Timer? _pingTimer;
  int _nextRequestId = 1;
  int _missedPings = 0;
  bool _connected = false;
  bool _disposed = false;
  List<McpToolDescriptor> _tools = const <McpToolDescriptor>[];
  List<McpResourceDescriptor> _resources = const <McpResourceDescriptor>[];
  List<McpResourceTemplateDescriptor> _resourceTemplates =
      const <McpResourceTemplateDescriptor>[];
  McpServerIdentity? _identity;

  /// Whether the handshake completed and the transport is still alive.
  bool get isConnected => _connected;

  /// The tools most recently published by the server.
  List<McpToolDescriptor> get tools => _tools;

  /// What the server reported during `initialize`, once connected.
  McpServerIdentity? get identity => _identity;

  /// The resources most recently published by the server.
  List<McpResourceDescriptor> get resources => _resources;

  /// The resource templates most recently published by the server.
  List<McpResourceTemplateDescriptor> get resourceTemplates =>
      _resourceTemplates;

  /// Fires whenever [tools] changes after the initial listing.
  Stream<void> get toolsChanged => _toolsChanged.stream;

  /// Fires whenever [resources] changes after the initial listing.
  Stream<void> get resourcesChanged => _resourcesChanged.stream;

  /// Non-fatal notes from the transport, such as child stderr.
  Stream<String> get diagnostics => _diagnostics.stream;

  /// Completes once the client is finished, cleanly or otherwise.
  Future<void> get closed => _closed.future;

  /// Runs the opening handshake and the first tool listing.
  Future<McpServerIdentity> connect() async {
    await transport.start();
    _incoming = transport.incoming.listen(
      _handleMessage,
      onDone: () => _teardown('the server closed the connection'),
    );
    _transportDiagnostics = transport.diagnostics.listen(_report);
    unawaited(transport.done.then((_) => _teardown(null)));
    _connected = true;

    final Map<String, dynamic> result;
    try {
      result = await _request(McpMethod.initialize, <String, dynamic>{
        'protocolVersion': preferredMcpProtocolVersion,
        'capabilities': <String, dynamic>{'tools': <String, dynamic>{}},
        'clientInfo': <String, dynamic>{
          'name': clientName,
          'version': clientVersion,
        },
      }, timeout: initializeTimeout);
    } on Object {
      await close();
      rethrow;
    }

    final version = result['protocolVersion'];
    if (version is! String || !supportedMcpProtocolVersions.contains(version)) {
      await close();
      throw McpUnsupportedProtocolVersion(
        version is String ? version : 'an unspecified revision',
      );
    }

    final info = result['serverInfo'];
    final capabilities = result['capabilities'];
    final toolCapability = capabilities is Map<String, dynamic>
        ? capabilities['tools']
        : null;
    final resourceCapability = capabilities is Map<String, dynamic>
        ? capabilities['resources']
        : null;
    final identity = McpServerIdentity(
      protocolVersion: version,
      name: info is Map<String, dynamic> && info['name'] is String
          ? info['name'] as String
          : null,
      version: info is Map<String, dynamic> && info['version'] is String
          ? info['version'] as String
          : null,
      publishesTools: toolCapability != null,
      emitsToolListChanged:
          toolCapability is Map<String, dynamic> &&
          toolCapability['listChanged'] == true,
      publishesResources: resourceCapability != null,
      emitsResourceListChanged:
          resourceCapability is Map<String, dynamic> &&
          resourceCapability['listChanged'] == true,
    );
    _identity = identity;

    await _notify(McpMethod.initialized);
    if (identity.publishesTools) {
      _tools = await _listTools();
    }
    if (identity.publishesResources) {
      _resources = await _listResources();
      _resourceTemplates = await _listResourceTemplates();
    }
    _startPinging();
    return identity;
  }

  /// Invokes [name] on the server and decodes its result.
  Future<McpCallToolResult> callTool(
    String name,
    Map<String, dynamic> arguments, {
    RequestCancellation? cancellation,
  }) async {
    final result = await _request(McpMethod.toolsCall, <String, dynamic>{
      'name': name,
      'arguments': arguments,
    }, cancellation: cancellation);
    return McpCallToolResult.fromJson(result);
  }

  /// Re-reads the server's tool list and republishes it.
  Future<void> refreshTools() async {
    if (_identity?.publishesTools != true) return;
    _tools = await _listTools();
    if (!_toolsChanged.isClosed) _toolsChanged.add(null);
  }

  /// Lists the server's resources and templates again.
  Future<void> refreshResources() async {
    if (_identity?.publishesResources != true) return;
    _resources = await _listResources();
    _resourceTemplates = await _listResourceTemplates();
    if (!_resourcesChanged.isClosed) _resourcesChanged.add(null);
  }

  /// Reads one published resource.
  Future<McpReadResourceResult> readResource(String uri) async {
    final result = await _request(McpMethod.resourcesRead, <String, dynamic>{
      'uri': uri,
    });
    return McpReadResourceResult.fromJson(result);
  }

  /// Ends the session and releases every resource the client holds.
  Future<void> close() async {
    if (_disposed) return;
    _disposed = true;
    _connected = false;
    _pingTimer?.cancel();
    await _incoming?.cancel();
    await _transportDiagnostics?.cancel();
    _failPending(const McpTransportClosed('the client was closed'));
    await transport.close();
    if (!_closed.isCompleted) _closed.complete();
    await _toolsChanged.close();
    await _resourcesChanged.close();
    await _diagnostics.close();
  }

  Future<void> _refreshToolsQuietly() async {
    try {
      await refreshTools();
    } on Object catch (error) {
      _report('$error');
    }
  }

  Future<void> _refreshResourcesQuietly() async {
    try {
      await refreshResources();
    } on Object catch (error) {
      _report('$error');
    }
  }

  Future<List<McpResourceDescriptor>> _listResources() =>
      _listPaged<McpResourceDescriptor>(
        McpMethod.resourcesList,
        'resources',
        McpResourceDescriptor.fromJson,
      );

  /// Reads one resource page while preserving the server cursor.
  Future<McpListPage<McpResourceDescriptor>> listResourcesPage({
    String? cursor,
  }) => _listPage(
    McpMethod.resourcesList,
    'resources',
    McpResourceDescriptor.fromJson,
    cursor,
  );

  /// Reads one resource-template page while preserving the server cursor.
  Future<McpListPage<McpResourceTemplateDescriptor>> listResourceTemplatesPage({
    String? cursor,
  }) => _listPage(
    McpMethod.resourceTemplatesList,
    'resourceTemplates',
    McpResourceTemplateDescriptor.fromJson,
    cursor,
  );

  Future<List<McpResourceTemplateDescriptor>> _listResourceTemplates() =>
      _listPaged<McpResourceTemplateDescriptor>(
        McpMethod.resourceTemplatesList,
        'resourceTemplates',
        McpResourceTemplateDescriptor.fromJson,
      );

  /// Drains every page of a cursor-paginated list method.
  ///
  /// An entry the server malformed is reported and skipped rather than
  /// failing the whole listing, matching how tools are decoded.
  Future<List<T>> _listPaged<T>(
    String method,
    String key,
    T Function(Map<String, dynamic> json) decode,
  ) async {
    final collected = <T>[];
    String? cursor;
    do {
      final page = await _listPage(method, key, decode, cursor);
      collected.addAll(page.items);
      cursor = page.nextCursor;
    } while (cursor != null);
    return List<T>.unmodifiable(collected);
  }

  Future<McpListPage<T>> _listPage<T>(
    String method,
    String key,
    T Function(Map<String, dynamic> json) decode,
    String? cursor,
  ) async {
    final result = await _request(method, <String, dynamic>{'cursor': ?cursor});
    final decoded = <T>[];
    final entries = result[key];
    if (entries is List) {
      for (final entry in entries) {
        if (entry is! Map<String, dynamic>) continue;
        try {
          decoded.add(decode(entry));
        } on McpProtocolException catch (error) {
          _report(error.message);
        }
      }
    }
    final next = result['nextCursor'];
    return McpListPage<T>(
      items: List<T>.unmodifiable(decoded),
      nextCursor: next is String && next.isNotEmpty ? next : null,
    );
  }

  Future<List<McpToolDescriptor>> _listTools() => _listPaged<McpToolDescriptor>(
    McpMethod.toolsList,
    'tools',
    McpToolDescriptor.fromJson,
  );

  Future<Map<String, dynamic>> _request(
    String method,
    Map<String, dynamic> params, {
    Duration? timeout,
    RequestCancellation? cancellation,
  }) async {
    if (!_connected) {
      throw const McpTransportClosed('the client is not connected');
    }
    const cancellationReason = 'the request was cancelled by its caller';
    if (cancellation?.isCancelled ?? false) {
      throw const McpRequestCancelled(cancellationReason);
    }
    final id = _nextRequestId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    var active = true;

    void cancel() {
      if (!active) return;
      final pending = _pending.remove(id);
      if (pending == null || pending.isCompleted) return;
      active = false;
      pending.completeError(const McpRequestCancelled(cancellationReason));
      unawaited(_cancelQuietly(id, cancellationReason));
    }

    try {
      await transport.send(<String, dynamic>{
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params,
      });
      cancellation?.onCancel(cancel);
      if (cancellation?.isCancelled ?? false) cancel();
      return await completer.future.timeout(timeout ?? requestTimeout);
    } on TimeoutException {
      _pending.remove(id);
      unawaited(_cancelQuietly(id, 'the request exceeded its timeout'));
      rethrow;
    } finally {
      active = false;
    }
  }

  Future<void> _cancelQuietly(int requestId, String reason) async {
    try {
      await _notify(McpMethod.cancelled, <String, dynamic>{
        'requestId': requestId,
        'reason': reason,
      });
    } on Object {
      // The peer is already gone; there is nothing left to cancel.
    }
  }

  Future<void> _notify(String method, [Map<String, dynamic>? params]) =>
      transport.send(<String, dynamic>{
        'jsonrpc': '2.0',
        'method': method,
        'params': ?params,
      });

  void _handleMessage(Map<String, dynamic> message) {
    final id = message['id'];
    final method = message['method'];

    if (method is String) {
      if (id == null) {
        if (method == McpMethod.toolsListChanged) {
          unawaited(_refreshToolsQuietly());
        }
        if (method == McpMethod.resourcesListChanged) {
          unawaited(_refreshResourcesQuietly());
        }
        return;
      }
      unawaited(_answer(id, method));
      return;
    }

    if (id is! int) return;
    final completer = _pending.remove(id);
    if (completer == null || completer.isCompleted) return;
    final error = message['error'];
    if (error is Map<String, dynamic>) {
      completer.completeError(
        McpServerException(
          code: error['code'] is int ? error['code'] as int : -32603,
          message: error['message'] is String
              ? error['message'] as String
              : 'the server reported an unspecified error',
        ),
      );
      return;
    }
    final result = message['result'];
    completer.complete(
      result is Map<String, dynamic>
          ? Map<String, dynamic>.from(result)
          : <String, dynamic>{},
    );
  }

  Future<void> _answer(Object? id, String method) async {
    if (method == McpMethod.ping) {
      await transport.send(<String, dynamic>{
        'jsonrpc': '2.0',
        'id': id,
        'result': <String, dynamic>{},
      });
      return;
    }
    // This client advertises no sampling, roots, or elicitation capability, so
    // any other server-originated request is genuinely unimplemented.
    await transport.send(<String, dynamic>{
      'jsonrpc': '2.0',
      'id': id,
      'error': <String, dynamic>{
        'code': -32601,
        'message': 'Method not found: $method',
      },
    });
  }

  void _startPinging() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(pingInterval, (_) => unawaited(_ping()));
  }

  Future<void> _ping() async {
    try {
      await _request(McpMethod.ping, const <String, dynamic>{});
      _missedPings = 0;
    } on Object {
      _missedPings += 1;
      if (_missedPings >= _maxMissedPings) {
        _report('the server stopped answering pings');
        await close();
      }
    }
  }

  void _report(String note) {
    if (!_diagnostics.isClosed) _diagnostics.add(note);
  }

  void _teardown(String? reason) {
    if (_disposed) return;
    if (reason != null) _report(reason);
    unawaited(close());
  }

  void _failPending(Object error) {
    for (final completer in _pending.values.toList(growable: false)) {
      if (!completer.isCompleted) completer.completeError(error);
    }
    _pending.clear();
  }
}
