import 'package:app/src/devtools/io_windows_build_environment.dart';
import 'package:app/src/devtools/windows_build_environment.dart';
import 'package:test/test.dart';

void main() {
  test('host build tools resolve for the desktop runner', () async {
    final environment = await resolveWindowsBuildEnvironment();
    expect(environment, isA<Map<String, String>>());
  });

  test('non-Windows hosts need no build-tool environment', () async {
    final discovery = _FakeDiscovery(isWindows: false);

    expect(
      await WindowsBuildEnvironmentResolver(discovery: discovery).resolve(),
      isEmpty,
    );
    expect(discovery.executableLookups, isEmpty);
  });

  test('an existing CMake and Ninja PATH remains unchanged', () async {
    final discovery = _FakeDiscovery(
      executables: const <String>{'cmake', 'ninja'},
    );

    expect(
      await WindowsBuildEnvironmentResolver(discovery: discovery).resolve(),
      isEmpty,
    );
    expect(discovery.visualStudioLookups, 0);
  });

  test('Visual Studio CMake and Ninja are prepended on Windows', () async {
    final discovery = _FakeDiscovery(
      visualStudioInstallation:
          r'C:\Program Files\Microsoft Visual Studio\18\Community',
      directories: const <String>{
        r'C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin',
        r'C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja',
      },
      path: r'C:\Windows\System32',
    );

    expect(
      await WindowsBuildEnvironmentResolver(discovery: discovery).resolve(),
      <String, String>{
        'PATH': '${discovery.directories.join(';')};C:\\Windows\\System32',
      },
    );
  });

  test('missing Windows CMake reports the required VS component', () async {
    final discovery = _FakeDiscovery();

    await expectLater(
      WindowsBuildEnvironmentResolver(discovery: discovery).resolve(),
      throwsA(
        isA<WindowsBuildToolsException>().having(
          (error) => error.toString(),
          'message',
          contains('C++ CMake tools for Windows'),
        ),
      ),
    );
  });
}

final class _FakeDiscovery implements WindowsBuildEnvironmentDiscovery {
  new({
    this.isWindows = true,
    this.executables = const <String>{},
    this.visualStudioInstallation,
    this.directories = const <String>{},
    this.path = '',
  });

  @override
  final bool isWindows;
  final Set<String> executables;
  final String? visualStudioInstallation;
  final Set<String> directories;
  final String path;
  final List<String> executableLookups = <String>[];
  int visualStudioLookups = 0;

  @override
  bool directoryExists(String path) => directories.contains(path);

  @override
  String? environment(String name) => name == 'PATH' ? path : null;

  @override
  Future<bool> executableExists(String executable) async {
    executableLookups.add(executable);
    return executables.contains(executable);
  }

  @override
  Future<String?> findVisualStudioInstallation() async {
    visualStudioLookups += 1;
    return visualStudioInstallation;
  }
}
