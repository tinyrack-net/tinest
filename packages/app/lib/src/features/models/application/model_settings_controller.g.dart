// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the daemon-global concrete default model for one connected host.

@ProviderFor(ModelSettingsController)
final modelSettingsControllerProvider = ModelSettingsControllerFamily._();

/// Owns the daemon-global concrete default model for one connected host.
final class ModelSettingsControllerProvider
    extends
        $AsyncNotifierProvider<
          ModelSettingsController,
          DaemonModelSettingsDto
        > {
  /// Owns the daemon-global concrete default model for one connected host.
  ModelSettingsControllerProvider._({
    required ModelSettingsControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: noAutomaticRetry,
         name: r'modelSettingsControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$modelSettingsControllerHash();

  @override
  String toString() {
    return r'modelSettingsControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ModelSettingsController create() => ModelSettingsController();

  @override
  bool operator ==(Object other) {
    return other is ModelSettingsControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$modelSettingsControllerHash() =>
    r'82e3aaabee382a0763c77bc4a8af50aca29113ec';

/// Owns the daemon-global concrete default model for one connected host.

final class ModelSettingsControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          ModelSettingsController,
          AsyncValue<DaemonModelSettingsDto>,
          DaemonModelSettingsDto,
          FutureOr<DaemonModelSettingsDto>,
          String
        > {
  ModelSettingsControllerFamily._()
    : super(
        retry: noAutomaticRetry,
        name: r'modelSettingsControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Owns the daemon-global concrete default model for one connected host.

  ModelSettingsControllerProvider call(String hostId) =>
      ModelSettingsControllerProvider._(argument: hostId, from: this);

  @override
  String toString() => r'modelSettingsControllerProvider';
}

/// Owns the daemon-global concrete default model for one connected host.

abstract class _$ModelSettingsController
    extends $AsyncNotifier<DaemonModelSettingsDto> {
  late final _$args = ref.$arg as String;
  String get hostId => _$args;

  FutureOr<DaemonModelSettingsDto> build(String hostId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<DaemonModelSettingsDto>, DaemonModelSettingsDto>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<DaemonModelSettingsDto>,
                DaemonModelSettingsDto
              >,
              AsyncValue<DaemonModelSettingsDto>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
