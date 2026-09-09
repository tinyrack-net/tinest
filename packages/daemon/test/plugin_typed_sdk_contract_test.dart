@Tags(<String>['feature_test__plugin_runtime__unit'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:daemon/src/features/plugins/infrastructure/plugin_bundles.dart';
import 'package:daemon/src/features/plugins/runtime/host_primitives.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_registration.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_sdk.dart';
import 'package:path/path.dart' as p;
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  test('publishes require("tinest") without installing a magic global', () {
    final program = TinestLuaPluginSdk.compose(
      _bundle('''
local tinest = require("tinest")
return tinest.plugin.define({})
'''),
    );

    expect(TinestLuaPluginSdk.publicModuleName, 'tinest');
    expect(program.modules, contains('tinest'));
    expect(program.modules, isNot(contains('tinest.sdk')));
    expect(program.preloadModules, isEmpty);
    expect(program.modules['tinest'], isNot(contains('\ntinest =')));
    expect(program.modules['tinest'], contains('runtime_json_null_key,'));
    expect(program.modules['tinest'], contains('_ENV[key] = nil'));
    expect(program.modules['tinest'], isNot(contains('\nNULL = nil')));
    expect(
      program.modules['tinest'],
      isNot(contains('runtime_json_null = NULL')),
    );
    expect(program.modules['tinest'], isNot(contains('_ENV["NULL"]')));
    for (final name in const <String>[
      'host',
      'assets',
      'tools',
      'store',
      'load',
      'ALL_TOOLS',
      'spawn',
      'await',
      'await_all',
      'text',
      'image',
      'audio',
      'generated_image',
      'notify',
      'yield_control',
      'exit',
      'set_timeout',
      'clear_timeout',
      '_G',
    ]) {
      expect(program.modules['tinest'], isNot(contains('\n$name = nil')));
    }
    expect(program.modules['tinest'], contains('null = runtime_json_null'));
    expect(program.modules['tinest'], contains('is_null = function(value)'));
    expect(
      program.modules['tinest'],
      contains('function tinest.tools.model_input'),
    );
  });

  test('runtime and LuaLS load the same generated SDK source asset', () async {
    final source = await File(p.join('plugin_sdk', 'library', 'tinest.lua'))
        .readAsString();
    final runtime = TinestLuaPluginSdk.runtimeModuleAssets['tinest'];
    final authoring =
        TinestLuaPluginSdk.authoringLibraryAssets['library/tinest.lua'];

    expect(runtime, source);
    expect(authoring, source);
    expect(
      await File(
        p.join(
          'lib',
          'src',
          'features',
          'plugins',
          'runtime',
          'plugin_sdk.dart',
        ),
      ).readAsString(),
      isNot(contains('const String _sdkSource')),
    );
    expect(utf8.encode(source), isNotEmpty);
  });

  test(
    'publishes an authoring-only definition of the sandbox globals',
    () async {
      final source = await File(
        p.join('plugin_sdk', 'library', 'tinest-sandbox.d.lua'),
      ).readAsString();

      expect(
        TinestLuaPluginSdk
            .authoringLibraryAssets['library/tinest-sandbox.d.lua'],
        source,
      );
      expect(
        TinestLuaPluginSdk.runtimeModuleAssets.values,
        isNot(contains(source)),
      );
      expect(source, contains('function require('));
      expect(source, isNot(contains('function load(')));
      expect(source, isNot(contains('function collectgarbage(')));
    },
  );

  test('generates direct host refs from safety-only primitive descriptors', () {
    final sdk = TinestLuaPluginSdk.runtimeModuleAssets['tinest']!;
    final descriptorModule =
        TinestLuaPluginSdk.runtimeModuleAssets['tinest.primitive_descriptors']!;
    final hostModule =
        TinestLuaPluginSdk.runtimeModuleAssets['tinest.host_primitives']!;

    expect(sdk, contains('require("tinest.host_primitives")'));
    expect(sdk, isNot(contains('function tinest.host.')));
    expect(sdk, isNot(contains('patch = {}')));
    expect(descriptorModule, contains('host.process.terminate'));
    expect(descriptorModule, isNot(contains('description')));
    expect(descriptorModule, isNot(contains('input_schema')));
    expect(hostModule, contains('tinest.ProcessStartInput'));
    expect(hostModule, contains('require("tinest.primitive_descriptors")'));
    expect(hostModule, contains('tinest.HostResult<tinest.ProcessHandle>'));
    expect(hostModule, contains('function sdk.host.process.start(arguments)'));
    expect(
      TinestLuaPluginSdk
          .authoringLibraryAssets['library/tinest/host_primitives.lua'],
      hostModule,
    );
  });

  test(
    'SDK primitive metadata is generated only from typed contracts',
    () async {
      final sdkSource = await File(
        p.join(
          'lib',
          'src',
          'features',
          'plugins',
          'runtime',
          'plugin_sdk.dart',
        ),
      ).readAsString();
      final luaSource = await File(
        p.join('plugin_sdk', 'library', 'tinest.lua'),
      ).readAsString();

      expect(sdkSource, contains('HostPrimitiveContracts.all.map'));
      expect(sdkSource, isNot(contains("operation: 'host.")));
      expect(luaSource, isNot(contains('local workspace_read_text')));
      expect(luaSource, isNot(contains('function tinest.host.')));
    },
  );

  test('literal enums expose author-owned code keys without string joins', () {
    final sdk = TinestLuaPluginSdk.runtimeModuleAssets['tinest']!;

    expect(sdk, contains('function schema.literal_enum(token, values)'));
    expect(sdk, contains('constants[key] = value'));
    expect(sdk, contains('schema.literal_enum requires at least one value'));
  });

  test('composes revision-local opaque type tokens before author code', () {
    final program = TinestLuaPluginSdk.compose(
      _bundle('''
local tinest = require("tinest")
local S = tinest.schema
local T = require("tinest.types")
local Input = S.object(T.Input, {path = S.string()})
return tinest.plugin.define({})
'''),
    );

    expect(program.modules, contains('tinest.types'));
    expect(
      program.modules['tinest.types'],
      contains('sdk.__install_type_tokens({"Input"})'),
    );
    final entrypoint = program.modules['tinest.entrypoint']!;
    expect(entrypoint, contains('local load_module = require'));
    expect(entrypoint, contains('local sdk = load_module("tinest")'));
    expect(entrypoint, contains('load_module("tinest.types")'));
    expect(entrypoint, contains('local export_definition = sdk.__entrypoint'));
    expect(entrypoint, contains('sdk.__set_identity = nil'));
    expect(entrypoint, contains('sdk.__entrypoint = nil'));
    expect(entrypoint, contains('_ENV.require = function(name)'));
    expect(entrypoint, contains('if name == "tinest.entrypoint" then'));
    expect(entrypoint, contains('return load_module(name)'));
    expect(
      entrypoint,
      contains('local definition = load_module("tinest.plugin_main")'),
    );
    expect(
      entrypoint.indexOf('sdk.__entrypoint = nil'),
      lessThan(entrypoint.indexOf('_ENV.require = function(name)')),
    );
    expect(
      entrypoint.indexOf('_ENV.require = function(name)'),
      lessThan(
        entrypoint.indexOf(
          'local definition = load_module("tinest.plugin_main")',
        ),
      ),
    );
  });

  test('private entrypoint wrapper remains part of the SDK ABI hash', () async {
    final sdkSource = await File(
      p.join('lib', 'src', 'features', 'plugins', 'runtime', 'plugin_sdk.dart'),
    ).readAsString();
    final abiHashStart = sdkSource.indexOf(
      'static final String sdkAbiHash = _hashAssets',
    );
    final composeStart = sdkSource.indexOf(
      'static lua.LuaProgramBundle compose',
    );

    expect(abiHashStart, greaterThanOrEqualTo(0));
    expect(composeStart, greaterThan(abiHashStart));
    final abiHashSource = sdkSource.substring(abiHashStart, composeStart);
    expect(
      abiHashSource,
      contains(r"'runtime/$_entrypointModule': _entrypointSource("),
    );
    expect(abiHashSource, contains("'__tinest_plugin_id__'"));
  });

  test('runtime token refs survive exact authoring projection failure', () {
    final program = TinestLuaPluginSdk.compose(
      _bundle('''
local tinest = require("tinest")
local S = tinest.schema
local T = require("tinest.types")
local Input = S.object(T.Input, fields_from_a_runtime_module())
return tinest.plugin.define({})
'''),
    );

    expect(
      program.modules['tinest.types'],
      contains('sdk.__install_type_tokens({"Input"})'),
    );
  });

  test('fails closed when native primitive safety metadata drifts', () {
    expect(
      () => TinestLuaPluginSdk.validatePrimitiveRegistry(
        HostPrimitiveRegistry.empty(),
      ),
      throwsStateError,
    );
  });

  test('rejects author supplied named handler strings', () {
    expect(
      () => PluginRegistrationParser.parse(
        descriptor: _descriptor(),
        revisionHash: 'revision-1',
        value: <String, Object?>{
          'api': 5,
          'spec': <String, Object?>{
            'tools': <Object?>[
              <String, Object?>{
                'id': 'read',
                'handler': 'read',
                'kind': 'function',
                'input_schema': <String, Object?>{'type': 'object'},
              },
            ],
          },
        },
      ),
      throwsA(
        isA<PluginRegistrationException>().having(
          (error) => error.path,
          'path',
          r'$.tools[0].binding',
        ),
      ),
    );
  });

  test('parses only deterministic SDK closure bindings', () {
    final registration = PluginRegistrationParser.parse(
      descriptor: _descriptor(),
      revisionHash: 'revision-1',
      value: <String, Object?>{
        'api': 5,
        'spec': <String, Object?>{
          'tools': <Object?>[
            <String, Object?>{
              'id': 'read',
              'binding': <String, Object?>{
                'kind': 'tool',
                'id': 'read',
                'key': '__tinest.tool.read',
              },
              'kind': 'function',
              'input_schema': <String, Object?>{'type': 'object'},
              'presentation': <String, Object?>{
                'ui': <String, Object?>{'__tinest_ref': 'ui', 'id': 'card'},
                'requires': <Object?>[
                  <String, Object?>{'__tinest_ref': 'tool', 'id': 'read'},
                ],
              },
            },
          ],
          'ui': <Object?>[
            <String, Object?>{
              'id': 'card',
              'slot': 'timeline',
              'input_schema': <String, Object?>{'type': 'object'},
              'binding': <String, Object?>{
                'kind': 'ui',
                'id': 'card',
                'key': '__tinest.ui.card',
              },
            },
          ],
          'ui_actions': <Object?>[
            <String, Object?>{
              'id': 'refresh',
              'payload_schema': <String, Object?>{'type': 'boolean'},
              'binding': <String, Object?>{
                'kind': 'action',
                'id': 'refresh',
                'key': '__tinest.action.ui_action.refresh',
              },
            },
          ],
        },
      },
    );

    expect(registration.tools.single.binding.internalKey, '__tinest.tool.read');
    expect(registration.tools.single.binding.pluginId, 'acme.typed');
    expect(
      registration.tools.single.binding.executionRevisionHash,
      'revision-1',
    );
    expect(registration.tools.single.presentation['ui'], 'acme.typed/card');
    expect(registration.tools.single.presentation['requires'], <Object?>[
      'acme.typed/read',
    ]);
    expect(registration.ui.single.inputSchema, <String, Object?>{
      'type': 'object',
    });
    expect(registration.hooks.single.payloadSchema, <String, Object?>{
      'type': 'boolean',
    });
  });

  test('rejects forged deterministic binding keys', () {
    expect(
      () => PluginRegistrationParser.parse(
        descriptor: _descriptor(),
        revisionHash: 'revision-1',
        value: <String, Object?>{
          'api': 5,
          'spec': <String, Object?>{
            'tools': <Object?>[
              <String, Object?>{
                'id': 'read',
                'binding': <String, Object?>{
                  'kind': 'tool',
                  'id': 'read',
                  'key': '__tinest.tool.some_other_tool',
                },
                'kind': 'function',
                'input_schema': <String, Object?>{'type': 'object'},
              },
            ],
          },
        },
      ),
      throwsA(
        isA<PluginRegistrationException>().having(
          (error) => error.path,
          'path',
          r'$.tools[0].binding.key',
        ),
      ),
    );
  });

  test('registration retains scheduled handler payload schemas', () {
    final registration = PluginRegistrationParser.parse(
      descriptor: _descriptor(),
      revisionHash: 'revision-1',
      value: <String, Object?>{
        'api': 5,
        'spec': <String, Object?>{
          'hooks': <String, Object?>{
            'scheduled': <String, Object?>{
              'id': 'resume',
              'binding': <String, Object?>{
                'kind': 'hook',
                'id': 'resume',
                'key': '__tinest.hook.scheduled.resume',
              },
              'payload_schema': <String, Object?>{
                'type': 'object',
                'properties': <String, Object?>{
                  'count': <String, Object?>{'type': 'integer'},
                },
                'required': <Object?>['count'],
              },
            },
          },
        },
      },
    );

    expect(
      registration.hooks.single.payloadSchema,
      containsPair('required', <Object?>['count']),
    );
  });
}

PluginBundle _bundle(String source) => PluginBundle(
  descriptor: _descriptor(),
  revision: _descriptor().revision!,
  assets: <String, Uint8List>{
    'PLUGIN.md': Uint8List.fromList('---\napi: 5\n---'.codeUnits),
    'main.lua': Uint8List.fromList(source.codeUnits),
  },
);

PluginDescriptorDto _descriptor() => PluginDescriptorDto(
  apiMajor: 5,
  id: 'acme.typed',
  version: '1.0.0',
  name: 'Typed',
  entrypoint: 'main.lua',
  source: PluginSource.user,
  sourcePath: r'C:\config\v5\plugins\acme.typed',
  requestedCapabilities: <String>[],
  revision: PluginRevisionDto(
    pluginId: 'acme.typed',
    contentHash: 'revision-1',
    manifestHash: 'manifest-1',
    sdkAbiHash: TinestLuaPluginSdk.sdkAbiHash,
    executionRevisionHash: 'execution-revision-1',
    requestedCapabilities: <String>[],
  ),
);
