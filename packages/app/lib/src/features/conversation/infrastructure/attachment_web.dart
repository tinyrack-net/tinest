import 'dart:typed_data';

import 'package:app/src/features/conversation/application/attachment_ports.dart';
import 'package:dropwell/dropwell.dart';
import 'package:file_selector/file_selector.dart';

export 'package:app/src/features/conversation/application/attachment_ports.dart';

/// Composer input adapter for a browser.
///
/// A browser never reports a path, so every file arrives as bytes; that is the
/// only way this differs from the native adapter.
final class WebAttachmentInput implements AttachmentInputPort {
  /// Creates the web adapter.
  const new();

  @override
  bool get supportsDrop => DropwellPlatform.instance.supportsDrop;

  @override
  Future<List<PendingAttachment>> pickFiles() async {
    final files = await openFiles();
    return await Future.wait(files.map(_fromXFile));
  }

  @override
  Future<List<PendingAttachment>> pasteFiles() async =>
      _fromDropwell(await DropwellPlatform.instance.readClipboardFiles());

  @override
  Future<List<PendingAttachment>> droppedFiles(
    List<DropwellFile> files,
  ) async => _fromDropwell(files);

  List<PendingAttachment> _fromDropwell(List<DropwellFile> files) => files
      .map(
        (file) => _validated(
          PendingAttachment.fromBytes(
            fileName: file.fileName,
            mimeType: mimeFromAttachmentName(
              file.fileName,
              mimeHint: file.mimeType,
            ),
            bytes: file.bytes!,
          ),
        ),
      )
      .toList(growable: false);

  Future<PendingAttachment> _fromXFile(XFile file) async {
    // A browser has already buffered the selection, so the length is known
    // without touching a filesystem.
    final bytes = await file.readAsBytes();
    return _validated(
      PendingAttachment.fromBytes(
        fileName: file.name,
        mimeType: file.mimeType ?? mimeFromAttachmentName(file.name),
        bytes: bytes,
      ),
    );
  }

  PendingAttachment _validated(PendingAttachment attachment) {
    if (attachment.byteSize > maxPendingAttachmentBytes) {
      throw const AttachmentFailure(AttachmentFailureReason.tooLarge);
    }
    return attachment;
  }
}

/// Download adapter for a browser.
final class WebAttachmentExport implements AttachmentExportPort {
  /// Creates the web export adapter.
  const new();

  @override
  Future<void> export({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    // `saveTo` is a no-op on the web; `getSaveLocation` returning a name is
    // what triggers the browser download.
    final file = XFile.fromData(bytes, mimeType: mimeType, name: fileName);
    await file.saveTo(fileName);
  }
}
