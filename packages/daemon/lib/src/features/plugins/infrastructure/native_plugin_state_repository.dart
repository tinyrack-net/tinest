import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:daemon/src/features/plugins/infrastructure/plugin_ports.dart';
import 'package:path/path.dart' as p;
import 'package:protocol/protocol.dart';

/// Atomic v5 persistence for grants, scoped JSON state, and scheduler jobs.
///
/// `stateDirectory` is the product state root; this adapter writes only
/// `<stateDirectory>/v5/plugin-state.json` and never reads an older namespace.
final class NativePluginStateRepository
    implements AgentPluginGrantStore, PluginStateStore, PluginJobStore {
  /// Creates the repository below a daemon state root.
  new(String stateDirectory)
    : _file = File(
        p.join(
          p.normalize(p.absolute(stateDirectory)),
          'v5',
          'plugin-state.json',
        ),
      );

  static const int _schemaVersion = 5;
  static const int _maximumErrorLength = 2048;

  final File _file;
  final StreamController<AgentPluginGrantDto> _revocations =
      StreamController<AgentPluginGrantDto>.broadcast(sync: true);
  final Set<AgentPluginGrantDto> _grants = <AgentPluginGrantDto>{};
  final Map<String, _StateNamespace> _state = <String, _StateNamespace>{};
  final Map<String, PluginJob> _jobs = <String, PluginJob>{};
  Future<void> _tail = Future<void>.value();
  bool _loaded = false;

  @override
  Stream<AgentPluginGrantDto> get revocations => _revocations.stream;

  @override
  Future<List<AgentPluginGrantDto>> list(String agentId) => _read(() {
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
  });

  @override
  Future<bool> isGranted(AgentPluginGrantDto grant) =>
      _read(() => _grants.contains(grant));

  @override
  Future<void> grant(AgentPluginGrantDto grant) => _write(() {
    _validateGrant(grant);
    _grants.add(grant);
  });

  @override
  Future<void> revoke(AgentPluginGrantDto grant) async {
    _validateGrant(grant);
    final removed = await _write(() => _grants.remove(grant));
    if (removed) _revocations.add(grant);
  }

  @override
  Future<PluginStateEntry?> read(PluginStateScope scope, String key) =>
      _read(() {
        _validateScope(scope);
        _validateStateKey(key);
        return _copyEntry(_state[_scopeKey(scope)]?.values[key]);
      });

  @override
  Future<PluginStateEntry> compareAndSet(
    PluginStateScope scope,
    String key, {
    required int expectedRevision,
    required Object? value,
  }) => _write(() {
    _validateScope(scope);
    _validateStateKey(key);
    _validateExpectedRevision(expectedRevision);
    _validateJson(value);
    final namespace = _state.putIfAbsent(
      _scopeKey(scope),
      () => _StateNamespace(scope),
    );
    final actualRevision = namespace.values[key]?.revision ?? 0;
    _checkRevision(key, expectedRevision, actualRevision);
    final entry = PluginStateEntry(
      revision: actualRevision + 1,
      value: _copyJson(value),
    );
    namespace.values[key] = entry;
    return _copyEntry(entry)!;
  });

  @override
  Future<Map<String, PluginStateEntry>> transaction(
    PluginStateScope scope,
    List<PluginStateMutation> Function(Map<String, PluginStateEntry> values)
    buildMutations,
  ) => _write(() {
    _validateScope(scope);
    final namespace = _state.putIfAbsent(
      _scopeKey(scope),
      () => _StateNamespace(scope),
    );
    final mutations = buildMutations(
      Map<String, PluginStateEntry>.unmodifiable(
        _copyEntries(namespace.values),
      ),
    );
    final mutatedKeys = <String>{};
    for (final mutation in mutations) {
      _validateStateKey(mutation.key);
      _validateExpectedRevision(mutation.expectedRevision);
      if (!mutatedKeys.add(mutation.key)) {
        throw StateError('A transaction may mutate each key only once.');
      }
      final actualRevision = namespace.values[mutation.key]?.revision ?? 0;
      _checkRevision(mutation.key, mutation.expectedRevision, actualRevision);
      if (!mutation.remove) _validateJson(mutation.value);
    }
    for (final mutation in mutations) {
      if (mutation.remove) {
        namespace.values.remove(mutation.key);
      } else {
        namespace.values[mutation.key] = PluginStateEntry(
          revision: mutation.expectedRevision + 1,
          value: _copyJson(mutation.value),
        );
      }
    }
    return _copyEntries(namespace.values);
  });

  @override
  Future<void> enqueue(PluginJob job) => _write(() {
    _validateJob(job, isNew: true);
    if (_jobs.containsKey(job.id)) {
      throw StateError('Plugin job already exists: ${job.id}');
    }
    _jobs[job.id] = _copyJob(job);
  });

  @override
  Future<PluginJob?> get(String id) => _read(() {
    _validateNonEmpty(id, 'Plugin job ID');
    final job = _jobs[id];
    return job == null ? null : _copyJob(job);
  });

  @override
  Future<bool> cancel(
    String id, {
    required String pluginId,
    required String agentId,
    required String sessionId,
  }) => _write(() {
    _validateNonEmpty(id, 'Plugin job ID');
    _validatePluginId(pluginId);
    _validateNonEmpty(agentId, 'Agent ID');
    _validateNonEmpty(sessionId, 'Session ID');
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
  }) => _write(() {
    _validateNonEmpty(leaseId, 'Plugin job lease ID');
    if (leaseDuration <= Duration.zero) {
      throw ArgumentError.value(
        leaseDuration,
        'leaseDuration',
        'Lease duration must be positive.',
      );
    }
    final normalizedNow = now.toUtc();
    final candidates =
        _jobs.values
            .where(
              (job) =>
                  !job.dueAt.isAfter(normalizedNow) &&
                  (job.status == PluginJobStatus.pending ||
                      (job.status == PluginJobStatus.running &&
                          job.leaseExpiresAt?.isAfter(normalizedNow) == false)),
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
      leaseExpiresAt: normalizedNow.add(leaseDuration),
    );
    _jobs[claimed.id] = claimed;
    return _copyJob(claimed);
  });

  @override
  Future<void> release(String id, {required String leaseId}) =>
      _resolveJob(id, leaseId: leaseId, status: PluginJobStatus.pending);

  @override
  Future<void> complete(String id, {required String leaseId}) =>
      _resolveJob(id, leaseId: leaseId, status: PluginJobStatus.completed);

  @override
  Future<void> fail(
    String id, {
    required String leaseId,
    required String error,
  }) => _resolveJob(
    id,
    leaseId: leaseId,
    status: PluginJobStatus.failed,
    error: error.length <= _maximumErrorLength
        ? error
        : error.substring(0, _maximumErrorLength),
  );

  Future<void> _resolveJob(
    String id, {
    required String leaseId,
    required PluginJobStatus status,
    String? error,
  }) => _write(() {
    final current = _jobs[id];
    if (current == null) throw StateError('Plugin job not found: $id');
    if (current.status != PluginJobStatus.running ||
        current.leaseId != leaseId) {
      throw PluginJobLeaseConflict(id);
    }
    _jobs[id] = current.withLifecycle(status: status, error: error);
  });

  Future<T> _read<T>(T Function() operation) => _serialize(() {
    _ensureLoaded();
    return operation();
  });

  Future<T> _write<T>(T Function() operation) => _serialize(() {
    _ensureLoaded();
    final snapshot = _snapshot();
    try {
      final result = operation();
      _persist();
      return result;
    } catch (_) {
      _restore(snapshot);
      rethrow;
    }
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

  void _ensureLoaded() {
    if (_loaded) return;
    if (!_file.existsSync()) {
      _loaded = true;
      return;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(_file.readAsStringSync());
    } on FormatException catch (error) {
      throw FormatException('Invalid v5 plugin state: ${error.message}');
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['schemaVersion'] != _schemaVersion) {
      throw const FormatException('Invalid v5 plugin state schema.');
    }
    final grants = _requiredList(decoded, 'grants');
    final state = _requiredList(decoded, 'state');
    final jobs = _requiredList(decoded, 'jobs');
    final parsedGrants = <AgentPluginGrantDto>{};
    final parsedState = <String, _StateNamespace>{};
    final parsedJobs = <String, PluginJob>{};
    for (final raw in grants) {
      final map = _requiredJsonMap(raw, 'grant');
      final grant = AgentPluginGrantDto(
        agentId: _requiredString(map, 'agentId'),
        pluginId: _requiredString(map, 'pluginId'),
        capability: _requiredString(map, 'capability'),
      );
      _validateGrant(grant);
      if (!parsedGrants.add(grant)) {
        throw const FormatException('Duplicate v5 plugin grant.');
      }
    }
    for (final raw in state) {
      final map = _requiredJsonMap(raw, 'state namespace');
      final scope = _decodeScope(map);
      final namespaceKey = _scopeKey(scope);
      if (parsedState.containsKey(namespaceKey)) {
        throw const FormatException('Duplicate v5 plugin state namespace.');
      }
      final namespace = _StateNamespace(scope);
      for (final rawEntry in _requiredList(map, 'entries')) {
        final entryMap = _requiredJsonMap(rawEntry, 'state entry');
        final key = _requiredString(entryMap, 'key');
        _validateStateKey(key);
        final revision = entryMap['revision'];
        if (revision is! int || revision <= 0) {
          throw const FormatException(
            'Plugin state revision must be a positive integer.',
          );
        }
        if (!entryMap.containsKey('value')) {
          throw const FormatException('Plugin state entry requires a value.');
        }
        final value = entryMap['value'];
        _validateJson(value);
        if (namespace.values.containsKey(key)) {
          throw FormatException('Duplicate plugin state key: $key');
        }
        namespace.values[key] = PluginStateEntry(
          revision: revision,
          value: _copyJson(value),
        );
      }
      parsedState[namespaceKey] = namespace;
    }
    for (final raw in jobs) {
      final job = _decodeJob(_requiredJsonMap(raw, 'job'));
      if (parsedJobs.containsKey(job.id)) {
        throw FormatException('Duplicate plugin job: ${job.id}');
      }
      parsedJobs[job.id] = job;
    }
    _grants
      ..clear()
      ..addAll(parsedGrants);
    _state
      ..clear()
      ..addAll(parsedState);
    _jobs
      ..clear()
      ..addAll(parsedJobs);
    _loaded = true;
  }

  void _persist() {
    final grants = _grants.toList(growable: false)
      ..sort((left, right) => _grantKey(left).compareTo(_grantKey(right)));
    final namespaces = _state.values.toList(growable: false)
      ..sort(
        (left, right) =>
            _scopeKey(left.scope).compareTo(_scopeKey(right.scope)),
      );
    final jobs = _jobs.values.toList(growable: false)
      ..sort((left, right) => left.id.compareTo(right.id));
    final document = <String, Object?>{
      'schemaVersion': _schemaVersion,
      'grants': <Object?>[
        for (final grant in grants)
          <String, Object?>{
            'agentId': grant.agentId,
            'pluginId': grant.pluginId,
            'capability': grant.capability,
          },
      ],
      'state': <Object?>[
        for (final namespace in namespaces)
          <String, Object?>{
            'pluginId': namespace.scope.pluginId,
            'kind': namespace.scope.kind.name,
            'ownerId': namespace.scope.ownerId,
            'entries': <Object?>[
              for (final entry
                  in (namespace.values.entries.toList()
                    ..sort((left, right) => left.key.compareTo(right.key))))
                <String, Object?>{
                  'key': entry.key,
                  'revision': entry.value.revision,
                  'value': entry.value.value,
                },
            ],
          },
      ],
      'jobs': <Object?>[for (final job in jobs) _encodeJob(job)],
    };
    _file.parent.createSync(recursive: true);
    final temporary = File('${_file.path}.$pid.tmp');
    try {
      if (temporary.existsSync()) temporary.deleteSync();
      temporary
        ..writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(document)}\n',
          flush: true,
        )
        ..renameSync(_file.path);
    } finally {
      if (temporary.existsSync()) temporary.deleteSync();
    }
  }

  _RepositorySnapshot _snapshot() => _RepositorySnapshot(
    grants: <AgentPluginGrantDto>{..._grants},
    state: <String, _StateNamespace>{
      for (final entry in _state.entries) entry.key: entry.value.copy(),
    },
    jobs: <String, PluginJob>{
      for (final entry in _jobs.entries) entry.key: _copyJob(entry.value),
    },
  );

  void _restore(_RepositorySnapshot snapshot) {
    _grants
      ..clear()
      ..addAll(snapshot.grants);
    _state
      ..clear()
      ..addAll(snapshot.state);
    _jobs
      ..clear()
      ..addAll(snapshot.jobs);
  }
}

final class _StateNamespace {
  new(this.scope);

  final PluginStateScope scope;
  final Map<String, PluginStateEntry> values = <String, PluginStateEntry>{};

  _StateNamespace copy() {
    final result = _StateNamespace(scope);
    result.values.addAll(_copyEntries(values));
    return result;
  }
}

final class _RepositorySnapshot {
  const new({required this.grants, required this.state, required this.jobs});

  final Set<AgentPluginGrantDto> grants;
  final Map<String, _StateNamespace> state;
  final Map<String, PluginJob> jobs;
}

PluginStateScope _decodeScope(Map<String, dynamic> map) {
  final pluginId = _requiredString(map, 'pluginId');
  final ownerId = map['ownerId'];
  if (ownerId != null && ownerId is! String) {
    throw const FormatException('Plugin state ownerId must be a string.');
  }
  final kindName = _requiredString(map, 'kind');
  final kind = PluginStateScopeKind.values
      .where((candidate) => candidate.name == kindName)
      .firstOrNull;
  if (kind == null) {
    throw FormatException('Unsupported plugin state scope: $kindName');
  }
  final scope = switch (kind) {
    PluginStateScopeKind.plugin => PluginStateScope.plugin(pluginId: pluginId),
    PluginStateScopeKind.agent => PluginStateScope.agent(
      pluginId: pluginId,
      agentId: _requiredOwnerId(ownerId, kindName),
    ),
    PluginStateScopeKind.session => PluginStateScope.session(
      pluginId: pluginId,
      sessionId: _requiredOwnerId(ownerId, kindName),
    ),
    PluginStateScopeKind.workspace => PluginStateScope.workspace(
      pluginId: pluginId,
      workspaceId: _requiredOwnerId(ownerId, kindName),
    ),
  };
  _validateScope(scope);
  return scope;
}

PluginJob _decodeJob(Map<String, dynamic> map) {
  final statusName = _requiredString(map, 'status');
  final status = PluginJobStatus.values
      .where((candidate) => candidate.name == statusName)
      .firstOrNull;
  if (status == null) {
    throw FormatException('Unsupported plugin job status: $statusName');
  }
  final job = PluginJob(
    id: _requiredString(map, 'id'),
    pluginId: _requiredString(map, 'pluginId'),
    executionRevisionHash: _requiredString(map, 'executionRevisionHash'),
    bindingId: _requiredString(map, 'bindingId'),
    payload: _requiredJsonMap(map['payload'], 'job payload'),
    dueAt: _requiredDateTime(map, 'dueAt'),
    agentId: _optionalString(map, 'agentId'),
    sessionId: _optionalString(map, 'sessionId'),
    status: status,
    leaseId: _optionalString(map, 'leaseId'),
    leaseExpiresAt: _optionalDateTime(map, 'leaseExpiresAt'),
    error: _optionalString(map, 'error'),
  );
  _validateJob(job, isNew: false);
  return job;
}

Map<String, Object?> _encodeJob(PluginJob job) => <String, Object?>{
  'id': job.id,
  'pluginId': job.pluginId,
  'executionRevisionHash': job.executionRevisionHash,
  'bindingId': job.bindingId,
  'payload': job.payload,
  'dueAt': job.dueAt.toUtc().toIso8601String(),
  'agentId': job.agentId,
  'sessionId': job.sessionId,
  'status': job.status.name,
  'leaseId': job.leaseId,
  'leaseExpiresAt': job.leaseExpiresAt?.toUtc().toIso8601String(),
  'error': job.error,
};

void _validateGrant(AgentPluginGrantDto grant) {
  _validateNonEmpty(grant.agentId, 'Agent ID');
  _validatePluginId(grant.pluginId);
  _validateCapability(grant.capability);
}

void _validateScope(PluginStateScope scope) {
  _validatePluginId(scope.pluginId);
  if (scope.kind == PluginStateScopeKind.plugin) {
    if (scope.ownerId != null) {
      throw const FormatException('Plugin-global state cannot have an owner.');
    }
  } else {
    _validateNonEmpty(scope.ownerId, 'Plugin state owner ID');
  }
}

void _validateJob(PluginJob job, {required bool isNew}) {
  _validateNonEmpty(job.id, 'Plugin job ID');
  _validatePluginId(job.pluginId);
  _validateNonEmpty(job.executionRevisionHash, 'Plugin execution revision');
  if (!RegExp(r'^[a-z][a-z0-9_-]{0,63}$').hasMatch(job.bindingId)) {
    throw const FormatException('Invalid plugin job binding ID.');
  }
  _validateJson(job.payload);
  if (job.agentId case final agentId?) _validateNonEmpty(agentId, 'Agent ID');
  if (job.sessionId case final sessionId?) {
    _validateNonEmpty(sessionId, 'Session ID');
  }
  if (isNew &&
      (job.status != PluginJobStatus.pending ||
          job.leaseId != null ||
          job.leaseExpiresAt != null)) {
    throw ArgumentError.value(job, 'job', 'New jobs must be pending.');
  }
  final isRunning = job.status == PluginJobStatus.running;
  if (isRunning != (job.leaseId != null) ||
      isRunning != (job.leaseExpiresAt != null)) {
    throw const FormatException(
      'Only running plugin jobs may have a complete lease.',
    );
  }
  if (job.error != null && job.status != PluginJobStatus.failed) {
    throw const FormatException('Only failed plugin jobs may have an error.');
  }
}

void _validatePluginId(String value) {
  if (!RegExp(r'^[a-z][a-z0-9]*(?:\.[a-z][a-z0-9]*)+$').hasMatch(value)) {
    throw FormatException('Invalid plugin ID: $value');
  }
}

void _validateCapability(String value) {
  if (!RegExp(r'^[a-z][a-z0-9]*(?:\.[a-z][a-z0-9_]*)+$').hasMatch(value)) {
    throw FormatException('Invalid plugin capability: $value');
  }
}

void _validateStateKey(String value) {
  _validateNonEmpty(value, 'Plugin state key');
  if (utf8.encode(value).length > 256) {
    throw const FormatException('Plugin state key exceeds 256 UTF-8 bytes.');
  }
}

void _validateExpectedRevision(int value) {
  if (value < 0) {
    throw ArgumentError.value(
      value,
      'expectedRevision',
      'Expected revision cannot be negative.',
    );
  }
}

void _validateNonEmpty(String? value, String field) {
  if (value == null || value.trim().isEmpty) {
    throw FormatException('$field must be a non-empty string.');
  }
}

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

Object? _copyJson(Object? value) {
  _validateJson(value);
  return jsonDecode(jsonEncode(value));
}

PluginJob _copyJob(PluginJob job) => PluginJob(
  id: job.id,
  pluginId: job.pluginId,
  executionRevisionHash: job.executionRevisionHash,
  bindingId: job.bindingId,
  payload: (_copyJson(job.payload)! as Map).cast<String, dynamic>(),
  dueAt: job.dueAt.toUtc(),
  agentId: job.agentId,
  sessionId: job.sessionId,
  status: job.status,
  leaseId: job.leaseId,
  leaseExpiresAt: job.leaseExpiresAt?.toUtc(),
  error: job.error,
);

Map<String, PluginStateEntry> _copyEntries(
  Map<String, PluginStateEntry> values,
) => <String, PluginStateEntry>{
  for (final entry in values.entries) entry.key: _copyEntry(entry.value)!,
};

PluginStateEntry? _copyEntry(PluginStateEntry? entry) => entry == null
    ? null
    : PluginStateEntry(revision: entry.revision, value: _copyJson(entry.value));

void _checkRevision(String key, int expected, int actual) {
  if (expected != actual) {
    throw PluginStateConflict(
      key: key,
      expectedRevision: expected,
      actualRevision: actual,
    );
  }
}

String _scopeKey(PluginStateScope scope) =>
    jsonEncode(<Object?>[scope.pluginId, scope.kind.name, scope.ownerId]);

String _grantKey(AgentPluginGrantDto grant) =>
    jsonEncode(<String>[grant.agentId, grant.pluginId, grant.capability]);

List<dynamic> _requiredList(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! List<dynamic>) throw FormatException('$key must be a list.');
  return value;
}

Map<String, dynamic> _requiredJsonMap(Object? value, String field) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('$field must be a JSON object.');
  }
  return value;
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = _optionalString(map, key);
  if (value == null) throw FormatException('$key must be a non-empty string.');
  return value;
}

String? _optionalString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

DateTime _requiredDateTime(Map<String, dynamic> map, String key) {
  final value = _optionalDateTime(map, key);
  if (value == null) throw FormatException('$key must be an ISO timestamp.');
  return value;
}

DateTime? _optionalDateTime(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('$key must be an ISO timestamp.');
  return DateTime.tryParse(value)?.toUtc() ??
      (throw FormatException('$key must be an ISO timestamp.'));
}

String _requiredOwnerId(Object? value, String kind) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$kind plugin state requires an ownerId.');
  }
  return value;
}
