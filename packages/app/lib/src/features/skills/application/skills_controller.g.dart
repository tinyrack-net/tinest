// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skills_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Loads one read-only view of the effective skills a daemon offers.

@ProviderFor(SkillsController)
final skillsControllerProvider = SkillsControllerFamily._();

/// Loads one read-only view of the effective skills a daemon offers.
final class SkillsControllerProvider
    extends $AsyncNotifierProvider<SkillsController, List<SkillSummaryDto>> {
  /// Loads one read-only view of the effective skills a daemon offers.
  SkillsControllerProvider._({
    required SkillsControllerFamily super.from,
    required (String, SkillListView, String?) super.argument,
  }) : super(
         retry: noAutomaticRetry,
         name: r'skillsControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$skillsControllerHash();

  @override
  String toString() {
    return r'skillsControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  SkillsController create() => SkillsController();

  @override
  bool operator ==(Object other) {
    return other is SkillsControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$skillsControllerHash() => r'626a18fdbf83d9f3478d6c90a97fabc7460773ad';

/// Loads one read-only view of the effective skills a daemon offers.

final class SkillsControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          SkillsController,
          AsyncValue<List<SkillSummaryDto>>,
          List<SkillSummaryDto>,
          FutureOr<List<SkillSummaryDto>>,
          (String, SkillListView, String?)
        > {
  SkillsControllerFamily._()
    : super(
        retry: noAutomaticRetry,
        name: r'skillsControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Loads one read-only view of the effective skills a daemon offers.

  SkillsControllerProvider call(
    String hostId,
    SkillListView view,
    String? workspaceId,
  ) => SkillsControllerProvider._(
    argument: (hostId, view, workspaceId),
    from: this,
  );

  @override
  String toString() => r'skillsControllerProvider';
}

/// Loads one read-only view of the effective skills a daemon offers.

abstract class _$SkillsController
    extends $AsyncNotifier<List<SkillSummaryDto>> {
  late final _$args = ref.$arg as (String, SkillListView, String?);
  String get hostId => _$args.$1;
  SkillListView get view => _$args.$2;
  String? get workspaceId => _$args.$3;

  FutureOr<List<SkillSummaryDto>> build(
    String hostId,
    SkillListView view,
    String? workspaceId,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<SkillSummaryDto>>, List<SkillSummaryDto>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<SkillSummaryDto>>,
                List<SkillSummaryDto>
              >,
              AsyncValue<List<SkillSummaryDto>>,
              Object?,
              Object?
            >;
    return element.handleCreate(
      ref,
      () => build(_$args.$1, _$args.$2, _$args.$3),
    );
  }
}
