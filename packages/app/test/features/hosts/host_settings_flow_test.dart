import 'dart:async';

import 'package:app/src/app/composition/app_services.dart';
import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/app/tinest_app.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/hosts/domain/host_ports.dart';
import 'package:app/src/shared/presentation/settings_layout.dart';
import 'package:app/src/shared/presentation/tinest_list_row.dart';
import 'package:app/src/shared/presentation/tinest_selection_row.dart';
import 'package:app/src/shared/presentation/workspace_skeletons.dart';
import 'package:client/client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:protocol/protocol.dart';
import 'package:relay_protocol/relay_protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/fake_tinest_api.dart';
import '../../support/localization.dart';

void main() {
  testWidgets(
    'daemon connection methods share one card beneath plain guidance',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final store = MemoryAppStore(
        settings: const AppSettings(embeddedDaemonEnabled: false),
      );
      await tester.pumpWidget(
        TinestApp(
          services: AppServices(
            settings: store,
            profiles: store,
            credentials: store,
            clients: _PairClients(
              FakeTinestApi(serverInfo: _serverInfo('relay-server')),
            ),
            clientKind: 'phone',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(findAccessibleAction('설정'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TRButton, '기기 연결'));
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;

      const description =
          'Daemon에 연결할 방법을 선택하세요. 릴레이 링크에서도 daemon 트래픽은 '
          '종단 간 암호화됩니다.';
      final section = find.byType(SettingsSection);
      final guidance = tester.widget<TRText>(
        find.widgetWithText(TRText, description),
      );
      expect(guidance.variant, TRTextVariant.bodySm);
      expect(guidance.color, TRTextColor.muted);
      expect(find.text('Daemon 연결'), findsOneWidget);
      expect(find.byType(TRAlert), findsNothing);
      expect(
        find.descendant(of: section, matching: find.byType(TRCard)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: section, matching: find.byType(TRSeparator)),
        findsNWidgets(2),
      );
    },
    tags: const <String>['feature_test__daemon_relay__widget'],
  );

  testWidgets('QR pairing validates and reviews an offer before connecting', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final store = MemoryAppStore(
      settings: const AppSettings(embeddedDaemonEnabled: false),
    );
    final pairer = _Pairer();
    await tester.pumpWidget(
      TinestApp(
        services: AppServices(
          settings: store,
          profiles: store,
          credentials: store,
          clients: _PairClients(
            FakeTinestApi(serverInfo: _serverInfo('relay-server')),
          ),
          clientKind: 'phone',
          relayPairer: pairer,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(findAccessibleAction('설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TRButton, '기기 연결'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('connect-daemon-scan')));
    await tester.pumpAndSettle();

    expect(find.text('QR 코드 스캔'), findsOneWidget);
    tester.widget<MobileScanner>(find.byType(MobileScanner)).onDetect!(
      BarcodeCapture(
        barcodes: <Barcode>[Barcode(rawValue: _pairingUrl().toString())],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daemon 연결 확인'), findsOneWidget);
    expect(find.text('relay-server'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('relay-pair-submit')));
    await tester.pumpAndSettle();

    expect(pairer.deviceName, 'phone');
    expect(store.profiles.single.serverId, 'relay-server');
    debugDefaultTargetPlatformOverride = null;
  }, tags: const <String>['feature_test__daemon_relay__widget']);

  testWidgets('pairing link registers a daemon-scoped relay device', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final store = MemoryAppStore(
      settings: const AppSettings(embeddedDaemonEnabled: false),
    );
    final pairer = _Pairer();
    await tester.pumpWidget(
      TinestApp(
        services: AppServices(
          settings: store,
          profiles: store,
          credentials: store,
          clients: _PairClients(
            FakeTinestApi(serverInfo: _serverInfo('relay-server')),
          ),
          clientKind: 'phone',
          relayPairer: pairer,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(findAccessibleAction('설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TRButton, '기기 연결'));
    await tester.pumpAndSettle();

    expect(find.text('직접 연결'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('connect-daemon-scan')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('connect-daemon-paste')),
    );
    await tester.pumpAndSettle();
    expect(find.text('연결 링크 붙여넣기'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
    await tester.enterText(_field('연결 링크'), 'https://example.test/bad');
    await tester.tap(find.byKey(const ValueKey<String>('relay-pair-review')));
    await tester.pumpAndSettle();
    expect(find.textContaining('올바른 Tinest 연결 링크'), findsOneWidget);
    await tester.enterText(_field('연결 링크'), _pairingUrl().toString());
    await tester.tap(find.byKey(const ValueKey<String>('relay-pair-review')));
    await tester.pumpAndSettle();
    await tester.enterText(_field('이 기기 이름'), 'My phone');
    await tester.tap(find.byKey(const ValueKey<String>('relay-pair-submit')));
    await tester.pumpAndSettle();

    expect(pairer.deviceName, 'My phone');
    expect(store.profiles.single.serverId, 'relay-server');
    expect(store.profiles.single.relayConnections, hasLength(1));
    expect(store.relayCredentials, hasLength(1));
  }, tags: const <String>['feature_test__daemon_relay__widget']);

  testWidgets('restores the last selected host even while it is offline', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 3);
    final store = MemoryAppStore(
      settings: const AppSettings(
        embeddedDaemonEnabled: false,
        lastActiveHostId: 'offline',
      ),
      profiles: <RemoteDaemonProfile>[
        RemoteDaemonProfile(
          id: 'offline',
          label: 'Offline daemon',
          connections: directHostConnections(
            Uri.parse('wss://offline.example/ws'),
          ),
          autoConnect: false,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      tokens: const <String, String>{'offline': 'token'},
    );
    await tester.pumpWidget(
      TinestApp(
        services: AppServices(
          settings: store,
          profiles: store,
          credentials: store,
          clients: const _OfflineClients(),
          clientKind: 'mobile',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The sidebar lists workspaces, not daemons, so an unreachable daemon
    // surfaces as an empty state instead of a status row.
    expect(find.text('연결된 daemon이 없습니다.'), findsOneWidget);
    await tester.tap(find.text('Daemon 설정'));
    await tester.pumpAndSettle();
    expect(find.text('Offline daemon'), findsWidgets);
    expect(find.textContaining('자동 연결 꺼짐'), findsWidgets);

    // A daemon-scoped category explains the missing connection rather than
    // failing to build its page.
    await tester.tap(find.text(testL10n.settingsCategoryAgent));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('settings-daemon-offline')),
      findsOneWidget,
    );
    expect(find.text('Offline daemon이(가) 연결되어 있지 않습니다.'), findsOneWidget);
  });

  testWidgets('remote-only app renders and opens settings without a daemon', (
    tester,
  ) async {
    final store = MemoryAppStore(
      settings: const AppSettings(embeddedDaemonEnabled: false),
    );
    await tester.pumpWidget(
      TinestApp(
        services: AppServices(
          settings: store,
          profiles: store,
          credentials: store,
          clients: const _OfflineClients(),
          clientKind: 'mobile',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('설정된 daemon이 없습니다.'), findsOneWidget);
    await tester.tap(findAccessibleAction('설정'));
    await tester.pumpAndSettle();
    expect(find.text('설정'), findsOneWidget);
    expect(find.text('내장 daemon'), findsNothing);
    expect(find.text('네트워크 접근 허용'), findsNothing);
    expect(find.text('기기 연결'), findsOneWidget);
  }, tags: const <String>['feature_test__daemon_exposure__widget']);

  testWidgets(
    'approved device loading and error states share the section card',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.utc(2026, 8, 8);
      final gate = Completer<void>();
      final api = FakeTinestApi(serverInfo: _serverInfo('device-server'))
        ..listRelayDevicesGate = gate.future;
      final store = MemoryAppStore(
        settings: const AppSettings(embeddedDaemonEnabled: false),
        profiles: <RemoteDaemonProfile>[
          RemoteDaemonProfile(
            id: 'remote',
            label: 'Remote daemon',
            serverId: 'device-server',
            connections: directHostConnections(
              Uri.parse('wss://daemon.example/v4/ws'),
            ),
            autoConnect: true,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        tokens: const <String, String>{'remote': 'token'},
      );
      await tester.pumpWidget(
        TinestApp(
          services: AppServices(
            settings: store,
            profiles: store,
            credentials: store,
            clients: _PairClients(api),
            clientKind: 'desktop',
          ),
        ),
      );
      await tester.pumpAndSettle();
      const DaemonConnectionsRoute(hostId: 'remote')
          .go(tester.element(find.byType(Navigator).first));
      await tester.pump();
      await tester.pump();

      expect(find.byType(ListRowsSkeleton), findsOneWidget);
      _expectDaemonConnectionSectionsUseSingleCards(tester);

      gate.completeError(StateError('planned device list failure'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('planned device list failure'),
        findsOneWidget,
      );
      final errorAlert = find.ancestor(
        of: find.textContaining('planned device list failure'),
        matching: find.byType(TRAlert),
      );
      expect(errorAlert, findsOneWidget);
      expect(
        tester.widget<TRAlert>(errorAlert).variant,
        TRStatusVariant.danger,
      );
      expect(
        find.ancestor(
          of: find.textContaining('planned device list failure'),
          matching: find.byType(SettingsRow),
        ),
        findsNothing,
      );
      _expectDaemonConnectionSectionsUseSingleCards(tester);
    },
    tags: const <String>[
      'feature_test__daemon_relay__widget',
      'feature_test__settings_async_loading__widget',
    ],
  );

  testWidgets(
    'approved devices can create a pairing offer and revoke a device',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      final now = DateTime.utc(2026, 8, 8);
      final api = FakeTinestApi(
        serverInfo: _serverInfo('device-server'),
        relayPairingOffer: RelayPairingOfferDto(
          url: 'https://tinest.tinyrack.net/pair#offer=test-offer',
          expiresAt: now.add(const Duration(minutes: 10)),
        ),
        relayDevices: <RelayDeviceDto>[
          RelayDeviceDto(
            id: 'phone',
            name: 'My phone',
            registeredAt: now,
            lastConnectedAt: now,
          ),
        ],
      );
      final store = MemoryAppStore(
        settings: const AppSettings(embeddedDaemonEnabled: false),
        profiles: <RemoteDaemonProfile>[
          RemoteDaemonProfile(
            id: 'remote',
            label: 'Remote daemon',
            serverId: 'device-server',
            connections: directHostConnections(
              Uri.parse('wss://daemon.example/v5/ws'),
            ),
            autoConnect: true,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        tokens: const <String, String>{'remote': 'token'},
      );
      await tester.pumpWidget(
        TinestApp(
          services: AppServices(
            settings: store,
            profiles: store,
            credentials: store,
            clients: _PairClients(api),
            clientKind: 'desktop',
          ),
        ),
      );
      await tester.pumpAndSettle();
      const DaemonConnectionsRoute(hostId: 'remote')
          .go(tester.element(find.byType(Navigator).first));
      await tester.pumpAndSettle();

      _expectDaemonConnectionSectionsUseSingleCards(tester);
      expect(
        tester
            .widgetList<SettingsSection>(find.byType(SettingsSection))
            .first
            .title,
        isNull,
      );
      for (final key in const <String>[
        'relay-pair-device',
        'relay-advanced-direct',
      ]) {
        final section = find
            .ancestor(
              of: find.byKey(ValueKey<String>(key)),
              matching: find.byType(SettingsSection),
            )
            .first;
        expect(
          find.descendant(of: section, matching: find.byType(TRCard)),
          findsOneWidget,
          reason: '$key should use only the section-owned surface',
        );
      }

      expect(find.byType(TRQrCode), findsNothing);
      await tester.tap(find.byKey(const ValueKey<String>('relay-pair-device')));
      await tester.pumpAndSettle();
      expect(find.textContaining('offer=test-offer'), findsOneWidget);
      expect(find.byType(TRQrCode), findsOneWidget);
      expect(find.byType(TRDialog), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(TRQrCode)).label,
        contains('일회용 기기 연결 링크 QR 코드'),
      );
      expect(api.relayEnabled, isTrue);

      await tester.tap(
        find.byKey(const ValueKey<String>('relay-dialog-close')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TRDialog), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('relay-advanced-direct')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('relay-endpoint')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('relay-advanced-endpoint')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TRDialog), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey<String>('relay-endpoint')),
        'wss://self-hosted.example/v1/ws',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('relay-endpoint-save')),
      );
      await tester.pumpAndSettle();
      expect(api.relayEndpoint, 'wss://self-hosted.example/v1/ws');

      tester.view.physicalSize = const Size(390, 760);
      await tester.pumpAndSettle();
      _expectDaemonConnectionSectionsUseSingleCards(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('relay-advanced-endpoint')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TRDrawer), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('relay-endpoint')),
        findsOneWidget,
      );
      Navigator.pop(tester.element(find.byType(TRDrawer)));
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(1200, 900);
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView).last, const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(find.text('My phone'), findsOneWidget);
      final revoke = find.widgetWithText(TRButton, '해제');
      expect(tester.widget<TRButton>(revoke).intent, TRIntent.danger);
      await tester.tap(revoke);
      await tester.pumpAndSettle();
      final confirmRevoke = find.widgetWithText(TRButton, '해제').last;
      expect(tester.widget<TRButton>(confirmRevoke).intent, TRIntent.danger);
      await tester.tap(confirmRevoke);
      await tester.pumpAndSettle();
      expect(api.revokedRelayDeviceIds, <String>['phone']);
      expect(find.text('My phone'), findsNothing);
      _expectDaemonConnectionSectionsUseSingleCards(tester);
      semantics.dispose();
    },
    tags: const <String>['feature_test__daemon_relay__widget'],
  );

  testWidgets('remote profiles can be saved offline, edited, and deleted', (
    tester,
  ) async {
    final store = MemoryAppStore(
      settings: const AppSettings(embeddedDaemonEnabled: false),
    );
    await tester.pumpWidget(
      TinestApp(
        services: AppServices(
          settings: store,
          profiles: store,
          credentials: store,
          clients: const _OfflineClients(),
          clientKind: 'mobile',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(findAccessibleAction('설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TRButton, '기기 연결'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('connect-daemon-direct')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(_field(testL10n.commonName), 'Production');
    await tester.enterText(
      _field(testL10n.appSettingsAddress),
      'ws://daemon.example/ws',
    );
    await tester.enterText(
      _field(testL10n.appSettingsBearerToken),
      'secret-token',
    );
    await tester.pump();
    expect(
      tester
          .widget<EditableText>(_field(testL10n.appSettingsAddress))
          .controller
          .text,
      'ws://daemon.example/ws',
    );
    expect(find.textContaining('암호화되지 않습니다'), findsNothing);
    await tester.tap(find.byType(TRSwitch));
    // Save commits the whole profile, so it sits in the pinned action bar
    // below the form rather than in the page header.
    final save = find.byKey(const ValueKey<String>('remote-host-save'));
    expect(
      find.descendant(of: find.byType(TRAppShellHeader), matching: save),
      findsNothing,
    );
    expect(
      find.ancestor(of: save, matching: find.byType(SettingsFormActions)),
      findsOneWidget,
    );
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(store.profiles.single.label, 'Production');
    expect(store.profiles.single.autoConnect, isFalse);
    expect(
      store.tokens[store.profiles.single.connections.single.credentialKey],
      'secret-token',
    );
    EditHostRoute(hostId: store.profiles.single.id)
        .go(tester.element(find.byType(Navigator).first));
    await tester.pumpAndSettle();
    await tester.enterText(_field(testL10n.commonName), 'Renamed');
    await tester.tap(find.widgetWithText(TRButton, '저장'));
    await tester.pumpAndSettle();
    expect(store.profiles.single.label, 'Renamed');

    EditHostRoute(hostId: store.profiles.single.id)
        .go(tester.element(find.byType(Navigator).first));
    await tester.pumpAndSettle();
    final delete = find.widgetWithText(TRButton, '삭제');
    final deleteButton = tester.widget<TRButton>(delete);
    expect(deleteButton.intent, TRIntent.danger);
    expect(
      find.ancestor(of: delete, matching: find.byType(SettingsSection)),
      findsOneWidget,
    );
    // Save is pinned below the form, so the last section of a long form
    // starts under it and has to be scrolled up before it can be tapped.
    await tester.ensureVisible(delete);
    await tester.pumpAndSettle();
    await tester.tap(delete);
    await tester.pumpAndSettle();
    final confirmDelete = find.widgetWithText(TRButton, '삭제').last;
    expect(tester.widget<TRButton>(confirmDelete).intent, TRIntent.danger);
    await tester.tap(confirmDelete);
    await tester.pumpAndSettle();
    expect(store.profiles, isEmpty);
    expect(store.tokens, isEmpty);
    expect(find.text('설정된 daemon이 없습니다.'), findsOneWidget);
  }, tags: const <String>['feature_test__daemon_management__widget']);

  testWidgets('daemon controls preserve readable copy at 696 pixels', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(696, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = MemoryAppStore();
    await tester.pumpWidget(
      TinestApp(
        services: AppServices(
          settings: store,
          profiles: store,
          credentials: store,
          clients: const _OfflineClients(),
          clientKind: 'desktop',
          embeddedLauncher: _FailingLauncher(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(findAccessibleAction('설정'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('settings-category-row-daemon')),
    );
    await tester.pumpAndSettle();

    final port = find.byKey(const ValueKey<String>('embedded-daemon-port'));
    await tester.ensureVisible(port);
    await tester.pumpAndSettle();
    final portSetting = find.ancestor(
      of: port,
      matching: find.byType(SettingsRow),
    );
    final portRow = tester.widget<TinestListRow>(
      find.descendant(of: portSetting, matching: find.byType(TinestListRow)),
    );
    expect(portRow.trailingLayout, TinestListRowTrailingLayout.below);
    expect(portRow.unboundedSubtitle, isTrue);
    expect(tester.getRect(port).width, greaterThan(TRMeasurements.measureSm));

    final exposure = find.byKey(
      const ValueKey<String>('embedded-daemon-exposure'),
    );
    final exposureRow = tester.widget<TinestListRow>(
      find.descendant(of: exposure, matching: find.byType(TinestListRow)),
    );
    expect(exposureRow.trailingLayout, TinestListRowTrailingLayout.inline);
    expect(exposureRow.unboundedSubtitle, isTrue);
    expect(tester.takeException(), isNull);
  }, tags: const <String>['feature_test__daemon_exposure__widget']);

  testWidgets('desktop settings toggles the embedded daemon independently', (
    tester,
  ) async {
    final store = MemoryAppStore();
    final launcher = _FailingLauncher();
    await tester.pumpWidget(
      TinestApp(
        services: AppServices(
          settings: store,
          profiles: store,
          credentials: store,
          clients: const _OfflineClients(),
          clientKind: 'desktop',
          embeddedLauncher: launcher,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(findAccessibleAction('설정'));
    await tester.pumpAndSettle();

    final daemonSettingsPane = _daemonSettingsPane();
    // The sidebar daemon picker names it too, so this is not unique.
    expect(find.text('내장 daemon'), findsWidgets);
    expect(find.text('네트워크 접근 허용'), findsOneWidget);
    expect(
      find.descendant(
        of: daemonSettingsPane,
        matching: find.textContaining('not running'),
      ),
      findsOneWidget,
    );
    final embeddedToggle = find.widgetWithText(TinestSwitchRow, '내장 daemon');
    final exposureToggle = find.widgetWithText(TinestSwitchRow, '네트워크 접근 허용');
    final toggle = tester.widget<TinestSwitchRow>(embeddedToggle);
    expect(toggle.value, isTrue);
    expect(tester.widget<TinestSwitchRow>(exposureToggle).value, isFalse);

    // The port is a setting like any other, so it uses the same leading
    // description / trailing control rail its sibling switches use instead
    // of stacking its own label above a full-width field.
    final portRow = find.ancestor(
      of: find.byKey(const ValueKey<String>('embedded-daemon-port')),
      matching: find.byType(SettingsRow),
    );
    expect(portRow, findsOneWidget);
    expect(
      find.descendant(of: portRow, matching: find.text('포트')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: portRow,
        matching: find.textContaining('1~65535 사이의 포트를 선택하세요.'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: portRow,
        matching: find.byKey(
          const ValueKey<String>('embedded-daemon-port-apply'),
        ),
      ),
      findsOneWidget,
    );

    await tester.enterText(_embeddedPortField(), '70000');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('1~65535 사이의 정수를 입력하세요.'), findsOneWidget);
    expect(
      tester
          .widget<TRButton>(
            find.byKey(const ValueKey<String>('embedded-daemon-port-apply')),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(_embeddedPortField(), '8123');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('embedded-daemon-port-apply')),
    );
    await tester.pumpAndSettle();
    expect(store.settings.embeddedDaemonPort, 8123);
    expect(launcher.ports.last, 8123);

    await tester.tap(exposureToggle);
    await tester.pumpAndSettle();
    expect(
      store.settings.embeddedDaemonExposure,
      EmbeddedDaemonExposure.allInterfaces,
    );

    await tester.tap(embeddedToggle);
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(store.settings.embeddedDaemonEnabled, isTrue);
    await tester.tap(embeddedToggle);
    await tester.pumpAndSettle();
    await tester.tap(find.text('중지'));
    await tester.pumpAndSettle();
    expect(store.settings.embeddedDaemonEnabled, isFalse);
    await tester.tap(embeddedToggle);
    await tester.pumpAndSettle();
    expect(store.settings.embeddedDaemonEnabled, isTrue);
  }, tags: const <String>['feature_test__daemon_exposure__widget']);

  testWidgets('an embedded port conflict shows guidance and can be retried', (
    tester,
  ) async {
    final store = MemoryAppStore();
    final launcher = _FailingLauncher(
      failure: const HostConnectionFailure.network(
        'socket bind failed',
        reason: HostFailureReason.embeddedPortInUse,
      ),
    );
    await tester.pumpWidget(
      TinestApp(
        services: AppServices(
          settings: store,
          profiles: store,
          credentials: store,
          clients: const _OfflineClients(),
          clientKind: 'desktop',
          embeddedLauncher: launcher,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(findAccessibleAction('설정'));
    await tester.pumpAndSettle();

    expect(find.text('내장 daemon을 시작할 수 없습니다'), findsOneWidget);
    expect(find.textContaining('포트 7337'), findsOneWidget);
    expect(find.textContaining('다른 포트를 입력'), findsOneWidget);
    expect(find.byKey(const ValueKey('embedded-daemon-error')), findsOneWidget);

    await tester.tap(find.widgetWithText(TRButton, '다시 시도'));
    await tester.pumpAndSettle();
    expect(launcher.starts, 2);
  }, tags: const <String>['feature_test__daemon_exposure__widget']);

  testWidgets(
    'a held daemon home names the running copy and copies the diagnostic',
    (tester) async {
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final arguments = call.arguments as Map<Object?, Object?>;
            clipboard = arguments['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final store = MemoryAppStore();
      final launcher = _FailingLauncher(
        failure: const HostConnectionFailure.network(
          "PathAccessException: lock failed, path = 'daemon.lock'",
          reason: HostFailureReason.embeddedAlreadyRunning,
        ),
      );
      await tester.pumpWidget(
        TinestApp(
          services: AppServices(
            settings: store,
            profiles: store,
            credentials: store,
            clients: const _OfflineClients(),
            clientKind: 'desktop',
            embeddedLauncher: launcher,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(findAccessibleAction('설정'));
      await tester.pumpAndSettle();

      final daemonSettingsPane = _daemonSettingsPane();
      expect(find.text('내장 daemon을 시작할 수 없습니다'), findsOneWidget);
      final runningCopyGuidance = find.descendant(
        of: daemonSettingsPane,
        matching: find.textContaining('이미 실행 중'),
      );
      expect(runningCopyGuidance, findsOneWidget);
      // Dragging over the message has to select it, so the text cannot be a
      // plain label inside the alert.
      expect(
        find.ancestor(
          of: runningCopyGuidance,
          matching: find.byType(SelectionArea),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('embedded-daemon-error-copy')),
      );
      await tester.pumpAndSettle();

      // A bug report needs the guidance and the operating-system diagnostic
      // the guidance replaced.
      expect(clipboard, contains('내장 daemon을 시작할 수 없습니다'));
      expect(clipboard, contains('이미 실행 중'));
      expect(clipboard, contains('PathAccessException'));
    },
    tags: const <String>['feature_test__daemon_management__widget'],
  );

  testWidgets('a browser explains a failed local-network daemon connection', (
    tester,
  ) async {
    final profile = RemoteDaemonProfile(
      id: 'remote',
      label: 'Loopback',
      connections: directHostConnections(Uri.parse('ws://127.0.0.1:7337/ws')),
      // Auto-connect would leave a retry timer pending past teardown.
      autoConnect: false,
      createdAt: DateTime.utc(2024),
      updatedAt: DateTime.utc(2024),
    );
    final store = MemoryAppStore(
      settings: const AppSettings(embeddedDaemonEnabled: false),
      profiles: <RemoteDaemonProfile>[profile],
      tokens: const <String, String>{'remote': 'token'},
    );
    await tester.pumpWidget(
      TinestApp(
        services: AppServices(
          settings: store,
          profiles: store,
          credentials: store,
          clients: const _LocalNetworkUnreachableClients(),
          clientKind: 'web',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(findAccessibleAction('설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TRButton, '다시 연결'));
    await tester.pumpAndSettle();

    // The browser cannot say which of the two causes it was, so both have
    // to reach the user.
    expect(find.textContaining('실행 중인지'), findsWidgets);
    expect(find.textContaining('로컬 네트워크 접근'), findsWidgets);
  }, tags: const <String>['feature_test__daemon_management__widget']);

  testWidgets('host home and settings render independent runtime statuses', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 3);
    RemoteDaemonProfile profile(String id, {bool autoConnect = true}) =>
        RemoteDaemonProfile(
          id: id,
          label: '$id daemon',
          connections: directHostConnections(Uri.parse('wss://$id.test/ws')),
          autoConnect: autoConnect,
          createdAt: now,
          updatedAt: now,
        );
    final onlineApi = FakeTinestApi(serverInfo: _serverInfo('shared-server'));
    final duplicateApi = FakeTinestApi(
      serverInfo: _serverInfo('shared-server'),
    );
    final pending = Completer<TinestApi>();
    final store = MemoryAppStore(
      settings: const AppSettings(embeddedDaemonEnabled: false),
      profiles: <RemoteDaemonProfile>[
        profile('online'),
        profile('duplicate'),
        profile('error'),
        profile('pending'),
        profile('idle', autoConnect: false),
      ],
      tokens: const <String, String>{
        'online': 'token',
        'duplicate': 'token',
        'error': 'token',
        'pending': 'token',
        'idle': 'token',
      },
    );
    await tester.pumpWidget(
      TinestApp(
        services: AppServices(
          settings: store,
          profiles: store,
          credentials: store,
          clients: _ProfileClients(<String, Future<TinestApi> Function()>{
            'online.test': () async => onlineApi,
            'duplicate.test': () async => duplicateApi,
            'error.test': () => Future<TinestApi>.error(
              const HostConnectionFailure.authentication('bad token'),
            ),
            'pending.test': () => pending.future,
          }),
          clientKind: 'test',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    onlineApi.emitState(ClientConnectionState.reconnecting);
    await tester.pump();
    // Runtime status lives in daemon settings; the sidebar shows workspaces.
    await tester.tap(findAccessibleAction('설정'));
    await tester.pumpAndSettle();
    expect(find.textContaining('같은 daemon이 이미 등록되어 있습니다.'), findsOneWidget);
    // A failed daemon reports its own message in place of the generic status.
    expect(find.text('연결 중'), findsOneWidget);
    expect(
      find.descendant(of: _daemonSettingsPane(), matching: find.text('재연결 중')),
      findsOneWidget,
    );
    expect(find.textContaining('bad token'), findsOneWidget);
    // The idle daemon sits below the fold of the settings list.
    await tester.drag(find.byType(ListView).last, const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(find.textContaining('자동 연결 꺼짐'), findsWidgets);

    pending.complete(FakeTinestApi(serverInfo: _serverInfo('pending-server')));
  });
}

ServerInfoDto _serverInfo(String id) => ServerInfoDto(
  serverId: id,
  version: 'test',
  protocolVersion: tinestProtocolMajor,
  features: const <String, bool>{},
);

final class _OfflineClients implements HostClientFactory {
  const new();

  @override
  Future<TinestApi> connect({
    required HostConnection connection,
    required HostConnectionCredential credential,
    required String clientId,
    required String clientKind,
  }) => Future<TinestApi>.error(const HostConnectionFailure.network('offline'));
}

final class _Pairer implements HostRelayPairer {
  String? deviceName;

  @override
  Future<RelayPairingResult> pair({
    required Uri pairingUrl,
    required String deviceId,
    required String deviceName,
    required String connectionId,
    required String credentialKey,
  }) async {
    this.deviceName = deviceName;
    return RelayPairingResult(
      connection: RelayHostConnection(
        id: connectionId,
        credentialKey: credentialKey,
        serverId: 'relay-server',
        relayUri: Uri.parse('wss://relay.tinest.tinyrack.net/v1/ws'),
        daemonIdentityPublicKey: List<int>.filled(32, 1),
      ),
      credential: RelayHostCredential(
        deviceId: deviceId,
        privateKey: List<int>.filled(32, 2),
      ),
    );
  }
}

final class _PairClients implements HostClientFactory {
  const new(this.api);

  final TinestApi api;

  @override
  Future<TinestApi> connect({
    required HostConnection connection,
    required HostConnectionCredential credential,
    required String clientId,
    required String clientKind,
  }) async => api;
}

/// Stands in for a browser that refuses to explain a failed connection to a
/// daemon on the user's own machine.
final class _LocalNetworkUnreachableClients implements HostClientFactory {
  const new();

  @override
  Future<TinestApi> connect({
    required HostConnection connection,
    required HostConnectionCredential credential,
    required String clientId,
    required String clientKind,
  }) => Future<TinestApi>.error(
    const TinestClientException(
      'Could not reach a daemon at 127.0.0.1:7337.',
      code: localNetworkUnreachableCode,
      retryable: true,
    ),
  );
}

final class _FailingLauncher implements EmbeddedDaemonLauncher {
  new({this.failure = const HostConnectionFailure.network('not running')});

  final HostConnectionFailure failure;
  final List<int> ports = <int>[];
  int starts = 0;

  @override
  Future<EmbeddedDaemonSession> start({
    required EmbeddedDaemonExposure exposure,
    required int port,
  }) {
    starts += 1;
    ports.add(port);
    return Future<EmbeddedDaemonSession>.error(failure);
  }
}

final class _ProfileClients implements HostClientFactory {
  const new(this.connections);

  final Map<String, Future<TinestApi> Function()> connections;

  @override
  Future<TinestApi> connect({
    required HostConnection connection,
    required HostConnectionCredential credential,
    required String clientId,
    required String clientKind,
  }) =>
      connections[(connection as DirectHostConnection)
          .endpoint
          .websocketUri
          .host]!();
}

Uri _pairingUrl() => RelayPairingOffer(
  serverId: 'relay-server',
  relayUri: Uri.parse('wss://relay.tinest.tinyrack.net/v1/ws'),
  daemonPublicKey: List<int>.filled(32, 1),
  offerId: 'test-offer',
  secret: List<int>.filled(32, 2),
  expiresAt: DateTime.utc(2100),
).toUrl(Uri.parse('https://tinest.tinyrack.net/pair'));

Finder _field(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is TRTextField && widget.label == label,
  ),
  matching: find.byType(EditableText),
);

Finder _embeddedPortField() => find.descendant(
  of: find.byKey(const ValueKey<String>('embedded-daemon-port')),
  matching: find.byType(EditableText),
);

Finder _daemonSettingsPane() =>
    find.byKey(const ValueKey<String>('settings-category-pane-daemon'));

void _expectDaemonConnectionSectionsUseSingleCards(WidgetTester tester) {
  // A phone draws its groups without a card, so what is being checked there is
  // that none appeared, and on a wider window that exactly one did. Either way
  // the point is the same: a group never nests a card inside a card.
  final compact =
      settingsAdaptiveWidthClassOf(
        tester.element(find.byType(SettingsSection).first),
      ) ==
      TRAdaptiveWidthClass.compact;
  for (final section in find.byType(SettingsSection).evaluate()) {
    final sectionFinder = find.byElementPredicate(
      (element) => identical(element, section),
    );
    final cards = find.descendant(
      of: sectionFinder,
      matching: find.byType(TRCard),
    );
    final isAlertOnly =
        cards.evaluate().isEmpty &&
        find
            .descendant(of: sectionFinder, matching: find.byType(TRAlert))
            .evaluate()
            .isNotEmpty;
    if (isAlertOnly) continue;
    expect(
      cards,
      compact ? findsNothing : findsOneWidget,
      reason: compact
          ? 'A compact settings group draws no card of its own.'
          : 'A boxed settings section must own its only card.',
    );
  }

  final advancedSection = find.ancestor(
    of: find.widgetWithText(TRText, '고급'),
    matching: find.byType(SettingsSection),
  );
  final separator = find.descendant(
    of: advancedSection,
    matching: find.byType(TRSeparator),
  );
  expect(separator, findsOneWidget);
  expect(
    tester.widget<TRSeparator>(separator).variant,
    TRSeparatorVariant.muted,
  );
}
