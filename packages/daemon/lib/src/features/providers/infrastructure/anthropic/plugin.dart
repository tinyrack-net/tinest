import 'package:agent/agent.dart';
import 'package:daemon/src/features/providers/infrastructure/anthropic/wire.dart';

const AgentProviderAuthMethod _apiKey = AgentProviderAuthMethod(
  id: 'api-key',
  label: 'API key',
  kind: AgentProviderAuthKind.apiKey,
  flow: AgentProviderAuthFlow.apiKey,
);

/// Public Anthropic API provider metadata.
const AgentProviderDefinition anthropicDefinition = AgentProviderDefinition(
  id: 'anthropic',
  name: 'Anthropic',
  description: 'Claude models through the public Anthropic API.',
  authMethods: <AgentProviderAuthMethod>[_apiKey],
  recommendedModelIds: <String>['claude-sonnet-5', 'claude-opus-5'],
  documentationUrl: 'https://platform.claude.com/docs',
);

// The wire owns each control template, so a bundled model and a custom model
// on the same transport cannot describe the same control differently.
const AgentModelControlDescriptor _effort = anthropicEffortControl;
const AgentModelControlDescriptor _adaptive = anthropicThinkingModeControl;
const AgentModelControlDescriptor _fast = anthropicFastModeControl;
const AgentModelControlDescriptor _budget = anthropicThinkingBudgetControl;

const AgentModelCapabilities _adaptiveCapabilities = AgentModelCapabilities(
  streaming: AgentCapabilitySupport.supported,
  toolCalling: AgentCapabilitySupport.supported,
  functionTools: AgentCapabilitySupport.supported,
  deferredTools: AgentCapabilitySupport.unsupported,
  imageInput: AgentCapabilitySupport.supported,
  fileInput: AgentCapabilitySupport.supported,
  controls: <AgentModelControlDescriptor>[_effort, _adaptive, _fast],
  source: AgentCapabilitySource.bundled,
);

/// Coding-capable Anthropic API models bundled with the daemon.
const List<ProviderCatalogModel> anthropicBundledModels =
    <ProviderCatalogModel>[
      ProviderCatalogModel(
        id: 'claude-sonnet-5',
        label: 'Claude Sonnet 5',
        capabilities: _adaptiveCapabilities,
      ),
      ProviderCatalogModel(
        id: 'claude-opus-5',
        label: 'Claude Opus 5',
        capabilities: _adaptiveCapabilities,
      ),
      ProviderCatalogModel(
        id: 'claude-opus-4-5',
        label: 'Claude Opus 4.5',
        capabilities: AgentModelCapabilities(
          streaming: AgentCapabilitySupport.supported,
          toolCalling: AgentCapabilitySupport.supported,
          functionTools: AgentCapabilitySupport.supported,
          deferredTools: AgentCapabilitySupport.unsupported,
          imageInput: AgentCapabilitySupport.supported,
          fileInput: AgentCapabilitySupport.supported,
          controls: <AgentModelControlDescriptor>[_effort, _budget],
          source: AgentCapabilitySource.bundled,
        ),
      ),
    ];

/// Built-in Anthropic public API adapter.
final class AnthropicAdapter extends ProviderAdapter {
  /// Creates the adapter.
  const new({this.wire = const AnthropicMessagesWire()});

  /// Messages wire shared with custom connections.
  final AnthropicMessagesWire wire;

  @override
  String get id => anthropicDefinition.id;

  @override
  AgentProviderDefinition get definition => anthropicDefinition;

  @override
  List<ProviderCatalogModel> get models => anthropicBundledModels;

  @override
  ProviderEndpoint endpoint(AgentProviderAuthKind authKind) =>
      const ProviderEndpoint(
        baseUrl: 'https://api.anthropic.com/v1',
        extensions: <ProviderEndpointExtension>{
          ProviderEndpointExtension.modelDiscovery,
          ProviderEndpointExtension.strictToolSchemas,
          ProviderEndpointExtension.expeditedProcessing,
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
