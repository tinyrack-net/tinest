import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:daemon/src/features/plugins/infrastructure/plugin_authoring.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_bundles.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_ports.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_ui_service.dart';
import 'package:path/path.dart' as p;
import 'package:protocol/protocol.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Lists immutable product plugins and app-data sources without discovering
/// code from a checkout.
abstract interface class PluginSourceCatalog {
  /// Emits after installed plugin source may have changed.
  Stream<void> get changes;

  /// Lists every installed product and user plugin ID.
  Future<List<String>> listPluginIds();

  /// Creates a new app-data plugin package from the public starter template.
  Future<void> scaffold(String id, String name);

  /// Copies a validated immutable revision into a new app-data package.
  Future<void> fork(PluginBundle source, String id, String name);
}

/// Native catalog combining embedded built-ins with `<config>/v5/plugins`.
final class NativePluginSourceCatalog implements PluginSourceCatalog {
  /// Creates the catalog rooted at `<config>/v5/plugins`.
  new(
    String configRoot, {
    this.builtIns = const BuiltInPluginCatalog(),
    this.authoring,
  }) : _root = Directory(p.join(configRoot, 'v5', 'plugins'));

  final Directory _root;
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );
  final Map<String, StreamSubscription<FileSystemEvent>> _watchSubscriptions =
      <String, StreamSubscription<FileSystemEvent>>{};
  Future<void> _watchTail = Future<void>.value();
  Future<void>? _initialization;
  Timer? _changeDebounce;
  bool _closed = false;

  /// Read-only product plugin source.
  final BuiltInPluginCatalog builtIns;

  /// Optional editor-sidecar owner used by the production composition root.
  final PluginAuthoringEnvironmentService? authoring;

  /// Emits after an external edit may have changed an app-data package.
  @override
  Stream<void> get changes => _changes.stream;

  /// Creates the app-data root and starts its native directory watchers.
  Future<void> initialize() {
    if (_closed) {
      return Future<void>.error(
        StateError('A closed plugin source catalog cannot be initialized.'),
      );
    }
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    await _root.create(recursive: true);
    await _ensureWatchTargets();
  }

  Future<void> _ensureWatchTargets() {
    final previous = _watchTail;
    final next = () async {
      await previous;
      if (_closed) return;
      await _replaceWatchTargets();
    }();
    // [next] still reports this refresh's error to its caller. The private
    // tail absorbs it only so one transient filesystem failure cannot poison
    // every later serialized refresh.
    _watchTail = next.catchError((Object _) {});
    return next;
  }

  Future<void> _replaceWatchTargets() async {
    final desiredPaths = await _sourceDirectoryPaths();
    for (final path in desiredPaths) {
      if (_watchSubscriptions.containsKey(path)) continue;
      _startWatching(path);
    }

    final stalePaths = _watchSubscriptions.keys
        .where((path) => !desiredPaths.contains(path))
        .toList(growable: false);
    for (final path in stalePaths) {
      final subscription = _watchSubscriptions.remove(path);
      await subscription?.cancel();
    }
  }

  Future<Set<String>> _sourceDirectoryPaths() async {
    final sourceRoot = p.normalize(p.absolute(_root.path));
    final paths = <String>{};
    final pending = <Directory>[_root];
    while (pending.isNotEmpty) {
      final directory = pending.removeLast();
      final directoryPath = p.normalize(p.absolute(directory.path));
      if (!p.equals(directoryPath, sourceRoot) &&
          !p.isWithin(sourceRoot, directoryPath)) {
        continue;
      }
      try {
        if (FileSystemEntity.typeSync(directoryPath, followLinks: false) !=
            FileSystemEntityType.directory) {
          continue;
        }
        paths.add(directoryPath);
        await for (final entity in Directory(
          directoryPath,
        ).list(followLinks: false)) {
          if (FileSystemEntity.typeSync(entity.path, followLinks: false) ==
              FileSystemEntityType.directory) {
            pending.add(Directory(entity.path));
          }
        }
      } on FileSystemException {
        // Editors can replace a directory while it is being enumerated. Keep
        // only still-existing non-link watchers until the next native event
        // produces a complete scan.
        paths.addAll(
          _watchSubscriptions.keys.where(
            (path) =>
                FileSystemEntity.typeSync(path, followLinks: false) ==
                FileSystemEntityType.directory,
          ),
        );
      }
    }
    return paths;
  }

  void _startWatching(String watchedPath) {
    try {
      late final StreamSubscription<FileSystemEvent> subscription;
      subscription = Directory(watchedPath)
          // dart:io's default is deliberately non-recursive so Linux uses the
          // same one-subscription-per-directory topology as other hosts.
          .watch()
          .listen(
            _handleWatchEvent,
            onError: (Object _) => _watchEnded(watchedPath, subscription),
            onDone: () => _watchEnded(watchedPath, subscription),
          );
      _watchSubscriptions[watchedPath] = subscription;
    } on FileSystemException {
      // The directory can disappear after enumeration. Its watched parent
      // will drive the next scan if it is recreated.
    }
  }

  void _handleWatchEvent(FileSystemEvent event) {
    if (_closed) return;
    if (event.isDirectory) {
      unawaited(_refreshAfterDirectoryEvent());
      return;
    }
    if (_isPluginSourceEvent(event)) _scheduleChange();
  }

  Future<void> _refreshAfterDirectoryEvent() async {
    await _ensureWatchTargets();
    _scheduleChange();
  }

  bool _isPluginSourceEvent(FileSystemEvent event) {
    if (_isPluginSourcePath(event.path)) return true;
    return event is FileSystemMoveEvent &&
        event.destination != null &&
        _isPluginSourcePath(event.destination!);
  }

  bool _isPluginSourcePath(String path) {
    final extension = p.extension(path).toLowerCase();
    return extension == '.lua' || extension == '.md';
  }

  void _scheduleChange() {
    if (_closed) return;
    _changeDebounce?.cancel();
    _changeDebounce = Timer(const Duration(milliseconds: 75), () {
      if (!_changes.isClosed) _changes.add(null);
    });
  }

  void _watchEnded(
    String watchedPath,
    StreamSubscription<FileSystemEvent> subscription,
  ) {
    if (_closed || !identical(_watchSubscriptions[watchedPath], subscription)) {
      return;
    }
    _watchSubscriptions.remove(watchedPath);
    unawaited(subscription.cancel());
    _scheduleChange();
    unawaited(_ensureWatchTargets());
  }

  /// Stops native observation.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _changeDebounce?.cancel();
    await _initialization;
    await _watchTail;
    final subscriptions = _watchSubscriptions.values.toList(growable: false);
    _watchSubscriptions.clear();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    await _changes.close();
  }

  @override
  Future<List<String>> listPluginIds() async {
    final ids = <String>{...builtIns.ids};
    if (_root.existsSync()) {
      await for (final entity in _root.list(followLinks: false)) {
        if (FileSystemEntity.typeSync(entity.path, followLinks: false) !=
            FileSystemEntityType.directory) {
          continue;
        }
        if (FileSystemEntity.isLinkSync(entity.path)) continue;
        final id = p.basename(entity.path);
        if (!id.startsWith('tinest.')) ids.add(id);
      }
    }
    final sorted = ids.toList(growable: false)..sort();
    return List<String>.unmodifiable(sorted);
  }

  @override
  Future<void> scaffold(String id, String name) async {
    _validateUserPluginId(id);
    final directory = Directory(p.join(_root.path, id));
    if (directory.existsSync()) {
      throw StateError('Plugin already exists: $id');
    }
    await directory.create(recursive: true);
    try {
      await File(p.join(directory.path, 'PLUGIN.md')).writeAsString(
        '''
---
api: 5
id: $id
version: 0.1.0
name: ${_yamlScalar(name)}
entrypoint: main.lua
capabilities: []
---

# $name
'''
            .trimLeft(),
        flush: true,
      );
      await File(p.join(directory.path, 'main.lua')).writeAsString(
        '''
local tinest = require("tinest")
local S = tinest.schema
local T = require("tinest.types")

local Input = S.object(T.Input, {
  message = S.string(),
})
local Output = S.object(T.Output, {
  message = S.string(),
})

local echo = tinest.tool.function_({
  id = "echo",
  description = "Return the supplied message.",
  uses = {},
}, Input, Output, function(arguments)
  return {message = arguments.message}
end)

return tinest.plugin.define({
  tools = {echo},
})
'''
            .trimLeft(),
        flush: true,
      );
      await authoring?.sync(id);
    } on Object {
      if (directory.existsSync()) await directory.delete(recursive: true);
      rethrow;
    }
  }

  @override
  Future<void> fork(PluginBundle source, String id, String name) async {
    _validateUserPluginId(id);
    _validatePluginName(name);
    await _root.create(recursive: true);
    _ensureAvailableUserId(id);
    final target = Directory(p.join(_root.path, id));
    final temporary = Directory(p.join(_root.path, '.$id.$pid.tmp'));
    if (temporary.existsSync()) {
      throw StateError('Temporary plugin package already exists: $id');
    }
    await temporary.create();
    var moved = false;
    try {
      for (final entry in source.assets.entries) {
        _validateForkAssetPath(entry.key);
        final bytes = entry.key == 'PLUGIN.md'
            ? _forkManifest(
                entry.value,
                sourceId: source.descriptor.id,
                id: id,
                name: name,
              )
            : _forkAssetIdentity(
                entry.value,
                sourceId: source.descriptor.id,
                id: id,
              );
        final file = File(
          p.joinAll(<String>[temporary.path, ...p.posix.split(entry.key)]),
        );
        _requireForkPath(temporary.path, file.path);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes, flush: true);
      }
      await temporary.rename(target.path);
      try {
        await authoring?.sync(id);
        moved = true;
      } on Object {
        if (target.existsSync()) await target.delete(recursive: true);
        rethrow;
      }
    } finally {
      if (!moved && temporary.existsSync()) {
        await temporary.delete(recursive: true);
      }
    }
  }

  void _ensureAvailableUserId(String id) {
    if (!_root.existsSync()) return;
    final collision = _root
        .listSync(followLinks: false)
        .any(
          (entity) => p.basename(entity.path).toLowerCase() == id.toLowerCase(),
        );
    if (collision) throw StateError('Plugin already exists: $id');
  }
}

/// Application service for the public plugin management surface.
final class PluginManagementService
    implements PluginDescriptorReader, AgentPluginDescriptorReader {
  /// Creates plugin management over validated revisions and daemon state.
  new({
    required this.sources,
    required this.revisions,
    required this.grants,
    required this.inspector,
  });

  /// Embedded and app-data source catalog.
  final PluginSourceCatalog sources;

  /// Last-known-good revision catalog.
  final PluginRevisionCatalog revisions;

  /// Per-Agent capability grants.
  final AgentPluginGrantStore grants;

  /// Effect-free Lua definition inspector used before an LKG is recorded.
  final PluginBundleInspector inspector;

  /// Lists installed built-in and user plugins in deterministic ID order.
  Future<List<PluginDescriptorDto>> list() async {
    final result = <PluginDescriptorDto>[];
    for (final id in await sources.listPluginIds()) {
      if (!id.startsWith('tinest.')) {
        try {
          result.add(
            await revisions.validateInstalled(id, inspector: inspector),
          );
        } on PluginBundleFormatException catch (error) {
          result.add(_invalidDescriptor(id, error.message, path: error.path));
        } on PluginBundleInspectionException catch (error) {
          result.add(_invalidDescriptor(id, error.message, path: error.path));
        } on FileSystemException catch (error) {
          result.add(_invalidDescriptor(id, error.message, path: error.path));
        }
        continue;
      }
      try {
        result.add(
          (await revisions.resolveInspectedInstalled(
            id,
            inspector: inspector,
          )).descriptor,
        );
      } on PluginRevisionUnavailable {
        try {
          result.add(
            await revisions.validateInstalled(id, inspector: inspector),
          );
        } on PluginBundleFormatException catch (error) {
          result.add(_invalidDescriptor(id, error.message, path: error.path));
        } on PluginBundleInspectionException catch (error) {
          result.add(_invalidDescriptor(id, error.message, path: error.path));
        } on FileSystemException catch (error) {
          result.add(_invalidDescriptor(id, error.message, path: error.path));
        }
      }
    }
    return List<PluginDescriptorDto>.unmodifiable(result);
  }

  /// Gets one descriptor, preferring its active last-known-good revision.
  @override
  Future<PluginDescriptorDto> get(String id) async {
    if (!(await sources.listPluginIds()).contains(id)) {
      throw PluginManagementException('Plugin is not installed: $id');
    }
    if (!id.startsWith('tinest.')) {
      return await revisions.validateInstalled(id, inspector: inspector);
    }
    try {
      return (await revisions.resolveInspectedInstalled(
        id,
        inspector: inspector,
      )).descriptor;
    } on PluginRevisionUnavailable {
      return await revisions.validateInstalled(id, inspector: inspector);
    }
  }

  @override
  Future<PluginDescriptorDto> getForAgent(String agentId, String id) async =>
      (await revisions.resolveInspectedForAgent(
        agentId,
        id,
        inspector: inspector,
      )).descriptor;

  /// Resolves or activates one plugin revision for an Agent.
  ///
  /// Product plugins retain the existing first-use policy of recording their
  /// manifest capabilities as ordinary Agent grants. User plugins still need
  /// explicit grants before their first revision can become active.
  Future<PluginDescriptorDto> prepareForAgent(String agentId, String id) async {
    try {
      await revisions.resolveForAgent(agentId, id);
    } on PluginRevisionUnavailable {
      final descriptor = await get(id);
      if (descriptor.source == PluginSource.builtIn) {
        for (final capability in descriptor.requestedCapabilities) {
          await grants.grant(
            AgentPluginGrantDto(
              agentId: agentId,
              pluginId: id,
              capability: capability,
            ),
          );
        }
      }
    }
    final descriptor = await reload(id, agentId);
    if (descriptor.revision == null) {
      throw StateError('Plugin has no runnable revision: $id');
    }
    return descriptor;
  }

  /// Validates a candidate without changing the active revision.
  Future<PluginDescriptorDto> validate(String id) async =>
      await revisions.validateInstalled(id, inspector: inspector);

  /// Reloads a candidate using only capabilities granted to [agentId].
  Future<PluginDescriptorDto> reload(String id, String agentId) async {
    final approved = <String>{
      for (final grant in await grants.list(agentId))
        if (grant.pluginId == id) grant.capability,
    };
    return await revisions.reload(
      id,
      agentId: agentId,
      approvedCapabilities: approved,
      inspector: inspector,
    );
  }

  /// Scaffolds and validates a new user plugin; it is not globally enabled.
  Future<PluginDescriptorDto> scaffold(String id, String name) async {
    await sources.scaffold(id, name);
    return await validate(id);
  }

  /// Forks an installed plugin's validated revision without activating it.
  Future<PluginDescriptorDto> fork({
    required String sourceId,
    required String id,
    required String name,
  }) async {
    if (!(await sources.listPluginIds()).contains(sourceId)) {
      throw PluginManagementException('Plugin is not installed: $sourceId');
    }
    await validate(sourceId);
    final source = await revisions.resolveInstalled(sourceId);
    await sources.fork(source, id, name);
    return await validate(id);
  }

  /// Lists Agent-owned grants.
  Future<List<AgentPluginGrantDto>> listGrants(String agentId) =>
      grants.list(agentId);

  /// Grants one manifest-bounded capability.
  Future<List<AgentPluginGrantDto>> grant(AgentPluginGrantDto grant) async {
    final descriptor = await validate(grant.pluginId);
    if (!descriptor.requestedCapabilities.contains(grant.capability)) {
      throw StateError(
        'Plugin ${grant.pluginId} does not request ${grant.capability}.',
      );
    }
    await grants.grant(grant);
    return await grants.list(grant.agentId);
  }

  /// Revokes one exact grant. Active host primitives observe revocation through
  /// the capability broker's cancellation signal.
  Future<List<AgentPluginGrantDto>> revoke(AgentPluginGrantDto grant) async {
    await grants.revoke(grant);
    return await grants.list(grant.agentId);
  }
}

/// Expected plugin management failure suitable for transport mapping.
final class PluginManagementException implements Exception {
  /// Creates a management failure.
  const new(this.message);

  /// User-safe failure description.
  final String message;

  @override
  String toString() => 'PluginManagementException: $message';
}

PluginDescriptorDto _invalidDescriptor(
  String id,
  String message, {
  String? path,
}) => PluginDescriptorDto(
  apiMajor: 5,
  id: id,
  version: '0.0.0',
  name: id,
  entrypoint: 'main.lua',
  source: id.startsWith('tinest.') ? PluginSource.builtIn : PluginSource.user,
  sourcePath: id.startsWith('tinest.') ? 'builtin://$id' : id,
  requestedCapabilities: const <String>[],
  diagnostics: <PluginDiagnosticDto>[
    PluginDiagnosticDto(
      code: 'invalid_plugin_bundle',
      message: message,
      severity: PluginDiagnosticSeverity.error,
      path: path,
    ),
  ],
);

void _validateUserPluginId(String id) {
  if (!RegExp(
        r'^[a-z][a-z0-9]*(?:-[a-z0-9]+)*(?:\.[a-z][a-z0-9]*(?:-[a-z0-9]+)*)+$',
      ).hasMatch(id) ||
      id.startsWith('tinest.')) {
    throw FormatException('Invalid user plugin ID: $id');
  }
}

String _yamlScalar(String value) =>
    "'${value.replaceAll("'", "''").replaceAll('\n', ' ')}'";

void _validatePluginName(String name) {
  if (name.trim().isEmpty) {
    throw const FormatException('Plugin name must not be empty.');
  }
}

void _validateForkAssetPath(String path) {
  final extension = p.posix.extension(path);
  if (path.isEmpty ||
      path.contains(r'\') ||
      path.startsWith('/') ||
      path.startsWith('../') ||
      p.posix.normalize(path) != path ||
      (extension != '.lua' && extension != '.md')) {
    throw PluginBundleFormatException(
      'Fork source contains an invalid plugin asset path.',
      path: path,
    );
  }
}

Uint8List _forkManifest(
  Uint8List bytes, {
  required String sourceId,
  required String id,
  required String name,
}) {
  final source = utf8.decode(bytes).replaceAll('\r\n', '\n');
  final lines = source.split('\n');
  if (lines.isEmpty || lines.first.trim() != '---') {
    throw const PluginBundleFormatException(
      'Validated fork source has no PLUGIN.md frontmatter.',
      path: 'PLUGIN.md',
    );
  }
  final end = lines.indexWhere((line) => line.trim() == '---', 1);
  if (end < 0) {
    throw const PluginBundleFormatException(
      'Validated fork source has unclosed PLUGIN.md frontmatter.',
      path: 'PLUGIN.md',
    );
  }
  final editor = YamlEditor(lines.sublist(1, end).join('\n'))
    ..update(<Object>['id'], id)
    ..update(<Object>['name'], name.trim());
  final body = _forkTextIdentity(
    lines.sublist(end + 1).join('\n'),
    sourceId: sourceId,
    id: id,
  );
  return Uint8List.fromList(utf8.encode('---\n$editor\n---\n$body'));
}

Uint8List _forkAssetIdentity(
  Uint8List bytes, {
  required String sourceId,
  required String id,
}) => Uint8List.fromList(
  utf8.encode(
    _forkTextIdentity(utf8.decode(bytes), sourceId: sourceId, id: id),
  ),
);

String _forkTextIdentity(
  String source, {
  required String sourceId,
  required String id,
}) => source.replaceAll(RegExp('${RegExp.escape(sourceId)}(?![a-z0-9.-])'), id);

void _requireForkPath(String root, String candidate) {
  final absoluteRoot = p.normalize(p.absolute(root));
  final absoluteCandidate = p.normalize(p.absolute(candidate));
  if (!p.isWithin(absoluteRoot, absoluteCandidate)) {
    throw PluginBundleFormatException(
      'Forked plugin asset escapes its package root.',
      path: candidate,
    );
  }
}
