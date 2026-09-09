import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:protocol/protocol.dart';

/// Filename holding project-scoped configuration in a workspace root.
const String projectSettingsFileName = '.tinest/config.json';

String _projectSettingsPath(String rootPath) =>
    p.join(rootPath, '.tinest', 'config.json');

/// Schema shared by project worktree and MCP configuration.
const int projectConfigSchemaVersion = 5;

/// Typed source-of-truth boundary for project-scoped configuration.
abstract interface class ProjectSettingsStore {
  /// Returns the settings file path for one workspace root.
  String sourcePath(String rootPath);

  /// Reads settings, treating a missing file as an empty configuration.
  Future<ProjectSettingsDto> load(String rootPath);

  /// Replaces the worktree hook section and preserves every other key.
  Future<void> save(String rootPath, ProjectSettingsDto settings);
}

/// Reads and writes `<workspace root>/.tinest/config.json`.
final class FileProjectSettingsStore implements ProjectSettingsStore {
  /// Creates the production project settings adapter.
  const new();

  @override
  String sourcePath(String rootPath) => _projectSettingsPath(rootPath);

  @override
  Future<ProjectSettingsDto> load(String rootPath) async {
    final document = await _read(rootPath);
    final worktree = document['worktree'];
    if (worktree == null) return const ProjectSettingsDto();
    if (worktree is! Map<String, dynamic>) {
      throw FormatException(
        'invalid_project_settings: "worktree" must be an object in '
        '${sourcePath(rootPath)}.',
      );
    }
    return ProjectSettingsDto(
      setup: _commands(worktree['setup'], 'setup', rootPath),
      teardown: _commands(worktree['teardown'], 'teardown', rootPath),
      shell: _shell(worktree['shell'], rootPath),
    );
  }

  @override
  Future<void> save(String rootPath, ProjectSettingsDto settings) async {
    final file = File(sourcePath(rootPath));
    if (!file.existsSync() &&
        settings.setup.isEmpty &&
        settings.teardown.isEmpty &&
        settings.shell == null) {
      return;
    }
    final document = await _read(rootPath);
    document['schemaVersion'] = projectConfigSchemaVersion;
    final worktree =
        <String, dynamic>{
          if (document['worktree'] case final Map<String, dynamic> existing)
            ...existing,
        }..removeWhere(
          (key, _) => key == 'setup' || key == 'teardown' || key == 'shell',
        );
    if (settings.setup.isNotEmpty) worktree['setup'] = settings.setup;
    if (settings.teardown.isNotEmpty) worktree['teardown'] = settings.teardown;
    if (settings.shell case final shell?) worktree['shell'] = shell.toJson();
    if (worktree.isEmpty) {
      document.remove('worktree');
    } else {
      document['worktree'] = worktree;
    }
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      '${encoder.convert(document)}\n',
      flush: true,
    );
    // `rename` replaces the destination on its own; unlinking it first throws
    // while anything else holds the file and loses the settings outright if
    // the process stops between the two calls.
    await temporary.rename(file.path);
  }

  Future<Map<String, dynamic>> _read(String rootPath) async {
    final file = File(sourcePath(rootPath));
    if (!file.existsSync()) return <String, dynamic>{};
    final source = await file.readAsString();
    if (source.trim().isEmpty) return <String, dynamic>{};
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw FormatException(
        'invalid_project_settings: ${file.path} is not valid JSON. '
        '${error.message}',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'invalid_project_settings: ${file.path} must contain a JSON object.',
      );
    }
    if (decoded['schemaVersion'] != projectConfigSchemaVersion) {
      throw FormatException(
        'invalid_project_settings: ${file.path} must declare '
        '"schemaVersion": $projectConfigSchemaVersion.',
      );
    }
    return decoded;
  }

  static List<String> _commands(Object? value, String key, String rootPath) {
    if (value == null) return const <String>[];
    if (value is! List) {
      throw FormatException(
        'invalid_project_settings: "worktree.$key" must be an array of '
        'strings in ${_projectSettingsPath(rootPath)}.',
      );
    }
    final commands = <String>[];
    for (final entry in value) {
      if (entry is! String) {
        throw FormatException(
          'invalid_project_settings: "worktree.$key" must contain only '
          'strings in ${_projectSettingsPath(rootPath)}.',
        );
      }
      if (entry.trim().isNotEmpty) commands.add(entry.trim());
    }
    return commands;
  }

  static ShellSpecDto? _shell(Object? value, String rootPath) {
    if (value == null) return null;
    if (value is! Map<String, dynamic>) {
      throw FormatException(
        'invalid_project_settings: "worktree.shell" must be an object in '
        '${_projectSettingsPath(rootPath)}.',
      );
    }
    final shell = ShellSpecDto.fromJson(value);
    if (shell.executable.trim().isEmpty) {
      throw FormatException(
        'invalid_project_settings: "worktree.shell.executable" must not be '
        'empty in ${_projectSettingsPath(rootPath)}.',
      );
    }
    return shell;
  }
}
