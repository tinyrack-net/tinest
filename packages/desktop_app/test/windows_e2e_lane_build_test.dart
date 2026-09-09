import 'dart:io';

import 'package:test/test.dart';

import '../tool/src/windows_e2e_lane_build.dart';

void main() {
  test(
    'project reset removes only Flutter build cache before the first lane',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'tinest-windows-e2e-project-cache-',
      );
      final project = Directory('${root.path}${Platform.pathSeparator}project');
      final flutterBuildCache = Directory(
        '${project.path}${Platform.pathSeparator}.dart_tool'
        '${Platform.pathSeparator}flutter_build',
      );
      final sibling = File(
        '${project.path}${Platform.pathSeparator}.dart_tool'
        '${Platform.pathSeparator}package_config.json',
      );
      final sharedWrapper = File(
        '${project.path}${Platform.pathSeparator}windows'
        '${Platform.pathSeparator}flutter${Platform.pathSeparator}ephemeral'
        '${Platform.pathSeparator}cpp_client_wrapper'
        '${Platform.pathSeparator}core_implementations.cc',
      );
      addTearDown(() => root.delete(recursive: true));
      await flutterBuildCache.create(recursive: true);
      await File(
        '${flutterBuildCache.path}${Platform.pathSeparator}stale.stamp',
      ).writeAsString('stale ordinary target');
      await sibling.create(recursive: true);
      await sibling.writeAsString('keep');
      await sharedWrapper.create(recursive: true);
      await sharedWrapper.writeAsString('Flutter owned');

      await resetWindowsE2eProjectBuildCache(project.path);

      expect(flutterBuildCache.existsSync(), isFalse);
      expect(sibling.readAsStringSync(), 'keep');
      expect(sharedWrapper.readAsStringSync(), 'Flutter owned');
    },
  );

  test('project reset fails closed for a linked Flutter build cache', () async {
    final root = await Directory.systemTemp.createTemp(
      'tinest-windows-e2e-project-cache-link-',
    );
    final project = Directory('${root.path}${Platform.pathSeparator}project');
    final outside = Directory(
      '${root.path}${Platform.pathSeparator}outside-cache',
    );
    final sentinel = File(
      '${outside.path}${Platform.pathSeparator}sentinel.txt',
    );
    final flutterBuildCache =
        '${project.path}${Platform.pathSeparator}.dart_tool'
        '${Platform.pathSeparator}flutter_build';
    addTearDown(() async {
      if (FileSystemEntity.typeSync(flutterBuildCache, followLinks: false) ==
          FileSystemEntityType.link) {
        await Link(flutterBuildCache).delete();
      }
      await root.delete(recursive: true);
    });
    await Directory(flutterBuildCache).parent.create(recursive: true);
    await outside.create();
    await sentinel.writeAsString('must survive');
    await _createDirectoryLink(link: flutterBuildCache, target: outside.path);

    await expectLater(
      resetWindowsE2eProjectBuildCache(project.path),
      throwsStateError,
    );
    expect(sentinel.readAsStringSync(), 'must survive');
    expect(
      FileSystemEntity.typeSync(flutterBuildCache, followLinks: false),
      FileSystemEntityType.link,
    );
  });

  test('project reset fails closed for a linked .dart_tool parent', () async {
    final root = await Directory.systemTemp.createTemp(
      'tinest-windows-e2e-project-parent-link-',
    );
    final project = Directory('${root.path}${Platform.pathSeparator}project');
    final outside = Directory(
      '${root.path}${Platform.pathSeparator}outside-dart-tool',
    );
    final sentinel = File(
      '${outside.path}${Platform.pathSeparator}flutter_build'
      '${Platform.pathSeparator}sentinel.txt',
    );
    final dartTool = '${project.path}${Platform.pathSeparator}.dart_tool';
    addTearDown(() async {
      if (FileSystemEntity.typeSync(dartTool, followLinks: false) ==
          FileSystemEntityType.link) {
        await Link(dartTool).delete();
      }
      await root.delete(recursive: true);
    });
    await project.create();
    await sentinel.create(recursive: true);
    await sentinel.writeAsString('must survive');
    await _createDirectoryLink(link: dartTool, target: outside.path);

    await expectLater(
      resetWindowsE2eProjectBuildCache(project.path),
      throwsStateError,
    );
    expect(sentinel.readAsStringSync(), 'must survive');
    expect(
      FileSystemEntity.typeSync(dartTool, followLinks: false),
      FileSystemEntityType.link,
    );
  });

  test(
    'lane reset deletes only its lane and preserves Flutter shared outputs',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'tinest-windows-e2e-ordinary-',
      );
      final project = Directory('${root.path}${Platform.pathSeparator}project');
      final lane = Directory(
        '${project.path}${Platform.pathSeparator}build'
        '${Platform.pathSeparator}e2e${Platform.pathSeparator}lane-0'
        '${Platform.pathSeparator}windows',
      );
      final sibling = File(
        '${project.path}${Platform.pathSeparator}build'
        '${Platform.pathSeparator}e2e${Platform.pathSeparator}lane-1'
        '${Platform.pathSeparator}windows${Platform.pathSeparator}keep.txt',
      );
      final ephemeral = Directory(
        '${project.path}${Platform.pathSeparator}windows'
        '${Platform.pathSeparator}flutter${Platform.pathSeparator}ephemeral',
      );
      addTearDown(() => root.delete(recursive: true));
      await lane.create(recursive: true);
      await File('${lane.path}${Platform.pathSeparator}stale.txt')
          .writeAsString('stale');
      await sibling.create(recursive: true);
      await sibling.writeAsString('keep');
      await ephemeral.create(recursive: true);
      final wrapper = File(
        '${ephemeral.path}${Platform.pathSeparator}stale.cc',
      );
      await wrapper.writeAsString('shared Flutter output');
      await resetWindowsE2eLaneBuild(
        projectDirectory: project.path,
        laneIndex: 0,
      );

      expect(lane.existsSync(), isFalse);
      expect(wrapper.readAsStringSync(), 'shared Flutter output');
      expect(sibling.readAsStringSync(), 'keep');
    },
  );

  test(
    'lane reset leaves shared Flutter outputs when its lane is absent',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'tinest-windows-e2e-missing-',
      );
      final project = Directory('${root.path}${Platform.pathSeparator}project');
      addTearDown(() => root.delete(recursive: true));
      await project.create();
      final ephemeral = Directory(
        '${project.path}${Platform.pathSeparator}windows'
        '${Platform.pathSeparator}flutter${Platform.pathSeparator}ephemeral',
      );
      await ephemeral.create(recursive: true);

      await resetWindowsE2eLaneBuild(
        projectDirectory: project.path,
        laneIndex: 0,
      );

      expect(project.existsSync(), isTrue);
      expect(ephemeral.existsSync(), isTrue);
    },
  );

  test('lane reset fails closed for a non-directory segment', () async {
    final root = await Directory.systemTemp.createTemp(
      'tinest-windows-e2e-file-',
    );
    final project = Directory('${root.path}${Platform.pathSeparator}project');
    final build = File('${project.path}${Platform.pathSeparator}build');
    addTearDown(() => root.delete(recursive: true));
    await project.create();
    await build.writeAsString('must survive');

    await expectLater(
      resetWindowsE2eLaneBuild(projectDirectory: project.path, laneIndex: 0),
      throwsStateError,
    );
    expect(build.readAsStringSync(), 'must survive');
  });

  test('lane reset fails closed for a directory link target', () async {
    final root = await Directory.systemTemp.createTemp(
      'tinest-windows-e2e-reset-',
    );
    final project = Directory('${root.path}${Platform.pathSeparator}project');
    final outside = Directory('${root.path}${Platform.pathSeparator}outside');
    final sentinel = File(
      '${outside.path}${Platform.pathSeparator}sentinel.txt',
    );
    final lane =
        '${project.path}${Platform.pathSeparator}build'
        '${Platform.pathSeparator}e2e${Platform.pathSeparator}lane-0'
        '${Platform.pathSeparator}windows';
    addTearDown(() async {
      if (FileSystemEntity.typeSync(lane, followLinks: false) ==
          FileSystemEntityType.link) {
        await Link(lane).delete();
      }
      await root.delete(recursive: true);
    });
    await project.create();
    await outside.create();
    await sentinel.writeAsString('must survive');
    await Directory(lane).parent.create(recursive: true);
    await _createDirectoryLink(link: lane, target: outside.path);
    expect(
      FileSystemEntity.typeSync(lane, followLinks: false),
      FileSystemEntityType.link,
    );
    await expectLater(
      resetWindowsE2eLaneBuild(projectDirectory: project.path, laneIndex: 0),
      throwsStateError,
    );
    expect(sentinel.readAsStringSync(), 'must survive');
    expect(
      FileSystemEntity.typeSync(lane, followLinks: false),
      FileSystemEntityType.link,
    );
  });

  test('lane reset fails closed for a linked parent segment', () async {
    final root = await Directory.systemTemp.createTemp(
      'tinest-windows-e2e-parent-link-',
    );
    final project = Directory('${root.path}${Platform.pathSeparator}project');
    final outsideBuild = Directory(
      '${root.path}${Platform.pathSeparator}outside-build',
    );
    final linkedBuild = '${project.path}${Platform.pathSeparator}build';
    final outsideLane = Directory(
      '${outsideBuild.path}${Platform.pathSeparator}e2e'
      '${Platform.pathSeparator}lane-0${Platform.pathSeparator}windows',
    );
    final sentinel = File(
      '${outsideLane.path}${Platform.pathSeparator}sentinel.txt',
    );
    addTearDown(() async {
      if (FileSystemEntity.typeSync(linkedBuild, followLinks: false) ==
          FileSystemEntityType.link) {
        await Link(linkedBuild).delete();
      }
      await root.delete(recursive: true);
    });
    await project.create();
    await outsideLane.create(recursive: true);
    await sentinel.writeAsString('must survive');
    await _createDirectoryLink(link: linkedBuild, target: outsideBuild.path);
    expect(
      FileSystemEntity.typeSync(linkedBuild, followLinks: false),
      FileSystemEntityType.link,
    );
    await expectLater(
      resetWindowsE2eLaneBuild(projectDirectory: project.path, laneIndex: 0),
      throwsStateError,
    );
    expect(sentinel.readAsStringSync(), 'must survive');
    expect(
      FileSystemEntity.typeSync(linkedBuild, followLinks: false),
      FileSystemEntityType.link,
    );
  });

  test(
    'lane reset never follows or removes a linked shared ephemeral',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'tinest-windows-e2e-ephemeral-link-',
      );
      final project = Directory('${root.path}${Platform.pathSeparator}project');
      final outside = Directory('${root.path}${Platform.pathSeparator}outside');
      final sentinel = File(
        '${outside.path}${Platform.pathSeparator}sentinel.txt',
      );
      final ephemeral =
          '${project.path}${Platform.pathSeparator}windows'
          '${Platform.pathSeparator}flutter${Platform.pathSeparator}ephemeral';
      addTearDown(() async {
        if (FileSystemEntity.typeSync(ephemeral, followLinks: false) ==
            FileSystemEntityType.link) {
          await Link(ephemeral).delete();
        }
        await root.delete(recursive: true);
      });
      await Directory(ephemeral).parent.create(recursive: true);
      await outside.create();
      await sentinel.writeAsString('must survive');
      await _createDirectoryLink(link: ephemeral, target: outside.path);

      await resetWindowsE2eLaneBuild(
        projectDirectory: project.path,
        laneIndex: 0,
      );
      expect(sentinel.readAsStringSync(), 'must survive');
      expect(
        FileSystemEntity.typeSync(ephemeral, followLinks: false),
        FileSystemEntityType.link,
      );
    },
  );
}

Future<void> _createDirectoryLink({
  required String link,
  required String target,
}) async {
  if (!Platform.isWindows) {
    await Link(link).create(target);
    return;
  }
  final result = await Process.run('cmd.exe', <String>[
    '/d',
    '/c',
    'mklink',
    '/J',
    link,
    target,
  ]);
  expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
}
