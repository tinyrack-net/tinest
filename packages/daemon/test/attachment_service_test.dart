import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:daemon/src/features/attachments/infrastructure/attachment_service.dart';
import 'package:daemon/src/features/relay/infrastructure/relay_attachment_adapter.dart';
import 'package:daemon/src/shared/infrastructure/persistence/repositories.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  test(
    'relay adapter preserves streamed attachment metadata and bytes',
    tags: const <String>['feature_test__daemon_relay__unit'],
    () async {
      final root = await Directory.systemTemp.createTemp(
        'tinest-relay-attachment-',
      );
      addTearDown(() => root.delete(recursive: true));
      final service = AttachmentService(
        repository: _MemoryAttachmentRepository(),
        blobs: NativeAttachmentBlobStore(root.path),
        clock: const _Clock(),
        ids: _Ids(),
      );
      final adapter = RelayAttachmentAdapter(service);
      final bytes = utf8.encode('opaque relay payload');

      final uploaded = await adapter.upload(
        fileName: 'payload.txt',
        mimeType: 'text/plain',
        declaredByteSize: bytes.length,
        bytes: Stream<List<int>>.value(bytes),
      );
      expect(uploaded.fileName, 'payload.txt');
      expect(uploaded.mimeType, 'text/plain');
      expect(uploaded.byteSize, bytes.length);
      expect(uploaded.kind, AttachmentKind.file.name);
      expect(uploaded.sha256, sha256.convert(bytes).toString());
      expect(uploaded.createdAt, const _Clock().nowUtc());

      final (metadata, download) = await adapter.download(uploaded.id);
      expect(metadata.id, uploaded.id);
      expect(metadata.sha256, uploaded.sha256);
      expect(await download.expand((chunk) => chunk).toList(), bytes);
    },
  );

  test(
    'upload streams, validates image identity, hashes, downloads, and cleans',
    tags: const <String>['feature_test__conversation_attachments__unit'],
    () async {
      final root = await Directory.systemTemp.createTemp(
        'tinest-attachment-store-',
      );
      addTearDown(() => root.delete(recursive: true));
      final repository = _MemoryAttachmentRepository();
      final service = AttachmentService(
        repository: repository,
        blobs: NativeAttachmentBlobStore(root.path),
        clock: const _Clock(),
        ids: _Ids(),
      );
      final bytes = <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1, 2];
      final uploaded = await service.upload(
        fileName: 'fixture.png',
        mimeType: 'image/png',
        declaredByteSize: bytes.length,
        bytes: Stream<List<int>>.fromIterable(<List<int>>[
          bytes.sublist(0, 3),
          bytes.sublist(3),
        ]),
      );
      expect(uploaded.kind, AttachmentKind.image);
      expect(uploaded.sha256, sha256.convert(bytes).toString());
      final (metadata, download) = await service.download(uploaded.id);
      expect(metadata, uploaded);
      expect(await download.expand((chunk) => chunk).toList(), bytes);

      repository.orphans = <String>[uploaded.id];
      await service.cleanupOrphans();
      expect(File('${root.path}/${uploaded.id}.blob').existsSync(), isFalse);
    },
  );

  test(
    'upload rejects traversal, declared length mismatch, and image spoofing',
    tags: const <String>['feature_test__conversation_attachments__unit'],
    () async {
      final root = await Directory.systemTemp.createTemp(
        'tinest-attachment-invalid-',
      );
      addTearDown(() => root.delete(recursive: true));
      final service = AttachmentService(
        repository: _MemoryAttachmentRepository(),
        blobs: NativeAttachmentBlobStore(root.path),
        clock: const _Clock(),
        ids: _Ids(),
      );
      await expectLater(
        service.upload(
          fileName: '../secret.txt',
          mimeType: 'text/plain',
          declaredByteSize: 1,
          bytes: Stream<List<int>>.value(<int>[1]),
        ),
        throwsFormatException,
      );
      await expectLater(
        service.upload(
          fileName: 'short.txt',
          mimeType: 'text/plain',
          declaredByteSize: 2,
          bytes: Stream<List<int>>.value(<int>[1]),
        ),
        throwsFormatException,
      );
      await expectLater(
        service.upload(
          fileName: 'spoof.png',
          mimeType: 'image/png',
          declaredByteSize: 4,
          bytes: Stream<List<int>>.value(utf8.encode('nope')),
        ),
        throwsFormatException,
      );
      expect(root.listSync(), isEmpty);
    },
  );
}

final class _Clock implements Clock {
  const new();

  @override
  DateTime nowUtc() => DateTime.utc(2026, 8, 5);
}

final class _Ids implements IdGenerator {
  int next = 0;

  @override
  String generate() => 'attachment-${next += 1}';
}

final class _MemoryAttachmentRepository implements AttachmentRepository {
  final Map<String, AttachmentDto> values = <String, AttachmentDto>{};
  List<String> orphans = const <String>[];

  @override
  Future<void> insert(AttachmentDto attachment) async {
    values[attachment.id] = attachment;
  }

  @override
  Future<AttachmentDto?> getById(String id) async => values[id];

  @override
  Future<List<AttachmentDto>> getByIds(List<String> ids) async =>
      ids.map((id) => values[id]!).toList(growable: false);

  @override
  Future<bool> isLinkedToSession(String id, String sessionId) async =>
      values.containsKey(id);

  @override
  Future<void> bindAssistant(String turnId, String attachmentId) async {}

  @override
  Future<List<String>> deleteOrphansBefore(DateTime cutoff) async {
    return orphans..forEach(values.remove);
  }
}
