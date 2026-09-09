import 'dart:convert';

import 'package:client/client.dart';
import 'package:qr/qr.dart';

/// Renders current relay state for scripts or humans.
Future<int> relayStatus({
  required RelayApi relay,
  required StringSink output,
  bool json = false,
}) async {
  final status = await relay.getRelayStatus();
  if (json) {
    output.writeln(jsonEncode(status.toJson()));
  } else {
    output
      ..writeln('Relay: ${status.enabled ? 'enabled' : 'disabled'}')
      ..writeln('Connection: ${status.connected ? 'connected' : 'offline'}')
      ..writeln('Server ID: ${status.serverId}')
      ..writeln('Endpoint: ${status.endpoint}');
  }
  return 0;
}

/// Changes relay activation and prints the resulting state.
Future<int> relaySetEnabled({
  required RelayApi relay,
  required StringSink output,
  required bool enabled,
}) async {
  final status = await relay.setRelayEnabled(enabled: enabled);
  output.writeln(status.enabled ? 'Relay enabled.' : 'Relay disabled.');
  return 0;
}

/// Creates a short-lived pairing capability and terminal QR.
Future<int> relayPair({
  required RelayApi relay,
  required StringSink output,
  required bool enableRelay,
  required bool json,
}) async {
  var status = await relay.getRelayStatus();
  if (!status.enabled) {
    if (!enableRelay) {
      throw const FormatException(
        'Relay is disabled. Pass --relay to enable it while pairing.',
      );
    }
    status = await relay.setRelayEnabled(enabled: true);
  }
  final offer = await relay.createRelayPairingOffer();
  if (json) {
    output.writeln(
      jsonEncode(<String, dynamic>{
        ...offer.toJson(),
        'serverId': status.serverId,
      }),
    );
  } else {
    output
      ..writeln('Pairing link (expires ${offer.expiresAt.toLocal()}):')
      ..writeln(offer.url)
      ..writeln()
      ..write(_terminalQr(offer.url));
  }
  return 0;
}

/// Lists daemon-approved relay devices.
Future<int> relayDevicesList({
  required RelayApi relay,
  required StringSink output,
  bool json = false,
}) async {
  final devices = await relay.listRelayDevices();
  if (json) {
    output.writeln(
      jsonEncode(devices.map((device) => device.toJson()).toList()),
    );
  } else if (devices.isEmpty) {
    output.writeln('No approved devices.');
  } else {
    for (final device in devices) {
      output.writeln('${device.id}\t${device.name}\t${device.registeredAt}');
    }
  }
  return 0;
}

/// Revokes one device and its live relay sessions.
Future<int> relayDeviceRevoke({
  required RelayApi relay,
  required StringSink output,
  required String deviceId,
}) async {
  await relay.revokeRelayDevice(deviceId);
  output.writeln('Revoked $deviceId.');
  return 0;
}

String _terminalQr(String data) {
  final image = QrImage(QrCode(payload: QrPayload.fromString(data)));
  const quiet = 2;
  final size = image.moduleCount + quiet * 2;
  bool dark(int row, int column) =>
      row >= quiet &&
      column >= quiet &&
      row < image.moduleCount + quiet &&
      column < image.moduleCount + quiet &&
      image.isDark(row - quiet, column - quiet);
  final buffer = StringBuffer();
  for (var row = 0; row < size; row += 2) {
    for (var column = 0; column < size; column += 1) {
      final top = dark(row, column);
      final bottom = row + 1 < size && dark(row + 1, column);
      buffer.write(switch ((top, bottom)) {
        (true, true) => '█',
        (true, false) => '▀',
        (false, true) => '▄',
        (false, false) => ' ',
      });
    }
    buffer.writeln();
  }
  return buffer.toString();
}
