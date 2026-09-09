import 'dart:async';

import 'package:app/testing/features/hosts/domain/host_models.dart';
import 'package:app/testing/features/hosts/domain/host_ports.dart';

/// Stable settings value that is never bound by an ephemeral test launcher.
const int testEmbeddedDaemonPort = 49152;

/// Starts a real embedded daemon on an OS-assigned port.
///
/// The app-owned daemon binds whatever `AppSettings.embeddedDaemonPort` says,
/// but reserving and releasing a port before startup leaves a race. This typed
/// test adapter ignores the display setting and passes zero to the production
/// launcher, which keeps the socket allocation and readiness message inside
/// the daemon lifecycle.
///
/// The app-owned embedded-port contract keeps every real-daemon E2E here.
final class EphemeralEmbeddedDaemonLauncher implements EmbeddedDaemonLauncher {
  new(this.delegate);

  final EmbeddedDaemonLauncher delegate;
  final Completer<EmbeddedDaemonSession> _started =
      Completer<EmbeddedDaemonSession>();

  /// The real session, including the OS-assigned endpoint.
  Future<EmbeddedDaemonSession> get started => _started.future;

  @override
  Future<EmbeddedDaemonSession> start({
    required EmbeddedDaemonExposure exposure,
    required int port,
  }) async {
    final session = await delegate.start(exposure: exposure, port: 0);
    if (!_started.isCompleted) _started.complete(session);
    return session;
  }
}
