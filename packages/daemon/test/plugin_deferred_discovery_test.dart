@Tags(<String>['feature_test__tool_search_deferred__unit'])
@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:agent/agent.dart';
import 'package:daemon/src/features/plugins/infrastructure/native_plugin_state_repository.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_bundles.dart';
import 'package:daemon/src/features/plugins/runtime/host_primitives.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_agent_harness.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_runtime.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart' show IdGenerator;
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
      'tinest-plugin-discovery-host-',
    );
    buildDirectory = await Directory.systemTemp.createTemp(
      'tinest-plugin-discovery-build-',
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
    'surfaces and invokes an MCP tool only through a revision-bound template',
    () async {
      final stateRoot = await Directory.systemTemp.createTemp(
        'tinest-plugin-discovery-state-',
      );
      addTearDown(() => stateRoot.delete(recursive: true));
      const catalog = BuiltInPluginCatalog();
      final standard = await catalog.load('tinest.standard');
      final mcp = await catalog.load('tinest.mcp');
      final revisions = PluginRevisionCatalog(
        loader: _BundleMapLoader(<String, PluginBundle>{
          standard.descriptor.id: standard,
          mcp.descriptor.id: mcp,
        }),
        cache: NativePluginRevisionCache(stateRoot.path),
      );
      final grants = <String, Set<String>>{};
      for (final bundle in <PluginBundle>[standard, mcp]) {
        final capabilities = bundle.descriptor.requestedCapabilities.toSet();
        grants[bundle.descriptor.id] = capabilities;
        await revisions.reload(
          bundle.descriptor.id,
          agentId: 'discovery-agent',
          approvedCapabilities: capabilities,
        );
      }
      final runtime = PluginRuntime<ConversationAttachment>(
        luaRuntime: lua.LuaToolRuntime<ConversationAttachment>(
          host: lua.LuaHostCommand.fromDirectory(stagedHost.path),
          processLauncher: const lua.IoLuaHostProcessLauncher(),
          clock: const lua.SystemLuaClock(),
          ids: _LuaIds(),
        ),
        revisions: revisions,
      );
      addTearDown(runtime.close);
      final mcpHost = _FakeMcpHost();
      final approval = _RecordingApprovalCoordinator();
      final model = _DiscoveryModelGateway();
      final persisted = <ConversationItem>[];

      await LuaAgentHarness(runtime: runtime).startTurn(
        request: LuaAgentHarnessRequest(
          definition: _definition,
          sessionId: 'session-1',
          turnId: 'turn-1',
          workspaceRoot: Directory.current.path,
          prompt: 'Schedule a calendar event.',
          modelId: 'model-1',
          model: model,
          modelCapabilities: const AgentModelCapabilities(
            streaming: AgentCapabilitySupport.supported,
            toolCalling: AgentCapabilitySupport.supported,
            functionTools: AgentCapabilitySupport.supported,
            deferredTools: AgentCapabilitySupport.supported,
          ),
          history: const <ConversationItem>[],
          allowedCapabilitiesByPlugin: grants,
          primitives: mcpHost.registry,
          state: NativePluginStateRepository(stateRoot.path),
          approvals: approval,
          policyFactory: (_) => const _AskPolicy(),
          ids: _HostIds(),
        ),
        callbacks: LuaAgentHarnessCallbacks(
          onEvent: (_, _) {},
          onStatus: (_, {error}) {},
          onProviderItems: persisted.addAll,
        ),
        cancellation: CancellationToken(),
      );

      expect(model.requests, hasLength(3));
      expect(model.requests.first.tools.map((tool) => tool.name), <String>[
        'tool_search_mcp',
      ]);
      expect(
        model.requests[1].tools.map((tool) => tool.name),
        contains('mcp__calendar__create_event'),
        reason: persisted
            .whereType<ToolResultConversationItem>()
            .map((item) => '${item.callId}: ${item.output}')
            .join('\n'),
      );
      expect(
        model.requests[1].tools.map((tool) => tool.name),
        isNot(contains('mcp__issues__close_ticket')),
      );
      expect(mcpHost.invocations, <Map<String, Object?>>[
        <String, Object?>{
          'server': 'calendar',
          'name': 'create_event',
          'arguments': <String, Object?>{'title': 'Planning'},
        },
      ]);
      expect(
        approval.invocations.map((invocation) => invocation.name),
        contains('mcp__calendar__create_event'),
      );
      expect(
        persisted.whereType<ToolResultConversationItem>().map(
          (item) => item.callId,
        ),
        containsAll(<String>['search-1', 'calendar-1']),
      );
    },
  );
}

const AgentDefinitionDto _definition = AgentDefinitionDto(
  version: 5,
  id: 'discovery-agent',
  name: 'Discovery Agent',
  description: '',
  mode: AgentMode.primary,
  model: AgentModelSelectionDto(source: AgentModelSource.session),
  driverId: 'tinest.standard/driver',
  extensionIds: <String>[],
  toolIds: <String>['tinest.mcp/tool_search'],
  pluginSettings: <String, Map<String, dynamic>>{},
  callableAgentIds: <String>[],
  prompt: '',
  contentHash: 'discovery-agent-hash',
  sourcePath: 'agent.md',
);

final class _FakeMcpHost {
  final List<Map<String, Object?>> invocations = <Map<String, Object?>>[];

  late final HostPrimitiveRegistry registry = HostPrimitiveRegistry(
    <HostPrimitive<Object?, Object?>>[
      HostPrimitive<Map<String, Object?>, Object?>(
        operation: 'host.mcp.catalog_tools',
        capability: 'mcp.read',
        effect: HostPrimitiveEffect.read,
        decode: _object,
        invoke: (_, _) async => <String, Object?>{
          'tools': <Map<String, Object?>>[
            _descriptor(
              server: 'calendar',
              name: 'create_event',
              description: 'Create a calendar event.',
            ),
            _descriptor(
              server: 'issues',
              name: 'close_ticket',
              description: 'Close an issue tracker ticket.',
            ),
          ],
        },
      ).erased,
      HostPrimitive<Map<String, Object?>, Object?>(
        operation: 'host.mcp.invoke_tool',
        capability: 'mcp.invoke',
        effect: HostPrimitiveEffect.dangerous,
        decode: _object,
        invoke: (arguments, _) async {
          invocations.add(Map<String, Object?>.from(arguments));
          return <String, Object?>{
            'content': <Map<String, Object?>>[
              <String, Object?>{
                'type': 'text',
                'text': 'created ${_object(arguments['arguments'])['title']}',
              },
            ],
            'isError': false,
          };
        },
      ).erased,
    ],
  );
}

Map<String, Object?> _descriptor({
  required String server,
  required String name,
  required String description,
}) => <String, Object?>{
  'server': server,
  'name': name,
  'description': description,
  'inputSchema': <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{
      'title': <String, Object?>{'type': 'string'},
    },
    'required': <String>['title'],
    'additionalProperties': false,
  },
};

final class _DiscoveryModelGateway implements ModelGateway {
  final List<ModelRequest> requests = <ModelRequest>[];

  @override
  String get id => 'discovery-model';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    requests.add(request);
    switch (requests.length) {
      case 1:
        const arguments = <String, dynamic>{'query': 'calendar', 'limit': 1};
        yield const ModelDeferredSearchCall(
          callId: 'search-1',
          name: 'tool_search_mcp',
          arguments: arguments,
        );
        yield const ModelResponseCompleted(
          assistant: AssistantConversationItem(
            text: '',
            toolCalls: <ConversationToolCall>[
              ConversationToolCall.deferredSearch(
                callId: 'search-1',
                name: 'tool_search_mcp',
                arguments: arguments,
              ),
            ],
          ),
        );
      case 2:
        const arguments = <String, dynamic>{'title': 'Planning'};
        yield const ModelFunctionCall(
          callId: 'calendar-1',
          name: 'mcp__calendar__create_event',
          arguments: arguments,
        );
        yield const ModelResponseCompleted(
          assistant: AssistantConversationItem(
            text: '',
            toolCalls: <ConversationToolCall>[
              ConversationToolCall.function(
                callId: 'calendar-1',
                name: 'mcp__calendar__create_event',
                arguments: arguments,
              ),
            ],
          ),
        );
      default:
        yield const ModelResponseCompleted(
          assistant: AssistantConversationItem(text: 'Done.'),
        );
    }
  }
}

final class _BundleMapLoader implements PluginBundleLoader {
  const new(this.bundles);

  final Map<String, PluginBundle> bundles;

  @override
  Future<PluginBundle> load(String id) async => bundles[id]!;
}

final class _AskPolicy implements ApprovalPolicy {
  const new();

  @override
  ApprovalEvaluation evaluate(ToolInvocation invocation) =>
      ApprovalEvaluation.ask;
}

final class _RecordingApprovalCoordinator implements ApprovalCoordinator {
  final List<ToolInvocation> invocations = <ToolInvocation>[];

  @override
  Future<ApprovalDecision> request(
    ToolInvocation invocation,
    CancellationToken cancellation,
  ) async {
    invocations.add(invocation);
    return ApprovalDecision.approved;
  }
}

final class _LuaIds implements lua.LuaIdGenerator {
  int _next = 0;

  @override
  String generate() => '${++_next}';
}

final class _HostIds implements IdGenerator {
  int _next = 0;

  @override
  String generate() => 'dynamic-${++_next}';
}

Map<String, Object?> _object(Object? value) => value is Map<Object?, Object?>
    ? <String, Object?>{
        for (final entry in value.entries) entry.key.toString(): entry.value,
      }
    : throw const FormatException('Expected an object.');

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
