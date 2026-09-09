import 'dart:async';

import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/app/platform/external_url_opener.dart';
import 'package:app/src/features/providers/application/provider_settings_controller.dart';
import 'package:app/src/shared/presentation/settings_layout.dart';
import 'package:app/src/shared/presentation/tinest_icons.dart';
import 'package:app/src/shared/presentation/tinest_layout_metrics.dart';
import 'package:app/src/shared/presentation/tinest_select_presentation.dart';
import 'package:app/src/shared/presentation/tinest_selection_row.dart';
import 'package:app/src/shared/presentation/toast_messenger.dart';
import 'package:client/client.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Provider connection settings for one daemon host.
class SettingsPage extends StatelessWidget {
  /// Creates a provider connection settings page.
  const new({
    required this.hostId,
    required this.paneController,
    required this.slot,
    super.key,
  });

  /// Route host identifier.
  final String hostId;

  /// Selection shared by the collection and detail scaffold slots.
  final ProviderSettingsPaneController paneController;

  /// Which scaffold slot this widget supplies.
  final SettingsPaneSlot slot;

  @override
  Widget build(BuildContext context) => _ProviderSettingsSlot(
    hostId: hostId,
    paneController: paneController,
    slot: slot,
  );
}

class _ProviderSettingsSlot extends ConsumerWidget {
  const new({
    required this.hostId,
    required this.paneController,
    required this.slot,
  });

  final String hostId;
  final ProviderSettingsPaneController paneController;
  final SettingsPaneSlot slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = providerSettingsControllerProvider(hostId);
    final state = ref.watch(provider);
    return ListenableBuilder(
      listenable: paneController,
      builder: (context, _) => SettingsAsyncContent<ProviderSettingsState?>(
        state: state,
        loading: settingsPaneSkeleton(
          slot,
          semanticLabel: l10n.settingsLoading,
        ),
        error: (error, _) => slot == SettingsPaneSlot.collection
            ? SettingsCollectionErrorState(
                key: const ValueKey<String>('provider-settings-error'),
                title: l10n.providerSettingsConnected,
                error: error,
                onRetry: () => ref.invalidate(provider),
              )
            : SettingsEmptyState(
                title: l10n.providerSettingsSelectConnection,
                icon: const Icon(TinestIcons.network),
              ),
        data: (state) => state == null
            ? SettingsEmptyState(
                title: slot == SettingsPaneSlot.collection
                    ? l10n.providerSettingsRequiresDaemon
                    : l10n.providerSettingsSelectConnection,
                icon: Icon(
                  slot == SettingsPaneSlot.collection
                      ? TinestIcons.daemon
                      : TinestIcons.network,
                ),
              )
            : _body(context, ref, state),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    ProviderSettingsState state,
  ) {
    final widthClass = settingsAdaptiveWidthClassOf(context);
    final showsSplit =
        widthClass == TRAdaptiveWidthClass.large ||
        widthClass == TRAdaptiveWidthClass.extraLarge;
    if (slot == SettingsPaneSlot.collection &&
        !paneController.hasDetail &&
        showsSplit &&
        paneController.canAutoSelect &&
        state.connections.isNotEmpty) {
      _scheduleInitialSelection(state.connections.first.id);
    }
    final selectedId = paneController.selectedId;
    final selected = state.connections
        .where((connection) => connection.id == selectedId)
        .firstOrNull;
    if (selectedId != null && selected == null) {
      _scheduleCollection(context, ref, selectedId);
    }
    if (slot == SettingsPaneSlot.collection) {
      return _ProviderCollection(
        connections: state.connections,
        selectedId: selectedId,
        onSelected: paneController.selectConnectionId,
        onAdd: paneController.showCatalog,
      );
    }
    // The destination comes from the page rather than the stack's innermost
    // entry, so a route leaving keeps rendering itself for its whole exit.
    return switch (SettingsDetailScope.maybeOf(context)) {
      _CatalogDestination() => _ProviderCatalogPane(
        hostId: hostId,
        state: state,
        onPreset: paneController.showPreset,
        onCustom: paneController.showCustom,
      ),
      _PresetDestination(:final definition, :final reauthConnectionId) =>
        _PresetProviderPane(
          key: ValueKey<String>('provider-preset-${definition.id}'),
          hostId: hostId,
          state: state,
          definition: definition,
          existing: state.connections
              .where((connection) => connection.id == reauthConnectionId)
              .firstOrNull,
          onCancel: paneController.popDetail,
          onConnected: paneController.selectConnection,
        ),
      _CustomDestination() => _CustomProviderPane(
        hostId: hostId,
        state: state,
        onCancel: paneController.popDetail,
        onSaved: paneController.selectConnection,
      ),
      // A connection can disappear while its detail is open, and the schedule
      // above returns to the collection on the next frame.
      _ConnectionDestination() when selected != null =>
        selected.customConfig == null
            ? _ProviderConnectionPane(
                key: ValueKey<String>('provider-detail-${selected.id}'),
                hostId: hostId,
                state: state,
                connection: selected,
                onChanged: paneController.selectConnection,
                onRemoved: paneController.showCollection,
                onReauth: (definition) => paneController.showReauthentication(
                  selected.id,
                  definition,
                ),
              )
            : _CustomProviderPane(
                key: ValueKey<String>('provider-detail-${selected.id}'),
                hostId: hostId,
                state: state,
                existing: selected,
                onCancel: paneController.showCollection,
                onSaved: paneController.selectConnection,
                onRemoved: paneController.showCollection,
              ),
      _ => SettingsEmptyState(
        title: AppLocalizations.of(context).providerSettingsSelectConnection,
        icon: const Icon(TinestIcons.network),
      ),
    };
  }

  void _scheduleInitialSelection(String connectionId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      paneController.selectInitialConnectionId(connectionId);
    });
  }

  void _scheduleCollection(
    BuildContext context,
    WidgetRef ref,
    String selectedId,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted || paneController.selectedId != selectedId) {
        return;
      }
      final latest = ref.read(providerSettingsControllerProvider(hostId)).value;
      final stillExists =
          latest?.connections.any(
            (connection) => connection.id == selectedId,
          ) ??
          false;
      if (!stillExists) paneController.showCollection();
    });
  }
}

/// One destination stacked above the Provider collection.
///
/// Identity is deliberately narrower than the payload. A catalog refresh
/// rebuilds its definitions, and keying an open form on the whole record would
/// swap the route out from under whoever is typing into it.
@immutable
sealed class _ProviderDestination {
  const new();
}

final class _CatalogDestination extends _ProviderDestination {
  const new();

  @override
  bool operator ==(Object other) => other is _CatalogDestination;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class _PresetDestination extends _ProviderDestination {
  const new({required this.definition, this.reauthConnectionId});

  final ProviderDefinitionDto definition;

  /// Connection being retried, when the preset flow is a reauthentication.
  final String? reauthConnectionId;

  @override
  bool operator ==(Object other) =>
      other is _PresetDestination &&
      other.definition.id == definition.id &&
      other.reauthConnectionId == reauthConnectionId;

  @override
  int get hashCode => Object.hash(definition.id, reauthConnectionId);
}

final class _CustomDestination extends _ProviderDestination {
  const new();

  @override
  bool operator ==(Object other) => other is _CustomDestination;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class _ConnectionDestination extends _ProviderDestination {
  const new(this.connectionId);

  final String connectionId;

  @override
  bool operator ==(Object other) =>
      other is _ConnectionDestination && other.connectionId == connectionId;

  @override
  int get hashCode => connectionId.hashCode;
}

/// Owns the Provider detail stack independently from either rendered slot.
///
/// The catalog and the form it opens are two levels rather than two values of
/// one level, so cancelling the form pops back onto the catalog route it was
/// pushed over instead of replacing it.
class ProviderSettingsPaneController extends SettingsPaneCoordinatorBase {
  final List<_ProviderDestination> _stack = <_ProviderDestination>[];

  /// Connection the collection highlights, when one is the base destination.
  ///
  /// A reauthentication form sits above its connection, which stays selected
  /// underneath it.
  String? get selectedId => switch (_stack.firstOrNull) {
    _ConnectionDestination(:final connectionId) => connectionId,
    _ => null,
  };

  @override
  List<Object> get detailStack => List<Object>.unmodifiable(_stack);

  /// Shows the first connection on initial desktop entry.
  void selectInitialConnectionId(String id) {
    if (!consumeInitialSelection()) return;
    _replace(_ConnectionDestination(id));
  }

  /// Shows an existing provider connection.
  void selectConnection(ProviderConnectionDto connection) =>
      selectConnectionId(connection.id);

  /// Shows an existing provider connection by ID.
  void selectConnectionId(String id) {
    consumeExplicitNavigation();
    _replace(_ConnectionDestination(id));
  }

  /// Shows the provider catalog.
  void showCatalog() {
    consumeExplicitNavigation();
    _replace(const _CatalogDestination());
  }

  /// Opens the connection flow for a catalog definition over the catalog.
  void showPreset(ProviderDefinitionDto definition) {
    consumeExplicitNavigation();
    _push(_PresetDestination(definition: definition));
  }

  /// Opens the preset flow over the connection being retried.
  void showReauthentication(
    String connectionId,
    ProviderDefinitionDto definition,
  ) {
    consumeExplicitNavigation();
    _push(
      _PresetDestination(
        definition: definition,
        reauthConnectionId: connectionId,
      ),
    );
  }

  /// Opens the custom provider creator over the catalog.
  void showCustom() {
    consumeExplicitNavigation();
    _push(const _CustomDestination());
  }

  @override
  void popDetail() {
    consumeExplicitNavigation();
    if (_stack.isEmpty) return;
    _stack.removeLast();
    notifyListeners();
  }

  @override
  void removeDetail(Object destination) {
    final index = _stack.indexWhere((entry) => entry == destination);
    if (index < 0) return;
    consumeExplicitNavigation();
    _stack.removeRange(index, _stack.length);
    notifyListeners();
  }

  @override
  void showCollection() {
    consumeExplicitNavigation();
    if (_stack.isEmpty) return;
    _stack.clear();
    notifyListeners();
  }

  @override
  void reset() {
    final hadDetail = _stack.isNotEmpty;
    resetInitialSelection();
    _stack.clear();
    if (hadDetail) notifyListeners();
  }

  void _push(_ProviderDestination destination) {
    if (_stack.lastOrNull == destination) return;
    _stack.add(destination);
    notifyListeners();
  }

  /// Makes [destination] the only level, which is how the collection offers
  /// its own destinations: a connection and the catalog are siblings.
  void _replace(_ProviderDestination destination) {
    if (_stack.length == 1 && _stack.single == destination) return;
    _stack
      ..clear()
      ..add(destination);
    notifyListeners();
  }
}

class _ProviderCollection extends StatelessWidget {
  const new({
    required this.connections,
    required this.selectedId,
    required this.onSelected,
    required this.onAdd,
  });

  final List<ProviderConnectionDto> connections;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsDestinationScaffold(
      // The collection names its category, matching every other list-detail
      // settings destination, so the compact header reads as one stack level.
      title: TRText.inherit(l10n.settingsCategoryProvider),
      actions: <TRIconButton>[
        TRIconButton(
          key: const ValueKey<String>('provider-add-button'),
          appearance: TRAppearance.ghost,
          label: l10n.providerSettingsAdd,
          onPressed: onAdd,
          icon: const Icon(TinestIcons.add),
        ),
      ],
      child: connections.isEmpty
          ? SettingsEmptyState(
              key: const ValueKey<String>('provider-list-empty'),
              title: l10n.providerSettingsNoConnections,
              icon: const Icon(TinestIcons.network),
            )
          : SettingsCollectionList(
              children: <Widget>[
                TRTreeNav<String>.controlled(
                  value: selectedId,
                  itemSpacing: TRSpacing.extraSmall,
                  onValueChange: (connectionId) {
                    if (connectionId != null) onSelected(connectionId);
                  },
                  items: <TRTreeNavItem<String>>[
                    for (final connection in connections)
                      TRTreeNavLeaf<String>(
                        key: ValueKey<String>(
                          'provider-connection-${connection.id}',
                        ),
                        value: connection.id,
                        showDisclosureIndicator: true,
                        leading: Icon(_statusIcon(connection.status)),
                        label: TRText.inherit(connection.displayName),
                        description: TRText.inherit(
                          '${connection.modelPrefix} · '
                          '${_statusLabel(l10n, connection.status)}',
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _ProviderCatalogPane extends ConsumerStatefulWidget {
  const new({
    required this.hostId,
    required this.state,
    required this.onPreset,
    required this.onCustom,
  });

  final ProviderSettingsState state;
  final String hostId;
  final ValueChanged<ProviderDefinitionDto> onPreset;
  final VoidCallback onCustom;

  @override
  ConsumerState<_ProviderCatalogPane> createState() =>
      _ProviderCatalogPaneState();
}

class _ProviderCatalogPaneState extends ConsumerState<_ProviderCatalogPane> {
  bool _refreshing = false;
  Object? _error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalog = widget.state.catalog;
    return SettingsDestinationScaffold(
      title: TRText.inherit(l10n.providerSettingsAdd),
      contentMaxWidth: TinestLayoutMetrics.settingsContentMaxWidth,
      // Refreshing the catalog is destination-scoped, idempotent, and has an
      // unambiguous glyph, so it is one of the few commands that belongs in
      // the header rather than in the body.
      actions: <TRIconButton>[
        TRIconButton(
          key: const ValueKey<String>('provider-catalog-refresh'),
          appearance: TRAppearance.ghost,
          label: l10n.providerSettingsRefreshCatalog,
          loading: _refreshing,
          onPressed: _refreshing ? null : _refresh,
          icon: const Icon(TinestIcons.refresh),
        ),
      ],
      child: SettingsScaffold(
        children: <Widget>[
          SettingsSection(
            title: l10n.providerSettingsCatalogStatus,
            banner: _error == null && catalog.refreshError == null
                ? null
                : TRAlert(
                    variant: TRStatusVariant.danger,
                    title: TRText.inherit(l10n.providerSettingsRefreshFailed),
                    description: TRText.inherit(
                      '${_error ?? catalog.refreshError}',
                    ),
                  ),
            children: <Widget>[
              SettingsRow(
                title: TRText.inherit(_catalogLabel(l10n, catalog.freshness)),
              ),
              for (final definition in catalog.definitions)
                TRNavigationRow(
                  key: ValueKey<String>('provider-add-${definition.id}'),
                  leading: const Icon(TinestIcons.network),
                  label: TRText.inherit(definition.name),
                  description: TRText.inherit(definition.description),
                  onPressed: () => widget.onPreset(definition),
                ),
              TRNavigationRow(
                key: const ValueKey<String>('provider-add-custom'),
                leading: const Icon(TinestIcons.tune),
                label: TRText.inherit(l10n.providerSettingsCustomName),
                description: TRText.inherit(
                  l10n.providerSettingsCustomSubtitle,
                ),
                onPressed: widget.onCustom,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      await ref
          .read(providerSettingsControllerProvider(widget.hostId).notifier)
          .refreshCatalog();
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }
}

class _PresetProviderPane extends ConsumerStatefulWidget {
  const new({
    required this.hostId,
    required this.state,
    required this.definition,
    required this.onCancel,
    required this.onConnected,
    this.existing,
    super.key,
  });

  final String hostId;
  final ProviderSettingsState state;
  final ProviderDefinitionDto definition;
  final ProviderConnectionDto? existing;
  final VoidCallback onCancel;
  final ValueChanged<ProviderConnectionDto> onConnected;

  @override
  ConsumerState<_PresetProviderPane> createState() =>
      _PresetProviderPaneState();
}

class _PresetProviderPaneState extends ConsumerState<_PresetProviderPane> {
  late final TextEditingController _prefix;
  final TextEditingController _apiKey = TextEditingController();
  late ProviderAuthMethodDto _method;
  bool _busy = false;
  Object? _error;
  String? _attemptId;
  String? _connectedAttemptId;
  String? _retryConnectionId;
  Object? _openError;
  final Set<String> _rejectedPrefixes = <String>{};

  @override
  void initState() {
    super.initState();
    _prefix = TextEditingController(
      text: widget.existing?.modelPrefix ?? _suggestPrefix(),
    );
    _method = _initialMethod();
  }

  @override
  void dispose() {
    _prefix.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attempt = widget.state.authAttempts[_attemptId];
    if (attempt != null &&
        attempt.status == ProviderAuthAttemptStatus.succeeded &&
        _connectedAttemptId != attempt.id) {
      final connection = widget.state.connections
          .where((item) => item.id == attempt.connectionId)
          .firstOrNull;
      if (connection != null) {
        // Once per authorization, not once per build. The connection arrives
        // a frame or more after the daemon reports it, so every rebuilt frame
        // in between used to queue another hand-off.
        _connectedAttemptId = attempt.id;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // This pane keeps painting through its exit transition, so by the
          // time the hand-off runs the user may already have chosen somewhere
          // else to be. Only the destination still on top may redirect
          // navigation; otherwise finishing here undoes their choice.
          if (!mounted) return;
          if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
          widget.onConnected(connection);
        });
      }
    }
    if (attempt != null) return _oauthPane(attempt);
    final l10n = AppLocalizations.of(context);
    return SettingsDestinationScaffold(
      title: TRText.inherit(
        widget.existing == null
            ? l10n.providerSettingsConnectTitle(widget.definition.name)
            : widget.definition.name,
      ),
      contentMaxWidth: TinestLayoutMetrics.settingsContentMaxWidth,
      formActions: <Widget>[
        TRButton(
          appearance: TRAppearance.ghost,
          onPressed: _busy ? null : widget.onCancel,
          child: TRText.inherit(l10n.commonCancel),
        ),
        TRButton(
          key: const ValueKey<String>('provider-connect-submit'),
          intent: TRIntent.primary,
          onPressed: _canSubmit ? _submit : null,
          child: TRText.inherit(l10n.providerSettingsConnect),
        ),
      ],
      child: SettingsScaffold(
        children: <Widget>[
          SettingsSection.form(
            title: l10n.providerSettingsAuthTitle(widget.definition.name),
            description: widget.definition.description,
            children: <Widget>[
              TRTextField(
                key: const ValueKey<String>('provider-model-prefix'),
                controller: _prefix,
                enabled: !_busy,
                label: l10n.providerSettingsModelPrefix,
                helperText: l10n.providerSettingsModelPrefixHelp,
                errorText: _prefixError(l10n),
                onChanged: (_) => setState(() => _error = null),
              ),
              if (widget.definition.authMethods.length > 1)
                TRSelectFormField<String>(
                  key: const ValueKey<String>('provider-auth-method'),
                  initialValue: _method.id,
                  searchable: true,
                  searchPlaceholder: l10n.selectSearchPlaceholder,
                  noResultsText: l10n.selectNoResults,
                  presentation: TinestSelectPresentation.resolve(context),
                  label: l10n.providerSettingsActions,
                  width: TinestLayoutMetrics.settingsContentMaxWidth,
                  items: <TRSelectItem<String>>[
                    for (final method in widget.definition.authMethods)
                      TRSelectItem<String>(
                        key: ValueKey<String>(
                          'provider-auth-method-${method.id}',
                        ),
                        value: method.id,
                        label: method.label,
                      ),
                  ],
                  onValueChange: _busy
                      ? null
                      : (id) => setState(() {
                          _method = widget.definition.authMethods.singleWhere(
                            (method) => method.id == id,
                          );
                          _error = null;
                        }),
                ),
              if (_method.flow == ProviderAuthFlow.apiKey)
                TRTextField(
                  key: const ValueKey<String>('provider-api-key'),
                  controller: _apiKey,
                  enabled: !_busy,
                  obscureText: true,
                  label: l10n.providerSettingsApiKey,
                  onChanged: (_) => setState(() => _error = null),
                ),
              if (_method.experimental)
                TRAlert(
                  variant: TRStatusVariant.warning,
                  title: TRText.inherit(l10n.providerSettingsExperimental),
                ),
              if (_unexpectedError case final error?)
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

  Widget _oauthPane(ProviderAuthAttemptDto attempt) {
    final l10n = AppLocalizations.of(context);
    final terminal =
        attempt.status == ProviderAuthAttemptStatus.failed ||
        attempt.status == ProviderAuthAttemptStatus.expired ||
        attempt.status == ProviderAuthAttemptStatus.cancelled;
    return SettingsDestinationScaffold(
      title: TRText.inherit(l10n.providerSettingsOAuthPending),
      contentMaxWidth: TinestLayoutMetrics.settingsContentMaxWidth,
      formActions: <Widget>[
        if (!terminal)
          TRButton(
            key: ValueKey<String>('provider-auth-cancel-${attempt.id}'),
            appearance: TRAppearance.ghost,
            onPressed: () => ref
                .read(
                  providerSettingsControllerProvider(widget.hostId).notifier,
                )
                .cancelAuth(attempt.id),
            child: TRText.inherit(l10n.commonCancel),
          )
        else
          TRButton(
            key: const ValueKey<String>('provider-auth-retry'),
            intent: TRIntent.primary,
            onPressed: () => setState(() {
              _attemptId = null;
              _error = null;
            }),
            child: TRText.inherit(l10n.commonRetry),
          ),
      ],
      child: SettingsScaffold(
        children: <Widget>[
          SettingsSection(
            title: _authStatusLabel(l10n, attempt.status),
            banner: _oauthErrorBanner(attempt),
            children: <Widget>[
              if (attempt.instructions != null)
                SettingsRow(title: TRText.inherit(attempt.instructions!)),
              if (attempt.authorizationUrl case final url?)
                SettingsRow(
                  title: SelectionArea(child: TRText.inherit(url)),
                  control: Wrap(
                    spacing: TRSpacing.small,
                    children: <Widget>[
                      TRIconButton(
                        appearance: TRAppearance.ghost,
                        label: l10n.commonCopy,
                        onPressed: () =>
                            Clipboard.setData(ClipboardData(text: url)),
                        icon: const Icon(TinestIcons.copy),
                      ),
                      TRIconButton(
                        key: const ValueKey<String>(
                          'provider-oauth-open-browser',
                        ),
                        appearance: TRAppearance.ghost,
                        label: l10n.providerSettingsOpenBrowser,
                        onPressed: () => _openUrl(url),
                        icon: const Icon(TinestIcons.network),
                      ),
                    ],
                  ),
                ),
              if (attempt.userCode case final code?)
                SettingsRow(
                  title: SelectionArea(child: TRText.inherit(code)),
                  control: TRIconButton(
                    appearance: TRAppearance.ghost,
                    label: l10n.commonCopy,
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: code)),
                    icon: const Icon(TinestIcons.copy),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _oauthErrorBanner(ProviderAuthAttemptDto attempt) {
    final authError = attempt.error;
    final openError = _openError;
    if (authError == null && openError == null) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (authError != null)
          TRAlert(
            variant: TRStatusVariant.danger,
            title: TRText.inherit(authError),
          ),
        if (authError != null && openError != null)
          const SizedBox(height: TRSpacing.medium),
        if (openError != null)
          TRAlert(
            key: const ValueKey<String>('provider-oauth-open-error'),
            variant: TRStatusVariant.danger,
            title: TRText.inherit('$openError'),
          ),
      ],
    );
  }

  bool get _canSubmit =>
      !_busy &&
      _validPrefix &&
      (_method.flow != ProviderAuthFlow.apiKey ||
          _apiKey.text.trim().isNotEmpty);

  bool get _validPrefix =>
      RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(_prefix.text.trim());

  String? _prefixError(AppLocalizations l10n) {
    if (_prefix.text.isEmpty || _validPrefix) {
      return _error is TinestClientException &&
              (_error! as TinestClientException).code == 'model_prefix_conflict'
          ? l10n.providerSettingsModelPrefixConflict
          : null;
    }
    return l10n.providerSettingsModelPrefixInvalid;
  }

  Object? get _unexpectedError => _isPrefixConflict(_error) ? null : _error;

  ProviderAuthMethodDto _initialMethod() {
    final existing = widget.existing;
    if (existing != null) {
      final matching = widget.definition.authMethods.where(
        (method) => method.kind == existing.authKind,
      );
      if (matching.isNotEmpty) return matching.first;
    }
    return widget.definition.authMethods.first;
  }

  String _suggestPrefix() {
    final used = <String>{
      for (final connection in widget.state.connections)
        connection.modelPrefix.toLowerCase(),
      for (final attempt in widget.state.authAttempts.values)
        attempt.modelPrefix.toLowerCase(),
      ..._rejectedPrefixes,
    };
    var candidate = widget.definition.id;
    var suffix = 2;
    while (used.contains(candidate)) {
      candidate = '${widget.definition.id}-$suffix';
      suffix += 1;
    }
    return candidate;
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final notifier = ref.read(
      providerSettingsControllerProvider(widget.hostId).notifier,
    );
    try {
      switch (_method.flow) {
        case ProviderAuthFlow.apiKey:
          final connection = await notifier.connectApiKey(
            widget.definition.id,
            _apiKey.text.trim(),
            connectionId: widget.existing?.id ?? _retryConnectionId,
            modelPrefix: _prefix.text.trim(),
          );
          _handleConnection(connection);
        case ProviderAuthFlow.none:
          final connection = await notifier.connectNone(
            widget.definition.id,
            connectionId: widget.existing?.id ?? _retryConnectionId,
            modelPrefix: _prefix.text.trim(),
          );
          _handleConnection(connection);
        case ProviderAuthFlow.oauthBrowser:
        case ProviderAuthFlow.oauthDevice:
          final attempt = await notifier.startAuth(
            widget.definition.id,
            _method.id,
            connectionId: widget.existing?.id,
            modelPrefix: _prefix.text.trim(),
          );
          if (!mounted) return;
          setState(() => _attemptId = attempt.id);
          if (_method.flow == ProviderAuthFlow.oauthBrowser &&
              attempt.authorizationUrl != null) {
            await _openUrl(attempt.authorizationUrl!);
          }
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          if (error is TinestClientException &&
              error.code == 'model_prefix_conflict') {
            _rejectedPrefixes.add(_prefix.text.trim().toLowerCase());
            _prefix.text = _suggestPrefix();
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openUrl(String value) async {
    final l10n = AppLocalizations.of(context);
    try {
      final opened = await ref
          .read(externalUrlOpenerProvider)
          .open(Uri.parse(value));
      if (!mounted) return;
      // A false result is not a failure the opener can describe: no handler
      // accepted the URL. Only this layer knows the reader's language, so the
      // explanation is written here rather than thrown from below.
      setState(
        () => _openError = opened ? null : l10n.providerSettingsAuthUrlFailed,
      );
    } on Object catch (error) {
      if (mounted) setState(() => _openError = error);
    }
  }

  void _handleConnection(ProviderConnectionDto connection) {
    if (connection.status == ProviderConnectionStatus.error) {
      setState(() {
        _retryConnectionId = connection.id;
        _error =
            connection.error ??
            AppLocalizations.of(context).providerSettingsConnectionFailed;
      });
      return;
    }
    widget.onConnected(connection);
  }
}

class _ProviderConnectionPane extends ConsumerStatefulWidget {
  const new({
    required this.hostId,
    required this.state,
    required this.connection,
    required this.onChanged,
    required this.onRemoved,
    required this.onReauth,
    super.key,
  });

  final String hostId;
  final ProviderSettingsState state;
  final ProviderConnectionDto connection;
  final ValueChanged<ProviderConnectionDto> onChanged;
  final VoidCallback onRemoved;
  final ValueChanged<ProviderDefinitionDto> onReauth;

  @override
  ConsumerState<_ProviderConnectionPane> createState() =>
      _ProviderConnectionPaneState();
}

class _ProviderConnectionPaneState
    extends ConsumerState<_ProviderConnectionPane> {
  late final TextEditingController _prefix = TextEditingController(
    text: widget.connection.modelPrefix,
  );
  Object? _error;

  @override
  void dispose() {
    _prefix.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final definition = widget.state.catalog.definitions
        .where((item) => item.id == widget.connection.definitionId)
        .firstOrNull;
    return SettingsDestinationScaffold(
      title: TRText.inherit(widget.connection.displayName),
      contentMaxWidth: TinestLayoutMetrics.settingsContentMaxWidth,
      formActions: <Widget>[
        TRButton(
          key: const ValueKey<String>('provider-prefix-save'),
          intent: TRIntent.primary,
          onPressed: _savePrefix,
          child: TRText.inherit(l10n.commonSave),
        ),
      ],
      child: SettingsScaffold(
        children: <Widget>[
          // Reconnect belongs beside the status it changes, not in the page
          // header: it is a word rather than a glyph, and a header that
          // carried it grew a second line to hold it. The shape matches the
          // disconnect section below — one row, its state leading, its action
          // trailing.
          if (definition case final definition?)
            SettingsSection(
              title: l10n.providerSettingsConnectionHeading,
              // The status row reports "Error" and stops. What the daemon
              // said is the only thing that names what to fix, so it belongs
              // to this section rather than being dropped.
              banner: widget.connection.status == ProviderConnectionStatus.error
                  ? TRAlert(
                      key: const ValueKey<String>('provider-connection-error'),
                      variant: TRStatusVariant.danger,
                      title: TRText.inherit(
                        widget.connection.error ??
                            l10n.providerSettingsConnectionFailed,
                      ),
                    )
                  : null,
              children: <Widget>[
                SettingsRow(
                  title: TRText.inherit(
                    _statusLabel(l10n, widget.connection.status),
                  ),
                  leading: Icon(_statusIcon(widget.connection.status)),
                  control: TRButton(
                    key: const ValueKey<String>('provider-reconnect'),
                    appearance: TRAppearance.outline,
                    onPressed: () => widget.onReauth(definition),
                    child: TRText.inherit(l10n.providerSettingsReconnect),
                  ),
                ),
              ],
            ),
          SettingsSection.form(
            title: l10n.providerSettingsModelPrefix,
            banner: _error == null || _isPrefixConflict(_error)
                ? null
                : TRAlert(
                    variant: TRStatusVariant.danger,
                    title: TRText.inherit('$_error'),
                  ),
            children: <Widget>[
              TRTextField(
                key: const ValueKey<String>('provider-model-prefix'),
                controller: _prefix,
                label: l10n.providerSettingsModelPrefix,
                helperText: l10n.providerSettingsModelPrefixHelp,
                errorText: _isPrefixConflict(_error)
                    ? l10n.providerSettingsModelPrefixConflict
                    : null,
                onChanged: (_) => setState(() => _error = null),
              ),
            ],
          ),
          SettingsSection(
            title: l10n.providerSettingsDisconnectTitle,
            // The row names the connection and the note says what disconnecting
            // costs. As the row's own title the note was prose wrapped beside a
            // button half its height, and it is still the only place the kept
            // agent history is explained before the confirmation opens.
            footer: l10n.providerSettingsDisconnectBody(
              widget.connection.displayName,
            ),
            children: <Widget>[
              SettingsRow(
                title: TRText.inherit(widget.connection.displayName),
                control: TRButton(
                  key: const ValueKey<String>('provider-connection-disconnect'),
                  appearance: TRAppearance.ghost,
                  intent: TRIntent.danger,
                  onPressed: _disconnect,
                  child: TRText.inherit(l10n.providerSettingsDisconnect),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _savePrefix() async {
    try {
      await ref
          .read(providerSettingsControllerProvider(widget.hostId).notifier)
          .updateModelPrefix(widget.connection.id, _prefix.text.trim());
      final changed = ref
          .read(providerSettingsControllerProvider(widget.hostId))
          .value
          ?.connections
          .where((item) => item.id == widget.connection.id)
          .firstOrNull;
      if (changed != null) widget.onChanged(changed);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _disconnect() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showTRDialog<bool>(
      context: context,
      builder: (context) => TRAlertDialog(
        title: TRText.inherit(l10n.providerSettingsDisconnectTitle),
        content: TRText.inherit(
          l10n.providerSettingsDisconnectBody(widget.connection.displayName),
        ),
        actions: <TRButton>[
          TRButton(
            appearance: TRAppearance.ghost,
            onPressed: () => Navigator.pop(context, false),
            child: TRText.inherit(l10n.commonCancel),
          ),
          TRButton(
            intent: TRIntent.danger,
            onPressed: () => Navigator.pop(context, true),
            child: TRText.inherit(l10n.providerSettingsDisconnect),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final disconnected = await ref
        .read(toastMessengerProvider)
        .run(
          () => ref
              .read(providerSettingsControllerProvider(widget.hostId).notifier)
              .disconnect(widget.connection.id),
          failure: l10n.providerSettingsDisconnectFailed,
          success: l10n.providerSettingsDisconnected,
          id: 'provider-disconnect',
        );
    if (disconnected && mounted) widget.onRemoved();
  }
}

bool _isPrefixConflict(Object? error) =>
    error is TinestClientException && error.code == 'model_prefix_conflict';

class _CustomProviderPane extends ConsumerStatefulWidget {
  const new({
    required this.hostId,
    required this.state,
    required this.onCancel,
    required this.onSaved,
    this.existing,
    this.onRemoved,
    super.key,
  });

  final String hostId;
  final ProviderSettingsState state;
  final ProviderConnectionDto? existing;
  final VoidCallback onCancel;
  final ValueChanged<ProviderConnectionDto> onSaved;
  final VoidCallback? onRemoved;

  @override
  ConsumerState<_CustomProviderPane> createState() =>
      _CustomProviderPaneState();
}

class _CustomProviderPaneState extends ConsumerState<_CustomProviderPane> {
  late final TextEditingController _name;
  late final TextEditingController _baseUrl;
  late final TextEditingController _apiKey;
  late final TextEditingController _prefix;
  late String _wireFormatId;
  late bool _authenticationRequired;
  final List<_ManualModelDraft> _drafts = <_ManualModelDraft>[];
  int _nextSeed = 0;
  bool _busy = false;
  bool _namePrefilled = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final connection = widget.existing;
    final initial = connection?.customConfig;
    _name = TextEditingController(text: initial?.name);
    _baseUrl = TextEditingController(
      text: initial?.baseUrl ?? 'http://127.0.0.1:8080/v1',
    );
    _apiKey = TextEditingController();
    for (final model in initial?.models ?? const <ManualProviderModelDto>[]) {
      _drafts.add(
        _ManualModelDraft(
          seed: _nextSeed++,
          modelId: model.id,
          controlIds: <String>{
            for (final control in model.controls) control.id,
          },
          values: <String, List<String>>{
            for (final control in model.controls)
              control.id: <String>[
                for (final choice in control.choices) choice.id,
              ],
          },
        ),
      );
    }
    if (_drafts.isEmpty) _drafts.add(_ManualModelDraft(seed: _nextSeed++));
    _prefix = TextEditingController(
      text: connection?.modelPrefix ?? _suggestCustomPrefix(),
    );
    _wireFormatId =
        initial?.wireFormatId ??
        widget.state.catalog.wireFormats.firstOrNull?.id ??
        '';
    _authenticationRequired = initial?.authenticationRequired ?? true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Localizations are not in scope during initState, so the default name for
    // a brand-new provider is filled in here. The flag keeps a later locale
    // change from overwriting a name the user has since typed or cleared.
    if (_namePrefilled) return;
    _namePrefilled = true;
    if (widget.existing == null) {
      _name.text = AppLocalizations.of(context).providerSettingsCustomName;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _apiKey.dispose();
    for (final draft in _drafts) {
      draft.dispose();
    }
    _prefix.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsDestinationScaffold(
      title: TRText.inherit(
        widget.existing == null
            ? l10n.providerSettingsCustomTitle
            : widget.existing!.displayName,
      ),
      contentMaxWidth: TinestLayoutMetrics.settingsContentMaxWidth,
      formActions: <Widget>[
        TRButton(
          appearance: TRAppearance.ghost,
          onPressed: _busy ? null : widget.onCancel,
          child: TRText.inherit(l10n.commonCancel),
        ),
        TRButton(
          key: const ValueKey<String>('provider-custom-save'),
          intent: TRIntent.primary,
          onPressed: _busy ? null : _save,
          child: TRText.inherit(
            widget.existing == null
                ? _busy
                      ? l10n.commonCreating
                      : l10n.commonCreate
                : _busy
                ? l10n.commonSaving
                : l10n.commonSave,
          ),
        ),
      ],
      child: SettingsScaffold(
        children: <Widget>[
          SettingsSection.form(
            banner: _error == null
                ? null
                : TRAlert(
                    variant: TRStatusVariant.danger,
                    title: TRText.inherit('$_error'),
                  ),
            children: <Widget>[
              TRTextField(controller: _name, label: l10n.commonName),
              TRTextField(
                controller: _baseUrl,
                label: l10n.providerSettingsBaseUrl,
              ),
              TRTextField(
                key: const ValueKey<String>('provider-model-prefix'),
                controller: _prefix,
                label: l10n.providerSettingsModelPrefix,
                helperText: l10n.providerSettingsModelPrefixHelp,
              ),
              TRSelectFormField<String>(
                initialValue: _wireFormatId,
                searchable: true,
                searchPlaceholder: l10n.selectSearchPlaceholder,
                noResultsText: l10n.selectNoResults,
                presentation: TinestSelectPresentation.resolve(context),
                label: l10n.providerSettingsApiFormat,
                width: TinestLayoutMetrics.settingsContentMaxWidth,
                items: <TRSelectItem<String>>[
                  for (final format in widget.state.catalog.wireFormats)
                    TRSelectItem<String>(value: format.id, label: format.label),
                ],
                onValueChange: (value) {
                  if (value == null) return;
                  setState(() {
                    _wireFormatId = value;
                    final encodable = _selectedWire.controls
                        .map((control) => control.id)
                        .toSet();
                    for (final draft in _drafts) {
                      draft.controlIds.retainAll(encodable);
                      draft.values.removeWhere(
                        (id, _) => !encodable.contains(id),
                      );
                    }
                  });
                },
              ),
              TinestSwitchRow(
                flush: true,
                title: TRText.inherit(l10n.providerSettingsRequiresApiKey),
                value: _authenticationRequired,
                onChanged: (value) =>
                    setState(() => _authenticationRequired = value),
              ),
              if (_authenticationRequired)
                TRTextField(
                  key: const ValueKey<String>('provider-api-key'),
                  controller: _apiKey,
                  obscureText: true,
                  label: l10n.providerSettingsApiKey,
                ),
              for (final (index, draft) in _drafts.indexed)
                _ManualModelEditor(
                  key: ValueKey<int>(draft.seed),
                  draft: draft,
                  controls: _selectedWire.controls,
                  onRemove: _drafts.length == 1
                      ? null
                      : () => setState(() {
                          _drafts.removeAt(index).dispose();
                        }),
                  onChanged: () => setState(() {}),
                ),
              TRButton(
                key: const ValueKey<String>('provider-custom-add-model'),
                appearance: TRAppearance.outline,
                onPressed: () => setState(() {
                  _drafts.add(_ManualModelDraft(seed: _nextSeed++));
                }),
                child: TRText.inherit(l10n.providerSettingsManualModelAdd),
              ),
            ],
          ),
          if (widget.existing case final existing?)
            SettingsSection(
              title: l10n.providerSettingsActions,
              children: <Widget>[
                SettingsRow(
                  title: TRText.inherit(
                    l10n.providerSettingsDisconnectBody(existing.displayName),
                  ),
                  control: TRButton(
                    key: const ValueKey<String>('provider-custom-disconnect'),
                    appearance: TRAppearance.ghost,
                    intent: TRIntent.danger,
                    onPressed: _busy ? null : _disconnect,
                    child: TRText.inherit(l10n.providerSettingsDisconnect),
                  ),
                ),
                SettingsRow(
                  title: TRText.inherit(
                    l10n.providerSettingsDeleteCustomBody(existing.displayName),
                  ),
                  control: TRButton(
                    key: const ValueKey<String>('provider-custom-delete'),
                    appearance: TRAppearance.ghost,
                    intent: TRIntent.danger,
                    onPressed: _busy ? null : _delete,
                    child: TRText.inherit(l10n.commonDelete),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  ProviderWireFormatDto get _selectedWire =>
      widget.state.catalog.wireFormats.firstWhere(
        (format) => format.id == _wireFormatId,
        orElse: () => const ProviderWireFormatDto(id: '', label: ''),
      );

  String _suggestCustomPrefix() {
    final used = widget.state.connections
        .map((connection) => connection.modelPrefix)
        .toSet();
    var candidate = 'custom';
    var suffix = 2;
    while (used.contains(candidate)) {
      candidate = 'custom-$suffix';
      suffix += 1;
    }
    return candidate;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final name = _name.text.trim();
    final baseUrl = _baseUrl.text.trim();
    final apiKey = _apiKey.text.trim();
    if (name.isEmpty || baseUrl.isEmpty) {
      setState(() => _error = l10n.providerSettingsRequiredFields);
      return;
    }
    if (_authenticationRequired && widget.existing == null && apiKey.isEmpty) {
      setState(() => _error = l10n.providerSettingsApiKeyRequired);
      return;
    }
    // A menu with nothing in it is a setting that cannot do anything, so the
    // save is refused rather than dropping the control without saying so.
    final incomplete = _selectedWire.controls.where(
      (control) =>
          control.kind == ModelControlKind.choice &&
          _drafts.any(
            (draft) =>
                draft.controlIds.contains(control.id) &&
                (draft.values[control.id] ?? const <String>[]).isEmpty,
          ),
    );
    if (incomplete.isNotEmpty) {
      setState(
        () => _error = l10n.providerSettingsControlValuesRequired(
          incomplete.first.label,
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final config = CustomProviderConfigDto(
      name: name,
      baseUrl: baseUrl,
      wireFormatId: _wireFormatId,
      authenticationRequired: _authenticationRequired,
      models: <ManualProviderModelDto>[
        for (final draft in _drafts)
          if (draft.modelId.text.trim() case final id when id.isNotEmpty)
            ManualProviderModelDto(
              id: id,
              label: id,
              controls: <ModelControlDescriptorDto>[
                for (final control in _selectedWire.controls)
                  if (draft.controlIds.contains(control.id))
                    control.copyWith(
                      choices: <ModelControlChoiceDto>[
                        for (final value
                            in draft.values[control.id] ?? const <String>[])
                          ModelControlChoiceDto(id: value, label: value),
                      ],
                    ),
              ],
            ),
      ],
    );
    final notifier = ref.read(
      providerSettingsControllerProvider(widget.hostId).notifier,
    );
    try {
      late final ProviderConnectionDto saved;
      if (widget.existing case final existing?) {
        if (_prefix.text.trim() != existing.modelPrefix) {
          await notifier.updateModelPrefix(existing.id, _prefix.text.trim());
        }
        saved = await notifier.updateCustom(
          existing.id,
          config,
          apiKey: apiKey.isEmpty ? null : apiKey,
        );
      } else {
        saved = await notifier.createCustom(
          ref.read(appIdGeneratorProvider).generate(),
          config,
          apiKey: apiKey.isEmpty ? null : apiKey,
          modelPrefix: _prefix.text.trim(),
        );
      }
      widget.onSaved(saved);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final connection = widget.existing!;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showTRDialog<bool>(
      context: context,
      builder: (context) => TRAlertDialog(
        title: TRText.inherit(l10n.providerSettingsDeleteCustomTitle),
        content: TRText.inherit(
          l10n.providerSettingsDeleteCustomBody(connection.displayName),
        ),
        actions: <TRButton>[
          TRButton(
            appearance: TRAppearance.ghost,
            onPressed: () => Navigator.pop(context, false),
            child: TRText.inherit(l10n.commonCancel),
          ),
          TRButton(
            intent: TRIntent.danger,
            onPressed: () => Navigator.pop(context, true),
            child: TRText.inherit(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final deleted = await ref
        .read(toastMessengerProvider)
        .run(
          () => ref
              .read(providerSettingsControllerProvider(widget.hostId).notifier)
              .deleteCustom(connection.id),
          failure: l10n.providerSettingsDeleteFailed,
          success: l10n.commonDeleted,
          id: 'provider-delete',
        );
    if (deleted) widget.onRemoved?.call();
  }

  Future<void> _disconnect() async {
    final connection = widget.existing!;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showTRDialog<bool>(
      context: context,
      builder: (context) => TRAlertDialog(
        title: TRText.inherit(l10n.providerSettingsDisconnectTitle),
        content: TRText.inherit(
          l10n.providerSettingsDisconnectBody(connection.displayName),
        ),
        actions: <TRButton>[
          TRButton(
            appearance: TRAppearance.ghost,
            onPressed: () => Navigator.pop(context, false),
            child: TRText.inherit(l10n.commonCancel),
          ),
          TRButton(
            intent: TRIntent.danger,
            onPressed: () => Navigator.pop(context, true),
            child: TRText.inherit(l10n.providerSettingsDisconnect),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final disconnected = await ref
        .read(toastMessengerProvider)
        .run(
          () => ref
              .read(providerSettingsControllerProvider(widget.hostId).notifier)
              .disconnect(connection.id),
          failure: l10n.providerSettingsDisconnectFailed,
          success: l10n.providerSettingsDisconnected,
          id: 'provider-disconnect',
        );
    if (disconnected) widget.onRemoved?.call();
  }
}

IconData _statusIcon(ProviderConnectionStatus status) => switch (status) {
  ProviderConnectionStatus.connected => TinestIcons.status,
  ProviderConnectionStatus.connecting => TinestIcons.refresh,
  ProviderConnectionStatus.degraded ||
  ProviderConnectionStatus.reauthRequired => TinestIcons.warning,
  ProviderConnectionStatus.error => TinestIcons.error,
  ProviderConnectionStatus.disconnected => TinestIcons.stop,
};

String _statusLabel(AppLocalizations l10n, ProviderConnectionStatus status) =>
    switch (status) {
      ProviderConnectionStatus.connecting => l10n.providerStatusConnecting,
      ProviderConnectionStatus.connected => l10n.providerStatusConnected,
      ProviderConnectionStatus.degraded => l10n.providerStatusDegraded,
      ProviderConnectionStatus.error => l10n.providerStatusError,
      ProviderConnectionStatus.reauthRequired =>
        l10n.providerStatusReauthRequired,
      ProviderConnectionStatus.disconnected => l10n.providerStatusDisconnected,
    };

String _catalogLabel(
  AppLocalizations l10n,
  ProviderCatalogFreshness freshness,
) => switch (freshness) {
  ProviderCatalogFreshness.bundled => l10n.providerSettingsCatalogBundled,
  ProviderCatalogFreshness.cached => l10n.providerSettingsCatalogCached,
  ProviderCatalogFreshness.fresh => l10n.providerSettingsCatalogFresh,
  ProviderCatalogFreshness.stale => l10n.providerSettingsCatalogStale,
};

String _authStatusLabel(
  AppLocalizations l10n,
  ProviderAuthAttemptStatus status,
) => switch (status) {
  ProviderAuthAttemptStatus.pending ||
  ProviderAuthAttemptStatus.awaitingUser => l10n.providerSettingsOAuthPending,
  ProviderAuthAttemptStatus.exchanging => l10n.providerStatusConnecting,
  ProviderAuthAttemptStatus.succeeded => l10n.providerStatusConnected,
  ProviderAuthAttemptStatus.failed ||
  ProviderAuthAttemptStatus.expired => l10n.providerStatusError,
  ProviderAuthAttemptStatus.cancelled => l10n.providerStatusDisconnected,
};

/// One manual model being edited on a custom connection.
///
/// Values are per model rather than per connection: two models behind one base
/// URL need not accept the same levels, and only their owner knows which.
final class _ManualModelDraft {
  new({
    required this.seed,
    String modelId = '',
    Set<String>? controlIds,
    Map<String, List<String>>? values,
  }) : modelId = TextEditingController(text: modelId),
       controlIds = controlIds ?? <String>{},
       values = values ?? <String, List<String>>{};

  /// Identity that survives reordering, so editors keep their field state.
  final int seed;

  /// Provider-local model identifier.
  final TextEditingController modelId;

  /// Controls this model offers.
  final Set<String> controlIds;

  /// Values the connection's owner declared, by control id.
  final Map<String, List<String>> values;

  void dispose() => modelId.dispose();
}

class _ManualModelEditor extends StatelessWidget {
  const new({
    required this.draft,
    required this.controls,
    required this.onChanged,
    this.onRemove,
    super.key,
  });

  final _ManualModelDraft draft;
  final List<ModelControlDescriptorDto> controls;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TRSpacing.small,
      children: <Widget>[
        Row(
          spacing: TRSpacing.small,
          children: <Widget>[
            Expanded(
              child: TRTextField(
                controller: draft.modelId,
                label: l10n.providerSettingsManualModelId,
                // A stand-in identifier, which providers never localize.
                placeholder: 'model-a',
                onChanged: (_) => onChanged(),
              ),
            ),
            if (onRemove case final remove?)
              TRIconButton(
                icon: const Icon(TinestIcons.delete),
                label: l10n.providerSettingsManualModelRemove,
                appearance: TRAppearance.ghost,
                onPressed: remove,
              ),
          ],
        ),
        for (final control in controls) ...<Widget>[
          TinestCheckboxRow(
            key: ValueKey<String>(
              'provider-custom-control-${draft.seed}-${control.id}',
            ),
            value: draft.controlIds.contains(control.id),
            onChanged: (selected) {
              selected == true
                  ? draft.controlIds.add(control.id)
                  : draft.controlIds.remove(control.id);
              onChanged();
            },
            title: TRText.inherit(control.label),
            subtitle: control.description == null
                ? null
                : TRText.inherit(control.description!),
          ),
          if (draft.controlIds.contains(control.id) &&
              control.kind == ModelControlKind.choice)
            TRMultiCombobox<String>.controlled(
              value: draft.values[control.id] ?? const <String>[],
              // Nothing here knows what an arbitrary endpoint accepts, so the
              // typed query itself is the option: the owner names the values.
              filterMode: TRComboboxFilterMode.none,
              optionsBuilder: (query) => <TRComboboxItem<String>>[
                for (final value in <String>{
                  ...?draft.values[control.id],
                  if (query.trim().isNotEmpty) query.trim(),
                })
                  TRComboboxItem<String>(value: value, label: value),
              ],
              label: l10n.providerSettingsControlValues(control.label),
              helperText: l10n.providerSettingsControlValuesHelp,
              placeholder: l10n.providerSettingsControlValuesPlaceholder,
              onValueChange: (values) {
                draft.values[control.id] = values;
                onChanged();
              },
            ),
        ],
      ],
    );
  }
}
