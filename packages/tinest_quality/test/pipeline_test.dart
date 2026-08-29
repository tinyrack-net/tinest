import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support/repo_root.dart';

/// Full platform matrices consumed outside pull-request fast validation.
final Map<String, dynamic> _matrices = jsonDecode(
  File('.github/ci-matrices.json').readAsStringSync(),
) as Map<String, dynamic>;

void main() {
  useRepositoryRoot();
  final workflow = File('.github/workflows/pipeline.yml').readAsStringSync();
  final nightlyWorkflow = File(
    '.github/workflows/nightly.yml',
  ).readAsStringSync();
  final relayWorkflowFile = File('.github/workflows/relay-release.yml');
  final relayWorkflow = relayWorkflowFile.existsSync()
      ? relayWorkflowFile.readAsStringSync()
      : '';
  final relayDockerfile = File(
    'packages/relay/Dockerfile',
  ).readAsStringSync();
  final relayPubspec = loadYaml(
    File('packages/relay/pubspec.yaml').readAsStringSync(),
  ) as YamlMap;
  final relayContainerLock = loadYaml(
    File('packages/relay/docker/pubspec.lock').readAsStringSync(),
  ) as YamlMap;
  final shipworld = File('shipworld.yaml').readAsStringSync();
  final ibusTerminalRunner = File(
    'packages/desktop_app/tool/run_linux_ibus_terminal_e2e.sh',
  ).readAsStringSync();
  final androidBuild = File(
    'packages/app/android/build.gradle.kts',
  ).readAsStringSync();
  final androidSettings = File(
    'packages/app/android/settings.gradle.kts',
  ).readAsStringSync();
  final androidGradleWrapper = File(
    'packages/app/android/gradle/wrapper/gradle-wrapper.properties',
  ).readAsStringSync();
  final androidAppBuild = File(
    'packages/app/android/app/build.gradle.kts',
  ).readAsStringSync();
  final appPubspec = File('packages/app/pubspec.yaml').readAsStringSync();
  final iosDebugConfig = File(
    'packages/app/ios/Flutter/Debug.xcconfig',
  ).readAsStringSync();
  final iosReleaseConfig = File(
    'packages/app/ios/Flutter/Release.xcconfig',
  ).readAsStringSync();
  final iosPodfileFile = File('packages/app/ios/Podfile');
  final iosPodfile = iosPodfileFile.existsSync()
      ? iosPodfileFile.readAsStringSync()
      : '';
  final iosProject = File(
    'packages/app/ios/Runner.xcodeproj/project.pbxproj',
  ).readAsStringSync();
  final cargoKitCompat = File(
    'packages/app/android/cargokit-gradle9-compat.gradle',
  );
  final windowsCmake = File(
    'packages/desktop_app/windows/CMakeLists.txt',
  ).readAsStringSync();
  final windowsInstaller = File(
    'packages/desktop_app/windows/installer/tinest.iss',
  ).readAsStringSync();
  final cliSmoke = File(
    '.github/actions/smoke-cli-bundle/action.yml',
  ).readAsStringSync();
  final linuxDesktopDependencies = File(
    '.github/actions/install-linux-desktop-deps/action.yml',
  ).readAsStringSync();

  test('quality and nightly workflows have disjoint triggers and jobs', () {
    expect(workflow, isNot(contains('schedule:')));
    expect(workflow, isNot(contains('branches:')));
    expect(workflow, contains('tags:'));
    expect(nightlyWorkflow, contains('schedule:'));
    for (final job in <String>[
      'changes',
      'static-linux',
      'generated-linux',
      'fast-dart-tests-linux',
      'fast-flutter-tests-linux',
      'dart-tests',
      'flutter-tests',
      'coverage-dart-linux',
      'coverage-flutter-linux',
      'relay-coverage-linux',
      'relay-smoke-linux',
      'debug-e2e-linux',
      'linux-ibus-terminal-e2e',
      'mobile-debug-build',
      'desktop-debug-build',
      'web-build',
      'cli-verify',
    ]) {
      expect(workflow, contains('  $job:'));
      expect(nightlyWorkflow, isNot(contains('  $job:')));
    }
    for (final job in <String>[
      'nightly-dart-macos',
      'nightly-desktop-e2e',
      'nightly-android-smoke',
      'nightly-ios-smoke',
    ]) {
      expect(workflow, isNot(contains('  $job:')));
      expect(nightlyWorkflow, contains('  $job:'));
    }
  });

  test('static checks enforce the Tinyrack design system', () {
    final job = _job(workflow, 'static-linux');
    expect(job, contains('tinest_quality _static-checks'));
    expect(job, isNot(contains('exec -c 4')));
  });

  test('quality jobs retain machine-readable timing reports', () {
    for (final name in <String>[
      'static-linux',
      'generated-linux',
      'fast-dart-tests-linux',
      'fast-flutter-tests-linux',
      'dart-tests',
      'flutter-tests',
      'coverage-dart-linux',
      'coverage-flutter-linux',
      'relay-coverage-linux',
    ]) {
      final job = _job(workflow, name);
      expect(job, contains('--report=build/quality/'), reason: name);
      expect(job, contains('actions/upload-artifact@v4'), reason: name);
    }
  });

  test('the cross-platform suites stay in separate parallel jobs', () {
    // Merging them to pay `setup-flutter` once was tried and measured: on
    // Windows the suites take 7.6 and 4.4 minutes, so one job serialises them
    // into 15.6 and the merge-queue run went 7.7 -> 18.2 minutes. Repeating a
    // setup that now costs under 2 minutes is the cheaper of the two, and the
    // queue gates every merge, so its wall clock is what matters here.
    final dart = _job(workflow, 'dart-tests');
    final flutter = _job(workflow, 'flutter-tests');
    expect(dart, contains('dart run tinest_quality _test-dart'));
    expect(dart, isNot(contains('_test-flutter')));
    expect(flutter, contains('dart run tinest_quality _test-flutter'));
    expect(flutter, isNot(contains('_test-dart')));
    expect(flutter, contains('os: macos'));
    for (final job in <String>[dart, flutter]) {
      expect(job, contains('os: windows'));
    }
    // A single job running both is what the measurement rejected.
    expect(workflow, isNot(contains('\n  cross-platform-tests:\n')));
  });

  test('the dominant Dart package is tested in its own job', () {
    // `daemon` holds 88 of the workspace's ~122 suites and decided the whole
    // pipeline's wall clock: on a four-core hosted Windows runner the eight
    // packages each take one slot, so daemon ran fully serial and spent 454 of
    // `Dart tests`'s 454 seconds. Splitting it out is what lets the slot
    // allocator hand it the entire machine, which no budget change can do while
    // seven other packages each need a slot of their own.
    for (final name in <String>[
      'fast-dart-tests-linux',
      'dart-tests',
      'coverage-dart-linux',
    ]) {
      final job = _job(workflow, name);
      expect(job, contains('--scope=daemon'), reason: name);
      expect(job, contains('matrix.scopes'), reason: name);
    }
    final dart = _job(workflow, 'dart-tests');
    expect(dart, contains('shard: daemon'));
    expect(dart, contains('shard: rest'));
    // The gate reads results by job id, so both shards stay required.
    expect(_job(workflow, 'quality-gate'), contains('- dart-tests'));
    expect(_job(workflow, 'quality-gate'), contains('- coverage-dart-linux'));
  });

  test('every Dart package with tests belongs to a shard', () {
    // A package missing from this list would be dropped by both shards and stop
    // being tested while the gate still went green, so the list has to match
    // the workspace rather than be maintained alongside it.
    final declared = jsonDecode(
      File('.github/dart-packages.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final packages = (declared['packages']! as List<dynamic>).cast<String>();
    final onItsOwn = declared['shardAlone']! as String;
    expect(packages, contains(onItsOwn));

    final actual = Directory('packages')
        .listSync()
        .whereType<Directory>()
        .map((entry) {
          final segments = entry.uri.pathSegments;
          return segments[segments.length - 2];
        })
        .where((name) => Directory('packages/$name/test').existsSync())
        .where(
          (name) =>
              !File('packages/$name/pubspec.yaml')
                  .readAsStringSync()
                  .contains('flutter:\n    sdk: flutter'),
        )
        .toSet();
    expect(
      actual.difference(packages.toSet()),
      isEmpty,
      reason: 'a Dart package with tests is in no shard',
    );
  });

  test('the macOS Dart suites run nightly rather than per merge', () {
    // Windows keeps both shards pre-merge, so a Dart change is gated on a
    // non-Linux host while nightly owns macOS-only Dart behaviour.
    final dart = _job(workflow, 'dart-tests');
    expect(dart, isNot(contains('os: macos')));
    expect(dart, isNot(contains('--jobs=1')));

    // Dart 3.13 rewrites native-library install names before a suite starts,
    // and concurrent macOS suites race while replacing the shared dylib, so
    // the serialization moves with the suites rather than being dropped.
    //
    // The nightly run is unsharded: sharding exists to cut queue wall clock,
    // and `changes` does not run on a schedule, so a shard would have to
    // duplicate that job's scope arithmetic to buy time nothing is waiting on.
    final nightly = _job(nightlyWorkflow, 'nightly-dart-macos');
    expect(nightly, contains('dart run tinest_quality _test-dart --jobs=1'));
    expect(nightly, isNot(contains('--scope=')));
    expect(nightly, contains('runs-on: macos-26'));
    expect(nightly, contains('--report=build/quality/'));
    expect(nightly, contains('actions/upload-artifact@v4'));
  });

  test('Windows fetches the SDK archive instead of the Actions cache', () {
    // The cached blob and the published archive are the same size on every
    // host (Windows 1.81 GB against 1.8, macOS 2.08 against 2.1, Linux 1.69
    // against 1.5), so the cache carries no precache bloat and the payload is
    // identical either way. Only throughput differs, and Windows restores at
    // ~6 MB/s against 48 MB/s for the same blob on macOS.
    final setup = File(
      '.github/actions/setup-flutter/action.yml',
    ).readAsStringSync();
    expect(
      setup,
      contains(
        r"cache: ${{ runner.os != 'Windows' }}",
      ),
    );
    expect(setup, isNot(contains('cache: true')));
    // One definition, so no job can quietly opt back into the slow path.
    expect(
      RegExp('setup-flutter').allMatches(workflow).length,
      greaterThan(1),
    );
    expect(workflow, isNot(contains('subosito/flutter-action')));
  });

  test('Linux dependency downloads cannot consume the whole desktop job', () {
    expect(loadYaml(linuxDesktopDependencies), isA<YamlMap>());
    expect(
      linuxDesktopDependencies,
      contains(r'Dir::State::lists="$fresh_lists"'),
    );
    expect(
      linuxDesktopDependencies,
      contains(
        'timeout --kill-after=10s 120s apt-get update --error-on=any',
      ),
    );
    expect(linuxDesktopDependencies, contains('Acquire::Retries=1'));
    expect(linuxDesktopDependencies, contains('Acquire::http::Timeout=15'));
    expect(linuxDesktopDependencies, contains('Acquire::https::Timeout=15'));
    expect(
      linuxDesktopDependencies,
      contains('Dir::State::lists=/var/lib/apt/lists'),
    );
    expect(
      linuxDesktopDependencies,
      contains('apt-get install --download-only'),
    );
    expect(
      linuxDesktopDependencies,
      contains('apt-get install --no-download'),
    );

    final download = linuxDesktopDependencies.indexOf(
      'apt-get install --download-only',
    );
    final mutation = linuxDesktopDependencies.indexOf(
      'apt-get install --no-download',
    );
    expect(download, isNonNegative);
    expect(mutation, isNonNegative);
    expect(download, lessThan(mutation));
    final mutationLine = linuxDesktopDependencies
        .split('\n')
        .singleWhere(
          (line) => line.contains('apt-get install --no-download'),
        );
    expect(
      mutationLine,
      isNot(contains('timeout')),
      reason: 'a timeout must never interrupt dpkg while it mutates the host',
    );
  });

  test('pull requests run a small Linux gate and defer full validation', () {
    expect(workflow, isNot(contains('max-parallel:')));
    for (final job in <String>[
      'fast-dart-tests-linux',
      'fast-flutter-tests-linux',
    ]) {
      final definition = _job(workflow, job);
      expect(definition, contains("github.event_name == 'pull_request'"));
      expect(definition, contains('runs-on: ubuntu-24.04'));
      expect(definition, isNot(contains('max-parallel:')));
    }
    final flutter = _job(workflow, 'fast-flutter-tests-linux');
    expect(flutter, contains('- package: app'));
    expect(flutter, contains('- package: desktop_app'));
    expect(flutter, contains(r'--scope=${{ matrix.package }}'));

    // These expensive or platform-specific jobs validate the merge candidate
    // rather than every intermediate pull-request head.
    for (final job in <String>[
      'dart-tests',
      'flutter-tests',
      'coverage-dart-linux',
      'coverage-flutter-linux',
      'relay-coverage-linux',
      'relay-smoke-linux',
      'debug-e2e-linux',
      'linux-ibus-terminal-e2e',
      'mobile-debug-build',
      'desktop-debug-build',
      'web-build',
      'cli-verify',
    ]) {
      expect(
        _job(workflow, job),
        contains("github.event_name != 'pull_request'"),
        reason: job,
      );
    }

    // Cheap structural checks still protect every pull-request head.
    for (final job in <String>[
      'static-linux',
      'generated-linux',
    ]) {
      expect(
        _job(workflow, job),
        isNot(contains("github.event_name != 'pull_request'")),
      );
    }
  });

  test('merge queue matrices preserve every release target', () {
    // Pull requests do not consume these matrices; merge candidates verify
    // every target using one job body per capability.
    expect(_job(workflow, 'cli-verify'), contains('fromJSON'));
    expect(_job(workflow, 'mobile-debug-build'), contains('fromJSON'));
    expect(_job(workflow, 'changes'), isNot(contains('CROSS_PLATFORM')));

    // An empty matrix is a workflow error, not a skipped job.
    for (final key in <String>['cli', 'mobile']) {
      expect(
        _matrices[key]! as List<dynamic>,
        isNotEmpty,
        reason: '$key matrix is empty',
      );
    }
    expect(
      _matrices['cli']! as List<dynamic>,
      hasLength(4),
      reason: 'the merge queue must verify every CLI release target',
    );
    expect(_matrices['mobile']! as List<dynamic>, hasLength(2));
  });

  test('a documentation-only pull request skips the quality matrix', () {
    final scope = _job(workflow, 'changes');
    expect(scope, contains('docs_only'));
    expect(scope, contains('pulls/'));
    // An empty or unreadable diff must not read as documentation-only, or a
    // code change could merge without ever running a gate.
    expect(scope, contains('docs_only=false'));
    expect(scope, contains('verification_scope=full'));
    for (final job in <String>[
      'static-linux',
      'fast-dart-tests-linux',
      'fast-flutter-tests-linux',
      'coverage-dart-linux',
      'coverage-flutter-linux',
      'debug-e2e-linux',
      'linux-ibus-terminal-e2e',
      'web-build',
      'cli-verify',
      'mobile-debug-build',
      'dart-tests',
      'flutter-tests',
      'desktop-debug-build',
    ]) {
      expect(
        _job(workflow, job),
        contains("needs.changes.outputs.docs_only != 'true'"),
      );
    }
  });

  test('pull request jobs follow the conservative change scope', () {
    final scope = _job(workflow, 'changes');
    expect(scope, contains('scope='));
    expect(
      scope,
      contains('dart packages/tinest_quality/bin/ci_scope.dart'),
    );
    expect(scope, isNot(contains('dart run tinest_quality ci-scope')));

    expect(
      _job(workflow, 'relay-coverage-linux'),
      contains("needs.changes.outputs.scope == 'relay-only'"),
    );
    expect(
      _job(workflow, 'relay-smoke-linux'),
      contains("needs.changes.outputs.scope == 'relay-only'"),
    );
    expect(_job(workflow, 'relay-smoke-linux'), contains('seq 1 80'));
    for (final job in <String>[
      'generated-linux',
      'coverage-flutter-linux',
      'debug-e2e-linux',
      'linux-ibus-terminal-e2e',
      'mobile-debug-build',
      'web-build',
    ]) {
      expect(
        _job(workflow, job),
        contains("needs.changes.outputs.scope != 'relay-only'"),
        reason: job,
      );
    }
    for (final job in <String>['coverage-dart-linux', 'cli-verify']) {
      expect(
        _job(workflow, job),
        contains("needs.changes.outputs.scope == 'full'"),
        reason: job,
      );
    }
  });

  test('Dart coverage enforces every non-Flutter package', () {
    // The scopes now come from .github/dart-packages.json so the two shards and
    // coverage-check cannot drift apart; `every Dart package with tests belongs
    // to a shard` is what checks the list against the workspace.
    final coverage = _job(workflow, 'coverage-dart-linux');
    final packages =
        ((jsonDecode(
                  File('.github/dart-packages.json').readAsStringSync(),
                ) as Map<String, dynamic>)['packages']!
                as List<dynamic>)
            .cast<String>();
    expect(packages, hasLength(8));
    expect(coverage, contains('--scope=daemon'));
    expect(coverage, contains(r'${{ matrix.scopes }}'));
    // coverage-check runs with the same scopes the shard tested, never a
    // wider list that would fail on packages this shard never ran.
    expect(
      coverage,
      contains(
        'coverage-check --line=90 --branch=80\n          '
        r'${{ matrix.scopes }}',
      ),
    );
    expect(
      _job(workflow, 'relay-coverage-linux'),
      contains('tinest_quality _coverage-dart --scope=relay'),
    );
  });

  test(
    'release builds are tag or manual only and publishing stays tag only',
    () {
      final build = _job(workflow, 'build-and-package');
      final androidRelease = _job(workflow, 'build-android-release');
      expect(build, contains("startsWith(github.ref, 'refs/tags/v')"));
      expect(build, contains("github.event_name == 'workflow_dispatch'"));
      expect(build, contains('inputs.package_release'));
      expect(build, isNot(contains("github.ref == 'refs/heads/main'")));
      expect(
        androidRelease,
        contains("startsWith(github.ref, 'refs/tags/v')"),
      );
      expect(
        androidRelease,
        contains("github.event_name == 'workflow_dispatch'"),
      );
      expect(androidRelease, contains('inputs.package_release'));
      expect(
        androidRelease,
        isNot(contains("github.ref == 'refs/heads/main'")),
      );

      for (final job in <String>[
        'publish-release',
        'publish-homebrew',
        'publish-winget',
      ]) {
        expect(
          _job(workflow, job),
          contains("startsWith(github.ref, 'refs/tags/v')"),
        );
      }
    },
  );

  test('Android releases publish signed APK and Play Store bundle', () {
    final release = _job(workflow, 'build-android-release');
    for (final secret in <String>[
      'ANDROID_KEYSTORE_BASE64',
      'ANDROID_KEYSTORE_PASSWORD',
      'ANDROID_KEY_ALIAS',
      'ANDROID_KEY_PASSWORD',
    ]) {
      final reference = r'${{ secrets.SECRET }}'.replaceFirst('SECRET', secret);
      expect(release, contains(reference));
    }
    expect(release, contains('gradle/actions/setup-gradle@v6'));
    expect(
      release,
      contains('flutter build apk --release -t lib/main_mobile.dart'),
    );
    expect(
      release,
      contains('flutter build appbundle --release -t lib/main_mobile.dart'),
    );
    expect(release, contains('verify --verbose --print-certs'));
    expect(release, contains('jarsigner -verify -verbose -certs'));
    expect(release, contains('Tinest-android-universal.apk'));
    expect(release, contains('Tinest-android-play.aab'));
    expect(release, contains('dist/Tinest-android-play.aab'));
    expect(release, contains('if: always()'));
    expect(release, isNot(contains('pull_request')));

    final publish = _job(workflow, 'publish-release');
    expect(publish, contains('- build-android-release'));
    expect(publish, contains('pattern: tinest-*'));
  });

  test('mobile artifact checks inspect the actual iOS app bundle', () {
    final mobileBuild = _job(workflow, 'mobile-debug-build');

    expect(mobileBuild, contains("-type d -name '*.app'"));
    expect(mobileBuild, contains('Expected one iOS app bundle'));
    expect(mobileBuild, contains(r'ios_app_count="$(find'));
    expect(mobileBuild, contains(r'find "$ios_app"'));
    expect(mobileBuild, isNot(contains('mapfile')));
    expect(mobileBuild, isNot(contains('Runner.app')));
  });

  test('Android release builds cannot fall back to the debug signing key', () {
    expect(androidAppBuild, contains('key.properties'));
    expect(androidAppBuild, contains('signingConfigs'));
    expect(androidAppBuild, contains('signingConfigs.getByName("release")'));
    expect(
      androidAppBuild,
      isNot(contains('signingConfigs.getByName("debug")')),
    );
  });

  test('app tags deploy web as a required release artifact', () {
    final deployWeb = _job(workflow, 'deploy-web');
    final publishRelease = _job(workflow, 'publish-release');
    final publishHomebrew = _job(workflow, 'publish-homebrew');
    final publishWinget = _job(workflow, 'publish-winget');

    expect(deployWeb, contains("startsWith(github.ref, 'refs/tags/v')"));
    expect(deployWeb, contains('if: always() &&'));
    expect(deployWeb, contains("needs.quality-gate.result == 'success'"));
    expect(deployWeb, contains("needs.web-build.result == 'success'"));
    expect(deployWeb, contains("needs.build-and-package.result == 'success'"));
    expect(deployWeb, contains("needs.build-cli.result == 'success'"));
    expect(deployWeb, isNot(contains("github.ref == 'refs/heads/main'")));
    for (final dependency in <String>[
      'quality-gate',
      'web-build',
      'build-and-package',
      'build-cli',
    ]) {
      expect(deployWeb, contains('- $dependency'));
    }
    expect(publishRelease, contains('- deploy-web'));
    expect(publishRelease, contains('if: always() &&'));
    expect(publishRelease, contains("needs.deploy-web.result == 'success'"));
    expect(publishHomebrew, contains('if: always() &&'));
    expect(
      publishHomebrew,
      contains("needs.publish-release.result == 'success'"),
    );
    expect(publishWinget, contains('if: always() &&'));
    expect(
      publishWinget,
      contains("needs.publish-release.result == 'success'"),
    );
    expect(publishWinget, contains('actions/checkout@v5'));
    expect(
      publishWinget,
      contains('.github/scripts/publish-winget.ps1'),
    );
    final publishWingetScript = File(
      '.github/scripts/publish-winget.ps1',
    ).readAsStringSync();
    expect(publishWingetScript, contains('Tinyrack.Tinest'));
    expect(publishWingetScript, contains('Tinyrack.TinestCLI'));
    expect(publishWingetScript, contains('wingetcreate.exe update'));
    expect(publishWingetScript, contains('wingetcreate.exe submit'));
    expect(publishWingetScript, contains('api.github.com/repos/microsoft/winget-pkgs/contents'));
    expect(
      publishWingetScript,
      contains('.github/winget/initial-manifests'),
    );
  });

  test('a failed WinGet publication can recover from a release tag', () {
    final recovery = File(
      '.github/workflows/recover-release-winget.yml',
    ).readAsStringSync();

    expect(recovery, contains('release_tag:'));
    expect(recovery, contains('actions/checkout@v5'));
    expect(recovery, contains("ref: 'main'"));
    expect(recovery, contains('.github/scripts/publish-winget.ps1'));
    expect(recovery, contains('secrets.WINGET_TOKEN'));
  });

  test('a release web deployment can recover from a skipped publish job', () {
    final recovery = File(
      '.github/workflows/recover-release-web.yml',
    ).readAsStringSync();

    expect(recovery, contains('source_run_id:'));
    expect(recovery, contains('release_tag:'));
    expect(recovery, contains('actions: read'));
    expect(recovery, contains(r'gh run download "$SOURCE_RUN_ID"'));
    expect(recovery, contains('--name web-assets'));
    expect(recovery, contains('tag_sha'));
    expect(recovery, contains('run_sha'));
    expect(recovery, contains('cloudflare/wrangler-action@v3'));
  });

  test('relay tags publish one attested multi-platform GHCR image', () {
    expect(relayWorkflow, contains('relay-v*.*.*'));
    expect(relayWorkflow, contains('packages: write'));
    expect(relayWorkflow, contains('attestations: write'));
    expect(relayWorkflow, contains('id-token: write'));
    expect(relayWorkflow, contains('release verify relay'));
    expect(relayWorkflow, contains('linux/amd64,linux/arm64'));
    expect(relayWorkflow, contains('ghcr.io/tinyrack-net/tinest-relay'));
    expect(
      relayWorkflow,
      contains(r'v${{ steps.version.outputs.version }}'),
    );
    expect(relayWorkflow, contains('latest'));
    expect(relayWorkflow, contains('actions/attest'));
    expect(
      relayWorkflow,
      contains('packages/relay/tool/smoke_relay.dart'),
    );
    expect(relayWorkflow, contains('seq 1 80'));
    expect(relayWorkflow, isNot(contains('gh release create')));
  });

  test('every release version file shipworld writes exists', () {
    // `release prepare` reads each synchronized path before rewriting it, so a
    // path left behind by a package move fails the release itself rather than
    // any earlier gate. Nothing else in the workspace references these files by
    // the name shipworld knows them under.
    final declared = RegExp(
      r'^\s*path:\s*(\S+version\.g\.dart)\s*$',
      multiLine: true,
    ).allMatches(shipworld).map((match) => match.group(1)!).toList();

    expect(declared, hasLength(3));
    for (final path in declared) {
      expect(
        File(path).existsSync(),
        isTrue,
        reason: 'shipworld.yaml writes $path, which does not exist',
      );
    }
  });

  test('release metadata points at the repository that hosts artifacts', () {
    expect(
      shipworld,
      contains('homepage: https://github.com/tinyrack-net/coder'),
    );
    expect(shipworld, contains('repository: tinyrack-net/coder'));
    expect(shipworld, isNot(contains('tinyrack-net/tinest')));
  });

  test('relay release has an independent version and reproducible image', () {
    expect(shipworld, contains('  relay:'));
    expect(shipworld, contains('source: packages/relay/pubspec.yaml'));
    expect(shipworld, contains('tag: "relay-v{version}"'));

    expect(workflow, contains('FLUTTER_VERSION: 3.47.2'));
    expect(workflow, contains('sdk: 3.13.2'));
    expect(relayWorkflow, contains('FLUTTER_VERSION: 3.47.2'));
    expect(
      relayDockerfile,
      contains(
        'dart:3.13.2@sha256:'
        '18cbfc2ede913addb75d3a4cd1dbc9288ba138e3fc76414dd864b2c847779f79',
      ),
    );
    expect(relayDockerfile, contains('cc-debian12:nonroot@sha256:'));
    expect(relayDockerfile, contains('docker/pubspec.lock pubspec.lock'));
    expect(relayDockerfile, contains('dart pub get --enforce-lockfile'));
    expect(relayDockerfile, isNot(contains('dart:stable')));
    expect(File('packages/relay/docker/pubspec.lock').existsSync(), isTrue);
    final directDependencies = <String>{
      ...(relayPubspec['dependencies']! as YamlMap).keys.cast<String>(),
      ...(relayPubspec['dev_dependencies']! as YamlMap).keys.cast<String>(),
    }..remove('relay_protocol');
    final lockedPackages = (relayContainerLock['packages']! as YamlMap).keys
        .cast<String>();
    expect(lockedPackages, containsAll(directDependencies));
    expect(File('packages/relay/deploy/kubernetes.yaml').existsSync(), isFalse);
  });

  test('both CLI jobs build and smoke the bundle through one definition', () {
    final verify = _job(workflow, 'cli-verify');
    final release = _job(workflow, 'build-cli');

    // Sharing the steps is what keeps the pull-request job honest: a smoke
    // test duplicated into two copies is one that stops matching the CLI.
    for (final job in <String>[verify, release]) {
      expect(job, contains('./.github/actions/build-cli-bundle'));
      expect(job, contains('./.github/actions/smoke-cli-bundle'));
    }
    // `cli-verify` takes its full merge-candidate matrix from `changes`; the
    // target list lives in the matrix file.
    final verified = (_matrices['cli']! as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((entry) => entry['target']! as String)
        .toList();
    for (final target in <String>[
      'linux-x64',
      'macos-x64',
      'macos-arm64',
      'windows-x64',
    ]) {
      expect(verified, contains(target));
      expect(release, contains('target: $target'));
    }
    // A queue run has to verify exactly what a tag releases, or the job stops
    // being the thing that catches a release-path breakage.
    expect(verified, hasLength(4));
    // Linux arm64 has no Flutter SDK, so it is not a release target and must
    // not reappear here; `shipworld.yaml` omits it too.
    expect(verified, isNot(contains('linux-arm64')));
    expect(release, isNot(contains('linux-arm64')));
    // A fork pull request has no signing secrets and no release to upload to.
    expect(verify, isNot(contains('APPLE_CERTIFICATE')));
    expect(verify, isNot(contains('upload-artifact')));
  });

  test('CLI smoke waits for daemon readiness before connecting', () {
    expect(cliSmoke, contains('daemon_log='));
    expect(cliSmoke, contains('trap cleanup EXIT'));
    expect(cliSmoke, contains(r'kill -0 "$daemon"'));
    expect(cliSmoke, contains(r'wait "$daemon"'));
    expect(cliSmoke, contains(r'cat "$daemon_log"'));
    expect(cliSmoke, contains('Tinest daemon listening on'));

    final ready = cliSmoke.indexOf('Tinest daemon listening on');
    final connect = cliSmoke.indexOf(r'"$cli" provider list');
    expect(ready, isNonNegative);
    expect(connect, greaterThan(ready));
  });

  test('CLI smoke invokes the staged Lua runtime protocol v2 bundle', () {
    expect(cliSmoke, contains('"version":2'));
    expect(cliSmoke, contains('"type":"invoke"'));
    expect(cliSmoke, contains('"entrypoint":"main"'));
    expect(cliSmoke, contains('"modules":{"main":'));
    expect(cliSmoke, contains('"handler":"run"'));
    expect(cliSmoke, isNot(contains('"version":1')));
    expect(cliSmoke, isNot(contains('"type":"init"')));
  });

  test('the aggregate gate requires every quality job', () {
    final gate = _job(workflow, 'quality-gate');
    for (final dependency in <String>[
      'changes',
      'static-linux',
      'generated-linux',
      'fast-dart-tests-linux',
      'fast-flutter-tests-linux',
      'dart-tests',
      'flutter-tests',
      'coverage-dart-linux',
      'coverage-flutter-linux',
      'relay-coverage-linux',
      'relay-smoke-linux',
      'debug-e2e-linux',
      'linux-ibus-terminal-e2e',
      'mobile-debug-build',
      'desktop-debug-build',
      'web-build',
      // The CLI is only built here on a pull request; `build-cli` waits for a
      // tag, which is how two release-path breakages reached main.
      'cli-verify',
    ]) {
      expect(gate, contains('- $dependency'));
    }
    // Scoping jobs out by event or by diff makes them report `skipped`, which
    // the gate has to accept. It must not accept a skip that came from
    // `changes` itself failing, because that skips everything at once.
    expect(
      gate,
      contains('all(.[]; .result == "success" or .result == "skipped")'),
    );
    expect(gate, contains('.changes.result == "success"'));
    expect(gate, isNot(contains('.result == "failure"')));
    expect(_job(workflow, 'publish-release'), contains('- quality-gate'));
  });

  test('desktop E2E jobs execute every catalog scenario exactly once', () {
    final linux = _job(workflow, 'debug-e2e-linux');
    final nightly = _job(nightlyWorkflow, 'nightly-desktop-e2e');
    for (final scenario in <String>[
      'daemon-workspace',
      'project-worktree',
      'plugin-harness',
      'relay',
      'conversation-adversity',
      'conversation-history',
      'conversation',
      'provider',
      'settings-desktop',
      'desktop-shell',
    ]) {
      expect(
        RegExp(
          '^\\s+scenario: ${RegExp.escape(scenario)}\\s*\$',
          multiLine: true,
        ).allMatches(linux),
        hasLength(1),
      );
      expect(
        RegExp(
          '^\\s+- ${RegExp.escape(scenario)}\\s*\$',
          multiLine: true,
        ).allMatches(nightly),
        hasLength(1),
      );
    }
    expect(linux, contains('fail-fast: false'));
    expect(linux, contains('run_desktop_e2e.dart'));
    expect(nightly, contains('run_desktop_e2e.dart'));
    expect(linux, contains('actions/upload-artifact@v4'));
    expect(nightly, contains('actions/upload-artifact@v4'));
  });

  test('Linux IBus terminal E2E is a required real desktop job', () {
    final job = _job(workflow, 'linux-ibus-terminal-e2e');
    expect(workflow, contains('pull_request:'));
    expect(workflow, contains('merge_group:'));
    expect(workflow, isNot(contains('branches:')));
    expect(job, contains('runs-on: ubuntu-24.04'));
    expect(job, contains('./.github/actions/setup-flutter'));
    for (final package in <String>[
      'ibus-gtk3',
      'ibus-hangul',
      'xdotool',
      'xclip',
      'dbus-x11',
      'xvfb',
    ]) {
      expect(job, contains(package));
    }
    expect(job, contains('xvfb-run -a dbus-run-session'));
    expect(
      job,
      contains('packages/desktop_app/tool/run_linux_ibus_terminal_e2e.sh'),
    );
    expect(job, contains('terminal_ibus_e2e_test.dart'));
    expect(job, isNot(contains('continue-on-error')));
    expect(job, isNot(contains('retry')));
    expect(
      ibusTerminalRunner,
      contains('flutter pub get --enforce-lockfile'),
    );
    expect(job, isNot(contains('mise')));
    expect(ibusTerminalRunner, isNot(contains('mise')));
  });

  test('mobile nightly jobs run remote and Android terminal E2E', () {
    final android = _job(nightlyWorkflow, 'nightly-android-smoke');
    final ios = _job(nightlyWorkflow, 'nightly-ios-smoke');
    for (final job in <String>[android, ios]) {
      expect(job, contains('remote_bootstrap_smoke_test.dart'));
      expect(job, isNot(contains('provider_e2e_test.dart')));
    }
    expect(android, contains('mobile_terminal_input_smoke_test.dart'));
    expect(ios, isNot(contains('mobile_terminal_input_smoke_test.dart')));
    expect(android, contains('script: >-'));
    expect(android, isNot(contains('script: |')));
    expect(android, contains('cd packages/app &&'));
    expect(
      android,
      contains(
        'remote_bootstrap_smoke_test.dart\n            -d emulator-5554 &&',
      ),
    );
    expect(
      android,
      contains(
        'mobile_terminal_input_smoke_test.dart\n            -d emulator-5554',
      ),
    );
  });

  test('only Android mobile builds use the enhanced Gradle cache', () {
    final mobileBuild = _job(workflow, 'mobile-debug-build');
    final androidBuild = _mobileEntry('ubuntu-24.04');
    final iosBuild = _mobileEntry('macos-26');

    expect(androidBuild['gradle_cache'], isTrue);
    expect(iosBuild['gradle_cache'], isFalse);
    expect(mobileBuild, contains('if: matrix.gradle_cache'));
    expect(mobileBuild, contains('uses: gradle/actions/setup-gradle@v6'));
    expect(mobileBuild, contains('cache-provider: enhanced'));
  });

  test('the scanner no longer forces SwiftPM off while iOS uses CocoaPods', () {
    expect(appPubspec, contains('mobile_scanner: ^7.4.0'));
    expect(
      appPubspec,
      isNot(contains('enable-swift-package-manager: false')),
    );
    expect(iosDebugConfig, contains('Pods-Runner.debug.xcconfig'));
    expect(iosReleaseConfig, contains('Pods-Runner.release.xcconfig'));
    expect(iosPodfile, contains("platform :ios, '13.0'"));
    expect(iosPodfile, isNot(contains('use_frameworks!')));
    expect(iosPodfile, contains('use_modular_headers!'));
    expect(
      iosPodfile,
      contains("config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'"),
    );
    expect(iosPodfile, contains('post_integrate do |installer|'));
    expect(iosPodfile, contains('frameworks_build_phase.files.find'));
    expect(iosPodfile, contains("display_name == 'libPods-Runner.a'"));
    expect(iosPodfile, contains('frameworks_group.remove_reference'));
    expect(iosPodfile, contains('frameworks_build_phase.remove_build_file'));
    expect(
      iosPodfile,
      contains("raise 'Missing redundant Pods-Runner library reference'"),
    );
    final iosBuild = _mobileEntry('macos-26');
    expect(
      iosBuild['command'],
      contains('flutter build ios --debug --no-codesign'),
    );
    expect(iosBuild['command'], isNot(contains('--simulator')));
    expect(iosProject, isNot(contains('FlutterGeneratedPluginSwiftPackage')));
  });

  test('native attachment plugins receive macOS and Windows debug builds', () {
    final desktopBuild = _job(workflow, 'desktop-debug-build');
    expect(
      _matrixEntry(desktopBuild, 'macos-26'),
      contains('flutter build macos --debug -t lib/main.dart'),
    );
    expect(
      _matrixEntry(desktopBuild, 'windows-2025'),
      contains('flutter build windows --debug -t lib/main.dart'),
    );
    expect(_job(workflow, 'quality-gate'), contains('- desktop-debug-build'));
  });

  test('Windows stages Lua with Flutter CMake in a short build tree', () {
    expect(
      windowsCmake,
      contains(r'--cmake-executable "${CMAKE_COMMAND}"'),
    );
    expect(
      windowsCmake,
      contains(r'--build-directory "${LUA_RUNTIME_BUILD}"'),
    );
    expect(windowsCmake, contains('run lua_tool_runtime:stage'));
    expect(windowsCmake, isNot(contains('tool/build_lua_host.dart')));
  });

  test('Windows refreshes a cached target-relative install prefix', () {
    expect(
      windowsCmake,
      contains('CMAKE_INSTALL_PREFIX MATCHES'),
      reason:
          'A build directory configured before an executable rename keeps its '
          r'$<TARGET_FILE_DIR:old_name> install prefix in CMakeCache.txt.',
    );
    expect(
      windowsCmake,
      contains(r'\\$<TARGET_FILE_DIR:[^>]+>$'),
      reason:
          'Only CMake-managed target-relative prefixes should be refreshed.',
    );
    expect(
      windowsCmake,
      contains(
        r'set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" '
        'CACHE PATH "..." FORCE)',
      ),
    );
  });

  test('Windows release artifacts carry their app-local MSVC runtime', () {
    expect(
      windowsCmake,
      contains('set(CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS_SKIP TRUE)'),
    );
    expect(windowsCmake, contains('include(InstallRequiredSystemLibraries)'));
    expect(
      windowsCmake,
      contains(r'install(PROGRAMS ${CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS}'),
    );
    expect(
      windowsCmake,
      contains(r'DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime'),
    );

    final release = _job(workflow, 'build-and-package');
    expect(release, contains(r'$PWD\packages\desktop_app\build\windows\'));
    expect(
      release,
      contains(r'$PWD\packages\desktop_app\windows\installer\tinest.iss'),
    );
    expect(release, isNot(contains(r'$PWD\apps\app\')));
    for (final dll in <String>[
      'msvcp140.dll',
      'vcruntime140.dll',
      'vcruntime140_1.dll',
    ]) {
      expect(release, contains(dll));
    }
    expect(release, contains('Test-Path -LiteralPath'));
    expect(release, contains('/VERYSILENT'));
    expect(release, contains('/CURRENTUSER'));
    expect(release, contains('Start-Process'));
    expect(release, contains('-Wait'));
    expect(release, contains('-PassThru'));
    expect(release, contains(r'$installProcess.ExitCode'));
    expect(release, isNot(contains(r'& $installer /VERYSILENT')));
    expect(
      windowsInstaller,
      contains('PrivilegesRequiredOverridesAllowed=commandline dialog'),
    );
  });

  test('Android supplies the CargoKit Gradle 9 exec compatibility service', () {
    expect(
      androidBuild,
      contains('apply(from = "cargokit-gradle9-compat.gradle")'),
    );
    expect(cargoKitCompat.existsSync(), isTrue);
    final script = cargoKitCompat.readAsStringSync();
    expect(script, contains('ExecOperations'));
    expect(script, isNot(contains('project.exec')));
    expect(script, contains('android.compileSdk = 36'));
  });

  test('Android build tooling stays on the supported stable releases', () {
    expect(
      androidSettings,
      contains('id("com.android.application") version "9.3.2"'),
    );
    expect(
      androidSettings,
      contains('id("org.jetbrains.kotlin.android") version "2.4.10"'),
    );
    expect(androidGradleWrapper, contains('gradle-9.7.1-all.zip'));
  });

  test('shipworld runs from the pinned Tinyrack Dart workspace', () {
    const shipworldRoot = '.dart_tool/tinyrack-dart-packages';
    final shipworldExecutable = <String>[
      shipworldRoot,
      'packages',
      'shipworld',
      'bin',
      'shipworld.dart',
    ].join('/');
    // The workflow ref and the cliweave dependency ref are two independent
    // copies of one commit; a release that resolved them differently would
    // package the CLI with a shipworld that disagrees with the framework it
    // was built against. Comparing them keeps the SHA in one place.
    final pubspec = File(
      'packages/cli/pubspec.yaml',
    ).readAsStringSync();
    final dependencyRef = RegExp(
      'ref: ([0-9a-f]{40})',
    ).firstMatch(pubspec)?.group(1);
    expect(dependencyRef, isNotNull);
    expect(
      workflow,
      contains('TINYRACK_DART_PACKAGES_REF: $dependencyRef'),
    );
    expect(workflow, contains('repository: tinyrack-net/dart-packages'));
    expect(
      workflow,
      contains(r'ref: ${{ env.TINYRACK_DART_PACKAGES_REF }}'),
    );
    expect(
      workflow,
      contains('dart pub get --directory $shipworldRoot'),
    );
    expect(workflow, contains('dart run $shipworldExecutable'));
    expect(workflow, isNot(contains('dart pub global activate shipworld')));
    expect(
      workflow,
      isNot(contains('dart pub global run shipworld:shipworld')),
    );
  });
  test('every workflow job runs only on GitHub-hosted images', () {
    final workflows = Directory('.github/workflows')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.yml'));
    for (final file in workflows) {
      final contents = file.readAsStringSync();
      expect(loadYaml(contents), isA<YamlMap>(), reason: file.path);
      for (final forbidden in <String>[
        'runner_pool:',
        'self-hosted',
        'tinyrack-ubuntu-ci',
        'tinyrack-windows-ci',
        'runner_linux',
        'runner_windows',
        'runner_macos',
        'fromJSON(matrix.runs_on)',
      ]) {
        expect(contents, isNot(contains(forbidden)), reason: file.path);
      }
    }
  });

  test('the x86_64 macOS target uses an x64 SDK on hosted arm64', () {
    // Dart compiles for the architecture it runs as and `dart build cli` has
    // no cross-architecture option, so the SDK is the only lever. Doing it
    // this way is what leaves no quality job needing a hosted Intel runner,
    // and hosted macOS allows five concurrent jobs, so that one job could
    // serialise the merge gate on its own.
    final entry = _cliEntry('macos-x64');
    expect(entry['os'], 'macos-26');
    expect(entry['sdk_arch'], 'x64');
    expect(entry['platform'], 'macos');
    expect(
      _job(workflow, 'cli-verify'),
      contains(r'architecture: ${{ matrix.sdk_arch }}'),
    );
    // The arm64 target must not inherit an x86_64 SDK by accident.
    expect(_cliEntry('macos-arm64')['sdk_arch'], isNull);
    // The workflow does not need an Intel image to produce the x64 target.
    expect(_job(workflow, 'changes'), isNot(contains('macos-intel')));
  });

  test('release jobs use exact GitHub-hosted images directly', () {
    for (final name in <String>['build-and-package', 'build-cli']) {
      final job = _job(workflow, name);
      expect(
        job,
        contains(r'runs-on: ${{ matrix.os }}'),
        reason: name,
      );
      expect(
        job,
        contains(r'architecture: ${{ matrix.sdk_arch }}'),
        reason: name,
      );
      for (final label in <String>[
        'ubuntu-24.04',
        'macos-26',
        'windows-2025',
      ]) {
        expect(job, contains('- os: $label'), reason: '$name: $label');
      }
    }
    // Nothing declares the Intel image any more, so the lint allowance for it
    // must go too or it stops meaning anything.
    expect(
      File('.github/actionlint.yaml').readAsStringSync(),
      isNot(contains('macos-15-intel')),
    );
    final packaging = _job(workflow, 'build-and-package');
    expect(packaging, isNot(contains('command -v nfpm')));
    expect(packaging, isNot(contains('command -v appimagetool')));
    expect(packaging, contains(r'echo "${NFPM_SHA256}  nfpm.deb"'));
    expect(packaging, contains(r'echo "${APPIMAGETOOL_SHA256}  appimagetool"'));
  });

  test('the CLI smoke daemon uses a fixed port on its isolated runner', () {
    final smoke = File(
      '.github/actions/smoke-cli-bundle/action.yml',
    ).readAsStringSync();
    expect(smoke, contains("default: '7399'"));
    expect(smoke, isNot(contains('RUNNER_NAME')));
    expect(smoke, isNot(contains('cksum')));
  });

  test('the macOS app is checked before it is signed', () {
    // A wrong-architecture app that gets signed and notarized costs a full
    // round trip to Apple to find out, and the signature would then vouch for
    // the wrong binary.
    final job = _job(workflow, 'build-and-package');
    final verify = job.indexOf('./.github/actions/verify-macos-arch');
    final sign = job.indexOf('Sign and archive the macOS app');
    expect(verify, isNot(-1));
    expect(sign, isNot(-1));
    expect(verify, lessThan(sign));
  });

  test('a macOS bundle is checked against the architecture it claims', () {
    // Rosetta runs the x86_64 bundle on the machine that built it, so the
    // smoke test passes whichever architecture came out. Without this an arm64
    // build would ship under an x64 name through the Homebrew formula and the
    // first sign would be an Intel user's crash.
    final verifier = File(
      '.github/actions/verify-macos-arch/action.yml',
    ).readAsStringSync();
    expect(verifier, contains('lipo -archs'));
    expect(verifier, contains('*-x64) want=x86_64'));
    expect(verifier, contains('*-arm64) want=arm64'));
    // Every Mach-O file, not only the launcher: sqlite3 downloads a prebuilt
    // library, the Lua host is compiled by a build hook, and a Flutter app
    // carries frameworks, so any one can resolve for the wrong architecture.
    expect(verifier, contains("grep -q 'Mach-O'"));
    // Finding nothing has to fail, or a bundle-layout change turns this into a
    // step that always passes.
    expect(verifier, contains('Found no Mach-O files to check'));
    expect(
      File('.github/actions/build-cli-bundle/action.yml').readAsStringSync(),
      contains('./.github/actions/verify-macos-arch'),
    );
  });

  test('every quality job uses an exact hosted image or hosted matrix', () {
    const singleHost = <String>[
      'static-linux',
      'generated-linux',
      'fast-dart-tests-linux',
      'fast-flutter-tests-linux',
      'coverage-dart-linux',
      'coverage-flutter-linux',
      'relay-coverage-linux',
      'relay-smoke-linux',
      'debug-e2e-linux',
      'linux-ibus-terminal-e2e',
      'web-build',
    ];
    for (final name in singleHost) {
      expect(
        _job(workflow, name),
        contains('runs-on: ubuntu-24.04'),
        reason: name,
      );
    }
    // The matrix jobs carry the resolved labels per entry instead, so one job
    // body can still span several hosts.
    for (final name in <String>[
      'dart-tests',
      'flutter-tests',
      'desktop-debug-build',
      'mobile-debug-build',
      'cli-verify',
    ]) {
      expect(
        _job(workflow, name),
        contains(r'runs-on: ${{ matrix.os }}'),
        reason: name,
      );
    }
  });

  test('the scope and gate jobs stay pinned as the fixed reference', () {
    // `changes` cannot read its own outputs, and `quality-gate` is a jq
    // one-liner whose duration is the same on either pool, so both stay on the
    // hosted label and act as the fixed point both arms are measured against.
    expect(_job(workflow, 'changes'), contains('runs-on: ubuntu-24.04'));
    expect(_job(workflow, 'quality-gate'), contains('runs-on: ubuntu-24.04'));
  });

  test('hosted runners use Actions caches without environment branches', () {
    final setup = File(
      '.github/actions/setup-flutter/action.yml',
    ).readAsStringSync();
    expect(setup, contains(r"cache: ${{ runner.os != 'Windows' }}"));
    expect(setup, isNot(contains('runner.environment')));
    expect(setup, isNot(contains('pub-cache:')));

    expect(linuxDesktopDependencies, contains('uses: actions/cache@v4'));
    expect(linuxDesktopDependencies, isNot(contains('runner.environment')));
    expect(linuxDesktopDependencies, isNot(contains('outputs.missing')));
    for (final gradle in <String>[
      _job(workflow, 'mobile-debug-build'),
      _job(workflow, 'build-android-release'),
    ]) {
      expect(gradle, isNot(contains('cache-disabled:')));
    }
  });

  test('the obsolete host fingerprint action is removed', () {
    expect(workflow, isNot(contains('./.github/actions/host-fingerprint')));
    expect(
      nightlyWorkflow,
      isNot(contains('./.github/actions/host-fingerprint')),
    );
    expect(
      File(
        '.github/actions/host-fingerprint/action.yml',
      ).existsSync(),
      isFalse,
    );
  });
}

String _job(String workflow, String name) {
  final start = workflow.indexOf('  $name:\n');
  if (start < 0) throw StateError('Missing workflow job $name');
  final next = RegExp(r'^  [a-z][a-z0-9-]*:$', multiLine: true).firstMatch(
    workflow.substring(start + name.length + 3),
  );
  final end = next == null
      ? workflow.length
      : start + name.length + 3 + next.start;
  return workflow.substring(start, end);
}

/// The CLI build matrix entry for [target].
Map<String, dynamic> _cliEntry(String target) {
  return (_matrices['cli']! as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .where((entry) => entry['target'] == target)
          .firstOrNull ??
      (throw StateError('Missing CLI matrix entry for $target'));
}

Map<String, dynamic> _mobileEntry(String os) {
  return (_matrices['mobile']! as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .where((entry) => entry['os'] == os)
          .firstOrNull ??
      (throw StateError('Missing mobile matrix entry for $os'));
}

String _matrixEntry(String job, String os) {
  final start = job.indexOf('          - os: $os\n');
  if (start < 0) throw StateError('Missing matrix entry for $os');
  final next = job.indexOf('          - os:', start + 1);
  return job.substring(start, next < 0 ? job.length : next);
}
