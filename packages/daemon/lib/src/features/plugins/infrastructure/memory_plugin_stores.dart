import 'dart:async';
import 'dart:convert';

import 'package:daemon/src/features/plugins/infrastructure/plugin_ports.dart';
import 'package:protocol/protocol.dart';

/// Deterministic grant adapter for tests and ephemeral daemon composition.
final class MemoryAgentPluginGrantStore implements AgentPluginGrantStore {
  final Set<AgentPluginGrantDto> _grants = <AgentPluginGrantDto>{};
  final StreamController<AgentPluginGrantDto> _revocations =
      StreamController<AgentPluginGrantDto>.broadcast(sync: true);

  @override
  Stream<AgentPluginGrantDto> get revocations => _revocations.stream;

  @override
  Future<void> grant(AgentPluginGrantDto grant) async {
    _grants.add(grant);
  }

  @override
  Future<bool> isGranted(AgentPluginGrantDto grant) async =>
      _grants.contains(grant);

  @override
  Future<List<AgentPluginGrantDto>> list(String agentId) async {
    final result =
        _grants
            .where((grant) => grant.agentId == agentId)
            .toList(growable: false)
          ..sort((left, right) {
            final pluginOrder = left.pluginId.compareTo(right.pluginId);
            return pluginOrder != 0
                ? pluginOrder
                : left.capability.compareTo(right.capability);
          });
    return result;
  }

  @override
  Future<void> revoke(AgentPluginGrantDto grant) async {
    if (_grants.remove(grant)) _revocations.add(grant);
  }
}

/// Deterministic serialized JSON state adapter.
final class MemoryPluginStateStore implements PluginStateStore {
  final Map<String, Map<String, PluginStateEntry>> _scopes =
      <String, Map<String, PluginStateEntry>>{};
  Future<void> _tail = Future<void>.value();

  @override
  Future<PluginStateEntry?> read(PluginStateScope scope, String key) =>
      _serialize(() => _copyEntry(_scopes[_scopeKey(scope)]?[key]));

  @override
  Future<PluginStateEntry> compareAndSet(
    PluginStateScope scope,
    String key, {
    required int expectedRevision,
    required Object? value,
  }) => _serialize(() {
    _validateJson(value);
    final values = _scopes.putIfAbsent(
      _scopeKey(scope),
      () => <String, PluginStateEntry>{},
    );
    final actualRevision = values[key]?.revision ?? 0;
    _checkRevision(key, expectedRevision, actualRevision);
    final next = PluginStateEntry(
      revision: actualRevision + 1,
      value: _copyJson(value),
    );
    values[key] = next;
    return _copyEntry(next)!;
  });

  @override
  Future<Map<String, PluginStateEntry>> transaction(
    PluginStateScope scope,
    List<PluginStateMutation> Function(Map<String, PluginStateEntry> values)
    buildMutations,
  ) => _serialize(() {
    final values = _scopes.putIfAbsent(
      _scopeKey(scope),
      () => <String, PluginStateEntry>{},
    );
    final snapshot = _copyEntries(values);
    final mutations = buildMutations(
      Map<String, PluginStateEntry>.unmodifiable(snapshot),
    );
    final keys = <String>{};
    for (final mutation in mutations) {
      if (!keys.add(mutation.key)) {
        throw StateError('A transaction may mutate each key only once.');
      }
      final actualRevision = values[mutation.key]?.revision ?? 0;
      _checkRevision(mutation.key, mutation.expectedRevision, actualRevision);
      if (!mutation.remove) _validateJson(mutation.value);
    }
    for (final mutation in mutations) {
      if (mutation.remove) {
        values.remove(mutation.key);
      } else {
        values[mutation.key] = PluginStateEntry(
          revision: mutation.expectedRevision + 1,
          value: _copyJson(mutation.value),
        );
      }
    }
    return _copyEntries(values);
  });

  Future<T> _serialize<T>(FutureOr<T> Function() operation) {
    final previous = _tail;
    final released = Completer<void>();
    _tail = released.future;
    return previous.then((_) async {
      try {
        return await operation();
      } finally {
        released.complete();
      }
    });
  }
}

/// Deterministic serialized durable-job adapter.
final class MemoryPluginJobStore implements PluginJobStore {
  final Map<String, PluginJob> _jobs = <String, PluginJob>{};
  Future<void> _tail = Future<void>.value();

  @override
  Future<void> enqueue(PluginJob job) => _serialize(() {
    if (job.status != PluginJobStatus.pending || job.leaseId != null) {
      throw ArgumentError.value(job, 'job', 'New jobs must be pending.');
    }
    if (_jobs.containsKey(job.id)) {
      throw StateError('Plugin job already exists: ${job.id}');
    }
    _validateJson(job.payload);
    _jobs[job.id] = job;
  });

  @override
  Future<PluginJob?> get(String id) => _serialize(() => _jobs[id]);

  @override
  Future<bool> cancel(
    String id, {
    required String pluginId,
    required String agentId,
    required String sessionId,
  }) => _serialize(() {
    final current = _jobs[id];
    if (current == null ||
        current.pluginId != pluginId ||
        current.agentId != agentId ||
        current.sessionId != sessionId ||
        current.status != PluginJobStatus.pending) {
      return false;
    }
    _jobs[id] = current.withLifecycle(status: PluginJobStatus.cancelled);
    return true;
  });

  @override
  Future<PluginJob?> claimNext({
    required DateTime now,
    required String leaseId,
    Duration leaseDuration = const Duration(minutes: 5),
  }) => _serialize(() {
    final candidates =
        _jobs.values
            .where(
              (job) =>
                  !job.dueAt.isAfter(now) &&
                  (job.status == PluginJobStatus.pending ||
                      (job.status == PluginJobStatus.running &&
                          job.leaseExpiresAt?.isAfter(now) == false)),
            )
            .toList(growable: false)
          ..sort((left, right) {
            final dueOrder = left.dueAt.compareTo(right.dueAt);
            return dueOrder != 0 ? dueOrder : left.id.compareTo(right.id);
          });
    if (candidates.isEmpty) return null;
    final claimed = candidates.first.withLifecycle(
      status: PluginJobStatus.running,
      leaseId: leaseId,
      leaseExpiresAt: now.add(leaseDuration),
    );
    _jobs[claimed.id] = claimed;
    return claimed;
  });

  @override
  Future<void> release(String id, {required String leaseId}) =>
      _resolve(id, leaseId: leaseId, status: PluginJobStatus.pending);

  @override
  Future<void> complete(String id, {required String leaseId}) =>
      _resolve(id, leaseId: leaseId, status: PluginJobStatus.completed);

  @override
  Future<void> fail(
    String id, {
    required String leaseId,
    required String error,
  }) => _resolve(
    id,
    leaseId: leaseId,
    status: PluginJobStatus.failed,
    error: error,
  );

  Future<void> _resolve(
    String id, {
    required String leaseId,
    required PluginJobStatus status,
    String? error,
  }) => _serialize(() {
    final current = _jobs[id];
    if (current == null) throw StateError('Plugin job not found: $id');
    if (current.status != PluginJobStatus.running ||
        current.leaseId != leaseId) {
      throw PluginJobLeaseConflict(id);
    }
    _jobs[id] = current.withLifecycle(status: status, error: error);
  });

  Future<T> _serialize<T>(FutureOr<T> Function() operation) {
    final previous = _tail;
    final released = Completer<void>();
    _tail = released.future;
    return previous.then((_) async {
      try {
        return await operation();
      } finally {
        released.complete();
      }
    });
  }
}

void _checkRevision(String key, int expected, int actual) {
  if (expected != actual) {
    throw PluginStateConflict(
      key: key,
      expectedRevision: expected,
      actualRevision: actual,
    );
  }
}

Map<String, PluginStateEntry> _copyEntries(
  Map<String, PluginStateEntry> values,
) => <String, PluginStateEntry>{
  for (final entry in values.entries) entry.key: _copyEntry(entry.value)!,
};

PluginStateEntry? _copyEntry(PluginStateEntry? entry) => entry == null
    ? null
    : PluginStateEntry(revision: entry.revision, value: _copyJson(entry.value));

void _validateJson(Object? value) {
  if (!_isJsonValue(value)) {
    throw const FormatException('Plugin state must be JSON-compatible.');
  }
}

bool _isJsonValue(Object? value) => switch (value) {
  null || String() || bool() || int() => true,
  double() => value.isFinite,
  List<Object?>() => value.every(_isJsonValue),
  Map<String, Object?>() => value.values.every(_isJsonValue),
  _ => false,
};

String _scopeKey(PluginStateScope scope) =>
    jsonEncode(<Object?>[scope.pluginId, scope.kind.name, scope.ownerId]);

Object? _copyJson(Object? value) {
  _validateJson(value);
  return jsonDecode(jsonEncode(value));
}
