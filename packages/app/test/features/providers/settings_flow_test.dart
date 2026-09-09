import 'dart:async';

import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/app/composition/app_services.dart';
import 'package:app/src/app/platform/external_url_opener.dart';
import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/hosts/domain/host_ports.dart';
import 'package:app/src/shared/presentation/settings_layout.dart';
import 'package:client/client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/fake_tinest_api.dart';
import '../../support/localization.dart';

void main() {
  testWidgets('configured providers occupy the collection pane', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    await _pumpSettings(tester, FakeTinestApi());

    expect(
      find.byKey(const ValueKey<String>('provider-connection-openai')),
      findsOneWidget,
    );
    expect(find.byType(TRTreeNav<String>), findsOneWidget);
    expect(find.byKey(const ValueKey('provider-add-openai')), findsNothing);
    await tester.tap(find.byKey(const ValueKey<String>('provider-add-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('provider-add-openai')), findsOneWidget);
    expect(find.byType(TRAlertDialog), findsNothing);
  }, tags: const <String>['feature_test__provider_catalog__widget']);

  testWidgets(
    'API key and prefix stay inline in the third pane',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(1200, 900);
      addTearDown(tester.view.reset);
      final api = FakeTinestApi(connections: <ProviderConnectionDto>[]);
      await _pumpSettings(tester, api);

      await _openCatalog(tester);
      await tester.tap(find.byKey(const ValueKey('provider-add-deepseek')));
      await tester.pumpAndSettle();
      expect(_field('모델 Prefix'), findsOneWidget);
      expect(_field('API 키'), findsOneWidget);
      expect(find.byType(TRAlertDialog), findsNothing);

      final save = find.byKey(
        const ValueKey<String>('provider-connect-submit'),
      );
      expect(
        find.ancestor(of: save, matching: find.byType(SettingsFormActions)),
        findsOneWidget,
      );

      await tester.enterText(_field('API 키'), 'deepseek-secret');
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('provider-connect-submit')),
      );
      await tester.pumpAndSettle();
      expect(api.credentials['deepseek'], 'deepseek-secret');
      expect(
        find.byKey(const ValueKey<String>('provider-connection-deepseek')),
        findsOneWidget,
      );
    },
    tags: const <String>[
      'feature_test__provider_connection_management__widget',
    ],
  );

  testWidgets('OAuth keeps progress and browser recovery in the detail pane', (
    tester,
  ) async {
    final api = FakeTinestApi(connections: <ProviderConnectionDto>[]);
    final opener = _ExternalUrlOpener();
    await _pumpSettings(tester, api, externalUrlOpener: opener);

    await _openCatalog(tester);
    await tester.tap(find.byKey(const ValueKey('provider-add-openai')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('provider-connect-submit')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('로그인 대기 중'), findsWidgets);
    expect(find.textContaining('auth.example'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('provider-oauth-open-browser')),
      findsOneWidget,
    );
    expect(opener.opened, hasLength(1));
    await tester.tap(
      find.byKey(const ValueKey<String>('provider-oauth-open-browser')),
    );
    await tester.pump();
    expect(opener.opened, hasLength(2));
    await tester.tap(
      find.byKey(const ValueKey<String>('provider-auth-cancel-attempt')),
    );
    await tester.pump();
    expect(api.cancelledAuthAttempts, <String>['attempt']);
    expect(find.byType(TRAlertDialog), findsNothing);
  }, tags: const <String>['feature_test__provider_oauth__widget']);

  testWidgets('OAuth browser failures use the shared danger alert', (
    tester,
  ) async {
    final api = FakeTinestApi(connections: <ProviderConnectionDto>[]);
    final opener = _ExternalUrlOpener(result: false);
    await _pumpSettings(tester, api, externalUrlOpener: opener);

    await _openCatalog(tester);
    await tester.tap(find.byKey(const ValueKey('provider-add-openai')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('provider-connect-submit')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final alert = find.byKey(
      const ValueKey<String>('provider-oauth-open-error'),
    );
    expect(alert, findsOneWidget);
    expect(tester.widget<TRAlert>(alert).variant, TRStatusVariant.danger);
    expect(
      find.ancestor(of: alert, matching: find.byType(SettingsRow)),
      findsNothing,
    );
    expect(find.text('인증 페이지를 열 수 없습니다.'), findsOneWidget);
  }, tags: const <String>['feature_test__provider_oauth__widget']);

  testWidgets('custom provider configuration is one inline form', (
    tester,
  ) async {
    await _pumpSettings(
      tester,
      FakeTinestApi(connections: <ProviderConnectionDto>[]),
    );

    await _openCatalog(tester);
    await tester.tap(find.byKey(const ValueKey('provider-add-custom')));
    await tester.pumpAndSettle();

    expect(_field('이름'), findsOneWidget);
    expect(_field('기본 URL'), findsOneWidget);
    expect(_field('모델 Prefix'), findsOneWidget);
    expect(_field('API 키'), findsOneWidget);
    expect(_field('Model ID'), findsOneWidget);
    expect(find.byType(TRAlertDialog), findsNothing);
  }, tags: const <String>['feature_test__provider_custom__widget']);

  testWidgets(
    'connection detail manages prefix without daemon model settings',
    (tester) async {
      final api = FakeTinestApi();
      await _pumpSettings(tester, api);
      await tester.tap(
        find.byKey(const ValueKey<String>('provider-connection-openai')),
      );
      await tester.pumpAndSettle();

      expect(_field('모델 Prefix'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('provider-default-model')),
        findsNothing,
      );
      expect(find.text('데몬 기본 모델'), findsNothing);
      // Save commits the whole record, so it lives in the pinned action bar
      // under the form rather than in the page header.
      final save = find.byKey(const ValueKey<String>('provider-prefix-save'));
      expect(
        find.ancestor(of: save, matching: find.byType(TRPaneHeader)),
        findsNothing,
      );
      expect(
        find.ancestor(of: save, matching: find.byType(SettingsFormActions)),
        findsOneWidget,
      );
      expect(tester.widget<TRButton>(save).intent, TRIntent.primary);
      // Reconnect acts on the connection status, so it sits with it.
      final reconnect = find.byKey(
        const ValueKey<String>('provider-reconnect'),
      );
      expect(
        find.ancestor(of: reconnect, matching: find.byType(TRPaneHeader)),
        findsNothing,
      );
      expect(
        find.ancestor(of: reconnect, matching: find.byType(SettingsSection)),
        findsOneWidget,
      );
      expect(find.widgetWithText(TRButton, testL10n.commonRetry), findsNothing);
      final disconnect = find.byKey(
        const ValueKey<String>('provider-connection-disconnect'),
      );
      await tester.scrollUntilVisible(
        disconnect,
        TRSpacing.fourExtraLarge,
        scrollable: find
            .descendant(
              of: find.byType(SettingsScaffold),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        find.ancestor(of: disconnect, matching: find.byType(TRPaneHeader)),
        findsNothing,
      );
      expect(
        find.ancestor(of: disconnect, matching: find.byType(SettingsSection)),
        findsOneWidget,
      );
      expect(tester.widget<TRButton>(disconnect).intent, TRIntent.danger);
      await tester.tap(disconnect);
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(TRButton, '연결 해제').last;
      expect(tester.widget<TRButton>(confirm).intent, TRIntent.danger);
      await tester.tap(find.widgetWithText(TRButton, '취소').last);
      await tester.pumpAndSettle();
      expect(
        (await api.providers.listProviderConnections()).single.status,
        ProviderConnectionStatus.connected,
      );
    },
    tags: const <String>[
      'feature_test__provider_connection_management__widget',
    ],
  );

  testWidgets('catalog and prefix failures recover inline', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final api = FakeTinestApi(
      connections: <ProviderConnectionDto>[],
      catalogRefreshError: const TinestClientException(
        'planned catalog outage',
        code: 'provider_unavailable',
      ),
      providerConnectError: const TinestClientException(
        'prefix conflict',
        code: 'model_prefix_conflict',
      ),
    );
    await _pumpSettings(tester, api);
    await _openCatalog(tester);

    final refresh = find.byKey(
      const ValueKey<String>('provider-catalog-refresh'),
    );
    await tester.tap(refresh);
    await tester.pumpAndSettle();
    expect(find.textContaining('planned catalog outage'), findsOneWidget);
    await tester.tap(refresh);
    await tester.pumpAndSettle();
    expect(find.textContaining('planned catalog outage'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('provider-add-deepseek')));
    await tester.pumpAndSettle();
    await tester.enterText(_field('API 키'), 'secret');
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('provider-connect-submit')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('이미 사용 중인 모델 Prefix'), findsOneWidget);
    expect(find.textContaining('prefix conflict'), findsNothing);
    expect(
      find.ancestor(
        of: find.textContaining('이미 사용 중인 모델 Prefix'),
        matching: find.byType(TRAlert),
      ),
      findsNothing,
    );
    expect(
      tester.widget<EditableText>(_field('모델 Prefix')).controller.text,
      'deepseek-2',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('provider-connect-submit')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('provider-connection-deepseek')),
      findsOneWidget,
    );
  });

  testWidgets('unexpected provider failures remain pane-level danger alerts', (
    tester,
  ) async {
    final api = FakeTinestApi(
      connections: <ProviderConnectionDto>[],
      providerConnectError: const TinestClientException(
        'planned provider outage',
        code: 'provider_unavailable',
      ),
    );
    await _pumpSettings(tester, api);
    await _openCatalog(tester);
    await tester.tap(find.byKey(const ValueKey('provider-add-deepseek')));
    await tester.pumpAndSettle();
    await tester.enterText(_field('모델 Prefix'), 'deepseek');
    await tester.enterText(_field('API 키'), 'secret');
    await tester.pump();
    final submit = find.byKey(
      const ValueKey<String>('provider-connect-submit'),
    );
    expect(tester.widget<TRButton>(submit).onPressed, isNotNull);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(api.providerConnectError, isNull);
    expect(find.textContaining('planned provider outage'), findsOneWidget);
    final alert = find.ancestor(
      of: find.textContaining('planned provider outage'),
      matching: find.byType(TRAlert),
    );
    expect(alert, findsOneWidget);
    expect(tester.widget<TRAlert>(alert).variant, TRStatusVariant.danger);
  });

  testWidgets('existing connection reauthenticates without duplication', (
    tester,
  ) async {
    final api = FakeTinestApi();
    await _pumpSettings(tester, api);
    await tester.tap(
      find.byKey(const ValueKey<String>('provider-connection-openai')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TRButton, '다시 연결'));
    await tester.pumpAndSettle();

    expect(_field('API 키'), findsOneWidget);
    expect(
      tester.widget<EditableText>(_field('API 키')).controller.text,
      isEmpty,
    );
    await tester.enterText(_field('API 키'), 'replacement-secret');
    await tester.pump();
    expect(
      tester
          .widget<TRButton>(
            find.byKey(const ValueKey<String>('provider-connect-submit')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('provider-connect-submit')),
    );
    await tester.pumpAndSettle();

    expect(api.credentials['openai'], 'replacement-secret');
    expect(await api.providers.listProviderConnections(), hasLength(1));
    expect((await api.providers.listProviderConnections()).single.id, 'openai');
  });

  testWidgets('failed OAuth stays in its pane and returns to the form', (
    tester,
  ) async {
    final events = StreamController<ClientEvent>.broadcast(sync: true);
    addTearDown(events.close);
    final api = FakeTinestApi(
      connections: <ProviderConnectionDto>[],
      eventStream: events.stream,
    );
    await _pumpSettings(tester, api);
    await _openCatalog(tester);
    await tester.tap(find.byKey(const ValueKey('provider-add-openai')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('provider-connect-submit')),
    );
    await tester.pump();
    events.add(
      const ProviderAuthUpdatedClientEvent(
        ProviderAuthAttemptDto(
          id: 'attempt',
          definitionId: 'openai',
          methodId: 'chatgpt-browser',
          status: ProviderAuthAttemptStatus.failed,
          error: 'planned authorization failure',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('planned authorization failure'),
      findsOneWidget,
    );
    expect(find.byType(TRAlertDialog), findsNothing);
    await tester.tap(find.widgetWithText(TRButton, '다시 시도'));
    await tester.pumpAndSettle();
    expect(_field('모델 Prefix'), findsOneWidget);
  });

  testWidgets(
    'each manual model carries the values its own endpoint accepts',
    tags: const <String>['feature_test__provider_custom__widget'],
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(1200, 2400);
      addTearDown(tester.view.reset);
      final api = FakeTinestApi(connections: <ProviderConnectionDto>[]);
      await _pumpSettings(tester, api);
      await _openCatalog(tester);
      await tester.tap(find.byKey(const ValueKey('provider-add-custom')));
      await tester.pumpAndSettle();
      await tester.enterText(_field('이름'), 'Lab');
      await tester.enterText(_field('기본 URL'), 'http://127.0.0.1:9000/v1');
      await tester.enterText(_field('API 키'), 'lab-secret');
      await tester.enterText(_field('Model ID').first, 'fast-model');

      Future<void> addValue(int model, String value) async {
        final field = find
            .descendant(
              of: find.byType(TRMultiCombobox<String>),
              matching: find.byType(EditableText),
            )
            .at(model);
        await tester.enterText(field, value);
        await tester.pumpAndSettle();
        // The value is committed by choosing it: the query itself is the only
        // option, because nothing here knows what the endpoint accepts.
        await tester.tap(find.text(value).last);
        await tester.pumpAndSettle();
        // Selecting keeps the option layer open over the form below it.
        await tester.tap(_field('이름'));
        await tester.pumpAndSettle();
      }

      // Turning the control on asks for values; nothing here can guess them.
      await tester.tap(
        find.byKey(
          const ValueKey<String>('provider-custom-control-0-reasoning_effort'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(find.byType(TRMultiCombobox<String>), findsOneWidget);

      // Saving with an empty menu is refused rather than dropping the control.
      await tester.tap(
        find.byKey(const ValueKey<String>('provider-custom-save')),
      );
      await tester.pumpAndSettle();
      expect(await api.providers.listProviderConnections(), isEmpty);

      await addValue(0, 'quick');
      await tester.tap(
        find.byKey(const ValueKey<String>('provider-custom-add-model')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(_field('Model ID').last, 'deep-model');
      await tester.tap(
        find.byKey(
          const ValueKey<String>('provider-custom-control-1-reasoning_effort'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      await addValue(1, 'deep');

      await tester.tap(
        find.byKey(const ValueKey<String>('provider-custom-save')),
      );
      await tester.pumpAndSettle();

      // Two models behind one base URL, each with its own menu.
      final saved = (await api.providers.listProviderConnections())
          .single
          .customConfig!
          .models;
      expect(
        saved.map(
          (model) => model.controls.single.choices.map((choice) => choice.id),
        ),
        <List<String>>[
          <String>['quick'],
          <String>['deep'],
        ],
      );
    },
  );

  testWidgets('custom provider creates, edits, disconnects, and deletes', (
    tester,
  ) async {
    final api = FakeTinestApi(connections: <ProviderConnectionDto>[]);
    await _pumpSettings(tester, api);
    await _openCatalog(tester);
    await tester.tap(find.byKey(const ValueKey('provider-add-custom')));
    await tester.pumpAndSettle();
    expect(find.text('Custom Provider 고급 설정'), findsOneWidget);
    final create = find.byKey(const ValueKey<String>('provider-custom-save'));
    expect(
      find.ancestor(of: create, matching: find.byType(SettingsFormActions)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: create, matching: find.text('생성')),
      findsOneWidget,
    );

    await tester.enterText(_field('이름'), 'Lab');
    await tester.enterText(_field('기본 URL'), 'http://127.0.0.1:9000/v1');
    await tester.enterText(_field('API 키'), 'lab-secret');
    await tester.enterText(_field('Model ID').first, 'model-a');
    await tester.tap(
      find.byKey(const ValueKey<String>('provider-custom-add-model')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(_field('Model ID').last, 'model-b');
    await tester.tap(
      find.byKey(const ValueKey<String>('provider-custom-save')),
    );
    await tester.pumpAndSettle();
    expect(
      (await api.providers.listProviderConnections()).single.displayName,
      'Lab',
    );
    expect(
      find.byKey(const ValueKey<String>('provider-custom-save')),
      findsOneWidget,
    );

    await tester.enterText(_field('이름'), 'Lab Edited');
    await tester.enterText(_field('모델 Prefix'), 'lab-edited');
    await tester.tap(
      find.byKey(const ValueKey<String>('provider-custom-save')),
    );
    await tester.pumpAndSettle();
    final edited = (await api.providers.listProviderConnections()).single;
    expect(edited.displayName, 'Lab Edited');
    expect(edited.modelPrefix, 'lab-edited');

    final save = find.byKey(const ValueKey<String>('provider-custom-save'));
    expect(
      find.ancestor(of: save, matching: find.byType(SettingsFormActions)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: save, matching: find.text('저장')),
      findsOneWidget,
    );

    final disconnect = find.byKey(
      const ValueKey<String>('provider-custom-disconnect'),
    );
    await tester.scrollUntilVisible(
      disconnect,
      TRSpacing.fourExtraLarge,
      scrollable: find
          .descendant(
            of: find.byType(SettingsScaffold),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(disconnect);
    await tester.pumpAndSettle();
    expect(
      find.ancestor(of: disconnect, matching: find.byType(TRPaneHeader)),
      findsNothing,
    );
    expect(
      find.ancestor(of: disconnect, matching: find.byType(SettingsSection)),
      findsOneWidget,
    );
    expect(tester.widget<TRButton>(disconnect).intent, TRIntent.danger);
    await tester.ensureVisible(disconnect);
    await tester.tap(disconnect);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TRButton>(find.widgetWithText(TRButton, '연결 해제').last)
          .intent,
      TRIntent.danger,
    );
    await tester.tap(find.widgetWithText(TRButton, '취소').last);
    await tester.pumpAndSettle();
    expect(
      (await api.providers.listProviderConnections()).single.status,
      ProviderConnectionStatus.connected,
    );

    final delete = find.byKey(const ValueKey<String>('provider-custom-delete'));
    await tester.scrollUntilVisible(
      delete,
      TRSpacing.fourExtraLarge,
      scrollable: find
          .descendant(
            of: find.byType(SettingsScaffold),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(delete);
    await tester.pumpAndSettle();
    expect(
      find.ancestor(of: delete, matching: find.byType(SettingsSection)),
      findsOneWidget,
    );
    await tester.tap(delete);
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(TRButton, '삭제').last;
    expect(tester.widget<TRButton>(confirm).intent, TRIntent.danger);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(await api.providers.listProviderConnections(), isEmpty);
  });

  testWidgets(
    'a disconnect completing after Settings closes does not reuse its pane',
    (tester) async {
      final disconnectGate = Completer<void>();
      final api = FakeTinestApi(providerDisconnectGate: disconnectGate.future);
      final router = await _pumpSettings(tester, api);

      await tester.tap(
        find.byKey(const ValueKey<String>('provider-connection-openai')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('provider-connection-disconnect')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TRButton, '연결 해제').last);
      await tester.pumpAndSettle();

      router.go(const WorkspaceHomeRoute().location);
      await tester.pumpAndSettle();
      disconnectGate.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
    tags: const <String>[
      'feature_test__provider_connection_management__widget',
    ],
  );

  testWidgets('provider list renders every connection status', (tester) async {
    final now = DateTime.utc(2026);
    const statuses = ProviderConnectionStatus.values;
    await _pumpSettings(
      tester,
      FakeTinestApi(
        connections: <ProviderConnectionDto>[
          for (var index = 0; index < statuses.length; index += 1)
            ProviderConnectionDto(
              id: 'status-$index',
              definitionId: 'definition-$index',
              modelPrefix: 'prefix-$index',
              displayName: 'Provider $index',
              status: statuses[index],
              authKind: ProviderAuthKind.none,
              credentialOrigin: ProviderCredentialOrigin.none,
              createdAt: now,
              updatedAt: now,
            ),
        ],
      ),
    );

    expect(find.textContaining('연결 중'), findsOneWidget);
    expect(find.textContaining('연결됨'), findsWidgets);
    expect(find.textContaining('제한된 연결'), findsOneWidget);
    expect(find.textContaining('오류'), findsOneWidget);
    expect(find.textContaining('재로그인 필요'), findsOneWidget);
    expect(find.textContaining('연결 해제됨'), findsOneWidget);
  });

  testWidgets('mobile add and Back move between collection and detail panes', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 760);
    addTearDown(tester.view.reset);
    await _pumpSettings(tester, FakeTinestApi());

    expect(
      find.byKey(const ValueKey<String>('provider-connection-openai')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey<String>('provider-add-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('provider-add-openai')), findsOneWidget);
  }, tags: const <String>['feature_test__provider_catalog__widget']);

  testWidgets(
    'a completing authorization does not undo where the user went next',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(1200, 900);
      addTearDown(tester.view.reset);
      final now = DateTime.utc(2026);
      final events = StreamController<ClientEvent>.broadcast(sync: true);
      addTearDown(events.close);
      final api = FakeTinestApi(
        connections: <ProviderConnectionDto>[
          ProviderConnectionDto(
            id: 'deepseek',
            definitionId: 'deepseek',
            modelPrefix: 'deepseek',
            displayName: 'DeepSeek',
            status: ProviderConnectionStatus.connected,
            authKind: ProviderAuthKind.apiKey,
            credentialOrigin: ProviderCredentialOrigin.stored,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        eventStream: events.stream,
      );
      await _pumpSettings(tester, api);

      await _openCatalog(tester);
      await tester.tap(find.byKey(const ValueKey('provider-add-openai')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('provider-connect-submit')),
      );
      await tester.pump();

      // The authorization completes in the same frame the user asks for the
      // catalog again. The form paints through its exit transition, so without
      // a guard its hand-off lands after the navigation and replaces it.
      events.add(
        const ProviderAuthUpdatedClientEvent(
          ProviderAuthAttemptDto(
            id: 'attempt',
            definitionId: 'openai',
            methodId: 'chatgpt-browser',
            connectionId: 'deepseek',
            status: ProviderAuthAttemptStatus.succeeded,
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('provider-add-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('provider-catalog-refresh')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('provider-connection-disconnect')),
        findsNothing,
      );
    },
    tags: const <String>['feature_test__provider_oauth__widget'],
  );

  testWidgets(
    'the catalog reopens after a connection completes the create flow',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(1200, 900);
      addTearDown(tester.view.reset);
      final api = FakeTinestApi(connections: <ProviderConnectionDto>[]);
      await _pumpSettings(tester, api);

      await _openCatalog(tester);
      await tester.tap(find.byKey(const ValueKey('provider-add-deepseek')));
      await tester.pumpAndSettle();
      await tester.enterText(_field('API 키'), 'deepseek-secret');
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('provider-connect-submit')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('provider-connection-deepseek')),
        findsOneWidget,
      );

      // Completing the flow replaces the whole stack with the new connection,
      // so adding another provider must reach the catalog rather than being
      // pulled back by the create flow it just left.
      await _openCatalog(tester);
      expect(
        find
            .byKey(const ValueKey<String>('provider-catalog-refresh'))
            .hitTestable(),
        findsOneWidget,
      );
    },
    tags: const <String>['feature_test__provider_catalog__widget'],
  );

  testWidgets(
    'a failed connection shows the reason the daemon reported',
    (tester) async {
      final now = DateTime.utc(2026);
      await _pumpSettings(
        tester,
        FakeTinestApi(
          connections: <ProviderConnectionDto>[
            ProviderConnectionDto(
              id: 'broken-provider',
              definitionId: 'deepseek',
              modelPrefix: 'broken',
              displayName: 'Unavailable provider',
              status: ProviderConnectionStatus.error,
              authKind: ProviderAuthKind.apiKey,
              credentialOrigin: ProviderCredentialOrigin.stored,
              error: 'Could not list models: upstream refused the request',
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('provider-connection-broken-provider'),
        ),
      );
      await tester.pumpAndSettle();

      final alert = find.byKey(
        const ValueKey<String>('provider-connection-error'),
      );
      expect(alert, findsOneWidget);
      expect(tester.widget<TRAlert>(alert).variant, TRStatusVariant.danger);
      expect(
        find.textContaining('upstream refused the request'),
        findsOneWidget,
      );
      // The reason belongs to the connection section, beside the status it
      // explains, rather than floating above the page.
      expect(
        find.ancestor(of: alert, matching: find.byType(SettingsSection)),
        findsOneWidget,
      );
    },
    tags: const <String>[
      'feature_test__provider_connection_management__widget',
    ],
  );

  testWidgets('mobile Back walks the detail stack one level at a time', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 760);
    addTearDown(tester.view.reset);
    await _pumpSettings(
      tester,
      FakeTinestApi(connections: <ProviderConnectionDto>[]),
    );

    await _openCatalog(tester);
    await tester.tap(find.byKey(const ValueKey('provider-add-deepseek')));
    await tester.pumpAndSettle();
    expect(_field('API 키'), findsOneWidget);

    // The form covers the catalog, which covers the collection, so Back
    // unwinds the same levels the taps built.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_field('API 키'), findsNothing);
    expect(find.byKey(const ValueKey('provider-add-deepseek')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('provider-add-button')),
      findsOneWidget,
    );
  }, tags: const <String>['feature_test__provider_catalog__widget']);

  testWidgets(
    'cancelling the preset form pops to the catalog it was pushed over',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(1200, 900);
      addTearDown(tester.view.reset);
      await _pumpSettings(
        tester,
        FakeTinestApi(connections: <ProviderConnectionDto>[]),
      );

      await _openCatalog(tester);
      final entry = find.byKey(const ValueKey<String>('provider-add-deepseek'));
      final catalogRoute = ModalRoute.of(tester.element(entry));
      expect(catalogRoute, isNotNull);

      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(_field('API 키'), findsOneWidget);

      await tester.tap(find.widgetWithText(TRButton, testL10n.commonCancel));
      await tester.pumpAndSettle();

      // The form is one step above the catalog, so cancelling pops onto the
      // route it was pushed over rather than pushing a second catalog. A
      // replacement would also rebind the collection's secondary animation and
      // replay its exit.
      expect(entry, findsOneWidget);
      expect(ModalRoute.of(tester.element(entry)), same(catalogRoute));
    },
    tags: const <String>['feature_test__provider_catalog__widget'],
  );

  testWidgets('provider route renders offline and unavailable daemon states', (
    tester,
  ) async {
    await _pumpSettings(tester, FakeTinestApi(), autoConnectEnabled: false);
    expect(
      find.byKey(const ValueKey<String>('settings-daemon-offline')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    final router = GoRouter(
      initialLocation: const ProviderSettingsRoute(hostId: 'server').location,
      routes: $appRoutes,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appServicesProvider.overrideWithValue(
            const AppServices(
              settings: _FailingStore(),
              profiles: _FailingStore(),
              credentials: _FailingStore(),
              clients: _FailingStore(),
              clientKind: 'test',
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: testLightTheme,
          darkTheme: testDarkTheme,
          locale: testLocale,
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('온라인 daemon 연결이 필요합니다.'), findsOneWidget);
  }, tags: const <String>['feature_test__daemon_authentication__widget']);
}

Finder _field(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is TRTextField && widget.label == label,
  ),
  matching: find.byType(EditableText),
);

Future<void> _openCatalog(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('provider-add-button')));
  await tester.pumpAndSettle();
}

Future<GoRouter> _pumpSettings(
  WidgetTester tester,
  FakeTinestApi api, {
  bool autoConnectEnabled = true,
  ExternalUrlOpener? externalUrlOpener,
}) async {
  final router = GoRouter(
    initialLocation: const ProviderSettingsRoute(hostId: 'server').location,
    routes: $appRoutes,
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appServicesProvider.overrideWithValue(
          fakeAppServices(api, connected: autoConnectEnabled),
        ),
        appIdGeneratorProvider.overrideWithValue(const _Ids()),
        externalUrlOpenerProvider.overrideWithValue(
          externalUrlOpener ?? _ExternalUrlOpener(),
        ),
      ],
      child: MaterialApp.router(
        theme: testLightTheme,
        darkTheme: testDarkTheme,
        locale: testLocale,
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

final class _ExternalUrlOpener implements ExternalUrlOpener {
  new({this.result = true});

  final bool result;
  final List<Uri> opened = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return result;
  }
}

final class _Ids implements AppIdGenerator {
  const new();

  @override
  String generate() => 'new-provider';
}

final class _FailingStore
    implements
        AppSettingsRepository,
        RemoteHostRepository,
        RemoteHostCredentialStore,
        HostClientFactory {
  const new();

  @override
  Future<AppSettings> loadSettings() =>
      Future<AppSettings>.error(StateError('connection failed'));

  @override
  Future<List<RemoteDaemonProfile>> listProfiles() async =>
      const <RemoteDaemonProfile>[];

  @override
  Future<void> saveSettings(AppSettings settings) async {}

  @override
  Future<void> upsertProfile(RemoteDaemonProfile profile) async {}

  @override
  Future<void> deleteProfile(String profileId) async {}

  @override
  Future<String?> readBearerToken(String profileId) async => null;

  @override
  Future<void> writeBearerToken(String profileId, String token) async {}

  @override
  Future<void> deleteBearerToken(String profileId) async {}

  @override
  Future<void> deleteAllBearerTokens() async {}

  @override
  Future<void> clear() async {}

  @override
  Future<TinestApi> connect({
    required HostConnection connection,
    required HostConnectionCredential credential,
    required String clientId,
    required String clientKind,
  }) => Future<TinestApi>.error(StateError('connection failed'));
}
