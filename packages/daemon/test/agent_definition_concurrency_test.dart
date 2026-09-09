import 'dart:async';

import 'package:daemon/src/features/agents/infrastructure/agent_definitions.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  test('a stale scan cannot remove a definition created behind it', () async {
    final files = _ControllableAgentDefinitionFiles();
    final store = FileAgentDefinitionStore.withFiles(files);
    addTearDown(store.close);
    await store.initialize();
    final tinest = (await store.get('tinest'))!;

    files.pauseNextActiveScan();
    final staleReload = store.reload();
    await files.scanStarted;
    final create = store.create(
      'reviewer',
      tinest.copyWith(
        id: 'reviewer',
        name: 'Reviewer',
        description: '',
        mode: AgentMode.subagent,
        callableAgentIds: const <String>[],
        sourcePath: '',
        contentHash: '',
        isBuiltIn: false,
      ),
    );

    files.releaseScan();
    await staleReload;
    await create;

    expect(files.activeDocuments, contains('reviewer'));
    expect(
      (await store.list()).map((definition) => definition.id),
      contains('reviewer'),
    );
  });

  test('watch reloads are debounced and drained before close', () async {
    final files = _ControllableAgentDefinitionFiles();
    final store = FileAgentDefinitionStore.withFiles(
      files,
      watchDebounce: const Duration(milliseconds: 1),
    );
    await store.initialize();
    final initialScans = files.activeScanCount;

    // Waiting for the reload the debounce timer schedules keeps the assertion
    // deterministic; a fixed delay races the timer whenever the machine is
    // busy. The three emits share one microtask, so no timer can fire between
    // them and they must coalesce into exactly one scan.
    final reloaded = store.changes.first;
    files
      ..emitChange()
      ..emitChange()
      ..emitChange();
    await reloaded;
    await store.close();

    expect(files.activeScanCount, initialScans + 1);
    expect(files.closed, isTrue);
  });

  test('model prefix rewrites active and archived definitions', () async {
    final files = _ControllableAgentDefinitionFiles();
    final store = FileAgentDefinitionStore.withFiles(files);
    addTearDown(store.close);
    await store.initialize();
    final tinest = (await store.get('tinest'))!;
    await store.create('active', _fixedAgent(tinest, 'active'));
    await store.create('archived', _fixedAgent(tinest, 'archived'));
    await store.archive('archived');

    await store.rewriteModelPrefix('openai', 'openai-new');

    expect(
      (await store.get('active'))!.model.modelId,
      'openai-new/model/active',
    );
    expect(
      (await store.resolve('archived'))!.model.modelId,
      'openai-new/model/archived',
    );
  });

  test(
    'model prefix rewrite restores completed files after a failure',
    () async {
      final files = _ControllableAgentDefinitionFiles();
      final store = FileAgentDefinitionStore.withFiles(files);
      addTearDown(store.close);
      await store.initialize();
      final tinest = (await store.get('tinest'))!;
      await store.create('active', _fixedAgent(tinest, 'active'));
      await store.create('archived', _fixedAgent(tinest, 'archived'));
      await store.archive('archived');
      final activeBefore = files.activeSource('active');
      final archivedBefore = files.archivedSource('archived');
      files.failNextArchivedWrite = true;

      await expectLater(
        store.rewriteModelPrefix('openai', 'openai-new'),
        throwsA(isA<StateError>()),
      );

      expect(files.activeSource('active'), activeBefore);
      expect(files.archivedSource('archived'), archivedBefore);
      await store.reload();
      expect((await store.get('active'))!.model.modelId, 'openai/model/active');
      expect(
        (await store.resolve('archived'))!.model.modelId,
        'openai/model/archived',
      );
    },
  );
}

AgentDefinitionDto _fixedAgent(AgentDefinitionDto tinest, String id) =>
    tinest.copyWith(
      id: id,
      name: id,
      description: '',
      mode: AgentMode.subagent,
      model: AgentModelSelectionDto(
        source: AgentModelSource.fixed,
        modelId: 'openai/model/$id',
      ),
      callableAgentIds: const <String>[],
      sourcePath: '',
      contentHash: '',
      isBuiltIn: false,
    );

final class _ControllableAgentDefinitionFiles implements AgentDefinitionFiles {
  final StreamController<void> _changes = StreamController<void>.broadcast();
  final Map<String, String> _active = <String, String>{};
  final Map<String, String> _archived = <String, String>{};
  Completer<void>? _scanStarted;
  Completer<void>? _scanRelease;

  int activeScanCount = 0;
  bool closed = false;
  bool failNextArchivedWrite = false;

  Iterable<String> get activeDocuments => _active.keys;

  String? activeSource(String id) => _active[id];

  String? archivedSource(String id) => _archived[id];

  Future<void> get scanStarted => _scanStarted!.future;

  void pauseNextActiveScan() {
    _scanStarted = Completer<void>();
    _scanRelease = Completer<void>();
  }

  void releaseScan() {
    _scanRelease!.complete();
    _scanRelease = null;
  }

  void emitChange() => _changes.add(null);

  @override
  Stream<void> get changes => _changes.stream;

  @override
  String activePath(String id) => '/agents/$id.md';

  @override
  Future<void> archive(String id) async {
    _archived[id] = _active.remove(id)!;
    emitChange();
  }

  @override
  String archivePath(String id) => '/agents/.archive/$id.md';

  @override
  Future<void> close() async {
    closed = true;
    await _changes.close();
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<List<AgentDefinitionDocument>> readActive() async {
    activeScanCount += 1;
    final snapshot = Map<String, String>.of(_active);
    final started = _scanStarted;
    final release = _scanRelease;
    if (started != null && release != null) {
      _scanStarted = null;
      started.complete();
      await release.future;
    }
    return <AgentDefinitionDocument>[
      for (final entry in snapshot.entries)
        AgentDefinitionDocument(
          id: entry.key,
          sourcePath: activePath(entry.key),
          source: entry.value,
        ),
    ];
  }

  @override
  Future<List<AgentDefinitionDocument>> readArchived() async =>
      <AgentDefinitionDocument>[
        for (final entry in _archived.entries)
          AgentDefinitionDocument(
            id: entry.key,
            sourcePath: archivePath(entry.key),
            source: entry.value,
          ),
      ];

  @override
  Future<void> writeActive(String id, String source) async {
    _active[id] = source;
    emitChange();
  }

  @override
  Future<void> writeArchived(String id, String source) async {
    if (failNextArchivedWrite) {
      failNextArchivedWrite = false;
      throw StateError('planned archived write failure');
    }
    _archived[id] = source;
    emitChange();
  }
}
