import 'dart:async';

import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/app/app_identity.dart';
import 'package:app/src/features/desktop/infrastructure/desktop_shell.dart';
import 'package:app/src/shared/presentation/tinest_icons.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Height of the compact Windows frame and Linux application menu row.
///
/// One compact control plus the inset `TRMenubar` draws around its triggers,
/// so the menubar fills the row instead of being clipped by a taller frame.
final double desktopMenuBarHeight =
    TRControlMetrics.heightOf(TRUiSize.sm) +
    TRSpacing.extraSmall +
    TRSpacing.extraSmall;

/// Window command a title-bar caption button issues.
enum DesktopCaptionAction {
  /// Hides the window to the taskbar.
  minimize,

  /// Grows the window to fill the work area.
  maximize,

  /// Returns a maximized window to its previous bounds.
  restore,

  /// Hides the window to the tray.
  close,
}

/// Localized application menus with optional Flutter-owned window controls.
class DesktopMenuBar extends StatelessWidget {
  /// Creates a menu row connected to typed application and window commands.
  const new({
    required this.window,
    required this.sidebarCollapsed,
    required this.onNewWorkspace,
    required this.onOpenSettings,
    required this.onSidebarVisibilityChanged,
    required this.onShowAbout,
    required this.onClose,
    required this.onQuit,
    super.key,
  });

  /// Typed native-window port.
  final DesktopWindow window;

  /// Whether the workspace sidebar is currently collapsed.
  final bool sidebarCollapsed;

  /// Opens the new-workspace composer.
  final VoidCallback onNewWorkspace;

  /// Opens general application settings.
  final VoidCallback onOpenSettings;

  /// Changes whether the workspace sidebar is visible.
  final ValueChanged<bool> onSidebarVisibilityChanged;

  /// Opens application name and version information.
  final VoidCallback onShowAbout;

  /// Hides the window to the tray.
  final VoidCallback onClose;

  /// Fully shuts down the resident application.
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.tinyrackTheme;
    return ColoredBox(
      color: colors.surface,
      child: SizedBox(
        height: desktopMenuBarHeight,
        child: DecoratedBox(
          key: const ValueKey<String>('desktop-title-bar-border'),
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: <Widget>[
              _ApplicationMenu(
                sidebarCollapsed: sidebarCollapsed,
                onNewWorkspace: onNewWorkspace,
                onOpenSettings: onOpenSettings,
                onSidebarVisibilityChanged: onSidebarVisibilityChanged,
                onShowAbout: onShowAbout,
                onQuit: onQuit,
              ),
              if (window.chrome.usesCustomTitleBar) ...<Widget>[
                Expanded(
                  child: GestureDetector(
                    key: const ValueKey<String>('desktop-title-bar-drag-area'),
                    behavior: HitTestBehavior.translucent,
                    onPanStart: (_) => unawaited(window.startDragging()),
                    onDoubleTap: () => unawaited(window.toggleMaximized()),
                    child: const SizedBox.expand(),
                  ),
                ),
                _CaptionButton(
                  key: const ValueKey<String>('desktop-title-bar-minimize'),
                  tooltip: l10n.desktopWindowMinimize,
                  action: DesktopCaptionAction.minimize,
                  onPressed: () => unawaited(window.minimize()),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: window.maximized,
                  builder: (context, maximized, _) => _CaptionButton(
                    key: ValueKey<String>(
                      maximized
                          ? 'desktop-title-bar-restore'
                          : 'desktop-title-bar-maximize',
                    ),
                    tooltip: maximized
                        ? l10n.desktopWindowRestore
                        : l10n.desktopWindowMaximize,
                    action: maximized
                        ? DesktopCaptionAction.restore
                        : DesktopCaptionAction.maximize,
                    onPressed: () => unawaited(window.toggleMaximized()),
                  ),
                ),
                _CaptionButton(
                  key: const ValueKey<String>('desktop-title-bar-close'),
                  tooltip: l10n.desktopWindowClose,
                  action: DesktopCaptionAction.close,
                  onPressed: onClose,
                ),
              ] else
                const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApplicationMenu extends StatelessWidget {
  const new({
    required this.sidebarCollapsed,
    required this.onNewWorkspace,
    required this.onOpenSettings,
    required this.onSidebarVisibilityChanged,
    required this.onShowAbout,
    required this.onQuit,
  });

  final bool sidebarCollapsed;
  final VoidCallback onNewWorkspace;
  final VoidCallback onOpenSettings;
  final ValueChanged<bool> onSidebarVisibilityChanged;
  final VoidCallback onShowAbout;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TRMenubar(
      semanticLabel: l10n.desktopMenuFile,
      uiSize: TRUiSize.sm,
      menus: <TRMenubarMenu>[
        TRMenubarMenu(
          menuChildren: <Widget>[
            TRMenuItem(
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyN,
                control: true,
                shift: true,
              ),
              onPressed: onNewWorkspace,
              child: TRText.inherit(l10n.workspaceNewWorkspace),
            ),
            TRMenuItem(
              shortcut: const SingleActivator(
                LogicalKeyboardKey.comma,
                control: true,
              ),
              onPressed: onOpenSettings,
              child: TRText.inherit(l10n.settingsTitle),
            ),
            const TRMenuSeparator(),
            TRMenuItem(
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyQ,
                control: true,
                shift: true,
              ),
              onPressed: onQuit,
              child: TRText.inherit(l10n.trayQuit),
            ),
          ],
          trigger: TRText.inherit(l10n.desktopMenuFile),
        ),
        TRMenubarMenu(
          menuChildren: <Widget>[
            TRMenuCheckboxItem(
              value: !sidebarCollapsed,
              closeOnActivate: true,
              onChanged: (visible) {
                if (visible == null) return;
                onSidebarVisibilityChanged(visible);
              },
              child: TRText.inherit(
                sidebarCollapsed
                    ? l10n.workspaceSidebarExpand
                    : l10n.workspaceSidebarCollapse,
              ),
            ),
          ],
          trigger: TRText.inherit(l10n.desktopMenuView),
        ),
        TRMenubarMenu(
          menuChildren: <Widget>[
            TRMenuItem(
              onPressed: onShowAbout,
              child: TRText.inherit(
                l10n.desktopMenuAbout(AppIdentity.displayName),
              ),
            ),
          ],
          trigger: TRText.inherit(l10n.desktopMenuHelp),
        ),
      ],
    );
  }
}

class _CaptionButton extends StatelessWidget {
  const new({
    required this.tooltip,
    required this.action,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final DesktopCaptionAction action;
  final VoidCallback onPressed;

  /// Ghost [TRIconButton]s in one neutral intent, so the group reads as quiet
  /// chrome rather than three competing controls. Tinting close alone would
  /// make it the loudest thing in a row the user is not meant to look at.
  @override
  Widget build(BuildContext context) => TRIconButton(
    icon: Icon(switch (action) {
      DesktopCaptionAction.minimize => TinestIcons.minimize,
      DesktopCaptionAction.maximize => TinestIcons.maximize,
      DesktopCaptionAction.restore => TinestIcons.restoreWindow,
      DesktopCaptionAction.close => TinestIcons.close,
    }),
    label: tooltip,
    onPressed: onPressed,
    appearance: TRAppearance.ghost,
    uiSize: TRUiSize.sm,
  );
}
