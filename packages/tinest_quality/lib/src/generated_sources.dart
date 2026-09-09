/// The generated files whose checked-in contents must match their generators.
abstract final class GeneratedSources {
  /// Whether [value] identifies a checked-in generated source.
  static bool includesPath(String value) {
    final path = value.replaceAll(r'\', '/').toLowerCase();
    return path.endsWith('.g.dart') ||
        isFreezedOutput(path) ||
        path.endsWith('/packages/desktop_app/pubspec.yaml') ||
        path == 'packages/desktop_app/pubspec.yaml' ||
        RegExp('(?:^|/)lib/l10n/gen/app_localizations').hasMatch(path);
  }

  /// Whether [value] identifies output owned by the Freezed builder.
  static bool isFreezedOutput(String value) =>
      value.replaceAll(r'\', '/').toLowerCase().endsWith('.freezed.dart');

  /// Canonicalizes whitespace emitted by the unformatted Freezed builder.
  ///
  /// Other generated-source families keep their generator-owned formatting.
  static String normalizeWhitespace({
    required String path,
    required String source,
  }) {
    if (!isFreezedOutput(path)) return source;
    return source.replaceAll(RegExp(r'[ \t]+(?=\r?\n|$)'), '');
  }

  /// Returns every generated Dart output that must pass through `dart format`.
  ///
  /// Generators do not all use the workspace formatter version. Formatting the
  /// complete generated Dart surface after every generator has finished keeps
  /// `generate --check` and the standalone format gate idempotent.
  static List<String> dartFormatPaths(Iterable<String> values) {
    final paths =
        values
            .where((value) {
              final path = value.replaceAll(r'\', '/').toLowerCase();
              return path.endsWith('.dart') && includesPath(path);
            })
            .toSet()
            .toList()
          ..sort(
            (left, right) => left
                .replaceAll(r'\', '/')
                .compareTo(right.replaceAll(r'\', '/')),
          );
    return List<String>.unmodifiable(paths);
  }

  /// Removes generated-source records from an LCOV document.
  static String excludeFromLcov(String value) {
    final output = StringBuffer();
    final record = <String>[];
    var generated = false;

    void flush() {
      if (!generated && record.any((line) => line.isNotEmpty)) {
        output
          ..writeAll(record, '\n')
          ..writeln();
      }
      record.clear();
      generated = false;
    }

    for (final line in value.split(RegExp(r'\r?\n'))) {
      if (record.isEmpty && line.isEmpty) continue;
      record.add(line);
      if (line.startsWith('SF:')) {
        generated = includesPath(line.substring('SF:'.length));
      }
      if (line == 'end_of_record') flush();
    }
    if (record.isNotEmpty) flush();
    return output.toString();
  }

  /// Compares snapshots captured before and after workspace generation.
  static GeneratedSourcesCheck compare({
    required Map<String, String> before,
    required Map<String, String> after,
  }) {
    final changedPaths = <String>{
      ...before.keys,
      ...after.keys,
    }.where((path) => before[path] != after[path]).toList()..sort();
    return GeneratedSourcesCheck(List<String>.unmodifiable(changedPaths));
  }
}

/// Result of comparing checked-in generated source snapshots.
final class GeneratedSourcesCheck {
  /// Creates a generated source comparison result.
  const new(this.changedPaths);

  /// Generated paths added, removed, or changed by their generators.
  final List<String> changedPaths;

  /// Whether every checked-in generated source was already current.
  bool get succeeded => changedPaths.isEmpty;
}
