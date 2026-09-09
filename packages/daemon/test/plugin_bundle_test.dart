import 'dart:io';

import 'package:daemon/src/features/plugins/infrastructure/memory_plugin_stores.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_bundles.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_service.dart';
import 'package:path/path.dart' as p;
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  late Directory config;
  late Directory state;

  setUp(() async {
    config = await Directory.systemTemp.createTemp('tinest-v5-config-');
    state = await Directory.systemTemp.createTemp('tinest-v5-state-');
  });

  tearDown(() async {
    await config.delete(recursive: true);
    await state.delete(recursive: true);
  });

  Future<Directory> writePlugin({
    String directoryId = 'acme.reader',
    String manifestId = 'acme.reader',
    String capabilities = '  - workspace.read',
  }) async {
    final directory = Directory(
      p.join(config.path, 'v5', 'plugins', directoryId),
    );
    await directory.create(recursive: true);
    await File(p.join(directory.path, 'PLUGIN.md')).writeAsString('''
---
api: 5
id: $manifestId
version: 1.0.0
name: Reader
entrypoint: main.lua
capabilities:
$capabilities
---

Reader documentation.
''');
    await File(p.join(directory.path, 'main.lua'))
        .writeAsString('return tinest.plugin.define({})\n');
    await Directory(p.join(directory.path, 'prompts')).create();
    await File(p.join(directory.path, 'prompts', 'read.md'))
        .writeAsString('Read carefully.\n');
    return directory;
  }

  test(
    'loads only app-data Lua and Markdown into a deterministic revision',
    () async {
      await writePlugin();
      final loader = NativePluginBundleLoader(config.path);

      final first = await loader.load('acme.reader');
      final second = await loader.load('acme.reader');

      expect(first.descriptor.source, PluginSource.user);
      expect(first.descriptor.id, 'acme.reader');
      expect(first.revision.contentHash, hasLength(64));
      expect(second.revision.contentHash, first.revision.contentHash);
      expect(first.assets.keys, <String>[
        'PLUGIN.md',
        'main.lua',
        'prompts/read.md',
      ]);
    },
    tags: const <String>['feature_test__plugin_runtime__unit'],
  );

  test(
    'ignores the root LuaLS sidecar when hashing executable assets',
    () async {
      final source = await writePlugin();
      final loader = NativePluginBundleLoader(config.path);
      final before = await loader.load('acme.reader');

      await File(p.join(source.path, '.luarc.json')).writeAsString('''
{"runtime.version":"Lua 5.5","workspace.library":["sdk/library"]}
''');
      final after = await loader.load('acme.reader');

      expect(after.revision.contentHash, before.revision.contentHash);
      expect(after.assets, isNot(contains('.luarc.json')));
    },
    tags: const <String>['feature_test__plugin_authoring__unit'],
  );

  test(
    'rejects reserved IDs, case mismatch, foreign files, and links',
    () async {
      final reserved = await writePlugin(
        directoryId: 'tinest.evil',
        manifestId: 'tinest.evil',
      );
      await expectLater(
        NativePluginBundleLoader(config.path).load('tinest.evil'),
        throwsA(isA<PluginBundleFormatException>()),
      );
      await reserved.delete(recursive: true);

      await writePlugin(directoryId: 'Acme.Reader');
      await expectLater(
        NativePluginBundleLoader(config.path).load('acme.reader'),
        throwsA(isA<PluginBundleFormatException>()),
      );

      await Directory(p.join(config.path, 'v5', 'plugins', 'Acme.Reader'))
          .delete(recursive: true);
      final plugin = await writePlugin();
      await File(p.join(plugin.path, 'native.dll')).writeAsBytes(<int>[0]);
      await expectLater(
        NativePluginBundleLoader(config.path).load('acme.reader'),
        throwsA(isA<PluginBundleFormatException>()),
      );
      await File(p.join(plugin.path, 'native.dll')).delete();

      final outside = File(p.join(config.path, 'outside.lua'));
      await outside.writeAsString('return {}');
      final link = Link(p.join(plugin.path, 'lua', 'escape.lua'));
      await link.parent.create(recursive: true);
      try {
        await link.create(outside.path);
      } on FileSystemException {
        // Windows developer mode may not permit symlink creation. The loader's
        // link branch is covered on CI hosts that permit it.
        return;
      }
      await expectLater(
        NativePluginBundleLoader(config.path).load('acme.reader'),
        throwsA(isA<PluginBundleFormatException>()),
      );
    },
  );

  test('rejects unsupported API major and entrypoint traversal', () async {
    final plugin = await writePlugin();
    final manifest = File(p.join(plugin.path, 'PLUGIN.md'));
    final source = await manifest.readAsString();

    await manifest.writeAsString(source.replaceFirst('api: 5', 'api: 6'));
    await expectLater(
      NativePluginBundleLoader(config.path).load('acme.reader'),
      throwsA(
        isA<PluginBundleFormatException>().having(
          (error) => error.message,
          'message',
          contains('Unsupported plugin API major'),
        ),
      ),
    );

    await manifest.writeAsString(
      source.replaceFirst('entrypoint: main.lua', 'entrypoint: ../main.lua'),
    );
    await expectLater(
      NativePluginBundleLoader(config.path).load('acme.reader'),
      throwsA(
        isA<PluginBundleFormatException>().having(
          (error) => error.message,
          'message',
          contains('normalized relative Lua path'),
        ),
      ),
    );
  });

  test(
    'LKG cache survives invalid source and gates capability expansion',
    () async {
      final source = await writePlugin();
      final catalog = PluginRevisionCatalog(
        loader: NativePluginBundleLoader(config.path),
        cache: NativePluginRevisionCache(state.path),
      );

      final initial = await catalog.reload(
        'acme.reader',
        agentId: 'agent-a',
        approvedCapabilities: const <String>{'workspace.read'},
      );
      expect(initial.isStale, isFalse);
      await catalog.reload(
        'acme.reader',
        agentId: 'agent-b',
        approvedCapabilities: const <String>{'workspace.read'},
      );

      await File(p.join(source.path, 'main.lua')).writeAsString('changed\n');
      await File(p.join(source.path, 'PLUGIN.md')).writeAsString(
        (await File(
          p.join(source.path, 'PLUGIN.md'),
        ).readAsString()).replaceFirst(
          '  - workspace.read',
          '  - workspace.read\n  - network.http',
        ),
      );
      final held = await catalog.reload(
        'acme.reader',
        agentId: 'agent-b',
        approvedCapabilities: const <String>{'workspace.read'},
      );
      expect(held.revision!.contentHash, initial.revision!.contentHash);
      expect(held.isStale, isTrue);
      expect(
        held.diagnostics.map((item) => item.code),
        contains('capability_expanded'),
      );
      final activatedForA = await catalog.reload(
        'acme.reader',
        agentId: 'agent-a',
        approvedCapabilities: const <String>{'workspace.read', 'network.http'},
      );
      expect(
        activatedForA.revision!.contentHash,
        isNot(initial.revision!.contentHash),
      );
      expect(
        (await catalog.resolveForAgent(
          'agent-b',
          'acme.reader',
        )).revision.contentHash,
        initial.revision!.contentHash,
      );

      await File(p.join(source.path, 'main.lua')).delete();
      final invalid = await catalog.reload(
        'acme.reader',
        agentId: 'agent-a',
        approvedCapabilities: const <String>{'workspace.read', 'network.http'},
      );
      expect(
        invalid.revision!.contentHash,
        activatedForA.revision!.contentHash,
      );
      expect(
        invalid.diagnostics.map((item) => item.code),
        contains('invalid_plugin_bundle'),
      );

      final restarted = PluginRevisionCatalog(
        loader: NativePluginBundleLoader(config.path),
        cache: NativePluginRevisionCache(state.path),
      );
      expect(
        (await restarted.resolveForAgent(
          'agent-a',
          'acme.reader',
        )).revision.contentHash,
        activatedForA.revision!.contentHash,
      );
      expect(
        (await restarted.resolveForAgent(
          'agent-b',
          'acme.reader',
        )).revision.contentHash,
        initial.revision!.contentHash,
      );
    },
    tags: const <String>['feature_test__plugin_runtime__unit'],
  );

  test(
    'revision cache resolves an exact execution hash after reload and restart',
    () async {
      final source = await writePlugin();
      final cache = NativePluginRevisionCache(state.path);
      final firstCatalog = PluginRevisionCatalog(
        loader: NativePluginBundleLoader(config.path),
        cache: cache,
      );
      final first = await firstCatalog.reload(
        'acme.reader',
        agentId: 'agent-a',
        approvedCapabilities: const <String>{'workspace.read'},
      );
      final firstRevision = first.revision!;

      await File(p.join(source.path, 'main.lua'))
          .writeAsString('return require("tinest").plugin.define({})\n');
      final second = await firstCatalog.reload(
        'acme.reader',
        agentId: 'agent-a',
        approvedCapabilities: const <String>{'workspace.read'},
      );
      final secondRevision = second.revision!;
      expect(
        secondRevision.executionRevisionHash,
        isNot(firstRevision.executionRevisionHash),
      );

      final restarted = PluginRevisionCatalog(
        loader: NativePluginBundleLoader(config.path),
        cache: NativePluginRevisionCache(state.path),
      );
      expect(
        (await restarted.resolveExecutionRevision(
          'acme.reader',
          firstRevision.executionRevisionHash,
        )).revision.contentHash,
        firstRevision.contentHash,
      );
      expect(
        (await restarted.resolveExecutionRevision(
          'acme.reader',
          secondRevision.executionRevisionHash,
        )).revision.contentHash,
        secondRevision.contentHash,
      );
      await expectLater(
        restarted.resolveExecutionRevision('acme.reader', 'f' * 64),
        throwsA(
          isA<PluginRevisionUnavailable>().having(
            (error) => error.message,
            'message',
            contains('exact execution revision'),
          ),
        ),
      );
    },
    tags: const <String>['feature_test__plugin_runtime__unit'],
  );

  test(
    'cached Agent pins rebuild executable contributions after restart',
    () async {
      await writePlugin();
      final grants = MemoryAgentPluginGrantStore();
      await grants.grant(
        const AgentPluginGrantDto(
          agentId: 'agent-a',
          pluginId: 'acme.reader',
          capability: 'workspace.read',
        ),
      );
      final first = PluginManagementService(
        sources: NativePluginSourceCatalog(config.path),
        revisions: PluginRevisionCatalog(
          loader: NativePluginBundleLoader(config.path),
          cache: NativePluginRevisionCache(state.path),
        ),
        grants: grants,
        inspector: const _UiContributionInspector(),
      );
      await first.reload('acme.reader', 'agent-a');

      final restarted = PluginManagementService(
        sources: NativePluginSourceCatalog(config.path),
        revisions: PluginRevisionCatalog(
          loader: NativePluginBundleLoader(config.path),
          cache: NativePluginRevisionCache(state.path),
        ),
        grants: grants,
        inspector: const _UiContributionInspector(),
      );
      final restored = await restarted.getForAgent('agent-a', 'acme.reader');

      expect(
        restored.contributions.map((contribution) => contribution.id),
        const <String>['acme.reader/status'],
      );
    },
    tags: const <String>['feature_test__plugin_runtime__unit'],
  );

  test(
    'installed LKG descriptors rebuild contributions for management listing',
    () async {
      final first = PluginManagementService(
        sources: NativePluginSourceCatalog(config.path),
        revisions: PluginRevisionCatalog(
          loader: NativePluginBundleLoader(config.path),
          cache: NativePluginRevisionCache(state.path),
        ),
        grants: MemoryAgentPluginGrantStore(),
        inspector: const _UiContributionInspector(),
      );
      await first.validate('tinest.standard');

      final restarted = PluginManagementService(
        sources: NativePluginSourceCatalog(config.path),
        revisions: PluginRevisionCatalog(
          loader: NativePluginBundleLoader(config.path),
          cache: NativePluginRevisionCache(state.path),
        ),
        grants: MemoryAgentPluginGrantStore(),
        inspector: const _UiContributionInspector(),
      );
      final listed = (await restarted.list()).singleWhere(
        (plugin) => plugin.id == 'tinest.standard',
      );

      expect(
        listed.contributions.map((contribution) => contribution.id),
        const <String>['tinest.standard/status'],
      );
      expect(
        (await restarted.get('tinest.standard')).contributions,
        isNotEmpty,
      );
    },
    tags: const <String>['feature_test__plugin_management__unit'],
  );

  test(
    'concurrent stores of one revision never lose the cached bundle',
    () async {
      final cache = NativePluginRevisionCache(state.path);
      await writePlugin();
      final bundle = await NativePluginBundleLoader(config.path)
          .load('acme.reader');
      final contentHash = bundle.revision.contentHash;
      final executionHash = bundle.revision.executionRevisionHash;

      // A turn activating a plugin for several Agents while an install
      // refresh stores the same revision must not race the staged rename:
      // the temporary path used to depend only on the content hash and
      // process ID, so same-process writers collided and one rename died
      // with PathNotFoundException.
      await Future.wait(<Future<void>>[
        for (var writer = 0; writer < 4; writer += 1) ...<Future<void>>[
          cache.storeInstalled(bundle),
          cache.activateForAgent('agent-$writer', bundle),
        ],
      ]);

      final installed = await cache.loadInstalled('acme.reader');
      expect(installed, isNotNull);
      expect(installed!.revision.contentHash, contentHash);
      expect(
        (await cache.loadExecutionRevision(
          'acme.reader',
          executionHash,
        ))!.assets.keys,
        containsAll(<String>['PLUGIN.md', 'main.lua']),
      );
      for (var writer = 0; writer < 4; writer += 1) {
        expect(
          await cache.loadForAgent('agent-$writer', 'acme.reader'),
          isNotNull,
        );
      }
    },
    tags: const <String>['feature_test__plugin_management__unit'],
  );
}

final class _UiContributionInspector implements PluginBundleInspector {
  const new();

  @override
  Future<PluginDescriptorDto> inspect(PluginBundle bundle) async =>
      bundle.descriptor.copyWith(
        contributions: <PluginContributionDto>[
          PluginContributionDto(
            pluginId: bundle.descriptor.id,
            id: '${bundle.descriptor.id}/status',
            kind: PluginContributionKind.ui,
            metadata: const <String, dynamic>{
              'slots': <String>['conversationStatus'],
            },
          ),
        ],
      );
}
