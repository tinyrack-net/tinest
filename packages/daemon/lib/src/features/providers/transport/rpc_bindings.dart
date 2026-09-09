import 'package:daemon/src/features/agents/infrastructure/agent_definitions.dart';
import 'package:daemon/src/features/providers/infrastructure/provider_auth.dart';
import 'package:daemon/src/features/providers/infrastructure/provider_service.dart';
import 'package:daemon/src/features/providers/infrastructure/provider_usage_service.dart';
import 'package:daemon/src/transport/rpc/binding.dart';
import 'package:protocol/protocol.dart';

/// Builds the provider feature's complete v5 RPC surface.
List<RpcBindingDescriptor> providerRpcBindings({
  required ProviderConnectionService providers,
  required ProviderUsageService usage,
  required ProviderAuthCoordinator auth,
  required AgentDefinitionService agentDefinitions,
}) {
  Future<R> exposeFailure<R>(Future<R> Function() action) async {
    try {
      return await action();
    } on ProviderConnectionFailure catch (error) {
      throw RpcFailureException(code: error.code, message: error.message);
    }
  }

  return <RpcBindingDescriptor>[
    RpcBinding(providersCatalogProcedure, (_, _) async {
      return ProviderCatalogResultDto(catalog: await providers.catalog());
    }),
    RpcBinding(providersListConnectionsProcedure, (_, _) async {
      return ProviderConnectionsResultDto(
        connections: await providers.connections(),
      );
    }),
    RpcBinding(providersListUsageProcedure, (_, _) async {
      return ProviderUsageResultDto(usage: await usage.listUsage());
    }),
    RpcBinding(providersConnectApiKeyProcedure, (request, _) async {
      return ProviderConnectionResultDto(
        connection: await exposeFailure(
          () => providers.connectApiKey(
            request.definitionId,
            request.apiKey,
            connectionId: request.connectionId,
            modelPrefix: request.modelPrefix,
          ),
        ),
      );
    }),
    RpcBinding(providersConnectNoneProcedure, (request, _) async {
      return ProviderConnectionResultDto(
        connection: await exposeFailure(
          () => providers.connectNone(
            request.definitionId,
            connectionId: request.connectionId,
            modelPrefix: request.modelPrefix,
          ),
        ),
      );
    }),
    RpcBinding(providersStartAuthProcedure, (request, _) async {
      return ProviderAuthAttemptResultDto(
        attempt: await exposeFailure(
          () => auth.start(
            definitionId: request.definitionId,
            methodId: request.methodId,
            connectionId: request.connectionId,
            modelPrefix: request.modelPrefix,
          ),
        ),
      );
    }),
    RpcBinding(providersGetAuthProcedure, (request, _) async {
      return ProviderAuthAttemptResultDto(
        attempt: await auth.status(request.attemptId),
      );
    }),
    RpcBinding(providersCancelAuthProcedure, (request, _) async {
      await auth.cancel(request.attemptId);
      return const EmptyResultDto();
    }),
    RpcBinding(providersDisconnectProcedure, (request, _) async {
      await providers.disconnect(request.connectionId);
      return const EmptyResultDto();
    }),
    RpcBinding(providersUpdateModelPrefixProcedure, (request, _) async {
      return ProviderConnectionResultDto(
        connection: await exposeFailure(
          () => providers.updateModelPrefix(
            request.connectionId,
            request.modelPrefix,
          ),
        ),
      );
    }),
    RpcBinding(providersRefreshCatalogProcedure, (_, _) async {
      return ProviderCatalogResultDto(
        catalog: await providers.refreshCatalog(),
      );
    }),
    RpcBinding(providersListModelsProcedure, (request, _) async {
      return ProviderModelsResultDto(
        models: await exposeFailure(
          () => providers.listModels(request.connectionId),
        ),
      );
    }),
    RpcBinding(providersCreateCustomProcedure, (request, _) async {
      return ProviderConnectionResultDto(
        connection: await exposeFailure(
          () => providers.createCustom(
            request.id,
            request.config,
            apiKey: request.apiKey,
            modelPrefix: request.modelPrefix,
          ),
        ),
      );
    }),
    RpcBinding(providersUpdateCustomProcedure, (request, _) async {
      return ProviderConnectionResultDto(
        connection: await exposeFailure(
          () => providers.updateCustom(
            request.connectionId,
            request.config,
            apiKey: request.apiKey,
          ),
        ),
      );
    }),
    RpcBinding(providersDeleteCustomProcedure, (request, _) async {
      final connection = await providers.get(request.connectionId);
      if (await agentDefinitions.referencesProvider(connection.modelPrefix)) {
        throw const FormatException(
          'Provider connection is referenced by an agent definition.',
        );
      }
      await exposeFailure(() => providers.deleteCustom(request.connectionId));
      return const EmptyResultDto();
    }),
  ];
}
