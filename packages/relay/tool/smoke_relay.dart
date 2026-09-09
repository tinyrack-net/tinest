import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:relay_protocol/relay_protocol.dart';

import 'src/smoke_relay_cli.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runRelaySmokeCli(arguments, execute: _smokeRelay);
}

Future<void> _smokeRelay(Uri base, String? readyFile) async {
  final live = await _get(base.resolve('/health/live'));
  final ready = await _get(base.resolve('/health/ready'));
  if (live != 'live\n' || ready != 'ready\n') {
    throw StateError('Unexpected relay health: live=$live ready=$ready');
  }

  final daemon = await WebSocket.connect(
    _webSocketUri(base, role: 'daemon', serverId: 'container-smoke').toString(),
  );
  // The daemon normally waits for a client before it has an envelope to send.
  // Keep it idle beyond the production client handshake timeout so release and
  // live smoke checks cover the daemon-role lifetime contract.
  await Future<void>.delayed(const Duration(seconds: 11));
  final client = await WebSocket.connect(
    _webSocketUri(base, role: 'client', serverId: 'container-smoke').toString(),
  );
  final daemonMessages = StreamIterator<dynamic>(daemon);
  final clientMessages = StreamIterator<dynamic>(client);

  client.add(Uint8List.fromList(<int>[1, 2, 3]));
  if (!await daemonMessages.moveNext().timeout(const Duration(seconds: 5))) {
    throw StateError('Relay closed before forwarding the client frame.');
  }
  final envelope = RelayEnvelope.decode(
    Uint8List.fromList(daemonMessages.current as List<int>),
  );
  daemon.add(
    RelayEnvelope(
      connectionId: envelope.connectionId,
      payload: Uint8List.fromList(<int>[4, 5, 6]),
    ).encode(),
  );
  if (!await clientMessages.moveNext().timeout(const Duration(seconds: 5)) ||
      !_sameBytes(clientMessages.current as List<int>, <int>[4, 5, 6])) {
    throw StateError('Relay did not return the daemon frame to the client.');
  }

  if (readyFile != null) {
    await File(readyFile).writeAsString('ready\n', flush: true);
    final drained = await Future.wait<bool>(<Future<bool>>[
      daemonMessages.moveNext(),
      clientMessages.moveNext(),
    ]).timeout(const Duration(seconds: 10));
    if (drained.any((hasMessage) => hasMessage) ||
        daemon.closeCode != 4002 ||
        client.closeCode != 4002) {
      throw StateError(
        'Relay did not drain cleanly: daemon=${daemon.closeCode}, '
        'client=${client.closeCode}.',
      );
    }
    return;
  }

  await Future.wait<void>(<Future<void>>[daemon.close(), client.close()]);
}

Uri _webSocketUri(Uri base, {required String role, required String serverId}) =>
    base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/v1/ws',
      queryParameters: <String, String>{'role': role, 'serverId': serverId},
    );

Future<String> _get(Uri uri) async {
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(uri)).close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('GET $uri returned ${response.statusCode}.');
    }
    return await response.transform(const SystemEncoding().decoder).join();
  } finally {
    client.close();
  }
}

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
