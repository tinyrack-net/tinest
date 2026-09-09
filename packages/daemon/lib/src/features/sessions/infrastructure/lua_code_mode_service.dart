import 'dart:convert';
import 'dart:io';

import 'package:agent/agent.dart';
import 'package:crypto/crypto.dart';
import 'package:lua_tool_runtime/lua_tool_runtime.dart' as lua;
import 'package:path/path.dart' as p;

/// Runs one process while locating the native build toolchain.
typedef LuaHostLocatorProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// Stages the pinned native Lua distribution for a development checkout.
abstract interface class LuaHostDistributionStager {
  /// Builds and copies one immutable distribution into [destination].
  Future<lua.LuaHostDistribution> stage({
    required String destination,
    required String packageRoot,
    required String buildDirectory,
  });
}

/// Production adapter for the upstream offline native-host stager.
final class NativeLuaHostDistributionStager
    implements LuaHostDistributionStager {
  /// Creates the native stager.
  const new({this.cmakeExecutable = _resolveCmakeExecutable});

  /// Resolves CMake without assuming it is on PATH.
  final Future<String> Function() cmakeExecutable;

  @override
  Future<lua.LuaHostDistribution> stage({
    required String destination,
    required String packageRoot,
    required String buildDirectory,
  }) async => await lua.stageLuaToolRuntime(
    destination: destination,
    packageRoot: packageRoot,
    buildDirectory: buildDirectory,
    cmakeExecutable: await cmakeExecutable(),
  );
}

/// Resolves the packaged Lua 5.5 host or stages the pinned dependency source.
///
/// Development never falls back to an arbitrary `lua` executable on PATH:
/// plugin execution must use the same vendored runtime as production.
Future<lua.LuaHostCommand> resolveLuaHostCommand({
  required String sourceRoot,
  String? resolvedExecutable,
  bool? isMacOS,
  LuaHostDistributionStager stager = const NativeLuaHostDistributionStager(),
}) async {
  final executableDirectory = p.dirname(
    resolvedExecutable ?? Platform.resolvedExecutable,
  );
  final packaged = lua.LuaHostCommand.fromDirectory(executableDirectory);
  if (File(packaged.executable).existsSync() &&
      File(packaged.arguments.single).existsSync()) {
    return packaged;
  }
  if (isMacOS ?? Platform.isMacOS) {
    final resourceBootstrap = p.normalize(
      p.join(
        executableDirectory,
        '..',
        'Resources',
        'lua_tool_runtime',
        'bootstrap.lua',
      ),
    );
    if (File(packaged.executable).existsSync() &&
        File(resourceBootstrap).existsSync()) {
      return lua.LuaHostCommand(
        executable: packaged.executable,
        arguments: <String>[resourceBootstrap],
      );
    }
  }

  var directory = Directory(p.normalize(p.absolute(sourceRoot)));
  while (true) {
    final packageConfig = File(
      p.join(directory.path, '.dart_tool', 'package_config.json'),
    );
    if (packageConfig.existsSync()) {
      final decoded = jsonDecode(packageConfig.readAsStringSync());
      if (decoded case {'packages': final List<dynamic> packages}) {
        for (final rawPackage in packages) {
          if (rawPackage case <String, dynamic>{
            'name': 'lua_tool_runtime',
            'rootUri': final String rootUri,
          }) {
            final root = packageConfig.parent.uri.resolve(rootUri).toFilePath();
            final bootstrap = p.join(root, 'native', 'bootstrap.lua');
            if (File(bootstrap).existsSync()) {
              return await _stageDevelopmentLuaHost(
                workspaceRoot: packageConfig.parent.parent.path,
                packageRoot: root,
                stager: stager,
              );
            }
          }
        }
      }
    }
    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  throw StateError(
    'lua-tool-runtime-host and its bootstrap could not be located next to '
    '${resolvedExecutable ?? Platform.resolvedExecutable}.',
  );
}

Future<lua.LuaHostCommand> _stageDevelopmentLuaHost({
  required String workspaceRoot,
  required String packageRoot,
  required LuaHostDistributionStager stager,
}) async {
  final source = p.basename(
    p.dirname(p.dirname(p.normalize(p.absolute(packageRoot)))),
  );
  final identity = source.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');
  final root = p.join(
    workspaceRoot,
    '.dart_tool',
    'tinest',
    'lua_tool_runtime',
    identity.isEmpty ? 'pinned' : identity,
    Platform.operatingSystem,
  );
  final command = lua.LuaHostCommand.fromDirectory(root);
  if (_isCompleteHost(command)) return command;

  final inProgress = _developmentLuaHostStages[root];
  if (inProgress != null) return await inProgress;
  final stage = _stageDevelopmentLuaHostWithFileLock(
    root: root,
    packageRoot: packageRoot,
    stager: stager,
  );
  _developmentLuaHostStages[root] = stage;
  try {
    return await stage;
  } finally {
    if (identical(_developmentLuaHostStages[root], stage)) {
      final _ = _developmentLuaHostStages.remove(root);
    }
  }
}

final Map<String, Future<lua.LuaHostCommand>> _developmentLuaHostStages =
    <String, Future<lua.LuaHostCommand>>{};

Future<lua.LuaHostCommand> _stageDevelopmentLuaHostWithFileLock({
  required String root,
  required String packageRoot,
  required LuaHostDistributionStager stager,
}) async {
  final command = lua.LuaHostCommand.fromDirectory(root);

  final lock = File('$root.lock')..parent.createSync(recursive: true);
  final handle = lock.openSync(mode: FileMode.append);
  var locked = false;
  try {
    await _acquireStagingLock(handle);
    locked = true;
    if (_isCompleteHost(command)) return command;
    await _deleteIncompleteCache(root);
    final build = await Directory.systemTemp.createTemp(
      'tinest-lua-${_shortIdentity(packageRoot)}-',
    );
    final staging = await Directory(p.dirname(root))
        .createTemp('${p.basename(root)}.staging-');
    var promoted = false;
    try {
      final distribution = await stager.stage(
        destination: staging.path,
        packageRoot: packageRoot,
        buildDirectory: build.path,
      );
      final staged = lua.LuaHostCommand(
        executable: distribution.hostPath,
        arguments: <String>[distribution.bootstrapPath],
      );
      if (!_isCompleteHost(staged)) {
        throw StateError('The pinned Lua host staging output is incomplete.');
      }
      final hostPath = _relativeStagedPath(staging.path, distribution.hostPath);
      final bootstrapPath = _relativeStagedPath(
        staging.path,
        distribution.bootstrapPath,
      );
      // Promotion is a race that more than one caller can enter. Neither guard
      // above closes it: `_developmentLuaHostStages` is top-level state, so
      // every isolate holds its own, and a POSIX lock belongs to the process,
      // so isolates of one process never exclude each other -- which is exactly
      // what `dart test` runs suites as. Renaming onto a directory another
      // caller already promoted fails with ENOTEMPTY.
      //
      // Losing that race is not an error: the cache the winner left is the same
      // pinned distribution this caller just built, so adopt it.
      try {
        await staging.rename(root);
      } on FileSystemException {
        final winner = lua.LuaHostCommand.fromDirectory(root);
        if (!_isCompleteHost(winner)) rethrow;
        return winner;
      }
      final cached = lua.LuaHostCommand(
        executable: p.join(root, hostPath),
        arguments: <String>[p.join(root, bootstrapPath)],
      );
      if (!_isCompleteHost(cached)) {
        await _deleteIncompleteCache(root);
        throw StateError('The pinned Lua host cache promotion was incomplete.');
      }
      promoted = true;
      return cached;
    } finally {
      if (build.existsSync()) await build.delete(recursive: true);
      if (!promoted && staging.existsSync()) {
        await staging.delete(recursive: true);
      }
    }
  } finally {
    if (locked) await handle.unlock();
    await handle.close();
  }
}

Future<void> _acquireStagingLock(RandomAccessFile handle) async {
  while (true) {
    try {
      await handle.lock();
      return;
    } on FileSystemException catch (error) {
      final code = error.osError?.errorCode;
      final lockIsBusy = Platform.isWindows && (code == 32 || code == 33);
      if (!lockIsBusy) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }
}

Future<void> _deleteIncompleteCache(String path) async {
  switch (FileSystemEntity.typeSync(path, followLinks: false)) {
    case FileSystemEntityType.notFound:
      return;
    case FileSystemEntityType.directory:
      await Directory(path).delete(recursive: true);
    case FileSystemEntityType.file:
      await File(path).delete();
    case FileSystemEntityType.link:
      await Link(path).delete();
    case FileSystemEntityType.pipe:
      throw StateError('The pinned Lua host cache path is not a directory.');
    case FileSystemEntityType.unixDomainSock:
      throw StateError('The pinned Lua host cache path is not a directory.');
  }
}

String _relativeStagedPath(String stagingRoot, String value) {
  final root = p.normalize(p.absolute(stagingRoot));
  final path = p.normalize(p.absolute(value));
  if (!p.isWithin(root, path)) {
    throw StateError(
      'The pinned Lua host stager returned a path outside cache.',
    );
  }
  return p.relative(path, from: root);
}

bool _isCompleteHost(lua.LuaHostCommand command) =>
    File(command.executable).existsSync() &&
    command.arguments.length == 1 &&
    File(command.arguments.single).existsSync();

String _shortIdentity(String value) {
  final digest = sha256.convert(utf8.encode(p.normalize(p.absolute(value))));
  return digest.toString().substring(0, 16);
}

Future<String> _resolveCmakeExecutable() => resolveLuaHostCmakeExecutable();

/// Locates CMake for the pinned native Lua build.
///
/// The injected environment and process runner keep discovery deterministic in
/// tests and allow callers to supply an equivalent host integration.
Future<String> resolveLuaHostCmakeExecutable({
  bool? isWindows,
  Map<String, String>? environment,
  LuaHostLocatorProcessRunner processRunner = _runLocatorProcess,
}) async {
  if (!(isWindows ?? Platform.isWindows)) return 'cmake';
  final onPath = await processRunner('where.exe', const <String>['cmake']);
  if (onPath.exitCode == 0) {
    final candidates = _processOutputLines(onPath.stdout);
    if (candidates.isNotEmpty) return candidates.first;
  }
  final programFilesX86 =
      (environment ?? Platform.environment)['ProgramFiles(x86)'];
  if (programFilesX86 != null) {
    final vswhere = File(
      p.join(
        programFilesX86,
        'Microsoft Visual Studio',
        'Installer',
        'vswhere.exe',
      ),
    );
    if (vswhere.existsSync()) {
      final result = await processRunner(vswhere.path, const <String>[
        '-latest',
        '-products',
        '*',
        '-requires',
        'Microsoft.VisualStudio.Component.VC.CMake.Project',
        '-find',
        r'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe',
      ]);
      final candidates = _processOutputLines(result.stdout);
      if (result.exitCode == 0 && candidates.isNotEmpty) {
        return candidates.first;
      }
    }
  }
  return 'cmake';
}

Future<ProcessResult> _runLocatorProcess(
  String executable,
  List<String> arguments,
) => Process.run(executable, arguments);

List<String> _processOutputLines(Object? output) => output is String
    ? output
          .split(RegExp(r'[\r\n]+'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(growable: false)
    : const <String>[];

/// Adapts Tinest's tool and attachment contracts to the shared Lua runtime.
final class LuaCodeModeService {
  /// Creates a service over the process runtime supplied by the composition
  /// root.
  new(this._runtime);

  final lua.LuaToolRuntime<ConversationAttachment> _runtime;
  final Map<String, lua.LuaRuntimeSession<ConversationAttachment>> _sessions =
      <String, lua.LuaRuntimeSession<ConversationAttachment>>{};
  final Map<String, Map<String, LuaNestedToolInvoker>> _cellTools =
      <String, Map<String, LuaNestedToolInvoker>>{};

  lua.LuaRuntimeSession<ConversationAttachment> _session(String owner) =>
      _sessions.putIfAbsent(owner, _runtime.createSession);

  /// Starts one fresh VM and returns its first output delta.
  Future<LuaCellChunk> execute({
    required String owner,
    required String workingDirectory,
    required LuaExecuteRequest request,
    required LuaCodeModeContext context,
  }) async {
    final chunk = _mapDelta(
      await _session(owner).execute(
        lua.LuaExecuteRequest(
          source: request.source,
          yieldTime: request.yieldTime,
          maxOutputTokens: request.maxOutputTokens,
          tools: <lua.LuaToolDefinition>[
            for (final tool in request.tools)
              lua.LuaToolDefinition(
                name: tool.name,
                description: tool.description,
                kind: tool.kind,
                namespace: tool.namespace,
                exposure: tool.exposure,
                inputSchema: tool.inputSchema,
                outputSchema: tool.outputSchema,
              ),
          ],
        ),
        _executionContext(context),
        workingDirectory: workingDirectory,
      ),
    );
    if (chunk.running) {
      _cellTools.putIfAbsent(
        owner,
        () => <String, LuaNestedToolInvoker>{},
      )[chunk.cellId] = context.tools;
    } else {
      _cellTools[owner]?.remove(chunk.cellId);
    }
    return chunk;
  }

  /// Resumes, observes, or terminates a session-owned cell.
  Future<LuaCellChunk> wait({
    required String owner,
    required LuaWaitRequest request,
    required LuaCodeModeContext context,
  }) async {
    final session = _sessions[owner];
    if (session == null) {
      return LuaCellChunk(
        cellId: request.cellId,
        output: '',
        error: 'Lua cell not found.',
      );
    }
    final tools = _cellTools[owner]?[request.cellId] ?? context.tools;
    final chunk = _mapDelta(
      await session.wait(
        lua.LuaWaitRequest(
          cellId: request.cellId,
          yieldTime: request.yieldTime,
          maxOutputTokens: request.maxOutputTokens,
          terminate: request.terminate,
        ),
        _executionContext(
          LuaCodeModeContext(cancellation: context.cancellation, tools: tools),
        ),
      ),
    );
    if (!chunk.running || request.terminate) {
      _cellTools[owner]?.remove(request.cellId);
    }
    return chunk;
  }

  lua.LuaExecutionContext<ConversationAttachment> _executionContext(
    LuaCodeModeContext context,
  ) => lua.LuaExecutionContext<ConversationAttachment>(
    dispatcher: _TinestLuaToolDispatcher(context),
    cancellation: _TinestLuaCancellation(context.cancellation),
  );

  LuaCellChunk _mapDelta(lua.LuaCellDelta<ConversationAttachment> delta) {
    var error = delta.error?.message;
    final contextImages = <ConversationAttachment>[];
    for (final resource in delta.emittedResources) {
      if (resource.mimeType.startsWith('image/')) {
        contextImages.add(resource.value);
      } else {
        error ??= resource.mimeType.startsWith('audio/')
            ? 'Audio output is not supported by the current provider bridge.'
            : 'Media handle ${resource.fileName} is not an image.';
      }
    }
    return LuaCellChunk(
      cellId: delta.cellId,
      output: delta.output,
      running: delta.running,
      terminated: delta.terminated,
      error: error,
      attachments: <ConversationAttachment>[
        for (final resource in delta.resources) resource.value,
      ],
      contextImages: contextImages,
      notifications: delta.notifications,
    );
  }

  /// Reclaims expired and over-time cells.
  void sweep() => _runtime.sweep();

  /// Terminates all cells owned by one Tinest session.
  Future<void> closeOwner(String owner) async {
    final session = _sessions.remove(owner);
    _cellTools.remove(owner);
    if (session != null) await session.close();
  }

  /// Terminates every helper process.
  Future<void> close() async {
    _sessions.clear();
    _cellTools.clear();
    await _runtime.close();
  }
}

/// Session-scoped view that prevents cross-session cell access.
final class SessionLuaCodeModeHost implements LuaCodeModeHost {
  /// Creates the scoped host.
  const new(this._service, this._sessionId, this._workingDirectory);

  final LuaCodeModeService _service;
  final String _sessionId;
  final String _workingDirectory;

  @override
  Future<LuaCellChunk> execute(
    LuaExecuteRequest request,
    LuaCodeModeContext context,
  ) => _service.execute(
    owner: _sessionId,
    workingDirectory: _workingDirectory,
    request: request,
    context: context,
  );

  @override
  Future<LuaCellChunk> wait(
    LuaWaitRequest request,
    LuaCodeModeContext context,
  ) => _service.wait(owner: _sessionId, request: request, context: context);
}

final class _TinestLuaToolDispatcher
    implements lua.LuaToolDispatcher<ConversationAttachment> {
  const new(this._context);

  final LuaCodeModeContext _context;

  @override
  Future<lua.LuaToolResult<ConversationAttachment>> invoke(
    lua.LuaToolInvocation invocation,
  ) async {
    final result = await _context.tools.invoke(
      invocation.name,
      Map<String, dynamic>.from(invocation.arguments),
    );
    final attachments = <ConversationAttachment>[
      ...result.attachments,
      ...result.contextImages,
    ];
    return lua.LuaToolResult<ConversationAttachment>(
      value: result.value,
      isError: result.isError,
      resources: <lua.LuaOpaqueResource<ConversationAttachment>>[
        for (final attachment in attachments)
          lua.LuaOpaqueResource<ConversationAttachment>(
            value: attachment,
            fileName: attachment.fileName,
            mimeType: attachment.mimeType,
            byteSize: attachment.byteSize,
          ),
      ],
      content: <Map<String, Object?>>[
        for (final block in result.content) block,
      ],
      structuredContent: result.structuredContent,
      meta: result.meta,
    );
  }
}

final class _TinestLuaCancellation implements lua.LuaCancellationSignal {
  const new(this._token);

  final CancellationToken _token;

  @override
  void onCancel(void Function() callback) => _token.onCancel(callback);
}
