import 'package:agent/src/model.dart';

/// One request to start a fresh Lua orchestration cell.
final class LuaExecuteRequest {
  /// Creates an execution request.
  const new({
    required this.source,
    required this.yieldTime,
    required this.maxOutputTokens,
    required this.tools,
  });

  /// User-authored Lua source.
  final String source;

  /// Time to observe the cell before yielding it as running.
  final Duration yieldTime;

  /// Output budget for this response.
  final int maxOutputTokens;

  /// Metadata for callable nested tools.
  final List<LuaNestedToolDefinition> tools;
}

/// One request for an existing cell.
final class LuaWaitRequest {
  /// Creates a wait request.
  const new({
    required this.cellId,
    required this.yieldTime,
    required this.maxOutputTokens,
    required this.terminate,
  });

  /// Session-local cell identifier.
  final String cellId;

  /// Maximum observation time.
  final Duration yieldTime;

  /// Output budget for this response.
  final int maxOutputTokens;

  /// Whether to terminate the cell.
  final bool terminate;
}

/// Provider-neutral metadata for one nested tool.
final class LuaNestedToolDefinition {
  /// Creates a nested tool definition.
  const new({
    required this.name,
    required this.description,
    required this.kind,
    required this.exposure,
    required this.inputSchema,
    this.namespace,
    this.outputSchema,
  });

  /// Exact dispatcher name.
  final String name;

  /// Human-readable behavior.
  final String description;

  /// Wire declaration kind.
  final String kind;

  /// Optional namespace.
  final String? namespace;

  /// Advertised or deferred exposure.
  final String exposure;

  /// JSON argument schema.
  final Map<String, dynamic> inputSchema;

  /// Optional structured result schema.
  final Map<String, dynamic>? outputSchema;
}

/// Structured result from a nested Lua tool dispatch.
final class LuaNestedToolResult {
  /// Creates a nested result.
  const new({
    required this.value,
    this.isError = false,
    this.content = const <Map<String, Object?>>[],
    this.structuredContent,
    this.meta = const <String, dynamic>{},
    this.attachments = const <ConversationAttachment>[],
    this.contextImages = const <ConversationAttachment>[],
  });

  /// Scalar or structured tool result.
  final Object? value;

  /// Whether the tool reported an isolated failure.
  final bool isError;

  /// Provider-neutral content blocks serialized as JSON.
  final List<Map<String, Object?>> content;

  /// Optional provider-owned structured content.
  final Object? structuredContent;

  /// Optional provider metadata.
  final Map<String, dynamic> meta;

  /// Files published for the user.
  final List<ConversationAttachment> attachments;

  /// Images forwarded into model context.
  final List<ConversationAttachment> contextImages;
}

/// Dispatches tools selected for one Lua execution.
abstract interface class LuaNestedToolInvoker {
  /// Runs [name] through the host's normal approval and cancellation path.
  Future<LuaNestedToolResult> invoke(
    String name,
    Map<String, dynamic> arguments,
  );
}

/// Host-owned dependencies for one Lua cell call.
final class LuaCodeModeContext {
  /// Creates an invocation context.
  const new({required this.cancellation, required this.tools});

  /// Turn cancellation signal.
  final CancellationToken cancellation;

  /// Revision-pinned nested tool dispatcher.
  final LuaNestedToolInvoker tools;
}

/// Output drained from one Lua cell.
final class LuaCellChunk {
  /// Creates a cell result.
  const new({
    required this.cellId,
    required this.output,
    this.running = false,
    this.terminated = false,
    this.error,
    this.attachments = const <ConversationAttachment>[],
    this.contextImages = const <ConversationAttachment>[],
    this.notifications = const <Object?>[],
  });

  /// Session-local cell identifier.
  final String cellId;

  /// Output produced since the previous drain.
  final String output;

  /// Whether the cell remains alive.
  final bool running;

  /// Whether explicit termination produced this result.
  final bool terminated;

  /// Script or host failure.
  final String? error;

  /// Published files.
  final List<ConversationAttachment> attachments;

  /// Images forwarded into model context.
  final List<ConversationAttachment> contextImages;

  /// Immediate notification values.
  final List<Object?> notifications;
}

/// Session-scoped host for Lua orchestration cells.
abstract interface class LuaCodeModeHost {
  /// Starts a new cell.
  Future<LuaCellChunk> execute(
    LuaExecuteRequest request,
    LuaCodeModeContext context,
  );

  /// Observes or terminates an existing cell.
  Future<LuaCellChunk> wait(LuaWaitRequest request, LuaCodeModeContext context);
}
