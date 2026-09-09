import 'package:daemon/src/features/providers/infrastructure/provider_service.dart';
import 'package:daemon/src/shared/infrastructure/persistence/repositories.dart';
import 'package:daemon/src/transport/rpc/binding.dart';
import 'package:protocol/protocol.dart';

/// Reports a settings change refused because the session's turn is running.
///
/// Typed rather than a bare [StateError] so the transport can answer with a
/// code the client can translate. An escaping [StateError] would arrive as
/// `internal_error`, which the protocol defines as a defect and the app shows
/// as an unexplained daemon failure, even though refusing the change is the
/// intended behavior and the user only has to wait for the turn.
final class SessionTurnActiveFailure implements Exception {
  /// Reports the [setting] that could not move on [sessionId].
  const new({required this.sessionId, required this.setting});

  /// Session whose turn is still running.
  final String sessionId;

  /// Name of the refused setting, used for diagnostics.
  final String setting;

  /// Diagnostic description; clients translate the protocol code instead.
  String get message => 'Cannot change the $setting while a turn is running.';

  @override
  String toString() => 'SessionTurnActiveFailure($sessionId): $message';
}

/// Session preference mutations exposed to the daemon transport.
abstract interface class SessionSettingsPort {
  /// Applies an atomic nullable patch to one session.
  Future<SessionDto> updateSettings(
    String sessionId,
    SessionSettingsPatchDto patch,
  );

  /// Sets the permission mode observed at tool boundaries.
  Future<SessionDto> setPermissionMode(
    String sessionId,
    PermissionMode permissionMode,
  );

  /// Sets or clears the provider and model override used by future turns.
  Future<SessionDto> setModel(String sessionId, ModelSelectionDto? model);
}

/// Applies session settings while enforcing live-turn constraints.
final class SessionSettingsService implements SessionSettingsPort {
  /// Creates the session settings application service.
  const new({
    required SessionRepository sessions,
    required ProviderModelResolver models,
    required bool Function(String sessionId) hasActiveTurn,
    required void Function(OutboundNotification event) events,
  }) : this._(sessions, models, hasActiveTurn, events);

  const new _(this._sessions, this._models, this._hasActiveTurn, this._events);

  final SessionRepository _sessions;
  final ProviderModelResolver _models;
  final bool Function(String sessionId) _hasActiveTurn;
  final void Function(OutboundNotification event) _events;

  @override
  Future<SessionDto> updateSettings(
    String sessionId,
    SessionSettingsPatchDto patch,
  ) async {
    await _requireSession(sessionId);
    final changesIdleSettings = patch.hasModel || patch.hasModelControls;
    if (changesIdleSettings) _requireIdle(sessionId, 'settings');
    if (patch.hasModel && patch.model != null) {
      await _models.validateQualifiedModel(patch.model!.qualifiedModelId);
    }

    var session = (await _sessions.getById(sessionId))!;
    final targetModel = patch.hasModel ? patch.model : session.model;
    var targetControls = patch.hasModelControls
        ? patch.modelControls
        : session.modelControls;
    if (targetModel == null) {
      if (patch.hasModelControls && targetControls.isNotEmpty) {
        throw const FormatException(
          'Model controls require an explicit provider model.',
        );
      }
      targetControls = const <String, ModelControlValueDto>{};
    } else if (patch.hasModelControls) {
      await _models.validateQualifiedModelControls(
        targetModel.qualifiedModelId,
        targetControls,
      );
    } else if (patch.hasModel) {
      targetControls = await _models.retainValidQualifiedModelControls(
        targetModel.qualifiedModelId,
        targetControls,
      );
    }
    if (patch.hasModel || patch.hasModelControls) {
      session = await _sessions.updateModelSettings(
        sessionId,
        hasModel: patch.hasModel,
        model: patch.model,
        modelControls: targetControls,
      );
    }
    if (patch.permissionMode case final mode?) {
      session = await _sessions.updatePermissionMode(sessionId, mode);
    }
    return _emit(session);
  }

  @override
  Future<SessionDto> setPermissionMode(
    String sessionId,
    PermissionMode permissionMode,
  ) async {
    await _requireSession(sessionId);
    return _emit(
      await _sessions.updatePermissionMode(sessionId, permissionMode),
    );
  }

  @override
  Future<SessionDto> setModel(
    String sessionId,
    ModelSelectionDto? model,
  ) async {
    await _requireSession(sessionId);
    _requireIdle(sessionId, 'model');
    if (model != null) {
      await _models.validateQualifiedModel(model.qualifiedModelId);
    }
    final current = (await _sessions.getById(sessionId))!;
    final controls = model == null
        ? const <String, ModelControlValueDto>{}
        : await _models.retainValidQualifiedModelControls(
            model.qualifiedModelId,
            current.modelControls,
          );
    return _emit(
      await _sessions.updateModelSettings(
        sessionId,
        hasModel: true,
        model: model,
        modelControls: controls,
      ),
    );
  }

  Future<void> _requireSession(String sessionId) async {
    if (await _sessions.getById(sessionId) == null) {
      throw StateError('Session not found: $sessionId');
    }
  }

  void _requireIdle(String sessionId, String setting) {
    if (_hasActiveTurn(sessionId)) {
      throw SessionTurnActiveFailure(sessionId: sessionId, setting: setting);
    }
  }

  SessionDto _emit(SessionDto session) {
    _events(OutboundNotification(sessionsUpdatedNotification, session));
    return session;
  }
}
