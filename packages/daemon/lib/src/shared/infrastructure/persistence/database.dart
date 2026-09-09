import 'dart:io';

import 'package:daemon/src/shared/infrastructure/persistence/daos.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'database.g.dart';

/// Workspaces defines a public contract.
class Workspaces extends Table {
  /// The id public API member.
  TextColumn get id => text()();

  /// The name public API member.
  TextColumn get name => text()();

  /// The rootPath public API member.
  TextColumn get rootPath => text()();

  /// Whether this workspace represents a Git repository or a directory.
  TextColumn get kind => text()();

  /// The createdAt public API member.
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// A concrete checkout belonging to a repository workspace.
class Worktrees extends Table {
  /// Stable worktree identifier.
  TextColumn get id => text()();

  /// Owning workspace identifier.
  TextColumn get workspaceId => text().references(Workspaces, #id)();

  /// Human-readable checkout name.
  TextColumn get name => text()();

  /// Canonical checkout path.
  TextColumn get path => text()();

  /// Checked-out branch, when this is a Git worktree.
  TextColumn get branch => text().nullable()();

  /// Current commit, when this is a Git worktree.
  TextColumn get head => text().nullable()();

  /// Worktree ownership and lifecycle kind.
  TextColumn get kind => text()();

  /// Whether Tinest created and may remove the checkout directory.
  BoolColumn get isTinestOwned => boolean()();

  /// Archive instant; null while visible in the workspace catalog.
  DateTimeColumn get archivedAt => dateTime().nullable()();

  /// Creation instant.
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Persisted AI coding sessions.
class Sessions extends Table {
  /// The id public API member.
  TextColumn get id => text()();

  /// The worktreeId public API member.
  TextColumn get worktreeId => text().references(Worktrees, #id)();

  /// The title public API member.
  TextColumn get title => text()();

  /// Markdown agent definition resolved for each turn.
  TextColumn get agentDefinitionId => text()();

  /// Whether this session was created directly or by delegation.
  TextColumn get origin => text()();

  /// Parent session for delegated subagents.
  TextColumn get parentSessionId =>
      text().nullable().references(Sessions, #id)();

  /// Leaf task name of a spawned subagent; null for root sessions.
  TextColumn get taskName => text().nullable()();

  /// Canonical collaboration path, e.g. `/root/task1/task_3`.
  TextColumn get agentPath => text().nullable()();

  /// Root session of the collaboration tree; null for root sessions.
  TextColumn get rootSessionId => text().nullable().references(Sessions, #id)();

  /// Collaboration lifecycle; null outside a collaboration tree.
  TextColumn get lifecycle => text().nullable()();

  /// The status public API member.
  TextColumn get status => text()();

  /// The activeTurnId public API member.
  TextColumn get activeTurnId => text().nullable()();

  /// The lastError public API member.
  TextColumn get lastError => text().nullable()();

  /// Qualified model pinned for this session; null inherits the agent.
  TextColumn get modelId => text().nullable()();

  /// JSON-encoded typed model-control values for this session.
  TextColumn get modelControlsJson =>
      text().withDefault(const Constant('{}'))();

  /// Permission mode this session was pinned to when it was created.
  TextColumn get permissionMode => text().withDefault(const Constant('ask'))();

  /// Live context window; `new_context` bumps it to hide older history.
  IntColumn get currentContextEpoch =>
      integer().withDefault(const Constant(0))();

  /// Tokens the last response reported for the live window.
  IntColumn get contextTokensUsed => integer().withDefault(const Constant(0))();

  /// Context window of the model last resolved for this session.
  ///
  /// Cached on the row rather than looked up per read, so every session read
  /// path reports the same number as the turn that produced the usage.
  IntColumn get contextWindowTokens => integer().nullable()();

  /// Exact accumulated USD cost while every usage event is priced.
  RealColumn get totalCostUsd => real().withDefault(const Constant(0))();

  /// False permanently after a usage event cannot be priced exactly.
  BoolColumn get hasCompleteCost =>
      boolean().withDefault(const Constant(true))();

  /// The createdAt public API member.
  DateTimeColumn get createdAt => dateTime()();

  /// The updatedAt public API member.
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Turns defines a public contract.
class Turns extends Table {
  /// The id public API member.
  TextColumn get id => text()();

  /// The sessionId public API member.
  TextColumn get sessionId => text().references(Sessions, #id)();

  /// The prompt public API member.
  TextColumn get prompt => text()();

  /// The status public API member.
  TextColumn get status => text()();

  /// The error public API member.
  TextColumn get error => text().nullable()();

  /// The createdAt public API member.
  DateTimeColumn get createdAt => dateTime()();

  /// The updatedAt public API member.
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Immutable attachment metadata; payload bytes live in the attachment store.
class Attachments extends Table {
  /// Stable opaque identifier used as the storage key.
  TextColumn get id => text()();

  /// Original display name, never used to construct a storage path.
  TextColumn get fileName => text()();

  /// Validated media type.
  TextColumn get mimeType => text()();

  /// Exact payload length.
  IntColumn get byteSize => integer()();

  /// Broad preview category.
  TextColumn get kind => text()();

  /// Lower-case SHA-256 digest.
  TextColumn get sha256 => text()();

  /// Upload completion time.
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Ordered attachment relationship for inbound and outbound turn files.
class TurnAttachments extends Table {
  /// Owning turn.
  TextColumn get turnId => text().references(Turns, #id)();

  /// Attached immutable payload.
  TextColumn get attachmentId => text().references(Attachments, #id)();

  /// `user` or `assistant`.
  TextColumn get direction => text()();

  /// Stable order within the direction.
  IntColumn get ordinal => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{
    turnId,
    direction,
    ordinal,
  };
}

/// Queued inter-agent mailbox messages for collaborating sessions.
class AgentMailboxMessages extends Table {
  /// The id public API member.
  TextColumn get id => text()();

  /// Recipient session.
  TextColumn get sessionId => text().references(Sessions, #id)();

  /// Sender session; null when the daemon itself authored the message.
  TextColumn get senderSessionId => text().nullable()();

  /// Canonical path of the sender agent.
  TextColumn get senderPath => text()();

  /// Canonical path of the recipient agent.
  TextColumn get recipientPath => text()();

  /// Wire name of the protocol `InterAgentMessageType` enum value.
  TextColumn get messageType => text()();

  /// Message body delivered inside the collaboration envelope.
  TextColumn get payload => text()();

  /// Whether this message should start a turn on an idle recipient.
  BoolColumn get triggerTurn => boolean()();

  /// The createdAt public API member.
  DateTimeColumn get createdAt => dateTime()();

  /// When the message was folded into a recipient turn; null while queued.
  DateTimeColumn get deliveredAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// TimelineEvents defines a public contract.
class TimelineEvents extends Table {
  /// The sessionId public API member.
  TextColumn get sessionId => text().references(Sessions, #id)();

  /// The sequence public API member.
  IntColumn get sequence => integer()();

  /// The turnId public API member.
  TextColumn get turnId => text().nullable()();

  /// The type public API member.
  TextColumn get type => text()();

  /// The dataJson public API member.
  TextColumn get dataJson => text()();

  /// The createdAt public API member.
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{sessionId, sequence};
}

/// ApprovalRequests defines a public contract.
class ApprovalRequests extends Table {
  /// The id public API member.
  TextColumn get id => text()();

  /// The sessionId public API member.
  TextColumn get sessionId => text().references(Sessions, #id)();

  /// The turnId public API member.
  TextColumn get turnId => text().references(Turns, #id)();

  /// The toolCallId public API member.
  TextColumn get toolCallId => text()();

  /// The toolName public API member.
  TextColumn get toolName => text()();

  /// The risk public API member.
  TextColumn get risk => text()();

  /// The argumentsJson public API member.
  TextColumn get argumentsJson => text()();

  /// The preview public API member.
  TextColumn get preview => text().nullable()();

  /// The status public API member.
  TextColumn get status => text()();

  /// The createdAt public API member.
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Questions the agent raised mid-turn and the answers they are waiting on.
///
/// The row class is named explicitly because the default would collide with
/// `UserQuestion`, the agent-side value type this table stores.
@DataClassName('UserQuestionRow')
class UserQuestions extends Table {
  /// The id public API member.
  TextColumn get id => text()();

  /// The sessionId public API member.
  TextColumn get sessionId => text().references(Sessions, #id)();

  /// The turnId public API member.
  TextColumn get turnId => text().references(Turns, #id)();

  /// The toolCallId public API member.
  TextColumn get toolCallId => text()();

  /// The questions, serialized as a JSON array.
  TextColumn get questionsJson => text()();

  /// The answers, serialized as a JSON array; empty while pending.
  TextColumn get answersJson => text()();

  /// The status public API member.
  TextColumn get status => text()();

  /// The createdAt public API member.
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// ProviderStates defines a public contract.
class ProviderStates extends Table {
  /// The sessionId public API member.
  TextColumn get sessionId => text().references(Sessions, #id)();

  /// The ordinal public API member.
  IntColumn get ordinal => integer()();

  /// The itemJson public API member.
  TextColumn get itemJson => text()();

  /// Context window this item belongs to; older windows are never replayed.
  IntColumn get contextEpoch => integer().withDefault(const Constant(0))();

  /// The createdAt public API member.
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{sessionId, ordinal};
}

/// Settings defines a public contract.
class Settings extends Table {
  /// The key public API member.
  TextColumn get key => text()();

  /// The value public API member.
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}

/// User-owned provider connections.
class ProviderConnections extends Table {
  /// The id public API member.
  TextColumn get id => text()();

  /// Built-in definition identifier, or `custom`.
  TextColumn get definitionId => text()();

  /// Globally unique prefix used by qualified model identifiers.
  TextColumn get modelPrefix => text().unique()();

  /// Human-readable connection name.
  TextColumn get displayName => text()();

  /// Current connection state.
  TextColumn get status => text()();

  /// Active authentication kind.
  TextColumn get authKind => text()();

  /// Non-secret credential origin.
  TextColumn get credentialOrigin => text()();

  /// Last user-safe connection error.
  TextColumn get error => text().nullable()();

  /// Advanced custom configuration, never used by built-in definitions.
  TextColumn get customConfigJson => text().nullable()();

  /// The createdAt public API member.
  DateTimeColumn get createdAt => dateTime()();

  /// The updatedAt public API member.
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// ProviderModels defines a public contract.
class ProviderModels extends Table {
  /// Owning provider connection.
  TextColumn get connectionId => text().references(ProviderConnections, #id)();

  /// The modelId public API member.
  TextColumn get modelId => text()();

  /// Model identifier sent to the upstream provider.
  TextColumn get providerModelId => text()();

  /// The label public API member.
  TextColumn get label => text()();

  /// The source public API member.
  TextColumn get source => text()();

  /// The capabilitiesJson public API member.
  TextColumn get capabilitiesJson => text()();

  /// Optional model pricing metadata.
  TextColumn get pricingJson => text().nullable()();

  /// Optional model token-limit metadata.
  TextColumn get limitsJson => text().nullable()();

  /// The diagnosticStatus public API member.
  TextColumn get diagnosticStatus =>
      text().withDefault(const Constant('unknown'))();

  /// The verifiedAt public API member.
  DateTimeColumn get verifiedAt => dateTime().nullable()();

  /// The diagnosticError public API member.
  TextColumn get diagnosticError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{connectionId, modelId};
}

@DriftDatabase(
  tables: <Type>[
    Workspaces,
    Worktrees,
    Sessions,
    Turns,
    AgentMailboxMessages,
    Attachments,
    TurnAttachments,
    TimelineEvents,
    ApprovalRequests,
    UserQuestions,
    ProviderStates,
    Settings,
    ProviderConnections,
    ProviderModels,
  ],
  daos: <Type>[
    SettingsDao,
    WorkspaceDao,
    WorktreeDao,
    SessionDao,
    AgentMailboxDao,
    AttachmentDao,
    TimelineDao,
    ProviderDao,
    RuntimeDao,
  ],
)
/// TinestDatabase defines a public contract.
class TinestDatabase extends _$TinestDatabase {
  /// Creates a [TinestDatabase].
  new(String path, {this.clock = const SystemClock()})
    : databasePath = path,
      super(NativeDatabase.createInBackground(File(path)));

  /// The TinestDatabaseforTesting public API member.
  new forTesting(super.e, {this.clock = const SystemClock()})
    : databasePath = '<memory>';

  /// The clock public API member.
  final Clock clock;

  /// SQLite path included in explicit incompatible-schema guidance.
  final String databasePath;

  @override
  int get schemaVersion => 21;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) => throw StateError(
      'incompatible_database: schema $from cannot be opened as schema $to. '
      'Stop the daemon and explicitly remove $databasePath to reset '
      'development data.',
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
