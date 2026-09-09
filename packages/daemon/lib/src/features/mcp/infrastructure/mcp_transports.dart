import 'package:daemon/src/features/mcp/infrastructure/mcp.dart';

/// Builds the real transports the daemon uses to reach MCP servers.
final class IoMcpTransportFactory implements McpTransportFactory {
  /// Creates a factory that reports [clientVersion] during handshakes.
  const new({this.clientVersion = '0.0.0'});

  /// The daemon version reported to servers.
  final String clientVersion;

  @override
  McpTransport create(McpTransportSpec spec) => switch (spec) {
    McpStdioSpec() => StdioMcpTransport(spec),
    McpHttpSpec() => HttpMcpTransport(spec),
  };
}
