@Tags(<String>['feature_test__plugin_runtime__unit'])
@Timeout(Duration(minutes: 2))
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:daemon/src/features/plugins/infrastructure/memory_plugin_stores.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_bundles.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_ports.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_execution_lifecycle.dart';
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
      'tinest-plugin-lifecycle-host-',
    );
    buildDirectory = await Directory.systemTemp.createTemp(
      'tinest-plugin-lifecycle-build-',
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

  test(
    'opens once, switches revision at a turn boundary, and closes idempotently',
    () async {
      final loader = _MutableLoader(_bundle('revision-one', 'one'));
      final revisions = PluginRevisionCatalog(
        loader: loader,
        cache: _MemoryRevisionCache(),
      );
      final runtime = _runtime(stagedHost, revisions);
      addTearDown(runtime.close);
      final state = MemoryPluginStateStore();
      await revisions.reload(
        'acme.lifecycle',
        agentId: 'agent',
        approvedCapabilities: const <String>{'state.read', 'state.write'},
        inspector: runtime,
      );
      final registry = PluginExecutionLifecycleRegistry<Object>(
        runtime: runtime,
        state: state,
      );
      final first = _request('agent-hash-one');

      await registry.enter(first);
      await registry.enter(first);
      expect(await _events(state), <String>['one:attach', 'one:open']);

      loader.bundle = _bundle('revision-two', 'two');
      await revisions.reload(
        'acme.lifecycle',
        agentId: 'agent',
        approvedCapabilities: const <String>{'state.read', 'state.write'},
        inspector: runtime,
      );
      await registry.enter(_request('agent-hash-two'));
      expect(await _events(state), <String>[
        'one:attach',
        'one:open',
        'one:close',
        'one:detach',
        'two:attach',
        'two:open',
      ]);

      await registry.close();
      await registry.close();
      expect(await _events(state), <String>[
        'one:attach',
        'one:open',
        'one:close',
        'one:detach',
        'two:attach',
        'two:open',
        'two:close',
        'two:detach',
      ]);
    },
  );

  test(
    'attach errors fail the boundary and do not retain an open entry',
    () async {
      final loader = _MutableLoader(
        _bundle('bad-revision', 'bad', failAttach: true),
      );
      final revisions = PluginRevisionCatalog(
        loader: loader,
        cache: _MemoryRevisionCache(),
      );
      final runtime = _runtime(stagedHost, revisions);
      addTearDown(runtime.close);
      final state = MemoryPluginStateStore();
      await revisions.reload(
        'acme.lifecycle',
        agentId: 'agent',
        approvedCapabilities: const <String>{'state.read', 'state.write'},
        inspector: runtime,
      );
      final registry = PluginExecutionLifecycleRegistry<Object>(
        runtime: runtime,
        state: state,
      );

      await expectLater(
        registry.enter(_request('bad-hash')),
        throwsA(isA<StateError>()),
      );
      loader.bundle = _bundle('good-revision', 'good');
      await revisions.reload(
        'acme.lifecycle',
        agentId: 'agent',
        approvedCapabilities: const <String>{'state.read', 'state.write'},
        inspector: runtime,
      );
      await registry.enter(_request('good-hash'));
      await registry.close();
      expect(
        await _events(state),
        containsAllInOrder(<String>[
          'good:attach',
          'good:open',
          'good:close',
          'good:detach',
        ]),
      );
    },
  );

  test(
    'close errors propagate after detach and close remains idempotent',
    () async {
      final loader = _MutableLoader(
        _bundle('close-error-revision', 'closing', failClose: true),
      );
      final revisions = PluginRevisionCatalog(
        loader: loader,
        cache: _MemoryRevisionCache(),
      );
      final runtime = _runtime(stagedHost, revisions);
      addTearDown(runtime.close);
      final state = MemoryPluginStateStore();
      await revisions.reload(
        'acme.lifecycle',
        agentId: 'agent',
        approvedCapabilities: const <String>{'state.read', 'state.write'},
        inspector: runtime,
      );
      final registry = PluginExecutionLifecycleRegistry<Object>(
        runtime: runtime,
        state: state,
      );

      await registry.enter(_request('close-error-hash'));
      await expectLater(registry.close(), throwsA(isA<StateError>()));
      await registry.close();
      expect(await _events(state), <String>[
        'closing:attach',
        'closing:open',
        'closing:detach',
      ]);
    },
  );

  test('lifecycle state cells reject malformed persisted values', () async {
    final loader = _MutableLoader(_bundle('schema-revision', 'schema'));
    final revisions = PluginRevisionCatalog(
      loader: loader,
      cache: _MemoryRevisionCache(),
    );
    final runtime = _runtime(stagedHost, revisions);
    addTearDown(runtime.close);
    final state = MemoryPluginStateStore();
    await state.compareAndSet(
      const PluginStateScope.session(
        pluginId: 'acme.lifecycle',
        sessionId: 'session',
      ),
      'events',
      expectedRevision: 0,
      value: 'not-an-array',
    );
    await revisions.reload(
      'acme.lifecycle',
      agentId: 'agent',
      approvedCapabilities: const <String>{'state.read', 'state.write'},
      inspector: runtime,
    );
    final registry = PluginExecutionLifecycleRegistry<Object>(
      runtime: runtime,
      state: state,
    );

    await expectLater(
      registry.enter(_request('schema-hash')),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'lifecycle state cells enforce scoped transactions and removal',
    () async {
      final loader = _MutableLoader(_stateOperationsBundle());
      final revisions = PluginRevisionCatalog(
        loader: loader,
        cache: _MemoryRevisionCache(),
      );
      final runtime = _runtime(stagedHost, revisions);
      addTearDown(runtime.close);
      final state = MemoryPluginStateStore();
      await revisions.reload(
        'acme.lifecycle',
        agentId: 'agent',
        approvedCapabilities: const <String>{'state.read', 'state.write'},
        inspector: runtime,
      );
      final registry = PluginExecutionLifecycleRegistry<Object>(
        runtime: runtime,
        state: state,
      );

      await registry.enter(
        _request('state-operations', workspaceId: 'workspace'),
      );
      await registry.close();

      expect(
        await state.read(
          const PluginStateScope.session(
            pluginId: 'acme.lifecycle',
            sessionId: 'session',
          ),
          'first',
        ),
        isNull,
      );
      expect(
        (await state.read(
          const PluginStateScope.session(
            pluginId: 'acme.lifecycle',
            sessionId: 'session',
          ),
          'second',
        ))?.value,
        <Object?>['second'],
      );
      expect(
        (await state.read(
          const PluginStateScope.plugin(pluginId: 'acme.lifecycle'),
          'plugin',
        ))?.value,
        <Object?>['plugin'],
      );
      expect(
        (await state.read(
          const PluginStateScope.agent(
            pluginId: 'acme.lifecycle',
            agentId: 'agent',
          ),
          'agent',
        ))?.value,
        <Object?>['agent'],
      );
      expect(
        (await state.read(
          const PluginStateScope.workspace(
            pluginId: 'acme.lifecycle',
            workspaceId: 'workspace',
          ),
          'workspace',
        ))?.value,
        <Object?>['workspace'],
      );
    },
  );
}

PluginExecutionLifecycleRequest _request(
  String contentHash, {
  String? workspaceId,
}) => PluginExecutionLifecycleRequest(
  definition: AgentDefinitionDto(
    version: 5,
    id: 'agent',
    name: 'Agent',
    description: '',
    mode: AgentMode.primary,
    model: const AgentModelSelectionDto(source: AgentModelSource.session),
    driverId: 'acme.lifecycle/driver',
    extensionIds: const <String>['acme.lifecycle'],
    toolIds: const <String>[],
    pluginSettings: const <String, Map<String, dynamic>>{},
    callableAgentIds: const <String>[],
    prompt: '',
    contentHash: contentHash,
    sourcePath: 'agent.md',
  ),
  sessionId: 'session',
  workspaceId: workspaceId,
  workingDirectory: '.',
  allowedCapabilitiesByPlugin: const <String, Set<String>>{
    'acme.lifecycle': <String>{'state.read', 'state.write'},
  },
);

PluginBundle _stateOperationsBundle() {
  const descriptor = PluginDescriptorDto(
    apiMajor: 5,
    id: 'acme.lifecycle',
    version: '1.0.0',
    name: 'Lifecycle state operations',
    entrypoint: 'main.lua',
    source: PluginSource.user,
    sourcePath: 'plugins/acme.lifecycle',
    requestedCapabilities: <String>['state.read', 'state.write'],
    revision: PluginRevisionDto(
      pluginId: 'acme.lifecycle',
      contentHash: 'state-operations',
      manifestHash: 'state-operations-manifest',
      sdkAbiHash: 'sdk-abi-hash',
      executionRevisionHash: 'execution-state-operations',
      requestedCapabilities: <String>['state.read', 'state.write'],
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
local function cell(scope, key)
  return tinest.state.cell({scope = scope, key = key}, S.array(S.string()))
end
local first = cell(tinest.state.scope.session, "first")
local plugin = cell(tinest.state.scope.plugin, "plugin")
local agent = cell(tinest.state.scope.agent, "agent")
local workspace = cell(tinest.state.scope.workspace, "workspace")
local attach = tinest.hook.agent_attach({
  id = "attach",
  required_capabilities = {
    tinest.capability.state.read,
    tinest.capability.state.write,
  },
}, function(_arguments)
  first:compare_and_set(0, {"first"})
  local current = first:read()
  first:transaction({
    {key = "first", expected_revision = current.revision, remove = true},
    {key = "second", expected_revision = 0, value = {"second"}},
  })
  first:remove(0)
  plugin:compare_and_set(0, {"plugin"})
  agent:compare_and_set(0, {"agent"})
  workspace:compare_and_set(0, {"workspace"})
  tinest.model.open({blocks = {}})
  return {}
end)
return tinest.plugin.define({hooks = {attach}})
'''
            .codeUnits,
      ),
    },
  );
}

Future<List<String>> _events(MemoryPluginStateStore state) async {
  final entry = await state.read(
    const PluginStateScope.session(
      pluginId: 'acme.lifecycle',
      sessionId: 'session',
    ),
    'events',
  );
  return entry == null
      ? <String>[]
      : List<String>.from(entry.value! as List<Object?>);
}

PluginBundle _bundle(
  String revision,
  String label, {
  bool failAttach = false,
  bool failClose = false,
}) {
  final descriptor = PluginDescriptorDto(
    apiMajor: 5,
    id: 'acme.lifecycle',
    version: '1.0.0',
    name: 'Lifecycle',
    entrypoint: 'main.lua',
    source: PluginSource.user,
    sourcePath: 'plugins/acme.lifecycle',
    requestedCapabilities: const <String>['state.read', 'state.write'],
    revision: PluginRevisionDto(
      pluginId: 'acme.lifecycle',
      contentHash: revision,
      manifestHash: 'manifest-$revision',
      sdkAbiHash: 'sdk-abi-hash',
      executionRevisionHash: 'execution-$revision',
      requestedCapabilities: const <String>['state.read', 'state.write'],
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
local events_state = tinest.state.cell({
  scope = tinest.state.scope.session,
  key = "events",
}, S.array(S.string()))
local hook_capabilities = {
  tinest.capability.state.read,
  tinest.capability.state.write,
}
local function append(value)
  local current = events_state:read()
  local events = {}
  if type(current) == "table" and current.found == true and
      type(current.value) == "table" then
    events = current.value
  end
  table.insert(events, "$label:" .. value)
  local revision = 0
  if type(current) == "table" then revision = current.revision or 0 end
  events_state:compare_and_set(revision, events)
end
local attach = tinest.hook.agent_attach({
  id = "attach", required_capabilities = hook_capabilities,
}, function(_arguments)
  ${failAttach ? 'error("attach failed")' : 'append("attach")'}
  return {}
end)
local open = tinest.hook.session_open({
  id = "open", required_capabilities = hook_capabilities,
}, function(_arguments) append("open") return {} end)
local close = tinest.hook.session_close({
  id = "close", required_capabilities = hook_capabilities,
}, function(_arguments)
  ${failClose ? 'error("close failed")' : 'append("close")'}
  return {}
end)
local detach = tinest.hook.agent_detach({
  id = "detach", required_capabilities = hook_capabilities,
}, function(_arguments) append("detach") return {} end)
return tinest.plugin.define({hooks = {attach, open, close, detach}})
'''
            .codeUnits,
      ),
    },
  );
}

PluginRuntime<Object> _runtime(
  Directory host,
  PluginRevisionCatalog revisions,
) => PluginRuntime<Object>(
  luaRuntime: lua.LuaToolRuntime<Object>(
    host: lua.LuaHostCommand.fromDirectory(host.path),
    processLauncher: const lua.IoLuaHostProcessLauncher(),
    clock: const lua.SystemLuaClock(),
    ids: _Ids(),
  ),
  revisions: revisions,
);

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
