import 'dart:async';
import 'dart:typed_data';

import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/features/agents/application/agent_definitions_controller.dart';
import 'package:app/src/features/conversation/application/attachment_ports.dart';
import 'package:app/src/features/conversation/application/composer_controller.dart';
import 'package:app/src/features/conversation/application/composer_suggestions.dart';
import 'package:app/src/features/conversation/application/conversation_controller.dart';
import 'package:app/src/features/conversation/domain/composer_commands.dart';
import 'package:app/src/features/conversation/presentation/chat_first_line_alignment.dart';
import 'package:app/src/features/conversation/presentation/composer_client_commands.dart';
import 'package:app/src/features/conversation/presentation/composer_trigger.dart';
import 'package:app/src/features/conversation/presentation/widgets/composer_completion_scope.dart';
import 'package:app/src/features/conversation/presentation/widgets/composer_suggestions_overlay.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/models/application/model_settings_controller.dart';
import 'package:app/src/features/permissions/application/permission_settings_controller.dart';
import 'package:app/src/features/plugins/presentation/agent_plugin_ui_slot.dart';
import 'package:app/src/features/providers/application/model_picker_options.dart';
import 'package:app/src/features/providers/application/provider_settings_controller.dart';
import 'package:app/src/features/providers/application/session_model_options.dart';
import 'package:app/src/features/sessions/application/session_prompt_starter.dart';
import 'package:app/src/features/sessions/application/session_starter.dart';
import 'package:app/src/features/sessions/domain/session_title.dart';
import 'package:app/src/shared/presentation/blocked_control.dart';
import 'package:app/src/shared/presentation/model_picker.dart';
import 'package:app/src/shared/presentation/permission_picker.dart';
import 'package:app/src/shared/presentation/settings_layout.dart';
import 'package:app/src/shared/presentation/tinest_bottom_sheet.dart';
import 'package:app/src/shared/presentation/tinest_icons.dart';
import 'package:app/src/shared/presentation/tinest_list_row.dart';
import 'package:app/src/shared/presentation/tinest_select_presentation.dart';
import 'package:app/src/shared/presentation/tinest_ui_density.dart';
import 'package:app/src/shared/presentation/toast_messenger.dart';
import 'package:dropwell/dropwell.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Turn settings shown in the composer toolbar row.
class SessionComposerBar extends ConsumerStatefulWidget {
  /// Creates a [SessionComposerBar].
  const new({
    required this.hostId,
    required this.definitions,
    required this.agentDefinitionId,
    required this.selection,
    required this.onAgentChanged,
    required this.onModelChanged,
    this.modelControls = const <String, ModelControlValueDto>{},
    this.onModelControlsChanged,
    this.permissionMode,
    this.onPermissionModeChanged,
    this.agentEnabled = true,
    this.enabled = true,
    this.compact = false,
    super.key,
  });

  /// Returns the single settings action used below the composer breakpoint.
  SessionComposerBar asCompact() => SessionComposerBar(
    hostId: hostId,
    definitions: definitions,
    agentDefinitionId: agentDefinitionId,
    selection: selection,
    onAgentChanged: onAgentChanged,
    onModelChanged: onModelChanged,
    modelControls: modelControls,
    onModelControlsChanged: onModelControlsChanged,
    permissionMode: permissionMode,
    onPermissionModeChanged: onPermissionModeChanged,
    agentEnabled: agentEnabled,
    enabled: enabled,
    compact: true,
    key: key,
  );

  /// Daemon profile owning the provider connections.
  final String hostId;

  /// Agent definitions the user may choose from.
  final List<AgentDefinitionDto> definitions;

  /// Agent definition currently in effect.
  final String? agentDefinitionId;

  /// Provider-qualified model currently in effect, if any resolves.
  final ModelSelectionDto? selection;

  /// Called with the newly chosen agent definition id.
  final ValueChanged<String> onAgentChanged;

  /// Called with one concrete chosen model.
  final FutureOr<void> Function(
    ModelSelectionDto selection,
    Map<String, ModelControlValueDto> controls,
  )
  onModelChanged;

  /// Explicit values for the selected provider model.
  final Map<String, ModelControlValueDto> modelControls;

  /// Called whenever a model-specific value changes.
  final FutureOr<void> Function(Map<String, ModelControlValueDto>)?
  onModelControlsChanged;

  /// Permission mode in effect, or null for a draft that has not chosen one
  /// and therefore shows the host default.
  final PermissionMode? permissionMode;

  /// Called with the chosen mode.
  final FutureOr<void> Function(PermissionMode)? onPermissionModeChanged;

  /// Whether the agent can still be changed; false once a session exists.
  final bool agentEnabled;

  /// Whether any selector accepts input.
  final bool enabled;

  /// Whether this bar renders as the compact settings-sheet trigger.
  final bool compact;

  @override
  ConsumerState<SessionComposerBar> createState() => _SessionComposerBarState();
}

class _SessionComposerBarState extends ConsumerState<SessionComposerBar> {
  final Set<String> _loading = <String>{};
  String? _permissionError;

  /// Loads the catalog naming the chosen model, after this frame.
  ///
  /// Whether the catalog is needed is only known once the connection has been
  /// resolved in build, but mutating a provider from build is not allowed, so
  /// the load is handed to the next frame instead.
  void _scheduleModelLoad(String connectionId) {
    if (_loadedModels(connectionId) != null || !_loading.add(connectionId)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await _ensureModelsLoaded(connectionId);
      } finally {
        _loading.remove(connectionId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hostId = widget.hostId;
    final selection = widget.selection;
    final agentEnabled = widget.agentEnabled;
    final enabled = widget.enabled;
    // Keep the loaded connections while the provider refreshes. A provider
    // state that has not produced its first value is different from a loaded
    // empty connection list: only the latter can explain why model selection
    // is unavailable.
    final providersState = ref.watch(
      providerSettingsControllerProvider(hostId),
    );
    final providers = providersState.value;
    final providersResolved = providersState.hasValue && providers != null;
    final l10n = AppLocalizations.of(context);
    final connections = usableConnections(
      providers?.connections ?? const <ProviderConnectionDto>[],
    );
    final daemonDefault = ref
        .watch(permissionSettingsControllerProvider(hostId))
        .value
        ?.defaultMode;
    final hostDefaultPermission = daemonDefault ?? PermissionMode.ask;
    final connection = connections
        .where(
          (item) =>
              selection?.qualifiedModelId.startsWith('${item.modelPrefix}/') ??
              false,
        )
        .firstOrNull;
    final models =
        providers?.models[connection?.id] ?? const <ProviderModelDto>[];
    final model = models
        .where((item) => item.id == selection?.modelId)
        .firstOrNull;
    final modelLabel = model?.label;
    final hasRunnableModel =
        firstUsableModel(
          providers?.connections ?? const <ProviderConnectionDto>[],
          providers?.models ?? const <String, List<ProviderModelDto>>{},
        ) !=
        null;
    final modelBlocked = enabled && providersResolved && !hasRunnableModel;
    // The catalog decides which turn settings the chosen model can honour, so
    // an unsupported control is hidden rather than shown and ignored.
    final capabilities = model?.capabilities ?? const ModelCapabilitiesDto();
    // Labels come from the model catalog, so load it once per connection
    // instead of showing a raw model id.
    if (connection != null) _scheduleModelLoad(connection.id);
    if (widget.compact) {
      return TRIconButton(
        key: const ValueKey<String>('session-composer-settings'),
        appearance: TRAppearance.ghost,
        uiSize: TinestUiDensity.compactControlSize(context),
        onPressed: () => unawaited(_showSettings()),
        icon: const Icon(TinestIcons.settings),
        label: l10n.composerMoreSettings,
      );
    }
    final bar = ComposerChipBar(
      // These are settings under the prompt, not the prompt itself, so the row
      // takes the dense size the design system keeps for application chrome.
      children: <Widget>[
        TRTooltip(
          message: agentEnabled
              ? l10n.composerSelectAgent
              : l10n.composerAgentLocked,
          child: _agentSelect(
            key: const ValueKey<String>('session-composer-agent'),
            enabled: enabled && agentEnabled,
            blocked: !agentEnabled,
            blockedHint: l10n.composerAgentLocked,
            appearance: TRFieldAppearance.ghost,
            uiSize: TRUiSize.sm,
            stretch: false,
            onBlocked: () => ref
                .read(toastMessengerProvider)
                .info(
                  l10n.composerAgentLocked,
                  id: 'session-composer-agent-locked',
                ),
          ),
        ),
        _modelSelect(
          key: const ValueKey<String>('session-composer-model'),
          enabled: enabled && hasRunnableModel,
          blocked: modelBlocked,
          l10n: l10n,
          placeholder: modelLabel ?? selection?.modelId ?? l10n.composerModel,
          appearance: TRFieldAppearance.ghost,
          uiSize: TRUiSize.sm,
          stretch: false,
        ),
        for (final control in capabilities.controls)
          _controlChip(control, enabled),
        _permissionSelect(
          key: const ValueKey<String>('session-composer-permission'),
          enabled: enabled && widget.onPermissionModeChanged != null,
          hostDefaultPermission: hostDefaultPermission,
          appearance: TRFieldAppearance.ghost,
          uiSize: TRUiSize.sm,
          stretch: false,
        ),
      ],
    );
    final permissionError = _permissionError;
    if (permissionError == null) return bar;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TRAlert(
          key: const ValueKey<String>('session-composer-permission-error'),
          title: TRText.inherit(l10n.permissionChangeFailed),
          description: TRText.inherit(permissionError),
          icon: const Icon(TinestIcons.error),
          variant: TRStatusVariant.danger,
        ),
        bar,
      ],
    );
  }

  Widget _agentSelect({
    required Key key,
    required bool enabled,
    bool blocked = false,
    String? blockedHint,
    TRFieldAppearance appearance = TRFieldAppearance.solid,
    TRUiSize? uiSize,
    bool stretch = true,
    VoidCallback? onBlocked,
    VoidCallback? onValueChanged,
  }) {
    final l10n = AppLocalizations.of(context);
    final select = _sized(stretch, (width) {
      return TRSelect<String>.controlled(
        key: key,
        value: widget.agentDefinitionId,
        enabled: enabled,
        width: width,
        leading: Icon(blocked ? TinestIcons.lock : TinestIcons.agent),
        appearance: appearance,
        uiSize: uiSize,
        searchable: true,
        searchPlaceholder: l10n.selectSearchPlaceholder,
        noResultsText: l10n.selectNoResults,
        presentation: TinestSelectPresentation.resolve(context),
        items: <TRSelectItem<String>>[
          for (final definition in widget.definitions)
            TRSelectItem<String>(
              key: ValueKey<String>('session-composer-agent-${definition.id}'),
              value: definition.id,
              label: definition.name,
            ),
        ],
        onValueChange: (value) {
          if (value != null) {
            widget.onAgentChanged(value);
            onValueChanged?.call();
          }
        },
      );
    });
    if (!blocked || onBlocked == null) return select;
    return BlockedControl(
      label: l10n.composerAgent,
      hint: blockedHint ?? l10n.composerAgentLocked,
      onTap: onBlocked,
      child: select,
    );
  }

  Widget _modelSelect({
    required Key key,
    required bool enabled,
    required bool blocked,
    required AppLocalizations l10n,
    required String placeholder,
    TRFieldAppearance appearance = TRFieldAppearance.solid,
    TRUiSize? uiSize,
    bool stretch = true,
    VoidCallback? onValueChanged,
  }) {
    final select = _sized(stretch, (width) {
      return AsyncModelSelect(
        loadKey: widget.hostId,
        loadOptions: ref.read(modelPickerOptionsLoaderProvider(widget.hostId)),
        currentSelection: widget.selection,
        placeholder: placeholder,
        enabled: enabled,
        width: width,
        leading: Icon(blocked ? TinestIcons.lock : TinestIcons.memory),
        appearance: appearance,
        uiSize: uiSize,
        onValueChange: (option) async {
          await _setModelOption(option);
          onValueChanged?.call();
        },
      );
    });
    if (!blocked) return KeyedSubtree(key: key, child: select);
    return BlockedControl(
      key: key,
      label: placeholder,
      hint: l10n.composerConnectProviderFirst,
      onTap: () => _showProviderRequiredToast(l10n),
      child: select,
    );
  }

  Widget _permissionSelect({
    required Key key,
    required bool enabled,
    required PermissionMode hostDefaultPermission,
    required TRFieldAppearance appearance,
    required TRUiSize uiSize,
    bool stretch = true,
    VoidCallback? onValueChanged,
  }) {
    return _sized(stretch, (width) {
      return PermissionSelect(
        key: key,
        // A draft has not been given a mode yet, so it shows the one the new
        // session would be created with.
        currentMode: widget.permissionMode ?? hostDefaultPermission,
        enabled: enabled,
        width: width,
        leading: const Icon(TinestIcons.permission),
        appearance: appearance,
        uiSize: uiSize,
        onValueChange: (mode) =>
            unawaited(_setPermission(mode).then((_) => onValueChanged?.call())),
      );
    });
  }

  /// Builds a control that either fills its slot or keeps its own label width.
  ///
  /// A Select's `width` is exact rather than a maximum, so a bounded parent is
  /// not on its own a reason to fill it: the settings sheet wants one control
  /// width per row, while the composer toolbar wants each control to stay as
  /// wide as what it says.
  Widget _sized(bool stretch, Widget Function(double? width) build) => stretch
      ? LayoutBuilder(
          builder: (context, constraints) =>
              build(constraints.hasBoundedWidth ? constraints.maxWidth : null),
        )
      : build(null);

  Future<void> _setModelOption(ModelPickerOption option) async {
    final allowed = option.model.capabilities.controls
        .map((control) => control.id)
        .toSet();
    final retained = <String, ModelControlValueDto>{
      for (final entry in widget.modelControls.entries)
        if (allowed.contains(entry.key)) entry.key: entry.value,
    };
    await widget.onModelChanged(option.selection, retained);
  }

  Future<void> _setPermission(PermissionMode mode) async {
    if (mounted) setState(() => _permissionError = null);
    try {
      await widget.onPermissionModeChanged?.call(mode);
    } on Object catch (error) {
      if (mounted) setState(() => _permissionError = '$error');
    }
  }

  Future<void> _showSettings() => showTinestBottomSheet<void>(
    context: context,
    useRootNavigator: false,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, refresh) => Consumer(
        builder: (context, sheetRef, _) {
          final snapshot = _settingsSnapshot(sheetRef);
          final l10n = AppLocalizations.of(context);
          final agentLocked = !widget.agentEnabled;
          return TinestBottomSheet(
            key: const ValueKey<String>('session-composer-settings-sheet'),
            title: TRText.inherit(l10n.composerMoreSettings),
            content: ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                if (_permissionError case final error?)
                  TRAlert(
                    key: const ValueKey<String>(
                      'session-composer-permission-error',
                    ),
                    title: TRText.inherit(l10n.permissionChangeFailed),
                    description: TRText.inherit(error),
                    icon: const Icon(TinestIcons.error),
                    variant: TRStatusVariant.danger,
                  ),
                SettingsRow(
                  controlLayout: _sheetControlLayout,
                  key: const ValueKey<String>(
                    'session-composer-settings-agent',
                  ),
                  flush: true,
                  leading: const Icon(TinestIcons.agent),
                  title: TRText.inherit(
                    l10n.composerAgent,
                    color: agentLocked ? TRTextColor.muted : null,
                  ),
                  controlOwnsFocus: true,
                  enabled:
                      agentLocked ||
                      (widget.enabled && widget.definitions.isNotEmpty),
                  control: _agentSelect(
                    stretch: _sheetControlsStretch,
                    key: const ValueKey<String>(
                      'session-composer-settings-agent-select',
                    ),
                    enabled: widget.enabled && !agentLocked,
                    blocked: agentLocked,
                    blockedHint: l10n.composerAgentLocked,
                    onBlocked: () => ref
                        .read(toastMessengerProvider)
                        .info(
                          l10n.composerAgentLocked,
                          id: 'session-composer-agent-locked',
                        ),
                    onValueChanged: () => unawaited(_refreshSettings(refresh)),
                  ),
                ),
                SettingsRow(
                  controlLayout: _sheetControlLayout,
                  key: const ValueKey<String>(
                    'session-composer-settings-model',
                  ),
                  flush: true,
                  leading: const Icon(TinestIcons.memory),
                  title: TRText.inherit(
                    l10n.composerModel,
                    color:
                        widget.enabled &&
                            snapshot.providersResolved &&
                            !snapshot.hasRunnableModel
                        ? TRTextColor.muted
                        : null,
                  ),
                  controlOwnsFocus: true,
                  control: _modelSelect(
                    stretch: _sheetControlsStretch,
                    key: const ValueKey<String>(
                      'session-composer-settings-model-select',
                    ),
                    enabled: widget.enabled && snapshot.hasRunnableModel,
                    blocked:
                        widget.enabled &&
                        snapshot.providersResolved &&
                        !snapshot.hasRunnableModel,
                    l10n: l10n,
                    placeholder:
                        snapshot.model?.label ??
                        widget.selection?.modelId ??
                        l10n.composerModel,
                    onValueChanged: () => unawaited(_refreshSettings(refresh)),
                  ),
                ),
                for (final descriptor in snapshot.capabilities.controls)
                  _compactControl(descriptor, l10n, refresh),
                SettingsRow(
                  controlLayout: _sheetControlLayout,
                  key: const ValueKey<String>(
                    'session-composer-settings-permission',
                  ),
                  flush: true,
                  leading: const Icon(TinestIcons.permission),
                  title: TRText.inherit(l10n.composerPermissionMode),
                  controlOwnsFocus: true,
                  control: PermissionSelect(
                    key: const ValueKey<String>(
                      'session-composer-settings-permission-select',
                    ),
                    currentMode:
                        widget.permissionMode ?? snapshot.hostDefaultPermission,
                    enabled:
                        widget.enabled &&
                        widget.onPermissionModeChanged != null,
                    onValueChange: (mode) => unawaited(
                      _setPermission(mode)
                          .then((_) => _refreshSettings(refresh)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );

  Future<void> _refreshSettings(StateSetter refresh) async {
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) refresh(() {});
  }

  /// Where the settings sheet puts a value control.
  ///
  /// The sheet is a form, and on a phone it fills the window: a select that
  /// shares a line with its label there has nothing left to show its value in,
  /// so every control takes the full rail and they line up as one column. A
  /// wider window has room for the list reading instead.
  ///
  /// Settings pages deliberately have one shape at every width. This sheet is
  /// the exception, so it makes the call here rather than asking a settings
  /// row to carry a width rule on its behalf.
  SettingsControlLayout get _sheetControlLayout =>
      settingsAdaptiveWidthClassOf(context) == TRAdaptiveWidthClass.compact
      ? SettingsControlLayout.stacked
      : SettingsControlLayout.inline;

  /// Whether the sheet's value controls fill the width they are given.
  ///
  /// A control on its own line fills it, so the sheet reads as one column of
  /// equal fields. A control that shares a line with its label takes only the
  /// width its own value needs and leaves the rest of the line to the label.
  ///
  /// This is asked rather than inferred from whether some parent happened to
  /// bound the control: a maximum width is not an instruction to fill it, and
  /// reading one as the other made every value in the sheet grow to the row
  /// and squeeze its label down to nothing.
  bool get _sheetControlsStretch =>
      _sheetControlLayout == SettingsControlLayout.stacked;

  Widget _settingsRow({
    required ValueKey<String> key,
    required IconData icon,
    required String title,
    required String value,
    required bool enabled,
    required VoidCallback onTap,
    bool locked = false,
    String? lockedHint,
  }) {
    final row = TinestListRow(
      key: key,
      enabled: enabled,
      leading: Icon(icon),
      title: TRText.inherit(title, color: locked ? TRTextColor.muted : null),
      subtitle: TRText.inherit(value),
      trailing: Icon(
        locked ? TinestIcons.lock : TinestIcons.expand,
        color: locked ? context.tinyrackTheme.textMuted : null,
      ),
      onTap: onTap,
    );
    return lockedHint == null ? row : Semantics(hint: lockedHint, child: row);
  }

  ({
    AgentDefinitionDto? agent,
    List<ProviderConnectionDto> connections,
    bool providersResolved,
    bool hasRunnableModel,
    ProviderModelDto? model,
    ModelCapabilitiesDto capabilities,
    PermissionMode hostDefaultPermission,
  })
  _settingsSnapshot(WidgetRef settingsRef) {
    final providersState = settingsRef.watch(
      providerSettingsControllerProvider(widget.hostId),
    );
    final providers = providersState.value;
    final connections = usableConnections(
      providers?.connections ?? const <ProviderConnectionDto>[],
    );
    final agent = _selectedAgent;
    final daemonDefault = settingsRef
        .watch(permissionSettingsControllerProvider(widget.hostId))
        .value
        ?.defaultMode;
    final connection = connections
        .where(
          (item) =>
              widget.selection?.qualifiedModelId.startsWith(
                '${item.modelPrefix}/',
              ) ??
              false,
        )
        .firstOrNull;
    final model =
        (providers?.models[connection?.id] ?? const <ProviderModelDto>[])
            .where((item) => item.id == widget.selection?.modelId)
            .firstOrNull;
    return (
      agent: agent,
      connections: connections,
      providersResolved: providersState.hasValue && providers != null,
      hasRunnableModel:
          firstUsableModel(
            providers?.connections ?? const <ProviderConnectionDto>[],
            providers?.models ?? const <String, List<ProviderModelDto>>{},
          ) !=
          null,
      model: model,
      capabilities: model?.capabilities ?? const ModelCapabilitiesDto(),
      hostDefaultPermission: daemonDefault ?? PermissionMode.ask,
    );
  }

  Future<void> _chooseControlSheet(
    BuildContext context,
    ModelControlDescriptorDto descriptor,
  ) async {
    final current = widget.modelControls[descriptor.id];
    switch (descriptor.kind) {
      case ModelControlKind.choice:
        return;
      case ModelControlKind.toggle:
        _setControl(
          descriptor,
          current is ModelControlBoolValueDto && current.value
              ? null
              : const ModelControlValueDto.boolValue(value: true),
        );
      case ModelControlKind.integer:
        final chosen = await showTinestBottomSheet<_ComposerSheetChoice<int?>>(
          context: context,
          useRootNavigator: false,
          builder: (context) => _IntegerControlDrawer(
            descriptor: descriptor,
            initialValue: current is ModelControlIntValueDto
                ? current.value
                : null,
          ),
        );
        if (chosen == null) return;
        _setControl(
          descriptor,
          chosen.value == null
              ? null
              : ModelControlValueDto.intValue(value: chosen.value!),
        );
    }
  }

  Widget _choiceControlSelect(
    ModelControlDescriptorDto descriptor, {
    required bool enabled,
    required TRFieldAppearance appearance,
    TRUiSize? uiSize,
    Key? key,
    bool stretch = true,
    VoidCallback? onValueChanged,
  }) {
    final l10n = AppLocalizations.of(context);
    final current = widget.modelControls[descriptor.id];
    final selectedId = current is ModelControlStringValueDto
        ? current.value
        : null;
    return _sized(stretch, (width) {
      return TRSelect<String?>.controlled(
        key: key,
        value: selectedId,
        enabled: enabled,
        width: width,
        leading: Icon(_controlIcon(descriptor.id)),
        appearance: appearance,
        uiSize: uiSize,
        searchable: true,
        searchPlaceholder: l10n.selectSearchPlaceholder,
        noResultsText: l10n.selectNoResults,
        presentation: TinestSelectPresentation.resolve(context),
        items: <TRSelectItem<String?>>[
          TRSelectItem<String?>(
            key: ValueKey<String>(
              'session-composer-control-${descriptor.id}-default',
            ),
            value: null,
            label: l10n.composerUseDefault,
          ),
          for (final choice in descriptor.choices)
            TRSelectItem<String?>(
              key: ValueKey<String>(
                'session-composer-control-${descriptor.id}-${choice.id}',
              ),
              value: choice.id,
              label: choice.label,
            ),
        ],
        onValueChange: (value) {
          _setControl(
            descriptor,
            value == null
                ? null
                : ModelControlValueDto.stringValue(value: value),
          );
          onValueChanged?.call();
        },
      );
    });
  }

  Widget _compactControl(
    ModelControlDescriptorDto descriptor,
    AppLocalizations l10n,
    StateSetter refresh,
  ) {
    final enabled = widget.enabled && widget.onModelControlsChanged != null;
    if (descriptor.kind == ModelControlKind.choice) {
      return SettingsRow(
        controlLayout: _sheetControlLayout,
        key: ValueKey<String>(
          'session-composer-settings-control-${descriptor.id}',
        ),
        flush: true,
        leading: Icon(_controlIcon(descriptor.id)),
        title: TRText.inherit(descriptor.label),
        description: descriptor.description == null
            ? null
            : TRText.inherit(descriptor.description!),
        controlOwnsFocus: true,
        control: _choiceControlSelect(
          stretch: _sheetControlsStretch,
          descriptor,
          key: ValueKey<String>(
            'session-composer-settings-control-${descriptor.id}-select',
          ),
          enabled: enabled,
          appearance: TRFieldAppearance.solid,
          onValueChanged: () => unawaited(_refreshSettings(refresh)),
        ),
      );
    }
    return _settingsRow(
      key: ValueKey<String>(
        'session-composer-settings-control-${descriptor.id}',
      ),
      icon: _controlIcon(descriptor.id),
      title: descriptor.label,
      value: _controlValueLabel(l10n, descriptor),
      enabled: enabled,
      onTap: () => unawaited(
        _chooseControlSheet(
          context,
          descriptor,
        ).then((_) => _refreshSettings(refresh)),
      ),
    );
  }

  String _controlValueLabel(
    AppLocalizations l10n,
    ModelControlDescriptorDto descriptor,
  ) => switch (widget.modelControls[descriptor.id]) {
    ModelControlStringValueDto(:final value) =>
      descriptor.choices
              .where((choice) => choice.id == value)
              .firstOrNull
              ?.label ??
          value,
    ModelControlBoolValueDto(:final value) =>
      value ? l10n.composerEnabled : l10n.composerUseDefault,
    ModelControlIntValueDto(:final value) => '$value',
    _ => l10n.composerUseDefault,
  };

  Widget _controlChip(ModelControlDescriptorDto descriptor, bool enabled) {
    final value = widget.modelControls[descriptor.id];
    final canChange = enabled && widget.onModelControlsChanged != null;
    return switch (descriptor.kind) {
      ModelControlKind.choice => _choiceControlSelect(
        descriptor,
        key: ValueKey<String>('session-composer-control-${descriptor.id}'),
        enabled: canChange,
        appearance: TRFieldAppearance.ghost,
        uiSize: TRUiSize.sm,
        stretch: false,
      ),
      ModelControlKind.toggle => ComposerChip(
        valueKey: ValueKey('session-composer-control-${descriptor.id}'),
        icon: _controlIcon(descriptor.id),
        label: descriptor.label,
        tooltip: descriptor.description ?? descriptor.label,
        selected: value is ModelControlBoolValueDto && value.value,
        uiSize: TRUiSize.sm,
        onPressed: canChange
            ? (_) => _setControl(
                descriptor,
                value is ModelControlBoolValueDto && value.value
                    ? null
                    : const ModelControlValueDto.boolValue(value: true),
              )
            : null,
      ),
      ModelControlKind.integer => ComposerChip(
        valueKey: ValueKey('session-composer-control-${descriptor.id}'),
        icon: _controlIcon(descriptor.id),
        label: switch (value) {
          ModelControlIntValueDto(:final value) =>
            '${descriptor.label}: $value',
          _ => descriptor.label,
        },
        tooltip: descriptor.description ?? descriptor.label,
        uiSize: TRUiSize.sm,
        onPressed: canChange
            ? (chipContext) =>
                  unawaited(_chooseInteger(chipContext, descriptor, value))
            : null,
      ),
    };
  }

  IconData _controlIcon(String id) => switch (id) {
    'fast_mode' => TinestIcons.fast,
    'reasoning_effort' ||
    'reasoning_mode' ||
    'thinking_budget' => TinestIcons.reasoning,
    _ => TinestIcons.settings,
  };

  void _setControl(
    ModelControlDescriptorDto descriptor,
    ModelControlValueDto? value,
  ) {
    final updated = <String, ModelControlValueDto>{...widget.modelControls}
      ..remove(descriptor.id);
    descriptor.conflictsWith.forEach(updated.remove);
    if (value != null) updated[descriptor.id] = value;
    final callback = widget.onModelControlsChanged;
    if (callback != null) {
      unawaited(Future<void>.sync(() async => await callback(updated)));
    }
  }

  Future<void> _chooseInteger(
    BuildContext context,
    ModelControlDescriptorDto descriptor,
    ModelControlValueDto? current,
  ) async {
    final value = await showTRDialog<int>(
      context: context,
      builder: (context) => _IntegerControlDialog(
        descriptor: descriptor,
        initialValue: current is ModelControlIntValueDto ? current.value : null,
      ),
    );
    if (value == null || !mounted) return;
    _setControl(descriptor, ModelControlValueDto.intValue(value: value));
  }

  List<ProviderModelDto>? _loadedModels(String connectionId) => ref
      .read(providerSettingsControllerProvider(widget.hostId))
      .value
      ?.models[connectionId];

  Future<void> _ensureModelsLoaded(String connectionId) async {
    if (_loadedModels(connectionId) != null) return;
    await ref
        .read(providerSettingsControllerProvider(widget.hostId).notifier)
        .loadModels(connectionId);
  }

  void _showProviderRequiredToast(AppLocalizations l10n) {
    ref
        .read(toastMessengerProvider)
        .info(
          l10n.composerConnectProviderFirst,
          id: 'model-selector-provider-required',
        );
  }

  AgentDefinitionDto? get _selectedAgent => widget.definitions
      .where((definition) => definition.id == widget.agentDefinitionId)
      .firstOrNull;
}

@immutable
final class _ComposerSheetChoice<T> {
  const new(this.value);

  final T value;
}

class _IntegerControlDrawer extends StatefulWidget {
  const new({required this.descriptor, required this.initialValue});

  final ModelControlDescriptorDto descriptor;
  final int? initialValue;

  @override
  State<_IntegerControlDrawer> createState() => _IntegerControlDrawerState();
}

class _IntegerControlDrawerState extends State<_IntegerControlDrawer> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue?.toString() ?? '',
  );

  int? get _value => int.tryParse(_controller.text.trim());

  bool get _valid {
    final value = _value;
    if (value == null) return false;
    final descriptor = widget.descriptor;
    return (descriptor.minimum == null || value >= descriptor.minimum!) &&
        (descriptor.maximum == null || value <= descriptor.maximum!) &&
        (descriptor.step == null ||
            descriptor.minimum == null ||
            (value - descriptor.minimum!) % descriptor.step! == 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TinestBottomSheet(
      title: TRText.inherit(widget.descriptor.label),
      description: widget.descriptor.description == null
          ? null
          : TRText.inherit(widget.descriptor.description!),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TRSpacing.small,
        children: <Widget>[
          TinestListRow(
            key: ValueKey<String>(
              'session-composer-control-${widget.descriptor.id}-default-sheet',
            ),
            selected: widget.initialValue == null,
            title: TRText.inherit(l10n.composerUseDefault),
            trailing: widget.initialValue == null
                ? const Icon(TinestIcons.check)
                : null,
            onTap: () =>
                Navigator.pop(context, const _ComposerSheetChoice<int?>(null)),
          ),
          TRTextField(
            key: ValueKey<String>(
              'session-composer-control-${widget.descriptor.id}-integer',
            ),
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            label: widget.descriptor.label,
            errorText: _controller.text.isEmpty || _valid
                ? null
                : '${widget.descriptor.minimum ?? ''}'
                      '–${widget.descriptor.maximum ?? ''}',
          ),
        ],
      ),
      actions: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        spacing: TRSpacing.small,
        children: <Widget>[
          TRButton(
            appearance: TRAppearance.ghost,
            onPressed: () => Navigator.pop(context),
            child: TRText.inherit(l10n.commonCancel),
          ),
          TRButton(
            key: ValueKey<String>(
              'session-composer-control-${widget.descriptor.id}-save',
            ),
            intent: TRIntent.primary,
            onPressed: _valid
                ? () =>
                      Navigator.pop(context, _ComposerSheetChoice<int?>(_value))
                : null,
            child: TRText.inherit(l10n.commonSave),
          ),
        ],
      ),
    );
  }
}

class _IntegerControlDialog extends StatefulWidget {
  const new({required this.descriptor, required this.initialValue});

  final ModelControlDescriptorDto descriptor;
  final int? initialValue;

  @override
  State<_IntegerControlDialog> createState() => _IntegerControlDialogState();
}

class _IntegerControlDialogState extends State<_IntegerControlDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue?.toString() ?? '',
  );

  int? get _value => int.tryParse(_controller.text.trim());

  bool get _valid {
    final value = _value;
    if (value == null) return false;
    final descriptor = widget.descriptor;
    return (descriptor.minimum == null || value >= descriptor.minimum!) &&
        (descriptor.maximum == null || value <= descriptor.maximum!) &&
        (descriptor.step == null ||
            descriptor.minimum == null ||
            (value - descriptor.minimum!) % descriptor.step! == 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TRAlertDialog(
    title: TRText.inherit(widget.descriptor.label),
    description: widget.descriptor.description == null
        ? null
        : TRText.inherit(widget.descriptor.description!),
    content: TRTextField(
      controller: _controller,
      autofocus: true,
      keyboardType: TextInputType.number,
      onChanged: (_) => setState(() {}),
      label: widget.descriptor.label,
      errorText: _controller.text.isEmpty || _valid
          ? null
          : '${widget.descriptor.minimum ?? ''}'
                '–${widget.descriptor.maximum ?? ''}',
    ),
    actions: <TRButton>[
      TRButton(
        appearance: TRAppearance.ghost,
        onPressed: () => Navigator.pop(context),
        child: TRText.inherit(AppLocalizations.of(context).commonCancel),
      ),
      TRButton(
        intent: TRIntent.primary,
        onPressed: _valid ? () => Navigator.pop(context, _value) : null,
        child: TRText.inherit(AppLocalizations.of(context).commonSave),
      ),
    ],
  );
}

/// Labelled settings toolbar shown at standard application density.
class ComposerChipBar extends StatelessWidget {
  /// Creates a [ComposerChipBar].
  const new({required this.children, super.key});

  /// Typed controls shown in the composer settings row.
  final List<Widget> children;

  /// Widest a single setting may grow before its label truncates.
  ///
  /// Splitting the row evenly would give a one-word setting the same slot as a
  /// long model name, so each control keeps its own label width and only the
  /// labels past this cap are truncated.
  static const double controlMaxWidth = TRMeasurements.measureMd;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: TRSpacing.extraSmall,
    runSpacing: TRSpacing.extraSmall,
    children: <Widget>[
      for (final child in children)
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: controlMaxWidth),
          child: child,
        ),
    ],
  );
}

/// Labelled selector chip shared by the composers.
class ComposerChip extends StatelessWidget {
  /// Creates a composer chip.
  const new({
    required this.valueKey,
    required this.icon,
    required this.label,
    required this.tooltip,
    this.onPressed,
    this.locked = false,
    this.lockedHint,
    this.onLockedPressed,
    this.selected = false,
    this.uiSize = TRUiSize.md,
    super.key,
  });

  /// Stable key used by tests and by the enclosing row.
  final ValueKey<String> valueKey;

  /// Leading glyph.
  final IconData icon;

  /// Chip label.
  final String label;

  /// Hover and long-press description.
  final String tooltip;

  /// Tap handler receiving the chip's own context.
  final void Function(BuildContext chipContext)? onPressed;

  /// Whether the chip keeps its disabled appearance while explaining why it
  /// cannot be activated.
  final bool locked;

  /// Accessibility explanation for a locked chip.
  final String? lockedHint;

  /// Tap handler for a locked chip.
  final void Function(BuildContext chipContext)? onLockedPressed;

  /// Whether the chip renders as active.
  final bool selected;

  /// Control geometry the chip and the row around it share.
  final TRUiSize uiSize;

  @override
  Widget build(BuildContext context) {
    // The glyph never appears or disappears with selection: a chip that
    // changes width on toggle shifts every chip beside it.
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: TRSpacing.extraSmall,
      children: <Widget>[
        // Sized from the token the toolbar measures with, so a chip is exactly
        // as wide as the arithmetic that decided it fits.
        Icon(icon, size: TRControlMetrics.iconSizeOf(uiSize)),
        Flexible(child: TRText.inherit(label, truncate: true)),
      ],
    );
    // Every chip sits inside the composer card, so the toolbar reads as one
    // surface: flat until a chip is active, and never a second nested border.
    final control = TRButton(
      key: locked ? null : valueKey,
      appearance: selected ? TRAppearance.solid : TRAppearance.ghost,
      intent: selected ? TRIntent.primary : TRIntent.neutral,
      uiSize: uiSize,
      onPressed: locked
          ? null
          : onPressed == null
          ? null
          : () => onPressed!(context),
      child: content,
    );
    final interactiveLocked = locked && onLockedPressed != null;
    final wrapped = interactiveLocked
        ? BlockedControl(
            key: valueKey,
            label: label,
            hint: lockedHint ?? tooltip,
            onTap: () => onLockedPressed!(context),
            child: control,
          )
        : control;
    return TRTooltip(message: tooltip, child: wrapped);
  }
}

/// Composer shown when no session is selected; the first prompt creates one.
class DraftSessionPane extends ConsumerStatefulWidget {
  /// Creates a [DraftSessionPane].
  const new({
    required this.selection,
    required this.draftId,
    required this.onCreated,
    super.key,
  });

  /// Worktree the new session belongs to.
  final WorkspaceSelection selection;

  /// Stable identity that isolates this draft from drafts in other panes.
  final String draftId;

  /// Called after the session exists and its first turn has started.
  ///
  /// The starter has already promoted this draft tab; the callback only
  /// updates navigation to the resulting session.
  final ValueChanged<SessionDto> onCreated;

  @override
  ConsumerState<DraftSessionPane> createState() => _DraftSessionPaneState();
}

class _DraftSessionPaneState extends ConsumerState<DraftSessionPane> {
  final SessionComposerController _dropController = SessionComposerController();

  @override
  void dispose() {
    _dropController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selection = widget.selection;
    final agentsAsync = ref.watch(
      agentDefinitionsControllerProvider(selection.hostId),
    );
    final agents = agentsAsync.value;
    final agentsLoading = agentsAsync.isLoading && !agentsAsync.hasValue;
    final providersAsync = ref.watch(
      providerSettingsControllerProvider(selection.hostId),
    );
    final providers = providersAsync.value;
    final providersLoading =
        providersAsync.isLoading && !providersAsync.hasValue;
    final modelSettingsAsync = ref.watch(
      modelSettingsControllerProvider(selection.hostId),
    );
    final modelSettingsLoading =
        modelSettingsAsync.isLoading && !modelSettingsAsync.hasValue;
    final draft = ref.watch(
      sessionComposerDraftControllerProvider(
        selection.hostId,
        selection.worktreeId,
        widget.draftId,
      ),
    );
    final definitions = selectableAgentDefinitions(
      agents?.definitions ?? const <AgentDefinitionDto>[],
    );
    final agent =
        definitions
            .where((definition) => definition.id == draft.agentDefinitionId)
            .firstOrNull ??
        definitions.firstOrNull;
    final l10n = AppLocalizations.of(context);
    final connections =
        providers?.connections ?? const <ProviderConnectionDto>[];
    final effective =
        draft.model ??
        effectiveModelFor(
          definition: agent,
          connections: connections,
          models: providers?.models ?? const <String, List<ProviderModelDto>>{},
          defaultModel: modelSettingsAsync.value?.defaultModel,
        );
    final effectiveRunnable =
        effective != null &&
        isRunnableSelection(
          effective,
          connections,
          providers?.models ?? const <String, List<ProviderModelDto>>{},
        );
    final hasRunnableModel =
        firstUsableModel(
          connections,
          providers?.models ?? const <String, List<ProviderModelDto>>{},
        ) !=
        null;
    final notifier = ref.read(
      sessionComposerDraftControllerProvider(
        selection.hostId,
        selection.worktreeId,
        widget.draftId,
      ).notifier,
    );
    return ComposerDropPane(
      controller: _dropController,
      child: Column(
        children: <Widget>[
          Expanded(
            child: Center(child: TRText.inherit(l10n.composerStartHint)),
          ),
          ComposerCompletionScope(
            hostId: selection.hostId,
            workspaceId: selection.workspaceId,
            worktreeId: selection.worktreeId,
            excludedClientActions: sessionlessClientActions,
            builder: (context, completion) => SessionComposer(
              controller: _dropController,
              header: agent == null
                  ? null
                  : AgentPluginUiSlot(
                      hostId: selection.hostId,
                      agent: agent,
                      slot: PluginUiSlot.composerControl,
                      context: <String, dynamic>{
                        'workspaceId': selection.workspaceId,
                        'worktreeId': selection.worktreeId,
                        'draft': true,
                      },
                    ),
              commands: completion.commands,
              suggestions: completion.suggestions,
              onCompletionQueryChanged: completion.onQueryChanged,
              onClientCommand: (invocation) => runSessionlessClientCommand(
                context,
                invocation,
                hostId: selection.hostId,
              ),
              enabled: agent != null && effectiveRunnable,
              hint: (agentsLoading || providersLoading || modelSettingsLoading)
                  ? null
                  : (agent == null
                        ? l10n.composerNoPrimaryAgent
                        : (!effectiveRunnable
                              ? hasRunnableModel && effective != null
                                    ? l10n.modelSettingsUnavailableDescription(
                                        effective.modelId,
                                      )
                                    : l10n.composerConnectProviderFirst
                              : null)),
              bar: SessionComposerBar(
                hostId: selection.hostId,
                definitions: definitions,
                agentDefinitionId: agent?.id,
                selection: effective,
                onAgentChanged: notifier.selectAgent,
                onModelChanged: (selection, controls) {
                  notifier
                    ..selectModel(selection)
                    ..selectModelControls(controls);
                },
                modelControls: draft.modelControls,
                onModelControlsChanged: (controls) {
                  if (effective == null) return;
                  notifier
                    ..selectModel(effective)
                    ..selectModelControls(controls);
                },
                permissionMode: draft.permissionMode,
                onPermissionModeChanged: notifier.selectPermissionMode,
              ),
              attachmentInput: ref.read(attachmentInputProvider),
              onSubmit: (submission) => _start(ref, submission, agent!, draft),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _start(
    WidgetRef ref,
    ComposerSubmission submission,
    AgentDefinitionDto agent,
    SessionComposerDraft draft,
  ) async {
    final l10n = AppLocalizations.of(context);
    widget.onCreated(
      await startSessionWithPrompt(
        ref.read(sessionStarterProvider),
        selection: widget.selection,
        agentDefinitionId: agent.id,
        title: deriveSessionTitle(
          submission.text.isEmpty
              ? submission.attachments.first.fileName
              : submission.text,
          fallback: l10n.sessionDefaultTitle,
        ),
        prompt: submission.text,
        draftTabId: widget.draftId,
        attachments: submission.attachments,
        model: draft.model,
        modelControls: draft.modelControls,
        permissionMode: draft.permissionMode,
      ),
    );
  }
}

/// Connects a pane-owned drop target to the composer currently inside it.
class SessionComposerController extends ChangeNotifier {
  Object? _owner;
  bool _canAcceptDrop = false;
  bool _disposed = false;
  Future<void> Function(List<DropwellFile> files)? _onDrop;

  /// Whether the current composer can receive a native file drop.
  bool get canAcceptDrop => _canAcceptDrop;

  Future<void> _acceptDrop(List<DropwellFile> files) async {
    if (!_canAcceptDrop) return;
    await _onDrop?.call(files);
  }

  void _attach({
    required Object owner,
    required bool canAcceptDrop,
    required Future<void> Function(List<DropwellFile> files) onDrop,
  }) {
    if (_disposed) return;
    final changed = _owner != owner || _canAcceptDrop != canAcceptDrop;
    _owner = owner;
    _canAcceptDrop = canAcceptDrop;
    _onDrop = onDrop;
    if (changed) notifyListeners();
  }

  void _detach(Object owner) {
    if (_disposed) return;
    if (_owner != owner) return;
    _owner = null;
    _canAcceptDrop = false;
    _onDrop = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _owner = null;
    _canAcceptDrop = false;
    _onDrop = null;
    super.dispose();
  }
}

/// A whole-pane native drop target connected to its descendant composer.
class ComposerDropPane extends StatefulWidget {
  /// Creates a pane-wide composer drop target.
  const new({required this.controller, required this.child, super.key});

  /// Composer accepting files for this pane.
  final SessionComposerController controller;

  /// Complete pane covered by the drag-active overlay.
  final Widget child;

  @override
  State<ComposerDropPane> createState() => _ComposerDropPaneState();
}

class _ComposerDropPaneState extends State<ComposerDropPane> {
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleAvailabilityChanged);
  }

  @override
  void didUpdateWidget(ComposerDropPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_handleAvailabilityChanged);
    widget.controller.addListener(_handleAvailabilityChanged);
    _dragging = false;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleAvailabilityChanged);
    super.dispose();
  }

  void _handleAvailabilityChanged() {
    if (!mounted) return;
    setState(() {
      if (!widget.controller.canAcceptDrop) _dragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final overlay = TRDropOverlay(
      key: const ValueKey<String>('composer-drop-overlay'),
      visible: _dragging && widget.controller.canAcceptDrop,
      label: AppLocalizations.of(context).composerDropFilesHere,
      child: widget.child,
    );
    if (!widget.controller.canAcceptDrop) return overlay;
    return DropwellRegion(
      onHoverChanged: (hovering) => setState(() => _dragging = hovering),
      onDrop: (files) async {
        setState(() => _dragging = false);
        await widget.controller._acceptDrop(files);
      },
      child: overlay,
    );
  }
}

/// Chat input with the agent and model selectors above it.
class SessionComposer extends StatefulWidget {
  /// Creates a [SessionComposer].
  const new({
    required this.bar,
    required this.onSubmit,
    required this.enabled,
    this.busy = false,
    this.queued = const <QueuedTurn>[],
    this.onQueue,
    this.onQueuedEdit,
    this.onQueuedSendNow,
    this.onSubmitAndInterrupt,
    this.onStop,
    this.header,
    this.hint,
    this.failure,
    this.restoreSubmission,
    this.restoreKey,
    this.onRestoreConsumed,
    this.attachmentInput,
    this.contextTokens = 0,
    this.contextWindow,
    this.totalCostUsd,
    this.providerConnectionId,
    this.onLoadProviderUsage,
    this.commands = const <ComposerCommand>[],
    this.suggestions = ComposerSuggestionsState.closed,
    this.onCompletionQueryChanged,
    this.onClientCommand,
    this.controller,
    super.key,
  });

  /// Selector row rendered above the input.
  final SessionComposerBar bar;

  /// Tokens the last response reported for the live context window.
  final int contextTokens;

  /// Context window of the session's model; null hides the meter entirely
  /// rather than showing a percentage of a denominator nobody advertised.
  final int? contextWindow;

  /// Exact accumulated cost, or null when any usage could not be priced.
  final double? totalCostUsd;

  /// Connection currently supplying the effective model.
  final String? providerConnectionId;

  /// Lazy quota loader invoked only after the preview opens.
  final Future<List<ProviderUsageDto>> Function()? onLoadProviderUsage;

  /// Receives the trimmed prompt text.
  final FutureOr<void> Function(ComposerSubmission submission) onSubmit;

  /// Native input boundary; null disables picker, paste, and drop.
  final AttachmentInputPort? attachmentInput;

  /// Connects this composer to a pane-owned native drop target.
  final SessionComposerController? controller;

  /// Whether a turn is running, so a new prompt has to wait its turn.
  final bool busy;

  /// Prompts already waiting for the running turn, oldest first.
  final List<QueuedTurn> queued;

  /// Holds a prompt until the running turn settles.
  ///
  /// When null the composer sends even while [busy], which is what the draft
  /// and new-workspace composers do because they own no session yet.
  final void Function(ComposerSubmission submission)? onQueue;

  /// Takes a waiting prompt back out of the queue for editing.
  final QueuedTurn? Function(String id)? onQueuedEdit;

  /// Stops the running turn and starts a waiting prompt at once.
  final FutureOr<void> Function(String id)? onQueuedSendNow;

  /// Stops the running turn and sends the composed prompt at once.
  final FutureOr<void> Function(ComposerSubmission submission)?
  onSubmitAndInterrupt;

  /// Stops the running turn, keeping whatever it already produced.
  ///
  /// Null on a composer that owns no session, which is what the draft and
  /// new-workspace composers are.
  final FutureOr<void> Function()? onStop;

  /// Extra selectors rendered above [bar].
  final Widget? header;

  /// Whether the prompt can be typed and sent.
  ///
  /// This is about the session being usable at all, not about a turn being
  /// in flight: a running turn never stops the user from typing ahead.
  final bool enabled;

  /// Reason shown below the input when sending is unavailable.
  ///
  /// Guidance only. A failure that already happened goes to [failure]: mixing
  /// the two made "Select a project." and a daemon error look identical.
  final String? hint;

  /// Report of an operation that failed, rendered above [hint].
  final Widget? failure;

  /// Submission to restore after a pre-echo first-turn failure.
  ///
  /// The owning session pane supplies this once. Keeping restoration at the
  /// composer boundary preserves both text and local attachment streams.
  final ComposerSubmission? restoreSubmission;

  /// Stable identity for one external restoration request.
  final String? restoreKey;

  /// Called after [restoreSubmission] has been applied and focused.
  final VoidCallback? onRestoreConsumed;

  /// Rows offered for the token being completed; closed by default.
  final ComposerSuggestionsState suggestions;

  /// Reports the token under the caret so a host can search for it.
  final ValueChanged<ComposerTrigger?>? onCompletionQueryChanged;

  /// Runs an app-owned command, reporting whether it consumed the submission.
  ///
  /// A null handler leaves the message to submit as ordinary text, which is
  /// what a composer with no completion catalog wants.
  final Future<bool> Function(ComposerCommandInvocation invocation)?
  onClientCommand;

  /// Commands a whole-message `/name` submission is matched against.
  final List<ComposerCommand> commands;

  @override
  State<SessionComposer> createState() => _SessionComposerState();
}

class _SessionComposerState extends State<SessionComposer> {
  final _controller = TextEditingController();
  final _inputFocus = FocusNode();
  final TRInlineSuggestionsController<String> _suggestions =
      TRInlineSuggestionsController<String>();
  final List<PendingAttachment> _attachments = <PendingAttachment>[];
  bool _submitting = false;

  /// Mention the user dismissed, so Enter sends it as prose again.
  Object? _dismissedMention;
  bool _focused = false;
  String? _attachmentError;
  ComposerTrigger? _trigger;
  String? _restoredKey;

  /// Text for a failure the composer reports above the input.
  ///
  /// The app's own limits are localized; anything else keeps its own words,
  /// since only whoever raised it knows what it means.
  String _attachmentText(Object error) => switch (error) {
    AttachmentFailure(:final reason) => switch (reason) {
      AttachmentFailureReason.tooLarge => AppLocalizations.of(
        context,
      ).composerAttachmentTooLarge(maxPendingAttachmentBytes ~/ (1024 * 1024)),
      AttachmentFailureReason.tooMany => AppLocalizations.of(
        context,
      ).composerAttachmentTooMany(maxPendingAttachmentCount),
    },
    _ => '$error',
  };

  @override
  void initState() {
    super.initState();
    // Standalone text editing consumes Enter in its editing shortcuts before
    // an ancestor Focus sees it. Listen before focus-tree dispatch, but only
    // claim events while this composer's actual input node owns focus.
    FocusManager.instance.addEarlyKeyEventHandler(_handleEarlyKey);
    // A listener rather than onChanged: a completion splices the value
    // programmatically, and that has to re-evaluate the token too.
    _controller.addListener(_handleTextChanged);
    _scheduleDropBinding();
    _scheduleRestore();
  }

  @override
  void didUpdateWidget(SessionComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => oldWidget.controller?._detach(this),
      );
    }
    _scheduleDropBinding();
    if (oldWidget.restoreKey != widget.restoreKey) _scheduleRestore();
  }

  void _scheduleRestore() {
    final submission = widget.restoreSubmission;
    final key = widget.restoreKey;
    if (submission == null || key == null || key == _restoredKey) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.restoreKey != key) return;
      final current = widget.restoreSubmission;
      if (current == null) return;
      _controller.text = current.text;
      setState(() {
        _attachments
          ..clear()
          ..addAll(current.attachments);
        _attachmentError = null;
        _restoredKey = key;
      });
      _inputFocus.requestFocus();
      widget.onRestoreConsumed?.call();
    });
  }

  void _handleTextChanged() {
    final trigger = parseComposerTrigger(_controller.value);
    if (trigger == _trigger) return;
    setState(() => _trigger = trigger);
    widget.onCompletionQueryChanged?.call(trigger);
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_handleEarlyKey);
    final dropController = widget.controller;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => dropController?._detach(this),
    );
    _inputFocus.dispose();
    _controller
      ..removeListener(_handleTextChanged)
      ..dispose();
    _suggestions.dispose();
    super.dispose();
  }

  void _scheduleDropBinding() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final input = widget.attachmentInput;
      widget.controller?._attach(
        owner: this,
        canAcceptDrop:
            widget.enabled &&
            !_submitting &&
            input != null &&
            input.supportsDrop,
        onDrop: _receiveDrop,
      );
    });
  }

  Future<void> _receiveDrop(List<DropwellFile> files) async {
    final input = widget.attachmentInput;
    if (!mounted ||
        !widget.enabled ||
        _submitting ||
        input == null ||
        !input.supportsDrop) {
      return;
    }
    await _addFiles(input.droppedFiles(files));
  }

  /// Splices the chosen row over the token that asked for it.
  void _completeWith(ComposerSuggestion suggestion) {
    final trigger = _trigger;
    if (trigger == null) return;
    _controller.value = applyComposerCompletion(
      value: _controller.value,
      trigger: trigger,
      replacement: suggestion.replacement,
    );
    _inputFocus.requestFocus();
  }

  /// Runs an app-owned command instead of sending, if the text names one.
  Future<bool> _dispatchClientCommand() async {
    final handler = widget.onClientCommand;
    if (handler == null) return false;
    final invocation = parseComposerCommand(
      _controller.text.trim(),
      widget.commands,
    );
    if (invocation == null ||
        invocation.command.kind != ComposerCommandKind.client) {
      return false;
    }
    // A command replaces the whole submission, so an attachment has nowhere
    // to go and silently dropping it would lose the user's work.
    if (_attachments.isNotEmpty) {
      final l10n = AppLocalizations.of(context);
      setState(() => _attachmentError = l10n.composerCommandNoAttachments);
      return true;
    }
    _clear();
    return await handler(invocation);
  }

  /// The trailing action: stop a running turn, queue ahead of it, or send.
  ///
  /// Stopping is the default over a running turn because it is what an idle
  /// composer is for at that moment. Once something is typed the prompt itself
  /// becomes the intent, so the button goes back to queueing it — and keeps the
  /// send glyph, since from the keyboard's point of view that is still sending.
  Widget _buildPrimaryAction(
    AppLocalizations l10n,
    TextEditingValue value,
    bool queueing,
  ) {
    final composing = value.text.trim().isNotEmpty || _attachments.isNotEmpty;
    final onStop = widget.onStop;
    if (widget.busy && !composing && onStop != null) {
      return TRTooltip(
        message: l10n.commonStop,
        child: TRIconButton(
          key: const ValueKey('session-composer-stop'),
          uiSize: TinestUiDensity.compactControlSize(context),
          onPressed: () => unawaited(Future<void>.sync(onStop)),
          icon: const Icon(TinestIcons.stop),
          label: l10n.commonStop,
        ),
      );
    }
    return TRTooltip(
      message: queueing ? l10n.composerQueueTooltip : l10n.composerSendLabel,
      child: TRIconButton(
        key: const ValueKey('session-composer-send'),
        intent: TRIntent.primary,
        uiSize: TinestUiDensity.compactControlSize(context),
        loading: _submitting,
        onPressed: widget.enabled ? () => unawaited(_runDefaultAction()) : null,
        icon: const Icon(TinestIcons.send),
        label: queueing ? l10n.composerQueueLabel : l10n.composerSendLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _buildContent(
    context,
    compactSettings: TRUiDensityScope.of(context) == TRUiDensity.comfortable,
  );

  Widget _buildContent(BuildContext context, {required bool compactSettings}) {
    final l10n = AppLocalizations.of(context);
    // Attaching is about composing the next prompt, so it stays available
    // while a turn runs; only the upload of this prompt takes it away.
    final editable = widget.enabled && !_submitting;
    final queueing = widget.busy && widget.onQueue != null;
    final content = SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TRSpacing.medium,
          TRSpacing.small,
          TRSpacing.medium,
          TRSpacing.medium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: TRSpacing.small,
          children: <Widget>[
            if (widget.header != null) widget.header!,
            TRCard(
              // The card is the control: the prompt, its settings, and send
              // are one thing to the reader, so descendant focus is passed
              // through once. The design system decides whether that raw
              // focus should be visible for the current input modality.
              focused: _focused,
              padding: TinestUiDensity.compactCardPadding(context),
              child: Focus(
                canRequestFocus: false,
                skipTraversal: true,
                onFocusChange: (focused) => setState(() => _focused = focused),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  spacing: TRSpacing.small,
                  children: <Widget>[
                    for (
                      var index = 0;
                      index < widget.queued.length;
                      index += 1
                    )
                      _QueuedTurnRow(
                        slotKey: ValueKey<String>('queued-turn-$index'),
                        turn: widget.queued[index],
                        onEdit: widget.onQueuedEdit == null
                            ? null
                            : () => _editQueued(widget.queued[index].id),
                        onSendNow: widget.onQueuedSendNow == null
                            ? null
                            : () => _sendQueuedNow(widget.queued[index].id),
                      ),
                    ComposerSuggestionsOverlay(
                      state: widget.suggestions,
                      controller: _suggestions,
                      onSelected: _completeWith,
                      onDismissed: () {
                        // Remembered so Enter sends this token as prose. The
                        // key is the sigil position, so typing on into the
                        // same token stays dismissed while a new mention
                        // starts offering completion again.
                        _dismissedMention = parseComposerTrigger(
                          _controller.value,
                        )?.sessionKey;
                        widget.onCompletionQueryChanged?.call(null);
                      },
                      // Shift+Tab cycles the mode instead of moving focus,
                      // and Enter sends rather than opening a line.
                      child: TRTextField(
                        key: const ValueKey('session-composer-input'),
                        controller: _controller,
                        focusNode: _inputFocus,
                        appearance: TRFieldAppearance.plain,
                        minLines: 1,
                        maxLines: 8,
                        enabled: widget.enabled,
                        placeholder: l10n.composerInputHint,
                      ),
                    ),
                    if (_attachments.isNotEmpty)
                      Wrap(
                        spacing: TRSpacing.extraSmall,
                        runSpacing: TRSpacing.extraSmall,
                        children: <Widget>[
                          for (
                            var index = 0;
                            index < _attachments.length;
                            index += 1
                          )
                            _PendingAttachmentPill(
                              key: ValueKey('pending-attachment-$index'),
                              attachment: _attachments[index],
                              uploading: _submitting,
                              onRemove: _submitting
                                  ? null
                                  : () => setState(
                                      () => _attachments.removeAt(index),
                                    ),
                            ),
                        ],
                      ),
                    Row(
                      spacing: TRSpacing.small,
                      children: <Widget>[
                        TRIconButton(
                          key: const ValueKey('session-composer-attach'),
                          appearance: TRAppearance.ghost,
                          uiSize: TinestUiDensity.compactControlSize(context),
                          onPressed: editable && widget.attachmentInput != null
                              ? _pickFiles
                              : null,
                          icon: const Icon(TinestIcons.paperclip),
                          label: l10n.composerAttachLabel,
                        ),
                        Expanded(
                          child: compactSettings
                              ? const SizedBox.shrink()
                              : Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: widget.bar,
                                ),
                        ),
                        if (widget.contextWindow case final window?
                            when window > 0)
                          _ContextMeter(
                            used: widget.contextTokens,
                            window: window,
                            totalCostUsd: widget.totalCostUsd,
                            providerConnectionId: widget.providerConnectionId,
                            onLoadProviderUsage: widget.onLoadProviderUsage,
                          ),
                        if (compactSettings) widget.bar.asCompact(),
                        // Emptiness decides between stopping and queueing, and
                        // plain typing does not rebuild the composer.
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _controller,
                          builder: (context, value, _) =>
                              _buildPrimaryAction(l10n, value, queueing),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (widget.failure case final failure?) ...<Widget>[
              const SizedBox(height: TRSpacing.extraSmall),
              failure,
            ],
            if (widget.hint != null)
              TRText(
                widget.hint!,
                variant: TRTextVariant.bodySm,
                color: TRTextColor.danger,
              ),
            if (_attachmentError != null)
              TRText(
                _attachmentError!,
                key: const ValueKey('session-composer-attachment-error'),
                variant: TRTextVariant.bodySm,
                color: TRTextColor.danger,
              ),
          ],
        ),
      ),
    );
    return content;
  }

  /// Whether Enter sends rather than opening a new line.
  ///
  /// A touch keyboard has no comfortable Shift+Enter, and its Enter key is
  /// where people reach for a line break, so those platforms send by button.
  bool get _submitsOnEnter => switch (Theme.of(context).platform) {
    TargetPlatform.android || TargetPlatform.iOS => false,
    _ => true,
  };

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    // First, so an open list owns Enter, Escape, Tab, and the arrows before
    // sending, dismissing, or the mode toggle can see them.
    if (_suggestions.handleKeyEvent(event) == KeyEventResult.handled) {
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final control =
        pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);
    final shift =
        pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight);

    if (event.logicalKey == LogicalKeyboardKey.keyV && control) {
      final input = widget.attachmentInput;
      if (input != null) unawaited(_addFiles(input.pasteFiles()));
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      // A Korean or Japanese composition ends on the same Enter that would
      // otherwise send a half-written word.
      if (!_submitsOnEnter ||
          shift ||
          !widget.enabled ||
          _controller.value.composing.isValid) {
        return KeyEventResult.ignored;
      }
      // An unfinished `@` mention keeps Enter even when its list is not up
      // yet: the search is debounced and asynchronous, so the list can be
      // frames behind the keystroke that asked for it. Sending here would
      // fire the half-typed mention as prose and clear the field, losing the
      // prompt the user was still writing. The text is the signal rather than
      // the list, because the list is what flickers. Escape still hands the
      // token back to prose, and `/` is left alone; it dispatches on its own.
      final mention = parseComposerTrigger(_controller.value);
      if (mention != null &&
          mention.kind == ComposerTriggerKind.file &&
          mention.sessionKey != _dismissedMention) {
        return KeyEventResult.handled;
      }
      unawaited(control ? _runAlternateAction() : _runDefaultAction());
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _handleEarlyKey(KeyEvent event) => _inputFocus.hasFocus
      ? _handleKey(_inputFocus, event)
      : KeyEventResult.ignored;

  Future<void> _pickFiles() async {
    final input = widget.attachmentInput;
    if (input != null) await _addFiles(input.pickFiles());
  }

  Future<void> _addFiles(Future<List<PendingAttachment>> pending) async {
    try {
      final files = await pending;
      if (_attachments.length + files.length > maxPendingAttachmentCount) {
        throw const AttachmentFailure(AttachmentFailureReason.tooMany);
      }
      if (!mounted) return;
      setState(() {
        _attachmentError = null;
        _attachments.addAll(files);
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _attachmentError = _attachmentText(error));
    }
  }

  ComposerSubmission? _take() {
    final text = _controller.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return null;
    return ComposerSubmission(
      // The single place a skill or agent command becomes its prompt, so
      // every call site gets the expansion without repeating it.
      text: renderComposerPrompt(text, widget.commands),
      attachments: List<PendingAttachment>.unmodifiable(_attachments),
    );
  }

  /// Puts an unsent prompt back so a failure never loses what was typed.
  void _restore(ComposerSubmission submission) {
    _controller.text = submission.text;
    setState(() {
      _attachments
        ..clear()
        ..addAll(submission.attachments);
    });
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _attachments.clear();
      _attachmentError = null;
    });
  }

  /// Puts the caret back in the prompt after an action consumed the draft.
  ///
  /// The trailing action takes focus on pointer-down, so a mouse send would
  /// otherwise leave the caret on a button that clearing the draft is about to
  /// replace with Stop, disposing the focused node along with it. Requested
  /// unconditionally: on Android and iOS the button is the only send path, and
  /// a tap that dismisses the keyboard after every message is worse than one
  /// that keeps it. Guarded on [SessionComposer.enabled] only because a
  /// disabled field cannot hold focus at all.
  void _keepInputFocus() {
    if (widget.enabled) _inputFocus.requestFocus();
  }

  /// Sends, or holds the prompt for the running turn.
  Future<void> _runDefaultAction() async {
    // Ahead of the queue branch: an app-owned command acts on the app, so it
    // works while a turn runs and must never be held for one.
    if (await _dispatchClientCommand()) {
      _keepInputFocus();
      return;
    }
    final queue = widget.onQueue;
    if (widget.busy && queue != null) {
      final submission = _take();
      if (submission == null) return;
      _keepInputFocus();
      _clear();
      queue(submission);
      return;
    }
    await _submit(widget.onSubmit);
  }

  /// Sends past a running turn, stopping it first.
  Future<void> _runAlternateAction() async {
    final interrupt = widget.onSubmitAndInterrupt;
    if (widget.busy && interrupt != null) {
      await _submit(interrupt);
      return;
    }
    await _runDefaultAction();
  }

  Future<void> _submit(
    FutureOr<void> Function(ComposerSubmission submission) send,
  ) async {
    final submission = _take();
    if (submission == null) return;
    // Ahead of the await, not after it: an upload can hold this for seconds,
    // and a field that only wakes up once the daemon answers is the defect.
    // A failure below hands the prompt back, so the caret has to be there.
    _keepInputFocus();
    // Cleared before the upload starts: the prompt reads as sent, and a
    // failure puts it back rather than freezing it in the field.
    _clear();
    setState(() => _submitting = true);
    _scheduleDropBinding();
    try {
      await send(submission);
    } on Exception catch (error) {
      if (!mounted) return;
      _restore(submission);
      setState(() => _attachmentError = _attachmentText(error));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
        _scheduleDropBinding();
      }
    }
  }

  Future<void> _sendQueuedNow(String id) async {
    _keepInputFocus();
    try {
      await widget.onQueuedSendNow!(id);
    } on Exception catch (error) {
      if (mounted) setState(() => _attachmentError = _attachmentText(error));
    }
  }

  void _editQueued(String id) {
    final taken = widget.onQueuedEdit?.call(id);
    if (taken == null) return;
    _controller.text = taken.text;
    setState(() {
      _attachments
        ..clear()
        ..addAll(taken.attachments);
    });
    _inputFocus.requestFocus();
  }
}

/// One prompt waiting for the running turn, shown above the input.
/// How much of the model's context window the session has spent.
///
/// The number is the last response's own total, not a running sum, so it drops
/// back to zero whenever the agent starts a new window.
class _ContextMeter extends StatefulWidget {
  const new({
    required this.used,
    required this.window,
    this.totalCostUsd,
    this.providerConnectionId,
    this.onLoadProviderUsage,
  });

  /// Tokens reported for the live window.
  final int used;

  /// Size of the window; always greater than zero at this point.
  final int window;

  final double? totalCostUsd;
  final String? providerConnectionId;
  final Future<List<ProviderUsageDto>> Function()? onLoadProviderUsage;

  @override
  State<_ContextMeter> createState() => _ContextMeterState();
}

class _ContextMeterState extends State<_ContextMeter> {
  final FocusNode _triggerFocusNode = FocusNode(
    debugLabel: 'session-composer-context-trigger',
  );
  final TRPreviewCardController _previewController = TRPreviewCardController();
  Future<List<ProviderUsageDto>>? _usage;

  @override
  void initState() {
    super.initState();
    _triggerFocusNode.addListener(_handleTriggerFocus);
  }

  @override
  void dispose() {
    _triggerFocusNode
      ..removeListener(_handleTriggerFocus)
      ..dispose();
    _previewController.dispose();
    super.dispose();
  }

  void _handleOpen(bool open) {
    if (!open || _usage != null || widget.onLoadProviderUsage == null) return;
    final request = widget.onLoadProviderUsage!();
    setState(() {
      _usage = request;
    });
  }

  void _handleTriggerFocus() {
    if (_triggerFocusNode.hasFocus) _openPreview();
  }

  void _openPreview() {
    _handleOpen(true);
    _previewController.open();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rawPercent = (widget.used / widget.window) * 100;
    final percent = rawPercent.round().clamp(0, 100);
    final variant = switch (rawPercent) {
      > 90 => TRStatusVariant.danger,
      >= 70 => TRStatusVariant.warning,
      _ => TRStatusVariant.neutral,
    };
    return TRPreviewCard(
      controller: _previewController,
      placement: TRLayerPlacement.topEnd,
      onOpenChange: _handleOpen,
      trigger: TRIconButton(
        key: const ValueKey<String>('session-composer-context-trigger'),
        appearance: TRAppearance.ghost,
        focusNode: _triggerFocusNode,
        uiSize: TinestUiDensity.compactControlSize(context),
        label: l10n.sessionContextMeter,
        onPressed: _openPreview,
        icon: ExcludeSemantics(
          child: TRRadialMeter(
            key: const ValueKey<String>('session-composer-context-meter'),
            value: percent.toDouble(),
            semanticLabel: l10n.sessionContextMeter,
            variant: variant,
          ),
        ),
      ),
      content: _ContextUsageDetails(
        used: widget.used,
        window: widget.window,
        percent: percent,
        totalCostUsd: widget.totalCostUsd,
        providerConnectionId: widget.providerConnectionId,
        usage: _usage,
      ),
    );
  }
}

class _ContextUsageDetails extends StatelessWidget {
  const new({
    required this.used,
    required this.window,
    required this.percent,
    required this.totalCostUsd,
    required this.providerConnectionId,
    required this.usage,
  });

  final int used;
  final int window;
  final int percent;
  final double? totalCostUsd;
  final String? providerConnectionId;
  final Future<List<ProviderUsageDto>>? usage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TRSpacing.small,
      children: <Widget>[
        TRText(
          l10n.sessionContextDetailsTitle,
          variant: TRTextVariant.headingSm,
        ),
        TRText(l10n.sessionContextPercent(percent)),
        TRText(
          l10n.sessionContextTokens(
            _compactNumber(used),
            _compactNumber(window),
          ),
          variant: TRTextVariant.bodySm,
          color: TRTextColor.muted,
        ),
        if (totalCostUsd case final cost?)
          TRText(
            l10n.sessionContextCost(_formatUsd(cost)),
            variant: TRTextVariant.bodySm,
            color: TRTextColor.muted,
          ),
        if (usage case final request?)
          FutureBuilder<List<ProviderUsageDto>>(
            future: request,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return _ProviderUsageLoading(label: l10n.sessionQuotaLoading);
              }
              if (snapshot.hasError) {
                return _ProviderUsageMessage(label: l10n.sessionQuotaError);
              }
              final connectionId = providerConnectionId;
              final value = snapshot.data
                  ?.where((item) => item.connectionId == connectionId)
                  .firstOrNull;
              if (value == null ||
                  value.status == ProviderUsageStatus.unsupported) {
                return const SizedBox.shrink();
              }
              if (value.status == ProviderUsageStatus.error) {
                return _ProviderUsageMessage(label: l10n.sessionQuotaError);
              }
              return _ProviderUsageDetails(value: value);
            },
          ),
      ],
    );
  }
}

class _ProviderUsageLoading extends StatelessWidget {
  const new({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: TRSpacing.small,
    children: <Widget>[
      const TRSeparator(variant: TRSeparatorVariant.muted),
      TRProgress(label: label),
    ],
  );
}

class _ProviderUsageMessage extends StatelessWidget {
  const new({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: TRSpacing.small,
    children: <Widget>[
      const TRSeparator(variant: TRSeparatorVariant.muted),
      TRText(label, variant: TRTextVariant.bodySm, color: TRTextColor.muted),
    ],
  );
}

class _ProviderUsageDetails extends StatelessWidget {
  const new({required this.value});
  final ProviderUsageDto value;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TRSpacing.small,
      children: <Widget>[
        const TRSeparator(variant: TRSeparatorVariant.muted),
        TRText(
          value.plan == null
              ? value.provider
              : l10n.sessionQuotaProviderPlan(value.provider, value.plan!),
          variant: TRTextVariant.label,
          weight: TRTextWeight.strong,
        ),
        for (final quota in value.windows) ...<Widget>[
          TRText(_quotaLabel(l10n, quota.kind), variant: TRTextVariant.bodySm),
          TRProgress(
            value: quota.usedPercent,
            variant: quota.usedPercent > 90
                ? TRStatusVariant.danger
                : quota.usedPercent >= 70
                ? TRStatusVariant.warning
                : TRStatusVariant.neutral,
            label: l10n.sessionQuotaPercent(quota.usedPercent.round()),
          ),
          if (quota.resetsAt case final reset?)
            TRText(
              l10n.sessionQuotaResets(_formatReset(context, reset)),
              variant: TRTextVariant.caption,
              color: TRTextColor.muted,
            ),
        ],
        if (value.creditBalance case final balance?)
          TRText(
            l10n.sessionQuotaCredits(_formatUsd(balance)),
            variant: TRTextVariant.bodySm,
          ),
      ],
    );
  }
}

String _quotaLabel(AppLocalizations l10n, ProviderUsageWindowKind kind) =>
    switch (kind) {
      ProviderUsageWindowKind.session => l10n.sessionQuotaWindowSession,
      ProviderUsageWindowKind.weekly => l10n.sessionQuotaWindowWeekly,
      ProviderUsageWindowKind.codeReview => l10n.sessionQuotaWindowCodeReview,
    };

String _compactNumber(int value) {
  if (value >= 1000000) return '${_compactDecimal(value / 1000000)}M';
  if (value >= 1000) return '${_compactDecimal(value / 1000)}K';
  return '$value';
}

String _compactDecimal(double value) => value >= 10 || value == value.round()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

String _formatUsd(double value) =>
    '\$${value < 0.01 ? value.toStringAsFixed(4) : value.toStringAsFixed(2)}';

String _formatReset(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final material = MaterialLocalizations.of(context);
  return '${material.formatShortDate(local)} '
      '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

class _QueuedTurnRow extends StatelessWidget {
  const new({
    required this.slotKey,
    required this.turn,
    required this.onEdit,
    required this.onSendNow,
  }) : super(key: slotKey);

  /// Position-stable key the actions extend for their own keys.
  final ValueKey<String> slotKey;
  final QueuedTurn turn;
  final VoidCallback? onEdit;
  final VoidCallback? onSendNow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final queueIconSize = TRControlMetrics.iconSizeOf(
      TinestUiDensity.defaultControlSize(context),
    );
    return TRCard(
      padding: TinestUiDensity.compactCardPadding(context),
      variant: TRCardVariant.elevated,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: TRSpacing.extraSmall,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(
              top: chatFirstLineLeadingInset(
                context,
                leadingExtent: queueIconSize,
              ),
            ),
            child: Icon(TinestIcons.queue, size: queueIconSize),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: TRSpacing.extraSmall,
              children: <Widget>[
                Text(
                  turn.text.isEmpty
                      ? l10n.composerQueuedAttachments(turn.attachments.length)
                      : turn.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // A prompt that has stopped retrying looks exactly like one
                // waiting its turn, so the reason is what tells the reader
                // there is something to act on.
                if (turn.error case final error?)
                  TRText(
                    l10n.composerQueuedFailed(error),
                    key: ValueKey<String>('${slotKey.value}-error'),
                    variant: TRTextVariant.bodySm,
                    color: TRTextColor.danger,
                  ),
              ],
            ),
          ),
          TRTooltip(
            message: l10n.composerQueuedEdit,
            child: TRIconButton(
              key: ValueKey('${slotKey.value}-edit'),
              appearance: TRAppearance.ghost,
              onPressed: onEdit,
              icon: const Icon(TinestIcons.edit),
              label: l10n.composerQueuedEdit,
            ),
          ),
          TRTooltip(
            message: l10n.composerQueuedSendNow,
            child: TRIconButton(
              key: ValueKey('${slotKey.value}-send'),
              appearance: TRAppearance.ghost,
              onPressed: onSendNow,
              icon: const Icon(TinestIcons.send),
              label: l10n.composerQueuedSendNow,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingAttachmentPill extends StatelessWidget {
  const new({
    required this.attachment,
    required this.uploading,
    required this.onRemove,
    super.key,
  });

  final PendingAttachment attachment;
  final bool uploading;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: TRMeasurements.measureMd),
      child: TRCard(
        padding: TinestUiDensity.compactCardPadding(context),
        variant: TRCardVariant.elevated,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: TRSpacing.extraSmall,
          children: <Widget>[
            if (uploading)
              const TRSpinner()
            else
              _PendingAttachmentPreview(attachment: attachment),
            Flexible(
              child: TRText.inherit(
                '${attachment.fileName} · ${_formatBytes(attachment.byteSize)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TRIconButton(
              key: ValueKey('remove-${attachment.fileName}'),
              appearance: TRAppearance.ghost,
              onPressed: onRemove,
              icon: const Icon(TinestIcons.close),
              label: l10n.composerRemoveAttachment(attachment.fileName),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingAttachmentPreview extends StatefulWidget {
  const new({required this.attachment});

  final PendingAttachment attachment;

  @override
  State<_PendingAttachmentPreview> createState() =>
      _PendingAttachmentPreviewState();
}

class _PendingAttachmentPreviewState extends State<_PendingAttachmentPreview> {
  Future<Uint8List>? _bytes;

  @override
  void initState() {
    super.initState();
    if (widget.attachment.isImage) _bytes = _read();
  }

  Future<Uint8List> _read() async {
    final builder = BytesBuilder(copy: false);
    await widget.attachment.openRead().forEach(builder.add);
    return builder.takeBytes();
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) return const Icon(TinestIcons.file);
    return FutureBuilder<Uint8List>(
      future: bytes,
      builder: (context, snapshot) => snapshot.hasData
          ? ClipRRect(
              borderRadius: const BorderRadius.all(TRRadii.extraSmall),
              child: Image.memory(
                snapshot.data!,
                // The thumbnail matches the icon it replaces, so a loaded
                // preview never reflows the pill.
                width: IconTheme.of(context).size,
                height: IconTheme.of(context).size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(TinestIcons.image),
              ),
            )
          : const TRSpinner(),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
