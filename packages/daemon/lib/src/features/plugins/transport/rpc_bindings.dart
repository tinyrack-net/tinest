import 'package:daemon/src/features/plugins/infrastructure/plugin_authoring.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_bundles.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_ports.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_service.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_session_control_service.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_ui_service.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_runtime.dart';
import 'package:daemon/src/transport/rpc/binding.dart';
import 'package:protocol/protocol.dart';

/// Builds the plugin-management portion of the v5 RPC surface.
List<RpcBindingDescriptor> pluginRpcBindings<T extends Object>({
  required PluginManagementService plugins,
  required PluginSessionControlService<T> sessionControls,
  required PluginUiService ui,
  required PluginSecretVault secrets,
  PluginAuthoringEnvironmentService? authoring,
}) => <RpcBindingDescriptor>[
  RpcBinding(pluginsListProcedure, (_, _) async {
    return PluginListResultDto(plugins: await plugins.list());
  }),
  RpcBinding(pluginsGetProcedure, (request, _) async {
    return PluginResultDto(plugin: await plugins.get(request.id));
  }),
  RpcBinding(pluginsValidateProcedure, (request, _) async {
    return PluginResultDto(plugin: await plugins.validate(request.id));
  }),
  RpcBinding(pluginsReloadProcedure, (request, _) async {
    return PluginResultDto(
      plugin: await plugins.reload(request.id, request.agentId),
    );
  }),
  RpcBinding(pluginsScaffoldProcedure, (request, _) async {
    return PluginResultDto(
      plugin: await plugins.scaffold(request.id, request.name),
    );
  }),
  RpcBinding(pluginsForkProcedure, (request, _) async {
    return PluginResultDto(
      plugin: await plugins.fork(
        sourceId: request.sourceId,
        id: request.id,
        name: request.name,
      ),
    );
  }),
  if (authoring != null) ...pluginAuthoringRpcBindings(authoring: authoring),
  RpcBinding(pluginsListGrantsProcedure, (request, _) async {
    return PluginGrantListResultDto(
      grants: await plugins.listGrants(request.agentId),
    );
  }),
  RpcBinding(pluginsGrantProcedure, (request, _) async {
    return PluginGrantListResultDto(grants: await plugins.grant(request.grant));
  }),
  RpcBinding(pluginsRevokeProcedure, (request, _) async {
    return PluginGrantListResultDto(
      grants: await plugins.revoke(request.grant),
    );
  }),
  ...pluginSecretRpcBindings(secrets: secrets),
  RpcBinding(pluginsGetSessionControlProcedure, (request, _) async {
    return PluginSessionControlResultDto(
      control: await sessionControls.get(request),
    );
  }),
  RpcBinding(pluginsSetSessionControlProcedure, (request, _) async {
    return PluginSessionControlResultDto(
      control: await sessionControls.set(request),
    );
  }),
  ...pluginUiRpcBindings(ui: ui),
];

/// Builds the public plugin UI bindings with sanitized typed failures.
///
/// A slot renders against whatever revision the Agent has pinned right now, so
/// a plugin the Agent has never activated and a runtime the daemon has already
/// torn down are both ordinary outcomes rather than defects. Leaving them
/// untyped collapses them into `internal_error`, which the protocol reserves
/// for defects and which no client can translate.
///
/// The two get separate codes because a host answers them differently: an
/// Agent that has not pinned a revision yet has nothing to show, while a
/// rejection is a real failure the user should read.
List<RpcBindingDescriptor> pluginUiRpcBindings({
  required PluginUiService ui,
}) => <RpcBindingDescriptor>[
  RpcBinding(pluginsRenderUiProcedure, (request, _) async {
    try {
      return PluginUiDocumentResultDto(document: await ui.render(request));
    } on PluginUiException catch (error) {
      throw _pluginUiRejection(error.message);
    } on PluginRevisionUnavailable catch (error) {
      throw RpcFailureException(
        code: RpcErrorCodes.pluginRevisionUnavailable,
        message: _safePluginUiFailureMessage(error.message),
      );
    } on PluginRuntimeClosed catch (error) {
      throw _pluginUiRejection(error.message);
    }
  }),
  RpcBinding(pluginsDispatchUiActionProcedure, (request, _) async {
    try {
      return PluginUiDocumentResultDto(document: await ui.dispatch(request));
    } on PluginUiException catch (error) {
      throw _pluginUiRejection(error.message);
    } on PluginRevisionUnavailable catch (error) {
      throw RpcFailureException(
        code: RpcErrorCodes.pluginRevisionUnavailable,
        message: _safePluginUiFailureMessage(error.message),
      );
    } on PluginRuntimeClosed catch (error) {
      throw _pluginUiRejection(error.message);
    }
  }),
];

RpcFailureException _pluginUiRejection(String message) => RpcFailureException(
  code: RpcErrorCodes.pluginUiRejected,
  message: _safePluginUiFailureMessage(message),
);

String _safePluginUiFailureMessage(String message) {
  final firstLine = message.split(RegExp(r'\r?\n')).first.trim();
  final withoutLuaLocation = firstLine.replaceAll(
    RegExp(r'(?:bundle[/\\])?[A-Za-z0-9_.\-/\\]+\.lua:\d+:\s*'),
    '',
  );
  return withoutLuaLocation.isEmpty
      ? 'Plugin UI callback failed.'
      : withoutLuaLocation;
}

/// Builds the editor-authoring portion of the v5 plugin RPC surface.
List<RpcBindingDescriptor> pluginAuthoringRpcBindings({
  required PluginAuthoringEnvironmentService authoring,
}) => <RpcBindingDescriptor>[
  RpcBinding(pluginsGetPluginAuthoringEnvironmentProcedure, (request, _) async {
    return PluginAuthoringEnvironmentResultDto(
      environment: await authoring.get(request.id),
    );
  }),
  RpcBinding(pluginsSyncPluginAuthoringEnvironmentProcedure, (
    request,
    _,
  ) async {
    return PluginAuthoringEnvironmentResultDto(
      environment: await authoring.sync(request.id),
    );
  }),
];

/// Builds the value-opaque secret provisioning portion of the v5 RPC surface.
List<RpcBindingDescriptor> pluginSecretRpcBindings({
  required PluginSecretVault secrets,
}) => <RpcBindingDescriptor>[
  RpcBinding(pluginsSetSecretProcedure, (request, _) async {
    await secrets.set(
      PluginSecretScope(agentId: request.agentId, pluginId: request.pluginId),
      request.name,
      request.value,
    );
    return const EmptyResultDto();
  }),
  RpcBinding(pluginsRemoveSecretProcedure, (request, _) async {
    await secrets.remove(
      PluginSecretScope(agentId: request.agentId, pluginId: request.pluginId),
      request.name,
    );
    return const EmptyResultDto();
  }),
];
