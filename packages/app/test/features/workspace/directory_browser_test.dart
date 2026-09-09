import 'dart:async';

import 'package:app/src/features/workspace/presentation/widgets/directory_browser.dart';
import 'package:client/client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../../support/fake_tinest_api.dart';
import '../../support/localization.dart';

void main() {
  const tree = <String, List<String>>{
    '/': <String>['/srv'],
    '/srv': <String>['/srv/repositories', '/srv/backups'],
    '/srv/repositories': <String>['/srv/repositories/project'],
    '/srv/repositories/project': <String>[],
  };

  Future<String?> pump(WidgetTester tester, FakeTinestApi api) async {
    String? chosen;
    await tester.pumpWidget(
      MaterialApp(
        theme: testLightTheme,
        darkTheme: testDarkTheme,
        locale: testLocale,
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => chosen = await showDirectoryBrowser(
                context,
                api: api,
                initialPath: '/srv',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return chosen;
  }

  testWidgets(
    'the browser lists children and walks into and out of directories',
    (tester) async {
      final api = FakeTinestApi(directories: tree);
      await pump(tester, api);

      expect(find.text('repositories'), findsOneWidget);
      expect(find.text('backups'), findsOneWidget);

      await tester.tap(find.text('repositories'));
      await tester.pumpAndSettle();
      expect(find.text('project'), findsOneWidget);
      expect(find.text('backups'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('directory-browser-parent')));
      await tester.pumpAndSettle();
      expect(find.text('backups'), findsOneWidget);

      await tester.tap(find.text('repositories'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('project'));
      await tester.pumpAndSettle();
      expect(find.text('하위 폴더가 없습니다.'), findsOneWidget);
      await tester.tap(find.widgetWithText(TRButton, '이 폴더 선택'));
      await tester.pumpAndSettle();
      expect(find.text('Daemon의 폴더 선택'), findsNothing);
    },
    tags: const <String>['feature_test__workspace_registration__widget'],
  );

  testWidgets(
    'the first listing renders row skeletons and later ones keep stale rows',
    (tester) async {
      final gate = Completer<void>();
      final api = FakeTinestApi(
        directories: tree,
        suggestDirectoriesGate: gate.future,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: testLightTheme,
          darkTheme: testDarkTheme,
          locale: testLocale,
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => await showDirectoryBrowser(
                  context,
                  api: api,
                  initialPath: '/srv',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump();

      // The first load is shape-preserving rows, not a bare progress bar.
      expect(
        find.byKey(const ValueKey<String>('list-rows-skeleton')),
        findsOneWidget,
      );
      expect(find.byType(TRProgress), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('list-rows-skeleton')),
        findsNothing,
      );
      expect(find.text('repositories'), findsOneWidget);
    },
    tags: const <String>['feature_test__workspace_async_loading__widget'],
  );

  testWidgets('typing a path is debounced into a single daemon request', (
    tester,
  ) async {
    final api = FakeTinestApi(directories: tree);
    await pump(tester, api);
    final before = api.suggestedQueries.length;

    final field = find.byKey(const ValueKey('directory-browser-path'));
    await tester.enterText(field, '/srv/r');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.enterText(field, '/srv/re');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.enterText(field, '/srv/rep');
    expect(api.suggestedQueries.length, before);

    await tester.pump(directoryBrowserDebounce);
    await tester.pumpAndSettle();
    expect(api.suggestedQueries.length, before + 1);
    expect(api.suggestedQueries.last, '/srv/rep');
    expect(find.text('repositories'), findsOneWidget);
  }, tags: const <String>['feature_test__workspace_registration__widget']);

  testWidgets('a slow earlier listing never overwrites a newer one', (
    tester,
  ) async {
    final gate = Completer<void>();
    final api = FakeTinestApi(
      directories: tree,
      suggestDirectoriesGate: gate.future,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: testLightTheme,
        darkTheme: testDarkTheme,
        locale: testLocale,
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Scaffold(
          body: DirectoryBrowserDialog(api: api, initialPath: '/'),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('directory-browser-path')),
      '/srv',
    );
    await tester.pump(directoryBrowserDebounce);
    gate.complete();
    await tester.pumpAndSettle();

    // Both the initial '/' listing and the '/srv' listing resolved together;
    // only the newest one may render.
    expect(find.text('repositories'), findsOneWidget);
    expect(find.text('srv'), findsNothing);
  }, tags: const <String>['feature_test__workspace_registration__widget']);

  testWidgets('daemon failures surface without clearing the dialog', (
    tester,
  ) async {
    final api = FakeTinestApi(
      directories: tree,
      suggestDirectoriesError: const TinestClientException(
        'Permission denied',
        code: 'request_failed',
      ),
    );
    await pump(tester, api);

    expect(find.text('Permission denied'), findsOneWidget);
    expect(find.text('Daemon의 폴더 선택'), findsOneWidget);
  }, tags: const <String>['feature_test__workspace_registration__widget']);
}
