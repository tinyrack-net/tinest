import 'package:agent/agent.dart';
import 'package:daemon/src/features/agents/infrastructure/agent_definitions.dart';
import 'package:daemon/src/features/agents/infrastructure/permission_defaults.dart';
import 'package:daemon/src/features/models/infrastructure/model_settings_service.dart';
import 'package:daemon/src/features/providers/infrastructure/provider_service.dart';
import 'package:daemon/src/features/sessions/infrastructure/agent_service.dart';
import 'package:daemon/src/features/sessions/infrastructure/session_interactions.dart';
import 'package:daemon/src/features/sessions/infrastructure/session_settings.dart';
import 'package:daemon/src/shared/infrastructure/persistence/repositories.dart';
import 'package:daemon/src/transport/rpc/binding.dart';
import 'package:protocol/protocol.dart';

/// Builds the session feature's complete v5 RPC surface.
List<RpcBindingDescriptor> sessionRpcBindings({
  required SessionRepository sessions,
  required TimelineRepository timeline,
  required SessionTurnCoordinator turns,
  required SessionSettingsPort settings,
  required SessionInteractionPort interactions,
  required AgentDefinitionService agentDefinitions,
  required ProviderModelResolver models,
  required PermissionDefaults permissions,
  required Clock clock,
}) => <RpcBindingDescriptor>[
  RpcBinding(sessionsListProcedure, (request, _) async {
    return SessionListResultDto(
      sessions: await sessions.list(worktreeId: request.worktreeId),
    );
  }),
  RpcBinding(sessionsListSubagentsProcedure, (request, _) async {
    final session = await sessions.getById(request.sessionId);
    if (session == null) throw const FormatException('Session not found.');
    return SessionListResultDto(
      sessions: await sessions.listByRoot(session.rootSessionId ?? session.id),
    );
  }),
  RpcBinding(sessionsCreateProcedure, (request, _) async {
    try {
      final definition = await agentDefinitions.get(request.agentDefinitionId);
      if (definition.mode != AgentMode.primary ||
          definition.isArchived ||
          definition.isStale) {
        throw RpcFailureException(
          code: RpcErrorCodes.agentDefinitionUnusable,
          message:
              'New sessions require an active primary agent definition, and '
              '"${definition.name}" is not one.',
          details: <String, dynamic>{'agentDefinitionId': definition.id},
        );
      }
      if (request.model case final selected?) {
        await models.validateQualifiedModel(selected.qualifiedModelId);
      } else {
        await models.resolveAgentModel(definition.model);
      }
      final now = clock.nowUtc();
      return SessionResultDto(
        session: await sessions.create(
          SessionDto(
            id: request.id,
            worktreeId: request.worktreeId,
            title: request.title,
            agentDefinitionId: definition.id,
            origin: SessionOrigin.manual,
            status: SessionStatus.idle,
            model: request.model,
            modelControls: request.modelControls,
            // The configured default is read once, here, so the session keeps
            // running under the mode it was created with even after the
            // default changes.
            permissionMode: request.permissionMode ?? await permissions.read(),
            createdAt: now,
            updatedAt: now,
          ),
        ),
      );
    } on ProviderConnectionFailure catch (error) {
      throw RpcFailureException(code: error.code, message: error.message);
    } on ModelSettingsFailure catch (error) {
      throw RpcFailureException(code: error.code, message: error.message);
    } on AgentDefinitionLookupFailure catch (error) {
      throw RpcFailureException(
        code: error.isMissing
            ? RpcErrorCodes.agentDefinitionNotFound
            : RpcErrorCodes.agentDefinitionUnusable,
        message: error.message,
        details: <String, dynamic>{'agentDefinitionId': error.id},
      );
    }
  }),
  RpcBinding(sessionsUpdateSettingsProcedure, (request, _) async {
    try {
      return SessionResultDto(
        session: await settings.updateSettings(
          request.sessionId,
          request.patch,
        ),
      );
    } on SessionTurnActiveFailure catch (error) {
      throw RpcFailureException(
        code: RpcErrorCodes.sessionTurnActive,
        message: error.message,
        details: <String, dynamic>{
          'sessionId': error.sessionId,
          'setting': error.setting,
        },
      );
    } on ProviderConnectionFailure catch (error) {
      throw RpcFailureException(code: error.code, message: error.message);
    }
  }),
  RpcBinding(sessionsStartTurnProcedure, (request, _) async {
    try {
      return TurnStartResultDto(
        created: await turns.startTurn(
          sessionId: request.sessionId,
          turnId: request.turnId,
          prompt: request.prompt,
          attachmentIds: request.attachmentIds,
        ),
      );
    } on ProviderConnectionFailure catch (error) {
      throw RpcFailureException(code: error.code, message: error.message);
    } on ModelSettingsFailure catch (error) {
      throw RpcFailureException(code: error.code, message: error.message);
    } on AgentDefinitionLookupFailure catch (error) {
      throw RpcFailureException(
        code: error.isMissing
            ? RpcErrorCodes.agentDefinitionNotFound
            : RpcErrorCodes.agentDefinitionUnusable,
        message: error.message,
        details: <String, dynamic>{'agentDefinitionId': error.id},
      );
    }
  }),
  RpcBinding(sessionsCancelTurnProcedure, (request, _) async {
    await turns.cancelTurn(request.sessionId);
    return const EmptyResultDto();
  }),
  RpcBinding(sessionsResolveApprovalProcedure, (request, _) async {
    return ApprovalResultDto(
      approval: await interactions.resolveApproval(
        request.approvalId,
        approved: request.approved,
      ),
    );
  }),
  RpcBinding(sessionsNotePendingInputProcedure, (request, _) async {
    interactions.notePendingInput(request.sessionId);
    return const EmptyResultDto();
  }),
  RpcBinding(sessionsAnswerQuestionProcedure, (request, _) async {
    return UserQuestionResultDto(
      request: await interactions.answerUserQuestion(
        request.requestId,
        request.answers,
      ),
    );
  }),
  RpcBinding(sessionsSubscribeTimelineProcedure, (request, context) async {
    context.timelineSubscriptions.add(request.sessionId);
    final tailLimit = request.tailLimit;
    return TimelineResultDto(
      events: tailLimit == null
          ? await timeline.after(request.sessionId, request.afterSequence)
          : await timeline.tail(
              request.sessionId,
              request.afterSequence,
              limit: tailLimit,
            ),
    );
  }),
  // Deliberately does not touch `context.timelineSubscriptions`: that set is
  // also the live delivery cursor, and rewinding it to read history would
  // drop the events arriving during the round trip.
  RpcBinding(sessionsTimelineHistoryProcedure, (request, _) async {
    return TimelineResultDto(
      events: await timeline.before(
        request.sessionId,
        request.beforeSequence,
        limit: request.limit,
      ),
    );
  }),
];
