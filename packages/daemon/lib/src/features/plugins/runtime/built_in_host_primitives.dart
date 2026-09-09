import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:agent/agent.dart';
import 'package:crypto/crypto.dart';
import 'package:daemon/src/features/plugins/runtime/host_primitive_contracts.dart';
import 'package:daemon/src/features/plugins/runtime/host_primitives.dart';
import 'package:daemon/src/features/sessions/infrastructure/multi_agent.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:daemon/src/shared/ports/mcp_host_primitives.dart';
import 'package:file/file.dart' as file_api;
import 'package:file/local.dart';
import 'package:platform/platform.dart';
import 'package:platform/testing.dart';
import 'package:protocol/protocol.dart';

/// Composition-root port that creates one turn's primitive registry.
abstract interface class HostPrimitiveRegistryFactory {
  /// Creates a registry over ports already scoped to one Agent turn.
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
  });
}

/// Invocation-local selected tool surface available to one Lua code cell.
///
/// Wire IDs are resolved only against the Agent's revision-pinned selection;
/// the cell receives neither a global catalog nor an unscoped dispatcher.
abstract interface class SelectedLuaToolInvoker
    implements LuaNestedToolInvoker {
  /// Resolves opaque SDK wire IDs into runtime definitions for one cell.
  List<LuaNestedToolDefinition> definitionsFor(List<String> ids);
}

/// Native filesystem-backed primitive factory used by the daemon composition.
final class IoHostPrimitiveRegistryFactory
    implements HostPrimitiveRegistryFactory {
  /// Creates the native registry factory.
  const new();

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
      fileSystem: const LocalFileSystem(),
      platform: const Platform(),
    ),
  );
}

/// Turn-scoped ports used by the model-agnostic native primitive registry.
final class BuiltInHostPrimitivePorts {
  /// Creates the primitive environment for one Agent turn.
  const new({
    required this.workspaceRoot,
    required this.attachments,
    required this.attachmentReader,
    required this.clock,
    required this.questions,
    required this.processes,
    required this.skills,
    required this.callId,
    required this.fileSystem,
    required this.platform,
    required this.session,
    required this.definition,
    this.collaboration,
    this.mcp,
    this.luaCodeMode,
    this.selectedTools,
    this.isRootAgent = true,
  }) : assert(
         (luaCodeMode == null) == (selectedTools == null),
         'Lua code host and selected tool invoker must be configured together.',
       );

  /// Canonical workspace root selected by the host.
  final String workspaceRoot;

  /// Publishes canonical workspace files into the turn.
  final AttachmentPublisher attachments;

  /// Reads opaque session-owned attachment identifiers.
  final AttachmentReader attachmentReader;

  /// Host-owned wall clock and wait service.
  final AgentClock clock;

  /// Host-owned user interaction coordinator.
  final UserQuestionCoordinator questions;

  /// Session-scoped process handle owner.
  final ExecSessionHost processes;

  /// Turn-scoped skill catalog.
  final SkillCatalog skills;

  /// Owning tool/turn call ID used by interaction primitives.
  final String callId;

  /// Whether interaction primitives are available to this session.
  final bool isRootAgent;

  /// Filesystem injected at the composition root.
  final file_api.FileSystem fileSystem;

  /// Platform path semantics injected at the composition root.
  final Platform platform;

  /// Session identity used by collaboration primitives.
  final SessionDto session;

  /// Agent definition governing delegated-agent allowlists.
  final AgentDefinitionDto definition;

  /// Optional collaboration coordinator configured after daemon bootstrap.
  final MultiAgentService? collaboration;

  /// Optional MCP gateway scoped to this workspace.
  final McpHostPrimitiveGateway? mcp;

  /// Optional session-scoped sandboxed Lua cell host.
  final LuaCodeModeHost? luaCodeMode;

  /// Revision-pinned nested tool surface for Lua cells.
  final SelectedLuaToolInvoker? selectedTools;
}

/// Creates the native safety-kernel operations available to Lua plugins.
///
/// No entry here owns a model tool name, description, schema, defaults,
/// output formatting, or UI. Lua contributions compose these raw operations.
HostPrimitiveRegistry builtInHostPrimitiveRegistry(
  BuiltInHostPrimitivePorts ports,
) {
  if ((ports.luaCodeMode == null) != (ports.selectedTools == null)) {
    throw StateError(
      'Lua code host and selected tool invoker must be configured together.',
    );
  }
  final workspace = _WorkspacePrimitiveHost(ports);
  final registry = HostPrimitiveRegistry(<HostPrimitive<Object?, Object?>>[
    HostPrimitiveContracts.workspaceStat
        .bind(decode: _object, invoke: workspace.stat)
        .erased,
    HostPrimitiveContracts.workspaceList
        .bind(decode: _object, invoke: workspace.list)
        .erased,
    HostPrimitiveContracts.workspaceReadText
        .bind(decode: _object, invoke: workspace.readText)
        .erased,
    HostPrimitiveContracts.workspaceReadBlob
        .bindOutput(decode: _object, invoke: workspace.readBlob)
        .erased,
    HostPrimitiveContracts.workspaceWalk
        .bind(decode: _object, invoke: workspace.walk)
        .erased,
    HostPrimitiveContracts.workspaceTransaction
        .bind(
          decode: _object,
          invoke: workspace.transaction,
          approvalPreview: _workspaceTransactionApprovalPreview,
        )
        .erased,
    HostPrimitiveContracts.processStart
        .bind(
          decode: _object,
          invoke: (arguments, context) =>
              _startProcess(ports, arguments, context),
        )
        .erased,
    HostPrimitiveContracts.processRead
        .bind(
          decode: _object,
          invoke: (arguments, context) =>
              _readProcess(ports, arguments, context),
        )
        .erased,
    HostPrimitiveContracts.processWrite
        .bind(
          decode: _object,
          invoke: (arguments, _) => _writeProcess(ports, arguments),
        )
        .erased,
    HostPrimitiveContracts.processInterrupt
        .bind(
          decode: _object,
          invoke: (arguments, _) => _interruptProcess(ports, arguments),
        )
        .erased,
    HostPrimitiveContracts.processTerminate
        .bind(
          decode: _object,
          invoke: (arguments, _) => _terminateProcess(ports, arguments),
        )
        .erased,
    HostPrimitiveContracts.attachmentPublish
        .bindOutput(
          decode: _object,
          invoke: (arguments, context) =>
              _publishAttachment(ports, workspace, arguments, context),
        )
        .erased,
    HostPrimitiveContracts.attachmentRead
        .bindOutput(
          decode: _object,
          invoke: (arguments, context) =>
              _readAttachment(ports, arguments, context),
        )
        .erased,
    HostPrimitiveContracts.clockCurrentTime
        .bind(
          decode: _object,
          invoke: (_, _) => <String, Object?>{
            'utc': ports.clock.nowUtc().toIso8601String(),
          },
        )
        .erased,
    HostPrimitiveContracts.clockSleep
        .bind(
          decode: _object,
          invoke: (arguments, context) => _sleep(ports, arguments, context),
        )
        .erased,
    HostPrimitiveContracts.skillsList
        .bind(
          decode: _object,
          invoke: (_, _) {
            final implicit = switch (ports.skills) {
              final ImplicitSkillDocumentSource source =>
                source.implicitSkillDocuments(),
              _ => const <ImplicitSkillDocument>[],
            };
            return <String, Object?>{
              'skills': <Map<String, Object?>>[
                for (final summary in ports.skills.summaries())
                  <String, Object?>{
                    'name': summary.name,
                    'description': summary.description,
                  },
              ],
              'implicit_skills': <Map<String, Object?>>[
                for (final document in implicit)
                  <String, Object?>{
                    'name': document.name,
                    'instructions': document.instructions,
                  },
              ],
            };
          },
        )
        .erased,
    HostPrimitiveContracts.skillsRead
        .bind(
          decode: _object,
          invoke: (arguments, _) => _readSkill(ports, arguments),
        )
        .erased,
    if (ports.isRootAgent)
      HostPrimitiveContracts.interactionRequestUserInput
          .bind(
            decode: _object,
            invoke: (arguments, context) =>
                _requestInteraction(ports, arguments, context),
          )
          .erased,
    if (ports.collaboration != null) ..._collaborationPrimitives(ports),
    if (ports.mcp != null) ..._mcpPrimitives(ports.mcp!),
    if (ports.luaCodeMode != null) ..._luaCodeModePrimitives(ports),
  ]);
  validateHostPrimitiveRegistry(
    registry,
    unavailableOperations: <String>{
      // Network and secret transports are capability-brokered directly by the
      // harness because their ports are session-scoped, not registry entries.
      HostPrimitiveContracts.networkRequest.operation,
      HostPrimitiveContracts.secretGet.operation,
      if (!ports.isRootAgent)
        HostPrimitiveContracts.interactionRequestUserInput.operation,
      if (ports.collaboration == null) ...<String>{
        HostPrimitiveContracts.collaborationSpawnAgent.operation,
        HostPrimitiveContracts.collaborationSendMessage.operation,
        HostPrimitiveContracts.collaborationFollowupTask.operation,
        HostPrimitiveContracts.collaborationWaitAgent.operation,
        HostPrimitiveContracts.collaborationInterruptAgent.operation,
        HostPrimitiveContracts.collaborationListAgents.operation,
      },
      if (ports.mcp == null) ...<String>{
        HostPrimitiveContracts.mcpListResources.operation,
        HostPrimitiveContracts.mcpListResourceTemplates.operation,
        HostPrimitiveContracts.mcpReadResource.operation,
        HostPrimitiveContracts.mcpCatalogTools.operation,
        HostPrimitiveContracts.mcpInvokeTool.operation,
      },
      if (ports.luaCodeMode == null) ...<String>{
        HostPrimitiveContracts.luaStart.operation,
        HostPrimitiveContracts.luaRead.operation,
        HostPrimitiveContracts.luaTerminate.operation,
      },
    },
  );
  return registry;
}

String? _workspaceTransactionApprovalPreview(Map<String, Object?> arguments) {
  final rawOperations = arguments['operations'];
  if (rawOperations is! List<Object?> || rawOperations.isEmpty) return null;
  final changes = <String>[];
  for (final rawOperation in rawOperations) {
    final operation = _object(rawOperation);
    final kind = _requiredString(operation, 'kind');
    final path = _requiredString(operation, 'path');
    changes.add('$kind $path');
  }
  return changes.join('\n');
}

final class _WorkspacePrimitiveHost {
  new(this.ports)
    : guard = WorkspacePathGuard(
        ports.workspaceRoot,
        fileSystem: ports.fileSystem,
        platform: ports.platform,
      );

  final BuiltInHostPrimitivePorts ports;
  final WorkspacePathGuard guard;

  Future<Map<String, Object?>> stat(
    Map<String, Object?> arguments,
    HostPrimitiveContext context,
  ) async {
    _checkCancelled(context);
    final requested = _requiredString(arguments, 'path');
    final resolved = guard.resolveExisting(requested);
    final stat = await ports.fileSystem.stat(resolved);
    return <String, Object?>{
      'path': _relative(resolved),
      'type': _entityType(stat.type),
      'size_bytes': stat.size,
      'modified_at': stat.modified.toUtc().toIso8601String(),
    };
  }

  Future<Map<String, Object?>> list(
    Map<String, Object?> arguments,
    HostPrimitiveContext context,
  ) async {
    _checkCancelled(context);
    final resolved = guard.resolveExisting(_requiredString(arguments, 'path'));
    final directory = ports.fileSystem.directory(resolved);
    if (!directory.existsSync()) {
      throw _failure('not_directory', 'Workspace path is not a directory.');
    }
    final entries = await directory.list(followLinks: false).toList()
      ..sort((left, right) => left.path.compareTo(right.path));
    final encoded = <Map<String, Object?>>[];
    for (final entry in entries) {
      _checkCancelled(context);
      final stat = entry.statSync();
      encoded.add(<String, Object?>{
        'name': ports.fileSystem.path.basename(entry.path),
        'path': _relative(entry.path),
        'type': _entityType(stat.type),
        if (stat.type == file_api.FileSystemEntityType.file)
          'size_bytes': stat.size,
      });
    }
    return <String, Object?>{'entries': encoded};
  }

  Future<Map<String, Object?>> readText(
    Map<String, Object?> arguments,
    HostPrimitiveContext context,
  ) async {
    _checkCancelled(context);
    final resolved = guard.resolveExisting(_requiredString(arguments, 'path'));
    final offset = _optionalInt(arguments, 'offset') ?? 0;
    final limit = _optionalInt(arguments, 'limit') ?? 400;
    if (offset < 0 || limit < 1 || limit > 10000) {
      throw const FormatException(
        'offset must be non-negative and limit between 1 and 10000.',
      );
    }
    final text = await ports.fileSystem.file(resolved).readAsString();
    _checkCancelled(context);
    final lines = const LineSplitter().convert(text);
    final start = offset.clamp(0, lines.length);
    final end = (start + limit).clamp(0, lines.length);
    return <String, Object?>{
      'text': lines.sublist(start, end).join('\n'),
      'offset': start,
      if (end < lines.length) 'next_offset': end,
      'total_lines': lines.length,
      'eof': end >= lines.length,
    };
  }

  Future<HostPrimitiveOutput<Object?>> readBlob(
    Map<String, Object?> arguments,
    HostPrimitiveContext context,
  ) async {
    _checkCancelled(context);
    final resolved = guard.resolveExisting(_requiredString(arguments, 'path'));
    final file = ports.fileSystem.file(resolved);
    final bytes = await file.readAsBytes();
    _checkCancelled(context);
    final mimeType = _imageMimeType(file.path, bytes);
    final imageDetail = _optionalString(arguments, 'image_detail');
    if (imageDetail != null &&
        imageDetail != 'high' &&
        imageDetail != 'original') {
      throw const FormatException(
        'image_detail must be high or original when supplied.',
      );
    }
    final attachment = ConversationAttachment(
      id: 'workspace:${_relative(resolved)}',
      fileName: ports.fileSystem.path.basename(resolved),
      mimeType: mimeType,
      byteSize: bytes.length,
      path: resolved,
      bytes: Uint8List.fromList(bytes),
      kind: AgentAttachmentKind.image,
      imageDetail: imageDetail,
    );
    return HostPrimitiveOutput<Object?>(
      value: <String, Object?>{
        'path': _relative(resolved),
        'mime_type': mimeType,
        'byte_size': bytes.length,
      },
      resources: <HostPrimitiveResource>[
        HostPrimitiveResource(
          value: attachment,
          fileName: attachment.fileName,
          mimeType: attachment.mimeType,
          byteSize: attachment.byteSize,
        ),
      ],
    );
  }

  Future<Map<String, Object?>> walk(
    Map<String, Object?> arguments,
    HostPrimitiveContext context,
  ) async {
    _checkCancelled(context);
    final rawPath = arguments['path'];
    final requested = rawPath is String && rawPath.trim().isNotEmpty
        ? rawPath
        : '.';
    final root = guard.resolveExisting(requested);
    const maximumEntries = 10000;
    final entries = <Map<String, Object?>>[];
    var truncated = false;
    await for (final entity
        in ports.fileSystem
            .directory(root)
            .list(recursive: true, followLinks: false)) {
      _checkCancelled(context);
      if (entries.length == maximumEntries) {
        truncated = true;
        break;
      }
      final stat = entity.statSync();
      entries.add(<String, Object?>{
        'path': _relative(entity.path),
        'type': _entityType(stat.type),
        if (stat.type == file_api.FileSystemEntityType.file)
          'size_bytes': stat.size,
      });
    }
    entries.sort(
      (left, right) =>
          (left['path']! as String).compareTo(right['path']! as String),
    );
    return <String, Object?>{'entries': entries, 'truncated': truncated};
  }

  Future<Map<String, Object?>> transaction(
    Map<String, Object?> arguments,
    HostPrimitiveContext context,
  ) async {
    _checkCancelled(context);
    final rawOperations = arguments['operations'];
    if (rawOperations is! List<Object?> || rawOperations.isEmpty) {
      throw const FormatException('operations must be a non-empty array.');
    }
    if (rawOperations.length > 256) {
      throw const FormatException(
        'A transaction may contain at most 256 operations.',
      );
    }
    final operations = <_WorkspaceMutation>[];
    final targets = <String>{};
    for (final rawOperation in rawOperations) {
      final operation = _object(rawOperation);
      final kind = _requiredString(operation, 'kind');
      final path = _requiredString(operation, 'path');
      final resolved = kind == 'write'
          ? guard.resolveWritable(path)
          : guard.resolveExisting(path);
      if (!targets.add(_pathKey(resolved))) {
        throw const FormatException(
          'A transaction cannot target the same path more than once.',
        );
      }
      final expected = _optionalString(operation, 'expected_sha256');
      final file = ports.fileSystem.file(resolved);
      final exists = file.existsSync();
      if (expected != null) {
        if (!exists || _digest(file.readAsBytesSync()) != expected) {
          throw _failure(
            'revision_conflict',
            'Workspace content changed before the transaction.',
          );
        }
      }
      switch (kind) {
        case 'write':
          final content = _requiredString(
            operation,
            'content',
            allowEmpty: true,
          );
          operations.add(
            _WorkspaceMutation.write(
              path: resolved,
              relativePath: _relative(resolved),
              content: content,
              previousBytes: exists ? file.readAsBytesSync() : null,
            ),
          );
        case 'delete':
          if (!exists) {
            throw _failure('not_found', 'Workspace file does not exist.');
          }
          operations.add(
            _WorkspaceMutation.delete(
              path: resolved,
              relativePath: _relative(resolved),
              previousBytes: file.readAsBytesSync(),
            ),
          );
        default:
          throw FormatException('Unsupported workspace operation: $kind');
      }
    }

    final applied = <_WorkspaceMutation>[];
    try {
      for (final operation in operations) {
        _checkCancelled(context);
        operation.apply(ports.fileSystem);
        applied.add(operation);
      }
    } on Object {
      for (final operation in applied.reversed) {
        operation.rollback(ports.fileSystem);
      }
      rethrow;
    }
    return <String, Object?>{
      'applied': <Map<String, Object?>>[
        for (final operation in operations)
          <String, Object?>{
            'kind': operation.kind,
            'path': operation.relativePath,
          },
      ],
    };
  }

  String resolveExisting(String requested) => guard.resolveExisting(requested);

  String _relative(String absolute) {
    final relative = ports.fileSystem.path.relative(
      absolute,
      from: ports.workspaceRoot,
    );
    return relative == '.'
        ? ''
        : ports.fileSystem.path.split(relative).join('/');
  }

  String _pathKey(String value) =>
      ports.platform.isWindows ? value.toLowerCase() : value;
}

final class _WorkspaceMutation {
  const new _({
    required this.kind,
    required this.path,
    required this.relativePath,
    required this.content,
    required this.previousBytes,
  });

  const new write({
    required String path,
    required String relativePath,
    required String content,
    required List<int>? previousBytes,
  }) : this._(
         kind: 'write',
         path: path,
         relativePath: relativePath,
         content: content,
         previousBytes: previousBytes,
       );

  const new delete({
    required String path,
    required String relativePath,
    required List<int> previousBytes,
  }) : this._(
         kind: 'delete',
         path: path,
         relativePath: relativePath,
         content: null,
         previousBytes: previousBytes,
       );

  final String kind;
  final String path;
  final String relativePath;
  final String? content;
  final List<int>? previousBytes;

  void apply(file_api.FileSystem fileSystem) {
    final file = fileSystem.file(path);
    switch (kind) {
      case 'write':
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(content!, flush: true);
      case 'delete':
        file.deleteSync();
    }
  }

  void rollback(file_api.FileSystem fileSystem) {
    final file = fileSystem.file(path);
    final previous = previousBytes;
    if (previous == null) {
      if (file.existsSync()) file.deleteSync();
      return;
    }
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(previous, flush: true);
  }
}

String _digest(List<int> bytes) => sha256.convert(bytes).toString();

Future<Map<String, Object?>> _startProcess(
  BuiltInHostPrimitivePorts ports,
  Map<String, Object?> arguments,
  HostPrimitiveContext context,
) async {
  _checkCancelled(context);
  final command = _requiredString(arguments, 'command');
  final rawWorkdir = arguments['workdir'];
  final guard = WorkspacePathGuard(
    ports.workspaceRoot,
    fileSystem: ports.fileSystem,
    platform: ports.platform,
  );
  final workdir = rawWorkdir is String && rawWorkdir.trim().isNotEmpty
      ? guard.resolveExisting(rawWorkdir)
      : ports.workspaceRoot;
  if (!ports.fileSystem.directory(workdir).existsSync()) {
    throw _failure('not_directory', 'Process workdir is not a directory.');
  }
  final session = await ports.processes.start(
    command: command,
    workingDirectory: workdir,
    tty: arguments['tty'] == true,
    shell: _optionalString(arguments, 'shell'),
    login: arguments['login'] != false,
  );
  _checkCancelled(context);
  ports.processes.markApproved(session.id);
  return <String, Object?>{'handle': session.id};
}

Future<Map<String, Object?>> _readProcess(
  BuiltInHostPrimitivePorts ports,
  Map<String, Object?> arguments,
  HostPrimitiveContext context,
) async {
  _checkCancelled(context);
  final session = _process(ports, arguments);
  final milliseconds = _optionalInt(arguments, 'yield_time_ms') ?? 0;
  if (milliseconds < 0 || milliseconds > 300000) {
    throw const FormatException('yield_time_ms must be between 0 and 300000.');
  }
  var interrupted = false;
  context.cancellation?.onCancel(() {
    interrupted = true;
    session.interrupt().ignore();
  });
  final chunk = await session.read(Duration(milliseconds: milliseconds));
  if (interrupted) {
    throw _failure('cancelled', 'Process read was cancelled.');
  }
  return <String, Object?>{
    'output': chunk.output,
    'running': chunk.isRunning,
    if (chunk.exitCode != null) 'exit_code': chunk.exitCode,
    'wall_time_ms': chunk.wallTime.inMilliseconds,
  };
}

Future<Map<String, Object?>> _writeProcess(
  BuiltInHostPrimitivePorts ports,
  Map<String, Object?> arguments,
) async {
  final session = _process(ports, arguments);
  await session.write(_requiredString(arguments, 'chars', allowEmpty: true));
  return const <String, Object?>{'written': true};
}

Future<Map<String, Object?>> _interruptProcess(
  BuiltInHostPrimitivePorts ports,
  Map<String, Object?> arguments,
) async {
  await _process(ports, arguments).interrupt();
  return const <String, Object?>{'interrupted': true};
}

Future<Map<String, Object?>> _terminateProcess(
  BuiltInHostPrimitivePorts ports,
  Map<String, Object?> arguments,
) async {
  final handle = _requiredInt(arguments, 'handle');
  if (!await ports.processes.terminate(handle)) {
    throw _failure('handle_not_found', 'Process handle is unavailable.');
  }
  return const <String, Object?>{'terminated': true};
}

ExecSession _process(
  BuiltInHostPrimitivePorts ports,
  Map<String, Object?> arguments,
) {
  final handle = _requiredInt(arguments, 'handle');
  final process = ports.processes.lookup(handle);
  if (process == null) {
    throw _failure('handle_not_found', 'Process handle is unavailable.');
  }
  return process;
}

Future<HostPrimitiveOutput<Object?>> _publishAttachment(
  BuiltInHostPrimitivePorts ports,
  _WorkspacePrimitiveHost workspace,
  Map<String, Object?> arguments,
  HostPrimitiveContext context,
) async {
  _checkCancelled(context);
  final path = workspace.resolveExisting(_requiredString(arguments, 'path'));
  final attachment = await ports.attachments.publish(path);
  return HostPrimitiveOutput<Object?>(
    value: _attachmentJson(attachment),
    resources: <HostPrimitiveResource>[
      HostPrimitiveResource(
        value: attachment,
        fileName: attachment.fileName,
        mimeType: attachment.mimeType,
        byteSize: attachment.byteSize,
      ),
    ],
  );
}

Future<HostPrimitiveOutput<Object?>> _readAttachment(
  BuiltInHostPrimitivePorts ports,
  Map<String, Object?> arguments,
  HostPrimitiveContext context,
) async {
  _checkCancelled(context);
  final attachment = await ports.attachmentReader.read(
    _requiredString(arguments, 'id'),
  );
  return HostPrimitiveOutput<Object?>(
    value: _attachmentJson(attachment),
    resources: <HostPrimitiveResource>[
      HostPrimitiveResource(
        value: attachment,
        fileName: attachment.fileName,
        mimeType: attachment.mimeType,
        byteSize: attachment.byteSize,
      ),
    ],
  );
}

Map<String, Object?> _attachmentJson(ConversationAttachment attachment) =>
    <String, Object?>{
      'id': attachment.id,
      'file_name': attachment.fileName,
      'mime_type': attachment.mimeType,
      'byte_size': attachment.byteSize,
      if (attachment.sha256 != null) 'sha256': attachment.sha256,
    };

Future<Map<String, Object?>> _sleep(
  BuiltInHostPrimitivePorts ports,
  Map<String, Object?> arguments,
  HostPrimitiveContext context,
) async {
  final milliseconds = _requiredInt(arguments, 'duration_ms');
  if (milliseconds < 1 || milliseconds > 43200000) {
    throw const FormatException('duration_ms must be between 1 and 43200000.');
  }
  final cancellation = context.cancellation;
  final token = _PrimitiveCancellationToken(cancellation);
  final started = ports.clock.nowUtc();
  final outcome = await ports.clock.sleep(
    Duration(milliseconds: milliseconds),
    token,
  );
  return <String, Object?>{
    'outcome': outcome.name,
    'elapsed_ms': ports.clock.nowUtc().difference(started).inMilliseconds,
  };
}

Future<Map<String, Object?>> _readSkill(
  BuiltInHostPrimitivePorts ports,
  Map<String, Object?> arguments,
) async {
  final name = _requiredString(arguments, 'name');
  final resource = _optionalString(arguments, 'resource');
  if (resource != null) {
    return <String, Object?>{
      'name': name,
      'resource': resource,
      'contents': await ports.skills.readResource(name, resource),
    };
  }
  final content = await ports.skills.read(name);
  return <String, Object?>{
    'name': content.name,
    'description': content.description,
    'instructions': content.instructions,
    'resources': <Map<String, Object?>>[
      for (final entry in content.resources)
        <String, Object?>{'path': entry.path, 'size_bytes': entry.sizeBytes},
    ],
  };
}

Future<Map<String, Object?>> _requestInteraction(
  BuiltInHostPrimitivePorts ports,
  Map<String, Object?> arguments,
  HostPrimitiveContext context,
) async {
  final rawQuestions = arguments['questions'];
  if (rawQuestions is! List<Object?> || rawQuestions.isEmpty) {
    throw const FormatException('questions must be a non-empty array.');
  }
  final questions = <UserQuestion>[];
  for (final rawQuestion in rawQuestions) {
    final question = _object(rawQuestion);
    final rawOptions = question['options'];
    if (rawOptions is! List<Object?> || rawOptions.isEmpty) {
      throw const FormatException(
        'question options must be a non-empty array.',
      );
    }
    questions.add(
      UserQuestion(
        id: _requiredString(question, 'id'),
        header: _requiredString(question, 'header'),
        question: _requiredString(question, 'question'),
        options: <UserQuestionOption>[
          for (final rawOption in rawOptions)
            UserQuestionOption(
              label: _requiredString(_object(rawOption), 'label'),
              description: _requiredString(
                _object(rawOption),
                'description',
                allowEmpty: true,
              ),
            ),
        ],
      ),
    );
  }
  final answers = await ports.questions.ask(
    context.callId ?? ports.callId,
    List<UserQuestion>.unmodifiable(questions),
    _PrimitiveCancellationToken(context.cancellation),
  );
  return <String, Object?>{
    'answers': <Map<String, Object?>>[
      for (final answer in answers)
        <String, Object?>{
          'question_id': answer.questionId,
          'answer': answer.answer,
          'free_form': answer.isFreeForm,
        },
    ],
  };
}

List<HostPrimitive<Object?, Object?>> _luaCodeModePrimitives(
  BuiltInHostPrimitivePorts ports,
) => <HostPrimitive<Object?, Object?>>[
  HostPrimitiveContracts.luaStart
      .bindOutput(
        decode: _object,
        invoke: (arguments, context) async {
          final source = _requiredString(arguments, 'source');
          if (utf8.encode(source).length > 256 * 1024) {
            throw _failure(
              'input_too_large',
              'Lua source exceeds the 256 KiB host limit.',
            );
          }
          final toolIds = _stringList(arguments, 'tools');
          final tools = ports.selectedTools!.definitionsFor(toolIds);
          final nestedTools = _CellSelectedLuaToolInvoker(
            ports.selectedTools!,
            <String>{for (final tool in tools) tool.name},
          );
          final chunk = await ports.luaCodeMode!.execute(
            LuaExecuteRequest(
              source: source,
              yieldTime: _luaYieldTime(arguments['yield_time_ms']),
              maxOutputTokens: _luaOutputTokens(arguments['max_output_tokens']),
              tools: tools,
            ),
            LuaCodeModeContext(
              cancellation: _PrimitiveCancellationToken(context.cancellation),
              tools: nestedTools,
            ),
          );
          return _luaChunkOutput(chunk);
        },
      )
      .erased,
  HostPrimitiveContracts.luaRead
      .bindOutput(
        decode: _object,
        invoke: (arguments, context) =>
            _waitLuaCodeMode(ports, arguments, context, terminate: false),
      )
      .erased,
  HostPrimitiveContracts.luaTerminate
      .bindOutput(
        decode: _object,
        invoke: (arguments, context) =>
            _waitLuaCodeMode(ports, arguments, context, terminate: true),
      )
      .erased,
];

Future<HostPrimitiveOutput<Object?>> _waitLuaCodeMode(
  BuiltInHostPrimitivePorts ports,
  Map<String, Object?> arguments,
  HostPrimitiveContext context, {
  required bool terminate,
}) async {
  final chunk = await ports.luaCodeMode!.wait(
    LuaWaitRequest(
      cellId: _requiredString(arguments, 'handle'),
      yieldTime: _luaYieldTime(arguments['yield_time_ms']),
      maxOutputTokens: _luaOutputTokens(arguments['max_output_tokens']),
      terminate: terminate,
    ),
    LuaCodeModeContext(
      cancellation: _PrimitiveCancellationToken(context.cancellation),
      tools: ports.selectedTools!,
    ),
  );
  return _luaChunkOutput(chunk);
}

HostPrimitiveOutput<Object?> _luaChunkOutput(LuaCellChunk chunk) {
  final resources = <ConversationAttachment>[
    ...chunk.attachments,
    for (final image in chunk.contextImages)
      if (!chunk.attachments.any((attachment) => attachment.id == image.id))
        image,
  ];
  return HostPrimitiveOutput<Object?>(
    value: <String, Object?>{
      'handle': chunk.cellId,
      'output': chunk.output,
      'running': chunk.running,
      'terminated': chunk.terminated,
      if (chunk.error != null) 'error': chunk.error,
    },
    resources: <HostPrimitiveResource>[
      for (final attachment in resources)
        HostPrimitiveResource(
          value: attachment,
          fileName: attachment.fileName,
          mimeType: attachment.mimeType,
          byteSize: attachment.byteSize,
        ),
    ],
    notifications: chunk.notifications,
  );
}

Duration _luaYieldTime(Object? value) =>
    Duration(milliseconds: value is int ? value.clamp(100, 60000) : 10000);

int _luaOutputTokens(Object? value) =>
    value is int ? value.clamp(256, 100000) : 10000;

final class _CellSelectedLuaToolInvoker implements LuaNestedToolInvoker {
  const new(this._delegate, this._allowedNames);

  final LuaNestedToolInvoker _delegate;
  final Set<String> _allowedNames;

  @override
  Future<LuaNestedToolResult> invoke(
    String name,
    Map<String, dynamic> arguments,
  ) {
    if (!_allowedNames.contains(name)) {
      return Future<LuaNestedToolResult>.value(
        LuaNestedToolResult(
          value: 'Tool is outside this Lua cell surface: $name',
          isError: true,
        ),
      );
    }
    return _delegate.invoke(name, arguments);
  }
}

List<HostPrimitive<Object?, Object?>> _collaborationPrimitives(
  BuiltInHostPrimitivePorts ports,
) => <HostPrimitive<Object?, Object?>>[
  HostPrimitiveContracts.collaborationSpawnAgent
      .bind(
        decode: _object,
        invoke: (arguments, _) async {
          final path = await _collaborationCall(
            () => ports.collaboration!.spawn(
              caller: ports.session,
              callerDefinition: ports.definition,
              turnId: ports.callId,
              taskName: _requiredString(arguments, 'task_name'),
              message: _requiredString(arguments, 'message'),
              agentType: _optionalString(arguments, 'agent_type'),
              forkTurns: _optionalString(arguments, 'fork_turns') ?? 'all',
              model: _optionalString(arguments, 'model'),
              reasoningEffort: _optionalString(arguments, 'reasoning_effort'),
              serviceTier: _optionalString(arguments, 'service_tier'),
            ),
          );
          return <String, Object?>{'task_name': path};
        },
      )
      .erased,
  HostPrimitiveContracts.collaborationSendMessage
      .bind(
        decode: _object,
        invoke: (arguments, _) async {
          await _collaborationCall(
            () => ports.collaboration!.sendMessage(
              caller: ports.session,
              target: _requiredString(arguments, 'target'),
              message: _requiredString(arguments, 'message'),
            ),
          );
          return const <String, Object?>{'queued': true};
        },
      )
      .erased,
  HostPrimitiveContracts.collaborationFollowupTask
      .bind(
        decode: _object,
        invoke: (arguments, _) async {
          final triggered = await _collaborationCall(
            () => ports.collaboration!.followupTask(
              caller: ports.session,
              target: _requiredString(arguments, 'target'),
              message: _requiredString(arguments, 'message'),
            ),
          );
          return <String, Object?>{
            'delivery': triggered ? 'triggered' : 'queued',
          };
        },
      )
      .erased,
  HostPrimitiveContracts.collaborationWaitAgent
      .bind(
        decode: _object,
        invoke: (arguments, context) async {
          final result = await _collaborationCall(
            () => ports.collaboration!.waitAgent(
              caller: ports.session,
              cancellation: _PrimitiveCancellationToken(context.cancellation),
              timeoutMs: _optionalInt(arguments, 'timeout_ms'),
            ),
          );
          return <String, Object?>{
            'outcome': result.outcome.name,
            'timed_out': result.timedOut,
            // The mail the wait ended on, so the caller can act on it in the
            // turn it waited in. Fields only; the extension owns the wording
            // it presents them to the model in.
            'messages': <Map<String, Object?>>[
              for (final message in result.messages)
                <String, Object?>{
                  'type': _interAgentMessageWireName(message.type),
                  'sender': message.senderPath,
                  'payload': message.payload,
                },
            ],
          };
        },
      )
      .erased,
  HostPrimitiveContracts.collaborationInterruptAgent
      .bind(
        decode: _object,
        invoke: (arguments, _) async {
          final lifecycle = await _collaborationCall(
            () => ports.collaboration!.interruptAgent(
              caller: ports.session,
              target: _requiredString(arguments, 'target'),
            ),
          );
          return <String, Object?>{
            'previous_status': _agentLifecycleWireName(lifecycle),
          };
        },
      )
      .erased,
  collaborationListAgentsHostPrimitive(
    session: (_) => ports.session,
    service: () => ports.collaboration,
  ),
];

/// Creates the shared typed primitive used by turn and declarative UI hosts.
///
/// The resolvers keep caller/session lookup in the composition root while this
/// primitive remains the single owner of validation, error classification, and
/// wire output for `host.collaboration.list_agents`.
HostPrimitive<Object?, Object?> collaborationListAgentsHostPrimitive({
  required FutureOr<SessionDto?> Function(HostPrimitiveContext context) session,
  required MultiAgentService? Function() service,
}) => HostPrimitiveContracts.collaborationListAgents
    .bind(
      decode: _object,
      invoke: (arguments, context) async {
        final caller = await session(context);
        final collaboration = service();
        if (caller == null || collaboration == null) {
          throw const HostPrimitiveException(
            HostPrimitiveError(
              code: 'collaboration_unavailable',
              message: 'Collaboration session is unavailable.',
              retryable: false,
            ),
          );
        }
        final agents = await _collaborationCall(
          () => collaboration.listAgents(
            caller: caller,
            pathPrefix: _optionalString(arguments, 'path_prefix'),
          ),
        );
        return <String, Object?>{
          'agents': <Map<String, Object?>>[
            for (final agent in agents)
              <String, Object?>{
                'session_id': agent.sessionId,
                'agent_name': agent.agentName,
                'agent_status': _agentLifecycleWireName(agent.agentStatus),
                'session_status': _sessionStatusWireName(agent.sessionStatus),
                'title': agent.title,
                'task_name': ?agent.taskName,
                'parent_session_id': ?agent.parentSessionId,
              },
          ],
        };
      },
    )
    .erased;

List<HostPrimitive<Object?, Object?>> _mcpPrimitives(
  McpHostPrimitiveGateway gateway,
) => <HostPrimitive<Object?, Object?>>[
  HostPrimitiveContracts.mcpListResources
      .bind(
        decode: _object,
        invoke: (arguments, _) => gateway.listResources(arguments),
      )
      .erased,
  HostPrimitiveContracts.mcpListResourceTemplates
      .bind(
        decode: _object,
        invoke: (arguments, _) => gateway.listResourceTemplates(arguments),
      )
      .erased,
  HostPrimitiveContracts.mcpReadResource
      .bind(
        decode: _object,
        invoke: (arguments, _) => gateway.readResource(arguments),
      )
      .erased,
  HostPrimitiveContracts.mcpCatalogTools
      .bind(
        decode: _object,
        invoke: (arguments, _) => gateway.catalogTools(arguments),
      )
      .erased,
  HostPrimitiveContracts.mcpInvokeTool
      .bind(
        decode: _object,
        invoke: (arguments, context) =>
            gateway.invokeTool(arguments, cancellation: context.cancellation),
      )
      .erased,
];

Future<T> _collaborationCall<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on CollaborationException catch (error) {
    throw HostPrimitiveException(
      HostPrimitiveError(
        code: 'collaboration_error',
        message: error.message,
        retryable: false,
      ),
    );
  }
}

String _interAgentMessageWireName(InterAgentMessageType type) => switch (type) {
  InterAgentMessageType.message => 'message',
  InterAgentMessageType.newTask => 'new_task',
  InterAgentMessageType.finalAnswer => 'final_answer',
};

String _agentLifecycleWireName(AgentLifecycle lifecycle) => switch (lifecycle) {
  AgentLifecycle.pendingInit => 'pending_init',
  AgentLifecycle.running => 'running',
  AgentLifecycle.interrupted => 'interrupted',
  AgentLifecycle.completed => 'completed',
  AgentLifecycle.errored => 'errored',
};

String _sessionStatusWireName(SessionStatus status) => switch (status) {
  SessionStatus.initializing => 'initializing',
  SessionStatus.idle => 'idle',
  SessionStatus.running => 'running',
  SessionStatus.waitingForApproval => 'waiting_for_approval',
  SessionStatus.waitingForInput => 'waiting_for_input',
  SessionStatus.failed => 'failed',
  SessionStatus.closed => 'closed',
};

final class _PrimitiveCancellationToken extends CancellationToken {
  new(HostPrimitiveCancellation? source) {
    if (source?.isCancelled ?? false) cancel();
    source?.onCancel(cancel);
  }
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map<Object?, Object?>) {
    throw const FormatException('Expected an object.');
  }
  return <String, Object?>{
    for (final entry in value.entries)
      if (entry.key is String) entry.key! as String: entry.value,
  };
}

String _requiredString(
  Map<String, Object?> arguments,
  String key, {
  bool allowEmpty = false,
}) {
  final value = arguments[key];
  if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
    throw FormatException(
      '$key must be a ${allowEmpty ? '' : 'non-empty '}string.',
    );
  }
  return value;
}

String? _optionalString(Map<String, Object?> arguments, String key) {
  final value = arguments[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('$key must be a string.');
  return value;
}

int _requiredInt(Map<String, Object?> arguments, String key) {
  final value = arguments[key];
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

int? _optionalInt(Map<String, Object?> arguments, String key) {
  final value = arguments[key];
  if (value == null) return null;
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

List<String> _stringList(Map<String, Object?> arguments, String key) {
  final value = arguments[key];
  if (value == null) return const <String>[];
  if (value is! List<Object?> || value.any((entry) => entry is! String)) {
    throw FormatException('$key must be an array of strings.');
  }
  final result = value.cast<String>();
  if (result.toSet().length != result.length) {
    throw FormatException('$key must not contain duplicate entries.');
  }
  return List<String>.unmodifiable(result);
}

String _entityType(file_api.FileSystemEntityType type) => switch (type) {
  file_api.FileSystemEntityType.file => 'file',
  file_api.FileSystemEntityType.directory => 'directory',
  file_api.FileSystemEntityType.link => 'link',
  _ => 'other',
};

String _imageMimeType(String path, List<int> bytes) {
  final extension = path.toLowerCase();
  if (extension.endsWith('.png')) return 'image/png';
  if (extension.endsWith('.jpg') || extension.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (extension.endsWith('.webp')) return 'image/webp';
  if (extension.endsWith('.gif')) return 'image/gif';
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  throw _failure('unsupported_media_type', 'Workspace blob is not an image.');
}

void _checkCancelled(HostPrimitiveContext context) {
  if (context.cancellation?.isCancelled ?? false) {
    throw _failure('cancelled', 'Host primitive invocation was cancelled.');
  }
}

HostPrimitiveException _failure(String code, String message) =>
    HostPrimitiveException(
      HostPrimitiveError(code: code, message: message, retryable: false),
    );
