import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:protocol/protocol.dart';

/// Git CLI adapter that never invokes a shell.
final class ProcessGitWorkspaceGateway implements GitWorkspaceGateway {
  /// Creates a Git adapter using the injected process boundary.
  const new(this._commands);

  final CommandRunner _commands;

  @override
  Future<String?> repositoryRoot(String path) async {
    final result = await _commands.run('git', const <String>[
      'rev-parse',
      '--show-toplevel',
    ], workingDirectory: path);
    return result.exitCode == 0 ? result.stdout.trim() : null;
  }

  @override
  Future<List<GitWorktreeSnapshot>> listWorktrees(String repositoryRoot) async {
    const arguments = <String>['worktree', 'list', '--porcelain'];
    final result = await _commands.run(
      'git',
      arguments,
      workingDirectory: repositoryRoot,
    );
    _requireSuccess(result, arguments, repositoryRoot);
    return parseGitWorktreePorcelain(result.stdout);
  }

  @override
  Future<Set<String>> localBranchNames(String repositoryRoot) async {
    const arguments = <String>[
      'for-each-ref',
      '--format=%(refname:short)',
      'refs/heads',
    ];
    final result = await _commands.run(
      'git',
      arguments,
      workingDirectory: repositoryRoot,
    );
    _requireSuccess(result, arguments, repositoryRoot);
    return result.stdout
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toSet();
  }

  @override
  Future<List<GitBranchDto>> listBranches(String repositoryRoot) async {
    const arguments = <String>[
      'for-each-ref',
      '--format=%(refname)%00%(refname:short)%00%(HEAD)%00%(symref:short)',
      'refs/heads',
      'refs/remotes',
    ];
    final result = await _commands.run(
      'git',
      arguments,
      workingDirectory: repositoryRoot,
    );
    _requireSuccess(result, arguments, repositoryRoot);
    final checkedOut = (await listWorktrees(repositoryRoot))
        .map((item) => item.branch)
        .nonNulls
        .toSet();
    final branches = <GitBranchDto>[];
    final defaults = <String>{};
    for (final line in result.stdout.split('\n')) {
      if (line.isEmpty) continue;
      final fields = line.split('\u0000');
      if (fields.length < 2) continue;
      final refname = fields.first;
      final name = fields[1];
      final isRemote = refname.startsWith('refs/remotes/');
      final symref = fields.length > 3 ? fields[3] : '';
      // `origin/HEAD` is a pointer, not a branch: record its target instead.
      if (symref.isNotEmpty) {
        defaults.add(symref);
        continue;
      }
      branches.add(
        GitBranchDto(
          name: name,
          current: fields.length > 2 && fields[2] == '*',
          checkedOut: !isRemote && checkedOut.contains(name),
          isRemote: isRemote,
        ),
      );
    }
    return branches
        .map(
          (branch) => defaults.contains(branch.name)
              ? branch.copyWith(isDefault: true)
              : branch,
        )
        .toList(growable: false);
  }

  @override
  Future<List<String>> listRemotes(String repositoryRoot) async {
    const arguments = <String>['remote'];
    final result = await _commands.run(
      'git',
      arguments,
      workingDirectory: repositoryRoot,
    );
    _requireSuccess(result, arguments, repositoryRoot);
    return result.stdout
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<bool> fetchRemote(String repositoryRoot, String remote) async {
    final result = await _commands.run('git', <String>[
      'fetch',
      remote,
    ], workingDirectory: repositoryRoot);
    return result.exitCode == 0;
  }

  @override
  Future<void> createWorktree(GitWorktreeCreateRequest request) async {
    final arguments = <String>['worktree', 'add'];
    if (request.mode == WorktreeCreateMode.newBranch) {
      arguments
        ..add('-b')
        ..add(request.branchName)
        ..add(request.path)
        ..add(request.baseBranch ?? 'HEAD');
    } else {
      arguments
        ..add(request.path)
        ..add(request.branchName);
    }
    final result = await _commands.run(
      'git',
      arguments,
      workingDirectory: request.repositoryRoot,
    );
    _requireSuccess(result, arguments, request.repositoryRoot);
  }

  @override
  Future<GitWorktreeState> inspectWorktree(String path) async {
    const statusArguments = <String>['status', '--porcelain=v1'];
    final status = await _commands.run(
      'git',
      statusArguments,
      workingDirectory: path,
    );
    _requireSuccess(status, statusArguments, path);
    final upstream = await _commands.run('git', const <String>[
      'rev-parse',
      '--abbrev-ref',
      '@{upstream}',
    ], workingDirectory: path);
    var unpushed = 0;
    if (upstream.exitCode == 0) {
      const countArguments = <String>[
        'rev-list',
        '--count',
        '@{upstream}..HEAD',
      ];
      final count = await _commands.run(
        'git',
        countArguments,
        workingDirectory: path,
      );
      _requireSuccess(count, countArguments, path);
      unpushed = int.tryParse(count.stdout.trim()) ?? 0;
    }
    return GitWorktreeState(
      dirty: status.stdout.trim().isNotEmpty,
      unpushedCommitCount: unpushed,
    );
  }

  @override
  Future<void> removeWorktree(
    String repositoryRoot,
    String path, {
    bool force = false,
  }) async {
    final arguments = <String>[
      'worktree',
      'remove',
      if (force) '--force',
      path,
    ];
    final result = await _commands.run(
      'git',
      arguments,
      workingDirectory: repositoryRoot,
    );
    _requireSuccess(result, arguments, repositoryRoot);
  }
}

/// Parses the stable porcelain output of `git worktree list`.
List<GitWorktreeSnapshot> parseGitWorktreePorcelain(String output) {
  final result = <GitWorktreeSnapshot>[];
  String? path;
  String? branch;
  String? head;
  void flush() {
    if (path == null) return;
    result.add(GitWorktreeSnapshot(path: path!, branch: branch, head: head));
    path = null;
    branch = null;
    head = null;
  }

  for (final line in '${output.trimRight()}\n\n'.split('\n')) {
    if (line.isEmpty) {
      flush();
    } else if (line.startsWith('worktree ')) {
      path = line.substring('worktree '.length);
    } else if (line.startsWith('HEAD ')) {
      head = line.substring('HEAD '.length);
    } else if (line.startsWith('branch refs/heads/')) {
      branch = line.substring('branch refs/heads/'.length);
    }
  }
  return List<GitWorktreeSnapshot>.unmodifiable(result);
}

void _requireSuccess(
  CommandResult result,
  List<String> arguments,
  String workingDirectory,
) {
  if (result.exitCode == 0) return;
  throw GitCommandException(
    arguments: arguments,
    workingDirectory: workingDirectory,
    exitCode: result.exitCode,
    stderr: result.stderr.trim(),
  );
}
