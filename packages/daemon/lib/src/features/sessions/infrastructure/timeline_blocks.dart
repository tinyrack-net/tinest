import 'package:agent/agent.dart';
import 'package:daemon/src/shared/infrastructure/persistence/repositories.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:protocol/protocol.dart';

/// Timeline event types whose payload belongs to a streamed prose block.
const String _proseDelta = 'assistant.delta';

/// Timeline event types whose payload belongs to a streamed reasoning block.
const Set<String> _reasoningTypes = <String>{
  'assistant.reasoning.started',
  'assistant.reasoning.delta',
};

/// Payload key carrying the identity of the block an event belongs to.
const String blockIdKey = 'blockId';

/// Names each streamed block of a turn so a reader can identify it from any
/// one of its events.
///
/// A streamed answer is one stored row per delta and routinely outgrows a
/// history page, so the daemon splits it and the oldest row a reader has
/// loaded is half a block. A reader that derives the block's identity from the
/// oldest delta it happens to hold renames that row every time an older page
/// lands — which, to a list anchored by identity, is the row being deleted out
/// from under the reader. Only the writer sees the whole block, so only the
/// writer can name it.
///
/// One block is open per turn per kind. Anything else closes it: prose and
/// reasoning interrupt each other, and a tool call, a user message or the end
/// of the turn ends both. That close rule is also what bounds this: a turn
/// always ends on an event that is not a delta, so no turn stays open.
class TimelineBlockStamper {
  /// Creates a [TimelineBlockStamper].
  new({required this._ids});

  final IdGenerator _ids;
  final Map<String, String> _openProse = <String, String>{};
  final Map<String, String> _openReasoning = <String, String>{};

  /// Blocks still open, which is one per turn that is mid-stream.
  int get openBlockCount => _openProse.length + _openReasoning.length;

  /// Returns [data] carrying the identity of the block [type] belongs to.
  ///
  /// An event outside any block is returned unchanged, so the payload of a
  /// tool call or a user message stays exactly what its writer built.
  Map<String, dynamic> stamp({
    required String? turnId,
    required String type,
    required Map<String, dynamic> data,
  }) {
    // A block belongs to a turn. An event without one cannot be grouped with
    // anything, so it opens nothing and closes nothing.
    if (turnId == null) return data;
    final isProse = type == _proseDelta;
    final isReasoning = _reasoningTypes.contains(type);
    if (!isProse) _openProse.remove(turnId);
    if (!isReasoning) _openReasoning.remove(turnId);
    if (!isProse && !isReasoning) return data;
    final open = isProse ? _openProse : _openReasoning;
    final blockId = open[turnId] ??= _ids.generate();
    return <String, dynamic>{...data, blockIdKey: blockId};
  }
}

/// The session timeline, with every appended event named by its block.
///
/// A decorator rather than a call at each writing service: a block is closed
/// by whatever is written next, so a service that appended straight to the
/// store would end a block without saying so and let the next delta rejoin one
/// the reader has already drawn as finished. Sharing one of these is what
/// makes the rule total.
final class BlockStampingTimelineRepository implements TimelineRepository {
  /// Creates a [BlockStampingTimelineRepository].
  new({required this._inner, required IdGenerator ids})
    : _blocks = TimelineBlockStamper(ids: ids);

  final TimelineRepository _inner;
  final TimelineBlockStamper _blocks;

  @override
  Future<TimelineEventDto> append({
    required String sessionId,
    required String type,
    required Map<String, dynamic> data,
    String? turnId,
  }) => _inner.append(
    sessionId: sessionId,
    type: type,
    turnId: turnId,
    data: _blocks.stamp(turnId: turnId, type: type, data: data),
  );

  @override
  Future<List<TimelineEventDto>> after(String sessionId, int sequence) =>
      _inner.after(sessionId, sequence);

  @override
  Future<List<TimelineEventDto>> tail(
    String sessionId,
    int sequence, {
    required int limit,
  }) => _inner.tail(sessionId, sequence, limit: limit);

  @override
  Future<List<TimelineEventDto>> before(
    String sessionId,
    int sequence, {
    required int limit,
  }) => _inner.before(sessionId, sequence, limit: limit);

  @override
  Future<void> appendProviderItems(
    String sessionId,
    List<ConversationItem> items,
  ) => _inner.appendProviderItems(sessionId, items);

  @override
  Future<List<ConversationItem>> providerHistory(String sessionId) =>
      _inner.providerHistory(sessionId);

  @override
  Future<void> resetContextWindow(
    String sessionId,
    List<ConversationItem> retain,
  ) => _inner.resetContextWindow(sessionId, retain);

  @override
  Future<void> createApproval(ApprovalRequestDto approval) =>
      _inner.createApproval(approval);

  @override
  Future<ApprovalRequestDto?> resolveApproval(
    String id,
    ApprovalStatus status,
  ) => _inner.resolveApproval(id, status);

  @override
  Future<void> createUserQuestion(UserQuestionRequestDto request) =>
      _inner.createUserQuestion(request);

  @override
  Future<UserQuestionRequestDto?> getUserQuestion(String id) =>
      _inner.getUserQuestion(id);

  @override
  Future<UserQuestionRequestDto?> answerUserQuestion(
    String id,
    UserQuestionStatus status,
    List<UserQuestionAnswerDto> answers,
  ) => _inner.answerUserQuestion(id, status, answers);
}
