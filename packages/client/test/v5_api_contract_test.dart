import 'package:client/client.dart';
import 'package:test/test.dart';

void main() {
  test('TinestApi exposes the v5 feature boundaries', () {
    final api = _ApiShapeProbe();

    expect(api.workspaces, isA<WorkspacesApi>());
    expect(api.sessions, isA<SessionsApi>());
    expect(api.agents, isA<AgentsApi>());
    expect(api.plugins, isA<PluginsApi>());
    expect(api.prompts, isA<PromptsApi>());
    expect(api.providers, isA<ProvidersApi>());
    expect(api.mcp, isA<McpApi>());
    expect(api.terminals, isA<TerminalsApi>());
    expect(api.attachments, isA<AttachmentsApi>());
    expect(api.relay, isA<RelayApi>());
  }, tags: const <String>['feature_test__daemon_relay__contract']);
}

final class _ApiShapeProbe
    implements
        TinestApi,
        WorkspacesApi,
        SessionsApi,
        AgentsApi,
        PluginsApi,
        PromptsApi,
        ProvidersApi,
        McpApi,
        TerminalsApi,
        AttachmentsApi,
        RelayApi {
  @override
  WorkspacesApi get workspaces => this;

  @override
  SessionsApi get sessions => this;

  @override
  AgentsApi get agents => this;

  @override
  PluginsApi get plugins => this;

  @override
  PromptsApi get prompts => this;

  @override
  ProvidersApi get providers => this;

  @override
  McpApi get mcp => this;

  @override
  TerminalsApi get terminals => this;

  @override
  AttachmentsApi get attachments => this;

  @override
  RelayApi get relay => this;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
