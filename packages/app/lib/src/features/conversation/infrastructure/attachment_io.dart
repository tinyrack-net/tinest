import 'dart:io';
import 'dart:typed_data';

import 'package:app/src/features/conversation/application/attachment_ports.dart';
import 'package:dropwell/dropwell.dart';
import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart';

export 'package:app/src/features/conversation/application/attachment_ports.dart';

/// Production native attachment input adapter.
final class NativeAttachmentInput implements AttachmentInputPort {
  /// Creates the native adapter.
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

  List<PendingAttachment> _fromDropwell(List<DropwellFile> files) =>
      files.map(_fromDropwellFile).toList(growable: false);

  PendingAttachment _fromDropwellFile(DropwellFile file) {
    final mimeType = mimeFromAttachmentName(
      file.fileName,
      mimeHint: file.mimeType,
    );
    final path = file.path;
    if (path == null) {
      return _validated(
        PendingAttachment.fromBytes(
          fileName: file.fileName,
          mimeType: mimeType,
          bytes: file.bytes!,
        ),
      );
    }
    // A path is streamed rather than buffered: an attachment can be 50 MB, and
    // reading it whole only to hand it to an upload that reads it again costs
    // that much resident memory for no benefit.
    final handle = File(path);
    return _validated(
      PendingAttachment(
        fileName: file.fileName,
        mimeType: mimeType,
        byteSize: handle.lengthSync(),
        openRead: handle.openRead,
      ),
    );
  }

  Future<PendingAttachment> _fromXFile(XFile file) async {
    final length = await file.length();
    return _validated(
      PendingAttachment(
        fileName: file.name,
        mimeType: file.mimeType ?? mimeFromAttachmentName(file.name),
        byteSize: length,
        openRead: file.openRead,
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

/// Production save/share adapter.
final class NativeAttachmentExport implements AttachmentExportPort {
  /// Creates the native export adapter.
  const new();

  @override
  Future<void> export({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final file = XFile.fromData(bytes, mimeType: mimeType, name: fileName);
    if (Platform.isAndroid || Platform.isIOS) {
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[file],
          fileNameOverrides: <String>[fileName],
        ),
      );
      return;
    }
    final location = await getSaveLocation(suggestedName: fileName);
    if (location != null) await file.saveTo(location.path);
  }
}
