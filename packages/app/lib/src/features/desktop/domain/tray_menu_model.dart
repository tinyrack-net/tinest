import 'package:meta/meta.dart';

/// What selecting one tray menu row asks the app to do.
enum TrayMenuAction {
  /// Reveals the window when hidden and hides it when visible.
  toggleWindow,

  /// Shows the window on the General settings page.
  openSettings,

  /// Stops the embedded daemon and exits the process.
  quit,
}

/// Stable, locale-independent key of the show/hide row.
const String trayItemToggleWindow = 'tray.toggleWindow';

/// Stable, locale-independent key of the settings row.
const String trayItemOpenSettings = 'tray.openSettings';

/// Stable, locale-independent key of the quit row.
const String trayItemQuit = 'tray.quit';

/// Stable, locale-independent key of the embedded daemon status row.
const String trayItemDaemonStatus = 'tray.daemonStatus';

/// Stable, locale-independent key shared by every separator row.
const String trayItemSeparator = 'tray.separator';

/// One row of the native tray menu.
@immutable
final class TrayMenuEntry {
  /// Creates a selectable or informational tray row.
  const new({
    required this.key,
    required this.label,
    this.action,
    this.enabled = true,
  });

  /// Creates the divider between two groups of rows.
  const new separator()
    : key = trayItemSeparator,
      label = '',
      action = null,
      enabled = false;

  /// Identity used by the native menu, stable across languages.
  final String key;

  /// Text shown to the user in the active language.
  final String label;

  /// What the row does, or null when it only reports state.
  final TrayMenuAction? action;

  /// Whether the row can be selected.
  final bool enabled;

  /// Whether this row is a divider rather than a labelled row.
  bool get isSeparator => key == trayItemSeparator;

  @override
  bool operator ==(Object other) =>
      other is TrayMenuEntry &&
      other.key == key &&
      other.label == label &&
      other.action == action &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(key, label, action, enabled);
}

/// The complete tray presentation for one moment in time.
///
/// Value equality lets the shell skip a native menu rebuild when a widget
/// rebuild did not actually change anything the user can see.
@immutable
final class TrayMenuModel {
  /// Creates a tray presentation.
  const new({required this.tooltip, required this.entries});

  /// Hover text of the tray icon.
  final String tooltip;

  /// Rows in display order.
  final List<TrayMenuEntry> entries;

  /// Returns the action of the row with [key], or null when it has none.
  TrayMenuAction? actionFor(String key) {
    for (final entry in entries) {
      if (entry.key == key) return entry.action;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is TrayMenuModel &&
      other.tooltip == tooltip &&
      _sameEntries(other.entries, entries);

  @override
  int get hashCode => Object.hash(tooltip, Object.hashAll(entries));

  static bool _sameEntries(
    List<TrayMenuEntry> left,
    List<TrayMenuEntry> right,
  ) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
