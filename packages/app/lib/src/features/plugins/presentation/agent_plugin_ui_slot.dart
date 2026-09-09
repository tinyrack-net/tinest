import 'dart:async';

import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/app/app_identity.dart';
import 'package:app/src/features/plugins/application/plugin_settings_controller.dart';
import 'package:app/src/features/plugins/presentation/plugin_ui_document_view.dart';
import 'package:app/src/features/sessions/application/sessions_controller.dart';
import 'package:app/src/shared/presentation/client_error_alert.dart';
import 'package:client/client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Renders every declarative UI contribution owned by an Agent in one slot.
///
/// Contribution order follows the Agent harness: driver, ordered extensions,
/// tools, and finally plugins referenced only by settings. The host owns the
/// loading/error boundary and all native widgets; plugins only provide data.
class AgentPluginUiSlot extends ConsumerStatefulWidget {
  /// Creates an Agent-scoped plugin surface.
  const new({
    required this.hostId,
    required this.agent,
    required this.slot,
    this.context = const <String, dynamic>{},
    this.onIntent,
    this.maxContentHeight,
    super.key,
  });

  /// Runs host-owned intents raised by documents in this slot.
  final PluginUiIntentHandler? onIntent;

  /// Bound this slot places on scrollable document content.
  final double? maxContentHeight;

  /// Daemon that owns the Agent and plugin catalog.
  final String hostId;

  /// Agent harness whose explicit references activate plugins.
  final AgentDefinitionDto agent;

  /// Host-owned native surface being rendered.
  final PluginUiSlot slot;

  /// Immutable session/workspace data offered to render handlers.
  final Map<String, dynamic> context;

  @override
  ConsumerState<AgentPluginUiSlot> createState() => _AgentPluginUiSlotState();
}

class _AgentPluginUiSlotState extends ConsumerState<AgentPluginUiSlot> {
  /// Contributions that reported they have nothing to show.
  ///
  /// A surface answers on its own schedule, so this column cannot know which
  /// of its children drew anything until each has loaded. It needs to know,
  /// because a separator above or below a surface that drew nothing is a gap
  /// with no reason to exist.
  final Set<String> _silent = <String>{};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // A plugin owns the strings it draws, so it has to be told which language
    // to draw them in. That is a fact about the surface, not about any one
    // call site, so it is added here rather than at every mount.
    final renderContext = <String, dynamic>{
      ...widget.context,
      'locale': Localizations.localeOf(context).toLanguageTag(),
    };
    final state = ref.watch(pluginSettingsControllerProvider(widget.hostId));
    return state.when(
      skipLoadingOnRefresh: true,
      data: (catalog) {
        final pluginsById = <String, PluginDescriptorDto>{
          for (final plugin in catalog.plugins) plugin.id: plugin,
        };
        final contributions =
            <
              ({PluginDescriptorDto plugin, PluginContributionDto contribution})
            >[];
        for (final pluginId in _orderedPluginIds(widget.agent)) {
          final plugin = pluginsById[pluginId];
          if (plugin == null) continue;
          for (final contribution in plugin.contributions) {
            if (contribution.kind == PluginContributionKind.ui &&
                _slots(contribution).contains(widget.slot.name)) {
              contributions.add((plugin: plugin, contribution: contribution));
            }
          }
        }
        if (contributions.isEmpty) return const SizedBox.shrink();
        // A surface that reads live host state declares it, and only such a
        // surface pays for the watch. The revision travels in the render
        // context, which the surface already reloads on, so no separate
        // invalidation channel is needed.
        final watchesSessionTree = contributions.any(
          (entry) =>
              _dependencies(entry.contribution)
                  .contains(_sessionTreeDependency),
        );
        final sessionTree = watchesSessionTree
            ? ref
                  .watch(
                    sessionsControllerProvider(
                      widget.hostId,
                      widget.context['worktreeId'] as String?,
                    ),
                  )
                  .value
            : null;
        final sessionTreeRevision = sessionTree == null
            ? null
            : _sessionTreeRevisionOf(
                sessionTree,
                widget.context['sessionId'] as String?,
              );
        final surfaces = <Widget>[];
        var drew = false;
        for (final entry in contributions) {
          final key =
              'agent-plugin-ui-${widget.slot.name}-'
              '${entry.plugin.id}-${entry.contribution.id}';
          final silent = _silent.contains(key);
          final declared = _dependencies(entry.contribution);
          // Rendering a tree surface before the tree is known would answer
          // from an empty list and then immediately render again once it
          // arrives, costing two round trips for one panel.
          if (declared.contains(_sessionTreeDependency) &&
              sessionTreeRevision == null) {
            continue;
          }
          surfaces.add(
            PluginUiContributionSurface(
              key: ValueKey<String>(key),
              hostId: widget.hostId,
              agentId: widget.agent.id,
              plugin: entry.plugin,
              contribution: entry.contribution,
              slot: widget.slot,
              // The gap belongs to the surface that follows a visible one, so
              // a silent contribution never leaves its separator behind.
              leadingSpacing: !silent && drew ? TRSpacing.small : 0,
              onSilentChanged: (value) => _reportSilent(key, silent: value),
              onIntent: widget.onIntent,
              maxContentHeight: widget.maxContentHeight,
              context: <String, dynamic>{
                ...renderContext,
                if (declared.contains(_sessionTreeDependency))
                  'sessionTreeRevision': sessionTreeRevision,
              },
            ),
          );
          drew = drew || !silent;
        }
        return Column(
          key: ValueKey<String>('agent-plugin-ui-${widget.slot.name}'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: surfaces,
        );
      },
      // Most Agents contribute to most slots, so a slot that announced itself
      // while the catalog loads would flash a progress bar and then usually
      // collapse to nothing. Waiting silently also keeps a host surface that
      // hosts several slots — the composer header — from growing a stack of
      // them the moment a daemon drops.
      loading: () => const SizedBox.shrink(),
      error: (error, _) => _isExpectedAbsence(error)
          ? const SizedBox.shrink()
          : ClientErrorAlert(
              error: _clientError(error),
              title: l10n.pluginUiLoadFailed,
            ),
    );
  }

  void _reportSilent(String key, {required bool silent}) {
    if (silent == _silent.contains(key)) return;
    setState(() => silent ? _silent.add(key) : _silent.remove(key));
  }
}

/// Presents any slot failure as the daemon failure the alert knows how to read.
///
/// A daemon failure already carries the code and trace id [ClientErrorAlert]
/// translates. Anything else came from this app, so it is wrapped without a
/// code, which makes the alert fall back to the original text rather than
/// claiming a daemon fault the daemon never reported.
TinestClientException _clientError(Object error) =>
    error is TinestClientException
    ? error
    : TinestClientException(error is Error ? '$error' : error.toString());

/// Whether [error] means the slot has nothing to show rather than that it
/// failed.
///
/// Two ways a slot legitimately has no answer. An Agent pins its plugin
/// revisions when a turn starts, so every slot on a session that has never run
/// reports an unavailable revision; that is the ordinary state of a new
/// session, not a fault. And a dropped daemon is the app's own state, reported
/// as a [StateError] rather than a daemon failure — the connection chrome
/// already says so, and a plugin surface has nothing to add. Reporting either
/// would put a red panel beside the composer, once per slot.
bool _isExpectedAbsence(Object error) =>
    error is StateError ||
    (error is TinestClientException &&
        error.code == RpcErrorCodes.pluginRevisionUnavailable);

/// Loads and renders one declared UI contribution through the public RPC.
class PluginUiContributionSurface extends ConsumerStatefulWidget {
  /// Creates one pinned plugin UI contribution surface.
  const new({
    required this.hostId,
    required this.agentId,
    required this.plugin,
    required this.contribution,
    required this.slot,
    this.leadingSpacing = 0,
    this.onSilentChanged,
    this.onIntent,
    this.maxContentHeight,
    this.context = const <String, dynamic>{},
    super.key,
  });

  /// Runs host-owned intents raised by this document.
  final PluginUiIntentHandler? onIntent;

  /// Bound the slot places on scrollable document content.
  final double? maxContentHeight;

  /// Daemon profile owning the plugin runtime.
  final String hostId;

  /// Agent whose grants and harness scope the contribution.
  final String agentId;

  /// Plugin descriptor containing [contribution].
  final PluginDescriptorDto plugin;

  /// Exact UI contribution to invoke.
  final PluginContributionDto contribution;

  /// Host-owned surface requested from the contribution.
  final PluginUiSlot slot;

  /// Gap kept above this surface when it draws anything at all.
  final double leadingSpacing;

  /// Reports whether this surface currently draws nothing at all.
  ///
  /// Only the surface knows: the answer arrives with the render, and it
  /// changes again whenever the contribution is asked a second time.
  final ValueChanged<bool>? onSilentChanged;

  /// Immutable render context supplied by the host.
  final Map<String, dynamic> context;

  @override
  ConsumerState<PluginUiContributionSurface> createState() =>
      _PluginUiContributionSurfaceState();
}

class _PluginUiContributionSurfaceState
    extends ConsumerState<PluginUiContributionSurface> {
  PluginUiDocumentDto? _document;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(PluginUiContributionSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hostId != widget.hostId ||
        oldWidget.agentId != widget.agentId ||
        oldWidget.plugin.revision?.contentHash !=
            widget.plugin.revision?.contentHash ||
        oldWidget.contribution != widget.contribution ||
        oldWidget.slot != widget.slot ||
        !mapEquals(oldWidget.context, widget.context)) {
      unawaited(_load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final document = _document;
    if (_error case final error?) {
      if (_isExpectedAbsence(error)) return const SizedBox.shrink();
      return _spaced(
        ClientErrorAlert(
          error: _clientError(error),
          title: l10n.pluginUiLoadFailed,
          onRetry: () => unawaited(_load()),
        ),
      );
    }
    if (document == null) {
      return _spaced(TRProgress(label: l10n.pluginUiLoading));
    }
    // A contribution with nothing to report answers with an empty document.
    // Framing it would leave a bare panel on the surface it renders into.
    if (pluginUiDocumentIsEmpty(document)) return const SizedBox.shrink();
    return _spaced(
      PluginUiDocumentView(
        document: document,
        semanticLabel: l10n.pluginUiSemanticLabel(widget.plugin.name),
        invalidDocumentLabel: l10n.pluginUiInvalidTitle,
        invalidDocumentDescription: l10n.pluginUiInvalidDescription(
          AppIdentity.displayName,
        ),
        onAction: _dispatch,
        onIntent: widget.onIntent,
        maxContentHeight: widget.maxContentHeight,
      ),
    );
  }

  Widget _spaced(Widget child) => widget.leadingSpacing == 0
      ? child
      : Padding(
          padding: EdgeInsets.only(top: widget.leadingSpacing),
          child: child,
        );

  /// Whether the current state paints nothing on the host surface.
  bool get _isSilent {
    if (_error case final error?) return _isExpectedAbsence(error);
    final document = _document;
    return document != null && pluginUiDocumentIsEmpty(document);
  }

  Future<void> _load() async {
    // A refresh keeps whatever is already rendered. The conversation slot sits
    // between the transcript and the composer and re-renders on every turn
    // boundary, so collapsing to the spinner and back would change the
    // timeline's viewport height twice per turn. A surface that declares a
    // dependency refreshes more often still, and tearing its subtree down
    // takes the reader's own state with it — a drawer they had expanded would
    // snap shut the moment a subagent finished. Only a first load, or one
    // retrying past an error, has nothing to hold on to.
    if (mounted && (_document == null || _error != null)) {
      setState(() {
        _document = null;
        _error = null;
      });
    }
    try {
      final document = await ref
          .read(pluginSettingsControllerProvider(widget.hostId).notifier)
          .renderUi(
            agentId: widget.agentId,
            pluginId: widget.plugin.id,
            contributionId: widget.contribution.id,
            slot: widget.slot,
            context: widget.context,
          );
      if (mounted) setState(() => _document = document);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
    if (mounted) widget.onSilentChanged?.call(_isSilent);
  }

  Future<PluginUiDocumentDto> _dispatch(PluginUiActionDto action) async {
    try {
      final document = await ref
          .read(pluginSettingsControllerProvider(widget.hostId).notifier)
          .dispatchUi(
            agentId: widget.agentId,
            pluginId: widget.plugin.id,
            action: action,
          );
      if (mounted) {
        setState(() => _document = document);
        widget.onSilentChanged?.call(_isSilent);
      }
      return document;
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error);
        widget.onSilentChanged?.call(_isSilent);
      }
      return _document!;
    }
  }
}

List<String> _orderedPluginIds(AgentDefinitionDto agent) {
  final ordered = <String>[];
  final seen = <String>{};
  void add(String contributionId) {
    final id = pluginIdForContribution(contributionId);
    if (id.isNotEmpty && seen.add(id)) ordered.add(id);
  }

  add(agent.driverId);
  agent.extensionIds.forEach(add);
  agent.toolIds.forEach(add);
  agent.pluginSettings.keys.forEach(add);
  return ordered;
}

Set<String> _slots(PluginContributionDto contribution) {
  final value = contribution.metadata['slots'];
  return value is List<Object?>
      ? value.whereType<String>().toSet()
      : const <String>{};
}

/// Live host state a contribution declared it reads, from `depends_on`.
Set<String> _dependencies(PluginContributionDto contribution) {
  final value = contribution.metadata['dependsOn'];
  return value is List<Object?>
      ? value.whereType<String>().toSet()
      : const <String>{};
}

/// The declared dependency naming the caller's collaboration tree.
const String _sessionTreeDependency = 'session_tree';

/// A revision that changes exactly when the tree under [sessionId] does.
///
/// Only what a surface could draw is folded in — identity, parentage, label,
/// and both status axes — so an unrelated write elsewhere in the worktree does
/// not make every declared surface render again.
String _sessionTreeRevisionOf(List<SessionDto> sessions, String? sessionId) {
  if (sessionId == null) return '';
  final current = sessions.where((item) => item.id == sessionId).firstOrNull;
  final rootId = current?.rootSessionId ?? sessionId;
  final members =
      sessions
          .where((item) => item.id == rootId || item.rootSessionId == rootId)
          .map(
            (item) => <String?>[
              item.id,
              item.parentSessionId,
              item.taskName ?? item.title,
              item.lifecycle?.name,
              item.status.name,
            ].join(':'),
          )
          .toList(growable: false)
        ..sort();
  return members.join('|');
}
