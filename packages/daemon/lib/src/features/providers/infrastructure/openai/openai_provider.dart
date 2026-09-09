import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:agent/agent.dart';
import 'package:daemon/src/features/providers/infrastructure/transport/error_body.dart';
import 'package:daemon/src/features/providers/infrastructure/transport/media.dart';
import 'package:daemon/src/features/providers/infrastructure/transport/sse.dart';
import 'package:dio/dio.dart';

/// OpenAIProviderConfig defines a public contract.
class OpenAIProviderConfig {
  /// Creates a [OpenAIProviderConfig].
  /// Every optional behaviour is stated by the caller. A default here would be
  /// a second place for one vendor's answer to hide, which is what let the
  /// platform-only fields reach every compatible endpoint.
  const new({
    required this.id,
    required this.baseUrl,
    this.apiKey = '',
    this.maxConnectAttempts = 3,
    this.requiresApiKey = true,
    this.supportsReasoningEffort = false,
    this.supportsImageInput = false,
    this.supportsFileInput = false,
    this.extensions = const <ProviderEndpointExtension>{},
    this.requestAttribution,
    this.additionalHeaders = const <String, String>{},
  });

  /// The id public API member.
  final String id;

  /// The apiKey public API member.
  final String apiKey;

  /// The baseUrl public API member.
  final String baseUrl;

  /// The maxConnectAttempts public API member.
  final int maxConnectAttempts;

  /// The requiresApiKey public API member.
  final bool requiresApiKey;

  /// The supportsReasoningEffort public API member.
  final bool supportsReasoningEffort;

  /// Whether hydrated images may be sent as Responses content parts.
  final bool supportsImageInput;

  /// Whether hydrated documents may be sent as Responses content parts.
  final bool supportsFileInput;

  /// Optional behaviours the endpoint this config addresses documents.
  final Set<ProviderEndpointExtension> extensions;

  /// Opaque per-installation identifier, when the endpoint accepts one.
  ///
  /// Supplied by the composition root rather than carried on every model
  /// request: one vendor's platform defines the field and the others do not.
  final String? requestAttribution;

  /// Additional non-secret headers required by a provider runtime.
  final Map<String, String> additionalHeaders;

  /// Whether the endpoint this config addresses accepts [extension].
  bool accepts(ProviderEndpointExtension extension) =>
      extensions.contains(extension);
}

/// OpenAIProviderException defines a public contract.
class OpenAIProviderException implements Exception {
  /// Creates a [OpenAIProviderException].
  const new(this.message, {this.retryable = false});

  /// The message public API member.
  final String message;

  /// The retryable public API member.
  final bool retryable;

  @override
  String toString() => 'OpenAIProviderException: $message';
}

/// Error codes every OpenAI-compatible API uses for an oversized prompt.
const Set<String> _contextOverflowCodes = <String>{
  'context_length_exceeded',
  'string_above_max_length',
};

/// Wordings used by servers that report the overflow without a code.
const List<String> _contextOverflowPhrases = <String>[
  'maximum context length',
  'context window',
  'too many tokens',
];

/// Decides whether a provider failure means the history no longer fits.
///
/// Both adapters share this so a compaction retry is triggered by the same
/// signal regardless of which API the provider speaks. Matching is broader than
/// the code alone because self-hosted runtimes report the same condition in
/// prose only.
bool isContextOverflowFailure(String? code, String message) {
  if (code != null && _contextOverflowCodes.contains(code)) return true;
  final lowered = message.toLowerCase();
  return _contextOverflowPhrases.any(lowered.contains);
}

bool _isReasoningSummaryRejection(
  int? statusCode,
  Object? body,
  String message,
) {
  if (statusCode != 400 && statusCode != 403) return false;
  Object? parameter;
  if (body is Map && body['error'] is Map) {
    parameter = (body['error'] as Map)['param'];
  }
  final description = '${parameter ?? ''} $message'.toLowerCase();
  return description.contains('summary') &&
      (description.contains('reasoning') ||
          description.contains('verification') ||
          description.contains('unsupported'));
}

/// Reads the `error.code` out of an OpenAI error envelope.
String? contextOverflowCode(Object? body) {
  if (body is! Map) return null;
  final error = body['error'];
  if (error is! Map) return null;
  final code = error['code'];
  return code is String ? code : null;
}

/// Reads a string-valued provider control.
String? modelControlString(ModelRequest request, String id) =>
    switch (request.modelControls[id]) {
      AgentModelControlStringValue(:final value) => value,
      _ => null,
    };

/// Reads a boolean-valued provider control.
bool? modelControlBool(ModelRequest request, String id) =>
    switch (request.modelControls[id]) {
      AgentModelControlBoolValue(:final value) => value,
      _ => null,
    };

/// Marks continuation state as belonging to this transport.
///
/// A session may move between providers, so every stored opaque item names
/// the transport that produced it and each replays only its own.
const String _providerTag = 'openai';

/// Where this wire performs deferred-tool matching and loading.
///
/// A Responses-only concept, so the value belongs to this transport rather
/// than to the neutral tool declaration every wire shares.
const String _clientExecution = 'client';

String? _deferredSearchName(List<ModelToolDefinition> tools) {
  final deferred = tools.whereType<ModelDeferredSearchToolDefinition>();
  final iterator = deferred.iterator;
  if (!iterator.moveNext()) return null;
  final name = iterator.current.name;
  if (iterator.moveNext()) {
    throw const OpenAIProviderException(
      'OpenAI Responses supports one provider-native deferred search tool.',
    );
  }
  return name;
}

/// OpenAIResponsesProvider defines a public contract.
class OpenAIResponsesProvider implements ModelGateway {
  /// Creates a [OpenAIResponsesProvider].
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
        'OpenAI API key is not configured. Connect the provider first.',
      );
    }
    final cancelToken = CancelToken();
    final deferredSearchName = _deferredSearchName(request.tools);
    cancellation.onCancel(() => cancelToken.cancel('Agent turn cancelled.'));
    Response<ResponseBody>? response;
    Object? lastError;
    var includeReasoningSummary = _config.accepts(
      ProviderEndpointExtension.reasoningSummaries,
    );
    var reasoningSummaryDowngraded = false;
    for (var attempt = 1; attempt <= _config.maxConnectAttempts; attempt += 1) {
      cancellation.throwIfCancelled();
      try {
        response = await _dio.post<ResponseBody>(
          '/responses',
          data: _requestBody(
            request,
            includeReasoningSummary: includeReasoningSummary,
          ),
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
        break;
      } on DioException catch (error) {
        if (CancelToken.isCancel(error)) throw const AgentCancelledException();
        final body = await decodeProviderErrorBody(error.response?.data);
        final message = providerErrorMessage(body) ?? error.message ?? '$error';
        if (includeReasoningSummary &&
            !reasoningSummaryDowngraded &&
            _isReasoningSummaryRejection(
              error.response?.statusCode,
              body,
              message,
            )) {
          includeReasoningSummary = false;
          reasoningSummaryDowngraded = true;
          attempt -= 1;
          continue;
        }
        // An oversized prompt is rejected before the stream opens, so it has to
        // be classified here rather than among the SSE events.
        if (isContextOverflowFailure(contextOverflowCode(body), message)) {
          throw ModelContextOverflowException(message);
        }
        final retryable = _isRetryable(error);
        // A raw DioException stringifies to its status code alone, so the
        // rejection is restated here or the reason never reaches the turn.
        final failure = OpenAIProviderException(
          describeProviderFailure(error.response?.statusCode, message),
          retryable: retryable,
        );
        lastError = failure;
        if (!retryable || attempt == _config.maxConnectAttempts) throw failure;
        await Future<void>.delayed(
          Duration(milliseconds: 250 * (1 << (attempt - 1))),
        );
      }
    }
    if (response?.data == null) {
      throw OpenAIProviderException('No response stream: $lastError');
    }
    yield* _modelEvents(
      response!.data!.stream,
      cancellation,
      deferredSearchName: deferredSearchName,
    );
  }

  Map<String, dynamic> _requestBody(
    ModelRequest request, {
    required bool includeReasoningSummary,
  }) {
    final effort = modelControlString(
      request,
      AgentModelControlIds.reasoningEffort,
    );
    final mode = modelControlString(
      request,
      AgentModelControlIds.reasoningMode,
    );
    return <String, dynamic>{
      'model': request.model,
      'input': <Map<String, dynamic>>[
        ...request.blocks.map(
          (block) => <String, dynamic>{
            'type': 'message',
            'role': block.role.name,
            'content': <Map<String, dynamic>>[
              <String, dynamic>{
                'type': block.role == ModelRole.assistant
                    ? 'output_text'
                    : 'input_text',
                'text': block.content,
              },
            ],
          },
        ),
        ..._responsesInput(request.history),
      ],
      if ((_config.supportsReasoningEffort &&
              (effort != null || mode != null)) ||
          includeReasoningSummary)
        'reasoning': <String, dynamic>{
          if (_config.supportsReasoningEffort) 'effort': ?effort,
          if (_config.supportsReasoningEffort) 'mode': ?mode,
          if (includeReasoningSummary) 'summary': 'auto',
        },
      if (_config.accepts(ProviderEndpointExtension.expeditedProcessing) &&
          modelControlBool(request, AgentModelControlIds.fastMode) == true)
        'service_tier': 'priority',
      'tools': request.tools.map(_responsesTool).toList(growable: false),
      'parallel_tool_calls': _config.accepts(
        ProviderEndpointExtension.concurrentToolCalls,
      ),
      if (request.forceToolName != null)
        'tool_choice': <String, dynamic>{
          'type': 'function',
          'name': request.forceToolName,
        },
      'stream': true,
      'store': false,
      if (_config.accepts(ProviderEndpointExtension.reasoningContinuation))
        'include': <String>['reasoning.encrypted_content'],
      if (_config.accepts(ProviderEndpointExtension.requestAttribution))
        'safety_identifier': ?_config.requestAttribution,
    };
  }

  List<Map<String, dynamic>> _responsesInput(List<ConversationItem> history) {
    final result = <Map<String, dynamic>>[];
    var directFileBytes = 0;
    for (final item in history) {
      switch (item) {
        case UserConversationItem(:final text, :final attachments):
          final content = <Map<String, dynamic>>[
            if (text.isNotEmpty)
              <String, dynamic>{'type': 'input_text', 'text': text},
          ];
          for (final attachment in attachments) {
            final bytes = attachment.bytes;
            if (_config.supportsImageInput &&
                bytes != null &&
                _supportedImageTypes.contains(attachment.mimeType)) {
              content.add(<String, dynamic>{
                'type': 'input_image',
                'image_url':
                    'data:${attachment.mimeType};base64,${base64Encode(bytes)}',
                'detail': attachment.imageDetail ?? 'auto',
              });
            } else if (_config.supportsFileInput &&
                _config.accepts(ProviderEndpointExtension.inlineDocuments) &&
                bytes != null &&
                _isSupportedFile(attachment) &&
                directFileBytes + bytes.length <= _maxDirectFileBytes) {
              directFileBytes += bytes.length;
              content.add(<String, dynamic>{
                'type': 'input_file',
                'filename': attachment.fileName,
                'file_data':
                    'data:${attachment.mimeType};base64,${base64Encode(bytes)}',
              });
            } else {
              content.add(<String, dynamic>{
                'type': 'input_text',
                'text': _attachmentFallback(attachment),
              });
            }
          }
          result.add(<String, dynamic>{'role': 'user', 'content': content});
        case AssistantConversationItem(
          :final text,
          :final toolCalls,
          :final opaqueItems,
        ):
          // A session may have been continued across transports, and the
          // others' continuation state is not decodable here.
          for (final item in opaqueItems) {
            if (item['provider'] != _providerTag) continue;
            final replayed = item['item'];
            if (replayed is Map) {
              result.add(Map<String, dynamic>.from(replayed));
            }
          }
          if (text.isNotEmpty) {
            result.add(<String, dynamic>{
              'type': 'message',
              'role': 'assistant',
              'content': <Map<String, dynamic>>[
                <String, dynamic>{
                  'type': 'output_text',
                  'text': text,
                  'annotations': <dynamic>[],
                },
              ],
            });
          }
          for (final call in toolCalls) {
            result.add(
              call.kind == ModelToolKind.deferredSearch
                  ? <String, dynamic>{
                      'type': 'tool_search_call',
                      'call_id': call.callId,
                      'execution': _clientExecution,
                      'arguments': call.arguments,
                    }
                  : <String, dynamic>{
                      'type': 'function_call',
                      'call_id': call.callId,
                      if (call.namespace != null) 'namespace': call.namespace,
                      'name': call.namespace == null
                          ? call.name
                          : call.name.substring(call.namespace!.length + 2),
                      'arguments': jsonEncode(call.arguments),
                    },
            );
          }
        case ToolResultConversationItem(
          :final callId,
          :final output,
          :final toolKind,
          :final content,
        ):
          result.add(<String, dynamic>{
            'type': switch (toolKind) {
              ModelToolKind.deferredSearch => 'tool_search_output',
              ModelToolKind.function ||
              ModelToolKind.namespace => 'function_call_output',
            },
            'call_id': callId,
            if (toolKind == ModelToolKind.deferredSearch) ...<String, dynamic>{
              'status': 'completed',
              'execution': _clientExecution,
              'tools': (jsonDecode(output) as Map)['tools'],
            } else
              'output': _functionOutput(output, content),
          });
      }
    }
    return result;
  }

  Object _functionOutput(String output, List<ToolContent> content) {
    if (content.isEmpty) return output;
    return <Map<String, dynamic>>[
      for (final item in content)
        switch (item) {
          ToolTextContent(:final text) => <String, dynamic>{
            'type': 'input_text',
            'text': text,
          },
          ToolImageContent(:final imageUrl, :final detail) => <String, dynamic>{
            'type': 'input_image',
            'image_url': imageUrl,
            'detail': ?detail,
          },
          ToolAudioContent(:final audioUrl) => <String, dynamic>{
            'type': 'input_audio',
            'audio_url': audioUrl,
          },
          ToolEmbeddedResourceContent() ||
          ToolResourceLinkContent() => <String, dynamic>{
            'type': 'input_text',
            'text': jsonEncode(item.toJson()),
          },
        },
    ];
  }

  Map<String, dynamic> _responsesTool(ModelToolDefinition tool) =>
      switch (tool) {
        ModelFunctionToolDefinition() => <String, dynamic>{
          'type': 'function',
          'name': tool.name,
          'description': tool.description,
          'parameters': tool.parameters,
          'strict': _config.accepts(
            ProviderEndpointExtension.strictToolSchemas,
          ),
          if (_config.accepts(ProviderEndpointExtension.toolOutputSchemas) &&
              tool.outputSchema != null)
            'output_schema': tool.outputSchema,
        },
        ModelNamespaceToolDefinition() => <String, dynamic>{
          'type': 'namespace',
          'name': tool.name,
          'description': tool.description,
          'tools': tool.tools.map(_responsesTool).toList(growable: false),
        },
        ModelDeferredSearchToolDefinition() => <String, dynamic>{
          'type': 'tool_search',
          'execution': _clientExecution,
          'description': tool.description,
          'parameters': tool.parameters,
        },
      };

  static const Set<String> _supportedImageTypes = inlineImageMediaTypes;

  static const int _maxDirectFileBytes = 50 * 1024 * 1024;

  static const Set<String> _supportedFileTypes = <String>{
    'application/pdf',
    'application/json',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'text/plain',
    'text/markdown',
    'text/csv',
    'text/html',
    'text/xml',
  };

  static bool _isSupportedFile(ConversationAttachment attachment) =>
      _supportedFileTypes.contains(attachment.mimeType) ||
      <String>{
        '.c',
        '.cpp',
        '.css',
        '.dart',
        '.go',
        '.java',
        '.js',
        '.kt',
        '.py',
        '.rb',
        '.rs',
        '.sh',
        '.ts',
        '.yaml',
        '.yml',
      }.any(attachment.fileName.toLowerCase().endsWith);

  static String _attachmentFallback(ConversationAttachment attachment) =>
      '[Attachment id=${attachment.id}, file=${attachment.fileName}, '
      'mime=${attachment.mimeType}, bytes=${attachment.byteSize}, '
      'path=${attachment.path}]';

  Stream<ModelEvent> _modelEvents(
    Stream<Uint8List> bytes,
    CancellationToken cancellation, {
    required String? deferredSearchName,
  }) async* {
    final emittedCalls = <String>{};
    await for (final sse in decodeServerSentEvents(bytes)) {
      cancellation.throwIfCancelled();
      if (sse.data == '[DONE]') continue;
      final decoded = jsonDecode(sse.data);
      if (decoded is! Map) continue;
      final event = Map<String, dynamic>.from(decoded);
      final type = event['type'] as String? ?? sse.event;
      switch (type) {
        case 'response.reasoning_summary_text.delta':
        case 'response.reasoning.delta':
          final delta = event['delta'];
          if (delta is String && delta.isNotEmpty) {
            yield ModelReasoningDelta(delta);
          }
        case 'response.output_text.delta':
          final delta = event['delta'];
          if (delta is String && delta.isNotEmpty) yield ModelTextDelta(delta);
        case 'response.output_item.done':
          final item = event['item'];
          if (item is Map) {
            final call = _toolCall(
              Map<String, dynamic>.from(item),
              deferredSearchName: deferredSearchName,
            );
            if (call != null && emittedCalls.add(call.callId)) yield call;
          }
        case 'response.completed':
          final response = event['response'];
          if (response is! Map) {
            throw const OpenAIProviderException(
              'response.completed has no response object.',
            );
          }
          final responseMap = Map<String, dynamic>.from(response);
          final output = (responseMap['output'] as List? ?? const <dynamic>[])
              .whereType<Map<dynamic, dynamic>>()
              .map(Map<String, dynamic>.from)
              .toList(growable: false);
          for (final item in output) {
            final call = _toolCall(
              item,
              deferredSearchName: deferredSearchName,
            );
            if (call != null && emittedCalls.add(call.callId)) yield call;
          }
          final calls = output
              .map(
                (item) =>
                    _toolCall(item, deferredSearchName: deferredSearchName),
              )
              .whereType<ModelToolCall>()
              .map(
                (call) => call is ModelDeferredSearchCall
                    ? ConversationToolCall.deferredSearch(
                        callId: call.callId,
                        name: call.name,
                        arguments: call.arguments,
                      )
                    : ConversationToolCall.function(
                        callId: call.callId,
                        name: call.name,
                        namespace: call.namespace,
                        arguments: call.arguments,
                      ),
              )
              .toList(growable: false);
          yield ModelResponseCompleted(
            assistant: AssistantConversationItem(
              text: _outputText(output),
              toolCalls: calls,
              opaqueItems: output
                  .where(
                    (item) =>
                        item['type'] != 'message' &&
                        item['type'] != 'function_call',
                  )
                  .map(
                    (item) => <String, dynamic>{
                      'provider': _providerTag,
                      'item': Map<String, dynamic>.from(item),
                    },
                  )
                  .toList(growable: false),
            ),
            usage: _usage(responseMap['usage']),
          );
        case 'response.failed':
        case 'error':
          throw _streamFailure(event);
      }
    }
  }

  String _outputText(List<Map<String, dynamic>> output) {
    final buffer = StringBuffer();
    for (final item in output) {
      if (item['type'] != 'message') continue;
      for (final content in item['content'] as List? ?? const <dynamic>[]) {
        if (content is Map && content['type'] == 'output_text') {
          final text = content['text'];
          if (text is String) buffer.write(text);
        }
      }
    }
    return buffer.toString();
  }

  ModelToolCall? _toolCall(
    Map<String, dynamic> item, {
    required String? deferredSearchName,
  }) {
    final callId = item['call_id'];
    if (callId is! String) return null;
    if (item['type'] == 'tool_search_call') {
      if (deferredSearchName == null) {
        throw const OpenAIProviderException(
          'The provider emitted a deferred search call without a selected '
          'Lua tool.',
        );
      }
      final arguments = item['arguments'];
      if (arguments is! Map) return null;
      return ModelDeferredSearchCall(
        callId: callId,
        name: deferredSearchName,
        arguments: Map<String, dynamic>.from(arguments),
      );
    }
    final name = item['name'];
    if (name is! String) return null;
    final namespace = item['namespace'] is String
        ? item['namespace']! as String
        : null;
    final canonicalName = namespace == null ? name : '${namespace}__$name';
    if (item['type'] == 'function_call') {
      final arguments = item['arguments'];
      if (arguments is! String) return null;
      final decoded = jsonDecode(arguments);
      if (decoded is! Map) {
        throw OpenAIProviderException(
          'Function $name returned non-object arguments.',
        );
      }
      return ModelFunctionCall(
        callId: callId,
        name: canonicalName,
        namespace: namespace,
        arguments: Map<String, dynamic>.from(decoded),
      );
    }
    return null;
  }

  ModelUsage _usage(Object? value) {
    if (value is! Map) return const ModelUsage();
    final usage = Map<String, dynamic>.from(value);
    return ModelUsage(
      inputTokens: _count(usage['input_tokens']),
      cachedInputTokens: _nestedCount(
        usage['input_tokens_details'],
        'cached_tokens',
      ),
      outputTokens: _count(usage['output_tokens']),
      reasoningTokens: _nestedCount(
        usage['output_tokens_details'],
        'reasoning_tokens',
      ),
      totalTokens: _count(usage['total_tokens']),
    );
  }

  static int _count(Object? value) => value is int ? value : 0;

  static int _nestedCount(Object? details, String key) =>
      details is Map ? _count(details[key]) : 0;

  String _errorMessage(Map<String, dynamic> event) {
    final error = _errorEnvelope(event);
    if (error is Map && error['message'] is String) {
      return error['message'] as String;
    }
    return event['message'] as String? ??
        'OpenAI Responses API request failed.';
  }

  /// A failure the model context can no longer hold, or a plain adapter error.
  ///
  /// `response.failed` nests the envelope under `response`, while a bare
  /// `error` event carries it at the top level.
  Exception _streamFailure(Map<String, dynamic> event) {
    final message = _errorMessage(event);
    final envelope = _errorEnvelope(event);
    final code = envelope is Map && envelope['code'] is String
        ? envelope['code'] as String
        : null;
    if (isContextOverflowFailure(code, message)) {
      return ModelContextOverflowException(message);
    }
    return OpenAIProviderException(message);
  }

  Object? _errorEnvelope(Map<String, dynamic> event) {
    final direct = event['error'];
    if (direct is Map) return direct;
    final response = event['response'];
    if (response is Map && response['error'] is Map) return response['error'];
    return direct;
  }

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
