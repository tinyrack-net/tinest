import 'package:app/src/shared/presentation/toast_messenger.dart';
import 'package:client/client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// The title a queued toast renders, as text.
String _title(TRToastData data) => (data.title as TRText).data;

/// The description a queued toast renders, or null when it has none.
String? _description(TRToastData data) => switch (data.description) {
  final TRText text => text.data,
  _ => null,
};

void main() {
  late TRToastController controller;
  late ToastMessenger messenger;

  setUp(() {
    controller = TRToastController();
    messenger = ToastMessenger(controller);
  });

  tearDown(() => controller.dispose());

  group('reporting', () {
    test('a success is queued as a success toast', () {
      messenger.success('Saved.');

      expect(controller.toasts, hasLength(1));
      expect(_title(controller.toasts.single), 'Saved.');
      expect(controller.toasts.single.variant, TRStatusVariant.success);
    }, tags: const <String>['feature_test__app_toast__unit']);

    test('information is queued as an info toast', () {
      messenger
        ..info('Agent is locked.', id: 'agent-lock')
        ..info('Agent is locked.', id: 'agent-lock');

      expect(controller.toasts, hasLength(1));
      expect(_title(controller.toasts.single), 'Agent is locked.');
      expect(controller.toasts.single.variant, TRStatusVariant.info);
    }, tags: const <String>['feature_test__app_toast__unit']);

    test('a failure is queued as a danger toast', () {
      messenger.failure('Could not save.');

      expect(controller.toasts.single.variant, TRStatusVariant.danger);
      expect(_title(controller.toasts.single), 'Could not save.');
    }, tags: const <String>['feature_test__app_toast__unit']);

    test('a daemon failure is described by its message, not its type', () {
      messenger.failure(
        'Could not save.',
        error: const TinestClientException('the host refused the request'),
      );

      expect(
        _description(controller.toasts.single),
        'the host refused the request',
      );
    }, tags: const <String>['feature_test__app_toast__unit']);

    test('any other failure falls back to its own description', () {
      messenger.failure(
        'Could not save.',
        error: const FormatException('bad port'),
      );

      expect(_description(controller.toasts.single), contains('bad port'));
    }, tags: const <String>['feature_test__app_toast__unit']);

    test('a long failure is trimmed rather than read out in full', () {
      messenger.failure(
        'Could not save.',
        error: TinestClientException('detail ' * 200),
      );

      final description = _description(controller.toasts.single)!;
      expect(description.length, lessThan(300));
      expect(description, endsWith('…'));
    }, tags: const <String>['feature_test__app_toast__unit']);

    test('repeating an identified report replaces it instead of stacking', () {
      messenger
        ..failure('Could not switch theme.', id: 'theme')
        ..failure('Could not switch theme.', id: 'theme');

      expect(controller.toasts, hasLength(1));
    }, tags: const <String>['feature_test__app_toast__unit']);
  });

  group('retirement', () {
    test(
      'a result that arrives after the scope is gone is dropped, not thrown',
      () async {
        messenger.retire();

        final saved = await messenger.run(
          () async {},
          failure: 'Could not save.',
          success: 'Saved.',
        );

        expect(saved, isTrue, reason: 'the action itself still completed');
        expect(controller.toasts, isEmpty);
      },
      tags: const <String>['feature_test__app_toast__unit'],
    );
  });

  group('run', () {
    test(
      'a completed action answers true and reports only when asked',
      () async {
        final quiet = await messenger.run(
          () async {},
          failure: 'Could not save.',
        );
        expect(quiet, isTrue);
        expect(controller.toasts, isEmpty);

        final announced = await messenger.run(
          () async {},
          failure: 'Could not save.',
          success: 'Saved.',
        );
        expect(announced, isTrue);
        expect(_title(controller.toasts.single), 'Saved.');
      },
      tags: const <String>['feature_test__app_toast__unit'],
    );

    test('a thrown action answers false and reports the failure', () async {
      final saved = await messenger.run(
        () async => throw const TinestClientException('the host refused'),
        failure: 'Could not save.',
        success: 'Saved.',
      );

      expect(saved, isFalse, reason: 'the caller must not navigate away');
      expect(controller.toasts, hasLength(1));
      expect(_title(controller.toasts.single), 'Could not save.');
      expect(controller.toasts.single.variant, TRStatusVariant.danger);
      expect(_description(controller.toasts.single), 'the host refused');
    }, tags: const <String>['feature_test__app_toast__unit']);

    test('a failure that is not an exception is still reported', () async {
      final saved = await messenger.run(
        // A `Future.error` carrying a bare object is what an unawaited
        // controller call turns into, so it has to be reportable too.
        () => Future<void>.error(StateError('no host selected')),
        failure: 'Could not save.',
      );

      expect(saved, isFalse);
      expect(controller.toasts.single.variant, TRStatusVariant.danger);
    }, tags: const <String>['feature_test__app_toast__unit']);
  });
}
