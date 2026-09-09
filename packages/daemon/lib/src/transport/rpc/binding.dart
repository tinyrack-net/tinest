import 'package:protocol/protocol.dart';

/// Type-erased transport binding registered by a feature module.
abstract interface class RpcBindingDescriptor {
  /// Procedure implemented by this binding.
  RpcProcedureDescriptor get procedure;

  /// Decodes, invokes, and encodes one request.
  Future<Map<String, dynamic>> invoke(
    Map<String, dynamic> params,
    RpcConnectionContext context,
  );
}

/// Per-connection state made available to feature RPC handlers.
final class RpcConnectionContext {
  /// Session IDs whose timeline notifications this connection receives.
  final Set<String> timelineSubscriptions = <String>{};
}

/// Stable feature failure safe to expose at the transport boundary.
final class RpcFailureException implements Exception {
  /// Creates a sanitized failure.
  const new({
    required this.code,
    required this.message,
    this.retryable = false,
    this.details,
  });

  /// Stable machine-readable error code.
  final String code;

  /// User-safe error message.
  final String message;

  /// Whether retrying without changing the request can succeed.
  final bool retryable;

  /// Optional structured, non-sensitive context.
  final Map<String, dynamic>? details;
}

/// Connects one typed protocol procedure to a typed feature handler.
final class RpcBinding<P extends Object, R extends Object>
    implements RpcBindingDescriptor {
  /// Creates a typed binding.
  const new(this.typedProcedure, this.handler);

  /// Typed procedure implemented by the handler.
  final RpcProcedure<P, R> typedProcedure;

  /// Feature handler invoked after decoding.
  final Future<R> Function(P, RpcConnectionContext) handler;

  @override
  RpcProcedureDescriptor get procedure => typedProcedure;

  @override
  Future<Map<String, dynamic>> invoke(
    Map<String, dynamic> params,
    RpcConnectionContext context,
  ) async => typedProcedure.encodeResult(
    await handler(typedProcedure.decodeParams(params), context),
  );
}

/// Immutable registry assembled from feature-owned bindings.
final class RpcBindingRegistry {
  /// Creates a registry and rejects duplicate or incomplete catalogs.
  new(
    Iterable<RpcBindingDescriptor> bindings, {
    required Iterable<RpcProcedureDescriptor> procedures,
  }) : _bindings = <String, RpcBindingDescriptor>{
         for (final binding in bindings) binding.procedure.name: binding,
       } {
    final items = bindings.toList(growable: false);
    if (_bindings.length != items.length) {
      throw StateError('RPC bindings contain duplicate procedure names.');
    }
    final expected = procedures.map((item) => item.name).toSet();
    if (_bindings.keys.toSet().difference(expected).isNotEmpty ||
        expected.difference(_bindings.keys.toSet()).isNotEmpty) {
      throw StateError('RPC bindings do not exactly implement the catalog.');
    }
  }

  final Map<String, RpcBindingDescriptor> _bindings;

  /// Descriptors registered exactly once by this daemon.
  Iterable<RpcProcedureDescriptor> get procedures =>
      _bindings.values.map((binding) => binding.procedure);

  /// Invokes the binding named by [method].
  Future<Map<String, dynamic>> invoke(
    String method,
    Map<String, dynamic> params,
    RpcConnectionContext context,
  ) {
    final binding = _bindings[method];
    if (binding == null) {
      throw RpcFailureException(
        code: 'unknown_method',
        message: 'Unknown RPC method: $method',
      );
    }
    return binding.invoke(params, context);
  }
}

/// One typed notification ready to cross the JSON-RPC transport boundary.
final class OutboundNotification {
  /// Creates an outbound notification.
  const new(this.notification, this.event);

  /// Descriptor that owns the notification name and codec.
  final RpcNotificationDescriptor notification;

  /// Typed event accepted by [notification].
  final Object event;

  /// Encoded protocol payload.
  Map<String, dynamic> get payload => notification.encodeObject(event);
}
