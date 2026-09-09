import 'package:daemon/src/features/mcp/infrastructure/mcp_service.dart';
import 'package:protocol/protocol.dart';

/// User-scoped MCP server configuration operations exposed over RPC.
abstract interface class McpAdminPort {
  /// Adds one user server and starts its connection.
  Future<McpServerStateDto> add(McpServerConfigDto server);

  /// Updates one user server and reconciles its connection.
  Future<McpServerStateDto> update(McpServerConfigDto server);

  /// Removes one user server and closes its connection.
  Future<void> remove(String id);

  /// Tests a server configuration without persisting it.
  Future<McpServerStateDto> test(McpServerConfigDto server);

  /// Stores one secret referenced by MCP configuration.
  Future<void> setSecret(String key, String value);

  /// Retries one failed user connection immediately.
  void retry(String id);
}

/// Coordinates persisted MCP server administration separately from runtime use.
final class McpServerService implements McpAdminPort {
  /// Creates the MCP administration service.
  const new(this._runtime);

  final McpRuntime _runtime;

  @override
  Future<McpServerStateDto> add(McpServerConfigDto server) =>
      _runtime.addUserServer(server);

  @override
  Future<McpServerStateDto> update(McpServerConfigDto server) =>
      _runtime.updateUserServer(server);

  @override
  Future<void> remove(String id) => _runtime.removeUserServer(id);

  @override
  Future<McpServerStateDto> test(McpServerConfigDto server) =>
      _runtime.testServer(server);

  @override
  Future<void> setSecret(String key, String value) =>
      _runtime.setSecret(key, value);

  @override
  void retry(String id) => _runtime.retry(id);
}
