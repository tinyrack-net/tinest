import 'package:client/client.dart';

/// Probe interval for the currently active host path.
const Duration activeHostPathProbeInterval = Duration(seconds: 10);

/// Probe interval for inactive paths while the daemon remains online.
const Duration inactiveHostPathProbeInterval = Duration(seconds: 120);

/// Result of one connection-path handshake probe.
final class HostPathObservation {
  /// Records a successful authenticated handshake.
  const new success(
    this.connection, {
    required this.latency,
    required this.serverId,
  }) : available = true;

  /// Records a failed probe without synthetic latency or daemon identity.
  const new failure(this.connection)
    : available = false,
      latency = Duration.zero,
      serverId = null;

  /// Path that was probed.
  final HostConnection connection;

  /// Whether its full transport and daemon handshake succeeded.
  final bool available;

  /// End-to-end handshake latency when [available].
  final Duration latency;

  /// Authoritative daemon identity returned by the handshake.
  final String? serverId;
}

/// Stateful failover and anti-flapping policy shared by all app platforms.
final class HostPathPolicy {
  /// Creates a policy pinned to one daemon identity.
  new({required this.authoritativeServerId});

  /// Expected server ID for every eligible path.
  final String authoritativeServerId;

  HostConnection? _active;
  String? _fasterCandidateId;
  int _fasterCandidateStreak = 0;

  /// Current selected path, when initial selection has completed.
  HostConnection? get active => _active;

  /// Accepts the first fully handshaken path during parallel startup.
  void selectInitial(HostConnection connection) {
    _active = connection;
    _resetPerformanceCandidate();
  }

  /// Applies immediate failure failover and three-sample latency hysteresis.
  HostConnection? evaluate(List<HostPathObservation> observations) {
    final active = _active;
    if (active == null) {
      final initial = _fastestEligible(observations);
      if (initial != null) {
        selectInitial(initial.connection);
      }
      return _active;
    }
    final activeObservation = observations
        .where((item) => item.connection.id == active.id)
        .firstOrNull;
    final alternatives = observations
        .where(
          (item) =>
              item.connection.id != active.id &&
              item.available &&
              item.serverId == authoritativeServerId,
        )
        .toList(growable: false);
    if (activeObservation == null ||
        !activeObservation.available ||
        activeObservation.serverId != authoritativeServerId) {
      final replacement = _fastestEligible(alternatives);
      if (replacement != null) {
        selectInitial(replacement.connection);
      }
      return _active;
    }
    final candidate = _fastestEligible(alternatives);
    if (candidate == null ||
        activeObservation.latency - candidate.latency <
            const Duration(milliseconds: 40)) {
      _resetPerformanceCandidate();
      return active;
    }
    if (_fasterCandidateId == candidate.connection.id) {
      _fasterCandidateStreak += 1;
    } else {
      _fasterCandidateId = candidate.connection.id;
      _fasterCandidateStreak = 1;
    }
    if (_fasterCandidateStreak >= 3) {
      selectInitial(candidate.connection);
    }
    return _active;
  }

  HostPathObservation? _fastestEligible(
    Iterable<HostPathObservation> observations,
  ) {
    HostPathObservation? fastest;
    for (final observation in observations) {
      if (!observation.available ||
          observation.serverId != authoritativeServerId) {
        continue;
      }
      if (fastest == null || observation.latency < fastest.latency) {
        fastest = observation;
      }
    }
    return fastest;
  }

  void _resetPerformanceCandidate() {
    _fasterCandidateId = null;
    _fasterCandidateStreak = 0;
  }
}
