import 'dart:convert';
import 'dart:typed_data';

import 'package:relay_protocol/src/cipher.dart';
import 'package:relay_protocol/src/offer.dart';

/// Decrypted device metadata carried by a one-time pairing registration.
final class RelayPairingRegistrationPayload {
  /// Creates validated registration metadata.
  new({
    required this.deviceId,
    required this.deviceName,
    required List<int> devicePublicKey,
  }) : devicePublicKey = Uint8List.fromList(devicePublicKey) {
    if (deviceId.isEmpty ||
        deviceName.isEmpty ||
        devicePublicKey.length != 32) {
      throw const FormatException('Invalid relay registration payload.');
    }
  }

  /// Decodes registration metadata.
  factory fromJson(Map<String, dynamic> json) =>
      RelayPairingRegistrationPayload(
        deviceId: json['deviceId']! as String,
        deviceName: json['deviceName']! as String,
        devicePublicKey: base64Url.decode(
          base64Url.normalize(json['devicePublicKey']! as String),
        ),
      );

  /// Daemon-scoped device identifier.
  final String deviceId;

  /// User-visible device name.
  final String deviceName;

  /// Device Ed25519 public key.
  final Uint8List devicePublicKey;

  /// Encodes registration metadata before offer-secret encryption.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'deviceId': deviceId,
    'deviceName': deviceName,
    'devicePublicKey': base64UrlEncode(devicePublicKey),
  };
}

/// Registration request with only its random offer ID visible to the relay.
final class RelayPairingRegistrationRequest {
  /// Creates an opaque registration request.
  new({required this.offerId, required List<int> encryptedPayload})
    : encryptedPayload = Uint8List.fromList(encryptedPayload) {
    if (offerId.isEmpty) {
      throw const FormatException('Pairing offer ID must not be empty.');
    }
  }

  /// Parses the small visible routing header and opaque ciphertext.
  factory decode(List<int> bytes) {
    if (bytes.length < 3) {
      throw const FormatException('Pairing registration is truncated.');
    }
    final idLength = ByteData.sublistView(
      Uint8List.fromList(bytes),
      0,
      2,
    ).getUint16(0);
    if (idLength == 0 || bytes.length <= idLength + 2) {
      throw const FormatException('Pairing registration header is invalid.');
    }
    return RelayPairingRegistrationRequest(
      offerId: utf8.decode(bytes.sublist(2, idLength + 2)),
      encryptedPayload: bytes.sublist(idLength + 2),
    );
  }

  /// Encrypts registration metadata with the fragment-only offer secret.
  static Future<RelayPairingRegistrationRequest> create({
    required RelayPairingOffer offer,
    required RelayPairingRegistrationPayload payload,
  }) async {
    final cipher = await _pairingCipher(
      offer.serverId,
      offer.offerId,
      offer.secret,
      RelayDirection.clientToDaemon,
    );
    return RelayPairingRegistrationRequest(
      offerId: offer.offerId,
      encryptedPayload: await cipher.encrypt(
        utf8.encode(jsonEncode(payload.toJson())),
      ),
    );
  }

  /// Random one-time offer identifier, which carries no secret.
  final String offerId;

  /// Authenticated ciphertext containing device metadata.
  final Uint8List encryptedPayload;

  /// Encodes the visible offer ID and encrypted registration metadata.
  Uint8List encode() {
    final id = utf8.encode(offerId);
    if (id.length > 0xffff) {
      throw RangeError.range(id.length, 1, 0xffff, 'offerId');
    }
    final header = ByteData(2)..setUint16(0, id.length);
    return Uint8List.fromList(<int>[
      ...header.buffer.asUint8List(),
      ...id,
      ...encryptedPayload,
    ]);
  }

  /// Decrypts metadata using a daemon-held offer secret.
  Future<RelayPairingRegistrationPayload> decrypt({
    required String serverId,
    required List<int> offerSecret,
  }) async {
    final cipher = await _pairingCipher(
      serverId,
      offerId,
      offerSecret,
      RelayDirection.clientToDaemon,
    );
    final decoded = jsonDecode(
      utf8.decode(await cipher.decrypt(encryptedPayload)),
    );
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Pairing registration must be an object.');
    }
    return RelayPairingRegistrationPayload.fromJson(decoded);
  }
}

/// Encrypts a registration acknowledgement for the same one-time capability.
Future<Uint8List> encryptRelayPairingAccepted({
  required String serverId,
  required String offerId,
  required List<int> offerSecret,
  required String deviceId,
}) async {
  final cipher = await _pairingCipher(
    serverId,
    offerId,
    offerSecret,
    RelayDirection.daemonToClient,
  );
  return await cipher.encrypt(
    utf8.encode(jsonEncode(<String, String>{'deviceId': deviceId})),
  );
}

/// Authenticates a registration acknowledgement and returns its device ID.
Future<String> decryptRelayPairingAccepted({
  required RelayPairingOffer offer,
  required List<int> encrypted,
}) async {
  final cipher = await _pairingCipher(
    offer.serverId,
    offer.offerId,
    offer.secret,
    RelayDirection.daemonToClient,
  );
  final decoded = jsonDecode(utf8.decode(await cipher.decrypt(encrypted)));
  if (decoded is! Map<String, dynamic> || decoded['deviceId'] is! String) {
    throw const FormatException('Invalid pairing acknowledgement.');
  }
  return decoded['deviceId']! as String;
}

Future<RelayCipherState> _pairingCipher(
  String serverId,
  String offerId,
  List<int> secret,
  RelayDirection direction,
) => RelayCipherState.create(
  sharedSecret: secret,
  transcript: utf8.encode('tinyrack-tinest-pair-v1:$serverId:$offerId'),
  direction: direction,
);
