import 'dart:async';

import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/features/conversation/application/pending_turns_controller.dart';
import 'package:app/src/features/hosts/application/host_controller.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/sessions/application/sessions_controller.dart';
import 'package:app/src/features/terminals/application/terminals_controller.dart';
import 'package:meta/meta.dart';
import 'package:protocol/protocol.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_tabs_controller.g.dart';

/// Content addressed by one workspace tab.
sealed class WorkspaceTabTarget {
  const new();
}

/// A daemon session tab.
@immutable
final class SessionTabTarget extends WorkspaceTabTarget {
  /// Creates a session target.
  const new(this.sessionId);

  /// Daemon session identity.
  final String sessionId;

  @override
  bool operator ==(Object other) =>
      other is SessionTabTarget && other.sessionId == sessionId;

  @override
  int get hashCode => sessionId.hashCode;
}

/// A daemon terminal tab.
final class TerminalTabTarget extends WorkspaceTabTarget {
  /// Creates a terminal target.
  const new(this.terminalId);

  /// Daemon terminal identity.
  final String terminalId;
}

/// An app-local composer draft.
final class DraftTabTarget extends WorkspaceTabTarget {
  /// Creates a draft target.
  const new();
}

/// A terminal tab whose daemon PTY is still being created.
///
/// The tab exists so terminal creation gives instant feedback; it is never
/// persisted, and is either promoted to a [TerminalTabTarget] or removed.
final class PendingTerminalTabTarget extends WorkspaceTabTarget {
  /// Creates a pending terminal target.
  const new();
}

/// Stable tab identity and its current content target.
final class WorkspaceTabEntry {
  /// Creates a workspace tab entry.
  const new({required this.id, required this.target});

  /// Stable identity used by pane ordering and widget keys.
  final String id;

  /// Content rendered by the tab.
  final WorkspaceTabTarget target;
}

/// Base class for the immutable workspace pane tree.
sealed class WorkspacePaneNode {
  const new();
}

/// A leaf pane with its own active, ordered tab collection.
final class PaneNode extends WorkspacePaneNode {
  /// Creates a leaf pane.
  const new({
    required this.id,
    required this.tabIds,
    required this.activeTabId,
  });

  /// Stable pane identity.
  final String id;

  /// Ordered stable tab identities.
  final List<String> tabIds;

  /// Active tab identity.
  final String activeTabId;

  /// Returns a copy with selected fields replaced.
  PaneNode copyWith({List<String>? tabIds, String? activeTabId}) => PaneNode(
    id: id,
    tabIds: List<String>.unmodifiable(tabIds ?? this.tabIds),
    activeTabId: activeTabId ?? this.activeTabId,
  );
}

/// A binary branch in the workspace pane tree.
final class WorkspaceSplitNode extends WorkspacePaneNode {
  /// Creates a split branch.
  const new({
    required this.id,
    required this.axis,
    required this.ratio,
    required this.first,
    required this.second,
  });

  /// Stable split identity.
  final String id;

  /// Horizontal or vertical layout direction.
  final WorkspaceSplitAxis axis;

  /// Fraction assigned to [first].
  final double ratio;

  /// First child in visual order.
  final WorkspacePaneNode first;

  /// Second child in visual order.
  final WorkspacePaneNode second;
}

/// Visible tabs and immutable pane layout for one worktree.
final class SessionTabsState {
  /// Creates immutable workspace tab state.
  const new({
    required this.sessions,
    required this.terminals,
    required this.tabs,
    required this.root,
    required this.focusedPaneId,
  });

  /// All daemon sessions available to the overflow picker.
  final List<SessionDto> sessions;

  /// All daemon terminals known to the workspace.
  final List<TerminalDto> terminals;

  /// Stable tab entries keyed by ID.
  final Map<String, WorkspaceTabEntry> tabs;

  /// Root of the binary pane tree.
  final WorkspacePaneNode root;

  /// Pane whose active tab owns routing and mobile presentation.
  final String focusedPaneId;

  /// Leaf panes in depth-first visual order.
  List<PaneNode> get panes => _panes(root);

  /// Focused leaf, falling back to the first valid leaf.
  PaneNode get focusedPane =>
      panes.where((pane) => pane.id == focusedPaneId).firstOrNull ??
      panes.first;

  /// Active tab identity in the focused pane.
  String get focusedTabId => focusedPane.activeTabId;

  /// Active tab in the focused pane.
  WorkspaceTabEntry? get focusedTab => tabs[focusedTabId];

  /// Returns a copy with selected fields replaced.
  SessionTabsState copyWith({
    List<SessionDto>? sessions,
    List<TerminalDto>? terminals,
    Map<String, WorkspaceTabEntry>? tabs,
    WorkspacePaneNode? root,
    String? focusedPaneId,
  }) => SessionTabsState(
    sessions: sessions ?? this.sessions,
    terminals: terminals ?? this.terminals,
    tabs: Map<String, WorkspaceTabEntry>.unmodifiable(tabs ?? this.tabs),
    root: root ?? this.root,
    focusedPaneId: focusedPaneId ?? this.focusedPaneId,
  );
}

@riverpod
/// Owns local workspace tabs and pane layout independently per worktree.
class SessionTabsController extends _$SessionTabsController {
  late WorkspaceSelection _selection;

  @override
  Future<SessionTabsState> build(WorkspaceSelection selection) async {
    _selection = selection;
    final sessionsProvider = sessionsControllerProvider(
      selection.hostId,
      selection.worktreeId,
    );
    final terminalsProvider = terminalsControllerProvider(
      selection.hostId,
      selection.worktreeId,
    );
    // The pane tree is restored once. Live daemon catalogs are folded into
    // that ready tree below instead of invalidating this async build and
    // replacing the whole workspace with a transient loading frame.
    ref
      ..listen(sessionsProvider, (_, next) => _syncSessions(next))
      ..listen(terminalsProvider, (_, next) => _syncTerminals(next));
    final values = await Future.wait<Object>(<Future<Object>>[
      ref.read(sessionsProvider.future),
      ref.read(terminalsProvider.future),
    ]);
    final sessions = values[0] as List<SessionDto>;
    final terminals = values[1] as List<TerminalDto>;
    final settings = (await ref.read(hostRegistryControllerProvider.future))
        .settings;
    final saved = settings.sessionTabs[selection.storageKey];
    return _restore(sessions, terminals, saved);
  }

  /// Opens and selects a session in its existing pane or the focused pane.
  Future<void> open(String sessionId) => _openTarget(
    SessionTabTarget(sessionId),
    preferredId: 'session:$sessionId',
  );

  /// Selects an already-open session and focuses its pane.
  Future<void> select(String sessionId) => _selectTarget(
    (target) => target is SessionTabTarget && target.sessionId == sessionId,
  );

  /// Opens a new independent draft in the focused pane.
  Future<void> startDraft() async {
    final current = state.requireValue;
    final id = 'draft:${ref.read(appIdGeneratorProvider).generate()}';
    final pane = current.focusedPane;
    _apply(
      current.copyWith(
        tabs: <String, WorkspaceTabEntry>{
          ...current.tabs,
          id: WorkspaceTabEntry(id: id, target: const DraftTabTarget()),
        },
        root: _replacePane(
          current.root,
          pane.id,
          pane.copyWith(tabIds: <String>[...pane.tabIds, id], activeTabId: id),
        ),
      ),
    );
  }

  /// Hides a session tab without deleting daemon history.
  Future<void> close(String sessionId) async {
    await _closeWhere(
      (target) => target is SessionTabTarget && target.sessionId == sessionId,
    );
    // A first turn that failed to start is kept so a mounting conversation
    // pane can requeue it. Closing the tab is the user declining that offer,
    // and it is the only bound on the pending map: without it an entry whose
    // pane never mounts is retained for the life of the process.
    ref.read(pendingFirstTurnsProvider.notifier).clear(sessionId);
  }

  /// Retargets the focused draft after the daemon creates its session.
  Future<void> add(SessionDto agent, {String? draftTabId}) async {
    final current = state.requireValue;
    final sessions = <SessionDto>[
      agent,
      ...current.sessions.where((item) => item.id != agent.id),
    ];
    final active = draftTabId == null
        ? current.focusedTab
        : current.tabs[draftTabId];
    if (active?.target is DraftTabTarget) {
      _apply(
        current.copyWith(
          sessions: sessions,
          tabs: <String, WorkspaceTabEntry>{
            ...current.tabs,
            active!.id: WorkspaceTabEntry(
              id: active.id,
              target: SessionTabTarget(agent.id),
            ),
          },
        ),
      );
      return;
    }
    await _openTarget(
      SessionTabTarget(agent.id),
      preferredId: 'session:${agent.id}',
      sessions: sessions,
    );
  }

  void _syncSessions(AsyncValue<List<SessionDto>> next) {
    final current = state.asData?.value;
    final sessions = next.asData?.value;
    if (current == null || sessions == null) return;
    final open = <String>{
      for (final entry in current.tabs.values)
        if (entry.target case SessionTabTarget(:final sessionId)) sessionId,
    };
    state = AsyncData<SessionTabsState>(
      current.copyWith(
        sessions: _retainOpen(
          next: sessions,
          known: current.sessions,
          open: open,
          idOf: (item) => item.id,
        ),
      ),
    );
  }

  void _syncTerminals(AsyncValue<List<TerminalDto>> next) {
    final current = state.asData?.value;
    final terminals = next.asData?.value;
    if (current == null || terminals == null) return;
    final open = <String>{
      for (final entry in current.tabs.values)
        if (entry.target case TerminalTabTarget(:final terminalId)) terminalId,
    };
    state = AsyncData<SessionTabsState>(
      current.copyWith(
        terminals: _retainOpen(
          next: terminals,
          known: current.terminals,
          open: open,
          idOf: (item) => item.id,
        ),
      ),
    );
  }

  /// Folds a fresh catalog in without unbinding the tabs that are open.
  ///
  /// [_restore] is the only place that reconciles tabs against a catalog, so
  /// every open tab names an entry that this state holds. A daemon that drops
  /// answers with an empty catalog, and letting that empty answer through would
  /// leave those tabs pointing at nothing. The last known entry stands in until
  /// the daemon lists it again.
  static List<T> _retainOpen<T>({
    required List<T> next,
    required List<T> known,
    required Set<String> open,
    required String Function(T) idOf,
  }) {
    if (open.isEmpty) return next;
    final listed = next.map(idOf).toSet();
    return <T>[
      ...next,
      ...known.where(
        (item) => !listed.contains(idOf(item)) && open.contains(idOf(item)),
      ),
    ];
  }

  /// Adds and selects a newly-created terminal tab.
  Future<void> addTerminal(TerminalDto terminal) => _openTarget(
    TerminalTabTarget(terminal.id),
    preferredId: 'terminal:${terminal.id}',
    terminals: <TerminalDto>[terminal, ...state.requireValue.terminals],
  );

  /// Selects a visible terminal and focuses its pane.
  Future<void> selectTerminal(String id) => _selectTarget(
    (target) => target is TerminalTabTarget && target.terminalId == id,
  );

  /// Opens and selects a terminal from the overflow picker.
  Future<void> openTerminal(String id) =>
      _openTarget(TerminalTabTarget(id), preferredId: 'terminal:$id');

  /// Removes a terminated terminal from the visible layout.
  Future<void> closeTerminal(String id) => _closeWhere(
    (target) => target is TerminalTabTarget && target.terminalId == id,
  );

  /// Inserts and focuses a placeholder tab while the daemon creates a PTY.
  ///
  /// Returns the placeholder tab identity so the caller can promote or remove
  /// it once the daemon answers. The placeholder is never persisted.
  String openPendingTerminal(String paneId) {
    final current = state.requireValue;
    final pane = _findPane(current.root, paneId) ?? current.focusedPane;
    final id =
        'pending-terminal:${ref.read(appIdGeneratorProvider).generate()}';
    _apply(
      current.copyWith(
        tabs: <String, WorkspaceTabEntry>{
          ...current.tabs,
          id: WorkspaceTabEntry(
            id: id,
            target: const PendingTerminalTabTarget(),
          ),
        },
        root: _replacePane(
          current.root,
          pane.id,
          pane.copyWith(tabIds: <String>[...pane.tabIds, id], activeTabId: id),
        ),
        focusedPaneId: pane.id,
      ),
    );
    return id;
  }

  /// Retargets a placeholder tab to its created terminal.
  void promotePendingTerminal(String pendingTabId, TerminalDto terminal) {
    final current = state.requireValue;
    final entry = current.tabs[pendingTabId];
    if (entry == null || entry.target is! PendingTerminalTabTarget) return;
    _apply(
      current.copyWith(
        terminals: <TerminalDto>[
          terminal,
          ...current.terminals.where((item) => item.id != terminal.id),
        ],
        tabs: <String, WorkspaceTabEntry>{
          ...current.tabs,
          pendingTabId: WorkspaceTabEntry(
            id: pendingTabId,
            target: TerminalTabTarget(terminal.id),
          ),
        },
      ),
    );
  }

  /// Removes a placeholder tab whose terminal creation failed or was
  /// cancelled.
  Future<void> removePendingTerminal(String pendingTabId) async {
    final current = state.asData?.value;
    if (current == null) return;
    if (current.tabs[pendingTabId]?.target is! PendingTerminalTabTarget) {
      return;
    }
    await closeTab(pendingTabId);
  }

  /// Closes an app-local tab by its stable identity.
  Future<void> closeTab(String tabId) async {
    final current = state.requireValue;
    final pane = current.panes
        .where((item) => item.tabIds.contains(tabId))
        .firstOrNull;
    if (pane != null) await _closeTab(current, pane, tabId);
  }

  /// Selects a tab and focuses its owning pane.
  Future<void> selectTab(String paneId, String tabId) async {
    final current = state.requireValue;
    final pane = _findPane(current.root, paneId);
    if (pane == null || !pane.tabIds.contains(tabId)) return;
    _apply(
      current.copyWith(
        root: _replacePane(
          current.root,
          paneId,
          pane.copyWith(activeTabId: tabId),
        ),
        focusedPaneId: paneId,
      ),
    );
  }

  /// Focuses a pane without changing its active tab.
  Future<void> focusPane(String paneId) async {
    final current = state.requireValue;
    if (_findPane(current.root, paneId) == null) return;
    _apply(current.copyWith(focusedPaneId: paneId));
  }

  /// Splits one leaf and creates a fresh draft in the new pane.
  Future<void> split(String paneId, WorkspaceSplitAxis axis) async {
    final current = state.requireValue;
    if (axis != WorkspaceSplitAxis.horizontal || current.panes.length >= 2) {
      return;
    }
    final pane = _findPane(current.root, paneId);
    if (pane == null) return;
    final ids = ref.read(appIdGeneratorProvider);
    final draftId = 'draft:${ids.generate()}';
    final newPaneId = 'pane:${ids.generate()}';
    final splitId = 'split:${ids.generate()}';
    final replacement = WorkspaceSplitNode(
      id: splitId,
      axis: axis,
      ratio: 0.5,
      first: pane,
      second: PaneNode(
        id: newPaneId,
        tabIds: <String>[draftId],
        activeTabId: draftId,
      ),
    );
    _apply(
      current.copyWith(
        tabs: <String, WorkspaceTabEntry>{
          ...current.tabs,
          draftId: WorkspaceTabEntry(
            id: draftId,
            target: const DraftTabTarget(),
          ),
        },
        root: _replaceNode(current.root, paneId, replacement),
        focusedPaneId: newPaneId,
      ),
    );
  }

  /// Reorders a tab or moves it atomically between panes.
  Future<void> moveTab({
    required String tabId,
    required String sourcePaneId,
    required String targetPaneId,
    required int targetIndex,
  }) async {
    final current = state.requireValue;
    final source = _findPane(current.root, sourcePaneId);
    final target = _findPane(current.root, targetPaneId);
    if (source == null || target == null || !source.tabIds.contains(tabId)) {
      return;
    }
    if (sourcePaneId == targetPaneId) {
      final reordered = source.tabIds.where((id) => id != tabId).toList();
      final index = targetIndex.clamp(0, reordered.length);
      reordered.insert(index, tabId);
      _apply(
        current.copyWith(
          root: _replacePane(
            current.root,
            sourcePaneId,
            source.copyWith(tabIds: reordered, activeTabId: tabId),
          ),
          focusedPaneId: sourcePaneId,
        ),
      );
      return;
    }
    final sourceIds = source.tabIds.where((id) => id != tabId).toList();
    final targetIds = target.tabIds.where((id) => id != tabId).toList();
    targetIds.insert(targetIndex.clamp(0, targetIds.length), tabId);
    var root = _replacePane(
      current.root,
      targetPaneId,
      target.copyWith(tabIds: targetIds, activeTabId: tabId),
    );
    if (sourceIds.isEmpty) {
      root = _removePane(root, sourcePaneId)!;
    } else {
      root = _replacePane(
        root,
        sourcePaneId,
        source.copyWith(
          tabIds: sourceIds,
          activeTabId: source.activeTabId == tabId
              ? sourceIds.last
              : source.activeTabId,
        ),
      );
    }
    _apply(current.copyWith(root: root, focusedPaneId: targetPaneId));
  }

  /// Updates a split ratio in memory without writing device settings.
  Future<void> resize(String splitId, double ratio) async {
    final current = state.requireValue;
    state = AsyncData<SessionTabsState>(
      current.copyWith(
        root: _replaceSplitRatio(current.root, splitId, ratio.clamp(0, 1)),
      ),
    );
  }

  /// Persists the final ratio after an interactive resize ends.
  Future<void> commitResize() => _persist(state.requireValue);

  Future<void> _selectTarget(bool Function(WorkspaceTabTarget) matches) async {
    final current = state.requireValue;
    for (final pane in current.panes) {
      for (final tabId in pane.tabIds) {
        if (matches(current.tabs[tabId]!.target)) {
          await selectTab(pane.id, tabId);
          return;
        }
      }
    }
  }

  Future<void> _openTarget(
    WorkspaceTabTarget target, {
    required String preferredId,
    List<SessionDto>? sessions,
    List<TerminalDto>? terminals,
  }) async {
    final current = state.requireValue;
    for (final pane in current.panes) {
      for (final tabId in pane.tabIds) {
        if (_sameTarget(current.tabs[tabId]!.target, target)) {
          _apply(
            current.copyWith(
              sessions: sessions,
              terminals: terminals,
              root: _replacePane(
                current.root,
                pane.id,
                pane.copyWith(activeTabId: tabId),
              ),
              focusedPaneId: pane.id,
            ),
          );
          return;
        }
      }
    }
    final pane = current.focusedPane;
    _apply(
      current.copyWith(
        sessions: sessions,
        terminals: terminals,
        tabs: <String, WorkspaceTabEntry>{
          ...current.tabs,
          preferredId: WorkspaceTabEntry(id: preferredId, target: target),
        },
        root: _replacePane(
          current.root,
          pane.id,
          pane.copyWith(
            tabIds: <String>[...pane.tabIds, preferredId],
            activeTabId: preferredId,
          ),
        ),
      ),
    );
  }

  Future<void> _closeWhere(bool Function(WorkspaceTabTarget) matches) async {
    final current = state.requireValue;
    for (final pane in current.panes) {
      for (final tabId in pane.tabIds) {
        if (matches(current.tabs[tabId]!.target)) {
          await _closeTab(current, pane, tabId);
          return;
        }
      }
    }
  }

  Future<void> _closeTab(
    SessionTabsState current,
    PaneNode pane,
    String tabId,
  ) async {
    final nextTabs = Map<String, WorkspaceTabEntry>.of(current.tabs)
      ..remove(tabId);
    final remaining = pane.tabIds.where((id) => id != tabId).toList();
    WorkspacePaneNode root;
    var focusedPaneId = current.focusedPaneId;
    if (remaining.isNotEmpty) {
      root = _replacePane(
        current.root,
        pane.id,
        pane.copyWith(
          tabIds: remaining,
          activeTabId: pane.activeTabId == tabId
              ? remaining.last
              : pane.activeTabId,
        ),
      );
    } else if (current.panes.length > 1) {
      root = _removePane(current.root, pane.id)!;
      if (focusedPaneId == pane.id) focusedPaneId = _panes(root).first.id;
    } else {
      final draftId = 'draft:${ref.read(appIdGeneratorProvider).generate()}';
      nextTabs[draftId] = WorkspaceTabEntry(
        id: draftId,
        target: const DraftTabTarget(),
      );
      root = PaneNode(
        id: pane.id,
        tabIds: <String>[draftId],
        activeTabId: draftId,
      );
    }
    _apply(
      current.copyWith(
        tabs: nextTabs,
        root: root,
        focusedPaneId: focusedPaneId,
      ),
    );
  }

  SessionTabsState _restore(
    List<SessionDto> sessions,
    List<TerminalDto> terminals,
    SessionTabPreference? saved,
  ) {
    final sessionIds = sessions.map((item) => item.id).toSet();
    final terminalIds = terminals.map((item) => item.id).toSet();
    if (saved != null) {
      try {
        final entries = <String, WorkspaceTabEntry>{};
        for (final tab in saved.tabs) {
          final target = switch (tab.kind) {
            WorkspaceTabTargetKind.session
                when tab.targetId != null &&
                    sessionIds.contains(tab.targetId) =>
              SessionTabTarget(tab.targetId!),
            WorkspaceTabTargetKind.terminal
                when tab.targetId != null &&
                    terminalIds.contains(tab.targetId) =>
              TerminalTabTarget(tab.targetId!),
            WorkspaceTabTargetKind.draft when tab.targetId == null =>
              const DraftTabTarget(),
            _ => null,
          };
          if (target != null && !entries.containsKey(tab.id)) {
            entries[tab.id] = WorkspaceTabEntry(id: tab.id, target: target);
          }
        }
        final seen = <String>{};
        final restoredRoot = _restoreNode(
          saved.root,
          entries.keys.toSet(),
          seen,
        );
        final root = restoredRoot == null
            ? null
            : normalizeWorkspacePaneCount(restoredRoot, saved.focusedPaneId);
        if (root != null && entries.isNotEmpty) {
          entries.removeWhere((id, _) => !seen.contains(id));
          final panes = _panes(root);
          final focused = panes.any((pane) => pane.id == saved.focusedPaneId)
              ? saved.focusedPaneId
              : panes.first.id;
          return SessionTabsState(
            sessions: sessions,
            terminals: terminals,
            tabs: Map<String, WorkspaceTabEntry>.unmodifiable(entries),
            root: root,
            focusedPaneId: focused,
          );
        }
      } on FormatException {
        // The entire entry is replaced below; daemon-owned content is intact.
      }
    }
    final paneId = 'pane:${ref.read(appIdGeneratorProvider).generate()}';
    final tabId = 'draft:${ref.read(appIdGeneratorProvider).generate()}';
    return SessionTabsState(
      sessions: sessions,
      terminals: terminals,
      tabs: <String, WorkspaceTabEntry>{
        tabId: WorkspaceTabEntry(id: tabId, target: const DraftTabTarget()),
      },
      root: PaneNode(id: paneId, tabIds: <String>[tabId], activeTabId: tabId),
      focusedPaneId: paneId,
    );
  }

  void _apply(SessionTabsState next) {
    state = AsyncData<SessionTabsState>(next);
    unawaited(_persistBestEffort(next));
  }

  Future<void> _persistBestEffort(SessionTabsState value) async {
    try {
      await _persist(value);
    } on Exception {
      // Layout persistence is best-effort: a failed device-settings write
      // costs at most the saved tab layout on next launch, and must never
      // block or roll back the live pane tree the user is interacting with.
    }
  }

  Future<void> _persist(SessionTabsState value) {
    final persisted = value.tabs.values
        .map(_entryPreference)
        .nonNulls
        .toList(growable: false);
    final persistedIds = persisted.map((tab) => tab.id).toSet();
    return ref
        .read(hostRegistryControllerProvider.notifier)
        .saveWorkspaceUi(
          selection: _selection,
          tabs: SessionTabPreference(
            tabs: persisted,
            root: _nodePreference(value.root, persistedIds),
            focusedPaneId: value.focusedPaneId,
          ),
        );
  }
}

WorkspaceTabPreference? _entryPreference(WorkspaceTabEntry entry) =>
    switch (entry.target) {
      SessionTabTarget(:final sessionId) => WorkspaceTabPreference(
        id: entry.id,
        kind: WorkspaceTabTargetKind.session,
        targetId: sessionId,
      ),
      TerminalTabTarget(:final terminalId) => WorkspaceTabPreference(
        id: entry.id,
        kind: WorkspaceTabTargetKind.terminal,
        targetId: terminalId,
      ),
      DraftTabTarget() => WorkspaceTabPreference(
        id: entry.id,
        kind: WorkspaceTabTargetKind.draft,
      ),
      // A PTY that never finished creating has nothing to restore into.
      PendingTerminalTabTarget() => null,
    };

WorkspacePanePreferenceNode _nodePreference(
  WorkspacePaneNode node,
  Set<String> persistedTabIds,
) => switch (node) {
  PaneNode() => WorkspacePanePreference(
    id: node.id,
    tabIds: node.tabIds.where(persistedTabIds.contains).toList(growable: false),
    // A pending active tab is absent from the persisted ids; restoring
    // falls back to the last surviving tab in `_restoreNode`.
    activeTabId: node.activeTabId,
  ),
  WorkspaceSplitNode() => WorkspaceSplitPreference(
    id: node.id,
    axis: node.axis,
    ratio: node.ratio,
    first: _nodePreference(node.first, persistedTabIds),
    second: _nodePreference(node.second, persistedTabIds),
  ),
};

WorkspacePaneNode? _restoreNode(
  WorkspacePanePreferenceNode node,
  Set<String> validTabs,
  Set<String> seen,
) => switch (node) {
  WorkspacePanePreference() => () {
    final ids = node.tabIds
        .where((id) => validTabs.contains(id) && seen.add(id))
        .toList(growable: false);
    if (ids.isEmpty) return null;
    return PaneNode(
      id: node.id,
      tabIds: ids,
      activeTabId: ids.contains(node.activeTabId) ? node.activeTabId : ids.last,
    );
  }(),
  WorkspaceSplitPreference() => () {
    final first = _restoreNode(node.first, validTabs, seen);
    final second = _restoreNode(node.second, validTabs, seen);
    if (first == null) return second;
    if (second == null) return first;
    return WorkspaceSplitNode(
      id: node.id,
      axis: node.axis,
      ratio: node.ratio,
      first: first,
      second: second,
    );
  }(),
};

bool _sameTarget(WorkspaceTabTarget first, WorkspaceTabTarget second) =>
    switch ((first, second)) {
      (
        SessionTabTarget(sessionId: final firstId),
        SessionTabTarget(sessionId: final secondId),
      ) =>
        firstId == secondId,
      (
        TerminalTabTarget(terminalId: final firstId),
        TerminalTabTarget(terminalId: final secondId),
      ) =>
        firstId == secondId,
      (DraftTabTarget(), DraftTabTarget()) => false,
      _ => false,
    };

List<PaneNode> _panes(WorkspacePaneNode node) => switch (node) {
  PaneNode() => <PaneNode>[node],
  WorkspaceSplitNode() => <PaneNode>[
    ..._panes(node.first),
    ..._panes(node.second),
  ],
};

/// Limits a restored layout to two content panes while retaining every tab.
WorkspacePaneNode normalizeWorkspacePaneCount(
  WorkspacePaneNode root,
  String focusedPaneId,
) {
  final panes = _panes(root);
  if (panes.length <= 2) return root;
  final first = panes.first;
  final focused = panes.firstWhere(
    (pane) => pane.id == focusedPaneId,
    orElse: () => first,
  );
  final second = identical(first, focused) ? panes[1] : focused;
  final mergedIds = <String>[
    for (final pane in panes)
      if (pane.id != first.id) ...pane.tabIds,
  ];
  final mergedSecond = second.copyWith(
    tabIds: mergedIds,
    activeTabId: second.activeTabId,
  );
  return WorkspaceSplitNode(
    id: root is WorkspaceSplitNode ? root.id : 'split:${first.id}:${second.id}',
    axis: WorkspaceSplitAxis.horizontal,
    ratio: root is WorkspaceSplitNode ? root.ratio : 0.5,
    first: first,
    second: mergedSecond,
  );
}

PaneNode? _findPane(WorkspacePaneNode node, String id) => switch (node) {
  PaneNode() => node.id == id ? node : null,
  WorkspaceSplitNode() =>
    _findPane(node.first, id) ?? _findPane(node.second, id),
};

WorkspacePaneNode _replacePane(
  WorkspacePaneNode node,
  String id,
  PaneNode replacement,
) => _replaceNode(node, id, replacement);

WorkspacePaneNode _replaceNode(
  WorkspacePaneNode node,
  String targetId,
  WorkspacePaneNode replacement,
) {
  if (node case PaneNode(:final id) when id == targetId) return replacement;
  if (node is PaneNode) return node;
  final split = node as WorkspaceSplitNode;
  if (split.id == targetId) return replacement;
  return WorkspaceSplitNode(
    id: split.id,
    axis: split.axis,
    ratio: split.ratio,
    first: _replaceNode(split.first, targetId, replacement),
    second: _replaceNode(split.second, targetId, replacement),
  );
}

WorkspacePaneNode? _removePane(WorkspacePaneNode node, String paneId) {
  if (node is PaneNode) return node.id == paneId ? null : node;
  final split = node as WorkspaceSplitNode;
  final first = _removePane(split.first, paneId);
  final second = _removePane(split.second, paneId);
  if (first == null) return second;
  if (second == null) return first;
  return WorkspaceSplitNode(
    id: split.id,
    axis: split.axis,
    ratio: split.ratio,
    first: first,
    second: second,
  );
}

WorkspacePaneNode _replaceSplitRatio(
  WorkspacePaneNode node,
  String splitId,
  double ratio,
) {
  if (node is PaneNode) return node;
  final split = node as WorkspaceSplitNode;
  return WorkspaceSplitNode(
    id: split.id,
    axis: split.axis,
    ratio: split.id == splitId ? ratio : split.ratio,
    first: _replaceSplitRatio(split.first, splitId, ratio),
    second: _replaceSplitRatio(split.second, splitId, ratio),
  );
}
