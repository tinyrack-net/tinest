import 'dart:async';

import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/shared/presentation/workspace_skeletons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';

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

  testWidgets(
    'the sidebar shows a tree skeleton, not a false empty state, while '
    'catalogs load',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gate = Completer<void>();
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        workspaceCatalogGate: gate.future,
      );
      final router = await pumpRoutedApp(
        tester,
        api,
        initialLocation: const WorkspaceHomeRoute().location,
        // The skeleton shimmer animates until the gate opens.
        settle: false,
      );
      addTearDown(router.dispose);

      expect(find.byType(SidebarTreeSkeleton), findsOneWidget);
      expect(find.bySemanticsLabel('워크스페이스 목록 불러오는 중'), findsOneWidget);
      semantics.dispose();
      expect(find.text('아직 workspace가 없습니다.'), findsNothing);
      expect(find.text('설정된 daemon이 없습니다.'), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SidebarTreeSkeleton), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('workspace-sidebar-tree')),
        findsOneWidget,
      );
      expect(find.text('Workspace'), findsWidgets);
    },
    tags: const <String>['feature_test__workspace_async_loading__widget'],
  );

  testWidgets('an empty catalog still resolves to the real empty state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = FakeTinestApi();
    final router = await pumpRoutedApp(
      tester,
      api,
      initialLocation: const WorkspaceHomeRoute().location,
    );
    addTearDown(router.dispose);

    expect(find.byType(SidebarTreeSkeleton), findsNothing);
    expect(find.text('아직 workspace가 없습니다.'), findsOneWidget);
  }, tags: const <String>['feature_test__workspace_async_loading__widget']);
}
