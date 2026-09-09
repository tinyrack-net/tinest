/// Transport-neutral attachment metadata exposed to relay infrastructure.
final class RelayAttachment {
  /// Creates immutable attachment metadata.
  const new({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.byteSize,
    required this.kind,
    required this.sha256,
    required this.createdAt,
  });

  /// Immutable attachment identifier.
  final String id;

  /// Original display filename.
  final String fileName;

  /// Validated media type.
  final String mimeType;

  /// Exact byte length.
  final int byteSize;

  /// Protocol attachment kind name.
  final String kind;

  /// Hexadecimal SHA-256 digest.
  final String sha256;

  /// UTC creation instant.
  final DateTime createdAt;
}

/// Attachment application boundary used by encrypted relay sessions.
abstract interface class RelayAttachmentHost {
  /// Streams an upload into daemon-owned immutable storage.
  Future<RelayAttachment> upload({
    required String fileName,
    required String mimeType,
    required int declaredByteSize,
    required Stream<List<int>> bytes,
  });

  /// Opens an immutable download and its authenticated metadata.
  Future<(RelayAttachment, Stream<List<int>>)> download(String id);
}
