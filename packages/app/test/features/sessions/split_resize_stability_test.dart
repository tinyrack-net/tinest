import 'dart:async';

import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/features/conversation/presentation/chat_message_views.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/fake_tinest_api.dart';
import '../../support/router_harness.dart';

void main() {
  final now = DateTime.utc(2026, 8, 10);
  final workspace = WorkspaceDto(
    id: 'workspace',
    name: 'Tinest',
    rootPath: '/repos/tinest',
    kind: WorkspaceKind.git,
    createdAt: now,
  );
  final checkout = WorktreeDto(
    id: 'checkout',
    workspaceId: workspace.id,
    name: 'main',
    path: workspace.rootPath,
    branch: 'main',
    head: 'abc',
    kind: WorktreeKind.checkout,
    isTinestOwned: false,
    createdAt: now,
  );
  final agent = SessionDto(
    id: 'one',
    worktreeId: checkout.id,
    title: 'Session one',
    agentDefinitionId: 'tinest',
    origin: SessionOrigin.manual,
    status: SessionStatus.idle,
    model: const ModelSelectionDto(modelId: 'openai/gpt-5.6-sol'),
    createdAt: now,
    updatedAt: now,
  );

  testWidgets('ending a split resize drag never reloads the open session', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = FakeTinestApi(
      workspaces: <WorkspaceDto>[workspace],
      worktrees: <WorktreeDto>[checkout],
      agents: <SessionDto>[agent],
      timelines: <String, List<TimelineEventDto>>{
        agent.id: <TimelineEventDto>[
          TimelineEventDto(
            sessionId: agent.id,
            sequence: 1,
            turnId: 'turn-1',
            type: 'user.message',
            data: const <String, dynamic>{
              'text': 'Earlier request',
              'attachments': <Map<String, dynamic>>[],
            },
            createdAt: now,
          ),
        ],
      },
    );
    final router = await pumpRoutedApp(
      tester,
      api,
      initialLocation: SessionRoute(
        hostId: 'server',
        workspaceId: workspace.id,
        worktreeId: checkout.id,
        sessionId: agent.id,
      ).location,
    );
    addTearDown(router.dispose);

    await tester.tap(find.byKey(const ValueKey('workspace-split-right')));
    await tester.pumpAndSettle();
    expect(find.byType(TRSplitView), findsOneWidget);
    expect(find.text('Earlier request', findRichText: true), findsWidgets);

    // Splitting itself persists the pane tree, so the baseline is taken once
    // that write has settled. Only the resize drag is under test here.
    final sessionLoads = api.listSessionsCount;
    final terminalLoads = api.listTerminalsCount;
    final timelineSubscriptions = api.subscribeTimelineCount;
    // A gate held open turns any re-subscription into a visible loading
    // window instead of a round trip the test would pump straight past.
    final gate = Completer<void>();
    api.subscribeTimelineGate = gate;
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });

    await tester.drag(
      find.byKey(const ValueKey<String>('tr-split-view-separator')),
      const Offset(TRSpacing.threeExtraLarge, 0),
    );
    await tester.pump();
    await tester.pump();

    expect(api.subscribeTimelineCount, timelineSubscriptions);
    expect(api.listSessionsCount, sessionLoads);
    expect(api.listTerminalsCount, terminalLoads);
    expect(find.byType(ChatEmptyState), findsNothing);
    expect(find.text('Earlier request', findRichText: true), findsWidgets);

    gate.complete();
    await tester.pumpAndSettle();
    expect(
      tester.widget<TRSplitView>(find.byType(TRSplitView)).ratio,
      greaterThan(0.5),
    );
    expect(find.text('Earlier request', findRichText: true), findsWidgets);
  }, tags: const <String>['feature_test__session_tabs__widget']);

  testWidgets('a resize drag keeps the divider under the pointer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = FakeTinestApi(
      workspaces: <WorkspaceDto>[workspace],
      worktrees: <WorktreeDto>[checkout],
      agents: <SessionDto>[agent],
    );
    final router = await pumpRoutedApp(
      tester,
      api,
      initialLocation: SessionRoute(
        hostId: 'server',
        workspaceId: workspace.id,
        worktreeId: checkout.id,
        sessionId: agent.id,
      ).location,
    );
    addTearDown(router.dispose);

    await tester.tap(find.byKey(const ValueKey('workspace-split-right')));
    await tester.pumpAndSettle();
    final splitView = find.byType(TRSplitView);
    expect(splitView, findsOneWidget);

    final available =
        tester.getSize(splitView).width - TRControlMetrics.borderWidth;
    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey<String>('tr-split-view-separator')),
      ),
    );
    // The first movement is consumed by drag acceptance and reports nothing.
    await gesture.moveBy(const Offset(TRSpacing.threeExtraLarge, 0));
    await gesture.moveBy(const Offset(TRSpacing.large, 0));
    await tester.pump();
    final afterFirst = tester.widget<TRSplitView>(splitView).ratio;
    // A fast pointer delivers several move events before the next frame can
    // rebuild; the divider must absorb every one of them, not only the last.
    await gesture.moveBy(const Offset(TRSpacing.large, 0));
    await gesture.moveBy(const Offset(TRSpacing.large, 0));
    await gesture.moveBy(const Offset(TRSpacing.large, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      tester.widget<TRSplitView>(splitView).ratio,
      closeTo(afterFirst + 3 * TRSpacing.large / available, 1e-9),
    );
  }, tags: const <String>['feature_test__session_tabs__widget']);
}
