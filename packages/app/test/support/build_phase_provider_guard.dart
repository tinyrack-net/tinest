import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Records every provider mutation that happens while the tree is building.
///
/// Riverpod ends a provider's life in one of two ways, and only one of them is
/// safe mid-frame: `invalidate` schedules a refresh through `setState` on the
/// enclosing `UncontrolledProviderScope`, while an `autoDispose` teardown goes
/// through `Future.microtask`. A build-phase mutation therefore surfaces as
/// "setState() or markNeedsBuild() called during build" — but only in debug,
/// because the assertion behind it is debug-only. In a release build the same
/// code silently rewrites the graph mid-frame instead of failing loudly.
///
/// This observer makes the class of defect visible in tests regardless of the
/// debug-only assertion, and names the provider, which the framework error does
/// not: it can only point at `UncontrolledProviderScope`.
final class BuildPhaseProviderGuard extends ProviderObserver {
  /// Creates a guard with an empty [violations] log.
  new();

  /// Providers mutated during a build, in the order the mutations happened.
  ///
  /// Deliberately reported by a teardown assertion rather than thrown at the
  /// offending call. A throw from inside `build` reaches the test as a pending
  /// exception, and any test that legitimately calls `tester.takeException()`
  /// for its own reasons would swallow the enforcement failure silently. The
  /// call site is not lost by waiting: [stacks] keeps it.
  final List<String> violations = <String>[];

  final List<StackTrace> _stacks = <StackTrace>[];

  /// Where each entry of [violations] was recorded.
  List<StackTrace> get stacks => List<StackTrace>.unmodifiable(_stacks);

  /// The first violation with its call site, for a failure message.
  String get report => violations.isEmpty
      ? 'no build-phase provider mutation'
      : 'provider mutated during build — ${violations.first}\n${_stacks.first}';

  /// Whether the framework is between `buildScope` entry and exit.
  static bool get _building =>
      WidgetsBinding.instance.buildOwner?.debugBuilding ?? false;

  /// Whether the current mutation is Riverpod draining its own scheduled work.
  ///
  /// `UncontrolledProviderScope` flushes pending refreshes from inside its own
  /// `build`, so `debugBuilding` is true for every ordinary rebuild Riverpod
  /// performs. Those are by design. What this guard is looking for is the other
  /// shape: application code mutating the graph while some *other* widget is
  /// building, which is what schedules a `setState` the framework then rejects.
  static bool _isScopeDrainingItsOwnQueue(StackTrace stack) =>
      stack.toString().contains('_UncontrolledProviderScopeState._callTask');

  void _record(ProviderObserverContext context, String event) {
    if (!_building) return;
    final stack = StackTrace.current;
    if (_isScopeDrainingItsOwnQueue(stack)) return;
    violations.add('$event: ${context.provider.name ?? context.provider}');
    _stacks.add(stack);
  }

  // `didAddProvider` is deliberately not overridden. Creating a provider for
  // the first time because a widget `ref.watch`ed it during its own build is
  // legal, and is exactly why Riverpod skips its own assertion on a first
  // build.

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) => _record(context, 'updated');

  @override
  void didDisposeProvider(ProviderObserverContext context) =>
      _record(context, 'disposed');
}
