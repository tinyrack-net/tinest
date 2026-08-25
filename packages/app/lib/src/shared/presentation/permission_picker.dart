import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/shared/presentation/tinest_select_presentation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Permission modes in the order they are offered.
///
/// The mode that asks before every mutation leads, because it is what a
/// session starts under unless the daemon default says otherwise. The enum
/// itself stays in restrictiveness order, which is what narrowing a nested
/// agent's permissions reads from.
const List<PermissionMode> permissionModeOrder = <PermissionMode>[
  PermissionMode.ask,
  PermissionMode.readOnly,
  PermissionMode.workspaceWrite,
  PermissionMode.fullAccess,
];

/// A descriptive permission Select shared by composer and settings surfaces.
class PermissionSelect extends StatelessWidget {
  /// Creates a permission Select over the four concrete modes.
  const PermissionSelect({
    required this.currentMode,
    required this.onValueChange,
    this.enabled = true,
    this.leading,
    this.appearance = TRFieldAppearance.solid,
    this.padding = TRFieldPadding.standard,
    this.uiSize,
    this.width,
    super.key,
  });

  /// Mode the surface currently runs under.
  final PermissionMode currentMode;

  /// Called with the newly chosen mode.
  final ValueChanged<PermissionMode>? onValueChange;

  /// Whether the Select accepts input.
  final bool enabled;

  /// Optional leading trigger content.
  final Widget? leading;

  /// Design-system field appearance.
  final TRFieldAppearance appearance;

  /// Design-system trigger padding.
  final TRFieldPadding padding;

  /// Design-system control density.
  final TRUiSize? uiSize;

  /// Optional trigger width.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final handler = onValueChange;
    return TRSelect<PermissionMode>.controlled(
      value: currentMode,
      enabled: enabled,
      leading: leading,
      appearance: appearance,
      padding: padding,
      uiSize: uiSize,
      width: width,
      searchable: true,
      searchPlaceholder: l10n.selectSearchPlaceholder,
      noResultsText: l10n.selectNoResults,
      presentation: TinestSelectPresentation.resolve(context),
      items: <TRSelectItem<PermissionMode>>[
        for (final mode in permissionModeOrder)
          TRSelectItem<PermissionMode>(
            key: ValueKey<String>('permission-option-${mode.name}'),
            value: mode,
            label: permissionModeLabel(l10n, mode),
            description: permissionModeDescription(l10n, mode),
          ),
      ],
      // The Select reports a nullable value because clearing is possible in
      // general; every item here holds a concrete mode, so it never does.
      onValueChange: handler == null
          ? null
          : (mode) {
              if (mode != null) handler(mode);
            },
    );
  }
}

/// Localized short label for one permission mode.
String permissionModeLabel(AppLocalizations l10n, PermissionMode mode) =>
    switch (mode) {
      PermissionMode.readOnly => l10n.composerPermissionReadOnly,
      PermissionMode.ask => l10n.composerPermissionAsk,
      PermissionMode.workspaceWrite => l10n.composerPermissionWorkspaceWrite,
      PermissionMode.fullAccess => l10n.composerPermissionFullAccess,
    };

/// Localized explanation of the effective behavior of one mode.
String permissionModeDescription(
  AppLocalizations l10n,
  PermissionMode mode,
) => switch (mode) {
  PermissionMode.readOnly => l10n.permissionDescriptionReadOnly,
  PermissionMode.ask => l10n.permissionDescriptionAsk,
  PermissionMode.workspaceWrite => l10n.permissionDescriptionWorkspaceWrite,
  PermissionMode.fullAccess => l10n.permissionDescriptionFullAccess,
};
