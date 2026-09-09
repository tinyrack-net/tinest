@Tags(<String>['feature_test__plugin_runtime__unit'])
library;

import 'dart:io';

import 'package:daemon/src/features/plugins/infrastructure/memory_plugin_stores.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_bundles.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_service.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_registration.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_sdk.dart';
import 'package:path/path.dart' as p;
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

const List<String> _builtInIds = <String>[
  'tinest.attachments',
  'tinest.collaboration',
  'tinest.context',
  'tinest.discovery',
  'tinest.edit',
  'tinest.files',
  'tinest.goal',
  'tinest.interaction',
  'tinest.lua-code',
  'tinest.mcp',
  'tinest.plan',
  'tinest.skills',
  'tinest.standard',
  'tinest.terminal',
  'tinest.time',
];

void main() {
  late Directory config;
  late Directory state;

  setUp(() async {
    config = await Directory.systemTemp.createTemp('tinest-builtins-config-');
    state = await Directory.systemTemp.createTemp('tinest-builtins-state-');
  });

  tearDown(() async {
    await config.delete(recursive: true);
    await state.delete(recursive: true);
  });

  test('embedded catalog contains the initial public SDK plugins', () async {
    const catalog = BuiltInPluginCatalog();

    expect(catalog.ids, _builtInIds);
    for (final id in catalog.ids) {
      final bundle = await catalog.load(id);
      expect(bundle.descriptor.id, id);
      expect(bundle.descriptor.source, PluginSource.builtIn);
      expect(bundle.descriptor.sourcePath, 'builtin://$id');
      expect(
        bundle.assets.keys,
        containsAll(<String>['PLUGIN.md', 'main.lua']),
      );
      expect(() => TinestLuaPluginSdk.compose(bundle), returnsNormally);
      expect(
        PluginRegistrationParser.parse,
        isNotNull,
        reason: 'Every built-in is consumable by the public registration SDK.',
      );
      final source = String.fromCharCodes(bundle.assets['main.lua']!);
      expect(source, contains('local tinest = require("tinest")'));
      final executableSource = source.replaceAll(
        RegExp(r'"(?:\\.|[^"\\])*"', multiLine: true),
        '""',
      );
      expect(
        executableSource,
        isNot(
          matches(
            RegExp(
              r'(^|[\s=(,])(?:host|model|tools|state|scheduler|ui|assets)\.',
              multiLine: true,
            ),
          ),
        ),
        reason: '$id must use only namespaced public tinest.* SDK calls.',
      );
    }
  });

  test('collaboration owns its model prompts as bundle assets', () async {
    final bundle = await const BuiltInPluginCatalog().load(
      'tinest.collaboration',
    );

    expect(
      bundle.assets.keys,
      containsAll(<String>[
        'prompts/common.md',
        'prompts/orchestrator.md',
        'prompts/subagent.md',
      ]),
    );
    final source = String.fromCharCodes(bundle.assets['main.lua']!);
    expect(source, contains('before_turn'));
    expect(source, contains('tinest.assets.read("prompts/orchestrator.md")'));
    expect(source, contains('tinest.assets.read("prompts/subagent.md")'));
  });

  test('edit tool owns its patch protocol instructions', () async {
    final bundle = await const BuiltInPluginCatalog().load('tinest.edit');

    expect(bundle.assets.keys, contains('prompts/apply_patch.md'));
    final source = String.fromCharCodes(bundle.assets['main.lua']!);
    expect(
      source,
      contains('description = tinest.assets.read("prompts/apply_patch.md")'),
    );
    final prompt = String.fromCharCodes(
      bundle.assets['prompts/apply_patch.md']!,
    );
    expect(prompt, contains('*** Begin Patch'));
    expect(prompt, contains('*** Update File:'));
  });

  test('standard driver owns optional host-policy prompt rendering', () async {
    final bundle = await const BuiltInPluginCatalog().load('tinest.standard');

    expect(
      bundle.assets.keys,
      containsAll(<String>[
        'prompts/permissions/readOnly.md',
        'prompts/permissions/ask.md',
        'prompts/permissions/workspaceWrite.md',
        'prompts/permissions/fullAccess.md',
      ]),
    );
    final source = String.fromCharCodes(bundle.assets['main.lua']!);
    expect(source, contains('host_policy = extension_data.host_policy'));
  });

  test(
    'embedded bytes exactly match the canonical package directories',
    () async {
      const catalog = BuiltInPluginCatalog();
      final daemonRoot = _daemonPackageRoot();
      for (final id in catalog.ids) {
        final bundle = await catalog.load(id);
        final source = Directory(
          p.join(daemonRoot.path, 'builtin_plugins', id),
        );
        final files =
            source
                .listSync(recursive: true, followLinks: false)
                .whereType<File>()
                .toList(growable: false)
              ..sort((left, right) => left.path.compareTo(right.path));
        final sourceAssets = <String, List<int>>{
          for (final file in files)
            p.posix.joinAll(p.split(p.relative(file.path, from: source.path))):
                file.readAsBytesSync(),
        };

        expect(bundle.assets.keys, sourceAssets.keys);
        for (final asset in bundle.assets.entries) {
          expect(
            asset.value,
            sourceAssets[asset.key],
            reason:
                '${asset.key} changed; run '
                '`dart run tool/generate_builtin_plugins.dart`.',
          );
        }
      }
    },
  );

  test(
    'product loader routes reserved IDs only to read-only built-ins',
    () async {
      final shadow = Directory(
        p.join(config.path, 'v5', 'plugins', 'tinest.files'),
      );
      await shadow.create(recursive: true);
      await File(p.join(shadow.path, 'PLUGIN.md')).writeAsString('malicious');
      await File(p.join(shadow.path, 'main.lua'))
          .writeAsString('error("owned")');
      final loader = NativePluginBundleLoader(config.path);

      final bundle = await loader.load('tinest.files');

      expect(bundle.descriptor.source, PluginSource.builtIn);
      expect(
        String.fromCharCodes(bundle.assets['main.lua']!),
        isNot(contains('owned')),
      );
      await expectLater(
        loader.load('tinest.unknown'),
        throwsA(isA<PluginBundleFormatException>()),
      );
    },
  );

  test(
    'source catalog and management combine built-in and user packages',
    () async {
      final user = Directory(p.join(config.path, 'v5', 'plugins', 'acme.echo'));
      await user.create(recursive: true);
      await File(p.join(user.path, 'PLUGIN.md')).writeAsString('''
---
api: 5
id: acme.echo
version: 1.0.0
name: Echo
entrypoint: main.lua
capabilities: []
---
''');
      await File(p.join(user.path, 'main.lua')).writeAsString('''
local tinest = require("tinest")
return tinest.plugin.define({tools = {}, hooks = {}, ui = {}})
''');
      final sources = NativePluginSourceCatalog(config.path);
      final loader = NativePluginBundleLoader(config.path);
      final service = PluginManagementService(
        sources: sources,
        revisions: PluginRevisionCatalog(
          loader: loader,
          cache: NativePluginRevisionCache(state.path),
        ),
        grants: MemoryAgentPluginGrantStore(),
        inspector: const _PassthroughInspector(),
      );

      expect(await sources.listPluginIds(), <String>[
        'acme.echo',
        ..._builtInIds,
      ]);
      expect((await service.list()).map((plugin) => plugin.id), <String>[
        'acme.echo',
        ..._builtInIds,
      ]);
      expect((await service.get('tinest.plan')).source, PluginSource.builtIn);
    },
  );

  test(
    'fork copies only the validated revision and rewrites its identity',
    () async {
      final sources = NativePluginSourceCatalog(config.path);
      final grants = MemoryAgentPluginGrantStore();
      final service = PluginManagementService(
        sources: sources,
        revisions: PluginRevisionCatalog(
          loader: NativePluginBundleLoader(config.path),
          cache: NativePluginRevisionCache(state.path),
        ),
        grants: grants,
        inspector: const _PassthroughInspector(),
      );
      final validated = await service.validate('tinest.files');

      final forked = await service.fork(
        sourceId: 'tinest.files',
        id: 'acme.files',
        name: 'Acme files',
      );

      expect(forked.id, 'acme.files');
      expect(forked.name, 'Acme files');
      expect(forked.source, PluginSource.user);
      expect(forked.requestedCapabilities, validated.requestedCapabilities);
      expect(await grants.list('tinest'), isEmpty);
      final directory = Directory(
        p.join(config.path, 'v5', 'plugins', 'acme.files'),
      );
      expect(
        directory
            .listSync(recursive: true)
            .whereType<File>()
            .map((file) => p.relative(file.path, from: directory.path)),
        everyElement(anyOf(endsWith('.lua'), endsWith('.md'))),
      );
      final manifest = await File(p.join(directory.path, 'PLUGIN.md'))
          .readAsString();
      expect(manifest, contains('id: acme.files'));
      expect(manifest, contains('name: Acme files'));
      expect(manifest, isNot(contains('id: tinest.files')));
      final entrypoint = await File(p.join(directory.path, 'main.lua'))
          .readAsString();
      expect(entrypoint, contains('ui = tool_card'));
      expect(entrypoint, isNot(contains('tinest.files/tool')));
    },
    tags: const <String>[
      'feature_test__plugin_management__unit',
      'feature_test__plugin_management__verticalSlice',
    ],
  );

  test(
    'app-data source watcher reports external Lua and Markdown edits',
    () async {
      final user = Directory(p.join(config.path, 'v5', 'plugins', 'acme.echo'));
      await user.create(recursive: true);
      final sources = NativePluginSourceCatalog(config.path);
      await sources.initialize();
      addTearDown(sources.close);
      final changed = sources.changes.first.timeout(const Duration(seconds: 5));

      await File(p.join(user.path, 'main.lua')).writeAsString('return {}');

      await expectLater(changed, completes);
    },
  );

  test(
    'app-data source watcher reports edits in existing nested source dirs',
    () async {
      final user = Directory(p.join(config.path, 'v5', 'plugins', 'acme.echo'));
      final lua = File(p.join(user.path, 'lua', 'helpers', 'echo.lua'));
      final markdown = File(p.join(user.path, 'prompts', 'system.md'));
      await lua.parent.create(recursive: true);
      await markdown.parent.create(recursive: true);
      await lua.writeAsString('return {}');
      await markdown.writeAsString('# System');
      final sources = NativePluginSourceCatalog(config.path);
      await sources.initialize();
      addTearDown(sources.close);

      final luaChanged = sources.changes.first.timeout(
        const Duration(seconds: 5),
      );
      await lua.writeAsString('return {updated = true}', flush: true);
      await expectLater(luaChanged, completes);

      final markdownChanged = sources.changes.first.timeout(
        const Duration(seconds: 5),
      );
      await markdown.writeAsString('# Updated system', flush: true);
      await expectLater(markdownChanged, completes);
    },
  );

  test(
    'app-data source watcher follows nested directory replacement and edits',
    () async {
      final user = Directory(p.join(config.path, 'v5', 'plugins', 'acme.echo'));
      await user.create(recursive: true);
      final sources = NativePluginSourceCatalog(config.path);
      await sources.initialize();
      addTearDown(sources.close);

      final nested = Directory(p.join(user.path, 'lua', 'generated'));
      var changed = sources.changes.first.timeout(const Duration(seconds: 5));
      await nested.create(recursive: true);
      await expectLater(changed, completes);

      changed = sources.changes.first.timeout(const Duration(seconds: 5));
      await nested.delete(recursive: true);
      await expectLater(changed, completes);

      changed = sources.changes.first.timeout(const Duration(seconds: 5));
      await nested.create(recursive: true);
      await expectLater(changed, completes);

      changed = sources.changes.first.timeout(const Duration(seconds: 5));
      await File(p.join(nested.path, 'tool.lua'))
          .writeAsString('return {}', flush: true);
      await expectLater(changed, completes);
    },
  );

  test(
    'app-data source watcher reports namespaced plugin directory creation',
    () async {
      final sources = NativePluginSourceCatalog(config.path);
      await sources.initialize();
      addTearDown(sources.close);
      final changed = sources.changes.first.timeout(const Duration(seconds: 5));

      await Directory(p.join(config.path, 'v5', 'plugins', 'acme.echo'))
          .create();

      await expectLater(changed, completes);
    },
  );

  test('listing revalidates user source and reports LKG diagnostics', () async {
    final user = Directory(p.join(config.path, 'v5', 'plugins', 'acme.echo'));
    await user.create(recursive: true);
    await File(p.join(user.path, 'PLUGIN.md')).writeAsString('''
---
api: 5
id: acme.echo
version: 1.0.0
name: Echo
entrypoint: main.lua
capabilities: []
---
''');
    await File(p.join(user.path, 'main.lua')).writeAsString('''
local tinest = require("tinest")
return tinest.plugin.define({tools = {}})
''');
    final service = PluginManagementService(
      sources: NativePluginSourceCatalog(config.path),
      revisions: PluginRevisionCatalog(
        loader: NativePluginBundleLoader(config.path),
        cache: NativePluginRevisionCache(state.path),
      ),
      grants: MemoryAgentPluginGrantStore(),
      inspector: const _PassthroughInspector(),
    );
    final valid = await service.validate('acme.echo');
    await File(p.join(user.path, 'native.dll')).writeAsBytes(<int>[0]);

    final listed = (await service.list()).singleWhere(
      (plugin) => plugin.id == 'acme.echo',
    );

    expect(listed.revision?.contentHash, valid.revision?.contentHash);
    expect(listed.isStale, isTrue);
    expect(listed.diagnostics, isNotEmpty);
  });

  test('validates and reloads a built-in using Agent grants', () async {
    final loader = NativePluginBundleLoader(config.path);
    final grants = MemoryAgentPluginGrantStore();
    final service = PluginManagementService(
      sources: NativePluginSourceCatalog(config.path),
      revisions: PluginRevisionCatalog(
        loader: loader,
        cache: NativePluginRevisionCache(state.path),
      ),
      grants: grants,
      inspector: const _PassthroughInspector(),
    );
    final validated = await service.validate('tinest.files');
    for (final capability in validated.requestedCapabilities) {
      await grants.grant(
        AgentPluginGrantDto(
          agentId: 'agent-a',
          pluginId: 'tinest.files',
          capability: capability,
        ),
      );
    }

    final activated = await service.reload('tinest.files', 'agent-a');

    expect(activated.source, PluginSource.builtIn);
    expect(
      (await service.revisions.resolveForAgent(
        'agent-a',
        'tinest.files',
      )).revision.contentHash,
      activated.revision!.contentHash,
    );
  });
}

final class _PassthroughInspector implements PluginBundleInspector {
  const new();

  @override
  Future<PluginDescriptorDto> inspect(PluginBundle bundle) async =>
      bundle.descriptor;
}

Directory _daemonPackageRoot() {
  var directory = Directory.current.absolute;
  while (true) {
    if (File(p.join(directory.path, 'pubspec.yaml')).existsSync() &&
        Directory(p.join(directory.path, 'builtin_plugins')).existsSync()) {
      return directory;
    }
    final nested = Directory(p.join(directory.path, 'packages', 'daemon'));
    if (File(p.join(nested.path, 'pubspec.yaml')).existsSync() &&
        Directory(p.join(nested.path, 'builtin_plugins')).existsSync()) {
      return nested;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('Daemon package root not found.');
    }
    directory = parent;
  }
}
