import 'package:cli/src/cli/context.dart';
import 'package:client/client.dart';
import 'package:client/local_daemon.dart';
import 'package:cliweave/cliweave.dart';

/// The daemon-addressing flags every client command accepts.
///
/// They repeat on each command rather than sitting before the subcommand,
/// which is what lets the scanner type them and propose completions for them.
/// The `TINYRACK_TINEST_*` environment variables remain the other way to set
/// them.
final class DaemonConnectionFlags {
  /// Creates one resolved flag set.
  const new({required this.home, required this.listen, required this.token});

  /// Configuration directory whose `v5/secrets.json` holds credentials.
  final String? home;

  /// Daemon address as `host:port`.
  final String? listen;

  /// Daemon bearer token.
  final String? token;
}

/// Builds the `--home`, `--listen`, and `--token` flag set.
FlagSet<DaemonConnectionFlags, TinestCliContext> daemonConnectionFlagSet() {
  return FlagSet.one(
        ParsedFlag.optional<String, TinestCliContext>(
          name: 'home',
          brief: 'Configuration directory holding v5/secrets.json',
          parse: stringParser,
          placeholder: 'directory',
        ),
      )
      .and(
        ParsedFlag.optional<String, TinestCliContext>(
          name: 'listen',
          brief: 'Daemon address as host:port',
          parse: stringParser,
          placeholder: 'host:port',
        ),
      )
      .and(
        ParsedFlag.optional<String, TinestCliContext>(
          name: 'token',
          brief: 'Daemon bearer token',
          parse: stringParser,
          placeholder: 'token',
        ),
      )
      .map(
        (values) => DaemonConnectionFlags(
          home: values.$1.$1,
          listen: values.$1.$2,
          token: values.$2,
        ),
      );
}

/// Raised when the CLI cannot address a daemon.
///
/// A missing token is an operator mistake rather than an unexpected failure,
/// so it is reported as a message and mapped to a connection exit code.
final class DaemonConnectionException implements Exception {
  /// Creates a connection failure carrying [message].
  const new(this.message);

  /// Human-readable explanation.
  final String message;

  @override
  String toString() => message;
}

/// Connects to the daemon addressed by [flags], the environment, or defaults.
///
/// The caller owns the returned client and must close it.
Future<TinestClient> connectDaemon(
  TinestCliContext context,
  DaemonConnectionFlags flags, {
  String clientId = 'tinest-cli',
}) async {
  final environment = context.environment;
  final configDirectory = flags.home ?? context.directories.configDirectory;
  final (host, port) = parseLocalDaemonListen(
    flags.listen ??
        environment['TINYRACK_TINEST_LISTEN'] ??
        defaultLocalDaemonListen,
  );
  final token =
      flags.token ??
      environment['TINYRACK_TINEST_TOKEN'] ??
      await readLocalDaemonBearerToken(configDirectory);
  if (token == null) {
    throw DaemonConnectionException(
      'No daemon connection token found in $configDirectory. Start the daemon '
      'first, or pass --token.',
    );
  }
  return await context.connectClient(
    // A daemon bound to every interface is still reached over loopback.
    host: host == '0.0.0.0' ? '127.0.0.1' : host,
    port: port,
    bearerToken: token,
    clientId: clientId,
  );
}

/// Runs [body] against a connected daemon and always closes the client.
Future<void> withDaemon(
  TinestCliContext context,
  DaemonConnectionFlags flags,
  Future<int> Function(TinestClient client) body,
) async {
  final client = await connectDaemon(context, flags);
  try {
    context.process.exitCode = await body(client);
  } finally {
    await client.close();
  }
}
