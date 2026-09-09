import 'package:path/path.dart' as p;

/// Host boundary used to discover Windows native build tools.
abstract interface class WindowsBuildEnvironmentDiscovery {
  /// Whether the current host is Windows.
  bool get isWindows;

  /// Reads one process environment variable.
  String? environment(String name);

  /// Whether [executable] is already resolvable from the current PATH.
  Future<bool> executableExists(String executable);

  /// Finds the latest Visual Studio installation with the C++ toolchain.
  Future<String?> findVisualStudioInstallation();

  /// Whether a directory exists at [path].
  bool directoryExists(String path);
}

/// Failure to find native build tools required by Windows tests.
final class WindowsBuildToolsException implements Exception {
  /// Creates a build-tool discovery failure.
  const new(this.message);

  /// Actionable failure description.
  final String message;

  @override
  String toString() => message;
}

/// Resolves PATH overrides for CMake-backed tests on Windows.
final class WindowsBuildEnvironmentResolver {
  /// Creates a resolver backed by [discovery].
  const new({required this.discovery});

  /// Host discovery boundary.
  final WindowsBuildEnvironmentDiscovery discovery;

  /// Returns environment overrides needed by child verification processes.
  Future<Map<String, String>> resolve() async {
    if (!discovery.isWindows) return const <String, String>{};
    final hasCmake = await discovery.executableExists('cmake');
    final hasNinja = await discovery.executableExists('ninja');
    if (hasCmake && hasNinja) return const <String, String>{};

    final installation = await discovery.findVisualStudioInstallation();
    if (installation == null || installation.isEmpty) {
      throw const WindowsBuildToolsException(
        'Windows verification requires the Visual Studio '
        '"C++ CMake tools for Windows" component.',
      );
    }
    final cmake = p.windows.join(
      installation,
      'Common7',
      'IDE',
      'CommonExtensions',
      'Microsoft',
      'CMake',
      'CMake',
      'bin',
    );
    final ninja = p.windows.join(
      installation,
      'Common7',
      'IDE',
      'CommonExtensions',
      'Microsoft',
      'CMake',
      'Ninja',
    );
    if (!discovery.directoryExists(cmake) ||
        !discovery.directoryExists(ninja)) {
      throw const WindowsBuildToolsException(
        'Windows verification requires the Visual Studio '
        '"C++ CMake tools for Windows" component.',
      );
    }

    final currentPath = discovery.environment('PATH');
    return <String, String>{
      'PATH': <String>[
        cmake,
        ninja,
        if (currentPath != null && currentPath.isNotEmpty) currentPath,
      ].join(';'),
    };
  }
}
