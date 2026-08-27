import 'dart:async';
import 'dart:math' as math;

import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/app/platform/external_url_opener.dart';
import 'package:app/src/features/conversation/application/chat_timeline_model.dart';
import 'package:app/src/features/conversation/presentation/chat_timeline_view.dart';
import 'package:app/src/shared/presentation/tinest_ui_density.dart';
import 'package:client/client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/localization.dart';

const _geometryTolerance = 0.01;
const _hostId = 'host-paging';
const _sessionId = 'paging-session';
final _createdAt = DateTime.utc(2026, 8, 15);

final class _NoopUrlOpener implements ExternalUrlOpener {
  const _NoopUrlOpener();

  @override
  Future<bool> open(Uri uri) => Future<bool>.value(false);
}

List<ChatItem> _messages(int first, int last) => <ChatItem>[
  for (var index = first; index <= last; index += 1)
    ChatUserMessage(
      key: 'history-$index',
      turnId: 'turn-$index',
      createdAt: _createdAt.add(Duration(seconds: index)),
      text: 'history $index',
    ),
];

Finder get _scrollable => find
    .descendant(
      of: find.byType(ChatTimelineView),
      matching: find.byType(Scrollable),
    )
    .first;

ScrollPosition _scrollPosition(WidgetTester tester) =>
    tester.state<ScrollableState>(_scrollable).position;

/// Pumps fixed frames instead of settling.
///
/// The in-flight status row animates for as long as it is shown, so a list
/// displaying one never reaches a quiescent state.
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var frame = 0; frame < 8; frame += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The label of the single leading status row, or null when there is none.
String? _statusLabel(WidgetTester tester) {
  final rows = tester.widgetList<TRChatStatusRow>(
    find.byType(TRChatStatusRow),
  );
  return rows.isEmpty ? null : rows.single.label;
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(ChatTimelineView)));

Future<void> _pump(
  WidgetTester tester, {
  required List<ChatItem> items,
  required VoidCallback onLoadOlder,
  Object? olderPageKey,
  bool loadingOlder = false,
  bool olderFailed = false,
}) => tester.pumpWidget(
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
          sessionKey: 'conversation:$_hostId:paging-session',
          items: items,
          busy: false,
          hostId: _hostId,
          olderPageKey: olderPageKey,
          loadingOlder: loadingOlder,
          olderFailed: olderFailed,
          onLoadOlder: onLoadOlder,
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'timeline rows keep token-backed edge and inter-row padding',
    tags: const <String>[
      'feature_test__conversation_history_pagination__widget',
    ],
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pump(
        tester,
        items: _messages(1, 3),
        onLoadOlder: () {},
      );
      await tester.pumpAndSettle();

      EdgeInsets paddingFor(String key) => tester
          .widgetList<Padding>(
            find.ancestor(
              of: find.byKey(ValueKey<String>(key)),
              matching: find.byType(Padding),
            ),
          )
          .map((padding) => padding.padding)
          .whereType<EdgeInsets>()
          .singleWhere(
            (padding) =>
                padding.left == TRSpacing.extraLarge &&
                padding.right == TRSpacing.extraLarge,
          );

      expect(
        paddingFor('history-1'),
        const EdgeInsets.fromLTRB(
          TRSpacing.extraLarge,
          TRSpacing.large,
          TRSpacing.extraLarge,
          TRSpacing.small,
        ),
      );
      expect(
        paddingFor('history-2'),
        const EdgeInsets.fromLTRB(
          TRSpacing.extraLarge,
          0,
          TRSpacing.extraLarge,
          TRSpacing.small,
        ),
      );
      expect(
        paddingFor('history-3'),
        const EdgeInsets.fromLTRB(
          TRSpacing.extraLarge,
          0,
          TRSpacing.extraLarge,
          TRSpacing.large,
        ),
      );
    },
  );

  testWidgets(
    'a short conversation with no older history never asks for a page',
    tags: const <String>[
      'feature_test__conversation_history_pagination__widget',
    ],
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var requests = 0;
      await _pump(
        tester,
        items: _messages(1, 3),
        onLoadOlder: () => requests += 1,
      );
      await tester.pumpAndSettle();

      // An underfilled list is already at its leading edge, so a request that
      // merely exists is a request that fires.
      expect(requests, 0);
      expect(_statusLabel(tester), isNull);
    },
  );

  testWidgets(
    'reaching the oldest loaded message asks for each page exactly once',
    tags: const <String>[
      'feature_test__conversation_history_pagination__widget',
      'ui_state__conversation_timeline__history_paging__widget',
    ],
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var requests = 0;
      await _pump(
        tester,
        items: _messages(40, 120),
        olderPageKey: 'older:40',
        onLoadOlder: () => requests += 1,
      );
      await tester.pumpAndSettle();
      expect(requests, 0, reason: 'the reader opens at the newest message');

      final position = _scrollPosition(tester)..jumpTo(0);
      await tester.pumpAndSettle();
      expect(requests, 1);

      // The same cursor must not be asked for again, however much the reader
      // moves around at the top.
      position
        ..jumpTo(position.maxScrollExtent * 0.2)
        ..jumpTo(0);
      await tester.pumpAndSettle();
      expect(requests, 1);
    },
  );

  testWidgets(
    'a page in flight shows one status row and prepending keeps the reader '
    'where they were',
    tags: const <String>[
      'feature_test__conversation_history_pagination__widget',
    ],
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pump(
        tester,
        items: _messages(40, 120),
        olderPageKey: 'older:40',
        loadingOlder: true,
        onLoadOlder: () {},
      );
      await _pumpFrames(tester);
      _scrollPosition(tester).jumpTo(0);
      await _pumpFrames(tester);
      expect(_statusLabel(tester), _l10n(tester).conversationLoadingOlder);

      final anchor = find.byKey(const ValueKey<String>('history-42'));
      final before = tester.getTopLeft(anchor).dy;

      await _pump(
        tester,
        items: _messages(1, 120),
        olderPageKey: 'older:1',
        onLoadOlder: () {},
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(anchor).dy,
        // The row that was first loses its extra top padding to the page that
        // arrived above it. That token is the entire budget: anything larger
        // means the viewport followed the new content instead of the reader.
        closeTo(before, TRSpacing.large + _geometryTolerance),
        reason: 'older messages arrive above the reader, not under them',
      );
      expect(_statusLabel(tester), isNull);
    },
  );

  testWidgets(
    'a failed page reports itself and the reader asks for it again',
    tags: const <String>[
      'feature_test__conversation_history_pagination__widget',
    ],
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var requests = 0;
      await _pump(
        tester,
        items: _messages(40, 120),
        olderPageKey: 'older:40',
        onLoadOlder: () => requests += 1,
      );
      await tester.pumpAndSettle();
      _scrollPosition(tester).jumpTo(0);
      await tester.pumpAndSettle();
      expect(requests, 1);

      await _pump(
        tester,
        items: _messages(40, 120),
        olderPageKey: 'older:40',
        olderFailed: true,
        onLoadOlder: () => requests += 1,
      );
      _scrollPosition(tester).jumpTo(0);
      await _pumpFrames(tester);

      expect(_statusLabel(tester), _l10n(tester).conversationLoadOlderFailed);
      expect(
        requests,
        1,
        reason: 'a failure waits rather than putting itself back on the wire',
      );

      // The row that announced the failure is the way back to the page.
      final retry = find.widgetWithText(
        TRButton,
        _l10n(tester).conversationLoadOlderRetry,
      );
      expect(retry, findsOneWidget);
      await tester.tap(retry);
      await _pumpFrames(tester);
      expect(requests, 2);
    },
  );

  testWidgets(
    'the status row is announced in the reader locale',
    tags: const <String>[
      'feature_test__conversation_history_pagination__widget',
    ],
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pump(
        tester,
        items: _messages(40, 120),
        olderPageKey: 'older:40',
        loadingOlder: true,
        onLoadOlder: () {},
      );
      await _pumpFrames(tester);
      _scrollPosition(tester).jumpTo(0);
      await _pumpFrames(tester);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ChatTimelineView)),
      );
      expect(_statusLabel(tester), l10n.conversationLoadingOlder);
      expect(find.bySemanticsLabel(l10n.conversationLoadingOlder), findsOne);
    },
  );

  testWidgets(
    'reaching the top of a streamed conversation loads one page, not the '
    'whole session',
    tags: const <String>[
      'feature_test__conversation_history_pagination__widget',
    ],
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // A session stored the way the daemon stores one: a row per streamed
      // delta, so a turn is far longer than a page and every page boundary
      // lands in the middle of one answer.
      final history = _streamedSession(turns: 6, deltasPerTurn: 499);
      final pages = (history.length / timelineHistoryPageSize).ceil();
      final requested = <int>[];
      final extents = <double>[];
      await tester.pumpWidget(
        _app(
          _PagingHarness(
            history: history,
            onRequest: (cursor) {
              requested.add(cursor);
              final scrollable = tester.state<ScrollableState>(_scrollable);
              extents.add(scrollable.position.extentBefore);
            },
          ),
        ),
      );
      await _pumpFrames(tester);
      expect(requested, isEmpty, reason: 'the reader opens at the newest row');

      final position = _scrollPosition(tester);
      final beforePaging = position.maxScrollExtent;
      position.jumpTo(0);
      // Generous: one page per frame is the fastest this can page, so this is
      // room for the whole history and then some.
      for (var frame = 0; frame < pages * 3; frame += 1) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(
        requested,
        hasLength(lessThanOrEqualTo(2)),
        reason:
            'one trip to the top pages back, it does not drain the session: '
            'asked for ${requested.length} of $pages pages at $extents',
      );
      // The page landed on the row the reader was holding, because a page
      // boundary lands mid-answer and an answer is one row. There is no
      // viewport of new rows above them to measure, so what a page adds is
      // measured as what there now is to read.
      expect(
        position.maxScrollExtent,
        greaterThan(beforePaging + position.viewportDimension),
        reason: 'the page that arrived is history the reader can now read',
      );

      // And they are not stranded at the edge: moving away and back asks for
      // the page after it, which is what stops the hold above being a wall.
      final answered = requested.length;
      position.jumpTo(position.maxScrollExtent);
      await _pumpFrames(tester);
      position.jumpTo(0);
      for (var frame = 0; frame < 8; frame += 1) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(
        requested.length,
        greaterThan(answered),
        reason: 'a reader who comes back to the edge can keep pulling history',
      );
    },
  );

  testWidgets(
    'a page that keeps failing is not retried without the reader',
    tags: const <String>[
      'feature_test__conversation_history_pagination__widget',
    ],
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var requests = 0;
      await tester.pumpWidget(
        _app(
          _FailingPagingHarness(
            items: _messages(40, 120),
            onRequest: () => requests += 1,
          ),
        ),
      );
      await _pumpFrames(tester);
      _scrollPosition(tester).jumpTo(0);
      // The reader asks once and then does nothing at all.
      for (var frame = 0; frame < 20; frame += 1) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(
        requests,
        lessThanOrEqualTo(1),
        reason:
            'a failure that reports itself waits to be asked again: '
            'made $requests attempts while the reader sat still',
      );
    },
  );
}

/// A session stored the way a streamed one is: one row per delta.
///
/// Each turn spans more than one page on purpose. The daemon caps a window at
/// a span it will not exceed for alignment, so a long turn is split and the
/// oldest loaded row is half of an answer — the ordinary case, not the corner.
List<TimelineEventDto> _streamedSession({
  required int turns,
  required int deltasPerTurn,
}) {
  final events = <TimelineEventDto>[];
  TimelineEventDto append(
    String type,
    String turnId,
    String text, {
    String? blockId,
  }) {
    final sequence = events.length + 1;
    return TimelineEventDto(
      sessionId: _sessionId,
      sequence: sequence,
      turnId: turnId,
      type: type,
      data: <String, dynamic>{
        'text': text,
        'blockId': ?blockId,
        if (type == 'user.message')
          'attachments': const <Map<String, dynamic>>[],
      },
      createdAt: _createdAt.add(Duration(seconds: sequence)),
    );
  }

  for (var turn = 1; turn <= turns; turn += 1) {
    events.add(append('user.message', 'turn-$turn', 'question $turn'));
    for (var delta = 0; delta < deltasPerTurn; delta += 1) {
      events.add(
        append(
          'assistant.delta',
          'turn-$turn',
          'answer $turn part $delta ',
          blockId: 'block-$turn',
        ),
      );
    }
  }
  return events;
}

Widget _app(Widget child) => ProviderScope(
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
    home: Scaffold(body: child),
  ),
);

/// Mirrors what the conversation controller does with a page of older events.
class _PagingHarness extends StatefulWidget {
  const _PagingHarness({required this.history, required this.onRequest});

  final List<TimelineEventDto> history;
  final ValueChanged<int> onRequest;

  @override
  State<_PagingHarness> createState() => _PagingHarnessState();
}

class _PagingHarnessState extends State<_PagingHarness> {
  late List<TimelineEventDto> _window = _page(widget.history);

  static List<TimelineEventDto> _page(List<TimelineEventDto> events) => events
      .sublist(math.max(0, events.length - timelineHistoryPageSize))
      .toList(growable: false);

  void _loadOlder() {
    final cursor = _window.first.sequence;
    widget.onRequest(cursor);
    // The view reports an edge from inside a scroll notification, so the
    // controller's write lands a microtask later, as it does in the app.
    scheduleMicrotask(() {
      if (!mounted) return;
      final older = widget.history
          .where((event) => event.sequence < cursor)
          .toList(growable: false);
      if (older.isEmpty) return;
      setState(() {
        _window = <TimelineEventDto>[..._page(older), ..._window];
      });
    });
  }

  @override
  Widget build(BuildContext context) => ChatTimelineView(
    sessionKey: 'conversation:$_hostId:$_sessionId',
    items: projectChatTimeline(_window),
    busy: false,
    hostId: _hostId,
    olderPageKey: _window.first.sequence > 1
        ? 'older:${_window.first.sequence}:0'
        : null,
    onLoadOlder: _loadOlder,
  );
}

/// Mirrors the controller's failed-page state, retry identity included.
class _FailingPagingHarness extends StatefulWidget {
  const _FailingPagingHarness({required this.items, required this.onRequest});

  final List<ChatItem> items;
  final VoidCallback onRequest;

  @override
  State<_FailingPagingHarness> createState() => _FailingPagingHarnessState();
}

class _FailingPagingHarnessState extends State<_FailingPagingHarness> {
  bool _loading = false;
  bool _failed = false;

  void _loadOlder() {
    widget.onRequest();
    setState(() {
      _loading = true;
      _failed = false;
    });
    scheduleMicrotask(() {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) => ChatTimelineView(
    sessionKey: 'conversation:$_hostId:$_sessionId',
    items: widget.items,
    busy: false,
    hostId: _hostId,
    olderPageKey: 'older:40',
    loadingOlder: _loading,
    olderFailed: _failed,
    onLoadOlder: _loadOlder,
  );
}
