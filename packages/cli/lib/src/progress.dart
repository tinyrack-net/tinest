/// Reports the progress of a long-running command step.
///
/// Command bodies depend on this narrow port rather than on a terminal
/// spinner, so a test can observe the reported steps without a TTY.
abstract interface class CliProgress {
  /// Announces that a step has begun.
  void start(String message);

  /// Marks the running step as finished.
  void succeed(String message);

  /// Marks the running step as failed.
  void fail(String message);
}

/// A [CliProgress] that reports nothing.
///
/// This is the default for command bodies so that a caller which does not
/// own a terminal never has to build one.
final class SilentCliProgress implements CliProgress {
  /// Creates a silent progress reporter.
  const new();

  @override
  void start(String message) {}

  @override
  void succeed(String message) {}

  @override
  void fail(String message) {}
}
