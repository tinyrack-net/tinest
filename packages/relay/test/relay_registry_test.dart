import 'dart:async';
import 'dart:typed_data';

import 'package:relay/relay.dart';
import 'package:test/test.dart';

void main() {
  test(
    'routes opaque frames between one daemon and multiple clients',
    () async {
      final registry = RelayRegistry(maxClientsPerDaemon: 2);
      final daemon = MemoryRelayPeer();
      final first = MemoryRelayPeer();
      final second = MemoryRelayPeer();

      registry
        ..attachDaemon(serverId: 'daemon-1', peer: daemon)
        ..attachClient(serverId: 'daemon-1', peer: first)
        ..attachClient(serverId: 'daemon-1', peer: second);

      first.receive(Uint8List.fromList(<int>[1, 2, 3]));
      await pumpEventQueue();
      expect(daemon.sent, hasLength(1));
      expect(daemon.sent.single.payload, <int>[1, 2, 3]);
      expect(daemon.sent.single.connectionId, isNotEmpty);

      daemon.receive(
        RelayEnvelope(
          connectionId: daemon.sent.single.connectionId,
          payload: Uint8List.fromList(<int>[4, 5]),
        ).encode(),
      );
      await pumpEventQueue();
      expect(first.sent.single.payload, <int>[4, 5]);
      expect(second.sent, isEmpty);
    },
  );

  test('rejects duplicate daemons, unknown hosts, and client overflow', () {
    final registry = RelayRegistry(maxClientsPerDaemon: 1)
      ..attachDaemon(serverId: 'daemon-1', peer: MemoryRelayPeer());
    expect(
      () =>
          registry.attachDaemon(serverId: 'daemon-1', peer: MemoryRelayPeer()),
      throwsA(isA<RelayAdmissionException>()),
    );
    expect(
      () => registry.attachClient(serverId: 'missing', peer: MemoryRelayPeer()),
      throwsA(isA<RelayAdmissionException>()),
    );
    registry.attachClient(serverId: 'daemon-1', peer: MemoryRelayPeer());
    expect(
      () =>
          registry.attachClient(serverId: 'daemon-1', peer: MemoryRelayPeer()),
      throwsA(isA<RelayAdmissionException>()),
    );
  });

  test('enforces opaque frame and buffered-byte limits', () {
    final registry = RelayRegistry(
      maxFrameBytes: 4,
      maxBufferedBytesPerPeer: 4,
    );
    final daemon = MemoryRelayPeer();
    final client = MemoryRelayPeer();
    registry
      ..attachDaemon(serverId: 'daemon-1', peer: daemon)
      ..attachClient(serverId: 'daemon-1', peer: client);

    client.receive(Uint8List.fromList(<int>[1, 2, 3, 4, 5]));
    expect(client.closeCode, relayPolicyViolationCloseCode);
  });

  test('closes a slow peer before its outbound buffer can grow', () async {
    final registry = RelayRegistry(
      maxFrameBytes: 128,
      maxBufferedBytesPerPeer: 5,
    );
    final daemon = MemoryRelayPeer();
    final client = _BlockedRelayPeer();
    registry.attachDaemon(serverId: 'daemon-1', peer: daemon);
    final connectionId = registry.attachClient(
      serverId: 'daemon-1',
      peer: client,
    );

    for (var index = 0; index < 2; index += 1) {
      daemon.receive(
        RelayEnvelope(
          connectionId: connectionId,
          payload: Uint8List.fromList(<int>[1, 2, 3, 4]),
        ).encode(),
      );
    }
    await pumpEventQueue();

    expect(client.closeCode, relayPolicyViolationCloseCode);
    expect(client.sendCalls, 1);
    client.sendGate.complete();
  });

  test('validates daemon envelopes and disconnect lifecycle', () async {
    final registry = RelayRegistry(maxFrameBytes: 8);
    final daemon = MemoryRelayPeer();
    final client = MemoryRelayPeer();
    expect(
      () => registry.attachDaemon(serverId: '', peer: daemon),
      throwsA(
        isA<RelayAdmissionException>().having(
          (error) => error.toString(),
          'message',
          contains('must not be empty'),
        ),
      ),
    );
    registry
      ..attachDaemon(serverId: 'daemon-1', peer: daemon)
      ..attachClient(serverId: 'daemon-1', peer: client);

    daemon.receive(Uint8List.fromList(const <int>[0]));
    await pumpEventQueue();
    expect(daemon.closeCode, relayPolicyViolationCloseCode);

    daemon.receive(Uint8List.fromList(List<int>.filled(9, 1)));
    await pumpEventQueue();
    expect(daemon.closeReason, contains('frame exceeds'));
    expect(client.closeCode, 1012);

    await daemon.dispose();
    await client.dispose();
  });

  test('client completion frees a slot for a replacement', () async {
    final registry = RelayRegistry(maxClientsPerDaemon: 1);
    final daemon = MemoryRelayPeer();
    final first = MemoryRelayPeer();
    registry
      ..attachDaemon(serverId: 'daemon-1', peer: daemon)
      ..attachClient(serverId: 'daemon-1', peer: first);
    await first.dispose();
    await pumpEventQueue();
    expect(
      registry.attachClient(serverId: 'daemon-1', peer: MemoryRelayPeer()),
      isNotEmpty,
    );
  });
}

final class _BlockedRelayPeer implements RelayPeer {
  final StreamController<Uint8List> _messages =
      StreamController<Uint8List>.broadcast(sync: true);
  final Completer<void> sendGate = Completer<void>();
  int sendCalls = 0;
  int? closeCode;

  @override
  Stream<Uint8List> get messages => _messages.stream;

  @override
  Future<void> close(int code, String reason) async {
    closeCode = code;
  }

  @override
  Future<void> send(Uint8List bytes) {
    sendCalls += 1;
    return sendGate.future;
  }
}
