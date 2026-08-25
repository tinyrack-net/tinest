import 'dart:async';

import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/features/agents/application/agent_definitions_controller.dart';
import 'package:app/src/features/conversation/application/attachment_ports.dart';
import 'package:app/src/features/conversation/application/composer_controller.dart';
import 'package:app/src/features/conversation/domain/composer_commands.dart';
import 'package:app/src/features/conversation/presentation/composer_client_commands.dart';
import 'package:app/src/features/conversation/presentation/widgets/composer_completion_scope.dart';
import 'package:app/src/features/conversation/presentation/widgets/composer_suggestions_overlay.dart';
import 'package:app/src/features/conversation/presentation/widgets/session_composer.dart';
import 'package:app/src/features/hosts/application/host_controller.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/hosts/presentation/host_labels.dart';
import 'package:app/src/features/models/application/model_settings_controller.dart';
import 'package:app/src/features/plugins/presentation/agent_plugin_ui_slot.dart';
import 'package:app/src/features/providers/application/provider_settings_controller.dart';
import 'package:app/src/features/providers/application/session_model_options.dart';
import 'package:app/src/features/sessions/application/session_prompt_starter.dart';
import 'package:app/src/features/sessions/application/session_starter.dart';
import 'package:app/src/features/sessions/domain/session_title.dart';
import 'package:app/src/features/workspace/application/directory_picker_port.dart';
import 'package:app/src/features/workspace/application/workspace_controller.dart';
import 'package:app/src/features/workspace/domain/branch_defaults.dart';
import 'package:app/src/features/workspace/domain/branch_name.dart';
import 'package:app/src/features/workspace/presentation/widgets/directory_browser.dart';
import 'package:app/src/features/workspace/presentation/widgets/worktree_hook_report.dart';
import 'package:app/src/shared/presentation/client_error_alert.dart';
import 'package:app/src/shared/presentation/tinest_icons.dart';
import 'package:app/src/shared/presentation/tinest_select_presentation.dart';
import 'package:app/src/shared/presentation/workspace_skeletons.dart';
import 'package:client/client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// One registered repository together with the daemon that owns it.
final class NewWorkspaceProject {
  /// Creates a selectable project.
  const NewWorkspaceProject({
    required this.hostId,
    required this.hostLabel,
    required this.workspace,
    required this.worktrees,
  });

  /// Daemon profile owning [workspace].
  final String hostId;

  /// User-visible daemon name.
  final String hostLabel;

  /// The registered repository.
  final WorkspaceDto workspace;

  /// Checkouts belonging to [workspace].
  final List<WorktreeDto> worktrees;

  /// Stable identity used by menu keys and selection.
  String get key => '$hostId\u0000${workspace.id}';
}

typedef _ProjectTarget = ({String? projectKey, bool addProject});

/// Flattens every online daemon catalog into selectable projects.
///
/// Takes [l10n] because the app owns the embedded daemon's name, and projects
/// are ordered by the name the user actually sees.
List<NewWorkspaceProject> collectProjects(
  AppLocalizations l10n,
  UnifiedWorkspaceCatalogState state,
) {
  final projects = <NewWorkspaceProject>[];
  for (final entry in state.catalogs.entries) {
    final host = state.hosts[entry.key];
    final label = host == null ? entry.key : hostLabel(l10n, host);
    for (final workspace in entry.value.workspaces) {
      // The home workspace exists only to give project-less sessions a working
      // directory, so it is never one of the projects the user picks from.
      if (workspace.kind == WorkspaceKind.home) continue;
      projects.add(
        NewWorkspaceProject(
          hostId: entry.key,
          hostLabel: label,
          workspace: workspace,
          worktrees: entry.value.worktrees
              .where((item) => item.workspaceId == workspace.id)
              .toList(growable: false),
        ),
      );
    }
  }
  projects.sort((left, right) {
    final byHost = left.hostLabel.compareTo(right.hostLabel);
    return byHost != 0
        ? byHost
        : left.workspace.name.compareTo(right.workspace.name);
  });
  return List<NewWorkspaceProject>.unmodifiable(projects);
}

/// Centered composer that starts a session on a new or existing worktree.
class NewWorkspacePane extends ConsumerStatefulWidget {
  /// Creates the new-workspace composer.
  const NewWorkspacePane({
    required this.onStarted,
    super.key,
  });

  /// Called with the selection and session created by the first prompt.
  final void Function(WorkspaceSelection selection, SessionDto session)
  onStarted;

  @override
  ConsumerState<NewWorkspacePane> createState() => _NewWorkspacePaneState();
}

class _NewWorkspacePaneState extends ConsumerState<NewWorkspacePane> {
  final SessionComposerController _dropController = SessionComposerController();
  bool _projectTooltipOpen = false;
  bool _worktreeTooltipOpen = false;
  bool _branchTooltipOpen = false;
  bool _projectSelectOpen = false;
  bool _worktreeSelectOpen = false;
  bool _branchSelectOpen = false;
  String? _projectKey;
  String? _worktreeId;
  String? _baseBranch;
  bool _submitting = false;
  bool _registeringProject = false;
  // Which submit step is running, so the wait is narrated instead of the
  // composer merely appearing frozen while a worktree is checked out.
  _NewWorkspaceStage _stage = _NewWorkspaceStage.creatingWorktree;
  // Guidance and failure are tracked apart: guidance says what is still
  // missing, a failure says what already went wrong, and rendering them
  // through one red line made a daemon error indistinguishable from a prompt
  // to pick a project.
  String? _guidance;
  TinestClientException? _failure;

  @override
  void dispose() {
    _dropController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `valueOrNull` keeps the last catalog while the provider refreshes, so a
    // host-registry change never flashes the empty state.
    final registryAsync = ref.watch(hostRegistryControllerProvider);
    final anyDaemonConnected =
        registryAsync.value?.runtimes.values.any((item) => item.connected) ??
        false;
    final catalogAsync = ref.watch(workspaceCatalogControllerProvider);
    final catalog = catalogAsync.value;
    final catalogLoading =
        (catalogAsync.isLoading && !catalogAsync.hasValue) ||
        (catalogAsync.value?.hasPendingHosts ?? false);
    final projects = catalog == null
        ? const <NewWorkspaceProject>[]
        : collectProjects(AppLocalizations.of(context), catalog);
    // A null [_projectKey] means the user picked no project, which is the
    // starting state: the composer never adopts a project on its own.
    final project = projects
        .where((item) => item.key == _projectKey)
        .firstOrNull;
    // Without a project the session runs in the home folder of the daemon the
    // rest of the app is pointed at.
    final hostId = project?.hostId ?? ref.watch(activeHostIdProvider);
    final home = hostId == null ? null : catalog?.homeSelection(hostId);
    final isGitProject = project?.workspace.kind == WorkspaceKind.git;
    final showGitTargets = project != null && isGitProject;
    final branchesAsync = project == null || !isGitProject
        ? const AsyncValue<List<GitBranchDto>>.data(<GitBranchDto>[])
        : ref.watch(
            gitBranchesProvider(project.hostId, project.workspace.id),
          );
    final branches = branchesAsync.value ?? const <GitBranchDto>[];
    // Remote refs win by default so a new branch starts from the latest push.
    final baseBranch = _baseBranch ?? defaultBaseBranch(branches);
    final worktree = project == null
        ? null
        : isGitProject
        ? project.worktrees.where((item) => item.id == _worktreeId).firstOrNull
        : _directoryCheckout(project);
    final agentsAsync = hostId == null
        ? null
        : ref.watch(agentDefinitionsControllerProvider(hostId));
    final agents = agentsAsync?.value;
    final agentsLoading =
        agentsAsync != null && agentsAsync.isLoading && !agentsAsync.hasValue;
    final definitions = selectableAgentDefinitions(
      agents?.definitions ?? const <AgentDefinitionDto>[],
    );
    final agent =
        definitions
            .where((item) => item.id == _draft(hostId)?.agentDefinitionId)
            .firstOrNull ??
        definitions.firstOrNull;
    final connectionsAsync = hostId == null
        ? null
        : ref.watch(providerSettingsControllerProvider(hostId));
    final connections = connectionsAsync?.value?.connections;
    final connectionsLoading =
        connectionsAsync != null &&
        connectionsAsync.isLoading &&
        !connectionsAsync.hasValue;
    final modelSettingsAsync = hostId == null
        ? null
        : ref.watch(modelSettingsControllerProvider(hostId));
    final modelSettingsLoading =
        modelSettingsAsync != null &&
        modelSettingsAsync.isLoading &&
        !modelSettingsAsync.hasValue;
    final draft = _draft(hostId);
    final effective =
        draft?.model ??
        effectiveModelFor(
          definition: agent,
          connections: connections ?? const <ProviderConnectionDto>[],
          models:
              connectionsAsync?.value?.models ??
              const <String, List<ProviderModelDto>>{},
          defaultModel: modelSettingsAsync?.value?.defaultModel,
        );
    final effectiveRunnable =
        effective != null &&
        isRunnableSelection(
          effective,
          connections ?? const <ProviderConnectionDto>[],
          connectionsAsync?.value?.models ??
              const <String, List<ProviderModelDto>>{},
        );
    final hasRunnableModel =
        firstUsableModel(
          connections ?? const <ProviderConnectionDto>[],
          connectionsAsync?.value?.models ??
              const <String, List<ProviderModelDto>>{},
        ) !=
        null;
    // A Git project can create the checkout on submit; every other target has
    // to already exist.
    final target = project == null
        ? home != null
        : isGitProject || worktree != null;
    final gitTargetReady =
        !isGitProject || worktree != null || branchesAsync.hasValue;
    final ready =
        hostId != null &&
        target &&
        gitTargetReady &&
        agent != null &&
        effectiveRunnable &&
        !_submitting;
    // The completion is null only while no daemon is chosen, which is also the
    // state where the composer is disabled and has nothing to complete.
    Widget composer(ComposerCompletion? completion) => SessionComposer(
      controller: _dropController,
      enabled: ready,
      hint: _hint(
        AppLocalizations.of(context),
        projects,
        project,
        worktree,
        agent,
        effective,
        modelRunnable: effectiveRunnable,
        hasRunnableModel: hasRunnableModel,
        home: home,
        loading:
            catalogLoading ||
            agentsLoading ||
            connectionsLoading ||
            modelSettingsLoading,
      ),
      failure: _failure == null
          ? null
          : ClientErrorAlert(
              key: const ValueKey<String>('new-workspace-error'),
              error: _failure!,
              title: AppLocalizations.of(context).workspaceStartFailedTitle,
            ),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _targets(
            projects: projects,
            project: project,
            home: home,
            worktree: worktree,
            branches: branches,
            branchesAsync: branchesAsync,
            showGitTargets: showGitTargets,
            baseBranch: baseBranch,
            anyDaemonConnected: anyDaemonConnected,
            catalogLoading: catalogLoading,
            registeringProject: _registeringProject,
          ),
          if (hostId != null && agent != null)
            AgentPluginUiSlot(
              hostId: hostId,
              agent: agent,
              slot: PluginUiSlot.composerControl,
              context: <String, dynamic>{
                'workspaceId': project?.workspace.id,
                'worktreeId': worktree?.id,
                'draft': true,
              },
            ),
        ],
      ),
      bar: SessionComposerBar(
        hostId: hostId ?? '',
        definitions: definitions,
        agentDefinitionId: agent?.id,
        selection: effective,
        enabled: hostId != null && !_submitting,
        onAgentChanged: (id) => _notifier(hostId)?.selectAgent(id),
        onModelChanged: (model, controls) {
          _notifier(hostId)?.selectModel(model);
          _notifier(hostId)?.selectModelControls(controls);
        },
        modelControls:
            draft?.modelControls ?? const <String, ModelControlValueDto>{},
        onModelControlsChanged: (controls) {
          final notifier = _notifier(hostId);
          if (notifier == null || effective == null) return;
          notifier
            ..selectModel(effective)
            ..selectModelControls(controls);
        },
        permissionMode: draft?.permissionMode,
        onPermissionModeChanged: (mode) =>
            _notifier(hostId)?.selectPermissionMode(mode),
      ),
      attachmentInput: ref.read(attachmentInputProvider),
      commands: completion?.commands ?? const <ComposerCommand>[],
      suggestions: completion?.suggestions ?? ComposerSuggestionsState.closed,
      onCompletionQueryChanged: completion?.onQueryChanged,
      onClientCommand: completion == null
          ? null
          : (invocation) => runSessionlessClientCommand(
              context,
              invocation,
              hostId: hostId!,
            ),
      onSubmit: (submission) =>
          _submit(submission, project, home, worktree, agent!, draft!),
    );
    final content = ConstrainedBox(
      constraints: const BoxConstraints(
        // tinyrack-check-ignore-next-line tokens/no-literal -- the pane cap is intentionally one eighth wider than the small breakpoint
        maxWidth: TRBreakpoints.small * 9 / 8,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(
              left: TRSpacing.large + TRSpacing.extraSmall,
              bottom: TRSpacing.extraSmall,
            ),
            child: TRText(
              AppLocalizations.of(context).workspaceNewWorkspace,
              variant: TRTextVariant.headingLg,
            ),
          ),
          if (hostId == null)
            composer(null)
          else
            ComposerCompletionScope(
              hostId: hostId,
              workspaceId: project?.workspace.id ?? home?.workspaceId,
              // A Git project whose checkout is still to be created has no
              // worktree to search, so it offers commands only.
              worktreeId:
                  worktree?.id ?? (project == null ? home?.worktreeId : null),
              excludedClientActions: sessionlessClientActions,
              builder: (context, completion) => composer(completion),
            ),
          if (_submitting)
            Padding(
              padding: const EdgeInsets.only(top: TRSpacing.medium),
              child: Row(
                key: const ValueKey<String>('new-workspace-progress'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const TRSpinner(),
                  const SizedBox(width: TRSpacing.small),
                  TRText(
                    _stage == _NewWorkspaceStage.creatingWorktree
                        ? AppLocalizations.of(
                            context,
                          ).workspaceCreatingWorktree
                        : AppLocalizations.of(
                            context,
                          ).workspaceStartingSession,
                    variant: TRTextVariant.bodySm,
                    color: TRTextColor.muted,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    return ComposerDropPane(
      controller: _dropController,
      child: Column(
        children: <Widget>[
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= TRBreakpoints.small) {
                  return Center(child: content);
                }
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: content,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  SessionComposerDraft? _draft(String? hostId) => hostId == null
      ? null
      : ref.watch(
          sessionComposerDraftControllerProvider(hostId, null, 'new-workspace'),
        );

  SessionComposerDraftController? _notifier(String? hostId) => hostId == null
      ? null
      : ref.read(
          sessionComposerDraftControllerProvider(
            hostId,
            null,
            'new-workspace',
          ).notifier,
        );

  String? _hint(
    AppLocalizations l10n,
    List<NewWorkspaceProject> projects,
    NewWorkspaceProject? project,
    WorktreeDto? worktree,
    AgentDefinitionDto? agent,
    ModelSelectionDto? model, {
    required bool modelRunnable,
    required bool hasRunnableModel,
    required WorkspaceSelection? home,
    required bool loading,
  }) {
    if (_guidance != null) return _guidance;
    if (loading) return null;
    if (project == null) {
      // A daemon configured without a user home publishes no home workspace,
      // so a project is the only thing left to start from.
      if (home != null) return null;
      return projects.isEmpty
          ? l10n.workspaceAddProjectFirst
          : l10n.workspaceSelectProject;
    }
    if (project.workspace.kind == WorkspaceKind.directory && worktree == null) {
      return l10n.workspaceCheckoutMissing;
    }
    if (agent == null) return l10n.composerNoPrimaryAgent;
    if (model == null) {
      return hasRunnableModel
          ? l10n.composerSelectProviderModel
          : l10n.composerConnectProviderFirst;
    }
    if (!modelRunnable) {
      return hasRunnableModel
          ? l10n.modelSettingsUnavailableDescription(model.modelId)
          : l10n.composerConnectProviderFirst;
    }
    return null;
  }

  Widget _targets({
    required List<NewWorkspaceProject> projects,
    required NewWorkspaceProject? project,
    required WorkspaceSelection? home,
    required WorktreeDto? worktree,
    required List<GitBranchDto> branches,
    required AsyncValue<List<GitBranchDto>> branchesAsync,
    required bool showGitTargets,
    required String? baseBranch,
    required bool anyDaemonConnected,
    required bool catalogLoading,
    required bool registeringProject,
  }) {
    final l10n = AppLocalizations.of(context);
    if (catalogLoading) {
      return ListRowsSkeleton(
        key: const ValueKey<String>('new-workspace-targets-loading'),
        semanticLabel: l10n.workspaceCatalogLoading,
        rows: 3,
      );
    }
    if (registeringProject) {
      return Semantics(
        label: l10n.workspaceRegisteringProject,
        liveRegion: true,
        container: true,
        child: ExcludeSemantics(
          child: Row(
            key: const ValueKey<String>('new-workspace-project-registering'),
            children: <Widget>[
              const TRSpinner(),
              const SizedBox(width: TRSpacing.small),
              TRText(
                l10n.workspaceRegisteringProject,
                variant: TRTextVariant.bodySm,
                color: TRTextColor.muted,
              ),
            ],
          ),
        ),
      );
    }
    final narrow = MediaQuery.sizeOf(context).width < TRBreakpoints.small;
    final local = project == null ? null : _localCheckout(project);
    final selectors = <Widget>[
      TRTooltip.controlled(
        message: l10n.workspaceProjectChipTooltip,
        open: _projectTooltipOpen && !_projectSelectOpen,
        onOpenChange: (open) => setState(() => _projectTooltipOpen = open),
        child: TRSelect<_ProjectTarget>.controlled(
          key: const ValueKey('new-workspace-project'),
          searchable: true,
          searchPlaceholder: l10n.selectSearchPlaceholder,
          noResultsText: l10n.selectNoResults,
          presentation: TinestSelectPresentation.resolve(context),
          value: (projectKey: project?.key, addProject: false),
          leading: const Icon(TinestIcons.folder),
          placeholder:
              project?.workspace.name ??
              (home == null
                  ? l10n.workspaceProjectChip
                  : l10n.workspaceNoProjectOption),
          appearance: TRFieldAppearance.ghost,
          width: narrow ? double.infinity : null,
          enabled: !_submitting && anyDaemonConnected,
          onOpen: () => setState(() {
            _projectSelectOpen = true;
            _projectTooltipOpen = false;
          }),
          onClose: () => setState(() => _projectSelectOpen = false),
          items: <TRSelectItem<_ProjectTarget>>[
            if (home != null)
              TRSelectItem<_ProjectTarget>(
                key: const ValueKey('new-workspace-project-none'),
                value: (projectKey: null, addProject: false),
                label: l10n.workspaceNoProjectOption,
              ),
            for (final item in projects)
              TRSelectItem<_ProjectTarget>(
                key: ValueKey('new-workspace-project-${item.key}'),
                value: (projectKey: item.key, addProject: false),
                label: '${item.workspace.name} · ${item.hostLabel}',
              ),
            TRSelectItem<_ProjectTarget>(
              key: const ValueKey('new-workspace-project-add'),
              value: (projectKey: null, addProject: true),
              label: l10n.workspaceProjectAdd,
              leading: const Icon(TinestIcons.addCircle),
            ),
          ],
          onValueChange: (chosen) {
            if (chosen == null) return;
            if (chosen.addProject) {
              unawaited(_addProject());
            } else {
              _selectProject(chosen.projectKey);
            }
          },
        ),
      ),
      if (showGitTargets) ...<Widget>[
        TRTooltip.controlled(
          message: l10n.workspaceWorktreeChipTooltip,
          open: _worktreeTooltipOpen && !_worktreeSelectOpen,
          onOpenChange: (open) => setState(() => _worktreeTooltipOpen = open),
          child: TRSelect<String?>.controlled(
            key: const ValueKey('new-workspace-worktree'),
            searchable: true,
            searchPlaceholder: l10n.selectSearchPlaceholder,
            noResultsText: l10n.selectNoResults,
            presentation: TinestSelectPresentation.resolve(context),
            value: worktree?.id,
            leading: const Icon(TinestIcons.branch),
            // The chip names the target, not the checkout behind it: the only
            // existing target this pane offers is the repository folder.
            placeholder: worktree == null
                ? l10n.workspaceWorktreeNew
                : l10n.workspaceWorktreeLocal,
            appearance: TRFieldAppearance.ghost,
            width: narrow ? double.infinity : null,
            enabled: project != null && !_submitting,
            onOpen: () => setState(() {
              _worktreeSelectOpen = true;
              _worktreeTooltipOpen = false;
            }),
            onClose: () => setState(() => _worktreeSelectOpen = false),
            // This pane starts something new, so it offers the two targets a
            // new session can have: the repository folder itself, or a
            // checkout created on submit. An existing worktree is picked from
            // the sidebar tree, which lists every one of them.
            items: <TRSelectItem<String?>>[
              if (local != null)
                TRSelectItem<String?>(
                  key: const ValueKey('new-workspace-worktree-local'),
                  value: local.id,
                  label: l10n.workspaceWorktreeLocal,
                  leading: const Icon(TinestIcons.folder),
                ),
              TRSelectItem<String?>(
                key: const ValueKey('new-workspace-worktree-new'),
                value: null,
                label: l10n.workspaceWorktreeNew,
                leading: const Icon(TinestIcons.branch),
              ),
            ],
            onValueChange: _selectWorktree,
          ),
        ),
        if (branchesAsync.isLoading && !branchesAsync.hasValue)
          Semantics(
            label: l10n.workspaceBranchesLoading,
            liveRegion: true,
            container: true,
            child: const ExcludeSemantics(
              child: TRSkeleton(
                key: ValueKey<String>('new-workspace-branch-loading'),
                width: TRMeasurements.measureSm,
              ),
            ),
          )
        else if (branchesAsync.hasError)
          TRAlert(
            key: const ValueKey<String>('new-workspace-branch-error'),
            variant: TRStatusVariant.danger,
            title: TRText.inherit(l10n.workspaceBranchesFailed),
            actions: <Widget>[
              TRButton(
                appearance: TRAppearance.outline,
                onPressed: project == null
                    ? null
                    : () => ref.invalidate(
                        gitBranchesProvider(
                          project.hostId,
                          project.workspace.id,
                        ),
                      ),
                child: TRText.inherit(l10n.commonRetry),
              ),
            ],
          )
        else
          TRTooltip.controlled(
            message: l10n.workspaceBaseBranchChipTooltip,
            open: _branchTooltipOpen && !_branchSelectOpen,
            onOpenChange: (open) => setState(() => _branchTooltipOpen = open),
            child: TRSelect<String>.controlled(
              key: const ValueKey('new-workspace-branch'),
              searchable: true,
              searchPlaceholder: l10n.selectSearchPlaceholder,
              noResultsText: l10n.selectNoResults,
              presentation: TinestSelectPresentation.resolve(context),
              value: baseBranch,
              leading: const Icon(TinestIcons.check),
              placeholder: baseBranch ?? l10n.workspaceBaseBranchChip,
              appearance: TRFieldAppearance.ghost,
              width: narrow ? double.infinity : null,
              enabled: project != null && worktree == null && !_submitting,
              onOpen: () => setState(() {
                _branchSelectOpen = true;
                _branchTooltipOpen = false;
              }),
              onClose: () => setState(() => _branchSelectOpen = false),
              items: <TRSelectItem<String>>[
                for (final branch in branches.where(
                  (branch) => branch.isRemote,
                ))
                  TRSelectItem<String>(
                    key: ValueKey('new-workspace-branch-${branch.name}'),
                    value: branch.name,
                    label: branch.name,
                  ),
                for (final branch in branches.where(
                  (branch) => !branch.isRemote,
                ))
                  TRSelectItem<String>(
                    key: ValueKey('new-workspace-branch-${branch.name}'),
                    value: branch.name,
                    label: branch.name,
                  ),
              ],
              onValueChange: (chosen) {
                if (chosen != null) _selectBranch(chosen);
              },
            ),
          ),
      ],
    ];
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TRSpacing.small,
        children: selectors,
      );
    }
    // A horizontal scroll view offers unbounded width, and a ghost chip is
    // intrinsically sized, so without a cap a long branch name widens the chip
    // instead of ellipsising inside it. The cap is what lets the Select's own
    // overflow handling take effect; a short label still shrinks to fit.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: TRSpacing.small,
        children: <Widget>[
          for (final selector in selectors)
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: TRMeasurements.measureMd,
              ),
              child: selector,
            ),
        ],
      ),
    );
  }

  /// Selects one project, or null to run the session in the home folder.
  void _selectProject(String? chosen) {
    setState(() {
      _projectKey = chosen;
      _worktreeId = null;
      _baseBranch = null;
      _guidance = null;
      _failure = null;
    });
  }

  void _selectWorktree(String? chosen) {
    setState(() {
      _worktreeId = chosen;
      _guidance = null;
      _failure = null;
    });
  }

  void _selectBranch(String chosen) {
    setState(() => _baseBranch = chosen);
  }

  Future<void> _addProject() async {
    final registry = ref.read(hostRegistryControllerProvider).value;
    final online =
        registry?.runtimes.values
            .where((item) => item.connected)
            .toList(growable: false) ??
        const <HostRuntimeSnapshot>[];
    final hostId = await pickDaemonHost(context, online);
    if (hostId == null || !mounted) return;
    final host = online.singleWhere((item) => item.id == hostId);
    // Repositories almost always live under the home of the machine that owns
    // them, so both pickers start there. A daemon configured without a home
    // reports none, leaving the root as the only path known to exist there.
    final home = host.serverInfo?.homeDirectory;
    final picker = ref.read(directoryPickerProvider);
    // The embedded daemon shares this filesystem, so the operating system's
    // own chooser browses exactly the paths it can register.
    final path = host.kind == HostKind.embedded && picker != null
        ? await picker.pickDirectory(initialDirectory: home)
        : await showDirectoryBrowser(
            context,
            api: host.api!,
            initialPath: home ?? '/',
          );
    if (path == null || path.isEmpty || !mounted) return;
    setState(() {
      _registeringProject = true;
      _failure = null;
    });
    try {
      final result = await ref
          .read(workspaceCatalogControllerProvider.notifier)
          .register(hostId, path);
      if (!mounted) return;
      setState(() {
        _projectKey = '$hostId\u0000${result.workspace.id}';
        _worktreeId = null;
        _baseBranch = null;
        _failure = null;
      });
    } on TinestClientException catch (error) {
      if (!mounted) return;
      setState(() => _failure = error);
    } finally {
      if (mounted) setState(() => _registeringProject = false);
    }
  }

  Future<void> _submit(
    ComposerSubmission submission,
    NewWorkspaceProject? project,
    WorkspaceSelection? home,
    WorktreeDto? worktree,
    AgentDefinitionDto agent,
    SessionComposerDraft draft,
  ) async {
    final seed = submission.text.isEmpty
        ? submission.attachments.first.fileName
        : submission.text;
    setState(() {
      _submitting = true;
      _stage = _NewWorkspaceStage.startingSession;
      _guidance = null;
      _failure = null;
    });
    try {
      if (project == null) {
        // No project was picked, so the session runs in the home checkout the
        // daemon provisioned; there is no worktree to create.
        if (home == null) {
          _reportGuidance(AppLocalizations.of(context).workspaceDaemonRequired);
          return;
        }
        await _start(home, agent, draft, submission, seed);
        return;
      }
      var worktreeId = worktree?.id;
      if (worktreeId == null) {
        if (project.workspace.kind != WorkspaceKind.git) {
          _reportGuidance(
            AppLocalizations.of(context).workspaceCheckoutMissing,
          );
          return;
        }
        final api = _hostApi(project.hostId);
        if (api == null) {
          _reportGuidance(AppLocalizations.of(context).workspaceDaemonRequired);
          return;
        }
        setState(() => _stage = _NewWorkspaceStage.creatingWorktree);
        final created = await api.workspaces.createWorktree(
          id: ref.read(appIdGeneratorProvider).generate(),
          workspaceId: project.workspace.id,
          mode: WorktreeCreateMode.newBranch,
          branchName: deriveWorktreeBranchName(
            seed,
            existingBranchNames: _takenBranchNames(project),
          ),
          baseBranch: _baseBranch ?? defaultBaseBranch(_branches(project)),
          // The name comes from a prompt, not from the user, so a collision is
          // the daemon's to resolve. It is also the only party that can: a
          // branch outlives the archived worktree that created it and never
          // appears in the catalog this pane reads.
          branchNaming: WorktreeBranchNaming.derive,
        );
        // The routed pages read the catalog, so refresh before navigating.
        await ref
            .read(workspaceCatalogControllerProvider.notifier)
            .refreshHost(project.hostId);
        // The daemon removes a checkout whose setup failed. Surface the exact
        // hook output and keep the submission available for a corrected retry.
        if (failedWorktreeHook(created.hookRuns) != null) {
          if (mounted) reportWorktreeHookFailure(context, created.hookRuns);
          return;
        }
        worktreeId = created.worktree.id;
      }
      if (mounted) {
        setState(() => _stage = _NewWorkspaceStage.startingSession);
      }
      await _start(
        WorkspaceSelection(
          hostId: project.hostId,
          workspaceId: project.workspace.id,
          worktreeId: worktreeId,
        ),
        agent,
        draft,
        submission,
        seed,
      );
    } on TinestClientException catch (error) {
      if (mounted) setState(() => _failure = error);
    } finally {
      // Every exit releases the composer. Without this a failure the typed
      // catch does not match leaves the pane permanently unable to submit.
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Shows a still-missing precondition and releases the composer.
  void _reportGuidance(String message) => setState(() => _guidance = message);

  /// Names the derived branch must avoid on the first attempt.
  ///
  /// Local branches are included alongside the catalog so the optimistic name
  /// is usually already free; the daemon stays the authority, since only it
  /// sees branches left behind by archived checkouts.
  Iterable<String> _takenBranchNames(NewWorkspaceProject project) => <String>[
    ...project.worktrees.map((item) => item.branch ?? item.name),
    ..._branches(
      project,
    ).where((branch) => !branch.isRemote).map((branch) => branch.name),
  ];

  /// Creates the session on [selection] and hands it to the caller.
  Future<void> _start(
    WorkspaceSelection selection,
    AgentDefinitionDto agent,
    SessionComposerDraft draft,
    ComposerSubmission submission,
    String seed,
  ) async {
    final l10n = AppLocalizations.of(context);
    final session = await startSessionWithPrompt(
      ref.read(sessionStarterProvider),
      selection: selection,
      agentDefinitionId: agent.id,
      title: deriveSessionTitle(seed, fallback: l10n.sessionDefaultTitle),
      prompt: submission.text,
      attachments: submission.attachments,
      model: draft.model,
      modelControls: draft.modelControls,
      permissionMode: draft.permissionMode,
    );
    if (!mounted) return;
    widget.onStarted(selection, session);
  }

  List<GitBranchDto> _branches(NewWorkspaceProject project) =>
      ref
          .read(gitBranchesProvider(project.hostId, project.workspace.id))
          .value ??
      const <GitBranchDto>[];

  /// The repository folder itself, which the worktree chip calls Local.
  ///
  /// A Git project has exactly one, but the catalog is a daemon snapshot: a
  /// project registered moments ago may not carry it yet, and the chip then
  /// offers only a new checkout rather than an entry that resolves to nothing.
  WorktreeDto? _localCheckout(NewWorkspaceProject project) => project.worktrees
      .where((item) => item.kind == WorktreeKind.checkout)
      .firstOrNull;

  WorktreeDto? _directoryCheckout(NewWorkspaceProject project) {
    final checkouts = project.worktrees
        .where((item) => item.kind == WorktreeKind.directory)
        .toList(growable: false);
    return checkouts.length == 1 ? checkouts.single : null;
  }

  TinestApi? _hostApi(String hostId) {
    final runtime = ref
        .read(hostRegistryControllerProvider)
        .value
        ?.runtimes[hostId];
    return runtime?.connected == true ? runtime!.api : null;
  }
}

/// Submit steps the new-workspace composer narrates while it works.
enum _NewWorkspaceStage { creatingWorktree, startingSession }
