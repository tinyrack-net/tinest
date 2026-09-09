import 'package:app/src/shared/presentation/toast_messenger.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../support/fake_tinest_api.dart';
import '../support/localization.dart';
import '../support/router_harness.dart';

/// Pumps [TinestToastScope] over a page and returns the messenger behind it.
Future<ToastMessenger> _pumpScope(WidgetTester tester) async {
  late ToastMessenger messenger;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: testLightTheme,
        locale: testLocale,
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Consumer(
          builder: (context, ref, _) {
            messenger = ref.read(toastMessengerProvider);
            return const TinestToastScope(
              child: Scaffold(body: Center(child: Text('Page'))),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return messenger;
}

void main() {
  testWidgets('a reported result is shown over the page and can be dismissed', (
    tester,
  ) async {
    final messenger = await _pumpScope(tester);

    messenger.success(testL10n.commonSaved);
    await tester.pumpAndSettle();
    expect(find.text(testL10n.commonSaved), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(TRToastRegion),
        matching: find.byType(TRIconButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(testL10n.commonSaved), findsNothing);
  }, tags: const <String>['feature_test__app_toast__widget']);

  testWidgets('a failure names what happened and describes why', (
    tester,
  ) async {
    final messenger = await _pumpScope(tester);

    messenger.failure(
      testL10n.commonActionFailed,
      error: StateError('no host selected'),
    );
    await tester.pumpAndSettle();

    expect(find.text(testL10n.commonActionFailed), findsOneWidget);
    expect(find.textContaining('no host selected'), findsOneWidget);

    // Left to time out rather than dismissed, which is the path a real
    // report takes and the one that leaves a timer behind.
    await tester.pump(TRMotion.toast);
    await tester.pumpAndSettle();
    expect(find.text(testL10n.commonActionFailed), findsNothing);
  }, tags: const <String>['feature_test__app_toast__widget']);

  testWidgets(
    'the region is disposed with the tree, leaving no timer pending',
    (tester) async {
      final messenger = await _pumpScope(tester);
      messenger.success(testL10n.commonSaved);
      await tester.pumpAndSettle();

      // Replacing the tree tears down the ProviderScope that owns the queue.
      // If disposal did not run before the binding checks its invariants, the
      // five second dismissal timer would fail this test rather than this
      // expectation, so reaching the end at all is the assertion.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(find.text(testL10n.commonSaved), findsNothing);
    },
    tags: const <String>['feature_test__app_toast__widget'],
  );

  testWidgets(
    'a report is styled by the region rather than by the page under it',
    (tester) async {
      final messenger = await _pumpScope(tester);

      messenger.failure(
        testL10n.commonActionFailed,
        error: StateError('no host selected'),
      );
      await tester.pumpAndSettle();

      // The region is a sibling of the routes, not a descendant, so nothing on
      // the page hands its text a style. Text left to MaterialApp's fallback
      // there is painted with a yellow double underline, which is what the app
      // shipped until the region brought its own surface.
      for (final report in <Finder>[
        find.text(testL10n.commonActionFailed),
        find.textContaining('no host selected'),
      ]) {
        expect(
          tester.renderObject<RenderParagraph>(report).text.style?.decoration ??
              TextDecoration.none,
          TextDecoration.none,
        );
      }
    },
    tags: const <String>['feature_test__app_toast__widget'],
  );

  testWidgets('the running app mounts the region above its routes', (
    tester,
  ) async {
    await pumpRoutedApp(tester, FakeTinestApi(), initialLocation: '/');

    expect(find.byType(TRToastRegion), findsOneWidget);
  }, tags: const <String>['feature_test__app_toast__widget']);

  testWidgets('a report keeps clear of the controls that raise it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final messenger = await _pumpScope(tester);

    messenger.success(testL10n.commonSaved);
    await tester.pumpAndSettle();

    // The bottom-end corner is where this app puts the control a report
    // follows: a settings form's Save, the composer's send. A toast placed
    // there covers the button that raised it, and the next press lands on
    // the report. Reports therefore sit at the top of the window.
    final report = tester.getRect(find.text(testL10n.commonSaved));
    final page = tester.getRect(find.byType(TRToastRegion));
    expect(report.bottom, lessThan(page.center.dy));
    expect(
      tester.widget<TRToastRegion>(find.byType(TRToastRegion)).placement,
      TRToastPlacement.topEnd,
    );
  }, tags: const <String>['feature_test__app_toast__widget']);
}
