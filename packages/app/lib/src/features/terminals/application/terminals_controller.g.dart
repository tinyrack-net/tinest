// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'terminals_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Loads and edits the daemon-wide shell inherited by project terminals.

@ProviderFor(HostShellSettingsController)
final hostShellSettingsControllerProvider =
    HostShellSettingsControllerFamily._();

/// Loads and edits the daemon-wide shell inherited by project terminals.
final class HostShellSettingsControllerProvider
    extends $AsyncNotifierProvider<HostShellSettingsController, ShellSpecDto?> {
  /// Loads and edits the daemon-wide shell inherited by project terminals.
  HostShellSettingsControllerProvider._({
    required HostShellSettingsControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'hostShellSettingsControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$hostShellSettingsControllerHash();

  @override
  String toString() {
    return r'hostShellSettingsControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  HostShellSettingsController create() => HostShellSettingsController();

  @override
  bool operator ==(Object other) {
    return other is HostShellSettingsControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$hostShellSettingsControllerHash() =>
    r'd7ca6cec781dfaa402798fe4e682c73888c21d2a';

/// Loads and edits the daemon-wide shell inherited by project terminals.

final class HostShellSettingsControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          HostShellSettingsController,
          AsyncValue<ShellSpecDto?>,
          ShellSpecDto?,
          FutureOr<ShellSpecDto?>,
          String
        > {
  HostShellSettingsControllerFamily._()
    : super(
        retry: null,
        name: r'hostShellSettingsControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Loads and edits the daemon-wide shell inherited by project terminals.

  HostShellSettingsControllerProvider call(String hostId) =>
      HostShellSettingsControllerProvider._(argument: hostId, from: this);

  @override
  String toString() => r'hostShellSettingsControllerProvider';
}

/// Loads and edits the daemon-wide shell inherited by project terminals.

abstract class _$HostShellSettingsController
    extends $AsyncNotifier<ShellSpecDto?> {
  late final _$args = ref.$arg as String;
  String get hostId => _$args;

  FutureOr<ShellSpecDto?> build(String hostId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ShellSpecDto?>, ShellSpecDto?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ShellSpecDto?>, ShellSpecDto?>,
              AsyncValue<ShellSpecDto?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// Owns the live terminal catalog for one connected worktree.

@ProviderFor(TerminalsController)
final terminalsControllerProvider = TerminalsControllerFamily._();

/// Owns the live terminal catalog for one connected worktree.
final class TerminalsControllerProvider
    extends $AsyncNotifierProvider<TerminalsController, List<TerminalDto>> {
  /// Owns the live terminal catalog for one connected worktree.
  TerminalsControllerProvider._({
    required TerminalsControllerFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'terminalsControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$terminalsControllerHash();

  @override
  String toString() {
    return r'terminalsControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  TerminalsController create() => TerminalsController();

  @override
  bool operator ==(Object other) {
    return other is TerminalsControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$terminalsControllerHash() =>
    r'0769c0baf4fbfb64a80c9c6c7397ec0c72057b91';

/// Owns the live terminal catalog for one connected worktree.

final class TerminalsControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          TerminalsController,
          AsyncValue<List<TerminalDto>>,
          List<TerminalDto>,
          FutureOr<List<TerminalDto>>,
          (String, String)
        > {
  TerminalsControllerFamily._()
    : super(
        retry: null,
        name: r'terminalsControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Owns the live terminal catalog for one connected worktree.

  TerminalsControllerProvider call(String hostId, String worktreeId) =>
      TerminalsControllerProvider._(argument: (hostId, worktreeId), from: this);

  @override
  String toString() => r'terminalsControllerProvider';
}

/// Owns the live terminal catalog for one connected worktree.

abstract class _$TerminalsController extends $AsyncNotifier<List<TerminalDto>> {
  late final _$args = ref.$arg as (String, String);
  String get hostId => _$args.$1;
  String get worktreeId => _$args.$2;

  FutureOr<List<TerminalDto>> build(String hostId, String worktreeId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<TerminalDto>>, List<TerminalDto>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<TerminalDto>>, List<TerminalDto>>,
              AsyncValue<List<TerminalDto>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}
