import 'package:daemon/src/features/prompts/infrastructure/commands.dart';
import 'package:daemon/src/features/prompts/infrastructure/skills.dart';
import 'package:daemon/src/features/prompts/transport/rpc_bindings.dart';
import 'package:daemon/src/features/workspaces/infrastructure/workspace_service.dart';
import 'package:daemon/src/transport/rpc/binding.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  test(
    'skill list rejects scope combinations outside the wire contract',
    () async {
      final skills = SkillCatalogService(
        store: FileSkillStore(roots: const <SkillFiles>[]),
      );
      final commands = CommandService(globalSources: const <CommandFiles>[]);
      addTearDown(skills.close);
      addTearDown(commands.close);
      final binding =
          promptRpcBindings(
            skills: skills,
            commands: commands,
            workspaces: _UnusedWorkspaceCatalog(),
          ).singleWhere(
            (candidate) =>
                candidate.procedure.name == promptsListSkillsProcedure.name,
          );

      for (final request in const <SkillListParamsDto>[
        SkillListParamsDto(
          view: SkillListView.global,
          workspaceId: 'workspace',
        ),
        SkillListParamsDto(view: SkillListView.project),
      ]) {
        await expectLater(
          binding.invoke(request.toJson(), RpcConnectionContext()),
          throwsA(
            isA<RpcFailureException>().having(
              (error) => error.code,
              'code',
              RpcErrorCodes.invalidParams,
            ),
          ),
        );
      }
    },
    tags: const <String>['feature_test__skill_catalog__contract'],
  );
}

final class _UnusedWorkspaceCatalog extends Mock
    implements WorkspaceCatalogPort;
