@Tags(<String>[
  'feature_test__plugin_permissions__unit',
  'feature_test__plugin_permissions__contract',
  'feature_test__plugin_permissions__verticalSlice',
])
library;

import 'dart:convert';
import 'dart:io';

import 'package:daemon/src/features/plugins/infrastructure/native_plugin_secret_vault.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_ports.dart';
import 'package:daemon/src/features/plugins/transport/rpc_bindings.dart';
import 'package:daemon/src/transport/rpc/binding.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  test('v5 vault persists only exact Agent/plugin secret scopes', () async {
    final root = await Directory.systemTemp.createTemp('tinest-v5-secrets-');
    addTearDown(() => root.delete(recursive: true));
    final vault = NativePluginSecretVault(root.path);
    const owner = PluginSecretScope(
      agentId: 'agent-a',
      pluginId: 'acme.reader',
    );

    await vault.set(owner, 'API_TOKEN', 'secret-value');

    final restarted = NativePluginSecretVault(root.path);
    expect(await restarted.read(owner, 'API_TOKEN'), 'secret-value');
    expect(
      await restarted.read(
        const PluginSecretScope(agentId: 'agent-b', pluginId: 'acme.reader'),
        'API_TOKEN',
      ),
      isNull,
    );
    expect(
      await restarted.read(
        const PluginSecretScope(agentId: 'agent-a', pluginId: 'acme.other'),
        'API_TOKEN',
      ),
      isNull,
    );
    expect(File('${root.path}/v5/plugin-secrets.json').existsSync(), isTrue);
    expect(File('${root.path}/plugin-secrets.json').existsSync(), isFalse);
  });

  test('secret RPC responses never round-trip values or existence', () async {
    final vault = _MemorySecretVault();
    final bindings = pluginSecretRpcBindings(secrets: vault);
    final context = RpcConnectionContext();
    RpcBindingDescriptor binding(RpcProcedureDescriptor procedure) => bindings
        .singleWhere((candidate) => candidate.procedure.name == procedure.name);
    const set = PluginSecretSetParamsDto(
      agentId: 'agent-a',
      pluginId: 'acme.reader',
      name: 'API_TOKEN',
      value: 'must-not-round-trip',
    );

    final setResult = await binding(pluginsSetSecretProcedure)
        .invoke(set.toJson(), context);
    expect(setResult, isEmpty);
    expect(jsonEncode(setResult), isNot(contains('must-not-round-trip')));
    expect(
      await vault.read(
        const PluginSecretScope(agentId: 'agent-a', pluginId: 'acme.reader'),
        'API_TOKEN',
      ),
      'must-not-round-trip',
    );

    const remove = PluginSecretRemoveParamsDto(
      agentId: 'agent-a',
      pluginId: 'acme.reader',
      name: 'API_TOKEN',
    );
    final first = await binding(pluginsRemoveSecretProcedure)
        .invoke(remove.toJson(), context);
    final missing = await binding(pluginsRemoveSecretProcedure)
        .invoke(remove.toJson(), context);
    expect(first, isEmpty);
    expect(missing, first);
  });
}

final class _MemorySecretVault implements PluginSecretVault {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(PluginSecretScope scope, String name) async =>
      _values[_key(scope, name)];

  @override
  Future<void> set(PluginSecretScope scope, String name, String value) async {
    _values[_key(scope, name)] = value;
  }

  @override
  Future<void> remove(PluginSecretScope scope, String name) async {
    _values.remove(_key(scope, name));
  }

  String _key(PluginSecretScope scope, String name) =>
      '${scope.agentId}/${scope.pluginId}/$name';
}
