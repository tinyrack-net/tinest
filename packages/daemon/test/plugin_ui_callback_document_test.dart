@Tags(<String>['feature_test__plugin_ui__unit'])
library;

import 'package:daemon/src/features/plugins/runtime/plugin_runtime.dart';
import 'package:test/test.dart';

void main() {
  const pluginId = 'acme.ui';
  const refresh = 'acme.ui/refresh';

  test('constructor documents bind only registered same-revision actions', () {
    final document = decodePluginUiCallbackDocument(
      <String, Object?>{
        '__tinest_ui_document': 'constructor',
        'root': <String, Object?>{
          'type': 'section',
          'children': <Object?>[
            <String, Object?>{'type': 'button', 'actionId': refresh},
          ],
        },
        'actions': <Object?>[refresh],
      },
      pluginId: pluginId,
      registeredActionIds: const <String>{refresh},
    );

    expect(document.constructorOwned, isTrue);
    expect(document.actionIds, const <String>{refresh});
    expect(
      () => document.actionIds.add('acme.ui/forged'),
      throwsUnsupportedError,
    );
    expect(() => document.root['type'] = 'forged', throwsUnsupportedError);
  });

  test('raw documents cannot smuggle action bindings', () {
    expect(
      () => decodePluginUiCallbackDocument(
        <String, Object?>{
          '__tinest_ui_document': 'raw',
          'root': <String, Object?>{'type': 'button', 'actionId': refresh},
        },
        pluginId: pluginId,
        registeredActionIds: const <String>{refresh},
      ),
      throwsA(
        isA<PluginUiCallbackDocumentException>().having(
          (error) => error.message,
          'message',
          contains('Raw plugin UI documents cannot declare actions'),
        ),
      ),
    );

    final inert = decodePluginUiCallbackDocument(
      <String, Object?>{
        '__tinest_ui_document': 'raw',
        'root': <String, Object?>{'type': 'text', 'text': 'safe'},
      },
      pluginId: pluginId,
      registeredActionIds: const <String>{refresh},
    );
    expect(inert.constructorOwned, isFalse);
    expect(inert.actionIds, isEmpty);
  });

  test('constructor ownership and action lists fail closed', () {
    final cases = <String, Object?>{
      'missing SDK ownership': <String, Object?>{
        'root': <String, Object?>{'type': 'text'},
      },
      'missing action list': <String, Object?>{
        '__tinest_ui_document': 'constructor',
        'root': <String, Object?>{'type': 'text'},
      },
      'duplicate action': <String, Object?>{
        '__tinest_ui_document': 'constructor',
        'root': <String, Object?>{'type': 'button', 'actionId': refresh},
        'actions': <Object?>[refresh, refresh],
      },
      'foreign action': <String, Object?>{
        '__tinest_ui_document': 'constructor',
        'root': <String, Object?>{
          'type': 'button',
          'actionId': 'other.ui/refresh',
        },
        'actions': <Object?>['other.ui/refresh'],
      },
      'unregistered action': <String, Object?>{
        '__tinest_ui_document': 'constructor',
        'root': <String, Object?>{
          'type': 'button',
          'actionId': 'acme.ui/hidden',
        },
        'actions': <Object?>['acme.ui/hidden'],
      },
      'snapshot mismatch': <String, Object?>{
        '__tinest_ui_document': 'constructor',
        'root': <String, Object?>{'type': 'text'},
        'actions': <Object?>[refresh],
      },
    };

    for (final entry in cases.entries) {
      expect(
        () => decodePluginUiCallbackDocument(
          entry.value,
          pluginId: pluginId,
          registeredActionIds: const <String>{refresh},
        ),
        throwsA(isA<PluginUiCallbackDocumentException>()),
        reason: entry.key,
      );
    }
  });

  test('callback documents accept only bounded JSON values', () {
    Object? nested = 'leaf';
    for (var index = 0; index < 34; index += 1) {
      nested = <Object?>[nested];
    }
    final cases = <String, Object?>{
      'non-object envelope': <Object?>[],
      'non-object root': <String, Object?>{
        '__tinest_ui_document': 'raw',
        'root': <Object?>[],
      },
      'non-string object key': <String, Object?>{
        '__tinest_ui_document': 'raw',
        'root': <Object?, Object?>{1: 'invalid'},
      },
      'non-json value': <String, Object?>{
        '__tinest_ui_document': 'raw',
        'root': <String, Object?>{'value': DateTime.utc(2026)},
      },
      'excessive depth': <String, Object?>{
        '__tinest_ui_document': 'raw',
        'root': <String, Object?>{'value': nested},
      },
      'empty action ID': <String, Object?>{
        '__tinest_ui_document': 'constructor',
        'root': <String, Object?>{'type': 'button', 'actionId': ''},
        'actions': <Object?>[],
      },
    };

    for (final entry in cases.entries) {
      expect(
        () => decodePluginUiCallbackDocument(
          entry.value,
          pluginId: pluginId,
          registeredActionIds: const <String>{refresh},
        ),
        throwsA(isA<PluginUiCallbackDocumentException>()),
        reason: entry.key,
      );
    }
  });
}
