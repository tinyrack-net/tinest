import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/features/conversation/application/conversation_controller.dart';
import 'package:app/src/features/conversation/application/subagent_track_model.dart';
import 'package:app/src/features/conversation/presentation/chat_approval_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Approvals of descendant subagents, docked above the parent's composer.
///
/// A subagent's approval is written to the subagent's own session, so it is
/// only actionable from that tab, and the daemon parks the child's turn on an
/// unbounded wait until someone answers. Surfacing the request where the user
/// already is keeps a whole tree from stalling behind a card nobody opened.
///
/// Watching a descendant's conversation is also what subscribes its timeline,
/// which is what makes the daemon deliver its approvals to this client at all.
class SubagentApprovalBanner extends ConsumerWidget {
  /// Creates a [SubagentApprovalBanner].
  const new({
    required this.hostId,
    required this.rows,
    required this.maxHeight,
    super.key,
  });

  /// Stable host profile owning the sessions.
  final String hostId;

  /// Descendants parked on an approval; see [blockedSubagentRows].
  final List<SubagentTrackRow> rows;

  /// Viewport-derived bound, so the cards never squeeze the input out.
  final double maxHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final pending = <({SubagentTrackRow row, ApprovalRequestDto approval})>[];
    for (final row in rows) {
      final conversation = ref.watch(
        conversationControllerProvider(hostId, row.session.id),
      );
      for (final approval
          in conversation.asData?.value.approvals.values ??
              const <ApprovalRequestDto>[]) {
        pending.add((row: row, approval: approval));
      }
    }
    if (pending.isEmpty) return const SizedBox.shrink();
    // Oldest first: the request that has been holding its agent the longest is
    // the one to answer first, and a map's order is not stable across rebuilds.
    // The id breaks ties, because `List.sort` is not stable and two agents can
    // block on the same instant.
    pending.sort((left, right) {
      final byAge = left.approval.createdAt.compareTo(right.approval.createdAt);
      return byAge != 0 ? byAge : left.approval.id.compareTo(right.approval.id);
    });
    return ConstrainedBox(
      key: const ValueKey('subagent-approval-banner'),
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: TRScrollArea(
        semanticLabel: l10n.subagentApprovalSection,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TRText(
              l10n.subagentApprovalSection,
              variant: TRTextVariant.label,
              color: TRTextColor.muted,
            ),
            for (final entry in pending) ...<Widget>[
              // The parent runs its own tools, so an unattributed card would
              // not say which agent is blocked.
              TRText(
                entry.row.session.agentPath ?? entry.row.label,
                variant: TRTextVariant.label,
                color: TRTextColor.muted,
              ),
              ApprovalCard(
                key: ValueKey('subagent-approval-${entry.approval.id}'),
                hostId: hostId,
                approval: entry.approval,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
