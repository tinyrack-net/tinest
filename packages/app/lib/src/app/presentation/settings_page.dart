import 'dart:async';

import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/features/agents/presentation/pages/agent_settings_page.dart';
import 'package:app/src/features/hosts/application/host_controller.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/hosts/presentation/host_labels.dart';
import 'package:app/src/features/hosts/presentation/pages/host_settings_page.dart';
import 'package:app/src/features/hosts/presentation/pages/relay_pairing_pages.dart';
import 'package:app/src/features/mcp/presentation/pages/mcp_settings_page.dart';
import 'package:app/src/features/models/presentation/pages/model_settings_page.dart';
import 'package:app/src/features/permissions/presentation/pages/permission_settings_page.dart';
import 'package:app/src/features/plugins/presentation/pages/plugin_settings_page.dart';
import 'package:app/src/features/providers/presentation/pages/provider_settings_page.dart';
import 'package:app/src/features/settings/domain/settings_category.dart';
import 'package:app/src/features/settings/presentation/pages/advanced_settings_page.dart';
import 'package:app/src/features/settings/presentation/pages/general_settings_page.dart';
import 'package:app/src/features/skills/presentation/pages/skill_settings_page.dart';
import 'package:app/src/features/workspace/presentation/pages/project_settings_page.dart';
import 'package:app/src/shared/presentation/settings_layout.dart';
import 'package:app/src/shared/presentation/tinest_icons.dart';
import 'package:app/src/shared/presentation/tinest_layout_metrics.dart';
import 'package:app/src/shared/presentation/tinest_page_shell.dart';
import 'package:app/src/shared/presentation/tinest_select_presentation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// The categories carried by one sidebar section, in display order.
List<SettingsCategory> _categoriesInScope(SettingsCategoryScope scope) =>
    SettingsCategory.values
        .where((category) => category.scope == scope)
        .toList(growable: false);

/// Shared responsive settings shell.
class UnifiedSettingsPage extends ConsumerStatefulWidget {
  /// Creates a unified settings page.
  const new({
    required this.navigator,
    this.category,
    this.hostId,
    this.workspaceId,
    super.key,
  });

  /// Navigator built by the typed Settings shell.
  final Widget navigator;

  /// Selected settings category, or null for a compact navigation pane.
  final SettingsCategory? category;

  /// Preferred provider daemon.
  final String? hostId;

  /// Project selected on the skill page.
  final String? workspaceId;

  @override
  ConsumerState<UnifiedSettingsPage> createState() =>
      _UnifiedSettingsPageState();
}

class _UnifiedSettingsPageState extends ConsumerState<UnifiedSettingsPage> {
  late final ProjectSettingsPaneController _projectPanes;
  late final AgentSettingsPaneController _agentPanes;
  late final PluginSettingsPaneController _pluginPanes;
  late final McpSettingsPaneController _mcpPanes;
  late final ProviderSettingsPaneController _providerPanes;
  late final Map<SettingsCategory, SettingsPaneCoordinator> _paneControllers;
  String? _routeHostAdoptionScheduled;

  SettingsCategory get _effectiveCategory =>
      widget.category ??
      (widget.hostId == null
          ? SettingsCategory.general
          : SettingsCategory.provider);

  /// The category a route configuration puts on screen, or null when it is a
  /// navigation screen rather than a category.
  ///
  /// Compact keeps `settings-home` and `settings-daemon-categories` as their
  /// own screens. Wider layouts already show every category in the sidebar, so
  /// those two routes render General and Provider instead. Local pane state
  /// must follow what is rendered, not what the URL says.
  static SettingsCategory? _renderedCategory(
    SettingsCategory? category,
    String? hostId, {
    required bool compact,
  }) {
    if (category != null) return category;
    if (compact) return null;
    return hostId == null
        ? SettingsCategory.general
        : SettingsCategory.provider;
  }

  @override
  void initState() {
    super.initState();
    _projectPanes = ProjectSettingsPaneController();
    _agentPanes = AgentSettingsPaneController();
    _pluginPanes = PluginSettingsPaneController();
    _mcpPanes = McpSettingsPaneController();
    _providerPanes = ProviderSettingsPaneController();
    _paneControllers = <SettingsCategory, SettingsPaneCoordinator>{
      SettingsCategory.project: _projectPanes,
      SettingsCategory.agent: _agentPanes,
      SettingsCategory.plugin: _pluginPanes,
      SettingsCategory.mcp: _mcpPanes,
      SettingsCategory.provider: _providerPanes,
    };
  }

  @override
  void dispose() {
    _projectPanes.dispose();
    _agentPanes.dispose();
    _pluginPanes.dispose();
    _mcpPanes.dispose();
    _providerPanes.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(UnifiedSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Two URLs can render the same category with the same daemon: the sidebar
    // drops `host-id` in favour of the persisted daemon, and a wide layout
    // renders `settings-daemon-categories` as Provider. Resetting on the raw
    // route identity would throw away the user's selection on those moves, and
    // re-arm the one-shot initial selection so the collection reopens its first
    // item instead.
    final compact =
        settingsAdaptiveWidthClassOf(context) == TRAdaptiveWidthClass.compact;
    final activeHostId = ref.read(activeHostIdProvider);
    if (_renderedCategory(
              oldWidget.category,
              oldWidget.hostId,
              compact: compact,
            ) !=
            _renderedCategory(
              widget.category,
              widget.hostId,
              compact: compact,
            ) ||
        (oldWidget.hostId ?? activeHostId) != (widget.hostId ?? activeHostId) ||
        oldWidget.workspaceId != widget.workspaceId) {
      for (final controller in _paneControllers.values) {
        controller.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final registryState = ref.watch(hostRegistryControllerProvider);
    final registry = registryState.value;
    _scheduleRouteHostAdoption(registry);
    final registryLoading = registryState.isLoading && !registryState.hasValue;
    final hosts =
        registry?.runtimes.values.toList(growable: false) ??
        const <HostRuntimeSnapshot>[];
    final activeHostId = ref.watch(activeHostIdProvider);
    final hostId = widget.hostId ?? activeHostId;
    final category = _effectiveCategory;
    final l10n = AppLocalizations.of(context);
    Widget categoryContent(
      SettingsCategory category, {
      String? hostId,
      String? workspaceId,
    }) {
      final effectiveHostId = hostId ?? activeHostId;
      final host = effectiveHostId == null
          ? null
          : registry?.runtimes[effectiveHostId];
      final panes = switch (category) {
        SettingsCategory.general => _SettingsPanePair(
          primary: _SettingsSimplePane(
            title: _settingsCategoryLabel(l10n, SettingsCategory.general),
            child: const GeneralSettingsPage(embedded: true),
          ),
        ),
        SettingsCategory.project => _hostListDetailPanes(
          host: host,
          loading: registryLoading,
          semanticLabel: l10n.settingsLoading,
          builder: (hostId, slot) => ProjectSettingsPage(
            hostId: hostId,
            paneController: _projectPanes,
            slot: slot,
          ),
        ),
        SettingsCategory.agent => _hostListDetailPanes(
          host: host,
          loading: registryLoading,
          semanticLabel: l10n.settingsLoading,
          builder: (hostId, slot) => AgentSettingsPage(
            hostId: hostId,
            paneController: _agentPanes,
            slot: slot,
          ),
        ),
        SettingsCategory.plugin => _hostListDetailPanes(
          host: host,
          loading: registryLoading,
          semanticLabel: l10n.settingsLoading,
          builder: (hostId, slot) => PluginSettingsPage(
            hostId: hostId,
            paneController: _pluginPanes,
            slot: slot,
          ),
        ),
        SettingsCategory.mcp => _hostListDetailPanes(
          host: host,
          loading: registryLoading,
          semanticLabel: l10n.settingsLoading,
          builder: (hostId, slot) => McpSettingsPage(
            hostId: hostId,
            paneController: _mcpPanes,
            slot: slot,
          ),
        ),
        SettingsCategory.connection => _SettingsPanePair(
          primary: _SettingsSimplePane(
            title: _settingsCategoryLabel(l10n, SettingsCategory.connection),
            child: _HostScopedDetail(
              host: host,
              loading: registryLoading,
              loadingChild: SettingsSkeletonLayout.form(
                semanticLabel: AppLocalizations.of(context).settingsLoading,
              ),
              builder: (hostId) =>
                  DaemonConnectionsPage(hostId: hostId, embedded: true),
            ),
          ),
        ),
        SettingsCategory.skill => _SettingsPanePair(
          primary: _SettingsSimplePane(
            title: _settingsCategoryLabel(l10n, SettingsCategory.skill),
            child: _HostScopedDetail(
              host: host,
              loading: registryLoading,
              loadingChild: SettingsSkeletonLayout.form(
                semanticLabel: l10n.settingsLoading,
              ),
              builder: (hostId) => SkillSettingsPage(
                hostId: hostId,
                workspaceId: workspaceId,
                onWorkspaceChanged: (value) => SkillSettingsRoute(
                  hostId: hostId,
                  workspaceId: value,
                ).replace(context),
              ),
            ),
          ),
        ),
        SettingsCategory.provider => _hostListDetailPanes(
          host: host,
          loading: registryLoading,
          semanticLabel: l10n.settingsLoading,
          builder: (hostId, slot) => SettingsPage(
            hostId: hostId,
            paneController: _providerPanes,
            slot: slot,
          ),
        ),
        SettingsCategory.model => _SettingsPanePair(
          primary: _SettingsSimplePane(
            title: _settingsCategoryLabel(l10n, SettingsCategory.model),
            child: _HostScopedDetail(
              host: host,
              loading: registryLoading,
              loadingChild: SettingsSkeletonLayout.form(
                semanticLabel: AppLocalizations.of(context).settingsLoading,
              ),
              builder: (hostId) => ModelSettingsPage(hostId: hostId),
            ),
          ),
        ),
        SettingsCategory.permission => _SettingsPanePair(
          primary: _SettingsSimplePane(
            title: _settingsCategoryLabel(l10n, SettingsCategory.permission),
            child: _HostScopedDetail(
              host: host,
              loading: registryLoading,
              loadingChild: SettingsSkeletonLayout.form(
                semanticLabel: AppLocalizations.of(context).settingsLoading,
              ),
              builder: (hostId) => PermissionSettingsPage(hostId: hostId),
            ),
          ),
        ),
        SettingsCategory.daemon => _SettingsPanePair(
          primary: _SettingsSimplePane(
            title: _settingsCategoryLabel(l10n, SettingsCategory.daemon),
            child: const AppSettingsPage(embedded: true),
          ),
        ),
        SettingsCategory.advanced => _SettingsPanePair(
          primary: _SettingsSimplePane(
            title: _settingsCategoryLabel(l10n, SettingsCategory.advanced),
            child: const AdvancedSettingsPage(embedded: true),
          ),
        ),
      };
      final coordinator = _paneControllers[category];
      return panes.secondary == null
          ? panes.primary
          : SettingsListDetailHost(
              key: ValueKey<String>('settings-list-detail-${category.name}'),
              coordinator: coordinator!,
              collection: panes.primary,
              detail: panes.secondary!,
            );
    }

    final routedContent = SettingsShellScope(
      onBack: _goBack,
      child: _SettingsRouteContentScope(
        categoryContent: categoryContent,
        home: SettingsDestinationScaffold(
          title: TRText.inherit(l10n.settingsTitle),
          child: _MobileSettingsHome(
            hosts: hosts,
            onCategorySelected: (category, {hostId}) =>
                _selectCategory(category, hostId: hostId, push: true),
            onDaemonSelected: _selectDaemon,
          ),
        ),
        daemonCategories: (hostId) => _MobileDaemonCategories(
          host: registry?.runtimes[hostId],
          onCategorySelected: (category, {hostId}) =>
              _selectCategory(category, hostId: hostId, push: true),
        ),
        child: widget.navigator,
      ),
    );
    // Measured rather than read from MediaQuery so the shell classifies the
    // same width the adaptive layout below it does. Below the compact
    // breakpoint the destination owns the page header, and the shell
    // contributes only its surface and the adaptive layout.
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            TRAdaptiveWidthClass.fromWidth(constraints.maxWidth) ==
            TRAdaptiveWidthClass.compact;
        return TinestPageShell(
          appBar: compact
              ? null
              : TinestPageHeader(
                  leading: TRIconButton(
                    key: const ValueKey<String>('settings-back-button'),
                    appearance: TRAppearance.ghost,
                    label: MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: _goBack,
                    icon: Icon(TinestIcons.backFor(context)),
                  ),
                  title: TRText.inherit(l10n.settingsTitle),
                ),
          body: TRAdaptiveNavigationLayout(
            navigationPaneWidth: TinestLayoutMetrics.settingsSidebarWidth,
            navigationPane: KeyedSubtree(
              key: const ValueKey<String>('settings-sidebar-surface'),
              child: _SettingsSidebar(
                selected: category,
                hosts: hosts,
                hostId: hostId,
                loading: registryLoading,
                onDaemonSelected: _selectSidebarDaemon,
                onCategorySelected: _selectCategory,
              ),
            ),
            contentPane: routedContent,
          ),
        );
      },
    );
  }

  _SettingsPanePair _hostListDetailPanes({
    required HostRuntimeSnapshot? host,
    required bool loading,
    required String semanticLabel,
    required Widget Function(String hostId, SettingsPaneSlot slot) builder,
  }) => _SettingsPanePair(
    primary: _HostScopedDetail(
      host: host,
      loading: loading,
      loadingChild: SettingsSkeletonLayout.collection(
        semanticLabel: semanticLabel,
      ),
      builder: (hostId) => builder(hostId, SettingsPaneSlot.collection),
    ),
    secondary: _HostScopedDetail(
      host: host,
      loading: loading,
      loadingChild: SettingsSkeletonLayout.detail(semanticLabel: semanticLabel),
      builder: (hostId) => builder(hostId, SettingsPaneSlot.detail),
    ),
  );

  /// Up: the enclosing destination of what is on screen.
  ///
  /// A detail is only a destination of its own while it covers its collection.
  /// Above that width both panes are already visible, and the sidebar keeps
  /// every category one click away, so Settings has nothing above it but the
  /// screen it was opened from. Only compact hides that structure behind the
  /// `settings-home` and `settings-daemon-categories` screens, so only compact
  /// walks up through them.
  void _goBack() {
    final widthClass = settingsAdaptiveWidthClassOf(context);
    final controller = _paneControllers[_effectiveCategory];
    if (!settingsListDetailIsSplit(widthClass) &&
        (controller?.hasDetail ?? false)) {
      // One level, matching the detail stack: a form opened from the catalog
      // returns to the catalog before the catalog returns to the collection.
      controller!.popDetail();
      return;
    }
    if (widthClass != TRAdaptiveWidthClass.compact) {
      _closeSettings();
      return;
    }
    final category = widget.category;
    if (category != null) {
      final hostId = widget.hostId;
      if (category.scope == SettingsCategoryScope.daemon && hostId != null) {
        _popToSettingsParent(
          'settings-daemon-categories',
          () => DaemonCategoriesRoute(hostId: hostId).replace(context),
        );
        return;
      }
      _popToSettingsParent(
        'settings-home',
        () => const SettingsHomeRoute().replace(context),
      );
      return;
    }
    if (widget.hostId != null) {
      _popToSettingsParent(
        'settings-home',
        () => const SettingsHomeRoute().replace(context),
      );
      return;
    }
    _closeSettings();
  }

  /// Leaves the settings task, or goes home when it was deep-linked into.
  ///
  /// One press per page: compact pushes categories, so a window widened
  /// mid-task can still hold pages the user pushed while it was narrow, and
  /// each of those is popped on its own press.
  void _closeSettings() =>
      closeTask(context, () => const WorkspaceHomeRoute().go(context));

  void _scheduleRouteHostAdoption(HostRegistryState? registry) {
    final requested = widget.hostId;
    if (requested == null ||
        registry == null ||
        !registry.runtimes.containsKey(requested) ||
        registry.settings.lastActiveHostId == requested ||
        _routeHostAdoptionScheduled == requested) {
      return;
    }
    _routeHostAdoptionScheduled = requested;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_routeHostAdoptionScheduled == requested) {
        _routeHostAdoptionScheduled = null;
      }
      if (!mounted || widget.hostId != requested) return;
      final latest = ref.read(hostRegistryControllerProvider).value;
      if (latest == null ||
          !latest.runtimes.containsKey(requested) ||
          latest.settings.lastActiveHostId == requested) {
        return;
      }
      unawaited(
        ref.read(hostRegistryControllerProvider.notifier).selectHost(requested),
      );
    });
  }

  void _popToSettingsParent(String routeName, VoidCallback replace) {
    final navigator = SettingsShellRoute.$navigatorKey.currentState;
    if (navigator?.canPop() != true) {
      replace();
      return;
    }
    var found = false;
    navigator!.popUntil((route) {
      if (route.settings.name == routeName) found = true;
      return found || route.isFirst;
    });
    if (!found) replace();
  }

  void _selectCategory(
    SettingsCategory category, {
    String? hostId,
    bool push = false,
  }) {
    _goToSettingsCategory(context, category, hostId: hostId, push: push);
  }

  Future<void> _selectDaemon(String hostId) async {
    await ref.read(hostRegistryControllerProvider.notifier).selectHost(hostId);
    if (!mounted) return;
    await DaemonCategoriesRoute(hostId: hostId).push<void>(context);
  }

  void _selectSidebarDaemon(String hostId) {
    final category = widget.category;
    if (category == null && widget.hostId != null) {
      DaemonCategoriesRoute(hostId: hostId).replace(context);
    } else if (category?.scope == SettingsCategoryScope.daemon) {
      _goToSettingsCategory(context, category!, hostId: hostId);
    }
    unawaited(
      ref.read(hostRegistryControllerProvider.notifier).selectHost(hostId),
    );
  }
}

/// Child content rendered by the stable typed Settings shell.
class SettingsRouteContent extends StatelessWidget {
  /// Creates a Settings child-route surface.
  const new({
    required this.kind,
    this.category,
    this.hostId,
    this.workspaceId,
    super.key,
  });

  /// Structural role of this child route.
  final SettingsRouteContentKind kind;

  /// Concrete category rendered by a category route.
  final SettingsCategory? category;

  /// Daemon selected by this route.
  final String? hostId;

  /// Workspace selected by this route.
  final String? workspaceId;

  @override
  Widget build(BuildContext context) {
    final scope = _SettingsRouteContentScope.of(context);
    final compact =
        TRAdaptiveLayoutScope.of(context).widthClass ==
        TRAdaptiveWidthClass.compact;
    return switch (kind) {
      SettingsRouteContentKind.home =>
        compact
            ? KeyedSubtree(
                key: const ValueKey<String>('settings-home-pane'),
                child: scope.home,
              )
            : scope.categoryContent(SettingsCategory.general),
      SettingsRouteContentKind.daemonCategories =>
        compact
            ? KeyedSubtree(
                key: const ValueKey<String>('settings-daemon-categories-pane'),
                child: scope.daemonCategories(hostId!),
              )
            : scope.categoryContent(SettingsCategory.provider, hostId: hostId),
      SettingsRouteContentKind.category => scope.categoryContent(
        category!,
        hostId: hostId,
        workspaceId: workspaceId,
      ),
    };
  }
}

/// Structural Settings route roles rendered inside [SettingsShellRoute].
enum SettingsRouteContentKind {
  /// Compact root navigation, or the default category on wider layouts.
  home,

  /// Compact daemon category navigation, or its default category when wider.
  daemonCategories,

  /// One concrete settings category.
  category,
}

class _SettingsRouteContentScope extends InheritedWidget {
  const new({
    required this.categoryContent,
    required this.home,
    required this.daemonCategories,
    required super.child,
  });

  final Widget Function(
    SettingsCategory category, {
    String? hostId,
    String? workspaceId,
  })
  categoryContent;
  final Widget home;
  final Widget Function(String hostId) daemonCategories;

  static _SettingsRouteContentScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SettingsRouteContentScope>()!;

  @override
  bool updateShouldNotify(_SettingsRouteContentScope oldWidget) =>
      categoryContent != oldWidget.categoryContent ||
      home != oldWidget.home ||
      daemonCategories != oldWidget.daemonCategories;
}

class _SettingsPanePair {
  const new({required this.primary, this.secondary});

  final Widget primary;
  final Widget? secondary;
}

class _SettingsSimplePane extends StatelessWidget {
  const new({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => SettingsDestinationScaffold(
    title: TRText.inherit(title),
    contentMaxWidth: TinestLayoutMetrics.settingsContentMaxWidth,
    child: child,
  );
}

class _MobileSettingsHome extends StatelessWidget {
  const new({
    required this.hosts,
    required this.onCategorySelected,
    required this.onDaemonSelected,
  });

  final List<HostRuntimeSnapshot> hosts;
  final void Function(SettingsCategory category, {String? hostId})
  onCategorySelected;
  final Future<void> Function(String hostId) onDaemonSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TRNavigationPane(
      children: <Widget>[
        TRNavigationSection(
          label: Text(l10n.settingsSectionApp),
          child: TRTreeNav<SettingsCategory>.controlled(
            value: null,
            semanticLabel: l10n.settingsSectionApp,
            itemSpacing: TRSpacing.extraSmall,
            items: <TRTreeNavItem<SettingsCategory>>[
              for (final category in _categoriesInScope(
                SettingsCategoryScope.app,
              ))
                TRTreeNavLeaf<SettingsCategory>(
                  key: ValueKey<String>(
                    'settings-category-row-${category.name}',
                  ),
                  value: category,
                  leading: Icon(_settingsCategoryIcon(category)),
                  label: TRText.inherit(_settingsCategoryLabel(l10n, category)),
                  trailing: Icon(TinestIcons.forwardFor(context)),
                ),
            ],
            onValueChange: (category) {
              if (category == null) return;
              onCategorySelected(category);
            },
          ),
        ),
        TRNavigationSection(
          label: Text(l10n.settingsSectionDaemon),
          child: hosts.isEmpty
              ? TRNavigationRow(
                  key: const ValueKey<String>('settings-daemon-empty-row'),
                  enabled: false,
                  leading: const Icon(TinestIcons.daemon),
                  label: TRText.inherit(l10n.settingsDaemonSelectEmpty),
                )
              : TRTreeNav<String>.controlled(
                  value: null,
                  semanticLabel: l10n.settingsSectionDaemon,
                  itemSpacing: TRSpacing.extraSmall,
                  items: <TRTreeNavItem<String>>[
                    for (final host in hosts)
                      TRTreeNavLeaf<String>(
                        key: ValueKey<String>('settings-daemon-row-${host.id}'),
                        value: host.id,
                        leading: Icon(hostStatusIcon(host.status)),
                        label: TRText.inherit(hostLabel(l10n, host)),
                        description: TRText.inherit(hostStatusText(l10n, host)),
                        trailing: Icon(TinestIcons.forwardFor(context)),
                      ),
                  ],
                  onValueChange: (hostId) {
                    if (hostId == null) return;
                    unawaited(onDaemonSelected(hostId));
                  },
                ),
        ),
      ],
    );
  }
}

class _MobileDaemonCategories extends StatelessWidget {
  const new({required this.host, required this.onCategorySelected});

  final HostRuntimeSnapshot? host;
  final void Function(SettingsCategory category, {String? hostId})
  onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final host = this.host;
    if (host == null) {
      return SettingsDestinationScaffold(
        title: TRText.inherit(l10n.settingsSectionDaemon),
        child: SettingsEmptyState(
          title: l10n.settingsDaemonSelectEmpty,
          icon: const Icon(TinestIcons.daemon),
        ),
      );
    }
    return SettingsDestinationScaffold(
      title: TRText.inherit(hostLabel(l10n, host)),
      child: TRNavigationPane(
        children: <Widget>[
          TRTreeNav<SettingsCategory>.controlled(
            value: null,
            semanticLabel: l10n.settingsSectionDaemon,
            itemSpacing: TRSpacing.extraSmall,
            items: <TRTreeNavItem<SettingsCategory>>[
              for (final category in _categoriesInScope(
                SettingsCategoryScope.daemon,
              ))
                TRTreeNavLeaf<SettingsCategory>(
                  key: ValueKey<String>(
                    'settings-category-row-${category.name}',
                  ),
                  value: category,
                  leading: Icon(_settingsCategoryIcon(category)),
                  label: TRText.inherit(_settingsCategoryLabel(l10n, category)),
                  trailing: Icon(TinestIcons.forwardFor(context)),
                ),
            ],
            onValueChange: (category) {
              if (category == null) return;
              onCategorySelected(category, hostId: host.id);
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsSidebar extends StatelessWidget {
  const new({
    required this.selected,
    required this.hosts,
    required this.hostId,
    required this.loading,
    required this.onDaemonSelected,
    required this.onCategorySelected,
  });

  final SettingsCategory selected;
  final List<HostRuntimeSnapshot> hosts;
  final String? hostId;
  final bool loading;
  final ValueChanged<String> onDaemonSelected;
  final void Function(SettingsCategory category, {String? hostId})
  onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TRNavigationPane(
      children: <Widget>[
        TRNavigationSection(
          label: Text(l10n.settingsSectionApp),
          child: _scopeNav(context, l10n, SettingsCategoryScope.app),
        ),
        TRNavigationSection(
          label: Text(l10n.settingsSectionDaemon),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: TRSpacing.extraSmall,
                ),
                child: _DaemonSelect(
                  hosts: hosts,
                  hostId: hostId,
                  loading: loading,
                  onValueChange: onDaemonSelected,
                ),
              ),
              _scopeNav(context, l10n, SettingsCategoryScope.daemon),
            ],
          ),
        ),
      ],
    );
  }

  /// One nav per section, since [TRTreeNav] has no non-selectable header item.
  ///
  /// Only the nav owning the selected category carries a value, so exactly
  /// one row stays highlighted across both sections.
  Widget _scopeNav(
    BuildContext context,
    AppLocalizations l10n,
    SettingsCategoryScope scope,
  ) {
    final storageId = 'settings-sidebar-tree-${scope.name}';
    return TRTreeNav<SettingsCategory>.controlled(
      key: ValueKey<String>(storageId),
      pageStorageId: storageId,
      semanticLabel: scope == SettingsCategoryScope.app
          ? l10n.settingsSectionApp
          : l10n.settingsSectionDaemon,
      value: selected.scope == scope ? selected : null,
      itemSpacing: TRSpacing.extraSmall,
      items: <TRTreeNavItem<SettingsCategory>>[
        for (final category in _categoriesInScope(scope))
          TRTreeNavLeaf<SettingsCategory>(
            key: ValueKey<String>('settings-category-row-${category.name}'),
            value: category,
            leading: Icon(_settingsCategoryIcon(category)),
            label: TRText.inherit(_settingsCategoryLabel(l10n, category)),
          ),
      ],
      onValueChange: (category) {
        if (category == null) return;
        onCategorySelected(
          category,
          hostId: category == SettingsCategory.connection ? hostId : null,
        );
      },
    );
  }
}

/// Picks the daemon that every host-scoped settings page edits.
///
/// Offline daemons stay listed so their settings can be reached as soon as
/// they reconnect, and so a saved selection does not silently jump elsewhere.
class _DaemonSelect extends StatelessWidget {
  const new({
    required this.hosts,
    required this.hostId,
    required this.loading,
    required this.onValueChange,
  });

  final List<HostRuntimeSnapshot> hosts;
  final String? hostId;
  final bool loading;
  final ValueChanged<String> onValueChange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (loading) {
      return Semantics(
        label: l10n.settingsLoading,
        container: true,
        child: const ExcludeSemantics(
          child: TRSkeleton(
            key: ValueKey<String>('settings-daemon-select-loading'),
            shape: TRSkeletonShape.rectangle,
          ),
        ),
      );
    }
    // Where a section heading already names this control the field label is
    // dropped, so the screen-reader name is carried here instead.
    // The pane is narrower than a daemon label, so the trigger takes the
    // full width and lets the label ellipsize instead of overflowing.
    final selected = hosts.where((host) => host.id == hostId).firstOrNull;
    return Semantics(
      label: l10n.settingsDaemonSelectLabel,
      container: true,
      child: LayoutBuilder(
        builder: (context, constraints) => TRSelect<String>.controlled(
          key: const ValueKey<String>('settings-daemon-select'),
          searchable: true,
          searchPlaceholder: l10n.selectSearchPlaceholder,
          noResultsText: l10n.selectNoResults,
          presentation: TinestSelectPresentation.resolve(context),
          value: hostId,
          // The sidebar is a flat list of borderless nav rows, so the trigger
          // takes its frame from the sidebar rather than drawing its own.
          appearance: TRFieldAppearance.ghost,
          placeholder: l10n.settingsDaemonSelectEmpty,
          helperText: selected == null ? null : hostStatusText(l10n, selected),
          leading: selected == null
              ? null
              : Icon(hostStatusIcon(selected.status)),
          enabled: hosts.isNotEmpty,
          width: constraints.maxWidth,
          items: hosts
              .map(
                (host) => TRSelectItem<String>(
                  key: ValueKey<String>('settings-daemon-option-${host.id}'),
                  value: host.id,
                  label: hostLabel(l10n, host),
                  description: hostStatusText(l10n, host),
                  leading: Icon(hostStatusIcon(host.status)),
                ),
              )
              .toList(growable: false),
          onValueChange: (value) {
            if (value == null) return;
            onValueChange(value);
          },
        ),
      ),
    );
  }
}

IconData _settingsCategoryIcon(SettingsCategory category) => switch (category) {
  SettingsCategory.general => TinestIcons.tune,
  SettingsCategory.project => TinestIcons.projects,
  SettingsCategory.agent => TinestIcons.agent,
  SettingsCategory.plugin => TinestIcons.extension,
  SettingsCategory.mcp => TinestIcons.extension,
  SettingsCategory.connection => TinestIcons.link,
  SettingsCategory.skill => TinestIcons.sparkle,
  SettingsCategory.provider => TinestIcons.network,
  SettingsCategory.model => TinestIcons.memory,
  SettingsCategory.permission => TinestIcons.permission,
  SettingsCategory.daemon => TinestIcons.daemon,
  SettingsCategory.advanced => TinestIcons.tool,
};

String _settingsCategoryLabel(
  AppLocalizations l10n,
  SettingsCategory category,
) => switch (category) {
  SettingsCategory.general => l10n.settingsCategoryGeneral,
  SettingsCategory.project => l10n.settingsCategoryProjects,
  SettingsCategory.agent => l10n.settingsCategoryAgent,
  SettingsCategory.plugin => l10n.settingsCategoryPlugin,
  SettingsCategory.mcp => l10n.settingsCategoryMcp,
  SettingsCategory.connection => l10n.settingsCategoryConnection,
  SettingsCategory.skill => l10n.settingsCategorySkill,
  SettingsCategory.provider => l10n.settingsCategoryProvider,
  SettingsCategory.model => l10n.settingsCategoryModel,
  SettingsCategory.permission => l10n.settingsCategoryPermission,
  SettingsCategory.daemon => l10n.settingsCategoryDaemon,
  SettingsCategory.advanced => l10n.settingsCategoryAdvanced,
};

/// Navigates to one settings category, keeping the persisted daemon choice.
///
/// Categories are siblings within the open settings task, so this replaces the
/// current page instead of pushing: the screen settings was opened from stays
/// beneath it however many categories the user visits.
void _goToSettingsCategory(
  BuildContext context,
  SettingsCategory category, {
  String? hostId,
  bool push = false,
}) {
  void navigate(VoidCallback replace, Future<void> Function() pushRoute) {
    if (push) {
      unawaited(pushRoute());
    } else {
      replace();
    }
  }

  switch (category) {
    case SettingsCategory.general:
      navigate(
        () => const GeneralSettingsRoute().replace(context),
        () => const GeneralSettingsRoute().push<void>(context),
      );
    case SettingsCategory.project:
      navigate(
        () => ProjectSettingsRoute(hostId: hostId).replace(context),
        () => ProjectSettingsRoute(hostId: hostId).push<void>(context),
      );
    case SettingsCategory.agent:
      navigate(
        () => AgentSettingsRoute(hostId: hostId).replace(context),
        () => AgentSettingsRoute(hostId: hostId).push<void>(context),
      );
    case SettingsCategory.plugin:
      navigate(
        () => PluginSettingsRoute(hostId: hostId).replace(context),
        () => PluginSettingsRoute(hostId: hostId).push<void>(context),
      );
    case SettingsCategory.mcp:
      navigate(
        () => McpSettingsRoute(hostId: hostId).replace(context),
        () => McpSettingsRoute(hostId: hostId).push<void>(context),
      );
    case SettingsCategory.connection:
      if (hostId != null) {
        navigate(
          () => DaemonConnectionsRoute(hostId: hostId).replace(context),
          () => DaemonConnectionsRoute(hostId: hostId).push<void>(context),
        );
      }
    case SettingsCategory.skill:
      navigate(
        () => SkillSettingsRoute(hostId: hostId).replace(context),
        () => SkillSettingsRoute(hostId: hostId).push<void>(context),
      );
    case SettingsCategory.provider:
      navigate(
        () => ProviderSettingsRoute(hostId: hostId).replace(context),
        () => ProviderSettingsRoute(hostId: hostId).push<void>(context),
      );
    case SettingsCategory.model:
      navigate(
        () => ModelSettingsRoute(hostId: hostId).replace(context),
        () => ModelSettingsRoute(hostId: hostId).push<void>(context),
      );
    case SettingsCategory.permission:
      navigate(
        () => PermissionSettingsRoute(hostId: hostId).replace(context),
        () => PermissionSettingsRoute(hostId: hostId).push<void>(context),
      );
    case SettingsCategory.daemon:
      navigate(
        () => const DaemonSettingsRoute().replace(context),
        () => const DaemonSettingsRoute().push<void>(context),
      );
    case SettingsCategory.advanced:
      navigate(
        () => const AdvancedSettingsRoute().replace(context),
        () => const AdvancedSettingsRoute().push<void>(context),
      );
  }
}

/// Guards a host-scoped settings page behind a usable daemon connection.
///
/// The daemon itself is chosen in the sidebar, so this only explains why a
/// page cannot render yet.
class _HostScopedDetail extends StatelessWidget {
  const new({
    required this.host,
    required this.loading,
    required this.loadingChild,
    required this.builder,
  });

  final HostRuntimeSnapshot? host;
  final bool loading;
  final Widget loadingChild;
  final Widget Function(String hostId) builder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (loading) return loadingChild;
    final host = this.host;
    if (host == null) {
      return SettingsEmptyState(
        title: l10n.settingsRequiresOnlineDaemon,
        icon: const Icon(TinestIcons.daemon),
      );
    }
    if (!host.connected) {
      return SettingsEmptyState(
        key: const ValueKey<String>('settings-daemon-offline'),
        title: l10n.settingsDaemonOffline(hostLabel(l10n, host)),
        description: hostStatusText(l10n, host),
        icon: Icon(hostStatusIcon(host.status)),
      );
    }
    return builder(host.id);
  }
}
