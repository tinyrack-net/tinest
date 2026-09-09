import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_service.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_sdk.dart';
import 'package:daemon/src/features/plugins/runtime/plugin_type_environment.dart';
import 'package:path/path.dart' as p;

const String _version = '3.18.2';
const String _releaseBase =
    'https://github.com/LuaLS/lua-language-server/releases/download/$_version';

const Map<Abi, _LuaLsAsset> _assets = <Abi, _LuaLsAsset>{
  Abi.windowsX64: _LuaLsAsset(
    fileName: 'lua-language-server-3.18.2-win32-x64.zip',
    sha256: 'a4439a8f5e8e9e6505c11f045a7bf45db602124a1e246371c1dbe34924f3cf71',
  ),
  Abi.linuxX64: _LuaLsAsset(
    fileName: 'lua-language-server-3.18.2-linux-x64.tar.gz',
    sha256: 'ca71415dd19f19e30aaa35a4915aefca9fdb5fec31b98331cc3d77f778d539c5',
  ),
  Abi.linuxArm64: _LuaLsAsset(
    fileName: 'lua-language-server-3.18.2-linux-arm64.tar.gz',
    sha256: '273af33f26f4a1143f27c96d9f9e1188aba619c71e0807042134f66b4bd27f24',
  ),
  Abi.macosX64: _LuaLsAsset(
    fileName: 'lua-language-server-3.18.2-darwin-x64.tar.gz',
    sha256: 'e26cfefe423dd7326fc7c649539e4d4aaa4f35f34d2fefd8af2ed7090b72c556',
  ),
  Abi.macosArm64: _LuaLsAsset(
    fileName: 'lua-language-server-3.18.2-darwin-arm64.tar.gz',
    sha256: 'cec99d70b1f612acec4a10a79a03664e3aa0c229d4d8a586cb3f928ec37d509e',
  ),
};

Future<void> main(List<String> arguments) async {
  try {
    final root = _workspaceRoot();
    final asset = _assets[Abi.current()];
    if (asset == null) {
      throw StateError('LuaLS conformance does not support ${Abi.current()}.');
    }
    final cacheArgument = _argument(arguments, '--cache=');
    final configuredCache = Platform.environment['TINEST_LUALS_CACHE'];
    final cache = Directory(
      p.absolute(
        cacheArgument ??
            configuredCache ??
            p.join(root.path, '.dart_tool', 'luals-conformance'),
      ),
    );
    final archive = _argument(arguments, '--archive=');
    final distribution = await _installLuaLs(
      cache: cache,
      asset: asset,
      suppliedArchive: archive == null ? null : File(p.absolute(archive)),
    );
    final executable = File(
      p.join(
        distribution.path,
        'bin',
        Platform.isWindows ? 'lua-language-server.exe' : 'lua-language-server',
      ),
    );
    await _verifyVersion(executable);
    await _runConformance(
      root: root,
      distribution: distribution,
      executable: executable,
    );
    await _runPackageTypechecks(root: root, executable: executable);
    stdout.writeln(
      'LuaLS $_version conformance passed '
      '(${asset.fileName}, ${asset.sha256}).',
    );
  } on Object catch (error, stackTrace) {
    stderr
      ..writeln('LuaLS conformance failed: $error')
      ..writeln(stackTrace);
    exitCode = 1;
  }
}

String? _argument(List<String> arguments, String prefix) {
  for (final argument in arguments) {
    if (argument.startsWith(prefix)) return argument.substring(prefix.length);
  }
  return null;
}

Directory _workspaceRoot() {
  var current = Directory.current.absolute;
  while (true) {
    final sdk = File(
      p.join(
        current.path,
        'packages',
        'daemon',
        'plugin_sdk',
        'library',
        'tinest.lua',
      ),
    );
    if (sdk.existsSync()) return current;
    final parent = current.parent;
    if (p.equals(parent.path, current.path)) {
      throw StateError('Could not locate the Tinest workspace root.');
    }
    current = parent;
  }
}

Future<Directory> _installLuaLs({
  required Directory cache,
  required _LuaLsAsset asset,
  required File? suppliedArchive,
}) async {
  final distribution = Directory(
    p.join(cache.path, _version, asset.platformDirectory),
  );
  final marker = File(p.join(distribution.path, '.asset-sha256'));
  final executable = File(
    p.join(
      distribution.path,
      'bin',
      Platform.isWindows ? 'lua-language-server.exe' : 'lua-language-server',
    ),
  );
  if (marker.existsSync() &&
      executable.existsSync() &&
      (await marker.readAsString()).trim() == asset.sha256) {
    return distribution;
  }

  await cache.create(recursive: true);
  final archive = suppliedArchive ?? File(p.join(cache.path, asset.fileName));
  if (!archive.existsSync() || await _digest(archive) != asset.sha256) {
    if (suppliedArchive != null) {
      throw StateError(
        'Supplied LuaLS archive does not match ${asset.sha256}: '
        '${archive.path}',
      );
    }
    await _download(Uri.parse('$_releaseBase/${asset.fileName}'), archive);
  }
  final digest = await _digest(archive);
  if (digest != asset.sha256) {
    throw StateError(
      'LuaLS archive checksum mismatch: expected ${asset.sha256}, got $digest.',
    );
  }

  final temporary = Directory('${distribution.path}.tmp-$pid');
  if (temporary.existsSync()) await temporary.delete(recursive: true);
  await temporary.create(recursive: true);
  try {
    final extraction = await Process.run('tar', <String>[
      '-xf',
      archive.path,
      '-C',
      temporary.path,
    ], runInShell: Platform.isWindows);
    if (extraction.exitCode != 0) {
      throw StateError(
        'Failed to extract ${asset.fileName}: ${extraction.stderr as String}',
      );
    }
    final extractedExecutable = File(
      p.join(
        temporary.path,
        'bin',
        Platform.isWindows ? 'lua-language-server.exe' : 'lua-language-server',
      ),
    );
    if (!extractedExecutable.existsSync()) {
      throw StateError('LuaLS archive does not contain its executable.');
    }
    if (!Platform.isWindows) {
      final chmod = await Process.run('chmod', <String>[
        '+x',
        extractedExecutable.path,
      ]);
      if (chmod.exitCode != 0) {
        throw StateError('Could not make LuaLS executable.');
      }
    }
    await File(p.join(temporary.path, '.asset-sha256'))
        .writeAsString('${asset.sha256}\n', flush: true);
    await distribution.parent.create(recursive: true);
    if (distribution.existsSync()) await distribution.delete(recursive: true);
    await temporary.rename(distribution.path);
  } finally {
    if (temporary.existsSync()) await temporary.delete(recursive: true);
  }
  return distribution;
}

Future<void> _download(Uri uri, File destination) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'Tinest-LuaLS-conformance/1',
    );
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw StateError(
        'LuaLS download returned HTTP ${response.statusCode}: $uri',
      );
    }
    final temporary = File('${destination.path}.tmp-$pid');
    if (temporary.existsSync()) await temporary.delete();
    try {
      await temporary.parent.create(recursive: true);
      final output = temporary.openWrite();
      await response.pipe(output);
      await temporary.rename(destination.path);
    } finally {
      if (temporary.existsSync()) await temporary.delete();
    }
  } finally {
    client.close(force: true);
  }
}

Future<String> _digest(File file) async =>
    await sha256.bind(file.openRead()).first.then((value) => value.toString());

Future<void> _verifyVersion(File executable) async {
  final result = await Process.run(executable.path, const <String>[
    '--version',
  ]);
  final output = (result.stdout as String).trim();
  if (result.exitCode != 0 ||
      !RegExp(r'^3\.18\.2(?:-dev)?$').hasMatch(output)) {
    throw StateError('Unexpected LuaLS version: "$output".');
  }
}

Future<void> _runConformance({
  required Directory root,
  required Directory distribution,
  required File executable,
}) async {
  final fixtureSource = await File(
    p.join(
      root.path,
      'packages',
      'daemon',
      'tool',
      'luals_conformance',
      'fixture',
      'main.lua',
    ),
  ).readAsString();
  final workspace = await Directory.systemTemp.createTemp(
    'tinest-luals-conformance-',
  );
  try {
    final library = Directory(p.join(workspace.path, 'library'));
    await library.create(recursive: true);
    for (final asset in TinestLuaPluginSdk.authoringLibraryAssets.entries) {
      final target = File(
        p.join(workspace.path, p.joinAll(p.posix.split(asset.key))),
      );
      await target.parent.create(recursive: true);
      await target.writeAsString(asset.value);
    }
    final fixture = File(p.join(workspace.path, 'main.lua'));
    await fixture.writeAsString(fixtureSource);
    final generatedTypes = PluginTypeEnvironmentGenerator.analyze(
      pluginId: 'conformance.typed',
      sources: <String, String>{'main.lua': fixtureSource},
    );
    if (generatedTypes.diagnostics.isNotEmpty) {
      throw StateError(
        'Production type sidecar generator diagnostics: '
        '${generatedTypes.diagnostics.map((item) => item.message).join('; ')}',
      );
    }
    if (Platform.environment['TINEST_LUALS_DUMP_TYPES'] == '1') {
      stdout.writeln(generatedTypes.authoringDefinition);
    }
    final authoring = Directory(p.join(workspace.path, 'authoring'));
    await authoring.create();
    await File(
      p.join(authoring.path, PluginTypeEnvironmentGenerator.sidecarFileName),
    ).writeAsString(generatedTypes.authoringDefinition);
    await File(p.join(workspace.path, '.luarc.json'))
        .writeAsString(_luaLanguageServerConfiguration(library, authoring));

    final client = await _LspClient.start(
      executable: executable,
      distribution: distribution,
      workspace: workspace,
    );
    try {
      final uri = fixture.uri.toString();
      await client.initialize(workspace);
      client.notify('textDocument/didOpen', <String, Object?>{
        'textDocument': <String, Object?>{
          'uri': uri,
          'languageId': 'lua',
          'version': 1,
          'text': fixtureSource,
        },
      });

      await _expectCompletion(
        client,
        uri,
        _after(fixtureSource, 'args.profile.'),
        const <String>{'line'},
      );
      await _expectCompletion(
        client,
        uri,
        _after(fixtureSource, 'local sandbox_global_completion = requ'),
        const <String>{'require(module_name)'},
      );
      await _expectCompletion(
        client,
        uri,
        _after(fixtureSource, 'tinest.json.'),
        const <String>{'null', 'is_null'},
      );
      await _expectCompletion(
        client,
        uri,
        _after(fixtureSource, 'tinest.tools.'),
        const <String>{'model_input'},
      );
      await _expectCompletion(
        client,
        uri,
        _after(fixtureSource, 'tinest.host.workspace.'),
        const <String>{'read_text'},
      );
      await _expectCompletion(
        client,
        uri,
        _after(fixtureSource, 'tinest.host.process.'),
        const <String>{'read', 'write', 'interrupt', 'terminate'},
      );
      await _expectCompletion(
        client,
        uri,
        _after(fixtureSource, 'tinest.host.mcp.'),
        const <String>{'list_resources', 'invoke_tool'},
      );
      await _expectCompletion(
        client,
        uri,
        _after(fixtureSource, 'tinest.host.collaboration.'),
        const <String>{'spawn_agent', 'list_agents'},
      );
      await _expectCompletion(
        client,
        uri,
        _after(fixtureSource, 'tinest.host.attachment.'),
        const <String>{'publish', 'read'},
      );
      await _expectCompletion(
        client,
        uri,
        _after(fixtureSource, 'tinest.host.interaction.'),
        const <String>{'request_user_input'},
      );
      await _expectCompletion(
        client,
        uri,
        _after(fixtureSource, 'tinest.host.clock.'),
        const <String>{'current_time', 'sleep'},
      );
      await _expectCompletion(
        client,
        uri,
        _after(fixtureSource, 'tinest.host.skills.'),
        const <String>{'list', 'read'},
      );
      await _expectCompletion(
        client,
        uri,
        _after(fixtureSource, 'tinest.host.lua.'),
        const <String>{'start', 'read', 'terminate'},
      );
      await _expectCompletion(
        client,
        uri,
        _after(fixtureSource, 'tinest.host.network.'),
        const <String>{'request'},
      );
      await _expectCompletion(
        client,
        uri,
        _after(fixtureSource, 'tinest.host.secret.'),
        const <String>{'get'},
      );
      await _expectCompletion(
        client,
        uri,
        _after(fixtureSource, 'value.profile.'),
        const <String>{'name', 'line'},
      );
      await _expectCompletion(
        client,
        uri,
        _after(fixtureSource, 'payload.profile.'),
        const <String>{'name', 'line'},
      );
      await _expectCompletion(
        client,
        uri,
        _after(fixtureSource, 'existing.value.profile.'),
        const <String>{'name', 'line'},
      );
      await _expectCompletion(
        client,
        uri,
        _after(fixtureSource, 'status.'),
        const <String>{'active', 'completed'},
      );
      await _expectCompletion(
        client,
        uri,
        _after(fixtureSource, 'local incomplete_code = tinest.ui.code({'),
        const <String>{'code', 'language', 'wrap'},
      );
      await _expectCompletion(
        client,
        uri,
        _after(fixtureSource, 'blocks = {{'),
        const <String>{'role', 'content'},
      );
      await _expectCompletion(
        client,
        uri,
        _after(fixtureSource, 'tinest.capability.workspace.'),
        const <String>{'read', 'patch'},
      );
      await _expectCompletion(
        client,
        uri,
        _after(fixtureSource, 'tinest.effect.filesystem.'),
        const <String>{'read', 'write'},
      );
      await _expectCompletion(
        client,
        uri,
        _after(fixtureSource, 'tinest.model.role.'),
        const <String>{'system', 'user', 'assistant'},
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(fixtureSource, 'local json_value = tinest.json.null', 'null'),
        'tinest.JsonNull',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(
          fixtureSource,
          'local spec_tool = tinest.tool.function_(',
          'function_',
        ),
        'ToolSpec',
      );
      await _expectCompletion(
        client,
        uri,
        _after(
          fixtureSource,
          'local completion_tool = tinest.tool.function_({',
        ),
        const <String>{
          'id',
          'name',
          'description',
          'uses',
          'effects',
          'required_capabilities',
          'presentation',
        },
      );
      await _expectCompletion(
        client,
        uri,
        _after(
          fixtureSource,
          'local completion_driver = tinest.driver.define({',
        ),
        const <String>{
          'id',
          'uses',
          'effects',
          'required_capabilities',
          'required_model_capabilities',
          'metadata',
        },
      );
      await _expectCompletion(
        client,
        uri,
        _after(
          fixtureSource,
          'local completion_hook = tinest.hook.agent_attach({',
        ),
        const <String>{
          'id',
          'uses',
          'effects',
          'required_capabilities',
          'metadata',
        },
      );
      await _expectCompletion(
        client,
        uri,
        _after(
          fixtureSource,
          'local completion_control = tinest.session.control({',
        ),
        const <String>{
          'id',
          'uses',
          'effects',
          'required_capabilities',
          'metadata',
        },
      );
      await _expectCompletion(
        client,
        uri,
        _after(fixtureSource, 'local completion_ui = tinest.ui.contribution({'),
        const <String>{
          'id',
          'slot',
          'uses',
          'effects',
          'required_capabilities',
          'metadata',
        },
      );
      await _expectCompletion(
        client,
        uri,
        _after(fixtureSource, 'local completion_action = tinest.ui.action({'),
        const <String>{
          'id',
          'uses',
          'effects',
          'required_capabilities',
          'metadata',
        },
      );
      await _expectCompletion(
        client,
        uri,
        _after(
          fixtureSource,
          'local completion_scheduled = tinest.scheduler.handler({',
        ),
        const <String>{
          'id',
          'uses',
          'effects',
          'required_capabilities',
          'metadata',
        },
      );
      await _expectCompletion(
        client,
        uri,
        _after(
          fixtureSource,
          'local completion_definition = tinest.plugin.define({',
        ),
        const <String>{
          'driver',
          'tools',
          'templates',
          'hooks',
          'session_controls',
          'ui',
          'actions',
        },
      );
      await _expectCompletion(
        client,
        uri,
        _after(fixtureSource, 'control_context.'),
        const <String>{
          'agent_id',
          'session_id',
          'workspace_id',
          'plugin_id',
          'contribution_id',
          'value',
          'current_value',
          'settings',
        },
      );

      await _expectHoverContains(
        client,
        uri,
        _inside(fixtureSource, 'T.Input', 'Input'),
        'TypeToken',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(fixtureSource, 'args.profile.name', 'name'),
        'string',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(fixtureSource, 'args.profile.line', 'line'),
        'integer',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(fixtureSource, 'args.tags[1]', 'tags'),
        'string',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(fixtureSource, 'args.labels.primary', 'primary'),
        'string',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(fixtureSource, 'args.status', 'status'),
        'active',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(fixtureSource, 'payload.server', 'server'),
        'string',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(fixtureSource, 'snapshot.output', 'output'),
        'string',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(fixtureSource, 'event.delta', 'delta'),
        'string',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(fixtureSource, 'event.inputTokens', 'inputTokens'),
        'integer',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(fixtureSource, 'local entity_type = stat.type', 'type'),
        'WorkspaceEntityType',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(fixtureSource, 'listing.entries[1].name', 'name'),
        'string',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(fixtureSource, 'local blob_mime = blob.mime_type', 'mime_type'),
        'string',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(
          fixtureSource,
          'local wall_time = chunk.wall_time_ms',
          'wall_time_ms',
        ),
        'integer',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(
          fixtureSource,
          'local answer_text = interaction.answers[1].answer',
          'answer_text',
        ),
        'string',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(
          fixtureSource,
          'local sleep_outcome = slept.outcome',
          'outcome',
        ),
        'elapsed',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(fixtureSource, 'resources.resources[1].uri', 'uri'),
        'string',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(fixtureSource, 'catalog.tools[1].name', 'name'),
        'string',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(
          fixtureSource,
          'local task_name = spawned.task_name',
          'task_name',
        ),
        'string',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(fixtureSource, 'agents.agents[1].agent_status', 'agent_status'),
        'CollaborationAgentStatus',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(
          fixtureSource,
          'agents.agents[1].session_status',
          'session_status',
        ),
        'CollaborationSessionStatus',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(fixtureSource, 'agents.agents[1].session_id', 'session_id'),
        'string',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(
          fixtureSource,
          'local ui_dependency = tinest.ui.dependency.session_tree',
          'ui_dependency',
        ),
        'session_tree',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(
          fixtureSource,
          'local render_locale = context.locale',
          'render_locale',
        ),
        'string',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(fixtureSource, 'local lua_handle = lua_chunk.handle', 'handle'),
        'string',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(fixtureSource, 'response.body_base64', 'body_base64'),
        'string',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(fixtureSource, 'local secret_value = secret.value', 'value'),
        'string',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(
          fixtureSource,
          'local attach_agent_id = attach_context.agent_id',
          'agent_id',
        ),
        'string',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(
          fixtureSource,
          'local before_turn_id = before_context.turn_id',
          'turn_id',
        ),
        'string',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(
          fixtureSource,
          'after_model_context.usage.inputTokens',
          'inputTokens',
        ),
        'integer',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(
          fixtureSource,
          'local after_tool_error = after_tool_context.is_error',
          'is_error',
        ),
        'boolean',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(
          fixtureSource,
          'local after_turn_rounds = after_turn_context.tool_rounds',
          'tool_rounds',
        ),
        'integer',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(
          fixtureSource,
          'local ui_action_id = ui_action_context.action.actionId',
          'actionId',
        ),
        'string',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(
          fixtureSource,
          'local current_enabled = control_context.current_value.enabled',
          'enabled',
        ),
        'boolean',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(fixtureSource, 'action = spec_action', 'spec_action'),
        'ActionPayload',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(
          fixtureSource,
          'local spec_scheduled = tinest.scheduler.handler',
          'spec_scheduled',
        ),
        'Input',
      );

      await _expectSignatureContains(
        client,
        uri,
        _after(fixtureSource, 'tinest.tool.function_('),
        'function_',
      );
      await _expectSignatureContains(
        client,
        uri,
        _after(fixtureSource, 'local tinest = require('),
        'require',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(fixtureSource, 'tinest.host.workspace.read_text(', 'read_text'),
        'WorkspaceReadTextInput',
      );
      await _expectSignatureContains(
        client,
        uri,
        _after(fixtureSource, 'tinest.host.workspace.read_text('),
        'WorkspaceReadTextInput',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(fixtureSource, 'tinest.host.process.start', 'start'),
        'ProcessStartInput',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(
          fixtureSource,
          'tinest.host.mcp.read_resource',
          'read_resource',
        ),
        'McpReadResourceInput',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(fixtureSource, 'tinest.host.network.request', 'request'),
        'NetworkRequestInput',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(fixtureSource, 'tinest.host.secret.get', 'get'),
        'SecretGetInput',
      );
      await _expectSignatureContains(
        client,
        uri,
        _after(fixtureSource, 'tinest.ui.contribution('),
        'contribution',
      );
      await _expectSignatureContains(
        client,
        uri,
        _after(fixtureSource, 'tinest.scheduler.handler('),
        'handler',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(fixtureSource, 'state_cell:transaction', 'transaction'),
        'StateMutation',
      );
      await _expectHoverContains(
        client,
        uri,
        _inside(
          fixtureSource,
          'local transaction_name = '
              'transaction_result.typed.value.profile.name',
          'transaction_name',
        ),
        'string',
      );
      await _expectSignatureContains(
        client,
        uri,
        _after(fixtureSource, 'tinest.tool.dynamic('),
        'dynamic',
      );
      await _expectSignatureContains(
        client,
        uri,
        _after(fixtureSource, 'tinest.tool.dynamic_from('),
        'dynamic_from',
      );
      await _expectSignatureContains(
        client,
        uri,
        _after(fixtureSource, 'tinest.model.open('),
        'open',
      );

      final diagnostics = await client.diagnostics(uri);
      _expectDiagnosticAt(
        fixtureSource,
        diagnostics,
        'local missing = args.profile.nonexistent',
      );
      _expectDiagnosticAt(fixtureSource, diagnostics, 'return {text = 42');
      _expectDiagnosticAt(fixtureSource, diagnostics, 'read_text({path = 42');
      _expectDiagnosticAt(fixtureSource, diagnostics, 'status.missing');
      _expectDiagnosticAt(fixtureSource, diagnostics, 'start({command = 42');
      _expectDiagnosticAt(fixtureSource, diagnostics, 'publish({path = 42');
      _expectDiagnosticAt(fixtureSource, diagnostics, 'questions = "bad"');
      _expectDiagnosticAt(fixtureSource, diagnostics, 'duration_ms = "bad"');
      _expectDiagnosticAt(fixtureSource, diagnostics, 'skills.read({name = 42');
      _expectDiagnosticAt(fixtureSource, diagnostics, 'server = 42');
      _expectDiagnosticAt(fixtureSource, diagnostics, 'target = 42');
      _expectDiagnosticAt(fixtureSource, diagnostics, 'lua.start({source = 42');
      _expectDiagnosticAt(fixtureSource, diagnostics, 'request({url = 42');
      _expectDiagnosticAt(fixtureSource, diagnostics, 'secret.get({name = 42');
      _expectDiagnosticAt(
        fixtureSource,
        diagnostics,
        'transaction({mutations = {}',
      );
      _expectDiagnosticAt(
        fixtureSource,
        diagnostics,
        'process.read({handle = "wrong"',
      );
      _expectDiagnosticAt(fixtureSource, diagnostics, 'current_time("+09:00")');
      _expectDiagnosticAt(fixtureSource, diagnostics, 'ui.text({text = 42');
      _expectDiagnosticAt(
        fixtureSource,
        diagnostics,
        'role = tinest.model.role.user, content = 42',
      );
      _expectDiagnosticAt(fixtureSource, diagnostics, 'io.open');
      _expectDiagnosticAt(fixtureSource, diagnostics, 'os.execute');
      _expectDiagnosticAt(fixtureSource, diagnostics, 'package.loadlib');
      _expectDiagnosticAt(fixtureSource, diagnostics, 'debug.traceback');
      _expectDiagnosticCodeAt(
        fixtureSource,
        diagnostics,
        'host.call("unsafe"',
        'undefined-global',
      );
      _expectDiagnosticCodeAt(
        fixtureSource,
        diagnostics,
        'assets.read("unsafe"',
        'undefined-global',
      );
      _expectDiagnosticCodeAt(
        fixtureSource,
        diagnostics,
        'tools.invoke("unsafe"',
        'undefined-global',
      );
      _expectDiagnosticCodeAt(
        fixtureSource,
        diagnostics,
        'store("unsafe"',
        'undefined-global',
      );
      _expectDiagnosticCodeAt(
        fixtureSource,
        diagnostics,
        'load("unsafe"',
        'undefined-global',
      );
      for (final unavailable in const <String>[
        'loadfile("unsafe"',
        'dofile("unsafe"',
        'collectgarbage("collect"',
        'rawget({}, "unsafe"',
        'setmetatable({}, {})',
        'coroutine.create(',
        'spawn(function()',
        'await(nil)',
        'text("unsafe")',
        'set_timeout(function()',
      ]) {
        _expectDiagnosticCodeAt(
          fixtureSource,
          diagnostics,
          unavailable,
          'undefined-global',
        );
      }
      _expectDiagnosticCodeAt(
        fixtureSource,
        diagnostics,
        'raw_tools = ALL_TOOLS',
        'undefined-global',
      );
      _expectDiagnosticAt(
        fixtureSource,
        diagnostics,
        'attach_context.missing_attach',
      );
      _expectDiagnosticAt(
        fixtureSource,
        diagnostics,
        'before_context.missing_before_turn',
      );
      _expectDiagnosticAt(
        fixtureSource,
        diagnostics,
        'after_model_context.missing_after_model',
      );
      _expectDiagnosticAt(
        fixtureSource,
        diagnostics,
        'after_tool_context.missing_after_tool',
      );
      _expectDiagnosticAt(
        fixtureSource,
        diagnostics,
        'after_turn_context.missing_after_turn',
      );
      _expectDiagnosticAt(
        fixtureSource,
        diagnostics,
        'ui_action_context.missing_ui_action',
      );
      _expectDiagnosticAt(
        fixtureSource,
        diagnostics,
        'control_context.missing_session_control',
      );
      _expectDiagnosticAt(fixtureSource, diagnostics, '"not.an.effect"');
      _expectDiagnosticAt(fixtureSource, diagnostics, '"not.a.capability"');
      _expectDiagnosticAt(
        fixtureSource,
        diagnostics,
        '"not.a.model.capability"',
      );
      _expectDiagnosticAt(
        fixtureSource,
        diagnostics,
        'payload.missing_scheduled_field',
      );
      _expectDiagnosticCodeAt(
        fixtureSource,
        diagnostics,
        'magic_json_null = NULL',
        'undefined-global',
      );
      _expectNoDiagnosticAt(
        fixtureSource,
        diagnostics,
        'local json_value = tinest.json.null',
      );
      _expectNoDiagnosticAt(
        fixtureSource,
        diagnostics,
        'local json_value_is_null = tinest.json.is_null(json_value)',
      );
      _expectNoDiagnosticAt(fixtureSource, diagnostics, 'require("tinest")');
    } finally {
      await client.close();
    }
  } finally {
    if (workspace.existsSync()) await workspace.delete(recursive: true);
  }
}

String _luaLanguageServerConfiguration(Directory library, Directory authoring) {
  const disabledBuiltins = <String, String>{
    'basic': 'disable',
    'bit': 'disable',
    'bit32': 'disable',
    'coroutine': 'disable',
    'debug': 'disable',
    'ffi': 'disable',
    'io': 'disable',
    'jit': 'disable',
    'os': 'disable',
    'package': 'disable',
    'string.buffer': 'disable',
    'table.clear': 'disable',
    'table.new': 'disable',
  };
  final configuration = <String, Object?>{
    'runtime': <String, Object?>{
      'version': 'Lua 5.5',
      'path': <String>['?.lua', '?/init.lua'],
      'pathStrict': true,
      'builtin': disabledBuiltins,
    },
    'workspace': <String, Object?>{
      'library': <String>[library.path, authoring.path],
      'checkThirdParty': 'Disable',
    },
    'diagnostics': <String, Object?>{
      'enable': true,
      'workspaceDelay': 0,
      'workspaceRate': 100,
      'globals': <String>[],
    },
    'type': <String, Object?>{'checkTableShape': true},
  };
  return '${const JsonEncoder.withIndent('  ').convert(configuration)}\n';
}

Future<void> _runPackageTypechecks({
  required Directory root,
  required File executable,
}) async {
  final workspace = await Directory.systemTemp.createTemp(
    'tinest-luals-packages-',
  );
  final catalog = NativePluginSourceCatalog(workspace.path);
  try {
    final library = Directory(p.join(workspace.path, 'library'));
    await library.create(recursive: true);
    for (final asset in TinestLuaPluginSdk.authoringLibraryAssets.entries) {
      final target = File(
        p.join(workspace.path, p.joinAll(p.posix.split(asset.key))),
      );
      await target.parent.create(recursive: true);
      await target.writeAsString(asset.value);
    }

    await catalog.scaffold('conformance.scaffold', 'Conformance scaffold');
    final packages = <({String id, Directory source})>[
      for (final source
          in (Directory(
              p.join(root.path, 'packages', 'daemon', 'builtin_plugins'),
            ).listSync(followLinks: false)
            ..sort((left, right) => left.path.compareTo(right.path))))
        if (source is Directory) (id: p.basename(source.path), source: source),
      (
        id: 'conformance.scaffold',
        source: Directory(
          p.join(workspace.path, 'v5', 'plugins', 'conformance.scaffold'),
        ),
      ),
    ];

    for (final package in packages) {
      final plugin = Directory(
        p.join(workspace.path, 'checks', package.id, 'plugin'),
      );
      final sources = <String, String>{};
      await for (final entity in package.source.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File || p.extension(entity.path) != '.lua') continue;
        final relative = p.relative(entity.path, from: package.source.path);
        final assetPath = p.posix.joinAll(p.split(relative));
        final source = await entity.readAsString();
        sources[assetPath] = source;
        final target = File(
          p.join(plugin.path, p.joinAll(p.posix.split(assetPath))),
        );
        await target.parent.create(recursive: true);
        await target.writeAsString(source);
      }
      if (sources.isEmpty) {
        throw StateError('Plugin package has no Lua sources: ${package.id}.');
      }

      final generatedTypes = PluginTypeEnvironmentGenerator.analyze(
        pluginId: package.id,
        sources: sources,
      );
      if (generatedTypes.diagnostics.isNotEmpty) {
        final details = generatedTypes.diagnostics
            .map(
              (item) =>
                  '${item.path}:${item.line}:${item.column} '
                  '${item.message}',
            )
            .join('; ');
        throw StateError(
          'Type sidecar generator rejected ${package.id}: $details',
        );
      }
      final authoring = Directory(
        p.join(workspace.path, 'checks', package.id, 'authoring'),
      );
      await authoring.create(recursive: true);
      await File(
        p.join(authoring.path, PluginTypeEnvironmentGenerator.sidecarFileName),
      ).writeAsString(generatedTypes.authoringDefinition);
      await File(p.join(plugin.path, '.luarc.json'))
          .writeAsString(_luaLanguageServerConfiguration(library, authoring));

      final result = await Process.run(executable.path, <String>[
        '--check=${plugin.path}',
        '--checklevel=Information',
        '--check_format=pretty',
      ], workingDirectory: plugin.path);
      if (result.exitCode != 0) {
        throw StateError(
          'LuaLS rejected ${package.id}:\n${result.stdout}${result.stderr}',
        );
      }
    }
  } finally {
    await catalog.close();
    if (workspace.existsSync()) await workspace.delete(recursive: true);
  }
}

Future<void> _expectCompletion(
  _LspClient client,
  String uri,
  _Position position,
  Set<String> expected,
) async {
  final labels = <String>{};
  for (var attempt = 0; attempt < 20; attempt += 1) {
    final result = await client.request(
      'textDocument/completion',
      <String, Object?>{
        'textDocument': <String, Object?>{'uri': uri},
        'position': position.toJson(),
      },
    );
    final values = switch (result) {
      final List<Object?> value => value,
      final Map<Object?, Object?> value =>
        (_jsonMap(value)['items'] as List<Object?>?) ?? const <Object?>[],
      _ => const <Object?>[],
    };
    for (final value in values) {
      if (value is Map<Object?, Object?>) {
        final label = _jsonMap(value)['label'];
        if (label is String) labels.add(label.replaceFirst(RegExp(r'\?$'), ''));
      }
    }
    if (labels.containsAll(expected)) return;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  throw StateError(
    'Completion at ${position.line}:${position.character} omitted '
    '${expected.difference(labels)}. Got: $labels',
  );
}

Future<void> _expectHoverContains(
  _LspClient client,
  String uri,
  _Position position,
  String expected,
) async {
  final result = await client.request('textDocument/hover', <String, Object?>{
    'textDocument': <String, Object?>{'uri': uri},
    'position': position.toJson(),
  });
  final rendered = jsonEncode(result);
  if (Platform.environment['TINEST_LUALS_DEBUG'] == '1') {
    stdout.writeln('hover ${position.line}:${position.character}: $rendered');
  }
  if (!rendered.toLowerCase().contains(expected.toLowerCase())) {
    throw StateError('Hover omitted "$expected": $rendered');
  }
}

Future<void> _expectSignatureContains(
  _LspClient client,
  String uri,
  _Position position,
  String expected,
) async {
  final result = await client.request(
    'textDocument/signatureHelp',
    <String, Object?>{
      'textDocument': <String, Object?>{'uri': uri},
      'position': position.toJson(),
      'context': <String, Object?>{'triggerKind': 1, 'isRetrigger': false},
    },
  );
  final rendered = jsonEncode(result);
  if (!rendered.contains(expected)) {
    throw StateError('Signature help omitted "$expected": $rendered');
  }
}

void _expectDiagnosticAt(
  String source,
  List<Map<String, Object?>> diagnostics,
  String needle,
) {
  final line = _position(source, source.indexOf(needle)).line;
  final matching = diagnostics
      .where((diagnostic) {
        final range = diagnostic['range'];
        if (range is! Map<Object?, Object?>) return false;
        final start = _jsonMap(range)['start'];
        return start is Map<Object?, Object?> &&
            _jsonMap(start)['line'] == line;
      })
      .toList(growable: false);
  if (matching.isEmpty) {
    throw StateError(
      'Expected a diagnostic at "$needle" (line ${line + 1}). '
      'Got: ${jsonEncode(diagnostics)}',
    );
  }
}

void _expectDiagnosticCodeAt(
  String source,
  List<Map<String, Object?>> diagnostics,
  String needle,
  String code,
) {
  final offset = source.indexOf(needle);
  if (offset < 0) throw StateError('Fixture marker not found: $needle');
  final line = _position(source, offset).line;
  final matching = diagnostics.where((diagnostic) {
    final range = diagnostic['range'];
    if (range is! Map<Object?, Object?>) return false;
    final start = _jsonMap(range)['start'];
    if (start is! Map<Object?, Object?>) return false;
    return _jsonMap(start)['line'] == line && diagnostic['code'] == code;
  });
  if (matching.isEmpty) {
    throw StateError(
      'Expected diagnostic $code at "$needle" (line ${line + 1}). '
      'Got: ${jsonEncode(diagnostics)}',
    );
  }
}

void _expectNoDiagnosticAt(
  String source,
  List<Map<String, Object?>> diagnostics,
  String needle,
) {
  final line = _position(source, source.indexOf(needle)).line;
  final matching = diagnostics
      .where((diagnostic) {
        final range = diagnostic['range'];
        if (range is! Map<Object?, Object?>) return false;
        final start = _jsonMap(range)['start'];
        return start is Map<Object?, Object?> &&
            _jsonMap(start)['line'] == line;
      })
      .toList(growable: false);
  if (matching.isNotEmpty) {
    throw StateError(
      'Did not expect a diagnostic at "$needle": ${jsonEncode(matching)}',
    );
  }
}

_Position _after(String source, String needle) {
  final index = source.indexOf(needle);
  if (index < 0) throw StateError('Fixture marker not found: $needle');
  return _position(source, index + needle.length);
}

_Position _inside(String source, String needle, String member) {
  final index = source.indexOf(needle);
  if (index < 0) throw StateError('Fixture marker not found: $needle');
  final memberIndex = source.indexOf(member, index);
  return _position(source, memberIndex + 1);
}

_Position _position(String source, int offset) {
  final before = source.substring(0, offset);
  final lines = before.split('\n');
  return _Position(lines.length - 1, lines.last.length);
}

Map<String, Object?> _jsonMap(Map<Object?, Object?> value) => <String, Object?>{
  for (final entry in value.entries)
    if (entry.key is String) entry.key! as String: entry.value,
};

final class _LspClient {
  new _(this._process) {
    _process.stdout.listen(_receive, onDone: _stdoutDone.complete);
    _process.stderr.transform(utf8.decoder).listen((value) {
      if (_stderr.length < 8192) _stderr.write(value);
    });
  }

  static Future<_LspClient> start({
    required File executable,
    required Directory distribution,
    required Directory workspace,
  }) async {
    final process = await Process.start(executable.path, <String>[
      '--logpath=${p.join(workspace.path, 'log')}',
      '--metapath=${p.join(distribution.path, 'meta')}',
    ], workingDirectory: distribution.path);
    return _LspClient._(process);
  }

  final Process _process;
  final List<int> _buffer = <int>[];
  final Map<int, Completer<Object?>> _requests = <int, Completer<Object?>>{};
  final Map<String, List<Map<String, Object?>>> _diagnostics =
      <String, List<Map<String, Object?>>>{};
  final Map<String, Completer<List<Map<String, Object?>>>> _diagnosticWaiters =
      <String, Completer<List<Map<String, Object?>>>>{};
  final Completer<void> _stdoutDone = Completer<void>();
  final StringBuffer _stderr = StringBuffer();
  var _nextId = 0;

  Future<void> initialize(Directory workspace) async {
    final uri = workspace.uri.toString();
    await request('initialize', <String, Object?>{
      'processId': pid,
      'clientInfo': <String, Object?>{
        'name': 'Tinest Lua SDK conformance',
        'version': '1',
      },
      'locale': 'en-US',
      'rootUri': uri,
      'workspaceFolders': <Object?>[
        <String, Object?>{'uri': uri, 'name': 'conformance'},
      ],
      'capabilities': <String, Object?>{
        'workspace': <String, Object?>{
          'configuration': true,
          'workspaceFolders': true,
        },
        'textDocument': <String, Object?>{
          'completion': <String, Object?>{
            'completionItem': <String, Object?>{'snippetSupport': false},
          },
          'hover': <String, Object?>{
            'contentFormat': <String>['markdown', 'plaintext'],
          },
          'publishDiagnostics': <String, Object?>{
            'relatedInformation': true,
            'tagSupport': <String, Object?>{
              'valueSet': <int>[1, 2],
            },
          },
          'signatureHelp': <String, Object?>{
            'signatureInformation': <String, Object?>{
              'documentationFormat': <String>['markdown', 'plaintext'],
            },
          },
        },
        'general': <String, Object?>{
          'positionEncodings': <String>['utf-16'],
        },
      },
    });
    notify('initialized', const <String, Object?>{});
  }

  Future<Object?> request(String method, Map<String, Object?> params) {
    final id = ++_nextId;
    final completer = Completer<Object?>();
    _requests[id] = completer;
    _send(<String, Object?>{
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    });
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () =>
          throw TimeoutException('LuaLS request timed out: $method. $_stderr'),
    );
  }

  void notify(String method, Map<String, Object?> params) {
    _send(<String, Object?>{
      'jsonrpc': '2.0',
      'method': method,
      'params': params,
    });
  }

  Future<List<Map<String, Object?>>> diagnostics(String uri) async {
    final existing = _diagnostics.entries
        .where((entry) => _sameDocumentUri(entry.key, uri))
        .map((entry) => entry.value)
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    if (existing != null && existing.isNotEmpty) return existing;
    // Asking again rather than waiting on one push. LuaLS answers only once it
    // has finished indexing the library, and how long that takes scales with
    // the SDK it is indexing and with what else the runner is doing. A single
    // armed waiter turns that into one edge to catch inside a fixed window,
    // which is a race the tool loses on a loaded machine and never loses
    // locally. Re-asking makes the wait a level check: whichever of the pull
    // and the push answers first ends it.
    final completer = _diagnosticWaiters.putIfAbsent(
      uri,
      Completer<List<Map<String, Object?>>>.new,
    );
    final waited = Stopwatch()..start();
    while (waited.elapsed < const Duration(minutes: 3)) {
      try {
        final result = await request(
          'textDocument/diagnostic',
          <String, Object?>{
            'textDocument': <String, Object?>{'uri': uri},
          },
        );
        if (result is Map<Object?, Object?>) {
          final items = _jsonMap(result)['items'];
          if (items is List<Object?> && items.isNotEmpty) {
            _diagnosticWaiters.remove(uri);
            return <Map<String, Object?>>[
              for (final value in items)
                if (value is Map<Object?, Object?>) _jsonMap(value),
            ];
          }
        }
      } on _LspRequestException {
        // LuaLS may use push diagnostics only; the waiter below covers it.
      }
      if (completer.isCompleted) return await completer.future;
      final pushed = await completer.future
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () => const <Map<String, Object?>>[],
          )
          .catchError((_) => const <Map<String, Object?>>[]);
      if (pushed.isNotEmpty) return pushed;
    }
    throw TimeoutException(
      'LuaLS did not publish diagnostics. Seen: ${_diagnostics.keys}. '
      '$_stderr',
    );
  }

  void _send(Map<String, Object?> message) {
    final payload = utf8.encode(jsonEncode(message));
    _process.stdin.add(<int>[
      ...ascii.encode('Content-Length: ${payload.length}\r\n\r\n'),
      ...payload,
    ]);
  }

  void _receive(List<int> bytes) {
    _buffer.addAll(bytes);
    while (true) {
      final separator = _indexOf(_buffer, const <int>[13, 10, 13, 10]);
      if (separator < 0) return;
      final header = ascii.decode(_buffer.sublist(0, separator));
      final match = RegExp(
        r'(?:^|\r\n)Content-Length: ([0-9]+)',
        caseSensitive: false,
      ).firstMatch(header);
      if (match == null) throw StateError('Invalid LuaLS frame: $header');
      final length = int.parse(match.group(1)!);
      final bodyStart = separator + 4;
      if (_buffer.length < bodyStart + length) return;
      final body = _buffer.sublist(bodyStart, bodyStart + length);
      _buffer.removeRange(0, bodyStart + length);
      final Object? decoded = jsonDecode(utf8.decode(body));
      if (decoded is! Map<Object?, Object?>) {
        throw StateError('LuaLS emitted a non-object message.');
      }
      _handle(_jsonMap(decoded));
    }
  }

  void _handle(Map<String, Object?> message) {
    final method = message['method'];
    final id = message['id'];
    if (method is String) {
      final params = message['params'];
      final parameters = params is Map<Object?, Object?>
          ? _jsonMap(params)
          : const <String, Object?>{};
      if (id is int) {
        final result = switch (method) {
          'workspace/configuration' => <Object?>[
            for (final _
                in (parameters['items'] as List<Object?>?) ?? const <Object?>[])
              null,
          ],
          'workspace/applyEdit' => <String, Object?>{'applied': false},
          _ => null,
        };
        _send(<String, Object?>{'jsonrpc': '2.0', 'id': id, 'result': result});
        return;
      }
      if (method == 'textDocument/publishDiagnostics') {
        final uri = parameters['uri'];
        final raw = parameters['diagnostics'];
        if (uri is String && raw is List<Object?>) {
          final diagnostics = <Map<String, Object?>>[
            for (final value in raw)
              if (value is Map<Object?, Object?>) _jsonMap(value),
          ];
          _diagnostics[uri] = diagnostics;
          if (diagnostics.isNotEmpty) {
            for (final entry in _diagnosticWaiters.entries.toList()) {
              if (_sameDocumentUri(entry.key, uri)) {
                final waiter = _diagnosticWaiters.remove(entry.key);
                if (waiter != null && !waiter.isCompleted) {
                  waiter.complete(diagnostics);
                }
              }
            }
          }
        }
      }
      return;
    }
    if (id is int) {
      final completer = _requests.remove(id);
      if (completer == null) return;
      final error = message['error'];
      if (error != null) {
        completer.completeError(_LspRequestException(error));
      } else {
        completer.complete(message['result']);
      }
    }
  }

  Future<void> close() async {
    try {
      await request(
        'shutdown',
        const <String, Object?>{},
      ).timeout(const Duration(seconds: 5));
      notify('exit', const <String, Object?>{});
      await _process.exitCode.timeout(const Duration(seconds: 5));
    } on Object {
      _process.kill();
      await _process.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () => -1,
      );
    }
    await _process.stdin.close();
  }
}

bool _sameDocumentUri(String left, String right) {
  try {
    final leftPath = File.fromUri(Uri.parse(left)).resolveSymbolicLinksSync();
    final rightPath = File.fromUri(Uri.parse(right)).resolveSymbolicLinksSync();
    return p.equals(leftPath, rightPath);
  } on FileSystemException {
    return left == right;
  }
}

int _indexOf(List<int> haystack, List<int> needle) {
  for (var start = 0; start <= haystack.length - needle.length; start += 1) {
    var matches = true;
    for (var offset = 0; offset < needle.length; offset += 1) {
      if (haystack[start + offset] != needle[offset]) {
        matches = false;
        break;
      }
    }
    if (matches) return start;
  }
  return -1;
}

final class _LuaLsAsset {
  const new({required this.fileName, required this.sha256});

  final String fileName;
  final String sha256;

  String get platformDirectory => fileName
      .replaceFirst('lua-language-server-$_version-', '')
      .replaceFirst('.tar.gz', '')
      .replaceFirst('.zip', '');
}

final class _LspRequestException implements Exception {
  const new(this.error);

  final Object error;

  @override
  String toString() => 'LuaLS request failed: $error';
}

final class _Position {
  const new(this.line, this.character);

  final int line;
  final int character;

  Map<String, Object?> toJson() => <String, Object?>{
    'line': line,
    'character': character,
  };
}
