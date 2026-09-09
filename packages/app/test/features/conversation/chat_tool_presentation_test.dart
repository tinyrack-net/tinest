import 'dart:io';

import 'package:app/src/features/conversation/application/chat_timeline_model.dart';
import 'package:app/src/features/conversation/application/chat_tool_presentation.dart';
import 'package:app/src/features/conversation/presentation/chat_tool_card.dart';
import 'package:app/src/shared/presentation/tinest_icons.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/localization.dart';

void main() {
  final now = DateTime.utc(2026, 8, 3);

  ChatToolActivity activity({
    String name = 'acme_tool',
    Map<String, dynamic> arguments = const <String, dynamic>{},
    Map<String, dynamic> presentation = const <String, dynamic>{},
    ChatToolStatus status = ChatToolStatus.succeeded,
    String? output,
    String? error,
    bool isError = false,
  }) => ChatToolActivity(
    key: 'tool-call-1',
    turnId: 'turn-1',
    createdAt: now,
    callId: 'call-1',
    toolName: name,
    arguments: arguments,
    presentation: presentation,
    status: status,
    output: output,
    error: error,
    isError: isError,
  );

  test('tool output decoding never throws for plugin-owned payloads', () {
    expect(
      decodeToolOutput('{"exitCode":1,"output":"boom"}'),
      isA<ChatToolJsonObject>().having(
        (value) => value.value['exitCode'],
        'exitCode',
        1,
      ),
    );
    expect(decodeToolOutput('[{"path":"a.dart"}]'), isA<ChatToolJsonArray>());
    expect(decodeToolOutput('plain text'), isA<ChatToolPlainText>());
    expect(decodeToolOutput('{'), isA<ChatToolPlainText>());
    expect(decodeToolOutput('  '), isA<ChatToolPlainText>());
  }, tags: const <String>['feature_test__turn_execution__unit']);

  test(
    'pinned contribution metadata owns glyph label and argument summary',
    () {
      final described = describeToolActivity(
        testL10n,
        activity(
          name: 'not_a_built_in_name',
          arguments: const <String, dynamic>{
            'path': 'lib/main.dart',
            'ignored': 'second',
          },
          presentation: const <String, dynamic>{
            'glyph': 'read',
            'label': 'Plugin read',
            'summary_argument': 'path',
          },
          output: 'file contents',
        ),
      );

      expect(described.glyph, ChatToolGlyph.read);
      expect(chatToolIcon(described.glyph), TinestIcons.document);
      expect(described.title, 'Plugin read(lib/main.dart)');
      expect(described.resultLine, isNull);
      expect((described.body as ChatToolTextBody).text, 'file contents');
      expect(
        (described.argumentBody as ChatToolTextBody).text,
        contains('lib/main.dart'),
      );
    },
    tags: const <String>['feature_test__plugin_ui__widget'],
  );

  test(
    'unknown or invalid presentation metadata has a safe generic fallback',
    () {
      final described = describeToolActivity(
        testL10n,
        activity(
          arguments: const <String, dynamic>{'value': 7},
          presentation: const <String, dynamic>{
            'glyph': 'remote_svg',
            'label': 42,
          },
          output: '{"ok":true}',
        ),
      );

      expect(described.glyph, ChatToolGlyph.generic);
      expect(described.title, 'acme_tool(7)');
      expect(described.isFailure, isFalse);
    },
  );

  test('timeline placement is an allowlisted contribution hint', () {
    expect(
      chatToolTimelineFromPresentation(const <String, dynamic>{
        'timeline': 'suppressed',
      }),
      ChatToolTimeline.suppressed,
    );
    expect(
      chatToolTimelineFromPresentation(const <String, dynamic>{
        'timeline': 'question',
      }),
      ChatToolTimeline.question,
    );
    expect(
      chatToolTimelineFromPresentation(const <String, dynamic>{
        'timeline': 'sleep',
      }),
      ChatToolTimeline.sleep,
    );
    expect(
      chatToolTimelineFromPresentation(const <String, dynamic>{
        'timeline': 'arbitrary-widget',
      }),
      ChatToolTimeline.row,
    );
  });

  test('running denied and failed states remain host-owned', () {
    final running = describeToolActivity(
      testL10n,
      activity(status: ChatToolStatus.running),
    );
    final denied = describeToolActivity(
      testL10n,
      activity(status: ChatToolStatus.denied),
    );
    final failed = describeToolActivity(
      testL10n,
      activity(
        status: ChatToolStatus.failed,
        error: 'plugin failed',
        isError: true,
      ),
    );

    expect(running.resultLine, testL10n.commonRunning);
    expect(denied.resultLine, testL10n.toolRejected);
    expect(failed.resultLine, 'plugin failed');
    expect(failed.isFailure, isTrue);
  });

  test('the app contains no tool-name presenter registry', () {
    final source = File(
      'lib/src/features/conversation/application/chat_tool_presentation.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('chatToolPresenters')));
    expect(source, isNot(contains('presenterFor(')));
  });

  test('usage summaries report a rounded rate only for measured output', () {
    final summary = describeTokenUsage(testL10n, const <String, num>{
      'inputTokens': 1200,
      'outputTokens': 340,
      'totalTokens': 1540,
      'generationMs': 5450,
    });
    expect(summary, contains('62.4 tok/s'));
    expect(
      describeTokenUsage(testL10n, const <String, num>{
        'inputTokens': 1200,
        'totalTokens': 1200,
        'generationMs': 5450,
      }),
      isNot(contains('tok/s')),
    );
    expect(describeTokenUsage(testL10n, const <String, num>{}), isNull);
  }, tags: const <String>['feature_test__tool_context_budget__unit']);
}
