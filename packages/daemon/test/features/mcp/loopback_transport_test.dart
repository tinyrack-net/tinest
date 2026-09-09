import 'package:daemon/src/features/mcp/infrastructure/mcp.dart';
import 'package:test/test.dart';

void main() {
  test('a started loopback transport carries messages both ways', () async {
    final received = <Map<String, dynamic>>[];
    final transport = LoopbackMcpTransport(received.add);
    addTearDown(transport.close);

    final incoming = <Map<String, dynamic>>[];
    final diagnostics = <String>[];
    transport
      ..incoming.listen(incoming.add)
      ..diagnostics.listen(diagnostics.add);

    await transport.start();
    await transport.send(<String, dynamic>{'id': 1});
    transport
      ..deliver(<String, dynamic>{'result': 'ok'})
      ..reportDiagnostic('a note');
    await pumpEventQueue();

    expect(received.single, <String, dynamic>{'id': 1});
    expect(transport.sent.single, <String, dynamic>{'id': 1});
    expect(incoming.single, <String, dynamic>{'result': 'ok'});
    expect(diagnostics.single, 'a note');
  });

  test('an unstarted or closed transport refuses to send', () async {
    final unstarted = LoopbackMcpTransport((_) {});
    expect(
      unstarted.send(<String, dynamic>{}),
      throwsA(isA<McpTransportClosed>()),
    );
    await unstarted.close();

    expect(unstarted.start(), throwsA(isA<McpTransportClosed>()));
    expect(
      unstarted.send(<String, dynamic>{}),
      throwsA(isA<McpTransportClosed>()),
    );
    expect(const McpTransportClosed('why').toString(), contains('why'));
    expect(const McpTransportClosed().toString(), 'McpTransportClosed');
  });

  test('closing completes done and is safe to repeat', () async {
    final transport = LoopbackMcpTransport((_) {});
    await transport.start();
    await transport.close();
    await transport.close();
    await expectLater(transport.done, completes);

    // Post-close delivery is dropped rather than throwing on a dead sink.
    transport
      ..deliver(<String, dynamic>{'ignored': true})
      ..reportDiagnostic('ignored')
      ..dropPeer('ignored');
  });

  test('dropping the peer completes done and reports the reason', () async {
    final transport = LoopbackMcpTransport((_) {});
    final diagnostics = <String>[];
    transport.diagnostics.listen(diagnostics.add);
    await transport.start();

    transport.dropPeer('exited with code 1');
    await pumpEventQueue();

    expect(diagnostics.single, 'exited with code 1');
    await expectLater(transport.done, completes);
  });

  test('transport specs describe stdio and HTTP servers', () {
    const stdio = McpStdioSpec(command: 'npx', args: <String>['-y', 'server']);
    expect(stdio.command, 'npx');
    expect(stdio.args, <String>['-y', 'server']);
    expect(stdio.env, isEmpty);
    expect(stdio.workingDirectory, isNull);

    final http = McpHttpSpec(
      url: Uri.parse('https://example.test/mcp'),
      headers: const <String, String>{'Authorization': 'Bearer x'},
    );
    expect(http.url.host, 'example.test');
    expect(http.headers['Authorization'], 'Bearer x');
    expect(<McpTransportSpec>[stdio, http], hasLength(2));
  });
}
