import 'package:daemon/src/features/agents/infrastructure/agent_definitions.dart';
import 'package:test/test.dart';

void main() {
  const source = '''
---
# Keep user comments and unknown metadata.
version: 5
name: Custom
description: Custom harness
mode: primary
model:
  source: session
driver: acme.driver/main
extensions:
  - acme.plan
tools:
  - acme.files/read
pluginSettings:
  acme.plan:
    responseStyle: concise
callableAgents: []
futureField: preserved
---

Prompt data owned by the Agent.
''';

  test('v5 codec gives the Agent sole ownership of its harness', () {
    const codec = AgentMarkdownCodec();
    final definition = codec.decode(
      id: 'custom',
      sourcePath: '/config/v5/agents/custom.md',
      source: source,
    );

    expect(definition.version, 5);
    expect(definition.driverId, 'acme.driver/main');
    expect(definition.extensionIds, <String>['acme.plan']);
    expect(definition.toolIds, <String>['acme.files/read']);
    expect(definition.pluginSettings, <String, Map<String, dynamic>>{
      'acme.plan': <String, dynamic>{'responseStyle': 'concise'},
    });
    expect(definition.prompt, 'Prompt data owned by the Agent.');

    final updated = codec.encodeUpdate(
      originalSource: source,
      definition: definition.copyWith(
        toolIds: const <String>[],
        prompt: 'No tools are valid too.',
      ),
    );
    expect(updated, contains('# Keep user comments'));
    expect(updated, contains('futureField: preserved'));
    expect(updated, contains('tools: []'));
    expect(updated, endsWith('No tools are valid too.\n'));
  }, tags: const <String>['feature_test__agent_harness__unit']);

  test('v5 codec rejects v4 and malformed harness references', () {
    const codec = AgentMarkdownCodec();
    for (final invalid in <String>[
      source.replaceFirst('version: 5', 'version: 4'),
      source.replaceFirst('driver: acme.driver/main', 'driver: acme.driver'),
      source.replaceFirst(
        'extensions:\n  - acme.plan',
        'extensions: [Acme.Plan]',
      ),
      source.replaceFirst('tools:\n  - acme.files/read', 'tools: [acme.files]'),
      source.replaceFirst('callableAgents: []', 'callableAgents: [one, one]'),
      source.replaceFirst(
        'acme.plan:\n    responseStyle',
        'unreferenced.plugin:\n    responseStyle',
      ),
    ]) {
      expect(
        () => codec.decode(
          id: 'custom',
          sourcePath: '/config/v5/agents/custom.md',
          source: invalid,
        ),
        throwsA(isA<FormatException>()),
      );
    }
  });
}
