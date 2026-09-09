part of '../../app/app_flows_test.dart';

void _registerSettingsAppFlows() {
  final now = DateTime.utc(2026, 8, 3);
  testWidgets('compact settings categories own the single page header', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = await _pumpRoute(
      tester,
      FakeTinestApi(),
      const GeneralSettingsRoute().location,
    );
    addTearDown(router.dispose);

    // The destination owns the only header, so its title replaces the
    // shell's '설정' instead of stacking below it.
    final header = find.byType(TinestPageHeaderBar);
    expect(header, findsOneWidget);
    expect(find.byType(TRPaneHeader), findsNothing);
    expect(find.text('설정'), findsNothing);
    expect(
      find.descendant(of: header, matching: find.text('일반')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: header,
        matching: find.byKey(const ValueKey<String>('settings-back-button')),
      ),
      findsOneWidget,
    );
  }, tags: const <String>['feature_test__app_navigation__widget']);

  testWidgets(
    'compact list-detail moves its header from collection to detail',
    (tester) async {
      await _setTestViewport(tester, const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = await _pumpRoute(
        tester,
        FakeTinestApi(),
        const McpSettingsRoute(hostId: 'server').location,
      );
      addTearDown(router.dispose);

      // The collection's own action rides in the single page header.
      expect(find.byType(TinestPageHeaderBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TinestPageHeaderBar),
          matching: find.byKey(const ValueKey<String>('mcp-server-add')),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey<String>('mcp-server-add')));
      await tester.pumpAndSettle();

      // Entering the detail replaces the header rather than stacking one.
      final detailHeader = find.byType(TinestPageHeaderBar).last;
      expect(
        find.descendant(
          of: detailHeader,
          matching: find.text(testL10n.mcpSettingsAdd),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('settings-back-button')),
        findsOneWidget,
      );
      // The header carries no editor commands at all, so it cannot grow a
      // second run to hold them at phone width. Save is pinned below the
      // form, and the two section-scoped commands sit with their sections.
      final headerRect = tester.getRect(detailHeader);
      for (final action in const <String>[
        'mcp-secret-set',
        'mcp-server-test',
        'mcp-server-save',
      ]) {
        final rect = tester.getRect(find.byKey(ValueKey<String>(action)));
        expect(headerRect.contains(rect.topLeft), isFalse, reason: action);
      }
      final save = find.byKey(const ValueKey<String>('mcp-server-save'));
      expect(
        find.ancestor(of: save, matching: find.byType(SettingsFormActions)),
        findsOneWidget,
      );
      // Pinned means always laid out, so a caller never has to scroll to it.
      expect(
        tester.getRect(save).bottom,
        lessThanOrEqualTo(tester.getSize(find.byType(MaterialApp)).height),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('settings-back-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(TinestPageHeaderBar),
          matching: find.byKey(const ValueKey<String>('mcp-server-add')),
        ),
        findsOneWidget,
      );
    },
    tags: const <String>['feature_test__app_navigation__widget'],
  );

  testWidgets('desktop settings header shares the form content rail', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = await _pumpRoute(
      tester,
      FakeTinestApi(),
      const GeneralSettingsRoute().location,
    );
    addTearDown(router.dispose);

    final headerFinder = find.byType(TRPaneHeader);
    expect(headerFinder, findsOneWidget);
    final headerTitle = find.descendant(
      of: headerFinder,
      matching: find.text('일반'),
    );
    // The group's own edge rather than a heading inside it: a page whose
    // first group needs no heading still has to share the header's rail.
    final firstGroup = find.byType(TRCard).first;
    expect(headerTitle, findsOneWidget);
    expect(firstGroup, findsOneWidget);
    expect(tester.getRect(headerTitle).left, tester.getRect(firstGroup).left);
    expect(
      tester.widget<TRPaneHeader>(headerFinder).contentMaxWidth,
      TinestLayoutMetrics.settingsContentMaxWidth,
    );
  }, tags: const <String>['feature_test__app_navigation__widget']);

  testWidgets(
    'host-scoped settings keep the selected daemon across categories',
    (tester) async {
      await _setTestViewport(tester, const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final first = FakeTinestApi(
        serverInfo: const ServerInfoDto(
          serverId: 'first-server',
          version: 'test',
          protocolVersion: tinestProtocolMajor,
          features: <String, bool>{},
        ),
      );
      final second = FakeTinestApi(
        serverInfo: const ServerInfoDto(
          serverId: 'second-server',
          version: 'test',
          protocolVersion: tinestProtocolMajor,
          features: <String, bool>{},
        ),
      );
      addTearDown(first.close);
      addTearDown(second.close);
      final store = MemoryAppStore(
        settings: const AppSettings(embeddedDaemonEnabled: false),
        profiles: <RemoteDaemonProfile>[
          RemoteDaemonProfile(
            id: 'first',
            label: 'First daemon',
            connections: directHostConnections(Uri.parse('ws://first.test/ws')),
            autoConnect: true,
            createdAt: now,
            updatedAt: now,
          ),
          RemoteDaemonProfile(
            id: 'second',
            label: 'Second daemon',
            connections: directHostConnections(
              Uri.parse('ws://second.test/ws'),
            ),
            autoConnect: true,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        tokens: const <String, String>{
          'first': 'first-token',
          'second': 'second-token',
        },
      );
      await tester.pumpWidget(
        TinestApp(
          services: AppServices(
            settings: store,
            profiles: store,
            credentials: store,
            clients: _MappedClients(<String, TinestApi>{
              'first.test': first,
              'second.test': second,
            }),
            clientKind: 'settings-host-test',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-settings-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('에이전트'));
      await tester.pumpAndSettle();

      final daemonSelect = find.byKey(
        const ValueKey<String>('settings-daemon-select'),
      );
      await tester.tap(daemonSelect);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Second daemon').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('MCP'));
      await tester.pumpAndSettle();

      expect(tester.widget<TRSelect<String>>(daemonSelect).value, 'second');
      expect(store.settings.lastActiveHostId, 'second');

      // App-wide categories carry no daemon, so passing through one used to
      // drop the selection back to the first online daemon.
      await tester.tap(find.text('일반'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('프로젝트'));
      await tester.pumpAndSettle();
      expect(tester.widget<TRSelect<String>>(daemonSelect).value, 'second');

      // A daemon card's provider shortcut names its host in the location and
      // replaces the settings page rather than pushing another one, so the
      // page outlives the change and has to adopt each daemon a later location
      // names, not only the first.
      Future<void> openProviderShortcut(String hostLabel) async {
        await tester.tap(
          find.byKey(const ValueKey<String>('settings-category-row-daemon')),
        );
        await tester.pumpAndSettle();
        final shortcut = find.descendant(
          of: find
              .ancestor(of: find.text(hostLabel), matching: find.byType(TRCard))
              .first,
          matching: find.widgetWithText(TRButton, 'Provider 설정'),
        );
        await tester.ensureVisible(shortcut);
        await tester.tap(shortcut);
        await tester.pumpAndSettle();
      }

      await openProviderShortcut('First daemon');
      expect(tester.widget<TRSelect<String>>(daemonSelect).value, 'first');
      expect(store.settings.lastActiveHostId, 'first');
      await openProviderShortcut('Second daemon');
      expect(tester.widget<TRSelect<String>>(daemonSelect).value, 'second');
      expect(store.settings.lastActiveHostId, 'second');
    },
    tags: const <String>['feature_test__daemon_management__widget'],
  );

  testWidgets(
    'sidebar daemon selection replaces an explicit host-scoped route',
    (tester) async {
      await _setTestViewport(tester, const Size(1200, 800));
      final now = DateTime.utc(2026, 8, 3);
      ProviderConnectionDto connection(String id, String displayName) =>
          ProviderConnectionDto(
            id: id,
            definitionId: id,
            modelPrefix: id,
            displayName: displayName,
            status: ProviderConnectionStatus.connected,
            authKind: ProviderAuthKind.none,
            credentialOrigin: ProviderCredentialOrigin.none,
            createdAt: now,
            updatedAt: now,
          );
      final first = FakeTinestApi(
        serverInfo: const ServerInfoDto(
          serverId: 'explicit-first-server',
          version: 'test',
          protocolVersion: tinestProtocolMajor,
          features: <String, bool>{},
        ),
        connections: <ProviderConnectionDto>[
          connection('first-provider', 'First provider'),
        ],
      );
      final second = FakeTinestApi(
        serverInfo: const ServerInfoDto(
          serverId: 'explicit-second-server',
          version: 'test',
          protocolVersion: tinestProtocolMajor,
          features: <String, bool>{},
        ),
        connections: <ProviderConnectionDto>[
          connection('second-provider', 'Second provider'),
        ],
      );
      addTearDown(first.close);
      addTearDown(second.close);
      final store = MemoryAppStore(
        settings: const AppSettings(
          embeddedDaemonEnabled: false,
          lastActiveHostId: 'first',
        ),
        profiles: <RemoteDaemonProfile>[
          RemoteDaemonProfile(
            id: 'first',
            label: 'First daemon',
            connections: directHostConnections(Uri.parse('ws://first.test/ws')),
            autoConnect: true,
            createdAt: now,
            updatedAt: now,
          ),
          RemoteDaemonProfile(
            id: 'second',
            label: 'Second daemon',
            connections: directHostConnections(
              Uri.parse('ws://second.test/ws'),
            ),
            autoConnect: true,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        tokens: const <String, String>{
          'first': 'first-token',
          'second': 'second-token',
        },
      );
      await tester.pumpWidget(
        TinestApp(
          initialLocation: const ProviderSettingsRoute(hostId: 'first')
              .location,
          services: AppServices(
            settings: store,
            profiles: store,
            credentials: store,
            clients: _MappedClients(<String, TinestApi>{
              'first.test': first,
              'second.test': second,
            }),
            clientKind: 'explicit-settings-host-test',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('First provider'), findsWidgets);

      final daemonSelect = find.byKey(
        const ValueKey<String>('settings-daemon-select'),
      );
      await tester.tap(daemonSelect);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Second daemon').last);
      await tester.pumpAndSettle();

      expect(tester.widget<TRSelect<String>>(daemonSelect).value, 'second');
      expect(store.settings.lastActiveHostId, 'second');
      final visibleText = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data)
          .whereType<String>()
          .toList(growable: false);
      expect(
        find.text('Second provider'),
        findsWidgets,
        reason: 'Visible text: $visibleText',
      );
      expect(find.text('First provider'), findsNothing);
    },
    tags: const <String>[
      'feature_test__app_navigation__widget',
      'feature_test__daemon_management__widget',
    ],
  );

  testWidgets(
    'the settings sidebar daemon select is framed by the sidebar, not itself',
    (tester) async {
      await _setTestViewport(tester, const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi(
        serverInfo: const ServerInfoDto(
          serverId: 'sidebar-server',
          version: 'test',
          protocolVersion: tinestProtocolMajor,
          features: <String, bool>{},
        ),
      );
      addTearDown(api.close);
      final store = MemoryAppStore(
        settings: const AppSettings(embeddedDaemonEnabled: false),
        profiles: <RemoteDaemonProfile>[
          RemoteDaemonProfile(
            id: 'only',
            label: 'Only daemon',
            connections: directHostConnections(Uri.parse('ws://only.test/ws')),
            autoConnect: true,
            createdAt: now,
            updatedAt: now,
          ),
          RemoteDaemonProfile(
            id: 'manual',
            label: 'Manual daemon',
            connections: directHostConnections(
              Uri.parse('ws://manual.test/ws'),
            ),
            autoConnect: false,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        tokens: const <String, String>{
          'only': 'only-token',
          'manual': 'manual-token',
        },
      );
      await tester.pumpWidget(
        TinestApp(
          services: AppServices(
            settings: store,
            profiles: store,
            credentials: store,
            clients: _MappedClients(<String, TinestApi>{'only.test': api}),
            clientKind: 'sidebar-daemon-select-test',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-settings-button')),
      );
      await tester.pumpAndSettle();

      // The sidebar is a flat list of borderless nav rows, so a boxed select
      // trigger sitting among them reads as a foreign control.
      final daemonSelect = find.byKey(
        const ValueKey<String>('settings-daemon-select'),
      );
      expect(
        tester.widget<TRSelect<String>>(daemonSelect).appearance,
        TRFieldAppearance.ghost,
      );
      final select = tester.widget<TRSelect<String>>(daemonSelect);
      expect(select.helperText, testL10n.hostStatusOnline);
      expect((select.leading! as Icon).icon, TinestIcons.success);
      expect(
        select.items.singleWhere((item) => item.value == 'only').description,
        testL10n.hostStatusOnline,
      );
      expect(
        select.items.singleWhere((item) => item.value == 'manual').description,
        testL10n.hostStatusIdle,
      );

      final trigger = find.descendant(
        of: daemonSelect,
        matching: find.byType(TextButton),
      );
      final button = tester.widget<TextButton>(trigger);
      await tester.tap(trigger, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      final states = <WidgetState>{
        if (button.focusNode?.hasFocus ?? false) WidgetState.focused,
      };
      final colors = tester.element(daemonSelect).tinyrackTheme;
      expect(
        button.style!.backgroundColor!.resolve(states),
        colors.surfaceSelected,
      );
      expect(button.style!.side!.resolve(states)!.color, isNot(colors.focus));

      await tester.tap(
        find.byKey(const ValueKey<String>('settings-daemon-option-manual')),
      );
      await tester.pumpAndSettle();
      final manualSelect = tester.widget<TRSelect<String>>(daemonSelect);
      expect(manualSelect.value, 'manual');
      expect(manualSelect.helperText, testL10n.hostStatusIdle);
      expect((manualSelect.leading! as Icon).icon, TinestIcons.paused);
    },
    tags: const <String>['feature_test__daemon_management__widget'],
  );

  testWidgets('settings combines Projects, Agent, Provider, and Daemon', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(1400, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = FakeTinestApi();
    final router = await _pumpRoute(
      tester,
      api,
      const ProviderSettingsRoute(hostId: 'server').location,
    );
    addTearDown(router.dispose);
    expect(
      find.byKey(const ValueKey<String>('settings-sidebar-surface')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('settings-sidebar-tree-app')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('settings-sidebar-tree-daemon')),
      findsOneWidget,
    );
    expect(find.text('프로젝트'), findsOneWidget);
    expect(find.text('에이전트'), findsOneWidget);
    // The sidebar entry and the collection's own pane header both name the
    // category, the same way every other list-detail category does.
    expect(find.text('프로바이더'), findsNWidgets(2));
    expect(find.text(testL10n.settingsSectionDaemon), findsWidgets);
    expect(find.text('Test daemon'), findsWidgets);
    await tester.tap(find.text('프로젝트'));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.toString(),
      const ProjectSettingsRoute().location,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('settings-category-row-daemon')),
    );
    await tester.pumpAndSettle();
    expect(find.text('원격 daemons'), findsOneWidget);
  });

  testWidgets(
    'desktop settings opens Connections for the selected daemon',
    (tester) async {
      await _setTestViewport(tester, const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = await _pumpRoute(
        tester,
        FakeTinestApi(),
        const ProviderSettingsRoute(hostId: 'server').location,
      );
      addTearDown(router.dispose);

      await tester.tap(find.text('연결'));
      await tester.pumpAndSettle();

      expect(
        router.state.uri.toString(),
        const DaemonConnectionsRoute(hostId: 'server').location,
      );
      expect(
        find.byKey(const ValueKey<String>('settings-sidebar-surface')),
        findsOneWidget,
      );
      expect(find.text('기기 연결'), findsWidgets);
    },
    tags: const <String>[
      'feature_test__app_navigation__widget',
      'feature_test__daemon_relay__widget',
    ],
  );

  testWidgets(
    'mobile daemon settings opens Connections and returns to categories',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final router = await _pumpRoute(
        tester,
        FakeTinestApi(),
        const DaemonCategoriesRoute(hostId: 'server').location,
      );
      addTearDown(router.dispose);

      await tester.tap(find.text('연결'));
      await tester.pumpAndSettle();

      expect(
        router.state.uri.toString(),
        const DaemonConnectionsRoute(hostId: 'server').location,
      );
      expect(find.text('기기 연결'), findsWidgets);
      final back = find.byKey(const ValueKey<String>('settings-back-button'));
      expect(back, findsOneWidget);

      await tester.tap(back);
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.toString(),
        const DaemonCategoriesRoute(hostId: 'server').location,
      );
      expect(find.text('MCP'), findsOneWidget);
    },
    tags: const <String>[
      'feature_test__app_navigation__widget',
      'feature_test__daemon_relay__widget',
    ],
  );

  testWidgets('mobile settings navigation rows remain keyboard activatable', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = await _pumpRoute(
      tester,
      FakeTinestApi(),
      const SettingsHomeRoute().location,
    );
    addTearDown(router.dispose);

    // The destination now owns the page header, so its up action is the
    // first focus stop and the first navigation row is the second.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, const GeneralSettingsRoute().location);
  }, tags: const <String>['feature_test__app_navigation__widget']);

  testWidgets(
    'mobile settings touch starts pressed feedback before navigation',
    (tester) async {
      await _setTestViewport(tester, const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = await _pumpRoute(
        tester,
        FakeTinestApi(),
        const SettingsHomeRoute().location,
      );
      addTearDown(router.dispose);

      AnimatedContainer rowSurface(String label) =>
          tester.widget<AnimatedContainer>(
            find
                .ancestor(
                  of: find.text(label),
                  matching: find.byType(AnimatedContainer),
                )
                .first,
          );

      Color? paintedRowBackground(String label) {
        final paintedSurface = find.descendant(
          of: find.byWidget(rowSurface(label)),
          matching: find.byType(DecoratedBox),
        );
        for (final decorated in tester.widgetList<DecoratedBox>(
          paintedSurface,
        )) {
          final decoration = decorated.decoration;
          if (decoration is BoxDecoration && decoration.color != null) {
            return decoration.color;
          }
        }
        return null;
      }

      final theme = tester.element(find.text('일반')).tinyrackTheme;
      final generalSemantics = tester.getSemantics(find.text('일반'));
      expect(generalSemantics.label, '일반');
      expect(
        generalSemantics.getSemanticsData().hasAction(ui.SemanticsAction.tap),
        isTrue,
      );
      expect(find.byType(TRTreeNav<SettingsCategory>), findsOneWidget);
      final startColor = paintedRowBackground('일반');
      final touch = await tester.startGesture(
        tester.getCenter(find.text('일반')),
      );
      await tester.pump();
      final entering = rowSurface('일반');
      expect(
        (entering.decoration! as BoxDecoration).color,
        theme.surfacePressed,
      );
      expect(entering.duration, lessThan(TRMotion.fast));
      expect(entering.curve, TRMotion.easeOut);
      await tester.pump(entering.duration ~/ 2);
      final halfwayColor = paintedRowBackground('일반');
      expect(halfwayColor, isNot(startColor));
      expect(halfwayColor, isNot(theme.surfacePressed));
      await tester.pump(entering.duration ~/ 2);
      expect(paintedRowBackground('일반'), theme.surfacePressed);

      await touch.up();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, const GeneralSettingsRoute().location);
    },
    tags: const <String>['feature_test__app_navigation__widget'],
  );

  testWidgets('mobile settings scroll cancels pressed navigation', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = await _pumpRoute(
      tester,
      FakeTinestApi(),
      const SettingsHomeRoute().location,
    );
    addTearDown(router.dispose);

    final touch = await tester.startGesture(
      tester.getCenter(find.text('Test daemon')),
    );
    await tester.pump();
    await touch.moveBy(const Offset(0, -80));
    await touch.up();
    await tester.pumpAndSettle();

    expect(router.state.uri.path, const SettingsHomeRoute().location);
  }, tags: const <String>['feature_test__app_navigation__widget']);

  testWidgets('mobile settings navigation uses comfortable row targets', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(390, 844));
    final router = await _pumpRoute(
      tester,
      FakeTinestApi(),
      const SettingsHomeRoute().location,
    );
    addTearDown(router.dispose);

    final general = find.text('일반');
    final surface = find
        .ancestor(of: general, matching: find.byType(AnimatedContainer))
        .first;
    expect(
      tester.getRect(surface).height,
      greaterThanOrEqualTo(TRControlMetrics.heightOf(TRUiSize.xl)),
    );
  }, tags: const <String>['feature_test__app_navigation__widget']);

  testWidgets('mobile settings navigation uses comfortable label typography', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(390, 844));
    final router = await _pumpRoute(
      tester,
      FakeTinestApi(),
      const SettingsHomeRoute().location,
    );
    addTearDown(router.dispose);

    final general = find.text('일반');
    final paragraph = tester.renderObject<RenderParagraph>(general);
    expect(
      paragraph.text.style?.fontSize,
      TRControlMetrics.fontSizeOf(TRUiSize.xl),
    );
  }, tags: const <String>['feature_test__app_navigation__widget']);

  testWidgets(
    'mobile settings root section shares the navigation content line',
    (tester) async {
      await _setTestViewport(tester, const Size(390, 844));
      final router = await _pumpRoute(
        tester,
        FakeTinestApi(),
        const SettingsHomeRoute().location,
      );
      addTearDown(router.dispose);

      Rect navigationSurface(String label) => tester.getRect(
        find
            .ancestor(
              of: find.text(label),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );

      final rootSurface = navigationSurface('일반');
      expect(rootSurface.left, TRSpacing.medium);
      expect(rootSurface.right, 390 - TRSpacing.medium);
      expect(
        tester.getRect(find.text('앱')).left,
        moreOrLessEquals(rootSurface.left + TRSpacing.medium, epsilon: 0.5),
      );
    },
    tags: const <String>['feature_test__app_navigation__widget'],
  );

  testWidgets('mobile daemon categories use the settings root surface inset', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(390, 844));
    final router = await _pumpRoute(
      tester,
      FakeTinestApi(),
      const DaemonCategoriesRoute(hostId: 'server').location,
    );
    addTearDown(router.dispose);

    final daemonSurface = tester.getRect(
      find
          .ancestor(
            of: find.text('MCP'),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    expect(daemonSurface.left, TRSpacing.medium);
    expect(daemonSurface.right, 390 - TRSpacing.medium);
  }, tags: const <String>['feature_test__app_navigation__widget']);

  testWidgets(
    'mobile daemon categories carry their identity in the page header',
    (tester) async {
      await _setTestViewport(tester, const Size(390, 844));
      final router = await _pumpRoute(
        tester,
        FakeTinestApi(),
        const DaemonCategoriesRoute(hostId: 'server').location,
      );
      addTearDown(router.dispose);

      // The daemon name replaces the shell title, and the header carries that
      // name alone: no second line stacked under it.
      final header = find.byType(TinestPageHeaderBar);
      expect(header, findsOneWidget);
      expect(find.byType(TRPaneHeader), findsNothing);
      expect(
        find.descendant(of: header, matching: find.text('Test daemon')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: header,
          matching: find.text(testL10n.hostStatusOnline),
        ),
        findsNothing,
      );
      final headerRect = tester.getRect(header);
      expect(
        tester.getRect(find.text('MCP')).top,
        greaterThan(headerRect.bottom),
      );
    },
    tags: const <String>['feature_test__app_navigation__widget'],
  );

  testWidgets('mobile settings drills from home into daemon MCP settings', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final router = await _pumpRoute(
      tester,
      FakeTinestApi(),
      const SettingsHomeRoute().location,
    );
    addTearDown(router.dispose);

    expect(
      find.byKey(const ValueKey<String>('settings-category-select')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('settings-daemon-select')),
      findsNothing,
    );
    expect(find.text('일반'), findsOneWidget);
    expect(find.text('Test daemon'), findsOneWidget);

    await tester.tap(find.text('Test daemon'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('settings-home-pane')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('settings-daemon-categories-pane')),
      findsOneWidget,
    );
    expect(router.state.uri.path, '/settings/daemons/server/categories');
    expect(find.text('MCP'), findsOneWidget);

    await tester.tap(find.text('MCP'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('settings-daemon-categories-pane')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('settings-category-pane-mcp')),
      findsOneWidget,
    );
    expect(router.state.uri.path, '/settings/mcp');
    expect(find.byKey(const ValueKey<String>('mcp-server-list')), findsOne);

    await tester.tap(find.byKey(const ValueKey<String>('mcp-server-add')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<TRPaneRole>(TRPaneRole.primary)),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<TRPaneRole>(TRPaneRole.secondary)),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('mcp-server-editor-new')),
      findsOne,
    );
    expect(find.text('MCP 서버'), findsNothing);

    final back = find.byKey(const ValueKey<String>('settings-back-button'));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<TRPaneRole>(TRPaneRole.secondary)),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('mcp-server-list')), findsOne);
    expect(find.byKey(const ValueKey<String>('mcp-field-id')), findsNothing);

    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('settings-category-pane-mcp')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('settings-daemon-categories-pane')),
      findsOneWidget,
    );
    expect(find.text('MCP'), findsOneWidget);
    expect(router.state.uri.path, '/settings/daemons/server/categories');

    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('settings-daemon-categories-pane')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('settings-home-pane')),
      findsOneWidget,
    );
    expect(find.text('일반'), findsOneWidget);
    expect(router.state.uri.path, '/settings');
  }, tags: const <String>['feature_test__app_navigation__widget']);

  testWidgets(
    'settings pane roles change only at the shared adaptive boundaries',
    (tester) async {
      await _setTestViewport(tester, const Size(599, 800));
      final api = FakeTinestApi();
      api.mcpServers['github'] = const McpServerStateDto(
        config: McpServerConfigDto(
          id: 'github',
          transport: McpTransportKind.stdio,
          command: 'npx',
        ),
        status: McpServerStatus.ready,
        scope: McpConfigScope.user,
        sourcePath: '/config/mcp.json',
      );
      final router = await _pumpRoute(
        tester,
        api,
        const McpSettingsRoute(hostId: 'server').location,
      );
      addTearDown(router.dispose);

      Future<void> expectRoles(
        double width, {
        required int paneCount,
        required bool collection,
        required bool detail,
      }) async {
        tester.view.physicalSize = Size(width, 800);
        await tester.pumpAndSettle();
        final scope = tester.widget<TRAdaptiveLayoutScope>(
          find.byType(TRAdaptiveLayoutScope),
        );
        expect(
          scope.widthClass,
          TRAdaptiveWidthClass.fromWidth(width),
          reason: 'viewport width class at $width logical pixels',
        );
        expect(
          find.byType(TRAdaptivePane),
          findsNWidgets(paneCount),
          reason: 'pane count at $width logical pixels',
        );
        final verticalSeparators = find.byWidgetPredicate(
          (widget) =>
              widget is TRSeparator &&
              widget.orientation == TRSeparatorOrientation.vertical,
        );
        expect(
          verticalSeparators,
          findsNWidgets(paneCount - 1),
          reason: 'separator count at $width logical pixels',
        );
        for (final separator in verticalSeparators.evaluate()) {
          expect(
            separator.size?.width,
            TRControlMetrics.borderWidth,
            reason: 'separator token width at $width logical pixels',
          );
        }
        expect(
          TRUiDensityScope.of(
            tester.element(find.byType(TRAdaptiveLayoutScope)),
          ),
          paneCount == 1 ? TRUiDensity.comfortable : TRUiDensity.standard,
          reason: 'UI density at $width logical pixels',
        );
        expect(
          find.byKey(const ValueKey<String>('settings-sidebar-surface')),
          paneCount > 1 ? findsOneWidget : findsNothing,
          reason: 'navigation role at $width logical pixels',
        );
        if (paneCount > 1) {
          expect(
            tester
                .getSize(
                  find.byKey(
                    const ValueKey<String>('settings-sidebar-surface'),
                  ),
                )
                .width,
            TinestLayoutMetrics.settingsSidebarWidth,
            reason: 'navigation token width at $width logical pixels',
          );
        }
        expect(
          find.byKey(const ValueKey<String>('mcp-server-list')),
          collection ? findsOneWidget : findsNothing,
          reason: 'collection role at $width logical pixels',
        );
        expect(
          find.byKey(const ValueKey<String>('mcp-server-editor-github')),
          detail ? findsOneWidget : findsNothing,
          reason: 'detail role at $width logical pixels',
        );
        if (paneCount == 3) {
          expect(
            tester
                .getSize(find.byKey(const ValueKey<String>('mcp-server-list')))
                .width,
            TinestLayoutMetrics.settingsCollectionWidth,
            reason: 'collection token width at $width logical pixels',
          );
        }
      }

      await expectRoles(599, paneCount: 1, collection: true, detail: false);
      for (final width in <double>[600, 839, 840, 1199]) {
        await expectRoles(width, paneCount: 2, collection: true, detail: false);
      }
      await expectRoles(1200, paneCount: 3, collection: true, detail: true);

      // Resizing keeps the selected server active. Narrow layouts replace the
      // collection with the secondary role rather than reclassifying the
      // already allocated content pane.
      for (final width in <double>[1199, 840, 839, 600]) {
        await expectRoles(width, paneCount: 2, collection: false, detail: true);
      }
      await expectRoles(599, paneCount: 1, collection: false, detail: true);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TRAdaptivePane), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('mcp-server-list')), findsOne);
      expect(
        find.byKey(const ValueKey<String>('mcp-server-editor-github')),
        findsNothing,
      );
    },
    tags: const <String>['feature_test__app_navigation__widget'],
  );

  testWidgets(
    'Android predictive Back cancels detail preview and commits to the list',
    (tester) async {
      await _setTestViewport(tester, const Size(390, 844));
      final api = FakeTinestApi();
      api.mcpServers['github'] = const McpServerStateDto(
        config: McpServerConfigDto(
          id: 'github',
          transport: McpTransportKind.stdio,
          command: 'npx',
        ),
        status: McpServerStatus.ready,
        scope: McpConfigScope.user,
        sourcePath: '/config/mcp.json',
      );
      final router = await _pumpRoute(
        tester,
        api,
        const McpSettingsRoute(hostId: 'server').location,
      );
      addTearDown(router.dispose);

      await tester.tap(
        find.byKey(const ValueKey<String>('mcp-server-tile-github')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('mcp-server-editor-github')),
        findsOneWidget,
      );
      final editor = find.byKey(
        const ValueKey<String>('mcp-server-editor-github'),
      );
      final settledEditorRect = tester.getRect(editor);

      Future<void> send(MethodCall call) async {
        final message = const StandardMethodCodec().encodeMethodCall(call);
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/backgesture',
          message,
          (_) {},
        );
        await tester.pump();
      }

      const start = MethodCall('startBackGesture', <String, Object>{
        'touchOffset': <double>[0, 422],
        'progress': 0.0,
        'swipeEdge': 0,
      });
      const update = MethodCall('updateBackGestureProgress', <String, Object>{
        'x': 195.0,
        'y': 422.0,
        'progress': 0.5,
        'swipeEdge': 0,
      });

      await send(start);
      await send(update);
      final list = find.byKey(const ValueKey<String>('mcp-server-list'));
      expect(tester.getTopLeft(list).dx, 0);
      expect(
        tester.getRect(editor),
        isNot(settledEditorRect),
        reason: 'Flutter must expose predictive gesture progress',
      );

      // The detail page carries its own background, so the shrinking route
      // hides the list instead of compositing over it. Scoped to the inner
      // Navigator: the shell paints a surface too, but it does not move.
      final detailSurface = find
          .descendant(
            of: find.byType(SettingsListDetailHost),
            matching: find.ancestor(
              of: editor,
              matching: find.byType(TRSurface),
            ),
          )
          .first;
      expect(detailSurface, findsOneWidget);
      final detailRect = tester.getRect(detailSurface);
      final editorRect = tester.getRect(editor);
      expect(detailRect.left, lessThanOrEqualTo(editorRect.left));
      expect(detailRect.top, lessThanOrEqualTo(editorRect.top));
      expect(detailRect.right, greaterThanOrEqualTo(editorRect.right));
      expect(detailRect.bottom, greaterThanOrEqualTo(editorRect.bottom));
      expect(
        detailRect,
        isNot(tester.getRect(list)),
        reason: 'the detail surface must move with the outgoing route',
      );

      await send(const MethodCall('cancelBackGesture'));
      await tester.pumpAndSettle();
      expect(editor, findsOneWidget);
      expect(tester.getRect(editor), settledEditorRect);

      await send(start);
      await send(update);
      expect(tester.getRect(editor), isNot(settledEditorRect));
      await send(const MethodCall('commitBackGesture'));
      await tester.pumpAndSettle();
      expect(list, findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('mcp-server-editor-github')),
        findsNothing,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
    tags: const <String>['feature_test__app_navigation__widget'],
  );
}
