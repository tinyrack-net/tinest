@Tags(<String>[
  'feature_test__plugin_runtime__unit',
  'feature_test__plugin_permissions__unit',
])
library;

import 'dart:async';

import 'package:agent/agent.dart';
import 'package:daemon/src/features/plugins/runtime/built_in_host_primitives.dart';
import 'package:daemon/src/features/plugins/runtime/host_primitives.dart';
import 'package:daemon/src/features/sessions/infrastructure/multi_agent.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:daemon/src/shared/ports/mcp_host_primitives.dart';
import 'package:daemon/src/shared/ports/request_cancellation.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:platform/testing.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  late MemoryFileSystem fileSystem;
  late HostPrimitiveRegistryFactory factory;

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    fileSystem.directory('/workspace').createSync(recursive: true);
    fileSystem.file('/workspace/a.txt').writeAsStringSync('old');
    fileSystem.file('/workspace/b.txt').writeAsStringSync('other');
    factory = _MemoryHostPrimitiveRegistryFactory(fileSystem);
  });

  test('workspace transaction applies validated writes atomically', () async {
    final registry = _registry(factory);
    const arguments = <String, Object?>{
      'operations': <Map<String, Object?>>[
        <String, Object?>{'kind': 'write', 'path': 'a.txt', 'content': 'new'},
        <String, Object?>{
          'kind': 'write',
          'path': 'created.txt',
          'content': 'created',
        },
      ],
    };
    expect(
      registry.approvalPreview('host.workspace.transaction', arguments),
      'write a.txt\nwrite created.txt',
    );
    final result = await registry.invoke(
      'host.workspace.transaction',
      arguments,
      _context(const <String>{'workspace.patch'}),
    );

    expect(result.ok, isTrue);
    expect(fileSystem.file('/workspace/a.txt').readAsStringSync(), 'new');
    expect(
      fileSystem.file('/workspace/created.txt').readAsStringSync(),
      'created',
    );
  });

  test(
    'workspace transaction CAS failure leaves every file unchanged',
    () async {
      final registry = _registry(factory);
      final result = await registry.invoke(
        'host.workspace.transaction',
        <String, Object?>{
          'operations': <Map<String, Object?>>[
            <String, Object?>{
              'kind': 'write',
              'path': 'a.txt',
              'content': 'must-not-apply',
            },
            <String, Object?>{
              'kind': 'delete',
              'path': 'b.txt',
              'expected_sha256': 'not-the-current-digest',
            },
          ],
        },
        _context(const <String>{'workspace.patch'}),
      );

      expect(result.ok, isFalse);
      expect(result.error?.code, 'revision_conflict');
      expect(fileSystem.file('/workspace/a.txt').readAsStringSync(), 'old');
      expect(fileSystem.file('/workspace/b.txt').readAsStringSync(), 'other');
    },
  );

  test('workspace primitives reject symlink escape before reading', () async {
    fileSystem.file('/outside.txt').writeAsStringSync('secret');
    fileSystem.link('/workspace/escape.txt').createSync('/outside.txt');

    final result = await _registry(factory).invoke(
      'host.workspace.read_text',
      const <String, Object?>{'path': 'escape.txt'},
      _context(const <String>{'workspace.read'}),
    );

    expect(result.ok, isFalse);
    expect(fileSystem.file('/outside.txt').readAsStringSync(), 'secret');
  });

  test('workspace blob preserves requested model image detail', () async {
    fileSystem.file('/workspace/preview.png').writeAsBytesSync(<int>[
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
    ]);

    final result = await _registry(factory)
        .invoke('host.workspace.read_blob', const <String, Object?>{
          'path': 'preview.png',
          'image_detail': 'original',
        }, _context(const <String>{'workspace.read'}));

    expect(result.ok, isTrue);
    final attachment = result.resources.single.value as ConversationAttachment;
    expect(attachment.imageDetail, 'original');
    expect(attachment.bytes, isNotNull);
  });

  test('workspace metadata primitives keep paths bounded and typed', () async {
    fileSystem.directory('/workspace/nested').createSync();
    fileSystem
        .file('/workspace/nested/c.txt')
        .writeAsStringSync('one\ntwo\nthree');
    fileSystem.link('/workspace/local-link').createSync('/workspace/a.txt');
    final registry = _registry(factory);

    final stat = await registry.invoke(
      'host.workspace.stat',
      const <String, Object?>{'path': 'nested/c.txt'},
      _context(const <String>{'workspace.read'}),
    );
    final list = await registry.invoke(
      'host.workspace.list',
      const <String, Object?>{'path': '.'},
      _context(const <String>{'workspace.read'}),
    );
    final read = await registry.invoke(
      'host.workspace.read_text',
      const <String, Object?>{'path': 'nested/c.txt', 'offset': 1, 'limit': 1},
      _context(const <String>{'workspace.read'}),
    );
    final walk = await registry.invoke(
      'host.workspace.walk',
      const <String, Object?>{},
      _context(const <String>{'workspace.read'}),
    );

    expect(stat.value, containsPair('type', 'file'));
    expect(
      ((list.value! as Map<String, Object?>)['entries']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .map((entry) => entry['type']),
      containsAll(<String>['file', 'directory']),
    );
    expect(read.value, containsPair('text', 'two'));
    expect(read.value, containsPair('next_offset', 2));
    expect(read.value, containsPair('eof', false));
    expect(
      ((walk.value! as Map<String, Object?>)['entries']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .map((entry) => entry['path']),
      contains('nested/c.txt'),
    );
  });

  test('workspace primitives return structured validation failures', () async {
    fileSystem.file('/workspace/photo.jpg').writeAsBytesSync(<int>[1]);
    fileSystem.file('/workspace/photo.webp').writeAsBytesSync(<int>[1]);
    fileSystem.file('/workspace/photo.gif').writeAsBytesSync(<int>[1]);
    fileSystem.file('/workspace/photo.bin').writeAsBytesSync(<int>[1]);
    final registry = _registry(factory);

    for (final path in <String>['photo.jpg', 'photo.webp', 'photo.gif']) {
      final result = await registry.invoke(
        'host.workspace.read_blob',
        <String, Object?>{'path': path},
        _context(const <String>{'workspace.read'}),
      );
      expect(result.ok, isTrue, reason: path);
    }
    final notDirectory = await registry.invoke(
      'host.workspace.list',
      const <String, Object?>{'path': 'a.txt'},
      _context(const <String>{'workspace.read'}),
    );
    final invalidPage = await registry.invoke(
      'host.workspace.read_text',
      const <String, Object?>{'path': 'a.txt', 'offset': -1},
      _context(const <String>{'workspace.read'}),
    );
    final invalidDetail = await registry.invoke(
      'host.workspace.read_blob',
      const <String, Object?>{'path': 'photo.jpg', 'image_detail': 'low'},
      _context(const <String>{'workspace.read'}),
    );
    final unsupported = await registry.invoke(
      'host.workspace.read_blob',
      const <String, Object?>{'path': 'photo.bin'},
      _context(const <String>{'workspace.read'}),
    );

    expect(notDirectory.error?.code, 'not_directory');
    expect(invalidPage.error?.code, 'invalid_arguments');
    expect(invalidDetail.error?.code, 'invalid_arguments');
    expect(unsupported.error?.code, 'unsupported_media_type');
  });

  test(
    'workspace transaction supports delete and rejects ambiguous writes',
    () async {
      final registry = _registry(factory);
      final deleted = await registry.invoke(
        'host.workspace.transaction',
        const <String, Object?>{
          'operations': <Map<String, Object?>>[
            <String, Object?>{'kind': 'delete', 'path': 'b.txt'},
          ],
        },
        _context(const <String>{'workspace.patch'}),
      );
      final duplicate = await registry.invoke(
        'host.workspace.transaction',
        const <String, Object?>{
          'operations': <Map<String, Object?>>[
            <String, Object?>{'kind': 'write', 'path': 'a.txt', 'content': '1'},
            <String, Object?>{'kind': 'write', 'path': 'a.txt', 'content': '2'},
          ],
        },
        _context(const <String>{'workspace.patch'}),
      );
      final unsupported = await registry.invoke(
        'host.workspace.transaction',
        const <String, Object?>{
          'operations': <Map<String, Object?>>[
            <String, Object?>{'kind': 'rename', 'path': 'a.txt'},
          ],
        },
        _context(const <String>{'workspace.patch'}),
      );

      expect(deleted.ok, isTrue);
      expect(fileSystem.file('/workspace/b.txt').existsSync(), isFalse);
      expect(duplicate.error?.code, 'invalid_arguments');
      expect(unsupported.error?.code, 'invalid_arguments');
    },
  );

  test('published attachment is emitted as an opaque tool resource', () async {
    const attachment = ConversationAttachment(
      id: 'published-1',
      fileName: 'a.txt',
      mimeType: 'text/plain',
      byteSize: 3,
      path: '/private/published-1.blob',
    );

    final result =
        await _registry(
          factory,
          attachments: const _FixedAttachmentPublisher(attachment),
        ).invoke('host.attachment.publish', const <String, Object?>{
          'path': 'a.txt',
        }, _context(const <String>{'attachment.publish'}));

    expect(result.ok, isTrue);
    expect(result.value, containsPair('id', attachment.id));
    expect(result.resources.single.value, same(attachment));
  });

  test('attachment read preserves immutable resource metadata', () async {
    const attachment = ConversationAttachment(
      id: 'stored-1',
      fileName: 'stored.txt',
      mimeType: 'text/plain',
      byteSize: 6,
      path: '/private/stored-1.blob',
      sha256: 'digest',
    );

    final result =
        await _registry(
          factory,
          attachmentReader: const _FixedAttachmentReader(attachment),
        ).invoke('host.attachment.read', const <String, Object?>{
          'id': 'stored-1',
        }, _context(const <String>{'attachment.read'}));

    expect(result.value, containsPair('sha256', 'digest'));
    expect(result.resources.single.value, same(attachment));
  });

  test('process primitives use only session-scoped handles', () async {
    final processes = _RecordingProcesses();
    final registry = _registry(factory, processes: processes);
    final started = await registry.invoke(
      'host.process.start',
      const <String, Object?>{
        'command': 'dart --version',
        'workdir': '.',
        'tty': true,
        'shell': 'powershell',
        'login': false,
      },
      _context(const <String>{'process.execute'}),
    );
    final read = await registry.invoke(
      'host.process.read',
      const <String, Object?>{'handle': 7, 'yield_time_ms': 25},
      _context(const <String>{'process.execute'}),
    );
    final written = await registry.invoke(
      'host.process.write',
      const <String, Object?>{'handle': 7, 'chars': ''},
      _context(const <String>{'process.write'}),
    );
    final interrupted = await registry.invoke(
      'host.process.interrupt',
      const <String, Object?>{'handle': 7},
      _context(const <String>{'process.write'}),
    );
    final terminated = await registry.invoke(
      'host.process.terminate',
      const <String, Object?>{'handle': 7},
      _context(const <String>{'process.write'}),
    );
    final unknown = await registry.invoke(
      'host.process.read',
      const <String, Object?>{'handle': 404},
      _context(const <String>{'process.execute'}),
    );
    final invalidYield = await registry.invoke(
      'host.process.read',
      const <String, Object?>{'handle': 7, 'yield_time_ms': -1},
      _context(const <String>{'process.execute'}),
    );

    expect(started.value, <String, Object?>{'handle': 7});
    expect(processes.command, 'dart --version');
    expect(processes.workingDirectory, '/workspace');
    expect(processes.markedApproved, 7);
    expect(read.value, <String, Object?>{
      'output': 'chunk',
      'running': false,
      'exit_code': 0,
      'wall_time_ms': 4,
    });
    expect(written.value, <String, Object?>{'written': true});
    expect(interrupted.value, <String, Object?>{'interrupted': true});
    expect(terminated.value, <String, Object?>{'terminated': true});
    expect(processes.session.writes, <String>['']);
    expect(processes.session.interruptions, 1);
    expect(unknown.error?.code, 'handle_not_found');
    expect(invalidYield.error?.code, 'invalid_arguments');
  });

  test('process read cancellation interrupts the live handle', () async {
    final session = _RecordingExecSession(blockReads: true);
    final processes = _RecordingProcesses(session: session);
    final cancellation = _HostCancellation();
    final pending = _registry(factory, processes: processes).invoke(
      'host.process.read',
      const <String, Object?>{'handle': 7, 'yield_time_ms': 300000},
      _context(const <String>{'process.execute'}, cancellation: cancellation),
    );

    await session.readStarted.future;
    cancellation.cancel();
    final result = await pending;

    expect(result.error?.code, 'cancelled');
    expect(session.interruptions, 1);
  });

  test('clock and skill primitives preserve structured host values', () async {
    final clock = _RecordingClock();
    final skills = _FixedSkills();
    final registry = _registry(factory, clock: clock, skills: skills);
    final current = await registry.invoke(
      'host.clock.current_time',
      const <String, Object?>{},
      _context(const <String>{'clock.read'}),
    );
    final slept = await registry.invoke(
      'host.clock.sleep',
      const <String, Object?>{'duration_ms': 250},
      _context(const <String>{'clock.sleep'}),
    );
    final listed = await registry.invoke(
      'host.skills.list',
      const <String, Object?>{},
      _context(const <String>{'workspace.read'}),
    );
    final document = await registry.invoke(
      'host.skills.read',
      const <String, Object?>{'name': 'sample'},
      _context(const <String>{'workspace.read'}),
    );
    final resource = await registry.invoke(
      'host.skills.read',
      const <String, Object?>{'name': 'sample', 'resource': 'notes.md'},
      _context(const <String>{'workspace.read'}),
    );

    expect(current.value, containsPair('utc', '2026-01-01T00:00:00.000Z'));
    expect(slept.value, <String, Object?>{
      'outcome': 'elapsed',
      'elapsed_ms': 250,
    });
    final listedValue = listed.value! as Map<String, Object?>;
    expect(listedValue['skills'], hasLength(1));
    expect(listedValue['implicit_skills'], <Map<String, Object?>>[
      <String, Object?>{'name': 'sample', 'instructions': '# Instructions'},
    ]);
    expect(document.value, containsPair('instructions', '# Instructions'));
    expect(
      (document.value! as Map<String, Object?>)['resources'],
      hasLength(1),
    );
    expect(resource.value, containsPair('contents', 'resource contents'));
  });

  test(
    'optional host surfaces are omitted instead of exposed unconfigured',
    () {
      final registry = _registry(factory, isRootAgent: false);

      expect(
        registry.descriptors.map((descriptor) => descriptor.operation),
        isNot(contains('host.interaction.request_user_input')),
      );
      expect(
        () => builtInHostPrimitiveRegistry(
          BuiltInHostPrimitivePorts(
            workspaceRoot: '/workspace',
            attachments: _UnusedAttachmentPublisher(),
            attachmentReader: _UnusedAttachmentReader(),
            clock: _UnusedClock(),
            questions: _UnusedQuestions(),
            processes: _UnusedProcesses(),
            skills: _EmptySkills(),
            callId: 'turn',
            session: _session,
            definition: _definition,
            luaCodeMode: _RecordingLuaCodeModeHost(),
            fileSystem: fileSystem,
            platform: TestPlatform.native(operatingSystem: 'linux'),
          ),
        ),
        throwsA(anyOf(isA<AssertionError>(), isA<StateError>())),
      );
    },
  );

  test('MCP invocation receives the live host cancellation signal', () async {
    final gateway = _RecordingMcpGateway();
    final cancellation = _HostCancellation();
    final result = await _registry(factory, mcp: gateway).invoke(
      'host.mcp.invoke_tool',
      const <String, Object?>{
        'server': 'github',
        'name': 'echo',
        'arguments': <String, Object?>{},
      },
      _context(const <String>{'mcp.invoke'}, cancellation: cancellation),
    );

    expect(result.ok, isTrue);
    expect(gateway.invocations, hasLength(1));
    expect(identical(gateway.cancellation, cancellation), isTrue);
  });

  test(
    'an already-cancelled MCP invocation never reaches the gateway',
    () async {
      final gateway = _RecordingMcpGateway();
      final cancellation = _HostCancellation()..cancel();
      final result = await _registry(factory, mcp: gateway).invoke(
        'host.mcp.invoke_tool',
        const <String, Object?>{
          'server': 'github',
          'name': 'echo',
          'arguments': <String, Object?>{},
        },
        _context(const <String>{'mcp.invoke'}, cancellation: cancellation),
      );

      expect(result.error?.code, 'cancelled');
      expect(gateway.invocations, isEmpty);
    },
  );

  test('Lua cell primitives expose only safety metadata', () {
    final registry = _registry(
      factory,
      luaCodeMode: _RecordingLuaCodeModeHost(),
      selectedTools: _SelectedLuaTools(),
    );

    expect(
      registry.descriptors
          .where((value) => value.operation.startsWith('host.lua.'))
          .map((value) => value.toJson()),
      <Map<String, Object?>>[
        <String, Object?>{
          'operation': 'host.lua.read',
          'capability': 'process.execute',
          'effect': 'command',
          'luaInputType': 'tinest.LuaReadInput',
          'luaOutputType': 'tinest.LuaChunkOutput',
        },
        <String, Object?>{
          'operation': 'host.lua.start',
          'capability': 'process.execute',
          'effect': 'command',
          'luaInputType': 'tinest.LuaStartInput',
          'luaOutputType': 'tinest.LuaChunkOutput',
        },
        <String, Object?>{
          'operation': 'host.lua.terminate',
          'capability': 'process.write',
          'effect': 'command',
          'luaInputType': 'tinest.LuaTerminateInput',
          'luaOutputType': 'tinest.LuaChunkOutput',
        },
      ],
    );
  });

  test(
    'Lua start resolves selected IDs and preserves structured effects',
    () async {
      const attachment = ConversationAttachment(
        id: 'file-1',
        fileName: 'result.txt',
        mimeType: 'text/plain',
        byteSize: 6,
        path: '/private/result.txt',
      );
      const image = ConversationAttachment(
        id: 'image-1',
        fileName: 'preview.png',
        mimeType: 'image/png',
        byteSize: 8,
        path: '/private/preview.png',
        imageDetail: 'high',
      );
      final host = _RecordingLuaCodeModeHost(
        executeResult: const LuaCellChunk(
          cellId: 'cell-1',
          output: 'started',
          running: true,
          attachments: <ConversationAttachment>[attachment],
          contextImages: <ConversationAttachment>[image],
          notifications: <Object?>['notice'],
        ),
      );
      final tools = _SelectedLuaTools();
      final registry = _registry(
        factory,
        luaCodeMode: host,
        selectedTools: tools,
      );

      final result = await registry.invoke(
        'host.lua.start',
        const <String, Object?>{
          'source': 'return tools.read_file({path="a.txt"})',
          'tools': <String>['acme.files/read'],
          'yield_time_ms': 75,
          'max_output_tokens': 128,
        },
        _context(const <String>{'process.execute'}),
      );

      expect(host.executeRequests.single.source, contains('read_file'));
      expect(
        host.executeRequests.single.yieldTime,
        const Duration(milliseconds: 100),
      );
      expect(host.executeRequests.single.maxOutputTokens, 256);
      expect(host.executeRequests.single.tools, hasLength(1));
      expect(host.executeRequests.single.tools.single.name, 'read_file');
      expect(tools.resolvedIds, <String>['acme.files/read']);
      final outside = await host.executeContexts.single.tools.invoke(
        'unselected',
        const <String, dynamic>{},
      );
      expect(outside.isError, isTrue);
      expect(tools.invokedNames, isEmpty);
      await host.executeContexts.single.tools.invoke(
        'read_file',
        const <String, dynamic>{},
      );
      expect(tools.invokedNames, <String>['read_file']);
      expect(result.toJson(), <String, Object?>{
        'ok': true,
        'value': <String, Object?>{
          'handle': 'cell-1',
          'output': 'started',
          'running': true,
          'terminated': false,
        },
      });
      expect(
        result.resources.map((value) => value.value),
        <ConversationAttachment>[attachment, image],
      );
      expect(result.notifications, <Object?>['notice']);
    },
  );

  test('Lua read and terminate use bounded wait requests', () async {
    final host = _RecordingLuaCodeModeHost(
      waitResult: const LuaCellChunk(
        cellId: 'cell-1',
        output: 'done',
        terminated: true,
      ),
    );
    final registry = _registry(
      factory,
      luaCodeMode: host,
      selectedTools: _SelectedLuaTools(),
    );

    final read = await registry.invoke('host.lua.read', const <String, Object?>{
      'handle': 'cell-1',
      'yield_time_ms': 90000,
      'max_output_tokens': 200000,
    }, _context(const <String>{'process.execute'}));
    final terminate = await registry.invoke(
      'host.lua.terminate',
      const <String, Object?>{'handle': 'cell-1'},
      _context(const <String>{'process.write'}),
    );

    expect(read.ok, isTrue);
    expect(host.waitRequests.first.cellId, 'cell-1');
    expect(host.waitRequests.first.yieldTime, const Duration(seconds: 60));
    expect(host.waitRequests.first.maxOutputTokens, 100000);
    expect(host.waitRequests.first.terminate, isFalse);
    expect(terminate.ok, isTrue);
    expect(host.waitRequests.last.terminate, isTrue);
  });

  test('Lua start rejects unselected and duplicate wire tool IDs', () async {
    final registry = _registry(
      factory,
      luaCodeMode: _RecordingLuaCodeModeHost(),
      selectedTools: _SelectedLuaTools(),
    );
    final unknown = await registry.invoke(
      'host.lua.start',
      const <String, Object?>{
        'source': 'return true',
        'tools': <String>['acme.files/unknown'],
      },
      _context(const <String>{'process.execute'}),
    );
    final duplicate = await registry.invoke(
      'host.lua.start',
      const <String, Object?>{
        'source': 'return true',
        'tools': <String>['acme.files/read', 'acme.files/read'],
      },
      _context(const <String>{'process.execute'}),
    );

    expect(unknown.error?.code, 'invalid_arguments');
    expect(duplicate.error?.code, 'invalid_arguments');
  });

  test('user interaction receives the owning model tool call ID', () async {
    final questions = _RecordingQuestions();
    final result = await _registry(factory, questions: questions).invoke(
      'host.interaction.request_user_input',
      const <String, Object?>{
        'questions': <Map<String, Object?>>[
          <String, Object?>{
            'id': 'store',
            'header': 'Storage',
            'question': 'Which store?',
            'options': <Map<String, Object?>>[
              <String, Object?>{
                'label': 'SQLite',
                'description': 'Local storage.',
              },
            ],
          },
        ],
      },
      _context(const <String>{
        'interaction.request',
      }, callId: 'model-tool-call'),
    );

    expect(result.ok, isTrue);
    expect(questions.callId, 'model-tool-call');
  });
}

HostPrimitiveRegistry _registry(
  HostPrimitiveRegistryFactory factory, {
  AttachmentPublisher? attachments,
  AttachmentReader? attachmentReader,
  AgentClock? clock,
  ExecSessionHost? processes,
  SkillCatalog? skills,
  McpHostPrimitiveGateway? mcp,
  LuaCodeModeHost? luaCodeMode,
  SelectedLuaToolInvoker? selectedTools,
  UserQuestionCoordinator? questions,
  bool isRootAgent = true,
}) => factory.create(
  workspaceRoot: '/workspace',
  attachments: attachments ?? _UnusedAttachmentPublisher(),
  attachmentReader: attachmentReader ?? _UnusedAttachmentReader(),
  clock: clock ?? _UnusedClock(),
  questions: questions ?? _UnusedQuestions(),
  processes: processes ?? _UnusedProcesses(),
  skills: skills ?? _EmptySkills(),
  callId: 'turn',
  isRootAgent: isRootAgent,
  session: _session,
  definition: _definition,
  mcp: mcp,
  luaCodeMode: luaCodeMode,
  selectedTools: selectedTools,
);

HostPrimitiveContext _context(
  Set<String> capabilities, {
  HostPrimitiveCancellation? cancellation,
  String? callId,
}) => HostPrimitiveContext(
  pluginId: 'acme.test',
  agentId: 'agent',
  sessionId: 'session',
  workspaceRoot: '/workspace',
  allowedCapabilities: capabilities,
  callId: callId,
  cancellation: cancellation,
);

final class _MemoryHostPrimitiveRegistryFactory
    implements HostPrimitiveRegistryFactory {
  const new(this.fileSystem);

  final FileSystem fileSystem;

  @override
  HostPrimitiveRegistry create({
    required String workspaceRoot,
    required AttachmentPublisher attachments,
    required AttachmentReader attachmentReader,
    required AgentClock clock,
    required UserQuestionCoordinator questions,
    required ExecSessionHost processes,
    required SkillCatalog skills,
    required String callId,
    required bool isRootAgent,
    required SessionDto session,
    required AgentDefinitionDto definition,
    MultiAgentService? collaboration,
    McpHostPrimitiveGateway? mcp,
    LuaCodeModeHost? luaCodeMode,
    SelectedLuaToolInvoker? selectedTools,
  }) => builtInHostPrimitiveRegistry(
    BuiltInHostPrimitivePorts(
      workspaceRoot: workspaceRoot,
      attachments: attachments,
      attachmentReader: attachmentReader,
      clock: clock,
      questions: questions,
      processes: processes,
      skills: skills,
      callId: callId,
      isRootAgent: isRootAgent,
      session: session,
      definition: definition,
      collaboration: collaboration,
      mcp: mcp,
      luaCodeMode: luaCodeMode,
      selectedTools: selectedTools,
      fileSystem: fileSystem,
      platform: TestPlatform.native(operatingSystem: 'linux'),
    ),
  );
}

final _session = SessionDto(
  id: 'session',
  worktreeId: 'worktree',
  title: 'Test',
  agentDefinitionId: 'agent',
  status: SessionStatus.idle,
  origin: SessionOrigin.manual,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

const _definition = AgentDefinitionDto(
  version: 5,
  id: 'agent',
  name: 'Agent',
  description: '',
  mode: AgentMode.primary,
  model: AgentModelSelectionDto(source: AgentModelSource.session),
  driverId: 'acme.driver/driver',
  extensionIds: <String>[],
  toolIds: <String>[],
  pluginSettings: <String, Map<String, dynamic>>{},
  callableAgentIds: <String>[],
  prompt: '',
  contentHash: 'agent-revision',
  sourcePath: 'agent.md',
);

final class _UnusedAttachmentPublisher implements AttachmentPublisher {
  @override
  Future<ConversationAttachment> publish(String path) =>
      throw UnimplementedError();
}

final class _FixedAttachmentPublisher implements AttachmentPublisher {
  const new(this.attachment);

  final ConversationAttachment attachment;

  @override
  Future<ConversationAttachment> publish(String path) async => attachment;
}

final class _UnusedAttachmentReader implements AttachmentReader {
  @override
  Future<ConversationAttachment> read(String id) => throw UnimplementedError();
}

final class _FixedAttachmentReader implements AttachmentReader {
  const new(this.attachment);

  final ConversationAttachment attachment;

  @override
  Future<ConversationAttachment> read(String id) async {
    expect(id, attachment.id);
    return attachment;
  }
}

final class _UnusedClock implements AgentClock {
  @override
  DateTime nowUtc() => DateTime.utc(2026);

  @override
  Future<SleepOutcome> sleep(
    Duration duration,
    CancellationToken cancellation,
  ) => throw UnimplementedError();
}

final class _RecordingClock implements AgentClock {
  DateTime _now = DateTime.utc(2026);

  @override
  DateTime nowUtc() => _now;

  @override
  Future<SleepOutcome> sleep(
    Duration duration,
    CancellationToken cancellation,
  ) async {
    expect(cancellation.isCancelled, isFalse);
    _now = _now.add(duration);
    return SleepOutcome.elapsed;
  }
}

final class _UnusedQuestions implements UserQuestionCoordinator {
  @override
  Future<List<UserAnswer>> ask(
    String callId,
    List<UserQuestion> questions,
    CancellationToken cancellation,
  ) => throw UnimplementedError();
}

final class _RecordingQuestions implements UserQuestionCoordinator {
  String? callId;

  @override
  Future<List<UserAnswer>> ask(
    String callId,
    List<UserQuestion> questions,
    CancellationToken cancellation,
  ) async {
    this.callId = callId;
    return const <UserAnswer>[];
  }
}

final class _UnusedProcesses implements ExecSessionHost {
  @override
  bool isApproved(int sessionId) => false;

  @override
  ExecSession? lookup(int sessionId) => null;

  @override
  void markApproved(int sessionId) {}

  @override
  Future<bool> terminate(int sessionId) async => false;

  @override
  Future<ExecSession> start({
    required String command,
    required String workingDirectory,
    required bool tty,
    String? shell,
    bool login = true,
  }) => throw UnimplementedError();
}

final class _RecordingProcesses implements ExecSessionHost {
  new({_RecordingExecSession? session})
    : session = session ?? _RecordingExecSession();

  final _RecordingExecSession session;
  String? command;
  String? workingDirectory;
  int? markedApproved;

  @override
  bool isApproved(int sessionId) => markedApproved == sessionId;

  @override
  ExecSession? lookup(int sessionId) =>
      sessionId == session.id ? session : null;

  @override
  void markApproved(int sessionId) {
    markedApproved = sessionId;
  }

  @override
  Future<bool> terminate(int sessionId) async => sessionId == session.id;

  @override
  Future<ExecSession> start({
    required String command,
    required String workingDirectory,
    required bool tty,
    String? shell,
    bool login = true,
  }) async {
    this.command = command;
    this.workingDirectory = workingDirectory;
    expect(tty, isTrue);
    expect(shell, 'powershell');
    expect(login, isFalse);
    return session;
  }
}

final class _RecordingExecSession implements ExecSession {
  new({this.blockReads = false});

  final bool blockReads;
  final List<String> writes = <String>[];
  final Completer<void> readStarted = Completer<void>();
  final Completer<ExecSessionChunk> _blockedRead =
      Completer<ExecSessionChunk>();
  int interruptions = 0;

  @override
  int get id => 7;

  @override
  Future<void> interrupt() async {
    interruptions += 1;
    if (!_blockedRead.isCompleted) {
      _blockedRead.complete(
        const ExecSessionChunk(output: '', isRunning: true),
      );
    }
  }

  @override
  Future<ExecSessionChunk> read(Duration yieldTime) async {
    if (!readStarted.isCompleted) readStarted.complete();
    if (blockReads) return await _blockedRead.future;
    expect(yieldTime, const Duration(milliseconds: 25));
    return const ExecSessionChunk(
      output: 'chunk',
      isRunning: false,
      exitCode: 0,
      wallTime: Duration(milliseconds: 4),
    );
  }

  @override
  Future<void> write(String chars) async {
    writes.add(chars);
  }
}

final class _EmptySkills implements SkillCatalog {
  @override
  Future<SkillContent> read(String name) => throw UnimplementedError();

  @override
  Future<String> readResource(String name, String relativePath) =>
      throw UnimplementedError();

  @override
  List<SkillSummary> summaries() => const <SkillSummary>[];
}

final class _FixedSkills implements SkillCatalog, ImplicitSkillDocumentSource {
  @override
  List<ImplicitSkillDocument> implicitSkillDocuments() =>
      const <ImplicitSkillDocument>[
        ImplicitSkillDocument(name: 'sample', instructions: '# Instructions'),
      ];

  @override
  Future<SkillContent> read(String name) async => const SkillContent(
    name: 'sample',
    description: 'Sample skill',
    instructions: '# Instructions',
    resources: <SkillResourceRef>[
      SkillResourceRef(path: 'notes.md', sizeBytes: 17),
    ],
  );

  @override
  Future<String> readResource(String name, String relativePath) async {
    expect(name, 'sample');
    expect(relativePath, 'notes.md');
    return 'resource contents';
  }

  @override
  List<SkillSummary> summaries() => const <SkillSummary>[
    SkillSummary(name: 'sample', description: 'Sample skill'),
  ];
}

final class _SelectedLuaTools implements SelectedLuaToolInvoker {
  final List<String> resolvedIds = <String>[];
  final List<String> invokedNames = <String>[];

  @override
  List<LuaNestedToolDefinition> definitionsFor(List<String> ids) {
    resolvedIds.addAll(ids);
    if (ids.any((id) => id != 'acme.files/read')) {
      throw const FormatException('Unknown selected tool.');
    }
    return <LuaNestedToolDefinition>[
      if (ids.contains('acme.files/read'))
        const LuaNestedToolDefinition(
          name: 'read_file',
          description: 'Read a file.',
          kind: 'function',
          exposure: 'advertised',
          inputSchema: <String, Object?>{'type': 'object'},
        ),
    ];
  }

  @override
  Future<LuaNestedToolResult> invoke(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    invokedNames.add(name);
    return LuaNestedToolResult(value: arguments);
  }
}

final class _RecordingLuaCodeModeHost implements LuaCodeModeHost {
  new({
    this.executeResult = const LuaCellChunk(cellId: 'cell', output: ''),
    this.waitResult = const LuaCellChunk(cellId: 'cell', output: ''),
  });

  final LuaCellChunk executeResult;
  final LuaCellChunk waitResult;
  final List<LuaExecuteRequest> executeRequests = <LuaExecuteRequest>[];
  final List<LuaCodeModeContext> executeContexts = <LuaCodeModeContext>[];
  final List<LuaWaitRequest> waitRequests = <LuaWaitRequest>[];

  @override
  Future<LuaCellChunk> execute(
    LuaExecuteRequest request,
    LuaCodeModeContext context,
  ) async {
    executeRequests.add(request);
    executeContexts.add(context);
    return executeResult;
  }

  @override
  Future<LuaCellChunk> wait(
    LuaWaitRequest request,
    LuaCodeModeContext context,
  ) async {
    waitRequests.add(request);
    return waitResult;
  }
}

final class _RecordingMcpGateway implements McpHostPrimitiveGateway {
  final List<Map<String, Object?>> invocations = <Map<String, Object?>>[];
  RequestCancellation? cancellation;

  @override
  Future<Map<String, Object?>> catalogTools(
    Map<String, Object?> arguments,
  ) async => const <String, Object?>{'tools': <Object?>[]};

  @override
  Future<Map<String, Object?>> invokeTool(
    Map<String, Object?> arguments, {
    RequestCancellation? cancellation,
  }) async {
    invocations.add(arguments);
    this.cancellation = cancellation;
    return const <String, Object?>{'content': <Object?>[], 'isError': false};
  }

  @override
  Future<Map<String, Object?>> listResourceTemplates(
    Map<String, Object?> arguments,
  ) async => const <String, Object?>{'resourceTemplates': <Object?>[]};

  @override
  Future<Map<String, Object?>> listResources(
    Map<String, Object?> arguments,
  ) async => const <String, Object?>{'resources': <Object?>[]};

  @override
  Future<Map<String, Object?>> readResource(
    Map<String, Object?> arguments,
  ) async => const <String, Object?>{'contents': <Object?>[]};
}

final class _HostCancellation implements HostPrimitiveCancellation {
  final List<void Function()> _callbacks = <void Function()>[];
  bool _cancelled = false;

  @override
  bool get isCancelled => _cancelled;

  @override
  void onCancel(void Function() callback) {
    if (_cancelled) {
      callback();
      return;
    }
    _callbacks.add(callback);
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final callback in List<void Function()>.of(_callbacks)) {
      callback();
    }
    _callbacks.clear();
  }
}
