import 'dart:async';

import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/features/terminals/application/terminals_controller.dart';
import 'package:app/src/features/workspace/application/workspace_controller.dart';
import 'package:app/src/shared/presentation/settings_layout.dart';
import 'package:app/src/shared/presentation/tinest_icons.dart';
import 'package:app/src/shared/presentation/tinest_layout_metrics.dart';
import 'package:app/src/shared/presentation/toast_messenger.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Splits a hook text field into one command per non-blank line.
List<String> parseHookCommands(String value) => <String>[
  for (final line in value.split('\n'))
    if (line.trim().isNotEmpty) line.trim(),
];

/// Renders configured hook commands as editable text.
String formatHookCommands(List<String> commands) => commands.join('\n');

/// Per-project settings manager for one connected daemon.
class ProjectSettingsPage extends ConsumerWidget {
  /// Creates a project settings page.
  const new({
    required this.hostId,
    required this.paneController,
    required this.slot,
    super.key,
  });

  /// App-local daemon profile identifier.
  final String hostId;

  /// Selection shared by the collection and detail scaffold slots.
  final ProjectSettingsPaneController paneController;

  /// Which scaffold slot this widget supplies.
  final SettingsPaneSlot slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final widthClass = settingsAdaptiveWidthClassOf(context);
    final showsSplit =
        widthClass == TRAdaptiveWidthClass.large ||
        widthClass == TRAdaptiveWidthClass.extraLarge;
    final state = ref.watch(workspaceCatalogControllerProvider);
    // Catalogs merge per host, so this host's section can still be on its way
    // even though the unified state already has a value. An empty project
    // list must not render for a catalog that has simply not arrived.
    if (state.value?.isHostPending(hostId) ?? false) {
      return settingsPaneSkeleton(
        slot,
        semanticLabel: AppLocalizations.of(context).settingsLoading,
      );
    }
    return ListenableBuilder(
      listenable: paneController,
      builder: (context, _) =>
          SettingsAsyncContent<UnifiedWorkspaceCatalogState>(
            state: state,
            loading: settingsPaneSkeleton(
              slot,
              semanticLabel: AppLocalizations.of(context).settingsLoading,
            ),
            error: (error, _) => slot == SettingsPaneSlot.collection
                ? SettingsCollectionErrorState(
                    title: AppLocalizations.of(context).projectSettingsHeading,
                    error: error,
                    onRetry: () =>
                        ref.invalidate(workspaceCatalogControllerProvider),
                  )
                : SettingsEmptyState(
                    title: AppLocalizations.of(context)
                        .projectSettingsSelectProject,
                    icon: const Icon(TinestIcons.folder),
                  ),
            data: (value) {
              final projects = _projects(value);
              final selectedId = paneController.selection;
              final selected = projects
                  .where((project) => project.id == selectedId)
                  .firstOrNull;
              if (slot == SettingsPaneSlot.collection &&
                  showsSplit &&
                  paneController.canAutoSelect &&
                  projects.isNotEmpty &&
                  selected == null) {
                _scheduleInitialSelection(projects.first.id);
              } else if (paneController.hasDetail && selected == null) {
                _scheduleCollection();
              }
              return switch (slot) {
                SettingsPaneSlot.collection => _ProjectList(
                  projects: projects,
                  selectedId: selectedId,
                  onSelected: paneController.showDetail,
                ),
                SettingsPaneSlot.detail =>
                  selected == null
                      ? SettingsEmptyState(
                          title: AppLocalizations.of(context)
                              .projectSettingsSelectProject,
                          icon: const Icon(TinestIcons.folder),
                        )
                      : _ProjectEditor(
                          key: ValueKey<String>('$hostId ${selected.id}'),
                          hostId: hostId,
                          workspace: selected,
                        ),
              };
            },
          ),
    );
  }

  List<WorkspaceDto> _projects(UnifiedWorkspaceCatalogState state) =>
      <WorkspaceDto>[...?state.catalogs[hostId]?.workspaces]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  void _scheduleInitialSelection(String projectId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      paneController.showInitialDetail(projectId);
    });
  }

  void _scheduleCollection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      paneController.showCollection();
    });
  }
}

/// Owns the selected project independently from either rendered pane slot.
class ProjectSettingsPaneController extends SettingsPaneController<String> {
  /// Creates a project pane controller.
  new();
}

class _ProjectList extends StatelessWidget {
  const new({
    required this.projects,
    required this.selectedId,
    required this.onSelected,
  });

  final List<WorkspaceDto> projects;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsDestinationScaffold(
      title: TRText.inherit(l10n.projectSettingsHeading),
      child: projects.isEmpty
          ? SettingsEmptyState(
              title: l10n.projectSettingsNoProjects,
              icon: const Icon(TinestIcons.folder),
            )
          : SettingsCollectionList(
              children: <Widget>[
                TRTreeNav<String>.controlled(
                  value: selectedId,
                  itemSpacing: TRSpacing.extraSmall,
                  onValueChange: (projectId) {
                    if (projectId != null) onSelected(projectId);
                  },
                  items: <TRTreeNavItem<String>>[
                    for (final project in projects)
                      TRTreeNavLeaf<String>(
                        value: project.id,
                        showDisclosureIndicator: true,
                        leading: Icon(
                          project.kind == WorkspaceKind.git
                              ? TinestIcons.worktree
                              : TinestIcons.folder,
                        ),
                        label: TRText.inherit(project.name),
                        description: TRText.inherit(project.rootPath),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _ProjectEditor extends ConsumerStatefulWidget {
  const new({required this.hostId, required this.workspace, super.key});

  final String hostId;
  final WorkspaceDto workspace;

  @override
  ConsumerState<_ProjectEditor> createState() => _ProjectEditorState();
}

class _ProjectEditorState extends ConsumerState<_ProjectEditor> {
  final TextEditingController _setup = TextEditingController();
  final TextEditingController _teardown = TextEditingController();
  final TextEditingController _shellExecutable = TextEditingController();
  final TextEditingController _shellArguments = TextEditingController();
  final TextEditingController _hostShellExecutable = TextEditingController();
  final TextEditingController _hostShellArguments = TextEditingController();
  bool _loaded = false;
  bool _hostShellLoaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _setup.dispose();
    _teardown.dispose();
    _shellExecutable.dispose();
    _shellArguments.dispose();
    _hostShellExecutable.dispose();
    _hostShellArguments.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = projectSettingsControllerProvider(
      widget.hostId,
      widget.workspace.id,
    );
    final state = ref.watch(provider);
    final hostShellProvider = hostShellSettingsControllerProvider(
      widget.hostId,
    );
    final hostShellState = ref.watch(hostShellProvider);
    return SettingsAsyncContent<ProjectSettingsResultDto>(
      state: state,
      loading: SettingsSkeletonLayout.form(semanticLabel: l10n.settingsLoading),
      error: (error, _) => SettingsErrorState(
        error: error,
        onRetry: () => ref.invalidate(provider),
      ),
      data: (value) {
        if (!_loaded) {
          _loaded = true;
          _setup.text = formatHookCommands(value.settings.setup);
          _teardown.text = formatHookCommands(value.settings.teardown);
          _shellExecutable.text = value.settings.shell?.executable ?? '';
          _shellArguments.text = formatHookCommands(
            value.settings.shell?.arguments ?? const <String>[],
          );
        }
        if (!_hostShellLoaded && hostShellState.hasValue) {
          _hostShellLoaded = true;
          final shell = hostShellState.requireValue;
          _hostShellExecutable.text = shell?.executable ?? '';
          _hostShellArguments.text = formatHookCommands(
            shell?.arguments ?? const <String>[],
          );
        }
        return SettingsDestinationScaffold(
          title: TRText.inherit(widget.workspace.name),
          contentMaxWidth: TinestLayoutMetrics.settingsContentMaxWidth,
          actions: <TRIconButton>[
            TRIconButton(
              appearance: TRAppearance.ghost,
              label: l10n.projectSettingsCopyPath,
              onPressed: () => unawaited(
                ref
                    .read(toastMessengerProvider)
                    .run(
                      () => Clipboard.setData(
                        ClipboardData(text: value.sourcePath),
                      ),
                      failure: l10n.commonActionFailed,
                      success: l10n.commonCopied,
                      id: 'project-settings-copy-path',
                    ),
              ),
              icon: const Icon(TinestIcons.copy),
            ),
          ],
          formActions: <Widget>[
            TRButton(
              key: const ValueKey<String>('project-settings-save'),
              intent: TRIntent.primary,
              onPressed: _saving || !hostShellState.hasValue ? null : _save,
              child: TRText.inherit(
                _saving ? l10n.commonSaving : l10n.commonSave,
              ),
            ),
          ],
          child: SettingsScaffold(
            children: <Widget>[
              SettingsSection.form(
                title: l10n.projectSettingsHookHeading,
                description: l10n.projectSettingsHookHelp,
                children: <Widget>[
                  TRTextField(
                    controller: _setup,
                    enabled: !_saving,
                    minLines: 3,
                    maxLines: 8,
                    label: l10n.projectSettingsSetup,
                    // Hook placeholders are shell commands, not prose: the
                    // example has to stay something a shell would accept.
                    placeholder: 'npm install',
                  ),
                  TRTextField(
                    controller: _teardown,
                    enabled: !_saving,
                    minLines: 3,
                    maxLines: 8,
                    label: l10n.projectSettingsTeardown,
                    placeholder: 'docker compose down',
                  ),
                ],
              ),
              SettingsSection.form(
                title: l10n.projectSettingsShellHeading,
                description: l10n.projectSettingsShellHelp,
                children: <Widget>[
                  TRTextField(
                    key: const ValueKey<String>('project-shell-executable'),
                    controller: _shellExecutable,
                    enabled: !_saving,
                    label: l10n.projectSettingsShellExecutable,
                    placeholder: '/bin/zsh',
                  ),
                  TRTextField(
                    key: const ValueKey<String>('project-shell-arguments'),
                    controller: _shellArguments,
                    enabled: !_saving,
                    minLines: 2,
                    maxLines: 4,
                    label: l10n.projectSettingsShellArguments,
                    placeholder: '-l',
                  ),
                ],
              ),
              SettingsSection.form(
                title: l10n.projectSettingsHostShellHeading,
                description: l10n.projectSettingsHostShellHelp,
                banner: hostShellState.hasError
                    ? TRAlert(
                        title: TRText.inherit(
                          l10n.settingsRefreshFailed('${hostShellState.error}'),
                        ),
                        variant: TRStatusVariant.danger,
                      )
                    : null,
                children: hostShellState.hasValue
                    ? <Widget>[
                        TRTextField(
                          key: const ValueKey<String>('host-shell-executable'),
                          controller: _hostShellExecutable,
                          enabled: !_saving,
                          label: l10n.projectSettingsShellExecutable,
                          placeholder: '/bin/zsh',
                        ),
                        TRTextField(
                          key: const ValueKey<String>('host-shell-arguments'),
                          controller: _hostShellArguments,
                          enabled: !_saving,
                          minLines: 2,
                          maxLines: 4,
                          label: l10n.projectSettingsShellArguments,
                          placeholder: '-l',
                        ),
                      ]
                    : <Widget>[
                        SettingsSkeletonLayout.overlay(
                          semanticLabel: l10n.settingsLoading,
                        ),
                      ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    // Every outcome runs through here, so the button cannot be left disabled by
    // a failure the previous catch clause did not name.
    await ref
        .read(toastMessengerProvider)
        .run(
          _write,
          failure: l10n.projectSettingsSaveFailed,
          success: l10n.commonSaved,
          id: 'project-settings-save',
        );
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _write() async {
    {
      final hostShell = _hostShellExecutable.text.trim().isEmpty
          ? null
          : ShellSpecDto(
              executable: _hostShellExecutable.text.trim(),
              arguments: parseHookCommands(_hostShellArguments.text),
            );
      await ref
          .read(hostShellSettingsControllerProvider(widget.hostId).notifier)
          .save(hostShell);
      await ref
          .read(
            projectSettingsControllerProvider(
              widget.hostId,
              widget.workspace.id,
            ).notifier,
          )
          .save(
            ProjectSettingsDto(
              setup: parseHookCommands(_setup.text),
              teardown: parseHookCommands(_teardown.text),
              shell: _shellExecutable.text.trim().isEmpty
                  ? null
                  : ShellSpecDto(
                      executable: _shellExecutable.text.trim(),
                      arguments: parseHookCommands(_shellArguments.text),
                    ),
            ),
          );
    }
  }
}
