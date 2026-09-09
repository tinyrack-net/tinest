import 'package:app/src/shared/presentation/tinest_status_icon.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';

/// The lifecycle indicator of one subagent.
///
/// Only the reading of a session's two status axes lives here; the drawing is
/// [TinestStatusIcon], shared with every other surface that reports work.
class SubagentStatusIcon extends StatelessWidget {
  /// Creates a lifecycle indicator.
  const new({required this.lifecycle, this.status, super.key});

  /// The lifecycle to render; null renders as pending.
  final AgentLifecycle? lifecycle;

  /// The session status, which distinguishes a subagent that is working from
  /// one parked on an approval only the user can answer.
  final SessionStatus? status;

  @override
  Widget build(BuildContext context) =>
      TinestStatusIcon(status: subagentStatusOf(lifecycle, status));
}

/// Reads a session's two status axes as one meaning.
///
/// A blocked subagent is still `running`, so the lifecycle alone would render
/// it as a spinner and hide the one row the user has to act on.
TinestStatus subagentStatusOf(
  AgentLifecycle? lifecycle,
  SessionStatus? status,
) {
  if (status == SessionStatus.waitingForApproval) return TinestStatus.blocked;
  return switch (lifecycle) {
    AgentLifecycle.pendingInit || null => TinestStatus.pending,
    AgentLifecycle.running => TinestStatus.running,
    AgentLifecycle.interrupted => TinestStatus.paused,
    AgentLifecycle.completed => TinestStatus.done,
    AgentLifecycle.errored => TinestStatus.failed,
  };
}
