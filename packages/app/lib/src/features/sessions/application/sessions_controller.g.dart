// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sessions_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// SessionsController defines a public contract.

@ProviderFor(SessionsController)
final sessionsControllerProvider = SessionsControllerFamily._();

/// SessionsController defines a public contract.
final class SessionsControllerProvider
    extends $AsyncNotifierProvider<SessionsController, List<SessionDto>> {
  /// SessionsController defines a public contract.
  SessionsControllerProvider._({
    required SessionsControllerFamily super.from,
    required (String, String?) super.argument,
  }) : super(
         retry: null,
         name: r'sessionsControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sessionsControllerHash();

  @override
  String toString() {
    return r'sessionsControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  SessionsController create() => SessionsController();

  @override
  bool operator ==(Object other) {
    return other is SessionsControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sessionsControllerHash() =>
    r'ea16fa59dbca87bc10535465ec2d3896eb55c707';

/// SessionsController defines a public contract.

final class SessionsControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          SessionsController,
          AsyncValue<List<SessionDto>>,
          List<SessionDto>,
          FutureOr<List<SessionDto>>,
          (String, String?)
        > {
  SessionsControllerFamily._()
    : super(
        retry: null,
        name: r'sessionsControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// SessionsController defines a public contract.

  SessionsControllerProvider call(String hostId, String? worktreeId) =>
      SessionsControllerProvider._(argument: (hostId, worktreeId), from: this);

  @override
  String toString() => r'sessionsControllerProvider';
}

/// SessionsController defines a public contract.

abstract class _$SessionsController extends $AsyncNotifier<List<SessionDto>> {
  late final _$args = ref.$arg as (String, String?);
  String get hostId => _$args.$1;
  String? get worktreeId => _$args.$2;

  FutureOr<List<SessionDto>> build(String hostId, String? worktreeId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<SessionDto>>, List<SessionDto>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<SessionDto>>, List<SessionDto>>,
              AsyncValue<List<SessionDto>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}
