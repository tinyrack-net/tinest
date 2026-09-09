import 'package:daemon/src/features/relay/application/relay_control_service.dart';
import 'package:daemon/src/features/relay/application/relay_pairing_service.dart';
import 'package:daemon/src/features/relay/transport/rpc_bindings.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:daemon/src/transport/rpc/binding.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  test(
    'control service publishes activation and connectivity transitions',
    () async {
      final applied = <bool>[];
      final endpoints = <Uri>[];
      final devices = MemoryRelayDeviceRepository();
      final pairing = RelayPairingService(
        serverId: 'daemon-1',
        relayUri: Uri.parse('wss://relay.example/v1/ws'),
        daemonIdentityPublicKey: List<int>.filled(32, 1),
        devices: devices,
        clock: const _Clock(),
        ids: const _Ids(),
        randomBytes: (length) => List<int>.filled(length, 2),
      );
      final service = RelayControlService(
        enabled: false,
        endpoint: Uri.parse('wss://relay.example/v1/ws'),
        serverId: 'daemon-1',
        pairing: pairing,
        applyEnabled: ({required enabled}) async => applied.add(enabled),
        applyEndpoint: (endpoint) async => endpoints.add(endpoint),
      );
      final updates = <RelayStatus>[];
      final subscription = service.updates.listen(updates.add);

      expect(service.status.enabled, isFalse);
      expect((await service.setEnabled(enabled: false)).enabled, isFalse);
      expect((await service.setEnabled(enabled: true)).enabled, isTrue);
      service
        ..setConnected(connected: true)
        ..setConnected(connected: true);
      expect(service.status.connected, isTrue);
      expect(service.status.endpoint, 'wss://relay.example/v1/ws');
      expect(service.status.serverId, 'daemon-1');
      expect(applied, <bool>[true]);
      expect(updates, hasLength(2));

      final endpointStatus = await service.setEndpoint(
        'wss://self-hosted.example/v1/ws',
      );
      expect(endpointStatus.endpoint, 'wss://self-hosted.example/v1/ws');
      expect(pairing.relayUri, Uri.parse(endpointStatus.endpoint));
      expect(endpoints, <Uri>[Uri.parse(endpointStatus.endpoint)]);
      await expectLater(
        service.setEndpoint('https://not-a-websocket.example'),
        throwsFormatException,
      );

      final offer = service.createOffer();
      expect(offer.url, startsWith('https://tinest.tinyrack.net/pair#offer='));
      expect(offer.expiresAt, DateTime.utc(2026, 8, 8, 0, 10));
      await devices.upsert(
        RelayApprovedDevice(
          id: 'phone',
          name: 'My phone',
          publicKey: List<int>.filled(32, 3),
          registeredAt: DateTime.utc(2026, 8, 7),
          lastConnectedAt: DateTime.utc(2026, 8, 8),
        ),
      );
      final listed = (await service.listDevices()).single;
      expect(listed.id, 'phone');
      expect(listed.name, 'My phone');
      expect(listed.registeredAt, DateTime.utc(2026, 8, 7));
      expect(listed.lastConnectedAt, DateTime.utc(2026, 8, 8));
      final bindings = relayRpcBindings(service);
      final endpointResult = await bindings
          .singleWhere(
            (item) => item.procedure.name == relaySetEndpointProcedure.name,
          )
          .invoke(const <String, dynamic>{
            'endpoint': 'wss://second-relay.example/v1/ws',
          }, RpcConnectionContext());
      expect(endpointResult['endpoint'], 'wss://second-relay.example/v1/ws');
      final listResult = await bindings
          .singleWhere(
            (item) => item.procedure.name == relayListDevicesProcedure.name,
          )
          .invoke(const <String, dynamic>{}, RpcConnectionContext());
      expect(listResult['devices'], hasLength(1));
      await bindings
          .singleWhere(
            (item) => item.procedure.name == relayRevokeDeviceProcedure.name,
          )
          .invoke(const <String, dynamic>{
            'deviceId': 'phone',
          }, RpcConnectionContext());
      expect(await service.listDevices(), isEmpty);
      await service.revokeDevice('missing');
      expect((await service.setEnabled(enabled: false)).connected, isFalse);
      await subscription.cancel();
      await service.close();
    },
    tags: const <String>['feature_test__daemon_relay__unit'],
  );
}

final class _Clock implements Clock {
  const new();

  @override
  DateTime nowUtc() => DateTime.utc(2026, 8, 8);
}

final class _Ids implements IdGenerator {
  const new();

  @override
  String generate() => 'offer-1';
}
