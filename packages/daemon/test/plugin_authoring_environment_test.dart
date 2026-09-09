@Tags(<String>['feature_test__plugin_authoring__unit'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:daemon/src/features/plugins/infrastructure/plugin_authoring.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_bundles.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_service.dart';
import 'package:daemon/src/features/plugins/transport/rpc_bindings.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:daemon/src/transport/rpc/binding.dart';
import 'package:path/path.dart' as p;
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  late Directory config;
  late Directory plugin;
  late PluginAuthoringEnvironmentService service;

  setUp(() async {
    config = await Directory.systemTemp.createTemp('tinest-authoring-');
    plugin = Directory(p.join(config.path, 'v5', 'plugins', 'acme.reader'));
    await plugin.create(recursive: true);
    service = PluginAuthoringEnvironmentService(
      configDirectory: config.path,
      sdk: const _Sdk(),
      ids: _Ids(),
    );
  });

  tearDown(() => config.delete(recursive: true));

  test('reports missing sidecars without mutating plugin source', () async {
    final environment = await service.get('acme.reader');

    expect(environment.synchronized, isFalse);
    expect(
      environment.diagnostics.map((item) => item.code),
      containsAll(<String>[
        'plugin_sdk_missing',
        'luarc_missing',
        'plugin_types_missing',
      ]),
    );
    expect(File(environment.configurationPath).existsSync(), isFalse);
    expect(Directory(environment.sdkLibraryPath).existsSync(), isFalse);
  });

  test('synchronizes exact ABI library metadata and sandbox config', () async {
    final environment = await service.sync('acme.reader');

    expect(environment.synchronized, isTrue);
    expect(environment.sdkAbiHash, _Sdk.abi);
    expect(
      await File(p.join(environment.sdkLibraryPath, 'tinest.lua'))
          .readAsString(),
      contains('---@class tinest.Api'),
    );
    final metadata = jsonDecode(
      await File(p.join(p.dirname(environment.sdkLibraryPath), 'sdk.json'))
          .readAsString(),
    ) as Map<String, dynamic>;
    expect(metadata, <String, dynamic>{
      'apiMajor': 5,
      'sdkAbiHash': _Sdk.abi,
      'luaRuntimeVersion': '5.5.1',
      'luaLanguageServerVersion': '3.18.2',
    });
    final luarc = jsonDecode(
      await File(environment.configurationPath).readAsString(),
    ) as Map<String, dynamic>;
    expect(luarc['runtime.version'], 'Lua 5.5');
    final libraries = (luarc['workspace.library']! as List<dynamic>)
        .cast<String>();
    expect(libraries, hasLength(2));
    expect(libraries.first, environment.sdkLibraryPath);
    expect(
      await File(p.join(libraries.last, 'types.d.lua')).readAsString(),
      allOf(contains('---@meta tinest.types'), contains('.Types')),
    );
    expect(p.isWithin(plugin.path, libraries.last), isFalse);
    expect(luarc['runtime.builtin'], containsPair('debug', 'disable'));
    expect(luarc['runtime.builtin'], containsPair('basic', 'disable'));
    expect(luarc['runtime.builtin'], containsPair('coroutine', 'disable'));
    expect(luarc['runtime.builtin'], containsPair('io', 'disable'));
    expect(luarc['runtime.builtin'], containsPair('os', 'disable'));
    expect(luarc['runtime.builtin'], containsPair('package', 'disable'));
    expect(luarc['diagnostics.globals'], isEmpty);
    final sandbox = await File(
      p.join(environment.sdkLibraryPath, 'tinest-sandbox.d.lua'),
    ).readAsString();
    for (final safeGlobal in const <String>[
      'assert',
      'error',
      'ipairs',
      'next',
      'pairs',
      'pcall',
      'select',
      'tonumber',
      'tostring',
      'type',
      'xpcall',
      'require',
    ]) {
      expect(sandbox, contains('function $safeGlobal('));
    }
    for (final safeLibrary in const <String>[
      'math',
      'string',
      'table',
      'utf8',
    ]) {
      expect(sandbox, contains('---@field $safeLibrary'));
    }
    for (final unavailableGlobal in const <String>[
      'collectgarbage',
      'dofile',
      'load',
      'loadfile',
      'rawget',
      'rawset',
      'getmetatable',
      'setmetatable',
    ]) {
      expect(sandbox, isNot(contains('function $unavailableGlobal(')));
    }

    expect((await service.sync('acme.reader')).synchronized, isTrue);
  });

  test(
    'serializes concurrent synchronization without partial sidecars',
    () async {
      final results = await Future.wait(<Future<PluginAuthoringEnvironmentDto>>[
        service.sync('acme.reader'),
        service.sync('acme.reader'),
      ]);

      expect(
        results.map((result) => result.synchronized),
        everyElement(isTrue),
      );
      expect((await service.get('acme.reader')).synchronized, isTrue);
    },
  );

  test('detects and repairs drift without accepting reserved IDs', () async {
    final first = await service.sync('acme.reader');
    await File(first.configurationPath).writeAsString('{}');

    final drifted = await service.get('acme.reader');
    expect(drifted.synchronized, isFalse);
    expect(
      drifted.diagnostics.map((item) => item.code),
      contains('luarc_out_of_sync'),
    );
    expect((await service.sync('acme.reader')).synchronized, isTrue);
    await expectLater(
      service.get('tinest.files'),
      throwsA(isA<PluginAuthoringException>()),
    );
  });

  test('marks generated types stale and repairs them outside source', () async {
    await File(p.join(plugin.path, 'main.lua')).writeAsString('''
local tinest = require("tinest")
local S = tinest.schema
local T = require("tinest.types")
local Input = S.object(T.Input, {path = S.string()})
return tinest.plugin.define({})
''');
    final first = await service.sync('acme.reader');
    expect(first.synchronized, isTrue);

    await File(p.join(plugin.path, 'main.lua')).writeAsString('''
local tinest = require("tinest")
local S = tinest.schema
local T = require("tinest.types")
local Input = S.object(T.Input, {
  path = S.string(),
  line = S.optional(S.integer()),
})
return tinest.plugin.define({})
''');

    final stale = await service.get('acme.reader');
    expect(
      stale.diagnostics.map((diagnostic) => diagnostic.code),
      contains('plugin_types_out_of_sync'),
    );
    final repaired = await service.sync('acme.reader');
    expect(repaired.synchronized, isTrue);
    final luarc = jsonDecode(
      await File(repaired.configurationPath).readAsString(),
    ) as Map<String, dynamic>;
    final typesRoot =
        (luarc['workspace.library']! as List<dynamic>).last as String;
    final types = await File(p.join(typesRoot, 'types.d.lua')).readAsString();
    expect(types, contains('---@field line? integer'));
    expect(File(p.join(plugin.path, 'types.d.lua')).existsSync(), isFalse);
  });

  test('native scaffold installs a reference-based typed workspace', () async {
    await plugin.delete(recursive: true);
    final sources = NativePluginSourceCatalog(config.path, authoring: service);

    await sources.scaffold('acme.reader', 'Reader');

    final source = await File(p.join(plugin.path, 'main.lua')).readAsString();
    expect(source, contains('local tinest = require("tinest")'));
    expect(source, contains('local T = require("tinest.types")'));
    expect(source, contains('S.object(T.Input'));
    expect(source, contains('S.object(T.Output'));
    final stringWiringViolations = <String>[
      if (RegExp(r'\bhandler\s*=').hasMatch(source)) 'handler binding',
      if (RegExp(r'''\.(?:call|open)\s*\(\s*["']''').hasMatch(source))
        'host operation',
      if (RegExp(r'\bactionId\s*=').hasMatch(source)) 'UI action',
      if (RegExp(r'\bcontribution_id\s*=').hasMatch(source)) 'UI contribution',
      if (RegExp(r'''tinest\.scheduler\.[a-z_]+\s*\(\s*["']''')
          .hasMatch(source))
        'scheduled handler',
      if (RegExp(r'''tinest\.tools\.invoke\s*\(\s*["']''').hasMatch(source))
        'tool invocation',
    ];
    expect(
      stringWiringViolations,
      isEmpty,
      reason: 'The scaffold must wire executable behavior through SDK refs.',
    );
    expect(File(p.join(plugin.path, '.luarc.json')).existsSync(), isTrue);
    final bundle = await NativePluginBundleLoader(config.path)
        .load('acme.reader');
    expect(bundle.assets, isNot(contains('.luarc.json')));
    expect(bundle.revision.sdkAbiHash, hasLength(64));
  });

  test('native fork synchronizes the target to the exact SDK ABI', () async {
    await plugin.delete(recursive: true);
    final sources = NativePluginSourceCatalog(config.path, authoring: service);
    await sources.scaffold('acme.source', 'Source');
    final source = await NativePluginBundleLoader(config.path)
        .load('acme.source');

    await sources.fork(source, 'acme.reader', 'Reader');

    final environment = await service.get('acme.reader');
    expect(environment.synchronized, isTrue);
    expect(environment.sdkAbiHash, _Sdk.abi);
    final luarc = jsonDecode(
      await File(environment.configurationPath).readAsString(),
    ) as Map<String, dynamic>;
    expect(luarc['runtime.version'], 'Lua 5.5');
    expect(
      (luarc['workspace.library']! as List<dynamic>).first,
      environment.sdkLibraryPath,
    );
    expect(
      File(p.join(p.dirname(environment.sdkLibraryPath), 'sdk.json'))
          .existsSync(),
      isTrue,
    );
  });

  test('RPC exposes read-only status and explicit synchronization', () async {
    final bindings = <String, RpcBindingDescriptor>{
      for (final binding in pluginAuthoringRpcBindings(authoring: service))
        binding.procedure.name: binding,
    };
    final context = RpcConnectionContext();

    final before = PluginAuthoringEnvironmentResultDto.fromJson(
      jsonDecode(
        jsonEncode(
          await bindings[pluginsGetPluginAuthoringEnvironmentProcedure.name]!
              .invoke(
                const PluginIdParamsDto(id: 'acme.reader').toJson(),
                context,
              ),
        ),
      ) as Map<String, dynamic>,
    );
    expect(before.environment.synchronized, isFalse);

    final after = PluginAuthoringEnvironmentResultDto.fromJson(
      jsonDecode(
        jsonEncode(
          await bindings[pluginsSyncPluginAuthoringEnvironmentProcedure.name]!
              .invoke(
                const PluginIdParamsDto(id: 'acme.reader').toJson(),
                context,
              ),
        ),
      ) as Map<String, dynamic>,
    );
    expect(after.environment.synchronized, isTrue);
  });
}

final class _Sdk implements PluginSdkAuthoringProvider {
  const new();

  static const String abi =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  @override
  int get apiMajor => 5;

  @override
  Map<String, String> get authoringLibraryAssets => const <String, String>{
    'library/tinest.lua': '---@meta\n---@class tinest.Api\nreturn {}\n',
    'library/tinest-sandbox.d.lua': '''
---@meta
---@class tinest.SandboxLibraries
---@field math table
---@field string table
---@field table table
---@field utf8 table
function assert(value) end
function error(message) end
function ipairs(value) end
function next(value) end
function pairs(value) end
function pcall(callback) end
function select(index, ...) end
function tonumber(value) end
function tostring(value) end
function type(value) end
function xpcall(callback, handler) end
function require(name) end
''',
  };

  @override
  String get luaLanguageServerVersion => '3.18.2';

  @override
  String get luaRuntimeVersion => '5.5.1';

  @override
  String get sdkAbiHash => abi;
}

final class _Ids implements IdGenerator {
  var _next = 0;

  @override
  String generate() => 'authoring-${_next++}';
}
