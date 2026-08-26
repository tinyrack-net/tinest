import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/app/composition/app_services.dart';
import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/app/tinest_app.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/hosts/domain/host_ports.dart';
import 'package:client/client.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:termworld/termworld.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/fake_desktop_ports.dart';
import '../../support/fake_tinest_api.dart';
import '../../support/localization.dart';

final _now = DateTime.utc(2026, 8, 3);
final _workspace = WorkspaceDto(
  id: 'workspace',
  name: 'Tinest',
  rootPath: '/repos/tinest',
  kind: WorkspaceKind.git,
  createdAt: _now,
);
final _worktree = WorktreeDto(
  id: 'checkout',
  workspaceId: 'workspace',
  name: 'main',
  path: '/repos/tinest',
  branch: 'main',
  head: 'abc',
  kind: WorktreeKind.checkout,
  isTinestOwned: false,
  createdAt: _now,
);
const _terminal = TerminalDto(
  id: 'terminal-menu',
  worktreeId: 'checkout',
  title: 'Remote terminal',
  shell: ShellSpecDto(executable: '/bin/sh'),
  status: TerminalStatus.running,
  columns: 80,
  rows: 24,
  lastSequence: 0,
);

/// Records the menu it was asked to present instead of opening anything.
///
/// A menu the operating system draws lives outside the Flutter tree, so this is
/// the only way a test can see what was handed over.
final class _RecordingPresenter implements TRContextMenuPresenter {
  final openings = <List<TRMenuElement>>[];
  VoidCallback? _onClose;

  List<String> get lastIds => <String>[
    for (final element in openings.last)
      if (element case TRMenuActionElement(:final id)) id else '-',
  ];

  void dismiss() {
    _onClose?.call();
    _onClose = null;
  }

  void select(String id) {
    final action = openings.last
        .whereType<TRMenuActionElement>()
        .singleWhere((element) => element.id == id)
        .onPressed;
    dismiss();
    action();
  }

  @override
  Widget buildHost({
    required Widget child,
    required TRMenuElementsBuilder itemsBuilder,
    required TRContextMenuController controller,
    required bool enabled,
    required bool useRootOverlay,
    VoidCallback? onOpen,
    VoidCallback? onClose,
  }) => _RecordingHost(
    presenter: this,
    controller: controller,
    itemsBuilder: itemsBuilder,
    onClose: onClose,
    child: child,
  );
}

final class _RecordingHost extends StatefulWidget {
  const _RecordingHost({
    required this.presenter,
    required this.controller,
    required this.itemsBuilder,
    required this.child,
    this.onClose,
  });

  final _RecordingPresenter presenter;
  final TRContextMenuController controller;
  final TRMenuElementsBuilder itemsBuilder;
  final Widget child;
  final VoidCallback? onClose;

  @override
  State<_RecordingHost> createState() => _RecordingHostState();
}

final class _RecordingHostState extends State<_RecordingHost>
    implements TRContextMenuHost {
  @override
  void initState() {
    super.initState();
    widget.controller.attach(this);
  }

  @override
  void dispose() {
    widget.controller.detach(this);
    super.dispose();
  }

  @override
  void openAt(Offset globalPosition) {
    widget.presenter
      ..openings.add(widget.itemsBuilder(context))
      .._onClose = widget.onClose;
  }

  @override
  void close() {}

  @override
  bool get isOpen => false;

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<void> _openTerminalMenu(WidgetTester tester) async {
  final surface = find.byKey(const ValueKey<String>('tr-terminal-surface'));
  final gesture = await tester.startGesture(
    tester.getTopLeft(surface) + const Offset(24, 24),
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryButton,
  );
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<FakeTinestApi> _pumpTerminal(
  WidgetTester tester, {
  required TRContextMenuPresenter presenter,
  TRUiDensity density = TRUiDensity.standard,
}) async {
  final api = FakeTinestApi(
    workspaces: <WorkspaceDto>[_workspace],
    worktrees: <WorktreeDto>[_worktree],
    terminals: const <TerminalDto>[_terminal],
    terminalReplay: const <TerminalOutputDto>[
      TerminalOutputDto(
        terminalId: 'terminal-menu',
        sequence: 1,
        data: 'selectable output',
      ),
    ],
  );
  final router = GoRouter(
    initialLocation: TerminalRoute(
      hostId: 'server',
      workspaceId: _workspace.id,
      worktreeId: _worktree.id,
      terminalId: _terminal.id,
    ).location,
    routes: $appRoutes,
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [appServicesProvider.overrideWithValue(fakeAppServices(api))],
      child: TRContextMenuPresenterScope(
        presenter: presenter,
        child: MaterialApp.router(
          theme: testLightTheme,
          darkTheme: testDarkTheme,
          locale: testLocale,
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          builder: (context, child) => TRUiDensityScope(
            density: density,
            child: child!,
          ),
          routerConfig: router,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets(
    'the composition root installs the system-menu presenter',
    (tester) async {
      final store = MemoryAppStore(
        settings: const AppSettings(embeddedDaemonEnabled: false),
      );
      late TRContextMenuPresenter resolved;
      await tester.pumpWidget(
        TinestApp(
          services: AppServices(
            settings: store,
            profiles: store,
            credentials: store,
            clients: const _OfflineClients(),
            clientKind: 'test',
          ),
          autostart: FakeAutostartRegistration(),
        ),
      );
      await tester.pumpAndSettle();

      // Reading it from inside the running app is what proves the scope really
      // wraps the router, rather than that the constant exists.
      resolved = TRContextMenuPresenterScope.of(
        tester.element(find.byType(Router<Object>)),
      );

      expect(resolved, isA<TRNativeContextMenuPresenter>());
    },
    tags: const <String>['feature_test__terminal_lifecycle__widget'],
  );

  for (final (name, size) in <(String, Size)>[
    ('desktop', const Size(1100, 760)),
    ('mobile', const Size(390, 780)),
  ]) {
    testWidgets(
      'the terminal describes its menu to the installed presenter on $name',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final presenter = _RecordingPresenter();

        await _pumpTerminal(tester, presenter: presenter);
        await _openTerminalMenu(tester);

        expect(presenter.openings, hasLength(1));
        expect(presenter.lastIds, <String>[
          'terminal-menu-copy',
          'terminal-menu-paste',
          '-',
          'terminal-menu-select-all',
          'terminal-menu-clear-selection',
          '-',
          'terminal-menu-clear-screen',
        ]);
        expect(
          find.byType(TRMenuItem),
          findsNothing,
          reason: 'the presenter took the menu, so Flutter drew none',
        );
      },
      tags: const <String>['feature_test__terminal_lifecycle__widget'],
    );
  }

  testWidgets(
    'the terminal receives Tinyrack presentation tokens',
    (tester) async {
      await _pumpTerminal(tester, presenter: _RecordingPresenter());

      final finder = find.byType(TerminalView);
      final terminal = tester.widget<TerminalView>(finder);
      final colors = tester.element(finder).tinyrackTheme;
      final theme = terminal.theme!;
      final style = terminal.style!;

      expect(terminal.terminal.options.rightClickSelectsWord, isFalse);
      expect(theme.background, colors.surface);
      expect(theme.foreground, colors.text);
      expect(theme.cursor, colors.focus);
      expect(theme.cursorAccent, colors.surface);
      expect(theme.selection, colors.surfaceSelected);
      expect(theme.selectionInactive, colors.surfaceSelected);
      expect(theme.palette, hasLength(256));
      expect(theme.palette.take(16), <Color>[
        colors.surface,
        colors.dangerForeground,
        colors.successForeground,
        colors.warningForeground,
        colors.infoForeground,
        colors.primaryForeground,
        colors.infoBorder,
        colors.text,
        colors.textMuted,
        colors.dangerBorder,
        colors.successBorder,
        colors.warningBorder,
        colors.infoBorder,
        colors.primaryForeground,
        colors.infoForeground,
        colors.text,
      ]);
      expect(
        theme.palette.skip(16),
        TerminalThemes.defaultTheme.palette.skip(16),
      );
      expect(style.fontSize, TRTypography.code.fontSize);
      expect(style.height, TRTypography.code.height);
      expect(style.fontFamily, TRTypography.code.fontFamily);
      expect(style.fontWeight, TRTypography.code.fontWeight);
      expect(style.letterSpacing, TRTypography.code.letterSpacing);
      expect(terminal.padding, const EdgeInsets.all(TRSpacing.small));
    },
    tags: const <String>['feature_test__terminal_lifecycle__widget'],
  );

  testWidgets(
    'viewport changes resize the attached terminal',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = await _pumpTerminal(
        tester,
        presenter: _RecordingPresenter(),
      );
      api.terminalResizes.clear();

      await tester.binding.setSurfaceSize(const Size(800, 600));
      await tester.pumpAndSettle();

      expect(api.terminalResizes, isNotEmpty);
      final resize = api.terminalResizes.last;
      expect(resize.terminalId, _terminal.id);
      expect(resize.columns, greaterThan(0));
      expect(resize.rows, greaterThan(0));
    },
    tags: const <String>['feature_test__terminal_lifecycle__widget'],
  );

  testWidgets(
    'comfortable density enlarges terminal code typography',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpTerminal(
        tester,
        presenter: _RecordingPresenter(),
        density: TRUiDensity.comfortable,
      );

      expect(
        tester.widget<TerminalView>(find.byType(TerminalView)).style!.fontSize,
        16,
      );
    },
    tags: const <String>['feature_test__terminal_lifecycle__widget'],
  );

  testWidgets(
    'mouse reporting suppresses the terminal context menu',
    (tester) async {
      final presenter = _RecordingPresenter();
      final api = await _pumpTerminal(tester, presenter: presenter);
      api.emit(
        const TerminalOutputClientEvent(
          TerminalOutputDto(
            terminalId: 'terminal-menu',
            sequence: 2,
            data: '\x1b[?1000h',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _openTerminalMenu(tester);

      expect(presenter.openings, isEmpty);
    },
    tags: const <String>['feature_test__terminal_lifecycle__widget'],
  );

  testWidgets(
    'copy and clear-selection follow the selection the terminal reports',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final presenter = _RecordingPresenter();

      await _pumpTerminal(tester, presenter: presenter);
      await _openTerminalMenu(tester);

      bool enabled(List<TRMenuElement> menu, String id) => menu
          .whereType<TRMenuActionElement>()
          .firstWhere((e) => e.id == id)
          .enabled;

      expect(enabled(presenter.openings.last, 'terminal-menu-copy'), isFalse);
      expect(
        enabled(presenter.openings.last, 'terminal-menu-clear-selection'),
        isFalse,
      );
      expect(enabled(presenter.openings.last, 'terminal-menu-paste'), isTrue);

      // Selecting through the described entry is what a system menu reports
      // back, so drive it the same way rather than through the controller.
      presenter.openings.last
          .whereType<TRMenuActionElement>()
          .firstWhere((e) => e.id == 'terminal-menu-select-all')
          .onPressed();
      await tester.pumpAndSettle();
      await _openTerminalMenu(tester);

      expect(enabled(presenter.openings.last, 'terminal-menu-copy'), isTrue);
      expect(
        enabled(presenter.openings.last, 'terminal-menu-clear-selection'),
        isTrue,
      );
    },
    tags: const <String>['feature_test__terminal_lifecycle__widget'],
  );

  testWidgets(
    'native menu dismissal restores text input and keyboard editing',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final presenter = _RecordingPresenter();
      final api = await _pumpTerminal(tester, presenter: presenter);
      await _openTerminalMenu(tester);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      presenter.dismiss();
      await tester.pumpAndSettle();
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'x',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);

      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<TerminalView>(),
        isNotNull,
      );
      expect(tester.testTextInput.hasAnyClients, isTrue);
      expect(api.terminalWrites.map((write) => write.data).join(), 'x\u007f');
    },
    tags: const <String>['feature_test__terminal_lifecycle__widget'],
  );

  testWidgets(
    'native menu selection restores input before its action continues',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? <String, Object?>{'text': 'pasted text'}
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final presenter = _RecordingPresenter();
      final api = await _pumpTerminal(tester, presenter: presenter);
      await _openTerminalMenu(tester);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      presenter.select('terminal-menu-paste');
      await tester.pumpAndSettle();

      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<TerminalView>(),
        isNotNull,
      );
      expect(tester.testTextInput.hasAnyClients, isTrue);
      expect(
        api.terminalWrites.map((write) => write.data).join(),
        'pasted text',
      );
    },
    tags: const <String>['feature_test__terminal_lifecycle__widget'],
  );
}

final class _OfflineClients implements HostClientFactory {
  const _OfflineClients();

  @override
  Future<TinestApi> connect({
    required HostConnection connection,
    required HostConnectionCredential credential,
    required String clientId,
    required String clientKind,
  }) => Future<TinestApi>.error(const HostConnectionFailure.network('offline'));
}
