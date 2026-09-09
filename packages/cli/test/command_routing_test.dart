@Tags(<String>['feature_test__daemon_management__unit'])
library;

import 'dart:async';
import 'dart:io';

import 'package:cli/cli.dart';
import 'package:client/client.dart';
import 'package:client/local_daemon.dart';
import 'package:daemon/daemon.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'helpers/capture_stream.dart';

/// Drives every route through the real cliweave application against a fake
/// daemon client, which is the only way the command bodies, the write-stream
/// adapter, and the spinner are all exercised together.
void main() {
  final now = DateTime.utc(2026, 8, 2);
  late CaptureStream out;
  late CaptureStream err;
  late _FakeClient client;

  setUp(() {
    out = CaptureStream();
    err = CaptureStream();
    client = _FakeClient(now);
  });

  const directories = LocalDaemonDirectories(
    configDirectory: '/config',
    stateDirectory: '/state',
    userHomeDirectory: '/home/test',
    osHomeDirectory: '/home/test',
  );

  Future<int> run(
    List<String> inputs, {
    Future<String> Function(String path)? readFile,
    Future<String> Function()? readSecret,
    PluginExternalProcessRunner? runPluginProcess,
  }) {
    return runCli(
      <String>[...inputs, '--token', 'token', '--listen', '127.0.0.1:7337'],
      stdout: out,
      stderr: err,
      environment: const <String, String>{},
      directories: directories,
      readFile: readFile ?? (_) async => 'markdown',
      readSecret: readSecret ?? () async => 'prompted-secret',
      runPluginProcess: runPluginProcess,
      connectClient: ({
        required host,
        required port,
        required bearerToken,
        required clientId,
      }) async => client,
    );
  }

  group('provider', () {
    test('list renders the catalog name of each connection', () async {
      expect(await run(<String>['provider', 'list']), 0);

      expect(out.text, contains('OpenAI'));
      expect(client.closed, isTrue);
    });

    test('connect prompts for a hosted provider secret', () async {
      expect(await run(<String>['provider', 'connect', 'deepseek']), 0);

      expect(client.apiKeys['deepseek'], 'prompted-secret');
      expect(out.text, contains('Connected'));
    });

    test('--method none connects without a credential', () async {
      expect(
        await run(<String>[
          'provider',
          'connect',
          'ollama',
          '--method',
          'none',
        ]),
        0,
      );

      expect(client.noneConnections, contains('ollama'));
    });

    test('--api-key skips the prompt', () async {
      expect(
        await run(<String>[
          'provider',
          'connect',
          'deepseek',
          '--api-key',
          'inline',
        ], readSecret: () async => fail('the prompt must not run')),
        0,
      );

      expect(client.apiKeys['deepseek'], 'inline');
    });

    test('an unknown --method is rejected by the scanner', () async {
      expect(
        await run(<String>[
          'provider',
          'connect',
          'openai',
          '--method',
          'telepathy',
        ]),
        isNot(0),
      );
      expect(client.apiKeys, isEmpty);
    });

    test('disconnect forwards the connection ID', () async {
      expect(await run(<String>['provider', 'disconnect', 'openai']), 0);

      expect(client.disconnected, <String>['openai']);
    });

    test('catalog-refresh runs through the spinner', () async {
      expect(await run(<String>['provider', 'catalog-refresh']), 0);

      expect(client.refreshes, 1);
      expect(out.text, contains('Provider catalog refreshed'));
    });

    test('a missing provider ID is a usage error', () async {
      expect(await run(<String>['provider', 'connect']), 64);
    });
  });

  group('agent', () {
    test('list renders each definition', () async {
      expect(await run(<String>['agent', 'list']), 0);

      expect(out.text, contains('tinest'));
      expect(client.closed, isTrue);
    });

    test('validate reads the file and names the definition', () async {
      expect(await run(<String>['agent', 'validate', '/tmp/reviewer.md']), 0);

      expect(out.text, contains('Valid reviewer'));
    });

    test('apply requires --file', () async {
      expect(await run(<String>['agent', 'apply', 'reviewer']), isNot(0));
      expect(client.created, isEmpty);
    });

    test('apply creates a definition from --file', () async {
      expect(
        await run(<String>[
          'agent',
          'apply',
          'reviewer',
          '--file',
          '/tmp/reviewer.md',
        ]),
        0,
      );

      expect(client.created, contains('reviewer'));
      expect(out.text, contains('Applied reviewer'));
    });

    test('archive forwards the agent ID', () async {
      expect(await run(<String>['agent', 'archive', 'reviewer']), 0);

      expect(client.archived, <String>['reviewer']);
    });

    test('reset restores the built-in definition', () async {
      expect(await run(<String>['agent', 'reset', 'tinest']), 0);

      expect(client.reset, <String>['tinest']);
    });

    test('reset refuses any other agent', () async {
      expect(await run(<String>['agent', 'reset', 'reviewer']), 64);

      expect(client.reset, isEmpty);
    });

    test('the real file reader is used by default', () async {
      final file = File(
        '${Directory.systemTemp.createTempSync('tinest-cli-agent-').path}'
        '/reviewer.md',
      )..writeAsStringSync('markdown from disk');
      addTearDown(() => file.parent.deleteSync(recursive: true));

      final code = await runCli(
        <String>[
          'agent',
          'validate',
          file.path,
          '--token',
          'token',
          '--listen',
          '127.0.0.1:7337',
        ],
        stdout: out,
        stderr: err,
        environment: const <String, String>{},
        directories: directories,
        connectClient: ({
          required host,
          required port,
          required bearerToken,
          required clientId,
        }) async => client,
      );

      expect(code, 0);
      expect(client.validatedMarkdown, <String>['markdown from disk']);
    });
  });

  group('plugin', () {
    test('init scaffolds only through the daemon plugin API', () async {
      expect(
        await run(<String>[
          'plugin',
          'init',
          'example.review',
          '--name',
          'Review tools',
        ]),
        0,
      );

      expect(client.scaffoldedPlugins, <(String, String)>[
        ('example.review', 'Review tools'),
      ]);
      expect(out.text, contains('Initialized example.review'));
      expect(out.text, contains('/config/v5/plugins/example.review'));
    });

    test('init requires a display name before calling the daemon', () async {
      expect(
        await run(<String>['plugin', 'init', 'example.review']),
        usageExitCode,
      );

      expect(client.scaffoldedPlugins, isEmpty);
    });

    test('fork copies one validated plugin through the daemon API', () async {
      expect(
        await run(<String>[
          'plugin',
          'fork',
          'tinest.files',
          '--id',
          'example.files',
          '--name',
          'Files fork',
        ]),
        0,
      );

      expect(client.forkedPlugins, <(String, String, String)>[
        ('tinest.files', 'example.files', 'Files fork'),
      ]);
      expect(out.text, contains('Forked tinest.files as example.files'));
    });

    test('validate reports the validated revision', () async {
      expect(await run(<String>['plugin', 'validate', 'example.review']), 0);

      expect(client.validatedPlugins, <String>['example.review']);
      expect(out.text, contains('Valid example.review@1.0.0'));
      expect(out.text, contains('revision-hash'));
    });

    test('sdk-sync repairs the exact SDK authoring sidecar', () async {
      expect(await run(<String>['plugin', 'sdk-sync', 'example.review']), 0);

      expect(out.text, contains('sdk-abi-hash'));
      expect(out.text, contains('.luarc.json'));
    });

    test(
      'doctor checks the exact LuaLS release through the process port',
      () async {
        String? executable;
        List<String>? arguments;

        expect(
          await run(
            <String>['plugin', 'doctor', 'example.review'],
            runPluginProcess: (command, args) async {
              executable = command;
              arguments = args;
              return const PluginExternalProcessResult(
                exitCode: 0,
                stdout: 'Lua Language Server 3.18.2\n',
                stderr: '',
              );
            },
          ),
          0,
        );
        expect(executable, 'lua-language-server');
        expect(arguments, <String>['--version']);
        expect(out.text, contains('LuaLS'));
      },
    );

    test('typecheck scopes LuaLS to the app-data plugin workspace', () async {
      List<String>? arguments;

      expect(
        await run(
          <String>['plugin', 'typecheck', 'example.review', '--json'],
          runPluginProcess: (_, args) async {
            arguments = args;
            return const PluginExternalProcessResult(
              exitCode: 0,
              stdout: '',
              stderr: '',
            );
          },
        ),
        0,
      );
      expect(arguments, <String>[
        '--check=/config/v5/plugins/example.review',
        '--checklevel=Information',
        '--check_format=pretty',
      ]);
      expect(out.text, contains('"pluginId":"example.review"'));
    });

    test(
      'daemon validation failures retain the unavailable exit code',
      () async {
        client.failPluginValidation = true;

        expect(
          await run(<String>['plugin', 'validate', 'example.review']),
          unavailableExitCode,
        );
        expect(err.text, contains('Plugin source is invalid.'));
        expect(out.text, isEmpty);
      },
    );

    test(
      'reload requires an Agent and reports the activated revision',
      () async {
        expect(
          await run(<String>[
            'plugin',
            'reload',
            'example.review',
            '--agent',
            'tinest',
          ]),
          0,
        );

        expect(client.reloadedPlugins, <(String, String)>[
          ('example.review', 'tinest'),
        ]);
        expect(out.text, contains('Reloaded example.review for tinest'));
        expect(out.text, contains('revision-hash'));

        final before = client.reloadedPlugins.length;
        expect(
          await run(<String>['plugin', 'reload', 'example.review']),
          usageExitCode,
        );
        expect(client.reloadedPlugins, hasLength(before));
      },
    );

    test(
      'secret set uses the no-echo prompt and never prints its value',
      () async {
        var prompts = 0;
        expect(
          await run(
            <String>[
              'plugin',
              'secret',
              'set',
              'example.review',
              '--agent',
              'tinest',
              '--name',
              'API_TOKEN',
            ],
            readSecret: () async {
              prompts += 1;
              return 'do-not-echo';
            },
          ),
          0,
        );

        expect(prompts, 1);
        expect(client.pluginSecrets, <String, String>{
          'example.review/tinest/API_TOKEN': 'do-not-echo',
        });
        expect(out.text, contains('Stored API_TOKEN'));
        expect(out.text, isNot(contains('do-not-echo')));
      },
    );

    test('secret remove does not prompt or reveal existence', () async {
      expect(
        await run(<String>[
          'plugin',
          'secret',
          'remove',
          'example.review',
          '--agent',
          'tinest',
          '--name',
          'API_TOKEN',
        ], readSecret: () async => fail('remove must not prompt')),
        0,
      );

      expect(client.removedPluginSecrets, <String>[
        'example.review/tinest/API_TOKEN',
      ]);
      expect(out.text, contains('Removed API_TOKEN'));
    });
  });

  group('daemon start', () {
    test('announces the endpoint and stops on the shutdown signal', () async {
      final handle = _FakeHandle();
      final shutdown = Completer<void>();

      final code = runCli(
        <String>['daemon', 'start', '--listen', '127.0.0.1:9200'],
        stdout: out,
        stderr: err,
        environment: const <String, String>{},
        directories: directories,
        startDaemon: (_) async => handle,
        shutdownSignal: () => shutdown.future,
      );
      await pumpEventQueue();
      shutdown.complete();

      expect(await code, 0);
      expect(out.text, contains('listening on'));
      expect(handle.stopped, isTrue);
    });

    test('every flag reaches the daemon config', () async {
      DaemonConfig? seen;

      await runCli(
        <String>[
          'daemon',
          'start',
          '--home',
          '/portable',
          '--listen',
          '0.0.0.0:9300',
          '--token',
          'a' * 32,
          '--allowed-origin',
          'https://tinest.tinyrack.net',
          '--allowed-origin',
          'http://localhost:8080',
          '--relay',
          '--relay-endpoint',
          'wss://relay.example/v1/ws',
        ],
        stdout: out,
        stderr: err,
        environment: const <String, String>{},
        directories: directories,
        startDaemon: (config) async {
          seen = config;
          return _FakeHandle();
        },
        shutdownSignal: () async {},
      );

      expect(seen?.homeDirectory, '/portable');
      expect(seen?.host, '0.0.0.0');
      expect(seen?.port, 9300);
      expect(seen?.bearerToken, 'a' * 32);
      expect(seen?.allowedOrigins, <String>{
        'https://tinest.tinyrack.net',
        'http://localhost:8080',
      });
      expect(seen?.relay.enabled, isTrue);
      expect(seen?.relay.endpoint.toString(), 'wss://relay.example/v1/ws');
    });

    test('a generated token is printed, a supplied one is not', () async {
      await runCli(
        <String>['daemon', 'start'],
        stdout: out,
        stderr: err,
        environment: const <String, String>{},
        directories: directories,
        startDaemon: (_) async => _FakeHandle(),
        shutdownSignal: () async {},
      );
      expect(out.text, contains('generated-token'));

      final quiet = CaptureStream();
      await runCli(
        <String>['daemon', 'start', '--token', 'a' * 32],
        stdout: quiet,
        stderr: err,
        environment: const <String, String>{},
        directories: directories,
        startDaemon: (_) async => _FakeHandle(),
        shutdownSignal: () async {},
      );
      expect(quiet.text, isNot(contains('generated-token')));
    });

    test('a malformed --listen is a usage error', () async {
      final code = await runCli(
        <String>['daemon', 'start', '--listen', 'nonsense'],
        stdout: out,
        stderr: err,
        environment: const <String, String>{},
        directories: directories,
        startDaemon: (_) async => fail('the daemon must not start'),
        shutdownSignal: () async {},
      );

      expect(code, 64);
      expect(err.text, contains('host:port'));
    });
  });

  group('daemon relay', () {
    test('pair can enable relay and emit a machine-readable offer', () async {
      expect(await run(<String>['daemon', 'pair', '--relay', '--json']), 0);

      expect(client.relayEnabled, isTrue);
      expect(out.text, contains('https://tinest.tinyrack.net/pair#offer='));
      expect(out.text, contains('serverId'));
    });

    test('status, device list, and revoke use the relay API', () async {
      client.relayEnabled = true;
      expect(await run(<String>['daemon', 'relay', 'status']), 0);
      expect(out.text, contains('Relay: enabled'));

      expect(await run(<String>['daemon', 'devices', 'list']), 0);
      expect(out.text, contains('Test phone'));

      expect(await run(<String>['daemon', 'devices', 'revoke', 'device-1']), 0);
      expect(client.revokedDevices, <String>['device-1']);
    });

    test('human pairing, JSON status, and activation routes render', () async {
      expect(await run(<String>['daemon', 'relay', 'status', '--json']), 0);
      expect(out.text, contains('"serverId":"server-1"'));

      expect(await run(<String>['daemon', 'relay', 'enable']), 0);
      expect(out.text, contains('Relay enabled.'));
      expect(await run(<String>['daemon', 'pair']), 0);
      expect(out.text, contains('Pairing link'));
      expect(out.text, contains('█'));

      expect(await run(<String>['daemon', 'devices', 'list', '--json']), 0);
      expect(out.text, contains('device-1'));
      expect(await run(<String>['daemon', 'relay', 'disable']), 0);
      expect(out.text, contains('Relay disabled.'));
    });

    test('pairing refuses to hide a disabled relay', () async {
      expect(await run(<String>['daemon', 'pair']), 64);
      expect(err.text, contains('Pass --relay'));
    });
  });

  group('default composition', () {
    test('resolves real directories when none are injected', () async {
      // No `directories` or `environment`, so the platform resolver runs.
      final code = await runCli(
        <String>['--version'],
        stdout: out,
        stderr: err,
      );

      expect(code, 0);
      expect(out.text.trim(), packageVersion);
    });

    test('the real connector reports a closed port as unavailable', () async {
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = socket.port;
      // Released so nothing is listening, which is the failure an operator
      // sees when the daemon is not running.
      await socket.close();

      final code = await runCli(
        <String>[
          'provider',
          'list',
          '--listen',
          '127.0.0.1:$port',
          '--token',
          'token',
        ],
        stdout: out,
        stderr: err,
        environment: const <String, String>{},
        directories: directories,
      );

      expect(code, 69);
      expect(err.text, contains('Cannot connect to the daemon'));
    });
  });
}

final class _FakeHandle implements DaemonHandle {
  bool stopped = false;

  @override
  Uri get boundEndpoint => Uri.parse('http://127.0.0.1:9200');

  @override
  String get serverId => 'server';

  @override
  String get bearerToken => 'generated-token';

  @override
  Future<void> get ready async {}

  @override
  Future<void> stop() async {
    stopped = true;
  }
}

/// A [TinestClient] stand-in answering only the calls the CLI makes.
final class _FakeClient
    implements TinestClient, ProvidersApi, AgentsApi, PluginsApi, RelayApi {
  new(this.now);

  final DateTime now;
  final Map<String, String> apiKeys = <String, String>{};
  final List<String> noneConnections = <String>[];
  final List<String> disconnected = <String>[];
  final List<String> archived = <String>[];
  final List<String> reset = <String>[];
  final List<String> created = <String>[];
  final List<String> validatedMarkdown = <String>[];
  final List<(String, String)> scaffoldedPlugins = <(String, String)>[];
  final List<(String, String, String)> forkedPlugins =
      <(String, String, String)>[];
  final List<String> validatedPlugins = <String>[];
  final List<(String, String)> reloadedPlugins = <(String, String)>[];
  final Map<String, String> pluginSecrets = <String, String>{};
  final List<String> removedPluginSecrets = <String>[];
  int refreshes = 0;
  bool closed = false;
  bool relayEnabled = false;
  bool failPluginValidation = false;
  final List<String> revokedDevices = <String>[];

  @override
  ProvidersApi get providers => this;

  @override
  AgentsApi get agents => this;

  @override
  PluginsApi get plugins => this;

  @override
  RelayApi get relay => this;

  @override
  Stream<RelayStatusDto> get statusUpdates => const Stream.empty();

  RelayStatusDto get _relayStatus => RelayStatusDto(
    enabled: relayEnabled,
    connected: relayEnabled,
    endpoint: 'wss://relay.tinest.tinyrack.net/v1/ws',
    serverId: 'server-1',
  );

  @override
  Future<RelayStatusDto> getRelayStatus() async => _relayStatus;

  @override
  Future<RelayStatusDto> setRelayEnabled({required bool enabled}) async {
    relayEnabled = enabled;
    return _relayStatus;
  }

  @override
  Future<RelayPairingOfferDto> createRelayPairingOffer() async =>
      RelayPairingOfferDto(
        url: 'https://tinest.tinyrack.net/pair#offer=test',
        expiresAt: now.add(const Duration(minutes: 10)),
      );

  @override
  Future<List<RelayDeviceDto>> listRelayDevices() async => <RelayDeviceDto>[
    RelayDeviceDto(
      id: 'device-1',
      name: 'Test phone',
      registeredAt: now,
      lastConnectedAt: now,
    ),
  ];

  @override
  Future<void> revokeRelayDevice(String deviceId) async {
    revokedDevices.add(deviceId);
  }

  ProviderConnectionDto _connection(String id, String name) =>
      ProviderConnectionDto(
        id: id,
        definitionId: id,
        displayName: name,
        status: ProviderConnectionStatus.connected,
        authKind: ProviderAuthKind.apiKey,
        credentialOrigin: ProviderCredentialOrigin.stored,
        createdAt: now,
        updatedAt: now,
      );

  AgentDefinitionDto _definition(String id) => AgentDefinitionDto(
    version: 5,
    id: id,
    name: id,
    description: '',
    mode: AgentMode.primary,
    model: const AgentModelSelectionDto(source: AgentModelSource.session),
    driverId: 'tinest.standard/driver',
    extensionIds: const <String>[],
    toolIds: const <String>[],
    pluginSettings: const <String, Map<String, dynamic>>{},
    callableAgentIds: const <String>[],
    prompt: 'prompt',
    contentHash: 'hash',
    sourcePath: '/config/agents/$id.md',
    isBuiltIn: id == 'tinest',
  );

  PluginDescriptorDto _plugin(String id) => PluginDescriptorDto(
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
    scaffoldedPlugins.add((id, name));
    return _plugin(id);
  }

  @override
  Future<PluginDescriptorDto> forkPlugin({
    required String sourceId,
    required String id,
    required String name,
  }) async {
    forkedPlugins.add((sourceId, id, name));
    return _plugin(id);
  }

  @override
  Future<PluginDescriptorDto> validatePlugin(String id) async {
    validatedPlugins.add(id);
    if (failPluginValidation) {
      throw const TinestClientException(
        'Plugin source is invalid.',
        code: 'invalid_plugin',
      );
    }
    return _plugin(id);
  }

  @override
  Future<PluginDescriptorDto> reloadPlugin(String id, String agentId) async {
    reloadedPlugins.add((id, agentId));
    return _plugin(id);
  }

  @override
  Future<PluginAuthoringEnvironmentDto> getPluginAuthoringEnvironment(
    String id,
  ) async => _authoring(id);

  @override
  Future<PluginAuthoringEnvironmentDto> syncPluginAuthoringEnvironment(
    String id,
  ) async => _authoring(id);

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

  @override
  Future<void> setPluginSecret({
    required String agentId,
    required String pluginId,
    required String name,
    required String value,
  }) async {
    pluginSecrets['$pluginId/$agentId/$name'] = value;
  }

  @override
  Future<void> removePluginSecret({
    required String agentId,
    required String pluginId,
    required String name,
  }) async {
    removedPluginSecrets.add('$pluginId/$agentId/$name');
  }

  @override
  Future<ProviderCatalogDto> listProviderCatalog() async => ProviderCatalogDto(
    definitions: const <ProviderDefinitionDto>[
      ProviderDefinitionDto(
        id: 'openai',
        name: 'OpenAI',
        description: 'OpenAI',
        authMethods: <ProviderAuthMethodDto>[
          ProviderAuthMethodDto(
            id: 'api-key',
            label: 'API key',
            kind: ProviderAuthKind.apiKey,
            flow: ProviderAuthFlow.apiKey,
          ),
        ],
      ),
      ProviderDefinitionDto(
        id: 'deepseek',
        name: 'DeepSeek',
        description: 'Hosted',
        authMethods: <ProviderAuthMethodDto>[
          ProviderAuthMethodDto(
            id: 'api-key',
            label: 'API key',
            kind: ProviderAuthKind.apiKey,
            flow: ProviderAuthFlow.apiKey,
          ),
        ],
      ),
      ProviderDefinitionDto(
        id: 'ollama',
        name: 'Ollama',
        description: 'Local',
        local: true,
        authMethods: <ProviderAuthMethodDto>[
          ProviderAuthMethodDto(
            id: 'none',
            label: 'Connect',
            kind: ProviderAuthKind.none,
            flow: ProviderAuthFlow.none,
          ),
        ],
      ),
    ],
    source: ProviderCatalogSource.bundled,
    updatedAt: now,
  );

  @override
  Future<List<ProviderConnectionDto>> listProviderConnections() async =>
      <ProviderConnectionDto>[_connection('openai', 'OpenAI')];

  @override
  Future<List<ProviderUsageDto>> listProviderUsage() async =>
      const <ProviderUsageDto>[];

  @override
  Future<ProviderConnectionDto> connectProviderApiKey(
    String definitionId,
    String apiKey, {
    String? connectionId,
    String? modelPrefix,
  }) async {
    apiKeys[definitionId] = apiKey;
    return _connection(definitionId, definitionId);
  }

  @override
  Future<ProviderConnectionDto> connectProviderNone(
    String definitionId, {
    String? connectionId,
    String? modelPrefix,
  }) async {
    noneConnections.add(definitionId);
    return _connection(definitionId, definitionId);
  }

  @override
  Future<void> disconnectProvider(String connectionId) async {
    disconnected.add(connectionId);
  }

  @override
  Future<ProviderCatalogDto> refreshProviderCatalog() async {
    refreshes += 1;
    return await listProviderCatalog();
  }

  @override
  Future<List<AgentDefinitionDto>> listAgentDefinitions() async =>
      <AgentDefinitionDto>[_definition('tinest')];

  @override
  Future<AgentDefinitionDto> validateAgentDefinition(
    String id,
    String markdown,
  ) async {
    validatedMarkdown.add(markdown);
    return _definition(id);
  }

  @override
  Future<AgentDefinitionDto> createAgentDefinition(
    String id,
    AgentDefinitionDto definition,
  ) async {
    created.add(id);
    return definition;
  }

  @override
  Future<void> archiveAgentDefinition(String id) async {
    archived.add(id);
  }

  @override
  Future<AgentDefinitionDto> resetAgentDefinition(String id) async {
    reset.add(id);
    return _definition(id);
  }

  @override
  Future<void> close() async {
    closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
