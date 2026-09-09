@Tags(<String>[
  'feature_test__agent_harness__unit',
  'feature_test__agent_harness__verticalSlice',
])
@Timeout(Duration(minutes: 2))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agent/agent.dart';
import 'package:daemon/src/features/plugins/infrastructure/memory_plugin_stores.dart';
import 'package:daemon/src/features/plugins/infrastructure/native_plugin_state_repository.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_bundles.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_network_gateway.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_ports.dart';
import 'package:daemon/src/features/plugins/runtime/host_primitive_contracts.dart';
import 'package:daemon/src/features/plugins/runtime/host_primitives.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_agent_harness.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_runtime.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_scheduled_handler.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_scheduler.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';
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
      'tinest-plugin-harness-host-',
    );
    buildDirectory = await Directory.systemTemp.createTemp(
      'tinest-plugin-harness-build-',
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
    'Lua driver owns prompt order, model calls, host inputs, and zero tools',
    () async {
      final bundle = _driverBundle();
      final cache = _MemoryRevisionCache();
      final revisions = PluginRevisionCatalog(
        loader: _BundleLoader(bundle),
        cache: cache,
      );
      await revisions.reload(
        'acme.driver',
        agentId: 'agent-1',
        approvedCapabilities: const <String>{'model.call', 'tools.list'},
      );
      final runtime = PluginRuntime<ConversationAttachment>(
        luaRuntime: lua.LuaToolRuntime<ConversationAttachment>(
          host: lua.LuaHostCommand.fromDirectory(stagedHost.path),
          processLauncher: const lua.IoLuaHostProcessLauncher(),
          clock: const lua.SystemLuaClock(),
          ids: _Ids(),
        ),
        revisions: revisions,
      );
      addTearDown(runtime.close);
      final model = _RecordingModelGateway();
      final persisted = <ConversationItem>[];
      final events = <String>[];
      final harness = LuaAgentHarness(runtime: runtime);
      final attachment = ConversationAttachment(
        id: 'attachment-1',
        fileName: 'input.png',
        mimeType: 'image/png',
        byteSize: 3,
        path: r'C:\private\attachment.blob',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        kind: AgentAttachmentKind.image,
      );

      final result = await harness.startTurn(
        request: LuaAgentHarnessRequest(
          definition: const AgentDefinitionDto(
            version: 5,
            id: 'agent-1',
            name: 'Agent',
            description: '',
            mode: AgentMode.primary,
            model: AgentModelSelectionDto(source: AgentModelSource.session),
            driverId: 'acme.driver/driver',
            extensionIds: <String>[],
            toolIds: <String>[],
            pluginSettings: <String, Map<String, dynamic>>{},
            callableAgentIds: <String>[],
            prompt: 'AGENT BODY',
            contentHash: 'agent-hash',
            sourcePath: 'agent.md',
          ),
          sessionId: 'session-1',
          turnId: 'turn-1',
          workspaceId: 'workspace-1',
          workspaceRoot: Directory.current.path,
          prompt: 'USER INPUT',
          modelId: 'model-1',
          model: model,
          modelCapabilities: const AgentModelCapabilities(
            streaming: AgentCapabilitySupport.supported,
          ),
          history: const <ConversationItem>[],
          turnInputs: <ConversationItem>[
            UserConversationItem(
              'HOST INPUT',
              attachments: <ConversationAttachment>[attachment],
            ),
          ],
          allowedCapabilitiesByPlugin: const <String, Set<String>>{
            'acme.driver': <String>{'model.call', 'tools.list'},
          },
        ),
        callbacks: LuaAgentHarnessCallbacks(
          onEvent: (type, _) => events.add(type),
          onStatus: (_, {error}) {},
          onProviderItems: persisted.addAll,
        ),
        cancellation: CancellationToken(),
      );

      expect(model.requests, hasLength(2));
      expect(model.requests.first.blocks, hasLength(2));
      expect(
        model.requests.first.blocks.map((block) => block.toJson()),
        <Map<String, dynamic>>[
          <String, dynamic>{'role': 'system', 'content': 'AGENT BODY'},
          <String, dynamic>{'role': 'system', 'content': 'first'},
        ],
      );
      expect(
        model.requests.last.blocks.map((block) => block.toJson()),
        <Map<String, dynamic>>[
          <String, dynamic>{'role': 'system', 'content': 'AGENT BODY'},
          <String, dynamic>{'role': 'system', 'content': 'second'},
        ],
      );
      expect(model.requests.every((request) => request.tools.isEmpty), isTrue);
      expect(
        model.requests.first.history.map((item) => item.toJson()),
        <Map<String, dynamic>>[
          UserConversationItem(
            'HOST INPUT',
            attachments: <ConversationAttachment>[attachment],
          ).toJson(),
          const UserConversationItem('USER INPUT').toJson(),
        ],
      );
      expect(
        model.requests.first.history
            .whereType<UserConversationItem>()
            .first
            .attachments
            .single
            .bytes,
        <int>[1, 2, 3],
      );
      expect(result.toolRounds, 0);
      expect(
        persisted.whereType<AssistantConversationItem>().map(
          (item) => item.text,
        ),
        <String>['first', 'second'],
      );
      expect(events, containsAll(<String>['user.message', 'model.usage']));
      expect(events.last, 'turn.completed');
    },
  );

  test('the built-in standard driver builds every prompt block from the '
      'universal role set', () async {
    const agentId = 'universal-role-agent';
    final standard = await const BuiltInPluginCatalog().load('tinest.standard');
    final revisions = PluginRevisionCatalog(
      loader: _BundleLoader(standard),
      cache: _MemoryRevisionCache(),
    );
    final capabilities = standard.descriptor.requestedCapabilities.toSet();
    await revisions.reload(
      standard.descriptor.id,
      agentId: agentId,
      approvedCapabilities: capabilities,
    );
    final runtime = _pluginRuntime(stagedHost, revisions);
    addTearDown(runtime.close);
    final model = _RecordingModelGateway();

    await LuaAgentHarness(runtime: runtime).startTurn(
      request: LuaAgentHarnessRequest(
        definition: const AgentDefinitionDto(
          version: 5,
          id: agentId,
          name: 'Universal Role Agent',
          description: '',
          mode: AgentMode.primary,
          model: AgentModelSelectionDto(source: AgentModelSource.session),
          driverId: 'tinest.standard/driver',
          extensionIds: <String>[],
          toolIds: <String>[],
          pluginSettings: <String, Map<String, dynamic>>{},
          callableAgentIds: <String>[],
          prompt: 'AGENT BODY',
          contentHash: 'universal-role-agent-hash',
          sourcePath: 'universal-role-agent.md',
        ),
        sessionId: 'universal-role-session',
        turnId: 'universal-role-turn',
        workspaceRoot: Directory.current.path,
        prompt: 'run',
        modelId: 'universal-role-model',
        model: model,
        modelCapabilities: const AgentModelCapabilities(
          streaming: AgentCapabilitySupport.supported,
        ),
        history: const <ConversationItem>[],
        // Exercises the permission-policy, project-document and agent-prompt
        // blocks in one turn, so every prompt-composition path is covered.
        projectDocument: 'PROJECT DOCUMENT',
        extensionData: const <String, Object?>{
          'host_policy': <String, Object?>{
            'permission_mode': 'readOnly',
            'workspace_root': '/workspace',
          },
        },
        allowedCapabilitiesByPlugin: <String, Set<String>>{
          standard.descriptor.id: capabilities,
        },
        state: MemoryPluginStateStore(),
      ),
      callbacks: LuaAgentHarnessCallbacks(
        onEvent: (_, _) {},
        onStatus: (_, {error}) {},
        onProviderItems: (_) {},
      ),
      cancellation: CancellationToken(),
    );

    // A driver may only name roles every transport accepts. One vendor's
    // superset reaches the others as an unknown role and fails the request.
    expect(model.requests, isNotEmpty);
    expect(
      model.requests
          .expand((request) => request.blocks)
          .map((block) => block.role.name)
          .toSet(),
      everyElement(isIn(<String>['system', 'user', 'assistant'])),
    );
  });

  test('model.open rejects a role outside the neutral vocabulary', () async {
    final bundle = _rawRoleDriverBundle('developer');
    final revisions = PluginRevisionCatalog(
      loader: _BundleLoader(bundle),
      cache: _MemoryRevisionCache(),
    );
    await revisions.reload(
      bundle.descriptor.id,
      agentId: 'agent-1',
      approvedCapabilities: const <String>{'model.call', 'tools.list'},
    );
    final runtime = _pluginRuntime(stagedHost, revisions);
    addTearDown(runtime.close);
    final model = _RecordingModelGateway();

    await expectLater(
      LuaAgentHarness(runtime: runtime).startTurn(
        request: LuaAgentHarnessRequest(
          definition: const AgentDefinitionDto(
            version: 5,
            id: 'agent-1',
            name: 'Agent',
            description: '',
            mode: AgentMode.primary,
            model: AgentModelSelectionDto(source: AgentModelSource.session),
            driverId: 'acme.raw-role/driver',
            extensionIds: <String>[],
            toolIds: <String>[],
            pluginSettings: <String, Map<String, dynamic>>{},
            callableAgentIds: <String>[],
            prompt: 'AGENT BODY',
            contentHash: 'agent-hash',
            sourcePath: 'agent.md',
          ),
          sessionId: 'session-1',
          turnId: 'unsupported-role-turn',
          workspaceRoot: Directory.current.path,
          prompt: 'run',
          modelId: 'model-1',
          model: model,
          modelCapabilities: const AgentModelCapabilities(
            streaming: AgentCapabilitySupport.supported,
          ),
          history: const <ConversationItem>[],
          allowedCapabilitiesByPlugin: const <String, Set<String>>{
            'acme.raw-role': <String>{'model.call', 'tools.list'},
          },
        ),
        callbacks: LuaAgentHarnessCallbacks(
          onEvent: (_, _) {},
          onStatus: (_, {error}) {},
          onProviderItems: (_) {},
        ),
        cancellation: CancellationToken(),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(contains('"developer"'), contains('system, user, assistant')),
        ),
      ),
    );
    // The role never reaches the transport, so no provider can answer 400
    // for a vocabulary the runtime should have rejected itself.
    expect(model.requests, isEmpty);
  });

  test(
    'driver media requirements are checked against the selected model',
    () async {
      for (final requirement in const <String>['image_input', 'file_input']) {
        final bundle = _driverBundle(
          requiredModelCapabilities: <String>['streaming', requirement],
        );
        final revisions = PluginRevisionCatalog(
          loader: _BundleLoader(bundle),
          cache: _MemoryRevisionCache(),
        );
        await revisions.reload(
          bundle.descriptor.id,
          agentId: 'agent-1',
          approvedCapabilities: const <String>{'model.call', 'tools.list'},
        );
        final runtime = _pluginRuntime(stagedHost, revisions);
        addTearDown(runtime.close);
        final model = _RecordingModelGateway();

        await expectLater(
          LuaAgentHarness(runtime: runtime).startTurn(
            request: LuaAgentHarnessRequest(
              definition: const AgentDefinitionDto(
                version: 5,
                id: 'agent-1',
                name: 'Agent',
                description: '',
                mode: AgentMode.primary,
                model: AgentModelSelectionDto(source: AgentModelSource.session),
                driverId: 'acme.driver/driver',
                extensionIds: <String>[],
                toolIds: <String>[],
                pluginSettings: <String, Map<String, dynamic>>{},
                callableAgentIds: <String>[],
                prompt: 'AGENT BODY',
                contentHash: 'agent-hash',
                sourcePath: 'agent.md',
              ),
              sessionId: 'session-1',
              turnId: 'unsupported-media-turn',
              workspaceRoot: Directory.current.path,
              prompt: 'run',
              modelId: 'model-1',
              model: model,
              modelCapabilities: const AgentModelCapabilities(
                streaming: AgentCapabilitySupport.supported,
              ),
              history: const <ConversationItem>[],
              allowedCapabilitiesByPlugin: const <String, Set<String>>{
                'acme.driver': <String>{'model.call', 'tools.list'},
              },
            ),
            callbacks: LuaAgentHarnessCallbacks(
              onEvent: (_, _) {},
              onStatus: (_, {error}) {},
              onProviderItems: (_) {},
            ),
            cancellation: CancellationToken(),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains(
                'Model does not satisfy driver capability: $requirement',
              ),
            ),
          ),
        );
        expect(model.requests, isEmpty);
      }
    },
  );

  for (final kind in const <String>['function', 'deferred']) {
    for (final support in const <AgentCapabilitySupport>[
      AgentCapabilitySupport.unknown,
      AgentCapabilitySupport.unsupported,
    ]) {
      test('model.open rejects a $kind tool when subtype support is '
          '${support.name}', () async {
        final model = _RecordingModelGateway();
        const base = AgentModelCapabilities(
          streaming: AgentCapabilitySupport.supported,
          toolCalling: AgentCapabilitySupport.supported,
        );
        final capabilities = kind == 'function'
            ? base.copyWith(functionTools: support)
            : base.copyWith(deferredTools: support);
        await expectLater(
          _runModelToolSurfaceTurn(
            stagedHost: stagedHost,
            bundle: _modelToolSurfaceBundle(kind: kind),
            toolIds: <String>['acme.surface/tool'],
            capabilities: capabilities,
            model: model,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('Model does not support selected'),
            ),
          ),
        );
        expect(model.requests, isEmpty);
      });
    }
  }

  test(
    'model.open accepts a zero-tool surface with all tool kinds denied',
    () async {
      final model = _RecordingModelGateway();
      await _runModelToolSurfaceTurn(
        stagedHost: stagedHost,
        bundle: _modelToolSurfaceBundle(kind: null),
        toolIds: const <String>[],
        capabilities: const AgentModelCapabilities(
          streaming: AgentCapabilitySupport.supported,
          toolCalling: AgentCapabilitySupport.unsupported,
          functionTools: AgentCapabilitySupport.unsupported,
          deferredTools: AgentCapabilitySupport.unsupported,
        ),
        model: model,
      );
      expect(model.requests, hasLength(1));
      expect(model.requests.single.tools, isEmpty);
    },
  );

  test(
    'model.open validates a function tool surfaced dynamically in the turn',
    () async {
      final model = _RecordingModelGateway();
      await expectLater(
        _runModelToolSurfaceTurn(
          stagedHost: stagedHost,
          bundle: _dynamicModelToolSurfaceBundle(),
          toolIds: const <String>[],
          capabilities: const AgentModelCapabilities(
            streaming: AgentCapabilitySupport.supported,
            toolCalling: AgentCapabilitySupport.supported,
            functionTools: AgentCapabilitySupport.unsupported,
          ),
          model: model,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('selected function tool: dynamic_runtime_tool'),
          ),
        ),
      );
      expect(model.requests, isEmpty);
    },
  );

  test('surfaced dynamic ToolRef executes its closure through the full host '
      'tool boundary', () async {
    final bundle = _dynamicToolExecutionBundle();
    final revisions = PluginRevisionCatalog(
      loader: _BundleLoader(bundle),
      cache: _MemoryRevisionCache(),
    );
    final grants = bundle.descriptor.requestedCapabilities.toSet();
    await revisions.reload(
      bundle.descriptor.id,
      agentId: 'dynamic-agent',
      approvedCapabilities: grants,
    );
    final runtime = _pluginRuntime(stagedHost, revisions);
    addTearDown(runtime.close);
    final model = _DynamicToolModelGateway();
    final host = _CountingPrimitiveHost();
    final persisted = <ConversationItem>[];
    final completed = <Map<String, dynamic>>[];

    final result = await LuaAgentHarness(runtime: runtime).startTurn(
      request: LuaAgentHarnessRequest(
        definition: const AgentDefinitionDto(
          version: 5,
          id: 'dynamic-agent',
          name: 'Dynamic Agent',
          description: '',
          mode: AgentMode.primary,
          model: AgentModelSelectionDto(source: AgentModelSource.session),
          driverId: 'acme.dynamic/driver',
          extensionIds: <String>[],
          toolIds: <String>[],
          pluginSettings: <String, Map<String, dynamic>>{},
          callableAgentIds: <String>[],
          prompt: '',
          contentHash: 'dynamic-agent-hash',
          sourcePath: 'dynamic-agent.md',
        ),
        sessionId: 'dynamic-session',
        turnId: 'dynamic-turn',
        workspaceRoot: Directory.current.path,
        prompt: 'read',
        modelId: 'dynamic-model',
        model: model,
        modelCapabilities: const AgentModelCapabilities(
          streaming: AgentCapabilitySupport.supported,
          toolCalling: AgentCapabilitySupport.supported,
          functionTools: AgentCapabilitySupport.supported,
        ),
        history: const <ConversationItem>[],
        allowedCapabilitiesByPlugin: <String, Set<String>>{
          bundle.descriptor.id: grants,
        },
        primitives: host.registry,
        ids: _HostIds('dynamic'),
      ),
      callbacks: LuaAgentHarnessCallbacks(
        onEvent: (type, data) {
          if (type == 'tool.completed') completed.add(data);
        },
        onStatus: (_, {error}) {},
        onProviderItems: persisted.addAll,
      ),
      cancellation: CancellationToken(),
    );

    expect(result.toolRounds, 1);
    expect(host.readCount, 1);
    expect(
      host.statCount,
      0,
      reason: 'a dynamic callback may invoke only the primitives in uses',
    );
    expect(model.requests, hasLength(2));
    expect(model.requests.first.tools.single.name, 'dynamic_runtime_tool');
    expect(completed.single, containsPair('callId', 'dynamic-call'));
    expect(completed.single, containsPair('isError', false));
    expect(
      persisted.whereType<ToolResultConversationItem>().single.output,
      'read_file executed',
    );
  });

  test(
    'uses gates exact host operations per contribution and shared closure',
    () async {
      final bundle = _exactPrimitiveUsesBundle();
      final host = _CountingPrimitiveHost();

      await _runHostPrimitiveTurn(
        stagedHost: stagedHost,
        bundle: bundle,
        agentId: 'exact-uses-agent',
        sessionId: 'exact-uses-session',
        prompt: 'verify exact primitive declarations',
        grantedCapabilities: bundle.descriptor.requestedCapabilities.toSet(),
        policy: const _AllowPolicy(),
        toolIds: const <String>[
          'acme.exact-uses/read',
          'acme.exact-uses/stat',
          'acme.exact-uses/capability-only',
        ],
        primitives: host.registry,
      );

      expect(
        host.readCount,
        1,
        reason: 'the contribution declaring read_text must still succeed',
      );
      expect(
        host.statCount,
        1,
        reason: 'only the contribution declaring stat may reach stat',
      );
    },
  );

  test(
    'opaque refs reject forged wrong-kind unselected and serialized uses',
    () async {
      final bundle = _opaqueRefSecurityBundle();

      await _runHostPrimitiveTurn(
        stagedHost: stagedHost,
        bundle: bundle,
        agentId: 'opaque-ref-agent',
        sessionId: 'opaque-ref-session',
        prompt: 'verify opaque references',
        grantedCapabilities: bundle.descriptor.requestedCapabilities.toSet(),
        policy: const _AllowPolicy(),
        toolIds: const <String>['acme.opaque-refs/return-ref'],
      );
    },
  );

  test(
    'dynamic schema errors skip the closure and use the tool completion path',
    () async {
      final bundle = _dynamicToolExecutionBundle();
      final revisions = PluginRevisionCatalog(
        loader: _BundleLoader(bundle),
        cache: _MemoryRevisionCache(),
      );
      final grants = bundle.descriptor.requestedCapabilities.toSet();
      await revisions.reload(
        bundle.descriptor.id,
        agentId: 'dynamic-invalid-agent',
        approvedCapabilities: grants,
      );
      final runtime = _pluginRuntime(stagedHost, revisions);
      addTearDown(runtime.close);
      final host = _CountingPrimitiveHost();
      final persisted = <ConversationItem>[];
      final completions = <Map<String, dynamic>>[];

      final result = await LuaAgentHarness(runtime: runtime).startTurn(
        request: LuaAgentHarnessRequest(
          definition: const AgentDefinitionDto(
            version: 5,
            id: 'dynamic-invalid-agent',
            name: 'Dynamic Invalid Agent',
            description: '',
            mode: AgentMode.primary,
            model: AgentModelSelectionDto(source: AgentModelSource.session),
            driverId: 'acme.dynamic/driver',
            extensionIds: <String>[],
            toolIds: <String>[],
            pluginSettings: <String, Map<String, dynamic>>{},
            callableAgentIds: <String>[],
            prompt: '',
            contentHash: 'dynamic-invalid-agent-hash',
            sourcePath: 'dynamic-invalid-agent.md',
          ),
          sessionId: 'dynamic-invalid-session',
          turnId: 'dynamic-invalid-turn',
          workspaceRoot: Directory.current.path,
          prompt: 'read',
          modelId: 'dynamic-model',
          model: _DynamicToolModelGateway(
            arguments: const <String, dynamic>{'path': 42},
          ),
          modelCapabilities: const AgentModelCapabilities(
            streaming: AgentCapabilitySupport.supported,
            toolCalling: AgentCapabilitySupport.supported,
            functionTools: AgentCapabilitySupport.supported,
          ),
          history: const <ConversationItem>[],
          allowedCapabilitiesByPlugin: <String, Set<String>>{
            bundle.descriptor.id: grants,
          },
          primitives: host.registry,
          ids: _HostIds('dynamic-invalid'),
        ),
        callbacks: LuaAgentHarnessCallbacks(
          onEvent: (type, data) {
            if (type == 'tool.completed') completions.add(data);
          },
          onStatus: (_, {error}) {},
          onProviderItems: persisted.addAll,
        ),
        cancellation: CancellationToken(),
      );

      expect(result.toolRounds, 1);
      expect(host.readCount, 0, reason: 'invalid input must skip the closure');
      expect(completions, hasLength(1));
      expect(completions.single, containsPair('callId', 'dynamic-call'));
      expect(completions.single, containsPair('isError', true));
      final stored = persisted.whereType<ToolResultConversationItem>().single;
      expect(stored.callId, 'dynamic-call');
      expect(stored.isError, isTrue);
      expect(stored.output, contains('invalid_tool_arguments'));
    },
  );

  test(
    'tool input normalization preserves each schema kind boundary',
    () async {
      final bundle = _toolInputNormalizationBundle();
      final revisions = PluginRevisionCatalog(
        loader: _BundleLoader(bundle),
        cache: _MemoryRevisionCache(),
      );
      final grants = bundle.descriptor.requestedCapabilities.toSet();
      await revisions.reload(
        bundle.descriptor.id,
        agentId: 'input-agent',
        approvedCapabilities: grants,
      );
      final runtime = _pluginRuntime(stagedHost, revisions);
      addTearDown(runtime.close);
      final completions = <Map<String, dynamic>>[];

      final result = await LuaAgentHarness(runtime: runtime).startTurn(
        request: LuaAgentHarnessRequest(
          definition: const AgentDefinitionDto(
            version: 5,
            id: 'input-agent',
            name: 'Input Agent',
            description: '',
            mode: AgentMode.primary,
            model: AgentModelSelectionDto(source: AgentModelSource.session),
            driverId: 'acme.inputs/driver',
            extensionIds: <String>[],
            toolIds: <String>[
              'acme.inputs/function',
              'acme.inputs/deferred',
              'acme.inputs/text',
            ],
            pluginSettings: <String, Map<String, dynamic>>{},
            callableAgentIds: <String>[],
            prompt: '',
            contentHash: 'input-agent-hash',
            sourcePath: 'input-agent.md',
          ),
          sessionId: 'input-session',
          turnId: 'input-turn',
          workspaceRoot: Directory.current.path,
          prompt: 'run',
          modelId: 'unused',
          model: _RecordingModelGateway(),
          modelCapabilities: const AgentModelCapabilities(),
          history: const <ConversationItem>[],
          allowedCapabilitiesByPlugin: <String, Set<String>>{
            bundle.descriptor.id: grants,
          },
        ),
        callbacks: LuaAgentHarnessCallbacks(
          onEvent: (type, data) {
            if (type == 'tool.completed') completions.add(data);
          },
          onStatus: (_, {error}) {},
          onProviderItems: (_) {},
        ),
        cancellation: CancellationToken(),
      );

      expect(result.toolRounds, 5);
      final outputs = completions.map((event) => event['output']).toList();
      expect(
        <Object?>[outputs[0], outputs[1], outputs[2], outputs[4]],
        <Object?>['function:1', 'deferred:1', 'raw source', 'function:1'],
      );
      expect(outputs[3], contains('invalid_tool_arguments'));
      expect(completions.map((event) => event['isError']), <Object?>[
        false,
        false,
        false,
        true,
        false,
      ]);
    },
  );

  test(
    'apply_patch surfaces to a model that advertises function tools only',
    () async {
      // The vendors behind Chat Completions — MiniMax, DeepSeek, Anthropic,
      // Gemini — advertise function tools and nothing else. apply_patch is
      // the product's only write tool, so it has to reach them unchanged.
      const agentId = 'patch-surface-agent';
      final bundles = <String, PluginBundle>{};
      for (final id in const <String>['tinest.standard', 'tinest.edit']) {
        final bundle = await const BuiltInPluginCatalog().load(id);
        bundles[bundle.descriptor.id] = bundle;
      }
      final revisions = PluginRevisionCatalog(
        loader: _BundleMapLoader(bundles),
        cache: _MemoryRevisionCache(),
      );
      final allowedCapabilities = <String, Set<String>>{};
      for (final bundle in bundles.values) {
        final capabilities = bundle.descriptor.requestedCapabilities.toSet();
        await revisions.reload(
          bundle.descriptor.id,
          agentId: agentId,
          approvedCapabilities: capabilities,
        );
        allowedCapabilities[bundle.descriptor.id] = capabilities;
      }
      final runtime = _pluginRuntime(stagedHost, revisions);
      addTearDown(runtime.close);
      const patch =
          '*** Begin Patch\n'
          '*** Add File: surfaced.txt\n'
          '+written\n'
          '*** End Patch';
      final model = _ScriptedModelGateway(<_ModelStep>[
        _ModelStep.events(<ModelEvent>[
          const ModelFunctionCall(
            callId: 'patch-call',
            name: 'apply_patch',
            arguments: <String, dynamic>{'patch': patch},
          ),
          const ModelResponseCompleted(
            assistant: AssistantConversationItem(
              text: '',
              toolCalls: <ConversationToolCall>[
                ConversationToolCall.function(
                  callId: 'patch-call',
                  name: 'apply_patch',
                  arguments: <String, dynamic>{'patch': patch},
                ),
              ],
            ),
          ),
        ]),
        _ModelStep.completion('done'),
      ]);
      final persisted = <ConversationItem>[];
      final requested = <Map<String, dynamic>>[];

      final result = await LuaAgentHarness(runtime: runtime).startTurn(
        request: LuaAgentHarnessRequest(
          definition: const AgentDefinitionDto(
            version: 5,
            id: agentId,
            name: 'Patch Surface Agent',
            description: '',
            mode: AgentMode.primary,
            model: AgentModelSelectionDto(source: AgentModelSource.session),
            driverId: 'tinest.standard/driver',
            extensionIds: <String>[],
            toolIds: <String>['tinest.edit/apply_patch'],
            pluginSettings: <String, Map<String, dynamic>>{},
            callableAgentIds: <String>[],
            prompt: '',
            contentHash: 'patch-surface-agent-hash',
            sourcePath: 'patch-surface-agent.md',
          ),
          sessionId: 'patch-surface-session',
          turnId: 'patch-surface-turn',
          workspaceRoot: Directory.current.path,
          prompt: 'create surfaced.txt',
          modelId: 'patch-surface-model',
          model: model,
          modelCapabilities: const AgentModelCapabilities(
            streaming: AgentCapabilitySupport.supported,
            toolCalling: AgentCapabilitySupport.supported,
            functionTools: AgentCapabilitySupport.supported,
            deferredTools: AgentCapabilitySupport.unsupported,
          ),
          history: const <ConversationItem>[],
          allowedCapabilitiesByPlugin: allowedCapabilities,
          state: MemoryPluginStateStore(),
        ),
        callbacks: LuaAgentHarnessCallbacks(
          onEvent: (type, data) {
            if (type == 'tool.requested') requested.add(data);
          },
          onStatus: (_, {error}) {},
          onProviderItems: persisted.addAll,
        ),
        cancellation: CancellationToken(),
      );

      expect(result.toolRounds, 1);
      final surfaced = model.requests.first.tools.single;
      expect(surfaced, isA<ModelFunctionToolDefinition>());
      surfaced as ModelFunctionToolDefinition;
      expect(surfaced.name, 'apply_patch');
      expect(surfaced.parameters['type'], 'object');
      expect(
        Map<String, Object?>.from(surfaced.parameters['properties']! as Map),
        contains('patch'),
      );
      // The whole patch document reaches the tool as one JSON string, so a
      // provider that only speaks function calls loses nothing.
      expect(
        Map<String, Object?>.from(requested.single['arguments']! as Map),
        containsPair('patch', patch),
      );
      final stored = persisted.whereType<ToolResultConversationItem>().single;
      expect(stored.toolKind, ModelToolKind.function);
    },
  );

  test(
    'standard driver omits optional object nulls and preserves array nulls',
    () async {
      const agentId = 'standard-null-agent';
      final standard = await const BuiltInPluginCatalog().load(
        'tinest.standard',
      );
      final toolBundle = _standardNullToolBundle();
      final bundles = <String, PluginBundle>{
        standard.descriptor.id: standard,
        toolBundle.descriptor.id: toolBundle,
      };
      final revisions = PluginRevisionCatalog(
        loader: _BundleMapLoader(bundles),
        cache: _MemoryRevisionCache(),
      );
      final allowedCapabilities = <String, Set<String>>{};
      for (final bundle in bundles.values) {
        final capabilities = bundle.descriptor.requestedCapabilities.toSet();
        await revisions.reload(
          bundle.descriptor.id,
          agentId: agentId,
          approvedCapabilities: capabilities,
        );
        allowedCapabilities[bundle.descriptor.id] = capabilities;
      }
      final runtime = _pluginRuntime(stagedHost, revisions);
      addTearDown(runtime.close);
      final model = _ScriptedModelGateway(<_ModelStep>[
        _ModelStep.events(<ModelEvent>[
          const ModelFunctionCall(
            callId: 'required-null-call',
            name: 'normalize_nulls',
            arguments: <String, dynamic>{
              'required_string': null,
              'required_nullable': null,
              'required_nullable_enum': null,
              'optional': null,
              'nested': <String, dynamic>{'optional': null},
              'mapped': <String, dynamic>{
                'first': <String, dynamic>{'optional': null},
              },
              'enum_only': null,
              'nullable_type_enum_excludes_null': null,
              'values': <Object?>['first', null],
              'empty_object': <String, dynamic>{},
              'empty_array': <Object?>[],
            },
          ),
          const ModelResponseCompleted(
            assistant: AssistantConversationItem(
              text: '',
              toolCalls: <ConversationToolCall>[
                ConversationToolCall.function(
                  callId: 'required-null-call',
                  name: 'normalize_nulls',
                  arguments: <String, dynamic>{
                    'required_string': null,
                    'required_nullable': null,
                    'required_nullable_enum': null,
                    'optional': null,
                    'nested': <String, dynamic>{'optional': null},
                    'mapped': <String, dynamic>{
                      'first': <String, dynamic>{'optional': null},
                    },
                    'enum_only': null,
                    'nullable_type_enum_excludes_null': null,
                    'values': <Object?>['first', null],
                    'empty_object': <String, dynamic>{},
                    'empty_array': <Object?>[],
                  },
                ),
              ],
            ),
          ),
        ]),
        _ModelStep.events(<ModelEvent>[
          const ModelFunctionCall(
            callId: 'optional-null-call',
            name: 'normalize_nulls',
            arguments: <String, dynamic>{
              'required_string': 'present',
              'required_nullable': null,
              'required_nullable_enum': null,
              'optional': null,
              'nested': <String, dynamic>{'optional': null},
              'mapped': <String, dynamic>{
                'first': <String, dynamic>{'optional': null},
              },
              'enum_only': null,
              'nullable_type_enum_excludes_null': null,
              'values': <Object?>['first', null],
              'empty_object': <String, dynamic>{},
              'empty_array': <Object?>[],
            },
          ),
          const ModelResponseCompleted(
            assistant: AssistantConversationItem(
              text: '',
              toolCalls: <ConversationToolCall>[
                ConversationToolCall.function(
                  callId: 'optional-null-call',
                  name: 'normalize_nulls',
                  arguments: <String, dynamic>{
                    'required_string': 'present',
                    'required_nullable': null,
                    'required_nullable_enum': null,
                    'optional': null,
                    'nested': <String, dynamic>{'optional': null},
                    'mapped': <String, dynamic>{
                      'first': <String, dynamic>{'optional': null},
                    },
                    'enum_only': null,
                    'nullable_type_enum_excludes_null': null,
                    'values': <Object?>['first', null],
                    'empty_object': <String, dynamic>{},
                    'empty_array': <Object?>[],
                  },
                ),
              ],
            ),
          ),
        ]),
        _ModelStep.completion('done'),
      ]);
      final persisted = <ConversationItem>[];
      final requested = <Map<String, dynamic>>[];

      final result = await LuaAgentHarness(runtime: runtime).startTurn(
        request: LuaAgentHarnessRequest(
          definition: const AgentDefinitionDto(
            version: 5,
            id: agentId,
            name: 'Standard Null Agent',
            description: '',
            mode: AgentMode.primary,
            model: AgentModelSelectionDto(source: AgentModelSource.session),
            driverId: 'tinest.standard/driver',
            extensionIds: <String>[],
            toolIds: <String>['acme.standard-null/normalize'],
            pluginSettings: <String, Map<String, dynamic>>{},
            callableAgentIds: <String>[],
            prompt: '',
            contentHash: 'standard-null-agent-hash',
            sourcePath: 'standard-null-agent.md',
          ),
          sessionId: 'standard-null-session',
          turnId: 'standard-null-turn',
          workspaceRoot: Directory.current.path,
          prompt: 'normalize nulls',
          modelId: 'standard-null-model',
          model: model,
          modelCapabilities: const AgentModelCapabilities(
            streaming: AgentCapabilitySupport.supported,
            toolCalling: AgentCapabilitySupport.supported,
            functionTools: AgentCapabilitySupport.supported,
          ),
          history: const <ConversationItem>[],
          allowedCapabilitiesByPlugin: allowedCapabilities,
          state: MemoryPluginStateStore(),
        ),
        callbacks: LuaAgentHarnessCallbacks(
          onEvent: (type, data) {
            if (type == 'tool.requested') requested.add(data);
          },
          onStatus: (_, {error}) {},
          onProviderItems: persisted.addAll,
        ),
        cancellation: CancellationToken(),
      );

      expect(result.toolRounds, 2);
      final stored = persisted.whereType<ToolResultConversationItem>().toList();
      expect(stored, hasLength(2));
      expect(stored.first.isError, isTrue);
      expect(stored.first.output, contains('Expected string, got null'));
      expect(stored.last.isError, isFalse);
      expect(stored.last.output, 'normalized');
      expect(requested, hasLength(2));
      final rawArguments = Map<String, Object?>.from(
        requested.last['arguments']! as Map,
      );
      expect(rawArguments, containsPair('optional', null));
      expect(
        Map<String, Object?>.from(rawArguments['nested']! as Map),
        containsPair('optional', null),
      );
      expect(
        Map<String, Object?>.from(
          Map<String, Object?>.from(rawArguments['mapped']! as Map)['first']!
              as Map,
        ),
        containsPair('optional', null),
      );
      expect(rawArguments, containsPair('enum_only', null));
      expect(
        rawArguments,
        containsPair('nullable_type_enum_excludes_null', null),
      );
      expect(rawArguments['values'], <Object?>['first', null]);
    },
  );

  test('Lua code driver omits optional wait nulls before invocation', () async {
    const agentId = 'lua-code-null-agent';
    final luaCode = await const BuiltInPluginCatalog().load('tinest.lua-code');
    final revisions = PluginRevisionCatalog(
      loader: _BundleLoader(luaCode),
      cache: _MemoryRevisionCache(),
    );
    final capabilities = luaCode.descriptor.requestedCapabilities.toSet();
    await revisions.reload(
      luaCode.descriptor.id,
      agentId: agentId,
      approvedCapabilities: capabilities,
    );
    final runtime = _pluginRuntime(stagedHost, revisions);
    addTearDown(runtime.close);
    final model = _ScriptedModelGateway(<_ModelStep>[
      _ModelStep.events(<ModelEvent>[
        const ModelFunctionCall(
          callId: 'wait-null-call',
          name: 'wait',
          arguments: <String, dynamic>{
            'cell_id': 'cell-1',
            'yield_time_ms': null,
            'max_tokens': null,
            'terminate': null,
          },
        ),
        const ModelResponseCompleted(
          assistant: AssistantConversationItem(
            text: '',
            toolCalls: <ConversationToolCall>[
              ConversationToolCall.function(
                callId: 'wait-null-call',
                name: 'wait',
                arguments: <String, dynamic>{
                  'cell_id': 'cell-1',
                  'yield_time_ms': null,
                  'max_tokens': null,
                  'terminate': null,
                },
              ),
            ],
          ),
        ),
      ]),
      _ModelStep.completion('done'),
    ]);
    final reads = <Map<String, Object?>>[];
    final primitives = HostPrimitiveRegistry(<HostPrimitive<Object?, Object?>>[
      HostPrimitiveContracts.luaRead
          .bind(
            decode: _primitiveArguments,
            invoke: (arguments, _) {
              reads.add(arguments);
              return <String, Object?>{'output': 'waited'};
            },
          )
          .erased,
    ]);
    final persisted = <ConversationItem>[];

    final result = await LuaAgentHarness(runtime: runtime).startTurn(
      request: LuaAgentHarnessRequest(
        definition: const AgentDefinitionDto(
          version: 5,
          id: agentId,
          name: 'Lua Code Null Agent',
          description: '',
          mode: AgentMode.primary,
          model: AgentModelSelectionDto(source: AgentModelSource.session),
          driverId: 'tinest.lua-code/driver',
          extensionIds: <String>[],
          toolIds: <String>['tinest.lua-code/exec', 'tinest.lua-code/wait'],
          pluginSettings: <String, Map<String, dynamic>>{},
          callableAgentIds: <String>[],
          prompt: '',
          contentHash: 'lua-code-null-agent-hash',
          sourcePath: 'lua-code-null-agent.md',
        ),
        sessionId: 'lua-code-null-session',
        turnId: 'lua-code-null-turn',
        workspaceRoot: Directory.current.path,
        prompt: 'wait',
        modelId: 'lua-code-null-model',
        model: model,
        modelCapabilities: const AgentModelCapabilities(
          streaming: AgentCapabilitySupport.supported,
          toolCalling: AgentCapabilitySupport.supported,
          functionTools: AgentCapabilitySupport.supported,
        ),
        history: const <ConversationItem>[],
        allowedCapabilitiesByPlugin: <String, Set<String>>{
          luaCode.descriptor.id: capabilities,
        },
        primitives: primitives,
        policyFactory: (_) => const _AllowPolicy(),
      ),
      callbacks: LuaAgentHarnessCallbacks(
        onEvent: (_, _) {},
        onStatus: (_, {error}) {},
        onProviderItems: persisted.addAll,
      ),
      cancellation: CancellationToken(),
    );

    expect(result.toolRounds, 1);
    expect(reads, <Map<String, Object?>>[
      <String, Object?>{'handle': 'cell-1'},
    ]);
    final stored = persisted.whereType<ToolResultConversationItem>().single;
    expect(stored.isError, isFalse);
  });

  test(
    'text driver parses XML and reuses the brokered tool result loop',
    () async {
      final bundle = _textToolDriverBundle();
      final revisions = PluginRevisionCatalog(
        loader: _BundleLoader(bundle),
        cache: _MemoryRevisionCache(),
      );
      await revisions.reload(
        bundle.descriptor.id,
        agentId: 'agent-text',
        approvedCapabilities: bundle.descriptor.requestedCapabilities.toSet(),
      );
      final runtime = _pluginRuntime(stagedHost, revisions);
      addTearDown(runtime.close);
      final model = _TextToolModelGateway();
      final host = _CountingPrimitiveHost();
      final approvals = _RecordingApprovalCoordinator(
        ApprovalDecision.approved,
      );
      final completions = <Map<String, dynamic>>[];

      final result = await LuaAgentHarness(runtime: runtime).startTurn(
        request: LuaAgentHarnessRequest(
          definition: const AgentDefinitionDto(
            version: 5,
            id: 'agent-text',
            name: 'Text tool Agent',
            description: '',
            mode: AgentMode.primary,
            model: AgentModelSelectionDto(source: AgentModelSource.session),
            driverId: 'acme.text/driver',
            extensionIds: <String>[],
            toolIds: <String>['acme.text/read'],
            pluginSettings: <String, Map<String, dynamic>>{},
            callableAgentIds: <String>[],
            prompt: '',
            contentHash: 'text-agent-hash',
            sourcePath: 'text-agent.md',
          ),
          sessionId: 'session-text',
          turnId: 'turn-text',
          workspaceRoot: Directory.current.path,
          prompt: 'Read README.md',
          modelId: 'text-only-model',
          model: model,
          modelCapabilities: const AgentModelCapabilities(
            streaming: AgentCapabilitySupport.supported,
          ),
          history: const <ConversationItem>[],
          allowedCapabilitiesByPlugin: const <String, Set<String>>{
            'acme.text': <String>{
              'model.call',
              'tools.list',
              'tools.invoke',
              'workspace.read',
            },
          },
          primitives: host.registry,
          approvals: approvals,
          policyFactory: (_) => const _AskPolicy(),
        ),
        callbacks: LuaAgentHarnessCallbacks(
          onEvent: (type, data) {
            if (type == 'tool.completed') completions.add(data);
          },
          onStatus: (_, {error}) {},
          onProviderItems: (_) {},
        ),
        cancellation: CancellationToken(),
      );

      expect(model.requests, hasLength(2));
      expect(model.requests.every((request) => request.tools.isEmpty), isTrue);
      expect(
        model.requests.first.blocks.map((block) => block.toJson()),
        <Map<String, dynamic>>[
          <String, dynamic>{
            'role': 'system',
            'content': 'Use XML tool syntax only.',
          },
        ],
      );
      expect(
        model.requests.last.history
            .whereType<AssistantConversationItem>()
            .single
            .text,
        '<tool name="read_file"><path>README.md</path></tool>',
      );
      final toolResult = model.requests.last.history
          .whereType<ToolResultConversationItem>()
          .single;
      expect(toolResult.callId, 'text-call-1');
      expect(toolResult.output, 'read_file executed');
      expect(host.readCount, 1);
      expect(approvals.invocations, hasLength(1));
      expect(approvals.invocations.single.name, 'read_file');
      expect(completions.single, containsPair('callId', 'text-call-1'));
      expect(completions.single, containsPair('isError', false));
      expect(result.toolRounds, 1);
    },
  );

  test(
    'lifecycle hooks receive every qualified control without enabled shim',
    () async {
      final bundle = _controlEchoBundle();
      final revisions = PluginRevisionCatalog(
        loader: _BundleLoader(bundle),
        cache: _MemoryRevisionCache(),
      );
      await revisions.reload(
        bundle.descriptor.id,
        agentId: 'agent-1',
        approvedCapabilities: bundle.descriptor.requestedCapabilities.toSet(),
      );
      final runtime = _pluginRuntime(stagedHost, revisions);
      addTearDown(runtime.close);
      final model = _RecordingModelGateway();

      await LuaAgentHarness(runtime: runtime).startTurn(
        request: LuaAgentHarnessRequest(
          definition: const AgentDefinitionDto(
            version: 5,
            id: 'agent-1',
            name: 'Control Agent',
            description: '',
            mode: AgentMode.primary,
            model: AgentModelSelectionDto(source: AgentModelSource.session),
            driverId: 'acme.controls/driver',
            extensionIds: <String>['acme.controls'],
            toolIds: <String>[],
            pluginSettings: <String, Map<String, dynamic>>{},
            callableAgentIds: <String>[],
            prompt: '',
            contentHash: 'agent-hash',
            sourcePath: 'agent.md',
          ),
          sessionId: 'session-1',
          turnId: 'turn-1',
          workspaceRoot: Directory.current.path,
          prompt: 'run',
          modelId: 'control-model',
          model: model,
          modelCapabilities: const AgentModelCapabilities(
            streaming: AgentCapabilitySupport.supported,
          ),
          history: const <ConversationItem>[],
          allowedCapabilitiesByPlugin: <String, Set<String>>{
            bundle.descriptor.id: bundle.descriptor.requestedCapabilities
                .toSet(),
          },
          sessionControlValues: const <String, Object?>{
            'acme.controls/alpha': true,
            'acme.controls/beta': 'selected',
          },
        ),
        callbacks: LuaAgentHarnessCallbacks(
          onEvent: (_, _) {},
          onStatus: (_, {error}) {},
          onProviderItems: (_) {},
        ),
        cancellation: CancellationToken(),
      );

      expect(model.requests.single.blocks.single.toJson(), <String, dynamic>{
        'role': 'system',
        'content': 'true|selected|nil',
      });
    },
  );

  test(
    'plugin tools receive per-Agent settings pinned for every tool call',
    () async {
      final bundle = _settingsToolBundle();
      final revisions = PluginRevisionCatalog(
        loader: _BundleLoader(bundle),
        cache: _MemoryRevisionCache(),
      );
      for (final agentId in const <String>['alpha-agent', 'bravo-agent']) {
        await revisions.reload(
          bundle.descriptor.id,
          agentId: agentId,
          approvedCapabilities: bundle.descriptor.requestedCapabilities.toSet(),
        );
      }
      final runtime = _pluginRuntime(stagedHost, revisions);
      addTearDown(runtime.close);
      final harness = LuaAgentHarness(runtime: runtime);
      final alphaSettings = <String, Map<String, dynamic>>{
        'acme.settings': <String, dynamic>{'label': 'alpha'},
      };

      AgentDefinitionDto definition(
        String agentId,
        Map<String, Map<String, dynamic>> settings,
      ) => AgentDefinitionDto(
        version: 5,
        id: agentId,
        name: agentId,
        description: '',
        mode: AgentMode.primary,
        model: const AgentModelSelectionDto(source: AgentModelSource.session),
        driverId: 'acme.settings/driver',
        extensionIds: const <String>[],
        toolIds: const <String>[
          'acme.settings/function',
          'acme.settings/text',
          'acme.settings/deferred',
        ],
        pluginSettings: settings,
        callableAgentIds: const <String>[],
        prompt: '',
        contentHash: '$agentId-hash',
        sourcePath: '$agentId.md',
      );

      Future<void> run({
        required AgentDefinitionDto agent,
        required String turnId,
        required ModelGateway model,
        required List<String> outputs,
      }) async {
        await harness.startTurn(
          request: LuaAgentHarnessRequest(
            definition: agent,
            sessionId: '$turnId-session',
            turnId: turnId,
            workspaceRoot: Directory.current.path,
            prompt: 'run',
            modelId: 'settings-model',
            model: model,
            modelCapabilities: const AgentModelCapabilities(
              streaming: AgentCapabilitySupport.supported,
            ),
            history: const <ConversationItem>[],
            allowedCapabilitiesByPlugin: <String, Set<String>>{
              bundle.descriptor.id: bundle.descriptor.requestedCapabilities
                  .toSet(),
            },
          ),
          callbacks: LuaAgentHarnessCallbacks(
            onEvent: (type, data) {
              if (type == 'tool.completed') {
                outputs.add(data['output']! as String);
              }
            },
            onStatus: (_, {error}) {},
            onProviderItems: (_) {},
          ),
          cancellation: CancellationToken(),
        );
      }

      final alphaOutputs = <String>[];
      final gatedModel = _GatedCompletionModelGateway();
      final alphaRun = run(
        agent: definition('alpha-agent', alphaSettings),
        turnId: 'alpha-turn',
        model: gatedModel,
        outputs: alphaOutputs,
      );
      await gatedModel.started.future;

      // The caller-owned source map changes after the turn starts. A pinned
      // turn must keep the snapshot it began with.
      alphaSettings['acme.settings']!['label'] = 'mutated';
      final bravoOutputs = <String>[];
      await run(
        agent: definition('bravo-agent', <String, Map<String, dynamic>>{
          'acme.settings': <String, dynamic>{'label': 'bravo'},
        }),
        turnId: 'bravo-turn',
        model: _RecordingModelGateway(),
        outputs: bravoOutputs,
      );
      gatedModel.release.complete();
      await alphaRun;

      expect(alphaOutputs, <String>[
        'alpha:function',
        'alpha:text',
        'alpha:deferred',
      ]);
      expect(bravoOutputs, <String>[
        'bravo:function',
        'bravo:text',
        'bravo:deferred',
      ]);
    },
  );

  test(
    'cancel and error transitions invoke their Lua lifecycle hooks',
    () async {
      final bundle = _terminalLifecycleBundle();
      final revisions = PluginRevisionCatalog(
        loader: _BundleLoader(bundle),
        cache: _MemoryRevisionCache(),
      );
      await revisions.reload(
        bundle.descriptor.id,
        agentId: 'agent-1',
        approvedCapabilities: bundle.descriptor.requestedCapabilities.toSet(),
      );
      final runtime = _pluginRuntime(stagedHost, revisions);
      addTearDown(runtime.close);
      final state = MemoryPluginStateStore();
      final statuses = <AgentSessionStatus>[];
      final lifecycleFailures = <Map<String, dynamic>>[];
      final lifecycleCompletions = <Map<String, dynamic>>[];

      Future<void> run(
        String prompt,
        ModelGateway model,
        CancellationToken cancellation,
      ) => LuaAgentHarness(runtime: runtime).startTurn(
        request: LuaAgentHarnessRequest(
          definition: _terminalLifecycleDefinition,
          sessionId: 'session-1',
          turnId: 'turn-$prompt',
          workspaceRoot: Directory.current.path,
          prompt: prompt,
          modelId: 'model',
          model: model,
          modelCapabilities: const AgentModelCapabilities(
            streaming: AgentCapabilitySupport.supported,
          ),
          history: const <ConversationItem>[],
          allowedCapabilitiesByPlugin: <String, Set<String>>{
            bundle.descriptor.id: bundle.descriptor.requestedCapabilities
                .toSet(),
          },
          state: state,
        ),
        callbacks: LuaAgentHarnessCallbacks(
          onEvent: (type, data) {
            if (type == 'plugin.lifecycle.failed') {
              lifecycleFailures.add(data);
            }
            if (type == 'plugin.lifecycle.completed') {
              lifecycleCompletions.add(data);
            }
          },
          onStatus: (status, {error}) => statuses.add(status),
          onProviderItems: (_) {},
        ),
        cancellation: cancellation,
      );

      Object? driverFailure;
      try {
        await run('error', _RecordingModelGateway(), CancellationToken());
      } on Object catch (error) {
        driverFailure = error;
      }
      expect(
        driverFailure,
        isA<StateError>().having(
          (error) => '$error',
          'message',
          contains('driver exploded'),
        ),
      );
      final cancellingModel = _BlockingModelGateway();
      final cancellation = CancellationToken();
      final cancelledRun = run('cancel', cancellingModel, cancellation);
      final cancelledExpectation = expectLater(
        cancelledRun,
        throwsA(isA<AgentCancelledException>()),
      );
      await cancellingModel.started.future;
      cancellation.cancel();
      await cancelledExpectation;

      const scope = PluginStateScope.session(
        pluginId: 'acme.lifecycle',
        sessionId: 'session-1',
      );
      expect(lifecycleFailures, isEmpty);
      expect(lifecycleCompletions.map((event) => event['lifecycle']), <String>[
        'error',
        'cancel',
      ]);
      expect((await state.read(scope, 'error'))?.value, 'error');
      expect((await state.read(scope, 'cancel'))?.value, 'cancel');
      expect(
        statuses,
        containsAll(<AgentSessionStatus>[
          AgentSessionStatus.failed,
          AgentSessionStatus.idle,
        ]),
      );
    },
  );

  test(
    'cancelling mid model stream keeps after-model hooks graceful',
    () async {
      final bundle = _afterModelLifecycleBundle();
      final revisions = PluginRevisionCatalog(
        loader: _BundleLoader(bundle),
        cache: _MemoryRevisionCache(),
      );
      await revisions.reload(
        bundle.descriptor.id,
        agentId: 'agent-1',
        approvedCapabilities: bundle.descriptor.requestedCapabilities.toSet(),
      );
      final runtime = _pluginRuntime(stagedHost, revisions);
      addTearDown(runtime.close);
      final statuses = <AgentSessionStatus>[];
      final lifecycleFailures = <Map<String, dynamic>>[];
      final lifecycleCompletions = <Map<String, dynamic>>[];
      final cancellingModel = _BlockingModelGateway();
      final cancellation = CancellationToken();

      final cancelledRun = LuaAgentHarness(runtime: runtime).startTurn(
        request: LuaAgentHarnessRequest(
          definition: _terminalLifecycleDefinition,
          sessionId: 'session-1',
          turnId: 'turn-cancel',
          workspaceRoot: Directory.current.path,
          prompt: 'cancel',
          modelId: 'model',
          model: cancellingModel,
          modelCapabilities: const AgentModelCapabilities(
            streaming: AgentCapabilitySupport.supported,
          ),
          history: const <ConversationItem>[],
          allowedCapabilitiesByPlugin: <String, Set<String>>{
            bundle.descriptor.id: bundle.descriptor.requestedCapabilities
                .toSet(),
          },
          state: MemoryPluginStateStore(),
        ),
        callbacks: LuaAgentHarnessCallbacks(
          onEvent: (type, data) {
            if (type == 'plugin.lifecycle.failed') lifecycleFailures.add(data);
            if (type == 'plugin.lifecycle.completed') {
              lifecycleCompletions.add(data);
            }
          },
          onStatus: (status, {error}) => statuses.add(status),
          onProviderItems: (_) {},
        ),
        cancellation: cancellation,
      );
      final cancelledExpectation = expectLater(
        cancelledRun,
        throwsA(isA<AgentCancelledException>()),
      );
      await cancellingModel.started.future;
      cancellation.cancel();
      // The cancelled model stream tears down through the runtime's own cell
      // close; an after-model hook started against the cancelled token must
      // fold into that cancellation instead of failing the turn or escaping
      // as an unhandled error.
      await cancelledExpectation;

      expect(lifecycleFailures, isEmpty);
      expect(
        lifecycleCompletions.map((event) => event['lifecycle']),
        contains('cancel'),
      );
      expect(statuses, contains(AgentSessionStatus.idle));
      expect(statuses, isNot(contains(AgentSessionStatus.failed)));
    },
  );

  test(
    'durable execution accepts only the registered scheduled hook',
    () async {
      final bundle = _terminalLifecycleBundle();
      final cache = _MemoryRevisionCache();
      final revisions = PluginRevisionCatalog(
        loader: _BundleLoader(bundle),
        cache: cache,
      );
      await revisions.reload(
        bundle.descriptor.id,
        agentId: 'agent-1',
        approvedCapabilities: bundle.descriptor.requestedCapabilities.toSet(),
      );
      final runtime = _pluginRuntime(stagedHost, revisions);
      addTearDown(runtime.close);
      final grants = MemoryAgentPluginGrantStore();
      for (final capability in bundle.descriptor.requestedCapabilities) {
        await grants.grant(
          AgentPluginGrantDto(
            agentId: 'agent-1',
            pluginId: bundle.descriptor.id,
            capability: capability,
          ),
        );
      }
      final jobs = MemoryPluginJobStore();
      final clock = _GoalClock(DateTime.utc(2026, 8, 12));
      final executor = LuaPluginScheduledJobExecutor(
        runtime: runtime,
        state: MemoryPluginStateStore(),
        grants: grants,
        jobs: () => jobs,
        clock: clock,
        ids: _HostIds('scheduled'),
        resolveContext: (_) async => const PluginScheduledExecutionContext(
          agentId: 'agent-1',
          sessionId: 'session-1',
          workingDirectory: '.',
        ),
      );
      final dueAt = clock.nowUtc();

      final result = await executor.execute(
        PluginJob(
          id: 'valid',
          pluginId: bundle.descriptor.id,
          executionRevisionHash: bundle.revision.executionRevisionHash,
          bindingId: 'scheduled',
          payload: const <String, dynamic>{'prompt': 'continue'},
          dueAt: dueAt,
          agentId: 'agent-1',
          sessionId: 'session-1',
        ),
        const _NeverCancelled(),
      );
      expect(result.continueTurn, isTrue);
      expect(result.prompt, 'continue');

      await expectLater(
        executor.execute(
          PluginJob(
            id: 'invalid',
            pluginId: bundle.descriptor.id,
            executionRevisionHash: bundle.revision.executionRevisionHash,
            bindingId: 'run',
            payload: const <String, dynamic>{},
            dueAt: dueAt,
            agentId: 'agent-1',
            sessionId: 'session-1',
          ),
          const _NeverCancelled(),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => '$error',
            'message',
            contains('registered scheduled hook'),
          ),
        ),
      );
    },
  );

  test('scheduled state cells reject malformed persisted values', () async {
    final bundle = _scheduledStateSchemaBundle();
    final revisions = PluginRevisionCatalog(
      loader: _BundleLoader(bundle),
      cache: _MemoryRevisionCache(),
    );
    await revisions.reload(
      bundle.descriptor.id,
      agentId: 'agent-1',
      approvedCapabilities: const <String>{'state.read'},
    );
    final runtime = _pluginRuntime(stagedHost, revisions);
    addTearDown(runtime.close);
    final grants = MemoryAgentPluginGrantStore();
    await grants.grant(
      const AgentPluginGrantDto(
        agentId: 'agent-1',
        pluginId: 'acme.scheduled-state-schema',
        capability: 'state.read',
      ),
    );
    final state = MemoryPluginStateStore();
    await state.compareAndSet(
      const PluginStateScope.session(
        pluginId: 'acme.scheduled-state-schema',
        sessionId: 'session-1',
      ),
      'value',
      expectedRevision: 0,
      value: 42,
    );
    final executor = LuaPluginScheduledJobExecutor(
      runtime: runtime,
      state: state,
      grants: grants,
      jobs: MemoryPluginJobStore.new,
      clock: _GoalClock(DateTime.utc(2026, 8, 12)),
      ids: _HostIds('scheduled-schema'),
      resolveContext: (_) async => const PluginScheduledExecutionContext(
        agentId: 'agent-1',
        sessionId: 'session-1',
        workingDirectory: '.',
      ),
    );

    await expectLater(
      executor.execute(
        PluginJob(
          id: 'schema',
          pluginId: bundle.descriptor.id,
          executionRevisionHash: bundle.revision.executionRevisionHash,
          bindingId: 'scheduled',
          payload: const <String, dynamic>{},
          dueAt: DateTime.utc(2026, 8, 12),
          agentId: 'agent-1',
          sessionId: 'session-1',
        ),
        const _NeverCancelled(),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'scheduler enqueue validates the exact handler payload schema',
    () async {
      final jobs = MemoryPluginJobStore();
      final clock = _GoalClock(DateTime.utc(2026, 8, 12));

      await _runHostPrimitiveTurn(
        stagedHost: stagedHost,
        bundle: _scheduledPayloadSchemaBundle(),
        agentId: 'agent-scheduled-payload',
        sessionId: 'session-scheduled-payload',
        prompt: 'unused',
        grantedCapabilities: const <String>{'scheduler.manage'},
        jobs: jobs,
        clock: clock,
        ids: _HostIds('payload'),
        policy: const _AllowPolicy(),
      );

      expect((await jobs.get('payload-1'))?.bindingId, 'scheduled');
      expect((await jobs.get('payload-1'))?.payload, <String, Object?>{
        'count': 1,
      });
      expect((await jobs.get('payload-2'))?.payload, <String, Object?>{
        'count': 2,
      });
      expect(await jobs.get('payload-3'), isNull);
    },
  );

  test('durable scheduled payloads and nested enqueue fail closed', () async {
    final bundle = _scheduledPayloadSchemaBundle();
    final revisions = PluginRevisionCatalog(
      loader: _BundleLoader(bundle),
      cache: _MemoryRevisionCache(),
    );
    await revisions.reload(
      bundle.descriptor.id,
      agentId: 'agent-1',
      approvedCapabilities: const <String>{'scheduler.manage'},
    );
    final runtime = _pluginRuntime(stagedHost, revisions);
    addTearDown(runtime.close);
    final grants = MemoryAgentPluginGrantStore();
    await grants.grant(
      const AgentPluginGrantDto(
        agentId: 'agent-1',
        pluginId: 'acme.scheduledschema',
        capability: 'scheduler.manage',
      ),
    );
    final jobs = MemoryPluginJobStore();
    final executor = LuaPluginScheduledJobExecutor(
      runtime: runtime,
      state: MemoryPluginStateStore(),
      grants: grants,
      jobs: () => jobs,
      clock: _GoalClock(DateTime.utc(2026, 8, 12)),
      ids: _HostIds('nested'),
      resolveContext: (_) async => const PluginScheduledExecutionContext(
        agentId: 'agent-1',
        sessionId: 'session-1',
        workingDirectory: '.',
      ),
    );

    PluginJob job(String id, String bindingId, Map<String, dynamic> payload) =>
        PluginJob(
          id: id,
          pluginId: bundle.descriptor.id,
          executionRevisionHash: bundle.revision.executionRevisionHash,
          bindingId: bindingId,
          payload: payload,
          dueAt: DateTime.utc(2026, 8, 12),
          agentId: 'agent-1',
          sessionId: 'session-1',
        );

    final valid = await executor.execute(
      job('valid', 'scheduled', <String, dynamic>{'count': 1}),
      const _NeverCancelled(),
    );
    expect(valid.prompt, '1');

    for (final invalid in <PluginJob>[
      job('malformed', 'scheduled', <String, dynamic>{'count': 'bad'}),
      job('foreign', 'other', <String, dynamic>{'count': 1}),
      job('nested', 'scheduled', <String, dynamic>{'nested': true}),
    ]) {
      await expectLater(
        executor.execute(invalid, const _NeverCancelled()),
        throwsA(isA<StateError>()),
        reason: invalid.id,
      );
    }
    expect(await jobs.get('nested-1'), isNull);
  });

  test(
    'durable execution stays pinned to its exact revision after reload',
    () async {
      final first = _scheduledRevisionBundle('one');
      final second = _scheduledRevisionBundle('two');
      final loader = _BundleMapLoader(<String, PluginBundle>{
        first.descriptor.id: first,
      });
      final cache = _MemoryRevisionCache();
      final firstCatalog = PluginRevisionCatalog(loader: loader, cache: cache);
      await firstCatalog.reload(
        first.descriptor.id,
        agentId: 'agent-1',
        approvedCapabilities: const <String>{},
      );
      loader.bundles[first.descriptor.id] = second;
      await firstCatalog.reload(
        second.descriptor.id,
        agentId: 'agent-1',
        approvedCapabilities: const <String>{},
      );

      final restartedCatalog = PluginRevisionCatalog(
        loader: loader,
        cache: cache,
      );
      final runtime = _pluginRuntime(stagedHost, restartedCatalog);
      addTearDown(runtime.close);
      final executor = LuaPluginScheduledJobExecutor(
        runtime: runtime,
        state: MemoryPluginStateStore(),
        grants: MemoryAgentPluginGrantStore(),
        jobs: MemoryPluginJobStore.new,
        clock: _GoalClock(DateTime.utc(2026, 8, 12)),
        ids: _HostIds('scheduled-revision'),
        resolveContext: (_) async => const PluginScheduledExecutionContext(
          agentId: 'agent-1',
          sessionId: 'session-1',
          workingDirectory: '.',
        ),
      );

      final result = await executor.execute(
        PluginJob(
          id: 'old-revision',
          pluginId: first.descriptor.id,
          executionRevisionHash: first.revision.executionRevisionHash,
          bindingId: 'scheduled',
          payload: const <String, dynamic>{},
          dueAt: DateTime.utc(2026, 8, 12),
          agentId: 'agent-1',
          sessionId: 'session-1',
        ),
        const _NeverCancelled(),
      );

      expect(result.prompt, 'one');
      expect(
        (await restartedCatalog.resolveForAgent(
          'agent-1',
          first.descriptor.id,
        )).revision.executionRevisionHash,
        second.revision.executionRevisionHash,
      );
      await expectLater(
        executor.execute(
          PluginJob(
            id: 'missing-revision',
            pluginId: first.descriptor.id,
            executionRevisionHash: 'missing-execution-revision',
            bindingId: 'scheduled',
            payload: const <String, dynamic>{},
            dueAt: DateTime.utc(2026, 8, 12),
            agentId: 'agent-1',
            sessionId: 'session-1',
          ),
          const _NeverCancelled(),
        ),
        throwsA(
          isA<PluginRevisionUnavailable>().having(
            (error) => error.message,
            'message',
            contains('exact execution revision'),
          ),
        ),
      );
    },
  );

  test(
    'durable execution fails explicitly after a required grant is revoked',
    () async {
      final bundle = _scheduledRevisionBundle(
        'revoked',
        capabilities: const <String>['state.write'],
        requiredCapabilities: const <String>['state.write'],
      );
      final revisions = PluginRevisionCatalog(
        loader: _BundleLoader(bundle),
        cache: _MemoryRevisionCache(),
      );
      await revisions.reload(
        bundle.descriptor.id,
        agentId: 'agent-1',
        approvedCapabilities: bundle.descriptor.requestedCapabilities.toSet(),
      );
      final runtime = _pluginRuntime(stagedHost, revisions);
      addTearDown(runtime.close);
      final grants = MemoryAgentPluginGrantStore();
      final grant = AgentPluginGrantDto(
        agentId: 'agent-1',
        pluginId: bundle.descriptor.id,
        capability: 'state.write',
      );
      await grants.grant(grant);
      await grants.revoke(grant);
      final executor = LuaPluginScheduledJobExecutor(
        runtime: runtime,
        state: MemoryPluginStateStore(),
        grants: grants,
        jobs: MemoryPluginJobStore.new,
        clock: _GoalClock(DateTime.utc(2026, 8, 12)),
        ids: _HostIds('revoked'),
        resolveContext: (_) async => const PluginScheduledExecutionContext(
          agentId: 'agent-1',
          sessionId: 'session-1',
          workingDirectory: '.',
        ),
      );

      await expectLater(
        executor.execute(
          PluginJob(
            id: 'revoked-revision',
            pluginId: bundle.descriptor.id,
            executionRevisionHash: bundle.revision.executionRevisionHash,
            bindingId: 'scheduled',
            payload: const <String, dynamic>{},
            dueAt: DateTime.utc(2026, 8, 12),
            agentId: 'agent-1',
            sessionId: 'session-1',
          ),
          const _NeverCancelled(),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => '$error',
            'message',
            allOf(contains('disabled'), contains('state.write')),
          ),
        ),
      );
    },
  );

  test(
    'scheduled handlers use scoped state, jobs, and UI through the broker',
    () async {
      final bundle = _scheduledCallbacksBundle();
      final revisions = PluginRevisionCatalog(
        loader: _BundleLoader(bundle),
        cache: _MemoryRevisionCache(),
      );
      await revisions.reload(
        bundle.descriptor.id,
        agentId: 'agent-1',
        approvedCapabilities: bundle.descriptor.requestedCapabilities.toSet(),
      );
      final runtime = _pluginRuntime(stagedHost, revisions);
      addTearDown(runtime.close);
      final grants = MemoryAgentPluginGrantStore();
      for (final capability in bundle.descriptor.requestedCapabilities) {
        await grants.grant(
          AgentPluginGrantDto(
            agentId: 'agent-1',
            pluginId: bundle.descriptor.id,
            capability: capability,
          ),
        );
      }
      final state = MemoryPluginStateStore();
      final jobs = MemoryPluginJobStore();
      final clock = _GoalClock(DateTime.utc(2026, 8, 12));
      final uiEvents = <String>[];
      final executor = LuaPluginScheduledJobExecutor(
        runtime: runtime,
        state: state,
        grants: grants,
        jobs: () => jobs,
        clock: clock,
        ids: _HostIds('callback'),
        resolveContext: (_) async => const PluginScheduledExecutionContext(
          agentId: 'agent-1',
          sessionId: 'session-1',
          workspaceId: 'workspace-1',
          workingDirectory: '.',
        ),
        onUiEvent: (job, context, operation, arguments) {
          final value = Map<String, Object?>.from(arguments['value']! as Map);
          uiEvents.add('$operation:${value['message']}');
        },
      );

      final result = await executor.execute(
        PluginJob(
          id: 'callbacks',
          pluginId: bundle.descriptor.id,
          executionRevisionHash: bundle.revision.executionRevisionHash,
          bindingId: 'scheduled',
          payload: const <String, dynamic>{'prompt': 'resume'},
          dueAt: clock.nowUtc(),
          agentId: 'agent-1',
          sessionId: 'session-1',
        ),
        const _NeverCancelled(),
      );

      expect(result.continueTurn, isTrue);
      expect(result.prompt, 'resume');
      expect(uiEvents, <String>['ui.status:scheduled']);
      expect(
        (await state.read(
          const PluginStateScope.plugin(pluginId: 'acme.scheduled'),
          'value',
        ))?.value,
        'plugin',
      );
      expect(
        (await state.read(
          const PluginStateScope.agent(
            pluginId: 'acme.scheduled',
            agentId: 'agent-1',
          ),
          'value',
        ))?.value,
        'agent',
      );
      expect(
        (await state.read(
          const PluginStateScope.workspace(
            pluginId: 'acme.scheduled',
            workspaceId: 'workspace-1',
          ),
          'value',
        ))?.value,
        'workspace',
      );
      expect((await jobs.get('callback-1'))?.status, PluginJobStatus.cancelled);
      expect((await jobs.get('callback-2'))?.status, PluginJobStatus.pending);

      await expectLater(
        executor.execute(
          PluginJob(
            id: 'foreign-owner',
            pluginId: bundle.descriptor.id,
            executionRevisionHash: bundle.revision.executionRevisionHash,
            bindingId: 'scheduled',
            payload: const <String, dynamic>{},
            dueAt: clock.nowUtc(),
            agentId: 'other-agent',
            sessionId: 'session-1',
          ),
          const _NeverCancelled(),
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('scheduler.cancel cancels only an owned pending durable job', () async {
    final bundle = _schedulerCancelBundle();
    final revisions = PluginRevisionCatalog(
      loader: _BundleLoader(bundle),
      cache: _MemoryRevisionCache(),
    );
    await revisions.reload(
      bundle.descriptor.id,
      agentId: 'agent-1',
      approvedCapabilities: bundle.descriptor.requestedCapabilities.toSet(),
    );
    final runtime = _pluginRuntime(stagedHost, revisions);
    addTearDown(runtime.close);
    final jobs = MemoryPluginJobStore();
    final clock = _GoalClock(DateTime.utc(2026, 8, 12));
    await jobs.enqueue(
      PluginJob(
        id: 'foreign',
        pluginId: 'other.plugin',
        executionRevisionHash: 'other-execution-revision',
        bindingId: 'scheduled',
        payload: const <String, dynamic>{},
        dueAt: clock.nowUtc(),
        agentId: 'agent-1',
        sessionId: 'session-1',
      ),
    );

    await LuaAgentHarness(runtime: runtime).startTurn(
      request: LuaAgentHarnessRequest(
        definition: const AgentDefinitionDto(
          version: 5,
          id: 'agent-1',
          name: 'Scheduler Agent',
          description: '',
          mode: AgentMode.primary,
          model: AgentModelSelectionDto(source: AgentModelSource.session),
          driverId: 'acme.scheduler/driver',
          extensionIds: <String>[],
          toolIds: <String>[],
          pluginSettings: <String, Map<String, dynamic>>{},
          callableAgentIds: <String>[],
          prompt: '',
          contentHash: 'agent-hash',
          sourcePath: 'agent.md',
        ),
        sessionId: 'session-1',
        turnId: 'turn-1',
        workspaceRoot: Directory.current.path,
        prompt: 'run',
        modelId: 'unused',
        model: _RecordingModelGateway(),
        modelCapabilities: const AgentModelCapabilities(),
        history: const <ConversationItem>[],
        allowedCapabilitiesByPlugin: const <String, Set<String>>{
          'acme.scheduler': <String>{'scheduler.manage'},
        },
        jobs: jobs,
        clock: clock,
        ids: _HostIds('own'),
      ),
      callbacks: LuaAgentHarnessCallbacks(
        onEvent: (_, _) {},
        onStatus: (_, {error}) {},
        onProviderItems: (_) {},
      ),
      cancellation: CancellationToken(),
    );

    expect((await jobs.get('own-1'))!.status, PluginJobStatus.cancelled);
    expect((await jobs.get('foreign'))!.status, PluginJobStatus.pending);
  });

  test('optional callback ports fail explicitly through the Lua SDK', () async {
    await _runHostPrimitiveTurn(
      stagedHost: stagedHost,
      bundle: _unavailableCallbacksBundle(),
      agentId: 'agent-unavailable-callbacks',
      sessionId: 'session-unavailable-callbacks',
      prompt: 'verify unavailable ports',
      grantedCapabilities: const <String>{
        'state.read',
        'state.write',
        'scheduler.manage',
        'ui.publish',
        'process.execute',
        'workspace.read',
        'network.access',
        'secret.access',
      },
      policy: const _AllowPolicy(),
    );
  });

  test('collaboration extension owns root and subagent prompt text', () async {
    const catalog = BuiltInPluginCatalog();
    final revisions = PluginRevisionCatalog(
      loader: catalog,
      cache: _MemoryRevisionCache(),
    );
    final runtime = _pluginRuntime(stagedHost, revisions);
    addTearDown(runtime.close);
    final grants = <String, Set<String>>{};
    for (final pluginId in const <String>[
      'tinest.standard',
      'tinest.collaboration',
    ]) {
      final bundle = await catalog.load(pluginId);
      final capabilities = bundle.descriptor.requestedCapabilities.toSet();
      grants[pluginId] = capabilities;
      await revisions.reload(
        pluginId,
        agentId: 'collaboration-agent',
        approvedCapabilities: capabilities,
        inspector: runtime,
      );
    }
    const definition = AgentDefinitionDto(
      version: 5,
      id: 'collaboration-agent',
      name: 'Collaboration Agent',
      description: '',
      mode: AgentMode.primary,
      model: AgentModelSelectionDto(source: AgentModelSource.session),
      driverId: 'tinest.standard/driver',
      extensionIds: <String>['tinest.collaboration'],
      toolIds: <String>[],
      pluginSettings: <String, Map<String, dynamic>>{},
      callableAgentIds: <String>[],
      prompt: 'AGENT BODY',
      contentHash: 'collaboration-agent-hash',
      sourcePath: 'agent.md',
    );
    final driverState = MemoryPluginStateStore();

    Future<String> instructionsFor({
      required String path,
      required bool isRoot,
    }) async {
      final model = _RecordingModelGateway();
      await LuaAgentHarness(runtime: runtime).startTurn(
        request: LuaAgentHarnessRequest(
          definition: definition,
          sessionId: isRoot ? 'root-session' : 'child-session',
          turnId: isRoot ? 'root-turn' : 'child-turn',
          workspaceRoot: Directory.current.path,
          prompt: 'work',
          modelId: 'model',
          model: model,
          modelCapabilities: const AgentModelCapabilities(
            streaming: AgentCapabilitySupport.supported,
          ),
          history: const <ConversationItem>[],
          allowedCapabilitiesByPlugin: grants,
          state: driverState,
          extensionData: <String, Object?>{
            'host_policy': <String, Object?>{
              'permission_mode': 'workspaceWrite',
              'workspace_root': Directory.current.path,
            },
            'collaboration': <String, Object?>{
              'path': path,
              'is_root': isRoot,
              'max_concurrent_turns': 4,
            },
          },
        ),
        callbacks: LuaAgentHarnessCallbacks(
          onEvent: (_, _) {},
          onStatus: (_, {error}) {},
          onProviderItems: (_) {},
        ),
        cancellation: CancellationToken(),
      );
      return model.requests.single.blocks
          .map((block) => block.content)
          .join('\n\n');
    }

    final root = await instructionsFor(path: '/root', isRoot: true);
    final child = await instructionsFor(path: '/root/reviewer', isRoot: false);
    expect(root, contains('root agent at path `/root`'));
    expect(root, contains('Permission mode: workspaceWrite'));
    expect(root, contains(Directory.current.path));
    expect(root, contains('### Coordinating subagents'));
    expect(root, isNot(contains('### Working as a subagent')));
    expect(child, contains('subagent `/root/reviewer`'));
    expect(child, contains('### Working as a subagent'));
    expect(child, isNot(contains('### Coordinating subagents')));
  });

  test(
    'before_turn capability limit blocks write and process but allows read',
    () async {
      final host = _CountingPrimitiveHost();

      final errors = await _runRestrictedTurn(
        stagedHost: stagedHost,
        bundles: <PluginBundle>[
          _restrictedDriverBundle(
            capabilityLimit: const <String>['workspace.read'],
          ),
        ],
        extensionIds: const <String>['acme.harness/plan'],
        primitives: host.registry,
      );

      expect(host.counts, <int>[1, 0, 0]);
      expect(errors, <bool>[false, true, true]);
    },
  );

  test(
    'tinest.plan default contributes no prompt or capability restriction',
    () async {
      final model = await _runPlanPromptTurn(
        stagedHost: stagedHost,
        enabled: false,
      );
      expect(model.requests, hasLength(1));
      expect(
        model.requests.single.blocks.map((block) => block.content),
        everyElement(isNot(contains('# Plan Mode'))),
      );

      final host = _CountingPrimitiveHost();
      final errors = await _runRestrictedTurn(
        stagedHost: stagedHost,
        bundles: <PluginBundle>[
          _unrestrictedDriverBundle(),
          await const BuiltInPluginCatalog().load('tinest.plan'),
        ],
        extensionIds: const <String>['tinest.plan'],
        primitives: host.registry,
      );

      expect(host.counts, <int>[1, 1, 1]);
      expect(errors, <bool>[false, false, false]);
    },
    tags: const <String>['feature_test__session_plan__unit'],
  );

  test(
    'tinest.plan enabled owns exact prompt order and capability restriction',
    () async {
      const catalog = BuiltInPluginCatalog();
      final model = await _runPlanPromptTurn(
        stagedHost: stagedHost,
        enabled: true,
      );
      final standard = await catalog.load('tinest.standard');
      final plan = await catalog.load('tinest.plan');
      final defaultPrompt = String.fromCharCodes(
        standard.assets['prompts/default.md']!,
      );
      final planPrompt = String.fromCharCodes(
        plan.assets['prompts/plan_mode.md']!,
      );
      expect(
        model.requests.single.blocks.map((block) => block.toJson()),
        <Map<String, dynamic>>[
          <String, dynamic>{'role': 'system', 'content': defaultPrompt},
          <String, dynamic>{'role': 'system', 'content': planPrompt},
          <String, dynamic>{'role': 'system', 'content': 'AGENT BODY'},
        ],
      );

      final host = _CountingPrimitiveHost();
      final errors = await _runRestrictedTurn(
        stagedHost: stagedHost,
        bundles: <PluginBundle>[_unrestrictedDriverBundle(), plan],
        extensionIds: const <String>['tinest.plan'],
        sessionControlValues: const <String, Object?>{'tinest.plan/mode': true},
        primitives: host.registry,
      );

      expect(host.counts, <int>[1, 0, 0]);
      expect(errors, <bool>[false, true, true]);
    },
    tags: const <String>[
      'feature_test__session_plan__unit',
      'feature_test__session_plan__verticalSlice',
    ],
  );

  test(
    'tinest.plan update_plan atomically replaces an existing plan',
    () async {
      const agentId = 'plan-cas-agent';
      const sessionId = 'plan-cas-session';
      const catalog = BuiltInPluginCatalog();
      final loader = _BundleMapLoader(<String, PluginBundle>{
        'tinest.standard': await catalog.load('tinest.standard'),
        'tinest.plan': await catalog.load('tinest.plan'),
      });
      final revisions = PluginRevisionCatalog(
        loader: loader,
        cache: _MemoryRevisionCache(),
      );
      final capabilities = <String, Set<String>>{};
      for (final entry in loader.bundles.entries) {
        final granted = entry.value.descriptor.requestedCapabilities.toSet();
        capabilities[entry.key] = granted;
        await revisions.reload(
          entry.key,
          agentId: agentId,
          approvedCapabilities: granted,
        );
      }
      final runtime = _pluginRuntime(stagedHost, revisions);
      addTearDown(runtime.close);
      final state = MemoryPluginStateStore();
      final model = _PlanUpdateModelGateway();
      final toolErrors = <bool>[];
      final turnErrors = <String>[];

      await LuaAgentHarness(runtime: runtime).startTurn(
        request: LuaAgentHarnessRequest(
          definition: const AgentDefinitionDto(
            version: 5,
            id: agentId,
            name: 'Plan Agent',
            description: '',
            mode: AgentMode.primary,
            model: AgentModelSelectionDto(source: AgentModelSource.session),
            driverId: 'tinest.standard/driver',
            extensionIds: <String>['tinest.plan'],
            toolIds: <String>['tinest.plan/update_plan'],
            pluginSettings: <String, Map<String, dynamic>>{},
            callableAgentIds: <String>[],
            prompt: '',
            contentHash: 'agent-hash',
            sourcePath: 'agent.md',
          ),
          sessionId: sessionId,
          turnId: 'turn-1',
          workspaceRoot: Directory.current.path,
          prompt: 'plan twice',
          modelId: 'plan-model',
          model: model,
          modelCapabilities: const AgentModelCapabilities(
            streaming: AgentCapabilitySupport.supported,
            toolCalling: AgentCapabilitySupport.supported,
            functionTools: AgentCapabilitySupport.supported,
          ),
          history: const <ConversationItem>[],
          allowedCapabilitiesByPlugin: capabilities,
          state: state,
        ),
        callbacks: LuaAgentHarnessCallbacks(
          onEvent: (type, data) {
            if (type == 'tool.completed') {
              toolErrors.add(data['isError'] == true);
            }
          },
          onStatus: (_, {error}) {
            if (error != null) turnErrors.add(error);
          },
          onProviderItems: (_) {},
        ),
        cancellation: CancellationToken(),
      );

      expect(turnErrors, isEmpty);
      expect(model.requests, hasLength(3));
      expect(toolErrors, <bool>[false, false]);
      final stored = await state.read(
        const PluginStateScope.session(
          pluginId: 'tinest.plan',
          sessionId: sessionId,
        ),
        'plan',
      );
      expect(stored?.revision, 2);
      expect(
        (stored!.value! as Map<Object?, Object?>)['explanation'],
        'Second',
      );
    },
    tags: const <String>['feature_test__session_plan__verticalSlice'],
  );

  test(
    'tinest.terminal preserves its process handle across model tool rounds',
    () async {
      const agentId = 'terminal-agent';
      const catalog = BuiltInPluginCatalog();
      final bundles = <String, PluginBundle>{
        'tinest.standard': await catalog.load('tinest.standard'),
        'tinest.terminal': await catalog.load('tinest.terminal'),
      };
      final revisions = PluginRevisionCatalog(
        loader: _BundleMapLoader(bundles),
        cache: _MemoryRevisionCache(),
      );
      final runtime = _pluginRuntime(stagedHost, revisions);
      addTearDown(runtime.close);
      final capabilities = await _prepareBuiltinPlugins(
        catalog: catalog,
        revisions: revisions,
        runtime: runtime,
        agentId: agentId,
        pluginIds: bundles.keys.toList(growable: false),
      );
      final primitives = _TerminalPrimitiveHost();
      final model = _TerminalModelGateway();
      final approvals = _RecordingApprovalCoordinator(
        ApprovalDecision.approved,
      );
      final persisted = <ConversationItem>[];
      final turnErrors = <String>[];

      await LuaAgentHarness(runtime: runtime).startTurn(
        request: LuaAgentHarnessRequest(
          definition: const AgentDefinitionDto(
            version: 5,
            id: agentId,
            name: 'Terminal Agent',
            description: '',
            mode: AgentMode.primary,
            model: AgentModelSelectionDto(source: AgentModelSource.session),
            driverId: 'tinest.standard/driver',
            extensionIds: <String>[],
            toolIds: <String>[
              'tinest.terminal/exec_command',
              'tinest.terminal/write_stdin',
            ],
            pluginSettings: <String, Map<String, dynamic>>{},
            callableAgentIds: <String>[],
            prompt: '',
            contentHash: 'terminal-agent-hash',
            sourcePath: 'terminal-agent.md',
          ),
          sessionId: 'terminal-session',
          turnId: 'terminal-turn',
          workspaceRoot: Directory.current.path,
          prompt: 'Run the shell',
          modelId: 'terminal-model',
          model: model,
          modelCapabilities: const AgentModelCapabilities(
            streaming: AgentCapabilitySupport.supported,
            toolCalling: AgentCapabilitySupport.supported,
            functionTools: AgentCapabilitySupport.supported,
          ),
          history: const <ConversationItem>[],
          allowedCapabilitiesByPlugin: capabilities,
          primitives: primitives.registry,
          state: MemoryPluginStateStore(),
          approvals: approvals,
          policyFactory: (_) => const _AskPolicy(),
        ),
        callbacks: LuaAgentHarnessCallbacks(
          onEvent: (_, _) {},
          onStatus: (_, {error}) {
            if (error != null) turnErrors.add(error);
          },
          onProviderItems: persisted.addAll,
        ),
        cancellation: CancellationToken(),
      );

      expect(turnErrors, isEmpty);
      expect(model.execResult, <String, Object?>{
        'output': '',
        'running': true,
        'wall_time_ms': 1,
        'session_id': 73,
      });
      expect(model.stdinResult['output'], contains('tinyrack-exec-probe'));
      expect(primitives.writes, <String>['tinyrack-exec-probe\n']);
      expect(
        approvals.invocations.map((invocation) => invocation.name),
        <String>['exec_command', 'write_stdin'],
      );
      expect(
        approvals.invocations.map((invocation) => invocation.risk),
        everyElement(AgentToolRisk.command),
      );
      expect(persisted.whereType<ToolResultConversationItem>(), hasLength(2));
    },
    tags: const <String>['feature_test__tool_exec_session__unit'],
  );

  test(
    'before_turn capability limits intersect in Agent extension order',
    () async {
      final host = _CountingPrimitiveHost();

      final errors = await _runRestrictedTurn(
        stagedHost: stagedHost,
        bundles: <PluginBundle>[
          _restrictedDriverBundle(
            capabilityLimit: const <String>[
              'workspace.read',
              'workspace.patch',
            ],
          ),
          _restrictionExtensionBundle(
            id: 'acme.restrict-process',
            capabilityLimit: const <String>[
              'workspace.read',
              'process.execute',
            ],
          ),
        ],
        extensionIds: const <String>[
          'acme.harness/plan',
          'acme.restrict-process/restriction',
        ],
        primitives: host.registry,
      );

      expect(host.counts, <int>[1, 0, 0]);
      expect(errors, <bool>[false, true, true]);
    },
  );

  test(
    'tool UI publication renders a pinned timeline snapshot after completion',
    () async {
      final bundle = _uiPublicationBundle();
      final revisions = PluginRevisionCatalog(
        loader: _BundleLoader(bundle),
        cache: _MemoryRevisionCache(),
      );
      await revisions.reload(
        bundle.descriptor.id,
        agentId: 'agent-1',
        approvedCapabilities: bundle.descriptor.requestedCapabilities.toSet(),
      );
      final runtime = _pluginRuntime(stagedHost, revisions);
      addTearDown(runtime.close);
      final events = <({String type, Map<String, dynamic> data})>[];
      final snapshots = <LuaAgentHarnessUiSnapshot>[];

      await LuaAgentHarness(runtime: runtime).startTurn(
        request: LuaAgentHarnessRequest(
          definition: const AgentDefinitionDto(
            version: 5,
            id: 'agent-1',
            name: 'UI Agent',
            description: '',
            mode: AgentMode.primary,
            model: AgentModelSelectionDto(source: AgentModelSource.session),
            driverId: 'acme.ui/driver',
            extensionIds: <String>[],
            toolIds: <String>['acme.ui/publish'],
            pluginSettings: <String, Map<String, dynamic>>{},
            callableAgentIds: <String>[],
            prompt: '',
            contentHash: 'agent-hash',
            sourcePath: 'agent.md',
          ),
          sessionId: 'session-1',
          turnId: 'turn-1',
          workspaceRoot: Directory.current.path,
          prompt: 'publish',
          modelId: 'unused',
          model: _RecordingModelGateway(),
          modelCapabilities: const AgentModelCapabilities(),
          history: const <ConversationItem>[],
          allowedCapabilitiesByPlugin: <String, Set<String>>{
            bundle.descriptor.id: bundle.descriptor.requestedCapabilities
                .toSet(),
          },
        ),
        callbacks: LuaAgentHarnessCallbacks(
          onEvent: (type, data) => events.add((type: type, data: data)),
          onStatus: (_, {error}) {},
          onProviderItems: (_) {},
          onUiSnapshot: snapshots.add,
        ),
        cancellation: CancellationToken(),
      );

      final completedIndex = events.indexWhere(
        (event) => event.type == 'tool.completed',
      );
      final uiIndex = events.indexWhere((event) => event.type == 'plugin.ui');
      expect(completedIndex, greaterThanOrEqualTo(0));
      expect(uiIndex, greaterThan(completedIndex));
      final uiEvent = events[uiIndex].data;
      expect(uiEvent['callId'], 'call-ui');
      expect(uiEvent['contributionId'], 'acme.ui/card');
      final document = PluginUiDocumentDto.fromJson(
        Map<String, dynamic>.from(uiEvent['document']! as Map),
      );
      expect(document.pluginId, 'acme.ui');
      expect(document.revisionHash, 'acme.ui-execution-revision');
      expect(document.slot, PluginUiSlot.timeline);
      expect(document.root, <String, dynamic>{
        'type': 'alert',
        'id': 'published-card',
        'title': 'hello from Lua',
      });
      expect(snapshots, hasLength(1));
      expect(snapshots.single.document, document);
      expect(snapshots.single.contribution.id, 'acme.ui/card');
      expect(snapshots.single.request.context['sessionId'], 'session-1');
    },
  );

  test(
    'standard driver keeps context tools individually selectable and reports '
    'the current normalized budget',
    () async {
      final stateRoot = await Directory.systemTemp.createTemp(
        'tinest-context-budget-state-',
      );
      addTearDown(() => stateRoot.delete(recursive: true));
      const agentId = 'context-budget-agent';
      const catalog = BuiltInPluginCatalog();
      final state = NativePluginStateRepository(stateRoot.path);
      final revisions = PluginRevisionCatalog(
        loader: catalog,
        cache: NativePluginRevisionCache(stateRoot.path),
      );
      final runtime = _pluginRuntime(stagedHost, revisions);
      addTearDown(runtime.close);
      final capabilities = await _prepareBuiltinPlugins(
        catalog: catalog,
        revisions: revisions,
        runtime: runtime,
        agentId: agentId,
        pluginIds: const <String>['tinest.standard', 'tinest.context'],
      );
      final model = _ContextBudgetModelGateway();
      final persisted = <ConversationItem>[];

      await LuaAgentHarness(runtime: runtime).startTurn(
        request: LuaAgentHarnessRequest(
          definition: _contextAgent(
            agentId: agentId,
            toolIds: const <String>['tinest.context/get_context_remaining'],
          ),
          sessionId: 'context-budget-session',
          turnId: 'context-budget-turn',
          workspaceRoot: Directory.current.path,
          prompt: 'How much context remains?',
          modelId: 'context-model',
          model: model,
          modelCapabilities: const AgentModelCapabilities(
            streaming: AgentCapabilitySupport.supported,
            toolCalling: AgentCapabilitySupport.supported,
            functionTools: AgentCapabilitySupport.supported,
          ),
          history: const <ConversationItem>[],
          allowedCapabilitiesByPlugin: capabilities,
          contextWindowTokens: 100,
          state: state,
        ),
        callbacks: LuaAgentHarnessCallbacks(
          onEvent: (_, _) {},
          onStatus: (_, {error}) {},
          onProviderItems: persisted.addAll,
        ),
        cancellation: CancellationToken(),
      );

      expect(
        model.requests
            .expand((request) => request.tools)
            .map((tool) => tool.name),
        everyElement('get_context_remaining'),
      );
      final result = persisted.whereType<ToolResultConversationItem>().single;
      expect(result.output, '30 tokens remaining.');
      expect(result.structuredContent, <String, dynamic>{
        'context': <String, dynamic>{
          'window_tokens': 100,
          'used_tokens': 70,
          'remaining_tokens': 30,
        },
      });
    },
    tags: const <String>[
      'feature_test__tool_context_budget__unit',
      'feature_test__plugin_runtime__unit',
    ],
  );

  test(
    'new_context retires prior provider history and survives runtime restart',
    () async {
      final stateRoot = await Directory.systemTemp.createTemp(
        'tinest-context-reset-state-',
      );
      addTearDown(() => stateRoot.delete(recursive: true));
      const agentId = 'context-reset-agent';
      const sessionId = 'context-reset-session';
      const catalog = BuiltInPluginCatalog();
      final state = NativePluginStateRepository(stateRoot.path);
      final firstRevisions = PluginRevisionCatalog(
        loader: catalog,
        cache: NativePluginRevisionCache(stateRoot.path),
      );
      final firstRuntime = _pluginRuntime(stagedHost, firstRevisions);
      // Closed explicitly below to model the restart. Registered here as well
      // so a failure between the two still terminates the hosts it started;
      // otherwise they hold the staged directory that tearDownAll removes.
      addTearDown(firstRuntime.close);
      final capabilities = await _prepareBuiltinPlugins(
        catalog: catalog,
        revisions: firstRevisions,
        runtime: firstRuntime,
        agentId: agentId,
        pluginIds: const <String>['tinest.standard', 'tinest.context'],
      );
      final model = _ScriptedModelGateway(<_ModelStep>[
        _ModelStep.completion('remembered'),
        _ModelStep.events(<ModelEvent>[
          const ModelFunctionCall(
            callId: 'reset-call',
            name: 'new_context',
            arguments: <String, dynamic>{},
          ),
          const ModelResponseCompleted(
            assistant: AssistantConversationItem(
              text: '',
              toolCalls: <ConversationToolCall>[
                ConversationToolCall.function(
                  callId: 'reset-call',
                  name: 'new_context',
                  arguments: <String, dynamic>{},
                ),
              ],
            ),
          ),
        ]),
        _ModelStep.completion('fresh answer'),
      ]);
      final timeline = <ConversationItem>[];
      final uiEvents = <Map<String, dynamic>>[];
      final definition = _contextAgent(
        agentId: agentId,
        toolIds: const <String>['tinest.context/new_context'],
      );

      await _runContextTurn(
        runtime: firstRuntime,
        definition: definition,
        sessionId: sessionId,
        turnId: 'remember-turn',
        prompt: 'Remember the old release date.',
        model: model,
        history: const <ConversationItem>[],
        persisted: timeline,
        state: state,
        capabilities: capabilities,
      );
      final historyBeforeReset = List<ConversationItem>.of(timeline);
      final resetPersisted = <ConversationItem>[];
      await _runContextTurn(
        runtime: firstRuntime,
        definition: definition,
        sessionId: sessionId,
        turnId: 'reset-turn',
        prompt: 'Start fresh.',
        model: model,
        history: historyBeforeReset,
        persisted: resetPersisted,
        state: state,
        capabilities: capabilities,
        onEvent: (type, data) {
          if (type == 'plugin.ui') uiEvents.add(data);
        },
      );

      expect(model.requests, hasLength(3));
      expect(
        model.requests
            .expand((request) => request.tools)
            .map((tool) => tool.name),
        everyElement('new_context'),
      );
      final afterReset = model.requests[2].history;
      expect(
        afterReset.whereType<UserConversationItem>(),
        isEmpty,
        reason: 'the reset retires both previous turns before the next call',
      );
      final retainedCalls = afterReset
          .whereType<AssistantConversationItem>()
          .expand((item) => item.toolCalls)
          .map((call) => call.callId)
          .toList(growable: false);
      final retainedResults = afterReset
          .whereType<ToolResultConversationItem>()
          .map((item) => item.callId)
          .toList(growable: false);
      expect(retainedCalls, <String>['reset-call']);
      expect(retainedResults, retainedCalls);
      expect(
        uiEvents.single['document'],
        isA<Map<Object?, Object?>>(),
        reason: 'context state is rendered from a revision-pinned UI snapshot',
      );
      await firstRuntime.close();

      final restartedRevisions = PluginRevisionCatalog(
        loader: catalog,
        cache: NativePluginRevisionCache(stateRoot.path),
      );
      final restartedRuntime = _pluginRuntime(stagedHost, restartedRevisions);
      addTearDown(restartedRuntime.close);
      await _prepareBuiltinPlugins(
        catalog: catalog,
        revisions: restartedRevisions,
        runtime: restartedRuntime,
        agentId: agentId,
        pluginIds: const <String>['tinest.standard', 'tinest.context'],
      );
      final restartedModel = _ScriptedModelGateway(<_ModelStep>[
        _ModelStep.completion('restart answer'),
      ]);
      await _runContextTurn(
        runtime: restartedRuntime,
        definition: definition,
        sessionId: sessionId,
        turnId: 'restart-turn',
        prompt: 'What context survived?',
        model: restartedModel,
        history: timeline,
        persisted: timeline,
        state: state,
        capabilities: capabilities,
      );

      final restartedHistory = restartedModel.requests.single.history;
      expect(
        restartedHistory.whereType<UserConversationItem>().map(
          (item) => item.text,
        ),
        allOf(
          isNot(contains('Remember the old release date.')),
          isNot(contains('Start fresh.')),
          contains('What context survived?'),
        ),
      );
      expect(
        restartedHistory.whereType<AssistantConversationItem>().map(
          (item) => item.text,
        ),
        contains('fresh answer'),
      );
    },
    tags: const <String>[
      'feature_test__tool_context_budget__verticalSlice',
      'feature_test__plugin_runtime__verticalSlice',
    ],
  );

  test(
    'compact_context uses an internal model request and persists replacement '
    'history',
    () async {
      final stateRoot = await Directory.systemTemp.createTemp(
        'tinest-context-compact-state-',
      );
      addTearDown(() => stateRoot.delete(recursive: true));
      const agentId = 'context-compact-agent';
      const sessionId = 'context-compact-session';
      const catalog = BuiltInPluginCatalog();
      final state = NativePluginStateRepository(stateRoot.path);
      final revisions = PluginRevisionCatalog(
        loader: catalog,
        cache: NativePluginRevisionCache(stateRoot.path),
      );
      final runtime = _pluginRuntime(stagedHost, revisions);
      addTearDown(runtime.close);
      final capabilities = await _prepareBuiltinPlugins(
        catalog: catalog,
        revisions: revisions,
        runtime: runtime,
        agentId: agentId,
        pluginIds: const <String>['tinest.standard', 'tinest.context'],
      );
      final model = _ScriptedModelGateway(<_ModelStep>[
        _ModelStep.events(<ModelEvent>[
          const ModelFunctionCall(
            callId: 'compact-call',
            name: 'compact_context',
            arguments: <String, dynamic>{'instructions': 'Keep decisions.'},
          ),
          const ModelResponseCompleted(
            assistant: AssistantConversationItem(
              text: '',
              toolCalls: <ConversationToolCall>[
                ConversationToolCall.function(
                  callId: 'compact-call',
                  name: 'compact_context',
                  arguments: <String, dynamic>{
                    'instructions': 'Keep decisions.',
                  },
                ),
              ],
            ),
          ),
        ]),
        _ModelStep.completion('Decisions: ship v5 without compatibility.'),
        _ModelStep.completion('continued after compaction'),
      ]);
      final persisted = <ConversationItem>[];
      final uiEvents = <Map<String, dynamic>>[];
      await _runContextTurn(
        runtime: runtime,
        definition: _contextAgent(
          agentId: agentId,
          toolIds: const <String>['tinest.context/compact_context'],
        ),
        sessionId: sessionId,
        turnId: 'compact-turn',
        prompt: 'Compact now.',
        model: model,
        history: const <ConversationItem>[
          UserConversationItem('obsolete detail'),
          AssistantConversationItem(text: 'old answer'),
        ],
        persisted: persisted,
        state: state,
        capabilities: capabilities,
        onEvent: (type, data) {
          if (type == 'plugin.ui') uiEvents.add(data);
        },
      );

      expect(model.requests, hasLength(3));
      expect(
        model.requests.first.tools.map((tool) => tool.name),
        everyElement('compact_context'),
      );
      expect(model.requests[1].tools, isEmpty);
      expect(
        model.requests[1].blocks.single.content,
        contains('Keep decisions.'),
      );
      expect(
        model.requests[2].history.whereType<UserConversationItem>().map(
          (item) => item.text,
        ),
        contains(contains('Decisions: ship v5 without compatibility.')),
      );
      expect(
        persisted.whereType<AssistantConversationItem>().map(
          (item) => item.text,
        ),
        isNot(contains('Decisions: ship v5 without compatibility.')),
        reason: 'internal summary output is audit data, not a chat message',
      );
      final document = PluginUiDocumentDto.fromJson(
        Map<String, dynamic>.from(uiEvents.single['document']! as Map),
      );
      expect(document.slot, PluginUiSlot.timeline);
      expect(document.root, containsPair('title', 'Compacting context'));
      expect(
        document.root,
        containsPair(
          'description',
          'The Agent driver is summarizing and replacing its model history.',
        ),
      );
      final stored = await state.read(
        const PluginStateScope.session(
          pluginId: 'tinest.standard',
          sessionId: sessionId,
        ),
        'driver_context',
      );
      expect(stored, isNotNull);
      expect(
        (stored!.value! as Map<Object?, Object?>).toString(),
        allOf(contains('Decisions:'), isNot(contains('obsolete detail'))),
      );
    },
    tags: const <String>[
      'feature_test__context_compaction__unit',
      'feature_test__context_compaction__contract',
      'feature_test__context_compaction__verticalSlice',
      'feature_test__plugin_runtime__unit',
    ],
  );

  test(
    'standard driver automatically compacts at its context threshold',
    () async {
      final stateRoot = await Directory.systemTemp.createTemp(
        'tinest-context-auto-compact-state-',
      );
      addTearDown(() => stateRoot.delete(recursive: true));
      const agentId = 'context-auto-compact-agent';
      const sessionId = 'context-auto-compact-session';
      const catalog = BuiltInPluginCatalog();
      final state = NativePluginStateRepository(stateRoot.path);
      final revisions = PluginRevisionCatalog(
        loader: catalog,
        cache: NativePluginRevisionCache(stateRoot.path),
      );
      final runtime = _pluginRuntime(stagedHost, revisions);
      addTearDown(runtime.close);
      final capabilities = await _prepareBuiltinPlugins(
        catalog: catalog,
        revisions: revisions,
        runtime: runtime,
        agentId: agentId,
        pluginIds: const <String>['tinest.standard'],
      );
      final model = _AutomaticCompactionModelGateway();

      await _runContextTurn(
        runtime: runtime,
        definition: _contextAgent(agentId: agentId, toolIds: const <String>[]),
        sessionId: sessionId,
        turnId: 'automatic-compaction-turn',
        prompt: 'Keep the v5 decision.',
        model: model,
        history: const <ConversationItem>[],
        persisted: <ConversationItem>[],
        state: state,
        capabilities: capabilities,
      );

      expect(model.requests, hasLength(2));
      expect(model.requests[1].tools, isEmpty);
      expect(
        model.requests[1].blocks.single.content,
        contains("reached the driver's compaction threshold"),
      );
      final stored = await state.read(
        const PluginStateScope.session(
          pluginId: 'tinest.standard',
          sessionId: sessionId,
        ),
        'driver_context',
      );
      final value = stored!.value! as Map<Object?, Object?>;
      expect(value['reason'], 'automatic_compaction');
      expect(value['history'].toString(), contains('Automatic summary'));
      expect(value['history'].toString(), isNot(contains('large answer')));
    },
    tags: const <String>[
      'feature_test__context_compaction__unit',
      'feature_test__plugin_runtime__unit',
    ],
  );

  test(
    'standard driver recovers once from provider context overflow',
    () async {
      final stateRoot = await Directory.systemTemp.createTemp(
        'tinest-context-overflow-state-',
      );
      addTearDown(() => stateRoot.delete(recursive: true));
      const agentId = 'context-overflow-agent';
      const sessionId = 'context-overflow-session';
      const catalog = BuiltInPluginCatalog();
      final state = NativePluginStateRepository(stateRoot.path);
      final revisions = PluginRevisionCatalog(
        loader: catalog,
        cache: NativePluginRevisionCache(stateRoot.path),
      );
      final runtime = _pluginRuntime(stagedHost, revisions);
      addTearDown(runtime.close);
      final capabilities = await _prepareBuiltinPlugins(
        catalog: catalog,
        revisions: revisions,
        runtime: runtime,
        agentId: agentId,
        pluginIds: const <String>['tinest.standard'],
      );
      final model = _OverflowRecoveryModelGateway();

      await _runContextTurn(
        runtime: runtime,
        definition: _contextAgent(agentId: agentId, toolIds: const <String>[]),
        sessionId: sessionId,
        turnId: 'overflow-turn',
        prompt: 'Recover this request.',
        model: model,
        history: const <ConversationItem>[],
        persisted: <ConversationItem>[],
        state: state,
        capabilities: capabilities,
      );

      expect(model.requests, hasLength(3));
      expect(model.requests[1].tools, isEmpty);
      expect(
        model.requests[1].blocks.single.content,
        contains('Recover from provider context overflow.'),
      );
      expect(
        model.requests[2].history.whereType<UserConversationItem>().map(
          (item) => item.text,
        ),
        contains(contains('Recovered summary')),
      );
    },
    tags: const <String>[
      'feature_test__context_compaction__unit',
      'feature_test__plugin_runtime__unit',
    ],
  );

  test(
    'tinest.goal recovers a durable Lua continuation after restart and '
    'accounts uncached usage',
    () async {
      final stateRoot = await Directory.systemTemp.createTemp(
        'tinest-goal-v5-state-',
      );
      addTearDown(() => stateRoot.delete(recursive: true));
      final clock = _GoalClock(DateTime.utc(2026, 8, 12, 1));
      const agentId = 'goal-agent';
      const sessionId = 'goal-session';
      const workspaceId = 'goal-workspace';
      const definition = AgentDefinitionDto(
        version: 5,
        id: agentId,
        name: 'Goal Agent',
        description: '',
        mode: AgentMode.primary,
        model: AgentModelSelectionDto(source: AgentModelSource.session),
        driverId: 'tinest.standard/driver',
        extensionIds: <String>['tinest.goal'],
        toolIds: <String>[
          'tinest.goal/create_goal',
          'tinest.goal/get_goal',
          'tinest.goal/update_goal',
        ],
        pluginSettings: <String, Map<String, dynamic>>{},
        callableAgentIds: <String>[],
        prompt: '',
        contentHash: 'goal-agent-hash',
        sourcePath: 'builtin://agents/goal.md',
      );
      const catalog = BuiltInPluginCatalog();
      final state = NativePluginStateRepository(stateRoot.path);
      final firstRevisions = PluginRevisionCatalog(
        loader: catalog,
        cache: NativePluginRevisionCache(stateRoot.path),
      );
      final firstRuntime = _pluginRuntime(stagedHost, firstRevisions);
      addTearDown(firstRuntime.close);
      final capabilities = <String, Set<String>>{};
      for (final pluginId in const <String>['tinest.standard', 'tinest.goal']) {
        final bundle = await catalog.load(pluginId);
        final granted = bundle.descriptor.requestedCapabilities.toSet();
        capabilities[pluginId] = granted;
        for (final capability in granted) {
          await state.grant(
            AgentPluginGrantDto(
              agentId: agentId,
              pluginId: pluginId,
              capability: capability,
            ),
          );
        }
        await firstRevisions.reload(
          pluginId,
          agentId: agentId,
          approvedCapabilities: granted,
          inspector: firstRuntime,
        );
      }

      final history = <ConversationItem>[];
      final firstIds = _HostIds('first');
      final creatingModel = _GoalModelGateway(
        phase: _GoalModelPhase.create,
        clock: clock,
      );
      await LuaAgentHarness(runtime: firstRuntime).startTurn(
        request: LuaAgentHarnessRequest(
          definition: definition,
          sessionId: sessionId,
          turnId: 'turn-create',
          workspaceId: workspaceId,
          workspaceRoot: Directory.current.path,
          prompt: 'Create and pursue the migration goal.',
          modelId: 'goal-model',
          model: creatingModel,
          modelCapabilities: const AgentModelCapabilities(
            streaming: AgentCapabilitySupport.supported,
            toolCalling: AgentCapabilitySupport.supported,
            functionTools: AgentCapabilitySupport.supported,
          ),
          history: const <ConversationItem>[],
          allowedCapabilitiesByPlugin: capabilities,
          state: state,
          jobs: state,
          clock: clock,
          ids: firstIds,
        ),
        callbacks: LuaAgentHarnessCallbacks(
          onEvent: (_, _) {},
          onStatus: (_, {error}) {},
          onProviderItems: history.addAll,
        ),
        cancellation: CancellationToken(),
      );
      final createdGoal = await state.read(
        const PluginStateScope.session(
          pluginId: 'tinest.goal',
          sessionId: sessionId,
        ),
        'goal',
      );
      expect(
        createdGoal,
        isNotNull,
        reason: history.map((item) => item.toJson()).join('\n'),
      );
      final pendingGoalContinuation = (await state.get('first-1'))!;
      expect(pendingGoalContinuation.status, PluginJobStatus.pending);
      expect(pendingGoalContinuation.payload, <String, Object?>{
        'reason': 'goal_active',
      });
      await firstRuntime.close();

      // A new repository, revision catalog, and Lua runtime model a daemon
      // restart. Only the durable v5 state and LKG cache survive this point.
      final restartedState = NativePluginStateRepository(stateRoot.path);
      final restartedRevisions = PluginRevisionCatalog(
        loader: catalog,
        cache: NativePluginRevisionCache(stateRoot.path),
      );
      final restartedRuntime = _pluginRuntime(stagedHost, restartedRevisions);
      addTearDown(restartedRuntime.close);
      final completingModel = _GoalModelGateway(
        phase: _GoalModelPhase.complete,
        clock: clock,
      );
      final schedulerIds = _HostIds('restart');
      late final DurablePluginScheduler scheduler;
      final scheduled = LuaPluginScheduledJobExecutor(
        runtime: restartedRuntime,
        state: restartedState,
        grants: restartedState,
        jobs: () => scheduler,
        clock: clock,
        ids: schedulerIds,
        resolveContext: (_) async => const PluginScheduledExecutionContext(
          agentId: agentId,
          sessionId: sessionId,
          workspaceId: workspaceId,
          workingDirectory: '.',
        ),
      );
      var continuationCount = 0;
      scheduler = DurablePluginScheduler(
        store: restartedState,
        clock: clock,
        ids: schedulerIds,
        execute: scheduled.execute,
        hasActiveTurn: (_) => false,
        hasPendingInput: (_) => false,
        startContinuation:
            ({required sessionId, required turnId, required prompt}) async {
              continuationCount += 1;
              await LuaAgentHarness(runtime: restartedRuntime).startTurn(
                request: LuaAgentHarnessRequest(
                  definition: definition,
                  sessionId: sessionId,
                  turnId: turnId,
                  workspaceId: workspaceId,
                  workspaceRoot: Directory.current.path,
                  prompt: prompt,
                  modelId: 'goal-model',
                  model: completingModel,
                  modelCapabilities: const AgentModelCapabilities(
                    streaming: AgentCapabilitySupport.supported,
                    toolCalling: AgentCapabilitySupport.supported,
                    functionTools: AgentCapabilitySupport.supported,
                  ),
                  history: history,
                  allowedCapabilitiesByPlugin: capabilities,
                  state: restartedState,
                  jobs: scheduler,
                  clock: clock,
                  ids: schedulerIds,
                  internal: true,
                ),
                callbacks: LuaAgentHarnessCallbacks(
                  onEvent: (_, _) {},
                  onStatus: (_, {error}) {},
                  onProviderItems: history.addAll,
                ),
                cancellation: CancellationToken(),
              );
              return true;
            },
      );
      addTearDown(scheduler.close);

      await scheduler.drainDueJobs();

      expect(continuationCount, 1);
      expect(
        (await restartedState.get('first-1'))!.status,
        PluginJobStatus.completed,
      );
      expect(
        completingModel.requests.first.blocks
            .map((block) => block.content)
            .join('\n\n'),
        allOf(
          contains('Objective: Move the harness to Lua'),
          contains('Continuation turns started: 1'),
        ),
      );
      final stored = await restartedState.read(
        const PluginStateScope.session(
          pluginId: 'tinest.goal',
          sessionId: sessionId,
        ),
        'goal',
      );
      final goal = Map<String, dynamic>.from(stored!.value! as Map);
      expect(goal['status'], 'complete');
      expect(goal['turns'], 1);
      expect(goal['tokens_used'], 16);
      expect(goal['time_used_seconds'], 7);
      expect(
        File(
          '${stateRoot.path}${Platform.pathSeparator}v5'
          '${Platform.pathSeparator}plugin-state.json',
        ).existsSync(),
        isTrue,
      );
    },
    tags: const <String>[
      'feature_test__session_goal__verticalSlice',
      'feature_test__plugin_runtime__verticalSlice',
    ],
  );

  test(
    'real Lua network calls require both a grant and dangerous approval',
    () async {
      final bundle = _networkHostBundle();
      final network = _RecordingPluginNetworkGateway();
      final state = MemoryPluginStateStore();
      final deniedApproval = _RecordingApprovalCoordinator(
        ApprovalDecision.denied,
      );

      await expectLater(
        _runHostPrimitiveTurn(
          stagedHost: stagedHost,
          bundle: bundle,
          agentId: 'agent-network',
          sessionId: 'session-ungranted',
          prompt: 'https://example.test/ungranted',
          grantedCapabilities: const <String>{'state.write'},
          network: network,
          state: state,
          policy: const _AskPolicy(),
          approvals: deniedApproval,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => '$error',
            'message',
            contains('Plugin capability is not granted: network.access'),
          ),
        ),
      );
      expect(network.requests, isEmpty);
      expect(deniedApproval.invocations, isEmpty);

      await expectLater(
        _runHostPrimitiveTurn(
          stagedHost: stagedHost,
          bundle: bundle,
          agentId: 'agent-network',
          sessionId: 'session-denied',
          prompt: 'https://example.test/denied',
          grantedCapabilities: const <String>{'network.access', 'state.write'},
          network: network,
          state: state,
          policy: const _AskPolicy(),
          approvals: deniedApproval,
        ),
        throwsA(isA<StateError>()),
      );
      expect(network.requests, isEmpty);
      expect(deniedApproval.invocations, hasLength(1));
      expect(deniedApproval.invocations.single.risk, AgentToolRisk.dangerous);

      final approved = _RecordingApprovalCoordinator(ApprovalDecision.approved);
      await _runHostPrimitiveTurn(
        stagedHost: stagedHost,
        bundle: bundle,
        agentId: 'agent-network',
        sessionId: 'session-approved',
        prompt: 'https://example.test/approved',
        grantedCapabilities: const <String>{'network.access', 'state.write'},
        network: network,
        state: state,
        policy: const _AskPolicy(),
        approvals: approved,
      );
      expect(network.requests, hasLength(1));
      expect(network.requests.single.uri.toString(), contains('/approved'));
      expect(approved.invocations.single.risk, AgentToolRisk.dangerous);
      final stored = await state.read(
        const PluginStateScope.session(
          pluginId: 'acme.network',
          sessionId: 'session-approved',
        ),
        'result',
      );
      expect(stored?.value, containsPair('body', 'network response'));
    },
  );

  test(
    'real Lua secret reads are missing-safe and isolated by Agent and plugin',
    () async {
      final secrets = _MemoryPluginSecretStore();
      await secrets.set(
        const PluginSecretScope(agentId: 'agent-a', pluginId: 'acme.secret'),
        'API_TOKEN',
        'agent-a-token',
      );
      final state = MemoryPluginStateStore();

      Future<Object?> run({
        required String agentId,
        required String sessionId,
        required String pluginId,
      }) async {
        final bundle = _secretHostBundle(pluginId);
        await _runHostPrimitiveTurn(
          stagedHost: stagedHost,
          bundle: bundle,
          agentId: agentId,
          sessionId: sessionId,
          prompt: 'API_TOKEN',
          grantedCapabilities: const <String>{'secret.access', 'state.write'},
          secrets: secrets,
          state: state,
          policy: const _AllowPolicy(),
        );
        return (await state.read(
          PluginStateScope.session(pluginId: pluginId, sessionId: sessionId),
          'result',
        ))?.value;
      }

      expect(
        await run(
          agentId: 'agent-a',
          sessionId: 'session-owner',
          pluginId: 'acme.secret',
        ),
        <String, Object?>{'found': true, 'value': 'agent-a-token'},
      );
      expect(
        await run(
          agentId: 'agent-b',
          sessionId: 'session-other-agent',
          pluginId: 'acme.secret',
        ),
        <String, Object?>{'found': false},
      );
      expect(
        await run(
          agentId: 'agent-a',
          sessionId: 'session-other-plugin',
          pluginId: 'acme.other',
        ),
        <String, Object?>{'found': false},
      );
      expect(
        secrets.reads.map((scope) => '${scope.agentId}/${scope.pluginId}'),
        <String>[
          'agent-a/acme.secret',
          'agent-b/acme.secret',
          'agent-a/acme.other',
        ],
      );
    },
  );

  test('real Lua network cancellation aborts in-flight host I/O', () async {
    final bundle = _networkHostBundle();
    final network = _BlockingPluginNetworkGateway();
    final cancellation = CancellationToken();
    final running = _runHostPrimitiveTurn(
      stagedHost: stagedHost,
      bundle: bundle,
      agentId: 'agent-network',
      sessionId: 'session-cancel',
      prompt: 'https://example.test/slow',
      grantedCapabilities: const <String>{'network.access', 'state.write'},
      network: network,
      state: MemoryPluginStateStore(),
      policy: const _AllowPolicy(),
      cancellation: cancellation,
    );
    await network.started.future.timeout(const Duration(seconds: 10));
    cancellation.cancel();

    await expectLater(running, throwsA(isA<AgentCancelledException>()));
    expect(network.cancelled, isTrue);
  });

  test('network transport failures use the structured host envelope', () async {
    final state = MemoryPluginStateStore();
    await _runHostPrimitiveTurn(
      stagedHost: stagedHost,
      bundle: _networkFailureEnvelopeBundle(),
      agentId: 'agent-network',
      sessionId: 'session-network-failure',
      prompt: 'https://example.test/unavailable',
      grantedCapabilities: const <String>{'network.access', 'state.write'},
      network: const _FailingPluginNetworkGateway('connectionError'),
      state: state,
      policy: const _AllowPolicy(),
    );

    expect(
      (await state.read(
        const PluginStateScope.session(
          pluginId: 'acme.network-failure',
          sessionId: 'session-network-failure',
        ),
        'result',
      ))?.value,
      <String, Object?>{
        'ok': false,
        'error': <String, Object?>{
          'code': 'network_transport_error',
          'message': 'Plugin network request failed: connectionError',
          'retryable': true,
          'details': <String, Object?>{'kind': 'connectionError'},
        },
      },
    );
  });

  test(
    'Lua state reads return explicit absent and present envelopes',
    () async {
      final state = MemoryPluginStateStore();

      await _runHostPrimitiveTurn(
        stagedHost: stagedHost,
        bundle: _stateReadEnvelopeBundle(),
        agentId: 'agent-state-envelope',
        sessionId: 'session-state-envelope',
        prompt: 'unused',
        grantedCapabilities: const <String>{'state.read', 'state.write'},
        state: state,
        policy: const _AllowPolicy(),
      );

      final result = await state.read(
        const PluginStateScope.session(
          pluginId: 'acme.state-envelope',
          sessionId: 'session-state-envelope',
        ),
        'result',
      );
      expect(result?.value, <String, Object?>{
        'missing_found': false,
        'present_found': true,
        'present_revision': 1,
        'present_value': 'stored',
      });
    },
  );

  test(
    'Lua state cells reject malformed persisted and replacement values',
    () async {
      const scope = PluginStateScope.session(
        pluginId: 'acme.state-schema',
        sessionId: 'session-state-schema-read',
      );
      final malformedReadState = MemoryPluginStateStore();
      await malformedReadState.compareAndSet(
        scope,
        'value',
        expectedRevision: 0,
        value: 42,
      );

      await expectLater(
        _runHostPrimitiveTurn(
          stagedHost: stagedHost,
          bundle: _stateSchemaBundle('read'),
          agentId: 'agent-state-schema',
          sessionId: 'session-state-schema-read',
          prompt: 'unused',
          grantedCapabilities: const <String>{'state.read', 'state.write'},
          state: malformedReadState,
          policy: const _AllowPolicy(),
        ),
        throwsA(isA<StateError>()),
      );

      for (final operation in <String>['compare_and_set', 'transaction']) {
        final state = MemoryPluginStateStore();
        await expectLater(
          _runHostPrimitiveTurn(
            stagedHost: stagedHost,
            bundle: _stateSchemaBundle(operation),
            agentId: 'agent-state-schema',
            sessionId: 'session-state-schema-$operation',
            prompt: 'unused',
            grantedCapabilities: const <String>{'state.read', 'state.write'},
            state: state,
            policy: const _AllowPolicy(),
          ),
          throwsA(isA<StateError>()),
          reason: operation,
        );
        expect(
          await state.read(
            PluginStateScope.session(
              pluginId: 'acme.state-schema',
              sessionId: 'session-state-schema-$operation',
            ),
            'value',
          ),
          isNull,
          reason: operation,
        );
      }
    },
  );

  test(
    'real Lua network calls enforce request and response size limits',
    () async {
      final network = _RecordingPluginNetworkGateway();
      await expectLater(
        _runHostPrimitiveTurn(
          stagedHost: stagedHost,
          bundle: _networkHostBundle(oversizedRequest: true),
          agentId: 'agent-network',
          sessionId: 'session-large-request',
          prompt: 'https://example.test/upload',
          grantedCapabilities: const <String>{'network.access', 'state.write'},
          network: network,
          state: MemoryPluginStateStore(),
          policy: const _AllowPolicy(),
        ),
        throwsA(isA<StateError>()),
      );
      expect(network.requests, isEmpty);

      network.response = PluginNetworkResponse(
        statusCode: 200,
        headers: const <String, List<String>>{},
        body: List<int>.filled(
          PluginNetworkLimits.maximumResponseBodyBytes + 1,
          65,
        ),
      );
      await expectLater(
        _runHostPrimitiveTurn(
          stagedHost: stagedHost,
          bundle: _networkHostBundle(),
          agentId: 'agent-network',
          sessionId: 'session-large-response',
          prompt: 'https://example.test/download',
          grantedCapabilities: const <String>{'network.access', 'state.write'},
          network: network,
          state: MemoryPluginStateStore(),
          policy: const _AllowPolicy(),
        ),
        throwsA(isA<StateError>()),
      );
      expect(network.requests, hasLength(1));
    },
  );
}

Future<void> _runModelToolSurfaceTurn({
  required Directory stagedHost,
  required PluginBundle bundle,
  required List<String> toolIds,
  required AgentModelCapabilities capabilities,
  required ModelGateway model,
}) async {
  final revisions = PluginRevisionCatalog(
    loader: _BundleLoader(bundle),
    cache: _MemoryRevisionCache(),
  );
  final grants = bundle.descriptor.requestedCapabilities.toSet();
  await revisions.reload(
    bundle.descriptor.id,
    agentId: 'surface-agent',
    approvedCapabilities: grants,
  );
  final runtime = _pluginRuntime(stagedHost, revisions);
  try {
    await LuaAgentHarness(runtime: runtime).startTurn(
      request: LuaAgentHarnessRequest(
        definition: AgentDefinitionDto(
          version: 5,
          id: 'surface-agent',
          name: 'Surface Agent',
          description: '',
          mode: AgentMode.primary,
          model: const AgentModelSelectionDto(source: AgentModelSource.session),
          driverId: 'acme.surface/driver',
          extensionIds: const <String>[],
          toolIds: toolIds,
          pluginSettings: const <String, Map<String, dynamic>>{},
          callableAgentIds: const <String>[],
          prompt: '',
          contentHash: 'surface-agent-hash',
          sourcePath: 'surface-agent.md',
        ),
        sessionId: 'surface-session',
        turnId: 'surface-turn',
        workspaceRoot: Directory.current.path,
        prompt: 'run',
        modelId: 'surface-model',
        model: model,
        modelCapabilities: capabilities,
        history: const <ConversationItem>[],
        allowedCapabilitiesByPlugin: <String, Set<String>>{
          bundle.descriptor.id: grants,
        },
      ),
      callbacks: LuaAgentHarnessCallbacks(
        onEvent: (_, _) {},
        onStatus: (_, {error}) {},
        onProviderItems: (_) {},
      ),
      cancellation: CancellationToken(),
    );
  } finally {
    await runtime.close();
  }
}

Future<void> _runHostPrimitiveTurn({
  required Directory stagedHost,
  required PluginBundle bundle,
  required String agentId,
  required String sessionId,
  required String prompt,
  required Set<String> grantedCapabilities,
  required ApprovalPolicy policy,
  String? workspaceId,
  List<String> toolIds = const <String>[],
  HostPrimitiveRegistry? primitives,
  PluginNetworkGateway? network,
  PluginSecretStore? secrets,
  PluginStateStore? state,
  PluginJobStore? jobs,
  Clock? clock,
  IdGenerator? ids,
  ApprovalCoordinator? approvals,
  CancellationToken? cancellation,
  AgentEventCallback? onEvent,
}) async {
  final revisions = PluginRevisionCatalog(
    loader: _BundleLoader(bundle),
    cache: _MemoryRevisionCache(),
  );
  await revisions.reload(
    bundle.descriptor.id,
    agentId: agentId,
    approvedCapabilities: bundle.descriptor.requestedCapabilities.toSet(),
  );
  final runtime = _pluginRuntime(stagedHost, revisions);
  try {
    await LuaAgentHarness(runtime: runtime).startTurn(
      request: LuaAgentHarnessRequest(
        definition: AgentDefinitionDto(
          version: 5,
          id: agentId,
          name: 'Host primitive Agent',
          description: '',
          mode: AgentMode.primary,
          model: const AgentModelSelectionDto(source: AgentModelSource.session),
          driverId: '${bundle.descriptor.id}/driver',
          extensionIds: const <String>[],
          toolIds: toolIds,
          pluginSettings: const <String, Map<String, dynamic>>{},
          callableAgentIds: const <String>[],
          prompt: '',
          contentHash: '$agentId-hash',
          sourcePath: '$agentId.md',
        ),
        sessionId: sessionId,
        turnId: '$sessionId-turn',
        workspaceId: workspaceId,
        workspaceRoot: Directory.current.path,
        prompt: prompt,
        modelId: 'unused',
        model: _RecordingModelGateway(),
        modelCapabilities: const AgentModelCapabilities(),
        history: const <ConversationItem>[],
        allowedCapabilitiesByPlugin: <String, Set<String>>{
          bundle.descriptor.id: grantedCapabilities,
        },
        primitives: primitives,
        network: network,
        secrets: secrets,
        state: state,
        jobs: jobs,
        clock: clock,
        ids: ids,
        approvals: approvals,
        policyFactory: (_) => policy,
      ),
      callbacks: LuaAgentHarnessCallbacks(
        onEvent: onEvent ?? (_, _) {},
        onStatus: (_, {error}) {},
        onProviderItems: (_) {},
      ),
      cancellation: cancellation ?? CancellationToken(),
    );
  } finally {
    await runtime.close();
  }
}

PluginRuntime<ConversationAttachment> _pluginRuntime(
  Directory stagedHost,
  PluginRevisionCatalog revisions,
) => PluginRuntime<ConversationAttachment>(
  luaRuntime: lua.LuaToolRuntime<ConversationAttachment>(
    host: lua.LuaHostCommand.fromDirectory(stagedHost.path),
    processLauncher: const lua.IoLuaHostProcessLauncher(),
    clock: const lua.SystemLuaClock(),
    ids: _Ids(),
  ),
  revisions: revisions,
);

Future<Map<String, Set<String>>> _prepareBuiltinPlugins({
  required BuiltInPluginCatalog catalog,
  required PluginRevisionCatalog revisions,
  required PluginRuntime<ConversationAttachment> runtime,
  required String agentId,
  required List<String> pluginIds,
}) async {
  final capabilities = <String, Set<String>>{};
  for (final pluginId in pluginIds) {
    final bundle = await catalog.load(pluginId);
    final granted = bundle.descriptor.requestedCapabilities.toSet();
    capabilities[pluginId] = granted;
    await revisions.reload(
      pluginId,
      agentId: agentId,
      approvedCapabilities: granted,
      inspector: runtime,
    );
  }
  return capabilities;
}

AgentDefinitionDto _contextAgent({
  required String agentId,
  required List<String> toolIds,
}) => AgentDefinitionDto(
  version: 5,
  id: agentId,
  name: 'Context Agent',
  description: '',
  mode: AgentMode.primary,
  model: const AgentModelSelectionDto(source: AgentModelSource.session),
  driverId: 'tinest.standard/driver',
  extensionIds: const <String>[],
  toolIds: toolIds,
  pluginSettings: const <String, Map<String, dynamic>>{},
  callableAgentIds: const <String>[],
  prompt: '',
  contentHash: '$agentId-hash',
  sourcePath: 'builtin://agents/$agentId.md',
);

Future<void> _runContextTurn({
  required PluginRuntime<ConversationAttachment> runtime,
  required AgentDefinitionDto definition,
  required String sessionId,
  required String turnId,
  required String prompt,
  required ModelGateway model,
  required List<ConversationItem> history,
  required List<ConversationItem> persisted,
  required PluginStateStore state,
  required Map<String, Set<String>> capabilities,
  FutureOr<void> Function(String, Map<String, dynamic>)? onEvent,
}) => LuaAgentHarness(runtime: runtime)
    .startTurn(
      request: LuaAgentHarnessRequest(
        definition: definition,
        sessionId: sessionId,
        turnId: turnId,
        workspaceRoot: Directory.current.path,
        prompt: prompt,
        modelId: 'context-model',
        model: model,
        modelCapabilities: const AgentModelCapabilities(
          streaming: AgentCapabilitySupport.supported,
          toolCalling: AgentCapabilitySupport.supported,
          functionTools: AgentCapabilitySupport.supported,
        ),
        history: history,
        allowedCapabilitiesByPlugin: capabilities,
        contextWindowTokens: 100,
        state: state,
      ),
      callbacks: LuaAgentHarnessCallbacks(
        onEvent: onEvent ?? (_, _) {},
        onStatus: (_, {error}) {},
        onProviderItems: persisted.addAll,
      ),
      cancellation: CancellationToken(),
    )
    .then((_) {});

Future<List<bool>> _runRestrictedTurn({
  required Directory stagedHost,
  required List<PluginBundle> bundles,
  required List<String> extensionIds,
  required HostPrimitiveRegistry primitives,
  Map<String, Object?> sessionControlValues = const <String, Object?>{},
}) async {
  final loader = _BundleMapLoader(<String, PluginBundle>{
    for (final bundle in bundles) bundle.descriptor.id: bundle,
  });
  final revisions = PluginRevisionCatalog(
    loader: loader,
    cache: _MemoryRevisionCache(),
  );
  final grants = <String, Set<String>>{};
  for (final bundle in bundles) {
    final capabilities = bundle.descriptor.requestedCapabilities.toSet();
    grants[bundle.descriptor.id] = capabilities;
    await revisions.reload(
      bundle.descriptor.id,
      agentId: 'agent-1',
      approvedCapabilities: capabilities,
    );
  }
  final runtime = PluginRuntime<ConversationAttachment>(
    luaRuntime: lua.LuaToolRuntime<ConversationAttachment>(
      host: lua.LuaHostCommand.fromDirectory(stagedHost.path),
      processLauncher: const lua.IoLuaHostProcessLauncher(),
      clock: const lua.SystemLuaClock(),
      ids: _Ids(),
    ),
    revisions: revisions,
  );
  final completions = <Map<String, dynamic>>[];
  try {
    await LuaAgentHarness(runtime: runtime).startTurn(
      request: LuaAgentHarnessRequest(
        definition: AgentDefinitionDto(
          version: 5,
          id: 'agent-1',
          name: 'Restricted Agent',
          description: '',
          mode: AgentMode.primary,
          model: const AgentModelSelectionDto(source: AgentModelSource.session),
          driverId: 'acme.harness/driver',
          extensionIds: extensionIds,
          toolIds: const <String>[
            'acme.harness/read',
            'acme.harness/write',
            'acme.harness/process',
          ],
          pluginSettings: const <String, Map<String, dynamic>>{},
          callableAgentIds: const <String>[],
          prompt: '',
          contentHash: 'agent-hash',
          sourcePath: 'agent.md',
        ),
        sessionId: 'session-1',
        turnId: 'turn-1',
        workspaceRoot: Directory.current.path,
        prompt: 'run',
        modelId: 'unused',
        model: _RecordingModelGateway(),
        modelCapabilities: const AgentModelCapabilities(),
        history: const <ConversationItem>[],
        allowedCapabilitiesByPlugin: grants,
        sessionControlValues: sessionControlValues,
        primitives: primitives,
        policyFactory: (_) => const _AllowPolicy(),
      ),
      callbacks: LuaAgentHarnessCallbacks(
        onEvent: (type, data) {
          if (type == 'tool.completed') completions.add(data);
        },
        onStatus: (_, {error}) {},
        onProviderItems: (_) {},
      ),
      cancellation: CancellationToken(),
    );
  } finally {
    await runtime.close();
  }
  return completions
      .map((completion) => completion['isError'] == true)
      .toList(growable: false);
}

Future<_RecordingModelGateway> _runPlanPromptTurn({
  required Directory stagedHost,
  required bool enabled,
}) async {
  const catalog = BuiltInPluginCatalog();
  final loader = _BundleMapLoader(<String, PluginBundle>{
    'tinest.standard': await catalog.load('tinest.standard'),
    'tinest.plan': await catalog.load('tinest.plan'),
  });
  final revisions = PluginRevisionCatalog(
    loader: loader,
    cache: _MemoryRevisionCache(),
  );
  final capabilities = <String, Set<String>>{};
  for (final entry in loader.bundles.entries) {
    final granted = entry.value.descriptor.requestedCapabilities.toSet();
    capabilities[entry.key] = granted;
    await revisions.reload(
      entry.key,
      agentId: 'agent-1',
      approvedCapabilities: granted,
    );
  }
  final runtime = _pluginRuntime(stagedHost, revisions);
  final model = _RecordingModelGateway();
  try {
    await LuaAgentHarness(runtime: runtime).startTurn(
      request: LuaAgentHarnessRequest(
        definition: const AgentDefinitionDto(
          version: 5,
          id: 'agent-1',
          name: 'Plan Agent',
          description: '',
          mode: AgentMode.primary,
          model: AgentModelSelectionDto(source: AgentModelSource.session),
          driverId: 'tinest.standard/driver',
          extensionIds: <String>['tinest.plan'],
          toolIds: <String>[],
          pluginSettings: <String, Map<String, dynamic>>{},
          callableAgentIds: <String>[],
          prompt: 'AGENT BODY',
          contentHash: 'agent-hash',
          sourcePath: 'agent.md',
        ),
        sessionId: 'session-1',
        turnId: 'turn-1',
        workspaceRoot: Directory.current.path,
        prompt: 'USER INPUT',
        modelId: 'plan-model',
        model: model,
        modelCapabilities: const AgentModelCapabilities(
          streaming: AgentCapabilitySupport.supported,
        ),
        history: const <ConversationItem>[],
        allowedCapabilitiesByPlugin: capabilities,
        sessionControlValues: enabled
            ? const <String, Object?>{'tinest.plan/mode': true}
            : const <String, Object?>{},
        state: MemoryPluginStateStore(),
      ),
      callbacks: LuaAgentHarnessCallbacks(
        onEvent: (_, _) {},
        onStatus: (_, {error}) {},
        onProviderItems: (_) {},
      ),
      cancellation: CancellationToken(),
    );
  } finally {
    await runtime.close();
  }
  return model;
}

PluginBundle _restrictedDriverBundle({required List<String> capabilityLimit}) {
  const id = 'acme.harness';
  const capabilities = <String>[
    'tools.invoke',
    'workspace.read',
    'workspace.patch',
    'process.execute',
  ];
  final limit = capabilityLimit.map(_luaCapabilityReference).join(', ');
  final source =
      '''
local tinest = require("tinest")
local S = tinest.schema

local read = tinest.tool.function_({
  id = "read", name = "read_file", description = "read",
  uses = {tinest.host.workspace.read_text},
}, S.object({}), nil, function(arguments)
  local value = tinest.result.unwrap(tinest.host.workspace.read_text(arguments))
  return {output = value.text}
end)

local write = tinest.tool.function_({
  id = "write", name = "apply_patch", description = "write",
  uses = {tinest.host.workspace.transaction},
}, S.object({}), nil, function(arguments)
  return tinest.result.unwrap(tinest.host.workspace.transaction(arguments))
end)

local process = tinest.tool.function_({
  id = "process", name = "exec_command", description = "process",
  uses = {tinest.host.process.start},
}, S.object({}), nil, function(arguments)
  return tinest.result.unwrap(tinest.host.process.start(arguments))
end)

local before_turn = tinest.hook.before_turn({id = "plan"}, function(_arguments)
  return {capability_limit = {$limit}}
end)

local driver = tinest.driver.define({
  id = "driver",
  required_capabilities = {
    tinest.capability.tools.list,
    tinest.capability.tools.invoke,
  },
}, function(_arguments)
  local descriptors = tinest.tools.list()
  local selected_read = tinest.tools.resolve(read, descriptors)
  local selected_write = tinest.tools.resolve(write, descriptors)
  local selected_process = tinest.tools.resolve(process, descriptors)
  tinest.tools.invoke(selected_read.ref, {})
  pcall(tinest.tools.invoke, selected_write.ref, {})
  pcall(tinest.tools.invoke, selected_process.ref, {})
  return {tool_rounds = 3}
end)

return tinest.plugin.define({
  driver = driver,
  tools = {read, write, process},
  hooks = {before_turn},
})
''';
  return _bundle(
    id: id,
    capabilities: <String>[...capabilities, 'tools.list'],
    source: source,
  );
}

String _luaCapabilityReference(String value) => switch (value) {
  'workspace.read' => 'tinest.capability.workspace.read',
  'workspace.patch' => 'tinest.capability.workspace.patch',
  'process.execute' => 'tinest.capability.process.execute',
  _ => throw ArgumentError.value(value, 'capabilityLimit'),
};

PluginBundle _restrictionExtensionBundle({
  required String id,
  required List<String> capabilityLimit,
}) {
  final limit = capabilityLimit.map(_luaCapabilityReference).join(', ');
  return _bundle(
    id: id,
    capabilities: const <String>[],
    source:
        '''
local tinest = require("tinest")
local before_turn = tinest.hook.before_turn({
  id = "restriction",
}, function(_arguments)
  return {capability_limit = {$limit}}
end)
return tinest.plugin.define({hooks = {before_turn}})
''',
  );
}

PluginBundle _unrestrictedDriverBundle() => _bundle(
  id: 'acme.harness',
  capabilities: const <String>[
    'tools.invoke',
    'tools.list',
    'workspace.read',
    'workspace.patch',
    'process.execute',
  ],
  source: '''
local tinest = require("tinest")
local S = tinest.schema

local read = tinest.tool.function_({
  id = "read", name = "read_file", description = "read",
  uses = {tinest.host.workspace.read_text},
}, S.object({}), nil, function(arguments)
  local value = tinest.result.unwrap(tinest.host.workspace.read_text(arguments))
  return {output = value.text}
end)
local write = tinest.tool.function_({
  id = "write", name = "apply_patch", description = "write",
  uses = {tinest.host.workspace.transaction},
}, S.object({}), nil, function(arguments)
  return tinest.result.unwrap(tinest.host.workspace.transaction(arguments))
end)
local process = tinest.tool.function_({
  id = "process", name = "exec_command", description = "process",
  uses = {tinest.host.process.start},
}, S.object({}), nil, function(arguments)
  return tinest.result.unwrap(tinest.host.process.start(arguments))
end)
local driver = tinest.driver.define({
  id = "driver",
  required_capabilities = {
    tinest.capability.tools.list,
    tinest.capability.tools.invoke,
  },
}, function(_arguments)
  local descriptors = tinest.tools.list()
  local selected_read = tinest.tools.resolve(read, descriptors)
  local selected_write = tinest.tools.resolve(write, descriptors)
  local selected_process = tinest.tools.resolve(process, descriptors)
  tinest.tools.invoke(selected_read.ref, {})
  pcall(tinest.tools.invoke, selected_write.ref, {})
  pcall(tinest.tools.invoke, selected_process.ref, {})
  return {tool_rounds = 3}
end)
return tinest.plugin.define({
  driver = driver,
  tools = {read, write, process},
})
  ''',
);

const AgentDefinitionDto _terminalLifecycleDefinition = AgentDefinitionDto(
  version: 5,
  id: 'agent-1',
  name: 'Lifecycle Agent',
  description: '',
  mode: AgentMode.primary,
  model: AgentModelSelectionDto(source: AgentModelSource.session),
  driverId: 'acme.lifecycle/driver',
  extensionIds: <String>['acme.lifecycle'],
  toolIds: <String>[],
  pluginSettings: <String, Map<String, dynamic>>{},
  callableAgentIds: <String>[],
  prompt: '',
  contentHash: 'agent-hash',
  sourcePath: 'agent.md',
);

PluginBundle _terminalLifecycleBundle() => _bundle(
  id: 'acme.lifecycle',
  capabilities: const <String>['model.call', 'state.write'],
  source: '''
local tinest = require("tinest")
local S = tinest.schema
local cancel_state = tinest.state.cell({
  scope = tinest.state.scope.session, key = "cancel",
}, S.string())
local error_state = tinest.state.cell({
  scope = tinest.state.scope.session, key = "error",
}, S.string())

local on_cancel = tinest.hook.cancel({
  id = "cancel",
  required_capabilities = {tinest.capability.state.write},
}, function(_arguments)
  cancel_state:compare_and_set(0, "cancel")
  return {marker = "cancel"}
end)
local on_error = tinest.hook.error({
  id = "error",
  required_capabilities = {tinest.capability.state.write},
}, function(_arguments)
  error_state:compare_and_set(0, "error")
  return {marker = "error"}
end)
local on_scheduled = tinest.scheduler.handler({
  id = "scheduled",
}, S.map(S.any()), function(arguments)
  return {continue = true, prompt = arguments.prompt}
end)
local driver = tinest.driver.define({
  id = "driver",
  uses = {tinest.model.open, tinest.model.next},
  required_model_capabilities = {tinest.model.capability.streaming},
}, function(arguments)
  if arguments.prompt == "error" then error("driver exploded") end
  local stream = tinest.model.open({blocks = {}, history = {}, tools = {}})
  while true do
    local item = tinest.model.next(stream)
    if item.done then break end
  end
  return {tool_rounds = 0}
end)
return tinest.plugin.define({
  driver = driver,
  hooks = {on_cancel, on_error, on_scheduled},
})
  ''',
);

PluginBundle _afterModelLifecycleBundle() => _bundle(
  id: 'acme.lifecycle',
  capabilities: const <String>['model.call', 'state.write'],
  source: '''
local tinest = require("tinest")
local S = tinest.schema
local cancel_state = tinest.state.cell({
  scope = tinest.state.scope.session, key = "cancel",
}, S.string())

local on_cancel = tinest.hook.cancel({
  id = "cancel",
  required_capabilities = {tinest.capability.state.write},
}, function(_arguments)
  cancel_state:compare_and_set(0, "cancel")
  return {marker = "cancel"}
end)
local after_model = tinest.hook.after_model({
  id = "after-model",
}, function(_context)
  return {marker = "after-model"}
end)
local driver = tinest.driver.define({
  id = "driver",
  uses = {tinest.model.open, tinest.model.next},
  required_model_capabilities = {tinest.model.capability.streaming},
}, function(arguments)
  local stream = tinest.model.open({blocks = {}, history = {}, tools = {}})
  while true do
    local item = tinest.model.next(stream)
    if item.done then break end
  end
  return {tool_rounds = 0}
end)
return tinest.plugin.define({
  driver = driver,
  hooks = {on_cancel, after_model},
})
  ''',
);

PluginBundle _scheduledCallbacksBundle() => _bundle(
  id: 'acme.scheduled',
  capabilities: const <String>[
    'state.read',
    'state.write',
    'scheduler.manage',
    'ui.publish',
  ],
  source: '''
local tinest = require("tinest")
local S = tinest.schema
local Any = S.any()
local missing_state = tinest.state.cell({
  scope = tinest.state.scope.session, key = "missing",
}, Any)
local plugin_state = tinest.state.cell({
  scope = tinest.state.scope.plugin, key = "value",
}, Any)
local agent_state = tinest.state.cell({
  scope = tinest.state.scope.agent, key = "value",
}, Any)
local session_state = tinest.state.cell({
  scope = tinest.state.scope.session, key = "value",
}, Any)
local workspace_state = tinest.state.cell({
  scope = tinest.state.scope.workspace, key = "value",
}, Any)
local removable_state = tinest.state.cell({
  scope = tinest.state.scope.session, key = "remove-me",
}, Any)
local direct_state = tinest.state.cell({
  scope = tinest.state.scope.session, key = "direct-remove",
}, Any)
local scheduled_status = tinest.ui.contribution({
  id = "scheduled-status", slot = tinest.ui.slot.conversation_status,
}, S.any(), function(value)
  return tinest.ui.text({text = value.message})
end)

local on_scheduled
on_scheduled = tinest.scheduler.handler({
  id = "scheduled",
  required_capabilities = {
    tinest.capability.state.read,
    tinest.capability.state.write,
    tinest.capability.scheduler.manage,
    tinest.capability.ui.publish,
  },
}, S.map(S.any()), function(arguments)
  local missing = missing_state:read()
  if missing.found then error("missing state was reported as present") end
  plugin_state:compare_and_set(0, "plugin")
  agent_state:compare_and_set(0, "agent")
  session_state:compare_and_set(0, "session")
  workspace_state:compare_and_set(0, "workspace")
  local removable = removable_state:compare_and_set(0, "old")
  removable_state:transaction({
    {key = "transaction", expected_revision = 0, value = "created"},
    {key = "remove-me", expected_revision = removable.revision, remove = true},
  })
  local direct = direct_state:compare_and_set(0, "old")
  direct_state:remove(direct.revision)
  local scheduled = tinest.scheduler.schedule(
    on_scheduled,
    {kind = "cancelled"},
    {delay_ms = 25}
  )
  local cancelled = tinest.scheduler.cancel(scheduled.id)
  if not cancelled.cancelled then error("scheduled job was not cancelled") end
  tinest.scheduler.continue_after_turn(
    on_scheduled,
    {kind = "continuation"},
    {delay_ms = -5}
  )
  tinest.ui.status(scheduled_status, {message = "scheduled"})
  return {continue = true, prompt = arguments.prompt}
end)
return tinest.plugin.define({
  hooks = {on_scheduled},
  ui = {scheduled_status},
})
''',
);

PluginBundle _scheduledRevisionBundle(
  String revision, {
  List<String> capabilities = const <String>[],
  List<String> requiredCapabilities = const <String>[],
}) => _bundle(
  id: 'acme.scheduled-revision',
  capabilities: capabilities,
  revision: revision,
  source:
      '''
local tinest = require("tinest")
local S = tinest.schema
local scheduled = tinest.scheduler.handler({
  id = "scheduled",
  required_capabilities = {${requiredCapabilities.map((value) => '"$value"').join(', ')}},
}, S.map(S.any()), function(_arguments)
  return {continue = false, prompt = "$revision"}
end)
return tinest.plugin.define({hooks = {scheduled}})
''',
);

PluginBundle _scheduledStateSchemaBundle() => _bundle(
  id: 'acme.scheduled-state-schema',
  capabilities: const <String>['state.read'],
  source: '''
local tinest = require("tinest")
local S = tinest.schema
local value_state = tinest.state.cell({
  scope = tinest.state.scope.session, key = "value",
}, S.string())
local scheduled = tinest.scheduler.handler({
  id = "scheduled",
  required_capabilities = {tinest.capability.state.read},
}, S.any(), function(_arguments)
  value_state:read()
  return {}
end)
return tinest.plugin.define({hooks = {scheduled}})
''',
);

PluginBundle _scheduledPayloadSchemaBundle() => _bundle(
  id: 'acme.scheduledschema',
  capabilities: const <String>['scheduler.manage'],
  source: '''
local tinest = require("tinest")
local S = tinest.schema
local T = require("tinest.types")
local Payload = S.object(T.ScheduledPayload, {
  count = S.optional(S.integer()),
  nested = S.optional(S.boolean()),
})
local scheduled
scheduled = tinest.scheduler.handler({
  id = "scheduled",
  required_capabilities = {tinest.capability.scheduler.manage},
}, Payload, function(payload)
  if payload.nested == true then
    tinest.scheduler.schedule(scheduled, {count = "bad"})
  end
  return {prompt = tostring(payload.count or "")}
end)
local driver = tinest.driver.define({
  id = "driver",
  required_capabilities = {tinest.capability.scheduler.manage},
}, function(_arguments)
  local valid = pcall(function()
    tinest.scheduler.schedule(scheduled, {count = 1})
    tinest.scheduler.continue_after_turn(scheduled, {count = 2})
  end)
  if not valid then error("valid scheduled payload was rejected") end
  local invalid = pcall(function()
    tinest.scheduler.schedule(scheduled, {count = "bad"})
  end)
  if invalid then error("invalid scheduled payload was accepted") end
  return {tool_rounds = 0}
end)
return tinest.plugin.define({driver = driver, hooks = {scheduled}})
''',
);

PluginBundle _schedulerCancelBundle() => _bundle(
  id: 'acme.scheduler',
  capabilities: const <String>['scheduler.manage'],
  source: '''
local tinest = require("tinest")
local S = tinest.schema
local scheduled = tinest.scheduler.handler({
  id = "scheduled",
}, S.map(S.any()), function(_arguments)
  return {}
end)
local driver = tinest.driver.define({
  id = "driver",
  required_capabilities = {tinest.capability.scheduler.manage},
}, function(_arguments)
  local foreign = tinest.scheduler.cancel("foreign")
  if foreign.cancelled ~= false then error("foreign job was cancelled") end
  local own = tinest.scheduler.schedule(scheduled, {}, {delay_ms = 10000})
  local cancelled = tinest.scheduler.cancel(own.id)
  if cancelled.cancelled ~= true then error("owned job was not cancelled") end
  return {tool_rounds = 0}
end)
return tinest.plugin.define({driver = driver, hooks = {scheduled}})
''',
);

PluginBundle _unavailableCallbacksBundle() => _bundle(
  id: 'acme.unavailable',
  capabilities: const <String>[
    'state.read',
    'state.write',
    'scheduler.manage',
    'ui.publish',
    'process.execute',
    'workspace.read',
    'network.access',
    'secret.access',
  ],
  source: '''
local tinest = require("tinest")
local S = tinest.schema
local unavailable_state = tinest.state.cell({
  scope = tinest.state.scope.session, key = "value",
}, S.any())
local scheduled = tinest.scheduler.handler({
  id = "scheduled",
}, S.map(S.any()), function(_arguments)
  return {}
end)
local unavailable_ui = tinest.ui.contribution({
  id = "unavailable-ui", slot = tinest.ui.slot.timeline,
}, S.any(), function(value)
  return tinest.ui.text({text = tostring(value)})
end)

local function must_fail(label, operation)
  local ok, message = pcall(operation)
  if ok then error(label .. " unexpectedly succeeded") end
  if type(message) ~= "string" or message == "" then
    error(label .. " did not return an explicit error")
  end
end

local driver = tinest.driver.define({
  id = "driver",
  uses = {
    tinest.host.lua.start,
    tinest.host.workspace.read_text,
    tinest.host.network.request,
    tinest.host.secret.get,
  },
  required_capabilities = {
    tinest.capability.state.read,
    tinest.capability.state.write,
    tinest.capability.scheduler.manage,
    tinest.capability.ui.publish,
  },
}, function(_arguments)
  must_fail("state.read", function()
    unavailable_state:read()
  end)
  must_fail("state.compare_and_set", function()
    unavailable_state:compare_and_set(0, true)
  end)
  must_fail("state.remove", function()
    unavailable_state:remove(0)
  end)
  must_fail("state.transaction", function()
    unavailable_state:transaction({})
  end)
  must_fail("scheduler.schedule", function()
    tinest.scheduler.schedule(scheduled, {})
  end)
  must_fail("scheduler.cancel", function()
    tinest.scheduler.cancel("missing")
  end)
  must_fail("lua_exec", function()
    tinest.result.unwrap(tinest.host.lua.start({source = "return true"}))
  end)
  must_fail("read_file", function()
    tinest.result.unwrap(tinest.host.workspace.read_text({path = "README.md"}))
  end)
  must_fail("network", function()
    tinest.result.unwrap(tinest.host.network.request({url = "https://example.test"}))
  end)
  must_fail("secret", function()
    tinest.result.unwrap(tinest.host.secret.get({name = "TOKEN"}))
  end)
  return {tool_rounds = 0}
end)

return tinest.plugin.define({
  driver = driver,
  hooks = {scheduled},
  ui = {unavailable_ui},
})
''',
);

PluginBundle _uiPublicationBundle() => _bundle(
  id: 'acme.ui',
  capabilities: const <String>['tools.list', 'tools.invoke', 'ui.publish'],
  source: '''
local tinest = require("tinest")
local S = tinest.schema
local card = tinest.ui.contribution({
  id = "card",
  slot = tinest.ui.slot.timeline,
}, S.any(), function(arguments)
  return tinest.ui.alert({
    id = "published-card",
    title = arguments.arguments.message,
  })
end)
local publish = tinest.tool.function_({
  id = "publish",
  name = "publish",
  description = "Publish a card",
  effects = {tinest.effect.ui.timeline},
  required_capabilities = {tinest.capability.ui.publish},
  presentation = {ui = card},
}, S.object({message = S.string()}), S.any(), function(arguments)
  return {output = "published", structured_content = arguments}
end)
local driver = tinest.driver.define({
  id = "driver",
  required_capabilities = {
    tinest.capability.tools.list,
    tinest.capability.tools.invoke,
  },
}, function(_arguments)
  local descriptor = tinest.tools.resolve(publish, tinest.tools.list())
  tinest.tools.invoke(
    descriptor.ref,
    {message = "hello from Lua"},
    {call_id = "call-ui"}
  )
  return {tool_rounds = 1}
end)

return tinest.plugin.define({driver = driver, tools = {publish}, ui = {card}})
''',
);

PluginBundle _networkHostBundle({bool oversizedRequest = false}) => _bundle(
  id: 'acme.network',
  capabilities: const <String>['network.access', 'state.write'],
  source:
      '''
local tinest = require("tinest")
local S = tinest.schema
local result_state = tinest.state.cell({
  scope = tinest.state.scope.session, key = "result",
}, S.any())
local driver = tinest.driver.define({
  id = "driver",
  uses = {tinest.host.network.request},
  required_capabilities = {tinest.capability.state.write},
}, function(arguments)
  local response = tinest.result.unwrap(tinest.host.network.request({
    url = arguments.prompt,
    method = "POST",
    headers = { ["content-type"] = "text/plain" },
    body = ${oversizedRequest ? 'string.rep("x", ${PluginNetworkLimits.maximumRequestBodyBytes + 1})' : '"request body"'},
  }))
  result_state:compare_and_set(0, response)
  return {tool_rounds = 0}
end)

return tinest.plugin.define({driver = driver})
''',
);

PluginBundle _networkFailureEnvelopeBundle() => _bundle(
  id: 'acme.network-failure',
  capabilities: const <String>['network.access', 'state.write'],
  source: '''
local tinest = require("tinest")
local S = tinest.schema
local result_state = tinest.state.cell({
  scope = tinest.state.scope.session, key = "result",
}, S.any())
local driver = tinest.driver.define({
  id = "driver",
  uses = {tinest.host.network.request},
  required_capabilities = {tinest.capability.state.write},
}, function(arguments)
  local result = tinest.host.network.request({url = arguments.prompt})
  result_state:compare_and_set(0, result)
  return {tool_rounds = 0}
end)

return tinest.plugin.define({driver = driver})
''',
);

PluginBundle _stateReadEnvelopeBundle() => _bundle(
  id: 'acme.state-envelope',
  capabilities: const <String>['state.read', 'state.write'],
  source: '''
local tinest = require("tinest")
local S = tinest.schema
local value_state = tinest.state.cell({
  scope = tinest.state.scope.session, key = "value",
}, S.string())
local result_state = tinest.state.cell({
  scope = tinest.state.scope.session, key = "result",
}, S.any())
local driver = tinest.driver.define({
  id = "driver",
  required_capabilities = {
    tinest.capability.state.read,
    tinest.capability.state.write,
  },
}, function(_arguments)
  local missing = value_state:read()
  if missing.found ~= false then error("missing state was not explicit") end
  value_state:compare_and_set(0, "stored")
  local present = value_state:read()
  if present.found ~= true then error("present state was not explicit") end
  result_state:compare_and_set(0, {
    missing_found = missing.found,
    present_found = present.found,
    present_revision = present.revision,
    present_value = present.value,
  })
  return {tool_rounds = 0}
end)

return tinest.plugin.define({driver = driver})
''',
);

PluginBundle _stateSchemaBundle(String operation) => _bundle(
  id: 'acme.state-schema',
  capabilities: const <String>['state.read', 'state.write'],
  source:
      '''
local tinest = require("tinest")
local S = tinest.schema
local value_state = tinest.state.cell({
  scope = tinest.state.scope.session, key = "value",
}, S.string())
local driver = tinest.driver.define({
  id = "driver",
  required_capabilities = {
    tinest.capability.state.read,
    tinest.capability.state.write,
  },
}, function(_arguments)
  local operation = "$operation"
  if operation == "read" then
    value_state:read()
  elseif operation == "compare_and_set" then
    value_state:compare_and_set(0, {invalid = true})
  else
    value_state:transaction({{
      key = "value", expected_revision = 0, value = {invalid = true},
    }})
  end
  return {tool_rounds = 0}
end)
return tinest.plugin.define({driver = driver})
''',
);

PluginBundle _secretHostBundle(String pluginId) => _bundle(
  id: pluginId,
  capabilities: const <String>['secret.access', 'state.write'],
  source: '''
local tinest = require("tinest")
local S = tinest.schema
local result_state = tinest.state.cell({
  scope = tinest.state.scope.session, key = "result",
}, S.any())
local driver = tinest.driver.define({
  id = "driver",
  uses = {tinest.host.secret.get},
  required_capabilities = {tinest.capability.state.write},
}, function(arguments)
  local secret = tinest.result.unwrap(
    tinest.host.secret.get({name = arguments.prompt})
  )
  result_state:compare_and_set(0, secret)
  return {tool_rounds = 0}
end)

return tinest.plugin.define({driver = driver})
''',
);

PluginBundle _bundle({
  required String id,
  required List<String> capabilities,
  required String source,
  String? revision,
}) {
  final revisionSuffix = revision == null ? '' : '-$revision';
  final descriptor = PluginDescriptorDto(
    apiMajor: 5,
    id: id,
    version: '1.0.0',
    name: id,
    entrypoint: 'main.lua',
    source: PluginSource.user,
    sourcePath: 'plugins/$id',
    requestedCapabilities: capabilities,
    revision: PluginRevisionDto(
      pluginId: id,
      contentHash: '$id-revision$revisionSuffix',
      manifestHash: '$id-manifest$revisionSuffix',
      sdkAbiHash: 'sdk-abi-hash',
      executionRevisionHash: '$id-execution-revision$revisionSuffix',
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

/// A driver that writes [role] straight into the block, bypassing the SDK
/// constant, so the host decode boundary is what has to reject it.
PluginBundle _rawRoleDriverBundle(String role) => _bundle(
  id: 'acme.raw-role',
  capabilities: const <String>['model.call', 'tools.list'],
  source:
      '''
local tinest = require("tinest")

local driver = tinest.driver.define({
  id = "driver",
  uses = {tinest.model.open, tinest.model.next},
  required_model_capabilities = {tinest.model.capability.streaming},
}, function(_arguments)
  local stream = tinest.model.open({
    blocks = {{role = "$role", content = "block"}},
    history = {},
    tools = {},
  })
  while true do
    local next_event = tinest.model.next(stream)
    if next_event.done then break end
  end
  return {tool_rounds = 0}
end)
return tinest.plugin.define({driver = driver})
''',
);

PluginBundle _driverBundle({
  List<String> requiredModelCapabilities = const <String>['streaming'],
}) {
  const descriptor = PluginDescriptorDto(
    apiMajor: 5,
    id: 'acme.driver',
    version: '1.0.0',
    name: 'Driver',
    entrypoint: 'main.lua',
    source: PluginSource.user,
    sourcePath: 'plugins/acme.driver',
    requestedCapabilities: <String>['model.call', 'tools.list'],
    revision: PluginRevisionDto(
      pluginId: 'acme.driver',
      contentHash: 'driver-revision',
      manifestHash: 'driver-manifest',
      sdkAbiHash: 'sdk-abi-hash',
      executionRevisionHash: 'driver-execution-revision',
      requestedCapabilities: <String>['model.call', 'tools.list'],
    ),
  );
  final modelRequirements = requiredModelCapabilities
      .map(
        (value) => switch (value) {
          'streaming' => 'tinest.model.capability.streaming',
          'image_input' => 'tinest.model.capability.image_input',
          'file_input' => 'tinest.model.capability.file_input',
          _ => throw ArgumentError.value(value, 'requiredModelCapabilities'),
        },
      )
      .join(', ');
  final source =
      '''
local tinest = require("tinest")

local function request(arguments, suffix, history)
  local stream = tinest.model.open({
    blocks = {
      {role = tinest.model.role.system, content = arguments.agent_prompt},
      {role = tinest.model.role.system, content = suffix},
    },
    history = history,
    tools = {},
  })
  local completed = nil
  while true do
    local next = tinest.model.next(stream)
    if next.done then break end
    local event = next.value
    if event.type == "completion" then completed = event.assistant end
  end
  return completed
end

local driver = tinest.driver.define({
  id = "driver",
  uses = {tinest.model.open, tinest.model.next},
  required_capabilities = {tinest.capability.tools.list},
  required_model_capabilities = {$modelRequirements},
}, function(arguments)
  local history = arguments.history
  for _, item in ipairs(arguments.turn_inputs or {}) do
    if type(item.attachments) == "table" and
        type(item.attachments[1]) == "table" and
        item.attachments[1].path ~= nil then
      error("host attachment path leaked into Lua")
    end
    table.insert(history, item)
  end
  table.insert(history, {type = "user", text = arguments.prompt, attachments = {}})
  local first = request(arguments, "first", history)
  table.insert(history, first)
  request(arguments, "second", history)
  return {tool_rounds = 0}
end)
return tinest.plugin.define({driver = driver})
''';
  return PluginBundle(
    descriptor: descriptor,
    revision: descriptor.revision!,
    assets: <String, Uint8List>{
      'PLUGIN.md': Uint8List.fromList('---\napi: 5\n---'.codeUnits),
      'main.lua': Uint8List.fromList(source.codeUnits),
    },
  );
}

PluginBundle _modelToolSurfaceBundle({required String? kind}) {
  final constructor = switch (kind) {
    'function' => 'tinest.tool.function_',
    'deferred' => 'tinest.tool.deferred',
    _ => null,
  };
  const schema = 'S.object({})';
  final tool = constructor == null
      ? ''
      : '''
local tool = $constructor({
  id = "tool",
  name = "${kind}_tool",
  description = "A $kind tool.",
}, $schema, nil, function(_arguments) return {} end)
''';
  return _bundle(
    id: 'acme.surface',
    capabilities: const <String>['model.call', 'tools.list'],
    source:
        '''
local tinest = require("tinest")
local S = tinest.schema
$tool
local driver = tinest.driver.define({
  id = "driver",
  uses = {tinest.model.open, tinest.model.next, tinest.tools.list},
  required_model_capabilities = {tinest.model.capability.streaming},
}, function(_arguments)
  local stream = tinest.model.open({
    blocks = {}, history = {}, tools = tinest.tools.list(),
  })
  while true do
    local next_event = tinest.model.next(stream)
    if next_event.done then break end
  end
  return {tool_rounds = 0}
end)
return tinest.plugin.define({
  driver = driver,
  tools = {${constructor == null ? '' : 'tool'}},
})
''',
  );
}

PluginBundle _dynamicModelToolSurfaceBundle() => _bundle(
  id: 'acme.surface',
  capabilities: const <String>['model.call', 'tools.list'],
  source: '''
local tinest = require("tinest")
local S = tinest.schema
local driver = tinest.driver.define({
  id = "driver",
  uses = {tinest.model.open, tinest.model.next, tinest.tools.list,
    tinest.tools.surface},
  required_model_capabilities = {tinest.model.capability.streaming},
}, function(_arguments)
  tinest.tools.list()
  local dynamic_tool = tinest.tool.dynamic({
    id = "dynamic-runtime",
    name = "dynamic_runtime_tool",
    description = "A runtime-created function tool.",
  }, S.object({}), nil, function(_input) return {} end)
  tinest.tools.surface({dynamic_tool})
  local stream = tinest.model.open({
    blocks = {}, history = {}, tools = tinest.tools.list(),
  })
  while true do
    local next_event = tinest.model.next(stream)
    if next_event.done then break end
  end
  return {tool_rounds = 0}
end)
return tinest.plugin.define({driver = driver})
''',
);

PluginBundle _dynamicToolExecutionBundle() => _bundle(
  id: 'acme.dynamic',
  capabilities: const <String>[
    'model.call',
    'tools.list',
    'tools.invoke',
    'workspace.read',
  ],
  source: '''
local tinest = require("tinest")
local S = tinest.schema

local driver = tinest.driver.define({
  id = "driver",
  uses = {
    tinest.model.open,
    tinest.model.next,
    tinest.model.close,
    tinest.tools.list,
    tinest.tools.surface,
    tinest.tools.invoke,
  },
  required_model_capabilities = {tinest.model.capability.streaming},
}, function(_arguments)
  tinest.tools.list()
  local dynamic_tool = tinest.tool.dynamic({
    id = "dynamic-runtime",
    name = "dynamic_runtime_tool",
    description = "Read through a runtime-created tool.",
    uses = {tinest.host.workspace.read_text},
  }, S.object({path = S.string()}), S.object({output = S.string()}),
  function(arguments)
    local stat_ok = pcall(function()
      tinest.result.unwrap(
        tinest.host.workspace.stat({path = arguments.path})
      )
    end)
    if stat_ok then
      error("dynamic callback reached an undeclared same-capability primitive")
    end
    local value = tinest.result.unwrap(
      tinest.host.workspace.read_text({path = arguments.path})
    )
    return {output = value.text}
  end)
  tinest.tools.surface({dynamic_tool})

  local history = {}
  local rounds = 0
  while true do
    local stream = tinest.model.open({
      blocks = {}, history = history, tools = tinest.tools.list(),
    })
    local assistant = nil
    local calls = {}
    while true do
      local next_event = tinest.model.next(stream)
      if next_event.done then break end
      local event = next_event.value
      if event.type == "tool_call" then calls[#calls + 1] = event end
      if event.type == "completion" then assistant = event.assistant end
    end
    tinest.model.close(stream)
    history[#history + 1] = assistant
    if #calls == 0 then return {tool_rounds = rounds} end
    rounds = rounds + 1
    for _, call in ipairs(calls) do
      local result = tinest.tools.invoke(
        call.tool_ref,
        call.arguments,
        {call_id = call.call_id}
      )
      history[#history + 1] = {
        type = "toolResult",
        callId = call.call_id,
        output = tostring(result.output or ""),
        toolKind = tinest.tool.kind.function_,
        isError = result.is_error == true,
        content = result.content or {},
        structuredContent = result.structured_content,
        meta = result._meta or {},
      }
    end
  end
end)

return tinest.plugin.define({driver = driver})
  ''',
);

PluginBundle _toolInputNormalizationBundle() => _bundle(
  id: 'acme.inputs',
  capabilities: const <String>['tools.list', 'tools.invoke'],
  source: '''
local tinest = require("tinest")
local S = tinest.schema
local function_calls = 0
local deferred_calls = 0

local function_tool = tinest.tool.function_({
  id = "function", name = "input_function", description = "function input",
}, S.object({}), S.any(), function(arguments)
  if next(arguments) ~= nil then error("function input was not empty") end
  function_calls = function_calls + 1
  return {output = "function:" .. function_calls}
end)

local deferred_tool = tinest.tool.deferred({
  id = "deferred", name = "input_deferred", description = "deferred input",
}, S.object({}), S.any(), function(arguments)
  if next(arguments) ~= nil then error("deferred input was not empty") end
  deferred_calls = deferred_calls + 1
  return {output = "deferred:" .. deferred_calls}
end)

local text_tool = tinest.tool.function_({
  id = "text", name = "input_text", description = "text input",
}, S.object({source = S.string()}), S.any(), function(arguments)
  return {output = arguments.source}
end)

local driver = tinest.driver.define({
  id = "driver",
  uses = {tinest.tools.list, tinest.tools.invoke},
}, function(_arguments)
  local descriptors = tinest.tools.list()
  local function_ref = tinest.tools.resolve(function_tool, descriptors).ref
  local deferred_ref = tinest.tools.resolve(deferred_tool, descriptors).ref
  local text_ref = tinest.tools.resolve(text_tool, descriptors).ref
  tinest.tools.invoke(function_ref, {})
  tinest.tools.invoke(deferred_ref, {})
  tinest.tools.invoke(text_ref, {source = "raw source"})
  local invalid_ok = pcall(tinest.tools.invoke, function_ref, {"not-an-object"})
  if invalid_ok then error("non-empty array was accepted") end
  tinest.tools.invoke(function_ref, {})
  return {tool_rounds = 5}
end)

return tinest.plugin.define({
  driver = driver,
  tools = {function_tool, deferred_tool, text_tool},
})
  ''',
);

PluginBundle _standardNullToolBundle() => _bundle(
  id: 'acme.standard-null',
  capabilities: const <String>[],
  source: '''
local tinest = require("tinest")
local S = tinest.schema
if NULL ~= nil then error("JSON null magic global remained public") end
for _, name in ipairs({
  "host", "assets", "tools", "store", "load", "ALL_TOOLS",
  "spawn", "await", "await_all", "text", "image", "audio",
  "generated_image", "notify", "yield_control", "exit", "set_timeout",
  "clear_timeout", "_G",
}) do
  if _ENV[name] ~= nil then error(name .. " magic global remained public") end
end
local structural_null_ok = pcall(function()
  S.object(tinest.json.null)
end)
if structural_null_ok then error("JSON null was accepted as a structural table") end
local missing_arguments = tinest.tools.model_input({name = "absent"})
if next(missing_arguments) ~= nil then
  error("an argument-less call was rewritten")
end

local normalize = tinest.tool.function_({
  id = "normalize", name = "normalize_nulls",
  description = "Verify standard-driver JSON-null normalization.",
}, S.object({
  required_string = S.string(),
  required_nullable = S.raw({type = {"string", "null"}}),
  required_nullable_enum = S.raw({
    type = {"string", "null"}, enum = {"first", tinest.json.null},
  }),
  optional = S.optional(S.string()),
  nested = S.object({optional = S.optional(S.string())}),
  mapped = S.map(S.object({optional = S.optional(S.string())})),
  enum_only = S.optional(S.raw({enum = {"first", "second"}})),
  nullable_type_enum_excludes_null = S.optional(S.raw({
    type = {"string", "null"}, enum = {"first", "second"},
  })),
  values = S.array(S.any()),
  empty_object = S.object({}),
  empty_array = S.array(S.any()),
}), nil, function(arguments)
  if arguments.required_string ~= "present" then
    error("required string changed")
  end
  if arguments.required_nullable ~= tinest.json.null then
    error("required nullable value changed")
  end
  if arguments.required_nullable_enum ~= tinest.json.null then
    error("required nullable enum value changed")
  end
  if arguments.optional ~= nil then error("top-level optional null survived") end
  if arguments.nested.optional ~= nil then error("nested optional null survived") end
  if arguments.mapped.first.optional ~= nil then
    error("mapped nested optional null survived")
  end
  if arguments.enum_only ~= nil then error("enum-only optional null survived") end
  if arguments.nullable_type_enum_excludes_null ~= nil then
    error("enum-rejected optional null survived")
  end
  if arguments.values[1] ~= "first" then error("array value changed") end
  if arguments.values[2] ~= tinest.json.null then
    error("array null identity changed")
  end
  if arguments.empty_object == tinest.json.null or
      next(arguments.empty_object) ~= nil then error("empty object changed") end
  if arguments.empty_array == tinest.json.null or
      next(arguments.empty_array) ~= nil then error("empty array changed") end
  return {output = "normalized"}
end)

return tinest.plugin.define({tools = {normalize}})
''',
);

PluginBundle _exactPrimitiveUsesBundle() => _bundle(
  id: 'acme.exact-uses',
  capabilities: const <String>['tools.list', 'tools.invoke', 'workspace.read'],
  source: '''
local tinest = require("tinest")
local S = tinest.schema
local Input = S.object({operation = S.string()})

local function shared(arguments)
  if arguments.operation == "stat" then
    return tinest.result.unwrap(
      tinest.host.workspace.stat({path = "README.md"})
    )
  end
  return tinest.result.unwrap(
    tinest.host.workspace.read_text({path = "README.md"})
  )
end

local read = tinest.tool.function_({
  id = "read", name = "read", description = "declared read",
  uses = {tinest.host.workspace.read_text},
}, Input, nil, shared)

local stat = tinest.tool.function_({
  id = "stat", name = "stat", description = "declared stat",
  uses = {tinest.host.workspace.stat},
}, Input, nil, shared)

local capability_only = tinest.tool.function_({
  id = "capability-only",
  name = "capability_only",
  description = "capability without a primitive declaration",
  required_capabilities = {tinest.capability.workspace.read},
}, Input, nil, shared)

local driver = tinest.driver.define({
  id = "driver",
  uses = {tinest.tools.list, tinest.tools.invoke},
}, function(_arguments)
  local descriptors = tinest.tools.list()
  local read_ref = tinest.tools.resolve(read, descriptors).ref
  local stat_ref = tinest.tools.resolve(stat, descriptors).ref
  local capability_only_ref =
    tinest.tools.resolve(capability_only, descriptors).ref

  if not pcall(tinest.tools.invoke, read_ref, {operation = "read"}) then
    error("declared read_text primitive was denied")
  end
  if pcall(tinest.tools.invoke, read_ref, {operation = "stat"}) then
    error("same-capability undeclared stat primitive was allowed")
  end
  if not pcall(tinest.tools.invoke, stat_ref, {operation = "stat"}) then
    error("declared stat primitive was denied")
  end
  if pcall(
      tinest.tools.invoke,
      capability_only_ref,
      {operation = "read"}
    ) then
    error("required_capabilities authorized an undeclared primitive")
  end
  return {tool_rounds = 4}
end)

return tinest.plugin.define({
  driver = driver,
  tools = {read, stat, capability_only},
})
''',
);

PluginBundle _opaqueRefSecurityBundle() => _bundle(
  id: 'acme.opaque-refs',
  capabilities: const <String>[
    'tools.list',
    'tools.invoke',
    'state.write',
    'scheduler.manage',
  ],
  source: '''
local tinest = require("tinest")
local S = tinest.schema
local cell = tinest.state.cell({
  scope = tinest.state.scope.session,
  key = "opaque-ref",
}, S.any())
local scheduled = tinest.scheduler.handler({
  id = "scheduled",
}, S.any(), function() return {} end)

local return_ref
return_ref = tinest.tool.function_({
  id = "return-ref",
  name = "return_ref",
  description = "Try to serialize its own opaque ref.",
}, S.object({}), nil, function()
  return return_ref
end)

local driver = tinest.driver.define({
  id = "driver",
  uses = {tinest.tools.list, tinest.tools.invoke},
  required_capabilities = {
    tinest.capability.state.write,
    tinest.capability.scheduler.manage,
  },
}, function()
  local function must_fail(label, callback)
    if pcall(callback) then error(label .. " accepted an opaque ref") end
  end

  must_fail("forged", function()
    tinest.tools.invoke({id = "acme.opaque-refs/return-ref"}, {})
  end)
  must_fail("wrong-kind", function()
    tinest.tools.invoke(cell, {})
  end)
  local dynamic = tinest.tool.dynamic({
    id = "not-surfaced",
  }, S.object({}), nil, function() return {} end)
  must_fail("unselected", function()
    tinest.tools.invoke(dynamic, {})
  end)

  local descriptor = tinest.tools.resolve(return_ref, tinest.tools.list())
  if descriptor == nil then error("selected ref was not resolved") end
  must_fail("callback result JSON", function()
    tinest.tools.invoke(descriptor.ref, {})
  end)
  must_fail("state payload", function()
    cell:compare_and_set(0, return_ref)
  end)
  must_fail("scheduler payload", function()
    tinest.scheduler.schedule(scheduled, return_ref)
  end)
  return {tool_rounds = 1}
end)

return tinest.plugin.define({
  driver = driver,
  tools = {return_ref},
  hooks = {scheduled},
})
''',
);

PluginBundle _textToolDriverBundle() => _bundle(
  id: 'acme.text',
  capabilities: const <String>[
    'model.call',
    'tools.list',
    'tools.invoke',
    'workspace.read',
  ],
  source: r'''
local tinest = require("tinest")
local S = tinest.schema
local read = tinest.tool.function_({
  id = "read",
  name = "read_file",
  description = "Read one file",
  uses = {tinest.host.workspace.read_text},
}, S.object({path = S.string()}), S.any(), function(arguments)
  local value = tinest.result.unwrap(
    tinest.host.workspace.read_text({path = arguments.path})
  )
  return {output = value.text}
end)

local function model_response(history)
  local stream = tinest.model.open({
    blocks = {{
      role = tinest.model.role.system,
      content = "Use XML tool syntax only.",
    }},
    history = history,
    tools = {},
  })
  local assistant = nil
  while true do
    local next = tinest.model.next(stream)
    if next.done then break end
    if next.value.type == "completion" then
      assistant = next.value.assistant
    elseif next.value.type == "error" then
      error(next.value.message)
    end
  end
  if type(assistant) ~= "table" then
    error("model stream ended without completion")
  end
  return assistant
end

local driver = tinest.driver.define({
  id = "driver",
  uses = {
    tinest.model.open,
    tinest.model.next,
    tinest.tools.list,
    tinest.tools.invoke,
  },
  required_model_capabilities = {tinest.model.capability.streaming},
}, function(arguments)
  local history = arguments.history or {}
  history[#history + 1] = {
    type = "user", text = arguments.prompt or "", attachments = {},
  }
  local assistant = model_response(history)
  history[#history + 1] = assistant

  local tool_name, path = string.match(
    assistant.text or "",
    '^<tool name="([%w_]+)"><path>([^<]+)</path></tool>$'
  )
  if tool_name == nil or path == nil then error("invalid XML tool call") end

  local selected = nil
  for _, descriptor in ipairs(tinest.tools.list({})) do
    if descriptor.name == tool_name then selected = descriptor break end
  end
  if selected == nil then error("unknown XML tool: " .. tool_name) end

  local result = tinest.tools.invoke(
    selected.ref,
    {path = path},
    {call_id = "text-call-1"}
  )
  history[#history + 1] = {
    type = "toolResult",
    callId = "text-call-1",
    output = tostring(result.output or ""),
    toolKind = "function",
    isError = result.is_error == true,
    structuredContent = result.structured_content,
    content = result.content,
    meta = result._meta,
  }
  model_response(history)
  return {tool_rounds = 1}
end)
return tinest.plugin.define({driver = driver, tools = {read}})
''',
);

PluginBundle _controlEchoBundle() => _bundle(
  id: 'acme.controls',
  capabilities: const <String>['model.call'],
  source: '''
local tinest = require("tinest")
local S = tinest.schema
local alpha = tinest.session.control({
  id = "alpha", metadata = {default = false},
}, S.boolean(), function(arguments)
  return arguments.value == true
end)
local beta = tinest.session.control({
  id = "beta", metadata = {default = "default"},
}, S.string(), function(arguments)
  return tostring(arguments.value)
end)
local before_turn = tinest.hook.before_turn({
  id = "before-turn",
}, function(arguments)
  return {
    prompt = tostring(alpha:get(arguments.session_controls)) .. "|" ..
      tostring(beta:get(arguments.session_controls)) .. "|" ..
      tostring(arguments.enabled),
  }
end)
local driver = tinest.driver.define({
  id = "driver",
  uses = {tinest.model.open, tinest.model.next},
  required_model_capabilities = {tinest.model.capability.streaming},
}, function(arguments)
  local stream = tinest.model.open({
    blocks = {{
      role = tinest.model.role.system,
      content = arguments.extensions[1].prompt,
    }},
    history = {},
    tools = {},
  })
  while true do
    local next = tinest.model.next(stream)
    if next.done then break end
  end
  return {tool_rounds = 0}
end)
return tinest.plugin.define({
  driver = driver,
  hooks = {before_turn},
  session_controls = {alpha, beta},
})
''',
);

PluginBundle _settingsToolBundle() => _bundle(
  id: 'acme.settings',
  capabilities: const <String>['model.call', 'tools.list', 'tools.invoke'],
  source: '''
local tinest = require("tinest")
local S = tinest.schema
local function output(kind, context)
  local settings = context.settings or {}
  return {output = tostring(settings.label) .. ":" .. kind}
end
local function_tool = tinest.tool.function_({
  id = "function", name = "settings_function", description = "function",
}, S.object({kind = S.string()}), S.any(), function(arguments, context)
  return output(arguments.kind, context)
end)
local text_tool = tinest.tool.function_({
  id = "text", name = "settings_text", description = "text",
}, S.object({kind = S.string()}), S.any(), function(arguments, context)
  return output(arguments.kind, context)
end)
local deferred_tool = tinest.tool.deferred({
  id = "deferred", name = "settings_deferred", description = "deferred",
  presentation = {exposure = tinest.tool.exposure.deferred},
}, S.object({kind = S.string()}), S.any(), function(arguments, context)
  return output(arguments.kind, context)
end)
local driver = tinest.driver.define({
  id = "driver",
  uses = {
    tinest.model.open,
    tinest.model.next,
    tinest.tools.list,
    tinest.tools.invoke,
  },
  required_model_capabilities = {tinest.model.capability.streaming},
}, function(_arguments)
  local stream = tinest.model.open({blocks = {}, history = {}, tools = {}})
  while true do
    local next = tinest.model.next(stream)
    if next.done then break end
  end
  local descriptors = tinest.tools.list()
  local calls = {
    {definition = function_tool, arguments = {kind = "function"}},
    {definition = text_tool, arguments = {kind = "text"}},
    {definition = deferred_tool, arguments = {kind = "deferred"}},
  }
  for _, call in ipairs(calls) do
    local descriptor = tinest.tools.resolve(call.definition, descriptors)
    local result = tinest.tools.invoke(descriptor.ref, call.arguments)
    if result.is_error == true then error(result.output) end
  end
  return {tool_rounds = 3}
end)
return tinest.plugin.define({
  driver = driver,
  tools = {function_tool, text_tool, deferred_tool},
})
''',
);

final class _RecordingModelGateway implements ModelGateway {
  final List<ModelRequest> requests = <ModelRequest>[];

  @override
  String get id => 'recording';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    requests.add(request);
    final text = requests.length == 1 ? 'first' : 'second';
    yield ModelTextDelta(text);
    yield ModelResponseCompleted(
      assistant: AssistantConversationItem(text: text),
      usage: const ModelUsage(inputTokens: 2, outputTokens: 1),
    );
  }
}

final class _DynamicToolModelGateway implements ModelGateway {
  new({this.arguments = const <String, dynamic>{'path': 'README.md'}});

  final Map<String, dynamic> arguments;
  final List<ModelRequest> requests = <ModelRequest>[];

  @override
  String get id => 'dynamic-tool-model';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    requests.add(request);
    if (requests.length == 1) {
      yield ModelFunctionCall(
        callId: 'dynamic-call',
        name: 'dynamic_runtime_tool',
        arguments: arguments,
      );
      yield ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.function(
              callId: 'dynamic-call',
              name: 'dynamic_runtime_tool',
              arguments: arguments,
            ),
          ],
        ),
        usage: const ModelUsage(inputTokens: 1, outputTokens: 1),
      );
      return;
    }
    yield const ModelResponseCompleted(
      assistant: AssistantConversationItem(text: 'done'),
      usage: ModelUsage(inputTokens: 1, outputTokens: 1),
    );
  }
}

final class _TextToolModelGateway implements ModelGateway {
  final List<ModelRequest> requests = <ModelRequest>[];

  @override
  String get id => 'text-tool-model';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    requests.add(request);
    final text = requests.length == 1
        ? '<tool name="read_file"><path>README.md</path></tool>'
        : 'done';
    yield ModelTextDelta(text);
    yield ModelResponseCompleted(
      assistant: AssistantConversationItem(text: text),
      usage: const ModelUsage(inputTokens: 2, outputTokens: 1),
    );
  }
}

final class _BlockingModelGateway implements ModelGateway {
  final Completer<void> started = Completer<void>();

  @override
  String get id => 'blocking';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    started.complete();
    while (!cancellation.isCancelled) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    cancellation.throwIfCancelled();
  }
}

final class _GatedCompletionModelGateway implements ModelGateway {
  final Completer<void> started = Completer<void>();
  final Completer<void> release = Completer<void>();

  @override
  String get id => 'gated-completion';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    started.complete();
    await release.future;
    cancellation.throwIfCancelled();
    yield const ModelResponseCompleted(
      assistant: AssistantConversationItem(text: 'released'),
      usage: ModelUsage(inputTokens: 1, outputTokens: 1),
    );
  }
}

final class _ModelStep {
  const new(this.events);

  factory completion(String text) => _ModelStep(<ModelEvent>[
    ModelTextDelta(text),
    ModelResponseCompleted(
      assistant: AssistantConversationItem(text: text),
      usage: const ModelUsage(inputTokens: 4, outputTokens: 2),
    ),
  ]);

  factory events(List<ModelEvent> events) => _ModelStep(events);

  final List<ModelEvent> events;
}

final class _ScriptedModelGateway implements ModelGateway {
  new(this.steps);

  final List<_ModelStep> steps;
  final List<ModelRequest> requests = <ModelRequest>[];

  @override
  String get id => 'scripted-context';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    requests.add(request);
    final index = requests.length - 1;
    if (index >= steps.length) {
      yield ModelResponseCompleted(
        assistant: AssistantConversationItem(text: 'unexpected-${index + 1}'),
      );
      return;
    }
    for (final event in steps[index].events) {
      cancellation.throwIfCancelled();
      yield event;
    }
  }
}

final class _TerminalModelGateway implements ModelGateway {
  final List<ModelRequest> requests = <ModelRequest>[];
  Map<String, Object?> execResult = const <String, Object?>{};
  Map<String, Object?> stdinResult = const <String, Object?>{};

  @override
  String get id => 'terminal-model';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    requests.add(request);
    if (requests.length == 1) {
      const arguments = <String, dynamic>{
        'cmd': 'cat',
        'workdir': null,
        'tty': false,
        'yield_time_ms': 300,
        'max_output_tokens': null,
      };
      yield const ModelFunctionCall(
        callId: 'exec-call',
        name: 'exec_command',
        arguments: arguments,
      );
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.function(
              callId: 'exec-call',
              name: 'exec_command',
              arguments: arguments,
            ),
          ],
        ),
      );
      return;
    }
    if (requests.length == 2) {
      execResult = _toolResultFor(request, 'exec-call');
      final arguments = <String, dynamic>{
        'session_id': execResult['session_id'],
        'chars': 'tinyrack-exec-probe\n',
        'yield_time_ms': 1000,
        'max_output_tokens': null,
      };
      yield ModelFunctionCall(
        callId: 'stdin-call',
        name: 'write_stdin',
        arguments: arguments,
      );
      yield ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.function(
              callId: 'stdin-call',
              name: 'write_stdin',
              arguments: arguments,
            ),
          ],
        ),
      );
      return;
    }
    stdinResult = _toolResultFor(request, 'stdin-call');
    yield const ModelResponseCompleted(
      assistant: AssistantConversationItem(text: 'Done.'),
    );
  }

  Map<String, Object?> _toolResultFor(ModelRequest request, String callId) =>
      Map<String, Object?>.from(
        jsonDecode(
          request.history
              .whereType<ToolResultConversationItem>()
              .firstWhere((item) => item.callId == callId)
              .output,
        ) as Map,
      );
}

final class _PlanUpdateModelGateway implements ModelGateway {
  final List<ModelRequest> requests = <ModelRequest>[];

  @override
  String get id => 'plan-model';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    requests.add(request);
    if (requests.length <= 2) {
      final callId = 'plan-${requests.length}';
      final explanation = requests.length == 1 ? 'First' : 'Second';
      final arguments = <String, dynamic>{
        'explanation': explanation,
        'plan': <Object?>[
          <String, Object?>{
            'step': '$explanation step',
            'status': 'in_progress',
          },
        ],
      };
      yield ModelFunctionCall(
        callId: callId,
        name: 'update_plan',
        arguments: arguments,
      );
      yield ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.function(
              callId: callId,
              name: 'update_plan',
              arguments: arguments,
            ),
          ],
        ),
        usage: const ModelUsage(inputTokens: 1, outputTokens: 1),
      );
      return;
    }
    yield const ModelTextDelta('planned');
    yield const ModelResponseCompleted(
      assistant: AssistantConversationItem(text: 'planned'),
      usage: ModelUsage(inputTokens: 1, outputTokens: 1),
    );
  }
}

final class _ContextBudgetModelGateway implements ModelGateway {
  final List<ModelRequest> requests = <ModelRequest>[];

  @override
  String get id => 'context-budget';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    requests.add(request);
    if (requests.length == 1) {
      yield const ModelFunctionCall(
        callId: 'remaining-call',
        name: 'get_context_remaining',
        arguments: <String, dynamic>{},
      );
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.function(
              callId: 'remaining-call',
              name: 'get_context_remaining',
              arguments: <String, dynamic>{},
            ),
          ],
        ),
        usage: ModelUsage(inputTokens: 60, outputTokens: 10),
      );
      return;
    }
    yield const ModelTextDelta('budget observed');
    yield const ModelResponseCompleted(
      assistant: AssistantConversationItem(text: 'budget observed'),
      usage: ModelUsage(inputTokens: 5, outputTokens: 1),
    );
  }
}

final class _AutomaticCompactionModelGateway implements ModelGateway {
  final List<ModelRequest> requests = <ModelRequest>[];

  @override
  String get id => 'automatic-compaction';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    requests.add(request);
    if (requests.length == 1) {
      yield const ModelTextDelta('large answer');
      yield const ModelResponseCompleted(
        assistant: AssistantConversationItem(text: 'large answer'),
        usage: ModelUsage(inputTokens: 85, outputTokens: 10, totalTokens: 95),
      );
      return;
    }
    yield const ModelTextDelta('Automatic summary');
    yield const ModelResponseCompleted(
      assistant: AssistantConversationItem(text: 'Automatic summary'),
      usage: ModelUsage(inputTokens: 5, outputTokens: 2),
    );
  }
}

final class _OverflowRecoveryModelGateway implements ModelGateway {
  final List<ModelRequest> requests = <ModelRequest>[];

  @override
  String get id => 'overflow-recovery';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    requests.add(request);
    if (requests.length == 1) {
      throw const ModelContextOverflowException('provider window exceeded');
    }
    final text = requests.length == 2
        ? 'Recovered summary'
        : 'continued after recovery';
    yield ModelTextDelta(text);
    yield ModelResponseCompleted(
      assistant: AssistantConversationItem(text: text),
      usage: const ModelUsage(inputTokens: 4, outputTokens: 2),
    );
  }
}

enum _GoalModelPhase { create, complete }

final class _GoalModelGateway implements ModelGateway {
  new({required this.phase, required this.clock});

  final _GoalModelPhase phase;
  final _GoalClock clock;
  final List<ModelRequest> requests = <ModelRequest>[];

  @override
  String get id => 'goal-model';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    requests.add(request);
    final firstRequest = requests.length == 1;
    final elapsed = switch ((phase, firstRequest)) {
      (_GoalModelPhase.create, true) => 2,
      (_GoalModelPhase.create, false) => 3,
      (_GoalModelPhase.complete, true) => 4,
      (_GoalModelPhase.complete, false) => 1,
    };
    clock.advance(Duration(seconds: elapsed));
    if (firstRequest) {
      final callId = phase == _GoalModelPhase.create
          ? 'create-goal'
          : 'complete-goal';
      final name = phase == _GoalModelPhase.create
          ? 'create_goal'
          : 'update_goal';
      final arguments = phase == _GoalModelPhase.create
          ? <String, dynamic>{
              'objective': 'Move the harness to Lua',
              'token_budget': 100,
            }
          : <String, dynamic>{'status': 'complete'};
      yield ModelFunctionCall(callId: callId, name: name, arguments: arguments);
      yield ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: '',
          toolCalls: <ConversationToolCall>[
            ConversationToolCall.function(
              callId: callId,
              name: name,
              arguments: arguments,
            ),
          ],
        ),
        usage: phase == _GoalModelPhase.create
            ? const ModelUsage(inputTokens: 2, outputTokens: 1)
            : const ModelUsage(
                inputTokens: 8,
                cachedInputTokens: 3,
                outputTokens: 2,
              ),
      );
      return;
    }
    yield const ModelTextDelta('done');
    yield ModelResponseCompleted(
      assistant: const AssistantConversationItem(text: 'done'),
      usage: phase == _GoalModelPhase.create
          ? const ModelUsage(
              inputTokens: 10,
              cachedInputTokens: 4,
              outputTokens: 3,
            )
          : const ModelUsage(inputTokens: 1, outputTokens: 1),
    );
  }
}

final class _GoalClock implements Clock {
  new(this._value);

  DateTime _value;

  @override
  DateTime nowUtc() => _value;

  void advance(Duration delta) => _value = _value.add(delta);
}

final class _HostIds implements IdGenerator {
  new(this.prefix);

  final String prefix;
  int _next = 0;

  @override
  String generate() => '$prefix-${++_next}';
}

final class _NeverCancelled implements PluginCancellationSignal {
  const new();

  @override
  void onCancel(void Function() callback) {}
}

final class _CountingPrimitiveHost {
  int readCount = 0;
  int statCount = 0;
  int writeCount = 0;
  int processCount = 0;

  List<int> get counts => <int>[readCount, writeCount, processCount];

  late final HostPrimitiveRegistry registry = HostPrimitiveRegistry(
    <HostPrimitive<Object?, Object?>>[
      HostPrimitive<Map<String, Object?>, Object?>(
        operation: 'host.workspace.read_text',
        capability: 'workspace.read',
        effect: HostPrimitiveEffect.read,
        decode: _primitiveArguments,
        invoke: (_, _) {
          readCount += 1;
          return <String, Object?>{'text': 'read_file executed'};
        },
      ).erased,
      HostPrimitive<Map<String, Object?>, Object?>(
        operation: 'host.workspace.stat',
        capability: 'workspace.read',
        effect: HostPrimitiveEffect.read,
        decode: _primitiveArguments,
        invoke: (_, _) {
          statCount += 1;
          return <String, Object?>{
            'type': 'file',
            'size': 1,
            'modified_at': '2026-01-01T00:00:00.000Z',
          };
        },
      ).erased,
      HostPrimitive<Map<String, Object?>, Object?>(
        operation: 'host.workspace.transaction',
        capability: 'workspace.patch',
        effect: HostPrimitiveEffect.write,
        decode: _primitiveArguments,
        invoke: (_, _) {
          writeCount += 1;
          return <String, Object?>{'output': 'apply_patch executed'};
        },
      ).erased,
      HostPrimitive<Map<String, Object?>, Object?>(
        operation: 'host.process.start',
        capability: 'process.execute',
        effect: HostPrimitiveEffect.command,
        decode: _primitiveArguments,
        invoke: (_, _) {
          processCount += 1;
          return <String, Object?>{'output': 'exec_command executed'};
        },
      ).erased,
    ],
  );
}

final class _TerminalPrimitiveHost {
  final List<String> writes = <String>[];
  var _reads = 0;

  late final HostPrimitiveRegistry registry = HostPrimitiveRegistry(
    <HostPrimitive<Object?, Object?>>[
      HostPrimitiveContracts.processStart
          .bind(
            decode: _primitiveArguments,
            invoke: (_, _) => <String, Object?>{'handle': 73},
          )
          .erased,
      HostPrimitiveContracts.processRead
          .bind(
            decode: _primitiveArguments,
            invoke: (_, _) {
              _reads += 1;
              return <String, Object?>{
                'output': _reads == 1 ? '' : 'tinyrack-exec-probe\n',
                'running': true,
                'wall_time_ms': _reads,
              };
            },
          )
          .erased,
      HostPrimitiveContracts.processWrite
          .bind(
            decode: _primitiveArguments,
            invoke: (arguments, _) {
              writes.add(arguments['chars']! as String);
              return <String, Object?>{'written': true};
            },
          )
          .erased,
    ],
  );
}

Map<String, Object?> _primitiveArguments(Object? value) =>
    Map<String, Object?>.from(value! as Map);

final class _BundleLoader implements PluginBundleLoader {
  const new(this.bundle);

  final PluginBundle bundle;

  @override
  Future<PluginBundle> load(String id) async => bundle;
}

final class _BundleMapLoader implements PluginBundleLoader {
  const new(this.bundles);

  final Map<String, PluginBundle> bundles;

  @override
  Future<PluginBundle> load(String id) async => bundles[id]!;
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

final class _RecordingPluginNetworkGateway implements PluginNetworkGateway {
  final List<PluginNetworkRequest> requests = <PluginNetworkRequest>[];
  PluginNetworkResponse response = PluginNetworkResponse(
    statusCode: 200,
    headers: const <String, List<String>>{
      'content-type': <String>['text/plain; charset=utf-8'],
    },
    body: utf8.encode('network response'),
  );

  @override
  Future<PluginNetworkResponse> send(
    PluginNetworkRequest request,
    PluginOperationCancellation cancellation,
  ) async {
    requests.add(request);
    return response;
  }
}

final class _BlockingPluginNetworkGateway implements PluginNetworkGateway {
  final Completer<void> started = Completer<void>();
  final Completer<PluginNetworkResponse> _result =
      Completer<PluginNetworkResponse>();
  bool cancelled = false;

  @override
  Future<PluginNetworkResponse> send(
    PluginNetworkRequest request,
    PluginOperationCancellation cancellation,
  ) {
    if (!started.isCompleted) started.complete();
    cancellation.onCancel(() {
      cancelled = true;
      if (!_result.isCompleted) {
        _result.completeError(const PluginHostOperationCancelledException());
      }
    });
    return _result.future;
  }
}

final class _FailingPluginNetworkGateway implements PluginNetworkGateway {
  const new(this.kind);

  final String kind;

  @override
  Future<PluginNetworkResponse> send(
    PluginNetworkRequest request,
    PluginOperationCancellation cancellation,
  ) => Future<PluginNetworkResponse>.error(
    PluginNetworkTransportException(kind),
  );
}

final class _MemoryPluginSecretStore implements PluginSecretStore {
  final Map<String, String> _values = <String, String>{};
  final List<PluginSecretScope> reads = <PluginSecretScope>[];

  Future<void> set(PluginSecretScope scope, String name, String value) async {
    _values[_key(scope, name)] = value;
  }

  @override
  Future<String?> read(PluginSecretScope scope, String name) async {
    reads.add(scope);
    return _values[_key(scope, name)];
  }

  String _key(PluginSecretScope scope, String name) =>
      '${scope.agentId}/${scope.pluginId}/$name';
}

final class _RecordingApprovalCoordinator implements ApprovalCoordinator {
  new(this.decision);

  final ApprovalDecision decision;
  final List<ToolInvocation> invocations = <ToolInvocation>[];

  @override
  Future<ApprovalDecision> request(
    ToolInvocation invocation,
    CancellationToken cancellation,
  ) async {
    invocations.add(invocation);
    return decision;
  }
}

final class _AskPolicy implements ApprovalPolicy {
  const new();

  @override
  ApprovalEvaluation evaluate(ToolInvocation invocation) =>
      ApprovalEvaluation.ask;
}

final class _AllowPolicy implements ApprovalPolicy {
  const new();

  @override
  ApprovalEvaluation evaluate(ToolInvocation invocation) =>
      ApprovalEvaluation.allow;
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
