import 'dart:async';

import 'package:daemon/src/features/plugins/infrastructure/plugin_ports.dart';
import 'package:dio/dio.dart';

/// Dio-backed network adapter created only by the daemon composition root.
final class DioPluginNetworkGateway implements PluginNetworkGateway {
  /// Creates the adapter over a host-owned HTTP client.
  const new(this._dio);

  final Dio _dio;

  @override
  Future<PluginNetworkResponse> send(
    PluginNetworkRequest request,
    PluginOperationCancellation cancellation,
  ) async {
    final cancelToken = CancelToken();
    cancellation.onCancel(() {
      if (!cancelToken.isCancelled) {
        cancelToken.cancel('Plugin invocation cancelled.');
      }
    });
    if (cancellation.isCancelled) {
      throw const PluginHostOperationCancelledException();
    }
    var deadlineExceeded = false;
    final deadline = Timer(request.timeout, () {
      deadlineExceeded = true;
      if (!cancelToken.isCancelled) {
        cancelToken.cancel('Plugin network deadline exceeded.');
      }
    });
    try {
      final response = await _dio.requestUri<ResponseBody>(
        request.uri,
        data: request.body.isEmpty ? null : request.body,
        options: Options(
          method: request.method,
          headers: request.headers,
          responseType: ResponseType.stream,
          followRedirects: false,
          validateStatus: (_) => true,
          sendTimeout: request.timeout,
          receiveTimeout: request.timeout,
        ),
        cancelToken: cancelToken,
      );
      final responseBody = response.data;
      if (responseBody == null) {
        throw const FormatException('Plugin network response has no body.');
      }
      final bytes = <int>[];
      await for (final chunk in responseBody.stream) {
        if (cancellation.isCancelled) {
          throw const PluginHostOperationCancelledException();
        }
        if (bytes.length + chunk.length > request.maximumResponseBytes) {
          if (!cancelToken.isCancelled) {
            cancelToken.cancel('Plugin network response limit exceeded.');
          }
          throw const FormatException(
            'Plugin network response body exceeds the selected limit.',
          );
        }
        bytes.addAll(chunk);
      }
      return PluginNetworkResponse(
        statusCode: response.statusCode ?? 0,
        headers: <String, List<String>>{
          for (final entry in response.headers.map.entries)
            entry.key.toLowerCase(): entry.value,
        },
        body: bytes,
      );
    } on DioException catch (error) {
      if (cancellation.isCancelled) {
        throw const PluginHostOperationCancelledException();
      }
      if (deadlineExceeded && error.type == DioExceptionType.cancel) {
        throw const PluginNetworkTransportException('deadline');
      }
      throw PluginNetworkTransportException(error.type.name);
    } finally {
      deadline.cancel();
    }
  }
}

/// Bounded transport diagnostic that never includes URLs, headers, or bodies.
final class PluginNetworkTransportException implements Exception {
  /// Creates a transport failure from a stable Dio classification.
  const new(this.kind);

  /// Stable failure kind without request data.
  final String kind;

  @override
  String toString() => 'Plugin network request failed: $kind';
}
