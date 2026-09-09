import 'dart:async';

import 'package:app/src/devtools/desktop_host.dart';

/// One independently runnable desktop E2E scenario.
final class DesktopE2eScenario {
  /// Creates a catalog entry.
  const new({required this.id, required this.estimatedSeconds});

  /// Stable command-line identifier.
  final String id;

  /// Measured warm runtime used for deterministic lane balancing.
  final int estimatedSeconds;
}

/// The complete app-owned desktop E2E catalog.
const desktopE2eScenarios = <DesktopE2eScenario>[
  DesktopE2eScenario(id: 'daemon-workspace', estimatedSeconds: 17),
  DesktopE2eScenario(id: 'project-worktree', estimatedSeconds: 12),
  DesktopE2eScenario(id: 'plugin-harness', estimatedSeconds: 18),
  DesktopE2eScenario(id: 'relay', estimatedSeconds: 1),
  DesktopE2eScenario(id: 'conversation-adversity', estimatedSeconds: 6),
  DesktopE2eScenario(id: 'conversation-history', estimatedSeconds: 14),
  DesktopE2eScenario(id: 'conversation-mcp', estimatedSeconds: 30),
  DesktopE2eScenario(id: 'conversation', estimatedSeconds: 54),
  DesktopE2eScenario(id: 'provider', estimatedSeconds: 12),
  DesktopE2eScenario(id: 'settings-desktop', estimatedSeconds: 18),
  DesktopE2eScenario(id: 'desktop-shell', estimatedSeconds: 2),
];

/// Typed command-line options for the app-owned E2E runner.
final class DesktopE2eOptions {
  /// Creates parsed options.
  const new({
    required this.jobs,
    required this.seed,
    this.scenario,
    this.reportPath,
  });

  /// Global CPU budget requested by the caller.
  final int jobs;

  /// Concrete randomized test-order seed.
  final int seed;

  /// Optional focused catalog scenario.
  final String? scenario;

  /// Optional JSON timing report path.
  final String? reportPath;
}

/// One deterministic subset of the scenario catalog.
final class DesktopE2eLane {
  /// Creates a lane.
  const new({required this.index, required this.scenarios});

  /// Zero-based stable lane index.
  final int index;

  /// Scenarios assigned to this lane in catalog order.
  final List<DesktopE2eScenario> scenarios;

  /// Total measured weight assigned to the lane.
  int get estimatedSeconds => scenarios.fold<int>(
    0,
    (total, scenario) => total + scenario.estimatedSeconds,
  );
}

/// One process invocation in a desktop E2E run.
final class DesktopE2eCommand {
  /// Creates a process invocation.
  const new({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
    this.environment = const <String, String>{},
    this.runInShell = false,
  });

  /// Executable passed to the process runtime.
  final String executable;

  /// Ordered command arguments.
  final List<String> arguments;

  /// Directory from which the command starts.
  final String workingDirectory;

  /// Environment overrides for the child process.
  final Map<String, String> environment;

  /// Whether the host shell resolves the executable.
  final bool runInShell;

  /// Returns this command with the supplied environment overrides.
  DesktopE2eCommand withEnvironment(Map<String, String> value) =>
      DesktopE2eCommand(
        executable: executable,
        arguments: arguments,
        workingDirectory: workingDirectory,
        environment: value,
        runInShell: runInShell,
      );
}

/// Platform-specific command plan for the complete desktop E2E suite.
final class DesktopE2ePlan {
  const new _({required this.host, required this.device});

  /// Creates a plan for [host].
  factory forHost(DesktopHost host) =>
      DesktopE2ePlan._(host: host, device: host.name);

  /// Host operating system.
  final DesktopHost host;

  /// Flutter desktop device identifier.
  final String device;

  /// Partitions scenarios with deterministic longest-processing-time packing.
  List<DesktopE2eLane> lanes({required int jobs}) {
    final laneCount = jobs <= 1 ? 1 : 2;
    final assignments = List.generate(
      laneCount,
      (_) => <DesktopE2eScenario>[],
      growable: false,
    );
    final totals = List<int>.filled(laneCount, 0);
    final ordered = [...desktopE2eScenarios]
      ..sort((left, right) {
        final byDuration = right.estimatedSeconds.compareTo(
          left.estimatedSeconds,
        );
        return byDuration != 0 ? byDuration : left.id.compareTo(right.id);
      });
    if (laneCount == 2) {
      final longest = ordered.removeAt(0);
      assignments[0].add(longest);
      totals[0] = longest.estimatedSeconds;
    }
    for (final scenario in ordered) {
      var target = laneCount == 2 ? 1 : 0;
      for (var index = target + 1; index < laneCount; index += 1) {
        if (totals[index] < totals[target]) target = index;
      }
      assignments[target].add(scenario);
      totals[target] += scenario.estimatedSeconds;
    }
    return <DesktopE2eLane>[
      for (var index = 0; index < laneCount; index += 1)
        DesktopE2eLane(
          index: index,
          scenarios: <DesktopE2eScenario>[
            for (final scenario in desktopE2eScenarios)
              if (assignments[index].contains(scenario)) scenario,
          ],
        ),
    ];
  }

  /// Builds the aggregate process command for [lane].
  DesktopE2eCommand commandForLane(DesktopE2eLane lane, {required int seed}) =>
      commandForScenarioIds(
        lane.scenarios.map((scenario) => scenario.id).toList(growable: false),
        seed: seed,
      );

  /// Builds a focused CI command.
  DesktopE2eCommand commandForScenario(String scenarioId, {required int seed}) {
    if (!desktopE2eScenarios.any((scenario) => scenario.id == scenarioId)) {
      throw ArgumentError.value(scenarioId, 'scenarioId', 'unknown scenario');
    }
    return commandForScenarioIds(<String>[scenarioId], seed: seed);
  }

  /// Builds an aggregate command containing [scenarioIds].
  DesktopE2eCommand commandForScenarioIds(
    List<String> scenarioIds, {
    required int seed,
  }) {
    final flutterArguments = <String>[
      '--suppress-analytics',
      'test',
      'integration_test/desktop_e2e_suite_test.dart',
      '-d',
      device,
      '--test-randomize-ordering-seed=$seed',
      '--dart-define=TINEST_E2E_SCENARIOS=${scenarioIds.join(',')}',
    ];
    return DesktopE2eCommand(
      executable: host == DesktopHost.linux ? 'xvfb-run' : 'flutter',
      arguments: host == DesktopHost.linux
          ? <String>['-a', 'flutter', ...flutterArguments]
          : flutterArguments,
      workingDirectory: 'packages/desktop_app',
      runInShell: host == DesktopHost.windows,
    );
  }
}

/// Temporary, isolated resources owned by one lane.
final class DesktopE2eLaneResources {
  /// Creates lane resources.
  const new({
    required this.home,
    required this.configHome,
    required this.temporaryDirectory,
    required this.readinessMarker,
  });

  /// Isolated Tinest home.
  final String home;

  /// Isolated Flutter configuration home.
  final String configHome;

  /// Isolated process temporary directory.
  final String temporaryDirectory;

  /// Application readiness marker path.
  final String readinessMarker;
}

/// Returns the generated build subtree owned by one Windows E2E lane.
String desktopE2eWindowsLaneBuildPath(int laneIndex) {
  if (laneIndex < 0) {
    throw ArgumentError.value(laneIndex, 'laneIndex', 'must be non-negative');
  }
  return 'build/e2e/lane-$laneIndex/windows';
}

/// A started Flutter process with an application-level readiness signal.
abstract interface class DesktopE2eProcess {
  /// Completes when the native app writes its readiness marker.
  Future<void> get ready;

  /// Completes when Flutter exits.
  Future<int> get exitCode;
}

/// Exclusive access to a host project while Flutter prepares a desktop build.
abstract interface class DesktopE2eBuildLease {
  /// Releases the host-project build lease.
  Future<void> release();
}

/// Runtime boundary for filesystem and process operations used by E2E.
abstract interface class DesktopE2eRuntime {
  /// Creates temporary resources for [laneIndex].
  Future<DesktopE2eLaneResources> createLaneResources(int laneIndex);

  /// Starts [command] without waiting for its exit.
  Future<DesktopE2eProcess> start(DesktopE2eCommand command);

  /// Acquires access to [projectDirectory]'s shared ephemeral build files.
  Future<DesktopE2eBuildLease> acquireProjectBuildLease(
    String projectDirectory,
  );

  /// Acquires access to one persistent lane output until its process exits.
  Future<DesktopE2eBuildLease> acquireLaneBuildLease(
    String projectDirectory,
    int laneIndex,
  );

  /// Invalidates Flutter's shared incremental build cache before the first
  /// Windows lane creates target-specific build state.
  Future<void> resetWindowsProjectBuildCache(String projectDirectory);

  /// Resets [laneIndex]'s Windows output before Flutter recreates ephemeral
  /// files.
  Future<void> resetWindowsLaneBuild(String projectDirectory, int laneIndex);

  /// Deletes resources after the lane process exits.
  Future<void> deleteLaneResources(DesktopE2eLaneResources resources);
}

/// Result of one lane.
final class DesktopE2eLaneResult {
  /// Creates a lane result.
  const new({
    required this.lane,
    required this.seed,
    required this.exitCode,
    required this.elapsed,
    required this.readyAfter,
  });

  /// Executed lane.
  final DesktopE2eLane lane;

  /// Concrete randomized test-order seed.
  final int seed;

  /// Flutter process exit code.
  final int exitCode;

  /// Total build and runtime duration.
  final Duration elapsed;

  /// Duration until the native app signaled readiness, when reached.
  final Duration? readyAfter;
}

/// Complete deterministic run result.
final class DesktopE2eRunResult {
  /// Creates a run result.
  const new(this.lanes);

  /// Results in deterministic lane order.
  final List<DesktopE2eLaneResult> lanes;

  /// First non-zero exit code in stable lane order.
  int get exitCode => lanes
      .map((lane) => lane.exitCode)
      .firstWhere((code) => code != 0, orElse: () => 0);
}

/// Runs up to two isolated desktop E2E lanes.
///
/// Windows build phases share `windows/flutter/ephemeral`, so the runtime holds
/// a cross-process lease until the native app is ready. Test execution may then
/// overlap while the next lane builds in its isolated output directory.
final class DesktopE2eRunner {
  /// Creates a runner backed by [runtime].
  const new({
    required this.runtime,
    this.environment = const <String, String>{},
  });

  /// Filesystem and process boundary.
  final DesktopE2eRuntime runtime;

  /// Host build-tool environment inherited by every lane.
  final Map<String, String> environment;

  /// Runs a focused scenario or the adaptive local lane plan.
  Future<DesktopE2eRunResult> run(
    DesktopE2ePlan plan, {
    required int jobs,
    required int seed,
    String? scenario,
  }) async {
    final lanes = scenario == null
        ? plan.lanes(jobs: jobs)
        : <DesktopE2eLane>[
            DesktopE2eLane(
              index: 0,
              scenarios: <DesktopE2eScenario>[
                desktopE2eScenarios.singleWhere((item) => item.id == scenario),
              ],
            ),
          ];
    final windowsProjectDirectory = plan.host == DesktopHost.windows
        ? plan.commandForLane(lanes.first, seed: seed).workingDirectory
        : null;
    try {
      final running = <Future<DesktopE2eLaneResult>>[];
      final first = await _startLane(
        plan,
        lanes.first,
        seed,
        resetWindowsProjectBuildCache: true,
      );
      running.add(first.result);
      if (lanes.length > 1) {
        await first.buildReady;
        running.add(
          (await _startLane(
            plan,
            lanes[1],
            seed + 1,
            resetWindowsProjectBuildCache: false,
          )).result,
        );
      }
      final results = await Future.wait(running);
      results.sort(
        (left, right) => left.lane.index.compareTo(right.lane.index),
      );
      return DesktopE2eRunResult(results);
    } finally {
      if (windowsProjectDirectory != null) {
        final lease = await runtime.acquireProjectBuildLease(
          windowsProjectDirectory,
        );
        try {
          // Flutter test targets and the ordinary desktop target share
          // generated wrapper sources but track ownership in
          // `.dart_tool/flutter_build`. Leave that ownership invalidated so
          // the next Flutter command must reconcile the shared sources instead
          // of trusting an E2E target hash.
          await runtime.resetWindowsProjectBuildCache(windowsProjectDirectory);
        } finally {
          await lease.release();
        }
      }
    }
  }

  Future<_RunningLane> _startLane(
    DesktopE2ePlan plan,
    DesktopE2eLane lane,
    int seed, {
    required bool resetWindowsProjectBuildCache,
  }) async {
    final resources = await runtime.createLaneResources(lane.index);
    final stopwatch = Stopwatch()..start();
    final command = plan.commandForLane(lane, seed: seed).withEnvironment(
      <String, String>{
        ...environment,
        'TINYRACK_TINEST_HOME': resources.home,
        'TINYRACK_TINEST_ALLOW_MULTIPLE_INSTANCES': '1',
        'TINYRACK_TINEST_E2E_READY_FILE': resources.readinessMarker,
        if (plan.host == DesktopHost.windows) ...<String, String>{
          'APPDATA': resources.configHome,
          // Concurrent Flutter tools otherwise share `%TEMP%`; a failed
          // platform process can remove another lane's listener directory
          // while that lane is still finalizing its test protocol.
          'TEMP': resources.temporaryDirectory,
          'TMP': resources.temporaryDirectory,
        },
        if (plan.host != DesktopHost.windows) ...<String, String>{
          'XDG_CONFIG_HOME': resources.configHome,
          'TMPDIR': resources.temporaryDirectory,
        },
      },
    );
    DesktopE2eBuildLease? projectBuildLease;
    DesktopE2eBuildLease? laneBuildLease;
    try {
      if (plan.host == DesktopHost.windows) {
        laneBuildLease = await runtime.acquireLaneBuildLease(
          command.workingDirectory,
          lane.index,
        );
        projectBuildLease = await runtime.acquireProjectBuildLease(
          command.workingDirectory,
        );
        if (resetWindowsProjectBuildCache) {
          await runtime.resetWindowsProjectBuildCache(command.workingDirectory);
        }
        await runtime.resetWindowsLaneBuild(
          command.workingDirectory,
          lane.index,
        );
      }
      final process = await runtime.start(command);
      final readyAt = Completer<Duration?>();
      final buildPhaseFinished = Completer<void>();
      unawaited(
        process.ready.then<void>(
          (_) {
            if (!readyAt.isCompleted) readyAt.complete(stopwatch.elapsed);
            if (!buildPhaseFinished.isCompleted) buildPhaseFinished.complete();
          },
          onError: (_) {
            if (!readyAt.isCompleted) readyAt.complete(null);
          },
        ),
      );
      unawaited(
        process.exitCode.then<void>(
          (_) {
            if (!buildPhaseFinished.isCompleted) buildPhaseFinished.complete();
          },
          onError: (_) {
            if (!buildPhaseFinished.isCompleted) buildPhaseFinished.complete();
          },
        ),
      );
      final buildReady = buildPhaseFinished.future.then<void>((_) async {
        await projectBuildLease?.release();
        projectBuildLease = null;
      });
      final result = () async {
        try {
          final exitCode = await process.exitCode;
          if (!readyAt.isCompleted) readyAt.complete(null);
          return DesktopE2eLaneResult(
            lane: lane,
            seed: seed,
            exitCode: exitCode,
            elapsed: stopwatch.elapsed,
            readyAfter: await readyAt.future,
          );
        } finally {
          try {
            await buildReady;
          } finally {
            try {
              await laneBuildLease?.release();
              laneBuildLease = null;
            } finally {
              stopwatch.stop();
              await runtime.deleteLaneResources(resources);
            }
          }
        }
      }();
      return _RunningLane(buildReady: buildReady, result: result);
    } catch (_) {
      try {
        await projectBuildLease?.release();
      } finally {
        try {
          await laneBuildLease?.release();
        } finally {
          stopwatch.stop();
          await runtime.deleteLaneResources(resources);
        }
      }
      rethrow;
    }
  }
}

final class _RunningLane {
  const new({required this.buildReady, required this.result});

  final Future<void> buildReady;
  final Future<DesktopE2eLaneResult> result;
}
