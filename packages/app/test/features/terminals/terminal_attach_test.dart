import 'dart:async';

import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/shared/presentation/workspace_skeletons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:termworld/termworld.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/fake_tinest_api.dart';
import '../../support/router_harness.dart';

void main() {
  final now = DateTime.utc(2026, 8, 2);
  final workspace = WorkspaceDto(
    id: 'workspace',
    name: 'Workspace',
    rootPath: '/workspace',
    kind: WorkspaceKind.directory,
    createdAt: now,
  );
  final checkout = WorktreeDto(
    id: 'checkout',
    workspaceId: workspace.id,
    name: workspace.name,
    path: workspace.rootPath,
    kind: WorktreeKind.directory,
    isTinestOwned: false,
    createdAt: now,
  );
  const terminal = TerminalDto(
    id: 'terminal-1',
    worktreeId: 'checkout',
    title: 'Terminal 1',
    shell: ShellSpecDto(executable: '/bin/sh'),
    status: TerminalStatus.running,
    columns: 80,
    rows: 24,
    lastSequence: 0,
  );
  final location = TerminalRoute(
    hostId: 'server',
    workspaceId: workspace.id,
    worktreeId: checkout.id,
    terminalId: terminal.id,
  ).location;

  testWidgets(
    'an attaching terminal shows a connecting state instead of a dead prompt',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
        terminals: const <TerminalDto>[terminal],
        terminalReplay: const <TerminalOutputDto>[
          TerminalOutputDto(terminalId: 'terminal-1', sequence: 1, data: r'$'),
        ],
      )..terminalAttachGate = Completer<void>();
      final router = await pumpRoutedApp(
        tester,
        api,
        initialLocation: location,
        // The connecting spinner animates until the gate opens.
        settle: false,
      );
      addTearDown(router.dispose);

      expect(find.byType(TerminalConnectingOverlay), findsOneWidget);
      expect(find.text('터미널 연결 중'), findsOneWidget);
      expect(find.byType(TerminalView), findsNothing);

      // Typing cannot reach a PTY that is not attached yet, and the overlay
      // says so; nothing is silently swallowed into a dead terminal.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      expect(api.terminalWrites, isEmpty);

      api.terminalAttachGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(TerminalConnectingOverlay), findsNothing);
      expect(find.byType(TerminalView), findsOneWidget);
      expect(api.attachedTerminalIds, <String>[terminal.id]);
    },
    tags: const <String>['feature_test__workspace_async_loading__widget'],
  );

  testWidgets('a failed attachment explains itself and retries on demand', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = FakeTinestApi(
      workspaces: <WorkspaceDto>[workspace],
      worktrees: <WorktreeDto>[checkout],
      terminals: const <TerminalDto>[terminal],
      terminalAttachError: Exception('host unreachable'),
    );
    final router = await pumpRoutedApp(tester, api, initialLocation: location);
    addTearDown(router.dispose);

    expect(find.byType(TRAlert), findsOneWidget);
    expect(find.textContaining('host unreachable'), findsOneWidget);
    expect(find.byType(TerminalView), findsNothing);

    api.terminalAttachError = null;
    await tester.tap(
      find.byKey(const ValueKey<String>('terminal-attach-retry')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TerminalView), findsOneWidget);
    expect(api.attachedTerminalIds, <String>[terminal.id]);
  }, tags: const <String>['feature_test__workspace_async_loading__widget']);
}
