import 'package:daemon/src/features/mcp/infrastructure/mcp.dart';
import 'package:test/test.dart';

void main() {
  group('tool annotations', () {
    test('a descriptor without annotations claims nothing', () {
      final tool = McpToolDescriptor.fromJson(<String, dynamic>{
        'name': 'lookup',
      });

      expect(tool.annotations.readOnlyHint, isFalse);
      expect(tool.annotations.destructiveHint, isNull);
      expect(tool.annotations.idempotentHint, isNull);
      expect(tool.annotations.openWorldHint, isNull);
    });

    test('every declared hint is decoded', () {
      final tool = McpToolDescriptor.fromJson(<String, dynamic>{
        'name': 'lookup',
        'annotations': <String, dynamic>{
          'readOnlyHint': true,
          'destructiveHint': false,
          'idempotentHint': true,
          'openWorldHint': false,
        },
      });

      expect(tool.annotations.readOnlyHint, isTrue);
      expect(tool.annotations.destructiveHint, isFalse);
      expect(tool.annotations.idempotentHint, isTrue);
      expect(tool.annotations.openWorldHint, isFalse);
    });

    test('a non-boolean hint is treated as unsaid', () {
      final tool = McpToolDescriptor.fromJson(<String, dynamic>{
        'name': 'lookup',
        'annotations': <String, dynamic>{
          'readOnlyHint': 'yes',
          'destructiveHint': 1,
        },
      });

      expect(tool.annotations.readOnlyHint, isFalse);
      expect(tool.annotations.destructiveHint, isNull);
    });
  });
  test('the negotiated protocol versions are ordered newest first', () {
    expect(supportedMcpProtocolVersions.first, preferredMcpProtocolVersion);
    expect(supportedMcpProtocolVersions, contains('2025-06-18'));
    expect(supportedMcpProtocolVersions, contains('2025-03-26'));
  });

  test('tool descriptors decode names, titles, and input schemas', () {
    final descriptor = McpToolDescriptor.fromJson(<String, dynamic>{
      'name': 'create_issue',
      'title': 'Create issue',
      'description': 'Opens a GitHub issue.',
      'inputSchema': <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'title': <String, dynamic>{'type': 'string'},
        },
        'required': <String>['title'],
      },
    });

    expect(descriptor.name, 'create_issue');
    expect(descriptor.title, 'Create issue');
    expect(descriptor.description, 'Opens a GitHub issue.');
    expect(descriptor.inputSchema!['type'], 'object');
  });

  test('tool descriptors tolerate a server that omits optional fields', () {
    final descriptor = McpToolDescriptor.fromJson(<String, dynamic>{
      'name': 'ping',
    });

    expect(descriptor.name, 'ping');
    expect(descriptor.title, isNull);
    expect(descriptor.description, isNull);
    expect(descriptor.inputSchema, isNull);
  });

  test('a tool descriptor without a usable name is rejected', () {
    expect(
      () => McpToolDescriptor.fromJson(<String, dynamic>{'title': 'No name'}),
      throwsA(isA<McpProtocolException>()),
    );
    expect(
      () => McpToolDescriptor.fromJson(<String, dynamic>{'name': ''}),
      throwsA(isA<McpProtocolException>()),
    );
  });

  test('call results decode every content block the spec defines', () {
    final result = McpCallToolResult.fromJson(<String, dynamic>{
      'content': <dynamic>[
        <String, dynamic>{'type': 'text', 'text': 'hello'},
        <String, dynamic>{
          'type': 'image',
          'mimeType': 'image/png',
          'data': 'AAAA',
        },
        <String, dynamic>{
          'type': 'audio',
          'mimeType': 'audio/wav',
          'data': 'AAAAAAAA',
        },
        <String, dynamic>{
          'type': 'resource',
          'resource': <String, dynamic>{
            'uri': 'file:///a.txt',
            'mimeType': 'text/plain',
            'text': 'body',
          },
        },
        <String, dynamic>{
          'type': 'resource',
          'resource': <String, dynamic>{'uri': 'file:///a.bin', 'blob': 'AAAA'},
        },
        <String, dynamic>{
          'type': 'resource_link',
          'uri': 'https://example.test/doc',
          'name': 'doc',
        },
        <String, dynamic>{'type': 'future_block'},
      ],
    });

    expect(result.isError, isFalse);
    expect(result.structuredContent, isNull);
    expect(result.content, hasLength(7));

    final text = result.content[0] as McpTextContent;
    expect(text.text, 'hello');

    final image = result.content[1] as McpImageContent;
    expect(image.mimeType, 'image/png');
    expect(image.data, 'AAAA');

    final audio = result.content[2] as McpAudioContent;
    expect(audio.mimeType, 'audio/wav');
    expect(audio.data, 'AAAAAAAA');

    final textResource = result.content[3] as McpEmbeddedResource;
    expect(textResource.uri, 'file:///a.txt');
    expect(textResource.mimeType, 'text/plain');
    expect(textResource.text, 'body');
    expect(textResource.blob, isNull);

    final blobResource = result.content[4] as McpEmbeddedResource;
    expect(blobResource.text, isNull);
    expect(blobResource.blob, 'AAAA');

    final link = result.content[5] as McpResourceLink;
    expect(link.uri, 'https://example.test/doc');
    expect(link.name, 'doc');

    final unknown = result.content[6] as McpUnknownContent;
    expect(unknown.type, 'future_block');
  });

  test('call results carry structured content and the error flag', () {
    final result = McpCallToolResult.fromJson(<String, dynamic>{
      'content': <dynamic>[
        <String, dynamic>{'type': 'text', 'text': 'failed'},
      ],
      'structuredContent': <String, dynamic>{'code': 42},
      'isError': true,
    });

    expect(result.isError, isTrue);
    expect(result.structuredContent, <String, dynamic>{'code': 42});
  });

  test('call results tolerate missing and malformed content', () {
    expect(McpCallToolResult.fromJson(<String, dynamic>{}).content, isEmpty);
    expect(
      McpCallToolResult.fromJson(<String, dynamic>{
        'content': <dynamic>['not-an-object', 42],
      }).content,
      isEmpty,
    );
    expect(
      McpCallToolResult.fromJson(<String, dynamic>{'content': 'not-a-list'})
          .content,
      isEmpty,
    );
    expect(
      McpCallToolResult.fromJson(<String, dynamic>{
        'structuredContent': 'not-an-object',
      }).structuredContent,
      isNull,
    );
  });

  test('base64 payloads are preserved verbatim for the caller', () {
    final result = McpCallToolResult.fromJson(<String, dynamic>{
      'content': <dynamic>[
        <String, dynamic>{'type': 'image', 'data': '!!not base64!!'},
        <String, dynamic>{'type': 'text'},
      ],
    });

    final image = result.content.single as McpImageContent;
    expect(image.mimeType, 'application/octet-stream');
    expect(image.data, '!!not base64!!');
  });

  test(
    'resource descriptors decode the fields a server publishes',
    tags: const <String>['feature_test__mcp_resource_access__unit'],
    () {
      final resource = McpResourceDescriptor.fromJson(<String, dynamic>{
        'uri': 'file:///repo/README.md',
        'name': 'README',
        'title': 'Project readme',
        'description': 'How to build the project.',
        'mimeType': 'text/markdown',
        'size': 4096,
      });
      expect(resource.uri, 'file:///repo/README.md');
      expect(resource.name, 'README');
      expect(resource.title, 'Project readme');
      expect(resource.mimeType, 'text/markdown');
      expect(resource.sizeBytes, 4096);

      // Only the URI is required; everything else is optional per spec.
      final bare = McpResourceDescriptor.fromJson(<String, dynamic>{
        'uri': 'db://schema',
      });
      expect(bare.name, isNull);
      expect(bare.sizeBytes, isNull);

      for (final invalid in <Map<String, dynamic>>[
        <String, dynamic>{},
        <String, dynamic>{'uri': ''},
        <String, dynamic>{'uri': 7},
      ]) {
        expect(
          () => McpResourceDescriptor.fromJson(invalid),
          throwsA(isA<McpProtocolException>()),
          reason: '$invalid',
        );
      }
    },
  );

  test(
    'resource template descriptors require a URI template',
    tags: const <String>['feature_test__mcp_resource_access__unit'],
    () {
      final template = McpResourceTemplateDescriptor.fromJson(<String, dynamic>{
        'uriTemplate': 'file:///repo/{path}',
        'name': 'Repository file',
        'mimeType': 'text/plain',
      });
      expect(template.uriTemplate, 'file:///repo/{path}');
      expect(template.name, 'Repository file');

      expect(
        () => McpResourceTemplateDescriptor.fromJson(const <String, dynamic>{
          'name': 'no template',
        }),
        throwsA(isA<McpProtocolException>()),
      );
    },
  );

  test(
    'read results decode text and blob contents and drop unusable entries',
    tags: const <String>['feature_test__mcp_resource_access__unit'],
    () {
      final result = McpReadResourceResult.fromJson(<String, dynamic>{
        'contents': <dynamic>[
          <String, dynamic>{
            'uri': 'file:///a.txt',
            'mimeType': 'text/plain',
            'text': 'hello',
          },
          <String, dynamic>{
            'uri': 'file:///b.png',
            'mimeType': 'image/png',
            'blob': 'AQID',
          },
          // A server that sends neither text nor blob contributes nothing.
          <String, dynamic>{'uri': 'file:///c.bin'},
          'not an object',
        ],
      });

      expect(result.contents, hasLength(2));
      final text = result.contents.first as McpTextResourceContents;
      expect(text.uri, 'file:///a.txt');
      expect(text.text, 'hello');
      final blob = result.contents.last as McpBlobResourceContents;
      expect(blob.mimeType, 'image/png');
      expect(blob.blob, 'AQID');

      expect(
        McpReadResourceResult.fromJson(const <String, dynamic>{}).contents,
        isEmpty,
      );
    },
  );

  test('protocol exceptions expose a stable diagnostic message', () {
    expect(
      const McpProtocolException('bad tool').toString(),
      contains('bad tool'),
    );
    expect(
      const McpUnsupportedProtocolVersion('1999-01-01').toString(),
      contains('1999-01-01'),
    );
    expect(
      const McpServerException(code: -32601, message: 'nope').toString(),
      allOf(contains('-32601'), contains('nope')),
    );
  });
}
