import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final root =
      Directory.current.path.endsWith(
        'packages${Platform.pathSeparator}tinest_quality',
      )
      ? Directory('../..').absolute
      : Directory.current.absolute;
  File workspaceFile(String path) => File('${root.path}/$path');
  Directory workspaceDirectory(String path) => Directory('${root.path}/$path');

  test('the mobile app dependency boundary excludes the embedded daemon', () {
    final manifests = <String, YamlMap>{};
    for (final entity in workspaceDirectory(
      'packages',
    ).listSync().whereType<Directory>()) {
      final file = File('${entity.path}/pubspec.yaml');
      if (!file.existsSync()) continue;
      final manifest = loadYaml(file.readAsStringSync()) as YamlMap;
      manifests[manifest['name'] as String] = manifest;
    }
    final closure = <String>{};
    void visit(String package) {
      if (!closure.add(package)) return;
      final dependencies = manifests[package]?['dependencies'];
      if (dependencies is! YamlMap) return;
      dependencies.keys.cast<String>().forEach(visit);
    }

    visit('app');
    expect(closure, isNot(contains(anyOf('daemon', 'drift', 'sqlite3'))));

    final pubspec = manifests['app']!;
    final devDependencies = (pubspec['dev_dependencies'] as YamlMap).keys
        .cast<String>()
        .toSet();

    expect(devDependencies, isNot(contains('daemon')));
  });

  test('mobile production sources cannot import the embedded daemon', () {
    final violations = workspaceDirectory('packages/app/lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => file.readAsStringSync().contains('package:daemon/'))
        .map((file) => file.path.replaceAll(r'\', '/'))
        .toList(growable: false);

    expect(violations, isEmpty);
  });

  test('app production sources cannot import the test-only facade', () {
    final violations = workspaceDirectory('packages/app/lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where(
          (file) => !file.path.replaceAll(r'\', '/').contains('/lib/testing'),
        )
        .where(
          (file) => file.readAsStringSync().contains('package:app/testing'),
        )
        .map((file) => file.path.replaceAll(r'\', '/'))
        .toList(growable: false);

    expect(violations, isEmpty);
  });

  test('desktop composition has its own package and matching version', () {
    final mobile = loadYaml(
      workspaceFile('packages/app/pubspec.yaml').readAsStringSync(),
    ) as YamlMap;
    final desktopFile = workspaceFile('packages/desktop_app/pubspec.yaml');

    expect(desktopFile.existsSync(), isTrue);
    final desktop = loadYaml(desktopFile.readAsStringSync()) as YamlMap;
    expect(desktop['version'], mobile['version']);
    expect((desktop['dependencies'] as YamlMap).keys, contains('daemon'));
  });

  test('mobile and desktop launch assets stay byte-identical', () {
    for (final directory in const <String>['brand', 'tray']) {
      final mobileDirectory = workspaceDirectory(
        'packages/app/assets/$directory',
      );
      final desktopDirectory = workspaceDirectory(
        'packages/desktop_app/assets/$directory',
      );
      final mobileFiles = mobileDirectory
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => !file.path.endsWith('.md'));
      for (final mobileFile in mobileFiles) {
        final relative = mobileFile.path.substring(mobileDirectory.path.length);
        final desktopFile = File('${desktopDirectory.path}$relative');
        expect(desktopFile.existsSync(), isTrue, reason: relative);
        expect(
          desktopFile.readAsBytesSync(),
          mobileFile.readAsBytesSync(),
          reason: relative,
        );
      }
    }
  });

  test('mobile launcher icons use the upstream safe-area assets', () {
    final pubspec = loadYaml(
      workspaceFile('packages/app/pubspec.yaml').readAsStringSync(),
    ) as YamlMap;
    final icons = pubspec['flutter_launcher_icons'] as YamlMap;
    const launcherPath = 'assets/brand/tinest-launcher-icon-1024.png';
    const adaptiveForegroundPath =
        'assets/brand/tinest-adaptive-foreground-1024.png';

    expect(icons['image_path_android'], launcherPath);
    expect(icons['image_path_ios'], launcherPath);
    expect(icons['adaptive_icon_foreground'], adaptiveForegroundPath);
    expect(
      (icons['web'] as YamlMap)['image_path'],
      'assets/brand/tinest-1024.png',
    );

    for (final relativePath in const <String>[
      launcherPath,
      adaptiveForegroundPath,
    ]) {
      final mobileFile = workspaceFile('packages/app/$relativePath');
      final desktopFile = workspaceFile('packages/desktop_app/$relativePath');
      expect(mobileFile.existsSync(), isTrue, reason: relativePath);
      expect(desktopFile.existsSync(), isTrue, reason: relativePath);
      expect(_pngDimensions(mobileFile), const (
        width: 1024,
        height: 1024,
      ), reason: relativePath);
      expect(
        desktopFile.readAsBytesSync(),
        mobileFile.readAsBytesSync(),
        reason: relativePath,
      );
    }
  });
}

({int width, int height}) _pngDimensions(File file) {
  final bytes = file.readAsBytesSync();
  const pngSignature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  expect(bytes, hasLength(greaterThanOrEqualTo(24)), reason: file.path);
  expect(bytes.take(8), orderedEquals(pngSignature), reason: file.path);

  int unsigned32(int offset) =>
      bytes[offset] << 24 |
      bytes[offset + 1] << 16 |
      bytes[offset + 2] << 8 |
      bytes[offset + 3];

  return (width: unsigned32(16), height: unsigned32(20));
}
