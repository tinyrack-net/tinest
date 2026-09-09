import 'dart:convert';

import 'package:daemon/src/features/attachments/infrastructure/attachment_service.dart';
import 'package:daemon/src/transport/http/attachment_binding.dart';
import 'package:shelf/shelf.dart';

/// Owns the attachment feature's versioned HTTP transport.
final class AttachmentHttpTransport implements AttachmentHttpBinding {
  /// Creates the transport over the feature application service.
  const new(this._attachments);

  final AttachmentService _attachments;

  /// Whether [request] targets the v5 attachment route.
  @override
  bool matches(Request request) =>
      request.url.path == 'v5/attachments' ||
      (request.url.pathSegments.length >= 2 &&
          request.url.pathSegments[0] == 'v5' &&
          request.url.pathSegments[1] == 'attachments');

  /// Handles an authenticated attachment request.
  @override
  Future<Response> call(Request request, Map<String, String> cors) async {
    try {
      if (request.method == 'POST' && request.url.path == 'v5/attachments') {
        final encodedName = request.headers['x-file-name'];
        final contentLength = int.tryParse(
          request.headers['content-length'] ?? '',
        );
        if (encodedName == null || contentLength == null) {
          return Response.badRequest(
            body: 'x-file-name and content-length are required.',
          );
        }
        final attachment = await _attachments.upload(
          fileName: Uri.decodeComponent(encodedName),
          mimeType:
              request.headers['content-type'] ?? 'application/octet-stream',
          declaredByteSize: contentLength,
          bytes: request.read(),
        );
        return Response.ok(
          jsonEncode(attachment.toJson()),
          headers: <String, String>{
            'content-type': 'application/json',
            'x-content-type-options': 'nosniff',
            ...cors,
          },
        );
      }
      if (request.method == 'GET' && request.url.pathSegments.length == 3) {
        final id = request.url.pathSegments[2];
        final (attachment, bytes) = await _attachments.download(id);
        return Response.ok(
          bytes,
          headers: <String, String>{
            'content-type': attachment.mimeType,
            'content-length': attachment.byteSize.toString(),
            'content-disposition':
                "attachment; filename*=UTF-8''"
                '${Uri.encodeComponent(attachment.fileName)}',
            'x-content-type-options': 'nosniff',
            ...cors,
          },
        );
      }
      return Response.notFound('Not found');
    } on FormatException catch (error) {
      return Response.badRequest(body: error.message, headers: cors);
    } on AttachmentNotFoundException {
      return Response.notFound('Attachment not found.', headers: cors);
    }
  }
}
