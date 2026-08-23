import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:protocol/protocol.dart';
import 'package:uuid/uuid.dart';

export 'package:agent/agent.dart' show Clock, SystemClock;

/// One host-owned skill document selected for implicit turn guidance.
///
/// This is raw catalog data. The active Lua extension decides whether and how
/// to turn it into model prompt blocks.
final class ImplicitSkillDocument {
  /// Creates one immutable implicit skill document.
  const ImplicitSkillDocument({
    required this.name,
    required this.instructions,
  });

  /// Stable catalog name.
  final String name;

  /// Markdown body loaded from the protected skill source.
  final String instructions;
}

/// Optional metadata surface implemented by catalogs with implicit skills.
abstract interface class ImplicitSkillDocumentSource {
  /// Returns protected implicit documents in deterministic display order.
  List<ImplicitSkillDocument> implicitSkillDocuments();
}

/// Public API exposed by this library.
abstract interface class IdGenerator {
  /// The generate public API member.
  String generate();
}

/// UuidIdGenerator defines a public contract.
final class UuidIdGenerator implements IdGenerator {
  /// Creates a [UuidIdGenerator].
  const UuidIdGenerator();

  @override
  String generate() => const Uuid().v4();
}

/// Public API exposed by this library.
abstract interface class WorkspaceCanonicalizer {
  /// Resolves [path] to its real directory.
  ///
  /// Throws a [FormatException], and nothing else, when the directory cannot
  /// be resolved. Callers live in the application layer and cannot name a
  /// `dart:io` failure, so every host error arrives as that one type.
  String canonicalizeExistingDirectory(String path);
}

/// IoWorkspaceCanonicalizer defines a public contract.
final class IoWorkspaceCanonicalizer implements WorkspaceCanonicalizer {
  /// Creates a [IoWorkspaceCanonicalizer].
  const IoWorkspaceCanonicalizer();

  @override
  String canonicalizeExistingDirectory(String path) {
    final directory = Directory(path);
    if (!directory.existsSync()) {
      throw const FormatException('Workspace directory not found.');
    }
    try {
      return directory.resolveSymbolicLinksSync();
    } on FileSystemException catch (error) {
      // A directory can vanish or turn unreadable between the check and the
      // resolve, and a broken link resolves to nothing at all.
      throw FormatException(
        'Workspace directory not resolvable: ${error.message}',
      );
    }
  }
}

/// Filesystem operations needed by the workspace application service.
abstract interface class WorkspacePathGateway {
  /// Resolves an existing directory and rejects missing paths.
  String canonicalizeExistingDirectory(String path);

  /// Creates a directory and missing parents.
  Future<void> createDirectory(String path);

  /// Returns matching directories on the daemon host.
  Future<List<DirectorySuggestionDto>> suggest(String query, int limit);
}

/// Production workspace filesystem adapter.
final class IoWorkspacePathGateway implements WorkspacePathGateway {
  /// Creates the production workspace filesystem adapter.
  const IoWorkspacePathGateway();

  @override
  String canonicalizeExistingDirectory(String path) =>
      const IoWorkspaceCanonicalizer().canonicalizeExistingDirectory(path);

  @override
  Future<void> createDirectory(String path) =>
      Directory(path).create(recursive: true);

  @override
  Future<List<DirectorySuggestionDto>> suggest(String query, int limit) async {
    if (limit <= 0) return const <DirectorySuggestionDto>[];
    final expanded = query.trim();
    if (expanded.isEmpty) return const <DirectorySuggestionDto>[];
    final candidate = Directory(expanded);
    final parent = candidate.existsSync() ? candidate : candidate.parent;
    if (!parent.existsSync()) return const <DirectorySuggestionDto>[];
    final needle = candidate.existsSync()
        ? ''
        : p.basename(expanded).toLowerCase();
    final suggestions = <DirectorySuggestionDto>[];
    try {
      await for (final entity in parent.list(followLinks: false)) {
        if (entity is! Directory) continue;
        final name = p.basename(entity.path);
        if (needle.isNotEmpty && !name.toLowerCase().contains(needle)) {
          continue;
        }
        suggestions.add(DirectorySuggestionDto(path: entity.path, name: name));
        if (suggestions.length == limit) break;
      }
    } on FileSystemException {
      return const <DirectorySuggestionDto>[];
    }
    suggestions.sort((left, right) => left.name.compareTo(right.name));
    return suggestions;
  }
}

/// One request for worktree files a composer mention can reference.
final class FileSearchRequest {
  /// Creates a file search request.
  ///
  /// [maxDepth] and [maxScannedEntries] bound the fallback walk used outside a
  /// Git repository so an unbounded tree cannot stall the daemon.
  const FileSearchRequest({
    required this.root,
    required this.query,
    this.limit = 50,
    this.maxDepth = 12,
    this.maxScannedEntries = 20000,
  });

  /// Absolute worktree root the search is scoped to.
  final String root;

  /// Query typed after the mention sigil; empty asks for the index head.
  final String query;

  /// Largest number of matches to return.
  final int limit;

  /// Deepest directory level the fallback walk descends into.
  final int maxDepth;

  /// Largest number of entries the fallback walk inspects.
  final int maxScannedEntries;
}

/// Gitignore-aware file index backing composer file mentions.
abstract interface class WorkspaceFileIndexGateway {
  /// Returns ranked matches for [request].
  Future<FileSearchResultDto> search(FileSearchRequest request);

  /// Drops any cached index for [root].
  void invalidate(String root);
}

/// One checkout reported by `git worktree list --porcelain`.
final class GitWorktreeSnapshot {
  /// Creates a Git worktree snapshot.
  const GitWorktreeSnapshot({
    required this.path,
    this.branch,
    this.head,
  });

  /// Checkout path.
  final String path;

  /// Short local branch name.
  final String? branch;

  /// Checked-out commit.
  final String? head;
}

/// State that may make archiving destructive.
final class GitWorktreeState {
  /// Creates worktree safety state.
  const GitWorktreeState({this.dirty = false, this.unpushedCommitCount = 0});

  /// Whether tracked or untracked files have changes.
  final bool dirty;

  /// Number of commits not present on the configured upstream.
  final int unpushedCommitCount;
}

/// Typed request for `git worktree add`.
final class GitWorktreeCreateRequest {
  /// Creates a managed-worktree request.
  const GitWorktreeCreateRequest({
    required this.repositoryRoot,
    required this.path,
    required this.mode,
    required this.branchName,
    this.baseBranch,
  });

  /// Repository root used as the Git working directory.
  final String repositoryRoot;

  /// New checkout path.
  final String path;

  /// Whether a branch is created or an existing branch is checked out.
  final WorktreeCreateMode mode;

  /// Normalized local branch name.
  final String branchName;

  /// Base revision for a newly-created branch.
  final String? baseBranch;
}

/// A Git invocation that exited non-zero.
///
/// The adapter raises this instead of a bare [StateError] so the transport can
/// report the real command and its stderr; without it the only surviving
/// diagnostic is a generic internal failure.
final class GitCommandException implements Exception {
  /// Creates a failed Git invocation report.
  const GitCommandException({
    required this.arguments,
    required this.workingDirectory,
    required this.exitCode,
    required this.stderr,
  });

  /// Arguments passed to `git`, without the executable itself.
  final List<String> arguments;

  /// Directory the command ran in.
  final String workingDirectory;

  /// Non-zero exit code Git reported.
  final int exitCode;

  /// Trimmed standard error, which is where Git explains itself.
  final String stderr;

  /// The invocation as a copy-pasteable command line.
  String get commandLine => 'git ${arguments.join(' ')}';

  @override
  String toString() => 'GitCommandException($commandLine): exit $exitCode';
}

/// Git operations used by workspace lifecycle logic.
abstract interface class GitWorkspaceGateway {
  /// Resolves a repository root, or null for a non-Git directory.
  Future<String?> repositoryRoot(String path);

  /// Lists active Git worktrees.
  Future<List<GitWorktreeSnapshot>> listWorktrees(String repositoryRoot);

  /// Lists local and remote-tracking branches with checkout state.
  Future<List<GitBranchDto>> listBranches(String repositoryRoot);

  /// Lists the names of every local branch.
  ///
  /// Separate from [listBranches] because collision checks run on the create
  /// path and do not need the checkout state that method resolves with a
  /// second `git worktree list` call.
  Future<Set<String>> localBranchNames(String repositoryRoot);

  /// Lists configured remote names.
  Future<List<String>> listRemotes(String repositoryRoot);

  /// Updates one remote, reporting whether the network call succeeded.
  Future<bool> fetchRemote(String repositoryRoot, String remote);

  /// Creates a managed checkout.
  Future<void> createWorktree(GitWorktreeCreateRequest request);

  /// Inspects dirty and unpushed state.
  Future<GitWorktreeState> inspectWorktree(String path);

  /// Removes a managed checkout through Git.
  ///
  /// [force] discards modified and untracked files, which setup hooks
  /// routinely create, and is only set once the caller has confirmed the
  /// archive risks.
  Future<void> removeWorktree(
    String repositoryRoot,
    String path, {
    bool force = false,
  });
}

/// Result returned by a process invocation.
final class CommandResult {
  /// Creates an immutable command result.
  const CommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  /// Process exit code.
  final int exitCode;

  /// Standard output.
  final String stdout;

  /// Standard error.
  final String stderr;
}

/// Process boundary used by the Git adapter.
abstract interface class CommandRunner {
  /// Runs an executable with an argument list and no shell interpolation.
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
  });
}

/// Runs project-configured worktree lifecycle commands.
///
/// Unlike [CommandRunner], hook commands are authored by the user in
/// `.tinest/config.json` and are expected to use shell syntax such as pipes and
/// environment expansion, so they are handed to the platform shell verbatim.
abstract interface class WorktreeHookRunner {
  /// Runs one hook command and reports its outcome.
  Future<CommandResult> run(
    String command, {
    required String workingDirectory,
    required Map<String, String> environment,
  });
}

/// A running command the agent can read from, write to, and stop.
///
/// Shared by pseudo-terminals and plain pipes so an exec session does not care
/// which one it is driving.
abstract interface class ExecProcess {
  /// Emits decoded output as it arrives.
  Stream<String> get outputs;

  /// Completes with the process exit code.
  Future<int> get exitCode;

  /// Writes to the process standard input.
  Future<void> write(String data);

  /// Stops the foreground command without ending the session.
  ///
  /// How that happens depends on the transport, which is exactly why it lives
  /// here: a terminal turns ETX into SIGINT through its line discipline, while
  /// on a pipe ETX is an ordinary byte and the signal has to be sent directly.
  Future<void> interrupt();

  /// Terminates the process.
  Future<void> terminate();
}

/// Starts commands on plain pipes, with no pseudo-terminal attached.
///
/// This is the path for ordinary non-interactive commands: without a terminal
/// the child emits no escape sequences and echoes no input, so its output is
/// what the program actually printed rather than what a screen would show.
abstract interface class PipeGateway {
  /// Starts [shell] in [workingDirectory].
  Future<ExecProcess> start({
    required ShellSpecDto shell,
    required String workingDirectory,
  });
}

/// Production pipe adapter.
final class IoPipeGateway implements PipeGateway {
  /// Creates the production pipe adapter.
  const IoPipeGateway();

  @override
  Future<ExecProcess> start({
    required ShellSpecDto shell,
    required String workingDirectory,
  }) async {
    final process = await Process.start(
      shell.executable,
      shell.arguments,
      workingDirectory: workingDirectory,
    );
    return _IoPipeProcess(process);
  }
}

final class _IoPipeProcess implements ExecProcess {
  _IoPipeProcess(this._process) {
    // stdout and stderr are interleaved because the agent reads one transcript
    // and a program's diagnostics are only meaningful next to the output they
    // describe. Lossy decoding keeps a stray byte from killing the stream.
    _subscriptions = <StreamSubscription<String>>[
      _process.stdout.transform(_decoder).listen(_outputs.add, onDone: _done),
      _process.stderr.transform(_decoder).listen(_outputs.add, onDone: _done),
    ];
  }

  static const Utf8Decoder _decoder = Utf8Decoder(allowMalformed: true);

  final Process _process;

  /// Buffers until the session subscribes, so nothing a fast command prints
  /// before the first read is lost.
  final StreamController<String> _outputs = StreamController<String>();
  late final List<StreamSubscription<String>> _subscriptions;
  int _open = 2;
  bool _closed = false;

  void _done() {
    if (--_open == 0) _close();
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    unawaited(_outputs.close());
  }

  @override
  Stream<String> get outputs => _outputs.stream;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  Future<void> write(String data) async {
    _process.stdin.write(data);
    // A pipe is buffered, unlike a terminal, so an unflushed write would sit
    // here while the caller waits for output that cannot arrive.
    await _process.stdin.flush();
  }

  @override
  Future<void> interrupt() async => _process.kill(ProcessSignal.sigint);

  @override
  Future<void> terminate() async {
    _process.kill(ProcessSignal.sigkill);
    await Future.wait(
      _subscriptions.map((subscription) => subscription.cancel()),
    );
    _close();
  }
}

/// Production shell adapter for worktree lifecycle hooks.
final class ShellWorktreeHookRunner implements WorktreeHookRunner {
  /// Creates the production hook adapter.
  const ShellWorktreeHookRunner();

  @override
  Future<CommandResult> run(
    String command, {
    required String workingDirectory,
    required Map<String, String> environment,
  }) async {
    final result = await Process.run(
      Platform.isWindows ? 'cmd.exe' : '/bin/sh',
      Platform.isWindows ? <String>['/c', command] : <String>['-c', command],
      workingDirectory: workingDirectory,
      environment: environment,
    );
    return CommandResult(
      exitCode: result.exitCode,
      stdout: '${result.stdout}',
      stderr: '${result.stderr}',
    );
  }
}

/// Production process adapter.
final class IoCommandRunner implements CommandRunner {
  /// Creates the production process adapter.
  const IoCommandRunner();

  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
  }) async {
    final result = await Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );
    return CommandResult(
      exitCode: result.exitCode,
      stdout: '${result.stdout}',
      stderr: '${result.stderr}',
    );
  }
}
