import 'package:client/src/client.dart';
import 'package:client/src/web_socket_connector.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Creates the connector used in a browser.
WebSocketConnector createConnector() => const WebWebSocketConnector();

/// Connects from a browser, where request headers cannot be set.
///
/// The `Authorization` header the other clients send is translated into a
/// subprotocol, which the daemon accepts as an equivalent credential.
final class WebWebSocketConnector implements WebSocketConnector {
  /// Creates a [WebWebSocketConnector].
  const new();

  @override
  Future<WebSocketChannel> connect(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    final authorization = headers['Authorization'] ?? headers['authorization'];
    final token = authorization != null && authorization.startsWith('Bearer ')
        ? authorization.substring('Bearer '.length)
        : null;
    final channel = WebSocketChannel.connect(
      uri,
      protocols: <String>[
        tinestWebSocketProtocol,
        if (token != null) encodeWebSocketTokenProtocol(token),
      ],
    );
    try {
      await channel.ready;
    } on Exception {
      // A browser reports every WebSocket failure identically so that a page
      // cannot scan the local network, so a refused daemon and a refused Local
      // Network Access permission are indistinguishable here. Report the
      // address instead of guessing between them.
      if (!targetsLocalNetwork(uri)) rethrow;
      throw TinestClientException(
        'Could not reach a daemon at ${uri.host}:${uri.port}.',
        code: localNetworkUnreachableCode,
        retryable: true,
      );
    }
    return channel;
  }
}
