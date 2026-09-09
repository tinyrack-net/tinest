import 'package:app/l10n/gen/app_localizations.dart';
import 'package:protocol/protocol.dart';

/// One tool group and the catalog entries that landed in it.
final class AgentToolGroupView {
  /// Creates a group view over [tools].
  const new({required this.group, required this.tools});

  /// The group these tools are presented and toggled under.
  final String group;

  /// The group's tools, in catalog order.
  final List<AgentToolDefinitionDto> tools;

  /// The ids a user may turn on or off independently.
  List<String> get toggleableIds => <String>[for (final tool in tools) tool.id];

  /// How many of this group's tools a turn would receive.
  int enabledCount(Set<String> selected) =>
      tools.where((tool) => selected.contains(tool.id)).length;

  /// Whether every tool in this group is on.
  bool allEnabled(Set<String> selected) =>
      enabledCount(selected) == tools.length;

  /// Whether the group is neither fully on nor fully off.
  bool partiallyEnabled(Set<String> selected) {
    final enabled = enabledCount(selected);
    return enabled > 0 && enabled < tools.length;
  }
}

/// Splits [tools] into groups, retaining the catalog's first-seen group order.
///
List<AgentToolGroupView> groupAgentTools(List<AgentToolDefinitionDto> tools) {
  final byGroup = <String, List<AgentToolDefinitionDto>>{};
  for (final tool in tools) {
    byGroup.putIfAbsent(tool.group, () => <AgentToolDefinitionDto>[]).add(tool);
  }
  return <AgentToolGroupView>[
    for (final entry in byGroup.entries)
      AgentToolGroupView(
        group: entry.key,
        tools: List.unmodifiable(entry.value),
      ),
  ];
}

/// The localized name of [group].
String toolGroupLabel(AppLocalizations l10n, String group) => switch (group) {
  'filesystem' => l10n.agentSettingsToolGroupFilesystem,
  'editing' => l10n.agentSettingsToolGroupEditing,
  'execution' => l10n.agentSettingsToolGroupExecution,
  'attachments' => l10n.agentSettingsToolGroupAttachments,
  'mcp' => l10n.agentSettingsToolGroupMcp,
  'collaboration' => l10n.agentSettingsToolGroupCollaboration,
  'session' => l10n.agentSettingsToolGroupSession,
  _ => group,
};
