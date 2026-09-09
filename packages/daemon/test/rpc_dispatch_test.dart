import 'package:daemon/src/transport/rpc/rpc_dispatch.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  test('every authenticated RPC method has one feature owner', () {
    expect(daemonRpcProcedureGroups.keys, <String>[
      'workspaces',
      'agents',
      'prompts',
      'models',
      'providers',
      'relay',
      'mcp',
      'plugins',
      'sessions',
      'terminals',
    ]);
    expect(
      daemonRpcProcedures.map((procedure) => procedure.name).toSet(),
      hasLength(daemonRpcProcedures.length),
    );
    expect(
      daemonRpcProcedureGroups['workspaces']?.map(
        (procedure) => procedure.name,
      ),
      containsAll(<String>[
        workspacesCatalogProcedure.name,
        workspacesCreateWorktreeProcedure.name,
      ]),
    );
    expect(
      daemonRpcProcedureGroups['sessions']?.map((procedure) => procedure.name),
      containsAll(<String>[
        sessionsCreateProcedure.name,
        sessionsStartTurnProcedure.name,
        sessionsResolveApprovalProcedure.name,
      ]),
    );
    expect(
      daemonRpcProcedureGroups['providers']?.map((procedure) => procedure.name),
      containsAll(<String>[
        providersCatalogProcedure.name,
        providersDeleteCustomProcedure.name,
      ]),
    );
  });
}
