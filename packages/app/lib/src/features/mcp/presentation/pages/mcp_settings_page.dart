import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/app/app_identity.dart';
import 'package:app/src/features/mcp/application/mcp_servers_controller.dart';
import 'package:app/src/shared/presentation/settings_layout.dart';
import 'package:app/src/shared/presentation/tinest_icons.dart';
import 'package:app/src/shared/presentation/tinest_layout_metrics.dart';
import 'package:app/src/shared/presentation/tinest_list_row.dart';
import 'package:app/src/shared/presentation/tinest_selection_row.dart';
import 'package:app/src/shared/presentation/toast_messenger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// The literal reference syntax an MCP value may use.
///
/// Not localized: these are tokens the daemon parses, not prose.
const String mcpSecretSyntax = r'${secret:name}   ${env:NAME}';

/// Two-pane editor for one daemon's MCP servers.
class McpSettingsPage extends ConsumerWidget {
  /// Creates the MCP settings page.
  const McpSettingsPage({
    required this.hostId,
    required this.paneController,
    required this.slot,
    this.worktreeId,
    super.key,
  });

  /// Daemon whose servers are shown.
  final String hostId;

  /// Worktree whose repository-declared servers are shown, when one is open.
  final String? worktreeId;

  /// Selection shared by the collection and detail scaffold slots.
  final McpSettingsPaneController paneController;

  /// Which scaffold slot this widget supplies.
  final SettingsPaneSlot slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = mcpServersControllerProvider(
      hostId,
      worktreeId,
    );
    final state = ref.watch(provider);
    return ListenableBuilder(
      listenable: paneController,
      builder: (context, _) => SettingsAsyncContent<McpServersState>(
        state: state,
        loading: settingsPaneSkeleton(
          slot,
          semanticLabel: l10n.settingsLoading,
        ),
        error: (error, _) => slot == SettingsPaneSlot.collection
            ? SettingsCollectionErrorState(
                key: const ValueKey<String>('mcp-settings-error'),
                title: l10n.mcpSettingsHeading,
                error: error,
                onRetry: () => ref.invalidate(provider),
              )
            : SettingsEmptyState(
                title: l10n.mcpSettingsSelectServer,
                icon: const Icon(TinestIcons.extension),
              ),
        data: (state) => _build(context, ref, l10n, state),
      ),
    );
  }

  Widget _build(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    McpServersState state,
  ) {
    final widthClass = settingsAdaptiveWidthClassOf(context);
    final showsSplit =
        widthClass == TRAdaptiveWidthClass.large ||
        widthClass == TRAdaptiveWidthClass.extraLarge;
    final selected = state.servers
        .where((server) => server.config.id == paneController.selectedId)
        .firstOrNull;
    if (slot == SettingsPaneSlot.collection &&
        !paneController.creating &&
        showsSplit &&
        paneController.canAutoSelect &&
        selected == null &&
        state.servers.isNotEmpty) {
      _scheduleInitialSelection(state.servers.first.config.id);
    } else if (!paneController.creating &&
        paneController.hasDetail &&
        selected == null) {
      _scheduleCollection();
    }
    if (slot == SettingsPaneSlot.collection) {
      return _ServerList(
        key: const ValueKey<String>('mcp-server-list'),
        state: state,
        selectedId: paneController.creating ? null : paneController.selectedId,
        onSelected: paneController.select,
        onAdd: paneController.create,
      );
    }
    if (paneController.creating) {
      return _ServerEditor(
        key: const ValueKey<String>('mcp-server-editor-new'),
        hostId: hostId,
        worktreeId: worktreeId,
        existingIds: state.userServers
            .map((server) => server.config.id)
            .toSet(),
        onDone: paneController.select,
      );
    }
    return selected == null
        ? SettingsEmptyState(
            title: l10n.mcpSettingsSelectServer,
            icon: const Icon(TinestIcons.extension),
          )
        : _ServerEditor(
            key: ValueKey<String>('mcp-server-editor-${selected.config.id}'),
            hostId: hostId,
            worktreeId: worktreeId,
            server: selected,
            existingIds: const <String>{},
            onDone: paneController.select,
          );
  }

  void _scheduleInitialSelection(String serverId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      paneController.selectInitial(serverId);
    });
  }

  void _scheduleCollection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      paneController.showCollection();
    });
  }
}

/// Owns MCP collection selection independently from either rendered slot.
class McpSettingsPaneController extends SettingsPaneCoordinatorBase {
  String? _selectedId;
  bool _creating = false;

  /// Selected MCP server ID, when an existing server is active.
  String? get selectedId => _selectedId;

  /// Whether the create destination is active.
  bool get creating => _creating;

  /// Sibling destinations, so the stack is never deeper than one entry.
  @override
  List<Object> get detailStack => _creating
      ? const <Object>[(_McpPaneDestination.create, null)]
      : _selectedId == null
      ? const <Object>[]
      : <Object>[(_McpPaneDestination.existing, _selectedId)];

  /// Shows the first server on initial desktop entry.
  void selectInitial(String id) {
    if (!consumeInitialSelection()) return;
    _selectedId = id;
    notifyListeners();
  }

  /// Shows an existing MCP server.
  void select(String id) {
    consumeExplicitNavigation();
    if (!_creating && _selectedId == id) return;
    _creating = false;
    _selectedId = id;
    notifyListeners();
  }

  /// Shows the create MCP server destination.
  void create() {
    consumeExplicitNavigation();
    if (_creating) return;
    _creating = true;
    _selectedId = null;
    notifyListeners();
  }

  @override
  void showCollection() {
    consumeExplicitNavigation();
    if (!hasDetail) return;
    _creating = false;
    _selectedId = null;
    notifyListeners();
  }

  @override
  void reset() {
    final hadDetail = hasDetail;
    resetInitialSelection();
    _creating = false;
    _selectedId = null;
    if (hadDetail) notifyListeners();
  }
}

enum _McpPaneDestination { create, existing }

class _ServerList extends StatelessWidget {
  const _ServerList({
    required this.state,
    required this.selectedId,
    required this.onSelected,
    required this.onAdd,
    super.key,
  });

  final McpServersState state;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsDestinationScaffold(
      title: TRText.inherit(l10n.mcpSettingsHeading),
      actions: <TRIconButton>[
        TRIconButton(
          appearance: TRAppearance.ghost,
          key: const ValueKey<String>('mcp-server-add'),
          label: l10n.mcpSettingsAdd,
          onPressed: onAdd,
          icon: const Icon(TinestIcons.add),
        ),
      ],
      child: state.servers.isEmpty
          ? SettingsEmptyState(
              key: const ValueKey<String>('mcp-server-list-empty'),
              title: l10n.mcpSettingsEmpty,
              icon: const Icon(TinestIcons.extension),
            )
          : SettingsCollectionList(
              children: <Widget>[
                TRTreeNav<String>.controlled(
                  value: selectedId,
                  itemSpacing: TRSpacing.extraSmall,
                  onValueChange: (serverId) {
                    if (serverId != null) onSelected(serverId);
                  },
                  items: <TRTreeNavItem<String>>[
                    for (final server in state.servers)
                      TRTreeNavLeaf<String>(
                        key: ValueKey<String>(
                          'mcp-server-tile-${server.config.id}',
                        ),
                        value: server.config.id,
                        showDisclosureIndicator: true,
                        leading: _StatusDot(server: server),
                        label: TRText.inherit(server.config.id),
                        description: TRText.inherit(
                          _serverListDescription(l10n, server),
                        ),
                        trailing: server.scope == McpConfigScope.project
                            ? const Icon(TinestIcons.lock)
                            : null,
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

String _serverListDescription(
  AppLocalizations l10n,
  McpServerStateDto server,
) {
  if (server.shadowed) return l10n.mcpSettingsShadowed;
  return <String>[
    mcpStatusLabel(l10n, server.status),
    '${l10n.mcpSettingsDiscoveredTools} ${server.tools.length}',
    '${l10n.mcpSettingsDiscoveredResources} ${server.resources.length}',
  ].join(' · ');
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.server});

  final McpServerStateDto server;

  @override
  Widget build(BuildContext context) {
    final colors = context.tinyrackTheme;
    if (server.status == McpServerStatus.connecting) {
      return TRSpinner(
        key: ValueKey<String>('mcp-server-status-${server.config.id}'),
        label: AppLocalizations.of(context).mcpSettingsConnecting,
      );
    }
    final color = switch (server.status) {
      McpServerStatus.ready => colors.primaryForeground,
      McpServerStatus.failed => colors.dangerForeground,
      McpServerStatus.disabled ||
      McpServerStatus.connecting => colors.textMuted,
    };
    return Icon(
      TinestIcons.status,
      key: ValueKey<String>('mcp-server-status-${server.config.id}'),
      // An inline status dot, deliberately smaller than a control glyph.
      size: TRSpacing.medium,
      color: color,
    );
  }
}

/// Returns the localized label for [status].
String mcpStatusLabel(AppLocalizations l10n, McpServerStatus status) =>
    switch (status) {
      McpServerStatus.disabled => l10n.mcpSettingsStatusDisabled,
      McpServerStatus.connecting => l10n.mcpSettingsStatusConnecting,
      McpServerStatus.ready => l10n.mcpSettingsStatusReady,
      McpServerStatus.failed => l10n.mcpSettingsStatusFailed,
    };

class _ServerEditor extends ConsumerStatefulWidget {
  const _ServerEditor({
    required this.hostId,
    required this.worktreeId,
    required this.existingIds,
    required this.onDone,
    this.server,
    super.key,
  });

  final String hostId;
  final String? worktreeId;
  final Set<String> existingIds;
  final ValueChanged<String> onDone;
  final McpServerStateDto? server;

  @override
  ConsumerState<_ServerEditor> createState() => _ServerEditorState();
}

class _ServerEditorState extends ConsumerState<_ServerEditor> {
  late final TextEditingController _id;
  late final TextEditingController _command;
  late final TextEditingController _args;
  late final TextEditingController _cwd;
  late final TextEditingController _url;
  late final TextEditingController _env;
  late final TextEditingController _headers;
  late McpTransportKind _transport;
  late bool _enabled;
  bool _busy = false;
  String? _error;
  String? _notice;

  bool get _readOnly => widget.server?.scope == McpConfigScope.project;

  bool get _isNew => widget.server == null;

  @override
  void initState() {
    super.initState();
    final config = widget.server?.config;
    _id = TextEditingController(text: config?.id ?? '');
    _command = TextEditingController(text: config?.command ?? '');
    _args = TextEditingController(
      text: (config?.args ?? <String>[]).join('\n'),
    );
    _cwd = TextEditingController(text: config?.cwd ?? '');
    _url = TextEditingController(text: config?.url ?? '');
    _env = TextEditingController(text: formatMcpPairs(config?.env, '='));
    _headers = TextEditingController(
      text: formatMcpPairs(config?.headers, ': '),
    );
    _transport = config?.transport ?? McpTransportKind.stdio;
    _enabled = config?.enabled ?? true;
  }

  @override
  void dispose() {
    _id.dispose();
    _command.dispose();
    _args.dispose();
    _cwd.dispose();
    _url.dispose();
    _env.dispose();
    _headers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final server = widget.server;
    return SettingsDestinationScaffold(
      title: TRText.inherit(_isNew ? l10n.mcpSettingsAdd : server!.config.id),
      contentMaxWidth: TinestLayoutMetrics.settingsContentMaxWidth,
      formActions: <Widget>[
        if (!_readOnly)
          TRButton(
            intent: TRIntent.primary,
            key: const ValueKey<String>('mcp-server-save'),
            onPressed: _busy ? null : _save,
            child: TRText.inherit(
              MaterialLocalizations.of(context).saveButtonLabel,
            ),
          ),
      ],
      child: SettingsScaffold(
        children: <Widget>[
          SettingsSection.form(
            title: l10n.mcpSettingsConnectionHeading,
            // Testing the connection acts on the fields in this section, so
            // it belongs to the section rather than to the page. Its label is
            // a phrase with no settled glyph, which rules out the header.
            action: _readOnly
                ? null
                : TRButton(
                    appearance: TRAppearance.outline,
                    key: const ValueKey<String>('mcp-server-test'),
                    onPressed: _busy ? null : _test,
                    child: TRText.inherit(l10n.mcpSettingsTest),
                  ),
            // Read-only and shadowed are independent server facts, and a
            // shadowed one still has to say where it came from, so both are
            // shown rather than one winning.
            banner: server == null
                ? null
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (_readOnly)
                        TRAlert(
                          key: const ValueKey<String>(
                            'mcp-server-readonly',
                          ),
                          title: TRText.inherit(
                            l10n.mcpSettingsProjectReadOnly(
                              AppIdentity.name,
                            ),
                          ),
                          description: TRText.inherit(
                            l10n.mcpSettingsSource(server.sourcePath),
                            key: ValueKey<String>(
                              'mcp-server-source-${server.config.id}',
                            ),
                          ),
                          icon: const Icon(TinestIcons.lock),
                        ),
                      if (_readOnly && server.shadowed)
                        const SizedBox(height: TRSpacing.small),
                      if (server.shadowed)
                        TRAlert(
                          key: ValueKey<String>(
                            'mcp-server-shadowed-${server.config.id}',
                          ),
                          title: TRText.inherit(l10n.mcpSettingsShadowed),
                          icon: const Icon(TinestIcons.warning),
                          variant: TRStatusVariant.warning,
                        ),
                    ],
                  ),
            children: <Widget>[
              TRTextField(
                key: const ValueKey<String>('mcp-field-id'),
                controller: _id,
                enabled: _isNew,
                label: l10n.mcpSettingsServerId,
              ),
              TRToggleGroup(
                key: const ValueKey<String>('mcp-transport-selector'),
                value: <String>[_transport.name],
                disabled: _readOnly,
                children: <TRToggle>[
                  TRToggle(
                    value: McpTransportKind.stdio.name,
                    child: TRText.inherit(l10n.mcpSettingsTransportStdio),
                  ),
                  TRToggle(
                    value: McpTransportKind.http.name,
                    child: TRText.inherit(l10n.mcpSettingsTransportHttp),
                  ),
                ],
                onValueChange: (value) => setState(
                  () => _transport = McpTransportKind.values.byName(
                    value.first,
                  ),
                ),
              ),
              const SizedBox(height: TRSpacing.large),
              if (_transport == McpTransportKind.stdio) ...<Widget>[
                TRTextField(
                  key: const ValueKey<String>('mcp-field-command'),
                  controller: _command,
                  enabled: !_readOnly,
                  label: l10n.mcpSettingsCommand,
                ),
                TRTextField(
                  key: const ValueKey<String>('mcp-field-args'),
                  controller: _args,
                  enabled: !_readOnly,
                  minLines: 2,
                  maxLines: 6,
                  label: l10n.mcpSettingsArgs,
                ),
                TRTextField(
                  key: const ValueKey<String>('mcp-field-cwd'),
                  controller: _cwd,
                  enabled: !_readOnly,
                  label: l10n.mcpSettingsWorkingDirectory,
                ),
                TRTextField(
                  key: const ValueKey<String>('mcp-field-env'),
                  controller: _env,
                  enabled: !_readOnly,
                  minLines: 2,
                  maxLines: 6,
                  label: l10n.mcpSettingsEnvironment,
                ),
              ] else ...<Widget>[
                TRTextField(
                  key: const ValueKey<String>('mcp-field-url'),
                  controller: _url,
                  enabled: !_readOnly,
                  label: l10n.mcpSettingsUrl,
                ),
                TRTextField(
                  key: const ValueKey<String>('mcp-field-headers'),
                  controller: _headers,
                  enabled: !_readOnly,
                  minLines: 2,
                  maxLines: 6,
                  label: l10n.mcpSettingsHeaders,
                ),
              ],
            ],
          ),
          SettingsSection(
            title: l10n.mcpSettingsStateHeading,
            description: '${l10n.mcpSettingsSecretHint} $mcpSecretSyntax',
            // Storing a secret is what the hint above it describes, so the
            // command sits with its explanation instead of in the header.
            action: _readOnly
                ? null
                : TRButton(
                    appearance: TRAppearance.outline,
                    key: const ValueKey<String>('mcp-secret-set'),
                    onPressed: _busy ? null : _promptForSecret,
                    child: TRText.inherit(l10n.mcpSettingsSecretSet),
                  ),
            banner: switch ((_error, _notice)) {
              (final String error, _) => TRAlert(
                key: const ValueKey<String>('mcp-editor-error'),
                title: TRText.inherit(error),
                icon: const Icon(TinestIcons.error),
                variant: TRStatusVariant.danger,
              ),
              (_, final String notice) => TRAlert(
                key: const ValueKey<String>('mcp-editor-notice'),
                title: TRText.inherit(notice),
                icon: const Icon(TinestIcons.success),
                variant: TRStatusVariant.success,
              ),
              _ => null,
            },
            children: <Widget>[
              TinestSwitchRow(
                key: const ValueKey<String>('mcp-field-enabled'),
                value: _enabled,
                onChanged: _readOnly
                    ? null
                    : (value) => setState(() => _enabled = value),
                title: TRText.inherit(l10n.mcpSettingsEnabled),
              ),
            ],
          ),
          if (server != null)
            // Discovery results are one group. Keeping all four parts
            // in a single scaffold child stops a section gap from opening
            // between a heading and the rows it heads.
            SettingsSection(
              title: l10n.mcpSettingsDiscoveredTools,
              banner: server.error == null
                  ? null
                  : TRAlert(
                      key: ValueKey<String>(
                        'mcp-server-error-${server.config.id}',
                      ),
                      title: TRText.inherit(server.error!),
                      icon: const Icon(TinestIcons.error),
                      variant: TRStatusVariant.danger,
                    ),
              children: <Widget>[
                Padding(
                  padding: SettingsRow.resolvedPadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Discovery output is a reference list, not a set
                      // of settings, so the rows stay dense: a server may
                      // publish dozens; the collapsibles below them must
                      // stay reachable without scrolling past all of them.
                      if (server.tools.isEmpty)
                        TRText(l10n.mcpSettingsNoTools)
                      else
                        for (final tool in server.tools)
                          TinestListRow(
                            key: ValueKey<String>(
                              'mcp-tool-tile-${tool.toolId}',
                            ),
                            contentPadding: SettingsRow.resolvedPadding(
                              context,
                              flush: true,
                            ),
                            dense: true,
                            title: TRText.inherit(tool.toolId),
                            subtitle: TRText.inherit(tool.description),
                          ),
                      const SizedBox(height: TRSpacing.small),
                      TRCollapsible(
                        key: const ValueKey<String>('mcp-server-resources'),
                        trigger: TRText(
                          '${l10n.mcpSettingsResources} '
                          '${server.resources.length}',
                        ),
                        content: Column(
                          children: <Widget>[
                            if (server.resources.isEmpty)
                              TRText(l10n.mcpSettingsNoResources)
                            else
                              for (final resource in server.resources)
                                TinestListRow(
                                  key: ValueKey<String>(
                                    'mcp-resource-tile-${resource.uri}',
                                  ),
                                  contentPadding: SettingsRow.resolvedPadding(
                                    context,
                                    flush: true,
                                  ),
                                  dense: true,
                                  title: TRText.inherit(resource.uri),
                                  subtitle: TRText.inherit(
                                    resource.description ?? resource.name ?? '',
                                  ),
                                ),
                          ],
                        ),
                      ),
                      const SizedBox(height: TRSpacing.small),
                      TRCollapsible(
                        key: const ValueKey<String>(
                          'mcp-server-resource-templates',
                        ),
                        trigger: TRText(
                          '${l10n.mcpSettingsResourceTemplates} '
                          '${server.resourceTemplates.length}',
                        ),
                        content: Column(
                          children: <Widget>[
                            if (server.resourceTemplates.isEmpty)
                              TRText(l10n.mcpSettingsNoResourceTemplates)
                            else
                              for (final template in server.resourceTemplates)
                                TinestListRow(
                                  key: ValueKey<String>(
                                    'mcp-resource-template-tile-'
                                    '${template.uriTemplate}',
                                  ),
                                  contentPadding: SettingsRow.resolvedPadding(
                                    context,
                                    flush: true,
                                  ),
                                  dense: true,
                                  title: TRText.inherit(
                                    template.uriTemplate,
                                  ),
                                  subtitle: TRText.inherit(
                                    template.description ?? template.name ?? '',
                                  ),
                                ),
                          ],
                        ),
                      ),
                      if (server.diagnostics.isNotEmpty) ...<Widget>[
                        const SizedBox(height: TRSpacing.small),
                        TRCollapsible(
                          key: const ValueKey<String>(
                            'mcp-server-diagnostics',
                          ),
                          trigger: TRText(l10n.mcpSettingsDiagnostics),
                          content: Column(
                            children: <Widget>[
                              for (final line in server.diagnostics)
                                TinestListRow(
                                  contentPadding: SettingsRow.resolvedPadding(
                                    context,
                                    flush: true,
                                  ),
                                  dense: true,
                                  title: TRText.inherit(line),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          if (!_readOnly && !_isNew)
            SettingsSection(
              title: l10n.mcpSettingsDelete,
              // The row names what is being deleted and the note says what
              // that costs. As the row's own title the note was a paragraph
              // wrapped beside a button half its height.
              footer: l10n.mcpSettingsDeleteConfirm(server!.config.id),
              children: <Widget>[
                SettingsRow(
                  title: TRText.inherit(server.config.id),
                  control: TRButton(
                    appearance: TRAppearance.ghost,
                    intent: TRIntent.danger,
                    key: const ValueKey<String>('mcp-server-delete'),
                    onPressed: _busy ? null : _delete,
                    child: TRText.inherit(l10n.mcpSettingsDelete),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  McpServerConfigDto? _edited(AppLocalizations l10n) {
    final id = _id.text.trim();
    if (!isValidMcpServerId(id) ||
        (_isNew && widget.existingIds.contains(id))) {
      setState(() => _error = l10n.mcpSettingsServerIdInvalid);
      return null;
    }
    return McpServerConfigDto(
      id: id,
      transport: _transport,
      enabled: _enabled,
      command: _transport == McpTransportKind.stdio
          ? _command.text.trim()
          : null,
      args: _transport == McpTransportKind.stdio
          ? parseMcpLines(_args.text)
          : const <String>[],
      env: _transport == McpTransportKind.stdio
          ? parseMcpPairs(_env.text, '=')
          : const <String, String>{},
      cwd: _transport == McpTransportKind.stdio && _cwd.text.trim().isNotEmpty
          ? _cwd.text.trim()
          : null,
      url: _transport == McpTransportKind.http ? _url.text.trim() : null,
      headers: _transport == McpTransportKind.http
          ? parseMcpPairs(_headers.text, ':')
          : const <String, String>{},
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final edited = _edited(l10n);
    if (edited == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    final controller = ref.read(
      mcpServersControllerProvider(widget.hostId, widget.worktreeId).notifier,
    );
    // Reported rather than shown in place: a save that works closes this
    // editor, so a banner announcing it would leave with the editor.
    final saved = await ref
        .read(toastMessengerProvider)
        .run(
          () => _isNew ? controller.add(edited) : controller.save(edited),
          failure: l10n.mcpSettingsSaveFailed,
          success: l10n.commonSaved,
          id: 'mcp-editor-save',
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved) widget.onDone(edited.id);
  }

  Future<void> _test() async {
    final l10n = AppLocalizations.of(context);
    final edited = _edited(l10n);
    if (edited == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final result = await ref
          .read(
            mcpServersControllerProvider(
              widget.hostId,
              widget.worktreeId,
            ).notifier,
          )
          .test(edited);
      if (!mounted) return;
      setState(() {
        if (result.status == McpServerStatus.ready) {
          _notice = l10n.mcpSettingsTestSucceeded(result.tools.length);
        } else {
          _error = l10n.mcpSettingsTestFailed(result.error ?? '');
        }
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = l10n.mcpSettingsTestFailed('$error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final id = widget.server!.config.id;
    final confirmed = await showTRDialog<bool>(
      context: context,
      builder: (context) => TRAlertDialog(
        key: const ValueKey<String>('mcp-delete-dialog'),
        title: TRText.inherit(l10n.mcpSettingsDelete),
        content: TRText.inherit(l10n.mcpSettingsDeleteConfirm(id)),
        actions: <TRButton>[
          TRButton(
            appearance: TRAppearance.ghost,
            onPressed: () => Navigator.of(context).pop(false),
            child: TRText.inherit(
              MaterialLocalizations.of(context).cancelButtonLabel,
            ),
          ),
          TRButton(
            intent: TRIntent.danger,
            key: const ValueKey<String>('mcp-delete-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: TRText.inherit(l10n.mcpSettingsDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final removed = await ref
        .read(toastMessengerProvider)
        .run(
          () => ref
              .read(
                mcpServersControllerProvider(
                  widget.hostId,
                  widget.worktreeId,
                ).notifier,
              )
              .remove(id),
          failure: l10n.mcpSettingsDeleteFailed,
          success: l10n.commonDeleted,
          id: 'mcp-editor-delete',
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (removed) widget.onDone('');
  }

  Future<void> _promptForSecret() async {
    final secret = await showTRDialog<({String key, String value})>(
      context: context,
      builder: (context) => const _SecretDialog(),
    );
    if (secret == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    await ref
        .read(toastMessengerProvider)
        .run(
          () => ref
              .read(
                mcpServersControllerProvider(
                  widget.hostId,
                  widget.worktreeId,
                ).notifier,
              )
              .setSecret(secret.key, secret.value),
          failure: l10n.mcpSettingsSecretFailed,
          success: l10n.commonSaved,
          id: 'mcp-editor-secret',
        );
  }
}

/// Collects one secret, owning the controllers for as long as it is shown.
class _SecretDialog extends StatefulWidget {
  const _SecretDialog();

  @override
  State<_SecretDialog> createState() => _SecretDialogState();
}

class _SecretDialogState extends State<_SecretDialog> {
  final TextEditingController _key = TextEditingController();
  final TextEditingController _value = TextEditingController();

  @override
  void dispose() {
    _key.dispose();
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TRAlertDialog(
      key: const ValueKey<String>('mcp-secret-dialog'),
      title: TRText.inherit(l10n.mcpSettingsSecretSet),
      content: SettingsDialogForm(
        width: TRMeasurements.overlayWidthSm,
        children: <Widget>[
          TRTextField(
            key: const ValueKey<String>('mcp-secret-key'),
            controller: _key,
            label: l10n.mcpSettingsSecretKey,
          ),
          TRTextField(
            key: const ValueKey<String>('mcp-secret-value'),
            controller: _value,
            obscureText: true,
            label: l10n.mcpSettingsSecretValue,
          ),
        ],
      ),
      actions: <TRButton>[
        TRButton(
          appearance: TRAppearance.ghost,
          onPressed: () => Navigator.of(context).pop(),
          child: TRText.inherit(
            MaterialLocalizations.of(context).cancelButtonLabel,
          ),
        ),
        TRButton(
          intent: TRIntent.primary,
          key: const ValueKey<String>('mcp-secret-save'),
          onPressed: () {
            final key = _key.text.trim();
            if (key.isEmpty) return;
            Navigator.of(context).pop((key: key, value: _value.text));
          },
          child: TRText.inherit(
            MaterialLocalizations.of(context).saveButtonLabel,
          ),
        ),
      ],
    );
  }
}

/// Whether [id] can be namespaced into `mcp__<server>__<tool>`.
bool isValidMcpServerId(String id) =>
    id.isNotEmpty &&
    id.length <= 40 &&
    !id.contains('__') &&
    RegExp(r'^[a-z0-9][a-z0-9_-]*$').hasMatch(id);

/// Splits a multi-line field into trimmed, non-empty entries.
List<String> parseMcpLines(String text) => <String>[
  for (final line in text.split('\n'))
    if (line.trim().isNotEmpty) line.trim(),
];

/// Parses `key<separator>value` lines into a map.
Map<String, String> parseMcpPairs(String text, String separator) {
  final entries = <String, String>{};
  for (final line in parseMcpLines(text)) {
    final index = line.indexOf(separator);
    if (index <= 0) continue;
    entries[line.substring(0, index).trim()] = line
        .substring(index + separator.length)
        .trim();
  }
  return entries;
}

/// Renders a map back into editable `key<separator>value` lines.
String formatMcpPairs(Map<String, String>? entries, String separator) =>
    (entries ?? const <String, String>{}).entries
        .map((entry) => '${entry.key}$separator${entry.value}')
        .join('\n');
