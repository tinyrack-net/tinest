import 'package:daemon/src/features/mcp/infrastructure/mcp_server_service.dart';
import 'package:daemon/src/features/mcp/infrastructure/mcp_service.dart';
import 'package:daemon/src/shared/infrastructure/persistence/repositories.dart';
import 'package:daemon/src/transport/rpc/binding.dart';
import 'package:protocol/protocol.dart';

/// Builds the MCP feature's complete v5 RPC surface.
List<RpcBindingDescriptor> mcpRpcBindings({
  required McpRuntime runtime,
  required McpAdminPort servers,
  required WorktreeRepository worktrees,
}) => <RpcBindingDescriptor>[
  RpcBinding(mcpListServersProcedure, (request, _) async {
    final worktree = request.worktreeId == null
        ? null
        : await worktrees.getById(request.worktreeId!);
    final root = worktree?.path;
    if (root != null) await runtime.ensureProject(root);
    return McpServersResultDto(servers: runtime.states(workspaceRoot: root));
  }),
  RpcBinding(mcpAddServerProcedure, (request, _) async {
    return McpServerStateResultDto(state: await servers.add(request.server));
  }),
  RpcBinding(mcpUpdateServerProcedure, (request, _) async {
    return McpServerStateResultDto(state: await servers.update(request.server));
  }),
  RpcBinding(mcpRemoveServerProcedure, (request, _) async {
    await servers.remove(request.id);
    return const EmptyResultDto();
  }),
  RpcBinding(mcpTestServerProcedure, (request, _) async {
    return McpServerStateResultDto(state: await servers.test(request.server));
  }),
  RpcBinding(mcpSetSecretProcedure, (request, _) async {
    await servers.setSecret(request.key, request.value);
    return const EmptyResultDto();
  }),
];
