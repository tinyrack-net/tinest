@Tags(<String>[
  'feature_test__plugin_runtime__unit',
  'feature_test__plugin_permissions__unit',
])
library;

import 'package:daemon/src/features/plugins/runtime/host_primitive_contracts.dart';
import 'package:daemon/src/features/plugins/runtime/host_primitives.dart';
import 'package:test/test.dart';

void main() {
  test('registry rejects duplicate primitive operation ids', () {
    final primitive = HostPrimitive<Map<String, Object?>, Object?>(
      operation: 'workspace.read_text',
      capability: 'workspace.read',
      effect: HostPrimitiveEffect.read,
      decode: _object,
      invoke: (_, _) async => const <String, Object?>{'text': ''},
    );

    expect(
      () => HostPrimitiveRegistry(<HostPrimitive<Object?, Object?>>[
        primitive.erased,
        primitive.erased,
      ]),
      throwsStateError,
    );
  });

  test('registry extension preserves bindings and rejects shadowing', () {
    final first = HostPrimitive<Map<String, Object?>, Object?>(
      operation: 'host.workspace.read_text',
      capability: 'workspace.read',
      effect: HostPrimitiveEffect.read,
      decode: _object,
      invoke: (_, _) async => const <String, Object?>{'text': ''},
    );
    final second = HostPrimitive<Map<String, Object?>, Object?>(
      operation: 'host.network.request',
      capability: 'network.access',
      effect: HostPrimitiveEffect.dangerous,
      decode: _object,
      invoke: (_, _) async => const <String, Object?>{'status': 204},
    );
    final registry = HostPrimitiveRegistry(<HostPrimitive<Object?, Object?>>[
      first.erased,
    ]);

    final extended = registry.withPrimitives(<HostPrimitive<Object?, Object?>>[
      second.erased,
    ]);

    expect(
      extended.descriptors.map((descriptor) => descriptor.operation),
      <String>['host.network.request', 'host.workspace.read_text'],
    );
    expect(
      registry.descriptor('host.network.request'),
      isNull,
      reason: 'turn-local bindings must not mutate the shared base registry',
    );
    expect(
      () => extended.withPrimitives(<HostPrimitive<Object?, Object?>>[
        second.erased,
      ]),
      throwsStateError,
    );
  });

  test('descriptor contains safety metadata but no model tool metadata', () {
    final primitive = HostPrimitive<Map<String, Object?>, Object?>(
      operation: 'workspace.read_text',
      capability: 'workspace.read',
      effect: HostPrimitiveEffect.read,
      decode: _object,
      invoke: (_, _) async => const <String, Object?>{'text': ''},
    );

    expect(primitive.descriptor.toJson(), <String, Object?>{
      'operation': 'workspace.read_text',
      'capability': 'workspace.read',
      'effect': 'read',
      'luaInputType': 'any',
      'luaOutputType': 'any',
    });
    expect(
      primitive.descriptor.toJson().keys,
      isNot(containsAll(<String>['name', 'description', 'inputSchema'])),
    );
  });

  test('registry enforces capability before decoding or executing', () async {
    var decoded = false;
    var invoked = false;
    final registry = HostPrimitiveRegistry(<HostPrimitive<Object?, Object?>>[
      HostPrimitive<Map<String, Object?>, Object?>(
        operation: 'workspace.read_text',
        capability: 'workspace.read',
        effect: HostPrimitiveEffect.read,
        decode: (value) {
          decoded = true;
          return _object(value);
        },
        invoke: (_, _) async {
          invoked = true;
          return const <String, Object?>{'text': 'secret'};
        },
      ).erased,
    ]);

    final result = await registry.invoke(
      'workspace.read_text',
      const <String, Object?>{'path': 'secret.txt'},
      const HostPrimitiveContext(
        pluginId: 'acme.reader',
        agentId: 'agent',
        sessionId: 'session',
        workspaceRoot: 'workspace',
        allowedCapabilities: <String>{},
      ),
    );

    expect(result.ok, isFalse);
    expect(result.error?.code, 'capability_denied');
    expect(decoded, isFalse);
    expect(invoked, isFalse);
  });

  test(
    'registry returns stable structured success and failure envelopes',
    () async {
      final registry = HostPrimitiveRegistry(<HostPrimitive<Object?, Object?>>[
        HostPrimitive<Map<String, Object?>, Object?>(
          operation: 'workspace.read_text',
          capability: 'workspace.read',
          effect: HostPrimitiveEffect.read,
          decode: _object,
          invoke: (arguments, _) async => <String, Object?>{
            'text': arguments['path'],
          },
        ).erased,
      ]);
      const context = HostPrimitiveContext(
        pluginId: 'acme.reader',
        agentId: 'agent',
        sessionId: 'session',
        workspaceRoot: 'workspace',
        allowedCapabilities: <String>{'workspace.read'},
      );

      final success = await registry.invoke(
        'workspace.read_text',
        const <String, Object?>{'path': 'README.md'},
        context,
      );
      final missing = await registry.invoke(
        'workspace.missing',
        const <String, Object?>{},
        context,
      );

      expect(success.toJson(), <String, Object?>{
        'ok': true,
        'value': <String, Object?>{'text': 'README.md'},
      });
      expect(missing.toJson(), <String, Object?>{
        'ok': false,
        'error': <String, Object?>{
          'code': 'primitive_not_found',
          'message': 'Host primitive is unavailable: workspace.missing',
          'retryable': false,
        },
      });
    },
  );

  test('contract binding preserves safety and Lua signature metadata', () {
    final primitive = HostPrimitiveContracts.workspaceReadText.bind(
      decode: _object,
      invoke: (_, _) => const <String, Object?>{'text': ''},
    );

    expect(primitive.descriptor.toJson(), <String, Object?>{
      'operation': 'host.workspace.read_text',
      'capability': 'workspace.read',
      'effect': 'read',
      'luaInputType': 'tinest.WorkspaceReadTextInput',
      'luaOutputType': 'tinest.WorkspaceReadTextOutput',
    });
  });

  test('public contract catalog rejects duplicate operation ids', () {
    expect(
      () => indexHostPrimitiveContracts(const <PublicHostPrimitiveContract>[
        HostPrimitiveContracts.workspaceReadText,
        HostPrimitiveContracts.workspaceReadText,
      ]),
      throwsStateError,
    );
  });

  test('registry validation rejects Lua signature drift', () {
    final drifted = HostPrimitive<Map<String, Object?>, Object?>(
      operation: HostPrimitiveContracts.workspaceReadText.operation,
      capability: HostPrimitiveContracts.workspaceReadText.capability,
      effect: HostPrimitiveContracts.workspaceReadText.effect,
      luaInputType: 'tinest.WrongInput',
      luaOutputType: HostPrimitiveContracts.workspaceReadText.luaOutputType,
      decode: _object,
      invoke: (_, _) => const <String, Object?>{'text': ''},
    );
    final registry = HostPrimitiveRegistry(<HostPrimitive<Object?, Object?>>[
      drifted.erased,
    ]);

    expect(
      () => validateHostPrimitiveRegistry(
        registry,
        contracts: const <PublicHostPrimitiveContract>[
          HostPrimitiveContracts.workspaceReadText,
        ],
      ),
      throwsStateError,
    );
  });
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map<Object?, Object?>) {
    throw const FormatException('Expected an object.');
  }
  return <String, Object?>{
    for (final entry in value.entries) entry.key.toString(): entry.value,
  };
}
