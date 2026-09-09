import 'package:agent/agent.dart';
import 'package:daemon/src/features/providers/infrastructure/gemini/wire.dart';

const AgentProviderAuthMethod _apiKey = AgentProviderAuthMethod(
  id: 'api-key',
  label: 'API key',
  kind: AgentProviderAuthKind.apiKey,
  flow: AgentProviderAuthFlow.apiKey,
);

/// Public Google Gemini API provider metadata.
const AgentProviderDefinition googleDefinition = AgentProviderDefinition(
  id: 'google',
  name: 'Google Gemini',
  description: 'Gemini models through the public Interactions API.',
  authMethods: <AgentProviderAuthMethod>[_apiKey],
  recommendedModelIds: <String>['gemini-3.6-pro', 'gemini-3.6-flash'],
  documentationUrl: 'https://ai.google.dev/gemini-api/docs',
);

const AgentModelControlDescriptor _thinkingLevel = AgentModelControlDescriptor(
  id: AgentModelControlIds.reasoningEffort,
  label: 'Thinking level',
  kind: AgentModelControlKind.choice,
  presentation: AgentModelControlPresentation.menuChip,
  choices: <AgentModelControlChoice>[
    AgentModelControlChoice(id: 'minimal', label: 'Minimal'),
    AgentModelControlChoice(id: 'low', label: 'Low'),
    AgentModelControlChoice(id: 'medium', label: 'Medium'),
    AgentModelControlChoice(id: 'high', label: 'High'),
  ],
);

const AgentModelCapabilities _geminiCapabilities = AgentModelCapabilities(
  streaming: AgentCapabilitySupport.supported,
  toolCalling: AgentCapabilitySupport.supported,
  functionTools: AgentCapabilitySupport.supported,
  deferredTools: AgentCapabilitySupport.unsupported,
  imageInput: AgentCapabilitySupport.supported,
  fileInput: AgentCapabilitySupport.supported,
  controls: <AgentModelControlDescriptor>[_thinkingLevel],
  source: AgentCapabilitySource.bundled,
);

/// Coding-capable Gemini API models bundled with the daemon.
const List<ProviderCatalogModel> googleBundledModels = <ProviderCatalogModel>[
  ProviderCatalogModel(
    id: 'gemini-3.6-pro',
    label: 'Gemini 3.6 Pro',
    capabilities: _geminiCapabilities,
  ),
  ProviderCatalogModel(
    id: 'gemini-3.6-flash',
    label: 'Gemini 3.6 Flash',
    capabilities: _geminiCapabilities,
  ),
];

/// Built-in Google public Gemini API adapter.
final class GoogleGeminiAdapter extends ProviderAdapter {
  /// Creates the adapter.
  const new({this.wire = const GeminiInteractionsWire()});

  /// Interactions wire shared with custom connections.
  final GeminiInteractionsWire wire;

  @override
  String get id => googleDefinition.id;

  @override
  AgentProviderDefinition get definition => googleDefinition;

  @override
  List<ProviderCatalogModel> get models => googleBundledModels;

  @override
  ProviderEndpoint endpoint(AgentProviderAuthKind authKind) =>
      const ProviderEndpoint(
        baseUrl: 'https://generativelanguage.googleapis.com/v1',
        extensions: <ProviderEndpointExtension>{
          ProviderEndpointExtension.modelDiscovery,
        },
      );

  @override
  ModelGateway createProvider(ModelGatewayRequest request) =>
      wire.createProvider(request);

  @override
  Future<List<String>> discoverModels(
    ProviderEndpoint endpoint,
    ProviderCredential? credential,
  ) => wire.discoverModels(endpoint, credential);
}
