import 'package:daemon/src/features/plugins/runtime/plugin_json_schema.dart';
import 'package:test/test.dart';

void main() {
  group('plugin JSON normalization', () {
    test('copies supported values into immutable JSON', () {
      final source = <Object?, Object?>{
        'null': null,
        'bool': true,
        'string': 'value',
        'number': 1.5,
        'list': <Object?>[1, 'two'],
      };

      final normalized = normalizePluginJson(source)! as Map<String, Object?>;

      expect(normalized, <String, Object?>{
        'null': null,
        'bool': true,
        'string': 'value',
        'number': 1.5,
        'list': <Object?>[1, 'two'],
      });
      expect(() => normalized['new'] = true, throwsUnsupportedError);
      expect(
        () => (normalized['list']! as List<Object?>).add(3),
        throwsUnsupportedError,
      );
    });

    test('rejects non-finite, non-string-keyed, and unsupported values', () {
      expect(
        () => normalizePluginJson(double.nan, path: r'$.number'),
        _validationAt(r'$.number', contains('finite')),
      );
      expect(
        () => normalizePluginJson(<Object?, Object?>{1: 'value'}),
        _validationAt(r'$', contains('keys must be strings')),
      );
      expect(
        () => normalizePluginJson(DateTime.utc(2026)),
        _validationAt(r'$', contains('JSON-compatible')),
      );
    });

    test('rejects JSON trees deeper than the runtime limit', () {
      Object? value = 'leaf';
      for (var index = 0; index < 66; index += 1) {
        value = <Object?>[value];
      }

      expect(
        () => normalizePluginJson(value),
        throwsA(isA<PluginJsonValidationException>()),
      );
    });
  });

  group('plugin JSON schema validation', () {
    test('accepts every supported type including nullable unions', () {
      final values = <String, Object?>{
        'null': null,
        'boolean': true,
        'string': 'value',
        'number': 1.5,
        'integer': 2.0,
        'array': <Object?>[],
        'object': <String, Object?>{},
      };
      for (final entry in values.entries) {
        expect(
          () => validatePluginJsonSchema(<String, Object?>{
            'type': entry.key,
          }, entry.value),
          returnsNormally,
          reason: entry.key,
        );
      }
      expect(
        () => validatePluginJsonSchema(<String, Object?>{
          'type': <Object?>['string', 'null', 4],
        }, null),
        returnsNormally,
      );
    });

    test('reports the actual type when no declared type matches', () {
      final cases = <Object?>[
        null,
        false,
        'text',
        1,
        1.5,
        <Object?>[],
        <String, Object?>{},
      ];
      for (final value in cases) {
        expect(
          () => validatePluginJsonSchema(
            <String, Object?>{'type': 'unsupported'},
            value,
            path: r'$.value',
          ),
          _validationAt(r'$.value', contains('Expected unsupported')),
        );
      }
    });

    test('compares enum values as JSON rather than object identity', () {
      expect(
        () => validatePluginJsonSchema(
          <String, Object?>{
            'enum': <Object?>[
              <String, Object?>{'enabled': true},
            ],
          },
          <String, Object?>{'enabled': true},
        ),
        returnsNormally,
      );
      expect(
        () => validatePluginJsonSchema(<String, Object?>{
          'enum': <Object?>['one', 'two'],
        }, 'three'),
        _validationAt(r'$', contains('enum')),
      );
    });

    test('enforces numeric, string, and array bounds', () {
      final invalid = <(Map<String, Object?>, Object?)>[
        (<String, Object?>{'minimum': 2}, 1),
        (<String, Object?>{'maximum': 2}, 3),
        (<String, Object?>{'minLength': 2}, 'x'),
        (<String, Object?>{'maxLength': 2}, 'xxx'),
        (<String, Object?>{'minItems': 2}, <Object?>[1]),
        (<String, Object?>{'maxItems': 2}, <Object?>[1, 2, 3]),
      ];
      for (final entry in invalid) {
        expect(
          () => validatePluginJsonSchema(entry.$1, entry.$2),
          throwsA(isA<PluginJsonValidationException>()),
        );
      }
      expect(
        () => validatePluginJsonSchema(<String, Object?>{
          'minimum': 1,
          'maximum': 3,
          'minLength': 'ignored',
        }, 2),
        returnsNormally,
      );
    });

    test('validates array items and nested object properties', () {
      final schema = <String, Object?>{
        'type': 'object',
        'required': <Object?>['items', 3],
        'additionalProperties': false,
        'properties': <String, Object?>{
          'items': <String, Object?>{
            'type': 'array',
            'items': <String, Object?>{'type': 'integer', 'minimum': 1},
          },
        },
      };

      expect(
        () => validatePluginJsonSchema(schema, <String, Object?>{}),
        _validationAt(r'$.items', contains('absent')),
      );
      expect(
        () => validatePluginJsonSchema(schema, <String, Object?>{
          'items': <Object?>[0],
        }),
        _validationAt(r'$.items[0]', contains('minimum')),
      );
      expect(
        () => validatePluginJsonSchema(schema, <String, Object?>{
          'items': <Object?>[1],
          'extra': true,
        }),
        _validationAt(r'$.extra', contains('not allowed')),
      );
      expect(
        () => validatePluginJsonSchema(schema, <String, Object?>{
          'items': <Object?>[1, 2.0],
        }),
        returnsNormally,
      );
    });

    test('validates schema-valued additional properties recursively', () {
      final schema = <String, Object?>{
        'type': 'object',
        'additionalProperties': <String, Object?>{
          'type': 'object',
          'properties': <String, Object?>{
            'label': <String, Object?>{
              'type': <Object?>['string', 'null'],
            },
          },
          'additionalProperties': <String, Object?>{
            'type': 'integer',
            'minimum': 1,
          },
        },
      };

      expect(
        () => validatePluginJsonSchema(schema, <String, Object?>{
          'empty': <String, Object?>{},
          'nullable': <String, Object?>{'label': null},
          'scored': <String, Object?>{'score': 2},
        }),
        returnsNormally,
      );
      expect(
        () => validatePluginJsonSchema(schema, <String, Object?>{
          'invalid': <String, Object?>{'score': 'high'},
        }),
        _validationAt(r'$.invalid.score', contains('Expected integer')),
      );
      expect(
        () => validatePluginJsonSchema(schema, <String, Object?>{
          'invalid': 'not-an-object',
        }),
        _validationAt(r'$.invalid', contains('Expected object')),
      );
    });

    test('rejects recursive schemas deeper than the runtime limit', () {
      var schema = <String, Object?>{'type': 'string'};
      Object? value = 'leaf';
      for (var index = 0; index < 66; index += 1) {
        schema = <String, Object?>{'type': 'array', 'items': schema};
        value = <Object?>[value];
      }

      expect(
        () => validatePluginJsonSchema(schema, value),
        throwsA(isA<PluginJsonValidationException>()),
      );
    });
  });
}

Matcher _validationAt(String path, Matcher message) => throwsA(
  isA<PluginJsonValidationException>()
      .having((failure) => failure.path, 'path', path)
      .having((failure) => failure.message, 'message', message),
);
