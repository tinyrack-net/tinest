import 'dart:async';

import 'package:app/src/app/presentation/workspace_page.dart';
import 'package:app/src/app/router/app_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../support/fake_tinest_api.dart';
import '../support/router_harness.dart';

Future<void> _sendBackGesture(WidgetTester tester, MethodCall call) async {
  final message = const StandardMethodCodec().encodeMethodCall(call);
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    message,
    (_) {},
  );
}

/// The opaque fill belonging to [page]'s own route, inside [navigator].
///
/// Scoped under [navigator] on purpose. The shell paints a surface too, but it
/// is an ancestor of the nested Navigator rather than part of any route, so an
/// unscoped ancestor finder would match the shell and report success while the
/// route itself is still transparent.
Finder _routeSurfaceOf(Finder navigator, Finder page) => find.descendant(
  of: navigator,
  matching: find.ancestor(of: page, matching: find.byType(TRSurface)),
);

/// A page inside a shell's Navigator paints its own background.
///
/// Android's predictive Back scales and translates the outgoing route within
/// the shell. A route with no background of its own therefore composites over
/// the route beneath it, and two settings panes read as one overlapping page.
void main() {
  final now = DateTime.utc(2026, 8, 5);
  final workspace = WorkspaceDto(
    id: 'workspace',
    name: 'Tinest',
    rootPath: '/repos/tinest',
    kind: WorkspaceKind.git,
    createdAt: now,
  );
  final worktree = WorktreeDto(
    id: 'checkout',
    workspaceId: workspace.id,
    name: 'main',
    path: workspace.rootPath,
    branch: 'main',
    kind: WorktreeKind.checkout,
    isTinestOwned: false,
    createdAt: now,
  );

  FakeTinestApi buildApi() => FakeTinestApi(
    workspaces: <WorkspaceDto>[workspace],
    worktrees: <WorktreeDto>[worktree],
  );

  void useViewport(WidgetTester tester, Size size) {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = size;
    addTearDown(tester.view.reset);
  }

  testWidgets('a settings route paints an opaque surface that travels with the '
      'predictive Back gesture', (tester) async {
    // Two-pane width, where the settings entry renders General beneath the
    // pushed General page: the arrangement in the reported defect.
    useViewport(tester, const Size(800, 900));
    final router = await pumpRoutedApp(
      tester,
      buildApi(),
      initialLocation: const SettingsHomeRoute().location,
      platform: TargetPlatform.android,
    );
    addTearDown(router.dispose);

    unawaited(router.push<void>(const GeneralSettingsRoute().location));
    await tester.pumpAndSettle();

    // Keyed only when the route carries a category, so this identifies the
    // pushed page and never the entry page beneath it.
    final page = find.byKey(
      const ValueKey<String>('settings-category-pane-general'),
    );
    final navigator = find.byKey(SettingsShellRoute.$navigatorKey);
    expect(page, findsOneWidget);

    final surface = _routeSurfaceOf(navigator, page);
    expect(surface, findsOneWidget);
    expect(
      tester
          .widget<ColoredBox>(
            find
                .descendant(of: surface, matching: find.byType(ColoredBox))
                .first,
          )
          .color,
      tester.element(page).tinyrackTheme.surface,
    );

    final settled = tester.getRect(surface);
    expect(
      settled,
      tester.getRect(navigator),
      reason: 'the surface must cover the whole routed content region',
    );

    await _sendBackGesture(
      tester,
      const MethodCall('startBackGesture', <String, Object>{
        'touchOffset': <double>[5, 300],
        'progress': 0.0,
        'swipeEdge': 0,
      }),
    );
    await _sendBackGesture(
      tester,
      const MethodCall('updateBackGestureProgress', <String, Object>{
        'touchOffset': <double>[160, 300],
        'progress': 0.5,
        'swipeEdge': 0,
      }),
    );
    await tester.pump();

    final moved = tester.getRect(surface);
    expect(
      moved,
      isNot(settled),
      reason: 'the surface must sit inside the transformed outgoing route',
    );

    // Rect.contains is half-open, so compare edges rather than using it.
    final label = tester.getRect(
      find.descendant(of: page, matching: find.text('테마')).first,
    );
    expect(moved.left, lessThanOrEqualTo(label.left));
    expect(moved.top, lessThanOrEqualTo(label.top));
    expect(moved.right, greaterThanOrEqualTo(label.right));
    expect(moved.bottom, greaterThanOrEqualTo(label.bottom));

    await _sendBackGesture(tester, const MethodCall('cancelBackGesture'));
    await tester.pumpAndSettle();
    expect(tester.getRect(surface), settled);
  }, tags: const <String>['feature_test__app_navigation__widget']);

  testWidgets(
    'a workspace route paints an opaque surface over its content region',
    (tester) async {
      useViewport(tester, const Size(390, 780));
      final router = await pumpRoutedApp(
        tester,
        buildApi(),
        initialLocation: WorktreeRoute(
          hostId: 'server',
          workspaceId: workspace.id,
          worktreeId: worktree.id,
        ).location,
      );
      addTearDown(router.dispose);

      final page = find.byType(WorkspaceRouteContent);
      final navigator = find.byKey(WorkspaceShellRoute.$navigatorKey);
      final surface = _routeSurfaceOf(navigator, page);

      expect(surface, findsOneWidget);
      expect(
        tester
            .widget<ColoredBox>(
              find
                  .descendant(of: surface, matching: find.byType(ColoredBox))
                  .first,
            )
            .color,
        tester.element(page).tinyrackTheme.surface,
      );
      expect(tester.getRect(surface), tester.getRect(navigator));
    },
    tags: const <String>['feature_test__app_navigation__widget'],
  );
}
