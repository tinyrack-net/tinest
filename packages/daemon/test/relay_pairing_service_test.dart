import 'package:daemon/src/features/relay/application/relay_pairing_service.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:relay_protocol/relay_protocol.dart';
import 'package:test/test.dart';

void main() {
  test(
    'offer expires after ten minutes and is bound to the first device',
    () async {
      final clock = _Clock(DateTime.utc(2026, 8, 8, 12));
      final service = RelayPairingService(
        serverId: 'daemon-1',
        relayUri: Uri.parse('wss://relay.tinest.tinyrack.net/v1/ws'),
        daemonIdentityPublicKey: List<int>.filled(32, 3),
        devices: MemoryRelayDeviceRepository(),
        clock: clock,
        ids: _Ids(),
        randomBytes: (length) => List<int>.generate(length, (index) => index),
      );

      final offer = service.createOffer();
      expect(offer.expiresAt, DateTime.utc(2026, 8, 8, 12, 10));
      final firstKey = List<int>.filled(32, 7);
      final device = await service.registerDevice(
        offerId: offer.offerId,
        offerSecret: offer.secret,
        deviceId: 'phone-1',
        deviceName: 'My phone',
        devicePublicKey: firstKey,
      );
      final retry = await service.registerDevice(
        offerId: offer.offerId,
        offerSecret: offer.secret,
        deviceId: 'phone-1',
        deviceName: 'Renamed phone',
        devicePublicKey: firstKey,
      );
      expect(retry.id, device.id);
      expect(retry.name, 'My phone');
      await expectLater(
        service.registerDevice(
          offerId: offer.offerId,
          offerSecret: offer.secret,
          deviceId: 'phone-2',
          deviceName: 'Other phone',
          devicePublicKey: List<int>.filled(32, 8),
        ),
        throwsA(isA<RelayPairingException>()),
      );

      final expired = service.createOffer();
      clock.value = DateTime.utc(2026, 8, 8, 12, 10);
      await expectLater(
        service.registerDevice(
          offerId: expired.offerId,
          offerSecret: expired.secret,
          deviceId: 'tablet',
          deviceName: 'Tablet',
          devicePublicKey: List<int>.filled(32, 9),
        ),
        throwsA(isA<RelayPairingException>()),
      );
    },
    tags: const <String>['feature_test__daemon_relay__unit'],
  );

  test(
    'revocation deletes authorization and terminates live sessions',
    () async {
      final repository = MemoryRelayDeviceRepository();
      final terminated = <String>[];
      final service = RelayPairingService(
        serverId: 'daemon-1',
        relayUri: Uri.parse('wss://relay.tinest.tinyrack.net/v1/ws'),
        daemonIdentityPublicKey: List<int>.filled(32, 3),
        devices: repository,
        clock: _Clock(DateTime.utc(2026, 8, 8)),
        ids: _Ids(),
        randomBytes: (length) => List<int>.filled(length, 4),
        terminateDeviceSessions: (deviceId) async => terminated.add(deviceId),
      );
      final offer = service.createOffer();
      await service.registerDevice(
        offerId: offer.offerId,
        offerSecret: offer.secret,
        deviceId: 'phone',
        deviceName: 'Phone',
        devicePublicKey: List<int>.filled(32, 5),
      );

      await service.revokeDevice('phone');
      expect(await service.listDevices(), isEmpty);
      expect(terminated, <String>['phone']);
    },
    tags: const <String>['feature_test__daemon_relay__unit'],
  );

  test('pairing validates identity, secret, and device metadata', () async {
    expect(
      () => RelayApprovedDevice(
        id: '',
        name: '',
        publicKey: const <int>[],
        registeredAt: DateTime.utc(2026),
        lastConnectedAt: null,
      ),
      throwsFormatException,
    );
    expect(
      () => RelayPairingService(
        serverId: 'daemon',
        relayUri: Uri.parse('wss://relay.example/ws'),
        daemonIdentityPublicKey: const <int>[1],
        devices: MemoryRelayDeviceRepository(),
        clock: _Clock(DateTime.utc(2026)),
        ids: _Ids(),
      ),
      throwsFormatException,
    );
    final service = RelayPairingService(
      serverId: 'daemon',
      relayUri: Uri.parse('wss://relay.example/ws'),
      daemonIdentityPublicKey: List<int>.filled(32, 1),
      devices: MemoryRelayDeviceRepository(),
      clock: _Clock(DateTime.utc(2026)),
      ids: _Ids(),
      randomBytes: (length) => List<int>.filled(length, 2),
    );
    final offer = service.createOffer();
    await expectLater(
      service.registerDevice(
        offerId: offer.offerId,
        offerSecret: List<int>.filled(32, 9),
        deviceId: 'phone',
        deviceName: 'Phone',
        devicePublicKey: List<int>.filled(32, 3),
      ),
      throwsA(isA<RelayPairingException>()),
    );
    expect(
      const RelayPairingException('code', 'message').toString(),
      contains('code'),
    );
  });

  test('encrypted registration consumes the opaque offer capability', () async {
    final service = RelayPairingService(
      serverId: 'daemon',
      relayUri: Uri.parse('wss://relay.example/ws'),
      daemonIdentityPublicKey: List<int>.filled(32, 1),
      devices: MemoryRelayDeviceRepository(),
      clock: _Clock(DateTime.utc(2026)),
      ids: _Ids(),
      randomBytes: (length) => List<int>.filled(length, 2),
    );
    final offer = service.createOffer();
    final request = await RelayPairingRegistrationRequest.create(
      offer: offer,
      payload: RelayPairingRegistrationPayload(
        deviceId: 'phone',
        deviceName: 'My phone',
        devicePublicKey: List<int>.filled(32, 3),
      ),
    );

    final result = await service.registerEncrypted(request);

    expect(result.device.id, 'phone');
    expect(result.device.name, 'My phone');
    expect(result.offerSecret, offer.secret);
    expect(
      (await service.findDevice('phone'))?.publicKey,
      List<int>.filled(32, 3),
    );
    await expectLater(
      service.registerEncrypted(
        RelayPairingRegistrationRequest(
          offerId: 'missing',
          encryptedPayload: const <int>[1],
        ),
      ),
      throwsA(
        isA<RelayPairingException>().having(
          (error) => error.code,
          'code',
          'invalid_offer',
        ),
      ),
    );
  });
}

final class _Clock implements Clock {
  new(this.value);

  DateTime value;

  @override
  DateTime nowUtc() => value;
}

final class _Ids implements IdGenerator {
  int _next = 0;

  @override
  String generate() => 'offer-${++_next}';
}
