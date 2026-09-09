import 'dart:io';

import 'package:client/client.dart';
import 'package:daemon/daemon.dart';
import 'package:relay_protocol/relay_protocol.dart';
import 'package:test/test.dart';

void main() {
  test(
    'relay status, pairing offer, and activation cross the real daemon',
    () async {
      final state = await Directory.systemTemp.createTemp(
        'tinest-relay-state-',
      );
      final config = DaemonConfig(
        homeDirectory: state.path,
        configDirectory: state.path,
        port: 0,
        bearerToken: 'relay-test-token-0123456789abcdef012345',
        useEnvironmentCredentials: false,
      );
      var handle = await DaemonApplication.start(config);
      var client = await _connect(handle);
      try {
        expect(client.serverInfo.features['relay'], isTrue);
        expect((await client.getRelayStatus()).enabled, isFalse);
        final offer = await client.createRelayPairingOffer();
        final parsed = RelayPairingOffer.parseUrl(Uri.parse(offer.url));
        expect(parsed.serverId, handle.serverId);
        expect(parsed.expiresAt, offer.expiresAt);
        expect(await client.listRelayDevices(), isEmpty);
        expect((await client.setRelayEnabled(enabled: true)).enabled, isTrue);
        final changed = await client.setRelayEndpoint(
          'wss://self-hosted.example/v1/ws',
        );
        expect(changed.endpoint, 'wss://self-hosted.example/v1/ws');

        await client.close();
        await handle.stop();
        handle = await DaemonApplication.start(config);
        client = await _connect(handle);
        final restarted = await client.getRelayStatus();
        expect(restarted.enabled, isTrue);
        expect(restarted.endpoint, 'wss://self-hosted.example/v1/ws');
        final restartedOffer = RelayPairingOffer.parseUrl(
          Uri.parse((await client.createRelayPairingOffer()).url),
        );
        expect(restartedOffer.relayUri, Uri.parse(restarted.endpoint));
      } finally {
        await client.close();
        await handle.stop();
        await state.delete(recursive: true);
      }
    },
    tags: const <String>['feature_test__daemon_relay__verticalSlice'],
  );
}

Future<TinestClient> _connect(DaemonHandle handle) => TinestClient.connect(
  endpoint: HostEndpoint(websocketUri: handle.boundEndpoint),
  credentials: const DaemonCredentials(
    bearerToken: 'relay-test-token-0123456789abcdef012345',
  ),
  clientId: 'relay-test',
  clientKind: 'test',
);
