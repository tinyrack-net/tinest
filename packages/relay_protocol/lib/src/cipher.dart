import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:relay_protocol/src/record.dart';

/// Traffic direction bound into key derivation and associated data.
enum RelayDirection {
  /// Traffic sent by a registered device.
  clientToDaemon,

  /// Traffic sent by the daemon to a registered device.
  daemonToClient,
}

/// Invalid, reordered, replayed, or unauthenticated relay traffic.
final class RelaySecurityException implements Exception {
  /// Creates a failure with a safe diagnostic [message].
  const new(this.message);

  /// Diagnostic that never includes plaintext or secret key material.
  final String message;

  @override
  String toString() => 'RelaySecurityException: $message';
}

/// Stateful ordered encryption for one direction of a relay session.
final class RelayCipherState {
  new _({
    required this._cipher,
    required this._key,
    required this._noncePrefix,
    required this._associatedDataPrefix,
  });

  /// Derives a direction-specific state from an authenticated handshake.
  static Future<RelayCipherState> create({
    required List<int> sharedSecret,
    required List<int> transcript,
    required RelayDirection direction,
  }) async {
    if (sharedSecret.length != 32) {
      throw const RelaySecurityException('Shared secret must be 32 bytes.');
    }
    final directionBytes = utf8.encode(direction.name);
    final digest = await Sha256().hash(<int>[...transcript, ...directionBytes]);
    final key = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: SecretKey(sharedSecret),
      nonce: transcript,
      info: <int>[
        ...utf8.encode('tinyrack-tinest-relay-v1:'),
        ...directionBytes,
      ],
    );
    return RelayCipherState._(
      cipher: Xchacha20.poly1305Aead(),
      key: key,
      noncePrefix: Uint8List.fromList(digest.bytes.take(16).toList()),
      associatedDataPrefix: Uint8List.fromList(<int>[
        1,
        direction.index,
        ...digest.bytes.take(8),
      ]),
    );
  }

  static const int _sequenceBytes = 8;
  static const int _macBytes = 16;

  final Cipher _cipher;
  final SecretKey _key;
  final Uint8List _noncePrefix;
  final Uint8List _associatedDataPrefix;
  int _sendSequence = 0;
  int _receiveSequence = 0;

  /// Encrypts the next plaintext record and prefixes its sequence number.
  Future<Uint8List> encrypt(List<int> plaintext) async {
    if (plaintext.length > maxRelayPlaintextRecordBytes) {
      throw RangeError.range(
        plaintext.length,
        0,
        maxRelayPlaintextRecordBytes,
        'plaintext.length',
      );
    }
    final sequence = _sendSequence;
    final sequenceBytes = _encodeSequence(sequence);
    final box = await _cipher.encrypt(
      plaintext,
      secretKey: _key,
      nonce: <int>[..._noncePrefix, ...sequenceBytes],
      aad: <int>[..._associatedDataPrefix, ...sequenceBytes],
    );
    _sendSequence += 1;
    return Uint8List.fromList(<int>[
      ...sequenceBytes,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
  }

  /// Authenticates and decrypts exactly the next expected record.
  Future<Uint8List> decrypt(List<int> encrypted) async {
    if (encrypted.length < _sequenceBytes + _macBytes) {
      throw const RelaySecurityException('Encrypted record is truncated.');
    }
    final sequenceBytes = encrypted.take(_sequenceBytes).toList();
    final sequence = _decodeSequence(sequenceBytes);
    if (sequence != _receiveSequence) {
      throw RelaySecurityException(
        'Expected sequence $_receiveSequence but received $sequence.',
      );
    }
    final macStart = encrypted.length - _macBytes;
    final box = SecretBox(
      encrypted.sublist(_sequenceBytes, macStart),
      nonce: <int>[..._noncePrefix, ...sequenceBytes],
      mac: Mac(encrypted.sublist(macStart)),
    );
    try {
      final plaintext = await _cipher.decrypt(
        box,
        secretKey: _key,
        aad: <int>[..._associatedDataPrefix, ...sequenceBytes],
      );
      _receiveSequence += 1;
      return Uint8List.fromList(plaintext);
    } on SecretBoxAuthenticationError catch (_) {
      throw const RelaySecurityException(
        'Encrypted record authentication failed.',
      );
    }
  }
}

Uint8List _encodeSequence(int value) {
  final data = ByteData(8)..setUint64(0, value);
  return data.buffer.asUint8List();
}

int _decodeSequence(List<int> bytes) =>
    ByteData.sublistView(Uint8List.fromList(bytes)).getUint64(0);
