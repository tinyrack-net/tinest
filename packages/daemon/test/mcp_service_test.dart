@Tags(<String>['feature_test__mcp_server_management__unit'])
library;

import 'dart:async';

import 'package:agent/agent.dart';
import 'package:daemon/src/features/mcp/infrastructure/mcp.dart';
import 'package:daemon/src/features/mcp/infrastructure/mcp_config.dart';
import 'package:daemon/src/features/mcp/infrastructure/mcp_host_primitives.dart';
import 'package:daemon/src/features/mcp/infrastructure/mcp_service.dart';
import 'package:daemon/src/features/mcp/infrastructure/testing.dart';
import 'package:daemon/src/features/plugins/runtime/host_primitives.dart';
import 'package:daemon/src/shared/infrastructure/persistence/repositories.dart';
import 'package:daemon/src/shared/ports/request_cancellation.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  const stdioServer = McpServerConfigDto(
    id: 'github',
    transport: McpTransportKind.stdio,
    command: 'npx',
    env: <String, String>{'TOKEN': r'${secret:github.token}'},
  );

  late _MemoryConfigStore store;
  late _FakeTransports transports;
  late _FakeCredentials credentials;

  McpRuntime build({
    Map<String, String> environment = const <String, String>{},
    McpTimerFactory? timerFactory,
  }) => McpRuntime(
    store: store,
    credentials: credentials,
    transports: transports,
    clock: _FixedClock(),
    environment: environment,
    timerFactory: timerFactory ?? Timer.new,
  );

  setUp(() {
    store = _MemoryConfigStore();
    transports = _FakeTransports();
    credentials = _FakeCredentials()
      ..mcpSecrets['github.token'] = 'stored-secret';
  });

  test('an empty configuration publishes nothing', () async {
    final service = build();
    addTearDown(service.close);

    await service.initialize();

    expect(service.availableTools(), isEmpty);
    expect(service.states(), isEmpty);
  });

  test('a connected server publishes its tools and state', () async {
    store.user = <McpServerConfigDto>[stdioServer];
    transports.nextServer = ScriptedMcpServer(
      toolPages: <List<Map<String, dynamic>>>[
        <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'echo',
            'description': 'Echoes its argument.',
            'inputSchema': <String, dynamic>{'type': 'object'},
            'outputSchema': <String, dynamic>{'type': 'string'},
          },
        ],
      ],
    );
    final service = build();
    addTearDown(service.close);

    await service.initialize();
    await pumpEventQueue();

    final published = service.availableTools().single;
    expect(published.server, 'github');
    expect(published.descriptor.name, 'echo');
    expect(published.descriptor.inputSchema?['type'], 'object');
    expect(published.descriptor.outputSchema, <String, dynamic>{
      'type': 'string',
    });

    final state = service.states().single;
    expect(state.status, McpServerStatus.ready);
    expect(state.scope, McpConfigScope.user);
    expect(state.sourcePath, store.sourcePath(McpConfigScope.user));
    expect(state.serverName, 'fake');
    expect(state.protocolVersion, preferredMcpProtocolVersion);
    expect(state.tools.single.toolId, 'mcp__github__echo');
    expect(state.tools.single.name, 'echo');
    expect(state.error, isNull);
    expect(state.lastConnectedAt, isNotNull);
  });

  test(
    'raw MCP gateway catalogs and invokes without model tool policy',
    () async {
      final server = ScriptedMcpServer(
        toolPages: <List<Map<String, dynamic>>>[
          <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'echo',
              'title': 'Echo',
              'description': 'External descriptor text.',
              'inputSchema': <String, dynamic>{
                'type': 'object',
                'properties': <String, dynamic>{
                  'value': <String, dynamic>{'type': 'string'},
                },
              },
              'annotations': <String, dynamic>{'readOnlyHint': true},
            },
          ],
        ],
        callResult: <String, dynamic>{
          'content': <Map<String, dynamic>>[
            <String, dynamic>{'type': 'text', 'text': 'pong'},
          ],
          'structuredContent': <String, dynamic>{'echo': 'pong'},
        },
      );
      transports.nextServer = server;
      store.user = <McpServerConfigDto>[stdioServer];
      final service = build();
      addTearDown(service.close);
      await service.initialize();
      await pumpEventQueue();
      final gateway = SessionMcpHostPrimitiveGateway(service, '/workspace');

      final catalog = await gateway.catalogTools(const <String, Object?>{});
      expect(catalog['tools'], <Map<String, Object?>>[
        <String, Object?>{
          'server': 'github',
          'name': 'echo',
          'title': 'Echo',
          'description': 'External descriptor text.',
          'inputSchema': <String, dynamic>{
            'type': 'object',
            'properties': <String, dynamic>{
              'value': <String, dynamic>{'type': 'string'},
            },
          },
          'annotations': <String, Object?>{'readOnlyHint': true},
        },
      ]);

      final result = await gateway.invokeTool(<String, Object?>{
        'server': 'github',
        'name': 'echo',
        'arguments': <String, Object?>{'value': 'ping'},
      });
      expect(result['isError'], isFalse);
      expect(result['structuredContent'], <String, dynamic>{'echo': 'pong'});
      expect(result['content'], <Map<String, Object?>>[
        <String, Object?>{'type': 'text', 'text': 'pong'},
      ]);
      expect(server.requests.last['params'], <String, dynamic>{
        'name': 'echo',
        'arguments': <String, Object?>{'value': 'ping'},
      });
    },
  );

  test(
    'raw MCP gateway maps host-await cancellation to a structured failure',
    () async {
      final server = ScriptedMcpServer(answerToolCalls: false);
      transports.nextServer = server;
      store.user = <McpServerConfigDto>[stdioServer];
      final service = build();
      addTearDown(service.close);
      await service.initialize();
      await pumpEventQueue();
      final gateway = SessionMcpHostPrimitiveGateway(service, '/workspace');
      final cancellation = _TestRequestCancellation();

      final pending = gateway.invokeTool(const <String, Object?>{
        'server': 'github',
        'name': 'echo',
        'arguments': <String, Object?>{},
      }, cancellation: cancellation);
      await pumpEventQueue();
      cancellation.cancel();

      await expectLater(
        pending,
        throwsA(
          isA<HostPrimitiveException>().having(
            (error) => error.error.code,
            'code',
            'cancelled',
          ),
        ),
      );
      expect(service.isReady('github'), isTrue);
    },
  );

  test(
    'raw MCP resource read and catalog behavior remains unchanged',
    () async {
      transports.nextServer = ScriptedMcpServer(
        publishesResources: true,
        resourcePages: <List<Map<String, dynamic>>>[
          <Map<String, dynamic>>[
            <String, dynamic>{'uri': 'file:///guide.md', 'name': 'guide'},
          ],
        ],
        resourceTemplates: <Map<String, dynamic>>[
          <String, dynamic>{'uriTemplate': 'file:///{path}'},
        ],
      );
      store.user = <McpServerConfigDto>[stdioServer];
      final service = build();
      addTearDown(service.close);
      await service.initialize();
      await pumpEventQueue();
      final gateway = SessionMcpHostPrimitiveGateway(service, '/workspace');

      final resources = await gateway.listResources(const <String, Object?>{
        'server': 'github',
      });
      final templates = await gateway.listResourceTemplates(
        const <String, Object?>{'server': 'github'},
      );
      final content = await gateway.readResource(const <String, Object?>{
        'server': 'github',
        'uri': 'file:///guide.md',
      });

      expect(resources['resources'], <Map<String, Object?>>[
        <String, Object?>{
          'server': 'github',
          'uri': 'file:///guide.md',
          'name': 'guide',
        },
      ]);
      expect(templates['resourceTemplates'], <Map<String, Object?>>[
        <String, Object?>{'server': 'github', 'uriTemplate': 'file:///{path}'},
      ]);
      expect(content['contents'], <Map<String, Object?>>[
        <String, Object?>{
          'uri': 'file:///guide.md',
          'mimeType': 'text/plain',
          'text': 'body',
        },
      ]);
    },
  );

  test(
    'a ready server publishes its resources, scoped and sorted',
    tags: const <String>['feature_test__mcp_resource_access__verticalSlice'],
    () async {
      transports.nextServer = ScriptedMcpServer(
        publishesResources: true,
        resourcePages: <List<Map<String, dynamic>>>[
          <Map<String, dynamic>>[
            <String, dynamic>{'uri': 'file:///b.txt', 'name': 'b'},
            <String, dynamic>{'uri': 'file:///a.txt', 'name': 'a'},
          ],
        ],
        resourceTemplates: <Map<String, dynamic>>[
          <String, dynamic>{'uriTemplate': 'file:///{path}'},
        ],
      );
      store.user = <McpServerConfigDto>[stdioServer];
      final service = build();
      addTearDown(service.close);

      await service.initialize();
      await pumpEventQueue();

      // The state DTO carries them, so the settings UI needs no new RPC.
      final state = service.states().single;
      expect(state.resources.map((item) => item.uri), <String>[
        'file:///b.txt',
        'file:///a.txt',
      ]);
      expect(state.resourceTemplates.single.uriTemplate, 'file:///{path}');

      expect(service.resources().map((item) => item.descriptor.uri), <String>[
        'file:///b.txt',
        'file:///a.txt',
      ]);
      expect(
        service.resources().every((item) => item.server == 'github'),
        isTrue,
      );
      expect(service.resourceTemplates(), hasLength(1));
      expect(service.isReady('github'), isTrue);
      expect(service.isReady('absent'), isFalse);

      final read = await service.readResource(
        server: 'github',
        uri: 'file:///a.txt',
      );
      expect((read.contents.single as McpTextResourceContents).text, 'body');

      await expectLater(
        service.readResource(server: 'absent', uri: 'file:///a.txt'),
        throwsA(isA<McpServerUnavailable>()),
      );
    },
  );

  test(
    'a server that is still connecting publishes no resources',
    tags: const <String>['feature_test__mcp_resource_access__verticalSlice'],
    () async {
      transports.nextServer = ScriptedMcpServer(
        publishesResources: true,
        resourcePages: <List<Map<String, dynamic>>>[
          <Map<String, dynamic>>[
            <String, dynamic>{'uri': 'file:///a.txt'},
          ],
        ],
      );
      store.user = <McpServerConfigDto>[stdioServer];
      transports.stall = true;
      final service = build();
      addTearDown(service.close);

      await service.initialize();

      expect(service.states().single.resources, isEmpty);
      expect(service.resources(), isEmpty);
      await expectLater(
        service.readResource(server: 'github', uri: 'file:///a.txt'),
        throwsA(isA<McpServerUnavailable>()),
      );
    },
  );

  test('initialization returns before any handshake completes', () async {
    store.user = <McpServerConfigDto>[stdioServer];
    transports.stall = true;
    final service = build();
    addTearDown(service.close);

    await service.initialize();

    expect(service.states().single.status, McpServerStatus.connecting);
    expect(service.availableTools(), isEmpty);
  });

  test('secrets and environment expand into the transport spec', () async {
    store.user = <McpServerConfigDto>[
      stdioServer,
      const McpServerConfigDto(
        id: 'linear',
        transport: McpTransportKind.http,
        url: 'https://mcp.linear.test/mcp',
        headers: <String, String>{'authorization': r'Bearer ${env:LINEAR}'},
      ),
    ];
    final service = build(
      environment: const <String, String>{'LINEAR': 'env-secret'},
    );
    addTearDown(service.close);

    await service.initialize();
    await pumpEventQueue();

    final stdio = transports.specs.first as McpStdioSpec;
    expect(stdio.command, 'npx');
    expect(stdio.env, <String, String>{'TOKEN': 'stored-secret'});
    final http = transports.specs.last as McpHttpSpec;
    expect(http.url, Uri.parse('https://mcp.linear.test/mcp'));
    expect(http.headers, <String, String>{
      'authorization': 'Bearer env-secret',
    });
  });

  test('a disabled server is never launched', () async {
    store.user = <McpServerConfigDto>[stdioServer.copyWith(enabled: false)];
    final service = build();
    addTearDown(service.close);

    await service.initialize();
    await pumpEventQueue();

    expect(transports.specs, isEmpty);
    expect(service.states().single.status, McpServerStatus.disabled);
    expect(service.availableTools(), isEmpty);
  });

  test('a server that cannot start fails without taking the rest', () async {
    store.user = <McpServerConfigDto>[
      stdioServer,
      const McpServerConfigDto(
        id: 'broken',
        transport: McpTransportKind.stdio,
        command: 'missing',
      ),
    ];
    transports.failFor.add('missing');
    final service = build();
    addTearDown(service.close);

    await service.initialize();
    await pumpEventQueue();

    final broken = service.states().firstWhere(
      (state) => state.config.id == 'broken',
    );
    expect(broken.status, McpServerStatus.failed);
    expect(broken.error, contains('cannot start'));
    expect(broken.diagnostics, isNotEmpty);
    expect(broken.nextRetryAt, isNotNull);
    // The healthy server still published its tools.
    expect(service.availableTools().single.descriptor.name, 'echo');
  });

  test('an unresolvable secret fails only its own server', () async {
    store.user = <McpServerConfigDto>[
      const McpServerConfigDto(
        id: 'needy',
        transport: McpTransportKind.stdio,
        command: 'x',
        env: <String, String>{'TOKEN': r'${env:ABSENT}'},
      ),
    ];
    final service = build();
    addTearDown(service.close);

    await service.initialize();
    await pumpEventQueue();

    expect(service.states().single.status, McpServerStatus.failed);
    expect(service.states().single.error, contains('mcp_missing_env'));
  });

  test('a tool list change re-publishes and announces', () async {
    store.user = <McpServerConfigDto>[stdioServer];
    final service = build();
    addTearDown(service.close);
    await service.initialize();
    await pumpEventQueue();

    final changes = <void>[];
    final subscription = service.changes.listen(changes.add);
    addTearDown(subscription.cancel);

    transports.servers.single
      ..toolPages = <List<Map<String, dynamic>>>[
        <Map<String, dynamic>>[
          <String, dynamic>{'name': 'renamed'},
        ],
      ]
      ..announceToolListChanged();
    await pumpEventQueue();

    expect(changes, isNotEmpty);
    expect(service.availableTools().single.descriptor.name, 'renamed');
  });

  test('saving reconciles instead of restarting everything', () async {
    store.user = <McpServerConfigDto>[
      stdioServer,
      const McpServerConfigDto(
        id: 'linear',
        transport: McpTransportKind.stdio,
        command: 'linear',
      ),
    ];
    final service = build();
    addTearDown(service.close);
    await service.initialize();
    await pumpEventQueue();
    expect(transports.specs, hasLength(2));

    await service.saveUserServers(<McpServerConfigDto>[
      stdioServer,
      const McpServerConfigDto(
        id: 'linear',
        transport: McpTransportKind.stdio,
        command: 'linear-v2',
      ),
    ]);
    await pumpEventQueue();

    // Only the changed server was relaunched.
    expect(transports.specs, hasLength(3));
    expect((transports.specs.last as McpStdioSpec).command, 'linear-v2');
    expect(store.user, hasLength(2));

    await service.saveUserServers(<McpServerConfigDto>[stdioServer]);
    await pumpEventQueue();

    expect(service.states().map((state) => state.config.id), <String>[
      'github',
    ]);
  });

  test('a failed server retries with a capped, jittered backoff', () async {
    store.user = <McpServerConfigDto>[
      const McpServerConfigDto(
        id: 'broken',
        transport: McpTransportKind.stdio,
        command: 'missing',
      ),
    ];
    transports.failFor.add('missing');
    final scheduled = <_ScheduledRetry>[];
    final service = build(
      timerFactory: (delay, run) {
        scheduled.add(_ScheduledRetry(delay, run));
        return _InertTimer();
      },
    );
    addTearDown(service.close);

    await service.initialize();
    await pumpEventQueue();

    // Drive the retries by hand so the schedule is observed exactly rather
    // than raced against real time.
    for (var round = 0; round < 9; round += 1) {
      scheduled.last.run();
      await pumpEventQueue();
    }

    final delays = scheduled.map((retry) => retry.delay).toList();
    expect(delays, hasLength(10));
    // Exponential from one second, ±20% jitter, capped at a minute.
    expect(delays[0].inMilliseconds, closeTo(1000, 200));
    expect(delays[1].inMilliseconds, closeTo(2000, 400));
    expect(delays[2].inMilliseconds, closeTo(4000, 800));
    expect(delays[3].inMilliseconds, closeTo(8000, 1600));
    for (final delay in delays) {
      expect(delay, lessThanOrEqualTo(const Duration(seconds: 72)));
    }
    expect(delays.last.inMilliseconds, closeTo(60000, 12000));
    expect(service.states().single.attempt, 10);
    expect(service.states().single.status, McpServerStatus.failed);
  });

  test('a manual retry resets the backoff and reconnects', () async {
    store.user = <McpServerConfigDto>[
      const McpServerConfigDto(
        id: 'broken',
        transport: McpTransportKind.stdio,
        command: 'missing',
      ),
    ];
    transports.failFor.add('missing');
    final service = build();
    addTearDown(service.close);
    await service.initialize();
    await pumpEventQueue();
    expect(service.states().single.attempt, 1);

    transports.failFor.clear();
    service.retry('broken');
    await pumpEventQueue();

    expect(service.states().single.status, McpServerStatus.ready);
    expect(service.states().single.attempt, 0);
    // Retrying an id that is not configured is a no-op, not a crash.
    service.retry('absent');
  });

  test('a lost connection is reported and retried', () async {
    store.user = <McpServerConfigDto>[stdioServer];
    final service = build();
    addTearDown(service.close);
    await service.initialize();
    await pumpEventQueue();
    expect(service.states().single.status, McpServerStatus.ready);

    transports.servers.single.transport.dropPeer('exited with code 1');
    await pumpEventQueue();

    expect(service.states().single.status, McpServerStatus.failed);
    expect(service.availableTools(), isEmpty);
    expect(service.states().single.nextRetryAt, isNotNull);
  });

  test('closing disposes every connection and is safe to repeat', () async {
    store.user = <McpServerConfigDto>[stdioServer];
    final service = build();
    await service.initialize();
    await pumpEventQueue();

    await service.close();
    await service.close();

    expect(service.states(), isEmpty);
    expect(service.availableTools(), isEmpty);
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

final class _ScheduledRetry {
  const new(this.delay, this.run);

  final Duration delay;
  final void Function() run;
}

final class _InertTimer implements Timer {
  @override
  void cancel() {}

  @override
  bool get isActive => true;

  @override
  int get tick => 0;
}

final class _FixedClock implements Clock {
  @override
  DateTime nowUtc() => DateTime.utc(2026, 8, 4, 12);
}

final class _MemoryConfigStore implements McpConfigStore {
  List<McpServerConfigDto> user = <McpServerConfigDto>[];

  @override
  String sourcePath(McpConfigScope scope, {String? rootPath}) =>
      scope == McpConfigScope.user
      ? '/config/mcp.json'
      : '${rootPath ?? ''}/.mcp.json';

  @override
  Future<McpConfigDocument> load(
    McpConfigScope scope, {
    String? rootPath,
  }) async => McpConfigDocument(
    scope: scope,
    sourcePath: sourcePath(scope, rootPath: rootPath),
    servers: scope == McpConfigScope.user ? user : const <McpServerConfigDto>[],
  );

  @override
  Future<void> save(McpConfigDocument document) async {
    user = document.servers;
  }

  @override
  Stream<void> watch(McpConfigScope scope, {String? rootPath}) =>
      const Stream<void>.empty();
}

final class _FakeCredentials implements CredentialRepository {
  @override
  final Map<String, String> mcpSecrets = <String, String>{};

  @override
  String? get bearerToken => null;

  @override
  ProviderCredential? credential(String connectionId) => null;

  @override
  Future<void> load() async {}

  @override
  Future<void> removeCredential(String connectionId) async {}

  @override
  Future<void> removeMcpSecret(String key) async {}

  @override
  Future<void> setCredential(
    String connectionId,
    ProviderCredential credential,
  ) async {}

  @override
  Future<void> setDaemonToken(String bearerToken) async {}

  @override
  Future<void> setMcpSecret(String key, String value) async {}
}

final class _FakeTransports implements McpTransportFactory {
  final List<McpTransportSpec> specs = <McpTransportSpec>[];
  final List<ScriptedMcpServer> servers = <ScriptedMcpServer>[];
  final Set<String> failFor = <String>{};
  bool stall = false;

  /// Answers the next connection with this server instead of a default one.
  ScriptedMcpServer? nextServer;

  @override
  McpTransport create(McpTransportSpec spec) {
    specs.add(spec);
    final command = spec is McpStdioSpec ? spec.command : '';
    if (failFor.contains(command)) return _UnstartableTransport();
    if (stall) return _StalledTransport();
    final server = nextServer ?? ScriptedMcpServer();
    nextServer = null;
    servers.add(server);
    return server.transport;
  }
}

final class _UnstartableTransport implements McpTransport {
  @override
  Stream<Map<String, dynamic>> get incoming =>
      const Stream<Map<String, dynamic>>.empty();

  @override
  Stream<String> get diagnostics => const Stream<String>.empty();

  @override
  Future<void> get done => Completer<void>().future;

  @override
  Future<void> start() async =>
      throw const McpTransportClosed('the server cannot start');

  @override
  Future<void> send(Map<String, dynamic> message) async {}

  @override
  Future<void> close() async {}
}

final class _StalledTransport implements McpTransport {
  @override
  Stream<Map<String, dynamic>> get incoming =>
      const Stream<Map<String, dynamic>>.empty();

  @override
  Stream<String> get diagnostics => const Stream<String>.empty();

  @override
  Future<void> get done => Completer<void>().future;

  @override
  Future<void> start() async {}

  @override
  Future<void> send(Map<String, dynamic> message) async {}

  @override
  Future<void> close() async {}
}
