/// One skill that ships inside the daemon binary.
///
/// Built-ins have no files on disk, so they carry prose only. An implicit
/// built-in is always injected and cannot be shadowed by a filesystem skill.
final class BuiltInSkill {
  /// Creates a built-in skill.
  const new({
    required this.id,
    required this.name,
    required this.description,
    required this.body,
    this.isImplicit = false,
  });

  /// Stable identifier shared with user-authored skills.
  final String id;

  /// Name the model loads the skill by.
  final String name;

  /// One-line catalog description.
  final String description;

  /// Markdown instructions handed to the model on demand.
  final String body;

  /// Whether the skill is injected implicitly and cannot be shadowed.
  final bool isImplicit;
}

/// Skills every daemon offers before any user directory is read.
const List<BuiltInSkill> builtInSkills = <BuiltInSkill>[
  BuiltInSkill(
    id: 'coding-conventions',
    name: 'coding-conventions',
    description:
        'How to match a codebase: read neighbouring code first, follow its '
        'naming and structure, and keep changes scoped.',
    body: '''
Before writing code, read the files around the change and match what they do.

- Reuse the helpers, ports, and error types the surrounding code already has
  instead of introducing parallel ones.
- Match the existing naming, file layout, comment density, and test style. A
  reviewer should not be able to tell which lines are new from style alone.
- Keep the change scoped to the request. Unrelated cleanups belong in their
  own change.
- Read a file before editing it, and validate the behaviour you changed before
  reporting the work as done.
''',
    isImplicit: true,
  ),
  BuiltInSkill(
    id: 'commit',
    name: 'commit',
    description:
        'How to split work into atomic commits and write messages that '
        'explain the reason for the change.',
    body: '''
Split the work by purpose, then commit each purpose on its own.

- One commit per intent: a feature, a fix, a refactor, and a formatting sweep
  are four commits, not one.
- Read `git log` first and match the repository's existing subject style.
- Write the subject as what the change does in the imperative mood; use the
  body to explain why it was needed, not to restate the diff.
- Never commit unrelated files that happen to be dirty in the worktree.
''',
  ),
];
