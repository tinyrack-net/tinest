import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// The maximum fraction of the full MediaQuery height used by Tinest sheets.
const double tinestBottomSheetMaxExtent = 0.7;

/// Opens a bottom sheet that follows Tinest's content-sized height policy.
Future<T?> showTinestBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  String? barrierLabel,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  bool? requestFocus,
}) => showTRDrawer<T>(
  context: context,
  builder: builder,
  barrierDismissible: barrierDismissible,
  barrierLabel: barrierLabel,
  useRootNavigator: useRootNavigator,
  routeSettings: routeSettings,
  requestFocus: requestFocus,
);

/// A content-sized Tinest bottom sheet capped at 70% of the screen height.
class TinestBottomSheet extends StatelessWidget {
  /// Creates a Tinest bottom sheet.
  const new({
    required this.content,
    this.actions,
    this.description,
    this.semanticLabel,
    this.title,
    super.key,
  });

  /// Main sheet content.
  final Widget content;

  /// Optional actions displayed below [content].
  final Widget? actions;

  /// Optional supporting description.
  final Widget? description;

  /// Accessibility label for the sheet surface.
  final String? semanticLabel;

  /// Optional sheet heading.
  final Widget? title;

  @override
  Widget build(BuildContext context) => TRDrawer(
    maxExtent: tinestBottomSheetMaxExtent,
    semanticLabel: semanticLabel,
    title: title,
    description: description,
    content: content,
    actions: actions,
  );
}
