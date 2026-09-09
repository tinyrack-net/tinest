import 'dart:convert';
import 'dart:math' as math;

import 'package:agent/agent.dart';
import 'package:daemon/src/shared/infrastructure/persistence/database.dart';
import 'package:daemon/src/shared/infrastructure/persistence/repositories.dart';
import 'package:drift/drift.dart';
import 'package:protocol/protocol.dart';

part 'daos.g.dart';

@DriftAccessor(tables: <Type>[Settings])
/// SettingsDao defines a public contract.
class SettingsDao extends DatabaseAccessor<TinestDatabase>
    with _$SettingsDaoMixin
    implements SettingsRepository {
  /// Creates a [SettingsDao].
  new(super.attachedDatabase);

  @override
  Future<String?> getValue(String key) async => (await (select(
    settings,
  )..where((row) => row.key.equals(key))).getSingleOrNull())?.value;

  @override
  Future<void> setValue(String key, String value) => into(settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
}

@DriftAccessor(tables: <Type>[Workspaces, Worktrees])
/// WorkspaceDao defines a public contract.
class WorkspaceDao extends DatabaseAccessor<TinestDatabase>
    with _$WorkspaceDaoMixin
    implements WorkspaceRepository {
  /// Creates a [WorkspaceDao].
  new(super.attachedDatabase);

  @override
  Future<List<WorkspaceDto>> list() async =>
      (await (select(workspaces)
                ..orderBy(<OrderClauseGenerator<$WorkspacesTable>>[
                  (row) => OrderingTerm.asc(row.name),
                ]))
              .get())
          .map(_toDto)
          .toList(growable: false);

  @override
  Future<WorkspaceDto?> getById(String id) async {
    final row = await (select(
      workspaces,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDto(row);
  }

  @override
  Future<WorkspaceDto?> getByRootPath(String rootPath) async {
    final row = await (select(
      workspaces,
    )..where((table) => table.rootPath.equals(rootPath))).getSingleOrNull();
    return row == null ? null : _toDto(row);
  }

  @override
  Future<WorkspaceDto> register(WorkspaceDto workspace) async {
    final existing = await getById(workspace.id);
    if (existing != null) return existing;
    await into(workspaces).insert(
      WorkspacesCompanion.insert(
        id: workspace.id,
        name: workspace.name,
        rootPath: workspace.rootPath,
        kind: workspace.kind.name,
        createdAt: workspace.createdAt,
      ),
    );
    return workspace;
  }

  @override
  Future<WorkspaceDto> upsert(WorkspaceDto workspace) async {
    await into(workspaces).insertOnConflictUpdate(
      WorkspacesCompanion.insert(
        id: workspace.id,
        name: workspace.name,
        rootPath: workspace.rootPath,
        kind: workspace.kind.name,
        createdAt: workspace.createdAt,
      ),
    );
    return (await getById(workspace.id))!;
  }

  @override
  Future<void> unregister(String id) => transaction(() async {
    await (delete(worktrees)..where((row) => row.workspaceId.equals(id))).go();
    await (delete(workspaces)..where((row) => row.id.equals(id))).go();
  });

  WorkspaceDto _toDto(Workspace row) => WorkspaceDto(
    id: row.id,
    name: row.name,
    rootPath: row.rootPath,
    kind: WorkspaceKind.values.byName(row.kind),
    createdAt: row.createdAt,
  );
}

@DriftAccessor(tables: <Type>[Worktrees])
/// Drift adapter for worktree persistence.
class WorktreeDao extends DatabaseAccessor<TinestDatabase>
    with _$WorktreeDaoMixin
    implements WorktreeRepository {
  /// Creates a [WorktreeDao].
  new(super.attachedDatabase);

  @override
  Future<List<WorktreeDto>> list({String? workspaceId}) async {
    final query = select(worktrees)..where((row) => row.archivedAt.isNull());
    if (workspaceId != null) {
      query.where((row) => row.workspaceId.equals(workspaceId));
    }
    query.orderBy(<OrderClauseGenerator<$WorktreesTable>>[
      (row) => OrderingTerm.asc(row.name),
    ]);
    return (await query.get()).map(_toDto).toList(growable: false);
  }

  @override
  Future<WorktreeDto?> getById(String id) async {
    final row = await (select(
      worktrees,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDto(row);
  }

  @override
  Future<WorktreeDto?> getByPath(String path) async {
    final row =
        await (select(worktrees)..where(
              (table) => table.path.equals(path) & table.archivedAt.isNull(),
            ))
            .getSingleOrNull();
    return row == null ? null : _toDto(row);
  }

  @override
  Future<WorktreeDto?> getByPathIncludingArchived(String path) async {
    final row = await (select(
      worktrees,
    )..where((table) => table.path.equals(path))).getSingleOrNull();
    return row == null ? null : _toDto(row);
  }

  @override
  Future<WorktreeDto> upsert(WorktreeDto worktree) async {
    await into(worktrees).insertOnConflictUpdate(
      WorktreesCompanion.insert(
        id: worktree.id,
        workspaceId: worktree.workspaceId,
        name: worktree.name,
        path: worktree.path,
        branch: Value<String?>(worktree.branch),
        head: Value<String?>(worktree.head),
        kind: worktree.kind.name,
        isTinestOwned: worktree.isTinestOwned,
        archivedAt: Value<DateTime?>(worktree.archivedAt),
        createdAt: worktree.createdAt,
      ),
    );
    return (await getById(worktree.id))!;
  }

  @override
  Future<void> archive(String id, DateTime archivedAt) =>
      (update(worktrees)..where((row) => row.id.equals(id))).write(
        WorktreesCompanion(archivedAt: Value<DateTime?>(archivedAt)),
      );

  WorktreeDto _toDto(Worktree row) => WorktreeDto(
    id: row.id,
    workspaceId: row.workspaceId,
    name: row.name,
    path: row.path,
    branch: row.branch,
    head: row.head,
    kind: WorktreeKind.values.byName(row.kind),
    isTinestOwned: row.isTinestOwned,
    archivedAt: row.archivedAt,
    createdAt: row.createdAt,
  );
}

@DriftAccessor(tables: <Type>[Sessions, Turns, Attachments, TurnAttachments])
/// SessionDao defines a public contract.
class SessionDao extends DatabaseAccessor<TinestDatabase>
    with _$SessionDaoMixin
    implements SessionRepository {
  /// Creates a [SessionDao].
  new(super.attachedDatabase);

  @override
  Future<List<SessionDto>> list({String? worktreeId}) async {
    final query = select(sessions);
    if (worktreeId != null) {
      query.where((row) => row.worktreeId.equals(worktreeId));
    }
    query.orderBy(<OrderClauseGenerator<$SessionsTable>>[
      (row) => OrderingTerm.desc(row.updatedAt),
    ]);
    return (await query.get()).map(_toDto).toList(growable: false);
  }

  @override
  Future<SessionDto?> getById(String id) async {
    final row = await (select(
      sessions,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDto(row);
  }

  @override
  Future<int> countActive(String worktreeId) async {
    final count = sessions.id.count();
    final query = selectOnly(sessions)
      ..addColumns(<Expression<Object>>[count])
      ..where(
        sessions.worktreeId.equals(worktreeId) &
            sessions.status.isIn(<String>[
              SessionStatus.running.name,
              SessionStatus.waitingForApproval.name,
              SessionStatus.initializing.name,
            ]),
      );
    return await (await query.getSingle()).read(count) ?? 0;
  }

  @override
  Future<SessionDto> create(SessionDto session) async {
    final existing = await getById(session.id);
    if (existing != null) return existing;
    await into(sessions).insert(
      SessionsCompanion.insert(
        id: session.id,
        worktreeId: session.worktreeId,
        title: session.title,
        agentDefinitionId: session.agentDefinitionId,
        origin: session.origin.name,
        parentSessionId: Value<String?>(session.parentSessionId),
        taskName: Value<String?>(session.taskName),
        agentPath: Value<String?>(session.agentPath),
        rootSessionId: Value<String?>(session.rootSessionId),
        lifecycle: Value<String?>(session.lifecycle?.name),
        status: session.status.name,
        activeTurnId: Value<String?>(session.activeTurnId),
        lastError: Value<String?>(session.lastError),
        modelId: Value<String?>(session.model?.qualifiedModelId),
        modelControlsJson: Value<String>(
          jsonEncode(
            session.modelControls.map(
              (key, value) => MapEntry<String, dynamic>(key, value.toJson()),
            ),
          ),
        ),
        permissionMode: Value<String>(session.permissionMode.name),
        createdAt: session.createdAt,
        updatedAt: session.updatedAt,
      ),
    );
    return session;
  }

  @override
  Future<SessionDto> updateModelSettings(
    String id, {
    required bool hasModel,
    required Map<String, ModelControlValueDto> modelControls,
    ModelSelectionDto? model,
  }) async {
    await (update(sessions)..where((row) => row.id.equals(id))).write(
      SessionsCompanion(
        modelId: hasModel
            ? Value<String?>(model?.qualifiedModelId)
            : const Value<String?>.absent(),
        modelControlsJson: Value<String>(
          jsonEncode(
            modelControls.map(
              (key, value) => MapEntry<String, dynamic>(key, value.toJson()),
            ),
          ),
        ),
        updatedAt: Value<DateTime>(attachedDatabase.clock.nowUtc()),
      ),
    );
    return (await getById(id))!;
  }

  @override
  Future<void> rewriteModelPrefix(String oldPrefix, String newPrefix) async {
    await attachedDatabase.transaction(() async {
      final affected = await (select(
        sessions,
      )..where((row) => row.modelId.like('$oldPrefix/%'))).get();
      for (final session in affected) {
        final modelId = session.modelId;
        if (modelId == null) continue;
        await (update(
          sessions,
        )..where((row) => row.id.equals(session.id))).write(
          SessionsCompanion(
            modelId: Value<String>(
              '$newPrefix/${modelId.substring(oldPrefix.length + 1)}',
            ),
          ),
        );
      }
    });
  }

  @override
  Future<SessionDto> updatePermissionMode(
    String id,
    PermissionMode permissionMode,
  ) async {
    await (update(sessions)..where((row) => row.id.equals(id))).write(
      SessionsCompanion(
        permissionMode: Value<String>(permissionMode.name),
        updatedAt: Value<DateTime>(attachedDatabase.clock.nowUtc()),
      ),
    );
    return (await getById(id))!;
  }

  @override
  Future<SessionDto> recordContextTokens(
    String id,
    int tokens, {
    required double? usageCostUsd,
  }) async {
    // Usage is not a user edit, so `updatedAt` deliberately stays put: a token
    // counter must not reorder a list sorted by recency.
    final current = await (select(
      sessions,
    )..where((row) => row.id.equals(id))).getSingle();
    await (update(sessions)..where((row) => row.id.equals(id))).write(
      SessionsCompanion(
        contextTokensUsed: Value<int>(tokens),
        totalCostUsd: Value<double>(current.totalCostUsd + (usageCostUsd ?? 0)),
        hasCompleteCost: Value<bool>(
          current.hasCompleteCost && usageCostUsd != null,
        ),
      ),
    );
    return (await getById(id))!;
  }

  @override
  Future<SessionDto> recordContextWindow(String id, int? window) async {
    await (update(sessions)..where((row) => row.id.equals(id))).write(
      SessionsCompanion(contextWindowTokens: Value<int?>(window)),
    );
    return (await getById(id))!;
  }

  @override
  Future<SessionDto> updateStatus(
    String id,
    SessionStatus status, {
    String? activeTurnId,
    String? error,
  }) async {
    await (update(sessions)..where((row) => row.id.equals(id))).write(
      SessionsCompanion(
        status: Value<String>(status.name),
        activeTurnId: Value<String?>(activeTurnId),
        lastError: Value<String?>(error),
        updatedAt: Value<DateTime>(attachedDatabase.clock.nowUtc()),
      ),
    );
    return (await getById(id))!;
  }

  @override
  Future<bool> createTurn({
    required String id,
    required String sessionId,
    required String prompt,
    List<String> attachmentIds = const <String>[],
  }) async {
    if (attachmentIds.length > 10) {
      throw const FormatException('A turn accepts at most 10 attachments.');
    }
    if (attachmentIds.toSet().length != attachmentIds.length) {
      throw const FormatException('Attachment IDs must be unique.');
    }
    final exists = await (select(
      turns,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (exists != null) return false;
    final now = attachedDatabase.clock.nowUtc();
    await transaction(() async {
      if (attachmentIds.isNotEmpty) {
        final rows = await (select(
          attachments,
        )..where((row) => row.id.isIn(attachmentIds))).get();
        if (rows.length != attachmentIds.length) {
          throw const FormatException('Unknown attachment ID.');
        }
      }
      await into(turns).insert(
        TurnsCompanion.insert(
          id: id,
          sessionId: sessionId,
          prompt: prompt,
          status: TurnStatus.running.name,
          createdAt: now,
          updatedAt: now,
        ),
      );
      for (var ordinal = 0; ordinal < attachmentIds.length; ordinal += 1) {
        await into(turnAttachments).insert(
          TurnAttachmentsCompanion.insert(
            turnId: id,
            attachmentId: attachmentIds[ordinal],
            direction: 'user',
            ordinal: ordinal,
          ),
        );
      }
    });
    return true;
  }

  @override
  Future<void> updateTurn(String id, TurnStatus status, {String? error}) =>
      (update(turns)..where((row) => row.id.equals(id))).write(
        TurnsCompanion(
          status: Value<String>(status.name),
          error: Value<String?>(error),
          updatedAt: Value<DateTime>(attachedDatabase.clock.nowUtc()),
        ),
      );

  @override
  Future<List<SessionDto>> listByRoot(String rootSessionId) async {
    final query = select(sessions)
      ..where(
        (row) =>
            row.id.equals(rootSessionId) |
            row.rootSessionId.equals(rootSessionId),
      )
      ..orderBy(<OrderClauseGenerator<$SessionsTable>>[
        // The root's null path sorts before every '/root/...' descendant.
        (row) => OrderingTerm.asc(row.agentPath),
        (row) => OrderingTerm.asc(row.createdAt),
      ]);
    return (await query.get()).map(_toDto).toList(growable: false);
  }

  @override
  Future<SessionDto?> getByAgentPath(
    String rootSessionId,
    String agentPath,
  ) async {
    if (agentPath == '/root') return await getById(rootSessionId);
    final row =
        await (select(sessions)..where(
              (table) =>
                  table.rootSessionId.equals(rootSessionId) &
                  table.agentPath.equals(agentPath),
            ))
            .getSingleOrNull();
    return row == null ? null : _toDto(row);
  }

  @override
  Future<SessionDto> updateLifecycle(
    String id,
    AgentLifecycle lifecycle,
  ) async {
    await (update(sessions)..where((row) => row.id.equals(id))).write(
      SessionsCompanion(
        lifecycle: Value<String?>(lifecycle.name),
        updatedAt: Value<DateTime>(attachedDatabase.clock.nowUtc()),
      ),
    );
    return (await getById(id))!;
  }

  SessionDto _toDto(Session row) {
    final modelId = row.modelId;
    return SessionDto(
      id: row.id,
      worktreeId: row.worktreeId,
      title: row.title,
      agentDefinitionId: row.agentDefinitionId,
      origin: SessionOrigin.values.byName(row.origin),
      parentSessionId: row.parentSessionId,
      taskName: row.taskName,
      agentPath: row.agentPath,
      rootSessionId: row.rootSessionId,
      // A row written by a newer build must still render as a session.
      lifecycle: AgentLifecycle.values
          .where((value) => value.name == row.lifecycle)
          .firstOrNull,
      status: SessionStatus.values.byName(row.status),
      activeTurnId: row.activeTurnId,
      lastError: row.lastError,
      model: modelId == null ? null : ModelSelectionDto(modelId: modelId),
      modelControls: <String, ModelControlValueDto>{
        for (final entry in (jsonDecode(
          row.modelControlsJson,
        ) as Map<String, dynamic>).entries)
          entry.key: ModelControlValueDto.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          ),
      },
      contextTokens: row.contextTokensUsed,
      contextWindow: row.contextWindowTokens,
      totalCostUsd: row.hasCompleteCost ? row.totalCostUsd : null,
      // A row written by a newer build must still render as a session, and
      // the mode it falls back to still asks before every mutation.
      permissionMode: PermissionMode.values.firstWhere(
        (value) => value.name == row.permissionMode,
        orElse: () => PermissionMode.ask,
      ),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}

@DriftAccessor(tables: <Type>[AgentMailboxMessages])
/// Drift inter-agent mailbox repository.
class AgentMailboxDao extends DatabaseAccessor<TinestDatabase>
    with _$AgentMailboxDaoMixin
    implements AgentMailboxRepository {
  /// Creates an agent mailbox DAO.
  new(super.attachedDatabase);

  @override
  Future<void> enqueue(
    AgentMailboxMessageDto message, {
    required bool triggerTurn,
  }) => into(agentMailboxMessages).insert(
    AgentMailboxMessagesCompanion.insert(
      id: message.id,
      sessionId: message.sessionId,
      senderSessionId: Value<String?>(message.senderSessionId),
      senderPath: message.senderPath,
      recipientPath: message.recipientPath,
      messageType: message.type.name,
      payload: message.payload,
      triggerTurn: triggerTurn,
      createdAt: message.createdAt,
      deliveredAt: Value<DateTime?>(message.deliveredAt),
    ),
  );

  @override
  Future<List<QueuedAgentMail>> undeliveredFor(String sessionId) async {
    final query = select(agentMailboxMessages)
      ..where(
        (row) => row.sessionId.equals(sessionId) & row.deliveredAt.isNull(),
      )
      ..orderBy(<OrderClauseGenerator<$AgentMailboxMessagesTable>>[
        (row) => OrderingTerm.asc(row.createdAt),
        (row) => OrderingTerm.asc(row.id),
      ]);
    return (await query.get())
        .map(
          (row) => (
            message: AgentMailboxMessageDto(
              id: row.id,
              sessionId: row.sessionId,
              senderSessionId: row.senderSessionId,
              senderPath: row.senderPath,
              recipientPath: row.recipientPath,
              type: InterAgentMessageType.values.byName(row.messageType),
              payload: row.payload,
              createdAt: row.createdAt,
              deliveredAt: row.deliveredAt,
            ),
            triggerTurn: row.triggerTurn,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> markDelivered(List<String> ids, DateTime deliveredAt) async {
    if (ids.isEmpty) return;
    await (update(
      agentMailboxMessages,
    )..where((row) => row.id.isIn(ids))).write(
      AgentMailboxMessagesCompanion(deliveredAt: Value<DateTime?>(deliveredAt)),
    );
  }

  @override
  Future<bool> hasUndeliveredTrigger(String sessionId) async {
    final row =
        await (select(agentMailboxMessages)
              ..where(
                (table) =>
                    table.sessionId.equals(sessionId) &
                    table.deliveredAt.isNull() &
                    table.triggerTurn.equals(true),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }
}

@DriftAccessor(tables: <Type>[Attachments, TurnAttachments, Turns])
/// Drift attachment metadata repository.
class AttachmentDao extends DatabaseAccessor<TinestDatabase>
    with _$AttachmentDaoMixin
    implements AttachmentRepository {
  /// Creates an attachment DAO.
  new(super.attachedDatabase);

  @override
  Future<void> insert(AttachmentDto attachment) => into(attachments).insert(
    AttachmentsCompanion.insert(
      id: attachment.id,
      fileName: attachment.fileName,
      mimeType: attachment.mimeType,
      byteSize: attachment.byteSize,
      kind: attachment.kind.name,
      sha256: attachment.sha256,
      createdAt: attachment.createdAt,
    ),
  );

  @override
  Future<AttachmentDto?> getById(String id) async {
    final row = await (select(
      attachments,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDto(row);
  }

  @override
  Future<List<AttachmentDto>> getByIds(List<String> ids) async {
    if (ids.isEmpty) return const <AttachmentDto>[];
    final rows = await (select(
      attachments,
    )..where((row) => row.id.isIn(ids))).get();
    final byId = <String, Attachment>{for (final row in rows) row.id: row};
    return ids
        .map((id) {
          final row = byId[id];
          if (row == null) {
            throw const FormatException('Unknown attachment ID.');
          }
          return _toDto(row);
        })
        .toList(growable: false);
  }

  @override
  Future<bool> isLinkedToSession(String id, String sessionId) async {
    final query =
        select(turnAttachments).join(<Join<HasResultSet, dynamic>>[
          innerJoin(turns, turns.id.equalsExp(turnAttachments.turnId)),
        ])..where(
          turnAttachments.attachmentId.equals(id) &
              turns.sessionId.equals(sessionId),
        );
    return await query.getSingleOrNull() != null;
  }

  @override
  Future<void> bindAssistant(String turnId, String attachmentId) async {
    final ordinalExpression = turnAttachments.ordinal.max();
    final maximum =
        await (selectOnly(turnAttachments)
              ..addColumns(<Expression<Object>>[ordinalExpression])
              ..where(
                turnAttachments.turnId.equals(turnId) &
                    turnAttachments.direction.equals('assistant'),
              ))
            .getSingle();
    final ordinal = (maximum.read(ordinalExpression) ?? -1) + 1;
    await into(turnAttachments).insert(
      TurnAttachmentsCompanion.insert(
        turnId: turnId,
        attachmentId: attachmentId,
        direction: 'assistant',
        ordinal: ordinal,
      ),
    );
  }

  @override
  Future<List<String>> deleteOrphansBefore(DateTime cutoff) async {
    final linked = selectOnly(turnAttachments)
      ..addColumns(<Expression<Object>>[turnAttachments.attachmentId]);
    final candidates =
        await (select(attachments)..where(
              (row) =>
                  row.createdAt.isSmallerThanValue(cutoff) &
                  row.id.isNotInQuery(linked),
            ))
            .get();
    if (candidates.isEmpty) return const <String>[];
    final ids = candidates.map((row) => row.id).toList(growable: false);
    await (delete(attachments)..where((row) => row.id.isIn(ids))).go();
    return ids;
  }

  AttachmentDto _toDto(Attachment row) => AttachmentDto(
    id: row.id,
    fileName: row.fileName,
    mimeType: row.mimeType,
    byteSize: row.byteSize,
    kind: AttachmentKind.values.byName(row.kind),
    sha256: row.sha256,
    createdAt: row.createdAt,
  );
}

@DriftAccessor(
  tables: <Type>[
    TimelineEvents,
    ApprovalRequests,
    UserQuestions,
    ProviderStates,
  ],
)
/// TimelineDao defines a public contract.
class TimelineDao extends DatabaseAccessor<TinestDatabase>
    with _$TimelineDaoMixin
    implements TimelineRepository {
  /// Creates a [TimelineDao].
  new(super.attachedDatabase);

  @override
  Future<TimelineEventDto> append({
    required String sessionId,
    required String type,
    required Map<String, dynamic> data,
    String? turnId,
  }) => transaction(() async {
    final maxSequence = timelineEvents.sequence.max();
    final query = selectOnly(timelineEvents)
      ..addColumns(<Expression<Object>>[maxSequence])
      ..where(timelineEvents.sessionId.equals(sessionId));
    final current = (await query.getSingle()).read(maxSequence) ?? 0;
    final event = TimelineEventDto(
      sessionId: sessionId,
      sequence: current + 1,
      turnId: turnId,
      type: type,
      data: data,
      createdAt: attachedDatabase.clock.nowUtc(),
    );
    await into(timelineEvents).insert(
      TimelineEventsCompanion.insert(
        sessionId: event.sessionId,
        sequence: event.sequence,
        turnId: Value<String?>(event.turnId),
        type: event.type,
        dataJson: jsonEncode(event.data),
        createdAt: event.createdAt,
      ),
    );
    return event;
  });

  @override
  Future<List<TimelineEventDto>> after(String sessionId, int sequence) async =>
      await _ascending(sessionId, lowerExclusive: sequence);

  @override
  Future<List<TimelineEventDto>> tail(
    String sessionId,
    int sequence, {
    required int limit,
  }) async {
    final newest = await _newest(
      sessionId,
      lowerExclusive: sequence,
      limit: limit,
    );
    if (newest.isEmpty) return const <TimelineEventDto>[];
    // Never reach back past what the caller already excluded: a tail is a
    // window over the events it asked for, not a licence to resend older ones.
    final start = await _turnStart(
      sessionId,
      newest.last,
      floor: math.max(sequence + 1, newest.first.sequence - _span(limit) + 1),
    );
    return await _ascending(
      sessionId,
      lowerExclusive: start - 1,
      upperInclusive: newest.first.sequence,
    );
  }

  @override
  Future<List<TimelineEventDto>> before(
    String sessionId,
    int sequence, {
    required int limit,
  }) async {
    final newest = await _newest(
      sessionId,
      upperExclusive: sequence,
      limit: limit,
    );
    if (newest.isEmpty) return const <TimelineEventDto>[];
    final start = await _turnStart(
      sessionId,
      newest.last,
      floor: math.max(1, newest.first.sequence - _span(limit) + 1),
    );
    return await _ascending(
      sessionId,
      lowerExclusive: start - 1,
      upperInclusive: newest.first.sequence,
    );
  }

  /// The hard ceiling on a window, alignment included.
  ///
  /// Turn alignment exists so a reply is never delivered without the prompt
  /// that produced it, but a turn is not small: one streamed answer is one row
  /// per delta and can run to thousands. Without this the alignment would undo
  /// the limit it is extending, and the oversized frame that follows is the
  /// failure paging exists to prevent. A turn longer than this is split, and
  /// the reader closes the gap by paging again.
  static int _span(int limit) => limit * 2;

  /// The first sequence of [row]'s turn, floored at [floor].
  ///
  /// An event with no turn is its own boundary; nothing groups it.
  Future<int> _turnStart(
    String sessionId,
    TimelineEvent row, {
    required int floor,
  }) async {
    final turnId = row.turnId;
    if (turnId == null) return row.sequence;
    final query = selectOnly(timelineEvents)
      ..addColumns(<Expression<Object>>[timelineEvents.sequence.min()])
      ..where(
        timelineEvents.sessionId.equals(sessionId) &
            timelineEvents.turnId.equals(turnId),
      );
    final start =
        (await query
            .map((row) => row.read(timelineEvents.sequence.min()))
            .getSingleOrNull()) ??
        row.sequence;
    return start < floor ? floor : start;
  }

  /// The [limit] highest sequences in range, newest first.
  Future<List<TimelineEvent>> _newest(
    String sessionId, {
    required int limit,
    int? lowerExclusive,
    int? upperExclusive,
  }) =>
      (select(timelineEvents)
            ..where(
              (row) =>
                  row.sessionId.equals(sessionId) &
                  (lowerExclusive == null
                      ? const Constant<bool>(true)
                      : row.sequence.isBiggerThanValue(lowerExclusive)) &
                  (upperExclusive == null
                      ? const Constant<bool>(true)
                      : row.sequence.isSmallerThanValue(upperExclusive)),
            )
            ..orderBy(<OrderClauseGenerator<$TimelineEventsTable>>[
              (row) => OrderingTerm.desc(row.sequence),
            ])
            ..limit(limit))
          .get();

  Future<List<TimelineEventDto>> _ascending(
    String sessionId, {
    required int lowerExclusive,
    int? upperInclusive,
  }) async =>
      (await (select(timelineEvents)
                ..where(
                  (row) =>
                      row.sessionId.equals(sessionId) &
                      row.sequence.isBiggerThanValue(lowerExclusive) &
                      (upperInclusive == null
                          ? const Constant<bool>(true)
                          : row.sequence.isSmallerOrEqualValue(upperInclusive)),
                )
                ..orderBy(<OrderClauseGenerator<$TimelineEventsTable>>[
                  (row) => OrderingTerm.asc(row.sequence),
                ]))
              .get())
          .map(
            (row) => TimelineEventDto(
              sessionId: row.sessionId,
              sequence: row.sequence,
              turnId: row.turnId,
              type: row.type,
              data: Map<String, dynamic>.from(jsonDecode(row.dataJson) as Map),
              createdAt: row.createdAt,
            ),
          )
          .toList(growable: false);

  @override
  Future<void> appendProviderItems(
    String sessionId,
    List<ConversationItem> items,
  ) async {
    if (items.isEmpty) return;
    await transaction(() async {
      await _appendToWindow(sessionId, items, await _liveEpoch(sessionId));
    });
  }

  @override
  Future<List<ConversationItem>> providerHistory(String sessionId) async {
    final epoch = await _liveEpoch(sessionId);
    final rows =
        await (select(providerStates)
              ..where((row) => row.sessionId.equals(sessionId))
              ..where((row) => row.contextEpoch.equals(epoch))
              ..orderBy(<OrderClauseGenerator<$ProviderStatesTable>>[
                (row) => OrderingTerm.asc(row.ordinal),
              ]))
            .get();
    return rows
        .map(
          (row) => ConversationItem.fromJson(
            Map<String, dynamic>.from(jsonDecode(row.itemJson) as Map),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> resetContextWindow(
    String sessionId,
    List<ConversationItem> retain,
  ) => transaction(() async {
    final epoch = await _liveEpoch(sessionId) + 1;
    await (update(sessions)..where((row) => row.id.equals(sessionId))).write(
      SessionsCompanion(
        currentContextEpoch: Value<int>(epoch),
        // The retained items are re-sent, so the next response reports them
        // again; starting from zero would double-count them.
        contextTokensUsed: const Value<int>(0),
        updatedAt: Value<DateTime>(attachedDatabase.clock.nowUtc()),
      ),
    );
    await _appendToWindow(sessionId, retain, epoch);
  });

  /// The context window every new provider item belongs to.
  Future<int> _liveEpoch(String sessionId) async {
    final query = selectOnly(sessions)
      ..addColumns(<Expression<Object>>[sessions.currentContextEpoch])
      ..where(sessions.id.equals(sessionId));
    final row = await query.getSingleOrNull();
    return await row?.read(sessions.currentContextEpoch) ?? 0;
  }

  /// Appends [items] after the last ordinal, tagged with [epoch].
  ///
  /// Ordinals stay session-global rather than per-epoch so replay order is
  /// still a single ascending scan after any number of resets.
  Future<void> _appendToWindow(
    String sessionId,
    List<ConversationItem> items,
    int epoch,
  ) async {
    if (items.isEmpty) return;
    final maxOrdinal = providerStates.ordinal.max();
    final query = selectOnly(providerStates)
      ..addColumns(<Expression<Object>>[maxOrdinal])
      ..where(providerStates.sessionId.equals(sessionId));
    var ordinal = (await query.getSingle()).read(maxOrdinal) ?? 0;
    for (final item in items) {
      ordinal += 1;
      await into(providerStates).insert(
        ProviderStatesCompanion.insert(
          sessionId: sessionId,
          ordinal: ordinal,
          itemJson: jsonEncode(item.toJson()),
          contextEpoch: Value<int>(epoch),
          createdAt: attachedDatabase.clock.nowUtc(),
        ),
      );
    }
  }

  @override
  Future<void> createApproval(ApprovalRequestDto approval) =>
      into(approvalRequests).insert(
        ApprovalRequestsCompanion.insert(
          id: approval.id,
          sessionId: approval.sessionId,
          turnId: approval.turnId,
          toolCallId: approval.toolCallId,
          toolName: approval.toolName,
          risk: approval.risk.name,
          argumentsJson: jsonEncode(approval.arguments),
          preview: Value<String?>(approval.preview),
          status: approval.status.name,
          createdAt: approval.createdAt,
        ),
      );

  @override
  Future<ApprovalRequestDto?> resolveApproval(
    String id,
    ApprovalStatus status,
  ) async {
    final row = await (select(
      approvalRequests,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    if (row == null || row.status != ApprovalStatus.pending.name) return null;
    await (update(approvalRequests)..where((table) => table.id.equals(id)))
        .write(ApprovalRequestsCompanion(status: Value<String>(status.name)));
    return ApprovalRequestDto(
      id: row.id,
      sessionId: row.sessionId,
      turnId: row.turnId,
      toolCallId: row.toolCallId,
      toolName: row.toolName,
      risk: ToolRisk.values.byName(row.risk),
      arguments: Map<String, dynamic>.from(
        jsonDecode(row.argumentsJson) as Map,
      ),
      status: status,
      createdAt: row.createdAt,
      preview: row.preview,
    );
  }

  @override
  Future<void> createUserQuestion(UserQuestionRequestDto request) =>
      into(userQuestions).insert(
        UserQuestionsCompanion.insert(
          id: request.id,
          sessionId: request.sessionId,
          turnId: request.turnId,
          toolCallId: request.toolCallId,
          questionsJson: jsonEncode(
            request.questions
                .map((question) => question.toJson())
                .toList(growable: false),
          ),
          answersJson: jsonEncode(
            request.answers
                .map((answer) => answer.toJson())
                .toList(growable: false),
          ),
          status: request.status.name,
          createdAt: request.createdAt,
        ),
      );

  @override
  Future<UserQuestionRequestDto?> getUserQuestion(String id) async {
    final row = await (select(
      userQuestions,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : _userQuestion(row);
  }

  @override
  Future<UserQuestionRequestDto?> answerUserQuestion(
    String id,
    UserQuestionStatus status,
    List<UserQuestionAnswerDto> answers,
  ) async {
    final row = await (select(
      userQuestions,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    if (row == null || row.status != UserQuestionStatus.pending.name) {
      return null;
    }
    final answersJson = jsonEncode(
      answers.map((answer) => answer.toJson()).toList(growable: false),
    );
    await (update(userQuestions)..where((table) => table.id.equals(id))).write(
      UserQuestionsCompanion(
        status: Value<String>(status.name),
        answersJson: Value<String>(answersJson),
      ),
    );
    return _userQuestion(row).copyWith(status: status, answers: answers);
  }

  UserQuestionRequestDto _userQuestion(UserQuestionRow row) =>
      UserQuestionRequestDto(
        id: row.id,
        sessionId: row.sessionId,
        turnId: row.turnId,
        toolCallId: row.toolCallId,
        questions: (jsonDecode(row.questionsJson) as List<dynamic>)
            .map(
              (question) => UserQuestionItemDto.fromJson(
                Map<String, dynamic>.from(question as Map),
              ),
            )
            .toList(growable: false),
        status: UserQuestionStatus.values.byName(row.status),
        createdAt: row.createdAt,
        answers: (jsonDecode(row.answersJson) as List<dynamic>)
            .map(
              (answer) => UserQuestionAnswerDto.fromJson(
                Map<String, dynamic>.from(answer as Map),
              ),
            )
            .toList(growable: false),
      );
}

@DriftAccessor(tables: <Type>[ProviderConnections, ProviderModels])
/// ProviderDao defines a public contract.
class ProviderDao extends DatabaseAccessor<TinestDatabase>
    with _$ProviderDaoMixin
    implements ProviderRepository {
  /// Creates a [ProviderDao].
  new(super.attachedDatabase);

  @override
  Future<List<ProviderConnectionDto>> listConnections() async =>
      (await (select(providerConnections)
                ..orderBy(<OrderClauseGenerator<$ProviderConnectionsTable>>[
                  (row) => OrderingTerm.asc(row.displayName),
                ]))
              .get())
          .map(_connectionToDto)
          .toList(growable: false);

  @override
  Future<ProviderConnectionDto?> getConnection(String id) async {
    final row = await (select(
      providerConnections,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : _connectionToDto(row);
  }

  @override
  Future<ProviderConnectionDto> upsertConnection(
    ProviderConnectionDto connection,
  ) async {
    await into(providerConnections).insertOnConflictUpdate(
      ProviderConnectionsCompanion.insert(
        id: connection.id,
        definitionId: connection.definitionId,
        modelPrefix: connection.modelPrefix,
        displayName: connection.displayName,
        status: connection.status.name,
        authKind: connection.authKind.name,
        credentialOrigin: connection.credentialOrigin.name,
        error: Value<String?>(connection.error),
        customConfigJson: Value<String?>(
          connection.customConfig == null
              ? null
              : jsonEncode(connection.customConfig!.toJson()),
        ),
        createdAt: connection.createdAt,
        updatedAt: connection.updatedAt,
      ),
    );
    return (await getConnection(connection.id))!;
  }

  @override
  Future<void> deleteConnection(String id) async {
    await transaction(() async {
      await (delete(
        providerModels,
      )..where((row) => row.connectionId.equals(id))).go();
      await (delete(
        providerConnections,
      )..where((row) => row.id.equals(id))).go();
    });
  }

  @override
  Future<List<ProviderModelDto>> listModels(String connectionId) async =>
      (await (select(providerModels)
                ..where((row) => row.connectionId.equals(connectionId))
                ..orderBy(<OrderClauseGenerator<$ProviderModelsTable>>[
                  (row) => OrderingTerm.asc(row.label),
                ]))
              .get())
          .map(_modelToDto)
          .toList(growable: false);

  @override
  Future<ProviderModelDto?> getModel(
    String connectionId,
    String modelId,
  ) async {
    final row =
        await (select(providerModels)..where(
              (table) =>
                  table.connectionId.equals(connectionId) &
                  table.modelId.equals(modelId),
            ))
            .getSingleOrNull();
    return row == null ? null : _modelToDto(row);
  }

  @override
  Future<ProviderModelDto> upsertModel(ProviderModelDto model) async {
    await into(providerModels).insertOnConflictUpdate(
      ProviderModelsCompanion.insert(
        connectionId: model.connectionId,
        modelId: model.id,
        providerModelId: model.providerModelId,
        label: model.label,
        source: model.source.name,
        capabilitiesJson: jsonEncode(model.capabilities.toJson()),
        pricingJson: Value<String?>(
          model.pricing == null ? null : jsonEncode(model.pricing!.toJson()),
        ),
        limitsJson: Value<String?>(
          model.limits == null ? null : jsonEncode(model.limits!.toJson()),
        ),
        diagnosticStatus: Value<String>(model.diagnosticStatus.name),
        verifiedAt: Value<DateTime?>(model.verifiedAt),
        diagnosticError: Value<String?>(model.diagnosticError),
      ),
    );
    return (await getModel(model.connectionId, model.id))!;
  }

  @override
  Future<void> replaceModels(
    String connectionId,
    Iterable<ProviderModelDto> models,
  ) => transaction(() async {
    await (delete(
      providerModels,
    )..where((row) => row.connectionId.equals(connectionId))).go();
    for (final model in models) {
      if (model.connectionId != connectionId) {
        throw StateError('Replacement model belongs to another connection.');
      }
      await upsertModel(model);
    }
  });

  @override
  Future<void> deleteModel(String connectionId, String modelId) =>
      (delete(providerModels)..where(
            (row) =>
                row.connectionId.equals(connectionId) &
                row.modelId.equals(modelId),
          ))
          .go();

  ProviderConnectionDto _connectionToDto(ProviderConnection row) =>
      ProviderConnectionDto(
        id: row.id,
        definitionId: row.definitionId,
        modelPrefix: row.modelPrefix,
        displayName: row.displayName,
        status: ProviderConnectionStatus.values.byName(row.status),
        authKind: ProviderAuthKind.values.byName(row.authKind),
        credentialOrigin: ProviderCredentialOrigin.values.byName(
          row.credentialOrigin,
        ),
        error: row.error,
        customConfig: row.customConfigJson == null
            ? null
            : CustomProviderConfigDto.fromJson(
                Map<String, dynamic>.from(
                  jsonDecode(row.customConfigJson!) as Map<dynamic, dynamic>,
                ),
              ),
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );

  ProviderModelDto _modelToDto(ProviderModel row) => ProviderModelDto(
    connectionId: row.connectionId,
    id: row.modelId,
    providerModelId: row.providerModelId,
    label: row.label,
    source: ProviderModelSource.values.byName(row.source),
    capabilities: ModelCapabilitiesDto.fromJson(
      Map<String, dynamic>.from(jsonDecode(row.capabilitiesJson) as Map),
    ),
    pricing: row.pricingJson == null
        ? null
        : ModelPricingDto.fromJson(
            Map<String, dynamic>.from(jsonDecode(row.pricingJson!) as Map),
          ),
    limits: row.limitsJson == null
        ? null
        : ModelLimitsDto.fromJson(
            Map<String, dynamic>.from(jsonDecode(row.limitsJson!) as Map),
          ),
    diagnosticStatus: DiagnosticStatus.values.byName(row.diagnosticStatus),
    verifiedAt: row.verifiedAt,
    diagnosticError: row.diagnosticError,
  );
}

@DriftAccessor(tables: <Type>[Sessions, Turns, ApprovalRequests, UserQuestions])
/// RuntimeDao defines a public contract.
class RuntimeDao extends DatabaseAccessor<TinestDatabase>
    with _$RuntimeDaoMixin
    implements RecoveryRepository {
  /// Creates a [RuntimeDao].
  new(super.attachedDatabase);

  @override
  Future<void> recoverInterruptedRuns() async {
    final now = attachedDatabase.clock.nowUtc();
    await transaction(() async {
      await (update(turns)..where(
            (row) => row.status.isIn(<String>[
              TurnStatus.running.name,
              TurnStatus.waitingForApproval.name,
            ]),
          ))
          .write(
            TurnsCompanion(
              status: Value<String>(TurnStatus.interrupted.name),
              error: const Value<String?>('Daemon restarted during the turn.'),
              updatedAt: Value<DateTime>(now),
            ),
          );
      await (update(sessions)..where(
            (row) => row.status.isIn(<String>[
              SessionStatus.running.name,
              SessionStatus.waitingForApproval.name,
              SessionStatus.initializing.name,
            ]),
          ))
          .write(
            SessionsCompanion(
              status: Value<String>(SessionStatus.failed.name),
              activeTurnId: const Value<String?>(null),
              lastError: const Value<String?>(
                'Daemon restarted during the turn.',
              ),
              updatedAt: Value<DateTime>(now),
            ),
          );
      await (update(
        approvalRequests,
      )..where((row) => row.status.equals(ApprovalStatus.pending.name))).write(
        ApprovalRequestsCompanion(
          status: Value<String>(ApprovalStatus.cancelled.name),
        ),
      );
      await (update(
            userQuestions,
          )..where((row) => row.status.equals(UserQuestionStatus.pending.name)))
          .write(
            UserQuestionsCompanion(
              status: Value<String>(UserQuestionStatus.cancelled.name),
            ),
          );
    });
  }
}
