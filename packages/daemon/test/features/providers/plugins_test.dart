@Tags(<String>['feature_test__provider_catalog__unit'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:agent/agent.dart';
import 'package:daemon/src/features/providers/infrastructure/anthropic/plugin.dart';
import 'package:daemon/src/features/providers/infrastructure/anthropic/wire.dart';
import 'package:daemon/src/features/providers/infrastructure/gemini/plugin.dart';
import 'package:daemon/src/features/providers/infrastructure/gemini/wire.dart';
import 'package:daemon/src/features/providers/infrastructure/openai/openai.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

import '../../support/agent_conformance.dart';

void main() {
  final clock = _FixedClock(DateTime.utc(2026, 8, 2));

  // Every vendor this package registers inherits the full plugin contract.
  for (final plugin in openAIFamilyAdapters(
    clock: clock,
    openAIOAuth: const _UnusedGateway(),
  )) {
    providerAdapterConformanceTests(plugin.id, () => plugin);
  }
  for (final wire in openAIWireProtocols()) {
    providerWireProtocolConformanceTests(wire.id, () => wire);
  }
  providerAdapterConformanceTests('anthropic', () => const AnthropicAdapter());
  providerWireProtocolConformanceTests(
    anthropicMessagesWireId,
    () => const AnthropicMessagesWire(),
  );
  providerAdapterConformanceTests('google', () => const GoogleGeminiAdapter());
  providerWireProtocolConformanceTests(
    geminiInteractionsWireId,
    () => const GeminiInteractionsWire(),
  );

  test('the family registers each vendor and both wire protocols once', () {
    final registry = ProviderRegistry(
      adapters: openAIFamilyAdapters(
        clock: clock,
        openAIOAuth: const _UnusedGateway(),
      ),
      wireProtocols: openAIWireProtocols(),
    );

    expect(registry.adapters.map((adapter) => adapter.id), <String>[
      'openai',
      'deepseek',
      'openrouter',
      'groq',
      'xai',
      'minimax',
      'minimax-cn',
      'ollama',
      'lmstudio',
      'vllm',
    ]);
    // Chat Completions first: the first registered format is what a new
    // custom connection defaults to, and most custom endpoints are local
    // OpenAI-compatible servers.
    expect(registry.wireProtocols.map((wire) => wire.id), <String>[
      openAIChatCompletionsWireId,
      openAIResponsesWireId,
    ]);
    // Local servers advertise unauthenticated connect; hosted ones never do.
    for (final plugin in registry.adapters) {
      final flows = plugin.definition.authMethods.map((method) => method.flow);
      expect(
        flows.contains(AgentProviderAuthFlow.none),
        plugin.definition.local,
        reason: plugin.id,
      );
    }
  });

  test('a vendor that lists models says so on its endpoint', () {
    // Discovery is skipped for an endpoint that has not stated it serves a
    // listing, so a vendor whose wire implements one has to declare it or the
    // listing silently never runs and only bundled models appear.
    for (final adapter in <ProviderAdapter>[
      const AnthropicAdapter(),
      const GoogleGeminiAdapter(),
    ]) {
      expect(
        adapter
            .endpoint(AgentProviderAuthKind.apiKey)
            .accepts(ProviderEndpointExtension.modelDiscovery),
        isTrue,
        reason: adapter.id,
      );
    }
  });

  test('the two MiniMax regions differ only by host', () {
    final adapters = openAIFamilyAdapters(
      clock: clock,
      openAIOAuth: const _UnusedGateway(),
    );
    final international = adapters.firstWhere(
      (adapter) => adapter.id == 'minimax',
    );
    final china = adapters.firstWhere((adapter) => adapter.id == 'minimax-cn');

    expect(
      international.endpoint(AgentProviderAuthKind.apiKey).baseUrl,
      'https://api.minimax.io/v1',
    );
    expect(
      china.endpoint(AgentProviderAuthKind.apiKey).baseUrl,
      'https://api.minimaxi.com/v1',
    );
    expect(
      china.models.map((model) => model.id),
      international.models.map((model) => model.id),
    );
    for (final adapter in <ProviderAdapter>[international, china]) {
      // MiniMax documents no `/models` listing, and Models.dev namespaces its
      // models under identifiers the MiniMax API rejects, so the bundled
      // catalog is the whole model set for both regions.
      expect(
        adapter
            .endpoint(AgentProviderAuthKind.apiKey)
            .accepts(ProviderEndpointExtension.modelDiscovery),
        isFalse,
        reason: adapter.id,
      );
      expect(adapter.usesRemoteCatalog, isFalse, reason: adapter.id);
      // MiniMax thinks adaptively, so an effort control would be inert.
      expect(
        adapter.models.expand((model) => model.capabilities.controls),
        isEmpty,
        reason: adapter.id,
      );
    }
  });

  test('the OpenAI subscription endpoint states a narrower surface', () {
    final openai = openAIFamilyAdapters(
      clock: clock,
      openAIOAuth: const _UnusedGateway(),
    ).first;

    final platform = openai.endpoint(AgentProviderAuthKind.apiKey);
    expect(platform.baseUrl, 'https://api.openai.com/v1');
    expect(platform.accepts(ProviderEndpointExtension.modelDiscovery), isTrue);

    // The subscription backend serves only the Responses API, answers 400 for
    // `/models`, and rejects the fields only the platform API documents.
    final subscription = openai.endpoint(AgentProviderAuthKind.oauth);
    expect(subscription.baseUrl, 'https://chatgpt.com/backend-api/codex');
    expect(
      subscription.extensions,
      isNot(
        contains(
          anyOf(
            ProviderEndpointExtension.modelDiscovery,
            ProviderEndpointExtension.requestAttribution,
            ProviderEndpointExtension.expeditedProcessing,
          ),
        ),
      ),
    );
    expect(
      subscription.accepts(ProviderEndpointExtension.strictToolSchemas),
      isTrue,
    );
    // The narrower endpoint is a strict subset, never a different surface.
    expect(subscription.extensions, everyElement(isIn(platform.extensions)));
  });

  test('a compatible vendor states only the baseline it documents', () {
    for (final adapter in openAIFamilyAdapters(
      clock: clock,
      openAIOAuth: const _UnusedGateway(),
    ).where((plugin) => plugin.id != openAIDefinition.id)) {
      // Every vendor sharing this wire inherited the platform answer before
      // extensions became data, which is how `safety_identifier` and
      // `service_tier` reached endpoints that reject them.
      expect(
        adapter.endpoint(AgentProviderAuthKind.apiKey).extensions,
        isNot(
          contains(
            anyOf(
              ProviderEndpointExtension.requestAttribution,
              ProviderEndpointExtension.expeditedProcessing,
              ProviderEndpointExtension.strictToolSchemas,
              ProviderEndpointExtension.reasoningSummaries,
              ProviderEndpointExtension.reasoningContinuation,
            ),
          ),
        ),
        reason: adapter.id,
      );
    }
  });

  // A custom connection is offered exactly the controls its wire advertises,
  // against an endpoint that has stated nothing beyond the baseline. A control
  // the wire never encodes there is a chip that silently does nothing.
  for (final entry
      in <
        ({
          String label,
          String fixture,
          ProviderWireProtocol Function(Dio Function(ProviderEndpoint)) build,
        })
      >[
        (
          label: openAIChatCompletionsWireId,
          fixture: '''
data: {"choices":[{"delta":{},"finish_reason":"stop"}]}

data: [DONE]

''',
          build: (factory) => OpenAIChatCompletionsWire(dioFactory: factory),
        ),
        (
          label: openAIResponsesWireId,
          fixture: '''
data: {"type":"response.completed","response":{"output":[],"usage":{}}}

data: [DONE]

''',
          build: (factory) => OpenAIResponsesWire(dioFactory: factory),
        ),
        (
          label: anthropicMessagesWireId,
          fixture: '''
event: message_start
data: {"type":"message_start","message":{"usage":{}}}

event: message_stop
data: {"type":"message_stop"}

''',
          build: (factory) => AnthropicMessagesWire(dioFactory: factory),
        ),
        (
          label: geminiInteractionsWireId,
          fixture: '''
event: interaction.completed
data: {"event_type":"interaction.completed","interaction":{"usage":{}}}

event: done
data: [DONE]

''',
          build: (factory) => GeminiInteractionsWire(dioFactory: factory),
        ),
      ]) {
    test('${entry.label} sends every control it advertises', () async {
      final wire = entry.build((_) => Dio());
      Future<String> body(Map<String, AgentModelControlValue> controls) async {
        final adapter = _Adapter(entry.fixture);
        await entry
            .build((_) => Dio()..httpClientAdapter = adapter)
            .createProvider(
              ModelGatewayRequest(
                connectionId: 'custom',
                endpoint: const ProviderEndpoint(
                  baseUrl: 'https://compatible.test/v1',
                ),
                credential: const ApiKeyCredential('key'),
                capabilities: AgentModelCapabilities(
                  controls: wire.controlDescriptors,
                ),
              ),
            )
            .stream(
              ModelRequest(
                model: 'custom-model',
                modelControls: controls,
                blocks: const <ModelRoleBlock>[
                  ModelRoleBlock(role: ModelRole.system, content: 'test'),
                ],
                history: const <ConversationItem>[],
                tools: const <ModelToolDefinition>[],
              ),
              CancellationToken(),
            )
            .toList();
        return jsonEncode(adapter.options!.data);
      }

      final baseline = await body(const <String, AgentModelControlValue>{});
      for (final control in wire.controlDescriptors) {
        // Every offered value, not just the first: a choice the wire drops is
        // as inert as a control it never reads.
        final values = switch (control.kind) {
          // A wire template carries no values of its own: the endpoint's owner
          // supplies those. Any value stands in to prove the wire encodes it.
          AgentModelControlKind.choice => <AgentModelControlValue>[
            for (final choice in <String>[
              if (control.choices.isEmpty)
                'user-defined'
              else
                for (final choice in control.choices) choice.id,
            ])
              AgentModelControlStringValue(value: choice),
          ],
          AgentModelControlKind.toggle => <AgentModelControlValue>[
            const AgentModelControlBoolValue(value: true),
          ],
          AgentModelControlKind.integer => <AgentModelControlValue>[
            AgentModelControlIntValue(value: control.minimum ?? 1),
          ],
        };
        for (final value in values) {
          expect(
            await body(<String, AgentModelControlValue>{control.id: value}),
            isNot(baseline),
            reason:
                '${entry.label} advertises ${control.id} = $value '
                'but never sends it',
          );
        }
      }
    });
  }

  test('provider catalogs describe each supported Lua tool surface', () {
    final openai = openAIBundledModels.first.capabilities;
    expect(openai.functionTools, AgentCapabilitySupport.supported);
    expect(openai.deferredTools, AgentCapabilitySupport.supported);

    expect(
      deepseekBundledModels.first.capabilities.functionTools,
      AgentCapabilitySupport.supported,
    );
    expect(
      deepseekBundledModels.first.capabilities.deferredTools,
      AgentCapabilitySupport.unsupported,
    );
    expect(
      anthropicBundledModels.first.capabilities.functionTools,
      AgentCapabilitySupport.supported,
    );
    expect(
      googleBundledModels.first.capabilities.functionTools,
      AgentCapabilitySupport.supported,
    );
  });

  test(
    'the subscription adapter carries identity headers, never the secret',
    () async {
      final adapter = _Adapter(
        'data: {"type":"response.completed","response":{"output":[]}}\n\n'
        'data: [DONE]\n\n',
      );
      final openai = openAIFamilyAdapters(
        clock: clock,
        openAIOAuth: const _UnusedGateway(),
        dioFactory: (_) => Dio()..httpClientAdapter = adapter,
      ).first;
      final credential = OAuthCredential(
        accessToken: 'access-secret',
        refreshToken: 'refresh-secret',
        expiresAt: DateTime.utc(2026, 8, 3),
        accountId: 'account-id',
      );
      final provider = openai.createProvider(
        ModelGatewayRequest(
          connectionId: 'openai',
          endpoint: openai.endpoint(AgentProviderAuthKind.oauth),
          credential: credential,
          capabilities: openAIBundledModels.first.capabilities,
        ),
      );

      await provider
          .stream(
            const ModelRequest(
              model: 'gpt-5.6-sol',
              modelControls: <String, AgentModelControlValue>{
                AgentModelControlIds.reasoningEffort:
                    AgentModelControlStringValue(value: 'medium'),
                AgentModelControlIds.fastMode: AgentModelControlBoolValue(
                  value: true,
                ),
              },
              blocks: <ModelRoleBlock>[
                ModelRoleBlock(role: ModelRole.system, content: 'test'),
              ],
              history: <ConversationItem>[],
              tools: <ModelToolDefinition>[],
            ),
            CancellationToken(),
          )
          .toList();

      expect(
        adapter.options!.uri.toString(),
        'https://chatgpt.com/backend-api/codex/responses',
      );
      expect(adapter.options!.headers['Authorization'], 'Bearer access-secret');
      expect(adapter.options!.headers['ChatGPT-Account-ID'], 'account-id');
      expect(adapter.options!.headers['originator'], 'tinyrack_tinest');
      expect(
        jsonEncode(adapter.options!.data),
        isNot(contains('refresh-secret')),
      );
      // The Codex backend rejects the whole turn when it receives a field
      // only the platform Responses API defines, even one the model supports
      // there.
      final body = Map<String, dynamic>.from(adapter.options!.data as Map);
      expect(body, isNot(contains('service_tier')));
      expect(body, isNot(contains('safety_identifier')));
    },
  );

  test('a compatible vendor receives no platform-only request field', () async {
    // A custom or compatible connection is offered every control the wire
    // can encode, so the model advertising fast mode is the normal case.
    final chatWire = openAIWireProtocols().firstWhere(
      (wire) => wire.id == openAIChatCompletionsWireId,
    );
    final capabilities = AgentModelCapabilities(
      streaming: AgentCapabilitySupport.supported,
      controls: chatWire.controlDescriptors,
    );
    final adapter = _Adapter(
      'data: {"choices":[{"delta":{},"finish_reason":"stop"}]}\n\n'
      'data: [DONE]\n\n',
    );
    final compatible = openAIFamilyAdapters(
      clock: clock,
      openAIOAuth: const _UnusedGateway(),
      dioFactory: (_) => Dio()..httpClientAdapter = adapter,
    ).firstWhere((plugin) => plugin.id == deepseekDefinition.id);

    await compatible
        .createProvider(
          ModelGatewayRequest(
            connectionId: compatible.id,
            endpoint: compatible.endpoint(AgentProviderAuthKind.apiKey),
            credential: const ApiKeyCredential('key'),
            capabilities: capabilities,
          ),
        )
        .stream(
          const ModelRequest(
            model: 'deepseek-v4-pro',
            modelControls: <String, AgentModelControlValue>{
              AgentModelControlIds.fastMode: AgentModelControlBoolValue(
                value: true,
              ),
            },
            blocks: <ModelRoleBlock>[
              ModelRoleBlock(role: ModelRole.system, content: 'test'),
            ],
            history: <ConversationItem>[],
            tools: <ModelToolDefinition>[],
          ),
          CancellationToken(),
        )
        .toList();

    // `service_tier` is documented by one vendor's platform API. Sending it
    // to a narrower compatible surface fails the whole request.
    final body = Map<String, dynamic>.from(adapter.options!.data as Map);
    expect(body, isNot(contains('service_tier')));
  });

  test('a compatible Responses endpoint receives no platform field', () async {
    final adapter = _Adapter(
      'data: {"type":"response.completed","response":{"output":[]}}\n\n'
      'data: [DONE]\n\n',
    );
    final wire = OpenAIResponsesWire(
      dioFactory: (_) => Dio()..httpClientAdapter = adapter,
    );

    await wire
        .createProvider(
          const ModelGatewayRequest(
            connectionId: 'custom',
            endpoint: ProviderEndpoint(baseUrl: 'https://compatible.test/v1'),
            credential: ApiKeyCredential('key'),
          ),
        )
        .stream(
          const ModelRequest(
            model: 'custom-model',
            blocks: <ModelRoleBlock>[
              ModelRoleBlock(role: ModelRole.system, content: 'test'),
            ],
            history: <ConversationItem>[],
            tools: <ModelToolDefinition>[],
          ),
          CancellationToken(),
        )
        .toList();

    // A user-entered base URL cannot be assumed to define any of the fields
    // one vendor's platform documents.
    final body = Map<String, dynamic>.from(adapter.options!.data as Map);
    expect(body, isNot(contains('safety_identifier')));
    expect(body, isNot(contains('include')));
  });

  test('an API key request carries no subscription identity headers', () {
    final openai = openAIFamilyAdapters(
      clock: clock,
      openAIOAuth: const _UnusedGateway(),
    ).first;

    final provider = openai.createProvider(
      const ModelGatewayRequest(
        connectionId: 'openai',
        endpoint: ProviderEndpoint(baseUrl: 'https://api.openai.com/v1'),
        credential: ApiKeyCredential('sk-test'),
      ),
    );

    expect(provider, isA<OpenAIResponsesProvider>());
  });

  test('discovery classifies credentials and parses model IDs', () async {
    final success = _Adapter(
      jsonEncode(<String, dynamic>{
        'data': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'model-b'},
          <String, dynamic>{'id': ''},
          <String, dynamic>{'id': 'model-a'},
        ],
      }),
      contentType: Headers.jsonContentType,
    );
    final wire = OpenAIChatCompletionsWire(
      dioFactory: (_) => Dio()..httpClientAdapter = success,
    );

    expect(
      await wire.discoverModels(
        const ProviderEndpoint(baseUrl: 'https://api.deepseek.com'),
        const ApiKeyCredential('secret'),
      ),
      <String>['model-b', 'model-a'],
    );
    expect(success.options!.headers['Authorization'], 'Bearer secret');
  });

  test('discovery classifies HTTP failures and malformed catalogs', () async {
    const failure = ProviderDiscoveryFailure(
      ProviderDiscoveryFailureKind.unavailable,
      'offline',
    );
    expect(
      failure.toString(),
      'ProviderDiscoveryFailure(ProviderDiscoveryFailureKind.unavailable): '
      'offline',
    );
    const endpoint = ProviderEndpoint(baseUrl: 'https://models.example/v1');

    for (final status in <int>[400, 401, 500]) {
      final adapter = _Adapter(
        '{}',
        contentType: Headers.jsonContentType,
        statusCode: status,
      );
      final wire = OpenAIChatCompletionsWire(
        dioFactory: (_) => Dio()..httpClientAdapter = adapter,
      );
      await expectLater(
        wire.discoverModels(
          endpoint,
          OAuthCredential(
            accessToken: 'oauth-access',
            refreshToken: 'refresh',
            expiresAt: DateTime.utc(2026, 8, 3),
          ),
        ),
        throwsA(
          isA<ProviderDiscoveryFailure>().having(
            (error) => error.kind,
            'kind',
            status == 401
                ? ProviderDiscoveryFailureKind.invalidCredential
                : ProviderDiscoveryFailureKind.unavailable,
          ),
        ),
      );
      expect(adapter.options!.headers['Authorization'], 'Bearer oauth-access');
    }

    final malformed = _Adapter(
      '{"data":"not-a-list"}',
      contentType: Headers.jsonContentType,
    );
    await expectLater(
      OpenAIChatCompletionsWire(
        dioFactory: (_) => Dio()..httpClientAdapter = malformed,
      ).discoverModels(endpoint, null),
      throwsA(isA<FormatException>()),
    );
  });

  test('the Chat Completions wire serves unauthenticated local servers', () {
    final dio = Dio();
    const endpoint = ProviderEndpoint(baseUrl: 'http://127.0.0.1:11434/v1');
    final provider = OpenAIChatCompletionsWire(dioFactory: (_) => dio)
        .createProvider(
          const ModelGatewayRequest(
            connectionId: 'local',
            endpoint: endpoint,
            credential: null,
          ),
        );

    expect(provider, isA<OpenAIChatCompletionsProvider>());
    expect(dio.options.baseUrl, endpoint.baseUrl);
  });
}

final class _FixedClock implements Clock {
  const new(this.value);

  final DateTime value;

  @override
  DateTime nowUtc() => value;
}

final class _UnusedGateway implements ProviderOAuthGateway {
  const new();

  @override
  Future<ProviderOAuthSession> start(AgentProviderAuthFlow flow) =>
      throw UnimplementedError('No test starts a flow.');

  @override
  Future<OAuthCredential> refresh(OAuthCredential credential) =>
      throw UnimplementedError('No test refreshes a credential.');
}

final class _Adapter implements HttpClientAdapter {
  new(
    this.body, {
    this.contentType = 'text/event-stream',
    this.statusCode = 200,
  });

  final String body;
  final String contentType;
  final int statusCode;
  RequestOptions? options;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
