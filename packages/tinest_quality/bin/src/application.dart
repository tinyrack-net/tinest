import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cliweave/cliweave.dart';
import 'package:tinest_quality/src/architecture_verifier.dart';
import 'package:tinest_quality/src/ci_change_scope.dart';
import 'package:tinest_quality/src/feature_manifest.dart';
import 'package:tinest_quality/src/feature_verifier.dart';
import 'package:tinest_quality/src/generated_sources.dart';
import 'package:tinest_quality/src/resource_budget.dart';
import 'package:tinest_quality/src/verification_runner.dart';
import 'package:tinest_quality/src/workload_planner.dart';
import 'package:yaml/yaml.dart';

/// Receives one human-readable line from a quality command.
typedef QualityOutput = void Function(Object? value);

enum _TinestQualityCommand {
  generate('generate'),
  test('test'),
  verify('verify'),
  e2e('e2e'),
  ciScope('ci-scope'),
  staticChecks('_static-checks'),
  architectureCheck('_architecture-check'),
  featuresCheck('_features-check'),
  testDart('_test-dart'),
  testFlutter('_test-flutter'),
  coverageDart('_coverage-dart'),
  coverageDartPackage('_coverage-dart-package'),
  coverageFlutter('_coverage-flutter');

  new(this.cliName);

  final String cliName;
}

typedef _CommonFlags = ({int? jobs, String? reportPath});

final class _QualityInvocation {
  const new({
    required this.command,
    required this.options,
    this.check = false,
    this.scopes = const <String>{},
  });

  final _TinestQualityCommand command;
  final QualityCommandOptions options;
  final bool check;
  final Set<String> scopes;
}

final class _QualityCliContext implements CommandContext {
  const new({
    required this.process,
    required this.environment,
    required this.detectedJobs,
    required this.out,
    required this.error,
  });

  @override
  final RunProcess process;
  final Map<String, String> environment;
  final int detectedJobs;
  final QualityOutput out;
  final QualityOutput error;

  Future<void> execute(
    _TinestQualityCommand command,
    _CommonFlags common, {
    bool check = false,
    List<String> scopes = const <String>[],
  }) async {
    final options = QualityCommandOptions(
      jobs: resolveQualityJobs(
        cliJobs: common.jobs,
        environment: environment,
        detectedJobs: detectedJobs,
      ),
      reportPath: common.reportPath,
    );
    process.exitCode = await _executeTinestQuality(
      _QualityInvocation(
        command: command,
        options: options,
        check: check,
        scopes: Set<String>.unmodifiable(scopes),
      ),
      out: out,
      error: error,
    );
  }
}

final class _CallbackWriteStream implements WriteStream {
  const new(this.output);

  final QualityOutput output;

  @override
  bool get isTTY => false;

  @override
  void clearLine(int dir) {}

  @override
  void cursorTo(int column) {}

  @override
  void write(String chunk) => output(chunk);
}

int _positiveInt(_QualityCliContext _, String value) {
  final parsed = int.tryParse(value);
  if (parsed == null || parsed < 1) {
    throw const FormatException('Value must be a positive integer.');
  }
  return parsed;
}

String _nonEmptyString(_QualityCliContext _, String value) {
  if (value.isEmpty) throw const FormatException('Value must not be empty.');
  return value;
}

FlagSet<_CommonFlags, _QualityCliContext> _commonFlags() =>
    FlagSet.one(
          ParsedFlag.optional<int, _QualityCliContext>(
            name: 'jobs',
            brief: 'Maximum concurrent job count',
            parse: _positiveInt,
            placeholder: 'count',
          ),
        )
        .and(
          ParsedFlag.optional<String, _QualityCliContext>(
            name: 'report',
            brief: 'Write a machine-readable timing report',
            parse: _nonEmptyString,
            placeholder: 'path',
          ),
        )
        .map((values) => (jobs: values.$1, reportPath: values.$2));

Command<_QualityCliContext> _plainCommand(
  _TinestQualityCommand command,
  String brief,
) => buildCommand(
  docs: CommandDocs(brief: brief),
  parameters: CommandParameters(
    flags: _commonFlags(),
    positional: PositionalSet.none(),
  ),
  func: (context, flags, _) => context.execute(command, flags),
);

final Command<_QualityCliContext> _generateCommand = buildCommand(
  docs: const CommandDocs(brief: 'Regenerate checked-in sources'),
  parameters: CommandParameters(
    flags: _commonFlags()
        .and(
          BooleanFlag.required<_QualityCliContext>(
            name: 'check',
            brief: 'Fail when generated sources are stale',
            withNegated: false,
          ),
        )
        .map((values) => (common: values.$1, check: values.$2)),
    positional: PositionalSet.none(),
  ),
  func: (context, flags, _) => context.execute(
    _TinestQualityCommand.generate,
    flags.common,
    check: flags.check,
  ),
);

Command<_QualityCliContext> _scopedCommand(
  _TinestQualityCommand command,
  String brief,
) => buildCommand(
  docs: CommandDocs(brief: brief),
  parameters: CommandParameters(
    flags: _commonFlags()
        .and(
          ParsedFlag.variadic<String, _QualityCliContext>(
            name: 'scope',
            brief: 'Limit execution to a workspace package',
            parse: _nonEmptyString,
            placeholder: 'package',
          ),
        )
        .map((values) => (common: values.$1, scopes: values.$2)),
    positional: PositionalSet.none(),
  ),
  func: (context, flags, _) =>
      context.execute(command, flags.common, scopes: flags.scopes),
);

RouteMap<_QualityCliContext> _qualityRoutes() => buildRouteMap(
  docs: RouteMapDocs(
    brief: 'Tinest workspace quality commands',
    hideRoute: <String, bool>{
      for (final command in _TinestQualityCommand.values)
        if (command.cliName.startsWith('_')) command.cliName: true,
    },
  ),
  routes: <String, RoutingTarget<_QualityCliContext>>{
    'generate': _generateCommand,
    'test': _plainCommand(_TinestQualityCommand.test, 'Run workspace tests'),
    'verify': _plainCommand(
      _TinestQualityCommand.verify,
      'Run the complete workspace verification suite',
    ),
    'e2e': _plainCommand(
      _TinestQualityCommand.e2e,
      'Run the desktop Debug E2E suite',
    ),
    'ci-scope': _plainCommand(
      _TinestQualityCommand.ciScope,
      'Resolve the conservative pull-request scope',
    ),
    '_static-checks': _plainCommand(
      _TinestQualityCommand.staticChecks,
      'Run static workspace checks',
    ),
    '_architecture-check': _plainCommand(
      _TinestQualityCommand.architectureCheck,
      'Verify package architecture',
    ),
    '_features-check': _plainCommand(
      _TinestQualityCommand.featuresCheck,
      'Verify feature evidence',
    ),
    '_test-dart': _scopedCommand(
      _TinestQualityCommand.testDart,
      'Run Dart package tests',
    ),
    '_test-flutter': _scopedCommand(
      _TinestQualityCommand.testFlutter,
      'Run Flutter package tests',
    ),
    '_coverage-dart': _scopedCommand(
      _TinestQualityCommand.coverageDart,
      'Run Dart package coverage',
    ),
    '_coverage-dart-package': _plainCommand(
      _TinestQualityCommand.coverageDartPackage,
      'Run coverage for the current Dart package',
    ),
    '_coverage-flutter': _plainCommand(
      _TinestQualityCommand.coverageFlutter,
      'Run Flutter package coverage',
    ),
  },
);

int _normalizeCliExitCode(int? code) => switch (code) {
  null || ExitCode.success => 0,
  ExitCode.unknownCommand || ExitCode.invalidArgument => 64,
  final int value when value < 0 => 70,
  final int value => value,
};

/// Runs the Tinest repository-quality command and returns a process exit code.
Future<int> runTinestQuality(
  List<String> arguments, {
  QualityOutput out = _writeOutput,
  QualityOutput? error,
}) async {
  final writeError = error ?? _writeError;
  final process = RunProcess(
    stdout: _CallbackWriteStream(out),
    stderr: _CallbackWriteStream(writeError),
  );
  final context = _QualityCliContext(
    process: process,
    environment: Platform.environment,
    detectedJobs: Platform.numberOfProcessors,
    out: out,
    error: writeError,
  );
  final application = buildApplication(
    _qualityRoutes(),
    ApplicationConfiguration(
      name: 'tinest-quality',
      determineExitCode: (failure) => failure is FormatException ? 64 : 70,
    ),
  );
  await run(application, arguments, RunContext.direct(context));
  return _normalizeCliExitCode(process.exitCode);
}

Future<int> _executeTinestQuality(
  _QualityInvocation invocation, {
  required QualityOutput out,
  required QualityOutput error,
}) async {
  final writeError = error;
  final command = invocation.command;
  final options = invocation.options;
  switch (command) {
    case _TinestQualityCommand.generate:
      return await _runMeasured(
        name: 'generate',
        jobs: options.jobs,
        reportPath: options.reportPath,
        body: () => _generate(
          check: invocation.check,
          jobs: options.jobs,
          out: out,
          error: writeError,
        ),
      );
    case _TinestQualityCommand.test:
      return await _runPlan(
        WorkspaceVerificationPlans.tests(jobs: options.jobs),
        jobs: options.jobs,
        reportPath: options.reportPath,
        out: out,
        error: writeError,
      );
    case _TinestQualityCommand.verify:
      return await _runPlan(
        WorkspaceVerificationPlans.full(
          jobs: options.jobs,
          serializeCoverage: Platform.isWindows,
        ),
        jobs: options.jobs,
        reportPath: options.reportPath,
        out: out,
        error: writeError,
      );
    case _TinestQualityCommand.e2e:
      return await _runMeasured(
        name: 'e2e',
        jobs: options.jobs,
        reportPath: options.reportPath,
        body: () => _runProcess(
          'dart',
          <String>[
            'run',
            'packages/desktop_app/tool/run_desktop_e2e.dart',
            '--jobs=${options.jobs}',
            if (options.reportPath case final reportPath?)
              '--report=$reportPath.desktop.json',
          ],
          out: out,
          error: writeError,
        ),
      );
    case _TinestQualityCommand.ciScope:
      final files = await stdin
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .toList();
      out(CiChangeScope.forPullRequest(files).outputValue);
      return 0;
    case _TinestQualityCommand.staticChecks:
      return await _runPlan(
        WorkspaceVerificationPlans.staticChecks(jobs: options.jobs),
        jobs: options.jobs,
        reportPath: options.reportPath,
        out: out,
        error: writeError,
      );
    case _TinestQualityCommand.architectureCheck:
      return _architectureCheck(out, writeError);
    case _TinestQualityCommand.featuresCheck:
      return _featuresCheck(out, writeError);
    case _TinestQualityCommand.testDart:
      return await _runDartPackages(
        jobs: options.jobs,
        scopes: invocation.scopes,
        coverage: false,
        reportPath: options.reportPath,
        out: out,
        error: writeError,
      );
    case _TinestQualityCommand.testFlutter:
      final seed = _newTestSeed();
      return await _runMeasured(
        name: 'Flutter tests',
        jobs: options.jobs,
        reportPath: options.reportPath,
        testRandomizationSeed: seed,
        body: () => _runFlutterPackageTests(
          jobs: options.jobs,
          seed: seed,
          coverage: false,
          scopes: invocation.scopes,
          out: out,
          error: writeError,
        ),
      );
    case _TinestQualityCommand.coverageDart:
      return await _runDartPackages(
        jobs: options.jobs,
        scopes: invocation.scopes,
        coverage: true,
        reportPath: options.reportPath,
        out: out,
        error: writeError,
      );
    case _TinestQualityCommand.coverageDartPackage:
      final seed = _newTestSeed();
      Directory('coverage').createSync(recursive: true);
      final packageName =
          Platform.environment['MELOS_PACKAGE_NAME'] ?? _currentPackageName();
      final coveragePath = File('coverage/lcov.info').absolute.path;
      final exitCode = await _runProcess(
        'dart',
        <String>[
          'test',
          '--concurrency=${options.jobs}',
          '--coverage-path=$coveragePath',
          '--coverage-package=$packageName',
          '--branch-coverage',
          '--test-randomize-ordering-seed=$seed',
        ],
        out: out,
        error: writeError,
      );
      if (exitCode == 0) _excludeGeneratedCoverage(File(coveragePath));
      return exitCode;
    case _TinestQualityCommand.coverageFlutter:
      final seed = _newTestSeed();
      return await _runMeasured(
        name: 'Flutter coverage',
        jobs: options.jobs,
        reportPath: options.reportPath,
        testRandomizationSeed: seed,
        body: () => _runFlutterPackageTests(
          jobs: options.jobs,
          seed: seed,
          coverage: true,
          scopes: const <String>{},
          out: out,
          error: writeError,
        ),
      );
  }
}

Future<int> _runFlutterPackageTests({
  required int jobs,
  required int seed,
  required bool coverage,
  required Set<String> scopes,
  required QualityOutput out,
  required QualityOutput error,
}) async {
  const packages = <String>['app', 'desktop_app'];
  final selected = scopes.isEmpty
      ? packages
      : packages.where(scopes.contains).toList(growable: false);
  if (selected.isEmpty) {
    error('No Flutter packages with tests matched the requested scope.');
    return 64;
  }
  for (final package in selected) {
    final result = await _runProcess(
      'flutter',
      <String>[
        'test',
        if (!coverage) 'test',
        if (coverage) ...<String>['--coverage', '--branch-coverage'],
        '--concurrency=$jobs',
        '--test-randomize-ordering-seed=$seed',
      ],
      workingDirectory: 'packages/$package',
      out: out,
      error: error,
    );
    if (result != 0) return result;
    if (coverage) {
      _excludeGeneratedCoverage(File('packages/$package/coverage/lcov.info'));
    }
  }
  return 0;
}

Future<int> _generate({
  required bool check,
  required int jobs,
  required QualityOutput out,
  required QualityOutput error,
}) async {
  final before = check ? await _generatedSources() : const <String, String>{};
  final generatorReport = await VerificationRunner(
    executor: _ProcessTaskExecutor(out, error),
    maxJobs: jobs,
  ).run(WorkspaceGenerationPlans.generate(jobs: jobs));
  if (!generatorReport.succeeded) {
    return generatorReport.failures.first.exitCode;
  }
  if (!check) return 0;
  final after = await _generatedSources();
  final sourceCheck = GeneratedSources.compare(before: before, after: after);
  if (sourceCheck.succeeded) {
    out('Generated sources are current.');
    return 0;
  }
  error('Generated sources were stale:');
  sourceCheck.changedPaths.forEach(error);
  return 1;
}

Future<Map<String, String>> _generatedSources() async {
  final sources = <String, String>{};
  final packagesDirectory = Directory('packages');
  await for (final package in packagesDirectory.list(followLinks: false)) {
    if (package is! Directory) continue;
    final sourceDirectory = Directory(
      '${package.path}${Platform.pathSeparator}lib',
    );
    if (!sourceDirectory.existsSync()) continue;
    await for (final entity in sourceDirectory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File && GeneratedSources.includesPath(entity.path)) {
        sources[entity.path] = entity.readAsStringSync();
      }
    }
  }
  final desktopPubspec = File('packages/desktop_app/pubspec.yaml');
  if (desktopPubspec.existsSync()) {
    sources[desktopPubspec.path] = desktopPubspec.readAsStringSync();
  }
  return sources;
}

int _architectureCheck(QualityOutput out, QualityOutput error) {
  final violations = ArchitectureVerifier(Directory.current.path).verify();
  if (violations.isEmpty) {
    out('Architecture verification passed.');
    return 0;
  }
  violations.forEach(error);
  return 1;
}

int _featuresCheck(QualityOutput out, QualityOutput error) {
  final violations = FeatureVerifier(
    Directory.current.path,
    contracts: tinestFeatureManifest,
    uiContracts: tinestUiReachabilityManifest,
    uiJourneys: tinestUiJourneyManifest,
  ).verify();
  if (violations.isEmpty) {
    out(
      'Feature verification passed (${tinestFeatureManifest.length} features).',
    );
    return 0;
  }
  error('Feature verification failed:');
  for (final violation in violations) {
    error('  - $violation');
  }
  return 1;
}

Future<int> _runDartPackages({
  required int jobs,
  required Set<String> scopes,
  required bool coverage,
  required String? reportPath,
  required QualityOutput out,
  required QualityOutput error,
}) async {
  final stopwatch = Stopwatch()..start();
  final targets = _dartPackageTargets(scopes);
  if (targets.isEmpty) {
    error('No Dart packages with tests matched the requested scope.');
    return 64;
  }
  final allocations = allocatePackageJobs(<PackageWorkload>[
    for (final target in targets)
      PackageWorkload(name: target.name, suites: target.suites),
  ], jobs);
  final tasks = <VerificationTask>[];
  if (coverage) {
    for (final target in targets) {
      final concurrency = allocations[target.name]!;
      final shardDirectory = Directory('${target.path}/coverage/shards');
      if (shardDirectory.existsSync()) {
        shardDirectory.deleteSync(recursive: true);
      }
      shardDirectory.createSync(recursive: true);
      final seed = _newTestSeed();
      tasks.add(
        VerificationTask(
          name: '${target.name} coverage',
          executable: 'dart',
          arguments: <String>[
            'test',
            // Kernel compiler processes share a package-global
            // `.dart_tool/test/incremental_kernel` cache. Keep one runner per
            // package and parallelize its suites internally; packages still
            // fan out concurrently under the global resource budget.
            '--concurrency=$concurrency',
            '--coverage-path=${_coverageShardPath(target, 0)}',
            '--coverage-package=${target.name}',
            '--branch-coverage',
            '--test-randomize-ordering-seed=$seed',
          ],
          workingDirectory: target.path,
          cpuSlots: concurrency,
          // Dart 3.13 places native assets in the workspace-wide `.dart_tool`
          // bundle. Windows cannot replace an in-use sqlite3.dll, so coverage
          // package runners must not overlap while that bundle is in use.
          exclusiveResources: Platform.isWindows
              ? const <String>{'native-assets'}
              : const <String>{},
          testRandomizationSeed: seed,
        ),
      );
    }
  } else {
    for (final target in targets) {
      final seed = _newTestSeed();
      tasks.add(
        VerificationTask(
          name: '${target.name} tests',
          executable: 'dart',
          arguments: <String>[
            'test',
            '--concurrency=${allocations[target.name]}',
            '--test-randomize-ordering-seed=$seed',
          ],
          workingDirectory: target.path,
          cpuSlots: allocations[target.name]!,
          testRandomizationSeed: seed,
        ),
      );
    }
  }
  final report =
      await VerificationRunner(
        executor: _ProcessTaskExecutor(out, error),
        maxJobs: jobs,
      ).run(
        VerificationPlan(
          phases: <VerificationPhase>[VerificationPhase(tasks: tasks)],
        ),
      );
  if (!report.succeeded) {
    stopwatch.stop();
    _writeReport(
      reportPath,
      jobs: jobs,
      duration: stopwatch.elapsed,
      results: report.results,
    );
    return 1;
  }
  if (!coverage) {
    stopwatch.stop();
    _writeReport(
      reportPath,
      jobs: jobs,
      duration: stopwatch.elapsed,
      results: report.results,
    );
    return 0;
  }
  final mergeReport =
      await VerificationRunner(
        executor: _ProcessTaskExecutor(out, error),
        maxJobs: jobs,
      ).run(
        VerificationPlan(
          phases: <VerificationPhase>[
            VerificationPhase(
              tasks: <VerificationTask>[
                for (final target in targets)
                  VerificationTask(
                    name: '${target.name} coverage merge',
                    executable: 'dart',
                    arguments: <String>[
                      'run',
                      'tinyrack_workspace',
                      'coverage-merge',
                      '--input=${_coverageShardPath(target, 0)}',
                      '--output=${_coveragePath(target)}',
                    ],
                    exclusiveResources: const <String>{'coverage-merge'},
                  ),
              ],
            ),
          ],
        ),
      );
  if (mergeReport.succeeded) {
    for (final target in targets) {
      _excludeGeneratedCoverage(File(_coveragePath(target)));
    }
  }
  stopwatch.stop();
  _writeReport(
    reportPath,
    jobs: jobs,
    duration: stopwatch.elapsed,
    results: <VerificationTaskResult>[
      ...report.results,
      ...mergeReport.results,
    ],
  );
  return mergeReport.succeeded ? 0 : 1;
}

List<_PackageTestTarget> _dartPackageTargets(Set<String> scopes) {
  final targets = <_PackageTestTarget>[];
  for (final entity in Directory('packages').listSync()) {
    if (entity is! Directory) continue;
    final pubspecFile = File('${entity.path}/pubspec.yaml');
    final testDirectory = Directory('${entity.path}/test');
    if (!pubspecFile.existsSync() || !testDirectory.existsSync()) continue;
    final pubspec = loadYaml(pubspecFile.readAsStringSync()) as YamlMap;
    final name = pubspec['name'] as String;
    final dependencies = pubspec['dependencies'];
    final isFlutter =
        dependencies is YamlMap && dependencies.containsKey('flutter');
    if (isFlutter || (scopes.isNotEmpty && !scopes.contains(name))) continue;
    final suiteCount = testDirectory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('_test.dart'))
        .length;
    if (suiteCount == 0) continue;
    targets.add(
      _PackageTestTarget(name: name, path: entity.path, suites: suiteCount),
    );
  }
  targets.sort((left, right) {
    final suites = right.suites.compareTo(left.suites);
    return suites == 0 ? left.name.compareTo(right.name) : suites;
  });
  return targets;
}

final class _PackageTestTarget {
  const new({required this.name, required this.path, required this.suites});

  final String name;
  final String path;
  final int suites;
}

String _coveragePath(_PackageTestTarget target) =>
    File('${target.path}/coverage/lcov.info').absolute.path;

String _coverageShardPath(_PackageTestTarget target, int shard) =>
    File('${target.path}/coverage/shards/$shard.info').absolute.path;

void _excludeGeneratedCoverage(File coverageFile) {
  if (!coverageFile.existsSync()) return;
  coverageFile.writeAsStringSync(
    GeneratedSources.excludeFromLcov(coverageFile.readAsStringSync()),
  );
}

Future<int> _runPlan(
  VerificationPlan plan, {
  required int jobs,
  required String? reportPath,
  required QualityOutput out,
  required QualityOutput error,
}) async {
  final stopwatch = Stopwatch()..start();
  final report = await VerificationRunner(
    executor: _ProcessTaskExecutor(out, error),
    maxJobs: jobs,
  ).run(plan);
  stopwatch.stop();
  out('\nVerification summary:');
  for (final result in report.results) {
    out(
      '  ${result.succeeded ? 'PASS' : 'FAIL'} ${result.task.name} '
      '(${result.duration.inMilliseconds / 1000}s, exit ${result.exitCode})',
    );
  }
  _writeReport(
    reportPath,
    jobs: jobs,
    duration: stopwatch.elapsed,
    results: report.results,
  );
  return report.succeeded ? 0 : 1;
}

Future<int> _runMeasured({
  required String name,
  required int jobs,
  required String? reportPath,
  required Future<int> Function() body,
  int? testRandomizationSeed,
}) async {
  final stopwatch = Stopwatch()..start();
  final result = await body();
  stopwatch.stop();
  _writeReport(
    reportPath,
    jobs: jobs,
    duration: stopwatch.elapsed,
    results: <VerificationTaskResult>[
      VerificationTaskResult(
        task: VerificationTask(
          name: name,
          executable: 'dart',
          arguments: const <String>[],
          cpuSlots: jobs,
          testRandomizationSeed: testRandomizationSeed,
        ),
        exitCode: result,
        duration: stopwatch.elapsed,
      ),
    ],
  );
  return result;
}

void _writeReport(
  String? path, {
  required int jobs,
  required Duration duration,
  required List<VerificationTaskResult> results,
}) {
  if (path == null) return;
  final weightedMilliseconds = results.fold<int>(
    0,
    (sum, result) =>
        sum + result.duration.inMilliseconds * result.task.cpuSlots,
  );
  final capacityMilliseconds = duration.inMilliseconds * jobs;
  final nestedSeeds = <VerificationTaskResult, List<int>>{
    for (final result in results) result: _nestedTestSeeds(result.task),
  };
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'schemaVersion': 1,
        'host': Platform.operatingSystem,
        'detectedJobs': Platform.numberOfProcessors,
        'effectiveJobs': jobs,
        'durationMilliseconds': duration.inMilliseconds,
        'slotUtilization': capacityMilliseconds == 0
            ? 0
            : weightedMilliseconds / capacityMilliseconds,
        'testRandomizationSeeds': <int>[
          for (final result in results) ?result.task.testRandomizationSeed,
          for (final result in results) ...nestedSeeds[result]!,
        ],
        'tasks': <Map<String, Object?>>[
          for (final result in results)
            <String, Object?>{
              'name': result.task.name,
              'cpuSlots': result.task.cpuSlots,
              'exclusiveResources': result.task.exclusiveResources.toList()
                ..sort(),
              'durationMilliseconds': result.duration.inMilliseconds,
              'exitCode': result.exitCode,
              'testRandomizationSeed': ?result.task.testRandomizationSeed,
              if (nestedSeeds[result]!.isNotEmpty)
                'nestedTestRandomizationSeeds': nestedSeeds[result],
            },
        ],
      }),
    );
}

List<int> _nestedTestSeeds(VerificationTask task) {
  final reportArgument = task.arguments
      .where((argument) => argument.startsWith('--report='))
      .firstOrNull;
  if (reportArgument == null) return const <int>[];
  final report = File(reportArgument.substring('--report='.length));
  if (!report.existsSync()) return const <int>[];
  final decoded = jsonDecode(report.readAsStringSync());
  if (decoded is! Map<String, Object?>) return const <int>[];
  final seeds = decoded['testRandomizationSeeds'];
  if (seeds is! List<Object?>) return const <int>[];
  return seeds.whereType<int>().toList(growable: false);
}

final Random _testSeedRandom = Random.secure();

int _newTestSeed() => _testSeedRandom.nextInt(0x7fffffff);

final class _ProcessTaskExecutor implements VerificationTaskExecutor {
  const new(this.out, this.error);

  final QualityOutput out;
  final QualityOutput error;

  @override
  Future<VerificationTaskResult> run(VerificationTask task) async {
    out('\n[${task.name}] ${task.executable} ${task.arguments.join(' ')}');
    final stopwatch = Stopwatch()..start();
    final result = await _runProcess(
      task.executable,
      task.arguments,
      workingDirectory: task.workingDirectory,
      out: out,
      error: error,
    );
    stopwatch.stop();
    return VerificationTaskResult(
      task: task,
      exitCode: result,
      duration: stopwatch.elapsed,
    );
  }
}

Future<int> _runProcess(
  String executable,
  List<String> arguments, {
  required QualityOutput out,
  required QualityOutput error,
  String? workingDirectory,
  Map<String, String> environment = const <String, String>{},
}) async {
  try {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      mode: ProcessStartMode.inheritStdio,
      runInShell: Platform.isWindows && executable == 'flutter',
    );
    return await process.exitCode;
  } on ProcessException catch (failure) {
    error(failure);
    return 127;
  }
}

void _writeOutput(Object? value) => stdout.writeln(value);

void _writeError(Object? value) => stderr.writeln(value);

String _currentPackageName() {
  final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
  return pubspec['name'] as String;
}
