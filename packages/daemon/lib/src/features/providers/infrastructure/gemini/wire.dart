import 'package:agent/agent.dart';
import 'package:daemon/src/features/providers/infrastructure/gemini/gemini_provider.dart';
import 'package:dio/dio.dart';

/// Custom-provider wire ID for Gemini Interactions.
const String geminiInteractionsWireId = 'gemini-interactions';

/// Gemini Interactions v1 transport.
final class GeminiInteractionsWire implements ProviderWireProtocol {
  /// Creates the wire with an optional deterministic HTTP client factory.
  const new({this.dioFactory});

  /// Injectable client factory used by contract tests.
  final Dio Function(ProviderEndpoint endpoint)? dioFactory;

  @override
  String get id => geminiInteractionsWireId;

  @override
  String get label => 'Gemini Interactions';

  /// This transport encodes a thinking level and nothing else.
  ///
  /// A thinking budget was advertised here without ever being sent, so the
  /// dialog it opened could not affect a single request.
  @override
  List<AgentModelControlDescriptor> get controlDescriptors => const [
    AgentModelControlDescriptor(
      id: AgentModelControlIds.reasoningEffort,
      label: 'Thinking level',
      kind: AgentModelControlKind.choice,
      presentation: AgentModelControlPresentation.menuChip,
    ),
  ];

  @override
  ModelGateway createProvider(ModelGatewayRequest request) {
    final credential = request.credential;
    return GeminiInteractionsProvider(
      GeminiProviderConfig(
        id: request.connectionId,
        apiKey: credential is ApiKeyCredential ? credential.key : '',
        baseUrl: request.endpoint.baseUrl,
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
    String? pageToken;
    try {
      do {
        final response = await dio.get<Map<String, dynamic>>(
          '/models',
          queryParameters: <String, dynamic>{
            'pageSize': 1000,
            'pageToken': ?pageToken,
          },
          options: Options(
            headers: <String, String>{
              if (credential case ApiKeyCredential(:final key))
                'x-goog-api-key': key,
            },
          ),
        );
        final body = response.data;
        final models = body?['models'];
        if (models is! List) {
          throw const FormatException('Gemini models response is invalid.');
        }
        for (final model in models.whereType<Map<String, dynamic>>()) {
          final name = model['name'];
          final methods = model['supportedGenerationMethods'];
          if (name is! String || _isManagedAgent(name)) continue;
          if (methods is List &&
              !methods.contains('generateContent') &&
              !methods.contains('interactions')) {
            continue;
          }
          result.add(name.startsWith('models/') ? name.substring(7) : name);
        }
        pageToken = body?['nextPageToken'] is String
            ? body!['nextPageToken']! as String
            : null;
      } while (pageToken != null && pageToken.isNotEmpty);
      return result;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      throw ProviderDiscoveryFailure(
        status == 401 || status == 403
            ? ProviderDiscoveryFailureKind.invalidCredential
            : ProviderDiscoveryFailureKind.unavailable,
        error.message ?? 'Gemini model discovery failed.',
      );
    }
  }

  bool _isManagedAgent(String id) {
    final value = id.toLowerCase();
    return value.contains('antigravity') || value.contains('deep-research');
  }
}
