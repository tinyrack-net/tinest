import 'dart:io';

/// Makes repository-relative contract fixtures independent of the test cwd.
void useRepositoryRoot() {
  var candidate = Directory.current.absolute;
  while (true) {
    if (File('${candidate.path}/packages/tinest_quality/pubspec.yaml')
        .existsSync()) {
      Directory.current = candidate.path;
      return;
    }
    final parent = candidate.parent;
    if (parent.path == candidate.path) {
      throw StateError('Tinest repository root not found.');
    }
    candidate = parent;
  }
}
