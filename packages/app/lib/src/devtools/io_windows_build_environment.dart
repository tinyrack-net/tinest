import 'dart:io';

import 'package:app/src/devtools/windows_build_environment.dart';
import 'package:path/path.dart' as p;

/// Resolves native build-tool environment overrides for workspace commands.
Future<Map<String, String>> resolveWindowsBuildEnvironment() =>
    const WindowsBuildEnvironmentResolver(
      discovery: _IoWindowsBuildEnvironmentDiscovery(),
    ).resolve();

final class _IoWindowsBuildEnvironmentDiscovery
    implements WindowsBuildEnvironmentDiscovery {
  const new();

  @override
  bool get isWindows => Platform.isWindows;

  @override
  bool directoryExists(String path) => Directory(path).existsSync();

  @override
  String? environment(String name) => Platform.environment[name];

  @override
  Future<bool> executableExists(String executable) async {
    try {
      final result = await Process.run('where.exe', <String>[executable]);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  @override
  Future<String?> findVisualStudioInstallation() async {
    final programFiles =
        Platform.environment['ProgramFiles(x86)'] ?? r'C:\Program Files (x86)';
    final vswhere = p.windows.join(
      programFiles,
      'Microsoft Visual Studio',
      'Installer',
      'vswhere.exe',
    );
    if (!File(vswhere).existsSync()) return null;
    final result = await Process.run(vswhere, const <String>[
      '-latest',
      '-products',
      '*',
      '-requires',
      'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
      '-property',
      'installationPath',
    ]);
    if (result.exitCode != 0) return null;
    final installation = result.stdout.toString().trim();
    return installation.isEmpty ? null : installation;
  }
}
