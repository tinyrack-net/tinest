import 'dart:io';

import 'package:tinest_quality/src/generated_sources.dart';

void main() {
  final packages = Directory('packages');
  final generatedPaths = <String>[];
  for (final package in packages.listSync().whereType<Directory>()) {
    final library = Directory('${package.path}/lib');
    if (!library.existsSync()) continue;
    for (final file in library.listSync(recursive: true).whereType<File>()) {
      if (!GeneratedSources.includesPath(file.path)) continue;
      generatedPaths.add(file.path);
      if (!GeneratedSources.isFreezedOutput(file.path)) continue;
      final source = file.readAsStringSync();
      final normalized = GeneratedSources.normalizeWhitespace(
        path: file.path,
        source: source,
      );
      if (normalized != source) file.writeAsStringSync(normalized);
    }
  }

  final formatPaths = GeneratedSources.dartFormatPaths(generatedPaths);
  if (formatPaths.isEmpty) return;
  final result = Process.runSync(Platform.resolvedExecutable, <String>[
    'format',
    ...formatPaths,
  ]);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) exitCode = result.exitCode;
}
