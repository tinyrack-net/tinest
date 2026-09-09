import 'dart:async';

import 'package:app/src/app/composition/app_providers.dart';
import 'package:app/src/features/hosts/application/host_controller.dart';
import 'package:client/client.dart';
import 'package:protocol/protocol.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sessions_controller.g.dart';

@riverpod
/// SessionsController defines a public contract.
class SessionsController extends _$SessionsController {
  StreamSubscription<SessionDto>? _events;
  late String? _worktreeId;

  @override
  Future<List<SessionDto>> build(String hostId, String? worktreeId) async {
    _worktreeId = worktreeId;
    final api = await watchConnectedHostApi(ref, hostId);
    if (api == null || worktreeId == null) {
      return const <SessionDto>[];
    }
    _events = api.sessions.sessionUpdates.listen(_handleEvent);
    ref.onDispose(() => unawaited(_events?.cancel()));
    return await api.sessions.listSessions(worktreeId: worktreeId);
  }

  /// The create public API member.
  ///
  /// A non-null [model] is the chat-level override captured by the session.
  Future<SessionDto> create({
    required String title,
    required String agentDefinitionId,
    ModelSelectionDto? model,
    Map<String, ModelControlValueDto> modelControls =
        const <String, ModelControlValueDto>{},
    PermissionMode? permissionMode,
  }) async {
    final worktreeId = _worktreeId;
    if (worktreeId == null) {
      // Internal invariant, not user copy: the composer is disabled without
      // both, so this only fires on a bug. Left in English for the report.
      throw StateError('Worktree selection and daemon connection required.');
    }
    final api = await requireHostApi(ref, hostId);
    // Creating one row must not turn the whole catalog back into a loading
    // screen. The caller owns the in-flight/error presentation; this provider
    // keeps the last usable snapshot until the daemon confirms the new row.
    final session = await api.sessions.createSession(
      id: ref.read(appIdGeneratorProvider).generate(),
      worktreeId: worktreeId,
      title: title,
      agentDefinitionId: agentDefinitionId,
      model: model,
      modelControls: modelControls,
      permissionMode: permissionMode,
    );
    final current = state.asData?.value ?? const <SessionDto>[];
    state = AsyncData<List<SessionDto>>(<SessionDto>[
      session,
      ...current.where((item) => item.id != session.id),
    ]);
    return session;
  }

  /// Replaces the concrete provider and model snapshot of one session.
  Future<SessionDto> setModel(
    String sessionId,
    ModelSelectionDto model,
    Map<String, ModelControlValueDto> modelControls,
  ) => _apply(
    sessionId,
    (session) => session.copyWith(model: model, modelControls: modelControls),
    (api) => api.sessions.updateSettings(
      sessionId,
      SessionSettingsPatchDto(
        hasModel: true,
        model: model,
        hasModelControls: true,
        modelControls: modelControls,
      ),
    ),
  );

  /// Replaces the typed controls for one session's selected model.
  Future<SessionDto> setModelControls(
    String sessionId,
    Map<String, ModelControlValueDto> modelControls,
  ) => _apply(
    sessionId,
    (session) => session.copyWith(modelControls: modelControls),
    (api) => api.sessions.updateSettings(
      sessionId,
      SessionSettingsPatchDto(
        hasModelControls: true,
        modelControls: modelControls,
      ),
    ),
  );

  /// Replaces the permission mode of one session.
  Future<SessionDto> setPermissionMode(
    String sessionId,
    PermissionMode permissionMode,
  ) => _apply(
    sessionId,
    (session) => session.copyWith(permissionMode: permissionMode),
    (api) => api.sessions.updateSettings(
      sessionId,
      SessionSettingsPatchDto(permissionMode: permissionMode),
    ),
  );

  /// Shows a turn-setting change immediately and confirms it with the daemon.
  ///
  /// Without the local patch the chip keeps its old label for a full round
  /// trip and then flips, which reads as a flicker rather than a toggle. The
  /// daemon still owns the value, so its answer replaces the guess and a
  /// failure restores what was on screen before.
  Future<SessionDto> _apply(
    String sessionId,
    SessionDto Function(SessionDto session) patch,
    Future<SessionDto> Function(TinestApi api) commit,
  ) async {
    // Patched before the first suspension, so the chip is already showing the
    // new value on the frame the tap is handled.
    final previous = state.asData?.value
        .where((session) => session.id == sessionId)
        .firstOrNull;
    if (previous != null) _replace(patch(previous));
    try {
      final session = await commit(await requireHostApi(ref, hostId));
      _replace(session);
      return session;
    } on Exception {
      if (previous != null) _replace(previous);
      rethrow;
    }
  }

  void _handleEvent(SessionDto session) {
    if (!ref.mounted) return;
    if (session.worktreeId == _worktreeId) {
      _replace(session);
    }
  }

  void _replace(SessionDto updated) {
    final current = state.asData?.value;
    if (current == null) return;
    final exists = current.any((session) => session.id == updated.id);
    state = AsyncData<List<SessionDto>>(<SessionDto>[
      if (!exists) updated,
      for (final agent in current)
        if (agent.id == updated.id) updated else agent,
    ]);
  }
}
