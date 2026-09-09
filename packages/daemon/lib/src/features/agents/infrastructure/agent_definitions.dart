import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:protocol/protocol.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Raised when a GUI update races an external editor update.
final class AgentFileConflict implements Exception {
  /// Creates a conflict containing the current content hash.
  const new(this.currentContentHash);

  /// Hash the client must reload before trying another guarded update.
  final String currentContentHash;

  @override
  String toString() => 'agent_file_conflict: $currentContentHash';
}

/// Typed source-of-truth boundary for Markdown agent definitions.
abstract interface class AgentDefinitionStore {
  /// Emits after a valid catalog change or a stale diagnostic is detected.
  Stream<void> get changes;

  /// Loads files and creates the protected built-in Tinest file when absent.
  Future<void> initialize();

  /// Returns visible definitions.
  Future<List<AgentDefinitionDto>> list();

  /// Returns archived definitions retained for historical sessions.
  Future<List<AgentDefinitionDto>> listArchived();

  /// Returns one visible definition.
  Future<AgentDefinitionDto?> get(String id);

  /// Resolves visible and archived definitions for historical sessions.
  Future<AgentDefinitionDto?> resolve(String id);

  /// Creates one custom definition.
  Future<AgentDefinitionDto> create(String id, AgentDefinitionDto definition);

  /// Updates one definition using optimistic concurrency.
  Future<AgentDefinitionDto> update(
    AgentDefinitionDto definition, {
    required String expectedContentHash,
    bool force = false,
  });

  /// Atomically rewrites fixed-model prefixes in active and archived files.
  Future<void> rewriteModelPrefix(String oldPrefix, String newPrefix);

  /// Moves one custom definition to the archive directory.
  Future<void> archive(String id);

  /// Restores the canonical built-in Tinest definition.
  Future<AgentDefinitionDto> resetTinest();

  /// Reloads external file changes immediately.
  Future<void> reload();

  /// Stops filesystem observation.
  Future<void> close();
}

/// One Markdown document read from the agent definition filesystem boundary.
final class AgentDefinitionDocument {
  /// Creates an immutable document snapshot.
  const new({required this.id, required this.sourcePath, required this.source});

  /// Filename-derived stable agent ID.
  final String id;

  /// Absolute source path shown to connected daemon users.
  final String sourcePath;

  /// Complete Markdown source.
  final String source;
}

/// Typed filesystem and watcher boundary used by the Markdown catalog.
abstract interface class AgentDefinitionFiles {
  /// Emits when active or archived source files may have changed.
  Stream<void> get changes;

  /// Creates protected directories and starts native observation.
  Future<void> initialize();

  /// Returns a point-in-time snapshot of active Markdown files.
  Future<List<AgentDefinitionDocument>> readActive();

  /// Returns a point-in-time snapshot of archived Markdown files.
  Future<List<AgentDefinitionDocument>> readArchived();

  /// Returns the canonical active path for [id].
  String activePath(String id);

  /// Returns the canonical archive path for [id].
  String archivePath(String id);

  /// Atomically writes one active Markdown document.
  Future<void> writeActive(String id, String source);

  /// Atomically writes one archived Markdown document.
  Future<void> writeArchived(String id, String source);

  /// Atomically moves one active document into the archive.
  Future<void> archive(String id);

  /// Stops native observation.
  Future<void> close();
}

/// Native atomic filesystem adapter for `<configDirectory>/agents/*.md`.
final class NativeAgentDefinitionFiles implements AgentDefinitionFiles {
  /// Creates a native adapter rooted at the daemon config directory.
  new(String configDirectory)
    : _directory = Directory(p.join(configDirectory, 'agents')),
      _archiveDirectory = Directory(
        p.join(configDirectory, 'agents', '.archive'),
      );

  final Directory _directory;
  final Directory _archiveDirectory;
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );
  StreamSubscription<FileSystemEvent>? _watchSubscription;
  bool _initialized = false;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  String activePath(String id) => p.join(_directory.path, '$id.md');

  @override
  String archivePath(String id) => p.join(_archiveDirectory.path, '$id.md');

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    await _directory.create(recursive: true);
    await _archiveDirectory.create(recursive: true);
    await _restrictDirectory(_directory);
    await _restrictDirectory(_archiveDirectory);
    _watchSubscription = _directory.watch(recursive: true).listen((_) {
      _changes.add(null);
    });
    _initialized = true;
  }

  @override
  Future<List<AgentDefinitionDocument>> readActive() =>
      _readDirectory(_directory);

  @override
  Future<List<AgentDefinitionDocument>> readArchived() =>
      _readDirectory(_archiveDirectory);

  Future<List<AgentDefinitionDocument>> _readDirectory(
    Directory directory,
  ) async {
    final documents = <AgentDefinitionDocument>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || p.extension(entity.path) != '.md') continue;
      if (FileSystemEntity.typeSync(entity.path, followLinks: false) ==
          FileSystemEntityType.link) {
        continue;
      }
      try {
        documents.add(
          AgentDefinitionDocument(
            id: p.basenameWithoutExtension(entity.path),
            sourcePath: entity.path,
            source: await entity.readAsString(),
          ),
        );
      } on FileSystemException {
        // Atomic editors may replace an entry after directory enumeration.
        if (entity.existsSync()) rethrow;
      }
    }
    return documents;
  }

  @override
  Future<void> writeActive(String id, String source) =>
      _writeAtomic(File(activePath(id)), source);

  @override
  Future<void> writeArchived(String id, String source) =>
      _writeAtomic(File(archivePath(id)), source);

  @override
  Future<void> archive(String id) async {
    final source = File(activePath(id));
    final destination = File(archivePath(id));
    if (destination.existsSync()) destination.deleteSync();
    await source.rename(destination.path);
    await _restrictFile(destination);
  }

  Future<void> _writeAtomic(File file, String source) async {
    final temporary = File('${file.path}.$pid.tmp');
    try {
      await temporary.writeAsString(source, flush: true);
      await _restrictFile(temporary);
      // `rename` replaces the destination on its own; unlinking it first
      // throws while anything else holds the file and loses the definition
      // outright if the process stops between the two calls.
      await temporary.rename(file.path);
      await _restrictFile(file);
    } finally {
      if (temporary.existsSync()) temporary.deleteSync();
    }
  }

  Future<void> _restrictDirectory(Directory directory) async {
    if (!Platform.isWindows) {
      await Process.run('chmod', <String>['700', directory.path]);
    }
  }

  Future<void> _restrictFile(File file) async {
    if (!Platform.isWindows) {
      await Process.run('chmod', <String>['600', file.path]);
    }
  }

  @override
  Future<void> close() async {
    await _watchSubscription?.cancel();
    await _changes.close();
  }
}

/// Serialized source-of-truth catalog for Markdown agent definitions.
final class FileAgentDefinitionStore implements AgentDefinitionStore {
  /// Creates a production store rooted at the daemon config directory.
  new(
    String configDirectory, {
    AgentMarkdownCodec codec = const AgentMarkdownCodec(),
    Duration watchDebounce = const Duration(milliseconds: 200),
  }) : this.withFiles(
         NativeAgentDefinitionFiles(configDirectory),
         codec: codec,
         watchDebounce: watchDebounce,
       );

  /// Creates a store with an injected deterministic filesystem boundary.
  new withFiles(
    this._files, {
    this.codec = const AgentMarkdownCodec(),
    this.watchDebounce = const Duration(milliseconds: 200),
  });

  /// Codec used for preserving frontmatter formatting and unknown fields.
  final AgentMarkdownCodec codec;

  /// Delay used to coalesce native editor event bursts.
  final Duration watchDebounce;

  final AgentDefinitionFiles _files;
  Map<String, AgentDefinitionDto> _active = <String, AgentDefinitionDto>{};
  Map<String, AgentDefinitionDto> _archived = <String, AgentDefinitionDto>{};
  Map<String, String> _sources = <String, String>{};
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );
  Future<void> _operationTail = Future<void>.value();
  Future<void>? _initializeFuture;
  StreamSubscription<void>? _watchSubscription;
  Timer? _reloadTimer;
  Future<void>? _watchReload;
  bool _closed = false;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<void> initialize() {
    _ensureOpen();
    return _initializeFuture ??= _serialize(() async {
      await _files.initialize();
      await _reloadLocked();
      if (!_closed) {
        _watchSubscription = _files.changes.listen((_) => _scheduleReload());
      }
    });
  }

  @override
  Future<List<AgentDefinitionDto>> list() async {
    await initialize();
    return await _serialize(() async {
      final definitions = _active.values.toList(growable: false)
        ..sort((left, right) {
          if (left.id == 'tinest') return -1;
          if (right.id == 'tinest') return 1;
          return left.name.compareTo(right.name);
        });
      return definitions;
    });
  }

  @override
  Future<List<AgentDefinitionDto>> listArchived() async {
    await initialize();
    return await _serialize(
      () async => List<AgentDefinitionDto>.unmodifiable(_archived.values),
    );
  }

  @override
  Future<AgentDefinitionDto?> get(String id) async {
    await initialize();
    return await _serialize(() async => _active[id]);
  }

  @override
  Future<AgentDefinitionDto?> resolve(String id) async {
    await initialize();
    return await _serialize(() async => _active[id] ?? _archived[id]);
  }

  @override
  Future<AgentDefinitionDto> create(
    String id,
    AgentDefinitionDto definition,
  ) async {
    await initialize();
    return await _serialize(() async {
      _validateId(id);
      if (id == 'tinest' ||
          _active.containsKey(id) ||
          _archived.containsKey(id)) {
        throw StateError('Agent definition already exists: $id');
      }
      if (definition.id != id) {
        throw const FormatException(
          'Filename ID and definition ID must match.',
        );
      }
      final source = codec.encodeNew(definition);
      codec.decode(id: id, sourcePath: _files.activePath(id), source: source);
      await _files.writeActive(id, source);
      await _reloadLocked();
      return _active[id]!;
    });
  }

  @override
  Future<AgentDefinitionDto> update(
    AgentDefinitionDto definition, {
    required String expectedContentHash,
    bool force = false,
  }) async {
    await initialize();
    return await _serialize(() async {
      final current = _active[definition.id];
      if (current == null) {
        throw StateError('Agent definition not found: ${definition.id}');
      }
      if (!force && current.contentHash != expectedContentHash) {
        throw AgentFileConflict(current.contentHash);
      }
      if (current.mode != definition.mode) {
        throw const FormatException(
          'Agent mode cannot be changed after create.',
        );
      }
      final original = _sources[definition.id];
      if (original == null) {
        throw StateError('Agent source is unavailable: ${definition.id}');
      }
      final source = codec.encodeUpdate(
        originalSource: original,
        definition: definition,
      );
      codec.decode(
        id: definition.id,
        sourcePath: current.sourcePath,
        source: source,
      );
      await _files.writeActive(definition.id, source);
      await _reloadLocked();
      return _active[definition.id]!;
    });
  }

  @override
  Future<void> rewriteModelPrefix(String oldPrefix, String newPrefix) async {
    await initialize();
    await _serialize(() async {
      await _reloadLocked();
      final writes =
          <({String id, String before, String after, bool archived})>[];
      for (final entry in <({AgentDefinitionDto value, bool archived})>[
        for (final value in _active.values) (value: value, archived: false),
        for (final value in _archived.values) (value: value, archived: true),
      ]) {
        final definition = entry.value;
        final modelId = definition.model.modelId;
        if (definition.model.source != AgentModelSource.fixed ||
            modelId == null ||
            !modelId.startsWith('$oldPrefix/')) {
          continue;
        }
        final before = _sources[definition.id];
        if (before == null) {
          throw StateError('Agent source is unavailable: ${definition.id}');
        }
        final after = codec.encodeUpdate(
          originalSource: before,
          definition: definition.copyWith(
            model: AgentModelSelectionDto(
              source: AgentModelSource.fixed,
              modelId: '$newPrefix/${modelId.substring(oldPrefix.length + 1)}',
            ),
          ),
        );
        codec.decode(
          id: definition.id,
          sourcePath: definition.sourcePath,
          source: after,
          isArchived: entry.archived,
        );
        writes.add((
          id: definition.id,
          before: before,
          after: after,
          archived: entry.archived,
        ));
      }
      final completed = <({String id, String before, bool archived})>[];
      try {
        for (final write in writes) {
          if (write.archived) {
            await _files.writeArchived(write.id, write.after);
          } else {
            await _files.writeActive(write.id, write.after);
          }
          completed.add((
            id: write.id,
            before: write.before,
            archived: write.archived,
          ));
        }
      } catch (_) {
        for (final write in completed.reversed) {
          if (write.archived) {
            await _files.writeArchived(write.id, write.before);
          } else {
            await _files.writeActive(write.id, write.before);
          }
        }
        rethrow;
      }
      await _reloadLocked();
    });
  }

  @override
  Future<void> archive(String id) async {
    await initialize();
    await _serialize(() async {
      if (id == 'tinest') {
        throw StateError('The built-in Tinest agent cannot be archived.');
      }
      if (!_active.containsKey(id)) {
        throw StateError('Agent definition not found: $id');
      }
      await _files.archive(id);
      await _reloadLocked();
    });
  }

  @override
  Future<AgentDefinitionDto> resetTinest() async {
    await initialize();
    return await _serialize(() async {
      final source = codec.encodeNew(
        _defaultTinest(_files.activePath('tinest')),
      );
      await _files.writeActive('tinest', source);
      await _reloadLocked();
      return _active['tinest']!;
    });
  }

  @override
  Future<void> reload() async {
    await initialize();
    await _serialize(_reloadLocked);
  }

  Future<void> _reloadLocked() async {
    var activeDocuments = await _files.readActive();
    if (!activeDocuments.any((document) => document.id == 'tinest')) {
      await _writeDefaultTinest();
      activeDocuments = await _files.readActive();
    }
    var snapshot = _parseSnapshot(
      activeDocuments: activeDocuments,
      archivedDocuments: await _files.readArchived(),
    );
    if (!snapshot.active.containsKey('tinest')) {
      await _writeDefaultTinest();
      snapshot = _parseSnapshot(
        activeDocuments: await _files.readActive(),
        archivedDocuments: await _files.readArchived(),
      );
    }
    _active = snapshot.active;
    _archived = snapshot.archived;
    _sources = snapshot.sources;
    _changes.add(null);
  }

  _AgentCatalogSnapshot _parseSnapshot({
    required List<AgentDefinitionDocument> activeDocuments,
    required List<AgentDefinitionDocument> archivedDocuments,
  }) {
    final active = <String, AgentDefinitionDto>{};
    final archived = <String, AgentDefinitionDto>{};
    final sources = <String, String>{};
    void parse(AgentDefinitionDocument document, {required bool isArchived}) {
      final previous = (isArchived ? _archived : _active)[document.id];
      try {
        _validateId(document.id);
        final parsed = codec.decode(
          id: document.id,
          sourcePath: document.sourcePath,
          source: document.source,
          isArchived: isArchived,
        );
        (isArchived ? archived : active)[document.id] = parsed;
        sources[document.id] = document.source;
      } on FormatException catch (error) {
        if (previous == null) return;
        (isArchived ? archived : active)[document.id] = previous.copyWith(
          isStale: true,
          diagnostics: <AgentDefinitionDiagnosticDto>[
            AgentDefinitionDiagnosticDto(
              code: 'invalid_agent_markdown',
              message: error.message,
              line: switch (error) {
                YamlException(:final span?) => span.start.line + 1,
                _ => null,
              },
              column: switch (error) {
                YamlException(:final span?) => span.start.column + 1,
                _ => null,
              },
            ),
          ],
        );
        final previousSource = _sources[document.id];
        if (previousSource != null) sources[document.id] = previousSource;
      }
    }

    for (final document in activeDocuments) {
      parse(document, isArchived: false);
    }
    for (final document in archivedDocuments) {
      parse(document, isArchived: true);
    }
    return _AgentCatalogSnapshot(
      active: active,
      archived: archived,
      sources: sources,
    );
  }

  Future<void> _writeDefaultTinest() => _files.writeActive(
    'tinest',
    codec.encodeNew(_defaultTinest(_files.activePath('tinest'))),
  );

  void _scheduleReload() {
    if (_closed) return;
    _reloadTimer?.cancel();
    _reloadTimer = Timer(watchDebounce, () {
      if (_closed) return;
      final reloadFuture = _serialize(_reloadLocked);
      _watchReload = reloadFuture;
      unawaited(
        reloadFuture.then<void>(
          (_) {},
          onError: (Object error, StackTrace stackTrace) {
            if (!_closed) Zone.current.handleUncaughtError(error, stackTrace);
          },
        ),
      );
    });
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final previous = _operationTail;
    final release = Completer<void>();
    _operationTail = release.future;
    Future<T> run() async {
      await previous;
      try {
        return await operation();
      } finally {
        release.complete();
      }
    }

    return run();
  }

  void _ensureOpen() {
    if (_closed) throw StateError('Agent definition store is closed.');
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _reloadTimer?.cancel();
    await _watchSubscription?.cancel();
    await _watchReload;
    await _operationTail;
    await _files.close();
    await _changes.close();
  }
}

final class _AgentCatalogSnapshot {
  const new({
    required this.active,
    required this.archived,
    required this.sources,
  });

  final Map<String, AgentDefinitionDto> active;
  final Map<String, AgentDefinitionDto> archived;
  final Map<String, String> sources;
}

/// Labels YAML parse errors with the document they came from.
///
/// Validating an unsaved document passes a synthetic marker rather than a
/// real path, and Windows rejects the characters such a marker contains in a
/// file URI. The label is a diagnostic convenience, so anything that is not an
/// absolute path simply goes unlabelled instead of failing the parse.
Uri? _yamlSourceUrl(String sourcePath) =>
    p.isAbsolute(sourcePath) ? Uri.file(sourcePath) : null;

AgentDefinitionDto _defaultTinest(String sourcePath) => AgentDefinitionDto(
  version: 5,
  id: 'tinest',
  name: 'Tinest',
  description: 'General-purpose coding agent',
  mode: AgentMode.primary,
  model: const AgentModelSelectionDto(source: AgentModelSource.session),
  driverId: 'tinest.standard/driver',
  extensionIds: const <String>['tinest.skills', 'tinest.collaboration'],
  toolIds: const <String>[
    'tinest.edit/apply_patch',
    'tinest.mcp/list_resources',
    'tinest.mcp/list_resource_templates',
    'tinest.mcp/read_resource',
    'tinest.terminal/exec_command',
    'tinest.terminal/write_stdin',
    'tinest.collaboration/spawn_agent',
    'tinest.collaboration/send_message',
    'tinest.collaboration/followup_task',
    'tinest.collaboration/wait_agent',
    'tinest.collaboration/interrupt_agent',
    'tinest.collaboration/list_agents',
  ],
  pluginSettings: const <String, Map<String, dynamic>>{},
  callableAgentIds: const <String>[],
  prompt:
      'You are a coding agent. Read relevant code before editing and validate '
      'your work.',
  contentHash: '',
  sourcePath: sourcePath,
  isBuiltIn: true,
);

/// Validated Lua registration metadata available to Agent configuration.
///
/// Implementations return revision-backed plugin descriptors, never a Dart
/// reconstruction of model-visible tool metadata.
abstract interface class AgentContributionCatalog {
  /// Lists installed plugin descriptors enriched by Lua registration.
  Future<List<PluginDescriptorDto>> listPluginDescriptors();

  /// Emits whenever the validated contribution set may have changed.
  Stream<void> get changes;
}

/// An agent definition a caller referenced could not be used.
///
/// Typed rather than a bare [StateError] so the session-create transport can
/// report which agent is missing instead of collapsing into a generic internal
/// failure the user cannot act on.
final class AgentDefinitionLookupFailure implements Exception {
  /// Reports a definition that no longer exists.
  const new notFound(this.id)
    : message = 'Agent definition not found: $id',
      isMissing = true;

  /// Reports a definition that exists but cannot start a session.
  const new unusable(this.id, this.message) : isMissing = false;

  /// Identifier the caller referenced.
  final String id;

  /// Diagnostic description; clients translate the protocol code instead.
  final String message;

  /// Whether the definition is absent rather than merely unusable.
  final bool isMissing;

  @override
  String toString() => 'AgentDefinitionLookupFailure($id): $message';
}

/// Validates domain relationships independently of filesystem mechanics.
final class AgentDefinitionService {
  /// Creates an agent definition application service.
  new({
    required this._store,
    required this._contributions,
    this.codec = const AgentMarkdownCodec(),
  });

  final AgentDefinitionStore _store;
  final AgentContributionCatalog _contributions;

  /// Codec used for validation-only RPC requests.
  final AgentMarkdownCodec codec;

  /// Emits after source files, diagnostics, or the tool catalog change.
  Stream<void> get changes =>
      StreamGroup.merge(<Stream<void>>[_store.changes, _contributions.changes]);

  /// Initializes the source store.
  Future<void> initialize() => _store.initialize();

  /// Returns definitions with source diagnostics preserved.
  Future<List<AgentDefinitionDto>> list() async =>
      await Future.wait((await _store.list()).map(_decorate));

  /// Returns one visible definition.
  Future<AgentDefinitionDto> get(String id) async {
    final definition = await _store.get(id);
    if (definition == null) throw AgentDefinitionLookupFailure.notFound(id);
    return await _decorate(definition);
  }

  /// Resolves active or archived configuration for a turn snapshot.
  Future<AgentDefinitionDto> resolve(String id) async {
    final definition = await _store.resolve(id);
    if (definition == null) throw AgentDefinitionLookupFailure.notFound(id);
    if (definition.isStale && definition.contentHash.isEmpty) {
      throw AgentDefinitionLookupFailure.unusable(
        id,
        'Agent definition is invalid: $id',
      );
    }
    return await _decorate(definition);
  }

  /// Returns model tools exactly as validated Lua registrations declared them.
  Future<List<AgentToolDefinitionDto>> toolCatalog() async {
    final tools = <AgentToolDefinitionDto>[
      for (final descriptor in await _contributions.listPluginDescriptors())
        if (descriptor.revision != null)
          for (final contribution in descriptor.contributions)
            if (contribution.kind == PluginContributionKind.tool &&
                contribution.tool != null)
              contribution.tool!,
    ]..sort((left, right) => left.name.compareTo(right.name));
    return List<AgentToolDefinitionDto>.unmodifiable(tools);
  }

  /// Whether an active or archived definition fixes itself to a connection.
  Future<bool> referencesProvider(String modelPrefix) async {
    final definitions = <AgentDefinitionDto>[
      ...await _store.list(),
      ...await _store.listArchived(),
    ];
    return definitions.any(
      (definition) =>
          definition.model.source == AgentModelSource.fixed &&
          definition.model.modelId?.startsWith('$modelPrefix/') == true,
    );
  }

  /// Rewrites fixed-model references in active and archived definitions.
  Future<void> rewriteModelPrefix(String oldPrefix, String newPrefix) =>
      _store.rewriteModelPrefix(oldPrefix, newPrefix);

  /// Creates a custom definition after validating references.
  Future<AgentDefinitionDto> create(
    String id,
    AgentDefinitionDto definition,
  ) async {
    await _validateReferences(definition);
    return await _decorate(await _store.create(id, definition));
  }

  /// Updates a definition after validating immutable and cross-file rules.
  Future<AgentDefinitionDto> update(
    AgentDefinitionDto definition, {
    required String expectedContentHash,
    bool force = false,
  }) async {
    await _validateReferences(definition);
    return await _decorate(
      await _store.update(
        definition,
        expectedContentHash: expectedContentHash,
        force: force,
      ),
    );
  }

  /// Archives a custom definition and removes it from primary allowlists.
  Future<void> archive(String id) async {
    await _store.archive(id);
    for (final definition in await _store.list()) {
      if (!definition.callableAgentIds.contains(id)) continue;
      await _store.update(
        definition.copyWith(
          callableAgentIds: definition.callableAgentIds
              .where((candidate) => candidate != id)
              .toList(growable: false),
        ),
        expectedContentHash: definition.contentHash,
      );
    }
  }

  /// Restores the protected built-in Tinest definition.
  Future<AgentDefinitionDto> reset(String id) async {
    if (id != 'tinest') {
      throw StateError('Only the built-in Tinest agent can be reset.');
    }
    return await _decorate(await _store.resetTinest());
  }

  /// Parses and validates one unsaved Markdown document.
  Future<AgentDefinitionDto> validate(String id, String markdown) async {
    final parsed = codec.decode(
      id: id,
      sourcePath: '<validation>/$id.md',
      source: markdown,
    );
    await _validateReferences(parsed);
    return await _decorate(parsed);
  }

  Future<void> _validateReferences(AgentDefinitionDto definition) async {
    if (definition.mode == AgentMode.subagent &&
        definition.callableAgentIds.isNotEmpty) {
      throw const FormatException('Subagents cannot call other agents.');
    }
    final definitions = <String, AgentDefinitionDto>{
      for (final item in await _store.list()) item.id: item,
    };
    for (final id in definition.callableAgentIds) {
      final target = definitions[id];
      if (target == null ||
          target.isArchived ||
          target.isStale ||
          target.mode != AgentMode.subagent) {
        throw FormatException('Callable agent must be an active subagent: $id');
      }
    }
  }

  Future<AgentDefinitionDto> _decorate(AgentDefinitionDto definition) async =>
      definition.copyWith(
        // A Dart host-primitive registry cannot validate public Lua plugin
        // contributions. Plugin management and the revision-pinned harness
        // own that check, which also lets app-data plugins participate on the
        // same terms as embedded ones.
        diagnostics: definition.diagnostics
            .where((diagnostic) => diagnostic.code != 'unavailable_tool')
            .toList(growable: false),
      );

  /// Stops file observation.
  Future<void> close() => _store.close();
}

/// Parses and updates the Tinest agent Markdown format.
final class AgentMarkdownCodec {
  /// Creates the stateless Markdown codec.
  const new();

  /// Parses one Markdown document into a typed definition.
  AgentDefinitionDto decode({
    required String id,
    required String sourcePath,
    required String source,
    bool isArchived = false,
  }) {
    _validateId(id);
    final document = _AgentMarkdownDocument.parse(source);
    final decoded = loadYaml(
      document.frontmatter,
      sourceUrl: _yamlSourceUrl(sourcePath),
    );
    if (decoded is! YamlMap) {
      throw const FormatException('Agent frontmatter must be a YAML map.');
    }
    final frontmatter = _stringMap(decoded);
    if (_requiredInt(frontmatter, 'version') != 5) {
      throw const FormatException('Unsupported agent Markdown version.');
    }
    final mode = _enumValue(
      AgentMode.values,
      _requiredString(frontmatter, 'mode'),
      'mode',
    );
    final modelMap = _requiredMap(frontmatter, 'model');
    final modelSource = _enumValue(
      AgentModelSource.values,
      _requiredString(modelMap, 'source'),
      'model.source',
    );
    final modelId = _optionalString(modelMap, 'modelId');
    if (modelSource == AgentModelSource.fixed && modelId == null) {
      throw const FormatException(
        'Fixed agent models require a qualified modelId.',
      );
    }
    final driverId = _requiredString(frontmatter, 'driver');
    _validateContributionId(driverId, field: 'driver');
    final extensionIds = _stringList(frontmatter, 'extensions');
    _validateUnique(extensionIds, field: 'extensions');
    for (final extensionId in extensionIds) {
      _validatePluginId(extensionId, field: 'extensions');
    }
    final toolIds = _stringList(frontmatter, 'tools');
    _validateUnique(toolIds, field: 'tools');
    for (final toolId in toolIds) {
      _validateContributionId(toolId, field: 'tools');
    }
    final pluginSettings = _pluginSettings(frontmatter['pluginSettings']);
    final activePluginIds = <String>{
      _contributionPluginId(driverId),
      ...extensionIds,
      for (final toolId in toolIds) _contributionPluginId(toolId),
    };
    for (final pluginId in pluginSettings.keys) {
      if (!activePluginIds.contains(pluginId)) {
        throw FormatException(
          'pluginSettings references an inactive plugin: $pluginId.',
        );
      }
    }
    final callableAgentIds = _stringList(frontmatter, 'callableAgents');
    _validateUnique(callableAgentIds, field: 'callableAgents');
    callableAgentIds.forEach(_validateId);
    if (mode == AgentMode.subagent && callableAgentIds.isNotEmpty) {
      throw const FormatException('Subagents cannot call other agents.');
    }
    return AgentDefinitionDto(
      version: 5,
      id: id,
      name: _requiredString(frontmatter, 'name'),
      description: _requiredStringAllowEmpty(frontmatter, 'description'),
      mode: mode,
      model: AgentModelSelectionDto(source: modelSource, modelId: modelId),
      driverId: driverId,
      extensionIds: extensionIds,
      toolIds: toolIds,
      pluginSettings: pluginSettings,
      callableAgentIds: callableAgentIds,
      prompt: document.body.trim(),
      contentHash: sha256.convert(utf8.encode(source)).toString(),
      sourcePath: sourcePath,
      isBuiltIn: id == 'tinest',
      isArchived: isArchived,
    );
  }

  /// Rewrites known fields while retaining unknown YAML and comments.
  String encodeUpdate({
    required String originalSource,
    required AgentDefinitionDto definition,
  }) {
    final document = _AgentMarkdownDocument.parse(originalSource);
    final editor = YamlEditor(document.frontmatter)
      ..update(<Object>['version'], 5)
      ..update(<Object>['name'], definition.name)
      ..update(<Object>['description'], definition.description)
      ..update(<Object>['mode'], definition.mode.name)
      ..update(<Object>['model'], _modelMap(definition.model))
      ..update(<Object>['driver'], definition.driverId)
      ..update(<Object>['extensions'], definition.extensionIds)
      ..update(<Object>['tools'], definition.toolIds)
      ..update(<Object>['pluginSettings'], definition.pluginSettings)
      ..update(<Object>['callableAgents'], definition.callableAgentIds);
    return '---\n$editor\n---\n\n${definition.prompt.trim()}\n';
  }

  /// Creates a canonical new Markdown document.
  String encodeNew(AgentDefinitionDto definition) {
    final editor = YamlEditor('')
      ..update(<Object>[], <String, Object?>{
        'version': 5,
        'name': definition.name,
        'description': definition.description,
        'mode': definition.mode.name,
        'model': _modelMap(definition.model),
        'driver': definition.driverId,
        'extensions': definition.extensionIds,
        'tools': definition.toolIds,
        'pluginSettings': definition.pluginSettings,
        'callableAgents': definition.callableAgentIds,
      });
    return '---\n$editor\n---\n\n${definition.prompt.trim()}\n';
  }

  static Map<String, Object?> _modelMap(AgentModelSelectionDto model) =>
      <String, Object?>{'source': model.source.name, 'modelId': ?model.modelId};
}

final class _AgentMarkdownDocument {
  const new({required this.frontmatter, required this.body});

  factory parse(String source) {
    final normalized = source.replaceAll('\r\n', '\n');
    final lines = normalized.split('\n');
    var start = 0;
    while (start < lines.length && lines[start].trim().isEmpty) {
      start += 1;
    }
    if (start == lines.length || lines[start].trim() != '---') {
      throw const FormatException(
        'Agent Markdown must start with frontmatter.',
      );
    }
    var end = start + 1;
    while (end < lines.length && lines[end].trim() != '---') {
      end += 1;
    }
    if (end == lines.length) {
      throw const FormatException('Agent Markdown frontmatter is not closed.');
    }
    return _AgentMarkdownDocument(
      frontmatter: lines.sublist(start + 1, end).join('\n'),
      body: lines.sublist(end + 1).join('\n'),
    );
  }

  final String frontmatter;
  final String body;
}

void _validateId(String id) {
  if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(id)) {
    throw const FormatException('Invalid agent definition ID.');
  }
}

Map<String, Object?> _stringMap(YamlMap value) {
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw const FormatException('Agent frontmatter keys must be strings.');
    }
    result[entry.key as String] = _plainValue(entry.value);
  }
  return result;
}

Object? _plainValue(Object? value) => switch (value) {
  YamlMap() => _stringMap(value),
  YamlList() => value.nodes.map((node) => _plainValue(node.value)).toList(),
  _ => value,
};

Map<String, Object?> _requiredMap(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! Map<String, Object?>) {
    throw FormatException('$key must be a map.');
  }
  return value;
}

String _requiredString(Map<String, Object?> map, String key) {
  final value = _optionalString(map, key);
  if (value == null) throw FormatException('$key must be a non-empty string.');
  return value;
}

String _requiredStringAllowEmpty(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String) throw FormatException('$key must be a string.');
  return value.trim();
}

String? _optionalString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value.trim();
}

int _requiredInt(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

List<String> _stringList(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! List<Object?> || value.any((item) => item is! String)) {
    throw FormatException('$key must be a string list.');
  }
  return List<String>.unmodifiable(value.cast<String>());
}

Map<String, Map<String, dynamic>> _pluginSettings(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('pluginSettings must be a map.');
  }
  final result = <String, Map<String, dynamic>>{};
  for (final entry in value.entries) {
    _validatePluginId(entry.key, field: 'pluginSettings');
    if (entry.value is! Map<String, Object?>) {
      throw FormatException('pluginSettings.${entry.key} must be a map.');
    }
    result[entry.key] = _jsonMap(
      entry.value! as Map<String, Object?>,
      field: 'pluginSettings.${entry.key}',
    );
  }
  return Map<String, Map<String, dynamic>>.unmodifiable(result);
}

Map<String, dynamic> _jsonMap(
  Map<String, Object?> value, {
  required String field,
}) => <String, dynamic>{
  for (final entry in value.entries)
    entry.key: _jsonValue(entry.value, field: '$field.${entry.key}'),
};

Object? _jsonValue(Object? value, {required String field}) => switch (value) {
  null || String() || bool() || num() => value,
  List<Object?>() => <Object?>[
    for (var index = 0; index < value.length; index += 1)
      _jsonValue(value[index], field: '$field[$index]'),
  ],
  Map<String, Object?>() => _jsonMap(value, field: field),
  _ => throw FormatException('$field must contain only JSON values.'),
};

void _validateUnique(List<String> values, {required String field}) {
  if (values.toSet().length != values.length) {
    throw FormatException('$field cannot contain duplicates.');
  }
}

void _validatePluginId(String id, {required String field}) {
  if (!RegExp(
    r'^[a-z][a-z0-9]*(?:-[a-z0-9]+)*(?:\.[a-z][a-z0-9]*(?:-[a-z0-9]+)*)+$',
  ).hasMatch(id)) {
    throw FormatException('$field contains an invalid plugin ID: $id.');
  }
}

void _validateContributionId(String id, {required String field}) {
  final slash = id.indexOf('/');
  if (slash <= 0 || slash != id.lastIndexOf('/') || slash == id.length - 1) {
    throw FormatException('$field contains an invalid contribution ID: $id.');
  }
  _validatePluginId(id.substring(0, slash), field: field);
  if (!RegExp(r'^[a-z][a-z0-9_-]{0,63}$').hasMatch(id.substring(slash + 1))) {
    throw FormatException('$field contains an invalid contribution ID: $id.');
  }
}

String _contributionPluginId(String id) => id.substring(0, id.indexOf('/'));

T _enumValue<T extends Enum>(List<T> values, String name, String field) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('Unsupported $field: $name.');
}
