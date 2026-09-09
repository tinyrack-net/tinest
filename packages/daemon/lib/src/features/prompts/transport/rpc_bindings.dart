import 'package:daemon/src/features/prompts/infrastructure/commands.dart';
import 'package:daemon/src/features/prompts/infrastructure/skills.dart';
import 'package:daemon/src/features/workspaces/infrastructure/workspace_service.dart';
import 'package:daemon/src/transport/rpc/binding.dart';
import 'package:protocol/protocol.dart';

/// Builds the prompt catalog feature's complete v5 RPC surface.
List<RpcBindingDescriptor> promptRpcBindings({
  required SkillCatalogService skills,
  required CommandService commands,
  required WorkspaceCatalogPort workspaces,
}) {
  Future<SkillScope> skillScope(String? workspaceId) async =>
      workspaceId == null
      ? SkillScope.global
      : SkillScope(projectRoot: await workspaces.workspaceRoot(workspaceId));
  Future<CommandScope> commandScope(String? workspaceId) async =>
      workspaceId == null
      ? CommandScope.global
      : CommandScope(
          workspaceId: workspaceId,
          projectRoot: await workspaces.workspaceRoot(workspaceId),
        );

  return <RpcBindingDescriptor>[
    RpcBinding(promptsListCommandsProcedure, (request, _) async {
      return CommandListResultDto(
        commands: await commands.list(
          scope: await commandScope(request.workspaceId),
        ),
      );
    }),
    RpcBinding(promptsListSkillsProcedure, (request, _) async {
      if (request.view == SkillListView.global && request.workspaceId != null) {
        throw const RpcFailureException(
          code: RpcErrorCodes.invalidParams,
          message: 'Global skill view does not accept workspaceId.',
        );
      }
      if (request.view == SkillListView.project &&
          request.workspaceId == null) {
        throw const RpcFailureException(
          code: RpcErrorCodes.invalidParams,
          message: 'Project skill view requires workspaceId.',
        );
      }
      return SkillListResultDto(
        skills: await skills.list(
          view: request.view,
          scope: await skillScope(request.workspaceId),
        ),
      );
    }),
  ];
}
