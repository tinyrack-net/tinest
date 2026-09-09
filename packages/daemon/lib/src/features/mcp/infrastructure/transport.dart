/// How a transport reaches one MCP server.
///
/// This is deliberately not a wire DTO: it keeps MCP transport code free of
/// dependency on the daemon's protocol package. The daemon maps its own
/// configuration onto these specs.
sealed class McpTransportSpec {
  /// Creates a [McpTransportSpec].
  const new();
}

/// Launches a child process and speaks newline-delimited JSON over its stdio.
final class McpStdioSpec extends McpTransportSpec {
  /// Creates a [McpStdioSpec].
  const new({
    required this.command,
    this.args = const <String>[],
    this.env = const <String, String>{},
    this.workingDirectory,
  });

  /// The executable to launch.
  final String command;

  /// Arguments passed to [command].
  final List<String> args;

  /// Extra environment entries merged over the daemon environment.
  final Map<String, String> env;

  /// Directory the child runs in, when the server needs a specific one.
  final String? workingDirectory;
}

/// Posts JSON-RPC messages to a Streamable HTTP endpoint.
final class McpHttpSpec extends McpTransportSpec {
  /// Creates a [McpHttpSpec].
  const new({required this.url, this.headers = const <String, String>{}});

  /// The single endpoint every message is posted to.
  final Uri url;

  /// Extra headers sent with every request.
  final Map<String, String> headers;
}

/// A closed or never-started transport was asked to carry a message.
class McpTransportClosed implements Exception {
  /// Creates a [McpTransportClosed].
  const new([this.reason]);

  /// Why the transport is unusable, when known.
  final String? reason;

  @override
  String toString() => 'McpTransportClosed${reason == null ? '' : ': $reason'}';
}

/// A bidirectional JSON-RPC message channel to one MCP server.
abstract interface class McpTransport {
  /// Decoded JSON-RPC messages arriving from the server.
  Stream<Map<String, dynamic>> get incoming;

  /// Non-fatal transport notes: child stderr, undecodable lines, and the like.
  Stream<String> get diagnostics;

  /// Completes when the peer goes away, carrying no value.
  Future<void> get done;

  /// Establishes the channel.
  Future<void> start();

  /// Sends one JSON-RPC message.
  Future<void> send(Map<String, dynamic> message);

  /// Tears the channel down, releasing every resource it holds.
  Future<void> close();
}

/// Builds a transport for one [McpTransportSpec].
abstract interface class McpTransportFactory {
  /// Creates — but does not start — a transport for [spec].
  McpTransport create(McpTransportSpec spec);
}
