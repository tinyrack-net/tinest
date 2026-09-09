import 'package:app/src/features/hosts/application/host_controller.dart';
import 'package:protocol/protocol.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'model_settings_controller.g.dart';

@Riverpod(retry: noAutomaticRetry)
/// Owns the daemon-global concrete default model for one connected host.
class ModelSettingsController extends _$ModelSettingsController {
  @override
  Future<DaemonModelSettingsDto> build(String hostId) async {
    final api = await requireHostApi(ref, hostId);
    return await api.models.getSettings();
  }

  /// Persists and exposes a concrete runnable daemon default.
  Future<void> setDefaultModel(ModelSelectionDto model) async {
    final previous = state;
    state = AsyncData<DaemonModelSettingsDto>(
      DaemonModelSettingsDto(defaultModel: model),
    );
    try {
      final api = await requireHostApi(ref, hostId);
      state = AsyncData<DaemonModelSettingsDto>(
        await api.models.setDefaultModel(model),
      );
    } on Object catch (error, stackTrace) {
      state = previous.hasValue
          ? AsyncData<DaemonModelSettingsDto>(previous.requireValue)
          : AsyncError<DaemonModelSettingsDto>(error, stackTrace);
      rethrow;
    }
  }
}
