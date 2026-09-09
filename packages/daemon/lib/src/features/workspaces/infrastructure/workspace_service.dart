import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:daemon/src/features/workspaces/infrastructure/project_settings.dart';
import 'package:daemon/src/shared/infrastructure/persistence/repositories.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:path/path.dart' as p;
import 'package:protocol/protocol.dart';

bool _sameWorktreePath(String first, String second) =>
    p.equals(first, second) || p.windows.equals(first, second);

/// Why a worktree lifecycle operation could not proceed.
enum WorktreeFailureReason {
  /// No workspace is registered under the requested id.
  workspaceNotFound,

  /// The operation needs a Git repository and the workspace is not one.
  workspaceNotGit,

  /// No worktree is registered under the requested id.
  worktreeNotFound,

  /// The requested branch name cannot be normalized into a Git ref.
  invalidBranchName,

  /// A local branch already uses the requested name.
  branchAlreadyExists,

  /// Another active checkout already occupies the generated path.
  pathInUse,

  /// A Git command exited non-zero.
  gitFailed,

  /// The checkout is not in a state that allows archiving.
  archiveBlocked,

  /// The daemon owns this workspace and refuses to register or remove it.
  workspaceProtected,
}

/// A worktree lifecycle operation that failed for a reason the user can act on.
///
/// Modelled on `TerminalCreationException`: the reason is what the transport
/// maps to a stable protocol code, and [details] carries the extra context a
/// client needs to explain the failure without parsing [message].
final class WorktreeFailure implements Exception {
  /// Creates a typed worktree lifecycle failure.
  const new(
    this.reason,
    this.message, {
    this.details = const <String, dynamic>{},
  });

  /// Why the operation failed.
  final WorktreeFailureReason reason;

  /// Diagnostic description; clients translate [reason] instead.
  final String message;

  /// Structured context safe to hand to a client.
  final Map<String, dynamic> details;

  @override
  String toString() => 'WorktreeFailure(${reason.name}): $message';
}

/// Repository and checkout lifecycle application service.
final class WorkspaceOperations {
  /// Creates a workspace service from typed persistence and host ports.
  new(
    this._workspaces,
    this._worktrees,
    this._agents,
    this._paths,
    this._git,
    this._clock,
    this._managedWorktreeRoot,
    this._fileIndex, [
    this._projectSettings = const FileProjectSettingsStore(),
    this._hooks = const ShellWorktreeHookRunner(),
  ]);

  final WorkspaceRepository _workspaces;
  final WorktreeRepository _worktrees;
  final SessionRepository _agents;
  final WorkspacePathGateway _paths;
  final GitWorkspaceGateway _git;
  final Clock _clock;
  final String _managedWorktreeRoot;
  final WorkspaceFileIndexGateway _fileIndex;
  final ProjectSettingsStore _projectSettings;
  final WorktreeHookRunner _hooks;
  final Map<String, int> _pendingManagedWorktreePaths = <String, int>{};

  /// Returns repositories and active worktrees as one catalog snapshot.
  Future<WorkspaceCatalogDto> catalog() async {
    final workspaces = await _workspaces.list();
    for (final workspace in workspaces) {
      if (workspace.kind != WorkspaceKind.git) continue;
      await _syncGitSnapshots(
        workspace,
        await _listWorktrees(workspace.rootPath),
      );
    }
    return WorkspaceCatalogDto(
      workspaces: workspaces,
      worktrees: await _worktrees.list(),
    );
  }

  /// Identity of the implicit home workspace when this daemon creates it.
  ///
  /// A workspace the user had already registered at the home path keeps its own
  /// id and is adopted instead, so the guards below key on
  /// [WorkspaceKind.home] rather than on this constant.
  static const String homeWorkspaceId = 'home';

  /// Identity of the sole checkout of the implicit home workspace.
  static const String homeWorktreeId = 'home-checkout';

  /// Registers the user home directory as the implicit home workspace.
  ///
  /// Sessions the user starts without picking a project run in this checkout,
  /// which keeps every session bound to a real working directory. Runs on every
  /// boot and is idempotent; a workspace already registered at [userHome] is
  /// adopted rather than duplicated.
  ///
  /// Returns null when [userHome] is null, which is how tests and CI runs keep
  /// the daemon away from any real home.
  Future<WorktreeDto?> provisionHome(String? userHome) async {
    if (userHome == null) return null;
    final rootPath = _paths.canonicalizeExistingDirectory(userHome);
    final existing =
        await _workspaces.getByRootPath(rootPath) ?? await _homeWorkspace();
    final workspace = await _workspaces.upsert(
      WorkspaceDto(
        id: existing?.id ?? homeWorkspaceId,
        name: p.basename(rootPath),
        rootPath: rootPath,
        kind: WorkspaceKind.home,
        createdAt: existing?.createdAt ?? _clock.nowUtc(),
      ),
    );
    final checkout = await _worktrees.getByPath(rootPath);
    return await _worktrees.upsert(
      WorktreeDto(
        id: checkout?.id ?? homeWorktreeId,
        workspaceId: workspace.id,
        name: workspace.name,
        path: rootPath,
        kind: WorktreeKind.directory,
        isTinestOwned: false,
        createdAt: checkout?.createdAt ?? _clock.nowUtc(),
      ),
    );
  }

  /// Returns the implicit home workspace, when this daemon has one.
  Future<WorkspaceDto?> _homeWorkspace() async => (await _workspaces.list())
      .where((item) => item.kind == WorkspaceKind.home)
      .firstOrNull;

  /// Registers a directory or Git repository and discovers its checkouts.
  Future<WorkspaceRegisterResultDto> register(
    WorkspaceRegisterParamsDto request,
  ) async {
    final selectedPath = _paths.canonicalizeExistingDirectory(request.rootPath);
    // Registration merges by root path, so without this the home directory
    // would silently return the home workspace, which every project list
    // filters out.
    if ((await _workspaces.getByRootPath(selectedPath))?.kind ==
        WorkspaceKind.home) {
      throw const WorktreeFailure(
        WorktreeFailureReason.workspaceProtected,
        'The home directory cannot be registered as a project.',
      );
    }
    final discoveredRoot = await _git.repositoryRoot(selectedPath);
    if (discoveredRoot == null) {
      final existing = await _workspaces.getByRootPath(selectedPath);
      final workspace =
          existing ??
          await _workspaces.register(
            WorkspaceDto(
              id: request.workspaceId,
              name: request.name,
              rootPath: selectedPath,
              kind: WorkspaceKind.directory,
              createdAt: _clock.nowUtc(),
            ),
          );
      final checkout = await _worktrees.upsert(
        WorktreeDto(
          id: request.checkoutId,
          workspaceId: workspace.id,
          name: request.name,
          path: selectedPath,
          kind: WorktreeKind.directory,
          isTinestOwned: false,
          createdAt: _clock.nowUtc(),
        ),
      );
      return WorkspaceRegisterResultDto(
        workspace: workspace,
        worktrees: <WorktreeDto>[checkout],
      );
    }

    final snapshots = await _listWorktrees(discoveredRoot);
    final repositoryRoot = snapshots.isEmpty
        ? discoveredRoot
        : snapshots.first.path;
    final canonicalRoot = _paths.canonicalizeExistingDirectory(repositoryRoot);
    final existing = await _workspaces.getByRootPath(canonicalRoot);
    final workspace =
        existing ??
        await _workspaces.register(
          WorkspaceDto(
            id: request.workspaceId,
            name: request.name,
            rootPath: canonicalRoot,
            kind: WorkspaceKind.git,
            createdAt: _clock.nowUtc(),
          ),
        );
    final discovered = await _upsertGitSnapshots(
      workspace,
      snapshots,
      checkoutId: request.checkoutId,
    );
    return WorkspaceRegisterResultDto(
      workspace: workspace,
      worktrees: discovered,
    );
  }

  /// Refreshes worktree metadata for one repository.
  Future<WorkspaceCatalogDto> refresh(String workspaceId) async {
    final workspace = await _requireWorkspace(workspaceId);
    if (workspace.kind == WorkspaceKind.git) {
      await _syncGitSnapshots(
        workspace,
        await _listWorktrees(workspace.rootPath),
      );
    }
    return await catalog();
  }

  /// Removes a workspace registration when no session history references it.
  ///
  /// The implicit home workspace is owned by the daemon and is never removable;
  /// dropping it would orphan every session that belongs to no project.
  Future<void> unregister(String workspaceId) async {
    final workspace = await _requireWorkspace(workspaceId);
    if (workspace.kind == WorkspaceKind.home) {
      throw const WorktreeFailure(
        WorktreeFailureReason.workspaceProtected,
        'The home workspace cannot be unregistered.',
      );
    }
    await _workspaces.unregister(workspaceId);
  }

  /// Searches directories on the daemon host.
  Future<List<DirectorySuggestionDto>> suggestDirectories(
    String query,
    int limit,
  ) => _paths.suggest(query, limit);

  /// Searches one worktree for files a composer mention can reference.
  Future<FileSearchResultDto> searchFiles(FileSearchParamsDto request) async {
    final worktree = await _worktrees.getById(request.worktreeId);
    if (worktree == null || worktree.archivedAt != null) {
      throw const FormatException('Active worktree not found.');
    }
    return await _fileIndex.search(
      FileSearchRequest(
        root: worktree.path,
        query: request.query,
        limit: request.limit.clamp(1, 100),
      ),
    );
  }

  /// Updates the remote a base ref belongs to so the new branch starts from
  /// the latest upstream commit; a failed fetch falls back to the cached ref.
  Future<void> _fetchBaseRemote(
    String repositoryRoot,
    WorktreeCreateParamsDto request,
  ) async {
    final base = request.baseBranch;
    if (request.mode != WorktreeCreateMode.newBranch || base == null) return;
    final separator = base.indexOf('/');
    if (separator <= 0) return;
    final remote = base.substring(0, separator);
    if (!(await _git.listRemotes(repositoryRoot)).contains(remote)) return;
    await _git.fetchRemote(repositoryRoot, remote);
  }

  /// Lists local branches in one Git workspace.
  Future<List<GitBranchDto>> listBranches(String workspaceId) async {
    final workspace = await _requireWorkspace(workspaceId);
    if (workspace.kind != WorkspaceKind.git) {
      throw const WorktreeFailure(
        WorktreeFailureReason.workspaceNotGit,
        'Workspace is not a Git repository.',
      );
    }
    return await _git.listBranches(workspace.rootPath);
  }

  /// Returns the `.tinest/config.json` settings of one registered workspace.
  Future<ProjectSettingsResultDto> getProjectSettings(
    String workspaceId,
  ) async {
    final workspace = await _requireWorkspace(workspaceId);
    return ProjectSettingsResultDto(
      settings: await _projectSettings.load(workspace.rootPath),
      sourcePath: _projectSettings.sourcePath(workspace.rootPath),
    );
  }

  /// Replaces the worktree hook section of one workspace's `.tinest/config.json`.
  Future<ProjectSettingsResultDto> saveProjectSettings(
    ProjectSettingsSaveParamsDto request,
  ) async {
    final workspace = await _requireWorkspace(request.workspaceId);
    await _projectSettings.save(workspace.rootPath, request.settings);
    return await getProjectSettings(workspace.id);
  }

  /// Creates a managed checkout from a new or existing local branch.
  Future<WorktreeResultDto> createWorktree(
    WorktreeCreateParamsDto request,
  ) async {
    final workspace = await _requireWorkspace(request.workspaceId);
    if (workspace.kind != WorkspaceKind.git) {
      throw const WorktreeFailure(
        WorktreeFailureReason.workspaceNotGit,
        'Managed worktrees require a Git repository.',
      );
    }
    if (await _worktrees.getById(request.id) case final existing?) {
      return WorktreeResultDto(worktree: existing);
    }
    final requested = _normalizeBranch(request.branchName);
    await _fetchBaseRemote(workspace.rootPath, request);
    final repositoryHash = sha256
        .convert(utf8.encode(workspace.rootPath))
        .toString()
        .substring(0, 12);
    // Build the checkout under the resolved managed root. Git answers every
    // later `worktree list` with the real directory, so a root reachable
    // through a Windows short name or a symlink would otherwise store a path
    // no snapshot ever matches, and the worktree would be archived and
    // rediscovered as a foreign one on the next catalog read.
    await _paths.createDirectory(_managedWorktreeRoot);
    final managedRoot = _paths.canonicalizeExistingDirectory(
      _managedWorktreeRoot,
    );
    String pathFor(String branch) =>
        p.join(managedRoot, repositoryHash, branch);
    final branch = await _resolveBranchName(
      workspace,
      request,
      requested,
      pathFor,
    );
    // The checkout path is already reserved by the branch resolution above, so
    // the release below balances that claim.
    final checkoutPath = pathFor(branch);
    late final WorktreeDto worktree;
    try {
      await _paths.createDirectory(p.dirname(checkoutPath));
      try {
        await _git.createWorktree(
          GitWorktreeCreateRequest(
            repositoryRoot: workspace.rootPath,
            path: checkoutPath,
            mode: request.mode,
            branchName: branch,
            baseBranch: request.baseBranch,
          ),
        );
      } on GitCommandException catch (error) {
        // The pre-flight checks race with anything else touching the
        // repository, so Git remains the authority on why this failed.
        throw _gitFailure(error);
      }
      final snapshots = await _listWorktrees(workspace.rootPath);
      final snapshot = snapshots
          .where((item) => p.equals(item.path, checkoutPath))
          .firstOrNull;
      worktree = await _worktrees.upsert(
        WorktreeDto(
          id: request.id,
          workspaceId: workspace.id,
          name: branch,
          path: checkoutPath,
          branch: snapshot?.branch ?? branch,
          head: snapshot?.head,
          kind: WorktreeKind.linked,
          isTinestOwned: true,
          createdAt: _clock.nowUtc(),
        ),
      );
    } finally {
      final remaining = _pendingManagedWorktreePaths[checkoutPath]! - 1;
      if (remaining == 0) {
        _pendingManagedWorktreePaths.remove(checkoutPath);
      } else {
        _pendingManagedWorktreePaths[checkoutPath] = remaining;
      }
    }
    final hookRuns = await _runHooks(
      WorktreeHookPhase.setup,
      workspace: workspace,
      worktree: worktree,
    );
    if (hookRuns.any((run) => run.exitCode != 0)) {
      // A setup failure means the checkout is not safe to use. Remove the
      // Tinest-owned path before hiding it from the active catalog so a failed
      // bootstrap cannot leave an apparently usable worktree behind.
      await _git.removeWorktree(workspace.rootPath, worktree.path, force: true);
      final archivedAt = _clock.nowUtc();
      await _worktrees.archive(worktree.id, archivedAt);
      return WorktreeResultDto(
        worktree: worktree.copyWith(archivedAt: archivedAt),
        hookRuns: hookRuns,
      );
    }
    return WorktreeResultDto(worktree: worktree, hookRuns: hookRuns);
  }

  /// Picks the branch a new managed checkout will use.
  ///
  /// Only the daemon can answer this. Archiving a worktree removes the checkout
  /// but leaves its local branch behind, and the catalog a client deduplicates
  /// against hides archived rows, so a client left to choose alone keeps
  /// proposing a name Git already refuses.
  ///
  /// On success the generated checkout path is reserved; the caller releases
  /// it once the checkout is registered.
  Future<String> _resolveBranchName(
    WorkspaceDto workspace,
    WorktreeCreateParamsDto request,
    String requested,
    String Function(String branch) pathFor,
  ) async {
    // Checking out an existing branch cannot rename it, so only the new-branch
    // path consults the local branch list.
    final branches = request.mode == WorktreeCreateMode.newBranch
        ? await _git.localBranchNames(workspace.rootPath)
        : const <String>{};
    final conflict = await _reserveCheckoutPath(requested, branches, pathFor);
    if (conflict == null) return requested;
    if (request.branchNaming == WorktreeBranchNaming.exact) {
      throw WorktreeFailure(
        conflict,
        'The branch "$requested" is already in use.',
        details: <String, dynamic>{'branchName': requested},
      );
    }
    for (var suffix = 2; suffix <= _maxDerivedBranchSuffix; suffix += 1) {
      final candidate = '$requested-$suffix';
      if (await _reserveCheckoutPath(candidate, branches, pathFor) == null) {
        return candidate;
      }
    }
    throw WorktreeFailure(
      conflict,
      'No free branch name derived from "$requested" was available.',
      details: <String, dynamic>{'branchName': requested},
    );
  }

  /// Claims the checkout path of [candidate], or reports the blocking conflict.
  ///
  /// The claim is made in the same synchronous step as the last free check so
  /// two concurrent submissions of the same prompt cannot both take one slug.
  Future<WorktreeFailureReason?> _reserveCheckoutPath(
    String candidate,
    Set<String> branches,
    String Function(String branch) pathFor,
  ) async {
    if (branches.contains(candidate)) {
      return WorktreeFailureReason.branchAlreadyExists;
    }
    final path = pathFor(candidate);
    if (_pendingManagedWorktreePaths.containsKey(path)) {
      return WorktreeFailureReason.pathInUse;
    }
    final registered = await _worktrees.getByPath(path);
    if (registered != null) return WorktreeFailureReason.pathInUse;
    if (_pendingManagedWorktreePaths.containsKey(path)) {
      return WorktreeFailureReason.pathInUse;
    }
    _pendingManagedWorktreePaths[path] = 1;
    return null;
  }

  WorktreeFailure _gitFailure(GitCommandException error) => WorktreeFailure(
    WorktreeFailureReason.gitFailed,
    error.stderr.isEmpty
        ? '${error.commandLine} exited with ${error.exitCode}.'
        : error.stderr,
    details: <String, dynamic>{
      'command': error.commandLine,
      'exitCode': error.exitCode,
      'stderr': error.stderr,
    },
  );

  /// Returns current archive safety conditions.
  Future<WorktreeArchivePreviewDto> previewArchive(String worktreeId) async {
    final worktree = await _requireWorktree(worktreeId);
    final state = worktree.kind == WorktreeKind.directory
        ? const GitWorktreeState()
        : await _git.inspectWorktree(worktree.path);
    return WorktreeArchivePreviewDto(
      worktreeId: worktree.id,
      dirty: state.dirty,
      unpushedCommitCount: state.unpushedCommitCount,
      runningSessionCount: await _agents.countActive(worktree.id),
      removesDirectory: isArchivableWorktreeKind(worktree.kind),
    );
  }

  /// Archives one worktree and removes only Tinest-owned managed checkouts.
  Future<WorktreeResultDto> archive(
    String worktreeId, {
    required bool force,
  }) async {
    final worktree = await _requireWorktree(worktreeId);
    if ((await _workspaces.getById(worktree.workspaceId))?.kind ==
        WorkspaceKind.home) {
      throw const WorktreeFailure(
        WorktreeFailureReason.archiveBlocked,
        'The home checkout cannot be archived.',
      );
    }
    if (!isArchivableWorktreeKind(worktree.kind)) {
      // The workspace root is never Tinest-owned, so archiving it would keep
      // the directory, hide the project, and let the next refresh rediscover
      // the same path under a new id that no existing session references.
      throw const WorktreeFailure(
        WorktreeFailureReason.archiveBlocked,
        'The project checkout cannot be archived.',
      );
    }
    final preview = await previewArchive(worktreeId);
    if (preview.runningSessionCount > 0) {
      throw const WorktreeFailure(
        WorktreeFailureReason.archiveBlocked,
        'A session is still running in this worktree.',
      );
    }
    if (!force && (preview.dirty || preview.unpushedCommitCount > 0)) {
      throw const WorktreeFailure(
        WorktreeFailureReason.archiveBlocked,
        'Archive confirmation is required for local changes.',
      );
    }
    final workspace = await _requireWorkspace(worktree.workspaceId);
    final hookRuns = await _runHooks(
      WorktreeHookPhase.teardown,
      workspace: workspace,
      worktree: worktree,
    );
    try {
      await _git.removeWorktree(
        workspace.rootPath,
        worktree.path,
        force: force,
      );
    } on GitCommandException catch (error) {
      throw _gitFailure(error);
    }
    final archivedAt = _clock.nowUtc();
    await _worktrees.archive(worktree.id, archivedAt);
    return WorktreeResultDto(
      worktree: (await _worktrees.getById(worktree.id))!,
      hookRuns: hookRuns,
    );
  }

  /// Runs configured hooks in order and stops at the first failing command.
  ///
  /// A failing hook never rolls back or blocks the surrounding lifecycle
  /// operation; the outcome is reported to the caller instead.
  Future<List<WorktreeHookRunDto>> _runHooks(
    WorktreeHookPhase phase, {
    required WorkspaceDto workspace,
    required WorktreeDto worktree,
  }) async {
    final ProjectSettingsDto settings;
    try {
      settings = await _projectSettings.load(workspace.rootPath);
    } on FormatException catch (error) {
      return <WorktreeHookRunDto>[
        WorktreeHookRunDto(
          phase: phase,
          command: _projectSettings.sourcePath(workspace.rootPath),
          exitCode: -1,
          stdout: '',
          stderr: error.message,
        ),
      ];
    }
    final commands = switch (phase) {
      WorktreeHookPhase.setup => settings.setup,
      WorktreeHookPhase.teardown => settings.teardown,
    };
    final environment = <String, String>{
      'CODER_PROJECT_PATH': workspace.rootPath,
      'CODER_WORKTREE_PATH': worktree.path,
      'CODER_BRANCH': ?worktree.branch,
    };
    final runs = <WorktreeHookRunDto>[];
    for (final command in commands) {
      final result = await _hooks.run(
        command,
        workingDirectory: worktree.path,
        environment: environment,
      );
      runs.add(
        WorktreeHookRunDto(
          phase: phase,
          command: command,
          exitCode: result.exitCode,
          stdout: result.stdout,
          stderr: result.stderr,
        ),
      );
      if (result.exitCode != 0) break;
    }
    return runs;
  }

  /// Reads Git worktrees with every path resolved to its real directory.
  ///
  /// Git and the daemon can spell the same directory differently: Git prints
  /// the resolved path with forward slashes, while a stored path keeps the host
  /// separator and whatever short or symlinked prefix it was built from.
  /// Resolving here gives the whole service one spelling to compare and store.
  Future<List<GitWorktreeSnapshot>> _listWorktrees(
    String repositoryRoot,
  ) async {
    final snapshots = await _git.listWorktrees(repositoryRoot);
    return <GitWorktreeSnapshot>[
      for (final snapshot in snapshots)
        GitWorktreeSnapshot(
          path: _resolveExistingPath(snapshot.path),
          branch: snapshot.branch,
          head: snapshot.head,
        ),
    ];
  }

  /// Resolves [path] when it still exists, and normalizes it when it does not.
  ///
  /// Git lists prunable worktrees whose directory is already gone, and those
  /// must stay in the snapshot so the catalog can archive them.
  String _resolveExistingPath(String path) {
    try {
      return _paths.canonicalizeExistingDirectory(path);
    } on FormatException {
      return p.normalize(path);
    }
  }

  Future<List<WorktreeDto>> _upsertGitSnapshots(
    WorkspaceDto workspace,
    List<GitWorktreeSnapshot> snapshots, {
    String? checkoutId,
  }) async {
    final result = <WorktreeDto>[];
    final activeWorktrees = await _worktrees.list(workspaceId: workspace.id);
    for (var index = 0; index < snapshots.length; index += 1) {
      final snapshot = snapshots[index];
      var existing = await _worktrees.getByPathIncludingArchived(snapshot.path);
      for (final worktree in activeWorktrees) {
        if (existing != null) break;
        if (_sameWorktreePath(worktree.path, snapshot.path)) {
          existing = worktree;
        }
      }
      if (existing == null &&
          _pendingManagedWorktreePaths.keys.any(
            (pending) => _sameWorktreePath(pending, snapshot.path),
          )) {
        continue;
      }
      final isCheckout = index == 0;
      final worktree = await _worktrees.upsert(
        WorktreeDto(
          id:
              existing?.id ??
              (isCheckout && checkoutId != null
                  ? checkoutId
                  : _stableWorktreeId(workspace.id, snapshot.path)),
          workspaceId: workspace.id,
          name: snapshot.branch ?? p.basename(snapshot.path),
          path: snapshot.path,
          branch: snapshot.branch,
          head: snapshot.head,
          kind:
              existing?.kind ??
              (isCheckout ? WorktreeKind.checkout : WorktreeKind.linked),
          isTinestOwned: existing?.isTinestOwned ?? false,
          createdAt: existing?.createdAt ?? _clock.nowUtc(),
        ),
      );
      result.add(worktree);
    }
    return result;
  }

  Future<List<WorktreeDto>> _syncGitSnapshots(
    WorkspaceDto workspace,
    List<GitWorktreeSnapshot> snapshots,
  ) async {
    final discovered = await _upsertGitSnapshots(workspace, snapshots);
    final discoveredPaths = snapshots.map((snapshot) => snapshot.path).toList();
    for (final worktree in await _worktrees.list(workspaceId: workspace.id)) {
      if (discoveredPaths.any(
        (path) => _sameWorktreePath(path, worktree.path),
      )) {
        continue;
      }
      await _worktrees.archive(worktree.id, _clock.nowUtc());
    }
    return discovered;
  }

  /// Returns the checkout root of one registered workspace.
  Future<String> workspaceRoot(String workspaceId) async =>
      (await _requireWorkspace(workspaceId)).rootPath;

  Future<WorkspaceDto> _requireWorkspace(String id) async =>
      await _workspaces.getById(id) ??
      (throw WorktreeFailure(
        WorktreeFailureReason.workspaceNotFound,
        'Workspace not found: $id',
        details: <String, dynamic>{'workspaceId': id},
      ));

  Future<WorktreeDto> _requireWorktree(String id) async =>
      await _worktrees.getById(id) ??
      (throw WorktreeFailure(
        WorktreeFailureReason.worktreeNotFound,
        'Worktree not found: $id',
        details: <String, dynamic>{'worktreeId': id},
      ));
}

/// Repository registration and discovery operations used by RPC callers.
abstract interface class WorkspaceCatalogPort {
  /// Returns every registered workspace and active checkout.
  Future<WorkspaceCatalogDto> catalog();

  /// Ensures the optional user-home workspace exists.
  Future<WorktreeDto?> provisionHome(String? userHome);

  /// Registers a directory or repository.
  Future<WorkspaceRegisterResultDto> register(
    WorkspaceRegisterParamsDto request,
  );

  /// Refreshes discovered checkout metadata.
  Future<WorkspaceCatalogDto> refresh(String workspaceId);

  /// Removes a project registration.
  Future<void> unregister(String workspaceId);

  /// Suggests host directories matching a query.
  Future<List<DirectorySuggestionDto>> suggestDirectories(
    String query,
    int limit,
  );

  /// Searches files within an active worktree.
  Future<FileSearchResultDto> searchFiles(FileSearchParamsDto request);

  /// Resolves the root directory of a registered workspace.
  Future<String> workspaceRoot(String workspaceId);
}

/// Worktree and project-settings operations used by RPC callers.
abstract interface class WorktreeLifecyclePort {
  /// Lists branches available to a Git workspace.
  Future<List<GitBranchDto>> listBranches(String workspaceId);

  /// Reads project settings from a workspace root.
  Future<ProjectSettingsResultDto> getProjectSettings(String workspaceId);

  /// Writes project settings to a workspace root.
  Future<ProjectSettingsResultDto> saveProjectSettings(
    ProjectSettingsSaveParamsDto request,
  );

  /// Creates one managed checkout.
  Future<WorktreeResultDto> createWorktree(WorktreeCreateParamsDto request);

  /// Reports archive risks without changing the checkout.
  Future<WorktreeArchivePreviewDto> previewArchive(String worktreeId);

  /// Archives a checkout after enforcing safety rules.
  Future<WorktreeResultDto> archive(String worktreeId, {required bool force});
}

/// Cohesive workspace catalog view over shared workspace operations.
final class WorkspaceCatalogService implements WorkspaceCatalogPort {
  /// Creates the workspace catalog service.
  const new(this._operations);

  final WorkspaceOperations _operations;

  @override
  Future<WorkspaceCatalogDto> catalog() => _operations.catalog();
  @override
  Future<WorktreeDto?> provisionHome(String? userHome) =>
      _operations.provisionHome(userHome);
  @override
  Future<WorkspaceRegisterResultDto> register(
    WorkspaceRegisterParamsDto request,
  ) => _operations.register(request);
  @override
  Future<WorkspaceCatalogDto> refresh(String workspaceId) =>
      _operations.refresh(workspaceId);
  @override
  Future<void> unregister(String workspaceId) =>
      _operations.unregister(workspaceId);
  @override
  Future<List<DirectorySuggestionDto>> suggestDirectories(
    String query,
    int limit,
  ) => _operations.suggestDirectories(query, limit);
  @override
  Future<FileSearchResultDto> searchFiles(FileSearchParamsDto request) =>
      _operations.searchFiles(request);
  @override
  Future<String> workspaceRoot(String workspaceId) =>
      _operations.workspaceRoot(workspaceId);
}

/// Cohesive managed-worktree lifecycle view over shared workspace operations.
final class WorktreeLifecycleService implements WorktreeLifecyclePort {
  /// Creates the managed-worktree lifecycle service.
  const new(this._operations);

  final WorkspaceOperations _operations;

  @override
  Future<List<GitBranchDto>> listBranches(String workspaceId) =>
      _operations.listBranches(workspaceId);
  @override
  Future<ProjectSettingsResultDto> getProjectSettings(String workspaceId) =>
      _operations.getProjectSettings(workspaceId);
  @override
  Future<ProjectSettingsResultDto> saveProjectSettings(
    ProjectSettingsSaveParamsDto request,
  ) => _operations.saveProjectSettings(request);
  @override
  Future<WorktreeResultDto> createWorktree(WorktreeCreateParamsDto request) =>
      _operations.createWorktree(request);
  @override
  Future<WorktreeArchivePreviewDto> previewArchive(String worktreeId) =>
      _operations.previewArchive(worktreeId);
  @override
  Future<WorktreeResultDto> archive(String worktreeId, {required bool force}) =>
      _operations.archive(worktreeId, force: force);
}

/// Longest chain of derived `-2`, `-3`, ... candidates before giving up.
const int _maxDerivedBranchSuffix = 200;

String _normalizeBranch(String input) {
  final slug = input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9._-]+'), '-')
      .replaceAll(RegExp('-+'), '-')
      .replaceAll(RegExp(r'^[-/.]+|[-/.]+$'), '');
  if (slug.isEmpty || slug.contains('..') || slug.endsWith('.lock')) {
    throw WorktreeFailure(
      WorktreeFailureReason.invalidBranchName,
      'The branch name "$input" cannot be used as a Git ref.',
      details: <String, dynamic>{'branchName': input},
    );
  }
  return slug;
}

String _stableWorktreeId(String workspaceId, String path) => sha256
    .convert(utf8.encode('$workspaceId\u0000$path'))
    .toString()
    .substring(0, 24);
