/// Shell command used to start a terminal.
final class TerminalShell {
  /// Creates a shell command.
  const new({required this.executable, this.arguments = const []});

  /// Executable path or command name.
  final String executable;

  /// Arguments passed to [executable].
  final List<String> arguments;
}

/// Lifecycle state of a daemon-owned terminal.
enum TerminalLifecycle {
  /// Process is accepting input.
  running,

  /// Process exited normally.
  exited,

  /// Process or PTY stream failed.
  failed,
}

/// Domain snapshot of a daemon-owned terminal.
final class Terminal {
  /// Creates a terminal snapshot.
  const new({
    required this.id,
    required this.worktreeId,
    required this.title,
    required this.shell,
    required this.status,
    required this.columns,
    required this.rows,
    required this.lastSequence,
    this.exitCode,
    this.error,
  });

  /// Stable terminal identifier.
  final String id;

  /// Worktree containing the process.
  final String worktreeId;

  /// User-facing title.
  final String title;

  /// Shell command used by the process.
  final TerminalShell shell;

  /// Current lifecycle state.
  final TerminalLifecycle status;

  /// PTY columns.
  final int columns;

  /// PTY rows.
  final int rows;

  /// Last emitted output sequence.
  final int lastSequence;

  /// Process exit code after a normal exit.
  final int? exitCode;

  /// Failure description after an abnormal exit.
  final String? error;

  /// Returns a copy with selected fields replaced.
  Terminal copyWith({
    TerminalLifecycle? status,
    int? columns,
    int? rows,
    int? lastSequence,
    int? exitCode,
    String? error,
  }) => Terminal(
    id: id,
    worktreeId: worktreeId,
    title: title,
    shell: shell,
    status: status ?? this.status,
    columns: columns ?? this.columns,
    rows: rows ?? this.rows,
    lastSequence: lastSequence ?? this.lastSequence,
    exitCode: exitCode ?? this.exitCode,
    error: error ?? this.error,
  );
}

/// One ordered terminal output chunk.
final class TerminalOutput {
  /// Creates an output chunk.
  const new({
    required this.terminalId,
    required this.sequence,
    required this.data,
  });

  /// Owning terminal identifier.
  final String terminalId;

  /// Monotonic per-terminal sequence.
  final int sequence;

  /// UTF-8 text emitted by the PTY.
  final String data;

  /// Returns a copy with replaced text.
  TerminalOutput copyWith({String? data}) => TerminalOutput(
    terminalId: terminalId,
    sequence: sequence,
    data: data ?? this.data,
  );
}

/// How the daemon should bring an attaching client up to date.
///
/// Named apart from the wire's `TerminalRestoreMode` the way
/// [TerminalLifecycle] is named apart from `TerminalStatus`: the transport
/// chooses its own words and the mapper is the one place the two meet.
enum TerminalRestoreStrategy {
  /// Continue the byte stream after a cursor, if the daemon still retains it.
  resume,

  /// Rebuild from the screen model regardless of what output is retained.
  snapshot,
}

/// Cell geometry an attaching client is claiming for the pseudo-terminal.
final class TerminalViewport {
  /// Creates a viewport claim.
  const new({required this.columns, required this.rows});

  /// Claimed column count.
  final int columns;

  /// Claimed row count.
  final int rows;
}

/// What an attaching client asks the daemon to rebuild.
final class TerminalRestoreRequest {
  /// Creates a restore request.
  const new({
    required this.strategy,
    this.afterSequence = 0,
    this.scrollbackLines = 200,
    this.viewport,
  });

  /// Whether the client can resume or needs a rebuilt screen.
  final TerminalRestoreStrategy strategy;

  /// Highest sequence the client has already applied.
  final int afterSequence;

  /// Retained rows the client wants a rebuilt screen to carry.
  final int scrollbackLines;

  /// Size to claim before anything is serialized, or null for a passive
  /// attach.
  final TerminalViewport? viewport;
}

/// Terminal metadata plus whatever makes an attaching client current.
sealed class TerminalRestore {
  const new({required this.terminal});

  /// Current terminal metadata.
  final Terminal terminal;
}

/// Retained output continuing a client's cursor.
final class TerminalDeltaRestore extends TerminalRestore {
  /// Creates a delta restore.
  const new({
    required super.terminal,
    required this.afterSequence,
    required this.chunks,
  });

  /// Cursor the chunks continue.
  final int afterSequence;

  /// Output newer than [afterSequence].
  final List<TerminalOutput> chunks;
}

/// A screen rebuilt from the daemon's own emulator.
final class TerminalSnapshotRestore extends TerminalRestore {
  /// Creates a snapshot restore.
  const new({
    required super.terminal,
    required this.throughSequence,
    required this.ansi,
  });

  /// Highest sequence [ansi] already includes.
  final int throughSequence;

  /// ANSI reproducing the screen in a reset terminal.
  final String ansi;
}
