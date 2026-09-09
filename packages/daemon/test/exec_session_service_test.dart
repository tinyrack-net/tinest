@Tags(<String>['feature_test__tool_exec_session__unit'])
library;

import 'dart:async';
import 'dart:io' show ProcessException;

import 'package:agent/agent.dart';
import 'package:daemon/src/features/sessions/infrastructure/exec_session_service.dart';
import 'package:daemon/src/features/terminals/application/terminal_service.dart';
import 'package:daemon/src/features/terminals/domain/terminal.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  late _FakeGateway gateway;
  late _FakePipeGateway pipes;
  late _StepClock clock;
  late ExecSessionService service;

  setUp(() {
    gateway = _FakeGateway();
    pipes = _FakePipeGateway();
    clock = _StepClock();
    service = ExecSessionService(
      gateway: gateway,
      pipes: pipes,
      clock: clock,
      isWindows: false,
    );
  });

  tearDown(() => service.close());

  test('a command runs in a POSIX login shell in the workspace', () async {
    await service.start(
      owner: 'session-1',
      command: 'echo hi',
      workingDirectory: '/workspace',
      tty: true,
    );

    expect(gateway.started.single.shell.executable, '/bin/sh');
    expect(gateway.started.single.shell.arguments, <String>['-lc', 'echo hi']);
    expect(gateway.started.single.workingDirectory, '/workspace');
  });

  test('a Windows host runs the command through PowerShell', () async {
    final windows = ExecSessionService(
      gateway: gateway,
      pipes: pipes,
      clock: clock,
      isWindows: true,
    );
    addTearDown(windows.close);

    await windows.start(
      owner: 'session-1',
      command: 'dir',
      workingDirectory: r'C:\workspace',
      tty: true,
    );

    expect(gateway.started.single.shell.executable, 'powershell.exe');
    expect(gateway.started.single.shell.arguments, <String>[
      '-NonInteractive',
      '-Command',
      'dir',
    ]);
  });

  test('a read drains buffered output and reports the exit code', () async {
    final session = await service.start(
      owner: 'session-1',
      command: 'echo hi',
      workingDirectory: '/workspace',
      tty: true,
    );
    final process = gateway.started.single.process
      ..emit('hi\n')
      ..finish(0);
    await pumpEventQueue();

    final chunk = await session.read(const Duration(seconds: 5));
    expect(chunk.output, 'hi\n');
    expect(chunk.isRunning, isFalse);
    expect(chunk.exitCode, 0);

    // A second read returns nothing new but still reports the exit.
    final again = await session.read(const Duration(seconds: 5));
    expect(again.output, isEmpty);
    expect(again.exitCode, 0);
    expect(process.terminated, isFalse);
  });

  test('a read of a running command returns after the wait', () async {
    final session = await service.start(
      owner: 'session-1',
      command: 'python3',
      workingDirectory: '/workspace',
      tty: true,
    );
    gateway.started.single.process.emit('>>> ');
    await pumpEventQueue();

    final chunk = await session.read(const Duration(milliseconds: 20));
    expect(chunk.output, '>>> ');
    expect(chunk.isRunning, isTrue);
    expect(chunk.exitCode, isNull);

    await session.write('2 + 2\n');
    expect(gateway.started.single.process.input, <String>['2 + 2\n']);
  });

  test('an interrupt sends ETX and leaves the session alive', () async {
    final session = await service.start(
      owner: 'session-1',
      command: 'sleep 100',
      workingDirectory: '/workspace',
      tty: true,
    );

    await session.interrupt();

    expect(gateway.started.single.process.input, <String>[
      String.fromCharCode(0x03),
    ]);
    expect(service.lookup('session-1', session.id), isNotNull);
  });

  test('output produced between reads is capped at the tail', () async {
    final session = await service.start(
      owner: 'session-1',
      command: 'yes',
      workingDirectory: '/workspace',
      tty: true,
    );
    final process = gateway.started.single.process;
    // Well past the shared tool-output ceiling.
    for (var index = 0; index < 3; index += 1) {
      process.emit('${'x' * (maxExecSessionOutputBytes ~/ 2)}$index');
    }
    await pumpEventQueue();

    final chunk = await session.read(const Duration(milliseconds: 10));
    expect(chunk.output.length, lessThanOrEqualTo(maxExecSessionOutputBytes));
    // The newest bytes survive; the oldest are dropped.
    expect(chunk.output, endsWith('2'));
  });

  test('sessions are isolated between tinest sessions', () async {
    final mine = await service.start(
      owner: 'session-1',
      command: 'sh',
      workingDirectory: '/workspace',
      tty: true,
    );

    expect(service.lookup('session-1', mine.id), isNotNull);
    expect(service.lookup('session-2', mine.id), isNull);

    final host = SessionExecHost(service, 'session-2');
    expect(host.lookup(mine.id), isNull);
    final theirs = await host.start(
      command: 'sh',
      workingDirectory: '/workspace',
      tty: true,
    );
    expect(host.lookup(theirs.id), isNotNull);
    expect(SessionExecHost(service, 'session-1').lookup(theirs.id), isNull);
  });

  test('an approved session id survives until the session ends', () async {
    final session = await service.start(
      owner: 'session-1',
      command: 'sh',
      workingDirectory: '/workspace',
      tty: true,
    );

    expect(service.isApproved(session.id), isFalse);
    service.markApproved(session.id);
    expect(service.isApproved(session.id), isTrue);

    await service.closeOwner('session-1');
    // Approval never outlives the terminal it was granted for.
    expect(service.isApproved(session.id), isFalse);
    expect(service.lookup('session-1', session.id), isNull);
  });

  test('an idle session is reclaimed on the next start', () async {
    final idle = await service.start(
      owner: 'session-1',
      command: 'sh',
      workingDirectory: '/workspace',
      tty: true,
    );
    final idleProcess = gateway.started.single.process;

    clock.advance(execSessionIdleTimeout + const Duration(minutes: 1));
    await service.start(
      owner: 'session-1',
      command: 'sh',
      workingDirectory: '/workspace',
      tty: true,
    );
    await pumpEventQueue();

    expect(service.lookup('session-1', idle.id), isNull);
    expect(idleProcess.terminated, isTrue);
  });

  test('the oldest session is evicted once the cap is reached', () async {
    final sessions = <ExecSession>[];
    for (var index = 0; index < maxExecSessionsPerSession; index += 1) {
      sessions.add(
        await service.start(
          owner: 'session-1',
          command: 'sh $index',
          workingDirectory: '/workspace',
          tty: true,
        ),
      );
      clock.advance(const Duration(seconds: 1));
    }

    await service.start(
      owner: 'session-1',
      command: 'sh extra',
      workingDirectory: '/workspace',
      tty: true,
    );

    expect(service.lookup('session-1', sessions.first.id), isNull);
    expect(service.lookup('session-1', sessions.last.id), isNotNull);
  });

  test('closing terminates every owned pseudo-terminal', () async {
    await service.start(
      owner: 'session-1',
      command: 'sh',
      workingDirectory: '/workspace',
      tty: true,
    );
    await service.start(
      owner: 'session-2',
      command: 'sh',
      workingDirectory: '/workspace',
      tty: true,
    );

    await service.close();
    await pumpEventQueue();

    expect(
      gateway.started.map((start) => start.process.terminated),
      everyElement(isTrue),
    );
  });

  test('a process that fails still reports a terminal state', () async {
    final session = await service.start(
      owner: 'session-1',
      command: 'missing',
      workingDirectory: '/workspace',
      tty: true,
    );
    gateway.started.single.process.fail(const ProcessException('missing', []));
    await pumpEventQueue();

    final chunk = await session.read(const Duration(milliseconds: 10));
    expect(chunk.isRunning, isFalse);
    expect(chunk.exitCode, -1);
  });

  test('a command without a tty runs on pipes, not a terminal', () async {
    final session = await service.start(
      owner: 'session-1',
      command: 'echo hi',
      workingDirectory: '/workspace/packages',
      tty: false,
    );

    expect(gateway.started, isEmpty);
    expect(pipes.started.single.shell.executable, '/bin/sh');
    expect(pipes.started.single.shell.arguments, <String>['-lc', 'echo hi']);
    expect(pipes.started.single.workingDirectory, '/workspace/packages');

    pipes.started.single.process
      ..emit('hi\n')
      ..finish(0);
    await pumpEventQueue();

    final chunk = await session.read(const Duration(seconds: 5));
    expect(chunk.output, 'hi\n');
    expect(chunk.exitCode, 0);
  });

  test('a pipe session shares the terminal close lifecycle', () async {
    await service.start(
      owner: 'session-1',
      command: 'sh',
      workingDirectory: '/workspace',
      tty: false,
    );

    await service.closeOwner('session-1');
    await pumpEventQueue();

    expect(pipes.started.single.process.terminated, isTrue);
  });

  test('interrupting a pipe session signals rather than writes', () async {
    final session = await service.start(
      owner: 'session-1',
      command: 'sleep 100',
      workingDirectory: '/workspace',
      tty: false,
    );

    await session.interrupt();

    // On a pipe there is no line discipline to turn ETX into SIGINT, so
    // writing the byte would leave the command running.
    expect(pipes.started.single.process.input, isEmpty);
    expect(pipes.started.single.process.interrupts, 1);
    expect(service.lookup('session-1', session.id), isNotNull);
  });

  test('a read reports how long it waited', () async {
    final session = await service.start(
      owner: 'session-1',
      command: 'sleep 1',
      workingDirectory: '/workspace',
      tty: true,
    );
    // The clock only moves when the test says so, so the reported wall time is
    // exactly the step taken across the wait.
    clock.advanceOnNextRead = const Duration(milliseconds: 750);

    final chunk = await session.read(const Duration(milliseconds: 10));

    expect(chunk.wallTime, const Duration(milliseconds: 750));
  });

  test('the tail truncation helper keeps whole characters', () {
    expect(truncateTailToBytes('abc', 10), 'abc');
    // '가' is three UTF-8 bytes, so a four-byte window cannot include it whole.
    expect(truncateTailToBytes('가나', 4), '나');
  });
}

final class _StepClock implements Clock {
  DateTime _now = DateTime.utc(2026, 8, 3);

  /// Applied once, immediately after the next reading.
  ///
  /// This is how a test makes time pass *inside* a call without a real delay.
  Duration? advanceOnNextRead;

  void advance(Duration duration) => _now = _now.add(duration);

  @override
  DateTime nowUtc() {
    final now = _now;
    final pending = advanceOnNextRead;
    if (pending != null) {
      advanceOnNextRead = null;
      _now = _now.add(pending);
    }
    return now;
  }
}

final class _FakePipeGateway implements PipeGateway {
  final List<_StartedPipe> started = <_StartedPipe>[];

  @override
  Future<ExecProcess> start({
    required ShellSpecDto shell,
    required String workingDirectory,
  }) async {
    final process = _FakePipeProcess();
    started.add(
      _StartedPipe(
        shell: shell,
        workingDirectory: workingDirectory,
        process: process,
      ),
    );
    return process;
  }
}

final class _StartedPipe {
  new({
    required this.shell,
    required this.workingDirectory,
    required this.process,
  });

  final ShellSpecDto shell;
  final String workingDirectory;
  final _FakePipeProcess process;
}

final class _FakePipeProcess implements ExecProcess {
  final StreamController<String> _output = StreamController<String>();
  final Completer<int> _exit = Completer<int>();
  final List<String> input = <String>[];
  int interrupts = 0;
  bool terminated = false;

  void emit(String data) => _output.add(data);

  void finish(int code) {
    if (!_exit.isCompleted) _exit.complete(code);
  }

  @override
  Stream<String> get outputs => _output.stream;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  Future<void> write(String data) async => input.add(data);

  @override
  Future<void> interrupt() async => interrupts += 1;

  @override
  Future<void> terminate() async {
    if (terminated) return;
    terminated = true;
    finish(0);
    await _output.close();
  }
}

final class _FakeGateway implements TerminalGateway {
  final List<_StartedTerminal> started = <_StartedTerminal>[];

  @override
  Future<TerminalProcess> start({
    required TerminalShell shell,
    required String workingDirectory,
    required int columns,
    required int rows,
  }) async {
    final process = _FakeProcess();
    started.add(
      _StartedTerminal(
        shell: shell,
        workingDirectory: workingDirectory,
        process: process,
      ),
    );
    return process;
  }
}

final class _StartedTerminal {
  new({
    required this.shell,
    required this.workingDirectory,
    required this.process,
  });

  final TerminalShell shell;
  final String workingDirectory;
  final _FakeProcess process;
}

final class _FakeProcess implements TerminalProcess {
  final StreamController<String> _output = StreamController<String>();
  final Completer<int> _exit = Completer<int>();
  final List<String> input = <String>[];
  bool terminated = false;

  void emit(String data) => _output.add(data);

  void finish(int code) {
    if (!_exit.isCompleted) _exit.complete(code);
  }

  void fail(Object error) {
    if (!_exit.isCompleted) _exit.completeError(error);
  }

  @override
  Stream<String> get outputs => _output.stream;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  Future<void> write(String data) async => input.add(data);

  @override
  Future<void> interrupt() async => input.add(String.fromCharCode(0x03));

  @override
  Future<void> resize(int columns, int rows) async {}

  @override
  Future<void> terminate() async {
    if (terminated) return;
    terminated = true;
    finish(0);
    await _output.close();
  }
}
