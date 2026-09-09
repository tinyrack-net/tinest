import 'package:client/src/web_socket_connector.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Creates the connector used on every platform with `dart:io`.
WebSocketConnector createConnector() => const IoWebSocketConnector();

/// IoWebSocketConnector defines a public contract.
final class IoWebSocketConnector implements WebSocketConnector {
  /// Creates a [IoWebSocketConnector].
  const new({
    this.connectTimeout = const Duration(seconds: 10),
    this.pingInterval = const Duration(seconds: 10),
  });

  /// The connectTimeout public API member.
  final Duration connectTimeout;

  /// The pingInterval public API member.
  final Duration pingInterval;

  @override
  Future<WebSocketChannel> connect(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    final channel = IOWebSocketChannel.connect(
      uri,
      headers: headers,
      connectTimeout: connectTimeout,
      pingInterval: pingInterval,
    );
    await channel.ready;
    return channel;
  }
}
