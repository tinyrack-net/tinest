import 'dart:async';
import 'dart:io';

import 'package:agent/agent.dart';
import 'package:daemon/src/features/prompts/infrastructure/built_in_skills.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:path/path.dart' as p;
import 'package:protocol/protocol.dart';
import 'package:yaml/yaml.dart';

/// Selects which project, if any, participates in skill resolution.
final class SkillScope {
  /// Creates a scope; [projectRoot] is null for global sources alone.
  const new({this.projectRoot});

  /// Global sources with no project overlay.
  static const SkillScope global = SkillScope();

  /// Absolute workspace root containing `.agents/skills`.
  final String? projectRoot;
}

/// Daemon-internal origin of a skill candidate.
enum SkillOrigin {
  /// Skill shipped inside the daemon binary.
  builtIn,

  /// Skill loaded from the user's shared `~/.agents/skills` tree.
  userHome,

  /// Skill loaded from the daemon configuration directory.
  config,

  /// Skill loaded from a project's `.agents/skills` tree.
  project,
}

/// One skill document read from a filesystem boundary.
final class SkillDocument {
  /// Creates an immutable document snapshot.
  const new({
    required this.id,
    required this.sourcePath,
    required this.source,
    required this.directory,
  });

  /// Directory-derived stable skill ID.
  final String id;

  /// Absolute path of `SKILL.md`.
  final String sourcePath;

  /// Complete Markdown source.
  final String source;

  /// Absolute directory holding the document and its bundled files.
  final String directory;
}

/// Metadata for one file bundled beside a skill document.
final class SkillResource {
  /// Creates resource metadata.
  const new({required this.path, required this.sizeBytes});

  /// Forward-slash relative path within the skill directory.
  final String path;

  /// Current resource size in bytes.
  final int sizeBytes;
}

/// Typed read-only filesystem and watcher boundary for one skills root.
abstract interface class SkillFiles {
  /// Origin represented by this root.
  SkillOrigin get origin;

  /// Emits when source files may have changed.
  Stream<void> get changes;

  /// Creates an owned root when requested and starts observation.
  Future<void> initialize();

  /// Returns a point-in-time snapshot of readable skill documents.
  Future<List<SkillDocument>> read();

  /// Lists files bundled next to [id], excluding `SKILL.md`.
  Future<List<SkillResource>> resources(String id);

  /// Stops observation.
  Future<void> close();
}

/// Matches native watcher paths against one intended skills root.
///
/// A watcher may temporarily move up to an existing ancestor while the skills
/// root is absent. Relative events are rooted at that watched directory so
/// sibling activity does not become a catalog refresh.
final class SkillWatchPathFilter {
  /// Creates a normalized path filter for one watcher subscription.
  new({required String skillRoot, required String watchedRoot})
    : _skillRoot = p.normalize(p.absolute(skillRoot)),
      _watchedRoot = p.normalize(p.absolute(watchedRoot));

  final String _skillRoot;
  final String _watchedRoot;

  /// Whether [eventPath] can create, remove, or change the skills root.
  ///
  /// Some native watchers report only the watched ancestor for every direct
  /// child change. An ancestor event is relevant only once the skills root
  /// exists; otherwise unrelated siblings would trigger catalog refreshes.
  bool accepts(String eventPath, {required bool skillRootExists}) {
    final changed = p.normalize(
      p.isRelative(eventPath) || p.isRootRelative(eventPath)
          ? p.join(_watchedRoot, eventPath)
          : eventPath,
    );
    return p.equals(changed, _skillRoot) ||
        p.isWithin(_skillRoot, changed) ||
        (skillRootExists && p.isWithin(changed, _skillRoot));
  }
}

/// One native filesystem notification, reduced to what the watcher reads.
///
/// `dart:io` keeps every `FileSystemEvent` constructor private, so a test can
/// observe native events but never produce one. Carrying the two fields the
/// watcher actually uses lets the arming and delivery order be driven directly
/// instead of being provoked by load.
final class SkillWatchEvent {
  /// Creates a notification for [path], moved to [destination] when renamed.
  const new({required this.path, this.destination});

  /// The entry that changed, or the watched directory on watchers that report
  /// only the directory for every direct child change.
  final String path;

  /// Where [path] was moved, when the notification describes a rename.
  final String? destination;
}

/// Opens a non-recursive native watch over one directory.
typedef SkillWatchOpener = Stream<SkillWatchEvent> Function(String path);

Stream<SkillWatchEvent> _openNativeWatch(String path) =>
    Directory(path).watch().map(
      (event) => SkillWatchEvent(
        path: event.path,
        destination: event is FileSystemMoveEvent ? event.destination : null,
      ),
    );

/// Native filesystem adapter for one `<root>/<id>/SKILL.md` tree.
final class NativeSkillFiles implements SkillFiles {
  /// Creates an adapter rooted at one skills directory.
  ///
  /// [createIfMissing] is reserved for the daemon-owned configuration root.
  /// Shared and project trees retain the permissions chosen by their owner.
  /// [openWatch] is a seam for tests that need to control when a watch is
  /// armed relative to the directories appearing under it.
  new(
    String root, {
    required this.origin,
    this.createIfMissing = false,
    this.maxResources = 200,
    this.openWatch = _openNativeWatch,
  }) : _directory = Directory(root);

  static const String _documentName = 'SKILL.md';

  @override
  final SkillOrigin origin;

  /// Whether the daemon owns and may create this root.
  final bool createIfMissing;

  /// Upper bound on bundled files reported for one skill.
  final int maxResources;

  /// Opens the native watch behind every directory this adapter tracks.
  final SkillWatchOpener openWatch;

  final Directory _directory;
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );
  final Map<String, StreamSubscription<SkillWatchEvent>> _watchSubscriptions =
      <String, StreamSubscription<SkillWatchEvent>>{};
  Future<void> _watchTail = Future<void>.value();
  bool _initialized = false;
  bool _closed = false;

  @override
  Stream<void> get changes => _changes.stream;

  /// Paths this adapter currently holds a native watch on.
  ///
  /// A change that never arrives is indistinguishable from a write that never
  /// landed unless the test can say where the watcher actually was. This has
  /// failed only on loaded CI hosts, where the filesystem and the kernel
  /// budgets both looked healthy, so the watcher's own position is the missing
  /// fact.
  ///
  /// Read by tests only; nothing in the daemon needs it.
  Set<String> get watchedPaths =>
      Set<String>.unmodifiable(_watchSubscriptions.keys);

  String _skillDirectory(String id) => p.join(_directory.path, id);

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    if (createIfMissing) {
      await _directory.create(recursive: true);
      await _restrict(_directory.path, '700');
    }
    _initialized = true;
    await _ensureWatchTarget();
  }

  Future<void> _ensureWatchTarget() {
    final previous = _watchTail;
    final next = () async {
      await previous;
      if (_closed) return;
      await _replaceWatchTarget();
    }();
    _watchTail = next.catchError((Object _) {});
    return next;
  }

  /// The deepest directory on the way to the skills root that exists now.
  Directory? _deepestExistingAncestor() {
    var target = _directory;
    while (!target.existsSync()) {
      final parent = target.parent;
      if (p.equals(parent.path, target.path)) return null;
      target = parent;
    }
    return target;
  }

  Future<void> _replaceWatchTarget() async {
    final skillRoot = p.normalize(p.absolute(_directory.path));
    // Resolving the anchor once is not enough. A missing root is created one
    // level at a time, each level appears inside the level above it, and this
    // method awaits between choosing an anchor and arming the watch on it. A
    // level that appears inside that window is observed by nobody — the
    // ancestor watch is not recursive and native watchers never replay — so a
    // single-pass anchor leaves the catalog permanently deaf. Repeat until a
    // pass finds the same deepest directory it just armed; the comparison is
    // an `existsSync` walk, so a settled watcher pays one cheap extra pass.
    String? armed;
    while (!_closed) {
      final target = _deepestExistingAncestor();
      if (target == null) return;
      final targetPath = p.normalize(p.absolute(target.path));
      if (targetPath == armed) return;
      armed = targetPath;

      final hadSubscriptions = _watchSubscriptions.isNotEmpty;
      final rootWasWatched = _watchSubscriptions.containsKey(skillRoot);

      final desiredPaths = await _desiredWatchPaths(target);
      if (_closed) return;
      for (final path in desiredPaths) {
        if (_watchSubscriptions.containsKey(path)) continue;
        _startWatching(path);
      }

      // A skills root that materialized while only an ancestor was watched has
      // already missed the native events for its own creation: the ancestor
      // delivered them while the root did not exist yet, so the path filter
      // dropped them, and native watchers never replay. Anchoring onto the root
      // is itself the missed change, so report it — except on the very first
      // anchor, where the initial catalog read has not happened yet.
      if (hadSubscriptions &&
          !rootWasWatched &&
          _watchSubscriptions.containsKey(skillRoot)) {
        _changes.add(null);
      }

      // Install replacement watchers before dropping ancestors so a root that
      // appeared between native events never has an unobserved window.
      if (!_watchSubscriptions.keys.any(desiredPaths.contains)) return;
      final stalePaths = _watchSubscriptions.keys
          .where((path) => !desiredPaths.contains(path))
          .toList(growable: false);
      for (final path in stalePaths) {
        final subscription = _watchSubscriptions.remove(path);
        await subscription?.cancel();
      }
    }
  }

  Future<Set<String>> _desiredWatchPaths(Directory target) async {
    final skillRoot = p.normalize(p.absolute(_directory.path));
    final targetPath = p.normalize(p.absolute(target.path));
    if (!p.equals(targetPath, skillRoot)) return <String>{targetPath};

    // dart:io does not support recursive directory watches on Linux. Watch
    // each existing directory non-recursively instead, including resource
    // directories, and rescan this set whenever a directory entry changes.
    final paths = <String>{skillRoot};
    try {
      await for (final entity in Directory(
        skillRoot,
      ).list(recursive: true, followLinks: false)) {
        if (entity is Directory) {
          paths.add(p.normalize(p.absolute(entity.path)));
        }
      }
    } on FileSystemException {
      // An editor may replace or remove part of the tree during enumeration.
      // Preserve every existing watch until one complete scan can safely prune
      // paths that vanished after enumeration began.
      paths.addAll(_watchSubscriptions.keys);
    }
    return paths;
  }

  void _startWatching(String watchedPath) {
    final pathFilter = SkillWatchPathFilter(
      skillRoot: _directory.path,
      watchedRoot: watchedPath,
    );
    try {
      late final StreamSubscription<SkillWatchEvent> subscription;
      subscription = openWatch(watchedPath).listen(
        (event) {
          if (_closed) return;
          if (!_affectsSkillRoot(event, pathFilter)) {
            // A missing root may be created one ancestor at a time. Quietly
            // move the watcher closer without reporting unrelated siblings.
            if (!_directory.existsSync()) unawaited(_ensureWatchTarget());
            return;
          }
          _changes.add(null);
          unawaited(_ensureWatchTarget());
        },
        onError: (Object _) => _watchEnded(watchedPath, subscription),
        onDone: () => _watchEnded(watchedPath, subscription),
      );
      _watchSubscriptions[watchedPath] = subscription;
    } on FileSystemException {
      // A path can disappear after enumeration. Its closest surviving parent
      // remains watched and the next read or event rebuilds this set.
    }
  }

  void _watchEnded(
    String watchedPath,
    StreamSubscription<SkillWatchEvent> subscription,
  ) {
    if (_closed || !identical(_watchSubscriptions[watchedPath], subscription)) {
      return;
    }
    _watchSubscriptions.remove(watchedPath);
    unawaited(subscription.cancel());
    _changes.add(null);
    unawaited(_ensureWatchTarget());
  }

  bool _affectsSkillRoot(
    SkillWatchEvent event,
    SkillWatchPathFilter pathFilter,
  ) {
    final skillRootExists = _directory.existsSync();
    if (pathFilter.accepts(event.path, skillRootExists: skillRootExists)) {
      return true;
    }
    final destination = event.destination;
    return destination != null &&
        pathFilter.accepts(destination, skillRootExists: skillRootExists);
  }

  @override
  Future<List<SkillDocument>> read() async {
    if (_initialized) await _ensureWatchTarget();
    if (!_directory.existsSync()) return const <SkillDocument>[];
    final documents = <SkillDocument>[];
    await for (final entity in _directory.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final id = p.basename(entity.path);
      if (id.startsWith('.')) continue;
      if (FileSystemEntity.typeSync(entity.path, followLinks: false) ==
          FileSystemEntityType.link) {
        continue;
      }
      final document = File(p.join(entity.path, _documentName));
      if (!document.existsSync()) continue;
      try {
        documents.add(
          SkillDocument(
            id: id,
            sourcePath: document.path,
            source: await document.readAsString(),
            directory: entity.path,
          ),
        );
      } on FileSystemException {
        // Atomic editors may replace an entry after directory enumeration.
        if (document.existsSync()) rethrow;
      }
    }
    return documents;
  }

  @override
  Future<List<SkillResource>> resources(String id) async {
    final directory = Directory(_skillDirectory(id));
    if (!directory.existsSync()) return const <SkillResource>[];
    final resources = <SkillResource>[];
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final relative = p.relative(entity.path, from: directory.path);
      if (relative == _documentName) continue;
      if (FileSystemEntity.typeSync(entity.path, followLinks: false) ==
          FileSystemEntityType.link) {
        continue;
      }
      resources.add(
        SkillResource(
          path: p.split(relative).join('/'),
          sizeBytes: await entity.length(),
        ),
      );
      if (resources.length >= maxResources) break;
    }
    resources.sort((left, right) => left.path.compareTo(right.path));
    return List<SkillResource>.unmodifiable(resources);
  }

  Future<void> _restrict(String path, String mode) async {
    if (Platform.isWindows) return;
    await Process.run('chmod', <String>[mode, path]);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _watchTail;
    final subscriptions = _watchSubscriptions.values.toList(growable: false);
    _watchSubscriptions.clear();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    await _changes.close();
  }
}

/// Source-of-truth catalog merging built-in, user, config, and project skills.
final class FileSkillStore {
  /// Creates a store over the global roots.
  new({
    required this.roots,
    this.builtIns = builtInSkills,
    this.watchDebounce = const Duration(milliseconds: 200),
    this.maxProjectRoots = 8,
  });

  /// Global filesystem roots.
  final List<SkillFiles> roots;

  /// Skills shipped inside the daemon.
  final List<BuiltInSkill> builtIns;

  /// Delay used to coalesce native editor event bursts.
  final Duration watchDebounce;

  /// Upper bound on simultaneously watched project roots.
  final int maxProjectRoots;

  final Map<SkillFiles, Map<String, _ParsedSkill>> _global =
      <SkillFiles, Map<String, _ParsedSkill>>{};
  final Map<String, _ProjectRoot> _projects = <String, _ProjectRoot>{};
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );
  final List<StreamSubscription<void>> _watchSubscriptions =
      <StreamSubscription<void>>[];
  Future<void> _operationTail = Future<void>.value();
  Future<void>? _initializeFuture;
  Timer? _reloadTimer;
  Future<void>? _watchReload;
  bool _closed = false;

  /// Emits after the effective catalog may have changed.
  Stream<void> get changes => _changes.stream;

  /// Number of project roots currently cached and watched.
  int get trackedProjectRoots => _projects.length;

  /// Starts all global root watchers and loads their first snapshot.
  Future<void> initialize() {
    _ensureOpen();
    return _initializeFuture ??= _serialize(() async {
      for (final root in roots) {
        await root.initialize();
        _watchSubscriptions.add(root.changes.listen((_) => _scheduleReload()));
      }
      await _reloadGlobalLocked();
    });
  }

  /// Lists public summaries for [view] in [scope].
  Future<List<SkillSummaryDto>> list({
    required SkillListView view,
    SkillScope scope = SkillScope.global,
  }) async {
    await initialize();
    return await _serialize(() async {
      final resolved = switch (view) {
        SkillListView.global => await _resolveLocked(SkillScope.global),
        SkillListView.project =>
          scope.projectRoot == null
              ? throw ArgumentError.value(
                  scope.projectRoot,
                  'scope.projectRoot',
                  'Project view requires a project root.',
                )
              : (await _resolveLocked(scope))
                    .where((skill) => skill.origin == SkillOrigin.project)
                    .toList(growable: false),
        SkillListView.effective => await _resolveLocked(scope),
      };
      return List<SkillSummaryDto>.unmodifiable(
        resolved.map(
          (skill) => SkillSummaryDto(
            id: skill.id,
            name: skill.name,
            description: skill.description,
            isImplicit: skill.isImplicit,
          ),
        ),
      );
    });
  }

  /// Reloads external changes immediately.
  Future<void> reload() async {
    await initialize();
    await _serialize(() async {
      await _reloadGlobalLocked();
      for (final project in _projects.values) {
        await _reloadProjectLocked(project);
      }
      _changes.add(null);
    });
  }

  Future<SkillTurnCatalog> _viewFor(String projectRoot) async {
    await initialize();
    return await _serialize(
      () async => SkillTurnCatalog._(
        await _resolveLocked(SkillScope(projectRoot: projectRoot)),
      ),
    );
  }

  Future<List<_ResolvedSkill>> _resolveLocked(SkillScope scope) async {
    final projectRoot = scope.projectRoot;
    final project = projectRoot == null
        ? null
        : await _projectRootLocked(projectRoot);
    final candidates = <_ResolvedSkill>[
      for (final builtIn in builtIns)
        _ResolvedSkill(
          id: builtIn.id,
          name: builtIn.name,
          description: builtIn.description,
          body: builtIn.body.trim(),
          origin: SkillOrigin.builtIn,
          isImplicit: builtIn.isImplicit,
          directory: null,
          resources: const <SkillResource>[],
        ),
      for (final root in roots)
        for (final parsed in _global[root]?.values ?? const <_ParsedSkill>[])
          await _resolveFileSkill(parsed, root),
      if (project != null)
        for (final parsed in project.parsed.values)
          await _resolveFileSkill(parsed, project.files),
    ]..sort(_compareWinnerPriority);

    final ids = <String>{};
    final names = <String>{};
    final winners = <_ResolvedSkill>[];
    for (final candidate in candidates) {
      if (ids.contains(candidate.id) || names.contains(candidate.name)) {
        continue;
      }
      ids.add(candidate.id);
      names.add(candidate.name);
      winners.add(candidate);
    }
    winners.sort(_compareDisplayOrder);
    return List<_ResolvedSkill>.unmodifiable(winners);
  }

  Future<_ResolvedSkill> _resolveFileSkill(
    _ParsedSkill parsed,
    SkillFiles files,
  ) async => _ResolvedSkill(
    id: parsed.id,
    name: parsed.name,
    description: parsed.description,
    body: parsed.body,
    origin: files.origin,
    isImplicit: false,
    directory: parsed.directory,
    resources: await files.resources(parsed.id),
  );

  Future<_ProjectRoot> _projectRootLocked(String projectRoot) async {
    final normalized = p.normalize(p.absolute(projectRoot));
    final cached = _projects.remove(normalized);
    if (cached != null) {
      _projects[normalized] = cached;
      return cached;
    }
    while (_projects.length >= maxProjectRoots) {
      final oldest = _projects.keys.first;
      final evicted = _projects.remove(oldest)!;
      await evicted.close();
    }
    final files = NativeSkillFiles(
      p.join(normalized, '.agents', 'skills'),
      origin: SkillOrigin.project,
    );
    await files.initialize();
    final entry = _ProjectRoot(files: files)
      ..watch = files.changes.listen((_) => _scheduleReload());
    _projects[normalized] = entry;
    await _reloadProjectLocked(entry);
    return entry;
  }

  Future<void> _reloadGlobalLocked() async {
    for (final root in roots) {
      _global[root] = _parse(await root.read());
    }
  }

  Future<void> _reloadProjectLocked(_ProjectRoot project) async {
    project.parsed = _parse(await project.files.read());
  }

  Map<String, _ParsedSkill> _parse(List<SkillDocument> documents) {
    final parsed = <String, _ParsedSkill>{};
    for (final document in documents) {
      try {
        _validateId(document.id);
        parsed[document.id] = _codec.decode(document);
      } on FormatException {
        // Invalid candidates are excluded before precedence is evaluated, so
        // a lower-precedence valid definition can remain effective.
      }
    }
    return parsed;
  }

  void _scheduleReload() {
    if (_closed) return;
    _reloadTimer?.cancel();
    _reloadTimer = Timer(watchDebounce, () {
      if (_closed) return;
      final reloadFuture = _serialize(() async {
        await _reloadGlobalLocked();
        for (final project in _projects.values) {
          await _reloadProjectLocked(project);
        }
        _changes.add(null);
      });
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
    if (_closed) throw StateError('Skill store is closed.');
  }

  /// Stops observation of every root.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _reloadTimer?.cancel();
    for (final subscription in _watchSubscriptions) {
      await subscription.cancel();
    }
    await _watchReload;
    await _operationTail;
    for (final project in _projects.values) {
      await project.close();
    }
    _projects.clear();
    for (final root in roots) {
      await root.close();
    }
    await _changes.close();
  }
}

final class _ProjectRoot {
  new({required this.files});

  final NativeSkillFiles files;
  Map<String, _ParsedSkill> parsed = <String, _ParsedSkill>{};
  StreamSubscription<void>? watch;

  Future<void> close() async {
    await watch?.cancel();
    await files.close();
  }
}

final class _ParsedSkill {
  const new({
    required this.id,
    required this.name,
    required this.description,
    required this.body,
    required this.directory,
  });

  final String id;
  final String name;
  final String description;
  final String body;
  final String directory;
}

final class _ResolvedSkill {
  const new({
    required this.id,
    required this.name,
    required this.description,
    required this.body,
    required this.origin,
    required this.isImplicit,
    required this.directory,
    required this.resources,
  });

  final String id;
  final String name;
  final String description;
  final String body;
  final SkillOrigin origin;
  final bool isImplicit;
  final String? directory;
  final List<SkillResource> resources;
}

int _compareWinnerPriority(_ResolvedSkill left, _ResolvedSkill right) {
  final implicit = _boolRank(right.isImplicit) - _boolRank(left.isImplicit);
  if (implicit != 0) return implicit;
  final origin = _originRank(right.origin) - _originRank(left.origin);
  if (origin != 0) return origin;
  final id = left.id.compareTo(right.id);
  if (id != 0) return id;
  final name = left.name.compareTo(right.name);
  if (name != 0) return name;
  return (left.directory ?? '').compareTo(right.directory ?? '');
}

int _compareDisplayOrder(_ResolvedSkill left, _ResolvedSkill right) {
  final folded = left.name.toLowerCase().compareTo(right.name.toLowerCase());
  if (folded != 0) return folded;
  final name = left.name.compareTo(right.name);
  return name != 0 ? name : left.id.compareTo(right.id);
}

int _boolRank(bool value) => value ? 1 : 0;

int _originRank(SkillOrigin origin) => switch (origin) {
  SkillOrigin.builtIn => 0,
  SkillOrigin.userHome => 1,
  SkillOrigin.config => 2,
  SkillOrigin.project => 3,
};

const _SkillMarkdownCodec _codec = _SkillMarkdownCodec();

final class _SkillMarkdownCodec {
  const new();

  _ParsedSkill decode(SkillDocument document) {
    final parsed = _SkillMarkdownDocument.parse(document.source);
    final decoded = loadYaml(
      parsed.frontmatter,
      sourceUrl: p.isAbsolute(document.sourcePath)
          ? Uri.file(document.sourcePath)
          : null,
    );
    if (decoded is! YamlMap) {
      throw const FormatException('Skill frontmatter must be a YAML map.');
    }
    final name = decoded['name'];
    final description = decoded['description'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('name must be a non-empty string.');
    }
    if (description is! String || description.trim().isEmpty) {
      throw const FormatException('description must be a non-empty string.');
    }
    return _ParsedSkill(
      id: document.id,
      name: name.trim(),
      description: description.trim(),
      body: parsed.body.trim(),
      directory: document.directory,
    );
  }
}

final class _SkillMarkdownDocument {
  const new({required this.frontmatter, required this.body});

  factory parse(String source) {
    final lines = source.replaceAll('\r\n', '\n').split('\n');
    var start = 0;
    while (start < lines.length && lines[start].trim().isEmpty) {
      start += 1;
    }
    if (start == lines.length || lines[start].trim() != '---') {
      throw const FormatException('SKILL.md must start with frontmatter.');
    }
    var end = start + 1;
    while (end < lines.length && lines[end].trim() != '---') {
      end += 1;
    }
    if (end == lines.length) {
      throw const FormatException('SKILL.md frontmatter is not closed.');
    }
    return _SkillMarkdownDocument(
      frontmatter: lines.sublist(start + 1, end).join('\n'),
      body: lines.sublist(end + 1).join('\n'),
    );
  }

  final String frontmatter;
  final String body;
}

/// Application service exposing skills to RPC callers and to turns.
final class SkillCatalogService {
  /// Creates a skill application service.
  new({required this.store});

  /// Source-of-truth catalog backing this service.
  final FileSkillStore store;

  /// Emits after a catalog change.
  Stream<void> get changes => store.changes;

  /// Number of project roots currently cached and watched.
  int get trackedProjectRoots => store.trackedProjectRoots;

  /// Starts root observation and reads the initial catalog.
  Future<void> initialize() => store.initialize();

  /// Lists effective summaries for [view] in [scope].
  Future<List<SkillSummaryDto>> list({
    required SkillListView view,
    SkillScope scope = SkillScope.global,
  }) => store.list(view: view, scope: scope);

  /// Reloads external changes immediately.
  Future<void> reload() => store.reload();

  /// Builds the immutable catalog one turn sees.
  Future<SkillTurnCatalog> viewFor(String projectRoot) =>
      store._viewFor(projectRoot);

  /// Stops observation.
  Future<void> close() => store.close();
}

/// Immutable turn catalog and its trusted, always-injected instructions.
final class SkillTurnCatalog
    implements SkillCatalog, ImplicitSkillDocumentSource {
  new _(List<_ResolvedSkill> skills)
    : _skills = List<_ResolvedSkill>.unmodifiable(skills),
      _byName = <String, _ResolvedSkill>{
        for (final skill in skills) skill.name: skill,
      };

  final List<_ResolvedSkill> _skills;
  final Map<String, _ResolvedSkill> _byName;

  @override
  List<ImplicitSkillDocument> implicitSkillDocuments() {
    final implicit = _skills.where((skill) => skill.isImplicit).toList()
      ..sort(_compareDisplayOrder);
    return <ImplicitSkillDocument>[
      for (final skill in implicit)
        ImplicitSkillDocument(name: skill.name, instructions: skill.body),
    ];
  }

  @override
  List<SkillSummary> summaries() {
    final names = _byName.keys.toList()..sort();
    return <SkillSummary>[
      for (final name in names)
        SkillSummary(name: name, description: _byName[name]!.description),
    ];
  }

  @override
  Future<SkillContent> read(String name) async {
    final skill = _require(name);
    return SkillContent(
      name: skill.name,
      description: skill.description,
      instructions: skill.body,
      directory: skill.directory,
      resources: skill.resources
          .map(
            (resource) => SkillResourceRef(
              path: resource.path,
              sizeBytes: resource.sizeBytes,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<String> readResource(String name, String relativePath) async {
    final skill = _require(name);
    final directory = skill.directory;
    if (directory == null) {
      throw SkillLookupException('Skill has no bundled files: $name');
    }
    final guard = SkillPathGuard(directory);
    return await File(guard.resolveExisting(relativePath)).readAsString();
  }

  _ResolvedSkill _require(String name) {
    final skill = _byName[name];
    if (skill == null) throw SkillLookupException('Unknown skill: $name');
    return skill;
  }
}

void _validateId(String id) {
  if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(id)) {
    throw const FormatException('Invalid skill ID.');
  }
}
