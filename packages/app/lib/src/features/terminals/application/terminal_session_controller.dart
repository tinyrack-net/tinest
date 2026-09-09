import 'dart:async';

import 'package:app/src/features/hosts/application/host_controller.dart';
import 'package:client/client.dart';
import 'package:protocol/protocol.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:termworld/termworld.dart';

part 'terminal_session_controller.g.dart';

/// Scrollback lines one long-lived terminal keeps in memory.
///
/// Kept in step with the daemon's per-terminal replay budget: retaining far
/// more here than the daemon could ever replay only costs memory, and a line
/// is a list of per-cell objects rather than a packed buffer.
const int terminalScrollbackLines = 1000;

/// Where one terminal session stands with its daemon.
enum TerminalSessionStatus {
  /// An attach round trip is in flight.
  attaching,

  /// A rebuilt screen is being painted and input is being dropped.
  restoring,

  /// Live output is flowing into the emulator.
  live,

  /// The host is offline; the emulator keeps everything it already has.
  reconnecting,

  /// The attach failed and the user can retry.
  failed,
}

/// One terminal's emulator plus the state of its daemon attachment.
final class TerminalSessionState {
  /// Creates a session snapshot.
  const new({
    required this.terminal,
    required this.status,
    required this.hasContent,
    this.error,
  });

  /// Emulator whose identity is stable for the whole session.
  ///
  /// [TerminalView] repaints from this object directly, so ordinary output
  /// never has to be published as a new session state.
  final Terminal terminal;

  /// Attachment phase this session is in.
  final TerminalSessionStatus status;

  /// Whether anything has ever been written into [terminal].
  final bool hasContent;

  /// Failure behind [TerminalSessionStatus.failed].
  final Object? error;

  /// Returns a copy with [status], [hasContent] and [error] replaced.
  TerminalSessionState _with(
    TerminalSessionStatus status, {
    required bool hasContent,
    Object? error,
  }) => TerminalSessionState(
    terminal: terminal,
    status: status,
    hasContent: hasContent,
    error: error,
  );
}

@riverpod
/// Owns one terminal's emulator, its attachment, and its daemon wiring.
///
/// The emulator outlives the pane that renders it, so switching tabs cannot
/// reset the scrollback, and output produced while the tab is off screen is
/// still written as it arrives. The pane is therefore not what keeps this
/// alive: `TerminalSessionLeases` holds a lease for as long as the checkout
/// shows a tab for this terminal, and the session ends when that lease is
/// dropped. Auto-disposal, rather than invalidation, is what ends it — see
/// `terminal_session_leases.dart` for why the distinction matters.
class TerminalSessionController extends _$TerminalSessionController {
  Terminal? _terminal;
  StreamSubscription<TerminalOutputDto>? _output;
  TinestApi? _api;
  int _sequence = 0;
  bool _started = false;
  bool _restoring = false;
  ({int columns, int rows})? _daemonSize;

  /// Viewport this session has claimed for the terminal, or null if it never
  /// has.
  ///
  /// Only a genuine resize from the view sets this. Attaching, remounting at
  /// the same size, and a renderer settling are passive, and a size claimed
  /// from one of those would fight every other client attached to the same
  /// terminal.
  ({int columns, int rows})? _claimedSize;

  @override
  TerminalSessionState build(String hostId, String terminalId) {
    // Synchronous by construction. Watching the connection here would rebuild
    // the provider on every reconnect and hand the pane a brand new, empty
    // emulator, which is the reset this provider exists to prevent.
    _sequence = 0;
    _daemonSize = null;
    _claimedSize = null;
    _started = false;
    _restoring = false;
    final terminal = Terminal(
      options: TerminalOptions(
        rightClickSelectsWord: false,
        // The value happens to match termworld's default today. Stating it
        // keeps a package upgrade from silently changing how much memory
        // every open tab holds, which is why the redundancy is intentional.
        // ignore: avoid_redundant_argument_values
        scrollback: terminalScrollbackLines,
      ),
    );
    terminal.onData.listen(_sendInput);
    terminal.onResize.listen(_resize);
    _terminal = terminal;
    ref.onDispose(() {
      _terminal = null;
      unawaited(_output?.cancel());
      terminal.dispose();
    });
    // Fires immediately, so `_api` is already resolved when the first state is
    // returned; state writes are suppressed until then by `_started`.
    listenHostApi(ref, hostId, _onApiChanged);
    _started = true;
    return TerminalSessionState(
      terminal: terminal,
      status: _api == null
          ? TerminalSessionStatus.reconnecting
          : TerminalSessionStatus.attaching,
      hasContent: false,
    );
  }

  /// Re-runs the attach after a failure, keeping the emulator and its content.
  ///
  /// Invalidating the provider would destroy the emulator, so the retry
  /// affordance has to come through here.
  void retry() {
    final api = _api;
    if (api == null) return;
    _publish(TerminalSessionStatus.attaching);
    unawaited(_attach(api));
  }

  void _onApiChanged(TinestApi? api) {
    if (api == null) {
      _api = null;
      // Never clear the emulator here: a dropped socket must not cost the user
      // the scrollback they were reading.
      _publish(TerminalSessionStatus.reconnecting);
      return;
    }
    // A transient socket loss keeps the same client, which reattaches itself
    // and republishes the gap onto the stream we are already listening to, so
    // only a genuinely different API needs a new attachment.
    if (identical(api, _api) && _output != null) return;
    _api = api;
    _publish(TerminalSessionStatus.attaching);
    unawaited(_attach(api));
  }

  Future<void> _attach(TinestApi api) async {
    // Not awaited: a cancel that never completes must not strand the terminal,
    // and a stale chunk slipping through is dropped by the sequence gate.
    unawaited(_output?.cancel());
    // Subscribing before the round trip closes the window the daemon cannot
    // cover: it snapshots the replay when the call arrives, so a chunk
    // published after that reaches only a subscription that already exists.
    final pending = <TerminalOutputDto>[];
    var replaying = true;
    _output = api.terminals.output
        .where((output) => output.terminalId == terminalId)
        .listen((output) => replaying ? pending.add(output) : _accept(output));
    final TerminalAttachResultDto attached;
    try {
      attached = await api.terminals.attachTerminal(
        terminalId,
        // A session that has applied nothing has no byte stream to continue.
        mode: _sequence == 0
            ? TerminalRestoreMode.snapshot
            : TerminalRestoreMode.resume,
        afterSequence: _sequence,
        viewport: switch (_claimedSize) {
          null => null,
          final size => TerminalViewportDto(
            columns: size.columns,
            rows: size.rows,
          ),
        },
      );
    } on Object catch (error) {
      unawaited(_output?.cancel());
      _output = null;
      _publish(TerminalSessionStatus.failed, error: error);
      return;
    }
    // A newer attachment, or disposal, overtook this one while it was in
    // flight; its subscription has already been replaced.
    if (_terminal == null || !identical(api, _api)) return;
    _applyDaemonSize(attached.terminal);
    switch (attached.restore) {
      case TerminalDeltaRestoreDto(:final chunks):
        chunks.forEach(_accept);
      case TerminalSnapshotRestoreDto(:final throughSequence, :final ansi):
        _applySnapshot(throughSequence: throughSequence, ansi: ansi);
    }
    replaying = false;
    pending.forEach(_accept);
    _publish(TerminalSessionStatus.live);
  }

  /// Rebuilds the emulator from a daemon snapshot behind an input barrier.
  ///
  /// The barrier covers two hazards rather than one. A keystroke typed into a
  /// half-painted screen lands in the wrong place; and the snapshot can carry
  /// a sequence the emulator answers on `onData`, which would reach the shell
  /// as typed input. Both are dropped for the duration, not queued.
  void _applySnapshot({required int throughSequence, required String ansi}) {
    final terminal = _terminal!;
    _restoring = true;
    _publish(TerminalSessionStatus.restoring);
    // A snapshot describes a whole terminal, including the alternate buffer
    // and the private modes. Writing it into one that already holds state
    // stacks the two.
    terminal.reset();
    // Assigned before the write so a live chunk the snapshot already includes
    // is discarded by the sequence gate rather than applied twice.
    _sequence = throughSequence;
    if (ansi.isEmpty) {
      // An empty payload is a terminator in the emulator's write queue, not a
      // no-op: queueing it would stall every chunk behind it.
      _restoring = false;
      return;
    }
    terminal.write(
      ansi,
      onParsed: () {
        if (!identical(_terminal, terminal)) return;
        _restoring = false;
      },
    );
  }

  /// Writes one chunk, gated by a single monotonic high-water mark.
  ///
  /// Replay and live notifications share the daemon's per-terminal sequence
  /// space, so one gate makes the merge idempotent under any overlap.
  void _accept(TerminalOutputDto output) {
    if (output.sequence <= _sequence) return;
    _sequence = output.sequence;
    _terminal?.write(output.data);
  }

  /// Reconciles the emulator and the daemon PTY geometry on every attach.
  void _applyDaemonSize(TerminalDto dto) {
    final terminal = _terminal!;
    if (_sequence == 0) {
      // First attach: adopt the daemon's width before any replay byte is
      // parsed, or the recorded output reflows at the wrong column count.
      _daemonSize = (columns: dto.columns, rows: dto.rows);
      terminal.resize(dto.columns, dto.rows);
      return;
    }
    if (terminal.cols == dto.columns && terminal.rows == dto.rows) {
      _daemonSize = (columns: dto.columns, rows: dto.rows);
      return;
    }
    // Adopt what the daemon reports and claim nothing. Either this session
    // asked for the size in its attach — in which case the daemon applied it
    // before serializing, and this is that size — or it did not ask, and
    // claiming now would arrive after the restore was built at the old
    // geometry and reflow it immediately.
    _daemonSize = (columns: dto.columns, rows: dto.rows);
    terminal.resize(dto.columns, dto.rows);
  }

  void _sendInput(String data) {
    // See `_applySnapshot`: mid-restore output is not input the user meant.
    if (_restoring) return;
    unawaited(
      _api?.terminals.writeTerminal(terminalId, data) ?? Future<void>.value(),
    );
  }

  void _resize(TerminalResizeEvent size) {
    // Adopting the daemon's geometry fires this too; echoing it straight back
    // would bounce a redundant resize at the daemon on every attach.
    if (_daemonSize case final known?
        when known.columns == size.cols && known.rows == size.rows) {
      return;
    }
    // The one place a size is claimed. It survives a reconnect deliberately:
    // the user's last real viewport should win over whatever geometry the
    // daemon comes back with, and it travels with the attach instead of
    // racing it.
    _daemonSize = (columns: size.cols, rows: size.rows);
    _claimedSize = _daemonSize;
    unawaited(
      _api?.terminals.resizeTerminal(
            terminalId,
            columns: size.cols,
            rows: size.rows,
          ) ??
          Future<void>.value(),
    );
  }

  void _publish(TerminalSessionStatus status, {Object? error}) {
    if (!_started || _terminal == null) return;
    state = state._with(status, hasContent: _sequence > 0, error: error);
  }
}
