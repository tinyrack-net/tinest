import 'package:flutter/widgets.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// The standard Tinest page shell backed by [TRAppShell].
class TinestPageShell extends StatelessWidget {
  /// Creates a page with optional top chrome.
  const new({required this.body, this.appBar, super.key});

  /// Page content.
  final Widget body;

  /// Optional page header.
  final TinestPageHeader? appBar;

  @override
  Widget build(BuildContext context) => TRSurface(
    child: SafeArea(
      child: TRAppShell(
        header: appBar == null ? null : TinestPageHeaderBar.bar(appBar!),
        main: TRAppShellMain(child: body),
      ),
    ),
  );
}

/// The top chrome of a [TinestPageShell], usable on its own.
///
/// A destination nested inside a shell's [TRAppShellMain] can render this to
/// own the page header itself. [TRAppShellHeader] resolves its scope from the
/// enclosing [TRAppShell], which spans the main region too, so the header
/// reads identically wherever it is composed.
class TinestPageHeaderBar extends StatelessWidget {
  /// Creates a standalone Tinest header bar.
  const new({required this.header, super.key});

  /// Declarative header content.
  final TinestPageHeader header;

  /// Builds the same bar as a raw [TRAppShellHeader].
  ///
  /// [TRAppShell.header] is typed to [TRAppShellHeader], so the shell slot
  /// cannot take this wrapper widget. Both paths share this one definition.
  ///
  /// Identity and actions share one row that never wraps. An earlier version
  /// wrapped them, because a destination carrying several text buttons
  /// overflowed a phone-width bar; the wrap traded that overflow for a bar
  /// that silently doubled in height. [TinestPageHeader.actions] is typed to
  /// square icon controls instead, so the action rail has a bounded width and
  /// the bar has room for both at every window size. Only the title may take
  /// a second line, which is what an enlarged text scale needs.
  ///
  /// [TRAppShellHeader] owns the resting height: [TRMeasurements.headerHeight],
  /// and one [TRSpacing.large] step more under comfortable density, which is
  /// what [TRPaneHeader] stands at either way. The bar used to strut that
  /// height itself, because sized by its contents it was a line of text tall
  /// with no actions and a control tall with them, so a page that carried none
  /// — standalone General or Advanced settings — drew a visibly shorter bar
  /// than every destination beside it in the same stack. A strut of one fixed
  /// height could not take the density step, and a comfortable control is
  /// exactly the standard resting height, so an action filled the bar edge to
  /// edge and its tap target met the content below it.
  ///
  /// The inline padding is asymmetric because the strut contributed a leading
  /// [Row] gap on top of it. Keeping the start inset at [TRSpacing.large]
  /// leaves the identity on the same rail it sat on before.
  static TRAppShellHeader bar(TinestPageHeader header) => TRAppShellHeader(
    borderBottom: true,
    padding: const EdgeInsetsDirectional.only(
      start: TRSpacing.large,
      end: TRSpacing.small,
    ),
    children: [
      ?header.leading,
      Expanded(child: _TinestPageHeaderTitle(title: header.title)),
      if (header.actions.isNotEmpty)
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: TRSpacing.small,
          children: header.actions,
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => bar(header);
}

class _TinestPageHeaderTitle extends StatelessWidget {
  const new({required this.title});

  final Widget title;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: DefaultTextStyle.merge(
      style: TRTypography.resolve(context, TRTextVariant.headingSm),
      softWrap: true,
      child: title,
    ),
  );
}

/// Declarative content for a [TinestPageShell] header.
class TinestPageHeader {
  /// Creates a page header.
  const new({
    required this.title,
    this.actions = const <TRIconButton>[],
    this.leading,
  });

  /// Header title.
  final Widget title;

  /// Optional leading navigation action.
  final Widget? leading;

  /// Trailing page actions.
  ///
  /// Typed to [TRIconButton] rather than [Widget] so the bar can lay its
  /// contents out in one row. A square icon control is as wide as it is tall,
  /// and it does not grow with the text scale, so any number of them a page
  /// reasonably carries still fits beside the title. A text button does not,
  /// and a header that accepted one would grow a second line to hold it.
  ///
  /// An action whose meaning needs words belongs in the body beside what it
  /// acts on — see `SettingsSection.action` — or in the destination's form
  /// action bar when it commits or abandons the page.
  final List<TRIconButton> actions;
}
