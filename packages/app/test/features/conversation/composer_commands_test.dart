import 'package:app/src/features/conversation/domain/composer_commands.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';

void main() {
  AgentCommandDto agentCommand({
    String id = 'review',
    String name = 'review',
    String description = 'Reviews the working diff.',
    String body = 'Review the diff.',
    String? argumentHint,
  }) => AgentCommandDto(
    id: id,
    name: name,
    description: description,
    source: AgentCommandSource.project,
    sourcePath: '/workspace/.agents/commands/$id.md',
    body: body,
    argumentHint: argumentHint,
  );

  SkillSummaryDto skill({
    String id = 'commit',
    String name = 'commit',
    bool isImplicit = false,
  }) => SkillSummaryDto(
    id: id,
    name: name,
    description: 'Writes atomic commits.',
    isImplicit: isImplicit,
  );

  List<ComposerCommand> merge({
    List<ComposerCommand> client = const <ComposerCommand>[],
    List<AgentCommandDto> agent = const <AgentCommandDto>[],
    List<SkillSummaryDto> skills = const <SkillSummaryDto>[],
  }) => mergeComposerCommands(client: client, agent: agent, skills: skills);

  group('withoutClientActions', () {
    test('drops only the named app commands and keeps the order', () {
      final merged = merge(
        client: clientComposerCommands,
        agent: <AgentCommandDto>[agentCommand()],
        skills: <SkillSummaryDto>[skill()],
      );

      final filtered = withoutClientActions(merged, const <ClientCommandAction>{
        ClientCommandAction.newSession,
      });

      expect(filtered.map((command) => command.name), isNot(contains('new')));
      expect(
        filtered.map((command) => command.name),
        orderedEquals(
          merged
              .where((command) => command.name != 'new')
              .map((command) => command.name),
        ),
      );
    }, tags: const <String>['feature_test__composer_slash_command__unit']);

    test('never drops a skill or agent command', () {
      final merged = merge(
        agent: <AgentCommandDto>[agentCommand(name: 'new')],
        skills: <SkillSummaryDto>[skill(id: 'clear', name: 'clear')],
      );

      final filtered = withoutClientActions(
        merged,
        ClientCommandAction.values.toSet(),
      );

      expect(
        filtered.map((command) => command.name),
        containsAll(<String>['new', 'clear']),
      );
    }, tags: const <String>['feature_test__composer_slash_command__unit']);

    test('returns the same catalog when nothing is excluded', () {
      final merged = merge(client: clientComposerCommands);

      expect(
        withoutClientActions(merged, const <ClientCommandAction>{}),
        orderedEquals(merged),
      );
    }, tags: const <String>['feature_test__composer_slash_command__unit']);
  });

  group('mergeComposerCommands', () {
    test('offers every source in one catalog sorted by name', () {
      final merged = merge(
        client: clientComposerCommands,
        agent: <AgentCommandDto>[agentCommand()],
        skills: <SkillSummaryDto>[skill()],
      );

      expect(
        merged.map((command) => command.name),
        orderedEquals(merged.map((command) => command.name).toList()..sort()),
      );
      expect(
        merged.singleWhere((command) => command.name == 'review').kind,
        ComposerCommandKind.agent,
      );
      expect(
        merged.singleWhere((command) => command.name == 'commit').kind,
        ComposerCommandKind.skill,
      );
      expect(
        merged.singleWhere((command) => command.name == 'clear').kind,
        ComposerCommandKind.client,
      );
    }, tags: const <String>['feature_test__composer_slash_command__unit']);

    test('lets a client command shadow a same-named file on disk', () {
      final merged = merge(
        client: clientComposerCommands,
        agent: <AgentCommandDto>[agentCommand(id: 'clear', name: 'clear')],
      );

      final clear = merged.singleWhere((command) => command.name == 'clear');
      expect(clear.kind, ComposerCommandKind.client);
      expect(clear.action, ClientCommandAction.clear);
    }, tags: const <String>['feature_test__composer_slash_command__unit']);

    test('lets an agent command shadow a same-named skill', () {
      final merged = merge(
        agent: <AgentCommandDto>[agentCommand(id: 'commit', name: 'commit')],
        skills: <SkillSummaryDto>[skill()],
      );

      expect(merged.single.kind, ComposerCommandKind.agent);
    }, tags: const <String>['feature_test__composer_slash_command__unit']);

    test('excludes an implicit skill the agent already receives', () {
      expect(
        merge(skills: <SkillSummaryDto>[skill(isImplicit: true)]),
        isEmpty,
      );
    }, tags: const <String>['feature_test__composer_slash_command__unit']);

    test('falls back to the skill id when it has no name', () {
      final merged = merge(skills: <SkillSummaryDto>[skill(name: '   ')]);

      expect(merged.single.name, 'commit');
    }, tags: const <String>['feature_test__composer_slash_command__unit']);

    test('carries the argument hint through from an agent command', () {
      final merged = merge(
        agent: <AgentCommandDto>[agentCommand(argumentHint: '<path>')],
      );

      expect(merged.single.argumentHint, '<path>');
    }, tags: const <String>['feature_test__composer_slash_command__unit']);
  });

  group('rankComposerCommands', () {
    test('drops commands the query cannot match', () {
      final ranked = rankComposerCommands(clientComposerCommands, 'zzzz');

      expect(ranked, isEmpty);
    }, tags: const <String>['feature_test__composer_slash_command__unit']);

    test('returns every command for an empty query', () {
      final ranked = rankComposerCommands(clientComposerCommands, '');

      expect(ranked, hasLength(clientComposerCommands.length));
    }, tags: const <String>['feature_test__composer_slash_command__unit']);

    test('puts the closest name first', () {
      final ranked = rankComposerCommands(clientComposerCommands, 'cle');

      expect(ranked.first.command.name, 'clear');
    }, tags: const <String>['feature_test__composer_slash_command__unit']);

    test('reports highlight indices into the command name', () {
      final ranked = rankComposerCommands(clientComposerCommands, 'cl');

      expect(ranked.first.match.matchedIndices, <int>[0, 1]);
    }, tags: const <String>['feature_test__composer_slash_command__unit']);
  });

  group('parseComposerCommand', () {
    test('resolves a bare command', () {
      final invocation = parseComposerCommand(
        '/clear',
        clientComposerCommands,
      )!;

      expect(invocation.command.action, ClientCommandAction.clear);
      expect(invocation.arguments, isEmpty);
    }, tags: const <String>['feature_test__composer_slash_command__unit']);

    test('splits trailing arguments off the name', () {
      final commands = merge(
        agent: <AgentCommandDto>[agentCommand(argumentHint: '<path>')],
      );

      final invocation = parseComposerCommand(
        '/review lib/app.dart now',
        commands,
      )!;

      expect(invocation.command.name, 'review');
      expect(invocation.arguments, 'lib/app.dart now');
    }, tags: const <String>['feature_test__composer_slash_command__unit']);

    test('host command catalog leaves goal behavior to plugins', () {
      expect(
        clientComposerCommands.any((command) => command.name == 'goal'),
        isFalse,
      );
      expect(
        parseComposerCommand('/goal pause', clientComposerCommands),
        isNull,
      );
    }, tags: const <String>['feature_test__session_goal__unit']);

    test('rejects an unknown name rather than guessing', () {
      expect(parseComposerCommand('/clea', clientComposerCommands), isNull);
    }, tags: const <String>['feature_test__composer_slash_command__unit']);

    test('rejects prose that merely contains a command', () {
      expect(
        parseComposerCommand('please /clear this', clientComposerCommands),
        isNull,
      );
    }, tags: const <String>['feature_test__composer_slash_command__unit']);

    test('treats a leading space as an escape hatch', () {
      expect(parseComposerCommand(' /clear', clientComposerCommands), isNull);
    }, tags: const <String>['feature_test__composer_slash_command__unit']);

    test('rejects a bare sigil', () {
      expect(parseComposerCommand('/', clientComposerCommands), isNull);
    }, tags: const <String>['feature_test__composer_slash_command__unit']);
  });

  group('renderComposerPrompt', () {
    test('leaves ordinary prose untouched', () {
      expect(
        renderComposerPrompt('read lib/app.dart', clientComposerCommands),
        'read lib/app.dart',
      );
    }, tags: const <String>['feature_test__composer_slash_command__unit']);

    test('leaves an unknown slash message untouched', () {
      expect(
        renderComposerPrompt('/unknown thing', clientComposerCommands),
        '/unknown thing',
      );
    }, tags: const <String>['feature_test__composer_slash_command__unit']);

    test('leaves a client command for the composer to dispatch', () {
      expect(renderComposerPrompt('/clear', clientComposerCommands), '/clear');
    }, tags: const <String>['feature_test__composer_slash_command__unit']);

    test('names a skill for the agent to load', () {
      final commands = merge(skills: <SkillSummaryDto>[skill()]);

      expect(
        renderComposerPrompt('/commit', commands),
        'Use the "commit" skill.',
      );
    }, tags: const <String>['feature_test__composer_slash_command__unit']);

    test('appends skill arguments below the instruction', () {
      final commands = merge(skills: <SkillSummaryDto>[skill()]);

      expect(
        renderComposerPrompt('/commit split the refactor', commands),
        'Use the "commit" skill.\n\nsplit the refactor',
      );
    }, tags: const <String>['feature_test__composer_slash_command__unit']);

    test(r'substitutes $ARGUMENTS into an agent template', () {
      final commands = merge(
        agent: <AgentCommandDto>[
          agentCommand(body: r'Review $ARGUMENTS and report defects.'),
        ],
      );

      expect(
        renderComposerPrompt('/review lib/app.dart', commands),
        'Review lib/app.dart and report defects.',
      );
    }, tags: const <String>['feature_test__composer_slash_command__unit']);

    test('substitutes positional arguments', () {
      final commands = merge(
        agent: <AgentCommandDto>[agentCommand(body: r'Compare $1 with $2.')],
      );

      expect(
        renderComposerPrompt('/review before.dart after.dart', commands),
        'Compare before.dart with after.dart.',
      );
    }, tags: const <String>['feature_test__composer_slash_command__unit']);

    test('empties a positional argument that was not supplied', () {
      final commands = merge(
        agent: <AgentCommandDto>[agentCommand(body: r'Compare $1 with $2.')],
      );

      expect(
        renderComposerPrompt('/review only.dart', commands),
        'Compare only.dart with .',
      );
    }, tags: const <String>['feature_test__composer_slash_command__unit']);

    test('leaves an unknown placeholder verbatim', () {
      final commands = merge(
        agent: <AgentCommandDto>[agentCommand(body: r'Spend $BUDGET on $1.')],
      );

      expect(
        renderComposerPrompt('/review now', commands),
        r'Spend $BUDGET on now.',
      );
    }, tags: const <String>['feature_test__composer_slash_command__unit']);
  });
}
