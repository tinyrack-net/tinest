import 'dart:async';
import 'dart:math';

import 'package:client/src/connection.dart';
import 'package:client/src/web_socket_connector.dart';
import 'package:relay_protocol/relay_protocol.dart';

/// Non-secret metadata decoded from a relay pairing capability.
final class RelayPairingOfferMetadata {
  /// Creates validated, non-secret offer metadata.
  const new({
    required this.serverId,
    required this.relayUri,
    required this.expiresAt,
  });

  /// Authoritative daemon identity.
  final String serverId;

  /// Relay WebSocket endpoint selected by the daemon.
  final Uri relayUri;

  /// UTC expiration of the one-time capability.
  final DateTime expiresAt;
}

/// Validates a relay offer and returns only metadata safe for confirmation UI.
RelayPairingOfferMetadata inspectRelayPairingOffer(Uri pairingUrl) {
  final offer = RelayPairingOffer.parseUrl(pairingUrl);
  return RelayPairingOfferMetadata(
    serverId: offer.serverId,
    relayUri: offer.relayUri,
    expiresAt: offer.expiresAt,
  );
}

/// Device-local result retained after a one-time offer is consumed.
final class RelayPairingResult {
  /// Creates a paired relay path and its separately stored credential.
  const new({required this.connection, required this.credential});

  /// Non-secret relay path persisted in the app settings document.
  final RelayHostConnection connection;

  /// Daemon-scoped private identity persisted in secure storage.
  final RelayHostCredential credential;
}

/// Consumes a pairing URL without exposing its secret in an HTTP request.
final class RelayDevicePairer {
  /// Creates a platform-neutral pairer.
  new({WebSocketConnector? connector, DateTime Function()? nowUtc})
    : _connector = connector ?? createWebSocketConnector(),
      _nowUtc = nowUtc ?? _systemNowUtc;

  final WebSocketConnector _connector;
  final DateTime Function() _nowUtc;

  /// Registers this device and returns long-lived connection material.
  Future<RelayPairingResult> pair({
    required Uri pairingUrl,
    required String deviceId,
    required String deviceName,
    required String connectionId,
    required String credentialKey,
  }) async {
    final offer = RelayPairingOffer.parseUrl(pairingUrl);
    if (!_nowUtc().isBefore(offer.expiresAt)) {
      throw const RelaySecurityException('Pairing offer has expired.');
    }
    final seed = _secureBytes(32);
    final identity = await RelayIdentity.fromSeed(seed);
    final request = await RelayPairingRegistrationRequest.create(
      offer: offer,
      payload: RelayPairingRegistrationPayload(
        deviceId: deviceId,
        deviceName: deviceName,
        devicePublicKey: identity.publicKey,
      ),
    );
    final uri = offer.relayUri.replace(
      queryParameters: <String, String>{
        ...offer.relayUri.queryParameters,
        'role': 'client',
        'serverId': offer.serverId,
      },
    );
    for (var attempt = 0; attempt < 2; attempt += 1) {
      try {
        await _registerOnce(
          uri: uri,
          offer: offer,
          request: request,
          expectedDeviceId: deviceId,
        );
        return RelayPairingResult(
          connection: RelayHostConnection(
            id: connectionId,
            credentialKey: credentialKey,
            serverId: offer.serverId,
            relayUri: offer.relayUri,
            daemonIdentityPublicKey: offer.daemonPublicKey,
          ),
          credential: RelayHostCredential(deviceId: deviceId, privateKey: seed),
        );
      } on _RelayPairingAcknowledgementLost {
        if (attempt == 1) {
          throw const RelaySecurityException(
            'Pairing acknowledgement is missing.',
          );
        }
      }
    }
    throw StateError('Pairing retry loop completed without a result.');
  }

  Future<void> _registerOnce({
    required Uri uri,
    required RelayPairingOffer offer,
    required RelayPairingRegistrationRequest request,
    required String expectedDeviceId,
  }) async {
    final channel = await _connector.connect(
      uri,
      headers: const <String, String>{},
    );
    final iterator = StreamIterator<dynamic>(channel.stream);
    try {
      channel.sink.add(
        RelayWireFrame(
          type: RelayWireFrameType.pairingRequest,
          payload: request.encode(),
        ).encode(),
      );
      bool received;
      try {
        received = await iterator.moveNext().timeout(
          const Duration(seconds: 10),
        );
      } on TimeoutException {
        throw const _RelayPairingAcknowledgementLost();
      }
      if (!received) throw const _RelayPairingAcknowledgementLost();
      if (iterator.current is! List<int>) {
        throw const RelaySecurityException(
          'Pairing acknowledgement is invalid.',
        );
      }
      final frame = RelayWireFrame.decode(iterator.current! as List<int>);
      if (frame.type != RelayWireFrameType.pairingAccepted) {
        throw const RelaySecurityException(
          'Pairing acknowledgement is invalid.',
        );
      }
      final acceptedDeviceId = await decryptRelayPairingAccepted(
        offer: offer,
        encrypted: frame.payload,
      );
      if (acceptedDeviceId != expectedDeviceId) {
        throw const RelaySecurityException(
          'Pairing acknowledgement changed device identity.',
        );
      }
    } finally {
      await iterator.cancel();
      await channel.sink.close();
    }
  }
}

final class _RelayPairingAcknowledgementLost implements Exception {
  const new();
}

List<int> _secureBytes(int length) {
  final random = Random.secure();
  return List<int>.generate(
    length,
    (_) => random.nextInt(256),
    growable: false,
  );
}

DateTime _systemNowUtc() => DateTime.now().toUtc();
