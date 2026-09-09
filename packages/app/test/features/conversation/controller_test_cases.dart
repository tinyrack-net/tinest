part of '../../app/application_controllers_test.dart';

/// Stands in for a host that cannot be reached while a page is requested.
final class _OfflineFailure implements Exception {
  const new();

  @override
  String toString() => 'offline';
}

void _registerConversationControllerTests() {
  final now = DateTime.utc(2026, 8, 2);
  final workspace = WorkspaceDto(
    id: 'workspace',
    name: 'Workspace',
    rootPath: '/workspace',
    kind: WorkspaceKind.directory,
    createdAt: now,
  );
  final worktree = WorktreeDto(
    id: 'worktree',
    workspaceId: workspace.id,
    name: workspace.name,
    path: workspace.rootPath,
    kind: WorktreeKind.directory,
    isTinestOwned: false,
    createdAt: now,
  );
  final agent = SessionDto(
    id: 'agent',
    worktreeId: worktree.id,
    title: 'Agent',
    agentDefinitionId: 'tinest',
    origin: SessionOrigin.manual,
    status: SessionStatus.idle,
    model: const ModelSelectionDto(modelId: 'openai/gpt-5.6-sol'),
    createdAt: now,
    updatedAt: now,
  );
  final approval = ApprovalRequestDto(
    id: 'approval',
    sessionId: agent.id,
    turnId: 'turn',
    toolCallId: 'call',
    toolName: 'apply_patch',
    risk: ToolRisk.write,
    arguments: const <String, dynamic>{'patch': 'diff'},
    status: ApprovalStatus.pending,
    createdAt: now,
  );
  final approvalEvent = TimelineEventDto(
    sessionId: agent.id,
    sequence: 1,
    turnId: 'turn',
    type: 'approval.requested',
    data: <String, dynamic>{'approval': approval.toJson()},
    createdAt: now,
  );

  test(
    'conversation notifier deduplicates timeline and resolves approvals',
    () async {
      final api = FakeTinestApi(
        agents: <SessionDto>[agent],
        timelines: <String, List<TimelineEventDto>>{
          agent.id: <TimelineEventDto>[approvalEvent],
        },
      );
      final container = _container(api);
      addTearDown(container.dispose);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      final provider = conversationControllerProvider('server', agent.id);
      final initial = await container.read(provider.future);
      expect(initial.timeline, <TimelineEventDto>[approvalEvent]);
      expect(initial.approvals[approval.id], approval);

      api
        ..emit(TimelineClientEvent(approvalEvent))
        ..emit(
          TimelineClientEvent(
            TimelineEventDto(
              sessionId: agent.id,
              sequence: 2,
              turnId: 'turn',
              type: 'assistant.delta',
              data: const <String, dynamic>{'text': 'hello'},
              createdAt: now,
            ),
          ),
        )
        ..emit(
          ApprovalRequestedClientEvent(approval.copyWith(id: 'approval-2')),
        );
      expect(container.read(provider).value!.timeline, hasLength(2));
      expect(container.read(provider).value!.approvals, hasLength(2));

      await container.read(provider.notifier).startTurn('  prompt  ');
      await container.read(provider.notifier).startTurn('   ');
      expect(api.startedPrompts, <String>['prompt']);
      expect(api.startedTurnIds, <String>['generated-id']);
      await container.read(provider.notifier).cancelTurn();
      expect(api.cancelledAgents, <String>[agent.id]);
      await container
          .read(provider.notifier)
          .resolveApproval(approval.id, approved: false);
      expect(api.approvalDecisions.single.approved, isFalse);
      expect(
        container.read(provider).value!.approvals,
        isNot(contains(approval.id)),
      );

      api.emit(
        TimelineClientEvent(
          TimelineEventDto(
            sessionId: agent.id,
            sequence: 3,
            turnId: 'turn',
            type: 'approval.resolved',
            data: const <String, dynamic>{'approvalId': 'approval-2'},
            createdAt: now,
          ),
        ),
      );
      expect(container.read(provider).value!.approvals, isEmpty);
      expect(
        await container.read(
          conversationControllerProvider('server', null).future,
        ),
        const ConversationState(),
      );
    },
    tags: const <String>['feature_test__turn_execution__unit'],
  );

  test('pending first prompts follow terminal timeline events', () async {
    final api = FakeTinestApi(agents: <SessionDto>[agent]);
    final container = _container(api);
    addTearDown(container.dispose);
    await container.read(hostRegistryControllerProvider.future);
    await Future<void>.delayed(Duration.zero);
    final provider = conversationControllerProvider('server', agent.id);
    final listener = container.listen(provider, (_, _) {});
    addTearDown(listener.close);
    await container.read(provider.future);
    container
        .read(pendingFirstTurnsProvider.notifier)
        .put(agent.id, 'first prompt');

    api.emit(
      TimelineClientEvent(
        TimelineEventDto(
          sessionId: agent.id,
          sequence: 1,
          turnId: 'first-turn',
          type: 'turn.failed',
          data: const <String, dynamic>{'error': 'runner setup failed'},
          createdAt: now,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(pendingFirstTurnsProvider)[agent.id]!.failed, isTrue);

    api.emit(
      TimelineClientEvent(
        TimelineEventDto(
          sessionId: agent.id,
          sequence: 2,
          turnId: 'retry-turn',
          type: 'user.message',
          data: const <String, dynamic>{'text': 'first prompt'},
          createdAt: now,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(pendingFirstTurnsProvider), isEmpty);
  }, tags: const <String>['feature_test__turn_execution__unit']);

  test('a started turn is visible before the daemon echoes it', () async {
    final api = FakeTinestApi(agents: <SessionDto>[agent])
      ..emitUserMessageEcho = false
      ..startTurnGate = Completer<void>();
    final container = _queueContainer(api);
    addTearDown(container.dispose);
    final provider = await _readyQueueProvider(container, agent);

    final send = container.read(provider.notifier).startTurn('follow up');
    await Future<void>.delayed(Duration.zero);

    // The bubble is recorded ahead of the RPC, not after it: the daemon acks
    // a turn long before it writes the durable user message.
    final pending = container.read(provider).value!.pending;
    expect(pending.map((turn) => turn.prompt), <String>['follow up']);

    api.startTurnGate!.complete();
    await send;
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(provider).value!.pending.single.turnId,
      api.startedTurnIds.single,
      reason: 'the entry carries the turn id the daemon was given',
    );
  }, tags: const <String>['feature_test__turn_execution__unit']);

  test(
    'the echo replaces the optimistic prompt in a single state write',
    () async {
      final api = FakeTinestApi(agents: <SessionDto>[agent])
        ..emitUserMessageEcho = false;
      final container = _queueContainer(api);
      addTearDown(container.dispose);
      final provider = await _readyQueueProvider(container, agent);
      await container.read(provider.notifier).startTurn('follow up');
      await Future<void>.delayed(Duration.zero);
      final turnId = api.startedTurnIds.single;

      // Two writes would put the echoed bubble on screen one frame after the
      // optimistic one left it, which is the flicker this pins shut.
      final observed = <({int timeline, int pending})>[];
      final listener = container.listen(provider, (_, next) {
        final state = next.value!;
        observed.add((
          timeline: state.timeline.length,
          pending: state.pending.length,
        ));
      });
      addTearDown(listener.close);

      api.emitTimeline(agent.id, 'user.message', <String, dynamic>{
        'text': 'follow up',
        'attachments': const <Map<String, dynamic>>[],
      }, turnId: turnId);
      await Future<void>.delayed(Duration.zero);

      expect(observed, <({int timeline, int pending})>[
        (timeline: 1, pending: 0),
      ]);
    },
    tags: const <String>['feature_test__turn_execution__unit'],
  );

  test(
    'cancelling one turn leaves another turn optimistic prompt alone',
    () async {
      final api = FakeTinestApi(agents: <SessionDto>[agent])
        ..emitUserMessageEcho = false;
      final container = _queueContainer(api);
      addTearDown(container.dispose);
      final provider = await _readyQueueProvider(container, agent);
      await container.read(provider.notifier).startTurn('first');
      await container.read(provider.notifier).startTurn('second');
      await Future<void>.delayed(Duration.zero);
      final first = api.startedTurnIds.first;

      api.emitTimeline(agent.id, 'turn.cancelled', const <String, dynamic>{
        'reason': 'interrupted',
      }, turnId: first);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(provider).value!.pending.map((turn) => turn.prompt),
        <String>['second'],
        reason: 'a terminal event resolves only its own turn',
      );
    },
    tags: const <String>['feature_test__turn_execution__unit'],
  );

  test(
    'a prompt the daemon rejects leaves no optimistic bubble behind',
    () async {
      final api = FakeTinestApi(agents: <SessionDto>[agent]);
      final container = _queueContainer(api);
      addTearDown(container.dispose);
      final provider = await _readyQueueProvider(container, agent);

      // Rejected as busy: the prompt becomes a visible queue row, and a bubble
      // left behind would be a second copy of the same prompt.
      api
        ..startTurnError = Exception('Agent already has a running turn.')
        ..emit(
          SessionUpdatedClientEvent(
            agent.copyWith(status: SessionStatus.running),
          ),
        );
      await Future<void>.delayed(Duration.zero);
      await container.read(provider.notifier).startTurn('into a live turn');
      await Future<void>.delayed(Duration.zero);

      expect(container.read(provider).value!.pending, isEmpty);
      expect(container.read(provider).value!.queued, hasLength(1));

      // Rejected outright: the composer takes the prompt back, so the bubble
      // has to go with it.
      api.emit(
        SessionUpdatedClientEvent(agent.copyWith(status: SessionStatus.idle)),
      );
      await Future<void>.delayed(Duration.zero);
      api.startTurnError = Exception('offline');
      await expectLater(
        container.read(provider.notifier).startTurn('while offline'),
        throwsA(isA<Exception>()),
      );
      expect(container.read(provider).value!.pending, isEmpty);
    },
    tags: const <String>['feature_test__turn_execution__unit'],
  );

  test('queued prompts start one per turn and survive a failed send', () async {
    final api = FakeTinestApi(agents: <SessionDto>[agent]);
    final container = ProviderContainer(
      overrides: [
        appServicesProvider.overrideWithValue(fakeAppServices(api)),
        appIdGeneratorProvider.overrideWithValue(_SequentialIdGenerator()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(hostRegistryControllerProvider.future);
    await Future<void>.delayed(Duration.zero);
    final provider = conversationControllerProvider('server', agent.id);
    final listener = container.listen(provider, (_, _) {});
    addTearDown(listener.close);
    await container.read(provider.future);
    // A prompt only queues because a turn is running.
    api.emit(
      SessionUpdatedClientEvent(agent.copyWith(status: SessionStatus.running)),
    );
    await Future<void>.delayed(Duration.zero);
    container.read(provider.notifier)
      ..enqueueTurn('  first  ')
      ..enqueueTurn('second')
      // Neither empty text nor empty attachments is worth a turn.
      ..enqueueTurn('   ');
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(provider).value!.queued.map((item) => item.text),
      <String>['first', 'second'],
    );

    // A settled session releases exactly one prompt, so each queued
    // follow-up gets a turn of its own.
    api.emit(
      SessionUpdatedClientEvent(agent.copyWith(status: SessionStatus.idle)),
    );
    await Future<void>.delayed(Duration.zero);
    expect(api.startedPrompts, <String>['first']);
    expect(
      container.read(provider).value!.queued.map((item) => item.text),
      <String>['second'],
    );

    // A send that fails puts its prompt back at the head rather than
    // dropping it. The failure also arms a retry, so this observes the state
    // one event-loop turn later, well inside conversationDrainRetryDelay:
    // the point here is the restore, and the retry has its own test.
    api
      ..startTurnError = Exception('offline')
      ..emit(
        SessionUpdatedClientEvent(agent.copyWith(status: SessionStatus.idle)),
      );
    await Future<void>.delayed(Duration.zero);
    expect(api.startedPrompts, <String>['first']);
    expect(
      container.read(provider).value!.queued.map((item) => item.text),
      <String>['second'],
    );

    api
      ..startTurnError = null
      ..emit(
        SessionUpdatedClientEvent(agent.copyWith(status: SessionStatus.failed)),
      );
    await Future<void>.delayed(Duration.zero);
    expect(api.startedPrompts, <String>['first', 'second']);
    expect(container.read(provider).value!.queued, isEmpty);
  }, tags: const <String>['feature_test__conversation_turn_queue__unit']);

  test(
    'a queued prompt whose send fails is retried without a new session event',
    () async {
      final api = FakeTinestApi(agents: <SessionDto>[agent])
        ..startTurnFailures = 1;
      final container = _queueContainer(api);
      addTearDown(container.dispose);
      final provider = await _readyQueueProvider(container, agent);

      api.emit(
        SessionUpdatedClientEvent(
          agent.copyWith(status: SessionStatus.running),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      container.read(provider.notifier).enqueueTurn('stranded');
      await Future<void>.delayed(Duration.zero);

      // The one event that releases the queue is also the last one coming: the
      // session is idle afterwards and stays there. A send that fails here has
      // no second chance unless the controller makes one.
      api.emit(
        SessionUpdatedClientEvent(agent.copyWith(status: SessionStatus.idle)),
      );
      await _settleDrainRetries();

      expect(api.startedPrompts, <String>['stranded']);
      expect(container.read(provider).value!.queued, isEmpty);
    },
    tags: const <String>['feature_test__conversation_turn_queue__unit'],
  );

  test(
    'a queued prompt still starts when the pending-input notice fails',
    () async {
      final api = FakeTinestApi(agents: <SessionDto>[agent])
        ..notePendingInputError = Exception('offline');
      final container = _queueContainer(api);
      addTearDown(container.dispose);
      final provider = await _readyQueueProvider(container, agent);

      // The session is already idle, so the enqueue's own settled check is the
      // only release this prompt will ever get. A failed notice must not take
      // that check down with it.
      container.read(provider.notifier).enqueueTurn('late');
      await _settleDrainRetries();

      expect(api.startedPrompts, <String>['late']);
      expect(container.read(provider).value!.queued, isEmpty);
    },
    tags: const <String>['feature_test__conversation_turn_queue__unit'],
  );

  test('a queued prompt still starts when the settled check fails', () async {
    final api = FakeTinestApi(agents: <SessionDto>[agent])
      ..listSessionsFailures = 1;
    final container = _queueContainer(api);
    addTearDown(container.dispose);
    final provider = await _readyQueueProvider(container, agent);

    container.read(provider.notifier).enqueueTurn('late');
    await _settleDrainRetries();

    expect(api.startedPrompts, <String>['late']);
    expect(container.read(provider).value!.queued, isEmpty);
  }, tags: const <String>['feature_test__conversation_turn_queue__unit']);

  test(
    'a queued prompt that never sends stops retrying and reports the failure',
    () async {
      final api = FakeTinestApi(agents: <SessionDto>[agent])
        ..startTurnError = Exception('offline');
      final container = _queueContainer(api);
      addTearDown(container.dispose);
      final provider = await _readyQueueProvider(container, agent);

      api.emit(
        SessionUpdatedClientEvent(
          agent.copyWith(status: SessionStatus.running),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      container.read(provider.notifier).enqueueTurn('doomed');
      await Future<void>.delayed(Duration.zero);
      api.emit(
        SessionUpdatedClientEvent(agent.copyWith(status: SessionStatus.idle)),
      );
      await _settleDrainRetries(rounds: conversationDrainMaxAttempts + 3);

      // An equality, not a bound: a greater count is the runaway retry this
      // budget exists to rule out, and `lessThan` would not catch it.
      expect(
        api.attemptedPrompts,
        List<String>.filled(conversationDrainMaxAttempts + 1, 'doomed'),
      );
      // The prompt is never dropped, but it stops passing for one that is
      // simply waiting its turn.
      final stuck = container.read(provider).value!.queued.single;
      expect(stuck.text, 'doomed');
      expect(stuck.error, isNotNull);
    },
    tags: const <String>['feature_test__conversation_turn_queue__unit'],
  );

  test('a drain requested while one is in flight is not dropped', () async {
    final gate = Completer<void>();
    final api = FakeTinestApi(agents: <SessionDto>[agent])
      ..startTurnGate = gate;
    final container = _queueContainer(api);
    addTearDown(container.dispose);
    final provider = await _readyQueueProvider(container, agent);

    api.emit(
      SessionUpdatedClientEvent(agent.copyWith(status: SessionStatus.running)),
    );
    await Future<void>.delayed(Duration.zero);
    container.read(provider.notifier).enqueueTurn('first');
    await Future<void>.delayed(Duration.zero);
    api.emit(
      SessionUpdatedClientEvent(agent.copyWith(status: SessionStatus.idle)),
    );
    await Future<void>.delayed(Duration.zero);

    // The drain is now parked inside startTurn. A prompt queued against the
    // idle session drains immediately, hits the in-flight guard, and that
    // rejected request is the only signal it had.
    container.read(provider.notifier).enqueueTurn('second');
    await Future<void>.delayed(Duration.zero);
    api.startTurnGate = null;
    gate.complete();
    await _settleDrainRetries();

    expect(api.startedPrompts, <String>['first', 'second']);
    expect(container.read(provider).value!.queued, isEmpty);
  }, tags: const <String>['feature_test__conversation_turn_queue__unit']);

  test(
    'a queue release that fails after disposal is dropped, not retried',
    () async {
      final gate = Completer<void>();
      final api = FakeTinestApi(agents: <SessionDto>[agent])
        ..startTurnGate = gate
        ..startTurnError = Exception('offline');
      final container = _queueContainer(api);
      addTearDown(container.dispose);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      final provider = conversationControllerProvider('server', agent.id);
      final listener = container.listen(provider, (_, _) {});
      await container.read(provider.future);

      api.emit(
        SessionUpdatedClientEvent(
          agent.copyWith(status: SessionStatus.running),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      container.read(provider.notifier).enqueueTurn('abandoned');
      await Future<void>.delayed(Duration.zero);
      api.emit(
        SessionUpdatedClientEvent(agent.copyWith(status: SessionStatus.idle)),
      );
      await Future<void>.delayed(Duration.zero);

      // The drain is parked inside startTurn when the screen goes away. The
      // failure it is about to see must not write state or arm a timer on a
      // controller nobody is listening to any more.
      listener.close();
      await Future<void>.delayed(Duration.zero);
      gate.complete();

      await expectLater(_settleDrainRetries(), completes);
      expect(api.attemptedPrompts, <String>['abandoned']);
    },
    tags: const <String>['feature_test__conversation_turn_queue__unit'],
  );

  test('a prompt queued after the turn already settled still starts', () async {
    final api = FakeTinestApi(agents: <SessionDto>[agent]);
    final container = ProviderContainer(
      overrides: [
        appServicesProvider.overrideWithValue(fakeAppServices(api)),
        appIdGeneratorProvider.overrideWithValue(_SequentialIdGenerator()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(hostRegistryControllerProvider.future);
    await Future<void>.delayed(Duration.zero);
    final provider = conversationControllerProvider('server', agent.id);
    final listener = container.listen(provider, (_, _) {});
    addTearDown(listener.close);
    await container.read(provider.future);

    // The composer reads a rendered flag that trails the daemon, so it can
    // queue one frame after the session went idle. No further session update
    // is coming, so nothing but the enqueue itself can release the prompt.
    container.read(provider.notifier).enqueueTurn('late');
    await Future<void>.delayed(Duration.zero);

    expect(api.startedPrompts, <String>['late']);
    expect(container.read(provider).value!.queued, isEmpty);
  }, tags: const <String>['feature_test__conversation_turn_queue__unit']);

  test(
    'a prompt the daemon rejects as busy is queued, not handed back',
    () async {
      final api = FakeTinestApi(agents: <SessionDto>[agent]);
      final container = ProviderContainer(
        overrides: [
          appServicesProvider.overrideWithValue(fakeAppServices(api)),
          appIdGeneratorProvider.overrideWithValue(_SequentialIdGenerator()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      final provider = conversationControllerProvider('server', agent.id);
      final listener = container.listen(provider, (_, _) {});
      addTearDown(listener.close);
      await container.read(provider.future);

      // The composer read `busy` one event too early and sent into a turn the
      // daemon still has running.
      api
        ..startTurnError = Exception('Agent already has a running turn.')
        ..emit(
          SessionUpdatedClientEvent(
            agent.copyWith(status: SessionStatus.running),
          ),
        );
      await Future<void>.delayed(Duration.zero);
      await container.read(provider.notifier).startTurn('into a live turn');
      await Future<void>.delayed(Duration.zero);

      expect(api.startedPrompts, isEmpty);
      expect(
        container.read(provider).value!.queued.map((item) => item.text),
        <String>['into a live turn'],
      );

      // It leaves the queue as soon as that turn settles.
      api
        ..startTurnError = null
        ..emit(
          SessionUpdatedClientEvent(agent.copyWith(status: SessionStatus.idle)),
        );
      await Future<void>.delayed(Duration.zero);
      expect(api.startedPrompts, <String>['into a live turn']);
      expect(container.read(provider).value!.queued, isEmpty);
    },
    tags: const <String>['feature_test__conversation_turn_queue__unit'],
  );

  test('a start failure that is not a running turn still surfaces', () async {
    final api = FakeTinestApi(agents: <SessionDto>[agent])
      ..startTurnError = Exception('offline');
    final container = ProviderContainer(
      overrides: [
        appServicesProvider.overrideWithValue(fakeAppServices(api)),
        appIdGeneratorProvider.overrideWithValue(_SequentialIdGenerator()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(hostRegistryControllerProvider.future);
    await Future<void>.delayed(Duration.zero);
    final provider = conversationControllerProvider('server', agent.id);
    final listener = container.listen(provider, (_, _) {});
    addTearDown(listener.close);
    await container.read(provider.future);

    // The session is idle, so the composer keeps owning the error.
    await expectLater(
      container.read(provider.notifier).startTurn('while offline'),
      throwsA(isA<Exception>()),
    );
    expect(container.read(provider).value!.queued, isEmpty);
  }, tags: const <String>['feature_test__conversation_turn_queue__unit']);

  test(
    'a queued prompt can be taken back or promoted past the active turn',
    () async {
      final api = FakeTinestApi(agents: <SessionDto>[agent]);
      final container = ProviderContainer(
        overrides: [
          appServicesProvider.overrideWithValue(fakeAppServices(api)),
          appIdGeneratorProvider.overrideWithValue(_SequentialIdGenerator()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      final provider = conversationControllerProvider('server', agent.id);
      final listener = container.listen(provider, (_, _) {});
      addTearDown(listener.close);
      await container.read(provider.future);
      final notifier = container.read(provider.notifier)
        ..enqueueTurn('edit me')
        ..enqueueTurn('send me');
      final queued = container.read(provider).value!.queued;

      expect(notifier.takeQueuedTurn(queued.first.id)?.text, 'edit me');
      expect(notifier.takeQueuedTurn('missing'), isNull);
      expect(
        container.read(provider).value!.queued.map((item) => item.text),
        <String>['send me'],
      );

      await notifier.sendQueuedTurnNow(queued.last.id);
      expect(api.cancelledAgents, <String>[agent.id]);
      expect(api.startedPrompts, <String>['send me']);
      expect(container.read(provider).value!.queued, isEmpty);

      notifier.enqueueTurn('doomed');
      final doomed = container.read(provider).value!.queued.single;
      api.startTurnError = Exception('offline');
      await expectLater(notifier.sendQueuedTurnNow(doomed.id), throwsException);
      expect(
        container.read(provider).value!.queued.map((item) => item.text),
        <String>['doomed'],
      );
    },
    tags: const <String>['feature_test__conversation_turn_queue__unit'],
  );

  test(
    'conversation ignores a transport event delivered after disposal',
    () async {
      final lateEvents = _LateClientEventStream();
      final api = FakeTinestApi(
        agents: <SessionDto>[agent],
        eventStream: lateEvents,
      );
      final container = _container(api);
      addTearDown(container.dispose);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      final provider = conversationControllerProvider('server', agent.id);
      final listener = container.listen(provider, (_, _) {});
      await container.read(provider.future);

      listener.close();
      await Future<void>.delayed(Duration.zero);

      expect(
        () => lateEvents.emit(
          TimelineClientEvent(
            TimelineEventDto(
              sessionId: agent.id,
              sequence: 1,
              type: 'assistant.delta',
              data: const <String, dynamic>{'text': 'late'},
              createdAt: now,
            ),
          ),
        ),
        returnsNormally,
      );
    },
  );

  test(
    'agent commands load once and reload when the daemon reports a change',
    () async {
      final api = FakeTinestApi(
        commands: <AgentCommandDto>[_agentCommand('review')],
      );
      final container = _container(api);
      addTearDown(container.dispose);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);

      final provider = agentCommandsControllerProvider('server', null);
      final listener = container.listen(provider, (_, _) {});
      addTearDown(listener.close);

      expect(
        (await container.read(provider.future)).map((item) => item.name),
        <String>['review'],
      );

      api.commands.add(_agentCommand('ship'));
      api.emit(const CommandsChangedClientEvent());
      await Future<void>.delayed(Duration.zero);

      expect(container.read(provider).value!.map((item) => item.name), <String>[
        'review',
        'ship',
      ]);
      unawaited(api.close());
    },
    tags: const <String>['feature_test__composer_slash_command__unit'],
  );

  test(
    'a file search waits out its debounce and re-ranks what it receives',
    () async {
      final api = FakeTinestApi(
        files: <String, List<String>>{
          'worktree': <String>['docs/composer.md', 'lib/composer.dart'],
        },
      );
      final container = _container(api);
      addTearDown(container.dispose);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);

      final provider = composerFileSearchProvider(
        'server',
        'worktree',
        'composer',
      );
      final listener = container.listen(provider, (_, _) {});
      addTearDown(listener.close);

      // Nothing reaches the daemon until the debounce elapses.
      await Future<void>.delayed(Duration.zero);
      expect(api.searchedQueries, isEmpty);

      final matches = await container.read(provider.future);

      expect(api.searchedQueries, <String>['composer']);
      // The basename match outranks the one that only matches through a
      // directory segment.
      expect(matches.first.relativePath, 'lib/composer.dart');
      unawaited(api.close());
    },
    tags: const <String>['feature_test__composer_file_mention__unit'],
  );

  test(
    'a file search abandoned inside its debounce never reaches the daemon',
    () async {
      final api = FakeTinestApi(
        files: <String, List<String>>{
          'worktree': <String>['lib/composer.dart'],
        },
      );
      final container = _container(api);
      addTearDown(container.dispose);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);

      // Each keystroke is its own provider, so an abandoned one disposes and
      // cancels its timer before the daemon is ever asked.
      for (final query in <String>['c', 'co', 'com']) {
        final listener = container.listen(
          composerFileSearchProvider('server', 'worktree', query),
          (_, _) {},
        );
        await Future<void>.delayed(Duration.zero);
        listener.close();
      }
      await Future<void>.delayed(composerFileSearchDebounce * 2);

      expect(api.searchedQueries, isEmpty);
      unawaited(api.close());
    },
    tags: const <String>['feature_test__composer_file_mention__unit'],
  );

  TimelineEventDto historyEvent(int sequence) => TimelineEventDto(
    sessionId: agent.id,
    sequence: sequence,
    turnId: 'turn-$sequence',
    type: 'user.message',
    data: <String, dynamic>{
      'text': 'history $sequence',
      'attachments': const <Map<String, dynamic>>[],
    },
    createdAt: now.add(Duration(seconds: sequence)),
  );

  test(
    'a delta delivered while the subscription was in flight is not dropped',
    () async {
      // Rejoining a tab re-subscribes, and the daemon answers over a link that
      // takes time. A running turn keeps writing throughout, so whatever is
      // delivered during that round trip has to reach the conversation: the
      // events after it are numbered as though it did.
      final history = <TimelineEventDto>[
        for (var sequence = 1; sequence <= 10; sequence += 1)
          historyEvent(sequence),
      ];
      final api = FakeTinestApi(
        agents: <SessionDto>[agent],
        timelines: <String, List<TimelineEventDto>>{agent.id: history},
      );
      final roundTrip = Completer<void>();
      api.subscribeTimelineGate = roundTrip;
      final container = _container(api);
      addTearDown(container.dispose);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      final provider = conversationControllerProvider('server', agent.id);
      final listener = container.listen(provider, (_, _) {});
      addTearDown(listener.close);
      final pending = container.read(provider.future);
      await Future<void>.delayed(Duration.zero);

      // The second is already in the snapshot the daemon is about to answer
      // with: the same row reaching the app twice is one row.
      api
        ..emit(TimelineClientEvent(historyEvent(11)))
        ..emit(TimelineClientEvent(historyEvent(10)));
      roundTrip.complete();
      api.subscribeTimelineGate = null;
      final loaded = await pending;

      expect(
        loaded.timeline.map((event) => event.sequence),
        <int>[for (var sequence = 1; sequence <= 11; sequence += 1) sequence],
        reason:
            'the delta written during the round trip belongs to the '
            'conversation, whichever side of the snapshot it arrived on',
      );
      unawaited(api.close());
    },
    tags: const <String>['feature_test__turn_execution__unit'],
  );

  test(
    'a first prompt delivered during the round trip opens the conversation',
    () async {
      // A session created moments ago has nothing stored yet, so the snapshot
      // is empty and everything it has is what arrives while it is in flight.
      final api = FakeTinestApi(agents: <SessionDto>[agent]);
      final roundTrip = Completer<void>();
      api.subscribeTimelineGate = roundTrip;
      final container = _container(api);
      addTearDown(container.dispose);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      final provider = conversationControllerProvider('server', agent.id);
      final listener = container.listen(provider, (_, _) {});
      addTearDown(listener.close);
      final pending = container.read(provider.future);
      await Future<void>.delayed(Duration.zero);

      api.emit(TimelineClientEvent(historyEvent(1)));
      roundTrip.complete();
      api.subscribeTimelineGate = null;
      final loaded = await pending;

      expect(loaded.timeline.map((event) => event.sequence), <int>[1]);
      expect(
        loaded.hasMoreOlder,
        isFalse,
        reason: 'the first event of a session has nothing behind it',
      );
      unawaited(api.close());
    },
    tags: const <String>['feature_test__turn_execution__unit'],
  );

  test(
    'an approval and a question raised during the round trip survive it',
    () async {
      // Both arrive on their own notification rather than in the timeline
      // window, so a subscription that starts after the snapshot loses the two
      // cards that are the only way to unblock the turn.
      final api = FakeTinestApi(
        agents: <SessionDto>[agent],
        timelines: <String, List<TimelineEventDto>>{
          agent.id: <TimelineEventDto>[historyEvent(1)],
        },
      );
      final question = UserQuestionRequestDto(
        id: 'question',
        sessionId: agent.id,
        turnId: 'turn',
        toolCallId: 'ask-call',
        questions: const <UserQuestionItemDto>[],
        status: UserQuestionStatus.pending,
        createdAt: now,
      );
      final roundTrip = Completer<void>();
      api.subscribeTimelineGate = roundTrip;
      final container = _container(api);
      addTearDown(container.dispose);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      final provider = conversationControllerProvider('server', agent.id);
      final listener = container.listen(provider, (_, _) {});
      addTearDown(listener.close);
      final pending = container.read(provider.future);
      await Future<void>.delayed(Duration.zero);

      api
        ..emit(ApprovalRequestedClientEvent(approval))
        ..emit(UserQuestionRequestedClientEvent(question));
      roundTrip.complete();
      api.subscribeTimelineGate = null;
      final loaded = await pending;

      expect(loaded.approvals[approval.id], approval);
      expect(loaded.questions[question.id], question);
      unawaited(api.close());
    },
    tags: const <String>['feature_test__turn_execution__unit'],
  );

  test(
    'the span a gap exposes is fetched back into place',
    () async {
      final history = <TimelineEventDto>[
        for (var sequence = 1; sequence <= 10; sequence += 1)
          historyEvent(sequence),
      ];
      final api = FakeTinestApi(
        agents: <SessionDto>[agent],
        timelines: <String, List<TimelineEventDto>>{agent.id: history},
      );
      final container = _container(api);
      addTearDown(container.dispose);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      final provider = conversationControllerProvider('server', agent.id);
      final listener = container.listen(provider, (_, _) {});
      addTearDown(listener.close);
      await container.read(provider.future);

      // The daemon wrote two more rows that this client was never told about,
      // and the row after them is the one that exposes the hole.
      api
        ..storeTimelineUnannounced(agent.id, <TimelineEventDto>[
          historyEvent(11),
          historyEvent(12),
          historyEvent(13),
        ])
        ..emit(TimelineClientEvent(historyEvent(13)));
      for (var turn = 0; turn < 4; turn += 1) {
        await Future<void>.delayed(Duration.zero);
      }

      final healed = container.read(provider).requireValue;
      expect(
        healed.timeline.map((event) => event.sequence),
        <int>[for (var sequence = 1; sequence <= 13; sequence += 1) sequence],
        reason: 'the missing rows belong between the ones either side of them',
      );
      expect(
        api.readTimelineHistoryCount,
        1,
        reason: 'one hole is one request, not one per row',
      );
      expect(healed.hasMoreOlder, isFalse);
      expect(healed.olderFailed, isFalse);
      unawaited(api.close());
    },
    tags: const <String>['feature_test__conversation_history_pagination__unit'],
  );

  test(
    'a gap wider than a page is filled from its newest end',
    () async {
      // Only an absence long enough to have written a page of history reaches
      // this. Filling what one page reaches leaves the rest missing, which is
      // a bounded inaccuracy above the reader rather than the loss of
      // everything they were reading.
      final history = <TimelineEventDto>[
        for (var sequence = 1; sequence <= 10; sequence += 1)
          historyEvent(sequence),
      ];
      const newest = 10 + timelineHistoryPageSize + 51;
      final api = FakeTinestApi(
        agents: <SessionDto>[agent],
        timelines: <String, List<TimelineEventDto>>{agent.id: history},
      );
      final container = _container(api);
      addTearDown(container.dispose);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      final provider = conversationControllerProvider('server', agent.id);
      final listener = container.listen(provider, (_, _) {});
      addTearDown(listener.close);
      await container.read(provider.future);

      api
        ..storeTimelineUnannounced(agent.id, <TimelineEventDto>[
          for (var sequence = 11; sequence <= newest; sequence += 1)
            historyEvent(sequence),
        ])
        ..emit(TimelineClientEvent(historyEvent(newest)));
      for (var turn = 0; turn < 4; turn += 1) {
        await Future<void>.delayed(Duration.zero);
      }

      final sequences = container
          .read(provider)
          .requireValue
          .timeline
          .map((event) => event.sequence)
          .toList(growable: false);
      expect(sequences.take(10), <int>[
        for (var sequence = 1; sequence <= 10; sequence += 1) sequence,
      ], reason: 'what the reader was holding is untouched');
      expect(sequences.last, newest);
      expect(
        sequences,
        isNot(contains(11)),
        reason: 'a page does not reach the oldest end of a span this wide',
      );
      expect(
        sequences.where((sequence) => sequence > 10 && sequence < newest),
        hasLength(timelineHistoryPageSize),
        reason: 'exactly one page of the span is recovered',
      );
      unawaited(api.close());
    },
    tags: const <String>['feature_test__conversation_history_pagination__unit'],
  );

  test(
    'a span that cannot be fetched leaves the transcript alone',
    () async {
      final history = <TimelineEventDto>[
        for (var sequence = 1; sequence <= 10; sequence += 1)
          historyEvent(sequence),
      ];
      final api = FakeTinestApi(
        agents: <SessionDto>[agent],
        timelines: <String, List<TimelineEventDto>>{agent.id: history},
      )..readTimelineHistoryFailure = const _OfflineFailure();
      final container = _container(api);
      addTearDown(container.dispose);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      final provider = conversationControllerProvider('server', agent.id);
      final listener = container.listen(provider, (_, _) {});
      addTearDown(listener.close);
      await container.read(provider.future);

      api
        ..storeTimelineUnannounced(agent.id, <TimelineEventDto>[
          historyEvent(11),
          historyEvent(12),
          historyEvent(13),
        ])
        ..emit(TimelineClientEvent(historyEvent(13)));
      for (var turn = 0; turn < 4; turn += 1) {
        await Future<void>.delayed(Duration.zero);
      }

      final unhealed = container.read(provider).requireValue;
      expect(unhealed.timeline.map((event) => event.sequence), <int>[
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        13,
      ]);
      expect(
        unhealed.olderFailed,
        isFalse,
        reason:
            'the row that reports a failure belongs to a page the reader '
            'asked for, and they asked for nothing here',
      );
      unawaited(api.close());
    },
    tags: const <String>['feature_test__conversation_history_pagination__unit'],
  );

  test(
    'a gap in delivered sequences does not discard the loaded transcript',
    () async {
      // The reader is looking at a loaded window. One event goes missing on the
      // way, so the next one is numbered past the last one held. The events
      // already on screen are still real, and they are what the reader is
      // reading.
      final history = <TimelineEventDto>[
        for (var sequence = 1; sequence <= 10; sequence += 1)
          historyEvent(sequence),
      ];
      final api = FakeTinestApi(
        agents: <SessionDto>[agent],
        timelines: <String, List<TimelineEventDto>>{agent.id: history},
      );
      final container = _container(api);
      addTearDown(container.dispose);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      final provider = conversationControllerProvider('server', agent.id);
      final listener = container.listen(provider, (_, _) {});
      addTearDown(listener.close);
      final loaded = await container.read(provider.future);
      expect(loaded.timeline, hasLength(10));

      api.emit(TimelineClientEvent(historyEvent(13)));
      final afterGap = container.read(provider).requireValue;

      expect(
        afterGap.timeline.map((event) => event.sequence),
        containsAllInOrder(<int>[1, 10, 13]),
        reason:
            'a gap above the window is a gap, not a reason to throw the '
            'window away',
      );
      unawaited(api.close());
    },
    tags: const <String>['feature_test__turn_execution__unit'],
  );

  test(
    'a conversation opens on the newest page and pages backwards on demand',
    () async {
      final history = <TimelineEventDto>[
        for (
          var sequence = 1;
          sequence <= timelineHistoryPageSize * 2 + 20;
          sequence += 1
        )
          historyEvent(sequence),
      ];
      final api = FakeTinestApi(
        agents: <SessionDto>[agent],
        timelines: <String, List<TimelineEventDto>>{agent.id: history},
      );
      final container = _container(api);
      addTearDown(container.dispose);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      final provider = conversationControllerProvider('server', agent.id);
      final initial = await container.read(provider.future);

      expect(initial.timeline, hasLength(timelineHistoryPageSize));
      expect(initial.timeline.last.sequence, history.last.sequence);
      expect(initial.hasMoreOlder, isTrue);
      expect(initial.loadingOlder, isFalse);

      await container.read(provider.notifier).loadOlderHistory();
      final second = container.read(provider).requireValue;
      expect(second.timeline, hasLength(timelineHistoryPageSize * 2));
      expect(second.timeline.first.sequence, 21);
      expect(second.hasMoreOlder, isTrue);
      expect(second.loadingOlder, isFalse);
      expect(
        second.timeline.map((event) => event.sequence).toSet(),
        hasLength(second.timeline.length),
        reason: 'a prepended page never repeats an event already loaded',
      );

      // The last page is short, which is how the beginning announces itself.
      await container.read(provider.notifier).loadOlderHistory();
      final third = container.read(provider).requireValue;
      expect(third.timeline, hasLength(history.length));
      expect(third.timeline.first.sequence, 1);
      expect(third.hasMoreOlder, isFalse);

      // Nothing left to ask for, so nothing is asked for.
      final calls = api.readTimelineHistoryCount;
      await container.read(provider.notifier).loadOlderHistory();
      expect(api.readTimelineHistoryCount, calls);
      unawaited(api.close());
    },
    tags: const <String>['feature_test__conversation_history_pagination__unit'],
  );

  test(
    'a session that fits one page never asks for older history',
    () async {
      final api = FakeTinestApi(
        agents: <SessionDto>[agent],
        timelines: <String, List<TimelineEventDto>>{
          agent.id: <TimelineEventDto>[historyEvent(1), historyEvent(2)],
        },
      );
      final container = _container(api);
      addTearDown(container.dispose);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      final provider = conversationControllerProvider('server', agent.id);
      final initial = await container.read(provider.future);

      expect(initial.hasMoreOlder, isFalse);
      await container.read(provider.notifier).loadOlderHistory();
      expect(api.readTimelineHistoryCount, 0);
      expect(container.read(provider).requireValue.timeline, hasLength(2));
      unawaited(api.close());
    },
    tags: const <String>['feature_test__conversation_history_pagination__unit'],
  );

  test(
    'a failed page keeps the timeline and lets the reader ask again',
    () async {
      final history = <TimelineEventDto>[
        for (
          var sequence = 1;
          sequence <= timelineHistoryPageSize + 5;
          sequence += 1
        )
          historyEvent(sequence),
      ];
      final api = FakeTinestApi(
        agents: <SessionDto>[agent],
        timelines: <String, List<TimelineEventDto>>{agent.id: history},
      )..readTimelineHistoryFailure = const _OfflineFailure();
      final container = _container(api);
      addTearDown(container.dispose);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      final provider = conversationControllerProvider('server', agent.id);
      final loaded = await container.read(provider.future);

      await container.read(provider.notifier).loadOlderHistory();
      final failed = container.read(provider).requireValue;
      expect(failed.timeline, loaded.timeline);
      expect(failed.loadingOlder, isFalse);
      expect(failed.hasMoreOlder, isTrue);
      expect(failed.olderFailed, isTrue);

      api.readTimelineHistoryFailure = null;
      await container.read(provider.notifier).loadOlderHistory();
      final recovered = container.read(provider).requireValue;
      expect(recovered.timeline, hasLength(history.length));
      expect(recovered.hasMoreOlder, isFalse);
      expect(
        recovered.olderFailed,
        isFalse,
        reason: 'a page that succeeded must clear the failure it replaced',
      );
      unawaited(api.close());
    },
    tags: const <String>['feature_test__conversation_history_pagination__unit'],
  );
}
