import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:relay_protocol/src/cipher.dart';

/// Persistent Ed25519 identity used by a daemon or one registered device.
final class RelayIdentity {
  new _(this._keyPair, this.publicKey);

  /// Restores a deterministic identity from its 32-byte private seed.
  static Future<RelayIdentity> fromSeed(List<int> seed) async {
    if (seed.length != 32) {
      throw const RelaySecurityException('Identity seed must be 32 bytes.');
    }
    final keyPair = await Ed25519().newKeyPairFromSeed(seed);
    final publicKey = await keyPair.extractPublicKey();
    return RelayIdentity._(keyPair, Uint8List.fromList(publicKey.bytes));
  }

  /// Generates a new persistent identity with platform secure randomness.
  static Future<RelayIdentity> generate() async {
    final keyPair = await Ed25519().newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    return RelayIdentity._(keyPair, Uint8List.fromList(publicKey.bytes));
  }

  final SimpleKeyPair _keyPair;

  /// Raw 32-byte Ed25519 public key.
  final Uint8List publicKey;

  Future<Uint8List> _sign(List<int> message) async => Uint8List.fromList(
    (await Ed25519().sign(message, keyPair: _keyPair)).bytes,
  );
}

/// First mutually authenticated handshake message sent by a device.
final class RelayClientHello {
  /// Creates a validated client hello.
  new({
    required this.serverId,
    required this.sessionId,
    required this.deviceId,
    required List<int> identityPublicKey,
    required List<int> ephemeralPublicKey,
    required List<int> signature,
  }) : identityPublicKey = Uint8List.fromList(identityPublicKey),
       ephemeralPublicKey = Uint8List.fromList(ephemeralPublicKey),
       signature = Uint8List.fromList(signature) {
    _validateKeyMaterial(
      this.identityPublicKey,
      this.ephemeralPublicKey,
      this.signature,
    );
  }

  /// Decodes a client hello from its strict JSON representation.
  factory fromJson(Map<String, dynamic> json) => RelayClientHello(
    serverId: json['serverId']! as String,
    sessionId: json['sessionId']! as String,
    deviceId: json['deviceId']! as String,
    identityPublicKey: _decodeBytes(json['identityPublicKey']! as String),
    ephemeralPublicKey: _decodeBytes(json['ephemeralPublicKey']! as String),
    signature: _decodeBytes(json['signature']! as String),
  );

  /// Authoritative daemon identifier from the pairing offer.
  final String serverId;

  /// Unique connection handshake identifier.
  final String sessionId;

  /// Registered device identifier.
  final String deviceId;

  /// Device Ed25519 public identity.
  final Uint8List identityPublicKey;

  /// Per-connection X25519 public key.
  final Uint8List ephemeralPublicKey;

  /// Device signature over identity and connection context.
  final Uint8List signature;

  /// Encodes the signed client hello.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'serverId': serverId,
    'sessionId': sessionId,
    'deviceId': deviceId,
    'identityPublicKey': base64UrlEncode(identityPublicKey),
    'ephemeralPublicKey': base64UrlEncode(ephemeralPublicKey),
    'signature': base64UrlEncode(signature),
  };
}

/// Authenticated handshake response sent by the daemon.
final class RelayDaemonHello {
  /// Creates a validated daemon hello.
  new({
    required List<int> identityPublicKey,
    required List<int> ephemeralPublicKey,
    required List<int> signature,
  }) : identityPublicKey = Uint8List.fromList(identityPublicKey),
       ephemeralPublicKey = Uint8List.fromList(ephemeralPublicKey),
       signature = Uint8List.fromList(signature) {
    _validateKeyMaterial(
      this.identityPublicKey,
      this.ephemeralPublicKey,
      this.signature,
    );
  }

  /// Decodes a daemon hello from its strict JSON representation.
  factory fromJson(Map<String, dynamic> json) => RelayDaemonHello(
    identityPublicKey: _decodeBytes(json['identityPublicKey']! as String),
    ephemeralPublicKey: _decodeBytes(json['ephemeralPublicKey']! as String),
    signature: _decodeBytes(json['signature']! as String),
  );

  /// Daemon Ed25519 public identity.
  final Uint8List identityPublicKey;

  /// Per-connection X25519 public key.
  final Uint8List ephemeralPublicKey;

  /// Daemon signature binding both ephemeral keys and identities.
  final Uint8List signature;

  /// Encodes the signed daemon hello.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'identityPublicKey': base64UrlEncode(identityPublicKey),
    'ephemeralPublicKey': base64UrlEncode(ephemeralPublicKey),
    'signature': base64UrlEncode(signature),
  };
}

/// Derived secret and authenticated transcript used by record ciphers.
final class RelayHandshakeResult {
  /// Creates an immutable handshake result.
  new({required List<int> sharedSecret, required List<int> transcript})
    : sharedSecret = Uint8List.fromList(sharedSecret),
      transcript = Uint8List.fromList(transcript);

  /// Raw X25519 shared secret passed to HKDF.
  final Uint8List sharedSecret;

  /// Full mutually authenticated handshake transcript.
  final Uint8List transcript;
}

/// Client-side state retained between the two handshake messages.
final class RelayHandshakeInitiator {
  new _(this.hello, this._ephemeralKeyPair);

  /// Creates and signs the device hello.
  static Future<RelayHandshakeInitiator> start({
    required String serverId,
    required String sessionId,
    required String deviceId,
    required RelayIdentity identity,
    List<int>? ephemeralSeed,
  }) async {
    final ephemeral = await _newEphemeralKeyPair(ephemeralSeed);
    final ephemeralPublic = await ephemeral.extractPublicKey();
    final unsigned = _clientTranscript(
      serverId,
      sessionId,
      deviceId,
      identity.publicKey,
      ephemeralPublic.bytes,
    );
    return RelayHandshakeInitiator._(
      RelayClientHello(
        serverId: serverId,
        sessionId: sessionId,
        deviceId: deviceId,
        identityPublicKey: identity.publicKey,
        ephemeralPublicKey: ephemeralPublic.bytes,
        signature: await identity._sign(unsigned),
      ),
      ephemeral,
    );
  }

  /// Signed first handshake message.
  final RelayClientHello hello;

  final SimpleKeyPair _ephemeralKeyPair;

  /// Verifies the pinned daemon identity and completes X25519 exchange.
  Future<RelayHandshakeResult> complete(
    RelayDaemonHello response, {
    required List<int> expectedDaemonPublicKey,
  }) async {
    if (!_constantTimeEqual(
      response.identityPublicKey,
      expectedDaemonPublicKey,
    )) {
      throw const RelaySecurityException(
        'Daemon identity does not match pairing offer.',
      );
    }
    final transcript = _fullTranscript(hello, response);
    final valid = await Ed25519().verify(
      transcript,
      signature: Signature(
        response.signature,
        publicKey: SimplePublicKey(
          response.identityPublicKey,
          type: KeyPairType.ed25519,
        ),
      ),
    );
    if (!valid) {
      throw const RelaySecurityException(
        'Daemon handshake signature is invalid.',
      );
    }
    return await _result(
      _ephemeralKeyPair,
      response.ephemeralPublicKey,
      transcript,
    );
  }
}

/// Daemon-side authenticated handshake result and response.
final class RelayHandshakeResponder {
  /// Creates a responder result.
  const new({required this.hello, required this.result});

  /// Verifies an approved device and signs a daemon response.
  static Future<RelayHandshakeResponder> respond({
    required RelayClientHello hello,
    required String expectedServerId,
    required List<int> approvedDevicePublicKey,
    required RelayIdentity identity,
    List<int>? ephemeralSeed,
  }) async {
    if (hello.serverId != expectedServerId ||
        !_constantTimeEqual(hello.identityPublicKey, approvedDevicePublicKey)) {
      throw const RelaySecurityException('Device identity is not approved.');
    }
    final clientTranscript = _clientTranscript(
      hello.serverId,
      hello.sessionId,
      hello.deviceId,
      hello.identityPublicKey,
      hello.ephemeralPublicKey,
    );
    final valid = await Ed25519().verify(
      clientTranscript,
      signature: Signature(
        hello.signature,
        publicKey: SimplePublicKey(
          hello.identityPublicKey,
          type: KeyPairType.ed25519,
        ),
      ),
    );
    if (!valid) {
      throw const RelaySecurityException(
        'Device handshake signature is invalid.',
      );
    }
    final ephemeral = await _newEphemeralKeyPair(ephemeralSeed);
    final publicKey = await ephemeral.extractPublicKey();
    final unsignedResponse = RelayDaemonHello(
      identityPublicKey: identity.publicKey,
      ephemeralPublicKey: publicKey.bytes,
      signature: List<int>.filled(64, 0),
    );
    final transcript = _fullTranscript(hello, unsignedResponse);
    final response = RelayDaemonHello(
      identityPublicKey: identity.publicKey,
      ephemeralPublicKey: publicKey.bytes,
      signature: await identity._sign(transcript),
    );
    return RelayHandshakeResponder(
      hello: response,
      result: await _result(ephemeral, hello.ephemeralPublicKey, transcript),
    );
  }

  /// Signed daemon response.
  final RelayDaemonHello hello;

  /// Derived shared secret and transcript.
  final RelayHandshakeResult result;
}

Future<SimpleKeyPair> _newEphemeralKeyPair(List<int>? seed) =>
    seed == null ? X25519().newKeyPair() : X25519().newKeyPairFromSeed(seed);

Future<RelayHandshakeResult> _result(
  SimpleKeyPair local,
  List<int> remotePublic,
  List<int> transcript,
) async {
  final key = await X25519().sharedSecretKey(
    keyPair: local,
    remotePublicKey: SimplePublicKey(remotePublic, type: KeyPairType.x25519),
  );
  return RelayHandshakeResult(
    sharedSecret: await key.extractBytes(),
    transcript: transcript,
  );
}

Uint8List _clientTranscript(
  String serverId,
  String sessionId,
  String deviceId,
  List<int> identity,
  List<int> ephemeral,
) => _encodeFields(<List<int>>[
  utf8.encode('tinyrack-tinest-relay-client-v1'),
  utf8.encode(serverId),
  utf8.encode(sessionId),
  utf8.encode(deviceId),
  identity,
  ephemeral,
]);

Uint8List _fullTranscript(RelayClientHello client, RelayDaemonHello daemon) =>
    _encodeFields(<List<int>>[
      _clientTranscript(
        client.serverId,
        client.sessionId,
        client.deviceId,
        client.identityPublicKey,
        client.ephemeralPublicKey,
      ),
      daemon.identityPublicKey,
      daemon.ephemeralPublicKey,
    ]);

Uint8List _encodeFields(List<List<int>> fields) {
  final builder = BytesBuilder(copy: false);
  for (final field in fields) {
    final length = ByteData(4)..setUint32(0, field.length);
    builder
      ..add(length.buffer.asUint8List())
      ..add(field);
  }
  return builder.takeBytes();
}

void _validateKeyMaterial(
  List<int> identity,
  List<int> ephemeral,
  List<int> signature,
) {
  if (identity.length != 32 ||
      ephemeral.length != 32 ||
      signature.length != 64) {
    throw const FormatException('Invalid relay handshake key material.');
  }
}

bool _constantTimeEqual(List<int> first, List<int> second) {
  var difference = first.length ^ second.length;
  final length = first.length < second.length ? first.length : second.length;
  for (var index = 0; index < length; index += 1) {
    difference |= first[index] ^ second[index];
  }
  return difference == 0;
}

List<int> _decodeBytes(String value) =>
    base64Url.decode(base64Url.normalize(value));
