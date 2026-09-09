import 'dart:io' show FileSystemException;

import 'package:file/file.dart' as file_api;
import 'package:file/local.dart';
import 'package:platform/platform.dart';
import 'package:platform/testing.dart';

/// One entry in a host-owned skill catalog.
final class SkillSummary {
  /// Creates a summary.
  const new({required this.name, required this.description});

  /// Stable catalog name.
  final String name;

  /// Concise author-provided description.
  final String description;
}

/// One file bundled beside a skill document.
final class SkillResourceRef {
  /// Creates a resource reference.
  const new({required this.path, required this.sizeBytes});

  /// Path relative to the skill directory.
  final String path;

  /// Size on disk.
  final int sizeBytes;
}

/// Full host-owned skill content.
final class SkillContent {
  /// Creates skill content.
  const new({
    required this.name,
    required this.description,
    required this.instructions,
    this.directory,
    this.resources = const <SkillResourceRef>[],
  });

  /// Stable catalog name.
  final String name;

  /// Concise description.
  final String description;

  /// Markdown instructions.
  final String instructions;

  /// Absolute backing directory, when any.
  final String? directory;

  /// Bundled resources.
  final List<SkillResourceRef> resources;
}

/// An unknown or unavailable skill was requested.
final class SkillLookupException implements Exception {
  /// Creates a lookup error.
  const new(this.message);

  /// Safe diagnostic text.
  final String message;

  @override
  String toString() => 'SkillLookupException: $message';
}

/// Host-owned view of the skills available to one workspace.
abstract interface class SkillCatalog {
  /// Lists available skills.
  List<SkillSummary> summaries();

  /// Reads one skill document.
  Future<SkillContent> read(String name);

  /// Reads one bundled resource.
  Future<String> readResource(String name, String relativePath);
}

/// Confines resource access to one skill directory.
final class SkillPathGuard {
  /// Creates a guard rooted at [skillRoot].
  new(
    String skillRoot, {
    file_api.FileSystem fileSystem = const LocalFileSystem(),
    this._platform = const Platform(),
  }) : _fileSystem = fileSystem,
       _skillRoot = fileSystem.directory(skillRoot).resolveSymbolicLinksSync();

  final file_api.FileSystem _fileSystem;
  final Platform _platform;
  final String _skillRoot;

  /// Resolves an existing relative resource within the skill root.
  String resolveExisting(String candidate) {
    final path = _fileSystem.path;
    if (path.isAbsolute(candidate)) {
      throw FileSystemException('Skill paths must be relative.', candidate);
    }
    final resolved = _fileSystem
        .file(path.join(_skillRoot, candidate))
        .resolveSymbolicLinksSync();
    final root = _platform.isWindows ? _skillRoot.toLowerCase() : _skillRoot;
    final target = _platform.isWindows ? resolved.toLowerCase() : resolved;
    if (!path.isWithin(root, target)) {
      throw FileSystemException('Path escapes the skill.', resolved);
    }
    return resolved;
  }
}
