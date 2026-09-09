import 'dart:async';

import 'package:app/src/features/hosts/application/host_controller.dart';
import 'package:client/client.dart';
import 'package:protocol/protocol.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'plugin_settings_controller.g.dart';

/// Plugin catalog and the Agent definitions that reference its contributions.
final class PluginSettingsState {
  /// Creates an immutable plugin-management snapshot.
  const new({
    required this.plugins,
    required this.agents,
    required this.authoringEnvironments,
  });

  /// Installed built-in and app-data plugin packages.
  final List<PluginDescriptorDto> plugins;

  /// Agent harnesses used to derive plugin references.
  final List<AgentDefinitionDto> agents;

  /// Editor-neutral SDK state for app-data plugins, keyed by plugin ID.
  final Map<String, PluginAuthoringEnvironmentDto> authoringEnvironments;

  /// Agents whose harness references [pluginId].
  List<AgentDefinitionDto> referencingAgents(String pluginId) => agents
      .where((agent) => agentPluginIds(agent).contains(pluginId))
      .toList(growable: false);
}

@riverpod
/// Loads and mutates the v5 plugin catalog for one connected daemon.
class PluginSettingsController extends _$PluginSettingsController {
  @override
  Future<PluginSettingsState> build(String hostId) async {
    final api = await watchHostApi(ref, hostId);
    final subscription = api.plugins.pluginChanges.listen((_) {
      unawaited(refresh());
    });
    ref.onDispose(subscription.cancel);
    return await _load(api);
  }

  /// Reloads both plugin descriptors and their Agent references.
  Future<void> refresh() async {
    final api = await requireHostApi(ref, hostId);
    final next = await _load(api);
    if (!ref.mounted) return;
    state = AsyncData<PluginSettingsState>(next);
  }

  /// Validates one candidate without activating it.
  Future<PluginDescriptorDto> validate(String pluginId) async {
    final api = await requireHostApi(ref, hostId);
    final plugin = await api.plugins.validatePlugin(pluginId);
    _replace(plugin);
    return plugin;
  }

  /// Activates one valid candidate under [agentId]'s capability grants.
  Future<PluginDescriptorDto> reload(String pluginId, String agentId) async {
    final api = await requireHostApi(ref, hostId);
    final plugin = await api.plugins.reloadPlugin(pluginId, agentId);
    _replace(plugin);
    return plugin;
  }

  /// Creates an app-data plugin starter without globally enabling it.
  Future<PluginDescriptorDto> scaffold(String id, String name) async {
    final api = await requireHostApi(ref, hostId);
    final plugin = await api.plugins.scaffoldPlugin(id, name);
    final authoring = await api.plugins.getPluginAuthoringEnvironment(id);
    final current = state.requireValue;
    state = AsyncData<PluginSettingsState>(
      PluginSettingsState(
        plugins: <PluginDescriptorDto>[...current.plugins, plugin]
          ..sort((left, right) => left.id.compareTo(right.id)),
        agents: current.agents,
        authoringEnvironments: <String, PluginAuthoringEnvironmentDto>{
          ...current.authoringEnvironments,
          id: authoring,
        },
      ),
    );
    return plugin;
  }

  /// Forks one validated installed revision into an app-data plugin.
  Future<PluginDescriptorDto> fork({
    required String sourceId,
    required String id,
    required String name,
  }) async {
    final api = await requireHostApi(ref, hostId);
    final plugin = await api.plugins.forkPlugin(
      sourceId: sourceId,
      id: id,
      name: name,
    );
    final authoring = await api.plugins.getPluginAuthoringEnvironment(id);
    final current = state.requireValue;
    state = AsyncData<PluginSettingsState>(
      PluginSettingsState(
        plugins: <PluginDescriptorDto>[...current.plugins, plugin]
          ..sort((left, right) => left.id.compareTo(right.id)),
        agents: current.agents,
        authoringEnvironments: <String, PluginAuthoringEnvironmentDto>{
          ...current.authoringEnvironments,
          id: authoring,
        },
      ),
    );
    return plugin;
  }

  /// Renders one Agent-owned contribution through the typed plugin RPC.
  Future<PluginUiDocumentDto> renderUi({
    required String agentId,
    required String pluginId,
    required String contributionId,
    PluginUiSlot slot = PluginUiSlot.agentSettings,
    Map<String, dynamic> context = const <String, dynamic>{},
  }) async {
    final api = await requireHostApi(ref, hostId);
    return await api.plugins.renderPluginUi(
      agentId: agentId,
      pluginId: pluginId,
      contributionId: contributionId,
      slot: slot,
      context: context,
    );
  }

  /// Synchronizes one user plugin with the runtime's exact SDK ABI.
  Future<PluginAuthoringEnvironmentDto> syncAuthoring(String pluginId) async {
    final api = await requireHostApi(ref, hostId);
    final environment = await api.plugins.syncPluginAuthoringEnvironment(
      pluginId,
    );
    final current = state.requireValue;
    state = AsyncData<PluginSettingsState>(
      PluginSettingsState(
        plugins: current.plugins,
        agents: current.agents,
        authoringEnvironments: <String, PluginAuthoringEnvironmentDto>{
          ...current.authoringEnvironments,
          pluginId: environment,
        },
      ),
    );
    return environment;
  }

  /// Dispatches an action against a pinned UI document snapshot.
  Future<PluginUiDocumentDto> dispatchUi({
    required String agentId,
    required String pluginId,
    required PluginUiActionDto action,
  }) async {
    final api = await requireHostApi(ref, hostId);
    return await api.plugins.dispatchPluginUiAction(
      agentId: agentId,
      pluginId: pluginId,
      action: action,
    );
  }

  void _replace(PluginDescriptorDto plugin) {
    final current = state.requireValue;
    state = AsyncData<PluginSettingsState>(
      PluginSettingsState(
        plugins: current.plugins
            .map((candidate) => candidate.id == plugin.id ? plugin : candidate)
            .toList(growable: false),
        agents: current.agents,
        authoringEnvironments: current.authoringEnvironments,
      ),
    );
  }

  Future<PluginSettingsState> _load(TinestApi api) async {
    final plugins = await api.plugins.listPlugins();
    final values = await Future.wait<Object>(<Future<Object>>[
      api.agents.listAgentDefinitions(),
      Future.wait<PluginAuthoringEnvironmentDto>(
        plugins
            .where((plugin) => plugin.source == PluginSource.user)
            .map(
              (plugin) => api.plugins.getPluginAuthoringEnvironment(plugin.id),
            ),
      ),
    ]);
    final authoring = values[1] as List<PluginAuthoringEnvironmentDto>;
    return PluginSettingsState(
      plugins: plugins,
      agents: values[0] as List<AgentDefinitionDto>,
      authoringEnvironments: <String, PluginAuthoringEnvironmentDto>{
        for (final environment in authoring) environment.pluginId: environment,
      },
    );
  }
}

@riverpod
/// Agent-owned plugin capability grants stored by the daemon, outside Agent MD.
class AgentPluginGrantsController extends _$AgentPluginGrantsController {
  @override
  Future<List<AgentPluginGrantDto>> build(String hostId, String agentId) async {
    final api = await watchHostApi(ref, hostId);
    return await api.plugins.listPluginGrants(agentId);
  }

  /// Grants or revokes one exact capability for this Agent and plugin.
  Future<void> setCapability({
    required String pluginId,
    required String capability,
    required bool granted,
  }) async {
    final api = await requireHostApi(ref, hostId);
    final grant = AgentPluginGrantDto(
      agentId: agentId,
      pluginId: pluginId,
      capability: capability,
    );
    final grants = granted
        ? await api.plugins.grantPluginCapability(grant)
        : await api.plugins.revokePluginCapability(grant);
    if (ref.mounted) {
      state = AsyncData<List<AgentPluginGrantDto>>(grants);
    }
  }
}

@riverpod
/// Reads and mutates one durable Agent-owned plugin session control.
class PluginSessionControlController extends _$PluginSessionControlController {
  @override
  Future<PluginSessionControlValueDto> build(
    String hostId,
    String sessionId,
    String pluginId,
    String contributionId,
  ) async {
    final api = await watchHostApi(ref, hostId);
    return await api.plugins.getPluginSessionControl(
      sessionId: sessionId,
      pluginId: pluginId,
      contributionId: contributionId,
    );
  }

  /// Replaces the control value after daemon-side schema normalization.
  Future<PluginSessionControlValueDto> setValue(Object? value) async {
    final api = await requireHostApi(ref, hostId);
    final control = await api.plugins.setPluginSessionControl(
      sessionId: sessionId,
      pluginId: pluginId,
      contributionId: contributionId,
      value: value,
    );
    if (ref.mounted) {
      state = AsyncData<PluginSessionControlValueDto>(control);
    }
    return control;
  }
}

/// Returns every plugin package explicitly referenced by one Agent harness.
Set<String> agentPluginIds(AgentDefinitionDto agent) => <String>{
  pluginIdForContribution(agent.driverId),
  ...agent.extensionIds.map(pluginIdForContribution),
  ...agent.toolIds.map(pluginIdForContribution),
  ...agent.pluginSettings.keys,
};

/// Returns the package portion of a canonical plugin contribution id.
String pluginIdForContribution(String contributionId) {
  final separator = contributionId.indexOf('/');
  return separator < 0
      ? contributionId
      : contributionId.substring(0, separator);
}
