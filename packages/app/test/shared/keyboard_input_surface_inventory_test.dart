import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every product input surface remains in the keyboard '
      'visibility audit', () {
    final actual = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) {
          final source = file.readAsStringSync();
          return source.contains('TRTextField(') ||
              source.contains('TRNumberField.') ||
              source.contains('TRTextarea(');
        })
        .map((file) => file.path.replaceAll(Platform.pathSeparator, '/'))
        .toSet();

    const auditedOwners = <String, String>{
      'lib/src/features/agents/presentation/pages/agent_settings_page.dart':
          'SettingsScaffold(',
      'lib/src/features/conversation/presentation/chat_question_card.dart':
          'ChatQuestionCard',
      'lib/src/features/conversation/presentation/widgets/session_composer.dart':
          'SessionComposer',
      'lib/src/features/hosts/presentation/pages/host_settings_page.dart':
          'SettingsScaffold(',
      'lib/src/features/hosts/presentation/pages/relay_pairing_pages.dart':
          'SettingsScaffold(',
      'lib/src/features/mcp/presentation/pages/mcp_settings_page.dart':
          'showTRDialog<',
      'lib/src/features/plugins/presentation/pages/plugin_settings_page.dart':
          'SettingsScaffold(',
      'lib/src/features/plugins/presentation/plugin_ui_document_view.dart':
          'PluginUiDocumentView',
      'lib/src/features/providers/presentation/pages/provider_settings_page.dart':
          'SettingsScaffold(',
      'lib/src/features/workspace/presentation/pages/project_settings_page.dart':
          'SettingsScaffold(',
      'lib/src/features/workspace/presentation/widgets/directory_browser.dart':
          'showTRDialog<',
    };
    expect(actual, auditedOwners.keys.toSet());
    for (final MapEntry(:key, :value) in auditedOwners.entries) {
      expect(
        File(key).readAsStringSync(),
        contains(value),
        reason: '$key must keep using its audited keyboard-aware owner',
      );
    }

    final terminal = File(
      'lib/src/features/terminals/presentation/tinest_terminal_view.dart',
    ).readAsStringSync();
    expect(terminal, contains('TerminalView('));
    expect(terminal, contains('requestKeyboard'));
  }, tags: const <String>['feature_test__soft_keyboard_visibility__widget']);
}
