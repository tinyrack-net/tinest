import 'dart:convert';
import 'dart:typed_data';

/// Relay-only routing envelope whose payload stays end-to-end encrypted.
final class RelayEnvelope {
  /// Creates an envelope for one client connection.
  new({required this.connectionId, required List<int> payload})
    : payload = Uint8List.fromList(payload) {
    if (connectionId.isEmpty) {
      throw const FormatException('Connection ID must not be empty.');
    }
  }

  /// Parses a strict binary envelope.
  factory decode(List<int> bytes) {
    if (bytes.length < 3) {
      throw const FormatException('Relay envelope is truncated.');
    }
    final idLength = ByteData.sublistView(
      Uint8List.fromList(bytes),
      0,
      2,
    ).getUint16(0);
    if (idLength == 0 || bytes.length < idLength + 2) {
      throw const FormatException('Relay envelope header is invalid.');
    }
    return RelayEnvelope(
      connectionId: utf8.decode(bytes.sublist(2, 2 + idLength)),
      payload: bytes.sublist(2 + idLength),
    );
  }

  /// Ephemeral relay connection identifier, never a credential.
  final String connectionId;

  /// Opaque end-to-end encrypted application bytes.
  final Uint8List payload;

  /// Encodes the routing header and opaque payload.
  Uint8List encode() {
    final id = utf8.encode(connectionId);
    if (id.length > 0xffff) {
      throw RangeError.range(id.length, 1, 0xffff, 'connectionId');
    }
    final header = ByteData(2)..setUint16(0, id.length);
    return Uint8List.fromList(<int>[
      ...header.buffer.asUint8List(),
      ...id,
      ...payload,
    ]);
  }
}
