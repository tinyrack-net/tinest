import 'dart:async';
import 'dart:typed_data';

import 'package:app/src/app/composition/app_primitives.dart';
import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/features/conversation/application/attachment_ports.dart';
import 'package:app/src/features/conversation/application/pending_turns_controller.dart';
import 'package:app/src/features/conversation/presentation/chat_timeline_view.dart';
import 'package:dropwell/dropwell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/fake_tinest_api.dart';
import '../../support/localization.dart';

void main() {
  final now = DateTime.utc(2026, 8, 3);
  final workspace = WorkspaceDto(
    id: 'workspace',
    name: 'Tinest',
    rootPath: '/repos/tinest',
    kind: WorkspaceKind.git,
    createdAt: now,
  );
  final checkout = WorktreeDto(
    id: 'checkout',
    workspaceId: workspace.id,
    name: 'main',
    path: workspace.rootPath,
    branch: 'main',
    head: 'abc',
    kind: WorktreeKind.checkout,
    isTinestOwned: false,
    createdAt: now,
  );
  final location = WorktreeRoute(
    hostId: 'server',
    workspaceId: workspace.id,
    worktreeId: checkout.id,
  ).location;

  Future<GoRouter> pumpDraft(
    WidgetTester tester,
    FakeTinestApi api, {
    AttachmentInputPort? attachmentInput,
  }) async {
    final router = GoRouter(initialLocation: location, routes: $appRoutes);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appServicesProvider.overrideWithValue(fakeAppServices(api)),
          attachmentInputProvider.overrideWithValue(attachmentInput),
        ],
        child: MediaQuery(
          data: MediaQueryData(
            disableAnimations: true,
            size: tester.view.physicalSize / tester.view.devicePixelRatio,
          ),
          child: MaterialApp.router(
            theme: testLightTheme,
            darkTheme: testDarkTheme,
            locale: testLocale,
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets(
    'a failed first turn restores the prompt instead of queueing it',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeTinestApi(
        workspaces: <WorkspaceDto>[workspace],
        worktrees: <WorktreeDto>[checkout],
      )..startTurnError = Exception('daemon rejected the turn');
      final router = await pumpDraft(
        tester,
        api,
        attachmentInput: const _FailedTurnAttachmentInput(),
      );
      addTearDown(router.dispose);

      const prompt = 'Prompt that must not be lost';
      await tester.enterText(
        find.byKey(const ValueKey('session-composer-input')),
        prompt,
      );
      await tester.tap(find.byKey(const ValueKey('session-composer-attach')));
      await tester.pumpAndSettle();
      expect(find.textContaining('fixture.txt'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('session-composer-send')));
      for (var frame = 0; frame < 8; frame += 1) {
        await tester.pump();
      }

      // The chat room opened despite the failure, and the prompt returned to
      // the composer rather than becoming a normal follow-up queue entry.
      expect(find.byType(ChatTimelineView).hitTestable(), findsOneWidget);
      expect(api.attemptedPrompts, contains(prompt));
      expect(
        find.byKey(const ValueKey<String>('queued-turn-0')).hitTestable(),
        findsNothing,
      );
      expect(
        tester
            .widget<TRTextField>(
              find.byKey(const ValueKey('session-composer-input')),
            )
            .controller!
            .text,
        prompt,
      );
      expect(find.textContaining('fixture.txt'), findsOneWidget);
    },
    tags: const <String>[
      'feature_test__workspace_async_loading__widget',
      'feature_test__turn_execution__widget',
    ],
  );

  testWidgets(
    'a pending first turn may fail after the provider container unmounts',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final startGate = Completer<void>();
      addTearDown(() {
        if (!startGate.isCompleted) startGate.complete();
      });
      final api =
          FakeTinestApi(
              workspaces: <WorkspaceDto>[workspace],
              worktrees: <WorktreeDto>[checkout],
            )
            ..startTurnGate = startGate
            ..startTurnError = Exception('daemon stopped during teardown');
      final router = await pumpDraft(tester, api);
      addTearDown(router.dispose);

      await tester.enterText(
        find.byKey(const ValueKey('session-composer-input')),
        'Turn that outlives the app',
      );
      await tester.tap(find.byKey(const ValueKey('session-composer-send')));
      for (var frame = 0; frame < 8; frame += 1) {
        await tester.pump();
      }
      expect(api.attemptedPrompts, contains('Turn that outlives the app'));

      await tester.pumpWidget(const SizedBox.shrink());
      startGate.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
    tags: const <String>['feature_test__turn_execution__widget'],
  );

  test('the pending first-turn registry records and forgets prompts', () {
    final container = ProviderContainer(
      overrides: [appClockProvider.overrideWithValue(_FixedClock(now))],
    );
    addTearDown(container.dispose);
    final notifier = container.read(pendingFirstTurnsProvider.notifier)
      ..put('session-1', 'Hello');
    final entry = container.read(pendingFirstTurnsProvider)['session-1']!;
    expect(entry.prompt, 'Hello');
    expect(entry.createdAt, now);
    expect(entry.failed, isFalse);
    notifier.markFailed('session-1');
    expect(
      container.read(pendingFirstTurnsProvider)['session-1']!.failed,
      isTrue,
    );
    // Marking an unknown id is a no-op rather than an error.
    notifier
      ..markFailed('session-unknown')
      ..clear('session-1');
    expect(container.read(pendingFirstTurnsProvider), isEmpty);
    // Clearing an unknown id is a no-op rather than an error.
    notifier.clear('session-unknown');
    expect(container.read(pendingFirstTurnsProvider), isEmpty);
  });
}

final class _FixedClock implements AppClock {
  const new(this.value);

  final DateTime value;

  @override
  DateTime nowUtc() => value;
}

final class _FailedTurnAttachmentInput implements AttachmentInputPort {
  const new();

  @override
  bool get supportsDrop => false;

  @override
  Future<List<PendingAttachment>> pickFiles() async => <PendingAttachment>[
    PendingAttachment.fromBytes(
      fileName: 'fixture.txt',
      mimeType: 'text/plain',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
    ),
  ];

  @override
  Future<List<PendingAttachment>> pasteFiles() async =>
      const <PendingAttachment>[];

  @override
  Future<List<PendingAttachment>> droppedFiles(
    List<DropwellFile> files,
  ) async => const <PendingAttachment>[];
}
