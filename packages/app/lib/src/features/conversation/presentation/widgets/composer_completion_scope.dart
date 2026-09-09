import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/features/conversation/application/agent_commands_controller.dart';
import 'package:app/src/features/conversation/application/composer_controller.dart';
import 'package:app/src/features/conversation/application/composer_suggestions.dart';
import 'package:app/src/features/conversation/domain/composer_commands.dart';
import 'package:app/src/features/conversation/presentation/composer_trigger.dart';
import 'package:app/src/features/conversation/presentation/widgets/composer_suggestions_overlay.dart';
import 'package:app/src/features/skills/application/skills_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';

/// Everything a composer needs to offer completions for one worktree.
@immutable
final class ComposerCompletion {
  /// Creates a completion bundle.
  const new({
    required this.commands,
    required this.suggestions,
    required this.onQueryChanged,
  });

  /// The `/` catalog, used both to rank rows and to resolve a submission.
  final List<ComposerCommand> commands;

  /// Rows for the token being completed right now.
  final ComposerSuggestionsState suggestions;

  /// Reports the token under the caret.
  final ValueChanged<ComposerTrigger?> onQueryChanged;
}

/// Owns the active completion token for one composer.
///
/// Every composer needs the same three things, so this keeps the token state
/// and the provider reads in one place rather than in each host screen.
class ComposerCompletionScope extends ConsumerStatefulWidget {
  /// Creates a completion scope.
  const new({
    required this.hostId,
    required this.builder,
    this.workspaceId,
    this.worktreeId,
    this.excludedClientActions = const <ClientCommandAction>{},
    super.key,
  });

  /// Daemon the catalogs come from.
  final String hostId;

  /// Workspace whose project commands layer over the global ones.
  final String? workspaceId;

  /// Worktree searched for file mentions; null offers commands only.
  final String? worktreeId;

  /// App actions this composer cannot carry out, hidden from the catalog.
  final Set<ClientCommandAction> excludedClientActions;

  /// Builds the composer with the resolved completion state.
  final Widget Function(BuildContext context, ComposerCompletion completion)
  builder;

  @override
  ConsumerState<ComposerCompletionScope> createState() =>
      _ComposerCompletionScopeState();
}

class _ComposerCompletionScopeState
    extends ConsumerState<ComposerCompletionScope> {
  ComposerTrigger? _trigger;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The app's own commands always exist; the daemon-provided ones layer on
    // once its catalogs load, so the list is never empty while offline.
    // Filtering here rather than at the call site keeps the offered rows and
    // the catalog the composer parses a submission against in step.
    //
    // The two catalogs are merged here rather than behind a derived provider
    // on purpose. A composer sits inside the page's LayoutBuilder, so this
    // build can run during layout; a derived provider watching these two would
    // invalidate itself as a host connects or disconnects and ask the scope to
    // rebuild mid-layout, which Flutter rejects. Watching the sources directly
    // keeps the invalidation on the widget side, where a rebuild is legal.
    final commands = withoutClientActions(
      mergeComposerCommands(
        client: localizedClientCommands(l10n),
        agent:
            ref
                .watch(
                  agentCommandsControllerProvider(
                    widget.hostId,
                    widget.workspaceId,
                  ),
                )
                .value ??
            const <AgentCommandDto>[],
        skills:
            ref
                .watch(
                  skillsControllerProvider(
                    widget.hostId,
                    SkillListView.effective,
                    widget.workspaceId,
                  ),
                )
                .value ??
            const <SkillSummaryDto>[],
      ),
      widget.excludedClientActions,
    );

    return widget.builder(
      context,
      ComposerCompletion(
        commands: commands,
        suggestions: _suggestions(commands, l10n),
        onQueryChanged: (trigger) => setState(() => _trigger = trigger),
      ),
    );
  }

  /// A command list is local and settles at once; a file list reaches the
  /// daemon, so its loading and failed states are surfaced to the overlay.
  ComposerSuggestionsState _suggestions(
    List<ComposerCommand> commands,
    AppLocalizations l10n,
  ) {
    final trigger = _trigger;
    if (trigger == null) return ComposerSuggestionsState.closed;

    if (trigger.kind == ComposerTriggerKind.command) {
      return ComposerSuggestionsState(
        trigger: trigger,
        items: commandSuggestions(
          commands,
          trigger.query,
          badgeOf: (kind) => composerCommandBadge(l10n, kind),
        ),
      );
    }

    final worktreeId = widget.worktreeId;
    if (worktreeId == null) return ComposerSuggestionsState.closed;
    final search = ref.watch(
      composerFileSearchProvider(widget.hostId, worktreeId, trigger.query),
    );
    return ComposerSuggestionsState(
      trigger: trigger,
      items: fileSuggestions(
        search.value ?? const <FileMatchDto>[],
        trigger.query,
      ),
      loading: search.isLoading,
      failed: search.hasError,
    );
  }
}
