import 'dart:async';

import 'package:agent/src/contracts.dart';
import 'package:agent/src/model.dart';

/// Receives a normalized event emitted while an agent harness runs a turn.
typedef AgentEventCallback = FutureOr<void> Function(
  String type,
  Map<String, dynamic> data,
);

/// Receives session status changes emitted by an agent harness.
typedef SessionStatusCallback = FutureOr<void> Function(
  AgentSessionStatus status, {
  String? error,
});

/// Persists provider-visible conversation items after each model boundary.
typedef ProviderItemsCallback = FutureOr<void> Function(
  List<ConversationItem> items,
);

/// Supplies externally queued conversation input at model boundaries.
abstract interface class TurnInputSource {
  /// Returns and consumes items queued for this session; empty when none.
  Future<List<ConversationItem>> drainPending();
}

/// Supplies the permission mode in effect at the next tool boundary.
abstract interface class PermissionModeSource {
  /// Returns the current effective permission mode.
  Future<AgentPermissionMode> currentMode();
}

/// Result returned after a harness completes a turn.
class AgentRunResult {
  /// Creates an immutable turn result.
  const new({required this.conversationItems, required this.toolRounds});

  /// Provider-visible conversation items produced by the turn.
  final List<ConversationItem> conversationItems;

  /// Number of tool execution rounds completed by the driver.
  final int toolRounds;
}
