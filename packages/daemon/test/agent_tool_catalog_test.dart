@Tags(<String>['feature_test__agent_harness__unit'])
library;

import 'dart:async';
import 'dart:io';

import 'package:daemon/src/features/agents/infrastructure/agent_definitions.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  const alpha = AgentToolDefinitionDto(
    id: 'acme.tools/alpha',
    originPluginId: 'acme.tools',
    contributionId: 'alpha',
    name: 'alpha',
    description: 'Registered by Lua.',
    risk: ToolRisk.read,
    group: 'custom',
    kind: AgentToolKind.function,
    inputSchema: <String, dynamic>{'type': 'object'},
    effects: <String>['workspace.read'],
    presentation: <String, dynamic>{'label': 'Alpha'},
  );
  const zulu = AgentToolDefinitionDto(
    id: 'acme.tools/zulu',
    originPluginId: 'acme.tools',
    contributionId: 'zulu',
    name: 'zulu',
    description: 'Also registered by Lua.',
    risk: ToolRisk.write,
    group: 'custom',
    kind: AgentToolKind.function,
    inputSchema: <String, dynamic>{
      'type': 'object',
      'properties': <String, dynamic>{
        'path': <String, dynamic>{'type': 'string'},
      },
      'required': <String>['path'],
    },
    effects: <String>['workspace.write'],
    presentation: <String, dynamic>{'label': 'Zulu'},
  );

  late Directory directory;
  late _FakeContributionCatalog contributions;
  late AgentDefinitionService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('tinest-agent-tools-');
    contributions = _FakeContributionCatalog(<PluginDescriptorDto>[
      _descriptor(
        id: 'acme.tools',
        contributions: const <PluginContributionDto>[
          PluginContributionDto(
            pluginId: 'acme.tools',
            id: 'zulu',
            kind: PluginContributionKind.tool,
            tool: zulu,
          ),
          PluginContributionDto(
            pluginId: 'acme.tools',
            id: 'prompt',
            kind: PluginContributionKind.extension,
          ),
          PluginContributionDto(
            pluginId: 'acme.tools',
            id: 'alpha',
            kind: PluginContributionKind.tool,
            tool: alpha,
          ),
        ],
      ),
      _descriptor(
        id: 'acme.invalid',
        runnable: false,
        contributions: const <PluginContributionDto>[
          PluginContributionDto(
            pluginId: 'acme.invalid',
            id: 'unvalidated',
            kind: PluginContributionKind.tool,
            tool: AgentToolDefinitionDto(
              id: 'acme.invalid/unvalidated',
              originPluginId: 'acme.invalid',
              contributionId: 'unvalidated',
              name: 'unvalidated',
              description: 'Must not escape an invalid candidate.',
              risk: ToolRisk.dangerous,
              group: 'invalid',
              kind: AgentToolKind.function,
              inputSchema: <String, dynamic>{},
              effects: <String>[],
              presentation: <String, dynamic>{},
            ),
          ),
        ],
      ),
    ]);
    service = AgentDefinitionService(
      store: FileAgentDefinitionStore(directory.path),
      contributions: contributions,
    );
    await service.initialize();
  });

  tearDown(() async {
    await service.close();
    await contributions.close();
    await directory.delete(recursive: true);
  });

  test(
    'catalog exposes only exact tools from runnable Lua registrations',
    () async {
      final tools = await service.toolCatalog();

      expect(tools, <AgentToolDefinitionDto>[alpha, zulu]);
      expect(tools.first.presentation, alpha.presentation);
      expect(
        tools.map((tool) => tool.id),
        isNot(contains('acme.invalid/unvalidated')),
      );
    },
  );

  test('zero validated tool contributions produces an empty catalog', () async {
    contributions.descriptors = <PluginDescriptorDto>[
      _descriptor(
        id: 'acme.prompt',
        contributions: const <PluginContributionDto>[
          PluginContributionDto(
            pluginId: 'acme.prompt',
            id: 'extension',
            kind: PluginContributionKind.extension,
          ),
        ],
      ),
    ];

    expect(await service.toolCatalog(), isEmpty);
  });

  test(
    'catalog changes participate in Agent definition notifications',
    () async {
      final changes = <void>[];
      final subscription = service.changes.listen(changes.add);
      addTearDown(subscription.cancel);

      contributions.announce();
      await pumpEventQueue();

      expect(changes, hasLength(1));
    },
  );
}

PluginDescriptorDto _descriptor({
  required String id,
  required List<PluginContributionDto> contributions,
  bool runnable = true,
}) => PluginDescriptorDto(
  apiMajor: 5,
  id: id,
  version: '1.0.0',
  name: id,
  entrypoint: 'main.lua',
  source: PluginSource.user,
  sourcePath: 'plugins/$id',
  requestedCapabilities: const <String>[],
  revision: runnable
      ? PluginRevisionDto(
          pluginId: id,
          contentHash: '$id-content',
          manifestHash: '$id-manifest',
          sdkAbiHash: 'sdk-abi',
          executionRevisionHash: '$id-execution',
          requestedCapabilities: const <String>[],
        )
      : null,
  contributions: contributions,
);

final class _FakeContributionCatalog implements AgentContributionCatalog {
  new(this.descriptors);

  List<PluginDescriptorDto> descriptors;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<PluginDescriptorDto>> listPluginDescriptors() async =>
      descriptors;

  void announce() => _changes.add(null);

  Future<void> close() => _changes.close();
}
