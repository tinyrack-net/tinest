import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:daemon/src/features/mcp/infrastructure/mcp.dart';
import 'package:mocktail/mocktail.dart';
import 'package:process/process.dart';
import 'package:test/test.dart';

void main() {
  test('stdout lines decode into JSON-RPC messages', () async {
    final harness = _Harness();
    final transport = harness.transport;
    addTearDown(transport.close);

    final messages = <Map<String, dynamic>>[];
    final diagnostics = <String>[];
    transport
      ..incoming.listen(messages.add)
      ..diagnostics.listen(diagnostics.add);
    await transport.start();

    harness
      ..emitStdout('{"jsonrpc":"2.0","id":1,"result":{}}\n')
      ..emitStdout('\n')
      ..emitStdout('   \n');
    await pumpEventQueue();

    expect(messages.single['id'], 1);
    expect(diagnostics, isEmpty);
  });

  test('non-JSON and non-object stdout is reported, not fatal', () async {
    final harness = _Harness();
    final transport = harness.transport;
    addTearDown(transport.close);

    final messages = <Map<String, dynamic>>[];
    final diagnostics = <String>[];
    transport
      ..incoming.listen(messages.add)
      ..diagnostics.listen(diagnostics.add);
    await transport.start();

    harness
      ..emitStdout('server listening on stdio\n')
      ..emitStdout('[1,2,3]\n')
      ..emitStdout('{"id":7,"result":{}}\n');
    await pumpEventQueue();

    expect(messages.single['id'], 7);
    expect(diagnostics, hasLength(2));
    expect(diagnostics.first, contains('non-JSON stdout'));
    expect(diagnostics.last, contains('non-object stdout'));
  });

  test('sending writes one newline-terminated JSON line', () async {
    final harness = _Harness();
    final transport = harness.transport;
    addTearDown(transport.close);
    await transport.start();

    await transport.send(<String, dynamic>{'id': 1, 'method': 'ping'});

    expect(harness.written, '{"id":1,"method":"ping"}\n');
    verify(harness.stdin.flush).called(1);
  });

  test('sending before start or after close is refused', () async {
    final harness = _Harness();
    final transport = harness.transport;

    await expectLater(
      transport.send(<String, dynamic>{}),
      throwsA(isA<McpTransportClosed>()),
    );

    await transport.start();
    await transport.close();
    await expectLater(
      transport.send(<String, dynamic>{}),
      throwsA(isA<McpTransportClosed>()),
    );
    expect(transport.start(), throwsA(isA<McpTransportClosed>()));
    await transport.close();
  });

  test('starting twice reuses the single child process', () async {
    final harness = _Harness();
    final transport = harness.transport;
    addTearDown(transport.close);

    await transport.start();
    await transport.start();

    verify(
      () => harness.manager.start(
        <String>['server', '--flag'],
        workingDirectory: '/workspace',
        environment: <String, String>{'TOKEN': 'secret'},
      ),
    ).called(1);
  });

  test('a spec without an environment inherits the parent one', () async {
    final harness = _Harness(spec: const McpStdioSpec(command: 'server'));
    final transport = harness.transport;
    addTearDown(transport.close);

    await transport.start();

    // A null environment is what makes the child inherit the daemon's.
    verify(() => harness.manager.start(<String>['server'])).called(1);
  });

  test('the stderr ring buffer stays bounded', () async {
    final harness = _Harness();
    final transport = harness.transport;
    addTearDown(transport.close);
    await transport.start();

    for (var index = 0; index < 150; index += 1) {
      harness.emitStderr('line $index\n');
    }
    await pumpEventQueue();

    expect(
      transport.retainedDiagnostics,
      hasLength(StdioMcpTransport.maxRetainedDiagnostics),
    );
    expect(transport.retainedDiagnostics.last, 'line 149');
    expect(transport.retainedDiagnostics.first, 'line 50');
  });

  test('an oversized stderr burst is trimmed by bytes as well', () async {
    final harness = _Harness();
    final transport = harness.transport;
    addTearDown(transport.close);
    await transport.start();

    final wide = 'x' * 40000;
    harness
      ..emitStderr('$wide\n')
      ..emitStderr('$wide\n')
      ..emitStderr('tail\n');
    await pumpEventQueue();

    expect(transport.retainedDiagnostics.last, 'tail');
    expect(
      transport.retainedDiagnostics.fold<int>(
        0,
        (total, entry) => total + entry.length,
      ),
      lessThanOrEqualTo(StdioMcpTransport.maxRetainedDiagnosticBytes),
    );
  });

  test('a child that exits completes done and reports its code', () async {
    final harness = _Harness(exitCode: Future<int>.value(3));
    final transport = harness.transport;
    addTearDown(transport.close);

    final diagnostics = <String>[];
    transport.diagnostics.listen(diagnostics.add);
    await transport.start();
    await transport.done;

    expect(diagnostics, contains('the server exited with code 3'));
    expect(transport.retainedDiagnostics.last, contains('code 3'));
  });

  test('a closed stdout is reported while the child lingers', () async {
    final harness = _Harness();
    final transport = harness.transport;
    addTearDown(transport.close);

    final diagnostics = <String>[];
    transport.diagnostics.listen(diagnostics.add);
    await transport.start();
    await harness.closeStdout();
    await pumpEventQueue();

    expect(diagnostics, contains('the server closed its stdout'));
  });

  test('a child that ignores termination is killed outright', () async {
    final harness = _Harness(exitCode: Completer<int>().future);
    final transport = harness.transport;

    await transport.start();
    await transport.close();

    verify(harness.process.kill).called(1);
    verify(() => harness.process.kill(ProcessSignal.sigkill)).called(1);
  });

  test('a real child process is framed correctly end to end', () async {
    final transport = StdioMcpTransport(
      McpStdioSpec(
        command: Platform.resolvedExecutable,
        // Directly, not through `dart run`: the script imports nothing but
        // dart:*, so it needs no package resolution.
        args: <String>['test/features/mcp/support/echo_mcp_server.dart'],
      ),
    );
    final client = McpClient(transport: transport);
    addTearDown(client.close);

    final identity = await client.connect();
    expect(identity.name, 'echo');
    expect(client.tools.single.name, 'echo');

    final result = await client.callTool('echo', <String, dynamic>{
      'value': 'round trip',
    });
    expect((result.content.single as McpTextContent).text, 'round trip');
  }, timeout: const Timeout(Duration(minutes: 2)));
}

final class _Harness {
  new({
    McpStdioSpec spec = const McpStdioSpec(
      command: 'server',
      args: <String>['--flag'],
      env: <String, String>{'TOKEN': 'secret'},
      workingDirectory: '/workspace',
    ),
    Future<int>? exitCode,
  }) {
    registerFallbackValue(ProcessSignal.sigterm);
    when(
      () => manager.start(
        any(),
        workingDirectory: any(named: 'workingDirectory'),
        environment: any(named: 'environment'),
      ),
    ).thenAnswer((_) async => process);
    when(() => process.stdout).thenAnswer((_) => _stdout.stream);
    when(() => process.stderr).thenAnswer((_) => _stderr.stream);
    when(() => process.stdin).thenReturn(stdin);
    when(() => process.exitCode)
        .thenAnswer((_) => exitCode ?? Completer<int>().future);
    when(() => process.kill(any())).thenReturn(true);
    when(stdin.flush).thenAnswer((_) async {});
    when(() => stdin.write(any<Object?>())).thenAnswer((invocation) {
      written += invocation.positionalArguments.first as String;
    });
    transport = StdioMcpTransport(
      spec,
      processManager: manager,
      terminationGrace: const Duration(milliseconds: 20),
    );
  }

  final ProcessManager manager = _MockProcessManager();
  final Process process = _MockProcess();
  final IOSink stdin = _MockIOSink();
  final StreamController<List<int>> _stdout =
      StreamController<List<int>>.broadcast();
  final StreamController<List<int>> _stderr =
      StreamController<List<int>>.broadcast();

  late final StdioMcpTransport transport;
  String written = '';

  void emitStdout(String text) => _stdout.add(utf8.encode(text));

  void emitStderr(String text) => _stderr.add(utf8.encode(text));

  Future<void> closeStdout() => _stdout.close();
}

final class _MockProcessManager extends Mock implements ProcessManager;

final class _MockProcess extends Mock implements Process;

final class _MockIOSink extends Mock implements IOSink;
