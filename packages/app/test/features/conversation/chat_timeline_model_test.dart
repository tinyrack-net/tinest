import 'package:app/src/features/conversation/application/chat_timeline_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';

void main() {
  final now = DateTime.utc(2026, 8, 3);
  var sequence = 0;

  TimelineEventDto event(
    String type,
    Map<String, dynamic> data, {
    String? turnId = 'turn-1',
    int? at,
  }) => TimelineEventDto(
    sessionId: 'session',
    sequence: at ?? (sequence += 1),
    turnId: turnId,
    type: type,
    data: data,
    createdAt: now,
  );

  setUp(() => sequence = 0);

  test(
    'projects ordered user and assistant attachment timeline events',
    tags: const <String>['feature_test__conversation_attachments__unit'],
    () {
      final items = projectChatTimeline(<TimelineEventDto>[
        event('user.message', <String, dynamic>{
          'text': '',
          'attachments': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'image-1',
              'fileName': 'fixture.png',
              'mimeType': 'image/png',
              'byteSize': 11,
              'path': '/daemon/image-1.blob',
            },
          ],
        }),
        event('assistant.attachment', <String, dynamic>{
          'id': 'file-1',
          'fileName': 'result.txt',
          'mimeType': 'text/plain',
          'byteSize': 5,
          'path': '/daemon/file-1.blob',
        }),
      ]);
      final user = items.first as ChatUserMessage;
      expect(user.text, isEmpty);
      expect(user.attachments.single.id, 'image-1');
      final assistant = items.last as ChatAttachmentMessage;
      expect(assistant.attachment.fileName, 'result.txt');
    },
  );

  test('assistant deltas of one turn merge even when tools interleave', () {
    final items = projectChatTimeline(<TimelineEventDto>[
      event('user.message', <String, dynamic>{'text': 'Fix it'}),
      event('assistant.delta', <String, dynamic>{'text': 'Reading '}),
      event('tool.requested', <String, dynamic>{
        'callId': 'call-1',
        'name': 'read_file',
        'arguments': <String, dynamic>{'path': 'lib/main.dart'},
      }),
      event('tool.completed', <String, dynamic>{
        'callId': 'call-1',
        'name': 'read_file',
        'output': 'void main() {}',
        'isError': false,
      }),
      event('assistant.delta', <String, dynamic>{'text': 'the '}),
      event('assistant.delta', <String, dynamic>{'text': 'file.'}),
      event('turn.completed', <String, dynamic>{'toolRounds': 1}),
    ]);

    expect(items.map((item) => item.runtimeType.toString()), <String>[
      'ChatUserMessage',
      'ChatAssistantMessage',
      'ChatToolActivity',
      'ChatAssistantMessage',
      'ChatNotice',
    ]);
    expect((items[1] as ChatAssistantMessage).markdown, 'Reading ');
    expect((items[3] as ChatAssistantMessage).markdown, 'the file.');
    expect((items[3] as ChatAssistantMessage).isStreaming, isFalse);
    expect((items[4] as ChatNotice).kind, ChatNoticeKind.turnCompleted);
    expect((items[4] as ChatNotice).toolRounds, 1);
  }, tags: const <String>['feature_test__turn_execution__unit']);

  test(
    'reasoning phases stream, complete, split across tools, and omit empties',
    tags: const <String>['feature_test__turn_execution__unit'],
    () {
      final items = projectChatTimeline(<TimelineEventDto>[
        event('assistant.reasoning.started', const <String, dynamic>{}),
        event('assistant.reasoning.delta', <String, dynamic>{
          'text': 'Inspecting ',
        }),
        event('assistant.reasoning.delta', <String, dynamic>{
          'text': 'the code.',
        }),
        event('assistant.reasoning.completed', const <String, dynamic>{}),
        event('tool.requested', <String, dynamic>{
          'callId': 'call-1',
          'name': 'read_file',
          'arguments': <String, dynamic>{'path': 'lib/main.dart'},
        }),
        event('tool.completed', <String, dynamic>{
          'callId': 'call-1',
          'name': 'read_file',
          'output': 'contents',
        }),
        event('assistant.reasoning.started', const <String, dynamic>{}),
        event('assistant.reasoning.delta', <String, dynamic>{
          'text': 'Checking the result.',
        }),
      ]);

      final reasoning = items.whereType<ChatReasoningActivity>().toList();
      expect(reasoning, hasLength(2));
      expect(reasoning.first.markdown, 'Inspecting the code.');
      expect(reasoning.first.isStreaming, isFalse);
      expect(reasoning.last.markdown, 'Checking the result.');
      expect(reasoning.last.isStreaming, isTrue);

      expect(
        projectChatTimeline(<TimelineEventDto>[
          event('assistant.reasoning.started', const <String, dynamic>{}),
          event('assistant.reasoning.completed', const <String, dynamic>{}),
          event('turn.completed', const <String, dynamic>{}),
        ]).whereType<ChatReasoningActivity>(),
        isEmpty,
      );
    },
  );

  test(
    'an empty active reasoning phase remains visible while it is running',
    tags: const <String>['feature_test__turn_execution__unit'],
    () {
      final reasoning =
          projectChatTimeline(<TimelineEventDto>[
                event('assistant.reasoning.started', const <String, dynamic>{}),
              ]).single
              as ChatReasoningActivity;

      expect(reasoning.markdown, isEmpty);
      expect(reasoning.isStreaming, isTrue);
    },
  );

  test('tool requests and results merge into one activity per call', () {
    final items = projectChatTimeline(<TimelineEventDto>[
      event('tool.requested', <String, dynamic>{
        'callId': 'call-1',
        'name': 'exec_command',
        'arguments': <String, dynamic>{'command': 'dart test'},
      }),
      event('tool.completed', <String, dynamic>{
        'callId': 'call-1',
        'name': 'exec_command',
        'output': '{"exitCode":0,"output":"ok"}',
        'isError': false,
      }),
      event('tool.requested', <String, dynamic>{
        'callId': 'call-2',
        'name': 'apply_patch',
        'arguments': <String, dynamic>{'patch': 'diff'},
      }),
      event('tool.failed', <String, dynamic>{
        'callId': 'call-2',
        'name': 'apply_patch',
        'error': 'context mismatch',
      }),
      event('tool.requested', <String, dynamic>{
        'callId': 'call-3',
        'name': 'exec_command',
        'arguments': <String, dynamic>{'command': 'rm -rf /'},
      }),
      event('tool.denied', <String, dynamic>{
        'callId': 'call-3',
        'name': 'exec_command',
      }),
      event('tool.requested', <String, dynamic>{
        'callId': 'call-4',
        'name': 'read_file',
        'arguments': <String, dynamic>{'path': 'a.dart'},
      }),
    ]);

    final activities = items.cast<ChatToolActivity>();
    expect(activities, hasLength(4));
    expect(activities[0].status, ChatToolStatus.succeeded);
    expect(activities[0].output, '{"exitCode":0,"output":"ok"}');
    expect(activities[0].arguments['command'], 'dart test');
    expect(activities[1].status, ChatToolStatus.failed);
    expect(activities[1].error, 'context mismatch');
    expect(activities[2].status, ChatToolStatus.denied);
    expect(activities[3].status, ChatToolStatus.running);
  }, tags: const <String>['feature_test__turn_execution__unit']);

  test('successful attach_file activity yields only its attachment card', () {
    final items = projectChatTimeline(<TimelineEventDto>[
      event('tool.requested', <String, dynamic>{
        'callId': 'attach-1',
        'name': 'attach_file',
        'presentation': <String, dynamic>{'timeline': 'suppressed'},
        'arguments': <String, dynamic>{'path': 'result.txt'},
      }),
      event('tool.completed', <String, dynamic>{
        'callId': 'attach-1',
        'name': 'attach_file',
        'presentation': <String, dynamic>{'timeline': 'suppressed'},
        'output': '{"attachmentId":"attachment-1"}',
        'isError': false,
      }),
      event('assistant.attachment', <String, dynamic>{
        'id': 'attachment-1',
        'fileName': 'result.txt',
        'mimeType': 'text/plain',
        'byteSize': 5,
      }),
    ]);

    expect(items.whereType<ChatToolActivity>(), isEmpty);
    expect(items.whereType<ChatAttachmentMessage>(), hasLength(1));
  }, tags: const <String>['feature_test__conversation_attachments__unit']);

  test('truncated and repeated tool histories stay renderable', () {
    final orphan = projectChatTimeline(<TimelineEventDto>[
      event('tool.completed', <String, dynamic>{
        'callId': 'call-1',
        'name': 'read_file',
        'output': 'text',
        'isError': false,
      }),
      event('tool.requested', <String, dynamic>{
        'callId': 'call-1',
        'name': 'read_file',
        'arguments': <String, dynamic>{'path': 'a.dart'},
      }),
    ]).cast<ChatToolActivity>();
    expect(orphan, hasLength(1));
    expect(orphan.single.status, ChatToolStatus.succeeded);
    expect(orphan.single.arguments['path'], 'a.dart');

    final duplicateTerminal = projectChatTimeline(<TimelineEventDto>[
      event('tool.requested', <String, dynamic>{
        'callId': 'call-1',
        'name': 'read_file',
        'arguments': <String, dynamic>{'path': 'a.dart'},
      }),
      event('tool.completed', <String, dynamic>{
        'callId': 'call-1',
        'name': 'read_file',
        'output': 'first',
        'isError': false,
      }),
      event('tool.completed', <String, dynamic>{
        'callId': 'call-1',
        'name': 'read_file',
        'output': 'second',
        'isError': false,
      }),
    ]).cast<ChatToolActivity>();
    expect(duplicateTerminal, hasLength(1));
    expect(duplicateTerminal.single.output, 'first');

    final reinvoked = projectChatTimeline(<TimelineEventDto>[
      event('tool.requested', <String, dynamic>{
        'callId': 'call-1',
        'name': 'read_file',
        'arguments': <String, dynamic>{'path': 'a.dart'},
      }),
      event('tool.completed', <String, dynamic>{
        'callId': 'call-1',
        'name': 'read_file',
        'output': 'first',
        'isError': false,
      }),
      event('tool.requested', <String, dynamic>{
        'callId': 'call-1',
        'name': 'read_file',
        'arguments': <String, dynamic>{'path': 'b.dart'},
      }),
    ]).cast<ChatToolActivity>();
    expect(reinvoked, hasLength(2));
    expect(reinvoked.last.status, ChatToolStatus.running);
    expect(reinvoked.last.arguments['path'], 'b.dart');

    final duplicateRequest = projectChatTimeline(<TimelineEventDto>[
      event('tool.requested', <String, dynamic>{
        'callId': 'call-1',
        'name': 'read_file',
        'arguments': <String, dynamic>{'path': 'a.dart'},
      }),
      event('tool.requested', <String, dynamic>{
        'callId': 'call-1',
        'name': 'read_file',
        'arguments': <String, dynamic>{'path': 'a.dart'},
      }),
    ]);
    expect(duplicateRequest, hasLength(1));
  }, tags: const <String>['feature_test__turn_execution__unit']);

  test(
    'approvals, usage, failures, and unknown events are typed not dumped',
    () {
      final items = projectChatTimeline(<TimelineEventDto>[
        event('approval.requested', <String, dynamic>{
          'approval': ApprovalRequestDto(
            id: 'approval-1',
            sessionId: 'session',
            turnId: 'turn-1',
            toolCallId: 'call-approval',
            toolName: 'write_file',
            risk: ToolRisk.write,
            arguments: const <String, dynamic>{'path': 'a.dart'},
            status: ApprovalStatus.pending,
            createdAt: now,
          ).toJson(),
        }),
        event('approval.resolved', <String, dynamic>{
          'approvalId': 'approval-1',
          'status': 'approved',
        }),
        event('model.usage', <String, dynamic>{
          'inputTokens': 12,
          'cachedInputTokens': 8,
          'outputTokens': 3,
          'reasoningTokens': 1,
          'totalTokens': 15,
        }),
        event('turn.failed', <String, dynamic>{'error': 'provider down'}),
        event('turn.cancelled', const <String, dynamic>{}, turnId: 'turn-2'),
        event('surprise.event', <String, dynamic>{'a': 1}, turnId: 'turn-3'),
      ]);

      expect(items.whereType<ChatUsage>().single.tokens, <String, num>{
        'inputTokens': 12,
        'cachedInputTokens': 8,
        'outputTokens': 3,
        'reasoningTokens': 1,
        'totalTokens': 15,
      });
      final approval = items.whereType<ChatApprovalInteraction>().single;
      expect(approval.key, 'approval-approval-1');
      expect(approval.status, ChatInteractionStatus.resolved);
      expect(approval.approved, isTrue);
      final notices = items.whereType<ChatNotice>().toList(growable: false);
      expect(notices.map((notice) => notice.kind), <ChatNoticeKind>[
        ChatNoticeKind.turnFailed,
        ChatNoticeKind.turnCancelled,
      ]);
      expect(notices.first.message, 'provider down');
      expect(items.whereType<ChatUnknownEvent>().single.type, 'surprise.event');
      expect(items, hasLength(5));
    },
    tags: const <String>['feature_test__turn_execution__unit'],
  );

  test(
    'projection sorts by sequence and keeps keys stable as events arrive',
    () {
      final first = event('user.message', <String, dynamic>{
        'text': 'Fix it',
      }, at: 1);
      final second = event('assistant.delta', <String, dynamic>{
        'text': 'Working',
      }, at: 2);
      final third = event('tool.requested', <String, dynamic>{
        'callId': 'call-1',
        'name': 'read_file',
        'arguments': <String, dynamic>{'path': 'a.dart'},
      }, at: 3);

      final unsorted = projectChatTimeline(<TimelineEventDto>[
        third,
        first,
        second,
      ]);
      final sorted = projectChatTimeline(<TimelineEventDto>[
        first,
        second,
        third,
      ]);
      expect(unsorted.map((item) => item.key), sorted.map((item) => item.key));

      final before = projectChatTimeline(<TimelineEventDto>[first, second]);
      expect(
        sorted.take(2).map((item) => item.key),
        before.map((item) => item.key),
      );
      expect(
        before.whereType<ChatAssistantMessage>().single.isStreaming,
        isTrue,
      );
    },
    tags: const <String>['feature_test__turn_execution__unit'],
  );

  testWidgets(
    'a question keeps one unique timeline key from broadcast through answer',
    (tester) async {
      final tool = event('tool.requested', <String, dynamic>{
        'callId': 'call-ask',
        'name': 'request_user_input',
        'presentation': <String, dynamic>{'timeline': 'question'},
        'arguments': <String, dynamic>{
          'questions': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'storage',
              'header': 'Storage',
              'question': 'Which store?',
              'options': <Map<String, dynamic>>[
                <String, dynamic>{'label': 'SQLite', 'description': 'Local'},
              ],
            },
          ],
        },
      });
      final request = UserQuestionRequestDto(
        id: 'request-1',
        sessionId: 'session',
        turnId: 'turn-1',
        toolCallId: 'call-ask',
        questions: const <UserQuestionItemDto>[
          UserQuestionItemDto(
            id: 'storage',
            header: 'Storage',
            question: 'Which store?',
            options: <UserQuestionOptionDto>[
              UserQuestionOptionDto(label: 'SQLite', description: 'Local'),
            ],
          ),
        ],
        status: UserQuestionStatus.pending,
        createdAt: now,
      );

      final broadcastOnly =
          projectChatTimeline(
                const <TimelineEventDto>[],
                questions: <String, UserQuestionRequestDto>{
                  request.id: request,
                },
              ).single
              as ChatQuestionInteraction;
      final persisted =
          projectChatTimeline(
                <TimelineEventDto>[tool],
                questions: <String, UserQuestionRequestDto>{
                  request.id: request,
                },
              ).single
              as ChatQuestionInteraction;
      final otherTurn = UserQuestionRequestDto(
        id: 'request-2',
        sessionId: 'session',
        turnId: 'turn-2',
        toolCallId: 'call-ask',
        questions: request.questions,
        status: UserQuestionStatus.pending,
        createdAt: now,
      );
      final concurrentKeys = projectChatTimeline(
        const <TimelineEventDto>[],
        questions: <String, UserQuestionRequestDto>{
          request.id: request,
          otherTurn.id: otherTurn,
        },
      ).map((item) => item.key);
      final answered =
          projectChatTimeline(<TimelineEventDto>[
                tool,
                event('tool.completed', <String, dynamic>{
                  'callId': 'call-ask',
                  'name': 'request_user_input',
                  'presentation': <String, dynamic>{'timeline': 'question'},
                  'output':
                      '[{"questionId":"storage","answer":"SQLite",'
                      '"isFreeForm":false}]',
                  'isError': false,
                }),
              ]).single
              as ChatUserAnswer;

      expect(persisted.key, broadcastOnly.key);
      expect(answered.key, persisted.key);
      expect(concurrentKeys.toSet(), hasLength(2));
      expect(answered.entries.single.answer, 'SQLite');
    },
    tags: const <String>['feature_test__turn_question__widget'],
  );

  test(
    'a failed question keeps the Lua contribution identity and presentation',
    () {
      final items = projectChatTimeline(<TimelineEventDto>[
        event('tool.requested', <String, dynamic>{
          'callId': 'call-ask',
          'name': 'choose_storage',
          'presentation': <String, dynamic>{
            'timeline': 'question',
            'label': 'Choose storage',
            'glyph': 'ask',
          },
          'arguments': <String, dynamic>{'questions': <Map<String, dynamic>>[]},
        }),
        event('tool.failed', <String, dynamic>{
          'callId': 'call-ask',
          'name': 'choose_storage',
          'presentation': <String, dynamic>{
            'timeline': 'question',
            'label': 'Choose storage',
            'glyph': 'ask',
          },
          'error': 'Unavailable',
        }),
      ]);

      final failed = items.single as ChatToolActivity;
      expect(failed.toolName, 'choose_storage');
      expect(failed.presentation, <String, dynamic>{
        'timeline': 'question',
        'label': 'Choose storage',
        'glyph': 'ask',
      });
    },
    tags: const <String>['feature_test__turn_question__widget'],
  );

  test(
    'a stopped turn keeps what it already said and marks itself cancelled',
    () {
      final items = projectChatTimeline(<TimelineEventDto>[
        event('user.message', <String, dynamic>{'text': 'Explain it'}),
        event('assistant.delta', <String, dynamic>{'text': 'half an '}),
        event('assistant.delta', <String, dynamic>{'text': 'answer'}),
        event('turn.cancelled', const <String, dynamic>{}),
      ]);

      // Stopping is not undoing: the partial answer stays in the transcript,
      // stops streaming, and carries a cancellation notice.
      final assistant = items.whereType<ChatAssistantMessage>().single;
      expect(assistant.markdown, 'half an answer');
      expect(assistant.isStreaming, isFalse);
      expect(
        items.whereType<ChatNotice>().single.kind,
        ChatNoticeKind.turnCancelled,
      );
    },
    tags: const <String>['feature_test__turn_execution__unit'],
  );

  test('empty assistant text and empty input produce no items', () {
    expect(projectChatTimeline(const <TimelineEventDto>[]), isEmpty);
    expect(
      projectChatTimeline(<TimelineEventDto>[
        event('assistant.delta', <String, dynamic>{'text': ''}),
      ]),
      isEmpty,
    );
  }, tags: const <String>['feature_test__turn_execution__unit']);

  test(
    'a block extended by an older page keeps the identity it already had',
    () {
      // The daemon splits a turn longer than one page, so the oldest loaded
      // row is routinely half of a streamed answer. Paging back extends that
      // same block: it is the same row, growing upwards, and the list anchors
      // the reader to it by key. An identity that moves with the window makes
      // the reader's anchor vanish at the exact moment a page lands.
      final deltas = <TimelineEventDto>[
        for (var index = 1; index <= 6; index += 1)
          event('assistant.delta', <String, dynamic>{
            'text': 'part $index ',
            'blockId': 'block-1',
          }, at: index),
      ];

      final loaded = projectChatTimeline(deltas.sublist(3));
      final extended = projectChatTimeline(deltas);

      final before = loaded.whereType<ChatAssistantMessage>().single;
      final after = extended.whereType<ChatAssistantMessage>().single;
      expect(before.markdown, 'part 4 part 5 part 6 ');
      expect(
        after.markdown,
        'part 1 part 2 part 3 part 4 part 5 part 6 ',
        reason: 'an older page extends the block it precedes',
      );
      expect(
        after.key,
        before.key,
        reason: 'the row the reader is anchored to survives its own page load',
      );
    },
    tags: const <String>['feature_test__conversation_history_pagination__unit'],
  );

  test(
    'a reasoning block extended by an older page keeps its identity too',
    () {
      final deltas = <TimelineEventDto>[
        for (var index = 1; index <= 6; index += 1)
          event('assistant.reasoning.delta', <String, dynamic>{
            'text': 'thought $index ',
            'blockId': 'block-1',
          }, at: index),
      ];

      final before = projectChatTimeline(deltas.sublist(3))
          .whereType<ChatReasoningActivity>()
          .single;
      final after = projectChatTimeline(deltas)
          .whereType<ChatReasoningActivity>()
          .single;

      expect(after.markdown, startsWith('thought 1 '));
      expect(
        after.key,
        before.key,
        reason: 'the row the reader is anchored to survives its own page load',
      );
    },
    tags: const <String>['feature_test__conversation_history_pagination__unit'],
  );

  test(
    'two answers in one turn are two rows with identities of their own',
    () {
      final items = projectChatTimeline(<TimelineEventDto>[
        event('assistant.delta', <String, dynamic>{
          'text': 'first ',
          'blockId': 'block-1',
        }),
        event('tool.requested', <String, dynamic>{
          'callId': 'call-1',
          'name': 'read_file',
          'arguments': <String, dynamic>{},
        }),
        event('tool.completed', <String, dynamic>{
          'callId': 'call-1',
          'name': 'read_file',
          'output': 'done',
          'isError': false,
        }),
        event('assistant.delta', <String, dynamic>{
          'text': 'second ',
          'blockId': 'block-2',
        }),
      ]);

      final answers = items.whereType<ChatAssistantMessage>().toList();
      expect(answers.map((item) => item.markdown), <String>[
        'first ',
        'second ',
      ]);
      expect(answers.map((item) => item.key).toSet(), hasLength(2));
    },
    tags: const <String>['feature_test__conversation_history_pagination__unit'],
  );
}
