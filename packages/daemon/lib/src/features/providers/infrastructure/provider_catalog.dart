import 'package:agent/agent.dart';
import 'package:daemon/src/features/providers/infrastructure/bundled_models_dev.dart';
import 'package:daemon/src/shared/ports/agent_protocol_mapping.dart';
import 'package:dio/dio.dart';
import 'package:protocol/protocol.dart';

/// Safe model metadata returned by an external catalog.
final class ProviderCatalogMetadata {
  /// Creates safe model metadata without provider runtime configuration.
  const new({
    required this.id,
    required this.label,
    required this.capabilities,
    this.pricing,
    this.limits,
    this.reasoning = false,
  });

  /// Provider-local model identifier.
  final String id;

  /// Human-readable model label.
  final String label;

  /// Streaming, tool, and reasoning capability metadata.
  final ModelCapabilitiesDto capabilities;

  /// Optional USD prices per million tokens.
  final ModelPricingDto? pricing;

  /// Optional token limits.
  final ModelLimitsDto? limits;

  /// Whether the public catalog reports this model as reasoning.
  ///
  /// The catalog knows which models reason; it does not always describe the
  /// levels, so the vendor supplies those.
  final bool reasoning;
}

/// Fetches model-only metadata for an explicit catalog refresh.
abstract interface class ProviderCatalogMetadataSource {
  /// Fetches metadata only for trusted built-in provider IDs.
  Future<Map<String, List<ProviderCatalogMetadata>>> fetch(
    Set<String> providerIds,
  );

  /// Cancels owned requests and releases transport resources.
  Future<void> close();
}

/// Models.dev adapter. Provider endpoints and auth fields are never parsed.
final class ModelsDevCatalogMetadataSource
    implements ProviderCatalogMetadataSource {
  /// Creates the production Models.dev adapter.
  new({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://models.dev',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );

  final Dio _dio;
  String? _etag;
  Map<String, List<ProviderCatalogMetadata>>? _lastFetched;

  @override
  Future<void> close() async => _dio.close(force: true);

  @override
  Future<Map<String, List<ProviderCatalogMetadata>>> fetch(
    Set<String> providerIds,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api.json',
      options: Options(
        headers: <String, String>{'If-None-Match': ?_etag},
        validateStatus: (status) =>
            status != null &&
            ((status >= 200 && status < 300) || status == 304),
      ),
    );
    if (response.statusCode == 304) {
      final cached = _lastFetched;
      if (cached == null) {
        throw const FormatException('Models.dev returned 304 without a cache.');
      }
      return cached;
    }
    final data = response.data;
    if (data == null) {
      throw const FormatException('Models.dev returned an empty catalog.');
    }
    final parsed = <String, List<ProviderCatalogMetadata>>{
      for (final providerId in providerIds)
        if (data[providerId] case final Map<String, dynamic> provider)
          providerId: _parseModels(provider, providerId),
    };
    _etag = response.headers.value('etag');
    _lastFetched = parsed;
    return parsed;
  }

  static List<ProviderCatalogMetadata> _parseModels(
    Map<String, dynamic> provider,
    String providerId,
  ) {
    final models = provider['models'];
    if (models is! Map<String, dynamic>) {
      return const <ProviderCatalogMetadata>[];
    }
    final result = <ProviderCatalogMetadata>[];
    for (final entry in models.entries) {
      if (entry.value is! Map<String, dynamic>) continue;
      final model = entry.value! as Map<String, dynamic>;
      final id = model['id'];
      if (id is! String || id.isEmpty) continue;
      final reasoning = model['reasoning'] == true;
      final toolCalling = model['tool_call'] == true;
      result.add(
        ProviderCatalogMetadata(
          id: id,
          label: model['name'] is String ? model['name']! as String : id,
          capabilities: ModelCapabilitiesDto(
            streaming: CapabilitySupport.supported,
            toolCalling: toolCalling
                ? CapabilitySupport.supported
                : CapabilitySupport.unsupported,
            functionTools: toolCalling
                ? CapabilitySupport.supported
                : CapabilitySupport.unsupported,
            controls: reasoning
                ? <ModelControlDescriptorDto>[
                    ModelControlDescriptorDto(
                      id: AgentModelControlIds.reasoningEffort,
                      label: 'Reasoning effort',
                      kind: ModelControlKind.choice,
                      presentation: ModelControlPresentation.menuChip,
                      choices: <ModelControlChoiceDto>[
                        for (final effort in _reasoningEfforts(model))
                          ModelControlChoiceDto(
                            id: effort,
                            label: _controlLabel(effort),
                          ),
                      ],
                    ),
                  ]
                : const <ModelControlDescriptorDto>[],
            source: CapabilitySource.refreshed,
          ),
          pricing: _pricing(model['cost']),
          limits: _limits(model['limit']),
          reasoning: reasoning,
        ),
      );
    }
    result.sort((left, right) => left.id.compareTo(right.id));
    return result;
  }

  static List<String> _reasoningEfforts(Map<String, dynamic> model) {
    final options = model['reasoning_options'];
    if (options is! List<dynamic>) return const <String>[];
    final efforts = <String>[];
    for (final option in options) {
      if (option is! Map<String, dynamic> || option['type'] != 'effort') {
        continue;
      }
      final values = option['values'];
      if (values is! List<dynamic>) continue;
      efforts.addAll(values.whereType<String>());
    }
    return efforts.toSet().toList(growable: false);
  }

  static String _controlLabel(String value) => value
      .split('_')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word.substring(0, 1).toUpperCase()}${word.substring(1)}',
      )
      .join(' ');

  static ModelPricingDto? _pricing(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    return ModelPricingDto(
      input: _double(value['input']),
      output: _double(value['output']),
      cacheRead: _double(value['cache_read']),
      cacheWrite: _double(value['cache_write']),
    );
  }

  static ModelLimitsDto? _limits(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    return ModelLimitsDto(
      context: _int(value['context']),
      input: _int(value['input']),
      output: _int(value['output']),
    );
  }

  static double? _double(Object? value) =>
      value is num ? value.toDouble() : null;

  static int? _int(Object? value) => value is num ? value.toInt() : null;
}

/// Read-only catalog of provider definitions trusted by the daemon.
final class BuiltInProviderCatalog {
  /// Creates a catalog over the registered vendors and a refresh port.
  factory({
    required Clock clock,
    required ProviderRegistry registry,
    ProviderCatalogMetadataSource? metadataSource,
  }) => BuiltInProviderCatalog._(
    clock,
    registry,
    metadataSource ?? ModelsDevCatalogMetadataSource(),
  );

  new _(this._clock, this._registry, this._metadataSource)
    : _bundledAdvisory = bundledModelsDevMetadata();

  final Clock _clock;
  final ProviderRegistry _registry;
  final ProviderCatalogMetadataSource _metadataSource;
  final Map<String, List<ProviderCatalogMetadata>> _bundledAdvisory;
  Map<String, List<ProviderCatalogMetadata>>? _refreshedModels;
  DateTime? _refreshedAt;
  DateTime? _lastAttemptAt;
  String? _refreshError;

  /// Cancels refresh work owned by the metadata source.
  Future<void> close() => _metadataSource.close();

  /// Returns public provider metadata without endpoint or transport details.
  ProviderCatalogDto catalog() => ProviderCatalogDto(
    definitions: <ProviderDefinitionDto>[
      for (final plugin in _registry.adapters)
        protocolProviderDefinition(plugin.definition),
    ],
    wireFormats: <ProviderWireFormatDto>[
      for (final wire in _registry.wireProtocols)
        ProviderWireFormatDto(
          id: wire.id,
          label: wire.label,
          controls: wire.controlDescriptors
              .map(protocolControlDescriptor)
              .toList(),
        ),
    ],
    source: _refreshedModels == null
        ? ProviderCatalogSource.bundled
        : ProviderCatalogSource.refreshed,
    updatedAt: _refreshedAt ?? _clock.nowUtc(),
    freshness: _freshness,
    lastSuccessAt: _refreshedAt,
    lastAttemptAt: _lastAttemptAt,
    refreshError: _refreshError,
  );

  ProviderCatalogFreshness get _freshness {
    if (_refreshedModels == null) return ProviderCatalogFreshness.bundled;
    if (_refreshError != null) return ProviderCatalogFreshness.cached;
    final refreshedAt = _refreshedAt;
    if (refreshedAt == null ||
        _clock.nowUtc().difference(refreshedAt) >= const Duration(hours: 24)) {
      return ProviderCatalogFreshness.stale;
    }
    return ProviderCatalogFreshness.fresh;
  }

  /// Explicitly refreshes model metadata while retaining trusted runtime data.
  Future<ProviderCatalogDto> refresh({bool force = true}) async {
    if (!force && _freshness == ProviderCatalogFreshness.fresh) {
      return catalog();
    }
    _lastAttemptAt = _clock.nowUtc();
    final providerIds = _registry.adapters
        .where((adapter) => adapter.usesRemoteCatalog)
        .map((adapter) => adapter.id)
        .toSet();
    final Map<String, List<ProviderCatalogMetadata>> fetched;
    try {
      fetched = await _metadataSource.fetch(providerIds);
    } on Object {
      _refreshError = 'Catalog refresh failed; using local metadata.';
      return catalog();
    }
    _refreshedModels = <String, List<ProviderCatalogMetadata>>{
      for (final entry in fetched.entries)
        if (_registry.find(entry.key) case final plugin?)
          // The public catalog reports what it measured; the vendor may know
          // more, such as inputs its API accepts for every model.
          entry.key: List<ProviderCatalogMetadata>.unmodifiable(
            <ProviderCatalogMetadata>[
              for (final model in entry.value)
                ProviderCatalogMetadata(
                  id: model.id,
                  label: model.label,
                  capabilities: protocolCapabilities(
                    plugin
                        .refineRemoteCapabilities(
                          agentCapabilities(model.capabilities),
                        )
                        .copyWith(
                          controls: <AgentModelControlDescriptor>[
                            for (final control in agentCapabilities(
                              model.capabilities,
                            ).controls)
                              if (plugin.models
                                  .expand(
                                    (known) => known.capabilities.controls,
                                  )
                                  .any((known) => known.id == control.id))
                                control,
                          ],
                        ),
                  ),
                  pricing: model.pricing,
                  limits: model.limits,
                  reasoning: model.reasoning,
                ),
            ],
          ),
    };
    _refreshedAt = _clock.nowUtc();
    _refreshError = null;
    return catalog();
  }

  /// Returns merged bundled and explicitly refreshed model metadata.
  /// Combines the controls a vendor declares with the ones the catalog knows.
  ///
  /// The public catalog reports the choices for one named model, which the
  /// vendor's own list can only approximate across a whole family, so a
  /// refreshed control replaces the declared one of the same id. Controls the
  /// catalog does not describe at all, such as expedited processing, are kept:
  /// the catalog being silent about them is not the catalog denying them.
  static List<ModelControlDescriptorDto> _mergedControls({
    required List<ModelControlDescriptorDto> bundled,
    required List<ModelControlDescriptorDto> refreshed,
  }) {
    final described = <String, ModelControlDescriptorDto>{
      for (final control in refreshed)
        if (control.choices.isNotEmpty) control.id: control,
    };
    final declared = bundled.map((control) => control.id).toSet();
    return <ModelControlDescriptorDto>[
      for (final control in bundled) described[control.id] ?? control,
      // The vendor describes a family; the catalog describes one model. Either
      // side being silent about a control is not that side denying it.
      for (final control in described.values)
        if (!declared.contains(control.id)) control,
    ];
  }

  /// Returns merged bundled and explicitly refreshed model metadata.
  List<ProviderCatalogMetadata> modelsFor(String definitionId) {
    final result = <String, ProviderCatalogMetadata>{
      for (final model
          in _bundledAdvisory[definitionId] ??
              const <ProviderCatalogMetadata>[])
        model.id: model,
      for (final model
          in _registry.find(definitionId)?.models ??
              const <ProviderCatalogModel>[])
        model.id: ProviderCatalogMetadata(
          id: model.id,
          label: model.label,
          capabilities: protocolCapabilities(model.capabilities),
          pricing: protocolPricing(model.pricing),
          limits: protocolLimits(model.limits),
        ),
    };
    for (final model
        in _refreshedModels?[definitionId] ??
            const <ProviderCatalogMetadata>[]) {
      final bundled = result[model.id];
      result[model.id] = bundled == null
          ? model
          : ProviderCatalogMetadata(
              id: model.id,
              label: model.label,
              capabilities: model.capabilities.copyWith(
                streaming:
                    bundled.capabilities.streaming == CapabilitySupport.unknown
                    ? model.capabilities.streaming
                    : bundled.capabilities.streaming,
                toolCalling:
                    bundled.capabilities.toolCalling ==
                        CapabilitySupport.unknown
                    ? model.capabilities.toolCalling
                    : bundled.capabilities.toolCalling,
                functionTools:
                    bundled.capabilities.functionTools ==
                        CapabilitySupport.unknown
                    ? model.capabilities.functionTools
                    : bundled.capabilities.functionTools,
                deferredTools:
                    bundled.capabilities.deferredTools ==
                        CapabilitySupport.unknown
                    ? model.capabilities.deferredTools
                    : bundled.capabilities.deferredTools,
                imageInput:
                    bundled.capabilities.imageInput == CapabilitySupport.unknown
                    ? model.capabilities.imageInput
                    : bundled.capabilities.imageInput,
                fileInput:
                    bundled.capabilities.fileInput == CapabilitySupport.unknown
                    ? model.capabilities.fileInput
                    : bundled.capabilities.fileInput,
                controls: _mergedControls(
                  bundled: bundled.capabilities.controls,
                  refreshed: model.capabilities.controls,
                ),
              ),
              pricing: model.pricing ?? bundled.pricing,
              limits: model.limits ?? bundled.limits,
              reasoning: model.reasoning || bundled.reasoning,
            );
    }
    // The catalog names models the vendor does not bundle. It reports which of
    // them reason but not always at which levels, so the vendor's own ladder
    // stands in; without this the model arrives with no effort control at all.
    final ladder = _registry
        .find(definitionId)
        ?.models
        .expand((model) => model.capabilities.controls)
        .where((control) => control.id == AgentModelControlIds.reasoningEffort)
        .firstOrNull;
    if (ladder == null) return result.values.toList(growable: false);
    return <ProviderCatalogMetadata>[
      for (final model in result.values)
        if (!model.reasoning ||
            model.capabilities.controls.any(
              (control) => control.id == AgentModelControlIds.reasoningEffort,
            ))
          model
        else
          ProviderCatalogMetadata(
            id: model.id,
            label: model.label,
            capabilities: model.capabilities.copyWith(
              controls: <ModelControlDescriptorDto>[
                ...model.capabilities.controls,
                protocolControlDescriptor(ladder),
              ],
            ),
            pricing: model.pricing,
            limits: model.limits,
            reasoning: model.reasoning,
          ),
    ];
  }

  /// Whether metadata for a model came from the explicit refresh.
  bool isRefreshedModel(String definitionId, String modelId) =>
      _refreshedModels?[definitionId]?.any((model) => model.id == modelId) ??
      false;
}
