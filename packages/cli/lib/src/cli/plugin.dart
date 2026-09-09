import 'package:cli/src/cli/context.dart';
import 'package:cli/src/cli/shared_flags.dart';
import 'package:cli/src/plugin_cli.dart';
import 'package:cliweave/cliweave.dart';

final Command<TinestCliContext> _initCommand = buildCommand(
  docs: const CommandDocs(
    brief: 'Scaffold a Lua plugin in the daemon app-data directory',
  ),
  parameters: CommandParameters(
    flags: daemonConnectionFlagSet()
        .and(
          ParsedFlag.required<String, TinestCliContext>(
            name: 'name',
            brief: 'Plugin display name',
            parse: stringParser,
            placeholder: 'name',
          ),
        )
        .map((values) => (daemon: values.$1, name: values.$2)),
    positional: PositionalSet.one(
      Positional.required<String, TinestCliContext>(
        brief: 'Namespaced plugin ID',
        parse: stringParser,
        placeholder: 'id',
      ),
    ).map((id) => (id: id)),
  ),
  func: (context, flags, args) => withDaemon(
    context,
    flags.daemon,
    (client) => pluginInit(
      backend: PluginsApiPluginCliBackend(client.plugins),
      output: context.output,
      id: args.id,
      name: flags.name,
    ),
  ),
);

FlagSet<({DaemonConnectionFlags daemon, bool json}), TinestCliContext>
_pluginJsonFlags() => daemonConnectionFlagSet()
    .and(
      BooleanFlag.required<TinestCliContext>(
        name: 'json',
        brief: 'Print machine-readable JSON',
        withNegated: false,
      ),
    )
    .map((values) => (daemon: values.$1, json: values.$2));

final Command<TinestCliContext> _validateCommand = buildCommand(
  docs: const CommandDocs(
    brief: 'Validate an app-data plugin without activating it',
  ),
  parameters: CommandParameters(
    flags: _pluginJsonFlags(),
    positional: PositionalSet.one(
      Positional.required<String, TinestCliContext>(
        brief: 'Namespaced plugin ID',
        parse: stringParser,
        placeholder: 'id',
      ),
    ).map((id) => (id: id)),
  ),
  func: (context, flags, args) => withDaemon(
    context,
    flags.daemon,
    (client) => pluginValidate(
      backend: PluginsApiPluginCliBackend(client.plugins),
      output: context.output,
      id: args.id,
      json: flags.json,
    ),
  ),
);

final Command<TinestCliContext> _sdkSyncCommand = buildCommand(
  docs: const CommandDocs(
    brief: 'Synchronize the exact Lua SDK ABI and LuaLS configuration',
  ),
  parameters: CommandParameters(
    flags: daemonConnectionFlagSet(),
    positional: PositionalSet.one(
      Positional.required<String, TinestCliContext>(
        brief: 'Namespaced plugin ID',
        parse: stringParser,
        placeholder: 'id',
      ),
    ).map((id) => (id: id)),
  ),
  func: (context, flags, args) => withDaemon(
    context,
    flags,
    (client) => pluginSdkSync(
      backend: PluginsApiPluginCliBackend(client.plugins),
      output: context.output,
      id: args.id,
    ),
  ),
);

final Command<TinestCliContext> _doctorCommand = buildCommand(
  docs: const CommandDocs(
    brief: 'Check the plugin SDK ABI and installed Lua Language Server',
  ),
  parameters: CommandParameters(
    flags: _pluginJsonFlags(),
    positional: PositionalSet.one(
      Positional.required<String, TinestCliContext>(
        brief: 'Namespaced plugin ID',
        parse: stringParser,
        placeholder: 'id',
      ),
    ).map((id) => (id: id)),
  ),
  func: (context, flags, args) => withDaemon(
    context,
    flags.daemon,
    (client) => pluginDoctor(
      backend: PluginsApiPluginCliBackend(client.plugins),
      runProcess: context.runPluginProcess,
      output: context.output,
      id: args.id,
      json: flags.json,
    ),
  ),
);

final Command<TinestCliContext> _typecheckCommand = buildCommand(
  docs: const CommandDocs(
    brief: 'Type-check one app-data plugin with Lua Language Server',
  ),
  parameters: CommandParameters(
    flags: _pluginJsonFlags(),
    positional: PositionalSet.one(
      Positional.required<String, TinestCliContext>(
        brief: 'Namespaced plugin ID',
        parse: stringParser,
        placeholder: 'id',
      ),
    ).map((id) => (id: id)),
  ),
  func: (context, flags, args) => withDaemon(
    context,
    flags.daemon,
    (client) => pluginTypecheck(
      backend: PluginsApiPluginCliBackend(client.plugins),
      runProcess: context.runPluginProcess,
      output: context.output,
      id: args.id,
      json: flags.json,
    ),
  ),
);

final Command<TinestCliContext> _forkCommand = buildCommand(
  docs: const CommandDocs(
    brief: 'Fork a validated plugin into the app-data directory',
  ),
  parameters: CommandParameters(
    flags: daemonConnectionFlagSet()
        .and(
          ParsedFlag.required<String, TinestCliContext>(
            name: 'id',
            brief: 'Namespaced ID for the fork',
            parse: stringParser,
            placeholder: 'id',
          ),
        )
        .and(
          ParsedFlag.required<String, TinestCliContext>(
            name: 'name',
            brief: 'Plugin display name',
            parse: stringParser,
            placeholder: 'name',
          ),
        )
        .map(
          (values) => (daemon: values.$1.$1, id: values.$1.$2, name: values.$2),
        ),
    positional: PositionalSet.one(
      Positional.required<String, TinestCliContext>(
        brief: 'Installed plugin ID to fork',
        parse: stringParser,
        placeholder: 'source-id',
      ),
    ).map((sourceId) => (sourceId: sourceId)),
  ),
  func: (context, flags, args) => withDaemon(
    context,
    flags.daemon,
    (client) => pluginFork(
      backend: PluginsApiPluginCliBackend(client.plugins),
      output: context.output,
      sourceId: args.sourceId,
      id: flags.id,
      name: flags.name,
    ),
  ),
);

final Command<TinestCliContext> _reloadCommand = buildCommand(
  docs: const CommandDocs(brief: 'Activate a plugin revision for one Agent'),
  parameters: CommandParameters(
    flags: daemonConnectionFlagSet()
        .and(
          ParsedFlag.required<String, TinestCliContext>(
            name: 'agent',
            brief: 'Agent whose grants authorize the revision',
            parse: stringParser,
            placeholder: 'id',
          ),
        )
        .map((values) => (daemon: values.$1, agentId: values.$2)),
    positional: PositionalSet.one(
      Positional.required<String, TinestCliContext>(
        brief: 'Namespaced plugin ID',
        parse: stringParser,
        placeholder: 'id',
      ),
    ).map((id) => (id: id)),
  ),
  func: (context, flags, args) => withDaemon(
    context,
    flags.daemon,
    (client) => pluginReload(
      backend: PluginsApiPluginCliBackend(client.plugins),
      output: context.output,
      id: args.id,
      agentId: flags.agentId,
    ),
  ),
);

final Command<TinestCliContext> _secretSetCommand = buildCommand(
  docs: const CommandDocs(
    brief: 'Prompt for and store an Agent-isolated plugin secret',
  ),
  parameters: CommandParameters(
    flags: daemonConnectionFlagSet()
        .and(
          ParsedFlag.required<String, TinestCliContext>(
            name: 'agent',
            brief: 'Agent allowed to expose the secret to this plugin',
            parse: stringParser,
            placeholder: 'id',
          ),
        )
        .and(
          ParsedFlag.required<String, TinestCliContext>(
            name: 'name',
            brief: 'Secret name visible to Lua',
            parse: stringParser,
            placeholder: 'name',
          ),
        )
        .map(
          (values) =>
              (daemon: values.$1.$1, agentId: values.$1.$2, name: values.$2),
        ),
    positional: PositionalSet.one(
      Positional.required<String, TinestCliContext>(
        brief: 'Namespaced plugin ID',
        parse: stringParser,
        placeholder: 'id',
      ),
    ).map((id) => (id: id)),
  ),
  func: (context, flags, args) async {
    final value = await context.readSecret();
    return await withDaemon(
      context,
      flags.daemon,
      (client) => pluginSecretSet(
        backend: PluginsApiPluginCliBackend(client.plugins),
        output: context.output,
        pluginId: args.id,
        agentId: flags.agentId,
        name: flags.name,
        value: value,
      ),
    );
  },
);

final Command<TinestCliContext> _secretRemoveCommand = buildCommand(
  docs: const CommandDocs(brief: 'Remove one Agent-isolated plugin secret'),
  parameters: CommandParameters(
    flags: daemonConnectionFlagSet()
        .and(
          ParsedFlag.required<String, TinestCliContext>(
            name: 'agent',
            brief: 'Agent that owns the plugin secret',
            parse: stringParser,
            placeholder: 'id',
          ),
        )
        .and(
          ParsedFlag.required<String, TinestCliContext>(
            name: 'name',
            brief: 'Secret name visible to Lua',
            parse: stringParser,
            placeholder: 'name',
          ),
        )
        .map(
          (values) =>
              (daemon: values.$1.$1, agentId: values.$1.$2, name: values.$2),
        ),
    positional: PositionalSet.one(
      Positional.required<String, TinestCliContext>(
        brief: 'Namespaced plugin ID',
        parse: stringParser,
        placeholder: 'id',
      ),
    ).map((id) => (id: id)),
  ),
  func: (context, flags, args) => withDaemon(
    context,
    flags.daemon,
    (client) => pluginSecretRemove(
      backend: PluginsApiPluginCliBackend(client.plugins),
      output: context.output,
      pluginId: args.id,
      agentId: flags.agentId,
      name: flags.name,
    ),
  ),
);

final RouteMap<TinestCliContext> _secretRoutes = buildRouteMap(
  docs: const RouteMapDocs(brief: 'Provision Agent-isolated plugin secrets'),
  routes: <String, RoutingTarget<TinestCliContext>>{
    'set': _secretSetCommand,
    'remove': _secretRemoveCommand,
  },
);

/// The `tinest-cli plugin` route map.
RouteMap<TinestCliContext> buildPluginRoutes() => buildRouteMap(
  docs: const RouteMapDocs(brief: 'Develop app-data Lua plugins'),
  routes: <String, RoutingTarget<TinestCliContext>>{
    'init': _initCommand,
    'fork': _forkCommand,
    'validate': _validateCommand,
    'sdk-sync': _sdkSyncCommand,
    'doctor': _doctorCommand,
    'typecheck': _typecheckCommand,
    'reload': _reloadCommand,
    'secret': _secretRoutes,
  },
);
