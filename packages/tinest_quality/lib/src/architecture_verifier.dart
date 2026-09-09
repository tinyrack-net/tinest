import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tinest_quality/src/lifecycle_phase_rules.dart';

/// A dependency or source-level architecture rule violation.
final class ArchitectureViolation {
  /// Creates an [ArchitectureViolation].
  const new({
    required this.path,
    required this.line,
    required this.rule,
    required this.message,
  });

  /// The file containing the violation.
  final String path;

  /// The one-based source line, or zero for pubspec violations.
  final int line;

  /// The stable architecture rule identifier.
  final String rule;

  /// A human-readable explanation.
  final String message;

  @override
  String toString() => '$path${line == 0 ? '' : ':$line'} [$rule] $message';
}

/// Verifies package boundaries and application-layer dependency rules.
final class ArchitectureVerifier {
  /// Creates a verifier rooted at [workspaceRoot].
  const new(this.workspaceRoot);

  /// The Pub workspace root to inspect.
  final String workspaceRoot;

  /// Every `keepAlive` provider, and who is answerable for its lifetime.
  ///
  /// A `keepAlive` provider cannot be ended by Riverpod, so something else must
  /// end it — and when that something is a widget, ending it means
  /// `Ref.invalidate` from a lifecycle callback, which schedules a `setState`
  /// during the build phase and crashes. Naming the owner and the bound here is
  /// what keeps that precondition from being recreated by accident: a new
  /// `keepAlive` provider fails this check until someone can write that
  /// sentence.
  static const Map<String, String> _keepAliveProviderOwners = <String, String>{
    'HostRegistryController':
        'Application-scoped and single-keyed. Lives for the process; the '
        'registry it wraps is closed by the composition root.',
    'activeHostId':
        'Derived from HostRegistryController, single-keyed. No family, so no '
        'growth.',
    'SelectionRestoreController':
        'Single-keyed launch-time latch. Consumed once per run by '
        'WorkspacePage, reset only by the data reset in AdvancedSettingsPage.',
    'WorkspaceCatalogController':
        'Single-keyed catalog of every host. Refreshed in place; never '
        'family-keyed, so it cannot grow.',
    'modelPickerOptionsLoader':
        'Keyed by hostId and stateless: it only closes over its own Ref so a '
        'picker opened later still has one. Bounded by the number of '
        'configured daemons, exactly like ProviderSettingsController.',
    'ProviderSettingsController':
        'Keyed by hostId, bounded by the number of configured daemons, which '
        'the user manages explicitly in daemon settings.',
    'PendingFirstTurns':
        'Single-keyed. Holds a map keyed by session id whose entries are '
        'cleared when a conversation pane mounts; a failure whose pane never '
        'mounts is retained. Bounded work is tracked, not yet done.',
    'ConversationReadingPositions':
        'Single-keyed. Holds at most retainedReadingPositions entries, keyed '
        'by host and session and evicted least-recently-read first, so a long '
        'run cannot accumulate layout snapshots. An entry is dropped as soon '
        'as its reader returns to the newest message.',
    'SessionComposerDraftController':
        'Keyed by (hostId, worktreeId, draftId) and NOT yet bounded: every '
        'draft ever opened is retained for the process. Ends only via the '
        'family-wide reset in AdvancedSettingsPage. Should move to the lease '
        'shape in TerminalSessionLeases; deliberately not folded in with the '
        'terminal work because a draft outlives its tab by design and losing '
        'one loses typed input.',
  };

  static const Map<String, Set<String>>
  _allowedInternalDependencies = <String, Set<String>>{
    'protocol': <String>{},
    'relay_protocol': <String>{},
    'relay': <String>{'relay_protocol'},
    'tinest_quality': <String>{},
    'agent': <String>{},
    'client': <String>{'protocol', 'relay_protocol'},
    // The CLI hosts the daemon through `tinest-cli daemon start`, so it
    // reaches the daemon's composition root and everything the daemon
    // itself is allowed to use.
    'cli': <String>{'agent', 'client', 'daemon', 'protocol', 'relay_protocol'},
    'daemon': <String>{'agent', 'protocol', 'relay_protocol'},
    'app': <String>{'client', 'protocol'},
    // The desktop composition root is the only application package that
    // may host the daemon. Mobile and web remain behind `app`'s client
    // boundary.
    'desktop_app': <String>{'app', 'daemon'},
  };

  // Vendor identifiers that must never appear outside an adapter package.
  //
  // A vendor's name in shared code is how the last refactor's leaks began: a
  // ChatGPT gateway in the daemon, an id switch in the settings page, an enum
  // of one vendor's flows in the CLI. Everything vendor-specific now lives in
  // provider infrastructure; the one legitimate mention elsewhere is the
  // daemon's composition root, which assembles the registry.
  static final RegExp _vendorIdentifier = RegExp(
    'openai|chatgpt|anthropic|deepseek|openrouter|groq|ollama|lmstudio'
    '|vllm|gemini|claude',
    caseSensitive: false,
  );

  // Built-in tool names that must never appear as string literals in the app
  // outside the presenter tree that owns them.
  //
  // One tool's name used to reach the UI through six literal sites; the
  // presenters in chat/tools/ are now the single place a tool name may be
  // spelled, with the timeline's dedicated card builders as the documented
  // exception because they hold per-turn state a presenter cannot.
  static final RegExp _quotedToolName = RegExp(
    "'(list_directory|read_file|search_text|glob|update_plan|apply_patch"
    '|attach_file|read_attachment|view_image|request_user_input'
    '|clock__curr_time|clock__sleep'
    '|exec_command|write_stdin|tool_search|list_skills|get_context_remaining'
    '|new_context|list_mcp_resources|list_mcp_resource_templates'
    '|read_mcp_resource|spawn_agent|followup_task|wait_agent|interrupt_agent'
    "|list_agents|skills__list|skills__read)'",
  );

  static bool _mayNameVendors(String package, String path) =>
      package == 'tinest_quality' ||
      (package == 'daemon' &&
          (path.contains('/features/providers/infrastructure/') ||
              path.contains('/bootstrap/')));

  static bool _mayNameTools(String package, String path) {
    if (package != 'app') return true;
    return path.contains('/features/conversation/presentation/tools/') ||
        path.endsWith(
          '/features/conversation/application/chat_timeline_model.dart',
        );
  }

  // Packages resolved from outside this workspace that must still stay behind
  // one boundary. `ptyworld` spawns native pseudo-terminals, so only the
  // daemon's terminal gateway may reach it; every other package goes through
  // the daemon. Without this map those imports would be unrestricted, because
  // enforcement is otherwise keyed off `_allowedInternalDependencies`, and
  // that failure would be silent.
  static const Map<String, Set<String>> _restrictedExternalPackages =
      <String, Set<String>>{
        'ptyworld': <String>{'daemon'},
        // The app reaches the same emulator through `termworld`, which
        // re-exports it. Importing it directly here would let a second copy of
        // the grid semantics into the tree.
        'vtworld': <String>{'daemon'},
      };

  /// Whether [consumer] is forbidden from depending on [dependency].
  static bool _isForbidden(String consumer, String dependency) {
    if (_allowedInternalDependencies.containsKey(dependency)) {
      return !(_allowedInternalDependencies[consumer] ?? const <String>{})
          .contains(dependency);
    }
    final allowedConsumers = _restrictedExternalPackages[dependency];
    return allowedConsumers != null && !allowedConsumers.contains(consumer);
  }

  /// Runs every architecture check and returns all violations.
  List<ArchitectureViolation> verify() {
    final violations = <ArchitectureViolation>[..._verifyPackageSet()];
    for (final package in _allowedInternalDependencies.keys) {
      final directory = p.join(workspaceRoot, 'packages', package);
      if (!Directory(directory).existsSync()) continue;
      violations
        ..addAll(_verifyPubspec(package, directory))
        ..addAll(_verifySources(package, directory));
    }
    return violations;
  }

  List<ArchitectureViolation> _verifyPackageSet() {
    final packages = Directory(p.join(workspaceRoot, 'packages'));
    if (!packages.existsSync()) return const <ArchitectureViolation>[];
    final actual = packages
        .listSync()
        .whereType<Directory>()
        .map((directory) => p.basename(directory.path))
        .toSet();
    const expected = <String>{
      'agent',
      'app',
      'cli',
      'client',
      'daemon',
      'desktop_app',
      'protocol',
      'relay',
      'relay_protocol',
      'tinest_quality',
    };
    if (actual.length == expected.length && actual.containsAll(expected)) {
      return const <ArchitectureViolation>[];
    }
    return <ArchitectureViolation>[
      ArchitectureViolation(
        path: 'packages',
        line: 0,
        rule: 'internal_package_set',
        message:
            'Expected exactly ${expected.toList()..sort()}, found '
            '${actual.toList()..sort()}.',
      ),
    ];
  }

  List<ArchitectureViolation> _verifyPubspec(String package, String directory) {
    final path = p.join(directory, 'pubspec.yaml');
    final dependencies = _productionDependencies(File(path).readAsLinesSync());
    return <ArchitectureViolation>[
      for (final dependency in dependencies)
        if (_isForbidden(package, dependency))
          ArchitectureViolation(
            path: p.relative(path, from: workspaceRoot),
            line: 0,
            rule: 'package_dependency_direction',
            message: '$package must not depend on $dependency.',
          ),
    ];
  }

  Set<String> _productionDependencies(List<String> lines) {
    final dependencies = <String>{};
    var inDependencies = false;
    for (final line in lines) {
      if (line == 'dependencies:') {
        inDependencies = true;
        continue;
      }
      if (inDependencies && line.isNotEmpty && !line.startsWith(' ')) break;
      if (!inDependencies) continue;
      final match = RegExp('^  ([a-zA-Z0-9_]+):').firstMatch(line);
      if (match != null) dependencies.add(match.group(1)!);
    }
    return dependencies;
  }

  List<ArchitectureViolation> _verifySources(String package, String directory) {
    final lib = Directory(p.join(directory, 'lib'));
    if (!lib.existsSync()) return const <ArchitectureViolation>[];
    final violations = <ArchitectureViolation>[];
    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart') ||
          entity.path.endsWith('.freezed.dart') ||
          entity.path.contains('${p.separator}l10n${p.separator}gen')) {
        continue;
      }
      violations.addAll(
        verifySource(
          package: package,
          path: p.relative(entity.path, from: workspaceRoot),
          source: entity.readAsStringSync(),
        ),
      );
    }
    return violations;
  }

  /// Verifies one source fixture without touching the filesystem.
  List<ArchitectureViolation> verifySource({
    required String package,
    required String path,
    required String source,
  }) => _verifyNormalizedSource(
    package: package,
    // The filesystem walk hands in host-native separators; every rule below
    // matches forward-slash layouts, so one canonical form keeps the checker
    // platform-independent.
    path: path.replaceAll(r'\', '/'),
    source: source,
  );

  List<ArchitectureViolation> _verifyNormalizedSource({
    required String package,
    required String path,
    required String source,
  }) {
    final violations = <ArchitectureViolation>[];
    final lines = source.split('\n');
    final applicationLayer = _isApplicationLayer(package, path);
    violations.addAll(
      _verifyLifecyclePhase(package: package, path: path, source: source),
    );
    for (var index = 0; index < lines.length; index += 1) {
      final line = lines[index];
      final importedPackage = RegExp(r"^\s*import 'package:([a-zA-Z0-9_]+)/")
          .firstMatch(line)
          ?.group(1);
      if (package == 'app') {
        violations.addAll(
          _verifyTinestAppLayerImport(
            path: path,
            line: index + 1,
            source: line,
          ),
        );
        if (_declaresKeepAliveProvider(lines, index)) {
          final owner = _providerDeclarationName(lines, index);
          if (owner == null || !_keepAliveProviderOwners.containsKey(owner)) {
            violations.add(
              ArchitectureViolation(
                path: path,
                line: index + 1,
                rule: 'keepalive_provider_owner',
                message:
                    'A keepAlive provider (${owner ?? 'unnamed'}) must be '
                    'listed in ArchitectureVerifier._keepAliveProviderOwners '
                    'with who ends its lifetime and what bounds it.',
              ),
            );
          }
        }
        final terminalCaret =
            path.endsWith(
              '/features/terminals/presentation/tinest_terminal_view.dart',
            ) &&
            line.contains('cursor: colors.focus');
        if (!terminalCaret &&
            (line.contains('TRControlMetrics.focusWidth') ||
                line.contains('tinyrackTheme.focus') ||
                line.contains('colors.focus'))) {
          violations.add(
            ArchitectureViolation(
              path: path,
              line: index + 1,
              rule: 'local_focus_style',
              message:
                  'App controls must delegate focus emphasis to a public '
                  'Tinyrack component.',
            ),
          );
        }
      }
      if (importedPackage != null &&
          importedPackage != package &&
          _isForbidden(package, importedPackage)) {
        violations.add(
          ArchitectureViolation(
            path: path,
            line: index + 1,
            rule: 'source_dependency_direction',
            message: '$package must not import $importedPackage.',
          ),
        );
      }
      if (package == 'daemon' && path.endsWith('/transport/rpc/server.dart')) {
        if (line.contains('package:daemon/src/features/')) {
          violations.add(
            ArchitectureViolation(
              path: path,
              line: index + 1,
              rule: 'rpc_server_feature_import',
              message: 'The RPC server must depend only on feature bindings.',
            ),
          );
        }
        if (line.contains('switch (method)')) {
          violations.add(
            ArchitectureViolation(
              path: path,
              line: index + 1,
              rule: 'central_rpc_switch',
              message: 'Feature modules own RPC dispatch.',
            ),
          );
        }
      }
      if (package == 'client' &&
          path.endsWith('/src/api.dart') &&
          line.contains('ClientEvent')) {
        violations.add(
          ArchitectureViolation(
            path: path,
            line: index + 1,
            rule: 'raw_client_event',
            message: 'Feature APIs must expose their own typed streams.',
          ),
        );
      }
      if (package == 'daemon' &&
          path.endsWith('/lib/daemon.dart') &&
          RegExp(
            'SystemClock|UuidIdGenerator|IoWorkspacePathGateway|'
            'ProcessGitWorkspaceGateway|FileProjectSettingsStore|'
            'ShellWorktreeHookRunner',
          ).hasMatch(line)) {
        violations.add(
          ArchitectureViolation(
            path: path,
            line: index + 1,
            rule: 'daemon_concrete_public_export',
            message: 'The daemon public API may expose typed host ports only.',
          ),
        );
      }
      if (package == 'daemon' &&
          (path.contains('/domain/') || path.contains('/application/')) &&
          importedPackage == 'protocol') {
        violations.add(
          ArchitectureViolation(
            path: path,
            line: index + 1,
            rule: 'application_protocol_dependency',
            message:
                'Daemon domain and application code must map protocol DTOs '
                'at a transport boundary.',
          ),
        );
      }
      if (!_mayNameVendors(package, path) && _vendorIdentifier.hasMatch(line)) {
        violations.add(
          ArchitectureViolation(
            path: path,
            line: index + 1,
            rule: 'vendor_literal',
            message:
                'Vendor names belong in provider infrastructure or the daemon '
                'composition root, not in shared code.',
          ),
        );
      }
      if (!_mayNameTools(package, path) && _quotedToolName.hasMatch(line)) {
        violations.add(
          ArchitectureViolation(
            path: path,
            line: index + 1,
            rule: 'tool_name_literal',
            message:
                'Tool names in the app belong to their chat/tools/ '
                'presenter, not to shared code.',
          ),
        );
      }
      if (!applicationLayer) continue;
      for (final forbidden in const <String>[
        "import 'dart:io'",
        'package:dio/',
        'package:drift/',
        'package:file_selector/',
        'package:flutter/material.dart',
        'package:flutter/services.dart',
        'package:flutter/widgets.dart',
        'package:flutter_secure_storage/',
        'package:go_router/',
        'package:launch_at_startup/',
        'package:path_provider/',
        'package:share_plus/',
        'package:shared_preferences/',
        'package:tinyrack_ui/',
        'package:tray_manager/',
        'package:url_launcher/',
        'package:uuid/',
        'package:window_manager/',
      ]) {
        if (line.contains(forbidden)) {
          violations.add(
            ArchitectureViolation(
              path: path,
              line: index + 1,
              rule: 'application_infrastructure_import',
              message: 'Application code must not import $forbidden.',
            ),
          );
        }
      }
      // `Ref` itself stays allowed: application code legitimately holds a
      // provider's own ref. What is banned is borrowing a *widget's* lifetime,
      // which is how work outlives the thing that asked for it.
      for (final borrowed in const <String>['WidgetRef', 'BuildContext']) {
        if (line.contains(borrowed)) {
          violations.add(
            ArchitectureViolation(
              path: path,
              line: index + 1,
              rule: 'application_widget_ref',
              message:
                  'Application code must not take a $borrowed. Take a Ref, or '
                  'expose the work as a provider.',
            ),
          );
        }
      }
      for (final forbiddenCall in const <String>[
        'DateTime.now(',
        'Uuid(',
        'Dio(',
        'TinestDatabase(',
        'TinestClient.connect(',
        'Process.',
      ]) {
        if (line.contains(forbiddenCall)) {
          violations.add(
            ArchitectureViolation(
              path: path,
              line: index + 1,
              rule: 'application_concrete_dependency',
              message: 'Inject $forbiddenCall behind a port.',
            ),
          );
        }
      }
    }
    return violations;
  }

  /// Reports provider invalidation reachable from a widget lifecycle method.
  ///
  /// A separate, AST-based pass because the rule turns on whether a call is
  /// synchronous, not on which tokens a line contains. Matching lines here
  /// would flag `onPressed: () => ref.invalidate(p)` and a tear-off handed to
  /// `ref.listen`, both of which are correct and common in this tree — and a
  /// rule that flags correct code teaches people to write exemptions.
  ///
  /// It sees one file at a time and has no element model, so a lifecycle
  /// method calling a top-level function in *another* file that invalidates is
  /// invisible to it. `BuildPhaseProviderGuard` covers that, which is why both
  /// mechanisms exist.
  Iterable<ArchitectureViolation> _verifyLifecyclePhase({
    required String package,
    required String path,
    required String source,
  }) sync* {
    if (package != 'app' || !path.contains('/presentation/')) return;
    for (final call in findLifecyclePhaseCalls(
      source: source,
      members: const <String>{'invalidate', 'refresh', 'invalidateSelf'},
    )) {
      yield ArchitectureViolation(
        path: path,
        line: _lineOf(source, call.offset),
        rule: 'lifecycle_provider_invalidation',
        message:
            '${call.lifecycle} runs during the build phase, where '
            'Ref.${call.member} schedules a setState the framework rejects. '
            'Defer it, or let the provider auto-dispose instead.',
      );
    }
    // Same defect shape, different victim: routing from a lifecycle method
    // mutates the Navigator while the tree it belongs to is being built. The
    // tree already does this correctly everywhere — post-frame with a latch, or
    // from a gesture closure — so this rule only has to keep it that way.
    for (final call in findLifecyclePhaseCalls(
      source: source,
      members: const <String>{'go', 'push', 'pushReplacement', 'replace'},
    )) {
      yield ArchitectureViolation(
        path: path,
        line: _lineOf(source, call.offset),
        rule: 'lifecycle_navigation',
        message:
            '${call.lifecycle} runs during the build phase, so navigating with '
            '${call.member} rebuilds the tree that is already building. Defer '
            'it behind a post-frame callback with a latch, as WorkspacePage '
            'does for its restore.',
      );
    }
  }

  static int _lineOf(String source, int offset) =>
      '\n'.allMatches(source.substring(0, offset)).length + 1;

  /// Whether the annotation at [index] asks for a `keepAlive` provider.
  ///
  /// The flag may sit on the same line or be wrapped onto the next few, so a
  /// small window is read rather than the single line.
  static bool _declaresKeepAliveProvider(List<String> lines, int index) {
    if (!lines[index].contains('@Riverpod(')) return false;
    final window = lines.skip(index).take(4).join(' ');
    return window.contains('keepAlive: true');
  }

  /// Name of the declaration an annotation at [index] applies to.
  ///
  /// This repo puts the doc comment *between* the annotation and the thing it
  /// annotates, and a provider may be a class or a plain function, so both the
  /// interleaved comment and either shape are handled.
  static String? _providerDeclarationName(List<String> lines, int index) {
    for (var next = index + 1; next < lines.length; next += 1) {
      final line = lines[next].trim();
      if (line.isEmpty || line.startsWith('///') || line.startsWith('@')) {
        continue;
      }
      final declared = RegExp(r'class\s+([A-Za-z_]\w*)').firstMatch(line);
      if (declared != null) return declared.group(1);
      return RegExp(r'([A-Za-z_]\w*)\s*\(').firstMatch(line)?.group(1);
    }
    return null;
  }

  bool _isApplicationLayer(String package, String path) {
    if (package == 'app') {
      return path.contains('/src/features/') && path.contains('/application/');
    }
    if (package == 'daemon') {
      return path.contains('/application/') ||
          path.endsWith('/agent_service.dart') ||
          path.endsWith('/session_interactions.dart') ||
          path.endsWith('/session_settings.dart') ||
          path.endsWith('/mcp_service.dart') ||
          path.endsWith('/mcp_server_service.dart') ||
          path.endsWith('/provider_service.dart') ||
          path.endsWith('/workspace_service.dart');
    }
    return package == 'agent' && path.endsWith('/runtime.dart');
  }

  Iterable<ArchitectureViolation> _verifyTinestAppLayerImport({
    required String path,
    required int line,
    required String source,
  }) sync* {
    final import = RegExp("import 'package:app/src/([^']+)';")
        .firstMatch(source);
    final importedPath = import?.group(1);

    if (path.contains('/src/shared/') &&
        importedPath?.startsWith('features/') == true) {
      yield ArchitectureViolation(
        path: path,
        line: line,
        rule: 'shared_feature_dependency',
        message: 'Shared code must not depend on a product feature.',
      );
    }

    final sourceFeature = RegExp('/src/features/([^/]+)/')
        .firstMatch(path)
        ?.group(1);
    final importedFeature = importedPath == null
        ? null
        : RegExp('^features/([^/]+)/').firstMatch(importedPath)?.group(1);
    final importsFeatureView =
        importedPath != null &&
        RegExp('^features/[^/]+/presentation/(pages|widgets)/')
            .hasMatch(importedPath);
    if (sourceFeature != null &&
        importedFeature != null &&
        sourceFeature != importedFeature &&
        importsFeatureView) {
      yield ArchitectureViolation(
        path: path,
        line: line,
        rule: 'feature_presentation_dependency',
        message:
            "A feature must not import another feature's page or widget; "
            'compose it in app/ or promote a feature-neutral component to '
            'shared/.',
      );
    }

    if (!path.contains('/src/features/') || !path.contains('/domain/')) {
      return;
    }
    final frameworkPackage = RegExp(
      "import 'package:(flutter|flutter_riverpod|riverpod_annotation|go_router|"
      'tinyrack_ui|file_selector|flutter_secure_storage|launch_at_startup|'
      'share_plus|shared_preferences|tray_manager|url_launcher|uuid|'
      'window_manager)/',
    ).hasMatch(source);
    if (frameworkPackage) {
      yield ArchitectureViolation(
        path: path,
        line: line,
        rule: 'domain_framework_dependency',
        message: 'Feature domain code must stay independent of frameworks.',
      );
    }
  }
}
