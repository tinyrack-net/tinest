import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:agent/agent.dart';
import 'package:daemon/src/features/providers/infrastructure/openai/openai.dart';
import 'package:daemon/src/features/providers/infrastructure/provider_catalog.dart';
import 'package:dio/dio.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 2);
  final registry = ProviderRegistry(
    adapters: openAIFamilyAdapters(clock: _Clock(now)),
    wireProtocols: openAIWireProtocols(),
  );

  test('the catalog owns the effort levels, the vendor owns the ladder', () {
    final catalog = BuiltInProviderCatalog(
      clock: _Clock(now),
      registry: registry,
      metadataSource: _MetadataSource(),
    );

    // Before a refresh the vendor's own ladder is all there is.
    final offline = catalog
        .modelsFor('deepseek')
        .singleWhere((model) => model.id == 'deepseek-reasoner');
    expect(
      offline.capabilities.controls
          .singleWhere(
            (control) => control.id == AgentModelControlIds.reasoningEffort,
          )
          .choices
          .map((choice) => choice.id),
      isNot(contains('ultra')),
    );
  });

  test('a refreshed effort ladder replaces the vendor guess', () async {
    final catalog = BuiltInProviderCatalog(
      clock: _Clock(now),
      registry: registry,
      metadataSource: _MetadataSource(),
    );
    await catalog.refresh();

    // The catalog describes one named model; the vendor's list can only
    // approximate a whole family, so the named description wins.
    final refreshed = catalog
        .modelsFor('deepseek')
        .singleWhere((model) => model.id == 'deepseek-chat');
    expect(
      refreshed.capabilities.controls
          .singleWhere(
            (control) => control.id == AgentModelControlIds.reasoningEffort,
          )
          .choices
          .map((choice) => choice.id),
      containsAll(<String>['low', 'ultra']),
    );

    // A model the vendor does not bundle still reasons, and the catalog did
    // not say at which levels, so the vendor's ladder stands in.
    final discovered = catalog
        .modelsFor('deepseek')
        .singleWhere((model) => model.id == 'deepseek-new');
    expect(
      discovered.capabilities.controls.map((control) => control.id),
      contains(AgentModelControlIds.reasoningEffort),
    );
  });

  test(
    'explicit refresh merges model metadata without runtime fields',
    () async {
      final source = _MetadataSource();
      final catalog = BuiltInProviderCatalog(
        clock: _Clock(now),
        registry: registry,
        metadataSource: source,
      );
      final trustedEndpoint = registry
          .require('deepseek')
          .endpoint(AgentProviderAuthKind.apiKey)
          .baseUrl;

      final refreshed = await catalog.refresh();
      final cachedRefresh = await catalog.refresh(force: false);
      final model = catalog
          .modelsFor('deepseek')
          .singleWhere((item) => item.id == 'deepseek-new');
      final enrichedBundledModel = catalog
          .modelsFor('deepseek')
          .singleWhere((item) => item.id == 'deepseek-chat');

      expect(refreshed.source, ProviderCatalogSource.refreshed);
      expect(cachedRefresh, refreshed);
      expect(source.requested, contains('deepseek'));
      expect(model.label, 'DeepSeek New');
      expect(model.pricing!.input, 0.25);
      expect(model.limits!.context, 128000);
      expect(
        enrichedBundledModel.capabilities.imageInput,
        CapabilitySupport.supported,
      );
      expect(
        enrichedBundledModel.capabilities.fileInput,
        CapabilitySupport.supported,
      );
      expect(catalog.isRefreshedModel('deepseek', model.id), isTrue);
      expect(
        registry
            .require('deepseek')
            .endpoint(AgentProviderAuthKind.apiKey)
            .baseUrl,
        trustedEndpoint,
      );
      expect(registry.find('attacker'), isNull);
    },
  );

  // Models.dev namespaces MiniMax under aggregator ids the vendor's own API
  // rejects, so a refresh must not be able to add a model that cannot run.
  test('a bundled-only vendor is never asked for public metadata', () async {
    final source = _MetadataSource();
    final catalog = BuiltInProviderCatalog(
      clock: _Clock(now),
      registry: registry,
      metadataSource: source,
    );

    await catalog.refresh();

    expect(source.requested, contains('deepseek'));
    expect(source.requested, isNot(contains('minimax')));
    expect(source.requested, isNot(contains('minimax-cn')));
    expect(
      catalog.modelsFor('minimax').map((model) => model.id),
      everyElement(startsWith('MiniMax-')),
    );
  });

  test('refreshed metadata fills unknown bundled capabilities', () async {
    final catalog = BuiltInProviderCatalog(
      clock: _Clock(now),
      registry: ProviderRegistry(
        adapters: const <ProviderAdapter>[_UnknownCapabilityAdapter()],
        wireProtocols: openAIWireProtocols(),
      ),
      metadataSource: _MetadataSource(),
    );

    await catalog.refresh();
    final capabilities = catalog
        .modelsFor('deepseek')
        .singleWhere((model) => model.id == 'deepseek-chat')
        .capabilities;

    expect(capabilities.streaming, CapabilitySupport.supported);
    expect(capabilities.toolCalling, CapabilitySupport.supported);
    expect(capabilities.imageInput, CapabilitySupport.supported);
    expect(capabilities.fileInput, CapabilitySupport.supported);
  });

  test('Models.dev parser accepts only requested model metadata', () async {
    final adapter = _JsonAdapter(<String, dynamic>{
      'deepseek': <String, dynamic>{
        'api': 'https://attacker.invalid',
        'env': <String>['STOLEN_KEY'],
        'models': <String, dynamic>{
          'deepseek-next': <String, dynamic>{
            'id': 'deepseek-next',
            'name': 'DeepSeek Next',
            'reasoning': true,
            'reasoning_options': <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'effort',
                'values': <String>['high', 'max'],
              },
            ],
            'tool_call': true,
            'cost': <String, dynamic>{
              'input': 0.4,
              'output': 1.2,
              'cache_read': 0.1,
            },
            'limit': <String, dynamic>{'context': 200000, 'output': 32000},
          },
        },
      },
      'attacker': <String, dynamic>{
        'models': <String, dynamic>{
          'bad': <String, dynamic>{'id': 'bad'},
        },
      },
    });
    final source = ModelsDevCatalogMetadataSource(
      dio: Dio()..httpClientAdapter = adapter,
    );

    final result = await source.fetch(<String>{'deepseek'});
    final model = result['deepseek']!.single;

    expect(result, isNot(contains('attacker')));
    expect(model.id, 'deepseek-next');
    expect(model.capabilities.toolCalling, CapabilitySupport.supported);
    expect(
      model.capabilities.controls.single.choices.map((item) => item.id),
      <String>['high', 'max'],
    );
    expect(model.pricing!.cacheRead, 0.1);
    expect(model.limits!.output, 32000);
    expect(adapter.path, '/api.json');
  });

  test(
    'Models.dev reuses its parsed catalog after a not-modified reply',
    () async {
      final adapter = _JsonAdapter(<String, dynamic>{
        'deepseek': <String, dynamic>{
          'models': <String, dynamic>{
            'deepseek-next': <String, dynamic>{
              'id': 'deepseek-next',
              'name': 'DeepSeek Next',
            },
          },
        },
      }, returnNotModifiedAfterFirst: true);
      final source = ModelsDevCatalogMetadataSource(
        dio: Dio()..httpClientAdapter = adapter,
      );

      final first = await source.fetch(<String>{'deepseek'});
      final cached = await source.fetch(<String>{'deepseek'});

      expect(cached, same(first));
      expect(adapter.requestCount, 2);
    },
  );

  test('refresh failure retains the bundled snapshot', () async {
    final catalog = BuiltInProviderCatalog(
      clock: _Clock(now),
      registry: registry,
      metadataSource: const _FailingMetadataSource(),
    );

    final refreshed = await catalog.refresh();

    expect(refreshed.refreshError, isNotNull);
    expect(refreshed.freshness, ProviderCatalogFreshness.bundled);
    expect(catalog.modelsFor('openai'), isNotEmpty);
  });

  test('closing a catalog cancels an in-flight metadata refresh', () async {
    final source = _BlockingMetadataSource();
    final catalog = BuiltInProviderCatalog(
      clock: _Clock(now),
      registry: registry,
      metadataSource: source,
    );

    final refresh = catalog.refresh();
    await source.started.future;
    await catalog.close();
    await refresh;

    expect(source.closed, isTrue);
  });

  test('pinned snapshot enriches models without runtime controls', () {
    final catalog = BuiltInProviderCatalog(
      clock: _Clock(now),
      registry: registry,
      metadataSource: const _FailingMetadataSource(),
    );

    final advisoryModel = catalog
        .modelsFor('openai')
        .firstWhere((item) => item.id == 'gpt-4');
    final runtimeModel = catalog
        .modelsFor('openai')
        .firstWhere((item) => item.id == 'gpt-5.6-sol');

    expect(advisoryModel.capabilities.controls, isEmpty);
    expect(advisoryModel.limits, isNotNull);
    expect(runtimeModel.capabilities.controls, isNotEmpty);
  });
}

final class _Clock implements Clock {
  const new(this.now);

  final DateTime now;

  @override
  DateTime nowUtc() => now;
}

final class _MetadataSource implements ProviderCatalogMetadataSource {
  Set<String> requested = <String>{};

  @override
  Future<Map<String, List<ProviderCatalogMetadata>>> fetch(
    Set<String> providerIds,
  ) async {
    requested = providerIds;
    return const <String, List<ProviderCatalogMetadata>>{
      'deepseek': <ProviderCatalogMetadata>[
        ProviderCatalogMetadata(
          id: 'deepseek-chat',
          label: 'DeepSeek Chat (refreshed)',
          capabilities: ModelCapabilitiesDto(
            streaming: CapabilitySupport.supported,
            toolCalling: CapabilitySupport.supported,
            imageInput: CapabilitySupport.supported,
            fileInput: CapabilitySupport.supported,
            controls: <ModelControlDescriptorDto>[
              ModelControlDescriptorDto(
                id: AgentModelControlIds.reasoningEffort,
                label: 'Reasoning effort',
                kind: ModelControlKind.choice,
                presentation: ModelControlPresentation.menuChip,
                choices: <ModelControlChoiceDto>[
                  ModelControlChoiceDto(id: 'low', label: 'Low'),
                  ModelControlChoiceDto(id: 'ultra', label: 'Ultra'),
                ],
              ),
            ],
            source: CapabilitySource.refreshed,
          ),
          reasoning: true,
        ),
        ProviderCatalogMetadata(
          id: 'deepseek-new',
          label: 'DeepSeek New',
          capabilities: ModelCapabilitiesDto(
            streaming: CapabilitySupport.supported,
            toolCalling: CapabilitySupport.supported,
            source: CapabilitySource.refreshed,
          ),
          pricing: ModelPricingDto(input: 0.25, output: 1),
          limits: ModelLimitsDto(context: 128000, output: 16000),
          reasoning: true,
        ),
      ],
      'attacker': <ProviderCatalogMetadata>[
        ProviderCatalogMetadata(
          id: 'bad',
          label: 'Bad',
          capabilities: ModelCapabilitiesDto(),
        ),
      ],
    };
  }

  @override
  Future<void> close() async {}
}

final class _UnknownCapabilityAdapter extends ProviderAdapter {
  const new();

  @override
  String get id => deepseekDefinition.id;

  @override
  AgentProviderDefinition get definition => deepseekDefinition;

  @override
  List<ProviderCatalogModel> get models => const <ProviderCatalogModel>[
    ProviderCatalogModel(
      id: 'deepseek-chat',
      label: 'DeepSeek Chat',
      capabilities: AgentModelCapabilities(),
    ),
  ];

  @override
  ProviderEndpoint endpoint(AgentProviderAuthKind authKind) =>
      const ProviderEndpoint(baseUrl: 'https://api.deepseek.com');

  @override
  ModelGateway createProvider(ModelGatewayRequest request) =>
      throw UnsupportedError('Catalog-only test plugin.');

  @override
  Future<List<String>> discoverModels(
    ProviderEndpoint endpoint,
    ProviderCredential? credential,
  ) async => const <String>[];
}

final class _BlockingMetadataSource implements ProviderCatalogMetadataSource {
  final Completer<void> started = Completer<void>();
  final Completer<Map<String, List<ProviderCatalogMetadata>>> _result =
      Completer<Map<String, List<ProviderCatalogMetadata>>>();
  bool closed = false;

  @override
  Future<Map<String, List<ProviderCatalogMetadata>>> fetch(
    Set<String> providerIds,
  ) {
    started.complete();
    return _result.future;
  }

  @override
  Future<void> close() async {
    closed = true;
    _result.completeError(StateError('catalog closed'));
  }
}

final class _FailingMetadataSource implements ProviderCatalogMetadataSource {
  const new();

  @override
  Future<Map<String, List<ProviderCatalogMetadata>>> fetch(
    Set<String> providerIds,
  ) => Future<Map<String, List<ProviderCatalogMetadata>>>.error(
    StateError('offline'),
  );

  @override
  Future<void> close() async {}
}

final class _JsonAdapter implements HttpClientAdapter {
  new(this.data, {this.returnNotModifiedAfterFirst = false});

  final Map<String, dynamic> data;
  final bool returnNotModifiedAfterFirst;
  String? path;
  int requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    path = options.path;
    requestCount += 1;
    if (returnNotModifiedAfterFirst && requestCount > 1) {
      return ResponseBody.fromString('', 304);
    }
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: <String, List<String>>{
        'etag': <String>['catalog-v1'],
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
