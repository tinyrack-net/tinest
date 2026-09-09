import 'dart:async';

import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:daemon/src/transport/http/attachment_binding.dart';
import 'package:daemon/src/transport/rpc/binding.dart';
import 'package:daemon/src/transport/rpc/diagnostics.dart';
import 'package:daemon/src/transport/rpc/server.dart';
import 'package:json_rpc_2/json_rpc_2.dart' as json_rpc;
import 'package:protocol/protocol.dart';
import 'package:shelf/shelf.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

void main() {
  test(
    'an unhandled handler error is reported before it becomes internal_error',
    () async {
      final diagnostics = _RecordingDiagnostics();
      final failure = StateError('worktree store is unavailable');
      final server = _server(
        diagnostics: diagnostics,
        onCatalog: () => throw failure,
      );
      addTearDown(server.close);

      final peer = _connect(server);
      await peer.sendRequest(systemHelloProcedure.name, _hello);
      final error = await _expectRpcException(
        peer.sendRequest(
          workspacesCatalogProcedure.name,
          const <String, dynamic>{},
        ),
      );

      // The client still learns nothing about the daemon's internals.
      final failureDto = RpcFailureDto.fromJson(
        error.data! as Map<String, dynamic>,
      );
      expect(failureDto.code, RpcErrorCodes.internalError);
      expect(error.message, isNot(contains('worktree store')));
      expect(failureDto.details.values, isNot(contains('worktree store')));

      // It does learn what failed and gets the one token that ties a user's
      // report to the record below, so the same failure is diagnosable from
      // a screenshot rather than only from a CI log.
      expect(failureDto.details['method'], workspacesCatalogProcedure.name);
      expect(failureDto.details['errorType'], 'StateError');
      expect(failureDto.details['traceId'], 'trace-0');

      // The daemon does: without this a failure seen once in CI names neither
      // the method nor the cause.
      expect(diagnostics.reports, hasLength(1));
      expect(
        diagnostics.reports.single.method,
        workspacesCatalogProcedure.name,
      );
      expect(diagnostics.reports.single.error, same(failure));
      expect(diagnostics.reports.single.stackTrace.toString(), isNotEmpty);
      expect(diagnostics.reports.single.traceId, 'trace-0');
    },
    tags: const <String>['feature_test__daemon_management__unit'],
  );

  test(
    'a typed feature failure reaches the client and is not reported',
    () async {
      final diagnostics = _RecordingDiagnostics();
      final server = _server(
        diagnostics: diagnostics,
        onCatalog: () => throw const RpcFailureException(
          code: 'workspace_missing',
          message: 'No such workspace.',
        ),
      );
      addTearDown(server.close);

      final peer = _connect(server);
      await peer.sendRequest(systemHelloProcedure.name, _hello);
      final error = await _expectRpcException(
        peer.sendRequest(
          workspacesCatalogProcedure.name,
          const <String, dynamic>{},
        ),
      );

      expect(
        RpcFailureDto.fromJson(error.data! as Map<String, dynamic>).code,
        'workspace_missing',
      );
      expect(diagnostics.reports, isEmpty);
    },
    tags: const <String>['feature_test__daemon_management__unit'],
  );
}

final Map<String, dynamic> _hello = systemHelloProcedure.encodeParams(
  const HelloParamsDto(
    protocolMajor: tinestProtocolMajor,
    clientId: 'diagnostics-test',
    clientKind: 'test',
    capabilities: <String, bool>{},
  ),
);

DaemonRpcServer _server({
  required RpcDiagnostics diagnostics,
  required WorkspaceCatalogResultDto Function() onCatalog,
}) => DaemonRpcServer(
  bindings: RpcBindingRegistry(
    <RpcBindingDescriptor>[
      RpcBinding<EmptyParamsDto, WorkspaceCatalogResultDto>(
        workspacesCatalogProcedure,
        (_, _) async => onCatalog(),
      ),
    ],
    procedures: <RpcProcedureDescriptor>[workspacesCatalogProcedure],
  ),
  attachments: _StubAttachments(),
  serverInfo: const ServerInfoDto(
    serverId: 'diagnostics',
    version: 'test',
    protocolVersion: tinestProtocolMajor,
    features: <String, bool>{},
  ),
  token: 'token',
  events: const Stream<OutboundNotification>.empty(),
  ids: _FixedIds(),
  diagnostics: diagnostics,
);

/// Opens one authenticated session and returns the client end of the channel.
json_rpc.Peer _connect(DaemonRpcServer server) {
  final controller = StreamChannelController<String>(allowForeignErrors: false);
  server.openSessionChannel(controller.foreign);
  final peer = json_rpc.Peer(controller.local);
  unawaited(peer.listen());
  addTearDown(peer.close);
  return peer;
}

Future<json_rpc.RpcException> _expectRpcException(Future<Object?> call) async {
  try {
    await call;
  } on json_rpc.RpcException catch (error) {
    return error;
  }
  fail('The call was expected to fail.');
}

final class _Report {
  const new(this.method, this.error, this.stackTrace, this.traceId);

  final String method;
  final Object error;
  final StackTrace stackTrace;
  final String traceId;
}

final class _RecordingDiagnostics implements RpcDiagnostics {
  final List<_Report> reports = <_Report>[];

  @override
  void unhandledError(
    String method,
    Object error,
    StackTrace stackTrace, {
    required String traceId,
  }) {
    reports.add(_Report(method, error, stackTrace, traceId));
  }
}

final class _FixedIds implements IdGenerator {
  var _next = 0;

  @override
  String generate() => 'trace-${_next++}';
}

final class _StubAttachments implements AttachmentHttpBinding {
  @override
  bool matches(Request request) => false;

  @override
  Future<Response> call(Request request, Map<String, String> cors) async =>
      Response.notFound('Not found');
}
