import 'package:app/desktop.dart';
import 'package:daemon/daemon.dart';

/// Starts one embedded daemon from a resolved configuration.
typedef EmbeddedDaemonStarter = Future<DaemonHandle> Function(
  DaemonConfig config,
);

/// Resolves the directories and listener the embedded daemon owns.
typedef DaemonConfigResolver = DaemonConfig Function();

/// Erases daemon state for one resolved configuration.
typedef DaemonDataResetter = Future<void> Function(DaemonConfig config);

/// Desktop daemon adapters that share one memoized configuration.
final class EmbeddedDaemonAdapters {
  /// Creates production adapters.
  factory({DaemonConfigResolver? resolveConfig}) {
    final resolver = resolveConfig ?? DaemonConfig.fromEnvironment;
    DaemonConfig? resolved;
    DaemonConfig memoizedResolver() => resolved ??= resolver();
    return EmbeddedDaemonAdapters._(
      launcher: IsolateEmbeddedDaemonLauncher(resolveConfig: memoizedResolver),
      dataEraser: IsolateEmbeddedDaemonDataEraser(
        resolveConfig: memoizedResolver,
      ),
    );
  }

  const new _({required this.launcher, required this.dataEraser});

  /// App-facing daemon launcher.
  final EmbeddedDaemonLauncher launcher;

  /// App-facing daemon data eraser.
  final EmbeddedDaemonDataEraser dataEraser;
}

/// Starts an embedded daemon isolate without connecting the GUI client.
final class IsolateEmbeddedDaemonLauncher implements EmbeddedDaemonLauncher {
  /// Creates the production embedded daemon launcher.
  const new({
    this.resolveConfig = DaemonConfig.fromEnvironment,
    this.startDaemon = _startEmbeddedDaemon,
  });

  /// Resolves the base configuration; tests substitute a temporary tree.
  final DaemonConfigResolver resolveConfig;

  /// Injected isolate starter used by deterministic tests.
  final EmbeddedDaemonStarter startDaemon;

  @override
  Future<EmbeddedDaemonSession> start({
    required EmbeddedDaemonExposure exposure,
    required int port,
  }) async {
    try {
      final baseConfig = resolveConfig();
      return _EmbeddedSession(
        await startDaemon(
          baseConfig.copyWith(host: exposure.bindHost, port: port),
        ),
      );
    } on EmbeddedDaemonStartupException catch (error) {
      throw HostConnectionFailure.network(
        error.message,
        reason: switch (error.reason) {
          EmbeddedDaemonStartupFailureReason.portInUse =>
            HostFailureReason.embeddedPortInUse,
          EmbeddedDaemonStartupFailureReason.alreadyRunning =>
            HostFailureReason.embeddedAlreadyRunning,
          EmbeddedDaemonStartupFailureReason.unknown => null,
        },
      );
    } on Exception catch (error) {
      throw HostConnectionFailure.network('$error');
    }
  }
}

/// Erases the app-owned daemon's stored data from disk.
final class IsolateEmbeddedDaemonDataEraser
    implements EmbeddedDaemonDataEraser {
  /// Creates the production embedded daemon data eraser.
  const new({
    this.resolveConfig = DaemonConfig.fromEnvironment,
    this.eraseData = _eraseDaemonData,
  });

  /// Resolves the directories to erase; tests substitute a temporary tree.
  final DaemonConfigResolver resolveConfig;

  /// Injected reset operation used by deterministic tests.
  final DaemonDataResetter eraseData;

  @override
  Future<void> eraseAll() async {
    final config = resolveConfig();
    try {
      await eraseData(config);
    } on DaemonDataResetException catch (error) {
      throw FactoryResetFailure(
        error.message,
        reason: switch (error.reason) {
          DaemonDataResetFailureReason.daemonRunning =>
            FactoryResetFailureReason.daemonStillRunning,
          DaemonDataResetFailureReason.filesystem =>
            FactoryResetFailureReason.filesystem,
        },
      );
    }
  }
}

Future<DaemonHandle> _startEmbeddedDaemon(DaemonConfig config) =>
    EmbeddedDaemonHandle.start(config);

Future<void> _eraseDaemonData(DaemonConfig config) => DaemonDataReset(
  configDirectory: config.configDirectory,
  homeDirectory: config.homeDirectory,
).eraseAll();

final class _EmbeddedSession implements EmbeddedDaemonSession {
  const new(this._handle);

  final DaemonHandle _handle;

  @override
  DaemonCredentials get credentials =>
      DaemonCredentials(bearerToken: _handle.bearerToken);

  @override
  HostEndpoint get endpoint =>
      HostEndpoint(websocketUri: _handle.boundEndpoint);

  @override
  String get serverId => _handle.serverId;

  @override
  Future<void> stop() => _handle.stop();
}
