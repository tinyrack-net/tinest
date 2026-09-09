import 'dart:async';

import 'package:daemon/src/features/models/infrastructure/model_settings_service.dart';
import 'package:daemon/src/shared/infrastructure/persistence/repositories.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  group('daemon model settings', () {
    test('persists the first runnable model once', () async {
      final settings = _MemorySettings();
      final catalog = _FakeRunnableModelCatalog(<ModelSelectionDto>[
        const ModelSelectionDto(modelId: 'alpha/first'),
        const ModelSelectionDto(modelId: 'beta/second'),
      ]);
      final service = DaemonModelSettingsService(
        settings: settings,
        catalog: catalog,
      );

      await service.initialize();
      expect(
        (await service.getSettings()).defaultModel,
        const ModelSelectionDto(modelId: 'alpha/first'),
      );
      expect(settings.writes, 1);

      catalog
        ..models = <ModelSelectionDto>[
          const ModelSelectionDto(modelId: 'aardvark/new-first'),
          const ModelSelectionDto(modelId: 'alpha/first'),
        ]
        ..notifyChanged();
      await service.settled;

      expect(
        (await service.getSettings()).defaultModel,
        const ModelSelectionDto(modelId: 'alpha/first'),
      );
      expect(settings.writes, 1);
      await service.close();
    });

    test('serializes concurrent initialization to one write', () async {
      final settings = _MemorySettings();
      final service = DaemonModelSettingsService(
        settings: settings,
        catalog: _FakeRunnableModelCatalog(<ModelSelectionDto>[
          const ModelSelectionDto(modelId: 'alpha/first'),
        ]),
      );

      await Future.wait<void>(<Future<void>>[
        service.initialize(),
        service.initialize(),
        service.initialize(),
      ]);

      expect(settings.writes, 1);
      await service.close();
    });

    test('an explicit write cannot be overwritten by initialization', () async {
      final settings = _MemorySettings();
      final catalog = _BlockingFirstCatalog(<ModelSelectionDto>[
        const ModelSelectionDto(modelId: 'alpha/first'),
        const ModelSelectionDto(modelId: 'beta/explicit'),
      ]);
      final service = DaemonModelSettingsService(
        settings: settings,
        catalog: catalog,
      );

      final initialization = service.initialize();
      await catalog.firstListStarted.future;
      final explicit = service.setDefaultModel(
        const ModelSelectionDto(modelId: 'beta/explicit'),
      );
      await Future<void>.delayed(Duration.zero);
      catalog.releaseFirstList.complete();
      await Future.wait<void>(<Future<void>>[initialization, explicit]);

      expect(
        (await service.getSettings()).defaultModel,
        const ModelSelectionDto(modelId: 'beta/explicit'),
      );
      await service.close();
    });

    test('a restarted service preserves the stored selection', () async {
      final settings = _MemorySettings();
      final firstCatalog = _FakeRunnableModelCatalog(<ModelSelectionDto>[
        const ModelSelectionDto(modelId: 'alpha/first'),
      ]);
      final first = DaemonModelSettingsService(
        settings: settings,
        catalog: firstCatalog,
      );
      await first.initialize();
      await first.close();

      final second = DaemonModelSettingsService(
        settings: settings,
        catalog: _FakeRunnableModelCatalog(<ModelSelectionDto>[
          const ModelSelectionDto(modelId: 'aardvark/new-first'),
          const ModelSelectionDto(modelId: 'alpha/first'),
        ]),
      );
      await second.initialize();

      expect(
        (await second.getSettings()).defaultModel,
        const ModelSelectionDto(modelId: 'alpha/first'),
      );
      expect(settings.writes, 1);
      await second.close();
    });

    test('rewrites the daemon reference after a prefix rename', () async {
      final settings = _MemorySettings();
      final service = DaemonModelSettingsService(
        settings: settings,
        catalog: _FakeRunnableModelCatalog(<ModelSelectionDto>[
          const ModelSelectionDto(modelId: 'alpha/first'),
        ]),
      );
      await service.initialize();

      await service.rewriteModelPrefix('alpha', 'renamed');

      expect(
        (await service.getSettings()).defaultModel,
        const ModelSelectionDto(modelId: 'renamed/first'),
      );
      await service.close();
    });

    test('keeps an unavailable default and refuses silent fallback', () async {
      final settings = _MemorySettings();
      final catalog = _FakeRunnableModelCatalog(<ModelSelectionDto>[
        const ModelSelectionDto(modelId: 'alpha/first'),
      ]);
      final service = DaemonModelSettingsService(
        settings: settings,
        catalog: catalog,
      );
      await service.initialize();
      await service.setDefaultModel(
        const ModelSelectionDto(modelId: 'alpha/first'),
      );

      catalog
        ..models = <ModelSelectionDto>[
          const ModelSelectionDto(modelId: 'beta/replacement'),
        ]
        ..notifyChanged();
      await service.settled;

      expect(
        (await service.getSettings()).defaultModel,
        const ModelSelectionDto(modelId: 'alpha/first'),
      );
      await expectLater(
        service.requireDefaultModel(),
        throwsA(
          isA<ModelSettingsFailure>().having(
            (error) => error.code,
            'code',
            'model_unavailable',
          ),
        ),
      );
      await service.close();
    });

    test('rejects a default that is not runnable', () async {
      final service = DaemonModelSettingsService(
        settings: _MemorySettings(),
        catalog: _FakeRunnableModelCatalog(<ModelSelectionDto>[
          const ModelSelectionDto(modelId: 'alpha/first'),
        ]),
      );
      await service.initialize();

      await expectLater(
        service.setDefaultModel(
          const ModelSelectionDto(modelId: 'missing/model'),
        ),
        throwsA(isA<ModelSettingsFailure>()),
      );
      await service.close();
    });
  }, tags: const <String>['feature_test__model_settings__unit']);
}

final class _MemorySettings implements SettingsRepository {
  final Map<String, String> values = <String, String>{};
  int writes = 0;

  @override
  Future<String?> getValue(String key) async => values[key];

  @override
  Future<void> setValue(String key, String value) async {
    writes += 1;
    values[key] = value;
  }
}

class _FakeRunnableModelCatalog implements RunnableModelCatalog {
  new(this.models);

  List<ModelSelectionDto> models;
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );

  @override
  Stream<void> get runnableModelChanges => _changes.stream;

  @override
  Future<List<ModelSelectionDto>> listRunnableModels() async => models;

  void notifyChanged() => _changes.add(null);
}

final class _BlockingFirstCatalog extends _FakeRunnableModelCatalog {
  new(super.models);

  final Completer<void> firstListStarted = Completer<void>();
  final Completer<void> releaseFirstList = Completer<void>();
  bool _blocked = false;

  @override
  Future<List<ModelSelectionDto>> listRunnableModels() async {
    if (!_blocked) {
      _blocked = true;
      firstListStarted.complete();
      await releaseFirstList.future;
    }
    return await super.listRunnableModels();
  }
}
