import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/shared/presentation/tinest_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// What a piece of work is doing, independent of how it is drawn.
///
/// This is the vocabulary a plugin document states and the host resolves. A
/// plugin never names a glyph or a colour: a design-system change would strand
/// every plugin that had, and a glyph a plugin wanted but the host had never
/// heard of would need a daemon release to draw. It is deliberately not
/// collaboration-specific — a build, a download, and a scheduled job all fit.
enum TinestStatus {
  /// Queued, not started.
  pending,

  /// Working.
  running,

  /// Parked on a decision only the user can make.
  blocked,

  /// Stopped on request.
  paused,

  /// Finished successfully.
  done,

  /// Finished with an error.
  failed,
}

/// Resolves [name] as a wire status, or null when it names nothing.
///
/// The wire spelling matches the enum name, so a plugin writes `"running"`.
TinestStatus? tinestStatusFromName(String name) {
  for (final status in TinestStatus.values) {
    if (status.name == name) return status;
  }
  return null;
}

/// The host's reading of one [TinestStatus]: a spinner while work moves, an
/// attention icon while it waits on the user, a status icon once it stopped.
class TinestStatusIcon extends StatelessWidget {
  /// Creates a status indicator.
  const TinestStatusIcon({required this.status, super.key});

  /// The meaning to draw.
  final TinestStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.tinyrackTheme;
    return switch (status) {
      TinestStatus.pending => TRSpinner(
        variant: TRSpinnerVariant.muted,
        label: l10n.statusPending,
      ),
      TinestStatus.running => TRSpinner(
        variant: TRSpinnerVariant.muted,
        label: l10n.statusRunning,
      ),
      TinestStatus.blocked => Icon(
        TinestIcons.approvalPending,
        color: colors.warningForeground,
        semanticLabel: l10n.statusBlocked,
      ),
      TinestStatus.paused => Icon(
        TinestIcons.paused,
        color: colors.textMuted,
        semanticLabel: l10n.statusPaused,
      ),
      TinestStatus.done => Icon(
        TinestIcons.success,
        color: colors.textMuted,
        semanticLabel: l10n.statusDone,
      ),
      TinestStatus.failed => Icon(
        TinestIcons.error,
        color: colors.dangerForeground,
        semanticLabel: l10n.statusFailed,
      ),
    };
  }
}
