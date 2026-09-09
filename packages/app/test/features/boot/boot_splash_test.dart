import 'dart:async';

import 'package:app/src/features/boot/presentation/boot_splash.dart';
import 'package:app/src/features/boot/presentation/bootstrap_gate.dart';
import 'package:app/src/shared/presentation/tinest_layout_metrics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

void main() {
  group('BootstrapGate', () {
    testWidgets('paints the splash while the bootstrap is unresolved', (
      tester,
    ) async {
      final bootstrap = Completer<String>();
      await tester.pumpWidget(
        BootstrapGate<String>(
          bootstrap: () => bootstrap.future,
          builder: (context, value) => _app(value),
        ),
      );

      // The whole point of the gate is that this frame exists at all: before
      // it, nothing was painted until the bootstrap future resolved.
      expect(find.byType(BootSplash), findsOneWidget);
      expect(find.text('ready'), findsNothing);

      bootstrap.complete('ready');
      await tester.pumpAndSettle();
    });

    testWidgets('swaps to the built app once the bootstrap resolves', (
      tester,
    ) async {
      final bootstrap = Completer<String>();
      await tester.pumpWidget(
        BootstrapGate<String>(
          bootstrap: () => bootstrap.future,
          builder: (context, value) => _app(value),
        ),
      );

      bootstrap.complete('ready');
      await tester.pumpAndSettle();

      expect(find.text('ready'), findsOneWidget);
      expect(find.byType(BootSplash), findsNothing);
    });

    testWidgets('runs the bootstrap once across rebuilds', (tester) async {
      // Desktop's bootstrap prepares the native window. Running it twice would
      // re-issue that side effect, so a rebuild while pending must not restart
      // it.
      final bootstrap = Completer<String>();
      var calls = 0;
      // A fresh widget each pump, so the element really does update rather
      // than short-circuit on an identical instance — that update is the case
      // that would restart the future if it were owned by build().
      BootstrapGate<String> gate() => BootstrapGate<String>(
        bootstrap: () {
          calls += 1;
          return bootstrap.future;
        },
        builder: (context, value) => _app(value),
      );

      await tester.pumpWidget(gate());
      await tester.pumpWidget(gate());

      expect(calls, 1);

      bootstrap.complete('ready');
      await tester.pumpAndSettle();
    });

    testWidgets('surfaces a bootstrap failure instead of hanging', (
      tester,
    ) async {
      await tester.pumpWidget(
        BootstrapGate<String>(
          bootstrap: () async => throw StateError('no daemon'),
          builder: (context, value) => _app(value),
        ),
      );
      await tester.pump();

      // Without this the app sits on the splash forever, which reads as a hang
      // rather than the startup failure it is.
      expect(tester.takeException(), isStateError);
    });
  });

  group('BootSplash', () {
    testWidgets('fills the surface with the brand mark on the dark token', (
      tester,
    ) async {
      // Pinned dark even under a light ambient theme: the native window and
      // the web overlay are both fixed to this color, so following the system
      // here would flash on a light-mode machine.
      await tester.pumpWidget(
        MaterialApp(theme: TinyrackTheme.light(), home: const BootSplash()),
      );

      final box = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(BootSplash),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(
        box.color,
        TinyrackTheme.dark().extension<TinyrackThemeData>()!.surface,
      );
      final mark = tester.widget<Image>(find.byType(Image));
      expect((mark.image as AssetImage).assetName, contains('brand/tinest'));
      expect(mark.width, TinestLayoutMetrics.bootBrandMarkSize);
    });

    testWidgets('resolves the brand mark instead of painting a bare surface', (
      tester,
    ) async {
      // An asset image resolves off the test's fake async, so a splash that
      // never drives a real async frame paints the surface with the mark
      // still missing. Declaring the widget is not enough: this asserts the
      // render object actually holds decoded pixels.
      await tester.pumpWidget(const MaterialApp(home: BootSplash()));

      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          await precacheImage((element.widget as Image).image, element);
        }
      });
      await tester.pumpAndSettle();

      expect(
        tester.renderObject<RenderImage>(find.byType(RawImage)).image,
        isNotNull,
      );
    });
  });
}

/// Stands in for the real app, which brings its own [MaterialApp].
Widget _app(String value) =>
    Directionality(textDirection: TextDirection.ltr, child: Text(value));
