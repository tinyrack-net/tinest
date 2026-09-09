import 'package:app/src/features/desktop/application/desktop_startup.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only a login-item launch with the preference on starts hidden', () {
    const enabled = AppSettings();
    const disabled = AppSettings(startMinimizedAtBoot: false);

    expect(
      shouldStartHidden(
        arguments: const <String>[startMinimizedFlag],
        settings: enabled,
      ),
      isTrue,
    );
    // Opening the app yourself always shows a window, even while the
    // preference is on, so the icon never appears to do nothing.
    expect(
      shouldStartHidden(arguments: const <String>[], settings: enabled),
      isFalse,
    );
    // A stale login item keeps passing the flag after the user turned the
    // preference off; the stored preference wins.
    expect(
      shouldStartHidden(
        arguments: const <String>[startMinimizedFlag],
        settings: disabled,
      ),
      isFalse,
    );
    expect(
      shouldStartHidden(arguments: const <String>[], settings: disabled),
      isFalse,
    );
    expect(
      shouldStartHidden(
        arguments: const <String>['--other'],
        settings: enabled,
      ),
      isFalse,
    );
  }, tags: const <String>['feature_test__settings_startup__unit']);

  test('custom pairing protocol becomes a canonical fragment-only route', () {
    expect(
      desktopPairingInitialLocation(const <String>[
        'tinyrack-tinest://pair#offer=secret-capability',
      ]),
      'https://tinest.tinyrack.net/pair#offer=secret-capability',
    );
    expect(
      desktopPairingInitialLocation(const <String>[
        'tinyrack-tinest://pair?offer=must-not-leak',
      ]),
      isNull,
    );
    expect(
      desktopPairingInitialLocation(const <String>[
        'tinyrack-tinest://settings#offer=secret-capability',
      ]),
      isNull,
    );
  });
}
