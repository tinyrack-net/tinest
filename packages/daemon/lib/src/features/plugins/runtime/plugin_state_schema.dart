import 'package:daemon/src/features/plugins/infrastructure/plugin_ports.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_json_schema.dart';

/// Reads the sealed state-cell schema copied into one SDK host call.
Map<String, Object?> pluginStateCellSchema(Map<String, Object?> arguments) {
  final raw = arguments['schema'];
  // The Lua JSON bridge represents an empty object and an empty array with
  // the same empty table. `S.any()` is the only schema that reaches this form.
  if (raw is List<Object?> && raw.isEmpty) {
    return const <String, Object?>{};
  }
  if (raw is! Map<Object?, Object?> ||
      !raw.keys.every((key) => key is String)) {
    throw PluginJsonValidationException(
      'State cell schema must be a JSON schema object.',
      path: r'$.schema',
    );
  }
  final normalized = normalizePluginJson(raw, path: r'$.schema');
  return normalized! as Map<String, Object?>;
}

/// Normalizes and validates one value before it crosses the state boundary.
Object? validatePluginStateCellValue(
  Map<String, Object?> arguments,
  Object? value, {
  required String path,
}) {
  final normalized = normalizePluginJson(value, path: path);
  validatePluginJsonSchema(
    pluginStateCellSchema(arguments),
    normalized,
    path: path,
  );
  return normalized;
}

/// Rejects persisted state that no longer satisfies the declaring cell.
PluginStateEntry? validatePluginStateCellEntry(
  Map<String, Object?> arguments,
  PluginStateEntry? entry, {
  String path = r'$.state.value',
}) {
  if (entry == null) return null;
  return PluginStateEntry(
    revision: entry.revision,
    value: validatePluginStateCellValue(arguments, entry.value, path: path),
  );
}
