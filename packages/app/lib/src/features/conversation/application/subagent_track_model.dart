import 'package:protocol/protocol.dart';

/// One row of the subagent track: a descendant session with its tree depth.
final class SubagentTrackRow {
  /// Creates a track row.
  const SubagentTrackRow({required this.session, required this.depth});

  /// The subagent session behind this row.
  final SessionDto session;

  /// Nesting depth below the root session; direct children are depth zero.
  final int depth;

  /// Display label: the collaboration task name, else the session title.
  String get label => session.taskName ?? session.title;
}

/// Whether [session] is a spawned subagent rather than a root session.
bool isSubagentSession(SessionDto session) => session.parentSessionId != null;

/// Depth-first descendants of [rootId] in [sessions], creation-ordered
/// within each parent.
List<SubagentTrackRow> buildSubagentTrackRows(
  List<SessionDto> sessions,
  String rootId,
) {
  final childrenByParent = <String, List<SessionDto>>{};
  for (final session in sessions) {
    final parentId = session.parentSessionId;
    if (parentId == null) continue;
    childrenByParent.putIfAbsent(parentId, () => <SessionDto>[]).add(session);
  }
  for (final children in childrenByParent.values) {
    children.sort((left, right) => left.createdAt.compareTo(right.createdAt));
  }
  final rows = <SubagentTrackRow>[];
  void visit(String parentId, int depth, Set<String> seen) {
    for (final child in childrenByParent[parentId] ?? const <SessionDto>[]) {
      if (!seen.add(child.id)) continue;
      rows.add(SubagentTrackRow(session: child, depth: depth));
      visit(child.id, depth + 1, seen);
    }
  }

  visit(rootId, 0, <String>{rootId});
  return List<SubagentTrackRow>.unmodifiable(rows);
}

/// Rows parked on an approval only the user can answer.
List<SubagentTrackRow> blockedSubagentRows(List<SubagentTrackRow> rows) =>
    List<SubagentTrackRow>.unmodifiable(
      rows.where(
        (row) => row.session.status == SessionStatus.waitingForApproval,
      ),
    );
