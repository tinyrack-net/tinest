import 'dart:async';

import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/app/router/app_router.dart';
import 'package:app/src/features/conversation/infrastructure/attachment_io.dart';
import 'package:app/src/features/conversation/presentation/widgets/session_composer.dart';
import 'package:dropwell/dropwell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/fake_tinest_api.dart';
import '../../support/localization.dart';

void main() {
  testWidgets(
    'composer keeps ordered attachment-only draft on failure '
    'and clears on success',
    tags: const <String>['feature_test__conversation_attachments__widget'],
    (tester) async {
      for (final size in <Size>[const Size(1000, 700), const Size(390, 844)]) {
        await tester.pumpWidget(const SizedBox());
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final input = _FakeAttachmentInput();
        final dropController = SessionComposerController();
        addTearDown(dropController.dispose);
        var fail = true;
        ComposerSubmission? submitted;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appServicesProvider.overrideWithValue(
                fakeAppServices(FakeTinestApi()),
              ),
            ],
            child: MaterialApp(
              theme: testLightTheme,
              locale: testLocale,
              localizationsDelegates: testLocalizationsDelegates,
              supportedLocales: testSupportedLocales,
              home: Scaffold(
                body: ComposerDropPane(
                  controller: dropController,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: SessionComposer(
                      controller: dropController,
                      enabled: true,
                      attachmentInput: input,
                      onSubmit: (submission) async {
                        submitted = submission;
                        if (fail) throw Exception('upload failed');
                      },
                      bar: _bar(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('session-composer-attach')));
        await tester.pumpAndSettle();
        expect(find.textContaining('fixture.png'), findsOneWidget);
        expect(find.textContaining('notes.txt'), findsOneWidget);
        expect(find.textContaining('2.0 KB'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('session-composer-send')));
        await tester.pumpAndSettle();
        expect(find.textContaining('fixture.png'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('session-composer-attachment-error')),
          findsOneWidget,
        );

        fail = false;
        await tester.tap(find.byKey(const ValueKey('session-composer-send')));
        await tester.pumpAndSettle();
        expect(submitted!.text, isEmpty);
        expect(submitted!.attachments.map((item) => item.fileName), <String>[
          'fixture.png',
          'notes.txt',
        ]);
        expect(find.textContaining('fixture.png'), findsNothing);

        final region = tester.widget<DropwellRegion>(
          find.byType(DropwellRegion),
        );
        region.onHoverChanged?.call(true);
        await tester.pumpAndSettle();
        expect(
          tester.widget<TRDropOverlay>(find.byType(TRDropOverlay)).visible,
          isTrue,
        );
        expect(
          tester.getRect(find.byType(TRDropOverlay)),
          tester.getRect(find.byType(ComposerDropPane)),
        );
        await region.onDrop(const <DropwellFile>[
          DropwellFile.path(fileName: 'dropped.txt', path: '/tmp/dropped.txt'),
        ]);
        await tester.pumpAndSettle();
        expect(
          tester.widget<TRDropOverlay>(find.byType(TRDropOverlay)).visible,
          isFalse,
        );
        expect(find.textContaining('dropped.txt'), findsOneWidget);
      }
    },
  );

  testWidgets(
    'composer omits the native drop target when the adapter cannot drop',
    tags: const <String>['feature_test__conversation_attachments__widget'],
    (tester) async {
      final dropController = SessionComposerController();
      addTearDown(dropController.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appServicesProvider.overrideWithValue(
              fakeAppServices(FakeTinestApi()),
            ),
          ],
          child: MaterialApp(
            theme: testLightTheme,
            locale: testLocale,
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            home: Scaffold(
              body: ComposerDropPane(
                controller: dropController,
                child: SessionComposer(
                  controller: dropController,
                  enabled: true,
                  attachmentInput: _FakeAttachmentInput(supportsDrop: false),
                  onSubmit: (_) async {},
                  bar: _bar(),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(DropwellRegion), findsNothing);
      expect(
        tester.widget<TRDropOverlay>(find.byType(TRDropOverlay)).visible,
        isFalse,
      );
      expect(
        find.byKey(const ValueKey('session-composer-attach')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'pane drop target follows disabled and submitting composer state',
    tags: const <String>['feature_test__conversation_attachments__widget'],
    (tester) async {
      final dropController = SessionComposerController();
      addTearDown(dropController.dispose);
      final submitting = Completer<void>();
      var enabled = false;
      late StateSetter refresh;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appServicesProvider.overrideWithValue(
              fakeAppServices(FakeTinestApi()),
            ),
          ],
          child: MaterialApp(
            theme: testLightTheme,
            locale: testLocale,
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  refresh = setState;
                  return ComposerDropPane(
                    controller: dropController,
                    child: SessionComposer(
                      controller: dropController,
                      enabled: enabled,
                      attachmentInput: _FakeAttachmentInput(),
                      onSubmit: (_) => submitting.future,
                      bar: _bar(),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DropwellRegion), findsNothing);

      refresh(() => enabled = true);
      await tester.pumpAndSettle();
      expect(find.byType(DropwellRegion), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey<String>('session-composer-input')),
        'send',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('session-composer-send')),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(DropwellRegion), findsNothing);
      expect(
        tester.widget<TRDropOverlay>(find.byType(TRDropOverlay)).visible,
        isFalse,
      );

      submitting.complete();
      await tester.pumpAndSettle();
      expect(find.byType(DropwellRegion), findsOneWidget);
    },
  );

  testWidgets(
    'new workspace, draft, and conversation own a full-pane drop overlay',
    tags: const <String>['feature_test__conversation_attachments__widget'],
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final now = DateTime.utc(2026, 8, 8);
      final home = WorkspaceDto(
        id: 'home',
        name: 'user',
        rootPath: '/home/user',
        kind: WorkspaceKind.home,
        createdAt: now,
      );
      final workspace = WorkspaceDto(
        id: 'workspace',
        name: 'Tinest',
        rootPath: '/repos/tinest',
        kind: WorkspaceKind.git,
        createdAt: now,
      );
      final homeCheckout = WorktreeDto(
        id: 'home-checkout',
        workspaceId: home.id,
        name: home.name,
        path: home.rootPath,
        kind: WorktreeKind.directory,
        isTinestOwned: false,
        createdAt: now,
      );
      final checkout = WorktreeDto(
        id: 'checkout',
        workspaceId: workspace.id,
        name: 'main',
        path: workspace.rootPath,
        branch: 'main',
        kind: WorktreeKind.checkout,
        isTinestOwned: false,
        createdAt: now,
      );
      final session = SessionDto(
        id: 'session',
        worktreeId: checkout.id,
        title: 'Focus migration',
        agentDefinitionId: 'tinest',
        origin: SessionOrigin.manual,
        status: SessionStatus.idle,
        model: const ModelSelectionDto(modelId: 'openai/gpt-5.6-sol'),
        createdAt: now,
        updatedAt: now,
      );
      final cases = <({FakeTinestApi api, String location})>[
        (
          api: FakeTinestApi(
            workspaces: <WorkspaceDto>[home],
            worktrees: <WorktreeDto>[homeCheckout],
          ),
          location: const WorkspaceHomeRoute(compose: true).location,
        ),
        (
          api: FakeTinestApi(
            workspaces: <WorkspaceDto>[workspace],
            worktrees: <WorktreeDto>[checkout],
          ),
          location: WorktreeRoute(
            hostId: 'server',
            workspaceId: workspace.id,
            worktreeId: checkout.id,
          ).location,
        ),
        (
          api: FakeTinestApi(
            workspaces: <WorkspaceDto>[workspace],
            worktrees: <WorktreeDto>[checkout],
            agents: <SessionDto>[session],
          ),
          location: SessionRoute(
            hostId: 'server',
            workspaceId: workspace.id,
            worktreeId: checkout.id,
            sessionId: session.id,
          ).location,
        ),
      ];

      for (final fixture in cases) {
        final router = GoRouter(
          initialLocation: fixture.location,
          routes: $appRoutes,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appServicesProvider.overrideWithValue(
                fakeAppServices(fixture.api),
              ),
              attachmentInputProvider.overrideWithValue(_FakeAttachmentInput()),
            ],
            child: MaterialApp.router(
              theme: testLightTheme,
              locale: testLocale,
              localizationsDelegates: testLocalizationsDelegates,
              supportedLocales: testSupportedLocales,
              routerConfig: router,
              builder: (context, child) => TRTooltipProvider(child: child!),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final region = tester.widget<DropwellRegion>(
          find.byType(DropwellRegion),
        );
        region.onHoverChanged?.call(true);
        await tester.pumpAndSettle();
        final overlay = find.byType(TRDropOverlay);
        expect(tester.widget<TRDropOverlay>(overlay).visible, isTrue);
        expect(
          tester.getRect(overlay),
          tester.getRect(find.byType(ComposerDropPane)),
        );

        router.dispose();
        await fixture.api.close();
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}

SessionComposerBar _bar() => SessionComposerBar(
  hostId: 'server',
  definitions: const <AgentDefinitionDto>[],
  agentDefinitionId: null,
  selection: null,
  onAgentChanged: (_) {},
  onModelChanged: (_, _) {},
);

final class _FakeAttachmentInput implements AttachmentInputPort {
  new({this.supportsDrop = true});

  @override
  final bool supportsDrop;

  @override
  Future<List<PendingAttachment>> pickFiles() async => <PendingAttachment>[
    PendingAttachment.fromBytes(
      fileName: 'fixture.png',
      mimeType: 'image/png',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
    ),
    PendingAttachment.fromBytes(
      fileName: 'notes.txt',
      mimeType: 'text/plain',
      bytes: Uint8List(2048),
    ),
  ];

  @override
  Future<List<PendingAttachment>> pasteFiles() async =>
      const <PendingAttachment>[];

  @override
  Future<List<PendingAttachment>> droppedFiles(
    List<DropwellFile> files,
  ) async => <PendingAttachment>[
    PendingAttachment.fromBytes(
      fileName: 'dropped.txt',
      mimeType: 'text/plain',
      bytes: Uint8List.fromList(<int>[6]),
    ),
  ];
}
