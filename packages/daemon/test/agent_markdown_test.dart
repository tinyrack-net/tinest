import 'dart:async';
import 'dart:io';

import 'package:daemon/src/features/agents/infrastructure/agent_definitions.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  const source = '''
---
# User comment must survive GUI edits.
version: 5
name: Reviewer
description: Reviews code
mode: subagent
model:
  source: session
driver: acme.driver/main
extensions: []
tools:
  - acme.files/read
  - acme.future/tool
pluginSettings: {}
callableAgents: []
customField: preserved
---

Review the requested code without modifying it.
''';

  test('decodes a document whose path is not a usable file URI', () {
    // Validation of an unsaved document passes a synthetic marker, and
    // Windows rejects its angle brackets in a file URI. The marker only
    // labels parse errors, so it must never fail the parse itself.
    final parsed = const AgentMarkdownCodec().decode(
      id: 'candidate',
      sourcePath: '<validation>/candidate.md',
      source: source,
    );

    expect(parsed.id, 'candidate');
    expect(parsed.sourcePath, '<validation>/candidate.md');
  });

  test('parses frontmatter and markdown body into a typed definition', () {
    final parsed = const AgentMarkdownCodec().decode(
      id: 'reviewer',
      sourcePath: '/config/agents/reviewer.md',
      source: source,
    );

    expect(parsed.id, 'reviewer');
    expect(parsed.mode, AgentMode.subagent);
    expect(parsed.model.source, AgentModelSource.session);
    expect(parsed.toolIds, <String>['acme.files/read', 'acme.future/tool']);
    expect(parsed.prompt, contains('Review the requested code'));
    expect(parsed.contentHash, isNotEmpty);
    expect(
      const AgentMarkdownCodec()
          .decode(
            id: 'reviewer',
            sourcePath: '/config/agents/reviewer.md',
            source: '\n\n$source',
          )
          .name,
      'Reviewer',
    );
    expect(
      const AgentFileConflict('current-hash').toString(),
      'agent_file_conflict: current-hash',
    );
  });

  test('a zero-tool Agent remains a valid zero-tool harness', () {
    const codec = AgentMarkdownCodec();
    final zeroTools = codec.decode(
      id: 'reviewer',
      sourcePath: '/config/agents/reviewer.md',
      source: source.replaceFirst(
        'tools:\n  - acme.files/read\n  - acme.future/tool',
        'tools: []',
      ),
    );

    expect(zeroTools.toolIds, isEmpty);
    expect(
      codec
          .decode(
            id: 'reviewer',
            sourcePath: '/config/agents/reviewer.md',
            source: codec.encodeNew(zeroTools),
          )
          .toolIds,
      isEmpty,
    );
  });

  test('updates known fields while preserving comments and unknown fields', () {
    const codec = AgentMarkdownCodec();
    final parsed = codec.decode(
      id: 'reviewer',
      sourcePath: '/config/agents/reviewer.md',
      source: source,
    );
    final updated = codec.encodeUpdate(
      originalSource: source,
      definition: parsed.copyWith(
        name: 'Security Reviewer',
        prompt: 'Audit security boundaries.',
      ),
    );

    expect(updated, contains('# User comment must survive GUI edits.'));
    expect(updated, contains('customField: preserved'));
    expect(updated, contains('name: Security Reviewer'));
    expect(updated, endsWith('Audit security boundaries.\n'));
  });

  test('rejects fixed model settings without provider and model IDs', () {
    expect(
      () => const AgentMarkdownCodec().decode(
        id: 'broken',
        sourcePath: '/config/agents/broken.md',
        source: source.replaceFirst('session', 'fixed'),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('accepts an intentionally empty agent description', () {
    final parsed = const AgentMarkdownCodec().decode(
      id: 'reviewer',
      sourcePath: '/config/agents/reviewer.md',
      source: source.replaceFirst(
        'description: Reviews code',
        'description: ""',
      ),
    );

    expect(parsed.description, isEmpty);
  }, tags: const <String>['feature_test__agent_definition_management__unit']);

  test('rejects every malformed Markdown boundary with typed diagnostics', () {
    const codec = AgentMarkdownCodec();
    final malformed = <String>[
      'name: no-frontmatter',
      '---\nname: unclosed',
      '---\n- not\n- a-map\n---\n',
      source.replaceFirst('version: 5', 'version: 4'),
      source.replaceFirst('mode: subagent', 'mode: unknown'),
      source
          .replaceFirst('mode: subagent', 'mode: subagent')
          .replaceFirst('callableAgents: []', 'callableAgents: [tinest]'),
      source.replaceFirst('model:\n  source: session', 'model: invalid'),
      source.replaceFirst('name: Reviewer', 'name: ""'),
      source.replaceFirst('name: Reviewer\n', ''),
      source.replaceFirst(
        'tools:\n  - acme.files/read\n  - acme.future/tool',
        'tools: 4',
      ),
      source.replaceFirst('version: 5', 'version: one'),
      source.replaceFirst('driver: acme.driver/main', 'driver: invalid'),
      source.replaceFirst('extensions: []', 'extensions: [Acme.Plan]'),
      source.replaceFirst('pluginSettings: {}', 'pluginSettings: []'),
      source.replaceFirst('name: Reviewer', '1: invalid-key'),
    ];

    for (final markdown in malformed) {
      expect(
        () => codec.decode(
          id: 'reviewer',
          sourcePath: '/config/agents/reviewer.md',
          source: markdown,
        ),
        throwsA(isA<FormatException>()),
      );
    }
    expect(
      () => codec.decode(
        id: '../escape',
        sourcePath: '/config/agents/escape.md',
        source: source,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'file store creates tinest, detects conflicts, and archives custom agents',
    () async {
      final directory = await Directory.systemTemp.createTemp('tinest-agents-');
      addTearDown(() => directory.delete(recursive: true));
      final store = FileAgentDefinitionStore(directory.path);
      addTearDown(store.close);

      await store.initialize();
      final tinest = await store.get('tinest');
      expect(tinest, isNotNull);
      expect(tinest!.isBuiltIn, isTrue);

      final reviewer = tinest.copyWith(
        id: 'reviewer',
        name: 'Reviewer',
        mode: AgentMode.subagent,
        callableAgentIds: const <String>[],
        sourcePath: '',
        isBuiltIn: false,
      );
      final created = await store.create('reviewer', reviewer);
      expect(created.sourcePath, endsWith('reviewer.md'));
      await expectLater(
        store.update(
          created.copyWith(name: 'Changed'),
          expectedContentHash: 'stale-hash',
        ),
        throwsA(isA<AgentFileConflict>()),
      );

      await store.archive('reviewer');
      expect(await store.get('reviewer'), isNull);
      expect(await store.resolve('reviewer'), isNotNull);
      expect((await store.resolve('reviewer'))!.isArchived, isTrue);

      await expectLater(
        store.create(
          'invalid',
          reviewer.copyWith(
            id: 'invalid',
            name: '',
            sourcePath: '',
            contentHash: '',
          ),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(File('${directory.path}/agents/invalid.md').existsSync(), isFalse);
    },
  );

  test(
    'reload retains the last valid definition after malformed external edit',
    () async {
      final directory = await Directory.systemTemp.createTemp('tinest-agents-');
      addTearDown(() => directory.delete(recursive: true));
      final store = FileAgentDefinitionStore(directory.path);
      addTearDown(store.close);
      await store.initialize();
      final tinest = (await store.get('tinest'))!;

      await File(tinest.sourcePath).writeAsString('---\ninvalid: [\n---\n');
      await store.reload();

      final stale = (await store.get('tinest'))!;
      expect(stale.isStale, isTrue);
      expect(stale.diagnostics, isNotEmpty);
      expect(stale.diagnostics.single.line, isNotNull);
      expect(stale.diagnostics.single.column, isNotNull);
      expect(stale.name, tinest.name);
    },
  );

  test(
    'valid external edits reload while symlinked definitions are ignored',
    () async {
      final directory = await Directory.systemTemp.createTemp('tinest-agents-');
      final outside = await Directory.systemTemp.createTemp('tinest-outside-');
      addTearDown(() async {
        await directory.delete(recursive: true);
        await outside.delete(recursive: true);
      });
      final store = FileAgentDefinitionStore(directory.path);
      addTearDown(store.close);
      await store.initialize();
      final tinest = (await store.get('tinest'))!;
      final sourceFile = File(tinest.sourcePath);
      await sourceFile.writeAsString(
        (await sourceFile.readAsString()).replaceFirst(
          'name: Tinest',
          'name: Dev',
        ),
      );
      if (!Platform.isWindows) {
        final outsideFile = File('${outside.path}/evil.md')
          ..writeAsStringSync(source);
        Link('${directory.path}/agents/evil.md').createSync(outsideFile.path);
      }

      await store.reload();

      expect((await store.get('tinest'))!.name, 'Dev');
      expect(await store.get('evil'), isNull);
      if (!Platform.isWindows) {
        expect(
          Directory('${directory.path}/agents').statSync().mode & 0x1ff,
          0x1c0,
        );
        expect(sourceFile.statSync().mode & 0x1ff, 0x180);
      }
    },
  );

  test(
    'domain service accepts plugin tools and validates callable subagents',
    () async {
      final directory = await Directory.systemTemp.createTemp('tinest-agents-');
      addTearDown(() => directory.delete(recursive: true));
      final store = FileAgentDefinitionStore(directory.path);
      final service = AgentDefinitionService(
        store: store,
        contributions: _toolCatalog(const <AgentToolDefinitionDto>[
          AgentToolDefinitionDto(
            id: 'acme.files/read',
            originPluginId: 'acme.files',
            contributionId: 'read',
            name: 'read_file',
            description: 'Read files.',
            risk: ToolRisk.read,
            group: 'filesystem',
            kind: AgentToolKind.function,
            inputSchema: <String, dynamic>{'type': 'object'},
            effects: <String>['filesystem.read'],
            presentation: <String, dynamic>{'group': 'filesystem'},
          ),
        ]),
      );
      addTearDown(service.close);
      await service.initialize();
      final tinest = await service.get('tinest');
      final reviewer = await service.create(
        'reviewer',
        tinest.copyWith(
          id: 'reviewer',
          name: 'Reviewer',
          mode: AgentMode.subagent,
          toolIds: const <String>['acme.files/read', 'acme.future/tool'],
          callableAgentIds: const <String>[],
          contentHash: '',
          sourcePath: '',
          isBuiltIn: false,
        ),
      );
      expect(reviewer.diagnostics, isEmpty);
      final callable = await service.update(
        tinest.copyWith(callableAgentIds: const <String>['reviewer']),
        expectedContentHash: tinest.contentHash,
      );
      expect(callable.callableAgentIds, const <String>['reviewer']);
      await expectLater(
        service.update(
          callable.copyWith(callableAgentIds: const <String>['missing']),
          expectedContentHash: callable.contentHash,
        ),
        throwsA(isA<FormatException>()),
      );

      await service.archive('reviewer');
      expect((await service.get('tinest')).callableAgentIds, isEmpty);
      await expectLater(service.archive('tinest'), throwsA(isA<StateError>()));
    },
    tags: const <String>['feature_test__agent_collaboration__unit'],
  );

  test(
    'file store protects immutable IDs, supports force, and restores tinest',
    () async {
      final directory = await Directory.systemTemp.createTemp('tinest-agents-');
      addTearDown(() => directory.delete(recursive: true));
      final store = FileAgentDefinitionStore(directory.path);
      addTearDown(store.close);
      await store.initialize();
      await store.initialize();
      final tinest = (await store.get('tinest'))!;
      expect(tinest.toolIds, <String>[
        'tinest.edit/apply_patch',
        'tinest.mcp/list_resources',
        'tinest.mcp/list_resource_templates',
        'tinest.mcp/read_resource',
        'tinest.terminal/exec_command',
        'tinest.terminal/write_stdin',
        'tinest.collaboration/spawn_agent',
        'tinest.collaboration/send_message',
        'tinest.collaboration/followup_task',
        'tinest.collaboration/wait_agent',
        'tinest.collaboration/interrupt_agent',
        'tinest.collaboration/list_agents',
      ]);

      await expectLater(
        store.create('other', tinest),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        store.create('tinest', tinest),
        throwsA(isA<StateError>()),
      );
      final reviewer = await store.create(
        'reviewer',
        tinest.copyWith(
          id: 'reviewer',
          name: 'Reviewer',
          mode: AgentMode.subagent,
          contentHash: '',
          sourcePath: '',
          isBuiltIn: false,
        ),
      );
      await expectLater(
        store.update(
          reviewer.copyWith(mode: AgentMode.primary),
          expectedContentHash: reviewer.contentHash,
        ),
        throwsA(isA<FormatException>()),
      );
      final forced = await store.update(
        reviewer.copyWith(name: 'Forced Reviewer'),
        expectedContentHash: 'outdated',
        force: true,
      );
      expect(forced.name, 'Forced Reviewer');
      await store.create(
        'auditor',
        reviewer.copyWith(
          id: 'auditor',
          name: 'Auditor',
          contentHash: '',
          sourcePath: '',
        ),
      );
      expect((await store.list()).map((definition) => definition.id), <String>[
        'tinest',
        'auditor',
        'reviewer',
      ]);
      await expectLater(store.archive('missing'), throwsA(isA<StateError>()));

      await File(tinest.sourcePath).delete();
      await store.reload();
      final reseeded = (await store.get('tinest'))!;
      expect(reseeded.name, 'Tinest');
      expect(reseeded.prompt, contains('Read relevant code'));
      expect(await store.list(), hasLength(3));
      await store.archive('reviewer');
      expect(await store.listArchived(), hasLength(1));
      await File((await store.resolve('reviewer'))!.sourcePath).delete();
      await store.reload();
      expect(await store.listArchived(), isEmpty);
      final reset = await store.resetTinest();
      expect(reset.prompt, contains('Read relevant code'));
      expect(reset.toolIds, tinest.toolIds);
    },
    tags: const <String>['feature_test__agent_definition_management__unit'],
  );

  test(
    'domain service covers lookup, validation, catalog, and fixed refs',
    () async {
      final directory = await Directory.systemTemp.createTemp('tinest-agents-');
      addTearDown(() => directory.delete(recursive: true));
      final store = FileAgentDefinitionStore(directory.path);
      final service = AgentDefinitionService(
        store: store,
        contributions: _toolCatalog(const <AgentToolDefinitionDto>[
          AgentToolDefinitionDto(
            id: 'acme.tools/z',
            originPluginId: 'acme.tools',
            contributionId: 'z',
            name: 'Zulu',
            description: 'Last.',
            risk: ToolRisk.read,
            group: 'filesystem',
            kind: AgentToolKind.function,
            inputSchema: <String, dynamic>{'type': 'object'},
            effects: <String>['filesystem.read'],
            presentation: <String, dynamic>{'group': 'filesystem'},
          ),
          AgentToolDefinitionDto(
            id: 'acme.tools/a',
            originPluginId: 'acme.tools',
            contributionId: 'a',
            name: 'Alpha',
            description: 'First.',
            risk: ToolRisk.read,
            group: 'filesystem',
            kind: AgentToolKind.function,
            inputSchema: <String, dynamic>{'type': 'object'},
            effects: <String>['filesystem.read'],
            presentation: <String, dynamic>{'group': 'filesystem'},
          ),
        ]),
      );
      addTearDown(service.close);
      await service.initialize();
      expect((await service.toolCatalog()).map((tool) => tool.name), <String>[
        'Alpha',
        'Zulu',
      ]);
      // A missing definition is reported as a typed lookup failure so
      // session creation can name the agent instead of reporting an
      // unexplained internal error.
      await expectLater(
        service.get('missing'),
        throwsA(
          isA<AgentDefinitionLookupFailure>()
              .having((error) => error.id, 'id', 'missing')
              .having((error) => error.isMissing, 'isMissing', isTrue),
        ),
      );
      await expectLater(
        service.resolve('missing'),
        throwsA(isA<AgentDefinitionLookupFailure>()),
      );
      await expectLater(service.reset('reviewer'), throwsA(isA<StateError>()));

      final tinest = await service.get('tinest');
      final fixed = await service.create(
        'fixed',
        tinest.copyWith(
          id: 'fixed',
          name: 'Fixed',
          mode: AgentMode.subagent,
          model: const AgentModelSelectionDto(
            source: AgentModelSource.fixed,
            modelId: 'connection/model',
          ),
          toolIds: const <String>['acme.tools/a'],
          contentHash: '',
          sourcePath: '',
          isBuiltIn: false,
        ),
      );
      expect(await service.referencesProvider('connection'), isTrue);
      expect(await service.referencesProvider('other'), isFalse);
      expect((await service.resolve(fixed.id)).id, fixed.id);
      await service.archive(fixed.id);
      expect(await service.referencesProvider('connection'), isTrue);

      final validated = await service.validate(
        'candidate',
        source
            .replaceFirst('mode: subagent', 'mode: primary')
            .replaceFirst('acme.future/tool', 'acme.tools/a'),
      );
      expect(validated.id, 'candidate');
      await expectLater(
        service.create(
          'invalid-subagent',
          tinest.copyWith(
            id: 'invalid-subagent',
            mode: AgentMode.subagent,
            callableAgentIds: const <String>['fixed'],
            contentHash: '',
            sourcePath: '',
            isBuiltIn: false,
          ),
        ),
        throwsA(isA<FormatException>()),
      );
      expect((await service.reset('tinest')).isBuiltIn, isTrue);
    },
  );
}

AgentContributionCatalog _toolCatalog(List<AgentToolDefinitionDto> tools) {
  final pluginId = tools.first.originPluginId;
  return _TestAgentContributionCatalog(<PluginDescriptorDto>[
    PluginDescriptorDto(
      apiMajor: 5,
      id: pluginId,
      version: '1.0.0',
      name: pluginId,
      entrypoint: 'main.lua',
      source: PluginSource.user,
      sourcePath: 'plugins/$pluginId',
      requestedCapabilities: const <String>[],
      revision: PluginRevisionDto(
        pluginId: pluginId,
        contentHash: 'content',
        manifestHash: 'manifest',
        sdkAbiHash: 'sdk-abi',
        executionRevisionHash: 'execution',
        requestedCapabilities: const <String>[],
      ),
      contributions: <PluginContributionDto>[
        for (final tool in tools)
          PluginContributionDto(
            pluginId: pluginId,
            id: tool.contributionId,
            kind: PluginContributionKind.tool,
            tool: tool,
          ),
      ],
    ),
  ]);
}

final class _TestAgentContributionCatalog implements AgentContributionCatalog {
  const new(this._descriptors);

  final List<PluginDescriptorDto> _descriptors;

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<List<PluginDescriptorDto>> listPluginDescriptors() async =>
      _descriptors;
}
