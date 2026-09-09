import 'dart:convert';
import 'dart:io';

import 'package:daemon/src/features/plugins/infrastructure/memory_plugin_stores.dart';
import 'package:daemon/src/features/plugins/infrastructure/native_plugin_state_repository.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_ports.dart';
import 'package:path/path.dart' as p;
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  test(
    'capability grants are keyed by Agent, plugin, and capability',
    () async {
      final store = MemoryAgentPluginGrantStore();
      const grant = AgentPluginGrantDto(
        agentId: 'agent-a',
        pluginId: 'acme.reader',
        capability: 'workspace.read',
      );

      await store.grant(grant);
      final revocations = <AgentPluginGrantDto>[];
      final subscription = store.revocations.listen(revocations.add);
      addTearDown(subscription.cancel);
      expect(await store.isGranted(grant), isTrue);
      expect(
        await store.isGranted(grant.copyWith(agentId: 'agent-b')),
        isFalse,
      );
      await store.revoke(grant);
      expect(await store.isGranted(grant), isFalse);
      expect(revocations, <AgentPluginGrantDto>[grant]);
      await store.revoke(grant);
      expect(revocations, <AgentPluginGrantDto>[grant]);
    },
    tags: const <String>['feature_test__plugin_permissions__unit'],
  );

  test(
    'scoped JSON state supports atomic compare-and-set transactions',
    () async {
      final store = MemoryPluginStateStore();
      const scope = PluginStateScope.agent(
        pluginId: 'acme.reader',
        agentId: 'agent-a',
      );

      expect(await store.read(scope, 'cursor'), isNull);
      final first = await store.compareAndSet(
        scope,
        'cursor',
        expectedRevision: 0,
        value: const <String, dynamic>{'offset': 1},
      );
      expect(first.revision, 1);
      await expectLater(
        store.compareAndSet(
          scope,
          'cursor',
          expectedRevision: 0,
          value: const <String, dynamic>{'offset': 2},
        ),
        throwsA(isA<PluginStateConflict>()),
      );
      final transaction = await store.transaction(scope, (values) {
        final current = values['cursor']!;
        return <PluginStateMutation>[
          PluginStateMutation.put(
            key: 'cursor',
            expectedRevision: current.revision,
            value: const <String, dynamic>{'offset': 3},
          ),
          const PluginStateMutation.put(
            key: 'status',
            expectedRevision: 0,
            value: 'ready',
          ),
        ];
      });
      expect(transaction['cursor']!.value, <String, dynamic>{'offset': 3});
      expect(transaction['status']!.value, 'ready');
    },
    tags: const <String>['feature_test__plugin_runtime__unit'],
  );

  test('durable jobs claim serially and require the current lease', () async {
    final store = MemoryPluginJobStore();
    final dueAt = DateTime.utc(2026);
    await store.enqueue(
      PluginJob(
        id: 'job-1',
        pluginId: 'acme.goal',
        executionRevisionHash: 'goal-execution-revision',
        bindingId: 'continue_goal',
        payload: const <String, dynamic>{'sessionId': 's1'},
        dueAt: dueAt,
      ),
    );

    final claimed = await store.claimNext(now: dueAt, leaseId: 'lease-a');
    expect(claimed?.status, PluginJobStatus.running);
    expect(await store.claimNext(now: dueAt, leaseId: 'lease-b'), isNull);
    await expectLater(
      store.complete('job-1', leaseId: 'wrong'),
      throwsA(isA<PluginJobLeaseConflict>()),
    );
    await store.complete('job-1', leaseId: 'lease-a');
    expect((await store.get('job-1'))!.status, PluginJobStatus.completed);
  });

  test(
    'native v5 repository recovers grants, scoped state, and expired jobs',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'tinest-plugin-state-',
      );
      addTearDown(() => root.delete(recursive: true));
      final v4File = File(p.join(root.path, 'v4', 'plugin-state.json'));
      await v4File.parent.create(recursive: true);
      await v4File.writeAsString('v4 must stay untouched');
      final repository = NativePluginStateRepository(root.path);
      const grant = AgentPluginGrantDto(
        agentId: 'agent-a',
        pluginId: 'acme.goal',
        capability: 'scheduler.write',
      );
      const scope = PluginStateScope.session(
        pluginId: 'acme.goal',
        sessionId: 'session-a',
      );
      final dueAt = DateTime.utc(2026, 1, 1, 12);

      await repository.grant(grant);
      await repository.compareAndSet(
        scope,
        'goal',
        expectedRevision: 0,
        value: const <String, dynamic>{'objective': 'Ship v5'},
      );
      await repository.enqueue(
        PluginJob(
          id: 'continue-goal',
          pluginId: 'acme.goal',
          executionRevisionHash: 'goal-execution-revision',
          bindingId: 'continue_goal',
          payload: const <String, dynamic>{'sessionId': 'session-a'},
          dueAt: dueAt,
          agentId: 'agent-a',
          sessionId: 'session-a',
        ),
      );
      final claimed = await repository.claimNext(
        now: dueAt,
        leaseId: 'first-process',
        leaseDuration: const Duration(minutes: 1),
      );
      expect(claimed?.leaseExpiresAt, dueAt.add(const Duration(minutes: 1)));

      final restarted = NativePluginStateRepository(root.path);
      expect(await restarted.isGranted(grant), isTrue);
      expect((await restarted.read(scope, 'goal'))!.value, <String, dynamic>{
        'objective': 'Ship v5',
      });
      expect(
        await restarted.claimNext(
          now: dueAt.add(const Duration(seconds: 30)),
          leaseId: 'second-process',
        ),
        isNull,
      );
      final reclaimed = await restarted.claimNext(
        now: dueAt.add(const Duration(minutes: 1)),
        leaseId: 'second-process',
      );
      expect(reclaimed?.id, 'continue-goal');
      expect(reclaimed?.leaseId, 'second-process');
      await restarted.complete('continue-goal', leaseId: 'second-process');

      final twiceRestarted = NativePluginStateRepository(root.path);
      expect(
        (await twiceRestarted.get('continue-goal'))!.status,
        PluginJobStatus.completed,
      );
      expect(await v4File.readAsString(), 'v4 must stay untouched');
      expect(
        File(p.join(root.path, 'v5', 'plugin-state.json')).existsSync(),
        isTrue,
      );

      final revocations = <AgentPluginGrantDto>[];
      final subscription = twiceRestarted.revocations.listen(revocations.add);
      addTearDown(subscription.cancel);
      await twiceRestarted.revoke(grant);
      expect(revocations, <AgentPluginGrantDto>[grant]);
      expect(
        await NativePluginStateRepository(root.path).isGranted(grant),
        isFalse,
      );
      await twiceRestarted.revoke(grant);
      expect(revocations, <AgentPluginGrantDto>[grant]);
    },
    tags: const <String>[
      'feature_test__plugin_permissions__unit',
      'feature_test__plugin_runtime__unit',
    ],
  );

  test('native scheduler cancellation is durable and owner isolated', () async {
    final root = await Directory.systemTemp.createTemp('tinest-plugin-cancel-');
    addTearDown(() => root.delete(recursive: true));
    final repository = NativePluginStateRepository(root.path);
    final dueAt = DateTime.utc(2026, 8, 12);
    for (final job in <PluginJob>[
      PluginJob(
        id: 'owned',
        pluginId: 'acme.goal',
        executionRevisionHash: 'goal-execution-revision',
        bindingId: 'scheduled',
        payload: const <String, dynamic>{},
        dueAt: dueAt,
        agentId: 'agent-a',
        sessionId: 'session-a',
      ),
      PluginJob(
        id: 'foreign',
        pluginId: 'other.goal',
        executionRevisionHash: 'other-execution-revision',
        bindingId: 'scheduled',
        payload: const <String, dynamic>{},
        dueAt: dueAt,
        agentId: 'agent-a',
        sessionId: 'session-a',
      ),
    ]) {
      await repository.enqueue(job);
    }

    expect(
      await repository.cancel(
        'foreign',
        pluginId: 'acme.goal',
        agentId: 'agent-a',
        sessionId: 'session-a',
      ),
      isFalse,
    );
    expect(
      await repository.cancel(
        'owned',
        pluginId: 'acme.goal',
        agentId: 'agent-a',
        sessionId: 'session-a',
      ),
      isTrue,
    );
    expect(
      await repository.cancel(
        'owned',
        pluginId: 'acme.goal',
        agentId: 'agent-a',
        sessionId: 'session-a',
      ),
      isFalse,
    );

    final restarted = NativePluginStateRepository(root.path);
    expect((await restarted.get('owned'))!.status, PluginJobStatus.cancelled);
    expect(
      (await restarted.claimNext(now: dueAt, leaseId: 'lease'))!.id,
      'foreign',
    );
  }, tags: const <String>['feature_test__plugin_runtime__unit']);

  test('native repository never overwrites malformed state', () async {
    final root = await Directory.systemTemp.createTemp('tinest-plugin-state-');
    addTearDown(() => root.delete(recursive: true));
    final stateFile = File(p.join(root.path, 'v5', 'plugin-state.json'));
    await stateFile.parent.create(recursive: true);
    await stateFile.writeAsString('{ malformed');
    final repository = NativePluginStateRepository(root.path);

    await expectLater(
      repository.list('agent-a'),
      throwsA(isA<FormatException>()),
    );
    expect(await stateFile.readAsString(), '{ malformed');
  });

  test(
    'native state transactions validate atomically and return copies',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'tinest-plugin-state-',
      );
      addTearDown(() => root.delete(recursive: true));
      final repository = NativePluginStateRepository(root.path);
      const scope = PluginStateScope.agent(
        pluginId: 'acme.state',
        agentId: 'agent-a',
      );
      final original = <String, Object?>{
        'nested': <Object?>[1, 2],
      };
      final first = await repository.compareAndSet(
        scope,
        'value',
        expectedRevision: 0,
        value: original,
      );
      (original['nested']! as List<Object?>).add(3);
      expect(first.value, <String, Object?>{
        'nested': <Object?>[1, 2],
      });

      await expectLater(
        repository.transaction(
          scope,
          (_) => const <PluginStateMutation>[
            PluginStateMutation.put(
              key: 'duplicate',
              expectedRevision: 0,
              value: 1,
            ),
            PluginStateMutation.put(
              key: 'duplicate',
              expectedRevision: 0,
              value: 2,
            ),
          ],
        ),
        throwsStateError,
      );
      expect(await repository.read(scope, 'duplicate'), isNull);

      final values = await repository.transaction(
        scope,
        (current) => <PluginStateMutation>[
          PluginStateMutation.remove(
            key: 'value',
            expectedRevision: current['value']!.revision,
          ),
          const PluginStateMutation.put(
            key: 'created',
            expectedRevision: 0,
            value: <String, Object?>{'ok': true},
          ),
        ],
      );
      expect(values.containsKey('value'), isFalse);
      expect(values['created']!.revision, 1);

      final invalid = <Future<void> Function()>[
        () async => await repository.grant(
          const AgentPluginGrantDto(
            agentId: '',
            pluginId: 'acme.state',
            capability: 'state.read',
          ),
        ),
        () async => await repository.grant(
          const AgentPluginGrantDto(
            agentId: 'agent-a',
            pluginId: 'invalid',
            capability: 'state.read',
          ),
        ),
        () async => await repository.grant(
          const AgentPluginGrantDto(
            agentId: 'agent-a',
            pluginId: 'acme.state',
            capability: 'invalid',
          ),
        ),
        () async =>
            await repository.read(scope, List<String>.filled(257, 'x').join()),
        () async => await repository.compareAndSet(
          scope,
          'value',
          expectedRevision: -1,
          value: null,
        ),
        () async => await repository.compareAndSet(
          scope,
          'value',
          expectedRevision: 0,
          value: double.nan,
        ),
        () async => await repository.compareAndSet(
          scope,
          'value',
          expectedRevision: 0,
          value: DateTime.utc(2026),
        ),
      ];
      for (final operation in invalid) {
        await expectLater(
          operation(),
          throwsA(anyOf(isA<FormatException>(), isA<ArgumentError>())),
        );
      }
    },
  );

  test(
    'native jobs validate leases and preserve every terminal outcome',
    () async {
      final root = await Directory.systemTemp.createTemp('tinest-plugin-jobs-');
      addTearDown(() => root.delete(recursive: true));
      final repository = NativePluginStateRepository(root.path);
      final dueAt = DateTime.utc(2026, 8, 12);

      await repository.enqueue(_pluginJob('release', dueAt));
      await expectLater(
        repository.enqueue(_pluginJob('release', dueAt)),
        throwsStateError,
      );
      expect(
        await repository.claimNext(
          now: dueAt.subtract(const Duration(seconds: 1)),
          leaseId: 'early',
        ),
        isNull,
      );
      await expectLater(
        repository.claimNext(
          now: dueAt,
          leaseId: 'lease',
          leaseDuration: Duration.zero,
        ),
        throwsArgumentError,
      );
      await repository.claimNext(now: dueAt, leaseId: 'release-lease');
      await repository.release('release', leaseId: 'release-lease');
      expect(
        (await repository.get('release'))!.status,
        PluginJobStatus.pending,
      );
      await repository.claimNext(now: dueAt, leaseId: 'complete-lease');
      await repository.complete('release', leaseId: 'complete-lease');

      await repository.enqueue(_pluginJob('failed', dueAt));
      await repository.claimNext(now: dueAt, leaseId: 'failed-lease');
      await repository.fail(
        'failed',
        leaseId: 'failed-lease',
        error: List<String>.filled(3000, 'x').join(),
      );
      expect((await repository.get('failed'))!.error, hasLength(2048));

      await expectLater(
        repository.complete('missing', leaseId: 'lease'),
        throwsStateError,
      );
      await expectLater(
        repository.complete('release', leaseId: 'wrong'),
        throwsA(isA<PluginJobLeaseConflict>()),
      );
      await expectLater(
        repository.enqueue(
          _pluginJob(
            'running',
            dueAt,
            status: PluginJobStatus.running,
            leaseId: 'lease',
            leaseExpiresAt: dueAt,
          ),
        ),
        throwsArgumentError,
      );
      await expectLater(
        repository.enqueue(
          _pluginJob('invalid-binding', dueAt, bindingId: 'Bad'),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'native decoding rejects malformed v5 fields without partial recovery',
    () async {
      final grant = <String, Object?>{
        'agentId': 'agent-a',
        'pluginId': 'acme.state',
        'capability': 'state.read',
      };
      final namespace = <String, Object?>{
        'pluginId': 'acme.state',
        'kind': 'session',
        'ownerId': 'session-a',
        'entries': <Object?>[
          <String, Object?>{'key': 'value', 'revision': 1, 'value': true},
        ],
      };
      final job = _encodedJob('job');
      final documents = <Object?>[
        null,
        <String, Object?>{'schemaVersion': 4},
        _document(grants: 'not-a-list'),
        _document(grants: <Object?>['not-an-object']),
        _document(grants: <Object?>[grant, grant]),
        _document(state: <Object?>[namespace, namespace]),
        _document(
          state: <Object?>[
            <String, Object?>{...namespace, 'kind': 'unknown'},
          ],
        ),
        _document(
          state: <Object?>[
            <String, Object?>{...namespace, 'ownerId': 3},
          ],
        ),
        _document(
          state: <Object?>[
            <String, Object?>{...namespace, 'ownerId': null},
          ],
        ),
        _document(
          state: <Object?>[
            <String, Object?>{
              ...namespace,
              'entries': <Object?>[
                <String, Object?>{'key': 'value', 'revision': 0, 'value': true},
              ],
            },
          ],
        ),
        _document(
          state: <Object?>[
            <String, Object?>{
              ...namespace,
              'entries': <Object?>[
                <String, Object?>{'key': 'value', 'revision': 1},
              ],
            },
          ],
        ),
        _document(
          state: <Object?>[
            <String, Object?>{
              ...namespace,
              'entries': <Object?>[
                <String, Object?>{'key': 'value', 'revision': 1, 'value': true},
                <String, Object?>{
                  'key': 'value',
                  'revision': 2,
                  'value': false,
                },
              ],
            },
          ],
        ),
        _document(jobs: <Object?>[job, job]),
        _document(
          jobs: <Object?>[
            <String, Object?>{...job, 'status': 'unknown'},
          ],
        ),
        _document(
          jobs: <Object?>[
            <String, Object?>{...job, 'dueAt': 'not-a-date'},
          ],
        ),
      ];

      for (final document in documents) {
        await _expectMalformedDocument(document);
      }
    },
  );

  test('native decoding restores every scoped state kind', () async {
    final root = await Directory.systemTemp.createTemp('tinest-plugin-scopes-');
    addTearDown(() => root.delete(recursive: true));
    final repository = NativePluginStateRepository(root.path);
    const scopes = <PluginStateScope>[
      PluginStateScope.plugin(pluginId: 'acme.state'),
      PluginStateScope.agent(pluginId: 'acme.state', agentId: 'agent-a'),
      PluginStateScope.session(pluginId: 'acme.state', sessionId: 'session-a'),
      PluginStateScope.workspace(
        pluginId: 'acme.state',
        workspaceId: 'workspace-a',
      ),
    ];
    for (final scope in scopes) {
      await repository.compareAndSet(
        scope,
        'value',
        expectedRevision: 0,
        value: scope.kind.name,
      );
    }

    final restarted = NativePluginStateRepository(root.path);
    for (final scope in scopes) {
      expect((await restarted.read(scope, 'value'))!.value, scope.kind.name);
    }
  });
}

PluginJob _pluginJob(
  String id,
  DateTime dueAt, {
  String bindingId = 'scheduled',
  PluginJobStatus status = PluginJobStatus.pending,
  String? leaseId,
  DateTime? leaseExpiresAt,
}) => PluginJob(
  id: id,
  pluginId: 'acme.state',
  executionRevisionHash: 'state-execution-revision',
  bindingId: bindingId,
  payload: const <String, dynamic>{},
  dueAt: dueAt,
  agentId: 'agent-a',
  sessionId: 'session-a',
  status: status,
  leaseId: leaseId,
  leaseExpiresAt: leaseExpiresAt,
);

Map<String, Object?> _document({
  Object? grants = const <Object?>[],
  Object? state = const <Object?>[],
  Object? jobs = const <Object?>[],
}) => <String, Object?>{
  'schemaVersion': 5,
  'grants': grants,
  'state': state,
  'jobs': jobs,
};

Map<String, Object?> _encodedJob(String id) => <String, Object?>{
  'id': id,
  'pluginId': 'acme.state',
  'executionRevisionHash': 'state-execution-revision',
  'bindingId': 'scheduled',
  'payload': <String, Object?>{},
  'dueAt': DateTime.utc(2026, 8, 12).toIso8601String(),
  'agentId': 'agent-a',
  'sessionId': 'session-a',
  'status': 'pending',
  'leaseId': null,
  'leaseExpiresAt': null,
  'error': null,
};

Future<void> _expectMalformedDocument(Object? document) async {
  final root = await Directory.systemTemp.createTemp(
    'tinest-plugin-malformed-',
  );
  try {
    final file = File(p.join(root.path, 'v5', 'plugin-state.json'));
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(document));
    await expectLater(
      NativePluginStateRepository(root.path).list('agent-a'),
      throwsFormatException,
    );
  } finally {
    await root.delete(recursive: true);
  }
}
