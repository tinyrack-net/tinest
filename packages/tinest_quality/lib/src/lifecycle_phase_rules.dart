import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// One call found inside a widget lifecycle method's synchronous region.
final class LifecyclePhaseCall {
  /// Creates a finding.
  const new({
    required this.member,
    required this.lifecycle,
    required this.offset,
  });

  /// Name of the invoked member, for instance `invalidate`.
  final String member;

  /// Lifecycle method the call is reachable from.
  final String lifecycle;

  /// Character offset of the call in the source.
  final int offset;
}

/// Widget lifecycle methods, all of which the framework runs mid-frame.
const Set<String> _lifecycleMethods = <String>{
  'build',
  'initState',
  'didUpdateWidget',
  'didChangeDependencies',
  'dispose',
  'activate',
  'deactivate',
};

const Set<String> _widgetSupertypes = <String>{
  'State',
  'ConsumerState',
  'StatelessWidget',
  'StatefulWidget',
  'ConsumerWidget',
  'ConsumerStatefulWidget',
  'HookWidget',
  'HookConsumerWidget',
};

/// Finds calls to [members] reachable synchronously from a lifecycle method.
///
/// "Synchronously reachable" is the whole point, and is why this cannot be a
/// line match. All four of these sit inside a lifecycle method and none of them
/// runs during the build:
///
/// * `onPressed: () => ref.invalidate(p)` — a closure, run on a tap.
/// * `WidgetsBinding.instance.addPostFrameCallback((_) => ...)` — next frame.
/// * `ref.listen(p, _handler)` — a tear-off, not a call.
/// * anything after the first `await` in an `async` body — a later microtask.
///
/// while `didUpdateWidget` calling a private helper that invalidates does run
/// during the build, in a different method and possibly several hops away.
List<LifecyclePhaseCall> findLifecyclePhaseCalls({
  required String source,
  required Set<String> members,
}) {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  final findings = <LifecyclePhaseCall>[];
  for (final declaration in unit.declarations) {
    if (declaration is! ClassDeclaration) continue;
    if (!_isWidgetLike(declaration)) continue;
    final methods = <String, MethodDeclaration>{
      for (final member in declaration.body.members)
        if (member is MethodDeclaration) member.name.lexeme: member,
    };
    for (final entry in methods.entries) {
      if (!_lifecycleMethods.contains(entry.key)) continue;
      findings.addAll(
        _walk(
          method: entry.value,
          lifecycle: entry.key,
          methods: methods,
          members: members,
          visited: <String>{entry.key},
        ),
      );
    }
  }
  return findings;
}

bool _isWidgetLike(ClassDeclaration declaration) {
  final supertype = declaration.extendsClause?.superclass.name.lexeme;
  if (supertype == null) return false;
  // `_$Foo`-style generated bases never appear on widgets, and the concrete
  // widget bases are generic (`State<Foo>`), so the raw name is enough.
  return _widgetSupertypes.contains(supertype);
}

Iterable<LifecyclePhaseCall> _walk({
  required MethodDeclaration method,
  required String lifecycle,
  required Map<String, MethodDeclaration> methods,
  required Set<String> members,
  required Set<String> visited,
}) {
  final collector = _SynchronousRegionCollector();
  method.body.accept(collector);
  final findings = <LifecyclePhaseCall>[];
  for (final invocation in collector.invocations) {
    final name = invocation.methodName.name;
    if (members.contains(name)) {
      findings.add(
        LifecyclePhaseCall(
          member: name,
          lifecycle: lifecycle,
          offset: invocation.offset,
        ),
      );
      continue;
    }
    // A call to another member of the same class extends the region: the crash
    // this rule exists for was two hops from the lifecycle method.
    final target = invocation.target;
    final isOwnMember = target == null || target is ThisExpression;
    if (!isOwnMember || visited.contains(name)) continue;
    final callee = methods[name];
    if (callee == null) continue;
    findings.addAll(
      _walk(
        method: callee,
        lifecycle: lifecycle,
        methods: methods,
        members: members,
        visited: <String>{...visited, name},
      ),
    );
  }
  return findings;
}

/// Collects invocations that run before the method yields or defers.
final class _SynchronousRegionCollector extends UnifyingAstVisitor<void> {
  final List<MethodInvocation> invocations = <MethodInvocation>[];
  bool _yielded = false;

  @override
  void visitNode(AstNode node) {
    if (_yielded) return;
    // Everything inside a closure runs when the closure is called, which is by
    // definition not now. Not descending is what makes `onPressed:` and
    // `addPostFrameCallback` legal without naming either of them.
    if (node is FunctionExpression) return;
    if (node is AwaitExpression) {
      _yielded = true;
      return;
    }
    if (node is MethodInvocation) invocations.add(node);
    node.visitChildren(this);
  }
}
