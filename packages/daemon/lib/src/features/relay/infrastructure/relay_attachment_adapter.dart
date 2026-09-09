import 'package:daemon/src/features/attachments/infrastructure/attachment_service.dart';
import 'package:daemon/src/features/relay/application/relay_ports.dart';
import 'package:protocol/protocol.dart';

/// Exposes the attachment application service through the relay feature port.
final class RelayAttachmentAdapter implements RelayAttachmentHost {
  /// Creates an adapter over the shared attachment service.
  const new(this._service);

  final AttachmentService _service;

  @override
  Future<(RelayAttachment, Stream<List<int>>)> download(String id) async {
    final (metadata, bytes) = await _service.download(id);
    return (_relayAttachment(metadata), bytes);
  }

  @override
  Future<RelayAttachment> upload({
    required String fileName,
    required String mimeType,
    required int declaredByteSize,
    required Stream<List<int>> bytes,
  }) async => _relayAttachment(
    await _service.upload(
      fileName: fileName,
      mimeType: mimeType,
      declaredByteSize: declaredByteSize,
      bytes: bytes,
    ),
  );

  RelayAttachment _relayAttachment(AttachmentDto attachment) => RelayAttachment(
    id: attachment.id,
    fileName: attachment.fileName,
    mimeType: attachment.mimeType,
    byteSize: attachment.byteSize,
    kind: attachment.kind.name,
    sha256: attachment.sha256,
    createdAt: attachment.createdAt,
  );
}
