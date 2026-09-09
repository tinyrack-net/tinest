import 'package:protocol/protocol.dart';

/// Timeline events requested per history page.
///
/// A session stores one row per streamed delta, so an unbounded history is
/// unbounded in bytes too, and a relay drops a daemon whose frame exceeds its
/// limit. This is the count that keeps one page comfortably under it while
/// still filling a tall viewport in a single request.
const int timelineHistoryPageSize = 200;

/// Authenticated streaming attachment download.
final class AttachmentDownload {
  /// Creates a download stream and response metadata.
  const new({
    required this.fileName,
    required this.mimeType,
    required this.byteSize,
    required this.bytes,
  });

  /// Server-provided display filename.
  final String fileName;

  /// Validated response media type.
  final String mimeType;

  /// Exact response length.
  final int byteSize;

  /// Payload bytes.
  final Stream<List<int>> bytes;
}

/// Values supported by ClientConnectionState.
enum ClientConnectionState {
  /// The initial connection is opening.
  connecting,

  /// The JSON-RPC handshake completed.
  connected,

  /// A previously connected client is reconnecting.
  reconnecting,

  /// No transport is currently connected.
  disconnected,
}

/// Workspace operations exposed by the v5 client.
abstract interface class WorkspacesApi {
  /// Returns repositories and active checkouts atomically.
  Future<WorkspaceCatalogDto> getWorkspaceCatalog();

  /// Registers a repository checkout.
  Future<WorkspaceRegisterResultDto> registerWorkspace({
    required String workspaceId,
    required String checkoutId,
    required String rootPath,
    required String name,
  });

  /// Refreshes Git metadata and checkout registrations.
  Future<WorkspaceCatalogDto> refreshWorkspace(String workspaceId);

  /// Removes a repository registration.
  Future<void> unregisterWorkspace(String workspaceId);

  /// Searches directories on the daemon machine.
  Future<List<DirectorySuggestionDto>> suggestDirectories(
    String query, {
    int limit = 30,
  });

  /// Searches a worktree for files.
  Future<FileSearchResultDto> searchFiles({
    required String worktreeId,
    required String query,
    int limit = 50,
  });

  /// Lists local branches in a repository.
  Future<List<GitBranchDto>> listGitBranches(String workspaceId);

  /// Reads project settings.
  Future<ProjectSettingsResultDto> getProjectSettings(String workspaceId);

  /// Saves project settings.
  Future<ProjectSettingsResultDto> saveProjectSettings(
    String workspaceId,
    ProjectSettingsDto settings,
  );

  /// Creates a managed worktree.
  ///
  /// [branchNaming] decides what the daemon does when [branchName] is taken.
  /// Callers that derive the name from a prompt pass
  /// [WorktreeBranchNaming.derive] so a branch an archived worktree left
  /// behind cannot block the request.
  Future<WorktreeResultDto> createWorktree({
    required String id,
    required String workspaceId,
    required WorktreeCreateMode mode,
    required String branchName,
    String? baseBranch,
    WorktreeBranchNaming branchNaming,
  });

  /// Previews archive safety conditions.
  Future<WorktreeArchivePreviewDto> previewWorktreeArchive(String worktreeId);

  /// Archives a managed worktree.
  Future<WorktreeResultDto> archiveWorktree(
    String worktreeId, {
    bool force = false,
  });
}

/// Session operations and updates exposed by the v5 client.
abstract interface class SessionsApi {
  /// Session lifecycle updates.
  Stream<SessionDto> get sessionUpdates;

  /// Ordered timeline events.
  Stream<TimelineEventDto> get timelineEvents;

  /// Approval requests awaiting the user.
  Stream<ApprovalRequestDto> get approvalRequests;

  /// Questions awaiting the user.
  Stream<UserQuestionRequestDto> get questionRequests;

  /// Lists persisted sessions.
  Future<List<SessionDto>> listSessions({String? worktreeId});

  /// Lists one collaboration tree.
  Future<List<SessionDto>> listSubagents(String sessionId);

  /// Creates a session.
  Future<SessionDto> createSession({
    required String id,
    required String worktreeId,
    required String title,
    required String agentDefinitionId,
    ModelSelectionDto? model,
    Map<String, ModelControlValueDto> modelControls =
        const <String, ModelControlValueDto>{},
    PermissionMode? permissionMode,
  });

  /// Atomically updates nullable session execution settings.
  Future<SessionDto> updateSettings(
    String sessionId,
    SessionSettingsPatchDto patch,
  );

  /// Starts a turn.
  Future<void> startTurn({
    required String sessionId,
    required String turnId,
    required String prompt,
    List<String> attachmentIds = const <String>[],
  });

  /// Cancels a running turn.
  Future<void> cancelTurn(String sessionId);

  /// Resolves a pending approval.
  Future<void> resolveApproval({
    required String approvalId,
    required bool approved,
  });

  /// Reports queued user input.
  Future<void> notePendingInput(String sessionId);

  /// Answers a pending user question.
  Future<UserQuestionRequestDto> answerUserQuestion({
    required String requestId,
    required List<UserQuestionAnswerDto> answers,
  });

  /// Subscribes to a session timeline.
  ///
  /// A non-null [tailLimit] returns only the newest events rather than the
  /// whole history, which is what keeps a long conversation's first frame off
  /// the relay's frame-size limit.
  Future<List<TimelineEventDto>> subscribeTimeline(
    String sessionId, {
    int afterSequence = 0,
    int? tailLimit,
  });

  /// Reads the page of history immediately preceding [beforeSequence].
  ///
  /// A pure read: it never moves the live delivery cursor, so paging backwards
  /// cannot drop events arriving at the same time. An empty result means the
  /// beginning of the conversation has been reached.
  Future<List<TimelineEventDto>> readTimelineHistory(
    String sessionId, {
    required int beforeSequence,
    required int limit,
  });
}

/// Agent-definition operations exposed by the v5 client.
abstract interface class AgentsApi {
  /// Emits whenever the agent-definition catalog changes.
  Stream<void> get definitionChanges;

  /// Lists agent definitions.
  Future<List<AgentDefinitionDto>> listAgentDefinitions();

  /// Reads an agent definition.
  Future<AgentDefinitionDto> getAgentDefinition(String id);

  /// Creates an agent definition.
  Future<AgentDefinitionDto> createAgentDefinition(
    String id,
    AgentDefinitionDto definition,
  );

  /// Updates an agent definition.
  Future<AgentDefinitionDto> updateAgentDefinition(
    AgentDefinitionDto definition, {
    required String expectedContentHash,
    bool force = false,
  });

  /// Archives an agent definition.
  Future<void> archiveAgentDefinition(String id);

  /// Resets a built-in agent definition.
  Future<AgentDefinitionDto> resetAgentDefinition(String id);

  /// Validates an agent definition without saving it.
  Future<AgentDefinitionDto> validateAgentDefinition(
    String id,
    String markdown,
  );

  /// Lists tools available to an agent.
  Future<List<AgentToolDefinitionDto>> listAgentTools({String? worktreeId});

  /// Reads the daemon default permission mode.
  Future<PermissionSettingsDto> getDefaultPermissionMode();

  /// Replaces the daemon default permission mode.
  Future<PermissionSettingsDto> setDefaultPermissionMode(
    PermissionMode permissionMode,
  );
}

/// Plugin package, grant, and declarative UI operations exposed by v5.
abstract interface class PluginsApi {
  /// Emits when app-data plugin source files may have changed.
  Stream<void> get pluginChanges;

  /// Lists installed built-in and app-data plugins.
  Future<List<PluginDescriptorDto>> listPlugins();

  /// Reads one plugin descriptor.
  Future<PluginDescriptorDto> getPlugin(String id);

  /// Validates a source revision without activating it.
  Future<PluginDescriptorDto> validatePlugin(String id);

  /// Activates a valid source revision within one Agent's grants.
  Future<PluginDescriptorDto> reloadPlugin(String id, String agentId);

  /// Creates a user plugin package under the app-data directory.
  Future<PluginDescriptorDto> scaffoldPlugin(String id, String name);

  /// Copies one installed validated revision into a new app-data plugin.
  Future<PluginDescriptorDto> forkPlugin({
    required String sourceId,
    required String id,
    required String name,
  });

  /// Reads the exact SDK ABI and LuaLS sidecar state for a user plugin.
  Future<PluginAuthoringEnvironmentDto> getPluginAuthoringEnvironment(
    String id,
  );

  /// Atomically synchronizes the exact SDK ABI and LuaLS sidecar.
  Future<PluginAuthoringEnvironmentDto> syncPluginAuthoringEnvironment(
    String id,
  );

  /// Lists the capability grants owned by one Agent.
  Future<List<AgentPluginGrantDto>> listPluginGrants(String agentId);

  /// Grants one exact Agent, plugin, and capability tuple.
  Future<List<AgentPluginGrantDto>> grantPluginCapability(
    AgentPluginGrantDto grant,
  );

  /// Revokes one exact Agent, plugin, and capability tuple.
  Future<List<AgentPluginGrantDto>> revokePluginCapability(
    AgentPluginGrantDto grant,
  );

  /// Stores a secret in one Agent/plugin namespace without returning it.
  Future<void> setPluginSecret({
    required String agentId,
    required String pluginId,
    required String name,
    required String value,
  });

  /// Removes one Agent/plugin secret without exposing whether it existed.
  Future<void> removePluginSecret({
    required String agentId,
    required String pluginId,
    required String name,
  });

  /// Reads one durable session-control value from an Agent-active plugin.
  Future<PluginSessionControlValueDto> getPluginSessionControl({
    required String sessionId,
    required String pluginId,
    required String contributionId,
  });

  /// Normalizes and replaces one durable plugin session-control value.
  Future<PluginSessionControlValueDto> setPluginSessionControl({
    required String sessionId,
    required String pluginId,
    required String contributionId,
    required Object? value,
  });

  /// Renders one declarative plugin UI contribution.
  Future<PluginUiDocumentDto> renderPluginUi({
    required String agentId,
    required String pluginId,
    required String contributionId,
    required PluginUiSlot slot,
    Object? input,
    Map<String, dynamic> context = const <String, dynamic>{},
  });

  /// Dispatches an action from a previously rendered document.
  Future<PluginUiDocumentDto> dispatchPluginUiAction({
    required String agentId,
    required String pluginId,
    required PluginUiActionDto action,
  });
}

/// Prompt, command, and skill operations exposed by the v5 client.
abstract interface class PromptsApi {
  /// Emits whenever the skill catalog changes.
  Stream<void> get skillChanges;

  /// Emits whenever the command catalog changes.
  Stream<void> get commandChanges;

  /// Lists commands visible in a workspace.
  Future<List<AgentCommandDto>> listCommands({String? workspaceId});

  /// Lists effective skill metadata for one catalog view.
  Future<List<SkillSummaryDto>> listSkills({
    required SkillListView view,
    String? workspaceId,
  });
}

/// Daemon-owned model settings exposed by the v4 client.
abstract interface class ModelsApi {
  /// Reads the daemon default model.
  Future<DaemonModelSettingsDto> getSettings();

  /// Replaces the daemon default with one concrete runnable model.
  Future<DaemonModelSettingsDto> setDefaultModel(ModelSelectionDto model);
}

/// Provider operations exposed by the v5 client.
abstract interface class ProvidersApi {
  /// Provider authorization updates.
  Stream<ProviderAuthAttemptDto> get authUpdates;

  /// Catalog state emitted after asynchronous refresh attempts.
  Stream<ProviderCatalogDto> get catalogUpdates;

  /// Lists built-in provider definitions.
  Future<ProviderCatalogDto> listProviderCatalog();

  /// Lists configured provider connections.
  Future<List<ProviderConnectionDto>> listProviderConnections();

  /// Lazily reads quota usage for configured provider connections.
  Future<List<ProviderUsageDto>> listProviderUsage();

  /// Connects a provider with an API key.
  Future<ProviderConnectionDto> connectProviderApiKey(
    String definitionId,
    String apiKey, {
    String? connectionId,
    String? modelPrefix,
  });

  /// Connects a provider without credentials.
  Future<ProviderConnectionDto> connectProviderNone(
    String definitionId, {
    String? connectionId,
    String? modelPrefix,
  });

  /// Starts provider authorization.
  Future<ProviderAuthAttemptDto> startProviderAuth(
    String definitionId,
    String methodId, {
    String? connectionId,
    String? modelPrefix,
  });

  /// Reads provider authorization state.
  Future<ProviderAuthAttemptDto> providerAuthStatus(String attemptId);

  /// Cancels provider authorization.
  Future<void> cancelProviderAuth(String attemptId);

  /// Disconnects a provider.
  Future<void> disconnectProvider(String connectionId);

  /// Changes a connection's globally unique model prefix.
  Future<ProviderConnectionDto> updateProviderModelPrefix(
    String connectionId,
    String modelPrefix,
  );

  /// Refreshes provider metadata.
  Future<ProviderCatalogDto> refreshProviderCatalog();

  /// Lists models for a connection.
  Future<List<ProviderModelDto>> listProviderModels(String connectionId);

  /// Creates a custom provider.
  Future<ProviderConnectionDto> createCustomProvider(
    String id,
    CustomProviderConfigDto config, {
    String? apiKey,
    String? modelPrefix,
  });

  /// Updates a custom provider.
  Future<ProviderConnectionDto> updateCustomProvider(
    String connectionId,
    CustomProviderConfigDto config, {
    String? apiKey,
  });

  /// Deletes a custom provider.
  Future<void> deleteCustomProvider(String connectionId);
}

/// MCP operations exposed by the v5 client.
abstract interface class McpApi {
  /// Emits whenever MCP server state changes.
  Stream<void> get serverChanges;

  /// Lists MCP server state.
  Future<List<McpServerStateDto>> listMcpServers({String? worktreeId});

  /// Adds an MCP server.
  Future<McpServerStateDto> addMcpServer(McpServerConfigDto server);

  /// Updates an MCP server.
  Future<McpServerStateDto> updateMcpServer(McpServerConfigDto server);

  /// Removes an MCP server.
  Future<void> removeMcpServer(String id);

  /// Tests an MCP server configuration.
  Future<McpServerStateDto> testMcpServer(McpServerConfigDto server);

  /// Stores an MCP secret.
  Future<void> setMcpSecret(String key, String value);
}

/// Terminal operations and output exposed by the v5 client.
abstract interface class TerminalsApi {
  /// Ordered terminal output chunks.
  Stream<TerminalOutputDto> get output;

  /// Terminal lifecycle and size updates.
  Stream<TerminalDto> get terminalUpdates;

  /// Lists live terminals.
  Future<List<TerminalDto>> listTerminals(String worktreeId);

  /// Creates a terminal.
  Future<TerminalDto> createTerminal({
    required String id,
    required String worktreeId,
    required String title,
    required int columns,
    required int rows,
  });

  /// Attaches to a terminal and asks for whatever makes the caller current.
  ///
  /// [viewport] claims the terminal's size and must be null unless the caller
  /// genuinely changed or focused its own viewport; a passive attach that
  /// claims a size fights every other attached client.
  Future<TerminalAttachResultDto> attachTerminal(
    String terminalId, {
    required TerminalRestoreMode mode,
    int afterSequence = 0,
    int scrollbackLines = terminalRestoreScrollbackLines,
    TerminalViewportDto? viewport,
  });

  /// Writes terminal input.
  Future<void> writeTerminal(String terminalId, String data);

  /// Resizes a terminal.
  Future<TerminalDto> resizeTerminal(
    String terminalId, {
    required int columns,
    required int rows,
  });

  /// Terminates a terminal.
  Future<void> terminateTerminal(String terminalId);

  /// Reads the terminal shell override.
  Future<ShellSpecDto?> getTerminalShell();

  /// Replaces the terminal shell override.
  Future<void> setTerminalShell(ShellSpecDto? shell);
}

/// Attachment transfer operations exposed by the v5 client.
abstract interface class AttachmentsApi {
  /// Uploads an attachment.
  Future<AttachmentDto> uploadAttachment({
    required String fileName,
    required String mimeType,
    required int byteSize,
    required Stream<List<int>> bytes,
  });

  /// Downloads an attachment.
  Future<AttachmentDownload> downloadAttachment(String id);
}

/// Relay configuration, pairing, and approved-device operations.
abstract interface class RelayApi {
  /// Relay status changes emitted by the daemon.
  Stream<RelayStatusDto> get statusUpdates;

  /// Reads current relay status.
  Future<RelayStatusDto> getRelayStatus();

  /// Enables or disables outbound relay operation.
  Future<RelayStatusDto> setRelayEnabled({required bool enabled});

  /// Changes the persisted relay endpoint and reconnects when enabled.
  Future<RelayStatusDto> setRelayEndpoint(String endpoint);

  /// Creates a ten-minute, one-time pairing offer.
  Future<RelayPairingOfferDto> createRelayPairingOffer();

  /// Lists approved devices.
  Future<List<RelayDeviceDto>> listRelayDevices();

  /// Revokes a device and terminates its active sessions.
  Future<void> revokeRelayDevice(String deviceId);
}

/// Root client API for connection lifecycle and feature-scoped operations.
abstract interface class TinestApi {
  /// Workspace-scoped operations.
  WorkspacesApi get workspaces;

  /// Session-scoped operations.
  SessionsApi get sessions;

  /// Agent-definition operations.
  AgentsApi get agents;

  /// Plugin package and runtime operations.
  PluginsApi get plugins;

  /// Prompt, command, and skill operations.
  PromptsApi get prompts;

  /// Daemon-owned model settings.
  ModelsApi get models;

  /// Provider operations.
  ProvidersApi get providers;

  /// MCP server operations.
  McpApi get mcp;

  /// Terminal operations.
  TerminalsApi get terminals;

  /// Attachment operations.
  AttachmentsApi get attachments;

  /// Relay and device-pairing operations.
  RelayApi get relay;

  /// Connection-state changes.
  Stream<ClientConnectionState> get states;

  /// Metadata returned by the v5 handshake.
  ServerInfoDto get serverInfo;

  /// Closes the connection and all feature streams.
  Future<void> close();
}
