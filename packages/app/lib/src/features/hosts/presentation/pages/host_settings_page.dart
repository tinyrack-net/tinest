import 'dart:async';

import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/features/hosts/application/host_controller.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/hosts/presentation/host_labels.dart';
import 'package:app/src/shared/presentation/settings_layout.dart';
import 'package:app/src/shared/presentation/tinest_icons.dart';
import 'package:app/src/shared/presentation/tinest_layout_metrics.dart';
import 'package:app/src/shared/presentation/tinest_page_shell.dart';
import 'package:app/src/shared/presentation/tinest_selection_row.dart';
import 'package:app/src/shared/presentation/toast_messenger.dart';
import 'package:client/client.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Daemon-independent app settings and remote host management.
class AppSettingsPage extends ConsumerWidget {
  /// Creates the global application settings page.
  const new({this.embedded = false, super.key});

  /// Whether the unified settings shell supplies navigation chrome.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(hostRegistryControllerProvider);
    final supportsEmbedded = ref
        .read(appServicesProvider)
        .supportsEmbeddedDaemon;
    final body = SettingsAsyncContent<HostRegistryState>(
      state: state,
      loading: SettingsSkeletonLayout.form(semanticLabel: l10n.settingsLoading),
      error: (error, stackTrace) => SettingsErrorState(
        key: const ValueKey<String>('daemon-settings-error'),
        error: error,
        onRetry: () => ref.invalidate(hostRegistryControllerProvider),
      ),
      data: (registry) => _settingsBody(
        context,
        ref,
        registry,
        supportsEmbedded: supportsEmbedded,
      ),
    );
    if (embedded) return body;
    return TinestPageShell(
      appBar: TinestPageHeader(
        leading: TRIconButton(
          key: const ValueKey<String>('app-settings-back-button'),
          appearance: TRAppearance.ghost,
          label: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () =>
              closeTask(context, () => const WorkspaceHomeRoute().go(context)),
          icon: Icon(TinestIcons.backFor(context)),
        ),
        title: TRText.inherit(l10n.appSettingsTitle),
      ),
      body: body,
    );
  }

  /// Builds the persistent alert for an embedded daemon that will not start.
  ///
  /// The guidance replaces the operating-system diagnostic, which no user can
  /// act on, so the copy action carries both: the guidance for the user and
  /// the diagnostic for whoever reads the bug report.
  Widget _embeddedFailureAlert(
    BuildContext context,
    WidgetRef ref,
    HostRuntimeSnapshot runtime, {
    required int port,
  }) {
    final l10n = AppLocalizations.of(context);
    final title = l10n.appSettingsEmbeddedFailureTitle;
    final guidance = switch (runtime.errorReason) {
      HostFailureReason.embeddedPortInUse =>
        l10n.appSettingsEmbeddedPortConflict(port),
      _ => hostErrorText(l10n, runtime) ?? l10n.hostStatusError,
    };
    final diagnostic = runtime.error;
    return TRAlert(
      key: const ValueKey<String>('embedded-daemon-error'),
      title: TRText.inherit(title),
      description: SelectionArea(child: TRText.inherit(guidance)),
      icon: const Icon(TinestIcons.error),
      variant: TRStatusVariant.danger,
      actions: <Widget>[
        TRButton(
          appearance: TRAppearance.outline,
          onPressed: () => ref
              .read(hostRegistryControllerProvider.notifier)
              .reconnect(embeddedHostId),
          child: TRText.inherit(l10n.commonRetry),
        ),
        TRIconButton(
          key: const ValueKey<String>('embedded-daemon-error-copy'),
          appearance: TRAppearance.ghost,
          label: l10n.commonCopy,
          onPressed: () => unawaited(
            ref
                .read(toastMessengerProvider)
                .run(
                  () => Clipboard.setData(
                    ClipboardData(
                      text: <String>[
                        title,
                        guidance,
                        if (diagnostic != null && diagnostic != guidance)
                          diagnostic,
                      ].join('\n'),
                    ),
                  ),
                  failure: l10n.commonActionFailed,
                  success: l10n.commonCopied,
                  id: 'host-copy-diagnostic',
                ),
          ),
          icon: const Icon(TinestIcons.copy),
        ),
      ],
    );
  }

  Widget _settingsBody(
    BuildContext context,
    WidgetRef ref,
    HostRegistryState registry, {
    required bool supportsEmbedded,
  }) {
    final l10n = AppLocalizations.of(context);
    final embeddedRuntime = registry.runtimes[embeddedHostId];
    return SettingsScaffold(
      children: <Widget>[
        if (supportsEmbedded)
          SettingsSection(
            title: l10n.appSettingsLocalSection,
            banner:
                embeddedRuntime != null &&
                    embeddedRuntime.status == HostRuntimeStatus.error
                ? _embeddedFailureAlert(
                    context,
                    ref,
                    embeddedRuntime,
                    port: registry.settings.embeddedDaemonPort,
                  )
                : null,
            children: <Widget>[
              TinestSwitchRow(
                title: TRText.inherit(l10n.embeddedDaemonName),
                subtitle: TRText.inherit(
                  <String>[
                    l10n.appSettingsEmbeddedSubtitle,
                    if (embeddedRuntime != null &&
                        embeddedRuntime.status != HostRuntimeStatus.error)
                      hostStatusText(l10n, embeddedRuntime),
                  ].join('\n'),
                ),
                wrapsSubtitle: true,
                value: registry.settings.embeddedDaemonEnabled,
                onChanged: (enabled) => _toggleEmbedded(
                  context,
                  ref,
                  currentlyEnabled: registry.settings.embeddedDaemonEnabled,
                  enabled: enabled,
                ),
              ),
              TinestSwitchRow(
                key: const ValueKey<String>('embedded-daemon-exposure'),
                title: TRText.inherit(l10n.appSettingsExposure),
                subtitle: TRText.inherit(l10n.appSettingsExposureSubtitle),
                wrapsSubtitle: true,
                value:
                    registry.settings.embeddedDaemonExposure ==
                    EmbeddedDaemonExposure.allInterfaces,
                onChanged: _embeddedRestarting(registry)
                    ? null
                    : (enabled) => unawaited(
                        ref
                            .read(toastMessengerProvider)
                            .run(
                              () => ref
                                  .read(hostRegistryControllerProvider.notifier)
                                  .setEmbeddedDaemonExposure(
                                    enabled
                                        ? EmbeddedDaemonExposure.allInterfaces
                                        : EmbeddedDaemonExposure.loopback,
                                  ),
                              failure: l10n.appSettingsDaemonChangeFailed,
                              id: 'host-embedded-exposure',
                            ),
                      ),
              ),
              _EmbeddedPortEditor(
                port: registry.settings.embeddedDaemonPort,
                restarting: _embeddedRestarting(registry),
              ),
            ],
          ),
        SettingsSection.form(
          title: l10n.appSettingsRemoteSection,
          action: TRButton(
            key: const ValueKey<String>('app-settings-add-remote'),
            intent: TRIntent.primary,
            onPressed: () =>
                unawaited(const ConnectDaemonRoute().push<void>(context)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(TinestIcons.add),
                const SizedBox(width: TRSpacing.extraSmall),
                TRText(l10n.relayPairTitle),
              ],
            ),
          ),
          children: <Widget>[
            if (registry.profiles.isEmpty)
              TRCard(
                padding: TRCardPadding.none,
                child: SettingsRow(
                  title: TRText.inherit(l10n.appSettingsNoRemotes),
                ),
              ),
            for (final profile in registry.profiles)
              _RemoteHostCard(
                profile: profile,
                runtime: registry.runtimes[profile.id],
              ),
          ],
        ),
      ],
    );
  }

  bool _embeddedRestarting(HostRegistryState registry) =>
      registry.settings.embeddedDaemonEnabled &&
      registry.runtimes[embeddedHostId]?.status == HostRuntimeStatus.connecting;

  Future<void> _toggleEmbedded(
    BuildContext context,
    WidgetRef ref, {
    required bool currentlyEnabled,
    required bool enabled,
  }) async {
    final l10n = AppLocalizations.of(context);
    if (currentlyEnabled && !enabled) {
      final confirmed = await showTRDialog<bool>(
        context: context,
        builder: (context) => TRAlertDialog(
          title: TRText.inherit(l10n.appSettingsStopEmbeddedTitle),
          content: TRText.inherit(l10n.appSettingsStopEmbeddedBody),
          actions: <TRButton>[
            TRButton(
              appearance: TRAppearance.ghost,
              onPressed: () => Navigator.pop(context, false),
              child: TRText.inherit(l10n.commonCancel),
            ),
            TRButton(
              intent: TRIntent.primary,
              onPressed: () => Navigator.pop(context, true),
              child: TRText.inherit(l10n.commonStop),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await ref
        .read(toastMessengerProvider)
        .run(
          () => ref
              .read(hostRegistryControllerProvider.notifier)
              .setEmbeddedDaemonEnabled(enabled: enabled),
          failure: l10n.appSettingsDaemonChangeFailed,
          id: 'host-embedded-enabled',
        );
  }
}

class _EmbeddedPortEditor extends ConsumerStatefulWidget {
  const new({required this.port, required this.restarting});

  final int port;
  final bool restarting;

  @override
  ConsumerState<_EmbeddedPortEditor> createState() =>
      _EmbeddedPortEditorState();
}

class _EmbeddedPortEditorState extends ConsumerState<_EmbeddedPortEditor> {
  final TextEditingController _draft = TextEditingController();
  bool _applying = false;

  /// The drafted port, or null while the draft is empty or out of range.
  int? get _validPort {
    final port = int.tryParse(_draft.text.trim());
    if (port == null) return null;
    return port >= 1 && port <= 65535 ? port : null;
  }

  /// Whether the draft is filled in but not a port.
  ///
  /// An empty draft is someone midway through retyping the number, so it
  /// disables Apply without accusing them of an error they have not made yet.
  bool get _invalid => _draft.text.trim().isNotEmpty && _validPort == null;

  @override
  void initState() {
    super.initState();
    _draft.text = widget.port.toString();
  }

  @override
  void didUpdateWidget(_EmbeddedPortEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.port != widget.port) {
      _draft.text = widget.port.toString();
    }
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final port = _validPort;
    final enabled = !_applying && !widget.restarting;
    final changed = port != null && port != widget.port;
    return SettingsRow(
      title: TRText.inherit(l10n.appSettingsEmbeddedPort),
      description: TRText.inherit(l10n.appSettingsEmbeddedPortHelp),
      unboundedDescription: true,
      controlLayout: SettingsControlLayout.stacked,
      control: LayoutBuilder(
        builder: (context, constraints) {
          final field = Semantics(
            container: true,
            label: l10n.appSettingsEmbeddedPort,
            child: TRTextField(
              key: const ValueKey<String>('embedded-daemon-port'),
              controller: _draft,
              enabled: enabled,
              errorText: _invalid ? l10n.appSettingsEmbeddedPortInvalid : null,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (changed && enabled) unawaited(_apply(port));
              },
            ),
          );
          final bounded = constraints.hasBoundedWidth;
          return Row(
            mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (bounded)
                Expanded(child: field)
              else
                SizedBox(width: TRMeasurements.measureSm, child: field),
              const SizedBox(width: TRSpacing.small),
              TRButton(
                key: const ValueKey<String>('embedded-daemon-port-apply'),
                intent: TRIntent.primary,
                onPressed: changed && enabled ? () => _apply(port) : null,
                child: TRText.inherit(l10n.appSettingsEmbeddedPortApply),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _apply(int port) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _applying = true);
    await ref
        .read(toastMessengerProvider)
        .run(
          () => ref
              .read(hostRegistryControllerProvider.notifier)
              .setEmbeddedDaemonPort(port),
          failure: l10n.appSettingsDaemonChangeFailed,
          success: l10n.commonSaved,
          id: 'host-embedded-port',
        );
    if (mounted) setState(() => _applying = false);
  }
}

/// One remote daemon: its address, its auto-connect choice, and its actions.
///
/// A daemon is a compound entity with actions of its own, so it keeps its own
/// card. Sharing one card across every daemon leaves no boundary between them
/// and makes "the reconnect button of this daemon" unaddressable.
class _RemoteHostCard extends ConsumerWidget {
  const new({required this.profile, required this.runtime});

  final RemoteDaemonProfile profile;
  final HostRuntimeSnapshot? runtime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final active = profile.connections
        .where((connection) => connection.id == runtime?.activeConnectionId)
        .firstOrNull;
    final pathLabel = switch (active) {
      DirectHostConnection() => l10n.relayPathDirect,
      RelayHostConnection() => l10n.relayPathRelay,
      _ => null,
    };
    return TRCard(
      padding: TRCardPadding.none,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SettingsRow(
            leading: Icon(hostStatusIcon(runtime?.status)),
            title: TRText.inherit(profile.label),
            description: TRText.inherit(hostStatusText(l10n, runtime)),
            wrapsDescription: true,
            control: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (pathLabel != null)
                  TRBadge(
                    variant: TRStatusVariant.info,
                    child: TRText.inherit(pathLabel),
                  ),
                TRIconButton(
                  appearance: TRAppearance.ghost,
                  label: l10n.appSettingsEditConnection,
                  onPressed: () => unawaited(
                    EditHostRoute(hostId: profile.id).push<void>(context),
                  ),
                  icon: const Icon(TinestIcons.edit),
                ),
              ],
            ),
          ),
          TRCollapsible(
            attachedEdge: TRCollapsibleAttachedEdge.top,
            trigger: TRText.inherit(l10n.relayConnectionDetails),
            content: Padding(
              padding: SettingsRow.resolvedPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final connection in profile.connections)
                    TRText.inherit(_connectionSummary(connection)),
                ],
              ),
            ),
          ),
          TinestSwitchRow(
            title: TRText.inherit(l10n.appSettingsAutoConnect),
            value: profile.autoConnect,
            onChanged: (enabled) => unawaited(
              ref
                  .read(toastMessengerProvider)
                  .run(
                    () => ref
                        .read(hostRegistryControllerProvider.notifier)
                        .setRemoteAutoConnect(profile.id, enabled: enabled),
                    failure: l10n.appSettingsDaemonChangeFailed,
                    id: 'host-auto-connect',
                  ),
            ),
          ),
          Padding(
            // Sharing the row inset keeps the actions on the same trailing edge
            // as the controls above them.
            padding: SettingsRow.resolvedPadding(context),
            // A Wrap rather than a Row: on a narrow window the two actions do
            // not fit on one line. It right-aligns correctly here because the
            // surrounding column stretches it to the card width.
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: TRSpacing.small,
              runSpacing: TRSpacing.extraSmall,
              children: <Widget>[
                TRButton(
                  appearance: TRAppearance.ghost,
                  onPressed: () => unawaited(
                    ref
                        .read(toastMessengerProvider)
                        .run(
                          () => ref
                              .read(hostRegistryControllerProvider.notifier)
                              .reconnect(profile.id),
                          failure: l10n.appSettingsReconnectFailed,
                          id: 'host-reconnect',
                        ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(TinestIcons.refresh),
                      const SizedBox(width: TRSpacing.extraSmall),
                      TRText(l10n.appSettingsReconnect),
                    ],
                  ),
                ),
                if (runtime?.connected == true)
                  TRButton(
                    appearance: TRAppearance.ghost,
                    onPressed: () => unawaited(
                      DaemonConnectionsRoute(hostId: profile.id)
                          .push<void>(context),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(TinestIcons.computer),
                        const SizedBox(width: TRSpacing.extraSmall),
                        TRText(l10n.relayApprovedDevices),
                      ],
                    ),
                  ),
                if (runtime?.connected == true)
                  TRButton(
                    appearance: TRAppearance.ghost,
                    onPressed: () =>
                        ProviderSettingsRoute(hostId: profile.id)
                            .replace(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(TinestIcons.network),
                        const SizedBox(width: TRSpacing.extraSmall),
                        TRText(l10n.appSettingsProviderSettings),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _connectionSummary(HostConnection connection) => switch (connection) {
  DirectHostConnection(:final endpoint) => endpoint.websocketUri.toString(),
  RelayHostConnection(:final relayUri) => relayUri.toString(),
};

/// Add/edit form for one remote daemon profile.
class RemoteHostEditPage extends ConsumerStatefulWidget {
  /// Creates an add form when [hostId] is null, otherwise an edit form.
  const new({this.hostId, super.key});

  /// Existing profile ID for edit mode.
  final String? hostId;

  @override
  ConsumerState<RemoteHostEditPage> createState() => _RemoteHostEditPageState();
}

class _RemoteHostEditPageState extends ConsumerState<RemoteHostEditPage> {
  final _label = TextEditingController();
  final _address = TextEditingController();
  final _token = TextEditingController();
  bool _autoConnect = true;
  bool _initialized = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _address.addListener(_addressChanged);
  }

  void _addressChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _address.removeListener(_addressChanged);
    _label.dispose();
    _address.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final registryState = ref.watch(hostRegistryControllerProvider);
    final registry = registryState.value;
    final existing = registry?.profiles
        .where((profile) => profile.id == widget.hostId)
        .firstOrNull;
    if (!_initialized && (widget.hostId == null || registry != null)) {
      _initialized = true;
      if (existing != null) {
        _label.text = existing.label;
        _address.text =
            existing.directConnections.firstOrNull?.endpoint.websocketUri
                .toString() ??
            '';
        _autoConnect = existing.autoConnect;
      }
    }
    final waitingForExisting = widget.hostId != null && !registryState.hasValue;
    final body = waitingForExisting
        ? registryState.hasError
              ? SettingsErrorState(
                  key: const ValueKey<String>('remote-daemon-settings-error'),
                  error: registryState.error!,
                  onRetry: () => ref.invalidate(hostRegistryControllerProvider),
                )
              : SettingsSkeletonLayout.form(semanticLabel: l10n.settingsLoading)
        : SettingsScaffold(
            children: <Widget>[
              SettingsSection.form(
                // Not the page title again: the header above already names the
                // form, and a section heading is drawn larger than it.
                title: l10n.appSettingsRemoteDetails,
                banner: _error == null
                    ? null
                    : TRAlert(
                        title: TRText.inherit(l10n.appSettingsConnectionFailed),
                        description: TRText.inherit(_error!),
                        icon: const Icon(TinestIcons.error),
                        variant: TRStatusVariant.danger,
                      ),
                children: <Widget>[
                  TRTextField(
                    key: const ValueKey<String>('remote-host-label'),
                    controller: _label,
                    label: l10n.commonName,
                    placeholder: l10n.appSettingsLabelPlaceholder,
                  ),
                  TRTextField(
                    key: const ValueKey<String>('remote-host-address'),
                    controller: _address,
                    keyboardType: TextInputType.url,
                    label: l10n.appSettingsAddress,
                    // A URL is not prose; the example is the same in every
                    // language.
                    placeholder: 'wss://tinest.example.com/ws',
                  ),
                  TRTextField(
                    key: const ValueKey<String>('remote-host-token'),
                    controller: _token,
                    obscureText: true,
                    label: existing == null
                        ? l10n.appSettingsBearerToken
                        : l10n.appSettingsNewToken,
                  ),
                ],
              ),
              SettingsSection(
                title: l10n.appSettingsConnectionBehaviour,
                children: <Widget>[
                  TinestSwitchRow(
                    title: TRText.inherit(l10n.appSettingsAutoConnect),
                    value: _autoConnect,
                    onChanged: (value) => setState(() => _autoConnect = value),
                  ),
                ],
              ),
              if (existing != null)
                SettingsSection(
                  title: l10n.commonDelete,
                  // What deleting costs belongs under the row it applies to,
                  // where it is read last, rather than above it as a preamble.
                  footer: l10n.appSettingsDeleteBody,
                  children: <Widget>[
                    SettingsRow(
                      title: TRText.inherit(existing.label),
                      control: TRButton(
                        key: const ValueKey<String>('remote-host-delete'),
                        appearance: TRAppearance.outline,
                        intent: TRIntent.danger,
                        onPressed: _saving ? null : () => _delete(existing),
                        child: TRText.inherit(l10n.commonDelete),
                      ),
                    ),
                  ],
                ),
            ],
          );
    return TinestPageShell(
      appBar: TinestPageHeader(
        leading: TRIconButton(
          key: const ValueKey<String>('remote-host-back-button'),
          appearance: TRAppearance.ghost,
          label: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () =>
              closeTask(context, () => const DaemonSettingsRoute().go(context)),
          icon: Icon(TinestIcons.backFor(context)),
        ),
        title: TRText.inherit(
          widget.hostId == null
              ? l10n.appSettingsAddRemoteTitle
              : l10n.appSettingsEditRemoteTitle,
        ),
      ),
      // This page owns a shell rather than a settings destination, so it
      // composes the same pinned action bar itself. Save stays out of the
      // scrolling form for the reason it does everywhere else: an action that
      // can scroll away is one the user has to go looking for.
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(child: body),
          SettingsFormActions(
            contentMaxWidth: TinestLayoutMetrics.settingsContentMaxWidth,
            children: <Widget>[
              TRButton(
                key: const ValueKey<String>('remote-host-save'),
                intent: TRIntent.primary,
                loading: _saving,
                loadingLabel: l10n.commonSaving,
                onPressed: _saving || waitingForExisting
                    ? null
                    : () => _save(existing),
                child: TRText.inherit(l10n.commonSave),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save(RemoteDaemonProfile? existing) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final controller = ref.read(hostRegistryControllerProvider.notifier);
      if (existing == null) {
        await controller.addRemote(
          label: _label.text,
          address: _address.text,
          bearerToken: _token.text,
          autoConnect: _autoConnect,
        );
      } else {
        await controller.updateRemote(
          profileId: existing.id,
          label: _label.text,
          address: _address.text,
          autoConnect: _autoConnect,
          replacementBearerToken: _token.text.trim().isEmpty
              ? null
              : _token.text,
        );
      }
      if (mounted) {
        if (existing == null) {
          const DaemonSettingsRoute().go(context);
        } else {
          closeTask(context, () => const DaemonSettingsRoute().go(context));
        }
      }
    } on HostConnectionFailure catch (failure) {
      if (!mounted) return;
      final message = hostConnectionFailureText(
        AppLocalizations.of(context),
        failure,
      );
      setState(() => _error = message);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(RemoteDaemonProfile profile) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showTRDialog<bool>(
      context: context,
      builder: (context) => TRAlertDialog(
        title: TRText.inherit(l10n.appSettingsDeleteTitle(profile.label)),
        content: TRText.inherit(l10n.appSettingsDeleteBody),
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
    final removed = await ref
        .read(toastMessengerProvider)
        .run(
          () => ref
              .read(hostRegistryControllerProvider.notifier)
              .removeRemote(profile.id),
          failure: l10n.appSettingsDeleteFailed,
          success: l10n.commonDeleted,
          id: 'host-delete',
        );
    if (!removed) return;
    // Deleting the daemon being edited invalidates the settings task that was
    // opened for it, so this clears the stack rather than popping into it.
    if (mounted) const WorkspaceHomeRoute().go(context);
  }
}
