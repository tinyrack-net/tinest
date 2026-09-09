import 'package:app/src/shared/presentation/client_error_alert.dart';
import 'package:client/client.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../support/localization.dart';

void main() {
  test('every daemon failure code has wording of its own', () {
    // The daemon writes its messages in English for a maintainer. A code
    // this app knows but forgot to translate would leak that sentence to a
    // Korean or Japanese user, which is exactly the bug being fixed.
    const daemonSentence = 'Internal daemon error.';
    for (final code in RpcErrorCodes.all) {
      final text = clientErrorText(
        testL10n,
        const TinestClientException(daemonSentence).copyWithCode(code),
      );
      expect(
        text,
        isNot(daemonSentence),
        reason: 'The code "$code" has no localized wording.',
      );
    }
  }, tags: const <String>['feature_test__worktree_lifecycle__unit']);

  test('an unknown code falls back to the daemon message', () {
    // Only the daemon knows what a code this app has never heard of means,
    // so its own text beats inventing a generic apology.
    expect(
      clientErrorText(
        testL10n,
        const TinestClientException('Something specific.', code: 'from_v5'),
      ),
      'Something specific.',
    );
    expect(
      clientErrorText(testL10n, const TinestClientException('No code.')),
      'No code.',
    );
  }, tags: const <String>['feature_test__worktree_lifecycle__unit']);

  test(
    'diagnostics carry the trace id and Git output, and nothing when empty',
    () {
      expect(
        clientErrorDiagnostics(
          const TinestClientException(
            'Internal daemon error.',
            code: RpcErrorCodes.gitCommandFailed,
            details: <String, dynamic>{
              'stderr': "fatal: a branch named 'flutter' already exists",
              'command': 'git worktree add -b flutter /checkout main',
              'traceId': 'trace-1',
              'method': 'workspaces.createWorktree',
              'errorType': 'StateError',
            },
          ),
        ),
        allOf(
          contains("fatal: a branch named 'flutter' already exists"),
          contains('git worktree add -b flutter /checkout main'),
          contains('code: ${RpcErrorCodes.gitCommandFailed}'),
          contains('traceId: trace-1'),
          contains('method: workspaces.createWorktree'),
          contains('type: StateError'),
        ),
      );
      // An empty stderr adds a blank line rather than information.
      expect(
        clientErrorDiagnostics(
          const TinestClientException(
            'Failed.',
            code: RpcErrorCodes.gitCommandFailed,
            details: <String, dynamic>{'stderr': ''},
          ),
        ),
        'code: ${RpcErrorCodes.gitCommandFailed}',
      );
      expect(
        clientErrorDiagnostics(const TinestClientException('Failed.')),
        isNull,
      );
    },
    tags: const <String>['feature_test__worktree_lifecycle__unit'],
  );

  testWidgets(
    'the alert offers a retry and copies guidance with its diagnostics',
    (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add(
              (call.arguments as Map<Object?, Object?>)['text']! as String,
            );
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      var retried = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: testLightTheme,
          locale: testLocale,
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: Scaffold(
            body: ClientErrorAlert(
              error: const TinestClientException(
                'Internal daemon error.',
                code: RpcErrorCodes.internalError,
                details: <String, dynamic>{'traceId': 'trace-7'},
              ),
              title: 'Start failed',
              onRetry: () => retried += 1,
            ),
          ),
        ),
      );

      expect(find.byType(TRAlert), findsOneWidget);
      expect(find.text('Start failed'), findsOneWidget);
      expect(find.textContaining('traceId: trace-7'), findsOneWidget);

      await tester.tap(find.text(testL10n.commonRetry));
      await tester.pump();
      expect(retried, 1);

      await tester.tap(find.byKey(const ValueKey<String>('client-error-copy')));
      await tester.pump();
      expect(
        copied.single,
        allOf(
          contains('Start failed'),
          contains(testL10n.errorInternalDaemon),
          contains('traceId: trace-7'),
        ),
      );
    },
    tags: const <String>['feature_test__worktree_lifecycle__widget'],
  );

  testWidgets(
    'an alert without diagnostics or a retry shows only the guidance',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: testLightTheme,
          locale: testLocale,
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: const Scaffold(
            body: ClientErrorAlert(
              error: TinestClientException('Plain failure.'),
              title: 'Start failed',
            ),
          ),
        ),
      );

      expect(find.text('Plain failure.'), findsOneWidget);
      expect(find.text(testL10n.commonRetry), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('client-error-copy')),
        findsOneWidget,
      );
    },
    tags: const <String>['feature_test__worktree_lifecycle__widget'],
  );
}

extension on TinestClientException {
  /// Rebuilds this failure under a different code.
  TinestClientException copyWithCode(String code) =>
      TinestClientException(message, code: code, retryable: retryable);
}
