import 'dart:async';

import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/features/hosts/domain/host_models.dart';
import 'package:app/src/features/hosts/domain/remote_path.dart';
import 'package:app/src/features/hosts/presentation/host_labels.dart';
import 'package:app/src/shared/presentation/tinest_icons.dart';
import 'package:app/src/shared/presentation/tinest_list_row.dart';
import 'package:app/src/shared/presentation/workspace_skeletons.dart';
import 'package:client/client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

const double _directoryBrowserWidth =
    TRMeasurements.overlayWidthMd + TRSpacing.threeExtraLarge;
const double _directoryBrowserHeight = _directoryBrowserWidth * 3 / 4;

/// Debounce applied to free-text path edits before querying the daemon.
const Duration directoryBrowserDebounce = Duration(milliseconds: 200);

/// Opens the daemon-side directory browser and returns the chosen path.
Future<String?> showDirectoryBrowser(
  BuildContext context, {
  required TinestApi api,
  required String initialPath,
}) => showTRDialog<String>(
  context: context,
  builder: (context) =>
      DirectoryBrowserDialog(api: api, initialPath: initialPath),
);

/// Walks daemon directories so a remote host can be browsed in the app.
class DirectoryBrowserDialog extends StatefulWidget {
  /// Creates the directory browser.
  const new({required this.api, required this.initialPath, super.key});

  /// Daemon whose filesystem is browsed.
  final TinestApi api;

  /// Directory listed when the dialog opens.
  final String initialPath;

  @override
  State<DirectoryBrowserDialog> createState() => _DirectoryBrowserDialogState();
}

class _DirectoryBrowserDialogState extends State<DirectoryBrowserDialog> {
  late final TextEditingController _path = TextEditingController(
    text: widget.initialPath,
  );
  List<DirectorySuggestionDto> _entries = const <DirectorySuggestionDto>[];
  bool _loading = true;
  // Whether any listing has ever resolved. The first load renders row-shaped
  // skeletons; later navigations keep the stale rows under a progress bar.
  bool _loadedOnce = false;
  String? _error;
  int _requestId = 0;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    unawaited(_load(widget.initialPath));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _path.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final parent = parentDirectoryPath(_path.text);
    return TRAlertDialog(
      title: TRText.inherit(l10n.directoryBrowserTitle),
      content: SizedBox(
        width: _directoryBrowserWidth,
        // tinyrack-check-ignore-next-line tokens/no-literal -- preserve the browser dialog's structural 4:3 aspect ratio
        height: _directoryBrowserHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TRTextField(
              key: const ValueKey('directory-browser-path'),
              controller: _path,
              autofocus: true,
              label: l10n.directoryBrowserPath,
              // A filesystem path is not prose; the example shape is the same
              // in every language.
              placeholder: '/home/you/repositories/project',
              onChanged: _onPathTyped,
            ),
            const SizedBox(height: TRSpacing.small),
            if (_loading && _loadedOnce) const TRProgress(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: TRSpacing.small),
                child: TRText(_error!, color: TRTextColor.danger),
              ),
            Expanded(
              child: _loading && !_loadedOnce
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: TRSpacing.small,
                      ),
                      child: ListRowsSkeleton(
                        semanticLabel: l10n.directoryBrowserLoading,
                      ),
                    )
                  : ListView(
                      children: <Widget>[
                        if (parent != null)
                          TinestListRow(
                            key: const ValueKey('directory-browser-parent'),
                            dense: true,
                            leading: const Icon(TinestIcons.uploadFolder),
                            title: const TRText.inherit('..'),
                            onTap: () => unawaited(_open(parent)),
                          ),
                        for (final entry in _entries)
                          TinestListRow(
                            key: ValueKey(
                              'directory-browser-entry-${entry.path}',
                            ),
                            dense: true,
                            leading: const Icon(TinestIcons.folder),
                            title: TRText.inherit(entry.name),
                            subtitle: TRText.inherit(entry.path),
                            onTap: () => unawaited(_open(entry.path)),
                          ),
                        if (!_loading && _entries.isEmpty && _error == null)
                          TinestListRow(
                            dense: true,
                            title: TRText.inherit(l10n.directoryBrowserEmpty),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: <TRButton>[
        TRButton(
          appearance: TRAppearance.ghost,
          onPressed: () => Navigator.pop(context),
          child: TRText.inherit(l10n.commonCancel),
        ),
        TRButton(
          intent: TRIntent.primary,
          onPressed: () => Navigator.pop(context, _path.text.trim()),
          child: TRText.inherit(l10n.directoryBrowserSelect),
        ),
      ],
    );
  }

  void _onPathTyped(String value) {
    _debounce?.cancel();
    _debounce = Timer(directoryBrowserDebounce, () => unawaited(_load(value)));
    setState(() {});
  }

  Future<void> _open(String path) async {
    _debounce?.cancel();
    _path.text = path;
    await _load(path);
  }

  Future<void> _load(String query) async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await widget.api.workspaces.suggestDirectories(
        query,
        limit: 200,
      );
      // A slower earlier request must never overwrite a newer listing.
      if (!mounted || id != _requestId) return;
      setState(() {
        _entries = entries;
        _loading = false;
        _loadedOnce = true;
      });
    } on TinestClientException catch (error) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = error.message;
        _loading = false;
        _loadedOnce = true;
      });
    }
  }
}

/// Asks which daemon a new project should be registered on.
class DaemonPickerDialog extends StatelessWidget {
  /// Creates the daemon picker.
  const new({required this.hosts, super.key});

  /// Online daemon runtimes offered to the user.
  final List<HostRuntimeSnapshot> hosts;

  @override
  Widget build(BuildContext context) => TRDialog(
    title: TRText.inherit(
      AppLocalizations.of(context).directoryBrowserHostTitle,
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final host in hosts)
          TinestListRow(
            onTap: () => Navigator.pop(context, host.id),
            leading: Icon(
              host.kind == HostKind.embedded
                  ? TinestIcons.computer
                  : TinestIcons.cloud,
            ),
            title: TRText.inherit(
              hostLabel(AppLocalizations.of(context), host),
            ),
          ),
      ],
    ),
  );
}

/// Picks the daemon to register on, skipping the prompt for a single host.
Future<String?> pickDaemonHost(
  BuildContext context,
  List<HostRuntimeSnapshot> online,
) async {
  if (online.isEmpty) return null;
  if (online.length == 1) return online.single.id;
  return await showTRDialog<String>(
    context: context,
    builder: (context) => DaemonPickerDialog(hosts: online),
  );
}
