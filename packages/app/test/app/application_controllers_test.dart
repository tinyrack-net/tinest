import 'dart:async';

import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/app/composition/app_services.dart';
import 'package:app/src/features/conversation/application/agent_commands_controller.dart';
import 'package:app/src/features/conversation/application/composer_controller.dart';
import 'package:app/src/features/conversation/application/conversation_controller.dart';
import 'package:app/src/features/conversation/application/pending_turns_controller.dart';
import 'package:app/src/features/hosts/application/host_controller.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/hosts/domain/host_ports.dart';
import 'package:app/src/features/mcp/application/mcp_servers_controller.dart';
import 'package:app/src/features/providers/application/provider_settings_controller.dart';
import 'package:app/src/features/sessions/application/session_tabs_controller.dart';
import 'package:app/src/features/sessions/application/sessions_controller.dart';
import 'package:app/src/features/workspace/application/workspace_controller.dart';
import 'package:client/client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';

import '../support/fake_tinest_api.dart';

part '../features/conversation/controller_test_cases.dart';
part '../features/providers/controller_test_cases.dart';
part '../features/workspace/controller_test_cases.dart';
part 'controller_contract_test_cases.dart';

void main() {
  _registerWorkspaceControllerTests();
  _registerConversationControllerTests();
  _registerProvidersControllerTests();
  _registerContractsControllerTests();
}

AgentCommandDto _agentCommand(String name) => AgentCommandDto(
  id: name,
  name: name,
  description: 'Runs $name.',
  source: AgentCommandSource.project,
  sourcePath: '/workspace/.agents/commands/$name.md',
  body: 'Run $name.',
);

ProviderContainer _container(FakeTinestApi api) => ProviderContainer(
  overrides: [
    appServicesProvider.overrideWithValue(fakeAppServices(api)),
    appIdGeneratorProvider.overrideWithValue(const _FixedIdGenerator()),
  ],
);

ProviderContainer _queueContainer(FakeTinestApi api) => ProviderContainer(
  overrides: [
    appServicesProvider.overrideWithValue(fakeAppServices(api)),
    appIdGeneratorProvider.overrideWithValue(_SequentialIdGenerator()),
  ],
);

/// Brings one conversation controller up and returns its provider.
Future<ConversationControllerProvider> _readyQueueProvider(
  ProviderContainer container,
  SessionDto agent,
) async {
  await container.read(hostRegistryControllerProvider.future);
  await Future<void>.delayed(Duration.zero);
  final provider = conversationControllerProvider('server', agent.id);
  final listener = container.listen(provider, (_, _) {});
  addTearDown(listener.close);
  await container.read(provider.future);
  return provider;
}

/// Lets every armed queue-release retry fire.
///
/// The retries are real timers rather than microtasks, so a plain
/// `Duration.zero` hop would observe the state between attempts instead of
/// the settled one.
Future<void> _settleDrainRetries({int rounds = 2}) async {
  for (var round = 0; round < rounds; round += 1) {
    await Future<void>.delayed(conversationDrainRetryDelay * 2);
  }
}

RemoteDaemonProfile _profile(String id, DateTime now) => RemoteDaemonProfile(
  id: id,
  label: id,
  connections: directHostConnections(Uri.parse('ws://$id.test/ws')),
  autoConnect: true,
  createdAt: now,
  updatedAt: now,
);

ServerInfoDto _serverInfo(String id) => ServerInfoDto(
  serverId: id,
  version: 'test',
  protocolVersion: tinestProtocolMajor,
  features: const <String, bool>{},
);

final class _HostClients implements HostClientFactory {
  const new(this.apis);

  final Map<String, TinestApi> apis;

  @override
  Future<TinestApi> connect({
    required HostConnection connection,
    required HostConnectionCredential credential,
    required String clientId,
    required String clientKind,
  }) async =>
      apis[(connection as DirectHostConnection).endpoint.websocketUri.host]!;
}

final class _FixedIdGenerator implements AppIdGenerator {
  const new();

  @override
  String generate() => 'generated-id';
}

final class _SequentialIdGenerator implements AppIdGenerator {
  var _next = 0;

  @override
  String generate() => 'generated-id-${_next++}';
}

final class _LateClientEventStream extends Stream<ClientEvent> {
  void Function(ClientEvent)? _onData;

  @override
  StreamSubscription<ClientEvent> listen(
    void Function(ClientEvent)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    _onData = onData;
    return const Stream<ClientEvent>.empty().listen(
      null,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  void emit(ClientEvent event) => _onData?.call(event);
}
