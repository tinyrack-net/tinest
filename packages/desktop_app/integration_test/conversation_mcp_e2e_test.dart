import 'package:app/testing/app/tinest_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import 'support/pump_until.dart';
import 'support/real_daemon_fixture.dart';
import 'support/settings_navigation.dart';
import 'support/tap_visible.dart';

/// The MCP server lifecycle, driven entirely through the settings UI.
///
/// Split out of `conversation`, which ran this as one leg of a single 3,800
/// line test case. That made it the longest scenario in the catalog by a
/// factor of four and, because a scenario is one test, nothing in it could run
/// in parallel: the shard held a single lane for its whole duration. This leg
/// needs a daemon and the settings route and none of that test's workspace,
/// skills, worktrees, or sessions, so it stands on its own.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a failing MCP server is repaired, discovered, and removed from settings',
    (tester) async {
      final fixture = await RealDaemonFixture.start(id: 'conversation-mcp');
      addTearDown(fixture.dispose);
      final assertions = await fixture.connect();
      addTearDown(assertions.close);

      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(TinestApp(services: fixture.services));
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pumpAndSettle();
      await tapVisible(
        tester,
        find.byKey(const ValueKey<String>('workspace-settings-button')),
        'the workspace settings button',
      );
      await tester.pumpAndSettle();

      // Scoped to the sidebar: the agent editor behind it also has a row
      // labelled MCP, the group its resource tools are toggled in.
      await openSettingsCategory(tester, 'agent');
      await openSettingsCategory(tester, 'mcp');
      await pumpUntil(tester, find.text('MCP 서버'));
      await tester.pumpAndSettle();

      // A command that cannot start is the failure a user actually hits, and
      // the editor has to say so rather than accept the server.
      await tester.tap(find.byKey(const ValueKey('mcp-server-add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('mcp-field-id')), 'e2e');
      await tester.enterText(
        find.byKey(const ValueKey('mcp-field-command')),
        '/nonexistent/mcp-server',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      final saveServer = find.byKey(const ValueKey('mcp-server-save'));
      await tester.ensureVisible(saveServer);
      await tester.pumpAndSettle();
      final testServer = find.byKey(const ValueKey<String>('mcp-server-test'));
      await tester.ensureVisible(testServer);
      await tester.tap(testServer);
      await pumpUntil(
        tester,
        find.byKey(const ValueKey<String>('mcp-editor-error')),
      );
      await pumpUntilCondition(
        tester,
        () => tester.widget<TRButton>(testServer).onPressed != null,
        'the failed MCP probe to release the editor',
      );

      // Repairing it is a text edit and a secret, both through the UI.
      await replaceMcpFieldText(tester, 'mcp-field-command', dartExecutable());
      await replaceMcpFieldText(tester, 'mcp-field-args', fakeMcpServerPath());
      await replaceMcpFieldText(
        tester,
        'mcp-field-env',
        r'MCP_ECHO_PREFIX=${secret:e2e.prefix}',
      );
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(const ValueKey('mcp-field-command')),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        dartExecutable(),
      );
      final setSecret = find.byKey(const ValueKey<String>('mcp-secret-set'));
      await tester.ensureVisible(setSecret);
      await pumpUntil(tester, setSecret.hitTestable());
      await tester.tap(setSecret.hitTestable());
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('mcp-secret-key')),
        'e2e.prefix',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('mcp-secret-value')),
        'secret-',
      );
      await tester.tap(find.byKey(const ValueKey<String>('mcp-secret-save')));
      await tester.pumpAndSettle();

      // Testing before saving is the point: the editor probes what is on
      // screen, not what is persisted.
      await tester.ensureVisible(testServer);
      await tester.tap(testServer);
      await tester.pump();
      final mcpTestNotice = find.byKey(
        const ValueKey<String>('mcp-editor-notice'),
      );
      final mcpTestError = find.byKey(
        const ValueKey<String>('mcp-editor-error'),
      );
      expect(mcpTestError, findsNothing);
      await pumpUntilCondition(
        tester,
        () =>
            mcpTestNotice.evaluate().isNotEmpty ||
            mcpTestError.evaluate().isNotEmpty,
        'the repaired unsaved MCP test to finish',
      );
      if (mcpTestError.evaluate().isNotEmpty) {
        throw TestFailure(
          'Repaired unsaved MCP test failed: '
          '${tester.widget<Text>(mcpTestError).data}',
        );
      }

      await tester.ensureVisible(saveServer);
      await tester.tap(saveServer);
      await pumpUntilCondition(tester, () async {
        final servers = await assertions.mcp.listMcpServers();
        if (servers.isEmpty) return false;
        final server = servers.single;
        if (server.status == McpServerStatus.failed &&
            server.config.command == dartExecutable()) {
          throw TestFailure(
            'Repaired MCP server failed: ${server.error}; '
            'args=${server.config.args}; env=${server.config.env}',
          );
        }
        return server.status == McpServerStatus.ready;
      }, 'the repaired MCP server to become ready');
      await tester.pumpAndSettle();
      expect(
        (await assertions.mcp.listMcpServers()).single.tools.single.toolId,
        'mcp__e2e__echo',
      );

      // The server refresh can briefly remove the selected row while the
      // daemon replaces its loading snapshot with the ready one. Re-select
      // the persisted server before exercising its detail-only actions.
      final savedServerTile = find.byKey(const ValueKey('mcp-server-tile-e2e'));
      await pumpUntil(tester, savedServerTile.hitTestable());
      await tester.tap(savedServerTile.hitTestable());
      await tester.pumpAndSettle();
      final deleteServer = find.byKey(const ValueKey('mcp-server-delete'));
      await centerSettingsAction(tester, deleteServer);
      // The save reported itself over the bottom-trailing corner, which is
      // where this button sits. Waiting the report out is what a user does
      // before reaching underneath it, and it doubles as proof that a toast
      // gives the surface back on its own.
      await pumpUntilGone(tester, find.text('저장했습니다.'));
      await tapVisible(tester, deleteServer, 'the MCP server delete action');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mcp-delete-confirm')));
      await pumpUntilGone(
        tester,
        find.byKey(const ValueKey('mcp-server-tile-e2e')),
      );
      expect(await assertions.mcp.listMcpServers(), isEmpty);
    },
    tags: const <String>[
      'feature_test__mcp_server_management__e2e',
      'feature_scenario__mcp_server_management__add_edit_test_remove__e2e',
      // The scenario tag mirrors its typed manifest ID exactly.
      // ignore: lines_longer_than_80_chars
      'feature_scenario__mcp_server_management__offline_and_secret_recovery__e2e',
    ],
  );
}
