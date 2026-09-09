/// Explicit empty parameter object for relay procedures.
final class RelayEmptyParamsDto {
  /// Creates empty relay parameters.
  const new();

  /// Decodes empty relay parameters.
  factory fromJson(Map<String, dynamic> json) {
    if (json.isNotEmpty) {
      throw const FormatException('Expected empty relay parameters.');
    }
    return const RelayEmptyParamsDto();
  }

  /// Encodes empty relay parameters.
  Map<String, dynamic> toJson() => const <String, dynamic>{};
}

/// Current outbound relay state reported by a daemon.
final class RelayStatusDto {
  /// Creates relay state.
  const new({
    required this.enabled,
    required this.connected,
    required this.endpoint,
    required this.serverId,
  });

  /// Decodes relay state.
  factory fromJson(Map<String, dynamic> json) => RelayStatusDto(
    enabled: json['enabled']! as bool,
    connected: json['connected']! as bool,
    endpoint: json['endpoint']! as String,
    serverId: json['serverId']! as String,
  );

  /// Whether outbound relay operation is configured.
  final bool enabled;

  /// Whether the daemon control socket is currently established.
  final bool connected;

  /// Effective relay WebSocket endpoint.
  final String endpoint;

  /// Authoritative daemon identity used for routing.
  final String serverId;

  /// Encodes relay state.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'enabled': enabled,
    'connected': connected,
    'endpoint': endpoint,
    'serverId': serverId,
  };
}

/// Short-lived pairing link returned by the daemon.
final class RelayPairingOfferDto {
  /// Creates a pairing offer result.
  const new({required this.url, required this.expiresAt});

  /// Decodes a pairing offer result.
  factory fromJson(Map<String, dynamic> json) => RelayPairingOfferDto(
    url: json['url']! as String,
    expiresAt: DateTime.parse(json['expiresAt']! as String).toUtc(),
  );

  /// Fragment-only pairing URL.
  final String url;

  /// UTC expiration instant.
  final DateTime expiresAt;

  /// Encodes a pairing offer result.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'url': url,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
  };
}

/// Public metadata for one daemon-approved device.
final class RelayDeviceDto {
  /// Creates approved device metadata.
  const new({
    required this.id,
    required this.name,
    required this.registeredAt,
    required this.lastConnectedAt,
  });

  /// Decodes approved device metadata.
  factory fromJson(Map<String, dynamic> json) => RelayDeviceDto(
    id: json['id']! as String,
    name: json['name']! as String,
    registeredAt: DateTime.parse(json['registeredAt']! as String).toUtc(),
    lastConnectedAt: json['lastConnectedAt'] == null
        ? null
        : DateTime.parse(json['lastConnectedAt']! as String).toUtc(),
  );

  /// Daemon-scoped device identifier.
  final String id;

  /// User-visible device name.
  final String name;

  /// UTC registration time.
  final DateTime registeredAt;

  /// Last authenticated relay connection time.
  final DateTime? lastConnectedAt;

  /// Encodes approved device metadata.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'registeredAt': registeredAt.toUtc().toIso8601String(),
    'lastConnectedAt': lastConnectedAt?.toUtc().toIso8601String(),
  };
}

/// Result of listing approved relay devices.
final class RelayDeviceListDto {
  /// Creates a device-list result.
  const new({required this.devices});

  /// Decodes a device-list result.
  factory fromJson(Map<String, dynamic> json) => RelayDeviceListDto(
    devices: (json['devices']! as List<dynamic>)
        .map(
          (value) =>
              RelayDeviceDto.fromJson(Map<String, dynamic>.from(value! as Map)),
        )
        .toList(growable: false),
  );

  /// Approved devices in stable repository order.
  final List<RelayDeviceDto> devices;

  /// Encodes a device-list result.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'devices': devices.map((device) => device.toJson()).toList(growable: false),
  };
}

/// Parameters for changing relay activation.
final class RelaySetEnabledParamsDto {
  /// Creates relay activation parameters.
  const new({required this.enabled});

  /// Decodes relay activation parameters.
  factory fromJson(Map<String, dynamic> json) =>
      RelaySetEnabledParamsDto(enabled: json['enabled']! as bool);

  /// Desired relay activation.
  final bool enabled;

  /// Encodes relay activation parameters.
  Map<String, dynamic> toJson() => <String, dynamic>{'enabled': enabled};
}

/// Parameters for changing the daemon's relay endpoint.
final class RelaySetEndpointParamsDto {
  /// Creates relay endpoint parameters.
  const new({required this.endpoint});

  /// Decodes relay endpoint parameters.
  factory fromJson(Map<String, dynamic> json) =>
      RelaySetEndpointParamsDto(endpoint: json['endpoint']! as String);

  /// Desired relay WebSocket endpoint.
  final String endpoint;

  /// Encodes relay endpoint parameters.
  Map<String, dynamic> toJson() => <String, dynamic>{'endpoint': endpoint};
}

/// Parameters for revoking one approved device.
final class RelayRevokeDeviceParamsDto {
  /// Creates device revocation parameters.
  const new({required this.deviceId});

  /// Decodes device revocation parameters.
  factory fromJson(Map<String, dynamic> json) =>
      RelayRevokeDeviceParamsDto(deviceId: json['deviceId']! as String);

  /// Device identifier to revoke.
  final String deviceId;

  /// Encodes device revocation parameters.
  Map<String, dynamic> toJson() => <String, dynamic>{'deviceId': deviceId};
}
