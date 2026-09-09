import 'dart:typed_data';

import 'package:client/src/endpoint.dart';

/// One independently probeable route to the same authoritative daemon.
sealed class HostConnection {
  /// Creates shared connection metadata.
  const new({required this.id, required this.credentialKey});

  /// Stable device-local path identifier.
  final String id;

  /// Opaque secure-storage lookup key; never credential material itself.
  final String credentialKey;
}

/// Existing direct WebSocket and HTTP route to a daemon.
final class DirectHostConnection extends HostConnection {
  /// Creates a direct route.
  const new({
    required super.id,
    required super.credentialKey,
    required this.endpoint,
  });

  /// Direct daemon WebSocket endpoint.
  final HostEndpoint endpoint;
}

/// End-to-end encrypted route through an opaque relay.
final class RelayHostConnection extends HostConnection {
  /// Creates and validates a relay route.
  new({
    required super.id,
    required super.credentialKey,
    required this.serverId,
    required this.relayUri,
    required List<int> daemonIdentityPublicKey,
  }) : daemonIdentityPublicKey = Uint8List.fromList(daemonIdentityPublicKey) {
    if (serverId.isEmpty ||
        daemonIdentityPublicKey.length != 32 ||
        (relayUri.scheme != 'wss' && relayUri.scheme != 'ws')) {
      throw const FormatException('Invalid relay host connection.');
    }
  }

  /// Authoritative identity used by relay routing and handshake verification.
  final String serverId;

  /// Outbound relay WebSocket endpoint.
  final Uri relayUri;

  /// Pinned daemon Ed25519 public key.
  final Uint8List daemonIdentityPublicKey;
}

/// Secret material loaded for one typed connection immediately before use.
sealed class HostConnectionCredential {
  const new();
}

/// Direct daemon bearer credential.
final class DirectHostCredential extends HostConnectionCredential {
  /// Creates a direct bearer credential.
  const new(this.credentials);

  /// Existing daemon authorization header value.
  final DaemonCredentials credentials;
}

/// Daemon-scoped device identity used only for relay mutual authentication.
final class RelayHostCredential extends HostConnectionCredential {
  /// Creates and validates a relay device credential.
  new({required this.deviceId, required List<int> privateKey})
    : privateKey = Uint8List.fromList(privateKey) {
    if (deviceId.isEmpty || privateKey.length != 32) {
      throw const FormatException('Invalid relay device credential.');
    }
  }

  /// Device identifier registered with this daemon.
  final String deviceId;

  /// Ed25519 private key seed stored in platform secure storage.
  final Uint8List privateKey;
}
