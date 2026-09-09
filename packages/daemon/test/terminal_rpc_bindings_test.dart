import 'dart:async';

import 'package:daemon/src/features/terminals/application/terminal_screen.dart';
import 'package:daemon/src/features/terminals/application/terminal_service.dart';
import 'package:daemon/src/features/terminals/domain/terminal.dart';
import 'package:daemon/src/features/terminals/transport/rpc_bindings.dart';
import 'package:daemon/src/shared/infrastructure/persistence/repositories.dart';
import 'package:daemon/src/transport/rpc/binding.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  test(
    'terminal create maps expected application failures to stable RPC codes',
    () async {
      for (final reason in TerminalCreationFailureReason.values) {
        final service = TerminalService(
          gateway: _FailingGateway(reason),
          screens: const _UnusedScreenFactory(),
          worktreePath: (_) async => '/worktree',
          shellFor: (_) async => const TerminalShell(executable: '/bin/sh'),
        );
        final binding =
            terminalRpcBindings(
              terminals: service,
              settings: _MemorySettings(),
            ).singleWhere(
              (binding) =>
                  binding.procedure.name == terminalsCreateProcedure.name,
            );

        await expectLater(
          binding.invoke(
            const TerminalCreateParamsDto(
              id: 'terminal-1',
              worktreeId: 'worktree-1',
              title: 'Terminal 1',
              columns: 80,
              rows: 24,
            ).toJson(),
            RpcConnectionContext(),
          ),
          throwsA(
            isA<RpcFailureException>().having(
              (error) => error.code,
              'code',
              reason == TerminalCreationFailureReason.worktreeUnavailable
                  ? 'worktree_unavailable'
                  : 'terminal_start_failed',
            ),
          ),
        );
      }
    },
    tags: const <String>['feature_test__terminal_lifecycle__contract'],
  );
}

final class _FailingGateway implements TerminalGateway {
  const new(this.reason);

  final TerminalCreationFailureReason reason;

  @override
  Future<TerminalProcess> start({
    required TerminalShell shell,
    required String workingDirectory,
    required int columns,
    required int rows,
  }) => Future<TerminalProcess>.error(
    TerminalCreationException(reason, 'safe failure'),
  );
}

final class _MemorySettings implements SettingsRepository {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> getValue(String key) async => _values[key];

  @override
  Future<void> setValue(String key, String value) async {
    _values[key] = value;
  }
}

/// Creating a terminal fails before a screen is ever needed here.
final class _UnusedScreenFactory implements TerminalScreenFactory {
  const new();

  @override
  TerminalScreen create({
    required int columns,
    required int rows,
    required int scrollbackLines,
  }) => throw StateError('no terminal reaches a screen in this test');
}
