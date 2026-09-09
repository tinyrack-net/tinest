import 'package:flutter/widgets.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Shape-preserving placeholders for asynchronous workspace surfaces.
///
/// Every workspace surface renders immediately with the silhouette of its
/// loaded form and swaps to real content when data arrives, mirroring the
/// settings skeleton contract in `settings_layout.dart`: one labelled,
/// inert placeholder per surface, announced once as a live region.
class WorkspacePaneSkeleton extends StatelessWidget {
  /// Creates a placeholder for a workspace tab pane.
  const new({required this.semanticLabel, super.key});

  /// Accessible description announced once for the complete placeholder.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    container: true,
    liveRegion: true,
    child: const ExcludeSemantics(
      child: Column(
        key: ValueKey<String>('workspace-pane-skeleton'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: TRSpacing.medium,
              vertical: TRSpacing.small,
            ),
            child: Row(
              children: <Widget>[
                TRSkeleton(width: TRMeasurements.measureXs),
                SizedBox(width: TRSpacing.large),
                TRSkeleton(width: TRMeasurements.measureXs),
              ],
            ),
          ),
          TRSeparator(variant: TRSeparatorVariant.muted),
          Expanded(child: _StaggeredTextLines()),
        ],
      ),
    ),
  );
}

/// A placeholder for a conversation timeline whose history is still loading.
class ChatTimelineSkeleton extends StatelessWidget {
  /// Creates a placeholder shaped like alternating chat turns.
  const new({required this.semanticLabel, super.key});

  /// Accessible description announced once for the complete placeholder.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    container: true,
    liveRegion: true,
    child: ExcludeSemantics(
      // A ListView, not a Column: the placeholder must degrade by clipping
      // its tail on a short surface instead of overflowing.
      child: ListView(
        key: const ValueKey<String>('chat-timeline-skeleton'),
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: TRSpacing.extraLarge,
          vertical: TRSpacing.large,
        ),
        children: const <Widget>[
          _ChatTurnSkeleton.user(),
          SizedBox(height: TRSpacing.extraLarge),
          _ChatTurnSkeleton.assistant(),
          SizedBox(height: TRSpacing.extraLarge),
          _ChatTurnSkeleton.user(),
          SizedBox(height: TRSpacing.extraLarge),
          _ChatTurnSkeleton.assistant(),
        ],
      ),
    ),
  );
}

class _ChatTurnSkeleton extends StatelessWidget {
  const new user() : _user = true;

  const new assistant() : _user = false;

  final bool _user;

  @override
  Widget build(BuildContext context) {
    if (_user) {
      return const Align(
        alignment: AlignmentDirectional.centerEnd,
        child: TRSkeleton(
          shape: TRSkeletonShape.rectangle,
          width: TRMeasurements.measureMd,
        ),
      );
    }
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TRSkeleton(width: TRMeasurements.measureXl),
        SizedBox(height: TRSpacing.small),
        TRSkeleton(width: TRMeasurements.measureLg),
        SizedBox(height: TRSpacing.small),
        TRSkeleton(width: TRMeasurements.measureMd),
      ],
    );
  }
}

/// A visible connecting state layered over a terminal's future scrollback.
///
/// The terminal grid mounts immediately; this overlay names why input is not
/// accepted yet, instead of leaving an empty prompt that swallows keystrokes.
class TerminalConnectingOverlay extends StatelessWidget {
  /// Creates a terminal attach placeholder.
  const new({required this.semanticLabel, required this.message, super.key});

  /// Accessible description announced once for the complete placeholder.
  final String semanticLabel;

  /// Visible label naming the pending attachment.
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    container: true,
    liveRegion: true,
    child: ExcludeSemantics(
      child: Stack(
        key: const ValueKey<String>('terminal-connecting'),
        children: <Widget>[
          Positioned.fill(
            // A ListView, not a Column: the faux scrollback must degrade by
            // clipping on a short pane instead of overflowing.
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(TRSpacing.large),
              children: const <Widget>[
                TRSkeleton(width: TRMeasurements.measureLg),
                SizedBox(height: TRSpacing.small),
                TRSkeleton(width: TRMeasurements.measureSm),
                SizedBox(height: TRSpacing.small),
                TRSkeleton(width: TRMeasurements.measureMd),
                SizedBox(height: TRSpacing.small),
                TRSkeleton(width: TRMeasurements.measureXs),
              ],
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const TRSpinner(),
                const SizedBox(height: TRSpacing.small),
                TRText(
                  message,
                  variant: TRTextVariant.bodySm,
                  color: TRTextColor.muted,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// A placeholder for the workspace sidebar tree while catalogs load.
class SidebarTreeSkeleton extends StatelessWidget {
  /// Creates a sidebar tree placeholder.
  const new({required this.semanticLabel, super.key});

  /// Accessible description announced once for the complete placeholder.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    container: true,
    liveRegion: true,
    child: ExcludeSemantics(
      // A ListView, not a Column: the placeholder must degrade by clipping
      // its tail on a short surface instead of overflowing.
      child: ListView(
        key: const ValueKey<String>('workspace-sidebar-skeleton'),
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: TRSpacing.large,
          vertical: TRSpacing.medium,
        ),
        children: const <Widget>[
          _SidebarProjectSkeleton(),
          SizedBox(height: TRSpacing.large),
          _SidebarProjectSkeleton(),
        ],
      ),
    ),
  );
}

class _SidebarProjectSkeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      TRSkeleton(width: TRMeasurements.measureSm),
      SizedBox(height: TRSpacing.small),
      Padding(
        padding: EdgeInsetsDirectional.only(start: TRSpacing.extraLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TRSkeleton(width: TRMeasurements.measureXs),
            SizedBox(height: TRSpacing.small),
            TRSkeleton(width: TRMeasurements.measureXs),
          ],
        ),
      ),
    ],
  );
}

/// A generic placeholder for a flat list whose rows are still loading.
class ListRowsSkeleton extends StatelessWidget {
  /// Creates a list placeholder with [rows] single-line rows.
  const new({required this.semanticLabel, this.rows = 8, super.key});

  /// Accessible description announced once for the complete placeholder.
  final String semanticLabel;

  /// Number of placeholder rows.
  final int rows;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    container: true,
    liveRegion: true,
    child: ExcludeSemantics(
      child: Column(
        key: const ValueKey<String>('list-rows-skeleton'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (var index = 0; index < rows; index++) ...<Widget>[
            if (index > 0) const SizedBox(height: TRSpacing.medium),
            TRSkeleton(
              width: index.isEven
                  ? TRMeasurements.measureMd
                  : TRMeasurements.measureSm,
            ),
          ],
        ],
      ),
    ),
  );
}

class _StaggeredTextLines extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(TRSpacing.extraLarge),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TRSkeleton(width: TRMeasurements.measureXl),
        SizedBox(height: TRSpacing.small),
        TRSkeleton(width: TRMeasurements.measureLg),
        SizedBox(height: TRSpacing.small),
        TRSkeleton(width: TRMeasurements.measureMd),
      ],
    ),
  );
}
