import 'dart:async';
import 'dart:io' show FileSystemException;

import 'package:daemon/src/shared/ports/request_cancellation.dart';

/// Core-owned effect floor for one host primitive.
///
/// Lua contributions may request stricter handling, but cannot lower this
/// classification when the capability broker evaluates a call.
enum HostPrimitiveEffect {
  /// Does not mutate host state.
  read,

  /// Mutates workspace or durable host state.
  write,

  /// Starts or controls a process.
  command,

  /// Has an effect that cannot be safely classified more narrowly.
  dangerous,
}

/// Safety metadata for one primitive exposed to Lua.
///
/// This deliberately has no model-facing name, description, JSON schema, or
/// presentation. Those belong to the Lua contribution that composes it.
final class HostPrimitiveDescriptor {
  /// Creates primitive safety metadata.
  const new({
    required this.operation,
    required this.capability,
    required this.effect,
    this.luaInputType = 'any',
    this.luaOutputType = 'any',
  });

  /// Stable SDK operation identifier.
  final String operation;

  /// Capability required before arguments are decoded.
  final String capability;

  /// Minimum host-enforced effect classification.
  final HostPrimitiveEffect effect;

  /// LuaCATS input type generated into the public authoring SDK.
  final String luaInputType;

  /// LuaCATS output type generated into the public authoring SDK.
  final String luaOutputType;

  /// Whether every safety and authoring field matches [other].
  bool matches(HostPrimitiveDescriptor other) =>
      operation == other.operation &&
      capability == other.capability &&
      effect == other.effect &&
      luaInputType == other.luaInputType &&
      luaOutputType == other.luaOutputType;

  /// Returns the public descriptor used to generate the Lua host surface.
  Map<String, Object?> toJson() => <String, Object?>{
    'operation': operation,
    'capability': capability,
    'effect': effect.name,
    'luaInputType': luaInputType,
    'luaOutputType': luaOutputType,
  };
}

/// Invocation-local identity and effective grant set.
final class HostPrimitiveContext {
  /// Creates a host primitive invocation context.
  const new({
    required this.pluginId,
    required this.agentId,
    required this.sessionId,
    required this.workspaceRoot,
    required this.allowedCapabilities,
    this.workspaceId,
    this.revisionHash,
    this.callId,
    this.cancellation,
  });

  /// Plugin owning the calling contribution.
  final String pluginId;

  /// Agent definition selecting the plugin.
  final String agentId;

  /// Session owning the invocation.
  final String sessionId;

  /// Optional stable workspace identity.
  final String? workspaceId;

  /// Absolute workspace root selected by the host.
  final String workspaceRoot;

  /// Exact plugin execution revision, when available.
  final String? revisionHash;

  /// Invocation-local model tool call identity, when a tool owns this call.
  ///
  /// Lifecycle and other direct plugin host calls have no model tool call and
  /// therefore leave this unset.
  final String? callId;

  /// Capabilities remaining after every broker restriction.
  final Set<String> allowedCapabilities;

  /// Cancellation signal for a live host operation.
  final HostPrimitiveCancellation? cancellation;
}

/// Minimal cancellation contract available at the primitive boundary.
abstract interface class HostPrimitiveCancellation
    implements RequestCancellation {
  /// Whether cancellation has already been requested.
  @override
  bool get isCancelled;

  /// Registers cleanup to run when cancellation is requested.
  @override
  void onCancel(void Function() callback);
}

/// Stable structured failure returned across the Lua boundary.
final class HostPrimitiveError {
  /// Creates a primitive failure.
  const new({
    required this.code,
    required this.message,
    required this.retryable,
    this.details,
  });

  /// Machine-readable error code owned by the primitive contract.
  final String code;

  /// User-safe diagnostic message.
  final String message;

  /// Whether retrying the same operation may succeed.
  final bool retryable;

  /// Optional JSON-compatible structured detail.
  final Object? details;

  /// Encodes this error for the public Lua result envelope.
  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'message': message,
    'retryable': retryable,
    if (details != null) 'details': details,
  };
}

/// Opaque host-owned value emitted alongside a JSON primitive result.
final class HostPrimitiveResource {
  /// Creates an opaque resource descriptor.
  const new({
    required this.value,
    required this.fileName,
    required this.mimeType,
    required this.byteSize,
  });

  /// Consumer-owned value that never enters Lua serialization.
  final Object value;

  /// Safe display filename.
  final String fileName;

  /// Declared media type.
  final String mimeType;

  /// Byte length used for host quotas and presentation.
  final int byteSize;
}

/// Complete output of a primitive implementation before wire encoding.
final class HostPrimitiveOutput<T> {
  /// Creates an output with optional opaque resources and notifications.
  const new({
    required this.value,
    this.resources = const <HostPrimitiveResource>[],
    this.notifications = const <Object?>[],
  });

  /// JSON-compatible value returned to Lua.
  final T value;

  /// Opaque host values registered with the Lua invocation.
  final List<HostPrimitiveResource> resources;

  /// Host audit notifications emitted by the operation.
  final List<Object?> notifications;
}

/// Result of invoking one capability-brokered host primitive.
final class HostPrimitiveResult<T> {
  const new _({
    this.value,
    this.error,
    this.resources = const <HostPrimitiveResource>[],
    this.notifications = const <Object?>[],
  });

  /// Creates a successful result.
  const new success(
    T value, {
    List<HostPrimitiveResource> resources = const <HostPrimitiveResource>[],
    List<Object?> notifications = const <Object?>[],
  }) : this._(value: value, resources: resources, notifications: notifications);

  /// Creates a failed result.
  const new failure(HostPrimitiveError error) : this._(error: error);

  /// Successful decoded value.
  final T? value;

  /// Structured failure, if any.
  final HostPrimitiveError? error;

  /// Opaque resources emitted by the successful operation.
  final List<HostPrimitiveResource> resources;

  /// Audit notifications emitted by the successful operation.
  final List<Object?> notifications;

  /// Whether the operation completed successfully.
  bool get ok => error == null;

  /// Encodes the stable result envelope consumed by Lua.
  Map<String, Object?> toJson() => ok
      ? <String, Object?>{'ok': true, 'value': value}
      : <String, Object?>{'ok': false, 'error': error!.toJson()};
}

/// Expected primitive failure raised by an implementation.
final class HostPrimitiveException implements Exception {
  /// Creates an expected structured failure.
  const new(this.error);

  /// Failure returned to Lua.
  final HostPrimitiveError error;

  @override
  String toString() => '${error.code}: ${error.message}';
}

/// Typed decoder for a primitive's public JSON-compatible input.
typedef HostPrimitiveDecoder<I> = I Function(Object? value);

/// Host-owned approval summary derived from decoded primitive input.
///
/// This is safety UI, not model-facing tool presentation. Keeping it on the
/// primitive lets the broker describe the exact low-level effect that is about
/// to run without teaching the harness operation-specific argument shapes.
typedef HostPrimitiveApprovalPreview<I> = String? Function(I arguments);

/// Typed implementation of a host primitive.
typedef HostPrimitiveInvoker<I, O> = FutureOr<O> Function(
  I arguments,
  HostPrimitiveContext context,
);

/// Typed implementation that also emits opaque resources or notifications.
typedef HostPrimitiveOutputInvoker<I, O> =
    FutureOr<HostPrimitiveOutput<O>> Function(
      I arguments,
      HostPrimitiveContext context,
    );

/// One immutable public contract shared by native binding and SDK generation.
///
/// It deliberately contains only safety metadata and Lua boundary type names;
/// model-facing tool names, descriptions, schemas, defaults, and presentation
/// remain owned by Lua contributions.
final class HostPrimitiveContract<I, O> {
  /// Creates one public host primitive contract.
  const new({
    required this.operation,
    required this.capability,
    required this.effect,
    required this.luaInputType,
    required this.luaOutputType,
  });

  /// Stable host operation identifier.
  final String operation;

  /// Capability checked before decoding input.
  final String capability;

  /// Minimum host-enforced effect classification.
  final HostPrimitiveEffect effect;

  /// LuaCATS type accepted by the generated host wrapper.
  final String luaInputType;

  /// LuaCATS type returned inside the structured result envelope.
  final String luaOutputType;

  /// Detached descriptor preserved by a bound registry entry.
  HostPrimitiveDescriptor get descriptor => HostPrimitiveDescriptor(
    operation: operation,
    capability: capability,
    effect: effect,
    luaInputType: luaInputType,
    luaOutputType: luaOutputType,
  );

  /// Binds a typed implementation without repeating contract metadata.
  HostPrimitive<I, O> bind({
    required HostPrimitiveDecoder<I> decode,
    required HostPrimitiveInvoker<I, O> invoke,
    HostPrimitiveApprovalPreview<I>? approvalPreview,
  }) =>
      HostPrimitive<I, O>._(descriptor, decode, invoke, null, approvalPreview);

  /// Binds an implementation that emits opaque resources or notifications.
  HostPrimitive<I, O> bindOutput({
    required HostPrimitiveDecoder<I> decode,
    required HostPrimitiveOutputInvoker<I, O> invoke,
    HostPrimitiveApprovalPreview<I>? approvalPreview,
  }) =>
      HostPrimitive<I, O>._(descriptor, decode, null, invoke, approvalPreview);
}

/// One typed, model-agnostic host operation.
final class HostPrimitive<I, O> {
  /// Creates a primitive whose decoder runs only after capability approval.
  factory({
    required String operation,
    required String capability,
    required HostPrimitiveEffect effect,
    required HostPrimitiveDecoder<I> decode,
    required HostPrimitiveInvoker<I, O> invoke,
    HostPrimitiveApprovalPreview<I>? approvalPreview,
    String luaInputType = 'any',
    String luaOutputType = 'any',
  }) => HostPrimitive<I, O>._(
    HostPrimitiveDescriptor(
      operation: operation,
      capability: capability,
      effect: effect,
      luaInputType: luaInputType,
      luaOutputType: luaOutputType,
    ),
    decode,
    invoke,
    null,
    approvalPreview,
  );

  /// Creates a primitive that emits opaque resources or notifications.
  factory output({
    required String operation,
    required String capability,
    required HostPrimitiveEffect effect,
    required HostPrimitiveDecoder<I> decode,
    required HostPrimitiveOutputInvoker<I, O> invoke,
    HostPrimitiveApprovalPreview<I>? approvalPreview,
    String luaInputType = 'any',
    String luaOutputType = 'any',
  }) => HostPrimitive<I, O>._(
    HostPrimitiveDescriptor(
      operation: operation,
      capability: capability,
      effect: effect,
      luaInputType: luaInputType,
      luaOutputType: luaOutputType,
    ),
    decode,
    null,
    invoke,
    approvalPreview,
  );

  new _(
    this.descriptor,
    this._decode,
    this._invoke,
    this._invokeOutput,
    this._approvalPreview,
  );

  /// Safety-only public descriptor.
  final HostPrimitiveDescriptor descriptor;
  final HostPrimitiveDecoder<I> _decode;
  final HostPrimitiveInvoker<I, O>? _invoke;
  final HostPrimitiveOutputInvoker<I, O>? _invokeOutput;
  final HostPrimitiveApprovalPreview<I>? _approvalPreview;

  /// Type-erased form stored by a heterogeneous registry.
  HostPrimitive<Object?, Object?> get erased {
    final outputInvoker = _invokeOutput;
    if (outputInvoker != null) {
      return HostPrimitive<Object?, Object?>._(
        descriptor,
        _decode,
        null,
        (arguments, context) async {
          final output = await outputInvoker(arguments as I, context);
          return HostPrimitiveOutput<Object?>(
            value: output.value,
            resources: output.resources,
            notifications: output.notifications,
          );
        },
        _approvalPreview == null
            ? null
            : (arguments) => _approvalPreview(arguments as I),
      );
    }
    final valueInvoker = _invoke!;
    return HostPrimitive<Object?, Object?>._(
      descriptor,
      _decode,
      (arguments, context) => valueInvoker(arguments as I, context),
      null,
      _approvalPreview == null
          ? null
          : (arguments) => _approvalPreview(arguments as I),
    );
  }

  String? _preview(Object? arguments) {
    final preview = _approvalPreview;
    if (preview == null) return null;
    try {
      return preview(_decode(arguments));
    } on FormatException {
      return null;
    }
  }

  Future<HostPrimitiveResult<Object?>> _execute(
    Object? arguments,
    HostPrimitiveContext context,
  ) async {
    if (context.cancellation?.isCancelled ?? false) {
      return const HostPrimitiveResult<Object?>.failure(
        HostPrimitiveError(
          code: 'cancelled',
          message: 'Host primitive invocation was cancelled.',
          retryable: false,
        ),
      );
    }
    try {
      final decoded = _decode(arguments);
      final outputInvoker = _invokeOutput;
      if (outputInvoker != null) {
        final output = await outputInvoker(decoded, context);
        return HostPrimitiveResult<Object?>.success(
          output.value,
          resources: output.resources,
          notifications: output.notifications,
        );
      }
      final value = await _invoke!(decoded, context);
      return HostPrimitiveResult<Object?>.success(value);
    } on HostPrimitiveException catch (error) {
      return HostPrimitiveResult<Object?>.failure(error.error);
    } on FormatException catch (error) {
      return HostPrimitiveResult<Object?>.failure(
        HostPrimitiveError(
          code: 'invalid_arguments',
          message: error.message,
          retryable: false,
        ),
      );
    } on FileSystemException catch (error) {
      return HostPrimitiveResult<Object?>.failure(
        HostPrimitiveError(
          code: 'filesystem_error',
          message: error.message,
          retryable: false,
          details: <String, Object?>{
            if (error.path != null) 'path': error.path,
          },
        ),
      );
    }
  }
}

/// Registry and capability gate for every Lua-accessible host primitive.
final class HostPrimitiveRegistry {
  /// Creates a registry, rejecting ambiguous operation identifiers.
  factory(List<HostPrimitive<Object?, Object?>> primitives) {
    final byOperation = <String, HostPrimitive<Object?, Object?>>{};
    for (final primitive in primitives) {
      final operation = primitive.descriptor.operation;
      if (byOperation.containsKey(operation)) {
        throw StateError('Two host primitives claim the operation $operation.');
      }
      byOperation[operation] = primitive;
    }
    return HostPrimitiveRegistry._(Map.unmodifiable(byOperation));
  }

  /// Creates a registry with no host operations.
  factory empty() =>
      HostPrimitiveRegistry(const <HostPrimitive<Object?, Object?>>[]);

  const new _(this._byOperation);

  final Map<String, HostPrimitive<Object?, Object?>> _byOperation;

  /// Returns an immutable registry with additional turn-scoped bindings.
  ///
  /// Existing operation identifiers cannot be shadowed. This lets composition
  /// roots add session-specific ports, such as network and secret access,
  /// without bypassing the common descriptor, capability, and result path.
  HostPrimitiveRegistry withPrimitives(
    List<HostPrimitive<Object?, Object?>> primitives,
  ) => HostPrimitiveRegistry(<HostPrimitive<Object?, Object?>>[
    ..._byOperation.values,
    ...primitives,
  ]);

  /// Safety descriptors in deterministic operation order.
  List<HostPrimitiveDescriptor> get descriptors {
    final values = <HostPrimitiveDescriptor>[
      for (final primitive in _byOperation.values) primitive.descriptor,
    ]..sort((left, right) => left.operation.compareTo(right.operation));
    return List<HostPrimitiveDescriptor>.unmodifiable(values);
  }

  /// Looks up the descriptor without exposing an implementation closure.
  HostPrimitiveDescriptor? descriptor(String operation) =>
      _byOperation[operation]?.descriptor;

  /// Builds host-owned approval text for the exact primitive input.
  String? approvalPreview(String operation, Object? arguments) =>
      _byOperation[operation]?._preview(arguments);

  /// Invokes an operation through the capability gate.
  Future<HostPrimitiveResult<Object?>> invoke(
    String operation,
    Object? arguments,
    HostPrimitiveContext context,
  ) async {
    final primitive = _byOperation[operation];
    if (primitive == null) {
      return HostPrimitiveResult<Object?>.failure(
        HostPrimitiveError(
          code: 'primitive_not_found',
          message: 'Host primitive is unavailable: $operation',
          retryable: false,
        ),
      );
    }
    if (!context.allowedCapabilities.contains(
      primitive.descriptor.capability,
    )) {
      return HostPrimitiveResult<Object?>.failure(
        HostPrimitiveError(
          code: 'capability_denied',
          message:
              'Capability ${primitive.descriptor.capability} is not granted.',
          retryable: false,
        ),
      );
    }
    return await primitive._execute(arguments, context);
  }
}
