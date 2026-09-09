import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/features/skills/application/skills_controller.dart';
import 'package:app/src/features/workspace/application/workspace_controller.dart';
import 'package:app/src/shared/presentation/settings_layout.dart';
import 'package:app/src/shared/presentation/tinest_selection_row.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Read-only catalog of the effective skills offered by one daemon.
class SkillSettingsPage extends ConsumerStatefulWidget {
  /// Creates a skill catalog.
  const new({
    required this.hostId,
    this.workspaceId,
    this.onWorkspaceChanged,
    super.key,
  });

  /// App-local daemon profile identifier.
  final String hostId;

  /// Project whose own effective skills are shown, or null for global skills.
  final String? workspaceId;

  /// Replaces the route when the user changes catalog scope.
  final ValueChanged<String?>? onWorkspaceChanged;

  @override
  ConsumerState<SkillSettingsPage> createState() => _SkillSettingsPageState();
}

class _SkillSettingsPageState extends ConsumerState<SkillSettingsPage> {
  String? _normalizationScheduledFor;

  @override
  void didUpdateWidget(SkillSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hostId != widget.hostId ||
        oldWidget.workspaceId != widget.workspaceId) {
      _normalizationScheduledFor = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogs = ref.watch(workspaceCatalogControllerProvider);
    final catalogState = catalogs.value;
    final catalog = catalogState?.catalogs[widget.hostId];
    if (catalogState == null || catalogState.isHostPending(widget.hostId)) {
      return SettingsSkeletonLayout.form(
        semanticLabel: AppLocalizations.of(context).settingsLoading,
      );
    }

    final projects =
        (catalog?.workspaces ?? const <WorkspaceDto>[])
            .where((workspace) => workspace.kind != WorkspaceKind.home)
            .toList(growable: false)
          ..sort(_compareProjects);
    final workspaceId = widget.workspaceId;
    final selectedProject = workspaceId == null
        ? null
        : projects
              .where((workspace) => workspace.id == workspaceId)
              .firstOrNull;

    // A route may outlive a removed project or arrive from a stale deep link.
    // Wait for the daemon's catalog before replacing it so the invalid project
    // is never sent to prompts.listSkills even for one transient frame.
    if (workspaceId != null && selectedProject == null) {
      _scheduleGlobalNormalization(workspaceId);
      return SettingsSkeletonLayout.form(
        semanticLabel: AppLocalizations.of(context).settingsLoading,
      );
    }

    final view = workspaceId == null
        ? SkillListView.global
        : SkillListView.project;
    final provider = skillsControllerProvider(widget.hostId, view, workspaceId);
    final state = ref.watch(provider);
    return SettingsAsyncContent<List<SkillSummaryDto>>(
      state: state,
      loading: SettingsSkeletonLayout.form(
        semanticLabel: AppLocalizations.of(context).settingsLoading,
      ),
      error: (error, _) => _SkillCatalogBody(
        projects: projects,
        workspaceId: workspaceId,
        error: error,
        onRetry: () => ref.invalidate(provider),
        onWorkspaceChanged: widget.onWorkspaceChanged,
      ),
      data: (skills) => _SkillCatalogBody(
        projects: projects,
        workspaceId: workspaceId,
        skills: skills,
        onWorkspaceChanged: widget.onWorkspaceChanged,
      ),
    );
  }

  void _scheduleGlobalNormalization(String invalidWorkspaceId) {
    if (_normalizationScheduledFor == invalidWorkspaceId) return;
    _normalizationScheduledFor = invalidWorkspaceId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.workspaceId != invalidWorkspaceId) return;
      widget.onWorkspaceChanged?.call(null);
    });
  }
}

int _compareProjects(WorkspaceDto left, WorkspaceDto right) {
  final byName = left.name.toLowerCase().compareTo(right.name.toLowerCase());
  if (byName != 0) return byName;
  return left.rootPath.compareTo(right.rootPath);
}

class _SkillCatalogBody extends StatelessWidget {
  const new({
    required this.projects,
    required this.workspaceId,
    required this.onWorkspaceChanged,
    this.skills,
    this.error,
    this.onRetry,
  });

  final List<WorkspaceDto> projects;
  final String? workspaceId;
  final ValueChanged<String?>? onWorkspaceChanged;
  final List<SkillSummaryDto>? skills;
  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsScaffold(
      children: <Widget>[
        if (projects.isNotEmpty)
          SettingsSection(
            // What the scope governs explains the whole group rather than
            // sitting under the one row that already names it.
            footer: l10n.skillSettingsScopeHint,
            children: <Widget>[
              TinestChoiceRow<String?>(
                selectKey: const ValueKey<String>('skill-scope-select'),
                title: TRText.inherit(l10n.skillSettingsScope),
                semanticLabel: l10n.skillSettingsScope,
                value: workspaceId,
                searchPlaceholder: l10n.skillSettingsProjectSearch,
                noResultsText: l10n.skillSettingsProjectNoMatch,
                items: <TRSelectItem<String?>>[
                  TRSelectItem<String?>(
                    value: null,
                    label: l10n.skillSettingsScopeGlobal,
                  ),
                  for (final project in projects)
                    TRSelectItem<String?>(
                      key: ValueKey<String>('skill-scope-${project.id}'),
                      value: project.id,
                      label: project.name,
                      description: project.rootPath,
                    ),
                ],
                onChanged: onWorkspaceChanged,
              ),
            ],
          ),
        _catalogSection(context),
      ],
    );
  }

  Widget _catalogSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = error;
    if (failure != null) {
      return SettingsSection.form(
        children: <Widget>[
          SettingsErrorState(error: failure, onRetry: onRetry!),
        ],
      );
    }
    final loaded = skills!;

    final sorted = loaded.toList(growable: false)
      ..sort((left, right) {
        final byName = left.name.toLowerCase().compareTo(
          right.name.toLowerCase(),
        );
        return byName != 0 ? byName : left.id.compareTo(right.id);
      });
    final title = workspaceId == null
        ? l10n.skillSettingsGlobalCount(sorted.length)
        : l10n.skillSettingsProjectCount(sorted.length);
    if (sorted.isEmpty) {
      return SettingsSection.form(
        title: title,
        children: <Widget>[
          SettingsEmptyState(
            title: workspaceId == null
                ? l10n.skillSettingsGlobalEmpty
                : l10n.skillSettingsProjectEmpty,
          ),
        ],
      );
    }
    return SettingsSection(
      title: title,
      children: <Widget>[
        for (final skill in sorted)
          SettingsRow(
            key: ValueKey<String>('skill-row-${skill.id}'),
            title: TRText.inherit(skill.name),
            description: TRText.inherit(skill.description),
            unboundedDescription: true,
          ),
      ],
    );
  }
}
