import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:agent/agent.dart';
import 'package:daemon/src/features/providers/infrastructure/openai/openai_provider.dart';
import 'package:daemon/src/features/providers/infrastructure/transport/error_body.dart';
import 'package:daemon/src/features/providers/infrastructure/transport/media.dart';
import 'package:daemon/src/features/providers/infrastructure/transport/sse.dart';
import 'package:dio/dio.dart';

/// OpenAIChatCompletionsProvider defines a public contract.
class OpenAIChatCompletionsProvider implements ModelGateway {
  /// Creates a [OpenAIChatCompletionsProvider].
  new(OpenAIProviderConfig config, {Dio? dio})
    : _config = config,
      _dio = dio ?? Dio(BaseOptions(baseUrl: config.baseUrl));

  final OpenAIProviderConfig _config;
  final Dio _dio;

  @override
  String get id => _config.id;

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    if (_config.requiresApiKey && _config.apiKey.isEmpty) {
      throw const OpenAIProviderException(
        'Provider API key is not configured.',
      );
    }
    final cancelToken = CancelToken();
    cancellation.onCancel(() => cancelToken.cancel('Agent turn cancelled.'));
    try {
      final response = await _dio.post<ResponseBody>(
        '/chat/completions',
        data: _requestBody(request),
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: <String, String>{
            ..._config.additionalHeaders,
            if (_config.apiKey.isNotEmpty)
              'Authorization': 'Bearer ${_config.apiKey}',
            'Accept': 'text/event-stream',
            'Content-Type': 'application/json',
          },
        ),
      );
      final stream = response.data?.stream;
      if (stream == null) {
        throw const OpenAIProviderException('No chat completion stream.');
      }
      yield* _modelEvents(stream, cancellation);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) throw const AgentCancelledException();
      final body = await decodeProviderErrorBody(error.response?.data);
      final message = providerErrorMessage(body) ?? error.message ?? '$error';
      if (isContextOverflowFailure(contextOverflowCode(body), message)) {
        throw ModelContextOverflowException(message);
      }
      throw OpenAIProviderException(
        describeProviderFailure(error.response?.statusCode, message),
        retryable: _isRetryable(error),
      );
    }
  }

  Map<String, dynamic> _requestBody(ModelRequest request) => <String, dynamic>{
    'model': request.model,
    'messages': <Map<String, dynamic>>[
      for (final block in request.blocks)
        <String, dynamic>{'role': block.role.name, 'content': block.content},
      ..._messages(request.history),
    ],
    if (_config.supportsReasoningEffort)
      'reasoning_effort': ?modelControlString(
        request,
        AgentModelControlIds.reasoningEffort,
      ),
    if (_config.accepts(ProviderEndpointExtension.expeditedProcessing) &&
        modelControlBool(request, AgentModelControlIds.fastMode) == true)
      'service_tier': 'priority',
    'tools': request.tools
        .whereType<ModelFunctionToolDefinition>()
        .map(
          (tool) => <String, dynamic>{
            'type': 'function',
            'function': <String, dynamic>{
              'name': tool.name,
              'description': tool.description,
              'parameters': tool.parameters,
              if (_config.accepts(ProviderEndpointExtension.strictToolSchemas))
                'strict': true,
            },
          },
        )
        .toList(growable: false),
    'stream': true,
    if (request.forceToolName != null)
      'tool_choice': <String, dynamic>{
        'type': 'function',
        'function': <String, dynamic>{'name': request.forceToolName},
      },
    'stream_options': <String, dynamic>{'include_usage': true},
  };

  List<Map<String, dynamic>> _messages(List<ConversationItem> history) {
    final result = <Map<String, dynamic>>[];
    for (final item in history) {
      switch (item) {
        case UserConversationItem(:final text, :final attachments):
          final content = StringBuffer(text);
          final images = <Map<String, dynamic>>[];
          for (final attachment in attachments) {
            final bytes = attachment.bytes;
            if (_config.supportsImageInput &&
                bytes != null &&
                inlineImageMediaTypes.contains(attachment.mimeType)) {
              images.add(<String, dynamic>{
                'type': 'image_url',
                'image_url': <String, dynamic>{
                  'url':
                      'data:${attachment.mimeType};'
                      'base64,${base64Encode(bytes)}',
                  'detail': attachment.imageDetail ?? 'auto',
                },
              });
              continue;
            }
            if (content.isNotEmpty) content.writeln();
            content.write(
              '[Attachment id=${attachment.id}, '
              'file=${attachment.fileName}, mime=${attachment.mimeType}, '
              'bytes=${attachment.byteSize}, path=${attachment.path}]',
            );
          }
          result.add(<String, dynamic>{
            'role': 'user',
            // A message without images keeps the plain-string form, so the
            // wire shape of every existing conversation is unchanged.
            'content': images.isEmpty
                ? content.toString()
                : <Map<String, dynamic>>[
                    if (content.isNotEmpty)
                      <String, dynamic>{
                        'type': 'text',
                        'text': content.toString(),
                      },
                    ...images,
                  ],
          });
        case AssistantConversationItem(:final text, :final toolCalls):
          result.add(<String, dynamic>{
            'role': 'assistant',
            'content': text.isEmpty ? null : text,
            if (toolCalls.isNotEmpty)
              'tool_calls': toolCalls
                  .map(
                    (call) => <String, dynamic>{
                      'id': call.callId,
                      'type': 'function',
                      'function': <String, dynamic>{
                        'name': call.name,
                        'arguments': jsonEncode(call.arguments),
                      },
                    },
                  )
                  .toList(growable: false),
          });
        case ToolResultConversationItem(:final callId, :final output):
          result.add(<String, dynamic>{
            'role': 'tool',
            'tool_call_id': callId,
            'content': output,
          });
      }
    }
    return result;
  }

  Stream<ModelEvent> _modelEvents(
    Stream<Uint8List> bytes,
    CancellationToken cancellation,
  ) async* {
    final text = StringBuffer();
    final calls = <int, _ChatToolCallBuilder>{};
    var usage = const ModelUsage();
    var receivedDone = false;
    await for (final sse in decodeServerSentEvents(bytes)) {
      cancellation.throwIfCancelled();
      if (sse.data == '[DONE]') {
        receivedDone = true;
        continue;
      }
      final decoded = jsonDecode(sse.data);
      if (decoded is! Map) continue;
      final event = Map<String, dynamic>.from(decoded);
      // Usage arrives in its own trailing chunk; keep the last non-empty one.
      final chunkUsage = _usage(event['usage']);
      if (!chunkUsage.isEmpty) usage = chunkUsage;
      final choices = event['choices'];
      if (choices is! List) continue;
      for (final choice in choices.whereType<Map<dynamic, dynamic>>()) {
        final delta = choice['delta'];
        if (delta is! Map) continue;
        for (final reasoning in _reasoningDeltas(delta)) {
          yield ModelReasoningDelta(reasoning);
        }
        final content = delta['content'];
        if (content is String && content.isNotEmpty) {
          text.write(content);
          yield ModelTextDelta(content);
        }
        for (final raw in delta['tool_calls'] as List? ?? const <dynamic>[]) {
          if (raw is! Map) continue;
          final index = raw['index'];
          if (index is! int) continue;
          final builder = calls.putIfAbsent(index, _ChatToolCallBuilder.new);
          if (raw['id'] is String) builder.callId = raw['id'] as String;
          final function = raw['function'];
          if (function is Map) {
            if (function['name'] is String) {
              builder.name += function['name'] as String;
            }
            if (function['arguments'] is String) {
              builder.arguments.write(function['arguments'] as String);
            }
          }
        }
      }
    }
    if (!receivedDone) {
      throw const OpenAIProviderException(
        'Chat completion stream ended before [DONE].',
      );
    }
    final toolCalls = <ConversationToolCall>[];
    for (final entry
        in calls.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
      final call = entry.value.build();
      toolCalls.add(call);
      yield ModelFunctionCall(
        callId: call.callId,
        name: call.name,
        arguments: call.arguments,
      );
    }
    yield ModelResponseCompleted(
      assistant: AssistantConversationItem(
        text: text.toString(),
        toolCalls: toolCalls,
      ),
      usage: usage,
    );
  }

  Iterable<String> _reasoningDeltas(Map<dynamic, dynamic> delta) sync* {
    final details = delta['reasoning_details'];
    var emittedStructured = false;
    if (details is List) {
      for (final detail in details.whereType<Map<dynamic, dynamic>>()) {
        final type = detail['type'];
        final value = switch (type) {
          'reasoning.text' => detail['text'],
          'reasoning.summary' => detail['summary'],
          _ => null,
        };
        if (value is String && value.isNotEmpty) {
          emittedStructured = true;
          yield value;
        }
      }
    }
    if (emittedStructured) return;
    final content = delta['reasoning_content'];
    if (content is String && content.isNotEmpty) {
      yield content;
      return;
    }
    final reasoning = delta['reasoning'];
    if (reasoning is String && reasoning.isNotEmpty) yield reasoning;
  }

  ModelUsage _usage(Object? value) {
    if (value is! Map) return const ModelUsage();
    return ModelUsage(
      inputTokens: _count(value['prompt_tokens']),
      cachedInputTokens: _nestedCount(
        value['prompt_tokens_details'],
        'cached_tokens',
      ),
      outputTokens: _count(value['completion_tokens']),
      reasoningTokens: _nestedCount(
        value['completion_tokens_details'],
        'reasoning_tokens',
      ),
      totalTokens: _count(value['total_tokens']),
    );
  }

  static int _count(Object? value) => value is int ? value : 0;

  static int _nestedCount(Object? details, String key) =>
      details is Map ? _count(details[key]) : 0;

  bool _isRetryable(DioException error) {
    final status = error.response?.statusCode;
    return status == 408 ||
        status == 429 ||
        (status != null && status >= 500) ||
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout;
  }
}

class _ChatToolCallBuilder {
  String callId = '';
  String name = '';
  final StringBuffer arguments = StringBuffer();

  ConversationToolCall build() {
    final decoded = jsonDecode(arguments.toString());
    if (callId.isEmpty || name.isEmpty || decoded is! Map) {
      throw const OpenAIProviderException('Invalid streamed tool call.');
    }
    return ConversationToolCall.function(
      callId: callId,
      name: name,
      arguments: Map<String, dynamic>.from(decoded),
    );
  }
}
