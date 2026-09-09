import 'dart:io';

import 'package:cliweave/cliweave.dart';

/// Generates the provider catalog, optionally refreshing upstream metadata.
typedef ProviderCatalogGenerator = Future<void> Function({
  required bool update,
});

final class _ProviderCatalogContext implements CommandContext {
  const new({required this.process, required this.generate});

  @override
  final RunProcess process;
  final ProviderCatalogGenerator generate;
}

final Command<_ProviderCatalogContext> _command = buildCommand(
  docs: const CommandDocs(brief: 'Generate the Tinest provider catalog'),
  parameters: CommandParameters(
    flags: FlagSet.one(
      BooleanFlag.required<_ProviderCatalogContext>(
        name: 'update',
        brief: 'Refresh the pinned upstream provider metadata',
        withNegated: false,
      ),
    ),
    positional: PositionalSet.none(),
  ),
  func: (context, update, _) => context.generate(update: update),
);

int _normalize(int? code) => switch (code) {
  null || ExitCode.success => 0,
  ExitCode.unknownCommand || ExitCode.invalidArgument => 64,
  final int value when value < 0 => 70,
  final int value => value,
};

/// Parses and executes the provider-catalog generator through cliweave.
Future<int> runProviderCatalogCli(
  List<String> arguments, {
  required ProviderCatalogGenerator generate,
  WriteStream? stdoutStream,
  WriteStream? stderrStream,
}) async {
  final process = RunProcess(
    stdout: stdoutStream ?? StdioWriteStream(stdout),
    stderr: stderrStream ?? StdioWriteStream(stderr),
  );
  final context = _ProviderCatalogContext(process: process, generate: generate);
  final application = buildApplication(
    _command,
    const ApplicationConfiguration(name: 'tinest-provider-catalog'),
  );
  await run(application, arguments, RunContext.direct(context));
  return _normalize(process.exitCode);
}
