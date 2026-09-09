@Tags(<String>['feature_test__plugin_authoring__unit'])
@Timeout(Duration(minutes: 2))
library;

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:daemon/src/features/plugins/infrastructure/plugin_bundles.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'support/temporary_directory.dart';

/// Enough bytes that both isolates are still writing when either one renames.
///
/// The staging window is what the two have to overlap in, and a small bundle
/// closes it faster than two isolates can be released from a barrier.
const int _assetCount = 400;
const int _assetBytes = 64 * 1024;

void main() {
  test(
    'two isolates storing one revision do not share a staging directory',
    () async {
      // `dart test` runs VM suites as isolates of one process, so a staging
      // name built from the process ID plus a top-level counter is not unique:
      // the counter is per-isolate and starts at zero in each. Two isolates
      // storing the same revision therefore pick the same path, write into it
      // together, and whichever one renames first pulls the directory out from
      // under the other's writes.
      final state = await Directory.systemTemp.createTemp(
        'tinest-revision-cache-',
      );
      addTearDown(() => deleteTemporaryDirectory(state));

      final done = ReceivePort();
      final results = <Object?>[];
      final gate = ReceivePort();
      final ready = <SendPort>[];
      final finished = done.take(2).forEach(results.add);

      gate.listen((message) {
        ready.add(message! as SendPort);
        // Release both only once both are parked, so neither can finish
        // staging before the other starts.
        if (ready.length == 2) {
          for (final port in ready) {
            port.send(null);
          }
        }
      });
      for (var index = 0; index < 2; index += 1) {
        await Isolate.spawn(_storeRevision, <Object>[
          state.path,
          gate.sendPort,
          done.sendPort,
        ]);
      }
      await finished;
      done.close();
      gate.close();

      expect(
        results.where((result) => result != null),
        isEmpty,
        reason: 'storing the same revision concurrently must not fail',
      );
    },
  );
}

Future<void> _storeRevision(List<Object> arguments) async {
  final statePath = arguments[0] as String;
  final gate = arguments[1] as SendPort;
  final done = arguments[2] as SendPort;
  final release = ReceivePort();
  gate.send(release.sendPort);
  await release.first;
  release.close();
  try {
    await NativePluginRevisionCache(statePath).storeInstalled(_bundle());
    done.send(null);
  } on Object catch (error) {
    done.send('$error');
  }
}

PluginBundle _bundle() {
  // Content-addressed, so both isolates must produce the same hash to collide
  // on the same revision directory. A fixed byte pattern keeps it that way.
  final asset = Uint8List(_assetBytes)..fillRange(0, _assetBytes, 0x41);
  return PluginBundle(
    descriptor: const PluginDescriptorDto(
      apiMajor: 1,
      id: 'concurrent.staging',
      version: '1.0.0',
      name: 'Concurrent',
      entrypoint: 'main.lua',
      source: PluginSource.user,
      sourcePath: 'plugins/concurrent',
      requestedCapabilities: <String>[],
    ),
    revision: PluginRevisionDto(
      pluginId: 'concurrent.staging',
      contentHash: 'a' * 64,
      manifestHash: 'c' * 64,
      sdkAbiHash: 'd' * 64,
      executionRevisionHash: 'b' * 64,
      requestedCapabilities: const <String>[],
    ),
    assets: <String, Uint8List>{
      'PLUGIN.md': Uint8List.fromList('# Concurrent\n'.codeUnits),
      for (var index = 0; index < _assetCount; index += 1)
        'assets/blob-$index.bin': asset,
    },
  );
}
