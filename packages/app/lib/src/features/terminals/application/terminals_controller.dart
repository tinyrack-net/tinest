import 'dart:async';

import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/features/hosts/application/host_controller.dart';
import 'package:protocol/protocol.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'terminals_controller.g.dart';

@riverpod
/// Loads and edits the daemon-wide shell inherited by project terminals.
class HostShellSettingsController extends _$HostShellSettingsController {
  @override
  Future<ShellSpecDto?> build(String hostId) async {
    final api = await watchHostApi(ref, hostId);
    return await api.terminals.getTerminalShell();
  }

  /// Replaces or clears the daemon-wide terminal shell.
  Future<void> save(ShellSpecDto? shell) async {
    final api = await requireHostApi(ref, hostId);
    await api.terminals.setTerminalShell(shell);
    state = AsyncData<ShellSpecDto?>(shell);
  }
}

@riverpod
/// Owns the live terminal catalog for one connected worktree.
class TerminalsController extends _$TerminalsController {
  StreamSubscription<TerminalDto>? _events;

  @override
  Future<List<TerminalDto>> build(String hostId, String worktreeId) async {
    final api = await watchConnectedHostApi(ref, hostId);
    if (api == null) return const <TerminalDto>[];
    _events = api.terminals.terminalUpdates.listen((terminal) {
      if (terminal.worktreeId == worktreeId) {
        final current = state.asData?.value ?? const <TerminalDto>[];
        state = AsyncData<List<TerminalDto>>(<TerminalDto>[
          terminal,
          ...current.where((item) => item.id != terminal.id),
        ]);
      }
    });
    ref.onDispose(() => unawaited(_events?.cancel()));
    return await api.terminals.listTerminals(worktreeId);
  }

  /// Creates a terminal with a standard initial character grid.
  ///
  /// [buildTitle] receives the tab's number within this worktree. The title is
  /// stored on the daemon, so it has to be localized, but only the caller is
  /// close enough to the widget tree to know the reader's language.
  Future<TerminalDto> create({
    required String Function(int number) buildTitle,
  }) async {
    final api = await requireHostApi(ref, hostId);
    final current = state.asData?.value ?? const <TerminalDto>[];
    final terminal = await api.terminals.createTerminal(
      id: ref.read(appIdGeneratorProvider).generate(),
      worktreeId: worktreeId,
      title: buildTitle(current.length + 1),
      columns: 80,
      rows: 24,
    );
    state = AsyncData<List<TerminalDto>>(<TerminalDto>[terminal, ...current]);
    return terminal;
  }
}

/// Visible and selected session tabs for one worktree.
