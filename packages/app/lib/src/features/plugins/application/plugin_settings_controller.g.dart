// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Loads and mutates the v5 plugin catalog for one connected daemon.

@ProviderFor(PluginSettingsController)
final pluginSettingsControllerProvider = PluginSettingsControllerFamily._();

/// Loads and mutates the v5 plugin catalog for one connected daemon.
final class PluginSettingsControllerProvider
    extends
        $AsyncNotifierProvider<PluginSettingsController, PluginSettingsState> {
  /// Loads and mutates the v5 plugin catalog for one connected daemon.
  PluginSettingsControllerProvider._({
    required PluginSettingsControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'pluginSettingsControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pluginSettingsControllerHash();

  @override
  String toString() {
    return r'pluginSettingsControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PluginSettingsController create() => PluginSettingsController();

  @override
  bool operator ==(Object other) {
    return other is PluginSettingsControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pluginSettingsControllerHash() =>
    r'da6ed6c53d614a6d9b984a7c93c424bcfbceeed4';

/// Loads and mutates the v5 plugin catalog for one connected daemon.

final class PluginSettingsControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          PluginSettingsController,
          AsyncValue<PluginSettingsState>,
          PluginSettingsState,
          FutureOr<PluginSettingsState>,
          String
        > {
  PluginSettingsControllerFamily._()
    : super(
        retry: null,
        name: r'pluginSettingsControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Loads and mutates the v5 plugin catalog for one connected daemon.

  PluginSettingsControllerProvider call(String hostId) =>
      PluginSettingsControllerProvider._(argument: hostId, from: this);

  @override
  String toString() => r'pluginSettingsControllerProvider';
}

/// Loads and mutates the v5 plugin catalog for one connected daemon.

abstract class _$PluginSettingsController
    extends $AsyncNotifier<PluginSettingsState> {
  late final _$args = ref.$arg as String;
  String get hostId => _$args;

  FutureOr<PluginSettingsState> build(String hostId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<PluginSettingsState>, PluginSettingsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PluginSettingsState>, PluginSettingsState>,
              AsyncValue<PluginSettingsState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// Agent-owned plugin capability grants stored by the daemon, outside Agent MD.

@ProviderFor(AgentPluginGrantsController)
final agentPluginGrantsControllerProvider =
    AgentPluginGrantsControllerFamily._();

/// Agent-owned plugin capability grants stored by the daemon, outside Agent MD.
final class AgentPluginGrantsControllerProvider
    extends
        $AsyncNotifierProvider<
          AgentPluginGrantsController,
          List<AgentPluginGrantDto>
        > {
  /// Agent-owned plugin capability grants stored by the daemon, outside Agent MD.
  AgentPluginGrantsControllerProvider._({
    required AgentPluginGrantsControllerFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'agentPluginGrantsControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$agentPluginGrantsControllerHash();

  @override
  String toString() {
    return r'agentPluginGrantsControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  AgentPluginGrantsController create() => AgentPluginGrantsController();

  @override
  bool operator ==(Object other) {
    return other is AgentPluginGrantsControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$agentPluginGrantsControllerHash() =>
    r'224f9f49a81e151ac04dcb9281e2eb5932d8d9b5';

/// Agent-owned plugin capability grants stored by the daemon, outside Agent MD.

final class AgentPluginGrantsControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          AgentPluginGrantsController,
          AsyncValue<List<AgentPluginGrantDto>>,
          List<AgentPluginGrantDto>,
          FutureOr<List<AgentPluginGrantDto>>,
          (String, String)
        > {
  AgentPluginGrantsControllerFamily._()
    : super(
        retry: null,
        name: r'agentPluginGrantsControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Agent-owned plugin capability grants stored by the daemon, outside Agent MD.

  AgentPluginGrantsControllerProvider call(String hostId, String agentId) =>
      AgentPluginGrantsControllerProvider._(
        argument: (hostId, agentId),
        from: this,
      );

  @override
  String toString() => r'agentPluginGrantsControllerProvider';
}

/// Agent-owned plugin capability grants stored by the daemon, outside Agent MD.

abstract class _$AgentPluginGrantsController
    extends $AsyncNotifier<List<AgentPluginGrantDto>> {
  late final _$args = ref.$arg as (String, String);
  String get hostId => _$args.$1;
  String get agentId => _$args.$2;

  FutureOr<List<AgentPluginGrantDto>> build(String hostId, String agentId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<AgentPluginGrantDto>>,
              List<AgentPluginGrantDto>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<AgentPluginGrantDto>>,
                List<AgentPluginGrantDto>
              >,
              AsyncValue<List<AgentPluginGrantDto>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}

/// Reads and mutates one durable Agent-owned plugin session control.

@ProviderFor(PluginSessionControlController)
final pluginSessionControlControllerProvider =
    PluginSessionControlControllerFamily._();

/// Reads and mutates one durable Agent-owned plugin session control.
final class PluginSessionControlControllerProvider
    extends
        $AsyncNotifierProvider<
          PluginSessionControlController,
          PluginSessionControlValueDto
        > {
  /// Reads and mutates one durable Agent-owned plugin session control.
  PluginSessionControlControllerProvider._({
    required PluginSessionControlControllerFamily super.from,
    required (String, String, String, String) super.argument,
  }) : super(
         retry: null,
         name: r'pluginSessionControlControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pluginSessionControlControllerHash();

  @override
  String toString() {
    return r'pluginSessionControlControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  PluginSessionControlController create() => PluginSessionControlController();

  @override
  bool operator ==(Object other) {
    return other is PluginSessionControlControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pluginSessionControlControllerHash() =>
    r'98e081d0dce0b11eade1b104e3a41161359b6acf';

/// Reads and mutates one durable Agent-owned plugin session control.

final class PluginSessionControlControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          PluginSessionControlController,
          AsyncValue<PluginSessionControlValueDto>,
          PluginSessionControlValueDto,
          FutureOr<PluginSessionControlValueDto>,
          (String, String, String, String)
        > {
  PluginSessionControlControllerFamily._()
    : super(
        retry: null,
        name: r'pluginSessionControlControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Reads and mutates one durable Agent-owned plugin session control.

  PluginSessionControlControllerProvider call(
    String hostId,
    String sessionId,
    String pluginId,
    String contributionId,
  ) => PluginSessionControlControllerProvider._(
    argument: (hostId, sessionId, pluginId, contributionId),
    from: this,
  );

  @override
  String toString() => r'pluginSessionControlControllerProvider';
}

/// Reads and mutates one durable Agent-owned plugin session control.

abstract class _$PluginSessionControlController
    extends $AsyncNotifier<PluginSessionControlValueDto> {
  late final _$args = ref.$arg as (String, String, String, String);
  String get hostId => _$args.$1;
  String get sessionId => _$args.$2;
  String get pluginId => _$args.$3;
  String get contributionId => _$args.$4;

  FutureOr<PluginSessionControlValueDto> build(
    String hostId,
    String sessionId,
    String pluginId,
    String contributionId,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<PluginSessionControlValueDto>,
              PluginSessionControlValueDto
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<PluginSessionControlValueDto>,
                PluginSessionControlValueDto
              >,
              AsyncValue<PluginSessionControlValueDto>,
              Object?,
              Object?
            >;
    return element.handleCreate(
      ref,
      () => build(_$args.$1, _$args.$2, _$args.$3, _$args.$4),
    );
  }
}
