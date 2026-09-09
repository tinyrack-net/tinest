import 'dart:typed_data';

/// Outer opaque frame kind needed by relay endpoints, never the relay server.
enum RelayWireFrameType {
  /// Offer-secret-encrypted one-time device registration.
  pairingRequest,

  /// Offer-secret-encrypted registration acknowledgement.
  pairingAccepted,

  /// Signed device handshake message.
  clientHello,

  /// Signed daemon handshake response.
  daemonHello,

  /// Ordered XChaCha20-Poly1305 ciphertext.
  encryptedRecord,
}

/// Minimal framing for handshake and encrypted records.
final class RelayWireFrame {
  /// Creates a typed outer frame.
  new({required this.type, required List<int> payload})
    : payload = Uint8List.fromList(payload);

  /// Parses a strict outer frame.
  factory decode(List<int> bytes) {
    if (bytes.isEmpty || bytes.first >= RelayWireFrameType.values.length) {
      throw const FormatException('Invalid relay wire frame.');
    }
    return RelayWireFrame(
      type: RelayWireFrameType.values[bytes.first],
      payload: bytes.sublist(1),
    );
  }

  /// Wire semantic.
  final RelayWireFrameType type;

  /// Handshake JSON or encrypted record bytes.
  final Uint8List payload;

  /// Encodes this outer frame.
  Uint8List encode() => Uint8List.fromList(<int>[type.index, ...payload]);
}
