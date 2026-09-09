import 'dart:convert';

/// Breaking wire protocol major.
const int tinestProtocolMajor = 5;

/// Exact revision supported by this implementation.
///
/// Revision 4 drops the per-model role list and the custom-endpoint strict
/// schema flag. Roles are now a closed neutral set every transport accepts,
/// and what an endpoint accepts is stated by the endpoint rather than
/// configured per connection. An earlier peer still expects both fields, so
/// the handshake rejects the pairing rather than letting it fail later at an
/// arbitrary RPC.
const int tinestProtocolRevision = 4;

/// WebSocket subprotocol offered by v5 clients and servers.
const String tinestWebSocketProtocol = 'tinyrack.tinest.v5';

/// Prefix for browser-compatible bearer-token subprotocols.
const String tinestWebSocketTokenPrefix = 'tinyrack.tinest.token.';

/// Encodes a bearer token into a WebSocket subprotocol value.
String encodeWebSocketTokenProtocol(String token) =>
    '$tinestWebSocketTokenPrefix'
    '${base64Url.encode(utf8.encode(token)).replaceAll('=', '')}';

/// Decodes a bearer token subprotocol, returning null for malformed input.
String? decodeWebSocketTokenProtocol(String protocol) {
  if (!protocol.startsWith(tinestWebSocketTokenPrefix)) return null;
  final encoded = protocol.substring(tinestWebSocketTokenPrefix.length);
  if (encoded.isEmpty) return null;
  try {
    return utf8.decode(base64Url.decode(base64Url.normalize(encoded)));
  } on FormatException {
    return null;
  }
}

/// Raised when a protocol payload cannot be decoded.
class ProtocolException implements Exception {
  /// Creates a protocol failure.
  const new(this.message);

  /// Human-readable protocol failure detail.
  final String message;
  @override
  String toString() => 'ProtocolException: $message';
}
