import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/features/conversation/application/composer_suggestions.dart';
import 'package:app/src/features/conversation/domain/composer_commands.dart';
import 'package:app/src/features/conversation/presentation/composer_trigger.dart';
import 'package:flutter/widgets.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// What the composer knows about the completion list right now.
@immutable
final class ComposerSuggestionsState {
  /// Creates a suggestions state.
  const new({
    this.trigger,
    this.items = const <ComposerSuggestion>[],
    this.loading = false,
    this.failed = false,
  });

  /// Nothing is being completed.
  static const ComposerSuggestionsState closed = ComposerSuggestionsState();

  /// The token being completed, or null when the list is closed.
  final ComposerTrigger? trigger;

  /// Rows to offer, already filtered and ordered.
  final List<ComposerSuggestion> items;

  /// Whether a search for this token is still in flight.
  final bool loading;

  /// Whether the search for this token failed.
  final bool failed;

  /// Whether the overlay should be on screen.
  bool get isOpen => trigger != null;
}

/// The composer's completion list, wrapping the design system's overlay.
///
/// Everything Tinest-specific stays here: which strings label the empty and
/// failed rows, and which badge names a command's source. The list, its
/// highlight, and its keyboard contract belong to `TRInlineSuggestions`.
class ComposerSuggestionsOverlay extends StatelessWidget {
  /// Creates the composer's completion overlay.
  const new({
    required this.state,
    required this.controller,
    required this.onSelected,
    required this.onDismissed,
    required this.child,
    super.key,
  });

  /// The active token and its rows.
  final ComposerSuggestionsState state;

  /// Owns the highlight and the key contract; the composer forwards keys to it.
  final TRInlineSuggestionsController<String> controller;

  /// Reports the committed row so the composer can splice its text.
  final ValueChanged<ComposerSuggestion> onSelected;

  /// Reports a dismissal so the composer can stop offering this token.
  final VoidCallback onDismissed;

  /// The composer's own input subtree.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isCommand = state.trigger?.kind == ComposerTriggerKind.command;
    final byId = <String, ComposerSuggestion>{
      for (final item in state.items) item.id: item,
    };

    return TRInlineSuggestions<String>(
      open: state.isOpen,
      sessionKey: state.trigger?.sessionKey,
      controller: controller,
      status: switch ((state.failed, state.loading)) {
        (true, _) => TRInlineSuggestionsStatus.error,
        (_, true) => TRInlineSuggestionsStatus.loading,
        _ => TRInlineSuggestionsStatus.ready,
      },
      emptyLabel: isCommand
          ? l10n.composerCommandsEmpty
          : l10n.composerFilesEmpty,
      loadingLabel: l10n.composerFilesSearching,
      errorLabel: isCommand
          ? l10n.composerCommandsError
          : l10n.composerFilesError,
      semanticLabel: l10n.composerSuggestionsLabel,
      onDismissed: onDismissed,
      onSelected: (item) {
        final selected = byId[item.value];
        if (selected != null) onSelected(selected);
      },
      items: <TRInlineSuggestionItem<String>>[
        for (final item in state.items)
          TRInlineSuggestionItem<String>(
            value: item.id,
            label: item.label,
            description: item.description.isEmpty ? null : item.description,
            hint: item.hint,
            tag: item.badge,
            matchedIndices: item.matchedIndices,
          ),
      ],
      child: child,
    );
  }
}

/// Names the source of a `/` row for the reader.
String composerCommandBadge(AppLocalizations l10n, ComposerCommandKind kind) =>
    switch (kind) {
      ComposerCommandKind.client => l10n.composerCommandSourceClient,
      ComposerCommandKind.agent => l10n.composerCommandSourceAgent,
      ComposerCommandKind.skill => l10n.composerCommandSourceSkill,
    };

/// Localizes the app-owned commands, whose const list carries English defaults.
List<ComposerCommand> localizedClientCommands(AppLocalizations l10n) =>
    <ComposerCommand>[
      for (final command in clientComposerCommands)
        ComposerCommand(
          id: command.id,
          name: _clientName(l10n, command.action!),
          description: _clientDescription(l10n, command.action!),
          kind: command.kind,
          argumentHint: command.argumentHint,
          action: command.action,
        ),
    ];

String _clientName(AppLocalizations l10n, ClientCommandAction action) =>
    switch (action) {
      ClientCommandAction.clear => l10n.composerCommandClearLabel,
      ClientCommandAction.newSession => l10n.composerCommandNewLabel,
      ClientCommandAction.openAgentSettings => l10n.composerCommandAgentsLabel,
      ClientCommandAction.openSkillSettings => l10n.composerCommandSkillsLabel,
      ClientCommandAction.help => l10n.composerCommandHelpLabel,
    };

String _clientDescription(AppLocalizations l10n, ClientCommandAction action) =>
    switch (action) {
      ClientCommandAction.clear => l10n.composerCommandClearDescription,
      ClientCommandAction.newSession => l10n.composerCommandNewDescription,
      ClientCommandAction.openAgentSettings =>
        l10n.composerCommandAgentsDescription,
      ClientCommandAction.openSkillSettings =>
        l10n.composerCommandSkillsDescription,
      ClientCommandAction.help => l10n.composerCommandHelpDescription,
    };
