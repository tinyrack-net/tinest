import 'dart:io';

import 'package:path/path.dart' as p;

/// Holds the daemon lock from a separate process.
///
/// POSIX record locks are owned per process, so a second handle opened by the
/// test itself would acquire the lock instead of contending for it.
final class DaemonLockHolder {
  new _(this._process);

  final Process _process;

  /// Starts a holder that owns the exclusive lock on [lockPath].
  ///
  /// [root] only supplies a writable place for the holder script.
  static Future<DaemonLockHolder> start({
    required Directory root,
    required String lockPath,
  }) async {
    final script = File(p.join(root.path, 'lock_holder.dart'));
    await script.writeAsString('''
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final handle = await File(arguments.single).open(mode: FileMode.append);
  await handle.lock();
  stdout.writeln('locked');
  await stdin.first;
  await handle.unlock();
  await handle.close();
}
''');
    final process = await Process.start(Platform.resolvedExecutable, <String>[
      script.path,
      lockPath,
    ]);
    await process.stdout.first;
    return DaemonLockHolder._(process);
  }

  /// Releases the lock and waits for the holder to exit.
  ///
  /// The holder unlocks and closes its handle when stdin delivers a line.
  /// Killing it skipped that protocol, and on Windows the file was still open
  /// when the temporary directory was deleted, failing the test in teardown
  /// with "the process cannot access the file because it is being used by
  /// another process".
  Future<void> stop() async {
    _process.stdin.writeln();
    await _process.stdin.flush();
    await _process.stdin.close();
    await _process.exitCode.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _process.kill();
        return _process.exitCode;
      },
    );
  }
}

/// Deletes [directory], retrying briefly while the platform still holds it.
///
/// Windows can report a just-closed file as in use for a moment, and a
/// teardown that trips over it fails a test that already passed.
Future<void> deleteWithRetry(Directory directory) async {
  for (var attempt = 0; ; attempt += 1) {
    try {
      await directory.delete(recursive: true);
      return;
    } on FileSystemException {
      if (attempt >= 10) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}
