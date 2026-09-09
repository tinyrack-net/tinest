import 'dart:convert';

import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  test('Agent definition is the complete version 5 harness contract', () {
    const definition = AgentDefinitionDto(
      version: 5,
      id: 'tinest',
      name: 'Tinest',
      description: 'Coding agent',
      mode: AgentMode.primary,
      model: AgentModelSelectionDto(source: AgentModelSource.session),
      driverId: 'tinest.standard/driver',
      extensionIds: <String>['tinest.plan', 'tinest.goal'],
      toolIds: <String>['tinest.files/read_file', 'tinest.edit/apply_patch'],
      pluginSettings: <String, Map<String, dynamic>>{
        'tinest.plan': <String, dynamic>{'style': 'concise'},
      },
      callableAgentIds: <String>[],
      prompt: 'Work carefully.',
      contentHash: 'sha256',
      sourcePath: r'C:\config\v5\agents\tinest.md',
    );

    final decoded = AgentDefinitionDto.fromJson(
      jsonDecode(jsonEncode(definition)) as Map<String, dynamic>,
    );

    expect(decoded, definition);
    expect(decoded.driverId, 'tinest.standard/driver');
    expect(decoded.prompt, 'Work carefully.');
    expect(decoded.pluginSettings['tinest.plan'], <String, dynamic>{
      'style': 'concise',
    });
  }, tags: const <String>['feature_test__agent_harness__contract']);

  test(
    'plugin descriptors, revisions, diagnostics, grants, and UI round trip',
    () {
      const diagnostic = PluginDiagnosticDto(
        code: 'capability_expanded',
        message: 'Regrant network access.',
        severity: PluginDiagnosticSeverity.warning,
        path: 'PLUGIN.md',
        line: 4,
      );
      const contribution = PluginContributionDto(
        pluginId: 'acme.reader',
        id: 'acme.reader/read',
        kind: PluginContributionKind.tool,
        requiredCapabilities: <String>['workspace.read'],
        tool: AgentToolDefinitionDto(
          id: 'acme.reader/read',
          originPluginId: 'acme.reader',
          contributionId: 'read',
          name: 'read_file',
          description: 'Read a workspace file.',
          risk: ToolRisk.read,
          group: 'filesystem',
          kind: AgentToolKind.function,
          inputSchema: <String, dynamic>{
            'type': 'object',
            'properties': <String, dynamic>{
              'path': <String, dynamic>{'type': 'string'},
            },
          },
          outputSchema: <String, dynamic>{'type': 'string'},
          effects: <String>['filesystem.read'],
          presentation: <String, dynamic>{
            'group': 'filesystem',
            'icon': 'file',
          },
        ),
        metadata: <String, dynamic>{'handler': 'read_file'},
      );
      const revision = PluginRevisionDto(
        pluginId: 'acme.reader',
        contentHash: 'content-sha',
        manifestHash: 'manifest-sha',
        sdkAbiHash: 'sdk-abi-sha',
        executionRevisionHash: 'execution-sha',
        requestedCapabilities: <String>['workspace.read'],
      );
      const descriptor = PluginDescriptorDto(
        apiMajor: 5,
        id: 'acme.reader',
        version: '1.0.0',
        name: 'Reader',
        entrypoint: 'main.lua',
        source: PluginSource.user,
        sourcePath: r'C:\config\v5\plugins\acme.reader',
        requestedCapabilities: <String>['workspace.read'],
        revision: revision,
        contributions: <PluginContributionDto>[contribution],
        diagnostics: <PluginDiagnosticDto>[diagnostic],
      );
      const grant = AgentPluginGrantDto(
        agentId: 'tinest',
        pluginId: 'acme.reader',
        capability: 'workspace.read',
      );
      const document = PluginUiDocumentDto(
        id: 'status',
        pluginId: 'acme.reader',
        revisionHash: 'content-sha',
        slot: PluginUiSlot.conversationStatus,
        root: <String, dynamic>{'type': 'text', 'text': 'Ready'},
      );
      const action = PluginUiActionDto(
        documentId: 'status',
        actionId: 'refresh',
        data: true,
      );
      const renderRequest = PluginUiRenderParamsDto(
        agentId: 'tinest',
        pluginId: 'acme.reader',
        contributionId: 'acme.reader/status',
        slot: PluginUiSlot.conversationStatus,
        input: <String, dynamic>{'title': 'Ready'},
      );

      Map<String, dynamic> wire(Object value) =>
          jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

      expect(PluginDescriptorDto.fromJson(wire(descriptor)), descriptor);
      final tool = PluginDescriptorDto.fromJson(wire(descriptor))
          .contributions
          .single
          .tool!;
      expect(tool.originPluginId, 'acme.reader');
      expect(tool.contributionId, 'read');
      expect(tool.kind, AgentToolKind.function);
      expect(tool.inputSchema['type'], 'object');
      expect(tool.outputSchema, <String, dynamic>{'type': 'string'});
      expect(tool.effects, <String>['filesystem.read']);
      expect(tool.presentation['icon'], 'file');
      expect(AgentPluginGrantDto.fromJson(wire(grant)), grant);
      expect(PluginUiDocumentDto.fromJson(wire(document)), document);
      expect(PluginUiActionDto.fromJson(wire(action)), action);
      expect(
        PluginUiRenderParamsDto.fromJson(wire(renderRequest)),
        renderRequest,
      );
      expect(
        PluginRevisionDto.fromJson(wire(revision)).executionRevisionHash,
        'execution-sha',
      );
    },
    tags: const <String>[
      'feature_test__plugin_runtime__contract',
      'feature_test__plugin_permissions__contract',
      'feature_test__plugin_ui__contract',
      'feature_test__plugin_authoring__contract',
    ],
  );

  test(
    'v5 exposes typed plugin management and Agent grant procedures',
    () {
      expect(pluginsListProcedure.name, 'plugins.list');
      expect(pluginsGetProcedure.name, 'plugins.get');
      expect(pluginsValidateProcedure.name, 'plugins.validate');
      expect(pluginsReloadProcedure.name, 'plugins.reload');
      expect(pluginsScaffoldProcedure.name, 'plugins.scaffold');
      expect(pluginsForkProcedure.name, 'plugins.fork');
      expect(
        pluginsGetPluginAuthoringEnvironmentProcedure.name,
        'plugins.getPluginAuthoringEnvironment',
      );
      expect(
        pluginsSyncPluginAuthoringEnvironmentProcedure.name,
        'plugins.syncPluginAuthoringEnvironment',
      );
      expect(pluginsListGrantsProcedure.name, 'plugins.listGrants');
      expect(pluginsGrantProcedure.name, 'plugins.grant');
      expect(pluginsRevokeProcedure.name, 'plugins.revoke');
      expect(pluginsSetSecretProcedure.name, 'plugins.setSecret');
      expect(pluginsRemoveSecretProcedure.name, 'plugins.removeSecret');
      expect(pluginsRenderUiProcedure.name, 'plugins.renderUi');
      expect(pluginsDispatchUiActionProcedure.name, 'plugins.dispatchUiAction');
      expect(
        pluginsGetSessionControlProcedure.name,
        'plugins.getSessionControl',
      );
      expect(
        pluginsSetSessionControlProcedure.name,
        'plugins.setSessionControl',
      );
      expect(pluginsChangedNotification.name, 'plugins.changed');

      const grant = AgentPluginGrantDto(
        agentId: 'reviewer',
        pluginId: 'acme.reader',
        capability: 'workspace.read',
      );
      expect(
        PluginGrantParamsDto.fromJson(
          jsonDecode(jsonEncode(const PluginGrantParamsDto(grant: grant)))
              as Map<String, dynamic>,
        ).grant,
        grant,
      );
      const secret = PluginSecretSetParamsDto(
        agentId: 'reviewer',
        pluginId: 'acme.reader',
        name: 'API_TOKEN',
        value: 'never-return-this',
      );
      expect(
        pluginsSetSecretProcedure.encodeResult(const EmptyResultDto()),
        isNot(containsValue('never-return-this')),
      );
      expect(PluginSecretSetParamsDto.fromJson(secret.toJson()), secret);
      const fork = PluginForkParamsDto(
        sourceId: 'tinest.files',
        id: 'acme.files',
        name: 'Acme files',
      );
      expect(PluginForkParamsDto.fromJson(fork.toJson()), fork);

      const authoring = PluginAuthoringEnvironmentDto(
        pluginId: 'acme.reader',
        apiMajor: 5,
        sdkAbiHash: 'sdk-abi-sha',
        luaRuntimeVersion: '5.5.1',
        luaLanguageServerVersion: '3.18.2',
        pluginPath: r'C:\config\v5\plugins\acme.reader',
        sdkLibraryPath: r'C:\config\v5\plugin-sdk\api-5\sdk-abi-sha\library',
        configurationPath: r'C:\config\v5\plugins\acme.reader\.luarc.json',
        synchronized: true,
      );
      expect(
        PluginAuthoringEnvironmentResultDto.fromJson(
          jsonDecode(
            jsonEncode(
              const PluginAuthoringEnvironmentResultDto(environment: authoring),
            ),
          ) as Map<String, dynamic>,
        ).environment,
        authoring,
      );
    },
    tags: const <String>[
      'feature_test__plugin_management__contract',
      'feature_test__plugin_authoring__contract',
    ],
  );

  test(
    'plugin authoring and UI action procedures preserve their typed wire',
    () {
      Map<String, dynamic> wire(Map<String, dynamic> value) =>
          jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

      const authoringParams = PluginIdParamsDto(id: 'acme.reader');
      const authoringResult = PluginAuthoringEnvironmentResultDto(
        environment: PluginAuthoringEnvironmentDto(
          pluginId: 'acme.reader',
          apiMajor: 5,
          sdkAbiHash: 'sdk-abi-sha',
          luaRuntimeVersion: '5.5.1',
          luaLanguageServerVersion: '3.18.2',
          pluginPath: r'C:\config\v5\plugins\acme.reader',
          sdkLibraryPath: r'C:\config\v5\plugin-sdk\api-5\sdk-abi-sha\library',
          configurationPath: r'C:\config\v5\plugins\acme.reader\.luarc.json',
          synchronized: true,
        ),
      );

      final authoringParamsWire = wire(
        pluginsSyncPluginAuthoringEnvironmentProcedure.encodeParams(
          authoringParams,
        ),
      );
      final authoringResultWire = wire(
        pluginsSyncPluginAuthoringEnvironmentProcedure.encodeResult(
          authoringResult,
        ),
      );
      expect(authoringParamsWire, <String, dynamic>{'id': 'acme.reader'});
      expect(
        pluginsSyncPluginAuthoringEnvironmentProcedure.decodeParams(
          authoringParamsWire,
        ),
        authoringParams,
      );
      expect(
        pluginsSyncPluginAuthoringEnvironmentProcedure.decodeResult(
          authoringResultWire,
        ),
        authoringResult,
      );

      const actionParams = PluginUiActionParamsDto(
        agentId: 'reviewer',
        pluginId: 'acme.reader',
        action: PluginUiActionDto(
          documentId: 'settings',
          actionId: 'refresh',
          data: <String, dynamic>{'force': true},
        ),
      );
      const actionResult = PluginUiDocumentResultDto(
        document: PluginUiDocumentDto(
          id: 'settings',
          pluginId: 'acme.reader',
          revisionHash: 'execution-sha',
          slot: PluginUiSlot.agentSettings,
          root: <String, dynamic>{'type': 'text', 'text': 'Ready'},
        ),
      );

      final actionParamsWire = wire(
        pluginsDispatchUiActionProcedure.encodeParams(actionParams),
      );
      final actionResultWire = wire(
        pluginsDispatchUiActionProcedure.encodeResult(actionResult),
      );
      expect(
        pluginsDispatchUiActionProcedure.decodeParams(actionParamsWire),
        actionParams,
      );
      expect(
        pluginsDispatchUiActionProcedure.decodeResult(actionResultWire),
        actionResult,
      );
    },
    tags: const <String>[
      'feature_test__plugin_authoring__contract',
      'feature_test__plugin_ui__contract',
    ],
  );

  test('plugin UI rejections have a protocol-owned code', () {
    expect(RpcErrorCodes.all, contains(RpcErrorCodes.pluginUiRejected));
    expect(RpcErrorCodes.pluginUiRejected, 'plugin_ui_rejected');
  }, tags: const <String>['feature_test__plugin_ui__contract']);

  test(
    'session control values are typed session-owned durable JSON',
    () {
      const value = PluginSessionControlValueDto(
        sessionId: 'session-1',
        agentId: 'reviewer',
        pluginId: 'tinest.plan',
        contributionId: 'tinest.plan/mode',
        revisionHash: 'plan-revision',
        schema: <String, dynamic>{'type': 'boolean'},
        defaultValue: false,
        value: true,
      );
      const getParams = PluginSessionControlParamsDto(
        sessionId: 'session-1',
        pluginId: 'tinest.plan',
        contributionId: 'tinest.plan/mode',
      );
      const setParams = PluginSessionControlSetParamsDto(
        sessionId: 'session-1',
        pluginId: 'tinest.plan',
        contributionId: 'tinest.plan/mode',
        value: true,
      );

      Map<String, dynamic> wire(Object input) =>
          jsonDecode(jsonEncode(input)) as Map<String, dynamic>;

      expect(PluginSessionControlValueDto.fromJson(wire(value)), value);
      expect(
        PluginSessionControlParamsDto.fromJson(wire(getParams)),
        getParams,
      );
      expect(
        PluginSessionControlSetParamsDto.fromJson(wire(setParams)),
        setParams,
      );
      expect(
        PluginSessionControlResultDto.fromJson(
          wire(const PluginSessionControlResultDto(control: value)),
        ).control,
        value,
      );
    },
    tags: const <String>[
      'feature_test__plugin_runtime__contract',
      'feature_test__session_plan__contract',
    ],
  );
}
