import 'dart:async';
import 'dart:convert';

import 'package:daemon/src/bootstrap/config.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:daemon/src/transport/http/attachment_binding.dart';
import 'package:daemon/src/transport/rpc/binding.dart';
import 'package:daemon/src/transport/rpc/diagnostics.dart';
import 'package:daemon/src/transport/rpc/session_host.dart';
import 'package:json_rpc_2/json_rpc_2.dart' as json_rpc;
import 'package:protocol/protocol.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Hosts authenticated HTTP/WebSocket lifecycle over feature RPC bindings.
final class DaemonRpcServer implements RpcSessionHost {
  /// Creates the transport-only daemon server.
  new({
    required this.bindings,
    required this.attachments,
    required this.serverInfo,
    required this.token,
    required Stream<OutboundNotification> events,
    required this.ids,
    this.allowedOrigins = defaultAllowedOrigins,
    this.diagnostics = const StderrRpcDiagnostics(),
  }) {
    _eventSubscription = events.listen(_broadcast);
  }

  /// Feature bindings assembled by the composition root.
  final RpcBindingRegistry bindings;

  /// Feature-owned attachment HTTP transport.
  final AttachmentHttpBinding attachments;

  /// Metadata returned during the v5 handshake.
  final ServerInfoDto serverInfo;

  /// Bearer credential accepted by HTTP and WebSocket transports.
  final String token;

  /// Browser origins permitted to call this daemon.
  final Set<String> allowedOrigins;

  /// Mints the trace id that ties a client-visible failure to a diagnostics
  /// record.
  final IdGenerator ids;

  /// Sink for errors this boundary replaces with an opaque client failure.
  final RpcDiagnostics diagnostics;

  final Set<_ClientSession> _sessions = <_ClientSession>{};
  late final StreamSubscription<OutboundNotification> _eventSubscription;

  /// Handles one HTTP or WebSocket request.
  FutureOr<Response> call(Request request) {
    final origin = request.headers['origin'];
    if (origin != null && !allowedOrigins.contains(origin)) {
      return Response.forbidden('Origin $origin is not allowed.');
    }
    final cors = _corsHeaders(origin);
    if (request.method == 'OPTIONS') {
      return origin == null
          ? Response.notFound('Not found')
          : Response.ok(null, headers: cors);
    }
    if (request.url.path == 'v5/health') {
      return Response.ok(
        jsonEncode(<String, dynamic>{
          'serverId': serverInfo.serverId,
          'version': serverInfo.version,
          'protocolVersion': serverInfo.protocolVersion,
        }),
        headers: <String, String>{'content-type': 'application/json', ...cors},
      );
    }
    final isAttachmentRequest = attachments.matches(request);
    if (request.url.path != 'v5/ws' && !isAttachmentRequest) {
      return Response.notFound('Not found');
    }
    if (!_constantTimeEquals(_presentedToken(request), token)) {
      return Response.unauthorized(
        'A valid bearer token is required.',
        headers: cors,
      );
    }
    if (isAttachmentRequest) return attachments.call(request, cors);
    return webSocketHandler(
      _openSession,
      protocols: const <String>[tinestWebSocketProtocol],
    )(request);
  }

  static String? _presentedToken(Request request) {
    final authorization = request.headers['authorization'];
    if (authorization != null && authorization.startsWith('Bearer ')) {
      return authorization.substring('Bearer '.length);
    }
    final requested = request.headers['sec-websocket-protocol'] ?? '';
    for (final protocol in requested.split(',').map((value) => value.trim())) {
      final token = decodeWebSocketTokenProtocol(protocol);
      if (token != null) return token;
    }
    return null;
  }

  Map<String, String> _corsHeaders(String? origin) => origin == null
      ? const <String, String>{}
      : <String, String>{
          'access-control-allow-origin': origin,
          'access-control-allow-methods': 'GET, POST, OPTIONS',
          'access-control-allow-headers':
              'authorization, content-type, x-file-name',
          'access-control-expose-headers': 'content-disposition',
          'access-control-max-age': '600',
          'vary': 'Origin',
        };

  void _openSession(WebSocketChannel channel, String? protocol) {
    openSessionChannel(channel.cast<String>());
  }

  /// Opens the same typed RPC binding over an authenticated external channel.
  @override
  void openSessionChannel(
    StreamChannel<String> channel, {
    String? relayDeviceId,
  }) {
    final session = _ClientSession(
      channel: channel,
      bindings: bindings,
      serverInfo: serverInfo,
      relayDeviceId: relayDeviceId,
      ids: ids,
      diagnostics: diagnostics,
      onClosed: () {},
    );
    session.onClosed = () => _sessions.remove(session);
    _sessions.add(session);
    session.start();
  }

  /// Immediately closes live relay sessions owned by [deviceId].
  @override
  Future<void> terminateRelayDeviceSessions(String deviceId) async {
    await Future.wait<void>(<Future<void>>[
      for (final session in List<_ClientSession>.of(_sessions))
        if (session.relayDeviceId == deviceId) session.close(),
    ]);
  }

  void _broadcast(OutboundNotification event) {
    for (final session in List<_ClientSession>.of(_sessions)) {
      if (event.notification == sessionsTimelineEventNotification ||
          event.notification == sessionsApprovalRequestedNotification ||
          event.notification == sessionsQuestionRequestedNotification) {
        final sessionId = event.payload['sessionId'] as String?;
        if (sessionId == null ||
            !session.context.timelineSubscriptions.contains(sessionId)) {
          continue;
        }
      }
      session.send(event);
    }
  }

  /// Stops accepting notifications and closes every client session.
  Future<void> close() async {
    await _eventSubscription.cancel();
    for (final session in List<_ClientSession>.of(_sessions)) {
      await session.close();
    }
  }
}

bool _constantTimeEquals(String? candidate, String expected) {
  if (candidate == null) return false;
  final candidateBytes = utf8.encode(candidate);
  final expectedBytes = utf8.encode(expected);
  var difference = candidateBytes.length ^ expectedBytes.length;
  final length = candidateBytes.length > expectedBytes.length
      ? candidateBytes.length
      : expectedBytes.length;
  for (var index = 0; index < length; index += 1) {
    final left = index < candidateBytes.length ? candidateBytes[index] : 0;
    final right = index < expectedBytes.length ? expectedBytes[index] : 0;
    difference |= left ^ right;
  }
  return difference == 0;
}

final class _ClientSession {
  new({
    required this.channel,
    required this.bindings,
    required this.serverInfo,
    required this.relayDeviceId,
    required this.ids,
    required this.diagnostics,
    required this.onClosed,
  });

  final StreamChannel<String> channel;
  final RpcBindingRegistry bindings;
  final ServerInfoDto serverInfo;
  final String? relayDeviceId;
  final IdGenerator ids;
  final RpcDiagnostics diagnostics;
  final RpcConnectionContext context = RpcConnectionContext();
  void Function() onClosed;
  late final json_rpc.Peer _peer;
  bool _handshakeComplete = false;

  void start() {
    _peer = json_rpc.Peer(channel);
    _peer.registerMethod(systemHelloProcedure.name, _hello);
    for (final procedure in bindings.procedures) {
      _peer.registerMethod(
        procedure.name,
        (json_rpc.Parameters parameters) => _invoke(procedure.name, parameters),
      );
    }
    _peer.registerFallback((_) {
      throw json_rpc.RpcException(
        1002,
        'Unknown RPC method.',
        data: const RpcFailureDto(code: RpcErrorCodes.unknownMethod).toJson(),
      );
    });
    unawaited(_peer.listen().whenComplete(onClosed));
  }

  Future<Map<String, dynamic>> _hello(json_rpc.Parameters parameters) async {
    late final HelloParamsDto payload;
    try {
      payload = systemHelloProcedure.decodeParams(
        Map<String, dynamic>.from(parameters.asMap),
      );
    } on FormatException {
      throw json_rpc.RpcException(
        1002,
        'Invalid handshake parameters.',
        data: const RpcFailureDto(code: RpcErrorCodes.invalidParams).toJson(),
      );
    } on Object catch (error, stackTrace) {
      throw _internalFailure(systemHelloProcedure.name, error, stackTrace);
    }
    if (payload.protocolMajor != tinestProtocolMajor ||
        payload.protocolRevision != tinestProtocolRevision) {
      throw json_rpc.RpcException(
        1001,
        'Unsupported protocol version.',
        data: const RpcFailureDto(code: RpcErrorCodes.protocolMismatch)
            .toJson(),
      );
    }
    _handshakeComplete = true;
    return systemHelloProcedure.encodeResult(
      serverInfo.copyWith(
        features: <String, bool>{...serverInfo.features, 'jsonRpc2': true},
      ),
    );
  }

  Future<Map<String, dynamic>> _invoke(
    String method,
    json_rpc.Parameters parameters,
  ) async {
    if (!_handshakeComplete) {
      throw json_rpc.RpcException(
        1000,
        'Handshake required.',
        data: const RpcFailureDto(code: RpcErrorCodes.handshakeRequired)
            .toJson(),
      );
    }
    try {
      return await bindings.invoke(
        method,
        Map<String, dynamic>.from(parameters.asMap),
        context,
      );
    } on RpcFailureException catch (error) {
      throw json_rpc.RpcException(
        1002,
        error.message,
        data: RpcFailureDto(
          code: error.code,
          retryable: error.retryable,
          details: error.details ?? const <String, dynamic>{},
        ).toJson(),
      );
    } on FormatException {
      throw json_rpc.RpcException(
        1002,
        'Invalid request parameters.',
        data: const RpcFailureDto(code: RpcErrorCodes.invalidParams).toJson(),
      );
    } on Object catch (error, stackTrace) {
      throw _internalFailure(method, error, stackTrace);
    }
  }

  /// Reports an unexpected handler failure without leaking its cause.
  ///
  /// The client must not see the message or stack, which routinely carry
  /// paths, tokens, and prompt text. It does get the method, the exception
  /// type, and a trace id, which is enough to say what failed and to match a
  /// user's report against the diagnostics record holding the stack.
  json_rpc.RpcException _internalFailure(
    String method,
    Object error,
    StackTrace stackTrace,
  ) {
    final traceId = ids.generate();
    diagnostics.unhandledError(method, error, stackTrace, traceId: traceId);
    return json_rpc.RpcException(
      1003,
      'Internal daemon error.',
      data: RpcFailureDto(
        code: RpcErrorCodes.internalError,
        details: <String, dynamic>{
          'method': method,
          'errorType': error.runtimeType.toString(),
          'traceId': traceId,
        },
      ).toJson(),
    );
  }

  void send(OutboundNotification event) {
    _peer.sendNotification(event.notification.name, event.payload);
  }

  Future<void> close() async {
    await _peer.close();
    onClosed();
  }
}
