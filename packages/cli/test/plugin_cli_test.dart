@Tags(<String>[
  'feature_test__plugin_management__unit',
  'feature_test__plugin_authoring__unit',
])
library;

import 'dart:convert';

import 'package:cli/cli.dart';
import 'package:client/client.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  test('client adapter calls only the typed plugin API', () async {
    final api = _RecordingPluginsApi();
    final backend = PluginsApiPluginCliBackend(api);

    expect(
      (await backend.init('example.review', 'Review tools')).id,
      'example.review',
    );
    expect(
      (await backend.fork('tinest.files', 'example.files', 'Files fork')).id,
      'example.files',
    );
    expect((await backend.validate('example.review')).id, 'example.review');
    expect(
      (await backend.reload('example.review', 'tinest')).id,
      'example.review',
    );
    expect(
      (await backend.getAuthoringEnvironment('example.review')).sdkAbiHash,
      'sdk-abi-hash',
    );
    expect(
      (await backend.syncAuthoringEnvironment('example.review')).synchronized,
      isTrue,
    );
    await backend.setSecret(
      'example.review',
      'tinest',
      'API_TOKEN',
      'do-not-print',
    );
    await backend.removeSecret('example.review', 'tinest', 'API_TOKEN');

    expect(api.calls, <String>[
      'scaffold',
      'fork',
      'validate',
      'reload',
      'authoring-get',
      'authoring-sync',
      'secret-set',
      'secret-remove',
    ]);
    expect(api.scaffoldArguments, ('example.review', 'Review tools'));
    expect(api.forkArguments, ('tinest.files', 'example.files', 'Files fork'));
    expect(api.reloadArguments, ('example.review', 'tinest'));
    expect(api.secretSetArguments, (
      'example.review',
      'tinest',
      'API_TOKEN',
      'do-not-print',
    ));
  });

  test('plugin commands preserve daemon-owned package paths', () async {
    final backend = _PluginBackend();
    final output = StringBuffer();

    expect(
      await pluginInit(
        backend: backend,
        output: output,
        id: 'example.review',
        name: 'Review tools',
      ),
      0,
    );
    expect(
      await pluginValidate(
        backend: backend,
        output: output,
        id: 'example.review',
      ),
      0,
    );
    expect(
      await pluginFork(
        backend: backend,
        output: output,
        sourceId: 'tinest.files',
        id: 'example.files',
        name: 'Files fork',
      ),
      0,
    );
    expect(
      await pluginReload(
        backend: backend,
        output: output,
        id: 'example.review',
        agentId: 'tinest',
      ),
      0,
    );

    expect(backend.scaffolded, <(String, String)>[
      ('example.review', 'Review tools'),
    ]);
    expect(backend.forked, <(String, String, String)>[
      ('tinest.files', 'example.files', 'Files fork'),
    ]);
    expect(backend.validated, <String>['example.review']);
    expect(backend.reloaded, <(String, String)>[('example.review', 'tinest')]);
    expect(output.toString(), contains('/config/v5/plugins/example.review'));
  });

  test('secret commands never write the secret value', () async {
    final backend = _PluginBackend();
    final output = StringBuffer();

    expect(
      await pluginSecretSet(
        backend: backend,
        output: output,
        pluginId: 'example.review',
        agentId: 'tinest',
        name: 'API_TOKEN',
        value: 'top-secret-value',
      ),
      0,
    );
    expect(
      await pluginSecretRemove(
        backend: backend,
        output: output,
        pluginId: 'example.review',
        agentId: 'tinest',
        name: 'API_TOKEN',
      ),
      0,
    );

    expect(backend.secrets, <String, String>{
      'example.review/tinest/API_TOKEN': 'top-secret-value',
    });
    expect(backend.removedSecrets, <String>['example.review/tinest/API_TOKEN']);
    expect(output.toString(), contains('API_TOKEN'));
    expect(output.toString(), isNot(contains('top-secret-value')));
  });

  test(
    'authoring commands expose ABI health and run LuaLS by reference',
    () async {
      final backend = _PluginBackend();
      final output = StringBuffer();
      final invocations = <(String, List<String>)>[];
      Future<PluginExternalProcessResult> run(
        String executable,
        List<String> arguments,
      ) async {
        invocations.add((executable, arguments));
        return const PluginExternalProcessResult(
          exitCode: 0,
          stdout: '3.18.2\n',
          stderr: '',
        );
      }

      expect(
        await pluginSdkSync(
          backend: backend,
          output: output,
          id: 'example.review',
        ),
        0,
      );
      expect(
        await pluginDoctor(
          backend: backend,
          runProcess: run,
          output: output,
          id: 'example.review',
        ),
        0,
      );
      expect(
        await pluginTypecheck(
          backend: backend,
          runProcess: run,
          output: output,
          id: 'example.review',
          json: true,
        ),
        0,
      );

      expect(invocations.first.$1, 'lua-language-server');
      expect(invocations.first.$2, <String>['--version']);
      expect(
        invocations.last.$2,
        contains('--check=/config/v5/plugins/example.review'),
      );
      expect(output.toString(), contains('sdk-abi-hash'));
      expect(output.toString(), contains('"exitCode":0'));
    },
  );

  test('typecheck JSON normalizes LuaLS source diagnostics', () async {
    final output = StringBuffer();
    const sourcePath = r'C:\config\v5\plugins\example.review\main.lua';
    const reset = '\u001b[0m';

    expect(
      await pluginTypecheck(
        backend: _PluginBackend(),
        runProcess: (_, arguments) async {
          expect(arguments, contains('--check_format=pretty'));
          return const PluginExternalProcessResult(
            exitCode: 1,
            stdout:
                '\u001b[34m$sourcePath:12:7\u001b[0m '
                '[\u001b[33mWarning\u001b[0m] '
                'Undefined field `missing`. \u001b[35m(undefined-field)$reset\n'
                '    args.missing\n'
                '          ^^^^^^^\n',
            stderr: '',
          );
        },
        output: output,
        id: 'example.review',
        json: true,
      ),
      1,
    );

    final document = jsonDecode(output.toString()) as Map<String, dynamic>;
    expect(document['exitCode'], 1);
    expect(document['diagnostics'], <Object?>[
      <String, Object?>{
        'code': 'undefined-field',
        'message': 'Undefined field `missing`.',
        'severity': 'warning',
        'path': r'C:\config\v5\plugins\example.review\main.lua',
        'line': 12,
        'column': 7,
      },
    ]);
  });

  test(
    'doctor rejects a different LuaLS release with a shared prefix',
    () async {
      final output = StringBuffer();

      expect(
        await pluginDoctor(
          backend: _PluginBackend(),
          runProcess: (_, _) async => const PluginExternalProcessResult(
            exitCode: 0,
            stdout: 'Lua Language Server 3.18.20\n',
            stderr: '',
          ),
          output: output,
          id: 'example.review',
        ),
        1,
      );
      expect(output.toString(), contains('3.18.2 is required'));
    },
  );
}

final class _RecordingPluginsApi implements PluginsApi {
  @override
  Stream<void> get pluginChanges => const Stream<void>.empty();

  final List<String> calls = <String>[];
  (String, String)? scaffoldArguments;
  (String, String, String)? forkArguments;
  (String, String)? reloadArguments;
  (String, String, String, String)? secretSetArguments;

  PluginDescriptorDto descriptor(String id) => PluginDescriptorDto(
    apiMajor: 5,
    id: id,
    version: '1.0.0',
    name: 'Review tools',
    entrypoint: 'main.lua',
    source: PluginSource.user,
    sourcePath: '/config/v5/plugins/$id',
    requestedCapabilities: const <String>[],
    revision: PluginRevisionDto(
      pluginId: id,
      contentHash: 'revision-hash',
      manifestHash: 'manifest-hash',
      sdkAbiHash: 'sdk-abi-hash',
      executionRevisionHash: 'execution-revision-hash',
      requestedCapabilities: const <String>[],
    ),
  );

  @override
  Future<PluginDescriptorDto> scaffoldPlugin(String id, String name) async {
    calls.add('scaffold');
    scaffoldArguments = (id, name);
    return descriptor(id);
  }

  @override
  Future<PluginDescriptorDto> forkPlugin({
    required String sourceId,
    required String id,
    required String name,
  }) async {
    calls.add('fork');
    forkArguments = (sourceId, id, name);
    return descriptor(id);
  }

  @override
  Future<PluginDescriptorDto> validatePlugin(String id) async {
    calls.add('validate');
    return descriptor(id);
  }

  @override
  Future<PluginDescriptorDto> reloadPlugin(String id, String agentId) async {
    calls.add('reload');
    reloadArguments = (id, agentId);
    return descriptor(id);
  }

  @override
  Future<PluginAuthoringEnvironmentDto> getPluginAuthoringEnvironment(
    String id,
  ) async {
    calls.add('authoring-get');
    return authoring(id);
  }

  @override
  Future<PluginAuthoringEnvironmentDto> syncPluginAuthoringEnvironment(
    String id,
  ) async {
    calls.add('authoring-sync');
    return authoring(id);
  }

  PluginAuthoringEnvironmentDto authoring(String id) =>
      PluginAuthoringEnvironmentDto(
        pluginId: id,
        apiMajor: 5,
        sdkAbiHash: 'sdk-abi-hash',
        luaRuntimeVersion: '5.5.1',
        luaLanguageServerVersion: '3.18.2',
        pluginPath: '/config/v5/plugins/$id',
        sdkLibraryPath: '/config/v5/plugin-sdk/api-5/sdk-abi-hash/library',
        configurationPath: '/config/v5/plugins/$id/.luarc.json',
        synchronized: true,
      );

  @override
  Future<void> setPluginSecret({
    required String agentId,
    required String pluginId,
    required String name,
    required String value,
  }) async {
    calls.add('secret-set');
    secretSetArguments = (pluginId, agentId, name, value);
  }

  @override
  Future<void> removePluginSecret({
    required String agentId,
    required String pluginId,
    required String name,
  }) async {
    calls.add('secret-remove');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

final class _PluginBackend implements PluginCliBackend {
  final List<(String, String)> scaffolded = <(String, String)>[];
  final List<(String, String, String)> forked = <(String, String, String)>[];
  final List<String> validated = <String>[];
  final List<(String, String)> reloaded = <(String, String)>[];
  final Map<String, String> secrets = <String, String>{};
  final List<String> removedSecrets = <String>[];

  PluginDescriptorDto descriptor(String id) => PluginDescriptorDto(
    apiMajor: 5,
    id: id,
    version: '1.0.0',
    name: 'Review tools',
    entrypoint: 'main.lua',
    source: PluginSource.user,
    sourcePath: '/config/v5/plugins/$id',
    requestedCapabilities: const <String>[],
    revision: PluginRevisionDto(
      pluginId: id,
      contentHash: 'revision-hash',
      manifestHash: 'manifest-hash',
      sdkAbiHash: 'sdk-abi-hash',
      executionRevisionHash: 'execution-revision-hash',
      requestedCapabilities: const <String>[],
    ),
  );

  @override
  Future<PluginDescriptorDto> init(String id, String name) async {
    scaffolded.add((id, name));
    return descriptor(id);
  }

  @override
  Future<PluginDescriptorDto> fork(
    String sourceId,
    String id,
    String name,
  ) async {
    forked.add((sourceId, id, name));
    return descriptor(id);
  }

  @override
  Future<PluginDescriptorDto> reload(String id, String agentId) async {
    reloaded.add((id, agentId));
    return descriptor(id);
  }

  @override
  Future<PluginDescriptorDto> validate(String id) async {
    validated.add(id);
    return descriptor(id);
  }

  @override
  Future<PluginAuthoringEnvironmentDto> getAuthoringEnvironment(
    String id,
  ) async => _authoring(id);

  @override
  Future<PluginAuthoringEnvironmentDto> syncAuthoringEnvironment(
    String id,
  ) async => _authoring(id);

  @override
  Future<void> setSecret(
    String pluginId,
    String agentId,
    String name,
    String value,
  ) async {
    secrets['$pluginId/$agentId/$name'] = value;
  }

  @override
  Future<void> removeSecret(
    String pluginId,
    String agentId,
    String name,
  ) async {
    removedSecrets.add('$pluginId/$agentId/$name');
  }

  PluginAuthoringEnvironmentDto _authoring(String id) =>
      PluginAuthoringEnvironmentDto(
        pluginId: id,
        apiMajor: 5,
        sdkAbiHash: 'sdk-abi-hash',
        luaRuntimeVersion: '5.5.1',
        luaLanguageServerVersion: '3.18.2',
        pluginPath: '/config/v5/plugins/$id',
        sdkLibraryPath: '/config/v5/plugin-sdk/api-5/sdk-abi-hash/library',
        configurationPath: '/config/v5/plugins/$id/.luarc.json',
        synchronized: true,
      );
}
