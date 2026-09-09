@Tags(<String>[
  'feature_test__plugin_runtime__unit',
  'feature_test__plugin_permissions__verticalSlice',
])
@Timeout(Duration(minutes: 2))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:daemon/src/features/plugins/infrastructure/builtin_plugin_assets.g.dart';
import 'package:daemon/src/features/plugins/infrastructure/memory_plugin_stores.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_bundles.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_service.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_runtime.dart';
import 'package:lua_tool_runtime/lua_tool_runtime.dart' as lua;
import 'package:path/path.dart' as p;
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'support/temporary_directory.dart';

void main() {
  late _MemoryRevisionCache cache;
  late PluginRevisionCatalog revisions;
  late PluginRuntime<Object> runtime;
  late PluginRuntimeSession<Object> session;
  late Directory stagedHost;
  late Directory buildDirectory;

  setUpAll(() async {
    final prebuilt = Platform.environment['TINEST_PLUGIN_TEST_LUA_HOST'];
    if (prebuilt != null && prebuilt.isNotEmpty) {
      stagedHost = Directory(prebuilt);
      buildDirectory = Directory('');
    } else {
      stagedHost = await Directory.systemTemp.createTemp(
        'tinest-plugin-runtime-host-',
      );
      buildDirectory = await Directory.systemTemp.createTemp(
        'tinest-plugin-runtime-build-',
      );
      await lua.stageLuaToolRuntime(
        destination: stagedHost.path,
        buildMode: lua.LuaBuildMode.debug,
        buildDirectory: buildDirectory.path,
        cmakeExecutable: await _cmakeExecutable(),
      );
    }
  });

  tearDownAll(() async {
    if (Platform.environment['TINEST_PLUGIN_TEST_LUA_HOST'] == null) {
      await deleteTemporaryDirectory(stagedHost);
      await deleteTemporaryDirectory(buildDirectory);
    }
  });

  setUp(() async {
    cache = _MemoryRevisionCache();
    revisions = PluginRevisionCatalog(
      loader: _BundleLoader(_validBundle()),
      cache: cache,
    );
    await revisions.reload(
      'acme.reader',
      agentId: 'agent-1',
      approvedCapabilities: const <String>{'model.call', 'tools.invoke'},
    );
    runtime = PluginRuntime<Object>(
      luaRuntime: lua.LuaToolRuntime<Object>(
        host: lua.LuaHostCommand.fromDirectory(stagedHost.path),
        processLauncher: const lua.IoLuaHostProcessLauncher(),
        clock: const lua.SystemLuaClock(),
        ids: _Ids(),
      ),
      revisions: revisions,
    );
    session = runtime.openSession(
      agentId: 'agent-1',
      sessionId: 'session-1',
      workspaceId: 'workspace-1',
      allowedCapabilitiesByPlugin: const <String, Set<String>>{
        'acme.reader': <String>{'model.call', 'tools.invoke'},
      },
    );
  });

  tearDown(() => runtime.close());

  test('registers an effect-free typed contribution spec', () async {
    final router = _RecordingRouter();

    final registration = await session.register(
      pluginId: 'acme.reader',
      callbackRouter: router,
    );

    expect(router.calls, isEmpty);
    expect(registration.revisionHash, 'execution-revision-1');
    expect(registration.driver?.id, 'acme.reader/driver');
    expect(registration.driver?.binding.internalKey, '__tinest.driver.driver');
    expect(registration.tools.single.id, 'acme.reader/read');
    final toolContribution = registration.descriptor.contributions.singleWhere(
      (value) => value.kind == PluginContributionKind.tool,
    );
    expect(toolContribution.metadata, <String, dynamic>{
      'bindingId': 'read',
      'declaredOperations': <String>['tools.invoke'],
    });
    expect(registration.tools.single.declaredOperations, const <String>{
      'tools.invoke',
    });
    expect(registration.driver?.declaredOperations, const <String>{
      'model.open',
    });
    expect(registration.hooks.single.declaredOperations, const <String>{
      'tools.invoke',
    });
    expect(
      registration.sessionControls.single.declaredOperations,
      const <String>{'tools.invoke'},
    );
    expect(registration.ui.single.declaredOperations, const <String>{
      'tools.invoke',
    });
    expect(toolContribution.tool?.originPluginId, 'acme.reader');
    expect(toolContribution.tool?.contributionId, 'read');
    expect(toolContribution.tool?.kind, AgentToolKind.function);
    expect(toolContribution.tool?.inputSchema['type'], 'object');
    expect(toolContribution.tool?.effects, <String>['filesystem.read']);
    expect(toolContribution.tool?.presentation['group'], 'filesystem');
    expect(registration.hooks.single.lifecycle, PluginLifecycle.beforeTurn);
    expect(registration.sessionControls.single.id, 'acme.reader/mode');
    expect(registration.ui.single.slot, PluginUiSlot.conversationStatus);
    expect(registration.ui.single.inputSchema, isEmpty);
    // A surface that reads live host state declares it, so the host knows to
    // render it again when that state changes instead of leaving a stale
    // panel up until the next turn boundary.
    expect(registration.ui.single.dependsOn, const <String>{'session_tree'});
    expect(
      registration.descriptor.contributions
          .firstWhere((value) => value.id == 'acme.reader/status')
          .metadata['dependsOn'],
      <String>['session_tree'],
    );
    expect(
      registration.descriptor.contributions.map((value) => value.id),
      containsAll(<String>[
        'acme.reader/driver',
        'acme.reader/read',
        'acme.reader/before-turn',
        'acme.reader/mode',
        'acme.reader/status',
      ]),
    );

    final again = await session.register(
      pluginId: 'acme.reader',
      callbackRouter: router,
    );
    expect(identical(again, registration), isTrue);
  });

  test('scaffold template validates through the real Lua inspector', () async {
    final root = await Directory.systemTemp.createTemp(
      'tinest-plugin-scaffold-',
    );
    addTearDown(() => root.delete(recursive: true));
    final catalog = PluginRevisionCatalog(
      loader: NativePluginBundleLoader(root.path),
      cache: NativePluginRevisionCache(root.path),
    );
    final scaffoldRuntime = PluginRuntime<Object>(
      luaRuntime: lua.LuaToolRuntime<Object>(
        host: lua.LuaHostCommand.fromDirectory(stagedHost.path),
        processLauncher: const lua.IoLuaHostProcessLauncher(),
        clock: const lua.SystemLuaClock(),
        ids: _Ids(),
      ),
      revisions: catalog,
    );
    addTearDown(scaffoldRuntime.close);
    final service = PluginManagementService(
      sources: NativePluginSourceCatalog(root.path),
      revisions: catalog,
      grants: MemoryAgentPluginGrantStore(),
      inspector: scaffoldRuntime,
    );

    final descriptor = await service.scaffold('acme.scaffold', 'Scaffold');

    expect(descriptor.id, 'acme.scaffold');
    expect(descriptor.diagnostics, isEmpty);
    expect(
      File(p.join(root.path, 'v5', 'plugins', 'acme.scaffold', 'main.lua'))
          .existsSync(),
      isTrue,
    );
  });

  test(
    'all embedded built-ins register complete public contributions',
    () async {
      const builtIns = BuiltInPluginCatalog();
      final builtInCache = _MemoryRevisionCache();
      final builtInRevisions = PluginRevisionCatalog(
        loader: builtIns,
        cache: builtInCache,
      );
      for (final id in builtIns.ids) {
        final bundle = await builtIns.load(id);
        await builtInRevisions.reload(
          id,
          agentId: 'builtin-agent',
          approvedCapabilities: bundle.descriptor.requestedCapabilities.toSet(),
        );
      }
      final builtInRuntime = PluginRuntime<Object>(
        luaRuntime: lua.LuaToolRuntime<Object>(
          host: lua.LuaHostCommand.fromDirectory(stagedHost.path),
          processLauncher: const lua.IoLuaHostProcessLauncher(),
          clock: const lua.SystemLuaClock(),
          ids: _Ids(),
        ),
        revisions: builtInRevisions,
      );
      addTearDown(builtInRuntime.close);
      final builtInSession = builtInRuntime.openSession(
        agentId: 'builtin-agent',
        sessionId: 'builtin-session',
        allowedCapabilitiesByPlugin: const <String, Set<String>>{
          'tinest.standard': <String>{
            'model.call',
            'tools.list',
            'tools.invoke',
          },
          'tinest.files': <String>{'workspace.read'},
          'tinest.plan': <String>{'state.read', 'state.write', 'ui.publish'},
          'tinest.goal': <String>{
            'state.read',
            'state.write',
            'scheduler.manage',
            'ui.publish',
          },
          'tinest.edit': <String>{'workspace.read', 'workspace.patch'},
          'tinest.terminal': <String>{'process.execute', 'process.write'},
          'tinest.attachments': <String>{
            'workspace.read',
            'attachment.publish',
            'attachment.read',
          },
          'tinest.interaction': <String>{'interaction.request'},
          'tinest.time': <String>{'clock.read', 'clock.sleep'},
          'tinest.context': <String>{'state.read', 'state.write'},
          'tinest.skills': <String>{'workspace.read'},
          'tinest.mcp': <String>{'mcp.read', 'mcp.invoke'},
          'tinest.collaboration': <String>{
            'collaboration.spawn',
            'collaboration.message',
            'collaboration.wait',
            'collaboration.interrupt',
            'collaboration.list',
            'ui.publish',
          },
          'tinest.discovery': <String>{'tools.list'},
          'tinest.lua-code': <String>{
            'model.call',
            'tools.list',
            'tools.invoke',
            'process.execute',
          },
        },
      );

      final registrations = <String, PluginRegistration>{};
      for (final id in builtIns.ids) {
        registrations[id] = await builtInSession.register(
          pluginId: id,
          callbackRouter: _RecordingRouter(),
        );
      }

      expect(
        registrations['tinest.standard']!.driver!.id,
        'tinest.standard/driver',
      );
      expect(
        registrations['tinest.files']!.tools.map((tool) => tool.id),
        <String>[
          'tinest.files/list_directory',
          'tinest.files/read_file',
          'tinest.files/search_text',
          'tinest.files/glob',
          'tinest.files/view_image',
        ],
      );
      expect(registrations['tinest.plan']!.tools, hasLength(1));
      expect(registrations['tinest.plan']!.hooks, hasLength(2));
      expect(registrations['tinest.plan']!.sessionControls, hasLength(1));
      expect(registrations['tinest.plan']!.ui, hasLength(1));
      expect(registrations['tinest.goal']!.tools, hasLength(3));
      expect(registrations['tinest.goal']!.hooks, hasLength(5));
      expect(
        registrations['tinest.goal']!.ui.map((contribution) => contribution.id),
        <String>[
          'tinest.goal/goal_tool',
          'tinest.goal/goal_status',
          'tinest.goal/goal_timeline',
          'tinest.goal/goal_dialog',
        ],
      );
      final toolIds = <String, List<String>>{
        for (final entry in registrations.entries)
          entry.key: entry.value.tools.map((tool) => tool.id).toList(),
      };
      final modelNames = <String, List<String>>{
        for (final entry in registrations.entries)
          entry.key: entry.value.tools.map((tool) => tool.name).toList(),
      };
      expect(toolIds['tinest.edit'], <String>['tinest.edit/apply_patch']);
      expect(toolIds['tinest.terminal'], <String>[
        'tinest.terminal/exec_command',
        'tinest.terminal/write_stdin',
      ]);
      expect(toolIds['tinest.attachments'], <String>[
        'tinest.attachments/attach_file',
        'tinest.attachments/read_attachment',
      ]);
      expect(toolIds['tinest.interaction'], <String>[
        'tinest.interaction/request_user_input',
      ]);
      expect(toolIds['tinest.time'], <String>[
        'tinest.time/current_time',
        'tinest.time/sleep',
      ]);
      expect(toolIds['tinest.context'], <String>[
        'tinest.context/get_context_remaining',
        'tinest.context/new_context',
        'tinest.context/compact_context',
      ]);
      expect(toolIds['tinest.skills'], <String>[
        'tinest.skills/list_skills',
        'tinest.skills/skill',
        'tinest.skills/list',
        'tinest.skills/read',
      ]);
      expect(toolIds['tinest.mcp'], <String>[
        'tinest.mcp/list_resources',
        'tinest.mcp/list_resource_templates',
        'tinest.mcp/read_resource',
        'tinest.mcp/tool_search',
      ]);
      expect(
        registrations['tinest.mcp']!.templates.map((template) => template.id),
        <String>['tinest.mcp/tool_bridge'],
      );
      expect(
        registrations['tinest.mcp']!.descriptor.contributions.map(
          (contribution) => contribution.id,
        ),
        isNot(contains('tinest.mcp/tool_bridge')),
      );
      expect(toolIds['tinest.collaboration'], <String>[
        'tinest.collaboration/spawn_agent',
        'tinest.collaboration/send_message',
        'tinest.collaboration/followup_task',
        'tinest.collaboration/wait_agent',
        'tinest.collaboration/interrupt_agent',
        'tinest.collaboration/list_agents',
      ]);
      expect(
        registrations['tinest.collaboration']!.ui.map(
          (contribution) => contribution.id,
        ),
        <String>[
          'tinest.collaboration/tool',
          'tinest.collaboration/agent_status',
        ],
      );
      expect(toolIds['tinest.discovery'], <String>[
        'tinest.discovery/tool_search',
      ]);
      expect(
        registrations['tinest.lua-code']!.driver!.id,
        'tinest.lua-code/driver',
      );
      expect(toolIds['tinest.lua-code'], <String>[
        'tinest.lua-code/exec',
        'tinest.lua-code/wait',
      ]);
      expect(modelNames, const <String, List<String>>{
        'tinest.attachments': <String>['attach_file', 'read_attachment'],
        'tinest.collaboration': <String>[
          'spawn_agent',
          'send_message',
          'followup_task',
          'wait_agent',
          'interrupt_agent',
          'list_agents',
        ],
        'tinest.context': <String>[
          'get_context_remaining',
          'new_context',
          'compact_context',
        ],
        'tinest.discovery': <String>['tool_search'],
        'tinest.edit': <String>['apply_patch'],
        'tinest.files': <String>[
          'list_directory',
          'read_file',
          'search_text',
          'glob',
          'view_image',
        ],
        'tinest.goal': <String>['create_goal', 'get_goal', 'update_goal'],
        'tinest.interaction': <String>['request_user_input'],
        'tinest.lua-code': <String>['exec', 'wait'],
        'tinest.mcp': <String>[
          'list_mcp_resources',
          'list_mcp_resource_templates',
          'read_mcp_resource',
          'tool_search_mcp',
        ],
        'tinest.plan': <String>['update_plan'],
        'tinest.skills': <String>[
          'list_skills',
          'skill',
          'skills__list',
          'skills__read',
        ],
        'tinest.standard': <String>[],
        'tinest.terminal': <String>['exec_command', 'write_stdin'],
        'tinest.time': <String>['clock__curr_time', 'clock__sleep'],
      });
      for (final registration in registrations.values) {
        expect(registration.descriptor.contributions, isNotEmpty);
      }
      expect(
        builtInPluginAssetsBase64.values
            .expand((assets) => assets.values)
            .map((source) => utf8.decode(base64Decode(source)))
            .join('\n'),
        isNot(contains('runtime_host.')),
        reason:
            'built-ins must use only the same public tinest.* SDK available '
            'to app-data plugins',
      );
    },
    tags: const <String>[
      'feature_test__session_goal__unit',
      'feature_test__session_goal__contract',
      'feature_test__turn_question__unit',
      'feature_test__tool_clock__unit',
      'feature_test__tool_search__unit',
    ],
  );

  test(
    'management list and get expose runtime-defined built-in contributions',
    () async {
      const builtIns = BuiltInPluginCatalog();
      final catalog = PluginRevisionCatalog(
        loader: builtIns,
        cache: _MemoryRevisionCache(),
      );
      final managementRuntime = PluginRuntime<Object>(
        luaRuntime: lua.LuaToolRuntime<Object>(
          host: lua.LuaHostCommand.fromDirectory(stagedHost.path),
          processLauncher: const lua.IoLuaHostProcessLauncher(),
          clock: const lua.SystemLuaClock(),
          ids: _Ids(),
        ),
        revisions: catalog,
      );
      addTearDown(managementRuntime.close);
      final service = PluginManagementService(
        sources: const _SourceCatalog(<String>[
          'tinest.standard',
          'tinest.files',
          'tinest.plan',
        ]),
        revisions: catalog,
        grants: MemoryAgentPluginGrantStore(),
        inspector: managementRuntime,
      );

      final listed = await service.list();
      final kinds = listed
          .expand((plugin) => plugin.contributions)
          .map((contribution) => contribution.kind)
          .toSet();
      expect(
        kinds,
        containsAll(<PluginContributionKind>{
          PluginContributionKind.driver,
          PluginContributionKind.tool,
          PluginContributionKind.extension,
          PluginContributionKind.sessionControl,
          PluginContributionKind.ui,
        }),
      );
      final plan = await service.get('tinest.plan');
      expect(
        plan.contributions.map((contribution) => contribution.id),
        containsAll(<String>[
          'tinest.plan/update_plan',
          'tinest.plan/before-turn',
          'tinest.plan/mode',
          'tinest.plan/plan_card',
        ]),
      );
      final ui = plan.contributions.singleWhere(
        (contribution) => contribution.kind == PluginContributionKind.ui,
      );
      expect(ui.metadata['slots'], <String>['timeline']);
      expect(ui.metadata['bindingId'], 'plan_card');
    },
  );

  test(
    'invalid define reports a diagnostic and preserves the active LKG',
    () async {
      final loader = _MutableBundleLoader(_validBundle());
      final cache = _MemoryRevisionCache();
      final catalog = PluginRevisionCatalog(loader: loader, cache: cache);
      final managementRuntime = PluginRuntime<Object>(
        luaRuntime: lua.LuaToolRuntime<Object>(
          host: lua.LuaHostCommand.fromDirectory(stagedHost.path),
          processLauncher: const lua.IoLuaHostProcessLauncher(),
          clock: const lua.SystemLuaClock(),
          ids: _Ids(),
        ),
        revisions: catalog,
      );
      addTearDown(managementRuntime.close);
      final grants = MemoryAgentPluginGrantStore();
      final service = PluginManagementService(
        sources: const _SourceCatalog(<String>['acme.reader']),
        revisions: catalog,
        grants: grants,
        inspector: managementRuntime,
      );
      for (final capability
          in _validBundle().descriptor.requestedCapabilities) {
        await grants.grant(
          AgentPluginGrantDto(
            agentId: 'agent-1',
            pluginId: 'acme.reader',
            capability: capability,
          ),
        );
      }
      final active = await service.reload('acme.reader', 'agent-1');

      loader.bundle = _validBundle(
        revisionHash: 'revision-2',
        source: 'error("invalid define")',
      );
      final validation = await service.validate('acme.reader');
      expect(validation.isStale, isTrue);
      expect(
        validation.diagnostics.map((diagnostic) => diagnostic.code),
        contains('invalid_plugin_definition'),
      );
      expect(
        cache.installed!.revision.contentHash,
        active.revision!.contentHash,
      );

      final held = await service.reload('acme.reader', 'agent-1');

      expect(held.isStale, isTrue);
      expect(held.revision!.contentHash, active.revision!.contentHash);
      expect(
        held.diagnostics.map((diagnostic) => diagnostic.code),
        contains('invalid_plugin_definition'),
      );
      expect(
        (await catalog.resolveForAgent(
          'agent-1',
          'acme.reader',
        )).revision.contentHash,
        active.revision!.contentHash,
      );
      expect(
        cache.installed!.revision.contentHash,
        active.revision!.contentHash,
      );
    },
  );

  test('blocks host effects while evaluating plugin registration', () async {
    final effectful = _validBundle(
      source: '''
local tinest = require("tinest")
tinest.tools.list({})
return tinest.plugin.define({})
''',
    );
    final effectCache = _MemoryRevisionCache();
    final effectRevisions = PluginRevisionCatalog(
      loader: _BundleLoader(effectful),
      cache: effectCache,
    );
    await effectRevisions.reload(
      'acme.reader',
      agentId: 'effect-agent',
      approvedCapabilities: const <String>{'model.call', 'tools.invoke'},
    );
    final effectRuntime = PluginRuntime<Object>(
      luaRuntime: lua.LuaToolRuntime<Object>(
        host: lua.LuaHostCommand.fromDirectory(stagedHost.path),
        processLauncher: const lua.IoLuaHostProcessLauncher(),
        clock: const lua.SystemLuaClock(),
        ids: _Ids(),
      ),
      revisions: effectRevisions,
    );
    addTearDown(effectRuntime.close);
    final effectSession = effectRuntime.openSession(
      agentId: 'effect-agent',
      sessionId: 'effect-session',
      allowedCapabilitiesByPlugin: const <String, Set<String>>{
        'acme.reader': <String>{'tools.invoke'},
      },
    );
    final router = _RecordingRouter();

    await expectLater(
      effectSession.register(pluginId: 'acme.reader', callbackRouter: router),
      throwsA(isA<PluginRegistrationException>()),
    );
    expect(router.calls, isEmpty);
  });

  test('reads revision assets and exposes no process globals', () async {
    final registration = await session.register(
      pluginId: 'acme.reader',
      callbackRouter: _RecordingRouter(),
    );
    final invocation = await session.invoke(
      pluginId: 'acme.reader',
      binding: registration.driver!.binding,
      arguments: const <String, Object?>{},
      callbackRouter: _RecordingRouter(),
    );
    final completed = await invocation.complete();

    expect(completed.error, isNull);
    expect(completed.result, <String, Object?>{
      'asset': '# Reader prompt',
      'io': 'nil',
      'os': 'nil',
      'package': 'nil',
      'leaked': 'nil',
    });

    final second = await (await session.invoke(
      pluginId: 'acme.reader',
      binding: registration.driver!.binding,
      arguments: const <String, Object?>{},
      callbackRouter: _RecordingRouter(),
    )).complete();
    expect((second.result! as Map<String, Object?>)['leaked'], 'nil');
  });

  test('double define runs in fresh VMs with canonical registration', () async {
    final deterministic = _validBundle(
      source: '''
local tinest = require("tinest")
local prior = definition_count or 0
definition_count = prior + 1
local driver = tinest.driver.define({
  id = "driver",
  metadata = {definition_count = definition_count},
}, function() return {tool_rounds = 0} end)
return tinest.plugin.define({driver = driver})
''',
    );
    final deterministicRevisions = PluginRevisionCatalog(
      loader: _BundleLoader(deterministic),
      cache: _MemoryRevisionCache(),
    );
    await deterministicRevisions.reload(
      deterministic.descriptor.id,
      agentId: 'fresh-vm-agent',
      approvedCapabilities: deterministic.descriptor.requestedCapabilities
          .toSet(),
    );
    final deterministicRuntime = PluginRuntime<Object>(
      luaRuntime: lua.LuaToolRuntime<Object>(
        host: lua.LuaHostCommand.fromDirectory(stagedHost.path),
        processLauncher: const lua.IoLuaHostProcessLauncher(),
        clock: const lua.SystemLuaClock(),
        ids: _Ids(),
      ),
      revisions: deterministicRevisions,
    );
    addTearDown(deterministicRuntime.close);
    final deterministicSession = deterministicRuntime.openSession(
      agentId: 'fresh-vm-agent',
      sessionId: 'fresh-vm-session',
      allowedCapabilitiesByPlugin: const <String, Set<String>>{},
    );

    final registration = await deterministicSession.register(
      pluginId: deterministic.descriptor.id,
      callbackRouter: _RecordingRouter(),
    );

    expect(registration.driver?.metadata['definition_count'], 1);
  });

  test(
    'duplicate contribution IDs fail in the real SDK registration',
    () async {
      final duplicate = _validBundle(
        source: '''
local tinest = require("tinest")
local S = tinest.schema
local tool = tinest.tool.function_({id = "duplicate"}, S.object({}), nil,
  function() return {} end)
local card = tinest.ui.contribution({
  id = "duplicate", slot = tinest.ui.slot.timeline,
}, S.any(), function() return tinest.ui.text({text = "duplicate"}) end)
return tinest.plugin.define({tools = {tool}, ui = {card}})
''',
      );
      final duplicateRevisions = PluginRevisionCatalog(
        loader: _BundleLoader(duplicate),
        cache: _MemoryRevisionCache(),
      );
      await duplicateRevisions.reload(
        duplicate.descriptor.id,
        agentId: 'duplicate-agent',
        approvedCapabilities: duplicate.descriptor.requestedCapabilities
            .toSet(),
      );
      final duplicateRuntime = PluginRuntime<Object>(
        luaRuntime: lua.LuaToolRuntime<Object>(
          host: lua.LuaHostCommand.fromDirectory(stagedHost.path),
          processLauncher: const lua.IoLuaHostProcessLauncher(),
          clock: const lua.SystemLuaClock(),
          ids: _Ids(),
        ),
        revisions: duplicateRevisions,
      );
      addTearDown(duplicateRuntime.close);
      final duplicateSession = duplicateRuntime.openSession(
        agentId: 'duplicate-agent',
        sessionId: 'duplicate-session',
        allowedCapabilitiesByPlugin: const <String, Set<String>>{},
      );

      await expectLater(
        duplicateSession.register(
          pluginId: duplicate.descriptor.id,
          callbackRouter: _RecordingRouter(),
        ),
        throwsA(
          isA<PluginRegistrationException>().having(
            (error) => error.message,
            'message',
            contains('Duplicate contribution ID'),
          ),
        ),
      );
    },
  );

  test('handler bindings are foreign-plugin and stale-revision safe', () async {
    final reader = _validBundle();
    final other = _validBundle(pluginId: 'acme.other');
    final loader = _MapBundleLoader(<String, PluginBundle>{
      reader.descriptor.id: reader,
      other.descriptor.id: other,
    });
    final identityCache = _MemoryRevisionCache();
    final identityRevisions = PluginRevisionCatalog(
      loader: loader,
      cache: identityCache,
    );
    for (final bundle in <PluginBundle>[reader, other]) {
      await identityRevisions.reload(
        bundle.descriptor.id,
        agentId: 'identity-agent',
        approvedCapabilities: bundle.descriptor.requestedCapabilities.toSet(),
      );
    }
    final identityRuntime = PluginRuntime<Object>(
      luaRuntime: lua.LuaToolRuntime<Object>(
        host: lua.LuaHostCommand.fromDirectory(stagedHost.path),
        processLauncher: const lua.IoLuaHostProcessLauncher(),
        clock: const lua.SystemLuaClock(),
        ids: _Ids(),
      ),
      revisions: identityRevisions,
    );
    addTearDown(identityRuntime.close);
    final grants = <String, Set<String>>{
      for (final bundle in <PluginBundle>[reader, other])
        bundle.descriptor.id: bundle.descriptor.requestedCapabilities.toSet(),
    };
    final oldSession = identityRuntime.openSession(
      agentId: 'identity-agent',
      sessionId: 'identity-old-session',
      allowedCapabilitiesByPlugin: grants,
    );
    final oldRegistration = await oldSession.register(
      pluginId: reader.descriptor.id,
      callbackRouter: _RecordingRouter(),
    );

    await expectLater(
      oldSession.invoke(
        pluginId: other.descriptor.id,
        binding: oldRegistration.tools.single.binding,
        arguments: const <String, Object?>{},
        callbackRouter: _RecordingRouter(),
      ),
      throwsA(isA<PluginRegistrationException>()),
      reason: 'a binding owned by another plugin must not match by shape',
    );

    final revised = _validBundle(revisionHash: 'revision-2');
    loader.bundles[reader.descriptor.id] = revised;
    await identityRevisions.reload(
      reader.descriptor.id,
      agentId: 'identity-agent',
      approvedCapabilities: revised.descriptor.requestedCapabilities.toSet(),
    );
    final newSession = identityRuntime.openSession(
      agentId: 'identity-agent',
      sessionId: 'identity-new-session',
      allowedCapabilitiesByPlugin: grants,
    );

    await expectLater(
      newSession.invoke(
        pluginId: revised.descriptor.id,
        binding: oldRegistration.tools.single.binding,
        arguments: const <String, Object?>{},
        callbackRouter: _RecordingRouter(),
      ),
      throwsA(isA<PluginRegistrationException>()),
      reason: 'a binding from an older execution revision must be stale',
    );
  });

  test(
    'session capability limits are intersected before a host callback runs',
    () async {
      final restricted = runtime.openSession(
        agentId: 'agent-1',
        sessionId: 'restricted-session',
        allowedCapabilitiesByPlugin: const <String, Set<String>>{
          'acme.reader': <String>{'model.call', 'tools.invoke'},
        },
        sessionCapabilities: const <String>{},
      );
      addTearDown(restricted.close);
      final router = _RecordingRouter(
        authorization: const PluginCallAuthorization.allowed(
          requiredCapabilities: <String>{'tools.invoke'},
        ),
        value: 'must not be returned',
      );
      final registration = await restricted.register(
        pluginId: 'acme.reader',
        callbackRouter: router,
      );

      final completed = await (await restricted.invoke(
        pluginId: 'acme.reader',
        binding: registration.tools.single.binding,
        arguments: const <String, Object?>{},
        callbackRouter: router,
      )).complete();

      expect(completed.error, isA<lua.LuaScriptException>());
      expect(router.calls, isEmpty);
    },
  );

  test(
    'a callback cannot expand the capability declared by its handler',
    () async {
      final router = _RecordingRouter(
        authorization: const PluginCallAuthorization.allowed(
          requiredCapabilities: <String>{'model.call'},
        ),
        value: 'must not be returned',
      );
      final registration = await session.register(
        pluginId: 'acme.reader',
        callbackRouter: router,
      );

      final invocation = await session.invoke(
        pluginId: 'acme.reader',
        binding: registration.tools.single.binding,
        arguments: const <String, Object?>{},
        callbackRouter: router,
      );
      final completed = await invocation.complete();

      expect(completed.error, isA<lua.LuaScriptException>());
      expect(router.calls, isEmpty);
      expect(identical(await invocation.wait(), invocation), isTrue);
    },
  );

  test('closed runtime and session reject new work idempotently', () async {
    final closedSession = runtime.openSession(
      agentId: 'agent-1',
      sessionId: 'closed-session',
      allowedCapabilitiesByPlugin: const <String, Set<String>>{},
    );
    await closedSession.close();
    await closedSession.close();

    // Typed, not a bare StateError: a transport has to answer a torn-down
    // runtime with a code the client can translate rather than internal_error.
    await expectLater(
      closedSession.register(
        pluginId: 'acme.reader',
        callbackRouter: _RecordingRouter(),
      ),
      throwsA(isA<PluginRuntimeClosed>()),
    );

    runtime.sweep();
    await runtime.close();
    await runtime.close();
    expect(
      () => runtime.openSession(
        agentId: 'agent-1',
        sessionId: 'after-close',
        allowedCapabilitiesByPlugin: const <String, Set<String>>{},
      ),
      throwsA(isA<PluginRuntimeClosed>()),
    );
  });

  test('routes SDK calls through capability-aware context', () async {
    final router = _RecordingRouter(
      authorization: const PluginCallAuthorization.allowed(
        requiredCapabilities: <String>{'tools.invoke'},
      ),
      value: const <String, Object?>{'text': 'approved'},
      values: const <String, Object?>{
        'tools.list': <Object?>[
          <String, Object?>{'id': 'acme.reader/read', 'name': 'Read'},
        ],
      },
    );

    final registration = await session.register(
      pluginId: 'acme.reader',
      callbackRouter: router,
    );
    final completed = await (await session.invoke(
      pluginId: 'acme.reader',
      binding: registration.tools.single.binding,
      arguments: const <String, Object?>{},
      callbackRouter: router,
    )).complete();

    expect(completed.error, isNull);
    expect(completed.result, <String, Object?>{'text': 'approved'});
    expect(router.calls.map((call) => call.name), <String>[
      'tools.list',
      'tools.invoke',
    ]);
    expect(router.calls.last.context.pluginId, 'acme.reader');
    expect(router.calls.last.context.revisionHash, 'execution-revision-1');
    expect(router.calls.last.context.effectiveCapabilities, const <String>{
      'model.call',
      'tools.invoke',
    });
  });

  test('preserves enriched tool result metadata across the Lua SDK', () async {
    final router = _RecordingRouter(
      authorization: const PluginCallAuthorization.allowed(
        requiredCapabilities: <String>{'tools.invoke'},
      ),
      value: const <String, Object?>{
        'output': 'Starting a new context window.',
        'is_error': false,
        'structured_content': <String, Object?>{
          'driver_action': <String, Object?>{'action': 'new_context'},
        },
        '_meta': <String, Object?>{
          'driver_action': <String, Object?>{'action': 'new_context'},
        },
      },
      values: const <String, Object?>{
        'tools.list': <Object?>[
          <String, Object?>{'id': 'acme.reader/read', 'name': 'Read'},
        ],
      },
    );

    final registration = await session.register(
      pluginId: 'acme.reader',
      callbackRouter: router,
    );
    final completed = await (await session.invoke(
      pluginId: 'acme.reader',
      binding: registration.tools.single.binding,
      arguments: const <String, Object?>{},
      callbackRouter: router,
    )).complete();

    expect(completed.error, isNull);
    expect(
      completed.result,
      containsPair(
        '_meta',
        containsPair('driver_action', containsPair('action', 'new_context')),
      ),
    );
    expect(
      completed.result,
      containsPair(
        'structured_content',
        containsPair('driver_action', containsPair('action', 'new_context')),
      ),
    );
  });

  test('raises actual primitive risk before calling its host port', () async {
    final router = _RecordingRouter(
      authorization: const PluginCallAuthorization.allowed(
        requiredCapabilities: <String>{'host.secret'},
      ),
      value: 'must not be returned',
    );

    final registration = await session.register(
      pluginId: 'acme.reader',
      callbackRouter: router,
    );
    final completed = await (await session.invoke(
      pluginId: 'acme.reader',
      binding: registration.tools.single.binding,
      arguments: const <String, Object?>{},
      callbackRouter: router,
    )).complete();

    expect(completed.error, isA<lua.LuaScriptException>());
    expect(router.calls, isEmpty);
  });

  test('does not share one plugin grant with another plugin', () async {
    final isolated = runtime.openSession(
      agentId: 'agent-1',
      sessionId: 'isolated-session',
      allowedCapabilitiesByPlugin: const <String, Set<String>>{
        'another.plugin': <String>{'tools.invoke'},
      },
    );
    addTearDown(isolated.close);
    final router = _RecordingRouter(
      authorization: const PluginCallAuthorization.allowed(
        requiredCapabilities: <String>{'tools.invoke'},
      ),
      value: 'must not be returned',
    );

    final registration = await isolated.register(
      pluginId: 'acme.reader',
      callbackRouter: router,
    );
    final completed = await (await isolated.invoke(
      pluginId: 'acme.reader',
      binding: registration.tools.single.binding,
      arguments: const <String, Object?>{},
      callbackRouter: router,
    )).complete();

    expect(completed.error, isA<lua.LuaScriptException>());
    expect(router.calls, isEmpty);
  });

  test('rejects a malformed or undeclared-capability spec', () async {
    final malformed = _validBundle(
      source: '''
tinest.plugin.define({
  tools = {{
    id = "bad/id",
    handler = "read",
    kind = "function",
    input_schema = {type = "string"},
    required_capabilities = {"host.secret"},
  }},
})
return {}
''',
    );
    revisions = PluginRevisionCatalog(
      loader: _BundleLoader(malformed),
      cache: cache,
    );
    await revisions.reload(
      'acme.reader',
      agentId: 'agent-2',
      approvedCapabilities: const <String>{'model.call', 'tools.invoke'},
    );
    final malformedRuntime = PluginRuntime<Object>(
      luaRuntime: lua.LuaToolRuntime<Object>(
        host: lua.LuaHostCommand.fromDirectory(stagedHost.path),
        processLauncher: const lua.IoLuaHostProcessLauncher(),
        clock: const lua.SystemLuaClock(),
        ids: _Ids(),
      ),
      revisions: revisions,
    );
    addTearDown(malformedRuntime.close);
    final malformedSession = malformedRuntime.openSession(
      agentId: 'agent-2',
      sessionId: 'session-2',
      allowedCapabilitiesByPlugin: const <String, Set<String>>{
        'acme.reader': <String>{'tools.invoke'},
      },
    );

    await expectLater(
      malformedSession.register(
        pluginId: 'acme.reader',
        callbackRouter: _RecordingRouter(),
      ),
      throwsA(isA<PluginRegistrationException>()),
    );
  });

  test('rejects author-written declared operation wire fields', () async {
    final forged = _validBundle(
      source: '''
local tinest = require("tinest")
local S = tinest.schema
local read = tinest.tool.function_({
  id = "read",
  declared_operations = {"host.workspace.read_text"},
}, S.object({}), nil, function() return {} end)
return tinest.plugin.define({tools = {read}})
''',
    );
    final forgedRevisions = PluginRevisionCatalog(
      loader: _BundleLoader(forged),
      cache: _MemoryRevisionCache(),
    );
    await forgedRevisions.reload(
      'acme.reader',
      agentId: 'agent-forged-operations',
      approvedCapabilities: forged.descriptor.requestedCapabilities.toSet(),
    );
    final forgedRuntime = PluginRuntime<Object>(
      luaRuntime: lua.LuaToolRuntime<Object>(
        host: lua.LuaHostCommand.fromDirectory(stagedHost.path),
        processLauncher: const lua.IoLuaHostProcessLauncher(),
        clock: const lua.SystemLuaClock(),
        ids: _Ids(),
      ),
      revisions: forgedRevisions,
    );
    addTearDown(forgedRuntime.close);
    final forgedSession = forgedRuntime.openSession(
      agentId: 'agent-forged-operations',
      sessionId: 'session-forged-operations',
      allowedCapabilitiesByPlugin: <String, Set<String>>{
        forged.descriptor.id: forged.descriptor.requestedCapabilities.toSet(),
      },
    );

    await expectLater(
      forgedSession.register(
        pluginId: forged.descriptor.id,
        callbackRouter: _RecordingRouter(),
      ),
      throwsA(
        isA<PluginRegistrationException>().having(
          (error) => error.message,
          'message',
          contains('declared_operations are SDK-owned'),
        ),
      ),
    );
  });

  test('plugin code cannot replace the private SDK entrypoint', () async {
    final forged = _validBundle(
      source: '''
local tinest = require("tinest")
tinest.__entrypoint = function(_definition)
  return {
    define = function(_arguments)
      return {api = 5, spec = {tools = {}}}
    end,
  }
end
return {}
''',
    );
    final forgedRevisions = PluginRevisionCatalog(
      loader: _BundleLoader(forged),
      cache: _MemoryRevisionCache(),
    );
    await forgedRevisions.reload(
      forged.descriptor.id,
      agentId: 'agent-forged-entrypoint',
      approvedCapabilities: forged.descriptor.requestedCapabilities.toSet(),
    );
    final forgedRuntime = PluginRuntime<Object>(
      luaRuntime: lua.LuaToolRuntime<Object>(
        host: lua.LuaHostCommand.fromDirectory(stagedHost.path),
        processLauncher: const lua.IoLuaHostProcessLauncher(),
        clock: const lua.SystemLuaClock(),
        ids: _Ids(),
      ),
      revisions: forgedRevisions,
    );
    addTearDown(forgedRuntime.close);
    final forgedSession = forgedRuntime.openSession(
      agentId: 'agent-forged-entrypoint',
      sessionId: 'session-forged-entrypoint',
      allowedCapabilitiesByPlugin: <String, Set<String>>{
        forged.descriptor.id: forged.descriptor.requestedCapabilities.toSet(),
      },
    );

    await expectLater(
      forgedSession.register(
        pluginId: forged.descriptor.id,
        callbackRouter: _RecordingRouter(),
      ),
      throwsA(
        isA<PluginRegistrationException>().having(
          (error) => error.message,
          'message',
          contains('plugin entrypoint return'),
        ),
      ),
    );
  });

  test(
    'author callbacks cannot require the private SDK entrypoint module',
    () async {
      final forged = _validBundle(
        source: '''
local tinest = require("tinest")
local S = tinest.schema

local probe = tinest.tool.function_({
  id = "probe",
  name = "Probe private SDK state",
  description = "Attempts to reach the private registration export.",
}, S.object({}), nil, function(_arguments)
  local private_entrypoint = require("tinest.entrypoint")
  private_entrypoint.define = function(_arguments)
    return {api = 5, spec = {tools = {}}}
  end
  return {private_entrypoint_accessible = true}
end)

return tinest.plugin.define({tools = {probe}})
''',
      );
      final forgedRevisions = PluginRevisionCatalog(
        loader: _BundleLoader(forged),
        cache: _MemoryRevisionCache(),
      );
      await forgedRevisions.reload(
        forged.descriptor.id,
        agentId: 'agent-private-entrypoint-require',
        approvedCapabilities: forged.descriptor.requestedCapabilities.toSet(),
      );
      final forgedRuntime = PluginRuntime<Object>(
        luaRuntime: lua.LuaToolRuntime<Object>(
          host: lua.LuaHostCommand.fromDirectory(stagedHost.path),
          processLauncher: const lua.IoLuaHostProcessLauncher(),
          clock: const lua.SystemLuaClock(),
          ids: _Ids(),
        ),
        revisions: forgedRevisions,
      );
      addTearDown(forgedRuntime.close);
      final forgedSession = forgedRuntime.openSession(
        agentId: 'agent-private-entrypoint-require',
        sessionId: 'session-private-entrypoint-require',
        allowedCapabilitiesByPlugin: <String, Set<String>>{
          forged.descriptor.id: forged.descriptor.requestedCapabilities.toSet(),
        },
      );
      final registration = await forgedSession.register(
        pluginId: forged.descriptor.id,
        callbackRouter: _RecordingRouter(),
      );

      final completed = await (await forgedSession.invoke(
        pluginId: forged.descriptor.id,
        binding: registration.tools.single.binding,
        arguments: const <String, Object?>{},
        callbackRouter: _RecordingRouter(),
      )).complete();

      expect(
        completed.error,
        isA<lua.LuaScriptException>().having(
          (error) => error.message,
          'message',
          contains('private Tinest module is unavailable: tinest.entrypoint'),
        ),
      );
    },
  );
}

PluginBundle _validBundle({
  String? source,
  String revisionHash = 'revision-1',
  String pluginId = 'acme.reader',
}) {
  final descriptor = PluginDescriptorDto(
    apiMajor: 5,
    id: pluginId,
    version: '1.0.0',
    name: 'Reader',
    entrypoint: 'main.lua',
    source: PluginSource.user,
    sourcePath: 'plugins/$pluginId',
    requestedCapabilities: <String>['model.call', 'tools.invoke'],
    revision: PluginRevisionDto(
      pluginId: pluginId,
      contentHash: revisionHash,
      manifestHash: 'manifest-1',
      sdkAbiHash: 'sdk-abi-hash',
      executionRevisionHash: 'execution-$revisionHash',
      requestedCapabilities: <String>['model.call', 'tools.invoke'],
    ),
  );
  return PluginBundle(
    descriptor: descriptor,
    revision: descriptor.revision!,
    assets: <String, Uint8List>{
      'PLUGIN.md': Uint8List.fromList('---\napi: 5\n---'.codeUnits),
      'main.lua': Uint8List.fromList(
        (source ??
                '''
local tinest = require("tinest")
local S = tinest.schema
local T = require("tinest.types")

local function runtime_fields()
  return {value = S.string()}
end

-- Exact LuaLS projection cannot analyze this function call, but runtime token
-- refs are compiled independently from the static T.Unprojected code ref.
local Unprojected = S.object(T.Unprojected, runtime_fields())
local ReadInput = S.object(T.ReadInput, {})

local driver = tinest.driver.define({
  id = "driver",
  uses = {tinest.model.open},
  required_model_capabilities = {"streaming"},
}, function(_arguments)
  local leaked = tostring(leaked_global)
  leaked_global = "must not survive this invocation"
  return {
    asset = tinest.assets.read("prompts/system.md"),
    io = tostring(io),
    os = tostring(os),
    package = tostring(package),
    leaked = leaked,
  }
end)

local read = tinest.tool.function_({
  id = "read",
  name = "Read",
  description = "Read one file",
  uses = {tinest.tools.invoke},
  effects = {"filesystem.read"},
  presentation = {group = "filesystem"},
}, ReadInput, nil, function(_arguments)
  local descriptors = tinest.tools.list({})
  return tinest.tools.invoke(descriptors[1].ref, {path = "README.md"})
end)

local before_turn = tinest.hook.before_turn({
  id = "before-turn",
  uses = {tinest.tools.invoke},
}, function(_arguments) return {} end)

local mode = tinest.session.control({
  id = "mode",
  uses = {tinest.tools.invoke},
  metadata = {default = false},
}, S.boolean(), function(arguments) return arguments.value end)

local status = tinest.ui.contribution({
  id = "status",
  slot = tinest.ui.slot.conversation_status,
  uses = {tinest.tools.invoke},
  depends_on = {tinest.ui.dependency.session_tree},
}, S.any(), function(_arguments) return tinest.ui.badge({text = "ok"}) end)

return tinest.plugin.define({
  driver = driver,
  tools = {read},
  hooks = {before_turn},
  session_controls = {mode},
  ui = {status},
})
''')
            .codeUnits,
      ),
      'prompts/system.md': Uint8List.fromList('# Reader prompt'.codeUnits),
    },
  );
}

final class _BundleLoader implements PluginBundleLoader {
  const new(this.bundle);

  final PluginBundle bundle;

  @override
  Future<PluginBundle> load(String id) async => bundle;
}

final class _MutableBundleLoader implements PluginBundleLoader {
  new(this.bundle);

  PluginBundle bundle;

  @override
  Future<PluginBundle> load(String id) async => bundle;
}

final class _MapBundleLoader implements PluginBundleLoader {
  const new(this.bundles);

  final Map<String, PluginBundle> bundles;

  @override
  Future<PluginBundle> load(String id) async => bundles[id]!;
}

final class _SourceCatalog implements PluginSourceCatalog {
  const new(this.ids);

  final List<String> ids;

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<List<String>> listPluginIds() async => ids;

  @override
  Future<void> scaffold(String id, String name) async =>
      throw UnsupportedError('not used');

  @override
  Future<void> fork(PluginBundle source, String id, String name) async =>
      throw UnsupportedError('not used');
}

final class _MemoryRevisionCache implements PluginRevisionCache {
  final Map<String, PluginBundle> _installed = <String, PluginBundle>{};
  final Map<String, PluginBundle> active = <String, PluginBundle>{};
  final Map<String, PluginBundle> executions = <String, PluginBundle>{};

  PluginBundle? get installed =>
      _installed.isEmpty ? null : _installed.values.last;

  @override
  Future<void> activateForAgent(String agentId, PluginBundle bundle) async {
    active['$agentId/${bundle.descriptor.id}'] = bundle;
    executions['${bundle.descriptor.id}/${bundle.revision.executionRevisionHash}'] =
        bundle;
  }

  @override
  Future<PluginBundle?> loadForAgent(String agentId, String id) async =>
      active['$agentId/$id'];

  @override
  Future<PluginBundle?> loadInstalled(String id) async => _installed[id];

  @override
  Future<PluginBundle?> loadExecutionRevision(
    String id,
    String executionRevisionHash,
  ) async => executions['$id/$executionRevisionHash'];

  @override
  Future<void> storeInstalled(PluginBundle bundle) async {
    _installed[bundle.descriptor.id] = bundle;
    executions['${bundle.descriptor.id}/${bundle.revision.executionRevisionHash}'] =
        bundle;
  }
}

final class _RecordingRouter implements PluginCallbackRouter<Object> {
  new({
    this.authorization = const PluginCallAuthorization.denied('not expected'),
    this.value,
    this.values = const <String, Object?>{},
  });

  final PluginCallAuthorization authorization;
  final Object? value;
  final Map<String, Object?> values;
  final List<_Call> calls = <_Call>[];

  @override
  Future<PluginCallAuthorization> authorize(
    PluginHostCallContext context,
    String name,
    Map<String, Object?> arguments,
  ) async => authorization;

  @override
  Future<PluginCallbackResult<Object>> call(
    PluginHostCallContext context,
    String name,
    Map<String, Object?> arguments,
    PluginInvocationCancellation cancellation,
  ) async {
    calls.add(_Call(context, name));
    return PluginCallbackResult<Object>(value: values[name] ?? value);
  }

  @override
  Stream<PluginCallbackResult<Object>> open(
    PluginHostCallContext context,
    String name,
    Map<String, Object?> arguments,
    PluginInvocationCancellation cancellation,
  ) => const Stream<PluginCallbackResult<Object>>.empty();
}

final class _Call {
  const new(this.context, this.name);

  final PluginHostCallContext context;
  final String name;
}

final class _Ids implements lua.LuaIdGenerator {
  int _next = 0;

  @override
  String generate() => '${++_next}';
}

Future<String> _cmakeExecutable() async {
  if (!Platform.isWindows) return 'cmake';
  final onPath = await Process.run('where.exe', <String>['cmake']);
  if (onPath.exitCode == 0) {
    final candidates = (onPath.stdout as String)
        .split(RegExp(r'[\r\n]+'))
        .where((line) => line.isNotEmpty);
    if (candidates.isNotEmpty) return candidates.first;
  }
  final programFilesX86 = Platform.environment['ProgramFiles(x86)'];
  if (programFilesX86 != null) {
    final vswhere = File(
      '$programFilesX86/Microsoft Visual Studio/Installer/vswhere.exe',
    );
    if (vswhere.existsSync()) {
      final result = await Process.run(vswhere.path, const <String>[
        '-latest',
        '-products',
        '*',
        '-requires',
        'Microsoft.VisualStudio.Component.VC.CMake.Project',
        '-find',
        r'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe',
      ]);
      final candidate = (result.stdout as String).trim();
      if (result.exitCode == 0 && candidate.isNotEmpty) return candidate;
    }
  }
  return 'cmake';
}
