import 'dart:ui' show Tristate;

import 'package:app/src/app/platform/external_url_opener.dart';
import 'package:app/src/features/conversation/application/chat_timeline_model.dart';
import 'package:app/src/features/conversation/presentation/chat_code_block.dart';
import 'package:app/src/features/conversation/presentation/chat_markdown.dart';
import 'package:app/src/features/conversation/presentation/chat_message_views.dart';
import 'package:app/src/features/conversation/presentation/chat_reasoning_card.dart';
import 'package:app/src/features/conversation/presentation/chat_timeline_view.dart';
import 'package:app/src/features/conversation/presentation/chat_tool_card.dart';
import 'package:app/src/features/plugins/presentation/plugin_ui_document_view.dart';
import 'package:app/src/shared/presentation/tinest_icons.dart';
import 'package:app/src/shared/presentation/tinest_ui_density.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/localization.dart';

void main() {
  final now = DateTime.utc(2026, 8, 3);
  var sequence = 0;

  TimelineEventDto event(String type, Map<String, dynamic> data) {
    final normalized = <String, dynamic>{...data};
    if (type.startsWith('tool.') && !normalized.containsKey('presentation')) {
      normalized['presentation'] = _testToolPresentation(
        normalized['name'] as String? ?? '',
      );
    }
    return TimelineEventDto(
      sessionId: 'session',
      sequence: sequence += 1,
      turnId: 'turn-1',
      type: type,
      data: normalized,
      createdAt: now,
    );
  }

  setUp(() => sequence = 0);

  Future<void> pump(
    WidgetTester tester,
    List<TimelineEventDto> events, {
    bool busy = false,
    _RecordingUrlOpener? opener,
    TextScaler textScaler = TextScaler.noScaling,
    bool disableAnimations = false,
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        externalUrlOpenerProvider.overrideWithValue(
          opener ?? _RecordingUrlOpener(),
        ),
      ],
      child: MaterialApp(
        theme: testLightTheme,
        darkTheme: testDarkTheme,
        locale: testLocale,
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: textScaler,
            disableAnimations: disableAnimations,
          ),
          child: TinestUiDensity(child: child!),
        ),
        home: Scaffold(
          body: ChatTimelineView(
            sessionKey: 'chat-view-test',
            items: projectChatTimeline(events),
            busy: busy,
          ),
        ),
      ),
    ),
  );

  testWidgets(
    'tool calls collapse to a CLI line instead of raw JSON',
    (tester) async {
      await pump(tester, <TimelineEventDto>[
        event('tool.requested', <String, dynamic>{
          'callId': 'call-1',
          'name': 'read_file',
          'arguments': <String, dynamic>{'path': 'lib/main.dart'},
        }),
        event('tool.completed', <String, dynamic>{
          'callId': 'call-1',
          'name': 'read_file',
          'output': 'a\nb\nc',
          'isError': false,
        }),
        event('turn.completed', <String, dynamic>{'toolRounds': 1}),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('파일 읽기'), findsOneWidget);
      expect(find.text('lib/main.dart'), findsNothing);
      expect(find.text('3줄 읽음'), findsNothing);
      expect(find.textContaining('{'), findsNothing);
      expect(find.textContaining('isError'), findsNothing);
    },
    tags: const <String>['feature_test__turn_execution__widget'],
  );

  testWidgets(
    'an expanded failed collaboration tool shows its structured error',
    (tester) async {
      await pump(tester, <TimelineEventDto>[
        event('tool.requested', <String, dynamic>{
          'callId': 'spawn-call',
          'name': 'spawn_agent',
          'arguments': <String, dynamic>{
            'task_name': 'forbidden_task',
            'message': 'This spawn must not start.',
            'agent_type': 'not-allowed',
          },
        }),
        event('tool.completed', <String, dynamic>{
          'callId': 'spawn-call',
          'name': 'spawn_agent',
          'output': '{"error":"Agent type is not allowed: not-allowed"}',
          'isError': true,
        }),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('실패'), findsOneWidget);
      expect(
        find.textContaining('Agent type is not allowed: not-allowed'),
        findsNothing,
      );
      await tester.tap(find.byType(ChatToolCard));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Agent type is not allowed: not-allowed'),
        findsWidgets,
      );
    },
    tags: const <String>['feature_test__agent_collaboration__widget'],
  );

  testWidgets(
    'a missing command UI snapshot falls back to a raw disclosure',
    (tester) async {
      final clipboard = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboard.add(
                (call.arguments as Map<Object?, Object?>)['text']! as String,
              );
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await pump(tester, <TimelineEventDto>[
        event('tool.requested', <String, dynamic>{
          'callId': 'call-1',
          'name': 'exec_command',
          'arguments': <String, dynamic>{'command': 'flutter test'},
        }),
        event('tool.completed', <String, dynamic>{
          'callId': 'call-1',
          'name': 'exec_command',
          'output': r'{"exitCode":0,"output":"All tests passed!\ndone"}',
          'isError': false,
        }),
        event('turn.completed', <String, dynamic>{'toolRounds': 1}),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('명령 실행'), findsOneWidget);
      expect(find.text('flutter test'), findsNothing);
      expect(find.text('종료 코드 0 · 2줄'), findsNothing);
      expect(find.textContaining('exitCode'), findsNothing);

      await tester.tap(find.text('명령 실행'));
      await tester.pumpAndSettle();
      expect(find.textContaining('All tests passed!'), findsOneWidget);
      expect(find.textContaining('flutter test'), findsWidgets);
      expect(find.textContaining('exitCode'), findsOneWidget);

      final copyAction = findAccessibleAction('복사').last;
      await tester.ensureVisible(copyAction);
      await tester.pumpAndSettle();
      await tester.tap(copyAction);
      await tester.pumpAndSettle();
      expect(
        clipboard.single,
        contains(r'"output": "All tests passed!\ndone"'),
      );

      await tester.tap(find.text('명령 실행'));
      await tester.pumpAndSettle();
      expect(find.textContaining('All tests passed!'), findsNothing);
    },
    tags: const <String>['feature_test__turn_execution__widget'],
  );

  testWidgets(
    'a missing patch UI snapshot falls back to immutable raw data',
    (tester) async {
      await pump(tester, <TimelineEventDto>[
        event('tool.requested', <String, dynamic>{
          'callId': 'call-1',
          'name': 'apply_patch',
          'arguments': <String, dynamic>{
            'patch':
                '--- a/lib/main.dart\n'
                '+++ b/lib/main.dart\n'
                '@@ -1,1 +1,2 @@\n'
                '-old line\n'
                '+new line\n'
                '+extra line\n',
          },
        }),
        event('tool.completed', <String, dynamic>{
          'callId': 'call-1',
          'name': 'apply_patch',
          'output': '{"changedFiles":1}',
          'isError': false,
        }),
        event('turn.completed', <String, dynamic>{'toolRounds': 1}),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('파일 편집'), findsOneWidget);
      expect(find.text('lib/main.dart'), findsNothing);
      expect(find.text('+2 -1 · 1개 파일'), findsNothing);

      await tester.tap(find.text('파일 편집'));
      await tester.pumpAndSettle();
      expect(find.textContaining('+new line'), findsWidgets);
      expect(find.textContaining('+extra line'), findsWidgets);
      expect(find.textContaining('-old line'), findsWidgets);
      expect(find.textContaining('changedFiles'), findsOneWidget);
    },
    tags: const <String>['feature_test__turn_execution__widget'],
  );

  testWidgets(
    'running turns show progress and the empty state explains itself',
    (tester) async {
      await pump(
        tester,
        <TimelineEventDto>[
          event('user.message', <String, dynamic>{'text': 'Run it'}),
          event('tool.requested', <String, dynamic>{
            'callId': 'call-1',
            'name': 'exec_command',
            'arguments': <String, dynamic>{'command': 'sleep 5'},
          }),
        ],
        busy: true,
      );
      await tester.pump();

      final tool = find.byType(ChatToolCard);
      expect(find.text('명령 실행 Execute command(sleep 5)'), findsOneWidget);
      expect(
        find.descendant(of: tool, matching: find.byType(ShaderMask)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tool, matching: find.byType(TRSpinner)),
        findsNothing,
      );
      expect(
        find.descendant(of: tool, matching: find.text('실행 중')),
        findsNothing,
      );
      final runningRow = find.byKey(const ValueKey<String>('chat-running'));
      expect(
        find.descendant(of: runningRow, matching: find.byType(ShaderMask)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: runningRow, matching: find.byType(TRSpinner)),
        findsNothing,
      );
      final runningText = find.descendant(
        of: find.byKey(const ValueKey<String>('chat-running')),
        matching: find.text('실행 중'),
      );
      expect(runningText, findsOneWidget);
      expect(find.byType(TRChatUserBubble), findsOneWidget);

      await pump(tester, const <TimelineEventDto>[]);
      await tester.pumpAndSettle();
      expect(find.text('코딩 요청을 입력하세요.'), findsOneWidget);
    },
    tags: const <String>['feature_test__turn_execution__widget'],
  );

  testWidgets(
    'running shimmer becomes static when reduced motion is enabled',
    (tester) async {
      await pump(
        tester,
        <TimelineEventDto>[
          event('tool.requested', <String, dynamic>{
            'callId': 'call-1',
            'name': 'exec_command',
            'arguments': <String, dynamic>{'command': 'sleep 5'},
          }),
        ],
        busy: true,
        disableAnimations: true,
      );
      await tester.pump();

      expect(find.text('명령 실행 Execute command(sleep 5)'), findsOneWidget);
      expect(find.text('실행 중'), findsOneWidget);
      expect(find.byType(ShaderMask), findsNothing);
      expect(find.byType(TRSpinner), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
    },
    tags: const <String>['feature_test__turn_execution__widget'],
  );

  testWidgets(
    'reasoning replaces generic progress and streams inside its disclosure',
    tags: const <String>[
      'feature_test__turn_execution__widget',
      'ui_state__conversation_timeline__streaming__widget',
    ],
    (tester) async {
      final events = <TimelineEventDto>[
        event('assistant.reasoning.started', const <String, dynamic>{}),
        event('assistant.reasoning.delta', <String, dynamic>{
          'text': '**파일을 확인하고 있습니다.**',
        }),
      ];
      await pump(tester, events, busy: true);
      await tester.pump();

      expect(find.byType(ChatReasoningCard), findsOneWidget);
      // The trailing row itself stays for the whole turn — taking it out and
      // putting it back at every reasoning boundary is what made the tail
      // twitch. What must not appear twice is the indicator.
      expect(
        find.byKey(const ValueKey<String>('chat-running')),
        findsOneWidget,
      );
      expect(find.byType(ChatRunningIndicator), findsNothing);
      expect(find.text('사고 중'), findsOneWidget);
      expect(find.textContaining('파일을 확인하고 있습니다.'), findsNothing);

      await tester.tap(find.byType(ChatReasoningCard));
      await tester.pump();
      expect(find.text('파일을 확인하고 있습니다.'), findsOneWidget);

      events.add(
        event('assistant.reasoning.delta', <String, dynamic>{
          'text': '\n\n결과를 검증합니다.',
        }),
      );
      await pump(tester, events, busy: true);
      await tester.pump();
      expect(find.text('결과를 검증합니다.'), findsOneWidget);
    },
  );

  testWidgets(
    'completed reasoning stays collapsed and can be opened from the keyboard',
    tags: const <String>['feature_test__turn_execution__widget'],
    (tester) async {
      await pump(tester, <TimelineEventDto>[
        event('assistant.reasoning.started', const <String, dynamic>{}),
        event('assistant.reasoning.delta', <String, dynamic>{
          'text': '완료된 사고 기록',
        }),
        event('assistant.reasoning.completed', const <String, dynamic>{}),
        event('turn.completed', const <String, dynamic>{}),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('생각함'), findsOneWidget);
      expect(find.text('완료된 사고 기록'), findsNothing);
      final collapsedSemantics = tester.getSemantics(
        find.byType(TRChatToolDisclosure),
      );
      expect(collapsedSemantics.flagsCollection.isButton, isTrue);
      expect(
        collapsedSemantics.flagsCollection.isExpanded,
        Tristate.isFalse,
      );
      await tester.tap(find.byType(ChatReasoningCard));
      await tester.pumpAndSettle();
      expect(find.text('완료된 사고 기록'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.byType(TRChatToolDisclosure))
            .flagsCollection
            .isExpanded,
        Tristate.isTrue,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.text('완료된 사고 기록'), findsNothing);
    },
  );

  testWidgets(
    'running state participates in the timeline layout',
    (tester) async {
      final events = <TimelineEventDto>[
        event('user.message', <String, dynamic>{'text': 'Keep me still'}),
      ];
      await pump(tester, events);
      await tester.pumpAndSettle();
      final message = find.text('Keep me still', findRichText: true);
      final before = tester.getRect(message);

      await pump(tester, events, busy: true);
      await tester.pump();

      expect(tester.getRect(message).bottom, lessThan(before.bottom));
      expect(find.text('실행 중'), findsWidgets);
    },
    tags: const <String>['feature_test__turn_execution__widget'],
  );

  testWidgets(
    'user messages and structured answers align to the trailing side',
    (tester) async {
      await pump(tester, <TimelineEventDto>[
        event('user.message', <String, dynamic>{
          'text': 'Right aligned prompt',
        }),
        event('tool.requested', <String, dynamic>{
          'callId': 'call-ask',
          'name': 'request_user_input',
          'presentation': <String, dynamic>{'timeline': 'question'},
          'arguments': <String, dynamic>{
            'questions': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'store',
                'header': 'Storage',
                'question': 'Which store?',
                'options': <Map<String, dynamic>>[],
              },
            ],
          },
        }),
        event('tool.completed', <String, dynamic>{
          'callId': 'call-ask',
          'name': 'request_user_input',
          'presentation': <String, dynamic>{'timeline': 'question'},
          'output':
              '[{"questionId":"store","answer":"SQLite","isFreeForm":false}]',
        }),
      ]);
      await tester.pumpAndSettle();

      final timeline = tester.getRect(find.byType(ChatTimelineView));
      expect(
        tester.getRect(find.text('Right aligned prompt')).center.dx,
        greaterThan(timeline.center.dx),
      );
      expect(
        tester.getRect(find.text('SQLite')).center.dx,
        greaterThan(timeline.center.dx),
      );
    },
    tags: const <String>[
      'feature_test__turn_execution__widget',
      'feature_test__turn_question__widget',
    ],
  );

  testWidgets(
    'running is a chronological row that cannot overlap the latest message',
    (tester) async {
      await pump(
        tester,
        <TimelineEventDto>[
          event('user.message', <String, dynamic>{'text': 'Last message'}),
        ],
        busy: true,
      );
      await tester.pump();

      final message = tester.getRect(find.text('Last message'));
      final running = tester.getRect(find.text('실행 중').last);
      expect(message.overlaps(running), isFalse);
      expect(running.top, greaterThanOrEqualTo(message.bottom));
    },
    tags: const <String>['feature_test__turn_execution__widget'],
  );

  testWidgets(
    'collapsed unknown tools hide identifiers and raw details until expanded',
    (tester) async {
      await pump(tester, <TimelineEventDto>[
        event('tool.requested', <String, dynamic>{
          'callId': 'call-private',
          'name': 'unknown_private_tool',
          'arguments': <String, dynamic>{
            'uid': '0f7607ef-743f-4b4c-a8ee-3b5354d762aa',
            'path': '/workspace/private.dart',
            'uri': 'file:///workspace/private.dart',
            'command': 'print-secret --verbose',
          },
        }),
        event('tool.completed', <String, dynamic>{
          'callId': 'call-private',
          'name': 'unknown_private_tool',
          'output': 'raw private result',
          'isError': true,
        }),
      ]);
      await tester.pumpAndSettle();

      for (final sensitive in <String>[
        '0f7607ef-743f-4b4c-a8ee-3b5354d762aa',
        '/workspace/private.dart',
        'file:///workspace/private.dart',
        'print-secret --verbose',
        'raw private result',
      ]) {
        expect(find.textContaining(sensitive), findsNothing);
      }

      await tester.tap(find.byType(ChatToolCard));
      await tester.pumpAndSettle();

      for (final sensitive in <String>[
        '0f7607ef-743f-4b4c-a8ee-3b5354d762aa',
        '/workspace/private.dart',
        'file:///workspace/private.dart',
        'print-secret --verbose',
        'raw private result',
      ]) {
        expect(find.textContaining(sensitive), findsWidgets);
      }
    },
    tags: const <String>['feature_test__turn_execution__widget'],
  );

  testWidgets(
    'assistant and tool rows share the same leading rail and text baseline',
    (tester) async {
      await pump(tester, <TimelineEventDto>[
        event('assistant.delta', <String, dynamic>{'text': '이미지를 보냈어요! 🖼️'}),
        event('tool.requested', <String, dynamic>{
          'callId': 'call-read',
          'name': 'read_file',
          'arguments': <String, dynamic>{'path': 'lib/main.dart'},
        }),
      ], textScaler: const TextScaler.linear(2));
      await tester.pump();

      final assistant = find.byType(ChatAssistantMessageView);
      final tool = find.byType(ChatToolCard);
      final assistantIcon = find
          .descendant(of: assistant, matching: find.byType(Icon))
          .first;
      final toolIcon = find
          .descendant(of: tool, matching: find.byType(Icon))
          .first;
      final assistantText = find.textContaining(
        '이미지를 보냈어요! 🖼️',
        findRichText: true,
      );
      final toolText = find.text('파일 읽기 Read file(lib/main.dart)');

      expect(
        tester.getTopLeft(assistantIcon).dx,
        tester.getTopLeft(toolIcon).dx,
      );
      expect(
        tester.getTopLeft(assistantText).dx,
        tester.getTopLeft(toolText).dx,
      );
      expect(
        tester.getRect(assistantIcon).center.dy,
        closeTo(tester.getRect(assistantText).center.dy, 0.5),
      );
    },
    tags: const <String>['feature_test__turn_execution__widget'],
  );

  testWidgets(
    'a persisted plugin timeline snapshot renders without plugin source',
    (tester) async {
      await pump(tester, <TimelineEventDto>[
        event('plugin.ui', <String, dynamic>{
          'document': <String, dynamic>{
            'id': 'historical-plan',
            'pluginId': 'tinest.plan',
            'revisionHash': 'removed-revision',
            'slot': 'timeline',
            'root': <String, dynamic>{
              'type': 'section',
              'title': '계획',
              'children': <Map<String, dynamic>>[
                <String, dynamic>{
                  'type': 'text',
                  'text': '첫 줄에 맞춰요',
                },
              ],
            },
          },
        }),
      ]);
      await tester.pump();

      expect(find.byType(PluginUiDocumentView), findsOneWidget);
      expect(find.text('계획'), findsOneWidget);
      expect(find.text('첫 줄에 맞춰요'), findsOneWidget);
    },
    tags: const <String>['feature_test__turn_execution__widget'],
  );

  testWidgets(
    'built-in execution search and image tools render pinned Lua snapshots',
    (tester) async {
      Map<String, dynamic> document({
        required String id,
        required String pluginId,
        required String title,
        required String text,
      }) => <String, dynamic>{
        'id': id,
        'pluginId': pluginId,
        'revisionHash': '$pluginId-revision',
        'slot': 'timeline',
        'root': <String, dynamic>{
          'type': 'section',
          'title': title,
          'children': <Map<String, dynamic>>[
            <String, dynamic>{'type': 'text', 'text': text},
          ],
        },
      };

      await pump(tester, <TimelineEventDto>[
        event('tool.completed', <String, dynamic>{
          'callId': 'exec-call',
          'name': 'exec_command',
          'uiDocument': document(
            id: 'exec-snapshot',
            pluginId: 'tinest.terminal',
            title: 'Command completed',
            text: 'exit 0',
          ),
        }),
        event('tool.completed', <String, dynamic>{
          'callId': 'search-call',
          'name': 'search_text',
          'uiDocument': document(
            id: 'search-snapshot',
            pluginId: 'tinest.files',
            title: 'Search completed',
            text: 'lib/main.dart:1',
          ),
        }),
        event('tool.completed', <String, dynamic>{
          'callId': 'image-call',
          'name': 'view_image',
          'uiDocument': document(
            id: 'image-snapshot',
            pluginId: 'tinest.files',
            title: 'Image loaded',
            text: 'shot.png',
          ),
        }),
      ]);
      await tester.pump();

      expect(find.byType(PluginUiDocumentView), findsNWidgets(3));
      expect(find.byType(ChatToolCard), findsNothing);
      expect(find.text('Command completed'), findsOneWidget);
      expect(find.text('Search completed'), findsOneWidget);
      expect(find.text('Image loaded'), findsOneWidget);
    },
    tags: const <String>[
      'feature_test__tool_exec_session__widget',
      'feature_test__tool_search__widget',
      'feature_test__tool_image_context__widget',
    ],
  );

  testWidgets(
    'assistant links open only browser-safe schemes',
    (tester) async {
      final opener = _RecordingUrlOpener();
      await pump(
        tester,
        <TimelineEventDto>[
          event('assistant.delta', <String, dynamic>{
            'text':
                'See [docs](https://example.com) and '
                '[bad](javascript:alert(1)).',
          }),
          event('turn.completed', <String, dynamic>{'toolRounds': 0}),
        ],
        opener: opener,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('docs', findRichText: true), findsWidgets);
      await openChatLink(opener, 'https://example.com');
      await openChatLink(opener, 'mailto:dev@example.com');
      await openChatLink(opener, 'javascript:alert(1)');
      await openChatLink(opener, 'file:///etc/passwd');
      await openChatLink(opener, '');
      await openChatLink(opener, null);
      expect(opener.opened, <Uri>[
        Uri.parse('https://example.com'),
        Uri.parse('mailto:dev@example.com'),
      ]);
    },
    tags: const <String>['feature_test__turn_execution__widget'],
  );

  testWidgets(
    'expanded cards keep their state when a new event arrives',
    (tester) async {
      final first = <TimelineEventDto>[
        event('tool.requested', <String, dynamic>{
          'callId': 'call-1',
          'name': 'read_file',
          'arguments': <String, dynamic>{'path': 'a.dart'},
        }),
        event('tool.completed', <String, dynamic>{
          'callId': 'call-1',
          'name': 'read_file',
          'output': 'first file body',
          'isError': false,
        }),
      ];
      await pump(tester, first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ChatToolCard));
      await tester.pumpAndSettle();
      expect(find.textContaining('first file body'), findsOneWidget);

      await pump(tester, <TimelineEventDto>[
        ...first,
        event('tool.requested', <String, dynamic>{
          'callId': 'call-2',
          'name': 'read_file',
          'arguments': <String, dynamic>{'path': 'b.dart'},
        }),
        event('tool.completed', <String, dynamic>{
          'callId': 'call-2',
          'name': 'read_file',
          'output': 'second file body',
          'isError': false,
        }),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('파일 읽기'), findsNWidgets(2));
      expect(find.textContaining('first file body'), findsOneWidget);
      expect(find.textContaining('second file body'), findsNothing);
    },
    tags: const <String>['feature_test__turn_execution__widget'],
  );

  testWidgets(
    'an answered question renders as prose, marking typed answers',
    (tester) async {
      await pump(tester, <TimelineEventDto>[
        event('tool.requested', <String, dynamic>{
          'callId': 'call-ask',
          'name': 'request_user_input',
          'presentation': <String, dynamic>{'timeline': 'question'},
          'arguments': <String, dynamic>{
            'questions': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'store',
                'header': 'Storage',
                'question': 'Which store should the cache use?',
                'options': <Map<String, dynamic>>[],
              },
              <String, dynamic>{
                'id': 'ttl',
                'header': 'TTL',
                'question': 'How long should entries live?',
                'options': <Map<String, dynamic>>[],
              },
            ],
          },
        }),
        event('tool.completed', <String, dynamic>{
          'callId': 'call-ask',
          'name': 'request_user_input',
          'presentation': <String, dynamic>{'timeline': 'question'},
          'output':
              '[{"questionId":"store","answer":"SQLite","isFreeForm":false},'
              '{"questionId":"ttl","answer":"A week","isFreeForm":true}]',
        }),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('Which store should the cache use?'), findsOneWidget);
      expect(find.text('SQLite'), findsOneWidget);
      // A typed answer is marked so it is not mistaken for an offered option.
      expect(find.text('A week (직접 입력)'), findsOneWidget);
      // No JSON tool row duplicates it.
      expect(find.textContaining('questionId'), findsNothing);
    },
    tags: const <String>['feature_test__turn_question__widget'],
  );

  testWidgets(
    'a running sleep counts down and settles when it ends',
    (tester) async {
      // A sleep is projected from its request, which carries createdAt, so
      // the countdown is recomputed rather than counted — correct on replay.
      final started = event('tool.requested', <String, dynamic>{
        'callId': 'call-sleep',
        'name': 'clock__sleep',
        'presentation': <String, dynamic>{'timeline': 'sleep'},
        'arguments': <String, dynamic>{
          'duration_ms': 4000,
          'reason': 'waiting for CI',
        },
      });
      await pump(tester, <TimelineEventDto>[started]);
      await tester.pump();

      expect(find.byKey(const ValueKey<String>('chat-sleep-card')), findsOne);
      expect(find.text('waiting for CI'), findsOneWidget);
      // No generic tool row duplicates the card.
      expect(find.text('clock__sleep'), findsNothing);

      // The card animates, so the tree never settles while it runs.
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester
            .widget<TRText>(
              find.byKey(const ValueKey<String>('chat-sleep-status')),
            )
            .data,
        contains('초'),
      );

      await pump(tester, <TimelineEventDto>[
        started,
        event('tool.completed', <String, dynamic>{
          'callId': 'call-sleep',
          'name': 'clock__sleep',
          'presentation': <String, dynamic>{
            'glyph': 'clock',
            'label': 'Sleep',
            'summary_argument': 'duration_ms',
            'timeline': 'sleep',
          },
          'output': '{"sleptMs":4000,"outcome":"elapsed"}',
        }),
      ]);
      // Finished, so the ticker stops and the tree can settle.
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TRText>(
              find.byKey(const ValueKey<String>('chat-sleep-status')),
            )
            .data,
        '4초 대기함',
      );
    },
    tags: const <String>['feature_test__tool_clock__widget'],
  );

  testWidgets(
    'a sleep without a usable duration stays an ordinary tool row',
    (tester) async {
      await pump(tester, <TimelineEventDto>[
        event('tool.requested', <String, dynamic>{
          'callId': 'call-sleep',
          'name': 'clock__sleep',
          'presentation': <String, dynamic>{
            'glyph': 'clock',
            'label': 'Sleep',
            'summary_argument': 'duration_ms',
            'timeline': 'sleep',
          },
          'arguments': <String, dynamic>{'duration_ms': 'soon'},
        }),
      ]);
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('chat-sleep-card')),
        findsNothing,
      );
      // It falls back to the ordinary tool row so the mistake stays visible.
      final disclosure = tester.widget<TRChatToolDisclosure>(
        find.byType(TRChatToolDisclosure),
      );
      expect(disclosure.label, '대기');
      expect(disclosure.secondaryLabel, 'Sleep(soon)');
    },
    tags: const <String>['feature_test__tool_clock__widget'],
  );

  testWidgets(
    'a rejected context reset stays visible as a tool row',
    (tester) async {
      await pump(tester, <TimelineEventDto>[
        event('tool.requested', <String, dynamic>{
          'callId': 'call-reset',
          'name': 'new_context',
          'arguments': <String, dynamic>{},
        }),
        event('tool.denied', <String, dynamic>{
          'callId': 'call-reset',
          'name': 'new_context',
          'error': 'Denied.',
        }),
      ]);
      await tester.pumpAndSettle();

      expect(find.byType(TRChatToolDisclosure), findsOneWidget);
      expect(find.text('거부됨'), findsOneWidget);
    },
    tags: const <String>['feature_test__tool_context_budget__widget'],
  );

  testWidgets(
    'withheld tools are announced so the user knows they exist',
    (tester) async {
      await pump(tester, <TimelineEventDto>[
        event('tools.deferred', <String, dynamic>{
          'count': 12,
          'surfaced': 0,
        }),
      ]);
      await tester.pumpAndSettle();

      final line = tester.widget<TRText>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('chat-deferred-tools')),
          matching: find.byType(TRText),
        ),
      );
      expect(line.data, contains('12'));
    },
    tags: const <String>['feature_test__tool_search_deferred__widget'],
  );

  testWidgets(
    'nothing withheld shows no notice',
    (tester) async {
      await pump(tester, <TimelineEventDto>[
        event('tools.deferred', <String, dynamic>{'count': 0}),
      ]);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('chat-deferred-tools')),
        findsNothing,
      );
    },
    tags: const <String>['feature_test__tool_search_deferred__widget'],
  );

  testWidgets(
    'token usage reads as labelled counters, not raw provider keys',
    (tester) async {
      await pump(tester, <TimelineEventDto>[
        event('model.usage', <String, dynamic>{
          'inputTokens': 1200,
          'cachedInputTokens': 800,
          'outputTokens': 340,
          'reasoningTokens': 120,
          'totalTokens': 1540,
        }),
      ]);
      await tester.pumpAndSettle();

      final line = tester.widget<TRText>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('chat-usage-line')),
          matching: find.byType(TRText),
        ),
      );
      // Cached and reasoning are subsets, so they read as qualifiers.
      expect(line.data, contains('1200'));
      expect(line.data, contains('800'));
      expect(line.data, contains('340'));
      expect(line.data, contains('120'));
      expect(line.data, contains('1540'));
      expect(line.data, isNot(contains('inputTokens')));
    },
    tags: const <String>['feature_test__tool_context_budget__widget'],
  );

  testWidgets(
    'a measured response reports its output rate on the usage line',
    (tester) async {
      await pump(tester, <TimelineEventDto>[
        event('model.usage', <String, dynamic>{
          'inputTokens': 1200,
          'outputTokens': 340,
          'totalTokens': 1540,
          'generationMs': 5450,
        }),
      ]);
      await tester.pumpAndSettle();

      final line = tester.widget<TRText>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('chat-usage-line')),
          matching: find.byType(TRText),
        ),
      );
      expect(line.data, contains('62.4 tok/s'));
    },
    tags: const <String>['feature_test__tool_context_budget__widget'],
  );

  testWidgets(
    'a usage event without a measured span reports counters only',
    (tester) async {
      await pump(tester, <TimelineEventDto>[
        event('model.usage', <String, dynamic>{
          'inputTokens': 1200,
          'outputTokens': 340,
          'totalTokens': 1540,
        }),
      ]);
      await tester.pumpAndSettle();

      final line = tester.widget<TRText>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('chat-usage-line')),
          matching: find.byType(TRText),
        ),
      );
      expect(line.data, contains('340'));
      expect(line.data, isNot(contains('tok/s')));
    },
    tags: const <String>['feature_test__tool_context_budget__widget'],
  );

  testWidgets(
    'a usage event with nothing to report renders nothing',
    (tester) async {
      await pump(tester, <TimelineEventDto>[
        event('model.usage', const <String, dynamic>{}),
      ]);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('chat-usage-line')),
        findsNothing,
      );
    },
    tags: const <String>['feature_test__tool_context_budget__widget'],
  );

  testWidgets(
    'a mixed-height timeline stays forward ordered and lazily builds history',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final events = <TimelineEventDto>[
        for (var index = 0; index < 80; index += 1)
          event('user.message', <String, dynamic>{
            'text': index < 65
                ? 'long $index\nline 2\nline 3\nline 4\nline 5\nline 6'
                : 'short $index',
          }),
      ];

      await pump(tester, events);
      await tester.pumpAndSettle();

      final scrollable = find
          .descendant(
            of: find.byType(ChatTimelineView),
            matching: find.byType(Scrollable),
          )
          .first;
      final viewportHeight = tester.getSize(scrollable).height;
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.axisDirection, AxisDirection.down);
      expect(position.extentAfter, closeTo(0, 0.01));
      expect(find.text('short 79'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('short 78')).dy,
        lessThan(tester.getTopLeft(find.text('short 79')).dy),
      );
      expect(find.textContaining('long 0'), findsNothing);
      expect(
        find.byType(ChatUserLine).evaluate().length,
        lessThan(events.length),
      );

      position.jumpTo(
        (position.maxScrollExtent - viewportHeight).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('long 0'), findsNothing);
    },
    tags: const <String>[
      'feature_test__turn_execution__widget',
      'ui_state__conversation_timeline__history_anchored__widget',
    ],
  );

  testWidgets(
    'a settled response offers a copy action carrying its raw Markdown',
    (tester) async {
      tester.binding.platformDispatcher.platformBrightnessTestValue =
          Brightness.dark;
      addTearDown(
        tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
      );
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add(
              ((call.arguments as Map<Object?, Object?>)['text'] as String?) ??
                  '',
            );
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await pump(tester, <TimelineEventDto>[
        event('assistant.delta', <String, dynamic>{
          'text': '**bold** answer\n\nsecond paragraph',
        }),
        event('turn.completed', <String, dynamic>{'toolRounds': 0}),
      ]);
      await tester.pumpAndSettle();

      final copy = find.byKey(const ValueKey<String>('chat-response-copy'));
      expect(copy, findsOneWidget);
      final markdownContext = tester.element(find.byType(MarkdownBody));
      final markdownStyle = chatMarkdownStyleSheet(markdownContext);
      expect(markdownStyle.p?.fontSize, 18);
      expect(markdownStyle.code?.fontSize, 16);
      expect(
        markdownStyle.a?.color,
        markdownContext.tinyrackTheme.primaryForeground,
      );
      expect(
        tester.getSize(copy).height,
        TRControlMetrics.heightOf(TRUiSize.xl),
      );
      await tester.tap(copy);
      await tester.pumpAndSettle();

      expect(copied, <String>['**bold** answer\n\nsecond paragraph']);
    },
    tags: const <String>['feature_test__turn_execution__widget'],
  );

  testWidgets(
    'a streaming response hides the copy action and paints no caret',
    (tester) async {
      await pump(tester, <TimelineEventDto>[
        event('assistant.delta', <String, dynamic>{'text': 'half an answer'}),
      ], busy: true);
      // The busy row spins forever, so this view can only be pumped.
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('chat-response-copy')),
        findsNothing,
      );
      expect(find.textContaining('▌', findRichText: true), findsNothing);
    },
    tags: const <String>['feature_test__turn_execution__widget'],
  );

  testWidgets(
    'inline code leaves the shared selection highlight visible',
    (tester) async {
      await pump(tester, <TimelineEventDto>[
        event('assistant.delta', <String, dynamic>{
          'text': 'before `inline_code` after',
        }),
        event('turn.completed', <String, dynamic>{'toolRounds': 0}),
      ]);
      await tester.pumpAndSettle();

      final markdown = tester.element(find.byType(MarkdownBody));
      expect(chatMarkdownStyleSheet(markdown).code?.backgroundColor, isNull);
    },
    tags: const <String>['feature_test__turn_execution__widget'],
  );

  testWidgets(
    'one drag selects across every Markdown block of a response',
    (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add(
              ((call.arguments as Map<Object?, Object?>)['text'] as String?) ??
                  '',
            );
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await pump(tester, <TimelineEventDto>[
        event('assistant.delta', <String, dynamic>{
          'text': 'first paragraph with `inline_code`\n\nsecond paragraph',
        }),
        event('turn.completed', <String, dynamic>{'toolRounds': 0}),
      ]);
      await tester.pumpAndSettle();

      // A per-block SelectableText traps the drag inside one paragraph, so the
      // response must host exactly one selectable region and no islands.
      final response = find.byType(ChatAssistantMessageView);
      expect(
        find.descendant(of: response, matching: find.byType(SelectableText)),
        findsNothing,
      );

      final first = find.textContaining('first paragraph', findRichText: true);
      final second = find.textContaining(
        'second paragraph',
        findRichText: true,
      );
      final gesture = await tester.startGesture(
        tester.getTopLeft(first) + const Offset(1, 1),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.moveTo(tester.getBottomRight(second) - const Offset(1, 1));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(copied, hasLength(1));
      expect(copied.single, contains('first paragraph'));
      expect(copied.single, contains('inline_code'));
      expect(copied.single, contains('second paragraph'));
    },
    tags: const <String>['feature_test__turn_execution__widget'],
  );

  testWidgets(
    'mixed Markdown elements copy as one readable ordered document',
    (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add(
              ((call.arguments as Map<Object?, Object?>)['text'] as String?) ??
                  '',
            );
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      const markdown = '''
# Composite heading

Lead **bold** and [linked](https://example.com) with `inline_code`.

- First item
- Second `item_code`

> quoted text

```dart
final value = 42;
```

Closing paragraph.
''';
      await pump(tester, <TimelineEventDto>[
        event('assistant.delta', <String, dynamic>{'text': markdown}),
        event('turn.completed', <String, dynamic>{'toolRounds': 0}),
      ]);
      await tester.pumpAndSettle();

      final first = find.textContaining(
        'Composite heading',
        findRichText: true,
      );
      final last = find.textContaining(
        'Closing paragraph.',
        findRichText: true,
      );
      final gesture = await tester.startGesture(
        tester.getTopLeft(first) + const Offset(1, 1),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.moveTo(tester.getBottomRight(last) - const Offset(1, 1));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      final expected = <String>[
        'Composite heading',
        'Lead bold and linked with inline_code.',
        '• First item',
        '• Second item_code',
        'quoted text',
        'final value = 42;',
        'Closing paragraph.',
      ].join('\n');
      expect(copied, <String>[expected]);
    },
    tags: const <String>['feature_test__turn_execution__widget'],
  );

  testWidgets(
    'fenced code in a response scrolls, copies, and selects into the prose',
    (tester) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add(
              ((call.arguments as Map<Object?, Object?>)['text'] as String?) ??
                  '',
            );
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      const fenced = 'var aVeryLongIdentifier = someOtherLongExpression + 1;';
      await pump(tester, <TimelineEventDto>[
        event('assistant.delta', <String, dynamic>{
          'text': 'before prose\n\n```dart\n$fenced\n```\n\nafter prose',
        }),
        event('turn.completed', <String, dynamic>{'toolRounds': 0}),
      ]);
      await tester.pumpAndSettle();

      // The same surface tool payloads use, so a long line scrolls instead of
      // wrapping and the block carries its own copy action.
      final block = find.byType(ChatCodeBlock);
      expect(block, findsOneWidget);
      expect(
        find.descendant(of: block, matching: find.byType(TRCodeBlock)),
        findsOneWidget,
      );
      final copy = find.descendant(
        of: block,
        matching: find.byIcon(TinestIcons.copy),
      );
      expect(copy, findsOneWidget);
      expect(
        tester
            .getSize(
              find.descendant(of: block, matching: find.byType(TRIconButton)),
            )
            .height,
        TRControlMetrics.heightOf(TRUiSize.xl),
      );
      await tester.tap(copy);
      await tester.pumpAndSettle();
      expect(copied, <String>[fenced]);

      // And it is not its own selection island: one drag covers prose and code.
      copied.clear();
      final first = find.textContaining('before prose', findRichText: true);
      final last = find.textContaining('after prose', findRichText: true);
      final gesture = await tester.startGesture(
        tester.getTopLeft(first) + const Offset(1, 1),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.moveTo(tester.getBottomRight(last) - const Offset(1, 1));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(copied.single, contains('before prose'));
      expect(copied.single, contains('aVeryLongIdentifier'));
      expect(copied.single, contains('after prose'));
    },
    tags: const <String>['feature_test__turn_execution__widget'],
  );

  testWidgets(
    'an expanded tool call selects from its label through its payload',
    (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add(
              ((call.arguments as Map<Object?, Object?>)['text'] as String?) ??
                  '',
            );
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await pump(tester, <TimelineEventDto>[
        event('tool.requested', <String, dynamic>{
          'callId': 'call-1',
          'name': 'read_file',
          'arguments': <String, dynamic>{'path': 'a.dart'},
        }),
        event('tool.completed', <String, dynamic>{
          'callId': 'call-1',
          'name': 'read_file',
          'output': 'result payload',
          'isError': false,
        }),
        event('turn.completed', <String, dynamic>{'toolRounds': 1}),
      ]);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ChatToolCard));
      await tester.pumpAndSettle();

      // One host for the whole card, so a drag runs from the request label into
      // the payload rather than stopping at each block.
      final request = find.textContaining('a.dart', findRichText: true).first;
      final result = find.textContaining('result payload', findRichText: true);
      final gesture = await tester.startGesture(
        tester.getTopLeft(request) + const Offset(1, 1),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.moveTo(tester.getBottomRight(result) - const Offset(1, 1));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(copied.single, contains('a.dart'));
      expect(copied.single, contains('result payload'));
    },
    tags: const <String>['feature_test__turn_execution__widget'],
  );

  testWidgets(
    'unfolding a tool call keeps its header pinned so the body grows downward',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final events = <TimelineEventDto>[
        for (var index = 0; index < 12; index += 1)
          event('user.message', <String, dynamic>{'text': 'filler $index'}),
        event('tool.requested', <String, dynamic>{
          'callId': 'call-1',
          'name': 'read_file',
          'arguments': <String, dynamic>{'path': 'a.dart'},
        }),
        event('tool.completed', <String, dynamic>{
          'callId': 'call-1',
          'name': 'read_file',
          'output': 'body line 1\nbody line 2\nbody line 3\nbody line 4',
          'isError': false,
        }),
        event('turn.completed', <String, dynamic>{'toolRounds': 1}),
      ];

      await pump(tester, events);
      await tester.pumpAndSettle();

      final header = find.text('파일 읽기');
      final before = tester.getTopLeft(header).dy;
      await tester.tap(find.byType(ChatToolCard));
      await tester.pumpAndSettle();

      expect(find.textContaining('body line 1'), findsOneWidget);
      expect(tester.getTopLeft(header).dy, closeTo(before, 0.5));
    },
    tags: const <String>['feature_test__turn_execution__widget'],
  );

  testWidgets(
    'every assistant message in a transcript shares one Markdown stylesheet',
    tags: const <String>['feature_test__turn_execution__widget'],
    (tester) async {
      // Building the sheet per message means generating a full tonal palette
      // per message, on every streamed delta. Identity is the direct read of
      // whether the transcript computes it once or once per row.
      await pump(tester, <TimelineEventDto>[
        for (var index = 0; index < 4; index += 1) ...<TimelineEventDto>[
          event('assistant.delta', <String, dynamic>{
            'text': '**Answer $index**\n\nWith a paragraph.',
          }),
          event('turn.completed', <String, dynamic>{'toolRounds': 0}),
        ],
      ]);
      await tester.pumpAndSettle();

      final sheets = tester
          .widgetList<MarkdownBody>(find.byType(MarkdownBody))
          .map((body) => body.styleSheet)
          .toList();
      expect(sheets, hasLength(greaterThan(1)));
      expect(
        sheets.every((sheet) => identical(sheet, sheets.first)),
        isTrue,
        reason: 'one palette generation for the transcript, not one per row',
      );
    },
  );
}

Map<String, dynamic> _testToolPresentation(String name) {
  final glyph = switch (name) {
    'read_file' || 'read_attachment' || 'attach_file' => 'read',
    'list_directory' => 'list',
    'search_text' || 'glob' => 'search',
    'apply_patch' => 'edit',
    'exec_command' || 'write_stdin' => 'run',
    'spawn_agent' ||
    'send_message' ||
    'followup_task' ||
    'wait_agent' ||
    'interrupt_agent' ||
    'list_agents' => 'delegate',
    'request_user_input' => 'ask',
    'list_mcp_resources' ||
    'list_mcp_resource_templates' ||
    'read_mcp_resource' => 'resource',
    'list_skills' || 'skill' || 'skills__list' || 'skills__read' => 'resource',
    'tool_search' => 'tools',
    'clock__curr_time' || 'clock__sleep' => 'clock',
    'get_context_remaining' || 'new_context' || 'compact_context' => 'context',
    'view_image' => 'image',
    _ => 'generic',
  };
  final label = switch (name) {
    'read_file' => 'Read file',
    'apply_patch' => 'Apply patch',
    'exec_command' => 'Execute command',
    'clock__sleep' => 'Sleep',
    _ => name,
  };
  return <String, dynamic>{
    'glyph': glyph,
    'label': label,
    if (name == 'read_file') 'summary_argument': 'path',
    if (name == 'exec_command') 'summary_argument': 'command',
    if (name == 'request_user_input') 'timeline': 'question',
    if (name == 'clock__sleep') 'timeline': 'sleep',
    if (name == 'attach_file') 'timeline': 'suppressed',
  };
}

final class _RecordingUrlOpener implements ExternalUrlOpener {
  final List<Uri> opened = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}
