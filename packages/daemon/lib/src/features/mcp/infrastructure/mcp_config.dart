import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:protocol/protocol.dart';

/// Filename holding user-scoped MCP configuration in the daemon config
/// directory.
const String userMcpConfigFileName = 'config.json';

/// Filename holding project-scoped MCP configuration in a worktree root.
const String projectMcpConfigFileName = '.tinest/config.json';

/// The only document version this daemon reads.
const int mcpConfigVersion = 5;

/// Longest accepted MCP server id.
const int maxMcpServerIdLength = 40;

/// Server ids become part of `mcp__<server>__<tool>`, so `__` must be
/// impossible inside one.
final RegExp _serverIdPattern = RegExp(r'^[a-z0-9][a-z0-9_-]*$');

/// One parsed MCP configuration file.
class McpConfigDocument {
  /// Creates a [McpConfigDocument].
  const new({
    required this.scope,
    required this.sourcePath,
    required this.servers,
  });

  /// Which file this document came from.
  final McpConfigScope scope;

  /// Where the file lives, for display and for opening it.
  final String sourcePath;

  /// The declared servers, in file order.
  final List<McpServerConfigDto> servers;
}

/// Typed source-of-truth boundary for MCP server configuration.
abstract interface class McpConfigStore {
  /// Returns the configuration path for [scope].
  String sourcePath(McpConfigScope scope, {String? rootPath});

  /// Reads one scope, treating a missing file as an empty document.
  Future<McpConfigDocument> load(McpConfigScope scope, {String? rootPath});

  /// Replaces the user-scoped document.
  Future<void> save(McpConfigDocument document);

  /// Fires whenever the file backing [scope] changes on disk.
  Stream<void> watch(McpConfigScope scope, {String? rootPath});
}

/// Reads v5 config documents from the daemon and project config roots.
///
/// Both files share one schema, so parsing, validation, and the read-only
/// project rules are a single code path.
final class FileMcpConfigStore implements McpConfigStore {
  /// Creates a store rooted at the daemon [configDirectory].
  const new(this.configDirectory);

  /// Where the user-scoped document lives.
  final String configDirectory;

  @override
  String sourcePath(McpConfigScope scope, {String? rootPath}) {
    switch (scope) {
      case McpConfigScope.user:
        return p.join(configDirectory, userMcpConfigFileName);
      case McpConfigScope.project:
        if (rootPath == null) {
          throw ArgumentError.notNull('rootPath');
        }
        return p.join(rootPath, '.tinest', 'config.json');
    }
  }

  @override
  Future<McpConfigDocument> load(
    McpConfigScope scope, {
    String? rootPath,
  }) async {
    final path = sourcePath(scope, rootPath: rootPath);
    final file = File(path);
    if (!file.existsSync()) {
      return McpConfigDocument(
        scope: scope,
        sourcePath: path,
        servers: const <McpServerConfigDto>[],
      );
    }
    return parseMcpConfig(
      await file.readAsString(),
      scope: scope,
      sourcePath: path,
    );
  }

  @override
  Future<void> save(McpConfigDocument document) async {
    if (document.scope == McpConfigScope.project) {
      throw const FormatException(
        'mcp_project_scope_readonly: project .tinest/config.json belongs to the '
        'repository, so the daemon never rewrites it.',
      );
    }
    final path = sourcePath(McpConfigScope.user);
    await _ensureDirectory();
    final encoded = const JsonEncoder.withIndent('  ')
        .convert(<String, dynamic>{
          'schemaVersion': mcpConfigVersion,
          'mcp': <String, dynamic>{
            'servers': <String, dynamic>{
              for (final server in document.servers)
                server.id: _serverToJson(server),
            },
          },
        });
    final temporary = File('$path.tmp');
    await temporary.writeAsString('$encoded\n', flush: true);
    await _protect(temporary.path);
    // `rename` replaces the destination on its own; unlinking it first throws
    // while anything else holds the file and loses the configuration outright
    // if the process stops between the two calls.
    await temporary.rename(path);
    await _protect(path);
  }

  @override
  Stream<void> watch(McpConfigScope scope, {String? rootPath}) {
    final path = sourcePath(scope, rootPath: rootPath);
    final directory = Directory(p.dirname(path));
    if (!directory.existsSync()) return const Stream<void>.empty();
    // Watching the directory rather than the file survives the atomic
    // rename an editor or a `git checkout` performs.
    return directory
        .watch()
        .where((event) => p.equals(event.path, path))
        .map((_) {});
  }

  Future<void> _ensureDirectory() async {
    final directory = Directory(configDirectory);
    await directory.create(recursive: true);
    if (!Platform.isWindows) {
      await Process.run('chmod', <String>['700', directory.path]);
    }
  }

  Future<void> _protect(String path) async {
    if (Platform.isWindows) return;
    await Process.run('chmod', <String>['600', path]);
  }

  static Map<String, dynamic> _serverToJson(McpServerConfigDto server) =>
      <String, dynamic>{
        'enabled': server.enabled,
        'transport': server.transport.name,
        if (server.transport == McpTransportKind.stdio) ...<String, dynamic>{
          'command': server.command,
          if (server.args.isNotEmpty) 'args': server.args,
          if (server.env.isNotEmpty) 'env': server.env,
          'cwd': ?server.cwd,
        } else ...<String, dynamic>{
          'url': server.url,
          if (server.headers.isNotEmpty) 'headers': server.headers,
        },
      };
}

/// Parses one MCP configuration document.
///
/// [scope] decides whether literal secrets are tolerated: a project file is
/// committed to the repository, so a literal is almost certainly a leaked
/// token rather than an intentional value.
McpConfigDocument parseMcpConfig(
  String contents, {
  required McpConfigScope scope,
  required String sourcePath,
}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(contents);
  } on FormatException catch (error) {
    throw FormatException(
      'invalid_mcp_config: $sourcePath is not valid JSON (${error.message}).',
    );
  }
  if (decoded is! Map<String, dynamic>) {
    throw FormatException('invalid_mcp_config: $sourcePath must be an object.');
  }
  if (decoded['schemaVersion'] != mcpConfigVersion) {
    throw FormatException(
      'invalid_mcp_config: $sourcePath must declare "schemaVersion": '
      '$mcpConfigVersion. Remove the file to reset it.',
    );
  }
  final mcp = decoded['mcp'];
  if (mcp != null && mcp is! Map<String, dynamic>) {
    throw FormatException(
      'invalid_mcp_config: $sourcePath "mcp" must be an object.',
    );
  }
  final rawServers = (mcp as Map<String, dynamic>?)?['servers'];
  if (rawServers == null) {
    return McpConfigDocument(
      scope: scope,
      sourcePath: sourcePath,
      servers: const <McpServerConfigDto>[],
    );
  }
  if (rawServers is! Map<String, dynamic>) {
    throw FormatException(
      'invalid_mcp_config: $sourcePath "servers" must be an object.',
    );
  }
  final servers = <McpServerConfigDto>[
    for (final entry in rawServers.entries)
      _serverFromJson(
        entry.key,
        entry.value,
        scope: scope,
        sourcePath: sourcePath,
      ),
  ];
  return McpConfigDocument(
    scope: scope,
    sourcePath: sourcePath,
    servers: List<McpServerConfigDto>.unmodifiable(servers),
  );
}

McpServerConfigDto _serverFromJson(
  String id,
  Object? value, {
  required McpConfigScope scope,
  required String sourcePath,
}) {
  Never reject(String reason) => throw FormatException(
    'invalid_mcp_config: $sourcePath server "$id" $reason',
  );

  if (!_serverIdPattern.hasMatch(id) ||
      id.contains('__') ||
      id.length > maxMcpServerIdLength) {
    reject(
      'has an unusable server id. Use lower-case letters, digits, "-", and '
      'single "_", at most $maxMcpServerIdLength characters.',
    );
  }
  if (value is! Map<String, dynamic>) reject('must be an object.');

  const stdioKeys = <String>{
    'enabled',
    'transport',
    'command',
    'args',
    'env',
    'cwd',
  };
  const httpKeys = <String>{'enabled', 'transport', 'url', 'headers'};

  final transport = switch (value['transport']) {
    'stdio' => McpTransportKind.stdio,
    'http' => McpTransportKind.http,
    _ => reject('needs a "transport" of "stdio" or "http".'),
  };
  final allowed = transport == McpTransportKind.stdio ? stdioKeys : httpKeys;
  for (final key in value.keys) {
    if (!allowed.contains(key)) {
      reject('has an unknown key "$key" for a ${transport.name} server.');
    }
  }

  final enabled = value['enabled'] ?? true;
  if (enabled is! bool) reject('must declare "enabled" as a boolean.');

  if (transport == McpTransportKind.stdio) {
    final command = value['command'];
    if (command is! String || command.isEmpty) {
      reject('needs a non-empty "command".');
    }
    final cwd = value['cwd'];
    if (cwd != null && (cwd is! String || !p.isAbsolute(cwd))) {
      reject('must declare "cwd" as an absolute path.');
    }
    return McpServerConfigDto(
      id: id,
      transport: transport,
      enabled: enabled,
      command: command,
      args: _stringList(value['args'], 'args', reject),
      env: _stringMap(value['env'], 'env', reject, scope: scope),
      cwd: cwd as String?,
    );
  }

  final url = value['url'];
  if (url is! String) reject('needs a "url".');
  final parsed = Uri.tryParse(url);
  if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
    reject('needs a "url" that is an absolute HTTP address.');
  }
  final loopback = parsed.host == 'localhost' || parsed.host == '127.0.0.1';
  if (parsed.scheme != 'https' && !(parsed.scheme == 'http' && loopback)) {
    reject(
      'needs an https "url". Plain http would leak its headers, and is '
      'accepted only for localhost.',
    );
  }
  return McpServerConfigDto(
    id: id,
    transport: transport,
    enabled: enabled,
    url: url,
    headers: _stringMap(value['headers'], 'headers', reject, scope: scope),
  );
}

List<String> _stringList(
  Object? value,
  String field,
  Never Function(String reason) reject,
) {
  if (value == null) return const <String>[];
  if (value is! List || value.any((entry) => entry is! String)) {
    reject('must declare "$field" as a list of strings.');
  }
  return List<String>.unmodifiable(value.cast<String>());
}

Map<String, String> _stringMap(
  Object? value,
  String field,
  Never Function(String reason) reject, {
  required McpConfigScope scope,
}) {
  if (value == null) return const <String, String>{};
  if (value is! Map<String, dynamic> ||
      value.values.any((entry) => entry is! String)) {
    reject('must declare "$field" as a map of strings.');
  }
  final entries = value.cast<String, String>();
  if (scope == McpConfigScope.project) {
    for (final entry in entries.entries) {
      if (_namesASecret(entry.key) && !_carriesAReference(entry.value)) {
        reject(
          'declares "$field.${entry.key}" as a literal secret. A committed '
          r'.tinest/config.json may only reference ${env:NAME} or ${secret:key}.',
        );
      }
    }
  }
  return Map<String, String>.unmodifiable(entries);
}

/// Whether [name] is the kind of key that carries a credential.
///
/// Matching on the key rather than guessing at the value's entropy keeps the
/// rule predictable: a contributor can tell from the key alone whether a
/// literal will be refused.
bool _namesASecret(String name) {
  final normalized = name.toLowerCase();
  return const <String>[
    'auth',
    'credential',
    'key',
    'passphrase',
    'password',
    'secret',
    'session',
    'token',
  ].any(normalized.contains);
}

bool _carriesAReference(String value) =>
    RegExp(r'\$\{(env|secret):[^}]*\}').hasMatch(value);

/// Expands `${env:NAME}` and `${secret:key}` references inside [value].
///
/// `$$` is a literal `$`. Any other `$` is literal too, so a value such as
/// `costs $5` needs no escaping.
String resolveMcpSecrets(
  String value, {
  required Map<String, String> environment,
  required Map<String, String> secrets,
}) {
  final buffer = StringBuffer();
  var index = 0;
  while (index < value.length) {
    final char = value[index];
    if (char != r'$') {
      buffer.write(char);
      index += 1;
      continue;
    }
    if (index + 1 < value.length && value[index + 1] == r'$') {
      buffer.write(r'$');
      index += 2;
      continue;
    }
    if (index + 1 >= value.length || value[index + 1] != '{') {
      buffer.write(char);
      index += 1;
      continue;
    }
    final end = value.indexOf('}', index + 2);
    if (end < 0) {
      throw FormatException(
        'invalid_mcp_config: "$value" has an unterminated reference.',
      );
    }
    final reference = value.substring(index + 2, end);
    final separator = reference.indexOf(':');
    final kind = separator < 0 ? reference : reference.substring(0, separator);
    final key = separator < 0 ? '' : reference.substring(separator + 1);
    switch (kind) {
      case 'env':
        final resolved = environment[key];
        if (resolved == null) {
          throw FormatException(
            'mcp_missing_env: the environment variable "$key" is not set.',
          );
        }
        buffer.write(resolved);
      case 'secret':
        final resolved = secrets[key];
        if (resolved == null) {
          throw FormatException(
            'mcp_missing_secret: no stored secret named "$key".',
          );
        }
        buffer.write(resolved);
      default:
        throw FormatException(
          'invalid_mcp_config: "$reference" is not an env or secret reference.',
        );
    }
    index = end + 1;
  }
  return buffer.toString();
}
