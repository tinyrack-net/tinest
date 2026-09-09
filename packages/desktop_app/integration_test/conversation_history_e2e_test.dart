import 'dart:async';
import 'dart:io';

import 'package:agent/agent.dart';
import 'package:app/testing/app/tinest_app.dart';
import 'package:app/testing/features/conversation/presentation/chat_timeline_view.dart';
import 'package:client/client.dart';
import 'package:daemon/daemon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';

import 'support/pump_until.dart';
import 'support/real_daemon_fixture.dart';
import 'support/tap_visible.dart';

/// Deltas streamed per scripted answer.
///
/// One row is written per delta, so this is what makes a handful of turns
/// exceed a page and forces the reader onto the paging path the way a real
/// long conversation does.
const int _deltasPerAnswer = 60;

/// Deltas streamed for the first answer alone.
///
/// The daemon caps a window at twice the page it was asked for, so an answer
/// longer than that is split and a reader paging into it holds half a block.
/// That is the ordinary shape of a long conversation and the one the reader's
/// row identity has to survive; the later turns stay short so entry still
/// lands on a turn boundary.
const int _deltasPerFirstAnswer = timelineHistoryPageSize * 2 + 50;
const int _turns = 5;
const double _geometryTolerance = 0.01;
const String _historyModelId = 'openai/gpt-5.6-sol';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a long conversation opens at its newest message, pages back through '
    'history, and returns where the reader left it',
    (tester) async {
      tester.binding.platformDispatcher.localeTestValue = const Locale('ko');
      addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fixture = await RealDaemonFixture.start(
        id: 'conversation-history',
        provider: _HistoryProvider(),
        providerCatalogMetadataSource: const _HistoryCatalogMetadataSource(),
      );
      addTearDown(fixture.dispose);
      final client = await fixture.connect(clientId: 'history-setup');
      addTearDown(client.close);
      final workspace = Directory('${fixture.home.path}/workspace')
        ..createSync();
      await client.workspaces.registerWorkspace(
        workspaceId: 'history-workspace',
        checkoutId: 'history-checkout',
        rootPath: workspace.path,
        name: 'History Workspace',
      );
      final registeredWorktree =
          (await client.workspaces.getWorkspaceCatalog()).worktrees.single;
      // The default Agent includes function and deferred tools. Manual
      // custom-provider models advertise function tools only, so use a
      // deterministic full-surface bundled model with the injected gateway.
      final model = (await client.providers.listProviderModels('openai'))
          .singleWhere((candidate) => candidate.id == _historyModelId);
      expect(model.capabilities.streaming, CapabilitySupport.supported);
      expect(model.capabilities.functionTools, CapabilitySupport.supported);
      expect(model.capabilities.deferredTools, CapabilitySupport.supported);

      // A conversation the reader is coming back to, not one they are starting:
      // the history exists before the app is ever mounted.
      final long = await client.sessions.createSession(
        id: 'history-session',
        worktreeId: 'history-checkout',
        title: '긴 대화',
        agentDefinitionId: 'tinest',
        model: ModelSelectionDto(modelId: model.id),
      );
      for (var turn = 1; turn <= _turns; turn += 1) {
        await client.sessions.startTurn(
          sessionId: long.id,
          turnId: 'history-turn-$turn',
          prompt: '질문 $turn',
        );
        await _awaitIdle(client, long.id);
      }
      final other = await client.sessions.createSession(
        id: 'other-session',
        worktreeId: 'history-checkout',
        title: '다른 대화',
        agentDefinitionId: 'tinest',
        model: ModelSelectionDto(modelId: model.id),
      );
      await client.sessions.startTurn(
        sessionId: other.id,
        turnId: 'other-turn',
        prompt: '다른 질문',
      );
      await _awaitIdle(client, other.id);

      final events = await client.sessions.subscribeTimeline(long.id);
      expect(
        events.length,
        greaterThan(timelineHistoryPageSize),
        reason: 'the scripted history must exceed one page to be a test',
      );

      await _openSession(
        tester,
        fixture,
        registeredWorktree.id,
        '긴 대화',
        'history-session',
      );

      // 1. Entering shows the newest message, not the oldest.
      await pumpUntil(tester, _newest());
      _expectAtNewest(tester, phase: 'first entry');
      expect(
        _oldest(),
        findsNothing,
        reason: 'the oldest turn is beyond the page loaded on entry',
      );
      final initialPageKeys = tester
          .widget<ChatTimelineView>(find.byType(ChatTimelineView))
          .items
          .map((item) => item.key)
          .toSet();

      // 2. A reader who leaves with messages below them returns to their spot.
      //    The anchor is inside the page loaded on entry on purpose: a switch
      //    disposes the conversation and reloads that page, so an anchor from
      //    deeper history is deliberately not restorable (see 4).
      ({String key, double viewportOffset})? leftAt;
      for (var drag = 0; drag < 3 && leftAt == null; drag += 1) {
        await tester.drag(_timeline, const Offset(0, 600));
        await tester.pump(const Duration(milliseconds: 100));
        if (_position(tester).extentAfter > 1) {
          leftAt = _firstFullyVisibleAnchor(tester, initialPageKeys);
        }
      }
      final savedPosition = leftAt;
      if (savedPosition == null) {
        throw TestFailure(
          'The initial history page had no fully visible row away from its '
          'trailing edge.',
        );
      }
      expect(
        _position(tester).extentAfter,
        greaterThan(1),
        reason: 'the reader must actually be away from the end to restore one',
      );
      await _activateSession(tester, '다른 대화', 'other-session');
      await _activateSession(tester, '긴 대화', 'history-session');
      final restoredItem = _chatItem(savedPosition.key);
      var restorationState = 'the restored timeline was not evaluated';
      try {
        await pumpUntilCondition(tester, () {
          final matchingItems = restoredItem.evaluate().length;
          final timeline = tester.widget<ChatTimelineView>(
            find.byType(ChatTimelineView),
          );
          if (matchingItems != 1) {
            final scrollables = _timeline.evaluate().length;
            final extentAfter = scrollables == 1
                ? _position(tester).extentAfter.toString()
                : 'unavailable';
            final modelContains = timeline.items.any(
              (item) => item.key == savedPosition.key,
            );
            restorationState =
                'matchingItems=$matchingItems, '
                'modelContains=$modelContains, '
                'modelItems=${timeline.items.length}, '
                'snapshot=${timeline.readingPosition != null}, '
                'extentAfter=$extentAfter';
            return false;
          }
          final viewport = tester.getRect(_timeline);
          final item = tester.getRect(restoredItem);
          final restoredOffset = item.top - viewport.top;
          final hasSnapshot = timeline.readingPosition != null;
          restorationState =
              'matchingItems=1, snapshot=$hasSnapshot, '
              'expectedOffset=${savedPosition.viewportOffset}, '
              'actualOffset=$restoredOffset, '
              'extentAfter=${_position(tester).extentAfter}';
          return (restoredOffset - savedPosition.viewportOffset).abs() <=
                  _geometryTolerance &&
              _position(tester).extentAfter > 1;
        }, 'the saved history row to return to its viewport position');
      } on TestFailure catch (error) {
        throw TestFailure('$error Last restoration state: $restorationState');
      }
      expect(
        tester.getTopLeft(restoredItem).dy - tester.getTopLeft(_timeline).dy,
        closeTo(savedPosition.viewportOffset, _geometryTolerance),
        reason: 'a reader who left with messages below them returns to them',
      );
      expect(
        _position(tester).extentAfter,
        greaterThan(1),
        reason: 'restoration must not fall back to the newest message',
      );

      // 3. Leaving from the newest message returns to the newest message,
      //    which is what makes the restore in 2 conditional rather than sticky.
      await _dragToNewest(tester);
      _expectAtNewest(tester, phase: 'after returning to the end');
      await _activateSession(tester, '다른 대화', 'other-session');
      await _activateSession(tester, '긴 대화', 'history-session');
      await pumpUntil(tester, _newest());
      _expectAtNewest(tester, phase: 'reopened from the end');

      // 4. Scrolling back loads earlier turns that entry never fetched. The
      //    first answer outgrows the window the daemon will build, so paging
      //    into it leaves the reader holding half a streamed answer. The pages
      //    that follow extend that row, and it has to still be the same row
      //    afterwards: a row that changes identity is a row the list has to
      //    replace, and the reader is sent back to the leading edge with it.
      //    Real drags rather than a programmatic jump: the edge request fires
      //    from scroll notifications, so a jump would prove the fetch works
      //    without proving a reader can ever provoke it.
      String? held;
      for (var drag = 0; drag < 120; drag += 1) {
        if (_oldest().evaluate().isNotEmpty) break;
        final head = _oldestRenderedKey(tester);
        held ??= head.startsWith('assistant-') ? head : null;
        await tester.drag(_timeline, const Offset(0, 600));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        _oldest(),
        findsWidgets,
        reason: 'the oldest turn arrives from an earlier page',
      );
      expect(
        held,
        isNotNull,
        reason: 'paging has to land inside the split answer to prove anything',
      );
      expect(
        tester
            .widget<ChatTimelineView>(find.byType(ChatTimelineView))
            .items
            .map((item) => item.key),
        contains(held),
        reason: 'the pages that extended the reader row did not rename it',
      );

      // 5. A cold start opens at the newest message too, which is the report
      //    this whole contract came from, and it is back to one page: paged
      //    history is a reading aid, not state the app carries around.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await _openSession(
        tester,
        fixture,
        registeredWorktree.id,
        '긴 대화',
        'history-session',
      );
      await pumpUntil(tester, _newest());
      _expectAtNewest(tester, phase: 'cold start');
      expect(_oldest(), findsNothing);
    },
    // Written inline and whole. The feature verifier reads evidence out of
    // source text and only counts a tag that follows its `testWidgets(`, so a
    // hoisted constant is a tag it cannot see.
    tags: const <String>[
      'feature_test__conversation_history_pagination__e2e',
      'feature_scenario__conversation_history_pagination__page_back__e2e',
    ],
  );
}

/// Built fresh per use: a Finder caches its matches, and stringifying one that
/// cached elements from a torn-down tree throws before any assertion runs.
Finder _newest() => find.textContaining('질문 5 응답 59', findRichText: true);

Finder _oldest() => find.textContaining('질문 1 응답 0', findRichText: true);

Future<void> _awaitIdle(TinestApi client, String sessionId) => awaitCondition(
  () async {
    final session = (await client.sessions.listSessions()).singleWhere(
      (candidate) => candidate.id == sessionId,
    );
    if (session.status == SessionStatus.failed) {
      throw TestFailure(
        'Session $sessionId failed before becoming idle: '
        '${session.lastError ?? 'unknown error'}.',
      );
    }
    return session.status == SessionStatus.idle;
  },
  'session $sessionId to finish its turn',
  budget: e2eTurnBudget,
);

Finder get _timeline => find
    .descendant(
      of: find.byType(ChatTimelineView),
      matching: find.byType(Scrollable),
    )
    .first;

ScrollPosition _position(WidgetTester tester) =>
    tester.state<ScrollableState>(_timeline).position;

Finder _chatItem(String key) => find.byWidgetPredicate(
  (widget) => widget is ChatItemView && widget.item.key == key,
  description: 'chat item $key',
);

/// Key of the oldest row the timeline is currently rendering.
String _oldestRenderedKey(WidgetTester tester) => tester
    .widget<ChatTimelineView>(find.byType(ChatTimelineView))
    .items
    .first
    .key;

({String key, double viewportOffset})? _firstFullyVisibleAnchor(
  WidgetTester tester,
  Set<String> allowedKeys,
) {
  final viewport = tester.getRect(_timeline);
  final visible = <({String key, double viewportOffset})>[];
  final items = find.descendant(
    of: _timeline,
    matching: find.byType(ChatItemView),
  );
  for (final widget in tester.widgetList<ChatItemView>(items)) {
    if (!allowedKeys.contains(widget.item.key)) continue;
    final item = tester.getRect(find.byWidget(widget));
    if (item.top < viewport.top || item.bottom > viewport.bottom) continue;
    visible.add((
      key: widget.item.key,
      viewportOffset: item.top - viewport.top,
    ));
  }
  if (visible.isEmpty) return null;
  visible.sort(
    (left, right) => left.viewportOffset.compareTo(right.viewportOffset),
  );
  return visible.first;
}

/// Asserts the reader is resting on the newest message.
///
/// `extentAfter` alone would pass while parked at the top of a list shorter
/// than its viewport, so the scroll extent is checked for meaning first.
void _expectAtNewest(WidgetTester tester, {required String phase}) {
  final position = _position(tester);
  expect(
    position.maxScrollExtent,
    greaterThan(0),
    reason: 'timeline overfills its viewport at $phase',
  );
  expect(
    position.extentAfter,
    closeTo(0, _geometryTolerance),
    reason: 'timeline rests on its newest message at $phase',
  );
}

/// Drags the transcript forwards until it rests on the newest message.
Future<void> _dragToNewest(WidgetTester tester) async {
  for (var attempt = 0; attempt < 200; attempt += 1) {
    if (_position(tester).extentAfter <= _geometryTolerance) return;
    await tester.drag(_timeline, const Offset(0, -900));
    await tester.pump(const Duration(milliseconds: 100));
  }
  throw TestFailure('Timed out dragging forward to the newest message.');
}

/// Moves to [title] the way a reader does, through the sessions menu.
///
/// Used in both directions on purpose: the menu opens a conversation that has
/// no tab yet and re-activates one that does, so a single path covers leaving
/// a conversation and coming back to it.
Future<void> _activateSession(
  WidgetTester tester,
  String title,
  String sessionId,
) async {
  await _openAllSessionsMenu(tester);
  final conversation = find.text(title).hitTestable();
  await pumpUntil(tester, conversation);
  await tester.tap(conversation.last);
  await pumpUntilCondition(
    tester,
    () =>
        _sessionTimeline(sessionId).evaluate().length == 1 &&
        find.byType(ChatTimelineView).evaluate().length == 1,
    'session $sessionId to own the active conversation timeline',
  );
}

Future<void> _openSession(
  WidgetTester tester,
  RealDaemonFixture fixture,
  String worktreeId,
  String title,
  String sessionId,
) async {
  await tester.pumpWidget(TinestApp(services: fixture.services));
  await pumpUntil(tester, find.text('History Workspace'));
  final worktree = find
      .byKey(ValueKey<String>('workspace-worktree-$worktreeId'))
      .hitTestable();
  await pumpUntil(tester, worktree);
  await tester.tap(worktree.last);
  await _openAllSessionsMenu(tester);
  final conversation = find.text(title).hitTestable();
  await pumpUntil(tester, conversation);
  await tester.tap(conversation.last);
  await pumpUntilCondition(
    tester,
    () =>
        _sessionTimeline(sessionId).evaluate().length == 1 &&
        find.byType(ChatTimelineView).evaluate().length == 1,
    'session $sessionId to own the active conversation timeline',
  );
}

/// Opens the sessions menu through the part of its trigger the view can hit.
Future<void> _openAllSessionsMenu(WidgetTester tester) => tapVisible(
  tester,
  find.byKey(const ValueKey<String>('workspace-all-sessions-menu')),
  'the all-sessions menu',
);

Finder _sessionTimeline(String sessionId) => find.byWidgetPredicate(
  (widget) =>
      widget is ChatTimelineView &&
      widget.sessionKey ==
          'conversation:conversation-history-daemon:$sessionId',
  description: 'timeline for session $sessionId',
);

final class _HistoryCatalogMetadataSource
    implements ProviderCatalogMetadataSource {
  const new();

  @override
  Future<Map<String, List<ProviderCatalogMetadata>>> fetch(
    Set<String> providerIds,
  ) async => <String, List<ProviderCatalogMetadata>>{
    if (providerIds.contains('openai'))
      'openai': const <ProviderCatalogMetadata>[
        ProviderCatalogMetadata(
          id: 'gpt-5.6-sol',
          label: 'History model',
          capabilities: ModelCapabilitiesDto(
            streaming: CapabilitySupport.supported,
            toolCalling: CapabilitySupport.supported,
            functionTools: CapabilitySupport.supported,
            deferredTools: CapabilitySupport.supported,
            source: CapabilitySource.refreshed,
          ),
        ),
      ],
  };

  @override
  Future<void> close() async {}
}

/// Answers every prompt with enough deltas to outgrow a single page.
final class _HistoryProvider implements ModelGateway {
  @override
  String get id => 'conversation-history';

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    final prompt = request.history.whereType<UserConversationItem>().last.text;
    // The first answer alone outgrows a window, so paging back into it is
    // paging into the middle of one block rather than onto a turn boundary.
    final deltas = prompt == '질문 1' ? _deltasPerFirstAnswer : _deltasPerAnswer;
    final buffer = StringBuffer();
    for (var index = 0; index < deltas; index += 1) {
      cancellation.throwIfCancelled();
      final delta = '$prompt 응답 $index\n\n';
      buffer.write(delta);
      yield ModelTextDelta(delta);
    }
    yield ModelResponseCompleted(
      assistant: AssistantConversationItem(text: buffer.toString()),
    );
  }
}
