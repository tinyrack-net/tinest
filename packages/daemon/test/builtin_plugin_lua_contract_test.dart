@Tags(<String>['feature_test__plugin_runtime__unit'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('built-in plugins use typed references instead of string wiring', () {
    final violations = <String>[];
    for (final file in _builtInEntrypoints()) {
      final source = file.readAsStringSync();
      final executable = _withoutCommentsAndStrings(source);
      final relative = p.relative(file.path, from: _daemonPackageRoot().path);

      void reject(RegExp pattern, String message) {
        if (pattern.hasMatch(executable)) {
          violations.add('$relative: $message');
        }
      }

      expect(
        source,
        contains('local tinest = require("tinest")'),
        reason: '$relative must import the public SDK module explicitly.',
      );
      reject(
        RegExp(r'\bhandler\s*='),
        'declares a handler binding instead of supplying a closure',
      );
      reject(RegExp(r'\.call\s*\('), 'dispatches a host operation by string');
      reject(RegExp(r'\bactionId\s*='), 'links a UI action by string');
      reject(
        RegExp(
          r'tinest\.ui\.(?:document|timeline|status|dialog)\s*\(\s*\{[^}]*\bcontribution_id\s*=',
          dotAll: true,
        ),
        'links a UI contribution by string',
      );
      reject(
        RegExp(r'''tinest\.tools\.invoke\s*\(\s*["']'''),
        'invokes a tool contribution by string',
      );
      reject(
        RegExp(r'\b(?:input_)?schema\s*=\s*\{'),
        'declares raw JSON Schema instead of using tinest.schema',
      );
      reject(
        RegExp(r'\bS\.(?:object|enum|literal_enum|raw)\s*\(\s*(?!T\.)'),
        'declares an untyped schema instead of a tinest.types token',
      );
      for (final field in const <String>[
        'required_capabilities',
        'capability_limit',
        'effects',
        'required_model_capabilities',
      ]) {
        reject(
          RegExp('\\b$field\\s*=\\s*\\{[^}]*""', dotAll: true),
          'uses string literals in $field instead of SDK code references',
        );
      }
      reject(
        RegExp(r'\bslot\s*=\s*""'),
        'uses a UI slot string instead of tinest.ui.slot',
      );
      reject(
        RegExp(r'\brole\s*=\s*""'),
        'uses a model role string instead of tinest.model.role',
      );
      reject(
        RegExp(r'descriptor\.(?:kind|exposure)\s*[~=]=\s*""'),
        'compares a tool descriptor to a string instead of an SDK constant',
      );
      reject(
        RegExp(r'\.status\s*(?:[~=]=|=)\s*""'),
        'links a status variant by string instead of enum constants',
      );
      if (RegExp(r'''["']tinest\.[a-z0-9.-]+/[a-z0-9_-]+["']''')
          .hasMatch(source)) {
        violations.add(
          '$relative: retypes a built-in contribution ID instead of using '
          'its opaque reference',
        );
      }
      if (RegExp(
        r'''\btype\s*=\s*["'](?:section|row|text|markdown|code|diff|alert|badge|progress|disclosure|field|button|switch|select)["']''',
      ).hasMatch(source)) {
        violations.add(
          '$relative: declares a raw UI node instead of using '
          'tinest.ui constructors',
        );
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('built-in model tools compose low-level host primitives in Lua', () {
    final sources = <String, String>{
      for (final file in _builtInEntrypoints())
        p.basename(file.parent.path): file.readAsStringSync(),
    };

    expect(
      sources['tinest.files'],
      allOf(
        contains('local T = require("tinest.types")'),
        contains('S.object(T.ReadFileInput'),
        contains('tinest.host.workspace.stat'),
        contains('tinest.host.workspace.list'),
        contains('tinest.host.workspace.read_text'),
        contains('tinest.host.workspace.read_blob'),
        contains('tinest.host.workspace.walk'),
      ),
    );
    expect(
      sources['tinest.edit'],
      allOf(
        contains('tinest.host.workspace.read_text'),
        contains('tinest.host.workspace.transaction'),
        contains('local function parse(source)'),
        contains('local function apply_chunks(operation, original)'),
      ),
    );
    expect(
      sources['tinest.terminal'],
      allOf(
        contains('tinest.host.process.start'),
        contains('tinest.host.process.read'),
        contains('tinest.host.process.write'),
      ),
    );
    expect(
      sources['tinest.lua-code'],
      allOf(
        contains('tinest.host.lua.start'),
        contains('tinest.host.lua.read'),
        contains('tinest.host.lua.terminate'),
        contains('tinest.tools.model_input(call, descriptor)'),
      ),
    );
    expect(
      sources['tinest.standard'],
      allOf(
        contains('tinest.model.close(stream)'),
        contains('tinest.tools.model_input(call, descriptor)'),
      ),
      reason: 'The standard Lua driver must release every completed stream.',
    );

    final all = sources.values.join('\n');
    expect(all, isNot(contains('tinest.host.patch.apply')));
    expect(all, isNot(contains('tinest.host.workspace.read_file')));
    expect(all, isNot(contains('tinest.host.workspace.search_text')));
    expect(all, isNot(contains('tinest.host.workspace.glob')));
    expect(all, isNot(contains('tinest.host.process.exec_command')));
    expect(all, isNot(contains('tinest.host.process.write_stdin')));
  });
}

Iterable<File> _builtInEntrypoints() sync* {
  final root = Directory(p.join(_daemonPackageRoot().path, 'builtin_plugins'));
  final files =
      root
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((file) => p.basename(file.path) == 'main.lua')
          .toList(growable: false)
        ..sort((left, right) => left.path.compareTo(right.path));
  yield* files;
}

String _withoutCommentsAndStrings(String source) {
  final buffer = StringBuffer();
  var index = 0;
  while (index < source.length) {
    if (source.startsWith('--[[', index)) {
      final end = source.indexOf(']]', index + 4);
      index = end < 0 ? source.length : end + 2;
      buffer.write(' ');
      continue;
    }
    if (source.startsWith('--', index)) {
      final end = source.indexOf('\n', index + 2);
      index = end < 0 ? source.length : end;
      buffer.write(' ');
      continue;
    }
    final quote = source.codeUnitAt(index);
    if (quote == 0x22 || quote == 0x27) {
      index += 1;
      while (index < source.length) {
        final current = source.codeUnitAt(index);
        if (current == 0x5c) {
          index += 2;
          continue;
        }
        index += 1;
        if (current == quote) break;
      }
      buffer.write('""');
      continue;
    }
    buffer.writeCharCode(source.codeUnitAt(index));
    index += 1;
  }
  return buffer.toString();
}

Directory _daemonPackageRoot() {
  var directory = Directory.current.absolute;
  while (true) {
    if (File(p.join(directory.path, 'pubspec.yaml')).existsSync() &&
        Directory(p.join(directory.path, 'builtin_plugins')).existsSync()) {
      return directory;
    }
    final nested = Directory(p.join(directory.path, 'packages', 'daemon'));
    if (File(p.join(nested.path, 'pubspec.yaml')).existsSync() &&
        Directory(p.join(nested.path, 'builtin_plugins')).existsSync()) {
      return nested;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('Daemon package root not found.');
    }
    directory = parent;
  }
}
