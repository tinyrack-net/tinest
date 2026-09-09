import 'dart:io';

import 'package:test/test.dart';
import 'package:tinest_quality/src/desktop_version_sync.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('desktop-version-sync-');
    Directory('${root.path}/packages/app').createSync(recursive: true);
    Directory('${root.path}/packages/desktop_app').createSync(recursive: true);
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('copies the complete Flutter version into the desktop manifest', () {
    File('${root.path}/packages/app/pubspec.yaml')
        .writeAsStringSync('name: app\nversion: 0.8.1+10\n');
    final desktop = File('${root.path}/packages/desktop_app/pubspec.yaml')
      ..writeAsStringSync('name: desktop_app\nversion: 0.8.0+9\n');

    expect(DesktopVersionSync(root.path).synchronize(), isTrue);
    expect(desktop.readAsStringSync(), contains('version: 0.8.1+10'));
    expect(DesktopVersionSync(root.path).synchronize(), isFalse);
  });

  test('rejects a manifest without a version', () {
    File('${root.path}/packages/app/pubspec.yaml')
        .writeAsStringSync('name: app\n');
    File('${root.path}/packages/desktop_app/pubspec.yaml')
        .writeAsStringSync('name: desktop_app\nversion: 0.8.0+9\n');

    expect(
      () => DesktopVersionSync(root.path).synchronize(),
      throwsFormatException,
    );
  });
}
