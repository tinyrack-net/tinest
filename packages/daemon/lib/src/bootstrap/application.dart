import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:agent/agent.dart';
import 'package:crypto/crypto.dart';
import 'package:daemon/src/bootstrap/config.dart';
import 'package:daemon/src/features/agents/infrastructure/agent_definitions.dart';
import 'package:daemon/src/features/agents/infrastructure/permission_defaults.dart';
import 'package:daemon/src/features/agents/transport/rpc_bindings.dart';
import 'package:daemon/src/features/attachments/infrastructure/attachment_service.dart';
import 'package:daemon/src/features/attachments/transport/http_transport.dart';
import 'package:daemon/src/features/mcp/infrastructure/mcp_config.dart';
import 'package:daemon/src/features/mcp/infrastructure/mcp_host_primitives.dart';
import 'package:daemon/src/features/mcp/infrastructure/mcp_server_service.dart';
import 'package:daemon/src/features/mcp/infrastructure/mcp_service.dart';
import 'package:daemon/src/features/mcp/infrastructure/mcp_transports.dart';
import 'package:daemon/src/features/mcp/transport/rpc_bindings.dart';
import 'package:daemon/src/features/models/infrastructure/model_settings_service.dart';
import 'package:daemon/src/features/models/transport/rpc_bindings.dart';
import 'package:daemon/src/features/plugins/infrastructure/native_plugin_secret_vault.dart';
import 'package:daemon/src/features/plugins/infrastructure/native_plugin_state_repository.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_authoring.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_bundles.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_network_gateway.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_service.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_session_control_service.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_ui_service.dart';
import 'package:daemon/src/features/plugins/runtime/built_in_host_primitives.dart';
import 'package:daemon/src/features/plugins/runtime/host_primitives.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_runtime.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_scheduled_handler.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_scheduler.dart';
import 'package:daemon/src/features/plugins/transport/rpc_bindings.dart';
import 'package:daemon/src/features/prompts/infrastructure/commands.dart';
import 'package:daemon/src/features/prompts/infrastructure/skills.dart';
import 'package:daemon/src/features/prompts/transport/rpc_bindings.dart';
import 'package:daemon/src/features/providers/infrastructure/anthropic/plugin.dart';
import 'package:daemon/src/features/providers/infrastructure/anthropic/wire.dart';
import 'package:daemon/src/features/providers/infrastructure/credential_store.dart';
import 'package:daemon/src/features/providers/infrastructure/gemini/plugin.dart';
import 'package:daemon/src/features/providers/infrastructure/gemini/wire.dart';
import 'package:daemon/src/features/providers/infrastructure/openai/openai.dart';
import 'package:daemon/src/features/providers/infrastructure/provider_adapters.dart';
import 'package:daemon/src/features/providers/infrastructure/provider_auth.dart';
import 'package:daemon/src/features/providers/infrastructure/provider_catalog.dart';
import 'package:daemon/src/features/providers/infrastructure/provider_service.dart';
import 'package:daemon/src/features/providers/infrastructure/provider_usage_service.dart';
import 'package:daemon/src/features/providers/transport/rpc_bindings.dart';
import 'package:daemon/src/features/relay/application/relay_control_service.dart';
import 'package:daemon/src/features/relay/application/relay_pairing_service.dart';
import 'package:daemon/src/features/relay/infrastructure/daemon_relay_transport.dart';
import 'package:daemon/src/features/relay/infrastructure/relay_attachment_adapter.dart';
import 'package:daemon/src/features/relay/infrastructure/settings_relay_device_repository.dart';
import 'package:daemon/src/features/relay/transport/rpc_bindings.dart';
import 'package:daemon/src/features/sessions/infrastructure/agent_service.dart';
import 'package:daemon/src/features/sessions/infrastructure/exec_session_service.dart';
import 'package:daemon/src/features/sessions/infrastructure/lua_code_mode_service.dart';
import 'package:daemon/src/features/sessions/infrastructure/multi_agent.dart';
import 'package:daemon/src/features/sessions/infrastructure/session_interactions.dart';
import 'package:daemon/src/features/sessions/infrastructure/session_settings.dart';
import 'package:daemon/src/features/sessions/infrastructure/timeline_blocks.dart';
import 'package:daemon/src/features/sessions/transport/rpc_bindings.dart';
import 'package:daemon/src/features/terminals/application/terminal_service.dart';
import 'package:daemon/src/features/terminals/domain/terminal.dart';
import 'package:daemon/src/features/terminals/infrastructure/portable_terminal.dart';
import 'package:daemon/src/features/terminals/infrastructure/vtworld_terminal_screen.dart';
import 'package:daemon/src/features/terminals/transport/rpc_bindings.dart';
import 'package:daemon/src/features/terminals/transport/terminal_mapper.dart';
import 'package:daemon/src/features/workspaces/infrastructure/file_index.dart';
import 'package:daemon/src/features/workspaces/infrastructure/git_workspace.dart';
import 'package:daemon/src/features/workspaces/infrastructure/project_settings.dart';
import 'package:daemon/src/features/workspaces/infrastructure/workspace_service.dart';
import 'package:daemon/src/features/workspaces/transport/rpc_bindings.dart';
import 'package:daemon/src/shared/infrastructure/deferred_lua_host_process.dart';
import 'package:daemon/src/shared/infrastructure/persistence/database.dart';
import 'package:daemon/src/shared/infrastructure/persistence/repositories.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:daemon/src/transport/rpc/binding.dart';
import 'package:daemon/src/transport/rpc/diagnostics.dart';
import 'package:daemon/src/transport/rpc/rpc_dispatch.dart';
import 'package:daemon/src/transport/rpc/server.dart';
import 'package:dio/dio.dart';
import 'package:lua_tool_runtime/lua_tool_runtime.dart' as lua;
import 'package:path/path.dart' as p;
import 'package:protocol/protocol.dart';
import 'package:relay_protocol/relay_protocol.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

// The deferred launcher replaces this identity before it reaches a process
// adapter. The runtime uses the value only to attach invocation limits.
const _deferredLuaHostCommand = lua.LuaHostCommand(
  executable: 'tinest-deferred-lua-host',
);

String _pluginIdOf(String contributionId) {
  final separator = contributionId.indexOf('/');
  return separator < 0
      ? contributionId
      : contributionId.substring(0, separator);
}

/// Raised when another daemon already holds the lock on a daemon home.
///
/// The daemon home is exclusive, so a second daemon over the same directory is
/// a lifecycle conflict rather than a filesystem fault. The operating system
/// only reports it as a lock error on `daemon.lock`, which reads as data
/// corruption to a user, so the cause is named here instead.
final class DaemonAlreadyRunningException implements Exception {
  /// Creates a conflict for the daemon home another daemon still owns.
  const new({required this.homeDirectory, required this.diagnostic});

  /// Daemon home whose lock could not be taken.
  final String homeDirectory;

  /// Operating-system diagnostic kept for a bug report.
  final String diagnostic;

  @override
  String toString() =>
      'A daemon is already running on $homeDirectory ($diagnostic).';
}

/// Public API exposed by this library.
abstract interface class DaemonHandle {
  /// The ready public API member.
  Future<void> get ready;

  /// The boundEndpoint public API member.
  Uri get boundEndpoint;

  /// The serverId public API member.
  String get serverId;

  /// The bearerToken public API member.
  String get bearerToken;

  /// The stop public API member.
  Future<void> stop();
}

/// Typed host ports that customize daemon composition without exposing
/// infrastructure adapters or feature services.
final class DaemonHostOptions {
  /// Creates optional host overrides.
  const new({
    this.provider,
    this.clock,
    this.ids,
    this.modelDiscovery,
    this.oauthGateway,
    this.providerUsageGateway,
    this.providerCatalogMetadataSource,
    this.workspacePaths,
    this.git,
    this.projectSettings,
    this.worktreeHooks,
    this.rpcDiagnostics,
  });

  /// Fixed provider used by deterministic embedded/test hosts.
  final ModelGateway? provider;

  /// Host clock.
  final Clock? clock;

  /// Host identifier generator.
  final IdGenerator? ids;

  /// Provider model discovery port.
  final ProviderModelDiscovery? modelDiscovery;

  /// Provider authorization port.
  final ProviderOAuthGateway? oauthGateway;

  /// Provider subscription usage transport.
  final ProviderUsageGateway? providerUsageGateway;

  /// Provider catalog metadata port.
  final ProviderCatalogMetadataSource? providerCatalogMetadataSource;

  /// Workspace path access port.
  final WorkspacePathGateway? workspacePaths;

  /// Git workspace port.
  final GitWorkspaceGateway? git;

  /// Project-settings persistence port.
  final ProjectSettingsStore? projectSettings;

  /// Worktree hook execution port.
  final WorktreeHookRunner? worktreeHooks;

  /// Sink for transport failures that are intentionally opaque to clients.
  final RpcDiagnostics? rpcDiagnostics;
}

/// Public API exposed by this library.
abstract final class DaemonApplication {
  /// The start public API member.
  static Future<DaemonHandle> start(
    DaemonConfig config, {
    DaemonHostOptions options = const DaemonHostOptions(),
    ModelGateway? provider,
    Clock clock = const SystemClock(),
    IdGenerator ids = const UuidIdGenerator(),
    ProviderModelDiscovery? modelDiscovery,
    ProviderOAuthGateway? oauthGateway,
    ProviderCatalogMetadataSource? providerCatalogMetadataSource,
    WorkspacePathGateway workspacePaths = const IoWorkspacePathGateway(),
    GitWorkspaceGateway? git,
    ProjectSettingsStore projectSettings = const FileProjectSettingsStore(),
    WorktreeHookRunner worktreeHooks = const ShellWorktreeHookRunner(),
  }) async {
    final effectiveProvider = options.provider ?? provider;
    final effectiveClock = options.clock ?? clock;
    final effectiveIds = options.ids ?? ids;
    final effectiveModelDiscovery = options.modelDiscovery ?? modelDiscovery;
    final effectiveOAuthGateway = options.oauthGateway ?? oauthGateway;
    final effectiveUsageGateway =
        options.providerUsageGateway ?? OpenAIProviderUsageGateway(Dio());
    final effectiveCatalogMetadataSource =
        options.providerCatalogMetadataSource ?? providerCatalogMetadataSource;
    final effectiveWorkspacePaths = options.workspacePaths ?? workspacePaths;
    final effectiveGit = options.git ?? git;
    final effectiveProjectSettings = options.projectSettings ?? projectSettings;
    final effectiveWorktreeHooks = options.worktreeHooks ?? worktreeHooks;
    final effectiveRpcDiagnostics =
        options.rpcDiagnostics ?? const StderrRpcDiagnostics();
    final home = Directory(p.join(config.homeDirectory, 'v5'));
    final configDirectory = p.join(config.configDirectory, 'v5');
    await home.create(recursive: true);
    final lockFile = File(p.join(home.path, 'daemon.lock'));
    final lock = await lockFile.open(mode: FileMode.append);
    try {
      await lock.lock();
    } on FileSystemException catch (error) {
      // Every failure of this call is contention: the file is already open, so
      // the only thing left to refuse is the lock itself. Matching on errno
      // would mean tracking 33 on Windows, 11 on Linux, and 35 on macOS.
      await lock.close();
      throw DaemonAlreadyRunningException(
        homeDirectory: home.path,
        diagnostic: '$error',
      );
    } catch (_) {
      await lock.close();
      rethrow;
    }

    final database = TinestDatabase(
      p.join(home.path, 'tinest.sqlite'),
      clock: effectiveClock,
    );
    NativePluginSourceCatalog? pluginSources;
    try {
      await database.runtimeDao.recoverInterruptedRuns();
      var serverId = await database.settingsDao.getValue('server.id');
      if (serverId == null) {
        serverId = effectiveIds.generate();
        await database.settingsDao.setValue('server.id', serverId);
      }
      final credentials = CredentialStore(configDirectory);
      await credentials.load();
      final token =
          config.bearerToken ??
          credentials.bearerToken ??
          generateBearerToken();
      if (utf8.encode(token).length < 32) {
        throw ArgumentError(
          'Bearer token must contain at least 256 bits (32 bytes).',
        );
      }
      await database.settingsDao.setValue(
        'auth.tokenHash',
        sha256.convert(utf8.encode(token)).toString(),
      );
      if (credentials.bearerToken != token) {
        await credentials.setDaemonToken(token);
      }
      var relayIdentitySeed = credentials.relayIdentityPrivateKey;
      if (relayIdentitySeed == null) {
        final random = Random.secure();
        relayIdentitySeed = List<int>.generate(
          32,
          (_) => random.nextInt(256),
          growable: false,
        );
        await credentials.setRelayIdentityPrivateKey(relayIdentitySeed);
      }
      final relayIdentity = await RelayIdentity.fromSeed(relayIdentitySeed);
      final storedRelayEnabled =
          await database.settingsDao.getValue('relay.enabled') == 'true';
      final storedRelayEndpoint = await database.settingsDao.getValue(
        'relay.endpoint',
      );
      final relayEndpoint =
          config.relay.endpointOverride ??
          (storedRelayEndpoint == null
              ? config.relay.endpoint
              : Uri.parse(storedRelayEndpoint));
      DaemonRpcServer? relayRpcSessions;
      DaemonRelayTransport? relayTransport;
      final relayPairing = RelayPairingService(
        ids: effectiveIds,
        serverId: serverId,
        relayUri: relayEndpoint,
        daemonIdentityPublicKey: relayIdentity.publicKey,
        devices: SettingsRelayDeviceRepository(database.settingsDao),
        clock: effectiveClock,
        terminateDeviceSessions: (deviceId) async {
          await relayTransport?.terminateDeviceSessions(deviceId);
          await relayRpcSessions?.terminateRelayDeviceSessions(deviceId);
        },
      );
      final relay = RelayControlService(
        enabled: config.relay.enabled || storedRelayEnabled,
        endpoint: relayEndpoint,
        serverId: serverId,
        pairing: relayPairing,
        applyEnabled: ({required enabled}) async {
          await database.settingsDao.setValue(
            'relay.enabled',
            enabled.toString(),
          );
          if (enabled) {
            await relayTransport?.start();
          } else {
            await relayTransport?.stop();
          }
        },
        applyEndpoint: (endpoint) async {
          await relayTransport?.setEndpoint(endpoint);
          await database.settingsDao.setValue(
            'relay.endpoint',
            endpoint.toString(),
          );
        },
      );
      final events = StreamController<OutboundNotification>.broadcast(
        sync: true,
      );
      // The whole vendor surface of this daemon: adding a vendor package
      // means adding its adapters and wire protocols to these two lists.
      final providerRegistry = ProviderRegistry(
        adapters: <ProviderAdapter>[
          ...openAIFamilyAdapters(
            clock: effectiveClock,
            openAIOAuth: effectiveOAuthGateway,
            // Only the platform Responses API defines an attribution field,
            // so the value reaches the one vendor that documents it rather
            // than riding on every model request.
            requestAttribution: sha256
                .convert(utf8.encode(serverId))
                .toString(),
          ),
          const AnthropicAdapter(),
          const GoogleGeminiAdapter(),
        ],
        wireProtocols: <ProviderWireProtocol>[
          ...openAIWireProtocols(),
          const AnthropicMessagesWire(),
          const GeminiInteractionsWire(),
        ],
      );
      final oauthRefresher = OAuthCredentialRefresher(
        registry: providerRegistry,
      );
      final providers = ProviderConnectionService(
        repository: database.providerDao,
        credentials: credentials,
        ids: effectiveIds,
        clock: effectiveClock,
        registry: providerRegistry,
        catalog: BuiltInProviderCatalog(
          clock: effectiveClock,
          registry: providerRegistry,
          metadataSource: effectiveCatalogMetadataSource,
        ),
        modelDiscovery: effectiveModelDiscovery,
        oauthRefresher: oauthRefresher,
        fixedProvider: effectiveProvider,
      );
      await providers.initialize();
      final modelSettings = DaemonModelSettingsService(
        settings: database.settingsDao,
        catalog: providers,
      );
      await modelSettings.initialize();
      final providerUsage = ProviderUsageService(
        repository: database.providerDao,
        credentials: credentials,
        gateway: effectiveUsageGateway,
        oauthRefresher: oauthRefresher,
        clock: effectiveClock,
      );
      final models = ProviderModelResolver(
        providers,
        defaultModel: modelSettings.requireDefaultModel,
      );
      final providerAuth = ProviderAuthCoordinator(
        registry: providerRegistry,
        connector: providers,
        ids: effectiveIds,
      );
      final attachments = AttachmentService(
        repository: database.attachmentDao,
        blobs: NativeAttachmentBlobStore(p.join(home.path, 'attachments')),
        clock: effectiveClock,
        ids: effectiveIds,
      );
      await attachments.cleanupOrphans();
      final mcp = McpRuntime(
        store: FileMcpConfigStore(configDirectory),
        credentials: credentials,
        transports: IoMcpTransportFactory(clientVersion: config.version),
        clock: effectiveClock,
        environment: config.useEnvironmentCredentials
            ? Platform.environment
            : const <String, String>{},
        clientVersion: config.version,
      );
      // Reads mcp.json only; every handshake runs in the background so one
      // unstartable server cannot hold up daemon boot.
      await mcp.initialize();
      final mcpServers = McpServerService(mcp);
      MultiAgentService? multiAgent;
      final agentDefinitionStore = FileAgentDefinitionStore(configDirectory);
      final pluginAuthoring = PluginAuthoringEnvironmentService(
        configDirectory: config.configDirectory,
        sdk: const _TinestPluginSdkAuthoringProvider(),
        ids: effectiveIds,
      );
      pluginSources = NativePluginSourceCatalog(
        config.configDirectory,
        authoring: pluginAuthoring,
      );
      await pluginSources.initialize();
      final pluginLoader = NativePluginBundleLoader(config.configDirectory);
      final pluginState = NativePluginStateRepository(config.homeDirectory);
      final pluginSecrets = NativePluginSecretVault(config.configDirectory);
      final pluginNetwork = DioPluginNetworkGateway(Dio());
      final pluginRevisions = PluginRevisionCatalog(
        loader: pluginLoader,
        cache: NativePluginRevisionCache(config.homeDirectory),
      );
      final luaSourceRoot = Directory.current.path;
      // The IO launcher serializes protocol writes with termination itself,
      // so no decorator is needed for turn cancellation racing a flush.
      final luaProcessLauncher = DeferredLuaHostProcessLauncher(
        () => resolveLuaHostCommand(sourceRoot: luaSourceRoot),
        const lua.IoLuaHostProcessLauncher(),
      );
      final pluginRuntime = PluginRuntime<ConversationAttachment>(
        luaRuntime: lua.LuaToolRuntime<ConversationAttachment>(
          host: _deferredLuaHostCommand,
          processLauncher: luaProcessLauncher,
          clock: _TinestLuaClock(effectiveClock),
          ids: _TinestLuaIds(effectiveIds),
        ),
        revisions: pluginRevisions,
      );
      final pluginManagement = PluginManagementService(
        sources: pluginSources,
        revisions: pluginRevisions,
        grants: pluginState,
        inspector: pluginRuntime,
      );
      final agentDefinitions = AgentDefinitionService(
        store: agentDefinitionStore,
        contributions: _PluginAgentContributionCatalog(
          pluginManagement,
          pluginSources.changes,
        ),
      );
      await agentDefinitions.initialize();
      final pluginSessionControls =
          PluginSessionControlService<ConversationAttachment>(
            plugins: pluginManagement,
            runtime: pluginRuntime,
            state: pluginState,
            sessions: database.sessionDao.getById,
            definitions: agentDefinitions.resolve,
            worktrees: database.worktreeDao.getById,
          );
      final pluginUi = PluginUiService(
        descriptors: pluginManagement,
        runtime: LuaPluginUiRuntime<ConversationAttachment>(
          runtime: pluginRuntime,
          grants: pluginState,
          state: pluginState,
          definitions: agentDefinitions.resolve,
          hostPrimitives: HostPrimitiveRegistry(
            <HostPrimitive<Object?, Object?>>[
              collaborationListAgentsHostPrimitive(
                session: (context) =>
                    database.sessionDao.getById(context.sessionId),
                service: () => multiAgent,
              ),
            ],
          ),
        ),
      );
      providers.referenceUpdater = _StoredProviderModelReferenceUpdater(
        database.sessionDao,
        agentDefinitions,
        modelSettings,
      );
      final userHome = config.userHomeDirectory;
      final skills = SkillCatalogService(
        store: FileSkillStore(
          roots: <SkillFiles>[
            // A daemon without a resolved user home stays away from any
            // `~/.agents` tree instead of guessing one.
            if (userHome != null)
              NativeSkillFiles(
                p.join(userHome, '.agents', 'skills'),
                origin: SkillOrigin.userHome,
              ),
            NativeSkillFiles(
              p.join(configDirectory, 'skills'),
              origin: SkillOrigin.config,
              createIfMissing: true,
            ),
          ],
        ),
      );
      await skills.initialize();
      final commands = CommandService(
        globalSources: <CommandFiles>[
          // A daemon without a resolved user home stays away from any
          // `~/.agents` tree instead of guessing one.
          if (userHome != null)
            NativeCommandFiles(
              p.join(userHome, '.agents', 'commands'),
              source: AgentCommandSource.userHome,
            ),
          NativeCommandFiles(
            p.join(configDirectory, 'commands'),
            source: AgentCommandSource.config,
          ),
        ],
        projectFiles: (root) => NativeCommandFiles(
          p.join(root, '.agents', 'commands'),
          source: AgentCommandSource.project,
        ),
      );
      await commands.initialize();
      final execSessions = ExecSessionService(
        gateway: const PtyworldTerminalGateway(),
        pipes: const IoPipeGateway(),
        clock: effectiveClock,
      );
      final execSweep = Timer.periodic(
        const Duration(minutes: 5),
        (_) => execSessions.sweepIdle(),
      );
      final luaCodeMode = LuaCodeModeService(
        lua.LuaToolRuntime<ConversationAttachment>(
          host: _deferredLuaHostCommand,
          processLauncher: luaProcessLauncher,
          clock: _TinestLuaClock(effectiveClock),
          ids: _TinestLuaIds(effectiveIds),
        ),
      );
      final luaSweep = Timer.periodic(const Duration(minutes: 5), (_) {
        luaCodeMode.sweep();
        pluginRuntime.sweep();
      });
      // One instance, shared by every writer: a block ends when something
      // else is written, so a writer holding its own would close blocks the
      // others cannot see.
      final timeline = BlockStampingTimelineRepository(
        inner: database.timelineDao,
        ids: effectiveIds,
      );
      final sessionInteractions = SessionInteractionCoordinator(
        timeline: timeline,
        events: events.add,
        ids: effectiveIds,
        clock: effectiveClock,
      );
      late final SessionTurnCoordinator service;
      late final DurablePluginScheduler pluginScheduler;
      final scheduledJobs = LuaPluginScheduledJobExecutor(
        runtime: pluginRuntime,
        state: pluginState,
        grants: pluginState,
        jobs: () => pluginScheduler,
        clock: effectiveClock,
        ids: effectiveIds,
        resolveContext: (job) async {
          final agentId = job.agentId;
          final sessionId = job.sessionId;
          if (agentId == null || sessionId == null) {
            throw StateError(
              'Scheduled Agent jobs require agent and session owners.',
            );
          }
          final session = await database.sessionDao.getById(sessionId);
          if (session == null || session.agentDefinitionId != agentId) {
            throw StateError('Scheduled plugin session ownership changed.');
          }
          final definition = await agentDefinitions.resolve(agentId);
          final referencedPlugins = <String>{
            _pluginIdOf(definition.driverId),
            ...definition.extensionIds.map(_pluginIdOf),
            ...definition.toolIds.map(_pluginIdOf),
          };
          if (!referencedPlugins.contains(job.pluginId)) {
            throw StateError(
              'Agent no longer references scheduled plugin ${job.pluginId}.',
            );
          }
          final worktree = await database.worktreeDao.getById(
            session.worktreeId,
          );
          if (worktree == null || worktree.archivedAt != null) {
            throw StateError('Scheduled plugin worktree is unavailable.');
          }
          return PluginScheduledExecutionContext(
            agentId: agentId,
            sessionId: sessionId,
            workspaceId: worktree.workspaceId,
            workingDirectory: worktree.path,
          );
        },
      );
      pluginScheduler = DurablePluginScheduler(
        store: pluginState,
        clock: effectiveClock,
        ids: effectiveIds,
        execute: scheduledJobs.execute,
        hasActiveTurn: (sessionId) => service.hasActiveTurn(sessionId),
        hasPendingInput: sessionInteractions.hasPendingInput,
        startContinuation:
            ({required sessionId, required turnId, required prompt}) =>
                service.startTurn(
                  sessionId: sessionId,
                  turnId: turnId,
                  prompt: prompt,
                  internal: true,
                ),
      );
      service = SessionTurnCoordinator(
        sessions: database.sessionDao,
        definitions: agentDefinitions,
        worktrees: database.worktreeDao,
        timeline: timeline,
        models: models,
        events: events.add,
        clock: effectiveClock,
        ids: effectiveIds,
        hostPrimitiveRegistryFactory: const IoHostPrimitiveRegistryFactory(),
        attachments: attachments,
        execHostFor: (id) => SessionExecHost(execSessions, id),
        skills: skills,
        interactions: sessionInteractions,
        mcpFor: (workspaceRoot) =>
            SessionMcpHostPrimitiveGateway(mcp, workspaceRoot),
        plugins: pluginManagement,
        pluginSessionControls: pluginSessionControls,
        pluginUi: pluginUi,
        pluginRuntime: pluginRuntime,
        pluginState: pluginState,
        pluginJobs: pluginScheduler,
        luaCodeMode: luaCodeMode,
        pluginNetwork: pluginNetwork,
        pluginSecrets: pluginSecrets,
      );
      final permissionDefaults = PermissionDefaults(database.settingsDao);
      multiAgent = MultiAgentService(
        sessions: database.sessionDao,
        mailbox: database.agentMailboxDao,
        timeline: timeline,
        getDefinition: agentDefinitions.get,
        validateModel: models.validateQualifiedModel,
        defaultModel: () async {
          try {
            return await modelSettings.requireDefaultModel();
          } on ModelSettingsFailure catch (error) {
            throw CollaborationException(error.message);
          }
        },
        events: events.add,
        clock: effectiveClock,
        ids: effectiveIds,
      )..runtime = service;
      service.multiAgent = multiAgent;
      final sessionSettings = SessionSettingsService(
        sessions: database.sessionDao,
        models: models,
        hasActiveTurn: service.hasActiveTurn,
        events: events.add,
      );
      final fileIndex = GitAwareFileIndexGateway(
        const IoCommandRunner(),
        effectiveClock,
      );
      final workspaceOperations = WorkspaceOperations(
        database.workspaceDao,
        database.worktreeDao,
        database.sessionDao,
        effectiveWorkspacePaths,
        effectiveGit ?? const ProcessGitWorkspaceGateway(IoCommandRunner()),
        effectiveClock,
        p.join(home.path, 'worktrees'),
        fileIndex,
        effectiveProjectSettings,
        effectiveWorktreeHooks,
      );
      // Sessions that belong to no project run here, so the home checkout has
      // to exist before the first client connects.
      final workspaceCatalog = WorkspaceCatalogService(workspaceOperations);
      final worktreeLifecycle = WorktreeLifecycleService(workspaceOperations);
      await workspaceCatalog.provisionHome(config.userHomeDirectory);
      final terminals = TerminalService(
        gateway: const PtyworldTerminalGateway(),
        screens: const VtworldTerminalScreenFactory(),
        worktreePath: (worktreeId) async {
          final worktree = await database.worktreeDao.getById(worktreeId);
          if (worktree == null || worktree.archivedAt != null) {
            throw const FormatException('Active worktree not found.');
          }
          return effectiveWorkspacePaths.canonicalizeExistingDirectory(
            worktree.path,
          );
        },
        shellFor: (worktreeId) async {
          final worktree = await database.worktreeDao.getById(worktreeId);
          if (worktree == null || worktree.archivedAt != null) {
            throw const FormatException('Active worktree not found.');
          }
          final workspace = await database.workspaceDao.getById(
            worktree.workspaceId,
          );
          if (workspace == null) {
            throw const FormatException('Workspace not found.');
          }
          final project = await effectiveProjectSettings.load(
            workspace.rootPath,
          );
          if (project.shell case final shell?) {
            return TerminalShell(
              executable: shell.executable,
              arguments: shell.arguments,
            );
          }
          final stored = await database.settingsDao.getValue('terminal.shell');
          if (stored != null) {
            final shell = ShellSpecDto.fromJson(
              Map<String, dynamic>.from(jsonDecode(stored) as Map),
            );
            return TerminalShell(
              executable: shell.executable,
              arguments: shell.arguments,
            );
          }
          if (Platform.isWindows) {
            return const TerminalShell(executable: 'powershell.exe');
          }
          return TerminalShell(
            executable: Platform.environment['SHELL'] ?? '/bin/sh',
            arguments: const <String>['-l'],
          );
        },
      );
      final info = ServerInfoDto(
        serverId: serverId,
        version: config.version,
        protocolVersion: tinestProtocolMajor,
        homeDirectory: config.osHomeDirectory,
        features: <String, bool>{
          'timelineCatchup': true,
          'approvals': true,
          'embeddedDaemon': true,
          'providerCatalog': true,
          'agentDefinitions': true,
          'multiAgent': true,
          'mcp': true,
          'skills': true,
          'attachments': true,
          'terminals': true,
          'relay': true,
        },
      );
      final notificationSubscriptions = <StreamSubscription<Object?>>[
        providers.catalogUpdates.listen((catalog) {
          events.add(
            OutboundNotification(providersCatalogUpdatedNotification, catalog),
          );
        }),
        providerAuth.events.listen((attempt) {
          events.add(
            OutboundNotification(providersAuthUpdatedNotification, attempt),
          );
        }),
        agentDefinitions.changes.listen((_) {
          events.add(
            OutboundNotification(
              agentsChangedNotification,
              const EmptyResultDto(),
            ),
          );
        }),
        pluginSources.changes.listen((_) {
          events.add(
            OutboundNotification(
              pluginsChangedNotification,
              const EmptyResultDto(),
            ),
          );
        }),
        mcp.changes.listen((_) {
          events.add(
            OutboundNotification(
              mcpChangedNotification,
              const EmptyResultDto(),
            ),
          );
        }),
        skills.changes.listen((_) {
          events.add(
            OutboundNotification(
              promptsSkillsChangedNotification,
              const EmptyResultDto(),
            ),
          );
        }),
        commands.changes.listen((_) {
          events.add(
            OutboundNotification(
              promptsCommandsChangedNotification,
              const EmptyResultDto(),
            ),
          );
        }),
        terminals.events.listen((event) {
          switch (event) {
            case final TerminalOutput output:
              events.add(
                OutboundNotification(
                  terminalsOutputNotification,
                  terminalOutputToDto(output),
                ),
              );
            case final Terminal terminal:
              events.add(
                OutboundNotification(
                  terminalsUpdatedNotification,
                  terminalToDto(terminal),
                ),
              );
          }
        }),
        relay.updates.listen((status) {
          events.add(
            OutboundNotification(
              relayStatusChangedNotification,
              relayStatusToDto(status),
            ),
          );
        }),
      ];
      final bindings = RpcBindingRegistry(<RpcBindingDescriptor>[
        ...workspaceRpcBindings(
          workspaces: workspaceCatalog,
          worktrees: worktreeLifecycle,
        ),
        ...agentRpcBindings(
          definitions: agentDefinitions,
          permissions: permissionDefaults,
        ),
        ...pluginRpcBindings(
          plugins: pluginManagement,
          sessionControls: pluginSessionControls,
          ui: pluginUi,
          secrets: pluginSecrets,
          authoring: pluginAuthoring,
        ),
        ...promptRpcBindings(
          skills: skills,
          commands: commands,
          workspaces: workspaceCatalog,
        ),
        ...modelRpcBindings(modelSettings),
        ...providerRpcBindings(
          providers: providers,
          usage: providerUsage,
          auth: providerAuth,
          agentDefinitions: agentDefinitions,
        ),
        ...relayRpcBindings(relay),
        ...mcpRpcBindings(
          runtime: mcp,
          servers: mcpServers,
          worktrees: database.worktreeDao,
        ),
        ...sessionRpcBindings(
          sessions: database.sessionDao,
          timeline: timeline,
          turns: service,
          settings: sessionSettings,
          interactions: sessionInteractions,
          agentDefinitions: agentDefinitions,
          models: models,
          permissions: permissionDefaults,
          clock: effectiveClock,
        ),
        ...terminalRpcBindings(
          terminals: terminals,
          settings: database.settingsDao,
        ),
      ], procedures: daemonRpcProcedures);
      final rpc = DaemonRpcServer(
        bindings: bindings,
        attachments: AttachmentHttpTransport(attachments),
        serverInfo: info,
        token: token,
        events: events.stream,
        ids: effectiveIds,
        allowedOrigins: config.allowedOrigins,
        diagnostics: effectiveRpcDiagnostics,
      );
      relayRpcSessions = rpc;
      relayTransport = DaemonRelayTransport(
        serverId: serverId,
        endpoint: relayEndpoint,
        tlsPolicy: config.relay.tlsPolicy,
        identity: relayIdentity,
        pairing: relayPairing,
        rpcSessions: rpc,
        attachments: RelayAttachmentAdapter(attachments),
        control: relay,
      );
      if (relay.status.enabled) {
        await relayTransport.start();
      }
      final http = await shelf_io.serve(rpc.call, config.host, config.port);
      final presentationHost = config.host == '0.0.0.0'
          ? '127.0.0.1'
          : config.host;
      final attachmentCleanup = Timer.periodic(
        const Duration(hours: 1),
        (_) => unawaited(attachments.cleanupOrphans()),
      );
      pluginScheduler.start();
      return _LocalDaemonHandle(
        endpoint: Uri(
          scheme: 'ws',
          host: presentationHost,
          port: http.port,
          path: '/v5/ws',
        ),
        serverIdValue: serverId,
        token: token,
        http: http,
        rpc: rpc,
        turns: service,
        database: database,
        events: events,
        agentDefinitions: agentDefinitions,
        mcp: mcp,
        skills: skills,
        lock: lock,
        attachmentCleanup: attachmentCleanup,
        execSweep: execSweep,
        execSessions: execSessions,
        luaSweep: luaSweep,
        luaCodeMode: luaCodeMode,
        pluginRuntime: pluginRuntime,
        pluginSources: pluginSources,
        pluginScheduler: pluginScheduler,
        providerAuth: providerAuth,
        providers: providers,
        modelSettings: modelSettings,
        terminals: terminals,
        relay: relay,
        relayTransport: relayTransport,
        notificationSubscriptions: notificationSubscriptions,
      );
    } catch (_) {
      await pluginSources?.close();
      await database.close();
      await lock.unlock();
      await lock.close();
      rethrow;
    }
  }
}

class _LocalDaemonHandle implements DaemonHandle {
  new({
    required this._endpoint,
    required String serverIdValue,
    required this._token,
    required this._http,
    required this._rpc,
    required this._turns,
    required this._database,
    required this._events,
    required this._agentDefinitions,
    required this._mcp,
    required this._skills,
    required this._lock,
    required this._attachmentCleanup,
    required this._execSweep,
    required this._execSessions,
    required this._luaSweep,
    required this._luaCodeMode,
    required this._pluginRuntime,
    required this._pluginSources,
    required this._pluginScheduler,
    required this._providerAuth,
    required this._providers,
    required this._modelSettings,
    required this._terminals,
    required this._relay,
    required this._relayTransport,
    required this._notificationSubscriptions,
  }) : _serverId = serverIdValue;

  final Uri _endpoint;
  final String _serverId;
  final String _token;
  final HttpServer _http;
  final DaemonRpcServer _rpc;
  final SessionTurnCoordinator _turns;
  final TinestDatabase _database;
  final StreamController<OutboundNotification> _events;
  final AgentDefinitionService _agentDefinitions;
  final McpRuntime _mcp;
  final SkillCatalogService _skills;
  final RandomAccessFile _lock;
  final Timer _attachmentCleanup;
  final Timer _execSweep;
  final ExecSessionService _execSessions;
  final Timer _luaSweep;
  final LuaCodeModeService _luaCodeMode;
  final PluginRuntime<ConversationAttachment> _pluginRuntime;
  final NativePluginSourceCatalog _pluginSources;
  final DurablePluginScheduler _pluginScheduler;
  final ProviderAuthCoordinator _providerAuth;
  final ProviderConnectionService _providers;
  final DaemonModelSettingsService _modelSettings;
  final TerminalService _terminals;
  final RelayControlService _relay;
  final DaemonRelayTransport _relayTransport;
  final List<StreamSubscription<Object?>> _notificationSubscriptions;
  bool _stopped = false;

  @override
  Uri get boundEndpoint => _endpoint;
  @override
  String get serverId => _serverId;
  @override
  String get bearerToken => _token;
  @override
  Future<void> get ready => Future<void>.value();

  @override
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _attachmentCleanup.cancel();
    _execSweep.cancel();
    _luaSweep.cancel();
    for (final subscription in _notificationSubscriptions) {
      await subscription.cancel();
    }
    await _http.close(force: true);
    await _rpc.close();
    await _pluginScheduler.close();
    await _turns.close();
    await _execSessions.close();
    await _luaCodeMode.close();
    await _pluginRuntime.close();
    await _pluginSources.close();
    await _terminals.close();
    await _relayTransport.close();
    await _relay.close();
    await _providerAuth.close();
    await _modelSettings.close();
    await _providers.close();
    await _mcp.close();
    await _agentDefinitions.close();
    await _skills.close();
    await _events.close();
    await _database.close();
    await _lock.unlock();
    await _lock.close();
  }
}

final class _StoredProviderModelReferenceUpdater
    implements ProviderModelReferenceUpdater {
  const new(this._sessions, this._agents, this._models);

  final SessionRepository _sessions;
  final AgentDefinitionService _agents;
  final DaemonModelSettingsService _models;

  @override
  Future<void> rewrite(String oldPrefix, String newPrefix) async {
    await _models.rewriteModelPrefix(oldPrefix, newPrefix);
    try {
      await _agents.rewriteModelPrefix(oldPrefix, newPrefix);
    } catch (_) {
      await _models.rewriteModelPrefix(newPrefix, oldPrefix);
      rethrow;
    }
    try {
      await _sessions.rewriteModelPrefix(oldPrefix, newPrefix);
    } catch (_) {
      await _agents.rewriteModelPrefix(newPrefix, oldPrefix);
      await _models.rewriteModelPrefix(newPrefix, oldPrefix);
      rethrow;
    }
  }
}

final class _PluginAgentContributionCatalog
    implements AgentContributionCatalog {
  const new(this._plugins, this._changes);

  final PluginManagementService _plugins;
  final Stream<void> _changes;

  @override
  Stream<void> get changes => _changes;

  @override
  Future<List<PluginDescriptorDto>> listPluginDescriptors() => _plugins.list();
}

final class _TinestLuaClock implements lua.LuaClock {
  const new(this._clock);

  final Clock _clock;

  @override
  DateTime nowUtc() => _clock.nowUtc();
}

final class _TinestLuaIds implements lua.LuaIdGenerator {
  const new(this._ids);

  final IdGenerator _ids;

  @override
  String generate() => _ids.generate();
}

final class _TinestPluginSdkAuthoringProvider
    implements PluginSdkAuthoringProvider {
  const new();

  @override
  int get apiMajor => TinestLuaPluginSdk.apiMajor;

  @override
  Map<String, String> get authoringLibraryAssets =>
      TinestLuaPluginSdk.authoringLibraryAssets;

  @override
  String get luaLanguageServerVersion =>
      TinestLuaPluginSdk.luaLanguageServerVersion;

  @override
  String get luaRuntimeVersion => TinestLuaPluginSdk.luaRuntimeVersion;

  @override
  String get sdkAbiHash => TinestLuaPluginSdk.sdkAbiHash;
}
