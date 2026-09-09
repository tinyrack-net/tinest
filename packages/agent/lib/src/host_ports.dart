import 'dart:io' show FileSystemException;

import 'package:agent/src/model.dart';
import 'package:file/file.dart' as file_api;
import 'package:file/local.dart';
import 'package:platform/platform.dart';
import 'package:platform/testing.dart';

/// Copies a workspace file into daemon-owned immutable attachment storage.
abstract interface class AttachmentPublisher {
  /// Publishes the regular file at canonical [path].
  Future<ConversationAttachment> publish(String path);
}

/// Resolves an opaque attachment ID without accepting a filesystem path.
abstract interface class AttachmentReader {
  /// Resolves one daemon-owned attachment reference.
  Future<ConversationAttachment> read(String id);
}

/// Resolves workspace paths without permitting lexical or linked escapes.
final class WorkspacePathGuard {
  /// Creates a guard for [workspaceRoot].
  new(
    String workspaceRoot, {
    file_api.FileSystem fileSystem = const LocalFileSystem(),
    this._platform = const Platform(),
  }) : _fileSystem = fileSystem,
       _workspaceRoot = fileSystem
           .directory(workspaceRoot)
           .resolveSymbolicLinksSync();

  final file_api.FileSystem _fileSystem;
  final Platform _platform;
  final String _workspaceRoot;

  /// Resolves an existing file or directory inside the workspace.
  String resolveExisting(String candidate) {
    final path = _fileSystem.path;
    final lexical = path.isAbsolute(candidate)
        ? candidate
        : path.join(_workspaceRoot, candidate);
    final resolved = _fileSystem.file(lexical).resolveSymbolicLinksSync();
    _assertInside(resolved);
    return resolved;
  }

  /// Resolves a possibly-new path whose closest existing ancestor is inside.
  String resolveWritable(String candidate) {
    final path = _fileSystem.path;
    final lexical = path.normalize(
      path.isAbsolute(candidate)
          ? candidate
          : path.join(_workspaceRoot, candidate),
    );
    var ancestor = path.dirname(lexical);
    final missingSegments = <String>[path.basename(lexical)];
    while (!_fileSystem.directory(ancestor).existsSync()) {
      final parent = path.dirname(ancestor);
      if (parent == ancestor) {
        throw FileSystemException('No existing writable ancestor.', lexical);
      }
      missingSegments.insert(0, path.basename(ancestor));
      ancestor = parent;
    }
    final resolvedAncestor = _fileSystem
        .directory(ancestor)
        .resolveSymbolicLinksSync();
    final resolved = path.joinAll(<String>[
      resolvedAncestor,
      ...missingSegments,
    ]);
    _assertInside(resolved);
    return resolved;
  }

  void _assertInside(String path) {
    final root = _platform.isWindows
        ? _workspaceRoot.toLowerCase()
        : _workspaceRoot;
    final candidate = _platform.isWindows ? path.toLowerCase() : path;
    if (candidate != root && !_fileSystem.path.isWithin(root, candidate)) {
      throw FileSystemException('Path escapes the workspace.', path);
    }
  }
}

/// Why a host-owned wait stopped.
enum SleepOutcome {
  /// The full duration elapsed.
  elapsed,

  /// New turn input interrupted the wait.
  interrupted,
}

/// Host-owned time and cancellable waiting.
abstract interface class AgentClock {
  /// Current time in UTC.
  DateTime nowUtc();

  /// Waits until elapsed, interrupted by input, or cancelled.
  Future<SleepOutcome> sleep(Duration duration, CancellationToken cancellation);
}

/// One drain of a live [ExecSession].
final class ExecSessionChunk {
  /// Creates a process output chunk.
  const new({
    required this.output,
    required this.isRunning,
    this.exitCode,
    this.wallTime = Duration.zero,
  });

  /// Output produced since the previous read.
  final String output;

  /// Whether the process remains alive.
  final bool isRunning;

  /// Exit status after completion.
  final int? exitCode;

  /// Actual duration spent observing output.
  final Duration wallTime;
}

/// Live process handle owned by the host.
abstract interface class ExecSession {
  /// Session-local handle.
  int get id;

  /// Writes characters to standard input.
  Future<void> write(String chars);

  /// Drains buffered output, waiting no longer than [yieldTime].
  Future<ExecSessionChunk> read(Duration yieldTime);

  /// Interrupts the foreground process.
  Future<void> interrupt();
}

/// Owns process handles for one Tinest session.
abstract interface class ExecSessionHost {
  /// Starts a process in an already-validated working directory.
  Future<ExecSession> start({
    required String command,
    required String workingDirectory,
    required bool tty,
    String? shell,
    bool login = true,
  });

  /// Looks up a live session-local handle.
  ExecSession? lookup(int sessionId);

  /// Whether the start command for a handle has been approved.
  bool isApproved(int sessionId);

  /// Records approval for a handle.
  void markApproved(int sessionId);

  /// Terminates and forgets a handle owned by this host.
  Future<bool> terminate(int sessionId);
}
