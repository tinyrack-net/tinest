import 'dart:async';

import 'package:app/src/app/presentation/settings_page.dart';
import 'package:app/src/app/presentation/workspace_page.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/hosts/presentation/pages/host_settings_page.dart';
import 'package:app/src/features/hosts/presentation/pages/relay_pairing_pages.dart';
import 'package:app/src/features/settings/domain/settings_category.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

part 'app_router.g.dart';

// The app moves in three different ways and each needs its own router verb.
//
// A modal task such as settings or daemon editing is pushed, so closing it can
// pop back to whatever the user was doing and the exit transition is the
// entry transition played in reverse. A lateral move inside one surface —
// settings categories, workspace and session selection — uses `replace`, which
// keeps the page key so no transition plays at all and the push depth beneath
// it survives. `go` is reserved for entering a root destination or for
// deliberately clearing the stack.

/// Whether [uri] addresses any settings surface.
bool _isSettingsLocation(Uri uri) => uri.path.startsWith('/settings');

MaterialPage<void> _settingsContentPage(
  GoRouterState state, {
  required String name,
  required SettingsRouteContentKind kind,
  SettingsCategory? category,
  String? hostId,
  String? workspaceId,
}) => MaterialPage<void>(
  key: state.pageKey,
  name: name,
  restorationId: name,
  child: TRSurface(
    child: KeyedSubtree(
      key: category == null
          ? null
          : ValueKey<String>('settings-category-pane-${category.name}'),
      child: SettingsRouteContent(
        kind: kind,
        category: category,
        hostId: hostId,
        workspaceId: workspaceId,
      ),
    ),
  ),
);

typedef _SettingsRouteConfiguration = ({
  SettingsCategory? category,
  String? hostId,
  String? workspaceId,
});

_SettingsRouteConfiguration _settingsRouteConfiguration(Uri uri) {
  final segments = uri.pathSegments;
  if (segments.length == 4 &&
      segments[1] == 'daemons' &&
      segments[3] == 'categories') {
    return (category: null, hostId: segments[2], workspaceId: null);
  }
  if (segments.length == 4 &&
      segments[1] == 'daemons' &&
      segments[3] == 'connections') {
    return (
      category: SettingsCategory.connection,
      hostId: segments[2],
      workspaceId: null,
    );
  }
  final category = switch (segments.length > 1 ? segments[1] : null) {
    'general' => SettingsCategory.general,
    'providers' => SettingsCategory.provider,
    'models' => SettingsCategory.model,
    'permissions' => SettingsCategory.permission,
    'projects' => SettingsCategory.project,
    'agents' => SettingsCategory.agent,
    'plugins' => SettingsCategory.plugin,
    'mcp' => SettingsCategory.mcp,
    'skills' => SettingsCategory.skill,
    'daemons' => SettingsCategory.daemon,
    'advanced' => SettingsCategory.advanced,
    _ => null,
  };
  return (
    category: category,
    hostId: uri.queryParameters['host-id'],
    workspaceId: uri.queryParameters['workspace-id'],
  );
}

typedef _WorkspaceRouteConfiguration = ({
  bool compose,
  String? requestedAgentId,
  String? requestedTerminalId,
  WorkspaceSelection? selection,
});

_WorkspaceRouteConfiguration _workspaceRouteConfiguration(Uri uri) {
  final segments = uri.pathSegments;
  if (segments.length >= 4 && segments.first == 'workspaces') {
    final selection = WorkspaceSelection(
      hostId: segments[1],
      workspaceId: segments[2],
      worktreeId: segments[3],
    );
    if (segments.length == 6 && segments[4] == 'sessions') {
      return (
        compose: false,
        requestedAgentId: segments[5],
        requestedTerminalId: null,
        selection: selection,
      );
    }
    if (segments.length == 6 && segments[4] == 'terminals') {
      return (
        compose: false,
        requestedAgentId: null,
        requestedTerminalId: segments[5],
        selection: selection,
      );
    }
    return (
      compose: false,
      requestedAgentId: null,
      requestedTerminalId: null,
      selection: selection,
    );
  }
  return (
    compose: uri.queryParameters['compose'] == 'true',
    requestedAgentId: null,
    requestedTerminalId: null,
    selection: null,
  );
}

MaterialPage<void> _workspaceContentPage(
  GoRouterState state, {
  required Widget child,
  bool sharedIdentity = false,
  String? name,
}) => MaterialPage<void>(
  // GoRouter's replace operation carries the replaced match's pageKey into
  // the new match. Using that key preserves one content Route without
  // assigning unrelated direct-link matches the same global identity.
  key: state.pageKey,
  name: sharedIdentity ? 'workspace-content' : name ?? 'workspace-home',
  restorationId: sharedIdentity
      ? 'workspace-content'
      : name ?? 'workspace-home',
  child: TRSurface(child: child),
);

/// Closes a pushed task and returns to the screen it was opened from.
///
/// A task can also be entered directly, by deep link or by a tray activation
/// into a hidden window, and then has nothing beneath it to return to.
/// [fallback] names the destination for that case.
void closeTask(BuildContext context, VoidCallback fallback) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  fallback();
}

/// Opens settings from outside the widget tree, such as the tray or menu bar.
///
/// Those entry points can fire repeatedly while settings is already open, and
/// stacking a second copy would make the first Back press look like it did
/// nothing, so an open settings task is replaced instead of pushed.
void openSettingsTask(GoRouter router) {
  const target = SettingsHomeRoute();
  // `state` is the top-most match; the route information provider only reports
  // the base configuration, which a pushed task never moves.
  if (_isSettingsLocation(router.state.uri)) {
    unawaited(router.replace<void>(target.location));
    return;
  }
  unawaited(router.push<void>(target.location));
}

@TypedShellRoute<SettingsShellRoute>(
  routes: <TypedRoute<RouteData>>[
    TypedGoRoute<SettingsHomeRoute>(path: '/settings'),
    TypedGoRoute<DaemonCategoriesRoute>(
      path: '/settings/daemons/:hostId/categories',
    ),
    TypedGoRoute<GeneralSettingsRoute>(path: '/settings/general'),
    TypedGoRoute<ProviderSettingsRoute>(path: '/settings/providers'),
    TypedGoRoute<ModelSettingsRoute>(path: '/settings/models'),
    TypedGoRoute<PermissionSettingsRoute>(path: '/settings/permissions'),
    TypedGoRoute<ProjectSettingsRoute>(path: '/settings/projects'),
    TypedGoRoute<AgentSettingsRoute>(path: '/settings/agents'),
    TypedGoRoute<PluginSettingsRoute>(path: '/settings/plugins'),
    TypedGoRoute<McpSettingsRoute>(path: '/settings/mcp'),
    TypedGoRoute<SkillSettingsRoute>(path: '/settings/skills'),
    TypedGoRoute<DaemonSettingsRoute>(path: '/settings/daemons'),
    TypedGoRoute<AdvancedSettingsRoute>(path: '/settings/advanced'),
    TypedGoRoute<DaemonConnectionsRoute>(
      path: '/settings/daemons/:hostId/connections',
    ),
  ],
)
/// Stable Settings frame whose child Navigator owns route history.
class SettingsShellRoute extends ShellRouteData {
  /// Creates the Settings shell.
  const new();

  /// Navigator used for hierarchical Settings pages.
  static final GlobalKey<NavigatorState> $navigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'settings-shell');

  @override
  Page<void> pageBuilder(
    BuildContext context,
    GoRouterState state,
    Widget navigator,
  ) {
    final configuration = _settingsRouteConfiguration(state.uri);
    return MaterialPage<void>(
      key: const ValueKey<String>('settings-shell'),
      name: 'settings-shell',
      restorationId: 'settings-shell',
      child: UnifiedSettingsPage(
        navigator: navigator,
        category: configuration.category,
        hostId: configuration.hostId,
        workspaceId: configuration.workspaceId,
      ),
    );
  }
}

/// Responsive settings entry: navigation home on compact widths, General on
/// wider layouts.
class SettingsHomeRoute extends GoRouteData with $SettingsHomeRoute {
  /// Creates the settings entry route.
  const new();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      _settingsContentPage(
        state,
        name: 'settings-home',
        kind: SettingsRouteContentKind.home,
      );
}

/// Compact daemon category pane, with Provider selected on wider layouts.
class DaemonCategoriesRoute extends GoRouteData with $DaemonCategoriesRoute {
  /// Creates a daemon category route.
  const new({required this.hostId});

  /// App-local daemon profile identifier.
  final String hostId;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      _settingsContentPage(
        state,
        name: 'settings-daemon-categories',
        kind: SettingsRouteContentKind.daemonCategories,
        hostId: hostId,
      );
}

@TypedShellRoute<WorkspaceShellRoute>(
  routes: <TypedRoute<RouteData>>[
    TypedGoRoute<WorkspaceHomeRoute>(
      path: '/',
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<WorktreeRoute>(
          path: 'workspaces/:hostId/:workspaceId/:worktreeId',
        ),
        TypedGoRoute<SessionRoute>(
          path:
              'workspaces/:hostId/:workspaceId/:worktreeId/'
              'sessions/:sessionId',
        ),
        TypedGoRoute<TerminalRoute>(
          path:
              'workspaces/:hostId/:workspaceId/:worktreeId/'
              'terminals/:terminalId',
        ),
      ],
    ),
  ],
)
/// Stable workspace frame whose child Navigator owns content history.
class WorkspaceShellRoute extends ShellRouteData {
  /// Creates the workspace shell.
  const new();

  /// Navigator used for workspace home and content pages.
  static final GlobalKey<NavigatorState> $navigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'workspace-shell');

  @override
  Page<void> pageBuilder(
    BuildContext context,
    GoRouterState state,
    Widget navigator,
  ) {
    final configuration = _workspaceRouteConfiguration(state.uri);
    return NoTransitionPage<void>(
      key: const ValueKey<String>('workspace-shell'),
      name: 'workspace-shell',
      restorationId: 'workspace-shell',
      child: WorkspacePage(
        navigator: navigator,
        selection: configuration.selection,
        requestedAgentId: configuration.requestedAgentId,
        requestedTerminalId: configuration.requestedTerminalId,
        compose: configuration.compose,
      ),
    );
  }
}

/// Unified workspace home shown before daemon connections complete.
class WorkspaceHomeRoute extends GoRouteData with $WorkspaceHomeRoute {
  /// Creates the workspace home route.
  const new({this.compose = false});

  /// Whether the right pane opens the new-workspace composer directly.
  final bool compose;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      _workspaceContentPage(
        state,
        name: compose ? 'workspace-compose' : 'workspace-home',
        child: WorkspaceRouteContent(compose: compose),
      );
}

/// Opens a checkout and its session tabs.
class WorktreeRoute extends GoRouteData with $WorktreeRoute {
  /// Creates a checkout route.
  const new({
    required this.hostId,
    required this.workspaceId,
    required this.worktreeId,
  });

  /// App-local daemon ID.
  final String hostId;

  /// Daemon-local repository ID.
  final String workspaceId;

  /// Daemon-local checkout ID.
  final String worktreeId;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      _workspaceContentPage(
        state,
        sharedIdentity: true,
        child: WorkspaceRouteContent(
          selection: WorkspaceSelection(
            hostId: hostId,
            workspaceId: workspaceId,
            worktreeId: worktreeId,
          ),
        ),
      );
}

/// Opens one AI session in the checkout tab strip.
class SessionRoute extends GoRouteData with $SessionRoute {
  /// Creates a session route.
  const new({
    required this.hostId,
    required this.workspaceId,
    required this.worktreeId,
    required this.sessionId,
  });

  /// App-local daemon ID.
  final String hostId;

  /// Daemon-local repository ID.
  final String workspaceId;

  /// Daemon-local checkout ID.
  final String worktreeId;

  /// Daemon-local AI session ID.
  final String sessionId;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      _workspaceContentPage(
        state,
        sharedIdentity: true,
        child: WorkspaceRouteContent(
          selection: WorkspaceSelection(
            hostId: hostId,
            workspaceId: workspaceId,
            worktreeId: worktreeId,
          ),
          requestedAgentId: sessionId,
        ),
      );
}

/// Opens one daemon terminal in the checkout tab strip.
class TerminalRoute extends GoRouteData with $TerminalRoute {
  /// Creates a terminal route.
  const new({
    required this.hostId,
    required this.workspaceId,
    required this.worktreeId,
    required this.terminalId,
  });

  /// App-local daemon ID.
  final String hostId;

  /// Daemon-local repository ID.
  final String workspaceId;

  /// Daemon-local checkout ID.
  final String worktreeId;

  /// Daemon-local terminal ID.
  final String terminalId;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      _workspaceContentPage(
        state,
        sharedIdentity: true,
        child: WorkspaceRouteContent(
          selection: WorkspaceSelection(
            hostId: hostId,
            workspaceId: workspaceId,
            worktreeId: worktreeId,
          ),
          requestedTerminalId: terminalId,
        ),
      );
}

/// Unified settings route with General selected.
class GeneralSettingsRoute extends GoRouteData with $GeneralSettingsRoute {
  /// Creates the general settings route.
  const new();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      _settingsContentPage(
        state,
        name: 'settings-category-general',
        kind: SettingsRouteContentKind.category,
        category: SettingsCategory.general,
      );
}

/// Unified settings route with Provider selected.
class ProviderSettingsRoute extends GoRouteData with $ProviderSettingsRoute {
  /// Creates the provider settings route.
  const new({this.hostId});

  /// Preferred daemon in the provider selector.
  final String? hostId;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      _settingsContentPage(
        state,
        name: 'settings-category-provider',
        kind: SettingsRouteContentKind.category,
        category: SettingsCategory.provider,
        hostId: hostId,
      );
}

/// Unified settings route with Model selected.
class ModelSettingsRoute extends GoRouteData with $ModelSettingsRoute {
  /// Creates the model settings route.
  const new({this.hostId});

  /// Preferred daemon in the model selector.
  final String? hostId;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      _settingsContentPage(
        state,
        name: 'settings-category-model',
        kind: SettingsRouteContentKind.category,
        category: SettingsCategory.model,
        hostId: hostId,
      );
}

/// Unified settings route with Permissions selected.
class PermissionSettingsRoute extends GoRouteData
    with $PermissionSettingsRoute {
  /// Creates the permission settings route.
  const new({this.hostId});

  /// Preferred daemon in the permission selector.
  final String? hostId;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      _settingsContentPage(
        state,
        name: 'settings-category-permission',
        kind: SettingsRouteContentKind.category,
        category: SettingsCategory.permission,
        hostId: hostId,
      );
}

/// Unified settings route with Projects selected.
class ProjectSettingsRoute extends GoRouteData with $ProjectSettingsRoute {
  /// Creates the project settings route.
  const new({this.hostId});

  /// Preferred daemon in the project selector.
  final String? hostId;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      _settingsContentPage(
        state,
        name: 'settings-category-project',
        kind: SettingsRouteContentKind.category,
        category: SettingsCategory.project,
        hostId: hostId,
      );
}

/// Unified settings route with Agent selected.
class AgentSettingsRoute extends GoRouteData with $AgentSettingsRoute {
  /// Creates the agent settings route.
  const new({this.hostId});

  /// Preferred daemon in the agent selector.
  final String? hostId;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      _settingsContentPage(
        state,
        name: 'settings-category-agent',
        kind: SettingsRouteContentKind.category,
        category: SettingsCategory.agent,
        hostId: hostId,
      );
}

/// Unified settings route with Plugins selected.
class PluginSettingsRoute extends GoRouteData with $PluginSettingsRoute {
  /// Creates the plugin settings route.
  const new({this.hostId});

  /// Preferred daemon in the plugin selector.
  final String? hostId;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      _settingsContentPage(
        state,
        name: 'settings-category-plugin',
        kind: SettingsRouteContentKind.category,
        category: SettingsCategory.plugin,
        hostId: hostId,
      );
}

/// Unified settings route with MCP selected.
class McpSettingsRoute extends GoRouteData with $McpSettingsRoute {
  /// Creates the MCP settings route.
  const new({this.hostId});

  /// Preferred daemon in the MCP selector.
  final String? hostId;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      _settingsContentPage(
        state,
        name: 'settings-category-mcp',
        kind: SettingsRouteContentKind.category,
        category: SettingsCategory.mcp,
        hostId: hostId,
      );
}

/// Unified settings route with Skill selected.
class SkillSettingsRoute extends GoRouteData with $SkillSettingsRoute {
  /// Creates the skill settings route.
  const new({this.hostId, this.workspaceId});

  /// Preferred daemon in the skill selector.
  final String? hostId;

  /// Project whose skills layer on top of the global sources.
  final String? workspaceId;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      _settingsContentPage(
        state,
        name: 'settings-category-skill',
        kind: SettingsRouteContentKind.category,
        category: SettingsCategory.skill,
        hostId: hostId,
        workspaceId: workspaceId,
      );
}

/// Unified settings route with Daemon selected.
class DaemonSettingsRoute extends GoRouteData with $DaemonSettingsRoute {
  /// Creates daemon settings route.
  const new();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      _settingsContentPage(
        state,
        name: 'settings-category-daemon',
        kind: SettingsRouteContentKind.category,
        category: SettingsCategory.daemon,
      );
}

/// Unified settings route with Advanced selected.
class AdvancedSettingsRoute extends GoRouteData with $AdvancedSettingsRoute {
  /// Creates the advanced settings route.
  const new();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      _settingsContentPage(
        state,
        name: 'settings-category-advanced',
        kind: SettingsRouteContentKind.category,
        category: SettingsCategory.advanced,
      );
}

@TypedGoRoute<ConnectDaemonRoute>(path: '/connect')
/// Chooses how to connect a daemon.
class ConnectDaemonRoute extends GoRouteData with $ConnectDaemonRoute {
  /// Creates the route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ConnectDaemonPage();
}

@TypedGoRoute<PairingLinkRoute>(path: '/connect/link')
/// Accepts a one-time HTTPS daemon connection link.
class PairingLinkRoute extends GoRouteData with $PairingLinkRoute {
  /// Creates the route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const PairingLinkPage();
}

@TypedGoRoute<PairingScanRoute>(path: '/connect/scan')
/// Scans a daemon connection QR code on supported native devices.
class PairingScanRoute extends GoRouteData with $PairingScanRoute {
  /// Creates the route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const PairingScanPage();
}

@TypedGoRoute<PairOfferRoute>(path: '/pair')
/// Reviews the fragment-only pairing capability from a web or app link.
class PairOfferRoute extends GoRouteData with $PairOfferRoute {
  /// Creates the route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      PairOfferPage(pairingUrl: state.uri);
}

@TypedGoRoute<AdvancedNewHostRoute>(path: '/connect/direct')
/// Adds a direct WebSocket connection for advanced users.
class AdvancedNewHostRoute extends GoRouteData with $AdvancedNewHostRoute {
  /// Creates the route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const RemoteHostEditPage();
}

/// Opens one daemon's connection, pairing, and approved-device settings.
class DaemonConnectionsRoute extends GoRouteData with $DaemonConnectionsRoute {
  /// Creates the route.
  const new({required this.hostId});

  /// App-local daemon profile identifier.
  final String hostId;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      _settingsContentPage(
        state,
        name: 'settings-category-connection',
        kind: SettingsRouteContentKind.category,
        category: SettingsCategory.connection,
        hostId: hostId,
      );
}

@TypedGoRoute<EditHostRoute>(path: '/settings/daemons/:hostId')
/// Edits a remote daemon profile.
class EditHostRoute extends GoRouteData with $EditHostRoute {
  /// Creates the route.
  const new({required this.hostId});

  /// App-local daemon profile ID.
  final String hostId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      RemoteHostEditPage(hostId: hostId);
}
