@Tags(<String>['feature_test__provider_catalog__unit'])
library;

import 'package:agent/agent.dart';
import 'package:test/test.dart';

import 'support/conformance.dart';

void main() {
  providerAdapterConformanceTests('a well-formed adapter', _FakeAdapter.new);

  providerWireProtocolConformanceTests('a well-formed wire', _FakeWire.new);

  test('the registry rejects two adapters claiming one id', () {
    expect(
      () => ProviderRegistry(
        adapters: <ProviderAdapter>[_FakeAdapter(), _FakeAdapter()],
        wireProtocols: const <ProviderWireProtocol>[],
      ),
      throwsStateError,
    );
  });

  test('the registry rejects an adapter advertising a different id', () {
    expect(
      () => ProviderRegistry(
        adapters: <ProviderAdapter>[_MislabelledAdapter()],
        wireProtocols: const <ProviderWireProtocol>[],
      ),
      throwsStateError,
    );
  });

  test('the registry rejects two wires claiming one id', () {
    expect(
      () => ProviderRegistry(
        adapters: const <ProviderAdapter>[],
        wireProtocols: <ProviderWireProtocol>[_FakeWire(), _FakeWire()],
      ),
      throwsStateError,
    );
  });

  test('lookups distinguish absence from a wrong id', () {
    final registry = ProviderRegistry(
      adapters: <ProviderAdapter>[_FakeAdapter()],
      wireProtocols: <ProviderWireProtocol>[_FakeWire()],
    );

    expect(registry.find('fake'), isNotNull);
    expect(registry.find('missing'), isNull);
    expect(() => registry.require('missing'), throwsStateError);
    expect(registry.require('fake').id, 'fake');
    expect(registry.findWire('fake-wire'), isNotNull);
    expect(registry.findWire('missing'), isNull);
    expect(() => registry.requireWire('missing'), throwsStateError);
    expect(registry.requireWire('fake-wire').id, 'fake-wire');
  });

  test('adapter defaults advertise nothing they do not implement', () {
    final adapter = _FakeAdapter();
    expect(adapter.oauth, isNull);
    const remote = AgentModelCapabilities(
      streaming: AgentCapabilitySupport.supported,
      toolCalling: AgentCapabilitySupport.supported,
    );
    expect(identical(adapter.refineRemoteCapabilities(remote), remote), isTrue);
    expect(
      identical(
        adapter.capabilitiesForAuth(remote, AgentProviderAuthKind.apiKey),
        remote,
      ),
      isTrue,
    );
  });

  test('provider failures retain stable classifications and safe messages', () {
    const discovery = ProviderDiscoveryFailure(
      ProviderDiscoveryFailureKind.invalidCredential,
      'Credential rejected.',
    );
    const refresh = OAuthRefreshFailure(
      'Refresh token expired.',
      reauthRequired: true,
    );
    const authorization = OAuthAuthorizationFailure('Authorization cancelled.');

    expect(discovery.kind, ProviderDiscoveryFailureKind.invalidCredential);
    expect(discovery.message, 'Credential rejected.');
    expect(
      discovery.toString(),
      'ProviderDiscoveryFailure('
      'ProviderDiscoveryFailureKind.invalidCredential): Credential rejected.',
    );
    expect(refresh.reauthRequired, isTrue);
    expect(refresh.toString(), 'OAuthRefreshFailure: Refresh token expired.');
    expect(authorization.toString(), 'Authorization cancelled.');
  });

  test('OAuth credentials retain optional vendor account identity', () {
    final expiresAt = DateTime.utc(2030);
    final withAccount = OAuthCredential(
      accessToken: 'access-one',
      refreshToken: 'refresh-one',
      expiresAt: expiresAt,
      accountId: 'account-one',
    );
    final withoutAccount = OAuthCredential(
      accessToken: 'access-two',
      refreshToken: 'refresh-two',
      expiresAt: expiresAt,
    );

    expect(withAccount.accountId, 'account-one');
    expect(withAccount.expiresAt, expiresAt);
    expect(withoutAccount.accountId, isNull);
  });

  test('an adapter reads the public catalog unless it opts out', () {
    expect(_FakeAdapter().usesRemoteCatalog, isTrue);
    expect(_BundledOnlyAdapter().usesRemoteCatalog, isFalse);
  });
}

final class _FakeWire implements ProviderWireProtocol {
  @override
  String get id => 'fake-wire';

  @override
  String get label => 'Fake wire';

  @override
  List<AgentModelControlDescriptor> get controlDescriptors => const [];

  @override
  ModelGateway createProvider(ModelGatewayRequest request) =>
      _FakeModelGateway(request.connectionId);

  @override
  Future<List<String>> discoverModels(
    ProviderEndpoint endpoint,
    ProviderCredential? credential,
  ) async => const <String>['fake-model'];
}

final class _FakeAdapter extends ProviderAdapter {
  @override
  String get id => 'fake';

  @override
  AgentProviderDefinition get definition => const AgentProviderDefinition(
    id: 'fake',
    name: 'Fake',
    description: 'A vendor used by the conformance suite.',
    authMethods: <AgentProviderAuthMethod>[
      AgentProviderAuthMethod(
        id: 'api-key',
        label: 'API key',
        kind: AgentProviderAuthKind.apiKey,
        flow: AgentProviderAuthFlow.apiKey,
      ),
    ],
    recommendedModelIds: <String>['fake-model'],
  );

  @override
  List<ProviderCatalogModel> get models => const <ProviderCatalogModel>[
    ProviderCatalogModel(
      id: 'fake-model',
      label: 'Fake Model',
      capabilities: AgentModelCapabilities(
        streaming: AgentCapabilitySupport.supported,
        toolCalling: AgentCapabilitySupport.supported,
      ),
    ),
  ];

  @override
  ProviderEndpoint endpoint(AgentProviderAuthKind authKind) =>
      const ProviderEndpoint(baseUrl: 'https://fake.example/v1');

  @override
  ModelGateway createProvider(ModelGatewayRequest request) =>
      _FakeModelGateway(request.connectionId);

  @override
  Future<List<String>> discoverModels(
    ProviderEndpoint endpoint,
    ProviderCredential? credential,
  ) async => const <String>['fake-model'];
}

final class _MislabelledAdapter extends _FakeAdapter {
  @override
  String get id => 'someone-else';
}

final class _BundledOnlyAdapter extends _FakeAdapter {
  @override
  bool get usesRemoteCatalog => false;
}

final class _FakeModelGateway implements ModelGateway {
  const new(this.id);

  @override
  final String id;

  @override
  Stream<ModelEvent> stream(ModelRequest request, CancellationToken token) =>
      const Stream<ModelEvent>.empty();
}
