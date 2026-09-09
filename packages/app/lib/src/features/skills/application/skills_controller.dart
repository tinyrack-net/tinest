import 'dart:async';

import 'package:app/src/features/hosts/application/host_controller.dart';
import 'package:protocol/protocol.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'skills_controller.g.dart';

@Riverpod(retry: noAutomaticRetry)
/// Loads one read-only view of the effective skills a daemon offers.
class SkillsController extends _$SkillsController {
  StreamSubscription<void>? _events;

  @override
  Future<List<SkillSummaryDto>> build(
    String hostId,
    SkillListView view,
    String? workspaceId,
  ) async {
    final api = await watchHostApi(ref, hostId);
    _events = api.prompts.skillChanges.listen((_) => unawaited(refresh()));
    ref.onDispose(() => unawaited(_events?.cancel()));
    return await api.prompts.listSkills(view: view, workspaceId: workspaceId);
  }

  /// Reloads the catalog from the daemon.
  Future<void> refresh() async {
    try {
      final api = await requireHostApi(ref, hostId);
      final skills = await api.prompts.listSkills(
        view: view,
        workspaceId: workspaceId,
      );
      if (!ref.mounted) return;
      state = AsyncData<List<SkillSummaryDto>>(skills);
    } on Object catch (error, stackTrace) {
      if (!ref.mounted) return;
      // Riverpod preserves the previous data when an AsyncNotifier transitions
      // to this error, allowing SettingsAsyncContent to keep the catalog below
      // its refresh alert instead of replacing it with a blocking error.
      state = AsyncError<List<SkillSummaryDto>>(error, stackTrace);
    }
  }
}
