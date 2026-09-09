import 'package:app/src/features/hosts/domain/pairing_intent.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay_protocol/relay_protocol.dart';

void main() {
  final now = DateTime.utc(2026, 8, 11, 12);

  test('parses the canonical fragment without exposing its capability', () {
    final uri = _offer(expiresAt: now.add(const Duration(minutes: 10)))
        .toUrl(Uri.parse('https://tinest.tinyrack.net/pair'));

    final intent = PairingIntent.parse(uri, nowUtc: now);

    expect(intent.serverId, 'daemon-1234567890');
    expect(intent.relayUri, Uri.parse('wss://relay.tinest.tinyrack.net/v1/ws'));
    expect(intent.expiresAt, now.add(const Duration(minutes: 10)));
    expect(intent.pairingUrl, uri);
    expect(intent.toString(), isNot(contains('offer=')));
  });

  test('rejects another origin, noncanonical URLs, and expired offers', () {
    final valid = _offer(expiresAt: now.add(const Duration(minutes: 10)));

    expect(
      () => PairingIntent.parse(
        valid.toUrl(Uri.parse('https://example.test/pair')),
        nowUtc: now,
      ),
      throwsFormatException,
    );
    expect(
      () => PairingIntent.parse(
        _offer(expiresAt: now)
            .toUrl(Uri.parse('https://tinest.tinyrack.net/pair')),
        nowUtc: now,
      ),
      throwsFormatException,
    );
    expect(
      () => PairingIntent.parse(
        valid.toUrl(Uri.parse('http://tinest.tinyrack.net/pair')),
        nowUtc: now,
      ),
      throwsFormatException,
    );
    expect(
      () => PairingIntent.parse(
        valid.toUrl(Uri.parse('https://tinest.tinyrack.net:8443/pair')),
        nowUtc: now,
      ),
      throwsFormatException,
    );
    expect(
      () => PairingIntent.parse(
        valid.toUrl(Uri.parse('https://tinest.tinyrack.net/pair?offer=logged')),
        nowUtc: now,
      ),
      throwsFormatException,
    );
  });
}

RelayPairingOffer _offer({required DateTime expiresAt}) => RelayPairingOffer(
  serverId: 'daemon-1234567890',
  relayUri: Uri.parse('wss://relay.tinest.tinyrack.net/v1/ws'),
  daemonPublicKey: List<int>.filled(32, 1),
  offerId: 'offer-id',
  secret: List<int>.filled(32, 2),
  expiresAt: expiresAt,
);
