import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:daemon/src/features/plugins/infrastructure/builtin_plugin_assets.g.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_sdk.dart';
import 'package:path/path.dart' as p;
import 'package:protocol/protocol.dart';
import 'package:yaml/yaml.dart';

/// A validated immutable plugin revision and its bundled Lua/Markdown bytes.
final class PluginBundle implements PluginLuaProgramSource {
  /// Creates a plugin bundle from already validated data.
  new({
    required this.descriptor,
    required this.revision,
    required Map<String, Uint8List> assets,
  }) : assets = Map<String, Uint8List>.unmodifiable(<String, Uint8List>{
         for (final entry in assets.entries)
           entry.key: Uint8List.fromList(entry.value),
       });

  /// Validated manifest metadata.
  @override
  final PluginDescriptorDto descriptor;

  /// Content-addressed revision metadata.
  @override
  final PluginRevisionDto revision;

  /// POSIX-relative immutable bundle assets in deterministic order.
  @override
  final Map<String, Uint8List> assets;
}

/// Raised when a source or cached plugin package violates the public format.
final class PluginBundleFormatException extends FormatException {
  /// Creates a bundle format failure.
  const new(super.message, {this.path});

  /// Relative or absolute path associated with the failure.
  final String? path;
}

/// Expected absence of an installed or Agent-pinned plugin revision.
final class PluginRevisionUnavailable implements Exception {
  /// Creates an unavailable revision failure.
  const new(this.message);

  /// User-safe reason.
  final String message;

  @override
  String toString() => 'PluginRevisionUnavailable: $message';
}

/// Typed boundary that loads validated plugin bundles.
abstract interface class PluginBundleLoader {
  /// Loads one plugin by its manifest ID.
  Future<PluginBundle> load(String id);
}

/// Effect-free validator for the Lua contribution definition in one bundle.
///
/// Implementations must inspect the supplied immutable bytes without changing
/// either the installed or an Agent-active revision pointer.
abstract interface class PluginBundleInspector {
  /// Returns the descriptor enriched with all typed Lua contributions.
  Future<PluginDescriptorDto> inspect(PluginBundle bundle);
}

/// Typed failure produced when a bundle manifest is valid but its Lua
/// `tinest.plugin.define` registration is not.
final class PluginBundleInspectionException implements Exception {
  /// Creates an inspection failure suitable for a plugin diagnostic.
  const new(this.message, {this.path});

  /// User-safe failure description.
  final String message;

  /// Bundle-relative location associated with the failure.
  final String? path;

  @override
  String toString() => 'PluginBundleInspectionException: $message';
}

/// Typed boundary for the atomic last-known-good revision cache.
abstract interface class PluginRevisionCache {
  /// Loads the installation-level last validated revision.
  Future<PluginBundle?> loadInstalled(String id);

  /// Loads the runtime revision selected for one Agent.
  Future<PluginBundle?> loadForAgent(String agentId, String id);

  /// Loads the immutable revision identified by its composite execution hash.
  ///
  /// This does not follow either mutable installed or Agent-active pointers.
  /// A durable callback can therefore resume the exact code and SDK ABI it was
  /// created against after a later plugin reload.
  Future<PluginBundle?> loadExecutionRevision(
    String id,
    String executionRevisionHash,
  );

  /// Atomically stores [bundle] as the installed validated revision.
  Future<void> storeInstalled(PluginBundle bundle);

  /// Atomically pins one Agent to an already validated [bundle].
  Future<void> activateForAgent(String agentId, PluginBundle bundle);
}

/// Read-only product bundle of plugins that reserve the `tinest.*` namespace.
final class BuiltInPluginCatalog implements PluginBundleLoader {
  /// Creates the immutable embedded catalog.
  const new();

  /// Built-in plugin IDs in deterministic display order.
  List<String> get ids => List<String>.unmodifiable(
    builtInPluginAssetsBase64.keys.toList(growable: false)..sort(),
  );

  @override
  Future<PluginBundle> load(String id) async {
    _validatePluginId(id, allowReserved: true);
    if (!_isReserved(id)) {
      throw PluginBundleFormatException(
        'Built-in plugin IDs must use the tinest.* namespace.',
        path: id,
      );
    }
    final encoded = builtInPluginAssetsBase64[id];
    if (encoded == null) {
      throw PluginBundleFormatException(
        'Built-in plugin is not part of this product revision: $id',
        path: id,
      );
    }
    final assets = <String, Uint8List>{
      for (final entry in encoded.entries)
        entry.key: Uint8List.fromList(base64Decode(entry.value)),
    };
    return _loadPluginAssets(
      assets,
      expectedId: id,
      source: PluginSource.builtIn,
      sourcePath: 'builtin://$id',
      rejectReservedId: false,
    );
  }
}

/// Product plugin loader that routes `tinest.*` to immutable built-ins and
/// every other valid ID to `<config>/v5/plugins`.
final class NativePluginBundleLoader implements PluginBundleLoader {
  /// Creates a loader from the daemon config directory and embedded catalog.
  new(String configDirectory, {this.builtIns = const BuiltInPluginCatalog()})
    : _pluginsRoot = p.normalize(
        p.absolute(p.join(configDirectory, 'v5', 'plugins')),
      );

  /// Read-only product-owned namespace.
  final BuiltInPluginCatalog builtIns;

  final String _pluginsRoot;

  @override
  Future<PluginBundle> load(String id) async {
    _validatePluginId(id, allowReserved: true);
    if (_isReserved(id)) {
      return await builtIns.load(id);
    }
    _validateDirectoryIdentity(id);
    final directory = Directory(p.join(_pluginsRoot, id));
    return await _loadPluginDirectory(
      directory,
      expectedId: id,
      source: PluginSource.user,
      rejectReservedId: true,
    );
  }

  void _validateDirectoryIdentity(String id) {
    final root = Directory(_pluginsRoot);
    if (!root.existsSync()) return;
    final matches = root
        .listSync(followLinks: false)
        .where((entity) => p.basename(entity.path).toLowerCase() == id)
        .toList(growable: false);
    if (matches.length > 1 ||
        (matches.length == 1 && p.basename(matches.single.path) != id)) {
      throw PluginBundleFormatException(
        'Plugin IDs cannot differ only by letter case.',
        path: id,
      );
    }
  }
}

/// Native immutable cache rooted at `<state>/v5/plugin-cache`.
final class NativePluginRevisionCache implements PluginRevisionCache {
  /// Creates a revision cache from the daemon state directory.
  new(String stateDirectory)
    : _cacheRoot = p.normalize(
        p.absolute(p.join(stateDirectory, 'v5', 'plugin-cache')),
      );

  final String _cacheRoot;

  @override
  Future<void> storeInstalled(PluginBundle bundle) async {
    _validatePluginId(bundle.descriptor.id, allowReserved: true);
    _validateHash(bundle.revision.contentHash);
    final pluginRoot = Directory(p.join(_cacheRoot, bundle.descriptor.id));
    await pluginRoot.create(recursive: true);
    await _storeRevision(pluginRoot, bundle);
    await _writeAtomic(
      File(p.join(pluginRoot.path, 'installed')),
      '${bundle.revision.contentHash}\n',
    );
  }

  @override
  Future<void> activateForAgent(String agentId, PluginBundle bundle) async {
    _validateOwnerId(agentId, field: 'Agent ID');
    _validatePluginId(bundle.descriptor.id, allowReserved: true);
    _validateHash(bundle.revision.contentHash);
    final pluginRoot = Directory(p.join(_cacheRoot, bundle.descriptor.id));
    await pluginRoot.create(recursive: true);
    await _storeRevision(pluginRoot, bundle);
    final pointers = Directory(p.join(pluginRoot.path, 'agents'));
    await pointers.create();
    await _writeAtomic(
      File(p.join(pointers.path, _pointerName(agentId))),
      '${bundle.revision.contentHash}\n',
    );
  }

  Future<void> _storeRevision(Directory pluginRoot, PluginBundle bundle) async {
    _validateHash(bundle.revision.executionRevisionHash);
    final revisionDirectory = Directory(
      p.join(pluginRoot.path, bundle.revision.contentHash),
    );
    if (!revisionDirectory.existsSync()) {
      // createTemp, not a name built from the process ID and a counter: the
      // counter is top-level state, so every isolate of one process holds its
      // own copy starting at zero, and two isolates staging the same revision
      // picked the same path. They then wrote into one directory together and
      // whichever renamed first pulled it out from under the other's writes.
      // The OS is the only thing that can promise this name is unheld.
      final temporary = await pluginRoot.createTemp(
        '.${bundle.revision.contentHash}.',
      );
      var moved = false;
      try {
        for (final entry in bundle.assets.entries) {
          final target = File(
            p.joinAll(<String>[temporary.path, ...p.posix.split(entry.key)]),
          );
          _requireWithin(temporary.path, target.path);
          await target.parent.create(recursive: true);
          await target.writeAsBytes(entry.value, flush: true);
        }
        try {
          await temporary.rename(revisionDirectory.path);
          moved = true;
        } on FileSystemException {
          // Revisions are content-addressed, so a concurrent writer that
          // renamed the same revision first has produced byte-identical
          // content; losing the rename race is success, anything else is a
          // real filesystem failure.
          if (!revisionDirectory.existsSync()) rethrow;
        }
      } finally {
        if (!moved && temporary.existsSync()) {
          await temporary.delete(recursive: true);
        }
      }
    }
    final executionPointers = Directory(p.join(pluginRoot.path, 'executions'));
    await executionPointers.create();
    await _writeAtomic(
      File(
        p.join(executionPointers.path, bundle.revision.executionRevisionHash),
      ),
      '${bundle.revision.contentHash}\n',
    );
  }

  @override
  Future<PluginBundle?> loadInstalled(String id) =>
      _loadPointer(id, pointerPath: p.join(id, 'installed'));

  @override
  Future<PluginBundle?> loadForAgent(String agentId, String id) {
    _validateOwnerId(agentId, field: 'Agent ID');
    return _loadPointer(
      id,
      pointerPath: p.join(id, 'agents', _pointerName(agentId)),
    );
  }

  @override
  Future<PluginBundle?> loadExecutionRevision(
    String id,
    String executionRevisionHash,
  ) {
    _validateHash(executionRevisionHash);
    return _loadPointer(
      id,
      pointerPath: p.join(id, 'executions', executionRevisionHash),
      expectedExecutionRevisionHash: executionRevisionHash,
    );
  }

  Future<PluginBundle?> _loadPointer(
    String id, {
    required String pointerPath,
    String? expectedExecutionRevisionHash,
  }) async {
    _validatePluginId(id, allowReserved: true);
    final pluginRoot = Directory(p.join(_cacheRoot, id));
    final activeFile = File(p.join(_cacheRoot, pointerPath));
    final pointerType = FileSystemEntity.typeSync(
      activeFile.path,
      followLinks: false,
    );
    if (pointerType == FileSystemEntityType.notFound) return null;
    if (pointerType != FileSystemEntityType.file) {
      throw PluginBundleFormatException(
        'Cached plugin revision pointer must be a regular file.',
        path: activeFile.path,
      );
    }
    final contentHash = (await activeFile.readAsString()).trim();
    _validateHash(contentHash);
    final revisionDirectory = Directory(p.join(pluginRoot.path, contentHash));
    final bundle = await _loadPluginDirectory(
      revisionDirectory,
      expectedId: id,
      source: id.startsWith('tinest.')
          ? PluginSource.builtIn
          : PluginSource.user,
      rejectReservedId: false,
      requireMatchingDirectoryName: false,
    );
    if (bundle.revision.contentHash != contentHash) {
      throw PluginBundleFormatException(
        'Cached plugin content does not match its revision directory.',
        path: revisionDirectory.path,
      );
    }
    if (expectedExecutionRevisionHash != null &&
        bundle.revision.executionRevisionHash !=
            expectedExecutionRevisionHash) {
      return null;
    }
    return bundle;
  }
}

/// Applies source revisions while retaining the last known good bundle.
final class PluginRevisionCatalog {
  /// Creates a revision catalog over injected source and cache ports.
  new({required this.loader, required this.cache});

  /// App-data or built-in source boundary.
  final PluginBundleLoader loader;

  /// Durable revision cache boundary.
  final PluginRevisionCache cache;

  final Map<String, PluginBundle> _installed = <String, PluginBundle>{};
  final Map<String, PluginBundle> _agentActive = <String, PluginBundle>{};
  final Set<String> _inspectedInstalledBundles = <String>{};
  final Set<String> _inspectedAgentBundles = <String>{};

  /// Loads the installation-level last validated revision after restart.
  Future<PluginDescriptorDto> loadInstalled(String id) async {
    final bundle = _installed[id] ?? await cache.loadInstalled(id);
    if (bundle == null) {
      throw PluginRevisionUnavailable(
        'No validated plugin revision exists: $id',
      );
    }
    _installed[id] = bundle;
    return bundle.descriptor;
  }

  /// Reconstructs executable contributions for an installation LKG.
  ///
  /// The durable cache stores original package assets, not an inspector's
  /// derived descriptor. Management UI therefore has to perform the same
  /// effect-free registration pass after restart that Agent pins perform.
  Future<PluginBundle> resolveInspectedInstalled(
    String id, {
    required PluginBundleInspector inspector,
  }) async {
    final bundle = await resolveInstalled(id);
    if (_inspectedInstalledBundles.contains(id)) return bundle;
    final inspected = await _inspect(bundle, inspector);
    _installed[id] = inspected;
    _inspectedInstalledBundles.add(id);
    return inspected;
  }

  /// Resolves the exact validated installation revision used for authoring.
  Future<PluginBundle> resolveInstalled(String id) async {
    final bundle = _installed[id] ?? await cache.loadInstalled(id);
    if (bundle == null) {
      throw PluginRevisionUnavailable(
        'No validated plugin revision exists: $id',
      );
    }
    _installed[id] = bundle;
    return bundle;
  }

  /// Resolves one Agent's exact runtime revision for turn pinning.
  Future<PluginBundle> resolveForAgent(String agentId, String id) async {
    final key = _agentKey(agentId, id);
    final bundle = _agentActive[key] ?? await cache.loadForAgent(agentId, id);
    if (bundle == null) {
      throw PluginRevisionUnavailable(
        'Agent $agentId has no active revision for plugin $id.',
      );
    }
    _agentActive[key] = bundle;
    return bundle;
  }

  /// Resolves immutable code for a durable revision-bound callback.
  Future<PluginBundle> resolveExecutionRevision(
    String id,
    String executionRevisionHash,
  ) async {
    _validatePluginId(id, allowReserved: true);
    if (executionRevisionHash.trim().isEmpty) {
      throw const PluginRevisionUnavailable(
        'An exact execution revision hash is required.',
      );
    }
    final inMemory =
        <PluginBundle>[..._installed.values, ..._agentActive.values].where(
          (bundle) =>
              bundle.descriptor.id == id &&
              bundle.revision.executionRevisionHash == executionRevisionHash,
        );
    final bundle =
        inMemory.firstOrNull ??
        await cache.loadExecutionRevision(id, executionRevisionHash);
    if (bundle == null) {
      throw PluginRevisionUnavailable(
        'No exact execution revision $executionRevisionHash exists for '
        'plugin $id.',
      );
    }
    if (bundle.descriptor.id != id ||
        bundle.revision.pluginId != id ||
        bundle.revision.executionRevisionHash != executionRevisionHash) {
      throw PluginBundleFormatException(
        'Cached plugin does not match the requested execution revision.',
        path: executionRevisionHash,
      );
    }
    return bundle;
  }

  /// Reconstructs executable contribution metadata for a cached Agent pin.
  ///
  /// Revision directories intentionally contain only the original Lua and
  /// Markdown assets. After daemon restart their manifest-only descriptor must
  /// therefore pass through the same effect-free inspector before UI or tool
  /// contribution lookup can use it.
  Future<PluginBundle> resolveInspectedForAgent(
    String agentId,
    String id, {
    required PluginBundleInspector inspector,
  }) async {
    final key = _agentKey(agentId, id);
    final bundle = await resolveForAgent(agentId, id);
    if (_inspectedAgentBundles.contains(key)) return bundle;
    final inspected = await _inspect(bundle, inspector);
    _agentActive[key] = inspected;
    _inspectedAgentBundles.add(key);
    return inspected;
  }

  /// Validates and records a source revision without Agent activation.
  Future<PluginDescriptorDto> validateInstalled(
    String id, {
    PluginBundleInspector? inspector,
  }) async {
    var previous = _installed[id] ?? await cache.loadInstalled(id);
    if (previous != null) {
      if (inspector != null && !_inspectedInstalledBundles.contains(id)) {
        previous = await _inspect(previous, inspector);
        _inspectedInstalledBundles.add(id);
      }
      _installed[id] = previous;
    }
    PluginBundle candidate;
    try {
      candidate = await _inspect(await loader.load(id), inspector);
    } on PluginBundleFormatException catch (error) {
      if (previous == null) rethrow;
      return _staleDescriptor(
        previous,
        PluginDiagnosticDto(
          code: 'invalid_plugin_bundle',
          message: error.message,
          severity: PluginDiagnosticSeverity.error,
          path: error.path,
        ),
      );
    } on FileSystemException catch (error) {
      if (previous == null) rethrow;
      return _staleDescriptor(
        previous,
        PluginDiagnosticDto(
          code: 'invalid_plugin_bundle',
          message: error.message,
          severity: PluginDiagnosticSeverity.error,
          path: error.path,
        ),
      );
    } on PluginBundleInspectionException catch (error) {
      if (previous == null) rethrow;
      return _staleDescriptor(
        previous,
        PluginDiagnosticDto(
          code: 'invalid_plugin_definition',
          message: error.message,
          severity: PluginDiagnosticSeverity.error,
          path: error.path,
        ),
      );
    }
    await cache.storeInstalled(candidate);
    _installed[id] = candidate;
    if (inspector != null) _inspectedInstalledBundles.add(id);
    return candidate.descriptor;
  }

  /// Validates the source and activates it when capabilities remain approved.
  ///
  Future<PluginDescriptorDto> reload(
    String id, {
    required String agentId,
    required Set<String> approvedCapabilities,
    PluginBundleInspector? inspector,
  }) async {
    final key = _agentKey(agentId, id);
    var previous = _agentActive[key] ?? await cache.loadForAgent(agentId, id);
    if (previous != null) {
      if (inspector != null && !_inspectedAgentBundles.contains(key)) {
        previous = await _inspect(previous, inspector);
        _inspectedAgentBundles.add(key);
      }
      _agentActive[key] = previous;
    }
    PluginBundle candidate;
    try {
      candidate = await _inspect(await loader.load(id), inspector);
    } on PluginBundleFormatException catch (error) {
      if (previous == null) rethrow;
      return _staleDescriptor(
        previous,
        PluginDiagnosticDto(
          code: 'invalid_plugin_bundle',
          message: error.message,
          severity: PluginDiagnosticSeverity.error,
          path: error.path,
        ),
      );
    } on FileSystemException catch (error) {
      if (previous == null) rethrow;
      return _staleDescriptor(
        previous,
        PluginDiagnosticDto(
          code: 'invalid_plugin_bundle',
          message: error.message,
          severity: PluginDiagnosticSeverity.error,
          path: error.path,
        ),
      );
    } on PluginBundleInspectionException catch (error) {
      if (previous == null) rethrow;
      return _staleDescriptor(
        previous,
        PluginDiagnosticDto(
          code: 'invalid_plugin_definition',
          message: error.message,
          severity: PluginDiagnosticSeverity.error,
          path: error.path,
        ),
      );
    }
    final expanded = candidate.revision.requestedCapabilities
        .where((capability) => !approvedCapabilities.contains(capability))
        .toList(growable: false);
    if (expanded.isNotEmpty) {
      if (previous == null) {
        throw PluginBundleFormatException(
          'Plugin capabilities require Agent approval: ${expanded.join(', ')}.',
          path: 'PLUGIN.md',
        );
      }
      return _staleDescriptor(
        previous,
        PluginDiagnosticDto(
          code: 'capability_expanded',
          message:
              'Candidate revision requests additional capabilities: '
              '${expanded.join(', ')}.',
          severity: PluginDiagnosticSeverity.warning,
          path: 'PLUGIN.md',
        ),
      );
    }
    await cache.storeInstalled(candidate);
    await cache.activateForAgent(agentId, candidate);
    _installed[id] = candidate;
    if (inspector != null) _inspectedInstalledBundles.add(id);
    _agentActive[key] = candidate;
    _inspectedAgentBundles.add(key);
    return candidate.descriptor;
  }

  PluginDescriptorDto _staleDescriptor(
    PluginBundle previous,
    PluginDiagnosticDto diagnostic,
  ) => previous.descriptor.copyWith(
    isStale: true,
    diagnostics: <PluginDiagnosticDto>[
      ...previous.descriptor.diagnostics,
      diagnostic,
    ],
  );

  Future<PluginBundle> _inspect(
    PluginBundle candidate,
    PluginBundleInspector? inspector,
  ) async {
    if (inspector == null) return candidate;
    final descriptor = await inspector.inspect(candidate);
    if (descriptor.id != candidate.descriptor.id ||
        descriptor.revision != candidate.revision ||
        descriptor.apiMajor != candidate.descriptor.apiMajor ||
        descriptor.requestedCapabilities
            .toSet()
            .difference(candidate.descriptor.requestedCapabilities.toSet())
            .isNotEmpty ||
        candidate.descriptor.requestedCapabilities
            .toSet()
            .difference(descriptor.requestedCapabilities.toSet())
            .isNotEmpty) {
      throw PluginBundleInspectionException(
        'Lua registration changed immutable manifest or revision metadata.',
        path: candidate.descriptor.entrypoint,
      );
    }
    return PluginBundle(
      descriptor: descriptor,
      revision: candidate.revision,
      assets: candidate.assets,
    );
  }
}

String _agentKey(String agentId, String pluginId) =>
    jsonEncode(<String>[agentId, pluginId]);

Future<PluginBundle> _loadPluginDirectory(
  Directory directory, {
  required String expectedId,
  required PluginSource source,
  required bool rejectReservedId,
  bool requireMatchingDirectoryName = true,
}) async {
  final type = FileSystemEntity.typeSync(directory.path, followLinks: false);
  if (type != FileSystemEntityType.directory) {
    throw PluginBundleFormatException(
      'Plugin package must be a real directory.',
      path: directory.path,
    );
  }
  final absoluteRoot = p.normalize(p.absolute(directory.path));
  final resolvedRoot = p.normalize(directory.resolveSymbolicLinksSync());
  if (!_resolvesAsDirectChild(absoluteRoot, resolvedRoot)) {
    throw PluginBundleFormatException(
      'Plugin package cannot be a symlink or junction.',
      path: directory.path,
    );
  }
  if (requireMatchingDirectoryName && p.basename(absoluteRoot) != expectedId) {
    throw PluginBundleFormatException(
      'Plugin directory name must exactly match its lowercase ID.',
      path: directory.path,
    );
  }
  final assets = <String, Uint8List>{};
  final casePaths = <String, String>{};
  await for (final entity in directory.list(
    recursive: true,
    followLinks: false,
  )) {
    final entityType = FileSystemEntity.typeSync(
      entity.path,
      followLinks: false,
    );
    if (entityType == FileSystemEntityType.link) {
      throw PluginBundleFormatException(
        'Plugin packages cannot contain symlinks or junctions.',
        path: entity.path,
      );
    }
    if (entityType == FileSystemEntityType.directory) {
      final resolved = p.normalize(
        Directory(entity.path).resolveSymbolicLinksSync(),
      );
      final absolute = p.normalize(p.absolute(entity.path));
      if (!_resolvesAsDirectChild(absolute, resolved) ||
          !_isWithin(resolvedRoot, resolved)) {
        throw PluginBundleFormatException(
          'Plugin directory escapes its package root.',
          path: entity.path,
        );
      }
      _registerCasePath(
        casePaths,
        _relativeBundlePath(absoluteRoot, absolute),
        entity.path,
      );
      continue;
    }
    if (entityType != FileSystemEntityType.file) {
      throw PluginBundleFormatException(
        'Unsupported plugin filesystem entry.',
        path: entity.path,
      );
    }
    final absolute = p.normalize(p.absolute(entity.path));
    final resolved = p.normalize(File(entity.path).resolveSymbolicLinksSync());
    if (!_resolvesAsDirectChild(absolute, resolved) ||
        !_isWithin(resolvedRoot, resolved)) {
      throw PluginBundleFormatException(
        'Plugin file escapes its package root.',
        path: entity.path,
      );
    }
    final relative = _relativeBundlePath(absoluteRoot, absolute);
    if (relative == '.luarc.json') continue;
    final extension = p.extension(entity.path);
    if (extension != '.lua' && extension != '.md') {
      throw PluginBundleFormatException(
        'Plugin packages may contain only Lua and Markdown files.',
        path: entity.path,
      );
    }
    _registerCasePath(casePaths, relative, entity.path);
    assets[relative] = Uint8List.fromList(File(entity.path).readAsBytesSync());
  }
  final sortedAssets = <String, Uint8List>{
    for (final path in (assets.keys.toList()..sort())) path: assets[path]!,
  };
  return _loadPluginAssets(
    sortedAssets,
    expectedId: expectedId,
    source: source,
    sourcePath: directory.path,
    rejectReservedId: rejectReservedId,
  );
}

PluginBundle _loadPluginAssets(
  Map<String, Uint8List> sourceAssets, {
  required String expectedId,
  required PluginSource source,
  required String sourcePath,
  required bool rejectReservedId,
}) {
  final casePaths = <String, String>{};
  final sortedAssets = <String, Uint8List>{};
  final paths = sourceAssets.keys.toList(growable: false)..sort();
  for (final path in paths) {
    if (path.isEmpty ||
        path.contains(r'\') ||
        path.startsWith('/') ||
        p.posix.normalize(path) != path ||
        path.startsWith('../')) {
      throw PluginBundleFormatException(
        'Plugin asset paths must be normalized and relative.',
        path: path,
      );
    }
    final extension = p.posix.extension(path);
    if (extension != '.lua' && extension != '.md') {
      throw PluginBundleFormatException(
        'Plugin packages may contain only Lua and Markdown files.',
        path: path,
      );
    }
    _registerCasePath(casePaths, path, path);
    sortedAssets[path] = Uint8List.fromList(sourceAssets[path]!);
  }
  final manifestBytes = sortedAssets['PLUGIN.md'];
  if (manifestBytes == null) {
    throw PluginBundleFormatException(
      'Plugin package requires PLUGIN.md.',
      path: sourcePath,
    );
  }
  final manifest = _parseManifest(
    utf8.decode(manifestBytes),
    sourcePath: source == PluginSource.builtIn
        ? '$sourcePath/PLUGIN.md'
        : p.join(sourcePath, 'PLUGIN.md'),
  );
  if (manifest.id != expectedId) {
    throw const PluginBundleFormatException(
      'Plugin manifest ID must match its directory name.',
      path: 'PLUGIN.md',
    );
  }
  if (rejectReservedId && _isReserved(manifest.id)) {
    throw const PluginBundleFormatException(
      'The tinest.* namespace is reserved for built-in plugins.',
      path: 'PLUGIN.md',
    );
  }
  if (!sortedAssets.containsKey(manifest.entrypoint)) {
    throw PluginBundleFormatException(
      'Plugin entrypoint does not exist in the revision bundle.',
      path: manifest.entrypoint,
    );
  }
  final contentHash = _bundleHash(sortedAssets);
  final sdkAbiHash = TinestLuaPluginSdk.sdkAbiHash;
  final executionRevisionHash = sha256
      .convert(utf8.encode('$contentHash\n$sdkAbiHash\n'))
      .toString();
  final revision = PluginRevisionDto(
    pluginId: manifest.id,
    contentHash: contentHash,
    manifestHash: sha256.convert(manifestBytes).toString(),
    sdkAbiHash: sdkAbiHash,
    executionRevisionHash: executionRevisionHash,
    requestedCapabilities: manifest.capabilities,
  );
  final descriptor = PluginDescriptorDto(
    apiMajor: 5,
    id: manifest.id,
    version: manifest.version,
    name: manifest.name,
    entrypoint: manifest.entrypoint,
    source: source,
    sourcePath: sourcePath,
    requestedCapabilities: manifest.capabilities,
    revision: revision,
  );
  return PluginBundle(
    descriptor: descriptor,
    revision: revision,
    assets: sortedAssets,
  );
}

String _relativeBundlePath(String root, String path) =>
    p.posix.joinAll(p.split(p.relative(path, from: root)));

void _registerCasePath(
  Map<String, String> paths,
  String relative,
  String sourcePath,
) {
  final folded = relative.toLowerCase();
  final prior = paths[folded];
  if (prior != null && prior != relative) {
    throw PluginBundleFormatException(
      'Plugin package contains case-colliding paths: $prior and $relative.',
      path: sourcePath,
    );
  }
  paths[folded] = relative;
}

({
  String id,
  String version,
  String name,
  String entrypoint,
  List<String> capabilities,
})
_parseManifest(String source, {required String sourcePath}) {
  final normalized = source.replaceAll('\r\n', '\n');
  final lines = normalized.split('\n');
  if (lines.isEmpty || lines.first.trim() != '---') {
    throw PluginBundleFormatException(
      'PLUGIN.md must start with YAML frontmatter.',
      path: sourcePath,
    );
  }
  final end = lines.indexWhere((line) => line.trim() == '---', 1);
  if (end < 0) {
    throw PluginBundleFormatException(
      'PLUGIN.md frontmatter is not closed.',
      path: sourcePath,
    );
  }
  Object? decoded;
  try {
    decoded = loadYaml(lines.sublist(1, end).join('\n'));
  } on YamlException catch (error) {
    throw PluginBundleFormatException(error.message, path: sourcePath);
  }
  if (decoded is! YamlMap) {
    throw PluginBundleFormatException(
      'PLUGIN.md frontmatter must be a map.',
      path: sourcePath,
    );
  }
  final values = <String, Object?>{};
  for (final entry in decoded.entries) {
    if (entry.key is! String) {
      throw PluginBundleFormatException(
        'Plugin manifest keys must be strings.',
        path: sourcePath,
      );
    }
    values[entry.key as String] = entry.value;
  }
  if (values['api'] != 5) {
    throw PluginBundleFormatException(
      'Unsupported plugin API major.',
      path: sourcePath,
    );
  }
  final id = _manifestString(values, 'id', sourcePath);
  _validatePluginId(id, allowReserved: true);
  final version = _manifestString(values, 'version', sourcePath);
  if (!RegExp(r'^\d+\.\d+\.\d+(?:[-+][a-zA-Z0-9.-]+)?$').hasMatch(version)) {
    throw PluginBundleFormatException(
      'Plugin version must be semantic version text.',
      path: sourcePath,
    );
  }
  final name = _manifestString(values, 'name', sourcePath);
  final entrypoint = _manifestString(values, 'entrypoint', sourcePath);
  if (p.isAbsolute(entrypoint) ||
      entrypoint.contains(r'\') ||
      p.posix.normalize(entrypoint) != entrypoint ||
      entrypoint.startsWith('../') ||
      p.posix.extension(entrypoint) != '.lua') {
    throw PluginBundleFormatException(
      'Plugin entrypoint must be a normalized relative Lua path.',
      path: sourcePath,
    );
  }
  final rawCapabilities = values['capabilities'];
  if (rawCapabilities is! YamlList ||
      rawCapabilities.any((value) => value is! String)) {
    throw PluginBundleFormatException(
      'Plugin capabilities must be a string list.',
      path: sourcePath,
    );
  }
  final capabilities = rawCapabilities.cast<String>().toList(growable: false);
  if (capabilities.toSet().length != capabilities.length) {
    throw PluginBundleFormatException(
      'Plugin capabilities cannot contain duplicates.',
      path: sourcePath,
    );
  }
  for (final capability in capabilities) {
    if (!RegExp(r'^[a-z][a-z0-9]*(?:\.[a-z][a-z0-9_]*)+$')
        .hasMatch(capability)) {
      throw PluginBundleFormatException(
        'Invalid plugin capability: $capability.',
        path: sourcePath,
      );
    }
  }
  return (
    id: id,
    version: version,
    name: name,
    entrypoint: entrypoint,
    capabilities: List<String>.unmodifiable(capabilities),
  );
}

String _manifestString(Map<String, Object?> values, String key, String path) {
  final value = values[key];
  if (value is! String || value.trim().isEmpty) {
    throw PluginBundleFormatException(
      'Plugin manifest $key must be a non-empty string.',
      path: path,
    );
  }
  return value.trim();
}

String _bundleHash(Map<String, Uint8List> assets) {
  final bytes = BytesBuilder(copy: false);
  for (final entry in assets.entries) {
    final pathBytes = utf8.encode(entry.key);
    bytes
      ..add(_uint64(pathBytes.length))
      ..add(pathBytes)
      ..add(_uint64(entry.value.length))
      ..add(entry.value);
  }
  return sha256.convert(bytes.takeBytes()).toString();
}

Uint8List _uint64(int value) =>
    (ByteData(8)..setUint64(0, value)).buffer.asUint8List();

void _validatePluginId(String id, {bool allowReserved = false}) {
  if (!RegExp(
    r'^[a-z][a-z0-9]*(?:-[a-z0-9]+)*(?:\.[a-z][a-z0-9]*(?:-[a-z0-9]+)*)+$',
  ).hasMatch(id)) {
    throw PluginBundleFormatException(
      'Plugin IDs require a lowercase dot-separated namespace.',
      path: id,
    );
  }
  if (!allowReserved && _isReserved(id)) {
    throw PluginBundleFormatException(
      'The tinest.* namespace is reserved for built-in plugins.',
      path: id,
    );
  }
}

bool _isReserved(String id) => id.startsWith('tinest.');

void _validateHash(String value) {
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
    throw PluginBundleFormatException(
      'Plugin revision hash is invalid.',
      path: value,
    );
  }
}

void _validateOwnerId(String value, {required String field}) {
  if (value.trim().isEmpty || utf8.encode(value).length > 256) {
    throw PluginBundleFormatException(
      '$field must be non-empty and at most 256 UTF-8 bytes.',
      path: value,
    );
  }
}

String _pointerName(String value) =>
    base64Url.encode(utf8.encode(value)).replaceAll('=', '');

bool _samePath(String left, String right) => p.equals(left, right);

bool _resolvesAsDirectChild(String source, String resolved) {
  final parent = Directory(p.dirname(source));
  final resolvedParent = p.normalize(parent.resolveSymbolicLinksSync());
  return _samePath(p.join(resolvedParent, p.basename(source)), resolved);
}

bool _isWithin(String root, String candidate) =>
    _samePath(root, candidate) || p.isWithin(root, candidate);

void _requireWithin(String root, String candidate) {
  if (!_isWithin(
    p.normalize(p.absolute(root)),
    p.normalize(p.absolute(candidate)),
  )) {
    throw PluginBundleFormatException(
      'Plugin asset path escapes its revision root.',
      path: candidate,
    );
  }
}

Future<void> _writeAtomic(File target, String contents) async {
  // A name built from the process ID and a top-level counter is not unique
  // across the isolates of one process: each holds its own counter starting at
  // zero. Let the OS pick a name nothing else holds and write inside it.
  final staging = await target.parent.createTemp(
    '.${p.basename(target.path)}.',
  );
  final temporary = File(p.join(staging.path, 'value'));
  try {
    await temporary.writeAsString(contents, flush: true);
    for (var attempt = 1; ; attempt += 1) {
      try {
        await temporary.rename(target.path);
        return;
      } on FileSystemException {
        // Windows denies replacing a destination while a concurrent writer
        // is replacing it at the same instant. Pointer writes for one
        // revision carry identical content, so the write has succeeded once
        // the destination carries this content; otherwise yield to let the
        // competing replace finish and retry, and only a destination that
        // never converges is a real filesystem failure.
        try {
          if (await target.readAsString() == contents) return;
        } on FileSystemException {
          // Destination unreadable mid-replacement; retry below.
        }
        if (attempt >= 32) rethrow;
        await Future<void>.delayed(Duration.zero);
      }
    }
  } finally {
    if (staging.existsSync()) await staging.delete(recursive: true);
  }
}
