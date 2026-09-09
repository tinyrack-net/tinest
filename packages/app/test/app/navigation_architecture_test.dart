import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'responsive navigation is owned by typed shells and Flutter Navigators',
    () {
      final router = File('lib/src/app/router/app_router.dart')
          .readAsStringSync();
      final settings = File('lib/src/app/presentation/settings_page.dart')
          .readAsStringSync();
      final workspace = File('lib/src/app/presentation/workspace_page.dart')
          .readAsStringSync();
      final provider = File(
        'lib/src/features/providers/presentation/pages/provider_settings_page.dart',
      ).readAsStringSync();
      final production = '$settings\n$workspace\n$provider';

      expect(router, contains('@TypedShellRoute<SettingsShellRoute>'));
      expect(router, contains('@TypedShellRoute<WorkspaceShellRoute>'));
      expect(settings, contains('SettingsListDetailHost'));
      expect(production, isNot(contains('TRThreePaneNavigator')));
      expect(production, isNot(contains('TRNavigableThreePaneScaffold')));
      expect(production, isNot(contains('TRPaneNavigationOperation')));
      expect(production, isNot(contains('_adaptiveNavigation')));
      expect(workspace, isNot(contains('_scheduleAdaptiveDestinationSync')));
      expect(settings, isNot(contains('_scheduleAdaptiveDestinationReset')));
    },
    tags: const <String>['feature_test__app_navigation__unit'],
  );
}
