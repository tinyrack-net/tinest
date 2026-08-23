@Tags(<String>['feature_test__agent_collaboration__unit'])
library;

import 'package:app/src/features/conversation/application/subagent_track_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';

void main() {
  final now = DateTime.utc(2026, 8, 6);

  SessionDto session(
    String id, {
    String? parentSessionId,
    String? taskName,
    String? agentPath,
    AgentLifecycle? lifecycle,
    DateTime? createdAt,
    SessionStatus status = SessionStatus.idle,
  }) => SessionDto(
    id: id,
    worktreeId: 'worktree',
    title: 'Session $id',
    agentDefinitionId: 'tinest',
    origin: parentSessionId == null
        ? SessionOrigin.manual
        : SessionOrigin.delegated,
    status: status,
    parentSessionId: parentSessionId,
    taskName: taskName,
    agentPath: agentPath,
    rootSessionId: parentSessionId == null ? null : 'root',
    lifecycle: lifecycle,
    model: const ModelSelectionDto(modelId: 'openai/gpt-5.6-sol'),
    createdAt: createdAt ?? now,
    updatedAt: createdAt ?? now,
  );

  test('rows are depth-first, creation-ordered, and scoped to one root', () {
    final sessions = <SessionDto>[
      session('root'),
      session('other-root'),
      session(
        'b',
        parentSessionId: 'root',
        taskName: 'task_b',
        createdAt: now.add(const Duration(seconds: 2)),
      ),
      session('a', parentSessionId: 'root', taskName: 'task_a'),
      session('a1', parentSessionId: 'a', taskName: 'task_a1'),
      session('stranger', parentSessionId: 'other-root'),
    ];
    final rows = buildSubagentTrackRows(sessions, 'root');
    expect(rows.map((row) => row.session.id), <String>['a', 'a1', 'b']);
    expect(rows.map((row) => row.depth), <int>[0, 1, 0]);
    expect(rows.map((row) => row.label), <String>[
      'task_a',
      'task_a1',
      'task_b',
    ]);
    expect(buildSubagentTrackRows(sessions, 'other-root'), hasLength(1));
    expect(buildSubagentTrackRows(sessions, 'a1'), isEmpty);
  });

  test('a label falls back to the session title', () {
    final rows = buildSubagentTrackRows(<SessionDto>[
      session('root'),
      session('child', parentSessionId: 'root'),
    ], 'root');
    expect(rows.single.label, 'Session child');
  });

  test('a parent cycle terminates instead of recursing forever', () {
    final rows = buildSubagentTrackRows(<SessionDto>[
      session('a', parentSessionId: 'b', taskName: 'task_a'),
      session('b', parentSessionId: 'a', taskName: 'task_b'),
    ], 'a');
    expect(rows.map((row) => row.session.id), <String>['b']);
  });

  test('running counts include pending, exclude finished states', () {
    final rows = buildSubagentTrackRows(<SessionDto>[
      session('root'),
      session(
        'a',
        parentSessionId: 'root',
        lifecycle: AgentLifecycle.running,
      ),
      session(
        'b',
        parentSessionId: 'root',
        lifecycle: AgentLifecycle.pendingInit,
        createdAt: now.add(const Duration(seconds: 1)),
      ),
      session(
        'c',
        parentSessionId: 'root',
        lifecycle: AgentLifecycle.completed,
        createdAt: now.add(const Duration(seconds: 2)),
      ),
      session(
        'd',
        parentSessionId: 'root',
        lifecycle: AgentLifecycle.errored,
        createdAt: now.add(const Duration(seconds: 3)),
      ),
      session(
        'e',
        parentSessionId: 'root',
        lifecycle: AgentLifecycle.interrupted,
        createdAt: now.add(const Duration(seconds: 4)),
      ),
    ], 'root');
    expect(isSubagentSession(rows.first.session), isTrue);
    expect(isSubagentSession(session('root')), isFalse);
  });

  test('blocked rows are the descendants waiting on the user', () {
    final rows = buildSubagentTrackRows(<SessionDto>[
      session('root'),
      session(
        'a',
        parentSessionId: 'root',
        taskName: 'task_a',
        lifecycle: AgentLifecycle.running,
        status: SessionStatus.running,
      ),
      session(
        'b',
        parentSessionId: 'root',
        taskName: 'task_b',
        lifecycle: AgentLifecycle.running,
        status: SessionStatus.waitingForApproval,
        createdAt: now.add(const Duration(seconds: 1)),
      ),
      session(
        'b1',
        parentSessionId: 'b',
        taskName: 'task_b1',
        lifecycle: AgentLifecycle.running,
        status: SessionStatus.waitingForApproval,
        createdAt: now.add(const Duration(seconds: 2)),
      ),
    ], 'root');
    expect(blockedSubagentRows(rows).map((row) => row.session.id), <String>[
      'b',
      'b1',
    ]);
  });

  test('a subagent waiting on the user appears in blocked rows', () {
    final rows = buildSubagentTrackRows(<SessionDto>[
      session('root'),
      session(
        'a',
        parentSessionId: 'root',
        lifecycle: AgentLifecycle.running,
        status: SessionStatus.running,
      ),
      session(
        'b',
        parentSessionId: 'root',
        lifecycle: AgentLifecycle.running,
        status: SessionStatus.waitingForApproval,
        createdAt: now.add(const Duration(seconds: 1)),
      ),
    ], 'root');
    expect(blockedSubagentRows(rows), hasLength(1));
  });
}
