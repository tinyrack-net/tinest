/// Type-erased view used to register a heterogeneous procedure catalog.
abstract interface class RpcProcedureDescriptor {
  /// Stable JSON-RPC method name.
  String get name;

  /// Runtime request type retained after generic erasure.
  Type get paramsType;

  /// Runtime result type retained after generic erasure.
  Type get resultType;

  /// Decodes request parameters after generic erasure.
  Object decodeParamsObject(Map<String, dynamic> json);

  /// Encodes request parameters after generic erasure.
  Map<String, dynamic> encodeParamsObject(Object value);

  /// Decodes a result after generic erasure.
  Object decodeResultObject(Map<String, dynamic> json);

  /// Encodes a result after generic erasure.
  Map<String, dynamic> encodeResultObject(Object value);
}

/// A typed JSON-RPC procedure shared by client and daemon transports.
final class RpcProcedure<P extends Object, R extends Object>
    implements RpcProcedureDescriptor {
  /// Creates a procedure descriptor.
  const new({
    required this.name,
    required this.decodeParams,
    required this.encodeParams,
    required this.decodeResult,
    required this.encodeResult,
  });

  @override
  final String name;

  /// Decodes request parameters.
  final P Function(Map<String, dynamic>) decodeParams;

  /// Encodes request parameters.
  final Map<String, dynamic> Function(P) encodeParams;

  /// Decodes a successful result.
  final R Function(Map<String, dynamic>) decodeResult;

  /// Encodes a successful result.
  final Map<String, dynamic> Function(R) encodeResult;

  @override
  Type get paramsType => P;
  @override
  Type get resultType => R;
  @override
  Object decodeParamsObject(Map<String, dynamic> json) => decodeParams(json);
  @override
  Map<String, dynamic> encodeParamsObject(Object value) =>
      encodeParams(value as P);
  @override
  Object decodeResultObject(Map<String, dynamic> json) => decodeResult(json);
  @override
  Map<String, dynamic> encodeResultObject(Object value) =>
      encodeResult(value as R);
}

/// Type-erased view used to register heterogeneous notifications.
abstract interface class RpcNotificationDescriptor {
  /// Stable JSON-RPC notification name.
  String get name;

  /// Runtime event type retained after generic erasure.
  Type get eventType;

  /// Decodes an event after generic erasure.
  Object decodeObject(Map<String, dynamic> json);

  /// Encodes an event after generic erasure.
  Map<String, dynamic> encodeObject(Object value);
}

/// A typed JSON-RPC notification shared by transport adapters.
final class RpcNotification<E extends Object>
    implements RpcNotificationDescriptor {
  /// Creates a notification descriptor.
  const new({required this.name, required this.decode, required this.encode});

  @override
  final String name;

  /// Decodes an event payload.
  final E Function(Map<String, dynamic>) decode;

  /// Encodes an event payload.
  final Map<String, dynamic> Function(E) encode;

  @override
  Type get eventType => E;
  @override
  Object decodeObject(Map<String, dynamic> json) => decode(json);
  @override
  Map<String, dynamic> encodeObject(Object value) => encode(value as E);
}
