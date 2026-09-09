import 'package:app/src/shared/presentation/tinest_layout_metrics.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// The surface the bootstrap gate paints while startup work is still running.
///
/// Pinned to the dark theme rather than following platform brightness. The
/// native window background and the web HTML overlay are both fixed to the
/// same token value and cannot react to brightness, so matching the system
/// here would reintroduce the flash this screen exists to remove.
class BootSplash extends StatelessWidget {
  /// Creates the boot splash.
  const new({super.key});

  @override
  Widget build(BuildContext context) => Theme(
    data: TinyrackTheme.dark(),
    child: Builder(
      builder: (context) => ColoredBox(
        color: context.tinyrackTheme.surface,
        child: Center(
          child: Image.asset(
            'assets/brand/tinest-256.png',
            width: TinestLayoutMetrics.bootBrandMarkSize,
            height: TinestLayoutMetrics.bootBrandMarkSize,
          ),
        ),
      ),
    ),
  );
}
