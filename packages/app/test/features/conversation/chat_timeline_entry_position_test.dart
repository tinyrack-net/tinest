import 'dart:async';

import 'package:app/src/app/platform/external_url_opener.dart';
import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/features/conversation/application/chat_timeline_model.dart';
import 'package:app/src/features/conversation/presentation/chat_timeline_view.dart';
import 'package:app/src/shared/presentation/tinest_ui_density.dart';
import 'package:app/src/shared/presentation/workspace_skeletons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/fake_tinest_api.dart';
import '../../support/localization.dart';
import '../../support/router_harness.dart';

/// Entry position contract: opening a conversation shows its newest message.
///
/// These cases exist because the timeline asks the virtual list for two
/// mutually exclusive initial positions at once, and the one that wins is not
/// the one the product wants. They deliberately drive the production mount
/// ordering — skeleton first, items a frame later — which the other timeline
/// suites skip by mounting already-populated.
const _geometryTolerance = 0.01;
const _hostId = 'host-entry-position';
final _createdAt = DateTime.utc(2026, 8, 15);

final class _NoopUrlOpener implements ExternalUrlOpener {
  const new();

  @override
  Future<bool> open(Uri uri) => Future<bool>.value(false);
}

/// History rows that measure well under the view's per-kind extent estimate.
///
/// The gap is the point: a list whose estimates overshoot reality must still
/// converge onto the trailing edge instead of stalling part-way.
List<ChatItem> _messages(int count, {String prefix = 'history'}) => <ChatItem>[
  for (var index = 0; index < count; index += 1)
    ChatUserMessage(
      key: '$prefix-$index',
      turnId: 'turn-$index',
      createdAt: _createdAt.add(Duration(seconds: index)),
      text: '$prefix $index',
    ),
];

Future<void> _useDesktopViewport(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Stands in for the app's retained conversation reading positions.
typedef _PositionStore = Map<String, TRVirtualListSnapshot<String>>;

Future<void> _pumpTimeline(
  WidgetTester tester, {
  required List<ChatItem> items,
  required _PositionStore positions,
  required String sessionId,
  bool busy = false,
  bool loading = false,
}) {
  final sessionKey = 'conversation:$_hostId:$sessionId';
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        externalUrlOpenerProvider.overrideWithValue(const _NoopUrlOpener()),
      ],
      child: MaterialApp(
        theme: testLightTheme,
        darkTheme: testDarkTheme,
        locale: testLocale,
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        builder: (context, child) => TinestUiDensity(child: child!),
        home: Scaffold(
          body: ChatTimelineView(
            sessionKey: sessionKey,
            readingPosition: positions[sessionKey],
            onReadingPositionChanged: (key, position) => position == null
                ? positions.remove(key)
                : positions[key] = position,
            items: items,
            busy: busy,
            loading: loading,
            hostId: _hostId,
          ),
        ),
      ),
    ),
  );
}

Finder get _scrollable => find
    .descendant(
      of: find.byType(ChatTimelineView),
      matching: find.byType(Scrollable),
    )
    .first;

ScrollPosition _scrollPosition(WidgetTester tester) =>
    tester.state<ScrollableState>(_scrollable).position;

/// Asserts the viewport rests on the newest row.
///
/// `extentAfter` alone is not evidence: an underfilled viewport reports zero
/// while sitting at the top, and `maxScrollExtent` is derived from estimates,
/// so the geometry can agree while the newest row is nowhere on screen. Every
/// clause below rules out one of those false positives.
void _expectOpenedAtNewest(
  WidgetTester tester, {
  required String newestKey,
  required String oldestKey,
  required String reason,
}) {
  final position = _scrollPosition(tester);
  expect(
    position.maxScrollExtent,
    greaterThan(0),
    reason: '$reason: the history must overfill the viewport to be meaningful',
  );
  expect(position.extentAfter, closeTo(0, _geometryTolerance), reason: reason);
  expect(
    position.pixels,
    closeTo(position.maxScrollExtent, _geometryTolerance),
    reason: reason,
  );
  expect(
    find.byKey(ValueKey<String>(newestKey)),
    findsOneWidget,
    reason: '$reason: the newest row must be built and on screen',
  );
  expect(
    find.byKey(ValueKey<String>(oldestKey)),
    findsNothing,
    reason: '$reason: the oldest row must be far above the viewport',
  );
  expect(
    tester.takeException(),
    isNull,
    reason: '$reason: layout must resolve without exhausting correction cycles',
  );
}

TimelineEventDto _event(String sessionId, int sequence) => TimelineEventDto(
  sessionId: sessionId,
  sequence: sequence,
  turnId: 'turn-$sequence',
  type: 'user.message',
  data: <String, dynamic>{
    'text': 'history $sequence',
    'attachments': const <Map<String, dynamic>>[],
  },
  createdAt: _createdAt.add(Duration(seconds: sequence)),
);

void main() {
  final now = DateTime.utc(2026, 8, 15);
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
  SessionDto session(String id, String title) => SessionDto(
    id: id,
    worktreeId: checkout.id,
    title: title,
    agentDefinitionId: 'tinest',
    origin: SessionOrigin.manual,
    status: SessionStatus.idle,
    model: const ModelSelectionDto(modelId: 'openai/gpt-5.6-sol'),
    createdAt: now,
    updatedAt: now,
  );
  String locationOf(String sessionId) => SessionRoute(
    hostId: 'server',
    workspaceId: workspace.id,
    worktreeId: checkout.id,
    sessionId: sessionId,
  ).location;

  testWidgets(
    'T-COLD: a cold first entry into a long session opens at its newest '
    'message',
    tags: const <String>['feature_test__turn_execution__widget'],
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final agent = session('agent', 'Agent');
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        agents: <SessionDto>[agent],
        timelines: <String, List<TimelineEventDto>>{
          agent.id: <TimelineEventDto>[
            for (var sequence = 1; sequence <= 300; sequence += 1)
              _event(agent.id, sequence),
          ],
        },
      )..subscribeTimelineGate = Completer<void>();
      final router = await pumpRoutedApp(
        tester,
        api,
        initialLocation: locationOf(agent.id),
        // The skeleton shimmer animates until the gate opens.
        settle: false,
      );
      addTearDown(router.dispose);

      expect(find.byType(ChatTimelineSkeleton), findsOneWidget);

      api.subscribeTimelineGate!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(ChatTimelineSkeleton), findsNothing);
      _expectOpenedAtNewest(
        tester,
        newestKey: 'user-300',
        oldestKey: 'user-1',
        reason: 'cold first entry',
      );
    },
  );

  testWidgets(
    'T-POISON: a session that was once shorter than the viewport still opens '
    'at its newest message',
    tags: const <String>['feature_test__turn_execution__widget'],
    (tester) async {
      await _useDesktopViewport(tester);
      final positions = _PositionStore();
      const sessionId = 'poison-session';

      // Production mount ordering: skeleton, then a short history that
      // underfills the viewport, then the same session grown past it.
      await _pumpTimeline(
        tester,
        items: const <ChatItem>[],
        positions: positions,
        sessionId: sessionId,
        loading: true,
      );
      await tester.pump();
      await _pumpTimeline(
        tester,
        items: _messages(2),
        positions: positions,
        sessionId: sessionId,
      );
      await tester.pumpAndSettle();

      // Unmounting is what forces the deactivate-time save.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      await _pumpTimeline(
        tester,
        items: _messages(120),
        positions: positions,
        sessionId: sessionId,
      );
      await tester.pumpAndSettle();

      _expectOpenedAtNewest(
        tester,
        newestKey: 'history-119',
        oldestKey: 'history-0',
        reason: 're-entry after the session outgrew the viewport',
      );
    },
  );

  testWidgets(
    'T-POISON-CONTROL: the same sequence with no retained position opens at '
    'the newest message',
    tags: const <String>['feature_test__turn_execution__widget'],
    (tester) async {
      await _useDesktopViewport(tester);
      const sessionId = 'control-session';

      await _pumpTimeline(
        tester,
        items: _messages(2),
        positions: _PositionStore(),
        sessionId: sessionId,
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      await _pumpTimeline(
        tester,
        items: _messages(120),
        positions: _PositionStore(),
        sessionId: sessionId,
      );
      await tester.pumpAndSettle();

      _expectOpenedAtNewest(
        tester,
        newestKey: 'history-119',
        oldestKey: 'history-0',
        reason: 'negative control: no shared restoration state',
      );
    },
  );

  testWidgets(
    'T-RUNNING: a session first seen with only the running indicator opens at '
    'its newest message once history arrives',
    tags: const <String>['feature_test__turn_execution__widget'],
    (tester) async {
      await _useDesktopViewport(tester);
      final positions = _PositionStore();
      const sessionId = 'running-session';

      await _pumpTimeline(
        tester,
        items: const <ChatItem>[],
        positions: positions,
        sessionId: sessionId,
        busy: true,
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('chat-running')),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      await _pumpTimeline(
        tester,
        items: _messages(120),
        positions: positions,
        sessionId: sessionId,
      );
      await tester.pumpAndSettle();

      _expectOpenedAtNewest(
        tester,
        newestKey: 'history-119',
        oldestKey: 'history-0',
        reason: 'history arriving after a running-only first paint',
      );
    },
  );

  testWidgets(
    'T-JUMP: the entry position is stable when the next event arrives',
    tags: const <String>['feature_test__turn_execution__widget'],
    (tester) async {
      await _useDesktopViewport(tester);
      final positions = _PositionStore();
      const sessionId = 'jump-session';

      await _pumpTimeline(
        tester,
        items: _messages(2),
        positions: positions,
        sessionId: sessionId,
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      await _pumpTimeline(
        tester,
        items: _messages(120),
        positions: positions,
        sessionId: sessionId,
      );
      await tester.pumpAndSettle();
      final onEntry = _scrollPosition(tester).pixels;
      final onEntryMax = _scrollPosition(tester).maxScrollExtent;

      // A content change re-runs the trailing-follow branch, which can drag a
      // list that opened at the top down to the bottom one event later. That
      // late correction is a visible jump, so the entry frame itself — not
      // just the settled state after the next event — has to be at the end.
      await _pumpTimeline(
        tester,
        items: _messages(121),
        positions: positions,
        sessionId: sessionId,
      );
      await tester.pumpAndSettle();

      _expectOpenedAtNewest(
        tester,
        newestKey: 'history-120',
        oldestKey: 'history-0',
        reason: 'after one more event',
      );
      expect(
        onEntry,
        closeTo(onEntryMax, _geometryTolerance),
        reason: 'the reader must already be at the end before the next event',
      );
    },
  );

  testWidgets(
    'T-BUCKET-IDENTITY: leaving a session scrolled up and returning restores '
    'that reading position',
    tags: const <String>[
      'feature_test__turn_execution__widget',
      'ui_state__conversation_timeline__history_anchored__widget',
    ],
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final first = session('agent-a', 'Agent A');
      final second = session('agent-b', 'Agent B');
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        agents: <SessionDto>[first, second],
        timelines: <String, List<TimelineEventDto>>{
          for (final agent in <SessionDto>[first, second])
            agent.id: <TimelineEventDto>[
              for (var sequence = 1; sequence <= 120; sequence += 1)
                _event(agent.id, sequence),
            ],
        },
      );
      final router = await pumpRoutedApp(
        tester,
        api,
        initialLocation: locationOf(first.id),
      );
      addTearDown(router.dispose);

      final position = _scrollPosition(tester);
      position.jumpTo(position.maxScrollExtent * 0.4);
      await tester.pumpAndSettle();
      final saved = position.pixels;

      router.go(locationOf(second.id));
      await tester.pumpAndSettle();
      router.go(locationOf(first.id));
      await tester.pumpAndSettle();

      expect(
        _scrollPosition(tester).pixels,
        closeTo(saved, 1),
        reason: 'a session left mid-history reopens where the reader left it',
      );
    },
  );
}
