import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:app/src/app/composition/app_services.dart';
import 'package:app/src/app/platform/external_url_opener.dart';
import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/app/tinest_app.dart';
import 'package:app/src/features/desktop/infrastructure/desktop_shell.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/hosts/domain/host_ports.dart';
import 'package:app/src/features/settings/domain/settings_category.dart';
import 'package:app/src/shared/presentation/settings_layout.dart';
import 'package:client/client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:relay_protocol/relay_protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../test/support/fake_desktop_ports.dart';
import '../test/support/fake_tinest_api.dart';

// Generate a filtered catalog from packages/app with, for example:
//
//   SETTINGS_CATALOG_PHASE=current
//   SETTINGS_CATALOG_SCENARIOS=settings-home
//   SETTINGS_CATALOG_VIEWPORTS=mobile
//   SETTINGS_CATALOG_VARIANTS=dark-en
//   SETTINGS_CATALOG_SCOPE=state
//   flutter test tool/settings_screen_catalog_test.dart
//
// The plural filters accept comma-separated values, and their singular aliases
// are accepted for one value. Set SETTINGS_CATALOG_BASELINE_PHASE=before while
// generating a later phase to create a deterministic side-by-side PNG for each
// selected capture under that phase's contact-sheets directory.
const _captureBoundary = ValueKey<String>('settings-screen-catalog');

final class _Scenario {
  const new({
    required this.id,
    required this.location,
    this.preparation = _CatalogPreparation.standard,
    this.action = _CatalogAction.none,
    this.expected = const _ExpectedFrame(),
    this.matrixOnly = false,
    this.connected = true,
    this.platform,
  });

  final String id;
  final String location;
  final _CatalogPreparation preparation;
  final _CatalogAction action;
  final _ExpectedFrame expected;
  final bool matrixOnly;
  final bool connected;
  final TargetPlatform? platform;
}

enum _CatalogPreparation {
  standard,
  noDaemon,
  registryLoading,
  registryError,
  empty,
  projectError,
  agentError,
  agentCreateError,
  agentReadOnly,
  skillError,
  mcpError,
  mcpDiagnostic,
  mcpResources,
  mcpReadOnly,
  mcpShadowed,
  providerEmpty,
  providerConnectError,
  providerOAuth,
  providerOAuthError,
  providerCustom,
  providerError,
  providerModelError,
  permissionSaveError,
  permissionError,
  relay,
  daemonPortConflict,
  daemonLaunchError,
  projectLoading,
  agentLoading,
  mcpLoading,
  skillLoading,
  providerLoading,
  permissionLoading,
}

enum _CatalogAction {
  none,
  openProjectDetail,
  openAgentCreate,
  validateAgentCreate,
  failAgentCreate,
  openAgentReadOnly,
  openAgentArchiveDialog,
  openAgentResetDialog,
  openMcpCreate,
  validateMcpCreate,
  openMcpDiagnostic,
  openMcpResources,
  openMcpTemplates,
  openMcpReadOnly,
  openMcpShadowed,
  openMcpSecretDialog,
  openMcpDeleteDialog,
  openProviderCatalog,
  openProviderPreset,
  openProviderCustomCreate,
  openProviderCustomEdit,
  failProviderConnect,
  startProviderOAuth,
  failProviderOAuth,
  openProviderModelError,
  openProviderDisconnectDialog,
  openProviderDeleteDialog,
  openDaemonModelSelect,
  openPermissionSelect,
  failPermissionSave,
  openRelayQrDialog,
  openRelayEndpointDialog,
  openRelayRevokeDialog,
  openAdvancedResetDialog,
  openRemoteHostDeleteDialog,
}

enum _ExpectedOverlay {
  none('none'),
  dialog('dialog'),
  adaptiveSelect('adaptive-select'),
  toast('toast');

  new(this.manifestValue);

  final String manifestValue;
}

enum _CatalogScrollTarget {
  none('none'),
  projectEditor('project-editor'),
  agentModel('agent-model'),
  agentDanger('agent-danger'),
  mcpDiagnostics('mcp-diagnostics'),
  mcpResources('mcp-resources'),
  mcpResourceTemplates('mcp-resource-templates'),
  mcpSecrets('mcp-secrets'),
  mcpDanger('mcp-danger'),
  daemonDefaultModel('daemon-default-model'),
  providerDanger('provider-danger'),
  relayEndpoint('relay-endpoint'),
  relayDevices('relay-devices'),
  advancedDanger('advanced-danger'),
  remoteHostDanger('remote-host-danger');

  new(this.manifestValue);

  final String manifestValue;
}

final class _ExpectedFrame {
  const new({
    this.destination = 'route-default',
    this.state = 'normal',
    this.overlay = _ExpectedOverlay.none,
    this.key,
    this.text,
    this.scrollTarget = _CatalogScrollTarget.none,
  });

  final String destination;
  final String state;
  final _ExpectedOverlay overlay;
  final String? key;
  final String? text;
  final _CatalogScrollTarget scrollTarget;
}

final class _PreparedScenario {
  const new({required this.api, this.providerEvents});

  final FakeTinestApi api;
  final StreamController<ClientEvent>? providerEvents;

  Future<void> dispose() async {
    await providerEvents?.close();
  }
}

enum _CatalogInteraction {
  idle('idle'),
  hover('hover'),
  pressed('pressed'),
  keyboardFocus('keyboard-focus');

  new(this.manifestValue);

  final String manifestValue;
}

enum _ScrollCheckpoint {
  top('top', 0),
  middle('middle', 0.5),
  bottom('bottom', 1);

  new(this.manifestValue, this.fraction);

  final String manifestValue;
  final double fraction;
}

final class _Variant {
  const new({
    required this.id,
    this.themeMode = AppThemeMode.dark,
    this.localeTag = 'en',
    this.textScale = 1,
    this.direction = TextDirection.ltr,
    this.reducedMotion = false,
    this.interaction = _CatalogInteraction.idle,
    this.interactionTargetKey,
    this.scrollCheckpoint = _ScrollCheckpoint.top,
  }) : assert(
         interaction == _CatalogInteraction.idle ||
             interactionTargetKey != null,
         'Interactive catalog variants need a stable target key.',
       );

  final String id;
  final AppThemeMode themeMode;
  final String localeTag;
  final double textScale;
  final TextDirection direction;
  final bool reducedMotion;
  final _CatalogInteraction interaction;
  final String? interactionTargetKey;
  final _ScrollCheckpoint scrollCheckpoint;

  String get theme => switch (themeMode) {
    AppThemeMode.light => 'light',
    AppThemeMode.dark => 'dark',
    AppThemeMode.system => 'system',
  };
}

final class _CaptureCase {
  const new({
    required this.scenario,
    required this.viewport,
    required this.variant,
  });

  final _Scenario scenario;
  final _Viewport viewport;
  final _Variant variant;
}

final class _Viewport {
  const new(this.id, this.size);

  final String id;
  final Size size;
}

FakeTinestApi _defaultApi() {
  final api = FakeTinestApi(
    workspaces: _workspaces,
    worktrees: _worktrees,
    workspaceCatalogResponses: <WorkspaceCatalogDto>[
      WorkspaceCatalogDto(workspaces: _workspaces, worktrees: _worktrees),
    ],
    agentDefinitions: _agentDefinitions,
    skills: _skills,
    projectSkills: _projectSkills,
    connections: _providerConnections,
  );
  api.mcpServers.addEntries(
    _mcpServers.map((server) => MapEntry(server.config.id, server)),
  );
  api.projectSettings.addAll(<String, ProjectSettingsDto>{
    for (final workspace in _workspaces)
      workspace.id: const ProjectSettingsDto(
        setup: <String>['dart pub get'],
        teardown: <String>['dart run melos clean'],
      ),
  });
  return api;
}

FakeTinestApi _emptyApi() => FakeTinestApi(
  workspaces: const <WorkspaceDto>[],
  worktrees: const <WorktreeDto>[],
  agentDefinitions: const <AgentDefinitionDto>[],
  skills: const <SkillSummaryDto>[],
  projectSkills: const <SkillSummaryDto>[],
  connections: const <ProviderConnectionDto>[],
);

_PreparedScenario _prepareScenario(_CatalogPreparation preparation) {
  switch (preparation) {
    case _CatalogPreparation.standard:
    case _CatalogPreparation.noDaemon:
    case _CatalogPreparation.registryLoading:
    case _CatalogPreparation.registryError:
      return _PreparedScenario(api: _defaultApi());
    case _CatalogPreparation.empty:
      return _PreparedScenario(api: _emptyApi());
    case _CatalogPreparation.projectError:
      return _PreparedScenario(
        api: FakeTinestApi(
          workspaces: _workspaces,
          worktrees: _worktrees,
          workspaceCatalogResponses: <WorkspaceCatalogDto>[
            WorkspaceCatalogDto(workspaces: _workspaces, worktrees: _worktrees),
          ],
          projectSettingsError: Exception(
            'Project settings unavailable: deterministic catalog failure',
          ),
        ),
      );
    case _CatalogPreparation.agentError:
      return _PreparedScenario(
        api: FakeTinestApi(
          agentListError: Exception(
            'Agent definitions unavailable: deterministic catalog failure',
          ),
        ),
      );
    case _CatalogPreparation.agentCreateError:
      return _PreparedScenario(
        api: FakeTinestApi(
          agentDefinitions: _agentDefinitions,
          failNextAgentCreate: true,
        ),
      );
    case _CatalogPreparation.agentReadOnly:
      return _PreparedScenario(
        api: FakeTinestApi(
          agentDefinitions: const <AgentDefinitionDto>[
            AgentDefinitionDto(
              version: 5,
              id: 'locked-agent',
              name: 'Locked model agent',
              description: 'Its pinned provider is not connected.',
              mode: AgentMode.primary,
              model: AgentModelSelectionDto(
                source: AgentModelSource.fixed,
                modelId: 'missing/catalog-model',
              ),
              driverId: 'tinest.standard/driver',
              extensionIds: <String>[],
              toolIds: <String>[],
              pluginSettings: <String, Map<String, dynamic>>{},
              callableAgentIds: <String>[],
              prompt: '',
              contentHash: 'locked-agent-hash',
              sourcePath: '/config/agents/locked-agent.md',
              isBuiltIn: true,
            ),
          ],
          connections: const <ProviderConnectionDto>[],
        ),
      );
    case _CatalogPreparation.skillError:
      return _PreparedScenario(
        api: FakeTinestApi(
          skillListError: Exception(
            'Skills unavailable: deterministic catalog failure',
          ),
        ),
      );
    case _CatalogPreparation.mcpError:
      final failure = _catalogFailure(
        'MCP unavailable: deterministic catalog failure',
      );
      return _PreparedScenario(
        // A gate fails every list request. A one-shot response could be
        // consumed by the host bootstrap before the visible MCP controller
        // subscribes, incorrectly turning the audited frame into "empty".
        api: FakeTinestApi(mcpListGate: failure),
      );
    case _CatalogPreparation.mcpDiagnostic:
      final api = FakeTinestApi()
        ..mcpServers['github'] = const McpServerStateDto(
          config: _catalogMcpServer,
          status: McpServerStatus.failed,
          scope: McpConfigScope.user,
          sourcePath: '/config/mcp.json',
          error: 'the server exited with code 127',
          diagnostics: <String>[
            'npx: command not found',
            'Verify the daemon PATH and restart the server.',
          ],
        );
      return _PreparedScenario(api: api);
    case _CatalogPreparation.mcpResources:
      final api = FakeTinestApi()
        ..mcpServers['github'] = _catalogMcpReady.copyWith(
          resources: const <McpResourceSummaryDto>[
            McpResourceSummaryDto(
              uri: 'file:///repo/README.md',
              name: 'README',
              description: 'How to build and test this repository.',
            ),
          ],
          resourceTemplates: const <McpResourceTemplateSummaryDto>[
            McpResourceTemplateSummaryDto(
              uriTemplate: 'file:///repo/{path}',
              name: 'Repository file',
              description: 'Reads a path from the active repository.',
            ),
          ],
        );
      return _PreparedScenario(api: api);
    case _CatalogPreparation.mcpReadOnly:
      final api = FakeTinestApi()
        ..mcpServers['repo'] = _catalogMcpReady.copyWith(
          config: const McpServerConfigDto(
            id: 'repo',
            transport: McpTransportKind.stdio,
            command: './tools/mcp',
          ),
          scope: McpConfigScope.project,
          sourcePath: '/repos/tinest/.mcp.json',
          serverName: 'Repository MCP',
        );
      return _PreparedScenario(api: api);
    case _CatalogPreparation.mcpShadowed:
      final api = FakeTinestApi()
        ..mcpServers['github'] = _catalogMcpReady
        ..mcpServers['repo'] = _catalogMcpReady.copyWith(
          config: const McpServerConfigDto(
            id: 'repo',
            transport: McpTransportKind.stdio,
            command: './tools/mcp',
          ),
          status: McpServerStatus.disabled,
          scope: McpConfigScope.project,
          sourcePath: '/repos/tinest/.mcp.json',
          shadowed: true,
          serverName: 'Shadowed repository MCP',
        );
      return _PreparedScenario(api: api);
    case _CatalogPreparation.providerEmpty:
      return _PreparedScenario(
        api: FakeTinestApi(connections: const <ProviderConnectionDto>[]),
      );
    case _CatalogPreparation.providerConnectError:
      return _PreparedScenario(
        api: FakeTinestApi(
          connections: const <ProviderConnectionDto>[],
          providerConnectError: const TinestClientException(
            'The model prefix is already in use.',
            code: 'model_prefix_conflict',
          ),
        ),
      );
    case _CatalogPreparation.providerOAuth:
      return _PreparedScenario(
        api: FakeTinestApi(connections: const <ProviderConnectionDto>[]),
      );
    case _CatalogPreparation.providerOAuthError:
      final events = StreamController<ClientEvent>.broadcast(sync: true);
      return _PreparedScenario(
        api: FakeTinestApi(
          connections: const <ProviderConnectionDto>[],
          eventStream: events.stream,
        ),
        providerEvents: events,
      );
    case _CatalogPreparation.providerCustom:
      return _PreparedScenario(
        api: FakeTinestApi(
          connections: <ProviderConnectionDto>[_catalogCustomProvider],
          models: const <String, List<ProviderModelDto>>{
            'catalog-lab': <ProviderModelDto>[
              ProviderModelDto(
                connectionId: 'catalog-lab',
                id: 'catalog-lab/model-a',
                providerModelId: 'model-a',
                label: 'Catalog Model A',
                source: ProviderModelSource.manual,
                capabilities: ModelCapabilitiesDto(
                  streaming: CapabilitySupport.supported,
                  toolCalling: CapabilitySupport.supported,
                  source: CapabilitySource.manual,
                ),
              ),
            ],
          },
        ),
      );
    case _CatalogPreparation.providerError:
      return _PreparedScenario(
        api: FakeTinestApi(
          providerConnectionsGate: _catalogFailure(
            'Providers unavailable: deterministic catalog failure',
          ),
        ),
      );
    case _CatalogPreparation.providerModelError:
      return _PreparedScenario(
        api: FakeTinestApi(
          providerModelListError: Exception(
            'Could not list models: deterministic provider failure',
          ),
          connections: <ProviderConnectionDto>[
            ProviderConnectionDto(
              id: 'broken-provider',
              definitionId: 'deepseek',
              modelPrefix: 'broken',
              displayName: 'Unavailable provider',
              status: ProviderConnectionStatus.error,
              authKind: ProviderAuthKind.apiKey,
              credentialOrigin: ProviderCredentialOrigin.stored,
              error: 'Could not list models: deterministic provider failure',
              createdAt: _now,
              updatedAt: _now,
            ),
          ],
        ),
      );
    case _CatalogPreparation.permissionSaveError:
      return _PreparedScenario(
        api: FakeTinestApi(
          defaultPermissionSetError: Exception(
            'daemon rejected the permission update',
          ),
        ),
      );
    case _CatalogPreparation.permissionError:
      return _PreparedScenario(
        api: FakeTinestApi(
          permissionSettingsGate: _catalogFailure(
            'Permissions unavailable: deterministic catalog failure',
          ),
        ),
      );
    case _CatalogPreparation.relay:
      return _PreparedScenario(api: _relayApi());
    case _CatalogPreparation.daemonPortConflict:
    case _CatalogPreparation.daemonLaunchError:
      return _PreparedScenario(api: _defaultApi());
    case _CatalogPreparation.projectLoading:
      return _PreparedScenario(
        api: FakeTinestApi(workspaceCatalogGate: Completer<void>().future),
      );
    case _CatalogPreparation.agentLoading:
      return _PreparedScenario(
        api: FakeTinestApi(agentDefinitionsGate: Completer<void>().future),
      );
    case _CatalogPreparation.mcpLoading:
      return _PreparedScenario(
        api: FakeTinestApi(mcpListGate: Completer<void>().future),
      );
    case _CatalogPreparation.skillLoading:
      return _PreparedScenario(
        api: FakeTinestApi(skillListGate: Completer<void>().future),
      );
    case _CatalogPreparation.providerLoading:
      return _PreparedScenario(
        api: FakeTinestApi(providerConnectionsGate: Completer<void>().future),
      );
    case _CatalogPreparation.permissionLoading:
      return _PreparedScenario(
        api: FakeTinestApi(permissionSettingsGate: Completer<void>().future),
      );
  }
}

Future<void> _catalogFailure(String message) {
  final failure = Future<void>.sync(() => throw Exception(message));
  // The fake consumes this Future after the first widget pump. Attach an
  // eager handler so the test binding never observes an unhandled async error
  // before the visible Settings provider subscribes to the same Future.
  unawaited(failure.then<void>((_) {}, onError: (Object _, StackTrace _) {}));
  return failure;
}

final _now = DateTime.utc(2026, 8, 13);
const _catalogMcpServer = McpServerConfigDto(
  id: 'github',
  transport: McpTransportKind.stdio,
  command: 'npx',
  args: <String>['-y', 'server-github'],
  env: <String, String>{'TOKEN': r'${secret:github.token}'},
);
const _catalogMcpReady = McpServerStateDto(
  config: _catalogMcpServer,
  status: McpServerStatus.ready,
  scope: McpConfigScope.user,
  sourcePath: '/config/mcp.json',
  protocolVersion: '2025-06-18',
  serverName: 'GitHub',
  tools: <McpToolSummaryDto>[
    McpToolSummaryDto(
      toolId: 'mcp__github__echo',
      name: 'echo',
      description: 'Echoes its argument.',
    ),
  ],
);
final _catalogCustomProvider = ProviderConnectionDto(
  id: 'catalog-lab',
  definitionId: 'custom',
  modelPrefix: 'catalog-lab',
  displayName: 'Catalog Lab',
  status: ProviderConnectionStatus.connected,
  authKind: ProviderAuthKind.apiKey,
  credentialOrigin: ProviderCredentialOrigin.stored,
  customConfig: const CustomProviderConfigDto(
    name: 'Catalog Lab',
    baseUrl: 'http://127.0.0.1:9000/v1',
    wireFormatId: 'openai-chat-completions',
    authenticationRequired: true,
    models: <ManualProviderModelDto>[
      ManualProviderModelDto(id: 'model-a', label: 'Catalog Model A'),
    ],
  ),
  createdAt: _now,
  updatedAt: _now,
);

FakeTinestApi _relayApi() => FakeTinestApi(
  serverInfo: const ServerInfoDto(
    serverId: 'relay-server',
    version: 'test',
    protocolVersion: tinestProtocolMajor,
    features: <String, bool>{},
  ),
  relayPairingOffer: RelayPairingOfferDto(
    url: 'https://tinest.tinyrack.net/pair#offer=catalog-offer',
    expiresAt: _now.add(const Duration(minutes: 10)),
  ),
  relayDevices: <RelayDeviceDto>[
    RelayDeviceDto(
      id: 'catalog-phone',
      name: 'Catalog phone',
      registeredAt: _now,
      lastConnectedAt: _now,
    ),
  ],
);

Uri _validPairingUrl() => RelayPairingOffer(
  serverId: 'relay-server',
  relayUri: Uri.parse('wss://relay.tinest.tinyrack.net/v1/ws'),
  daemonPublicKey: List<int>.filled(32, 1),
  offerId: 'catalog-offer',
  secret: List<int>.filled(32, 2),
  expiresAt: DateTime.utc(2100),
).toUrl(Uri.parse('https://tinest.tinyrack.net/pair'));

final _workspaces = List<WorkspaceDto>.unmodifiable(<WorkspaceDto>[
  for (var index = 0; index < 18; index += 1)
    WorkspaceDto(
      id: index == 0 ? 'tinest' : 'project-$index',
      name: index == 0 ? 'Tinest' : 'Project $index',
      rootPath: index == 0 ? '/repos/tinest' : '/repos/project-$index',
      kind: WorkspaceKind.git,
      createdAt: _now,
    ),
]);
final _worktrees = List<WorktreeDto>.unmodifiable(<WorktreeDto>[
  for (final workspace in _workspaces)
    WorktreeDto(
      id: '${workspace.id}-main',
      workspaceId: workspace.id,
      name: 'main',
      path: workspace.rootPath,
      branch: 'main',
      kind: WorktreeKind.checkout,
      isTinestOwned: false,
      createdAt: _now,
    ),
]);
final _agentDefinitions = List<AgentDefinitionDto>.unmodifiable(
  <AgentDefinitionDto>[
    for (var index = 0; index < 18; index += 1)
      AgentDefinitionDto(
        version: 5,
        id: index == 0 ? 'tinest' : 'agent-$index',
        name: index == 0 ? 'Tinest' : 'Agent $index',
        description: index == 0
            ? 'General-purpose coding agent'
            : 'Deterministic catalog agent $index',
        mode: index == 0 ? AgentMode.primary : AgentMode.subagent,
        model: const AgentModelSelectionDto(source: AgentModelSource.session),
        driverId: 'tinest.standard/driver',
        extensionIds: const <String>[],
        toolIds: const <String>['tinest.files/read_file'],
        pluginSettings: const <String, Map<String, dynamic>>{},
        callableAgentIds: const <String>[],
        prompt: 'Use the shared settings visual contract.',
        contentHash: 'agent-$index-hash',
        sourcePath: '/config/agents/agent-$index.md',
        isBuiltIn: index == 0,
      ),
  ],
);
final _skills = List<SkillSummaryDto>.unmodifiable(<SkillSummaryDto>[
  for (var index = 0; index < 18; index += 1)
    SkillSummaryDto(
      id: 'catalog-skill-$index',
      name: 'catalog-skill-$index',
      description: 'Deterministic catalog skill $index.',
      isImplicit: index == 0,
    ),
]);
final _projectSkills = List<SkillSummaryDto>.unmodifiable(<SkillSummaryDto>[
  for (var index = 0; index < 6; index += 1)
    SkillSummaryDto(
      id: 'project-skill-$index',
      name: 'project-skill-$index',
      description: 'Deterministic project skill $index.',
      isImplicit: false,
    ),
]);
final _providerConnections = List<ProviderConnectionDto>.unmodifiable(
  <ProviderConnectionDto>[
    for (var index = 0; index < 18; index += 1)
      ProviderConnectionDto(
        id: index == 0 ? 'openai' : 'provider-$index',
        definitionId: index == 0 ? 'openai' : 'deepseek',
        modelPrefix: index == 0 ? 'openai' : 'provider-$index',
        displayName: index == 0 ? 'OpenAI' : 'Provider $index',
        status: ProviderConnectionStatus.connected,
        authKind: ProviderAuthKind.apiKey,
        credentialOrigin: ProviderCredentialOrigin.stored,
        createdAt: _now,
        updatedAt: _now,
      ),
  ],
);
final _mcpServers = List<McpServerStateDto>.unmodifiable(<McpServerStateDto>[
  for (var index = 0; index < 18; index += 1)
    McpServerStateDto(
      config: McpServerConfigDto(
        id: index == 0 ? 'github' : 'catalog-$index',
        transport: McpTransportKind.stdio,
        command: 'npx',
        args: <String>['-y', 'catalog-mcp-$index'],
      ),
      status: McpServerStatus.ready,
      scope: McpConfigScope.user,
      sourcePath: '/config/mcp.json',
      protocolVersion: '2025-06-18',
      serverName: index == 0 ? 'GitHub' : 'Catalog MCP $index',
      tools: <McpToolSummaryDto>[
        McpToolSummaryDto(
          toolId: 'mcp__catalog_$index',
          name: 'catalog_tool_$index',
          description: 'Deterministic catalog tool $index.',
        ),
      ],
    ),
]);

final _viewports = <_Viewport>[
  const _Viewport('reported-compact', Size(344, 672)),
  const _Viewport('mobile', Size(390, 844)),
  const _Viewport('tablet', Size(800, 900)),
  const _Viewport('desktop', Size(1440, 900)),
];

final _scenarios = <_Scenario>[
  _Scenario(id: 'settings-home', location: const SettingsHomeRoute().location),
  _Scenario(
    id: 'workspaces',
    location: const WorkspaceHomeRoute().location,
    preparation: _CatalogPreparation.empty,
  ),
  _Scenario(
    id: 'settings-home-no-daemon',
    location: const SettingsHomeRoute().location,
    preparation: _CatalogPreparation.noDaemon,
    expected: const _ExpectedFrame(
      destination: 'settings-home',
      state: 'empty',
      text: 'No daemons',
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'settings-registry-loading',
    location: const GeneralSettingsRoute().location,
    preparation: _CatalogPreparation.registryLoading,
    expected: const _ExpectedFrame(
      destination: 'general-settings',
      state: 'loading',
      key: 'settings-skeleton-form',
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'settings-registry-error',
    location: const GeneralSettingsRoute().location,
    preparation: _CatalogPreparation.registryError,
    expected: const _ExpectedFrame(
      destination: 'general-settings',
      state: 'error',
      text: 'registry unavailable',
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'daemon-categories',
    location: const DaemonCategoriesRoute(hostId: 'server').location,
  ),
  _Scenario(id: 'general', location: const GeneralSettingsRoute().location),
  _Scenario(id: 'daemons', location: const DaemonSettingsRoute().location),
  _Scenario(
    id: 'projects',
    location: const ProjectSettingsRoute(hostId: 'server').location,
  ),
  _Scenario(
    id: 'projects-empty',
    location: const ProjectSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.empty,
  ),
  _Scenario(
    id: 'projects-loading',
    location: const ProjectSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.projectLoading,
  ),
  _Scenario(
    id: 'projects-error',
    location: const ProjectSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.projectError,
    action: _CatalogAction.openProjectDetail,
    expected: const _ExpectedFrame(
      destination: 'project-detail',
      state: 'error',
      text: 'Project settings unavailable',
    ),
  ),
  _Scenario(
    id: 'agents',
    location: const AgentSettingsRoute(hostId: 'server').location,
  ),
  _Scenario(
    id: 'agents-empty',
    location: const AgentSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.empty,
  ),
  _Scenario(
    id: 'agents-loading',
    location: const AgentSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.agentLoading,
  ),
  _Scenario(
    id: 'agents-error',
    location: const AgentSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.agentError,
    expected: const _ExpectedFrame(
      state: 'error',
      text: 'Agent definitions unavailable',
    ),
  ),
  _Scenario(
    id: 'mcp',
    location: const McpSettingsRoute(hostId: 'server').location,
  ),
  _Scenario(
    id: 'mcp-empty',
    location: const McpSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.empty,
  ),
  _Scenario(
    id: 'mcp-loading',
    location: const McpSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.mcpLoading,
  ),
  _Scenario(
    id: 'mcp-error',
    location: const McpSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.mcpError,
    expected: const _ExpectedFrame(state: 'error', text: 'MCP unavailable'),
  ),
  _Scenario(
    id: 'connections',
    location: const DaemonConnectionsRoute(hostId: 'server').location,
  ),
  _Scenario(
    id: 'skills',
    location: const SkillSettingsRoute(hostId: 'server').location,
  ),
  _Scenario(
    id: 'skills-project',
    location: const SkillSettingsRoute(
      hostId: 'server',
      workspaceId: 'tinest',
    ).location,
    expected: const _ExpectedFrame(
      state: 'project-only',
      key: 'skill-row-project-skill-0',
      text: 'project-skill-0',
    ),
  ),
  _Scenario(
    id: 'skills-empty',
    location: const SkillSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.empty,
  ),
  _Scenario(
    id: 'skills-loading',
    location: const SkillSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.skillLoading,
  ),
  _Scenario(
    id: 'skills-error',
    location: const SkillSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.skillError,
    expected: const _ExpectedFrame(state: 'error', text: 'Skills unavailable'),
  ),
  _Scenario(
    id: 'providers',
    location: const ProviderSettingsRoute(hostId: 'server').location,
  ),
  _Scenario(
    id: 'providers-empty',
    location: const ProviderSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.providerEmpty,
  ),
  _Scenario(
    id: 'providers-loading',
    location: const ProviderSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.providerLoading,
  ),
  _Scenario(
    id: 'providers-error',
    location: const ProviderSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.providerError,
    expected: const _ExpectedFrame(
      state: 'error',
      key: 'provider-settings-error',
    ),
  ),
  _Scenario(
    id: 'permissions',
    location: const PermissionSettingsRoute(hostId: 'server').location,
  ),
  _Scenario(
    id: 'permissions-loading',
    location: const PermissionSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.permissionLoading,
  ),
  _Scenario(
    id: 'permissions-error',
    location: const PermissionSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.permissionError,
    expected: const _ExpectedFrame(
      state: 'error',
      key: 'permission-settings-error',
    ),
  ),
  _Scenario(id: 'advanced', location: const AdvancedSettingsRoute().location),
  _Scenario(id: 'connect', location: const ConnectDaemonRoute().location),
  _Scenario(id: 'connect-link', location: const PairingLinkRoute().location),
  _Scenario(
    id: 'connect-scan',
    location: const PairingScanRoute().location,
    platform: TargetPlatform.windows,
    expected: const _ExpectedFrame(
      state: 'camera-unavailable',
      key: 'relay-camera-unavailable',
    ),
  ),
  _Scenario(
    id: 'connect-direct',
    location: const AdvancedNewHostRoute().location,
  ),
  _Scenario(id: 'pair-invalid', location: const PairOfferRoute().location),
  _Scenario(
    id: 'remote-host-edit',
    location: const EditHostRoute(hostId: 'server').location,
  ),
  _Scenario(
    id: 'settings-home-offline',
    location: const SettingsHomeRoute().location,
    connected: false,
  ),
  _Scenario(
    id: 'project-detail',
    location: const ProjectSettingsRoute(hostId: 'server').location,
    action: _CatalogAction.openProjectDetail,
    expected: const _ExpectedFrame(
      destination: 'project-detail',
      key: 'project-shell-executable',
      scrollTarget: _CatalogScrollTarget.projectEditor,
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'daemon-port-conflict',
    location: const DaemonSettingsRoute().location,
    preparation: _CatalogPreparation.daemonPortConflict,
    expected: const _ExpectedFrame(
      destination: 'daemon-settings',
      state: 'conflict',
      key: 'embedded-daemon-error',
      text: 'Port 7337',
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'daemon-start-error',
    location: const DaemonSettingsRoute().location,
    preparation: _CatalogPreparation.daemonLaunchError,
    expected: const _ExpectedFrame(
      destination: 'daemon-settings',
      state: 'error',
      key: 'embedded-daemon-error',
      text: 'daemon process exited',
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'agent-create',
    location: const AgentSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.agentCreateError,
    action: _CatalogAction.openAgentCreate,
    expected: const _ExpectedFrame(
      destination: 'agent-create',
      text: 'Add agent',
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'agent-create-validation',
    location: const AgentSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.agentCreateError,
    action: _CatalogAction.validateAgentCreate,
    expected: const _ExpectedFrame(
      destination: 'agent-create',
      state: 'validation-error',
      text: 'Only lowercase letters',
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'agent-create-error',
    location: const AgentSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.agentCreateError,
    action: _CatalogAction.failAgentCreate,
    expected: const _ExpectedFrame(
      destination: 'agent-create',
      state: 'error',
      text: 'agent_create_failed',
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'agent-read-only-model-error',
    location: const AgentSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.agentReadOnly,
    action: _CatalogAction.openAgentReadOnly,
    expected: const _ExpectedFrame(
      destination: 'agent-detail',
      state: 'read-only-error',
      key: 'agent-settings-model-selector',
      scrollTarget: _CatalogScrollTarget.agentModel,
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'agent-archive-confirm',
    location: const AgentSettingsRoute(hostId: 'server').location,
    action: _CatalogAction.openAgentArchiveDialog,
    expected: const _ExpectedFrame(
      destination: 'agent-detail',
      state: 'destructive-confirm',
      overlay: _ExpectedOverlay.dialog,
      key: 'agent-archive-confirm',
      scrollTarget: _CatalogScrollTarget.agentDanger,
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'agent-reset-confirm',
    location: const AgentSettingsRoute(hostId: 'server').location,
    action: _CatalogAction.openAgentResetDialog,
    expected: const _ExpectedFrame(
      destination: 'agent-detail',
      state: 'destructive-confirm',
      overlay: _ExpectedOverlay.dialog,
      key: 'agent-reset-confirm',
      scrollTarget: _CatalogScrollTarget.agentDanger,
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'mcp-create',
    location: const McpSettingsRoute(hostId: 'server').location,
    action: _CatalogAction.openMcpCreate,
    expected: const _ExpectedFrame(
      destination: 'mcp-create',
      key: 'mcp-field-id',
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'mcp-create-validation',
    location: const McpSettingsRoute(hostId: 'server').location,
    action: _CatalogAction.validateMcpCreate,
    expected: const _ExpectedFrame(
      destination: 'mcp-create',
      state: 'validation-error',
      key: 'mcp-editor-error',
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'mcp-diagnostic',
    location: const McpSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.mcpDiagnostic,
    action: _CatalogAction.openMcpDiagnostic,
    expected: const _ExpectedFrame(
      destination: 'mcp-detail',
      state: 'diagnostic-error',
      key: 'mcp-server-diagnostics',
      scrollTarget: _CatalogScrollTarget.mcpDiagnostics,
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'mcp-resources',
    location: const McpSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.mcpResources,
    action: _CatalogAction.openMcpResources,
    expected: const _ExpectedFrame(
      destination: 'mcp-detail',
      state: 'resources-expanded',
      key: 'mcp-resource-tile-file:///repo/README.md',
      scrollTarget: _CatalogScrollTarget.mcpResources,
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'mcp-resource-templates',
    location: const McpSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.mcpResources,
    action: _CatalogAction.openMcpTemplates,
    expected: const _ExpectedFrame(
      destination: 'mcp-detail',
      state: 'resource-templates-expanded',
      key: 'mcp-resource-template-tile-file:///repo/{path}',
      scrollTarget: _CatalogScrollTarget.mcpResourceTemplates,
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'mcp-read-only',
    location: const McpSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.mcpReadOnly,
    action: _CatalogAction.openMcpReadOnly,
    expected: const _ExpectedFrame(
      destination: 'mcp-detail',
      state: 'read-only',
      key: 'mcp-server-readonly',
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'mcp-shadowed',
    location: const McpSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.mcpShadowed,
    action: _CatalogAction.openMcpShadowed,
    expected: const _ExpectedFrame(
      destination: 'mcp-detail',
      state: 'shadowed',
      key: 'mcp-server-shadowed-repo',
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'mcp-secret-dialog',
    location: const McpSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.mcpResources,
    action: _CatalogAction.openMcpSecretDialog,
    expected: const _ExpectedFrame(
      destination: 'mcp-detail',
      state: 'secret-entry',
      overlay: _ExpectedOverlay.dialog,
      key: 'mcp-secret-key',
      scrollTarget: _CatalogScrollTarget.mcpSecrets,
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'mcp-delete-confirm',
    location: const McpSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.mcpResources,
    action: _CatalogAction.openMcpDeleteDialog,
    expected: const _ExpectedFrame(
      destination: 'mcp-detail',
      state: 'destructive-confirm',
      overlay: _ExpectedOverlay.dialog,
      key: 'mcp-delete-dialog',
      scrollTarget: _CatalogScrollTarget.mcpDanger,
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'provider-catalog',
    location: const ProviderSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.providerEmpty,
    action: _CatalogAction.openProviderCatalog,
    expected: const _ExpectedFrame(
      destination: 'provider-catalog',
      key: 'provider-add-openai',
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'provider-preset-create',
    location: const ProviderSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.providerEmpty,
    action: _CatalogAction.openProviderPreset,
    expected: const _ExpectedFrame(
      destination: 'provider-preset-create',
      key: 'provider-connect-submit',
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'provider-connect-error',
    location: const ProviderSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.providerConnectError,
    action: _CatalogAction.failProviderConnect,
    expected: const _ExpectedFrame(
      destination: 'provider-preset-create',
      state: 'error',
      text: 'model prefix is already in use',
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'provider-custom-create',
    location: const ProviderSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.providerEmpty,
    action: _CatalogAction.openProviderCustomCreate,
    expected: const _ExpectedFrame(
      destination: 'provider-custom-create',
      key: 'provider-custom-save',
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'provider-custom-edit',
    location: const ProviderSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.providerCustom,
    action: _CatalogAction.openProviderCustomEdit,
    expected: const _ExpectedFrame(
      destination: 'provider-custom-edit',
      key: 'provider-custom-save',
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'provider-oauth-waiting',
    location: const ProviderSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.providerOAuth,
    action: _CatalogAction.startProviderOAuth,
    expected: const _ExpectedFrame(
      destination: 'provider-oauth',
      state: 'waiting',
      key: 'provider-oauth-open-browser',
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'provider-oauth-error',
    location: const ProviderSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.providerOAuthError,
    action: _CatalogAction.failProviderOAuth,
    expected: const _ExpectedFrame(
      destination: 'provider-oauth',
      state: 'error',
      text: 'planned authorization failure',
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'provider-model-error',
    location: const ProviderSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.providerModelError,
    action: _CatalogAction.openProviderModelError,
    expected: const _ExpectedFrame(
      destination: 'provider-detail',
      state: 'error',
      text: 'Could not list models',
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'daemon-model-select',
    location: const ModelSettingsRoute(hostId: 'server').location,
    action: _CatalogAction.openDaemonModelSelect,
    expected: const _ExpectedFrame(
      destination: 'model-settings',
      state: 'selection-open',
      overlay: _ExpectedOverlay.adaptiveSelect,
      key: 'model-option-openai-gpt-5.6-sol',
      scrollTarget: _CatalogScrollTarget.daemonDefaultModel,
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'provider-disconnect-confirm',
    location: const ProviderSettingsRoute(hostId: 'server').location,
    action: _CatalogAction.openProviderDisconnectDialog,
    expected: const _ExpectedFrame(
      destination: 'provider-detail',
      state: 'destructive-confirm',
      overlay: _ExpectedOverlay.dialog,
      text: 'Disconnect OpenAI?',
      scrollTarget: _CatalogScrollTarget.providerDanger,
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'provider-delete-confirm',
    location: const ProviderSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.providerCustom,
    action: _CatalogAction.openProviderDeleteDialog,
    expected: const _ExpectedFrame(
      destination: 'provider-custom-edit',
      state: 'destructive-confirm',
      overlay: _ExpectedOverlay.dialog,
      text: 'Delete Catalog Lab',
      scrollTarget: _CatalogScrollTarget.providerDanger,
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'permission-select-open',
    location: const PermissionSettingsRoute(hostId: 'server').location,
    action: _CatalogAction.openPermissionSelect,
    expected: const _ExpectedFrame(
      destination: 'permission-detail',
      state: 'selection-open',
      overlay: _ExpectedOverlay.adaptiveSelect,
      key: 'permission-option-fullAccess',
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'permission-save-error',
    location: const PermissionSettingsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.permissionSaveError,
    action: _CatalogAction.failPermissionSave,
    expected: const _ExpectedFrame(
      destination: 'permission-detail',
      state: 'error-toast',
      overlay: _ExpectedOverlay.toast,
      text: 'Could not update default permissions',
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'relay-valid-review',
    location: _validPairingUrl().toString(),
    preparation: _CatalogPreparation.relay,
    expected: const _ExpectedFrame(
      destination: 'pair-review',
      state: 'valid',
      key: 'relay-pair-submit',
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'relay-qr-dialog',
    location: const DaemonConnectionsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.relay,
    action: _CatalogAction.openRelayQrDialog,
    expected: const _ExpectedFrame(
      destination: 'connection-settings',
      state: 'qr-offer',
      overlay: _ExpectedOverlay.dialog,
      key: 'relay-dialog-close',
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'relay-endpoint-dialog',
    location: const DaemonConnectionsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.relay,
    action: _CatalogAction.openRelayEndpointDialog,
    expected: const _ExpectedFrame(
      destination: 'connection-settings',
      state: 'endpoint-edit',
      overlay: _ExpectedOverlay.adaptiveSelect,
      key: 'relay-endpoint',
      scrollTarget: _CatalogScrollTarget.relayEndpoint,
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'relay-revoke-confirm',
    location: const DaemonConnectionsRoute(hostId: 'server').location,
    preparation: _CatalogPreparation.relay,
    action: _CatalogAction.openRelayRevokeDialog,
    expected: const _ExpectedFrame(
      destination: 'connection-settings',
      state: 'destructive-confirm',
      overlay: _ExpectedOverlay.dialog,
      text: 'Catalog phone',
      scrollTarget: _CatalogScrollTarget.relayDevices,
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'advanced-reset-confirm',
    location: const AdvancedSettingsRoute().location,
    action: _CatalogAction.openAdvancedResetDialog,
    expected: const _ExpectedFrame(
      destination: 'advanced',
      state: 'destructive-confirm',
      overlay: _ExpectedOverlay.dialog,
      key: 'advanced-reset-confirm-dialog',
      scrollTarget: _CatalogScrollTarget.advancedDanger,
    ),
    matrixOnly: true,
  ),
  _Scenario(
    id: 'remote-host-delete-confirm',
    location: const EditHostRoute(hostId: 'server').location,
    action: _CatalogAction.openRemoteHostDeleteDialog,
    expected: const _ExpectedFrame(
      destination: 'remote-host-edit',
      state: 'destructive-confirm',
      overlay: _ExpectedOverlay.dialog,
      text: 'Delete',
      scrollTarget: _CatalogScrollTarget.remoteHostDanger,
    ),
    matrixOnly: true,
  ),
];

const _baseVariant = _Variant(id: 'dark-en');
const _normalVariants = <_Variant>[
  _Variant(id: 'light-en', themeMode: AppThemeMode.light),
  _Variant(id: 'dark-ko', localeTag: 'ko'),
  _Variant(id: 'dark-ja', localeTag: 'ja'),
];
const _environmentVariants = <_Variant>[
  _Variant(id: 'text-scale-1.5', textScale: 1.5),
  _Variant(id: 'text-scale-2.0', textScale: 2),
  _Variant(id: 'rtl', direction: TextDirection.rtl),
  _Variant(id: 'reduced-motion', reducedMotion: true),
];
const _scrollVariants = <_Variant>[
  _Variant(id: 'scroll-middle', scrollCheckpoint: _ScrollCheckpoint.middle),
  _Variant(id: 'scroll-bottom', scrollCheckpoint: _ScrollCheckpoint.bottom),
];
const _settingsInteractionTargetKey = 'settings-category-row-daemon';
const _interactionVariants = <_Variant>[
  _Variant(
    id: 'navigation-hover',
    interaction: _CatalogInteraction.hover,
    interactionTargetKey: _settingsInteractionTargetKey,
  ),
  _Variant(
    id: 'navigation-pressed',
    interaction: _CatalogInteraction.pressed,
    interactionTargetKey: _settingsInteractionTargetKey,
  ),
  _Variant(
    id: 'navigation-keyboard-focus',
    interaction: _CatalogInteraction.keyboardFocus,
    interactionTargetKey: _settingsInteractionTargetKey,
  ),
];

const _normalScenarioIds = <String>{
  'settings-home',
  'daemon-categories',
  'general',
  'daemons',
  'projects',
  'agents',
  'mcp',
  'connections',
  'skills',
  'providers',
  'permissions',
  'advanced',
  'connect',
  'connect-link',
  'connect-scan',
  'connect-direct',
  'remote-host-edit',
};
const _environmentScenarioIds = <String>{
  'projects',
  'agents',
  'mcp',
  'providers',
  'permissions',
  'advanced',
  'connect-direct',
};
const _longListScenarioIds = <String>{'projects', 'agents', 'mcp', 'providers'};
const _matrixViewportIds = <String>{'mobile', 'desktop'};
const _stateViewportIds = <String>{
  'reported-compact',
  'mobile',
  'tablet',
  'desktop',
};

List<_CaptureCase> _catalogCases() {
  final byId = <String, _Scenario>{
    for (final scenario in _scenarios) scenario.id: scenario,
  };
  final viewportById = <String, _Viewport>{
    for (final viewport in _viewports) viewport.id: viewport,
  };
  final result = <_CaptureCase>[
    for (final scenario in _scenarios)
      if (!scenario.matrixOnly)
        for (final viewport in _viewports)
          _CaptureCase(
            scenario: scenario,
            viewport: viewport,
            variant: _baseVariant,
          ),
    for (final scenario in _scenarios)
      if (scenario.matrixOnly)
        for (final viewportId in _stateViewportIds)
          _CaptureCase(
            scenario: scenario,
            viewport: viewportById[viewportId]!,
            variant: _baseVariant,
          ),
    for (final scenarioId in _normalScenarioIds)
      for (final viewportId in _matrixViewportIds)
        for (final variant in _normalVariants)
          _CaptureCase(
            scenario: byId[scenarioId]!,
            viewport: viewportById[viewportId]!,
            variant: variant,
          ),
    for (final scenarioId in _environmentScenarioIds)
      for (final viewportId in _matrixViewportIds)
        for (final variant in _environmentVariants)
          _CaptureCase(
            scenario: byId[scenarioId]!,
            viewport: viewportById[viewportId]!,
            variant: variant,
          ),
    for (final scenarioId in _longListScenarioIds)
      for (final viewportId in _matrixViewportIds)
        for (final variant in _scrollVariants)
          _CaptureCase(
            scenario: byId[scenarioId]!,
            viewport: viewportById[viewportId]!,
            variant: variant,
          ),
    for (final viewportId in _matrixViewportIds)
      for (final variant in _interactionVariants)
        _CaptureCase(
          scenario: byId['settings-home']!,
          viewport: viewportById[viewportId]!,
          variant: variant,
        ),
  ];
  assert(
    result.map(_captureIdentity).toSet().length == result.length,
    'The Settings screen catalog matrix contains duplicate captures.',
  );
  return List<_CaptureCase>.unmodifiable(result);
}

String _captureIdentity(_CaptureCase capture) =>
    '${capture.scenario.id}/${capture.viewport.id}/${capture.variant.id}';

String? _manifestExpectedKey(_CaptureCase capture) =>
    capture.scenario.expected.key ?? capture.variant.interactionTargetKey;

AppServices _catalogServices({
  required _Scenario scenario,
  required FakeTinestApi api,
  required MemoryAppStore store,
}) {
  final registrySettings = switch (scenario.preparation) {
    _CatalogPreparation.noDaemon => store,
    _CatalogPreparation.registryLoading => _CatalogLoadingSettingsRepository(
      store,
    ),
    _CatalogPreparation.registryError => _CatalogErrorSettingsRepository(store),
    _ => null,
  };
  if (registrySettings != null) {
    return AppServices(
      settings: registrySettings,
      profiles: store,
      credentials: store,
      clients: _CatalogHostClientFactory(api),
      clientKind: 'catalog',
    );
  }
  final base = fakeAppServices(
    api,
    connected: scenario.connected,
    store: store,
  );
  final clients = scenario.preparation == _CatalogPreparation.mcpError
      ? _CatalogHostClientFactory(_CatalogMcpErrorApi(api))
      : base.clients;
  final failure = switch (scenario.preparation) {
    _CatalogPreparation.daemonPortConflict =>
      const HostConnectionFailure.network(
        'socket bind failed on 127.0.0.1:7337',
        reason: HostFailureReason.embeddedPortInUse,
      ),
    _CatalogPreparation.daemonLaunchError =>
      const HostConnectionFailure.network(
        'daemon process exited before it became ready',
      ),
    _ => null,
  };
  if (failure == null && identical(clients, base.clients)) return base;
  if (failure != null) {
    store.settings = store.settings.copyWith(embeddedDaemonEnabled: true);
  }
  return AppServices(
    settings: base.settings,
    profiles: base.profiles,
    credentials: base.credentials,
    clients: clients,
    clientKind: base.clientKind,
    embeddedLauncher: failure == null
        ? base.embeddedLauncher
        : _CatalogFailingLauncher(failure),
    delay: base.delay,
    pathProbeScheduler: base.pathProbeScheduler,
    relayPairer: base.relayPairer,
  );
}

final class _CatalogLoadingSettingsRepository implements AppSettingsRepository {
  new(this.delegate);

  final MemoryAppStore delegate;
  final Completer<AppSettings> _gate = Completer<AppSettings>();

  @override
  Future<void> clear() => delegate.clear();

  @override
  Future<AppSettings> loadSettings() => _gate.future;

  @override
  Future<void> saveSettings(AppSettings settings) =>
      delegate.saveSettings(settings);
}

final class _CatalogErrorSettingsRepository implements AppSettingsRepository {
  const new(this.delegate);

  final MemoryAppStore delegate;

  @override
  Future<void> clear() => delegate.clear();

  @override
  Future<AppSettings> loadSettings() async =>
      throw StateError('registry unavailable');

  @override
  Future<void> saveSettings(AppSettings settings) =>
      delegate.saveSettings(settings);
}

final class _CatalogFailingLauncher implements EmbeddedDaemonLauncher {
  const new(this.failure);

  final HostConnectionFailure failure;

  @override
  Future<EmbeddedDaemonSession> start({
    required EmbeddedDaemonExposure exposure,
    required int port,
  }) => Future<EmbeddedDaemonSession>.error(failure);
}

final class _CatalogExternalUrlOpener implements ExternalUrlOpener {
  const new();

  @override
  Future<bool> open(Uri uri) async => true;
}

final class _CatalogHostClientFactory implements HostClientFactory {
  const new(this.api);

  final TinestApi api;

  @override
  Future<TinestApi> connect({
    required HostConnection connection,
    required HostConnectionCredential credential,
    required String clientId,
    required String clientKind,
  }) async => api;
}

final class _CatalogMcpErrorApi implements TinestApi {
  const new(this.delegate);

  final TinestApi delegate;

  @override
  WorkspacesApi get workspaces => delegate.workspaces;
  @override
  SessionsApi get sessions => delegate.sessions;
  @override
  AgentsApi get agents => delegate.agents;
  @override
  PluginsApi get plugins => delegate.plugins;
  @override
  PromptsApi get prompts => delegate.prompts;
  @override
  ModelsApi get models => delegate.models;
  @override
  ProvidersApi get providers => delegate.providers;
  @override
  McpApi get mcp => _CatalogFailingMcpApi(delegate.mcp);
  @override
  TerminalsApi get terminals => delegate.terminals;
  @override
  AttachmentsApi get attachments => delegate.attachments;
  @override
  RelayApi get relay => delegate.relay;
  @override
  Stream<ClientConnectionState> get states => delegate.states;
  @override
  ServerInfoDto get serverInfo => delegate.serverInfo;
  @override
  Future<void> close() => delegate.close();
}

final class _CatalogFailingMcpApi implements McpApi {
  const new(this.delegate);

  final McpApi delegate;

  @override
  Stream<void> get serverChanges => delegate.serverChanges;

  @override
  Future<List<McpServerStateDto>> listMcpServers({String? worktreeId}) async {
    await Future<void>.delayed(Duration.zero);
    throw StateError('MCP unavailable: deterministic catalog failure');
  }

  @override
  Future<McpServerStateDto> addMcpServer(McpServerConfigDto server) =>
      delegate.addMcpServer(server);
  @override
  Future<McpServerStateDto> updateMcpServer(McpServerConfigDto server) =>
      delegate.updateMcpServer(server);
  @override
  Future<void> removeMcpServer(String id) => delegate.removeMcpServer(id);
  @override
  Future<McpServerStateDto> testMcpServer(McpServerConfigDto server) =>
      delegate.testMcpServer(server);
  @override
  Future<void> setMcpSecret(String key, String value) =>
      delegate.setMcpSecret(key, value);
}

void main() {
  test('state catalog scenarios declare an auditable frame contract', () {
    final stateScenarios = _scenarios
        .where((scenario) => scenario.matrixOnly)
        .toList(growable: false);
    expect(stateScenarios, isNotEmpty);
    expect(
      stateScenarios.map((scenario) => scenario.id).toSet(),
      hasLength(stateScenarios.length),
    );
    for (final scenario in stateScenarios) {
      expect(
        scenario.expected.destination,
        isNot('route-default'),
        reason: '${scenario.id} needs an expected destination.',
      );
      expect(
        scenario.action != _CatalogAction.none ||
            scenario.preparation != _CatalogPreparation.standard ||
            scenario.expected.state != 'normal',
        isTrue,
        reason: '${scenario.id} must prepare, act, or assert a named state.',
      );
      if (scenario.expected.state.contains('error')) {
        expect(
          scenario.expected.key != null || scenario.expected.text != null,
          isTrue,
          reason: '${scenario.id} needs visible error evidence.',
        );
      }
    }
    final captures = _catalogCases();
    for (final scenario in stateScenarios) {
      final viewports = captures
          .where((capture) => capture.scenario.id == scenario.id)
          .map((capture) => capture.viewport.id)
          .toSet();
      expect(
        viewports,
        _stateViewportIds,
        reason: '${scenario.id} needs every adaptive viewport frame.',
      );
    }
  });

  test('Settings shell catalog covers deterministic empty, loading, and error '
      'registry states at every adaptive viewport', () {
    const expectedStates = <String, ({String preparation, String state})>{
      'settings-home-no-daemon': (preparation: 'noDaemon', state: 'empty'),
      'settings-registry-loading': (
        preparation: 'registryLoading',
        state: 'loading',
      ),
      'settings-registry-error': (preparation: 'registryError', state: 'error'),
    };
    final scenariosById = <String, _Scenario>{
      for (final scenario in _scenarios) scenario.id: scenario,
    };
    final captures = _catalogCases();

    for (final MapEntry(key: id, value: contract) in expectedStates.entries) {
      final scenario = scenariosById[id];
      expect(scenario, isNotNull, reason: '$id must be catalogued.');
      expect(scenario!.matrixOnly, isTrue);
      expect(scenario.preparation.name, contract.preparation);
      expect(scenario.expected.state, contract.state);
      expect(
        captures
            .where((capture) => capture.scenario.id == id)
            .map((capture) => capture.viewport.id)
            .toSet(),
        _stateViewportIds,
        reason: '$id needs every adaptive viewport frame.',
      );
    }
  });

  test(
    'interaction catalog records its stable navigation target in manifest',
    () {
      final interactions = _catalogCases()
          .where(
            (capture) =>
                capture.variant.interaction != _CatalogInteraction.idle,
          )
          .toList(growable: false);
      expect(interactions, isNotEmpty);
      for (final capture in interactions) {
        expect(
          capture.variant.interactionTargetKey,
          _settingsInteractionTargetKey,
        );
        expect(_manifestExpectedKey(capture), _settingsInteractionTargetKey);
        expect(capture.scenario.id, 'settings-home');
      }
    },
  );

  for (final interaction in const <_CatalogInteraction>{
    _CatalogInteraction.hover,
    _CatalogInteraction.pressed,
    _CatalogInteraction.keyboardFocus,
  }) {
    testWidgets(
      '${interaction.manifestValue} catalog interaction targets the stable '
      'non-selected daemon settings row',
      (tester) async {
        await _loadPackageFontAliases();
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size(1440, 900);
        addTearDown(tester.view.reset);
        final store = MemoryAppStore(
          settings: const AppSettings(
            embeddedDaemonEnabled: false,
            themeMode: AppThemeMode.dark,
            localeTag: 'en',
          ),
        );
        final prepared = _prepareScenario(_CatalogPreparation.standard);
        addTearDown(prepared.dispose);
        await tester.pumpWidget(
          RepaintBoundary(
            key: _captureBoundary,
            child: TinestApp(
              services: _catalogServices(
                scenario: _scenarios.first,
                api: prepared.api,
                store: store,
              ),
              desktopWindow: FakeDesktopWindow(
                chrome: DesktopWindowChrome.custom,
              ),
              autostart: FakeAutostartRegistration(),
              externalUrlOpener: const _CatalogExternalUrlOpener(),
              initialLocation: const SettingsHomeRoute().location,
            ),
          ),
        );
        await _pumpCatalogFrame(tester);

        final cleanup = await _applyInteraction(
          tester,
          interaction,
          targetKey: _settingsInteractionTargetKey,
        );
        addTearDown(() async => await cleanup?.call());
        final target = _byKey('settings-category-row-daemon');
        expect(target, findsOneWidget);
        final surface = find
            .descendant(of: target, matching: find.byType(AnimatedContainer))
            .first;
        final theme = tester.element(target).tinyrackTheme;
        final expectedColor = switch (interaction) {
          _CatalogInteraction.pressed => theme.surfacePressed,
          _CatalogInteraction.hover ||
          _CatalogInteraction.keyboardFocus => theme.surfaceHover,
          _CatalogInteraction.idle => throw StateError(
            'Idle is not an interaction test case.',
          ),
        };
        expect(
          (tester.widget<AnimatedContainer>(surface).decoration
                  as BoxDecoration?)
              ?.color,
          expectedColor,
        );
        if (interaction == _CatalogInteraction.keyboardFocus) {
          final focus = tester.widget<Focus>(
            find.descendant(of: target, matching: find.byType(Focus)).first,
          );
          expect(focus.focusNode?.hasPrimaryFocus, isTrue);
        }
      },
    );
  }

  test(
    'MCP error preparation fails every list request deterministically',
    () async {
      final prepared = _prepareScenario(_CatalogPreparation.mcpError);
      addTearDown(prepared.dispose);
      final api = _CatalogMcpErrorApi(prepared.api);
      for (var attempt = 0; attempt < 2; attempt += 1) {
        await expectLater(api.mcp.listMcpServers(), throwsA(isA<StateError>()));
      }
    },
  );

  testWidgets('generate deterministic Settings visual catalog', (tester) async {
    await _loadPackageFontAliases();
    final phase = Platform.environment['SETTINGS_CATALOG_PHASE'] ?? 'current';
    _validatePhase(phase, variable: 'SETTINGS_CATALOG_PHASE');
    final baselinePhase =
        Platform.environment['SETTINGS_CATALOG_BASELINE_PHASE'];
    if (baselinePhase != null) {
      _validatePhase(
        baselinePhase,
        variable: 'SETTINGS_CATALOG_BASELINE_PHASE',
      );
      if (baselinePhase == phase) {
        throw StateError(
          'SETTINGS_CATALOG_BASELINE_PHASE must differ from '
          'SETTINGS_CATALOG_PHASE.',
        );
      }
    }
    final scenarioFilter = _environmentFilter(
      'SETTINGS_CATALOG_SCENARIOS',
      alias: 'SETTINGS_CATALOG_SCENARIO',
    );
    final viewportFilter = _environmentFilter(
      'SETTINGS_CATALOG_VIEWPORTS',
      alias: 'SETTINGS_CATALOG_VIEWPORT',
    );
    final variantFilter = _environmentFilter(
      'SETTINGS_CATALOG_VARIANTS',
      alias: 'SETTINGS_CATALOG_VARIANT',
    );
    final scope = Platform.environment['SETTINGS_CATALOG_SCOPE'] ?? 'all';
    if (!const <String>{'all', 'base', 'state'}.contains(scope)) {
      throw StateError('SETTINGS_CATALOG_SCOPE must be all, base, or state.');
    }
    final cases = _catalogCases()
        .where(
          (capture) =>
              (scope == 'all' ||
                  (scope == 'state') == capture.scenario.matrixOnly) &&
              (scenarioFilter.isEmpty ||
                  scenarioFilter.contains(capture.scenario.id)) &&
              (viewportFilter.isEmpty ||
                  viewportFilter.contains(capture.viewport.id)) &&
              (variantFilter.isEmpty ||
                  variantFilter.contains(capture.variant.id)),
        )
        .toList(growable: false);
    if (scenarioFilter.isNotEmpty &&
        !_scenarios.any((scenario) => scenarioFilter.contains(scenario.id))) {
      throw StateError(
        'SETTINGS_CATALOG_SCENARIOS did not match a catalog scenario.',
      );
    }
    if (viewportFilter.isNotEmpty &&
        !_viewports.any((viewport) => viewportFilter.contains(viewport.id))) {
      throw StateError(
        'SETTINGS_CATALOG_VIEWPORTS did not match a catalog viewport.',
      );
    }
    final variantIds = _catalogCases()
        .map((capture) => capture.variant.id)
        .toSet();
    if (variantFilter.isNotEmpty && !variantFilter.any(variantIds.contains)) {
      throw StateError(
        'SETTINGS_CATALOG_VARIANTS did not match a catalog variant.',
      );
    }
    if (cases.isEmpty) {
      throw StateError(
        'The selected scenario, viewport, and variant filters do not '
        'intersect.',
      );
    }
    final root = Directory('build/settings-screen-catalog/$phase');
    if (root.existsSync()) root.deleteSync(recursive: true);
    root.createSync(recursive: true);
    final manifest = <Map<String, Object?>>[];
    final contactSheets = <Map<String, Object?>>[];

    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = cases.first.viewport.size;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    for (final catalogCase in cases) {
      await _captureCase(
        tester: tester,
        catalogCase: catalogCase,
        root: root,
        phase: phase,
        manifest: manifest,
        contactSheets: contactSheets,
      );
    }

    if (baselinePhase != null) {
      await _generateContactSheets(
        tester: tester,
        root: root,
        phase: phase,
        baselinePhase: baselinePhase,
        captures: manifest,
        contactSheets: contactSheets,
      );
    }

    expect(manifest, hasLength(cases.length));
    expect(
      manifest.every((capture) => (capture['byteLength']! as int) > 0),
      isTrue,
    );
    expect(
      contactSheets,
      baselinePhase == null ? isEmpty : hasLength(cases.length),
    );
    expect(
      contactSheets.every(
        (sheet) =>
            sheet['status'] == 'captured' && (sheet['byteLength']! as int) > 0,
      ),
      isTrue,
    );
  }, timeout: const Timeout(Duration(minutes: 45)));
}

Future<void> _captureCase({
  required WidgetTester tester,
  required _CaptureCase catalogCase,
  required Directory root,
  required String phase,
  required List<Map<String, Object?>> manifest,
  required List<Map<String, Object?>> contactSheets,
}) async {
  final scenario = catalogCase.scenario;
  final viewport = catalogCase.viewport;
  final variant = catalogCase.variant;
  tester.view.physicalSize = viewport.size;
  tester.platformDispatcher.textScaleFactorTestValue = variant.textScale;
  tester.platformDispatcher.platformBrightnessTestValue =
      variant.themeMode == AppThemeMode.light
      ? Brightness.light
      : Brightness.dark;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(
        disableAnimations: variant.reducedMotion,
        reduceMotion: variant.reducedMotion,
      );
  final store = MemoryAppStore(
    settings: AppSettings(
      embeddedDaemonEnabled: false,
      localeTag: variant.localeTag,
      themeMode: variant.themeMode,
    ),
  );
  final window = FakeDesktopWindow(chrome: DesktopWindowChrome.custom);
  final prepared = _prepareScenario(scenario.preparation);
  final api = prepared.api;
  final services = _catalogServices(scenario: scenario, api: api, store: store);
  Future<void> Function()? interactionCleanup;
  try {
    debugDefaultTargetPlatformOverride = scenario.platform;
    final app = TinestApp(
      services: services,
      desktopWindow: window,
      autostart: FakeAutostartRegistration(),
      externalUrlOpener: const _CatalogExternalUrlOpener(),
      initialLocation: scenario.location,
    );
    await tester.pumpWidget(RepaintBoundary(key: _captureBoundary, child: app));
    await _pumpCatalogFrame(tester);
    if (variant.direction == TextDirection.rtl) {
      await _forceDirection(tester, variant.direction);
      await _pumpCatalogFrame(tester);
    }
    await _openRepresentativeDetail(tester, catalogCase);
    await _applyScenarioAction(tester, scenario: scenario, prepared: prepared);
    await _applyScrollCheckpoint(tester, variant.scrollCheckpoint);
    interactionCleanup = await _applyInteraction(
      tester,
      variant.interaction,
      targetKey: variant.interactionTargetKey,
    );

    final fileName = '${scenario.id}__${viewport.id}__${variant.id}.png';
    final output = File('${root.path}/$fileName');
    final capture = <String, Object?>{
      'scenario': scenario.id,
      'route': scenario.location,
      'viewport': viewport.id,
      'variant': variant.id,
      'width': viewport.size.width,
      'height': viewport.size.height,
      'devicePixelRatio': 1,
      'theme': variant.theme,
      'locale': variant.localeTag,
      'textScale': variant.textScale,
      'direction': variant.direction.name,
      'reducedMotion': variant.reducedMotion,
      'fixture': scenario.id,
      'preparation': scenario.preparation.name,
      'action': scenario.action.name,
      'expectedDestination': scenario.expected.destination,
      'expectedState': scenario.expected.state,
      'expectedOverlay': scenario.expected.overlay.manifestValue,
      'expectedKey': _manifestExpectedKey(catalogCase),
      'interactionTargetKey': variant.interactionTargetKey,
      'expectedText': scenario.expected.text,
      'scrollTarget': scenario.expected.scrollTarget.manifestValue,
      'destination': scenario.expected.destination == 'route-default'
          ? _catalogDestination(catalogCase)
          : scenario.expected.destination,
      'interaction': variant.interaction.manifestValue,
      'scrollCheckpoint': variant.scrollCheckpoint.manifestValue,
      'file': fileName,
      'status': 'capturing',
      'byteLength': 0,
    };
    manifest.add(capture);
    _writeManifest(
      root: root,
      phase: phase,
      captures: manifest,
      contactSheets: contactSheets,
    );
    try {
      await _capture(tester, output);
      capture
        ..['status'] = 'captured'
        ..['byteLength'] = output.lengthSync();
      _assertExpectedFrame(tester, scenario);
    } on Object {
      capture['status'] = 'failed';
      _writeManifest(
        root: root,
        phase: phase,
        captures: manifest,
        contactSheets: contactSheets,
      );
      rethrow;
    }
    _writeManifest(
      root: root,
      phase: phase,
      captures: manifest,
      contactSheets: contactSheets,
    );
  } finally {
    await interactionCleanup?.call();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
    await prepared.dispose();
    tester.platformDispatcher
      ..clearTextScaleFactorTestValue()
      ..clearPlatformBrightnessTestValue()
      ..clearAccessibilityFeaturesTestValue();
  }
}

Future<void> _openRepresentativeDetail(
  WidgetTester tester,
  _CaptureCase catalogCase,
) async {
  if (!_isEnvironmentVariant(catalogCase.variant) ||
      catalogCase.viewport.id != 'mobile' ||
      !_longListScenarioIds.contains(catalogCase.scenario.id)) {
    return;
  }
  final row = _firstTreeNavigationRow();
  if (row == null) {
    throw StateError(
      'The ${catalogCase.scenario.id} accessibility variant has no detail '
      'navigation row.',
    );
  }
  await tester.tap(row);
  await _pumpCatalogFrame(tester);
}

Future<void> _applyScenarioAction(
  WidgetTester tester, {
  required _Scenario scenario,
  required _PreparedScenario prepared,
}) async {
  switch (scenario.action) {
    case _CatalogAction.none:
      break;
    case _CatalogAction.openProjectDetail:
      await _tapFirstNavigationRow(tester);
      // The 344px audit viewport lazily builds only the first form section.
      // Scroll to the project-specific field so the captured frame and its
      // expected-key contract prove that collection activation reached the
      // actual detail destination, rather than merely changing the header.
      if (scenario.expected.key case final key?) {
        await _ensureVisibleKey(tester, key);
      }
    case _CatalogAction.openAgentCreate:
      await _tapKey(tester, 'agent-add-button');
    case _CatalogAction.validateAgentCreate:
      await _tapKey(tester, 'agent-add-button');
      await tester.enterText(_textField('ID (file name)'), 'Invalid ID');
      await tester.enterText(_textField('Name'), 'Catalog reviewer');
      await _pumpCatalogFrame(tester);
    case _CatalogAction.failAgentCreate:
      await _tapKey(tester, 'agent-add-button');
      await tester.enterText(_textField('ID (file name)'), 'catalog-reviewer');
      await tester.enterText(_textField('Name'), 'Catalog reviewer');
      await _tapButton(tester, 'Create');
    case _CatalogAction.openAgentReadOnly:
      await _tapFirstNavigationRow(tester);
      await _ensureVisibleKey(tester, 'agent-settings-model-selector');
    case _CatalogAction.openAgentArchiveDialog:
      await _tapText(tester, 'Agent 1');
      await _tapKey(tester, 'agent-archive-button');
    case _CatalogAction.openAgentResetDialog:
      await _tapText(tester, 'Tinest');
      await _tapKey(tester, 'agent-reset-button');
    case _CatalogAction.openMcpCreate:
      await _tapKey(tester, 'mcp-server-add');
    case _CatalogAction.validateMcpCreate:
      await _tapKey(tester, 'mcp-server-add');
      await tester.enterText(_byKey('mcp-field-id'), 'Has__Underscores');
      await _tapKey(tester, 'mcp-server-save');
      await _ensureVisibleKey(tester, 'mcp-editor-error');
    case _CatalogAction.openMcpDiagnostic:
      await _tapKey(tester, 'mcp-server-tile-github');
      await _ensureVisibleKey(tester, 'mcp-server-diagnostics');
    case _CatalogAction.openMcpResources:
      await _tapKey(tester, 'mcp-server-tile-github');
      await _tapKey(tester, 'mcp-server-resources');
    case _CatalogAction.openMcpTemplates:
      await _tapKey(tester, 'mcp-server-tile-github');
      await _tapKey(tester, 'mcp-server-resource-templates');
    case _CatalogAction.openMcpReadOnly:
      await _tapKey(tester, 'mcp-server-tile-repo');
    case _CatalogAction.openMcpShadowed:
      await _tapKey(tester, 'mcp-server-tile-repo');
    case _CatalogAction.openMcpSecretDialog:
      await _tapKey(tester, 'mcp-server-tile-github');
      await _tapKey(tester, 'mcp-secret-set');
      await tester.enterText(_byKey('mcp-secret-key'), 'github.token');
      await tester.enterText(_byKey('mcp-secret-value'), '••••••••••••');
      await tester.pump();
    case _CatalogAction.openMcpDeleteDialog:
      await _tapKey(tester, 'mcp-server-tile-github');
      await _tapKey(tester, 'mcp-server-delete');
    case _CatalogAction.openProviderCatalog:
      await _tapKey(tester, 'provider-add-button');
    case _CatalogAction.openProviderPreset:
      await _tapKey(tester, 'provider-add-button');
      await _tapKey(tester, 'provider-add-deepseek');
    case _CatalogAction.openProviderCustomCreate:
      await _tapKey(tester, 'provider-add-button');
      await _tapKey(tester, 'provider-add-custom');
    case _CatalogAction.openProviderCustomEdit:
      await _tapKey(tester, 'provider-connection-catalog-lab');
    case _CatalogAction.failProviderConnect:
      await _tapKey(tester, 'provider-add-button');
      await _tapKey(tester, 'provider-add-deepseek');
      await tester.enterText(_textField('API key'), 'catalog-secret');
      await _tapKey(tester, 'provider-connect-submit');
    case _CatalogAction.startProviderOAuth:
      await _startProviderOAuth(tester);
    case _CatalogAction.failProviderOAuth:
      await _startProviderOAuth(tester);
      prepared.providerEvents!.add(
        const ProviderAuthUpdatedClientEvent(
          ProviderAuthAttemptDto(
            id: 'attempt',
            definitionId: 'openai',
            methodId: 'chatgpt-browser',
            status: ProviderAuthAttemptStatus.failed,
            error: 'planned authorization failure',
          ),
        ),
      );
      await _pumpCatalogFrame(tester);
    case _CatalogAction.openProviderModelError:
      await _tapKey(tester, 'provider-connection-broken-provider');
      await _ensureVisibleText(tester, 'Could not list models');
    case _CatalogAction.openProviderDisconnectDialog:
      await _tapKey(tester, 'provider-connection-openai');
      await _tapButton(tester, 'Disconnect');
    case _CatalogAction.openProviderDeleteDialog:
      await _tapKey(tester, 'provider-connection-catalog-lab');
      await _tapKey(tester, 'provider-custom-delete');
    case _CatalogAction.openDaemonModelSelect:
      await _tapKey(tester, 'daemon-default-model');
    case _CatalogAction.openPermissionSelect:
      await _tapKey(tester, 'permission-settings-change');
    case _CatalogAction.failPermissionSave:
      await _tapKey(tester, 'permission-settings-change');
      await _tapKey(tester, 'permission-option-fullAccess');
    case _CatalogAction.openRelayQrDialog:
      await _tapKey(tester, 'relay-pair-device');
    case _CatalogAction.openRelayEndpointDialog:
      await _tapKey(tester, 'relay-advanced-endpoint');
    case _CatalogAction.openRelayRevokeDialog:
      await _ensureVisibleText(tester, 'Catalog phone');
      await _tapButton(tester, 'Revoke');
    case _CatalogAction.openAdvancedResetDialog:
      await _tapKey(tester, 'advanced-settings-reset-button');
    case _CatalogAction.openRemoteHostDeleteDialog:
      await _tapKey(tester, 'remote-host-delete');
  }
  await _pumpCatalogFrame(tester);
}

Future<void> _startProviderOAuth(WidgetTester tester) async {
  await _tapKey(tester, 'provider-add-button');
  await _tapKey(tester, 'provider-add-openai');
  await _tapKey(tester, 'provider-connect-submit');
  await tester.pump(const Duration(milliseconds: 100));
}

Finder _byKey(String value) => find.byKey(ValueKey<String>(value));

Finder _textField(String label) => find
    .descendant(
      of: find.byWidgetPredicate(
        (widget) => switch (widget) {
          TRTextField(label: final fieldLabel) => fieldLabel == label,
          _ => false,
        },
      ),
      matching: find.byType(EditableText),
    )
    .last;

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = _byKey(key);
  await _ensureVisible(tester, finder, 'key $key');
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  final matches = find.widgetWithText(TRButton, label);
  if (matches.evaluate().isEmpty) {
    throw StateError('Catalog action could not find button: $label');
  }
  final finder = matches.last;
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _pumpCatalogFrame(tester);
}

Future<void> _tapFirstNavigationRow(WidgetTester tester) async {
  final finder = _firstTreeNavigationRow();
  if (finder == null) {
    throw StateError('Catalog action could not find a navigation row.');
  }
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _pumpCatalogFrame(tester);
}

Finder? _firstTreeNavigationRow() {
  // The Settings sidebar is a typed tree too, and it joins the tree from the
  // medium width class up, ahead of the collection in the adaptive Row. Taking
  // the first tree unscoped therefore tapped a category rather than opening a
  // detail on every viewport wider than a phone, which is why the compact
  // captures passed while tablet and desktop did not.
  final collection = find
      .byWidgetPredicate(
        (widget) => widget is TRTreeNav<Object>,
        description: 'typed tree navigation',
      )
      .evaluate()
      .where((element) => !_isInsideSettingsSidebar(element))
      .toList(growable: false);
  if (collection.isEmpty) return null;
  final tree = collection.first;
  final rows = find.descendant(
    of: find.byElementPredicate(
      (element) => identical(element, tree),
      description: 'collection tree navigation',
    ),
    matching: find.byWidgetPredicate(
      (widget) => widget is GestureDetector && widget.onTap != null,
      description: 'actionable tree navigation row',
    ),
  );
  return rows.evaluate().isEmpty ? null : rows.first;
}

bool _isInsideSettingsSidebar(Element element) {
  var inside = false;
  element.visitAncestorElements((ancestor) {
    if (ancestor.widget.key == _settingsSidebarSurface) {
      inside = true;
      return false;
    }
    return true;
  });
  return inside;
}

const _settingsSidebarSurface = ValueKey<String>('settings-sidebar-surface');

Future<void> _tapText(WidgetTester tester, String text) async {
  final matches = find.text(text);
  await _scrollTowards(tester, matches);
  if (matches.evaluate().isEmpty) {
    throw StateError('Catalog action could not find text: $text');
  }
  final finder = matches.first;
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _pumpCatalogFrame(tester);
}

Future<void> _ensureVisibleKey(WidgetTester tester, String key) =>
    _ensureVisible(tester, _byKey(key), 'key $key');

Future<void> _ensureVisibleText(WidgetTester tester, String text) =>
    _ensureVisible(tester, find.textContaining(text), 'text $text');

Future<void> _ensureVisible(
  WidgetTester tester,
  Finder finder,
  String description,
) async {
  await _scrollTowards(tester, finder);
  if (finder.evaluate().isEmpty) {
    throw StateError('Catalog scroll target could not find $description.');
  }
  await tester.ensureVisible(finder.first);
  await _pumpCatalogFrame(tester);
}

/// Drags the primary scrollable until [finder] resolves, or gives up quietly.
///
/// `scrollUntilVisible` ends by calling `ensureVisible` on the finder even when
/// its own search exhausted every iteration, so a target that is simply absent
/// surfaced as `Bad state: No element` from deep inside flutter_test and hid
/// which target the catalog was looking for. Leaving the reporting to the
/// caller keeps that diagnostic reachable.
Future<void> _scrollTowards(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isNotEmpty) return;
  final scrollable = _primaryCatalogScrollable(tester);
  if (scrollable == null) return;
  for (var attempt = 0; attempt < 50; attempt++) {
    if (scrollable.evaluate().isEmpty) return;
    await tester.drag(scrollable, const Offset(0, -240));
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
  }
}

Finder? _primaryCatalogScrollable(WidgetTester tester) {
  Iterable<ScrollableState> scrollables(Finder finder) => tester
      .stateList<ScrollableState>(finder)
      .where(
        (state) =>
            state.position.hasContentDimensions &&
            state.position.maxScrollExtent > 0,
      );

  var candidates = scrollables(
    find.descendant(
      of: find.byType(SettingsScaffold),
      matching: find.byType(Scrollable),
    ),
  ).toList(growable: false);
  if (candidates.isEmpty) {
    candidates = scrollables(find.byType(Scrollable)).toList(growable: false);
  }
  if (candidates.isEmpty) return null;
  final target = candidates.reduce(
    (current, candidate) =>
        candidate.position.maxScrollExtent > current.position.maxScrollExtent
        ? candidate
        : current,
  );
  // Identify the scrollable by element rather than by widget instance. A drag
  // pumps frames, an async load rebuilds the pane, and the captured widget
  // instance stops matching, at which point scrollUntilVisible throws
  // "Bad state: No element" instead of reporting the target it never found.
  final context = target.context;
  return find.byElementPredicate(
    (element) => identical(element, context),
    description: 'primary catalog scrollable',
  );
}

void _assertExpectedFrame(WidgetTester tester, _Scenario scenario) {
  final expected = scenario.expected;
  if (expected.key case final key?) {
    expect(
      _byKey(key),
      findsWidgets,
      reason: '${scenario.id} must reach its expected key.',
    );
  }
  if (expected.text case final text?) {
    expect(
      find.textContaining(text),
      findsWidgets,
      reason: '${scenario.id} must reach its expected visible state.',
    );
  }
  switch (expected.overlay) {
    case _ExpectedOverlay.none:
      break;
    case _ExpectedOverlay.dialog:
      expect(
        find.byType(TRDialog).evaluate().isNotEmpty ||
            find.byType(TRAlertDialog).evaluate().isNotEmpty,
        isTrue,
        reason: '${scenario.id} must have a dialog overlay.',
      );
    case _ExpectedOverlay.adaptiveSelect:
      expect(
        find.byType(TRDrawer).evaluate().isNotEmpty ||
            (expected.key != null &&
                _byKey(expected.key!).evaluate().isNotEmpty),
        isTrue,
        reason: '${scenario.id} must have its adaptive overlay open.',
      );
    case _ExpectedOverlay.toast:
      expect(
        find.byType(TRToastRegion),
        findsOneWidget,
        reason: '${scenario.id} must render through the toast region.',
      );
  }
}

String _catalogDestination(_CaptureCase catalogCase) {
  final opensDetail =
      _isEnvironmentVariant(catalogCase.variant) &&
      catalogCase.viewport.id == 'mobile' &&
      _longListScenarioIds.contains(catalogCase.scenario.id);
  return opensDetail ? 'detail' : 'route-default';
}

bool _isEnvironmentVariant(_Variant variant) =>
    _environmentVariants.any((candidate) => candidate.id == variant.id);

Future<void> _pumpCatalogFrame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _forceDirection(
  WidgetTester tester,
  TextDirection direction,
) async {
  final scope = tester.widget<ProviderScope>(find.byType(ProviderScope).first);
  final app = tester.widget<MaterialApp>(find.byType(MaterialApp).first);
  final originalBuilder = app.builder;
  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureBoundary,
      child: ProviderScope(
        overrides: scope.overrides,
        observers: scope.observers,
        retry: scope.retry,
        child: MaterialApp.router(
          scaffoldMessengerKey: app.scaffoldMessengerKey,
          routerConfig: app.routerConfig,
          builder: (context, child) {
            final directed = Directionality(
              textDirection: direction,
              child: child ?? const SizedBox.shrink(),
            );
            return originalBuilder?.call(context, directed) ?? directed;
          },
          title: app.title,
          onGenerateTitle: app.onGenerateTitle,
          onNavigationNotification: app.onNavigationNotification,
          color: app.color,
          theme: app.theme,
          darkTheme: app.darkTheme,
          highContrastTheme: app.highContrastTheme,
          highContrastDarkTheme: app.highContrastDarkTheme,
          themeMode: app.themeMode,
          themeAnimationDuration: app.themeAnimationDuration,
          themeAnimationCurve: app.themeAnimationCurve,
          themeAnimationStyle: app.themeAnimationStyle,
          locale: app.locale,
          localizationsDelegates: app.localizationsDelegates,
          localeListResolutionCallback: app.localeListResolutionCallback,
          localeResolutionCallback: app.localeResolutionCallback,
          supportedLocales: app.supportedLocales,
          debugShowMaterialGrid: app.debugShowMaterialGrid,
          showPerformanceOverlay: app.showPerformanceOverlay,
          checkerboardRasterCacheImages: app.checkerboardRasterCacheImages,
          checkerboardOffscreenLayers: app.checkerboardOffscreenLayers,
          showSemanticsDebugger: app.showSemanticsDebugger,
          debugShowCheckedModeBanner: app.debugShowCheckedModeBanner,
          shortcuts: app.shortcuts,
          actions: app.actions,
          restorationScopeId: app.restorationScopeId,
          scrollBehavior: app.scrollBehavior,
        ),
      ),
    ),
  );
}

Future<void> _applyScrollCheckpoint(
  WidgetTester tester,
  _ScrollCheckpoint checkpoint,
) async {
  if (checkpoint == _ScrollCheckpoint.top) return;
  final scrollables = tester
      .stateList<ScrollableState>(
        find.descendant(
          of: find.byKey(_captureBoundary),
          matching: find.byType(Scrollable),
        ),
      )
      .where(
        (state) =>
            state.position.hasContentDimensions &&
            state.position.maxScrollExtent > 0,
      )
      .toList(growable: false);
  if (scrollables.isEmpty) {
    throw StateError(
      'The ${checkpoint.manifestValue} catalog variant has no scrollable '
      'content.',
    );
  }
  final target = scrollables.reduce(
    (current, candidate) =>
        candidate.position.maxScrollExtent > current.position.maxScrollExtent
        ? candidate
        : current,
  );
  target.position.jumpTo(target.position.maxScrollExtent * checkpoint.fraction);
  await tester.pump();
}

Future<Future<void> Function()?> _applyInteraction(
  WidgetTester tester,
  _CatalogInteraction interaction, {
  required String? targetKey,
}) async {
  if (interaction == _CatalogInteraction.idle) return null;
  if (targetKey == null) {
    throw StateError(
      'The ${interaction.manifestValue} catalog variant has no stable '
      'interaction target key.',
    );
  }
  final target = _byKey(targetKey);
  if (target.evaluate().length != 1) {
    throw StateError(
      'The ${interaction.manifestValue} catalog variant expected exactly one '
      '$targetKey navigation row.',
    );
  }
  final navigation = find.ancestor(
    of: target,
    matching: find.byType(TRTreeNav<SettingsCategory>),
  );
  if (navigation.evaluate().isEmpty) {
    throw StateError(
      'The $targetKey interaction target is not inside Settings navigation.',
    );
  }
  final row = find
      .descendant(of: target, matching: find.byType(MouseRegion))
      .first;
  if (row.evaluate().isEmpty) {
    throw StateError(
      'The ${interaction.manifestValue} catalog variant has no navigation row.',
    );
  }
  final surface = find
      .descendant(of: row, matching: find.byType(AnimatedContainer))
      .first;
  Color? surfaceColor() =>
      (tester.widget<AnimatedContainer>(surface).decoration as BoxDecoration?)
          ?.color;
  final theme = tester.element(row).tinyrackTheme;
  expect(
    surfaceColor(),
    Colors.transparent,
    reason: '$targetKey must be non-selected before interaction.',
  );
  switch (interaction) {
    case _CatalogInteraction.idle:
      return null;
    case _CatalogInteraction.hover:
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(row));
      await tester.pump();
      await tester.pump(TRMotion.fast);
      expect(surfaceColor(), theme.surfaceHover);
      return () async {
        await gesture.removePointer();
      };
    case _CatalogInteraction.pressed:
      final gesture = await tester.startGesture(tester.getCenter(row));
      await tester.pump();
      // GestureDetector reports tap-down after its press deadline. The first
      // token-duration pump crosses that deadline; the second completes the
      // surface transition which starts in that frame.
      await tester.pump(TRMotion.fast);
      await tester.pump(TRMotion.fast);
      expect(surfaceColor(), theme.surfacePressed);
      return () async {
        await gesture.cancel();
      };
    case _CatalogInteraction.keyboardFocus:
      final focus = tester
          .widgetList<Focus>(
            find.descendant(of: row, matching: find.byType(Focus)),
          )
          .firstWhere(
            (candidate) =>
                candidate.canRequestFocus && candidate.focusNode != null,
          );
      final node = focus.focusNode!;
      for (var step = 0; step < 20 && !node.hasPrimaryFocus; step += 1) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      if (!node.hasPrimaryFocus) {
        throw StateError(
          'Keyboard traversal did not reach the catalog navigation row.',
        );
      }
      // Let both the previous control's focus surface and the navigation
      // row's new surface complete their tokenized transition before capture.
      await tester.pump(TRMotion.fast);
      expect(surfaceColor(), theme.surfaceHover);
      return () async {
        node.unfocus();
        await tester.pump();
      };
  }
}

void _validatePhase(String value, {required String variable}) {
  if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]*$').hasMatch(value)) {
    throw StateError('$variable must be one safe path segment.');
  }
}

Future<void> _generateContactSheets({
  required WidgetTester tester,
  required Directory root,
  required String phase,
  required String baselinePhase,
  required List<Map<String, Object?>> captures,
  required List<Map<String, Object?>> contactSheets,
}) async {
  final baselineRoot = Directory('${root.parent.path}/$baselinePhase');
  final baselineManifest = File('${baselineRoot.path}/manifest.json');
  if (!baselineManifest.existsSync()) {
    throw StateError(
      'The baseline catalog manifest does not exist: '
      '${baselineManifest.path}',
    );
  }
  final baselineCaptures = _readManifestCaptures(baselineManifest);
  final baselineByIdentity = <String, Map<String, Object?>>{
    for (final capture in baselineCaptures)
      _manifestCaptureIdentity(capture): capture,
  };
  final outputDirectory = Directory('${root.path}/contact-sheets')
    ..createSync(recursive: true);

  for (final capture in captures) {
    final identity = _manifestCaptureIdentity(capture);
    final baseline = baselineByIdentity[identity];
    if (baseline == null || baseline['status'] != 'captured') {
      throw StateError(
        'The baseline catalog has no captured frame for $identity.',
      );
    }
    if (capture['status'] != 'captured') {
      throw StateError('The current catalog frame is not captured: $identity.');
    }
    final baselineName = baseline['file'];
    final currentName = capture['file'];
    if (baselineName is! String || currentName is! String) {
      throw StateError('Catalog frame $identity has no valid PNG file name.');
    }
    final baselineFile = File('${baselineRoot.path}/$baselineName');
    final currentFile = File('${root.path}/$currentName');
    if (!baselineFile.existsSync() || !currentFile.existsSync()) {
      throw StateError('Catalog frame files are missing for $identity.');
    }
    final output = File('${outputDirectory.path}/$currentName');
    final sheet = <String, Object?>{
      'scenario': capture['scenario'],
      'viewport': capture['viewport'],
      'variant': capture['variant'],
      'baselinePhase': baselinePhase,
      'currentPhase': phase,
      'baselineFile': '../$baselinePhase/$baselineName',
      'currentFile': currentName,
      'file': 'contact-sheets/$currentName',
      'status': 'composing',
      'byteLength': 0,
      'width': 0,
      'height': 0,
    };
    contactSheets.add(sheet);
    _writeManifest(
      root: root,
      phase: phase,
      captures: captures,
      contactSheets: contactSheets,
    );
    try {
      final dimensions = await _composeContactSheet(
        tester: tester,
        baseline: baselineFile,
        current: currentFile,
        output: output,
      );
      sheet
        ..['status'] = 'captured'
        ..['byteLength'] = output.lengthSync()
        ..['width'] = dimensions.$1
        ..['height'] = dimensions.$2;
    } on Object {
      sheet['status'] = 'failed';
      _writeManifest(
        root: root,
        phase: phase,
        captures: captures,
        contactSheets: contactSheets,
      );
      rethrow;
    }
    _writeManifest(
      root: root,
      phase: phase,
      captures: captures,
      contactSheets: contactSheets,
    );
  }
}

List<Map<String, Object?>> _readManifestCaptures(File manifest) {
  final Object? decoded = jsonDecode(manifest.readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw StateError('Catalog manifest must contain a JSON object.');
  }
  final rawCaptures = decoded['captures'];
  if (rawCaptures is! List<Object?>) {
    throw StateError('Catalog manifest must contain a captures array.');
  }
  return <Map<String, Object?>>[
    for (final capture in rawCaptures)
      if (capture is Map<String, Object?>)
        capture
      else
        throw StateError('Catalog manifest contains an invalid capture.'),
  ];
}

String _manifestCaptureIdentity(Map<String, Object?> capture) {
  final scenario = capture['scenario'];
  final viewport = capture['viewport'];
  final variant = capture['variant'];
  if (scenario is! String || viewport is! String || variant is! String) {
    throw StateError('Catalog capture identity fields must be strings.');
  }
  return '$scenario/$viewport/$variant';
}

Future<(int, int)> _composeContactSheet({
  required WidgetTester tester,
  required File baseline,
  required File current,
  required File output,
}) async {
  final result = await tester.runAsync(() async {
    final baselineImage = await _decodePng(baseline);
    final currentImage = await _decodePng(current);
    final width = baselineImage.width + currentImage.width;
    final height = baselineImage.height > currentImage.height
        ? baselineImage.height
        : currentImage.height;
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder)
      ..drawImage(baselineImage, ui.Offset.zero, ui.Paint())
      ..drawImage(
        currentImage,
        ui.Offset(baselineImage.width.toDouble(), 0),
        ui.Paint(),
      );
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(width, height);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) {
          throw StateError('Contact sheet PNG encoding returned no bytes.');
        }
        output.writeAsBytesSync(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          flush: true,
        );
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
      baselineImage.dispose();
      currentImage.dispose();
    }
    return (width, height);
  });
  if (result == null || output.lengthSync() == 0) {
    throw StateError('Contact sheet capture did not complete: ${output.path}');
  }
  return result;
}

Future<ui.Image> _decodePng(File file) async {
  final codec = await ui.instantiateImageCodec(file.readAsBytesSync());
  try {
    final frame = await codec.getNextFrame();
    return frame.image;
  } finally {
    codec.dispose();
  }
}

Set<String> _environmentFilter(String name, {required String alias}) =>
    (Platform.environment[name] ?? Platform.environment[alias])
        ?.split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet() ??
    const <String>{};

var _packageFontAliasesLoaded = false;

Future<void> _loadPackageFontAliases() async {
  if (_packageFontAliasesLoaded) return;
  const fonts = <String, List<String>>{
    'IBMPlexSans': <String>[
      'IBMPlexSans-Regular.otf',
      'IBMPlexSans-SemiBold.otf',
      'IBMPlexSans-Bold.otf',
    ],
    'IBMPlexSansKR': <String>[
      'IBMPlexSansKR-Regular.otf',
      'IBMPlexSansKR-SemiBold.otf',
      'IBMPlexSansKR-Bold.otf',
    ],
    'IBMPlexSansJP': <String>[
      'IBMPlexSansJP-Regular.otf',
      'IBMPlexSansJP-SemiBold.otf',
      'IBMPlexSansJP-Bold.otf',
    ],
    'IBMPlexMono': <String>[
      'IBMPlexMono-Regular.otf',
      'IBMPlexMono-Medium.otf',
    ],
  };
  for (final family in fonts.entries) {
    final loader = FontLoader('packages/tinyrack_ui/${family.key}');
    for (final asset in family.value) {
      loader.addFont(
        rootBundle.load('packages/tinyrack_ui/assets/fonts/$asset'),
      );
    }
    await loader.load();
  }
  final lucideLoader = FontLoader('packages/lucide_flutter/LucideIcons')
    ..addFont(rootBundle.load('packages/lucide_flutter/assets/lucide.ttf'));
  await lucideLoader.load();
  _packageFontAliasesLoaded = true;
}

Future<void> _capture(WidgetTester tester, File output) async {
  final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
    find.byKey(_captureBoundary),
  );
  final png = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) throw StateError('PNG encoding returned no bytes.');
    return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  });
  if (png == null) throw StateError('PNG capture did not complete.');
  output.writeAsBytesSync(png, flush: true);
  if (output.lengthSync() == 0) {
    throw StateError('PNG capture wrote an empty file: ${output.path}');
  }
}

void _writeManifest({
  required Directory root,
  required String phase,
  required List<Map<String, Object?>> captures,
  required List<Map<String, Object?>> contactSheets,
}) {
  const encoder = JsonEncoder.withIndent('  ');
  File('${root.path}/manifest.json').writeAsStringSync(
    encoder.convert(<String, Object?>{
      'schemaVersion': 5,
      'phase': phase,
      'generatedAt': _now.toIso8601String(),
      'fonts': const <String>[
        'IBMPlexSans',
        'IBMPlexSansKR',
        'IBMPlexSansJP',
        'IBMPlexMono',
        'LucideIcons',
      ],
      'captures': captures,
      'contactSheets': contactSheets,
    }),
    flush: true,
  );
}
