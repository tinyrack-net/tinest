import 'package:client/client.dart';
import 'package:path/path.dart' as p;
import 'package:protocol/protocol.dart';

/// Narrow Markdown agent administration port used by the standalone CLI.
abstract interface class AgentCliBackend {
  /// Lists active agent definitions.
  Future<List<AgentDefinitionDto>> list();

  /// Validates an unsaved Markdown source.
  Future<AgentDefinitionDto> validate(String id, String markdown);

  /// Creates or updates one definition.
  Future<AgentDefinitionDto> apply(String id, AgentDefinitionDto definition);

  /// Archives one custom definition.
  Future<void> archive(String id);

  /// Resets the protected built-in definition.
  Future<AgentDefinitionDto> reset(String id);
}

/// Adapts [TinestApi] to the standalone agent administration commands.
final class TinestApiAgentCliBackend implements AgentCliBackend {
  /// Creates the client adapter.
  const new(this._api);

  final TinestApi _api;

  @override
  Future<List<AgentDefinitionDto>> list() => _api.agents.listAgentDefinitions();

  @override
  Future<AgentDefinitionDto> validate(String id, String markdown) =>
      _api.agents.validateAgentDefinition(id, markdown);

  @override
  Future<AgentDefinitionDto> apply(
    String id,
    AgentDefinitionDto definition,
  ) async {
    final existing = (await _api.agents.listAgentDefinitions())
        .where((item) => item.id == id)
        .firstOrNull;
    if (existing == null) {
      return await _api.agents.createAgentDefinition(id, definition);
    }
    return await _api.agents.updateAgentDefinition(
      definition.copyWith(
        contentHash: existing.contentHash,
        sourcePath: existing.sourcePath,
        isBuiltIn: existing.isBuiltIn,
      ),
      expectedContentHash: existing.contentHash,
    );
  }

  @override
  Future<void> archive(String id) => _api.agents.archiveAgentDefinition(id);

  @override
  Future<AgentDefinitionDto> reset(String id) =>
      _api.agents.resetAgentDefinition(id);
}

/// Lists every active agent definition with its mode and staleness.
Future<int> agentList({
  required AgentCliBackend backend,
  required StringSink output,
}) async {
  for (final definition in await backend.list()) {
    final state = definition.isStale ? 'stale' : 'ready';
    output.writeln(
      '${definition.id}\t${definition.mode.name}\t$state\t'
      '${definition.sourcePath}',
    );
  }
  return 0;
}

/// Validates the Markdown definition at [path] without saving it.
///
/// The agent ID is taken from the file name, which is how an operator names a
/// definition on disk.
Future<int> agentValidate({
  required AgentCliBackend backend,
  required StringSink output,
  required String path,
  Future<String> Function(String path)? readFile,
}) async {
  final id = p.basenameWithoutExtension(path);
  final markdown = await _read(path, readFile);
  final validated = await backend.validate(id, markdown);
  output.writeln('Valid ${validated.id}: ${validated.name}');
  return 0;
}

/// Creates or updates the agent [id] from the Markdown file at [path].
Future<int> agentApply({
  required AgentCliBackend backend,
  required StringSink output,
  required String id,
  required String path,
  Future<String> Function(String path)? readFile,
}) async {
  final markdown = await _read(path, readFile);
  final definition = await backend.validate(id, markdown);
  await backend.apply(id, definition);
  output.writeln('Applied $id.');
  return 0;
}

/// Archives the custom agent definition [id].
Future<int> agentArchive({
  required AgentCliBackend backend,
  required StringSink output,
  required String id,
}) async {
  await backend.archive(id);
  output.writeln('Archived $id.');
  return 0;
}

/// Restores the protected built-in definition [id] to its shipped content.
Future<int> agentReset({
  required AgentCliBackend backend,
  required StringSink output,
  required String id,
}) async {
  // `tinest` is the only built-in definition, so resetting anything else would
  // silently do nothing rather than fail.
  if (id != 'tinest') {
    throw const FormatException('agent reset only supports tinest.');
  }
  await backend.reset('tinest');
  output.writeln('Reset tinest.');
  return 0;
}

Future<String> _read(
  String path,
  Future<String> Function(String path)? readFile,
) {
  final reader = readFile;
  if (reader == null) {
    throw StateError('A file reader is required.');
  }
  return reader(path);
}
