import 'dart:convert';
import 'dart:typed_data';

import 'package:relay_protocol/src/record.dart';

/// Maximum outstanding attachment payload granted to a sender.
const int relayAttachmentCreditWindowBytes = 1024 * 1024;

/// Maximum data bytes inside one encrypted attachment record.
const int maxRelayAttachmentChunkBytes = maxRelayRecordPayloadBytes;

/// Operation requested when opening an attachment stream.
enum RelayAttachmentOperation {
  /// Client streams a new attachment to the daemon.
  upload,

  /// Daemon streams an existing attachment to the client.
  download,
}

/// Validated metadata for an attachment stream open record.
final class RelayAttachmentOpen {
  new _({
    required this.operation,
    this.fileName,
    this.mimeType,
    this.byteSize,
    this.attachmentId,
  });

  /// Opens a client-to-daemon upload.
  factory upload({
    required String fileName,
    required String mimeType,
    required int byteSize,
  }) {
    if (fileName.isEmpty || mimeType.isEmpty || byteSize < 0) {
      throw const FormatException('Invalid relay attachment upload.');
    }
    return RelayAttachmentOpen._(
      operation: RelayAttachmentOperation.upload,
      fileName: fileName,
      mimeType: mimeType,
      byteSize: byteSize,
    );
  }

  /// Opens a daemon-to-client download.
  factory download({required String attachmentId}) {
    if (attachmentId.isEmpty) {
      throw const FormatException('Invalid relay attachment download.');
    }
    return RelayAttachmentOpen._(
      operation: RelayAttachmentOperation.download,
      attachmentId: attachmentId,
    );
  }

  /// Decodes strict operation-specific metadata.
  factory decode(List<int> bytes) {
    final value = jsonDecode(utf8.decode(bytes));
    if (value is! Map<String, dynamic>) {
      throw const FormatException(
        'Attachment open metadata must be an object.',
      );
    }
    return switch (value['operation']) {
      'upload' => RelayAttachmentOpen.upload(
        fileName: value['fileName']! as String,
        mimeType: value['mimeType']! as String,
        byteSize: value['byteSize']! as int,
      ),
      'download' => RelayAttachmentOpen.download(
        attachmentId: value['attachmentId']! as String,
      ),
      _ => throw const FormatException('Unknown relay attachment operation.'),
    };
  }

  /// Requested transfer direction.
  final RelayAttachmentOperation operation;

  /// Upload file name.
  final String? fileName;

  /// Upload media type.
  final String? mimeType;

  /// Declared upload byte size.
  final int? byteSize;

  /// Download attachment identifier.
  final String? attachmentId;

  /// Encodes metadata for an attachment open record.
  Uint8List encode() => Uint8List.fromList(
    utf8.encode(
      jsonEncode(<String, Object>{
        'operation': operation.name,
        'fileName': ?fileName,
        'mimeType': ?mimeType,
        'byteSize': ?byteSize,
        'attachmentId': ?attachmentId,
      }),
    ),
  );
}

/// Encodes a positive attachment credit grant.
Uint8List encodeRelayAttachmentCredit(int bytes) {
  if (bytes <= 0 || bytes > relayAttachmentCreditWindowBytes) {
    throw RangeError.range(bytes, 1, relayAttachmentCreditWindowBytes, 'bytes');
  }
  return (ByteData(4)..setUint32(0, bytes)).buffer.asUint8List();
}

/// Decodes a positive attachment credit grant.
int decodeRelayAttachmentCredit(List<int> payload) {
  if (payload.length != 4) {
    throw const FormatException('Attachment credit must contain four bytes.');
  }
  final credit = ByteData.sublistView(Uint8List.fromList(payload)).getUint32(0);
  if (credit == 0 || credit > relayAttachmentCreditWindowBytes) {
    throw const FormatException('Attachment credit is outside the window.');
  }
  return credit;
}
