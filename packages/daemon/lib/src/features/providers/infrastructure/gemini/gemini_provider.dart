import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:agent/agent.dart';
import 'package:daemon/src/features/providers/infrastructure/transport/error_body.dart';
import 'package:daemon/src/features/providers/infrastructure/transport/sse.dart';
import 'package:dio/dio.dart';

/// Runtime configuration for Gemini Interactions.
final class GeminiProviderConfig {
  /// Creates Gemini endpoint configuration.
  const new({
    required this.apiKey,
    this.id = 'google',
    this.baseUrl = 'https://generativelanguage.googleapis.com/v1',
  });

  /// Connection ID.
  final String id;

  /// Secret API key.
  final String apiKey;

  /// Trusted or user-selected API root.
  final String baseUrl;
}

/// Classified Gemini transport or stream failure.
final class GeminiProviderException implements Exception {
  /// Creates a provider failure.
  const new(this.message, {this.retryable = false});

  /// User-safe description.
  final String message;

  /// Whether retrying without changing the request may succeed.
  final bool retryable;

  @override
  String toString() => 'GeminiProviderException: $message';
}

/// Stateless Gemini Interactions v1 streaming adapter.
final class GeminiInteractionsProvider implements ModelGateway {
  /// Creates an Interactions adapter.
  new(GeminiProviderConfig config, {Dio? dio})
    : _config = config,
      _dio = dio ?? Dio(BaseOptions(baseUrl: config.baseUrl));

  final GeminiProviderConfig _config;
  final Dio _dio;

  @override
  String get id => _config.id;

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    if (_config.apiKey.isEmpty) {
      throw const GeminiProviderException('Gemini API key is not configured.');
    }
    final cancelToken = CancelToken();
    cancellation.onCancel(() => cancelToken.cancel('Agent turn cancelled.'));
    try {
      final response = await _dio.post<ResponseBody>(
        '/interactions',
        data: _requestBody(request),
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: <String, String>{
            'x-goog-api-key': _config.apiKey,
            'accept': 'text/event-stream',
            'content-type': 'application/json',
          },
        ),
      );
      final bytes = response.data?.stream;
      if (bytes == null) {
        throw const GeminiProviderException(
          'No Gemini Interactions response stream.',
        );
      }
      yield* _events(bytes, cancellation);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) throw const AgentCancelledException();
      final body = await decodeProviderErrorBody(error.response?.data);
      final message = providerErrorMessage(body) ?? error.message ?? '$error';
      if (_isContextOverflow(message)) {
        throw ModelContextOverflowException(message);
      }
      final status = error.response?.statusCode;
      throw GeminiProviderException(
        describeProviderFailure(status, message),
        retryable: status == 429 || (status ?? 0) >= 500,
      );
    }
  }

  Map<String, dynamic> _requestBody(ModelRequest request) {
    final level = _stringControl(request, AgentModelControlIds.reasoningEffort);
    return <String, dynamic>{
      'model': request.model,
      // Complementary to the system-instruction filter, so a role added later
      // reaches the transport rather than being dropped between two positive
      // predicates.
      'input': <Map<String, dynamic>>[
        for (final block in request.blocks.where(
          (block) => block.role != ModelRole.system,
        ))
          <String, dynamic>{
            'role': block.role.name,
            'content': <Map<String, dynamic>>[
              <String, dynamic>{'type': 'text', 'text': block.content},
            ],
          },
        ..._input(request.history),
      ],
      'system_instruction': request.blocks
          .where((block) => block.role == ModelRole.system)
          .map((block) => block.content)
          .join('\n\n'),
      'stream': true,
      'store': false,
      if (level != null)
        'generation_config': <String, dynamic>{'thinking_level': level},
      'tools': <Map<String, dynamic>>[
        for (final tool
            in request.tools.whereType<ModelFunctionToolDefinition>())
          <String, dynamic>{
            'type': 'function',
            'name': tool.name,
            'description': tool.description,
            'parameters': tool.parameters,
          },
      ],
      if (request.forceToolName != null)
        'tool_choice': <String, dynamic>{
          'type': 'function',
          'name': request.forceToolName,
        },
    };
  }

  List<Map<String, dynamic>> _input(List<ConversationItem> history) =>
      <Map<String, dynamic>>[
        for (final item in history)
          switch (item) {
            UserConversationItem(:final text) => <String, dynamic>{
              'role': 'user',
              'content': <Map<String, dynamic>>[
                <String, dynamic>{'type': 'text', 'text': text},
              ],
            },
            AssistantConversationItem(
              :final text,
              :final toolCalls,
              :final opaqueItems,
            ) =>
              <String, dynamic>{
                'role': 'assistant',
                'content': <Map<String, dynamic>>[
                  for (final opaque in opaqueItems)
                    if (opaque['provider'] == 'gemini' && opaque['step'] is Map)
                      Map<String, dynamic>.from(opaque['step']! as Map),
                  if (text.isNotEmpty)
                    <String, dynamic>{'type': 'text', 'text': text},
                  for (final call in toolCalls)
                    <String, dynamic>{
                      'type': 'function_call',
                      'id': call.callId,
                      'name': call.name,
                      'arguments': call.arguments,
                    },
                ],
              },
            ToolResultConversationItem(
              :final callId,
              :final output,
              :final isError,
            ) =>
              <String, dynamic>{
                'type': 'function_result',
                'call_id': callId,
                'result': <Map<String, dynamic>>[
                  <String, dynamic>{'type': 'text', 'text': output},
                ],
                if (isError) 'is_error': true,
              },
          },
      ];

  Stream<ModelEvent> _events(
    Stream<Uint8List> bytes,
    CancellationToken cancellation,
  ) async* {
    var text = '';
    var completed = false;
    final steps = <int, _GeminiStep>{};
    final calls = <ConversationToolCall>[];
    final opaque = <Map<String, dynamic>>[];
    await for (final sse in decodeServerSentEvents(bytes)) {
      cancellation.throwIfCancelled();
      if (sse.data == '[DONE]') break;
      final event = Map<String, dynamic>.from(jsonDecode(sse.data) as Map);
      final type = event['event_type'] ?? event['type'];
      switch (type) {
        case 'step.start':
          final index = event['index'];
          final raw = event['step'];
          if (index is int && raw is Map) {
            steps[index] = _GeminiStep(Map<String, dynamic>.from(raw));
          }
        case 'step.delta':
          final index = event['index'];
          final delta = event['delta'];
          if (index is! int || delta is! Map || steps[index] == null) continue;
          final step = steps[index]!;
          switch (delta['type']) {
            case 'text':
              final value = delta['text'];
              if (value is String) {
                text += value;
                yield ModelTextDelta(value);
              }
            case 'arguments_delta':
              final value = delta['arguments'];
              if (value is String) step.arguments.write(value);
            case 'arguments':
              final value = delta['partial_arguments'];
              if (value is String) step.arguments.write(value);
            case 'thought_signature':
              final value = delta['signature'];
              if (value is String) step.signature.write(value);
            case 'thought_summary' || 'thought':
              final value = delta['text'];
              if (value is String) {
                step.thought.write(value);
                if (value.isNotEmpty) yield ModelReasoningDelta(value);
              }
          }
        case 'step.stop':
          final index = event['index'];
          final step = index is int ? steps[index] : null;
          if (step == null) continue;
          if (step.raw['type'] == 'function_call') {
            final initial = step.raw['arguments'];
            final arguments = step.arguments.isEmpty && initial is Map
                ? Map<String, dynamic>.from(initial)
                : _jsonObject(step.arguments.toString());
            final call = ConversationToolCall.function(
              callId: step.raw['id']! as String,
              name: step.raw['name']! as String,
              arguments: arguments,
            );
            calls.add(call);
            yield ModelFunctionCall(
              callId: call.callId,
              name: call.name,
              arguments: call.arguments,
            );
          } else if (step.raw['type'] == 'thought') {
            final raw = <String, dynamic>{...step.raw};
            if (step.signature.isNotEmpty) {
              raw['signature'] = '${step.signature}';
            }
            if (step.thought.isNotEmpty) raw['summary'] = '${step.thought}';
            opaque.add(<String, dynamic>{'provider': 'gemini', 'step': raw});
          }
        case 'interaction.completed' || 'interaction.requires_action':
          final interaction = event['interaction'];
          final rawUsage = interaction is Map ? interaction['usage'] : null;
          final usage = rawUsage is Map ? _usage(rawUsage) : const ModelUsage();
          yield ModelResponseCompleted(
            assistant: AssistantConversationItem(
              text: text,
              toolCalls: calls,
              opaqueItems: opaque,
            ),
            usage: usage,
          );
          completed = true;
        case 'error':
          final error = event['error'];
          final code = error is Map ? error['code'] : null;
          final message = error is Map ? error['message'] : null;
          throw GeminiProviderException(
            message is String ? message : 'Gemini stream failed.',
            retryable: code == 'gateway_timeout' || code == 'unavailable',
          );
      }
    }
    if (!completed &&
        (text.isNotEmpty || calls.isNotEmpty || opaque.isNotEmpty)) {
      yield ModelResponseCompleted(
        assistant: AssistantConversationItem(
          text: text,
          toolCalls: calls,
          opaqueItems: opaque,
        ),
      );
    }
  }
}

final class _GeminiStep {
  new(this.raw);
  final Map<String, dynamic> raw;
  final StringBuffer arguments = StringBuffer();
  final StringBuffer signature = StringBuffer();
  final StringBuffer thought = StringBuffer();
}

Map<String, dynamic> _jsonObject(String value) {
  if (value.isEmpty) return <String, dynamic>{};
  final decoded = jsonDecode(value);
  if (decoded is! Map) throw const FormatException('Tool input must be JSON.');
  return Map<String, dynamic>.from(decoded);
}

ModelUsage _usage(Map<dynamic, dynamic> value) {
  int read(String preferred, String fallback) {
    final raw = value[preferred] ?? value[fallback];
    return raw is int ? raw : 0;
  }

  return ModelUsage(
    inputTokens: read('total_input_tokens', 'prompt_tokens'),
    cachedInputTokens: read('total_cached_tokens', 'cached_tokens'),
    outputTokens: read('total_output_tokens', 'completion_tokens'),
    reasoningTokens: read('total_thought_tokens', 'thought_tokens'),
    totalTokens: read('total_tokens', 'total_tokens'),
  );
}

String? _stringControl(ModelRequest request, String id) =>
    switch (request.modelControls[id]) {
      AgentModelControlStringValue(:final value) => value,
      _ => null,
    };

bool _isContextOverflow(String message) {
  final lowered = message.toLowerCase();
  return lowered.contains('context window') ||
      lowered.contains('input token count') ||
      lowered.contains('too many tokens');
}
