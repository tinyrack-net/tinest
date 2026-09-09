import 'dart:io';

import 'package:cliweave/cliweave.dart';

/// Executes the relay smoke protocol after parsing command inputs.
typedef RelaySmokeExecutor = Future<void> Function(Uri base, String? readyFile);

final class _RelaySmokeContext implements CommandContext {
  const new({required this.process, required this.execute});

  @override
  final RunProcess process;
  final RelaySmokeExecutor execute;
}

Uri _uriParser(_RelaySmokeContext _, String value) => Uri.parse(value);

final Command<_RelaySmokeContext> _command = buildCommand(
  docs: const CommandDocs(brief: 'Smoke-test a running Tinest relay'),
  parameters: CommandParameters(
    flags: FlagSet<NoFlags, _RelaySmokeContext>.none(),
    positional:
        PositionalSet.one(
          Positional.required<Uri, _RelaySmokeContext>(
            brief: 'Relay base URL',
            parse: _uriParser,
            placeholder: 'base-url',
          ),
        ).and(
          Positional.optional<String, _RelaySmokeContext>(
            brief: 'File written after the smoke test reaches readiness',
            parse: stringParser,
            placeholder: 'ready-file',
          ),
        ),
  ),
  func: (context, _, arguments) => context.execute(arguments.$1, arguments.$2),
);

int _normalize(int? code) => switch (code) {
  null || ExitCode.success => 0,
  ExitCode.unknownCommand || ExitCode.invalidArgument => 64,
  final int value when value < 0 => 70,
  final int value => value,
};

/// Parses and executes the relay smoke command through cliweave.
Future<int> runRelaySmokeCli(
  List<String> arguments, {
  required RelaySmokeExecutor execute,
  WriteStream? stdoutStream,
  WriteStream? stderrStream,
}) async {
  final process = RunProcess(
    stdout: stdoutStream ?? StdioWriteStream(stdout),
    stderr: stderrStream ?? StdioWriteStream(stderr),
  );
  final context = _RelaySmokeContext(process: process, execute: execute);
  final application = buildApplication(
    _command,
    const ApplicationConfiguration(name: 'tinest-relay-smoke'),
  );
  await run(application, arguments, RunContext.direct(context));
  return _normalize(process.exitCode);
}
