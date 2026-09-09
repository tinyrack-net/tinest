part of '../../app/application_controllers_test.dart';

void _registerProvidersControllerTests() {
  const model = ProviderModelDto(
    connectionId: 'openai',
    id: 'openai/gpt-5.6-sol',
    providerModelId: 'gpt-5.6-sol',
    label: 'GPT',
    source: ProviderModelSource.bundled,
    capabilities: ModelCapabilitiesDto(
      streaming: CapabilitySupport.supported,
      toolCalling: CapabilitySupport.supported,
    ),
  );

  test(
    'provider settings notifier performs every administrative command',
    () async {
      final api = FakeTinestApi(
        models: const <String, List<ProviderModelDto>>{
          'openai': <ProviderModelDto>[model],
        },
      );
      final container = _container(api);
      addTearDown(container.dispose);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      final provider = providerSettingsControllerProvider('server');
      final notifier = container.read(provider.notifier);
      final initial = await container.read(provider.future);
      expect(initial!.catalog.definitions.first.id, 'openai');
      expect(initial.connections.single.id, 'openai');

      await notifier.loadModels('openai');
      expect(
        container.read(provider).value!.models['openai'],
        <ProviderModelDto>[model],
      );
      final connected = await notifier.connectApiKey('deepseek', 'secret');
      expect(connected.definitionId, 'deepseek');
      expect(api.credentials['deepseek'], 'secret');
      final attempt = await notifier.startAuth('openai', 'chatgpt-browser');
      expect(attempt.status, ProviderAuthAttemptStatus.awaitingUser);
      await notifier.cancelAuth(attempt.id);
      await notifier.refreshCatalog();
      expect(
        container.read(provider).value!.catalog.source,
        ProviderCatalogSource.refreshed,
      );
      final custom = await notifier.createCustom(
        'custom',
        const CustomProviderConfigDto(
          name: 'Custom',
          baseUrl: 'http://127.0.0.1:9000/v1',
          wireFormatId: 'openai-chat-completions',
          authenticationRequired: false,
          models: <ManualProviderModelDto>[
            ManualProviderModelDto(id: 'manual', label: 'manual'),
          ],
        ),
      );
      expect(custom.displayName, 'Custom');
      await notifier.updateCustom(
        custom.id,
        custom.customConfig!.copyWith(name: 'Updated'),
      );
      await notifier.deleteCustom(custom.id);
      await notifier.disconnect('deepseek');
      expect(
        container
            .read(provider)
            .value!
            .connections
            .singleWhere((item) => item.id == 'deepseek')
            .status,
        ProviderConnectionStatus.disconnected,
      );
    },
  );

  test(
    'provider settings retains every concurrent model catalog result',
    () async {
      const first = ProviderModelDto(
        connectionId: 'first',
        id: 'first/very-long-model-identifier',
        label: 'First very long model label',
        source: ProviderModelSource.discovered,
        capabilities: ModelCapabilitiesDto(),
      );
      const second = ProviderModelDto(
        connectionId: 'second',
        id: 'second/very-long-model-identifier',
        label: 'Second very long model label',
        source: ProviderModelSource.discovered,
        capabilities: ModelCapabilitiesDto(),
      );
      final api = FakeTinestApi(
        models: const <String, List<ProviderModelDto>>{
          'first': <ProviderModelDto>[first],
          'second': <ProviderModelDto>[second],
        },
      );
      final container = _container(api);
      addTearDown(container.dispose);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      final provider = providerSettingsControllerProvider('server');
      await container.read(provider.future);

      await Future.wait(<Future<void>>[
        container.read(provider.notifier).loadModels('first'),
        container.read(provider.notifier).loadModels('second'),
      ]);

      // The build already seeds the first usable connection, so assert that
      // neither concurrent load dropped the other rather than the exact map.
      expect(
        container.read(provider).value!.models,
        allOf(
          containsPair('first', const <ProviderModelDto>[first]),
          containsPair('second', const <ProviderModelDto>[second]),
        ),
      );
    },
    tags: const <String>['feature_test__provider_catalog__unit'],
  );

  test('MCP reload ignores an older response that completes last', () async {
    const config = McpServerConfigDto(
      id: 'e2e',
      transport: McpTransportKind.stdio,
      command: '/missing',
    );
    const connecting = McpServerStateDto(
      config: config,
      scope: McpConfigScope.user,
      sourcePath: '/config/mcp.json',
      status: McpServerStatus.connecting,
    );
    const failed = McpServerStateDto(
      config: config,
      scope: McpConfigScope.user,
      sourcePath: '/config/mcp.json',
      status: McpServerStatus.failed,
      error: 'planned process failure',
    );
    final api = FakeTinestApi();
    final container = _container(api);
    addTearDown(container.dispose);
    await container.read(hostRegistryControllerProvider.future);
    await Future<void>.delayed(Duration.zero);
    final provider = mcpServersControllerProvider('server', null);
    await container.read(provider.future);

    final older = Completer<List<McpServerStateDto>>();
    final newer = Completer<List<McpServerStateDto>>();
    api.mcpListResponses.addAll(<Future<List<McpServerStateDto>>>[
      older.future,
      newer.future,
    ]);
    final first = container.read(provider.notifier).refresh();
    final second = container.read(provider.notifier).refresh();
    newer.complete(const <McpServerStateDto>[failed]);
    await second;
    older.complete(const <McpServerStateDto>[connecting]);
    await first;

    expect(container.read(provider).value!.servers, <McpServerStateDto>[
      failed,
    ]);
  }, tags: const <String>['feature_test__mcp_server_management__unit']);

  test(
    'MCP add exposes the created server before a newer reload finishes',
    () async {
      const config = McpServerConfigDto(
        id: 'e2e',
        transport: McpTransportKind.stdio,
        command: 'dart',
      );
      const created = McpServerStateDto(
        config: config,
        scope: McpConfigScope.user,
        sourcePath: '/config/mcp.json',
        status: McpServerStatus.ready,
        serverName: 'e2e',
      );
      final api = FakeTinestApi();
      final container = _container(api);
      addTearDown(container.dispose);
      await container.read(hostRegistryControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      final provider = mcpServersControllerProvider('server', null);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(provider.future);

      final mutationReload = Completer<List<McpServerStateDto>>();
      final eventReload = Completer<List<McpServerStateDto>>();
      api.mcpListResponses.addAll(<Future<List<McpServerStateDto>>>[
        mutationReload.future,
        eventReload.future,
      ]);
      final adding = container.read(provider.notifier).add(config);
      await Future<void>.delayed(Duration.zero);
      final eventRefresh = container.read(provider.notifier).refresh();
      mutationReload.complete(const <McpServerStateDto>[created]);
      await adding;

      final visible = container.read(provider).requireValue.servers;
      expect(visible, hasLength(1));
      expect(visible.single.config, config);
      expect(visible.single.status, McpServerStatus.ready);

      eventReload.complete(const <McpServerStateDto>[created]);
      await eventRefresh;
    },
    tags: const <String>['feature_test__mcp_server_management__unit'],
  );
}
