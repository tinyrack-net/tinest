import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:termworld/termworld.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Applies the Tinest design system and context-menu contract to termworld.
final class TinestTerminalView extends StatefulWidget {
  /// Creates a token-backed terminal viewport for Tinest.
  const TinestTerminalView({
    required this.terminal,
    required this.controller,
    this.contextMenuItems,
    this.onCopy,
    this.onPaste,
    this.autofocus = false,
    this.readOnly = false,
    super.key,
  });

  /// Terminal engine connected to the active PTY.
  final Terminal terminal;

  /// Selection and scroll state rendered by the viewport.
  final TerminalViewController controller;

  /// Native or Flutter context-menu description for terminal actions.
  final TRMenuElementsBuilder? contextMenuItems;

  /// Runs on the desktop terminal copy chord, Control+Shift+C.
  ///
  /// Plain Control+C is the program's interrupt and always goes to the PTY.
  final VoidCallback? onCopy;

  /// Runs on the desktop terminal paste chord, Control+Shift+V.
  ///
  /// Plain Control+V is literal-next and always goes to the PTY.
  final VoidCallback? onPaste;

  /// Whether the terminal requests focus when mounted.
  final bool autofocus;

  /// Whether user input is disabled.
  final bool readOnly;

  @override
  State<TinestTerminalView> createState() => _TinestTerminalViewState();
}

final class _TinestTerminalViewState extends State<TinestTerminalView> {
  final TRContextMenuController _menuController = TRContextMenuController();

  @override
  void initState() {
    super.initState();
    widget.terminal.attachCustomKeyEventHandler(_handleTerminalKeyEvent);
  }

  @override
  void didUpdateWidget(TinestTerminalView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.terminal == widget.terminal) return;
    oldWidget.terminal.attachCustomKeyEventHandler((_) => true);
    widget.terminal.attachCustomKeyEventHandler(_handleTerminalKeyEvent);
  }

  void _openContextMenu(TapDownDetails details, TerminalCellOffset _) {
    if (widget.terminal.modes.mouseTrackingMode != 'none') {
      return;
    }
    _menuController.openAt(details.globalPosition);
  }

  bool _handleTerminalKeyEvent(TerminalKeyEvent event) {
    if (_menuController.isOpen &&
        event.key == LogicalKeyboardKey.escape.keyLabel) {
      _menuController.close();
      return false;
    }
    if (event.control && event.shift && !event.alt && !event.meta) {
      // The key carries the platform's character when there is one — which a
      // control chord may report as the C0 byte — and the key label otherwise.
      if (widget.onCopy != null && _isLetter(event.key, 'c', '\u0003')) {
        widget.onCopy!();
        return false;
      }
      if (widget.onPaste != null && _isLetter(event.key, 'v', '\u0016')) {
        widget.onPaste!();
        return false;
      }
    }
    return true;
  }

  static bool _isLetter(String key, String letter, String controlByte) =>
      key.toLowerCase() == letter || key == controlByte;

  @override
  void dispose() {
    widget.terminal.attachCustomKeyEventHandler((_) => true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tinyrackTheme;
    final palette = List<Color>.of(TerminalThemes.defaultTheme.palette)
      ..setAll(0, <Color>[
        colors.surface,
        colors.dangerForeground,
        colors.successForeground,
        colors.warningForeground,
        colors.infoForeground,
        colors.primaryForeground,
        colors.infoBorder,
        colors.text,
        colors.textMuted,
        colors.dangerBorder,
        colors.successBorder,
        colors.warningBorder,
        colors.infoBorder,
        colors.primaryForeground,
        colors.infoForeground,
        colors.text,
      ]);
    final codeStyle = TRTypography.resolve(context, TRTextVariant.code);
    final terminal = TerminalView(
      terminal: widget.terminal,
      controller: widget.controller,
      autofocus: widget.autofocus,
      readOnly: widget.readOnly,
      onSecondaryTapDown: widget.contextMenuItems == null
          ? null
          : _openContextMenu,
      theme: TerminalTheme(
        background: colors.surface,
        foreground: colors.text,
        cursor: colors.focus,
        cursorAccent: colors.surface,
        selection: colors.surfaceSelected,
        selectionInactive: colors.surfaceSelected,
        palette: palette,
      ),
      style: TerminalStyle(
        fontFamily: codeStyle.fontFamily!,
        fontSize: codeStyle.fontSize!,
        height: codeStyle.height!,
        fontWeight: codeStyle.fontWeight!,
        letterSpacing: codeStyle.letterSpacing!,
      ),
      padding: const EdgeInsets.all(TRSpacing.small),
    );
    final items = widget.contextMenuItems;
    return ColoredBox(
      key: const ValueKey<String>('tr-terminal-surface'),
      color: colors.surface,
      child: items == null
          ? terminal
          : TRContextMenu.itemsBuilder(
              menuController: _menuController,
              itemsBuilder: items,
              onClose: widget.controller.requestKeyboard,
              child: terminal,
            ),
    );
  }
}
