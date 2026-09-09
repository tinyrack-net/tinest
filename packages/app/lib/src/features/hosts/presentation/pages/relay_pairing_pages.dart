import 'dart:async';

import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/app/app_identity.dart';
import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/features/hosts/application/host_controller.dart';
import 'package:app/src/features/hosts/application/relay_devices_controller.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/hosts/domain/pairing_intent.dart';
import 'package:app/src/features/hosts/presentation/host_labels.dart';
import 'package:app/src/shared/presentation/settings_layout.dart';
import 'package:app/src/shared/presentation/tinest_bottom_sheet.dart';
import 'package:app/src/shared/presentation/tinest_icons.dart';
import 'package:app/src/shared/presentation/tinest_layout_metrics.dart';
import 'package:app/src/shared/presentation/tinest_page_shell.dart';
import 'package:app/src/shared/presentation/toast_messenger.dart';
import 'package:app/src/shared/presentation/workspace_skeletons.dart';
import 'package:client/client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:protocol/protocol.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Chooses a relay-first or advanced direct daemon connection.
class ConnectDaemonPage extends StatelessWidget {
  /// Creates the connection method page.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cameraSupported =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    return _PairingTaskShell(
      title: l10n.relayConnectDaemonTitle,
      child: SettingsSection(
        description: l10n.relayConnectDaemonDescription,
        children: <Widget>[
          if (cameraSupported)
            _ConnectionMethod(
              key: const ValueKey<String>('connect-daemon-scan'),
              icon: TinestIcons.scanQr,
              title: l10n.relayPairScan,
              description: l10n.relayConnectScanDescription,
              onTap: () => const PairingScanRoute().push<void>(context),
            ),
          _ConnectionMethod(
            key: const ValueKey<String>('connect-daemon-paste'),
            icon: TinestIcons.paste,
            title: l10n.relayConnectPasteTitle,
            description: l10n.relayConnectPasteDescription,
            onTap: () => const PairingLinkRoute().push<void>(context),
          ),
          _ConnectionMethod(
            key: const ValueKey<String>('connect-daemon-direct'),
            icon: TinestIcons.link,
            title: l10n.relayAdvancedDirect,
            description: l10n.relayConnectDirectDescription,
            onTap: () => const AdvancedNewHostRoute().push<void>(context),
          ),
        ],
      ),
    );
  }
}

class _ConnectionMethod extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TRNavigationRow(
    leading: Icon(icon),
    label: TRText.inherit(title),
    description: TRText.inherit(description),
    onPressed: onTap,
  );
}

/// Accepts a connection link and opens the shared offer review page.
class PairingLinkPage extends ConsumerStatefulWidget {
  /// Creates the link entry page.
  const new({super.key});

  @override
  ConsumerState<PairingLinkPage> createState() => _PairingLinkPageState();
}

class _PairingLinkPageState extends ConsumerState<PairingLinkPage> {
  final _link = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _PairingTaskShell(
      title: l10n.relayConnectPasteTitle,
      child: SettingsSection.form(
        children: <Widget>[
          if (_error != null)
            TRAlert(
              title: TRText.inherit(l10n.appSettingsConnectionFailed),
              description: TRText.inherit(_error!),
              icon: const Icon(TinestIcons.error),
              variant: TRStatusVariant.danger,
            ),
          TRTextField(
            key: const ValueKey<String>('relay-pair-link'),
            controller: _link,
            keyboardType: TextInputType.url,
            label: l10n.relayPairLink,
            placeholder: 'https://tinest.tinyrack.net/pair#offer=…',
            onSubmitted: (_) => _review(),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TRButton(
              key: const ValueKey<String>('relay-pair-review'),
              intent: TRIntent.primary,
              onPressed: _review,
              child: TRText.inherit(l10n.relayPairAction),
            ),
          ),
        ],
      ),
    );
  }

  void _review() {
    final uri = Uri.tryParse(_link.text.trim());
    try {
      if (uri == null) throw const FormatException();
      PairingIntent.parse(uri, nowUtc: ref.read(appClockProvider).nowUtc());
      unawaited(context.push<void>(uri.toString()));
    } on FormatException {
      setState(
        () =>
            _error = AppLocalizations.of(context)
                .relayPairInvalid(AppIdentity.displayName),
      );
    }
  }
}

/// Scans a daemon's one-time connection QR code with the native camera.
class PairingScanPage extends ConsumerStatefulWidget {
  /// Creates the camera scanner page.
  const new({super.key});

  @override
  ConsumerState<PairingScanPage> createState() => _PairingScanPageState();
}

class _PairingScanPageState extends ConsumerState<PairingScanPage> {
  final _scanner = MobileScannerController();
  bool _handled = false;
  bool _cameraFailed = false;
  String? _scanError;

  @override
  void dispose() {
    unawaited(_scanner.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cameraSupported =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    return _PairingTaskShell(
      title: l10n.relayPairScan,
      child: SettingsSection(
        children: <Widget>[
          if (_scanError != null)
            TRAlert(
              title: TRText.inherit(l10n.appSettingsConnectionFailed),
              description: TRText.inherit(_scanError!),
              icon: const Icon(TinestIcons.error),
              variant: TRStatusVariant.danger,
            ),
          if (!cameraSupported)
            TRAlert(
              key: const ValueKey<String>('relay-camera-unavailable'),
              title: TRText.inherit(l10n.relayPairTitle),
              description: TRText.inherit(l10n.relayPairCameraUnavailable),
              icon: const Icon(TinestIcons.info),
              variant: TRStatusVariant.info,
            )
          else
            AspectRatio(
              aspectRatio: 1,
              child: MobileScanner(
                controller: _scanner,
                onDetect: _detected,
                errorBuilder: (context, error) {
                  _cameraFailed = true;
                  return TRAlert(
                    title: TRText.inherit(l10n.appSettingsConnectionFailed),
                    description: TRText.inherit(
                      l10n.relayPairCameraError(AppIdentity.displayName),
                    ),
                    icon: const Icon(TinestIcons.error),
                    variant: TRStatusVariant.danger,
                    actions: <Widget>[
                      TRButton(
                        key: const ValueKey<String>('relay-camera-retry'),
                        appearance: TRAppearance.outline,
                        onPressed: _retryCamera,
                        child: TRText.inherit(l10n.relayPairCameraRetry),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _retryCamera() async {
    if (!_cameraFailed) return;
    try {
      await _scanner.start();
      if (mounted) setState(() => _cameraFailed = false);
    } on MobileScannerException {
      if (mounted) {
        setState(
          () =>
              _scanError = AppLocalizations.of(context)
                  .relayPairCameraError(AppIdentity.displayName),
        );
      }
    }
  }

  void _detected(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    final uri = raw == null ? null : Uri.tryParse(raw.trim());
    try {
      if (uri == null) throw const FormatException();
      PairingIntent.parse(uri, nowUtc: ref.read(appClockProvider).nowUtc());
      _handled = true;
      context.replace(uri.toString());
    } on FormatException {
      setState(
        () =>
            _scanError = AppLocalizations.of(context)
                .relayPairInvalid(AppIdentity.displayName),
      );
    }
  }
}

/// Reviews a locally validated offer before consuming its capability.
class PairOfferPage extends ConsumerStatefulWidget {
  /// Creates the review page for [pairingUrl].
  const new({required this.pairingUrl, super.key});

  /// Canonical URL including its fragment-only pairing capability.
  final Uri pairingUrl;

  @override
  ConsumerState<PairOfferPage> createState() => _PairOfferPageState();
}

class _PairOfferPageState extends ConsumerState<PairOfferPage> {
  final _deviceName = TextEditingController();
  PairingIntent? _intent;
  bool _pairing = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_deviceName.text.isEmpty) {
      _deviceName.text = ref.read(appServicesProvider).clientKind;
    }
    if (_intent == null && _error == null) {
      try {
        _intent = PairingIntent.parse(
          widget.pairingUrl,
          nowUtc: ref.read(appClockProvider).nowUtc(),
        );
      } on FormatException {
        _error = AppLocalizations.of(context)
            .relayPairInvalid(AppIdentity.displayName);
      }
    }
  }

  @override
  void dispose() {
    _deviceName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final intent = _intent;
    return _PairingTaskShell(
      title: l10n.relayConfirmTitle,
      child: SettingsSection.form(
        banner: _error == null
            ? TRAlert(
                title: TRText.inherit(l10n.relayPairTitle),
                description: TRText.inherit(l10n.relayConfirmDescription),
                icon: const Icon(TinestIcons.lock),
                variant: TRStatusVariant.info,
              )
            : TRAlert(
                title: TRText.inherit(l10n.appSettingsConnectionFailed),
                description: TRText.inherit(_error!),
                icon: const Icon(TinestIcons.error),
                variant: TRStatusVariant.danger,
              ),
        children: <Widget>[
          if (intent != null) ...<Widget>[
            _PairingFact(
              label: l10n.relayConfirmDaemon,
              value: intent.serverId,
            ),
            _PairingFact(
              label: l10n.relayConfirmRelay,
              value: intent.relayUri.authority,
            ),
            _PairingFact(
              label: l10n.relayConfirmExpires,
              value: MaterialLocalizations.of(context).formatTimeOfDay(
                TimeOfDay.fromDateTime(intent.expiresAt.toLocal()),
              ),
            ),
            TRTextField(
              key: const ValueKey<String>('relay-device-name'),
              controller: _deviceName,
              label: l10n.relayPairDeviceName,
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TRButton(
                key: const ValueKey<String>('relay-pair-submit'),
                intent: TRIntent.primary,
                loading: _pairing,
                loadingLabel: l10n.relayPairAction,
                onPressed: _pairing ? null : _pair,
                child: TRText.inherit(l10n.relayPairAction),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pair() async {
    final intent = _intent;
    if (intent == null) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _pairing = true;
      _error = null;
    });
    try {
      final profile = await ref
          .read(hostRegistryControllerProvider.notifier)
          .pairRemote(
            pairingUrl: intent.pairingUrl,
            deviceName: _deviceName.text.trim().isEmpty
                ? ref.read(appServicesProvider).clientKind
                : _deviceName.text.trim(),
          );
      if (mounted) DaemonConnectionsRoute(hostId: profile.id).go(context);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().toLowerCase().contains('expired')
            ? l10n.relayPairExpired
            : l10n.relayPairFailed;
      });
    } finally {
      if (mounted) setState(() => _pairing = false);
    }
  }
}

class _PairingFact extends StatelessWidget {
  const new({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => TRCard(
    padding: TRCardPadding.none,
    child: SettingsRow(
      title: TRText.inherit(label),
      description: SelectionArea(child: TRText.inherit(value)),
      wrapsDescription: true,
    ),
  );
}

class _PairingTaskShell extends StatelessWidget {
  const new({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => TinestPageShell(
    appBar: TinestPageHeader(
      leading: TRIconButton(
        key: const ValueKey<String>('remote-host-back-button'),
        appearance: TRAppearance.ghost,
        label: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () =>
            closeTask(context, () => const DaemonSettingsRoute().go(context)),
        icon: Icon(TinestIcons.backFor(context)),
      ),
      title: TRText.inherit(title),
    ),
    body: SettingsScaffold(children: <Widget>[child]),
  );
}

/// Shows one daemon's transport, share offer, and approved relay devices.
class DaemonConnectionsPage extends ConsumerStatefulWidget {
  /// Creates the page for [hostId].
  const new({required this.hostId, this.embedded = false, super.key});

  /// App-local daemon identifier.
  final String hostId;

  /// Whether the unified settings shell supplies page chrome.
  final bool embedded;

  @override
  ConsumerState<DaemonConnectionsPage> createState() =>
      _DaemonConnectionsPageState();
}

class _DaemonConnectionsPageState extends ConsumerState<DaemonConnectionsPage> {
  final _offerLink = TextEditingController();
  RelayStatusDto? _status;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _offerLink.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final devicesAsync = ref.watch(relayDevicesProvider(widget.hostId));
    final registry = ref.watch(hostRegistryControllerProvider).value;
    final runtime = registry?.runtimes[widget.hostId];
    final profile = registry?.profiles
        .where((item) => item.id == widget.hostId)
        .firstOrNull;
    final activeConnection = profile?.connections
        .where((connection) => connection.id == runtime?.activeConnectionId)
        .firstOrNull;
    final pathLabel = switch (activeConnection) {
      DirectHostConnection() => l10n.relayPathDirect,
      RelayHostConnection() => l10n.relayPathRelay,
      _ when runtime?.kind == HostKind.embedded => l10n.relayPathDirect,
      _ => null,
    };
    final body = SettingsScaffold(
      children: <Widget>[
        SettingsSection(
          children: <Widget>[
            SettingsRow(
              leading: const Icon(TinestIcons.network),
              title: TRText.inherit(runtime?.label ?? widget.hostId),
              description: TRText.inherit(hostStatusText(l10n, runtime)),
              wrapsDescription: true,
              control: pathLabel == null && profile == null
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (pathLabel != null)
                          TRBadge(
                            variant: TRStatusVariant.info,
                            child: TRText.inherit(pathLabel),
                          ),
                        if (profile != null)
                          TRButton(
                            appearance: TRAppearance.ghost,
                            onPressed: () =>
                                EditHostRoute(hostId: profile.id)
                                    .push<void>(context),
                            child: TRText.inherit(
                              l10n.appSettingsEditConnection,
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
        SettingsSection(
          // No heading: the one row below it carries the same words, so a
          // heading here printed the name of the action twice in a row.
          banner: _error == null
              ? null
              : TRAlert(
                  title: TRText.inherit(l10n.appSettingsConnectionFailed),
                  description: TRText.inherit(_error!),
                  icon: const Icon(TinestIcons.error),
                  variant: TRStatusVariant.danger,
                ),
          children: <Widget>[
            TRNavigationRow(
              key: const ValueKey<String>('relay-pair-device'),
              label: TRText.inherit(l10n.relayPairTitle),
              description: TRText.inherit(l10n.relayPairDeviceDescription),
              trailing: _busy ? const TRSpinner() : null,
              onPressed: _busy ? null : _openPairDialog,
            ),
          ],
        ),
        SettingsSection(
          title: l10n.settingsCategoryAdvanced,
          children: <Widget>[
            TRNavigationRow(
              key: const ValueKey<String>('relay-advanced-endpoint'),
              leading: const Icon(TinestIcons.cloud),
              label: TRText.inherit(l10n.relayAdvancedRelayEndpointChange),
              description: _status == null
                  ? null
                  : TRText.inherit(_status!.endpoint),
              onPressed: _busy ? null : _openRelayEndpointEditor,
            ),
            TRNavigationRow(
              key: const ValueKey<String>('relay-advanced-direct'),
              leading: const Icon(TinestIcons.link),
              label: TRText.inherit(l10n.relayAdvancedDirect),
              description: TRText.inherit(l10n.relayConnectDirectDescription),
              onPressed: () => const AdvancedNewHostRoute().push<void>(context),
            ),
          ],
        ),
        _devicesSection(devicesAsync),
      ],
    );
    if (widget.embedded) return body;
    return TinestPageShell(
      appBar: TinestPageHeader(
        leading: TRIconButton(
          appearance: TRAppearance.ghost,
          label: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () =>
              closeTask(context, () => const DaemonSettingsRoute().go(context)),
          icon: Icon(TinestIcons.backFor(context)),
        ),
        title: TRText.inherit(l10n.settingsCategoryConnection),
      ),
      body: body,
    );
  }

  Widget _devicesSection(AsyncValue<List<RelayDeviceDto>> devicesAsync) {
    final l10n = AppLocalizations.of(context);
    if (!devicesAsync.hasValue && devicesAsync.hasError) {
      return SettingsSection.form(
        title: l10n.relayApprovedDevices,
        banner: TRAlert(
          title: TRText.inherit(l10n.appSettingsConnectionFailed),
          description: TRText.inherit('${devicesAsync.error}'),
          icon: const Icon(TinestIcons.error),
          variant: TRStatusVariant.danger,
        ),
        children: const <Widget>[],
      );
    }
    return SettingsSection(
      title: l10n.relayApprovedDevices,
      children: <Widget>[
        if (!devicesAsync.hasValue)
          Padding(
            padding: SettingsRow.resolvedPadding(context),
            child: ListRowsSkeleton(
              semanticLabel: l10n.settingsLoading,
              rows: 3,
            ),
          )
        else if (devicesAsync.requireValue.isEmpty)
          SettingsRow(title: TRText.inherit(l10n.relayNoDevices))
        else
          for (final device in devicesAsync.requireValue)
            SettingsRow(
              leading: const Icon(TinestIcons.computer),
              title: TRText.inherit(device.name),
              control: TRButton(
                appearance: TRAppearance.ghost,
                intent: TRIntent.danger,
                onPressed: _busy ? null : () => _revoke(device),
                child: TRText.inherit(l10n.relayRevoke),
              ),
            ),
      ],
    );
  }

  Future<RelayApi> _relay() async {
    final registry = await ref.read(hostRegistryControllerProvider.future);
    final runtime = registry.runtimes[widget.hostId];
    if (runtime?.connected != true || runtime?.api == null) {
      throw const HostConnectionFailure.network(
        'Online daemon connection required.',
      );
    }
    return runtime!.api!.relay;
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final status = await (await _relay()).getRelayStatus();
      if (!mounted) return;
      setState(() => _status = status);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPairDialog() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final relay = await _relay();
      final status = _status?.enabled == true
          ? _status!
          : await relay.setRelayEnabled(enabled: true);
      final offer = await relay.createRelayPairingOffer();
      if (mounted) {
        _offerLink.text = offer.url;
        setState(() => _status = status);
        unawaited(_showPairDialog(offer));
      }
    } on Exception catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openRelayEndpointEditor() async {
    final l10n = AppLocalizations.of(context);
    final editor = _RelayEndpointEditor(
      initialValue: _status?.endpoint ?? '',
      fieldLabel: l10n.relayAdvancedRelayEndpoint,
      saveLabel: l10n.commonSave,
      errorTitle: l10n.appSettingsConnectionFailed,
      onSave: _setRelayEndpoint,
    );
    if (MediaQuery.sizeOf(context).width <
        TinestLayoutMetrics.compactBreakpoint) {
      await showTinestBottomSheet<void>(
        context: context,
        builder: (context) => TinestBottomSheet(
          semanticLabel: l10n.relayAdvancedRelayEndpointChange,
          title: TRText.inherit(l10n.relayAdvancedRelayEndpointChange),
          description: TRText.inherit(l10n.relayAdvancedRelayEndpointHelp),
          content: editor,
        ),
      );
      return;
    }
    await showTRDialog<void>(
      context: context,
      builder: (context) => TRDialog(
        semanticLabel: l10n.relayAdvancedRelayEndpointChange,
        title: TRText.inherit(l10n.relayAdvancedRelayEndpointChange),
        description: TRText.inherit(l10n.relayAdvancedRelayEndpointHelp),
        content: editor,
      ),
    );
  }

  Future<void> _setRelayEndpoint(String endpoint) async {
    final status = await (await _relay()).setRelayEndpoint(endpoint);
    if (mounted) setState(() => _status = status);
  }

  Future<void> _showPairDialog(RelayPairingOfferDto offer) =>
      showTRDialog<void>(
        context: context,
        builder: (dialogContext) => TRDialog(
          title: Row(
            children: <Widget>[
              Expanded(
                child: TRText.inherit(
                  AppLocalizations.of(context).relayPairTitle,
                ),
              ),
              TRIconButton(
                key: const ValueKey<String>('relay-dialog-close'),
                appearance: TRAppearance.ghost,
                label: AppLocalizations.of(context).commonClose,
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(TinestIcons.close),
              ),
            ],
          ),
          description: TRText.inherit(
            AppLocalizations.of(context).relayPairDialogDescription,
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: TRSpacing.large),
              Center(
                child: TRQrCode(
                  data: offer.url,
                  semanticLabel: AppLocalizations.of(context)
                      .relayPairQrSemantics,
                  uiSize: TRUiSize.lg,
                ),
              ),
              const SizedBox(height: TRSpacing.medium),
              TRTextField(
                controller: _offerLink,
                label: AppLocalizations.of(context).relayPairLink,
                readOnly: true,
              ),
              const SizedBox(height: TRSpacing.small),
              TRText.inherit(
                AppLocalizations.of(context).relayLinkExpires(
                  MaterialLocalizations.of(context).formatTimeOfDay(
                    TimeOfDay.fromDateTime(offer.expiresAt.toLocal()),
                  ),
                ),
              ),
            ],
          ),
          actions: Wrap(
            alignment: WrapAlignment.end,
            spacing: TRSpacing.small,
            children: <Widget>[
              TRCopyButton(
                value: offer.url,
                idleLabel: AppLocalizations.of(context).commonCopy,
              ),
              TRButton(
                appearance: TRAppearance.outline,
                onPressed: () => unawaited(
                  SharePlus.instance.share(ShareParams(text: offer.url)),
                ),
                child: TRText.inherit(AppLocalizations.of(context).relayShare),
              ),
            ],
          ),
        ),
      );

  Future<void> _revoke(RelayDeviceDto device) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showTRDialog<bool>(
      context: context,
      builder: (context) => TRAlertDialog(
        title: TRText.inherit(l10n.relayRevokeTitle(device.name)),
        content: TRText.inherit(l10n.relayRevokeBody),
        actions: <TRButton>[
          TRButton(
            appearance: TRAppearance.ghost,
            onPressed: () => Navigator.pop(context, false),
            child: TRText.inherit(l10n.commonCancel),
          ),
          TRButton(
            intent: TRIntent.danger,
            onPressed: () => Navigator.pop(context, true),
            child: TRText.inherit(l10n.relayRevoke),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    final revoked = await ref
        .read(toastMessengerProvider)
        .run(
          () async => await (await _relay()).revokeRelayDevice(device.id),
          failure: l10n.relayRevokeFailed,
          success: l10n.commonDeleted,
          id: 'relay-revoke',
        );
    if (revoked) ref.invalidate(relayDevicesProvider(widget.hostId));
    if (mounted) setState(() => _busy = false);
  }
}

class _RelayEndpointEditor extends StatefulWidget {
  const new({
    required this.initialValue,
    required this.fieldLabel,
    required this.saveLabel,
    required this.errorTitle,
    required this.onSave,
  });

  final String initialValue;
  final String fieldLabel;
  final String saveLabel;
  final String errorTitle;
  final Future<void> Function(String endpoint) onSave;

  @override
  State<_RelayEndpointEditor> createState() => _RelayEndpointEditorState();
}

class _RelayEndpointEditorState extends State<_RelayEndpointEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_error case final error?) ...<Widget>[
          TRAlert(
            title: TRText.inherit(widget.errorTitle),
            description: TRText.inherit(error),
            icon: const Icon(TinestIcons.error),
            variant: TRStatusVariant.danger,
          ),
          const SizedBox(height: TRSpacing.medium),
        ],
        TRTextField(
          key: const ValueKey<String>('relay-endpoint'),
          controller: _controller,
          keyboardType: TextInputType.url,
          label: widget.fieldLabel,
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: TRSpacing.medium),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TRButton(
            key: const ValueKey<String>('relay-endpoint-save'),
            intent: TRIntent.primary,
            loading: _saving,
            loadingLabel: widget.saveLabel,
            onPressed: _saving ? null : _save,
            child: TRText.inherit(widget.saveLabel),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_controller.text.trim());
      if (mounted) Navigator.pop(context);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
