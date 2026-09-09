import 'dart:convert';

import 'package:meta/meta.dart';

/// Current relay pairing protocol version.
const int relayProtocolVersion = 1;

/// A short-lived capability used to register one device with a daemon.
@immutable
final class RelayPairingOffer {
  /// Creates a validated version-one offer.
  new({
    required this.serverId,
    required this.relayUri,
    required List<int> daemonPublicKey,
    required this.offerId,
    required List<int> secret,
    required this.expiresAt,
  }) : daemonPublicKey = List<int>.unmodifiable(daemonPublicKey),
       secret = List<int>.unmodifiable(secret) {
    _validate();
  }

  /// Decodes and validates an offer JSON object.
  factory fromJson(Map<String, Object?> json) {
    if (json['v'] != relayProtocolVersion) {
      throw const FormatException('Unsupported relay offer version.');
    }
    try {
      return RelayPairingOffer(
        serverId: json['serverId']! as String,
        relayUri: Uri.parse(json['relayUri']! as String),
        daemonPublicKey: _decodeBytes(json['daemonPublicKey']! as String),
        offerId: json['offerId']! as String,
        secret: _decodeBytes(json['secret']! as String),
        expiresAt: DateTime.parse(json['expiresAt']! as String).toUtc(),
      );
    } on Object catch (error) {
      if (error is FormatException) {
        rethrow;
      }
      throw FormatException('Malformed relay pairing offer.', error);
    }
  }

  /// Reads an offer exclusively from [uri]'s fragment.
  factory parseUrl(Uri uri) {
    const prefix = 'offer=';
    if (!uri.fragment.startsWith(prefix)) {
      throw const FormatException('Pairing URL has no offer fragment.');
    }
    final encoded = uri.fragment.substring(prefix.length);
    final decoded = utf8.decode(_decodeBytes(encoded));
    final value = jsonDecode(decoded);
    if (value is! Map<String, Object?>) {
      throw const FormatException('Pairing offer must be a JSON object.');
    }
    return RelayPairingOffer.fromJson(value);
  }

  /// Authoritative daemon identity shared by all connection paths.
  final String serverId;

  /// WebSocket endpoint used for registration and relay sessions.
  final Uri relayUri;

  /// Daemon Ed25519 identity public key.
  final List<int> daemonPublicKey;

  /// Identifier of this one-time registration capability.
  final String offerId;

  /// Random 256-bit registration capability.
  final List<int> secret;

  /// UTC instant after which registration must be rejected.
  final DateTime expiresAt;

  /// Serializes the complete URL-fragment payload.
  Map<String, Object?> toJson() => <String, Object?>{
    'v': relayProtocolVersion,
    'serverId': serverId,
    'relayUri': relayUri.toString(),
    'daemonPublicKey': _encodeBytes(daemonPublicKey),
    'offerId': offerId,
    'secret': _encodeBytes(secret),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
  };

  /// Embeds this offer in [pairingPage] without query-string disclosure.
  Uri toUrl(Uri pairingPage) {
    final encoded = _encodeBytes(utf8.encode(jsonEncode(toJson())));
    return pairingPage.replace(fragment: 'offer=$encoded');
  }

  void _validate() {
    if (serverId.isEmpty || offerId.isEmpty) {
      throw const FormatException('Relay identifiers must not be empty.');
    }
    if (relayUri.scheme != 'wss' && relayUri.scheme != 'ws') {
      throw const FormatException('Relay URI must use WebSocket.');
    }
    if (daemonPublicKey.length != 32 || secret.length != 32) {
      throw const FormatException('Relay keys and secrets must be 32 bytes.');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is RelayPairingOffer &&
      serverId == other.serverId &&
      relayUri == other.relayUri &&
      offerId == other.offerId &&
      expiresAt == other.expiresAt &&
      _bytesEqual(daemonPublicKey, other.daemonPublicKey) &&
      _bytesEqual(secret, other.secret);

  @override
  int get hashCode => Object.hash(
    serverId,
    relayUri,
    offerId,
    expiresAt,
    Object.hashAll(daemonPublicKey),
    Object.hashAll(secret),
  );
}

String _encodeBytes(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

List<int> _decodeBytes(String encoded) {
  final padding = (4 - encoded.length % 4) % 4;
  return base64Url.decode('$encoded${'=' * padding}');
}

bool _bytesEqual(List<int> first, List<int> second) {
  if (first.length != second.length) {
    return false;
  }
  for (var index = 0; index < first.length; index += 1) {
    if (first[index] != second[index]) {
      return false;
    }
  }
  return true;
}
