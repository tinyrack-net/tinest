import 'dart:convert';

/// A plugin value is not finite, bounded JSON or does not satisfy its schema.
final class PluginJsonValidationException extends FormatException {
  /// Creates a validation failure at [path].
  new(String message, {required this.path}) : super('$path: $message');

  /// JSON path containing the invalid value.
  final String path;
}

/// Copies [value] into an immutable, finite, string-keyed JSON tree.
Object? normalizePluginJson(Object? value, {String path = r'$'}) =>
    _normalize(value, path, 0);

/// Validates one normalized JSON value against the supported schema subset.
///
/// Session controls intentionally use a compact provider-neutral subset:
/// type, enum, numeric/string/array bounds, object properties and required
/// keys, additionalProperties, and homogeneous items.
void validatePluginJsonSchema(
  Map<String, Object?> schema,
  Object? value, {
  String path = r'$',
}) {
  final normalized = normalizePluginJson(value, path: path);
  _validate(schema, normalized, path, 0);
}

Object? _normalize(Object? value, String path, int depth) {
  if (depth > 64) {
    throw PluginJsonValidationException(
      'JSON nesting exceeds 64 levels.',
      path: path,
    );
  }
  return switch (value) {
    null || bool() || String() => value,
    final num number when number.isFinite => number,
    num() => throw PluginJsonValidationException(
      'JSON numbers must be finite.',
      path: path,
    ),
    final List<Object?> values => List<Object?>.unmodifiable(<Object?>[
      for (var index = 0; index < values.length; index += 1)
        _normalize(values[index], '$path[$index]', depth + 1),
    ]),
    final Map<Object?, Object?> values => _normalizeMap(values, path, depth),
    _ => throw PluginJsonValidationException(
      'Value must be JSON-compatible.',
      path: path,
    ),
  };
}

Map<String, Object?> _normalizeMap(
  Map<Object?, Object?> values,
  String path,
  int depth,
) {
  final result = <String, Object?>{};
  for (final entry in values.entries) {
    final key = entry.key;
    if (key is! String) {
      throw PluginJsonValidationException(
        'Object keys must be strings.',
        path: path,
      );
    }
    result[key] = _normalize(entry.value, '$path.$key', depth + 1);
  }
  return Map<String, Object?>.unmodifiable(result);
}

void _validate(
  Map<String, Object?> schema,
  Object? value,
  String path,
  int depth,
) {
  if (depth > 64) {
    throw PluginJsonValidationException(
      'Schema nesting exceeds 64 levels.',
      path: path,
    );
  }
  final types = _schemaTypes(schema['type']);
  if (types.isNotEmpty && !types.any((type) => _matchesType(type, value))) {
    throw PluginJsonValidationException(
      'Expected ${types.join(' or ')}, got ${_valueType(value)}.',
      path: path,
    );
  }
  final enumValues = schema['enum'];
  if (enumValues is List<Object?> &&
      !enumValues.any((candidate) => _jsonEquals(candidate, value))) {
    throw PluginJsonValidationException(
      'Value is not one of the declared enum values.',
      path: path,
    );
  }
  switch (value) {
    case final num number:
      _numericBound(
        schema,
        'minimum',
        number,
        path,
        (value) => number >= value,
      );
      _numericBound(
        schema,
        'maximum',
        number,
        path,
        (value) => number <= value,
      );
    case final String text:
      _lengthBound(schema, 'minLength', text.length, path, (a, b) => a >= b);
      _lengthBound(schema, 'maxLength', text.length, path, (a, b) => a <= b);
    case final List<Object?> values:
      _lengthBound(schema, 'minItems', values.length, path, (a, b) => a >= b);
      _lengthBound(schema, 'maxItems', values.length, path, (a, b) => a <= b);
      final items = _schemaMap(schema['items']);
      if (items != null) {
        for (var index = 0; index < values.length; index += 1) {
          _validate(items, values[index], '$path[$index]', depth + 1);
        }
      }
    case final Map<String, Object?> values:
      final required = schema['required'];
      if (required is List<Object?>) {
        for (final key in required.whereType<String>()) {
          if (!values.containsKey(key)) {
            throw PluginJsonValidationException(
              'Required property is absent.',
              path: '$path.$key',
            );
          }
        }
      }
      final properties = _schemaMap(schema['properties']);
      final additionalProperties = schema['additionalProperties'];
      final additionalPropertySchema = _schemaMap(additionalProperties);
      for (final entry in values.entries) {
        final propertySchema = _schemaMap(properties?[entry.key]);
        if (propertySchema != null) {
          _validate(
            propertySchema,
            entry.value,
            '$path.${entry.key}',
            depth + 1,
          );
        } else if (additionalPropertySchema != null) {
          _validate(
            additionalPropertySchema,
            entry.value,
            '$path.${entry.key}',
            depth + 1,
          );
        } else if (additionalProperties == false) {
          throw PluginJsonValidationException(
            'Additional property is not allowed.',
            path: '$path.${entry.key}',
          );
        }
      }
  }
}

Set<String> _schemaTypes(Object? raw) => switch (raw) {
  final String value => <String>{value},
  final List<Object?> values => values.whereType<String>().toSet(),
  _ => const <String>{},
};

bool _matchesType(String type, Object? value) => switch (type) {
  'null' => value == null,
  'boolean' => value is bool,
  'string' => value is String,
  'number' => value is num,
  'integer' =>
    value is int ||
        (value is num && value.isFinite && value == value.truncate()),
  'array' => value is List<Object?>,
  'object' => value is Map<String, Object?>,
  _ => false,
};

String _valueType(Object? value) => switch (value) {
  null => 'null',
  bool() => 'boolean',
  String() => 'string',
  int() => 'integer',
  num() => 'number',
  List<Object?>() => 'array',
  Map<String, Object?>() => 'object',
  _ => value.runtimeType.toString(),
};

void _numericBound(
  Map<String, Object?> schema,
  String keyword,
  num actual,
  String path,
  bool Function(num bound) accepts,
) {
  final bound = schema[keyword];
  if (bound is num && !accepts(bound)) {
    throw PluginJsonValidationException(
      '$actual violates $keyword $bound.',
      path: path,
    );
  }
}

void _lengthBound(
  Map<String, Object?> schema,
  String keyword,
  int actual,
  String path,
  bool Function(int actual, int bound) accepts,
) {
  final bound = schema[keyword];
  if (bound is int && !accepts(actual, bound)) {
    throw PluginJsonValidationException(
      '$actual violates $keyword $bound.',
      path: path,
    );
  }
}

Map<String, Object?>? _schemaMap(Object? value) => switch (value) {
  final Map<Object?, Object?> map when map.keys.every((key) => key is String) =>
    <String, Object?>{
      for (final entry in map.entries) entry.key! as String: entry.value,
    },
  _ => null,
};

bool _jsonEquals(Object? left, Object? right) =>
    jsonEncode(normalizePluginJson(left)) ==
    jsonEncode(normalizePluginJson(right));
