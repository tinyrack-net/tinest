import 'package:app/src/shared/domain/fuzzy_match.dart';
import 'package:meta/meta.dart';
import 'package:protocol/protocol.dart';

/// Where one `/` command comes from and how submitting it behaves.
enum ComposerCommandKind {
  /// Handled inside the app; never reaches the daemon as a turn.
  client,

  /// Names an effective skill for the agent to load.
  skill,

  /// Expands a Markdown prompt template authored on disk.
  agent,
}

/// An app-owned action a `/` command performs instead of starting a turn.
enum ClientCommandAction {
  /// Clears the composer draft.
  clear,

  /// Starts a new session in the current worktree.
  newSession,

  /// Opens the agent settings screen.
  openAgentSettings,

  /// Opens the skill settings screen.
  openSkillSettings,

  /// Lists the available commands.
  help,
}

/// One entry the composer offers behind `/`.
@immutable
final class ComposerCommand {
  /// Creates a composer command.
  const new({
    required this.id,
    required this.name,
    required this.description,
    required this.kind,
    this.argumentHint,
    this.action,
    this.promptTemplate,
  }) : assert(
         (kind == ComposerCommandKind.client) == (action != null),
         'A client command carries an action; others do not.',
       ),
       assert(
         kind != ComposerCommandKind.agent || promptTemplate != null,
         'An agent command carries a prompt template.',
       );

  /// Stable identity, namespaced by kind so sources cannot collide.
  final String id;

  /// Text typed after `/`.
  final String name;

  /// One-line summary shown beside the name.
  final String description;

  /// Which source provided the command.
  final ComposerCommandKind kind;

  /// Documents the trailing arguments, such as `<path>`.
  final String? argumentHint;

  /// Non-null exactly when [kind] is [ComposerCommandKind.client].
  final ClientCommandAction? action;

  /// Non-null exactly when [kind] is [ComposerCommandKind.agent].
  final String? promptTemplate;

  @override
  bool operator ==(Object other) =>
      other is ComposerCommand &&
      other.id == id &&
      other.name == name &&
      other.description == description &&
      other.kind == kind &&
      other.argumentHint == argumentHint &&
      other.action == action &&
      other.promptTemplate == promptTemplate;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    kind,
    argumentHint,
    action,
    promptTemplate,
  );
}

/// The commands the app performs itself, independent of any daemon.
///
/// Descriptions are placeholders replaced by localized strings at the call
/// site; keeping the list const makes it usable from pure unit tests.
const List<ComposerCommand> clientComposerCommands = <ComposerCommand>[
  ComposerCommand(
    id: 'client:clear',
    name: 'clear',
    description: 'Clears the composer.',
    kind: ComposerCommandKind.client,
    action: ClientCommandAction.clear,
  ),
  ComposerCommand(
    id: 'client:new',
    name: 'new',
    description: 'Starts a new session.',
    kind: ComposerCommandKind.client,
    action: ClientCommandAction.newSession,
  ),
  ComposerCommand(
    id: 'client:agents',
    name: 'agents',
    description: 'Opens agent settings.',
    kind: ComposerCommandKind.client,
    action: ClientCommandAction.openAgentSettings,
  ),
  ComposerCommand(
    id: 'client:skills',
    name: 'skills',
    description: 'Opens skill settings.',
    kind: ComposerCommandKind.client,
    action: ClientCommandAction.openSkillSettings,
  ),
  ComposerCommand(
    id: 'client:help',
    name: 'help',
    description: 'Lists the available commands.',
    kind: ComposerCommandKind.client,
    action: ClientCommandAction.help,
  ),
];

/// Merges the three command sources into one catalog sorted by name.
///
/// Precedence on a colliding name is client, then agent, then skill: an
/// app-owned action must never be shadowed by a file on disk, and an explicit
/// prompt template is more specific than naming a skill.
List<ComposerCommand> mergeComposerCommands({
  required List<ComposerCommand> client,
  required List<AgentCommandDto> agent,
  required List<SkillSummaryDto> skills,
}) {
  final resolved = <String, ComposerCommand>{};

  for (final skill in skills) {
    // Implicit skills are injected into every turn already, so offering them
    // here would only duplicate what the agent has.
    if (skill.isImplicit) continue;
    final name = skill.name.trim().isEmpty ? skill.id : skill.name.trim();
    resolved[name] = ComposerCommand(
      id: 'skill:${skill.id}',
      name: name,
      description: skill.description,
      kind: ComposerCommandKind.skill,
    );
  }

  for (final command in agent) {
    resolved[command.name] = ComposerCommand(
      id: 'agent:${command.id}',
      name: command.name,
      description: command.description,
      kind: ComposerCommandKind.agent,
      argumentHint: command.argumentHint,
      promptTemplate: command.body,
    );
  }

  for (final command in client) {
    resolved[command.name] = command;
  }

  final commands = resolved.values.toList()
    ..sort((left, right) => left.name.compareTo(right.name));
  return List<ComposerCommand>.unmodifiable(commands);
}

/// Hides the app commands a composer cannot carry out.
///
/// A composer that has no session yet cannot start another one, and offering
/// an action that would do nothing is worse than not offering it. Only client
/// commands are eligible: a skill or agent command named after an action is
/// authored on disk and stays.
List<ComposerCommand> withoutClientActions(
  List<ComposerCommand> commands,
  Set<ClientCommandAction> excluded,
) {
  if (excluded.isEmpty) return commands;
  return List<ComposerCommand>.unmodifiable(
    commands.where(
      (command) =>
          command.kind != ComposerCommandKind.client ||
          !excluded.contains(command.action),
    ),
  );
}

/// One command ranked against a `/` query, with its highlight spans.
@immutable
final class RankedComposerCommand {
  /// Creates a ranked command.
  const new({required this.command, required this.match});

  /// The command itself.
  final ComposerCommand command;

  /// Score and highlight indices into [ComposerCommand.name].
  final FuzzyMatch match;
}

/// Ranks [all] against a `/` query, dropping entries that cannot match.
List<RankedComposerCommand> rankComposerCommands(
  List<ComposerCommand> all,
  String query,
) {
  final ranked = <RankedComposerCommand>[];
  for (final command in all) {
    final match = fuzzyMatch(command.name, query);
    if (match == null) continue;
    ranked.add(RankedComposerCommand(command: command, match: match));
  }
  ranked.sort(
    (left, right) => compareFuzzyCandidates(
      left.match,
      left.command.name,
      right.match,
      right.command.name,
    ),
  );
  return List<RankedComposerCommand>.unmodifiable(ranked);
}

/// One resolved `/name args` submission.
@immutable
final class ComposerCommandInvocation {
  /// Creates an invocation.
  const new({required this.command, required this.arguments});

  /// The command the message named.
  final ComposerCommand command;

  /// Everything after the command name, trimmed.
  final String arguments;

  @override
  bool operator ==(Object other) =>
      other is ComposerCommandInvocation &&
      other.command == command &&
      other.arguments == arguments;

  @override
  int get hashCode => Object.hash(command, arguments);
}

/// Resolves a whole message that names a command, or null when it does not.
///
/// The match is on the exact name so a typo is sent as prose rather than
/// silently running a command the user did not choose. A leading space is the
/// escape hatch for sending literal slash text.
ComposerCommandInvocation? parseComposerCommand(
  String text,
  List<ComposerCommand> commands,
) {
  if (!text.startsWith('/')) return null;
  final body = text.substring(1);
  if (body.isEmpty) return null;

  final separator = body.indexOf(RegExp(r'\s'));
  final name = separator < 0 ? body : body.substring(0, separator);
  final arguments = separator < 0 ? '' : body.substring(separator + 1).trim();
  if (name.isEmpty) return null;

  for (final command in commands) {
    if (command.name == name) {
      return ComposerCommandInvocation(command: command, arguments: arguments);
    }
  }
  return null;
}

/// Expands a leading skill or agent command into the prompt actually sent.
///
/// A client command never reaches here; the composer dispatches it before it
/// would submit. Anything unrecognized is returned verbatim so ordinary prose
/// that happens to start with a slash still sends.
String renderComposerPrompt(String text, List<ComposerCommand> commands) {
  final invocation = parseComposerCommand(text.trim(), commands);
  if (invocation == null) return text;

  final command = invocation.command;
  final arguments = invocation.arguments;
  return switch (command.kind) {
    ComposerCommandKind.client => text,
    ComposerCommandKind.skill =>
      arguments.isEmpty
          ? 'Use the "${command.name}" skill.'
          : 'Use the "${command.name}" skill.\n\n$arguments',
    ComposerCommandKind.agent => _expandTemplate(
      command.promptTemplate!,
      arguments,
    ),
  };
}

/// Substitutes `$ARGUMENTS` and `$1`..`$9`, leaving unknown markers alone.
String _expandTemplate(String template, String arguments) {
  final positional = arguments.isEmpty
      ? const <String>[]
      : arguments.split(RegExp(r'\s+'));
  var expanded = template.replaceAll(r'$ARGUMENTS', arguments);
  for (var index = 1; index <= 9; index += 1) {
    final value = index <= positional.length ? positional[index - 1] : '';
    expanded = expanded.replaceAll('\$$index', value);
  }
  return expanded;
}
