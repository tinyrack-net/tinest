import 'dart:typed_data';

import 'package:agent/agent.dart';
import 'package:daemon/src/features/providers/infrastructure/openai/openai.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  test('both OpenAI wires serialize every neutral role in order', () async {
    // The trailing repeat pins multi-system ordering: the standard driver
    // emits several consecutive system blocks ahead of history.
    const blocks = <ModelRoleBlock>[
      ModelRoleBlock(role: ModelRole.system, content: 'system-1'),
      ModelRoleBlock(role: ModelRole.system, content: 'system-2'),
      ModelRoleBlock(role: ModelRole.user, content: 'user-1'),
      ModelRoleBlock(role: ModelRole.assistant, content: 'assistant-1'),
      ModelRoleBlock(role: ModelRole.system, content: 'system-3'),
    ];
    const request = ModelRequest(
      model: 'gpt-5.6-sol',
      blocks: blocks,
      history: <ConversationItem>[],
      tools: <ModelToolDefinition>[],
    );
    final responsesAdapter = _RecordingAdapter('''
data: {"type":"response.completed","response":{"output":[],"usage":{}}}

data: [DONE]

''');
    await OpenAIResponsesProvider(
      _config(apiKey: 'secret-test-key'),
      dio: Dio()..httpClientAdapter = responsesAdapter,
    ).stream(request, CancellationToken()).toList();
    final responsesInput =
        Map<String, dynamic>.from(
              responsesAdapter.options!.data as Map,
            )['input']!
            as List;
    expect(
      responsesInput.map((item) => (item as Map)['role']),
      blocks.map((block) => block.role.name),
    );
    expect(
      responsesInput.map(
        (item) => (((item as Map)['content'] as List).single as Map)['text'],
      ),
      blocks.map((block) => block.content),
    );

    final chatAdapter = _RecordingAdapter('''
data: {"choices":[{"delta":{},"finish_reason":"stop"}]}

data: [DONE]

''');
    await OpenAIChatCompletionsProvider(
      _config(apiKey: 'secret-test-key'),
      dio: Dio()..httpClientAdapter = chatAdapter,
    ).stream(request, CancellationToken()).toList();
    final messages =
        Map<String, dynamic>.from(chatAdapter.options!.data as Map)['messages']!
            as List;
    expect(messages, <Map<String, dynamic>>[
      for (final block in blocks)
        <String, dynamic>{'role': block.role.name, 'content': block.content},
    ]);
    // The regression lock on the reported 400: this wire serves every
    // OpenAI-compatible vendor, and most accept only the classic roles.
    expect(
      messages.map((message) => (message as Map)['role']),
      everyElement(isIn(<String>['system', 'user', 'assistant'])),
    );
  });

  test(
    'Responses maps hydrated image and document attachments to content parts',
    tags: const <String>['feature_test__conversation_attachments__unit'],
    () async {
      final adapter = _RecordingAdapter('''
data: {"type":"response.completed","response":{"output":[{"type":"message","role":"assistant","content":[{"type":"output_text","text":"ok"}]}],"usage":{}}}

data: [DONE]

''');
      final dio = Dio()..httpClientAdapter = adapter;
      final provider = OpenAIResponsesProvider(
        _config(apiKey: 'secret-test-key'),
        dio: dio,
      );
      await provider
          .stream(
            ModelRequest(
              model: 'gpt-5.6-sol',
              modelControls: <String, AgentModelControlValue>{
                AgentModelControlIds.reasoningEffort:
                    const AgentModelControlStringValue(value: 'medium'),
              },
              blocks: const <ModelRoleBlock>[
                ModelRoleBlock(role: ModelRole.system, content: 'test'),
              ],
              history: <ConversationItem>[
                UserConversationItem(
                  'inspect these',
                  attachments: <ConversationAttachment>[
                    ConversationAttachment(
                      id: 'image',
                      fileName: 'diagram.png',
                      mimeType: 'image/png',
                      byteSize: 3,
                      path: '/attachments/image.blob',
                      bytes: Uint8List.fromList(<int>[1, 2, 3]),
                    ),
                    ConversationAttachment(
                      id: 'document',
                      fileName: 'notes.txt',
                      mimeType: 'text/plain',
                      byteSize: 2,
                      path: '/attachments/document.blob',
                      bytes: Uint8List.fromList(<int>[4, 5]),
                    ),
                    const ConversationAttachment(
                      id: 'archive',
                      fileName: 'source.zip',
                      mimeType: 'application/zip',
                      byteSize: 12,
                      path: '/attachments/archive.blob',
                    ),
                  ],
                ),
              ],
              tools: const <ModelToolDefinition>[],
            ),
            CancellationToken(),
          )
          .toList();

      final body = Map<String, dynamic>.from(adapter.options!.data as Map);
      final input = (body['input'] as List).last as Map;
      final content = input['content']! as List;
      expect(
        content,
        contains(
          equals(<String, dynamic>{
            'type': 'input_image',
            'image_url': 'data:image/png;base64,AQID',
            'detail': 'auto',
          }),
        ),
      );
      expect(
        content,
        contains(
          equals(<String, dynamic>{
            'type': 'input_text',
            'text':
                '[Attachment id=archive, file=source.zip, '
                'mime=application/zip, bytes=12, '
                'path=/attachments/archive.blob]',
          }),
        ),
      );
      expect(
        content,
        contains(
          equals(<String, dynamic>{
            'type': 'input_file',
            'filename': 'notes.txt',
            'file_data': 'data:text/plain;base64,BAU=',
          }),
        ),
      );
    },
  );

  test(
    'both APIs honour the requested image detail',
    tags: const <String>['feature_test__tool_image_context__unit'],
    () async {
      final history = <ConversationItem>[
        UserConversationItem(
          '',
          attachments: <ConversationAttachment>[
            ConversationAttachment(
              id: 'shot',
              fileName: 'shot.png',
              mimeType: 'image/png',
              byteSize: 3,
              path: '/attachments/shot.blob',
              bytes: Uint8List.fromList(<int>[1, 2, 3]),
              imageDetail: 'high',
            ),
          ],
        ),
      ];

      final responsesAdapter = _RecordingAdapter('''
data: {"type":"response.completed","response":{"output":[],"usage":{}}}

data: [DONE]

''');
      await OpenAIResponsesProvider(
            _config(apiKey: 'secret-test-key'),
            dio: Dio()..httpClientAdapter = responsesAdapter,
          )
          .stream(
            ModelRequest(
              model: 'gpt-5.6-sol',
              modelControls: <String, AgentModelControlValue>{
                AgentModelControlIds.reasoningEffort:
                    const AgentModelControlStringValue(value: 'medium'),
              },
              blocks: const <ModelRoleBlock>[
                ModelRoleBlock(role: ModelRole.system, content: 'test'),
              ],
              history: history,
              tools: const <ModelToolDefinition>[],
            ),
            CancellationToken(),
          )
          .toList();
      final responsesBody = Map<String, dynamic>.from(
        responsesAdapter.options!.data as Map,
      );
      expect(
        ((responsesBody['input'] as List).last as Map)['content'],
        contains(
          equals(<String, dynamic>{
            'type': 'input_image',
            'image_url': 'data:image/png;base64,AQID',
            'detail': 'high',
          }),
        ),
      );

      // Chat Completions carries the image as an array content part; a message
      // without images keeps the plain string form.
      final chatAdapter = _RecordingAdapter('''
data: {"choices":[{"delta":{},"finish_reason":"stop"}]}

data: [DONE]

''');
      await OpenAIChatCompletionsProvider(
            _config(apiKey: 'secret-test-key'),
            dio: Dio()..httpClientAdapter = chatAdapter,
          )
          .stream(
            ModelRequest(
              model: 'gpt-5.6-sol',
              modelControls: <String, AgentModelControlValue>{
                AgentModelControlIds.reasoningEffort:
                    const AgentModelControlStringValue(value: 'medium'),
              },
              blocks: <ModelRoleBlock>[
                const ModelRoleBlock(role: ModelRole.system, content: 'test'),
              ],
              history: <ConversationItem>[
                ...history,
                const UserConversationItem('plain text'),
              ],
              tools: const <ModelToolDefinition>[],
            ),
            CancellationToken(),
          )
          .toList();
      final chatBody = Map<String, dynamic>.from(
        chatAdapter.options!.data as Map,
      );
      final messages = (chatBody['messages'] as List)
          .cast<Map<String, dynamic>>()
          .where((message) => message['role'] == 'user')
          .toList(growable: false);
      expect(
        messages.first['content'],
        contains(
          equals(<String, dynamic>{
            'type': 'image_url',
            'image_url': <String, dynamic>{
              'url': 'data:image/png;base64,AQID',
              'detail': 'high',
            },
          }),
        ),
      );
      expect(messages.last['content'], 'plain text');
    },
  );

  test('Responses request is stateless, strict, sequential, '
      'and preserves output items', () async {
    final adapter = _RecordingAdapter('''
data: {"type":"response.reasoning_summary_text.delta","item_id":"rs-1","output_index":0,"summary_index":0,"delta":"Checking the request."}

data: {"type":"response.output_text.delta","delta":"hello"}

data: {"type":"response.completed","response":{"output":[{"type":"reasoning","encrypted_content":"opaque","summary":[{"type":"summary_text","text":"Checking the request."}]},{"type":"message","role":"assistant","content":[{"type":"output_text","text":"hello"}]}],"usage":{"input_tokens":2,"output_tokens":1}}}

data: [DONE]

''');
    final dio = Dio()..httpClientAdapter = adapter;
    final provider = OpenAIResponsesProvider(
      _config(apiKey: 'secret-test-key'),
      dio: dio,
    );
    final events = await provider
        .stream(
          const ModelRequest(
            model: 'gpt-5.6-sol',
            modelControls: <String, AgentModelControlValue>{
              AgentModelControlIds.reasoningEffort:
                  AgentModelControlStringValue(value: 'medium'),
            },
            blocks: <ModelRoleBlock>[
              ModelRoleBlock(role: ModelRole.system, content: 'test'),
            ],
            history: <ConversationItem>[],
            tools: <ModelToolDefinition>[
              ModelFunctionToolDefinition(
                name: 'read_file',
                description: 'read',
                parameters: <String, dynamic>{
                  'type': 'object',
                  'properties': <String, dynamic>{
                    'path': <String, dynamic>{'type': 'string'},
                  },
                  'required': <String>['path'],
                  'additionalProperties': false,
                },
              ),
            ],
          ),
          CancellationToken(),
        )
        .toList();

    final body = Map<String, dynamic>.from(adapter.options!.data as Map);
    expect(body['store'], isFalse);
    expect(body['stream'], isTrue);
    expect(body['parallel_tool_calls'], isFalse);
    expect(body['model'], 'gpt-5.6-sol');
    expect(body['reasoning'], <String, dynamic>{
      'effort': 'medium',
      'summary': 'auto',
    });
    expect(body['include'], contains('reasoning.encrypted_content'));
    expect((body['tools'] as List).single, containsPair('strict', true));
    expect(adapter.options!.headers['Authorization'], 'Bearer secret-test-key');
    expect(events.whereType<ModelTextDelta>().single.delta, 'hello');
    expect(
      events.whereType<ModelReasoningDelta>().single.delta,
      'Checking the request.',
    );
    final completed = events.whereType<ModelResponseCompleted>().single;
    expect(
      (completed.assistant.opaqueItems.first['item']!
          as Map)['encrypted_content'],
      'opaque',
    );
    expect(completed.usage.outputTokens, 1);
  });

  test(
    'both APIs normalize usage, including the nested detail counters',
    tags: const <String>['feature_test__tool_context_budget__unit'],
    () async {
      final responsesAdapter = _RecordingAdapter('''
data: {"type":"response.completed","response":{"output":[],"usage":{"input_tokens":120,"output_tokens":30,"total_tokens":150,"input_tokens_details":{"cached_tokens":80},"output_tokens_details":{"reasoning_tokens":12}}}}

data: [DONE]

''');
      final responses = await OpenAIResponsesProvider(
        _config(apiKey: 'secret-test-key'),
        dio: Dio()..httpClientAdapter = responsesAdapter,
      ).stream(_request(), CancellationToken()).toList();
      final responsesUsage = responses
          .whereType<ModelResponseCompleted>()
          .single
          .usage;

      expect(responsesUsage.inputTokens, 120);
      expect(responsesUsage.outputTokens, 30);
      expect(responsesUsage.totalTokens, 150);
      // The nested detail maps were silently dropped before normalization.
      expect(responsesUsage.cachedInputTokens, 80);
      expect(responsesUsage.reasoningTokens, 12);
      expect(responsesUsage.contextTokens, 150);

      final chatAdapter = _RecordingAdapter('''
data: {"choices":[],"usage":{"prompt_tokens":90,"completion_tokens":10,"total_tokens":100,"prompt_tokens_details":{"cached_tokens":40},"completion_tokens_details":{"reasoning_tokens":6}}}

data: [DONE]

''');
      final chat = await OpenAIChatCompletionsProvider(
        _config(apiKey: 'secret-test-key'),
        dio: Dio()..httpClientAdapter = chatAdapter,
      ).stream(_request(), CancellationToken()).toList();
      final chatUsage = chat.whereType<ModelResponseCompleted>().single.usage;

      // The two APIs spell every counter differently; the agent sees one shape.
      expect(chatUsage.inputTokens, 90);
      expect(chatUsage.outputTokens, 10);
      expect(chatUsage.totalTokens, 100);
      expect(chatUsage.cachedInputTokens, 40);
      expect(chatUsage.reasoningTokens, 6);

      // A response without usage reports zeroes, never null.
      final emptyAdapter = _RecordingAdapter('''
data: {"type":"response.completed","response":{"output":[],"usage":{}}}

data: [DONE]

''');
      final empty = await OpenAIResponsesProvider(
        _config(apiKey: 'secret-test-key'),
        dio: Dio()..httpClientAdapter = emptyAdapter,
      ).stream(_request(), CancellationToken()).toList();
      final emptyUsage = empty.whereType<ModelResponseCompleted>().single.usage;
      expect(emptyUsage.contextTokens, 0);
      expect(emptyUsage.isEmpty, isTrue);
    },
  );

  test('the service tier is sent only when the model supports it', () async {
    Future<Map<String, dynamic>> body({
      required bool supportsServiceTier,
      required String? serviceTier,
    }) async {
      final adapter = _RecordingAdapter('''
data: {"type":"response.completed","response":{"output":[],"usage":{}}}

data: [DONE]

''');
      final provider = OpenAIResponsesProvider(
        _config(
          apiKey: 'secret-test-key',
          extensions: supportsServiceTier
              ? const <ProviderEndpointExtension>{
                  ProviderEndpointExtension.expeditedProcessing,
                }
              : const <ProviderEndpointExtension>{},
        ),
        dio: Dio()..httpClientAdapter = adapter,
      );
      await provider
          .stream(
            ModelRequest(
              model: 'gpt-5.6-sol',
              modelControls: <String, AgentModelControlValue>{
                AgentModelControlIds.reasoningEffort:
                    const AgentModelControlStringValue(value: 'medium'),
                if (serviceTier == 'priority')
                  AgentModelControlIds.fastMode:
                      const AgentModelControlBoolValue(value: true),
              },
              blocks: <ModelRoleBlock>[
                const ModelRoleBlock(role: ModelRole.system, content: 'test'),
              ],
              history: const <ConversationItem>[],
              tools: const <ModelToolDefinition>[],
            ),
            CancellationToken(),
          )
          .toList();
      return Map<String, dynamic>.from(adapter.options!.data as Map);
    }

    expect(
      await body(supportsServiceTier: true, serviceTier: 'priority'),
      containsPair('service_tier', 'priority'),
    );
    // An unsupported model must never receive the field, because endpoints
    // that do not know it reject the whole request.
    expect(
      await body(supportsServiceTier: false, serviceTier: 'priority'),
      isNot(contains('service_tier')),
    );
    expect(
      await body(supportsServiceTier: true, serviceTier: null),
      isNot(contains('service_tier')),
    );
  });

  test('an empty API key fails before opening a connection', () async {
    final provider = OpenAIResponsesProvider(_config());
    expect(
      provider
          .stream(
            const ModelRequest(
              model: 'gpt-5.6-sol',
              modelControls: <String, AgentModelControlValue>{
                AgentModelControlIds.reasoningEffort:
                    AgentModelControlStringValue(value: 'medium'),
              },
              blocks: <ModelRoleBlock>[
                ModelRoleBlock(role: ModelRole.system, content: 'test'),
              ],
              history: <ConversationItem>[],
              tools: <ModelToolDefinition>[],
            ),
            CancellationToken(),
          )
          .toList(),
      throwsA(isA<OpenAIProviderException>()),
    );
  });

  test('Chat Completions assembles text and fragmented tool calls', () async {
    final adapter = _RecordingAdapter(r'''
data: {"choices":[{"index":0,"delta":{"content":"hello "}}]}

data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"call-1","function":{"name":"read_","arguments":"{\"path\":"}}]}}]}

data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"name":"file","arguments":"\"README.md\"}"}}]},"finish_reason":"tool_calls"}]}

data: {"choices":[],"usage":{"prompt_tokens":4,"completion_tokens":3,"total_tokens":7}}

data: [DONE]

''');
    final dio = Dio()..httpClientAdapter = adapter;
    final provider = OpenAIChatCompletionsProvider(
      _config(
        id: 'compatible',
        requiresApiKey: false,
        supportsReasoningEffort: false,
        extensions: const <ProviderEndpointExtension>{},
      ),
      dio: dio,
    );
    final events = await provider
        .stream(
          const ModelRequest(
            model: 'local-model',
            modelControls: <String, AgentModelControlValue>{
              AgentModelControlIds.reasoningEffort:
                  AgentModelControlStringValue(value: 'medium'),
            },
            blocks: <ModelRoleBlock>[
              ModelRoleBlock(role: ModelRole.system, content: 'test'),
            ],
            history: <ConversationItem>[
              UserConversationItem('inspect'),
              AssistantConversationItem(text: 'earlier'),
            ],
            tools: <ModelToolDefinition>[
              ModelFunctionToolDefinition(
                name: 'read_file',
                description: 'read',
                parameters: <String, dynamic>{
                  'type': 'object',
                  'properties': <String, dynamic>{
                    'path': <String, dynamic>{'type': 'string'},
                  },
                  'required': <String>['path'],
                  'additionalProperties': false,
                },
              ),
            ],
          ),
          CancellationToken(),
        )
        .toList();

    final body = Map<String, dynamic>.from(adapter.options!.data as Map);
    expect(body['stream'], isTrue);
    expect(body, isNot(contains('reasoning_effort')));
    expect((body['messages'] as List)[1], <String, dynamic>{
      'role': 'user',
      'content': 'inspect',
    });
    expect(events.whereType<ModelTextDelta>().single.delta, 'hello ');
    final call = events.whereType<ModelFunctionCall>().single;
    expect(call.name, 'read_file');
    expect(call.arguments, <String, dynamic>{'path': 'README.md'});
    final completed = events.whereType<ModelResponseCompleted>().single;
    expect(completed.assistant.toolCalls.single.callId, 'call-1');
    expect(completed.usage.totalTokens, 7);
  });

  test('an endpoint that has not stated it inlines documents gets text', () {
    // The accepted media types and the size ceiling are one platform's
    // documented limits. An endpoint that has not claimed them is described
    // the attachment in text, which every endpoint understands.
    final adapter = _RecordingAdapter('''
data: {"type":"response.completed","response":{"output":[],"usage":{}}}

data: [DONE]

''');
    return OpenAIResponsesProvider(
          _config(
            apiKey: 'secret-test-key',
            extensions: const <ProviderEndpointExtension>{},
          ),
          dio: Dio()..httpClientAdapter = adapter,
        )
        .stream(_request(history: _documentHistory), CancellationToken())
        .toList()
        .then((_) {
          final input =
              Map<String, dynamic>.from(adapter.options!.data as Map)['input']!
                  as List;
          final content = (input.last as Map)['content']! as List;
          expect(
            content,
            everyElement(isNot(containsPair('type', 'input_file'))),
          );
          expect(
            content,
            contains(
              allOf(
                containsPair('type', 'input_text'),
                containsPair('text', contains('notes.txt')),
              ),
            ),
          );
        });
  });

  test('Responses replays only its own opaque items', () async {
    final adapter = _RecordingAdapter('''
data: {"type":"response.completed","response":{"output":[{"type":"reasoning","id":"rs_1","encrypted_content":"blob"}],"usage":{}}}

data: [DONE]

''');
    final events = await OpenAIResponsesProvider(
      _config(apiKey: 'secret-test-key'),
      dio: Dio()..httpClientAdapter = adapter,
    ).stream(_request(), CancellationToken()).toList();
    final assistant = events
        .whereType<ModelResponseCompleted>()
        .single
        .assistant;
    // Written tagged, like every other transport, so a later turn can tell
    // whose continuation state it is holding.
    expect(assistant.opaqueItems.single['provider'], 'openai');

    final replayAdapter = _RecordingAdapter('''
data: {"type":"response.completed","response":{"output":[],"usage":{}}}

data: [DONE]

''');
    await OpenAIResponsesProvider(
          _config(apiKey: 'secret-test-key'),
          dio: Dio()..httpClientAdapter = replayAdapter,
        )
        .stream(
          _request(
            history: <ConversationItem>[
              AssistantConversationItem(
                text: 'earlier',
                opaqueItems: <Map<String, dynamic>>[
                  ...assistant.opaqueItems,
                  // A session that switched providers carries the other
                  // transport's state, which this API cannot decode.
                  const <String, dynamic>{
                    'provider': 'anthropic',
                    'block': <String, dynamic>{'type': 'thinking'},
                  },
                ],
              ),
            ],
          ),
          CancellationToken(),
        )
        .toList();

    final input =
        Map<String, dynamic>.from(replayAdapter.options!.data as Map)['input']!
            as List;
    expect(input, contains(containsPair('encrypted_content', 'blob')));
    expect(input, everyElement(isNot(contains('provider'))));
    expect(input, everyElement(isNot(contains('block'))));
  });

  test('strict schemas are sent only where the endpoint takes them', () async {
    const tools = <ModelToolDefinition>[
      ModelFunctionToolDefinition(
        name: 'read_file',
        description: 'read',
        parameters: <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{},
          'required': <String>[],
          'additionalProperties': false,
        },
      ),
      ModelFunctionToolDefinition(
        name: 'mcp__github__create_issue',
        description: 'create an issue',
        parameters: <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'title': <String, dynamic>{'type': 'string'},
            'body': <String, dynamic>{'type': 'string'},
          },
          'required': <String>['title'],
        },
      ),
    ];
    const responsesFixture = '''
data: {"type":"response.completed","response":{"output":[],"usage":{}}}

data: [DONE]

''';

    final responsesAdapter = _RecordingAdapter(responsesFixture);
    await OpenAIResponsesProvider(
      _config(apiKey: 'secret-test-key'),
      dio: Dio()..httpClientAdapter = responsesAdapter,
    ).stream(_request(tools: tools), CancellationToken()).toList();
    final responsesBody = Map<String, dynamic>.from(
      responsesAdapter.options!.data as Map,
    );
    final responsesTools = responsesBody['tools']! as List;
    expect(responsesTools, everyElement(containsPair('strict', true)));

    // A compatible endpoint has not stated that it validates strictly, so it
    // is told the schemas are ordinary rather than being sent a promise it
    // may reject.
    final compatibleAdapter = _RecordingAdapter(responsesFixture);
    await OpenAIResponsesProvider(
      _config(
        apiKey: 'secret-test-key',
        extensions: const <ProviderEndpointExtension>{},
      ),
      dio: Dio()..httpClientAdapter = compatibleAdapter,
    ).stream(_request(tools: tools), CancellationToken()).toList();
    expect(
      Map<String, dynamic>.from(
            compatibleAdapter.options!.data as Map,
          )['tools']!
          as List,
      everyElement(containsPair('strict', false)),
    );

    final chatAdapter = _RecordingAdapter('''
data: {"choices":[{"index":0,"delta":{"content":"hi"},"finish_reason":"stop"}]}

data: {"choices":[],"usage":{"total_tokens":1}}

data: [DONE]

''');
    await OpenAIChatCompletionsProvider(
      _config(apiKey: 'secret-test-key'),
      dio: Dio()..httpClientAdapter = chatAdapter,
    ).stream(_request(tools: tools), CancellationToken()).toList();
    final chatBody = Map<String, dynamic>.from(
      chatAdapter.options!.data as Map,
    );
    final chatTools = chatBody['tools']! as List;
    expect(
      chatTools.map((tool) => (tool as Map)['function']),
      everyElement(containsPair('strict', true)),
    );

    final compatibleChat = _RecordingAdapter('''
data: {"choices":[{"index":0,"delta":{"content":"hi"},"finish_reason":"stop"}]}

data: [DONE]

''');
    await OpenAIChatCompletionsProvider(
      _config(
        apiKey: 'secret-test-key',
        extensions: const <ProviderEndpointExtension>{},
      ),
      dio: Dio()..httpClientAdapter = compatibleChat,
    ).stream(_request(tools: tools), CancellationToken()).toList();
    expect(
      (Map<String, dynamic>.from(compatibleChat.options!.data as Map)['tools']!
              as List)
          .map((tool) => (tool as Map)['function']),
      everyElement(isNot(contains('strict'))),
    );
  });

  test('Responses sends patch tools over the function surface', () async {
    final adapter = _RecordingAdapter(r'''
data: {"type":"response.output_item.done","item":{"type":"function_call","call_id":"call-patch","name":"apply_patch","arguments":"{\"patch\":\"*** Begin Patch\\n*** End Patch\"}"}}

data: {"type":"response.completed","response":{"output":[{"type":"function_call","call_id":"call-patch","name":"apply_patch","arguments":"{\"patch\":\"*** Begin Patch\\n*** End Patch\"}"}],"usage":{}}}

data: [DONE]

''');
    final events =
        await OpenAIResponsesProvider(
              _config(apiKey: 'secret-test-key'),
              dio: Dio()..httpClientAdapter = adapter,
            )
            .stream(
              _request(
                history: const <ConversationItem>[
                  ToolResultConversationItem(
                    callId: 'earlier-patch',
                    output: 'Done!',
                    toolKind: ModelToolKind.function,
                  ),
                ],
                tools: const <ModelToolDefinition>[
                  ModelFunctionToolDefinition(
                    name: 'apply_patch',
                    description: 'Patch files.',
                    parameters: <String, dynamic>{
                      'type': 'object',
                      'properties': <String, dynamic>{
                        'patch': <String, dynamic>{'type': 'string'},
                      },
                      'required': <String>['patch'],
                    },
                  ),
                ],
              ),
              CancellationToken(),
            )
            .toList();

    final body = Map<String, dynamic>.from(adapter.options!.data as Map);
    // Concurrency is an endpoint fact. No endpoint states it yet, so every
    // request declares sibling calls run one at a time, as before.
    expect(body['parallel_tool_calls'], isFalse);
    expect((body['tools'] as List).single, <String, dynamic>{
      'type': 'function',
      'name': 'apply_patch',
      'description': 'Patch files.',
      'parameters': <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'patch': <String, dynamic>{'type': 'string'},
        },
        'required': <String>['patch'],
      },
      'strict': true,
    });
    expect((body['input'] as List).last, <String, dynamic>{
      'type': 'function_call_output',
      'call_id': 'earlier-patch',
      'output': 'Done!',
    });
    final call = events.whereType<ModelFunctionCall>().single;
    expect(call.name, 'apply_patch');
    expect(call.arguments['patch'], '*** Begin Patch\n*** End Patch');
    final completed = events.whereType<ModelResponseCompleted>().single;
    expect(
      completed.assistant.toolCalls.single.arguments['patch'],
      '*** Begin Patch\n*** End Patch',
    );
  });

  test(
    'Responses preserves native deferred-search calls and outputs',
    () async {
      final adapter = _RecordingAdapter('''
data: {"type":"response.output_item.done","item":{"type":"tool_search_call","call_id":"search-1","execution":"client","arguments":{"query":"calendar","limit":1}}}

data: {"type":"response.completed","response":{"output":[{"type":"tool_search_call","call_id":"search-1","execution":"client","arguments":{"query":"calendar","limit":1}}],"usage":{}}}

data: [DONE]

''');
      final events =
          await OpenAIResponsesProvider(
                _config(apiKey: 'secret-test-key'),
                dio: Dio()..httpClientAdapter = adapter,
              )
              .stream(
                _request(
                  history: const <ConversationItem>[
                    ToolResultConversationItem(
                      callId: 'search-0',
                      output:
                          '{"tools":[{"type":"function","name":"calendar"}]}',
                      toolKind: ModelToolKind.deferredSearch,
                    ),
                  ],
                  tools: const <ModelToolDefinition>[
                    ModelDeferredSearchToolDefinition(
                      name: 'discover_tools',
                      description: 'Discover deferred tools.',
                      parameters: <String, dynamic>{'type': 'object'},
                    ),
                  ],
                ),
                CancellationToken(),
              )
              .toList();

      final body = Map<String, dynamic>.from(adapter.options!.data as Map);
      expect((body['tools'] as List).single, <String, dynamic>{
        'type': 'tool_search',
        'execution': 'client',
        'description': 'Discover deferred tools.',
        'parameters': <String, dynamic>{'type': 'object'},
      });
      expect((body['input'] as List).last, <String, dynamic>{
        'type': 'tool_search_output',
        'call_id': 'search-0',
        'status': 'completed',
        'execution': 'client',
        'tools': <Object?>[
          <String, Object?>{'type': 'function', 'name': 'calendar'},
        ],
      });
      expect(
        events.whereType<ModelDeferredSearchCall>().single.arguments,
        <String, dynamic>{'query': 'calendar', 'limit': 1},
      );
      expect(
        events.whereType<ModelDeferredSearchCall>().single.name,
        'discover_tools',
      );
      final completed = events.whereType<ModelResponseCompleted>().single;
      expect(completed.assistant.toolCalls.single.name, 'discover_tools');
      expect(
        completed.assistant.toolCalls.single.kind,
        ModelToolKind.deferredSearch,
      );
    },
  );

  test(
    'Responses preserves namespace declarations and qualified calls',
    () async {
      final adapter = _RecordingAdapter('''
data: {"type":"response.output_item.done","item":{"type":"function_call","call_id":"clock-call","namespace":"clock","name":"curr_time","arguments":"{}"}}

data: {"type":"response.completed","response":{"output":[{"type":"function_call","call_id":"clock-call","namespace":"clock","name":"curr_time","arguments":"{}"}],"usage":{}}}

data: [DONE]

''');
      final events =
          await OpenAIResponsesProvider(
                _config(apiKey: 'secret-test-key'),
                dio: Dio()..httpClientAdapter = adapter,
              )
              .stream(
                _request(
                  history: const <ConversationItem>[
                    AssistantConversationItem(
                      text: '',
                      toolCalls: <ConversationToolCall>[
                        ConversationToolCall.function(
                          callId: 'old-clock',
                          name: 'clock__curr_time',
                          namespace: 'clock',
                          arguments: <String, dynamic>{},
                        ),
                      ],
                    ),
                    ToolResultConversationItem(
                      callId: 'old-clock',
                      output: 'now',
                      toolKind: ModelToolKind.function,
                      content: <ToolContent>[
                        ToolTextContent('now'),
                        ToolImageContent(
                          imageUrl: 'data:image/png;base64,AA==',
                        ),
                        ToolAudioContent(
                          audioUrl: 'data:audio/wav;base64,AA==',
                        ),
                      ],
                    ),
                  ],
                  tools: const <ModelToolDefinition>[
                    ModelNamespaceToolDefinition(
                      name: 'clock',
                      description: 'Clock tools.',
                      tools: <ModelFunctionToolDefinition>[
                        ModelFunctionToolDefinition(
                          name: 'curr_time',
                          description: 'Current time.',
                          parameters: <String, dynamic>{'type': 'object'},
                        ),
                      ],
                    ),
                  ],
                ),
                CancellationToken(),
              )
              .toList();

      final body = Map<String, dynamic>.from(adapter.options!.data as Map);
      expect((body['tools'] as List).single, containsPair('type', 'namespace'));
      expect((body['input'] as List)[1], containsPair('namespace', 'clock'));
      expect(
        ((body['input'] as List)[2] as Map)['output'],
        <Map<String, dynamic>>[
          <String, dynamic>{'type': 'input_text', 'text': 'now'},
          <String, dynamic>{
            'type': 'input_image',
            'image_url': 'data:image/png;base64,AA==',
          },
          <String, dynamic>{
            'type': 'input_audio',
            'audio_url': 'data:audio/wav;base64,AA==',
          },
        ],
      );
      final call = events.whereType<ModelFunctionCall>().single;
      expect(call.name, 'clock__curr_time');
      expect(call.namespace, 'clock');
      final completed = events.whereType<ModelResponseCompleted>().single;
      expect(completed.assistant.toolCalls.single.namespace, 'clock');
    },
  );

  test('Chat Completions rejects a truncated SSE response', () async {
    final adapter = _RecordingAdapter('''
data: {"choices":[{"index":0,"delta":{"content":"partial"}}]}

''');
    final dio = Dio()..httpClientAdapter = adapter;
    final provider = OpenAIChatCompletionsProvider(
      _config(requiresApiKey: false),
      dio: dio,
    );
    expect(
      provider
          .stream(
            const ModelRequest(
              model: 'local-model',
              modelControls: <String, AgentModelControlValue>{
                AgentModelControlIds.reasoningEffort:
                    AgentModelControlStringValue(value: 'medium'),
              },
              blocks: <ModelRoleBlock>[
                ModelRoleBlock(role: ModelRole.system, content: 'test'),
              ],
              history: <ConversationItem>[],
              tools: <ModelToolDefinition>[],
            ),
            CancellationToken(),
          )
          .toList(),
      throwsA(isA<OpenAIProviderException>()),
    );
  });

  test(
    'Responses maps canonical history, forced tools, and function calls',
    () async {
      final adapter = _RecordingAdapter(r'''
event: response.output_item.done
data: {"item":{"type":"function_call","call_id":"call-2","name":"write_file","arguments":"{\"path\":\"a.txt\"}"}}

data: {"type":"response.completed","response":{"output":[{"type":"function_call","call_id":"call-2","name":"write_file","arguments":"{\"path\":\"a.txt\"}"},{"type":"message","content":[{"type":"refusal","text":"ignored"},{"type":"output_text","text":"done"}]},{"type":"future_state","opaque":"value"}],"usage":{"input_tokens":3,"label":"ignored"}}}

data: [DONE]

''');
      final dio = Dio()..httpClientAdapter = adapter;
      final provider = OpenAIResponsesProvider(
        _config(
          id: 'compatible-responses',
          requiresApiKey: false,
          supportsReasoningEffort: false,
          extensions: const <ProviderEndpointExtension>{},
        ),
        dio: dio,
      );
      final events = await provider
          .stream(
            _request(
              forceToolName: 'write_file',
              history: const <ConversationItem>[
                UserConversationItem('inspect'),
                AssistantConversationItem(
                  text: 'earlier',
                  toolCalls: <ConversationToolCall>[
                    ConversationToolCall.function(
                      callId: 'call-1',
                      name: 'read_file',
                      arguments: <String, dynamic>{'path': 'a.txt'},
                    ),
                  ],
                  opaqueItems: <Map<String, dynamic>>[
                    <String, dynamic>{
                      'provider': 'openai',
                      'item': <String, dynamic>{
                        'type': 'reasoning',
                        'opaque': true,
                      },
                    },
                  ],
                ),
                ToolResultConversationItem(
                  callId: 'call-1',
                  output: 'content',
                  toolKind: ModelToolKind.function,
                ),
              ],
            ),
            CancellationToken(),
          )
          .toList();

      final body = Map<String, dynamic>.from(adapter.options!.data as Map);
      expect(body, isNot(contains('reasoning')));
      expect(body['tool_choice'], <String, dynamic>{
        'type': 'function',
        'name': 'write_file',
      });
      expect(adapter.options!.headers, isNot(contains('Authorization')));
      final input = body['input']! as List<dynamic>;
      expect(
        input.map((item) => (item as Map<String, dynamic>)['type']),
        <Object?>[
          'message',
          null,
          'reasoning',
          'message',
          'function_call',
          'function_call_output',
        ],
      );
      expect(events.whereType<ModelFunctionCall>(), hasLength(1));
      final completed = events.whereType<ModelResponseCompleted>().single;
      expect(completed.assistant.text, 'done');
      expect(completed.assistant.toolCalls.single.name, 'write_file');
      expect(
        (completed.assistant.opaqueItems.single['item']! as Map)['opaque'],
        'value',
      );
      // A non-numeric counter the provider slipped in is ignored, not copied.
      expect(completed.usage.inputTokens, 3);
      expect(completed.usage.outputTokens, 0);
      expect(provider.id, 'compatible-responses');
    },
  );

  test('Responses normalizes semantic failures and malformed calls', () async {
    for (final fixture in <String>[
      'data: {"type":"response.completed"}\n\n',
      'data: {"type":"response.failed","error":{"message":"failed"}}\n\n',
      'data: {"type":"error","message":"top-level"}\n\n',
      <String>[
        'data: {"type":"response.output_item.done","item":',
        '{"type":"function_call","call_id":"call","name":"tool",',
        '"arguments":"[]"}}\n\n',
      ].join(),
    ]) {
      final dio = Dio()..httpClientAdapter = _RecordingAdapter(fixture);
      final provider = OpenAIResponsesProvider(
        _config(requiresApiKey: false),
        dio: dio,
      );
      await expectLater(
        provider.stream(_request(), CancellationToken()).toList(),
        throwsA(isA<OpenAIProviderException>()),
      );
    }
  });

  test('Responses retries only transient connection setup failures', () async {
    final retrying = _SequenceAdapter(
      failures: 1,
      type: DioExceptionType.connectionError,
      statusCode: 429,
      fixture:
          'data: {"type":"response.completed","response":{"output":[]}}\n\n',
    );
    final retryDio = Dio()..httpClientAdapter = retrying;
    final provider = OpenAIResponsesProvider(
      _config(requiresApiKey: false),
      dio: retryDio,
    );
    expect(
      await provider.stream(_request(), CancellationToken()).toList(),
      hasLength(1),
    );
    expect(retrying.calls, 2);

    final failing = _SequenceAdapter(
      failures: 1,
      type: DioExceptionType.badResponse,
      statusCode: 400,
      fixture: '',
    );
    final failingDio = Dio()..httpClientAdapter = failing;
    await expectLater(
      OpenAIResponsesProvider(
        _config(requiresApiKey: false, maxConnectAttempts: 1),
        dio: failingDio,
      ).stream(_request(), CancellationToken()).toList(),
      throwsA(isA<OpenAIProviderException>()),
    );
  });

  test('both adapters report the words of a rejected stream', () async {
    // Dio never decodes the body of a streaming response, so the adapters have
    // to drain it themselves or the server's own explanation is lost.
    const payload =
        '{"error":{"message":"Unsupported parameter: \'service_tier\'.", '
        '"type":"invalid_request_error","param":"service_tier"}}';
    for (final build in <ModelGateway Function(Dio)>[
      (dio) => OpenAIResponsesProvider(
        _config(requiresApiKey: false, maxConnectAttempts: 1),
        dio: dio,
      ),
      (dio) => OpenAIChatCompletionsProvider(
        _config(requiresApiKey: false),
        dio: dio,
      ),
    ]) {
      final dio = Dio()..httpClientAdapter = _StreamedStatusAdapter(payload);
      await expectLater(
        build(dio).stream(_request(), CancellationToken()).toList(),
        throwsA(
          isA<OpenAIProviderException>()
              .having(
                (error) => error.message,
                'message',
                contains("Unsupported parameter: 'service_tier'."),
              )
              .having((error) => error.message, 'status', contains('400')),
        ),
      );
    }
  });

  test('a streamed overflow rejection is classified from its body', () async {
    final dio = Dio()
      ..httpClientAdapter = _StreamedStatusAdapter(
        '{"error":{"code":"context_length_exceeded",'
        '"message":"Your input exceeds the context window."}}',
      );
    await expectLater(
      OpenAIResponsesProvider(
        _config(requiresApiKey: false, maxConnectAttempts: 1),
        dio: dio,
      ).stream(_request(), CancellationToken()).toList(),
      throwsA(isA<ModelContextOverflowException>()),
    );
  });

  test('the safety identifier is sent only where it is known', () async {
    Future<Map<String, dynamic>> body({required bool accepted}) async {
      final adapter = _RecordingAdapter(
        'data: {"type":"response.completed","response":{"output":[]}}\n\n',
      );
      await OpenAIResponsesProvider(
        _config(
          requiresApiKey: false,
          extensions: accepted
              ? const <ProviderEndpointExtension>{
                  ProviderEndpointExtension.requestAttribution,
                }
              : const <ProviderEndpointExtension>{},
        ),
        dio: Dio()..httpClientAdapter = adapter,
      ).stream(_request(), CancellationToken()).toList();
      return Map<String, dynamic>.from(adapter.options!.data as Map);
    }

    expect(
      await body(accepted: true),
      containsPair('safety_identifier', 'safe'),
    );
    // Every endpoint that has not stated it defines the field rejects the
    // whole request when it carries one.
    expect(await body(accepted: false), isNot(contains('safety_identifier')));
  });

  test('Responses retries without an unavailable reasoning summary', () async {
    final adapter = _ReasoningSummaryFallbackAdapter();
    final events = await OpenAIResponsesProvider(
      _config(requiresApiKey: false),
      dio: Dio()..httpClientAdapter = adapter,
    ).stream(_request(), CancellationToken()).toList();

    expect(adapter.bodies, hasLength(2));
    expect(adapter.bodies.first['reasoning'], containsPair('summary', 'auto'));
    expect(adapter.bodies.last['reasoning'], isNot(contains('summary')));
    expect(events.whereType<ModelTextDelta>().single.delta, 'ok');
  });

  test('both adapters translate transport cancellation', () async {
    for (final providerFactory in <ModelGateway Function(Dio)>[
      (dio) =>
          OpenAIResponsesProvider(_config(requiresApiKey: false), dio: dio),
      (dio) => OpenAIChatCompletionsProvider(
        _config(requiresApiKey: false),
        dio: dio,
      ),
    ]) {
      final dio = Dio()..httpClientAdapter = _CancelAdapter();
      final token = CancellationToken();
      final events = providerFactory(dio).stream(_request(), token).toList();
      await Future<void>.delayed(Duration.zero);
      token.cancel();
      await expectLater(events, throwsA(isA<AgentCancelledException>()));
    }
  });

  test(
    'Chat Completions normalizes structured and string reasoning deltas',
    () async {
      final adapter = _RecordingAdapter('''
data: {"choices":[{"delta":{"reasoning_details":[{"type":"reasoning.summary","summary":"Structured "},{"type":"reasoning.text","text":"reasoning."}]}}]}

data: {"choices":[{"delta":{"reasoning_content":"Fallback content"}}]}

data: {"choices":[{"delta":{"reasoning":"Fallback reasoning"}}]}

data: {"choices":[{"delta":{"content":"answer"}}]}

data: [DONE]

''');
      final events = await OpenAIChatCompletionsProvider(
        _config(apiKey: 'key'),
        dio: Dio()..httpClientAdapter = adapter,
      ).stream(_request(), CancellationToken()).toList();

      expect(
        events.whereType<ModelReasoningDelta>().map((event) => event.delta),
        <String>[
          'Structured ',
          'reasoning.',
          'Fallback content',
          'Fallback reasoning',
        ],
      );
      expect(events.whereType<ModelTextDelta>().single.delta, 'answer');
    },
  );

  test(
    'Chat Completions maps all canonical messages and forced tools',
    () async {
      final adapter = _RecordingAdapter(
        'data: {"choices":[]}\n\ndata: [DONE]\n\n',
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final provider = OpenAIChatCompletionsProvider(
        _config(apiKey: 'key'),
        dio: dio,
      );
      final events = await provider
          .stream(
            _request(
              forceToolName: 'read_file',
              history: const <ConversationItem>[
                UserConversationItem('user'),
                AssistantConversationItem(
                  text: '',
                  toolCalls: <ConversationToolCall>[
                    ConversationToolCall.function(
                      callId: 'call',
                      name: 'read_file',
                      arguments: <String, dynamic>{'path': 'a'},
                    ),
                  ],
                ),
                ToolResultConversationItem(
                  callId: 'call',
                  output: 'value',
                  toolKind: ModelToolKind.function,
                ),
              ],
            ),
            CancellationToken(),
          )
          .toList();
      final body = Map<String, dynamic>.from(adapter.options!.data as Map);
      expect(body['reasoning_effort'], 'medium');
      expect(body['tool_choice'], isA<Map<String, dynamic>>());
      expect(body['messages'], hasLength(4));
      expect((body['tools'] as List<dynamic>).single, contains('function'));
      expect(events.single, isA<ModelResponseCompleted>());
      expect(provider.id, 'openai');
    },
  );

  test(
    'Chat Completions validates credentials, calls, and Dio errors',
    () async {
      await expectLater(
        OpenAIChatCompletionsProvider(_config())
            .stream(_request(), CancellationToken())
            .toList(),
        throwsA(isA<OpenAIProviderException>()),
      );

      final malformed = Dio()
        ..httpClientAdapter = _RecordingAdapter('''
data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"","function":{"name":"","arguments":"[]"}}]}}]}

data: [DONE]

''');
      await expectLater(
        OpenAIChatCompletionsProvider(
          _config(requiresApiKey: false),
          dio: malformed,
        ).stream(_request(), CancellationToken()).toList(),
        throwsA(isA<OpenAIProviderException>()),
      );

      final errorAdapter = _SequenceAdapter(
        failures: 1,
        type: DioExceptionType.connectionTimeout,
        statusCode: 503,
        fixture: '',
      );
      final errorDio = Dio()..httpClientAdapter = errorAdapter;
      await expectLater(
        OpenAIChatCompletionsProvider(
          _config(requiresApiKey: false),
          dio: errorDio,
        ).stream(_request(), CancellationToken()).toList(),
        throwsA(
          isA<OpenAIProviderException>().having(
            (error) => error.retryable,
            'retryable',
            isTrue,
          ),
        ),
      );
    },
  );

  test(
    'both adapters classify a context overflow refusal',
    tags: const <String>['feature_test__context_compaction__unit'],
    () async {
      final streamed = Dio()
        ..httpClientAdapter = _RecordingAdapter('''
data: {"type":"response.failed","response":{"error":{"code":"context_length_exceeded","message":"Your input exceeds the context window."}}}

''');
      await expectLater(
        OpenAIResponsesProvider(
          _config(requiresApiKey: false),
          dio: streamed,
        ).stream(_request(), CancellationToken()).toList(),
        throwsA(isA<ModelContextOverflowException>()),
      );

      final rejected = Dio()
        ..httpClientAdapter = _BadRequestAdapter(<String, dynamic>{
          'error': <String, dynamic>{
            'code': 'context_length_exceeded',
            'message': 'maximum context length is 128000 tokens',
          },
        });
      await expectLater(
        OpenAIChatCompletionsProvider(
          _config(requiresApiKey: false),
          dio: rejected,
        ).stream(_request(), CancellationToken()).toList(),
        throwsA(isA<ModelContextOverflowException>()),
      );

      // A Responses 400 that is not about the window must stay a plain
      // transport failure so the turn still reports the provider's own words.
      final unrelated = Dio()
        ..httpClientAdapter = _BadRequestAdapter(<String, dynamic>{
          'error': <String, dynamic>{'code': 'invalid_api_key'},
        });
      await expectLater(
        OpenAIResponsesProvider(
          _config(requiresApiKey: false, maxConnectAttempts: 1),
          dio: unrelated,
        ).stream(_request(), CancellationToken()).toList(),
        throwsA(isNot(isA<ModelContextOverflowException>())),
      );
    },
  );
}

ModelRequest _request({
  List<ConversationItem> history = const <ConversationItem>[],
  String? forceToolName,
  List<ModelToolDefinition> tools = const <ModelToolDefinition>[
    ModelFunctionToolDefinition(
      name: 'read_file',
      description: 'Read',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{},
        'required': <String>[],
        'additionalProperties': false,
      },
    ),
  ],
}) => ModelRequest(
  model: 'model',
  modelControls: <String, AgentModelControlValue>{
    AgentModelControlIds.reasoningEffort: const AgentModelControlStringValue(
      value: 'medium',
    ),
  },
  blocks: const <ModelRoleBlock>[
    ModelRoleBlock(role: ModelRole.system, content: 'instructions'),
  ],
  history: history,
  tools: tools,
  forceToolName: forceToolName,
);

class _RecordingAdapter implements HttpClientAdapter {
  new(this.fixture);

  final String fixture;
  RequestOptions? options;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    return ResponseBody.fromString(
      fixture,
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['text/event-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _SequenceAdapter implements HttpClientAdapter {
  new({
    required this.failures,
    required this.type,
    required this.statusCode,
    required this.fixture,
  });

  final int failures;
  final DioExceptionType type;
  final int statusCode;
  final String fixture;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls += 1;
    if (calls <= failures) {
      throw DioException(
        requestOptions: options,
        type: type,
        response: Response<Object?>(
          requestOptions: options,
          statusCode: statusCode,
          data: <String, dynamic>{'error': 'failure'},
        ),
      );
    }
    return ResponseBody.fromString(fixture, 200);
  }

  @override
  void close({bool force = false}) {}
}

/// Rejects every request the way a real server does: a 400 whose body arrives
/// as an undecoded stream, because the request asked for `ResponseType.stream`.
final class _StreamedStatusAdapter implements HttpClientAdapter {
  new(this.body);

  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body,
    400,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

/// Rejects every request with a 400 carrying a decoded JSON error body.
final class _BadRequestAdapter implements HttpClientAdapter {
  new(this.body);

  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response<Object?>(
        requestOptions: options,
        statusCode: 400,
        data: body,
      ),
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _ReasoningSummaryFallbackAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> bodies = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    bodies.add(Map<String, dynamic>.from(options.data as Map));
    if (bodies.length == 1) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response<Object?>(
          requestOptions: options,
          statusCode: 400,
          data: <String, dynamic>{
            'error': <String, dynamic>{
              'param': 'reasoning.summary',
              'message': 'Reasoning summaries are unsupported.',
            },
          },
        ),
      );
    }
    return ResponseBody.fromString('''
data: {"type":"response.output_text.delta","delta":"ok"}

data: {"type":"response.completed","response":{"output":[{"type":"message","content":[{"type":"output_text","text":"ok"}]}],"usage":{}}}

data: [DONE]

''', 200);
  }

  @override
  void close({bool force = false}) {}
}

final class _CancelAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await cancelFuture;
    throw DioException.requestCancelled(
      requestOptions: options,
      reason: 'cancelled',
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Builds a provider config for one test.
///
/// Defaults mirror the platform endpoint, which is the surface most of these
/// tests exercise. A test covering a narrower compatible endpoint states the
/// smaller [extensions] set explicitly.
OpenAIProviderConfig _config({
  String id = 'openai',
  String baseUrl = 'https://provider.test/v1',
  String apiKey = '',
  int maxConnectAttempts = 3,
  bool requiresApiKey = true,
  bool supportsReasoningEffort = true,
  bool supportsImageInput = true,
  bool supportsFileInput = true,
  Set<ProviderEndpointExtension> extensions = _platformExtensions,
  String? requestAttribution = 'safe',
  Map<String, String> additionalHeaders = const <String, String>{},
}) => OpenAIProviderConfig(
  id: id,
  baseUrl: baseUrl,
  apiKey: apiKey,
  maxConnectAttempts: maxConnectAttempts,
  requiresApiKey: requiresApiKey,
  supportsReasoningEffort: supportsReasoningEffort,
  supportsImageInput: supportsImageInput,
  supportsFileInput: supportsFileInput,
  extensions: extensions,
  requestAttribution: requestAttribution,
  additionalHeaders: additionalHeaders,
);

const Set<ProviderEndpointExtension> _platformExtensions =
    <ProviderEndpointExtension>{
      ProviderEndpointExtension.modelDiscovery,
      ProviderEndpointExtension.strictToolSchemas,
      ProviderEndpointExtension.toolOutputSchemas,
      ProviderEndpointExtension.reasoningContinuation,
      ProviderEndpointExtension.reasoningSummaries,
      ProviderEndpointExtension.requestAttribution,
      ProviderEndpointExtension.expeditedProcessing,
      ProviderEndpointExtension.inlineDocuments,
    };

final List<ConversationItem> _documentHistory = <ConversationItem>[
  UserConversationItem(
    'inspect',
    attachments: <ConversationAttachment>[
      ConversationAttachment(
        id: 'document',
        fileName: 'notes.txt',
        mimeType: 'text/plain',
        byteSize: 2,
        path: '/attachments/document.blob',
        bytes: Uint8List.fromList(<int>[4, 5]),
      ),
    ],
  ),
];
