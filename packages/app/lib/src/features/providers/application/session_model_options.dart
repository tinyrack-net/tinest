import 'package:protocol/protocol.dart';

/// Agent definitions a user may start a session with.
///
/// Unlike the daemon, this does not require the definition's own model to
/// resolve: the composer can pin an explicit provider and model instead.
List<AgentDefinitionDto> selectableAgentDefinitions(
  List<AgentDefinitionDto> definitions,
) => definitions
    .where(
      (definition) =>
          definition.mode == AgentMode.primary &&
          !definition.isArchived &&
          !definition.isStale,
    )
    .toList(growable: false);

/// Provider connections that can currently run a turn.
List<ProviderConnectionDto> usableConnections(
  List<ProviderConnectionDto> connections,
) {
  final usable =
      connections
          .where(
            (connection) =>
                connection.status == ProviderConnectionStatus.connected ||
                connection.status == ProviderConnectionStatus.degraded,
          )
          .toList()
        ..sort((left, right) {
          final byName = left.displayName.compareTo(right.displayName);
          return byName != 0
              ? byName
              : left.modelPrefix.compareTo(right.modelPrefix);
        });
  return usable;
}

/// Resolves the provider and model a definition would use on its own.
///
/// Returns null only when the definition delegates to the daemon default.
/// An unavailable explicit selection is preserved so the UI can show its raw
/// ID and block execution instead of silently falling through.
ModelSelectionDto? agentSelectionFor(AgentDefinitionDto definition) {
  final model = definition.model;
  final modelId = model.modelId;
  return model.source == AgentModelSource.fixed && modelId != null
      ? ModelSelectionDto(modelId: modelId)
      : null;
}

/// Whether one selection names a connection and model that can run a turn.
///
/// Mirrors the daemon predicate so the composer never shows a model the daemon
/// would refuse at turn start.
bool isRunnableSelection(
  ModelSelectionDto selection,
  List<ProviderConnectionDto> connections,
  Map<String, List<ProviderModelDto>> models,
) {
  final usable = usableConnections(connections);
  for (final connection in usable) {
    for (final model in models[connection.id] ?? const <ProviderModelDto>[]) {
      if (model.id == selection.qualifiedModelId) {
        return _isRunnableModel(model);
      }
    }
  }
  return false;
}

/// Returns the first runnable model of the first usable connection.
///
/// [connections] must arrive in daemon order (display name ascending) and the
/// lists in [models] in `listProviderModels` order (label ascending), so this
/// resolves to the same model the daemon would pick.
ModelSelectionDto? firstUsableModel(
  List<ProviderConnectionDto> connections,
  Map<String, List<ProviderModelDto>> models,
) {
  for (final connection in usableConnections(connections)) {
    final ordered =
        <ProviderModelDto>[
          ...models[connection.id] ?? const <ProviderModelDto>[],
        ]..sort((left, right) {
          final byLabel = left.label.compareTo(right.label);
          return byLabel != 0 ? byLabel : left.id.compareTo(right.id);
        });
    for (final model in ordered) {
      if (!_isRunnableModel(model)) continue;
      return ModelSelectionDto(modelId: model.id);
    }
  }
  return null;
}

/// Resolves the model a session runs on when it has no explicit override.
///
/// Applies the agent definition, then the daemon-global [defaultModel], then
/// the first runnable provider model. Explicit unavailable values remain the
/// result so callers can report and block them without falling through.
ModelSelectionDto? effectiveModelFor({
  required AgentDefinitionDto? definition,
  required List<ProviderConnectionDto> connections,
  required Map<String, List<ProviderModelDto>> models,
  ModelSelectionDto? defaultModel,
}) {
  if (definition != null) {
    final pinned = agentSelectionFor(definition);
    if (pinned != null) return pinned;
  }
  if (defaultModel != null) return defaultModel;
  return firstUsableModel(connections, models);
}

bool _isRunnableModel(ProviderModelDto model) =>
    model.capabilities.streaming == CapabilitySupport.supported &&
    model.capabilities.toolCalling == CapabilitySupport.supported;
