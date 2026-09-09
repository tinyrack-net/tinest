import 'dart:async';
import 'dart:io';

import 'package:app/src/devtools/desktop_e2e_runner.dart';
import 'package:app/src/devtools/desktop_host.dart';
import 'package:test/test.dart';

void main() {
  test('desktop hosts map to Flutter devices and Linux alone uses Xvfb', () {
    final linux = DesktopE2ePlan.forHost(DesktopHost.linux);
    final macos = DesktopE2ePlan.forHost(DesktopHost.macos);
    final windows = DesktopE2ePlan.forHost(DesktopHost.windows);
    final lane = windows.lanes(jobs: 1).single;

    expect(linux.commandForLane(lane, seed: 7).executable, 'xvfb-run');
    expect(macos.commandForLane(lane, seed: 7).executable, 'flutter');
    expect(windows.commandForLane(lane, seed: 7).executable, 'flutter');
    expect(windows.commandForLane(lane, seed: 7).runInShell, isTrue);
    expect(macos.commandForLane(lane, seed: 7).runInShell, isFalse);
    expect(
      windows.commandForLane(lane, seed: 7).arguments,
      containsAll(<String>[
        '-d',
        'windows',
        '--test-randomize-ordering-seed=7',
      ]),
    );
    expect(
      linux.commandForLane(lane, seed: 7).arguments,
      isNot(contains('--no-pub')),
      reason: 'clean isolated build directories need plugin symlink bootstrap',
    );
  });

  test('jobs adapt to one or two exact-once deterministic lanes', () {
    for (final jobs in <int>[1, 2, 4, 8, 32]) {
      final plan = DesktopE2ePlan.forHost(DesktopHost.windows);
      final first = plan.lanes(jobs: jobs);
      final second = plan.lanes(jobs: jobs);
      expect(first, hasLength(jobs == 1 ? 1 : 2));
      expect(
        first.expand((lane) => lane.scenarios).map((scenario) => scenario.id),
        unorderedEquals(desktopE2eScenarios.map((scenario) => scenario.id)),
      );
      expect(
        first.map((lane) => lane.scenarios.map((item) => item.id).toList()),
        second.map((lane) => lane.scenarios.map((item) => item.id).toList()),
      );
    }
  });

  test('integration dispatcher registers every catalog scenario once', () {
    final dispatcher = File(
      '../desktop_app/integration_test/desktop_e2e_suite_test.dart',
    ).readAsStringSync();
    for (final scenario in desktopE2eScenarios) {
      expect(
        RegExp("'${RegExp.escape(scenario.id)}':").allMatches(dispatcher),
        hasLength(1),
        reason: scenario.id,
      );
    }
  });

  test('longest scenario is isolated from the remaining measured work', () {
    final lanes = DesktopE2ePlan.forHost(DesktopHost.windows).lanes(jobs: 32);
    final longest = desktopE2eScenarios.reduce(
      (left, right) =>
          right.estimatedSeconds > left.estimatedSeconds ? right : left,
    );
    expect(lanes.first.scenarios.map((scenario) => scenario.id), <String>[
      longest.id,
    ]);
    // Everything that is not the long pole shares the other lane. Derived from
    // the catalog rather than written out, so re-estimating a scenario or
    // splitting one does not turn this into an arithmetic puzzle.
    expect(
      lanes.last.estimatedSeconds,
      desktopE2eScenarios
          .where((scenario) => scenario.id != longest.id)
          .fold<int>(0, (sum, scenario) => sum + scenario.estimatedSeconds),
    );
  });

  test('non-Windows second lane waits for application readiness', () async {
    final runtime = _FakeDesktopE2eRuntime();
    final future = DesktopE2eRunner(runtime: runtime)
        .run(DesktopE2ePlan.forHost(DesktopHost.macos), jobs: 4, seed: 100);
    await Future<void>.delayed(Duration.zero);
    expect(runtime.commands, hasLength(1));

    runtime.processes.first.markReady();
    await Future<void>.delayed(Duration.zero);
    expect(runtime.commands, hasLength(2));
    runtime.processes.first.finish(0);
    runtime.processes.last
      ..markReady()
      ..finish(0);

    final result = await future;
    expect(result.exitCode, 0);
    expect(result.lanes.map((lane) => lane.seed), <int>[100, 101]);
    expect(runtime.deleted, <int>[0, 1]);
    expect(
      runtime.commands.map((command) => command.environment['TMPDIR']),
      <String>[r'C:\temp\lane-0', r'C:\temp\lane-1'],
    );
  });

  test('Windows lane build phases do not overlap', () async {
    final runtime = _FakeDesktopE2eRuntime();
    final future = DesktopE2eRunner(runtime: runtime)
        .run(DesktopE2ePlan.forHost(DesktopHost.windows), jobs: 2, seed: 200);
    await Future<void>.delayed(Duration.zero);
    expect(runtime.commands, hasLength(1));

    runtime.processes.first.markReady();
    await Future<void>.delayed(Duration.zero);
    expect(
      runtime.commands,
      hasLength(2),
      reason: 'the first native app is ready, so only test execution overlaps',
    );

    runtime.processes.first.finish(0);
    runtime.processes.last
      ..markReady()
      ..finish(0);

    final result = await future;
    expect(result.exitCode, 0);
    expect(result.lanes.map((lane) => lane.seed), <int>[200, 201]);
    expect(runtime.builds.maximumActiveBuilds, 1);
    expect(
      runtime.projectBuildCacheResets,
      2,
      reason:
          'the runner must invalidate shared Flutter ownership both before '
          'the E2E targets and after every lane has exited',
    );
    expect(runtime.windowsPreparationEvents, <String>[
      'project-cache',
      'lane-0',
      'lane-1',
      'project-cache',
    ]);
  });

  test(
    'independent Windows runners never overlap persistent lane output',
    () async {
      final builds = _FakeSharedBuildCoordinator();
      final firstRuntime = _FakeDesktopE2eRuntime(builds: builds);
      final secondRuntime = _FakeDesktopE2eRuntime(builds: builds);
      final firstFuture = DesktopE2eRunner(runtime: firstRuntime)
          .run(DesktopE2ePlan.forHost(DesktopHost.windows), jobs: 1, seed: 300);
      await Future<void>.delayed(Duration.zero);
      firstRuntime.processes.single.markReady();
      await Future<void>.delayed(Duration.zero);
      final secondFuture = DesktopE2eRunner(runtime: secondRuntime)
          .run(DesktopE2ePlan.forHost(DesktopHost.windows), jobs: 1, seed: 301);
      await Future<void>.delayed(Duration.zero);
      expect(
        secondRuntime.commands,
        isEmpty,
        reason: 'both runner invocations own persistent lane-0 output',
      );

      firstRuntime.processes.single.finish(0);
      for (
        var turn = 0;
        turn < 3 && secondRuntime.processes.isEmpty;
        turn += 1
      ) {
        await Future<void>.delayed(Duration.zero);
      }
      secondRuntime.processes.single
        ..markReady()
        ..finish(0);
      await Future.wait(<Future<DesktopE2eRunResult>>[
        firstFuture,
        secondFuture,
      ]);

      expect(builds.maximumActiveBuilds, 1);
      expect(builds.maximumActiveLaneBuilds(0), 1);
    },
  );

  test('Windows repairs partially missing lane state before Flutter', () async {
    final runtime = _FakeDesktopE2eRuntime(
      missingWindowsGeneratedSources: <String>{'plugin_registrar.cc'},
    );
    final future = DesktopE2eRunner(runtime: runtime)
        .run(DesktopE2ePlan.forHost(DesktopHost.windows), jobs: 1, seed: 302);
    await Future<void>.delayed(Duration.zero);

    expect(runtime.invalidatedWindowsLanes, <int>[0]);
    expect(runtime.startedWithIncompleteWindowsState, isFalse);
    runtime.processes.single
      ..markReady()
      ..finish(0);
    expect((await future).exitCode, 0);
  });

  test(
    'Windows invalidates a complete lane before Flutter recreates ephemeral',
    () async {
      final runtime = _FakeDesktopE2eRuntime();
      final future = DesktopE2eRunner(runtime: runtime)
          .run(DesktopE2ePlan.forHost(DesktopHost.windows), jobs: 1, seed: 303);
      await Future<void>.delayed(Duration.zero);

      expect(runtime.invalidatedWindowsLanes, <int>[0]);
      runtime.processes.single
        ..markReady()
        ..finish(0);
      expect((await future).exitCode, 0);
    },
  );

  test('Windows reset guards its lane-owned target path', () {
    expect(desktopE2eWindowsLaneBuildPath(1), 'build/e2e/lane-1/windows');
    expect(() => desktopE2eWindowsLaneBuildPath(-1), throwsArgumentError);
  });

  test(
    'Windows readiness errors retain the project lease until exit',
    () async {
      final runtime = _FakeDesktopE2eRuntime();
      final future = DesktopE2eRunner(runtime: runtime)
          .run(DesktopE2ePlan.forHost(DesktopHost.windows), jobs: 2, seed: 303);
      await Future<void>.delayed(Duration.zero);
      runtime.processes.single.failReadiness();
      await Future<void>.delayed(Duration.zero);
      expect(runtime.commands, hasLength(1));

      runtime.processes.single.finish(0);
      for (var turn = 0; turn < 3 && runtime.processes.length < 2; turn += 1) {
        await Future<void>.delayed(Duration.zero);
      }
      runtime.processes.last
        ..markReady()
        ..finish(0);
      final result = await future;
      expect(result.exitCode, 0);
      expect(result.lanes.map((lane) => lane.seed), <int>[303, 304]);
      expect(runtime.builds.maximumActiveBuilds, 1);
    },
  );

  test('early failure still launches and completes the other lane', () async {
    final runtime = _FakeDesktopE2eRuntime();
    final future = DesktopE2eRunner(runtime: runtime)
        .run(DesktopE2ePlan.forHost(DesktopHost.windows), jobs: 8, seed: 9);
    await Future<void>.delayed(Duration.zero);
    runtime.processes.first.finish(69);
    await Future<void>.delayed(Duration.zero);
    expect(runtime.commands, hasLength(2));
    runtime.processes.last
      ..markReady()
      ..finish(70);

    final result = await future;
    expect(result.exitCode, 69);
    expect(result.lanes.map((lane) => lane.exitCode), <int>[69, 70]);
    expect(runtime.deleted, <int>[0, 1]);
  });

  test(
    'Windows invalidates project cache after lane resource cleanup fails',
    () async {
      final cleanupFailure = StateError('lane cleanup failed');
      final runtime = _FakeDesktopE2eRuntime(
        laneResourceDeletionFailure: cleanupFailure,
      );
      final run = DesktopE2eRunner(runtime: runtime)
          .run(DesktopE2ePlan.forHost(DesktopHost.windows), jobs: 1, seed: 10);
      await Future<void>.delayed(Duration.zero);
      final failure = expectLater(run, throwsA(same(cleanupFailure)));

      runtime.processes.single
        ..markReady()
        ..finish(0);

      await failure;
      expect(
        runtime.projectBuildCacheResets,
        2,
        reason: 'the final invalidation must run even when lane cleanup fails',
      );
    },
  );

  test(
    'lanes use independent home config readiness and build directories',
    () async {
      final runtime = _FakeDesktopE2eRuntime();
      final future = DesktopE2eRunner(runtime: runtime)
          .run(DesktopE2ePlan.forHost(DesktopHost.windows), jobs: 2, seed: 2);
      await Future<void>.delayed(Duration.zero);
      runtime.processes.first
        ..markReady()
        ..finish(0);
      await Future<void>.delayed(Duration.zero);
      expect(runtime.processes, hasLength(2));
      for (final process in runtime.processes) {
        process
          ..markReady()
          ..finish(0);
      }
      await future;

      expect(
        runtime.commands.map((command) => command.environment['APPDATA']),
        <String>[r'C:\config\lane-0', r'C:\config\lane-1'],
      );
      expect(
        runtime.commands.map(
          (command) => command.environment['TINYRACK_TINEST_HOME'],
        ),
        <String>[r'C:\home\lane-0', r'C:\home\lane-1'],
      );
      expect(
        runtime.commands.map((command) => command.environment['TEMP']),
        <String>[r'C:\temp\lane-0', r'C:\temp\lane-1'],
      );
      expect(
        runtime.commands.map((command) => command.environment['TMP']),
        <String>[r'C:\temp\lane-0', r'C:\temp\lane-1'],
      );
    },
  );

  test('macOS Lua host phase is incremental', () {
    final project = File(
      '../desktop_app/macos/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final start = project.indexOf('/* Bundle Lua Host */ = {');
    final end = project.indexOf('\n\t\t};', start);
    final phase = project.substring(start, end);
    expect(phase, isNot(contains('alwaysOutOfDate = 1')));
    expect(phase, contains(r'$(PROJECT_DIR)/../../../pubspec.lock'));
    expect(phase, contains('lua-tool-runtime-host'));
  });
}

final class _FakeDesktopE2eRuntime implements DesktopE2eRuntime {
  new({
    _FakeSharedBuildCoordinator? builds,
    Set<String> missingWindowsGeneratedSources = const <String>{},
    this.laneResourceDeletionFailure,
  }) : builds = builds ?? _FakeSharedBuildCoordinator(),
       missingWindowsGeneratedSources = <String>{
         ...missingWindowsGeneratedSources,
       };

  final _FakeSharedBuildCoordinator builds;
  final Set<String> missingWindowsGeneratedSources;
  final Error? laneResourceDeletionFailure;
  bool startedWithIncompleteWindowsState = false;
  int projectBuildCacheResets = 0;
  final List<String> windowsPreparationEvents = <String>[];
  final List<int> invalidatedWindowsLanes = <int>[];
  final List<DesktopE2eCommand> commands = <DesktopE2eCommand>[];
  final List<_FakeProcess> processes = <_FakeProcess>[];
  final List<int> deleted = <int>[];

  @override
  Future<DesktopE2eBuildLease> acquireProjectBuildLease(
    String projectDirectory,
  ) => builds.acquireProject();

  @override
  Future<DesktopE2eBuildLease> acquireLaneBuildLease(
    String projectDirectory,
    int laneIndex,
  ) => builds.acquireLane(laneIndex);

  @override
  Future<DesktopE2eLaneResources> createLaneResources(int laneIndex) async =>
      DesktopE2eLaneResources(
        home: 'C:\\home\\lane-$laneIndex',
        configHome: 'C:\\config\\lane-$laneIndex',
        temporaryDirectory: 'C:\\temp\\lane-$laneIndex',
        readinessMarker: 'C:\\ready\\lane-$laneIndex',
      );

  @override
  Future<void> deleteLaneResources(DesktopE2eLaneResources resources) async {
    deleted.add(int.parse(resources.home.substring(resources.home.length - 1)));
    final failure = laneResourceDeletionFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<void> resetWindowsLaneBuild(
    String projectDirectory,
    int laneIndex,
  ) async {
    invalidatedWindowsLanes.add(laneIndex);
    windowsPreparationEvents.add('lane-$laneIndex');
    missingWindowsGeneratedSources.clear();
  }

  @override
  Future<void> resetWindowsProjectBuildCache(String projectDirectory) async {
    expect(builds.activeProjectBuilds, 1);
    projectBuildCacheResets += 1;
    windowsPreparationEvents.add('project-cache');
  }

  @override
  Future<DesktopE2eProcess> start(DesktopE2eCommand command) async {
    startedWithIncompleteWindowsState |=
        missingWindowsGeneratedSources.isNotEmpty;
    commands.add(command);
    final process = _FakeProcess();
    processes.add(process);
    return process;
  }
}

final class _FakeSharedBuildCoordinator {
  final _FakeBuildLeaseCoordinator _project = _FakeBuildLeaseCoordinator();
  final Map<int, _FakeBuildLeaseCoordinator> _lanes =
      <int, _FakeBuildLeaseCoordinator>{};

  int get maximumActiveBuilds => _project.maximumActiveBuilds;

  int get activeProjectBuilds => _project.activeBuilds;

  Future<_FakeDesktopE2eBuildLease> acquireProject() => _project.acquire();

  Future<_FakeDesktopE2eBuildLease> acquireLane(int laneIndex) =>
      _lanes.putIfAbsent(laneIndex, _FakeBuildLeaseCoordinator.new).acquire();

  int maximumActiveLaneBuilds(int laneIndex) =>
      _lanes[laneIndex]?.maximumActiveBuilds ?? 0;
}

final class _FakeBuildLeaseCoordinator {
  final List<Completer<void>> _waiters = <Completer<void>>[];
  int activeBuilds = 0;
  int maximumActiveBuilds = 0;

  Future<_FakeDesktopE2eBuildLease> acquire() async {
    if (activeBuilds > 0) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    }
    activeBuilds += 1;
    if (activeBuilds > maximumActiveBuilds) {
      maximumActiveBuilds = activeBuilds;
    }
    return _FakeDesktopE2eBuildLease(this);
  }

  void release() {
    activeBuilds -= 1;
    if (_waiters.isNotEmpty) _waiters.removeAt(0).complete();
  }
}

final class _FakeDesktopE2eBuildLease implements DesktopE2eBuildLease {
  new(this._coordinator);

  final _FakeBuildLeaseCoordinator _coordinator;
  bool _released = false;

  @override
  Future<void> release() async {
    if (_released) return;
    _released = true;
    _coordinator.release();
  }
}

final class _FakeProcess implements DesktopE2eProcess {
  final Completer<void> _ready = Completer<void>();
  final Completer<int> _exitCode = Completer<int>();

  @override
  Future<void> get ready => _ready.future;

  @override
  Future<int> get exitCode => _exitCode.future;

  void markReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  void failReadiness() {
    if (!_ready.isCompleted) {
      _ready.completeError(StateError('readiness watcher failed'));
    }
  }

  void finish(int code) {
    if (!_exitCode.isCompleted) _exitCode.complete(code);
  }
}
