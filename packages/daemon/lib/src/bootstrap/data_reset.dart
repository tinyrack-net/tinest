import 'dart:io';

import 'package:path/path.dart' as p;

/// Filesystem primitives required to erase stored daemon data.
abstract interface class DaemonDataFiles {
  /// Whether an entity exists at [path].
  Future<bool> exists(String path);

  /// Whether [path] points at a directory rather than a file.
  Future<bool> isDirectory(String path);

  /// Deletes the file at [path].
  Future<void> deleteFile(String path);

  /// Recursively deletes the directory at [path].
  Future<void> deleteDirectory(String path);

  /// Throws when another process still holds the daemon lock at [lockPath].
  ///
  /// Record locks are owned per process, so this cannot detect a daemon
  /// running inside the calling process. Callers stop their own daemon first.
  Future<void> assertLockAvailable(String lockPath);
}

/// Why a [DaemonDataReset] refused to erase stored data.
enum DaemonDataResetFailureReason {
  /// Another daemon process owns the data directory.
  daemonRunning,

  /// The operating system rejected a delete.
  filesystem,
}

/// Raised when stored daemon data cannot be erased.
final class DaemonDataResetException implements Exception {
  /// Creates a [DaemonDataResetException].
  const new(this.message, {required this.reason, this.path});

  /// Human-readable explanation of the failure.
  final String message;

  /// Machine-readable failure classification.
  final DaemonDataResetFailureReason reason;

  /// The path that could not be erased, when the failure names one.
  final String? path;

  @override
  String toString() => 'DaemonDataResetException(${reason.name}): $message';
}

/// Native [DaemonDataFiles] adapter backed by `dart:io`.
final class NativeDaemonDataFiles implements DaemonDataFiles {
  /// Creates the production filesystem adapter.
  const new();

  @override
  Future<bool> exists(String path) async =>
      FileSystemEntity.typeSync(path, followLinks: false) !=
      FileSystemEntityType.notFound;

  @override
  Future<bool> isDirectory(String path) async =>
      FileSystemEntity.typeSync(path, followLinks: false) ==
      FileSystemEntityType.directory;

  @override
  Future<void> deleteFile(String path) => File(path).delete();

  @override
  Future<void> deleteDirectory(String path) =>
      Directory(path).delete(recursive: true);

  @override
  Future<void> assertLockAvailable(String lockPath) async {
    final file = File(lockPath);
    if (!file.existsSync()) return;
    final handle = await file.open(mode: FileMode.append);
    try {
      await handle.lock();
      await handle.unlock();
    } on FileSystemException catch (error) {
      throw DaemonDataResetException(
        'Another daemon owns ${p.dirname(lockPath)}: ${error.message}',
        reason: DaemonDataResetFailureReason.daemonRunning,
        path: lockPath,
      );
    } finally {
      await handle.close();
    }
  }
}

/// Erases every daemon-owned file while preserving managed Git checkouts.
///
/// The daemon must be stopped first: it holds an exclusive lock on
/// `daemon.lock` and an open handle on `tinest.sqlite`.
final class DaemonDataReset {
  /// Creates a reset targeting one daemon's config and state directories.
  const new({
    required this.configDirectory,
    required this.homeDirectory,
    this.files = const NativeDaemonDataFiles(),
  });

  /// Directory holding credentials and declarative configuration.
  final String configDirectory;

  /// Directory holding the database, attachments, and managed checkouts.
  final String homeDirectory;

  /// Filesystem adapter used to inspect and delete entries.
  final DaemonDataFiles files;

  /// Entries erased from [homeDirectory].
  static const List<String> homeEntries = <String>[
    'v5/tinest.sqlite',
    'v5/tinest.sqlite-wal',
    'v5/tinest.sqlite-shm',
    'v5/tinest.sqlite-journal',
    'v5/attachments',
    'v5/plugin-cache',
    'v5/plugin-state.json',
    'v5/plugin-state.json.tmp',
    'v5/daemon.lock',
  ];

  /// Entries erased from [configDirectory].
  static const List<String> configEntries = <String>[
    'v5/secrets.json',
    'v5/secrets.json.tmp',
    'v5/plugin-secrets.json',
    'v5/plugin-secrets.json.tmp',
    'v5/config.json',
    'v5/config.json.tmp',
    'v5/agents',
    'v5/plugins',
    'v5/skills',
    'v5/commands',
  ];

  /// Entries under [homeDirectory] that a reset must never touch.
  ///
  /// Managed checkouts can hold unpushed work, so they outlive a reset even
  /// though their workspace registrations do not.
  static const List<String> preservedHomeEntries = <String>['v5/worktrees'];

  /// Erases every entry in the allowlist, leaving both roots in place.
  ///
  /// Missing entries are not an error. Throws [DaemonDataResetException] when
  /// another daemon still owns the directory, in which case nothing is
  /// deleted.
  Future<void> eraseAll() async {
    await files.assertLockAvailable(p.join(homeDirectory, 'v5', 'daemon.lock'));
    for (final path in _targets()) {
      if (!await files.exists(path)) continue;
      try {
        if (await files.isDirectory(path)) {
          await files.deleteDirectory(path);
        } else {
          await files.deleteFile(path);
        }
      } on FileSystemException catch (error) {
        throw DaemonDataResetException(
          'Failed to delete $path: ${error.message}',
          reason: DaemonDataResetFailureReason.filesystem,
          path: path,
        );
      }
    }
  }

  /// Absolute deletion targets, deduplicated by canonical path.
  ///
  /// The config and state roots collapse into one directory on macOS, on
  /// Windows without `LOCALAPPDATA`, and under `TINYRACK_TINEST_HOME`, so the
  /// same entry can be named twice.
  List<String> _targets() {
    final seen = <String>{};
    final targets = <String>[];
    for (final (root, entries) in <(String, List<String>)>[
      (homeDirectory, homeEntries),
      (configDirectory, configEntries),
    ]) {
      for (final entry in entries) {
        final path = p.join(root, entry);
        if (seen.add(p.canonicalize(path))) targets.add(path);
      }
    }
    return targets;
  }
}

/// Explicitly removes preserved pre-v4 daemon namespaces.
///
/// This operation is never called by startup or [DaemonDataReset]. Callers
/// must name the legacy versions they intend to remove.
final class DaemonLegacyDataCleanup {
  /// Creates a cleanup operation for one daemon installation.
  const new({
    required this.configDirectory,
    required this.homeDirectory,
    this.files = const NativeDaemonDataFiles(),
  });

  /// Root containing legacy configuration namespaces.
  final String configDirectory;

  /// Root containing legacy state namespaces.
  final String homeDirectory;

  /// Filesystem adapter used by the operation.
  final DaemonDataFiles files;

  /// Deletes exactly the requested v2 and/or v3 namespaces.
  Future<void> erase({required Set<int> versions}) async {
    if (versions.isEmpty ||
        versions.any((version) => version != 2 && version != 3)) {
      throw ArgumentError.value(
        versions,
        'versions',
        'Only legacy versions 2 and 3 may be removed.',
      );
    }
    final targets = <String>{};
    for (final version in versions) {
      final name = 'v$version';
      await files.assertLockAvailable(
        p.join(homeDirectory, name, 'daemon.lock'),
      );
      targets
        ..add(p.canonicalize(p.join(homeDirectory, name)))
        ..add(p.canonicalize(p.join(configDirectory, name)));
    }
    for (final path in targets) {
      if (!await files.exists(path)) continue;
      try {
        if (await files.isDirectory(path)) {
          await files.deleteDirectory(path);
        } else {
          await files.deleteFile(path);
        }
      } on FileSystemException catch (error) {
        throw DaemonDataResetException(
          'Failed to delete $path: ${error.message}',
          reason: DaemonDataResetFailureReason.filesystem,
          path: path,
        );
      }
    }
  }
}
