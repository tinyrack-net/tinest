import 'dart:io';

/// Keeps the desktop Flutter manifest on the mobile app release version.
final class DesktopVersionSync {
  /// Creates a workspace version synchronizer.
  const new(this.workspaceRoot);

  /// Absolute or relative workspace root.
  final String workspaceRoot;

  /// Updates the desktop manifest and returns whether it changed.
  bool synchronize() {
    final mobile = File('$workspaceRoot/packages/app/pubspec.yaml');
    final desktop = File('$workspaceRoot/packages/desktop_app/pubspec.yaml');
    final versionPattern = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true);
    final mobileMatch = versionPattern.firstMatch(mobile.readAsStringSync());
    if (mobileMatch == null) {
      throw const FormatException('Mobile pubspec has no version.');
    }
    final desktopSource = desktop.readAsStringSync();
    final desktopMatch = versionPattern.firstMatch(desktopSource);
    if (desktopMatch == null) {
      throw const FormatException('Desktop pubspec has no version.');
    }
    final mobileVersion = mobileMatch.group(1)!;
    if (desktopMatch.group(1) == mobileVersion) return false;
    desktop.writeAsStringSync(
      desktopSource.replaceFirst(versionPattern, 'version: $mobileVersion'),
    );
    return true;
  }
}
