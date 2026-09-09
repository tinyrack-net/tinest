import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Keeps a disabled design-system control actionable to explain its policy.
///
/// The child remains the real visual control. This product wrapper owns only
/// focus, keyboard, pointer, and semantics behavior for the locked state.
class BlockedControl extends StatefulWidget {
  /// Creates an interactive explanation around a disabled [child].
  const new({
    required this.label,
    required this.hint,
    required this.onTap,
    required this.child,
    super.key,
  });

  /// Accessible control label.
  final String label;

  /// Explanation for why the control is unavailable.
  final String hint;

  /// Shows the product-owned explanation.
  final VoidCallback onTap;

  /// Disabled public design-system control.
  final Widget child;

  @override
  State<BlockedControl> createState() => _BlockedControlState();
}

class _BlockedControlState extends State<BlockedControl> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

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

  void _handleFocusChange() {
    final focused = _focusNode.hasPrimaryFocus;
    if (focused == _focused || !mounted) return;
    setState(() => _focused = focused);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    enabled: true,
    label: widget.label,
    hint: widget.hint,
    onTap: widget.onTap,
    child: CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter): widget.onTap,
        const SingleActivator(LogicalKeyboardKey.space): widget.onTap,
      },
      child: Focus(
        focusNode: _focusNode,
        canRequestFocus: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: TRFocusRing(
              focused: _focused,
              child: ExcludeSemantics(
                child: IgnorePointer(child: widget.child),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
