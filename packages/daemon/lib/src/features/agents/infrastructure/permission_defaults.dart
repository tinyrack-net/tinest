import 'package:daemon/src/shared/infrastructure/persistence/repositories.dart';
import 'package:protocol/protocol.dart';

/// Reads and writes the one daemon-global permission mode that new sessions
/// are pinned to when the caller does not choose one.
///
/// A session owns a concrete mode from the moment it is created, so this
/// default is only ever consulted while creating one. Changing it later leaves
/// every existing session exactly where its own mode put it.
final class PermissionDefaults {
  /// Reads the default out of the daemon settings store.
  const new(this._settings);

  /// Settings key holding the stored mode name.
  static const String settingsKey = 'permission.defaultMode';

  final SettingsRepository _settings;

  /// Returns the configured default, falling back to the mode that asks
  /// before every mutation.
  ///
  /// An unreadable value degrades to that same fallback rather than throwing,
  /// so a row written by a newer build cannot stop the daemon from starting a
  /// session.
  Future<PermissionMode> read() async {
    final stored = await _settings.getValue(settingsKey);
    if (stored == null || stored.isEmpty) return PermissionMode.ask;
    return PermissionMode.values.firstWhere(
      (value) => value.name == stored,
      orElse: () => PermissionMode.ask,
    );
  }

  /// Stores the default new sessions are pinned to.
  Future<void> write(PermissionMode mode) =>
      _settings.setValue(settingsKey, mode.name);
}
