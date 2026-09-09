import 'package:protocol/protocol.dart';

/// Hard safety-kernel bounds for public plugin network operations.
abstract final class PluginNetworkLimits {
  /// Maximum UTF-8 bytes accepted in a URL.
  static const int maximumUrlBytes = 8192;

  /// Maximum number of request header fields.
  static const int maximumHeaderCount = 64;

  /// Maximum combined UTF-8 bytes accepted across request/response headers.
  static const int maximumHeaderBytes = 32768;

  /// Maximum request payload copied from Lua into the network adapter.
  static const int maximumRequestBodyBytes = 65536;

  /// Maximum response payload copied from the adapter back into Lua.
  static const int maximumResponseBodyBytes = 524288;

  /// Longest wall timeout one plugin request may select.
  static const Duration maximumTimeout = Duration(seconds: 60);

  /// Default wall timeout when Lua does not select one.
  static const Duration defaultTimeout = Duration(seconds: 30);
}

/// Cancellation boundary shared by a Lua invocation and host I/O adapter.
abstract interface class PluginOperationCancellation {
  /// Whether cancellation has already been requested.
  bool get isCancelled;

  /// Registers cleanup, firing immediately when already cancelled.
  void onCancel(void Function() callback);
}

/// Raised by a host adapter after it stops I/O because its invocation ended.
final class PluginHostOperationCancelledException implements Exception {
  /// Creates the cancellation sentinel.
  const new();
}

/// One bounded HTTP request issued by an authorized Lua plugin.
final class PluginNetworkRequest {
  /// Creates an immutable request after safety-kernel validation.
  new({
    required this.uri,
    required this.method,
    required Map<String, String> headers,
    required List<int> body,
    required this.timeout,
    required this.maximumResponseBytes,
  }) : headers = Map<String, String>.unmodifiable(headers),
       body = List<int>.unmodifiable(body);

  /// Absolute HTTP(S) endpoint without embedded credentials.
  final Uri uri;

  /// Uppercase HTTP method.
  final String method;

  /// Bounded request headers.
  final Map<String, String> headers;

  /// Bounded request body bytes.
  final List<int> body;

  /// Wall deadline no longer than [PluginNetworkLimits.maximumTimeout].
  final Duration timeout;

  /// Caller-selected response limit under the host maximum.
  final int maximumResponseBytes;
}

/// One bounded HTTP response returned to the Lua safety kernel.
final class PluginNetworkResponse {
  /// Creates an immutable response.
  new({
    required this.statusCode,
    required Map<String, List<String>> headers,
    required List<int> body,
  }) : headers = Map<String, List<String>>.unmodifiable(<String, List<String>>{
         for (final entry in headers.entries)
           entry.key: List<String>.unmodifiable(entry.value),
       }),
       body = List<int>.unmodifiable(body);

  /// HTTP status code.
  final int statusCode;

  /// Response headers without transport-specific objects.
  final Map<String, List<String>> headers;

  /// Response bytes, rechecked by the safety kernel before Lua sees them.
  final List<int> body;
}

/// Typed transport boundary for public `tinest.host.network` calls.
abstract interface class PluginNetworkGateway {
  /// Sends one bounded request and stops its I/O on [cancellation].
  Future<PluginNetworkResponse> send(
    PluginNetworkRequest request,
    PluginOperationCancellation cancellation,
  );
}

/// Exact secret namespace derived by the host, never accepted from Lua.
final class PluginSecretScope {
  /// Creates an Agent/plugin-isolated secret namespace.
  const new({required this.agentId, required this.pluginId});

  /// Agent definition that owns the secret.
  final String agentId;

  /// Plugin that may read the secret.
  final String pluginId;
}

/// Read-only secret boundary exposed to the Lua safety kernel.
abstract interface class PluginSecretStore {
  /// Reads an exact name in [scope], or null without revealing other scopes.
  Future<String?> read(PluginSecretScope scope, String name);
}

/// Hard safety-kernel bounds for plugin secret names and values.
abstract final class PluginSecretLimits {
  /// Maximum UTF-8 bytes in one secret name.
  static const int maximumNameBytes = 128;

  /// Maximum UTF-8 bytes copied into a Lua invocation.
  static const int maximumValueBytes = 65536;
}

/// Host-management boundary used to provision plugin secrets.
abstract interface class PluginSecretVault implements PluginSecretStore {
  /// Stores one bounded secret in an exact Agent/plugin namespace.
  Future<void> set(PluginSecretScope scope, String name, String value);

  /// Removes one exact secret without exposing whether another scope has it.
  Future<void> remove(PluginSecretScope scope, String name);
}

/// Persistence boundary for per-Agent plugin capability grants.
abstract interface class AgentPluginGrantStore {
  /// Emits an exact grant after a durable revoke removes it.
  Stream<AgentPluginGrantDto> get revocations;

  /// Lists all grants belonging to [agentId].
  Future<List<AgentPluginGrantDto>> list(String agentId);

  /// Whether the exact three-part grant key exists.
  Future<bool> isGranted(AgentPluginGrantDto grant);

  /// Adds an idempotent grant.
  Future<void> grant(AgentPluginGrantDto grant);

  /// Removes an idempotent grant.
  Future<void> revoke(AgentPluginGrantDto grant);
}

/// Supported durable state scopes exposed to Lua plugins.
enum PluginStateScopeKind {
  /// Shared by every use of one plugin revision family.
  plugin,

  /// Isolated to one Agent definition.
  agent,

  /// Isolated to one session.
  session,

  /// Isolated to one registered workspace.
  workspace,
}

/// Stable identity of one plugin JSON state namespace.
final class PluginStateScope {
  /// Creates plugin-global state.
  const new plugin({required this.pluginId})
    : kind = PluginStateScopeKind.plugin,
      ownerId = null;

  /// Creates state isolated to one Agent.
  const new agent({required this.pluginId, required String agentId})
    : kind = PluginStateScopeKind.agent,
      ownerId = agentId;

  /// Creates state isolated to one session.
  const new session({required this.pluginId, required String sessionId})
    : kind = PluginStateScopeKind.session,
      ownerId = sessionId;

  /// Creates state isolated to one workspace.
  const new workspace({required this.pluginId, required String workspaceId})
    : kind = PluginStateScopeKind.workspace,
      ownerId = workspaceId;

  /// Plugin that owns the namespace.
  final String pluginId;

  /// Scope kind.
  final PluginStateScopeKind kind;

  /// Entity identity for every non-plugin scope.
  final String? ownerId;

  /// Stable storage key used by persistence adapters.
  String get storageKey => '$pluginId/${kind.name}/${ownerId ?? ''}';
}

/// One versioned JSON value in plugin state.
final class PluginStateEntry {
  /// Creates a state entry.
  const new({required this.revision, required this.value});

  /// Monotonically increasing compare-and-set revision.
  final int revision;

  /// JSON-compatible value.
  final Object? value;
}

/// Encodes one state read without relying on a transport-specific null value.
///
/// Lua tables cannot preserve every JSON null distinction across the isolated
/// host protocol. Keeping absence explicit also lets plugins store JSON null as
/// an ordinary present value.
Map<String, Object?> pluginStateReadEnvelope(PluginStateEntry? entry) =>
    entry == null
    ? const <String, Object?>{'found': false}
    : <String, Object?>{
        'found': true,
        'revision': entry.revision,
        'value': entry.value,
      };

/// One compare-and-set mutation in an atomic transaction.
final class PluginStateMutation {
  /// Creates a put mutation.
  const new put({
    required this.key,
    required this.expectedRevision,
    required this.value,
  }) : remove = false;

  /// Creates a remove mutation.
  const new remove({required this.key, required this.expectedRevision})
    : value = null,
      remove = true;

  /// State key.
  final String key;

  /// Revision that must still be current, where zero means absent.
  final int expectedRevision;

  /// Replacement JSON value.
  final Object? value;

  /// Whether this mutation removes rather than replaces the entry.
  final bool remove;
}

/// Raised when a plugin state compare-and-set observes another writer.
final class PluginStateConflict implements Exception {
  /// Creates a state conflict.
  const new({
    required this.key,
    required this.expectedRevision,
    required this.actualRevision,
  });

  /// Conflicting key.
  final String key;

  /// Revision supplied by the caller.
  final int expectedRevision;

  /// Revision found by the store.
  final int actualRevision;
}

/// Atomic JSON KV boundary exposed through `tinest.state`.
abstract interface class PluginStateStore {
  /// Reads one key, or null when absent.
  Future<PluginStateEntry?> read(PluginStateScope scope, String key);

  /// Writes one key when [expectedRevision] still matches.
  Future<PluginStateEntry> compareAndSet(
    PluginStateScope scope,
    String key, {
    required int expectedRevision,
    required Object? value,
  });

  /// Reads a consistent scope snapshot and atomically applies returned edits.
  Future<Map<String, PluginStateEntry>> transaction(
    PluginStateScope scope,
    List<PluginStateMutation> Function(Map<String, PluginStateEntry> values)
    buildMutations,
  );
}

/// Lifecycle of one daemon-owned durable plugin handler job.
enum PluginJobStatus {
  /// Waiting until its due time.
  pending,

  /// Claimed by one scheduler lease.
  running,

  /// Handler finished successfully.
  completed,

  /// Handler finished unsuccessfully.
  failed,

  /// An owning plugin cancelled the job before it was claimed.
  cancelled,
}

/// Durable scheduler record for a named plugin handler.
final class PluginJob {
  /// Creates a job.
  const new({
    required this.id,
    required this.pluginId,
    required this.executionRevisionHash,
    required this.bindingId,
    required this.payload,
    required this.dueAt,
    this.agentId,
    this.sessionId,
    this.status = PluginJobStatus.pending,
    this.leaseId,
    this.leaseExpiresAt,
    this.error,
  });

  /// Stable job ID.
  final String id;

  /// Owning plugin.
  final String pluginId;

  /// Exact plugin SDK and content revision used to create the job.
  final String executionRevisionHash;

  /// Deterministic SDK-owned scheduled-handler binding ID.
  final String bindingId;

  /// JSON-compatible handler payload.
  final Map<String, dynamic> payload;

  /// Earliest scheduler time.
  final DateTime dueAt;

  /// Optional Agent isolation key.
  final String? agentId;

  /// Optional session isolation key.
  final String? sessionId;

  /// Current durable lifecycle.
  final PluginJobStatus status;

  /// Scheduler lease that owns a running job.
  final String? leaseId;

  /// Time after which another scheduler may reclaim a running job.
  final DateTime? leaseExpiresAt;

  /// Bounded failure description.
  final String? error;

  /// Returns a copy with explicitly supplied lifecycle fields.
  PluginJob withLifecycle({
    required PluginJobStatus status,
    String? leaseId,
    DateTime? leaseExpiresAt,
    String? error,
  }) => PluginJob(
    id: id,
    pluginId: pluginId,
    executionRevisionHash: executionRevisionHash,
    bindingId: bindingId,
    payload: payload,
    dueAt: dueAt,
    agentId: agentId,
    sessionId: sessionId,
    status: status,
    leaseId: leaseId,
    leaseExpiresAt: leaseExpiresAt,
    error: error,
  );
}

/// Raised when a scheduler tries to resolve a job owned by another lease.
final class PluginJobLeaseConflict implements Exception {
  /// Creates a lease conflict.
  const new(this.jobId);

  /// Conflicting job.
  final String jobId;
}

/// Persistence boundary for durable plugin scheduler jobs.
abstract interface class PluginJobStore {
  /// Adds a new pending job.
  Future<void> enqueue(PluginJob job);

  /// Reads one job.
  Future<PluginJob?> get(String id);

  /// Atomically cancels an unclaimed job owned by the exact plugin context.
  ///
  /// Returns false for missing, foreign, already claimed, or terminal jobs so
  /// callers cannot probe another plugin's durable queue.
  Future<bool> cancel(
    String id, {
    required String pluginId,
    required String agentId,
    required String sessionId,
  });

  /// Claims the first due job using deterministic due-time and ID ordering.
  Future<PluginJob?> claimNext({
    required DateTime now,
    required String leaseId,
    Duration leaseDuration = const Duration(minutes: 5),
  });

  /// Returns a leased job to the pending queue without losing it.
  Future<void> release(String id, {required String leaseId});

  /// Marks a leased job complete.
  Future<void> complete(String id, {required String leaseId});

  /// Marks a leased job failed.
  Future<void> fail(
    String id, {
    required String leaseId,
    required String error,
  });
}
