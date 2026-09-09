import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/features/terminals/application/terminal_session_controller.dart';
import 'package:app/src/features/terminals/presentation/tinest_terminal_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;
import 'package:termworld/termworld.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

import '../test/support/fake_tinest_api.dart';
import '../test/support/localization.dart';

const _terminal = TerminalDto(
  id: 'mobile-terminal-input',
  worktreeId: 'checkout',
  title: 'Mobile terminal',
  shell: ShellSpecDto(executable: '/bin/sh'),
  status: TerminalStatus.running,
  columns: 80,
  rows: 24,
  lastSequence: 0,
);

Future<TerminalSessionState> _waitForLiveSession(
  TerminalSessionState Function() read,
) async {
  for (var turn = 0; turn < 20; turn += 1) {
    final session = read();
    if (session.status == TerminalSessionStatus.live) return session;
    await Future<void>.delayed(Duration.zero);
  }
  final session = read();
  expect(
    session.status,
    TerminalSessionStatus.live,
    reason: 'The terminal attachment did not become live within 20 turns.',
  );
  return session;
}

Future<void> _sendEditingState(
  WidgetTester tester,
  TextEditingValue value,
) async {
  final message = SystemChannels.textInput.codec.encodeMethodCall(
    MethodCall('TextInputClient.updateEditingState', <Object?>[
      -1,
      value.toJSON(),
    ]),
  );
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.textInput.name,
    message,
    (_) {},
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'mobile software keyboard resumes and forwards exact PTY data',
    (tester) async {
      expect(defaultTargetPlatform, TargetPlatform.android);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final api = FakeTinestApi(terminals: const <TerminalDto>[_terminal]);
      final container = ProviderContainer(
        overrides: <Override>[
          appServicesProvider.overrideWithValue(fakeAppServices(api)),
        ],
      );
      final sessionProvider = terminalSessionControllerProvider(
        'server',
        _terminal.id,
      );
      final subscription = container.listen(sessionProvider, (_, _) {});
      final controller = TerminalViewController();
      final nextFocus = FocusNode(debugLabel: 'mobile-terminal-next-focus');
      addTearDown(() {
        nextFocus.dispose();
        controller.dispose();
        subscription.close();
        container.dispose();
      });
      final session = await _waitForLiveSession(
        () => container.read(sessionProvider),
      );
      expect(session.status, TerminalSessionStatus.live);

      await tester.pumpWidget(
        MaterialApp(
          theme: testLightTheme,
          home: Scaffold(
            body: Column(
              children: <Widget>[
                Expanded(
                  child: TinestTerminalView(
                    terminal: session.terminal,
                    controller: controller,
                    autofocus: true,
                  ),
                ),
                Focus(
                  focusNode: nextFocus,
                  child: TRButton(
                    onPressed: nextFocus.requestFocus,
                    child: const Text('Focus target'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TinestTerminalView), findsOneWidget);
      expect(FocusManager.instance.primaryFocus, isNotNull);
      await _sendEditingState(
        tester,
        const TextEditingValue(
          text: '한글',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await tester.pump();
      expect(api.terminalWrites.map((write) => write.data).join(), '한글');

      await tester.tap(find.text('Focus target'));
      await tester.pumpAndSettle();
      expect(nextFocus.hasFocus, isTrue);
      await _sendEditingState(
        tester,
        const TextEditingValue(
          text: 'should-not-forward',
          selection: TextSelection.collapsed(offset: 18),
        ),
      );
      await tester.pump();
      expect(api.terminalWrites.map((write) => write.data).join(), '한글');

      controller.requestKeyboard();
      await tester.pumpAndSettle();
      expect(nextFocus.hasFocus, isFalse);
      await _sendEditingState(
        tester,
        const TextEditingValue(
          text: '입력\n',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      await tester.pump();

      expect(api.terminalWrites.map((write) => write.data).join(), '한글입력\r');
      expect(
        api.terminalWrites.map((write) => write.terminalId).toSet(),
        <String>{_terminal.id},
      );
    },
    tags: const <String>[
      'feature_test__terminal_lifecycle__platformSmoke',
      // Kept whole because the feature verifier scans raw source literals.
      // ignore: lines_longer_than_80_chars
      'feature_scenario__terminal_lifecycle__mobile_software_keyboard_input__e2e',
    ],
  );
}
