import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:daemon/src/features/plugins/runtime/plugin_type_environment.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:path/path.dart' as p;
import 'package:protocol/protocol.dart';

/// Immutable SDK metadata and LuaCATS files supplied by the runtime SDK.
abstract interface class PluginSdkAuthoringProvider {
  /// Public plugin API major.
  int get apiMajor;

  /// Exact ABI hash shared by runtime and editor definitions.
  String get sdkAbiHash;

  /// Lua runtime implemented by the native host.
  String get luaRuntimeVersion;

  /// LuaLS release used by conformance tests.
  String get luaLanguageServerVersion;

  /// UTF-8 authoring files relative to the content-addressed SDK root.
  Map<String, String> get authoringLibraryAssets;
}

/// Owns editor-only Lua SDK files beneath the daemon config directory.
final class PluginAuthoringEnvironmentService {
  /// Creates the service over one explicit config root and SDK provider.
  new({required String configDirectory, required this.sdk, required this._ids})
    : _configRoot = p.normalize(p.absolute(configDirectory));

  final String _configRoot;
  final IdGenerator _ids;
  Future<void> _syncTail = Future<void>.value();

  /// Runtime-owned canonical SDK assets.
  final PluginSdkAuthoringProvider sdk;

  /// Reads synchronization state without mutating files.
  Future<PluginAuthoringEnvironmentDto> get(String pluginId) async {
    final paths = _paths(pluginId);
    final diagnostics = <PluginDiagnosticDto>[];
    final types = await _typeEnvironment(paths, diagnostics);
    final sdkExpected = _sdkFiles();
    if (!paths.sdkRoot.existsSync()) {
      diagnostics.add(
        PluginDiagnosticDto(
          code: 'plugin_sdk_missing',
          message: 'The exact plugin SDK ABI is not installed.',
          severity: PluginDiagnosticSeverity.warning,
          path: paths.sdkRoot.path,
        ),
      );
    } else if (!await _directoryMatches(paths.sdkRoot, sdkExpected)) {
      diagnostics.add(
        PluginDiagnosticDto(
          code: 'plugin_sdk_out_of_sync',
          message: 'The installed plugin SDK does not match its ABI.',
          severity: PluginDiagnosticSeverity.warning,
          path: paths.sdkRoot.path,
        ),
      );
    }
    final configuration = File(paths.configurationPath);
    if (!configuration.existsSync()) {
      diagnostics.add(
        PluginDiagnosticDto(
          code: 'luarc_missing',
          message: 'The LuaLS workspace configuration is missing.',
          severity: PluginDiagnosticSeverity.info,
          path: configuration.path,
        ),
      );
    } else if (await configuration.readAsString() != _luarc(paths)) {
      diagnostics.add(
        PluginDiagnosticDto(
          code: 'luarc_out_of_sync',
          message: 'The LuaLS workspace configuration uses another SDK ABI.',
          severity: PluginDiagnosticSeverity.warning,
          path: configuration.path,
        ),
      );
    }
    final definition = File(paths.typesDefinitionPath);
    if (!definition.existsSync()) {
      diagnostics.add(
        PluginDiagnosticDto(
          code: 'plugin_types_missing',
          message: 'The generated LuaLS plugin types are missing.',
          severity: PluginDiagnosticSeverity.info,
          path: definition.path,
        ),
      );
    } else if (await definition.readAsString() != types.authoringDefinition) {
      diagnostics.add(
        PluginDiagnosticDto(
          code: 'plugin_types_out_of_sync',
          message: 'The generated LuaLS plugin types are stale.',
          severity: PluginDiagnosticSeverity.warning,
          path: definition.path,
        ),
      );
    }
    return _dto(paths, diagnostics);
  }

  /// Atomically replaces the SDK ABI directory and plugin `.luarc.json`.
  Future<PluginAuthoringEnvironmentDto> sync(String pluginId) async {
    final previous = _syncTail;
    final release = Completer<void>();
    _syncTail = release.future;
    await previous;
    try {
      return await _sync(pluginId);
    } finally {
      release.complete();
    }
  }

  Future<PluginAuthoringEnvironmentDto> _sync(String pluginId) async {
    final paths = _paths(pluginId);
    final diagnostics = <PluginDiagnosticDto>[];
    final types = await _typeEnvironment(paths, diagnostics);
    final sdkFiles = _sdkFiles();
    final temporaryId = _temporaryId();
    if (!await _directoryMatches(paths.sdkRoot, sdkFiles)) {
      await _replaceDirectory(
        paths.sdkRoot,
        sdkFiles,
        temporaryId: temporaryId,
      );
    }
    await _writeAtomic(
      File(paths.typesDefinitionPath),
      utf8.encode(types.authoringDefinition),
      temporaryId: temporaryId,
    );
    await _writeAtomic(
      File(paths.configurationPath),
      utf8.encode(_luarc(paths)),
      temporaryId: temporaryId,
    );
    return _dto(paths, diagnostics);
  }

  String _temporaryId() {
    final id = _ids.generate();
    if (!RegExp(r'^[A-Za-z0-9-]+$').hasMatch(id)) {
      throw const PluginAuthoringException(
        'The plugin authoring temporary ID is invalid.',
      );
    }
    return id;
  }

  ({
    Directory pluginRoot,
    Directory sdkRoot,
    String libraryPath,
    String authoringLibraryPath,
    String typesDefinitionPath,
    String configurationPath,
  })
  _paths(String pluginId) {
    _validatePluginId(pluginId);
    final pluginsRoot = Directory(p.join(_configRoot, 'v5', 'plugins'));
    final pluginRoot = Directory(p.join(pluginsRoot.path, pluginId));
    if (FileSystemEntity.typeSync(pluginRoot.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw PluginAuthoringException('Plugin is not installed: $pluginId');
    }
    final resolved = p.normalize(pluginRoot.resolveSymbolicLinksSync());
    final resolvedParent = p.normalize(
      pluginsRoot.existsSync()
          ? pluginsRoot.resolveSymbolicLinksSync()
          : pluginsRoot.path,
    );
    final directChild = p.join(resolvedParent, p.basename(pluginRoot.path));
    if (!p.equals(directChild, resolved)) {
      throw PluginAuthoringException(
        'Plugin authoring paths cannot be symlinks or junctions: '
        '${pluginRoot.path} -> $resolved.',
      );
    }
    final sdkAbiRoot = Directory(
      p.join(
        _configRoot,
        'v5',
        'plugin-sdk',
        'api-${sdk.apiMajor}',
        sdk.sdkAbiHash,
      ),
    );
    final authoringLibrary = Directory(
      p.join(sdkAbiRoot.path, 'authoring', pluginId),
    );
    return (
      pluginRoot: pluginRoot,
      sdkRoot: sdkAbiRoot,
      libraryPath: p.join(sdkAbiRoot.path, 'library'),
      authoringLibraryPath: authoringLibrary.path,
      typesDefinitionPath: p.join(
        authoringLibrary.path,
        PluginTypeEnvironmentGenerator.sidecarFileName,
      ),
      configurationPath: p.join(pluginRoot.path, '.luarc.json'),
    );
  }

  Future<PluginTypeEnvironment> _typeEnvironment(
    ({
      Directory pluginRoot,
      Directory sdkRoot,
      String libraryPath,
      String authoringLibraryPath,
      String typesDefinitionPath,
      String configurationPath,
    })
    paths,
    List<PluginDiagnosticDto> diagnostics,
  ) async {
    final sources = <String, String>{};
    final root = p.normalize(paths.pluginRoot.resolveSymbolicLinksSync());
    await for (final entity in paths.pluginRoot.list(
      recursive: true,
      followLinks: false,
    )) {
      final type = FileSystemEntity.typeSync(entity.path, followLinks: false);
      if (type == FileSystemEntityType.link) {
        diagnostics.add(
          PluginDiagnosticDto(
            code: 'plugin_types_unsafe_path',
            message: 'LuaLS type generation ignores symlinks and junctions.',
            severity: PluginDiagnosticSeverity.warning,
            path: entity.path,
          ),
        );
        continue;
      }
      if (type != FileSystemEntityType.file ||
          p.extension(entity.path).toLowerCase() != '.lua') {
        continue;
      }
      final resolved = p.normalize(
        File(entity.path).resolveSymbolicLinksSync(),
      );
      if (!p.isWithin(root, resolved)) {
        diagnostics.add(
          PluginDiagnosticDto(
            code: 'plugin_types_unsafe_path',
            message: 'LuaLS type generation ignores paths outside the plugin.',
            severity: PluginDiagnosticSeverity.warning,
            path: entity.path,
          ),
        );
        continue;
      }
      final relative = p.posix.joinAll(
        p.split(p.relative(entity.path, from: paths.pluginRoot.path)),
      );
      try {
        sources[relative] = utf8.decode(
          await File(entity.path).readAsBytes(),
          allowMalformed: false,
        );
      } on FormatException {
        diagnostics.add(
          PluginDiagnosticDto(
            code: 'plugin_types_invalid_utf8',
            message: 'LuaLS type generation requires UTF-8 Lua source.',
            severity: PluginDiagnosticSeverity.warning,
            path: entity.path,
          ),
        );
      }
    }
    final environment = PluginTypeEnvironmentGenerator.analyze(
      pluginId: p.basename(paths.pluginRoot.path),
      sources: sources,
    );
    diagnostics.addAll(
      environment.diagnostics.map(
        (diagnostic) => PluginDiagnosticDto(
          code: diagnostic.code,
          message: diagnostic.message,
          severity: PluginDiagnosticSeverity.warning,
          path: p.joinAll(<String>[
            paths.pluginRoot.path,
            ...p.posix.split(diagnostic.path),
          ]),
          line: diagnostic.line,
          column: diagnostic.column,
        ),
      ),
    );
    return environment;
  }

  Map<String, List<int>> _sdkFiles() {
    final files = <String, List<int>>{};
    for (final entry in sdk.authoringLibraryAssets.entries) {
      final path = p.posix.normalize(entry.key);
      if (path != entry.key ||
          path.startsWith('../') ||
          path.startsWith('/') ||
          !path.startsWith('library/') ||
          p.posix.extension(path) != '.lua') {
        throw PluginAuthoringException(
          'Invalid SDK authoring asset path: ${entry.key}',
        );
      }
      files[path] = utf8.encode(entry.value);
    }
    if (!files.containsKey('library/tinest.lua')) {
      throw const PluginAuthoringException(
        'The SDK authoring bundle requires library/tinest.lua.',
      );
    }
    final sdkDescription = <String, Object>{
      'apiMajor': sdk.apiMajor,
      'sdkAbiHash': sdk.sdkAbiHash,
      'luaRuntimeVersion': sdk.luaRuntimeVersion,
      'luaLanguageServerVersion': sdk.luaLanguageServerVersion,
    };
    files['sdk.json'] = utf8.encode(
      '${const JsonEncoder.withIndent('  ').convert(sdkDescription)}\n',
    );
    return Map<String, List<int>>.unmodifiable(files);
  }

  PluginAuthoringEnvironmentDto _dto(
    ({
      Directory pluginRoot,
      Directory sdkRoot,
      String libraryPath,
      String authoringLibraryPath,
      String typesDefinitionPath,
      String configurationPath,
    })
    paths,
    List<PluginDiagnosticDto> diagnostics,
  ) => PluginAuthoringEnvironmentDto(
    pluginId: p.basename(paths.pluginRoot.path),
    apiMajor: sdk.apiMajor,
    sdkAbiHash: sdk.sdkAbiHash,
    luaRuntimeVersion: sdk.luaRuntimeVersion,
    luaLanguageServerVersion: sdk.luaLanguageServerVersion,
    pluginPath: paths.pluginRoot.path,
    sdkLibraryPath: paths.libraryPath,
    configurationPath: paths.configurationPath,
    synchronized: diagnostics.every(
      (diagnostic) => _isAuthoringOnlyDiagnostic(diagnostic.code),
    ),
    diagnostics: diagnostics,
  );

  String _luarc(
    ({
      Directory pluginRoot,
      Directory sdkRoot,
      String libraryPath,
      String authoringLibraryPath,
      String typesDefinitionPath,
      String configurationPath,
    })
    paths,
  ) {
    const disabledBuiltins = <String, String>{
      'basic': 'disable',
      'bit': 'disable',
      'bit32': 'disable',
      'coroutine': 'disable',
      'debug': 'disable',
      'ffi': 'disable',
      'io': 'disable',
      'jit': 'disable',
      'os': 'disable',
      'package': 'disable',
      'string.buffer': 'disable',
      'table.clear': 'disable',
      'table.new': 'disable',
    };
    final configuration = <String, Object>{
      r'$schema':
          'https://raw.githubusercontent.com/LuaLS/vscode-lua/master/'
          'setting/schema.json',
      'runtime.version': 'Lua 5.5',
      'runtime.path': <String>['?.lua', '?/init.lua'],
      'runtime.pathStrict': true,
      'runtime.builtin': disabledBuiltins,
      'workspace.library': <String>[
        paths.libraryPath,
        paths.authoringLibraryPath,
      ],
      'workspace.checkThirdParty': 'Disable',
      'diagnostics.globals': <String>[],
      'type.checkTableShape': true,
    };
    return '${const JsonEncoder.withIndent('  ').convert(configuration)}\n';
  }
}

bool _isAuthoringOnlyDiagnostic(String code) =>
    code == 'plugin_types_parse' ||
    code == 'plugin_type_unprojected' ||
    code == 'plugin_type_dynamic_reference';

/// Expected plugin-authoring setup failure.
final class PluginAuthoringException implements Exception {
  /// Creates an authoring failure suitable for RPC error mapping.
  const new(this.message);

  /// User-safe failure detail.
  final String message;

  @override
  String toString() => 'PluginAuthoringException: $message';
}

Future<bool> _directoryMatches(
  Directory root,
  Map<String, List<int>> files,
) async {
  if (!root.existsSync()) return false;
  final actual = <String>[];
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (FileSystemEntity.typeSync(entity.path, followLinks: false) ==
        FileSystemEntityType.file) {
      actual.add(
        p.posix.joinAll(p.split(p.relative(entity.path, from: root.path))),
      );
    }
  }
  actual
    ..removeWhere((path) => path.startsWith('authoring/'))
    ..sort();
  final expected = files.keys.toList(growable: false)..sort();
  if (!_sameStrings(actual, expected)) return false;
  for (final entry in files.entries) {
    final file = File(
      p.joinAll(<String>[root.path, ...p.posix.split(entry.key)]),
    );
    if (!_sameBytes(await file.readAsBytes(), entry.value)) return false;
  }
  return true;
}

Future<void> _replaceDirectory(
  Directory target,
  Map<String, List<int>> files, {
  required String temporaryId,
}) async {
  await target.parent.create(recursive: true);
  final suffix = '$pid-$temporaryId';
  final temporary = Directory('${target.path}.$suffix.tmp');
  final backup = Directory('${target.path}.$suffix.backup');
  await temporary.create();
  var targetMoved = false;
  try {
    for (final entry in files.entries) {
      final file = File(
        p.joinAll(<String>[temporary.path, ...p.posix.split(entry.key)]),
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(entry.value, flush: true);
    }
    if (target.existsSync()) {
      await target.rename(backup.path);
      targetMoved = true;
    }
    await temporary.rename(target.path);
    if (backup.existsSync()) await backup.delete(recursive: true);
  } on Object {
    if (!target.existsSync() && targetMoved && backup.existsSync()) {
      await backup.rename(target.path);
    }
    rethrow;
  } finally {
    if (temporary.existsSync()) await temporary.delete(recursive: true);
    if (target.existsSync() && backup.existsSync()) {
      await backup.delete(recursive: true);
    }
  }
}

Future<void> _writeAtomic(
  File target,
  List<int> bytes, {
  required String temporaryId,
}) async {
  await target.parent.create(recursive: true);
  final suffix = '$pid-$temporaryId';
  final temporary = File('${target.path}.$suffix.tmp');
  final backup = File('${target.path}.$suffix.backup');
  var targetMoved = false;
  try {
    await temporary.writeAsBytes(bytes, flush: true);
    if (target.existsSync()) {
      await target.rename(backup.path);
      targetMoved = true;
    }
    await temporary.rename(target.path);
    if (backup.existsSync()) await backup.delete();
  } on Object {
    if (!target.existsSync() && targetMoved && backup.existsSync()) {
      await backup.rename(target.path);
    }
    rethrow;
  } finally {
    if (temporary.existsSync()) await temporary.delete();
    if (target.existsSync() && backup.existsSync()) await backup.delete();
  }
}

void _validatePluginId(String id) {
  if (id.startsWith('tinest.') ||
      !RegExp(
        r'^[a-z][a-z0-9]*(?:-[a-z0-9]+)*(?:\.[a-z][a-z0-9]*(?:-[a-z0-9]+)*)+$',
      ).hasMatch(id)) {
    throw PluginAuthoringException('Invalid user plugin ID: $id');
  }
}

bool _sameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
