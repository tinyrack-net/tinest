import 'dart:convert';

import 'package:client/client.dart';
import 'package:protocol/protocol.dart';

/// Narrow plugin-authoring port used by the standalone CLI.
///
/// Filesystem ownership stays in the daemon. The CLI can only request the
/// public scaffold, validation, and activation operations exposed by v5.
abstract interface class PluginCliBackend {
  /// Creates a package in the daemon's app-data plugin directory.
  Future<PluginDescriptorDto> init(String id, String name);

  /// Forks an installed validated plugin into a new app-data package.
  Future<PluginDescriptorDto> fork(String sourceId, String id, String name);

  /// Validates the current app-data source without activating it.
  Future<PluginDescriptorDto> validate(String id);

  /// Activates a valid revision within one Agent's stored grants.
  Future<PluginDescriptorDto> reload(String id, String agentId);

  /// Reads the exact SDK ABI and LuaLS sidecar state.
  Future<PluginAuthoringEnvironmentDto> getAuthoringEnvironment(String id);

  /// Synchronizes the exact SDK ABI and LuaLS sidecar.
  Future<PluginAuthoringEnvironmentDto> syncAuthoringEnvironment(String id);

  /// Stores one secret in an exact plugin and Agent namespace.
  Future<void> setSecret(
    String pluginId,
    String agentId,
    String name,
    String value,
  );

  /// Removes one exact plugin and Agent secret.
  Future<void> removeSecret(String pluginId, String agentId, String name);
}

/// Adapts only the daemon's [PluginsApi] to plugin-authoring commands.
final class PluginsApiPluginCliBackend implements PluginCliBackend {
  /// Creates a client adapter without exposing filesystem operations.
  const new(this._plugins);

  final PluginsApi _plugins;

  @override
  Future<PluginDescriptorDto> init(String id, String name) =>
      _plugins.scaffoldPlugin(id, name);

  @override
  Future<PluginDescriptorDto> fork(String sourceId, String id, String name) =>
      _plugins.forkPlugin(sourceId: sourceId, id: id, name: name);

  @override
  Future<PluginDescriptorDto> validate(String id) =>
      _plugins.validatePlugin(id);

  @override
  Future<PluginDescriptorDto> reload(String id, String agentId) =>
      _plugins.reloadPlugin(id, agentId);

  @override
  Future<PluginAuthoringEnvironmentDto> getAuthoringEnvironment(String id) =>
      _plugins.getPluginAuthoringEnvironment(id);

  @override
  Future<PluginAuthoringEnvironmentDto> syncAuthoringEnvironment(String id) =>
      _plugins.syncPluginAuthoringEnvironment(id);

  @override
  Future<void> setSecret(
    String pluginId,
    String agentId,
    String name,
    String value,
  ) => _plugins.setPluginSecret(
    agentId: agentId,
    pluginId: pluginId,
    name: name,
    value: value,
  );

  @override
  Future<void> removeSecret(String pluginId, String agentId, String name) =>
      _plugins.removePluginSecret(
        agentId: agentId,
        pluginId: pluginId,
        name: name,
      );
}

/// Scaffolds one user plugin under the daemon-owned app-data directory.
Future<int> pluginInit({
  required PluginCliBackend backend,
  required StringSink output,
  required String id,
  required String name,
}) async {
  final descriptor = await backend.init(id, name);
  output.writeln('Initialized ${descriptor.id} at ${descriptor.sourcePath}.');
  return 0;
}

/// Forks one installed validated revision into an app-data plugin package.
Future<int> pluginFork({
  required PluginCliBackend backend,
  required StringSink output,
  required String sourceId,
  required String id,
  required String name,
}) async {
  final descriptor = await backend.fork(sourceId, id, name);
  output.writeln(
    'Forked $sourceId as ${descriptor.id} at ${descriptor.sourcePath}.',
  );
  return 0;
}

/// Validates one plugin candidate without changing the active revision.
Future<int> pluginValidate({
  required PluginCliBackend backend,
  required StringSink output,
  required String id,
  bool json = false,
}) async {
  final descriptor = await backend.validate(id);
  if (json) {
    output.writeln(jsonEncode(descriptor.toJson()));
  } else {
    output.writeln(
      'Valid ${descriptor.id}@${descriptor.version} '
      '(${_revisionHash(descriptor)}).',
    );
  }
  return 0;
}

/// Synchronizes the exact content-addressed SDK and LuaLS workspace config.
Future<int> pluginSdkSync({
  required PluginCliBackend backend,
  required StringSink output,
  required String id,
}) async {
  final environment = await backend.syncAuthoringEnvironment(id);
  output
    ..writeln(
      'Synchronized ${environment.pluginId} with SDK '
      '${environment.sdkAbiHash}.',
    )
    ..writeln(environment.configurationPath);
  return 0;
}

/// Checks the daemon-owned authoring files and the user's LuaLS release.
Future<int> pluginDoctor({
  required PluginCliBackend backend,
  required PluginExternalProcessRunner runProcess,
  required StringSink output,
  required String id,
  bool json = false,
}) async {
  final environment = await backend.getAuthoringEnvironment(id);
  PluginExternalProcessResult? version;
  Object? processError;
  try {
    version = await runProcess('lua-language-server', const <String>[
      '--version',
    ]);
  } on Object catch (error) {
    processError = error;
  }
  final versionText = version?.stdout.trim() ?? '';
  final languageServerReady =
      version?.exitCode == 0 &&
      _containsExactVersion(versionText, environment.luaLanguageServerVersion);
  final healthy = environment.synchronized && languageServerReady;
  if (json) {
    output.writeln(
      jsonEncode(<String, Object?>{
        'pluginId': environment.pluginId,
        'sdkAbiHash': environment.sdkAbiHash,
        'synchronized': environment.synchronized,
        'luaLanguageServer': <String, Object?>{
          'requiredVersion': environment.luaLanguageServerVersion,
          'detectedVersion': versionText.isEmpty ? null : versionText,
          'ready': languageServerReady,
          if (processError != null) 'error': '$processError',
        },
        'diagnostics': environment.diagnostics
            .map((item) => item.toJson())
            .toList(growable: false),
      }),
    );
  } else {
    output
      ..writeln(
        environment.synchronized
            ? 'SDK ${environment.sdkAbiHash} is synchronized.'
            : 'SDK authoring files are not synchronized.',
      )
      ..writeln(
        languageServerReady
            ? 'LuaLS $versionText is ready.'
            : 'LuaLS ${environment.luaLanguageServerVersion} is required.',
      );
  }
  return healthy ? 0 : 1;
}

bool _containsExactVersion(String output, String requiredVersion) => RegExp(
  '(^|[^0-9A-Za-z.+-])${RegExp.escape(requiredVersion)}'
  r'(?=$|[^0-9A-Za-z.+-])',
).hasMatch(output);

/// Runs the user's LuaLS against a synchronized app-data plugin package.
Future<int> pluginTypecheck({
  required PluginCliBackend backend,
  required PluginExternalProcessRunner runProcess,
  required StringSink output,
  required String id,
  bool json = false,
}) async {
  final environment = await backend.getAuthoringEnvironment(id);
  if (!environment.synchronized) {
    throw FormatException(
      'Plugin authoring files are not synchronized. '
      'Run `tinest-cli plugin sdk-sync $id`.',
    );
  }
  final result = await runProcess('lua-language-server', <String>[
    '--check=${environment.pluginPath}',
    '--checklevel=Information',
    '--check_format=pretty',
  ]);
  if (json) {
    final diagnostics = _luaLanguageServerDiagnostics(result.stdout);
    output.writeln(
      jsonEncode(<String, Object?>{
        'pluginId': id,
        'exitCode': result.exitCode,
        'diagnostics': diagnostics
            .map((diagnostic) => diagnostic.toJson())
            .toList(growable: false),
        if (result.stderr.trim().isNotEmpty) 'stderr': result.stderr,
      }),
    );
  } else {
    output
      ..write(result.stdout)
      ..write(result.stderr);
  }
  return result.exitCode;
}

List<PluginDiagnosticDto> _luaLanguageServerDiagnostics(String output) {
  final diagnostics = <PluginDiagnosticDto>[];
  final ansi = RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]');
  final diagnostic = RegExp(
    r'^(.+):(\d+):(\d+) \[(Error|Warning|Information|Hint)\] '
    r'(.+?) \(([^()]+)\)$',
  );
  for (final rawLine in const LineSplitter().convert(output)) {
    final match = diagnostic.firstMatch(rawLine.replaceAll(ansi, ''));
    if (match == null) continue;
    diagnostics.add(
      PluginDiagnosticDto(
        code: match.group(6)!,
        message: match.group(5)!,
        severity: switch (match.group(4)) {
          'Error' => PluginDiagnosticSeverity.error,
          'Warning' => PluginDiagnosticSeverity.warning,
          'Information' || 'Hint' => PluginDiagnosticSeverity.info,
          _ => throw StateError('Unexpected LuaLS diagnostic severity.'),
        },
        path: match.group(1),
        line: int.parse(match.group(2)!),
        column: int.parse(match.group(3)!),
      ),
    );
  }
  return diagnostics;
}

/// Result of one local editor-tool process without exposing `dart:io` types.
final class PluginExternalProcessResult {
  /// Creates an immutable process result.
  const new({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  /// Native process exit code.
  final int exitCode;

  /// Captured UTF-8 standard output.
  final String stdout;

  /// Captured UTF-8 standard error.
  final String stderr;
}

/// Injectable boundary for the optional user-installed LuaLS executable.
typedef PluginExternalProcessRunner =
    Future<PluginExternalProcessResult> Function(
      String executable,
      List<String> arguments,
    );

/// Reloads one plugin using the grants stored for [agentId].
Future<int> pluginReload({
  required PluginCliBackend backend,
  required StringSink output,
  required String id,
  required String agentId,
}) async {
  final descriptor = await backend.reload(id, agentId);
  output.writeln(
    'Reloaded ${descriptor.id} for $agentId '
    '(${_revisionHash(descriptor)}).',
  );
  return 0;
}

/// Stores a prompted secret without writing its value to command output.
Future<int> pluginSecretSet({
  required PluginCliBackend backend,
  required StringSink output,
  required String pluginId,
  required String agentId,
  required String name,
  required String value,
}) async {
  if (value.isEmpty) throw const FormatException('Secret must not be empty.');
  await backend.setSecret(pluginId, agentId, name, value);
  output.writeln('Stored $name for $pluginId in Agent $agentId.');
  return 0;
}

/// Removes one secret without revealing whether it previously existed.
Future<int> pluginSecretRemove({
  required PluginCliBackend backend,
  required StringSink output,
  required String pluginId,
  required String agentId,
  required String name,
}) async {
  await backend.removeSecret(pluginId, agentId, name);
  output.writeln('Removed $name for $pluginId in Agent $agentId.');
  return 0;
}

String _revisionHash(PluginDescriptorDto descriptor) {
  final revision = descriptor.revision;
  if (revision == null) {
    throw StateError('Plugin ${descriptor.id} has no validated revision.');
  }
  return revision.contentHash;
}
