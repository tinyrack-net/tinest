import 'package:app/src/shared/presentation/workspace_skeletons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../support/localization.dart';

/// Hosts one skeleton at a fixed size so geometry reads the skeleton itself.
Widget _host(Widget child, {double width = 1200, double height = 800}) =>
    MaterialApp(
      theme: testLightTheme,
      home: Scaffold(
        body: SizedBox(width: width, height: height, child: child),
      ),
    );

void main() {
  testWidgets(
    'WorkspacePaneSkeleton renders an inert labelled pane silhouette',
    (tester) async {
      await tester.pumpWidget(
        _host(const WorkspacePaneSkeleton(semanticLabel: 'Loading workspace')),
      );

      expect(
        find.byKey(const ValueKey<String>('workspace-pane-skeleton')),
        findsOneWidget,
      );
      expect(find.byType(TRSkeleton), findsWidgets);
      expect(find.bySemanticsLabel('Loading workspace'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(WorkspacePaneSkeleton),
          matching: find.byType(Focus),
        ),
        findsNothing,
      );
    },
    tags: const <String>['feature_test__workspace_async_loading__widget'],
  );

  testWidgets(
    'ChatTimelineSkeleton alternates user and assistant silhouettes',
    (tester) async {
      await tester.pumpWidget(
        _host(const ChatTimelineSkeleton(semanticLabel: 'Loading messages')),
      );

      expect(
        find.byKey(const ValueKey<String>('chat-timeline-skeleton')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Loading messages'), findsOneWidget);

      // A user turn reads from the trailing edge and an assistant turn from
      // the leading edge, so the placeholder carries the conversation shape.
      final surface = tester.getRect(find.byType(ChatTimelineSkeleton));
      final skeletons = find.byType(TRSkeleton);
      expect(skeletons, findsWidgets);
      final centers = <double>[
        for (var i = 0; i < tester.widgetList(skeletons).length; i++)
          tester.getRect(skeletons.at(i)).center.dx,
      ];
      expect(centers.any((dx) => dx > surface.center.dx), isTrue);
      expect(centers.any((dx) => dx < surface.center.dx), isTrue);
    },
    tags: const <String>['feature_test__workspace_async_loading__widget'],
  );

  testWidgets(
    'TerminalConnectingOverlay shows progress over a scrollback silhouette',
    (tester) async {
      await tester.pumpWidget(
        _host(
          const TerminalConnectingOverlay(
            semanticLabel: 'Connecting to terminal',
            message: 'Connecting…',
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('terminal-connecting')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Connecting to terminal'), findsOneWidget);
      expect(find.byType(TRSpinner), findsOneWidget);
      expect(find.text('Connecting…'), findsOneWidget);
      expect(find.byType(TRSkeleton), findsWidgets);
    },
    tags: const <String>['feature_test__workspace_async_loading__widget'],
  );

  testWidgets('SidebarTreeSkeleton indents worktree rows under project rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const SidebarTreeSkeleton(semanticLabel: 'Loading workspaces'),
        width: 320,
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('workspace-sidebar-skeleton')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Loading workspaces'), findsOneWidget);

    // Child rows sit deeper than their project heading, matching the tree.
    final skeletons = find.byType(TRSkeleton);
    final lefts = <double>[
      for (var i = 0; i < tester.widgetList(skeletons).length; i++)
        tester.getRect(skeletons.at(i)).left,
    ];
    expect(lefts.toSet().length, greaterThan(1));
  }, tags: const <String>['feature_test__workspace_async_loading__widget']);

  testWidgets('ListRowsSkeleton renders the requested number of rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const ListRowsSkeleton(semanticLabel: 'Loading entries', rows: 5)),
    );

    expect(
      find.byKey(const ValueKey<String>('list-rows-skeleton')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Loading entries'), findsOneWidget);
    expect(find.byType(TRSkeleton), findsNWidgets(5));
  }, tags: const <String>['feature_test__workspace_async_loading__widget']);
}
