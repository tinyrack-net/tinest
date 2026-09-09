import 'package:daemon/src/shared/infrastructure/persistence/database.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:drift/native.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

final class _FixedClock implements Clock {
  const new(this.now);

  final DateTime now;

  @override
  DateTime nowUtc() => now;
}

void main() {
  final now = DateTime.utc(2026, 8, 6);
  late TinestDatabase database;

  SessionDto session(
    String id, {
    String? parentSessionId,
    String? taskName,
    String? agentPath,
    String? rootSessionId,
    AgentLifecycle? lifecycle,
    DateTime? createdAt,
  }) => SessionDto(
    id: id,
    worktreeId: 'worktree',
    title: id,
    agentDefinitionId: 'tinest',
    origin: parentSessionId == null
        ? SessionOrigin.manual
        : SessionOrigin.delegated,
    status: SessionStatus.idle,
    parentSessionId: parentSessionId,
    taskName: taskName,
    agentPath: agentPath,
    rootSessionId: rootSessionId,
    lifecycle: lifecycle,
    model: const ModelSelectionDto(modelId: 'local-test/test-model'),
    createdAt: createdAt ?? now,
    updatedAt: createdAt ?? now,
  );

  setUp(() async {
    database = TinestDatabase.forTesting(
      NativeDatabase.memory(),
      clock: _FixedClock(now),
    );
    await database.workspaceDao.register(
      WorkspaceDto(
        id: 'workspace',
        name: 'Workspace',
        rootPath: '/workspace',
        kind: WorkspaceKind.directory,
        createdAt: now,
      ),
    );
    await database.worktreeDao.upsert(
      WorktreeDto(
        id: 'worktree',
        workspaceId: 'workspace',
        name: 'Workspace',
        path: '/workspace',
        kind: WorktreeKind.directory,
        isTinestOwned: false,
        createdAt: now,
      ),
    );
  });

  tearDown(() => database.close());

  test('sessions persist and expose collaboration identity fields', () async {
    await database.sessionDao.create(session('root'));
    await database.sessionDao.create(
      session(
        'child',
        parentSessionId: 'root',
        taskName: 'explore_auth',
        agentPath: '/root/explore_auth',
        rootSessionId: 'root',
        lifecycle: AgentLifecycle.pendingInit,
      ),
    );

    final child = (await database.sessionDao.getById('child'))!;
    expect(child.taskName, 'explore_auth');
    expect(child.agentPath, '/root/explore_auth');
    expect(child.rootSessionId, 'root');
    expect(child.lifecycle, AgentLifecycle.pendingInit);

    final root = (await database.sessionDao.getById('root'))!;
    expect(root.taskName, isNull);
    expect(root.agentPath, isNull);
    expect(root.rootSessionId, isNull);
    expect(root.lifecycle, isNull);
  });

  test('listByRoot returns the tree ordered by agent path', () async {
    await database.sessionDao.create(session('other'));
    await database.sessionDao.create(session('root'));
    await database.sessionDao.create(
      session(
        'child-b',
        parentSessionId: 'root',
        taskName: 'task_b',
        agentPath: '/root/task_b',
        rootSessionId: 'root',
      ),
    );
    await database.sessionDao.create(
      session(
        'grandchild',
        parentSessionId: 'child-b',
        taskName: 'task_1',
        agentPath: '/root/task_b/task_1',
        rootSessionId: 'root',
      ),
    );
    await database.sessionDao.create(
      session(
        'child-a',
        parentSessionId: 'root',
        taskName: 'task_a',
        agentPath: '/root/task_a',
        rootSessionId: 'root',
      ),
    );

    final tree = await database.sessionDao.listByRoot('root');
    expect(tree.map((entry) => entry.id), <String>[
      'root',
      'child-a',
      'child-b',
      'grandchild',
    ]);
  });

  test('getByAgentPath resolves members and the implicit /root', () async {
    await database.sessionDao.create(session('root'));
    await database.sessionDao.create(
      session(
        'child',
        parentSessionId: 'root',
        taskName: 'task_a',
        agentPath: '/root/task_a',
        rootSessionId: 'root',
      ),
    );

    final root = await database.sessionDao.getByAgentPath('root', '/root');
    expect(root?.id, 'root');
    final child = await database.sessionDao.getByAgentPath(
      'root',
      '/root/task_a',
    );
    expect(child?.id, 'child');
    expect(
      await database.sessionDao.getByAgentPath('root', '/root/missing'),
      isNull,
    );
  });

  test('lifecycle transitions persist through updateLifecycle', () async {
    await database.sessionDao.create(session('root'));
    await database.sessionDao.create(
      session(
        'child',
        parentSessionId: 'root',
        taskName: 'task_a',
        agentPath: '/root/task_a',
        rootSessionId: 'root',
        lifecycle: AgentLifecycle.pendingInit,
      ),
    );

    for (final lifecycle in AgentLifecycle.values) {
      final updated = await database.sessionDao.updateLifecycle(
        'child',
        lifecycle,
      );
      expect(updated.lifecycle, lifecycle);
    }
  });

  test('mailbox queues, drains oldest-first, and marks delivery', () async {
    await database.sessionDao.create(session('root'));

    AgentMailboxMessageDto mail(String id, DateTime createdAt) =>
        AgentMailboxMessageDto(
          id: id,
          sessionId: 'root',
          senderPath: '/root/task_a',
          recipientPath: '/root',
          type: InterAgentMessageType.message,
          payload: 'payload $id',
          createdAt: createdAt,
          senderSessionId: 'child',
        );

    await database.agentMailboxDao.enqueue(
      mail('m2', now.add(const Duration(seconds: 1))),
      triggerTurn: false,
    );
    await database.agentMailboxDao.enqueue(mail('m1', now), triggerTurn: true);

    expect(await database.agentMailboxDao.hasUndeliveredTrigger('root'), true);
    expect(
      await database.agentMailboxDao.hasUndeliveredTrigger('missing'),
      false,
    );

    final queued = await database.agentMailboxDao.undeliveredFor('root');
    expect(queued.map((entry) => entry.message.id), <String>['m1', 'm2']);
    expect(queued.first.triggerTurn, isTrue);
    expect(queued.last.triggerTurn, isFalse);
    expect(queued.first.message.type, InterAgentMessageType.message);
    expect(queued.first.message.payload, 'payload m1');

    await database.agentMailboxDao.markDelivered(<String>['m1'], now);
    final remaining = await database.agentMailboxDao.undeliveredFor('root');
    expect(remaining.map((entry) => entry.message.id), <String>['m2']);
    expect(await database.agentMailboxDao.hasUndeliveredTrigger('root'), false);

    await database.agentMailboxDao.markDelivered(const <String>[], now);
    expect((await database.agentMailboxDao.undeliveredFor('root')).length, 1);
  });

  test('countActive ignores idle and failed sessions', () async {
    await database.sessionDao.create(session('root'));
    await database.sessionDao.updateStatus('root', SessionStatus.running);
    expect(await database.sessionDao.countActive('worktree'), 1);
    await database.sessionDao.updateStatus('root', SessionStatus.idle);
    expect(await database.sessionDao.countActive('worktree'), 0);
  });
}
