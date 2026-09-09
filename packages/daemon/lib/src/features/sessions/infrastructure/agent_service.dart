import 'dart:async';

import 'package:agent/agent.dart';
import 'package:daemon/src/features/agents/infrastructure/agent_definitions.dart';
import 'package:daemon/src/features/attachments/infrastructure/attachment_service.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_ports.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_service.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_session_control_service.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_ui_service.dart';
import 'package:daemon/src/features/plugins/runtime/built_in_host_primitives.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_agent_harness.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_execution_lifecycle.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_runtime.dart';
import 'package:daemon/src/features/prompts/infrastructure/skills.dart';
import 'package:daemon/src/features/providers/infrastructure/provider_service.dart';
import 'package:daemon/src/features/sessions/infrastructure/agent_clock.dart';
import 'package:daemon/src/features/sessions/infrastructure/lua_code_mode_service.dart';
import 'package:daemon/src/features/sessions/infrastructure/model_usage_cost.dart';
import 'package:daemon/src/features/sessions/infrastructure/multi_agent.dart';
import 'package:daemon/src/features/sessions/infrastructure/session_interactions.dart';
import 'package:daemon/src/shared/infrastructure/persistence/repositories.dart';
import 'package:daemon/src/shared/ports/agent_protocol_mapping.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:daemon/src/shared/ports/mcp_host_primitives.dart';
import 'package:daemon/src/transport/rpc/binding.dart';
import 'package:protocol/protocol.dart';

/// Signature used by DaemonEventSink.
typedef DaemonEventSink = void Function(OutboundNotification event);

/// Resolves the pseudo-terminals one tinest session owns.
typedef ExecHostFactory = ExecSessionHost Function(String sessionId);

/// Resolves the raw MCP transport scoped to one worktree.
typedef McpHostFactory = McpHostPrimitiveGateway Function(String workspaceRoot);

String _pluginId(String contributionId) {
  final separator = contributionId.indexOf('/');
  return separator < 0
      ? contributionId
      : contributionId.substring(0, separator);
}

/// Coordinates model-turn execution and lifecycle for tinest sessions.
class SessionTurnCoordinator implements SessionTurnPort {
  /// Creates a session turn coordinator.
  new({
    required this._sessions,
    required this._definitions,
    required this._worktrees,
    required this._timeline,
    required this._models,
    required this._events,
    required this._clock,
    required this._ids,
    required this._hostPrimitiveRegistryFactory,
    required this._skills,
    required this._attachments,
    required this._execHostFor,
    required this._interactions,
    required this._plugins,
    required this._pluginSessionControls,
    required this._pluginUi,
    required this._pluginRuntime,
    required this._pluginState,
    required this._pluginJobs,
    required this._luaCodeMode,
    this._mcpFor,
    this._pluginNetwork,
    this._pluginSecrets,
    PluginExecutionLifecycleRegistry<ConversationAttachment>? pluginLifecycle,
    ProjectDocLoader? projectDocs,
  }) : _projectDocs = projectDocs ?? ProjectDocLoader(),
       _pluginLifecycle =
           pluginLifecycle ??
           PluginExecutionLifecycleRegistry<ConversationAttachment>(
             runtime: _pluginRuntime,
             state: _pluginState,
           );

  final ProjectDocLoader _projectDocs;
  final ExecHostFactory _execHostFor;
  final SessionRepository _sessions;
  final AgentDefinitionService _definitions;
  final WorktreeRepository _worktrees;
  final TimelineRepository _timeline;
  final ProviderModelResolver _models;
  final DaemonEventSink _events;
  final Clock _clock;
  final IdGenerator _ids;
  final HostPrimitiveRegistryFactory _hostPrimitiveRegistryFactory;
  final SkillCatalogService _skills;
  final AttachmentService _attachments;
  final SessionInteractionCoordinator _interactions;
  final PluginManagementService _plugins;
  final PluginSessionControlService<ConversationAttachment>
  _pluginSessionControls;
  final PluginUiService _pluginUi;
  final PluginRuntime<ConversationAttachment> _pluginRuntime;
  final PluginStateStore _pluginState;
  final PluginJobStore _pluginJobs;
  final LuaCodeModeService _luaCodeMode;
  final McpHostFactory? _mcpFor;
  final PluginNetworkGateway? _pluginNetwork;
  final PluginSecretStore? _pluginSecrets;
  final PluginExecutionLifecycleRegistry<ConversationAttachment>
  _pluginLifecycle;
  final Map<String, CancellationToken> _activeTurns =
      <String, CancellationToken>{};
  final Map<String, Completer<AgentRunResult>> _turnCompletions =
      <String, Completer<AgentRunResult>>{};
  final Set<String> _startingTurns = <String>{};
  final Set<Future<void>> _runningTurns = <Future<void>>{};
  Completer<void>? _startsDrained;
  Future<void>? _closeFuture;
  bool _closing = false;

  /// The collaboration layer, bound once from the composition root.
  MultiAgentService? multiAgent;

  @override
  bool hasActiveTurn(String sessionId) => _activeTurns.containsKey(sessionId);

  /// The startTurn public API member.
  @override
  Future<bool> startTurn({
    required String sessionId,
    required String turnId,
    required String prompt,
    List<String> attachmentIds = const <String>[],
    bool trackCompletion = false,
    bool internal = false,
  }) async {
    if (_closing) throw StateError('Turn coordinator is closing.');
    if (!_startingTurns.add(sessionId)) {
      throw StateError('Agent already has a turn starting.');
    }
    try {
      final session = await _sessions.getById(sessionId);
      if (session == null) throw StateError('Session not found: $sessionId');
      final definition = await _definitions.resolve(session.agentDefinitionId);
      final sessionModel = session.model;
      // A session override wins over the model of its agent definition.
      final resolvedModel = sessionModel == null
          ? await _models.resolveAgentModel(definition.model)
          : await _models.resolveQualifiedModel(sessionModel.qualifiedModelId);
      final controls = sessionModel != null
          ? session.modelControls
          : const <String, ModelControlValueDto>{};
      await _models.validateModelControls(
        resolvedModel.connectionId,
        resolvedModel.modelId,
        controls,
      );
      if (_activeTurns.containsKey(sessionId)) {
        throw StateError('Agent already has a running turn.');
      }
      final worktree = await _worktrees.getById(session.worktreeId);
      if (worktree == null || worktree.archivedAt != null) {
        throw StateError('Worktree not found: ${session.worktreeId}');
      }
      // Subagent turns hold a per-tree concurrency slot from here on; the slot
      // is released by `onTurnFinished` once the launched run terminates, or in
      // the `finally` below when the turn never launches.
      multiAgent?.acquireTurnSlot(session);
      var launched = false;
      try {
        return await _startAcquiredTurn(
          session: session,
          definition: definition,
          resolvedModel: resolvedModel,
          modelControls: controls,
          worktree: worktree,
          sessionId: sessionId,
          turnId: turnId,
          prompt: prompt,
          attachmentIds: attachmentIds,
          trackCompletion: trackCompletion,
          internal: internal,
          onLaunched: () => launched = true,
        );
      } finally {
        if (!launched) multiAgent?.releaseTurnSlot(session);
      }
    } finally {
      _startingTurns.remove(sessionId);
      if (_closing && _startingTurns.isEmpty) {
        _startsDrained?.complete();
        _startsDrained = null;
      }
    }
  }

  Future<bool> _startAcquiredTurn({
    required SessionDto session,
    required AgentDefinitionDto definition,
    required ResolvedAgentModel resolvedModel,
    required Map<String, ModelControlValueDto> modelControls,
    required WorktreeDto worktree,
    required String sessionId,
    required String turnId,
    required String prompt,
    required List<String> attachmentIds,
    required bool trackCompletion,
    required bool internal,
    required void Function() onLaunched,
  }) async {
    final created = await _sessions.createTurn(
      id: turnId,
      sessionId: sessionId,
      prompt: prompt,
      attachmentIds: attachmentIds,
    );
    if (!created) return false;

    final cancellation = CancellationToken();
    // Starting a turn consumes whatever the client had queued, so a stale
    // notice cannot shorten a later wait.
    _interactions.beginTurn(sessionId);
    _activeTurns[sessionId] = cancellation;
    if (trackCompletion) {
      _turnCompletions[turnId] = Completer<AgentRunResult>();
    }
    try {
      await _sessions.updateStatus(
        sessionId,
        SessionStatus.running,
        activeTurnId: turnId,
      );
      await multiAgent?.onTurnStarted(session);
      // Cached on the row so the context meter reads the same window the turn
      // runs against, without a catalog lookup on every session read.
      _emitSession(
        await _sessions.recordContextWindow(
          sessionId,
          resolvedModel.limits?.context,
        ),
      );

      Future<void> reportStatus(SessionStatus status, {String? error}) async {
        final turnStatus = switch (status) {
          SessionStatus.waitingForApproval => TurnStatus.waitingForApproval,
          SessionStatus.waitingForInput => TurnStatus.waitingForInput,
          SessionStatus.running => TurnStatus.running,
          _ => null,
        };
        if (turnStatus != null) {
          await _sessions.updateTurn(turnId, turnStatus);
        }
        final terminal =
            status == SessionStatus.idle || status == SessionStatus.failed;
        final updated = await _sessions.updateStatus(
          sessionId,
          status,
          activeTurnId: terminal ? null : turnId,
          error: error,
        );
        // A client that queues follow-ups starts the next turn the moment it
        // sees the idle session, so the slot has to be free before the event
        // goes out. The `finally` below stays as the cancellation backstop.
        if (terminal && identical(_activeTurns[sessionId], cancellation)) {
          _activeTurns.remove(sessionId);
        }
        _emitSession(updated);
      }

      final agentClock = SessionAgentClock(
        clock: _clock,
        sessionId: sessionId,
        pendingInput: _interactions.pendingInput,
      );
      // Skills resolve against the worktree, so a branch carries the project
      // skills that were committed to it.
      final skills = await _skills.viewFor(worktree.path);
      final attachmentPublisher = TurnAttachmentPublisher(_attachments, turnId);
      final attachmentReader = SessionAttachmentReader(_attachments, sessionId);
      final questions = _interactions.questionsFor(
        sessionId: sessionId,
        turnId: turnId,
        reportStatus: reportStatus,
      );
      final execHost = _execHostFor(sessionId);
      final isRootAgent = session.parentSessionId == null;
      final allowedCapabilities = await _preparePlugins(definition);
      await _pluginLifecycle.enter(
        PluginExecutionLifecycleRequest(
          definition: definition,
          sessionId: sessionId,
          workspaceId: worktree.workspaceId,
          workingDirectory: worktree.path,
          allowedCapabilitiesByPlugin: allowedCapabilities,
        ),
      );
      final sessionControlValues = await _pluginSessionControls.valuesForTurn(
        session: session,
        definition: definition,
        worktree: worktree,
      );
      final referencedPlugins = allowedCapabilities.keys.toSet();
      final revocations = _plugins.grants.revocations.listen((grant) {
        if (grant.agentId == definition.id &&
            referencedPlugins.contains(grant.pluginId)) {
          cancellation.cancel();
        }
      });
      final harness = LuaAgentHarness(runtime: _pluginRuntime);
      final callbacks = LuaAgentHarnessCallbacks(
        onEvent: (type, data) async {
          await _appendEvent(
            sessionId: sessionId,
            turnId: turnId,
            type: type,
            data: data,
          );
          // The context meter rides the session stream, so every reported usage
          // updates the row the clients already watch.
          if (type == 'model.usage') {
            final usage = ModelUsage.fromJson(data);
            _emitSession(
              await _sessions.recordContextTokens(
                sessionId,
                usage.contextTokens,
                usageCostUsd: modelUsageCostUsd(usage, resolvedModel.pricing),
              ),
            );
          }
        },
        onStatus: (status, {error}) =>
            reportStatus(protocolSessionStatus(status), error: error),
        onProviderItems: (items) =>
            _timeline.appendProviderItems(sessionId, items),
        onUiSnapshot: (snapshot) => _pluginUi.rememberPublished(
          plugin: snapshot.plugin,
          contribution: snapshot.contribution,
          request: snapshot.request,
          document: snapshot.document,
        ),
      );

      final turnAttachments = await _attachments.resolveAll(
        attachmentIds,
        hydrate: true,
      );
      final history = await _hydrateHistory(
        await _timeline.providerHistory(sessionId),
      );
      final pendingInputs = await multiAgent
          ?.drainSourceFor(sessionId)
          .drainPending();
      if (pendingInputs != null && pendingInputs.isNotEmpty) {
        await _timeline.appendProviderItems(sessionId, pendingInputs);
      }
      // Read per turn rather than per session: the worktree is a live checkout,
      // so a turn that follows an edit to AGENTS.md must see the edit.
      final projectDoc = await _projectDocs.load(workspaceRoot: worktree.path);
      final selectedLuaTools = InvocationLocalSelectedLuaToolInvoker();
      late final Future<void> running;
      running = _run(
        harness.startTurn(
          request: LuaAgentHarnessRequest(
            definition: definition,
            sessionId: sessionId,
            turnId: turnId,
            workspaceId: worktree.workspaceId,
            workspaceRoot: worktree.path,
            prompt: prompt,
            modelId: resolvedModel.modelId,
            model: resolvedModel.provider,
            modelCapabilities: resolvedModel.capabilities,
            modelControls: agentModelControls(modelControls),
            history: history,
            attachments: turnAttachments,
            turnInputs: pendingInputs ?? const <ConversationItem>[],
            allowedCapabilitiesByPlugin: allowedCapabilities,
            primitives: _hostPrimitiveRegistryFactory.create(
              workspaceRoot: worktree.path,
              attachments: attachmentPublisher,
              attachmentReader: attachmentReader,
              clock: agentClock,
              questions: questions,
              processes: execHost,
              skills: skills,
              callId: turnId,
              isRootAgent: isRootAgent,
              session: session,
              definition: definition,
              collaboration: multiAgent,
              mcp: _mcpFor?.call(worktree.path),
              luaCodeMode: SessionLuaCodeModeHost(
                _luaCodeMode,
                sessionId,
                worktree.path,
              ),
              selectedTools: selectedLuaTools,
            ),
            projectDocument: projectDoc?.render(),
            extensionData: <String, Object?>{
              'host_policy': <String, Object?>{
                'permission_mode': (await _effectivePermissionForSession(
                  sessionId,
                )).name,
                'workspace_root': worktree.path,
              },
              'collaboration': ?multiAgent?.extensionDataFor(
                session,
                definition,
              ),
            },
            sessionControlValues: sessionControlValues,
            contextWindowTokens: resolvedModel.limits?.context,
            internal: internal,
            approvals: _interactions.approvalsFor(
              sessionId: sessionId,
              turnId: turnId,
            ),
            permissions: _LivePermissionModeSource(
              () => _effectivePermissionForSession(sessionId),
            ),
            policyFactory: DefaultApprovalPolicy.new,
            state: _pluginState,
            jobs: _pluginJobs,
            clock: _clock,
            ids: _ids,
            network: _pluginNetwork,
            secrets: _pluginSecrets,
            selectedLuaTools: selectedLuaTools,
          ),
          callbacks: callbacks,
          cancellation: cancellation,
        ),
        sessionId: sessionId,
        turnId: turnId,
        cancellation: cancellation,
        revocations: revocations,
      ).whenComplete(() => _runningTurns.remove(running));
      _runningTurns.add(running);
      unawaited(running);
      onLaunched();
      return true;
    } on Object catch (error) {
      await _failUnlaunchedTurn(
        sessionId: sessionId,
        turnId: turnId,
        cancellation: cancellation,
        error: error,
      );
      rethrow;
    }
  }

  /// Settles a turn whose runner failed before it was detached.
  ///
  /// The normal runner owns this lifecycle after the launch callback.
  /// Preparation is different: no detached future exists to report the
  /// failure, so this boundary must publish the same terminal state and
  /// release its in-memory ownership before the RPC returns.
  Future<void> _failUnlaunchedTurn({
    required String sessionId,
    required String turnId,
    required CancellationToken cancellation,
    required Object error,
  }) async {
    if (identical(_activeTurns[sessionId], cancellation)) {
      _activeTurns.remove(sessionId);
    }
    _failTurnCompletion(turnId, error);
    await _sessions.updateTurn(turnId, TurnStatus.failed, error: '$error');
    await _appendEvent(
      sessionId: sessionId,
      turnId: turnId,
      type: 'turn.failed',
      data: <String, dynamic>{'error': '$error'},
    );
    _emitSession(
      await _sessions.updateStatus(
        sessionId,
        SessionStatus.failed,
        error: '$error',
      ),
    );
  }

  /// Cancels and drains every turn before its repositories are closed.
  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    _closing = true;
    for (final cancellation in _activeTurns.values.toList()) {
      cancellation.cancel();
    }
    if (_startingTurns.isNotEmpty) {
      _startsDrained ??= Completer<void>();
      await _startsDrained!.future;
    }
    for (final cancellation in _activeTurns.values.toList()) {
      cancellation.cancel();
    }
    while (_runningTurns.isNotEmpty) {
      await Future.wait(_runningTurns.toList());
    }
    Object? lifecycleError;
    try {
      await _pluginLifecycle.close();
    } on Object catch (error) {
      lifecycleError = error;
    }
    if (lifecycleError != null) {
      throw StateError('Plugin lifecycle close failed: $lifecycleError');
    }
  }

  Future<Map<String, Set<String>>> _preparePlugins(
    AgentDefinitionDto definition,
  ) async {
    final pluginIds = <String>{
      _pluginId(definition.driverId),
      ...definition.extensionIds.map(_pluginId),
      ...definition.toolIds.map(_pluginId),
    };
    for (final pluginId in pluginIds) {
      await _plugins.prepareForAgent(definition.id, pluginId);
    }
    final grants = await _plugins.grants.list(definition.id);
    return <String, Set<String>>{
      for (final pluginId in pluginIds)
        pluginId: <String>{
          for (final grant in grants)
            if (grant.pluginId == pluginId) grant.capability,
        },
    };
  }

  Future<List<ConversationItem>> _hydrateHistory(
    List<ConversationItem> history,
  ) async => await Future.wait(
    history.map((item) async {
      if (item is! UserConversationItem || item.attachments.isEmpty) {
        return item;
      }
      return UserConversationItem(
        item.text,
        attachments: await _attachments.resolveAll(
          item.attachments.map((attachment) => attachment.id).toList(),
          hydrate: true,
        ),
      );
    }),
  );

  Future<void> _run(
    Future<AgentRunResult> running, {
    required String sessionId,
    required String turnId,
    required CancellationToken cancellation,
    required StreamSubscription<AgentPluginGrantDto> revocations,
  }) async {
    TurnStatus outcome;
    String? finalText;
    String? failure;
    try {
      final result = await running;
      await _sessions.updateTurn(turnId, TurnStatus.completed);
      _completeTurn(turnId, result);
      outcome = TurnStatus.completed;
      finalText = result.conversationItems
          .whereType<AssistantConversationItem>()
          .map((item) => item.text)
          .where((text) => text.isNotEmpty)
          .lastOrNull;
    } on AgentCancelledException {
      await _sessions.updateTurn(turnId, TurnStatus.cancelled);
      _failTurnCompletion(turnId, const AgentCancelledException());
      outcome = TurnStatus.cancelled;
      // This is the terminal boundary of a detached turn. Lua/provider
      // contract validation can report Dart [Error] values (for example
      // [StateError]); if one escaped here, the durable turn would be marked
      // failed but the unowned Future would still surface as an unhandled
      // isolate error.
    } on Object catch (error) {
      await _markTurnFailed(turnId, error);
      _failTurnCompletion(turnId, error);
      outcome = TurnStatus.failed;
      failure = '$error';
    } finally {
      await revocations.cancel();
      if (identical(_activeTurns[sessionId], cancellation)) {
        _activeTurns.remove(sessionId);
      }
    }
    // Runs after the turn slot is free so collaboration follow-ups can start
    // the session's next turn immediately.
    try {
      await multiAgent?.onTurnFinished(
        sessionId: sessionId,
        outcome: outcome,
        finalText: finalText,
        error: failure,
      );
    } on Exception {
      // See the StateError clause below: this runner is detached, so an
      // escaping failure has no handler above it.
    }
    // The daemon closes its database while turns may still be settling, and
    // drift reports a query that outlives it as a StateError. Restart
    // recovery reconciles session state and queued mail is durable, so
    // there is nothing to salvage — but letting it escape a detached runner
    // would surface as an unhandled error.
    // ignore: avoid_catching_errors
    on StateError {
      // Nothing to salvage; see above.
    }
  }

  Future<void> _markTurnFailed(String turnId, Object error) =>
      _sessions.updateTurn(turnId, TurnStatus.failed, error: '$error');

  /// The cancelTurn public API member.
  @override
  Future<void> cancelTurn(String sessionId) async {
    _activeTurns[sessionId]?.cancel();
  }

  /// Completes once the client queues input for [sessionId].
  ///
  /// Waiters share one completer, so a single notice wakes every sleeping
  /// tool in that session and a fresh completer takes its place.
  /// The notice is sticky: a client that queues something before the agent
  /// starts waiting would otherwise have its signal dropped, and the next
  /// sleep would run its full duration.
  @override
  Future<void> pendingInput(String sessionId) {
    return _interactions.pendingInput(sessionId);
  }

  /// Reports that the client has something queued for [sessionId].
  ///
  /// Best-effort: it only shortens a wait, so a lost notice costs a longer
  /// sleep and nothing else.
  void notePendingInput(String sessionId) {
    _interactions.notePendingInput(sessionId);
  }

  Future<void> _appendEvent({
    required String sessionId,
    required String? turnId,
    required String type,
    required Map<String, dynamic> data,
  }) async {
    final event = await _timeline.append(
      sessionId: sessionId,
      turnId: turnId,
      type: type,
      data: data,
    );
    _events(OutboundNotification(sessionsTimelineEventNotification, event));
  }

  void _emitSession(SessionDto? session) {
    if (session != null) {
      _events(OutboundNotification(sessionsUpdatedNotification, session));
    }
  }

  Future<PermissionMode> _effectivePermissionForSession(
    String sessionId,
  ) async {
    final session = await _sessions.getById(sessionId);
    if (session == null) return PermissionMode.readOnly;
    // A session mode may narrow an ancestor's permissions but never widen
    // them, so no agent in a nested tree can escalate past any ancestor.
    var mode = session.permissionMode;
    var parentId = session.parentSessionId;
    final visited = <String>{session.id};
    while (parentId != null && visited.add(parentId)) {
      final parent = await _sessions.getById(parentId);
      if (parent == null) return PermissionMode.readOnly;
      mode = _moreRestrictive(parent.permissionMode, mode);
      parentId = parent.parentSessionId;
    }
    return mode;
  }

  void _completeTurn(String turnId, AgentRunResult result) {
    final completion = _turnCompletions.remove(turnId);
    if (completion != null && !completion.isCompleted) {
      completion.complete(result);
    }
  }

  void _failTurnCompletion(String turnId, Object error) {
    final completion = _turnCompletions.remove(turnId);
    if (completion != null && !completion.isCompleted) {
      completion.completeError(error);
    }
  }
}

PermissionMode _moreRestrictive(PermissionMode left, PermissionMode right) {
  const rank = <PermissionMode, int>{
    PermissionMode.readOnly: 0,
    PermissionMode.ask: 1,
    PermissionMode.workspaceWrite: 2,
    PermissionMode.fullAccess: 3,
  };
  return rank[left]! <= rank[right]! ? left : right;
}

final class _LivePermissionModeSource implements PermissionModeSource {
  const new(this._read);

  final Future<PermissionMode> Function() _read;

  @override
  Future<AgentPermissionMode> currentMode() async =>
      agentPermission(await _read());
}
