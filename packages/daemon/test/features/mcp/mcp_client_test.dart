import 'dart:async';

import 'package:daemon/src/features/mcp/infrastructure/mcp.dart';
import 'package:daemon/src/features/mcp/infrastructure/testing.dart';
import 'package:daemon/src/shared/ports/request_cancellation.dart';
import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';

void main() {
  test('connecting negotiates, confirms, and lists every tool page', () async {
    final server = ScriptedMcpServer(
      toolPages: <List<Map<String, dynamic>>>[
        <Map<String, dynamic>>[
          <String, dynamic>{'name': 'first'},
        ],
        <Map<String, dynamic>>[
          <String, dynamic>{'name': 'second'},
        ],
      ],
    );
    final client = McpClient(
      transport: server.transport,
      clientVersion: '0.1.0',
    );
    addTearDown(client.close);

    final identity = await client.connect();

    expect(identity.protocolVersion, preferredMcpProtocolVersion);
    expect(identity.name, 'fake');
    expect(identity.version, '1.0.0');
    expect(identity.publishesTools, isTrue);
    expect(identity.emitsToolListChanged, isTrue);
    expect(client.tools.map((tool) => tool.name), <String>['first', 'second']);

    expect(
      server.methods,
      containsAllInOrder(<String>[
        McpMethod.initialize,
        McpMethod.initialized,
        McpMethod.toolsList,
        McpMethod.toolsList,
      ]),
    );
    final initialize = server.requests.first['params']! as Map<String, dynamic>;
    expect(initialize['protocolVersion'], preferredMcpProtocolVersion);
    expect(
      (initialize['clientInfo']! as Map<String, dynamic>)['name'],
      'tinyrack-tinest',
    );
    expect(
      (initialize['clientInfo']! as Map<String, dynamic>)['version'],
      '0.1.0',
    );
    expect(initialize['capabilities'], contains('tools'));
  });

  test(
    'connecting drains every resource page and both template lists',
    tags: const <String>['feature_test__mcp_resource_access__unit'],
    () async {
      final server = ScriptedMcpServer(
        publishesResources: true,
        resourcePages: <List<Map<String, dynamic>>>[
          <Map<String, dynamic>>[
            <String, dynamic>{'uri': 'file:///a.txt', 'name': 'a'},
          ],
          <Map<String, dynamic>>[
            <String, dynamic>{'uri': 'file:///b.txt', 'name': 'b'},
            // A malformed entry is skipped, not fatal.
            <String, dynamic>{'name': 'no uri'},
          ],
        ],
        resourceTemplates: <Map<String, dynamic>>[
          <String, dynamic>{'uriTemplate': 'file:///{path}'},
        ],
      );
      final client = McpClient(transport: server.transport);
      addTearDown(client.close);

      final identity = await client.connect();

      expect(identity.publishesResources, isTrue);
      expect(identity.emitsResourceListChanged, isTrue);
      expect(client.resources.map((item) => item.uri), <String>[
        'file:///a.txt',
        'file:///b.txt',
      ]);
      expect(client.resourceTemplates.single.uriTemplate, 'file:///{path}');
      expect(
        server.methods.where((m) => m == McpMethod.resourcesList).length,
        2,
      );
    },
  );

  test(
    'a server without the resources capability is never asked for them',
    tags: const <String>['feature_test__mcp_resource_access__unit'],
    () async {
      final server = ScriptedMcpServer();
      final client = McpClient(transport: server.transport);
      addTearDown(client.close);

      final identity = await client.connect();

      expect(identity.publishesResources, isFalse);
      expect(client.resources, isEmpty);
      expect(client.resourceTemplates, isEmpty);
      expect(server.methods, isNot(contains(McpMethod.resourcesList)));
    },
  );

  test(
    'a resources-only server connects and reads a resource',
    tags: const <String>['feature_test__mcp_resource_access__unit'],
    () async {
      // Nothing may assume a server publishes tools.
      final server = ScriptedMcpServer(
        publishesTools: false,
        publishesResources: true,
        resourcePages: <List<Map<String, dynamic>>>[
          <Map<String, dynamic>>[
            <String, dynamic>{'uri': 'db://schema'},
          ],
        ],
      );
      final client = McpClient(transport: server.transport);
      addTearDown(client.close);

      final identity = await client.connect();
      expect(identity.publishesTools, isFalse);
      expect(client.tools, isEmpty);
      expect(client.resources.single.uri, 'db://schema');

      final read = await client.readResource('db://schema');
      final contents = read.contents.single as McpTextResourceContents;
      expect(contents.text, 'body');
      expect(contents.uri, 'db://schema');
    },
  );

  test(
    'a resource list change refreshes the cache and notifies listeners',
    tags: const <String>['feature_test__mcp_resource_access__unit'],
    () async {
      final server = ScriptedMcpServer(
        publishesResources: true,
        resourcePages: <List<Map<String, dynamic>>>[
          <Map<String, dynamic>>[
            <String, dynamic>{'uri': 'file:///old.txt'},
          ],
        ],
      );
      final client = McpClient(transport: server.transport);
      addTearDown(client.close);
      await client.connect();

      final changed = client.resourcesChanged.first;
      server
        ..resourcePages = <List<Map<String, dynamic>>>[
          <Map<String, dynamic>>[
            <String, dynamic>{'uri': 'file:///new.txt'},
          ],
        ]
        ..announceResourceListChanged();
      await changed;

      expect(client.resources.single.uri, 'file:///new.txt');
    },
  );

  test('a server that speaks an older supported revision connects', () async {
    final server = ScriptedMcpServer(protocolVersion: '2025-03-26');
    final client = McpClient(transport: server.transport);
    addTearDown(client.close);

    final identity = await client.connect();

    expect(identity.protocolVersion, '2025-03-26');
  });

  test('an unsupported protocol revision fails the connection', () async {
    final server = ScriptedMcpServer(protocolVersion: '1999-01-01');
    final client = McpClient(transport: server.transport);
    addTearDown(client.close);

    await expectLater(
      client.connect(),
      throwsA(isA<McpUnsupportedProtocolVersion>()),
    );
    expect(server.methods, isNot(contains(McpMethod.toolsList)));
  });

  test('a server without the tools capability is ready but empty', () async {
    final server = ScriptedMcpServer(publishesTools: false);
    final client = McpClient(transport: server.transport);
    addTearDown(client.close);

    final identity = await client.connect();

    expect(identity.publishesTools, isFalse);
    expect(client.tools, isEmpty);
    expect(server.methods, isNot(contains(McpMethod.toolsList)));
  });

  test('malformed tool entries are skipped instead of failing', () async {
    final server = ScriptedMcpServer(
      toolPages: <List<Map<String, dynamic>>>[
        <Map<String, dynamic>>[
          <String, dynamic>{'name': 'good'},
          <String, dynamic>{'title': 'no name'},
        ],
      ],
    );
    final client = McpClient(transport: server.transport);
    addTearDown(client.close);

    await client.connect();

    expect(client.tools.map((tool) => tool.name), <String>['good']);
  });

  test(
    'a tool list change triggers a re-list and notifies listeners',
    () async {
      final server = ScriptedMcpServer();
      final client = McpClient(transport: server.transport);
      addTearDown(client.close);
      await client.connect();

      final changes = <void>[];
      client.toolsChanged.listen(changes.add);

      server
        ..toolPages = <List<Map<String, dynamic>>>[
          <Map<String, dynamic>>[
            <String, dynamic>{'name': 'renamed'},
          ],
        ]
        ..announceToolListChanged();
      await pumpEventQueue();

      expect(client.tools.single.name, 'renamed');
      expect(changes, hasLength(1));
    },
  );

  test('calling a tool decodes the result and forwards arguments', () async {
    final server = ScriptedMcpServer(
      callResult: <String, dynamic>{
        'content': <dynamic>[
          <String, dynamic>{'type': 'text', 'text': 'done'},
        ],
        'structuredContent': <String, dynamic>{'ok': true},
      },
    );
    final client = McpClient(transport: server.transport);
    addTearDown(client.close);
    await client.connect();

    final result = await client.callTool('echo', <String, dynamic>{'v': 1});

    expect((result.content.single as McpTextContent).text, 'done');
    expect(result.structuredContent, <String, dynamic>{'ok': true});
    final call = server.requests.last['params']! as Map<String, dynamic>;
    expect(call['name'], 'echo');
    expect(call['arguments'], <String, dynamic>{'v': 1});
  });

  test('an already-cancelled tool call is never transmitted', () async {
    final server = ScriptedMcpServer();
    final client = McpClient(transport: server.transport);
    addTearDown(client.close);
    await client.connect();
    final cancellation = _TestRequestCancellation()..cancel();

    await expectLater(
      client.callTool(
        'echo',
        const <String, dynamic>{},
        cancellation: cancellation,
      ),
      throwsA(isA<McpRequestCancelled>()),
    );

    expect(
      server.methods.where((method) => method == McpMethod.toolsCall),
      isEmpty,
    );
    expect(client.isConnected, isTrue);
  });

  test(
    'cancelling one pending tool call preserves unrelated requests',
    () async {
      final server = ScriptedMcpServer(answerToolCalls: false);
      final client = McpClient(transport: server.transport);
      addTearDown(client.close);
      await client.connect();
      final cancellation = _TestRequestCancellation();

      final pending = client.callTool(
        'echo',
        const <String, dynamic>{},
        cancellation: cancellation,
      );
      final unrelated = client.callTool('other', const <String, dynamic>{
        'after': true,
      });
      await pumpEventQueue();
      final calls = server.requests
          .where((message) => message['method'] == McpMethod.toolsCall)
          .toList(growable: false);
      cancellation.cancel();
      server.transport.deliver(<String, dynamic>{
        'jsonrpc': '2.0',
        'id': calls.last['id'],
        'result': <String, dynamic>{
          'content': <Map<String, dynamic>>[
            <String, dynamic>{'type': 'text', 'text': 'unrelated'},
          ],
        },
      });

      await expectLater(pending, throwsA(isA<McpRequestCancelled>()));
      final result = await unrelated;
      await pumpEventQueue();
      final notification = server.requests.lastWhere(
        (message) => message['method'] == McpMethod.cancelled,
      );
      expect(notification['id'], isNull);
      expect(notification['params'], <String, dynamic>{
        'requestId': isA<int>(),
        'reason': 'the request was cancelled by its caller',
      });

      expect((result.content.single as McpTextContent).text, 'unrelated');
      expect(client.isConnected, isTrue);
    },
  );

  test('a JSON-RPC error response surfaces as a server exception', () async {
    final server = ScriptedMcpServer(
      callError: <String, dynamic>{'code': -32602, 'message': 'bad args'},
    );
    final client = McpClient(transport: server.transport);
    addTearDown(client.close);
    await client.connect();

    await expectLater(
      client.callTool('echo', const <String, dynamic>{}),
      throwsA(
        isA<McpServerException>()
            .having((error) => error.code, 'code', -32602)
            .having((error) => error.message, 'message', 'bad args'),
      ),
    );
  });

  test('inbound pings are answered and unknown methods are refused', () async {
    final server = ScriptedMcpServer();
    final client = McpClient(transport: server.transport);
    addTearDown(client.close);
    await client.connect();

    server
      ..sendRequest(90, McpMethod.ping)
      ..sendRequest(91, 'sampling/createMessage');
    await pumpEventQueue();

    final answers = server.transport.sent
        .where(
          (message) =>
              message.containsKey('result') || message.containsKey('error'),
        )
        .toList();
    expect(answers, hasLength(2));
    expect(answers.first['id'], 90);
    expect(answers.first['result'], isEmpty);
    expect(answers.last['id'], 91);
    expect((answers.last['error']! as Map<String, dynamic>)['code'], -32601);
  });

  test('a request that outlives its timeout is cancelled', () {
    fakeAsync((async) {
      final server = ScriptedMcpServer(answerToolsList: false);
      final client = McpClient(transport: server.transport);

      Object? failure;
      unawaited(
        client.connect().catchError((Object error) {
          failure = error;
          return const McpServerIdentity(
            protocolVersion: preferredMcpProtocolVersion,
          );
        }),
      );
      // One second past the default 60-second request timeout.
      async.elapse(const Duration(seconds: 61));

      expect(failure, isA<TimeoutException>());
      expect(server.methods, contains(McpMethod.cancelled));
      unawaited(client.close());
      async.flushTimers();
    });
  });

  test('two unanswered pings tear the transport down', () {
    fakeAsync((async) {
      final server = ScriptedMcpServer(answerPing: false);
      final client = McpClient(
        transport: server.transport,
        requestTimeout: const Duration(seconds: 10),
      );

      unawaited(client.connect());
      async.flushMicrotasks();
      expect(client.isConnected, isTrue);

      async.elapse(const Duration(seconds: 100));

      expect(client.isConnected, isFalse);
      expect(server.methods.where((m) => m == McpMethod.ping).length, 2);
      async.flushTimers();
    });
  });

  test('an answered ping keeps the connection alive', () {
    fakeAsync((async) {
      final server = ScriptedMcpServer();
      final client = McpClient(transport: server.transport);

      unawaited(client.connect());
      // Three default 30-second ping intervals.
      async
        ..flushMicrotasks()
        ..elapse(const Duration(seconds: 100));

      expect(client.isConnected, isTrue);
      expect(server.methods.where((m) => m == McpMethod.ping), isNotEmpty);
      unawaited(client.close());
      async.flushTimers();
    });
  });

  test('a dropped peer marks the client disconnected', () async {
    final server = ScriptedMcpServer();
    final client = McpClient(transport: server.transport);
    addTearDown(client.close);
    await client.connect();

    final diagnostics = <String>[];
    client.diagnostics.listen(diagnostics.add);
    server.transport.dropPeer('exited with code 1');
    await client.closed;

    expect(client.isConnected, isFalse);
    expect(diagnostics, contains('exited with code 1'));
    await expectLater(
      client.callTool('echo', const <String, dynamic>{}),
      throwsA(isA<McpTransportClosed>()),
    );
  });

  test('calling before connecting is refused', () async {
    final server = ScriptedMcpServer();
    final client = McpClient(transport: server.transport);
    addTearDown(client.close);

    await expectLater(
      client.callTool('echo', const <String, dynamic>{}),
      throwsA(isA<McpTransportClosed>()),
    );
  });

  test('unmatched and malformed server messages are ignored', () async {
    final server = ScriptedMcpServer();
    final client = McpClient(transport: server.transport);
    addTearDown(client.close);
    await client.connect();

    server.transport
      ..deliver(<String, dynamic>{
        'jsonrpc': '2.0',
        'id': 9999,
        'result': <String, dynamic>{},
      })
      ..deliver(<String, dynamic>{'jsonrpc': '2.0'})
      ..deliver(<String, dynamic>{'method': 'notifications/unknown'});
    await pumpEventQueue();

    expect(client.isConnected, isTrue);
  });
}

final class _TestRequestCancellation implements RequestCancellation {
  final List<void Function()> _callbacks = <void Function()>[];
  bool _cancelled = false;

  @override
  bool get isCancelled => _cancelled;

  @override
  void onCancel(void Function() callback) {
    if (_cancelled) {
      callback();
      return;
    }
    _callbacks.add(callback);
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final callback in List<void Function()>.of(_callbacks)) {
      callback();
    }
    _callbacks.clear();
  }
}
