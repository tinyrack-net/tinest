import 'dart:convert';

import 'package:relay_protocol/relay_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('RelayPairingOffer', () {
    test('round-trips through a fragment without leaking into the query', () {
      final offer = RelayPairingOffer(
        serverId: 'daemon-1',
        relayUri: Uri.parse('wss://relay.tinest.tinyrack.net/v1/ws'),
        daemonPublicKey: List<int>.generate(32, (index) => index),
        offerId: 'offer-1',
        secret: List<int>.generate(32, (index) => 255 - index),
        expiresAt: DateTime.utc(2026, 8, 8, 12, 10),
      );

      final url = offer.toUrl(Uri.parse('https://tinest.tinyrack.net/pair'));
      expect(url.query, isEmpty);
      expect(url.fragment, startsWith('offer='));
      expect(RelayPairingOffer.parseUrl(url), offer);
    });

    test('rejects malformed key and secret lengths', () {
      expect(
        () => RelayPairingOffer.fromJson(<String, Object?>{
          'v': 1,
          'serverId': 'daemon-1',
          'relayUri': 'wss://relay.tinest.tinyrack.net/v1/ws',
          'daemonPublicKey': base64Url.encode(const <int>[1]),
          'offerId': 'offer-1',
          'secret': base64Url.encode(const <int>[2]),
          'expiresAt': '2026-08-08T12:10:00.000Z',
        }),
        throwsFormatException,
      );
    });
  });

  group('RelayCipherState', () {
    test(
      'encrypts ordered records and rejects replay and sequence gaps',
      () async {
        final sender = await RelayCipherState.create(
          sharedSecret: List<int>.filled(32, 7),
          transcript: utf8.encode('daemon-1:session-1'),
          direction: RelayDirection.clientToDaemon,
        );
        final receiver = await RelayCipherState.create(
          sharedSecret: List<int>.filled(32, 7),
          transcript: utf8.encode('daemon-1:session-1'),
          direction: RelayDirection.clientToDaemon,
        );

        final first = await sender.encrypt(utf8.encode('first'));
        expect(
          base64UrlEncode(first),
          'AAAAAAAAAAC5wBJUh84j4qXwMQksRqmBBlAUxFQ=',
        );
        final second = await sender.encrypt(utf8.encode('second'));
        expect(utf8.decode(await receiver.decrypt(first)), 'first');
        expect(utf8.decode(await receiver.decrypt(second)), 'second');
        await expectLater(
          receiver.decrypt(first),
          throwsA(isA<RelaySecurityException>()),
        );

        final fresh = await RelayCipherState.create(
          sharedSecret: List<int>.filled(32, 7),
          transcript: utf8.encode('daemon-1:session-1'),
          direction: RelayDirection.clientToDaemon,
        );
        await expectLater(
          fresh.decrypt(second),
          throwsA(isA<RelaySecurityException>()),
        );
      },
    );

    test('authenticates direction and ciphertext', () async {
      final sender = await RelayCipherState.create(
        sharedSecret: List<int>.filled(32, 9),
        transcript: utf8.encode('transcript'),
        direction: RelayDirection.clientToDaemon,
      );
      final wrongDirection = await RelayCipherState.create(
        sharedSecret: List<int>.filled(32, 9),
        transcript: utf8.encode('transcript'),
        direction: RelayDirection.daemonToClient,
      );
      final encrypted = await sender.encrypt(utf8.encode('secret payload'));
      await expectLater(
        wrongDirection.decrypt(encrypted),
        throwsA(isA<RelaySecurityException>()),
      );

      final tampered = List<int>.of(encrypted)..[encrypted.length - 1] ^= 1;
      final receiver = await RelayCipherState.create(
        sharedSecret: List<int>.filled(32, 9),
        transcript: utf8.encode('transcript'),
        direction: RelayDirection.clientToDaemon,
      );
      await expectLater(
        receiver.decrypt(tampered),
        throwsA(isA<RelaySecurityException>()),
      );
    });
  });

  test(
    'mutual handshake authenticates identities and derives one secret',
    () async {
      final clientIdentity = await RelayIdentity.fromSeed(
        List<int>.filled(32, 1),
      );
      final daemonIdentity = await RelayIdentity.fromSeed(
        List<int>.filled(32, 2),
      );
      final client = await RelayHandshakeInitiator.start(
        serverId: 'daemon-1',
        sessionId: 'session-1',
        deviceId: 'phone',
        identity: clientIdentity,
        ephemeralSeed: List<int>.filled(32, 3),
      );
      final daemon = await RelayHandshakeResponder.respond(
        hello: client.hello,
        expectedServerId: 'daemon-1',
        approvedDevicePublicKey: clientIdentity.publicKey,
        identity: daemonIdentity,
        ephemeralSeed: List<int>.filled(32, 4),
      );
      final clientResult = await client.complete(
        daemon.hello,
        expectedDaemonPublicKey: daemonIdentity.publicKey,
      );
      expect(clientResult.sharedSecret, daemon.result.sharedSecret);
      expect(clientResult.transcript, daemon.result.transcript);

      await expectLater(
        RelayHandshakeResponder.respond(
          hello: client.hello,
          expectedServerId: 'daemon-1',
          approvedDevicePublicKey: List<int>.filled(32, 9),
          identity: daemonIdentity,
          ephemeralSeed: List<int>.filled(32, 4),
        ),
        throwsA(isA<RelaySecurityException>()),
      );
    },
  );

  test('relay records enforce the 64 KiB plaintext contract', () {
    expect(
      () => RelayRecord(
        type: RelayRecordType.rpc,
        streamId: 0,
        payload: List<int>.filled(maxRelayRecordPayloadBytes + 1, 0),
      ),
      throwsRangeError,
    );
  });

  test('large logical RPC messages fragment and reassemble in order', () {
    final message = 'x' * (maxRelayRecordPayloadBytes * 2);
    final fragments = fragmentRelayRpcMessage(message);
    expect(fragments, hasLength(greaterThanOrEqualTo(3)));
    expect(
      fragments.every(
        (record) => record.payload.length <= maxRelayRecordPayloadBytes,
      ),
      isTrue,
    );
    final assembler = RelayRpcMessageAssembler();
    final outputs = fragments.map(assembler.add).whereType<String>().toList();
    expect(outputs, <String>[message]);
  });

  test(
    'pairing registration hides device metadata with the offer secret',
    () async {
      final offer = RelayPairingOffer(
        serverId: 'daemon-1',
        relayUri: Uri.parse('wss://relay.example/v1/ws'),
        daemonPublicKey: List<int>.filled(32, 1),
        offerId: 'offer-1',
        secret: List<int>.filled(32, 2),
        expiresAt: DateTime.utc(2026, 8, 8, 12, 10),
      );
      final request = await RelayPairingRegistrationRequest.create(
        offer: offer,
        payload: RelayPairingRegistrationPayload(
          deviceId: 'phone',
          deviceName: 'Alice phone',
          devicePublicKey: List<int>.filled(32, 3),
        ),
      );
      final wire = request.encode();
      expect(utf8.decode(wire, allowMalformed: true), isNot(contains('Alice')));
      final decoded = RelayPairingRegistrationRequest.decode(wire);
      final payload = await decoded.decrypt(
        serverId: offer.serverId,
        offerSecret: offer.secret,
      );
      expect(payload.deviceName, 'Alice phone');
      final accepted = await encryptRelayPairingAccepted(
        serverId: offer.serverId,
        offerId: offer.offerId,
        offerSecret: offer.secret,
        deviceId: payload.deviceId,
      );
      expect(
        await decryptRelayPairingAccepted(offer: offer, encrypted: accepted),
        'phone',
      );
    },
  );

  test('attachment controls enforce typed metadata and credit', () {
    final upload = RelayAttachmentOpen.upload(
      fileName: 'notes.txt',
      mimeType: 'text/plain',
      byteSize: 50 * 1024 * 1024,
    );
    final decodedUpload = RelayAttachmentOpen.decode(upload.encode());
    expect(decodedUpload.fileName, 'notes.txt');
    expect(decodedUpload.byteSize, 50 * 1024 * 1024);

    final download = RelayAttachmentOpen.download(attachmentId: 'attachment-1');
    expect(
      RelayAttachmentOpen.decode(download.encode()).attachmentId,
      'attachment-1',
    );
    expect(
      decodeRelayAttachmentCredit(
        encodeRelayAttachmentCredit(relayAttachmentCreditWindowBytes),
      ),
      relayAttachmentCreditWindowBytes,
    );
    expect(() => encodeRelayAttachmentCredit(0), throwsRangeError);
  });

  test('binary envelopes, frames, and records reject malformed input', () {
    final envelope = RelayEnvelope(
      connectionId: 'connection',
      payload: const <int>[1, 2],
    );
    final decodedEnvelope = RelayEnvelope.decode(envelope.encode());
    expect(decodedEnvelope.connectionId, 'connection');
    expect(decodedEnvelope.payload, <int>[1, 2]);
    expect(
      () => RelayEnvelope(connectionId: '', payload: const <int>[]),
      throwsFormatException,
    );
    expect(() => RelayEnvelope.decode(const <int>[0]), throwsFormatException);
    expect(
      () => RelayEnvelope.decode(const <int>[0, 0, 1]),
      throwsFormatException,
    );

    final wire = RelayWireFrame(
      type: RelayWireFrameType.encryptedRecord,
      payload: const <int>[3],
    );
    expect(RelayWireFrame.decode(wire.encode()).payload, <int>[3]);
    expect(() => RelayWireFrame.decode(const <int>[]), throwsFormatException);
    expect(() => RelayWireFrame.decode(const <int>[99]), throwsFormatException);

    final record = RelayRecord(
      type: RelayRecordType.close,
      streamId: 4,
      payload: const <int>[7],
    );
    final decodedRecord = RelayRecord.decode(record.encode());
    expect(decodedRecord.streamId, 4);
    expect(decodedRecord.payload, <int>[7]);
    expect(
      () => RelayRecord(
        type: RelayRecordType.rpc,
        streamId: -1,
        payload: const <int>[],
      ),
      throwsRangeError,
    );
    expect(() => RelayRecord.decode(const <int>[1]), throwsFormatException);
    final badHeader = List<int>.of(record.encode())..[0] = 99;
    expect(() => RelayRecord.decode(badHeader), throwsFormatException);

    final assembler = RelayRpcMessageAssembler();
    expect(
      () => assembler.add(
        RelayRecord(
          type: RelayRecordType.rpc,
          streamId: 1,
          payload: const <int>[1],
        ),
      ),
      throwsFormatException,
    );
    expect(fragmentRelayRpcMessage(''), hasLength(1));
  });

  test('offers, attachment metadata, and credits validate every boundary', () {
    expect(
      () => RelayPairingOffer.parseUrl(Uri.parse('https://example.test/pair')),
      throwsFormatException,
    );
    expect(
      () => RelayPairingOffer.fromJson(const <String, Object?>{'v': 2}),
      throwsFormatException,
    );
    expect(
      () => RelayPairingOffer(
        serverId: '',
        relayUri: Uri.parse('https://relay.example'),
        daemonPublicKey: List<int>.filled(32, 1),
        offerId: '',
        secret: List<int>.filled(32, 2),
        expiresAt: DateTime.utc(2026),
      ),
      throwsFormatException,
    );
    expect(
      () => RelayAttachmentOpen.upload(
        fileName: '',
        mimeType: 'text/plain',
        byteSize: 1,
      ),
      throwsFormatException,
    );
    expect(
      () => RelayAttachmentOpen.download(attachmentId: ''),
      throwsFormatException,
    );
    expect(
      () => RelayAttachmentOpen.decode(utf8.encode('[]')),
      throwsFormatException,
    );
    expect(
      () => RelayAttachmentOpen.decode(
        utf8.encode(jsonEncode(<String, String>{'operation': 'unknown'})),
      ),
      throwsFormatException,
    );
    expect(
      () => decodeRelayAttachmentCredit(const <int>[1]),
      throwsFormatException,
    );
    expect(
      () => decodeRelayAttachmentCredit(const <int>[0, 0, 0, 0]),
      throwsFormatException,
    );
  });

  test('handshake validates key material, identity, and signatures', () async {
    await expectLater(
      RelayIdentity.fromSeed(const <int>[1]),
      throwsA(isA<RelaySecurityException>()),
    );
    expect(
      () => RelayClientHello(
        serverId: 'daemon',
        sessionId: 'session',
        deviceId: 'device',
        identityPublicKey: const <int>[1],
        ephemeralPublicKey: List<int>.filled(32, 2),
        signature: List<int>.filled(64, 3),
      ),
      throwsFormatException,
    );
    final clientIdentity = await RelayIdentity.generate();
    final daemonIdentity = await RelayIdentity.generate();
    final initiator = await RelayHandshakeInitiator.start(
      serverId: 'daemon',
      sessionId: 'session',
      deviceId: 'device',
      identity: clientIdentity,
    );
    final responder = await RelayHandshakeResponder.respond(
      hello: initiator.hello,
      expectedServerId: 'daemon',
      approvedDevicePublicKey: clientIdentity.publicKey,
      identity: daemonIdentity,
    );
    await expectLater(
      initiator.complete(
        responder.hello,
        expectedDaemonPublicKey: List<int>.filled(32, 9),
      ),
      throwsA(isA<RelaySecurityException>()),
    );
    final badHello = RelayDaemonHello(
      identityPublicKey: daemonIdentity.publicKey,
      ephemeralPublicKey: responder.hello.ephemeralPublicKey,
      signature: List<int>.filled(64, 0),
    );
    await expectLater(
      initiator.complete(
        badHello,
        expectedDaemonPublicKey: daemonIdentity.publicKey,
      ),
      throwsA(isA<RelaySecurityException>()),
    );
  });
}
