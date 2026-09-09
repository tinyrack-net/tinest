import 'dart:async';

/// One process executed as part of workspace verification.
final class VerificationTask {
  /// Creates a process-backed verification task.
  const new({
    required this.name,
    required this.executable,
    required this.arguments,
    this.workingDirectory,
    this.cpuSlots = 1,
    this.exclusiveResources = const <String>{},
    this.testRandomizationSeed,
  });

  /// Human-readable task name.
  final String name;

  /// Executable launched for the task.
  final String executable;

  /// Arguments passed to [executable].
  final List<String> arguments;

  /// Optional working directory relative to the workspace root.
  final String? workingDirectory;

  /// Number of jobs reserved while this task is running.
  final int cpuSlots;

  /// Workspace resources that no other running task may use concurrently.
  final Set<String> exclusiveResources;

  /// Concrete randomized-order seed passed to a test process, when applicable.
  final int? testRandomizationSeed;
}

/// Tasks that may execute concurrently.
final class VerificationPhase {
  /// Creates a phase whose [tasks] may run concurrently.
  const new({required this.tasks});

  /// Tasks in this phase.
  final List<VerificationTask> tasks;
}

/// Ordered phases in a verification run.
final class VerificationPlan {
  /// Creates an ordered verification plan.
  const new({required this.phases});

  /// Ordered phases; a failed phase prevents later phases from running.
  final List<VerificationPhase> phases;
}

/// Result of running one [VerificationTask].
final class VerificationTaskResult {
  /// Creates a completed task result.
  const new({
    required this.task,
    required this.exitCode,
    required this.duration,
  });

  /// Task that ran.
  final VerificationTask task;

  /// Process exit code.
  final int exitCode;

  /// Elapsed execution time.
  final Duration duration;

  /// Whether the process exited successfully.
  bool get succeeded => exitCode == 0;
}

/// Executes one verification task.
abstract interface class VerificationTaskExecutor {
  /// Runs [task] and returns its result.
  Future<VerificationTaskResult> run(VerificationTask task);
}

/// Results collected from the phases that ran.
final class VerificationReport {
  /// Creates an immutable verification report.
  const new(this.results);

  /// Task results in deterministic plan order.
  final List<VerificationTaskResult> results;

  /// Failed task results.
  List<VerificationTaskResult> get failures =>
      results.where((result) => !result.succeeded).toList(growable: false);

  /// Whether every executed task succeeded.
  bool get succeeded => failures.isEmpty;
}

/// Executes ordered phases with bounded concurrency inside each phase.
final class VerificationRunner {
  /// Creates a runner with bounded phase concurrency.
  new({required this.executor, required this.maxJobs})
    : assert(maxJobs > 0, 'maxJobs must be positive');

  /// Task execution boundary.
  final VerificationTaskExecutor executor;

  /// Maximum tasks running at once in a phase.
  final int maxJobs;

  /// Runs phases in order and stops after the first failed phase.
  Future<VerificationReport> run(VerificationPlan plan) async {
    final allResults = <VerificationTaskResult>[];
    for (final phase in plan.phases) {
      final results = await _runPhase(phase);
      allResults.addAll(results);
      if (results.any((result) => !result.succeeded)) break;
    }
    return VerificationReport(List.unmodifiable(allResults));
  }

  Future<List<VerificationTaskResult>> _runPhase(
    VerificationPhase phase,
  ) async {
    if (phase.tasks.isEmpty) return const <VerificationTaskResult>[];
    final results = List<VerificationTaskResult?>.filled(
      phase.tasks.length,
      null,
    );
    final pending = <int>[
      for (var index = 0; index < phase.tasks.length; index += 1) index,
    ];
    final running = <int, Future<void>>{};
    final heldResources = <String>{};
    var usedJobs = 0;

    while (pending.isNotEmpty || running.isNotEmpty) {
      var launched = false;
      for (var pendingIndex = 0; pendingIndex < pending.length;) {
        final index = pending[pendingIndex];
        final task = phase.tasks[index];
        if (task.cpuSlots <= 0 || task.cpuSlots > maxJobs) {
          throw ArgumentError.value(
            task.cpuSlots,
            'task.cpuSlots',
            'must be between 1 and maxJobs ($maxJobs)',
          );
        }
        final hasResourceConflict = task.exclusiveResources.any(
          heldResources.contains,
        );
        if (usedJobs + task.cpuSlots > maxJobs || hasResourceConflict) {
          pendingIndex += 1;
          continue;
        }

        pending.removeAt(pendingIndex);
        usedJobs += task.cpuSlots;
        heldResources.addAll(task.exclusiveResources);
        launched = true;
        running[index] = executor
            .run(task)
            .then((result) {
              results[index] = result;
            })
            .whenComplete(() {
              usedJobs -= task.cpuSlots;
              heldResources.removeAll(task.exclusiveResources);
              unawaited(running.remove(index));
            });
      }
      if (running.isNotEmpty && (!launched || pending.isEmpty)) {
        await Future.any(running.values.toList(growable: false));
      }
    }
    return results.cast<VerificationTaskResult>();
  }
}

VerificationTask _dart(String name, List<String> arguments) =>
    VerificationTask(name: name, executable: 'dart', arguments: arguments);

({int dart, int flutter}) _splitCoverageJobs(int jobs) {
  // Dart owns several package runners and the longest coverage suite, so keep
  // twice the capacity there while Flutter runs concurrently.
  final flutterJobs = jobs == 1 ? 1 : (jobs / 3).ceil();
  final dartJobs = jobs == 1 ? 1 : jobs - flutterJobs;
  return (dart: dartJobs, flutter: flutterJobs);
}

/// Canonical ordering for every immutable workspace source generator.
abstract final class WorkspaceGenerationPlans {
  /// Generates direct source snapshots before package build runners consume
  /// them or verify the rest of the generated tree.
  static VerificationPlan generate({required int jobs}) => VerificationPlan(
    phases: <VerificationPhase>[
      const VerificationPhase(
        tasks: <VerificationTask>[
          VerificationTask(
            name: 'desktop app version',
            executable: 'dart',
            arguments: <String>[
              'run',
              'packages/tinest_quality/bin/sync_desktop_version.dart',
            ],
          ),
          VerificationTask(
            name: 'Flutter localizations',
            executable: 'flutter',
            arguments: <String>['gen-l10n'],
            workingDirectory: 'packages/app',
            exclusiveResources: <String>{'flutter-build'},
          ),
          VerificationTask(
            name: 'provider catalog',
            executable: 'dart',
            arguments: <String>[
              'run',
              'packages/daemon/tool/generate_provider_catalog.dart',
            ],
          ),
          VerificationTask(
            name: 'built-in Lua plugins',
            executable: 'dart',
            arguments: <String>[
              'run',
              'packages/daemon/tool/generate_builtin_plugins.dart',
            ],
          ),
        ],
      ),
      VerificationPhase(
        tasks: <VerificationTask>[
          VerificationTask(
            name: 'build_runner',
            executable: 'dart',
            arguments: <String>[
              'run',
              'melos',
              'exec',
              '--depends-on=build_runner',
              '-c',
              '$jobs',
              '-o',
              '--',
              'dart run build_runner build',
            ],
            cpuSlots: jobs,
          ),
        ],
      ),
      const VerificationPhase(
        tasks: <VerificationTask>[
          VerificationTask(
            name: 'generated source whitespace',
            executable: 'dart',
            arguments: <String>[
              'run',
              'packages/tinest_quality/tool/normalize_generated_sources.dart',
            ],
          ),
        ],
      ),
    ],
  );
}

/// Canonical plans used by the four public Melos quality commands.
abstract final class WorkspaceVerificationPlans {
  static VerificationPhase _generated(int jobs) => VerificationPhase(
    tasks: <VerificationTask>[
      VerificationTask(
        name: 'generated sources',
        executable: 'dart',
        arguments: <String>[
          'run',
          'tinest_quality',
          'generate',
          '--check',
          '--jobs=$jobs',
        ],
        cpuSlots: jobs,
        exclusiveResources: const <String>{'generated-output'},
      ),
    ],
  );

  static List<VerificationTask> _staticTasks(int jobs) {
    final analysisJobs = jobs == 1 ? 1 : (jobs / 2).ceil();
    final dependencyJobs = jobs == 1 ? 1 : jobs - analysisJobs;
    return <VerificationTask>[
      _dart('format', <String>[
        'run',
        'melos',
        'format',
        '--output=none',
        '--set-exit-if-changed',
      ]),
      VerificationTask(
        name: 'analysis',
        executable: 'dart',
        arguments: const <String>['analyze', '--fatal-infos'],
        cpuSlots: analysisJobs,
      ),
      VerificationTask(
        name: 'dependencies',
        executable: 'dart',
        arguments: <String>[
          'run',
          'melos',
          'exec',
          '-c',
          '$dependencyJobs',
          '--',
          'dart run dependency_validator',
        ],
        cpuSlots: dependencyJobs,
      ),
      _dart('Tinyrack dependency sources', const <String>[
        'run',
        'tinyrack_workspace',
        'source-check',
      ]),
      _dart('LuaLS plugin SDK conformance', const <String>[
        'run',
        'packages/daemon/tool/luals_conformance.dart',
      ]),
      _dart('architecture', const <String>[
        'run',
        'tinest_quality',
        '_architecture-check',
      ]),
      _dart('features', const <String>[
        'run',
        'tinest_quality',
        '_features-check',
      ]),
      _dart('Tinyrack design system', const <String>[
        'run',
        'tinyrack_ui:tinyrack_ui_check',
        '--root',
        '.',
      ]),
    ];
  }

  /// Runs every package test exactly once without coverage collection.
  static VerificationPlan tests({required int jobs}) {
    final dartJobs = jobs == 1 ? 1 : (jobs / 2).ceil();
    final flutterJobs = jobs == 1 ? 1 : jobs - dartJobs;
    return VerificationPlan(
      phases: <VerificationPhase>[
        VerificationPhase(
          tasks: <VerificationTask>[
            VerificationTask(
              name: 'Dart tests',
              executable: 'dart',
              arguments: <String>[
                'run',
                'tinest_quality',
                '_test-dart',
                '--jobs=$dartJobs',
                '--report=build/quality/internal/test-dart.json',
              ],
              cpuSlots: dartJobs,
            ),
            VerificationTask(
              name: 'Flutter tests',
              executable: 'dart',
              arguments: <String>[
                'run',
                'tinest_quality',
                '_test-flutter',
                '--jobs=$flutterJobs',
                '--report=build/quality/internal/test-flutter.json',
              ],
              cpuSlots: flutterJobs,
              exclusiveResources: const <String>{'flutter-build'},
            ),
          ],
        ),
      ],
    );
  }

  /// Runs the read-only workspace checks without generation or tests.
  static VerificationPlan staticChecks({required int jobs}) => VerificationPlan(
    phases: <VerificationPhase>[VerificationPhase(tasks: _staticTasks(jobs))],
  );

  /// Runs the complete static and coverage gates on every supported host.
  ///
  /// When [serializeCoverage] is true, each coverage runner receives the full
  /// [jobs] budget in its own phase. Windows uses this mode because Dart and
  /// Flutter coverage share workspace-native assets that cannot be replaced
  /// while another process has them open.
  static VerificationPlan full({
    required int jobs,
    required bool serializeCoverage,
  }) {
    final splitJobs = _splitCoverageJobs(jobs);
    final dartJobs = serializeCoverage ? jobs : splitJobs.dart;
    final flutterJobs = serializeCoverage ? jobs : splitJobs.flutter;
    final coverageTasks = <VerificationTask>[
      VerificationTask(
        name: 'Dart coverage',
        executable: 'dart',
        arguments: <String>[
          'run',
          'tinest_quality',
          '_coverage-dart',
          '--jobs=$dartJobs',
          '--report=build/quality/internal/coverage-dart.json',
        ],
        cpuSlots: dartJobs,
      ),
      VerificationTask(
        name: 'Flutter coverage',
        executable: 'dart',
        arguments: <String>[
          'run',
          'tinest_quality',
          '_coverage-flutter',
          '--jobs=$flutterJobs',
          '--report=build/quality/internal/coverage-flutter.json',
        ],
        cpuSlots: flutterJobs,
        exclusiveResources: const <String>{'flutter-build'},
      ),
    ];
    final coveragePhases = serializeCoverage
        ? <VerificationPhase>[
            for (final task in coverageTasks)
              VerificationPhase(tasks: <VerificationTask>[task]),
          ]
        : <VerificationPhase>[VerificationPhase(tasks: coverageTasks)];
    return VerificationPlan(
      phases: <VerificationPhase>[
        _generated(jobs),
        ...staticChecks(jobs: jobs).phases,
        ...coveragePhases,
        VerificationPhase(
          tasks: <VerificationTask>[
            _dart('coverage thresholds', const <String>[
              'run',
              'tinyrack_workspace',
              'coverage-check',
              '--line=90',
              '--branch=80',
            ]),
          ],
        ),
      ],
    );
  }
}
