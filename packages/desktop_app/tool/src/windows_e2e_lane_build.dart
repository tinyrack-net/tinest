import 'dart:io';

import 'package:app/testing/devtools/desktop_e2e_runner.dart';

/// Removes Flutter's shared incremental build cache before Windows E2E.
///
/// Flutter desktop targets with different entrypoints share
/// `windows/flutter/ephemeral`, but cache their output ownership under
/// `.dart_tool/flutter_build`. Keeping an ordinary target's stale ownership
/// record while E2E target hashes come and go can make the next ordinary build
/// delete shared wrapper sources and then skip the target that restores them.
/// The first E2E lane invalidates the cache under the project build lease;
/// later lanes must retain the fresh cache created by that transition.
Future<void> resetWindowsE2eProjectBuildCache(String projectDirectory) async {
  final project = Directory(projectDirectory).absolute;
  final target = _validatedGeneratedDirectory(
    project,
    '.dart_tool/flutter_build',
  );
  await target?.delete(recursive: true);
}

/// Removes the persistent Windows build subtree owned by one E2E lane.
///
/// Flutter owns `windows/flutter/ephemeral`, which is shared by every build
/// directory. Deleting that directory outside Flutter can leave its first
/// incremental invocation compiling CMake targets before the client wrapper
/// sources have been restored. Invalidating the lane output is sufficient to
/// make Flutter reconcile its own generated inputs without racing that shared
/// state.
Future<void> resetWindowsE2eLaneBuild({
  required String projectDirectory,
  required int laneIndex,
}) async {
  final project = Directory(projectDirectory).absolute;
  final target = _validatedGeneratedDirectory(
    project,
    desktopE2eWindowsLaneBuildPath(laneIndex),
  );
  await target?.delete(recursive: true);
}

Directory? _validatedGeneratedDirectory(
  Directory project,
  String relativePath,
) {
  final nativeRelativePath = relativePath.replaceAll(
    '/',
    Platform.pathSeparator,
  );
  final target = Directory(
    '${project.path}${Platform.pathSeparator}$nativeRelativePath',
  ).absolute;
  final projectPrefix = '${project.path}${Platform.pathSeparator}';
  if (!target.path.startsWith(projectPrefix)) {
    throw StateError('Windows generated path escaped the desktop project.');
  }

  final candidatePath = StringBuffer(project.path);
  for (final segment in nativeRelativePath.split(Platform.pathSeparator)) {
    candidatePath
      ..write(Platform.pathSeparator)
      ..write(segment);
    final path = candidatePath.toString();
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return null;
    if (type == FileSystemEntityType.link) {
      throw StateError(
        'Windows generated path contains a symbolic link or junction: '
        '$path',
      );
    }
    if (type != FileSystemEntityType.directory) {
      throw StateError(
        'Windows generated path contains a non-directory entry: '
        '$path',
      );
    }
  }
  return target;
}
