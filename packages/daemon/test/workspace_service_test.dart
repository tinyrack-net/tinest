import 'dart:async';

import 'package:daemon/src/features/workspaces/infrastructure/git_workspace.dart';
import 'package:daemon/src/features/workspaces/infrastructure/project_settings.dart';
import 'package:daemon/src/features/workspaces/infrastructure/workspace_service.dart';
import 'package:daemon/src/shared/infrastructure/persistence/database.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'support/fake_file_index_gateway.dart';

/// Builds a service over an in-memory database with the standard fakes.
WorkspaceOperations _service(
  TinestDatabase database, {
  required GitWorkspaceGateway git,
}) => WorkspaceOperations(
  database.workspaceDao,
  database.worktreeDao,
  database.sessionDao,
  _FakeWorkspacePaths(),
  git,
  _FixedClock(),
  '/state/worktrees',
  FakeFileIndexGateway(),
);

void main() {
  test('parses git worktree porcelain without shell-dependent output', () {
    final worktrees = parseGitWorktreePorcelain('''
worktree /repo
HEAD abc123
branch refs/heads/main

worktree /repo-feature
HEAD def456
branch refs/heads/feature/settings

''');

    expect(worktrees, hasLength(2));
    expect(worktrees.first.path, '/repo');
    expect(worktrees.first.branch, 'main');
    expect(worktrees.last.branch, 'feature/settings');
  });

  test(
    'registers repository checkouts and creates a managed worktree',
    () async {
      final database = TinestDatabase.forTesting(
        NativeDatabase.memory(),
        clock: _FixedClock(),
      );
      addTearDown(database.close);
      final git = _FakeGitGateway();
      final service = WorkspaceOperations(
        database.workspaceDao,
        database.worktreeDao,
        database.sessionDao,
        _FakeWorkspacePaths(),
        git,
        _FixedClock(),
        '/state/worktrees',
        FakeFileIndexGateway(),
      );

      final registered = await service.register(
        const WorkspaceRegisterParamsDto(
          workspaceId: 'repo-1',
          checkoutId: 'checkout-1',
          rootPath: '/repo',
          name: 'Repository',
        ),
      );
      expect(registered.workspace.kind, WorkspaceKind.git);
      expect(registered.worktrees.map((item) => item.kind), <WorktreeKind>[
        WorktreeKind.checkout,
        WorktreeKind.linked,
      ]);
      // A checkout Git already had is linked like any other, and says it is
      // not Tinest's to remove through the field rather than a second kind.
      expect(registered.worktrees.last.isTinestOwned, isFalse);

      final managed = await service.createWorktree(
        const WorktreeCreateParamsDto(
          id: 'managed-1',
          workspaceId: 'repo-1',
          mode: WorktreeCreateMode.newBranch,
          branchName: 'Feature/User Settings',
          baseBranch: 'main',
        ),
      );
      expect(managed.worktree.kind, WorktreeKind.linked);
      expect(managed.worktree.isTinestOwned, isTrue);
      // The configured root is preserved verbatim and the branch names the
      // leaf; only the separator between them follows the host.
      expect(managed.worktree.path, startsWith('/state/worktrees'));
      expect(managed.worktree.path, endsWith('feature-user-settings'));
      expect(managed.hookRuns, isEmpty);
      expect(git.created.single.branchName, 'feature-user-settings');
    },
    tags: const <String>[
      'feature_test__workspace_catalog__unit',
      'feature_test__workspace_registration__unit',
      'feature_test__worktree_lifecycle__unit',
    ],
  );

  test(
    'a managed worktree keeps one identity when Git resolves its real path',
    () async {
      final database = TinestDatabase.forTesting(
        NativeDatabase.memory(),
        clock: _FixedClock(),
      );
      addTearDown(database.close);
      // The managed root is reachable under two spellings, as it is through a
      // Windows short name or a symlinked parent. Git always answers with the
      // resolved one.
      final paths = _FakeWorkspacePaths()
        ..canonicalPrefixes['/state/worktrees'] = '/real/worktrees';
      final git = _FakeGitGateway()
        ..reportedPrefixes['/state/worktrees'] = '/real/worktrees';
      final service = WorkspaceOperations(
        database.workspaceDao,
        database.worktreeDao,
        database.sessionDao,
        paths,
        git,
        _FixedClock(),
        '/state/worktrees',
        FakeFileIndexGateway(),
      );

      await service.register(
        const WorkspaceRegisterParamsDto(
          workspaceId: 'repo-1',
          checkoutId: 'checkout-1',
          rootPath: '/repo',
          name: 'Repository',
        ),
      );
      // `topic` is already a local branch here, and `git worktree add -b` on a
      // name Git already holds fails, so this asks for a free one.
      final managed = await service.createWorktree(
        const WorktreeCreateParamsDto(
          id: 'managed-1',
          workspaceId: 'repo-1',
          mode: WorktreeCreateMode.newBranch,
          branchName: 'resolved-path',
          baseBranch: 'main',
        ),
      );
      expect(p.isWithin('/real/worktrees', managed.worktree.path), isTrue);

      // Re-reading the catalog re-reads Git, which is where a second spelling
      // used to archive the managed row and rediscover it as an external one.
      final catalog = await service.catalog();
      final owned = catalog.worktrees
          .where((worktree) => worktree.branch == 'resolved-path')
          .toList(growable: false);
      expect(owned.map((worktree) => worktree.id), <String>['managed-1']);
      expect(owned.single.kind, WorktreeKind.linked);
      expect(owned.single.isTinestOwned, isTrue);
      expect(owned.single.head, 'created-head');
    },
    tags: const <String>['feature_test__worktree_lifecycle__unit'],
  );

  test(
    'catalog archives Git worktrees that disappeared outside Tinest',
    () async {
      final database = TinestDatabase.forTesting(
        NativeDatabase.memory(),
        clock: _FixedClock(),
      );
      addTearDown(database.close);
      final git = _FakeGitGateway();
      final service = _service(database, git: git);

      final registered = await service.register(
        const WorkspaceRegisterParamsDto(
          workspaceId: 'repo-1',
          checkoutId: 'checkout-1',
          rootPath: '/repo',
          name: 'Repository',
        ),
      );
      final external = registered.worktrees.singleWhere(
        (worktree) => worktree.path == '/other',
      );
      git.snapshots.removeWhere((snapshot) => snapshot.path == '/other');

      final catalog = await service.catalog();

      expect(
        catalog.worktrees.map((worktree) => worktree.id),
        isNot(contains(external.id)),
      );
      expect(
        (await database.worktreeDao.getById(external.id))!.archivedAt?.toUtc(),
        _FixedClock.now,
      );

      git.snapshots.add(
        const GitWorktreeSnapshot(
          path: '/other',
          branch: 'other',
          head: 'restored',
        ),
      );
      final restored = await service.catalog();
      expect(
        restored.worktrees
            .singleWhere((worktree) => worktree.path == '/other')
            .id,
        external.id,
      );
      expect(
        (await database.worktreeDao.getById(external.id))!.archivedAt,
        isNull,
      );
    },
    tags: const <String>['feature_test__workspace_catalog__unit'],
  );

  test(
    'catalog polling does not steal the identity of a managed worktree '
    'being created',
    () async {
      final database = TinestDatabase.forTesting(
        NativeDatabase.memory(),
        clock: _FixedClock(),
      );
      addTearDown(database.close);
      final git = _FakeGitGateway();
      final service = _service(database, git: git);
      await service.register(
        const WorkspaceRegisterParamsDto(
          workspaceId: 'repo-1',
          checkoutId: 'checkout-1',
          rootPath: '/repo',
          name: 'Repository',
        ),
      );
      final createdInGit = Completer<void>();
      final releaseCreation = Completer<void>();
      git
        ..createdInGit = createdInGit
        ..releaseCreation = releaseCreation.future;

      final creating = service.createWorktree(
        const WorktreeCreateParamsDto(
          id: 'managed-1',
          workspaceId: 'repo-1',
          mode: WorktreeCreateMode.newBranch,
          branchName: 'feature-race',
          baseBranch: 'main',
        ),
      );
      await createdInGit.future;
      await service.catalog();
      releaseCreation.complete();
      final created = await creating;
      final catalog = await service.catalog();

      final matching = catalog.worktrees
          .where((worktree) => worktree.path == created.worktree.path)
          .toList(growable: false);
      expect(matching, hasLength(1));
      expect(matching.single.id, 'managed-1');
      expect(matching.single.kind, WorktreeKind.linked);
    },
    tags: const <String>[
      'feature_test__workspace_catalog__unit',
      'feature_test__worktree_lifecycle__unit',
    ],
  );

  test(
    'catalog preserves a managed identity across path separators',
    () async {
      final database = TinestDatabase.forTesting(
        NativeDatabase.memory(),
        clock: _FixedClock(),
      );
      addTearDown(database.close);
      final git = _FakeGitGateway();
      final service = _service(database, git: git);
      await service.register(
        const WorkspaceRegisterParamsDto(
          workspaceId: 'repo-1',
          checkoutId: 'checkout-1',
          rootPath: '/repo',
          name: 'Repository',
        ),
      );

      final created = await service.createWorktree(
        const WorktreeCreateParamsDto(
          id: 'managed-equivalent-path',
          workspaceId: 'repo-1',
          mode: WorktreeCreateMode.newBranch,
          branchName: 'feature-equivalent-path',
          baseBranch: 'main',
        ),
      );
      final createdPath = created.worktree.path;
      final snapshotIndex = git.snapshots.indexWhere(
        (snapshot) => snapshot.path == createdPath,
      );
      final alternatePath = createdPath.contains(r'\')
          ? createdPath.replaceAll(r'\', '/')
          : createdPath.replaceAll('/', r'\');
      git.snapshots[snapshotIndex] = GitWorktreeSnapshot(
        path: alternatePath,
        branch: 'feature-equivalent-path',
        head: 'created-head',
      );

      final catalog = await service.catalog();
      final matching = catalog.worktrees
          .where((worktree) => worktree.branch == 'feature-equivalent-path')
          .toList(growable: false);
      expect(matching, hasLength(1));
      expect(matching.single.id, 'managed-equivalent-path');
      expect(matching.single.kind, WorktreeKind.linked);
    },
    tags: const <String>[
      'feature_test__workspace_catalog__unit',
      'feature_test__worktree_lifecycle__unit',
    ],
  );

  test('catalog does not archive unavailable directory workspaces', () async {
    final database = TinestDatabase.forTesting(
      NativeDatabase.memory(),
      clock: _FixedClock(),
    );
    addTearDown(database.close);
    final git = _FakeGitGateway()..root = null;
    final service = _service(database, git: git);
    final registered = await service.register(
      const WorkspaceRegisterParamsDto(
        workspaceId: 'directory-1',
        checkoutId: 'directory-checkout',
        rootPath: '/plain',
        name: 'Plain folder',
      ),
    );

    final catalog = await service.catalog();

    expect(catalog.worktrees, <WorktreeDto>[registered.worktrees.single]);
  }, tags: const <String>['feature_test__workspace_catalog__unit']);

  test(
    'archive requires confirmation and only removes managed paths',
    () async {
      final database = TinestDatabase.forTesting(
        NativeDatabase.memory(),
        clock: _FixedClock(),
      );
      addTearDown(database.close);
      final git = _FakeGitGateway()
        ..state = const GitWorktreeState(dirty: true);
      final service = WorkspaceOperations(
        database.workspaceDao,
        database.worktreeDao,
        database.sessionDao,
        _FakeWorkspacePaths(),
        git,
        _FixedClock(),
        '/state/worktrees',
        FakeFileIndexGateway(),
      );
      await service.register(
        const WorkspaceRegisterParamsDto(
          workspaceId: 'repo-1',
          checkoutId: 'checkout-1',
          rootPath: '/repo',
          name: 'Repository',
        ),
      );
      await service.createWorktree(
        const WorktreeCreateParamsDto(
          id: 'managed-1',
          workspaceId: 'repo-1',
          mode: WorktreeCreateMode.existingBranch,
          branchName: 'topic',
        ),
      );

      final preview = await service.previewArchive('managed-1');
      expect(preview.dirty, isTrue);
      expect(preview.removesDirectory, isTrue);
      await expectLater(
        service.archive('managed-1', force: false),
        throwsA(_failsWith(WorktreeFailureReason.archiveBlocked)),
      );
      final archived = await service.archive('managed-1', force: true);
      expect(archived.worktree.archivedAt?.toUtc(), _FixedClock.now);
      expect(git.removed, hasLength(1));
    },
  );

  test(
    'the project checkout cannot be archived but extra worktrees can',
    () async {
      final database = TinestDatabase.forTesting(
        NativeDatabase.memory(),
        clock: _FixedClock(),
      );
      addTearDown(database.close);
      final git = _FakeGitGateway();
      final service = _service(database, git: git);
      final registered = await service.register(
        const WorkspaceRegisterParamsDto(
          workspaceId: 'repo-1',
          checkoutId: 'checkout-1',
          rootPath: '/repo',
          name: 'Repository',
        ),
      );

      // The repository checkout is not Tinest-owned, so archiving it would keep
      // the directory and let the next refresh rediscover it under a new id.
      await expectLater(
        service.archive('checkout-1', force: true),
        throwsA(_failsWith(WorktreeFailureReason.archiveBlocked)),
      );
      expect(git.removed, isEmpty);
      expect(
        (await service.catalog()).worktrees.map((item) => item.id),
        contains('checkout-1'),
      );

      final external = registered.worktrees.last;
      expect(external.kind, WorktreeKind.linked);
      expect(external.isTinestOwned, isFalse);
      final branchesBeforeArchive = Set<String>.of(git.localBranches);
      expect(
        (await service.previewArchive(external.id)).removesDirectory,
        isTrue,
      );
      final archived = await service.archive(external.id, force: false);
      expect(archived.worktree.archivedAt?.toUtc(), _FixedClock.now);
      expect(git.removed, <String>[external.path]);
      expect(git.localBranches, branchesBeforeArchive);
      expect(
        (await service.catalog()).worktrees.map((item) => item.id),
        isNot(contains(external.id)),
      );
    },
    tags: const <String>['feature_test__worktree_lifecycle__unit'],
  );

  test(
    'a failed external worktree removal leaves its catalog record active',
    () async {
      final database = TinestDatabase.forTesting(
        NativeDatabase.memory(),
        clock: _FixedClock(),
      );
      addTearDown(database.close);
      final git = _FakeGitGateway()
        ..removeFailure = const GitCommandException(
          arguments: <String>['worktree', 'remove', '/other'],
          workingDirectory: '/repo',
          exitCode: 128,
          stderr: 'fatal: removal failed',
        );
      final service = _service(database, git: git);
      final registered = await service.register(
        const WorkspaceRegisterParamsDto(
          workspaceId: 'repo-1',
          checkoutId: 'checkout-1',
          rootPath: '/repo',
          name: 'Repository',
        ),
      );
      final external = registered.worktrees.last;

      await expectLater(
        service.archive(external.id, force: false),
        throwsA(_failsWith(WorktreeFailureReason.gitFailed)),
      );

      expect(git.removed, isEmpty);
      expect(
        (await database.worktreeDao.getById(external.id))!.archivedAt,
        isNull,
      );
      expect(
        (await service.catalog()).worktrees.map((item) => item.id),
        contains(external.id),
      );
    },
    tags: const <String>['feature_test__worktree_lifecycle__unit'],
  );

  test(
    'supports directory lifecycle and rejects Git-only operations',
    () async {
      final database = TinestDatabase.forTesting(
        NativeDatabase.memory(),
        clock: _FixedClock(),
      );
      addTearDown(database.close);
      final git = _FakeGitGateway()..root = null;
      final paths = _FakeWorkspacePaths();
      final service = WorkspaceOperations(
        database.workspaceDao,
        database.worktreeDao,
        database.sessionDao,
        paths,
        git,
        _FixedClock(),
        '/state/worktrees',
        FakeFileIndexGateway(),
      );

      final registered = await service.register(
        const WorkspaceRegisterParamsDto(
          workspaceId: 'directory-1',
          checkoutId: 'directory-checkout',
          rootPath: '/plain',
          name: 'Plain folder',
        ),
      );
      expect(registered.workspace.kind, WorkspaceKind.directory);
      expect(registered.worktrees.single.kind, WorktreeKind.directory);
      expect((await service.catalog()).workspaces, hasLength(1));
      expect((await service.refresh('directory-1')).worktrees, hasLength(1));
      expect(await service.suggestDirectories('/pl', 4), hasLength(1));
      expect(paths.lastSuggestion, (query: '/pl', limit: 4));
      await expectLater(
        service.listBranches('directory-1'),
        throwsA(_failsWith(WorktreeFailureReason.workspaceNotGit)),
      );
      await expectLater(
        service.createWorktree(
          const WorktreeCreateParamsDto(
            id: 'not-allowed',
            workspaceId: 'directory-1',
            mode: WorktreeCreateMode.newBranch,
            branchName: 'topic',
          ),
        ),
        throwsA(_failsWith(WorktreeFailureReason.workspaceNotGit)),
      );
      final preview = await service.previewArchive('directory-checkout');
      expect(preview.dirty, isFalse);
      expect(preview.removesDirectory, isFalse);
      // The registered directory itself is the workspace root, so archiving it
      // would hide the project while leaving the registration behind.
      await expectLater(
        service.archive('directory-checkout', force: false),
        throwsA(_failsWith(WorktreeFailureReason.archiveBlocked)),
      );
      expect(git.removed, isEmpty);
      await service.unregister('directory-1');
      expect((await service.catalog()).workspaces, isEmpty);
    },
  );

  test(
    'home provisioning is idempotent and yields one directory checkout',
    () async {
      final database = TinestDatabase.forTesting(
        NativeDatabase.memory(),
        clock: _FixedClock(),
      );
      addTearDown(database.close);
      final service = _service(database, git: _FakeGitGateway()..root = null);

      final first = await service.provisionHome('/home/user');
      expect(first, isNotNull);
      expect(first!.kind, WorktreeKind.directory);
      expect(first.path, '/home/user');
      expect(first.isTinestOwned, isFalse);

      // Every boot re-provisions, so a second call must not fork a second
      // workspace or checkout.
      final second = await service.provisionHome('/home/user');
      expect(second!.id, first.id);
      final catalog = await service.catalog();
      expect(catalog.workspaces, hasLength(1));
      expect(catalog.workspaces.single.kind, WorkspaceKind.home);
      expect(catalog.worktrees, hasLength(1));
    },
    tags: const <String>['feature_test__session_home__unit'],
  );

  test('a daemon without a user home provisions no home workspace', () async {
    final database = TinestDatabase.forTesting(
      NativeDatabase.memory(),
      clock: _FixedClock(),
    );
    addTearDown(database.close);
    final service = _service(database, git: _FakeGitGateway()..root = null);

    expect(await service.provisionHome(null), isNull);
    expect((await service.catalog()).workspaces, isEmpty);
  }, tags: const <String>['feature_test__session_home__unit']);

  test(
    'a workspace already registered at the home path becomes the home one',
    () async {
      final database = TinestDatabase.forTesting(
        NativeDatabase.memory(),
        clock: _FixedClock(),
      );
      addTearDown(database.close);
      final service = _service(database, git: _FakeGitGateway()..root = null);
      await service.register(
        const WorkspaceRegisterParamsDto(
          workspaceId: 'manual-home',
          checkoutId: 'manual-home-checkout',
          rootPath: '/home/user',
          name: 'My home',
        ),
      );

      await service.provisionHome('/home/user');

      final catalog = await service.catalog();
      expect(catalog.workspaces, hasLength(1));
      expect(catalog.workspaces.single.id, 'manual-home');
      expect(catalog.workspaces.single.kind, WorkspaceKind.home);
    },
    tags: const <String>['feature_test__session_home__unit'],
  );

  test(
    'the home workspace and its checkout cannot be removed or re-registered',
    () async {
      final database = TinestDatabase.forTesting(
        NativeDatabase.memory(),
        clock: _FixedClock(),
      );
      addTearDown(database.close);
      final service = _service(database, git: _FakeGitGateway()..root = null);
      final home = (await service.provisionHome('/home/user'))!;

      await expectLater(
        service.unregister(home.workspaceId),
        throwsA(_failsWith(WorktreeFailureReason.workspaceProtected)),
      );
      await expectLater(
        service.archive(home.id, force: true),
        throwsA(_failsWith(WorktreeFailureReason.archiveBlocked)),
      );
      // Registering the home directory as a project would otherwise merge into
      // the home workspace by root path and vanish from every project list.
      await expectLater(
        service.register(
          const WorkspaceRegisterParamsDto(
            workspaceId: 'shadow',
            checkoutId: 'shadow-checkout',
            rootPath: '/home/user',
            name: 'Home again',
          ),
        ),
        throwsA(_failsWith(WorktreeFailureReason.workspaceProtected)),
      );
      expect((await service.catalog()).workspaces, hasLength(1));
    },
    tags: const <String>['feature_test__session_home__unit'],
  );

  test(
    'worktree creation is idempotent and validates branch collisions',
    () async {
      final database = TinestDatabase.forTesting(
        NativeDatabase.memory(),
        clock: _FixedClock(),
      );
      addTearDown(database.close);
      final git = _FakeGitGateway();
      final service = WorkspaceOperations(
        database.workspaceDao,
        database.worktreeDao,
        database.sessionDao,
        _FakeWorkspacePaths(),
        git,
        _FixedClock(),
        '/state/worktrees',
        FakeFileIndexGateway(),
      );
      await service.register(
        const WorkspaceRegisterParamsDto(
          workspaceId: 'repo-1',
          checkoutId: 'checkout-1',
          rootPath: '/repo',
          name: 'Repository',
        ),
      );
      final branches = await service.listBranches('repo-1');
      expect(branches, hasLength(3));
      expect(
        branches.where((branch) => branch.isRemote).single.name,
        'origin/main',
      );

      // A remote base ref is refreshed before the worktree is created.
      await service.createWorktree(
        const WorktreeCreateParamsDto(
          id: 'managed-remote',
          workspaceId: 'repo-1',
          mode: WorktreeCreateMode.newBranch,
          branchName: 'from-remote',
          baseBranch: 'origin/main',
        ),
      );
      expect(git.fetched, <String>['origin']);
      expect(git.created.single.baseBranch, 'origin/main');

      // A local base ref and an unknown remote never trigger a fetch.
      git
        ..fetched.clear()
        ..created.clear()
        ..fetchSucceeds = false;
      await service.createWorktree(
        const WorktreeCreateParamsDto(
          id: 'managed-local',
          workspaceId: 'repo-1',
          mode: WorktreeCreateMode.newBranch,
          branchName: 'from-local',
          baseBranch: 'main',
        ),
      );
      expect(git.fetched, isEmpty);

      // A failing fetch still creates the worktree from the cached ref.
      final offline = await service.createWorktree(
        const WorktreeCreateParamsDto(
          id: 'managed-offline',
          workspaceId: 'repo-1',
          mode: WorktreeCreateMode.newBranch,
          branchName: 'offline',
          baseBranch: 'origin/main',
        ),
      );
      expect(git.fetched, <String>['origin']);
      expect(offline.worktree.branch, 'offline');
      git
        ..fetched.clear()
        ..created.clear()
        ..fetchSucceeds = true;

      const request = WorktreeCreateParamsDto(
        id: 'managed-1',
        workspaceId: 'repo-1',
        mode: WorktreeCreateMode.newBranch,
        branchName: 'Topic Branch',
      );
      final created = await service.createWorktree(request);
      expect(created.worktree.head, 'created-head');
      expect(await service.createWorktree(request), created);
      await expectLater(
        service.createWorktree(
          const WorktreeCreateParamsDto(
            id: 'managed-2',
            workspaceId: 'repo-1',
            mode: WorktreeCreateMode.newBranch,
            branchName: 'Topic Branch',
          ),
        ),
        throwsA(_failsWith(WorktreeFailureReason.branchAlreadyExists)),
      );
      await expectLater(
        service.createWorktree(
          const WorktreeCreateParamsDto(
            id: 'managed-invalid',
            workspaceId: 'repo-1',
            mode: WorktreeCreateMode.newBranch,
            branchName: '../',
          ),
        ),
        throwsA(_failsWith(WorktreeFailureReason.invalidBranchName)),
      );
      await expectLater(
        service.refresh('missing'),
        throwsA(_failsWith(WorktreeFailureReason.workspaceNotFound)),
      );
      await expectLater(
        service.previewArchive('missing'),
        throwsA(_failsWith(WorktreeFailureReason.worktreeNotFound)),
      );
    },
  );

  test(
    'derived naming steps past a branch an archived worktree left behind',
    () async {
      final database = TinestDatabase.forTesting(
        NativeDatabase.memory(),
        clock: _FixedClock(),
      );
      addTearDown(database.close);
      final git = _FakeGitGateway();
      final service = WorkspaceOperations(
        database.workspaceDao,
        database.worktreeDao,
        database.sessionDao,
        _FakeWorkspacePaths(),
        git,
        _FixedClock(),
        '/state/worktrees',
        FakeFileIndexGateway(),
      );
      await service.register(
        const WorkspaceRegisterParamsDto(
          workspaceId: 'repo-1',
          checkoutId: 'checkout-1',
          rootPath: '/repo',
          name: 'Repository',
        ),
      );
      const request = WorktreeCreateParamsDto(
        id: 'managed-1',
        workspaceId: 'repo-1',
        mode: WorktreeCreateMode.newBranch,
        branchName: 'flutter',
        branchNaming: WorktreeBranchNaming.derive,
      );
      final first = await service.createWorktree(request);
      expect(first.worktree.branch, 'flutter');

      // Archiving removes the checkout and the catalog row but leaves the
      // local branch, which is exactly what the client cannot see.
      await service.archive('managed-1', force: true);
      expect(git.localBranches, contains('flutter'));
      expect(await database.worktreeDao.getByPath(first.worktree.path), isNull);

      final second = await service.createWorktree(
        request.copyWith(id: 'managed-2'),
      );
      expect(second.worktree.branch, 'flutter-2');
      expect(second.worktree.path, endsWith('flutter-2'));

      // The same request without derived naming is the failure the user hit,
      // and it now names the conflict instead of collapsing into an internal
      // error.
      await expectLater(
        service.createWorktree(
          request.copyWith(
            id: 'managed-3',
            branchNaming: WorktreeBranchNaming.exact,
          ),
        ),
        throwsA(
          _failsWith(WorktreeFailureReason.branchAlreadyExists).having(
            (error) => error.details,
            'details',
            <String, dynamic>{'branchName': 'flutter'},
          ),
        ),
      );
    },
    tags: const <String>['feature_test__worktree_lifecycle__unit'],
  );

  test(
    'two simultaneous submissions of one prompt take different branches',
    () async {
      final database = TinestDatabase.forTesting(
        NativeDatabase.memory(),
        clock: _FixedClock(),
      );
      addTearDown(database.close);
      final git = _FakeGitGateway();
      final service = WorkspaceOperations(
        database.workspaceDao,
        database.worktreeDao,
        database.sessionDao,
        _FakeWorkspacePaths(),
        git,
        _FixedClock(),
        '/state/worktrees',
        FakeFileIndexGateway(),
      );
      await service.register(
        const WorkspaceRegisterParamsDto(
          workspaceId: 'repo-1',
          checkoutId: 'checkout-1',
          rootPath: '/repo',
          name: 'Repository',
        ),
      );
      const request = WorktreeCreateParamsDto(
        id: 'managed-1',
        workspaceId: 'repo-1',
        mode: WorktreeCreateMode.newBranch,
        branchName: 'flutter',
        branchNaming: WorktreeBranchNaming.derive,
      );

      // Both resolve their name before either has a registered checkout, so
      // the reservation has to be what keeps them apart.
      final results = await Future.wait(<Future<WorktreeResultDto>>[
        service.createWorktree(request),
        service.createWorktree(request.copyWith(id: 'managed-2')),
      ]);

      expect(results.map((result) => result.worktree.branch).toSet(), <String>{
        'flutter',
        'flutter-2',
      });
      expect(
        results.map((result) => result.worktree.path).toSet(),
        hasLength(2),
      );
    },
    tags: const <String>['feature_test__worktree_lifecycle__unit'],
  );

  test(
    'a failing Git worktree command reports the command and its stderr',
    () async {
      final commands = _FakeCommandRunner(<CommandResult>[
        _result(exitCode: 128, stderr: "fatal: invalid reference: 'nope'"),
      ]);
      final gateway = ProcessGitWorkspaceGateway(commands);
      await expectLater(
        gateway.createWorktree(
          const GitWorktreeCreateRequest(
            repositoryRoot: '/repo',
            path: '/state/worktrees/hash/topic',
            mode: WorktreeCreateMode.newBranch,
            branchName: 'topic',
            baseBranch: 'nope',
          ),
        ),
        throwsA(
          isA<GitCommandException>()
              .having(
                (error) => error.commandLine,
                'commandLine',
                'git worktree add -b topic /state/worktrees/hash/topic nope',
              )
              .having(
                (error) => error.stderr,
                'stderr',
                "fatal: invalid reference: 'nope'",
              ),
        ),
      );
    },
    tags: const <String>['feature_test__worktree_lifecycle__unit'],
  );

  group(
    'searchFiles',
    tags: const <String>['feature_test__composer_file_mention__unit'],
    () {
      late TinestDatabase database;
      late FakeFileIndexGateway fileIndex;
      late WorkspaceOperations service;

      setUp(() async {
        database = TinestDatabase.forTesting(
          NativeDatabase.memory(),
          clock: _FixedClock(),
        );
        addTearDown(database.close);
        fileIndex = FakeFileIndexGateway();
        service = WorkspaceOperations(
          database.workspaceDao,
          database.worktreeDao,
          database.sessionDao,
          _FakeWorkspacePaths(),
          _FakeGitGateway(),
          _FixedClock(),
          '/state/worktrees',
          fileIndex,
        );
        await service.register(
          const WorkspaceRegisterParamsDto(
            workspaceId: 'repo-1',
            checkoutId: 'checkout-1',
            rootPath: '/repo',
            name: 'Repository',
          ),
        );
      });

      test('resolves the worktree root before searching', () async {
        fileIndex.matches['/repo'] = <FileMatchDto>[
          const FileMatchDto(
            relativePath: 'lib/app.dart',
            absolutePath: '/repo/lib/app.dart',
            name: 'app.dart',
            isDirectory: false,
          ),
        ];

        final result = await service.searchFiles(
          const FileSearchParamsDto(worktreeId: 'checkout-1', query: 'app'),
        );

        expect(fileIndex.requests.single.root, '/repo');
        expect(fileIndex.requests.single.query, 'app');
        expect(result.matches.single.relativePath, 'lib/app.dart');
      });

      test('clamps the limit into a range the index can serve', () async {
        await service.searchFiles(
          const FileSearchParamsDto(
            worktreeId: 'checkout-1',
            query: 'app',
            limit: 5000,
          ),
        );
        await service.searchFiles(
          const FileSearchParamsDto(
            worktreeId: 'checkout-1',
            query: 'app',
            limit: 0,
          ),
        );

        expect(fileIndex.requests.map((request) => request.limit), <int>[
          100,
          1,
        ]);
      });

      test('rejects a worktree the daemon does not know', () async {
        await expectLater(
          service.searchFiles(
            const FileSearchParamsDto(worktreeId: 'missing', query: 'app'),
          ),
          throwsA(isA<FormatException>()),
        );
        expect(fileIndex.requests, isEmpty);
      });
    },
  );

  test('archive refuses a worktree with a running session', () async {
    final database = TinestDatabase.forTesting(
      NativeDatabase.memory(),
      clock: _FixedClock(),
    );
    addTearDown(database.close);
    final service = WorkspaceOperations(
      database.workspaceDao,
      database.worktreeDao,
      database.sessionDao,
      _FakeWorkspacePaths(),
      _FakeGitGateway(),
      _FixedClock(),
      '/state/worktrees',
      FakeFileIndexGateway(),
    );
    await service.register(
      const WorkspaceRegisterParamsDto(
        workspaceId: 'repo-1',
        checkoutId: 'checkout-1',
        rootPath: '/repo',
        name: 'Repository',
      ),
    );
    await database.sessionDao.create(
      SessionDto(
        id: 'running-session',
        worktreeId: 'checkout-1',
        title: 'Running',
        agentDefinitionId: 'tinest',
        origin: SessionOrigin.manual,
        status: SessionStatus.running,
        model: const ModelSelectionDto(modelId: 'local-test/test-model'),
        createdAt: _FixedClock.now,
        updatedAt: _FixedClock.now,
      ),
    );

    expect((await service.previewArchive('checkout-1')).runningSessionCount, 1);
    await expectLater(
      service.archive('checkout-1', force: true),
      throwsA(_failsWith(WorktreeFailureReason.archiveBlocked)),
    );
  });

  group('worktree lifecycle hooks', () {
    late TinestDatabase database;
    late _FakeProjectSettings projectSettings;
    late _FakeHookRunner hooks;
    late _FakeGitGateway git;
    late List<String> log;
    late WorkspaceOperations service;

    setUp(() async {
      database = TinestDatabase.forTesting(
        NativeDatabase.memory(),
        clock: _FixedClock(),
      );
      addTearDown(database.close);
      log = <String>[];
      projectSettings = _FakeProjectSettings();
      hooks = _FakeHookRunner(log);
      git = _FakeGitGateway(log);
      service = WorkspaceOperations(
        database.workspaceDao,
        database.worktreeDao,
        database.sessionDao,
        _FakeWorkspacePaths(),
        git,
        _FixedClock(),
        '/state/worktrees',
        FakeFileIndexGateway(),
        projectSettings,
        hooks,
      );
      await service.register(
        const WorkspaceRegisterParamsDto(
          workspaceId: 'repo-1',
          checkoutId: 'checkout-1',
          rootPath: '/repo',
          name: 'Repository',
        ),
      );
    });

    Future<WorktreeResultDto> createManaged({String id = 'managed-1'}) =>
        service.createWorktree(
          WorktreeCreateParamsDto(
            id: id,
            workspaceId: 'repo-1',
            mode: WorktreeCreateMode.existingBranch,
            branchName: 'topic',
          ),
        );

    test(
      'reads and writes project settings through the workspace root',
      () async {
        expect(
          await service.getProjectSettings('repo-1'),
          const ProjectSettingsResultDto(
            settings: ProjectSettingsDto(),
            sourcePath: '/repo/.tinest/config.json',
          ),
        );

        const settings = ProjectSettingsDto(
          setup: <String>['npm ci'],
          teardown: <String>['docker compose down'],
        );
        expect(
          await service.saveProjectSettings(
            const ProjectSettingsSaveParamsDto(
              workspaceId: 'repo-1',
              settings: settings,
            ),
          ),
          const ProjectSettingsResultDto(
            settings: settings,
            sourcePath: '/repo/.tinest/config.json',
          ),
        );
        expect(projectSettings.saved, <ProjectSettingsDto>[settings]);
        await expectLater(
          service.getProjectSettings('missing'),
          throwsA(_failsWith(WorktreeFailureReason.workspaceNotFound)),
        );
      },
      tags: const <String>['feature_test__project_settings__unit'],
    );

    test(
      'runs setup hooks in the new checkout with worktree environment',
      () async {
        projectSettings.settings = const ProjectSettingsDto(
          setup: <String>['npm ci', 'npm run build'],
        );

        final created = await createManaged();

        expect(created.hookRuns.map((run) => run.command), <String>[
          'npm ci',
          'npm run build',
        ]);
        expect(
          created.hookRuns.every(
            (run) => run.phase == WorktreeHookPhase.setup && run.exitCode == 0,
          ),
          isTrue,
        );
        expect(hooks.invocations.first.workingDirectory, created.worktree.path);
        expect(hooks.invocations.first.environment, <String, String>{
          'CODER_PROJECT_PATH': '/repo',
          'CODER_WORKTREE_PATH': created.worktree.path,
          'CODER_BRANCH': 'topic',
        });
      },
      tags: const <String>['feature_test__worktree_lifecycle__unit'],
    );

    test(
      'removes and archives the worktree after a failing setup hook',
      () async {
        projectSettings.settings = const ProjectSettingsDto(
          setup: <String>['npm ci', 'npm run build'],
        );
        hooks.failures['npm ci'] = const CommandResult(
          exitCode: 2,
          stdout: 'partial',
          stderr: 'network down',
        );

        final created = await createManaged();

        expect(created.hookRuns, hasLength(1));
        expect(created.hookRuns.single.exitCode, 2);
        expect(created.hookRuns.single.stderr, 'network down');
        expect(created.worktree.archivedAt?.toUtc(), _FixedClock.now);
        expect(git.removed, <String>[created.worktree.path]);
        expect(
          (await service.catalog()).worktrees.map((item) => item.id),
          isNot(contains('managed-1')),
        );
        expect(log, <String>['hook:npm ci', 'git:remove:force']);
      },
      tags: const <String>['feature_test__worktree_lifecycle__unit'],
    );

    test('reports unreadable project settings as a failed hook', () async {
      projectSettings.loadFailure = const FormatException(
        'invalid_project_settings: broken',
      );

      final created = await createManaged();

      expect(created.hookRuns.single.exitCode, -1);
      expect(created.hookRuns.single.command, '/repo/.tinest/config.json');
      expect(created.hookRuns.single.stderr, contains('broken'));
      expect(hooks.invocations, isEmpty);
    });

    test('does not rerun setup hooks for an existing worktree', () async {
      projectSettings.settings = const ProjectSettingsDto(
        setup: <String>['npm ci'],
      );

      await createManaged();
      final repeated = await createManaged();

      expect(hooks.invocations, hasLength(1));
      expect(repeated.hookRuns, isEmpty);
    });

    test('runs teardown hooks before the checkout is removed', () async {
      projectSettings.settings = const ProjectSettingsDto(
        teardown: <String>['docker compose down'],
      );
      final created = await createManaged();
      log.clear();

      final archived = await service.archive('managed-1', force: true);

      expect(log, <String>['hook:docker compose down', 'git:remove:force']);
      expect(archived.hookRuns.single.phase, WorktreeHookPhase.teardown);
      expect(archived.worktree.archivedAt?.toUtc(), _FixedClock.now);
      expect(hooks.invocations.single.workingDirectory, created.worktree.path);
    }, tags: const <String>['feature_test__worktree_lifecycle__unit']);

    test('archives even when a teardown hook fails', () async {
      projectSettings.settings = const ProjectSettingsDto(
        teardown: <String>['docker compose down'],
      );
      hooks.failures['docker compose down'] = const CommandResult(
        exitCode: 1,
        stdout: '',
        stderr: 'no such service',
      );
      await createManaged();

      final archived = await service.archive('managed-1', force: true);

      expect(archived.hookRuns.single.exitCode, 1);
      expect(archived.worktree.archivedAt, isNotNull);
      expect(git.removed, hasLength(1));
    });

    test('does not run teardown hooks for a refused archive', () async {
      projectSettings.settings = const ProjectSettingsDto(
        teardown: <String>['docker compose down'],
      );
      await createManaged();
      git.state = const GitWorktreeState(dirty: true);

      await expectLater(
        service.archive('managed-1', force: false),
        throwsA(_failsWith(WorktreeFailureReason.archiveBlocked)),
      );
      expect(hooks.invocations, isEmpty);
    });
  });

  group('process Git workspace gateway', () {
    test(
      'discovers repositories, worktrees, and checkout branch state',
      () async {
        final commands = _FakeCommandRunner(<CommandResult>[
          _result(stdout: '/repo\n'),
          _result(stdout: _worktreePorcelain),
          _result(
            stdout:
                'refs/heads/main\u0000main\u0000*\u0000\n'
                'refs/heads/topic\u0000topic\u0000\u0000\n'
                'refs/remotes/origin/HEAD\u0000origin/HEAD'
                '\u0000\u0000origin/main\n'
                'refs/remotes/origin/main\u0000origin/main\u0000\u0000\n',
          ),
          _result(stdout: _worktreePorcelain),
        ]);
        final gateway = ProcessGitWorkspaceGateway(commands);

        expect(await gateway.repositoryRoot('/repo/child'), '/repo');
        final worktrees = await gateway.listWorktrees('/repo');
        expect(worktrees, hasLength(2));
        final branches = await gateway.listBranches('/repo');
        expect(branches, <GitBranchDto>[
          const GitBranchDto(name: 'main', current: true, checkedOut: true),
          const GitBranchDto(name: 'topic', current: false, checkedOut: false),
          const GitBranchDto(
            name: 'origin/main',
            current: false,
            checkedOut: false,
            isRemote: true,
            isDefault: true,
          ),
        ]);
        expect(
          commands.invocations[2].arguments,
          containsAll(<String>['refs/heads', 'refs/remotes']),
        );
        expect(commands.invocations.first.executable, 'git');
        expect(commands.invocations.first.workingDirectory, '/repo/child');
      },
    );

    test('returns null outside a repository and surfaces Git errors', () async {
      final commands = _FakeCommandRunner(<CommandResult>[
        _result(exitCode: 128, stderr: 'not a repository'),
        _result(exitCode: 1, stderr: 'broken repository'),
      ]);
      final gateway = ProcessGitWorkspaceGateway(commands);

      expect(await gateway.repositoryRoot('/plain'), isNull);
      await expectLater(
        gateway.listWorktrees('/repo'),
        throwsA(
          isA<GitCommandException>()
              .having(
                (error) => error.stderr,
                'stderr',
                contains('broken repository'),
              )
              .having((error) => error.exitCode, 'exitCode', 1)
              .having(
                (error) => error.commandLine,
                'commandLine',
                'git worktree list --porcelain',
              ),
        ),
      );
    });

    test('creates new and existing branch worktrees without a shell', () async {
      final commands = _FakeCommandRunner(<CommandResult>[
        _result(),
        _result(),
      ]);
      final gateway = ProcessGitWorkspaceGateway(commands);

      await gateway.createWorktree(
        const GitWorktreeCreateRequest(
          repositoryRoot: '/repo',
          path: '/managed/new',
          mode: WorktreeCreateMode.newBranch,
          branchName: 'feature',
          baseBranch: 'develop',
        ),
      );
      await gateway.createWorktree(
        const GitWorktreeCreateRequest(
          repositoryRoot: '/repo',
          path: '/managed/existing',
          mode: WorktreeCreateMode.existingBranch,
          branchName: 'topic',
        ),
      );

      expect(commands.invocations.first.arguments, <String>[
        'worktree',
        'add',
        '-b',
        'feature',
        '/managed/new',
        'develop',
      ]);
      expect(commands.invocations.last.arguments, <String>[
        'worktree',
        'add',
        '/managed/existing',
        'topic',
      ]);
    });

    test(
      'inspects dirty and unpushed state with and without upstream',
      () async {
        final withUpstream = ProcessGitWorkspaceGateway(
          _FakeCommandRunner(<CommandResult>[
            _result(stdout: ' M lib/main.dart\n'),
            _result(stdout: 'origin/main\n'),
            _result(stdout: '3\n'),
          ]),
        );
        expect(
          await withUpstream.inspectWorktree('/repo'),
          isA<GitWorktreeState>()
              .having((state) => state.dirty, 'dirty', isTrue)
              .having(
                (state) => state.unpushedCommitCount,
                'unpushedCommitCount',
                3,
              ),
        );

        final withoutUpstream = ProcessGitWorkspaceGateway(
          _FakeCommandRunner(<CommandResult>[
            _result(),
            _result(exitCode: 128),
          ]),
        );
        final clean = await withoutUpstream.inspectWorktree('/repo');
        expect(clean.dirty, isFalse);
        expect(clean.unpushedCommitCount, 0);
      },
    );

    test(
      'removes a worktree and validates status and count commands',
      () async {
        final commands = _FakeCommandRunner(<CommandResult>[
          _result(),
          _result(),
          _result(exitCode: 1, stderr: 'status failed'),
        ]);
        final gateway = ProcessGitWorkspaceGateway(commands);

        await gateway.removeWorktree('/repo', '/managed/topic');
        expect(commands.invocations.first.arguments, <String>[
          'worktree',
          'remove',
          '/managed/topic',
        ]);
        await gateway.removeWorktree('/repo', '/managed/topic', force: true);
        expect(commands.invocations[1].arguments, <String>[
          'worktree',
          'remove',
          '--force',
          '/managed/topic',
        ]);
        await expectLater(
          gateway.inspectWorktree('/repo'),
          throwsA(isA<GitCommandException>()),
        );
      },
    );
  });
}

const _worktreePorcelain = '''
worktree /repo
HEAD abc123
branch refs/heads/main

worktree /repo-feature
HEAD def456
branch refs/heads/feature/settings

''';

CommandResult _result({
  int exitCode = 0,
  String stdout = '',
  String stderr = '',
}) => CommandResult(exitCode: exitCode, stdout: stdout, stderr: stderr);

/// Respells [path] under [to] when it names [from] or something inside it.
String _rewritePrefix(String path, String from, String to) {
  if (p.equals(path, from)) return to;
  if (!p.isWithin(from, path)) return path;
  return p.join(to, p.relative(path, from: from));
}

final class _CommandInvocation {
  const new({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
  });

  final String executable;
  final List<String> arguments;
  final String workingDirectory;
}

final class _FakeCommandRunner implements CommandRunner {
  new(this._results);

  final List<CommandResult> _results;
  final List<_CommandInvocation> invocations = <_CommandInvocation>[];

  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
  }) async {
    invocations.add(
      _CommandInvocation(
        executable: executable,
        arguments: List<String>.unmodifiable(arguments),
        workingDirectory: workingDirectory,
      ),
    );
    return _results.removeAt(0);
  }
}

final class _FixedClock implements Clock {
  static final DateTime now = DateTime.utc(2026, 8, 3);

  @override
  DateTime nowUtc() => now;
}

final class _FakeWorkspacePaths implements WorkspacePathGateway {
  ({String query, int limit})? lastSuggestion;

  /// Directories the host resolves to a different real path.
  ///
  /// Mirrors a Windows short (8.3) name or a symlinked parent, where the path
  /// the daemon builds and the path Git reports name the same directory in two
  /// different spellings.
  final Map<String, String> canonicalPrefixes = <String, String>{};

  /// Directories created through this gateway, in call order.
  final List<String> createdDirectories = <String>[];

  @override
  String canonicalizeExistingDirectory(String path) {
    for (final entry in canonicalPrefixes.entries) {
      final resolved = _rewritePrefix(path, entry.key, entry.value);
      if (resolved != path) return resolved;
    }
    return path;
  }

  @override
  Future<void> createDirectory(String path) async {
    createdDirectories.add(path);
  }

  @override
  Future<List<DirectorySuggestionDto>> suggest(String query, int limit) async {
    lastSuggestion = (query: query, limit: limit);
    return <DirectorySuggestionDto>[
      const DirectorySuggestionDto(path: '/repo', name: 'repo'),
    ];
  }
}

/// Matches a typed workspace failure carrying [reason].
///
/// Asserting the reason rather than the exception type is what keeps the RPC
/// code stable: the transport switches on exactly this value.
TypeMatcher<WorktreeFailure> _failsWith(WorktreeFailureReason reason) =>
    isA<WorktreeFailure>().having((error) => error.reason, 'reason', reason);

final class _FakeProjectSettings implements ProjectSettingsStore {
  ProjectSettingsDto settings = const ProjectSettingsDto();
  FormatException? loadFailure;
  final List<ProjectSettingsDto> saved = <ProjectSettingsDto>[];

  @override
  String sourcePath(String rootPath) => '$rootPath/.tinest/config.json';

  @override
  Future<ProjectSettingsDto> load(String rootPath) async {
    if (loadFailure case final failure?) throw failure;
    return settings;
  }

  @override
  Future<void> save(String rootPath, ProjectSettingsDto value) async {
    saved.add(value);
    settings = value;
  }
}

final class _HookInvocation {
  const new(this.command, this.workingDirectory, this.environment);

  final String command;
  final String workingDirectory;
  final Map<String, String> environment;
}

final class _FakeHookRunner implements WorktreeHookRunner {
  new(this.log);

  final List<String> log;
  final List<_HookInvocation> invocations = <_HookInvocation>[];
  final Map<String, CommandResult> failures = <String, CommandResult>{};

  @override
  Future<CommandResult> run(
    String command, {
    required String workingDirectory,
    required Map<String, String> environment,
  }) async {
    log.add('hook:$command');
    invocations.add(_HookInvocation(command, workingDirectory, environment));
    return failures[command] ??
        const CommandResult(exitCode: 0, stdout: '', stderr: '');
  }
}

final class _FakeGitGateway implements GitWorkspaceGateway {
  new([List<String>? log]) : log = log ?? <String>[];

  /// Shared call log used to assert hook ordering against Git operations.
  final List<String> log;

  String? root = '/repo';
  GitWorktreeState state = const GitWorktreeState();
  final List<GitWorktreeCreateRequest> created = <GitWorktreeCreateRequest>[];
  final List<String> removed = <String>[];
  final List<GitWorktreeSnapshot> snapshots = <GitWorktreeSnapshot>[
    const GitWorktreeSnapshot(path: '/repo', branch: 'main', head: 'abc'),
    const GitWorktreeSnapshot(path: '/other', branch: 'other', head: 'def'),
  ];
  Completer<void>? createdInGit;
  Future<void>? releaseCreation;
  GitCommandException? removeFailure;

  @override
  Future<String?> repositoryRoot(String path) async => root;

  @override
  Future<List<GitWorktreeSnapshot>> listWorktrees(
    String repositoryRoot,
  ) async => List<GitWorktreeSnapshot>.unmodifiable(snapshots);

  /// Local branch names Git would report, including ones whose worktree was
  /// archived: archiving removes the checkout but never the branch.
  final Set<String> localBranches = <String>{'main', 'topic'};

  @override
  Future<Set<String>> localBranchNames(String repositoryRoot) async =>
      Set<String>.of(localBranches);

  @override
  Future<List<GitBranchDto>> listBranches(String repositoryRoot) async =>
      const <GitBranchDto>[
        GitBranchDto(name: 'main', current: true, checkedOut: true),
        GitBranchDto(name: 'topic', current: false, checkedOut: false),
        GitBranchDto(
          name: 'origin/main',
          current: false,
          checkedOut: false,
          isRemote: true,
          isDefault: true,
        ),
      ];

  /// Remote names reported to the service.
  List<String> remotes = <String>['origin'];

  /// Remotes fetched through this gateway, in call order.
  final List<String> fetched = <String>[];

  /// Whether the next fetch reports a network failure.
  bool fetchSucceeds = true;

  @override
  Future<List<String>> listRemotes(String repositoryRoot) async => remotes;

  @override
  Future<bool> fetchRemote(String repositoryRoot, String remote) async {
    fetched.add(remote);
    return fetchSucceeds;
  }

  /// Directories this Git reports under a different real path than requested.
  ///
  /// `git worktree list` always prints the resolved directory, so a checkout
  /// created under a short or symlinked path comes back spelled differently.
  final Map<String, String> reportedPrefixes = <String, String>{};

  @override
  Future<void> createWorktree(GitWorktreeCreateRequest request) async {
    if (request.mode == WorktreeCreateMode.newBranch &&
        !localBranches.add(request.branchName)) {
      throw GitCommandException(
        arguments: <String>['worktree', 'add', '-b', request.branchName],
        workingDirectory: request.repositoryRoot,
        exitCode: 128,
        stderr: "fatal: a branch named '${request.branchName}' already exists",
      );
    }
    created.add(request);
    var reported = request.path;
    for (final entry in reportedPrefixes.entries) {
      reported = _rewritePrefix(reported, entry.key, entry.value);
    }
    snapshots.add(
      GitWorktreeSnapshot(
        path: reported,
        branch: request.branchName,
        head: 'created-head',
      ),
    );
    createdInGit?.complete();
    if (releaseCreation case final release?) await release;
  }

  @override
  Future<GitWorktreeState> inspectWorktree(String path) async => state;

  @override
  Future<void> removeWorktree(
    String repositoryRoot,
    String path, {
    bool force = false,
  }) async {
    log.add('git:remove${force ? ':force' : ''}');
    if (removeFailure case final failure?) throw failure;
    removed.add(path);
    snapshots.removeWhere((snapshot) => snapshot.path == path);
  }
}
