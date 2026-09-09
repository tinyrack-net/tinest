@Tags(<String>[
  'feature_test__terminal_lifecycle__unit',
  'feature_test__terminal_lifecycle__widget',
])
library;

import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/sessions/application/session_tabs_controller.dart';
import 'package:app/src/features/terminals/application/terminal_session_controller.dart';
import 'package:app/src/features/terminals/application/terminal_session_leases.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:termworld/termworld.dart';

import '../../support/fake_tinest_api.dart';
import '../../support/provider_lifetime_recorder.dart';
import '../../support/router_harness.dart';

final _now = DateTime.utc(2026, 8, 11);
final _workspace = WorkspaceDto(
  id: 'workspace',
  name: 'Tinest',
  rootPath: '/repos/tinest',
  kind: WorkspaceKind.git,
  createdAt: _now,
);

WorktreeDto _worktree(String id, String branch) => WorktreeDto(
  id: id,
  workspaceId: _workspace.id,
  name: branch,
  path: '/repos/tinest-$id',
  branch: branch,
  head: 'abc',
  kind: WorktreeKind.checkout,
  isTinestOwned: false,
  createdAt: _now,
);

TerminalDto _terminal(String id, String worktreeId) => TerminalDto(
  id: id,
  worktreeId: worktreeId,
  title: id,
  shell: const ShellSpecDto(executable: '/bin/sh'),
  status: TerminalStatus.running,
  columns: 80,
  rows: 24,
  lastSequence: 0,
);

WorkspaceSelection _selection(String worktreeId) => WorkspaceSelection(
  hostId: 'server',
  workspaceId: _workspace.id,
  worktreeId: worktreeId,
);

String _terminalLocation(String worktreeId, String terminalId) => TerminalRoute(
  hostId: 'server',
  workspaceId: _workspace.id,
  worktreeId: worktreeId,
  terminalId: terminalId,
).location;

String _worktreeLocation(String worktreeId) => WorktreeRoute(
  hostId: 'server',
  workspaceId: _workspace.id,
  worktreeId: worktreeId,
).location;

FakeTinestApi _api() => FakeTinestApi(
  workspaces: <WorkspaceDto>[_workspace],
  worktrees: <WorktreeDto>[
    _worktree('checkout-a', 'main'),
    _worktree('checkout-b', 'feature'),
  ],
  terminals: <TerminalDto>[
    _terminal('terminal-a', 'checkout-a'),
    _terminal('terminal-a2', 'checkout-a'),
    _terminal('terminal-b', 'checkout-b'),
  ],
);

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(MaterialApp)),
  listen: false,
);

Future<void> _flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  // The whole redesign rests on one property of Riverpod 3.3.2: ending a
  // lifetime by `invalidate` schedules a refresh through `setState`, while an
  // auto-disposed lifetime is drained in a microtask. An auto-disposed session
  // therefore *cannot* be ended by the call that caused the build-phase crash.
  // No static rule can express this, because the verifier cannot see a
  // provider's type — so it is asserted here.
  test('a terminal session is auto-disposed, never invalidated', () {
    expect(
      terminalSessionControllerProvider('server', 'terminal-a').isAutoDispose,
      isTrue,
    );
    expect(
      terminalSessionLeasesProvider(_selection('checkout-a')).isAutoDispose,
      isTrue,
    );
  });

  testWidgets('leaving a checkout ends its terminal sessions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final lifetimes = ProviderLifetimeRecorder();
    final router = await pumpRoutedApp(
      tester,
      _api(),
      observers: <ProviderObserver>[lifetimes],
      initialLocation: _terminalLocation('checkout-a', 'terminal-a'),
    );
    addTearDown(router.dispose);
    await _flush(tester);

    final session = terminalSessionControllerProvider('server', 'terminal-a');
    final leases = terminalSessionLeasesProvider(_selection('checkout-a'));
    expect(lifetimes.isAlive(session), isTrue);
    expect(lifetimes.isAlive(leases), isTrue);

    router.go(_worktreeLocation('checkout-b'));
    await tester.pumpAndSettle();

    // Leaving a checkout is what bounds the number of live terminals, and now
    // that bound is a property of the graph rather than of a widget callback.
    expect(lifetimes.isAlive(session), isFalse);
    expect(lifetimes.isAlive(leases), isFalse);
  });

  testWidgets('a trip to settings keeps the very same emulator', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final lifetimes = ProviderLifetimeRecorder();
    final router = await pumpRoutedApp(
      tester,
      _api(),
      observers: <ProviderObserver>[lifetimes],
      initialLocation: _terminalLocation('checkout-a', 'terminal-a'),
    );
    addTearDown(router.dispose);
    await _flush(tester);

    final container = _container(tester);
    final session = terminalSessionControllerProvider('server', 'terminal-a');
    final before = container.read(session).terminal;

    await tester.tap(
      find.byKey(const ValueKey<String>('workspace-settings-button')),
    );
    await tester.pumpAndSettle();
    router.pop();
    await _flush(tester);

    expect(lifetimes.isAlive(session), isTrue);
    expect(identical(container.read(session).terminal, before), isTrue);
  });

  // The lease provider rebuilds whenever the open set changes, and during that
  // rebuild every session momentarily loses its listener. This is the test
  // that proves a surviving sibling is not collected in that window.
  testWidgets('closing one terminal tab leaves its sibling untouched', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final lifetimes = ProviderLifetimeRecorder();
    final router = await pumpRoutedApp(
      tester,
      _api(),
      observers: <ProviderObserver>[lifetimes],
      initialLocation: _terminalLocation('checkout-a', 'terminal-a'),
    );
    addTearDown(router.dispose);
    router.go(_terminalLocation('checkout-a', 'terminal-a2'));
    await _flush(tester);

    final container = _container(tester);
    final selection = _selection('checkout-a');
    final closing = terminalSessionControllerProvider('server', 'terminal-a2');
    final surviving = terminalSessionControllerProvider('server', 'terminal-a');
    final before = container.read(surviving).terminal;
    expect(container.read(openTerminalIdsProvider(selection)), <String>{
      'terminal-a',
      'terminal-a2',
    });

    await container
        .read(sessionTabsControllerProvider(selection).notifier)
        .closeTerminal('terminal-a2');
    await _flush(tester);

    expect(lifetimes.isAlive(closing), isFalse);
    expect(lifetimes.isAlive(surviving), isTrue);
    expect(identical(container.read(surviving).terminal, before), isTrue);
    expect(container.read(surviving).terminal, isA<Terminal>());
  });

  testWidgets('an unchanged tab set yields the identical id set', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final lifetimes = ProviderLifetimeRecorder();
    final router = await pumpRoutedApp(
      tester,
      _api(),
      observers: <ProviderObserver>[lifetimes],
      initialLocation: _terminalLocation('checkout-a', 'terminal-a'),
    );
    addTearDown(router.dispose);
    router.go(_terminalLocation('checkout-a', 'terminal-a2'));
    await _flush(tester);

    final container = _container(tester);
    final selection = _selection('checkout-a');
    final ids = openTerminalIdsProvider(selection);
    final before = container.read(ids);

    // Switching tabs republishes the whole tab registry. If that produced a new
    // set instance, every lease would be dropped and re-taken on each switch,
    // resetting the emulators this design exists to preserve.
    router.go(_terminalLocation('checkout-a', 'terminal-a'));
    await _flush(tester);

    expect(identical(container.read(ids), before), isTrue);
  });

  testWidgets('a reload frame does not read as every terminal closed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final lifetimes = ProviderLifetimeRecorder();
    final router = await pumpRoutedApp(
      tester,
      _api(),
      observers: <ProviderObserver>[lifetimes],
      initialLocation: _terminalLocation('checkout-a', 'terminal-a'),
    );
    addTearDown(router.dispose);
    await _flush(tester);

    final container = _container(tester);
    final selection = _selection('checkout-a');
    final ids = openTerminalIdsProvider(selection);
    expect(container.read(ids), <String>{'terminal-a'});

    // A reload carries no value. Reading that as "the user closed everything"
    // would tear down live terminals on any refresh of the tab state.
    container.invalidate(sessionTabsControllerProvider(selection));
    expect(container.read(ids), <String>{'terminal-a'});
    expect(
      lifetimes.isAlive(
        terminalSessionControllerProvider('server', 'terminal-a'),
      ),
      isTrue,
    );
    await _flush(tester);
  });
}
