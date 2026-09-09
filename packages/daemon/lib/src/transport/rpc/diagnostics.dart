import 'dart:io';

/// Reports errors the RPC boundary replaces with an opaque client failure.
///
/// The transport must never hand an internal error to a client, because the
/// message and stack can carry paths, tokens, and prompt text. Discarding it
/// entirely is the other extreme: an `internal_error` alone names neither the
/// failing method nor the cause, so a failure seen once in CI cannot be
/// diagnosed at all. Every swallowed error goes through this port instead.
abstract interface class RpcDiagnostics {
  /// Reports [error] raised by [method] and converted into `internal_error`.
  ///
  /// [traceId] is the one token the client is given, so it has to appear in
  /// this record too: without it a user's screenshot cannot be matched to the
  /// stack trace that explains it.
  void unhandledError(
    String method,
    Object error,
    StackTrace stackTrace, {
    required String traceId,
  });
}

/// Writes unhandled RPC errors to the daemon's standard error stream.
final class StderrRpcDiagnostics implements RpcDiagnostics {
  /// Creates the standard-error diagnostics adapter.
  const new();

  @override
  void unhandledError(
    String method,
    Object error,
    StackTrace stackTrace, {
    required String traceId,
  }) {
    stderr
      ..writeln('Unhandled RPC error in $method [$traceId]: $error')
      ..writeln(stackTrace);
  }
}
