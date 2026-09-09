import 'package:app/src/features/boot/presentation/boot_splash.dart';
import 'package:material_ui/material_ui.dart';

/// Paints [splash] at once and swaps to [builder] when [bootstrap] resolves.
///
/// Every entrypoint has async startup work — loading preferences, and on
/// desktop resolving settings and preparing the native window — that used to
/// run before `runApp`. Nothing was painted for that whole window, so the
/// platform showed its own blank surface. The gate inverts that: `runApp` is
/// called first, and the work runs behind a frame the app itself owns.
class BootstrapGate<T extends Object> extends StatefulWidget {
  /// Creates a gate that renders the result of [bootstrap].
  const new({
    required this.bootstrap,
    required this.builder,
    this.splash = const BootSplash(),
    super.key,
  });

  /// Startup work to run once, before the app can be built.
  final Future<T> Function() bootstrap;

  /// Builds the application from the resolved [bootstrap] result.
  final Widget Function(BuildContext context, T result) builder;

  /// Painted until [bootstrap] resolves.
  final Widget splash;

  @override
  State<BootstrapGate<T>> createState() => _BootstrapGateState<T>();
}

class _BootstrapGateState<T extends Object> extends State<BootstrapGate<T>> {
  // Started once, on the first build rather than on every one. Desktop's
  // bootstrap prepares the native window, so restarting it on a rebuild would
  // re-issue that side effect.
  late final Future<T> _bootstrap = widget.bootstrap();

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _bootstrap,
    builder: (context, snapshot) {
      final error = snapshot.error;
      if (error != null) {
        // Startup failed, so there is no app to show. Rethrowing surfaces it
        // the way any other build failure is surfaced; staying on the splash
        // would present a permanent hang instead.
        Error.throwWithStackTrace(
          error,
          snapshot.stackTrace ?? StackTrace.empty,
        );
      }
      final result = snapshot.data;
      if (result == null) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: widget.splash,
        );
      }
      return widget.builder(context, result);
    },
  );
}
