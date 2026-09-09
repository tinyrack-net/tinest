import 'package:cli/cli.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 2);

  test('list prints safe connection metadata', () async {
    final backend = _Backend(now);
    final output = StringBuffer();

    final exitCode = await providerList(backend: backend, output: output);

    expect(exitCode, 0);
    expect(output.toString(), contains('OpenAI'));
    expect(output.toString(), contains('connected'));
    expect(output.toString(), isNot(contains('https://')));
  });

  test('connect supports API key, local, and OAuth service flows', () async {
    final backend = _Backend(now);
    final output = StringBuffer();

    expect(
      await providerConnect(
        backend: backend,
        output: output,
        definitionId: 'deepseek',
        methodId: 'api-key',
        readSecret: () async => 'secret',
      ),
      0,
    );
    expect(backend.apiKeys['deepseek'], 'secret');

    expect(
      await providerConnect(
        backend: backend,
        output: output,
        definitionId: 'ollama',
      ),
      0,
    );
    expect(backend.noneConnections, contains('ollama'));

    expect(
      await providerConnect(
        backend: backend,
        output: output,
        definitionId: 'openai',
        methodId: 'chatgpt-device',
      ),
      0,
    );
    expect(output.toString(), contains('CODE-1234'));
    expect(backend.statusCalls, 1);
  });

  test('an inline API key skips the interactive prompt', () async {
    final backend = _Backend(now);
    final output = StringBuffer();

    expect(
      await providerConnect(
        backend: backend,
        output: output,
        definitionId: 'deepseek',
        apiKey: 'inline',
        readSecret: () async => fail('the prompt must not run'),
      ),
      0,
    );
    expect(backend.apiKeys['deepseek'], 'inline');
  });

  test('disconnect and explicit catalog refresh are routed', () async {
    final backend = _Backend(now);
    final output = StringBuffer();

    expect(
      await providerDisconnect(
        backend: backend,
        output: output,
        connectionId: 'openai',
      ),
      0,
    );
    expect(backend.disconnected, <String>['openai']);
    expect(await providerCatalogRefresh(backend: backend, output: output), 0);
    expect(backend.refreshes, 1);
  });

  test('an empty connection list says so', () async {
    final backend = _Backend(now)..emptyConnections = true;
    final output = StringBuffer();

    expect(await providerList(backend: backend, output: output), 0);
    expect(output.toString(), contains('No provider connections.'));
  });

  test('an unknown provider fails before mutating the backend', () async {
    final backend = _Backend(now);
    final output = StringBuffer();

    await expectLater(
      providerConnect(
        backend: backend,
        output: output,
        definitionId: 'missing',
      ),
      throwsA(isA<StateError>()),
    );
    expect(backend.apiKeys, isEmpty);
    expect(backend.noneConnections, isEmpty);
  });

  test('a hosted provider without a secret source fails', () async {
    final backend = _Backend(now);
    final output = StringBuffer();

    await expectLater(
      providerConnect(
        backend: backend,
        output: output,
        definitionId: 'deepseek',
      ),
      throwsA(isA<StateError>()),
    );
    expect(backend.apiKeys, isEmpty);
  });

  test('OAuth terminal failures return a non-zero result', () async {
    final backend = _Backend(now)
      ..authResult = ProviderAuthAttemptStatus.failed
      ..authError = 'authorization rejected';
    final output = StringBuffer();
    final progress = _RecordingProgress();

    expect(
      await providerConnect(
        backend: backend,
        output: output,
        definitionId: 'openai',
        methodId: 'chatgpt-browser',
        progress: progress,
        pollInterval: Duration.zero,
      ),
      1,
    );
    expect(output.toString(), contains('authorization rejected'));
    expect(progress.events.first, startsWith('start:'));
    expect(progress.events.last, 'fail:authorization rejected');
  });

  test('a successful OAuth flow reports progress as succeeded', () async {
    final backend = _Backend(now);
    final output = StringBuffer();
    final progress = _RecordingProgress();

    expect(
      await providerConnect(
        backend: backend,
        output: output,
        definitionId: 'openai',
        methodId: 'chatgpt-device',
        progress: progress,
        pollInterval: Duration.zero,
      ),
      0,
    );
    expect(progress.events, <String>[
      'start:Waiting for authorization',
      'succeed:Authorized',
    ]);
  });

  test('catalog refresh reports progress', () async {
    final backend = _Backend(now);
    final progress = _RecordingProgress();

    await providerCatalogRefresh(
      backend: backend,
      output: StringBuffer(),
      progress: progress,
    );

    expect(progress.events, <String>[
      'start:Refreshing the provider catalog',
      'succeed:Provider catalog refreshed',
    ]);
  });

  test('the silent reporter records nothing and throws nothing', () {
    const progress = SilentCliProgress();

    expect(() {
      progress
        ..start('a')
        ..succeed('b')
        ..fail('c');
    }, returnsNormally);
  });
}

final class _RecordingProgress implements CliProgress {
  final List<String> events = <String>[];

  @override
  void start(String message) => events.add('start:$message');

  @override
  void succeed(String message) => events.add('succeed:$message');

  @override
  void fail(String message) => events.add('fail:$message');
}

final class _Backend implements ProviderCliBackend {
  new(this.now);

  final DateTime now;
  final Map<String, String> apiKeys = <String, String>{};
  final List<String> noneConnections = <String>[];
  final List<String> disconnected = <String>[];
  int refreshes = 0;
  int statusCalls = 0;
  bool emptyConnections = false;
  ProviderAuthAttemptStatus authResult = ProviderAuthAttemptStatus.succeeded;
  String? authError;

  ProviderConnectionDto connection(String id, String name) =>
      ProviderConnectionDto(
        id: id,
        definitionId: id,
        modelPrefix: id,
        displayName: name,
        status: ProviderConnectionStatus.connected,
        authKind: ProviderAuthKind.apiKey,
        credentialOrigin: ProviderCredentialOrigin.stored,
        createdAt: now,
        updatedAt: now,
      );

  @override
  Future<ProviderConnectionDto> connectApiKey(
    String definitionId,
    String apiKey, {
    String? modelPrefix,
  }) async {
    apiKeys[definitionId] = apiKey;
    return connection(definitionId, definitionId);
  }

  @override
  Future<ProviderConnectionDto> connectNone(
    String definitionId, {
    String? modelPrefix,
  }) async {
    noneConnections.add(definitionId);
    return connection(definitionId, definitionId);
  }

  @override
  Future<void> disconnect(String connectionId) async {
    disconnected.add(connectionId);
  }

  @override
  Future<ProviderCatalogDto> catalog() async => ProviderCatalogDto(
    definitions: const <ProviderDefinitionDto>[
      ProviderDefinitionDto(
        id: 'openai',
        name: 'OpenAI',
        description: 'OpenAI',
        authMethods: <ProviderAuthMethodDto>[
          ProviderAuthMethodDto(
            id: 'chatgpt-browser',
            label: 'Sign in with ChatGPT',
            kind: ProviderAuthKind.oauth,
            flow: ProviderAuthFlow.oauthBrowser,
          ),
          ProviderAuthMethodDto(
            id: 'chatgpt-device',
            label: 'Sign in with device code',
            kind: ProviderAuthKind.oauth,
            flow: ProviderAuthFlow.oauthDevice,
          ),
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
  Future<List<ProviderConnectionDto>> connections() async => emptyConnections
      ? <ProviderConnectionDto>[]
      : <ProviderConnectionDto>[connection('openai', 'OpenAI')];

  @override
  Future<ProviderCatalogDto> refreshCatalog() async {
    refreshes += 1;
    return await catalog();
  }

  @override
  Future<ProviderAuthAttemptDto> startAuth(
    String definitionId,
    String methodId, {
    String? modelPrefix,
  }) async {
    return ProviderAuthAttemptDto(
      id: 'attempt',
      definitionId: definitionId,
      methodId: methodId,
      status: ProviderAuthAttemptStatus.awaitingUser,
      authorizationUrl: 'https://auth.example/device',
      userCode: 'CODE-1234',
    );
  }

  @override
  Future<ProviderAuthAttemptDto> authStatus(String attemptId) async {
    statusCalls += 1;
    return ProviderAuthAttemptDto(
      id: 'attempt',
      definitionId: 'openai',
      methodId: 'chatgpt-device',
      status: authResult,
      error: authError,
    );
  }

  @override
  Future<ProviderConnectionDto> updateModelPrefix(
    String connectionId,
    String modelPrefix,
  ) async =>
      connection(connectionId, connectionId).copyWith(modelPrefix: modelPrefix);
}
