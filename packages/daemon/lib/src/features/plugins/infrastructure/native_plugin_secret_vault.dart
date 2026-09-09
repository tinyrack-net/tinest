import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:daemon/src/features/plugins/infrastructure/plugin_ports.dart';
import 'package:path/path.dart' as p;

/// Atomic Agent/plugin-isolated secret storage under the fresh v5 namespace.
final class NativePluginSecretVault implements PluginSecretVault {
  /// Creates a vault below `<configRoot>/v5` without reading older files.
  new(String configRoot)
    : _file = File(
        p.join(
          p.normalize(p.absolute(configRoot)),
          'v5',
          'plugin-secrets.json',
        ),
      );

  static const int _schemaVersion = 5;

  final File _file;
  final Map<String, String> _values = <String, String>{};
  Future<void> _tail = Future<void>.value();
  bool _loaded = false;

  @override
  Future<String?> read(PluginSecretScope scope, String name) => _serialize(() {
    _ensureLoaded();
    _validate(scope, name);
    return _values[_key(scope, name)];
  });

  @override
  Future<void> set(PluginSecretScope scope, String name, String value) =>
      _serialize(() {
        _ensureLoaded();
        _validate(scope, name);
        if (utf8.encode(value).length > PluginSecretLimits.maximumValueBytes) {
          throw const FormatException('Plugin secret exceeds the host limit.');
        }
        _values[_key(scope, name)] = value;
        _persist();
      });

  @override
  Future<void> remove(PluginSecretScope scope, String name) => _serialize(() {
    _ensureLoaded();
    _validate(scope, name);
    if (_values.remove(_key(scope, name)) != null) _persist();
  });

  Future<T> _serialize<T>(FutureOr<T> Function() operation) {
    final previous = _tail;
    final released = Completer<void>();
    _tail = released.future;
    return previous.then((_) async {
      try {
        return await operation();
      } finally {
        released.complete();
      }
    });
  }

  void _ensureLoaded() {
    if (_loaded) return;
    if (!_file.existsSync()) {
      _loaded = true;
      return;
    }
    final decoded = jsonDecode(_file.readAsStringSync());
    if (decoded is! Map<String, dynamic> ||
        decoded['schemaVersion'] != _schemaVersion ||
        decoded['secrets'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid v5 plugin secret vault.');
    }
    final secrets = decoded['secrets']! as Map<String, dynamic>;
    if (secrets.values.any((value) => value is! String)) {
      throw const FormatException('Invalid v5 plugin secret value.');
    }
    _values.addAll(secrets.cast<String, String>());
    _loaded = true;
  }

  void _persist() {
    _file.parent.createSync(recursive: true);
    if (!Platform.isWindows) {
      Process.runSync('chmod', <String>['700', _file.parent.path]);
    }
    final temporary = File('${_file.path}.$pid.tmp');
    try {
      final sortedKeys = _values.keys.toList()..sort();
      final secrets = <String, String>{
        for (final key in sortedKeys) key: _values[key]!,
      };
      final contents = <String, Object?>{
        'schemaVersion': _schemaVersion,
        'secrets': secrets,
      };
      if (temporary.existsSync()) temporary.deleteSync();
      temporary.writeAsStringSync('${jsonEncode(contents)}\n', flush: true);
      if (!Platform.isWindows) {
        Process.runSync('chmod', <String>['600', temporary.path]);
      }
      temporary.renameSync(_file.path);
      if (!Platform.isWindows) {
        Process.runSync('chmod', <String>['600', _file.path]);
      }
    } finally {
      if (temporary.existsSync()) temporary.deleteSync();
    }
  }
}

void _validate(PluginSecretScope scope, String name) {
  if (!_agentId.hasMatch(scope.agentId)) {
    throw const FormatException('Invalid plugin secret Agent ID.');
  }
  if (!_pluginId.hasMatch(scope.pluginId)) {
    throw const FormatException('Invalid plugin secret plugin ID.');
  }
  if (!_secretName.hasMatch(name) ||
      utf8.encode(name).length > PluginSecretLimits.maximumNameBytes) {
    throw const FormatException('Invalid plugin secret name.');
  }
}

String _key(PluginSecretScope scope, String name) =>
    jsonEncode(<String>[scope.agentId, scope.pluginId, name]);

final RegExp _agentId = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$');
final RegExp _pluginId = RegExp(r'^[a-z][a-z0-9]*(?:\.[a-z][a-z0-9]*)+$');
final RegExp _secretName = RegExp(r'^[A-Za-z][A-Za-z0-9_.-]{0,127}$');
