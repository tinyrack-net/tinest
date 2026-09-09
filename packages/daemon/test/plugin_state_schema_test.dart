@Tags(<String>['feature_test__plugin_runtime__unit'])
library;

import 'package:daemon/src/features/plugins/infrastructure/plugin_ports.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_json_schema.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_state_schema.dart';
import 'package:test/test.dart';

void main() {
  const stringArguments = <String, Object?>{
    'schema': <String, Object?>{'type': 'string'},
  };

  test('normalizes and validates state cell writes and persisted entries', () {
    expect(
      validatePluginStateCellValue(stringArguments, 'valid', path: r'$.value'),
      'valid',
    );
    expect(validatePluginStateCellEntry(stringArguments, null), isNull);
    final entry = validatePluginStateCellEntry(
      stringArguments,
      const PluginStateEntry(revision: 3, value: 'persisted'),
    );
    expect(entry?.revision, 3);
    expect(entry?.value, 'persisted');

    expect(
      () => validatePluginStateCellValue(stringArguments, 42, path: r'$.value'),
      throwsA(
        isA<PluginJsonValidationException>().having(
          (error) => error.path,
          'path',
          r'$.value',
        ),
      ),
    );
    expect(
      () => validatePluginStateCellEntry(
        stringArguments,
        const PluginStateEntry(revision: 4, value: 42),
      ),
      throwsA(
        isA<PluginJsonValidationException>().having(
          (error) => error.path,
          'path',
          r'$.state.value',
        ),
      ),
    );
  });

  test('accepts the empty-table projection of the any schema', () {
    const arguments = <String, Object?>{'schema': <Object?>[]};
    expect(pluginStateCellSchema(arguments), isEmpty);
    expect(
      validatePluginStateCellValue(arguments, const <String, Object?>{
        'any': true,
      }, path: r'$.value'),
      const <String, Object?>{'any': true},
    );
  });

  test('rejects absent and forged state cell schemas', () {
    for (final arguments in <Map<String, Object?>>[
      const <String, Object?>{},
      const <String, Object?>{'schema': 'string'},
      <String, Object?>{
        'schema': <Object?, Object?>{1: 'forged'},
      },
    ]) {
      expect(
        () => pluginStateCellSchema(arguments),
        throwsA(
          isA<PluginJsonValidationException>().having(
            (error) => error.path,
            'path',
            r'$.schema',
          ),
        ),
      );
    }
  });
}
