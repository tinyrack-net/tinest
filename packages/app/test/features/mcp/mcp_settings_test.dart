@Tags(<String>['feature_test__mcp_server_management__widget'])
library;

import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/features/mcp/presentation/pages/mcp_settings_page.dart';
import 'package:app/src/shared/presentation/settings_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/fake_tinest_api.dart';
import '../../support/localization.dart';

void main() {
  const stdioServer = McpServerConfigDto(
    id: 'github',
    transport: McpTransportKind.stdio,
    command: 'npx',
    args: <String>['-y', 'server-github'],
    env: <String, String>{'TOKEN': r'${secret:github.token}'},
  );
  const projectServer = McpServerConfigDto(
    id: 'repo',
    transport: McpTransportKind.stdio,
    command: './tools/mcp',
  );

  McpServerStateDto ready(
    McpServerConfigDto config, {
    McpConfigScope scope = McpConfigScope.user,
    bool shadowed = false,
  }) => McpServerStateDto(
    config: config,
    status: shadowed ? McpServerStatus.disabled : McpServerStatus.ready,
    scope: scope,
    shadowed: shadowed,
    sourcePath: scope == McpConfigScope.user
        ? '/config/mcp.json'
        : '/repos/tinest/.mcp.json',
    serverName: config.id,
    tools: <McpToolSummaryDto>[
      McpToolSummaryDto(
        toolId: 'mcp__${config.id}__echo',
        name: 'echo',
        description: 'Echoes its argument.',
      ),
    ],
  );

  Future<GoRouter> pump(
    WidgetTester tester,
    FakeTinestApi api, {
    ThemeMode? themeMode,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: const McpSettingsRoute(hostId: 'server').location,
      routes: $appRoutes,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appServicesProvider.overrideWithValue(fakeAppServices(api)),
        ],
        child: MaterialApp.router(
          theme: testLightTheme,
          darkTheme: testDarkTheme,
          themeMode: themeMode,
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

  testWidgets('an empty daemon invites the first server', (tester) async {
    await pump(tester, FakeTinestApi());

    expect(find.text('MCP 서버'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('mcp-server-list-empty')),
      findsOneWidget,
    );
    expect(
      tester.widget(
        find.byKey(const ValueKey<String>('mcp-server-list-empty')),
      ),
      isA<SettingsEmptyState>(),
    );
    expect(find.text('편집할 서버를 선택하세요.'), findsOneWidget);
  });

  testWidgets('adding a server writes it through the daemon', (tester) async {
    final api = FakeTinestApi();
    await pump(tester, api);

    await tester.tap(find.byKey(const ValueKey<String>('mcp-server-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('mcp-field-id')),
      'github',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('mcp-field-command')),
      'npx',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('mcp-field-args')),
      '-y\nserver-github',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('mcp-field-env')),
      r'TOKEN=${secret:github.token}',
    );
    await tester.tap(find.byKey(const ValueKey<String>('mcp-server-save')));
    await tester.pumpAndSettle();

    final saved = api.mcpServers['github']!.config;
    expect(saved.transport, McpTransportKind.stdio);
    expect(saved.command, 'npx');
    expect(saved.args, <String>['-y', 'server-github']);
    expect(saved.env, <String, String>{'TOKEN': r'${secret:github.token}'});
    expect(saved.enabled, isTrue);
  });

  testWidgets('an unusable server id is refused before saving', (tester) async {
    final api = FakeTinestApi();
    await pump(tester, api);

    await tester.tap(find.byKey(const ValueKey<String>('mcp-server-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('mcp-field-id')),
      'Has__Underscores',
    );
    await tester.tap(find.byKey(const ValueKey<String>('mcp-server-save')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('mcp-editor-error')),
      findsOneWidget,
    );
    expect(api.mcpServers, isEmpty);
  });

  testWidgets('switching transport swaps the fields it needs', (tester) async {
    await pump(tester, FakeTinestApi());

    await tester.tap(find.byKey(const ValueKey<String>('mcp-server-add')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('mcp-field-command')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('mcp-field-url')), findsNothing);

    await tester.tap(find.text('HTTP'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('mcp-field-url')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('mcp-field-headers')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('mcp-field-command')),
      findsNothing,
    );
  });

  testWidgets('a ready server shows its status and tools', (tester) async {
    final api = FakeTinestApi()..mcpServers['github'] = ready(stdioServer);
    await pump(tester, api, themeMode: ThemeMode.dark);

    expect(
      find.byKey(const ValueKey<String>('mcp-server-tile-github')),
      findsOneWidget,
    );
    final status = find.byKey(
      const ValueKey<String>('mcp-server-status-github'),
    );
    expect(
      tester.widget<Icon>(status).color,
      testDarkTheme.extension<TinyrackThemeData>()!.primaryForeground,
    );
    expect(find.byType(TRTreeNav<String>), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('mcp-server-tile-github')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('mcp-tool-tile-mcp__github__echo')),
      findsOneWidget,
    );
    expect(find.text('mcp__github__echo'), findsOneWidget);
  });

  testWidgets(
    'a server publishing resources lists them beside its tools',
    (tester) async {
      final api = FakeTinestApi()
        ..mcpServers['github'] = ready(stdioServer).copyWith(
          resources: const <McpResourceSummaryDto>[
            McpResourceSummaryDto(
              uri: 'file:///repo/README.md',
              name: 'README',
              description: 'How to build.',
            ),
          ],
          resourceTemplates: const <McpResourceTemplateSummaryDto>[
            McpResourceTemplateSummaryDto(
              uriTemplate: 'file:///repo/{path}',
              name: 'Repository file',
            ),
          ],
        );
      await pump(tester, api);
      await tester.tap(
        find.byKey(const ValueKey<String>('mcp-server-tile-github')),
      );
      await tester.pumpAndSettle();

      // Both lists are collapsed so a server with hundreds of resources
      // cannot push the error and diagnostics blocks off screen. The editor
      // carries section headings above them, so reaching either one scrolls
      // first, exactly as the templates list below does.
      final resources = find.byKey(
        const ValueKey<String>('mcp-server-resources'),
      );
      await tester.scrollUntilVisible(
        resources,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(resources);
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey<String>('mcp-resource-tile-file:///repo/README.md'),
        ),
        findsOneWidget,
      );

      final templates = find.byKey(
        const ValueKey<String>('mcp-server-resource-templates'),
      );
      await tester.scrollUntilVisible(
        templates,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(templates);
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey<String>(
            'mcp-resource-template-tile-file:///repo/{path}',
          ),
        ),
        findsOneWidget,
      );
    },
    tags: const <String>['feature_test__mcp_resource_access__widget'],
  );

  testWidgets(
    'a server without resources says so instead of showing nothing',
    (tester) async {
      final api = FakeTinestApi()..mcpServers['github'] = ready(stdioServer);
      await pump(tester, api);
      await tester.tap(
        find.byKey(const ValueKey<String>('mcp-server-tile-github')),
      );
      await tester.pumpAndSettle();

      final resources = find.byKey(
        const ValueKey<String>('mcp-server-resources'),
      );
      await tester.scrollUntilVisible(
        resources,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(resources);
      await tester.pumpAndSettle();
      expect(find.text('게시된 리소스가 없습니다.'), findsOneWidget);
    },
    tags: const <String>['feature_test__mcp_resource_access__widget'],
  );

  testWidgets('a failed server surfaces its reason and output', (tester) async {
    final api = FakeTinestApi()
      ..mcpServers['github'] = const McpServerStateDto(
        config: stdioServer,
        status: McpServerStatus.failed,
        scope: McpConfigScope.user,
        sourcePath: '/config/mcp.json',
        error: 'the server exited with code 127',
        diagnostics: <String>['npx: command not found'],
      );
    await pump(tester, api, themeMode: ThemeMode.dark);
    final status = find.byKey(
      const ValueKey<String>('mcp-server-status-github'),
    );
    expect(
      tester.widget<Icon>(status).color,
      testDarkTheme.extension<TinyrackThemeData>()!.dangerForeground,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('mcp-server-tile-github')),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('mcp-server-diagnostics')),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('the server exited with code 127'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('mcp-server-diagnostics')),
      findsOneWidget,
    );
  });

  testWidgets('a project server is shown read-only with its source', (
    tester,
  ) async {
    final api = FakeTinestApi()
      ..mcpServers['repo'] = ready(
        projectServer,
        scope: McpConfigScope.project,
      );
    await pump(tester, api);

    expect(find.byType(TRTreeNav<String>), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('mcp-server-tile-repo')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('mcp-server-readonly')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('mcp-server-source-repo')),
      findsOneWidget,
    );
    // A repository's server offers no edit affordances at all.
    expect(find.byKey(const ValueKey<String>('mcp-server-save')), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('mcp-server-delete')),
      findsNothing,
    );
    final command = tester.widget<TRTextField>(
      find.byKey(const ValueKey<String>('mcp-field-command')),
    );
    expect(command.enabled, isFalse);
  });

  testWidgets('a shadowed project server warns why it is off', (tester) async {
    final api = FakeTinestApi()
      ..mcpServers['user'] = ready(stdioServer)
      ..mcpServers['repo'] = ready(
        projectServer,
        scope: McpConfigScope.project,
        shadowed: true,
      );
    await pump(tester, api);
    await tester.tap(
      find.byKey(const ValueKey<String>('mcp-server-tile-repo')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('mcp-server-shadowed-repo')),
      findsOneWidget,
    );
  });

  testWidgets('testing a connection reports what it found', (tester) async {
    final api = FakeTinestApi()..mcpServers['github'] = ready(stdioServer);
    await pump(tester, api);
    await tester.tap(
      find.byKey(const ValueKey<String>('mcp-server-tile-github')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('mcp-server-test')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('mcp-editor-notice')),
      findsOneWidget,
    );
    expect(find.textContaining('도구 1개'), findsOneWidget);
  });

  testWidgets('deleting asks first, then removes the server', (tester) async {
    final api = FakeTinestApi()..mcpServers['github'] = ready(stdioServer);
    await pump(tester, api);
    await tester.tap(
      find.byKey(const ValueKey<String>('mcp-server-tile-github')),
    );
    await tester.pumpAndSettle();

    final delete = find.byKey(const ValueKey<String>('mcp-server-delete'));
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
    expect(
      find.byKey(const ValueKey<String>('mcp-delete-dialog')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TRButton>(
            find.byKey(const ValueKey<String>('mcp-delete-confirm')),
          )
          .intent,
      TRIntent.danger,
    );
    await tester.tap(find.byKey(const ValueKey<String>('mcp-delete-confirm')));
    await tester.pumpAndSettle();

    expect(api.mcpServers, isEmpty);
  });

  testWidgets('a secret is stored without appearing in the config', (
    tester,
  ) async {
    final api = FakeTinestApi()..mcpServers['github'] = ready(stdioServer);
    await pump(tester, api);
    await tester.tap(
      find.byKey(const ValueKey<String>('mcp-server-tile-github')),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('mcp-secret-set')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const ValueKey<String>('mcp-secret-set')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('mcp-secret-key')),
      'github.token',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('mcp-secret-value')),
      'ghp-secret',
    );
    await tester.tap(find.byKey(const ValueKey<String>('mcp-secret-save')));
    await tester.pumpAndSettle();

    expect(api.mcpSecrets, <String, String>{'github.token': 'ghp-secret'});
    // The configuration still references the secret rather than holding it.
    expect(
      api.mcpServers['github']!.config.env['TOKEN'],
      r'${secret:github.token}',
    );
  });

  group('field parsing', () {
    test('multi-line fields round-trip through their maps', () {
      expect(parseMcpLines('a\n\n  b  \n'), <String>['a', 'b']);
      expect(parseMcpPairs('A=1\nB=x=y\nbroken', '='), <String, String>{
        'A': '1',
        'B': 'x=y',
      });
      expect(
        parseMcpPairs('Authorization: Bearer x\nX-Trace:on', ':'),
        <String, String>{'Authorization': 'Bearer x', 'X-Trace': 'on'},
      );
      expect(
        formatMcpPairs(const <String, String>{'A': '1'}, '='),
        'A=1',
      );
      expect(formatMcpPairs(null, '='), isEmpty);
    });

    test('a server id must survive tool-name namespacing', () {
      expect(isValidMcpServerId('github'), isTrue);
      expect(isValidMcpServerId('git-hub_1'), isTrue);
      expect(isValidMcpServerId(''), isFalse);
      expect(isValidMcpServerId('Uppercase'), isFalse);
      expect(isValidMcpServerId('-leading'), isFalse);
      expect(isValidMcpServerId('has__separator'), isFalse);
      expect(isValidMcpServerId('a' * 41), isFalse);
    });
  });
}
