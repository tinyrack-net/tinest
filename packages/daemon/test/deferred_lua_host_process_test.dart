@Tags(<String>[
  'feature_test__plugin_runtime__unit',
  'feature_test__lua_tool_orchestration__unit',
])
library;

import 'dart:async';

import 'package:daemon/src/shared/infrastructure/deferred_lua_host_process.dart';
import 'package:lua_tool_runtime/lua_tool_runtime.dart' as lua;
import 'package:test/test.dart';

void main() {
  test('host resolution is deferred and shared by concurrent starts', () async {
    final delegate = _RecordingLauncher();
    final resolution = Completer<lua.LuaHostCommand>();
    var resolverCalls = 0;
    final launcher = DeferredLuaHostProcessLauncher(() {
      resolverCalls += 1;
      return resolution.future;
    }, delegate);

    expect(resolverCalls, 0);
    expect(delegate.commands, isEmpty);

    final first = launcher.start(
      const lua.LuaHostCommand(
        executable: 'unresolved-host-must-not-run',
        environment: <String, String>{'first-limit': '1'},
      ),
      workingDirectory: 'first-workspace',
    );
    final second = launcher.start(
      const lua.LuaHostCommand(
        executable: 'unresolved-host-must-not-run',
        environment: <String, String>{'second-limit': '2'},
      ),
      workingDirectory: 'second-workspace',
    );
    await pumpEventQueue();

    expect(resolverCalls, 1);
    expect(delegate.commands, isEmpty);

    resolution.complete(
      const lua.LuaHostCommand(
        executable: 'resolved-host',
        arguments: <String>['bootstrap.lua'],
        environment: <String, String>{'base': 'true'},
      ),
    );
    await Future.wait(<Future<lua.LuaHostProcess>>[first, second]);

    expect(
      delegate.commands.map((command) => command.executable),
      everyElement('resolved-host'),
    );
    expect(
      delegate.commands.map((command) => command.arguments),
      everyElement(<String>['bootstrap.lua']),
    );
    expect(delegate.commands[0].environment, <String, String>{
      'base': 'true',
      'first-limit': '1',
    });
    expect(delegate.commands[1].environment, <String, String>{
      'base': 'true',
      'second-limit': '2',
    });
    expect(delegate.workingDirectories, <String>[
      'first-workspace',
      'second-workspace',
    ]);
  });

  test('a failed deferred resolution is retried by the next start', () async {
    final delegate = _RecordingLauncher();
    var resolverCalls = 0;
    final launcher = DeferredLuaHostProcessLauncher(() async {
      resolverCalls += 1;
      if (resolverCalls == 1) throw StateError('staging failed');
      return const lua.LuaHostCommand(executable: 'resolved-host');
    }, delegate);

    await expectLater(
      launcher.start(
        const lua.LuaHostCommand(executable: 'unresolved-host-must-not-run'),
        workingDirectory: 'workspace',
      ),
      throwsStateError,
    );
    expect(delegate.commands, isEmpty);

    await launcher.start(
      const lua.LuaHostCommand(executable: 'unresolved-host-must-not-run'),
      workingDirectory: 'workspace',
    );

    expect(resolverCalls, 2);
    expect(delegate.commands.single.executable, 'resolved-host');
  });
}

final class _RecordingLauncher implements lua.LuaHostProcessLauncher {
  new() : process = _RecordingProcess();

  final _RecordingProcess process;
  final List<lua.LuaHostCommand> commands = <lua.LuaHostCommand>[];
  final List<String> workingDirectories = <String>[];

  @override
  Future<lua.LuaHostProcess> start(
    lua.LuaHostCommand command, {
    required String workingDirectory,
  }) async {
    commands.add(command);
    workingDirectories.add(workingDirectory);
    return process;
  }
}

final class _RecordingProcess implements lua.LuaHostProcess {
  @override
  Future<int> get exitCode => Future<int>.value(0);

  @override
  Stream<String> get outputs => const Stream<String>.empty();

  @override
  String get diagnostics => '';

  @override
  Future<void> terminate() async {}

  @override
  Future<void> write(String value) async {}
}
