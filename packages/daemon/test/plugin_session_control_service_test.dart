@Tags(<String>[
  'feature_test__plugin_runtime__unit',
  'feature_test__plugin_runtime__contract',
  'feature_test__plugin_runtime__verticalSlice',
])
@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:daemon/src/features/plugins/infrastructure/native_plugin_secret_vault.dart';
import 'package:daemon/src/features/plugins/infrastructure/native_plugin_state_repository.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_bundles.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_ports.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_service.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_session_control_service.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_ui_service.dart';
import 'package:daemon/src/features/plugins/runtime/host_primitive_contracts.dart';
import 'package:daemon/src/features/plugins/runtime/host_primitives.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_runtime.dart';
import 'package:daemon/src/features/plugins/transport/rpc_bindings.dart';
import 'package:daemon/src/transport/rpc/binding.dart';
import 'package:lua_tool_runtime/lua_tool_runtime.dart' as lua;
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'support/temporary_directory.dart';

const Map<String, Object?> _controlBinding = <String, Object?>{
  'kind': 'session_control',
  'id': 'mode',
  'key': '__tinest.session_control.mode',
};

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
      'tinest-plugin-control-host-',
    );
    buildDirectory = await Directory.systemTemp.createTemp(
      'tinest-plugin-control-build-',
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
      await deleteTemporaryDirectory(stagedHost);
      await deleteTemporaryDirectory(buildDirectory);
    }
  });

  test('registration rejects missing schemas and invalid defaults', () {
    const descriptor = PluginDescriptorDto(
      apiMajor: 5,
      id: 'acme.control',
      version: '1.0.0',
      name: 'Control',
      entrypoint: 'main.lua',
      source: PluginSource.user,
      sourcePath: 'plugins/acme.control',
      requestedCapabilities: <String>[],
    );

    expect(
      () => PluginRegistrationParser.parse(
        descriptor: descriptor,
        revisionHash: 'revision',
        value: <String, Object?>{
          'api': 5,
          'spec': <String, Object?>{
            'session_controls': <Object?>[
              <String, Object?>{
                'id': 'mode',
                'binding': _controlBinding,
                'metadata': <String, Object?>{'default': false},
              },
            ],
          },
        },
      ),
      throwsA(
        isA<PluginRegistrationException>().having(
          (error) => error.path,
          'path',
          r'$.session_controls[0].schema',
        ),
      ),
    );
    expect(
      () => PluginRegistrationParser.parse(
        descriptor: descriptor,
        revisionHash: 'revision',
        value: <String, Object?>{
          'api': 5,
          'spec': <String, Object?>{
            'session_controls': <Object?>[
              <String, Object?>{
                'id': 'mode',
                'binding': _controlBinding,
                'schema': <String, Object?>{'type': 'boolean'},
                'metadata': <String, Object?>{'default': 'false'},
              },
            ],
          },
        },
      ),
      throwsA(
        isA<PluginRegistrationException>().having(
          (error) => error.path,
          'path',
          r'$.session_controls[0].metadata.default',
        ),
      ),
    );
  }, tags: const <String>['feature_test__session_plan__unit']);

  test(
    'real tinest.plan handler normalizes and survives runtime restart',
    () async {
      const agentId = 'agent';
      const sessionId = 'session';
      const pluginId = 'tinest.plan';
      const contributionId = 'tinest.plan/mode';
      final now = DateTime.utc(2026, 8, 12);
      final session = SessionDto(
        id: sessionId,
        worktreeId: 'worktree',
        title: 'Plan',
        agentDefinitionId: agentId,
        origin: SessionOrigin.manual,
        status: SessionStatus.idle,
        createdAt: now,
        updatedAt: now,
      );
      final worktree = WorktreeDto(
        id: 'worktree',
        workspaceId: 'workspace',
        name: 'Workspace',
        path: Directory.current.path,
        kind: WorktreeKind.directory,
        isTinestOwned: false,
        createdAt: now,
      );
      const definition = AgentDefinitionDto(
        version: 5,
        id: agentId,
        name: 'Plan Agent',
        description: '',
        mode: AgentMode.primary,
        model: AgentModelSelectionDto(source: AgentModelSource.session),
        driverId: 'tinest.standard/driver',
        extensionIds: <String>[pluginId],
        toolIds: <String>[],
        pluginSettings: <String, Map<String, dynamic>>{},
        callableAgentIds: <String>[],
        prompt: '',
        contentHash: 'agent-revision',
        sourcePath: 'agent.md',
      );
      final cache = _MemoryRevisionCache();
      final stateRoot = await Directory.systemTemp.createTemp(
        'tinest-plan-control-state-',
      );
      addTearDown(() => stateRoot.delete(recursive: true));
      final state = NativePluginStateRepository(stateRoot.path);

      Future<
        ({
          PluginSessionControlService<Object> controls,
          PluginManagementService plugins,
        })
      >
      createService(NativePluginStateRepository repository) async {
        final revisions = PluginRevisionCatalog(
          loader: const BuiltInPluginCatalog(),
          cache: cache,
        );
        final runtime = PluginRuntime<Object>(
          luaRuntime: lua.LuaToolRuntime<Object>(
            host: lua.LuaHostCommand.fromDirectory(stagedHost.path),
            processLauncher: const lua.IoLuaHostProcessLauncher(),
            clock: const lua.SystemLuaClock(),
            ids: _Ids(),
          ),
          revisions: revisions,
        );
        addTearDown(runtime.close);
        final plugins = PluginManagementService(
          sources: const _SourceCatalog(<String>[pluginId]),
          revisions: revisions,
          grants: repository,
          inspector: runtime,
        );
        return (
          controls: PluginSessionControlService<Object>(
            plugins: plugins,
            runtime: runtime,
            state: repository,
            sessions: (id) async => id == sessionId ? session : null,
            definitions: (id) async {
              if (id != agentId) throw StateError('unexpected Agent: $id');
              return definition;
            },
            worktrees: (id) async => id == worktree.id ? worktree : null,
          ),
          plugins: plugins,
        );
      }

      final first = await createService(state);
      final initial = await first.controls.get(
        const PluginSessionControlParamsDto(
          sessionId: sessionId,
          pluginId: pluginId,
          contributionId: contributionId,
        ),
      );
      expect(initial.value, isFalse);
      expect(initial.defaultValue, isFalse);
      expect(initial.isDefault, isTrue);
      expect(initial.agentId, agentId);

      await expectLater(
        first.controls.set(
          const PluginSessionControlSetParamsDto(
            sessionId: sessionId,
            pluginId: pluginId,
            contributionId: contributionId,
            value: 'true',
          ),
        ),
        throwsA(isA<PluginSessionControlException>()),
      );
      expect(
        (await first.controls.get(
          const PluginSessionControlParamsDto(
            sessionId: sessionId,
            pluginId: pluginId,
            contributionId: contributionId,
          ),
        )).value,
        isFalse,
      );

      final enabled = await first.controls.set(
        const PluginSessionControlSetParamsDto(
          sessionId: sessionId,
          pluginId: pluginId,
          contributionId: contributionId,
          value: true,
        ),
      );
      expect(enabled.value, isTrue);
      expect(enabled.isDefault, isFalse);

      final restartedState = NativePluginStateRepository(stateRoot.path);
      final restarted = await createService(restartedState);
      final recovered = await restarted.controls.get(
        const PluginSessionControlParamsDto(
          sessionId: sessionId,
          pluginId: pluginId,
          contributionId: contributionId,
        ),
      );
      expect(recovered.value, isTrue);
      expect(recovered.revisionHash, enabled.revisionHash);
      expect(recovered.isDefault, isFalse);
      expect(
        await restarted.controls.valuesForTurn(
          session: session,
          definition: definition,
          worktree: worktree,
        ),
        <String, Object?>{contributionId: true},
      );

      await expectLater(
        restarted.controls.get(
          const PluginSessionControlParamsDto(
            sessionId: sessionId,
            pluginId: 'tinest.goal',
            contributionId: 'tinest.goal/mode',
          ),
        ),
        throwsA(isA<PluginSessionControlException>()),
      );
      await expectLater(
        restarted.controls.get(
          const PluginSessionControlParamsDto(
            sessionId: sessionId,
            pluginId: pluginId,
            contributionId: 'tinest.goal/mode',
          ),
        ),
        throwsA(isA<PluginSessionControlException>()),
      );

      final bindings = pluginRpcBindings<Object>(
        plugins: restarted.plugins,
        sessionControls: restarted.controls,
        ui: PluginUiService(
          descriptors: restarted.plugins,
          runtime: const ManifestPluginUiRuntime(),
        ),
        secrets: NativePluginSecretVault(stateRoot.path),
      );
      RpcBindingDescriptor binding(RpcProcedureDescriptor procedure) =>
          bindings.singleWhere(
            (candidate) => candidate.procedure.name == procedure.name,
          );
      final context = RpcConnectionContext();
      final getWire = await binding(pluginsGetSessionControlProcedure).invoke(
        const PluginSessionControlParamsDto(
          sessionId: sessionId,
          pluginId: pluginId,
          contributionId: contributionId,
        ).toJson(),
        context,
      );
      expect(
        PluginSessionControlResultDto.fromJson(
          jsonDecode(jsonEncode(getWire)) as Map<String, dynamic>,
        ).control.value,
        isTrue,
      );
      final setWire = await binding(pluginsSetSessionControlProcedure).invoke(
        const PluginSessionControlSetParamsDto(
          sessionId: sessionId,
          pluginId: pluginId,
          contributionId: contributionId,
          value: false,
        ).toJson(),
        context,
      );
      expect(
        PluginSessionControlResultDto.fromJson(
          jsonDecode(jsonEncode(setWire)) as Map<String, dynamic>,
        ).control.value,
        isFalse,
      );
      expect(
        File(
          '${stateRoot.path}${Platform.pathSeparator}v5'
          '${Platform.pathSeparator}plugin-state.json',
        ).existsSync(),
        isTrue,
      );
    },
    tags: const <String>[
      'feature_test__session_plan__contract',
      'feature_test__session_plan__verticalSlice',
    ],
  );

  test('session-control handlers use only scoped state callbacks', () async {
    const agentId = 'agent';
    const sessionId = 'session';
    const pluginId = 'acme.controls';
    const contributionId = 'acme.controls/mode';
    final now = DateTime.utc(2026, 8, 12);
    final session = SessionDto(
      id: sessionId,
      worktreeId: 'worktree',
      title: 'Control',
      agentDefinitionId: agentId,
      origin: SessionOrigin.manual,
      status: SessionStatus.idle,
      createdAt: now,
      updatedAt: now,
    );
    final worktree = WorktreeDto(
      id: 'worktree',
      workspaceId: 'workspace',
      name: 'Workspace',
      path: Directory.current.path,
      kind: WorktreeKind.directory,
      isTinestOwned: false,
      createdAt: now,
    );
    const definition = AgentDefinitionDto(
      version: 5,
      id: agentId,
      name: 'Control Agent',
      description: '',
      mode: AgentMode.primary,
      model: AgentModelSelectionDto(source: AgentModelSource.session),
      driverId: 'tinest.standard/driver',
      extensionIds: <String>[pluginId],
      toolIds: <String>[],
      pluginSettings: <String, Map<String, dynamic>>{},
      callableAgentIds: <String>[],
      prompt: '',
      contentHash: 'agent-revision',
      sourcePath: 'agent.md',
    );
    final bundle = _sessionControlBundle();
    final revisions = PluginRevisionCatalog(
      loader: _SingleBundleLoader(bundle),
      cache: _MemoryRevisionCache(),
    );
    final runtime = PluginRuntime<Object>(
      luaRuntime: lua.LuaToolRuntime<Object>(
        host: lua.LuaHostCommand.fromDirectory(stagedHost.path),
        processLauncher: const lua.IoLuaHostProcessLauncher(),
        clock: const lua.SystemLuaClock(),
        ids: _Ids(),
      ),
      revisions: revisions,
    );
    addTearDown(runtime.close);
    final stateRoot = await Directory.systemTemp.createTemp(
      'tinest-custom-control-state-',
    );
    addTearDown(() => stateRoot.delete(recursive: true));
    final state = NativePluginStateRepository(stateRoot.path);
    for (final capability in bundle.descriptor.requestedCapabilities) {
      await state.grant(
        AgentPluginGrantDto(
          agentId: agentId,
          pluginId: pluginId,
          capability: capability,
        ),
      );
    }
    final plugins = PluginManagementService(
      sources: const _SourceCatalog(<String>[pluginId]),
      revisions: revisions,
      grants: state,
      inspector: runtime,
    );
    final controls = PluginSessionControlService<Object>(
      plugins: plugins,
      runtime: runtime,
      state: state,
      sessions: (id) async => id == sessionId ? session : null,
      definitions: (_) async => definition,
      worktrees: (id) async => id == worktree.id ? worktree : null,
    );

    final values = await Future.wait(<Future<PluginSessionControlValueDto>>[
      controls.set(
        const PluginSessionControlSetParamsDto(
          sessionId: sessionId,
          pluginId: pluginId,
          contributionId: contributionId,
          value: true,
        ),
      ),
      controls.set(
        const PluginSessionControlSetParamsDto(
          sessionId: sessionId,
          pluginId: pluginId,
          contributionId: contributionId,
          value: false,
        ),
      ),
    ]);
    expect(values.map((value) => value.value), <Object?>[true, false]);
    expect(
      (await controls.get(
        const PluginSessionControlParamsDto(
          sessionId: sessionId,
          pluginId: pluginId,
          contributionId: contributionId,
        ),
      )).value,
      isFalse,
    );
    for (final scope in <PluginStateScope>[
      const PluginStateScope.plugin(pluginId: pluginId),
      const PluginStateScope.agent(pluginId: pluginId, agentId: agentId),
      const PluginStateScope.session(pluginId: pluginId, sessionId: sessionId),
      const PluginStateScope.workspace(
        pluginId: pluginId,
        workspaceId: 'workspace',
      ),
    ]) {
      expect(
        await state.read(scope, 'seen'),
        isNotNull,
        reason: scope.kind.name,
      );
    }

    final uiHost = _UiHost();
    final ui = PluginUiService(
      descriptors: plugins,
      runtime: LuaPluginUiRuntime<Object>(
        runtime: runtime,
        grants: state,
        state: state,
        definitions: (_) async => definition,
        hostPrimitives: uiHost.primitives,
      ),
    );
    final rendered = await ui.render(
      const PluginUiRenderParamsDto(
        agentId: agentId,
        pluginId: pluginId,
        contributionId: 'acme.controls/card',
        slot: PluginUiSlot.timeline,
        context: <String, dynamic>{
          'sessionId': sessionId,
          'workspaceId': 'workspace',
        },
        input: <String, dynamic>{'event': 'render'},
      ),
    );
    expect(_uiText(rendered.root), 'render:2026-08-12T00:00:00.000Z');
    final dispatched = await ui.dispatch(
      PluginUiActionParamsDto(
        agentId: agentId,
        pluginId: pluginId,
        action: PluginUiActionDto(
          documentId: rendered.id,
          actionId: 'acme.controls/refresh',
          data: <String, dynamic>{'action_id': 'acme.controls/refresh'},
        ),
      ),
    );
    expect(_uiText(dispatched.root), 'action:acme.controls/refresh');
    expect(uiHost.operations, <String>[
      'host.clock.current_time',
      'host.clock.current_time',
    ]);

    const clockGrant = AgentPluginGrantDto(
      agentId: agentId,
      pluginId: pluginId,
      capability: 'clock.read',
    );
    await state.revoke(clockGrant);
    await expectLater(
      ui.dispatch(
        PluginUiActionParamsDto(
          agentId: agentId,
          pluginId: pluginId,
          action: PluginUiActionDto(
            documentId: rendered.id,
            actionId: 'acme.controls/denied',
            data: <String, dynamic>{'action_id': 'acme.controls/denied'},
          ),
        ),
      ),
      throwsA(isA<PluginUiException>()),
    );
    await state.grant(clockGrant);

    const stateWriteGrant = AgentPluginGrantDto(
      agentId: agentId,
      pluginId: pluginId,
      capability: 'state.write',
    );
    await state.revoke(stateWriteGrant);
    await expectLater(
      controls.set(
        const PluginSessionControlSetParamsDto(
          sessionId: sessionId,
          pluginId: pluginId,
          contributionId: contributionId,
          value: true,
        ),
      ),
      throwsA(
        isA<PluginSessionControlException>().having(
          (failure) => failure.toString(),
          'message',
          contains('state.write'),
        ),
      ),
    );

    await expectLater(
      controls.get(
        const PluginSessionControlParamsDto(
          sessionId: 'missing',
          pluginId: pluginId,
          contributionId: contributionId,
        ),
      ),
      throwsA(isA<PluginSessionControlException>()),
    );
    final wrongOwner = PluginSessionControlService<Object>(
      plugins: plugins,
      runtime: runtime,
      state: state,
      sessions: (_) async => session,
      definitions: (_) async => definition.copyWith(id: 'other-agent'),
      worktrees: (_) async => worktree,
    );
    await expectLater(
      wrongOwner.get(
        const PluginSessionControlParamsDto(
          sessionId: sessionId,
          pluginId: pluginId,
          contributionId: contributionId,
        ),
      ),
      throwsA(isA<PluginSessionControlException>()),
    );
    final noWorktree = PluginSessionControlService<Object>(
      plugins: plugins,
      runtime: runtime,
      state: state,
      sessions: (_) async => session,
      definitions: (_) async => definition,
      worktrees: (_) async => null,
    );
    await expectLater(
      noWorktree.get(
        const PluginSessionControlParamsDto(
          sessionId: sessionId,
          pluginId: pluginId,
          contributionId: contributionId,
        ),
      ),
      throwsA(isA<PluginSessionControlException>()),
    );
  });

  test(
    'session-control state cells reject malformed persisted values',
    () async {
      const agentId = 'agent';
      const sessionId = 'session';
      const pluginId = 'acme.controlschema';
      const contributionId = '$pluginId/mode';
      final now = DateTime.utc(2026, 8, 12);
      final session = SessionDto(
        id: sessionId,
        worktreeId: 'worktree',
        title: 'Control schema',
        agentDefinitionId: agentId,
        origin: SessionOrigin.manual,
        status: SessionStatus.idle,
        createdAt: now,
        updatedAt: now,
      );
      final worktree = WorktreeDto(
        id: 'worktree',
        workspaceId: 'workspace',
        name: 'Workspace',
        path: Directory.current.path,
        kind: WorktreeKind.directory,
        isTinestOwned: false,
        createdAt: now,
      );
      const definition = AgentDefinitionDto(
        version: 5,
        id: agentId,
        name: 'Control schema Agent',
        description: '',
        mode: AgentMode.primary,
        model: AgentModelSelectionDto(source: AgentModelSource.session),
        driverId: 'tinest.standard/driver',
        extensionIds: <String>[pluginId],
        toolIds: <String>[],
        pluginSettings: <String, Map<String, dynamic>>{},
        callableAgentIds: <String>[],
        prompt: '',
        contentHash: 'agent-revision',
        sourcePath: 'agent.md',
      );
      final bundle = _sessionControlStateSchemaBundle();
      final revisions = PluginRevisionCatalog(
        loader: _SingleBundleLoader(bundle),
        cache: _MemoryRevisionCache(),
      );
      final runtime = PluginRuntime<Object>(
        luaRuntime: lua.LuaToolRuntime<Object>(
          host: lua.LuaHostCommand.fromDirectory(stagedHost.path),
          processLauncher: const lua.IoLuaHostProcessLauncher(),
          clock: const lua.SystemLuaClock(),
          ids: _Ids(),
        ),
        revisions: revisions,
      );
      addTearDown(runtime.close);
      final stateRoot = await Directory.systemTemp.createTemp(
        'tinest-control-schema-state-',
      );
      addTearDown(() => stateRoot.delete(recursive: true));
      final state = NativePluginStateRepository(stateRoot.path);
      await state.grant(
        const AgentPluginGrantDto(
          agentId: agentId,
          pluginId: pluginId,
          capability: 'state.read',
        ),
      );
      await state.compareAndSet(
        const PluginStateScope.session(
          pluginId: pluginId,
          sessionId: sessionId,
        ),
        'typed',
        expectedRevision: 0,
        value: 42,
      );
      final plugins = PluginManagementService(
        sources: const _SourceCatalog(<String>[pluginId]),
        revisions: revisions,
        grants: state,
        inspector: runtime,
      );
      final controls = PluginSessionControlService<Object>(
        plugins: plugins,
        runtime: runtime,
        state: state,
        sessions: (id) async => id == sessionId ? session : null,
        definitions: (_) async => definition,
        worktrees: (id) async => id == worktree.id ? worktree : null,
      );

      await expectLater(
        controls.set(
          const PluginSessionControlSetParamsDto(
            sessionId: sessionId,
            pluginId: pluginId,
            contributionId: contributionId,
            value: true,
          ),
        ),
        throwsA(isA<PluginSessionControlException>()),
      );
    },
  );
}

PluginBundle _sessionControlBundle() {
  const id = 'acme.controls';
  const capabilities = <String>[
    'state.read',
    'state.write',
    'model.call',
    'ui.publish',
    'clock.read',
  ];
  const source = '''
local tinest = require("tinest")
local S = tinest.schema
local T = require("tinest.types")

local UiInput = S.object(T.UiInput, {
  event = S.string(),
})
local UiActionInput = S.object(T.UiActionInput, {
  action_id = S.string(),
})

local function cell(scope, key)
  return tinest.state.cell({scope = scope, key = key}, S.any())
end
local plugin_seen = cell(tinest.state.scope.plugin, "seen")
local agent_seen = cell(tinest.state.scope.agent, "seen")
local session_seen = cell(tinest.state.scope.session, "seen")
local workspace_seen = cell(tinest.state.scope.workspace, "seen")
local removable_state = cell(tinest.state.scope.session, "remove-me")
local transaction_state = cell(tinest.state.scope.session, "tx")
local action_state = cell(tinest.state.scope.session, "action")
local plugin_ui = cell(tinest.state.scope.plugin, "ui")
local agent_ui = cell(tinest.state.scope.agent, "ui")
local session_ui = cell(tinest.state.scope.session, "ui")
local workspace_ui = cell(tinest.state.scope.workspace, "ui")
local ui_removable = cell(tinest.state.scope.session, "ui-remove")
local ui_transaction = cell(tinest.state.scope.session, "ui-transaction")

local function put(target, value)
  local current = target:read()
  return target:compare_and_set(current.revision or 0, value)
end

local function observe_action(arguments)
  local current = action_state:read()
  action_state:compare_and_set(
    current.revision or 0,
    arguments.action_id
  )
  return {action_id = arguments.action_id}
end
local refresh = tinest.ui.action({
  id = "refresh",
  required_capabilities = {
    tinest.capability.state.read,
    tinest.capability.state.write,
  },
}, UiActionInput, observe_action)
local denied = tinest.ui.action({
  id = "denied",
  required_capabilities = {
    tinest.capability.state.read,
    tinest.capability.state.write,
  },
}, UiActionInput, observe_action)

local card
card = tinest.ui.contribution({
  id = "card",
  slot = tinest.ui.slot.timeline,
  uses = {tinest.host.clock.current_time},
  required_capabilities = {
    tinest.capability.state.read,
    tinest.capability.state.write,
    tinest.capability.ui.publish,
  },
}, UiInput, function(arguments)
  put(plugin_ui, arguments.event)
  put(agent_ui, arguments.event)
  put(session_ui, arguments.event)
  put(workspace_ui, arguments.event)
  local removable = put(ui_removable, true)
  local transaction = ui_transaction:read()
  ui_transaction:transaction({
    {
      key = "ui-transaction",
      expected_revision = transaction.revision or 0,
      value = arguments.event,
    },
    {
      key = "ui-remove", expected_revision = removable.revision,
      remove = true,
    },
  })
  tinest.ui.status(card, {message = arguments.event})
  local clock = tinest.result.unwrap(tinest.host.clock.current_time({}))
  local text = arguments.event .. ":" .. clock.now
  local action = action_state:read()
  if action.found == true then
    text = "action:" .. tostring(action.value)
  end
  return tinest.ui.section({children = {
    tinest.ui.text({text = text}),
    tinest.ui.button({
      label = "Refresh",
      action = refresh,
      data = {action_id = "acme.controls/refresh"},
    }),
    tinest.ui.button({
      label = "Denied",
      action = denied,
      data = {action_id = "acme.controls/denied"},
    }),
  }})
end)

local mode = tinest.session.control({
  id = "mode",
  metadata = {default = false},
  required_capabilities = {
    tinest.capability.state.read,
    tinest.capability.state.write,
    tinest.capability.model.call,
    tinest.capability.ui.publish,
  },
}, S.boolean(), function(arguments)
  put(plugin_seen, arguments.value)
  put(agent_seen, arguments.value)
  put(session_seen, arguments.value)
  put(workspace_seen, arguments.value)
  local removable = put(removable_state, true)
  removable_state:remove(removable.revision)
  local transaction = transaction_state:read()
  transaction_state:transaction({
    {
      key = "tx", expected_revision = transaction.revision or 0,
      value = arguments.value,
    },
  })
  local allowed = pcall(function()
    tinest.ui.toast(card, {message = "not allowed"})
  end)
  if allowed then error("UI unexpectedly allowed") end
  local stream = tinest.model.open({blocks = {}, history = {}, tools = {}})
  tinest.model.next(stream)
  tinest.model.close(stream)
  return arguments.value
end)

return tinest.plugin.define({
  session_controls = {mode},
  ui = {card},
  actions = {refresh, denied},
})
''';
  const descriptor = PluginDescriptorDto(
    apiMajor: 5,
    id: id,
    version: '1.0.0',
    name: 'Controls',
    entrypoint: 'main.lua',
    source: PluginSource.user,
    sourcePath: 'plugins/acme.controls',
    requestedCapabilities: capabilities,
    revision: PluginRevisionDto(
      pluginId: id,
      contentHash: 'controls-revision',
      manifestHash: 'controls-manifest',
      sdkAbiHash: 'sdk-abi-hash',
      executionRevisionHash: 'controls-execution-revision',
      requestedCapabilities: capabilities,
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

PluginBundle _sessionControlStateSchemaBundle() {
  const id = 'acme.controlschema';
  const capabilities = <String>['state.read'];
  const descriptor = PluginDescriptorDto(
    apiMajor: 5,
    id: id,
    version: '1.0.0',
    name: 'Control state schema',
    entrypoint: 'main.lua',
    source: PluginSource.user,
    sourcePath: 'plugins/$id',
    requestedCapabilities: capabilities,
    revision: PluginRevisionDto(
      pluginId: id,
      contentHash: 'control-state-schema-revision',
      manifestHash: 'control-state-schema-manifest',
      sdkAbiHash: 'sdk-abi-hash',
      executionRevisionHash: 'control-state-schema-execution',
      requestedCapabilities: capabilities,
    ),
  );
  return PluginBundle(
    descriptor: descriptor,
    revision: descriptor.revision!,
    assets: <String, Uint8List>{
      'PLUGIN.md': Uint8List.fromList('---\napi: 5\n---'.codeUnits),
      'main.lua': Uint8List.fromList(
        '''
local tinest = require("tinest")
local S = tinest.schema
local typed_state = tinest.state.cell({
  scope = tinest.state.scope.session, key = "typed",
}, S.string())
local mode = tinest.session.control({
  id = "mode",
  metadata = {default = false},
  required_capabilities = {tinest.capability.state.read},
}, S.boolean(), function(arguments)
  typed_state:read()
  return arguments.value
end)
return tinest.plugin.define({session_controls = {mode}})
'''
            .codeUnits,
      ),
    },
  );
}

final class _SingleBundleLoader implements PluginBundleLoader {
  const new(this.bundle);

  final PluginBundle bundle;

  @override
  Future<PluginBundle> load(String id) async {
    if (id != bundle.descriptor.id) throw StateError('Plugin not found: $id');
    return bundle;
  }
}

final class _UiHost {
  new() {
    primitives = HostPrimitiveRegistry(<HostPrimitive<Object?, Object?>>[
      HostPrimitiveContracts.clockCurrentTime
          .bind(decode: _object, invoke: _currentTime)
          .erased,
    ]);
  }

  final List<String> operations = <String>[];
  late final HostPrimitiveRegistry primitives;

  Future<Map<String, Object?>> _currentTime(
    Map<String, Object?> arguments,
    HostPrimitiveContext context,
  ) async {
    operations.add(HostPrimitiveContracts.clockCurrentTime.operation);
    return const <String, Object?>{'now': '2026-08-12T00:00:00.000Z'};
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
  final Map<String, PluginBundle> _active = <String, PluginBundle>{};
  final Map<String, PluginBundle> _executions = <String, PluginBundle>{};

  @override
  Future<void> activateForAgent(String agentId, PluginBundle bundle) async {
    _active['$agentId/${bundle.descriptor.id}'] = bundle;
    _executions['${bundle.descriptor.id}/${bundle.revision.executionRevisionHash}'] =
        bundle;
  }

  @override
  Future<PluginBundle?> loadForAgent(String agentId, String id) async =>
      _active['$agentId/$id'];

  @override
  Future<PluginBundle?> loadInstalled(String id) async => _installed[id];

  @override
  Future<PluginBundle?> loadExecutionRevision(
    String id,
    String executionRevisionHash,
  ) async => _executions['$id/$executionRevisionHash'];

  @override
  Future<void> storeInstalled(PluginBundle bundle) async {
    _installed[bundle.descriptor.id] = bundle;
    _executions['${bundle.descriptor.id}/${bundle.revision.executionRevisionHash}'] =
        bundle;
  }
}

final class _Ids implements lua.LuaIdGenerator {
  int _next = 0;

  @override
  String generate() => '${++_next}';
}

Object? _uiText(Map<String, dynamic> root) {
  final children = root['children']! as List<Object?>;
  return (children.first! as Map<String, dynamic>)['text'];
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
