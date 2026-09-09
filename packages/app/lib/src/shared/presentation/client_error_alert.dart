import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/src/shared/presentation/tinest_icons.dart';
import 'package:client/client.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:tinyrack_ui/tinyrack_ui.dart';

/// Translates a daemon failure code into text the user can act on.
///
/// The code is the contract, not the message: the daemon writes its messages
/// in English for a maintainer, so anything this app understands is replaced
/// with a localized explanation. An unrecognized code falls back to the
/// daemon's own text, since only the daemon knows what it means.
String clientErrorText(
  AppLocalizations l10n,
  TinestClientException error,
) => switch (error.code) {
  RpcErrorCodes.branchAlreadyExists => l10n.errorBranchAlreadyExists,
  RpcErrorCodes.worktreePathInUse => l10n.errorWorktreePathInUse,
  RpcErrorCodes.invalidBranchName => l10n.errorInvalidBranchName,
  RpcErrorCodes.gitCommandFailed => l10n.errorGitCommandFailed,
  RpcErrorCodes.workspaceNotFound => l10n.errorWorkspaceNotFound,
  RpcErrorCodes.workspaceNotGit => l10n.errorWorkspaceNotGit,
  RpcErrorCodes.workspaceProtected => l10n.errorWorkspaceProtected,
  RpcErrorCodes.worktreeNotFound => l10n.errorWorktreeNotFound,
  RpcErrorCodes.worktreeArchiveBlocked => l10n.errorWorktreeArchiveBlocked,
  RpcErrorCodes.agentDefinitionNotFound => l10n.errorAgentDefinitionNotFound,
  RpcErrorCodes.agentDefinitionUnusable => l10n.errorAgentDefinitionUnusable,
  RpcErrorCodes.worktreeUnavailable => l10n.terminalWorktreeUnavailable,
  RpcErrorCodes.terminalStartFailed => l10n.terminalShellStartFailed,
  RpcErrorCodes.invalidProjectSettings => l10n.errorInvalidProjectSettings,
  RpcErrorCodes.sessionTurnActive => l10n.errorSessionTurnActive,
  // All four mean the daemon could not make sense of what this app sent,
  // which from the user's side is one problem: the two are out of step.
  RpcErrorCodes.protocolMismatch ||
  RpcErrorCodes.handshakeRequired ||
  RpcErrorCodes.unknownMethod ||
  RpcErrorCodes.invalidParams => l10n.errorProtocolMismatch,
  RpcErrorCodes.requestTimeout => l10n.errorRequestTimeout,
  RpcErrorCodes.internalError => l10n.errorInternalDaemon,
  RpcErrorCodes.pluginUiRejected => l10n.errorPluginUiRejected,
  RpcErrorCodes.pluginRevisionUnavailable =>
    l10n.errorPluginRevisionUnavailable,
  _ => error.message,
};

/// The diagnostic lines a bug report needs, or null when there are none.
///
/// Kept separate from [clientErrorText] so the guidance stays readable while
/// the machine-facing context is still one copy away. Git's stderr is included
/// verbatim: for a failed command it is the only real explanation.
String? clientErrorDiagnostics(TinestClientException error) {
  final lines = <String>[
    if (error.details['stderr'] case final String stderr when stderr.isNotEmpty)
      stderr,
    if (error.details['command'] case final String command) command,
    if (error.code case final String code) 'code: $code',
    if (error.details['traceId'] case final String traceId) 'traceId: $traceId',
    if (error.details['method'] case final String method) 'method: $method',
    if (error.details['errorType'] case final String type) 'type: $type',
  ];
  return lines.isEmpty ? null : lines.join('\n');
}

/// Reports one daemon failure with guidance, diagnostics, and a retry.
///
/// Every hard failure in the app renders through this so a user never meets a
/// bare untranslated daemon string, and so whoever reads the bug report gets
/// the trace id that points at the daemon log record.
class ClientErrorAlert extends StatelessWidget {
  /// Creates a failure alert for [error].
  const new({
    required this.error,
    required this.title,
    this.onRetry,
    super.key,
  });

  /// Failure to report.
  final TinestClientException error;

  /// Localized headline describing what did not happen.
  final String title;

  /// Runs the failed operation again, when retrying is meaningful.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final guidance = clientErrorText(l10n, error);
    final diagnostics = clientErrorDiagnostics(error);
    return TRAlert(
      variant: TRStatusVariant.danger,
      icon: const Icon(TinestIcons.error),
      title: TRText.inherit(title),
      description: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TRText.inherit(guidance),
            if (diagnostics != null) ...<Widget>[
              const SizedBox(height: TRSpacing.extraSmall),
              TRText(
                diagnostics,
                variant: TRTextVariant.caption,
                color: TRTextColor.muted,
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        if (onRetry != null)
          TRButton(
            appearance: TRAppearance.outline,
            onPressed: onRetry,
            child: TRText.inherit(l10n.commonRetry),
          ),
        TRIconButton(
          key: const ValueKey<String>('client-error-copy'),
          appearance: TRAppearance.ghost,
          label: l10n.commonCopy,
          onPressed: () => Clipboard.setData(
            ClipboardData(
              text: <String>[title, guidance, ?diagnostics].join('\n'),
            ),
          ),
          icon: const Icon(TinestIcons.copy),
        ),
      ],
    );
  }
}
