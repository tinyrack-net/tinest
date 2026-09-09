import 'dart:async';

import 'package:app/src/features/conversation/application/composer_suggestions.dart';
import 'package:app/src/features/hosts/application/host_controller.dart';
import 'package:protocol/protocol.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'composer_controller.g.dart';

/// How long an `@` query rests before the daemon index is asked.
const Duration composerFileSearchDebounce = Duration(milliseconds: 120);

/// How long an idle empty-query result stays warm so reopening `@` is instant.
const Duration composerFileSearchKeepAlive = Duration(seconds: 30);

/// How long a failed queue release rests before it is tried again.
const Duration conversationDrainRetryDelay = Duration(milliseconds: 250);

/// Releases one queued prompt may be charged before it waits for the user.
///
/// The queue is released by session events, and the event that would have
/// released a prompt is often the last one coming. A bounded retry is what
/// keeps a prompt from waiting on an event that will never arrive, so the
/// bound has to be small enough to stay invisible and finite by construction.
const int conversationDrainMaxAttempts = 3;

@riverpod
/// Searches one worktree for the files an `@` query could mention.
///
/// The query is part of the provider key, so each keystroke creates a new
/// provider and disposes the previous one. Cancelling the timer on dispose is
/// therefore the debounce itself, with no controller state to keep in sync.
Future<List<FileMatchDto>> composerFileSearch(
  Ref ref,
  String hostId,
  String worktreeId,
  String query,
) async {
  await _debounce(ref, composerFileSearchDebounce);
  if (query.isEmpty) {
    final link = ref.keepAlive();
    final timer = Timer(composerFileSearchKeepAlive, link.close);
    ref.onDispose(timer.cancel);
  }
  final api = await requireHostApi(ref, hostId);
  final result = await api.workspaces.searchFiles(
    worktreeId: worktreeId,
    query: query,
  );
  return rankFileMatches(result.matches, query);
}

/// Waits [delay], or never completes when the provider is disposed first.
Future<void> _debounce(Ref ref, Duration delay) {
  final completer = Completer<void>();
  final timer = Timer(delay, () {
    if (!completer.isCompleted) completer.complete();
  });
  ref.onDispose(timer.cancel);
  return completer.future;
}

/// Agent and model chosen in the composer before a session exists.
final class SessionComposerDraft {
  /// Creates a composer draft.
  const new({
    this.agentDefinitionId,
    this.model,
    this.modelControls = const <String, ModelControlValueDto>{},
    this.permissionMode,
  });

  /// Explicitly chosen agent definition; null falls back to the first usable.
  final String? agentDefinitionId;

  /// Explicit chat model; null resolves through the agent and daemon defaults.
  final ModelSelectionDto? model;

  /// Explicit values for the selected provider model.
  final Map<String, ModelControlValueDto> modelControls;

  /// Permission mode chosen for the next session; null has not been touched
  /// yet and takes the host default the daemon is configured with.
  final PermissionMode? permissionMode;

  /// Returns a copy with the given fields replaced.
  ///
  /// Every nullable field takes a wrapper so passing an explicit null clears
  /// the override instead of being read as "leave unchanged".
  SessionComposerDraft copyWith({
    ({String? value})? agentDefinitionId,
    ({ModelSelectionDto? value})? model,
    Map<String, ModelControlValueDto>? modelControls,
    ({PermissionMode? value})? permissionMode,
  }) => SessionComposerDraft(
    agentDefinitionId: agentDefinitionId == null
        ? this.agentDefinitionId
        : agentDefinitionId.value,
    model: model == null ? this.model : model.value,
    modelControls: modelControls ?? this.modelControls,
    permissionMode: permissionMode == null
        ? this.permissionMode
        : permissionMode.value,
  );
}

@Riverpod(keepAlive: true)
/// Holds the composer selection used to create the next session.
class SessionComposerDraftController extends _$SessionComposerDraftController {
  @override
  SessionComposerDraft build(
    String hostId,
    String? worktreeId,
    String draftId,
  ) => const SessionComposerDraft();

  /// Chooses the agent definition and drops the overrides bound to the old
  /// agent, so the new definition supplies its own defaults.
  ///
  /// The permission mode survives: no agent definition declares one, so
  /// clearing it would throw away a deliberate choice and silently widen or
  /// narrow what the next session may do.
  void selectAgent(String agentDefinitionId) => state = state.copyWith(
    agentDefinitionId: (value: agentDefinitionId),
    model: (value: null),
    modelControls: const <String, ModelControlValueDto>{},
  );

  /// Chooses one concrete provider and model override.
  void selectModel(ModelSelectionDto model) => state = state.copyWith(
    model: (value: model),
    modelControls: const <String, ModelControlValueDto>{},
  );

  /// Replaces all values for the currently selected provider model.
  void selectModelControls(Map<String, ModelControlValueDto> controls) =>
      state = state.copyWith(modelControls: controls);

  /// Chooses the permission mode the next session is created with.
  void selectPermissionMode(PermissionMode permissionMode) =>
      state = state.copyWith(permissionMode: (value: permissionMode));
}
