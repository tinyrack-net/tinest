import 'dart:convert';

import 'package:daemon/src/features/relay/application/relay_pairing_service.dart';
import 'package:daemon/src/shared/infrastructure/persistence/repositories.dart';

/// Stores approved relay devices in the daemon's SQLite settings table.
final class SettingsRelayDeviceRepository implements RelayDeviceRepository {
  /// Creates a device repository over [settings].
  const new(this.settings);

  static const String _key = 'relay.approvedDevices';

  /// SQLite-backed settings port.
  final SettingsRepository settings;

  @override
  Future<void> delete(String id) async {
    final devices = await list();
    await _write(devices.where((device) => device.id != id).toList());
  }

  @override
  Future<RelayApprovedDevice?> get(String id) async {
    for (final device in await list()) {
      if (device.id == id) {
        return device;
      }
    }
    return null;
  }

  @override
  Future<List<RelayApprovedDevice>> list() async {
    final encoded = await settings.getValue(_key);
    if (encoded == null) {
      return const <RelayApprovedDevice>[];
    }
    final decoded = jsonDecode(encoded);
    if (decoded is! List) {
      throw const FormatException('Invalid approved relay device data.');
    }
    return List<RelayApprovedDevice>.unmodifiable(
      decoded.map((value) {
        if (value is! Map<String, dynamic>) {
          throw const FormatException('Invalid approved relay device.');
        }
        return _fromJson(value);
      }),
    );
  }

  @override
  Future<void> upsert(RelayApprovedDevice device) async {
    final devices = await list();
    await _write(<RelayApprovedDevice>[
      ...devices.where((existing) => existing.id != device.id),
      device,
    ]);
  }

  Future<void> _write(List<RelayApprovedDevice> devices) => settings.setValue(
    _key,
    jsonEncode(devices.map(_toJson).toList(growable: false)),
  );
}

RelayApprovedDevice _fromJson(Map<String, dynamic> json) {
  try {
    return RelayApprovedDevice(
      id: json['id']! as String,
      name: json['name']! as String,
      publicKey: base64Url.decode(
        base64Url.normalize(json['publicKey']! as String),
      ),
      registeredAt: DateTime.parse(json['registeredAt']! as String).toUtc(),
      lastConnectedAt: json['lastConnectedAt'] == null
          ? null
          : DateTime.parse(json['lastConnectedAt']! as String).toUtc(),
    );
  } on Object catch (error) {
    if (error is FormatException) {
      rethrow;
    }
    throw FormatException('Invalid approved relay device data.', error);
  }
}

Map<String, Object?> _toJson(RelayApprovedDevice device) => <String, Object?>{
  'id': device.id,
  'name': device.name,
  'publicKey': base64UrlEncode(device.publicKey),
  'registeredAt': device.registeredAt.toUtc().toIso8601String(),
  'lastConnectedAt': device.lastConnectedAt?.toUtc().toIso8601String(),
};
