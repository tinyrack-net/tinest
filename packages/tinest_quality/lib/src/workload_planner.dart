/// Test-suite workload used to divide a global process budget.
final class PackageWorkload {
  /// Creates one named package workload.
  const new({required this.name, required this.suites});

  /// Pub package name.
  final String name;

  /// Number of independently runnable test suites.
  final int suites;
}

/// Allocates [jobs] proportionally while keeping every package runnable.
Map<String, int> allocatePackageJobs(
  List<PackageWorkload> workloads,
  int jobs,
) {
  if (jobs <= 0) throw ArgumentError.value(jobs, 'jobs', 'must be positive');
  if (workloads.isEmpty) return const <String, int>{};
  if (workloads.any((workload) => workload.suites <= 0)) {
    throw ArgumentError.value(
      workloads,
      'workloads',
      'suites must be positive',
    );
  }
  final allocations = <String, int>{
    for (final workload in workloads) workload.name: 1,
  };
  var remaining = jobs - workloads.length;
  if (remaining <= 0) return allocations;

  // What decides how long the command takes is the package that finishes last,
  // so each spare slot goes to whichever package currently has the most suites
  // per slot. Splitting the spare slots in proportion to suite counts instead
  // reads as fair and is not: measured on CI, `daemon` held 73% of the suites,
  // was handed 5 of 14 slots, and spent 454 of the job's 454 seconds while the
  // other seven packages finished inside a minute and left their slots idle.
  //
  // Ties go to the lowest package name so a plan is reproducible whatever order
  // the packages were discovered in.
  while (remaining > 0) {
    var chosen = workloads.first;
    var worst = chosen.suites / allocations[chosen.name]!;
    for (final workload in workloads.skip(1)) {
      final ratio = workload.suites / allocations[workload.name]!;
      final better =
          ratio > worst ||
          (ratio == worst && workload.name.compareTo(chosen.name) < 0);
      if (better) {
        chosen = workload;
        worst = ratio;
      }
    }
    allocations[chosen.name] = allocations[chosen.name]! + 1;
    remaining -= 1;
  }
  return allocations;
}
