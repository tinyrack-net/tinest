import 'dart:async';
import 'dart:typed_data';

import 'package:app/src/app/composition/app_services.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/hosts/domain/host_ports.dart';
import 'package:client/client.dart';
import 'package:protocol/protocol.dart';

sealed class ClientEvent {
  const ClientEvent();
}

extension TypedClientEventStream on Stream<ClientEvent> {
  Stream<T> whereType<T extends ClientEvent>() =>
      where((event) => event is T).cast<T>();
}

final class TimelineClientEvent extends ClientEvent {
  const TimelineClientEvent(this.event);
  final TimelineEventDto event;
}

final class SessionUpdatedClientEvent extends ClientEvent {
  const SessionUpdatedClientEvent(this.session);
  final SessionDto session;
}

final class TerminalOutputClientEvent extends ClientEvent {
  const TerminalOutputClientEvent(this.output);
  final TerminalOutputDto output;
}

final class TerminalUpdatedClientEvent extends ClientEvent {
  const TerminalUpdatedClientEvent(this.terminal);
  final TerminalDto terminal;
}

final class AgentDefinitionsChangedClientEvent extends ClientEvent {
  const AgentDefinitionsChangedClientEvent();
}

final class PluginsChangedClientEvent extends ClientEvent {
  const PluginsChangedClientEvent();
}

final class McpServersChangedClientEvent extends ClientEvent {
  const McpServersChangedClientEvent();
}

final class SkillsChangedClientEvent extends ClientEvent {
  const SkillsChangedClientEvent();
}

final class CommandsChangedClientEvent extends ClientEvent {
  const CommandsChangedClientEvent();
}

final class ApprovalRequestedClientEvent extends ClientEvent {
  const ApprovalRequestedClientEvent(this.approval);
  final ApprovalRequestDto approval;
}

final class UserQuestionRequestedClientEvent extends ClientEvent {
  const UserQuestionRequestedClientEvent(this.request);
  final UserQuestionRequestDto request;
}

final class ProviderAuthUpdatedClientEvent extends ClientEvent {
  const ProviderAuthUpdatedClientEvent(this.attempt);
  final ProviderAuthAttemptDto attempt;
}

/// An in-memory [TinestApi] used by notifier and widget tests.
final class FakeTinestApi
    implements
        TinestApi,
        WorkspacesApi,
        SessionsApi,
        AgentsApi,
        PluginsApi,
        PromptsApi,
        ModelsApi,
        ProvidersApi,
        McpApi,
        TerminalsApi,
        AttachmentsApi,
        RelayApi {
  /// Creates a configurable [FakeTinestApi].
  FakeTinestApi({
    ServerInfoDto? serverInfo,
    ProviderCatalogDto? catalog,
    List<ProviderConnectionDto>? connections,
    List<WorkspaceDto>? workspaces,
    List<WorktreeDto>? worktrees,
    List<SessionDto>? agents,
    List<TerminalDto>? terminals,
    List<AgentDefinitionDto>? agentDefinitions,
    List<SkillSummaryDto>? skills,
    List<SkillSummaryDto>? projectSkills,
    List<PluginDescriptorDto>? plugins,
    List<AgentPluginGrantDto>? pluginGrants,
    Map<String, PluginUiDocumentDto>? pluginUiDocuments,
    Map<String, PluginAuthoringEnvironmentDto>? pluginAuthoringEnvironments,
    Map<String, PluginSessionControlValueDto>? pluginSessionControls,
    Map<String, List<TimelineEventDto>>? timelines,
    Map<String, List<ProviderModelDto>>? models,
    List<ProviderUsageDto>? providerUsage,
    ModelSelectionDto? defaultModel,
    List<WorkspaceCatalogDto>? workspaceCatalogResponses,
    this.eventStream,
    this.agentListError,
    this.skillListError,
    this.failNextAgentCreate = false,
    this.failNextAgentUpdate = false,
    this.catalogRefreshError,
    this.providerConnectError,
    this.providerModelListError,
    this.modelListGate,
    this.suggestDirectoriesGate,
    this.workspaceCatalogGate,
    this.workspaceCatalogError,
    this.gitBranchesGate,
    this.gitBranchesError,
    this.previewArchiveGate,
    this.previewArchiveError,
    this.archiveWorktreeError,
    this.registerWorkspaceGate,
    this.agentDefinitionsGate,
    this.agentUpdateGate,
    this.terminalShellGate,
    this.listSessionsGate,
    this.listTerminalsGate,
    this.skillListGate,
    this.permissionSettingsGate,
    this.modelSettingsGate,
    this.providerConnectionsGate,
    this.providerDisconnectGate,
    this.mcpListGate,
    this.pluginListGate,
    this.createWorktreeError,
    this.suggestDirectoriesError,
    this.projectSettingsError,
    List<Future<List<McpServerStateDto>>>? mcpListResponses,
    this.terminalAttachError,
    this.terminalCreateError,
    this.terminalReplay = const <TerminalOutputDto>[],
    Map<String, List<String>>? directories,
    Map<String, List<String>>? files,
    List<AgentCommandDto>? commands,
    this.searchFilesGate,
    this.searchFilesError,
    this.defaultPermissionSetError,
    this.sessionPermissionSetError,
    this.relayPairingOffer,
    List<RelayDeviceDto>? relayDevices,
    this.relayEnabled = false,
    this.relayEndpoint = 'wss://relay.tinest.tinyrack.net/v1/ws',
    this._defaultPermissionMode = PermissionMode.ask,
  }) : mcpListResponses =
           mcpListResponses ?? <Future<List<McpServerStateDto>>>[],
       workspaceCatalogResponses =
           workspaceCatalogResponses ?? <WorkspaceCatalogDto>[],
       directories = directories ?? const <String, List<String>>{},
       files = files ?? const <String, List<String>>{},
       commands = List<AgentCommandDto>.of(
         commands ?? const <AgentCommandDto>[],
       ),
       _serverInfo = serverInfo ?? _defaultServerInfo,
       _catalog = catalog ?? _defaultCatalog,
       _connections =
           (connections ?? <ProviderConnectionDto>[_openAIConnection])
               .map(
                 (connection) => connection.modelPrefix.isEmpty
                     ? connection.copyWith(modelPrefix: connection.definitionId)
                     : connection,
               )
               .toList(),
       _defaultModel =
           defaultModel ??
           ((connections ?? <ProviderConnectionDto>[_openAIConnection]).isEmpty
               ? null
               : const ModelSelectionDto(modelId: 'openai/gpt-5.6-sol')),
       _workspaces = workspaces ?? <WorkspaceDto>[],
       _worktrees = worktrees ?? <WorktreeDto>[],
       _agents = agents ?? <SessionDto>[],
       _terminals = List<TerminalDto>.of(terminals ?? const <TerminalDto>[]),
       _terminalReplays = _groupReplay(terminalReplay),
       _agentDefinitions = List<AgentDefinitionDto>.of(
         agentDefinitions ?? <AgentDefinitionDto>[_tinest],
       ),
       _plugins = List<PluginDescriptorDto>.of(
         plugins ?? _defaultPlugins,
       ),
       _pluginGrants = List<AgentPluginGrantDto>.of(
         pluginGrants ?? const <AgentPluginGrantDto>[],
       ),
       pluginUiDocuments = Map<String, PluginUiDocumentDto>.of(
         pluginUiDocuments ?? const <String, PluginUiDocumentDto>{},
       ),
       pluginAuthoringEnvironments =
           Map<String, PluginAuthoringEnvironmentDto>.of(
             pluginAuthoringEnvironments ??
                 const <String, PluginAuthoringEnvironmentDto>{},
           ),
       pluginSessionControls = Map<String, PluginSessionControlValueDto>.of(
         pluginSessionControls ??
             const <String, PluginSessionControlValueDto>{},
       ),
       _skills = List<SkillSummaryDto>.of(
         skills ?? <SkillSummaryDto>[_builtInSkill, _configSkill],
       ),
       _projectSkills = List<SkillSummaryDto>.of(
         projectSkills ?? <SkillSummaryDto>[],
       ),
       relayDevices = List<RelayDeviceDto>.of(
         relayDevices ?? const <RelayDeviceDto>[],
       ),
       _timelines = <String, List<TimelineEventDto>>{
         for (final entry
             in (timelines ?? <String, List<TimelineEventDto>>{}).entries)
           entry.key: List<TimelineEventDto>.of(entry.value),
       },
       _providerUsage = List<ProviderUsageDto>.of(
         providerUsage ?? const <ProviderUsageDto>[],
       ),
       _models = <String, List<ProviderModelDto>>{
         'openai': <ProviderModelDto>[_openAIModel],
         for (final entry
             in (models ?? <String, List<ProviderModelDto>>{}).entries)
           entry.key: List<ProviderModelDto>.of(entry.value),
       };

  static final DateTime _now = DateTime.utc(2026);

  /// Pairing offer returned by the relay fake.
  final RelayPairingOfferDto? relayPairingOffer;

  /// Mutable approved-device state used by relay widget tests.
  final List<RelayDeviceDto> relayDevices;

  /// Device identifiers revoked through this fake.
  final List<String> revokedRelayDeviceIds = <String>[];

  /// Current relay activation state.
  bool relayEnabled;

  /// Current relay endpoint state.
  String relayEndpoint;

  /// Error thrown once by the next explicit provider catalog refresh.
  TinestClientException? catalogRefreshError;

  /// Error thrown once by the next explicit provider connection.
  TinestClientException? providerConnectError;
  static const ServerInfoDto _defaultServerInfo = ServerInfoDto(
    serverId: 'server',
    version: 'test',
    protocolVersion: tinestProtocolMajor,
    features: <String, bool>{},
  );
  static final ProviderCatalogDto _defaultCatalog = ProviderCatalogDto(
    definitions: const <ProviderDefinitionDto>[
      ProviderDefinitionDto(
        id: 'openai',
        name: 'OpenAI',
        description: 'OpenAI Platform API or ChatGPT subscription.',
        authMethods: <ProviderAuthMethodDto>[
          ProviderAuthMethodDto(
            id: 'chatgpt-browser',
            label: 'Sign in with ChatGPT',
            kind: ProviderAuthKind.oauth,
            flow: ProviderAuthFlow.oauthBrowser,
            experimental: true,
          ),
          ProviderAuthMethodDto(
            id: 'api-key',
            label: 'API key',
            kind: ProviderAuthKind.apiKey,
            flow: ProviderAuthFlow.apiKey,
          ),
        ],
        recommendedModelIds: <String>['gpt-5.6-sol'],
      ),
      ProviderDefinitionDto(
        id: 'deepseek',
        name: 'DeepSeek',
        description: 'DeepSeek hosted models.',
        authMethods: <ProviderAuthMethodDto>[
          ProviderAuthMethodDto(
            id: 'api-key',
            label: 'API key',
            kind: ProviderAuthKind.apiKey,
            flow: ProviderAuthFlow.apiKey,
          ),
        ],
      ),
    ],
    // A wire template names the control it can encode and no values: which
    // values an arbitrary endpoint accepts is stated by whoever runs it.
    wireFormats: const <ProviderWireFormatDto>[
      ProviderWireFormatDto(
        id: 'openai-chat-completions',
        label: 'OpenAI Chat Completions',
        controls: <ModelControlDescriptorDto>[
          ModelControlDescriptorDto(
            id: 'reasoning_effort',
            label: 'Reasoning effort',
            kind: ModelControlKind.choice,
            presentation: ModelControlPresentation.menuChip,
          ),
        ],
      ),
    ],
    source: ProviderCatalogSource.bundled,
    updatedAt: _now,
  );
  static final ProviderConnectionDto _openAIConnection = ProviderConnectionDto(
    id: 'openai',
    definitionId: 'openai',
    modelPrefix: 'openai',
    displayName: 'OpenAI',
    status: ProviderConnectionStatus.connected,
    authKind: ProviderAuthKind.apiKey,
    credentialOrigin: ProviderCredentialOrigin.stored,
    createdAt: _now,
    updatedAt: _now,
  );
  static const ProviderModelDto _openAIModel = ProviderModelDto(
    connectionId: 'openai',
    id: 'openai/gpt-5.6-sol',
    providerModelId: 'gpt-5.6-sol',
    label: 'GPT-5.6 Sol',
    source: ProviderModelSource.bundled,
    capabilities: ModelCapabilitiesDto(
      streaming: CapabilitySupport.supported,
      toolCalling: CapabilitySupport.supported,
      controls: <ModelControlDescriptorDto>[
        ModelControlDescriptorDto(
          id: 'reasoning_effort',
          label: 'Reasoning effort',
          kind: ModelControlKind.choice,
          presentation: ModelControlPresentation.menuChip,
          choices: <ModelControlChoiceDto>[
            ModelControlChoiceDto(id: 'medium', label: 'Medium'),
          ],
        ),
      ],
      source: CapabilitySource.bundled,
    ),
  );
  static const AgentDefinitionDto _tinest = AgentDefinitionDto(
    version: 5,
    id: 'tinest',
    name: 'Tinest',
    description: 'General-purpose coding agent',
    mode: AgentMode.primary,
    model: AgentModelSelectionDto(
      source: AgentModelSource.session,
    ),
    driverId: 'tinest.standard/driver',
    extensionIds: <String>[],
    toolIds: <String>['tinest.files/read_file'],
    pluginSettings: <String, Map<String, dynamic>>{},
    callableAgentIds: <String>[],
    prompt: 'Code carefully.',
    contentHash: 'tinest-hash',
    sourcePath: '/config/agents/tinest.md',
    isBuiltIn: true,
  );

  static const List<PluginDescriptorDto> _defaultPlugins =
      <PluginDescriptorDto>[
        PluginDescriptorDto(
          apiMajor: 5,
          id: 'tinest.standard',
          version: '1.0.0',
          name: 'Standard',
          entrypoint: 'main.lua',
          source: PluginSource.builtIn,
          sourcePath: '/built-in/tinest.standard',
          requestedCapabilities: <String>['model.call'],
          contributions: <PluginContributionDto>[
            PluginContributionDto(
              pluginId: 'tinest.standard',
              id: 'tinest.standard/driver',
              kind: PluginContributionKind.driver,
              metadata: <String, dynamic>{
                'name': 'Standard driver',
                'requiredModelCapabilities': <String>['streaming'],
              },
            ),
            PluginContributionDto(
              pluginId: 'tinest.standard',
              id: 'tinest.standard/telemetry',
              kind: PluginContributionKind.extension,
              metadata: <String, dynamic>{'lifecycle': 'after_model'},
            ),
          ],
        ),
        PluginDescriptorDto(
          apiMajor: 5,
          id: 'tinest.files',
          version: '1.0.0',
          name: 'Files',
          entrypoint: 'main.lua',
          source: PluginSource.builtIn,
          sourcePath: '/built-in/tinest.files',
          requestedCapabilities: <String>['workspace.read'],
          contributions: <PluginContributionDto>[
            PluginContributionDto(
              pluginId: 'tinest.files',
              id: 'tinest.files/read_file',
              kind: PluginContributionKind.tool,
              requiredCapabilities: <String>['workspace.read'],
              tool: AgentToolDefinitionDto(
                id: 'tinest.files/read_file',
                originPluginId: 'tinest.files',
                contributionId: 'read_file',
                name: 'read_file',
                description: 'Read a file.',
                risk: ToolRisk.read,
                group: 'filesystem',
                kind: AgentToolKind.function,
                inputSchema: <String, dynamic>{'type': 'object'},
                effects: <String>['filesystem.read'],
                presentation: <String, dynamic>{'group': 'filesystem'},
              ),
            ),
          ],
        ),
        PluginDescriptorDto(
          apiMajor: 5,
          id: 'tinest.terminal',
          version: '1.0.0',
          name: 'Terminal',
          entrypoint: 'main.lua',
          source: PluginSource.builtIn,
          sourcePath: '/built-in/tinest.terminal',
          requestedCapabilities: <String>['process.exec'],
          contributions: <PluginContributionDto>[
            PluginContributionDto(
              pluginId: 'tinest.terminal',
              id: 'tinest.terminal/exec_command',
              kind: PluginContributionKind.tool,
              requiredCapabilities: <String>['process.exec'],
              tool: AgentToolDefinitionDto(
                id: 'tinest.terminal/exec_command',
                originPluginId: 'tinest.terminal',
                contributionId: 'exec_command',
                name: 'exec_command',
                description: 'Run a command in a pseudo-terminal.',
                risk: ToolRisk.command,
                group: 'execution',
                kind: AgentToolKind.function,
                inputSchema: <String, dynamic>{'type': 'object'},
                effects: <String>['process.execute'],
                presentation: <String, dynamic>{'group': 'execution'},
              ),
            ),
          ],
        ),
        PluginDescriptorDto(
          apiMajor: 5,
          id: 'tinest.mcp',
          version: '1.0.0',
          name: 'MCP',
          entrypoint: 'main.lua',
          source: PluginSource.builtIn,
          sourcePath: '/built-in/tinest.mcp',
          requestedCapabilities: <String>['mcp.read'],
          contributions: <PluginContributionDto>[
            PluginContributionDto(
              pluginId: 'tinest.mcp',
              id: 'tinest.mcp/list_mcp_resources',
              kind: PluginContributionKind.tool,
              tool: AgentToolDefinitionDto(
                id: 'tinest.mcp/list_mcp_resources',
                originPluginId: 'tinest.mcp',
                contributionId: 'list_mcp_resources',
                name: 'list_mcp_resources',
                description: 'List MCP resources.',
                risk: ToolRisk.read,
                group: 'mcp',
                kind: AgentToolKind.function,
                inputSchema: <String, dynamic>{'type': 'object'},
                effects: <String>['mcp.read'],
                presentation: <String, dynamic>{'group': 'mcp'},
              ),
            ),
            PluginContributionDto(
              pluginId: 'tinest.mcp',
              id: 'tinest.mcp/list_mcp_resource_templates',
              kind: PluginContributionKind.tool,
              tool: AgentToolDefinitionDto(
                id: 'tinest.mcp/list_mcp_resource_templates',
                originPluginId: 'tinest.mcp',
                contributionId: 'list_mcp_resource_templates',
                name: 'list_mcp_resource_templates',
                description: 'List MCP resource templates.',
                risk: ToolRisk.read,
                group: 'mcp',
                kind: AgentToolKind.function,
                inputSchema: <String, dynamic>{'type': 'object'},
                effects: <String>['mcp.read'],
                presentation: <String, dynamic>{'group': 'mcp'},
              ),
            ),
            PluginContributionDto(
              pluginId: 'tinest.mcp',
              id: 'tinest.mcp/read_mcp_resource',
              kind: PluginContributionKind.tool,
              tool: AgentToolDefinitionDto(
                id: 'tinest.mcp/read_mcp_resource',
                originPluginId: 'tinest.mcp',
                contributionId: 'read_mcp_resource',
                name: 'read_mcp_resource',
                description: 'Read one MCP resource.',
                risk: ToolRisk.read,
                group: 'mcp',
                kind: AgentToolKind.function,
                inputSchema: <String, dynamic>{'type': 'object'},
                effects: <String>['mcp.read'],
                presentation: <String, dynamic>{'group': 'mcp'},
              ),
            ),
          ],
        ),
      ];

  static const SkillSummaryDto _builtInSkill = SkillSummaryDto(
    id: 'coding-conventions',
    name: 'coding-conventions',
    description: 'Match the surrounding code.',
    isImplicit: true,
  );

  static const SkillSummaryDto _configSkill = SkillSummaryDto(
    id: 'commit',
    name: 'commit',
    description: 'Writes atomic commits.',
    isImplicit: false,
  );

  final ServerInfoDto _serverInfo;
  ProviderCatalogDto _catalog;
  final List<ProviderConnectionDto> _connections;
  final List<WorkspaceDto> _workspaces;
  final List<WorktreeDto> _worktrees;
  final List<WorkspaceCatalogDto> workspaceCatalogResponses;
  final List<SessionDto> _agents;
  final List<TerminalDto> _terminals;
  final Map<String, List<TerminalOutputDto>> _terminalReplays;
  ShellSpecDto? _terminalShell;

  /// Groups seeded scrollback by terminal so attach can honour a resume cursor.
  static Map<String, List<TerminalOutputDto>> _groupReplay(
    List<TerminalOutputDto> replay,
  ) {
    final grouped = <String, List<TerminalOutputDto>>{};
    for (final output in replay) {
      grouped
          .putIfAbsent(output.terminalId, () => <TerminalOutputDto>[])
          .add(output);
    }
    return grouped;
  }

  /// Host shell saved through the settings API.
  ShellSpecDto? get terminalShell => _terminalShell;
  ModelSelectionDto? _defaultModel;

  /// Daemon-global concrete model saved through the model settings API.
  ModelSelectionDto? get defaultModel => _defaultModel;
  PermissionMode _defaultPermissionMode;

  /// Error thrown when the daemon-global permission default is saved.
  final Exception? defaultPermissionSetError;

  /// Error thrown when a chat permission override is saved.
  final Exception? sessionPermissionSetError;

  /// Daemon-global default permission mode.
  PermissionMode get defaultPermissionMode => _defaultPermissionMode;
  final List<AgentDefinitionDto> _agentDefinitions;
  final List<PluginDescriptorDto> _plugins;
  final List<AgentPluginGrantDto> _pluginGrants;

  /// Declarative documents keyed by `plugin/contribution/agent`.
  final Map<String, PluginUiDocumentDto> pluginUiDocuments;

  /// Daemon failure every render answers with, when one is staged.
  TinestClientException? pluginUiRenderFailure;

  /// Awaited before a render answers, to hold one in flight.
  Completer<void>? pluginUiRenderGate;

  /// Optional explicit authoring states keyed by plugin ID.
  final Map<String, PluginAuthoringEnvironmentDto> pluginAuthoringEnvironments;

  /// Session controls keyed by `session/plugin/contribution`.
  final Map<String, PluginSessionControlValueDto> pluginSessionControls;

  /// Plugin session-control mutations received by the fake transport.
  final List<
    ({
      String sessionId,
      String pluginId,
      String contributionId,
      Object? value,
    })
  >
  pluginSessionControlSets =
      <
        ({
          String sessionId,
          String pluginId,
          String contributionId,
          Object? value,
        })
      >[];

  /// Plugin reload calls in transport order.
  final List<({String pluginId, String agentId})> reloadedPlugins =
      <({String pluginId, String agentId})>[];
  final List<(String, String, String)> forkedPlugins =
      <(String, String, String)>[];
  final Map<String, String> pluginSecrets = <String, String>{};

  /// Plugin UI actions dispatched through the fake transport.
  final List<PluginUiActionDto> pluginUiActions = <PluginUiActionDto>[];

  /// Plugin UI render requests received by the fake transport.
  final List<
    ({
      String agentId,
      String pluginId,
      String contributionId,
      PluginUiSlot slot,
      Map<String, dynamic> context,
    })
  >
  pluginUiRenders =
      <
        ({
          String agentId,
          String pluginId,
          String contributionId,
          PluginUiSlot slot,
          Map<String, dynamic> context,
        })
      >[];
  final List<SkillSummaryDto> _skills;
  final List<SkillSummaryDto> _projectSkills;
  final Map<String, List<TimelineEventDto>> _timelines;
  final List<ProviderUsageDto> _providerUsage;
  final Map<String, List<ProviderModelDto>> _models;

  /// Optional event stream that can model transport lifecycle races.
  final Stream<ClientEvent>? eventStream;

  /// Optional failure returned while loading Markdown agent definitions.
  final Exception? agentListError;

  /// Optional failure returned while loading the skill catalog.
  Exception? skillListError;

  /// Skill catalog requests, retained so scope and routing tests can inspect
  /// the exact view sent to the API.
  final List<SkillListParamsDto> skillListRequests = <SkillListParamsDto>[];

  /// Optional attach failure used by terminal error-state tests.
  ///
  /// Mutable so a retry test can clear the failure between attempts.
  Exception? terminalAttachError;

  /// Scrollback returned by terminal attach.
  final List<TerminalOutputDto> terminalReplay;

  /// Whether the next guarded Markdown save should simulate a file race.
  bool failNextAgentUpdate;

  /// Whether the next Markdown create should simulate a daemon failure.
  bool failNextAgentCreate;

  /// Optional gate used to keep model discovery in its loading state.
  final Future<void>? modelListGate;

  /// Optional gate used to keep daemon model settings loading.
  final Future<void>? modelSettingsGate;

  /// Optional failure returned while loading one provider's model catalog.
  final Exception? providerModelListError;

  /// Optional gate used to keep the workspace catalog in its loading state.
  final Future<void>? workspaceCatalogGate;

  /// Optional failure returned while loading the workspace catalog.
  Exception? workspaceCatalogError;

  /// Optional gate used to keep Git branch discovery in its loading state.
  Completer<void>? gitBranchesGate;

  /// Optional failure returned while loading Git branches.
  Exception? gitBranchesError;

  /// Optional gate used to keep archive safety inspection pending.
  Completer<void>? previewArchiveGate;

  /// Optional failure returned by archive safety inspection.
  Exception? previewArchiveError;

  /// Optional failure returned while archiving a worktree.
  Exception? archiveWorktreeError;

  /// Optional gate used to keep repository registration pending.
  Completer<void>? registerWorkspaceGate;

  /// Optional gate used to keep agent definition discovery in its loading
  /// state. Tests may replace it after the initial catalog has loaded.
  Future<void>? agentDefinitionsGate;

  /// Number of agent definition catalog reads.
  int agentDefinitionsListCount = 0;

  /// Optional gate used to keep an Agent definition update pending.
  final Future<void>? agentUpdateGate;

  /// Optional gate used to keep daemon shell settings in their loading state.
  final Future<void>? terminalShellGate;

  /// Optional gate used to keep skill discovery in its loading state.
  final Future<void>? skillListGate;

  /// Optional gate used to keep the session catalog in its loading state.
  final Future<void>? listSessionsGate;

  /// Optional gate used to keep the terminal catalog in its loading state.
  final Future<void>? listTerminalsGate;

  /// Number of [listSessions] calls, counted so a test can assert that an
  /// unrelated change never reloads the session catalog.
  int listSessionsCount = 0;

  /// Number of [listTerminals] calls, counted for the same reason.
  int listTerminalsCount = 0;

  /// Number of [subscribeTimeline] calls, counted for the same reason.
  int subscribeTimelineCount = 0;

  /// Number of [getWorkspaceCatalog] calls, counted for the same reason.
  int workspaceCatalogCount = 0;

  /// Optional gate used to keep a terminal creation pending.
  Completer<void>? terminalCreateGate;

  /// Optional daemon failure thrown while creating a terminal.
  Exception? terminalCreateError;

  /// Optional gate used to keep permission settings in their loading state.
  final Future<void>? permissionSettingsGate;

  /// Optional gate used to keep provider settings in their loading state.
  final Future<void>? providerConnectionsGate;

  /// Optional gate used to keep provider disconnection pending.
  final Future<void>? providerDisconnectGate;

  /// Optional gate used to keep MCP discovery in its loading state.
  final Future<void>? mcpListGate;

  /// Optional gate used to hold plugin catalog loading in widget tests.
  final Future<void>? pluginListGate;

  /// Daemon-side directory tree keyed by parent path.
  final Map<String, List<String>> directories;

  /// Optional gate used to order concurrent directory listings.
  final Future<void>? suggestDirectoriesGate;

  /// Optional daemon failure returned while creating a worktree.
  ///
  /// Mutable so a test can clear it and assert that a failed submission left
  /// the composer usable for the retry.
  TinestClientException? createWorktreeError;

  /// Optional gate used to keep a worktree creation pending.
  Completer<void>? createWorktreeGate;

  /// Optional daemon failure returned while listing directories.
  final TinestClientException? suggestDirectoriesError;

  /// Directory queries received by the fake, in call order.
  final List<String> suggestedQueries = <String>[];

  /// Worktree-relative file paths keyed by worktree ID.
  final Map<String, List<String>> files;

  /// Agent commands the daemon offers.
  final List<AgentCommandDto> commands;

  /// Optional gate used to keep a file search in its loading state.
  final Future<void>? searchFilesGate;

  /// Optional daemon failure returned while searching files.
  final TinestClientException? searchFilesError;

  /// File search queries received by the fake, in call order.
  final List<String> searchedQueries = <String>[];

  /// Worktree creations recorded by the fake.
  final List<
    ({
      WorktreeCreateMode mode,
      String branchName,
      String? baseBranch,
      WorktreeBranchNaming branchNaming,
    })
  >
  createdWorktrees =
      <
        ({
          WorktreeCreateMode mode,
          String branchName,
          String? baseBranch,
          WorktreeBranchNaming branchNaming,
        })
      >[];

  /// Workspace IDs whose Git branches were requested.
  final List<String> listedGitBranchWorkspaceIds = <String>[];
  final StreamController<ClientEvent> _events =
      StreamController<ClientEvent>.broadcast(sync: true);
  final StreamController<ClientConnectionState> _states =
      StreamController<ClientConnectionState>.broadcast(sync: true);
  final StreamController<ProviderCatalogDto> _catalogUpdates =
      StreamController<ProviderCatalogDto>.broadcast(sync: true);
  bool _closed = false;

  /// Whether [close] released this fake client.
  bool get isClosed => _closed;

  @override
  Stream<ProviderCatalogDto> get catalogUpdates => _catalogUpdates.stream;

  /// Paths registered through the fake, in call order.
  final List<String> registeredPaths = <String>[];

  /// Sessions created through the fake, in creation order.
  final List<SessionDto> createdSessions = <SessionDto>[];

  /// Session model overrides written through the fake.
  final List<({String sessionId, ModelSelectionDto? model})>
  updatedSessionModels = <({String sessionId, ModelSelectionDto? model})>[];

  /// Session reasoning effort overrides written through the fake.
  final List<({String sessionId, String? reasoningEffort})>
  updatedSessionReasoningEfforts =
      <({String sessionId, String? reasoningEffort})>[];

  /// Session permission modes written through the fake.
  final List<({String sessionId, PermissionMode permissionMode})>
  updatedSessionPermissionModes =
      <({String sessionId, PermissionMode permissionMode})>[];

  /// Session service tier selections written through the fake.
  final List<({String sessionId, String? serviceTier})>
  updatedSessionServiceTiers = <({String sessionId, String? serviceTier})>[];

  /// Turn prompts received by the fake.
  final List<String> startedPrompts = <String>[];

  /// Turn identifiers received by the fake.
  final List<String> startedTurnIds = <String>[];

  /// Ordered attachment IDs received by each started turn.
  final List<List<String>> startedAttachmentIds = <List<String>>[];

  final Map<String, ({AttachmentDto metadata, Uint8List bytes})> _attachments =
      <String, ({AttachmentDto metadata, Uint8List bytes})>{};

  /// Agent identifiers cancelled through the fake.
  final List<String> cancelledAgents = <String>[];

  /// Provider credentials written through the fake.
  final Map<String, String> credentials = <String, String>{};

  /// OAuth attempts cancelled through the fake.
  final List<String> cancelledAuthAttempts = <String>[];

  /// Approval decisions received by the fake.
  /// Answers submitted through [answerUserQuestion], in order.
  final List<({String id, List<UserQuestionAnswerDto> answers})>
  questionAnswers = <({String id, List<UserQuestionAnswerDto> answers})>[];

  /// Holds an answer request in flight until a test releases it.
  Completer<void>? questionAnswerGate;

  /// Error thrown after a question answer is recorded.
  Exception? questionAnswerError;

  final List<({String id, bool approved})> approvalDecisions =
      <({String id, bool approved})>[];

  /// Thrown instead of starting a turn, so a caller's rollback can be checked.
  Exception? startTurnError;

  /// Awaited before a session is created, so pending catalog state is visible.
  Completer<void>? sessionCreateGate;

  /// Thrown instead of creating a session.
  Exception? sessionCreateError;

  /// Prompts [startTurn] was called with, recorded before it can throw.
  ///
  /// [startedPrompts] only records what succeeded, so a retry bound has to be
  /// counted here or a failing send looks like no send at all.
  final List<String> attemptedPrompts = <String>[];

  /// Number of leading [startTurn] calls that fail before one is allowed.
  ///
  /// Separate from [startTurnError], which fails every call, so a test can
  /// distinguish "recovers on retry" from "never recovers".
  int startTurnFailures = 0;

  /// Awaited before a turn starts, to hold one send in flight.
  Completer<void>? startTurnGate;

  /// Whether [startTurn] emits the session-running notification.
  ///
  /// Tests that need to hold a session in its busy state can opt in without
  /// suppressing the durable user-message echo below.
  bool emitTurnStartEvents = false;

  /// Whether a successful turn emits its durable user-message echo.
  ///
  /// The real daemon writes this event for every accepted turn. Keeping it
  /// enabled by default makes widget tests exercise the same optimistic
  /// message lifecycle as the production client.
  bool emitUserMessageEcho = true;

  /// Thrown instead of noting pending input.
  Exception? notePendingInputError;

  /// Number of leading [listSessions] calls that fail before one succeeds.
  int listSessionsFailures = 0;

  /// Thrown instead of writing a session turn setting.
  Exception? sessionUpdateError;

  /// Awaited before a session turn setting is written.
  ///
  /// Lets a test observe the state a caller shows while the write is in
  /// flight, rather than only its settled result.
  Completer<void>? sessionUpdateGate;

  Future<void> _beforeSessionUpdate() async {
    final gate = sessionUpdateGate;
    if (gate != null) await gate.future;
    final error = sessionUpdateError;
    if (error != null) throw error;
  }

  /// Emits a typed daemon notification.
  ///
  /// A session update also lands in the stored sessions, so a later
  /// [listSessions] agrees with what subscribers were told.
  void emit(ClientEvent event) {
    if (event is SessionUpdatedClientEvent) {
      final index = _agents.indexWhere((agent) => agent.id == event.session.id);
      if (index >= 0) _agents[index] = event.session;
    }
    _events.add(event);
  }

  /// Replaces one descriptor and emits the app-data watcher notification.
  void emitPluginChange(PluginDescriptorDto plugin) {
    final index = _plugins.indexWhere((candidate) => candidate.id == plugin.id);
    if (index < 0) {
      _plugins.add(plugin);
    } else {
      _plugins[index] = plugin;
    }
    emit(const PluginsChangedClientEvent());
  }

  /// Appends and broadcasts one timeline event for a session.
  ///
  /// [turnId] defaults to a single fixture turn. The daemon stamps the turn id
  /// the client supplied onto every event of that turn, so anything echoing a
  /// started turn has to pass the id it was actually given.
  void emitTimeline(
    String sessionId,
    String type,
    Map<String, dynamic> data, {
    String turnId = 'turn-1',
  }) {
    final events = _timelines.putIfAbsent(
      sessionId,
      () => <TimelineEventDto>[],
    );
    final event = TimelineEventDto(
      sessionId: sessionId,
      sequence: events.length + 1,
      turnId: turnId,
      type: type,
      data: data,
      createdAt: _now,
    );
    events.add(event);
    emit(TimelineClientEvent(event));
  }

  /// Stores timeline events without announcing them.
  ///
  /// Models delivery a subscriber missed: the daemon wrote the rows and will
  /// answer for them as history, but no notification for them ever arrived.
  void storeTimelineUnannounced(
    String sessionId,
    List<TimelineEventDto> events,
  ) => _timelines
      .putIfAbsent(sessionId, () => <TimelineEventDto>[])
      .addAll(events);

  /// Emits a transport connection state.
  void emitState(ClientConnectionState state) => _states.add(state);

  Stream<ClientEvent> get events => eventStream ?? _events.stream;

  @override
  Stream<ClientConnectionState> get states => _states.stream;

  @override
  WorkspacesApi get workspaces => this;

  @override
  SessionsApi get sessions => this;

  @override
  AgentsApi get agents => this;

  @override
  PluginsApi get plugins => this;

  @override
  PromptsApi get prompts => this;

  @override
  ModelsApi get models => this;

  @override
  ProvidersApi get providers => this;

  @override
  McpApi get mcp => this;

  @override
  TerminalsApi get terminals => this;

  @override
  AttachmentsApi get attachments => this;

  @override
  RelayApi get relay => this;

  @override
  Stream<RelayStatusDto> get statusUpdates =>
      const Stream<RelayStatusDto>.empty();

  @override
  Future<RelayStatusDto> getRelayStatus() async => RelayStatusDto(
    enabled: relayEnabled,
    connected: false,
    endpoint: relayEndpoint,
    serverId: serverInfo.serverId,
  );

  @override
  Future<RelayStatusDto> setRelayEnabled({required bool enabled}) async {
    relayEnabled = enabled;
    return RelayStatusDto(
      enabled: enabled,
      connected: false,
      endpoint: relayEndpoint,
      serverId: serverInfo.serverId,
    );
  }

  @override
  Future<RelayStatusDto> setRelayEndpoint(String endpoint) async {
    relayEndpoint = endpoint;
    return RelayStatusDto(
      enabled: relayEnabled,
      connected: false,
      endpoint: endpoint,
      serverId: serverInfo.serverId,
    );
  }

  @override
  Future<RelayPairingOfferDto> createRelayPairingOffer() async =>
      relayPairingOffer ??
      (throw StateError('No relay pairing offer configured for this fake.'));

  @override
  Future<List<RelayDeviceDto>> listRelayDevices() async {
    await listRelayDevicesGate;
    return List<RelayDeviceDto>.unmodifiable(relayDevices);
  }

  /// Optional gate used to keep the approved-device list loading.
  Future<void>? listRelayDevicesGate;

  @override
  Future<void> revokeRelayDevice(String deviceId) async {
    revokedRelayDeviceIds.add(deviceId);
    relayDevices.removeWhere((device) => device.id == deviceId);
  }

  @override
  Stream<SessionDto> get sessionUpdates => events
      .whereType<SessionUpdatedClientEvent>()
      .map((event) => event.session);

  @override
  Stream<TimelineEventDto> get timelineEvents =>
      events.whereType<TimelineClientEvent>().map((event) => event.event);

  @override
  Stream<ApprovalRequestDto> get approvalRequests => events
      .whereType<ApprovalRequestedClientEvent>()
      .map((event) => event.approval);

  @override
  Stream<UserQuestionRequestDto> get questionRequests => events
      .whereType<UserQuestionRequestedClientEvent>()
      .map((event) => event.request);

  @override
  Stream<void> get definitionChanges =>
      events.whereType<AgentDefinitionsChangedClientEvent>().map((_) {});

  @override
  Stream<void> get pluginChanges =>
      events.whereType<PluginsChangedClientEvent>().map((_) {});

  @override
  Stream<void> get skillChanges =>
      events.whereType<SkillsChangedClientEvent>().map((_) {});

  @override
  Stream<void> get commandChanges =>
      events.whereType<CommandsChangedClientEvent>().map((_) {});

  @override
  Stream<ProviderAuthAttemptDto> get authUpdates => events
      .whereType<ProviderAuthUpdatedClientEvent>()
      .map((event) => event.attempt);

  @override
  Stream<void> get serverChanges =>
      events.whereType<McpServersChangedClientEvent>().map((_) {});

  @override
  Stream<TerminalOutputDto> get output => events
      .whereType<TerminalOutputClientEvent>()
      .map((event) => event.output);

  @override
  Stream<TerminalDto> get terminalUpdates => events
      .whereType<TerminalUpdatedClientEvent>()
      .map((event) => event.terminal);

  @override
  ServerInfoDto get serverInfo => _serverInfo;

  @override
  Future<WorkspaceCatalogDto> getWorkspaceCatalog() async {
    workspaceCatalogCount += 1;
    await workspaceCatalogGate;
    if (workspaceCatalogError case final error?) throw error;
    if (workspaceCatalogResponses.isNotEmpty) {
      return workspaceCatalogResponses.removeAt(0);
    }
    return WorkspaceCatalogDto(
      workspaces: List<WorkspaceDto>.unmodifiable(_workspaces),
      worktrees: List<WorktreeDto>.unmodifiable(_worktrees),
    );
  }

  @override
  Future<WorkspaceRegisterResultDto> registerWorkspace({
    required String workspaceId,
    required String checkoutId,
    required String rootPath,
    required String name,
  }) async {
    registeredPaths.add(rootPath);
    if (registerWorkspaceGate case final gate?) await gate.future;
    final workspace = WorkspaceDto(
      id: workspaceId,
      name: name,
      rootPath: rootPath,
      kind: WorkspaceKind.directory,
      createdAt: _now,
    );
    final worktree = WorktreeDto(
      id: checkoutId,
      workspaceId: workspace.id,
      name: name,
      path: rootPath,
      kind: WorktreeKind.directory,
      isTinestOwned: false,
      createdAt: _now,
    );
    _workspaces.add(workspace);
    _worktrees.add(worktree);
    return WorkspaceRegisterResultDto(
      workspace: workspace,
      worktrees: <WorktreeDto>[worktree],
    );
  }

  @override
  Future<WorkspaceCatalogDto> refreshWorkspace(String workspaceId) =>
      getWorkspaceCatalog();

  @override
  Future<void> unregisterWorkspace(String workspaceId) async {
    _workspaces.removeWhere((item) => item.id == workspaceId);
    _worktrees.removeWhere((item) => item.workspaceId == workspaceId);
  }

  @override
  Future<List<DirectorySuggestionDto>> suggestDirectories(
    String query, {
    int limit = 30,
  }) async {
    suggestedQueries.add(query);
    await suggestDirectoriesGate;
    final failure = suggestDirectoriesError;
    if (failure != null) throw failure;
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const <DirectorySuggestionDto>[];
    // Mirrors the daemon: an existing directory lists its children, anything
    // else filters the siblings of the typed basename.
    final children = directories[trimmed];
    if (children != null) return _entries(children);
    final separator = trimmed.lastIndexOf('/');
    if (separator < 0) return const <DirectorySuggestionDto>[];
    final parent = separator == 0 ? '/' : trimmed.substring(0, separator);
    final needle = trimmed.substring(separator + 1).toLowerCase();
    final siblings = directories[parent] ?? const <String>[];
    return _entries(
      siblings
          .where((path) => _basename(path).toLowerCase().contains(needle))
          .toList(growable: false),
    );
  }

  List<DirectorySuggestionDto> _entries(List<String> paths) => paths
      .map((path) => DirectorySuggestionDto(path: path, name: _basename(path)))
      .toList(growable: false);

  static String _basename(String path) =>
      path.split('/').where((part) => part.isNotEmpty).lastOrNull ?? path;

  @override
  Future<List<GitBranchDto>> listGitBranches(String workspaceId) async {
    listedGitBranchWorkspaceIds.add(workspaceId);
    if (gitBranchesGate case final gate?) await gate.future;
    if (gitBranchesError case final error?) throw error;
    return branches;
  }

  /// Branches reported for every workspace.
  List<GitBranchDto> branches = const <GitBranchDto>[
    GitBranchDto(name: 'main', current: true, checkedOut: true),
    GitBranchDto(name: 'feature', current: false, checkedOut: false),
    GitBranchDto(
      name: 'origin/main',
      current: false,
      checkedOut: false,
      isRemote: true,
      isDefault: true,
    ),
  ];

  /// Project settings keyed by workspace ID.
  final Map<String, ProjectSettingsDto> projectSettings =
      <String, ProjectSettingsDto>{};

  /// Error returned while loading project settings.
  Exception? projectSettingsError;

  /// Number of project settings load attempts.
  int projectSettingsLoadCount = 0;

  /// Hook runs reported by the next worktree create call.
  List<WorktreeHookRunDto> createWorktreeHookRuns =
      const <WorktreeHookRunDto>[];

  /// Hook runs reported by the next worktree archive call.
  List<WorktreeHookRunDto> archiveWorktreeHookRuns =
      const <WorktreeHookRunDto>[];

  /// Holds an archive open, so a test can unmount the caller mid-flight.
  Completer<void>? archiveWorktreeGate;

  @override
  Future<ProjectSettingsResultDto> getProjectSettings(
    String workspaceId,
  ) async {
    projectSettingsLoadCount += 1;
    if (projectSettingsError case final error?) throw error;
    return ProjectSettingsResultDto(
      settings: projectSettings[workspaceId] ?? const ProjectSettingsDto(),
      sourcePath: '/projects/$workspaceId/.tinest/config.json',
    );
  }

  @override
  Future<ProjectSettingsResultDto> saveProjectSettings(
    String workspaceId,
    ProjectSettingsDto settings,
  ) async {
    projectSettings[workspaceId] = settings;
    return getProjectSettings(workspaceId);
  }

  @override
  Future<WorktreeResultDto> createWorktree({
    required String id,
    required String workspaceId,
    required WorktreeCreateMode mode,
    required String branchName,
    String? baseBranch,
    WorktreeBranchNaming branchNaming = WorktreeBranchNaming.exact,
  }) async {
    if (createWorktreeGate case final gate?) await gate.future;
    final failure = createWorktreeError;
    if (failure != null) throw failure;
    createdWorktrees.add((
      mode: mode,
      branchName: branchName,
      baseBranch: baseBranch,
      branchNaming: branchNaming,
    ));
    final worktree = WorktreeDto(
      id: id,
      workspaceId: workspaceId,
      name: branchName,
      path: '/worktrees/$branchName',
      branch: branchName,
      kind: WorktreeKind.linked,
      isTinestOwned: true,
      createdAt: _now,
    );
    _worktrees.add(worktree);
    return WorktreeResultDto(
      worktree: worktree,
      hookRuns: createWorktreeHookRuns,
    );
  }

  @override
  Future<WorktreeArchivePreviewDto> previewWorktreeArchive(
    String worktreeId,
  ) async {
    if (previewArchiveGate case final gate?) await gate.future;
    if (previewArchiveError case final error?) throw error;
    return WorktreeArchivePreviewDto(
      worktreeId: worktreeId,
      dirty: false,
      unpushedCommitCount: 0,
      runningSessionCount: 0,
      removesDirectory: true,
    );
  }

  @override
  Future<WorktreeResultDto> archiveWorktree(
    String worktreeId, {
    bool force = false,
  }) async {
    if (archiveWorktreeGate case final gate?) await gate.future;
    if (archiveWorktreeError case final error?) throw error;
    final index = _worktrees.indexWhere((item) => item.id == worktreeId);
    final archived = _worktrees[index].copyWith(archivedAt: _now);
    _worktrees.removeAt(index);
    return WorktreeResultDto(
      worktree: archived,
      hookRuns: archiveWorktreeHookRuns,
    );
  }

  @override
  Future<List<SessionDto>> listSessions({String? worktreeId}) async {
    listSessionsCount += 1;
    await listSessionsGate;
    if (listSessionsFailures > 0) {
      listSessionsFailures -= 1;
      throw Exception('transient listSessions failure');
    }
    return _agents
        .where((agent) => worktreeId == null || agent.worktreeId == worktreeId)
        .toList(growable: false);
  }

  @override
  Future<List<SessionDto>> listSubagents(String sessionId) async {
    final session = _agents.firstWhere(
      (agent) => agent.id == sessionId,
      orElse: () => throw StateError('Session not found: $sessionId'),
    );
    final rootId = session.rootSessionId ?? session.id;
    return _agents
        .where(
          (agent) => agent.id == rootId || agent.rootSessionId == rootId,
        )
        .toList(growable: false)
      ..sort(
        (left, right) =>
            (left.agentPath ?? '').compareTo(right.agentPath ?? ''),
      );
  }

  @override
  Future<SessionDto> createSession({
    required String id,
    required String worktreeId,
    required String title,
    required String agentDefinitionId,
    ModelSelectionDto? model,
    Map<String, ModelControlValueDto> modelControls =
        const <String, ModelControlValueDto>{},
    PermissionMode? permissionMode,
  }) async {
    final gate = sessionCreateGate;
    if (gate != null) await gate.future;
    final error = sessionCreateError;
    if (error != null) throw error;
    final agent = SessionDto(
      id: id,
      worktreeId: worktreeId,
      title: title,
      agentDefinitionId: agentDefinitionId,
      origin: SessionOrigin.manual,
      status: SessionStatus.idle,
      model: model,
      modelControls: modelControls,
      // Like the daemon, an omitted mode is resolved once, here, so the
      // session owns a concrete mode from the start.
      permissionMode: permissionMode ?? _defaultPermissionMode,
      createdAt: _now,
      updatedAt: _now,
    );
    _agents.add(agent);
    createdSessions.add(agent);
    return agent;
  }

  @override
  Future<SessionDto> updateSettings(
    String sessionId,
    SessionSettingsPatchDto patch,
  ) async {
    await _beforeSessionUpdate();
    final index = _agents.indexWhere((agent) => agent.id == sessionId);
    if (index < 0) throw StateError('Session not found: $sessionId');
    var updated = _agents[index];
    if (patch.hasModel) {
      updatedSessionModels.add((sessionId: sessionId, model: patch.model));
      updated = updated.copyWith(model: patch.model);
    }
    if (patch.hasModelControls) {
      final controls = patch.modelControls;
      final effort = controls['reasoning_effort']?.map(
        stringValue: (value) => value.value,
        boolValue: (_) => null,
        intValue: (_) => null,
      );
      updatedSessionReasoningEfforts.add((
        sessionId: sessionId,
        reasoningEffort: effort,
      ));
      final fast = controls['fast_mode']?.map(
        stringValue: (_) => false,
        boolValue: (value) => value.value,
        intValue: (_) => false,
      );
      updatedSessionServiceTiers.add((
        sessionId: sessionId,
        serviceTier: fast == true ? 'priority' : null,
      ));
      updated = updated.copyWith(modelControls: controls);
    }
    if (patch.permissionMode case final mode?) {
      if (sessionPermissionSetError case final error?) throw error;
      updatedSessionPermissionModes.add((
        sessionId: sessionId,
        permissionMode: mode,
      ));
      updated = updated.copyWith(permissionMode: mode);
    }
    _agents[index] = updated;
    emit(SessionUpdatedClientEvent(updated));
    return updated;
  }

  @override
  Future<PermissionSettingsDto> getDefaultPermissionMode() async {
    await permissionSettingsGate;
    return PermissionSettingsDto(defaultMode: _defaultPermissionMode);
  }

  @override
  Future<PermissionSettingsDto> setDefaultPermissionMode(
    PermissionMode permissionMode,
  ) async {
    if (defaultPermissionSetError case final error?) throw error;
    _defaultPermissionMode = permissionMode;
    return PermissionSettingsDto(defaultMode: permissionMode);
  }

  @override
  Future<List<TerminalDto>> listTerminals(String worktreeId) async {
    listTerminalsCount += 1;
    await listTerminalsGate;
    return _terminals.where((item) => item.worktreeId == worktreeId).toList();
  }

  @override
  Future<TerminalDto> createTerminal({
    required String id,
    required String worktreeId,
    required String title,
    required int columns,
    required int rows,
  }) async {
    if (terminalCreateGate case final gate?) await gate.future;
    if (terminalCreateError case final error?) throw error;
    final terminal = TerminalDto(
      id: id,
      worktreeId: worktreeId,
      title: title,
      shell: const ShellSpecDto(executable: '/bin/sh'),
      status: TerminalStatus.running,
      columns: columns,
      rows: rows,
      lastSequence: 0,
    );
    _terminals.add(terminal);
    emit(TerminalUpdatedClientEvent(terminal));
    return terminal;
  }

  @override
  Future<TerminalAttachResultDto> attachTerminal(
    String terminalId, {
    required TerminalRestoreMode mode,
    int afterSequence = 0,
    int scrollbackLines = terminalRestoreScrollbackLines,
    TerminalViewportDto? viewport,
  }) async {
    attachedTerminalRequests.add((
      terminalId: terminalId,
      mode: mode,
      afterSequence: afterSequence,
      scrollbackLines: scrollbackLines,
      viewport: viewport,
    ));
    // A viewport claim lands before anything is read, so what the restore
    // describes is already at the geometry the caller asked for.
    if (viewport != null) {
      final index = _terminals.indexWhere((item) => item.id == terminalId);
      _terminals[index] = _terminals[index].copyWith(
        columns: viewport.columns,
        rows: viewport.rows,
      );
    }
    // The daemon decides the restore when the call arrives, not when the caller
    // finally sees the response, so anything published while the round trip is
    // in flight reaches subscribers only as a live notification.
    final retained = _replayFor(terminalId);
    final floor = terminalDeltaFloors[terminalId] ?? 0;
    final resumable =
        mode == TerminalRestoreMode.resume && afterSequence >= floor;
    final restore = resumable
        ? TerminalRestoreDto.delta(
            afterSequence: afterSequence,
            chunks: retained
                .where((output) => output.sequence > afterSequence)
                .toList(growable: false),
          )
        : TerminalRestoreDto.snapshot(
            throughSequence: retained.isEmpty ? 0 : retained.last.sequence,
            ansi:
                terminalSnapshotAnsi[terminalId] ??
                retained.map((output) => output.data).join(),
          );
    if (terminalAttachGate case final gate?) await gate.future;
    final error = terminalAttachError;
    if (error != null) throw error;
    attachedTerminalIds.add(terminalId);
    return TerminalAttachResultDto(
      terminal: _terminals.firstWhere((item) => item.id == terminalId),
      restore: restore,
    );
  }

  /// Resizes a terminal the way another client would, without an RPC.
  void resizeTerminalDirectly(
    String terminalId, {
    required int columns,
    required int rows,
  }) {
    final index = _terminals.indexWhere((item) => item.id == terminalId);
    _terminals[index] = _terminals[index].copyWith(
      columns: columns,
      rows: rows,
    );
  }

  /// Sequence below which a terminal can no longer be resumed.
  ///
  /// Mirrors the daemon dropping retained output: a cursor at or under the
  /// floor gets a rebuilt screen instead of a delta.
  final Map<String, int> terminalDeltaFloors = <String, int>{};

  /// ANSI a rebuilt screen carries, when a test needs to assert on it.
  final Map<String, String> terminalSnapshotAnsi = <String, String>{};

  /// Appends one output chunk to a terminal's scrollback and broadcasts it.
  ///
  /// The sequence is assigned the way the daemon assigns it, so a later attach
  /// replays exactly what a subscriber that missed the notification needs.
  TerminalOutputDto emitTerminalOutput(String terminalId, String data) {
    final replay = _replayFor(terminalId);
    final output = TerminalOutputDto(
      terminalId: terminalId,
      sequence: replay.isEmpty ? 1 : replay.last.sequence + 1,
      data: data,
    );
    replay.add(output);
    emit(TerminalOutputClientEvent(output));
    return output;
  }

  List<TerminalOutputDto> _replayFor(String terminalId) =>
      _terminalReplays.putIfAbsent(terminalId, () => <TerminalOutputDto>[]);

  /// Terminals attached to, in order, including repeat attachments.
  final List<String> attachedTerminalIds = <String>[];

  /// Attach requests received, in order, with everything they claimed.
  final List<
    ({
      String terminalId,
      TerminalRestoreMode mode,
      int afterSequence,
      int scrollbackLines,
      TerminalViewportDto? viewport,
    })
  >
  attachedTerminalRequests =
      <
        ({
          String terminalId,
          TerminalRestoreMode mode,
          int afterSequence,
          int scrollbackLines,
          TerminalViewportDto? viewport,
        })
      >[];

  /// Optional gate used to keep a terminal attachment pending.
  Completer<void>? terminalAttachGate;

  /// Terminal input received by the fake.
  final List<({String terminalId, String data})> terminalWrites =
      <({String terminalId, String data})>[];

  /// Terminal viewport sizes received by the fake.
  final List<({String terminalId, int columns, int rows})> terminalResizes =
      <({String terminalId, int columns, int rows})>[];

  @override
  Future<void> writeTerminal(String terminalId, String data) async {
    terminalWrites.add((terminalId: terminalId, data: data));
  }

  @override
  Future<TerminalDto> resizeTerminal(
    String terminalId, {
    required int columns,
    required int rows,
  }) async {
    terminalResizes.add((
      terminalId: terminalId,
      columns: columns,
      rows: rows,
    ));
    final index = _terminals.indexWhere((item) => item.id == terminalId);
    final terminal = _terminals[index].copyWith(columns: columns, rows: rows);
    _terminals[index] = terminal;
    return terminal;
  }

  @override
  Future<void> terminateTerminal(String terminalId) async {
    final index = _terminals.indexWhere((item) => item.id == terminalId);
    final terminal = _terminals[index].copyWith(
      status: TerminalStatus.exited,
      exitCode: 0,
    );
    _terminals[index] = terminal;
    emit(TerminalUpdatedClientEvent(terminal));
  }

  @override
  Future<ShellSpecDto?> getTerminalShell() async {
    await terminalShellGate;
    return _terminalShell;
  }

  @override
  Future<void> setTerminalShell(ShellSpecDto? shell) async {
    _terminalShell = shell;
  }

  @override
  Future<List<AgentDefinitionDto>> listAgentDefinitions() async {
    agentDefinitionsListCount += 1;
    await agentDefinitionsGate;
    final error = agentListError;
    if (error != null) throw error;
    return List<AgentDefinitionDto>.unmodifiable(_agentDefinitions);
  }

  @override
  Future<AgentDefinitionDto> getAgentDefinition(String id) async =>
      _agentDefinitions.singleWhere((definition) => definition.id == id);

  @override
  Future<AgentDefinitionDto> createAgentDefinition(
    String id,
    AgentDefinitionDto definition,
  ) async {
    if (failNextAgentCreate) {
      failNextAgentCreate = false;
      throw Exception('agent_create_failed');
    }
    if (_agentDefinitions.any((item) => item.id == id)) {
      throw StateError('Agent definition already exists: $id');
    }
    final created = definition.copyWith(
      id: id,
      contentHash: '$id-hash',
      sourcePath: '/config/agents/$id.md',
    );
    _agentDefinitions.add(created);
    return created;
  }

  @override
  Future<AgentDefinitionDto> updateAgentDefinition(
    AgentDefinitionDto definition, {
    required String expectedContentHash,
    bool force = false,
  }) async {
    await agentUpdateGate;
    if (failNextAgentUpdate && !force) {
      failNextAgentUpdate = false;
      throw Exception('agent_file_conflict');
    }
    final index = _agentDefinitions.indexWhere(
      (item) => item.id == definition.id,
    );
    if (!force && _agentDefinitions[index].contentHash != expectedContentHash) {
      throw StateError('agent_file_conflict');
    }
    final updated = definition.copyWith(
      contentHash: '${definition.id}-updated-hash',
    );
    _agentDefinitions[index] = updated;
    return updated;
  }

  @override
  Future<void> archiveAgentDefinition(String id) async {
    _agentDefinitions.removeWhere((definition) => definition.id == id);
  }

  @override
  Future<AgentDefinitionDto> resetAgentDefinition(String id) async {
    if (id != 'tinest') throw StateError('Only tinest can be reset.');
    final index = _agentDefinitions.indexWhere(
      (definition) => definition.id == id,
    );
    _agentDefinitions[index] = _tinest;
    return _tinest;
  }

  @override
  Future<AgentDefinitionDto> validateAgentDefinition(
    String id,
    String markdown,
  ) async => _tinest.copyWith(id: id, prompt: markdown);

  @override
  Future<List<AgentToolDefinitionDto>> listAgentTools({
    String? worktreeId,
  }) async => const <AgentToolDefinitionDto>[
    AgentToolDefinitionDto(
      id: 'tinest.files/read_file',
      originPluginId: 'tinest.files',
      contributionId: 'read_file',
      name: 'read_file',
      description: 'Read a file.',
      risk: ToolRisk.read,
      group: 'filesystem',
      kind: AgentToolKind.function,
      inputSchema: <String, dynamic>{'type': 'object'},
      effects: <String>['filesystem.read'],
      presentation: <String, dynamic>{'group': 'filesystem'},
    ),
    AgentToolDefinitionDto(
      id: 'tinest.terminal/exec_command',
      originPluginId: 'tinest.terminal',
      contributionId: 'exec_command',
      name: 'exec_command',
      description: 'Run a command in a pseudo-terminal.',
      risk: ToolRisk.command,
      group: 'execution',
      kind: AgentToolKind.function,
      inputSchema: <String, dynamic>{'type': 'object'},
      effects: <String>['process.execute'],
      presentation: <String, dynamic>{'group': 'execution'},
    ),
    // Three of one group, so a test can tell a whole-group toggle from a
    // per-tool one and see the header report a partial selection.
    AgentToolDefinitionDto(
      id: 'tinest.mcp/list_mcp_resources',
      originPluginId: 'tinest.mcp',
      contributionId: 'list_mcp_resources',
      name: 'list_mcp_resources',
      description: 'List MCP resources.',
      risk: ToolRisk.read,
      group: 'mcp',
      kind: AgentToolKind.function,
      inputSchema: <String, dynamic>{'type': 'object'},
      effects: <String>['mcp.read'],
      presentation: <String, dynamic>{'group': 'mcp'},
    ),
    AgentToolDefinitionDto(
      id: 'tinest.mcp/list_mcp_resource_templates',
      originPluginId: 'tinest.mcp',
      contributionId: 'list_mcp_resource_templates',
      name: 'list_mcp_resource_templates',
      description: 'List MCP resource templates.',
      risk: ToolRisk.read,
      group: 'mcp',
      kind: AgentToolKind.function,
      inputSchema: <String, dynamic>{'type': 'object'},
      effects: <String>['mcp.read'],
      presentation: <String, dynamic>{'group': 'mcp'},
    ),
    AgentToolDefinitionDto(
      id: 'tinest.mcp/read_mcp_resource',
      originPluginId: 'tinest.mcp',
      contributionId: 'read_mcp_resource',
      name: 'read_mcp_resource',
      description: 'Read one MCP resource.',
      risk: ToolRisk.read,
      group: 'mcp',
      kind: AgentToolKind.function,
      inputSchema: <String, dynamic>{'type': 'object'},
      effects: <String>['mcp.read'],
      presentation: <String, dynamic>{'group': 'mcp'},
    ),
  ];

  @override
  Future<List<PluginDescriptorDto>> listPlugins() async {
    await pluginListGate;
    return List<PluginDescriptorDto>.unmodifiable(_plugins);
  }

  @override
  Future<PluginDescriptorDto> getPlugin(String id) async =>
      _plugins.singleWhere((plugin) => plugin.id == id);

  @override
  Future<PluginDescriptorDto> validatePlugin(String id) async => getPlugin(id);

  @override
  Future<PluginDescriptorDto> reloadPlugin(String id, String agentId) async {
    reloadedPlugins.add((pluginId: id, agentId: agentId));
    return getPlugin(id);
  }

  @override
  Future<PluginDescriptorDto> scaffoldPlugin(String id, String name) async {
    if (_plugins.any((plugin) => plugin.id == id)) {
      throw StateError('Plugin already exists: $id');
    }
    final plugin = PluginDescriptorDto(
      apiMajor: 5,
      id: id,
      version: '0.1.0',
      name: name,
      entrypoint: 'main.lua',
      source: PluginSource.user,
      sourcePath: '/config/v5/plugins/$id',
      requestedCapabilities: const <String>[],
      revision: PluginRevisionDto(
        pluginId: id,
        contentHash: '$id-revision',
        manifestHash: '$id-manifest',
        sdkAbiHash: 'sdk-abi-hash',
        executionRevisionHash: '$id-execution-revision',
        requestedCapabilities: const <String>[],
      ),
    );
    _plugins.add(plugin);
    return plugin;
  }

  @override
  Future<PluginDescriptorDto> forkPlugin({
    required String sourceId,
    required String id,
    required String name,
  }) async {
    forkedPlugins.add((sourceId, id, name));
    final source = await getPlugin(sourceId);
    final plugin = source.copyWith(
      id: id,
      name: name,
      source: PluginSource.user,
      sourcePath: '/config/v5/plugins/$id',
      revision: source.revision?.copyWith(pluginId: id),
      contributions: const <PluginContributionDto>[],
      diagnostics: const <PluginDiagnosticDto>[],
      isStale: false,
    );
    _plugins.add(plugin);
    return plugin;
  }

  @override
  Future<PluginAuthoringEnvironmentDto> getPluginAuthoringEnvironment(
    String id,
  ) async =>
      pluginAuthoringEnvironments[id] ?? _defaultAuthoringEnvironment(id);

  @override
  Future<PluginAuthoringEnvironmentDto> syncPluginAuthoringEnvironment(
    String id,
  ) async {
    final environment = _defaultAuthoringEnvironment(id);
    pluginAuthoringEnvironments[id] = environment;
    return environment;
  }

  PluginAuthoringEnvironmentDto _defaultAuthoringEnvironment(String id) {
    final plugin = _plugins.singleWhere((candidate) => candidate.id == id);
    final abi = plugin.revision?.sdkAbiHash ?? 'sdk-abi-hash';
    return PluginAuthoringEnvironmentDto(
      pluginId: id,
      apiMajor: plugin.apiMajor,
      sdkAbiHash: abi,
      luaRuntimeVersion: '5.5.1',
      luaLanguageServerVersion: '3.18.2',
      pluginPath: plugin.sourcePath,
      sdkLibraryPath: '/config/v5/plugin-sdk/api-5/$abi/library',
      configurationPath: '${plugin.sourcePath}/.luarc.json',
      synchronized: true,
    );
  }

  @override
  Future<void> setPluginSecret({
    required String agentId,
    required String pluginId,
    required String name,
    required String value,
  }) async {
    pluginSecrets['$agentId/$pluginId/$name'] = value;
  }

  @override
  Future<void> removePluginSecret({
    required String agentId,
    required String pluginId,
    required String name,
  }) async {
    pluginSecrets.remove('$agentId/$pluginId/$name');
  }

  @override
  Future<List<AgentPluginGrantDto>> listPluginGrants(String agentId) async =>
      _pluginGrants
          .where((grant) => grant.agentId == agentId)
          .toList(growable: false);

  @override
  Future<List<AgentPluginGrantDto>> grantPluginCapability(
    AgentPluginGrantDto grant,
  ) async {
    if (!_pluginGrants.contains(grant)) _pluginGrants.add(grant);
    return listPluginGrants(grant.agentId);
  }

  @override
  Future<List<AgentPluginGrantDto>> revokePluginCapability(
    AgentPluginGrantDto grant,
  ) async {
    _pluginGrants.remove(grant);
    return listPluginGrants(grant.agentId);
  }

  @override
  Future<PluginSessionControlValueDto> getPluginSessionControl({
    required String sessionId,
    required String pluginId,
    required String contributionId,
  }) async {
    final key = '$sessionId/$pluginId/$contributionId';
    return pluginSessionControls[key] ??
        (throw StateError('Plugin session control is not configured: $key'));
  }

  @override
  Future<PluginSessionControlValueDto> setPluginSessionControl({
    required String sessionId,
    required String pluginId,
    required String contributionId,
    required Object? value,
  }) async {
    pluginSessionControlSets.add((
      sessionId: sessionId,
      pluginId: pluginId,
      contributionId: contributionId,
      value: value,
    ));
    final key = '$sessionId/$pluginId/$contributionId';
    final current = await getPluginSessionControl(
      sessionId: sessionId,
      pluginId: pluginId,
      contributionId: contributionId,
    );
    final updated = current.copyWith(value: value, isDefault: false);
    pluginSessionControls[key] = updated;
    return updated;
  }

  @override
  Future<PluginUiDocumentDto> renderPluginUi({
    required String agentId,
    required String pluginId,
    required String contributionId,
    required PluginUiSlot slot,
    Object? input,
    Map<String, dynamic> context = const <String, dynamic>{},
  }) async {
    pluginUiRenders.add((
      agentId: agentId,
      pluginId: pluginId,
      contributionId: contributionId,
      slot: slot,
      context: Map<String, dynamic>.unmodifiable(context),
    ));
    final gate = pluginUiRenderGate;
    if (gate != null) await gate.future;
    if (pluginUiRenderFailure case final failure?) throw failure;
    final key = '$pluginId/$contributionId/$agentId';
    final document = pluginUiDocuments[key];
    if (document == null) {
      throw StateError('Plugin UI is not configured: $key');
    }
    return document;
  }

  @override
  Future<PluginUiDocumentDto> dispatchPluginUiAction({
    required String agentId,
    required String pluginId,
    required PluginUiActionDto action,
  }) async {
    pluginUiActions.add(action);
    return pluginUiDocuments.values.singleWhere(
      (document) => document.id == action.documentId,
    );
  }

  /// MCP servers this fake daemon reports, keyed by id.
  final Map<String, McpServerStateDto> mcpServers =
      <String, McpServerStateDto>{};

  /// Ordered MCP list responses used to reproduce out-of-order reloads.
  final List<Future<List<McpServerStateDto>>> mcpListResponses;

  /// Secrets stored through [setMcpSecret].
  final Map<String, String> mcpSecrets = <String, String>{};

  @override
  Future<List<McpServerStateDto>> listMcpServers({String? worktreeId}) async {
    await mcpListGate;
    if (mcpListResponses.isNotEmpty) {
      return mcpListResponses.removeAt(0);
    }
    return mcpServers.values.toList(growable: false);
  }

  @override
  Future<McpServerStateDto> addMcpServer(McpServerConfigDto server) async =>
      mcpServers[server.id] = _readyState(server);

  @override
  Future<McpServerStateDto> updateMcpServer(McpServerConfigDto server) async =>
      mcpServers[server.id] = _readyState(server);

  @override
  Future<void> removeMcpServer(String id) async => mcpServers.remove(id);

  @override
  Future<McpServerStateDto> testMcpServer(McpServerConfigDto server) async =>
      _readyState(server);

  @override
  Future<void> setMcpSecret(String key, String value) async =>
      mcpSecrets[key] = value;

  McpServerStateDto _readyState(McpServerConfigDto server) => McpServerStateDto(
    config: server,
    status: server.enabled ? McpServerStatus.ready : McpServerStatus.disabled,
    scope: McpConfigScope.user,
    sourcePath: '/config/mcp.json',
    serverName: server.id,
    protocolVersion: '2025-06-18',
    tools: <McpToolSummaryDto>[
      McpToolSummaryDto(
        toolId: 'mcp__${server.id}__echo',
        name: 'echo',
        description: 'Echoes its argument.',
      ),
    ],
  );

  @override
  Future<FileSearchResultDto> searchFiles({
    required String worktreeId,
    required String query,
    int limit = 50,
  }) async {
    searchedQueries.add(query);
    await searchFilesGate;
    final failure = searchFilesError;
    if (failure != null) throw failure;
    final paths = files[worktreeId] ?? const <String>[];
    // Mirrors the daemon's coarse filter: a subsequence over the whole path.
    final matched = paths
        .where(
          (path) => _isSubsequence(path.toLowerCase(), query.toLowerCase()),
        )
        .take(limit)
        .map(
          (path) => FileMatchDto(
            relativePath: path,
            absolutePath: '/worktree/$path',
            name: path.split('/').last,
            isDirectory: false,
          ),
        )
        .toList(growable: false);
    return FileSearchResultDto(matches: matched);
  }

  static bool _isSubsequence(String candidate, String query) {
    var cursor = 0;
    for (
      var index = 0;
      index < candidate.length && cursor < query.length;
      index += 1
    ) {
      if (candidate.codeUnitAt(index) == query.codeUnitAt(cursor)) cursor += 1;
    }
    return cursor == query.length;
  }

  @override
  Future<List<AgentCommandDto>> listCommands({String? workspaceId}) async =>
      List<AgentCommandDto>.unmodifiable(commands);

  @override
  Future<List<SkillSummaryDto>> listSkills({
    required SkillListView view,
    String? workspaceId,
  }) async {
    skillListRequests.add(
      SkillListParamsDto(view: view, workspaceId: workspaceId),
    );
    await skillListGate;
    final error = skillListError;
    if (error != null) throw error;
    final result = switch (view) {
      SkillListView.global => _skills,
      SkillListView.project => _projectSkills,
      SkillListView.effective => <SkillSummaryDto>[
        ..._skills,
        ..._projectSkills,
      ],
    };
    return List<SkillSummaryDto>.unmodifiable(result);
  }

  @override
  Future<ProviderCatalogDto> listProviderCatalog() async => _catalog;

  @override
  Future<List<ProviderConnectionDto>> listProviderConnections() async {
    await providerConnectionsGate;
    return List<ProviderConnectionDto>.unmodifiable(_connections);
  }

  @override
  Future<ProviderConnectionDto> connectProviderApiKey(
    String definitionId,
    String apiKey, {
    String? connectionId,
    String? modelPrefix,
  }) async {
    final error = providerConnectError;
    providerConnectError = null;
    if (error != null) throw error;
    final existing = _connections
        .where((connection) => connection.definitionId == definitionId)
        .length;
    final resolvedConnectionId =
        connectionId ??
        (existing == 0 ? definitionId : '$definitionId-${existing + 1}');
    credentials[definitionId] = apiKey;
    credentials[resolvedConnectionId] = apiKey;
    final definition = _catalog.definitions.singleWhere(
      (item) => item.id == definitionId,
    );
    return _saveConnection(
      ProviderConnectionDto(
        id: resolvedConnectionId,
        definitionId: definitionId,
        modelPrefix: modelPrefix ?? definitionId,
        displayName: definition.name,
        status: ProviderConnectionStatus.connected,
        authKind: ProviderAuthKind.apiKey,
        credentialOrigin: ProviderCredentialOrigin.stored,
        createdAt:
            _connections
                .where((item) => item.id == resolvedConnectionId)
                .firstOrNull
                ?.createdAt ??
            _now,
        updatedAt: _now,
      ),
    );
  }

  @override
  Future<ProviderConnectionDto> connectProviderNone(
    String definitionId, {
    String? connectionId,
    String? modelPrefix,
  }) async {
    final existing = _connections
        .where((connection) => connection.definitionId == definitionId)
        .length;
    final resolvedConnectionId =
        connectionId ??
        (existing == 0 ? definitionId : '$definitionId-${existing + 1}');
    final definition = _catalog.definitions.singleWhere(
      (item) => item.id == definitionId,
    );
    return _saveConnection(
      ProviderConnectionDto(
        id: resolvedConnectionId,
        definitionId: definitionId,
        modelPrefix: modelPrefix ?? definitionId,
        displayName: definition.name,
        status: ProviderConnectionStatus.connected,
        authKind: ProviderAuthKind.none,
        credentialOrigin: ProviderCredentialOrigin.none,
        createdAt:
            _connections
                .where((item) => item.id == resolvedConnectionId)
                .firstOrNull
                ?.createdAt ??
            _now,
        updatedAt: _now,
      ),
    );
  }

  @override
  Future<ProviderAuthAttemptDto> startProviderAuth(
    String definitionId,
    String methodId, {
    String? connectionId,
    String? modelPrefix,
  }) async => ProviderAuthAttemptDto(
    id: 'attempt',
    definitionId: definitionId,
    methodId: methodId,
    connectionId: connectionId ?? definitionId,
    modelPrefix: modelPrefix ?? definitionId,
    status: ProviderAuthAttemptStatus.awaitingUser,
    authorizationUrl: 'https://auth.example/authorize',
    userCode: methodId.contains('device') ? 'CODE-1234' : null,
  );

  @override
  Future<ProviderAuthAttemptDto> providerAuthStatus(String attemptId) async =>
      const ProviderAuthAttemptDto(
        id: 'attempt',
        definitionId: 'openai',
        methodId: 'chatgpt-browser',
        status: ProviderAuthAttemptStatus.awaitingUser,
      );

  @override
  Future<void> cancelProviderAuth(String attemptId) async {
    cancelledAuthAttempts.add(attemptId);
  }

  @override
  Future<void> disconnectProvider(String connectionId) async {
    await providerDisconnectGate;
    credentials.remove(connectionId);
    final current = _connections.singleWhere((item) => item.id == connectionId);
    _saveConnection(
      current.copyWith(
        status: ProviderConnectionStatus.disconnected,
        credentialOrigin: ProviderCredentialOrigin.none,
      ),
    );
  }

  @override
  Future<ProviderConnectionDto> updateProviderModelPrefix(
    String connectionId,
    String modelPrefix,
  ) async {
    final current = _connections.singleWhere((item) => item.id == connectionId);
    return _saveConnection(current.copyWith(modelPrefix: modelPrefix));
  }

  @override
  Future<ProviderCatalogDto> refreshProviderCatalog() async {
    final error = catalogRefreshError;
    catalogRefreshError = null;
    if (error != null) throw error;
    return _catalog = _catalog.copyWith(
      source: ProviderCatalogSource.refreshed,
    );
  }

  @override
  Future<List<ProviderModelDto>> listProviderModels(
    String connectionId,
  ) async {
    final gate = modelListGate;
    if (gate != null) await gate;
    final error = providerModelListError;
    if (error != null) throw error;
    return List<ProviderModelDto>.unmodifiable(
      _models[connectionId] ?? const <ProviderModelDto>[],
    );
  }

  @override
  Future<List<ProviderUsageDto>> listProviderUsage() async =>
      List<ProviderUsageDto>.unmodifiable(_providerUsage);

  @override
  Future<DaemonModelSettingsDto> getSettings() async {
    await modelSettingsGate;
    return DaemonModelSettingsDto(defaultModel: _defaultModel);
  }

  @override
  Future<DaemonModelSettingsDto> setDefaultModel(
    ModelSelectionDto model,
  ) async {
    _defaultModel = model;
    return DaemonModelSettingsDto(defaultModel: model);
  }

  @override
  Future<ProviderConnectionDto> createCustomProvider(
    String id,
    CustomProviderConfigDto config, {
    String? apiKey,
    String? modelPrefix,
  }) async {
    final prefix =
        modelPrefix ?? config.name.toLowerCase().replaceAll(' ', '-');
    if (apiKey != null) credentials[id] = apiKey;
    for (final manualModel in config.models) {
      _models
          .putIfAbsent(id, () => <ProviderModelDto>[])
          .add(
            ProviderModelDto(
              connectionId: id,
              id: '$prefix/${manualModel.id}',
              providerModelId: manualModel.id,
              label: manualModel.label,
              source: ProviderModelSource.manual,
              capabilities: const ModelCapabilitiesDto(
                streaming: CapabilitySupport.supported,
                toolCalling: CapabilitySupport.supported,
                source: CapabilitySource.manual,
              ),
            ),
          );
    }
    return _saveConnection(
      ProviderConnectionDto(
        id: id,
        definitionId: 'custom',
        modelPrefix: prefix,
        displayName: config.name,
        status: ProviderConnectionStatus.connected,
        authKind: config.authenticationRequired
            ? ProviderAuthKind.apiKey
            : ProviderAuthKind.none,
        credentialOrigin: apiKey == null
            ? ProviderCredentialOrigin.none
            : ProviderCredentialOrigin.stored,
        customConfig: config,
        createdAt: _now,
        updatedAt: _now,
      ),
    );
  }

  @override
  Future<ProviderConnectionDto> updateCustomProvider(
    String connectionId,
    CustomProviderConfigDto config, {
    String? apiKey,
  }) async {
    if (apiKey != null) credentials[connectionId] = apiKey;
    final current = _connections.singleWhere(
      (item) => item.id == connectionId,
    );
    for (final manualModel in config.models) {
      final models = _models.putIfAbsent(
        connectionId,
        () => <ProviderModelDto>[],
      );
      if (models.any((model) => model.providerModelId == manualModel.id)) {
        continue;
      }
      models.add(
        ProviderModelDto(
          connectionId: connectionId,
          id: '${current.modelPrefix}/${manualModel.id}',
          providerModelId: manualModel.id,
          label: manualModel.label,
          source: ProviderModelSource.manual,
          capabilities: const ModelCapabilitiesDto(
            streaming: CapabilitySupport.supported,
            toolCalling: CapabilitySupport.supported,
            source: CapabilitySource.manual,
          ),
        ),
      );
    }
    return _saveConnection(
      current.copyWith(
        displayName: config.name,
        customConfig: config,
      ),
    );
  }

  @override
  Future<void> deleteCustomProvider(String connectionId) async {
    _connections.removeWhere((item) => item.id == connectionId);
    _models.remove(connectionId);
    credentials.remove(connectionId);
  }

  ProviderConnectionDto _saveConnection(ProviderConnectionDto connection) {
    _connections
      ..removeWhere((item) => item.id == connection.id)
      ..add(connection);
    return connection;
  }

  @override
  Future<void> startTurn({
    required String sessionId,
    required String turnId,
    required String prompt,
    List<String> attachmentIds = const <String>[],
  }) async {
    attemptedPrompts.add(prompt);
    final gate = startTurnGate;
    if (gate != null) await gate.future;
    if (startTurnFailures > 0) {
      startTurnFailures -= 1;
      throw Exception('transient send failure');
    }
    final error = startTurnError;
    if (error != null) throw error;
    startedPrompts.add(prompt);
    startedTurnIds.add(turnId);
    startedAttachmentIds.add(List<String>.of(attachmentIds));
    if (emitTurnStartEvents) {
      final index = _agents.indexWhere((agent) => agent.id == sessionId);
      if (index >= 0) {
        emit(
          SessionUpdatedClientEvent(
            _agents[index].copyWith(status: SessionStatus.running),
          ),
        );
      }
    }
    if (emitUserMessageEcho) {
      emitTimeline(sessionId, 'user.message', <String, dynamic>{
        'text': prompt,
        'attachments': const <Map<String, dynamic>>[],
      }, turnId: turnId);
    }
  }

  @override
  Future<AttachmentDto> uploadAttachment({
    required String fileName,
    required String mimeType,
    required int byteSize,
    required Stream<List<int>> bytes,
  }) async {
    final builder = BytesBuilder(copy: false);
    await bytes.forEach(builder.add);
    final payload = builder.takeBytes();
    if (payload.length != byteSize) {
      throw const FormatException('Attachment size mismatch.');
    }
    final id = 'attachment-${_attachments.length + 1}';
    final metadata = AttachmentDto(
      id: id,
      fileName: fileName,
      mimeType: mimeType,
      byteSize: byteSize,
      kind: mimeType.startsWith('image/')
          ? AttachmentKind.image
          : AttachmentKind.file,
      sha256: 'fake-sha256-$id',
      createdAt: _now,
    );
    _attachments[id] = (metadata: metadata, bytes: payload);
    return metadata;
  }

  @override
  Future<AttachmentDownload> downloadAttachment(String id) async {
    final attachment = _attachments[id];
    if (attachment == null) throw StateError('Attachment not found: $id');
    return AttachmentDownload(
      fileName: attachment.metadata.fileName,
      mimeType: attachment.metadata.mimeType,
      byteSize: attachment.metadata.byteSize,
      bytes: Stream<List<int>>.value(attachment.bytes),
    );
  }

  @override
  Future<void> cancelTurn(String sessionId) async {
    cancelledAgents.add(sessionId);
  }

  @override
  Future<void> resolveApproval({
    required String approvalId,
    required bool approved,
  }) async {
    approvalDecisions.add((id: approvalId, approved: approved));
  }

  /// Sessions the app told the daemon had queued input, in order.
  final List<String> notedPendingInput = <String>[];

  @override
  Future<void> notePendingInput(String sessionId) async {
    notedPendingInput.add(sessionId);
    final error = notePendingInputError;
    if (error != null) throw error;
  }

  @override
  Future<UserQuestionRequestDto> answerUserQuestion({
    required String requestId,
    required List<UserQuestionAnswerDto> answers,
  }) async {
    questionAnswers.add((id: requestId, answers: answers));
    await questionAnswerGate?.future;
    if (questionAnswerError case final error?) throw error;
    return UserQuestionRequestDto(
      id: requestId,
      sessionId: 'session',
      turnId: 'turn',
      toolCallId: 'ask-call',
      questions: const <UserQuestionItemDto>[],
      status: UserQuestionStatus.answered,
      createdAt: DateTime.utc(2026, 8, 3),
      answers: answers,
    );
  }

  @override
  Future<List<TimelineEventDto>> subscribeTimeline(
    String sessionId, {
    int afterSequence = 0,
    int? tailLimit,
  }) async {
    subscribeTimelineCount += 1;
    if (subscribeTimelineGate case final gate?) await gate.future;
    final events = (_timelines[sessionId] ?? const <TimelineEventDto>[])
        .where((event) => event.sequence > afterSequence)
        .toList(growable: false);
    if (tailLimit == null || events.length <= tailLimit) return events;
    return events.sublist(events.length - tailLimit);
  }

  /// Optional gate used to keep a timeline subscription pending.
  Completer<void>? subscribeTimelineGate;

  @override
  Future<List<TimelineEventDto>> readTimelineHistory(
    String sessionId, {
    required int beforeSequence,
    required int limit,
  }) async {
    readTimelineHistoryCount += 1;
    if (readTimelineHistoryGate case final gate?) await gate.future;
    if (readTimelineHistoryFailure case final failure?) throw failure;
    final older = (_timelines[sessionId] ?? const <TimelineEventDto>[])
        .where((event) => event.sequence < beforeSequence)
        .toList(growable: false);
    if (older.length <= limit) return older;
    return older.sublist(older.length - limit);
  }

  /// Number of [readTimelineHistory] calls, counted so a test can prove a
  /// page is fetched exactly once per cursor.
  int readTimelineHistoryCount = 0;

  /// Optional gate used to keep a history page pending.
  Completer<void>? readTimelineHistoryGate;

  /// Optional error thrown instead of returning a history page.
  Exception? readTimelineHistoryFailure;

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _events.close();
    await _states.close();
    await _catalogUpdates.close();
  }
}

/// Creates app services with one deterministic remote daemon profile.
AppServices fakeAppServices(
  FakeTinestApi api, {
  bool connected = true,
  String hostId = 'server',
  MemoryAppStore? store,
}) {
  final now = DateTime.utc(2026, 8, 2);
  final profiles = <RemoteDaemonProfile>[
    RemoteDaemonProfile(
      id: hostId,
      label: 'Test daemon',
      connections: directHostConnections(Uri.parse('ws://127.0.0.1:7337/ws')),
      autoConnect: connected,
      createdAt: now,
      updatedAt: now,
    ),
  ];
  final tokens = <String, String>{hostId: 'test-token'};
  final effectiveStore =
      store ??
      MemoryAppStore(
        settings: const AppSettings(embeddedDaemonEnabled: false),
        profiles: profiles,
        tokens: tokens,
      );
  if (store != null) {
    // Keep caller-provided settings such as a collapsed sidebar.
    store
      ..settings = store.settings.copyWith(embeddedDaemonEnabled: false)
      ..profiles.addAll(profiles)
      ..tokens.addAll(tokens);
  }
  return AppServices(
    settings: effectiveStore,
    profiles: effectiveStore,
    credentials: effectiveStore,
    clients: _FakeHostClientFactory(api),
    clientKind: 'test',
    pathProbeScheduler: const _NoopHostPathProbeScheduler(),
  );
}

final class _NoopHostPathProbeScheduler implements HostPathProbeScheduler {
  const _NoopHostPathProbeScheduler();

  @override
  HostPathProbeTask periodic(
    Duration interval,
    Future<void> Function() callback,
  ) => const _NoopHostPathProbeTask();
}

final class _NoopHostPathProbeTask implements HostPathProbeTask {
  const _NoopHostPathProbeTask();

  @override
  void cancel() {}
}

final class _FakeHostClientFactory implements HostClientFactory {
  const _FakeHostClientFactory(this.api);

  final TinestApi api;

  @override
  Future<TinestApi> connect({
    required HostConnection connection,
    required HostConnectionCredential credential,
    required String clientId,
    required String clientKind,
  }) async => api;
}
