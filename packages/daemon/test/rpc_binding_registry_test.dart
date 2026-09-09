import 'package:daemon/src/transport/rpc/binding.dart';
import 'package:daemon/src/transport/rpc/rpc_dispatch.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  test('daemon bindings implement the descriptor catalog exactly once', () {
    final registry = RpcBindingRegistry(
      daemonRpcProcedures.map(_StubBinding.new),
      procedures: daemonRpcProcedures,
    );

    expect(
      registry.procedures.map((procedure) => procedure.name),
      daemonRpcProcedures.map((procedure) => procedure.name),
    );
  });

  test('daemon binding registry rejects missing and duplicate procedures', () {
    expect(
      () => RpcBindingRegistry(
        daemonRpcProcedures.skip(1).map(_StubBinding.new),
        procedures: daemonRpcProcedures,
      ),
      throwsStateError,
    );
    expect(
      () => RpcBindingRegistry(<RpcBindingDescriptor>[
        ...daemonRpcProcedures.map(_StubBinding.new),
        _StubBinding(daemonRpcProcedures.first),
      ], procedures: daemonRpcProcedures),
      throwsStateError,
    );
  });
}

final class _StubBinding implements RpcBindingDescriptor {
  const new(this.procedure);

  @override
  final RpcProcedureDescriptor procedure;

  @override
  Future<Map<String, dynamic>> invoke(
    Map<String, dynamic> params,
    RpcConnectionContext context,
  ) async => const <String, dynamic>{};
}
