// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Tracks whether the saved worktree was already restored this run.
///
/// The workspace page is rebuilt whenever the route changes, so the guard has
/// to outlive its state or leaving a session would snap straight back into it.

@ProviderFor(SelectionRestoreController)
final selectionRestoreControllerProvider =
    SelectionRestoreControllerProvider._();

/// Tracks whether the saved worktree was already restored this run.
///
/// The workspace page is rebuilt whenever the route changes, so the guard has
/// to outlive its state or leaving a session would snap straight back into it.
final class SelectionRestoreControllerProvider
    extends $NotifierProvider<SelectionRestoreController, bool> {
  /// Tracks whether the saved worktree was already restored this run.
  ///
  /// The workspace page is rebuilt whenever the route changes, so the guard has
  /// to outlive its state or leaving a session would snap straight back into it.
  SelectionRestoreControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectionRestoreControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectionRestoreControllerHash();

  @$internal
  @override
  SelectionRestoreController create() => SelectionRestoreController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$selectionRestoreControllerHash() =>
    r'392030769d1af6173d49ecf3505645831dd34e2a';

/// Tracks whether the saved worktree was already restored this run.
///
/// The workspace page is rebuilt whenever the route changes, so the guard has
/// to outlive its state or leaving a session would snap straight back into it.

abstract class _$SelectionRestoreController extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Loads every online daemon catalog without merging daemon-local IDs.

@ProviderFor(WorkspaceCatalogController)
final workspaceCatalogControllerProvider =
    WorkspaceCatalogControllerProvider._();

/// Loads every online daemon catalog without merging daemon-local IDs.
final class WorkspaceCatalogControllerProvider
    extends
        $AsyncNotifierProvider<
          WorkspaceCatalogController,
          UnifiedWorkspaceCatalogState
        > {
  /// Loads every online daemon catalog without merging daemon-local IDs.
  WorkspaceCatalogControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceCatalogControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceCatalogControllerHash();

  @$internal
  @override
  WorkspaceCatalogController create() => WorkspaceCatalogController();
}

String _$workspaceCatalogControllerHash() =>
    r'3c1b7ed102f8f3d20b177dccec770513a0ae2c0c';

/// Loads every online daemon catalog without merging daemon-local IDs.

abstract class _$WorkspaceCatalogController
    extends $AsyncNotifier<UnifiedWorkspaceCatalogState> {
  FutureOr<UnifiedWorkspaceCatalogState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<UnifiedWorkspaceCatalogState>,
              UnifiedWorkspaceCatalogState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<UnifiedWorkspaceCatalogState>,
                UnifiedWorkspaceCatalogState
              >,
              AsyncValue<UnifiedWorkspaceCatalogState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Lists local Git branches for one repository.

@ProviderFor(gitBranches)
final gitBranchesProvider = GitBranchesFamily._();

/// Lists local Git branches for one repository.

final class GitBranchesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<GitBranchDto>>,
          List<GitBranchDto>,
          FutureOr<List<GitBranchDto>>
        >
    with
        $FutureModifier<List<GitBranchDto>>,
        $FutureProvider<List<GitBranchDto>> {
  /// Lists local Git branches for one repository.
  GitBranchesProvider._({
    required GitBranchesFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'gitBranchesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$gitBranchesHash();

  @override
  String toString() {
    return r'gitBranchesProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<GitBranchDto>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<GitBranchDto>> create(Ref ref) {
    final argument = this.argument as (String, String);
    return gitBranches(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is GitBranchesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$gitBranchesHash() => r'2a04178fc557eaedc66a8a4cfe1a36d04d832e9a';

/// Lists local Git branches for one repository.

final class GitBranchesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<GitBranchDto>>,
          (String, String)
        > {
  GitBranchesFamily._()
    : super(
        retry: null,
        name: r'gitBranchesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Lists local Git branches for one repository.

  GitBranchesProvider call(String hostId, String workspaceId) =>
      GitBranchesProvider._(argument: (hostId, workspaceId), from: this);

  @override
  String toString() => r'gitBranchesProvider';
}

/// Loads and edits the `.tinest/config.json` worktree hooks of one project.

@ProviderFor(ProjectSettingsController)
final projectSettingsControllerProvider = ProjectSettingsControllerFamily._();

/// Loads and edits the `.tinest/config.json` worktree hooks of one project.
final class ProjectSettingsControllerProvider
    extends
        $AsyncNotifierProvider<
          ProjectSettingsController,
          ProjectSettingsResultDto
        > {
  /// Loads and edits the `.tinest/config.json` worktree hooks of one project.
  ProjectSettingsControllerProvider._({
    required ProjectSettingsControllerFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: noAutomaticRetry,
         name: r'projectSettingsControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$projectSettingsControllerHash();

  @override
  String toString() {
    return r'projectSettingsControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  ProjectSettingsController create() => ProjectSettingsController();

  @override
  bool operator ==(Object other) {
    return other is ProjectSettingsControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$projectSettingsControllerHash() =>
    r'57aefc95e9654f24e44c23a7b60b937483358455';

/// Loads and edits the `.tinest/config.json` worktree hooks of one project.

final class ProjectSettingsControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          ProjectSettingsController,
          AsyncValue<ProjectSettingsResultDto>,
          ProjectSettingsResultDto,
          FutureOr<ProjectSettingsResultDto>,
          (String, String)
        > {
  ProjectSettingsControllerFamily._()
    : super(
        retry: noAutomaticRetry,
        name: r'projectSettingsControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Loads and edits the `.tinest/config.json` worktree hooks of one project.

  ProjectSettingsControllerProvider call(String hostId, String workspaceId) =>
      ProjectSettingsControllerProvider._(
        argument: (hostId, workspaceId),
        from: this,
      );

  @override
  String toString() => r'projectSettingsControllerProvider';
}

/// Loads and edits the `.tinest/config.json` worktree hooks of one project.

abstract class _$ProjectSettingsController
    extends $AsyncNotifier<ProjectSettingsResultDto> {
  late final _$args = ref.$arg as (String, String);
  String get hostId => _$args.$1;
  String get workspaceId => _$args.$2;

  FutureOr<ProjectSettingsResultDto> build(String hostId, String workspaceId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<ProjectSettingsResultDto>,
              ProjectSettingsResultDto
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<ProjectSettingsResultDto>,
                ProjectSettingsResultDto
              >,
              AsyncValue<ProjectSettingsResultDto>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}
