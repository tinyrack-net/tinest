import 'package:app/src/shared/presentation/settings_layout.dart';
import 'package:app/src/shared/presentation/tinest_select_presentation.dart';
import 'package:flutter/widgets.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// A labeled setting whose value is one of a fixed set of choices.
///
/// The row reads as a line: the label on one side, the value it currently
/// holds on the other. The value is the select's own trigger drawn without a
/// field frame, so it takes the width of what it says and opens the same sheet
/// or layer a framed select would.
///
/// A framed select stretched across a row underneath its label was the shape
/// this replaces. It cost three lines for one setting, and a page of them read
/// as a stack of forms rather than as a list of what is currently set.
class TinestChoiceRow<T> extends StatelessWidget {
  /// Creates a choice setting row.
  const TinestChoiceRow({
    required this.title,
    required this.semanticLabel,
    required this.items,
    required this.value,
    required this.searchPlaceholder,
    required this.noResultsText,
    this.onChanged,
    this.placeholder,
    this.subtitle,
    this.wrapsSubtitle = false,
    this.selectKey,
    super.key,
  });

  /// Visible label.
  final Widget title;

  /// Names the control for assistive technology.
  ///
  /// The row's title names the setting, so the field drops its own label and
  /// carries the accessible name here instead of announcing it twice.
  final String semanticLabel;

  /// Optional supporting text.
  final Widget? subtitle;

  /// Whether the supporting text may occupy a second line.
  final bool wrapsSubtitle;

  /// The choices, in menu order.
  final List<TRSelectItem<T>> items;

  /// The choice currently held.
  final T? value;

  /// Shown while [value] is absent.
  final String? placeholder;

  /// Called with the next choice, or null when the row is read-only.
  final ValueChanged<T?>? onChanged;

  /// Placeholder for the filter field.
  ///
  /// Every selection control in Tinest filters, however short its list, so a
  /// reader learns the behaviour once rather than per control.
  final String searchPlaceholder;

  /// Shown when the filter matches nothing.
  final String noResultsText;

  /// Identifies the select for tests and for the layer it opens.
  final Key? selectKey;

  @override
  Widget build(BuildContext context) => SettingsRow(
    enabled: onChanged != null,
    // The row's tap is the select's tap, so the select is the tab stop.
    controlOwnsFocus: true,
    title: title,
    description: subtitle,
    wrapsDescription: wrapsSubtitle,
    control: Semantics(
      label: semanticLabel,
      container: true,
      child: TRSelect<T>.controlled(
        key: selectKey,
        // Ghost, so the value reads as the row's own trailing copy rather than
        // as a field parked inside a list.
        appearance: TRFieldAppearance.ghost,
        // No width: the trigger then shrinks to the value it is showing and
        // leaves the rest of the line to the label.
        presentation: TinestSelectPresentation.resolve(context),
        searchable: true,
        searchPlaceholder: searchPlaceholder,
        noResultsText: noResultsText,
        placeholder: placeholder,
        value: value,
        enabled: onChanged != null,
        items: items,
        onValueChange: onChanged,
      ),
    ),
  );
}

/// A labeled binary setting backed by [TRSwitch].
///
/// The inset comes from [SettingsRow] and cannot be overridden. A caller that
/// could set its own was how one card ended up drawing two alignment lines.
class TinestSwitchRow extends StatelessWidget {
  /// Creates a binary setting row.
  const TinestSwitchRow({
    required this.title,
    required this.value,
    this.onChanged,
    this.subtitle,
    this.wrapsSubtitle = false,
    this.flush = false,
    super.key,
  });

  /// Visible label.
  final Widget title;

  /// Optional supporting text.
  final Widget? subtitle;

  /// Whether the supporting text may occupy a second line.
  final bool wrapsSubtitle;

  /// Whether the surrounding container already supplies the inline inset.
  final bool flush;

  /// Current state.
  final bool value;

  /// Called with the next state.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SettingsRow(
    enabled: onChanged != null,
    flush: flush,
    // The row's tap is the switch's tap, so the switch is the tab stop.
    controlOwnsFocus: true,
    onTap: onChanged == null ? null : () => onChanged!(!value),
    title: title,
    description: subtitle,
    wrapsDescription: wrapsSubtitle,
    control: TRSwitch(
      checked: value,
      disabled: onChanged == null,
      onCheckedChange: onChanged,
    ),
  );
}

/// A labeled multi-selection setting backed by [TRCheckbox].
class TinestCheckboxRow extends StatelessWidget {
  /// Creates a checkbox setting row.
  const TinestCheckboxRow({
    required this.title,
    required this.value,
    this.onChanged,
    this.onRowTap,
    this.indeterminate = false,
    this.secondary,
    this.subtitle,
    this.wrapsSubtitle = false,
    super.key,
  });

  /// Visible label.
  final Widget title;

  /// Optional supporting text.
  final Widget? subtitle;

  /// Whether the supporting text may occupy a second line.
  final bool wrapsSubtitle;

  /// Optional leading visual.
  final Widget? secondary;

  /// Current checked state.
  final bool value;

  /// Whether the checkbox reads as partially checked.
  ///
  /// For a row standing for several settings that disagree, such as a group
  /// header over tools where only some are on.
  final bool indeterminate;

  /// Called with the next checked state.
  final ValueChanged<bool?>? onChanged;

  /// What the row does when the checkbox is not what was tapped.
  ///
  /// Left null, the row simply repeats the checkbox, which is the usual shape
  /// and keeps one setting at one tab stop. A row that does something else —
  /// a group header that expands while its checkbox toggles the whole group —
  /// supplies this, and then the row and the checkbox are two actions and get
  /// a tab stop each.
  final VoidCallback? onRowTap;

  @override
  Widget build(BuildContext context) => SettingsRow(
    enabled: onChanged != null || onRowTap != null,
    // Without [onRowTap] the row's tap is the checkbox's tap, so the checkbox
    // is the single tab stop. With one they are two actions, and two stops.
    controlOwnsFocus: onRowTap == null,
    onTap: onRowTap ?? (onChanged == null ? null : () => onChanged!(!value)),
    leading: secondary,
    title: title,
    description: subtitle,
    wrapsDescription: wrapsSubtitle,
    control: TRCheckbox(
      checked: value,
      indeterminate: indeterminate,
      disabled: onChanged == null,
      onCheckedChange: (checked) => onChanged?.call(checked),
    ),
  );
}
