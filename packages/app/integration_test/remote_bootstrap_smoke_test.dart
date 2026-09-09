import 'package:app/src/app/composition/app_services.dart';
import 'package:app/src/app/tinest_app.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/hosts/domain/host_ports.dart';
import 'package:client/client.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/localization.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'mobile bootstrap remains remote-only',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = MemoryAppStore(
        settings: const AppSettings(embeddedDaemonEnabled: false),
      );
      await tester.pumpWidget(
        TinestApp(
          services: AppServices(
            settings: store,
            profiles: store,
            credentials: store,
            clients: const _UnusedClients(),
            clientKind: 'mobile-integration-test',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Resolve every label through the harness locale rather than literals:
      // a translation pass must not silently detach this smoke test from the
      // strings the pinned locale actually renders.
      expect(find.text(testL10n.workspaceNoDaemons), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-settings-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('settings-category-select')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('settings-daemon-select')),
        findsNothing,
      );
      // The category label and the daemon section header share one localized
      // string, so the row's stable key is the only unambiguous target.
      await tester.tap(
        find.byKey(const ValueKey<String>('settings-category-row-daemon')),
      );
      await tester.pumpAndSettle();
      expect(find.text(testL10n.embeddedDaemonName), findsNothing);
      expect(find.text(testL10n.relayPairTitle), findsOneWidget);

      await tester.tap(find.text(testL10n.relayPairTitle));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('connect-daemon-paste')),
      );
      await tester.pumpAndSettle();

      final field = find.byKey(const ValueKey<String>('relay-pair-link'));
      final action = find.byKey(const ValueKey<String>('relay-pair-review'));
      await tester.tap(field);
      await tester.showKeyboard(field);
      await tester.pumpAndSettle();

      // The IME is another process, and a cold emulator keyboard can deliver
      // its window insets seconds after TextInput.show. No Flutter frame is
      // scheduled while nothing changes, so pumpAndSettle returns before the
      // insets exist; pump on a real-time deadline until they arrive.
      final insetsDeadline = DateTime.now().add(const Duration(seconds: 15));
      while (MediaQuery.of(tester.element(field)).viewInsets.bottom <= 0 &&
          DateTime.now().isBefore(insetsDeadline)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // Let the inset-driven relayout and its reveal scroll settle before
      // measuring the field against the keyboard edge.
      await tester.pumpAndSettle();

      final mediaQuery = MediaQuery.of(tester.element(field));
      expect(
        mediaQuery.viewInsets.bottom,
        greaterThan(0),
        reason: 'The soft keyboard never reported window insets.',
      );
      final keyboardTop = mediaQuery.size.height - mediaQuery.viewInsets.bottom;
      expect(tester.getRect(field).bottom, lessThanOrEqualTo(keyboardTop));
      expect(tester.getRect(action).bottom, lessThanOrEqualTo(keyboardTop));
    },
    tags: const <String>[
      'feature_test__daemon_management__platformSmoke',
      'feature_test__daemon_relay__platformSmoke',
      'feature_test__soft_keyboard_visibility__platformSmoke',
    ],
  );
}

final class _UnusedClients implements HostClientFactory {
  const new();

  @override
  Future<TinestApi> connect({
    required HostConnection connection,
    required HostConnectionCredential credential,
    required String clientId,
    required String clientKind,
  }) => throw StateError('No host should connect in a remote-only smoke test.');
}
