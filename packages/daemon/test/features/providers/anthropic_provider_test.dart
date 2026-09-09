import 'dart:convert';
import 'dart:typed_data';

import 'package:agent/agent.dart';
import 'package:daemon/src/features/providers/infrastructure/anthropic/anthropic_provider.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Messages preserves ordered system and conversational role blocks',
    () async {
      final adapter = _RecordingAdapter('''
event: message_start
data: {"type":"message_start","message":{"usage":{}}}

event: message_stop
data: {"type":"message_stop"}

''');
      await AnthropicMessagesProvider(
            const AnthropicProviderConfig(apiKey: 'secret'),
            dio: Dio()..httpClientAdapter = adapter,
          )
          .stream(
            const ModelRequest(
              model: 'claude-sonnet-5',
              blocks: <ModelRoleBlock>[
                ModelRoleBlock(role: ModelRole.system, content: 'system-1'),
                ModelRoleBlock(role: ModelRole.system, content: 'system-2'),
                ModelRoleBlock(role: ModelRole.user, content: 'user-1'),
                ModelRoleBlock(
                  role: ModelRole.assistant,
                  content: 'assistant-1',
                ),
              ],
              history: <ConversationItem>[],
              tools: <ModelToolDefinition>[],
            ),
            CancellationToken(),
          )
          .toList();

      final body = Map<String, dynamic>.from(adapter.options!.data as Map);
      expect(body['system'], <Map<String, dynamic>>[
        <String, dynamic>{'type': 'text', 'text': 'system-1'},
        <String, dynamic>{'type': 'text', 'text': 'system-2'},
      ]);
      expect(body['messages'], <Map<String, dynamic>>[
        <String, dynamic>{
          'role': 'user',
          'content': <Map<String, dynamic>>[
            <String, dynamic>{'type': 'text', 'text': 'user-1'},
          ],
        },
        <String, dynamic>{
          'role': 'assistant',
          'content': <Map<String, dynamic>>[
            <String, dynamic>{'type': 'text', 'text': 'assistant-1'},
          ],
        },
      ]);
      // The two destinations partition the blocks. A role that matched
      // neither would vanish with no error, so count the round trip.
      expect(
        (body['system']! as List).length + (body['messages']! as List).length,
        ModelRole.values.length + 1,
      );
    },
  );

  test('Messages accumulates tools and preserves thinking blocks', () async {
    final adapter = _RecordingAdapter(r'''
event: message_start
data: {"type":"message_start","message":{"usage":{"input_tokens":7}}}

event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":"","signature":""}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"plan"}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"signature_delta","signature":"signed"}}

event: content_block_stop
data: {"type":"content_block_stop","index":0}

event: content_block_start
data: {"type":"content_block_start","index":1,"content_block":{"type":"text","text":""}}

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"hello"}}

event: content_block_start
data: {"type":"content_block_start","index":2,"content_block":{"type":"tool_use","id":"call-1","name":"read_file","input":{}}}

event: content_block_delta
data: {"type":"content_block_delta","index":2,"delta":{"type":"input_json_delta","partial_json":"{\"path\":"}}

event: content_block_delta
data: {"type":"content_block_delta","index":2,"delta":{"type":"input_json_delta","partial_json":"\"README.md\"}"}}

event: content_block_stop
data: {"type":"content_block_stop","index":2}

event: message_delta
data: {"type":"message_delta","usage":{"output_tokens":5}}

event: message_stop
data: {"type":"message_stop"}

''');
    final provider = AnthropicMessagesProvider(
      const AnthropicProviderConfig(apiKey: 'secret'),
      dio: Dio()..httpClientAdapter = adapter,
    );
    final events = await provider
        .stream(_request(), CancellationToken())
        .toList();

    expect(events.whereType<ModelTextDelta>().single.delta, 'hello');
    expect(events.whereType<ModelReasoningDelta>().single.delta, 'plan');
    expect(
      events.whereType<ModelFunctionCall>().single.arguments,
      <String, dynamic>{'path': 'README.md'},
    );
    final completed = events.whereType<ModelResponseCompleted>().single;
    expect(completed.usage.inputTokens, 7);
    expect(completed.usage.outputTokens, 5);
    expect(completed.assistant.opaqueItems.single['block'], <String, dynamic>{
      'type': 'thinking',
      'thinking': 'plan',
      'signature': 'signed',
    });

    final continuationAdapter = _RecordingAdapter('''
event: message_start
data: {"type":"message_start","message":{"usage":{}}}

event: message_stop
data: {"type":"message_stop"}

''');
    await AnthropicMessagesProvider(
          const AnthropicProviderConfig(apiKey: 'secret'),
          dio: Dio()..httpClientAdapter = continuationAdapter,
        )
        .stream(
          _request(
            history: <ConversationItem>[
              completed.assistant,
              const ToolResultConversationItem(
                callId: 'call-1',
                output: 'contents',
                toolKind: ModelToolKind.function,
              ),
            ],
          ),
          CancellationToken(),
        )
        .toList();
    final body = Map<String, dynamic>.from(
      continuationAdapter.options!.data as Map,
    );
    expect(
      ((body['messages'] as List).first as Map)['content'],
      contains(
        equals(<String, dynamic>{
          'type': 'thinking',
          'thinking': 'plan',
          'signature': 'signed',
        }),
      ),
    );
  });
}

ModelRequest _request({
  List<ConversationItem> history = const <ConversationItem>[],
}) => ModelRequest(
  model: 'claude-sonnet-5',
  blocks: const <ModelRoleBlock>[
    ModelRoleBlock(role: ModelRole.system, content: 'test'),
  ],
  history: history,
  tools: const <ModelToolDefinition>[],
);

final class _RecordingAdapter implements HttpClientAdapter {
  new(this.body);
  final String body;
  RequestOptions? options;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    return ResponseBody.fromBytes(
      utf8.encode(body),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['text/event-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
