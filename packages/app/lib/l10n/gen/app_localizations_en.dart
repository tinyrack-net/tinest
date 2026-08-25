// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonSaving => 'Saving…';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonCreating => 'Creating…';

  @override
  String get commonConfirm => 'OK';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRetry => 'Retry';

  @override
  String get selectSearchPlaceholder => 'Search options';

  @override
  String get selectNoResults => 'No matching options.';

  @override
  String get commonClose => 'Close';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonStop => 'Stop';

  @override
  String get commonName => 'Name';

  @override
  String get commonKind => 'Kind';

  @override
  String get commonDescription => 'Description';

  @override
  String get commonRunning => 'Running';

  @override
  String get commonDone => 'Done';

  @override
  String get commonDetails => 'Details';

  @override
  String get commonSaved => 'Saved.';

  @override
  String get commonDeleted => 'Deleted.';

  @override
  String get commonCopied => 'Copied to the clipboard.';

  @override
  String get commonActionFailed => 'Something went wrong.';

  @override
  String get toastRegionLabel => 'Notifications';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLoading => 'Loading settings';

  @override
  String settingsRefreshFailed(String error) {
    return 'Could not refresh settings: $error';
  }

  @override
  String get settingsSectionApp => 'App';

  @override
  String get settingsSectionDaemon => 'Daemon';

  @override
  String get settingsDaemonSelectLabel => 'Daemon';

  @override
  String get settingsDaemonSelectEmpty => 'No daemons';

  @override
  String settingsDaemonOffline(String label) {
    return '$label is not connected.';
  }

  @override
  String get settingsCategoryGeneral => 'General';

  @override
  String get settingsCategoryProjects => 'Projects';

  @override
  String get settingsCategoryAgent => 'Agent';

  @override
  String get settingsCategoryProvider => 'Provider';

  @override
  String get settingsCategoryModel => 'Model';

  @override
  String get settingsCategoryPermission => 'Permissions';

  @override
  String get settingsCategoryDaemon => 'Daemons';

  @override
  String get settingsCategoryAdvanced => 'Advanced';

  @override
  String get advancedResetTitle => 'Reset all data';

  @override
  String get advancedResetDescription =>
      'Deletes the embedded daemon\'s database, credentials, MCP and agent configuration, skills, and attachments, and clears every app setting and stored remote daemon token. Git checkouts under the worktrees folder stay on disk.';

  @override
  String get advancedResetDescriptionAppOnly =>
      'Clears every app setting and stored remote daemon token on this device. Remote daemons keep their own data.';

  @override
  String get advancedResetRunning => 'Resetting…';

  @override
  String get advancedResetConfirmTitle => 'Reset all data?';

  @override
  String get advancedResetConfirmBody =>
      'Every session, workspace registration, provider connection, agent, skill, and MCP server on the embedded daemon is deleted, together with every app setting and remote daemon profile and token. The daemon returns to its default port. Git checkouts stay on disk but have to be added again. This cannot be undone.';

  @override
  String get advancedResetConfirmAccept => 'Reset';

  @override
  String get advancedResetDone => 'Reset to factory defaults.';

  @override
  String get advancedResetFailedTitle => 'Reset failed';

  @override
  String advancedResetFailedDaemonRunning(String appDisplayName) {
    return 'Another $appDisplayName daemon is using the data directory. Quit it and try again. Nothing was deleted.';
  }

  @override
  String advancedResetFailedFilesystem(String error) {
    return 'Some daemon files could not be deleted: $error';
  }

  @override
  String advancedResetFailedIncomplete(String appDisplayName) {
    return 'Daemon data was removed but the app settings could not be cleared. Restart $appDisplayName.';
  }

  @override
  String get settingsRequiresOnlineDaemon => 'Connect an online daemon first.';

  @override
  String get generalAppearanceLabel => 'Theme';

  @override
  String get generalAppearanceSystem => 'Follow system';

  @override
  String get generalAppearanceLight => 'Light';

  @override
  String get generalAppearanceDark => 'Dark';

  @override
  String get generalLanguageLabel => 'Display language';

  @override
  String get generalLanguageSystem => 'System default';

  @override
  String get generalStartupSection => 'Startup';

  @override
  String get generalStartupAtBootLabel => 'Start at login';

  @override
  String get generalStartupMinimizedLabel => 'Start minimized';

  @override
  String get generalAppearanceFailed => 'Could not change the appearance.';

  @override
  String get generalLanguageFailed => 'Could not change the language.';

  @override
  String get generalStartupFailed => 'Could not change the startup setting.';

  @override
  String generalStartupCloseNotice(String appDisplayName) {
    return 'Closing the window keeps $appDisplayName running in the tray.';
  }

  @override
  String trayTooltip(String appDisplayName) {
    return '$appDisplayName';
  }

  @override
  String get trayShowWindow => 'Show window';

  @override
  String get trayHideWindow => 'Hide window';

  @override
  String get trayOpenSettings => 'Settings';

  @override
  String get trayQuit => 'Quit';

  @override
  String get desktopMenuFile => 'File';

  @override
  String get desktopMenuView => 'View';

  @override
  String get desktopMenuHelp => 'Help';

  @override
  String desktopMenuAbout(String appDisplayName) {
    return 'About $appDisplayName';
  }

  @override
  String get desktopWindowMinimize => 'Minimize';

  @override
  String get desktopWindowMaximize => 'Maximize';

  @override
  String get desktopWindowRestore => 'Restore';

  @override
  String get desktopWindowClose => 'Close to tray';

  @override
  String get workspacesTitle => 'Workspaces';

  @override
  String get workspaceSidebarExpand => 'Show sidebar';

  @override
  String get workspaceSidebarCollapse => 'Hide sidebar';

  @override
  String get workspaceNewSession => 'New session';

  @override
  String get sessionDefaultTitle => 'Coding session';

  @override
  String get workspaceNewTab => 'New tab';

  @override
  String get workspaceNewTerminal => 'New terminal';

  @override
  String terminalTabTitle(int number) {
    return 'Terminal $number';
  }

  @override
  String get workspaceLoading => 'Loading workspace';

  @override
  String get workspaceCatalogLoading => 'Loading workspaces';

  @override
  String get workspaceCatalogRefreshing => 'Refreshing workspaces…';

  @override
  String get workspaceCatalogFailed => 'Could not load workspaces';

  @override
  String get workspaceBranchesLoading => 'Loading branches';

  @override
  String get workspaceBranchesFailed => 'Could not load branches';

  @override
  String get workspaceRegisteringProject => 'Adding project…';

  @override
  String get workspaceArchiveChecking => 'Checking worktree…';

  @override
  String get workspaceCreatingWorktree => 'Creating worktree…';

  @override
  String get workspaceStartingSession => 'Starting session…';

  @override
  String get workspaceTerminalStarting => 'Starting terminal';

  @override
  String workspaceTerminalStartFailed(String error) {
    return 'Could not start terminal: $error';
  }

  @override
  String get terminalCloseTitle => 'Terminate terminal?';

  @override
  String get terminalCloseConfirm =>
      'Closing this tab terminates its shell and child processes.';

  @override
  String get terminalTerminate => 'Terminate';

  @override
  String get terminalConnectionFailed => 'Terminal connection failed';

  @override
  String get terminalConnecting => 'Connecting to terminal';

  @override
  String get conversationLoading => 'Loading conversation';

  @override
  String get conversationLoadingOlder => 'Loading earlier messages';

  @override
  String get conversationLoadOlderFailed => 'Could not load earlier messages';

  @override
  String get conversationLoadOlderRetry => 'Try again';

  @override
  String get directoryBrowserLoading => 'Loading directories';

  @override
  String get terminalCreationFailed => 'Couldn\'t create terminal';

  @override
  String get terminalWorktreeUnavailable =>
      'This worktree is no longer available. Choose another worktree.';

  @override
  String get terminalShellStartFailed =>
      'The configured terminal shell couldn\'t be started. Check terminal settings and try again.';

  @override
  String get terminalMenuCopy => 'Copy';

  @override
  String get terminalMenuPaste => 'Paste';

  @override
  String get terminalMenuSelectAll => 'Select all';

  @override
  String get terminalMenuClearSelection => 'Clear selection';

  @override
  String get terminalMenuClearScreen => 'Clear screen';

  @override
  String get projectSettingsHookHeading => 'Worktree lifecycle hooks';

  @override
  String get projectSettingsShellHeading => 'Project terminal shell';

  @override
  String get projectSettingsShellHelp =>
      'Overrides the daemon host shell for terminals opened in this project. Leave the executable empty to inherit the host default.';

  @override
  String get projectSettingsShellExecutable => 'Shell executable';

  @override
  String get projectSettingsShellArguments => 'Shell arguments (one per line)';

  @override
  String get projectSettingsHostShellHeading => 'Daemon host default shell';

  @override
  String get projectSettingsHostShellHelp =>
      'Used by every project on this daemon host unless the project overrides it. Leave the executable empty to use the operating system default.';

  @override
  String get workspaceAllSessions => 'All sessions';

  @override
  String get workspaceSplitRight => 'Split right';

  @override
  String get workspaceSplitDown => 'Split down';

  @override
  String get workspaceResizePanes => 'Resize panes';

  @override
  String get workspaceMoveTabToPane => 'Move active tab to pane';

  @override
  String get workspaceCloseTab => 'Close tab';

  @override
  String get workspaceNewWorkspace => 'New workspace';

  @override
  String get workspaceWorktreeMenu => 'Worktree menu';

  @override
  String get workspaceProjectMenu => 'Project menu';

  @override
  String get workspaceUnregister => 'Remove project';

  @override
  String workspaceUnregisterTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String workspaceUnregisterBody(String appName) {
    return 'The project disappears from $appName, but its repository and files stay on disk.';
  }

  @override
  String get workspaceArchive => 'Archive';

  @override
  String get workspaceArchiveBlockedTitle => 'Cannot archive';

  @override
  String workspaceArchiveBlockedBody(int count) {
    return 'Stop the $count running session(s) first.';
  }

  @override
  String workspaceArchiveTitle(String name) {
    return 'Archive $name?';
  }

  @override
  String get workspaceArchiveDirty => 'It has uncommitted changes.\n';

  @override
  String workspaceArchiveUnpushed(int count) {
    return 'It has $count unpushed commit(s).\n';
  }

  @override
  String get workspaceArchiveRemovesDirectory =>
      'The checkout directory will be removed.';

  @override
  String get workspaceArchiveRisky => 'Confirm the risks and archive';

  @override
  String get workspaceNoDaemons => 'No daemons are configured.';

  @override
  String get workspaceNoConnectedDaemons => 'No daemon is connected.';

  @override
  String get workspaceNoWorkspaces => 'No workspaces yet.';

  @override
  String get workspaceNoProjectSessions => 'No project';

  @override
  String get workspaceNoProjectOption => 'No project (home folder)';

  @override
  String get workspaceProjectChip => 'Project';

  @override
  String get workspaceProjectChipTooltip => 'Select a project';

  @override
  String get workspaceProjectAdd => 'Add';

  @override
  String get workspaceWorktreeNew => 'New worktree';

  @override
  String get workspaceWorktreeLocal => 'Local';

  @override
  String get workspaceWorktreeChipTooltip => 'Select a worktree';

  @override
  String get workspaceBaseBranchChip => 'Base branch';

  @override
  String get workspaceBaseBranchChipTooltip => 'Select a base branch';

  @override
  String get workspaceAddProjectFirst => 'Add a project first.';

  @override
  String get workspaceSelectProject => 'Select a project.';

  @override
  String get workspaceCheckoutMissing => 'No project checkout was found.';

  @override
  String get workspaceDaemonRequired => 'A daemon connection is required.';

  @override
  String get workspaceOpenDaemonSettings => 'Daemon settings';

  @override
  String get workspaceStartFailedTitle => 'The session could not be started';

  @override
  String get composerSelectProviderModel =>
      'Choose a provider and model first.';

  @override
  String get errorBranchAlreadyExists =>
      'A branch with that name already exists. Choose another name.';

  @override
  String get errorWorktreePathInUse =>
      'Another checkout already uses that folder.';

  @override
  String get errorInvalidBranchName =>
      'That name can\'t be used as a Git branch.';

  @override
  String get errorGitCommandFailed =>
      'A Git command failed. The details below are Git\'s own output.';

  @override
  String get errorWorkspaceNotFound =>
      'That project is no longer registered with the daemon.';

  @override
  String get errorWorkspaceNotGit =>
      'That project is not a Git repository, so it has no worktrees.';

  @override
  String get errorWorkspaceProtected =>
      'The daemon owns that folder and manages it itself.';

  @override
  String get errorWorktreeNotFound =>
      'That checkout is no longer registered with the daemon.';

  @override
  String get errorWorktreeArchiveBlocked =>
      'This checkout can\'t be archived right now.';

  @override
  String get errorAgentDefinitionNotFound =>
      'That agent no longer exists. Choose another agent.';

  @override
  String get errorAgentDefinitionUnusable =>
      'That agent can\'t start a session. Choose another agent.';

  @override
  String get errorProtocolMismatch =>
      'This app and the daemon speak different protocol versions. Update both to the same release.';

  @override
  String get errorInvalidProjectSettings =>
      'The project\'s .tinest/config.json could not be read. Fix the file and try again.';

  @override
  String get errorRequestTimeout =>
      'The daemon didn\'t respond in time. Try again.';

  @override
  String get errorInternalDaemon =>
      'The daemon hit an unexpected problem. Copy the details below when reporting it.';

  @override
  String get errorPluginUiRejected =>
      'The plugin interface request was rejected.';

  @override
  String get errorPluginRevisionUnavailable =>
      'This agent has not activated the plugin yet. Send a message to start it.';

  @override
  String get errorSessionTurnActive =>
      'This session is running a turn. Wait for it to finish or stop it, then change the setting.';

  @override
  String get errorSessionSettingFailed =>
      'The session setting could not be changed.';

  @override
  String get hostStatusOnline => 'Online';

  @override
  String get hostStatusConnecting => 'Connecting';

  @override
  String get hostStatusReconnecting => 'Reconnecting';

  @override
  String get hostStatusOffline => 'Offline';

  @override
  String get hostStatusError => 'Error';

  @override
  String get hostStatusConflict => 'Duplicate daemon';

  @override
  String get hostStatusIdle => 'Auto-connect off';

  @override
  String get hostStatusPending => 'Waiting';

  @override
  String get embeddedDaemonName => 'Embedded daemon';

  @override
  String get hostErrorMissingToken => 'Enter a bearer token.';

  @override
  String get hostErrorNoToken => 'No bearer token is stored.';

  @override
  String get hostErrorDuplicate => 'That daemon is already registered.';

  @override
  String get hostErrorUnauthorized => 'The daemon rejected the bearer token.';

  @override
  String get hostErrorEmbeddedPortInUse =>
      'The selected port is already in use.';

  @override
  String hostErrorEmbeddedAlreadyRunning(String appName) {
    return '$appName is already running on this computer and owns the local daemon. Open the running copy from the system tray, or quit it and retry.';
  }

  @override
  String get hostErrorLocalNetworkUnreachable =>
      'Could not reach the daemon. Check that it is running, and that you allowed this site to access your local network.';

  @override
  String get hostErrorRelayPairingUnavailable =>
      'Relay pairing is not available on this platform.';

  @override
  String get hostErrorServerIdentityMismatch =>
      'That address now reaches a different daemon than the one saved here.';

  @override
  String get hostErrorCredentialMismatch =>
      'The stored credential does not match this connection path.';

  @override
  String get appSettingsTitle => 'App settings';

  @override
  String get appSettingsLocalSection => 'Local execution';

  @override
  String get appSettingsEmbeddedSubtitle =>
      'Starts with the app and stops when it exits. A failed start does not block the app.';

  @override
  String get appSettingsExposure => 'Allow network access';

  @override
  String get appSettingsExposureSubtitle =>
      'Off accepts connections from this machine only; on accepts them on every IPv4 interface.';

  @override
  String get appSettingsEmbeddedPort => 'Port';

  @override
  String get appSettingsEmbeddedPortHelp =>
      'Choose a port from 1 to 65535. Applying restarts the embedded daemon when it is running.';

  @override
  String get appSettingsEmbeddedPortInvalid =>
      'Enter a whole number from 1 to 65535.';

  @override
  String get appSettingsEmbeddedPortApply => 'Apply';

  @override
  String get appSettingsEmbeddedFailureTitle =>
      'The embedded daemon could not start';

  @override
  String appSettingsEmbeddedPortConflict(int port) {
    return 'Port $port is being used by another process. Choose another port and apply it, or retry after the port becomes available.';
  }

  @override
  String get appSettingsRemoteSection => 'Remote daemons';

  @override
  String get appSettingsAddRemote => 'Add remote daemon';

  @override
  String get relayPairTitle => 'Connect a device';

  @override
  String get relayPairDeviceDescription =>
      'Scan a QR code or copy a link to connect your other device to this daemon.';

  @override
  String get relayPairDialogDescription =>
      'Scan this QR code on your other device, or copy the connection link below.';

  @override
  String get relayConnectDaemonTitle => 'Connect a daemon';

  @override
  String get relayConnectDaemonDescription =>
      'Choose how to connect to a daemon. Relay links keep daemon traffic end-to-end encrypted.';

  @override
  String get relayConnectScanDescription =>
      'Scan the one-time QR code shown by the daemon.';

  @override
  String get relayConnectPasteTitle => 'Paste connection link';

  @override
  String get relayConnectPasteDescription =>
      'Paste the one-time link shown by the daemon.';

  @override
  String get relayConnectDirectDescription =>
      'Connect with a WebSocket address and bearer token.';

  @override
  String get relayConfirmTitle => 'Review daemon connection';

  @override
  String get relayConfirmDescription =>
      'Confirm the daemon and relay before registering this device.';

  @override
  String get relayConfirmDaemon => 'Daemon ID';

  @override
  String get relayConfirmRelay => 'Relay server';

  @override
  String get relayConfirmExpires => 'Link expires';

  @override
  String get relayShare => 'Share';

  @override
  String get relayRefreshLink => 'Create a new link';

  @override
  String get relayEnableTitle => 'Connect this daemon through the relay';

  @override
  String get relayEnableDescription =>
      'The daemon will open an outbound encrypted connection to the separate Tinyrack relay server so your other devices can reach it.';

  @override
  String get relayEnableAction => 'Enable relay connection';

  @override
  String get settingsCategoryConnection => 'Connections';

  @override
  String get relayPairDescription =>
      'Paste the one-time link shown by the daemon. Its code and files stay end-to-end encrypted through the relay.';

  @override
  String get relayPairLink => 'Pairing link';

  @override
  String get relayPairDeviceName => 'This device\'s name';

  @override
  String get relayPairAction => 'Connect';

  @override
  String get relayPairScan => 'Scan QR code';

  @override
  String get relayPairCameraUnavailable =>
      'QR scanning is available on Android and iOS. Paste the connection link on this device instead.';

  @override
  String relayPairCameraError(String appDisplayName) {
    return '$appDisplayName could not open the camera. Allow camera access in system settings, then try again.';
  }

  @override
  String get relayPairCameraRetry => 'Try camera again';

  @override
  String get relayPairQrSemantics =>
      'QR code for the one-time device connection link';

  @override
  String relayPairInvalid(String appDisplayName) {
    return 'Enter a valid $appDisplayName pairing link.';
  }

  @override
  String get relayPairExpired =>
      'This pairing link expired or was already used. Create a new link on the daemon.';

  @override
  String get relayPairFailed =>
      'Could not connect this daemon. Create a new link on the daemon and try again.';

  @override
  String get relayAdvancedDirect => 'Direct connection';

  @override
  String get relayAdvancedRelayEndpoint => 'Relay server address';

  @override
  String get relayAdvancedRelayEndpointChange => 'Change relay server address';

  @override
  String get relayAdvancedRelayEndpointHelp =>
      'Use the official relay by default, or enter a self-hosted WebSocket endpoint.';

  @override
  String get relayDevicesTitle => 'Connected devices';

  @override
  String get relayDevicesDescription =>
      'Create a ten-minute link for a new device or remove a device that should no longer connect.';

  @override
  String get relayCreateLink => 'Create connection link';

  @override
  String relayLinkExpires(String expiresAt) {
    return 'Expires $expiresAt';
  }

  @override
  String get relayNoDevices => 'No devices are approved.';

  @override
  String get relayRevoke => 'Revoke';

  @override
  String relayRevokeTitle(String name) {
    return 'Revoke $name?';
  }

  @override
  String get relayRevokeBody =>
      'The device\'s live relay connection ends immediately. A new pairing link is required to reconnect.';

  @override
  String get relayPathDirect => 'Direct';

  @override
  String get relayPathRelay => 'Relay';

  @override
  String get relayConnectionDetails => 'Connection details';

  @override
  String get relayApprovedDevices => 'Devices';

  @override
  String get appSettingsNoRemotes => 'No remote daemons are saved.';

  @override
  String get appSettingsStopEmbeddedTitle => 'Stop the embedded daemon?';

  @override
  String get appSettingsStopEmbeddedBody =>
      'This stops only the daemon this app owns, along with its connection. Remote and standalone daemons are unaffected.';

  @override
  String get appSettingsEditConnection => 'Edit connection';

  @override
  String get appSettingsAutoConnect => 'Connect on app start';

  @override
  String get appSettingsReconnect => 'Reconnect';

  @override
  String get appSettingsProviderSettings => 'Provider settings';

  @override
  String get appSettingsAddRemoteTitle => 'Add remote daemon';

  @override
  String get appSettingsEditRemoteTitle => 'Edit remote daemon';

  @override
  String get appSettingsAddress => 'WebSocket address';

  @override
  String get appSettingsLabelPlaceholder => 'Production daemon';

  @override
  String get appSettingsNewToken => 'New bearer token (only when changing it)';

  @override
  String get appSettingsBearerToken => 'Bearer token';

  @override
  String get appSettingsRemoteDetails => 'Daemon';

  @override
  String get appSettingsConnectionBehaviour => 'Connection';

  @override
  String get appSettingsConnectionFailed => 'Could not save the connection';

  @override
  String appSettingsDeleteTitle(String label) {
    return 'Delete $label?';
  }

  @override
  String get appSettingsDeleteBody =>
      'The connection and the bearer token stored on this device are removed too.';

  @override
  String get projectSettingsHeading => 'Projects';

  @override
  String get projectSettingsNoProjects => 'No projects are registered.';

  @override
  String get projectSettingsSelectProject => 'Select a project.';

  @override
  String get projectSettingsProjectList => 'Project list';

  @override
  String projectSettingsCount(int count) {
    return '$count projects';
  }

  @override
  String get projectSettingsCopyPath => 'Copy file location';

  @override
  String get projectSettingsHookHelp =>
      'Write one command per line; they run in order in the daemon host\'s shell. The CODER_WORKTREE_PATH, CODER_PROJECT_PATH, and CODER_BRANCH environment variables are available.';

  @override
  String get projectSettingsSetup => 'Setup (after a worktree is created)';

  @override
  String get projectSettingsTeardown =>
      'Teardown (before a worktree is removed)';

  @override
  String get agentSettingsHeading => 'Agents';

  @override
  String get agentSettingsSelectAgent => 'Select an agent.';

  @override
  String get agentSettingsEmpty => 'No agents are configured.';

  @override
  String agentSettingsCount(int count) {
    return '$count definitions';
  }

  @override
  String agentSettingsModeStale(String mode) {
    return '$mode · stale';
  }

  @override
  String get agentSettingsAdd => 'Add agent';

  @override
  String get agentSettingsAddTitle => 'Add agent';

  @override
  String get agentSettingsList => 'Agent list';

  @override
  String get agentSettingsCopyPath => 'Copy file location';

  @override
  String get agentSettingsReset => 'Reset to defaults';

  @override
  String get agentSettingsCustomPrompt => 'Use a custom system prompt';

  @override
  String get agentSettingsUseModel => 'Set a model for this agent';

  @override
  String get agentSettingsUseModelDescription =>
      'When off, this agent uses the daemon default model.';

  @override
  String get agentSettingsDefinitionHeading => 'Definition';

  @override
  String get agentSettingsPromptHeading => 'System prompt';

  @override
  String get agentSettingsSystemPrompt => 'System prompt (Markdown)';

  @override
  String get agentSettingsModelHeading => 'Model';

  @override
  String get agentSettingsSessionModel => 'Use the session model';

  @override
  String get agentSettingsPinnedModel => 'Pin a model';

  @override
  String get agentSettingsProviderConnectionId => 'Provider connection ID';

  @override
  String get agentSettingsModelId => 'Model ID';

  @override
  String get agentSettingsHarnessHeading => 'Agent harness';

  @override
  String get agentSettingsHarnessDescription =>
      'The Agent owns exactly one driver, ordered extensions, and its model-visible tools.';

  @override
  String get agentSettingsDriver => 'Driver';

  @override
  String get agentSettingsNoDrivers => 'No plugin driver is installed.';

  @override
  String get agentSettingsExtensions => 'Ordered extensions';

  @override
  String get agentSettingsExtensionsDescription =>
      'Extensions run serially in this order.';

  @override
  String get agentSettingsMoveUp => 'Move earlier';

  @override
  String get agentSettingsMoveDown => 'Move later';

  @override
  String get agentSettingsPluginTools => 'Plugin tools';

  @override
  String get agentSettingsPluginToolsDescription =>
      'Every model-visible tool can be switched independently for this Agent.';

  @override
  String get agentSettingsPluginSettings => 'Plugin settings';

  @override
  String get agentSettingsPluginSettingsDescription =>
      'Settings are stored in this Agent definition as JSON objects.';

  @override
  String get agentSettingsPluginSettingsRemove =>
      'Clear the field to remove an existing settings entry.';

  @override
  String agentSettingsPluginSettingsLabel(String plugin) {
    return '$plugin settings (JSON)';
  }

  @override
  String get agentSettingsCapabilities => 'Plugin capabilities';

  @override
  String get agentSettingsCapabilitiesDescription =>
      'Grants are kept in daemon state for this Agent, not in the editable Agent file.';

  @override
  String get agentSettingsNoCapabilities =>
      'The selected plugins request no capabilities.';

  @override
  String get agentSettingsHarnessDiagnostics => 'Harness diagnostics';

  @override
  String agentSettingsHarnessMissing(String kind, String id) {
    return 'Configured $kind is unavailable: $id';
  }

  @override
  String get agentSettingsHarnessKindDriver => 'driver';

  @override
  String get agentSettingsHarnessKindExtension => 'extension';

  @override
  String get agentSettingsHarnessKindTool => 'tool';

  @override
  String get agentSettingsHarnessKindPlugin => 'plugin';

  @override
  String get agentSettingsHarnessKindDependency => 'dependency';

  @override
  String get agentSettingsHarnessKindModel => 'model';

  @override
  String agentSettingsHarnessModelMismatch(String capability) {
    return 'The selected model does not satisfy driver capability: $capability';
  }

  @override
  String agentSettingsHarnessInvalidSettings(String plugin) {
    return '$plugin settings must be a valid JSON object.';
  }

  @override
  String get agentSettingsPluginsLoading => 'Loading plugin contributions…';

  @override
  String get agentSettingsBehaviourHeading => 'Behaviour';

  @override
  String get agentSettingsReasoning => 'Reasoning effort';

  @override
  String get agentSettingsPermission => 'Permission mode';

  @override
  String get agentSettingsBuiltinTools => 'Built-in tools';

  @override
  String get agentSettingsToolGroupFilesystem => 'Files';

  @override
  String get agentSettingsToolGroupEditing => 'Editing';

  @override
  String get agentSettingsToolGroupExecution => 'Commands';

  @override
  String get agentSettingsToolGroupAttachments => 'Attachments';

  @override
  String get agentSettingsToolGroupMcp => 'MCP';

  @override
  String get agentSettingsToolGroupCollaboration => 'Collaboration';

  @override
  String get agentSettingsToolGroupSession => 'Session';

  @override
  String agentSettingsToolGroupSummary(int enabled, int total) {
    return '$enabled of $total on';
  }

  @override
  String get agentSettingsSubagents => 'Callable subagents';

  @override
  String get agentSettingsNoSubagents => 'No subagents are registered.';

  @override
  String agentSettingsArchiveTitle(String name) {
    return 'Archive $name?';
  }

  @override
  String get agentSettingsArchiveBody =>
      'Sessions already using this agent keep running. It stops being offered for new ones.';

  @override
  String agentSettingsResetTitle(String name) {
    return 'Reset $name to defaults?';
  }

  @override
  String get agentSettingsResetBody =>
      'Every edit made to this built-in agent is discarded and cannot be recovered.';

  @override
  String get agentSettingsArchiveFailed => 'Could not archive the agent.';

  @override
  String get agentSettingsResetFailed =>
      'Could not restore the built-in agent.';

  @override
  String get agentSettingsArchived => 'Archived.';

  @override
  String get agentSettingsResetDone => 'Restored the built-in agent.';

  @override
  String get agentSettingsSaveFailedTitle => 'Could not save the agent';

  @override
  String get agentSettingsReload => 'Reload';

  @override
  String get agentSettingsOverwrite => 'Overwrite';

  @override
  String get agentSettingsIdInvalid =>
      'Only lowercase letters, digits, -, and _ are allowed.';

  @override
  String get agentSettingsIdTaken => 'That agent ID already exists.';

  @override
  String get agentSettingsIdLabel => 'ID (file name)';

  @override
  String get agentSettingsNameRequired => 'Enter a name.';

  @override
  String get providerSettingsTitle => 'Provider settings';

  @override
  String get providerSettingsRequiresDaemon => 'Connect a daemon first.';

  @override
  String get providerSettingsRefreshCatalog => 'Refresh catalog';

  @override
  String get providerSettingsCatalogStatus => 'Catalog metadata';

  @override
  String get providerSettingsCatalogBundled => 'Bundled snapshot';

  @override
  String get providerSettingsCatalogCached => 'Last-known-good cache';

  @override
  String get providerSettingsCatalogFresh => 'Recently refreshed';

  @override
  String get providerSettingsCatalogStale =>
      'Refresh due; local metadata remains available';

  @override
  String get modelSettingsSection => 'Daemon default model';

  @override
  String get modelSettingsSectionDescription =>
      'New chats use this model when neither the chat nor its agent specifies one.';

  @override
  String get modelSettingsUnavailableTitle => 'Saved model unavailable';

  @override
  String modelSettingsUnavailableDescription(String modelId) {
    return '$modelId cannot run. Choose another model before starting a chat.';
  }

  @override
  String get modelSettingsSaveFailed =>
      'Could not update the daemon default model';

  @override
  String providerSettingsAuthTitle(String name) {
    return '$name connection';
  }

  @override
  String get providerSettingsExperimental => 'Experimental';

  @override
  String get providerSettingsDisconnectTitle => 'Disconnect provider';

  @override
  String providerSettingsDisconnectBody(String name) {
    return 'Disconnect $name? Existing agent history is kept.';
  }

  @override
  String get providerSettingsDisconnect => 'Disconnect';

  @override
  String get providerSettingsDeleteCustomTitle => 'Delete custom provider';

  @override
  String providerSettingsDeleteCustomBody(String name) {
    return 'Delete $name and its stored credentials? Existing session history is kept.';
  }

  @override
  String get providerSettingsConnected => 'Connected';

  @override
  String get providerSettingsNoConnections => 'No providers are connected.';

  @override
  String get providerSettingsSelectConnection => 'Select a provider to manage.';

  @override
  String get providerSettingsRequiredFields =>
      'Name and Base URL are required.';

  @override
  String get providerSettingsApiKeyRequired => 'API key is required.';

  @override
  String get providerSettingsEditAdvanced => 'Edit advanced settings';

  @override
  String get providerSettingsActions => 'Connection actions';

  @override
  String get providerSettingsAdd => 'Add provider';

  @override
  String get providerSettingsNoPresets => 'No presets are left to add.';

  @override
  String get providerSettingsCustomSubtitle =>
      'Advanced: connect your own endpoint';

  @override
  String get providerSettingsCustomName => 'Custom Provider';

  @override
  String get providerSettingsRefreshFailed => 'Could not refresh the catalog';

  @override
  String get providerSettingsOAuthPending => 'Waiting for sign-in';

  @override
  String get providerSettingsOpenBrowser => 'Open browser';

  @override
  String get providerSettingsReconnect => 'Reconnect';

  @override
  String get providerSettingsModelPrefix => 'Model prefix';

  @override
  String get providerSettingsModelPrefixHelp =>
      'Used in model IDs such as openai/gpt-5.6-col.';

  @override
  String get providerSettingsModelPrefixInvalid =>
      'Use 1–64 lowercase letters, numbers, hyphens, or underscores.';

  @override
  String get providerSettingsModelPrefixConflict =>
      'That model prefix is already in use. Try the updated suggestion.';

  @override
  String get providerSettingsConnectionHeading => 'Connection status';

  @override
  String providerSettingsConnectTitle(String name) {
    return 'Connect $name';
  }

  @override
  String get providerSettingsConnect => 'Connect';

  @override
  String get providerSettingsApiKey => 'API key';

  @override
  String get providerSettingsBaseUrl => 'Base URL';

  @override
  String get providerSettingsConnectionFailed => 'Provider connection failed.';

  @override
  String get providerSettingsAuthUrlFailed =>
      'Unable to open the authorization page.';

  @override
  String get providerSettingsCustomTitle => 'Custom provider advanced settings';

  @override
  String get providerSettingsApiFormat => 'API format';

  @override
  String get providerSettingsRequiresApiKey => 'Requires an API key';

  @override
  String get providerSettingsManualModelId => 'Model ID';

  @override
  String get providerSettingsManualModelAdd => 'Add model';

  @override
  String get providerSettingsManualModelRemove => 'Remove model';

  @override
  String providerSettingsControlValues(String control) {
    return '$control values';
  }

  @override
  String get providerSettingsControlValuesHelp =>
      'Type a value and select it to add. Only whoever runs this endpoint knows which values it accepts.';

  @override
  String get providerSettingsControlValuesPlaceholder => 'Type a value';

  @override
  String providerSettingsControlValuesRequired(String control) {
    return 'Add at least one value for $control, or turn it off.';
  }

  @override
  String get providerSettingsModelLookupFailedTitle => 'Could not list models';

  @override
  String get providerSettingsModelLookupFailedBody =>
      'The provider did not return a model list. Enter the model IDs to use.';

  @override
  String get providerSettingsLater => 'Later';

  @override
  String get providerStatusConnecting => 'Connecting';

  @override
  String get providerStatusConnected => 'Connected';

  @override
  String get providerStatusDegraded => 'Limited connection';

  @override
  String get providerStatusError => 'Error';

  @override
  String get providerStatusReauthRequired => 'Sign in again';

  @override
  String get providerStatusDisconnected => 'Disconnected';

  @override
  String get providerAuthStored => 'Stored credential';

  @override
  String get providerAuthOAuth => 'OAuth';

  @override
  String get providerAuthNone => 'No credential';

  @override
  String get modelPickerTitle => 'Select a model';

  @override
  String get modelPickerSearch => 'Search models';

  @override
  String get modelPickerNoResults => 'No results.';

  @override
  String get composerSelectAgent => 'Select an agent';

  @override
  String get composerAgent => 'Agent';

  @override
  String get composerAgentLocked =>
      'The agent cannot be changed after the session starts.';

  @override
  String get composerModel => 'Model';

  @override
  String get composerSelectModel => 'Select a model';

  @override
  String get composerStartHint => 'Start a new session with a coding request.';

  @override
  String get composerNoPrimaryAgent => 'No primary agent is available.';

  @override
  String get composerConnectProviderFirst => 'Connect a provider first.';

  @override
  String get composerInputHint => 'Type a coding request…';

  @override
  String get composerReasoningEffort => 'Effort';

  @override
  String get composerSelectReasoningEffort => 'Select reasoning effort';

  @override
  String get composerInheritReasoningEffort => 'Agent default';

  @override
  String get composerPermissionMode => 'Permissions';

  @override
  String get composerSelectPermissionMode => 'Select permissions';

  @override
  String get composerPermissionReadOnly => 'Read only';

  @override
  String get composerPermissionAsk => 'Ask before changes';

  @override
  String get composerPermissionWorkspaceWrite => 'Workspace access';

  @override
  String get composerPermissionFullAccess => 'Full access';

  @override
  String get permissionPickerDescription =>
      'Choose what the agent may do without asking.';

  @override
  String get permissionDescriptionReadOnly =>
      'Can read files. File changes, commands, and write-capable external tools are blocked.';

  @override
  String get permissionDescriptionAsk =>
      'Reads without asking. Asks before file changes, commands, and write-capable external tools.';

  @override
  String get permissionDescriptionWorkspaceWrite =>
      'Can read and edit workspace files. Asks before commands and write-capable external tools.';

  @override
  String get permissionDescriptionFullAccess =>
      'Runs file changes, commands, and external tools without asking. Use only for trusted work.';

  @override
  String get permissionSettingsTitle => 'Permissions';

  @override
  String get permissionSettingsSection => 'Default permissions';

  @override
  String get permissionSettingsSectionDescription =>
      'Agents that do not choose their own permissions inherit this daemon default.';

  @override
  String get permissionSettingsChange => 'Change default permissions';

  @override
  String get permissionSettingsSaveFailed =>
      'Could not update default permissions';

  @override
  String get permissionChangeFailed => 'Could not change permissions';

  @override
  String get permissionSettingsDaemonDefault => 'Daemon default';

  @override
  String get composerFastMode => 'Fast';

  @override
  String get composerFastModeTooltip =>
      'Faster responses at a higher credit rate';

  @override
  String get composerFastModeOnTooltip =>
      'Fast mode is on; tap to use the standard tier';

  @override
  String get composerSettingLocked => 'Settings change between turns';

  @override
  String get composerSendLabel => 'Send message';

  @override
  String get composerQueueLabel => 'Queue message';

  @override
  String get composerQueueTooltip => 'Sends when the current turn finishes';

  @override
  String get composerQueuedEdit => 'Edit queued message';

  @override
  String get composerQueuedSendNow => 'Send queued message now';

  @override
  String composerQueuedAttachments(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString files',
      one: '1 file',
    );
    return '$_temp0';
  }

  @override
  String composerQueuedFailed(String reason) {
    return 'Not sent · $reason';
  }

  @override
  String get composerAttachLabel => 'Attach files';

  @override
  String composerRemoveAttachment(String name) {
    return 'Remove $name';
  }

  @override
  String composerAttachmentTooLarge(int limit) {
    return 'Each attachment must be under $limit MB.';
  }

  @override
  String composerAttachmentTooMany(int limit) {
    return 'A turn accepts at most $limit files.';
  }

  @override
  String get composerMoreSettings => 'More settings';

  @override
  String get composerUseDefault => 'Use default';

  @override
  String get composerEnabled => 'Enabled';

  @override
  String get chatEmptyTitle => 'Type a coding request.';

  @override
  String get chatEmptyExample => 'e.g. Run the tests and fix what fails';

  @override
  String get chatNoticeCancelled => 'Stopped';

  @override
  String chatNoticeFailed(String message) {
    return 'Failed · $message';
  }

  @override
  String get chatCopyResponse => 'Copy response';

  @override
  String chatMoreLines(int count) {
    return '… $count more lines';
  }

  @override
  String chatApprovalRequired(String tool) {
    return 'Approval required · $tool';
  }

  @override
  String get chatApprovalDeny => 'Deny';

  @override
  String get chatApprovalAllow => 'Allow';

  @override
  String usageInput(int tokens) {
    return 'in $tokens';
  }

  @override
  String usageInputCached(int tokens, int cached) {
    return 'in $tokens ($cached cached)';
  }

  @override
  String usageOutput(int tokens) {
    return 'out $tokens';
  }

  @override
  String usageOutputReasoning(int tokens, int reasoning) {
    return 'out $tokens ($reasoning reasoning)';
  }

  @override
  String usageTotal(int tokens) {
    return 'total $tokens';
  }

  @override
  String usageThroughput(double rate) {
    final intl.NumberFormat rateNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String rateString = rateNumberFormat.format(rate);

    return '$rateString tok/s';
  }

  @override
  String chatAnswerTyped(String answer) {
    return '$answer (typed)';
  }

  @override
  String get chatSleepWaiting => 'Waiting';

  @override
  String chatSleepRemaining(int seconds) {
    return '${seconds}s left';
  }

  @override
  String chatSleepDone(int seconds) {
    return 'Waited ${seconds}s';
  }

  @override
  String get subagentApprovalSection => 'Subagent approvals';

  @override
  String get subagentTabAwaitingApproval =>
      'A subagent is waiting for approval';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusRunning => 'Running';

  @override
  String get statusBlocked => 'Waiting for approval';

  @override
  String get statusPaused => 'Interrupted';

  @override
  String get statusDone => 'Completed';

  @override
  String get statusFailed => 'Failed';

  @override
  String get chatToolSubagentQueued => 'Queued';

  @override
  String chatToolSubagentCount(int count) {
    return '$count agents';
  }

  @override
  String chatDeferredTools(int count) {
    return '$count tools are available through search';
  }

  @override
  String get chatQuestionSubmit => 'Answer';

  @override
  String get chatQuestionNext => 'Next';

  @override
  String get chatQuestionNavigation => 'Questions';

  @override
  String get chatQuestionSubmitting => 'Submitting answers';

  @override
  String get chatQuestionOther => 'Other';

  @override
  String get chatQuestionOtherPlaceholder => 'Type your answer';

  @override
  String get toolRejected => 'Rejected';

  @override
  String get toolFailed => 'Failed';

  @override
  String get directoryBrowserTitle => 'Choose a folder on the daemon';

  @override
  String get directoryBrowserPath => 'Daemon path';

  @override
  String get directoryBrowserEmpty => 'No subfolders.';

  @override
  String get directoryBrowserSelect => 'Choose this folder';

  @override
  String get directoryBrowserHostTitle => 'Daemon to add the folder to';

  @override
  String hookFailureMessage(String phase, int exitCode, String command) {
    return '$phase failed (exit $exitCode): $command';
  }

  @override
  String hookFailureTitle(String phase) {
    return '$phase hook failed';
  }

  @override
  String get hookFailureNoOutput => '(no output)';

  @override
  String get settingsCategorySkill => 'Skill';

  @override
  String get skillSettingsHeading => 'Skills';

  @override
  String get skillSettingsScope => 'Skill scope';

  @override
  String get skillSettingsScopeGlobal => 'Global';

  @override
  String get skillSettingsScopeHint =>
      'Shows only effective skills defined in the selected scope.';

  @override
  String skillSettingsGlobalCount(int count) {
    return '$count global skills';
  }

  @override
  String skillSettingsProjectCount(int count) {
    return '$count project skills';
  }

  @override
  String get skillSettingsGlobalEmpty => 'No global skills are available.';

  @override
  String get skillSettingsProjectEmpty =>
      'No skills are available in this project.';

  @override
  String get skillSettingsProjectSearch => 'Search projects';

  @override
  String get skillSettingsProjectNoMatch => 'No matching project';

  @override
  String get settingsCategoryMcp => 'MCP';

  @override
  String get mcpSettingsHeading => 'MCP servers';

  @override
  String get mcpSettingsAdd => 'Add MCP server';

  @override
  String get mcpSettingsEmpty => 'No MCP servers are configured.';

  @override
  String get mcpSettingsSelectServer => 'Select a server to edit it.';

  @override
  String get mcpSettingsScopeUser => 'Yours';

  @override
  String get mcpSettingsScopeProject => 'This project';

  @override
  String mcpSettingsProjectReadOnly(String appName) {
    return 'Defined by this repository, so $appName does not edit it.';
  }

  @override
  String get mcpSettingsShadowed => 'Hidden by your server of the same name';

  @override
  String mcpSettingsSource(String path) {
    return 'Defined in $path';
  }

  @override
  String get mcpSettingsServerId => 'ID';

  @override
  String get mcpSettingsServerIdInvalid =>
      'Use lower-case letters, digits, - and _.';

  @override
  String get mcpSettingsTransport => 'Transport';

  @override
  String get mcpSettingsTransportStdio => 'Command';

  @override
  String get mcpSettingsTransportHttp => 'HTTP';

  @override
  String get mcpSettingsCommand => 'Command';

  @override
  String get mcpSettingsArgs => 'Arguments (one per line)';

  @override
  String get mcpSettingsWorkingDirectory => 'Working directory (optional)';

  @override
  String get mcpSettingsUrl => 'URL';

  @override
  String get mcpSettingsEnvironment => 'Environment (KEY=value, one per line)';

  @override
  String get mcpSettingsHeaders => 'Headers (Name: value, one per line)';

  @override
  String get mcpSettingsConnectionHeading => 'Connection';

  @override
  String get mcpSettingsStateHeading => 'Availability';

  @override
  String get mcpSettingsEnabled => 'Enabled';

  @override
  String get mcpSettingsSecretHint =>
      'Never paste a secret here. Reference a stored secret or an environment variable instead:';

  @override
  String get mcpSettingsTest => 'Test connection';

  @override
  String mcpSettingsTestSucceeded(int count) {
    return 'Connected and found $count tools.';
  }

  @override
  String mcpSettingsTestFailed(String error) {
    return 'Could not connect: $error';
  }

  @override
  String get terminalTerminateFailed => 'Could not stop the terminal.';

  @override
  String get relayRevokeFailed => 'Could not revoke the device.';

  @override
  String get appSettingsDaemonChangeFailed =>
      'Could not change the daemon setting.';

  @override
  String get appSettingsDeleteFailed => 'Could not remove the daemon.';

  @override
  String get appSettingsReconnectFailed => 'Could not reconnect.';

  @override
  String get providerSettingsDisconnectFailed =>
      'Could not disconnect the provider.';

  @override
  String get providerSettingsDeleteFailed => 'Could not delete the provider.';

  @override
  String get providerSettingsDisconnected => 'Disconnected.';

  @override
  String get workspaceArchiveFailed => 'Could not archive the worktree.';

  @override
  String get workspaceUnregisterFailed => 'Could not remove the project.';

  @override
  String get projectSettingsSaveFailed =>
      'Could not save the project settings.';

  @override
  String get mcpSettingsSaveFailed => 'Could not save the server.';

  @override
  String get mcpSettingsDeleteFailed => 'Could not delete the server.';

  @override
  String get mcpSettingsSecretFailed => 'Could not store the secret.';

  @override
  String get mcpSettingsDelete => 'Delete server';

  @override
  String mcpSettingsDeleteConfirm(String name) {
    return 'Delete $name? Agents using its tools will lose them.';
  }

  @override
  String get mcpSettingsStatusDisabled => 'Disabled';

  @override
  String get mcpSettingsStatusConnecting => 'Connecting';

  @override
  String get mcpSettingsConnecting => 'Connecting MCP server';

  @override
  String get mcpSettingsStatusReady => 'Ready';

  @override
  String get mcpSettingsStatusFailed => 'Failed';

  @override
  String get mcpSettingsDiscoveredResources => 'resources';

  @override
  String get mcpSettingsResources => 'Published resources';

  @override
  String get mcpSettingsNoResources => 'This server publishes no resources.';

  @override
  String get mcpSettingsResourceTemplates => 'Resource templates';

  @override
  String get mcpSettingsNoResourceTemplates =>
      'This server publishes no resource templates.';

  @override
  String get mcpSettingsDiscoveredTools => 'Tools';

  @override
  String get mcpSettingsNoTools => 'This server publishes no tools.';

  @override
  String get mcpSettingsDiagnostics => 'Server output';

  @override
  String get mcpSettingsSecretSet => 'Store a secret';

  @override
  String get mcpSettingsSecretKey => 'Reference name';

  @override
  String get mcpSettingsSecretValue => 'Value';

  @override
  String get sessionContextMeter => 'Context';

  @override
  String sessionContextMeterValue(int percent) {
    return '$percent% of the context window used';
  }

  @override
  String get sessionContextDetailsTitle => 'Context usage';

  @override
  String sessionContextPercent(int percent) {
    return '$percent% used';
  }

  @override
  String sessionContextTokens(String used, String max) {
    return '$used / $max tokens';
  }

  @override
  String sessionContextCost(String cost) {
    return 'Session cost $cost';
  }

  @override
  String get sessionQuotaLoading => 'Loading provider usage';

  @override
  String get sessionQuotaError => 'Provider usage is temporarily unavailable.';

  @override
  String sessionQuotaProviderPlan(String provider, String plan) {
    return '$provider · $plan';
  }

  @override
  String sessionQuotaPercent(int percent) {
    return '$percent% used';
  }

  @override
  String sessionQuotaResets(String time) {
    return 'Resets $time';
  }

  @override
  String sessionQuotaCredits(String amount) {
    return 'Credits $amount';
  }

  @override
  String get sessionQuotaWindowSession => 'Session limit';

  @override
  String get sessionQuotaWindowWeekly => 'Weekly limit';

  @override
  String get sessionQuotaWindowCodeReview => 'Code review limit';

  @override
  String get composerCommandNoAttachments =>
      'Remove attachments to run a command.';

  @override
  String get composerCommandsEmpty => 'No commands';

  @override
  String get composerFilesEmpty => 'No files';

  @override
  String get composerFilesSearching => 'Searching workspace';

  @override
  String get composerCommandsError => 'Could not load commands';

  @override
  String get composerFilesError => 'Could not search files';

  @override
  String get composerCommandSourceClient => 'app';

  @override
  String get composerCommandSourceAgent => 'command';

  @override
  String get composerCommandSourceSkill => 'skill';

  @override
  String get composerCommandClearLabel => 'clear';

  @override
  String get composerCommandClearDescription => 'Clear the composer.';

  @override
  String get composerCommandNewLabel => 'new';

  @override
  String get composerCommandNewDescription => 'Start a new session.';

  @override
  String get composerCommandAgentsLabel => 'agents';

  @override
  String get composerCommandAgentsDescription => 'Open agent settings.';

  @override
  String get composerCommandSkillsLabel => 'skills';

  @override
  String get composerCommandSkillsDescription => 'Open skill settings.';

  @override
  String get composerCommandHelpLabel => 'help';

  @override
  String get composerCommandHelpDescription => 'List the available commands.';

  @override
  String get composerSuggestionsLabel => 'Suggestions';

  @override
  String get composerDropFilesHere => 'Drop files here';

  @override
  String get chatToolActionRead => 'Read file';

  @override
  String get chatToolActionList => 'List files';

  @override
  String get chatToolActionSearch => 'Search';

  @override
  String get chatToolActionEdit => 'Edit files';

  @override
  String get chatToolActionRun => 'Run command';

  @override
  String get chatToolActionDelegate => 'Coordinate agents';

  @override
  String get chatToolActionAsk => 'Ask a question';

  @override
  String get chatToolActionResource => 'Use resource';

  @override
  String get chatToolActionTools => 'Find tools';

  @override
  String get chatToolActionClock => 'Wait';

  @override
  String get chatToolActionContext => 'Manage context';

  @override
  String get chatToolActionImage => 'View image';

  @override
  String get chatToolActionGeneric => 'Use tool';

  @override
  String get chatReasoningThinking => 'Thinking…';

  @override
  String get chatReasoningThought => 'Thought';

  @override
  String get chatReasoningWaiting => 'Waiting for reasoning details…';

  @override
  String get chatToolStatusFailed => 'Failed';

  @override
  String get chatToolStatusDenied => 'Denied';

  @override
  String get chatToolDetailsTool => 'Tool';

  @override
  String get chatToolDetailsRequest => 'Request';

  @override
  String get chatToolDetailsResult => 'Result';

  @override
  String get settingsCategoryPlugin => 'Plugins';

  @override
  String get pluginSettingsHeading => 'Plugins';

  @override
  String pluginSettingsCount(int count) {
    return '$count plugins';
  }

  @override
  String get pluginSettingsSelect => 'Select a plugin.';

  @override
  String get pluginSettingsAdd => 'Create plugin';

  @override
  String get pluginSettingsAddTitle => 'Create plugin starter';

  @override
  String get pluginSettingsEmpty => 'No plugins are installed.';

  @override
  String get pluginSettingsSource => 'Source';

  @override
  String get pluginSettingsSourceBuiltIn => 'Built in';

  @override
  String get pluginSettingsSourceUser => 'User';

  @override
  String get pluginSettingsSourcePath => 'Source path';

  @override
  String get pluginSettingsApi => 'Plugin API';

  @override
  String pluginSettingsApiValue(int api) {
    return 'API $api';
  }

  @override
  String get pluginSettingsRevision => 'Active revision';

  @override
  String get pluginSettingsRevisionMissing => 'No active revision';

  @override
  String get pluginSettingsStale => 'Using last known good revision';

  @override
  String get pluginSettingsAuthoring => 'Lua development environment';

  @override
  String get pluginSettingsAuthoringStatus => 'Authoring status';

  @override
  String get pluginSettingsAuthoringSynchronized => 'Synchronized';

  @override
  String get pluginSettingsAuthoringNeedsSync => 'Synchronization required';

  @override
  String get pluginSettingsSdkAbi => 'SDK ABI';

  @override
  String get pluginSettingsLuaRuntime => 'Lua runtime';

  @override
  String get pluginSettingsLuaLs => 'Lua Language Server';

  @override
  String get pluginSettingsLuaConfig => 'LuaLS configuration';

  @override
  String get pluginSettingsSdkSync => 'Synchronize SDK';

  @override
  String get pluginSettingsCapabilities => 'Requested capabilities';

  @override
  String get pluginSettingsCapabilitiesNone =>
      'No host capabilities requested.';

  @override
  String get pluginSettingsAgents => 'Referencing agents';

  @override
  String get pluginSettingsAgentsNone => 'No Agent references this plugin.';

  @override
  String get pluginSettingsContributions => 'Contributions';

  @override
  String get pluginSettingsDiagnostics => 'Diagnostics';

  @override
  String get pluginSettingsDiagnosticsNone => 'No diagnostics.';

  @override
  String get pluginSettingsValidate => 'Validate';

  @override
  String get pluginSettingsReload => 'Reload';

  @override
  String get pluginSettingsOpenPath => 'Open plugin folder';

  @override
  String get pluginSettingsFork => 'Fork';

  @override
  String pluginSettingsForkTitle(String plugin) {
    return 'Fork $plugin';
  }

  @override
  String get pluginSettingsForkDescription =>
      'Copies the validated revision into a new app-data plugin without enabling it for any Agent.';

  @override
  String get pluginSettingsReloadAgent => 'Agent grants used for reload';

  @override
  String get pluginSettingsReloadNeedsAgent =>
      'Reference this plugin from an Agent before reloading it.';

  @override
  String get pluginSettingsId => 'Plugin ID';

  @override
  String get pluginSettingsName => 'Name';

  @override
  String get pluginSettingsIdInvalid =>
      'Use a lowercase dot-separated namespace, such as example.tools.';

  @override
  String get pluginSettingsIdTaken => 'That plugin ID already exists.';

  @override
  String get pluginSettingsUi => 'Plugin interface';

  @override
  String get pluginUiLoading => 'Loading plugin interface';

  @override
  String get pluginUiLoadFailed => 'The plugin interface could not be loaded.';

  @override
  String get pluginUiInvalidTitle => 'Unsupported plugin interface';

  @override
  String pluginUiInvalidDescription(String appName) {
    return 'This document is invalid, so $appName rendered its source as a read-only disclosure.';
  }

  @override
  String pluginUiSemanticLabel(String plugin) {
    return '$plugin plugin interface';
  }

  @override
  String get pluginSessionControlLoading => 'Loading session control';

  @override
  String get pluginSessionControlLoadFailed =>
      'The plugin session control could not be loaded.';

  @override
  String get pluginSessionControlUnsupported =>
      'Unsupported plugin session control';

  @override
  String get pluginSessionControlSaveFailed =>
      'The plugin session control could not be saved.';

  @override
  String get pluginContributionDriver => 'Driver';

  @override
  String get pluginContributionExtension => 'Extension';

  @override
  String get pluginContributionTool => 'Tool';

  @override
  String get pluginContributionSessionControl => 'Session control';

  @override
  String get pluginContributionUi => 'Interface';

  @override
  String get pluginSettingsActionFailed => 'Plugin action failed';
}
