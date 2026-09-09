import 'dart:async';
import 'dart:convert';

import 'package:daemon/src/shared/infrastructure/persistence/repositories.dart';
import 'package:protocol/protocol.dart';

/// Persistent key owned by the daemon model-settings feature.
const String daemonDefaultModelSettingKey = 'model.default';

/// Read-only catalog boundary used to resolve concrete runnable models.
abstract interface class RunnableModelCatalog {
  /// Emits whenever connection or model availability may have changed.
  Stream<void> get runnableModelChanges;

  /// Returns every runnable selection in the canonical picker order.
  Future<List<ModelSelectionDto>> listRunnableModels();
}

/// Stable model-settings failure exposed through RPC bindings.
final class ModelSettingsFailure implements Exception {
  /// Creates a model-settings failure.
  const new(this.code, this.message);

  /// Stable machine-readable failure code.
  final String code;

  /// User-safe failure message.
  final String message;

  @override
  String toString() => 'ModelSettingsFailure($code): $message';
}

/// Owns the single concrete daemon default model.
final class DaemonModelSettingsService {
  /// Creates daemon model settings over typed storage and catalog ports.
  factory({
    required SettingsRepository settings,
    required RunnableModelCatalog catalog,
  }) => DaemonModelSettingsService._(settings, catalog);

  new _(this._settings, this._catalog);

  final SettingsRepository _settings;
  final RunnableModelCatalog _catalog;
  StreamSubscription<void>? _catalogSubscription;
  Future<void> _settled = Future<void>.value();

  /// Completes after every currently queued initialization attempt.
  Future<void> get settled => _settled;

  /// Starts model-availability observation and initializes the default.
  Future<void> initialize() async {
    _catalogSubscription ??= _catalog.runnableModelChanges.listen((_) {
      unawaited(_queueInitialization());
    });
    await _queueInitialization();
  }

  /// Stops model-availability observation.
  Future<void> close() async {
    await _catalogSubscription?.cancel();
    await _settled;
  }

  /// Reads current settings after ensuring a first default when possible.
  Future<DaemonModelSettingsDto> getSettings() => _serialize(() async {
    await _initializeDefault();
    return DaemonModelSettingsDto(defaultModel: await _storedDefault());
  });

  /// Replaces the default with a concrete runnable selection.
  Future<DaemonModelSettingsDto> setDefaultModel(ModelSelectionDto model) =>
      _serialize(() async {
        await requireRunnable(model);
        await _write(model);
        return DaemonModelSettingsDto(defaultModel: model);
      });

  /// Returns the stored default only when it can currently run.
  Future<ModelSelectionDto> requireDefaultModel() => _serialize(() async {
    await _initializeDefault();
    final stored = await _storedDefault();
    if (stored == null) {
      throw const ModelSettingsFailure(
        'model_required',
        'No connected provider offers a usable model.',
      );
    }
    await requireRunnable(stored);
    return stored;
  });

  /// Rejects selections absent from the canonical runnable catalog.
  Future<void> requireRunnable(ModelSelectionDto model) async {
    final runnable = await _catalog.listRunnableModels();
    if (!runnable.contains(model)) {
      throw ModelSettingsFailure(
        'model_unavailable',
        'The configured model is unavailable: ${model.qualifiedModelId}',
      );
    }
  }

  /// Rewrites the persisted qualified model after a provider-prefix change.
  Future<void> rewriteModelPrefix(
    String oldPrefix,
    String newPrefix,
  ) => _serialize(() async {
    final stored = await _storedDefault();
    if (stored == null || !stored.qualifiedModelId.startsWith('$oldPrefix/')) {
      return;
    }
    await _write(
      ModelSelectionDto(
        modelId:
            '$newPrefix/${stored.qualifiedModelId.substring(oldPrefix.length + 1)}',
      ),
    );
  });

  Future<void> _queueInitialization() => _serialize(_initializeDefault);

  Future<T> _serialize<T>(Future<T> Function() action) {
    final run = _settled.then((_) => action());
    _settled = run.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return run;
  }

  Future<void> _initializeDefault() async {
    if (await _storedDefault() != null) return;
    final runnable = await _catalog.listRunnableModels();
    if (runnable.isEmpty) return;
    await _write(runnable.first);
  }

  Future<ModelSelectionDto?> _storedDefault() async {
    final raw = await _settings.getValue(daemonDefaultModelSettingKey);
    if (raw == null) return null;
    return ModelSelectionDto.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }

  Future<void> _write(ModelSelectionDto model) => _settings.setValue(
    daemonDefaultModelSettingKey,
    jsonEncode(model.toJson()),
  );
}
