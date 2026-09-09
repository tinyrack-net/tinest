@Tags(<String>['feature_test__agent_definition_management__unit'])
library;

import 'package:app/src/features/agents/presentation/tool_groups.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';

AgentToolDefinitionDto _tool(String id, String group) => AgentToolDefinitionDto(
  id: id,
  originPluginId: 'test.tools',
  contributionId: id,
  name: id,
  description: 'Does $id.',
  risk: ToolRisk.read,
  group: group,
  kind: AgentToolKind.function,
  inputSchema: const <String, dynamic>{'type': 'object'},
  effects: const <String>['test.read'],
  presentation: <String, dynamic>{'group': group},
);

void main() {
  test('plugin string groups keep first-seen catalog order', () {
    final grouped = groupAgentTools(<AgentToolDefinitionDto>[
      _tool('exec_command', 'execution'),
      _tool('read_file', 'filesystem'),
      _tool('apply_patch', 'third.party'),
      _tool('glob', 'filesystem'),
    ]);

    expect(grouped.map((view) => view.group), <String>[
      'execution',
      'filesystem',
      'third.party',
    ]);
    expect(grouped[1].tools.map((tool) => tool.id), <String>[
      'read_file',
      'glob',
    ]);
  });

  test('a group nothing belongs to is not drawn', () {
    final grouped = groupAgentTools(<AgentToolDefinitionDto>[
      _tool('read_file', 'filesystem'),
    ]);

    expect(grouped, hasLength(1));
    expect(grouped.single.group, 'filesystem');
  });

  test('every tool in a group can be toggled independently', () {
    final view = groupAgentTools(<AgentToolDefinitionDto>[
      _tool('read_file', 'filesystem'),
      _tool('glob', 'filesystem'),
    ]).single;

    expect(view.toggleableIds, <String>['read_file', 'glob']);
    expect(view.enabledCount(const <String>{}), 0);
    expect(view.allEnabled(const <String>{}), isFalse);
    expect(view.partiallyEnabled(const <String>{}), isFalse);
    expect(view.enabledCount(const <String>{'read_file'}), 1);
    expect(view.partiallyEnabled(const <String>{'read_file'}), isTrue);
  });

  test('a group reports partial only between empty and full', () {
    final view = groupAgentTools(<AgentToolDefinitionDto>[
      _tool('list_mcp_resources', 'mcp'),
      _tool('read_mcp_resource', 'mcp'),
    ]).single;

    expect(view.toggleableIds, <String>[
      'list_mcp_resources',
      'read_mcp_resource',
    ]);
    expect(view.partiallyEnabled(const <String>{}), isFalse);
    expect(view.allEnabled(const <String>{}), isFalse);

    expect(view.partiallyEnabled(const <String>{'read_mcp_resource'}), isTrue);
    expect(view.allEnabled(const <String>{'read_mcp_resource'}), isFalse);

    const both = <String>{'list_mcp_resources', 'read_mcp_resource'};
    expect(view.partiallyEnabled(both), isFalse);
    expect(view.allEnabled(both), isTrue);
  });
}
