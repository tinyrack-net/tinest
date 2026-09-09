import 'dart:async';

import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/app/app_identity.dart';
import 'package:app/src/features/desktop/infrastructure/desktop_shell.dart';
import 'package:app/src/features/hosts/application/host_controller.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/shared/presentation/settings_layout.dart';
import 'package:app/src/shared/presentation/tinest_page_shell.dart';
import 'package:app/src/shared/presentation/tinest_selection_row.dart';
import 'package:app/src/shared/presentation/toast_messenger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Languages the app offers, keyed by language tag, in menu order.
///
/// Each one is named in its own script rather than in the active UI language,
/// so a reader who cannot read the current language can still find their own.
const Map<String, String> languageEndonyms = <String, String>{
  'ko': '한국어',
  'ja': '日本語',
  'en': 'English',
};

/// App-wide preferences that do not belong to any single daemon.
class GeneralSettingsPage extends ConsumerWidget {
  /// Creates the general settings page.
  const new({this.embedded = false, super.key});

  /// Whether the unified settings shell supplies navigation chrome.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final body = SettingsAsyncContent<HostRegistryState>(
      state: ref.watch(hostRegistryControllerProvider),
      loading: SettingsSkeletonLayout.form(semanticLabel: l10n.settingsLoading),
      error: (error, _) => SettingsErrorState(
        key: const ValueKey<String>('general-settings-error'),
        error: error,
        onRetry: () => ref.invalidate(hostRegistryControllerProvider),
      ),
      // Appearance and language are one preference each, so a heading and a
      // group boundary apiece announced three groups where there is one
      // subject: how the app presents itself.
      data: (_) => const SettingsScaffold(
        children: <Widget>[_PresentationSection(), _StartupSection()],
      ),
    );
    if (embedded) return body;
    return TinestPageShell(
      appBar: TinestPageHeader(
        title: TRText.inherit(l10n.settingsCategoryGeneral),
      ),
      body: body,
    );
  }
}

/// Login-item preferences, shown only where the app can register one.
class _StartupSection extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final autostart = ref.watch(autostartProvider);
    // Mobile and plain widget tests have no login items, so offering a switch
    // that silently does nothing would be worse than offering none.
    if (autostart == null) return const SizedBox.shrink();
    final settings = ref.watch(hostRegistryControllerProvider).value?.settings;
    final controller = ref.read(hostRegistryControllerProvider.notifier);
    return SettingsSection(
      title: l10n.generalStartupSection,
      // The tray notice explains the group rather than either switch, so it
      // sits under both once instead of above them as a preamble.
      footer: l10n.generalStartupCloseNotice(AppIdentity.displayName),
      children: <Widget>[
        TinestSwitchRow(
          key: const ValueKey<String>('general-settings-start-at-boot'),
          title: TRText.inherit(l10n.generalStartupAtBootLabel),
          value: settings?.startAtBoot ?? true,
          onChanged: settings == null
              ? null
              : (enabled) => unawaited(
                  ref
                      .read(toastMessengerProvider)
                      .run(
                        () async {
                          await controller.setStartAtBoot(enabled: enabled);
                          await autostart.apply(
                            enabled: enabled,
                            minimized: settings.startMinimizedAtBoot,
                          );
                        },
                        failure: l10n.generalStartupFailed,
                        // The switch snaps back to the stored value on
                        // its own, so only the failure needs saying.
                        id: 'general-settings-startup',
                      ),
                ),
        ),
        TinestSwitchRow(
          key: const ValueKey<String>('general-settings-start-minimized'),
          title: TRText.inherit(l10n.generalStartupMinimizedLabel),
          // The stored preference keeps showing while it is out of reach.
          // Blanking it would claim the choice had been changed, and the
          // switch would then jump back on its own the moment login starts
          // again.
          value: settings?.startMinimizedAtBoot ?? true,
          // Only a login launch can start minimized, so the choice is
          // meaningless while the app is not registered to launch.
          onChanged: settings == null || !settings.startAtBoot
              ? null
              : (minimized) => unawaited(
                  ref
                      .read(toastMessengerProvider)
                      .run(
                        () async {
                          await controller.setStartMinimizedAtBoot(
                            enabled: minimized,
                          );
                          await autostart.apply(
                            enabled: settings.startAtBoot,
                            minimized: minimized,
                          );
                        },
                        failure: l10n.generalStartupFailed,
                        id: 'general-settings-startup',
                      ),
                ),
        ),
      ],
    );
  }
}

/// How the app presents itself: its theme and the language it speaks.
class _PresentationSection extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(hostRegistryControllerProvider).value?.settings;
    final controller = ref.read(hostRegistryControllerProvider.notifier);
    return SettingsSection(
      // No heading: the page is already titled General, and a heading over
      // two rows that between them are the page's subject only repeats it.
      // Startup keeps its heading because it is a departure from that subject.
      children: <Widget>[
        TinestChoiceRow<AppThemeMode>(
          selectKey: const ValueKey<String>('general-settings-theme-mode'),
          title: TRText.inherit(l10n.generalAppearanceLabel),
          semanticLabel: l10n.generalAppearanceLabel,
          searchPlaceholder: l10n.selectSearchPlaceholder,
          noResultsText: l10n.selectNoResults,
          value: settings?.themeMode ?? AppThemeMode.system,
          items: <TRSelectItem<AppThemeMode>>[
            for (final mode in AppThemeMode.values)
              TRSelectItem<AppThemeMode>(
                value: mode,
                label: _appearanceLabel(l10n, mode),
              ),
          ],
          // Every item carries a mode, so a cleared field can only mean the
          // app should go back to following the system.
          onChanged: settings == null
              ? null
              : (mode) => unawaited(
                  ref
                      .read(toastMessengerProvider)
                      .run(
                        () => controller.setThemeMode(
                          mode ?? AppThemeMode.system,
                        ),
                        failure: l10n.generalAppearanceFailed,
                        // A theme that changed is its own confirmation;
                        // success would be noise.
                        id: 'general-settings-theme-mode',
                      ),
                ),
        ),
        TinestChoiceRow<String?>(
          selectKey: const ValueKey<String>('general-settings-language'),
          title: TRText.inherit(l10n.generalLanguageLabel),
          semanticLabel: l10n.generalLanguageLabel,
          value: settings?.localeTag,
          placeholder: l10n.generalLanguageSystem,
          searchPlaceholder: l10n.selectSearchPlaceholder,
          noResultsText: l10n.selectNoResults,
          items: <TRSelectItem<String?>>[
            // A null tag follows the system locale.
            TRSelectItem<String?>(
              value: null,
              label: l10n.generalLanguageSystem,
            ),
            for (final entry in languageEndonyms.entries)
              TRSelectItem<String?>(value: entry.key, label: entry.value),
          ],
          onChanged: settings == null
              ? null
              : (tag) => unawaited(
                  ref
                      .read(toastMessengerProvider)
                      .run(
                        () => controller.setLocaleTag(tag),
                        failure: l10n.generalLanguageFailed,
                        id: 'general-settings-language',
                      ),
                ),
        ),
      ],
    );
  }
}

String _appearanceLabel(AppLocalizations l10n, AppThemeMode mode) =>
    switch (mode) {
      AppThemeMode.system => l10n.generalAppearanceSystem,
      AppThemeMode.light => l10n.generalAppearanceLight,
      AppThemeMode.dark => l10n.generalAppearanceDark,
    };
