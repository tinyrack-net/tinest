import 'package:agent/agent.dart';
import 'package:daemon/src/features/providers/infrastructure/openai/chat_completions_provider.dart';
import 'package:daemon/src/features/providers/infrastructure/openai/openai_provider.dart';
import 'package:dio/dio.dart';

/// Wire protocol identifier of the OpenAI Responses API.
const String openAIResponsesWireId = 'openai-responses';

/// Wire protocol identifier of the OpenAI Chat Completions API.
const String openAIChatCompletionsWireId = 'openai-chat-completions';

/// Shared transport behaviour of the two OpenAI-compatible wire protocols.
///
/// Both authenticate with a bearer token and list models on `/models`; they
/// differ only in the streaming endpoint the adapter speaks.
abstract base class OpenAICompatibleWire implements ProviderWireProtocol {
  /// Allows subclasses to be const.
  const new({this.dioFactory});

  /// Injectable HTTP client factory used by deterministic contract tests.
  final Dio Function(ProviderEndpoint endpoint)? dioFactory;

  /// Reasoning effort is the one control both OpenAI-compatible APIs encode.
  ///
  /// The template carries no levels. A custom connection addresses an endpoint
  /// nobody here has seen, and which levels it takes is known only to whoever
  /// runs it. Fast mode is absent for a related reason: `service_tier` is a
  /// platform-only field that would never reach such an endpoint at all.
  @override
  List<AgentModelControlDescriptor> get controlDescriptors => const [
    AgentModelControlDescriptor(
      id: AgentModelControlIds.reasoningEffort,
      label: 'Reasoning effort',
      kind: AgentModelControlKind.choice,
      presentation: AgentModelControlPresentation.menuChip,
      conflictsWith: <String>[AgentModelControlIds.reasoningMode],
    ),
  ];

  @override
  ModelGateway createProvider(ModelGatewayRequest request) =>
      adapterFor(request);

  /// Builds the adapter, letting a vendor add its own non-secret headers.
  ///
  /// Every optional request field is decided by what the endpoint states it
  /// accepts. One wire implementation serves many endpoints, so a default here
  /// would be one vendor's answer applied to all of them.
  ModelGateway adapterFor(
    ModelGatewayRequest request, {
    Map<String, String> additionalHeaders = const <String, String>{},
    String? requestAttribution,
  }) {
    final credential = request.credential;
    final capabilities = request.capabilities;
    final endpoint = request.endpoint;
    final config = OpenAIProviderConfig(
      id: request.connectionId,
      apiKey: switch (credential) {
        ApiKeyCredential(:final key) => key,
        OAuthCredential(:final accessToken) => accessToken,
        null => '',
      },
      baseUrl: endpoint.baseUrl,
      requiresApiKey: credential != null,
      supportsReasoningEffort: capabilities.controls.any(
        (control) => control.id == AgentModelControlIds.reasoningEffort,
      ),
      supportsImageInput:
          capabilities.imageInput == AgentCapabilitySupport.supported,
      supportsFileInput:
          capabilities.fileInput == AgentCapabilitySupport.supported,
      // Expedited processing needs both halves: the endpoint has to define the
      // field and the model has to offer the control that sets it.
      extensions: <ProviderEndpointExtension>{
        for (final extension in endpoint.extensions)
          if (extension != ProviderEndpointExtension.expeditedProcessing ||
              capabilities.controls.any(
                (control) => control.id == AgentModelControlIds.fastMode,
              ))
            extension,
      },
      requestAttribution: requestAttribution,
      additionalHeaders: additionalHeaders,
    );
    final dio = dioFactory?.call(request.endpoint);
    if (dio != null && dio.options.baseUrl.isEmpty) {
      dio.options.baseUrl = request.endpoint.baseUrl;
    }
    return buildAdapter(config, dio);
  }

  /// Builds the concrete adapter of this wire protocol.
  ModelGateway buildAdapter(OpenAIProviderConfig config, Dio? dio);

  @override
  Future<List<String>> discoverModels(
    ProviderEndpoint endpoint,
    ProviderCredential? credential,
  ) async {
    final dio =
        dioFactory?.call(endpoint) ??
        Dio(BaseOptions(baseUrl: endpoint.baseUrl));
    if (dio.options.baseUrl.isEmpty) dio.options.baseUrl = endpoint.baseUrl;
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/models',
        options: Options(
          headers: <String, String>{
            if (credential case ApiKeyCredential(:final key))
              'Authorization': 'Bearer $key',
            if (credential case OAuthCredential(:final accessToken))
              'Authorization': 'Bearer $accessToken',
          },
        ),
      );
      final data = response.data?['data'];
      if (data is! List<dynamic>) {
        throw const FormatException('The /models response has no data list.');
      }
      final ids = <String>[];
      for (final item in data) {
        if (item is! Map<dynamic, dynamic>) continue;
        final id = item['id'];
        if (id is String && id.trim().isNotEmpty) ids.add(id);
      }
      return ids;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      final message = error.message ?? 'Provider model discovery failed.';
      if (statusCode == 401 || statusCode == 403) {
        throw ProviderDiscoveryFailure(
          ProviderDiscoveryFailureKind.invalidCredential,
          message,
        );
      }
      throw ProviderDiscoveryFailure(
        ProviderDiscoveryFailureKind.unavailable,
        message,
      );
    }
  }
}

/// The OpenAI Responses streaming API.
final class OpenAIResponsesWire extends OpenAICompatibleWire {
  /// Creates the Responses wire protocol.
  const new({super.dioFactory});

  @override
  String get id => openAIResponsesWireId;

  @override
  String get label => 'OpenAI Responses';

  /// Only this API encodes `reasoning.mode`, so only it offers the control.
  @override
  List<AgentModelControlDescriptor> get controlDescriptors =>
      <AgentModelControlDescriptor>[
        ...super.controlDescriptors,
        const AgentModelControlDescriptor(
          id: AgentModelControlIds.reasoningMode,
          label: 'Reasoning mode',
          kind: AgentModelControlKind.choice,
          presentation: AgentModelControlPresentation.menuChip,
          conflictsWith: <String>[AgentModelControlIds.reasoningEffort],
        ),
      ];

  @override
  ModelGateway buildAdapter(OpenAIProviderConfig config, Dio? dio) =>
      OpenAIResponsesProvider(config, dio: dio);
}

/// The OpenAI Chat Completions streaming API.
final class OpenAIChatCompletionsWire extends OpenAICompatibleWire {
  /// Creates the Chat Completions wire protocol.
  const new({super.dioFactory});

  @override
  String get id => openAIChatCompletionsWireId;

  @override
  String get label => 'OpenAI Chat Completions';

  @override
  ModelGateway buildAdapter(OpenAIProviderConfig config, Dio? dio) =>
      OpenAIChatCompletionsProvider(config, dio: dio);
}
