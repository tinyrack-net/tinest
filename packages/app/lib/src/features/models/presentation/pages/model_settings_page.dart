import 'dart:async';

import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/features/models/application/model_settings_controller.dart';
import 'package:app/src/features/providers/application/model_picker_options.dart';
import 'package:app/src/features/providers/application/provider_settings_controller.dart';
import 'package:app/src/features/providers/application/session_model_options.dart';
import 'package:app/src/shared/presentation/blocked_control.dart';
import 'package:app/src/shared/presentation/model_picker.dart';
import 'package:app/src/shared/presentation/settings_layout.dart';
import 'package:app/src/shared/presentation/tinest_icons.dart';
import 'package:app/src/shared/presentation/toast_messenger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Daemon-global concrete default model settings.
class ModelSettingsPage extends ConsumerWidget {
  /// Creates model settings for [hostId].
  const ModelSettingsPage({required this.hostId, super.key});

  /// Selected daemon host.
  final String hostId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = modelSettingsControllerProvider(hostId);
    final settings = ref.watch(provider);
    final providerState = ref.watch(providerSettingsControllerProvider(hostId));
    return SettingsAsyncContent<DaemonModelSettingsDto>(
      state: settings,
      loading: SettingsSkeletonLayout.form(
        semanticLabel: AppLocalizations.of(context).settingsLoading,
      ),
      error: (error, stackTrace) => SettingsErrorState(
        key: const ValueKey<String>('model-settings-error'),
        error: error,
        onRetry: () => ref.invalidate(provider),
      ),
      data: (settings) {
        final l10n = AppLocalizations.of(context);
        final providers = providerState.value;
        final connections =
            providers?.connections ?? const <ProviderConnectionDto>[];
        final models =
            providers?.models ?? const <String, List<ProviderModelDto>>{};
        final first = firstUsableModel(connections, models);
        final current = settings.defaultModel;
        final unavailable =
            providerState.hasValue &&
            current != null &&
            !isRunnableSelection(current, connections, models);
        final blocked = providerState.hasValue && first == null;
        final select = AsyncModelSelect(
          key: const ValueKey<String>('daemon-default-model'),
          loadKey: hostId,
          loadOptions: ref.read(modelPickerOptionsLoaderProvider(hostId)),
          currentSelection: current,
          placeholder: current?.modelId ?? l10n.composerModel,
          enabled: !blocked,
          appearance: TRFieldAppearance.ghost,
          leading: Icon(blocked ? TinestIcons.lock : TinestIcons.memory),
          onValueChange: (option) => unawaited(
            _set(context, ref, option.selection),
          ),
        );
        return SettingsScaffold(
          children: <Widget>[
            SettingsSection(
              // The row names the setting and shows the model it is set to,
              // so a heading and a title would say it twice over.
              footer: l10n.modelSettingsSectionDescription,
              banner: unavailable
                  ? TRAlert(
                      key: const ValueKey<String>(
                        'model-settings-unavailable',
                      ),
                      title: TRText.inherit(
                        l10n.modelSettingsUnavailableTitle,
                      ),
                      description: TRText.inherit(
                        l10n.modelSettingsUnavailableDescription(
                          current.modelId,
                        ),
                      ),
                      icon: const Icon(TinestIcons.warning),
                      variant: TRStatusVariant.warning,
                    )
                  : null,
              children: <Widget>[
                SettingsRow(
                  title: TRText.inherit(l10n.modelSettingsSection),
                  controlOwnsFocus: true,
                  control: blocked
                      ? BlockedControl(
                          label: l10n.modelSettingsSection,
                          hint: l10n.composerConnectProviderFirst,
                          onTap: () => ref
                              .read(toastMessengerProvider)
                              .info(
                                l10n.composerConnectProviderFirst,
                                id: 'model-selector-provider-required',
                              ),
                          child: select,
                        )
                      : select,
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
    WidgetRef ref,
    ModelSelectionDto model,
  ) async {
    final l10n = AppLocalizations.of(context);
    await ref
        .read(toastMessengerProvider)
        .run(
          () => ref
              .read(modelSettingsControllerProvider(hostId).notifier)
              .setDefaultModel(model),
          failure: l10n.modelSettingsSaveFailed,
          success: l10n.commonSaved,
          id: 'model-settings-default-model',
        );
  }
}
