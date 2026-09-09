import 'package:app/src/app/app_identity.dart';
import 'package:app/src/features/desktop/domain/tray_menu_model.dart';
import 'package:app/src/features/desktop/presentation/tray_menu.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/localization.dart';

void main() {
  TrayMenuModel menu({
    bool windowVisible = true,
    HostRuntimeSnapshot? daemon,
    bool supportsEmbeddedDaemon = true,
  }) => buildTrayMenu(
    l10n: testL10n,
    windowVisible: windowVisible,
    embeddedDaemon: daemon,
    supportsEmbeddedDaemon: supportsEmbeddedDaemon,
  );

  String labelFor(TrayMenuModel model, String key) =>
      model.entries.firstWhere((entry) => entry.key == key).label;

  test(
    'the first row offers to hide a visible window and to show a hidden one',
    () {
      expect(labelFor(menu(), trayItemToggleWindow), testL10n.trayHideWindow);
      expect(
        labelFor(menu(windowVisible: false), trayItemToggleWindow),
        testL10n.trayShowWindow,
      );
      expect(
        menu().actionFor(trayItemToggleWindow),
        TrayMenuAction.toggleWindow,
      );
      expect(
        menu().actionFor(trayItemOpenSettings),
        TrayMenuAction.openSettings,
      );
      expect(menu().actionFor(trayItemQuit), TrayMenuAction.quit);
      expect(menu().tooltip, testL10n.trayTooltip(AppIdentity.displayName));
    },
    tags: const <String>['feature_test__desktop_residency__unit'],
  );

  test(
    'the embedded daemon row reports every status and is never selectable',
    () {
      for (final status in HostRuntimeStatus.values) {
        final model = menu(
          daemon: HostRuntimeSnapshot(
            id: embeddedHostId,
            label: 'Embedded',
            kind: HostKind.embedded,
            status: status,
          ),
        );
        final row = model.entries.firstWhere(
          (entry) => entry.key == trayItemDaemonStatus,
        );
        expect(
          row.enabled,
          isFalse,
          reason: 'status $status must not be a command',
        );
        expect(row.action, isNull);
        expect(row.label, startsWith(testL10n.embeddedDaemonName));
        expect(model.actionFor(trayItemDaemonStatus), isNull);
      }

      // Before the daemon reports, the row reads as pending rather than as a
      // failure.
      final pending = menu().entries.firstWhere(
        (entry) => entry.key == trayItemDaemonStatus,
      );
      expect(pending.label, endsWith(testL10n.hostStatusPending));
    },
    tags: const <String>['feature_test__desktop_residency__unit'],
  );

  test('the embedded daemon row never includes unbounded failure details', () {
    const schemaFailure =
        'SQLite schema validation failed: expected a very long list of '
        'migrations, columns, indexes, and constraints that must remain '
        'available in settings without expanding the native tray menu.';
    final label = labelFor(
      menu(
        daemon: const HostRuntimeSnapshot(
          id: embeddedHostId,
          label: 'Embedded',
          kind: HostKind.embedded,
          status: HostRuntimeStatus.error,
          error: schemaFailure,
        ),
      ),
      trayItemDaemonStatus,
    );

    expect(
      label,
      '${testL10n.embeddedDaemonName}: ${testL10n.hostStatusError}',
    );
    expect(label, isNot(contains(schemaFailure)));
  }, tags: const <String>['feature_test__desktop_residency__unit']);

  test('a build without an embedded daemon omits the status row entirely', () {
    final model = menu(supportsEmbeddedDaemon: false);
    expect(
      model.entries.map((entry) => entry.key),
      isNot(contains(trayItemDaemonStatus)),
    );
    // The separator that introduced the status row goes with it, so two
    // dividers never end up adjacent.
    expect(model.entries.where((entry) => entry.isSeparator).length, 2);
    expect(model.actionFor(trayItemQuit), TrayMenuAction.quit);
  }, tags: const <String>['feature_test__desktop_residency__unit']);

  test(
    'menu equality ignores rebuilds and notices real presentation changes',
    () {
      expect(menu(), menu());
      expect(menu().hashCode, menu().hashCode);
      expect(menu(), isNot(menu(windowVisible: false)));
      expect(menu(), isNot(menu(supportsEmbeddedDaemon: false)));
      expect(
        menu(),
        isNot(
          menu(
            daemon: const HostRuntimeSnapshot(
              id: embeddedHostId,
              label: 'Embedded',
              kind: HostKind.embedded,
              status: HostRuntimeStatus.online,
            ),
          ),
        ),
      );
      expect(
        const TrayMenuEntry(key: 'a', label: 'A'),
        isNot(const TrayMenuEntry(key: 'a', label: 'A', enabled: false)),
      );
      expect(
        const TrayMenuEntry(key: 'a', label: 'A'),
        isNot(
          const TrayMenuEntry(
            key: 'a',
            label: 'A',
            action: TrayMenuAction.quit,
          ),
        ),
      );
      expect(const TrayMenuEntry.separator().isSeparator, isTrue);
      expect(menu().actionFor('tray.unknown'), isNull);
    },
    tags: const <String>['feature_test__desktop_residency__unit'],
  );
}
