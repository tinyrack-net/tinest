import 'dart:async';

import 'package:agent/agent.dart';
import 'package:app/testing/app/tinest_app.dart';
import 'package:daemon/daemon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';

import 'support/pump_until.dart';
import 'support/real_daemon_fixture.dart';
import 'support/tap_visible.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'catalog failure remains visible and a retry refreshes daemon metadata',
    (tester) async {
      final metadata = _RetryingMetadataSource();
      final fixture = await RealDaemonFixture.start(
        id: 'provider-catalog',
        providerCatalogMetadataSource: metadata,
      );
      addTearDown(fixture.dispose);
      final assertions = await fixture.connect();
      addTearDown(assertions.close);

      await _pumpProviderSettings(tester, fixture);
      await tester.tap(
        find.byKey(const ValueKey<String>('provider-add-button')),
      );
      await tester.pumpAndSettle();
      final refresh = find.byKey(
        const ValueKey<String>('provider-catalog-refresh'),
      );

      expect(find.textContaining('Catalog refresh failed'), findsOneWidget);
      expect(find.textContaining('planned catalog outage'), findsNothing);
      expect(metadata.calls, 1);
      expect(
        (await assertions.providers.listProviderCatalog()).source,
        ProviderCatalogSource.bundled,
      );

      await tester.tap(refresh);
      await tester.pumpAndSettle();
      expect(find.textContaining('Catalog refresh failed'), findsNothing);
      expect(metadata.calls, 2);
      expect(
        (await assertions.providers.listProviderCatalog()).source,
        ProviderCatalogSource.refreshed,
      );
      expect(
        (await assertions.providers.refreshProviderCatalog()).source,
        ProviderCatalogSource.refreshed,
      );
    },
    tags: const <String>[
      'feature_scenario__provider_catalog__catalog_failure_retry__e2e',
    ],
  );

  testWidgets(
    'OAuth recovers from failure and cancellation before connecting',
    (tester) async {
      final oauth = _ControlledOAuthGateway();
      final fixture = await RealDaemonFixture.start(
        id: 'provider-oauth',
        modelDiscovery: const _StaticModelDiscovery(),
        oauthGateway: oauth,
        providerCatalogMetadataSource: _SuccessfulMetadataSource(),
      );
      addTearDown(fixture.dispose);
      final assertions = await fixture.connect();
      addTearDown(assertions.close);

      await _pumpProviderSettings(tester, fixture);

      await _startDeviceOAuth(tester);
      oauth.sessions.single.fail('planned authorization failure');
      await pumpUntilCondition(
        tester,
        () => find
            .textContaining('planned authorization failure')
            .evaluate()
            .isNotEmpty,
        'the failed authorization message',
      );
      // The failure text can paint one frame before the terminal attempt
      // action replaces Cancel. Wait for the retry contract before starting
      // the next authorization attempt.
      await pumpUntil(
        tester,
        find.byKey(const ValueKey<String>('provider-auth-retry')),
      );
      // The tile shows the reason itself, never a transport exception name.
      expect(find.textContaining('Exception'), findsNothing);

      await _startDeviceOAuth(tester);
      final cancelled = oauth.sessions.last;
      final cancel = _authCancelButton();
      expect(cancel, findsOneWidget);
      await tester.tap(cancel);
      await pumpUntilCondition(
        tester,
        () => cancelled.cancelled,
        'the cancelled device authorization to report it',
      );
      expect(cancelled.cancelled, isTrue);

      await _startDeviceOAuth(tester);
      oauth.sessions.last.succeed(
        OAuthCredential(
          accessToken: 'oauth-access-token',
          refreshToken: 'oauth-refresh-token',
          expiresAt: DateTime.utc(2026, 8, 5, 13),
          accountId: 'e2e-account',
        ),
      );
      await pumpUntilCondition(tester, () async {
        final connections = await assertions.providers
            .listProviderConnections();
        return connections.any(
          (connection) =>
              connection.definitionId == 'openai' &&
              connection.status == ProviderConnectionStatus.connected,
        );
      }, 'the OAuth connection to report connected');

      final connection = (await assertions.providers.listProviderConnections())
          .singleWhere((item) => item.definitionId == 'openai');
      expect(connection.credentialOrigin, ProviderCredentialOrigin.oauth);
      expect(connection.status, ProviderConnectionStatus.connected);
      // The ChatGPT endpoint has no `/models` listing, so the connected
      // catalog is the bundled one and discovery never runs.
      final oauthModels = (await assertions.providers.listProviderModels(
        connection.id,
      )).map((model) => model.id);
      expect(oauthModels, contains('${connection.modelPrefix}/gpt-5.6-sol'));
      expect(oauthModels, isNot(contains('oauth-e2e-model')));

      await tester.tap(
        find.byKey(const ValueKey<String>('provider-add-button')),
      );
      final activeCatalogRefresh = find
          .byKey(const ValueKey<String>('provider-catalog-refresh'))
          .hitTestable();
      await pumpUntil(tester, activeCatalogRefresh);
      await tester.tap(activeCatalogRefresh);
      await tester.pumpAndSettle();
      expect(
        (await assertions.providers.listProviderCatalog()).source,
        ProviderCatalogSource.refreshed,
      );
    },
    tags: const <String>[
      'feature_scenario__provider_oauth__authorize_and_refresh__e2e',
      'feature_scenario__provider_oauth__cancel_and_error_recovery__e2e',
    ],
  );
}

Future<void> _pumpProviderSettings(
  WidgetTester tester,
  RealDaemonFixture fixture,
) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  tester.binding.platformDispatcher.localeTestValue = const Locale('en');
  addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
  await tester.pumpWidget(TinestApp(services: fixture.services));
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpAndSettle();
  await tapVisible(
    tester,
    find.byKey(const ValueKey<String>('workspace-settings-button')),
    'the workspace settings button',
  );
  await tester.pumpAndSettle();
  final providerCategory = find.byKey(
    const ValueKey<String>('settings-category-row-provider'),
  );
  await pumpUntil(tester, providerCategory);
  await tester.tap(providerCategory);
  await tester.pumpAndSettle();
}

Future<void> _startDeviceOAuth(WidgetTester tester) async {
  final retry = find.byKey(const ValueKey<String>('provider-auth-retry'));
  if (retry.evaluate().isNotEmpty) {
    await tester.tap(retry);
    await tester.pumpAndSettle();
  } else {
    final preset = find.byKey(const ValueKey<String>('provider-add-openai'));
    if (preset.evaluate().isEmpty) {
      await tester.tap(
        find.byKey(const ValueKey<String>('provider-add-button')),
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(preset);
    await tester.pumpAndSettle();
  }
  expect(
    find.byKey(const ValueKey<String>('provider-model-prefix')),
    findsOneWidget,
  );
  await tester.tap(find.byKey(const ValueKey<String>('provider-auth-method')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const ValueKey<String>('provider-auth-method-chatgpt-device')),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const ValueKey<String>('provider-connect-submit')),
  );
  await tester.pump();
  await pumpUntilCondition(
    tester,
    () => _authCancelButton().evaluate().isNotEmpty,
    'the device authorization prompt',
  );
}

Finder _authCancelButton() => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> &&
      key.value.startsWith('provider-auth-cancel-');
});

final class _RetryingMetadataSource implements ProviderCatalogMetadataSource {
  int calls = 0;

  @override
  Future<void> close() async {}

  @override
  Future<Map<String, List<ProviderCatalogMetadata>>> fetch(
    Set<String> providerIds,
  ) async {
    calls += 1;
    if (calls == 1) throw StateError('planned catalog outage');
    return _metadata(providerIds);
  }
}

final class _SuccessfulMetadataSource implements ProviderCatalogMetadataSource {
  @override
  Future<void> close() async {}

  @override
  Future<Map<String, List<ProviderCatalogMetadata>>> fetch(
    Set<String> providerIds,
  ) async => _metadata(providerIds);
}

Map<String, List<ProviderCatalogMetadata>> _metadata(Set<String> providerIds) =>
    <String, List<ProviderCatalogMetadata>>{
      if (providerIds.contains('openai'))
        'openai': const <ProviderCatalogMetadata>[
          ProviderCatalogMetadata(
            id: 'refreshed-e2e-model',
            label: 'Refreshed E2E model',
            capabilities: ModelCapabilitiesDto(
              streaming: CapabilitySupport.supported,
              toolCalling: CapabilitySupport.supported,
              controls: <ModelControlDescriptorDto>[
                ModelControlDescriptorDto(
                  id: 'reasoning_effort',
                  label: 'Reasoning effort',
                  kind: ModelControlKind.choice,
                  presentation: ModelControlPresentation.menuChip,
                ),
              ],
              source: CapabilitySource.refreshed,
            ),
          ),
        ],
    };

final class _StaticModelDiscovery implements ProviderModelDiscovery {
  const new();

  @override
  Future<List<String>> fetchModelIds(
    ProviderEndpoint endpoint,
    ProviderCredential? credential,
  ) async => const <String>['oauth-e2e-model'];
}

final class _ControlledOAuthGateway implements ProviderOAuthGateway {
  final List<_ControlledOAuthSession> sessions = <_ControlledOAuthSession>[];

  @override
  Future<OAuthCredential> refresh(OAuthCredential credential) async =>
      credential;

  @override
  Future<ProviderOAuthSession> start(AgentProviderAuthFlow flow) async {
    final session = _ControlledOAuthSession(flow);
    sessions.add(session);
    return session;
  }
}

final class _ControlledOAuthSession implements ProviderOAuthSession {
  new(this.flow);

  final AgentProviderAuthFlow flow;
  final Completer<({OAuthCredential? credential, String? error})> _result =
      Completer<({OAuthCredential? credential, String? error})>();
  bool cancelled = false;

  void fail(String message) =>
      _result.complete((credential: null, error: message));

  void succeed(OAuthCredential credential) =>
      _result.complete((credential: credential, error: null));

  @override
  String get authorizationUrl => 'https://auth.invalid/${flow.name}';

  @override
  Future<OAuthCredential> get completion async {
    final result = await _result.future;
    // Mirrors the real gateway, which reports a plain sentence rather than a
    // transport exception the user cannot act on.
    if (result.error case final error?) throw OAuthAuthorizationFailure(error);
    return result.credential!;
  }

  @override
  DateTime get expiresAt => DateTime.utc(2026, 8, 5, 13);

  @override
  String? get instructions => 'Complete deterministic authorization.';

  @override
  String? get userCode => 'E2E-CODE';

  @override
  Future<void> cancel() async {
    cancelled = true;
    if (!_result.isCompleted) {
      _result.complete((credential: null, error: 'authorization cancelled'));
    }
  }
}
