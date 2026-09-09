import 'dart:async';

import 'package:test/test.dart';
import 'package:tinest_quality/src/verification_runner.dart';

const _task = VerificationTask(
  name: 'task',
  executable: 'dart',
  arguments: <String>['test'],
);

void main() {
  test('generation normalizes Freezed output after build_runner', () async {
    final plan = WorkspaceGenerationPlans.generate(jobs: 4);
    expect(plan.phases, hasLength(3));
    expect(plan.phases.first.tasks.map((task) => task.name), <String>[
      'desktop app version',
      'Flutter localizations',
      'provider catalog',
      'built-in Lua plugins',
    ]);
    final builtIns = plan.phases.first.tasks.last;
    expect(builtIns.executable, 'dart');
    expect(builtIns.arguments, <String>[
      'run',
      'packages/daemon/tool/generate_builtin_plugins.dart',
    ]);
    expect(plan.phases[1].tasks.single.name, 'build_runner');
    final normalization = plan.phases.last.tasks.single;
    expect(normalization.name, 'generated source whitespace');
    expect(normalization.arguments, <String>[
      'run',
      'packages/tinest_quality/tool/normalize_generated_sources.dart',
    ]);

    final executor = _ControlledExecutor();
    final run = VerificationRunner(executor: executor, maxJobs: 4).run(plan);
    expect(executor.started, <String>[
      'desktop app version',
      'Flutter localizations',
      'provider catalog',
      'built-in Lua plugins',
    ]);
    executor.complete('built-in Lua plugins');
    await pumpEventQueue();
    expect(executor.started, isNot(contains('build_runner')));
    executor
      ..complete('desktop app version')
      ..complete('Flutter localizations')
      ..complete('provider catalog');
    await pumpEventQueue();
    expect(executor.started.last, 'build_runner');
    executor.complete('build_runner');
    await pumpEventQueue();
    expect(executor.started.last, 'generated source whitespace');
    executor.complete('generated source whitespace');

    expect((await run).succeeded, isTrue);
  });

  test('runs phases in order and tasks within a phase concurrently', () async {
    final executor = _ControlledExecutor();
    final run = VerificationRunner(executor: executor, maxJobs: 2).run(
      const VerificationPlan(
        phases: <VerificationPhase>[
          VerificationPhase(
            tasks: <VerificationTask>[
              VerificationTask(
                name: 'generate',
                executable: 'dart',
                arguments: <String>['run', 'generator'],
              ),
            ],
          ),
          VerificationPhase(
            tasks: <VerificationTask>[
              VerificationTask(
                name: 'analyze',
                executable: 'dart',
                arguments: <String>['analyze'],
              ),
              VerificationTask(
                name: 'dart tests',
                executable: 'dart',
                arguments: <String>['test'],
              ),
              VerificationTask(
                name: 'flutter tests',
                executable: 'flutter',
                arguments: <String>['test'],
              ),
            ],
          ),
        ],
      ),
    );

    expect(executor.started, <String>['generate']);
    executor.complete('generate');
    await pumpEventQueue();
    expect(executor.started, <String>['generate', 'analyze', 'dart tests']);
    executor.complete('analyze');
    await pumpEventQueue();
    expect(executor.started.last, 'flutter tests');
    executor
      ..complete('dart tests')
      ..complete('flutter tests');

    final report = await run;
    expect(report.succeeded, isTrue);
    expect(executor.maximumActive, 2);
  });

  test('aggregates current-phase failures and skips later phases', () async {
    final executor = _ImmediateExecutor(const <String, int>{
      'analyze': 1,
      'tests': 2,
    });
    final report = await VerificationRunner(executor: executor, maxJobs: 4).run(
      const VerificationPlan(
        phases: <VerificationPhase>[
          VerificationPhase(
            tasks: <VerificationTask>[
              VerificationTask(
                name: 'analyze',
                executable: 'dart',
                arguments: <String>['analyze'],
              ),
              VerificationTask(
                name: 'tests',
                executable: 'dart',
                arguments: <String>['test'],
              ),
            ],
          ),
          VerificationPhase(tasks: <VerificationTask>[_task]),
        ],
      ),
    );

    expect(report.succeeded, isFalse);
    expect(report.failures.map((failure) => failure.exitCode), <int>[1, 2]);
    expect(executor.started, <String>['analyze', 'tests']);
  });

  test('never exceeds the job budget and honors exclusive resources', () async {
    final executor = _ControlledExecutor();
    final run = VerificationRunner(executor: executor, maxJobs: 4).run(
      const VerificationPlan(
        phases: <VerificationPhase>[
          VerificationPhase(
            tasks: <VerificationTask>[
              VerificationTask(
                name: 'heavy',
                executable: 'dart',
                arguments: <String>['test'],
                cpuSlots: 3,
              ),
              VerificationTask(
                name: 'small',
                executable: 'dart',
                arguments: <String>['test'],
              ),
              VerificationTask(
                name: 'flutter one',
                executable: 'flutter',
                arguments: <String>['test'],
                exclusiveResources: <String>{'flutter-build'},
              ),
              VerificationTask(
                name: 'flutter two',
                executable: 'flutter',
                arguments: <String>['test'],
                exclusiveResources: <String>{'flutter-build'},
              ),
            ],
          ),
        ],
      ),
    );

    expect(executor.started, <String>['heavy', 'small']);
    expect(executor.activeSlots, 4);
    executor.complete('small');
    await pumpEventQueue();
    expect(executor.started, contains('flutter one'));
    expect(executor.started, isNot(contains('flutter two')));
    executor.complete('heavy');
    await pumpEventQueue();
    expect(executor.started, isNot(contains('flutter two')));
    executor.complete('flutter one');
    await pumpEventQueue();
    expect(executor.started.last, 'flutter two');
    executor.complete('flutter two');

    expect((await run).succeeded, isTrue);
    expect(executor.maximumActiveSlots, 4);
  });

  test('canonical plans derive child concurrency from the job budget', () {
    final tests = WorkspaceVerificationPlans.tests(jobs: 8);
    final full = WorkspaceVerificationPlans.full(
      jobs: 32,
      serializeCoverage: false,
    );

    expect(_commands(tests), contains(contains('_test-dart --jobs=4')));
    expect(_commands(tests), contains(contains('_test-flutter --jobs=4')));
    expect(_commands(tests), everyElement(contains('--report=')));
    expect(_commands(full), contains(contains('_coverage-dart --jobs=21')));
    expect(_commands(full), contains(contains('_coverage-flutter --jobs=11')));
    expect(_commands(full), contains(contains('exec -c 16')));
    expect(
      _commands(full),
      contains('dart run packages/daemon/tool/luals_conformance.dart'),
    );
  });

  test('full verification finishes generation before the format gate', () {
    final full = WorkspaceVerificationPlans.full(
      jobs: 8,
      serializeCoverage: false,
    );
    final generatedPhase = full.phases.indexWhere(
      (phase) => phase.tasks.any((task) => task.name == 'generated sources'),
    );
    final formatPhase = full.phases.indexWhere(
      (phase) => phase.tasks.any((task) => task.name == 'format'),
    );

    expect(generatedPhase, isNonNegative);
    expect(formatPhase, greaterThan(generatedPhase));
    expect(full.phases[generatedPhase].tasks, hasLength(1));
  });

  test('non-Windows full verification overlaps coverage', () {
    final full = WorkspaceVerificationPlans.full(
      jobs: 8,
      serializeCoverage: false,
    );
    final coveragePhase = full.phases.singleWhere(
      (phase) => phase.tasks.any((task) => task.name == 'Dart coverage'),
    );

    expect(coveragePhase.tasks.map((task) => task.name), <String>[
      'Dart coverage',
      'Flutter coverage',
    ]);
    expect(
      coveragePhase.tasks.fold<int>(0, (slots, task) => slots + task.cpuSlots),
      8,
    );
  });

  test('Windows full verification serializes native-asset coverage', () {
    final full = WorkspaceVerificationPlans.full(
      jobs: 8,
      serializeCoverage: true,
    );
    final dartCoveragePhase = full.phases.indexWhere(
      (phase) => phase.tasks.any((task) => task.name == 'Dart coverage'),
    );
    final flutterCoveragePhase = full.phases.indexWhere(
      (phase) => phase.tasks.any((task) => task.name == 'Flutter coverage'),
    );

    expect(dartCoveragePhase, isNonNegative);
    expect(flutterCoveragePhase, greaterThan(dartCoveragePhase));
    expect(full.phases[dartCoveragePhase].tasks, hasLength(1));
    expect(full.phases[flutterCoveragePhase].tasks, hasLength(1));
    expect(full.phases[dartCoveragePhase].tasks.single.cpuSlots, 8);
    expect(full.phases[flutterCoveragePhase].tasks.single.cpuSlots, 8);
    expect(
      full.phases[dartCoveragePhase].tasks.single.arguments,
      contains('--jobs=8'),
    );
    expect(
      full.phases[flutterCoveragePhase].tasks.single.arguments,
      contains('--jobs=8'),
    );
  });

  test('canonical plans run each suite once on every host', () {
    final tests = WorkspaceVerificationPlans.tests(jobs: 4);
    final full = WorkspaceVerificationPlans.full(
      jobs: 4,
      serializeCoverage: false,
    );

    expect(
      _commands(tests).where((value) => value.contains('_test-dart')),
      hasLength(1),
    );
    expect(
      _commands(tests).where((value) => value.contains('_test-flutter')),
      hasLength(1),
    );
    expect(
      _commands(full).where((value) => value.contains('_coverage-dart')),
      hasLength(1),
    );
    expect(
      _commands(full).where((value) => value.contains('_coverage-flutter')),
      hasLength(1),
    );
    expect(_commands(full).any((value) => value.contains('_golden')), isFalse);
    expect(
      _commands(full).singleWhere((value) => value.contains('coverage-check')),
      allOf(contains('--line=90'), contains('--branch=80')),
    );
  });
}

List<String> _commands(VerificationPlan plan) => <String>[
  for (final phase in plan.phases)
    for (final task in phase.tasks)
      '${task.executable} ${task.arguments.join(' ')}',
];

final class _ImmediateExecutor implements VerificationTaskExecutor {
  new(this.exitCodes);

  final Map<String, int> exitCodes;
  final List<String> started = <String>[];

  @override
  Future<VerificationTaskResult> run(VerificationTask task) async {
    started.add(task.name);
    return VerificationTaskResult(
      task: task,
      exitCode: exitCodes[task.name] ?? 0,
      duration: Duration.zero,
    );
  }
}

final class _ControlledExecutor implements VerificationTaskExecutor {
  final List<String> started = <String>[];
  final Map<String, Completer<VerificationTaskResult>> _completers = {};
  var _active = 0;
  int maximumActive = 0;
  int activeSlots = 0;
  int maximumActiveSlots = 0;

  @override
  Future<VerificationTaskResult> run(VerificationTask task) {
    started.add(task.name);
    _active += 1;
    activeSlots += task.cpuSlots;
    if (_active > maximumActive) maximumActive = _active;
    if (activeSlots > maximumActiveSlots) {
      maximumActiveSlots = activeSlots;
    }
    final completer = Completer<VerificationTaskResult>();
    _completers[task.name] = completer;
    return completer.future.whenComplete(() {
      _active -= 1;
      activeSlots -= task.cpuSlots;
    });
  }

  void complete(String name) {
    final task = VerificationTask(
      name: name,
      executable: 'dart',
      arguments: const <String>[],
    );
    _completers[name]!.complete(
      VerificationTaskResult(task: task, exitCode: 0, duration: Duration.zero),
    );
  }
}
