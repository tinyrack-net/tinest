// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// ProviderSettingsController defines a public contract.

@ProviderFor(ProviderSettingsController)
final providerSettingsControllerProvider = ProviderSettingsControllerFamily._();

/// ProviderSettingsController defines a public contract.
final class ProviderSettingsControllerProvider
    extends
        $AsyncNotifierProvider<
          ProviderSettingsController,
          ProviderSettingsState?
        > {
  /// ProviderSettingsController defines a public contract.
  ProviderSettingsControllerProvider._({
    required ProviderSettingsControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: noAutomaticRetry,
         name: r'providerSettingsControllerProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$providerSettingsControllerHash();

  @override
  String toString() {
    return r'providerSettingsControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ProviderSettingsController create() => ProviderSettingsController();

  @override
  bool operator ==(Object other) {
    return other is ProviderSettingsControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$providerSettingsControllerHash() =>
    r'9875174c3bf4ac20227730b27e5eac000c2e7b1f';

/// ProviderSettingsController defines a public contract.

final class ProviderSettingsControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          ProviderSettingsController,
          AsyncValue<ProviderSettingsState?>,
          ProviderSettingsState?,
          FutureOr<ProviderSettingsState?>,
          String
        > {
  ProviderSettingsControllerFamily._()
    : super(
        retry: noAutomaticRetry,
        name: r'providerSettingsControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// ProviderSettingsController defines a public contract.

  ProviderSettingsControllerProvider call(String hostId) =>
      ProviderSettingsControllerProvider._(argument: hostId, from: this);

  @override
  String toString() => r'providerSettingsControllerProvider';
}

/// ProviderSettingsController defines a public contract.

abstract class _$ProviderSettingsController
    extends $AsyncNotifier<ProviderSettingsState?> {
  late final _$args = ref.$arg as String;
  String get hostId => _$args;

  FutureOr<ProviderSettingsState?> build(String hostId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<ProviderSettingsState?>, ProviderSettingsState?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<ProviderSettingsState?>,
                ProviderSettingsState?
              >,
              AsyncValue<ProviderSettingsState?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
