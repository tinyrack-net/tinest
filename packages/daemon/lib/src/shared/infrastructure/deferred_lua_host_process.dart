import 'package:lua_tool_runtime/lua_tool_runtime.dart' as lua;

/// Resolves the immutable native Lua host distribution on first use.
typedef LuaHostCommandResolver = Future<lua.LuaHostCommand> Function();

/// Defers native Lua host staging until a runtime starts its first worker.
///
/// Daemon transports and non-Lua RPCs do not need the native helper. Keeping
/// resolution behind the process-launch boundary prevents an unused helper
/// build from delaying daemon readiness. Concurrent first workers share one
/// resolution, while a failed resolution remains retryable.
final class DeferredLuaHostProcessLauncher
    implements lua.LuaHostProcessLauncher {
  /// Creates a launcher over a lazily resolved host and concrete process port.
  new(this._resolver, this._delegate);

  final LuaHostCommandResolver _resolver;
  final lua.LuaHostProcessLauncher _delegate;
  Future<lua.LuaHostCommand>? _resolution;

  @override
  Future<lua.LuaHostProcess> start(
    lua.LuaHostCommand command, {
    required String workingDirectory,
  }) async {
    final resolved = await _resolve();
    return await _delegate.start(
      resolved.withEnvironment(command.environment),
      workingDirectory: workingDirectory,
    );
  }

  Future<lua.LuaHostCommand> _resolve() {
    final existing = _resolution;
    if (existing != null) return existing;

    final shared = Future<lua.LuaHostCommand>.sync(_resolver).then(
      (command) => command,
      onError: (Object error, StackTrace stackTrace) {
        _resolution = null;
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
    _resolution = shared;
    return shared;
  }
}
