import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'build_phase_provider_guard.dart';

/// A provider the controls below can mutate and invalidate at will.
final _counter = NotifierProvider<_Counter, int>(_Counter.new);

final class _Counter extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state = state + 1;
}

/// Rebuilds itself through Riverpod the ordinary way, mutating nothing itself.
class _OrdinaryRebuild extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Text('${ref.watch(_counter)}', textDirection: TextDirection.ltr);
}

/// Invalidates a provider from `didUpdateWidget`, i.e. inside the build phase.
class _MutatesDuringBuild extends ConsumerStatefulWidget {
  const new({required this.revision});

  final int revision;

  @override
  ConsumerState<_MutatesDuringBuild> createState() =>
      _MutatesDuringBuildState();
}

class _MutatesDuringBuildState extends ConsumerState<_MutatesDuringBuild> {
  @override
  void didUpdateWidget(_MutatesDuringBuild oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revision != oldWidget.revision) ref.invalidate(_counter);
  }

  @override
  Widget build(BuildContext context) =>
      Text('${ref.watch(_counter)}', textDirection: TextDirection.ltr);
}

/// Mounts [child] under [container] the way `ProviderScope` does internally.
///
/// `UncontrolledProviderScope` is deliberate rather than incidental: it is the
/// widget that drains Riverpod's scheduler from its own `build`, which is the
/// exact behaviour the exclusion under test has to keep telling apart from a
/// real violation.
Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container,
  Widget child,
) => tester.pumpWidget(
  UncontrolledProviderScope(
    container: container,
    child: Directionality(textDirection: TextDirection.ltr, child: child),
  ),
);

void main() {
  // These two are a matched pair and neither is optional.
  //
  // The guard ignores mutations whose stack contains
  // `_UncontrolledProviderScopeState._callTask`, because Riverpod drains its
  // own scheduled refreshes from inside its own `build`. That exclusion keys on
  // a private symbol of a pinned dependency, so it can fail in both directions:
  // if the symbol is renamed the guard floods every routed test with false
  // positives, and if Riverpod stops draining from build the exclusion silently
  // becomes over-broad and the guard stops catching anything at all. The
  // negative control catches the first; the positive control catches the
  // second. A guard with no positive control cannot be told apart from having
  // no guard at all.

  testWidgets('an ordinary Riverpod rebuild is not a violation', (
    tester,
  ) async {
    final guard = BuildPhaseProviderGuard();
    final container = ProviderContainer(observers: <ProviderObserver>[guard]);
    addTearDown(container.dispose);

    await _pump(tester, container, const _OrdinaryRebuild());
    container.read(_counter.notifier).increment();
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(guard.violations, isEmpty, reason: guard.report);
  });

  testWidgets('invalidating from didUpdateWidget is a violation', (
    tester,
  ) async {
    final guard = BuildPhaseProviderGuard();
    final container = ProviderContainer(observers: <ProviderObserver>[guard]);
    addTearDown(container.dispose);

    Future<void> pumpRevision(int revision) =>
        _pump(tester, container, _MutatesDuringBuild(revision: revision));

    await pumpRevision(1);
    expect(guard.violations, isEmpty, reason: 'nothing mutated yet');

    await pumpRevision(2);
    // The framework rejects this too; draining it keeps the guard's report as
    // the thing the test fails on.
    tester.takeException();

    expect(guard.violations, isNotEmpty);
    expect(guard.report, contains('didUpdateWidget'));
  });
}
