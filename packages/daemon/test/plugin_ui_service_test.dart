import 'dart:async';
import 'dart:convert';

import 'package:daemon/src/features/plugins/infrastructure/plugin_bundles.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_ui_service.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_runtime.dart';
import 'package:daemon/src/features/plugins/transport/rpc_bindings.dart';
import 'package:daemon/src/transport/rpc/binding.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  group('plugin UI RPC failures', () {
    RpcBindingDescriptor binding(
      PluginUiService service,
      RpcProcedureDescriptor procedure,
    ) => pluginUiRpcBindings(ui: service)
        .singleWhere((candidate) => candidate.procedure.name == procedure.name);

    test('render exposes a stable sanitized document failure', () async {
      final service = PluginUiService(
        descriptors: _DescriptorReader(_uiDescriptor()),
        runtime: const _RejectingUiRuntime(rejectRender: true),
      );

      await expectLater(
        binding(service, pluginsRenderUiProcedure).invoke(
          const PluginUiRenderParamsDto(
            agentId: 'agent',
            pluginId: 'example.ui',
            contributionId: 'card',
            slot: PluginUiSlot.timeline,
          ).toJson(),
          RpcConnectionContext(),
        ),
        throwsA(
          isA<RpcFailureException>()
              .having(
                (error) => error.code,
                'code',
                RpcErrorCodes.pluginUiRejected,
              )
              .having(
                (error) => error.message,
                'message',
                'Plugin UI handler failed: '
                    'UI callback must return a Tinest UI node.',
              ),
        ),
      );
    }, tags: const <String>['feature_test__plugin_ui__contract']);

    test('dispatch exposes a stable sanitized document failure', () async {
      final service = PluginUiService(
        descriptors: _DescriptorReader(_uiDescriptor()),
        runtime: const _RejectingUiRuntime(),
      );
      final document = await service.render(
        const PluginUiRenderParamsDto(
          agentId: 'agent',
          pluginId: 'example.ui',
          contributionId: 'card',
          slot: PluginUiSlot.timeline,
        ),
      );

      await expectLater(
        binding(service, pluginsDispatchUiActionProcedure).invoke(
          jsonDecode(
            jsonEncode(
              PluginUiActionParamsDto(
                agentId: 'agent',
                pluginId: 'example.ui',
                action: PluginUiActionDto(
                  documentId: document.id,
                  actionId: 'refresh',
                ),
              ),
            ),
          ) as Map<String, dynamic>,
          RpcConnectionContext(),
        ),
        throwsA(
          isA<RpcFailureException>()
              .having(
                (error) => error.code,
                'code',
                RpcErrorCodes.pluginUiRejected,
              )
              .having(
                (error) => error.message,
                'message',
                'Plugin UI action failed: '
                    'UI action callback must return a Tinest UI node.',
              ),
        ),
      );
    }, tags: const <String>['feature_test__plugin_ui__contract']);

    test('render replaces an empty sanitized runtime failure', () async {
      final service = PluginUiService(
        descriptors: _DescriptorReader(_uiDescriptor()),
        runtime: const _RejectingUiRuntime(
          rejectRender: true,
          renderFailure: 'bundle/tinest.plugin_main.lua:42:',
        ),
      );

      await expectLater(
        binding(service, pluginsRenderUiProcedure).invoke(
          const PluginUiRenderParamsDto(
            agentId: 'agent',
            pluginId: 'example.ui',
            contributionId: 'card',
            slot: PluginUiSlot.timeline,
          ).toJson(),
          RpcConnectionContext(),
        ),
        throwsA(
          isA<RpcFailureException>().having(
            (error) => error.message,
            'message',
            'Plugin UI callback failed.',
          ),
        ),
      );
    }, tags: const <String>['feature_test__plugin_ui__contract']);

    // A slot renders against whatever revision the Agent has pinned right now.
    // Before the Agent's first turn nothing is pinned, and after shutdown the
    // runtime is gone; both are ordinary, so neither may reach the client as
    // internal_error, which the protocol reserves for defects. They carry
    // different codes because a host shows nothing for the first and reports
    // the second.
    for (final failure in <({String name, Exception error, String code})>[
      (
        name: 'an Agent with no active revision',
        error: const PluginRevisionUnavailable(
          'Agent agent has no active revision for plugin example.ui.',
        ),
        code: RpcErrorCodes.pluginRevisionUnavailable,
      ),
      (
        name: 'a torn-down runtime',
        error: const PluginRuntimeClosed('Plugin runtime session is closed.'),
        code: RpcErrorCodes.pluginUiRejected,
      ),
    ]) {
      test('render answers ${failure.name} with a translatable code', () async {
        final service = PluginUiService(
          descriptors: _ThrowingDescriptorReader(failure.error),
          runtime: const _RejectingUiRuntime(),
        );

        await expectLater(
          binding(service, pluginsRenderUiProcedure).invoke(
            const PluginUiRenderParamsDto(
              agentId: 'agent',
              pluginId: 'example.ui',
              contributionId: 'card',
              slot: PluginUiSlot.timeline,
            ).toJson(),
            RpcConnectionContext(),
          ),
          throwsA(
            isA<RpcFailureException>().having(
              (error) => error.code,
              'code',
              failure.code,
            ),
          ),
        );
      }, tags: const <String>['feature_test__plugin_ui__contract']);
    }
  });

  test(
    'renders a manifest contribution and dispatches its declared action',
    () async {
      const descriptor = PluginDescriptorDto(
        apiMajor: 5,
        id: 'example.controls',
        version: '1.0.0',
        name: 'Controls',
        entrypoint: 'main.lua',
        source: PluginSource.user,
        sourcePath: r'C:\config\v5\plugins\example.controls',
        requestedCapabilities: <String>[],
        revision: PluginRevisionDto(
          pluginId: 'example.controls',
          contentHash: 'revision',
          manifestHash: 'manifest',
          sdkAbiHash: 'sdk-abi-hash',
          executionRevisionHash: 'execution-revision',
          requestedCapabilities: <String>[],
        ),
        contributions: <PluginContributionDto>[
          PluginContributionDto(
            pluginId: 'example.controls',
            id: 'settings',
            kind: PluginContributionKind.ui,
            metadata: <String, dynamic>{
              'slots': <String>['agentSettings'],
              'document': <String, dynamic>{
                'type': 'text',
                'text': 'Before',
                'actionId': 'refresh',
              },
              'actions': <String, dynamic>{
                'refresh': <String, dynamic>{'type': 'text', 'text': 'After'},
              },
            },
          ),
        ],
      );
      final service = PluginUiService(
        descriptors: const _DescriptorReader(descriptor),
        runtime: const ManifestPluginUiRuntime(),
      );

      final rendered = await service.render(
        const PluginUiRenderParamsDto(
          agentId: 'agent',
          pluginId: 'example.controls',
          contributionId: 'settings',
          slot: PluginUiSlot.agentSettings,
        ),
      );
      expect(rendered.root['text'], 'Before');
      expect(rendered.revisionHash, 'execution-revision');

      final updated = await service.dispatch(
        PluginUiActionParamsDto(
          agentId: 'agent',
          pluginId: 'example.controls',
          action: PluginUiActionDto(
            documentId: rendered.id,
            actionId: 'refresh',
          ),
        ),
      );

      expect(updated.root['text'], 'After');
      expect(updated.id, rendered.id);
    },
    tags: const <String>['feature_test__plugin_ui__unit'],
  );

  test('rejects a contribution in a slot it did not declare', () async {
    const descriptor = PluginDescriptorDto(
      apiMajor: 5,
      id: 'example.controls',
      version: '1.0.0',
      name: 'Controls',
      entrypoint: 'main.lua',
      source: PluginSource.user,
      sourcePath: 'plugins/example.controls',
      requestedCapabilities: <String>[],
      revision: PluginRevisionDto(
        pluginId: 'example.controls',
        contentHash: 'revision',
        manifestHash: 'manifest',
        sdkAbiHash: 'sdk-abi-hash',
        executionRevisionHash: 'execution-revision',
        requestedCapabilities: <String>[],
      ),
      contributions: <PluginContributionDto>[
        PluginContributionDto(
          pluginId: 'example.controls',
          id: 'settings',
          kind: PluginContributionKind.ui,
          metadata: <String, dynamic>{
            'slots': <String>['agentSettings'],
            'document': <String, dynamic>{'type': 'text', 'text': 'Only'},
          },
        ),
      ],
    );
    final service = PluginUiService(
      descriptors: const _DescriptorReader(descriptor),
      runtime: const ManifestPluginUiRuntime(),
    );

    expect(
      () => service.render(
        const PluginUiRenderParamsDto(
          agentId: 'agent',
          pluginId: 'example.controls',
          contributionId: 'settings',
          slot: PluginUiSlot.dialog,
        ),
      ),
      throwsA(isA<PluginUiException>()),
    );
  }, tags: const <String>['feature_test__plugin_ui__unit']);

  test(
    'dispatches against the historical revision pinned at render time',
    () async {
      const revisionOne = PluginDescriptorDto(
        apiMajor: 5,
        id: 'example.history',
        version: '1.0.0',
        name: 'History',
        entrypoint: 'main.lua',
        source: PluginSource.user,
        sourcePath: 'plugins/example.history',
        requestedCapabilities: <String>[],
        revision: PluginRevisionDto(
          pluginId: 'example.history',
          contentHash: 'revision-one',
          manifestHash: 'manifest-one',
          sdkAbiHash: 'sdk-abi-hash',
          executionRevisionHash: 'execution-revision-one',
          requestedCapabilities: <String>[],
        ),
        contributions: <PluginContributionDto>[
          PluginContributionDto(
            pluginId: 'example.history',
            id: 'timeline',
            kind: PluginContributionKind.ui,
            metadata: <String, dynamic>{
              'slots': <String>['timeline'],
              'document': <String, dynamic>{
                'type': 'text',
                'text': 'Version one',
                'actionId': 'expand',
              },
              'actions': <String, dynamic>{
                'expand': <String, dynamic>{
                  'type': 'text',
                  'text': 'Version one details',
                },
              },
            },
          ),
        ],
      );
      final reader = _MutableDescriptorReader(revisionOne);
      final service = PluginUiService(
        descriptors: reader,
        runtime: const ManifestPluginUiRuntime(),
      );
      final rendered = await service.render(
        const PluginUiRenderParamsDto(
          agentId: 'agent',
          pluginId: 'example.history',
          contributionId: 'timeline',
          slot: PluginUiSlot.timeline,
        ),
      );

      reader.descriptor = revisionOne.copyWith(
        version: '2.0.0',
        revision: revisionOne.revision!.copyWith(contentHash: 'revision-two'),
        contributions: <PluginContributionDto>[
          revisionOne.contributions.single.copyWith(
            metadata: const <String, dynamic>{
              'slots': <String>['timeline'],
              'document': <String, dynamic>{
                'type': 'text',
                'text': 'Version two',
                'actionId': 'expand',
              },
              'actions': <String, dynamic>{
                'expand': <String, dynamic>{
                  'type': 'text',
                  'text': 'Version two details',
                },
              },
            },
          ),
        ],
      );

      final updated = await service.dispatch(
        PluginUiActionParamsDto(
          agentId: 'agent',
          pluginId: 'example.history',
          action: PluginUiActionDto(
            documentId: rendered.id,
            actionId: 'expand',
          ),
        ),
      );

      expect(updated.revisionHash, 'execution-revision-one');
      expect(updated.root['text'], 'Version one details');
    },
    tags: const <String>['feature_test__plugin_ui__unit'],
  );

  test(
    'remembers harness-published snapshots for the ordinary action path',
    () async {
      const contribution = PluginContributionDto(
        pluginId: 'example.published',
        id: 'card',
        kind: PluginContributionKind.ui,
        metadata: <String, dynamic>{
          'slots': <String>['timeline'],
          'actions': <String, dynamic>{
            'expand': <String, dynamic>{
              'type': 'text',
              'text': 'Expanded publication',
            },
          },
        },
      );
      const descriptor = PluginDescriptorDto(
        apiMajor: 5,
        id: 'example.published',
        version: '1.0.0',
        name: 'Published',
        entrypoint: 'main.lua',
        source: PluginSource.user,
        sourcePath: 'plugins/example.published',
        requestedCapabilities: <String>[],
        revision: PluginRevisionDto(
          pluginId: 'example.published',
          contentHash: 'revision-one',
          manifestHash: 'manifest-one',
          sdkAbiHash: 'sdk-abi-hash',
          executionRevisionHash: 'execution-revision-one',
          requestedCapabilities: <String>[],
        ),
        contributions: <PluginContributionDto>[contribution],
      );
      final service = PluginUiService(
        descriptors: const _DescriptorReader(descriptor),
        runtime: const ManifestPluginUiRuntime(),
      );
      const request = PluginUiRenderParamsDto(
        agentId: 'agent',
        pluginId: 'example.published',
        contributionId: 'card',
        slot: PluginUiSlot.timeline,
        context: <String, dynamic>{'sessionId': 'session'},
      );
      const document = PluginUiDocumentDto(
        id: 'published-document',
        pluginId: 'example.published',
        revisionHash: 'execution-revision-one',
        slot: PluginUiSlot.timeline,
        root: <String, dynamic>{
          'type': 'text',
          'text': 'Published',
          'actionId': 'expand',
        },
      );

      service.rememberPublished(
        plugin: descriptor,
        contribution: contribution,
        request: request,
        document: document,
      );
      final updated = await service.dispatch(
        const PluginUiActionParamsDto(
          agentId: 'agent',
          pluginId: 'example.published',
          action: PluginUiActionDto(
            documentId: 'published-document',
            actionId: 'expand',
          ),
        ),
      );

      expect(updated.id, document.id);
      expect(updated.root['text'], 'Expanded publication');
    },
    tags: const <String>['feature_test__plugin_ui__unit'],
  );

  test(
    'rejects missing revisions, contributions, documents, and actions',
    () async {
      final noRevision = _uiDescriptor(revisionHash: null);
      final noContribution = _uiDescriptor(
        contributions: const <PluginContributionDto>[],
      );
      final noDocument = _uiDescriptor(
        metadata: const <String, dynamic>{
          'slots': <String>['timeline'],
        },
      );
      final noActions = _uiDescriptor(
        metadata: const <String, dynamic>{
          'slots': <String>['timeline'],
          'document': <String, dynamic>{'type': 'text', 'text': 'initial'},
        },
      );
      const request = PluginUiRenderParamsDto(
        agentId: 'agent',
        pluginId: 'example.ui',
        contributionId: 'card',
        slot: PluginUiSlot.timeline,
      );

      await expectLater(
        PluginUiService(
          descriptors: _DescriptorReader(noRevision),
          runtime: const ManifestPluginUiRuntime(),
        ).render(request),
        throwsA(isA<PluginUiException>()),
      );
      await expectLater(
        PluginUiService(
          descriptors: _DescriptorReader(noContribution),
          runtime: const ManifestPluginUiRuntime(),
        ).render(request),
        throwsA(isA<PluginUiException>()),
      );
      await expectLater(
        PluginUiService(
          descriptors: _DescriptorReader(noDocument),
          runtime: const ManifestPluginUiRuntime(),
        ).render(request),
        throwsA(isA<PluginUiException>()),
      );

      final service = PluginUiService(
        descriptors: _DescriptorReader(noActions),
        runtime: const ManifestPluginUiRuntime(),
      );
      final document = await service.render(request);
      await expectLater(
        service.dispatch(
          PluginUiActionParamsDto(
            agentId: 'agent',
            pluginId: 'example.ui',
            action: PluginUiActionDto(
              documentId: document.id,
              actionId: 'missing',
            ),
          ),
        ),
        throwsA(isA<PluginUiException>()),
      );
      expect(
        const PluginUiException('safe').toString(),
        'PluginUiException: safe',
      );
    },
  );

  test('actions reject expired and cross-Agent document ownership', () async {
    final descriptor = _uiDescriptor();
    final service = PluginUiService(
      descriptors: _DescriptorReader(descriptor),
      runtime: const ManifestPluginUiRuntime(),
    );
    await expectLater(
      service.dispatch(
        const PluginUiActionParamsDto(
          agentId: 'agent',
          pluginId: 'example.ui',
          action: PluginUiActionDto(documentId: 'missing', actionId: 'refresh'),
        ),
      ),
      throwsA(isA<PluginUiException>()),
    );

    final document = await service.render(
      const PluginUiRenderParamsDto(
        agentId: 'agent',
        pluginId: 'example.ui',
        contributionId: 'card',
        slot: PluginUiSlot.timeline,
      ),
    );
    for (final owner in <(String, String)>[
      ('other-agent', 'example.ui'),
      ('agent', 'other.ui'),
    ]) {
      await expectLater(
        service.dispatch(
          PluginUiActionParamsDto(
            agentId: owner.$1,
            pluginId: owner.$2,
            action: PluginUiActionDto(
              documentId: document.id,
              actionId: 'refresh',
            ),
          ),
        ),
        throwsA(isA<PluginUiException>()),
      );
    }
  });

  test('published snapshot metadata and slots must exactly match', () {
    final descriptor = _uiDescriptor();
    final contribution = descriptor.contributions.single;
    final service = PluginUiService(
      descriptors: _DescriptorReader(descriptor),
      runtime: const ManifestPluginUiRuntime(),
    );
    const request = PluginUiRenderParamsDto(
      agentId: 'agent',
      pluginId: 'example.ui',
      contributionId: 'card',
      slot: PluginUiSlot.timeline,
    );
    const document = PluginUiDocumentDto(
      id: 'published',
      pluginId: 'example.ui',
      revisionHash: 'execution-revision',
      slot: PluginUiSlot.timeline,
      root: <String, dynamic>{'type': 'text'},
    );

    expect(
      () => service.rememberPublished(
        plugin: descriptor,
        contribution: contribution,
        request: request.copyWith(agentId: ''),
        document: document,
      ),
      throwsA(isA<PluginUiException>()),
    );
    expect(
      () => service.rememberPublished(
        plugin: descriptor,
        contribution: contribution.copyWith(
          metadata: const <String, dynamic>{
            'slots': <String>['dialog'],
          },
        ),
        request: request,
        document: document,
      ),
      throwsA(isA<PluginUiException>()),
    );
  });

  test('manifest documents are immutable, bounded JSON trees', () async {
    final invalidDocuments = <Object?>[
      <Object?, Object?>{1: 'non-string key'},
      <String, Object?>{'type': DateTime.utc(2026)},
      <Object?>['root must be an object'],
      _deepUiDocument(),
    ];
    for (final document in invalidDocuments) {
      final descriptor = _uiDescriptor(
        metadata: <String, dynamic>{
          'slots': <String>['timeline'],
          'document': document,
        },
      );
      await expectLater(
        PluginUiService(
          descriptors: _DescriptorReader(descriptor),
          runtime: const ManifestPluginUiRuntime(),
        ).render(
          const PluginUiRenderParamsDto(
            agentId: 'agent',
            pluginId: 'example.ui',
            contributionId: 'card',
            slot: PluginUiSlot.timeline,
          ),
        ),
        throwsA(isA<PluginUiException>()),
      );
    }

    final service = PluginUiService(
      descriptors: _DescriptorReader(_uiDescriptor()),
      runtime: const ManifestPluginUiRuntime(),
    );
    final rendered = await service.render(
      const PluginUiRenderParamsDto(
        agentId: 'agent',
        pluginId: 'example.ui',
        contributionId: 'card',
        slot: PluginUiSlot.timeline,
      ),
    );
    expect(() => rendered.root['new'] = true, throwsUnsupportedError);
  });

  test('Agent-pinned descriptors are used for render', () async {
    final reader = _AgentDescriptorReader(_uiDescriptor());
    final service = PluginUiService(
      descriptors: reader,
      runtime: const ManifestPluginUiRuntime(),
    );

    await service.render(
      const PluginUiRenderParamsDto(
        agentId: 'agent-pinned',
        pluginId: 'example.ui',
        contributionId: 'card',
        slot: PluginUiSlot.timeline,
      ),
    );

    expect(reader.agentId, 'agent-pinned');
  });

  test('actions for one document are serialized', () async {
    final runtime = _BlockingUiRuntime();
    final service = PluginUiService(
      descriptors: _DescriptorReader(_uiDescriptor()),
      runtime: runtime,
    );
    final document = await service.render(
      const PluginUiRenderParamsDto(
        agentId: 'agent',
        pluginId: 'example.ui',
        contributionId: 'card',
        slot: PluginUiSlot.timeline,
      ),
    );
    final request = PluginUiActionParamsDto(
      agentId: 'agent',
      pluginId: 'example.ui',
      action: PluginUiActionDto(documentId: document.id, actionId: 'refresh'),
    );

    final first = service.dispatch(request);
    await runtime.firstDispatchStarted.future;
    final second = service.dispatch(request);
    await Future<void>.delayed(Duration.zero);
    expect(runtime.dispatches, 1);
    runtime.releaseFirst.complete();
    await Future.wait(<Future<PluginUiDocumentDto>>[first, second]);
    expect(runtime.dispatches, 2);
  });

  test('oldest UI snapshots are evicted at the host bound', () async {
    final service = PluginUiService(
      descriptors: _DescriptorReader(_uiDescriptor()),
      runtime: const ManifestPluginUiRuntime(),
    );
    const request = PluginUiRenderParamsDto(
      agentId: 'agent',
      pluginId: 'example.ui',
      contributionId: 'card',
      slot: PluginUiSlot.timeline,
    );
    final first = await service.render(request);
    PluginUiDocumentDto? last;
    for (var index = 0; index < 1024; index += 1) {
      last = await service.render(request);
    }

    await expectLater(
      service.dispatch(
        PluginUiActionParamsDto(
          agentId: 'agent',
          pluginId: 'example.ui',
          action: PluginUiActionDto(documentId: first.id, actionId: 'refresh'),
        ),
      ),
      throwsA(isA<PluginUiException>()),
    );
    expect(last, isNotNull);
  });
}

PluginDescriptorDto _uiDescriptor({
  String? revisionHash = 'revision',
  List<PluginContributionDto>? contributions,
  Map<String, dynamic>? metadata,
}) {
  final contribution = PluginContributionDto(
    pluginId: 'example.ui',
    id: 'card',
    kind: PluginContributionKind.ui,
    metadata:
        metadata ??
        const <String, dynamic>{
          'slots': <String>['timeline'],
          'document': <String, dynamic>{
            'type': 'text',
            'text': 'before',
            'actionId': 'refresh',
          },
          'actions': <String, dynamic>{
            'refresh': <String, dynamic>{
              'type': 'text',
              'text': 'after',
              'actionId': 'refresh',
            },
          },
        },
  );
  return PluginDescriptorDto(
    apiMajor: 5,
    id: 'example.ui',
    version: '1.0.0',
    name: 'UI',
    entrypoint: 'main.lua',
    source: PluginSource.user,
    sourcePath: 'plugins/example.ui',
    requestedCapabilities: const <String>[],
    revision: revisionHash == null
        ? null
        : PluginRevisionDto(
            pluginId: 'example.ui',
            contentHash: revisionHash,
            manifestHash: 'manifest',
            sdkAbiHash: 'sdk-abi-hash',
            executionRevisionHash: 'execution-$revisionHash',
            requestedCapabilities: const <String>[],
          ),
    contributions: contributions ?? <PluginContributionDto>[contribution],
  );
}

Object? _deepUiDocument() {
  Object? value = 'leaf';
  for (var index = 0; index < 34; index += 1) {
    value = <String, Object?>{'child': value};
  }
  return value;
}

final class _DescriptorReader implements PluginDescriptorReader {
  const new(this.descriptor);

  final PluginDescriptorDto descriptor;

  @override
  Future<PluginDescriptorDto> get(String id) async {
    if (id != descriptor.id) throw StateError('Plugin not found: $id');
    return descriptor;
  }
}

final class _ThrowingDescriptorReader implements PluginDescriptorReader {
  const new(this.error);

  final Exception error;

  @override
  Future<PluginDescriptorDto> get(String id) async => throw error;
}

final class _RejectingUiRuntime implements PluginUiRuntime {
  const new({
    this.rejectRender = false,
    this.renderFailure =
        'Plugin UI handler failed: bundle/tinest.plugin_main.lua:42: '
        'UI callback must return a Tinest UI node.\n'
        'stack traceback:\n'
        '\tbundle/tinest.lua:1353: in function <bundle/tinest.lua:1352>',
  });

  final bool rejectRender;
  final String renderFailure;

  @override
  Future<Map<String, dynamic>> render({
    required PluginDescriptorDto plugin,
    required PluginContributionDto contribution,
    required PluginUiRenderParamsDto request,
  }) async {
    if (rejectRender) {
      throw PluginUiException(renderFailure);
    }
    return <String, dynamic>{
      'type': 'text',
      'text': 'ready',
      'actionId': 'refresh',
    };
  }

  @override
  Future<Map<String, dynamic>> dispatch({
    required PluginDescriptorDto plugin,
    required PluginContributionDto contribution,
    required PluginUiRenderParamsDto request,
    required PluginUiDocumentDto document,
    required PluginUiActionDto action,
  }) => throw const PluginUiException(
    'Plugin UI action failed: bundle/tinest.plugin_main.lua:57: '
    'UI action callback must return a Tinest UI node.\n'
    'stack traceback:\n'
    '\tbundle/tinest.lua:1353: in function <bundle/tinest.lua:1352>',
  );
}

final class _MutableDescriptorReader implements PluginDescriptorReader {
  new(this.descriptor);

  PluginDescriptorDto descriptor;

  @override
  Future<PluginDescriptorDto> get(String id) async {
    if (id != descriptor.id) throw StateError('Plugin not found: $id');
    return descriptor;
  }
}

final class _AgentDescriptorReader
    implements PluginDescriptorReader, AgentPluginDescriptorReader {
  new(this.descriptor);

  final PluginDescriptorDto descriptor;
  String? agentId;

  @override
  Future<PluginDescriptorDto> get(String id) async => descriptor;

  @override
  Future<PluginDescriptorDto> getForAgent(String agentId, String id) async {
    this.agentId = agentId;
    return descriptor;
  }
}

final class _BlockingUiRuntime implements PluginUiRuntime {
  final Completer<void> firstDispatchStarted = Completer<void>();
  final Completer<void> releaseFirst = Completer<void>();
  int dispatches = 0;

  @override
  Future<Map<String, dynamic>> render({
    required PluginDescriptorDto plugin,
    required PluginContributionDto contribution,
    required PluginUiRenderParamsDto request,
  }) async => <String, dynamic>{
    'type': 'text',
    'text': 'initial',
    'actionId': 'refresh',
  };

  @override
  Future<Map<String, dynamic>> dispatch({
    required PluginDescriptorDto plugin,
    required PluginContributionDto contribution,
    required PluginUiRenderParamsDto request,
    required PluginUiDocumentDto document,
    required PluginUiActionDto action,
  }) async {
    dispatches += 1;
    if (dispatches == 1) {
      firstDispatchStarted.complete();
      await releaseFirst.future;
    }
    return <String, dynamic>{
      'type': 'text',
      'text': 'dispatch-$dispatches',
      'actionId': 'refresh',
    };
  }
}
