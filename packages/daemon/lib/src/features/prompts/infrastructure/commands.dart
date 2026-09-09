import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:protocol/protocol.dart';
import 'package:yaml/yaml.dart';

/// Scopes a command request to the global sources plus one workspace.
final class CommandScope {
  /// Creates a scope; both fields are null for the global sources alone.
  const new({this.workspaceId, this.projectRoot});

  /// The global sources with no project overlay.
  static const CommandScope global = CommandScope();

  /// Workspace owning the project commands.
  final String? workspaceId;

  /// Absolute workspace root containing `.agents/commands`.
  final String? projectRoot;
}

/// One command document read from a filesystem boundary.
final class CommandDocument {
  /// Creates an immutable document snapshot.
  const new({required this.id, required this.sourcePath, required this.source});

  /// File-name derived stable command ID.
  final String id;

  /// Absolute path of the Markdown document.
  final String sourcePath;

  /// Complete Markdown source.
  final String source;
}

/// Typed filesystem and watcher boundary for one commands root.
abstract interface class CommandFiles {
  /// Where documents from this root are loaded from.
  AgentCommandSource get source;

  /// Emits after the root changes on disk.
  Stream<void> get changes;

  /// Prepares the root and starts watching it.
  Future<void> initialize();

  /// Reads every command document in the root.
  Future<List<CommandDocument>> read();

  /// Releases the watcher.
  Future<void> close();
}

/// Filesystem adapter rooted at one `commands` directory.
///
/// Each command is a single `<name>.md` document, flatter than a skill's
/// `<id>/SKILL.md` because a command carries one prompt and no bundled files.
final class NativeCommandFiles implements CommandFiles {
  /// Creates an adapter rooted at one commands directory.
  new(String root, {required this.source}) : _directory = Directory(root);

  static const String _extension = '.md';

  @override
  final AgentCommandSource source;

  final Directory _directory;
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );
  StreamSubscription<FileSystemEvent>? _watchSubscription;
  bool _initialized = false;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    if (_directory.existsSync()) _watch();
    _initialized = true;
  }

  void _watch() {
    _watchSubscription = _directory
        .watch(recursive: true)
        .listen((_) => _changes.add(null), onError: (Object _) {});
  }

  @override
  Future<List<CommandDocument>> read() async {
    if (!_directory.existsSync()) return const <CommandDocument>[];
    // A shared root may appear after the daemon started, so pick up the
    // watcher on the first read that finds the directory.
    if (_initialized && _watchSubscription == null) _watch();

    final documents = <CommandDocument>[];
    await for (final entity in _directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name.startsWith('.') || !name.endsWith(_extension)) continue;
      try {
        documents.add(
          CommandDocument(
            id: name.substring(0, name.length - _extension.length),
            sourcePath: entity.path,
            source: await entity.readAsString(),
          ),
        );
      } on FileSystemException {
        // Atomic editors may replace an entry after directory enumeration.
        if (entity.existsSync()) rethrow;
      }
    }
    return documents;
  }

  @override
  Future<void> close() async {
    await _watchSubscription?.cancel();
    _watchSubscription = null;
    await _changes.close();
  }
}

/// Builds the project-scoped command source for one workspace root.
typedef ProjectCommandFilesBuilder = CommandFiles Function(String projectRoot);

/// Application service exposing agent commands to RPC callers.
///
/// The catalog is read-only in this version: commands are authored on disk and
/// the daemon only resolves precedence between the roots that provide them.
final class CommandService {
  /// Creates a command application service.
  new({required List<CommandFiles> globalSources, this.projectFiles})
    : _globalSources = List<CommandFiles>.unmodifiable(globalSources) {
    for (final source in _globalSources) {
      _subscriptions.add(source.changes.listen((_) => _changes.add(null)));
    }
  }

  /// Builds the project-scoped source; null disables project commands.
  final ProjectCommandFilesBuilder? projectFiles;

  final List<CommandFiles> _globalSources;
  final List<StreamSubscription<void>> _subscriptions =
      <StreamSubscription<void>>[];
  final Map<String, CommandFiles> _projectSources = <String, CommandFiles>{};
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );

  /// Emits after any command root changes.
  Stream<void> get changes => _changes.stream;

  /// Prepares every global root.
  Future<void> initialize() async {
    for (final source in _globalSources) {
      await source.initialize();
    }
  }

  /// Returns every command visible in [scope], highest precedence first.
  ///
  /// Later sources shadow earlier ones on the resolved command name, so a
  /// project may override a command the user defined in their home directory.
  Future<List<AgentCommandDto>> list({
    CommandScope scope = CommandScope.global,
  }) async {
    final resolved = <String, AgentCommandDto>{};
    for (final source in await _sourcesFor(scope)) {
      for (final document in await source.read()) {
        final command = _decode(document, source.source);
        if (command != null) resolved[command.name] = command;
      }
    }
    final commands = resolved.values.toList()
      ..sort((left, right) => left.name.compareTo(right.name));
    return List<AgentCommandDto>.unmodifiable(commands);
  }

  Future<List<CommandFiles>> _sourcesFor(CommandScope scope) async {
    final projectRoot = scope.projectRoot;
    final builder = projectFiles;
    if (projectRoot == null || builder == null) return _globalSources;

    var project = _projectSources[projectRoot];
    if (project == null) {
      project = builder(projectRoot);
      _projectSources[projectRoot] = project;
      _subscriptions.add(project.changes.listen((_) => _changes.add(null)));
      await project.initialize();
    }
    return <CommandFiles>[..._globalSources, project];
  }

  /// Returns null when the document cannot be understood as a command.
  AgentCommandDto? _decode(CommandDocument document, AgentCommandSource from) {
    final split = _CommandMarkdown.split(document.source);
    if (split == null) {
      // No front matter at all: the whole file is the prompt.
      return AgentCommandDto(
        id: document.id,
        name: document.id,
        description: '',
        source: from,
        sourcePath: document.sourcePath,
        body: document.source.trim(),
      );
    }

    final YamlNode decoded;
    try {
      decoded = loadYamlNode(split.frontMatter);
    } on YamlException {
      return null;
    }
    if (decoded is! YamlMap) return null;

    final name = decoded['name'];
    final description = decoded['description'];
    final argumentHint = decoded['argument-hint'];
    final resolvedName = name is String && name.trim().isNotEmpty
        ? name.trim()
        : document.id;

    return AgentCommandDto(
      id: document.id,
      name: resolvedName,
      description: description is String ? description.trim() : '',
      source: from,
      sourcePath: document.sourcePath,
      body: split.body.trim(),
      argumentHint: argumentHint is String && argumentHint.trim().isNotEmpty
          ? argumentHint.trim()
          : null,
    );
  }

  /// Releases every source this service owns.
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    for (final source in <CommandFiles>[
      ..._globalSources,
      ..._projectSources.values,
    ]) {
      await source.close();
    }
    _projectSources.clear();
    await _changes.close();
  }
}

final class _CommandMarkdown {
  const new({required this.frontMatter, required this.body});

  /// Returns null when the document opens with no front matter fence.
  static _CommandMarkdown? split(String source) {
    final lines = source.replaceAll('\r\n', '\n').split('\n');
    var start = 0;
    while (start < lines.length && lines[start].trim().isEmpty) {
      start += 1;
    }
    if (start == lines.length || lines[start].trim() != '---') return null;
    var end = start + 1;
    while (end < lines.length && lines[end].trim() != '---') {
      end += 1;
    }
    if (end == lines.length) return null;
    return _CommandMarkdown(
      frontMatter: lines.sublist(start + 1, end).join('\n'),
      body: lines.sublist(end + 1).join('\n'),
    );
  }

  final String frontMatter;
  final String body;
}
