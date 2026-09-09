import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Selects the semantic surface used when a row is selected.
enum TinestListRowSelectionAppearance {
  /// Uses the standard content-list selected surface.
  standard,

  /// Uses the navigation selected surface shared with [TRTreeNav].
  navigation,
}

/// Selects where a list row places its trailing content.
enum TinestListRowTrailingLayout {
  /// Keeps trailing content opposite the leading copy.
  inline,

  /// Places trailing content below the leading copy at the full row width.
  below,
}

/// A Tinest content row composed exclusively from Tinyrack tokens.
///
/// The row rings itself only while it holds the primary focus. A row reports
/// focus for its descendants as well, so a row that read plain focus painted
/// its ring beside the emphasis a focused trailing control was already
/// carrying, which marked one control twice.
///
/// A row whose [onTap] only repeats what its trailing control already does sets
/// [controlOwnsFocus] so the control is the single tab stop for the setting.
class TinestListRow extends StatefulWidget {
  /// Creates a content or navigation row.
  const new({
    required this.title,
    this.contentPadding,
    this.controlOwnsFocus = false,
    this.dense = false,
    this.enabled = true,
    this.hoverEnabled = true,
    this.isThreeLine = false,
    this.leading,
    this.onTap,
    this.selected = false,
    this.selectionAppearance = TinestListRowSelectionAppearance.standard,
    this.subtitle,
    this.subtitleMaxLines,
    this.trailing,
    this.trailingLayout = TinestListRowTrailingLayout.inline,
    this.unboundedSubtitle = false,
    super.key,
  });

  /// Primary row content.
  final Widget title;

  /// Optional supporting content.
  final Widget? subtitle;

  /// Optional leading visual.
  final Widget? leading;

  /// Optional trailing visual or action.
  final Widget? trailing;

  /// Where [trailing] is placed relative to the row copy.
  final TinestListRowTrailingLayout trailingLayout;

  /// Invoked when the row is activated.
  final VoidCallback? onTap;

  /// Whether the row is selected.
  final bool selected;

  /// Semantic appearance used for the selected surface.
  final TinestListRowSelectionAppearance selectionAppearance;

  /// Whether the row accepts activation.
  final bool enabled;

  /// Whether the row paints a hover surface while the pointer is over it.
  ///
  /// A containing settings surface can disable this while preserving the
  /// row's pointer activation and the trailing control's own hover state.
  final bool hoverEnabled;

  /// Whether compact vertical padding is used.
  final bool dense;

  /// Whether supporting content may occupy two lines.
  final bool isThreeLine;

  /// Caps the supporting content, overriding the cap [isThreeLine] implies.
  final int? subtitleMaxLines;

  /// Whether the supporting content may run to as many lines as it needs.
  ///
  /// A list row truncates by default, because a list reads as a column of
  /// equal rows. A setting's description is prose the reader has to finish,
  /// and on a narrow window two lines cut it mid-sentence.
  final bool unboundedSubtitle;

  /// Overrides token-based content padding when layout requires it.
  final EdgeInsetsGeometry? contentPadding;

  /// Whether the trailing control is the row's only tab stop.
  ///
  /// A switch row taps the switch and nothing else, so a stop on the row and
  /// another on the switch cost two presses for one setting and announced the
  /// setting twice. The row still activates from a pointer anywhere on it.
  ///
  /// A row whose trailing control does something the row does not, such as a
  /// tab that selects and a button that closes it, leaves this off: those are
  /// two actions and deserve two stops.
  final bool controlOwnsFocus;

  @override
  State<TinestListRow> createState() => _TinestListRowState();
}

class _TinestListRowState extends State<TinestListRow> {
  final FocusNode _focusNode = FocusNode();
  bool _hovered = false;
  bool _focused = false;

  /// Whether a pointer on the row runs [TinestListRow.onTap].
  bool get _interactive => widget.enabled && widget.onTap != null;

  /// Whether the row is a tab stop of its own.
  bool get _focusable => _interactive && !widget.controlOwnsFocus;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  /// Tracks the primary focus, not [FocusNode.hasFocus].
  ///
  /// A focused control inside the row is not a focused row: reading plain
  /// focus is what put a ring around the row and around its select at once.
  void _handleFocusChange() {
    final focused = _focusNode.hasPrimaryFocus;
    if (focused == _focused || !mounted) return;
    setState(() => _focused = focused);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tinyrackTheme;
    final background = widget.selected
        ? widget.selectionAppearance ==
                  TinestListRowSelectionAppearance.navigation
              ? colors.surfaceHover
              : colors.surfaceSelected
        : widget.hoverEnabled && _hovered
        ? colors.surfaceHover
        : colors.surface;
    final comfortable = TRUiDensityScope.of(context) == TRUiDensity.comfortable;
    final verticalPadding = switch ((comfortable, widget.dense)) {
      (true, true) => TRSpacing.small,
      (true, false) => TRSpacing.medium,
      (false, true) => TRSpacing.extraSmall,
      (false, false) => TRSpacing.small,
    };
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DefaultTextStyle.merge(
          style: TRTypography.resolve(context, TRTextVariant.body),
          child: widget.title,
        ),
        if (widget.subtitle case final subtitle?) ...[
          const SizedBox(height: TRSpacing.extraSmall),
          DefaultTextStyle.merge(
            style: TRTypography.resolve(
              context,
              TRTextVariant.bodySm,
            ).copyWith(color: colors.textMuted),
            maxLines: widget.unboundedSubtitle
                ? null
                : widget.subtitleMaxLines ?? (widget.isThreeLine ? 2 : 1),
            overflow: widget.unboundedSubtitle
                ? TextOverflow.clip
                : TextOverflow.ellipsis,
            child: subtitle,
          ),
        ],
      ],
    );
    final content = switch ((widget.trailingLayout, widget.trailing)) {
      (TinestListRowTrailingLayout.below, final trailing?) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: widget.isThreeLine
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              if (widget.leading case final leading?) ...[
                IconTheme.merge(
                  data: IconThemeData(color: colors.textMuted),
                  child: leading,
                ),
                const SizedBox(width: TRSpacing.small),
              ],
              Expanded(child: copy),
            ],
          ),
          const SizedBox(height: TRSpacing.medium),
          trailing,
        ],
      ),
      _ => LayoutBuilder(
        builder: (context, constraints) => Row(
          crossAxisAlignment: widget.isThreeLine
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            if (widget.leading case final leading?) ...[
              IconTheme.merge(
                data: IconThemeData(color: colors.textMuted),
                child: leading,
              ),
              const SizedBox(width: TRSpacing.small),
            ],
            Expanded(child: copy),
            if (widget.trailing case final trailing?) ...[
              const SizedBox(width: TRSpacing.small),
              // A trailing control sizes itself, so a long value — a theme
              // named in Japanese, a host address — measured wider than the
              // row and pushed it past its own edge. Bounding it leaves the
              // title a rail to read on and lets the control ellipsize.
              // A control that already fits is untouched, so a short value
              // still sits against the content edge.
              ConstrainedBox(
                constraints: BoxConstraints(
                  // tinyrack-check-ignore-next-line tokens/no-literal -- the bound is the row's own width less token gap and rail; the floor keeps a degenerate width from asserting, and is not a spacing value
                  maxWidth: math.max(
                    0,
                    constraints.maxWidth -
                        TRSpacing.small -
                        TRMeasurements.measureXs,
                  ),
                ),
                child: trailing,
              ),
            ],
          ],
        ),
      ),
    };

    return Semantics(
      // A row that hands its focus to its control is not a control itself, so
      // it stays out of the way and lets the control name the setting once.
      button: _focusable,
      enabled: widget.enabled,
      selected: widget.selected,
      onTap: _focusable ? widget.onTap : null,
      child: CallbackShortcuts(
        bindings: _focusable
            ? <ShortcutActivator, VoidCallback>{
                const SingleActivator(LogicalKeyboardKey.enter): widget.onTap!,
                const SingleActivator(LogicalKeyboardKey.space): widget.onTap!,
              }
            : const <ShortcutActivator, VoidCallback>{},
        child: Focus(
          focusNode: _focusNode,
          canRequestFocus: _focusable,
          skipTraversal: !_focusable,
          child: MouseRegion(
            cursor: _interactive ? SystemMouseCursors.click : MouseCursor.defer,
            onEnter: _interactive && widget.hoverEnabled
                ? (_) => setState(() => _hovered = true)
                : null,
            onExit: _interactive && widget.hoverEnabled
                ? (_) => setState(() => _hovered = false)
                : null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _interactive ? widget.onTap : null,
              child: TRFocusRing(
                focused: _focused,
                child: AnimatedContainer(
                  duration: TRMotion.fast,
                  curve: TRMotion.standard,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: const BorderRadius.all(TRRadii.medium),
                  ),
                  padding:
                      widget.contentPadding ??
                      EdgeInsets.symmetric(
                        horizontal: TRSpacing.small,
                        vertical: verticalPadding,
                      ),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
