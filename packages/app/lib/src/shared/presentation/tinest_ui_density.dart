import 'package:flutter/widgets.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Selects Tinest's semantic UI density from the available window width.
///
/// The product owns the responsive policy while `tinyrack_ui` owns the
/// geometry of each density. This follows the shared adaptive width class so
/// comfortable density starts exactly when navigation shows one pane.
class TinestUiDensity extends StatelessWidget {
  /// Creates the responsive density boundary around [child].
  const new({required this.child, super.key});

  /// The application subtree that inherits the selected UI density.
  final Widget child;

  /// Keeps desktop chrome compact while comfortable UI inherits its XL size.
  static TRUiSize? compactControlSize(BuildContext context) =>
      TRUiDensityScope.of(context) == TRUiDensity.comfortable
      ? null
      : TRUiSize.sm;

  /// Keeps desktop cards compact while comfortable UI gets medium padding.
  static TRCardPadding compactCardPadding(BuildContext context) =>
      TRUiDensityScope.of(context) == TRUiDensity.comfortable
      ? TRCardPadding.md
      : TRCardPadding.sm;

  /// Resolves the default control recipe for density-derived visual geometry.
  static TRUiSize defaultControlSize(BuildContext context) =>
      TRUiDensityScope.resolveSize(context, null);

  @override
  Widget build(BuildContext context) => TRUiDensityScope(
    density:
        TRAdaptiveWidthClass.fromWidth(MediaQuery.sizeOf(context).width) ==
            TRAdaptiveWidthClass.compact
        ? TRUiDensity.comfortable
        : TRUiDensity.standard,
    child: child,
  );
}
