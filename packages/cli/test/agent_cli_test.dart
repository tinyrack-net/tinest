import 'package:cli/cli.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  test('agent CLI lists, validates, applies, archives, and resets', () async {
    final backend = _AgentBackend();
    final output = StringBuffer();

    expect(await agentList(backend: backend, output: output), 0);
    expect(output.toString(), contains('tinest'));

    expect(
      await agentValidate(
        backend: backend,
        output: output,
        path: '/tmp/reviewer.md',
        readFile: (_) async => 'markdown',
      ),
      0,
    );
    expect(
      await agentApply(
        backend: backend,
        output: output,
        id: 'reviewer',
        path: '/tmp/reviewer.md',
        readFile: (_) async => 'markdown',
      ),
      0,
    );
    expect(backend.applied, contains('reviewer'));
    expect(
      await agentArchive(backend: backend, output: output, id: 'reviewer'),
      0,
    );
    expect(await agentReset(backend: backend, output: output, id: 'tinest'), 0);
  });

  test('validate takes the agent ID from the file name', () async {
    final backend = _AgentBackend();
    final output = StringBuffer();

    await agentValidate(
      backend: backend,
      output: output,
      path: '/tmp/nested/reviewer.md',
      readFile: (_) async => 'markdown',
    );

    expect(backend.validated, <String>['reviewer']);
  });

  test('list marks a stale definition', () async {
    final backend = _AgentBackend(includeStale: true);
    final output = StringBuffer();

    await agentList(backend: backend, output: output);

    expect(output.toString(), contains('stale'));
  });

  test('reset refuses anything but the built-in definition', () async {
    final backend = _AgentBackend();

    await expectLater(
      agentReset(backend: backend, output: StringBuffer(), id: 'reviewer'),
      throwsA(isA<FormatException>()),
    );
    expect(backend.resetIds, isEmpty);
  });

  test(
    'reading a file without a reader fails before the daemon call',
    () async {
      final backend = _AgentBackend();

      await expectLater(
        agentValidate(
          backend: backend,
          output: StringBuffer(),
          path: '/tmp/reviewer.md',
        ),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        agentApply(
          backend: backend,
          output: StringBuffer(),
          id: 'reviewer',
          path: '/tmp/reviewer.md',
        ),
        throwsA(isA<StateError>()),
      );
      expect(backend.validated, isEmpty);
      expect(backend.applied, isEmpty);
    },
  );
}

final class _AgentBackend implements AgentCliBackend {
  new({this.includeStale = false});

  final bool includeStale;
  final List<String> applied = <String>[];
  final List<String> validated = <String>[];
  final List<String> resetIds = <String>[];

  AgentDefinitionDto definition(String id) => AgentDefinitionDto(
    version: 5,
    id: id,
    name: id,
    description: '',
    mode: id == 'tinest' ? AgentMode.primary : AgentMode.subagent,
    model: const AgentModelSelectionDto(source: AgentModelSource.session),
    driverId: 'tinest.standard/driver',
    extensionIds: const <String>[],
    toolIds: const <String>[],
    pluginSettings: const <String, Map<String, dynamic>>{},
    callableAgentIds: const <String>[],
    prompt: 'prompt',
    contentHash: 'hash',
    sourcePath: '/config/agents/$id.md',
    isBuiltIn: id == 'tinest',
  );

  @override
  Future<void> archive(String id) async {}

  @override
  Future<AgentDefinitionDto> apply(
    String id,
    AgentDefinitionDto definition,
  ) async {
    applied.add(id);
    return definition;
  }

  @override
  Future<List<AgentDefinitionDto>> list() async => <AgentDefinitionDto>[
    definition('tinest'),
    if (includeStale)
      definition('stale').copyWith(
        isStale: true,
        diagnostics: const <AgentDefinitionDiagnosticDto>[
          AgentDefinitionDiagnosticDto(
            code: 'invalid_agent_markdown',
            message: 'broken',
          ),
        ],
      ),
  ];

  @override
  Future<AgentDefinitionDto> reset(String id) async {
    resetIds.add(id);
    return definition(id);
  }

  @override
  Future<AgentDefinitionDto> validate(String id, String markdown) async {
    validated.add(id);
    return definition(id);
  }
}
