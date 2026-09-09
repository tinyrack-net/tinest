import 'dart:convert';
import 'dart:io';

import 'src/provider_catalog_cli.dart';

const _providerIds = <String>{
  'openai',
  'anthropic',
  'google',
  'deepseek',
  'openrouter',
  'groq',
  'xai',
};

final _lockFile = File(
  'packages/daemon/tool/provider_catalog/models_dev.lock.json',
);
final _normalizedFile = File(
  'packages/daemon/tool/provider_catalog/models_dev.normalized.json',
);
final _generatedFile = File(
  'packages/daemon/lib/src/features/providers/infrastructure/'
  'generated/models_dev_snapshot.g.dart',
);

Future<void> main(List<String> arguments) async {
  exitCode = await runProviderCatalogCli(
    arguments,
    generate: _generateProviderCatalog,
  );
}

Future<void> _generateProviderCatalog({required bool update}) async {
  final lock = Map<String, dynamic>.from(
    jsonDecode(await _lockFile.readAsString()) as Map,
  );
  if (update) {
    await _updateNormalized(lock);
    lock['verifiedAt'] = DateTime.now().toUtc().toIso8601String();
    await _lockFile.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(lock)}\n',
    );
  }
  if (!_normalizedFile.existsSync()) {
    stderr.writeln('Missing ${_normalizedFile.path}; run with --update once.');
    exitCode = 1;
    return;
  }
  final normalized = await _normalizedFile.readAsBytes();
  final encoded = base64Encode(normalized);
  final chunks = <String>[
    for (var offset = 0; offset < encoded.length; offset += 72)
      encoded.substring(
        offset,
        offset + 72 > encoded.length ? encoded.length : offset + 72,
      ),
  ];
  final generatedBody = chunks.indexed
      .map(
        (entry) =>
            "    '${entry.$2}'${entry.$1 == chunks.length - 1 ? ';' : ''}",
      )
      .join('\n');
  await _generatedFile.parent.create(recursive: true);
  await _generatedFile.writeAsString(
    '// GENERATED CODE - DO NOT MODIFY BY HAND.\n'
    '// models.dev ${lock['commit']} verified ${lock['verifiedAt']}\n\n'
    '/// Base64-encoded normalized advisory model metadata.\n'
    'const String modelsDevSnapshotBase64 =\n'
    '$generatedBody\n',
  );
}

Future<void> _updateNormalized(Map<String, dynamic> lock) async {
  final temporary = await Directory.systemTemp.createTemp('tinest-models-dev-');
  try {
    await _run('git', <String>[
      'clone',
      '--quiet',
      '--filter=blob:none',
      '--no-checkout',
      lock['repository']! as String,
      temporary.path,
    ]);
    await _run('git', <String>[
      '-C',
      temporary.path,
      'fetch',
      '--quiet',
      '--depth=1',
      'origin',
      lock['commit']! as String,
    ]);
    await _run('git', <String>[
      '-C',
      temporary.path,
      'checkout',
      '--quiet',
      'FETCH_HEAD',
    ]);
    final raw = <String, _RawModel>{};
    for (final providerId in _providerIds) {
      final directory = Directory(
        '${temporary.path}/providers/$providerId/models',
      );
      if (!directory.existsSync()) continue;
      await for (final entity in directory.list(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.toml')) continue;
        final relative = entity.path
            .substring(directory.path.length + 1)
            .replaceAll(r'\', '/')
            .replaceAll(RegExp(r'\.toml$'), '');
        raw['$providerId/$relative'] = _parseToml(
          providerId,
          relative,
          await entity.readAsString(),
        );
      }
    }
    final result = <String, List<Map<String, Object?>>>{};
    for (final entry in raw.entries) {
      final resolved = _resolve(entry.value, raw, <String>{});
      if (!resolved.toolCalling || _excluded(resolved.id)) continue;
      result
          .putIfAbsent(resolved.providerId, () => <Map<String, Object?>>[])
          .add(resolved.toJson());
    }
    for (final models in result.values) {
      models.sort(
        (left, right) =>
            (left['id']! as String).compareTo(right['id']! as String),
      );
    }
    final ordered = <String, Object?>{
      for (final providerId in result.keys.toList()..sort())
        providerId: result[providerId],
    };
    await _normalizedFile.parent.create(recursive: true);
    await _normalizedFile.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(ordered)}\n',
    );
  } finally {
    await temporary.delete(recursive: true);
  }
}

_RawModel _parseToml(String providerId, String id, String source) {
  String? section;
  String? name;
  String? baseModel;
  var reasoning = false;
  var toolCalling = false;
  var imageInput = false;
  var fileInput = false;
  final cost = <String, double>{};
  final limits = <String, int>{};
  for (final original in const LineSplitter().convert(source)) {
    final line = original.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    if (line.startsWith('[')) {
      section = line.replaceAll(RegExp(r'^\[+|\]+$'), '');
      continue;
    }
    final split = line.indexOf('=');
    if (split < 0) continue;
    final key = line.substring(0, split).trim();
    final value = line.substring(split + 1).trim();
    if (section == null) {
      if (key == 'name') name = _string(value);
      if (key == 'base_model') baseModel = _string(value);
      if (key == 'reasoning') reasoning = value == 'true';
      if (key == 'tool_call') toolCalling = value == 'true';
      if (key == 'attachment') fileInput = value == 'true';
    } else if (section == 'cost') {
      final number = _number(value);
      if (number != null) cost[key] = number;
    } else if (section == 'limit') {
      final number = _integer(value);
      if (number != null) limits[key] = number;
    } else if (section == 'modalities' && key == 'input') {
      imageInput = value.contains('"image"');
      fileInput = fileInput || value.contains('"pdf"');
    }
  }
  return _RawModel(
    providerId: providerId,
    id: id,
    name: name,
    baseModel: baseModel,
    reasoning: reasoning,
    toolCalling: toolCalling,
    imageInput: imageInput,
    fileInput: fileInput,
    cost: cost,
    limits: limits,
  );
}

_RawModel _resolve(
  _RawModel model,
  Map<String, _RawModel> all,
  Set<String> path,
) {
  final baseId = model.baseModel;
  if (baseId == null || !path.add(baseId) || all[baseId] == null) return model;
  final base = _resolve(all[baseId]!, all, path);
  return model.merge(base);
}

bool _excluded(String id) {
  final lowered = id.toLowerCase();
  return lowered.contains('antigravity') ||
      lowered.contains('deep-research') ||
      lowered.contains('computer-use');
}

String? _string(String value) {
  final match = RegExp(r'^"(.*)"$').firstMatch(value);
  return match?.group(1);
}

double? _number(String value) =>
    double.tryParse(value.replaceAll('_', '').split(' ').first);

int? _integer(String value) =>
    int.tryParse(value.replaceAll('_', '').split(' ').first);

Future<void> _run(String executable, List<String> arguments) async {
  final process = await Process.run(executable, arguments);
  if (process.exitCode != 0) {
    throw ProcessException(
      executable,
      arguments,
      '${process.stdout}${process.stderr}',
      process.exitCode,
    );
  }
}

final class _RawModel {
  const new({
    required this.providerId,
    required this.id,
    required this.name,
    required this.baseModel,
    required this.reasoning,
    required this.toolCalling,
    required this.imageInput,
    required this.fileInput,
    required this.cost,
    required this.limits,
  });

  final String providerId;
  final String id;
  final String? name;
  final String? baseModel;
  final bool reasoning;
  final bool toolCalling;
  final bool imageInput;
  final bool fileInput;
  final Map<String, double> cost;
  final Map<String, int> limits;

  _RawModel merge(_RawModel base) => _RawModel(
    providerId: providerId,
    id: id,
    name: name ?? base.name,
    baseModel: baseModel,
    reasoning: reasoning || base.reasoning,
    toolCalling: toolCalling || base.toolCalling,
    imageInput: imageInput || base.imageInput,
    fileInput: fileInput || base.fileInput,
    cost: <String, double>{...base.cost, ...cost},
    limits: <String, int>{...base.limits, ...limits},
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'label': name ?? id,
    'reasoning': reasoning,
    'toolCalling': toolCalling,
    'imageInput': imageInput,
    'fileInput': fileInput,
    if (cost.isNotEmpty) 'cost': cost,
    if (limits.isNotEmpty) 'limits': limits,
  };
}
