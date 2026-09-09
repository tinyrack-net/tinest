import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:daemon/src/features/plugins/runtime/host_primitive_contracts.dart';
import 'package:daemon/src/features/plugins/runtime/host_primitives.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_sdk_assets.g.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_type_environment.dart';
import 'package:lua_tool_runtime/lua_tool_runtime.dart' as lua;
import 'package:protocol/protocol.dart';

/// Dependency-neutral immutable plugin bytes consumed by the Lua SDK.
abstract interface class PluginLuaProgramSource {
  /// Validated public descriptor.
  PluginDescriptorDto get descriptor;

  /// Exact validated revision.
  PluginRevisionDto get revision;

  /// Detached, bundle-relative Lua and Markdown bytes.
  Map<String, Uint8List> get assets;
}

/// Converts a validated Tinest plugin revision into the public Lua SDK bundle.
abstract final class TinestLuaPluginSdk {
  /// Breaking public plugin API implemented by this SDK.
  static const int apiMajor = 5;

  /// Public module imported by plugin code with `require("tinest")`.
  static const String publicModuleName = 'tinest';

  /// Lua runtime whose standard library and syntax are described by the SDK.
  static const String luaRuntimeVersion = '5.5.1';

  /// LuaLS release used by Tinest's authoring conformance suite.
  static const String luaLanguageServerVersion = '3.18.2';

  /// Safety-only native primitive descriptors used to build the Lua refs.
  ///
  /// Model names, schemas, descriptions, defaults, and presentation are
  /// intentionally absent. Those remain owned by Lua contributions.
  static final List<HostPrimitiveDescriptor> primitiveDescriptors =
      List<HostPrimitiveDescriptor>.unmodifiable(
        HostPrimitiveContracts.all.map((contract) => contract.descriptor),
      );

  /// Fails closed when the native safety registry drifts from public Lua refs.
  static void validatePrimitiveRegistry(
    HostPrimitiveRegistry registry, {
    Set<String> unavailableOperations = const <String>{},
  }) => validateHostPrimitiveRegistry(
    registry,
    unavailableOperations: unavailableOperations,
  );

  /// Runtime modules that form the public SDK ABI.
  static final Map<String, String> runtimeModuleAssets =
      Map<String, String>.unmodifiable(<String, String>{
        publicModuleName: _sdkSource,
        'tinest.primitive_descriptors': _primitiveDescriptorModuleSource(),
        'tinest.host_primitives': _hostPrimitiveModuleSource(),
        'tinest.types': _typeTokenModuleSource,
      });

  /// Editor-neutral LuaLS library files shipped to plugin authors.
  ///
  /// The executable module is also the annotation source, preventing runtime
  /// and editor surfaces from drifting apart.
  static final Map<String, String> authoringLibraryAssets =
      Map<String, String>.unmodifiable(<String, String>{
        'library/tinest.lua': _sdkSource,
        'library/tinest-sandbox.d.lua': _sandboxDefinitionSource,
        'library/tinest/primitive_descriptors.lua':
            _primitiveDescriptorModuleSource(),
        'library/tinest/host_primitives.lua': _hostPrimitiveModuleSource(),
      });

  /// Exact ABI identity used to invalidate revision and editor caches.
  static final String sdkAbiHash = _hashAssets(<String, String>{
    for (final entry in runtimeModuleAssets.entries)
      'runtime/${entry.key}': entry.value,
    // The revision-specific wrapper is executable SDK code as well. Hash a
    // canonical instance so hardening it invalidates pinned execution bundles.
    'runtime/$_entrypointModule': _entrypointSource(
      'tinest.plugin_main',
      '__tinest_plugin_id__',
    ),
    for (final entry in authoringLibraryAssets.entries)
      'authoring/${entry.key}': entry.value,
  });

  /// Composes immutable Lua and Markdown assets without retaining filesystem
  /// access or a mutable reference to [bundle].
  static lua.LuaProgramBundle compose(PluginLuaProgramSource bundle) {
    final modules = <String, String>{...runtimeModuleAssets};
    final markdown = <String, String>{};
    final pluginLua = <String, String>{};
    for (final asset in bundle.assets.entries) {
      if (asset.key == 'PLUGIN.md') continue;
      final source = _decode(asset.value, asset.key);
      if (asset.key.endsWith('.md')) {
        markdown[asset.key] = source;
        continue;
      }
      if (!asset.key.endsWith('.lua')) continue;
      pluginLua[asset.key] = source;
      final module = _moduleName(asset.key);
      if (modules.containsKey(module) || module == _entrypointModule) {
        throw PluginRuntimeBundleException(
          'Plugin module collides with a reserved Tinest SDK module.',
          path: asset.key,
        );
      }
      modules[module] = source;
    }
    final typeNames = PluginTypeEnvironmentGenerator.referencedTokenNames(
      pluginLua,
    );
    modules['tinest.types'] = _typeTokenModuleSource.replaceFirst(
      '__TINEST_TYPE_NAMES__',
      _luaLiteral(typeNames),
    );
    final pluginEntrypoint = _moduleName(bundle.descriptor.entrypoint);
    if (!modules.containsKey(pluginEntrypoint)) {
      throw PluginRuntimeBundleException(
        'Plugin entrypoint is absent from the immutable revision.',
        path: bundle.descriptor.entrypoint,
      );
    }
    modules[_entrypointModule] = _entrypointSource(
      pluginEntrypoint,
      bundle.descriptor.id,
    );
    return lua.LuaProgramBundle(
      revision:
          '${bundle.descriptor.id}:${bundle.revision.executionRevisionHash}',
      entrypoint: _entrypointModule,
      modules: modules,
      markdownAssets: markdown,
    );
  }
}

const String _typeTokenModuleSource = '''
local sdk = require("tinest")
local types = sdk.__install_type_tokens(__TINEST_TYPE_NAMES__)
sdk.__install_type_tokens = nil
return types
''';

String _primitiveDescriptorModuleSource() {
  final descriptors = <Map<String, Object?>>[
    for (final descriptor in TinestLuaPluginSdk.primitiveDescriptors)
      descriptor.toJson(),
  ];
  return 'return ${_luaLiteral(descriptors)}\n';
}

String _hostPrimitiveModuleSource() {
  const contracts = HostPrimitiveContracts.all;
  final byScope = <String, List<PublicHostPrimitiveContract>>{};
  for (final contract in contracts) {
    final segments = contract.operation.split('.');
    if (segments.length != 3 || segments.first != 'host') {
      throw StateError(
        'Host primitive operation cannot generate a Lua wrapper: '
        '${contract.operation}.',
      );
    }
    byScope
        .putIfAbsent(segments[1], () => <PublicHostPrimitiveContract>[])
        .add(contract);
  }
  final output = StringBuffer('''
local descriptors = require("tinest.primitive_descriptors")

''');
  for (final entry in byScope.entries) {
    output.writeln('---@class (exact) tinest.Host${_pascal(entry.key)}Api');
    for (final contract in entry.value) {
      final member = contract.operation.split('.')[2];
      output.writeln(
        '---@field $member fun(arguments: ${contract.luaInputType}): '
        'tinest.HostResult<${contract.luaOutputType}>',
      );
    }
    output.writeln();
  }
  output.writeln(r'''
---@param sdk table
---@param install_primitive fun(scope: string, member: string, capability: string, effect: string, stream: boolean?)
---@param references table
return function(sdk, install_primitive, references)
  for _, descriptor in ipairs(descriptors) do
    local scope, member = descriptor.operation:match(
      "^host%.([a-z_]+)%.([a-z_]+)$"
    )
    if scope == nil or member == nil or sdk.host[scope] == nil then
      error(
        "invalid native primitive descriptor: " ..
          tostring(descriptor.operation),
        2
      )
    end
    install_primitive(
      scope, member, descriptor.capability, descriptor.effect, false
    )
  end
''');
  for (final contract in contracts) {
    final segments = contract.operation.split('.');
    final scope = segments[1];
    final member = segments[2];
    final localName = 'host_${scope}_$member';
    output
      ..writeln('  local $localName = sdk.host.$scope.$member')
      ..writeln('  ---@param arguments ${contract.luaInputType}')
      ..writeln('  ---@return tinest.HostResult<${contract.luaOutputType}>')
      ..writeln('  function sdk.host.$scope.$member(arguments)')
      ..writeln('    return $localName(arguments)')
      ..writeln('  end')
      ..writeln(
        '  references[sdk.host.$scope.$member] = references[$localName]',
      )
      ..writeln();
  }
  output.writeln('end');
  return output.toString();
}

String _pascal(String value) => value
    .split('_')
    .where((segment) => segment.isNotEmpty)
    .map((segment) => '${segment[0].toUpperCase()}${segment.substring(1)}')
    .join();

String _luaLiteral(Object? value) => switch (value) {
  null => 'nil',
  final bool flag => flag ? 'true' : 'false',
  final num number => number.toString(),
  final String string => jsonEncode(string),
  final List<Object?> values => '{${values.map(_luaLiteral).join(',')}}',
  final Map<String, Object?> values =>
    '{${values.entries.map((entry) => '[${jsonEncode(entry.key)}]='
        '${_luaLiteral(entry.value)}').join(',')}}',
  _ => throw ArgumentError.value(value, 'value', 'Not JSON-compatible.'),
};

/// A validated plugin could not be mapped into the immutable Lua module map.
final class PluginRuntimeBundleException extends FormatException {
  /// Creates a runtime bundle failure.
  const new(super.message, {this.path});

  /// Bundle-relative asset associated with the error.
  final String? path;
}

const String _entrypointModule = 'tinest.entrypoint';

String _hashAssets(Map<String, String> assets) {
  final entries = assets.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  final canonical = entries.map((entry) {
    return '${entry.key.length}:${entry.key}'
        '${entry.value.length}:${entry.value}';
  }).join();
  return sha256.convert(utf8.encode(canonical)).toString();
}

String _decode(List<int> bytes, String path) {
  try {
    return utf8.decode(bytes, allowMalformed: false);
  } on FormatException catch (error) {
    throw PluginRuntimeBundleException(
      'Plugin text asset is not valid UTF-8: ${error.message}',
      path: path,
    );
  }
}

String _moduleName(String path) {
  if (path == 'main.lua') return 'tinest.plugin_main';
  if (!path.startsWith('lua/') || !path.endsWith('.lua')) {
    throw PluginRuntimeBundleException(
      'Lua assets must be main.lua or lua/**/*.lua.',
      path: path,
    );
  }
  return path
      .substring('lua/'.length, path.length - '.lua'.length)
      .split('/')
      .join('.');
}

String _entrypointSource(String pluginEntrypoint, String pluginId) =>
    '''
local load_module = require
local sdk = load_module("tinest")
local set_identity = sdk.__set_identity
local export_definition = sdk.__entrypoint
sdk.__set_identity = nil
sdk.__entrypoint = nil
set_identity(${jsonEncode(pluginId)})
load_module("tinest.types")
_ENV.require = function(name)
  if name == ${jsonEncode(_entrypointModule)} then
    error("private Tinest module is unavailable: " .. name, 2)
  end
  return load_module(name)
end
local definition = load_module(${jsonEncode(pluginEntrypoint)})
return export_definition(definition)
''';

// This executable module is deliberately annotated with LuaCATS so the exact
// same source can be installed as a LuaLS definition library.
final String _sdkSource = utf8.decode(
  base64Decode(tinestLuaSdkSourceBase64),
  allowMalformed: false,
);

final String _sandboxDefinitionSource = utf8.decode(
  base64Decode(tinestLuaSandboxDefinitionSourceBase64),
  allowMalformed: false,
);
