import 'dart:async';

import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/features/plugins/application/plugin_settings_controller.dart';
import 'package:app/src/features/plugins/domain/plugin_revision_label.dart';
import 'package:app/src/features/plugins/presentation/agent_plugin_ui_slot.dart';
import 'package:app/src/shared/presentation/settings_layout.dart';
import 'package:app/src/shared/presentation/tinest_icons.dart';
import 'package:app/src/shared/presentation/tinest_layout_metrics.dart';
import 'package:app/src/shared/presentation/tinest_select_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// Installed built-in and app-data plugin management for one daemon.
class PluginSettingsPage extends ConsumerWidget {
  /// Creates the plugin settings page.
  const new({
    required this.hostId,
    required this.paneController,
    required this.slot,
    super.key,
  });

  /// App-local daemon profile identifier.
  final String hostId;

  /// Selection shared by the collection and detail scaffold slots.
  final PluginSettingsPaneController paneController;

  /// Which scaffold slot this widget supplies.
  final SettingsPaneSlot slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final widthClass = settingsAdaptiveWidthClassOf(context);
    final showsSplit =
        widthClass == TRAdaptiveWidthClass.large ||
        widthClass == TRAdaptiveWidthClass.extraLarge;
    final state = ref.watch(pluginSettingsControllerProvider(hostId));
    return ListenableBuilder(
      listenable: paneController,
      builder: (context, _) => SettingsAsyncContent<PluginSettingsState>(
        state: state,
        loading: settingsPaneSkeleton(
          slot,
          semanticLabel: AppLocalizations.of(context).settingsLoading,
        ),
        error: (error, _) => slot == SettingsPaneSlot.collection
            ? SettingsCollectionErrorState(
                title: AppLocalizations.of(context).pluginSettingsHeading,
                error: error,
                onRetry: () =>
                    ref.invalidate(pluginSettingsControllerProvider(hostId)),
              )
            : SettingsEmptyState(
                title: AppLocalizations.of(context).pluginSettingsSelect,
                icon: const Icon(TinestIcons.extension),
              ),
        data: (value) =>
            _buildPane(context, ref, value, showsSplit: showsSplit),
      ),
    );
  }

  Widget _buildPane(
    BuildContext context,
    WidgetRef ref,
    PluginSettingsState state, {
    required bool showsSplit,
  }) {
    final selected = state.plugins
        .where((plugin) => plugin.id == paneController.selectedId)
        .firstOrNull;
    if (slot == SettingsPaneSlot.collection &&
        !paneController.creating &&
        showsSplit &&
        paneController.canAutoSelect &&
        selected == null &&
        state.plugins.isNotEmpty) {
      _scheduleInitialSelection(state.plugins.first.id);
    } else if (!paneController.creating &&
        paneController.hasDetail &&
        selected == null) {
      _scheduleCollection();
    }
    if (slot == SettingsPaneSlot.collection) {
      return KeyedSubtree(
        key: const ValueKey<String>('plugin-settings-page'),
        child: _PluginList(
          plugins: state.plugins,
          selectedId: paneController.selectedId,
          onSelected: paneController.select,
          onCreate: paneController.create,
        ),
      );
    }
    if (paneController.creating) {
      return _CreatePluginPane(
        existingIds: state.plugins
            .map((plugin) => plugin.id.toLowerCase())
            .toSet(),
        onCancel: paneController.showCollection,
        onCreate: (id, name) => ref
            .read(pluginSettingsControllerProvider(hostId).notifier)
            .scaffold(id, name),
        onCreated: (plugin) => paneController.select(plugin.id),
      );
    }
    return selected == null
        ? SettingsEmptyState(
            title: AppLocalizations.of(context).pluginSettingsSelect,
            icon: const Icon(TinestIcons.extension),
          )
        : _PluginDetailPane(
            key: ValueKey<String>(
              '${selected.id}-${selected.revision?.contentHash ?? 'none'}',
            ),
            hostId: hostId,
            plugin: selected,
            authoring: state.authoringEnvironments[selected.id],
            agents: state.referencingAgents(selected.id),
            existingIds: state.plugins
                .map((plugin) => plugin.id.toLowerCase())
                .toSet(),
            onForked: (plugin) => paneController.select(plugin.id),
          );
  }

  void _scheduleInitialSelection(String pluginId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      paneController.selectInitial(pluginId);
    });
  }

  void _scheduleCollection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      paneController.showCollection();
    });
  }
}

/// Owns Plugin collection selection independently from either rendered slot.
class PluginSettingsPaneController extends SettingsPaneCoordinatorBase {
  String? _selectedId;
  bool _creating = false;

  /// Selected plugin ID, when an installed plugin is active.
  String? get selectedId => _selectedId;

  /// Whether the scaffold destination is active.
  bool get creating => _creating;

  /// Sibling destinations, so the stack is never deeper than one entry.
  @override
  List<Object> get detailStack => _creating
      ? const <Object>['plugin-create']
      : _selectedId == null
      ? const <Object>[]
      : <Object>['plugin-$_selectedId'];

  /// Shows the first plugin on initial desktop entry.
  void selectInitial(String id) {
    if (!consumeInitialSelection()) return;
    _selectedId = id;
    notifyListeners();
  }

  /// Shows an installed plugin.
  void select(String id) {
    consumeExplicitNavigation();
    if (!_creating && _selectedId == id) return;
    _creating = false;
    _selectedId = id;
    notifyListeners();
  }

  /// Shows the plugin scaffold destination.
  void create() {
    consumeExplicitNavigation();
    if (_creating) return;
    _creating = true;
    _selectedId = null;
    notifyListeners();
  }

  @override
  void showCollection() {
    consumeExplicitNavigation();
    if (!hasDetail) return;
    _creating = false;
    _selectedId = null;
    notifyListeners();
  }

  @override
  void reset() {
    final hadDetail = hasDetail;
    resetInitialSelection();
    _creating = false;
    _selectedId = null;
    if (hadDetail) notifyListeners();
  }
}

class _PluginList extends StatelessWidget {
  const new({
    required this.plugins,
    required this.selectedId,
    required this.onSelected,
    required this.onCreate,
  });

  final List<PluginDescriptorDto> plugins;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsDestinationScaffold(
      title: TRText.inherit(l10n.pluginSettingsHeading),
      actions: <TRIconButton>[
        TRIconButton(
          key: const ValueKey<String>('plugin-add-button'),
          appearance: TRAppearance.ghost,
          label: l10n.pluginSettingsAdd,
          onPressed: onCreate,
          icon: const Icon(TinestIcons.add),
        ),
      ],
      child: plugins.isEmpty
          ? SettingsEmptyState(
              title: l10n.pluginSettingsEmpty,
              icon: const Icon(TinestIcons.extension),
            )
          : SettingsCollectionList(
              children: <Widget>[
                TRTreeNav<String>.controlled(
                  value: selectedId,
                  itemSpacing: TRSpacing.extraSmall,
                  onValueChange: (pluginId) {
                    if (pluginId != null) onSelected(pluginId);
                  },
                  items: <TRTreeNavItem<String>>[
                    for (final plugin in plugins)
                      TRTreeNavLeaf<String>(
                        key: ValueKey<String>('plugin-row-${plugin.id}'),
                        value: plugin.id,
                        showDisclosureIndicator: true,
                        leading: const Icon(TinestIcons.extension),
                        label: TRText.inherit(plugin.name),
                        description: TRText.inherit(plugin.id),
                        trailing:
                            plugin.diagnostics.any(
                              (diagnostic) =>
                                  diagnostic.severity ==
                                  PluginDiagnosticSeverity.error,
                            )
                            ? const Icon(TinestIcons.warning)
                            : TRBadge(
                                variant: plugin.source == PluginSource.builtIn
                                    ? TRStatusVariant.neutral
                                    : TRStatusVariant.info,
                                child: TRText.inherit(
                                  _pluginSourceLabel(l10n, plugin.source),
                                ),
                              ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _PluginDetailPane extends ConsumerStatefulWidget {
  const new({
    required this.hostId,
    required this.plugin,
    required this.authoring,
    required this.agents,
    required this.existingIds,
    required this.onForked,
    super.key,
  });

  final String hostId;
  final PluginDescriptorDto plugin;
  final PluginAuthoringEnvironmentDto? authoring;
  final List<AgentDefinitionDto> agents;
  final Set<String> existingIds;
  final ValueChanged<PluginDescriptorDto> onForked;

  @override
  ConsumerState<_PluginDetailPane> createState() => _PluginDetailPaneState();
}

class _PluginDetailPaneState extends ConsumerState<_PluginDetailPane> {
  String? _agentId;
  String? _busyAction;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _agentId = widget.agents.firstOrNull?.id;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plugin = widget.plugin;
    final authoring = widget.authoring;
    final uiContributions = plugin.contributions
        .where(
          (contribution) =>
              contribution.kind == PluginContributionKind.ui &&
              _contributionSlots(contribution)
                  .contains(PluginUiSlot.agentSettings.name),
        )
        .toList(growable: false);
    return SettingsDestinationScaffold(
      title: TRText.inherit(plugin.name),
      contentMaxWidth: TinestLayoutMetrics.settingsContentMaxWidth,
      actions: <TRIconButton>[
        TRIconButton(
          key: const ValueKey<String>('plugin-open-path-button'),
          appearance: TRAppearance.ghost,
          label: l10n.pluginSettingsOpenPath,
          onPressed: plugin.source != PluginSource.user || _busyAction != null
              ? null
              : () => unawaited(_openPath()),
          icon: const Icon(TinestIcons.folderOpen),
        ),
        TRIconButton(
          key: const ValueKey<String>('plugin-fork-button'),
          appearance: TRAppearance.ghost,
          label: l10n.pluginSettingsFork,
          onPressed: plugin.revision == null || _busyAction != null
              ? null
              : () => unawaited(_fork()),
          icon: const Icon(TinestIcons.copy),
        ),
      ],
      child: SettingsScaffold(
        children: <Widget>[
          SettingsSection(
            title: l10n.pluginSettingsSource,
            // Validate and Reload act on the plugin this section describes.
            // They read as words rather than glyphs, so they sit with the
            // source they operate on instead of widening the page header.
            action: Wrap(
              spacing: TRSpacing.small,
              runSpacing: TRSpacing.small,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                TRButton(
                  key: const ValueKey<String>('plugin-validate-button'),
                  appearance: TRAppearance.outline,
                  loading: _busyAction == 'validate',
                  loadingLabel: l10n.pluginSettingsValidate,
                  onPressed: _busyAction == null
                      ? () => unawaited(_validate())
                      : null,
                  child: TRText.inherit(l10n.pluginSettingsValidate),
                ),
                TRButton(
                  key: const ValueKey<String>('plugin-reload-button'),
                  loading: _busyAction == 'reload',
                  loadingLabel: l10n.pluginSettingsReload,
                  onPressed: _busyAction == null && _agentId != null
                      ? () => unawaited(_reload())
                      : null,
                  child: TRText.inherit(l10n.pluginSettingsReload),
                ),
              ],
            ),
            banner: _error == null
                ? null
                : TRAlert(
                    variant: TRStatusVariant.danger,
                    title: TRText.inherit(l10n.pluginSettingsActionFailed),
                    description: TRText.inherit('$_error'),
                  ),
            children: <Widget>[
              SettingsRow(
                title: TRText.inherit(l10n.pluginSettingsSource),
                control: TRBadge(
                  variant: plugin.source == PluginSource.builtIn
                      ? TRStatusVariant.neutral
                      : TRStatusVariant.info,
                  child: TRText.inherit(
                    _pluginSourceLabel(l10n, plugin.source),
                  ),
                ),
              ),
              SettingsRow(
                title: TRText.inherit(l10n.pluginSettingsSourcePath),
                description: TRText.inherit(plugin.sourcePath),
              ),
              SettingsRow(
                title: TRText.inherit(l10n.pluginSettingsApi),
                control: TRText.inherit(
                  l10n.pluginSettingsApiValue(plugin.apiMajor),
                ),
              ),
              SettingsRow(
                title: TRText.inherit(l10n.pluginSettingsRevision),
                description: plugin.isStale
                    ? TRText.inherit(l10n.pluginSettingsStale)
                    : null,
                // Even shortened, a monospace digest and its label stop
                // sharing a line once the reader scales the text up.
                controlLayout: SettingsControlLayout.stacked,
                control: TRCode(switch (plugin.revision?.contentHash) {
                  final hash? => pluginRevisionLabel(hash),
                  null => l10n.pluginSettingsRevisionMissing,
                }),
              ),
            ],
          ),
          SettingsSection.form(
            title: l10n.pluginSettingsCapabilities,
            children: <Widget>[
              if (plugin.requestedCapabilities.isEmpty)
                TRText(
                  l10n.pluginSettingsCapabilitiesNone,
                  color: TRTextColor.muted,
                )
              else
                Wrap(
                  spacing: TRSpacing.small,
                  runSpacing: TRSpacing.small,
                  children: plugin.requestedCapabilities
                      .map(
                        (capability) =>
                            TRBadge(child: TRText.inherit(capability)),
                      )
                      .toList(growable: false),
                ),
            ],
          ),
          if (plugin.source == PluginSource.user && authoring != null)
            SettingsSection(
              title: l10n.pluginSettingsAuthoring,
              children: <Widget>[
                SettingsRow(
                  title: TRText.inherit(l10n.pluginSettingsAuthoringStatus),
                  control: TRBadge(
                    variant: authoring.synchronized
                        ? TRStatusVariant.success
                        : TRStatusVariant.warning,
                    child: TRText.inherit(
                      authoring.synchronized
                          ? l10n.pluginSettingsAuthoringSynchronized
                          : l10n.pluginSettingsAuthoringNeedsSync,
                    ),
                  ),
                ),
                SettingsRow(
                  title: TRText.inherit(l10n.pluginSettingsSdkAbi),
                  controlLayout: SettingsControlLayout.stacked,
                  control: TRCode(pluginRevisionLabel(authoring.sdkAbiHash)),
                ),
                SettingsRow(
                  title: TRText.inherit(l10n.pluginSettingsLuaRuntime),
                  control: TRText.inherit(authoring.luaRuntimeVersion),
                ),
                SettingsRow(
                  title: TRText.inherit(l10n.pluginSettingsLuaLs),
                  description: TRText.inherit(authoring.sdkLibraryPath),
                  control: TRText.inherit(authoring.luaLanguageServerVersion),
                ),
                SettingsRow(
                  title: TRText.inherit(l10n.pluginSettingsLuaConfig),
                  description: TRText.inherit(authoring.configurationPath),
                  control: TRButton(
                    key: const ValueKey<String>('plugin-sdk-sync-button'),
                    appearance: TRAppearance.outline,
                    loading: _busyAction == 'sdkSync',
                    loadingLabel: l10n.pluginSettingsSdkSync,
                    onPressed: _busyAction == null
                        ? () => unawaited(_syncAuthoring())
                        : null,
                    child: TRText.inherit(l10n.pluginSettingsSdkSync),
                  ),
                ),
                for (final diagnostic in authoring.diagnostics)
                  TRAlert(
                    variant: _diagnosticVariant(diagnostic.severity),
                    title: TRText.inherit(diagnostic.code),
                    description: TRText.inherit(diagnostic.message),
                  ),
              ],
            ),
          SettingsSection.form(
            title: l10n.pluginSettingsAgents,
            children: <Widget>[
              if (widget.agents.isEmpty)
                TRAlert(
                  variant: TRStatusVariant.warning,
                  title: TRText.inherit(l10n.pluginSettingsAgentsNone),
                  description: TRText.inherit(
                    l10n.pluginSettingsReloadNeedsAgent,
                  ),
                )
              else ...<Widget>[
                Wrap(
                  spacing: TRSpacing.small,
                  runSpacing: TRSpacing.small,
                  children: widget.agents
                      .map(
                        (agent) => TRBadge(
                          variant: TRStatusVariant.info,
                          child: TRText.inherit(agent.name),
                        ),
                      )
                      .toList(growable: false),
                ),
                TRSelect<String>.controlled(
                  searchable: true,
                  presentation: TinestSelectPresentation.resolve(context),
                  key: const ValueKey<String>('plugin-reload-agent'),
                  label: l10n.pluginSettingsReloadAgent,
                  value: _agentId,
                  items: widget.agents
                      .map(
                        (agent) => TRSelectItem<String>(
                          value: agent.id,
                          label: agent.name,
                        ),
                      )
                      .toList(growable: false),
                  onValueChange: _busyAction == null
                      ? (value) => setState(() => _agentId = value)
                      : null,
                ),
              ],
            ],
          ),
          SettingsSection(
            title: l10n.pluginSettingsContributions,
            children: plugin.contributions
                .map(
                  (contribution) => SettingsRow(
                    title: TRText.inherit(contribution.id),
                    description: contribution.requiredCapabilities.isEmpty
                        ? null
                        : TRText.inherit(
                            contribution.requiredCapabilities.join(', '),
                          ),
                    control: TRBadge(
                      child: TRText.inherit(
                        _contributionKindLabel(l10n, contribution.kind),
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          SettingsSection.form(
            title: l10n.pluginSettingsDiagnostics,
            children: <Widget>[
              if (plugin.diagnostics.isEmpty)
                TRText(
                  l10n.pluginSettingsDiagnosticsNone,
                  color: TRTextColor.muted,
                )
              else
                for (final diagnostic in plugin.diagnostics)
                  TRAlert(
                    variant: _diagnosticVariant(diagnostic.severity),
                    title: TRText.inherit(diagnostic.code),
                    description: TRText.inherit(diagnostic.message),
                  ),
            ],
          ),
          if (_agentId case final agentId?)
            for (final contribution in uiContributions)
              SettingsSection.form(
                title: '${l10n.pluginSettingsUi} · ${contribution.id}',
                children: <Widget>[
                  PluginUiContributionSurface(
                    hostId: widget.hostId,
                    agentId: agentId,
                    plugin: plugin,
                    contribution: contribution,
                    slot: PluginUiSlot.agentSettings,
                  ),
                ],
              ),
        ],
      ),
    );
  }

  Future<void> _validate() => _run('validate', () {
    return ref
        .read(pluginSettingsControllerProvider(widget.hostId).notifier)
        .validate(widget.plugin.id);
  });

  Future<void> _reload() => _run('reload', () {
    return ref
        .read(pluginSettingsControllerProvider(widget.hostId).notifier)
        .reload(widget.plugin.id, _agentId!);
  });

  Future<void> _syncAuthoring() => _run('sdkSync', () {
    return ref
        .read(pluginSettingsControllerProvider(widget.hostId).notifier)
        .syncAuthoring(widget.plugin.id);
  });

  Future<void> _openPath() => _run('openPath', () async {
    final opened = await launchUrl(
      Uri.file(widget.plugin.sourcePath),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) throw StateError('Could not open ${widget.plugin.sourcePath}');
    return opened;
  });

  Future<void> _fork() async {
    final plugin = await showTRDialog<PluginDescriptorDto>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ForkPluginDialog(
        source: widget.plugin,
        existingIds: widget.existingIds,
        onFork: ({required id, required name}) => ref
            .read(pluginSettingsControllerProvider(widget.hostId).notifier)
            .fork(sourceId: widget.plugin.id, id: id, name: name),
      ),
    );
    if (plugin != null && mounted) widget.onForked(plugin);
  }

  Future<void> _run(String action, Future<Object?> Function() run) async {
    setState(() {
      _busyAction = action;
      _error = null;
    });
    try {
      await run();
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }
}

class _ForkPluginDialog extends StatefulWidget {
  const new({
    required this.source,
    required this.existingIds,
    required this.onFork,
  });

  final PluginDescriptorDto source;
  final Set<String> existingIds;
  final Future<PluginDescriptorDto> Function({
    required String id,
    required String name,
  })
  onFork;

  @override
  State<_ForkPluginDialog> createState() => _ForkPluginDialogState();
}

class _ForkPluginDialogState extends State<_ForkPluginDialog> {
  final TextEditingController _id = TextEditingController();
  final TextEditingController _name = TextEditingController();
  bool _saving = false;
  Object? _error;

  bool get _validId {
    final id = _id.text.trim();
    return RegExp(
          r'^[a-z][a-z0-9]*(?:-[a-z0-9]+)*(?:\.[a-z][a-z0-9]*(?:-[a-z0-9]+)*)+$',
        ).hasMatch(id) &&
        !id.startsWith('tinest.') &&
        !widget.existingIds.contains(id.toLowerCase());
  }

  bool get _valid => _validId && _name.text.trim().isNotEmpty;

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TRDialog(
      semanticLabel: l10n.pluginSettingsForkTitle(widget.source.name),
      title: TRText.inherit(l10n.pluginSettingsForkTitle(widget.source.name)),
      description: TRText.inherit(l10n.pluginSettingsForkDescription),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: TRSpacing.medium,
        children: <Widget>[
          if (_error != null)
            TRAlert(
              variant: TRStatusVariant.danger,
              title: TRText.inherit(l10n.pluginSettingsActionFailed),
              description: TRText.inherit('$_error'),
            ),
          TRTextField(
            key: const ValueKey<String>('plugin-fork-id'),
            controller: _id,
            autofocus: true,
            enabled: !_saving,
            label: l10n.pluginSettingsId,
            errorText: _id.text.isEmpty || _validId
                ? null
                : widget.existingIds.contains(_id.text.trim().toLowerCase())
                ? l10n.pluginSettingsIdTaken
                : l10n.pluginSettingsIdInvalid,
            onChanged: (_) => setState(() => _error = null),
          ),
          TRTextField(
            key: const ValueKey<String>('plugin-fork-name'),
            controller: _name,
            enabled: !_saving,
            label: l10n.pluginSettingsName,
            onChanged: (_) => setState(() => _error = null),
          ),
        ],
      ),
      actions: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: TRSpacing.small,
        children: <Widget>[
          TRButton(
            appearance: TRAppearance.ghost,
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: TRText.inherit(l10n.commonCancel),
          ),
          TRButton(
            key: const ValueKey<String>('plugin-fork-confirm'),
            intent: TRIntent.primary,
            loading: _saving,
            loadingLabel: l10n.pluginSettingsFork,
            onPressed: !_saving && _valid ? _submit : null,
            child: TRText.inherit(l10n.pluginSettingsFork),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final plugin = await widget.onFork(
        id: _id.text.trim(),
        name: _name.text.trim(),
      );
      if (mounted) Navigator.pop(context, plugin);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error;
        });
      }
    }
  }
}

class _CreatePluginPane extends StatefulWidget {
  const new({
    required this.existingIds,
    required this.onCancel,
    required this.onCreate,
    required this.onCreated,
  });

  final Set<String> existingIds;
  final VoidCallback onCancel;
  final Future<PluginDescriptorDto> Function(String id, String name) onCreate;
  final ValueChanged<PluginDescriptorDto> onCreated;

  @override
  State<_CreatePluginPane> createState() => _CreatePluginPaneState();
}

class _CreatePluginPaneState extends State<_CreatePluginPane> {
  final TextEditingController _id = TextEditingController();
  final TextEditingController _name = TextEditingController();
  bool _saving = false;
  Object? _error;

  bool get _validId {
    final id = _id.text.trim();
    return RegExp(r'^[a-z][a-z0-9]*(?:\.[a-z][a-z0-9]*)+$').hasMatch(id) &&
        !id.startsWith('tinest.') &&
        !widget.existingIds.contains(id.toLowerCase());
  }

  bool get _valid => _validId && _name.text.trim().isNotEmpty;

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsDestinationScaffold(
      title: TRText.inherit(l10n.pluginSettingsAddTitle),
      contentMaxWidth: TinestLayoutMetrics.settingsContentMaxWidth,
      formActions: <Widget>[
        TRButton(
          appearance: TRAppearance.ghost,
          onPressed: _saving ? null : widget.onCancel,
          child: TRText.inherit(l10n.commonCancel),
        ),
        TRButton(
          key: const ValueKey<String>('plugin-create-submit'),
          intent: TRIntent.primary,
          onPressed: !_saving && _valid ? _submit : null,
          child: TRText.inherit(
            _saving ? l10n.commonCreating : l10n.commonCreate,
          ),
        ),
      ],
      child: SettingsScaffold(
        children: <Widget>[
          SettingsSection.form(
            title: l10n.pluginSettingsAddTitle,
            banner: _error == null
                ? null
                : TRAlert(
                    variant: TRStatusVariant.danger,
                    title: TRText.inherit(l10n.pluginSettingsActionFailed),
                    description: TRText.inherit('$_error'),
                  ),
            children: <Widget>[
              TRTextField(
                controller: _id,
                autofocus: true,
                enabled: !_saving,
                label: l10n.pluginSettingsId,
                placeholder: 'example.tools',
                errorText: _id.text.isEmpty || _validId
                    ? null
                    : widget.existingIds.contains(_id.text.toLowerCase())
                    ? l10n.pluginSettingsIdTaken
                    : l10n.pluginSettingsIdInvalid,
                onChanged: (_) => setState(() => _error = null),
              ),
              TRTextField(
                controller: _name,
                enabled: !_saving,
                label: l10n.pluginSettingsName,
                onChanged: (_) => setState(() => _error = null),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final plugin = await widget.onCreate(_id.text.trim(), _name.text.trim());
      if (mounted) widget.onCreated(plugin);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error;
        });
      }
    }
  }
}

String _pluginSourceLabel(AppLocalizations l10n, PluginSource source) =>
    switch (source) {
      PluginSource.builtIn => l10n.pluginSettingsSourceBuiltIn,
      PluginSource.user => l10n.pluginSettingsSourceUser,
    };

String _contributionKindLabel(
  AppLocalizations l10n,
  PluginContributionKind kind,
) => switch (kind) {
  PluginContributionKind.driver => l10n.pluginContributionDriver,
  PluginContributionKind.extension => l10n.pluginContributionExtension,
  PluginContributionKind.tool => l10n.pluginContributionTool,
  PluginContributionKind.sessionControl =>
    l10n.pluginContributionSessionControl,
  PluginContributionKind.ui => l10n.pluginContributionUi,
};

TRStatusVariant _diagnosticVariant(PluginDiagnosticSeverity severity) =>
    switch (severity) {
      PluginDiagnosticSeverity.info => TRStatusVariant.info,
      PluginDiagnosticSeverity.warning => TRStatusVariant.warning,
      PluginDiagnosticSeverity.error => TRStatusVariant.danger,
    };

Set<String> _contributionSlots(PluginContributionDto contribution) {
  final value = contribution.metadata['slots'];
  return value is List<Object?>
      ? value.whereType<String>().toSet()
      : <String>{};
}
