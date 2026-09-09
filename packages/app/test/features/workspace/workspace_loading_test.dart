import 'dart:async';

import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/features/hosts/application/host_controller.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/shared/presentation/workspace_skeletons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:termworld/termworld.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/fake_tinest_api.dart';
import '../../support/router_harness.dart';

void main() {
  final now = DateTime.utc(2026, 8, 2);
  final workspace = WorkspaceDto(
    id: 'workspace',
    name: 'Workspace',
    rootPath: '/workspace',
    kind: WorkspaceKind.directory,
    createdAt: now,
  );
  final checkout = WorktreeDto(
    id: 'checkout',
    workspaceId: workspace.id,
    name: workspace.name,
    path: workspace.rootPath,
    kind: WorktreeKind.directory,
    isTinestOwned: false,
    createdAt: now,
  );
  final location = WorktreeRoute(
    hostId: 'server',
    workspaceId: workspace.id,
    worktreeId: checkout.id,
  ).location;

  testWidgets(
    'the worktree pane renders a skeleton, not a spinner, while loading',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gate = Completer<void>();
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
      );
      // Gating the host registry keeps the whole session-tabs chain pending,
      // which is what a slow daemon looks like to the workspace pane.
      final router = await pumpRoutedApp(
        tester,
        api,
        initialLocation: location,
        overrides: [
          hostRegistryControllerProvider.overrideWith(
            () => _GatedHostRegistry(gate.future),
          ),
        ],
        // The skeleton shimmer animates until the gate opens.
        settle: false,
      );
      addTearDown(router.dispose);

      expect(find.byType(WorkspacePaneSkeleton), findsOneWidget);
      expect(find.byType(TRSkeleton), findsWidgets);
      expect(find.bySemanticsLabel('워크스페이스 불러오는 중'), findsOneWidget);
      expect(find.byType(TRSpinner), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(WorkspacePaneSkeleton), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('session-tab-strip')),
        findsOneWidget,
      );
    },
    tags: const <String>['feature_test__workspace_async_loading__widget'],
  );

  testWidgets(
    'creating a terminal shows a placeholder tab before the daemon answers',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
      )..terminalCreateGate = Completer<void>();
      final router = await pumpRoutedApp(
        tester,
        api,
        initialLocation: location,
      );
      addTearDown(router.dispose);

      await tester.tap(find.byKey(const ValueKey('workspace-new-tab-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('workspace-new-terminal')));
      for (var frame = 0; frame < 4; frame += 1) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Feedback is immediate: a starting tab and a visible connecting state
      // exist while the PTY is still being spawned.
      expect(find.byType(TerminalConnectingOverlay), findsOneWidget);
      expect(find.text('터미널 시작 중'), findsWidgets);
      expect(find.byType(TerminalView), findsNothing);

      api.terminalCreateGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(TerminalConnectingOverlay), findsNothing);
      expect(find.byType(TerminalView), findsOneWidget);
      expect(find.text('터미널 1'), findsOneWidget);
      expect(currentLocation(router), contains('/terminals/'));
    },
    tags: const <String>['feature_test__workspace_async_loading__widget'],
  );

  testWidgets(
    'a failed terminal creation rolls the placeholder back and explains',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api =
          FakeTinestApi(
              workspaces: <WorkspaceDto>[workspace],
              worktrees: <WorktreeDto>[checkout],
            )
            ..terminalCreateGate = Completer<void>()
            ..terminalCreateError = Exception('pty failed');
      final router = await pumpRoutedApp(
        tester,
        api,
        initialLocation: location,
      );
      addTearDown(router.dispose);

      await tester.tap(find.byKey(const ValueKey('workspace-new-tab-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('workspace-new-terminal')));
      for (var frame = 0; frame < 4; frame += 1) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(TerminalConnectingOverlay), findsOneWidget);

      api.terminalCreateGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(TerminalConnectingOverlay), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('terminal-create-failed')),
        findsOneWidget,
      );
      expect(find.textContaining('pty failed'), findsOneWidget);

      await tester.tap(find.widgetWithText(TRButton, '확인'));
      await tester.pumpAndSettle();
      expect(find.byType(TerminalView), findsNothing);
      expect(find.text('터미널 시작 중'), findsNothing);
    },
    tags: const <String>['feature_test__workspace_async_loading__widget'],
  );
}

final class _GatedHostRegistry extends HostRegistryController {
  new(this.gate);

  final Future<void> gate;

  @override
  Future<HostRegistryState> build() async {
    await gate;
    return await super.build();
  }
}
