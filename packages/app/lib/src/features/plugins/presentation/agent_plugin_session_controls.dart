import 'dart:async';

import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/features/plugins/application/plugin_settings_controller.dart';
import 'package:app/src/shared/presentation/tinest_select_presentation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Renders the session controls of Agent-ordered extension plugins.
class AgentPluginSessionControls extends ConsumerWidget {
  /// Creates the host-owned composer controls for one existing session.
  const new({
    required this.hostId,
    required this.sessionId,
    required this.agent,
    super.key,
  });

  /// Daemon profile owning the session.
  final String hostId;

  /// Durable session whose control values are read and written.
  final String sessionId;

  /// Agent whose extension order activates the controls.
  final AgentDefinitionDto agent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(pluginSettingsControllerProvider(hostId));
    return catalog.when(
      skipLoadingOnRefresh: true,
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (state) {
        final byId = <String, PluginDescriptorDto>{
          for (final plugin in state.plugins) plugin.id: plugin,
        };
        final controls =
            <
              ({PluginDescriptorDto plugin, PluginContributionDto contribution})
            >[];
        for (final extensionId in agent.extensionIds) {
          final pluginId = pluginIdForContribution(extensionId);
          final plugin = byId[pluginId];
          if (plugin == null) continue;
          for (final contribution in plugin.contributions) {
            if (contribution.kind == PluginContributionKind.sessionControl) {
              controls.add((plugin: plugin, contribution: contribution));
            }
          }
        }
        if (controls.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: TRSpacing.small,
          children: <Widget>[
            for (final control in controls)
              _PluginSessionControl(
                hostId: hostId,
                sessionId: sessionId,
                plugin: control.plugin,
                contribution: control.contribution,
              ),
          ],
        );
      },
    );
  }
}

class _PluginSessionControl extends ConsumerStatefulWidget {
  const new({
    required this.hostId,
    required this.sessionId,
    required this.plugin,
    required this.contribution,
  });

  final String hostId;
  final String sessionId;
  final PluginDescriptorDto plugin;
  final PluginContributionDto contribution;

  @override
  ConsumerState<_PluginSessionControl> createState() =>
      _PluginSessionControlState();
}

class _PluginSessionControlState extends ConsumerState<_PluginSessionControl> {
  bool _mutating = false;
  Object? _mutationError;

  PluginSessionControlControllerProvider get _provider =>
      pluginSessionControlControllerProvider(
        widget.hostId,
        widget.sessionId,
        widget.plugin.id,
        widget.contribution.id,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(_provider);
    return value.when(
      skipLoadingOnRefresh: true,
      loading: () => TRProgress(label: l10n.pluginSessionControlLoading),
      error: (error, _) => TRAlert(
        variant: TRStatusVariant.danger,
        title: TRText.inherit(l10n.pluginSessionControlLoadFailed),
        description: TRText.inherit('$error'),
      ),
      data: (control) {
        final label =
            control.metadata['label']?.toString() ??
            widget.contribution.metadata['label']?.toString() ??
            widget.contribution.id;
        final description =
            control.metadata['description']?.toString() ??
            widget.contribution.metadata['description']?.toString();
        final type = control.schema['type'];
        final field = switch (type) {
          'boolean' when control.value is bool => TRField(
            label: label,
            description: description,
            disabled: _mutating,
            control: TRSwitch(
              key: ValueKey<String>(
                'plugin-session-control-${widget.contribution.id}',
              ),
              checked: control.value! as bool,
              semanticLabel: label,
              disabled: _mutating,
              onCheckedChange: (next) => unawaited(_setValue(next)),
            ),
          ),
          'string'
              when control.schema['enum'] is List<Object?> &&
                  control.value is String =>
            TRField(
              label: label,
              description: description,
              disabled: _mutating,
              control: TRSelect<String>.controlled(
                searchable: true,
                presentation: TinestSelectPresentation.resolve(context),
                key: ValueKey<String>(
                  'plugin-session-control-${widget.contribution.id}',
                ),
                value: control.value! as String,
                enabled: !_mutating,
                items: <TRSelectItem<String>>[
                  for (final option
                      in (control.schema['enum']! as List<Object?>)
                          .whereType<String>())
                    TRSelectItem<String>(value: option, label: option),
                ],
                onValueChange: (next) {
                  if (next != null) unawaited(_setValue(next));
                },
              ),
            ),
          _ => TRAlert(
            variant: TRStatusVariant.warning,
            title: TRText.inherit(l10n.pluginSessionControlUnsupported),
            description: TRText.inherit(widget.contribution.id),
          ),
        };
        if (_mutationError case final error?) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: TRSpacing.small,
            children: <Widget>[
              field,
              TRAlert(
                variant: TRStatusVariant.danger,
                title: TRText.inherit(l10n.pluginSessionControlSaveFailed),
                description: TRText.inherit('$error'),
              ),
            ],
          );
        }
        return field;
      },
    );
  }

  Future<void> _setValue(Object? value) async {
    if (_mutating) return;
    setState(() {
      _mutating = true;
      _mutationError = null;
    });
    try {
      await ref.read(_provider.notifier).setValue(value);
    } on Object catch (error) {
      if (mounted) setState(() => _mutationError = error);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }
}
