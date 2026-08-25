import 'dart:async';

import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/features/permissions/application/permission_settings_controller.dart';
import 'package:app/src/shared/presentation/permission_picker.dart';
import 'package:app/src/shared/presentation/settings_layout.dart';
import 'package:app/src/shared/presentation/toast_messenger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Daemon-global default permission settings.
class PermissionSettingsPage extends ConsumerStatefulWidget {
  /// Creates permission settings for [hostId].
  const PermissionSettingsPage({required this.hostId, super.key});

  /// Selected daemon host.
  final String hostId;

  @override
  ConsumerState<PermissionSettingsPage> createState() =>
      _PermissionSettingsPageState();
}

class _PermissionSettingsPageState
    extends ConsumerState<PermissionSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final provider = permissionSettingsControllerProvider(widget.hostId);
    final state = ref.watch(provider);
    return SettingsAsyncContent<PermissionSettingsDto>(
      state: state,
      loading: SettingsSkeletonLayout.form(
        semanticLabel: AppLocalizations.of(context).settingsLoading,
      ),
      error: (error, stackTrace) => SettingsErrorState(
        key: const ValueKey<String>('permission-settings-error'),
        error: error,
        onRetry: () => ref.invalidate(provider),
      ),
      data: (settings) {
        final l10n = AppLocalizations.of(context);
        return SettingsScaffold(
          children: <Widget>[
            SettingsSection(
              // The row names the setting and shows what it is set to, so a
              // heading over one row would only say it a second time. What
              // each mode actually allows is on the options themselves.
              footer: l10n.permissionSettingsSectionDescription,
              children: <Widget>[
                SettingsRow(
                  title: TRText.inherit(l10n.permissionSettingsSection),
                  controlOwnsFocus: true,
                  control: PermissionSelect(
                    key: const ValueKey<String>(
                      'permission-settings-change',
                    ),
                    currentMode: settings.defaultMode,
                    appearance: TRFieldAppearance.ghost,
                    onValueChange: (mode) => unawaited(_set(context, mode)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _set(
    BuildContext context,
    PermissionMode mode,
  ) async {
    if (!context.mounted) return;
    // Resolved before the write: the messenger keeps no context of its own,
    // which is what lets its report outlive this screen.
    final l10n = AppLocalizations.of(context);
    await ref
        .read(toastMessengerProvider)
        .run(
          () => ref
              .read(
                permissionSettingsControllerProvider(widget.hostId).notifier,
              )
              .setDefaultMode(mode),
          failure: l10n.permissionSettingsSaveFailed,
          success: l10n.commonSaved,
          id: 'permission-settings-default-mode',
        );
  }
}
