import 'dart:async';
import 'dart:convert';

import 'package:daemon/src/features/plugins/infrastructure/plugin_bundles.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_ports.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_registration.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_sdk.dart';
import 'package:lua_tool_runtime/lua_tool_runtime.dart' as lua;
import 'package:protocol/protocol.dart';

export 'plugin_registration.dart';
export 'plugin_sdk.dart';

/// Validated document returned by the constructor-only Lua UI SDK.
final class PluginUiCallbackDocument {
  /// Creates a normalized immutable UI callback result.
  new({
    required Map<String, dynamic> root,
    required Set<String> actionIds,
    required this.constructorOwned,
  }) : root = Map<String, dynamic>.unmodifiable(root),
       actionIds = Set<String>.unmodifiable(actionIds);

  /// Declarative root retained by the host as the immutable snapshot.
  final Map<String, dynamic> root;

  /// Exact revision-local action bindings referenced by [root].
  final Set<String> actionIds;

  /// Whether [root] came from opaque SDK constructors.
  ///
  /// Raw documents remain renderable through the generic fallback, but can
  /// never publish actions.
  final bool constructorOwned;
}

/// Safe rejection while decoding a Lua UI callback result.
final class PluginUiCallbackDocumentException extends FormatException {
  /// Creates a UI callback validation failure.
  new(super.message);
}

/// Expected refusal to run Lua after its runtime or session was torn down.
///
/// Typed rather than a bare `StateError` so a transport can answer with a code
/// the client can translate. A shutting-down daemon, a cancelled turn, and a
/// detached Agent all reach this legitimately; an escaping `StateError` would
/// arrive as `internal_error`, which the protocol reserves for defects.
final class PluginRuntimeClosed implements Exception {
  /// Creates a closed-runtime refusal.
  const new(this.message);

  /// User-safe reason.
  final String message;

  @override
  String toString() => 'PluginRuntimeClosed: $message';
}

/// Decodes the private SDK UI envelope and proves every action belongs to the
/// same plugin revision that produced the document.
PluginUiCallbackDocument decodePluginUiCallbackDocument(
  Object? value, {
  required String pluginId,
  required Set<String> registeredActionIds,
}) {
  final envelope = _pluginUiObject(value, label: 'UI callback result');
  final ownership = envelope['__tinest_ui_document'];
  final root = _pluginUiObject(envelope['root'], label: 'UI document root');
  final referenced = _pluginUiActionIds(root);
  if (ownership == 'raw') {
    if (referenced.isNotEmpty) {
      throw PluginUiCallbackDocumentException(
        'Raw plugin UI documents cannot declare actions.',
      );
    }
    return PluginUiCallbackDocument(
      root: root,
      actionIds: const <String>{},
      constructorOwned: false,
    );
  }
  if (ownership != 'constructor') {
    throw PluginUiCallbackDocumentException(
      'Plugin UI callback did not return an SDK document envelope.',
    );
  }
  final rawActions = envelope['actions'];
  if (rawActions is! List<Object?>) {
    throw PluginUiCallbackDocumentException(
      'Constructor-owned UI documents require an action reference list.',
    );
  }
  final declared = <String>{};
  for (final rawAction in rawActions) {
    if (rawAction is! String || rawAction.isEmpty || !declared.add(rawAction)) {
      throw PluginUiCallbackDocumentException(
        'Plugin UI action references must be unique non-empty strings.',
      );
    }
    if (!rawAction.startsWith('$pluginId/')) {
      throw PluginUiCallbackDocumentException(
        'Plugin UI action belongs to another plugin: $rawAction',
      );
    }
    if (!registeredActionIds.contains(rawAction)) {
      throw PluginUiCallbackDocumentException(
        'Plugin UI action is not registered in this revision: $rawAction',
      );
    }
  }
  if (!_stringSetEquals(declared, referenced)) {
    throw PluginUiCallbackDocumentException(
      'Plugin UI action references do not match the constructor snapshot.',
    );
  }
  return PluginUiCallbackDocument(
    root: root,
    actionIds: declared,
    constructorOwned: true,
  );
}

Map<String, dynamic> _pluginUiObject(Object? value, {required String label}) {
  final normalized = _pluginUiJson(value, depth: 0);
  if (normalized is Map<String, dynamic>) return normalized;
  throw PluginUiCallbackDocumentException('$label must be an object.');
}

Object? _pluginUiJson(Object? value, {required int depth}) {
  if (depth > 32) {
    throw PluginUiCallbackDocumentException(
      'Plugin UI document exceeds 32 levels.',
    );
  }
  if (value == null || value is String || value is bool || value is num) {
    return value;
  }
  if (value is List<Object?>) {
    return List<Object?>.unmodifiable(
      value.map((item) => _pluginUiJson(item, depth: depth + 1)),
    );
  }
  if (value case final Map<Object?, Object?> map) {
    if (!map.keys.every((key) => key is String)) {
      throw PluginUiCallbackDocumentException(
        'Plugin UI document object keys must be strings.',
      );
    }
    return Map<String, dynamic>.unmodifiable(<String, dynamic>{
      for (final entry in map.entries)
        entry.key! as String: _pluginUiJson(entry.value, depth: depth + 1),
    });
  }
  throw PluginUiCallbackDocumentException(
    'Plugin UI document must be JSON-compatible.',
  );
}

Set<String> _pluginUiActionIds(Object? value) {
  final result = <String>{};
  void visit(Object? candidate) {
    if (candidate is List<Object?>) {
      candidate.forEach(visit);
      return;
    }
    if (candidate is! Map<String, dynamic>) return;
    for (final entry in candidate.entries) {
      if (entry.key == 'actionId') {
        if (entry.value is! String || (entry.value! as String).isEmpty) {
          throw PluginUiCallbackDocumentException(
            'Plugin UI actionId must be a non-empty string.',
          );
        }
        result.add(entry.value! as String);
      }
      visit(entry.value);
    }
  }

  visit(value);
  return result;
}

bool _stringSetEquals(Set<String> left, Set<String> right) =>
    left.length == right.length && left.containsAll(right);

String _canonicalRegistration(PluginRegistration registration) => jsonEncode(
  <String, Object?>{
    'descriptor': registration.descriptor.toJson(),
    'driver': registration.driver == null
        ? null
        : <String, Object?>{
            'id': registration.driver!.id,
            'binding': registration.driver!.binding.internalKey,
            'declaredOperations': registration.driver!.declaredOperations
                .toList(growable: false),
          },
    'tools': <Object?>[
      for (final tool in registration.tools)
        <String, Object?>{
          'id': tool.id,
          'binding': tool.binding.internalKey,
          'declaredOperations': tool.declaredOperations.toList(growable: false),
        },
    ],
    'templates': <Object?>[
      for (final template in registration.templates)
        <String, Object?>{
          'id': template.id,
          'binding': template.binding.internalKey,
          'declaredOperations': template.declaredOperations.toList(
            growable: false,
          ),
        },
    ],
    'hooks': <Object?>[
      for (final hook in registration.hooks)
        <String, Object?>{
          'id': hook.id,
          'binding': hook.binding.internalKey,
          'declaredOperations': hook.declaredOperations.toList(growable: false),
          'payloadSchema': hook.payloadSchema,
        },
    ],
    'sessionControls': <Object?>[
      for (final control in registration.sessionControls)
        <String, Object?>{
          'id': control.id,
          'binding': control.binding.internalKey,
          'declaredOperations': control.declaredOperations.toList(
            growable: false,
          ),
        },
    ],
    'ui': <Object?>[
      for (final contribution in registration.ui)
        <String, Object?>{
          'id': contribution.id,
          'binding': contribution.binding.internalKey,
          'declaredOperations': contribution.declaredOperations.toList(
            growable: false,
          ),
          'inputSchema': contribution.inputSchema,
        },
    ],
  },
);

/// Core capability decision applied before a Lua callback reaches a host port.
final class PluginCallAuthorization {
  /// Allows a callback when all [requiredCapabilities] remain effective.
  const new allowed({this.requiredCapabilities = const <String>{}})
    : allowed = true,
      reason = null;

  /// Denies a callback without invoking its host implementation.
  const new denied(this.reason)
    : allowed = false,
      requiredCapabilities = const <String>{};

  /// Whether the safety kernel approved this exact call.
  final bool allowed;

  /// Capabilities derived from the actual host primitive and effective risk.
  final Set<String> requiredCapabilities;

  /// User-safe denial reason.
  final String? reason;
}

/// Immutable identity and capability ceiling for one named-handler call.
final class PluginHostCallContext {
  /// Creates a callback context pinned to one plugin revision.
  new({
    required this.agentId,
    required this.sessionId,
    required this.workspaceId,
    required this.pluginId,
    required this.revisionHash,
    required Set<String> manifestCapabilities,
    required Set<String> effectiveCapabilities,
    required Set<String> handlerCapabilities,
    required Set<String> handlerOperations,
  }) : manifestCapabilities = Set<String>.unmodifiable(manifestCapabilities),
       effectiveCapabilities = Set<String>.unmodifiable(effectiveCapabilities),
       handlerCapabilities = Set<String>.unmodifiable(handlerCapabilities),
       handlerOperations = Set<String>.unmodifiable(handlerOperations);

  /// Agent definition selecting the plugin.
  final String agentId;

  /// Session owning this runtime.
  final String sessionId;

  /// Optional registered workspace identity.
  final String? workspaceId;

  /// Owning plugin ID.
  final String pluginId;

  /// Exact content hash pinned for this invocation.
  final String revisionHash;

  /// Manifest capability upper bound.
  final Set<String> manifestCapabilities;

  /// Manifest, Agent grant, and session restriction intersection.
  final Set<String> effectiveCapabilities;

  /// Capabilities declared by the contribution whose handler is running.
  final Set<String> handlerCapabilities;

  /// Exact SDK primitive operations referenced by the handler's `uses` list.
  final Set<String> handlerOperations;
}

/// Cancellation state supplied to an in-flight callback implementation.
abstract interface class PluginInvocationCancellation
    implements PluginOperationCancellation {
  /// Whether the owning Lua invocation has already been cancelled.
  @override
  bool get isCancelled;

  /// Registers cleanup that fires exactly when the invocation is cancelled.
  @override
  void onCancel(void Function() callback);
}

/// Cancellation signal supplied by the owner of a plugin invocation.
abstract interface class PluginCancellationSignal {
  /// Registers a callback invoked when the owning operation is cancelled.
  void onCancel(void Function() callback);
}

/// One opaque host resource that Lua may reference but never deserialize.
final class PluginOpaqueResource<T extends Object> {
  /// Creates an opaque callback resource.
  const new({
    required this.value,
    required this.fileName,
    required this.mimeType,
    required this.byteSize,
  });

  /// Consumer-owned resource value.
  final T value;

  /// Display filename.
  final String fileName;

  /// Resource MIME type.
  final String mimeType;

  /// Byte length without copying the resource into Lua.
  final int byteSize;
}

/// JSON-compatible result returned by a capability-brokered callback.
final class PluginCallbackResult<T extends Object> {
  /// Creates one callback result or stream event.
  const new({
    required this.value,
    this.isError = false,
    this.resources = const [],
  });

  /// JSON-compatible result value.
  final Object? value;

  /// Whether this value represents an application-level failure.
  final bool isError;

  /// Opaque resources registered alongside this result.
  final List<PluginOpaqueResource<T>> resources;
}

/// Safety-kernel boundary for every Lua SDK callback and model stream.
abstract interface class PluginCallbackRouter<T extends Object> {
  /// Resolves actual primitive risk, lifecycle restriction, and call approval.
  Future<PluginCallAuthorization> authorize(
    PluginHostCallContext context,
    String name,
    Map<String, Object?> arguments,
  );

  /// Executes one already-authorized unary callback.
  Future<PluginCallbackResult<T>> call(
    PluginHostCallContext context,
    String name,
    Map<String, Object?> arguments,
    PluginInvocationCancellation cancellation,
  );

  /// Opens one already-authorized provider or host event stream.
  Stream<PluginCallbackResult<T>> open(
    PluginHostCallContext context,
    String name,
    Map<String, Object?> arguments,
    PluginInvocationCancellation cancellation,
  );
}

/// Result after a named handler reaches a terminal state.
final class PluginInvocationResult<T extends Object> {
  /// Creates a completed invocation result.
  new({
    required this.pluginId,
    required this.revisionHash,
    required List<lua.LuaCellDelta<T>> deltas,
  }) : deltas = List<lua.LuaCellDelta<T>>.unmodifiable(deltas),
       rawDelta = deltas.last,
       output = deltas.map((delta) => delta.output).join();

  /// Owning plugin.
  final String pluginId;

  /// Exact executed composite revision hash, including the SDK ABI.
  final String revisionHash;

  /// Every raw upstream observation, in order.
  final List<lua.LuaCellDelta<T>> deltas;

  /// Terminal raw runtime delta.
  final lua.LuaCellDelta<T> rawDelta;

  /// Concatenated textual output from every observation.
  final String output;

  /// JSON-compatible named-handler result.
  Object? get result => rawDelta.result;

  /// Classified runtime failure, when the handler failed.
  lua.LuaRuntimeException? get error => rawDelta.error;

  /// Whether the owner explicitly terminated the invocation.
  bool get terminated => rawDelta.terminated;
}

/// A started named handler that may still require pull-based observation.
final class PluginInvocation<T extends Object> {
  new _({
    required this.pluginId,
    required this.revisionHash,
    required this._runtimeSession,
    required this._executionContext,
    required lua.LuaCellDelta<T> rawDelta,
  }) : rawDelta = rawDelta,
       _deltas = <lua.LuaCellDelta<T>>[rawDelta];

  /// Owning plugin.
  final String pluginId;

  /// Exact executed composite revision hash, including the SDK ABI.
  final String revisionHash;

  final lua.LuaRuntimeSession<T> _runtimeSession;
  final lua.LuaExecutionContext<T> _executionContext;
  final List<lua.LuaCellDelta<T>> _deltas;

  /// Most recent unmodified upstream delta.
  lua.LuaCellDelta<T> rawDelta;

  /// Whether this invocation remains live.
  bool get running => rawDelta.running;

  /// Observes, terminates, or resumes this invocation.
  Future<PluginInvocation<T>> wait({
    Duration yieldTime = const Duration(seconds: 10),
    int maxOutputTokens = 10000,
    bool terminate = false,
  }) async {
    if (!running) return this;
    rawDelta = await _runtimeSession.wait(
      lua.LuaWaitRequest(
        cellId: rawDelta.cellId,
        yieldTime: yieldTime,
        maxOutputTokens: maxOutputTokens,
        terminate: terminate,
      ),
      _executionContext,
    );
    _deltas.add(rawDelta);
    return this;
  }

  /// Drains the invocation until it reaches a terminal result.
  Future<PluginInvocationResult<T>> complete({
    Duration yieldTime = const Duration(seconds: 10),
    int maxOutputTokens = 10000,
  }) async {
    while (running) {
      await wait(yieldTime: yieldTime, maxOutputTokens: maxOutputTokens);
    }
    return PluginInvocationResult<T>(
      pluginId: pluginId,
      revisionHash: revisionHash,
      deltas: _deltas,
    );
  }
}

/// Owns isolated Lua sessions over a shared native plugin-host distribution.
final class PluginRuntime<T extends Object> implements PluginBundleInspector {
  /// Creates a runtime over injected native and revision ports.
  new({required this._luaRuntime, required this.revisions});

  final lua.LuaToolRuntime<T> _luaRuntime;

  /// Validated last-known-good revision catalog.
  final PluginRevisionCatalog revisions;

  final Set<PluginRuntimeSession<T>> _sessions = <PluginRuntimeSession<T>>{};
  bool _closed = false;

  /// Inspects `tinest.plugin.define` in an isolated fresh VM without resolving
  /// or updating an Agent-active revision.
  @override
  Future<PluginDescriptorDto> inspect(PluginBundle bundle) async {
    if (_closed) throw const PluginRuntimeClosed('Plugin runtime is closed.');
    final runtimeSession = _luaRuntime.createSession();
    try {
      final executionContext = lua.LuaExecutionContext<T>(
        dispatcher: _RejectedNestedToolDispatcher<T>(),
        hostCallbacks: _RegistrationOnlyCallbackDispatcher<T>(),
      );
      var delta = await runtimeSession.invoke(
        lua.LuaInvokeRequest(
          bundle: TinestLuaPluginSdk.compose(bundle),
          handler: 'define',
          yieldTime: const Duration(seconds: 10),
          maxOutputTokens: 10000,
        ),
        executionContext,
      );
      final deltas = <lua.LuaCellDelta<T>>[delta];
      while (delta.running) {
        delta = await runtimeSession.wait(
          lua.LuaWaitRequest(
            cellId: delta.cellId,
            yieldTime: const Duration(seconds: 10),
            maxOutputTokens: 10000,
          ),
          executionContext,
        );
        deltas.add(delta);
      }
      if (delta.error != null) {
        throw PluginBundleInspectionException(
          'Plugin define failed: ${delta.error!.message}',
          path: bundle.descriptor.entrypoint,
        );
      }
      final emittedEffects = deltas.any(
        (item) =>
            item.output.isNotEmpty ||
            item.notifications.isNotEmpty ||
            item.resources.isNotEmpty ||
            item.emittedResources.isNotEmpty,
      );
      if (emittedEffects) {
        throw PluginBundleInspectionException(
          'Plugin define must not emit output, notifications, or resources.',
          path: bundle.descriptor.entrypoint,
        );
      }
      try {
        final registration = PluginRegistrationParser.parse(
          descriptor: bundle.descriptor,
          revisionHash: bundle.revision.executionRevisionHash,
          value: delta.result,
        );
        var repeated = await runtimeSession.invoke(
          lua.LuaInvokeRequest(
            bundle: TinestLuaPluginSdk.compose(bundle),
            handler: 'define',
            yieldTime: const Duration(seconds: 10),
            maxOutputTokens: 10000,
          ),
          executionContext,
        );
        final repeatedDeltas = <lua.LuaCellDelta<T>>[repeated];
        while (repeated.running) {
          repeated = await runtimeSession.wait(
            lua.LuaWaitRequest(
              cellId: repeated.cellId,
              yieldTime: const Duration(seconds: 10),
              maxOutputTokens: 10000,
            ),
            executionContext,
          );
          repeatedDeltas.add(repeated);
        }
        if (repeated.error != null ||
            repeatedDeltas.any(
              (item) =>
                  item.output.isNotEmpty ||
                  item.notifications.isNotEmpty ||
                  item.resources.isNotEmpty ||
                  item.emittedResources.isNotEmpty,
            )) {
          throw PluginRegistrationException(
            'Plugin determinism check failed.',
            path: bundle.descriptor.entrypoint,
          );
        }
        final second = PluginRegistrationParser.parse(
          descriptor: bundle.descriptor,
          revisionHash: bundle.revision.executionRevisionHash,
          value: repeated.result,
        );
        if (_canonicalRegistration(registration) !=
            _canonicalRegistration(second)) {
          throw PluginRegistrationException(
            'Plugin define returned a nondeterministic registration.',
            path: bundle.descriptor.entrypoint,
          );
        }
        return registration.descriptor;
      } on PluginRegistrationException catch (error) {
        throw PluginBundleInspectionException(
          error.message,
          path: error.path ?? bundle.descriptor.entrypoint,
        );
      }
    } finally {
      await runtimeSession.close();
    }
  }

  /// Opens one Agent/session-isolated plugin runtime.
  PluginRuntimeSession<T> openSession({
    required String agentId,
    required String sessionId,
    required Map<String, Set<String>> allowedCapabilitiesByPlugin,
    String? workspaceId,
    Set<String>? sessionCapabilities,
    Map<String, String> executionRevisionPinsByPlugin =
        const <String, String>{},
    String workingDirectory = '.',
    lua.LuaRuntimeLimits limits = const lua.LuaRuntimeLimits(),
  }) {
    if (_closed) throw const PluginRuntimeClosed('Plugin runtime is closed.');
    final session = PluginRuntimeSession<T>._(
      owner: this,
      runtimeSession: _luaRuntime.createSession(limits: limits),
      agentId: agentId,
      sessionId: sessionId,
      workspaceId: workspaceId,
      allowedCapabilitiesByPlugin: allowedCapabilitiesByPlugin,
      sessionCapabilities: sessionCapabilities,
      executionRevisionPinsByPlugin: executionRevisionPinsByPlugin,
      workingDirectory: workingDirectory,
    );
    _sessions.add(session);
    return session;
  }

  void _forget(PluginRuntimeSession<T> session) => _sessions.remove(session);

  /// Reclaims expired invocations in every open session.
  void sweep() => _luaRuntime.sweep();

  /// Closes every session and native helper process.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await Future.wait(
      List<PluginRuntimeSession<T>>.of(_sessions)
          .map((session) => session.close()),
    );
    _sessions.clear();
    await _luaRuntime.close();
  }
}

/// Agent/session-isolated view of revision-pinned plugin handlers.
final class PluginRuntimeSession<T extends Object> {
  new _({
    required this._owner,
    required this._runtimeSession,
    required this.agentId,
    required this.sessionId,
    required this.workspaceId,
    required Map<String, Set<String>> allowedCapabilitiesByPlugin,
    required Set<String>? sessionCapabilities,
    required Map<String, String> executionRevisionPinsByPlugin,
    required this.workingDirectory,
  }) : _allowedCapabilitiesByPlugin = Map<String, Set<String>>.unmodifiable(
         <String, Set<String>>{
           for (final entry in allowedCapabilitiesByPlugin.entries)
             entry.key: Set<String>.unmodifiable(entry.value),
         },
       ),
       _sessionCapabilities = sessionCapabilities == null
           ? null
           : Set<String>.unmodifiable(sessionCapabilities),
       _executionRevisionPinsByPlugin = Map<String, String>.unmodifiable(
         executionRevisionPinsByPlugin,
       );

  final PluginRuntime<T> _owner;
  final lua.LuaRuntimeSession<T> _runtimeSession;
  final Map<String, Set<String>> _allowedCapabilitiesByPlugin;
  final Set<String>? _sessionCapabilities;
  final Map<String, String> _executionRevisionPinsByPlugin;
  final Map<String, PluginRegistration> _registrations =
      <String, PluginRegistration>{};
  final Map<String, PluginBundle> _pinnedBundles = <String, PluginBundle>{};
  bool _closed = false;

  /// Agent definition selecting all plugins in this session.
  final String agentId;

  /// Owning session identity.
  final String sessionId;

  /// Optional workspace identity used by scoped host state.
  final String? workspaceId;

  /// Native worker directory. It is host-selected, never plugin-selected.
  final String workingDirectory;

  /// Invokes the effect-free `define` handler and caches its typed result by
  /// plugin ID and exact composite execution revision.
  Future<PluginRegistration> register({
    required String pluginId,
    required PluginCallbackRouter<T> callbackRouter,
    PluginCancellationSignal? cancellation,
  }) async {
    _requireOpen();
    final bundle = await _pin(pluginId);
    final key = '$pluginId:${bundle.revision.executionRevisionHash}';
    final cached = _registrations[key];
    if (cached != null) return cached;
    final context = _hostContext(
      bundle,
      handlerCapabilities: const <String>{},
      handlerOperations: const <String>{},
    );
    final executionContext = _executionContext(
      context,
      callbackRouter,
      cancellation,
      effectFree: true,
    );
    final deltas = await _invokeAndDrain(
      bundle: bundle,
      handler: 'define',
      arguments: const <String, Object?>{},
      executionContext: executionContext,
    );
    final terminal = deltas.last;
    if (terminal.error != null) {
      throw PluginRegistrationException(
        'Plugin define failed: ${terminal.error!.message}',
        path: bundle.descriptor.entrypoint,
      );
    }
    final emittedEffects = deltas.any(
      (delta) =>
          delta.output.isNotEmpty ||
          delta.notifications.isNotEmpty ||
          delta.resources.isNotEmpty ||
          delta.emittedResources.isNotEmpty,
    );
    if (emittedEffects) {
      throw PluginRegistrationException(
        'Plugin define must not emit output, notifications, or resources.',
        path: bundle.descriptor.entrypoint,
      );
    }
    final registration = PluginRegistrationParser.parse(
      descriptor: bundle.descriptor,
      revisionHash: bundle.revision.executionRevisionHash,
      value: terminal.result,
    );
    final secondDeltas = await _invokeAndDrain(
      bundle: bundle,
      handler: 'define',
      arguments: const <String, Object?>{},
      executionContext: executionContext,
    );
    final secondTerminal = secondDeltas.last;
    if (secondTerminal.error != null) {
      throw PluginRegistrationException(
        'Plugin determinism check failed: ${secondTerminal.error!.message}',
        path: bundle.descriptor.entrypoint,
      );
    }
    final secondRegistration = PluginRegistrationParser.parse(
      descriptor: bundle.descriptor,
      revisionHash: bundle.revision.executionRevisionHash,
      value: secondTerminal.result,
    );
    if (_canonicalRegistration(registration) !=
        _canonicalRegistration(secondRegistration)) {
      throw PluginRegistrationException(
        'Plugin define returned a nondeterministic registration.',
        path: bundle.descriptor.entrypoint,
      );
    }
    _registrations[key] = registration;
    return registration;
  }

  /// Starts one registered handler in a fresh Lua VM.
  Future<PluginInvocation<T>> invoke({
    required String pluginId,
    required PluginHandlerBinding binding,
    required Map<String, Object?> arguments,
    required PluginCallbackRouter<T> callbackRouter,
    PluginCancellationSignal? cancellation,
    Duration yieldTime = const Duration(seconds: 10),
    int maxOutputTokens = 10000,
  }) async {
    _requireOpen();
    final bundle = await _pin(pluginId);
    final registration = await register(
      pluginId: pluginId,
      callbackRouter: callbackRouter,
      cancellation: cancellation,
    );
    final handlerCapabilities = _handlerCapabilities(registration, binding);
    final handlerOperations = _handlerOperations(registration, binding);
    if (handlerCapabilities == null || handlerOperations == null) {
      throw PluginRegistrationException(
        'Plugin handler binding is not registered: ${binding.internalKey}',
        path: binding.internalKey,
      );
    }
    final executionContext = _executionContext(
      _hostContext(
        bundle,
        handlerCapabilities: handlerCapabilities,
        handlerOperations: handlerOperations,
      ),
      callbackRouter,
      cancellation,
      effectFree: false,
    );
    final delta = await _runtimeSession.invoke(
      lua.LuaInvokeRequest(
        bundle: TinestLuaPluginSdk.compose(bundle),
        handler: binding.internalKey,
        arguments: arguments,
        yieldTime: yieldTime,
        maxOutputTokens: maxOutputTokens,
      ),
      executionContext,
      workingDirectory: workingDirectory,
    );
    return PluginInvocation<T>._(
      pluginId: pluginId,
      revisionHash: bundle.revision.executionRevisionHash,
      runtimeSession: _runtimeSession,
      executionContext: executionContext,
      rawDelta: delta,
    );
  }

  Future<List<lua.LuaCellDelta<T>>> _invokeAndDrain({
    required PluginBundle bundle,
    required String handler,
    required Map<String, Object?> arguments,
    required lua.LuaExecutionContext<T> executionContext,
  }) async {
    var delta = await _runtimeSession.invoke(
      lua.LuaInvokeRequest(
        bundle: TinestLuaPluginSdk.compose(bundle),
        handler: handler,
        arguments: arguments,
        yieldTime: const Duration(seconds: 10),
        maxOutputTokens: 10000,
      ),
      executionContext,
      workingDirectory: workingDirectory,
    );
    final deltas = <lua.LuaCellDelta<T>>[delta];
    while (delta.running) {
      delta = await _runtimeSession.wait(
        lua.LuaWaitRequest(
          cellId: delta.cellId,
          yieldTime: const Duration(seconds: 10),
          maxOutputTokens: 10000,
        ),
        executionContext,
      );
      deltas.add(delta);
    }
    return deltas;
  }

  PluginHostCallContext _hostContext(
    PluginBundle bundle, {
    required Set<String> handlerCapabilities,
    required Set<String> handlerOperations,
  }) {
    final manifest = bundle.revision.requestedCapabilities.toSet();
    final effective = manifest.intersection(
      _allowedCapabilitiesByPlugin[bundle.descriptor.id] ?? const <String>{},
    );
    final sessionCapabilities = _sessionCapabilities;
    if (sessionCapabilities != null) {
      effective.removeWhere(
        (capability) => !sessionCapabilities.contains(capability),
      );
    }
    return PluginHostCallContext(
      agentId: agentId,
      sessionId: sessionId,
      workspaceId: workspaceId,
      pluginId: bundle.descriptor.id,
      revisionHash: bundle.revision.executionRevisionHash,
      manifestCapabilities: manifest,
      effectiveCapabilities: effective,
      handlerCapabilities: handlerCapabilities,
      handlerOperations: handlerOperations,
    );
  }

  lua.LuaExecutionContext<T> _executionContext(
    PluginHostCallContext context,
    PluginCallbackRouter<T> callbackRouter,
    PluginCancellationSignal? cancellation, {
    required bool effectFree,
  }) => lua.LuaExecutionContext<T>(
    dispatcher: _RejectedNestedToolDispatcher<T>(),
    hostCallbacks: _PluginHostCallbackDispatcher<T>(
      context: context,
      router: callbackRouter,
      effectFree: effectFree,
    ),
    cancellation: cancellation == null
        ? null
        : _PluginCancellationAdapter(cancellation),
  );

  Set<String>? _handlerCapabilities(
    PluginRegistration registration,
    PluginHandlerBinding binding,
  ) {
    final matches = <Set<String>>[
      if (_sameBinding(registration.driver?.binding, binding))
        registration.driver!.requiredCapabilities,
      for (final tool in registration.tools)
        if (_sameBinding(tool.binding, binding)) tool.requiredCapabilities,
      for (final template in registration.templates)
        if (_sameBinding(template.binding, binding))
          template.requiredCapabilities,
      for (final hook in registration.hooks)
        if (_sameBinding(hook.binding, binding)) hook.requiredCapabilities,
      for (final control in registration.sessionControls)
        if (_sameBinding(control.binding, binding))
          control.requiredCapabilities,
      for (final contribution in registration.ui)
        if (_sameBinding(contribution.binding, binding))
          contribution.requiredCapabilities,
    ];
    if (matches.isEmpty) return null;
    return Set<String>.unmodifiable(matches.expand((value) => value));
  }

  Set<String>? _handlerOperations(
    PluginRegistration registration,
    PluginHandlerBinding binding,
  ) {
    final matches = <Set<String>>[
      if (_sameBinding(registration.driver?.binding, binding))
        registration.driver!.declaredOperations,
      for (final tool in registration.tools)
        if (_sameBinding(tool.binding, binding)) tool.declaredOperations,
      for (final template in registration.templates)
        if (_sameBinding(template.binding, binding))
          template.declaredOperations,
      for (final hook in registration.hooks)
        if (_sameBinding(hook.binding, binding)) hook.declaredOperations,
      for (final control in registration.sessionControls)
        if (_sameBinding(control.binding, binding)) control.declaredOperations,
      for (final contribution in registration.ui)
        if (_sameBinding(contribution.binding, binding))
          contribution.declaredOperations,
    ];
    if (matches.isEmpty) return null;
    return Set<String>.unmodifiable(matches.expand((value) => value));
  }

  Future<PluginBundle> _pin(String pluginId) async {
    final pinned = _pinnedBundles[pluginId];
    if (pinned != null) return pinned;
    final executionRevisionHash = _executionRevisionPinsByPlugin[pluginId];
    final bundle = executionRevisionHash == null
        ? await _owner.revisions.resolveForAgent(agentId, pluginId)
        : await _owner.revisions.resolveExecutionRevision(
            pluginId,
            executionRevisionHash,
          );
    _pinnedBundles[pluginId] = bundle;
    return bundle;
  }

  void _requireOpen() {
    if (_closed) {
      throw const PluginRuntimeClosed('Plugin runtime session is closed.');
    }
  }

  /// Terminates all in-flight handlers and releases revision workers.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _registrations.clear();
    _pinnedBundles.clear();
    _owner._forget(this);
    await _runtimeSession.close();
  }
}

bool _sameBinding(
  PluginHandlerBinding? registered,
  PluginHandlerBinding requested,
) =>
    registered != null &&
    registered.pluginId == requested.pluginId &&
    registered.executionRevisionHash == requested.executionRevisionHash &&
    registered.kind == requested.kind &&
    registered.localId == requested.localId &&
    registered.internalKey == requested.internalKey &&
    registered.lifecycle == requested.lifecycle;

final class _PluginHostCallbackDispatcher<T extends Object>
    implements lua.LuaHostCallbackDispatcher<T> {
  const new({
    required this.context,
    required this.router,
    required this.effectFree,
  });

  final PluginHostCallContext context;
  final PluginCallbackRouter<T> router;
  final bool effectFree;

  @override
  Future<lua.LuaHostResult<T>> call(lua.LuaHostInvocation invocation) async {
    if (effectFree) return _registrationEffectError();
    final operationDenial = _operationDenial(invocation);
    if (operationDenial != null) return operationDenial;
    final authorization = await router.authorize(
      context,
      invocation.name,
      invocation.arguments,
    );
    final denied = _denial(authorization);
    if (denied != null) return denied;
    final result = await router.call(
      context,
      invocation.name,
      invocation.arguments,
      _InvocationCancellationAdapter(invocation.cancellation),
    );
    return _mapResult(result);
  }

  @override
  Stream<lua.LuaHostResult<T>> open(lua.LuaHostInvocation invocation) async* {
    if (effectFree) {
      yield _registrationEffectError();
      return;
    }
    final operationDenial = _operationDenial(invocation);
    if (operationDenial != null) {
      yield operationDenial;
      return;
    }
    final authorization = await router.authorize(
      context,
      invocation.name,
      invocation.arguments,
    );
    final denied = _denial(authorization);
    if (denied != null) {
      yield denied;
      return;
    }
    await for (final result in router.open(
      context,
      invocation.name,
      invocation.arguments,
      _InvocationCancellationAdapter(invocation.cancellation),
    )) {
      yield _mapResult(result);
    }
  }

  lua.LuaHostResult<T>? _denial(PluginCallAuthorization authorization) {
    if (!authorization.allowed) {
      return lua.LuaHostResult<T>(
        value: authorization.reason ?? 'Plugin callback was denied.',
        isError: true,
      );
    }
    final outsideManifest = authorization.requiredCapabilities.difference(
      context.manifestCapabilities,
    );
    if (outsideManifest.isNotEmpty) {
      return lua.LuaHostResult<T>(
        value:
            'Actual host primitive requires an undeclared capability: '
            '${outsideManifest.first}',
        isError: true,
      );
    }
    final ungranted = authorization.requiredCapabilities.difference(
      context.effectiveCapabilities,
    );
    if (ungranted.isNotEmpty) {
      return lua.LuaHostResult<T>(
        value: 'Plugin capability is not granted: ${ungranted.first}',
        isError: true,
      );
    }
    final lifecycleRestricted = authorization.requiredCapabilities.difference(
      context.handlerCapabilities,
    );
    if (lifecycleRestricted.isNotEmpty) {
      return lua.LuaHostResult<T>(
        value:
            'Handler did not declare the required capability: '
            '${lifecycleRestricted.first}',
        isError: true,
      );
    }
    return null;
  }

  lua.LuaHostResult<T>? _operationDenial(lua.LuaHostInvocation invocation) {
    if (!invocation.name.startsWith('host.')) return null;
    final dynamicToken = invocation.arguments['_tinest_dynamic_token'];
    if (dynamicToken is String && dynamicToken.isNotEmpty) {
      // The Agent harness validates this unforgeable SDK token against the
      // revision-pinned dynamic contribution and its own declared operations.
      return null;
    }
    if (context.handlerOperations.contains(invocation.name)) return null;
    return lua.LuaHostResult<T>(
      value:
          'Handler did not declare the host primitive in uses: '
          '${invocation.name}',
      isError: true,
    );
  }

  lua.LuaHostResult<T> _registrationEffectError() => lua.LuaHostResult<T>(
    value: 'tinest.plugin.define registration is effect-free.',
    isError: true,
  );

  lua.LuaHostResult<T> _mapResult(PluginCallbackResult<T> result) =>
      lua.LuaHostResult<T>(
        value: result.value,
        isError: result.isError,
        resources: <lua.LuaOpaqueResource<T>>[
          for (final resource in result.resources)
            lua.LuaOpaqueResource<T>(
              value: resource.value,
              fileName: resource.fileName,
              mimeType: resource.mimeType,
              byteSize: resource.byteSize,
            ),
        ],
      );
}

final class _RegistrationOnlyCallbackDispatcher<T extends Object>
    implements lua.LuaHostCallbackDispatcher<T> {
  const new();

  @override
  Future<lua.LuaHostResult<T>> call(lua.LuaHostInvocation invocation) async =>
      _error();

  @override
  Stream<lua.LuaHostResult<T>> open(lua.LuaHostInvocation invocation) =>
      Stream<lua.LuaHostResult<T>>.value(_error());

  lua.LuaHostResult<T> _error() => lua.LuaHostResult<T>(
    value: 'tinest.plugin.define registration is effect-free.',
    isError: true,
  );
}

final class _RejectedNestedToolDispatcher<T extends Object>
    implements lua.LuaToolDispatcher<T> {
  const new();

  @override
  Future<lua.LuaToolResult<T>> invoke(lua.LuaToolInvocation invocation) async =>
      lua.LuaToolResult<T>(
        value:
            'Raw tools.call is unavailable to plugins; use '
            'tinest.tools.invoke.',
        isError: true,
      );
}

final class _PluginCancellationAdapter implements lua.LuaCancellationSignal {
  const new(this.signal);

  final PluginCancellationSignal signal;

  @override
  void onCancel(void Function() callback) => signal.onCancel(callback);
}

final class _InvocationCancellationAdapter
    implements PluginInvocationCancellation {
  const new(this.cancellation);

  final lua.LuaInvocationCancellation cancellation;

  @override
  bool get isCancelled => cancellation.isCancelled;

  @override
  void onCancel(void Function() callback) => cancellation.onCancel(callback);
}
