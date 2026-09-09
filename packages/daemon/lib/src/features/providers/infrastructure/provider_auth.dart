import 'dart:async';

import 'package:agent/agent.dart';
import 'package:daemon/src/shared/ports/daemon_ports.dart';
import 'package:protocol/protocol.dart';

// The OAuth port types moved to the vendor-neutral port layer so a vendor
// package can implement its own gateway; daemon consumers keep this path.
export 'package:agent/agent.dart'
    show
        OAuthAuthorizationFailure,
        OAuthRefreshFailure,
        ProviderOAuthGateway,
        ProviderOAuthSession;

/// Refreshes one connection credential while preserving token rotation.
abstract interface class ProviderCredentialRefresher {
  /// Returns a fresh credential for one connection.
  Future<OAuthCredential> refresh(
    String connectionId,
    String definitionId,
    OAuthCredential credential,
  );
}

/// Identity reserved before an OAuth browser or device flow starts.
typedef ProviderOAuthReservation = ({String connectionId, String modelPrefix});

/// Connects a successfully authorized OAuth credential to a provider.
abstract interface class ProviderOAuthConnector {
  /// Atomically reserves a unique connection ID and model prefix.
  Future<ProviderOAuthReservation> reserveOAuthConnection(
    String definitionId, {
    String? connectionId,
    String? modelPrefix,
  });

  /// Releases a reservation that did not become a connection.
  Future<void> releaseOAuthConnection(String connectionId);

  /// Stores and activates one OAuth-backed provider connection.
  Future<void> connectOAuth(
    String definitionId,
    OAuthCredential credential, {
    String? connectionId,
    String? modelPrefix,
  });
}

/// Coordinates transient OAuth state without persisting authorization attempts.
final class ProviderAuthCoordinator {
  /// Creates an authorization coordinator from typed ports.
  factory({
    required ProviderRegistry registry,
    required ProviderOAuthConnector connector,
    required IdGenerator ids,
  }) => ProviderAuthCoordinator._(
    registry: registry,
    connector: connector,
    ids: ids,
  );

  new _({
    required this._registry,
    required this._connector,
    required this._ids,
  });

  final ProviderRegistry _registry;
  final ProviderOAuthConnector _connector;
  final IdGenerator _ids;
  final Map<String, _PendingAuth> _attempts = <String, _PendingAuth>{};
  final StreamController<ProviderAuthAttemptDto> _events =
      StreamController<ProviderAuthAttemptDto>.broadcast(sync: true);

  /// Authorization attempt updates safe to broadcast to clients.
  Stream<ProviderAuthAttemptDto> get events => _events.stream;

  /// Starts one vendor's browser or device-code OAuth flow.
  Future<ProviderAuthAttemptDto> start({
    required String definitionId,
    required String methodId,
    String? connectionId,
    String? modelPrefix,
  }) async {
    final plugin = _registry.require(definitionId);
    final gateway = plugin.oauth;
    if (gateway == null) {
      throw StateError('$definitionId does not support OAuth.');
    }
    // The definition already names each method's flow, so the coordinator
    // never has to know what a vendor called its buttons.
    final method = plugin.definition.authMethods
        .where((candidate) => candidate.id == methodId)
        .firstOrNull;
    final flow = method?.flow;
    if (flow != AgentProviderAuthFlow.oauthBrowser &&
        flow != AgentProviderAuthFlow.oauthDevice) {
      throw StateError('Unknown $definitionId OAuth method: $methodId');
    }
    final reservation = await _connector.reserveOAuthConnection(
      definitionId,
      connectionId: connectionId,
      modelPrefix: modelPrefix,
    );
    late final ProviderOAuthSession session;
    try {
      session = await gateway.start(flow!);
    } catch (_) {
      await _connector.releaseOAuthConnection(reservation.connectionId);
      rethrow;
    }
    final attempt = ProviderAuthAttemptDto(
      id: _ids.generate(),
      definitionId: definitionId,
      methodId: methodId,
      connectionId: reservation.connectionId,
      modelPrefix: reservation.modelPrefix,
      status: ProviderAuthAttemptStatus.awaitingUser,
      authorizationUrl: session.authorizationUrl,
      userCode: session.userCode,
      instructions: session.instructions,
      expiresAt: session.expiresAt,
    );
    final pending = _PendingAuth(attempt: attempt, session: session);
    _attempts[attempt.id] = pending;
    _events.add(attempt);
    unawaited(_complete(pending));
    return attempt;
  }

  /// Returns the current state of one authorization attempt.
  Future<ProviderAuthAttemptDto> status(String attemptId) async {
    final pending = _attempts[attemptId];
    if (pending == null) {
      throw StateError('Provider authorization attempt not found: $attemptId');
    }
    return pending.attempt;
  }

  /// Cancels one pending authorization attempt.
  Future<void> cancel(String attemptId) async {
    final pending = _attempts[attemptId];
    if (pending == null) {
      throw StateError('Provider authorization attempt not found: $attemptId');
    }
    if (_isTerminal(pending.attempt.status)) return;
    pending.attempt = pending.attempt.copyWith(
      status: ProviderAuthAttemptStatus.cancelled,
    );
    await pending.session.cancel();
    await _connector.releaseOAuthConnection(pending.attempt.connectionId);
    _events.add(pending.attempt);
  }

  Future<void> _complete(_PendingAuth pending) async {
    try {
      final credential = await pending.session.completion;
      if (pending.attempt.status == ProviderAuthAttemptStatus.cancelled) return;
      pending.attempt = pending.attempt.copyWith(
        status: ProviderAuthAttemptStatus.exchanging,
      );
      _events.add(pending.attempt);
      await _connector.connectOAuth(
        pending.attempt.definitionId,
        credential,
        connectionId: pending.attempt.connectionId,
        modelPrefix: pending.attempt.modelPrefix,
      );
      pending.attempt = pending.attempt.copyWith(
        status: ProviderAuthAttemptStatus.succeeded,
      );
    } on TimeoutException catch (error) {
      if (pending.attempt.status == ProviderAuthAttemptStatus.cancelled) return;
      pending.attempt = pending.attempt.copyWith(
        status: ProviderAuthAttemptStatus.expired,
        error: '$error',
      );
      await _connector.releaseOAuthConnection(pending.attempt.connectionId);
    } on Exception catch (error) {
      if (pending.attempt.status == ProviderAuthAttemptStatus.cancelled) return;
      pending.attempt = pending.attempt.copyWith(
        status: ProviderAuthAttemptStatus.failed,
        error: '$error',
      );
      await _connector.releaseOAuthConnection(pending.attempt.connectionId);
    }
    _events.add(pending.attempt);
  }

  /// Cancels active sessions and closes the update stream.
  Future<void> close() async {
    for (final pending in _attempts.values) {
      if (!_isTerminal(pending.attempt.status)) await pending.session.cancel();
      if (!_isTerminal(pending.attempt.status)) {
        await _connector.releaseOAuthConnection(pending.attempt.connectionId);
      }
    }
    await _events.close();
  }

  static bool _isTerminal(ProviderAuthAttemptStatus status) =>
      status == ProviderAuthAttemptStatus.succeeded ||
      status == ProviderAuthAttemptStatus.failed ||
      status == ProviderAuthAttemptStatus.cancelled ||
      status == ProviderAuthAttemptStatus.expired;
}

/// Deduplicates concurrent refreshes because vendors rotate refresh tokens.
final class OAuthCredentialRefresher implements ProviderCredentialRefresher {
  /// Creates a single-flight token refresher over the registered vendors.
  factory({required ProviderRegistry registry}) =>
      OAuthCredentialRefresher._(registry);

  new _(this._registry);

  final ProviderRegistry _registry;
  final Map<String, Future<OAuthCredential>> _inFlight =
      <String, Future<OAuthCredential>>{};

  /// Refreshes at most once concurrently for each provider connection.
  @override
  Future<OAuthCredential> refresh(
    String connectionId,
    String definitionId,
    OAuthCredential credential,
  ) {
    final existing = _inFlight[connectionId];
    if (existing != null) return existing;
    // Only built-in vendors authenticate over OAuth, and a built-in
    // connection's id is its definition id, so the lookup needs no join.
    final gateway = _registry.find(definitionId)?.oauth;
    if (gateway == null) {
      throw StateError('$definitionId does not support OAuth refresh.');
    }
    final operation = gateway.refresh(credential);
    _inFlight[connectionId] = operation;
    unawaited(
      operation.then<void>(
        (_) {
          final _ = _inFlight.remove(connectionId);
        },
        onError: (Object _, StackTrace _) {
          final _ = _inFlight.remove(connectionId);
        },
      ),
    );
    return operation;
  }
}

final class _PendingAuth {
  new({required this.attempt, required this.session});

  ProviderAuthAttemptDto attempt;
  final ProviderOAuthSession session;
}
