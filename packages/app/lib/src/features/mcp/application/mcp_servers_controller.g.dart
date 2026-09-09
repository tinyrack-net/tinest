// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp_servers_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Loads and edits one daemon's MCP server configuration.

@ProviderFor(McpServersController)
final mcpServersControllerProvider = McpServersControllerFamily._();

/// Loads and edits one daemon's MCP server configuration.
final class McpServersControllerProvider
    extends $AsyncNotifierProvider<McpServersController, McpServersState> {
  /// Loads and edits one daemon's MCP server configuration.
  McpServersControllerProvider._({
    required McpServersControllerFamily super.from,
    required (String, String?) super.argument,
  }) : super(
         retry: noAutomaticRetry,
         name: r'mcpServersControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mcpServersControllerHash();

  @override
  String toString() {
    return r'mcpServersControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  McpServersController create() => McpServersController();

  @override
  bool operator ==(Object other) {
    return other is McpServersControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mcpServersControllerHash() =>
    r'536f4c20521653824902735987281cb7b9d8c921';

/// Loads and edits one daemon's MCP server configuration.

final class McpServersControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          McpServersController,
          AsyncValue<McpServersState>,
          McpServersState,
          FutureOr<McpServersState>,
          (String, String?)
        > {
  McpServersControllerFamily._()
    : super(
        retry: noAutomaticRetry,
        name: r'mcpServersControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Loads and edits one daemon's MCP server configuration.

  McpServersControllerProvider call(String hostId, String? worktreeId) =>
      McpServersControllerProvider._(
        argument: (hostId, worktreeId),
        from: this,
      );

  @override
  String toString() => r'mcpServersControllerProvider';
}

/// Loads and edits one daemon's MCP server configuration.

abstract class _$McpServersController extends $AsyncNotifier<McpServersState> {
  late final _$args = ref.$arg as (String, String?);
  String get hostId => _$args.$1;
  String? get worktreeId => _$args.$2;

  FutureOr<McpServersState> build(String hostId, String? worktreeId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<McpServersState>, McpServersState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<McpServersState>, McpServersState>,
              AsyncValue<McpServersState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}
