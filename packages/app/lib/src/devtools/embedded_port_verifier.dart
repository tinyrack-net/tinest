import 'dart:io';

import 'package:path/path.dart' as p;

/// A test-isolation rule violation about machine-global daemon resources.
final class EmbeddedPortViolation {
  /// Creates an [EmbeddedPortViolation].
  const new({
    required this.path,
    required this.line,
    required this.rule,
    required this.message,
  });

  /// The file containing the violation.
  final String path;

  /// The one-based source line.
  final int line;

  /// The stable rule identifier.
  final String rule;

  /// A human-readable explanation.
  final String message;

  @override
  String toString() => '$path:$line [$rule] $message';
}

/// Verifies that E2E tests never bind a machine-global daemon port or home.
///
/// The app-owned daemon binds whatever `AppSettings.embeddedDaemonPort` says,
/// overriding the port in the injected `DaemonConfig`, so a test that pairs the
/// real `IsolateEmbeddedDaemonLauncher` with default settings binds 7337 on the
/// whole machine. Two checkouts verifying in parallel, or a developer running
/// `melos run:daemon`, then fail with `embeddedPortInUse`.
final class EmbeddedPortVerifier {
  /// Creates a verifier rooted at [workspaceRoot].
  const new(this.workspaceRoot);

  /// The Pub workspace root to inspect.
  final String workspaceRoot;

  /// Directory whose sources may start a real embedded daemon.
  static const String integrationTestDirectory =
      'packages/desktop_app/integration_test';

  /// Runs every check against the workspace and returns all violations.
  List<EmbeddedPortViolation> verify() {
    final directory = Directory(
      p.join(workspaceRoot, p.joinAll(p.posix.split(integrationTestDirectory))),
    );
    if (!directory.existsSync()) {
      return const <EmbeddedPortViolation>[];
    }
    final violations = <EmbeddedPortViolation>[];
    final files =
        directory
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .toList(growable: false)
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      violations.addAll(
        verifySource(
          path: p
              .relative(file.path, from: workspaceRoot)
              .replaceAll(r'\', '/'),
          source: file.readAsStringSync(),
        ),
      );
    }
    return violations;
  }

  /// Verifies one source fixture without touching the filesystem.
  List<EmbeddedPortViolation> verifySource({
    required String path,
    required String source,
  }) {
    final violations = <EmbeddedPortViolation>[
      ..._verifyFixedPortLiterals(path: path, source: source),
    ];
    if (!source.contains('IsolateEmbeddedDaemonLauncher')) return violations;
    return violations
      ..addAll(_verifyEphemeralLauncher(path: path, source: source))
      ..addAll(_verifyPinnedSettingsPort(path: path, source: source))
      ..addAll(_verifyInjectedConfig(path: path, source: source));
  }

  List<EmbeddedPortViolation> _verifyFixedPortLiterals({
    required String path,
    required String source,
  }) {
    final literal = RegExp(r'(?<![\w.])7337(?![\w.])');
    final lines = source.split('\n');
    return <EmbeddedPortViolation>[
      for (var index = 0; index < lines.length; index += 1)
        if (literal.hasMatch(lines[index]) ||
            lines[index].contains('defaultEmbeddedDaemonPort'))
          EmbeddedPortViolation(
            path: path,
            line: index + 1,
            rule: 'fixed_embedded_daemon_port',
            message:
                'Port 7337 is machine-global. Use the ephemeral embedded '
                'daemon launcher so parallel runs cannot collide.',
          ),
    ];
  }

  List<EmbeddedPortViolation> _verifyEphemeralLauncher({
    required String path,
    required String source,
  }) {
    if (source.contains('EphemeralEmbeddedDaemonLauncher')) {
      return const <EmbeddedPortViolation>[];
    }
    return <EmbeddedPortViolation>[
      EmbeddedPortViolation(
        path: path,
        line: _lineOf(source, 'IsolateEmbeddedDaemonLauncher'),
        rule: 'non_ephemeral_embedded_daemon_port',
        message:
            'A file that starts the real embedded daemon must wrap its '
            'launcher with EphemeralEmbeddedDaemonLauncher.',
      ),
    ];
  }

  /// Requires one pinned port per app store in a file that binds for real.
  ///
  /// `MemoryAppStore` defaults to the machine-global port, and the launcher
  /// lets the settings port win, so a store built without an explicit
  /// `embeddedDaemonPort` binds 7337. Settings are written across several
  /// lines, so the check pairs the two token counts instead of parsing.
  List<EmbeddedPortViolation> _verifyPinnedSettingsPort({
    required String path,
    required String source,
  }) {
    final stores = 'MemoryAppStore('.allMatches(source).length;
    final pinned = 'embeddedDaemonPort:'.allMatches(source).length;
    if (pinned >= stores) return const <EmbeddedPortViolation>[];
    return <EmbeddedPortViolation>[
      EmbeddedPortViolation(
        path: path,
        line: _lineOf(source, 'MemoryAppStore('),
        rule: 'unpinned_embedded_daemon_port',
        message:
            'Every MemoryAppStore in this file must set embeddedDaemonPort; '
            'found $stores stores and $pinned pinned ports.',
      ),
    ];
  }

  List<EmbeddedPortViolation> _verifyInjectedConfig({
    required String path,
    required String source,
  }) {
    if (!source.contains('IsolateEmbeddedDaemonLauncher(') ||
        source.contains('resolveConfig:')) {
      return const <EmbeddedPortViolation>[];
    }
    return <EmbeddedPortViolation>[
      EmbeddedPortViolation(
        path: path,
        line: _lineOf(source, 'IsolateEmbeddedDaemonLauncher('),
        rule: 'ambient_daemon_config',
        message:
            'Pass resolveConfig with a temporary home; the default reaches the '
            "real user's daemon home and its exclusive daemon.lock.",
      ),
    ];
  }

  int _lineOf(String source, String token) {
    final index = source.indexOf(token);
    if (index < 0) return 1;
    return '\n'.allMatches(source.substring(0, index)).length + 1;
  }
}
