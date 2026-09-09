import 'dart:async';
import 'dart:math';

import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:relay_protocol/relay_protocol.dart';

/// Generates cryptographically random bytes at a typed boundary.
typedef RelayRandomBytes = List<int> Function(int length);

/// Ends every currently connected session belonging to one device.
typedef RelayDeviceSessionTerminator = Future<void> Function(String deviceId);

/// An approved device persisted by the daemon.
final class RelayApprovedDevice {
  /// Creates an approved relay device.
  new({
    required this.id,
    required this.name,
    required List<int> publicKey,
    required this.registeredAt,
    required this.lastConnectedAt,
  }) : publicKey = List<int>.unmodifiable(publicKey) {
    if (id.isEmpty || name.isEmpty || publicKey.length != 32) {
      throw const FormatException('Invalid approved relay device.');
    }
  }

  /// Stable device identifier scoped to one daemon.
  final String id;

  /// User-visible device name.
  final String name;

  /// Device Ed25519 public key.
  final List<int> publicKey;

  /// UTC registration time.
  final DateTime registeredAt;

  /// UTC time of the last authenticated connection, when any.
  final DateTime? lastConnectedAt;
}

/// Persistence port for daemon-approved devices.
abstract interface class RelayDeviceRepository {
  /// Lists every approved device.
  Future<List<RelayApprovedDevice>> list();

  /// Finds one device by its daemon-scoped identifier.
  Future<RelayApprovedDevice?> get(String id);

  /// Inserts or replaces one approved device.
  Future<void> upsert(RelayApprovedDevice device);

  /// Deletes one approved device.
  Future<void> delete(String id);
}

/// Deterministic device repository for tests and embedded compositions.
final class MemoryRelayDeviceRepository implements RelayDeviceRepository {
  final Map<String, RelayApprovedDevice> _devices =
      <String, RelayApprovedDevice>{};

  @override
  Future<void> delete(String id) async => _devices.remove(id);

  @override
  Future<RelayApprovedDevice?> get(String id) async => _devices[id];

  @override
  Future<List<RelayApprovedDevice>> list() async =>
      List<RelayApprovedDevice>.unmodifiable(_devices.values);

  @override
  Future<void> upsert(RelayApprovedDevice device) async {
    _devices[device.id] = device;
  }
}

/// Pairing failure safe to return across the daemon RPC boundary.
final class RelayPairingException implements Exception {
  /// Creates a pairing failure with a machine-readable [code].
  const new(this.code, this.message);

  /// Stable error code.
  final String code;

  /// User-safe explanation.
  final String message;

  @override
  String toString() => 'RelayPairingException($code): $message';
}

/// Successful encrypted registration and its acknowledgement capability.
final class RelayPairingRegistrationResult {
  /// Creates a successful registration result.
  new({required this.device, required List<int> offerSecret})
    : offerSecret = List<int>.unmodifiable(offerSecret);

  /// Newly registered or idempotently retried device.
  final RelayApprovedDevice device;

  /// One-time secret used only to encrypt the acknowledgement.
  final List<int> offerSecret;
}

/// Creates, consumes, lists, and revokes daemon relay registrations.
final class RelayPairingService {
  /// Creates a pairing service for one daemon identity.
  new({
    required this.serverId,
    required this.relayUri,
    required List<int> daemonIdentityPublicKey,
    required this._devices,
    required this._clock,
    required this._ids,
    RelayRandomBytes? randomBytes,
    RelayDeviceSessionTerminator? terminateDeviceSessions,
  }) : daemonIdentityPublicKey = List<int>.unmodifiable(
         daemonIdentityPublicKey,
       ),
       _randomBytes = randomBytes ?? _secureRandomBytes,
       _terminateDeviceSessions =
           terminateDeviceSessions ?? _noLiveDeviceSessions {
    if (daemonIdentityPublicKey.length != 32) {
      throw const FormatException(
        'Daemon identity public key must be 32 bytes.',
      );
    }
  }

  /// Authoritative daemon identity.
  final String serverId;

  /// Effective relay WebSocket endpoint.
  Uri relayUri;

  /// Daemon Ed25519 public identity distributed in offers.
  final List<int> daemonIdentityPublicKey;

  final RelayDeviceRepository _devices;
  final Clock _clock;
  final IdGenerator _ids;
  final RelayRandomBytes _randomBytes;
  final RelayDeviceSessionTerminator _terminateDeviceSessions;
  final Map<String, _PairingGrant> _offers = <String, _PairingGrant>{};

  /// Creates a ten-minute, one-time device registration capability.
  RelayPairingOffer createOffer() {
    final now = _clock.nowUtc();
    _offers.removeWhere((_, grant) => !now.isBefore(grant.offer.expiresAt));
    final offer = RelayPairingOffer(
      serverId: serverId,
      relayUri: relayUri,
      daemonPublicKey: daemonIdentityPublicKey,
      offerId: _ids.generate(),
      secret: _randomBytes(32),
      expiresAt: now.add(const Duration(minutes: 10)),
    );
    _offers[offer.offerId] = _PairingGrant(offer);
    return offer;
  }

  /// Consumes an offer or idempotently returns its first registered device.
  Future<RelayApprovedDevice> registerDevice({
    required String offerId,
    required List<int> offerSecret,
    required String deviceId,
    required String deviceName,
    required List<int> devicePublicKey,
  }) async {
    final grant = _offers[offerId];
    if (grant == null || !_constantTimeEqual(grant.offer.secret, offerSecret)) {
      throw const RelayPairingException(
        'invalid_offer',
        'Pairing offer is invalid.',
      );
    }
    if (!_clock.nowUtc().isBefore(grant.offer.expiresAt)) {
      _offers.remove(offerId);
      throw const RelayPairingException(
        'expired_offer',
        'Pairing offer has expired.',
      );
    }
    if (grant.device case final registered?) {
      if (registered.id == deviceId &&
          _constantTimeEqual(registered.publicKey, devicePublicKey)) {
        return registered;
      }
      throw const RelayPairingException(
        'consumed_offer',
        'Pairing offer was already used by another device.',
      );
    }
    if (deviceId.isEmpty ||
        deviceName.trim().isEmpty ||
        devicePublicKey.length != 32) {
      throw const RelayPairingException(
        'invalid_device',
        'Device identity is invalid.',
      );
    }
    final device = RelayApprovedDevice(
      id: deviceId,
      name: deviceName.trim(),
      publicKey: devicePublicKey,
      registeredAt: _clock.nowUtc(),
      lastConnectedAt: null,
    );
    await _devices.upsert(device);
    grant.device = device;
    return device;
  }

  /// Decrypts and consumes an offer-secret-protected registration request.
  Future<RelayPairingRegistrationResult> registerEncrypted(
    RelayPairingRegistrationRequest request,
  ) async {
    final grant = _offers[request.offerId];
    if (grant == null) {
      throw const RelayPairingException(
        'invalid_offer',
        'Pairing offer is invalid.',
      );
    }
    if (!_clock.nowUtc().isBefore(grant.offer.expiresAt)) {
      _offers.remove(request.offerId);
      throw const RelayPairingException(
        'expired_offer',
        'Pairing offer has expired.',
      );
    }
    final payload = await request.decrypt(
      serverId: serverId,
      offerSecret: grant.offer.secret,
    );
    final device = await registerDevice(
      offerId: request.offerId,
      offerSecret: grant.offer.secret,
      deviceId: payload.deviceId,
      deviceName: payload.deviceName,
      devicePublicKey: payload.devicePublicKey,
    );
    return RelayPairingRegistrationResult(
      device: device,
      offerSecret: grant.offer.secret,
    );
  }

  /// Lists approved devices without exposing private key material.
  Future<List<RelayApprovedDevice>> listDevices() => _devices.list();

  /// Finds an approved device for relay handshake authentication.
  Future<RelayApprovedDevice?> findDevice(String deviceId) =>
      _devices.get(deviceId);

  /// Records a successful mutually authenticated relay handshake.
  Future<void> markDeviceConnected(RelayApprovedDevice device) =>
      _devices.upsert(
        RelayApprovedDevice(
          id: device.id,
          name: device.name,
          publicKey: device.publicKey,
          registeredAt: device.registeredAt,
          lastConnectedAt: _clock.nowUtc(),
        ),
      );

  /// Revokes a device and immediately ends all of its live sessions.
  Future<void> revokeDevice(String deviceId) async {
    await _devices.delete(deviceId);
    await _terminateDeviceSessions(deviceId);
  }
}

final class _PairingGrant {
  new(this.offer);

  final RelayPairingOffer offer;
  RelayApprovedDevice? device;
}

List<int> _secureRandomBytes(int length) {
  final random = Random.secure();
  return List<int>.generate(
    length,
    (_) => random.nextInt(256),
    growable: false,
  );
}

Future<void> _noLiveDeviceSessions(String _) async {}

bool _constantTimeEqual(List<int> first, List<int> second) {
  var difference = first.length ^ second.length;
  final length = min(first.length, second.length);
  for (var index = 0; index < length; index += 1) {
    difference |= first[index] ^ second[index];
  }
  return difference == 0;
}
