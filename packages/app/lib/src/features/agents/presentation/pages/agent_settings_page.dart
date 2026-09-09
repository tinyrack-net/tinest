import 'dart:async';
import 'dart:convert';

import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/features/agents/application/agent_definitions_controller.dart';
import 'package:app/src/features/agents/presentation/tool_groups.dart';
import 'package:app/src/features/plugins/application/plugin_settings_controller.dart';
import 'package:app/src/features/providers/application/model_picker_options.dart';
import 'package:app/src/features/providers/application/provider_settings_controller.dart';
import 'package:app/src/features/providers/application/session_model_options.dart';
import 'package:app/src/shared/presentation/blocked_control.dart';
import 'package:app/src/shared/presentation/model_picker.dart';
import 'package:app/src/shared/presentation/settings_layout.dart';
import 'package:app/src/shared/presentation/tinest_icons.dart';
import 'package:app/src/shared/presentation/tinest_layout_metrics.dart';
import 'package:app/src/shared/presentation/tinest_select_presentation.dart';
import 'package:app/src/shared/presentation/tinest_selection_row.dart';
import 'package:app/src/shared/presentation/toast_messenger.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Markdown-backed agent manager for one connected daemon.
class AgentSettingsPage extends ConsumerWidget {
  /// Creates an agent settings page.
  const new({
    required this.hostId,
    required this.paneController,
    required this.slot,
    super.key,
  });

  /// App-local daemon profile identifier.
  final String hostId;

  /// Selection shared by the collection and detail scaffold slots.
  final AgentSettingsPaneController paneController;

  /// Which scaffold slot this widget supplies.
  final SettingsPaneSlot slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final widthClass = settingsAdaptiveWidthClassOf(context);
    final showsSplit =
        widthClass == TRAdaptiveWidthClass.large ||
        widthClass == TRAdaptiveWidthClass.extraLarge;
    final state = ref.watch(agentDefinitionsControllerProvider(hostId));
    return ListenableBuilder(
      listenable: paneController,
      builder: (context, _) => SettingsAsyncContent<AgentDefinitionsState>(
        state: state,
        loading: settingsPaneSkeleton(
          slot,
          semanticLabel: AppLocalizations.of(context).settingsLoading,
        ),
        error: (error, _) => slot == SettingsPaneSlot.collection
            ? SettingsCollectionErrorState(
                title: AppLocalizations.of(context).agentSettingsHeading,
                error: error,
                onRetry: () =>
                    ref.invalidate(agentDefinitionsControllerProvider(hostId)),
              )
            : SettingsEmptyState(
                title: AppLocalizations.of(context).agentSettingsSelectAgent,
                icon: const Icon(TinestIcons.agent),
              ),
        data: (value) =>
            _buildPane(context, ref, value, showsSplit: showsSplit),
      ),
    );
  }

  Widget _buildPane(
    BuildContext context,
    WidgetRef ref,
    AgentDefinitionsState value, {
    required bool showsSplit,
  }) {
    final selected = value.definitions
        .where((definition) => definition.id == paneController.selectedId)
        .firstOrNull;
    if (slot == SettingsPaneSlot.collection &&
        !paneController.creating &&
        showsSplit &&
        paneController.canAutoSelect &&
        selected == null &&
        value.definitions.isNotEmpty) {
      _scheduleInitialSelection(value.definitions.first.id);
    } else if (!paneController.creating &&
        paneController.hasDetail &&
        selected == null) {
      _scheduleCollection();
    }
    if (slot == SettingsPaneSlot.collection) {
      return _AgentDefinitionList(
        state: value,
        selectedId: paneController.selectedId,
        onSelected: paneController.select,
        onCreate: paneController.create,
      );
    }
    if (paneController.creating) {
      return _CreateAgentPane(
        existingIds: value.definitions
            .map((definition) => definition.id)
            .toSet(),
        onCancel: paneController.showCollection,
        onCreate: (input) {
          final template = value.definitions
              .where((definition) => definition.id == 'tinest')
              .first;
          final definition = template.copyWith(
            version: 5,
            id: input.id,
            name: input.name,
            description: '',
            mode: input.mode,
            driverId: template.driverId,
            extensionIds: template.extensionIds,
            pluginSettings: template.pluginSettings,
            callableAgentIds: const <String>[],
            prompt: '',
            contentHash: '',
            sourcePath: '',
            isBuiltIn: false,
            isArchived: false,
            isStale: false,
            diagnostics: const <AgentDefinitionDiagnosticDto>[],
          );
          return ref
              .read(agentDefinitionsControllerProvider(hostId).notifier)
              .create(input.id, definition);
        },
        onCreated: (created) => paneController.select(created.id),
      );
    }
    return selected == null
        ? SettingsEmptyState(
            title: AppLocalizations.of(context).agentSettingsSelectAgent,
            icon: const Icon(TinestIcons.agent),
          )
        : _AgentEditor(
            key: ValueKey<String>(selected.contentHash),
            hostId: hostId,
            state: value,
            definition: selected,
            onArchived: paneController.showCollection,
          );
  }

  void _scheduleInitialSelection(String agentId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      paneController.selectInitial(agentId);
    });
  }

  void _scheduleCollection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      paneController.showCollection();
    });
  }
}

/// Owns Agent collection selection independently from either rendered slot.
class AgentSettingsPaneController extends SettingsPaneCoordinatorBase {
  String? _selectedId;
  bool _creating = false;

  /// Selected Agent ID, when an existing definition is active.
  String? get selectedId => _selectedId;

  /// Whether the create destination is active.
  bool get creating => _creating;

  /// Sibling destinations, so the stack is never deeper than one entry.
  @override
  List<Object> get detailStack => _creating
      ? const <Object>[(_AgentPaneDestination.create, null)]
      : _selectedId == null
      ? const <Object>[]
      : <Object>[(_AgentPaneDestination.existing, _selectedId)];

  /// Shows the first Agent on initial desktop entry.
  void selectInitial(String id) {
    if (!consumeInitialSelection()) return;
    _selectedId = id;
    notifyListeners();
  }

  /// Shows an existing Agent definition.
  void select(String id) {
    consumeExplicitNavigation();
    if (!_creating && _selectedId == id) return;
    _creating = false;
    _selectedId = id;
    notifyListeners();
  }

  /// Shows the create Agent destination.
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

enum _AgentPaneDestination { create, existing }

class _AgentDefinitionList extends StatelessWidget {
  const new({
    required this.state,
    required this.selectedId,
    required this.onSelected,
    required this.onCreate,
  });

  final AgentDefinitionsState state;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsDestinationScaffold(
      title: TRText.inherit(l10n.agentSettingsHeading),
      actions: <TRIconButton>[
        TRIconButton(
          key: const ValueKey('agent-add-button'),
          appearance: TRAppearance.ghost,
          label: l10n.agentSettingsAdd,
          onPressed: onCreate,
          icon: const Icon(TinestIcons.add),
        ),
      ],
      child: state.definitions.isEmpty
          ? SettingsEmptyState(
              title: l10n.agentSettingsEmpty,
              icon: const Icon(TinestIcons.agent),
            )
          : SettingsCollectionList(
              children: <Widget>[
                TRTreeNav<String>.controlled(
                  value: selectedId,
                  itemSpacing: TRSpacing.extraSmall,
                  onValueChange: (definitionId) {
                    if (definitionId != null) onSelected(definitionId);
                  },
                  items: <TRTreeNavItem<String>>[
                    for (final definition in state.definitions)
                      TRTreeNavLeaf<String>(
                        value: definition.id,
                        showDisclosureIndicator: true,
                        leading: Icon(
                          definition.mode == AgentMode.primary
                              ? TinestIcons.agent
                              : TinestIcons.branch,
                        ),
                        label: TRText.inherit(definition.name),
                        description: TRText.inherit(
                          definition.isStale
                              ? l10n.agentSettingsModeStale(
                                  definition.mode.name,
                                )
                              : definition.mode.name,
                        ),
                        trailing: definition.diagnostics.isEmpty
                            ? null
                            : const Icon(TinestIcons.warning),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _AgentEditor extends ConsumerStatefulWidget {
  const new({
    required this.hostId,
    required this.state,
    required this.definition,
    required this.onArchived,
    super.key,
  });

  final String hostId;
  final AgentDefinitionsState state;
  final AgentDefinitionDto definition;
  final VoidCallback onArchived;

  @override
  ConsumerState<_AgentEditor> createState() => _AgentEditorState();
}

class _AgentEditorState extends ConsumerState<_AgentEditor> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _prompt;
  late final TextEditingController _modelId;
  late AgentModelSource _modelSource;
  late String _driverId;
  late List<String> _extensions;
  late Set<String> _tools;
  late Set<String> _callableAgents;
  late final Set<String> _initialSettingPluginIds;
  final Map<String, TextEditingController> _pluginSettings =
      <String, TextEditingController>{};
  final Set<String> _grantMutations = <String>{};
  final Set<String> _loadingModelConnections = <String>{};
  // Every group starts closed. The header carries the count, so a closed list
  // still says what is on, and seventeen tools fit on screen as seven rows.
  final Set<String> _expandedGroups = <String>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final definition = widget.definition;
    _name = TextEditingController(text: definition.name);
    _description = TextEditingController(text: definition.description);
    _prompt = TextEditingController(text: definition.prompt);
    _modelId = TextEditingController(text: definition.model.modelId);
    _modelSource = definition.model.source;
    _driverId = definition.driverId;
    _extensions = definition.extensionIds.toList(growable: true);
    _tools = definition.toolIds.toSet();
    _callableAgents = definition.callableAgentIds.toSet();
    _initialSettingPluginIds = definition.pluginSettings.keys.toSet();
    for (final entry in definition.pluginSettings.entries) {
      _pluginSettings[entry.key] = _pluginSettingsController(
        entry.key,
        initial: entry.value,
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _prompt.dispose();
    _modelId.dispose();
    for (final controller in _pluginSettings.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final definition = widget.definition;
    final editable = !_saving;
    final canSave =
        editable &&
        (_modelSource != AgentModelSource.fixed ||
            _modelId.text.trim().isNotEmpty);
    final providersState = ref.watch(
      providerSettingsControllerProvider(widget.hostId),
    );
    final pluginsState = ref.watch(
      pluginSettingsControllerProvider(widget.hostId),
    );
    final providers = providersState.value;
    final providersResolved = providersState.hasValue && providers != null;
    if (providers != null) _ensurePinnedModelLoaded(providers);
    final firstModel = providers == null
        ? null
        : firstUsableModel(providers.connections, providers.models);
    final modelBlocked = editable && providersResolved && firstModel == null;
    final modelSelectionEnabled =
        editable && providersResolved && firstModel != null;
    final storedModel = _modelId.text.isEmpty
        ? null
        : ModelSelectionDto(modelId: _modelId.text);
    final modelUnavailable =
        _modelSource == AgentModelSource.fixed &&
        providers != null &&
        storedModel != null &&
        !isRunnableSelection(
          storedModel,
          providers.connections,
          providers.models,
        );
    final plugins = pluginsState.value?.plugins;
    final contributionViews = plugins == null
        ? const <_PluginContributionView>[]
        : _contributions(plugins);
    final drivers = contributionViews
        .where(
          (view) => view.contribution.kind == PluginContributionKind.driver,
        )
        .toList(growable: false);
    final extensions = (plugins ?? const <PluginDescriptorDto>[])
        .where(
          (plugin) => plugin.contributions.any(
            (contribution) =>
                contribution.kind == PluginContributionKind.extension,
          ),
        )
        .map(_PluginExtensionView.new)
        .toList(growable: false);
    final pluginTools = _pluginToolDefinitions(contributionViews);
    final referencedPluginIds = _referencedPluginIds();
    final settingsPluginIds = <String>{
      ..._initialSettingPluginIds,
      ...referencedPluginIds,
    }.toList(growable: false)..sort();
    final harnessDiagnostics = plugins == null
        ? const <_HarnessDiagnostic>[]
        : _harnessDiagnostics(
            l10n,
            plugins,
            contributionViews,
            settingsPluginIds,
            providers,
          );
    // A definition returned by the daemon is already validated. Catalog
    // discovery may still be in flight after switching hosts, so only apply
    // contribution diagnostics once that catalog has actually arrived. This
    // keeps prompt and metadata edits independent from an unrelated reload.
    final harnessBlocked =
        plugins != null &&
        (_driverId.isEmpty ||
            !drivers.any((view) => view.id == _driverId) ||
            harnessDiagnostics.any((diagnostic) => diagnostic.blocking));
    final subagents = widget.state.definitions.where(
      (candidate) =>
          candidate.mode == AgentMode.subagent &&
          !candidate.isArchived &&
          !candidate.isStale,
    );
    return SettingsDestinationScaffold(
      title: TRText.inherit(definition.name),
      contentMaxWidth: TinestLayoutMetrics.settingsContentMaxWidth,
      actions: <TRIconButton>[
        TRIconButton(
          key: const ValueKey('agent-copy-path-button'),
          appearance: TRAppearance.ghost,
          label: l10n.agentSettingsCopyPath,
          onPressed: () =>
              Clipboard.setData(ClipboardData(text: definition.sourcePath)),
          icon: const Icon(TinestIcons.copy),
        ),
      ],
      formActions: <Widget>[
        TRButton(
          key: const ValueKey<String>('agent-settings-save'),
          intent: TRIntent.primary,
          onPressed: canSave && !harnessBlocked
              ? () => _save(force: false)
              : null,
          child: TRText.inherit(_saving ? l10n.commonSaving : l10n.commonSave),
        ),
      ],
      child: SettingsScaffold(
        key: ValueKey<String>('agent-settings-editor-${definition.id}'),
        children: <Widget>[
          SettingsSection.form(
            title: l10n.agentSettingsDefinitionHeading,
            banner: definition.diagnostics.isEmpty
                ? null
                : TRAlert(
                    title: TRText.inherit(definition.diagnostics.first.code),
                    description: TRText.inherit(
                      definition.diagnostics
                          .map((diagnostic) => diagnostic.message)
                          .join('\n'),
                    ),
                    icon: const Icon(TinestIcons.warning),
                    variant: TRStatusVariant.warning,
                  ),
            children: <Widget>[
              TRTextField(
                controller: _name,
                enabled: editable,
                label: l10n.commonName,
              ),
              TRTextField(
                controller: _description,
                enabled: editable,
                label: l10n.commonDescription,
              ),
              TRTextField(
                initialValue: definition.mode.name,
                enabled: false,
                label: l10n.commonKind,
              ),
            ],
          ),
          SettingsSection.form(
            title: l10n.agentSettingsPromptHeading,
            children: <Widget>[
              TRTextField(
                controller: _prompt,
                enabled: editable,
                minLines: 8,
                maxLines: 18,
                label: l10n.agentSettingsSystemPrompt,
              ),
            ],
          ),
          SettingsSection.form(
            title: l10n.agentSettingsModelHeading,
            banner: modelUnavailable
                ? TRAlert(
                    key: const ValueKey<String>(
                      'agent-settings-model-unavailable',
                    ),
                    title: TRText.inherit(l10n.modelSettingsUnavailableTitle),
                    description: TRText.inherit(
                      l10n.modelSettingsUnavailableDescription(_modelId.text),
                    ),
                    icon: const Icon(TinestIcons.warning),
                    variant: TRStatusVariant.warning,
                  )
                : null,
            children: <Widget>[
              TRRadioGroup(
                value: _modelSource.name,
                disabled: !editable,
                onValueChange: (value) => setState(() {
                  _modelSource = AgentModelSource.values.byName(value);
                  if (_modelSource == AgentModelSource.fixed &&
                      _modelId.text.isEmpty) {
                    _modelId.text = firstModel?.modelId ?? '';
                  }
                }),
                children: <TRRadio>[
                  TRRadio(
                    key: const ValueKey<String>(
                      'agent-settings-model-source-session',
                    ),
                    value: AgentModelSource.session.name,
                    label: TRText.inherit(l10n.agentSettingsSessionModel),
                  ),
                  TRRadio(
                    key: const ValueKey<String>(
                      'agent-settings-model-source-fixed',
                    ),
                    value: AgentModelSource.fixed.name,
                    label: TRText.inherit(l10n.agentSettingsPinnedModel),
                  ),
                ],
              ),
              if (_modelSource == AgentModelSource.fixed) ...<Widget>[
                Semantics(
                  key: const ValueKey<String>('agent-settings-model-selector'),
                  hint: modelBlocked ? l10n.composerConnectProviderFirst : null,
                  child: SettingsRow(
                    flush: true,
                    // A providerless selector remains actionable so the
                    // product wrapper can explain how to unlock it.
                    enabled: modelSelectionEnabled || modelBlocked,
                    title: TRText.inherit(
                      l10n.agentSettingsModelId,
                      color: modelBlocked ? TRTextColor.muted : null,
                    ),
                    controlOwnsFocus: true,
                    control: _agentModelSelect(
                      l10n,
                      enabled: modelSelectionEnabled,
                      blocked: modelBlocked,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (plugins == null)
            SettingsSection(
              title: l10n.agentSettingsHarnessHeading,
              children: <Widget>[
                TRAlert(
                  key: const ValueKey<String>('agent-plugins-loading'),
                  title: TRText.inherit(l10n.agentSettingsPluginsLoading),
                  description: pluginsState.hasError
                      ? TRText.inherit('${pluginsState.error}')
                      : null,
                  icon: const Icon(TinestIcons.agent),
                  variant: pluginsState.hasError
                      ? TRStatusVariant.danger
                      : TRStatusVariant.info,
                ),
              ],
            )
          else ...<Widget>[
            SettingsSection.form(
              title: l10n.agentSettingsHarnessHeading,
              description: l10n.agentSettingsHarnessDescription,
              banner: harnessDiagnostics.isEmpty
                  ? null
                  : TRAlert(
                      key: const ValueKey<String>('agent-harness-diagnostics'),
                      title: TRText.inherit(
                        l10n.agentSettingsHarnessDiagnostics,
                      ),
                      description: TRText.inherit(
                        harnessDiagnostics
                            .map((diagnostic) => diagnostic.message)
                            .join('\n'),
                      ),
                      icon: const Icon(TinestIcons.warning),
                      variant:
                          harnessDiagnostics.any(
                            (diagnostic) => diagnostic.blocking,
                          )
                          ? TRStatusVariant.danger
                          : TRStatusVariant.warning,
                    ),
              children: <Widget>[
                if (drivers.isEmpty)
                  TRAlert(
                    title: TRText.inherit(l10n.agentSettingsNoDrivers),
                    variant: TRStatusVariant.danger,
                  )
                else
                  TRSelect<String>.controlled(
                    searchable: true,
                    presentation: TinestSelectPresentation.resolve(context),
                    key: const ValueKey<String>('agent-plugin-driver'),
                    label: l10n.agentSettingsDriver,
                    value: _driverId.isEmpty ? null : _driverId,
                    enabled: editable,
                    items: _driverItems(drivers),
                    onValueChange: editable
                        ? (value) {
                            if (value == null) return;
                            setState(() => _driverId = value);
                          }
                        : null,
                  ),
              ],
            ),
            SettingsSection(
              title: l10n.agentSettingsExtensions,
              description: l10n.agentSettingsExtensionsDescription,
              children: <Widget>[
                for (final entry in _orderedExtensionRows(extensions))
                  TinestCheckboxRow(
                    key: ValueKey<String>(
                      'agent-extension-${_keyId(entry.id)}',
                    ),
                    value: entry.selected,
                    onChanged: editable
                        ? (enabled) => setState(() {
                            if (enabled ?? false) {
                              _extensions.add(entry.id);
                            } else {
                              _extensions.remove(entry.id);
                            }
                          })
                        : null,
                    title: TRText.inherit(entry.label),
                    subtitle: TRText.inherit(entry.description),
                    secondary: entry.selected
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              TRIconButton(
                                key: ValueKey<String>(
                                  'agent-extension-up-${_keyId(entry.id)}',
                                ),
                                appearance: TRAppearance.ghost,
                                uiSize: TRUiSize.sm,
                                label: l10n.agentSettingsMoveUp,
                                onPressed: editable && entry.index > 0
                                    ? () => _moveExtension(
                                        entry.index,
                                        entry.index - 1,
                                      )
                                    : null,
                                icon: const Icon(TinestIcons.collapse),
                              ),
                              TRIconButton(
                                key: ValueKey<String>(
                                  'agent-extension-down-'
                                  '${_keyId(entry.id)}',
                                ),
                                appearance: TRAppearance.ghost,
                                uiSize: TRUiSize.sm,
                                label: l10n.agentSettingsMoveDown,
                                onPressed:
                                    editable &&
                                        entry.index < _extensions.length - 1
                                    ? () => _moveExtension(
                                        entry.index,
                                        entry.index + 1,
                                      )
                                    : null,
                                icon: const Icon(TinestIcons.expand),
                              ),
                            ],
                          )
                        : null,
                  ),
              ],
            ),
            SettingsSection(
              title: l10n.agentSettingsPluginTools,
              description: l10n.agentSettingsPluginToolsDescription,
              children: <Widget>[
                for (final view in groupAgentTools(pluginTools)) ...[
                  _toolGroupHeader(l10n, view, editable: editable),
                  if (_expandedGroups.contains(view.group))
                    for (final tool in view.tools)
                      TinestCheckboxRow(
                        key: ValueKey<String>(
                          'agent-tool-tile-${_keyId(tool.id)}',
                        ),
                        value: _tools.contains(tool.id),
                        onChanged: editable
                            ? (enabled) => setState(() {
                                enabled!
                                    ? _tools.add(tool.id)
                                    : _tools.remove(tool.id);
                              })
                            : null,
                        title: TRText.inherit(tool.name),
                        subtitle: TRText.inherit(tool.description),
                      ),
                ],
              ],
            ),
            SettingsSection.form(
              title: l10n.agentSettingsPluginSettings,
              description: l10n.agentSettingsPluginSettingsDescription,
              children: <Widget>[
                for (final pluginId in settingsPluginIds)
                  TRTextField(
                    key: ValueKey<String>('agent-plugin-settings-$pluginId'),
                    controller: _settingsController(pluginId),
                    enabled: editable,
                    minLines: 3,
                    maxLines: 8,
                    onChanged: (_) => setState(() {}),
                    helperText: l10n.agentSettingsPluginSettingsRemove,
                    label: l10n.agentSettingsPluginSettingsLabel(
                      _pluginLabel(plugins, pluginId),
                    ),
                  ),
              ],
            ),
            _capabilitiesSection(
              l10n,
              plugins,
              referencedPluginIds,
              editable: editable,
            ),
          ],
          if (definition.mode == AgentMode.primary)
            SettingsSection(
              title: l10n.agentSettingsSubagents,
              children: <Widget>[
                if (subagents.isEmpty)
                  SettingsRow(
                    title: TRText.inherit(l10n.agentSettingsNoSubagents),
                  ),
                for (final subagent in subagents)
                  TinestCheckboxRow(
                    key: ValueKey<String>('agent-callable-${subagent.id}'),
                    value: _callableAgents.contains(subagent.id),
                    onChanged: editable
                        ? (enabled) => setState(() {
                            enabled!
                                ? _callableAgents.add(subagent.id)
                                : _callableAgents.remove(subagent.id);
                          })
                        : null,
                    title: TRText.inherit(subagent.name),
                    subtitle: TRText.inherit(subagent.description),
                  ),
              ],
            ),
          SettingsSection(
            title: definition.isBuiltIn
                ? l10n.agentSettingsReset
                : l10n.workspaceArchive,
            // The row names the agent and the note says what the action costs.
            // As the row's own title the note wrapped beside a button half its
            // height, which is what every destructive row here used to do.
            footer: definition.isBuiltIn
                ? l10n.agentSettingsResetBody
                : l10n.agentSettingsArchiveBody,
            children: <Widget>[
              SettingsRow(
                title: TRText.inherit(definition.name),
                control: TRButton(
                  key: ValueKey<String>(
                    definition.isBuiltIn
                        ? 'agent-reset-button'
                        : 'agent-archive-button',
                  ),
                  appearance: TRAppearance.ghost,
                  intent: TRIntent.danger,
                  onPressed: editable
                      ? definition.isBuiltIn
                            ? _reset
                            : _archive
                      : null,
                  child: TRText.inherit(
                    definition.isBuiltIn
                        ? l10n.agentSettingsReset
                        : l10n.workspaceArchive,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The row standing for one group: its state, and the whole-group toggle.
  ///
  /// The checkbox and the row do different things — one turns the group on and
  /// off, the other opens it — so each is its own tab stop rather than the row
  /// repeating the control the way a plain setting does.
  Widget _toolGroupHeader(
    AppLocalizations l10n,
    AgentToolGroupView view, {
    required bool editable,
  }) {
    final expanded = _expandedGroups.contains(view.group);
    final enabled = view.enabledCount(_tools);
    return TinestCheckboxRow(
      key: ValueKey<String>('agent-tool-group-${view.group}'),
      value: view.allEnabled(_tools),
      indeterminate: view.partiallyEnabled(_tools),
      onChanged: editable
          ? (checked) => setState(() {
              checked!
                  ? _tools.addAll(view.toggleableIds)
                  : _tools.removeAll(view.toggleableIds);
            })
          : null,
      onRowTap: () => setState(() {
        expanded
            ? _expandedGroups.remove(view.group)
            : _expandedGroups.add(view.group);
      }),
      secondary: Icon(expanded ? TinestIcons.collapse : TinestIcons.expand),
      title: TRText.inherit(toolGroupLabel(l10n, view.group)),
      subtitle: TRText.inherit(
        l10n.agentSettingsToolGroupSummary(enabled, view.tools.length),
      ),
    );
  }

  AgentDefinitionDto _editedDefinition() => widget.definition.copyWith(
    version: 5,
    name: _name.text.trim(),
    description: _description.text.trim(),
    driverId: _driverId,
    extensionIds: List<String>.unmodifiable(_extensions),
    model: AgentModelSelectionDto(
      source: _modelSource,
      modelId: _modelSource == AgentModelSource.fixed
          ? _modelId.text.trim()
          : null,
    ),
    toolIds: _tools.toList(growable: false)..sort(),
    pluginSettings: _decodedPluginSettings(),
    callableAgentIds: _callableAgents.toList(growable: false)..sort(),
    prompt: _prompt.text,
    contentHash: widget.definition.contentHash,
  );

  List<_PluginContributionView> _contributions(
    List<PluginDescriptorDto> plugins,
  ) => <_PluginContributionView>[
    for (final plugin in plugins)
      for (final contribution in plugin.contributions)
        _PluginContributionView(plugin: plugin, contribution: contribution),
  ];

  List<AgentToolDefinitionDto> _pluginToolDefinitions(
    List<_PluginContributionView> contributions,
  ) {
    final installed = contributions
        .where(
          (view) =>
              view.contribution.kind == PluginContributionKind.tool &&
              view.contribution.tool != null,
        )
        .map((view) => view.contribution.tool!)
        .toList(growable: true);
    final installedIds = installed.map((tool) => tool.id).toSet();
    installed.addAll(<AgentToolDefinitionDto>[
      for (final toolId in _tools)
        if (!installedIds.contains(toolId))
          AgentToolDefinitionDto(
            id: toolId,
            originPluginId: _pluginId(toolId),
            contributionId: _localId(toolId),
            name: _localId(toolId),
            description: toolId,
            risk: ToolRisk.dangerous,
            group: _pluginId(toolId),
            kind: AgentToolKind.function,
            inputSchema: const <String, dynamic>{'type': 'object'},
            effects: const <String>[],
            presentation: const <String, dynamic>{},
            available: false,
          ),
    ]);
    return installed;
  }

  List<TRSelectItem<String>> _driverItems(
    List<_PluginContributionView> drivers,
  ) {
    final items = <TRSelectItem<String>>[
      for (final driver in drivers)
        TRSelectItem<String>(value: driver.id, label: driver.label),
    ];
    if (_driverId.isNotEmpty &&
        !drivers.any((driver) => driver.id == _driverId)) {
      items.insert(0, TRSelectItem<String>(value: _driverId, label: _driverId));
    }
    return items;
  }

  List<_ExtensionRow> _orderedExtensionRows(
    List<_PluginExtensionView> extensions,
  ) {
    final byId = <String, _PluginExtensionView>{
      for (final extension in extensions) extension.id: extension,
    };
    return <_ExtensionRow>[
      for (final entry in _extensions.indexed)
        _ExtensionRow(
          id: entry.$2,
          label: byId[entry.$2]?.label ?? entry.$2,
          description: byId[entry.$2]?.description ?? entry.$2,
          selected: true,
          index: entry.$1,
        ),
      for (final extension in extensions)
        if (!_extensions.contains(extension.id))
          _ExtensionRow(
            id: extension.id,
            label: extension.label,
            description: extension.description,
            selected: false,
            index: -1,
          ),
    ];
  }

  void _moveExtension(int from, int to) => setState(() {
    final value = _extensions.removeAt(from);
    _extensions.insert(to, value);
  });

  Set<String> _referencedPluginIds() => <String>{
    if (_driverId.isNotEmpty) _pluginId(_driverId),
    ..._extensions.map(_pluginId),
    ..._tools.map(_pluginId),
    ..._initialSettingPluginIds,
  };

  TextEditingController _settingsController(String pluginId) => _pluginSettings
      .putIfAbsent(pluginId, () => _pluginSettingsController(pluginId));

  TextEditingController _pluginSettingsController(
    String pluginId, {
    Map<String, dynamic>? initial,
  }) => TextEditingController(
    text: const JsonEncoder.withIndent('  ')
        .convert(initial ?? <String, dynamic>{}),
  );

  Map<String, Map<String, dynamic>> _decodedPluginSettings() =>
      <String, Map<String, dynamic>>{
        for (final entry in _pluginSettings.entries)
          if (entry.value.text.trim().isNotEmpty &&
              (_initialSettingPluginIds.contains(entry.key) ||
                  entry.value.text.trim() != '{}'))
            entry.key: Map<String, dynamic>.from(
              jsonDecode(entry.value.text) as Map,
            ),
      };

  List<_HarnessDiagnostic> _harnessDiagnostics(
    AppLocalizations l10n,
    List<PluginDescriptorDto> plugins,
    List<_PluginContributionView> contributions,
    List<String> settingsPluginIds,
    ProviderSettingsState? providers,
  ) {
    final diagnostics = <_HarnessDiagnostic>[];
    final installedPlugins = plugins.map((plugin) => plugin.id).toSet();
    final contributionIds = contributions.map((view) => view.id).toSet();
    final extensionIds = contributions
        .where(
          (view) => view.contribution.kind == PluginContributionKind.extension,
        )
        .map((view) => view.plugin.id)
        .toSet();
    if (_driverId.isEmpty || !contributionIds.contains(_driverId)) {
      diagnostics.add(
        _HarnessDiagnostic(
          l10n.agentSettingsHarnessMissing(
            l10n.agentSettingsHarnessKindDriver,
            _driverId.isEmpty ? '—' : _driverId,
          ),
        ),
      );
    }
    for (final extension in _extensions) {
      if (!extensionIds.contains(extension)) {
        diagnostics.add(
          _HarnessDiagnostic(
            l10n.agentSettingsHarnessMissing(
              l10n.agentSettingsHarnessKindExtension,
              extension,
            ),
          ),
        );
      }
    }
    for (final tool in _tools) {
      if (!contributionIds.contains(tool)) {
        diagnostics.add(
          _HarnessDiagnostic(
            l10n.agentSettingsHarnessMissing(
              l10n.agentSettingsHarnessKindTool,
              tool,
            ),
          ),
        );
      }
    }
    for (final pluginId in _referencedPluginIds()) {
      if (!installedPlugins.contains(pluginId)) {
        diagnostics.add(
          _HarnessDiagnostic(
            l10n.agentSettingsHarnessMissing(
              l10n.agentSettingsHarnessKindPlugin,
              pluginId,
            ),
          ),
        );
      }
    }
    final activeContributions = contributions.where(
      (view) =>
          view.id == _driverId ||
          _tools.contains(view.id) ||
          (view.contribution.kind == PluginContributionKind.extension &&
              _extensions.contains(view.plugin.id)),
    );
    for (final contribution in activeContributions) {
      for (final dependency in contribution.dependencies) {
        final satisfied = dependency.contains('/')
            ? contributionIds.contains(dependency) &&
                  (_driverId == dependency ||
                      _tools.contains(dependency) ||
                      _extensions.contains(_pluginId(dependency)))
            : _referencedPluginIds().contains(dependency);
        if (!satisfied) {
          diagnostics.add(
            _HarnessDiagnostic(
              l10n.agentSettingsHarnessMissing(
                l10n.agentSettingsHarnessKindDependency,
                dependency,
              ),
            ),
          );
        }
      }
    }
    for (final pluginId in settingsPluginIds) {
      if (_settingsController(pluginId).text.trim().isEmpty) continue;
      try {
        if (jsonDecode(_settingsController(pluginId).text) is! Map) {
          throw const FormatException();
        }
      } on FormatException {
        diagnostics.add(
          _HarnessDiagnostic(
            l10n.agentSettingsHarnessInvalidSettings(pluginId),
          ),
        );
      }
    }
    final driver = contributions
        .where((view) => view.id == _driverId)
        .firstOrNull;
    final model = _selectedProviderModel(providers);
    if (_modelSource == AgentModelSource.fixed && providers != null) {
      final connection = usableConnections(providers.connections)
          .where(
            (candidate) =>
                _modelId.text.startsWith('${candidate.modelPrefix}/'),
          )
          .firstOrNull;
      if (connection == null ||
          (providers.models.containsKey(connection.id) && model == null)) {
        diagnostics.add(
          _HarnessDiagnostic(
            l10n.agentSettingsHarnessMissing(
              l10n.agentSettingsHarnessKindModel,
              _modelId.text,
            ),
          ),
        );
      }
    }
    if (_modelSource == AgentModelSource.fixed &&
        driver != null &&
        model != null) {
      for (final capability in driver.requiredModelCapabilities) {
        if (!_modelSupports(model, capability)) {
          diagnostics.add(
            _HarnessDiagnostic(
              l10n.agentSettingsHarnessModelMismatch(capability),
            ),
          );
        }
      }
    }
    return diagnostics;
  }

  ProviderModelDto? _selectedProviderModel(ProviderSettingsState? providers) {
    if (providers == null || _modelId.text.trim().isEmpty) return null;
    for (final models in providers.models.values) {
      for (final model in models) {
        if (model.id == _modelId.text.trim()) return model;
      }
    }
    return null;
  }

  bool _modelSupports(ProviderModelDto model, String requirement) {
    final capabilities = model.capabilities;
    final support = switch (requirement) {
      'streaming' => capabilities.streaming,
      'tool_calling' => capabilities.toolCalling,
      'function_tools' => capabilities.functionTools,
      'deferred_tools' => capabilities.deferredTools,
      'image_input' => capabilities.imageInput,
      'file_input' => capabilities.fileInput,
      _ => CapabilitySupport.unknown,
    };
    return support == CapabilitySupport.supported;
  }

  SettingsSection _capabilitiesSection(
    AppLocalizations l10n,
    List<PluginDescriptorDto> plugins,
    Set<String> referencedPluginIds, {
    required bool editable,
  }) {
    final requested =
        <({String pluginId, String pluginName, String capability})>[
          for (final plugin in plugins)
            if (referencedPluginIds.contains(plugin.id))
              for (final capability in plugin.requestedCapabilities)
                (
                  pluginId: plugin.id,
                  pluginName: plugin.name,
                  capability: capability,
                ),
        ];
    final grantsState = ref.watch(
      agentPluginGrantsControllerProvider(widget.hostId, widget.definition.id),
    );
    final grants = grantsState.value ?? const <AgentPluginGrantDto>[];
    return SettingsSection(
      title: l10n.agentSettingsCapabilities,
      description: l10n.agentSettingsCapabilitiesDescription,
      children: <Widget>[
        if (requested.isEmpty)
          SettingsRow(title: TRText.inherit(l10n.agentSettingsNoCapabilities))
        else if (!grantsState.hasValue)
          SettingsRow(title: TRText.inherit(l10n.agentSettingsPluginsLoading))
        else
          for (final request in requested)
            SettingsRow(
              title: TRText.inherit(request.capability),
              description: TRText.inherit(request.pluginName),
              control: TRSwitch(
                key: ValueKey<String>(
                  'agent-plugin-grant-${request.pluginId}-'
                  '${request.capability}',
                ),
                checked: grants.any(
                  (grant) =>
                      grant.pluginId == request.pluginId &&
                      grant.capability == request.capability,
                ),
                semanticLabel: '${request.pluginName}: ${request.capability}',
                disabled:
                    !editable ||
                    _grantMutations.contains(
                      '${request.pluginId}/${request.capability}',
                    ),
                onCheckedChange: (granted) => _setCapability(
                  pluginId: request.pluginId,
                  capability: request.capability,
                  granted: granted,
                ),
              ),
            ),
      ],
    );
  }

  Future<void> _setCapability({
    required String pluginId,
    required String capability,
    required bool granted,
  }) async {
    final key = '$pluginId/$capability';
    setState(() => _grantMutations.add(key));
    try {
      final controller = ref.read(
        agentPluginGrantsControllerProvider(
          widget.hostId,
          widget.definition.id,
        ).notifier,
      );
      await ref
          .read(toastMessengerProvider)
          .run(
            () => controller.setCapability(
              pluginId: pluginId,
              capability: capability,
              granted: granted,
            ),
            failure: AppLocalizations.of(context).pluginSettingsActionFailed,
            id: 'agent-plugin-grant-$key',
          );
    } finally {
      if (mounted) setState(() => _grantMutations.remove(key));
    }
  }

  void _ensurePinnedModelLoaded(ProviderSettingsState providers) {
    if (_modelSource != AgentModelSource.fixed || _modelId.text.isEmpty) return;
    final connection = usableConnections(providers.connections)
        .where(
          (candidate) => _modelId.text.startsWith('${candidate.modelPrefix}/'),
        )
        .firstOrNull;
    if (connection == null ||
        providers.models.containsKey(connection.id) ||
        !_loadingModelConnections.add(connection.id)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref
            .read(providerSettingsControllerProvider(widget.hostId).notifier)
            .loadModels(connection.id);
      } finally {
        _loadingModelConnections.remove(connection.id);
      }
    });
  }

  void _showProviderRequiredToast(AppLocalizations l10n) {
    ref
        .read(toastMessengerProvider)
        .info(
          l10n.composerConnectProviderFirst,
          id: 'model-selector-provider-required',
        );
  }

  Widget _agentModelSelect(
    AppLocalizations l10n, {
    required bool enabled,
    required bool blocked,
  }) {
    final select = AsyncModelSelect(
      loadKey: widget.hostId,
      loadOptions: ref.read(modelPickerOptionsLoaderProvider(widget.hostId)),
      currentSelection: _modelId.text.isEmpty
          ? null
          : ModelSelectionDto(modelId: _modelId.text),
      placeholder: _modelId.text.isEmpty ? l10n.composerModel : _modelId.text,
      enabled: enabled,
      leading: Icon(blocked ? TinestIcons.lock : TinestIcons.memory),
      onValueChange: (option) =>
          setState(() => _modelId.text = option.model.id),
    );
    if (!blocked) return select;
    return BlockedControl(
      label: l10n.agentSettingsModelId,
      hint: l10n.composerConnectProviderFirst,
      onTap: () => _showProviderRequiredToast(l10n),
      child: select,
    );
  }

  Future<void> _save({required bool force}) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      await ProviderScope.containerOf(context)
          .read(agentDefinitionsControllerProvider(widget.hostId).notifier)
          .saveDefinition(
            _editedDefinition(),
            expectedContentHash: widget.definition.contentHash,
            force: force,
          );
      if (!mounted) return;
      ref.invalidate(pluginSettingsControllerProvider(widget.hostId));
    } on Exception catch (error) {
      if (!mounted) return;
      final retry = await showTRDialog<bool>(
        context: context,
        builder: (context) => TRAlertDialog(
          title: TRText.inherit(l10n.agentSettingsSaveFailedTitle),
          content: TRText.inherit('$error'),
          actions: <TRButton>[
            TRButton(
              appearance: TRAppearance.ghost,
              onPressed: () => Navigator.pop(context, false),
              child: TRText.inherit(l10n.agentSettingsReload),
            ),
            TRButton(
              intent: TRIntent.primary,
              onPressed: () => Navigator.pop(context, true),
              child: TRText.inherit(l10n.agentSettingsOverwrite),
            ),
          ],
        ),
      );
      if (retry == true && mounted) await _save(force: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Asks before a destructive change, the way every other one here does.
  ///
  /// Archiving and resetting used to run straight off a single click, which
  /// made them the only two irreversible actions in the application without a
  /// step between the pointer and the consequence.
  Future<bool> _confirm({
    required String title,
    required String body,
    required String accept,
    required String confirmKey,
  }) async {
    final confirmed = await showTRDialog<bool>(
      context: context,
      builder: (context) => TRAlertDialog(
        title: TRText.inherit(title),
        content: TRText.inherit(body),
        actions: <TRButton>[
          TRButton(
            appearance: TRAppearance.ghost,
            onPressed: () => Navigator.pop(context, false),
            child: TRText.inherit(AppLocalizations.of(context).commonCancel),
          ),
          TRButton(
            key: ValueKey<String>(confirmKey),
            intent: TRIntent.danger,
            onPressed: () => Navigator.pop(context, true),
            child: TRText.inherit(accept),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _archive() async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(
      title: l10n.agentSettingsArchiveTitle(widget.definition.name),
      body: l10n.agentSettingsArchiveBody,
      accept: l10n.workspaceArchive,
      confirmKey: 'agent-archive-confirm',
    )) {
      return;
    }
    if (!mounted) return;
    final container = ProviderScope.containerOf(context);
    final archived = await container
        .read(toastMessengerProvider)
        .run(
          () => container
              .read(agentDefinitionsControllerProvider(widget.hostId).notifier)
              .archive(widget.definition.id),
          failure: l10n.agentSettingsArchiveFailed,
          success: l10n.agentSettingsArchived,
          id: 'agent-archive',
        );
    if (archived) widget.onArchived();
  }

  Future<void> _reset() async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(
      title: l10n.agentSettingsResetTitle(widget.definition.name),
      body: l10n.agentSettingsResetBody,
      accept: l10n.agentSettingsReset,
      confirmKey: 'agent-reset-confirm',
    )) {
      return;
    }
    if (!mounted) return;
    final container = ProviderScope.containerOf(context);
    await container
        .read(toastMessengerProvider)
        .run(
          () => container
              .read(agentDefinitionsControllerProvider(widget.hostId).notifier)
              .resetTinest(),
          failure: l10n.agentSettingsResetFailed,
          success: l10n.agentSettingsResetDone,
          id: 'agent-reset',
        );
  }
}

final class _PluginContributionView {
  const new({required this.plugin, required this.contribution});

  final PluginDescriptorDto plugin;
  final PluginContributionDto contribution;

  String get id => contribution.id.contains('/')
      ? contribution.id
      : '${plugin.id}/${contribution.id}';

  String get label =>
      contribution.tool?.name ??
      contribution.metadata['name'] as String? ??
      '${plugin.name} · ${_localId(id)}';

  String get description =>
      contribution.tool?.description ??
      contribution.metadata['description'] as String? ??
      plugin.name;

  List<String> get requiredModelCapabilities {
    final value = contribution.metadata['requiredModelCapabilities'];
    if (value is! List) return const <String>[];
    return value.whereType<String>().toList(growable: false);
  }

  List<String> get dependencies {
    final value =
        contribution.metadata['dependencies'] ??
        contribution.metadata['requires'];
    if (value is! List) return const <String>[];
    return value.whereType<String>().toList(growable: false);
  }
}

final class _ExtensionRow {
  const new({
    required this.id,
    required this.label,
    required this.description,
    required this.selected,
    required this.index,
  });

  final String id;
  final String label;
  final String description;
  final bool selected;
  final int index;
}

final class _PluginExtensionView {
  const new(this.plugin);

  final PluginDescriptorDto plugin;

  String get id => plugin.id;
  String get label => plugin.name;
  String get description {
    final lifecycle = plugin.contributions
        .where(
          (contribution) =>
              contribution.kind == PluginContributionKind.extension,
        )
        .map(
          (contribution) =>
              contribution.metadata['lifecycle'] as String? ??
              _localId(contribution.id),
        )
        .join(', ');
    return lifecycle.isEmpty ? plugin.id : lifecycle;
  }
}

final class _HarnessDiagnostic {
  const new(this.message);

  final String message;
  bool get blocking => true;
}

String _pluginId(String contributionId) {
  final separator = contributionId.indexOf('/');
  return separator < 0
      ? contributionId
      : contributionId.substring(0, separator);
}

String _localId(String contributionId) {
  final separator = contributionId.indexOf('/');
  return separator < 0
      ? contributionId
      : contributionId.substring(separator + 1);
}

String _keyId(String contributionId) => contributionId.replaceAll('/', '-');

String _pluginLabel(List<PluginDescriptorDto> plugins, String pluginId) =>
    plugins
        .where((plugin) => plugin.id == pluginId)
        .map((plugin) => plugin.name)
        .firstOrNull ??
    pluginId;

class _CreateAgentInput {
  const new({required this.id, required this.name, required this.mode});

  final String id;
  final String name;
  final AgentMode mode;
}

class _CreateAgentPane extends StatefulWidget {
  const new({
    required this.existingIds,
    required this.onCreate,
    required this.onCreated,
    required this.onCancel,
  });

  final Set<String> existingIds;
  final Future<AgentDefinitionDto> Function(_CreateAgentInput input) onCreate;
  final ValueChanged<AgentDefinitionDto> onCreated;
  final VoidCallback onCancel;

  @override
  State<_CreateAgentPane> createState() => _CreateAgentPaneState();
}

class _CreateAgentPaneState extends State<_CreateAgentPane> {
  final _id = TextEditingController();
  final _name = TextEditingController();
  AgentMode _mode = AgentMode.primary;
  bool _saving = false;
  Object? _error;

  /// Whether the typed ID is well-formed and unused.
  bool get _idAccepted {
    final id = _id.text.trim();
    return RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(id) &&
        !widget.existingIds.contains(id);
  }

  String? _idError(AppLocalizations l10n) {
    final id = _id.text.trim();
    if (id.isEmpty) return null;
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(id)) {
      return l10n.agentSettingsIdInvalid;
    }
    if (widget.existingIds.contains(id)) return l10n.agentSettingsIdTaken;
    return null;
  }

  bool get _valid => _name.text.trim().isNotEmpty && _idAccepted;

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
      title: TRText.inherit(l10n.agentSettingsAddTitle),
      contentMaxWidth: TinestLayoutMetrics.settingsContentMaxWidth,
      formActions: <Widget>[
        TRButton(
          appearance: TRAppearance.ghost,
          onPressed: _saving ? null : widget.onCancel,
          child: TRText.inherit(l10n.commonCancel),
        ),
        TRButton(
          key: const ValueKey<String>('agent-settings-create'),
          intent: TRIntent.primary,
          onPressed: _valid && !_saving ? _submit : null,
          child: TRText.inherit(
            _saving ? l10n.commonCreating : l10n.commonCreate,
          ),
        ),
      ],
      child: SettingsScaffold(
        children: <Widget>[
          SettingsSection.form(
            children: <Widget>[
              TRTextField(
                controller: _id,
                autofocus: true,
                enabled: !_saving,
                onChanged: (_) => setState(() => _error = null),
                label: l10n.agentSettingsIdLabel,
                // An ID becomes a file name, so the example stays a
                // literal identifier in every language.
                placeholder: 'reviewer',
                errorText: _idError(l10n),
              ),
              TRTextField(
                controller: _name,
                enabled: !_saving,
                onChanged: (_) => setState(() => _error = null),
                label: l10n.commonName,
                errorText: _name.text.isEmpty || _name.text.trim().isNotEmpty
                    ? null
                    : l10n.agentSettingsNameRequired,
              ),
              TRSelectFormField<AgentMode>(
                initialValue: _mode,
                searchable: true,
                searchPlaceholder: l10n.selectSearchPlaceholder,
                noResultsText: l10n.selectNoResults,
                presentation: TinestSelectPresentation.resolve(context),
                label: l10n.commonKind,
                width: TinestLayoutMetrics.settingsContentMaxWidth,
                items: AgentMode.values
                    .map(
                      (value) => TRSelectItem<AgentMode>(
                        value: value,
                        label: value.name,
                      ),
                    )
                    .toList(growable: false),
                onValueChange: _saving
                    ? null
                    : (value) => setState(() => _mode = value!),
              ),
              if (_error case final error?)
                TRAlert(
                  variant: TRStatusVariant.danger,
                  title: TRText.inherit('$error'),
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
      final created = await widget.onCreate(
        _CreateAgentInput(
          id: _id.text.trim(),
          name: _name.text.trim(),
          mode: _mode,
        ),
      );
      if (mounted) widget.onCreated(created);
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error;
        });
      }
    }
  }
}
