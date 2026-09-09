import 'package:app/src/features/agents/presentation/pages/agent_settings_page.dart';
import 'package:app/src/features/mcp/presentation/pages/mcp_settings_page.dart';
import 'package:app/src/features/providers/presentation/pages/provider_settings_page.dart';
import 'package:app/src/features/workspace/presentation/pages/project_settings_page.dart';
import 'package:app/src/shared/presentation/settings_layout.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every list-detail controller consumes its initial auto-selection', () {
    final projects = ProjectSettingsPaneController();
    final agents = AgentSettingsPaneController();
    final mcp = McpSettingsPaneController();
    final providers = ProviderSettingsPaneController();
    addTearDown(projects.dispose);
    addTearDown(agents.dispose);
    addTearDown(mcp.dispose);
    addTearDown(providers.dispose);

    _expectInitialSelectionIsConsumed(
      projects,
      () => projects.showInitialDetail('project'),
    );
    _expectInitialSelectionIsConsumed(
      agents,
      () => agents.selectInitial('agent'),
    );
    _expectInitialSelectionIsConsumed(mcp, () => mcp.selectInitial('server'));
    _expectInitialSelectionIsConsumed(
      providers,
      () => providers.selectInitialConnectionId('provider'),
    );
  }, tags: const <String>['feature_test__app_navigation__unit']);
}

void _expectInitialSelectionIsConsumed(
  SettingsPaneCoordinator controller,
  VoidCallback selectInitial,
) {
  expect(controller.canAutoSelect, isTrue);

  selectInitial();
  expect(controller.hasDetail, isTrue);
  expect(controller.canAutoSelect, isFalse);

  controller.showCollection();
  expect(controller.hasDetail, isFalse);
  expect(controller.canAutoSelect, isFalse);

  selectInitial();
  expect(controller.hasDetail, isFalse);

  controller.reset();
  expect(controller.canAutoSelect, isTrue);
  selectInitial();
  expect(controller.hasDetail, isTrue);
}
