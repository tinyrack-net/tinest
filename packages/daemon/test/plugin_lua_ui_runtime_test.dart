@Tags(<String>['feature_test__plugin_ui__unit'])
@Timeout(Duration(minutes: 2))
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:daemon/src/features/plugins/infrastructure/memory_plugin_stores.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_bundles.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_ports.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_ui_service.dart';
import 'package:daemon/src/features/plugins/runtime/host_primitive_contracts.dart';
import 'package:daemon/src/features/plugins/runtime/host_primitives.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_runtime.dart';
import 'package:lua_tool_runtime/lua_tool_runtime.dart' as lua;
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'support/temporary_directory.dart';

void main() {
  late Directory stagedHost;
  late Directory buildDirectory;

  setUpAll(() async {
    final prebuilt = Platform.environment['TINEST_PLUGIN_TEST_LUA_HOST'];
    if (prebuilt != null && prebuilt.isNotEmpty) {
      stagedHost = Directory(prebuilt);
      buildDirectory = Directory('');
      return;
    }
    stagedHost = await Directory.systemTemp.createTemp(
      'tinest-plugin-ui-host-',
    );
    buildDirectory = await Directory.systemTemp.createTemp(
      'tinest-plugin-ui-build-',
    );
    await lua.stageLuaToolRuntime(
      destination: stagedHost.path,
      buildMode: lua.LuaBuildMode.debug,
      buildDirectory: buildDirectory.path,
      cmakeExecutable: await _cmakeExecutable(),
    );
  });

  tearDownAll(() async {
    if (Platform.environment['TINEST_PLUGIN_TEST_LUA_HOST'] == null) {
      // The staged host is an executable these tests ran, so on Windows its
      // image handle can outlive the process that held it.
      await deleteTemporaryDirectory(stagedHost);
      await deleteTemporaryDirectory(buildDirectory);
    }
  });

  test(
    'renders plan, goal, and collaboration UI through registered Lua handlers',
    () async {
      final loader = _MapLoader(<String, PluginBundle>{
        'tinest.plan': await const BuiltInPluginCatalog().load('tinest.plan'),
        'tinest.goal': await const BuiltInPluginCatalog().load('tinest.goal'),
        'tinest.collaboration': await const BuiltInPluginCatalog().load(
          'tinest.collaboration',
        ),
      });
      final cache = _MemoryRevisionCache();
      final revisions = PluginRevisionCatalog(loader: loader, cache: cache);
      final runtime = _runtime(revisions, stagedHost);
      addTearDown(runtime.close);
      final grants = MemoryAgentPluginGrantStore();
      final state = MemoryPluginStateStore();
      final collaborationHostCalls = <Map<String, Object?>>[];
      for (final entry in loader.bundles.entries) {
        for (final capability in entry.value.revision.requestedCapabilities) {
          await grants.grant(
            AgentPluginGrantDto(
              agentId: 'agent',
              pluginId: entry.key,
              capability: capability,
            ),
          );
        }
        await revisions.reload(
          entry.key,
          agentId: 'agent',
          approvedCapabilities: entry.value.revision.requestedCapabilities
              .toSet(),
          inspector: runtime,
        );
      }
      await state.compareAndSet(
        const PluginStateScope.session(
          pluginId: 'tinest.plan',
          sessionId: 'session',
        ),
        'plan',
        expectedRevision: 0,
        value: <String, Object?>{
          'explanation': 'Ship it',
          'plan': <Object?>[
            <String, Object?>{'step': 'Test', 'status': 'in_progress'},
          ],
        },
      );
      await state.compareAndSet(
        const PluginStateScope.session(
          pluginId: 'tinest.goal',
          sessionId: 'session',
        ),
        'goal',
        expectedRevision: 0,
        value: <String, Object?>{
          'objective': 'Finish v5',
          'status': 'active',
          'tokens_used': 0,
          'time_used_seconds': 0,
          'turns': 0,
        },
      );
      final service = PluginUiService(
        descriptors: _RevisionDescriptorReader(revisions),
        runtime: LuaPluginUiRuntime<Object>(
          runtime: runtime,
          grants: grants,
          state: state,
          hostPrimitives: _collaborationUiPrimitives(
            calls: collaborationHostCalls,
          ),
          definitions: (_) async => _definition(const <String>[
            'tinest.plan',
            'tinest.goal',
            'tinest.collaboration',
          ]),
        ),
      );

      final plan = await service.render(
        const PluginUiRenderParamsDto(
          agentId: 'agent',
          pluginId: 'tinest.plan',
          contributionId: 'tinest.plan/plan_card',
          slot: PluginUiSlot.timeline,
          context: <String, dynamic>{'sessionId': 'session'},
        ),
      );
      final goal = await service.render(
        const PluginUiRenderParamsDto(
          agentId: 'agent',
          pluginId: 'tinest.goal',
          contributionId: 'tinest.goal/goal_status',
          slot: PluginUiSlot.conversationStatus,
          context: <String, dynamic>{'sessionId': 'session'},
        ),
      );
      final goalDialog = await service.render(
        const PluginUiRenderParamsDto(
          agentId: 'agent',
          pluginId: 'tinest.goal',
          contributionId: 'tinest.goal/goal_dialog',
          slot: PluginUiSlot.dialog,
          context: <String, dynamic>{'sessionId': 'session'},
        ),
      );
      final collaboration = await service.render(
        const PluginUiRenderParamsDto(
          agentId: 'agent',
          pluginId: 'tinest.collaboration',
          contributionId: 'tinest.collaboration/agent_status',
          slot: PluginUiSlot.composerDrawer,
          context: <String, dynamic>{'sessionId': 'session', 'locale': 'en'},
        ),
      );
      await service.render(
        const PluginUiRenderParamsDto(
          agentId: 'agent',
          pluginId: 'tinest.collaboration',
          contributionId: 'tinest.collaboration/agent_status',
          slot: PluginUiSlot.composerDrawer,
          input: <String, Object?>{'snapshot': 'presentation-only'},
          context: <String, dynamic>{'sessionId': 'session', 'locale': 'en'},
        ),
      );

      expect(plan.root, containsPair('type', 'section'));
      final planChildren = plan.root['children']! as List<Object?>;
      expect(planChildren.first, containsPair('text', contains('Ship it')));
      expect(goal.root, containsPair('type', 'badge'));
      expect(goal.root, containsPair('text', 'active'));
      expect(goalDialog.root, containsPair('type', 'section'));
      expect(goalDialog.root.toString(), contains('Finish v5'));
      // The drawer states meaning, not presentation: a count, a status word
      // from the closed vocabulary, and a session to open. Which glyph and
      // which colour those become is the host's business.
      expect(collaboration.root, containsPair('type', 'disclosure'));
      expect(collaboration.root, containsPair('title', '1 subagent'));
      final tree =
          (collaboration.root['children']! as List).single
              as Map<String, Object?>;
      expect(tree, containsPair('type', 'tree'));
      final item = (tree['children']! as List).single as Map<String, Object?>;
      // `list_agents` answers with the whole tree, root included, but the root
      // is the session this drawer sits under. Only subagents belong here.
      expect(item, containsPair('label', 'reviewer'));
      expect(item, containsPair('description', '/root/reviewer'));
      expect(item, containsPair('status', 'running'));
      expect(item['onActivate'], <String, Object?>{
        'type': 'open_session',
        'sessionId': 'reviewer-session',
      });
      expect(collaborationHostCalls, <Map<String, Object?>>[
        <String, Object?>{},
        <String, Object?>{},
      ]);

      final refreshed = await service.dispatch(
        PluginUiActionParamsDto(
          agentId: 'agent',
          pluginId: 'tinest.plan',
          action: PluginUiActionDto(
            documentId: plan.id,
            actionId: 'tinest.plan/refresh',
          ),
        ),
      );
      expect(refreshed.id, plan.id);
      expect(refreshed.root.toString(), contains('Ship it'));

      await grants.revoke(
        const AgentPluginGrantDto(
          agentId: 'agent',
          pluginId: 'tinest.plan',
          capability: 'state.read',
        ),
      );
      await expectLater(
        service.dispatch(
          PluginUiActionParamsDto(
            agentId: 'agent',
            pluginId: 'tinest.plan',
            action: PluginUiActionDto(
              documentId: plan.id,
              actionId: 'tinest.plan/refresh',
            ),
          ),
        ),
        throwsA(isA<PluginUiException>()),
      );
    },
  );

  test(
    'a tree without subagents renders an empty collaboration status document',
    () async {
      final bundle = await const BuiltInPluginCatalog().load(
        'tinest.collaboration',
      );
      final revisions = PluginRevisionCatalog(
        loader: _MapLoader(<String, PluginBundle>{
          'tinest.collaboration': bundle,
        }),
        cache: _MemoryRevisionCache(),
      );
      final runtime = _runtime(revisions, stagedHost);
      addTearDown(runtime.close);
      final grants = MemoryAgentPluginGrantStore();
      for (final capability in bundle.revision.requestedCapabilities) {
        await grants.grant(
          AgentPluginGrantDto(
            agentId: 'agent',
            pluginId: 'tinest.collaboration',
            capability: capability,
          ),
        );
      }
      await revisions.reload(
        'tinest.collaboration',
        agentId: 'agent',
        approvedCapabilities: bundle.revision.requestedCapabilities.toSet(),
        inspector: runtime,
      );
      final service = PluginUiService(
        descriptors: _RevisionDescriptorReader(revisions),
        runtime: LuaPluginUiRuntime<Object>(
          runtime: runtime,
          grants: grants,
          state: MemoryPluginStateStore(),
          hostPrimitives: _collaborationUiPrimitives(
            agents: const <Map<String, Object?>>[
              <String, Object?>{
                'session_id': 'root-session',
                'agent_name': '/root',
                'agent_status': 'running',
                'session_status': 'running',
                'title': 'Root',
              },
            ],
          ),
          definitions: (_) async =>
              _definition(const <String>['tinest.collaboration']),
        ),
      );

      final document = await service.render(
        const PluginUiRenderParamsDto(
          agentId: 'agent',
          pluginId: 'tinest.collaboration',
          contributionId: 'tinest.collaboration/agent_status',
          slot: PluginUiSlot.composerDrawer,
          context: <String, dynamic>{'sessionId': 'session', 'locale': 'en'},
        ),
      );

      // Every ordinary session is a tree of exactly one agent: itself. The
      // drawer has nothing to report there, and it says so with a section that
      // carries no rows, which the host drops instead of framing.
      expect(document.root, containsPair('type', 'section'));
      expect(document.root['children'], isEmpty);
      expect(document.root['children'], isA<List<Object?>>());
    },
  );

  test(
    'UI host primitives require registry, uses, grant, and structured results',
    () async {
      final runtimes = <PluginRuntime<Object>>[];
      addTearDown(() async {
        for (final runtime in runtimes) {
          await runtime.close();
        }
      });

      Future<PluginUiDocumentDto> render({
        required PluginBundle bundle,
        required Set<String> grantedCapabilities,
        HostPrimitiveRegistry? hostPrimitives,
      }) async {
        final revisions = PluginRevisionCatalog(
          loader: _MapLoader(<String, PluginBundle>{
            bundle.descriptor.id: bundle,
          }),
          cache: _MemoryRevisionCache(),
        );
        final runtime = _runtime(revisions, stagedHost);
        runtimes.add(runtime);
        final grants = MemoryAgentPluginGrantStore();
        for (final capability in grantedCapabilities) {
          await grants.grant(
            AgentPluginGrantDto(
              agentId: 'agent',
              pluginId: bundle.descriptor.id,
              capability: capability,
            ),
          );
        }
        await revisions.reload(
          bundle.descriptor.id,
          agentId: 'agent',
          approvedCapabilities: bundle.revision.requestedCapabilities.toSet(),
          inspector: runtime,
        );
        final service = PluginUiService(
          descriptors: _RevisionDescriptorReader(revisions),
          runtime: LuaPluginUiRuntime<Object>(
            runtime: runtime,
            grants: grants,
            state: MemoryPluginStateStore(),
            hostPrimitives: hostPrimitives,
            definitions: (_) async => _definition(const <String>[]),
          ),
        );
        return await service.render(
          PluginUiRenderParamsDto(
            agentId: 'agent',
            pluginId: bundle.descriptor.id,
            contributionId: '${bundle.descriptor.id}/card',
            slot: PluginUiSlot.timeline,
          ),
        );
      }

      await expectLater(
        render(
          bundle: _uiPrimitiveBundle(
            id: 'acme.missing-primitive',
            primitive: 'tinest.host.clock.sleep',
            capability: 'tinest.capability.clock.sleep',
            requestedCapability: 'clock.sleep',
          ),
          grantedCapabilities: const <String>{'clock.sleep'},
        ),
        throwsA(
          isA<PluginUiException>().having(
            (error) => error.message,
            'message',
            contains(
              'UI handlers cannot call Tinest host operation: '
              'host.clock.sleep',
            ),
          ),
        ),
      );

      await expectLater(
        render(
          bundle: _uiPrimitiveBundle(
            id: 'acme.missing-uses',
            primitive: 'tinest.host.clock.sleep',
            capability: 'tinest.capability.clock.sleep',
            requestedCapability: 'clock.sleep',
            declareUse: false,
          ),
          grantedCapabilities: const <String>{'clock.sleep'},
          hostPrimitives: _immediateClockUiPrimitives(),
        ),
        throwsA(
          isA<PluginUiException>().having(
            (error) => error.message,
            'message',
            contains(
              'Handler did not declare the host primitive in uses: '
              'host.clock.sleep',
            ),
          ),
        ),
      );

      await expectLater(
        render(
          bundle: _uiPrimitiveBundle(
            id: 'acme.missing-grant',
            primitive: 'tinest.host.clock.sleep',
            capability: 'tinest.capability.clock.sleep',
            requestedCapability: 'clock.sleep',
          ),
          grantedCapabilities: const <String>{},
          hostPrimitives: _immediateClockUiPrimitives(),
        ),
        throwsA(
          isA<PluginUiException>().having(
            (error) => error.message,
            'message',
            contains('Plugin capability is not granted: clock.sleep'),
          ),
        ),
      );

      final structured = await render(
        bundle: _uiPrimitiveBundle(
          id: 'acme.structured-host',
          primitive: 'tinest.host.collaboration.list_agents',
          capability: 'tinest.capability.collaboration.list',
          requestedCapability: 'collaboration.list',
          inspectEnvelope: true,
        ),
        grantedCapabilities: const <String>{'collaboration.list'},
        hostPrimitives: _collaborationUiPrimitives(),
      );
      expect(structured.root, containsPair('text', 'true'));
    },
  );

  test('a UI handler reads the host facts of its surface', () async {
    // A surface has to know where it is being drawn — which session, which
    // locale, whether the pane accepts input — and the host is the only one
    // that knows. Without it every plugin either hardcodes English or asks a
    // host primitive for something the host already had in hand.
    final bundle = _pluginBundle(
      id: 'acme.ui-context',
      source: '''
local tinest = require("tinest")
local S = tinest.schema
local card = tinest.ui.contribution({
  id = "card",
  slot = tinest.ui.slot.timeline,
}, S.any(), function(_arguments, context)
  return tinest.ui.text({
    text = tostring(context.locale) .. "|" ..
      tostring(context.sessionId) .. "|" ..
      tostring(context.readOnly),
  })
end)
return tinest.plugin.define({ui = {card}})
''',
    );
    final revisions = PluginRevisionCatalog(
      loader: _MapLoader(<String, PluginBundle>{bundle.descriptor.id: bundle}),
      cache: _MemoryRevisionCache(),
    );
    final runtime = _runtime(revisions, stagedHost);
    addTearDown(runtime.close);
    await revisions.reload(
      bundle.descriptor.id,
      agentId: 'agent',
      approvedCapabilities: const <String>{},
      inspector: runtime,
    );
    final service = PluginUiService(
      descriptors: _RevisionDescriptorReader(revisions),
      runtime: LuaPluginUiRuntime<Object>(
        runtime: runtime,
        grants: MemoryAgentPluginGrantStore(),
        state: MemoryPluginStateStore(),
        definitions: (_) async => _definition(const <String>[]),
      ),
    );

    final document = await service.render(
      const PluginUiRenderParamsDto(
        agentId: 'agent',
        pluginId: 'acme.ui-context',
        contributionId: 'acme.ui-context/card',
        slot: PluginUiSlot.timeline,
        context: <String, dynamic>{
          'sessionId': 'session',
          'locale': 'ko',
          'readOnly': true,
        },
      ),
    );

    expect(document.root, containsPair('text', 'ko|session|true'));
  });

  test('a UI handler that ignores the context still renders', () async {
    // Every built-in takes one parameter. The context is an addition, not a
    // new obligation, so a handler written before it must be unaffected.
    final bundle = _pluginBundle(
      id: 'acme.ui-no-context',
      source: '''
local tinest = require("tinest")
local S = tinest.schema
local card = tinest.ui.contribution({
  id = "card",
  slot = tinest.ui.slot.timeline,
}, S.any(), function(_arguments)
  return tinest.ui.text({text = "steady"})
end)
return tinest.plugin.define({ui = {card}})
''',
    );
    final revisions = PluginRevisionCatalog(
      loader: _MapLoader(<String, PluginBundle>{bundle.descriptor.id: bundle}),
      cache: _MemoryRevisionCache(),
    );
    final runtime = _runtime(revisions, stagedHost);
    addTearDown(runtime.close);
    await revisions.reload(
      bundle.descriptor.id,
      agentId: 'agent',
      approvedCapabilities: const <String>{},
      inspector: runtime,
    );
    final service = PluginUiService(
      descriptors: _RevisionDescriptorReader(revisions),
      runtime: LuaPluginUiRuntime<Object>(
        runtime: runtime,
        grants: MemoryAgentPluginGrantStore(),
        state: MemoryPluginStateStore(),
        definitions: (_) async => _definition(const <String>[]),
      ),
    );

    final document = await service.render(
      const PluginUiRenderParamsDto(
        agentId: 'agent',
        pluginId: 'acme.ui-no-context',
        contributionId: 'acme.ui-no-context/card',
        slot: PluginUiSlot.timeline,
        context: <String, dynamic>{'sessionId': 'session', 'locale': 'ko'},
      ),
    );

    expect(document.root, containsPair('text', 'steady'));
  });

  test('UI state cells reject malformed persisted values', () async {
    final bundle = _pluginBundle(
      id: 'acme.ui-state-schema',
      requestedCapabilities: const <String>['state.read'],
      source: '''
local tinest = require("tinest")
local S = tinest.schema
local value_state = tinest.state.cell({
  scope = tinest.state.scope.session, key = "value",
}, S.string())
local card = tinest.ui.contribution({
  id = "card",
  slot = tinest.ui.slot.timeline,
  required_capabilities = {tinest.capability.state.read},
}, S.any(), function(_arguments)
  local value = value_state:read()
  return tinest.ui.text({text = tostring(value.value)})
end)
return tinest.plugin.define({ui = {card}})
''',
    );
    final revisions = PluginRevisionCatalog(
      loader: _MapLoader(<String, PluginBundle>{bundle.descriptor.id: bundle}),
      cache: _MemoryRevisionCache(),
    );
    final runtime = _runtime(revisions, stagedHost);
    addTearDown(runtime.close);
    final grants = MemoryAgentPluginGrantStore();
    await grants.grant(
      const AgentPluginGrantDto(
        agentId: 'agent',
        pluginId: 'acme.ui-state-schema',
        capability: 'state.read',
      ),
    );
    await revisions.reload(
      bundle.descriptor.id,
      agentId: 'agent',
      approvedCapabilities: const <String>{'state.read'},
      inspector: runtime,
    );
    final state = MemoryPluginStateStore();
    await state.compareAndSet(
      const PluginStateScope.session(
        pluginId: 'acme.ui-state-schema',
        sessionId: 'session',
      ),
      'value',
      expectedRevision: 0,
      value: 42,
    );
    final service = PluginUiService(
      descriptors: _RevisionDescriptorReader(revisions),
      runtime: LuaPluginUiRuntime<Object>(
        runtime: runtime,
        grants: grants,
        state: state,
        definitions: (_) async => _definition(const <String>[]),
      ),
    );

    await expectLater(
      service.render(
        const PluginUiRenderParamsDto(
          agentId: 'agent',
          pluginId: 'acme.ui-state-schema',
          contributionId: 'acme.ui-state-schema/card',
          slot: PluginUiSlot.timeline,
          context: <String, dynamic>{'sessionId': 'session'},
        ),
      ),
      throwsA(isA<PluginUiException>()),
    );
  });

  test('keeps the exact Lua revision alive for a historical action', () async {
    final loader = _MutableLoader(_uiBundle('revision-one', 'One'));
    final cache = _MemoryRevisionCache();
    final revisions = PluginRevisionCatalog(loader: loader, cache: cache);
    final runtime = _runtime(revisions, stagedHost);
    addTearDown(runtime.close);
    final grants = MemoryAgentPluginGrantStore();
    await revisions.reload(
      'acme.ui',
      agentId: 'agent',
      approvedCapabilities: const <String>{},
      inspector: runtime,
    );
    final service = PluginUiService(
      descriptors: _RevisionDescriptorReader(revisions),
      runtime: LuaPluginUiRuntime<Object>(
        runtime: runtime,
        grants: grants,
        state: MemoryPluginStateStore(),
        definitions: (_) async => _definition(const <String>[]),
      ),
    );
    final rendered = await service.render(
      const PluginUiRenderParamsDto(
        agentId: 'agent',
        pluginId: 'acme.ui',
        contributionId: 'acme.ui/card',
        slot: PluginUiSlot.timeline,
      ),
    );

    loader.bundle = _uiBundle('revision-two', 'Two');
    await revisions.reload(
      'acme.ui',
      agentId: 'agent',
      approvedCapabilities: const <String>{},
      inspector: runtime,
    );
    await expectLater(
      service.dispatch(
        PluginUiActionParamsDto(
          agentId: 'agent',
          pluginId: 'acme.ui',
          action: PluginUiActionDto(
            documentId: rendered.id,
            actionId: 'acme.ui/refresh',
            data: const <String, dynamic>{'suffix': 42},
          ),
        ),
      ),
      throwsA(
        isA<PluginUiException>().having(
          (error) => error.message,
          'message',
          contains(r'$.action.data.suffix'),
        ),
      ),
    );
    final updated = await service.dispatch(
      PluginUiActionParamsDto(
        agentId: 'agent',
        pluginId: 'acme.ui',
        action: PluginUiActionDto(
          documentId: rendered.id,
          actionId: 'acme.ui/refresh',
          data: <String, dynamic>{'suffix': 'action'},
        ),
      ),
    );

    expect(updated.revisionHash, 'execution-revision-one');
    expect(updated.root.toString(), contains('One'));
  });

  test('passes validated RPC input directly to the UI callback', () async {
    final bundle = _pluginBundle(
      id: 'acme.input',
      source: '''
local tinest = require("tinest")
local S = tinest.schema
local card = tinest.ui.contribution({
  id = "card", slot = tinest.ui.slot.timeline,
}, S.object({title = S.string()}), function(input)
  if input.event ~= nil or input.context ~= nil then
    error("host envelope leaked into public input")
  end
  return tinest.ui.text({text = input.title})
end)
return tinest.plugin.define({ui = {card}})
''',
    );
    final revisions = PluginRevisionCatalog(
      loader: _MapLoader(<String, PluginBundle>{'acme.input': bundle}),
      cache: _MemoryRevisionCache(),
    );
    final runtime = _runtime(revisions, stagedHost);
    addTearDown(runtime.close);
    await revisions.reload(
      'acme.input',
      agentId: 'agent',
      approvedCapabilities: const <String>{},
      inspector: runtime,
    );
    final service = PluginUiService(
      descriptors: _RevisionDescriptorReader(revisions),
      runtime: LuaPluginUiRuntime<Object>(
        runtime: runtime,
        grants: MemoryAgentPluginGrantStore(),
        state: MemoryPluginStateStore(),
        definitions: (_) async => _definition(const <String>[]),
      ),
    );
    const request = PluginUiRenderParamsDto(
      agentId: 'agent',
      pluginId: 'acme.input',
      contributionId: 'acme.input/card',
      slot: PluginUiSlot.timeline,
      input: <String, dynamic>{'title': 'Direct input'},
    );

    final document = await service.render(request);
    expect(document.root['text'], 'Direct input');
    await expectLater(
      service.render(request.copyWith(input: <String, dynamic>{'title': 42})),
      throwsA(
        isA<PluginUiException>().having(
          (error) => error.message,
          'message',
          contains(r'$.input.title'),
        ),
      ),
    );
  });

  test(
    'rejects a raw Lua UI document that bypasses SDK constructors',
    () async {
      final loader = _MutableLoader(
        _uiBundle('invalid-revision', 'Bad', invalid: true),
      );
      final revisions = PluginRevisionCatalog(
        loader: loader,
        cache: _MemoryRevisionCache(),
      );
      final runtime = _runtime(revisions, stagedHost);
      addTearDown(runtime.close);
      await revisions.reload(
        'acme.ui',
        agentId: 'agent',
        approvedCapabilities: const <String>{},
        inspector: runtime,
      );
      final service = PluginUiService(
        descriptors: _RevisionDescriptorReader(revisions),
        runtime: LuaPluginUiRuntime<Object>(
          runtime: runtime,
          grants: MemoryAgentPluginGrantStore(),
          state: MemoryPluginStateStore(),
          definitions: (_) async => _definition(const <String>[]),
        ),
      );

      await expectLater(
        service.render(
          const PluginUiRenderParamsDto(
            agentId: 'agent',
            pluginId: 'acme.ui',
            contributionId: 'acme.ui/card',
            slot: PluginUiSlot.timeline,
          ),
        ),
        throwsA(
          isA<PluginUiException>().having(
            (error) => error.message,
            'message',
            contains('must return a Tinest UI node'),
          ),
        ),
      );
    },
  );

  test('rejects raw, foreign, and wrong-kind UI action references', () async {
    final cases = <String, String>{
      'raw foreign action ID': '''
local tinest = require("tinest")
local S = tinest.schema
local card = tinest.ui.contribution({
  id = "card", slot = tinest.ui.slot.timeline,
}, S.any(), function(_arguments)
  return {type = "button", label = "Pwn", actionId = "acme.foreign/run"}
end)
return tinest.plugin.define({ui = {card}})
''',
      'raw same-plugin action ID': '''
local tinest = require("tinest")
local S = tinest.schema
local refresh = tinest.ui.action({id = "refresh"}, S.any(), function(arguments)
  return arguments
end)
local card = tinest.ui.contribution({
  id = "card", slot = tinest.ui.slot.timeline,
}, S.any(), function(_arguments)
  return {type = "button", label = "Pwn", actionId = "acme.target/refresh"}
end)
return tinest.plugin.define({ui = {card}, actions = {refresh}})
''',
      'wrong-kind contribution ref': '''
local tinest = require("tinest")
local S = tinest.schema
local card
card = tinest.ui.contribution({
  id = "card", slot = tinest.ui.slot.timeline,
}, S.any(), function(_arguments)
  return tinest.ui.button({label = "Pwn", action = card})
end)
return tinest.plugin.define({ui = {card}})
''',
    };

    for (final entry in cases.entries) {
      final bundle = _pluginBundle(id: 'acme.target', source: entry.value);
      final revisions = PluginRevisionCatalog(
        loader: _MapLoader(<String, PluginBundle>{'acme.target': bundle}),
        cache: _MemoryRevisionCache(),
      );
      final runtime = _runtime(revisions, stagedHost);
      addTearDown(runtime.close);
      await revisions.reload(
        'acme.target',
        agentId: 'agent',
        approvedCapabilities: const <String>{},
        inspector: runtime,
      );
      final service = PluginUiService(
        descriptors: _RevisionDescriptorReader(revisions),
        runtime: LuaPluginUiRuntime<Object>(
          runtime: runtime,
          grants: MemoryAgentPluginGrantStore(),
          state: MemoryPluginStateStore(),
          definitions: (_) async => _definition(const <String>[]),
        ),
      );

      await expectLater(
        service.render(
          const PluginUiRenderParamsDto(
            agentId: 'agent',
            pluginId: 'acme.target',
            contributionId: 'acme.target/card',
            slot: PluginUiSlot.timeline,
          ),
        ),
        throwsA(isA<PluginUiException>()),
        reason: entry.key,
      );
    }
  });

  test(
    'dispatch accepts only an action referenced by its UI snapshot',
    () async {
      final bundle = _pluginBundle(
        id: 'acme.target',
        source: '''
local tinest = require("tinest")
local S = tinest.schema
local refresh = tinest.ui.action({id = "refresh"}, S.any(), function(arguments)
  return arguments
end)
local hidden = tinest.ui.action({id = "hidden"}, S.any(), function(arguments)
  return arguments
end)
local card = tinest.ui.contribution({
  id = "card", slot = tinest.ui.slot.timeline,
}, S.any(), function(_arguments)
  return tinest.ui.button({label = "Refresh", action = refresh})
end)
return tinest.plugin.define({ui = {card}, actions = {refresh, hidden}})
''',
      );
      final revisions = PluginRevisionCatalog(
        loader: _MapLoader(<String, PluginBundle>{'acme.target': bundle}),
        cache: _MemoryRevisionCache(),
      );
      final runtime = _runtime(revisions, stagedHost);
      addTearDown(runtime.close);
      await revisions.reload(
        'acme.target',
        agentId: 'agent',
        approvedCapabilities: const <String>{},
        inspector: runtime,
      );
      final service = PluginUiService(
        descriptors: _RevisionDescriptorReader(revisions),
        runtime: LuaPluginUiRuntime<Object>(
          runtime: runtime,
          grants: MemoryAgentPluginGrantStore(),
          state: MemoryPluginStateStore(),
          definitions: (_) async => _definition(const <String>['acme.target']),
        ),
      );
      final rendered = await service.render(
        const PluginUiRenderParamsDto(
          agentId: 'agent',
          pluginId: 'acme.target',
          contributionId: 'acme.target/card',
          slot: PluginUiSlot.timeline,
        ),
      );

      await expectLater(
        service.dispatch(
          PluginUiActionParamsDto(
            agentId: 'agent',
            pluginId: 'acme.target',
            action: PluginUiActionDto(
              documentId: rendered.id,
              actionId: 'acme.target/hidden',
            ),
          ),
        ),
        throwsA(isA<PluginUiException>()),
      );
    },
  );

  test('revoking a grant cancels an in-flight UI action primitive', () async {
    final bundle = _pluginBundle(
      id: 'acme.target',
      requestedCapabilities: const <String>['clock.sleep'],
      source: '''
local tinest = require("tinest")
local S = tinest.schema
local wait = tinest.ui.action({
  id = "wait",
  uses = {tinest.host.clock.sleep},
}, S.any(), function(_arguments)
  return tinest.result.unwrap(tinest.host.clock.sleep({milliseconds = 60000}))
end)
local card = tinest.ui.contribution({
  id = "card", slot = tinest.ui.slot.timeline,
}, S.any(), function(_arguments)
  return tinest.ui.button({label = "Wait", action = wait})
end)
return tinest.plugin.define({ui = {card}, actions = {wait}})
''',
    );
    final revisions = PluginRevisionCatalog(
      loader: _MapLoader(<String, PluginBundle>{'acme.target': bundle}),
      cache: _MemoryRevisionCache(),
    );
    final runtime = _runtime(revisions, stagedHost);
    addTearDown(runtime.close);
    const grant = AgentPluginGrantDto(
      agentId: 'agent',
      pluginId: 'acme.target',
      capability: 'clock.sleep',
    );
    final grants = MemoryAgentPluginGrantStore();
    await grants.grant(grant);
    await revisions.reload(
      'acme.target',
      agentId: 'agent',
      approvedCapabilities: const <String>{'clock.sleep'},
      inspector: runtime,
    );
    final host = _BlockingClockUiHost();
    final service = PluginUiService(
      descriptors: _RevisionDescriptorReader(revisions),
      runtime: LuaPluginUiRuntime<Object>(
        runtime: runtime,
        grants: grants,
        state: MemoryPluginStateStore(),
        hostPrimitives: host.primitives,
        definitions: (_) async => _definition(const <String>[]),
      ),
    );
    final rendered = await service.render(
      const PluginUiRenderParamsDto(
        agentId: 'agent',
        pluginId: 'acme.target',
        contributionId: 'acme.target/card',
        slot: PluginUiSlot.timeline,
      ),
    );

    final dispatch = service.dispatch(
      PluginUiActionParamsDto(
        agentId: 'agent',
        pluginId: 'acme.target',
        action: PluginUiActionDto(
          documentId: rendered.id,
          actionId: 'acme.target/wait',
        ),
      ),
    );
    await host.started.future;
    await grants.revoke(grant);

    await expectLater(dispatch, throwsA(isA<PluginUiException>()));
    await expectLater(host.cancelled.future, completes);
  });

  test('runs ui_action hooks serially in Agent extension order', () async {
    final loader = _MapLoader(<String, PluginBundle>{
      'acme.target': _orderedUiBundle(),
      'acme.first': _actionHookBundle('acme.first', 'first'),
      'acme.second': _actionHookBundle('acme.second', 'second'),
    });
    final revisions = PluginRevisionCatalog(
      loader: loader,
      cache: _MemoryRevisionCache(),
    );
    final runtime = _runtime(revisions, stagedHost);
    addTearDown(runtime.close);
    final grants = MemoryAgentPluginGrantStore();
    for (final pluginId in loader.bundles.keys) {
      final capabilities =
          loader.bundles[pluginId]!.revision.requestedCapabilities;
      for (final capability in capabilities) {
        await grants.grant(
          AgentPluginGrantDto(
            agentId: 'agent',
            pluginId: pluginId,
            capability: capability,
          ),
        );
      }
      await revisions.reload(
        pluginId,
        agentId: 'agent',
        approvedCapabilities: capabilities.toSet(),
        inspector: runtime,
      );
    }
    final host = _OrderedUiHost();
    final service = PluginUiService(
      descriptors: _RevisionDescriptorReader(revisions),
      runtime: LuaPluginUiRuntime<Object>(
        runtime: runtime,
        grants: grants,
        state: MemoryPluginStateStore(),
        hostPrimitives: host.primitives,
        definitions: (_) async =>
            _definition(const <String>['acme.first', 'acme.second']),
      ),
    );
    final rendered = await service.render(
      const PluginUiRenderParamsDto(
        agentId: 'agent',
        pluginId: 'acme.target',
        contributionId: 'acme.target/card',
        slot: PluginUiSlot.timeline,
        context: <String, dynamic>{'sessionId': 'session'},
      ),
    );

    final updated = await service.dispatch(
      PluginUiActionParamsDto(
        agentId: 'agent',
        pluginId: 'acme.target',
        action: PluginUiActionDto(
          documentId: rendered.id,
          actionId: 'acme.target/refresh',
        ),
      ),
    );

    expect(updated.root['label'], 'ready');
    expect(host.pluginIds, const <String>['acme.first', 'acme.second']);
  });
}

PluginRuntime<Object> _runtime(
  PluginRevisionCatalog revisions,
  Directory stagedHost,
) => PluginRuntime<Object>(
  luaRuntime: lua.LuaToolRuntime<Object>(
    host: lua.LuaHostCommand.fromDirectory(stagedHost.path),
    processLauncher: const lua.IoLuaHostProcessLauncher(),
    clock: const lua.SystemLuaClock(),
    ids: _Ids(),
  ),
  revisions: revisions,
);

PluginBundle _uiBundle(String revision, String label, {bool invalid = false}) {
  final descriptor = PluginDescriptorDto(
    apiMajor: 5,
    id: 'acme.ui',
    version: '1.0.0',
    name: 'UI',
    entrypoint: 'main.lua',
    source: PluginSource.user,
    sourcePath: 'plugins/acme.ui',
    requestedCapabilities: const <String>[],
    revision: PluginRevisionDto(
      pluginId: 'acme.ui',
      contentHash: revision,
      manifestHash: 'manifest-$revision',
      sdkAbiHash: 'sdk-abi-hash',
      executionRevisionHash: 'execution-$revision',
      requestedCapabilities: const <String>[],
    ),
  );
  final initialDocument = invalid
      ? '{type = "remote-widget", text = "$label"}'
      : 'tinest.ui.text({text = "$label"})';
  return PluginBundle(
    descriptor: descriptor,
    revision: descriptor.revision!,
    assets: <String, Uint8List>{
      'PLUGIN.md': Uint8List.fromList('---\napi: 5\n---'.codeUnits),
      'main.lua': Uint8List.fromList(
        '''
local tinest = require("tinest")
local S = tinest.schema
local refresh = tinest.ui.action({id = "refresh"}, S.object({
  suffix = S.string(),
}), function(arguments)
  if arguments.suffix ~= "action" then error("direct action payload missing") end
  return {text = "$label " .. arguments.suffix}
end)
local card = tinest.ui.contribution({
  id = "card", slot = tinest.ui.slot.timeline,
}, S.any(), function(arguments)
  if $invalid then return $initialDocument end
  return tinest.ui.section({children = {
    $initialDocument,
    tinest.ui.button({label = "Refresh", action = refresh}),
  }})
end)
return tinest.plugin.define({ui = {card}, actions = {refresh}})
'''
            .codeUnits,
      ),
    },
  );
}

AgentDefinitionDto _definition(List<String> extensionIds) => AgentDefinitionDto(
  version: 5,
  id: 'agent',
  name: 'UI Agent',
  description: '',
  mode: AgentMode.primary,
  model: const AgentModelSelectionDto(source: AgentModelSource.session),
  driverId: 'acme.target/driver',
  extensionIds: extensionIds,
  toolIds: const <String>[],
  pluginSettings: const <String, Map<String, dynamic>>{},
  callableAgentIds: const <String>[],
  prompt: '',
  contentHash: 'agent-hash',
  sourcePath: 'agent.md',
);

PluginBundle _uiPrimitiveBundle({
  required String id,
  required String primitive,
  required String capability,
  required String requestedCapability,
  bool declareUse = true,
  bool inspectEnvelope = false,
}) => _pluginBundle(
  id: id,
  requestedCapabilities: <String>[requestedCapability],
  source:
      '''
local tinest = require("tinest")
local S = tinest.schema
local primitive = $primitive
local card = tinest.ui.contribution({
  id = "card",
  slot = tinest.ui.slot.timeline,
  ${declareUse ? 'uses = {primitive},' : ''}
  required_capabilities = {$capability},
}, S.any(), function(_arguments)
  local result = primitive({milliseconds = 0})
  ${inspectEnvelope ? '' : 'result = tinest.result.unwrap(result)'}
  return tinest.ui.text({text = tostring(result.ok)})
end)
return tinest.plugin.define({ui = {card}})
''',
);

PluginBundle _orderedUiBundle() => _pluginBundle(
  id: 'acme.target',
  source: '''
local tinest = require("tinest")
local S = tinest.schema
local refresh = tinest.ui.action({id = "refresh"}, S.any(), function(arguments)
  return arguments
end)
local card = tinest.ui.contribution({
  id = "card", slot = tinest.ui.slot.timeline,
}, S.any(), function(_arguments)
  return tinest.ui.button({label = "ready", action = refresh})
end)
return tinest.plugin.define({ui = {card}, actions = {refresh}})
''',
);

PluginBundle _actionHookBundle(String id, String name) => _pluginBundle(
  id: id,
  requestedCapabilities: const <String>['clock.sleep'],
  source:
      '''
local tinest = require("tinest")
local ui_action = tinest.hook.ui_action({
  id = "ui-action", uses = {tinest.host.clock.sleep},
}, function(_arguments)
  tinest.result.unwrap(tinest.host.clock.sleep({milliseconds = 0}))
  return {name = "$name"}
end)
return tinest.plugin.define({hooks = {ui_action}})
''',
);

PluginBundle _pluginBundle({
  required String id,
  required String source,
  List<String> requestedCapabilities = const <String>[],
}) {
  final descriptor = PluginDescriptorDto(
    apiMajor: 5,
    id: id,
    version: '1.0.0',
    name: id,
    entrypoint: 'main.lua',
    source: PluginSource.user,
    sourcePath: 'plugins/$id',
    requestedCapabilities: requestedCapabilities,
    revision: PluginRevisionDto(
      pluginId: id,
      contentHash: '$id-revision',
      manifestHash: '$id-manifest',
      sdkAbiHash: 'sdk-abi-hash',
      executionRevisionHash: '$id-execution-revision',
      requestedCapabilities: requestedCapabilities,
    ),
  );
  return PluginBundle(
    descriptor: descriptor,
    revision: descriptor.revision!,
    assets: <String, Uint8List>{
      'PLUGIN.md': Uint8List.fromList('---\napi: 5\n---'.codeUnits),
      'main.lua': Uint8List.fromList(source.codeUnits),
    },
  );
}

final class _RevisionDescriptorReader implements PluginDescriptorReader {
  const new(this.revisions);
  final PluginRevisionCatalog revisions;

  @override
  Future<PluginDescriptorDto> get(String id) => revisions.loadInstalled(id);
}

/// Fakes `host.collaboration.list_agents` the way the daemon answers it.
///
/// The real service returns every session of the caller's tree, and the first
/// of those is always the tree root the panel is rendered under, so [agents]
/// keeps that root entry present by default.
HostPrimitiveRegistry _collaborationUiPrimitives({
  List<Map<String, Object?>>? calls,
  List<Map<String, Object?>> agents = const <Map<String, Object?>>[
    <String, Object?>{
      'session_id': 'root-session',
      'agent_name': '/root',
      'agent_status': 'running',
      'session_status': 'running',
      'title': 'Root',
    },
    <String, Object?>{
      'session_id': 'reviewer-session',
      'agent_name': '/root/reviewer',
      'agent_status': 'running',
      'session_status': 'running',
      'title': 'Reviewer',
      'task_name': 'reviewer',
      'parent_session_id': 'root-session',
    },
  ],
}) => HostPrimitiveRegistry(<HostPrimitive<Object?, Object?>>[
  HostPrimitiveContracts.collaborationListAgents
      .bind(
        decode: _object,
        invoke: (arguments, _) {
          calls?.add(Map<String, Object?>.unmodifiable(arguments));
          return <String, Object?>{'agents': agents};
        },
      )
      .erased,
]);

HostPrimitiveRegistry _immediateClockUiPrimitives() =>
    HostPrimitiveRegistry(<HostPrimitive<Object?, Object?>>[
      HostPrimitiveContracts.clockSleep
          .bind(
            decode: _object,
            invoke: (_, _) => const <String, Object?>{'completed': true},
          )
          .erased,
    ]);

final class _BlockingClockUiHost {
  new() {
    primitives = HostPrimitiveRegistry(<HostPrimitive<Object?, Object?>>[
      HostPrimitiveContracts.clockSleep
          .bind(decode: _object, invoke: _sleep)
          .erased,
    ]);
  }

  final Completer<void> started = Completer<void>();
  final Completer<void> cancelled = Completer<void>();
  late final HostPrimitiveRegistry primitives;

  Future<Map<String, Object?>> _sleep(
    Map<String, Object?> arguments,
    HostPrimitiveContext context,
  ) {
    final completion = Completer<Map<String, Object?>>();
    started.complete();
    context.cancellation?.onCancel(() {
      if (!cancelled.isCompleted) cancelled.complete();
      if (!completion.isCompleted) {
        completion.completeError(
          const HostPrimitiveException(
            HostPrimitiveError(
              code: 'cancelled',
              message: 'Clock sleep was cancelled.',
              retryable: false,
            ),
          ),
        );
      }
    });
    return completion.future;
  }
}

final class _OrderedUiHost {
  new() {
    primitives = HostPrimitiveRegistry(<HostPrimitive<Object?, Object?>>[
      HostPrimitiveContracts.clockSleep
          .bind(decode: _object, invoke: _sleep)
          .erased,
    ]);
  }

  final List<String> pluginIds = <String>[];
  late final HostPrimitiveRegistry primitives;

  Future<Map<String, Object?>> _sleep(
    Map<String, Object?> arguments,
    HostPrimitiveContext context,
  ) async {
    pluginIds.add(context.pluginId);
    return const <String, Object?>{'completed': true};
  }
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map<Object?, Object?>) {
    throw const FormatException('Expected an object.');
  }
  return <String, Object?>{
    for (final entry in value.entries) entry.key.toString(): entry.value,
  };
}

final class _MapLoader implements PluginBundleLoader {
  const new(this.bundles);
  final Map<String, PluginBundle> bundles;

  @override
  Future<PluginBundle> load(String id) async => bundles[id]!;
}

final class _MutableLoader implements PluginBundleLoader {
  new(this.bundle);
  PluginBundle bundle;

  @override
  Future<PluginBundle> load(String id) async => bundle;
}

final class _MemoryRevisionCache implements PluginRevisionCache {
  final Map<String, PluginBundle> installed = <String, PluginBundle>{};
  final Map<String, PluginBundle> active = <String, PluginBundle>{};
  final Map<String, PluginBundle> executions = <String, PluginBundle>{};

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
  Future<PluginBundle?> loadInstalled(String id) async => installed[id];

  @override
  Future<PluginBundle?> loadExecutionRevision(
    String id,
    String executionRevisionHash,
  ) async => executions['$id/$executionRevisionHash'];

  @override
  Future<void> storeInstalled(PluginBundle bundle) async {
    installed[bundle.descriptor.id] = bundle;
    executions['${bundle.descriptor.id}/${bundle.revision.executionRevisionHash}'] =
        bundle;
  }
}

final class _Ids implements lua.LuaIdGenerator {
  int _next = 0;

  @override
  String generate() => '${++_next}';
}

Future<String> _cmakeExecutable() async {
  if (!Platform.isWindows) return 'cmake';
  final result = await Process.run('where.exe', <String>['cmake']);
  final candidates = (result.stdout as String)
      .split(RegExp(r'[\r\n]+'))
      .where((line) => line.isNotEmpty);
  if (result.exitCode == 0 && candidates.isNotEmpty) return candidates.first;
  final programFilesX86 = Platform.environment['ProgramFiles(x86)'];
  if (programFilesX86 != null) {
    final vswhere = File(
      '$programFilesX86/Microsoft Visual Studio/Installer/vswhere.exe',
    );
    if (vswhere.existsSync()) {
      final located = await Process.run(vswhere.path, const <String>[
        '-latest',
        '-products',
        '*',
        '-requires',
        'Microsoft.VisualStudio.Component.VC.CMake.Project',
        '-find',
        r'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe',
      ]);
      final candidate = (located.stdout as String).trim();
      if (located.exitCode == 0 && candidate.isNotEmpty) return candidate;
    }
  }
  return 'cmake';
}
