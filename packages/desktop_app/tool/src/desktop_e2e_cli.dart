import 'dart:io';

import 'package:app/testing/devtools/desktop_e2e_runner.dart';
import 'package:cliweave/cliweave.dart';

/// Fully resolved options passed to the desktop E2E runner.
typedef DesktopE2eCliOptions = DesktopE2eOptions;

/// Executes one parsed desktop E2E invocation.
typedef DesktopE2eExecutor = Future<int> Function(DesktopE2eCliOptions options);

final class _DesktopE2eContext implements CommandContext {
  const new({
    required this.process,
    required this.execute,
    required this.detectedJobs,
    required this.defaultSeed,
  });

  @override
  final RunProcess process;
  final DesktopE2eExecutor execute;
  final int detectedJobs;
  final int defaultSeed;
}

typedef _DesktopE2eFlags = ({
  int? jobs,
  int? seed,
  String? scenario,
  String? reportPath,
});

int _positiveInt(_DesktopE2eContext _, String value) {
  final parsed = int.tryParse(value);
  if (parsed == null || parsed < 1) {
    throw const FormatException('Value must be a positive integer.');
  }
  return parsed;
}

int _integer(_DesktopE2eContext _, String value) {
  final parsed = int.tryParse(value);
  if (parsed == null) throw const FormatException('Value must be an integer.');
  return parsed;
}

String _nonEmptyString(_DesktopE2eContext _, String value) {
  if (value.isEmpty) throw const FormatException('Value must not be empty.');
  return value;
}

final Command<_DesktopE2eContext> _command = buildCommand(
  docs: const CommandDocs(brief: 'Run the Tinest desktop E2E suite'),
  parameters: CommandParameters(
    flags:
        FlagSet.one(
              ParsedFlag.optional<int, _DesktopE2eContext>(
                name: 'jobs',
                brief: 'Maximum concurrent job count',
                parse: _positiveInt,
                placeholder: 'count',
              ),
            )
            .and(
              ParsedFlag.optional<int, _DesktopE2eContext>(
                name: 'seed',
                brief: 'Randomized test-order seed',
                parse: _integer,
                placeholder: 'integer',
              ),
            )
            .and(
              EnumFlag.optional<String, _DesktopE2eContext>(
                name: 'scenario',
                brief: 'Run one desktop E2E scenario',
                values: <String, String>{
                  for (final scenario in desktopE2eScenarios)
                    scenario.id: scenario.id,
                },
                placeholder: 'id',
              ),
            )
            .and(
              ParsedFlag.optional<String, _DesktopE2eContext>(
                name: 'report',
                brief: 'Write a machine-readable timing report',
                parse: _nonEmptyString,
                placeholder: 'path',
              ),
            )
            .map<_DesktopE2eFlags>(
              (values) => (
                jobs: values.$1.$1.$1,
                seed: values.$1.$1.$2,
                scenario: values.$1.$2,
                reportPath: values.$2,
              ),
            ),
    positional: PositionalSet.none(),
  ),
  func: (context, flags, _) async {
    final result = await context.execute(
      DesktopE2eOptions(
        jobs: flags.jobs ?? context.detectedJobs,
        seed: flags.seed ?? context.defaultSeed,
        scenario: flags.scenario,
        reportPath: flags.reportPath,
      ),
    );
    context.process.exitCode = result;
  },
);

int _normalize(int? code) => switch (code) {
  null || ExitCode.success => 0,
  ExitCode.unknownCommand || ExitCode.invalidArgument => 64,
  final int value when value < 0 => 70,
  final int value => value,
};

/// Parses and executes the desktop E2E command through cliweave.
Future<int> runDesktopE2eCli(
  List<String> arguments, {
  required int detectedJobs,
  required int defaultSeed,
  required DesktopE2eExecutor execute,
  WriteStream? stdoutStream,
  WriteStream? stderrStream,
}) async {
  final process = RunProcess(
    stdout: stdoutStream ?? StdioWriteStream(stdout),
    stderr: stderrStream ?? StdioWriteStream(stderr),
  );
  final context = _DesktopE2eContext(
    process: process,
    execute: execute,
    detectedJobs: detectedJobs,
    defaultSeed: defaultSeed,
  );
  final application = buildApplication(
    _command,
    const ApplicationConfiguration(name: 'tinest-desktop-e2e'),
  );
  await run(application, arguments, RunContext.direct(context));
  return _normalize(process.exitCode);
}
