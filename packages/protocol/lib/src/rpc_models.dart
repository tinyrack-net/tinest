// @dart=3.12

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:protocol/src/models.dart';
import 'package:protocol/src/protocol.dart';

part 'rpc_models.freezed.dart';
part 'rpc_models.g.dart';

@freezed
/// HelloParamsDto defines a public contract.
abstract class HelloParamsDto with _$HelloParamsDto {
  /// The HelloParamsDto public API member.
  const factory HelloParamsDto({
    required String clientId,
    required String clientKind,
    required int protocolMajor,
    required Map<String, bool> capabilities,
    @Default(tinestProtocolRevision) int protocolRevision,
    @Default('unknown') String clientVersion,
  }) = _HelloParamsDto;

  /// Creates a [HelloParamsDto].
  factory HelloParamsDto.fromJson(Map<String, dynamic> json) =>
      _$HelloParamsDtoFromJson(json);
}

@freezed
/// WorkspaceRegisterParamsDto defines a public contract.
abstract class WorkspaceRegisterParamsDto with _$WorkspaceRegisterParamsDto {
  /// The WorkspaceRegisterParamsDto public API member.
  const factory WorkspaceRegisterParamsDto({
    required String workspaceId,
    required String checkoutId,
    required String rootPath,
    required String name,
  }) = _WorkspaceRegisterParamsDto;

  /// Creates a [WorkspaceRegisterParamsDto].
  factory WorkspaceRegisterParamsDto.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceRegisterParamsDtoFromJson(json);
}

@freezed
/// Selects one registered workspace for refresh or removal.
abstract class WorkspaceIdParamsDto with _$WorkspaceIdParamsDto {
  /// Creates workspace identifier parameters.
  const factory WorkspaceIdParamsDto({required String workspaceId}) =
      _WorkspaceIdParamsDto;

  /// Decodes workspace identifier parameters.
  factory WorkspaceIdParamsDto.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceIdParamsDtoFromJson(json);
}

@freezed
/// Searches directories on the daemon host.
abstract class DirectorySuggestParamsDto with _$DirectorySuggestParamsDto {
  /// Creates directory search parameters.
  const factory DirectorySuggestParamsDto({
    required String query,
    @Default(30) int limit,
  }) = _DirectorySuggestParamsDto;

  /// Decodes directory search parameters.
  factory DirectorySuggestParamsDto.fromJson(Map<String, dynamic> json) =>
      _$DirectorySuggestParamsDtoFromJson(json);
}

@freezed
/// Searches one worktree for files a composer mention can reference.
abstract class FileSearchParamsDto with _$FileSearchParamsDto {
  /// Creates file search parameters.
  ///
  /// An empty [query] asks for the head of the index rather than no results.
  const factory FileSearchParamsDto({
    required String worktreeId,
    required String query,
    @Default(50) int limit,
  }) = _FileSearchParamsDto;

  /// Decodes file search parameters.
  factory FileSearchParamsDto.fromJson(Map<String, dynamic> json) =>
      _$FileSearchParamsDtoFromJson(json);
}

@freezed
/// Scopes an agent command request to the global sources plus one workspace.
abstract class CommandListParamsDto with _$CommandListParamsDto {
  /// Creates command list parameters.
  const factory CommandListParamsDto({String? workspaceId}) =
      _CommandListParamsDto;

  /// Decodes command list parameters.
  factory CommandListParamsDto.fromJson(Map<String, dynamic> json) =>
      _$CommandListParamsDtoFromJson(json);
}

@freezed
/// Requests local branches for one Git workspace.
abstract class GitBranchesListParamsDto with _$GitBranchesListParamsDto {
  /// Creates branch-list parameters.
  const factory GitBranchesListParamsDto({required String workspaceId}) =
      _GitBranchesListParamsDto;

  /// Decodes branch-list parameters.
  factory GitBranchesListParamsDto.fromJson(Map<String, dynamic> json) =>
      _$GitBranchesListParamsDtoFromJson(json);
}

@freezed
/// Creates a managed Git worktree from a new or existing local branch.
abstract class WorktreeCreateParamsDto with _$WorktreeCreateParamsDto {
  /// Creates managed-worktree parameters.
  ///
  /// [branchNaming] decides what happens when [branchName] is already taken by
  /// a local branch or an existing checkout path. The daemon owns that check
  /// because only it can see branches left behind by archived worktrees.
  const factory WorktreeCreateParamsDto({
    required String id,
    required String workspaceId,
    required WorktreeCreateMode mode,
    required String branchName,
    String? baseBranch,
    @Default(WorktreeBranchNaming.exact) WorktreeBranchNaming branchNaming,
  }) = _WorktreeCreateParamsDto;

  /// Decodes managed-worktree parameters.
  factory WorktreeCreateParamsDto.fromJson(Map<String, dynamic> json) =>
      _$WorktreeCreateParamsDtoFromJson(json);
}

@freezed
/// Identifies one worktree.
abstract class WorktreeIdParamsDto with _$WorktreeIdParamsDto {
  /// Creates worktree identifier parameters.
  const factory WorktreeIdParamsDto({required String worktreeId}) =
      _WorktreeIdParamsDto;

  /// Decodes worktree identifier parameters.
  factory WorktreeIdParamsDto.fromJson(Map<String, dynamic> json) =>
      _$WorktreeIdParamsDtoFromJson(json);
}

@freezed
/// Confirms archive risks for one worktree.
abstract class WorktreeArchiveParamsDto with _$WorktreeArchiveParamsDto {
  /// Creates worktree archive parameters.
  const factory WorktreeArchiveParamsDto({
    required String worktreeId,
    required bool force,
  }) = _WorktreeArchiveParamsDto;

  /// Decodes worktree archive parameters.
  factory WorktreeArchiveParamsDto.fromJson(Map<String, dynamic> json) =>
      _$WorktreeArchiveParamsDtoFromJson(json);
}

@freezed
/// Filters sessions by worktree.
abstract class SessionListParamsDto with _$SessionListParamsDto {
  /// Creates session list parameters.
  const factory SessionListParamsDto({String? worktreeId}) =
      _SessionListParamsDto;

  /// Decodes session list parameters.
  factory SessionListParamsDto.fromJson(Map<String, dynamic> json) =>
      _$SessionListParamsDtoFromJson(json);
}

@freezed
/// Selects the collaboration tree containing one session.
abstract class SessionSubagentListParamsDto
    with _$SessionSubagentListParamsDto {
  /// Creates subagent list parameters.
  const factory SessionSubagentListParamsDto({required String sessionId}) =
      _SessionSubagentListParamsDto;

  /// Decodes subagent list parameters.
  factory SessionSubagentListParamsDto.fromJson(Map<String, dynamic> json) =>
      _$SessionSubagentListParamsDtoFromJson(json);
}

@freezed
/// Creates a user-visible session from a primary agent definition.
abstract class SessionCreateParamsDto with _$SessionCreateParamsDto {
  /// Creates session creation parameters.
  const factory SessionCreateParamsDto({
    required String id,
    required String worktreeId,
    required String title,
    required String agentDefinitionId,
    ModelSelectionDto? model,
    @Default(<String, ModelControlValueDto>{})
    Map<String, ModelControlValueDto> modelControls,

    /// Permission mode to pin on the new session; null takes the daemon
    /// default that is configured when the session is created.
    PermissionMode? permissionMode,
  }) = _SessionCreateParamsDto;

  /// Decodes session creation parameters.
  factory SessionCreateParamsDto.fromJson(Map<String, dynamic> json) =>
      _$SessionCreateParamsDtoFromJson(json);
}

@freezed
/// Changes to session execution settings.
abstract class SessionSettingsPatchDto with _$SessionSettingsPatchDto {
  /// Creates an atomic session settings patch.
  const factory SessionSettingsPatchDto({
    @Default(false) bool hasModel,
    ModelSelectionDto? model,
    @Default(false) bool hasModelControls,
    @Default(<String, ModelControlValueDto>{})
    Map<String, ModelControlValueDto> modelControls,

    /// New permission mode, or null to leave the current one in place. A
    /// session always owns a concrete mode, so there is nothing to clear and
    /// the field needs no has-flag of its own.
    PermissionMode? permissionMode,
  }) = _SessionSettingsPatchDto;

  /// Decodes a session settings patch.
  factory SessionSettingsPatchDto.fromJson(Map<String, dynamic> json) =>
      _$SessionSettingsPatchDtoFromJson(json);
}

@freezed
/// Parameters for the atomic `sessions.updateSettings` procedure.
abstract class SessionSettingsUpdateParamsDto
    with _$SessionSettingsUpdateParamsDto {
  /// Creates update parameters for one session.
  const factory SessionSettingsUpdateParamsDto({
    required String sessionId,
    required SessionSettingsPatchDto patch,
  }) = _SessionSettingsUpdateParamsDto;

  /// Decodes session settings update parameters.
  factory SessionSettingsUpdateParamsDto.fromJson(Map<String, dynamic> json) =>
      _$SessionSettingsUpdateParamsDtoFromJson(json);
}

@freezed
/// Identifies one Markdown-backed agent definition.
abstract class AgentDefinitionIdParamsDto with _$AgentDefinitionIdParamsDto {
  /// Creates agent definition identifier parameters.
  const factory AgentDefinitionIdParamsDto({required String id}) =
      _AgentDefinitionIdParamsDto;

  /// Decodes agent definition identifier parameters.
  factory AgentDefinitionIdParamsDto.fromJson(Map<String, dynamic> json) =>
      _$AgentDefinitionIdParamsDtoFromJson(json);
}

@freezed
/// Creates one Markdown-backed agent definition.
abstract class AgentDefinitionCreateParamsDto
    with _$AgentDefinitionCreateParamsDto {
  /// Creates agent definition creation parameters.
  const factory AgentDefinitionCreateParamsDto({
    required String id,
    required AgentDefinitionDto definition,
  }) = _AgentDefinitionCreateParamsDto;

  /// Decodes agent definition creation parameters.
  factory AgentDefinitionCreateParamsDto.fromJson(Map<String, dynamic> json) =>
      _$AgentDefinitionCreateParamsDtoFromJson(json);
}

@freezed
/// Updates one Markdown-backed agent definition with optimistic concurrency.
abstract class AgentDefinitionUpdateParamsDto
    with _$AgentDefinitionUpdateParamsDto {
  /// Creates agent definition update parameters.
  const factory AgentDefinitionUpdateParamsDto({
    required AgentDefinitionDto definition,
    required String expectedContentHash,
    @Default(false) bool force,
  }) = _AgentDefinitionUpdateParamsDto;

  /// Decodes agent definition update parameters.
  factory AgentDefinitionUpdateParamsDto.fromJson(Map<String, dynamic> json) =>
      _$AgentDefinitionUpdateParamsDtoFromJson(json);
}

@freezed
/// Validates an agent Markdown document without saving it.
abstract class AgentDefinitionValidateParamsDto
    with _$AgentDefinitionValidateParamsDto {
  /// Creates agent definition validation parameters.
  const factory AgentDefinitionValidateParamsDto({
    required String id,
    required String markdown,
  }) = _AgentDefinitionValidateParamsDto;

  /// Decodes agent definition validation parameters.
  factory AgentDefinitionValidateParamsDto.fromJson(
    Map<String, dynamic> json,
  ) => _$AgentDefinitionValidateParamsDtoFromJson(json);
}

@freezed
/// Identifies one app-data or bundled plugin.
abstract class PluginIdParamsDto with _$PluginIdParamsDto {
  /// Creates plugin identifier parameters.
  const factory PluginIdParamsDto({required String id}) = _PluginIdParamsDto;

  /// Decodes plugin identifier parameters.
  factory PluginIdParamsDto.fromJson(Map<String, dynamic> json) =>
      _$PluginIdParamsDtoFromJson(json);
}

@freezed
/// Reloads one plugin in the context of an Agent's stored grants.
abstract class PluginReloadParamsDto with _$PluginReloadParamsDto {
  /// Creates plugin reload parameters.
  const factory PluginReloadParamsDto({
    required String id,
    required String agentId,
  }) = _PluginReloadParamsDto;

  /// Decodes plugin reload parameters.
  factory PluginReloadParamsDto.fromJson(Map<String, dynamic> json) =>
      _$PluginReloadParamsDtoFromJson(json);
}

@freezed
/// Creates a user plugin package without enabling it globally.
abstract class PluginScaffoldParamsDto with _$PluginScaffoldParamsDto {
  /// Creates plugin scaffold parameters.
  const factory PluginScaffoldParamsDto({
    required String id,
    required String name,
  }) = _PluginScaffoldParamsDto;

  /// Decodes plugin scaffold parameters.
  factory PluginScaffoldParamsDto.fromJson(Map<String, dynamic> json) =>
      _$PluginScaffoldParamsDtoFromJson(json);
}

@freezed
/// Creates an app-data plugin from one installed validated revision.
abstract class PluginForkParamsDto with _$PluginForkParamsDto {
  /// Creates plugin fork parameters.
  const factory PluginForkParamsDto({
    required String sourceId,
    required String id,
    required String name,
  }) = _PluginForkParamsDto;

  /// Decodes plugin fork parameters.
  factory PluginForkParamsDto.fromJson(Map<String, dynamic> json) =>
      _$PluginForkParamsDtoFromJson(json);
}

@freezed
/// Identifies the grants owned by one Agent.
abstract class AgentPluginGrantsParamsDto with _$AgentPluginGrantsParamsDto {
  /// Creates Agent grant-list parameters.
  const factory AgentPluginGrantsParamsDto({required String agentId}) =
      _AgentPluginGrantsParamsDto;

  /// Decodes Agent grant-list parameters.
  factory AgentPluginGrantsParamsDto.fromJson(Map<String, dynamic> json) =>
      _$AgentPluginGrantsParamsDtoFromJson(json);
}

@freezed
/// Adds or removes one exact Agent plugin capability grant.
abstract class PluginGrantParamsDto with _$PluginGrantParamsDto {
  /// Creates grant mutation parameters.
  const factory PluginGrantParamsDto({required AgentPluginGrantDto grant}) =
      _PluginGrantParamsDto;

  /// Decodes grant mutation parameters.
  factory PluginGrantParamsDto.fromJson(Map<String, dynamic> json) =>
      _$PluginGrantParamsDtoFromJson(json);
}

@freezed
/// Stores one secret in an exact Agent/plugin namespace.
abstract class PluginSecretSetParamsDto with _$PluginSecretSetParamsDto {
  /// Creates a secret mutation. Responses never contain [value].
  const factory PluginSecretSetParamsDto({
    required String agentId,
    required String pluginId,
    required String name,
    required String value,
  }) = _PluginSecretSetParamsDto;

  /// Decodes secret mutation parameters.
  factory PluginSecretSetParamsDto.fromJson(Map<String, dynamic> json) =>
      _$PluginSecretSetParamsDtoFromJson(json);
}

@freezed
/// Removes one secret in an exact Agent/plugin namespace.
abstract class PluginSecretRemoveParamsDto with _$PluginSecretRemoveParamsDto {
  /// Creates a secret removal without accepting or returning a value.
  const factory PluginSecretRemoveParamsDto({
    required String agentId,
    required String pluginId,
    required String name,
  }) = _PluginSecretRemoveParamsDto;

  /// Decodes secret removal parameters.
  factory PluginSecretRemoveParamsDto.fromJson(Map<String, dynamic> json) =>
      _$PluginSecretRemoveParamsDtoFromJson(json);
}

@freezed
/// Identifies one Agent-active plugin session-control contribution.
abstract class PluginSessionControlParamsDto
    with _$PluginSessionControlParamsDto {
  /// Creates session-control read parameters.
  const factory PluginSessionControlParamsDto({
    required String sessionId,
    required String pluginId,
    required String contributionId,
  }) = _PluginSessionControlParamsDto;

  /// Decodes session-control read parameters.
  factory PluginSessionControlParamsDto.fromJson(Map<String, dynamic> json) =>
      _$PluginSessionControlParamsDtoFromJson(json);
}

@freezed
/// Replaces one Agent-active plugin session-control value.
abstract class PluginSessionControlSetParamsDto
    with _$PluginSessionControlSetParamsDto {
  /// Creates session-control mutation parameters.
  const factory PluginSessionControlSetParamsDto({
    required String sessionId,
    required String pluginId,
    required String contributionId,
    required Object? value,
  }) = _PluginSessionControlSetParamsDto;

  /// Decodes session-control mutation parameters.
  factory PluginSessionControlSetParamsDto.fromJson(
    Map<String, dynamic> json,
  ) => _$PluginSessionControlSetParamsDtoFromJson(json);
}

@freezed
/// Requests a declarative UI contribution in a host-owned slot.
abstract class PluginUiRenderParamsDto with _$PluginUiRenderParamsDto {
  /// Creates UI render parameters.
  const factory PluginUiRenderParamsDto({
    required String agentId,
    required String pluginId,
    required String contributionId,
    required PluginUiSlot slot,
    Object? input,
    @Default(<String, dynamic>{}) Map<String, dynamic> context,
  }) = _PluginUiRenderParamsDto;

  /// Decodes UI render parameters.
  factory PluginUiRenderParamsDto.fromJson(Map<String, dynamic> json) =>
      _$PluginUiRenderParamsDtoFromJson(json);
}

@freezed
/// Dispatches an action from a host-rendered plugin UI document.
abstract class PluginUiActionParamsDto with _$PluginUiActionParamsDto {
  /// Creates UI action parameters.
  const factory PluginUiActionParamsDto({
    required String agentId,
    required String pluginId,
    required PluginUiActionDto action,
  }) = _PluginUiActionParamsDto;

  /// Decodes UI action parameters.
  factory PluginUiActionParamsDto.fromJson(Map<String, dynamic> json) =>
      _$PluginUiActionParamsDtoFromJson(json);
}

@freezed
/// Selects one read-only view of the skill catalog.
abstract class SkillListParamsDto with _$SkillListParamsDto {
  /// Creates skill list parameters.
  const factory SkillListParamsDto({
    required SkillListView view,
    String? workspaceId,
  }) = _SkillListParamsDto;

  /// Decodes skill list parameters.
  factory SkillListParamsDto.fromJson(Map<String, dynamic> json) =>
      _$SkillListParamsDtoFromJson(json);
}

@freezed
/// Parameters for connecting a built-in provider with an API key.
abstract class ProviderConnectApiKeyParamsDto
    with _$ProviderConnectApiKeyParamsDto {
  /// Creates API-key connection parameters.
  const factory ProviderConnectApiKeyParamsDto({
    required String definitionId,
    required String apiKey,
    String? connectionId,
    String? modelPrefix,
  }) = _ProviderConnectApiKeyParamsDto;

  /// Decodes API-key connection parameters.
  factory ProviderConnectApiKeyParamsDto.fromJson(Map<String, dynamic> json) =>
      _$ProviderConnectApiKeyParamsDtoFromJson(json);
}

@freezed
/// Parameters for connecting a provider that needs no credentials.
abstract class ProviderConnectNoneParamsDto
    with _$ProviderConnectNoneParamsDto {
  /// Creates no-auth connection parameters.
  const factory ProviderConnectNoneParamsDto({
    required String definitionId,
    String? connectionId,
    String? modelPrefix,
  }) = _ProviderConnectNoneParamsDto;

  /// Decodes no-auth connection parameters.
  factory ProviderConnectNoneParamsDto.fromJson(Map<String, dynamic> json) =>
      _$ProviderConnectNoneParamsDtoFromJson(json);
}

@freezed
/// Parameters identifying one provider connection.
abstract class ProviderConnectionIdParamsDto
    with _$ProviderConnectionIdParamsDto {
  /// Creates provider connection identifier parameters.
  const factory ProviderConnectionIdParamsDto({required String connectionId}) =
      _ProviderConnectionIdParamsDto;

  /// Decodes provider connection identifier parameters.
  factory ProviderConnectionIdParamsDto.fromJson(Map<String, dynamic> json) =>
      _$ProviderConnectionIdParamsDtoFromJson(json);
}

@freezed
/// ProviderModelParamsDto defines a public contract.
abstract class ProviderModelParamsDto with _$ProviderModelParamsDto {
  /// The ProviderModelParamsDto public API member.
  const factory ProviderModelParamsDto({
    required String connectionId,
    required String modelId,
  }) = _ProviderModelParamsDto;

  /// Creates a [ProviderModelParamsDto].
  factory ProviderModelParamsDto.fromJson(Map<String, dynamic> json) =>
      _$ProviderModelParamsDtoFromJson(json);
}

@freezed
/// Parameters for starting a provider OAuth flow.
abstract class ProviderAuthStartParamsDto with _$ProviderAuthStartParamsDto {
  /// Creates OAuth start parameters.
  const factory ProviderAuthStartParamsDto({
    required String definitionId,
    required String methodId,
    String? connectionId,
    String? modelPrefix,
  }) = _ProviderAuthStartParamsDto;

  /// Decodes OAuth start parameters.
  factory ProviderAuthStartParamsDto.fromJson(Map<String, dynamic> json) =>
      _$ProviderAuthStartParamsDtoFromJson(json);
}

/// Parameters for changing a provider connection's model prefix.
@freezed
abstract class ProviderPrefixUpdateParamsDto
    with _$ProviderPrefixUpdateParamsDto {
  /// Creates model-prefix update parameters.
  const factory ProviderPrefixUpdateParamsDto({
    required String connectionId,
    required String modelPrefix,
  }) = _ProviderPrefixUpdateParamsDto;

  /// Decodes model-prefix update parameters.
  factory ProviderPrefixUpdateParamsDto.fromJson(Map<String, dynamic> json) =>
      _$ProviderPrefixUpdateParamsDtoFromJson(json);
}

@freezed
/// Parameters identifying a provider authorization attempt.
abstract class ProviderAuthAttemptParamsDto
    with _$ProviderAuthAttemptParamsDto {
  /// Creates authorization attempt parameters.
  const factory ProviderAuthAttemptParamsDto({required String attemptId}) =
      _ProviderAuthAttemptParamsDto;

  /// Decodes authorization attempt parameters.
  factory ProviderAuthAttemptParamsDto.fromJson(Map<String, dynamic> json) =>
      _$ProviderAuthAttemptParamsDtoFromJson(json);
}

@freezed
/// Parameters for creating an advanced custom provider connection.
abstract class ProviderCustomCreateParamsDto
    with _$ProviderCustomCreateParamsDto {
  /// Creates custom provider parameters.
  const factory ProviderCustomCreateParamsDto({
    required String id,
    required CustomProviderConfigDto config,
    String? apiKey,
    String? modelPrefix,
  }) = _ProviderCustomCreateParamsDto;

  /// Decodes custom provider parameters.
  factory ProviderCustomCreateParamsDto.fromJson(Map<String, dynamic> json) =>
      _$ProviderCustomCreateParamsDtoFromJson(json);
}

@freezed
/// Parameters for updating an advanced custom provider connection.
abstract class ProviderCustomUpdateParamsDto
    with _$ProviderCustomUpdateParamsDto {
  /// Creates custom provider update parameters.
  const factory ProviderCustomUpdateParamsDto({
    required String connectionId,
    required CustomProviderConfigDto config,
    String? apiKey,
  }) = _ProviderCustomUpdateParamsDto;

  /// Decodes custom provider update parameters.
  factory ProviderCustomUpdateParamsDto.fromJson(Map<String, dynamic> json) =>
      _$ProviderCustomUpdateParamsDtoFromJson(json);
}

@freezed
/// TurnStartParamsDto defines a public contract.
abstract class TurnStartParamsDto with _$TurnStartParamsDto {
  /// The TurnStartParamsDto public API member.
  const factory TurnStartParamsDto({
    required String sessionId,
    required String turnId,
    required String prompt,
    @Default(<String>[]) List<String> attachmentIds,
  }) = _TurnStartParamsDto;

  /// Creates a [TurnStartParamsDto].
  factory TurnStartParamsDto.fromJson(Map<String, dynamic> json) =>
      _$TurnStartParamsDtoFromJson(json);
}

@freezed
/// Identifies one session.
abstract class SessionIdParamsDto with _$SessionIdParamsDto {
  /// Creates session identifier parameters.
  const factory SessionIdParamsDto({required String sessionId}) =
      _SessionIdParamsDto;

  /// Decodes session identifier parameters.
  factory SessionIdParamsDto.fromJson(Map<String, dynamic> json) =>
      _$SessionIdParamsDtoFromJson(json);
}

@freezed
/// ApprovalResolveParamsDto defines a public contract.
abstract class ApprovalResolveParamsDto with _$ApprovalResolveParamsDto {
  /// The ApprovalResolveParamsDto public API member.
  const factory ApprovalResolveParamsDto({
    required String approvalId,
    required bool approved,
  }) = _ApprovalResolveParamsDto;

  /// Creates a [ApprovalResolveParamsDto].
  factory ApprovalResolveParamsDto.fromJson(Map<String, dynamic> json) =>
      _$ApprovalResolveParamsDtoFromJson(json);
}

@freezed
/// Announces that the client has a prompt waiting for one session.
abstract class SessionPendingInputParamsDto
    with _$SessionPendingInputParamsDto {
  /// Creates a [SessionPendingInputParamsDto].
  const factory SessionPendingInputParamsDto({required String sessionId}) =
      _SessionPendingInputParamsDto;

  /// Decodes a [SessionPendingInputParamsDto].
  factory SessionPendingInputParamsDto.fromJson(Map<String, dynamic> json) =>
      _$SessionPendingInputParamsDtoFromJson(json);
}

@freezed
/// Answers to every question of one pending [UserQuestionRequestDto].
abstract class UserQuestionAnswerParamsDto with _$UserQuestionAnswerParamsDto {
  /// The UserQuestionAnswerParamsDto public API member.
  const factory UserQuestionAnswerParamsDto({
    required String requestId,
    required List<UserQuestionAnswerDto> answers,
  }) = _UserQuestionAnswerParamsDto;

  /// Creates a [UserQuestionAnswerParamsDto].
  factory UserQuestionAnswerParamsDto.fromJson(Map<String, dynamic> json) =>
      _$UserQuestionAnswerParamsDtoFromJson(json);
}

@freezed
/// TimelineSubscribeParamsDto defines a public contract.
abstract class TimelineSubscribeParamsDto with _$TimelineSubscribeParamsDto {
  /// The TimelineSubscribeParamsDto public API member.
  ///
  /// A non-null [tailLimit] asks for only the newest events instead of the
  /// whole history. It is optional because an unbounded subscribe is still the
  /// right request for a caller that wants everything, such as the reconnect
  /// catch-up that resumes from the last sequence it already saw.
  const factory TimelineSubscribeParamsDto({
    required String sessionId,
    required int afterSequence,
    int? tailLimit,
  }) = _TimelineSubscribeParamsDto;

  /// Creates a [TimelineSubscribeParamsDto].
  factory TimelineSubscribeParamsDto.fromJson(Map<String, dynamic> json) =>
      _$TimelineSubscribeParamsDtoFromJson(json);
}

@freezed
/// Request for the page of timeline history preceding a known sequence.
///
/// This is a pure read. It deliberately does not go through
/// `sessions.subscribeTimeline`, whose parameters double as the live-delivery
/// cursor: rewinding that cursor to fetch older events would drop every event
/// the daemon emitted during the round trip.
abstract class TimelineHistoryParamsDto with _$TimelineHistoryParamsDto {
  /// Creates a timeline history request.
  const factory TimelineHistoryParamsDto({
    required String sessionId,
    required int beforeSequence,
    required int limit,
  }) = _TimelineHistoryParamsDto;

  /// Creates a [TimelineHistoryParamsDto].
  factory TimelineHistoryParamsDto.fromJson(Map<String, dynamic> json) =>
      _$TimelineHistoryParamsDtoFromJson(json);
}

@freezed
/// Result containing an atomic workspace catalog.
abstract class WorkspaceCatalogResultDto with _$WorkspaceCatalogResultDto {
  /// Creates a workspace catalog result.
  const factory WorkspaceCatalogResultDto({
    required WorkspaceCatalogDto catalog,
  }) = _WorkspaceCatalogResultDto;

  /// Decodes a workspace catalog result.
  factory WorkspaceCatalogResultDto.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceCatalogResultDtoFromJson(json);
}

@freezed
/// Result of registering one workspace and its discovered checkouts.
abstract class WorkspaceRegisterResultDto with _$WorkspaceRegisterResultDto {
  /// Creates a workspace registration result.
  const factory WorkspaceRegisterResultDto({
    required WorkspaceDto workspace,
    required List<WorktreeDto> worktrees,
  }) = _WorkspaceRegisterResultDto;

  /// Decodes a workspace registration result.
  factory WorkspaceRegisterResultDto.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceRegisterResultDtoFromJson(json);
}

@freezed
/// Boolean result for unregistering a workspace.
abstract class WorkspaceUnregisterResultDto
    with _$WorkspaceUnregisterResultDto {
  /// Creates an unregister result.
  const factory WorkspaceUnregisterResultDto({required bool unregistered}) =
      _WorkspaceUnregisterResultDto;

  /// Decodes an unregister result.
  factory WorkspaceUnregisterResultDto.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceUnregisterResultDtoFromJson(json);
}

@freezed
/// Result of daemon-side directory search.
abstract class DirectorySuggestResultDto with _$DirectorySuggestResultDto {
  /// Creates directory suggestions.
  const factory DirectorySuggestResultDto({
    required List<DirectorySuggestionDto> suggestions,
  }) = _DirectorySuggestResultDto;

  /// Decodes directory suggestions.
  factory DirectorySuggestResultDto.fromJson(Map<String, dynamic> json) =>
      _$DirectorySuggestResultDtoFromJson(json);
}

@freezed
/// Result of a worktree file search.
abstract class FileSearchResultDto with _$FileSearchResultDto {
  /// Creates file matches.
  ///
  /// [truncated] reports that indexing stopped at its entry budget, so the
  /// worktree holds files this search could never rank.
  const factory FileSearchResultDto({
    required List<FileMatchDto> matches,
    @Default(false) bool truncated,
  }) = _FileSearchResultDto;

  /// Decodes file matches.
  factory FileSearchResultDto.fromJson(Map<String, dynamic> json) =>
      _$FileSearchResultDtoFromJson(json);
}

@freezed
/// Result containing local Git branches.
abstract class GitBranchesListResultDto with _$GitBranchesListResultDto {
  /// Creates a branch-list result.
  const factory GitBranchesListResultDto({
    required List<GitBranchDto> branches,
  }) = _GitBranchesListResultDto;

  /// Decodes a branch-list result.
  factory GitBranchesListResultDto.fromJson(Map<String, dynamic> json) =>
      _$GitBranchesListResultDtoFromJson(json);
}

@freezed
/// Result containing one worktree and the lifecycle hooks it ran.
abstract class WorktreeResultDto with _$WorktreeResultDto {
  /// Creates a worktree result.
  const factory WorktreeResultDto({
    required WorktreeDto worktree,
    @Default(<WorktreeHookRunDto>[]) List<WorktreeHookRunDto> hookRuns,
  }) = _WorktreeResultDto;

  /// Decodes a worktree result.
  factory WorktreeResultDto.fromJson(Map<String, dynamic> json) =>
      _$WorktreeResultDtoFromJson(json);
}

@freezed
/// Requests the `.tinest/config.json` settings of one registered workspace.
abstract class ProjectSettingsGetParamsDto with _$ProjectSettingsGetParamsDto {
  /// Creates project settings read parameters.
  const factory ProjectSettingsGetParamsDto({required String workspaceId}) =
      _ProjectSettingsGetParamsDto;

  /// Decodes project settings read parameters.
  factory ProjectSettingsGetParamsDto.fromJson(Map<String, dynamic> json) =>
      _$ProjectSettingsGetParamsDtoFromJson(json);
}

@freezed
/// Replaces the worktree hook section of one workspace's `.tinest/config.json`.
abstract class ProjectSettingsSaveParamsDto
    with _$ProjectSettingsSaveParamsDto {
  /// Creates project settings write parameters.
  const factory ProjectSettingsSaveParamsDto({
    required String workspaceId,
    required ProjectSettingsDto settings,
  }) = _ProjectSettingsSaveParamsDto;

  /// Decodes project settings write parameters.
  factory ProjectSettingsSaveParamsDto.fromJson(Map<String, dynamic> json) =>
      _$ProjectSettingsSaveParamsDtoFromJson(json);
}

@freezed
/// Result containing project settings and the file backing them.
abstract class ProjectSettingsResultDto with _$ProjectSettingsResultDto {
  /// Creates a project settings result.
  const factory ProjectSettingsResultDto({
    required ProjectSettingsDto settings,
    required String sourcePath,
  }) = _ProjectSettingsResultDto;

  /// Decodes a project settings result.
  factory ProjectSettingsResultDto.fromJson(Map<String, dynamic> json) =>
      _$ProjectSettingsResultDtoFromJson(json);
}

@freezed
/// Result containing archive risk information.
abstract class WorktreeArchivePreviewResultDto
    with _$WorktreeArchivePreviewResultDto {
  /// Creates an archive preview result.
  const factory WorktreeArchivePreviewResultDto({
    required WorktreeArchivePreviewDto preview,
  }) = _WorktreeArchivePreviewResultDto;

  /// Decodes an archive preview result.
  factory WorktreeArchivePreviewResultDto.fromJson(Map<String, dynamic> json) =>
      _$WorktreeArchivePreviewResultDtoFromJson(json);
}

@freezed
/// Returns sessions visible in a worktree.
abstract class SessionListResultDto with _$SessionListResultDto {
  /// Creates a session list result.
  const factory SessionListResultDto({required List<SessionDto> sessions}) =
      _SessionListResultDto;

  /// Decodes a session list result.
  factory SessionListResultDto.fromJson(Map<String, dynamic> json) =>
      _$SessionListResultDtoFromJson(json);
}

@freezed
/// Returns one session.
abstract class SessionResultDto with _$SessionResultDto {
  /// Creates a session result.
  const factory SessionResultDto({required SessionDto session}) =
      _SessionResultDto;

  /// Decodes a session result.
  factory SessionResultDto.fromJson(Map<String, dynamic> json) =>
      _$SessionResultDtoFromJson(json);
}

@freezed
/// Requests live terminals for a worktree.
abstract class TerminalListParamsDto with _$TerminalListParamsDto {
  /// Creates terminal-list parameters.
  const factory TerminalListParamsDto({required String worktreeId}) =
      _TerminalListParamsDto;

  /// Decodes terminal-list parameters.
  factory TerminalListParamsDto.fromJson(Map<String, dynamic> json) =>
      _$TerminalListParamsDtoFromJson(json);
}

@freezed
/// Returns live terminals for a worktree.
abstract class TerminalListResultDto with _$TerminalListResultDto {
  /// Creates a terminal-list result.
  const factory TerminalListResultDto({required List<TerminalDto> terminals}) =
      _TerminalListResultDto;

  /// Decodes a terminal-list result.
  factory TerminalListResultDto.fromJson(Map<String, dynamic> json) =>
      _$TerminalListResultDtoFromJson(json);
}

@freezed
/// Parameters used to start a terminal.
abstract class TerminalCreateParamsDto with _$TerminalCreateParamsDto {
  /// Creates terminal-create parameters.
  const factory TerminalCreateParamsDto({
    required String id,
    required String worktreeId,
    required String title,
    required int columns,
    required int rows,
  }) = _TerminalCreateParamsDto;

  /// Decodes terminal-create parameters.
  factory TerminalCreateParamsDto.fromJson(Map<String, dynamic> json) =>
      _$TerminalCreateParamsDtoFromJson(json);
}

@freezed
/// Identifies one terminal.
abstract class TerminalIdParamsDto with _$TerminalIdParamsDto {
  /// Creates terminal identifier parameters.
  const factory TerminalIdParamsDto({required String terminalId}) =
      _TerminalIdParamsDto;

  /// Decodes terminal identifier parameters.
  factory TerminalIdParamsDto.fromJson(Map<String, dynamic> json) =>
      _$TerminalIdParamsDtoFromJson(json);
}

/// How much history an attaching client needs rebuilt.
enum TerminalRestoreMode {
  /// Continue the byte stream after a cursor.
  ///
  /// The daemon substitutes a snapshot when it no longer retains output that
  /// far back, so a client asking to resume must still handle either answer.
  resume,

  /// Rebuild from the daemon's screen model regardless of what it retains.
  snapshot,
}

@freezed
/// Cell geometry an attaching client is claiming for the pseudo-terminal.
abstract class TerminalViewportDto with _$TerminalViewportDto {
  /// Creates a viewport claim.
  const factory TerminalViewportDto({required int columns, required int rows}) =
      _TerminalViewportDto;

  /// Decodes a viewport claim.
  factory TerminalViewportDto.fromJson(Map<String, dynamic> json) =>
      _$TerminalViewportDtoFromJson(json);
}

@freezed
/// Requests a restore while attaching to a terminal.
abstract class TerminalAttachParamsDto with _$TerminalAttachParamsDto {
  /// Creates terminal-attach parameters.
  const factory TerminalAttachParamsDto({
    required String terminalId,
    required TerminalRestoreMode mode,
    @Default(0) int afterSequence,
    @Default(terminalRestoreScrollbackLines) int scrollbackLines,

    /// Null for a passive attach, which must not claim the terminal's size.
    ///
    /// Only a viewport the user genuinely changed or focused claims the size.
    /// Attaching, restoring visibility, and a renderer settling are not that,
    /// and a claim from one would fight every other attached client.
    TerminalViewportDto? viewport,
  }) = _TerminalAttachParamsDto;

  /// Decodes terminal-attach parameters.
  factory TerminalAttachParamsDto.fromJson(Map<String, dynamic> json) =>
      _$TerminalAttachParamsDtoFromJson(json);
}

/// Scrollback lines an attaching client asks the daemon to rebuild.
const int terminalRestoreScrollbackLines = 200;

@Freezed(unionKey: 'type')
/// What the daemon sends an attaching client to make it current.
sealed class TerminalRestoreDto with _$TerminalRestoreDto {
  /// Retained output continuing [afterSequence], which the client writes as-is.
  const factory TerminalRestoreDto.delta({
    required int afterSequence,
    required List<TerminalOutputDto> chunks,
  }) = TerminalDeltaRestoreDto;

  /// A rebuilt screen.
  ///
  /// [ansi] reproduces every chunk at or below [throughSequence] in a reset
  /// terminal, including the alternate buffer and the DEC private modes, so a
  /// client resets, writes it, and resumes its cursor at [throughSequence].
  const factory TerminalRestoreDto.snapshot({
    required int throughSequence,
    required String ansi,
  }) = TerminalSnapshotRestoreDto;

  /// Decodes a restore.
  factory TerminalRestoreDto.fromJson(Map<String, dynamic> json) =>
      _$TerminalRestoreDtoFromJson(json);
}

@freezed
/// Terminal metadata and the restore that makes an attaching client current.
abstract class TerminalAttachResultDto with _$TerminalAttachResultDto {
  /// Creates a terminal-attach result.
  const factory TerminalAttachResultDto({
    required TerminalDto terminal,
    required TerminalRestoreDto restore,
  }) = _TerminalAttachResultDto;

  /// Decodes a terminal-attach result.
  factory TerminalAttachResultDto.fromJson(Map<String, dynamic> json) =>
      _$TerminalAttachResultDtoFromJson(json);
}

@freezed
/// Returns one terminal.
abstract class TerminalResultDto with _$TerminalResultDto {
  /// Creates a terminal result.
  const factory TerminalResultDto({required TerminalDto terminal}) =
      _TerminalResultDto;

  /// Decodes a terminal result.
  factory TerminalResultDto.fromJson(Map<String, dynamic> json) =>
      _$TerminalResultDtoFromJson(json);
}

@freezed
/// Terminal input parameters.
abstract class TerminalWriteParamsDto with _$TerminalWriteParamsDto {
  /// Creates terminal-write parameters.
  const factory TerminalWriteParamsDto({
    required String terminalId,
    required String data,
  }) = _TerminalWriteParamsDto;

  /// Decodes terminal-write parameters.
  factory TerminalWriteParamsDto.fromJson(Map<String, dynamic> json) =>
      _$TerminalWriteParamsDtoFromJson(json);
}

@freezed
/// Terminal resize parameters.
abstract class TerminalResizeParamsDto with _$TerminalResizeParamsDto {
  /// Creates terminal-resize parameters.
  const factory TerminalResizeParamsDto({
    required String terminalId,
    required int columns,
    required int rows,
  }) = _TerminalResizeParamsDto;

  /// Decodes terminal-resize parameters.
  factory TerminalResizeParamsDto.fromJson(Map<String, dynamic> json) =>
      _$TerminalResizeParamsDtoFromJson(json);
}

@freezed
/// Reads or writes the optional daemon-host shell override.
abstract class TerminalShellDto with _$TerminalShellDto {
  /// Creates a terminal-shell payload.
  const factory TerminalShellDto({ShellSpecDto? shell}) = _TerminalShellDto;

  /// Decodes a terminal-shell payload.
  factory TerminalShellDto.fromJson(Map<String, dynamic> json) =>
      _$TerminalShellDtoFromJson(json);
}

@freezed
/// Daemon-global permission defaults.
abstract class PermissionSettingsDto with _$PermissionSettingsDto {
  /// Creates daemon-global permission settings.
  const factory PermissionSettingsDto({
    @Default(PermissionMode.ask) PermissionMode defaultMode,
  }) = _PermissionSettingsDto;

  /// Decodes daemon-global permission settings.
  factory PermissionSettingsDto.fromJson(Map<String, dynamic> json) =>
      _$PermissionSettingsDtoFromJson(json);
}

@freezed
/// Daemon-owned model settings.
abstract class DaemonModelSettingsDto with _$DaemonModelSettingsDto {
  /// Creates daemon model settings.
  const factory DaemonModelSettingsDto({ModelSelectionDto? defaultModel}) =
      _DaemonModelSettingsDto;

  /// Decodes daemon model settings.
  factory DaemonModelSettingsDto.fromJson(Map<String, dynamic> json) =>
      _$DaemonModelSettingsDtoFromJson(json);
}

@freezed
/// Replaces the daemon default with one concrete model.
abstract class SetDaemonDefaultModelParamsDto
    with _$SetDaemonDefaultModelParamsDto {
  /// Creates daemon-default update parameters.
  const factory SetDaemonDefaultModelParamsDto({
    required ModelSelectionDto model,
  }) = _SetDaemonDefaultModelParamsDto;

  /// Decodes daemon-default update parameters.
  factory SetDaemonDefaultModelParamsDto.fromJson(Map<String, dynamic> json) =>
      _$SetDaemonDefaultModelParamsDtoFromJson(json);
}

@freezed
/// Returns agent definitions and source diagnostics.
abstract class AgentDefinitionListResultDto
    with _$AgentDefinitionListResultDto {
  /// Creates an agent definition list result.
  const factory AgentDefinitionListResultDto({
    required List<AgentDefinitionDto> definitions,
  }) = _AgentDefinitionListResultDto;

  /// Decodes an agent definition list result.
  factory AgentDefinitionListResultDto.fromJson(Map<String, dynamic> json) =>
      _$AgentDefinitionListResultDtoFromJson(json);
}

@freezed
/// Returns one agent definition.
abstract class AgentDefinitionResultDto with _$AgentDefinitionResultDto {
  /// Creates an agent definition result.
  const factory AgentDefinitionResultDto({
    required AgentDefinitionDto definition,
  }) = _AgentDefinitionResultDto;

  /// Decodes an agent definition result.
  factory AgentDefinitionResultDto.fromJson(Map<String, dynamic> json) =>
      _$AgentDefinitionResultDtoFromJson(json);
}

@freezed
/// Returns the installed built-in and user plugin catalog.
abstract class PluginListResultDto with _$PluginListResultDto {
  /// Creates a plugin catalog result.
  const factory PluginListResultDto({
    required List<PluginDescriptorDto> plugins,
  }) = _PluginListResultDto;

  /// Decodes a plugin catalog result.
  factory PluginListResultDto.fromJson(Map<String, dynamic> json) =>
      _$PluginListResultDtoFromJson(json);
}

@freezed
/// Returns one validated plugin descriptor.
abstract class PluginResultDto with _$PluginResultDto {
  /// Creates a plugin result.
  const factory PluginResultDto({required PluginDescriptorDto plugin}) =
      _PluginResultDto;

  /// Decodes a plugin result.
  factory PluginResultDto.fromJson(Map<String, dynamic> json) =>
      _$PluginResultDtoFromJson(json);
}

@freezed
/// Returns one plugin's editor-neutral Lua authoring environment.
abstract class PluginAuthoringEnvironmentResultDto
    with _$PluginAuthoringEnvironmentResultDto {
  /// Creates an authoring environment result.
  const factory PluginAuthoringEnvironmentResultDto({
    required PluginAuthoringEnvironmentDto environment,
  }) = _PluginAuthoringEnvironmentResultDto;

  /// Decodes an authoring environment result.
  factory PluginAuthoringEnvironmentResultDto.fromJson(
    Map<String, dynamic> json,
  ) => _$PluginAuthoringEnvironmentResultDtoFromJson(json);
}

@freezed
/// Returns every capability grant owned by one Agent.
abstract class PluginGrantListResultDto with _$PluginGrantListResultDto {
  /// Creates an Agent grant list result.
  const factory PluginGrantListResultDto({
    required List<AgentPluginGrantDto> grants,
  }) = _PluginGrantListResultDto;

  /// Decodes an Agent grant list result.
  factory PluginGrantListResultDto.fromJson(Map<String, dynamic> json) =>
      _$PluginGrantListResultDtoFromJson(json);
}

@freezed
/// Returns one normalized plugin session-control value.
abstract class PluginSessionControlResultDto
    with _$PluginSessionControlResultDto {
  /// Creates a session-control result.
  const factory PluginSessionControlResultDto({
    required PluginSessionControlValueDto control,
  }) = _PluginSessionControlResultDto;

  /// Decodes a session-control result.
  factory PluginSessionControlResultDto.fromJson(Map<String, dynamic> json) =>
      _$PluginSessionControlResultDtoFromJson(json);
}

@freezed
/// Returns one declarative UI document snapshot.
abstract class PluginUiDocumentResultDto with _$PluginUiDocumentResultDto {
  /// Creates a UI document result.
  const factory PluginUiDocumentResultDto({
    required PluginUiDocumentDto document,
  }) = _PluginUiDocumentResultDto;

  /// Decodes a UI document result.
  factory PluginUiDocumentResultDto.fromJson(Map<String, dynamic> json) =>
      _$PluginUiDocumentResultDtoFromJson(json);
}

@freezed
/// Scopes an agent tool catalog request to one worktree.
abstract class AgentToolCatalogParamsDto with _$AgentToolCatalogParamsDto {
  /// Creates agent tool catalog parameters.
  const factory AgentToolCatalogParamsDto({String? worktreeId}) =
      _AgentToolCatalogParamsDto;

  /// Decodes agent tool catalog parameters.
  factory AgentToolCatalogParamsDto.fromJson(Map<String, dynamic> json) =>
      _$AgentToolCatalogParamsDtoFromJson(json);
}

@freezed
/// Scopes an MCP server listing to one worktree.
abstract class McpServersParamsDto with _$McpServersParamsDto {
  /// Creates MCP server listing parameters.
  const factory McpServersParamsDto({String? worktreeId}) =
      _McpServersParamsDto;

  /// Decodes MCP server listing parameters.
  factory McpServersParamsDto.fromJson(Map<String, dynamic> json) =>
      _$McpServersParamsDtoFromJson(json);
}

@freezed
/// Returns every configured MCP server and its state.
abstract class McpServersResultDto with _$McpServersResultDto {
  /// Creates an MCP server listing result.
  const factory McpServersResultDto({
    required List<McpServerStateDto> servers,
  }) = _McpServersResultDto;

  /// Decodes an MCP server listing result.
  factory McpServersResultDto.fromJson(Map<String, dynamic> json) =>
      _$McpServersResultDtoFromJson(json);
}

@freezed
/// Carries one MCP server configuration.
abstract class McpServerParamsDto with _$McpServerParamsDto {
  /// Creates MCP server parameters.
  const factory McpServerParamsDto({required McpServerConfigDto server}) =
      _McpServerParamsDto;

  /// Decodes MCP server parameters.
  factory McpServerParamsDto.fromJson(Map<String, dynamic> json) =>
      _$McpServerParamsDtoFromJson(json);
}

@freezed
/// Identifies one configured MCP server.
abstract class McpServerIdParamsDto with _$McpServerIdParamsDto {
  /// Creates MCP server id parameters.
  const factory McpServerIdParamsDto({required String id}) =
      _McpServerIdParamsDto;

  /// Decodes MCP server id parameters.
  factory McpServerIdParamsDto.fromJson(Map<String, dynamic> json) =>
      _$McpServerIdParamsDtoFromJson(json);
}

@freezed
/// Returns one MCP server's state.
abstract class McpServerStateResultDto with _$McpServerStateResultDto {
  /// Creates an MCP server state result.
  const factory McpServerStateResultDto({required McpServerStateDto state}) =
      _McpServerStateResultDto;

  /// Decodes an MCP server state result.
  factory McpServerStateResultDto.fromJson(Map<String, dynamic> json) =>
      _$McpServerStateResultDtoFromJson(json);
}

@freezed
/// Stores one secret an MCP configuration may reference.
abstract class McpSecretParamsDto with _$McpSecretParamsDto {
  /// Creates MCP secret parameters.
  const factory McpSecretParamsDto({
    required String key,
    required String value,
  }) = _McpSecretParamsDto;

  /// Decodes MCP secret parameters.
  factory McpSecretParamsDto.fromJson(Map<String, dynamic> json) =>
      _$McpSecretParamsDtoFromJson(json);
}

@freezed
/// Returns the daemon's agent tool catalog.
abstract class AgentToolCatalogResultDto with _$AgentToolCatalogResultDto {
  /// Creates an agent tool catalog result.
  const factory AgentToolCatalogResultDto({
    required List<AgentToolDefinitionDto> tools,
  }) = _AgentToolCatalogResultDto;

  /// Decodes an agent tool catalog result.
  factory AgentToolCatalogResultDto.fromJson(Map<String, dynamic> json) =>
      _$AgentToolCatalogResultDtoFromJson(json);
}

@freezed
/// Returns every skill visible in one scope.
abstract class SkillListResultDto with _$SkillListResultDto {
  /// Creates a skill list result.
  const factory SkillListResultDto({required List<SkillSummaryDto> skills}) =
      _SkillListResultDto;

  /// Decodes a skill list result.
  factory SkillListResultDto.fromJson(Map<String, dynamic> json) =>
      _$SkillListResultDtoFromJson(json);
}

@freezed
/// Returns every agent command visible in one scope.
abstract class CommandListResultDto with _$CommandListResultDto {
  /// Creates a command list result.
  const factory CommandListResultDto({
    required List<AgentCommandDto> commands,
  }) = _CommandListResultDto;

  /// Decodes a command list result.
  factory CommandListResultDto.fromJson(Map<String, dynamic> json) =>
      _$CommandListResultDtoFromJson(json);
}

@freezed
/// ProviderCatalogResultDto defines a public contract.
abstract class ProviderCatalogResultDto with _$ProviderCatalogResultDto {
  /// The ProviderCatalogResultDto public API member.
  const factory ProviderCatalogResultDto({
    required ProviderCatalogDto catalog,
  }) = _ProviderCatalogResultDto;

  /// Creates a [ProviderCatalogResultDto].
  factory ProviderCatalogResultDto.fromJson(Map<String, dynamic> json) =>
      _$ProviderCatalogResultDtoFromJson(json);
}

@freezed
/// Result containing all configured provider connections.
abstract class ProviderConnectionsResultDto
    with _$ProviderConnectionsResultDto {
  /// Creates a provider connections result.
  const factory ProviderConnectionsResultDto({
    required List<ProviderConnectionDto> connections,
  }) = _ProviderConnectionsResultDto;

  /// Decodes a provider connections result.
  factory ProviderConnectionsResultDto.fromJson(Map<String, dynamic> json) =>
      _$ProviderConnectionsResultDtoFromJson(json);
}

@freezed
/// Result containing quota usage for configured provider connections.
abstract class ProviderUsageResultDto with _$ProviderUsageResultDto {
  /// Creates a provider usage result.
  const factory ProviderUsageResultDto({
    required List<ProviderUsageDto> usage,
  }) = _ProviderUsageResultDto;

  /// Decodes a provider usage result.
  factory ProviderUsageResultDto.fromJson(Map<String, dynamic> json) =>
      _$ProviderUsageResultDtoFromJson(json);
}

@freezed
/// Result containing one configured provider connection.
abstract class ProviderConnectionResultDto with _$ProviderConnectionResultDto {
  /// Creates a provider connection result.
  const factory ProviderConnectionResultDto({
    required ProviderConnectionDto connection,
  }) = _ProviderConnectionResultDto;

  /// Decodes a provider connection result.
  factory ProviderConnectionResultDto.fromJson(Map<String, dynamic> json) =>
      _$ProviderConnectionResultDtoFromJson(json);
}

@freezed
/// ProviderModelsResultDto defines a public contract.
abstract class ProviderModelsResultDto with _$ProviderModelsResultDto {
  /// The ProviderModelsResultDto public API member.
  const factory ProviderModelsResultDto({
    required List<ProviderModelDto> models,
  }) = _ProviderModelsResultDto;

  /// Creates a [ProviderModelsResultDto].
  factory ProviderModelsResultDto.fromJson(Map<String, dynamic> json) =>
      _$ProviderModelsResultDtoFromJson(json);
}

@freezed
/// Result containing one provider authorization attempt.
abstract class ProviderAuthAttemptResultDto
    with _$ProviderAuthAttemptResultDto {
  /// Creates an authorization attempt result.
  const factory ProviderAuthAttemptResultDto({
    required ProviderAuthAttemptDto attempt,
  }) = _ProviderAuthAttemptResultDto;

  /// Decodes an authorization attempt result.
  factory ProviderAuthAttemptResultDto.fromJson(Map<String, dynamic> json) =>
      _$ProviderAuthAttemptResultDtoFromJson(json);
}

@freezed
/// ProviderDiagnosticResultDto defines a public contract.
abstract class ProviderDiagnosticResultDto with _$ProviderDiagnosticResultDto {
  /// The ProviderDiagnosticResultDto public API member.
  const factory ProviderDiagnosticResultDto({
    required ProviderDiagnosticDto diagnostic,
  }) = _ProviderDiagnosticResultDto;

  /// Creates a [ProviderDiagnosticResultDto].
  factory ProviderDiagnosticResultDto.fromJson(Map<String, dynamic> json) =>
      _$ProviderDiagnosticResultDtoFromJson(json);
}

@freezed
/// TurnStartResultDto defines a public contract.
abstract class TurnStartResultDto with _$TurnStartResultDto {
  /// The TurnStartResultDto public API member.
  const factory TurnStartResultDto({required bool created}) =
      _TurnStartResultDto;

  /// Creates a [TurnStartResultDto].
  factory TurnStartResultDto.fromJson(Map<String, dynamic> json) =>
      _$TurnStartResultDtoFromJson(json);
}

@freezed
/// ApprovalResultDto defines a public contract.
abstract class ApprovalResultDto with _$ApprovalResultDto {
  /// The ApprovalResultDto public API member.
  const factory ApprovalResultDto({required ApprovalRequestDto approval}) =
      _ApprovalResultDto;

  /// Creates a [ApprovalResultDto].
  factory ApprovalResultDto.fromJson(Map<String, dynamic> json) =>
      _$ApprovalResultDtoFromJson(json);
}

@freezed
/// The resolved question returned by an answer call.
abstract class UserQuestionResultDto with _$UserQuestionResultDto {
  /// The UserQuestionResultDto public API member.
  const factory UserQuestionResultDto({
    required UserQuestionRequestDto request,
  }) = _UserQuestionResultDto;

  /// Creates a [UserQuestionResultDto].
  factory UserQuestionResultDto.fromJson(Map<String, dynamic> json) =>
      _$UserQuestionResultDtoFromJson(json);
}

@freezed
/// TimelineResultDto defines a public contract.
abstract class TimelineResultDto with _$TimelineResultDto {
  /// The TimelineResultDto public API member.
  const factory TimelineResultDto({required List<TimelineEventDto> events}) =
      _TimelineResultDto;

  /// Creates a [TimelineResultDto].
  factory TimelineResultDto.fromJson(Map<String, dynamic> json) =>
      _$TimelineResultDtoFromJson(json);
}
