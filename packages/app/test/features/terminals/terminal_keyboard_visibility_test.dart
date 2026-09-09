import 'package:app/src/features/terminals/presentation/tinest_terminal_view.dart';
import 'package:app/src/shared/presentation/tinest_page_shell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:termworld/termworld.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

void main() {
  testWidgets('mobile terminal viewport remains above the software keyboard', (
    tester,
  ) async {
    const viewport = Size(390, 760);
    const keyboardHeight = 300.0;
    const terminalKey = ValueKey<String>('terminal-input-surface');
    final controller = TerminalViewController();
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: TinyrackTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: viewport,
            viewInsets: const EdgeInsets.only(bottom: keyboardHeight),
          ),
          child: child!,
        ),
        home: TinestPageShell(
          body: TinestTerminalView(
            key: terminalKey,
            terminal: Terminal(),
            controller: controller,
            autofocus: true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.getRect(find.byKey(terminalKey)).bottom,
      lessThanOrEqualTo(viewport.height - keyboardHeight),
    );
    expect(tester.takeException(), isNull);
  }, tags: const <String>['feature_test__soft_keyboard_visibility__widget']);
}
