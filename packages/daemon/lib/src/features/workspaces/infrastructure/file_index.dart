import 'dart:async';
import 'dart:io';

import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:path/path.dart' as p;
import 'package:protocol/protocol.dart';

/// Indexes worktree files for composer mentions, preferring Git's own view.
///
/// Asking `git ls-files` for the tracked and untracked-but-not-ignored set
/// gives nested, global, and `.git/info/exclude` ignore rules for free. The
/// directory walk is only a fallback for roots that are not repositories.
final class GitAwareFileIndexGateway implements WorkspaceFileIndexGateway {
  /// Creates the Git-aware file index.
  new(this._runner, this._clock);

  /// How long an index is served before a refresh is scheduled.
  static const Duration indexTtl = Duration(seconds: 15);

  /// How many worktree roots keep a warm index.
  static const int maxCachedRoots = 4;

  /// Directory names skipped by the fallback walk and by Git's output.
  ///
  /// Git already hides ignored paths, but a repository that commits its build
  /// output would otherwise flood the mention list with generated files.
  static const Set<String> ignoredDirectoryNames = <String>{
    '.git',
    '.hg',
    '.svn',
    'node_modules',
    '.dart_tool',
    'build',
    'dist',
    'out',
    'target',
    '.next',
    '.nuxt',
    '.gradle',
    'Pods',
    '.venv',
    'venv',
    '__pycache__',
    '.idea',
    '.vscode',
    '.cache',
    'coverage',
    '.terraform',
  };

  static const List<String> _gitArguments = <String>[
    'ls-files',
    '--cached',
    '--others',
    '--exclude-standard',
    '--deduplicate',
    '-z',
  ];

  final CommandRunner _runner;
  final Clock _clock;
  final Map<String, _FileIndex> _cache = <String, _FileIndex>{};
  final Map<String, Future<_FileIndex>> _building =
      <String, Future<_FileIndex>>{};

  @override
  Future<FileSearchResultDto> search(FileSearchRequest request) async {
    final snapshot = await _snapshot(request);
    return FileSearchResultDto(
      matches: _rank(snapshot, request),
      truncated: snapshot.truncated,
    );
  }

  @override
  void invalidate(String root) => _cache.remove(root);

  Future<_IndexSnapshot> _snapshot(FileSearchRequest request) async {
    final cached = _cache[request.root];
    if (cached != null) {
      // Capture before scheduling the refresh: a rebuild that lands while this
      // search is still ranking must not change the result it returns.
      final snapshot = cached.snapshot();
      final age = _clock.nowUtc().difference(cached.loadedAt);
      if (age >= indexTtl && cached.refresh == null) {
        // Serve what we have and rebuild behind it, so no keystroke ever waits
        // on a full reindex.
        final refresh = _refresh(request, cached);
        cached.refresh = refresh;
        unawaited(refresh);
      }
      return snapshot;
    }

    final building = _building[request.root];
    if (building != null) return (await building).snapshot();

    final future = _build(request);
    _building[request.root] = future;
    try {
      final index = await future;
      _cache[request.root] = index;
      _evict();
      return index.snapshot();
    } finally {
      // Already awaited above; dropping the map's copy is not a lost future.
      _building.remove(request.root)?.ignore();
    }
  }

  Future<void> _refresh(FileSearchRequest request, _FileIndex entry) async {
    try {
      final rebuilt = await _build(request);
      entry
        ..entries = rebuilt.entries
        ..truncated = rebuilt.truncated
        ..loadedAt = rebuilt.loadedAt;
    } on Object {
      // Keep serving the previous index and back off for another window.
      entry.loadedAt = _clock.nowUtc();
    } finally {
      entry.refresh = null;
    }
  }

  void _evict() {
    while (_cache.length > maxCachedRoots) {
      final oldest = _cache.entries.reduce(
        (left, right) =>
            left.value.loadedAt.isAfter(right.value.loadedAt) ? right : left,
      );
      _cache.remove(oldest.key);
    }
  }

  Future<_FileIndex> _build(FileSearchRequest request) async {
    CommandResult? result;
    try {
      result = await _runner.run(
        'git',
        _gitArguments,
        workingDirectory: request.root,
      );
    } on Object {
      result = null;
    }
    if (result != null && result.exitCode == 0) {
      return _fromGit(result.stdout, request);
    }
    return await _walk(request);
  }

  _FileIndex _fromGit(String stdout, FileSearchRequest request) {
    final paths = <String>[];
    var truncated = false;
    for (final raw in stdout.split('\u0000')) {
      if (raw.isEmpty) continue;
      final relative = p.posix.normalize(raw);
      if (_isIgnored(relative)) continue;
      if (paths.length == request.maxScannedEntries) {
        truncated = true;
        break;
      }
      paths.add(relative);
    }
    return _index0(paths, request, truncated: truncated);
  }

  Future<_FileIndex> _walk(FileSearchRequest request) async {
    final root = Directory(request.root);
    if (!root.existsSync()) {
      return _index0(const <String>[], request, truncated: false);
    }

    final paths = <String>[];
    final queue = <_PendingDirectory>[
      _PendingDirectory(directory: root, depth: 0),
    ];
    var scanned = 0;
    var truncated = false;

    while (queue.isNotEmpty && !truncated) {
      final current = queue.removeAt(0);
      final List<FileSystemEntity> children;
      try {
        children = await current.directory.list(followLinks: false).toList();
      } on FileSystemException {
        continue;
      }

      for (final child in children) {
        if (ignoredDirectoryNames.contains(p.basename(child.path))) continue;
        scanned += 1;
        if (scanned > request.maxScannedEntries) {
          truncated = true;
          break;
        }
        if (child is Directory) {
          if (current.depth < request.maxDepth) {
            queue.add(
              _PendingDirectory(directory: child, depth: current.depth + 1),
            );
          }
        } else if (child is File) {
          paths.add(_toPosix(p.relative(child.path, from: request.root)));
        }
      }
    }

    return _index0(paths, request, truncated: truncated);
  }

  _FileIndex _index0(
    List<String> filePaths,
    FileSearchRequest request, {
    required bool truncated,
  }) {
    final entries = <String, _IndexedPath>{};
    for (final path in filePaths) {
      entries[path] = _IndexedPath(
        relativePath: path,
        root: request.root,
        isDirectory: false,
      );
      // A mention may point at a folder, so every parent prefix becomes a
      // candidate even though Git only reports files.
      var parent = p.posix.dirname(path);
      while (parent != '.' && parent != '/' && parent.isNotEmpty) {
        entries.putIfAbsent(
          parent,
          () => _IndexedPath(
            relativePath: parent,
            root: request.root,
            isDirectory: true,
          ),
        );
        parent = p.posix.dirname(parent);
      }
    }
    return _FileIndex(
      entries: entries.values.toList(growable: false),
      loadedAt: _clock.nowUtc(),
      truncated: truncated,
    );
  }

  List<FileMatchDto> _rank(_IndexSnapshot index, FileSearchRequest request) {
    final limit = request.limit <= 0 ? 0 : request.limit;
    if (limit == 0) return const <FileMatchDto>[];

    final query = request.query.toLowerCase();
    if (query.isEmpty) {
      final head = index.entries.toList()..sort(_byShallowestFileFirst);
      return <FileMatchDto>[
        for (final entry in head.take(limit)) entry.toDto(0),
      ];
    }

    final scored = <({_IndexedPath entry, int score})>[];
    for (final entry in index.entries) {
      final score = _score(entry, query);
      if (score != null) scored.add((entry: entry, score: score));
    }
    scored.sort((left, right) {
      final byScore = right.score.compareTo(left.score);
      if (byScore != 0) return byScore;
      return _byShallowestFileFirst(left.entry, right.entry);
    });
    return <FileMatchDto>[
      for (final match in scored.take(limit)) match.entry.toDto(match.score),
    ];
  }

  /// Coarse relevance; the app re-ranks to compute highlight spans.
  int? _score(_IndexedPath entry, String query) {
    final name = entry.name.toLowerCase();
    final path = entry.relativePath.toLowerCase();
    int score;
    if (_isSubsequence(name, query)) {
      score = 400;
      if (name.startsWith(query)) score += 200;
      if (name == query) score += 100;
    } else if (_isSubsequence(path, query)) {
      score = 100;
      if (path.startsWith(query)) score += 60;
    } else {
      return null;
    }
    score -= entry.depth * 5;
    if (entry.isDirectory) score -= 10;
    return score;
  }

  static int _byShallowestFileFirst(_IndexedPath left, _IndexedPath right) {
    final byDepth = left.depth.compareTo(right.depth);
    if (byDepth != 0) return byDepth;
    if (left.isDirectory != right.isDirectory) {
      return left.isDirectory ? 1 : -1;
    }
    return left.relativePath.compareTo(right.relativePath);
  }

  static bool _isIgnored(String relativePath) =>
      relativePath.split('/').any(ignoredDirectoryNames.contains);

  static String _toPosix(String path) => p.split(path).join(p.posix.separator);

  static bool _isSubsequence(String candidate, String query) {
    var cursor = 0;
    for (
      var index = 0;
      index < candidate.length && cursor < query.length;
      index += 1
    ) {
      if (candidate.codeUnitAt(index) == query.codeUnitAt(cursor)) cursor += 1;
    }
    return cursor == query.length;
  }
}

final class _PendingDirectory {
  const new({required this.directory, required this.depth});

  final Directory directory;
  final int depth;
}

/// Joins a worktree root and a POSIX relative path into one native path.
///
/// Git reports a repository root with forward slashes even on Windows, so
/// joining without normalizing leaves a path that mixes both separators.
/// [context] exists so the Windows behaviour is testable from any host.
String absolutePathFor(String root, String relativePath, {p.Context? context}) {
  final resolved = context ?? p.context;
  return resolved.normalize(
    resolved.join(root, resolved.joinAll(p.posix.split(relativePath))),
  );
}

final class _IndexedPath {
  new({
    required this.relativePath,
    required this.root,
    required this.isDirectory,
  }) : name = p.posix.basename(relativePath),
       depth = p.posix.split(relativePath).length - 1;

  final String relativePath;
  final String root;
  final bool isDirectory;
  final String name;
  final int depth;

  FileMatchDto toDto(int score) => FileMatchDto(
    relativePath: relativePath,
    absolutePath: absolutePathFor(root, relativePath),
    name: name,
    isDirectory: isDirectory,
    score: score,
  );
}

/// An immutable view of one index, stable across a concurrent refresh.
final class _IndexSnapshot {
  const new({required this.entries, required this.truncated});

  final List<_IndexedPath> entries;
  final bool truncated;
}

final class _FileIndex {
  new({required this.entries, required this.loadedAt, required this.truncated});

  List<_IndexedPath> entries;
  DateTime loadedAt;
  bool truncated;
  Future<void>? refresh;

  _IndexSnapshot snapshot() =>
      _IndexSnapshot(entries: entries, truncated: truncated);
}
