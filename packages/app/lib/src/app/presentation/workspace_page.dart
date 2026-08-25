import 'dart:async';

import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/app/app_identity.dart';
import 'package:app/src/app/presentation/new_workspace_pane.dart';
import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/features/agents/application/agent_definitions_controller.dart';
import 'package:app/src/features/conversation/application/attachment_ports.dart';
import 'package:app/src/features/conversation/application/chat_timeline_model.dart';
import 'package:app/src/features/conversation/application/conversation_controller.dart';
import 'package:app/src/features/conversation/application/conversation_timeline_controller.dart';
import 'package:app/src/features/conversation/application/pending_turns_controller.dart';
import 'package:app/src/features/conversation/application/subagent_track_model.dart';
import 'package:app/src/features/conversation/domain/composer_commands.dart';
import 'package:app/src/features/conversation/presentation/chat_timeline_view.dart';
import 'package:app/src/features/conversation/presentation/reading_positions_controller.dart';
import 'package:app/src/features/conversation/presentation/subagents/subagent_approval_banner.dart';
import 'package:app/src/features/conversation/presentation/subagents/subagent_status_icon.dart';
import 'package:app/src/features/conversation/presentation/widgets/composer_completion_scope.dart';
import 'package:app/src/features/conversation/presentation/widgets/session_composer.dart';
import 'package:app/src/features/hosts/application/host_controller.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/models/application/model_settings_controller.dart';
import 'package:app/src/features/plugins/application/plugin_settings_controller.dart';
import 'package:app/src/features/plugins/application/plugin_ui_events.dart';
import 'package:app/src/features/plugins/presentation/agent_plugin_session_controls.dart';
import 'package:app/src/features/plugins/presentation/agent_plugin_ui_slot.dart';
import 'package:app/src/features/plugins/presentation/plugin_ui_document_view.dart';
import 'package:app/src/features/providers/application/provider_settings_controller.dart';
import 'package:app/src/features/providers/application/session_model_options.dart';
import 'package:app/src/features/sessions/application/session_tabs_controller.dart';
import 'package:app/src/features/sessions/application/sessions_controller.dart';
import 'package:app/src/features/terminals/application/terminal_session_controller.dart';
import 'package:app/src/features/terminals/application/terminal_session_leases.dart';
import 'package:app/src/features/terminals/application/terminals_controller.dart';
import 'package:app/src/features/terminals/presentation/tinest_terminal_view.dart';
import 'package:app/src/features/workspace/application/workspace_controller.dart';
import 'package:app/src/features/workspace/presentation/widgets/workspace_sidebar.dart';
import 'package:app/src/shared/presentation/client_error_alert.dart';
import 'package:app/src/shared/presentation/tinest_icons.dart';
import 'package:app/src/shared/presentation/tinest_layout_metrics.dart';
import 'package:app/src/shared/presentation/tinest_page_shell.dart';
import 'package:app/src/shared/presentation/toast_messenger.dart';
import 'package:app/src/shared/presentation/workspace_skeletons.dart';
import 'package:client/client.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:termworld/termworld.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Unified host/repository/worktree tree and session-tab workspace.
class WorkspacePage extends ConsumerStatefulWidget {
  /// Creates a workspace page.
  const WorkspacePage({
    required this.navigator,
    this.selection,
    this.requestedAgentId,
    this.requestedTerminalId,
    this.compose = false,
    super.key,
  });

  /// Navigator built by the typed workspace shell.
  final Widget navigator;

  /// Whether the right pane opens the new-workspace composer directly.
  final bool compose;

  /// Selected checkout, if any.
  final WorkspaceSelection? selection;

  /// Session requested by the route.
  final String? requestedAgentId;

  /// Terminal requested by the route.
  final String? requestedTerminalId;

  @override
  ConsumerState<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends ConsumerState<WorkspacePage> {
  /// Whether this state already queued the saved-worktree restore.
  bool _restoreScheduled = false;
  bool _missingSelectionScheduled = false;
  late final TRTreeNavController<WorkspaceNavValue> _workspaceTreeController;

  @override
  void initState() {
    super.initState();
    final selection = widget.selection;
    _workspaceTreeController = TRTreeNavController<WorkspaceNavValue>(
      expanded: selection == null
          ? const <WorkspaceNavValue>[]
          : <WorkspaceNavValue>[
              (
                hostId: selection.hostId,
                workspaceId: selection.workspaceId,
                worktreeId: null,
              ),
            ],
    );
  }

  @override
  void didUpdateWidget(WorkspacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // One Navigator page now serves every checkout, so this state outlives a
    // selection change and each new checkout needs its own archived check.
    if (widget.selection != oldWidget.selection) {
      _missingSelectionScheduled = false;
    }
    if ((oldWidget.selection != null || oldWidget.compose) &&
        widget.selection == null &&
        !widget.compose) {
      // Returning through Navigator history is an explicit choice. Do not let
      // startup restoration immediately reopen the page that was just closed.
      _restoreScheduled = true;
    }
  }

  @override
  void dispose() {
    _workspaceTreeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Every tab switch persists the pane tree, which re-emits the whole
    // registry. Selecting only what this page renders keeps that write from
    // rebuilding the sidebar beside the tabs. `value` rather than `asData` so
    // a reload keeps showing the registry that is already loaded.
    final hosts = ref.watch(
      hostRegistryControllerProvider.select((value) => value.value?.runtimes),
    );
    final catalog = ref.watch(workspaceCatalogControllerProvider);
    final collapsed = ref.watch(
      hostRegistryControllerProvider.select(
        (value) => value.value?.settings.sidebarCollapsed ?? false,
      ),
    );
    final savedWorktree = ref.watch(
      hostRegistryControllerProvider.select(
        (value) => value.value?.settings.lastWorktree,
      ),
    );
    _restoreSelection(savedWorktree, catalog.value);
    _replaceMissingSelection(catalog.value);
    return LayoutBuilder(
      builder: (context, constraints) => _buildAdaptiveShell(
        context,
        width: constraints.maxWidth,
        hosts: hosts,
        catalog: catalog,
        collapsed: collapsed,
      ),
    );
  }

  Widget _buildAdaptiveShell(
    BuildContext context, {
    required double width,
    required Map<String, HostRuntimeSnapshot>? hosts,
    required AsyncValue<UnifiedWorkspaceCatalogState> catalog,
    required bool collapsed,
  }) {
    final widthClass = TRAdaptiveWidthClass.fromWidth(width);
    final compact = widthClass == TRAdaptiveWidthClass.compact;
    final desktop =
        widthClass == TRAdaptiveWidthClass.large ||
        widthClass == TRAdaptiveWidthClass.extraLarge;
    final showsCompactDetail =
        compact && (widget.selection != null || widget.compose);
    WorkspaceSidebar sidebar({required bool push}) => WorkspaceSidebar(
      hosts: hosts,
      catalog: catalog,
      homeSessions: _homeSessions(catalog.value),
      selected: widget.selection,
      treeController: _workspaceTreeController,
      onNewWorkspace: () => _openNewWorkspaceComposer(push: push),
      onSelect: (selection) => _selectWorktree(selection, push: push),
      onSelectSession: (selection, sessionId) =>
          _selectSession(selection, sessionId, push: push),
      onOpenDaemonSettings: () => unawaited(
        const DaemonSettingsRoute().push<void>(context),
      ),
      onConnectDaemon: () => unawaited(
        const ConnectDaemonRoute().push<void>(context),
      ),
      onArchivedSelection: () => const WorkspaceHomeRoute().replace(context),
    );
    final routedContent = _WorkspaceRouteContentScope(
      compactHome: KeyedSubtree(
        key: const ValueKey<String>('workspace-compact-sidebar-surface'),
        child: sidebar(push: true),
      ),
      onStarted: (selection, session) => _selectSession(selection, session.id),
      child: widget.navigator,
    );
    final effectiveCollapsed = desktop && collapsed;
    return TinestPageShell(
      appBar: TinestPageHeader(
        // Compact Back and the desktop toggle share the one stable
        // navigation position at the very top left.
        leading: showsCompactDetail
            ? TRIconButton(
                key: const ValueKey<String>('workspace-back-button'),
                appearance: TRAppearance.ghost,
                label: MaterialLocalizations.of(
                  context,
                ).backButtonTooltip,
                onPressed: _goBack,
                icon: Icon(TinestIcons.backFor(context)),
              )
            : !desktop
            ? null
            : TRIconButton(
                appearance: TRAppearance.ghost,
                key: const ValueKey('workspace-sidebar-toggle'),
                label: collapsed
                    ? AppLocalizations.of(context).workspaceSidebarExpand
                    : AppLocalizations.of(
                        context,
                      ).workspaceSidebarCollapse,
                onPressed: () => unawaited(_setSidebarCollapsed(!collapsed)),
                icon: Icon(
                  collapsed ? TinestIcons.menu : TinestIcons.menuOpen,
                ),
              ),
        title: TRText.inherit(
          AppLocalizations.of(context).workspacesTitle,
        ),
        actions: <TRIconButton>[
          TRIconButton(
            key: const ValueKey('workspace-settings-button'),
            appearance: TRAppearance.ghost,
            label: AppLocalizations.of(context).settingsTitle,
            onPressed: () {
              if (compact) {
                unawaited(const SettingsHomeRoute().push<void>(context));
                return;
              }
              final hostId = widget.selection?.hostId;
              unawaited(
                hostId == null
                    ? const DaemonSettingsRoute().push<void>(context)
                    : ProviderSettingsRoute(
                        hostId: hostId,
                      ).push<void>(context),
              );
            },
            icon: const Icon(TinestIcons.settings),
          ),
        ],
      ),
      body: effectiveCollapsed
          ? TRAdaptiveLayoutScope(
              widthClass: widthClass,
              child: routedContent,
            )
          : TRAdaptiveNavigationLayout(
              navigationPane: KeyedSubtree(
                key: const ValueKey<String>('workspace-sidebar-surface'),
                child: sidebar(push: false),
              ),
              contentPane: routedContent,
            ),
    );
  }

  void _goBack() {
    final navigator = WorkspaceShellRoute.$navigatorKey.currentState;
    if (navigator?.canPop() != true) {
      const WorkspaceHomeRoute().replace(context);
      return;
    }
    var found = false;
    navigator!.popUntil((route) {
      if (route.settings.name == 'workspace-home') found = true;
      return found || route.isFirst;
    });
    if (!found) const WorkspaceHomeRoute().replace(context);
  }

  void _selectWorktree(
    WorkspaceSelection selection, {
    bool push = false,
  }) {
    ref.read(selectionRestoreControllerProvider.notifier).markConsumed();
    _goWorktree(
      context,
      selection,
      push: push || (widget.selection == null && !widget.compose),
    );
  }

  void _openNewWorkspaceComposer({bool push = false}) {
    ref.read(selectionRestoreControllerProvider.notifier).markConsumed();
    if (push) {
      unawaited(const WorkspaceHomeRoute(compose: true).push<void>(context));
      return;
    }
    const WorkspaceHomeRoute(compose: true).replace(context);
  }

  void _selectSession(
    WorkspaceSelection selection,
    String sessionId, {
    bool push = false,
  }) {
    ref.read(selectionRestoreControllerProvider.notifier).markConsumed();
    _goSession(
      context,
      selection,
      sessionId,
      push: push || (widget.selection == null && !widget.compose),
    );
  }

  /// Gathers the sessions that belong to no project across every daemon.
  ///
  /// Each daemon's home checkout is an ordinary checkout, so this reuses the
  /// same per-checkout session family the session area does rather than adding
  /// a second source of truth.
  AsyncValue<List<HomeSessionEntry>> _homeSessions(
    UnifiedWorkspaceCatalogState? catalog,
  ) {
    if (catalog == null) {
      return const AsyncValue<List<HomeSessionEntry>>.loading();
    }
    final entries = <HomeSessionEntry>[];
    for (final hostId in catalog.catalogs.keys) {
      final selection = catalog.homeSelection(hostId);
      if (selection == null) continue;
      final sessions = ref.watch(
        sessionsControllerProvider(hostId, selection.worktreeId),
      );
      for (final session in sessions.value ?? const <SessionDto>[]) {
        entries.add((selection: selection, session: session));
      }
    }
    return AsyncValue<List<HomeSessionEntry>>.data(sortedHomeSessions(entries));
  }

  Future<void> _setSidebarCollapsed(bool collapsed) => ref
      .read(hostRegistryControllerProvider.notifier)
      .setSidebarCollapsed(collapsed: collapsed);

  void _restoreSelection(
    WorkspaceSelection? saved,
    UnifiedWorkspaceCatalogState? catalog,
  ) {
    // Opening the composer is an explicit choice; never bounce out of it.
    if (widget.compose || widget.selection != null) return;
    if (_restoreScheduled) return;
    if (ref.read(selectionRestoreControllerProvider)) return;
    if (saved == null || catalog == null) return;
    final exists =
        catalog.catalogs[saved.hostId]?.worktrees.any(
          (item) =>
              item.id == saved.worktreeId &&
              item.workspaceId == saved.workspaceId,
        ) ??
        false;
    if (!exists) return;
    // This runs from build, where writing a provider is not allowed, so the
    // restore is both marked and navigated after the frame. The local flag
    // covers the frames in between, which the provider cannot yet reject.
    _restoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(selectionRestoreControllerProvider.notifier).markConsumed();
      // The catalog can finish loading after a pushed task such as Settings
      // has covered this page. Replacing from this stale context would replace
      // that task with a second workspace-shell page, duplicating its Page key
      // in the root Navigator. Opening another task supersedes startup restore.
      if (ModalRoute.of(context)?.isCurrent != true) return;
      _goWorktree(context, saved, push: true);
    });
  }

  void _replaceMissingSelection(UnifiedWorkspaceCatalogState? catalog) {
    final selection = widget.selection;
    if (selection == null || catalog == null || _missingSelectionScheduled) {
      return;
    }
    final hostCatalog = catalog.catalogs[selection.hostId];
    if (hostCatalog == null) return;
    final exists = hostCatalog.worktrees.any(
      (worktree) =>
          worktree.id == selection.worktreeId &&
          worktree.workspaceId == selection.workspaceId,
    );
    if (exists) return;
    _missingSelectionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_confirmMissingSelection(selection));
    });
  }

  Future<void> _confirmMissingSelection(WorkspaceSelection selection) async {
    try {
      await ref
          .read(workspaceCatalogControllerProvider.notifier)
          .refreshHost(selection.hostId);
    } on TinestClientException {
      _missingSelectionScheduled = false;
      return;
    }
    if (!mounted || widget.selection != selection) {
      _missingSelectionScheduled = false;
      return;
    }
    final refreshed = ref.read(workspaceCatalogControllerProvider).value;
    final stillMissing =
        refreshed?.catalogs[selection.hostId]?.worktrees.any(
          (worktree) =>
              worktree.id == selection.worktreeId &&
              worktree.workspaceId == selection.workspaceId,
        ) !=
        true;
    if (stillMissing) {
      const WorkspaceHomeRoute().replace(context);
      return;
    }
    _missingSelectionScheduled = false;
  }
}

/// Child content rendered by the stable typed workspace shell.
class WorkspaceRouteContent extends StatelessWidget {
  /// Creates a workspace child-route surface.
  const WorkspaceRouteContent({
    this.selection,
    this.requestedAgentId,
    this.requestedTerminalId,
    this.compose = false,
    super.key,
  });

  /// Whether this route paints the new-workspace composer.
  final bool compose;

  /// Selected checkout, if any.
  final WorkspaceSelection? selection;

  /// Session requested by the route.
  final String? requestedAgentId;

  /// Terminal requested by the route.
  final String? requestedTerminalId;

  @override
  Widget build(BuildContext context) {
    final selected = selection;
    if (selected == null && !compose) {
      return const _WorkspaceHomeRouteSurface();
    }
    final scope = _WorkspaceRouteContentScope.of(context);
    final widthClass = TRAdaptiveLayoutScope.of(context).widthClass;
    final desktop =
        widthClass == TRAdaptiveWidthClass.large ||
        widthClass == TRAdaptiveWidthClass.extraLarge;
    if (selected == null) {
      return NewWorkspacePane(onStarted: scope.onStarted);
    }
    return _SessionArea(
      // The shared workspace-content Page keeps this State across lateral
      // route replacements for one checkout, while a new checkout starts a
      // fresh tabs/conversation surface.
      key: ValueKey<WorkspaceSelection>(selected),
      selection: selected,
      requestedAgentId: requestedAgentId,
      requestedTerminalId: requestedTerminalId,
      mobile: !desktop,
    );
  }
}

class _WorkspaceHomeRouteSurface extends StatelessWidget {
  const _WorkspaceHomeRouteSurface();

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context)!;
    final secondaryAnimation = route.secondaryAnimation!;
    return AnimatedBuilder(
      animation: secondaryAnimation,
      builder: (context, _) {
        // Direct workspace deep links include a structural home Page under the
        // content Page. Keep that inactive Page lightweight, while preserving
        // its real outgoing surface for push and predictive-Back transitions.
        if (!route.isCurrent && !secondaryAnimation.isAnimating) {
          return const SizedBox.expand();
        }
        final scope = _WorkspaceRouteContentScope.of(context);
        final compact =
            TRAdaptiveLayoutScope.of(context).widthClass ==
            TRAdaptiveWidthClass.compact;
        return compact
            ? scope.compactHome
            : NewWorkspacePane(onStarted: scope.onStarted);
      },
    );
  }
}

class _WorkspaceRouteContentScope extends InheritedWidget {
  const _WorkspaceRouteContentScope({
    required this.compactHome,
    required this.onStarted,
    required super.child,
  });

  final Widget compactHome;
  final void Function(WorkspaceSelection selection, SessionDto session)
  onStarted;

  static _WorkspaceRouteContentScope of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_WorkspaceRouteContentScope>()!;

  @override
  bool updateShouldNotify(_WorkspaceRouteContentScope oldWidget) =>
      compactHome != oldWidget.compactHome || onStarted != oldWidget.onStarted;
}

class _SessionArea extends ConsumerStatefulWidget {
  const _SessionArea({
    required this.selection,
    this.requestedAgentId,
    this.requestedTerminalId,
    this.mobile = false,
    super.key,
  });

  final WorkspaceSelection selection;
  final String? requestedAgentId;
  final String? requestedTerminalId;
  final bool mobile;

  @override
  ConsumerState<_SessionArea> createState() => _SessionAreaState();
}

class _SessionAreaState extends ConsumerState<_SessionArea> {
  // Selecting a session or terminal replaces the location rather than pushing,
  // so this state outlives the change. Remember each opened target so closing
  // a local tab is not immediately undone while the route is being replaced.
  String? _openedAgentId;
  String? _openedTerminalId;
  TinestClientException? _terminalCreationError;

  @override
  Widget build(BuildContext context) {
    final provider = sessionTabsControllerProvider(widget.selection);
    // Roots this checkout's terminal sessions. A listener rather than a watch:
    // it is a non-weak dependent, so it holds the leases, while leaving this
    // widget to rebuild from the tab state it actually renders.
    ref.listen(terminalSessionLeasesProvider(widget.selection), (_, _) {});
    final value = ref.watch(provider);
    final workspace = value.asData?.value;
    _openRequestedRoute(provider, workspace);
    if (workspace == null) {
      return WorkspacePaneSkeleton(
        semanticLabel: AppLocalizations.of(context).workspaceLoading,
      );
    }
    final content = widget.mobile
        ? _buildMobile(context, workspace)
        : _buildNode(context, workspace, workspace.root);
    final error = _terminalCreationError;
    if (error == null) return content;
    final l10n = AppLocalizations.of(context);
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(TRSpacing.small),
          child: TRAlert(
            key: const ValueKey<String>('terminal-creation-error'),
            variant: TRStatusVariant.danger,
            title: TRText.inherit(l10n.terminalCreationFailed),
            description: TRText.inherit(clientErrorText(l10n, error)),
          ),
        ),
        Expanded(child: content),
      ],
    );
  }

  void _openRequestedRoute(
    SessionTabsControllerProvider provider,
    SessionTabsState? workspace,
  ) {
    if (widget.requestedAgentId != null &&
        widget.requestedAgentId != _openedAgentId &&
        workspace != null &&
        workspace.sessions.any((item) => item.id == widget.requestedAgentId)) {
      _openedAgentId = widget.requestedAgentId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(ref.read(provider.notifier).open(widget.requestedAgentId!));
        }
      });
    }
    if (widget.requestedTerminalId != null &&
        widget.requestedTerminalId != _openedTerminalId &&
        workspace != null &&
        workspace.terminals.any(
          (item) => item.id == widget.requestedTerminalId,
        )) {
      _openedTerminalId = widget.requestedTerminalId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(
            ref
                .read(provider.notifier)
                .openTerminal(widget.requestedTerminalId!),
          );
        }
      });
    }
  }

  Widget _buildNode(
    BuildContext context,
    SessionTabsState workspace,
    WorkspacePaneNode node,
  ) => switch (node) {
    PaneNode() => _buildPane(context, workspace, node),
    WorkspaceSplitNode() => TRSplitView(
      key: ValueKey<String>('workspace-split-${node.id}'),
      axis: node.axis == WorkspaceSplitAxis.horizontal
          ? Axis.horizontal
          : Axis.vertical,
      ratio: node.ratio,
      separatorLabel: AppLocalizations.of(context).workspaceResizePanes,
      onRatioChanged: (ratio) => unawaited(
        ref
            .read(sessionTabsControllerProvider(widget.selection).notifier)
            .resize(node.id, ratio),
      ),
      onRatioChangeEnd: (_) => unawaited(
        ref
            .read(sessionTabsControllerProvider(widget.selection).notifier)
            .commitResize(),
      ),
      first: _buildNode(context, workspace, node.first),
      second: _buildNode(context, workspace, node.second),
    ),
  };

  Widget _buildPane(
    BuildContext context,
    SessionTabsState workspace,
    PaneNode pane,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final canSplitRight =
          workspace.panes.length < 2 &&
          constraints.maxWidth >= TRMeasurements.splitPaneMinExtent * 2;
      final firstPane = pane.id == workspace.panes.first.id;
      return KeyedSubtree(
        key: const ValueKey<String>('workspace-pane'),
        child: Column(
          children: <Widget>[
            TRTabs(
              key: ValueKey<String>(
                firstPane
                    ? 'session-tab-strip'
                    : 'session-tab-strip-${pane.id}',
              ),
              tabWidth: TRTabsWidth.fixed,
              semanticLabel: AppLocalizations.of(context).workspaceAllSessions,
              value: _controlValue(workspace.tabs[pane.activeTabId]!),
              onValueChange: (value) => unawaited(
                _activate(
                  pane.id,
                  pane.tabIds.firstWhere(
                    (id) => _controlValue(workspace.tabs[id]!) == value,
                  ),
                ),
              ),
              tabs: <TRTabsTab>[
                for (final tabId in pane.tabIds)
                  _tab(context, workspace, workspace.tabs[tabId]!),
              ],
              dragConfiguration: TRTabsDragConfiguration(
                groupId: pane.id,
                onDrop: (details) => unawaited(_dropTab(workspace, details)),
              ),
              actions: <Widget>[
                _newTabMenu(context, pane.id, firstPane),
                TRIconButton(
                  key: ValueKey<String>(
                    firstPane
                        ? 'workspace-split-right'
                        : 'workspace-split-right-${pane.id}',
                  ),
                  appearance: TRAppearance.ghost,
                  label: AppLocalizations.of(context).workspaceSplitRight,
                  onPressed: canSplitRight
                      ? () => unawaited(
                          _split(pane.id, WorkspaceSplitAxis.horizontal),
                        )
                      : null,
                  icon: const Icon(TinestIcons.splitRight),
                ),
                _allTabsMenu(context, workspace, pane, firstPane),
              ],
            ),
            Expanded(
              child: KeyedSubtree(
                key: ValueKey<String>('workspace-content-${pane.activeTabId}'),
                child: _content(workspace, workspace.tabs[pane.activeTabId]!),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _buildMobile(BuildContext context, SessionTabsState workspace) {
    final entry = workspace.focusedTab!;
    final tabLocations = <({PaneNode pane, String tabId})>[
      for (final pane in workspace.panes)
        for (final tabId in pane.tabIds) (pane: pane, tabId: tabId),
    ];
    return Column(
      children: <Widget>[
        TRTabs(
          key: const ValueKey<String>('workspace-mobile-tab-strip'),
          tabWidth: TRTabsWidth.fixed,
          semanticLabel: AppLocalizations.of(context).workspaceAllSessions,
          value: _controlValue(entry),
          onValueChange: (value) {
            final location = tabLocations.firstWhere(
              (item) => _controlValue(workspace.tabs[item.tabId]!) == value,
            );
            unawaited(_activate(location.pane.id, location.tabId));
          },
          tabs: <TRTabsTab>[
            for (final location in tabLocations)
              _tab(context, workspace, workspace.tabs[location.tabId]!),
          ],
          actions: <Widget>[
            _newTabMenu(context, workspace.focusedPaneId, true),
          ],
        ),
        Expanded(child: _content(workspace, entry)),
      ],
    );
  }

  TRTabsTab _tab(
    BuildContext context,
    SessionTabsState workspace,
    WorkspaceTabEntry entry, {
    bool closable = true,
  }) => switch (entry.target) {
    SessionTabTarget(:final sessionId) => () {
      final session = workspace.sessions.firstWhere(
        (item) => item.id == sessionId,
      );
      final subagent = isSubagentSession(session);
      // The tab is all that stays visible of a session the user navigated
      // away from, so a tree parked behind it has to be flagged here too.
      final blocked =
          !subagent &&
          blockedSubagentRows(
            buildSubagentTrackRows(workspace.sessions, sessionId),
          ).isNotEmpty;
      return TRTabsTab(
        value: _controlValue(entry),
        label: subagent ? session.taskName ?? session.title : session.title,
        leading: subagent
            ? SubagentStatusIcon(
                lifecycle: session.lifecycle,
                status: session.status,
              )
            : blocked
            ? Icon(
                TinestIcons.approvalPending,
                key: ValueKey<String>('session-tab-approval-$sessionId'),
                color: context.tinyrackTheme.warning,
                semanticLabel: AppLocalizations.of(
                  context,
                ).subagentTabAwaitingApproval,
              )
            : null,
        onClose: closable ? () => unawaited(_closeEntry(entry)) : null,
        closeLabel: AppLocalizations.of(context).workspaceCloseTab,
      );
    }(),
    TerminalTabTarget(:final terminalId) => TRTabsTab(
      value: _controlValue(entry),
      label: workspace.terminals
          .firstWhere((item) => item.id == terminalId)
          .title,
      leading: const Icon(TinestIcons.terminal),
      onClose: closable ? () => unawaited(_closeEntry(entry)) : null,
      closeLabel: AppLocalizations.of(context).workspaceCloseTab,
    ),
    DraftTabTarget() => TRTabsTab(
      value: _controlValue(entry),
      label: AppLocalizations.of(context).workspaceNewTab,
      leading: const Icon(TinestIcons.chat),
      onClose: closable ? () => unawaited(_closeEntry(entry)) : null,
      closeLabel: AppLocalizations.of(context).workspaceCloseTab,
    ),
    PendingTerminalTabTarget() => TRTabsTab(
      value: _controlValue(entry),
      label: AppLocalizations.of(context).workspaceTerminalStarting,
      leading: const Icon(TinestIcons.terminal),
      onClose: closable ? () => unawaited(_closeEntry(entry)) : null,
      closeLabel: AppLocalizations.of(context).workspaceCloseTab,
    ),
  };

  String _controlValue(WorkspaceTabEntry entry) => switch (entry.target) {
    SessionTabTarget(:final sessionId) => sessionId,
    TerminalTabTarget(:final terminalId) => terminalId,
    DraftTabTarget() || PendingTerminalTabTarget() => entry.id,
  };

  Widget _content(SessionTabsState workspace, WorkspaceTabEntry entry) =>
      switch (entry.target) {
        TerminalTabTarget(:final terminalId) => _TerminalPane(
          key: ValueKey<String>('terminal-pane-${entry.id}'),
          selection: widget.selection,
          terminal: workspace.terminals.firstWhere(
            (item) => item.id == terminalId,
          ),
        ),
        SessionTabTarget(:final sessionId) => _ConversationPane(
          key: ValueKey<String>('conversation-pane-${entry.id}'),
          selection: widget.selection,
          agent: workspace.sessions.firstWhere((item) => item.id == sessionId),
        ),
        DraftTabTarget() => DraftSessionPane(
          key: ValueKey<String>('draft-pane-${entry.id}'),
          selection: widget.selection,
          draftId: entry.id,
          onCreated: _createdSession,
        ),
        PendingTerminalTabTarget() => TerminalConnectingOverlay(
          key: ValueKey<String>('pending-terminal-pane-${entry.id}'),
          semanticLabel: AppLocalizations.of(context).workspaceTerminalStarting,
          message: AppLocalizations.of(context).workspaceTerminalStarting,
        ),
      };

  Widget _newTabMenu(
    BuildContext context,
    String paneId,
    bool primary,
  ) => TRMenu.icon(
    key: ValueKey<String>(
      primary ? 'workspace-new-tab-menu' : 'workspace-new-tab-menu-$paneId',
    ),
    icon: const Icon(TinestIcons.add),
    label: AppLocalizations.of(context).workspaceNewTab,
    menuChildren: <Widget>[
      TRMenuItem(
        key: primary ? const ValueKey<String>('workspace-new-session') : null,
        onPressed: () => unawaited(_startDraft(paneId)),
        leadingIcon: const Icon(TinestIcons.chat),
        child: TRText.inherit(
          AppLocalizations.of(context).workspaceNewSession,
        ),
      ),
      TRMenuItem(
        key: primary ? const ValueKey<String>('workspace-new-terminal') : null,
        onPressed: () => unawaited(_createTerminal(paneId)),
        leadingIcon: const Icon(TinestIcons.terminal),
        child: TRText.inherit(
          AppLocalizations.of(context).workspaceNewTerminal,
        ),
      ),
    ],
  );

  Widget _allTabsMenu(
    BuildContext context,
    SessionTabsState workspace,
    PaneNode pane,
    bool primary,
  ) => TRMenu.icon(
    key: ValueKey<String>(
      primary ? 'workspace-all-sessions-menu' : 'workspace-tabs-${pane.id}',
    ),
    icon: const Icon(TinestIcons.more),
    label: AppLocalizations.of(context).workspaceAllSessions,
    menuChildren: <Widget>[
      for (final session in workspace.sessions.where(
        (item) => !isSubagentSession(item),
      ))
        TRMenuItem(
          onPressed: () => unawaited(_open(session.id)),
          child: TRText.inherit(session.title),
        ),
      for (final terminal in workspace.terminals)
        TRMenuItem(
          leadingIcon: const Icon(TinestIcons.terminal),
          onPressed: () => unawaited(_openTerminal(terminal.id)),
          child: TRText.inherit(terminal.title),
        ),
      for (final target in workspace.panes.where((item) => item.id != pane.id))
        TRMenuItem(
          leadingIcon: const Icon(TinestIcons.movePane),
          onPressed: () => unawaited(
            _moveTab(
              tabId: pane.activeTabId,
              sourcePaneId: pane.id,
              targetPaneId: target.id,
              targetIndex: target.tabIds.length,
            ),
          ),
          child: TRText.inherit(
            AppLocalizations.of(context).workspaceMoveTabToPane,
          ),
        ),
    ],
  );

  Future<void> _split(String paneId, WorkspaceSplitAxis axis) async {
    await ref
        .read(sessionTabsControllerProvider(widget.selection).notifier)
        .split(paneId, axis);
    if (mounted) _routeFocused();
  }

  Future<void> _dropTab(
    SessionTabsState workspace,
    TRTabDropDetails details,
  ) {
    final source = workspace.panes.firstWhere(
      (item) => item.id == details.sourceGroupId,
    );
    final tabId = source.tabIds.firstWhere(
      (id) => _controlValue(workspace.tabs[id]!) == details.value,
    );
    return _moveTab(
      tabId: tabId,
      sourcePaneId: details.sourceGroupId,
      targetPaneId: details.targetGroupId,
      targetIndex: details.targetIndex,
    );
  }

  Future<void> _moveTab({
    required String tabId,
    required String sourcePaneId,
    required String targetPaneId,
    required int targetIndex,
  }) async {
    await ref
        .read(sessionTabsControllerProvider(widget.selection).notifier)
        .moveTab(
          tabId: tabId,
          sourcePaneId: sourcePaneId,
          targetPaneId: targetPaneId,
          targetIndex: targetIndex,
        );
    if (mounted) _routeFocused();
  }

  Future<void> _activate(String paneId, String tabId) async {
    final notifier = ref.read(
      sessionTabsControllerProvider(widget.selection).notifier,
    );
    await notifier.selectTab(paneId, tabId);
    if (mounted) _routeFocused();
  }

  Future<void> _open(String id) async {
    await ref
        .read(sessionTabsControllerProvider(widget.selection).notifier)
        .open(id);
    if (mounted) _goSession(context, widget.selection, id);
  }

  Future<void> _openTerminal(String id) async {
    await ref
        .read(sessionTabsControllerProvider(widget.selection).notifier)
        .openTerminal(id);
    if (mounted) _goTerminal(context, widget.selection, id);
  }

  Future<void> _startDraft(String paneId) async {
    final notifier = ref.read(
      sessionTabsControllerProvider(widget.selection).notifier,
    );
    await notifier.focusPane(paneId);
    await notifier.startDraft();
    if (mounted) _goWorktree(context, widget.selection);
  }

  Future<void> _createTerminal(String paneId) async {
    final l10n = AppLocalizations.of(context);
    final tabs = ref.read(
      sessionTabsControllerProvider(widget.selection).notifier,
    );
    if (_terminalCreationError != null) {
      setState(() => _terminalCreationError = null);
    }
    // The placeholder tab appears before the daemon answers, so creating a
    // terminal never leaves the pane frozen while the PTY spawns.
    final pendingTabId = tabs.openPendingTerminal(paneId);
    final TerminalDto terminal;
    try {
      terminal = await ref
          .read(
            terminalsControllerProvider(
              widget.selection.hostId,
              widget.selection.worktreeId,
            ).notifier,
          )
          .create(buildTitle: l10n.terminalTabTitle);
    } on TinestClientException catch (error) {
      await tabs.removePendingTerminal(pendingTabId);
      if (mounted) setState(() => _terminalCreationError = error);
      if (error.code == 'worktree_unavailable') {
        await ref
            .read(workspaceCatalogControllerProvider.notifier)
            .refreshHost(widget.selection.hostId);
      }
      return;
    } on Exception catch (error) {
      await tabs.removePendingTerminal(pendingTabId);
      if (mounted) await _showTerminalCreateError(error);
      return;
    }
    tabs.promotePendingTerminal(pendingTabId, terminal);
    if (mounted) _goTerminal(context, widget.selection, terminal.id);
  }

  Future<void> _showTerminalCreateError(Object error) => showTRDialog<void>(
    context: context,
    builder: (context) => TRAlertDialog(
      key: const ValueKey<String>('terminal-create-failed'),
      title: TRText.inherit(
        AppLocalizations.of(context).terminalConnectionFailed,
      ),
      content: TRText.inherit(
        AppLocalizations.of(context).workspaceTerminalStartFailed('$error'),
      ),
      actions: <TRButton>[
        TRButton(
          onPressed: () => Navigator.of(context).pop(),
          child: TRText.inherit(
            MaterialLocalizations.of(context).okButtonLabel,
          ),
        ),
      ],
    ),
  );

  void _createdSession(SessionDto session) {
    if (mounted) _goSession(context, widget.selection, session.id);
  }

  Future<void> _closeEntry(WorkspaceTabEntry entry) async {
    switch (entry.target) {
      case SessionTabTarget(:final sessionId):
        await ref
            .read(sessionTabsControllerProvider(widget.selection).notifier)
            .close(sessionId);
      case TerminalTabTarget(:final terminalId):
        await _closeTerminal(terminalId);
      case DraftTabTarget():
        await ref
            .read(sessionTabsControllerProvider(widget.selection).notifier)
            .closeTab(entry.id);
      case PendingTerminalTabTarget():
        await ref
            .read(sessionTabsControllerProvider(widget.selection).notifier)
            .removePendingTerminal(entry.id);
    }
    if (mounted) _routeFocused();
  }

  Future<void> _closeTerminal(String id) async {
    final state = ref
        .read(sessionTabsControllerProvider(widget.selection))
        .requireValue;
    final terminal = state.terminals.where((item) => item.id == id).first;
    if (terminal.status == TerminalStatus.running) {
      final confirmed = await showTRDialog<bool>(
        context: context,
        builder: (context) => TRAlertDialog(
          key: const ValueKey<String>('terminal-close-dialog'),
          title: TRText.inherit(
            AppLocalizations.of(context).terminalCloseTitle,
          ),
          content: TRText.inherit(
            AppLocalizations.of(context).terminalCloseConfirm,
          ),
          actions: <TRButton>[
            TRButton(
              appearance: TRAppearance.ghost,
              onPressed: () => Navigator.of(context).pop(false),
              child: TRText.inherit(
                MaterialLocalizations.of(context).cancelButtonLabel,
              ),
            ),
            TRButton(
              intent: TRIntent.danger,
              key: const ValueKey<String>('terminal-close-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: TRText.inherit(
                AppLocalizations.of(context).terminalTerminate,
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      // A terminate the daemon refuses must not close the tab, or the process
      // keeps running with nothing left on screen that can reach it.
      final terminated = await ref
          .read(toastMessengerProvider)
          .run(
            () async {
              final registry = await ref.read(
                hostRegistryControllerProvider.future,
              );
              await registry.runtimes[widget.selection.hostId]!.api!.terminals
                  .terminateTerminal(id);
            },
            failure: AppLocalizations.of(context).terminalTerminateFailed,
            id: 'terminal-terminate',
          );
      if (!terminated) return;
    }
    await ref
        .read(sessionTabsControllerProvider(widget.selection).notifier)
        .closeTerminal(id);
  }

  void _routeFocused() {
    final entry = ref
        .read(sessionTabsControllerProvider(widget.selection))
        .requireValue
        .focusedTab;
    switch (entry?.target) {
      case SessionTabTarget(:final sessionId):
        _goSession(context, widget.selection, sessionId);
      case TerminalTabTarget(:final terminalId):
        _goTerminal(context, widget.selection, terminalId);
      case DraftTabTarget() || PendingTerminalTabTarget() || null:
        _goWorktree(context, widget.selection);
    }
  }
}

class _TerminalPane extends ConsumerStatefulWidget {
  const _TerminalPane({
    required this.selection,
    required this.terminal,
    super.key,
  });

  final WorkspaceSelection selection;
  final TerminalDto terminal;

  @override
  ConsumerState<_TerminalPane> createState() => _TerminalPaneState();
}

/// Renders one terminal session; the emulator itself lives in the provider.
///
/// Nothing durable is kept here, so the pane can be unmounted and rebuilt as
/// often as the tab layout likes without resetting what the user sees.
class _TerminalPaneState extends ConsumerState<_TerminalPane> {
  final TerminalViewController _controller = TerminalViewController();

  TerminalSessionControllerProvider get _provider =>
      terminalSessionControllerProvider(
        widget.selection.hostId,
        widget.terminal.id,
      );

  Terminal get _terminal => ref.read(_provider).terminal;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(_provider);
    if (session.status == TerminalSessionStatus.failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TRAlert(
              variant: TRStatusVariant.danger,
              title: TRText.inherit(l10n.terminalConnectionFailed),
              description: TRText.inherit('${session.error}'),
            ),
            const SizedBox(height: TRSpacing.medium),
            TRButton(
              key: const ValueKey<String>('terminal-attach-retry'),
              // Invalidating would destroy the emulator, so the retry goes
              // through the session, which keeps whatever it already holds.
              onPressed: () => ref.read(_provider.notifier).retry(),
              child: TRText.inherit(l10n.commonRetry),
            ),
          ],
        ),
      );
    }
    // The pane never blocks on the attach round trip: while the replay is on
    // its way, a visible connecting state explains why input is not accepted
    // yet instead of rendering an empty prompt that swallows keystrokes. Once
    // there is content to show, the terminal stays on screen through a
    // reconnect rather than being replaced by a spinner.
    if (session.status != TerminalSessionStatus.live && !session.hasContent) {
      return TerminalConnectingOverlay(
        key: ValueKey<String>('terminal-connecting-${widget.terminal.id}'),
        semanticLabel: l10n.terminalConnecting,
        message: l10n.terminalConnecting,
      );
    }
    // Input is dropped for the frames a rebuilt screen takes to paint, so the
    // terminal says so rather than looking live and swallowing keystrokes.
    final restoring = session.status == TerminalSessionStatus.restoring;
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => TinestTerminalView(
        key: ValueKey<String>('terminal-view-${widget.terminal.id}'),
        terminal: session.terminal,
        controller: _controller,
        autofocus: true,
        readOnly: restoring,
        contextMenuItems: _buildContextMenu,
        onCopy: _copySelection,
        onPaste: _pasteClipboard,
      ),
    );
  }

  /// Describes the terminal menu so the operating system can draw it.
  ///
  /// The ids are what a system menu reports back in place of a Dart closure,
  /// and are the same strings the Flutter presentation keys its items by.
  List<TRMenuElement> _buildContextMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasSelection = _controller.hasSelection;
    return <TRMenuElement>[
      TRMenuActionElement(
        id: 'terminal-menu-copy',
        title: l10n.terminalMenuCopy,
        icon: TinestIcons.copy,
        enabled: hasSelection,
        onPressed: _copySelection,
      ),
      TRMenuActionElement(
        id: 'terminal-menu-paste',
        title: l10n.terminalMenuPaste,
        icon: TinestIcons.paste,
        onPressed: _pasteClipboard,
      ),
      const TRMenuSeparatorElement(),
      TRMenuActionElement(
        id: 'terminal-menu-select-all',
        title: l10n.terminalMenuSelectAll,
        icon: TinestIcons.selectAll,
        onPressed: _controller.selectAll,
      ),
      TRMenuActionElement(
        id: 'terminal-menu-clear-selection',
        title: l10n.terminalMenuClearSelection,
        icon: TinestIcons.clearSelection,
        enabled: hasSelection,
        onPressed: _controller.clearSelection,
      ),
      const TRMenuSeparatorElement(),
      TRMenuActionElement(
        id: 'terminal-menu-clear-screen',
        title: l10n.terminalMenuClearScreen,
        icon: TinestIcons.erase,
        onPressed: _clearScreen,
      ),
    ];
  }

  void _copySelection() {
    final text = _controller.selectedText;
    if (text == null) return;
    unawaited(Clipboard.setData(ClipboardData(text: text)));
  }

  void _pasteClipboard() {
    unawaited(() async {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text == null || text.isEmpty) return;
      _terminal.paste(text);
      _controller.clearSelection();
    }());
  }

  /// Erases the screen and the scrollback, then homes the cursor.
  void _clearScreen() {
    _terminal.write('\x1b[H\x1b[2J\x1b[3J');
    _controller.clearSelection();
  }
}

class _ConversationPane extends ConsumerStatefulWidget {
  const _ConversationPane({
    required this.selection,
    required this.agent,
    super.key,
  });

  final WorkspaceSelection selection;
  final SessionDto agent;

  @override
  ConsumerState<_ConversationPane> createState() => _ConversationPaneState();
}

class _ConversationPaneState extends ConsumerState<_ConversationPane> {
  final SessionComposerController _dropController = SessionComposerController();
  PluginUiDocumentDto? _liveStatusDocument;
  Future<void> _pluginDialogTail = Future<void>.value();

  @override
  void didUpdateWidget(_ConversationPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.agent.id != widget.agent.id) {
      _liveStatusDocument = null;
      _pluginDialogTail = Future<void>.value();
    }
  }

  @override
  void dispose() {
    _dropController.dispose();
    super.dispose();
  }

  SessionsController _sessions(WidgetRef ref) => ref.read(
    sessionsControllerProvider(
      widget.selection.hostId,
      widget.selection.worktreeId,
    ).notifier,
  );

  /// Applies a session setting and explains a refusal instead of dropping it.
  ///
  /// These controls stay live while a turn runs because they are meant for the
  /// next one, so the daemon can legitimately refuse the change: the mode and
  /// the model are read when a turn starts. Firing the change and forgetting
  /// it left the chip snapping back to its old value with nothing said, and
  /// the failure escaping as an unhandled asynchronous error.
  Future<void> _applySessionSetting(Future<void> Function() change) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ref.read(toastMessengerProvider);
    try {
      await change();
    }
    // Deliberately broad: this is the boundary that turns a refused setting
    // into something the user can read, and anything it declined to catch
    // would go back to being silent.
    on Object catch (error) {
      messenger.failure(
        error is TinestClientException
            ? clientErrorText(l10n, error)
            : l10n.errorSessionSettingFailed,
        id: 'session-setting',
      );
    }
  }

  ConversationController _conversation(WidgetRef ref, String sessionId) =>
      ref.read(
        conversationControllerProvider(
          widget.selection.hostId,
          sessionId,
        ).notifier,
      );

  /// Runs one host-owned intent a plugin document raised, if it may.
  ///
  /// A plugin naming a session is a request, not a permission. Only the
  /// descendants of the session the drawer is mounted on are reachable, so a
  /// document cannot send the reader somewhere else in the workspace — and an
  /// unauthorized intent is dropped rather than reported, because the plugin
  /// is not the party that needs to hear about it.
  void _runPluginUiIntent(
    BuildContext context,
    PluginUiIntent intent,
    List<SubagentTrackRow> reachable,
  ) {
    switch (intent) {
      case PluginUiOpenSessionIntent(:final sessionId):
        if (!reachable.any((row) => row.session.id == sessionId)) return;
        _goSession(context, widget.selection, sessionId);
    }
  }

  Future<PluginUiDocumentDto> _dispatchPluginUi(
    String agentId,
    PluginUiDocumentDto document,
    PluginUiActionDto action,
  ) => ref
      .read(pluginSettingsControllerProvider(widget.selection.hostId).notifier)
      .dispatchUi(
        agentId: agentId,
        pluginId: document.pluginId,
        action: action,
      );

  void _consumePluginUiEvent(
    TimelineEventDto event,
    String agentId,
  ) {
    final document = pluginUiDocumentFromEvent(event);
    if (document == null || !mounted) return;
    switch (document.slot) {
      case PluginUiSlot.conversationStatus:
        setState(() => _liveStatusDocument = document);
      case PluginUiSlot.dialog:
        _pluginDialogTail = _pluginDialogTail
            .then((_) => _showPluginDialog(agentId, document))
            .catchError((_) {});
      case PluginUiSlot.toast:
        _showPluginToast(agentId, document);
      case PluginUiSlot.agentSettings:
      case PluginUiSlot.composerControl:
      // A drawer is asked for its contents when the tree it watches moves, so
      // it has nothing to push mid-turn.
      case PluginUiSlot.composerDrawer:
      case PluginUiSlot.timeline:
        break;
    }
  }

  Future<void> _showPluginDialog(
    String agentId,
    PluginUiDocumentDto document,
  ) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    await showTRDialog<void>(
      context: context,
      builder: (dialogContext) => TRDialog(
        semanticLabel: l10n.pluginUiSemanticLabel(document.pluginId),
        content: PluginUiDocumentView(
          document: document,
          semanticLabel: l10n.pluginUiSemanticLabel(document.pluginId),
          invalidDocumentLabel: l10n.pluginUiInvalidTitle,
          invalidDocumentDescription: l10n.pluginUiInvalidDescription(
            AppIdentity.displayName,
          ),
          onAction: (action) => _dispatchPluginUi(agentId, document, action),
        ),
        actions: TRButton(
          appearance: TRAppearance.outline,
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: TRText.inherit(l10n.commonClose),
        ),
      ),
    );
  }

  void _showPluginToast(
    String agentId,
    PluginUiDocumentDto document,
  ) {
    final l10n = AppLocalizations.of(context);
    ref
        .read(appToastControllerProvider)
        .show(
          TRToastData(
            id: 'plugin-ui-${document.id}',
            title: PluginUiDocumentView(
              document: document,
              semanticLabel: l10n.pluginUiSemanticLabel(document.pluginId),
              invalidDocumentLabel: l10n.pluginUiInvalidTitle,
              invalidDocumentDescription: l10n.pluginUiInvalidDescription(
                AppIdentity.displayName,
              ),
              onAction: (action) =>
                  _dispatchPluginUi(agentId, document, action),
            ),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sessions =
        ref
            .watch(
              sessionsControllerProvider(
                widget.selection.hostId,
                widget.selection.worktreeId,
              ),
            )
            .value ??
        const <SessionDto>[];
    final current =
        sessions.where((item) => item.id == widget.agent.id).firstOrNull ??
        widget.agent;
    // A spawned subagent's conversation is watched live but never driven from
    // here: no composer or plan actions. Its approvals are the exception —
    // only a human can answer them, and the daemon parks the subagent's turn
    // on an unbounded wait until one does, so hiding them hangs the agent.
    final readOnly = isSubagentSession(current);
    final subagentRows = readOnly
        ? const <SubagentTrackRow>[]
        : buildSubagentTrackRows(sessions, current.id);
    final busy = _isTurnActive(current.status);
    // A published status document belongs to the turn that published it.
    // Keeping it afterwards pins whatever the plugin reported mid-turn above
    // the composer for the rest of the session, so the pane drops it at the
    // turn boundary and lets the on-demand slot report the current state.
    ref.listen(
      sessionsControllerProvider(
        widget.selection.hostId,
        widget.selection.worktreeId,
      ).select(
        (value) => value.value
            ?.where((item) => item.id == widget.agent.id)
            .firstOrNull
            ?.status,
      ),
      (previous, next) {
        if (next == null || _isTurnActive(next)) return;
        if (_liveStatusDocument != null) {
          setState(() => _liveStatusDocument = null);
        }
      },
    );
    // Narrowed for the same reason the paging selector below is: this pane
    // owns the composer, its selectors, the plugin slots, and the subagent
    // track, and a streamed delta has nothing to say to any of them. The two
    // lists are compared by identity, which is exactly right — `copyWith`
    // keeps the instance of every field it is not given, so an event that
    // touches only the timeline leaves both untouched.
    final conversation = ref.watch(
      conversationControllerProvider(
        widget.selection.hostId,
        current.id,
      ).select(
        (value) => (
          queued: value.asData?.value.queued ?? const <QueuedTurn>[],
          pending: value.asData?.value.pending ?? const <PendingTurn>[],
          hasValue: value.hasValue,
          loading: value.isLoading && !value.hasValue,
        ),
      ),
    );
    // Stays on the whole provider: it diffs the timeline to drive plugin UI,
    // which a narrowed selector cannot carry, and listening never rebuilds.
    ref.listen(
      conversationControllerProvider(widget.selection.hostId, current.id),
      (previous, next) {
        final before = previous?.asData?.value;
        final after = next.asData?.value;
        if (before == null || after == null) return;
        final lastSequence = before.timeline.isEmpty
            ? 0
            : before.timeline.last.sequence;
        for (final event in after.timeline) {
          if (event.sequence > lastSequence) {
            _consumePluginUiEvent(event, current.agentDefinitionId);
          }
        }
      },
    );
    // A freshly created session navigates before its first turn is accepted.
    // Until the real timeline echoes the prompt, render it optimistically so
    // the chat room never opens onto an empty page after Send.
    final pendingFirstTurn = ref.watch(
      pendingFirstTurnsProvider.select((value) => value[current.id]),
    );
    final failedFirstTurn =
        pendingFirstTurn != null &&
        pendingFirstTurn.failed &&
        conversation.hasValue;
    final pending = conversation.pending;
    final restoreSubmission = failedFirstTurn
        ? ComposerSubmission(
            text: pendingFirstTurn.prompt,
            attachments: pendingFirstTurn.attachments,
          )
        : null;
    final restoreKey = failedFirstTurn
        ? '${current.id}:${pendingFirstTurn.createdAt.microsecondsSinceEpoch}'
        : null;
    // Read, not watched: a position is consumed when the pane mounts, and
    // watching it would rebuild the pane every time the reader scrolls away.
    // The notifier is resolved here rather than inside the callback, which
    // runs while the pane is being torn down and can no longer look up
    // ancestors.
    // Narrow on purpose: paging ticks several times per page, and watching the
    // whole controller would rebuild this pane's agents, providers, plan
    // actions, and subagent track along with the timeline.
    final paging = ref.watch(
      conversationControllerProvider(
        widget.selection.hostId,
        current.id,
      ).select(
        (value) => (
          hasMoreOlder: value.asData?.value.hasMoreOlder ?? false,
          loading: value.asData?.value.loadingOlder ?? false,
          failed: value.asData?.value.olderFailed ?? false,
          oldest: value.asData?.value.oldestLoadedSequence ?? 0,
        ),
      ),
    );
    // Resolved during build for the same reason the store below is: the edge
    // callback runs a microtask later, by which time this pane may be gone and
    // unable to look up an ancestor.
    final loadOlderHistory = ref
        .read(
          conversationControllerProvider(
            widget.selection.hostId,
            current.id,
          ).notifier,
        )
        .loadOlderHistory;
    final sessionKey = 'conversation:${widget.selection.hostId}:${current.id}';
    final readingPositions = ref.read(
      conversationReadingPositionsProvider.notifier,
    );
    final readingPosition = ref.read(
      conversationReadingPositionsProvider,
    )[sessionKey];
    final agentsAsync = ref.watch(
      agentDefinitionsControllerProvider(widget.selection.hostId),
    );
    final agents = agentsAsync.value;
    final agentsLoading = agentsAsync.isLoading && !agentsAsync.hasValue;
    final providersAsync = ref.watch(
      providerSettingsControllerProvider(widget.selection.hostId),
    );
    final connections =
        providersAsync.value?.connections ?? const <ProviderConnectionDto>[];
    final providersLoading =
        providersAsync.isLoading && !providersAsync.hasValue;
    final modelSettingsAsync = ref.watch(
      modelSettingsControllerProvider(widget.selection.hostId),
    );
    final modelSettingsLoading =
        modelSettingsAsync.isLoading && !modelSettingsAsync.hasValue;
    final definitions = selectableAgentDefinitions(
      agents?.definitions ?? const <AgentDefinitionDto>[],
    );
    final definition = agents?.definitions
        .where((candidate) => candidate.id == current.agentDefinitionId)
        .firstOrNull;
    final effective =
        current.model ??
        effectiveModelFor(
          definition: definition,
          connections: connections,
          models:
              providersAsync.value?.models ??
              const <String, List<ProviderModelDto>>{},
          defaultModel: modelSettingsAsync.value?.defaultModel,
        );
    final effectiveRunnable =
        effective != null &&
        isRunnableSelection(
          effective,
          connections,
          providersAsync.value?.models ??
              const <String, List<ProviderModelDto>>{},
        );
    final hasRunnableModel =
        firstUsableModel(
          connections,
          providersAsync.value?.models ??
              const <String, List<ProviderModelDto>>{},
        ) !=
        null;
    return ComposerDropPane(
      controller: _dropController,
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: <Widget>[
            // No title header: the tab already names the session and carries
            // the subagent status icon, so the timeline owns the top edge.
            //
            // The transcript is watched here rather than in the pane. Every
            // streamed delta produces a new projection, and watching it above
            // would rebuild the composer, its selectors, the plugin slots, and
            // the subagent track along with the messages — none of which a
            // delta has anything to say to.
            Expanded(
              child: Consumer(
                builder: (context, ref, _) {
                  final items = ref.watch(
                    conversationTimelineProvider(
                      widget.selection.hostId,
                      current.id,
                    ),
                  );
                  // `request_user_input` is refused for non-root agents, so a
                  // question here would be unanswerable; approvals stay so the
                  // user can unblock the turn.
                  var visibleItems = readOnly
                      ? items
                            .where((item) => item is! ChatQuestionInteraction)
                            .toList(growable: false)
                      : items;
                  final optimistic =
                      pendingFirstTurn != null &&
                      !pendingFirstTurn.failed &&
                      !visibleItems.any((item) => item is ChatUserMessage);
                  if (optimistic) {
                    visibleItems = <ChatItem>[
                      ...visibleItems,
                      ChatUserMessage(
                        key: 'pending-first-turn-${current.id}',
                        turnId: 'pending-first-turn',
                        createdAt: pendingFirstTurn.createdAt,
                        text: pendingFirstTurn.prompt,
                      ),
                    ];
                  } else if (pending.isNotEmpty) {
                    // One optimistic message per prompt. The registry above
                    // owns the pre-echo view of a session's first prompt, so
                    // while it is on screen the conversation's own pending
                    // list stays out of the way rather than drawing the same
                    // prompt a second time.
                    visibleItems = <ChatItem>[
                      ...visibleItems,
                      for (final turn in pending)
                        ChatUserMessage(
                          key: 'pending-turn-${turn.turnId}',
                          turnId: turn.turnId,
                          createdAt: turn.createdAt,
                          text: turn.prompt,
                        ),
                    ];
                  }
                  return ChatTimelineView(
                    sessionKey: sessionKey,
                    readingPosition: readingPosition,
                    // Reported while the pane is being torn down, which is a
                    // widget life-cycle: the store has to be written after the
                    // tree settles rather than during it.
                    onReadingPositionChanged: (key, position) =>
                        scheduleMicrotask(
                          () => readingPositions.remember(key, position),
                        ),
                    olderPageKey: paging.hasMoreOlder
                        ? 'older:${paging.oldest}'
                        : null,
                    loadingOlder: paging.loading,
                    olderFailed: paging.failed,
                    // The list reports an edge from inside a scroll
                    // notification, and mutating a provider there is a
                    // build-phase write.
                    onLoadOlder: () => scheduleMicrotask(loadOlderHistory),
                    items: visibleItems,
                    // The optimistic prompt brings the running row with it, so
                    // a send makes one change to the list instead of three:
                    // the status event that follows adds nothing, and the echo
                    // is a key swap in place rather than an insert above the
                    // running row that pushes it down.
                    busy: busy || optimistic || pending.isNotEmpty,
                    loading: conversation.loading,
                    hostId: widget.selection.hostId,
                    onPluginUiAction: (document, action) => ref
                        .read(
                          pluginSettingsControllerProvider(
                            widget.selection.hostId,
                          ).notifier,
                        )
                        .dispatchUi(
                          agentId: current.agentDefinitionId,
                          pluginId: document.pluginId,
                          action: action,
                        ),
                    loadAttachment: _loadAttachment,
                    exportAttachment: _exportAttachment,
                  );
                },
              ),
            ),
            if (definition != null)
              _ConversationContentColumn(
                key: const ValueKey<String>('conversation-status'),
                child: switch (_liveStatusDocument) {
                  // `busy` rides along so the slot re-renders on both turn
                  // boundaries. Without it the surface loads once and keeps
                  // showing whatever the status said when it first mounted.
                  null => AgentPluginUiSlot(
                    hostId: widget.selection.hostId,
                    agent: definition,
                    slot: PluginUiSlot.conversationStatus,
                    context: <String, dynamic>{
                      'sessionId': current.id,
                      'workspaceId': widget.selection.workspaceId,
                      'worktreeId': widget.selection.worktreeId,
                      'readOnly': readOnly,
                      'busy': busy,
                    },
                  ),
                  final document when pluginUiDocumentIsEmpty(document) =>
                    const SizedBox.shrink(),
                  final document => PluginUiDocumentView(
                    document: document,
                    semanticLabel: l10n.pluginUiSemanticLabel(
                      document.pluginId,
                    ),
                    invalidDocumentLabel: l10n.pluginUiInvalidTitle,
                    invalidDocumentDescription: l10n.pluginUiInvalidDescription(
                      AppIdentity.displayName,
                    ),
                    onAction: (action) => _dispatchPluginUi(
                      current.agentDefinitionId,
                      document,
                      action,
                    ),
                  ),
                },
              ),
            // Beside the composer rather than inside it: a blocked descendant
            // holds its whole tree, so the request takes room from the
            // transcript while the input keeps its own height.
            //
            // The slot is always built, and collapses to nothing when there is
            // no request. Inserting it only when one arrives would move the
            // composer down the child list, and the unkeyed subtree that moves
            // with it loses its state, snapping the expanded subagent track
            // shut at the exact moment the user needs it.
            if (!readOnly)
              _ConversationContentColumn(
                key: const ValueKey<String>('conversation-approvals'),
                child: SubagentApprovalBanner(
                  hostId: widget.selection.hostId,
                  rows: blockedSubagentRows(subagentRows),
                  maxHeight: constraints.maxHeight / 3,
                ),
              ),
            // The drawer content owns its viewport-derived cap below. Let the
            // complete composer keep its natural height so the preceding
            // Expanded timeline receives the actual remaining space instead of
            // imposing a second, conflicting cap around fixed drawer chrome and
            // the input.
            if (!readOnly)
              _ConversationContentColumn(
                key: const ValueKey<String>('conversation-composer'),
                child: ComposerCompletionScope(
                  hostId: widget.selection.hostId,
                  workspaceId: widget.selection.workspaceId,
                  worktreeId: widget.selection.worktreeId,
                  builder: (context, completion) => SessionComposer(
                    controller: _dropController,
                    header: definition == null
                        ? null
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              AgentPluginUiSlot(
                                hostId: widget.selection.hostId,
                                agent: definition,
                                slot: PluginUiSlot.composerControl,
                                context: <String, dynamic>{
                                  'sessionId': current.id,
                                  'workspaceId': widget.selection.workspaceId,
                                  'worktreeId': widget.selection.worktreeId,
                                },
                              ),
                              AgentPluginSessionControls(
                                hostId: widget.selection.hostId,
                                sessionId: current.id,
                                agent: definition,
                              ),
                              AgentPluginUiSlot(
                                hostId: widget.selection.hostId,
                                agent: definition,
                                slot: PluginUiSlot.composerDrawer,
                                // Viewport-derived cap: an expanded
                                // drawer never squeezes the input out,
                                // and the plugin never picks a height.
                                maxContentHeight: constraints.maxHeight / 4,
                                onIntent: (intent) => _runPluginUiIntent(
                                  context,
                                  intent,
                                  subagentRows,
                                ),
                                context: <String, dynamic>{
                                  'sessionId': current.id,
                                  'workspaceId': widget.selection.workspaceId,
                                  'worktreeId': widget.selection.worktreeId,
                                },
                              ),
                            ],
                          ),
                    // A running turn never takes the keyboard away; the
                    // prompt queues instead.
                    enabled: effectiveRunnable,
                    // The session status trails the daemon by an event,
                    // so a prompt it has already accepted counts as busy
                    // here: the next one queues rather than racing it.
                    busy: busy || pending.isNotEmpty,
                    contextTokens: current.contextTokens,
                    contextWindow: current.contextWindow,
                    totalCostUsd: current.totalCostUsd,
                    providerConnectionId: effectiveRunnable
                        ? connections
                              .where(
                                (connection) =>
                                    effective.qualifiedModelId.startsWith(
                                      '${connection.modelPrefix}/',
                                    ),
                              )
                              .firstOrNull
                              ?.id
                        : null,
                    onLoadProviderUsage: () => ref
                        .read(
                          providerSettingsControllerProvider(
                            widget.selection.hostId,
                          ).notifier,
                        )
                        .loadUsage(),
                    queued: conversation.queued,
                    onQueue: (submission) =>
                        _conversation(ref, current.id).enqueueTurn(
                          submission.text,
                          attachments: submission.attachments,
                        ),
                    onQueuedEdit: (id) =>
                        _conversation(ref, current.id).takeQueuedTurn(id),
                    onQueuedSendNow: (id) => _conversation(
                      ref,
                      current.id,
                    ).sendQueuedTurnNow(id),
                    onSubmitAndInterrupt: (submission) async {
                      await _conversation(ref, current.id).cancelTurn();
                      await _send(current.id, submission);
                    },
                    onStop: () => _conversation(ref, current.id).cancelTurn(),
                    hint:
                        (agentsLoading ||
                            providersLoading ||
                            modelSettingsLoading ||
                            effectiveRunnable)
                        ? null
                        : hasRunnableModel && effective != null
                        ? AppLocalizations.of(
                            context,
                          ).modelSettingsUnavailableDescription(
                            effective.modelId,
                          )
                        : AppLocalizations.of(
                            context,
                          ).composerConnectProviderFirst,
                    bar: SessionComposerBar(
                      hostId: widget.selection.hostId,
                      definitions: definitions,
                      agentDefinitionId: current.agentDefinitionId,
                      selection: effective,
                      // Turn settings apply to the next turn, so they
                      // stay reachable while one is running.
                      agentEnabled: false,
                      onAgentChanged: (_) {},
                      onModelChanged: (model, controls) => unawaited(
                        _applySessionSetting(
                          () => _sessions(
                            ref,
                          ).setModel(current.id, model, controls),
                        ),
                      ),
                      modelControls: current.modelControls,
                      onModelControlsChanged: (controls) => unawaited(
                        _applySessionSetting(
                          () => _sessions(
                            ref,
                          ).setModelControls(current.id, controls),
                        ),
                      ),
                      permissionMode: current.permissionMode,
                      // Not routed through [_applySessionSetting]: the
                      // permission mode is not read at turn start, so the
                      // daemon never refuses it, and the composer already
                      // reports a save failure on the control itself.
                      onPermissionModeChanged: (mode) async {
                        await _sessions(
                          ref,
                        ).setPermissionMode(current.id, mode);
                      },
                    ),
                    attachmentInput: ref.read(attachmentInputProvider),
                    commands: completion.commands,
                    suggestions: completion.suggestions,
                    onCompletionQueryChanged: completion.onQueryChanged,
                    onClientCommand: (invocation) =>
                        _runClientCommand(invocation, current),
                    onSubmit: (submission) => _send(current.id, submission),
                    restoreSubmission: restoreSubmission,
                    restoreKey: restoreKey,
                    onRestoreConsumed: restoreSubmission == null
                        ? null
                        : () {
                            final entry = ref.read(
                              pendingFirstTurnsProvider,
                            )[current.id];
                            if (entry != null &&
                                entry.failed &&
                                entry.createdAt ==
                                    pendingFirstTurn!.createdAt) {
                              ref
                                  .read(
                                    pendingFirstTurnsProvider.notifier,
                                  )
                                  .clear(current.id);
                            }
                          },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Runs an app-owned command, reporting that the submission was consumed.
  Future<bool> _runClientCommand(
    ComposerCommandInvocation invocation,
    SessionDto session,
  ) async {
    switch (invocation.command.action!) {
      case ClientCommandAction.clear:
        // The draft is already cleared by the composer; nothing else to undo.
        break;
      case ClientCommandAction.newSession:
        await _sessions(ref).create(
          title: invocation.arguments.isEmpty
              ? AppLocalizations.of(context).workspaceNewSession
              : invocation.arguments,
          agentDefinitionId: session.agentDefinitionId,
          model: session.model,
          // The new session continues the same work, so it keeps the
          // permissions the current one was granted.
          permissionMode: session.permissionMode,
        );
      case ClientCommandAction.openAgentSettings:
        if (mounted) {
          AgentSettingsRoute(hostId: widget.selection.hostId).go(context);
        }
      case ClientCommandAction.openSkillSettings:
        if (mounted) {
          SkillSettingsRoute(hostId: widget.selection.hostId).go(context);
        }
      case ClientCommandAction.help:
        // Typing `/` already lists every command, so help only reopens it.
        break;
    }
    return true;
  }

  Future<void> _send(
    String sessionId,
    ComposerSubmission submission,
  ) async {
    await ref
        .read(
          conversationControllerProvider(
            widget.selection.hostId,
            sessionId,
          ).notifier,
        )
        .startTurn(
          submission.text,
          attachments: submission.attachments,
        );
  }

  Future<Uint8List> _loadAttachment(ChatAttachment attachment) async {
    final registry = await ref.read(hostRegistryControllerProvider.future);
    final api = registry.runtimes[widget.selection.hostId]?.api;
    // A user reaching this has hit a bug, not a situation to explain: the
    // caller is supposed to check the connection first. Left in English for
    // whoever reads the crash report.
    if (api == null) throw StateError('Daemon is not connected.');
    return readAttachmentDownload(
      await api.attachments.downloadAttachment(attachment.id),
    );
  }

  Future<void> _exportAttachment(ChatAttachment attachment) async {
    final bytes = await _loadAttachment(attachment);
    await ref
        .read(attachmentExportProvider)
        .export(
          fileName: attachment.fileName,
          mimeType: attachment.mimeType,
          bytes: bytes,
        );
  }
}

/// Whether [status] means a turn is still in flight, waiting included.
///
/// A turn parked on an approval or a question has not ended: the composer stays
/// busy and any status a plugin published for it is still current.
bool _isTurnActive(SessionStatus status) =>
    status == SessionStatus.running ||
    status == SessionStatus.waitingForApproval ||
    status == SessionStatus.waitingForInput;

/// Keeps every session-owned conversation surface on one readable centerline.
///
/// Every use is keyed. These are same-typed siblings in one [Column], and a
/// conditional one appearing above another would otherwise be matched against
/// its neighbour by position, re-inflating the subtree that got pushed down.
class _ConversationContentColumn extends StatelessWidget {
  const _ConversationContentColumn({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: TinestLayoutMetrics.conversationContentMaxWidth,
      ),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

/// Selects [selection] within the workspace surface.
///
/// Lateral selection replaces the shared content page; compact hierarchy
/// entry pushes it above workspace home.
void _goWorktree(
  BuildContext context,
  WorkspaceSelection selection, {
  bool push = false,
}) {
  final route = WorktreeRoute(
    hostId: selection.hostId,
    workspaceId: selection.workspaceId,
    worktreeId: selection.worktreeId,
  );
  if (push) {
    unawaited(route.push<void>(context));
  } else {
    route.replace(context);
  }
}

void _goSession(
  BuildContext context,
  WorkspaceSelection selection,
  String sessionId, {
  bool push = false,
}) {
  final route = SessionRoute(
    hostId: selection.hostId,
    workspaceId: selection.workspaceId,
    worktreeId: selection.worktreeId,
    sessionId: sessionId,
  );
  if (push) {
    unawaited(route.push<void>(context));
  } else {
    route.replace(context);
  }
}

void _goTerminal(
  BuildContext context,
  WorkspaceSelection selection,
  String terminalId,
) {
  TerminalRoute(
    hostId: selection.hostId,
    workspaceId: selection.workspaceId,
    worktreeId: selection.worktreeId,
    terminalId: terminalId,
  ).replace(context);
}
