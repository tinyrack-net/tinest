@Tags(<String>['feature_test__agent_collaboration__unit'])
library;

import 'dart:async';

import 'package:agent/agent.dart';
import 'package:daemon/src/features/plugins/runtime/built_in_host_primitives.dart';
import 'package:daemon/src/features/plugins/runtime/host_primitives.dart';
import 'package:daemon/src/features/sessions/infrastructure/multi_agent.dart';
import 'package:daemon/src/shared/infrastructure/persistence/database.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:daemon/src/transport/rpc/binding.dart';
import 'package:drift/native.dart';
import 'package:file/memory.dart';
import 'package:platform/testing.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

final class _FixedClock implements Clock {
  const new(this.now);

  final DateTime now;

  @override
  DateTime nowUtc() => now;
}

final class _SequentialIds implements IdGenerator {
  int _next = 0;

  @override
  String generate() => 'id-${_next++}';
}

final class _FakeRuntime implements SessionTurnPort {
  final Set<String> active = <String>{};
  final List<({String sessionId, String turnId, String prompt})> started =
      <({String sessionId, String turnId, String prompt})>[];
  final List<String> cancelled = <String>[];
  final Map<String, Completer<void>> steer = <String, Completer<void>>{};
  bool throwOnStart = false;

  @override
  Future<bool> startTurn({
    required String sessionId,
    required String turnId,
    required String prompt,
    bool internal = false,
  }) async {
    if (throwOnStart) throw StateError('Agent already has a running turn.');
    started.add((sessionId: sessionId, turnId: turnId, prompt: prompt));
    return true;
  }

  @override
  Future<void> cancelTurn(String sessionId) async => cancelled.add(sessionId);

  @override
  bool hasActiveTurn(String sessionId) => active.contains(sessionId);

  @override
  Future<void> pendingInput(String sessionId) =>
      steer.putIfAbsent(sessionId, Completer<void>.new).future;
}

const AgentDefinitionDto _tinestDefinition = AgentDefinitionDto(
  version: 5,
  id: 'tinest',
  name: 'Tinest',
  description: 'Primary agent.',
  mode: AgentMode.primary,
  model: AgentModelSelectionDto(source: AgentModelSource.session),
  driverId: 'tinest.standard/driver',
  extensionIds: <String>['tinest.collaboration'],
  toolIds: <String>['tinest.collaboration/spawn_agent'],
  pluginSettings: <String, Map<String, dynamic>>{},
  callableAgentIds: <String>['reviewer'],
  prompt: '',
  contentHash: 'hash',
  sourcePath: '/config/agents/tinest.md',
);

const AgentDefinitionDto _reviewerDefinition = AgentDefinitionDto(
  version: 5,
  id: 'reviewer',
  name: 'Reviewer',
  description: 'Reviews code.',
  mode: AgentMode.subagent,
  model: AgentModelSelectionDto(source: AgentModelSource.session),
  driverId: 'tinest.standard/driver',
  extensionIds: <String>[],
  toolIds: <String>[],
  pluginSettings: <String, Map<String, dynamic>>{},
  callableAgentIds: <String>[],
  prompt: '',
  contentHash: 'hash',
  sourcePath: '/config/agents/reviewer.md',
);

void main() {
  final now = DateTime.utc(2026, 8, 6);
  late TinestDatabase database;
  late _FakeRuntime fakeRuntime;
  late MultiAgentService service;
  late List<OutboundNotification> emitted;
  late List<(String, String)> validatedModels;

  SessionDto session(
    String id, {
    String? parentSessionId,
    String? taskName,
    String? agentPath,
    String? rootSessionId,
    AgentLifecycle? lifecycle,
    ModelSelectionDto? model,
    String agentDefinitionId = 'tinest',
    PermissionMode permissionMode = PermissionMode.ask,
    SessionStatus status = SessionStatus.idle,
  }) => SessionDto(
    id: id,
    worktreeId: 'worktree',
    title: id,
    agentDefinitionId: agentDefinitionId,
    origin: parentSessionId == null
        ? SessionOrigin.manual
        : SessionOrigin.delegated,
    status: status,
    parentSessionId: parentSessionId,
    taskName: taskName,
    agentPath: agentPath,
    rootSessionId: rootSessionId,
    lifecycle: lifecycle,
    permissionMode: permissionMode,
    model: model ?? const ModelSelectionDto(modelId: 'openai/gpt-test'),
    createdAt: now,
    updatedAt: now,
  );

  HostPrimitiveRegistry collaborationRegistry(
    SessionDto caller,
    AgentDefinitionDto definition,
  ) {
    final fileSystem = MemoryFileSystem.test()
      ..directory('/workspace').createSync(recursive: true);
    return builtInHostPrimitiveRegistry(
      BuiltInHostPrimitivePorts(
        workspaceRoot: '/workspace',
        attachments: _UnusedAttachmentPublisher(),
        attachmentReader: _UnusedAttachmentReader(),
        clock: _PrimitiveClock(now),
        questions: _UnusedQuestions(),
        processes: _UnusedProcesses(),
        skills: _EmptySkills(),
        callId: 'turn-1',
        fileSystem: fileSystem,
        platform: TestPlatform.native(operatingSystem: 'linux'),
        session: caller,
        definition: definition,
        collaboration: service,
      ),
    );
  }

  HostPrimitiveContext collaborationContext(Set<String> capabilities) =>
      HostPrimitiveContext(
        pluginId: 'tinest.collaboration',
        agentId: 'tinest',
        sessionId: 'root',
        workspaceRoot: '/workspace',
        allowedCapabilities: capabilities,
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
    fakeRuntime = _FakeRuntime();
    emitted = <OutboundNotification>[];
    validatedModels = <(String, String)>[];
    service = MultiAgentService(
      sessions: database.sessionDao,
      mailbox: database.agentMailboxDao,
      timeline: database.timelineDao,
      getDefinition: (id) async => switch (id) {
        'tinest' => _tinestDefinition,
        'reviewer' => _reviewerDefinition,
        _ => throw const FormatException('Unknown agent definition.'),
      },
      defaultModel: () async =>
          const ModelSelectionDto(modelId: 'openai/gpt-default'),
      validateModel: (modelId) async {
        validatedModels.add(('', modelId));
        if (modelId == 'missing-model') {
          throw const CollaborationException('Unknown model.');
        }
      },
      events: emitted.add,
      clock: _FixedClock(now),
      ids: _SequentialIds(),
    )..runtime = fakeRuntime;
  });

  tearDown(() => database.close());

  group('AgentPaths', () {
    test('validates task names', () {
      expect(AgentPaths.isValidTaskName('task_1'), isTrue);
      expect(AgentPaths.isValidTaskName('a'), isTrue);
      expect(AgentPaths.isValidTaskName('root'), isFalse);
      expect(AgentPaths.isValidTaskName('Task'), isFalse);
      expect(AgentPaths.isValidTaskName('1task'), isFalse);
      expect(AgentPaths.isValidTaskName(''), isFalse);
      expect(AgentPaths.isValidTaskName('has-dash'), isFalse);
      expect(AgentPaths.isValidTaskName('x' * 65), isFalse);
    });

    test('resolves relative and absolute targets', () {
      expect(AgentPaths.resolve('/root', 'task_1'), '/root/task_1');
      expect(
        AgentPaths.resolve('/root/task_1', 'task_2'),
        '/root/task_1/task_2',
      );
      expect(AgentPaths.resolve('/root', 'a/b'), '/root/a/b');
      expect(AgentPaths.resolve('/root/task_1', '/root'), '/root');
      expect(AgentPaths.resolve('/root', '/root/task_1'), '/root/task_1');
      expect(AgentPaths.resolve('/root', '/other/task_1'), isNull);
      expect(AgentPaths.resolve('/root', '/root/BAD'), isNull);
      expect(AgentPaths.resolve('/root', '..'), isNull);
      expect(AgentPaths.resolve('/root', 'root'), isNull);
    });
  });

  group('spawn', () {
    test('creates an identified child and triggers its first turn', () async {
      final root = await database.sessionDao.create(session('root'));
      final path = await service.spawn(
        caller: root,
        callerDefinition: _tinestDefinition,
        turnId: 'turn-1',
        taskName: 'review_task',
        message: 'Review the code.',
        agentType: 'reviewer',
      );
      expect(path, '/root/review_task');

      final child = (await database.sessionDao.getByAgentPath(
        'root',
        '/root/review_task',
      ))!;
      expect(child.parentSessionId, 'root');
      expect(child.rootSessionId, 'root');
      expect(child.taskName, 'review_task');
      expect(child.lifecycle, AgentLifecycle.pendingInit);
      expect(child.agentDefinitionId, 'reviewer');
      expect(child.model, root.model);
      expect(child.modelControls, root.modelControls);
      expect(child.origin, SessionOrigin.delegated);

      // NEW_TASK mail is queued for the child and its delivery turn started.
      final queued = await database.agentMailboxDao.undeliveredFor(child.id);
      expect(queued.single.message.type, InterAgentMessageType.newTask);
      expect(queued.single.message.payload, 'Review the code.');
      expect(queued.single.triggerTurn, isTrue);
      expect(fakeRuntime.started.single.sessionId, child.id);

      // The parent timeline records the spawn.
      final events = await database.timelineDao.after('root', 0);
      expect(
        events
            .where((event) => event.type == 'agent.spawned')
            .single
            .data['agentPath'],
        '/root/review_task',
      );
    });

    test('a child is pinned to the mode its caller runs under', () async {
      // A subagent pane has no permission control, so the caller's mode is the
      // only permission decision the user makes for this tree. Seeding the
      // child from the daemon default would re-park work the user had already
      // granted, with nothing to undo it with.
      final root = await database.sessionDao.create(
        session('root', permissionMode: PermissionMode.fullAccess),
      );
      await service.spawn(
        caller: root,
        callerDefinition: _tinestDefinition,
        turnId: 'turn-1',
        taskName: 'review_task',
        message: 'Review the code.',
      );
      final child = (await database.sessionDao.getByAgentPath(
        'root',
        '/root/review_task',
      ))!;
      expect(child.permissionMode, PermissionMode.fullAccess);

      // A narrowed caller hands down exactly what it holds, never more.
      final narrow = await database.sessionDao.create(
        session('narrow', permissionMode: PermissionMode.readOnly),
      );
      await service.spawn(
        caller: narrow,
        callerDefinition: _tinestDefinition,
        turnId: 'turn-2',
        taskName: 'read_task',
        message: 'Read the code.',
      );
      final narrowChild = (await database.sessionDao.getByAgentPath(
        'narrow',
        '/root/read_task',
      ))!;
      expect(narrowChild.permissionMode, PermissionMode.readOnly);
    });

    test('rejects invalid names, duplicates, and bad fork values', () async {
      final root = await database.sessionDao.create(session('root'));
      Future<String> spawn(String name, {String fork = 'none'}) =>
          service.spawn(
            caller: root,
            callerDefinition: _tinestDefinition,
            turnId: 'turn-1',
            taskName: name,
            message: 'Work.',
            forkTurns: fork,
          );

      await expectLater(
        spawn('Bad-Name'),
        throwsA(isA<CollaborationException>()),
      );
      await expectLater(
        spawn('ok', fork: 'seven'),
        throwsA(isA<CollaborationException>()),
      );
      await expectLater(
        spawn('ok', fork: '0'),
        throwsA(isA<CollaborationException>()),
      );
      await spawn('taken');
      await expectLater(
        spawn('taken'),
        throwsA(
          isA<CollaborationException>().having(
            (error) => error.message,
            'message',
            contains('already exists'),
          ),
        ),
      );
    });

    test('rejects overrides for a full-history fork', () async {
      final root = await database.sessionDao.create(session('root'));
      await expectLater(
        service.spawn(
          caller: root,
          callerDefinition: _tinestDefinition,
          turnId: 'turn-1',
          taskName: 'forked',
          message: 'Continue.',
          forkTurns: 'all',
          agentType: 'reviewer',
        ),
        throwsA(isA<CollaborationException>()),
      );
    });

    test(
      'full-history fork copies the parent model snapshot and controls',
      () async {
        final root = await database.sessionDao.create(
          session(
            'root',
            model: const ModelSelectionDto(modelId: 'openai/parent-snapshot'),
          ).copyWith(
            modelControls: const <String, ModelControlValueDto>{
              'reasoning_effort': ModelControlValueDto.stringValue(
                value: 'low',
              ),
            },
          ),
        );
        await service.spawn(
          caller: root,
          callerDefinition: _tinestDefinition,
          turnId: 'turn-1',
          taskName: 'forked',
          message: 'Continue.',
          forkTurns: 'all',
        );

        final child = (await database.sessionDao.getByAgentPath(
          'root',
          '/root/forked',
        ))!;
        expect(child.model, root.model);
        expect(child.modelControls, root.modelControls);
      },
    );

    test('persists explicit model controls on a non-full fork', () async {
      final root = await database.sessionDao.create(session('root'));
      await service.spawn(
        caller: root,
        callerDefinition: _tinestDefinition,
        turnId: 'turn-1',
        taskName: 'controlled',
        message: 'Work.',
        reasoningEffort: 'high',
        serviceTier: 'priority',
      );
      final child = (await database.sessionDao.getByAgentPath(
        'root',
        '/root/controlled',
      ))!;
      expect(child.model, const ModelSelectionDto(modelId: 'openai/gpt-test'));
      expect(child.modelControls, <String, ModelControlValueDto>{
        'reasoning_effort': const ModelControlValueDto.stringValue(
          value: 'high',
        ),
        'service_tier': const ModelControlValueDto.stringValue(
          value: 'priority',
        ),
      });
    });

    test('rejects agent types outside the caller allowlist', () async {
      final root = await database.sessionDao.create(session('root'));
      await expectLater(
        service.spawn(
          caller: root,
          callerDefinition: _tinestDefinition,
          turnId: 'turn-1',
          taskName: 'stranger_task',
          message: 'Work.',
          agentType: 'stranger',
        ),
        throwsA(
          isA<CollaborationException>().having(
            (error) => error.message,
            'message',
            contains('not allowed'),
          ),
        ),
      );
    });

    test('validates model overrides against the caller connection', () async {
      final root = await database.sessionDao.create(session('root'));
      await service.spawn(
        caller: root,
        callerDefinition: _tinestDefinition,
        turnId: 'turn-1',
        taskName: 'fast_task',
        message: 'Work.',
        agentType: 'reviewer',
        model: 'openai/gpt-cheap',
      );
      expect(validatedModels.single, ('', 'openai/gpt-cheap'));
      final child = (await database.sessionDao.getByAgentPath(
        'root',
        '/root/fast_task',
      ))!;
      expect(child.model!.modelId, 'openai/gpt-cheap');
      await expectLater(
        service.spawn(
          caller: root,
          callerDefinition: _tinestDefinition,
          turnId: 'turn-1',
          taskName: 'bad_model',
          message: 'Work.',
          model: 'missing-model',
        ),
        throwsA(isA<CollaborationException>()),
      );
    });

    test('rejects a spawn when the tree is at capacity', () async {
      final root = await database.sessionDao.create(session('root'));
      for (
        var index = 0;
        index < maxConcurrentSubagentTurnsPerTree;
        index += 1
      ) {
        service.acquireTurnSlot(
          session(
            'busy-$index',
            parentSessionId: 'root',
            taskName: 'busy_$index',
            agentPath: '/root/busy_$index',
            rootSessionId: 'root',
          ),
        );
      }
      await expectLater(
        service.spawn(
          caller: root,
          callerDefinition: _tinestDefinition,
          turnId: 'turn-1',
          taskName: 'one_too_many',
          message: 'Work.',
        ),
        throwsA(
          isA<CollaborationException>().having(
            (error) => error.message,
            'message',
            contains('Agent limit reached'),
          ),
        ),
      );
    });
  });

  group('limiter', () {
    test('caps concurrent subagent turns per tree and frees slots', () {
      final subagents = List<SessionDto>.generate(
        maxConcurrentSubagentTurnsPerTree + 1,
        (index) => session(
          'sub-$index',
          parentSessionId: 'root',
          taskName: 'task_$index',
          agentPath: '/root/task_$index',
          rootSessionId: 'root',
        ),
      );
      subagents
          .take(maxConcurrentSubagentTurnsPerTree)
          .forEach(service.acquireTurnSlot);
      expect(
        () => service.acquireTurnSlot(subagents.last),
        throwsA(isA<CollaborationException>()),
      );
      // Re-acquiring a held slot and root sessions are both free.
      service
        ..acquireTurnSlot(subagents.first)
        ..acquireTurnSlot(session('root'))
        ..releaseTurnSlot(subagents.first)
        ..acquireTurnSlot(subagents.last);
    });
  });

  group('mailbox', () {
    test('queue-only mail never starts a turn', () async {
      final root = await database.sessionDao.create(session('root'));
      final child = await database.sessionDao.create(
        session(
          'child',
          parentSessionId: 'root',
          taskName: 'task_a',
          agentPath: '/root/task_a',
          rootSessionId: 'root',
        ),
      );
      await service.sendMessage(
        caller: root,
        target: 'task_a',
        message: 'Ping.',
      );
      expect(fakeRuntime.started, isEmpty);
      final queued = await database.agentMailboxDao.undeliveredFor(child.id);
      expect(queued.single.triggerTurn, isFalse);
    });

    test('followup starts a turn on an idle target only', () async {
      final root = await database.sessionDao.create(session('root'));
      final child = await database.sessionDao.create(
        session(
          'child',
          parentSessionId: 'root',
          taskName: 'task_a',
          agentPath: '/root/task_a',
          rootSessionId: 'root',
        ),
      );
      expect(
        await service.followupTask(
          caller: root,
          target: 'task_a',
          message: 'More work.',
        ),
        isTrue,
      );
      expect(fakeRuntime.started.single.sessionId, child.id);

      fakeRuntime.active.add(child.id);
      expect(
        await service.followupTask(
          caller: root,
          target: 'task_a',
          message: 'Even more.',
        ),
        isFalse,
      );
      expect(fakeRuntime.started, hasLength(1));
    });

    test('followup rejects the tree root and unknown targets', () async {
      final root = await database.sessionDao.create(session('root'));
      final child = await database.sessionDao.create(
        session(
          'child',
          parentSessionId: 'root',
          taskName: 'task_a',
          agentPath: '/root/task_a',
          rootSessionId: 'root',
        ),
      );
      await expectLater(
        service.followupTask(
          caller: child,
          target: '/root',
          message: 'Hi parent.',
        ),
        throwsA(isA<CollaborationException>()),
      );
      await expectLater(
        service.followupTask(
          caller: root,
          target: 'missing',
          message: 'Anyone?',
        ),
        throwsA(isA<CollaborationException>()),
      );
    });

    test('drain renders envelopes once and marks delivery', () async {
      final root = await database.sessionDao.create(session('root'));
      final child = await database.sessionDao.create(
        session(
          'child',
          parentSessionId: 'root',
          taskName: 'task_a',
          agentPath: '/root/task_a',
          rootSessionId: 'root',
        ),
      );
      await service.sendMessage(
        caller: child,
        target: '/root',
        message: 'Progress update.',
      );
      final source = service.drainSourceFor(root.id);
      final drained = await source.drainPending();
      final text = (drained.single as UserConversationItem).text;
      expect(
        text,
        'Message Type: MESSAGE\n'
        'Task name: /root\n'
        'Sender: /root/task_a\n'
        'Payload:\nProgress update.',
      );
      expect(await source.drainPending(), isEmpty);
    });
  });

  group('onTurnFinished', () {
    late SessionDto root;
    late SessionDto child;

    setUp(() async {
      root = await database.sessionDao.create(session('root'));
      child = await database.sessionDao.create(
        session(
          'child',
          parentSessionId: 'root',
          taskName: 'task_a',
          agentPath: '/root/task_a',
          rootSessionId: 'root',
          lifecycle: AgentLifecycle.running,
        ),
      );
    });

    test('completion mails a FINAL_ANSWER to the parent', () async {
      await service.onTurnFinished(
        sessionId: child.id,
        outcome: TurnStatus.completed,
        finalText: 'All done.',
      );
      expect(
        (await database.sessionDao.getById(child.id))!.lifecycle,
        AgentLifecycle.completed,
      );
      final mail = await database.agentMailboxDao.undeliveredFor(root.id);
      expect(mail.single.message.type, InterAgentMessageType.finalAnswer);
      expect(mail.single.message.payload, 'All done.');
    });

    test('the last child to finish wakes an idle parent', () async {
      // Without this the parent's mailbox holds an undelivered FINAL_ANSWER
      // forever whenever its own turn ended before the child's did, and the
      // tree only resumes when the user types.
      await service.onTurnFinished(
        sessionId: child.id,
        outcome: TurnStatus.completed,
        finalText: 'All done.',
      );
      final mail = await database.agentMailboxDao.undeliveredFor(root.id);
      expect(mail.single.triggerTurn, isTrue);
      expect(fakeRuntime.started.single.sessionId, root.id);
    });

    test('a failing child also wakes an idle parent', () async {
      await service.onTurnFinished(
        sessionId: child.id,
        outcome: TurnStatus.failed,
        error: 'provider exploded',
      );
      expect(fakeRuntime.started.single.sessionId, root.id);
    });

    test('a parent mid-turn is not interrupted', () async {
      fakeRuntime.active.add(root.id);
      await service.onTurnFinished(
        sessionId: child.id,
        outcome: TurnStatus.completed,
        finalText: 'All done.',
      );
      // The running parent drains the mailbox at its next turn boundary; the
      // end of its own turn is what schedules that boundary.
      expect(fakeRuntime.started, isEmpty);
    });

    test('a parent busy at the time still gets woken later', () async {
      // The parent is mid-turn when the child finishes — the ordinary case,
      // because a parent that spawned and then waited is inside a turn. The
      // answer must stay entitled to wake it: queuing it as non-triggering
      // mail spends that entitlement, and nothing ever restores it, so the
      // tree stalls until the user types.
      fakeRuntime.active.add(root.id);
      await service.onTurnFinished(
        sessionId: child.id,
        outcome: TurnStatus.completed,
        finalText: 'All done.',
      );
      expect(fakeRuntime.started, isEmpty);
      expect(
        (await database.agentMailboxDao.undeliveredFor(root.id))
            .single
            .triggerTurn,
        isTrue,
      );

      fakeRuntime.active.remove(root.id);
      await service.onTurnFinished(
        sessionId: root.id,
        outcome: TurnStatus.completed,
        finalText: 'Parent turn over.',
      );
      expect(fakeRuntime.started.single.sessionId, root.id);
    });

    test('a parent with a sibling still running is left alone', () async {
      final sibling = await database.sessionDao.create(
        session(
          'sibling',
          parentSessionId: 'root',
          taskName: 'task_b',
          agentPath: '/root/task_b',
          rootSessionId: 'root',
          lifecycle: AgentLifecycle.running,
        ),
      );
      service.acquireTurnSlot(sibling);
      await service.onTurnFinished(
        sessionId: child.id,
        outcome: TurnStatus.completed,
        finalText: 'First one done.',
      );
      // Waking now would make the parent report on a half-finished tree; the
      // sibling's own completion wakes it instead.
      expect(fakeRuntime.started, isEmpty);
      await service.onTurnFinished(
        sessionId: sibling.id,
        outcome: TurnStatus.completed,
        finalText: 'Second one done.',
      );
      expect(fakeRuntime.started.single.sessionId, root.id);
    });

    test('a vanished session still releases its turn slot', () async {
      final ghost = session(
        'ghost',
        parentSessionId: 'root',
        taskName: 'task_ghost',
        agentPath: '/root/task_ghost',
        rootSessionId: 'root',
      );
      service.acquireTurnSlot(ghost);
      // The row is gone, so onTurnFinished returns early. Releasing the slot
      // only after that read leaks it, and four leaks wedge the whole tree.
      await service.onTurnFinished(
        sessionId: ghost.id,
        outcome: TurnStatus.completed,
        finalText: 'Never recorded.',
      );
      for (var index = 0; index < maxConcurrentSubagentTurnsPerTree; index++) {
        service.acquireTurnSlot(
          session(
            'filler-$index',
            parentSessionId: 'root',
            taskName: 'filler_$index',
            agentPath: '/root/filler_$index',
            rootSessionId: 'root',
          ),
        );
      }
    });

    test('failure mails an errored FINAL_ANSWER', () async {
      await service.onTurnFinished(
        sessionId: child.id,
        outcome: TurnStatus.failed,
        error: 'provider exploded',
      );
      expect(
        (await database.sessionDao.getById(child.id))!.lifecycle,
        AgentLifecycle.errored,
      );
      final mail = await database.agentMailboxDao.undeliveredFor(root.id);
      expect(mail.single.message.payload, 'Status: errored\nprovider exploded');
    });

    test(
      'interruption is not final: no mail, agent stays messageable',
      () async {
        await service.onTurnFinished(
          sessionId: child.id,
          outcome: TurnStatus.cancelled,
        );
        expect(
          (await database.sessionDao.getById(child.id))!.lifecycle,
          AgentLifecycle.interrupted,
        );
        expect(await database.agentMailboxDao.undeliveredFor(root.id), isEmpty);
      },
    );

    test('a finished turn delivers trigger mail queued during it', () async {
      fakeRuntime.active.add(child.id);
      await service.followupTask(
        caller: root,
        target: 'task_a',
        message: 'Queued mid-turn.',
      );
      expect(fakeRuntime.started, isEmpty);
      fakeRuntime.active.remove(child.id);
      await service.onTurnFinished(
        sessionId: child.id,
        outcome: TurnStatus.completed,
        finalText: 'First answer.',
      );
      expect(
        fakeRuntime.started.map((call) => call.sessionId),
        contains(child.id),
      );
    });

    test('a freed slot pumps a parked trigger', () async {
      final blockers = List<SessionDto>.generate(
        maxConcurrentSubagentTurnsPerTree,
        (index) => session(
          'busy-$index',
          parentSessionId: 'root',
          taskName: 'busy_$index',
          agentPath: '/root/busy_$index',
          rootSessionId: 'root',
        ),
      )..forEach(service.acquireTurnSlot);
      // The follow-up cannot start while the tree is saturated: it parks.
      await service.followupTask(
        caller: root,
        target: 'task_a',
        message: 'Wait your turn.',
      );
      expect(fakeRuntime.started, isEmpty);
      await database.sessionDao.create(blockers.first);
      await service.onTurnFinished(
        sessionId: blockers.first.id,
        outcome: TurnStatus.completed,
        finalText: 'Done.',
      );
      expect(
        fakeRuntime.started.map((call) => call.sessionId),
        contains(child.id),
      );
    });
  });

  group('waitAgent', () {
    test('returns immediately when mail is already queued', () async {
      final root = await database.sessionDao.create(session('root'));
      final child = await database.sessionDao.create(
        session(
          'child',
          parentSessionId: 'root',
          taskName: 'task_a',
          agentPath: '/root/task_a',
          rootSessionId: 'root',
        ),
      );
      await service.sendMessage(caller: child, target: '/root', message: 'x');
      final result = await service.waitAgent(
        caller: root,
        cancellation: CancellationToken(),
      );
      expect(result.outcome, WaitAgentOutcome.mail);
      expect(result.timedOut, isFalse);
    });

    test('the wait hands back the mail it woke for, once', () async {
      // Reporting only that mail exists strands the payload: the mailbox is
      // drained at turn start, so a waiter inside a turn has no other way to
      // read what it waited for.
      final root = await database.sessionDao.create(session('root'));
      final child = await database.sessionDao.create(
        session(
          'child',
          parentSessionId: 'root',
          taskName: 'task_a',
          agentPath: '/root/task_a',
          rootSessionId: 'root',
        ),
      );
      await service.onTurnFinished(
        sessionId: child.id,
        outcome: TurnStatus.completed,
        finalText: 'Found the leak in the parser.',
      );

      final result = await service.waitAgent(
        caller: root,
        cancellation: CancellationToken(),
      );

      expect(result.outcome, WaitAgentOutcome.mail);
      expect(result.messages.single.type, InterAgentMessageType.finalAnswer);
      expect(result.messages.single.senderPath, '/root/task_a');
      expect(result.messages.single.payload, 'Found the leak in the parser.');
      // Consumed by the wait: the next turn must not replay it as input.
      expect(await database.agentMailboxDao.undeliveredFor(root.id), isEmpty);
      expect(await service.drainSourceFor(root.id).drainPending(), isEmpty);
    });

    test('wakes on mail arriving mid-wait', () async {
      final root = await database.sessionDao.create(session('root'));
      final child = await database.sessionDao.create(
        session(
          'child',
          parentSessionId: 'root',
          taskName: 'task_a',
          agentPath: '/root/task_a',
          rootSessionId: 'root',
        ),
      );
      final wait = service.waitAgent(
        caller: root,
        cancellation: CancellationToken(),
        timeoutMs: maxWaitTimeoutMs,
      );
      await Future<void>.delayed(Duration.zero);
      await service.sendMessage(
        caller: child,
        target: '/root',
        message: 'Wake up.',
      );
      final result = await wait;
      expect(result.outcome, WaitAgentOutcome.mail);
      expect(result.messages.single.payload, 'Wake up.');
    });

    test('wakes on user steering input', () async {
      final root = await database.sessionDao.create(session('root'));
      final wait = service.waitAgent(
        caller: root,
        cancellation: CancellationToken(),
        timeoutMs: maxWaitTimeoutMs,
      );
      await Future<void>.delayed(Duration.zero);
      fakeRuntime.steer[root.id]?.complete();
      final result = await wait;
      expect(result.outcome, WaitAgentOutcome.steer);
      expect(result.timedOut, isFalse);
      expect(result.messages, isEmpty);
    });

    test('times out and validates the timeout range', () async {
      final root = await database.sessionDao.create(session('root'));
      final result = await service.waitAgent(
        caller: root,
        cancellation: CancellationToken(),
        timeoutMs: minWaitTimeoutMs,
      );
      expect(result.outcome, WaitAgentOutcome.timeout);
      expect(result.timedOut, isTrue);
      expect(result.messages, isEmpty);
      await expectLater(
        service.waitAgent(
          caller: root,
          cancellation: CancellationToken(),
          timeoutMs: minWaitTimeoutMs - 1,
        ),
        throwsA(isA<CollaborationException>()),
      );
      await expectLater(
        service.waitAgent(
          caller: root,
          cancellation: CancellationToken(),
          timeoutMs: maxWaitTimeoutMs + 1,
        ),
        throwsA(isA<CollaborationException>()),
      );
    });
  });

  group('interrupt and list', () {
    test(
      'interrupt cancels the target turn and reports prior status',
      () async {
        final root = await database.sessionDao.create(session('root'));
        final child = await database.sessionDao.create(
          session(
            'child',
            parentSessionId: 'root',
            taskName: 'task_a',
            agentPath: '/root/task_a',
            rootSessionId: 'root',
            lifecycle: AgentLifecycle.running,
          ),
        );
        final previous = await service.interruptAgent(
          caller: root,
          target: 'task_a',
        );
        expect(previous, AgentLifecycle.running);
        expect(fakeRuntime.cancelled.single, child.id);
        await expectLater(
          service.interruptAgent(caller: root, target: '/root'),
          throwsA(isA<CollaborationException>()),
        );
        await expectLater(
          service.interruptAgent(caller: child, target: '/root/task_a'),
          throwsA(isA<CollaborationException>()),
        );
      },
    );

    test('list returns the tree with statuses and honours a prefix', () async {
      final root = await database.sessionDao.create(session('root'));
      await database.sessionDao.create(
        session(
          'child-a',
          parentSessionId: 'root',
          taskName: 'task_a',
          agentPath: '/root/task_a',
          rootSessionId: 'root',
          lifecycle: AgentLifecycle.running,
        ),
      );
      await database.sessionDao.create(
        session(
          'grandchild',
          parentSessionId: 'child-a',
          taskName: 'task_b',
          agentPath: '/root/task_a/task_b',
          rootSessionId: 'root',
          lifecycle: AgentLifecycle.running,
          status: SessionStatus.waitingForApproval,
        ),
      );
      final all = await service.listAgents(caller: root);
      expect(all.map((agent) => agent.agentName), <String>[
        '/root',
        '/root/task_a',
        '/root/task_a/task_b',
      ]);
      expect(all.first.agentStatus, AgentLifecycle.completed);
      expect(all[1].agentStatus, AgentLifecycle.running);
      final scoped = await service.listAgents(
        caller: root,
        pathPrefix: '/root/task_a',
      );
      expect(scoped.map((agent) => agent.agentName), <String>[
        '/root/task_a',
        '/root/task_a/task_b',
      ]);
    });

    test('list carries the identity needed to address an agent', () async {
      final root = await database.sessionDao.create(session('root'));
      await database.sessionDao.create(
        session(
          'child-a',
          parentSessionId: 'root',
          taskName: 'task_a',
          agentPath: '/root/task_a',
          rootSessionId: 'root',
          lifecycle: AgentLifecycle.running,
        ),
      );
      // A subagent parked on an approval keeps the `running` lifecycle, so the
      // lifecycle alone cannot tell a working agent from one only the user can
      // release. The session status is what carries that difference.
      await database.sessionDao.create(
        session(
          'grandchild',
          parentSessionId: 'child-a',
          taskName: 'task_b',
          agentPath: '/root/task_a/task_b',
          rootSessionId: 'root',
          lifecycle: AgentLifecycle.running,
          status: SessionStatus.waitingForApproval,
        ),
      );

      final agents = await service.listAgents(caller: root);

      expect(agents.map((agent) => agent.sessionId), <String>[
        'root',
        'child-a',
        'grandchild',
      ]);
      expect(agents.map((agent) => agent.parentSessionId), <String?>[
        null,
        'root',
        'child-a',
      ]);
      expect(agents.map((agent) => agent.taskName), <String?>[
        null,
        'task_a',
        'task_b',
      ]);
      // The tree root is the session the caller already sits in, so its title
      // is the only label it ever has.
      expect(agents.map((agent) => agent.title), <String>[
        'root',
        'child-a',
        'grandchild',
      ]);
      expect(agents.map((agent) => agent.sessionStatus), <SessionStatus>[
        SessionStatus.idle,
        SessionStatus.idle,
        SessionStatus.waitingForApproval,
      ]);
    });
  });

  group('fork seeding', () {
    Future<SessionDto> spawnFork(String fork) async {
      final root = await database.sessionDao.create(session('root'));
      await database.timelineDao.appendProviderItems(
        root.id,
        const <ConversationItem>[
          UserConversationItem('First prompt'),
          AssistantConversationItem(
            text: 'First answer',
            toolCalls: <ConversationToolCall>[
              ConversationToolCall.function(
                callId: 'call',
                name: 'read_file',
                arguments: <String, dynamic>{'path': 'a'},
              ),
            ],
            opaqueItems: <Map<String, dynamic>>[
              <String, dynamic>{'type': 'reasoning', 'encrypted': 'secret'},
            ],
          ),
          ToolResultConversationItem(
            callId: 'call',
            output: 'contents',
            toolKind: ModelToolKind.function,
          ),
          UserConversationItem('Second prompt'),
          AssistantConversationItem(text: ''),
          AssistantConversationItem(text: 'Second answer'),
        ],
      );
      final path = await service.spawn(
        caller: root,
        callerDefinition: _tinestDefinition,
        turnId: 'turn-1',
        taskName: 'fork_task',
        message: 'Continue.',
        forkTurns: fork,
      );
      return (await database.sessionDao.getByAgentPath('root', path))!;
    }

    test('a full fork keeps prompts and answers, drops tool state', () async {
      final child = await spawnFork('all');
      final history = await database.timelineDao.providerHistory(child.id);
      expect(history.map((item) => item.runtimeType.toString()), <String>[
        'UserConversationItem',
        'AssistantConversationItem',
        'UserConversationItem',
        'AssistantConversationItem',
      ]);
      final assistant = history[1] as AssistantConversationItem;
      expect(assistant.text, 'First answer');
      expect(assistant.toolCalls, isEmpty);
      expect(assistant.opaqueItems, isEmpty);
    });

    test('a numbered fork keeps only the trailing turns', () async {
      final child = await spawnFork('1');
      final history = await database.timelineDao.providerHistory(child.id);
      expect((history.first as UserConversationItem).text, 'Second prompt');
      expect(history, hasLength(2));
    });

    test('fork none seeds nothing', () async {
      final child = await spawnFork('none');
      expect(await database.timelineDao.providerHistory(child.id), isEmpty);
    });
  });

  group('host collaboration primitives', () {
    test('descriptors expose safety metadata without model tool data', () {
      final registry = collaborationRegistry(
        session('root'),
        _tinestDefinition,
      );
      expect(
        registry.descriptors
            .where(
              (descriptor) =>
                  descriptor.operation.startsWith('host.collaboration.'),
            )
            .map((descriptor) => descriptor.toJson()),
        <Map<String, Object?>>[
          <String, Object?>{
            'operation': 'host.collaboration.followup_task',
            'capability': 'collaboration.message',
            'effect': 'read',
            'luaInputType': 'tinest.CollaborationMessageInput',
            'luaOutputType': 'tinest.CollaborationFollowupOutput',
          },
          <String, Object?>{
            'operation': 'host.collaboration.interrupt_agent',
            'capability': 'collaboration.interrupt',
            'effect': 'read',
            'luaInputType': 'tinest.CollaborationTargetInput',
            'luaOutputType': 'tinest.CollaborationInterruptOutput',
          },
          <String, Object?>{
            'operation': 'host.collaboration.list_agents',
            'capability': 'collaboration.list',
            'effect': 'read',
            'luaInputType': 'tinest.CollaborationListInput',
            'luaOutputType': 'tinest.CollaborationListOutput',
          },
          <String, Object?>{
            'operation': 'host.collaboration.send_message',
            'capability': 'collaboration.message',
            'effect': 'read',
            'luaInputType': 'tinest.CollaborationMessageInput',
            'luaOutputType': 'tinest.CollaborationQueuedOutput',
          },
          <String, Object?>{
            'operation': 'host.collaboration.spawn_agent',
            'capability': 'collaboration.spawn',
            'effect': 'read',
            'luaInputType': 'tinest.CollaborationSpawnInput',
            'luaOutputType': 'tinest.CollaborationSpawnOutput',
          },
          <String, Object?>{
            'operation': 'host.collaboration.wait_agent',
            'capability': 'collaboration.wait',
            'effect': 'read',
            'luaInputType': 'tinest.CollaborationWaitInput',
            'luaOutputType': 'tinest.CollaborationWaitOutput',
          },
        ],
      );
    });

    test('capability and service failures use structured envelopes', () async {
      final root = await database.sessionDao.create(session('root'));
      final registry = collaborationRegistry(root, _tinestDefinition);

      final denied = await registry.invoke(
        'host.collaboration.spawn_agent',
        const <String, Object?>{},
        collaborationContext(const <String>{}),
      );
      expect(denied.toJson(), <String, Object?>{
        'ok': false,
        'error': <String, Object?>{
          'code': 'capability_denied',
          'message': 'Capability collaboration.spawn is not granted.',
          'retryable': false,
        },
      });

      final invalid = await registry.invoke(
        'host.collaboration.spawn_agent',
        const <String, Object?>{'task_name': 'BAD NAME', 'message': 'x'},
        collaborationContext(const <String>{'collaboration.spawn'}),
      );
      expect(invalid.ok, isFalse);
      expect(invalid.error?.code, 'collaboration_error');
      expect(invalid.error?.message, contains('task_name'));
      expect(invalid.error?.retryable, isFalse);
    });

    test('the wait primitive carries the mail across the boundary', () async {
      final root = await database.sessionDao.create(session('root'));
      final child = await database.sessionDao.create(
        session(
          'child',
          parentSessionId: 'root',
          taskName: 'task_a',
          agentPath: '/root/task_a',
          rootSessionId: 'root',
        ),
      );
      await service.onTurnFinished(
        sessionId: child.id,
        outcome: TurnStatus.completed,
        finalText: 'Reviewed.',
      );
      final registry = collaborationRegistry(root, _tinestDefinition);

      final waited = await registry.invoke(
        'host.collaboration.wait_agent',
        const <String, Object?>{},
        collaborationContext(const <String>{'collaboration.wait'}),
      );

      expect(waited.toJson(), <String, Object?>{
        'ok': true,
        'value': <String, Object?>{
          'outcome': 'mail',
          'timed_out': false,
          'messages': <Map<String, Object?>>[
            <String, Object?>{
              'type': 'final_answer',
              'sender': '/root/task_a',
              'payload': 'Reviewed.',
            },
          ],
        },
      });
    });

    test('list and interrupt preserve lifecycle wire values', () async {
      final root = await database.sessionDao.create(session('root'));
      await database.sessionDao.create(
        session(
          'child',
          parentSessionId: 'root',
          taskName: 'task_a',
          agentPath: '/root/task_a',
          rootSessionId: 'root',
          lifecycle: AgentLifecycle.pendingInit,
          agentDefinitionId: 'reviewer',
        ),
      );
      final registry = collaborationRegistry(root, _tinestDefinition);

      final listed = await registry.invoke(
        'host.collaboration.list_agents',
        const <String, Object?>{},
        collaborationContext(const <String>{'collaboration.list'}),
      );
      expect(listed.toJson(), <String, Object?>{
        'ok': true,
        'value': <String, Object?>{
          'agents': <Map<String, Object?>>[
            // Absent optionals are omitted rather than sent as null: the tree
            // root has no task name and no parent, and a Lua table reads an
            // absent key and an explicit null the same way.
            <String, Object?>{
              'session_id': 'root',
              'agent_name': '/root',
              'agent_status': 'completed',
              'session_status': 'idle',
              'title': 'root',
            },
            <String, Object?>{
              'session_id': 'child',
              'agent_name': '/root/task_a',
              'agent_status': 'pending_init',
              'session_status': 'idle',
              'title': 'child',
              'task_name': 'task_a',
              'parent_session_id': 'root',
            },
          ],
        },
      });

      final interrupted = await registry.invoke(
        'host.collaboration.interrupt_agent',
        const <String, Object?>{'target': '/root/task_a'},
        collaborationContext(const <String>{'collaboration.interrupt'}),
      );
      expect(interrupted.toJson(), <String, Object?>{
        'ok': true,
        'value': <String, Object?>{'previous_status': 'pending_init'},
      });
      expect(fakeRuntime.cancelled, <String>['child']);
    });

    test(
      'extension data identifies root and subagent roles without prompts',
      () {
        final root = session('root');
        expect(
          service.extensionDataFor(root, _tinestDefinition),
          <String, Object?>{
            'path': '/root',
            'is_root': true,
            'max_concurrent_turns': maxConcurrentSubagentTurnsPerTree,
          },
        );
        expect(
          service.extensionDataFor(root, _reviewerDefinition),
          <String, Object?>{
            'path': '/root',
            'is_root': true,
            'max_concurrent_turns': maxConcurrentSubagentTurnsPerTree,
          },
        );
        final child = session(
          'child',
          parentSessionId: 'root',
          taskName: 'task_a',
          agentPath: '/root/task_a',
          rootSessionId: 'root',
        );
        expect(
          service.extensionDataFor(
            child,
            _reviewerDefinition.copyWith(
              extensionIds: const <String>['tinest.collaboration'],
              toolIds: const <String>['tinest.collaboration/spawn_agent'],
            ),
          ),
          <String, Object?>{
            'path': '/root/task_a',
            'is_root': false,
            'max_concurrent_turns': maxConcurrentSubagentTurnsPerTree,
          },
        );
      },
    );

    test('Dart collaboration data contains no model prompt text', () {
      final root = session('root');
      final child = session(
        'child',
        parentSessionId: 'root',
        taskName: 'task_a',
        agentPath: '/root/task_a',
        rootSessionId: 'root',
      );
      final rootData = service.extensionDataFor(root, _tinestDefinition)!;
      final childData = service.extensionDataFor(
        child,
        _reviewerDefinition.copyWith(
          extensionIds: const <String>['tinest.collaboration'],
          toolIds: const <String>['tinest.collaboration/spawn_agent'],
        ),
      )!;
      expect(rootData.values.whereType<String>(), <String>['/root']);
      expect(childData.values.whereType<String>(), <String>['/root/task_a']);
    });
  });
}

final class _UnusedAttachmentPublisher implements AttachmentPublisher {
  @override
  Future<ConversationAttachment> publish(String path) =>
      throw UnimplementedError();
}

final class _UnusedAttachmentReader implements AttachmentReader {
  @override
  Future<ConversationAttachment> read(String id) => throw UnimplementedError();
}

final class _PrimitiveClock implements AgentClock {
  const new(this.now);

  final DateTime now;

  @override
  DateTime nowUtc() => now;

  @override
  Future<SleepOutcome> sleep(
    Duration duration,
    CancellationToken cancellation,
  ) => throw UnimplementedError();
}

final class _UnusedQuestions implements UserQuestionCoordinator {
  @override
  Future<List<UserAnswer>> ask(
    String callId,
    List<UserQuestion> questions,
    CancellationToken cancellation,
  ) => throw UnimplementedError();
}

final class _UnusedProcesses implements ExecSessionHost {
  @override
  bool isApproved(int sessionId) => false;

  @override
  ExecSession? lookup(int sessionId) => null;

  @override
  void markApproved(int sessionId) {}

  @override
  Future<ExecSession> start({
    required String command,
    required String workingDirectory,
    required bool tty,
    String? shell,
    bool login = true,
  }) => throw UnimplementedError();

  @override
  Future<bool> terminate(int sessionId) async => false;
}

final class _EmptySkills implements SkillCatalog {
  @override
  Future<SkillContent> read(String name) => throw UnimplementedError();

  @override
  Future<String> readResource(String name, String relativePath) =>
      throw UnimplementedError();

  @override
  List<SkillSummary> summaries() => const <SkillSummary>[];
}
