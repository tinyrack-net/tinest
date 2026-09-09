@Tags(<String>[
  'feature_test__lua_tool_orchestration__contract',
  'feature_test__lua_tool_orchestration__unit',
])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agent/agent.dart';
import 'package:daemon/src/features/sessions/infrastructure/lua_code_mode_service.dart';
import 'package:lua_tool_runtime/lua_tool_runtime.dart' as lua;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late _PipeGateway pipes;
  late LuaCodeModeService service;

  setUp(() {
    pipes = _PipeGateway();
    service = LuaCodeModeService(
      lua.LuaToolRuntime<ConversationAttachment>(
        host: const lua.LuaHostCommand(
          executable: 'lua-tool-runtime-host',
          arguments: <String>['bootstrap.lua'],
        ),
        processLauncher: pipes,
        clock: const lua.SystemLuaClock(),
        ids: _Ids(),
      ),
    );
  });

  tearDown(() => service.close());

  test("losing the staging promotion race uses the winner's cache", () async {
    // `dart test` runs VM suites as isolates of one process. Neither guard here
    // survives that: `_developmentLuaHostStages` is top-level state, so each
    // isolate has its own copy, and a POSIX fcntl lock is held per process, so
    // isolates of the same process never exclude each other. Every suite
    // therefore stages, and only the first `rename` onto the shared cache can
    // win -- the rest hit ENOTEMPTY.
    //
    // This showed up the moment Dart coverage went from --concurrency=1 to 4:
    // `FileSystemException: Rename failed ... Directory not empty, errno = 39`
    // reached a client as a bare "Internal daemon error."
    final workspace = Directory.systemTemp.createTempSync('tinest-lua-race-');
    addTearDown(() => workspace.deleteSync(recursive: true));
    File(p.join(workspace.path, '.dart_tool', 'package_config.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        jsonEncode(<String, Object?>{
          'configVersion': 2,
          'packages': <Map<String, Object?>>[
            <String, Object?>{
              'name': 'lua_tool_runtime',
              'rootUri': '../runtime/',
              'packageUri': 'lib/',
              'languageVersion': '3.12',
            },
          ],
        }),
      );
    File(p.join(workspace.path, 'runtime', 'native', 'bootstrap.lua'))
        .createSync(recursive: true);
    final stager = _RaceLosingLuaHostStager();

    final command = await resolveLuaHostCommand(
      sourceRoot: workspace.path,
      stager: stager,
    );

    expect(stager.calls, 1);
    expect(File(command.executable).existsSync(), isTrue);
    expect(File(command.arguments.single).existsSync(), isTrue);
    expect(p.isWithin(stager.cacheRoot!, command.executable), isTrue);
  });

  test('development discovery stages the pinned native Lua host', () async {
    final workspace = Directory.systemTemp.createTempSync(
      'tinest-lua-discovery-',
    );
    addTearDown(() => workspace.deleteSync(recursive: true));
    File(p.join(workspace.path, '.dart_tool', 'package_config.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        jsonEncode(<String, Object?>{
          'configVersion': 2,
          'packages': <Map<String, Object?>>[
            <String, Object?>{
              'name': 'lua_tool_runtime',
              'rootUri': '../runtime/',
              'packageUri': 'lib/',
              'languageVersion': '3.12',
            },
          ],
        }),
      );
    File(p.join(workspace.path, 'runtime', 'native', 'bootstrap.lua'))
        .createSync(recursive: true);
    final staging = _LuaHostStager();
    final command = await resolveLuaHostCommand(
      sourceRoot: p.join(workspace.path, 'test'),
      stager: staging,
    );
    final cached = await resolveLuaHostCommand(
      sourceRoot: workspace.path,
      stager: staging,
    );

    expect(staging.calls, 1);
    expect(cached.executable, command.executable);
    expect(
      command.executable,
      endsWith(
        Platform.isWindows
            ? 'lua-tool-runtime-host.exe'
            : 'lua-tool-runtime-host',
      ),
    );
    expect(
      command.arguments.single,
      endsWith(
        <String>[
          'lua_tool_runtime',
          'bootstrap.lua',
        ].join(Platform.pathSeparator),
      ),
    );
    expect(command.executable, isNot(anyOf('lua', 'lua.exe')));
  });

  test('packaged host is returned without scanning or staging', () async {
    final bundle = Directory.systemTemp.createTempSync('tinest-lua-packaged-');
    addTearDown(() => bundle.deleteSync(recursive: true));
    final executableDirectory = Directory(p.join(bundle.path, 'bin'))
      ..createSync(recursive: true);
    final distribution = _writeDistribution(executableDirectory.path);
    final stager = _LuaHostStager();

    final command = await resolveLuaHostCommand(
      sourceRoot: p.join(bundle.path, 'missing-source-root'),
      resolvedExecutable: p.join(executableDirectory.path, 'tinest'),
      stager: stager,
    );

    expect(command.executable, distribution.hostPath);
    expect(command.arguments, <String>[distribution.bootstrapPath]);
    expect(stager.calls, 0);
  });

  test('concurrent development discovery stages one distribution', () async {
    final workspace = _developmentWorkspace('tinest-lua-concurrent-');
    addTearDown(() => workspace.deleteSync(recursive: true));
    final staging = _BlockingLuaHostStager();

    final first = resolveLuaHostCommand(
      sourceRoot: workspace.path,
      stager: staging,
    );
    await staging.started.future;
    final second = resolveLuaHostCommand(
      sourceRoot: p.join(workspace.path, 'nested'),
      stager: staging,
    );
    await pumpEventQueue();

    expect(staging.calls, 1);
    staging.release.complete();
    final commands = await Future.wait(<Future<lua.LuaHostCommand>>[
      first,
      second,
    ]).timeout(const Duration(seconds: 5));

    expect(staging.calls, 1);
    expect(commands[1].executable, commands[0].executable);
    expect(commands[1].arguments, commands[0].arguments);
  });

  test('development build uses a fresh short system-temp directory', () async {
    final workspace = _developmentWorkspace('tinest-lua-short-build-');
    addTearDown(() => workspace.deleteSync(recursive: true));
    final staging = _LuaHostStager();

    await resolveLuaHostCommand(sourceRoot: workspace.path, stager: staging);

    final buildDirectory = staging.buildDirectories.single;
    expect(
      p.equals(p.dirname(buildDirectory), Directory.systemTemp.absolute.path),
      isTrue,
    );
    expect(p.basename(buildDirectory), startsWith('tinest-lua-'));
    expect(p.basename(buildDirectory).length, lessThanOrEqualTo(48));
    expect(p.isWithin(workspace.path, buildDirectory), isFalse);
    expect(Directory(buildDirectory).existsSync(), isFalse);
  });

  test(
    'failed staging leaves no partial cache and a fresh retry succeeds',
    () async {
      final workspace = _developmentWorkspace('tinest-lua-retry-');
      addTearDown(() => workspace.deleteSync(recursive: true));
      final staging = _FailOnceLuaHostStager();

      await expectLater(
        resolveLuaHostCommand(sourceRoot: workspace.path, stager: staging),
        throwsStateError,
      );

      expect(staging.calls, 1);
      final failedDestination = staging.destinations.single;
      final cacheRoot = p.join(
        p.dirname(failedDestination),
        Platform.operatingSystem,
      );
      expect(Directory(failedDestination).existsSync(), isFalse);
      expect(Directory(cacheRoot).existsSync(), isFalse);
      final command = await resolveLuaHostCommand(
        sourceRoot: workspace.path,
        stager: staging,
      );

      expect(staging.calls, 2);
      expect(staging.destinations[1], isNot(staging.destinations[0]));
      expect(File(command.executable).existsSync(), isTrue);
      expect(File(command.arguments.single).existsSync(), isTrue);
      expect(p.isWithin(cacheRoot, command.executable), isTrue);
    },
  );

  test(
    'Windows CMake locator discovers Visual Studio through vswhere',
    () async {
      final programFiles = Directory.systemTemp.createTempSync(
        'tinest-cmake-locator-',
      );
      addTearDown(() => programFiles.deleteSync(recursive: true));
      final vswhere = File(
        p.join(
          programFiles.path,
          'Microsoft Visual Studio',
          'Installer',
          'vswhere.exe',
        ),
      )..createSync(recursive: true);
      final calls = <({String executable, List<String> arguments})>[];
      final expected = p.join(
        programFiles.path,
        'Microsoft Visual Studio',
        '2022',
        'BuildTools',
        'Common7',
        'IDE',
        'CommonExtensions',
        'Microsoft',
        'CMake',
        'CMake',
        'bin',
        'cmake.exe',
      );

      final resolved = await resolveLuaHostCmakeExecutable(
        isWindows: true,
        environment: <String, String>{'ProgramFiles(x86)': programFiles.path},
        processRunner: (executable, arguments) async {
          calls.add((executable: executable, arguments: arguments));
          if (executable == 'where.exe') {
            return ProcessResult(1, 1, '', 'not found');
          }
          return ProcessResult(2, 0, '$expected\r\n', '');
        },
      );

      expect(resolved, expected);
      expect(calls, hasLength(2));
      expect(calls[1].executable, vswhere.path);
      expect(
        calls[1].arguments,
        containsAllInOrder(<String>[
          '-requires',
          'Microsoft.VisualStudio.Component.VC.CMake.Project',
          '-find',
          r'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe',
        ]),
      );
    },
  );

  test('macOS discovery reads bootstrap from app resources', () async {
    final bundle = Directory.systemTemp.createTempSync('tinest-lua-bundle-');
    addTearDown(() => bundle.deleteSync(recursive: true));
    final executableDirectory = Directory(
      p.join(bundle.path, 'Tinest.app', 'Contents', 'MacOS'),
    )..createSync(recursive: true);
    final helper = File(
      p.join(
        executableDirectory.path,
        Platform.isWindows
            ? 'lua-tool-runtime-host.exe'
            : 'lua-tool-runtime-host',
      ),
    )..createSync();
    final bootstrap = File(
      p.join(
        bundle.path,
        'Tinest.app',
        'Contents',
        'Resources',
        'lua_tool_runtime',
        'bootstrap.lua',
      ),
    )..createSync(recursive: true);

    final command = await resolveLuaHostCommand(
      sourceRoot: bundle.path,
      resolvedExecutable: p.join(executableDirectory.path, 'Tinest'),
      isMacOS: true,
    );

    expect(command.executable, helper.path);
    expect(command.arguments, <String>[bootstrap.path]);
  });

  test('a nested tool batch resumes the cell and preserves output', () async {
    final invoker = _Invoker();
    final future = service.execute(
      owner: 'session-1',
      workingDirectory: '/workspace',
      request: const LuaExecuteRequest(
        source: 'text(tools.echo({value="hi"}))',
        yieldTime: Duration(seconds: 1),
        maxOutputTokens: 1000,
        tools: <LuaNestedToolDefinition>[
          LuaNestedToolDefinition(
            name: 'echo',
            description: 'Echo a value.',
            kind: 'function',
            namespace: 'sample',
            exposure: 'advertised',
            inputSchema: <String, dynamic>{'type': 'object'},
            outputSchema: <String, dynamic>{'type': 'string'},
          ),
        ],
      ),
      context: _context(invoker),
    );
    await pumpEventQueue();
    final process = pipes.process;
    final init = process.writtenFrame(0);
    final cellId = init['cell_id']! as String;
    final initPayload = Map<String, dynamic>.from(init['payload']! as Map);
    expect(initPayload['tools'], <Object?>[
      <String, Object?>{
        'name': 'echo',
        'description': 'Echo a value.',
        'kind': 'function',
        'namespace': 'sample',
        'exposure': 'advertised',
        'input_schema': <String, Object?>{'type': 'object'},
        'output_schema': <String, Object?>{'type': 'string'},
      },
    ]);

    process.emitFrame(cellId, 1, 'tool_batch', <String, dynamic>{
      'calls': <Map<String, dynamic>>[
        <String, dynamic>{
          'request_id': '1:1',
          'name': 'echo',
          'arguments': <String, dynamic>{'value': 'hi'},
        },
      ],
    });
    await pumpEventQueue();

    expect(invoker.calls, <String>['echo:hi']);
    final response = process.writtenFrame(1);
    expect(response['type'], 'tool_results');
    final responsePayload = Map<String, dynamic>.from(
      response['payload']! as Map,
    );
    final results = responsePayload['results']! as List;
    expect((results.single as Map)['value'], 'echoed hi');
    process
      ..emitFrame(cellId, 2, 'output', <String, dynamic>{
        'kind': 'notify',
        'value': <String, dynamic>{'progress': 1},
      })
      ..emitFrame(cellId, 3, 'output', <String, dynamic>{
        'kind': 'text',
        'value': 'echoed hi',
      })
      ..emitFrame(cellId, 4, 'completed', const <String, dynamic>{
        'store': <String, dynamic>{},
      });

    var chunk = await future;
    final output = StringBuffer(chunk.output);
    final notifications = <Object?>[...chunk.notifications];
    while (chunk.running) {
      chunk = await service.wait(
        owner: 'session-1',
        request: LuaWaitRequest(
          cellId: cellId,
          yieldTime: const Duration(seconds: 1),
          maxOutputTokens: 1000,
          terminate: false,
        ),
        context: _context(invoker),
      );
      output.write(chunk.output);
      notifications.addAll(chunk.notifications);
    }
    expect(chunk.running, isFalse);
    expect(output.toString(), 'echoed hi');
    expect(notifications, <Object?>[
      <String, Object?>{'progress': 1},
    ]);
  });

  test('yielded cells resume through wait and can be terminated', () async {
    final execute = service.execute(
      owner: 'session-1',
      workingDirectory: '/workspace',
      request: const LuaExecuteRequest(
        source: 'yield_control(); text("later")',
        yieldTime: Duration(seconds: 1),
        maxOutputTokens: 1000,
        tools: <LuaNestedToolDefinition>[],
      ),
      context: _context(_Invoker()),
    );
    await pumpEventQueue();
    final cellId = pipes.process.writtenFrame(0)['cell_id']! as String;
    pipes.process.emitFrame(cellId, 1, 'yielded', const <String, dynamic>{
      'store': <String, dynamic>{},
    });

    final first = await execute;
    expect(first.running, isTrue);

    final resumed = service.wait(
      owner: 'session-1',
      request: LuaWaitRequest(
        cellId: cellId,
        yieldTime: const Duration(seconds: 1),
        maxOutputTokens: 1000,
        terminate: false,
      ),
      context: _context(_Invoker()),
    );
    await pumpEventQueue();
    expect(pipes.process.writtenFrame(1)['type'], 'continue');
    pipes.process
      ..emitFrame(cellId, 2, 'output', <String, dynamic>{
        'kind': 'text',
        'value': 'later',
      })
      ..emitFrame(cellId, 3, 'completed', const <String, dynamic>{
        'store': <String, dynamic>{},
      });
    final resumedChunk = await resumed;
    expect(resumedChunk.output, 'later');

    final missing = await service.wait(
      owner: 'session-1',
      request: LuaWaitRequest(
        cellId: cellId,
        yieldTime: const Duration(milliseconds: 10),
        maxOutputTokens: 1000,
        terminate: true,
      ),
      context: _context(_Invoker()),
    );
    if (resumedChunk.running) {
      expect(missing.terminated, isTrue);
    } else {
      expect(missing.error, 'Lua cell not found.');
    }
  });

  test('a yielded cell keeps its original nested tool surface', () async {
    final original = _Invoker();
    final replacement = _Invoker();
    final execute = service.execute(
      owner: 'session-1',
      workingDirectory: '/workspace',
      request: const LuaExecuteRequest(
        source: 'yield_control(); text(tools.echo({value="after"}))',
        yieldTime: Duration(seconds: 1),
        maxOutputTokens: 1000,
        tools: <LuaNestedToolDefinition>[],
      ),
      context: _context(original),
    );
    await pumpEventQueue();
    final cellId = pipes.process.writtenFrame(0)['cell_id']! as String;
    pipes.process.emitFrame(cellId, 1, 'yielded', const <String, dynamic>{
      'store': <String, dynamic>{},
    });
    expect((await execute).running, isTrue);

    final resumed = service.wait(
      owner: 'session-1',
      request: LuaWaitRequest(
        cellId: cellId,
        yieldTime: const Duration(seconds: 1),
        maxOutputTokens: 1000,
        terminate: false,
      ),
      context: _context(replacement),
    );
    await pumpEventQueue();
    pipes.process.emitFrame(cellId, 2, 'tool_batch', <String, dynamic>{
      'calls': <Map<String, dynamic>>[
        <String, dynamic>{
          'request_id': '2:1',
          'name': 'echo',
          'arguments': <String, dynamic>{'value': 'after'},
        },
      ],
    });
    await pumpEventQueue();
    expect(original.calls, <String>['echo:after']);
    expect(replacement.calls, isEmpty);
    pipes.process.emitFrame(cellId, 3, 'completed', const <String, dynamic>{
      'store': <String, dynamic>{},
    });
    await resumed;
  });

  test('forwards Tinest cancellation to the shared runtime process', () async {
    final cancellation = CancellationToken();
    final execute = service.execute(
      owner: 'session-1',
      workingDirectory: '/workspace',
      request: const LuaExecuteRequest(
        source: 'yield_control()',
        yieldTime: Duration(seconds: 1),
        maxOutputTokens: 1000,
        tools: <LuaNestedToolDefinition>[],
      ),
      context: LuaCodeModeContext(
        cancellation: cancellation,
        tools: _Invoker(),
      ),
    );
    await pumpEventQueue();
    final cellId = pipes.process.writtenFrame(0)['cell_id']! as String;
    pipes.process.emitFrame(cellId, 1, 'yielded', const <String, dynamic>{
      'store': <String, dynamic>{},
    });
    expect((await execute).running, isTrue);

    cancellation.cancel();
    await pumpEventQueue();

    expect(pipes.process.terminated, isTrue);
  });

  test(
    'maps opaque tool resources into attachments and image context',
    () async {
      const attachment = ConversationAttachment(
        id: 'image-1',
        fileName: 'preview.png',
        mimeType: 'image/png',
        byteSize: 42,
        path: '/attachments/preview.png',
      );
      final execute = service.execute(
        owner: 'session-1',
        workingDirectory: '/workspace',
        request: const LuaExecuteRequest(
          source: 'image(tools.picture({}).attachments[1].handle)',
          yieldTime: Duration(seconds: 1),
          maxOutputTokens: 1000,
          tools: <LuaNestedToolDefinition>[],
        ),
        context: _context(const _AttachmentInvoker(attachment)),
      );
      await pumpEventQueue();
      final cellId = pipes.process.writtenFrame(0)['cell_id']! as String;
      pipes.process.emitFrame(cellId, 1, 'tool_batch', <String, dynamic>{
        'calls': <Map<String, dynamic>>[
          <String, dynamic>{
            'request_id': '1:1',
            'name': 'picture',
            'arguments': <String, dynamic>{},
          },
        ],
      });
      await pumpEventQueue();
      pipes.process
        ..emitFrame(cellId, 2, 'output', <String, dynamic>{
          'kind': 'image',
          'value': 'resource-1',
        })
        ..emitFrame(cellId, 3, 'completed', const <String, dynamic>{
          'store': <String, dynamic>{},
        });

      final chunk = await execute;
      expect(chunk.attachments, <ConversationAttachment>[attachment]);
      expect(chunk.contextImages, <ConversationAttachment>[attachment]);
    },
  );
}

LuaCodeModeContext _context(LuaNestedToolInvoker invoker) =>
    LuaCodeModeContext(cancellation: CancellationToken(), tools: invoker);

final class _Invoker implements LuaNestedToolInvoker {
  final List<String> calls = <String>[];

  @override
  Future<LuaNestedToolResult> invoke(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    calls.add('$name:${arguments['value']}');
    return LuaNestedToolResult(value: 'echoed ${arguments['value']}');
  }
}

final class _AttachmentInvoker implements LuaNestedToolInvoker {
  const new(this.attachment);

  final ConversationAttachment attachment;

  @override
  Future<LuaNestedToolResult> invoke(
    String name,
    Map<String, dynamic> arguments,
  ) async => LuaNestedToolResult(
    value: 'image',
    attachments: <ConversationAttachment>[attachment],
  );
}

final class _LuaHostStager implements LuaHostDistributionStager {
  int calls = 0;
  final List<String> destinations = <String>[];
  final List<String> buildDirectories = <String>[];

  @override
  Future<lua.LuaHostDistribution> stage({
    required String destination,
    required String packageRoot,
    required String buildDirectory,
  }) async {
    calls += 1;
    destinations.add(destination);
    buildDirectories.add(buildDirectory);
    expect(Directory(buildDirectory).existsSync(), isTrue);
    return _writeDistribution(destination);
  }
}

/// Completes the shared cache while this caller is still staging into its own
/// temporary directory, which is what losing the promotion race looks like.
final class _RaceLosingLuaHostStager implements LuaHostDistributionStager {
  int calls = 0;
  String? cacheRoot;

  @override
  Future<lua.LuaHostDistribution> stage({
    required String destination,
    required String packageRoot,
    required String buildDirectory,
  }) async {
    calls += 1;
    // `destination` is `<cache root>.staging-XXXXXX`, so the promotion target
    // comes from it rather than from repeating how the caller builds the path.
    final marker = destination.lastIndexOf('.staging-');
    final root = destination.substring(0, marker);
    cacheRoot = root;
    // The winner promotes first, so by the time this caller renames, the
    // destination already exists and holds a complete host.
    _writeDistribution(root);
    return _writeDistribution(destination);
  }
}

final class _BlockingLuaHostStager implements LuaHostDistributionStager {
  int calls = 0;
  final Completer<void> started = Completer<void>();
  final Completer<void> release = Completer<void>();

  @override
  Future<lua.LuaHostDistribution> stage({
    required String destination,
    required String packageRoot,
    required String buildDirectory,
  }) async {
    calls += 1;
    if (!started.isCompleted) started.complete();
    await release.future;
    return _writeDistribution(destination);
  }
}

final class _FailOnceLuaHostStager implements LuaHostDistributionStager {
  int calls = 0;
  final List<String> destinations = <String>[];

  @override
  Future<lua.LuaHostDistribution> stage({
    required String destination,
    required String packageRoot,
    required String buildDirectory,
  }) async {
    calls += 1;
    destinations.add(destination);
    if (calls == 1) {
      File(p.join(destination, _hostExecutableName))
        ..createSync(recursive: true)
        ..writeAsStringSync('partial');
      throw StateError('staging failed');
    }
    return _writeDistribution(destination);
  }
}

Directory _developmentWorkspace(String prefix) {
  final workspace = Directory.systemTemp.createTempSync(prefix);
  File(p.join(workspace.path, '.dart_tool', 'package_config.json'))
    ..createSync(recursive: true)
    ..writeAsStringSync(
      jsonEncode(<String, Object?>{
        'configVersion': 2,
        'packages': <Map<String, Object?>>[
          <String, Object?>{
            'name': 'lua_tool_runtime',
            'rootUri': '../runtime/',
            'packageUri': 'lib/',
            'languageVersion': '3.12',
          },
        ],
      }),
    );
  File(p.join(workspace.path, 'runtime', 'native', 'bootstrap.lua'))
      .createSync(recursive: true);
  return workspace;
}

lua.LuaHostDistribution _writeDistribution(String destination) {
  final host = File(p.join(destination, _hostExecutableName))
    ..createSync(recursive: true);
  final bootstrap = File(
    p.join(destination, 'lua_tool_runtime', 'bootstrap.lua'),
  )..createSync(recursive: true);
  return lua.LuaHostDistribution(
    hostPath: host.path,
    bootstrapPath: bootstrap.path,
  );
}

String get _hostExecutableName =>
    Platform.isWindows ? 'lua-tool-runtime-host.exe' : 'lua-tool-runtime-host';

final class _Ids implements lua.LuaIdGenerator {
  int value = 0;

  @override
  String generate() => '${++value}';
}

final class _PipeGateway implements lua.LuaHostProcessLauncher {
  final _Process process = _Process();

  @override
  Future<lua.LuaHostProcess> start(
    lua.LuaHostCommand command, {
    required String workingDirectory,
  }) async {
    expect(command.executable, 'lua-tool-runtime-host');
    expect(workingDirectory, '/workspace');
    return process;
  }
}

final class _Process implements lua.LuaHostProcess {
  final StreamController<String> _outputs = StreamController<String>();
  final Completer<int> _exit = Completer<int>();
  final List<String> input = <String>[];
  bool terminated = false;

  Map<String, dynamic> writtenFrame(int index) =>
      Map<String, dynamic>.from(jsonDecode(input[index].trim()) as Map);

  void emit(String value) => _outputs.add(value);

  void emitFrame(
    String cellId,
    int sequence,
    String type,
    Map<String, dynamic> payload,
  ) {
    final frame = <String, dynamic>{
      'version': lua.luaHostProtocolVersion,
      'cell_id': cellId,
      'sequence_id': sequence,
      'type': type,
      'payload': payload,
    };
    emit('${jsonEncode(frame)}\n');
  }

  @override
  Future<int> get exitCode => _exit.future;

  @override
  Stream<String> get outputs => _outputs.stream;

  @override
  String get diagnostics => '';

  @override
  Future<void> terminate() async {
    terminated = true;
    if (!_exit.isCompleted) _exit.complete(0);
  }

  @override
  Future<void> write(String data) async => input.add(data);
}
