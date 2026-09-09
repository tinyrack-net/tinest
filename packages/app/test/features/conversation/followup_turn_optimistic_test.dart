import 'dart:async';

import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/features/conversation/presentation/chat_timeline_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/fake_tinest_api.dart';
import '../../support/localization.dart';
import '../../support/router_harness.dart';

/// A follow-up prompt in a session that already has history.
///
/// The first turn of a new session is covered by its own pending registry; a
/// follow-up had nothing, so the prompt left the composer and stayed invisible
/// for a daemon round trip plus plugin, skill, and project-doc loading.
void main() {
  final now = DateTime.utc(2026, 8, 3);
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
  final session = SessionDto(
    id: 'session',
    worktreeId: checkout.id,
    title: 'Session',
    agentDefinitionId: 'tinest',
    origin: SessionOrigin.manual,
    status: SessionStatus.idle,
    model: const ModelSelectionDto(modelId: 'openai/gpt-5.6-sol'),
    createdAt: now,
    updatedAt: now,
  );
  final history = <TimelineEventDto>[
    TimelineEventDto(
      sessionId: session.id,
      sequence: 1,
      turnId: 'turn-0',
      type: 'user.message',
      data: const <String, dynamic>{'text': 'Earlier prompt'},
      createdAt: now,
    ),
    TimelineEventDto(
      sessionId: session.id,
      sequence: 2,
      turnId: 'turn-0',
      type: 'assistant.message',
      data: const <String, dynamic>{'text': 'Earlier answer'},
      createdAt: now,
    ),
  ];
  final location = SessionRoute(
    hostId: 'server',
    workspaceId: workspace.id,
    worktreeId: checkout.id,
    sessionId: session.id,
  ).location;

  FakeTinestApi api() => FakeTinestApi(
    workspaces: <WorkspaceDto>[workspace],
    worktrees: <WorktreeDto>[checkout],
    agents: <SessionDto>[session],
    timelines: <String, List<TimelineEventDto>>{session.id: history},
  );

  const inputKey = ValueKey<String>('session-composer-input');
  const sendKey = ValueKey<String>('session-composer-send');

  testWidgets('a follow-up prompt is visible before the daemon echoes it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final startGate = Completer<void>();
    final fake = api()
      ..startTurnGate = startGate
      ..emitTurnStartEvents = true;
    final router = await pumpRoutedApp(
      tester,
      fake,
      initialLocation: location,
      disableAnimations: true,
    );
    addTearDown(router.dispose);

    const prompt = 'Second request that must stay visible';
    await tester.enterText(find.byKey(inputKey), prompt);
    await tester.tap(find.byKey(sendKey));
    for (var frame = 0; frame < 4; frame += 1) {
      await tester.pump();
    }

    final timeline = find.byType(ChatTimelineView).hitTestable();
    expect(timeline, findsOneWidget);
    expect(
      find.descendant(
        of: timeline,
        matching: find.text(prompt, findRichText: true),
      ),
      findsOneWidget,
      reason: 'the prompt reads as sent while the RPC is still in flight',
    );

    startGate.complete();
    for (var frame = 0; frame < 8; frame += 1) {
      await tester.pump();
    }

    // The durable echo takes the same position rather than arriving beside
    // the optimistic message.
    expect(
      find.descendant(
        of: timeline,
        matching: find.text(prompt, findRichText: true),
      ),
      findsOneWidget,
      reason: 'the echo replaces the optimistic message, never doubles it',
    );
    expect(fake.startedPrompts, <String>[prompt]);
  }, tags: const <String>['feature_test__turn_execution__widget']);

  testWidgets('a rejected follow-up leaves nothing behind in the transcript', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fake = api()..startTurnError = Exception('daemon rejected the turn');
    final router = await pumpRoutedApp(
      tester,
      fake,
      initialLocation: location,
      disableAnimations: true,
    );
    addTearDown(router.dispose);

    const prompt = 'Prompt that must not be lost';
    await tester.enterText(find.byKey(inputKey), prompt);
    await tester.tap(find.byKey(sendKey));
    for (var frame = 0; frame < 8; frame += 1) {
      await tester.pump();
    }

    final timeline = find.byType(ChatTimelineView).hitTestable();
    expect(
      find.descendant(
        of: timeline,
        matching: find.text(prompt, findRichText: true),
      ),
      findsNothing,
      reason: 'a prompt the composer took back is not also in the transcript',
    );
    expect(
      tester.widget<TRTextField>(find.byKey(inputKey)).controller!.text,
      prompt,
    );
  }, tags: const <String>['feature_test__turn_execution__widget']);

  testWidgets('the composer queues behind a turn it has already started', (
    tester,
  ) async {
    // The daemon acks a turn well before it reports the session as running,
    // and well before the durable echo. In that window the status is still
    // idle, so without the accepted prompt counting as busy the next send
    // races a turn that is already under way.
    await tester.binding.setSurfaceSize(const Size(1100, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fake = api()
      ..emitTurnStartEvents = false
      ..emitUserMessageEcho = false;
    final router = await pumpRoutedApp(
      tester,
      fake,
      initialLocation: location,
      disableAnimations: true,
    );
    addTearDown(router.dispose);

    expect(
      tester.widget<TRIconButton>(find.byKey(sendKey)).label,
      testL10n.composerSendLabel,
      reason: 'an idle session sends',
    );

    await tester.enterText(find.byKey(inputKey), 'first');
    await tester.tap(find.byKey(sendKey));
    for (var frame = 0; frame < 4; frame += 1) {
      await tester.pump();
    }
    expect(fake.startedPrompts, <String>['first']);

    // The session is still reported idle and nothing has echoed, so the only
    // thing that knows a turn is under way is the accepted prompt itself.
    await tester.enterText(find.byKey(inputKey), 'second');
    for (var frame = 0; frame < 2; frame += 1) {
      await tester.pump();
    }
    expect(
      tester.widget<TRIconButton>(find.byKey(sendKey)).label,
      testL10n.composerQueueLabel,
      reason: 'the next prompt queues behind the turn already accepted',
    );
  }, tags: const <String>['feature_test__conversation_turn_queue__widget']);
}
