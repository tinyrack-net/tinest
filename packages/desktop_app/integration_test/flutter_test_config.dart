import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/localization.dart';

/// Pins the platform locale and brightness so end-to-end runs resolve the
/// same strings and exercise the canonical dark desktop theme.
///
/// Without this the app follows the locale of whichever machine runs the
/// suite, and every assertion on user-visible text becomes host-dependent.
///
/// A tap that misses its target is promoted to a failure at the tap itself.
/// On a real desktop window an edge-adjacent control can measure its center a
/// fraction of a pixel off screen; the silent miss otherwise surfaces minutes
/// later as an unrelated wait timeout. Use `tapVisible` from
/// `support/tap_visible.dart` for controls that can touch a window edge.
Future<void> testExecutable(Future<void> Function() testMain) async {
  WidgetController.hitTestWarningShouldBeFatal = true;
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.platformDispatcher
    ..localeTestValue = testLocale
    ..localesTestValue = <Locale>[testLocale]
    ..platformBrightnessTestValue = Brightness.dark;

  // A runner without a GUI session (a headless macOS runner service, an X
  // server whose window never mapped) leaves the native window 0x0, and the
  // whole suite then fails as hundreds of unrelated-looking semantics and
  // hit-test errors ("Invisible SemanticsNodes", "outside the bounds of the
  // root of the render tree, Size(0.0, 0.0)"). Fail fast with the actual
  // cause instead.
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (binding.platformDispatcher.implicitView?.physicalSize.isEmpty ??
      true) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError(
        'The desktop window never obtained a size. This host has no usable '
        'GUI session (for a self-hosted macOS runner the service must run '
        'inside a logged-in Aqua session); every test would fail on a 0x0 '
        'render view.',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return await testMain();
}
