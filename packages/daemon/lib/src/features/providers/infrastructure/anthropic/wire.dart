import 'package:agent/agent.dart';
import 'package:daemon/src/features/providers/infrastructure/anthropic/anthropic_provider.dart';
import 'package:dio/dio.dart';

/// Effort chosen for one turn.
///
/// It travels in its own request field, so it constrains nothing else. The
/// bundled catalog and a custom connection share these descriptors: a control
/// a custom model configures is compared against the wire's own template.
const AgentModelControlDescriptor anthropicEffortControl =
    AgentModelControlDescriptor(
      id: AgentModelControlIds.reasoningEffort,
      label: 'Reasoning effort',
      kind: AgentModelControlKind.choice,
      presentation: AgentModelControlPresentation.menuChip,
      choices: <AgentModelControlChoice>[
        AgentModelControlChoice(id: 'low', label: 'Low'),
        AgentModelControlChoice(id: 'medium', label: 'Medium'),
        AgentModelControlChoice(id: 'high', label: 'High'),
      ],
    );

/// How the model decides to think.
///
/// Adaptive is the only mode this transport encodes, and it writes the same
/// request field as the budget, so the two exclude each other.
const AgentModelControlDescriptor anthropicThinkingModeControl =
    AgentModelControlDescriptor(
      id: AgentModelControlIds.reasoningMode,
      label: 'Thinking mode',
      kind: AgentModelControlKind.choice,
      presentation: AgentModelControlPresentation.menuChip,
      choices: <AgentModelControlChoice>[
        AgentModelControlChoice(id: 'adaptive', label: 'Adaptive'),
      ],
      conflictsWith: <String>[AgentModelControlIds.thinkingBudget],
    );

/// Explicit thinking budget, exclusive with the thinking mode.
const AgentModelControlDescriptor anthropicThinkingBudgetControl =
    AgentModelControlDescriptor(
      id: AgentModelControlIds.thinkingBudget,
      label: 'Thinking budget',
      kind: AgentModelControlKind.integer,
      presentation: AgentModelControlPresentation.numberDialog,
      minimum: 1024,
      maximum: 32768,
      step: 1024,
      conflictsWith: <String>[AgentModelControlIds.reasoningMode],
    );

/// Priority processing for one turn.
const AgentModelControlDescriptor anthropicFastModeControl =
    AgentModelControlDescriptor(
      id: AgentModelControlIds.fastMode,
      label: 'Fast mode',
      kind: AgentModelControlKind.toggle,
      presentation: AgentModelControlPresentation.selectableChip,
    );

/// Custom-provider wire ID for Anthropic Messages.
const String anthropicMessagesWireId = 'anthropic-messages';

/// Anthropic Messages transport shared by the built-in and custom providers.
final class AnthropicMessagesWire implements ProviderWireProtocol {
  /// Creates the wire with an optional deterministic HTTP client factory.
  const new({this.dioFactory});

  /// Injectable client factory used by contract tests.
  final Dio Function(ProviderEndpoint endpoint)? dioFactory;

  @override
  String get id => anthropicMessagesWireId;

  @override
  String get label => 'Anthropic Messages';

  /// Fast mode is absent for the same reason it is absent from the other
  /// wires: `speed` reaches only an endpoint that has stated it accepts
  /// expedited processing, which a custom connection never has, so offering
  /// the toggle there would be offering a setting that does nothing.
  /// A custom connection addresses an endpoint nobody here has seen, so the
  /// template carries the shape this wire encodes and no values: which levels
  /// exist is known only to whoever runs that endpoint.
  @override
  List<AgentModelControlDescriptor> get controlDescriptors => const [
    AgentModelControlDescriptor(
      id: AgentModelControlIds.reasoningEffort,
      label: 'Reasoning effort',
      kind: AgentModelControlKind.choice,
      presentation: AgentModelControlPresentation.menuChip,
    ),
    AgentModelControlDescriptor(
      id: AgentModelControlIds.reasoningMode,
      label: 'Thinking mode',
      kind: AgentModelControlKind.choice,
      presentation: AgentModelControlPresentation.menuChip,
      conflictsWith: <String>[AgentModelControlIds.thinkingBudget],
    ),
    anthropicThinkingBudgetControl,
  ];

  @override
  ModelGateway createProvider(ModelGatewayRequest request) {
    final credential = request.credential;
    return AnthropicMessagesProvider(
      AnthropicProviderConfig(
        id: request.connectionId,
        apiKey: credential is ApiKeyCredential ? credential.key : '',
        baseUrl: request.endpoint.baseUrl,
        extensions: request.endpoint.extensions,
      ),
      dio: dioFactory?.call(request.endpoint),
    );
  }

  @override
  Future<List<String>> discoverModels(
    ProviderEndpoint endpoint,
    ProviderCredential? credential,
  ) async {
    final dio =
        dioFactory?.call(endpoint) ??
        Dio(BaseOptions(baseUrl: endpoint.baseUrl));
    if (dio.options.baseUrl.isEmpty) dio.options.baseUrl = endpoint.baseUrl;
    final result = <String>[];
    String? afterId;
    try {
      do {
        final response = await dio.get<Map<String, dynamic>>(
          '/models',
          queryParameters: <String, dynamic>{
            'limit': 100,
            'after_id': ?afterId,
          },
          options: Options(
            headers: <String, String>{
              if (credential case ApiKeyCredential(:final key))
                'x-api-key': key,
              'anthropic-version': '2023-06-01',
            },
          ),
        );
        final body = response.data;
        final data = body?['data'];
        if (data is! List) {
          throw const FormatException('Anthropic models response is invalid.');
        }
        for (final item in data.whereType<Map<String, dynamic>>()) {
          final id = item['id'];
          if (id is String && id.isNotEmpty) result.add(id);
        }
        final hasMore = body?['has_more'] == true;
        afterId = hasMore && body?['last_id'] is String
            ? body!['last_id']! as String
            : null;
      } while (afterId != null);
      return result;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      throw ProviderDiscoveryFailure(
        status == 401 || status == 403
            ? ProviderDiscoveryFailureKind.invalidCredential
            : ProviderDiscoveryFailureKind.unavailable,
        error.message ?? 'Anthropic model discovery failed.',
      );
    }
  }
}
