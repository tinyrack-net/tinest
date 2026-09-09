import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agent/agent.dart';
import 'package:crypto/crypto.dart';
import 'package:daemon/src/shared/infrastructure/persistence/repositories.dart';
import 'package:daemon/src/shared/ports/agent_protocol_mapping.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:path/path.dart' as p;
import 'package:protocol/protocol.dart';

/// Maximum payload size of one attachment.
const int maxAttachmentPayloadBytes = 50 * 1024 * 1024;

/// Maximum number of attachments accepted by one turn.
const int maxTurnAttachmentCount = 10;

/// Result of streaming bytes into a temporary attachment object.
final class StagedAttachment {
  /// Creates a staged payload description.
  const new({
    required this.id,
    required this.byteSize,
    required this.sha256,
    required this.header,
    required this.looksAnimatedGif,
  });

  /// Opaque storage key.
  final String id;

  /// Observed payload length.
  final int byteSize;

  /// Observed digest.
  final String sha256;

  /// Leading bytes retained for media validation.
  final Uint8List header;

  /// Whether a GIF declares the standard looping animation extension.
  final bool looksAnimatedGif;
}

/// Streaming payload storage port.
abstract interface class AttachmentBlobStore {
  /// Streams [source] into a temporary object while hashing it.
  Future<StagedAttachment> stage(
    String id,
    Stream<List<int>> source, {
    required int maxBytes,
  });

  /// Atomically makes a staged object readable.
  Future<void> commit(String id);

  /// Removes a staged object after validation failure.
  Future<void> abort(String id);

  /// Opens an immutable payload stream.
  Stream<List<int>> openRead(String id);

  /// Returns the daemon-local immutable payload path.
  String pathFor(String id);

  /// Removes an immutable payload.
  Future<void> delete(String id);
}

/// Native atomic attachment payload storage.
final class NativeAttachmentBlobStore implements AttachmentBlobStore {
  /// Creates storage rooted at [rootPath].
  new(this.rootPath);

  /// Directory containing opaque payload names.
  final String rootPath;

  String _temporaryPath(String id) => p.join(rootPath, '.$id.uploading');
  String _finalPath(String id) => p.join(rootPath, '$id.blob');

  @override
  Future<StagedAttachment> stage(
    String id,
    Stream<List<int>> source, {
    required int maxBytes,
  }) async {
    Directory(rootPath).createSync(recursive: true);
    final temporary = File(_temporaryPath(id));
    final output = temporary.openWrite(mode: FileMode.writeOnly);
    final header = BytesBuilder(copy: false);
    final animationScanner = _BytePatternScanner(ascii.encode('NETSCAPE2.0'));
    final digestOutput = _DigestSink();
    final digestSink = sha256.startChunkedConversion(digestOutput);
    var size = 0;
    try {
      await for (final chunk in source) {
        size += chunk.length;
        if (size > maxBytes) {
          throw const FormatException('Attachment exceeds the 50 MB limit.');
        }
        if (header.length < 32) {
          final remaining = 32 - header.length;
          header.add(
            chunk.length <= remaining ? chunk : chunk.sublist(0, remaining),
          );
        }
        digestSink.add(chunk);
        animationScanner.add(chunk);
        output.add(chunk);
      }
      digestSink.close();
      await output.flush();
      await output.close();
      final completedDigest = digestOutput.value;
      if (completedDigest == null) {
        throw StateError('Attachment digest did not complete.');
      }
      return StagedAttachment(
        id: id,
        byteSize: size,
        sha256: completedDigest.toString(),
        header: header.takeBytes(),
        looksAnimatedGif: animationScanner.matched,
      );
    } catch (_) {
      digestSink.close();
      await output.close();
      if (temporary.existsSync()) temporary.deleteSync();
      rethrow;
    }
  }

  @override
  Future<void> commit(String id) => Future<void>.sync(
    () => File(_temporaryPath(id)).renameSync(_finalPath(id)),
  );

  @override
  Future<void> abort(String id) => Future<void>.sync(() {
    final file = File(_temporaryPath(id));
    if (file.existsSync()) file.deleteSync();
  });

  @override
  Stream<List<int>> openRead(String id) => File(_finalPath(id)).openRead();

  @override
  String pathFor(String id) => _finalPath(id);

  @override
  Future<void> delete(String id) => Future<void>.sync(() {
    final file = File(_finalPath(id));
    if (file.existsSync()) file.deleteSync();
  });
}

final class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

final class _BytePatternScanner {
  new(this.pattern);

  final List<int> pattern;
  var _matchedBytes = 0;
  bool matched = false;

  void add(List<int> bytes) {
    if (matched) return;
    for (final byte in bytes) {
      if (byte == pattern[_matchedBytes]) {
        _matchedBytes += 1;
        if (_matchedBytes == pattern.length) {
          matched = true;
          return;
        }
      } else {
        _matchedBytes = byte == pattern.first ? 1 : 0;
      }
    }
  }
}

/// Validates, persists, resolves, and cleans daemon-owned attachments.
final class AttachmentService {
  /// Creates the attachment application service.
  factory({
    required AttachmentRepository repository,
    required AttachmentBlobStore blobs,
    required Clock clock,
    required IdGenerator ids,
  }) => AttachmentService._(repository, blobs, clock, ids);

  const new _(this._repository, this._blobs, this._clock, this._ids);

  final AttachmentRepository _repository;
  final AttachmentBlobStore _blobs;
  final Clock _clock;
  final IdGenerator _ids;

  /// Streams a client upload into immutable daemon storage.
  Future<AttachmentDto> upload({
    required String fileName,
    required String mimeType,
    required int declaredByteSize,
    required Stream<List<int>> bytes,
  }) async {
    _validateFileName(fileName);
    if (declaredByteSize < 0 || declaredByteSize > maxAttachmentPayloadBytes) {
      throw const FormatException('Invalid attachment content length.');
    }
    final id = _ids.generate();
    final staged = await _blobs.stage(
      id,
      bytes,
      maxBytes: maxAttachmentPayloadBytes,
    );
    try {
      if (staged.byteSize != declaredByteSize) {
        throw const FormatException(
          'Declared attachment size does not match the uploaded bytes.',
        );
      }
      final validated = _validatedMediaType(fileName, mimeType, staged.header);
      if (validated == 'image/gif' && staged.looksAnimatedGif) {
        throw const FormatException(
          'Animated GIF attachments are unsupported.',
        );
      }
      final attachment = AttachmentDto(
        id: id,
        fileName: fileName,
        mimeType: validated,
        byteSize: staged.byteSize,
        kind: _supportedImageTypes.contains(validated)
            ? AttachmentKind.image
            : AttachmentKind.file,
        sha256: staged.sha256,
        createdAt: _clock.nowUtc(),
      );
      await _blobs.commit(id);
      try {
        await _repository.insert(attachment);
      } catch (_) {
        await _blobs.delete(id);
        rethrow;
      }
      return attachment;
    } catch (_) {
      await _blobs.abort(id);
      rethrow;
    }
  }

  /// Copies a workspace-produced file into the immutable store.
  Future<ConversationAttachment> publishFile(String turnId, String path) async {
    final file = File(path);
    final size = await file.length();
    final attachment = await upload(
      fileName: p.basename(path),
      mimeType: _mimeFromExtension(path),
      declaredByteSize: size,
      bytes: file.openRead(),
    );
    await _repository.bindAssistant(turnId, attachment.id);
    return _conversationAttachment(attachment);
  }

  /// Returns ordered references and optionally hydrates their bytes.
  Future<List<ConversationAttachment>> resolveAll(
    List<String> ids, {
    required bool hydrate,
  }) async {
    if (ids.length > maxTurnAttachmentCount) {
      throw const FormatException('A turn accepts at most 10 attachments.');
    }
    final metadata = await _repository.getByIds(ids);
    return await Future.wait(
      metadata.map((item) async {
        if (!hydrate) return _conversationAttachment(item);
        final builder = BytesBuilder(copy: false);
        await _blobs.openRead(item.id).forEach(builder.add);
        return ConversationAttachment(
          id: item.id,
          fileName: item.fileName,
          mimeType: item.mimeType,
          byteSize: item.byteSize,
          path: _blobs.pathFor(item.id),
          bytes: builder.takeBytes(),
          kind: agentAttachmentKind(item.kind),
          sha256: item.sha256,
          createdAt: item.createdAt,
        );
      }),
    );
  }

  /// Opens one authenticated download.
  Future<(AttachmentDto, Stream<List<int>>)> download(String id) async {
    final attachment = await _repository.getById(id);
    if (attachment == null) throw AttachmentNotFoundException(id);
    return (attachment, _blobs.openRead(id));
  }

  /// Resolves an attachment only when it belongs to [sessionId].
  Future<ConversationAttachment> readForSession(
    String id,
    String sessionId,
  ) async {
    if (!await _repository.isLinkedToSession(id, sessionId)) {
      throw AttachmentNotFoundException(id);
    }
    final attachment = await _repository.getById(id);
    if (attachment == null) throw AttachmentNotFoundException(id);
    return _conversationAttachment(attachment);
  }

  /// Removes uploads that were never linked to a turn after 24 hours.
  Future<void> cleanupOrphans() async {
    final cutoff = _clock.nowUtc().subtract(const Duration(hours: 24));
    final ids = await _repository.deleteOrphansBefore(cutoff);
    await Future.wait(ids.map(_blobs.delete));
  }

  ConversationAttachment _conversationAttachment(AttachmentDto attachment) =>
      ConversationAttachment(
        id: attachment.id,
        fileName: attachment.fileName,
        mimeType: attachment.mimeType,
        byteSize: attachment.byteSize,
        path: _blobs.pathFor(attachment.id),
        kind: agentAttachmentKind(attachment.kind),
        sha256: attachment.sha256,
        createdAt: attachment.createdAt,
      );
}

/// Session-scoped adapter exposed to the `read_attachment` tool.
final class SessionAttachmentReader implements AttachmentReader {
  /// Creates a reader constrained to one session.
  const new(this._service, this._sessionId);

  final AttachmentService _service;
  final String _sessionId;

  @override
  Future<ConversationAttachment> read(String id) =>
      _service.readForSession(id, _sessionId);
}

/// Turn-bound adapter exposed to the `attach_file` agent tool.
final class TurnAttachmentPublisher implements AttachmentPublisher {
  /// Creates a publisher scoped to one turn identifier.
  const new(this._service, this._turnId);

  final AttachmentService _service;
  final String _turnId;

  @override
  Future<ConversationAttachment> publish(String path) =>
      _service.publishFile(_turnId, path);
}

/// Signals that an attachment identifier has no persisted metadata.
final class AttachmentNotFoundException implements Exception {
  /// Creates an attachment-not-found error.
  const new(this.id);

  /// Missing attachment identifier.
  final String id;
}

const Set<String> _supportedImageTypes = <String>{
  'image/png',
  'image/jpeg',
  'image/webp',
  'image/gif',
};

void _validateFileName(String fileName) {
  if (fileName.isEmpty ||
      fileName == '.' ||
      fileName == '..' ||
      p.basename(fileName) != fileName ||
      fileName.contains(r'\') ||
      fileName.runes.any((rune) => rune < 32 || rune == 127)) {
    throw const FormatException('Attachment file name must be a base name.');
  }
  if (utf8.encode(fileName).length > 255) {
    throw const FormatException('Attachment file name is too long.');
  }
}

String _validatedMediaType(
  String fileName,
  String declaredMimeType,
  Uint8List header,
) {
  final declared = declaredMimeType.split(';').first.trim().toLowerCase();
  final detected = _imageMime(header);
  final extensionMime = _imageMimeFromExtension(fileName);
  if (detected != null ||
      extensionMime != null ||
      _supportedImageTypes.contains(declared)) {
    if (detected == null ||
        extensionMime == null ||
        detected != extensionMime ||
        (_supportedImageTypes.contains(declared) && declared != detected)) {
      throw const FormatException(
        'Image MIME type, extension, and magic bytes do not agree.',
      );
    }
    return detected;
  }
  if (!RegExp(r'^[a-z0-9][a-z0-9!#$&^_.+-]*/[a-z0-9][a-z0-9!#$&^_.+-]*$')
      .hasMatch(declared)) {
    return 'application/octet-stream';
  }
  return declared;
}

String? _imageMime(Uint8List bytes) {
  bool begins(List<int> signature) =>
      bytes.length >= signature.length &&
      Iterable<int>.generate(signature.length)
          .every((index) => bytes[index] == signature[index]);
  if (begins(<int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
    return 'image/png';
  }
  if (begins(<int>[0xff, 0xd8, 0xff])) return 'image/jpeg';
  if (bytes.length >= 12 &&
      ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
      ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
    return 'image/webp';
  }
  if (bytes.length >= 6) {
    final gif = ascii.decode(bytes.sublist(0, 6), allowInvalid: true);
    if (gif == 'GIF87a' || gif == 'GIF89a') return 'image/gif';
  }
  return null;
}

String? _imageMimeFromExtension(String path) =>
    switch (p.extension(path).toLowerCase()) {
      '.png' => 'image/png',
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.webp' => 'image/webp',
      '.gif' => 'image/gif',
      _ => null,
    };

String _mimeFromExtension(String path) =>
    _imageMimeFromExtension(path) ??
    switch (p.extension(path).toLowerCase()) {
      '.txt' || '.md' || '.log' => 'text/plain',
      '.json' => 'application/json',
      '.pdf' => 'application/pdf',
      '.csv' => 'text/csv',
      _ => 'application/octet-stream',
    };
