import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/app/app_identity.dart';
import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/features/conversation/application/composer_controller.dart';
import 'package:app/src/features/desktop/infrastructure/desktop_shell.dart';
import 'package:app/src/features/hosts/application/host_controller.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/providers/application/provider_settings_controller.dart';
import 'package:app/src/features/workspace/application/workspace_controller.dart';
import 'package:app/src/shared/presentation/settings_layout.dart';
import 'package:app/src/shared/presentation/tinest_page_shell.dart';
import 'package:app/src/shared/presentation/toast_messenger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Developer maintenance actions that are not tied to any single daemon.
class AdvancedSettingsPage extends ConsumerWidget {
  /// Creates the advanced settings page.
  const new({this.embedded = false, super.key});

  /// Whether the unified settings shell supplies navigation chrome.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    const body = SettingsScaffold(children: <Widget>[_ResetSection()]);
    if (embedded) return body;
    return TinestPageShell(
      appBar: TinestPageHeader(
        title: TRText.inherit(l10n.settingsCategoryAdvanced),
      ),
      body: body,
    );
  }
}

class _ResetSection extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_ResetSection> createState() => _ResetSectionState();
}

class _ResetSectionState extends ConsumerState<_ResetSection> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final erasesDaemonData = ref
        .watch(appServicesProvider)
        .erasesEmbeddedDaemonData;
    return SettingsSection(
      // One row, so a heading over it would only repeat the row's own title.
      // What the reset erases is the group's note: it is the same warning
      // whichever way the row is read, and it belongs under the whole group.
      footer: erasesDaemonData
          ? l10n.advancedResetDescription
          : l10n.advancedResetDescriptionAppOnly,
      children: <Widget>[
        SettingsRow(
          title: TRText.inherit(l10n.advancedResetTitle),
          control: TRButton(
            key: const ValueKey<String>('advanced-settings-reset-button'),
            appearance: TRAppearance.outline,
            intent: TRIntent.danger,
            onPressed: _busy ? null : _confirmAndReset,
            // The verb alone: the row beside it already names what is being
            // reset, and repeating the full name on the button said it twice
            // on one line.
            child: TRText.inherit(
              _busy
                  ? l10n.advancedResetRunning
                  : l10n.advancedResetConfirmAccept,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmAndReset() async {
    final confirmed = await showTRDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return TRAlertDialog(
          key: const ValueKey<String>('advanced-reset-confirm-dialog'),
          title: TRText.inherit(l10n.advancedResetConfirmTitle),
          content: TRText.inherit(l10n.advancedResetConfirmBody),
          actions: <TRButton>[
            TRButton(
              key: const ValueKey<String>('advanced-reset-confirm-cancel'),
              appearance: TRAppearance.ghost,
              onPressed: () => Navigator.pop(context, false),
              child: TRText.inherit(l10n.commonCancel),
            ),
            TRButton(
              key: const ValueKey<String>('advanced-reset-confirm-accept'),
              intent: TRIntent.danger,
              onPressed: () => Navigator.pop(context, true),
              child: TRText.inherit(l10n.advancedResetConfirmAccept),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    final autostart = ref.read(autostartProvider);
    setState(() => _busy = true);
    try {
      await ref
          .read(hostRegistryControllerProvider.notifier)
          .resetToFactoryDefaults();
      if (!mounted) return;
      // The registry survives a reset; only the caches keyed off erased daemon
      // state are stale. Invalidating the registry itself would close the
      // daemon that was just started.
      ref
        ..invalidate(selectionRestoreControllerProvider)
        ..invalidate(workspaceCatalogControllerProvider)
        ..invalidate(sessionComposerDraftControllerProvider)
        ..invalidate(providerSettingsControllerProvider);
      // Restored defaults re-enable the login item, so the operating system
      // registration has to follow rather than silently disagree.
      final settings = ref
          .read(hostRegistryControllerProvider)
          .asData
          ?.value
          .settings;
      if (settings != null) {
        await autostart?.apply(
          enabled: settings.startAtBoot,
          minimized: settings.startMinimizedAtBoot,
        );
      }
      if (!mounted) return;
      // Reported rather than shown in place, because the next line leaves this
      // screen for the workspace and a banner here would go with it.
      ref
          .read(toastMessengerProvider)
          .success(AppLocalizations.of(context).advancedResetDone);
      const WorkspaceHomeRoute().go(context);
    } on FactoryResetFailure catch (failure) {
      if (!mounted) return;
      // Read after the await: a reset clears the language override, so the
      // localizations in scope before it may no longer be the active ones.
      final l10n = AppLocalizations.of(context);
      ref
          .read(toastMessengerProvider)
          .failure(
            l10n.advancedResetFailedTitle,
            error: switch (failure.reason) {
              FactoryResetFailureReason.daemonStillRunning =>
                l10n.advancedResetFailedDaemonRunning(AppIdentity.displayName),
              FactoryResetFailureReason.filesystem =>
                l10n.advancedResetFailedFilesystem(failure.message),
              FactoryResetFailureReason.incomplete =>
                l10n.advancedResetFailedIncomplete(AppIdentity.displayName),
            },
          );
    } on Object catch (error) {
      // A reset that failed for a reason it does not model is still a reset
      // that did not happen, and saying nothing would read as success.
      if (!mounted) return;
      ref
          .read(toastMessengerProvider)
          .failure(
            AppLocalizations.of(context).advancedResetFailedTitle,
            error: error,
          );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
