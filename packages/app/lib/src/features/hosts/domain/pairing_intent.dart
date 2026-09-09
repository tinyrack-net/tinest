import 'package:client/client.dart';

/// A locally validated request to register this device with one daemon.
///
/// The capability-bearing URL is retained for the pairing port but deliberately
/// omitted from [toString] so diagnostics cannot accidentally disclose it.
final class PairingIntent {
  const new _({
    required this.pairingUrl,
    required this.serverId,
    required this.relayUri,
    required this.expiresAt,
  });

  /// Parses the canonical HTTPS pairing URL and rejects expired capabilities.
  factory parse(Uri uri, {required DateTime nowUtc}) {
    if (uri.scheme != 'https' ||
        uri.host != 'tinest.tinyrack.net' ||
        uri.path != '/pair' ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty) {
      throw const FormatException('Unsupported pairing URL.');
    }
    final offer = inspectRelayPairingOffer(uri);
    if (!nowUtc.toUtc().isBefore(offer.expiresAt)) {
      throw const FormatException('Pairing offer has expired.');
    }
    return PairingIntent._(
      pairingUrl: uri,
      serverId: offer.serverId,
      relayUri: offer.relayUri,
      expiresAt: offer.expiresAt,
    );
  }

  /// Capability URL consumed only by the typed pairing port.
  final Uri pairingUrl;

  /// Authoritative daemon identity embedded in the signed offer context.
  final String serverId;

  /// Relay server selected by the daemon.
  final Uri relayUri;

  /// UTC expiration time of the one-time capability.
  final DateTime expiresAt;

  @override
  String toString() =>
      'PairingIntent(serverId: $serverId, relayUri: $relayUri, '
      'expiresAt: $expiresAt)';
}
