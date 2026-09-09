import 'package:daemon/src/features/mcp/infrastructure/mcp.dart';
import 'package:daemon/src/features/mcp/infrastructure/mcp_service.dart';
import 'package:daemon/src/features/plugins/runtime/host_primitives.dart';
import 'package:daemon/src/shared/ports/mcp_host_primitives.dart';
import 'package:daemon/src/shared/ports/request_cancellation.dart';

/// Worktree-scoped raw MCP transport used by the Lua host primitive registry.
final class SessionMcpHostPrimitiveGateway implements McpHostPrimitiveGateway {
  /// Creates a gateway that can see user servers and this project's servers.
  const new(this._runtime, this._workspaceRoot);

  final McpRuntime _runtime;
  final String _workspaceRoot;

  Future<void> _prepare() => _runtime.ensureProject(_workspaceRoot);

  @override
  Future<Map<String, Object?>> listResources(Map<String, Object?> arguments) =>
      _translate(() async {
        await _prepare();
        final server = _optionalString(arguments, 'server');
        final cursor = _optionalString(arguments, 'cursor');
        if (server == null && cursor != null) {
          throw const FormatException(
            'cursor is only valid together with a server.',
          );
        }
        final page = server == null
            ? McpListPage<McpServerResource>(
                items: _runtime.resources(workspaceRoot: _workspaceRoot),
              )
            : await _runtime.resourcePage(
                server: server,
                cursor: cursor,
                workspaceRoot: _workspaceRoot,
              );
        return <String, Object?>{
          'resources': <Map<String, Object?>>[
            for (final item in page.items)
              <String, Object?>{
                'server': item.server,
                ..._resource(item.descriptor),
              },
          ],
          if (page.nextCursor != null) 'nextCursor': page.nextCursor,
        };
      });

  @override
  Future<Map<String, Object?>> listResourceTemplates(
    Map<String, Object?> arguments,
  ) => _translate(() async {
    await _prepare();
    final server = _optionalString(arguments, 'server');
    final cursor = _optionalString(arguments, 'cursor');
    if (server == null && cursor != null) {
      throw const FormatException(
        'cursor is only valid together with a server.',
      );
    }
    final page = server == null
        ? McpListPage<McpServerResourceTemplate>(
            items: _runtime.resourceTemplates(workspaceRoot: _workspaceRoot),
          )
        : await _runtime.resourceTemplatePage(
            server: server,
            cursor: cursor,
            workspaceRoot: _workspaceRoot,
          );
    return <String, Object?>{
      'resourceTemplates': <Map<String, Object?>>[
        for (final item in page.items)
          <String, Object?>{
            'server': item.server,
            ..._resourceTemplate(item.descriptor),
          },
      ],
      if (page.nextCursor != null) 'nextCursor': page.nextCursor,
    };
  });

  @override
  Future<Map<String, Object?>> readResource(Map<String, Object?> arguments) =>
      _translate(() async {
        await _prepare();
        final result = await _runtime.readResource(
          server: _requiredString(arguments, 'server'),
          uri: _requiredString(arguments, 'uri'),
          workspaceRoot: _workspaceRoot,
        );
        return <String, Object?>{
          'contents': <Map<String, Object?>>[
            for (final content in result.contents) _resourceContents(content),
          ],
        };
      });

  @override
  Future<Map<String, Object?>> catalogTools(Map<String, Object?> arguments) =>
      _translate(() async {
        await _prepare();
        final server = _optionalString(arguments, 'server');
        return <String, Object?>{
          'tools': <Map<String, Object?>>[
            for (final item in _runtime.availableTools(
              workspaceRoot: _workspaceRoot,
            ))
              if (server == null || item.server == server)
                <String, Object?>{
                  'server': item.server,
                  ..._tool(item.descriptor),
                },
          ],
        };
      });

  @override
  Future<Map<String, Object?>> invokeTool(
    Map<String, Object?> arguments, {
    RequestCancellation? cancellation,
  }) => _translate(() async {
    await _prepare();
    final result = await _runtime.invokeTool(
      server: _requiredString(arguments, 'server'),
      tool: _requiredString(arguments, 'name'),
      arguments: _requiredObject(arguments, 'arguments'),
      workspaceRoot: _workspaceRoot,
      cancellation: cancellation,
    );
    return <String, Object?>{
      'content': <Map<String, Object?>>[
        for (final content in result.content) _content(content),
      ],
      if (result.structuredContent != null)
        'structuredContent': result.structuredContent,
      'isError': result.isError,
      if (result.meta.isNotEmpty) '_meta': result.meta,
    };
  });
}

Future<Map<String, Object?>> _translate(
  Future<Map<String, Object?>> Function() call,
) async {
  try {
    return await call();
  } on McpServerUnavailable catch (error) {
    throw HostPrimitiveException(
      HostPrimitiveError(
        code: 'mcp_server_unavailable',
        message: '$error',
        retryable: true,
      ),
    );
  } on McpRequestCancelled catch (error) {
    throw HostPrimitiveException(
      HostPrimitiveError(
        code: 'cancelled',
        message: error.reason,
        retryable: false,
      ),
    );
  } on McpToolUnavailable catch (error) {
    throw HostPrimitiveException(
      HostPrimitiveError(
        code: 'mcp_tool_unavailable',
        message: '$error',
        retryable: false,
      ),
    );
  } on McpServerException catch (error) {
    throw HostPrimitiveException(
      HostPrimitiveError(
        code: 'mcp_server_error',
        message: error.message,
        retryable: false,
        details: <String, Object?>{'serverCode': error.code},
      ),
    );
  } on McpProtocolException catch (error) {
    throw HostPrimitiveException(
      HostPrimitiveError(
        code: 'mcp_protocol_error',
        message: error.message,
        retryable: false,
      ),
    );
  } on McpTransportClosed catch (error) {
    throw HostPrimitiveException(
      HostPrimitiveError(
        code: 'mcp_transport_closed',
        message: '$error',
        retryable: true,
      ),
    );
  }
}

String? _optionalString(Map<String, Object?> arguments, String key) {
  final value = arguments[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('$key must be a string.');
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _requiredString(Map<String, Object?> arguments, String key) {
  final value = _optionalString(arguments, key);
  if (value == null) throw FormatException('$key must be a non-empty string.');
  return value;
}

Map<String, dynamic> _requiredObject(
  Map<String, Object?> arguments,
  String key,
) {
  final value = arguments[key];
  if (value is! Map) throw FormatException('$key must be an object.');
  return Map<String, dynamic>.from(value);
}

Map<String, Object?> _resource(McpResourceDescriptor value) =>
    <String, Object?>{
      'uri': value.uri,
      if (value.name != null) 'name': value.name,
      if (value.title != null) 'title': value.title,
      if (value.description != null) 'description': value.description,
      if (value.mimeType != null) 'mimeType': value.mimeType,
      if (value.sizeBytes != null) 'size': value.sizeBytes,
      if (value.annotations.isNotEmpty) 'annotations': value.annotations,
      if (value.meta.isNotEmpty) '_meta': value.meta,
    };

Map<String, Object?> _resourceTemplate(McpResourceTemplateDescriptor value) =>
    <String, Object?>{
      'uriTemplate': value.uriTemplate,
      if (value.name != null) 'name': value.name,
      if (value.title != null) 'title': value.title,
      if (value.description != null) 'description': value.description,
      if (value.mimeType != null) 'mimeType': value.mimeType,
      if (value.annotations.isNotEmpty) 'annotations': value.annotations,
      if (value.meta.isNotEmpty) '_meta': value.meta,
    };

Map<String, Object?> _tool(McpToolDescriptor value) => <String, Object?>{
  'name': value.name,
  if (value.title != null) 'title': value.title,
  if (value.description != null) 'description': value.description,
  if (value.inputSchema != null) 'inputSchema': value.inputSchema,
  if (value.outputSchema != null) 'outputSchema': value.outputSchema,
  if (_annotations(value.annotations).isNotEmpty)
    'annotations': _annotations(value.annotations),
};

Map<String, Object?> _annotations(
  McpToolAnnotations value,
) => <String, Object?>{
  if (value.readOnlyHint) 'readOnlyHint': true,
  if (value.destructiveHint != null) 'destructiveHint': value.destructiveHint,
  if (value.idempotentHint != null) 'idempotentHint': value.idempotentHint,
  if (value.openWorldHint != null) 'openWorldHint': value.openWorldHint,
};

Map<String, Object?> _resourceContents(McpResourceContents value) =>
    switch (value) {
      McpTextResourceContents() => <String, Object?>{
        'uri': value.uri,
        'mimeType': value.mimeType,
        'text': value.text,
        if (value.meta.isNotEmpty) '_meta': value.meta,
      },
      McpBlobResourceContents() => <String, Object?>{
        'uri': value.uri,
        'mimeType': value.mimeType,
        'blob': value.blob,
        if (value.meta.isNotEmpty) '_meta': value.meta,
      },
    };

Map<String, Object?> _content(McpContentBlock value) => switch (value) {
  McpTextContent() => <String, Object?>{
    'type': 'text',
    'text': value.text,
    ..._blockMetadata(value),
  },
  McpImageContent() => <String, Object?>{
    'type': 'image',
    'mimeType': value.mimeType,
    'data': value.data,
    ..._blockMetadata(value),
  },
  McpAudioContent() => <String, Object?>{
    'type': 'audio',
    'mimeType': value.mimeType,
    'data': value.data,
    ..._blockMetadata(value),
  },
  McpEmbeddedResource() => <String, Object?>{
    'type': 'resource',
    'uri': value.uri,
    if (value.mimeType != null) 'mimeType': value.mimeType,
    if (value.text != null) 'text': value.text,
    if (value.blob != null) 'blob': value.blob,
    ..._blockMetadata(value),
  },
  McpResourceLink() => <String, Object?>{
    'type': 'resource_link',
    'uri': value.uri,
    if (value.name != null) 'name': value.name,
    if (value.title != null) 'title': value.title,
    if (value.description != null) 'description': value.description,
    if (value.mimeType != null) 'mimeType': value.mimeType,
    if (value.size != null) 'size': value.size,
    ..._blockMetadata(value),
  },
  McpUnknownContent() => <String, Object?>{
    ...value.raw,
    ..._blockMetadata(value),
  },
};

Map<String, Object?> _blockMetadata(McpContentBlock value) => <String, Object?>{
  if (value.annotations.isNotEmpty) 'annotations': value.annotations,
  if (value.meta.isNotEmpty) '_meta': value.meta,
};
