@Tags(<String>['feature_test__tool_harness_parity__unit'])
library;

import 'dart:io' show FileSystemException;

import 'package:agent/agent.dart';
import 'package:file/memory.dart';
import 'package:platform/testing.dart';
import 'package:test/test.dart';

void main() {
  test(
    'workspace guard follows the injected filesystem and blocks escapes',
    () {
      final fileSystem = MemoryFileSystem.test()
        ..directory('/workspace/nested').createSync(recursive: true)
        ..file('/workspace/existing.txt').writeAsStringSync('value');
      final guard = WorkspacePathGuard(
        '/workspace',
        fileSystem: fileSystem,
        platform: TestPlatform.native(
          operatingSystem: 'linux',
          environment: const <String, String>{},
        ),
      );

      expect(guard.resolveExisting('existing.txt'), '/workspace/existing.txt');
      expect(
        guard.resolveWritable('nested/new.txt'),
        '/workspace/nested/new.txt',
      );
      expect(
        guard.resolveWritable('created/deep/new.txt'),
        '/workspace/created/deep/new.txt',
      );
      expect(
        () => guard.resolveWritable('../escape.txt'),
        throwsA(isA<FileSystemException>()),
      );
    },
  );

  test('skill guard accepts only existing relative files beneath its root', () {
    final fileSystem = MemoryFileSystem.test()
      ..directory('/skill/scripts').createSync(recursive: true)
      ..file('/skill/scripts/run.lua').writeAsStringSync('return true')
      ..file('/outside.lua').writeAsStringSync('return false');
    final guard = SkillPathGuard(
      '/skill',
      fileSystem: fileSystem,
      platform: TestPlatform.native(
        operatingSystem: 'linux',
        environment: const <String, String>{},
      ),
    );

    expect(guard.resolveExisting('scripts/run.lua'), '/skill/scripts/run.lua');
    expect(
      () => guard.resolveExisting('../outside.lua'),
      throwsA(isA<FileSystemException>()),
    );
    expect(
      () => guard.resolveExisting('/skill/scripts/run.lua'),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('neutral execution and Lua DTOs preserve host-owned values', () {
    const chunk = ExecSessionChunk(
      output: 'ready',
      isRunning: true,
      wallTime: Duration(milliseconds: 125),
    );
    const nested = LuaNestedToolDefinition(
      name: 'read_file',
      description: 'Read text.',
      kind: 'function',
      exposure: 'advertised',
      inputSchema: <String, dynamic>{'type': 'object'},
    );
    const execute = LuaExecuteRequest(
      source: 'return true',
      yieldTime: Duration(seconds: 1),
      maxOutputTokens: 512,
      tools: <LuaNestedToolDefinition>[nested],
    );
    const cell = LuaCellChunk(
      cellId: 'cell-1',
      output: 'done',
      notifications: <Object?>['notice'],
    );

    expect(chunk.output, 'ready');
    expect(chunk.isRunning, isTrue);
    expect(chunk.wallTime, const Duration(milliseconds: 125));
    expect(execute.tools.single, same(nested));
    expect(execute.maxOutputTokens, 512);
    expect(cell.cellId, 'cell-1');
    expect(cell.notifications, <Object?>['notice']);
  });

  test('skill catalog values remain transport-neutral', () {
    const content = SkillContent(
      name: 'review',
      description: 'Review code.',
      instructions: 'Inspect the diff.',
      resources: <SkillResourceRef>[
        SkillResourceRef(path: 'checklist.md', sizeBytes: 42),
      ],
    );

    expect(
      const SkillSummary(name: 'review', description: 'Review code.').name,
      content.name,
    );
    expect(content.resources.single.path, 'checklist.md');
    expect(
      const SkillLookupException('missing').toString(),
      contains('missing'),
    );
  });
}
