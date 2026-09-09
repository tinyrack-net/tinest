import 'dart:async';

import 'package:client/client.dart';
import 'package:relay_protocol/relay_protocol.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

void main() {
  test('offer inspection exposes metadata without capability material', () {
    final offer = RelayPairingOffer(
      serverId: 'daemon-1',
      relayUri: Uri.parse('wss://relay.example/v1/ws'),
      daemonPublicKey: List<int>.filled(32, 1),
      offerId: 'offer-1',
      secret: List<int>.filled(32, 2),
      expiresAt: DateTime.utc(2026, 8, 8, 12, 10),
    );

    final metadata = inspectRelayPairingOffer(
      offer.toUrl(Uri.parse('https://tinest.tinyrack.net/pair')),
    );

    expect(metadata.serverId, offer.serverId);
    expect(metadata.relayUri, offer.relayUri);
    expect(metadata.expiresAt, offer.expiresAt);
  });

  test('lost acknowledgement retries with the same device identity', () async {
    final offer = RelayPairingOffer(
      serverId: 'daemon-1',
      relayUri: Uri.parse('wss://relay.example/v1/ws'),
      daemonPublicKey: List<int>.filled(32, 1),
      offerId: 'offer-1',
      secret: List<int>.filled(32, 2),
      expiresAt: DateTime.utc(2026, 8, 8, 12, 10),
    );
    final connector = _LostAcknowledgementConnector(offer);
    final pairer = RelayDevicePairer(
      connector: connector,
      nowUtc: () => DateTime.utc(2026, 8, 8, 12),
    );

    final result = await pairer.pair(
      pairingUrl: offer.toUrl(Uri.parse('https://tinest.tinyrack.net/pair')),
      deviceId: 'phone',
      deviceName: 'Phone',
      connectionId: 'relay',
      credentialKey: 'relay-key',
    );

    expect(result.credential.deviceId, 'phone');
    expect(connector.requests, hasLength(2));
    expect(connector.requests[1], connector.requests[0]);
  });
}

final class _LostAcknowledgementConnector implements WebSocketConnector {
  new(this.offer);

  final RelayPairingOffer offer;
  final List<List<int>> requests = <List<int>>[];

  @override
  Future<StreamChannel<dynamic>> connect(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    final socket = StreamChannelController<dynamic>(sync: true);
    unawaited(
      socket.foreign.stream.first.then((message) async {
        final frame = RelayWireFrame.decode(message! as List<int>);
        requests.add(List<int>.of(frame.payload));
        if (requests.length == 1) {
          await socket.foreign.sink.close();
          return;
        }
        final request = RelayPairingRegistrationRequest.decode(frame.payload);
        final payload = await request.decrypt(
          serverId: offer.serverId,
          offerSecret: offer.secret,
        );
        socket.foreign.sink.add(
          RelayWireFrame(
            type: RelayWireFrameType.pairingAccepted,
            payload: await encryptRelayPairingAccepted(
              serverId: offer.serverId,
              offerId: offer.offerId,
              offerSecret: offer.secret,
              deviceId: payload.deviceId,
            ),
          ).encode(),
        );
      }),
    );
    return socket.local;
  }
}
