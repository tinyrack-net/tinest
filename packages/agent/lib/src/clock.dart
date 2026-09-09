/// Wall-clock port shared by everything that must never call `DateTime.now()`.
abstract interface class Clock {
  /// The current UTC instant.
  DateTime nowUtc();
}

/// Production clock over the system time.
final class SystemClock implements Clock {
  /// Creates the production clock.
  const new();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}
