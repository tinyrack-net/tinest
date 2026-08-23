import 'package:agent/agent.dart';
import 'package:protocol/protocol.dart';

/// Converts agent risk to the protocol contract.
ToolRisk protocolRisk(AgentToolRisk value) =>
    ToolRisk.values.byName(value.name);

/// Converts protocol permissions to the agent domain.
AgentPermissionMode agentPermission(PermissionMode value) =>
    AgentPermissionMode.values.byName(value.name);

/// Converts agent runtime status to the protocol contract.
SessionStatus protocolSessionStatus(AgentSessionStatus value) =>
    SessionStatus.values.byName(value.name);

/// Converts attachment category to the agent domain.
AgentAttachmentKind agentAttachmentKind(AttachmentKind value) =>
    AgentAttachmentKind.values.byName(value.name);

/// Converts provider authentication kind to the agent domain.
AgentProviderAuthKind agentAuthKind(ProviderAuthKind value) =>
    AgentProviderAuthKind.values.byName(value.name);

/// Converts model capabilities to the agent domain.
AgentModelCapabilities agentCapabilities(ModelCapabilitiesDto value) =>
    AgentModelCapabilities(
      streaming: AgentCapabilitySupport.values.byName(value.streaming.name),
      toolCalling: AgentCapabilitySupport.values.byName(value.toolCalling.name),
      functionTools: AgentCapabilitySupport.values.byName(
        value.functionTools.name,
      ),
      deferredTools: AgentCapabilitySupport.values.byName(
        value.deferredTools.name,
      ),
      imageInput: AgentCapabilitySupport.values.byName(value.imageInput.name),
      fileInput: AgentCapabilitySupport.values.byName(value.fileInput.name),
      controls: value.controls.map(agentControlDescriptor).toList(),
      source: AgentCapabilitySource.values.byName(value.source.name),
    );

/// Converts model capabilities to the protocol contract.
ModelCapabilitiesDto protocolCapabilities(AgentModelCapabilities value) =>
    ModelCapabilitiesDto(
      streaming: CapabilitySupport.values.byName(value.streaming.name),
      toolCalling: CapabilitySupport.values.byName(value.toolCalling.name),
      functionTools: CapabilitySupport.values.byName(value.functionTools.name),
      deferredTools: CapabilitySupport.values.byName(value.deferredTools.name),
      imageInput: CapabilitySupport.values.byName(value.imageInput.name),
      fileInput: CapabilitySupport.values.byName(value.fileInput.name),
      controls: value.controls.map(protocolControlDescriptor).toList(),
      source: CapabilitySource.values.byName(value.source.name),
    );

/// Converts a protocol control descriptor to the agent domain.
AgentModelControlDescriptor agentControlDescriptor(
  ModelControlDescriptorDto value,
) => AgentModelControlDescriptor(
  id: value.id,
  label: value.label,
  kind: AgentModelControlKind.values.byName(value.kind.name),
  presentation: AgentModelControlPresentation.values.byName(
    value.presentation.name,
  ),
  description: value.description,
  choices: <AgentModelControlChoice>[
    for (final choice in value.choices)
      AgentModelControlChoice(
        id: choice.id,
        label: choice.label,
        description: choice.description,
      ),
  ],
  minimum: value.minimum,
  maximum: value.maximum,
  step: value.step,
  conflictsWith: value.conflictsWith,
);

/// Converts an agent control descriptor to the protocol contract.
ModelControlDescriptorDto protocolControlDescriptor(
  AgentModelControlDescriptor value,
) => ModelControlDescriptorDto(
  id: value.id,
  label: value.label,
  kind: ModelControlKind.values.byName(value.kind.name),
  presentation: ModelControlPresentation.values.byName(value.presentation.name),
  description: value.description,
  choices: <ModelControlChoiceDto>[
    for (final choice in value.choices)
      ModelControlChoiceDto(
        id: choice.id,
        label: choice.label,
        description: choice.description,
      ),
  ],
  minimum: value.minimum,
  maximum: value.maximum,
  step: value.step,
  conflictsWith: value.conflictsWith,
);

/// Converts protocol model-control values to the provider-neutral domain.
Map<String, AgentModelControlValue> agentModelControls(
  Map<String, ModelControlValueDto> values,
) => <String, AgentModelControlValue>{
  for (final entry in values.entries)
    entry.key: switch (entry.value) {
      ModelControlStringValueDto(:final value) => AgentModelControlStringValue(
        value: value,
      ),
      ModelControlBoolValueDto(:final value) => AgentModelControlBoolValue(
        value: value,
      ),
      ModelControlIntValueDto(:final value) => AgentModelControlIntValue(
        value: value,
      ),
    },
};

/// Converts optional pricing to the protocol contract.
ModelPricingDto? protocolPricing(AgentModelPricing? value) => value == null
    ? null
    : ModelPricingDto(
        input: value.input,
        output: value.output,
        cacheRead: value.cacheRead,
        cacheWrite: value.cacheWrite,
      );

/// Converts optional token limits to the protocol contract.
ModelLimitsDto? protocolLimits(AgentModelLimits? value) => value == null
    ? null
    : ModelLimitsDto(
        context: value.context,
        input: value.input,
        output: value.output,
      );

/// Converts provider metadata to the protocol contract.
ProviderDefinitionDto protocolProviderDefinition(
  AgentProviderDefinition value,
) => ProviderDefinitionDto(
  id: value.id,
  name: value.name,
  description: value.description,
  authMethods: <ProviderAuthMethodDto>[
    for (final method in value.authMethods)
      ProviderAuthMethodDto(
        id: method.id,
        label: method.label,
        kind: ProviderAuthKind.values.byName(method.kind.name),
        flow: ProviderAuthFlow.values.byName(method.flow.name),
        experimental: method.experimental,
      ),
  ],
  recommendedModelIds: value.recommendedModelIds,
  local: value.local,
  experimental: value.experimental,
  documentationUrl: value.documentationUrl,
);
