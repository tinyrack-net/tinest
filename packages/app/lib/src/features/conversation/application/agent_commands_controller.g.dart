// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_commands_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Loads the agent commands one daemon offers, optionally for one project.
///
/// A null [AgentCommandsController.workspaceId] shows only the user-home and
/// daemon-config sources; naming a workspace layers its `.agents/commands` on
/// top.

@ProviderFor(AgentCommandsController)
final agentCommandsControllerProvider = AgentCommandsControllerFamily._();

/// Loads the agent commands one daemon offers, optionally for one project.
///
/// A null [AgentCommandsController.workspaceId] shows only the user-home and
/// daemon-config sources; naming a workspace layers its `.agents/commands` on
/// top.
final class AgentCommandsControllerProvider
    extends
        $AsyncNotifierProvider<AgentCommandsController, List<AgentCommandDto>> {
  /// Loads the agent commands one daemon offers, optionally for one project.
  ///
  /// A null [AgentCommandsController.workspaceId] shows only the user-home and
  /// daemon-config sources; naming a workspace layers its `.agents/commands` on
  /// top.
  AgentCommandsControllerProvider._({
    required AgentCommandsControllerFamily super.from,
    required (String, String?) super.argument,
  }) : super(
         retry: null,
         name: r'agentCommandsControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$agentCommandsControllerHash();

  @override
  String toString() {
    return r'agentCommandsControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  AgentCommandsController create() => AgentCommandsController();

  @override
  bool operator ==(Object other) {
    return other is AgentCommandsControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$agentCommandsControllerHash() =>
    r'bbd459c72e03ba765e32d3edcbb6e7a3833fc162';

/// Loads the agent commands one daemon offers, optionally for one project.
///
/// A null [AgentCommandsController.workspaceId] shows only the user-home and
/// daemon-config sources; naming a workspace layers its `.agents/commands` on
/// top.

final class AgentCommandsControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          AgentCommandsController,
          AsyncValue<List<AgentCommandDto>>,
          List<AgentCommandDto>,
          FutureOr<List<AgentCommandDto>>,
          (String, String?)
        > {
  AgentCommandsControllerFamily._()
    : super(
        retry: null,
        name: r'agentCommandsControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Loads the agent commands one daemon offers, optionally for one project.
  ///
  /// A null [AgentCommandsController.workspaceId] shows only the user-home and
  /// daemon-config sources; naming a workspace layers its `.agents/commands` on
  /// top.

  AgentCommandsControllerProvider call(String hostId, String? workspaceId) =>
      AgentCommandsControllerProvider._(
        argument: (hostId, workspaceId),
        from: this,
      );

  @override
  String toString() => r'agentCommandsControllerProvider';
}

/// Loads the agent commands one daemon offers, optionally for one project.
///
/// A null [AgentCommandsController.workspaceId] shows only the user-home and
/// daemon-config sources; naming a workspace layers its `.agents/commands` on
/// top.

abstract class _$AgentCommandsController
    extends $AsyncNotifier<List<AgentCommandDto>> {
  late final _$args = ref.$arg as (String, String?);
  String get hostId => _$args.$1;
  String? get workspaceId => _$args.$2;

  FutureOr<List<AgentCommandDto>> build(String hostId, String? workspaceId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<AgentCommandDto>>, List<AgentCommandDto>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<AgentCommandDto>>,
                List<AgentCommandDto>
              >,
              AsyncValue<List<AgentCommandDto>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}
