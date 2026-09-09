import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> main() async {
  final packageRoot = File.fromUri(Platform.script).parent.parent;
  await _generatePluginSdk(packageRoot);
  final sourceRoot = Directory(p.join(packageRoot.path, 'builtin_plugins'));
  final output = File(
    p.join(
      packageRoot.path,
      'lib',
      'src',
      'features',
      'plugins',
      'infrastructure',
      'builtin_plugin_assets.g.dart',
    ),
  );
  final plugins = <String, Map<String, String>>{};
  final directories =
      sourceRoot
          .listSync(followLinks: false)
          .whereType<Directory>()
          .toList(growable: false)
        ..sort((left, right) => left.path.compareTo(right.path));
  for (final directory in directories) {
    final id = p.basename(directory.path);
    if (!RegExp(r'^tinest\.[a-z][a-z0-9]*(?:-[a-z0-9]+)*$').hasMatch(id)) {
      throw FormatException('Invalid built-in plugin directory: $id');
    }
    final assets = <String, String>{};
    final entities =
        directory
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .toList(growable: false)
          ..sort((left, right) => left.path.compareTo(right.path));
    for (final file in entities) {
      final relative = p.posix.joinAll(
        p.split(p.relative(file.path, from: directory.path)),
      );
      if (!relative.endsWith('.lua') && !relative.endsWith('.md')) {
        throw FormatException('Unsupported built-in asset: $id/$relative');
      }
      assets[relative] = base64Encode(await file.readAsBytes());
    }
    plugins[id] = assets;
  }

  final buffer = StringBuffer('''
// GENERATED CODE - DO NOT MODIFY BY HAND.
// Run: dart run tool/generate_builtin_plugins.dart

/// Embedded Lua and Markdown bytes keyed by built-in plugin and asset path.
const Map<String, Map<String, String>> builtInPluginAssetsBase64 =
    <String, Map<String, String>>{
''');
  for (final plugin in plugins.entries) {
    buffer.writeln("      '${plugin.key}': <String, String>{");
    for (final asset in plugin.value.entries) {
      buffer.writeln("        '${asset.key}':");
      for (var offset = 0; offset < asset.value.length; offset += 64) {
        final end = (offset + 64).clamp(0, asset.value.length);
        final comma = end == asset.value.length ? ',' : '';
        buffer.writeln(
          "            '${asset.value.substring(offset, end)}'$comma",
        );
      }
    }
    buffer.writeln('      },');
  }
  buffer.writeln('    };');
  await output.writeAsString(buffer.toString(), flush: true);
}

Future<void> _generatePluginSdk(Directory packageRoot) async {
  final sources = <String, File>{
    'tinestLuaSdkSourceBase64': File(
      p.join(packageRoot.path, 'plugin_sdk', 'library', 'tinest.lua'),
    ),
    'tinestLuaSandboxDefinitionSourceBase64': File(
      p.join(packageRoot.path, 'plugin_sdk', 'library', 'tinest-sandbox.d.lua'),
    ),
  };
  final output = File(
    p.join(
      packageRoot.path,
      'lib',
      'src',
      'features',
      'plugins',
      'runtime',
      'plugin_sdk_assets.g.dart',
    ),
  );
  final buffer = StringBuffer('''
// GENERATED CODE - DO NOT MODIFY BY HAND.
// Run: dart run tool/generate_builtin_plugins.dart
''');
  for (final entry in sources.entries) {
    final encoded = base64Encode(await entry.value.readAsBytes());
    buffer
      ..writeln()
      ..writeln('/// Exact generated source for the public plugin SDK.')
      ..writeln('const String ${entry.key} =');
    for (var offset = 0; offset < encoded.length; offset += 64) {
      final end = (offset + 64).clamp(0, encoded.length);
      final semicolon = end == encoded.length ? ';' : '';
      buffer.writeln("    '${encoded.substring(offset, end)}'$semicolon");
    }
  }
  await output.writeAsString(buffer.toString(), flush: true);
}
