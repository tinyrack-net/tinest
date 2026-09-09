import 'dart:async';
import 'dart:convert';

import 'package:agent/agent.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_network_gateway.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_ports.dart';
import 'package:daemon/src/features/plugins/runtime/built_in_host_primitives.dart';
import 'package:daemon/src/features/plugins/runtime/host_primitive_contracts.dart';
import 'package:daemon/src/features/plugins/runtime/host_primitives.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_json_schema.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_runtime.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_scheduled_payload.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_state_schema.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart' show IdGenerator;
import 'package:protocol/protocol.dart';

/// Immutable inputs that one Agent-owned Lua driver may arrange as it chooses.
final class LuaAgentHarnessRequest {
  /// Creates one revision-pinned turn request.
  new({
    required this.definition,
    required this.sessionId,
    required this.turnId,
    required this.workspaceRoot,
    required this.prompt,
    required this.modelId,
    required this.model,
    required this.modelCapabilities,
    required this.history,
    required this.allowedCapabilitiesByPlugin,
    this.workspaceId,
    this.attachments = const <ConversationAttachment>[],
    this.turnInputs = const <ConversationItem>[],
    this.modelControls = const <String, AgentModelControlValue>{},
    HostPrimitiveRegistry? primitives,
    this.projectDocument,
    this.extensionData = const <String, Object?>{},
    this.sessionControlValues = const <String, Object?>{},
    this.contextWindowTokens,
    this.internal = false,
    this.approvals,
    this.permissions,
    this.policyFactory,
    this.state,
    this.jobs,
    this.clock,
    this.ids,
    this.network,
    this.secrets,
    this.selectedLuaTools,
  }) : primitives = primitives ?? HostPrimitiveRegistry.empty();

  /// Exact Agent definition snapshot that owns the harness.
  final AgentDefinitionDto definition;

  /// Session owning the turn.
  final String sessionId;

  /// Turn owning emitted events and tool calls.
  final String turnId;

  /// Optional stable workspace identity used by scoped plugin state.
  final String? workspaceId;

  /// Host-selected working directory.
  final String workspaceRoot;

  /// New user input. The driver decides whether and where to send it.
  final String prompt;

  /// Provider model ID selected by the Agent/session model rule.
  final String modelId;

  /// Provider transport retained in the Dart safety kernel.
  final ModelGateway model;

  /// Provider-neutral capabilities validated against the driver.
  final AgentModelCapabilities modelCapabilities;

  /// Hydrated conversation data made available to the driver.
  final List<ConversationItem> history;

  /// Hydrated attachments submitted with [prompt].
  final List<ConversationAttachment> attachments;

  /// Host-originated inputs that arrived after the previous driver boundary.
  ///
  /// The driver decides where these ordered items enter its model context.
  final List<ConversationItem> turnInputs;

  /// Already validated provider controls.
  final Map<String, AgentModelControlValue> modelControls;

  /// Capability grants keyed by plugin, never read from Agent Markdown.
  final Map<String, Set<String>> allowedCapabilitiesByPlugin;

  /// Model-agnostic, capability-brokered native host operations.
  final HostPrimitiveRegistry primitives;

  /// Workspace documentation offered as data rather than injected text.
  final String? projectDocument;

  /// Ordered extension-owned data offered to the driver.
  final Map<String, Object?> extensionData;

  /// Durable values for every control declared by an active extension.
  final Map<String, Object?> sessionControlValues;

  /// Provider context limit, when known.
  final int? contextWindowTokens;

  /// Whether a daemon workflow, rather than a user, started the turn.
  final bool internal;

  /// Host approval coordinator for effectful primitives.
  final ApprovalCoordinator? approvals;

  /// Live session permission restriction.
  final PermissionModeSource? permissions;

  /// Tool-specific approval policy decoration.
  final ApprovalPolicy Function(AgentPermissionMode mode)? policyFactory;

  /// Durable scoped JSON state shared by every plugin through the public SDK.
  final PluginStateStore? state;

  /// Durable named-handler job store.
  final PluginJobStore? jobs;

  /// Host clock for durable job deadlines.
  final Clock? clock;

  /// Host ID source for durable jobs.
  final IdGenerator? ids;

  /// Capability-brokered network transport for public Lua plugins.
  final PluginNetworkGateway? network;

  /// Agent/plugin-isolated secret store for public Lua plugins.
  final PluginSecretStore? secrets;

  /// Late-bound selected tool surface shared with Lua cell primitives.
  final InvocationLocalSelectedLuaToolInvoker? selectedLuaTools;
}

/// One-turn bridge that prevents a native Lua cell from retaining a router.
///
/// The registry is assembled before plugin registrations are pinned. The
/// harness binds the exact turn router after selection validation, then clears
/// it when the revision-pinned turn closes.
final class InvocationLocalSelectedLuaToolInvoker
    implements SelectedLuaToolInvoker {
  SelectedLuaToolInvoker? _delegate;

  /// Binds the validated selected surface exactly once for the live turn.
  void bind(SelectedLuaToolInvoker delegate) {
    if (_delegate != null) {
      throw StateError('Lua nested tool invoker is already bound.');
    }
    _delegate = delegate;
  }

  /// Makes every later cell callback fail closed after the turn boundary.
  void unbind() => _delegate = null;

  SelectedLuaToolInvoker get _bound =>
      _delegate ??
      (throw StateError('Lua nested tool invoker is outside its turn.'));

  @override
  List<LuaNestedToolDefinition> definitionsFor(List<String> ids) =>
      _bound.definitionsFor(ids);

  @override
  Future<LuaNestedToolResult> invoke(
    String name,
    Map<String, dynamic> arguments,
  ) => _bound.invoke(name, arguments);
}

/// Side effects the harness reports without coupling to daemon persistence.
final class LuaAgentHarnessCallbacks {
  /// Creates callback ports for one turn.
  const new({
    required this.onEvent,
    required this.onStatus,
    required this.onProviderItems,
    this.onUiSnapshot,
  });

  /// Publishes one normalized timeline/audit event.
  final AgentEventCallback onEvent;

  /// Publishes the current session transition.
  final SessionStatusCallback onStatus;

  /// Persists provider conversation items.
  final ProviderItemsCallback onProviderItems;

  /// Registers an emitted document with the action host before publication.
  final FutureOr<void> Function(LuaAgentHarnessUiSnapshot snapshot)?
  onUiSnapshot;
}

/// Exact metadata needed to preserve actions for an emitted UI snapshot.
final class LuaAgentHarnessUiSnapshot {
  /// Creates one revision-pinned declarative UI publication.
  const new({
    required this.plugin,
    required this.contribution,
    required this.request,
    required this.document,
  });

  /// Pinned plugin descriptor from the running turn.
  final PluginDescriptorDto plugin;

  /// Pinned UI contribution invoked by the publication.
  final PluginContributionDto contribution;

  /// Host context used to dispatch later actions.
  final PluginUiRenderParamsDto request;

  /// Immutable document written to the event stream.
  final PluginUiDocumentDto document;
}

/// Runs an Agent definition through exactly one revision-pinned Lua driver.
final class LuaAgentHarness {
  /// Creates a harness over the shared isolated plugin runtime.
  const new({required this.runtime});

  /// General-purpose Lua plugin host.
  final PluginRuntime<ConversationAttachment> runtime;

  /// Runs one turn. No Tinest prompt or tool is implicitly added here.
  Future<AgentRunResult> startTurn({
    required LuaAgentHarnessRequest request,
    required LuaAgentHarnessCallbacks callbacks,
    required CancellationToken cancellation,
  }) async {
    final pluginSettings = _pinPluginSettings(
      request.definition.pluginSettings,
    );
    final pluginIds = _referencedPluginIds(request.definition);
    final session = runtime.openSession(
      agentId: request.definition.id,
      sessionId: request.sessionId,
      workspaceId: request.workspaceId,
      workingDirectory: request.workspaceRoot,
      allowedCapabilitiesByPlugin: request.allowedCapabilitiesByPlugin,
    );
    late final _TurnCallbackRouter router;
    final registrations = <String, PluginRegistration>{};
    var hooksReady = false;
    Future<List<Object?>> runHooks(
      PluginLifecycle lifecycle,
      Object? payload, {
      bool afterCancellation = false,
    }) async {
      final values = <Object?>[];
      for (final extensionId in request.definition.extensionIds) {
        final pluginId = _pluginId(extensionId);
        final registration = registrations[pluginId];
        if (registration == null) continue;
        for (final hook in registration.hooks) {
          if (hook.lifecycle != lifecycle) continue;
          final invocation = await session.invoke(
            pluginId: pluginId,
            binding: hook.binding,
            arguments: <String, Object?>{
              ..._object(payload),
              'payload': payload,
              'session_controls': request.sessionControlValues,
              'settings': pluginSettings[pluginId] ?? const <String, Object?>{},
            },
            callbackRouter: router,
            cancellation: afterCancellation
                ? null
                : _PluginCancellation(cancellation),
          );
          final completed = await invocation.complete();
          if (completed.error != null) {
            router.discardUiPublications();
            // A hook killed by the turn's own cancellation is not a plugin
            // failure; fold it into the cancelled transition exactly like
            // the driver path below does.
            if (!afterCancellation &&
                (completed.terminated || cancellation.isCancelled)) {
              throw const AgentCancelledException();
            }
            throw StateError(
              'Plugin hook ${hook.id} failed: ${completed.error}',
            );
          }
          if (lifecycle == PluginLifecycle.beforeTurn) {
            router.applyLifecycleCapabilityLimit(completed.result);
          }
          await router.flushUiPublications();
          values.add(completed.result);
        }
      }
      return values;
    }

    Future<void> runTerminalHooks(
      PluginLifecycle lifecycle,
      Object? payload,
    ) async {
      if (!hooksReady) return;
      router.beginTerminalLifecycle();
      try {
        final values = await runHooks(
          lifecycle,
          payload,
          afterCancellation: true,
        );
        await callbacks.onEvent('plugin.lifecycle.completed', <String, dynamic>{
          'lifecycle': lifecycle.wireName,
          'results': values,
        });
      } on Object catch (hookError) {
        await callbacks.onEvent('plugin.lifecycle.failed', <String, dynamic>{
          'lifecycle': lifecycle.wireName,
          'error': '$hookError',
        });
      } finally {
        router.endTerminalLifecycle();
      }
    }

    try {
      router = _TurnCallbackRouter(
        request: request,
        callbacks: callbacks,
        session: session,
        registrations: registrations,
        pluginSettings: pluginSettings,
        runHooks: (lifecycle, payload) async {
          await runHooks(lifecycle, payload);
        },
        cancellation: cancellation,
      );
      for (final pluginId in pluginIds) {
        registrations[pluginId] = await session.register(
          pluginId: pluginId,
          callbackRouter: router,
          cancellation: _PluginCancellation(cancellation),
        );
      }
      hooksReady = true;
      final driverPluginId = _pluginId(request.definition.driverId);
      final driverRegistration = registrations[driverPluginId];
      final driver = driverRegistration?.driver;
      if (driver == null || driver.id != request.definition.driverId) {
        throw StateError(
          'Agent driver is not registered: ${request.definition.driverId}',
        );
      }
      _validateDriverCapabilities(driver, request.modelCapabilities);
      router.bindSelectedTools(request.definition.toolIds);
      request.selectedLuaTools?.bind(router);

      await callbacks.onStatus(AgentSessionStatus.running);
      final user = request.internal
          ? null
          : UserConversationItem(
              request.prompt,
              attachments: request.attachments,
            );
      if (user != null) {
        await callbacks.onEvent('user.message', <String, dynamic>{
          'text': request.prompt,
          'attachments': request.attachments
              .map(_publicAttachmentJson)
              .toList(growable: false),
        });
        await router.persist(<ConversationItem>[user]);
      }

      final extensions = await runHooks(
        PluginLifecycle.beforeTurn,
        <String, Object?>{
          'turn_id': request.turnId,
          'prompt': request.prompt,
          'internal': request.internal,
          'extension_data': request.extensionData,
        },
      );
      final invocation = await session.invoke(
        pluginId: driverPluginId,
        binding: driver.binding,
        arguments: <String, Object?>{
          'agent': request.definition.toJson(),
          'agent_prompt': request.definition.prompt,
          'prompt': request.prompt,
          'internal': request.internal,
          'history': request.history
              .map(_pluginConversationItemJson)
              .toList(growable: true),
          'attachments': request.attachments
              .map(_publicAttachmentJson)
              .toList(growable: true),
          'turn_inputs': request.turnInputs
              .map(_pluginConversationItemJson)
              .toList(growable: true),
          'project_document': request.projectDocument,
          'extension_data': request.extensionData,
          'extensions': extensions,
          'plugin_settings': pluginSettings,
          'model': <String, Object?>{
            'id': request.modelId,
            'capabilities': _modelCapabilitiesJson(request.modelCapabilities),
          },
          'context': <String, Object?>{
            if (request.contextWindowTokens != null)
              'window_tokens': request.contextWindowTokens,
          },
        },
        callbackRouter: router,
        cancellation: _PluginCancellation(cancellation),
      );
      final completed = await invocation.complete();
      final modelContractError = router.fatalModelContractError;
      if (modelContractError != null) {
        router.discardUiPublications();
        throw StateError(modelContractError);
      }
      if (completed.error != null) {
        router.discardUiPublications();
        if (completed.terminated || cancellation.isCancelled) {
          throw const AgentCancelledException();
        }
        throw StateError('Agent driver failed: ${completed.error}');
      }
      await router.flushUiPublications();
      final result = _object(completed.result);
      final toolRounds = _integer(result['tool_rounds']) ?? router.toolRounds;
      await runHooks(PluginLifecycle.afterTurn, <String, Object?>{
        'turn_id': request.turnId,
        'tool_rounds': toolRounds,
        'internal': request.internal,
      });
      await callbacks.onEvent('turn.completed', <String, dynamic>{
        'toolRounds': toolRounds,
      });
      await callbacks.onStatus(AgentSessionStatus.idle);
      return AgentRunResult(
        conversationItems: List<ConversationItem>.unmodifiable(
          router.persisted,
        ),
        toolRounds: toolRounds,
      );
    } on AgentCancelledException {
      await runTerminalHooks(PluginLifecycle.cancel, <String, Object?>{
        'turn_id': request.turnId,
        'reason': 'cancelled',
      });
      await callbacks.onEvent('turn.cancelled', const <String, dynamic>{});
      await callbacks.onStatus(AgentSessionStatus.idle);
      rethrow;
      // Lua/provider failures are foreign boundary values, and every one must
      // drive the plugin error transition, including malformed StateError data.
    } on Object catch (error) {
      await runTerminalHooks(PluginLifecycle.error, <String, Object?>{
        'turn_id': request.turnId,
        'error': '$error',
      });
      await callbacks.onEvent('turn.failed', <String, dynamic>{
        'error': '$error',
      });
      await callbacks.onStatus(AgentSessionStatus.failed, error: '$error');
      rethrow;
    } finally {
      request.selectedLuaTools?.unbind();
      await session.close();
    }
  }
}

final class _TurnCallbackRouter
    implements
        PluginCallbackRouter<ConversationAttachment>,
        SelectedLuaToolInvoker {
  new({
    required this.request,
    required this.callbacks,
    required this.session,
    required this.registrations,
    required this.pluginSettings,
    required this.runHooks,
    required CancellationToken cancellation,
  }) : _hydratedAttachments = <String, ConversationAttachment>{
         for (final item in request.history.whereType<UserConversationItem>())
           for (final attachment in item.attachments) attachment.id: attachment,
         for (final item
             in request.turnInputs.whereType<UserConversationItem>())
           for (final attachment in item.attachments) attachment.id: attachment,
         for (final attachment in request.attachments)
           attachment.id: attachment,
       },
       _turnCancellation = cancellation,
       _primitives = _turnPrimitiveRegistry(request);

  final LuaAgentHarnessRequest request;
  final LuaAgentHarnessCallbacks callbacks;
  final PluginRuntimeSession<ConversationAttachment> session;
  final Map<String, PluginRegistration> registrations;
  final Map<String, Map<String, Object?>> pluginSettings;
  final Future<void> Function(PluginLifecycle, Object?) runHooks;
  final CancellationToken _turnCancellation;
  final HostPrimitiveRegistry _primitives;
  CancellationToken? _terminalLifecycleCancellation;
  CancellationToken get cancellation =>
      _terminalLifecycleCancellation ?? _turnCancellation;
  final Map<String, ConversationAttachment> _hydratedAttachments;
  final Map<String, ({String pluginId, PluginToolRegistration tool})>
  _selectedTools = <String, ({String pluginId, PluginToolRegistration tool})>{};
  final Set<String> _surfacedToolIds = <String>{};
  final Map<String, _DynamicToolRecord> _dynamicTools =
      <String, _DynamicToolRecord>{};
  // A host call carries only an opaque token. Bind that token to the exact
  // plugin/revision that materialized it so two plugins cannot collide even
  // when a caller-supplied ID generator returns the same value.
  final Map<String, String> _dynamicToolIdsByIdentity = <String, String>{};
  final Map<String, _PendingDynamicToolCall> _pendingDynamicToolCalls =
      <String, _PendingDynamicToolCall>{};
  final Map<String, String> _luaToolIdsByName = <String, String>{};
  final Map<String, _ActiveToolCall> _activeCalls = <String, _ActiveToolCall>{};
  final Set<String> _deniedToolCallIds = <String>{};
  final List<_PendingUiPublication> _pendingUiPublications =
      <_PendingUiPublication>[];
  final List<ConversationItem> persisted = <ConversationItem>[];
  Future<void> _approvalQueue = Future<void>.value();
  Set<String>? _lifecycleHostCapabilities;
  ModelUsage _turnUsage = const ModelUsage();
  bool _renderingPluginUi = false;
  String? _fatalModelContractError;
  int _uiDocumentGeneration = 0;
  int _dynamicToolGeneration = 0;
  int toolRounds = 0;

  String? get fatalModelContractError => _fatalModelContractError;

  void beginTerminalLifecycle() {
    _terminalLifecycleCancellation = CancellationToken();
  }

  void endTerminalLifecycle() {
    _terminalLifecycleCancellation = null;
  }

  /// Drops publications emitted by an invocation that failed atomically.
  void discardUiPublications() => _pendingUiPublications.clear();

  /// Renders queued publications only after their owning Lua invocation exits.
  ///
  /// A native callback cannot invoke another handler on the same Lua worker
  /// while that callback is awaited. Deferring the render also lets a tool's
  /// completion event arrive before the snapshot that replaces its generic
  /// timeline row.
  Future<void> flushUiPublications() async {
    var renderedCount = 0;
    while (_pendingUiPublications.isNotEmpty) {
      renderedCount += 1;
      if (renderedCount > 128) {
        _pendingUiPublications.clear();
        throw StateError('Plugin UI publication limit exceeded.');
      }
      final publication = _pendingUiPublications.removeAt(0);
      final registration = registrations[publication.pluginId];
      if (registration == null ||
          registration.revisionHash != publication.revisionHash) {
        throw StateError(
          'Plugin UI revision is no longer pinned: '
          '${publication.pluginId}@${publication.revisionHash}',
        );
      }
      final contributions = registration.ui.where(
        (candidate) => candidate.id == publication.contributionId,
      );
      if (contributions.length != 1) {
        throw StateError(
          'Plugin UI contribution is not registered: '
          '${publication.contributionId}',
        );
      }
      final contribution = contributions.single;
      if (contribution.slot != publication.slot) {
        throw StateError(
          'Plugin UI contribution ${publication.contributionId} is not '
          'registered for ${publication.slot.name}.',
        );
      }

      _renderingPluginUi = true;
      try {
        final value = publication.arguments['value'];
        try {
          validatePluginJsonSchema(
            contribution.inputSchema,
            value,
            path: r'$.publication.value',
          );
        } on PluginJsonValidationException catch (error) {
          throw StateError(
            'Plugin UI contribution ${publication.contributionId} received '
            'an invalid publication value: ${error.message}',
          );
        }
        final invocation = await session.invoke(
          pluginId: publication.pluginId,
          binding: contribution.binding,
          arguments: <String, Object?>{
            '__tinest_callback_value': true,
            'value': value,
          },
          callbackRouter: this,
          cancellation: _PluginCancellation(cancellation),
        );
        final completed = await invocation.complete();
        if (completed.error != null) {
          throw StateError(
            'Plugin UI contribution ${publication.contributionId} failed: '
            '${completed.error}',
          );
        }
        if (completed.revisionHash != publication.revisionHash) {
          throw StateError(
            'Plugin UI contribution revision changed during a pinned turn.',
          );
        }
        late final PluginUiCallbackDocument callbackDocument;
        try {
          callbackDocument = decodePluginUiCallbackDocument(
            completed.result,
            pluginId: publication.pluginId,
            registeredActionIds: <String>{
              for (final hook in registration.hooks)
                if (hook.lifecycle == PluginLifecycle.uiAction &&
                    hook.metadata['uiAction'] == true)
                  hook.id,
            },
          );
        } on PluginUiCallbackDocumentException catch (error) {
          throw StateError(
            'Plugin UI contribution ${publication.contributionId} returned '
            'an invalid document: ${error.message}',
          );
        }
        _uiDocumentGeneration += 1;
        final document = PluginUiDocumentDto(
          id:
              '${publication.pluginId}/${publication.contributionId}/'
              '${request.sessionId}/${publication.revisionHash}/'
              '${request.turnId}/$_uiDocumentGeneration',
          pluginId: publication.pluginId,
          revisionHash: publication.revisionHash,
          slot: publication.slot,
          root: callbackDocument.root,
        );
        final contributionDescriptor = registration.descriptor.contributions
            .where(
              (candidate) =>
                  candidate.kind == PluginContributionKind.ui &&
                  candidate.id == publication.contributionId,
            )
            .single;
        final renderRequest = PluginUiRenderParamsDto(
          agentId: request.definition.id,
          pluginId: publication.pluginId,
          contributionId: publication.contributionId,
          slot: publication.slot,
          input: value,
          context: <String, dynamic>{
            'sessionId': request.sessionId,
            if (request.workspaceId != null) 'workspaceId': request.workspaceId,
            'turnId': request.turnId,
            'publication': publication.arguments,
          },
        );
        final snapshotCallback = callbacks.onUiSnapshot;
        if (snapshotCallback != null) {
          await snapshotCallback(
            LuaAgentHarnessUiSnapshot(
              plugin: registration.descriptor,
              contribution: contributionDescriptor,
              request: renderRequest,
              document: document,
            ),
          );
        }
        await callbacks.onEvent('plugin.ui', <String, dynamic>{
          'document': document.toJson(),
          'operation': publication.operation,
          'contributionId': publication.contributionId,
          if (publication.callId != null) 'callId': publication.callId,
        });
      } finally {
        _renderingPluginUi = false;
      }
    }
  }

  void applyLifecycleCapabilityLimit(Object? hookResult) {
    final result = _object(hookResult);
    if (!result.containsKey('capability_limit')) return;
    final rawLimit = result['capability_limit'];
    if (rawLimit is! List) {
      throw const FormatException(
        'before_turn capability_limit must be an array of capabilities.',
      );
    }
    final limit = <String>{};
    for (final value in rawLimit) {
      if (value is! String || value.isEmpty) {
        throw const FormatException(
          'before_turn capability_limit entries must be non-empty strings.',
        );
      }
      limit.add(value);
    }
    final current = _lifecycleHostCapabilities;
    _lifecycleHostCapabilities = current == null
        ? limit
        : (Set<String>.of(current)..retainAll(limit));
  }

  void bindSelectedTools(List<String> ids) {
    for (final id in ids) {
      final pluginId = _pluginId(id);
      final registration = registrations[pluginId];
      final matches = registration?.tools
          .where((tool) => tool.id == id)
          .toList(growable: false);
      if (matches != null && matches.length == 1) {
        _selectedTools[id] = (pluginId: pluginId, tool: matches.single);
        continue;
      }
      throw StateError('Agent tool contribution is not registered: $id');
    }
    _restoreSurfacedTools();
  }

  @override
  List<LuaNestedToolDefinition> definitionsFor(List<String> ids) {
    final definitions = <LuaNestedToolDefinition>[];
    for (final id in ids) {
      final selected = _selectedTools[id];
      if (selected == null) {
        throw FormatException('Unknown or disabled tool contribution: $id');
      }
      final existing = _luaToolIdsByName[selected.tool.name];
      if (existing != null && existing != id) {
        throw FormatException(
          'Lua nested tool name is ambiguous: ${selected.tool.name}',
        );
      }
      _luaToolIdsByName[selected.tool.name] = id;
      definitions.add(
        LuaNestedToolDefinition(
          name: selected.tool.name,
          description: selected.tool.description,
          kind: selected.tool.kind,
          exposure: _isDeferredTool(selected) ? 'deferred' : 'advertised',
          inputSchema: Map<String, dynamic>.from(selected.tool.inputSchema),
          outputSchema: selected.tool.outputSchema == null
              ? null
              : Map<String, dynamic>.from(selected.tool.outputSchema!),
        ),
      );
    }
    return List<LuaNestedToolDefinition>.unmodifiable(definitions);
  }

  void _restoreSurfacedTools() {
    for (final item
        in request.history.whereType<ToolResultConversationItem>()) {
      if (item.toolKind != ModelToolKind.deferredSearch) continue;
      final Object? decoded;
      try {
        decoded = jsonDecode(item.output);
      } on FormatException {
        continue;
      }
      final tools = decoded is Map<Object?, Object?> ? decoded['tools'] : null;
      if (tools is! List) continue;
      for (final raw in tools.whereType<Map<Object?, Object?>>()) {
        final id = raw['canonical_name'];
        if (id is String && _isDeferredTool(_selectedTools[id])) {
          _surfacedToolIds.add(id);
        }
      }
    }
  }

  Future<void> persist(List<ConversationItem> items) async {
    persisted.addAll(items);
    await callbacks.onProviderItems(items);
  }

  /// Effective context payload supplied to any selected tool invocation.
  Map<String, Object?> contextPayload() => <String, Object?>{
    if (request.contextWindowTokens != null)
      'window_tokens': request.contextWindowTokens,
    'usage': _turnUsage.toJson(),
    'used_tokens': _turnUsage.contextTokens,
    if (request.contextWindowTokens != null)
      'remaining_tokens':
          (request.contextWindowTokens! - _turnUsage.contextTokens).clamp(
            0,
            request.contextWindowTokens!,
          ),
  };

  @override
  Future<PluginCallAuthorization> authorize(
    PluginHostCallContext context,
    String name,
    Map<String, Object?> arguments,
  ) async {
    final capability = switch (name) {
      'model.open' => 'model.call',
      'tools.list' || 'tools.surface' => 'tools.list',
      'tools.invoke' ||
      'tools.dynamic_begin' ||
      'tools.dynamic_end' => 'tools.invoke',
      _ when name.startsWith('host.') => _hostCapability(name),
      'state.read' => 'state.read',
      _ when name.startsWith('state.') => 'state.write',
      _ when name.startsWith('scheduler.') => 'scheduler.manage',
      _ when name.startsWith('ui.') => 'ui.publish',
      _ => null,
    };
    if (capability == null) {
      return PluginCallAuthorization.denied(
        'Unknown Tinest host operation: $name',
      );
    }
    _DynamicToolRecord? dynamicRecord;
    if (name.startsWith('host.')) {
      try {
        dynamicRecord = _dynamicPrimitiveRecord(
          context,
          name,
          arguments,
          capability,
        );
      } on FormatException catch (error) {
        return PluginCallAuthorization.denied(error.message);
      }
    }
    final lifecycleLimit = _lifecycleHostCapabilities;
    if (name.startsWith('host.') &&
        lifecycleLimit != null &&
        !lifecycleLimit.contains(capability)) {
      return PluginCallAuthorization.denied(
        'Lifecycle capability restriction denies: $capability',
      );
    }
    if (dynamicRecord != null) {
      if (!context.manifestCapabilities.contains(capability)) {
        return PluginCallAuthorization.denied(
          'Actual host primitive requires an undeclared capability: '
          '$capability',
        );
      }
      if (!context.effectiveCapabilities.contains(capability)) {
        return PluginCallAuthorization.denied(
          'Plugin capability is not granted: $capability',
        );
      }
      // The dispatcher normally intersects with the currently executing
      // handler. An ephemeral callback is a separately declared dynamic tool,
      // so its revision-bound token and own capability set are authoritative.
      return const PluginCallAuthorization.allowed();
    }
    if (name.startsWith('host.') && !context.handlerOperations.contains(name)) {
      return PluginCallAuthorization.denied(
        'Handler did not declare the host primitive in uses: $name',
      );
    }
    return PluginCallAuthorization.allowed(
      requiredCapabilities: <String>{capability},
    );
  }

  String? _hostCapability(String operation) {
    final registered = _primitives.descriptor(operation);
    return registered?.capability;
  }

  @override
  Future<PluginCallbackResult<ConversationAttachment>> call(
    PluginHostCallContext context,
    String name,
    Map<String, Object?> arguments,
    PluginInvocationCancellation invocationCancellation,
  ) async {
    cancellation.throwIfCancelled();
    final dynamicRecord = name.startsWith('host.')
        ? _dynamicPrimitiveRecord(
            context,
            name,
            arguments,
            _hostCapability(name),
          )
        : null;
    final publicArguments = name.startsWith('host.')
        ? _publicHostPrimitiveArguments(arguments)
        : arguments;
    switch (name) {
      case 'tools.list':
        return PluginCallbackResult<ConversationAttachment>(
          value: _listSelectedTools(),
        );
      case 'tools.surface':
        return PluginCallbackResult<ConversationAttachment>(
          value: _surfaceSelectedTools(context, arguments),
        );
      case 'tools.invoke':
        return await _invokePluginTool(context, arguments);
      case 'tools.dynamic_begin':
        return await _beginDynamicTool(context, arguments);
      case 'tools.dynamic_end':
        return await _endDynamicTool(context, arguments);
      case 'state.read':
        return await _readState(context, arguments);
      case 'state.compare_and_set':
        return await _compareAndSetState(context, arguments);
      case 'state.remove':
        return await _removeState(context, arguments);
      case 'state.transaction':
        return await _transactState(context, arguments);
      case 'scheduler.schedule':
      case 'scheduler.continue_after_turn':
        return await _schedule(context, name, arguments);
      case 'scheduler.cancel':
        return await _cancelScheduledJob(context, arguments);
      default:
        if (name.startsWith('ui.')) {
          return _queueUiPublication(context, name, arguments);
        }
        if (name.startsWith('host.')) {
          return await _invokeHostPrimitive(
            context,
            name,
            publicArguments,
            invocationCancellation,
            dynamicRecord: dynamicRecord,
          );
        }
        return PluginCallbackResult<ConversationAttachment>(
          value: 'Host operation is not configured: $name',
          isError: true,
        );
    }
  }

  Map<String, Object?> _publicHostPrimitiveArguments(
    Map<String, Object?> arguments,
  ) => <String, Object?>{
    for (final entry in arguments.entries)
      if (entry.key != '_tinest_dynamic_token') entry.key: entry.value,
  };

  _DynamicToolRecord? _dynamicPrimitiveRecord(
    PluginHostCallContext context,
    String operation,
    Map<String, Object?> arguments,
    String? capability,
  ) {
    final token = arguments['_tinest_dynamic_token'];
    if (token == null) return null;
    if (capability == null) {
      throw FormatException('Unknown host primitive: $operation');
    }
    if (token is! String || token.isEmpty) {
      throw const FormatException('Dynamic primitive token is invalid.');
    }
    final dynamicId =
        _dynamicToolIdsByIdentity[_dynamicToolIdentity(
          context.pluginId,
          context.revisionHash,
          token,
        )];
    final record = dynamicId == null ? null : _dynamicTools[dynamicId];
    if (record == null ||
        !record.ephemeral ||
        record.callerPluginId != context.pluginId ||
        record.callerRevisionHash != context.revisionHash) {
      throw const FormatException(
        'Dynamic primitive token is forged, foreign, or stale.',
      );
    }
    if (!record.declaredCapabilities.contains(capability)) {
      throw FormatException(
        'Dynamic tool did not declare the capability for $operation: '
        '$capability',
      );
    }
    if (!record.declaredOperations.contains(operation)) {
      throw FormatException(
        'Dynamic tool did not declare the host primitive in uses: $operation',
      );
    }
    return record;
  }

  PluginCallbackResult<ConversationAttachment> _queueUiPublication(
    PluginHostCallContext context,
    String operation,
    Map<String, Object?> arguments,
  ) {
    if (_renderingPluginUi) {
      return const PluginCallbackResult<ConversationAttachment>(
        value: 'A plugin UI renderer cannot publish another UI document.',
        isError: true,
      );
    }
    final slot = switch (operation) {
      'ui.timeline' => PluginUiSlot.timeline,
      'ui.status' => PluginUiSlot.conversationStatus,
      'ui.dialog' => PluginUiSlot.dialog,
      'ui.toast' => PluginUiSlot.toast,
      _ => null,
    };
    if (slot == null) {
      return PluginCallbackResult<ConversationAttachment>(
        value: 'Unsupported plugin UI publication: $operation',
        isError: true,
      );
    }
    final contributionId = arguments['contribution_id'];
    if (contributionId is! String || contributionId.isEmpty) {
      return const PluginCallbackResult<ConversationAttachment>(
        value: 'Plugin UI publication requires contribution_id.',
        isError: true,
      );
    }
    final registration = registrations[context.pluginId];
    final matches = registration?.ui.where(
      (candidate) => candidate.id == contributionId,
    );
    if (registration == null ||
        registration.revisionHash != context.revisionHash ||
        matches == null ||
        matches.length != 1 ||
        matches.single.slot != slot) {
      return PluginCallbackResult<ConversationAttachment>(
        value:
            'Plugin UI contribution $contributionId is not registered for '
            '${slot.name} at ${context.revisionHash}.',
        isError: true,
      );
    }
    final contribution = matches.single;
    final value = arguments['value'];
    try {
      validatePluginJsonSchema(
        contribution.inputSchema,
        value,
        path: r'$.value',
      );
    } on PluginJsonValidationException catch (error) {
      return PluginCallbackResult<ConversationAttachment>(
        value: 'Plugin UI publication value is invalid: ${error.message}',
        isError: true,
      );
    }
    _pendingUiPublications.add(
      _PendingUiPublication(
        operation: operation,
        pluginId: context.pluginId,
        revisionHash: context.revisionHash,
        contributionId: contributionId,
        slot: slot,
        callId: _activeCalls[context.pluginId]?.callId,
        arguments: Map<String, Object?>.unmodifiable(arguments),
      ),
    );
    return PluginCallbackResult<ConversationAttachment>(
      value: <String, Object?>{
        'plugin_id': context.pluginId,
        'revision_hash': context.revisionHash,
        'contribution_id': contributionId,
        'slot': slot.name,
        'queued': true,
      },
    );
  }

  List<Map<String, Object?>> _listSelectedTools() => <Map<String, Object?>>[
    for (final value in _selectedTools.values)
      <String, Object?>{
        ..._toolDescriptor(value),
        'surfaced': _surfacedToolIds.contains(value.tool.id),
        if (_isDynamicTemplate(value)) '_tinest_template': true,
        if (_dynamicTools[value.tool.id] case final dynamicTool?)
          '_tinest_token': dynamicTool.token,
      },
  ];

  Map<String, Object?> _surfaceSelectedTools(
    PluginHostCallContext context,
    Map<String, Object?> arguments,
  ) {
    final rawIds = arguments['ids'];
    if (rawIds is! List<Object?>) {
      throw const FormatException('tools.surface ids must be an array.');
    }
    final descriptors = <Map<String, Object?>>[];
    for (final rawId in rawIds) {
      if (rawId is! String) {
        throw const FormatException('tools.surface ids must be strings.');
      }
      final selected = _selectedTools[rawId];
      if (selected == null || !_isDeferredTool(selected)) {
        throw FormatException(
          'Tool is not a selected deferred contribution: $rawId',
        );
      }
      _surfacedToolIds.add(rawId);
      descriptors.add(_surfaceToolDescriptor(selected));
    }
    final restoration = <Map<String, Object?>>[];
    final rawDynamic = arguments['dynamic'];
    if (rawDynamic != null && rawDynamic is! List<Object?>) {
      throw const FormatException('tools.surface dynamic must be an array.');
    }
    for (final raw in (rawDynamic as List<Object?>? ?? const <Object?>[])) {
      final request = _object(raw);
      final privateRefId = _integer(request['private_ref_id']);
      if (privateRefId == null || privateRefId < 1) {
        throw const FormatException(
          'Dynamic tool private_ref_id must be a positive integer.',
        );
      }
      final mode = request['mode'];
      if (mode != 'from_template' && mode != 'ephemeral') {
        throw const FormatException('Unsupported dynamic tool mode.');
      }
      final materialized = _materializeDynamicTool(
        context,
        _object(request['spec']),
        privateRefId: privateRefId,
        ephemeral: mode == 'ephemeral',
      );
      descriptors.add(<String, Object?>{
        ..._surfaceToolDescriptor(materialized.selected),
        '_tinest_private_ref_id': privateRefId,
        '_tinest_token': materialized.record.token,
      });
      if (!materialized.record.ephemeral) {
        restoration.add(materialized.record.toJson());
      }
    }
    return <String, Object?>{
      'tools': descriptors,
      if (restoration.isNotEmpty) 'dynamic_tools': restoration,
    };
  }

  _MaterializedDynamicTool _materializeDynamicTool(
    PluginHostCallContext context,
    Map<String, Object?> spec, {
    required int privateRefId,
    required bool ephemeral,
  }) {
    final localId = _requiredString(spec, 'id');
    if (!RegExp(r'^[a-z][a-z0-9_-]*$').hasMatch(localId)) {
      throw const FormatException(
        'Dynamic tool IDs must be lowercase local IDs.',
      );
    }
    final kind = (spec['kind'] ?? 'function').toString();
    if (kind != 'function') {
      throw const FormatException('Dynamic tools must be function tools.');
    }
    final inputSchema = _requiredSchema(spec, 'input_schema');
    final outputSchema = spec['output_schema'] == null
        ? null
        : _requiredSchema(spec, 'output_schema');
    final templateId = ephemeral ? null : _requiredString(spec, 'template_id');
    final templateMatches = templateId == null
        ? const <PluginToolRegistration>[]
        : registrations[context.pluginId]?.templates
                  .where((template) => template.id == templateId)
                  .toList(growable: false) ??
              const <PluginToolRegistration>[];
    final template = templateMatches.length == 1
        ? templateMatches.single
        : null;
    if (!ephemeral && template == null) {
      throw FormatException(
        'Dynamic template is foreign, stale, or unselected: $templateId',
      );
    }
    if (template != null) {
      final registration = registrations[context.pluginId];
      if (registration == null ||
          registration.revisionHash != spec['template_execution_revision'] &&
              spec['template_execution_revision'] != null) {
        throw FormatException(
          'Dynamic template revision is unavailable: $templateId',
        );
      }
      final payloadSchema = template.payloadSchema!;
      validatePluginJsonSchema(
        payloadSchema,
        spec['payload'],
        path: r'$.dynamic.payload',
      );
    }
    final ownerPluginId = context.pluginId;
    final id = '$ownerPluginId/$localId';
    final existing = _selectedTools[id];
    if (existing != null && !_dynamicTools.containsKey(id)) {
      throw FormatException(
        'Dynamic tool collides with a declared contribution: $id',
      );
    }
    final name = (spec['name'] ?? localId).toString();
    if (name.trim().isEmpty) {
      throw const FormatException('Dynamic tool name must not be empty.');
    }
    final description = (spec['description'] ?? name).toString();
    final declaredCapabilities = _stringSet(
      spec['required_capabilities'],
      'dynamic required_capabilities',
    );
    final declaredOperations = _stringSet(
      spec['declared_operations'],
      'dynamic declared_operations',
    );
    // An ephemeral tool callback is a distinct contribution even though its
    // closure executes in the driver's VM. Its own `uses` refs define the
    // capability ceiling; the driver must not inherit those capabilities.
    final ceiling =
        template?.requiredCapabilities ?? context.manifestCapabilities;
    if (!ceiling.containsAll(declaredCapabilities)) {
      throw const FormatException(
        'Dynamic tool capabilities exceed their template or handler.',
      );
    }
    final effects = <String>{
      ...?template?.effects,
      ..._stringSet(spec['effects'], 'dynamic effects'),
    };
    final presentation = <String, Object?>{
      ...?template?.presentation,
      ..._resolveDynamicPresentation(
        _object(spec['presentation']),
        context.pluginId,
      ),
      'dynamicContributionId': id,
      'dynamicTemplateId': ?templateId,
      if (!ephemeral) 'dynamicPayload': normalizePluginJson(spec['payload']),
    };
    final token =
        request.ids?.generate() ??
        '${request.turnId}:${++_dynamicToolGeneration}:'
            '${context.revisionHash}:$privateRefId';
    final tool = PluginToolRegistration(
      id: id,
      name: name,
      description: description,
      binding:
          template?.binding ??
          PluginHandlerBinding(
            pluginId: context.pluginId,
            executionRevisionHash: context.revisionHash,
            kind: PluginHandlerKind.tool,
            localId: localId,
            internalKey: '__tinest.ephemeral.$localId',
          ),
      kind: kind,
      inputSchema: inputSchema,
      outputSchema: outputSchema,
      payloadSchema: null,
      effects: Set<String>.unmodifiable(effects),
      requiredCapabilities: Set<String>.unmodifiable(
        template?.requiredCapabilities ?? declaredCapabilities,
      ),
      declaredOperations: Set<String>.unmodifiable(
        template?.declaredOperations ?? declaredOperations,
      ),
      presentation: Map<String, Object?>.unmodifiable(presentation),
    );
    final selected = (pluginId: ownerPluginId, tool: tool);
    final record = _DynamicToolRecord(
      token: token,
      privateRefId: privateRefId,
      ephemeral: ephemeral,
      callerPluginId: context.pluginId,
      callerRevisionHash: context.revisionHash,
      templateId: templateId,
      templateExecutionRevision: template == null
          ? null
          : registrations[context.pluginId]!.revisionHash,
      payload: normalizePluginJson(spec['payload']),
      declaredCapabilities: Set<String>.unmodifiable(
        template?.requiredCapabilities ?? declaredCapabilities,
      ),
      declaredOperations: Set<String>.unmodifiable(
        template?.declaredOperations ?? declaredOperations,
      ),
    );
    _selectedTools[id] = selected;
    _dynamicTools[id] = record;
    final identity = _dynamicToolIdentity(
      record.callerPluginId,
      record.callerRevisionHash,
      record.token,
    );
    final existingIdentity = _dynamicToolIdsByIdentity[identity];
    if (existingIdentity != null && existingIdentity != id) {
      throw const FormatException('Dynamic tool token is not unique.');
    }
    _dynamicToolIdsByIdentity[identity] = id;
    _surfacedToolIds.add(id);
    return (selected: selected, record: record);
  }

  Future<PluginCallbackResult<ConversationAttachment>> _beginDynamicTool(
    PluginHostCallContext context,
    Map<String, Object?> arguments,
  ) async {
    final id = _requiredString(arguments, 'id');
    final token = _requiredString(arguments, 'token');
    final selected = _selectedTools[id];
    final record = _dynamicTools[id];
    final identity = _dynamicToolIdentity(
      context.pluginId,
      context.revisionHash,
      token,
    );
    if (selected == null ||
        record == null ||
        !record.ephemeral ||
        selected.pluginId != context.pluginId ||
        record.callerPluginId != context.pluginId ||
        record.callerRevisionHash != context.revisionHash ||
        record.token != token ||
        _dynamicToolIdsByIdentity[identity] != id) {
      throw const FormatException(
        'Dynamic tool reference is forged, foreign, or stale.',
      );
    }
    if (_pendingDynamicToolCalls.containsKey(identity) ||
        _activeCalls.containsKey(context.pluginId)) {
      throw const FormatException(
        'A dynamic tool invocation is already active for this plugin.',
      );
    }
    final suppliedCallId = arguments['call_id'];
    if (suppliedCallId != null &&
        (suppliedCallId is! String || suppliedCallId.isEmpty)) {
      throw const FormatException(
        'Dynamic tool call_id must be a non-empty string.',
      );
    }
    final callId =
        suppliedCallId as String? ?? '${request.turnId}:tool-${toolRounds + 1}';
    final input = _normalizeToolInput(selected.tool, arguments['arguments']);
    PluginJsonValidationException? validationError;
    try {
      validatePluginJsonSchema(
        selected.tool.inputSchema,
        input,
        path: r'$.arguments',
      );
    } on PluginJsonValidationException catch (error) {
      validationError = error;
    }
    toolRounds += 1;
    await runHooks(PluginLifecycle.beforeTool, <String, Object?>{
      'id': id,
      'call_id': callId,
      'arguments': input,
    });
    final pending = _PendingDynamicToolCall(
      identity: identity,
      pluginId: context.pluginId,
      revisionHash: context.revisionHash,
      contributionId: id,
      token: token,
      callId: callId,
      input: input,
      resources: <ConversationAttachment>[],
    );
    _pendingDynamicToolCalls[identity] = pending;
    _activeCalls[context.pluginId] = _ActiveToolCall(
      callId: callId,
      contributionId: id,
      arguments: _toolArgumentsMap(input),
    );
    if (validationError == null) {
      return PluginCallbackResult<ConversationAttachment>(
        value: <String, Object?>{'execute': true, 'call_id': callId},
      );
    }
    final result = ToolResult(
      value: <String, Object?>{
        'code': 'invalid_tool_arguments',
        'message': validationError.message,
        'retryable': false,
        'details': <String, Object?>{'path': validationError.path},
      },
      isError: true,
    );
    try {
      final completed = await _completeToolCall(pending, result);
      return PluginCallbackResult<ConversationAttachment>(
        value: <String, Object?>{
          'execute': false,
          'call_id': callId,
          'result': _pluginToolResultValue(completed),
        },
      );
    } finally {
      _clearPendingDynamicTool(pending);
    }
  }

  Future<PluginCallbackResult<ConversationAttachment>> _endDynamicTool(
    PluginHostCallContext context,
    Map<String, Object?> arguments,
  ) async {
    final id = _requiredString(arguments, 'id');
    final token = _requiredString(arguments, 'token');
    final callId = _requiredString(arguments, 'call_id');
    final identity = _dynamicToolIdentity(
      context.pluginId,
      context.revisionHash,
      token,
    );
    final pending = _pendingDynamicToolCalls[identity];
    final active = _activeCalls[context.pluginId];
    if (pending == null ||
        pending.pluginId != context.pluginId ||
        pending.revisionHash != context.revisionHash ||
        pending.contributionId != id ||
        pending.token != token ||
        pending.callId != callId ||
        active?.contributionId != id ||
        active?.callId != callId) {
      throw const FormatException(
        'Dynamic tool completion is forged, foreign, stale, or mismatched.',
      );
    }
    ToolResult result;
    if (arguments.containsKey('error')) {
      discardUiPublications();
      result = ToolResult(
        value: '$id failed: ${arguments['error']}',
        isError: true,
        attachments: List<ConversationAttachment>.unmodifiable(
          pending.resources,
        ),
        contextImages: _contextImages(pending.resources),
      );
    } else {
      result = _validatedToolResult(
        _selectedTools[id]!.tool,
        arguments['result'],
        resources: pending.resources,
      );
    }
    try {
      final completed = await _completeToolCall(pending, result);
      return PluginCallbackResult<ConversationAttachment>(
        value: _pluginToolResultValue(completed),
        resources: _opaqueResources(completed),
      );
    } finally {
      _clearPendingDynamicTool(pending);
    }
  }

  void _clearPendingDynamicTool(_PendingDynamicToolCall pending) {
    _pendingDynamicToolCalls.remove(pending.identity);
    final active = _activeCalls[pending.pluginId];
    if (active?.callId == pending.callId &&
        active?.contributionId == pending.contributionId) {
      _activeCalls.remove(pending.pluginId);
    }
  }

  Future<PluginCallbackResult<ConversationAttachment>> _readState(
    PluginHostCallContext context,
    Map<String, Object?> arguments,
  ) async {
    final store = request.state;
    if (store == null) return _unavailable('Plugin state');
    final entry = validatePluginStateCellEntry(
      arguments,
      await store.read(
        _stateScope(context, arguments),
        _requiredString(arguments, 'key'),
      ),
    );
    return PluginCallbackResult<ConversationAttachment>(
      value: pluginStateReadEnvelope(entry),
    );
  }

  Future<PluginCallbackResult<ConversationAttachment>> _compareAndSetState(
    PluginHostCallContext context,
    Map<String, Object?> arguments,
  ) async {
    final store = request.state;
    if (store == null) return _unavailable('Plugin state');
    final entry = await store.compareAndSet(
      _stateScope(context, arguments),
      _requiredString(arguments, 'key'),
      expectedRevision: _integer(arguments['expected_revision']) ?? 0,
      value: validatePluginStateCellValue(
        arguments,
        arguments['value'],
        path: r'$.value',
      ),
    );
    return PluginCallbackResult<ConversationAttachment>(
      value: _stateEntry(entry),
    );
  }

  Future<PluginCallbackResult<ConversationAttachment>> _removeState(
    PluginHostCallContext context,
    Map<String, Object?> arguments,
  ) async {
    final store = request.state;
    if (store == null) return _unavailable('Plugin state');
    final key = _requiredString(arguments, 'key');
    final values = await store.transaction(
      _stateScope(context, arguments),
      (_) => <PluginStateMutation>[
        PluginStateMutation.remove(
          key: key,
          expectedRevision: _integer(arguments['expected_revision']) ?? 0,
        ),
      ],
    );
    return PluginCallbackResult<ConversationAttachment>(
      value: <String, Object?>{
        for (final entry in values.entries) entry.key: _stateEntry(entry.value),
      },
    );
  }

  Future<PluginCallbackResult<ConversationAttachment>> _transactState(
    PluginHostCallContext context,
    Map<String, Object?> arguments,
  ) async {
    final store = request.state;
    if (store == null) return _unavailable('Plugin state');
    final mutations = <PluginStateMutation>[
      for (final raw in _list(arguments['mutations']))
        if (_dynamicObject(raw) case final mutation)
          if (mutation['remove'] == true)
            PluginStateMutation.remove(
              key: _requiredString(mutation, 'key'),
              expectedRevision: _integer(mutation['expected_revision']) ?? 0,
            )
          else
            PluginStateMutation.put(
              key: _requiredString(mutation, 'key'),
              expectedRevision: _integer(mutation['expected_revision']) ?? 0,
              value: validatePluginStateCellValue(
                arguments,
                mutation['value'],
                path: r'$.mutations.value',
              ),
            ),
    ];
    final values = await store.transaction(
      _stateScope(context, arguments),
      (_) => mutations,
    );
    return PluginCallbackResult<ConversationAttachment>(
      value: <String, Object?>{
        for (final entry in values.entries) entry.key: _stateEntry(entry.value),
      },
    );
  }

  Future<PluginCallbackResult<ConversationAttachment>> _schedule(
    PluginHostCallContext context,
    String operation,
    Map<String, Object?> arguments,
  ) async {
    final jobs = request.jobs;
    final clock = request.clock;
    final ids = request.ids;
    if (jobs == null || clock == null || ids == null) {
      return _unavailable('Plugin scheduler');
    }
    final registration = registrations[context.pluginId];
    if (registration == null) {
      throw StateError(
        'Plugin registration is unavailable while scheduling: '
        '${context.pluginId}.',
      );
    }
    final bindingId = _requiredString(arguments, 'binding_id');
    final handler = resolvePluginScheduledHandler(
      registration: registration,
      pluginId: context.pluginId,
      executionRevisionHash: context.revisionHash,
      bindingId: bindingId,
    );
    final payload = validatePluginScheduledPayload(
      handler,
      arguments['payload'],
      path: r'$.payload',
    );
    final delay = Duration(
      milliseconds: (_integer(arguments['delay_ms']) ?? 0).clamp(0, 86400000),
    );
    final job = PluginJob(
      id: ids.generate(),
      pluginId: context.pluginId,
      executionRevisionHash: context.revisionHash,
      bindingId: bindingId,
      payload: payload,
      dueAt: clock.nowUtc().add(delay),
      agentId: context.agentId,
      sessionId: context.sessionId,
    );
    await jobs.enqueue(job);
    return PluginCallbackResult<ConversationAttachment>(
      value: <String, Object?>{
        'id': job.id,
        'due_at': job.dueAt.toIso8601String(),
        'continuation': operation == 'scheduler.continue_after_turn',
      },
    );
  }

  Future<PluginCallbackResult<ConversationAttachment>> _cancelScheduledJob(
    PluginHostCallContext context,
    Map<String, Object?> arguments,
  ) async {
    final jobs = request.jobs;
    if (jobs == null) return _unavailable('Plugin scheduler');
    final id = _requiredString(arguments, 'id');
    final cancelled = await jobs.cancel(
      id,
      pluginId: context.pluginId,
      agentId: context.agentId,
      sessionId: context.sessionId,
    );
    return PluginCallbackResult<ConversationAttachment>(
      value: <String, Object?>{'id': id, 'cancelled': cancelled},
    );
  }

  @override
  Stream<PluginCallbackResult<ConversationAttachment>> open(
    PluginHostCallContext context,
    String name,
    Map<String, Object?> arguments,
    PluginInvocationCancellation invocationCancellation,
  ) async* {
    if (name != 'model.open') {
      yield PluginCallbackResult<ConversationAttachment>(
        value: 'Host stream is not configured: $name',
        isError: true,
      );
      return;
    }
    final modelStartedAt = request.clock?.nowUtc();
    var modelUsage = const ModelUsage();
    await runHooks(PluginLifecycle.beforeModel, arguments);
    try {
      final history = <ConversationItem>[];
      for (final item in _list(arguments['history'])) {
        try {
          history.add(_driverHistoryItem(item));
        } on Object catch (error) {
          throw FormatException(
            'Invalid driver history item ${jsonEncode(item)}: $error',
          );
        }
      }
      final tools = _list(arguments['tools'])
          .map(_modelTool)
          .toList(growable: false);
      final surfaceError = _selectedToolCompatibilityError(
        tools,
        request.modelCapabilities,
      );
      if (surfaceError != null) {
        // Provider incompatibility is a core contract failure, not a model
        // stream event that a driver may accidentally ignore.
        _fatalModelContractError ??= surfaceError;
        throw StateError(surfaceError);
      }
      final List<ModelRoleBlock> blocks;
      try {
        blocks = _modelRoleBlocks(arguments['blocks']);
      } on FormatException catch (error) {
        // A role outside the neutral vocabulary is a core contract failure,
        // not a model stream event a driver may accidentally ignore.
        _fatalModelContractError ??= error.message;
        throw StateError(error.message);
      }
      await for (final event in request.model.stream(
        ModelRequest(
          model: request.modelId,
          blocks: blocks,
          history: history,
          tools: tools,
          modelControls: request.modelControls,
          forceToolName: arguments['force_tool_name'] as String?,
        ),
        cancellation,
      )) {
        switch (event) {
          case ModelReasoningDelta(:final delta):
            await callbacks.onEvent(
              'assistant.reasoning.delta',
              <String, dynamic>{'text': delta},
            );
            yield PluginCallbackResult<ConversationAttachment>(
              value: <String, Object?>{'type': 'reasoning', 'delta': delta},
            );
          case ModelTextDelta(:final delta):
            await callbacks.onEvent('assistant.delta', <String, dynamic>{
              'text': delta,
            });
            yield PluginCallbackResult<ConversationAttachment>(
              value: <String, Object?>{'type': 'text', 'delta': delta},
            );
          case ModelToolCall():
            final selected = _selectedToolByModelName(event.name);
            await callbacks.onEvent('tool.requested', <String, dynamic>{
              'callId': event.callId,
              'name': event.name,
              'arguments': event.arguments,
              if (selected != null) 'contributionId': selected.tool.id,
              if (selected != null) 'presentation': selected.tool.presentation,
            });
            yield PluginCallbackResult<ConversationAttachment>(
              value: <String, Object?>{
                'type': 'tool_call',
                'call_id': event.callId,
                'name': event.name,
                'arguments': event.arguments,
              },
            );
          case ModelResponseCompleted(:final assistant, :final usage):
            modelUsage = usage;
            _turnUsage = usage;
            if (arguments['persist_completion'] != false) {
              await persist(<ConversationItem>[assistant]);
            }
            await callbacks.onEvent('model.usage', usage.toJson());
            yield PluginCallbackResult<ConversationAttachment>(
              value: <String, Object?>{'type': 'usage', ...usage.toJson()},
            );
            yield PluginCallbackResult<ConversationAttachment>(
              value: <String, Object?>{
                'type': 'completion',
                'assistant': assistant.toJson(),
                'usage': usage.toJson(),
              },
            );
        }
      }
    } on AgentCancelledException {
      yield const PluginCallbackResult<ConversationAttachment>(
        value: <String, Object?>{
          'type': 'error',
          'code': 'cancelled',
          'message': 'Model call was cancelled.',
        },
        isError: true,
      );
    } on ModelContextOverflowException catch (error) {
      yield PluginCallbackResult<ConversationAttachment>(
        value: <String, Object?>{
          'type': 'error',
          'code': 'context_overflow',
          'message': error.message,
        },
      );
    } on Object catch (error) {
      yield PluginCallbackResult<ConversationAttachment>(
        value: <String, Object?>{
          'type': 'error',
          'code': 'model_host_error',
          'message': error.toString(),
        },
      );
    } finally {
      final modelFinishedAt = request.clock?.nowUtc();
      final elapsedSeconds = modelStartedAt == null || modelFinishedAt == null
          ? 0
          : modelFinishedAt
                .difference(modelStartedAt)
                .inSeconds
                .clamp(0, 1 << 31);
      // A cancelled turn tears this stream down through the runtime's own
      // unawaited cell close, where any throw becomes an unhandled isolate
      // error, and a fresh hook invocation against the cancelled token dies
      // instantly anyway. The terminal cancel hooks already deliver the
      // plugin its lifecycle, so skip after-model on that path. Read the turn
      // token directly: while terminal hooks run, the lifecycle getter swaps
      // in their fresh token and would hide the cancellation.
      if (!_turnCancellation.isCancelled) {
        await runHooks(PluginLifecycle.afterModel, <String, Object?>{
          ...arguments,
          'usage': modelUsage.toJson(),
          'elapsed_seconds': elapsedSeconds,
        });
      }
    }
  }

  ConversationItem _driverHistoryItem(Object? value) {
    final normalized = _normalizeDriverHistoryItem(value);
    if (normalized['type'] == 'user' && normalized['attachments'] is List) {
      normalized['attachments'] = <Map<String, dynamic>>[
        for (final raw in normalized['attachments']! as List)
          (() {
            final reference = _dynamicObject(raw);
            final id = reference['id'];
            final attachment = id is String ? _hydratedAttachments[id] : null;
            if (attachment == null) {
              throw const FormatException(
                'Driver history referenced an unknown attachment.',
              );
            }
            return attachment.toJson();
          })(),
      ];
    }
    final item = ConversationItem.fromJson(normalized);
    if (item is! UserConversationItem || item.attachments.isEmpty) return item;
    return UserConversationItem(
      item.text,
      attachments: <ConversationAttachment>[
        for (final attachment in item.attachments)
          _hydratedAttachments[attachment.id] ?? attachment,
      ],
    );
  }

  Future<PluginCallbackResult<ConversationAttachment>> _invokePluginTool(
    PluginHostCallContext context,
    Map<String, Object?> arguments,
  ) async {
    final id = arguments['id']?.toString();
    if (id == null || !_selectedTools.containsKey(id)) {
      return PluginCallbackResult<ConversationAttachment>(
        value: <String, Object?>{
          'output': 'Unknown or disabled tool contribution: $id',
          'is_error': true,
        },
      );
    }
    final dynamicTool = _dynamicTools[id];
    if (dynamicTool != null) {
      final token = arguments['token'];
      if (token != dynamicTool.token) {
        return const PluginCallbackResult<ConversationAttachment>(
          value: <String, Object?>{
            'output': 'Dynamic tool reference is forged, foreign, or stale.',
            'is_error': true,
          },
        );
      }
      if (dynamicTool.ephemeral) {
        return const PluginCallbackResult<ConversationAttachment>(
          value: <String, Object?>{
            'output': 'Ephemeral tool callbacks must run in their owning VM.',
            'is_error': true,
          },
        );
      }
    }
    final selected = _selectedTools[id]!;
    final input = _normalizeToolInput(selected.tool, arguments['arguments']);
    final callId =
        arguments['call_id']?.toString() ??
        '${request.turnId}:tool-${toolRounds + 1}';
    final result = await _runSelectedTool(id, input, callId);
    return PluginCallbackResult<ConversationAttachment>(
      value: _pluginToolResultValue(result),
      resources: _opaqueResources(result),
    );
  }

  @override
  Future<LuaNestedToolResult> invoke(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    final id = _luaToolIdsByName[name];
    if (id == null) {
      return LuaNestedToolResult(
        value: 'Unknown or unselected Lua nested tool: $name',
        isError: true,
      );
    }
    final result = await _runSelectedTool(
      id,
      Map<String, Object?>.from(arguments),
      '${request.turnId}:lua-${toolRounds + 1}',
    );
    return LuaNestedToolResult(
      value: result.value,
      isError: result.isError,
      content: result.content.map((value) => value.toJson()).toList(),
      structuredContent: result.structuredContent,
      meta: result.meta,
      attachments: result.attachments,
      contextImages: result.contextImages,
    );
  }

  Future<ToolResult> _runSelectedTool(
    String id,
    Object? input,
    String callId,
  ) async {
    final selected = _selectedTools[id]!;
    PluginJsonValidationException? inputValidationError;
    try {
      validatePluginJsonSchema(
        selected.tool.inputSchema,
        input,
        path: r'$.arguments',
      );
    } on PluginJsonValidationException catch (error) {
      inputValidationError = error;
    }
    final internal = <String, Object?>{
      'context': contextPayload(),
      'settings':
          pluginSettings[selected.pluginId] ?? const <String, Object?>{},
    };
    toolRounds += 1;
    await runHooks(PluginLifecycle.beforeTool, <String, Object?>{
      'id': id,
      'call_id': callId,
      'arguments': input,
    });
    ToolResult result;
    _activeCalls[selected.pluginId] = _ActiveToolCall(
      callId: callId,
      contributionId: id,
      arguments: _toolArgumentsMap(input),
    );
    try {
      try {
        if (inputValidationError != null) {
          result = ToolResult(
            value: <String, Object?>{
              'code': 'invalid_tool_arguments',
              'message': inputValidationError.message,
              'retryable': false,
              'details': <String, Object?>{'path': inputValidationError.path},
            },
            isError: true,
          );
        } else {
          final dynamicTool = _dynamicTools[id];
          final handlerInput = <String, Object?>{
            ..._object(input),
            '_tinest': internal,
          };
          final invocation = await session.invoke(
            pluginId: selected.pluginId,
            binding: selected.tool.binding,
            arguments: dynamicTool?.templateId != null
                ? <String, Object?>{
                    'payload': dynamicTool!.payload,
                    'arguments': handlerInput,
                  }
                : handlerInput,
            callbackRouter: this,
            cancellation: _PluginCancellation(cancellation),
          );
          final completed = await invocation.complete();
          if (completed.error != null) {
            discardUiPublications();
            result = ToolResult(
              value: '$id failed: ${completed.error}',
              isError: true,
            );
          } else {
            final resources = <ConversationAttachment>[];
            for (final resource in completed.deltas.expand(
              (delta) => delta.resources,
            )) {
              final attachment = resource.value;
              _addToolResource(resources, attachment);
            }
            result = _validatedToolResult(
              selected.tool,
              completed.result,
              resources: resources,
            );
          }
        }
      } on AgentCancelledException {
        rethrow;
      } on Exception catch (error) {
        discardUiPublications();
        result = ToolResult(value: '$id failed: $error', isError: true);
      }
      return await _finalizeToolCall(
        selected: selected,
        contributionId: id,
        callId: callId,
        input: input,
        result: result,
      );
    } finally {
      _activeCalls.remove(selected.pluginId);
    }
  }

  Future<ToolResult> _completeToolCall(
    _PendingDynamicToolCall pending,
    ToolResult result,
  ) => _finalizeToolCall(
    selected: _selectedTools[pending.contributionId]!,
    contributionId: pending.contributionId,
    callId: pending.callId,
    input: pending.input,
    result: result,
  );

  Future<ToolResult> _finalizeToolCall({
    required ({String pluginId, PluginToolRegistration tool}) selected,
    required String contributionId,
    required String callId,
    required Object? input,
    required ToolResult result,
  }) async {
    final denied = _deniedToolCallIds.remove(callId);
    final item = ToolResultConversationItem(
      callId: callId,
      output: result.output,
      toolKind: _modelToolKind(selected.tool),
      isError: result.isError,
      content: result.content,
      structuredContent: result.structuredContent,
      meta: result.meta,
    );
    final contextItem = result.contextImages.isEmpty
        ? null
        : UserConversationItem('', attachments: result.contextImages);
    await persist(<ConversationItem>[item, ?contextItem]);
    for (final notification in result.notifications) {
      await callbacks.onEvent('tool.notification', <String, dynamic>{
        'callId': callId,
        'name': selected.tool.name,
        'value': notification,
      });
    }
    for (final attachment in result.attachments) {
      await callbacks.onEvent(
        'assistant.attachment',
        _publicAttachmentJson(attachment),
      );
    }
    _queueToolPresentation(
      selected: selected,
      contributionId: contributionId,
      callId: callId,
      arguments: _toolArgumentsMap(input),
      result: result,
    );
    await callbacks.onEvent(
      denied ? 'tool.denied' : 'tool.completed',
      <String, dynamic>{
        'callId': callId,
        'name': selected.tool.name,
        'contributionId': contributionId,
        'output': result.output,
        'isError': denied || result.isError,
        'presentation': selected.tool.presentation,
      },
    );
    await flushUiPublications();
    await runHooks(PluginLifecycle.afterTool, <String, Object?>{
      'id': contributionId,
      'call_id': callId,
      'is_error': result.isError,
    });
    return result;
  }

  ToolResult _validatedToolResult(
    PluginToolRegistration tool,
    Object? value, {
    required List<ConversationAttachment> resources,
  }) {
    final envelope = value is Map ? _object(value) : null;
    final isExplicitValue = envelope?[_toolValueMarker] == true;
    if (isExplicitValue &&
        (envelope!.length != 2 || !envelope.containsKey('value'))) {
      discardUiPublications();
      return ToolResult(
        value: const <String, Object?>{
          'code': 'invalid_tool_result',
          'message': 'Explicit tool values must contain exactly one value.',
          'retryable': false,
          'details': <String, Object?>{'path': r'$.result'},
        },
        isError: true,
        attachments: List<ConversationAttachment>.unmodifiable(resources),
        contextImages: _contextImages(resources),
      );
    }
    final resultValue = isExplicitValue ? envelope!['value'] : value;
    final outputSchema = tool.outputSchema;
    if (outputSchema != null) {
      try {
        validatePluginJsonSchema(outputSchema, resultValue, path: r'$.result');
      } on PluginJsonValidationException catch (error) {
        discardUiPublications();
        return ToolResult(
          value: <String, Object?>{
            'code': 'invalid_tool_result',
            'message': error.message,
            'retryable': false,
            'details': <String, Object?>{'path': error.path},
          },
          isError: true,
          attachments: List<ConversationAttachment>.unmodifiable(resources),
          contextImages: _contextImages(resources),
        );
      }
    }
    final base = isExplicitValue
        ? ToolResult(value: resultValue)
        : _toolResult(value);
    final attachments = <ConversationAttachment>[...base.attachments];
    for (final resource in resources) {
      _addToolResource(attachments, resource);
    }
    return ToolResult(
      value: base.value,
      isError: base.isError,
      content: base.content,
      structuredContent: base.structuredContent,
      meta: base.meta,
      attachments: List<ConversationAttachment>.unmodifiable(attachments),
      contextImages: _contextImages(attachments),
      notifications: base.notifications,
    );
  }

  void _addToolResource(
    List<ConversationAttachment> resources,
    ConversationAttachment attachment,
  ) {
    _hydratedAttachments[attachment.id] = attachment;
    if (!resources.any((candidate) => candidate.id == attachment.id)) {
      resources.add(attachment);
    }
  }

  List<ConversationAttachment> _contextImages(
    Iterable<ConversationAttachment> resources,
  ) => List<ConversationAttachment>.unmodifiable(
    resources.where((attachment) => attachment.imageDetail != null),
  );

  List<PluginOpaqueResource<ConversationAttachment>> _opaqueResources(
    ToolResult result,
  ) => <PluginOpaqueResource<ConversationAttachment>>[
    for (final attachment in <ConversationAttachment>{
      ...result.attachments,
      ...result.contextImages,
    })
      PluginOpaqueResource<ConversationAttachment>(
        value: attachment,
        fileName: attachment.fileName,
        mimeType: attachment.mimeType,
        byteSize: attachment.byteSize,
      ),
  ];

  Map<String, Object?> _toolArgumentsMap(Object? input) => input is Map
      ? Map<String, Object?>.unmodifiable(_object(input))
      : Map<String, Object?>.unmodifiable(<String, Object?>{'input': input});

  Object? _normalizeToolInput(PluginToolRegistration tool, Object? input) =>
      _normalizeToolSchemaValue(tool.inputSchema, input);

  Object? _normalizeToolSchemaValue(
    Map<String, Object?> schema,
    Object? value,
  ) {
    final acceptsObject = _schemaHasType(schema, 'object');
    final acceptsArray = _schemaHasType(schema, 'array');
    if (acceptsObject && !acceptsArray) {
      // The Lua JSON bridge represents both empty objects and empty arrays as
      // an empty table. The selected tool schema is the authoritative shape,
      // including for nested values.
      if (value is List && value.isEmpty) return <String, Object?>{};
      if (value is Map) {
        final object = _object(value);
        final properties = _schemaObject(schema['properties']);
        final additional = _schemaObject(schema['additionalProperties']);
        return <String, Object?>{
          for (final entry in object.entries)
            entry.key: switch (_schemaObject(properties?[entry.key]) ??
                additional) {
              final propertySchema? => _normalizeToolSchemaValue(
                propertySchema,
                entry.value,
              ),
              null => entry.value,
            },
        };
      }
      return value;
    }
    if (acceptsArray && !acceptsObject && value is List<Object?>) {
      final items = _schemaObject(schema['items']);
      if (items == null) return value;
      return <Object?>[
        for (final item in value) _normalizeToolSchemaValue(items, item),
      ];
    }
    return value;
  }

  Map<String, Object?> _pluginToolResultValue(ToolResult result) =>
      <String, Object?>{
        'output': result.output,
        'is_error': result.isError,
        if (result.structuredContent != null)
          'structured_content': result.structuredContent,
        if (result.content.isNotEmpty)
          'content': result.content.map((value) => value.toJson()).toList(),
        if (result.meta.isNotEmpty) '_meta': result.meta,
        if (result.contextImages.isNotEmpty)
          'context_images': result.contextImages
              .map(_publicAttachmentJson)
              .toList(growable: false),
      };

  void _queueToolPresentation({
    required ({String pluginId, PluginToolRegistration tool}) selected,
    required String contributionId,
    required String callId,
    required Map<String, Object?> arguments,
    required ToolResult result,
  }) {
    final uiContribution = selected.tool.presentation['ui'];
    if (uiContribution is! String || uiContribution.isEmpty) return;
    if (_pendingUiPublications.any(
      (publication) =>
          publication.callId == callId &&
          publication.contributionId == uiContribution,
    )) {
      return;
    }
    final registration = registrations[selected.pluginId];
    final matches = registration?.ui.where(
      (candidate) =>
          candidate.id == uiContribution &&
          candidate.slot == PluginUiSlot.timeline,
    );
    if (registration == null || matches == null || matches.length != 1) {
      throw StateError(
        'Tool $contributionId references an unregistered timeline UI '
        'contribution: $uiContribution',
      );
    }
    _pendingUiPublications.add(
      _PendingUiPublication(
        operation: 'ui.timeline',
        pluginId: selected.pluginId,
        revisionHash: registration.revisionHash,
        contributionId: uiContribution,
        slot: PluginUiSlot.timeline,
        callId: callId,
        arguments: Map<String, Object?>.unmodifiable(<String, Object?>{
          'contribution_id': uiContribution,
          'snapshot': true,
          'value': <String, Object?>{
            'tool_id': contributionId,
            'tool_name': selected.tool.name,
            'label': selected.tool.presentation['label'],
            'arguments': arguments,
            'arguments_json': jsonEncode(arguments),
            'output': result.output,
            'is_error': result.isError,
            if (result.structuredContent != null)
              'structured_content': result.structuredContent,
            if (result.meta.isNotEmpty) 'meta': result.meta,
          },
        }),
      ),
    );
  }

  Future<PluginCallbackResult<ConversationAttachment>> _invokeHostPrimitive(
    PluginHostCallContext pluginContext,
    String operation,
    Map<String, Object?> arguments,
    PluginInvocationCancellation invocationCancellation, {
    _DynamicToolRecord? dynamicRecord,
  }) async {
    if (_primitives.descriptor(operation) != null) {
      return await _invokeRegisteredHostPrimitive(
        pluginContext,
        operation,
        arguments,
        invocationCancellation,
        dynamicRecord: dynamicRecord,
      );
    }
    return PluginCallbackResult<ConversationAttachment>(
      value: 'Unknown host primitive: $operation',
      isError: true,
    );
  }

  Future<PluginCallbackResult<ConversationAttachment>>
  _invokeRegisteredHostPrimitive(
    PluginHostCallContext pluginContext,
    String operation,
    Map<String, Object?> arguments,
    PluginInvocationCancellation invocationCancellation, {
    _DynamicToolRecord? dynamicRecord,
  }) async {
    final descriptor = _primitives.descriptor(operation)!;
    final approval = await _approveDirectHostPrimitive(
      pluginId: pluginContext.pluginId,
      name: operation,
      arguments: <String, dynamic>{...arguments},
      risk: switch (descriptor.effect) {
        HostPrimitiveEffect.read => AgentToolRisk.read,
        HostPrimitiveEffect.write => AgentToolRisk.write,
        HostPrimitiveEffect.command => AgentToolRisk.command,
        HostPrimitiveEffect.dangerous => AgentToolRisk.dangerous,
      },
    );
    if (approval != null) {
      return PluginCallbackResult<ConversationAttachment>(
        value: const HostPrimitiveResult<Object?>.failure(
          HostPrimitiveError(
            code: 'approval_denied',
            message: 'Host primitive invocation was denied.',
            retryable: false,
          ),
        ).toJson(),
      );
    }
    final allowed = Set<String>.of(pluginContext.effectiveCapabilities)
      ..retainAll(
        dynamicRecord?.declaredCapabilities ??
            pluginContext.handlerCapabilities,
      );
    final lifecycle = _lifecycleHostCapabilities;
    if (lifecycle != null) allowed.retainAll(lifecycle);
    final result = await _primitives.invoke(
      operation,
      arguments,
      HostPrimitiveContext(
        pluginId: pluginContext.pluginId,
        agentId: pluginContext.agentId,
        sessionId: pluginContext.sessionId,
        workspaceId: pluginContext.workspaceId,
        workspaceRoot: request.workspaceRoot,
        revisionHash: pluginContext.revisionHash,
        callId: _activeCalls[pluginContext.pluginId]?.callId,
        allowedCapabilities: allowed,
        cancellation: _HostPrimitiveCancellation(invocationCancellation),
      ),
    );
    for (final notification in result.notifications) {
      await callbacks.onEvent('host.notification', <String, dynamic>{
        'operation': operation,
        'value': notification,
      });
    }
    if (dynamicRecord != null) {
      final identity = _dynamicToolIdentity(
        pluginContext.pluginId,
        pluginContext.revisionHash,
        dynamicRecord.token,
      );
      final pending = _pendingDynamicToolCalls[identity];
      if (pending == null ||
          pending.contributionId != _dynamicToolIdsByIdentity[identity]) {
        throw const FormatException(
          'Dynamic host primitive has no active owning invocation.',
        );
      }
      for (final resource in result.resources) {
        final value = resource.value;
        if (value is ConversationAttachment) {
          _addToolResource(pending.resources, value);
        }
      }
    }
    return PluginCallbackResult<ConversationAttachment>(
      value: result.toJson(),
      resources: <PluginOpaqueResource<ConversationAttachment>>[
        for (final resource in result.resources)
          if (resource.value is ConversationAttachment)
            PluginOpaqueResource<ConversationAttachment>(
              value: resource.value as ConversationAttachment,
              fileName: resource.fileName,
              mimeType: resource.mimeType,
              byteSize: resource.byteSize,
            ),
      ],
    );
  }

  Future<PluginCallbackResult<ConversationAttachment>?>
  _approveDirectHostPrimitive({
    required String pluginId,
    required String name,
    required Map<String, dynamic> arguments,
    required AgentToolRisk risk,
  }) async {
    final active = _activeCalls[pluginId];
    if (active?.approvedRisks.contains(risk) ?? false) return null;
    final activeTool = active == null
        ? null
        : _selectedTools[active.contributionId];
    final invocation = ToolInvocation(
      callId: active?.callId ?? '${request.turnId}:host-$name',
      name: activeTool?.tool.name ?? name,
      arguments: active == null
          ? arguments
          : Map<String, dynamic>.from(active.arguments),
      risk: risk,
      workspaceRoot: request.workspaceRoot,
      preview:
          _primitives.approvalPreview(name, arguments) ??
          (activeTool?.tool.presentation['approval_preview'] is String
              ? activeTool!.tool.presentation['approval_preview']! as String
              : null),
    );
    final mode =
        await request.permissions?.currentMode() ??
        AgentPermissionMode.readOnly;
    final evaluation = (request.policyFactory ?? DefaultApprovalPolicy.new)(
      mode,
    ).evaluate(invocation);
    var approved = evaluation == ApprovalEvaluation.allow;
    if (evaluation == ApprovalEvaluation.ask && request.approvals != null) {
      approved =
          await _requestApproval(invocation) == ApprovalDecision.approved;
    }
    if (evaluation == ApprovalEvaluation.deny || !approved) {
      if (active != null) _deniedToolCallIds.add(active.callId);
      return const PluginCallbackResult<ConversationAttachment>(
        value: 'Host operation was denied.',
        isError: true,
      );
    }
    active?.approvedRisks.add(risk);
    return null;
  }

  Future<ApprovalDecision> _requestApproval(ToolInvocation invocation) {
    final result = Completer<ApprovalDecision>();
    _approvalQueue = _approvalQueue.then((_) async {
      try {
        cancellation.throwIfCancelled();
        await callbacks.onStatus(AgentSessionStatus.waitingForApproval);
        result.complete(
          await request.approvals!.request(invocation, cancellation),
        );
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      } finally {
        await callbacks.onStatus(AgentSessionStatus.running);
      }
    });
    return result.future;
  }

  ({String pluginId, PluginToolRegistration tool})? _selectedToolByModelName(
    String name,
  ) {
    final matches = _selectedTools.values.where(
      (selected) => selected.tool.name == name,
    );
    return matches.length == 1 ? matches.single : null;
  }
}

HostPrimitiveRegistry _turnPrimitiveRegistry(LuaAgentHarnessRequest request) {
  final turnBindings = <HostPrimitive<Object?, Object?>>[];
  final network = request.network;
  if (network != null) {
    turnBindings.add(
      HostPrimitiveContracts.networkRequest
          .bind(
            decode: _object,
            invoke: (arguments, context) =>
                _sendNetworkRequest(network, arguments, context),
            approvalPreview: _networkApprovalPreview,
          )
          .erased,
    );
  }
  final secrets = request.secrets;
  if (secrets != null) {
    turnBindings.add(
      HostPrimitiveContracts.secretGet
          .bind(
            decode: _object,
            invoke: (arguments, context) =>
                _readPluginSecret(secrets, arguments, context),
            approvalPreview: _secretApprovalPreview,
          )
          .erased,
    );
  }
  if (turnBindings.isEmpty) return request.primitives;
  return request.primitives.withPrimitives(turnBindings);
}

String? _networkApprovalPreview(Map<String, Object?> arguments) {
  try {
    final request = _networkRequest(arguments);
    return '${request.method} ${request.uri}';
  } on FormatException {
    return null;
  }
}

String? _secretApprovalPreview(Map<String, Object?> arguments) {
  try {
    return 'Read secret ${_secretName(arguments['name'])}';
  } on FormatException {
    return null;
  }
}

Future<Map<String, Object?>> _sendNetworkRequest(
  PluginNetworkGateway gateway,
  Map<String, Object?> arguments,
  HostPrimitiveContext context,
) async {
  final request = _networkRequest(arguments);
  final PluginNetworkResponse response;
  try {
    response = await gateway.send(
      request,
      _NetworkOperationCancellation(context.cancellation),
    );
  } on PluginHostOperationCancelledException {
    throw const AgentCancelledException();
  } on PluginNetworkTransportException catch (error) {
    throw HostPrimitiveException(
      HostPrimitiveError(
        code: 'network_transport_error',
        message: 'Plugin network request failed: ${error.kind}',
        retryable: _retryableNetworkFailure(error.kind),
        details: <String, Object?>{'kind': error.kind},
      ),
    );
  } on FormatException catch (error) {
    throw HostPrimitiveException(
      HostPrimitiveError(
        code: 'invalid_network_response',
        message: error.message,
        retryable: false,
      ),
    );
  }
  if (context.cancellation?.isCancelled ?? false) {
    throw const AgentCancelledException();
  }
  try {
    _validateNetworkResponse(response, request.maximumResponseBytes);
  } on FormatException catch (error) {
    throw HostPrimitiveException(
      HostPrimitiveError(
        code: 'invalid_network_response',
        message: error.message,
        retryable: false,
      ),
    );
  }
  String? textBody;
  try {
    textBody = utf8.decode(response.body, allowMalformed: false);
  } on FormatException {
    // Binary bodies remain available through body_base64.
  }
  return <String, Object?>{
    'status': response.statusCode,
    'headers': response.headers,
    'body_base64': base64Encode(response.body),
    'body': ?textBody,
  };
}

bool _retryableNetworkFailure(String kind) => const <String>{
  'connectionError',
  'connectionTimeout',
  'deadline',
  'receiveTimeout',
  'sendTimeout',
  'unknown',
}.contains(kind);

Future<Map<String, Object?>> _readPluginSecret(
  PluginSecretStore secrets,
  Map<String, Object?> arguments,
  HostPrimitiveContext context,
) async {
  final name = _secretName(arguments['name']);
  final value = await secrets.read(
    PluginSecretScope(agentId: context.agentId, pluginId: context.pluginId),
    name,
  );
  if (context.cancellation?.isCancelled ?? false) {
    throw const AgentCancelledException();
  }
  if (value == null) return <String, Object?>{'found': false};
  if (utf8.encode(value).length > PluginSecretLimits.maximumValueBytes) {
    throw const HostPrimitiveException(
      HostPrimitiveError(
        code: 'secret_value_too_large',
        message: 'Plugin secret exceeds the host limit.',
        retryable: false,
      ),
    );
  }
  return <String, Object?>{'found': true, 'value': value};
}

final class _PluginCancellation implements PluginCancellationSignal {
  const new(this.token);

  final CancellationToken token;

  @override
  void onCancel(void Function() callback) => token.onCancel(callback);
}

final class _HostPrimitiveCancellation implements HostPrimitiveCancellation {
  const new(this.source);

  final PluginInvocationCancellation source;

  @override
  bool get isCancelled => source.isCancelled;

  @override
  void onCancel(void Function() callback) => source.onCancel(callback);
}

final class _NetworkOperationCancellation
    implements PluginOperationCancellation {
  const new(this.source);

  final HostPrimitiveCancellation? source;

  @override
  bool get isCancelled => source?.isCancelled ?? false;

  @override
  void onCancel(void Function() callback) => source?.onCancel(callback);
}

final class _ActiveToolCall {
  new({
    required this.callId,
    required this.contributionId,
    required this.arguments,
  });

  final String callId;
  final String contributionId;
  final Map<String, Object?> arguments;
  final Set<AgentToolRisk> approvedRisks = <AgentToolRisk>{};
}

final class _PendingDynamicToolCall {
  const new({
    required this.identity,
    required this.pluginId,
    required this.revisionHash,
    required this.contributionId,
    required this.token,
    required this.callId,
    required this.input,
    required this.resources,
  });

  final String identity;
  final String pluginId;
  final String revisionHash;
  final String contributionId;
  final String token;
  final String callId;
  final Object? input;
  final List<ConversationAttachment> resources;
}

typedef _MaterializedDynamicTool = ({
  ({String pluginId, PluginToolRegistration tool}) selected,
  _DynamicToolRecord record,
});

String _dynamicToolIdentity(
  String pluginId,
  String revisionHash,
  String token,
) => '$pluginId\u0000$revisionHash\u0000$token';

final class _DynamicToolRecord {
  const new({
    required this.token,
    required this.privateRefId,
    required this.ephemeral,
    required this.callerPluginId,
    required this.callerRevisionHash,
    required this.templateId,
    required this.templateExecutionRevision,
    required this.payload,
    required this.declaredCapabilities,
    required this.declaredOperations,
  });

  final String token;
  final int privateRefId;
  final bool ephemeral;
  final String callerPluginId;
  final String callerRevisionHash;
  final String? templateId;
  final String? templateExecutionRevision;
  final Object? payload;
  final Set<String> declaredCapabilities;
  final Set<String> declaredOperations;

  Map<String, Object?> toJson() => <String, Object?>{
    'token': token,
    'private_ref_id': privateRefId,
    'plugin_id': callerPluginId,
    'execution_revision': callerRevisionHash,
    if (templateId != null) 'template_id': templateId,
    if (templateExecutionRevision != null)
      'template_execution_revision': templateExecutionRevision,
    'payload': payload,
  };
}

final class _PendingUiPublication {
  const new({
    required this.operation,
    required this.pluginId,
    required this.revisionHash,
    required this.contributionId,
    required this.slot,
    required this.callId,
    required this.arguments,
  });

  final String operation;
  final String pluginId;
  final String revisionHash;
  final String contributionId;
  final PluginUiSlot slot;
  final String? callId;
  final Map<String, Object?> arguments;
}

List<String> _referencedPluginIds(AgentDefinitionDto definition) => <String>{
  _pluginId(definition.driverId),
  ...definition.extensionIds.map(_pluginId),
  ...definition.toolIds.map(_pluginId),
}.toList(growable: false);

String _pluginId(String contributionId) {
  final separator = contributionId.indexOf('/');
  return separator < 0
      ? contributionId
      : contributionId.substring(0, separator);
}

void _validateDriverCapabilities(
  PluginDriverRegistration driver,
  AgentModelCapabilities capabilities,
) {
  for (final requirement in driver.requiredModelCapabilities) {
    final supported = switch (requirement) {
      'streaming' => capabilities.streaming,
      'tool_calling' => capabilities.toolCalling,
      'function_tools' => capabilities.functionTools,
      'deferred_tools' => capabilities.deferredTools,
      'image_input' => capabilities.imageInput,
      'file_input' => capabilities.fileInput,
      _ => AgentCapabilitySupport.unknown,
    };
    if (supported != AgentCapabilitySupport.supported) {
      throw StateError(
        'Model does not satisfy driver capability: $requirement',
      );
    }
  }
}

String? _selectedToolCompatibilityError(
  List<ModelToolDefinition> tools,
  AgentModelCapabilities capabilities,
) {
  if (tools.isEmpty) return null;
  if (capabilities.toolCalling != AgentCapabilitySupport.supported) {
    return 'Model does not support tool calling for the selected surface.';
  }
  for (final tool in tools) {
    final support = switch (tool) {
      ModelFunctionToolDefinition() ||
      ModelNamespaceToolDefinition() => capabilities.functionTools,
      ModelDeferredSearchToolDefinition() => capabilities.deferredTools,
    };
    if (support != AgentCapabilitySupport.supported) {
      return 'Model does not support selected ${tool.kind.name} tool: '
          '${tool.name}';
    }
  }
  return null;
}

Map<String, Object?> _modelCapabilitiesJson(
  AgentModelCapabilities capabilities,
) => <String, Object?>{
  'streaming': capabilities.streaming.name,
  'tool_calling': capabilities.toolCalling.name,
  'function_tools': capabilities.functionTools.name,
  'deferred_tools': capabilities.deferredTools.name,
  'image_input': capabilities.imageInput.name,
  'file_input': capabilities.fileInput.name,
};

Map<String, Object?> _toolDescriptor(
  ({String pluginId, PluginToolRegistration tool}) selected,
) => <String, Object?>{
  'id': selected.tool.id,
  'name': selected.tool.name,
  'description': selected.tool.description,
  'kind': selected.tool.kind,
  'input_schema': selected.tool.inputSchema,
  if (selected.tool.outputSchema != null)
    'output_schema': selected.tool.outputSchema,
  'exposure': _isDeferredTool(selected) ? 'deferred' : 'advertised',
  'presentation': selected.tool.presentation,
};

Map<String, Object?> _surfaceToolDescriptor(
  ({String pluginId, PluginToolRegistration tool}) selected,
) => <String, Object?>{
  'type': 'function',
  'canonical_name': selected.tool.id,
  'name': selected.tool.name,
  'description': selected.tool.description,
  'parameters': selected.tool.inputSchema,
  'strict': true,
  if (selected.tool.outputSchema != null)
    'output_schema': selected.tool.outputSchema,
};

bool _isDynamicTemplate(
  ({String pluginId, PluginToolRegistration tool}) selected,
) =>
    selected.tool.presentation['dynamic'] == true &&
    selected.tool.presentation['dynamicContributionId'] == null;

bool _isDeferredTool(
  ({String pluginId, PluginToolRegistration tool})? selected,
) => selected?.tool.presentation['exposure'] == 'deferred';

ModelToolKind _modelToolKind(PluginToolRegistration tool) =>
    tool.kind == 'deferred' && tool.presentation['dynamic'] != true
    ? ModelToolKind.deferredSearch
    : ModelToolKind.function;

ModelToolDefinition _modelTool(Object? raw) {
  final value = _dynamicObject(raw);
  final name = value['name']?.toString() ?? '';
  final description = value['description']?.toString() ?? name;
  return switch (value['kind']) {
    'deferred' => ModelDeferredSearchToolDefinition(
      name: name,
      description: description,
      parameters: _dynamicObject(value['input_schema']),
    ),
    _ => ModelFunctionToolDefinition(
      name: name,
      description: description,
      parameters: _dynamicObject(value['input_schema']),
      outputSchema: value['output_schema'] == null
          ? null
          : _dynamicObject(value['output_schema']),
    ),
  };
}

const _toolValueMarker = '__tinest_tool_value';

ToolResult _toolResult(Object? value) {
  if (value is! Map) return ToolResult(value: value);
  final object = _dynamicObject(value);
  final output = object['output'] ?? object['value'] ?? value;
  return ToolResult(
    value: output,
    isError: object['is_error'] == true,
    structuredContent: object['structured_content'],
    meta: object['_meta'] is Map
        ? _dynamicObject(object['_meta'])
        : const <String, dynamic>{},
  );
}

Map<String, Object?> _object(Object? value) => value is Map
    ? <String, Object?>{
        for (final entry in value.entries) entry.key.toString(): entry.value,
      }
    : <String, Object?>{};

bool _schemaHasType(Map<String, Object?> schema, String expected) =>
    switch (schema['type']) {
      final String value => value == expected,
      final List<Object?> values => values.contains(expected),
      _ => false,
    };

Map<String, Object?>? _schemaObject(Object? value) => switch (value) {
  final Map<Object?, Object?> map when map.keys.every((key) => key is String) =>
    <String, Object?>{
      for (final entry in map.entries) entry.key! as String: entry.value,
    },
  _ => null,
};

Map<String, Map<String, Object?>> _pinPluginSettings(
  Map<String, Map<String, dynamic>> settings,
) => Map<String, Map<String, Object?>>.unmodifiable(
  <String, Map<String, Object?>>{
    for (final entry in settings.entries)
      entry.key: _pinJsonObject(entry.value),
  },
);

Map<String, Object?> _pinJsonObject(Map<Object?, Object?> value) {
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      throw const FormatException(
        'Plugin setting object keys must be strings.',
      );
    }
    result[key] = _pinJson(entry.value);
  }
  return Map<String, Object?>.unmodifiable(result);
}

Object? _pinJson(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is List<Object?>) {
    return List<Object?>.unmodifiable(value.map(_pinJson));
  }
  if (value is Map<Object?, Object?>) {
    return _pinJsonObject(value);
  }
  throw FormatException(
    'Plugin settings must contain only JSON-compatible values, got '
    '${value.runtimeType}.',
  );
}

Map<String, dynamic> _dynamicObject(Object? value) =>
    Map<String, dynamic>.from(_object(value));

Map<String, dynamic> _pluginConversationItemJson(ConversationItem item) =>
    item is UserConversationItem
    ? <String, dynamic>{
        'type': 'user',
        'text': item.text,
        if (item.attachments.isNotEmpty)
          'attachments': item.attachments
              .map(_publicAttachmentJson)
              .toList(growable: false),
      }
    : item.toJson();

Map<String, dynamic> _publicAttachmentJson(ConversationAttachment attachment) =>
    <String, dynamic>{
      'id': attachment.id,
      'fileName': attachment.fileName,
      'mimeType': attachment.mimeType,
      'byteSize': attachment.byteSize,
      if (attachment.kind != null) 'kind': attachment.kind!.name,
      if (attachment.sha256 != null) 'sha256': attachment.sha256,
      if (attachment.createdAt != null)
        'createdAt': attachment.createdAt!.toIso8601String(),
      if (attachment.imageDetail != null) 'imageDetail': attachment.imageDetail,
    };

Map<String, dynamic> _normalizeDriverHistoryItem(Object? value) {
  final item = _dynamicObject(value);
  if (item['type'] != 'assistant') return item;
  final calls = item['toolCalls'];
  if (calls is! List) return item;
  item['toolCalls'] = <Map<String, dynamic>>[
    for (final rawCall in calls)
      if (rawCall is Map)
        (() {
          final call = _dynamicObject(rawCall);
          // An argument-less call is an empty Lua table, which the bridge
          // cannot tell apart from an empty array on the way back.
          final arguments = call['arguments'];
          call['arguments'] = arguments is List && arguments.isEmpty
              ? <String, dynamic>{}
              : arguments;
          return call;
        })(),
  ];
  return item;
}

List<Object?> _list(Object? value) =>
    value is List ? List<Object?>.from(value) : const <Object?>[];

List<ModelRoleBlock> _modelRoleBlocks(Object? value) {
  if (value is! List) {
    throw const FormatException('model.open blocks must be an array.');
  }
  return <ModelRoleBlock>[
    for (final raw in value)
      (() {
        final block = _object(raw);
        final name = _requiredString(block, 'role');
        final role = ModelRole.values.where((value) => value.name == name);
        if (role.isEmpty) {
          throw FormatException(
            'model.open block role "$name" is not one of '
            '${ModelRole.values.map((value) => value.name).join(', ')}.',
          );
        }
        final content = block['content'];
        if (content is! String) {
          throw const FormatException(
            'model.open block content must be a string.',
          );
        }
        return ModelRoleBlock(role: role.first, content: content);
      })(),
  ];
}

int? _integer(Object? value) => value is num ? value.toInt() : null;

PluginNetworkRequest _networkRequest(Map<String, Object?> arguments) {
  final url = _requiredString(arguments, 'url');
  if (utf8.encode(url).length > PluginNetworkLimits.maximumUrlBytes) {
    throw const FormatException('Plugin network URL exceeds the host limit.');
  }
  final uri = Uri.tryParse(url);
  if (uri == null ||
      !uri.hasScheme ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.userInfo.isNotEmpty) {
    throw const FormatException(
      'Plugin network URL must be an absolute HTTP(S) URL without credentials.',
    );
  }
  final method = (arguments['method']?.toString() ?? 'GET').toUpperCase();
  if (!const <String>{
    'GET',
    'POST',
    'PUT',
    'PATCH',
    'DELETE',
    'HEAD',
    'OPTIONS',
  }.contains(method)) {
    throw FormatException('Unsupported plugin network method: $method');
  }
  final rawHeaders = arguments['headers'];
  if (rawHeaders != null && rawHeaders is! Map) {
    throw const FormatException('Plugin network headers must be an object.');
  }
  final headers = <String, String>{};
  if (rawHeaders case final Map<Object?, Object?> values) {
    if (values.length > PluginNetworkLimits.maximumHeaderCount) {
      throw const FormatException(
        'Plugin network request has too many headers.',
      );
    }
    for (final entry in values.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException(
          'Plugin network header names and values must be strings.',
        );
      }
      final name = (entry.key! as String).toLowerCase();
      final value = entry.value! as String;
      if (!_httpHeaderName.hasMatch(name) ||
          value.contains('\r') ||
          value.contains('\n')) {
        throw const FormatException('Invalid plugin network header.');
      }
      headers[name] = value;
    }
  }
  _validateHeaderBytes(
    headers.map((key, value) => MapEntry(key, <String>[value])),
  );

  final rawBody = arguments['body'];
  final rawBase64 = arguments['body_base64'];
  if (rawBody != null && rawBase64 != null) {
    throw const FormatException(
      'Plugin network request accepts body or body_base64, not both.',
    );
  }
  final List<int> body;
  if (rawBase64 != null) {
    if (rawBase64 is! String) {
      throw const FormatException('body_base64 must be a string.');
    }
    try {
      body = base64Decode(rawBase64);
    } on FormatException {
      throw const FormatException('body_base64 is not valid base64.');
    }
  } else if (rawBody != null) {
    if (rawBody is! String) {
      throw const FormatException('Plugin network body must be a string.');
    }
    body = utf8.encode(rawBody);
  } else {
    body = const <int>[];
  }
  if (body.length > PluginNetworkLimits.maximumRequestBodyBytes) {
    throw const FormatException(
      'Plugin network request body exceeds the host limit.',
    );
  }
  final timeoutMilliseconds =
      _integer(arguments['timeout_ms']) ??
      PluginNetworkLimits.defaultTimeout.inMilliseconds;
  if (timeoutMilliseconds <= 0 ||
      timeoutMilliseconds > PluginNetworkLimits.maximumTimeout.inMilliseconds) {
    throw const FormatException(
      'Plugin network timeout exceeds the host limit.',
    );
  }
  final maximumResponseBytes =
      _integer(arguments['max_response_bytes']) ??
      PluginNetworkLimits.maximumResponseBodyBytes;
  if (maximumResponseBytes <= 0 ||
      maximumResponseBytes > PluginNetworkLimits.maximumResponseBodyBytes) {
    throw const FormatException(
      'Plugin network response limit exceeds the host maximum.',
    );
  }
  return PluginNetworkRequest(
    uri: uri,
    method: method,
    headers: headers,
    body: body,
    timeout: Duration(milliseconds: timeoutMilliseconds),
    maximumResponseBytes: maximumResponseBytes,
  );
}

void _validateNetworkResponse(
  PluginNetworkResponse response,
  int maximumResponseBytes,
) {
  if (response.statusCode < 100 || response.statusCode > 999) {
    throw const FormatException('Invalid plugin network response status.');
  }
  if (response.headers.length > PluginNetworkLimits.maximumHeaderCount) {
    throw const FormatException(
      'Plugin network response has too many headers.',
    );
  }
  _validateHeaderBytes(response.headers);
  if (response.body.length > maximumResponseBytes) {
    throw const FormatException(
      'Plugin network response body exceeds the selected limit.',
    );
  }
}

void _validateHeaderBytes(Map<String, List<String>> headers) {
  var bytes = 0;
  for (final entry in headers.entries) {
    final unsafeValue = entry.value.any(
      (value) => value.contains('\r') || value.contains('\n'),
    );
    if (!_httpHeaderName.hasMatch(entry.key) || unsafeValue) {
      throw const FormatException('Invalid plugin network header.');
    }
    bytes += utf8.encode(entry.key).length;
    for (final value in entry.value) {
      bytes += utf8.encode(value).length;
    }
    if (bytes > PluginNetworkLimits.maximumHeaderBytes) {
      throw const FormatException(
        'Plugin network headers exceed the host limit.',
      );
    }
  }
}

String _secretName(Object? value) {
  if (value is! String ||
      !_pluginSecretName.hasMatch(value) ||
      utf8.encode(value).length > PluginSecretLimits.maximumNameBytes) {
    throw const FormatException('Invalid plugin secret name.');
  }
  return value;
}

final RegExp _httpHeaderName = RegExp(r"^[!#$%&'*+.^_`|~0-9a-z-]+$");
final RegExp _pluginSecretName = RegExp(r'^[A-Za-z][A-Za-z0-9_.-]{0,127}$');

String _requiredString(Map<String, Object?> value, String key) {
  final result = value[key];
  if (result is! String || result.isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return result;
}

Map<String, Object?> _requiredSchema(Map<String, Object?> value, String key) {
  final schema = value[key];
  if (schema is List<Object?> && schema.isEmpty) {
    return const <String, Object?>{};
  }
  if (schema is! Map<Object?, Object?> ||
      !schema.keys.every((item) => item is String)) {
    throw FormatException('$key must be a JSON schema object.');
  }
  final normalized = normalizePluginJson(schema, path: r'$.dynamic.schema');
  return Map<String, Object?>.unmodifiable(normalized! as Map<String, Object?>);
}

Set<String> _stringSet(Object? value, String label) {
  if (value == null) return const <String>{};
  if (value is! List<Object?>) {
    throw FormatException('$label must be an array.');
  }
  final result = <String>{};
  for (final item in value) {
    if (item is! String || item.isEmpty || !result.add(item)) {
      throw FormatException('$label entries must be unique strings.');
    }
  }
  return Set<String>.unmodifiable(result);
}

Map<String, Object?> _resolveDynamicPresentation(
  Map<String, Object?> value,
  String pluginId,
) => <String, Object?>{
  for (final entry in value.entries)
    entry.key: _resolveDynamicPresentationValue(entry.value, pluginId),
};

Object? _resolveDynamicPresentationValue(Object? value, String pluginId) {
  if (value is List<Object?>) {
    return <Object?>[
      for (final item in value)
        _resolveDynamicPresentationValue(item, pluginId),
    ];
  }
  if (value is Map<Object?, Object?>) {
    final object = _object(value);
    final kind = object['__tinest_ref'];
    final id = object['id'];
    if (kind != null || id != null) {
      if ((kind != 'ui' && kind != 'action') ||
          id is! String ||
          !RegExp(r'^[a-z][a-z0-9_-]*$').hasMatch(id) ||
          object.length != 2) {
        throw const FormatException(
          'Dynamic presentation contains an invalid Tinest reference.',
        );
      }
      return '$pluginId/$id';
    }
    return _resolveDynamicPresentation(object, pluginId);
  }
  return value;
}

PluginStateScope _stateScope(
  PluginHostCallContext context,
  Map<String, Object?> arguments,
) => switch (arguments['scope']) {
  'plugin' => PluginStateScope.plugin(pluginId: context.pluginId),
  'agent' => PluginStateScope.agent(
    pluginId: context.pluginId,
    agentId: context.agentId,
  ),
  'session' => PluginStateScope.session(
    pluginId: context.pluginId,
    sessionId: context.sessionId,
  ),
  'workspace' when context.workspaceId != null => PluginStateScope.workspace(
    pluginId: context.pluginId,
    workspaceId: context.workspaceId!,
  ),
  'workspace' => throw const FormatException(
    'Workspace-scoped state requires a workspace.',
  ),
  _ => throw const FormatException('Unknown plugin state scope.'),
};

Map<String, Object?> _stateEntry(PluginStateEntry entry) => <String, Object?>{
  'revision': entry.revision,
  'value': entry.value,
};

PluginCallbackResult<ConversationAttachment> _unavailable(String feature) =>
    PluginCallbackResult<ConversationAttachment>(
      value: '$feature is unavailable.',
      isError: true,
    );
