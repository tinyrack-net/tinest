import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks which providers a container currently holds an element for.
///
/// `ProviderContainer` exposes no public way to enumerate its live elements in
/// riverpod 3.3.2, and a lifetime redesign is exactly the kind of change whose
/// whole point is unobservable without one: "the session ended" and "the
/// session is still there" look identical from the widget tree. Observing the
/// add/dispose pair gives the same answer through public API.
final class ProviderLifetimeRecorder extends ProviderObserver {
  /// Creates a recorder that starts out knowing about nothing.
  new();

  final Set<Object> _live = <Object>{};

  /// Whether [provider] currently has an element in the observed container.
  bool isAlive(Object provider) => _live.contains(provider);

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) =>
      _live.add(context.provider);

  // `didUnmountProvider`, not `didDisposeProvider`. The latter fires whenever
  // `Ref.onDispose` listeners run, which includes every ordinary rebuild of a
  // provider, so tracking it would report a provider as gone while it is very
  // much still there. Only an unmount means the element left memory.
  @override
  void didUnmountProvider(ProviderObserverContext context) =>
      _live.remove(context.provider);
}
