import 'dart:async';

import 'package:app/src/features/hosts/application/host_controller.dart';
import 'package:protocol/protocol.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'relay_devices_controller.g.dart';

@Riverpod(retry: noAutomaticRetry)
/// Approved relay devices of one daemon.
///
/// Stays in its loading state until the daemon connects: an approved-device
/// list that rendered as empty before the daemon answered would misreport
/// revoked access.
Future<List<RelayDeviceDto>> relayDevices(Ref ref, String hostId) async {
  final api = await watchConnectedHostApi(ref, hostId);
  if (api == null) {
    // The connection watch re-runs this build on every connection change, so
    // the pending future is discarded as soon as the daemon connects.
    return await Completer<List<RelayDeviceDto>>().future;
  }
  return await api.relay.listRelayDevices();
}
