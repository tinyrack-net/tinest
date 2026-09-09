import 'package:flutter/widgets.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Returns the token-derived top inset that centers a leading visual on the
/// first line box of [textStyle] at the current accessibility text scale.
double chatFirstLineLeadingInset(
  BuildContext context, {
  required double leadingExtent,
  TextStyle? textStyle,
}) {
  final resolvedStyle =
      textStyle ?? TRTypography.resolve(context, TRTextVariant.body);
  final lineExtent =
      MediaQuery.textScalerOf(context).scale(resolvedStyle.fontSize!) *
      resolvedStyle.height!;
  return ((lineExtent - leadingExtent) / 2)
      .clamp(0, double.infinity)
      .toDouble();
}
