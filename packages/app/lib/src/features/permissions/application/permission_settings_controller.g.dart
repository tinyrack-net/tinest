// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'permission_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the daemon-global permission default for one connected host.

@ProviderFor(PermissionSettingsController)
final permissionSettingsControllerProvider =
    PermissionSettingsControllerFamily._();

/// Owns the daemon-global permission default for one connected host.
final class PermissionSettingsControllerProvider
    extends
        $AsyncNotifierProvider<
          PermissionSettingsController,
          PermissionSettingsDto
        > {
  /// Owns the daemon-global permission default for one connected host.
  PermissionSettingsControllerProvider._({
    required PermissionSettingsControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: noAutomaticRetry,
         name: r'permissionSettingsControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$permissionSettingsControllerHash();

  @override
  String toString() {
    return r'permissionSettingsControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PermissionSettingsController create() => PermissionSettingsController();

  @override
  bool operator ==(Object other) {
    return other is PermissionSettingsControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$permissionSettingsControllerHash() =>
    r'76659515d0f4df87e16a7b9f1feb9a4db66cc8e6';

/// Owns the daemon-global permission default for one connected host.

final class PermissionSettingsControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          PermissionSettingsController,
          AsyncValue<PermissionSettingsDto>,
          PermissionSettingsDto,
          FutureOr<PermissionSettingsDto>,
          String
        > {
  PermissionSettingsControllerFamily._()
    : super(
        retry: noAutomaticRetry,
        name: r'permissionSettingsControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Owns the daemon-global permission default for one connected host.

  PermissionSettingsControllerProvider call(String hostId) =>
      PermissionSettingsControllerProvider._(argument: hostId, from: this);

  @override
  String toString() => r'permissionSettingsControllerProvider';
}

/// Owns the daemon-global permission default for one connected host.

abstract class _$PermissionSettingsController
    extends $AsyncNotifier<PermissionSettingsDto> {
  late final _$args = ref.$arg as String;
  String get hostId => _$args;

  FutureOr<PermissionSettingsDto> build(String hostId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<PermissionSettingsDto>, PermissionSettingsDto>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<PermissionSettingsDto>,
                PermissionSettingsDto
              >,
              AsyncValue<PermissionSettingsDto>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
